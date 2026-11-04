"""Independent exact-rational arithmetic and analytic-root oracle. Python stdlib only.

MoonBit answers arrive through a separate compiled public consumer. Certificate
replay uses Fraction interval operations and a Python AST evaluator, not the
MoonBit rounding, differentiation, search or matrix-inversion implementation.
"""
from fractions import Fraction as F
from pathlib import Path
import ast,itertools,json,math,random,subprocess

ROOT=Path(__file__).resolve().parents[1]
SEED=20261104
rng=random.Random(SEED)
from reference_math import f,pt,add,sub,mul,power,replay

messages=[];expected=[]
rows=[];exact=[]
special=[0.0,-0.0,math.ulp(0.0),-math.ulp(0.0),1e-300,-1e-300,1e300,-1e300,0.1,-0.2]
for _ in range(700):
    a,b=sorted(rng.choices(special,k=2)) if rng.random()<0.3 else sorted(rng.uniform(-100,100) for _ in range(2))
    c,d=sorted(rng.choices(special,k=2)) if rng.random()<0.3 else sorted(rng.uniform(-100,100) for _ in range(2))
    for op,func in [('add',add),('sub',sub),('mul',mul)]:
        rows.append([op,a,b,c,d]);exact.append(func((f(a),f(b)),(f(c),f(d))))
    k=rng.randrange(0,9);rows.append(['pow',a,b,k,0]);exact.append(power((f(a),f(b)),k))
messages.append({'kind':'probe','rows':rows})
for _ in range(75):
    n=rng.randrange(1,7);names=[f'x{i}' for i in range(n)];r=[rng.randint(-12,12)/4 for _ in names]
    matrix=[[rng.randint(-2,2) for _ in names] for _ in names]
    for i in range(n):matrix[i][i]=sum(abs(x) for x in matrix[i])+3
    equations=['+'.join(f'({a})*({v}-({z}))' for a,v,z in zip(row,names,r)) for row in matrix]
    q={'version':1,'variables':names,'equations':equations,'box':[[z-1,z+1] for z in r]}
    messages.append({'kind':'solve','request':q});expected.append((q,[tuple(map(f,r))]))
for _ in range(75):
    n=rng.randrange(1,4);names=[f'x{i}' for i in range(n)];pairs=[]
    for _ in names:
        a=rng.randint(-15,-1)/4;b=rng.randint(1,15)/4;pairs.append((a,b))
    q={'version':1,'variables':names,'equations':[f'({x}-({a}))*({x}-({b}))' for x,(a,b) in zip(names,pairs)],'box':[[a-1,b+1] for a,b in pairs]}
    messages.append({'kind':'solve','request':q});expected.append((q,[tuple(map(f,z)) for z in itertools.product(*pairs)]))
for _ in range(30):
    a=rng.randint(-9,9)/4;k=rng.randint(1,8)
    q={'version':1,'variables':['x'],'equations':[f'(x-({a}))^2+{k}'],'box':[[a-4,a+4]]}
    messages.append({'kind':'solve','request':q});expected.append((q,[]))
for name,roots in [('localization',[(F(1),F(1),F(-2)),(F(1),F(1),F(2))]),('coupled6',list(itertools.product([F(-1),F(1)],repeat=6)))]:
    q=json.loads((ROOT/'examples'/f'{name}.json').read_text(encoding='utf-8'))
    messages.append({'kind':'solve','request':q});expected.append((q,roots))
proc=subprocess.run(['node','tests/oracle_bridge.mjs'],cwd=ROOT,input='\n'.join(json.dumps(x) for x in messages)+'\n',text=True,capture_output=True,timeout=180,check=True)
answers=[json.loads(x) for x in proc.stdout.splitlines()];assert len(answers)==len(messages),(len(answers),proc.stderr)
assert len(answers[0])==len(rows)
for got,want in zip(answers[0],exact):
    a,b=map(float,got)
    assert (math.isinf(a) and a<0 or f(a)<=want[0]) and (math.isinf(b) and b>0 or want[1]<=f(b)),(got,want)
certificates=0
for got,(q,roots) in zip(answers[1:],expected):
    assert 'error' not in got,got
    assert got['complete'] and not got['unresolved'],(q,got)
    assert got['root_count']==len(roots),(q,got)
    for root in roots:
        matches=[r for r in got['roots'] if all(f(a)<=x<=f(b) for (a,b),x in zip(r['enclosure'],root))]
        assert len(matches)==1,(q,root,got)
    for root in got['roots']:replay(q,root);certificates+=1
report={'seed':SEED,'interval_cases':len(rows),'systems':len(expected),'exact_certificate_replays':certificates,'passed':True}
(ROOT/'artifacts').mkdir(exist_ok=True)
(ROOT/'artifacts/oracle.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
