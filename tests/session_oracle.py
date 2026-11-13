"""Exact rational coverage and certificate checks across pauses and restoration.

The reference parses algebra independently and does not call MoonBit arithmetic,
classification or contractor helpers. Trace modifications are either rejected or
must still retain every independently feasible sample.
"""
from pathlib import Path
from fractions import Fraction as F
import ast
import itertools
import json
import random
import subprocess

ROOT = Path(__file__).resolve().parents[1]
rng = random.Random(20261113)

def q(x):
    return F.from_float(x) if isinstance(x, float) else F(x)

def evaluate(expression, box):
    def walk(node):
        if isinstance(node, ast.Name): return box['xy'.index(node.id)]
        if isinstance(node, ast.Constant): return q(node.value), q(node.value)
        if isinstance(node, ast.UnaryOp):
            a, b = walk(node.operand)
            return (-b, -a) if isinstance(node.op, ast.USub) else (a, b)
        a, b = walk(node.left)
        if isinstance(node.op, ast.Pow):
            k = node.right.value
            assert k == 2
            return (F(0) if a <= 0 <= b else min(a*a, b*b), max(a*a, b*b))
        c, d = walk(node.right)
        if isinstance(node.op, ast.Add): return a+c, b+d
        if isinstance(node.op, ast.Sub): return a-d, b-c
        assert isinstance(node.op, ast.Mult)
        values = [a*c, a*d, b*c, b*d]
        return min(values), max(values)
    return walk(ast.parse(expression.replace('^', '**'), mode='eval').body)

def formula_truth(formula, atoms):
    if isinstance(formula, int): return atoms[formula]
    if 'all' in formula: k, children = len(formula['all']), formula['all']
    elif 'any' in formula: k, children = 1, formula['any']
    else: k, children = formula['at_least']['count'], formula['at_least']['of']
    values = [formula_truth(child, atoms) for child in children]
    if values.count(1) >= k: return 1
    if sum(v != -1 for v in values) < k: return -1
    return 0

def truth(request, box):
    atoms = []
    for c in request['constraints']:
        a, b = evaluate(c['expression'], box)
        lo, hi = map(q, c['range'])
        atoms.append(1 if lo <= a <= b <= hi else -1 if b < lo or a > hi else 0)
    return formula_truth(request.get('formula', {'all': list(range(len(atoms)))}), atoms)

requests = []
for i in range(48):
    a, b = rng.randint(1, 3), rng.randint(1, 3)
    constraints = []
    for expression in [f'{a}*x+{b}*y', 'x-y', 'x^2+y^2', 'x*y']:
        center = rng.randint(-4, 4)/4
        width = rng.randint(2, 8)/4
        constraints.append({'expression': expression, 'range': [center-width, center+width]})
    request = {
        'version': 1, 'mode': 'feasibility', 'variables': ['x', 'y'],
        'constraints': constraints, 'box': [[-1.5, 1.5], [-1.5, 1.5]],
        'options': {'tolerance': 0.125, 'max_assessments': 240, 'max_depth': 18},
        'search': {'strategy': 'bfs' if i % 2 else 'dfs', 'split': ['widest', 'scaled', 'smear'][i % 3]},
        'contractors': {'propagation': i % 4 != 0, 'newton': i % 4 in (2, 3), 'max_steps': 40},
    }
    if i % 4 == 1: request['formula'] = {'any': [{'all': [0, 1]}, 2]}
    if i % 4 == 2: request['formula'] = {'at_least': {'count': 2, 'of': [0, 1, 2, 3]}}
    if i % 4 == 3: request['formula'] = {'all': [3, {'any': [0, 1, 2]}]}
    requests.append(request)
run = subprocess.run(['node', 'tests/session_driver.mjs'], cwd=ROOT, input=json.dumps(requests), text=True, encoding='utf-8', capture_output=True, check=True)
results = json.loads(run.stdout)
assert len(results) == len(requests)
counts = {'models': len(requests), 'checked_snapshots': 0, 'exact_inner_certificates': 0, 'feasible_sample_coverage_checks': 0, 'trace_mutations': 0, 'rejected_mutations': 0, 'accepted_mutations_checked': 0}
for request, result in zip(requests, results):
    grid = itertools.product([F(j, 8) for j in range(-12, 13, 2)], repeat=2)
    points = [p for p in grid if truth(request, [(x, x) for x in p]) == 1]
    for snapshot in result['snapshots'] + [s for s in result['mutations'] if s is not None]:
        counts['checked_snapshots'] += 1
        boxes = [[(q(a), q(b)) for a, b in cell['box']] for cell in snapshot['inside'] + snapshot['unresolved']]
        for cell in snapshot['inside']:
            assert truth(request, [(q(a), q(b)) for a, b in cell['box']]) == 1, (request, cell)
            counts['exact_inner_certificates'] += 1
        for point in points:
            assert any(all(a <= x <= b for (a, b), x in zip(box, point)) for box in boxes), (request, point, snapshot)
            counts['feasible_sample_coverage_checks'] += 1
        assert snapshot['stats']['assessments'] <= request['options']['max_assessments']
        assert snapshot['stats']['contractor_calls'] <= 40
    counts['trace_mutations'] += len(result['mutations'])
    counts['rejected_mutations'] += sum(s is None for s in result['mutations'])
    counts['accepted_mutations_checked'] += sum(s is not None for s in result['mutations'])
report = {'passed': True, 'seed': 20261113, **counts, 'scope': 'finite exact-rational polynomial/formula regression; no formal proof or exhaustive corruption claim'}
(ROOT/'artifacts').mkdir(exist_ok=True)
(ROOT/'artifacts/session-oracle.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report))
