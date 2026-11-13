"""Exact rational predicate certificates, quorum preservation, search policies.
Not a proof of all inputs. No MoonBit evaluation/rounding logic is imported.
"""
from pathlib import Path
from fractions import Fraction as F
import ast,itertools,json,math,random,subprocess
from reference_math import dual,f
from high_precision import mp,val,valid_value,contains,bound
ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(20261113)

def formula(p,values):
    if isinstance(p,int):return values[p]
    if 'all' in p:return all(formula(c,values) for c in p['all'])
    if 'any' in p:return any(formula(c,values) for c in p['any'])
    q=p['at_least'];return sum(formula(c,values) for c in q['of'])>=q['count']

def integer_formula(p,values):
    """-1 false,0 unknown,1 true, independently count sure/possible children."""
    if isinstance(p,int):return values[p]
    children=p.get('all',p.get('any',p.get('at_least',{}).get('of')))
    k=len(children) if 'all' in p else 1 if 'any' in p else p['at_least']['count']
    states=[integer_formula(c,values) for c in children]
    return 1 if states.count(1)>=k else -1 if sum(x>=0 for x in states)<k else 0

def rational_contains(box,point):return all(f(a)<=x<=f(b) for (a,b),x in zip(box,point))

messages=[];cases=[];contractions=[];policies=[];scenarios=[]
def add(kind,q):messages.append({'kind':kind,'request':q});return len(messages)-1

for index in range(54):
    n=1 if index<24 else 2;names=['x','y'][:n]
    pool=['x','x^2','x^3','x*(x-1)'] if n==1 else ['x','y','x-y','x^2+y^2','x*y','(x-1)^2+y^2']
    constraints=[]
    for j in range(5):
        lo=rng.randint(-8,4)/4;hi=lo+rng.randint(1,8)/4
        constraints.append({'expression':rng.choice(pool),'range':[lo,hi]})
    predicates=[{'at_least':{'count':rng.randrange(1,5),'of':[0,1,2,3]}},
                {'all':[4,{'any':[{'all':[0,1]},{'all':[2,3]}]}]},
                {'any':[0,{'all':[4,{'at_least':{'count':2,'of':[1,2,3]}}]}]}]
    predicate=predicates[index%3]
    q={'version':1,'mode':'feasibility','variables':names,'constraints':constraints,'formula':predicate,'box':[[-2,2]]*n,
       'options':{'tolerance':.125 if n==1 else .25,'max_assessments':2000},
       'search':{'strategy':'bfs' if index%2 else 'dfs','split':['widest','scaled','smear'][index%3]}}
    expressions=[ast.parse(c['expression'].replace('^','**'),mode='eval').body for c in constraints]
    def exact_values(point):
        return [c['range'][0]<=dual(e,[(z,z) for z in point],names)[0][0]<=c['range'][1] for e,c in zip(expressions,constraints)]
    feasible=[]
    for point in itertools.product([F(k,4) for k in range(-8,9)],repeat=n):
        if formula(predicate,exact_values(point)):feasible.append(point)
    cases.append((add('solve',q),q,expressions,feasible))
    for flags in [{'propagation':True,'newton':False},{'propagation':False,'newton':True},{'propagation':True,'newton':True}]:
        request={**q,'contractors':{**flags,'max_steps':80,'max_rounds':4}}
        contractions.append((add('nonlinear',{'operation':'contract','request':json.dumps(request)}),q,feasible))

roots=[('x^2-1',[-2,2],[-mp.mpf(1),mp.mpf(1)]),('sin(x)',[-10,10],[k*mp.pi for k in range(-3,4)]),
       ('log(x)',[-1,3],[mp.mpf(1)]),('exp(x)-2',[-2,2],[mp.log(2)])]
for expression,domain,expected in roots:
    for order in ['dfs','bfs']:
        for split in ['widest','scaled','smear']:
            q={'version':1,'variables':['x'],'equations':[expression],'box':[domain],
               'search':{'strategy':order,'split':split,'absolute_tolerances':[1e-7],'relative_tolerance':1e-6}}
            policies.append((add('solve',q),q,expected))

for name,points in [('robust_localization',[(1,1)]),('design_alternatives',[(mp.mpf('.5'),mp.exp(mp.mpf('.25'))),(2,mp.sqrt(2))]),('scaled_parameters',[(1000100,mp.mpf('.0005'))])]:
    q=json.loads((ROOT/'examples'/f'{name}.json').read_text(encoding='utf-8'))
    scenarios.append((add('solve',q),q,points))

p=subprocess.run(['node','tests/oracle_bridge.mjs'],cwd=ROOT,input='\n'.join(json.dumps(m) for m in messages)+'\n',text=True,encoding='utf-8',capture_output=True,check=True,timeout=240)
answers=[json.loads(s) for s in p.stdout.splitlines()];assert len(answers)==len(messages),(len(answers),p.stderr)
certificate_count=0;feasible_samples=0;preserved_contractions=0
for index,q,expressions,feasible in cases:
    result=answers[index];assert 'error' not in result,(q,result)
    assert result['certificate_kind']=='positive_formula_interval_truth'
    assert result['formula']==q['formula']
    assert result['complete']==(not result['unresolved'])
    assert len(result['inside'])+len(result['unresolved'])+result['stats']['excluded']==result['stats']['splits']+1
    cells=[b['box'] for b in result['inside']+result['unresolved']]
    for cell in cells:assert all(a<=c<=d<=b for (a,b),(c,d) in zip(q['box'],cell))
    for i,a in enumerate(cells):
        for b in cells[:i]:assert not all(max(x[0],y[0])<min(x[1],y[1]) for x,y in zip(a,b)),('overlapping interiors',q,a,b)
    for cell in result['inside']:
        assert len(cell['atoms'])==len(expressions)
        exact_states=[]
        for e,c,reported in zip(expressions,q['constraints'],cell['atoms']):
            exact,_=dual(e,[tuple(map(f,a)) for a in cell['box']],q['variables'])
            lo,hi=map(f,reported['range']);a,b=map(f,c['range'])
            assert lo<=exact[0]<=exact[1]<=hi
            truth=1 if a<=exact[0]<=exact[1]<=b else -1 if exact[1]<a or exact[0]>b else 0
            if reported['truth']=='true':assert truth==1
            if reported['truth']=='false':assert truth==-1
            exact_states.append(truth)
        assert integer_formula(q['formula'],exact_states)==1,('unproved inner cell',q,cell)
        certificate_count+=1
    for point in feasible:
        assert any(rational_contains(cell,point) for cell in cells),('lost feasible point',q,point,result)
        feasible_samples+=1

for index,q,feasible in contractions:
    got=answers[index];assert 'error' not in got,(q,got)
    if got['box'] is not None:assert all(a<=c<=d<=b for (a,b),(c,d) in zip(q['box'],got['box']))
    for point in feasible:
        assert got['box'] is not None and rational_contains(got['box'],point),('quorum contractor lost feasible point',q,point,got)
        preserved_contractions+=1

for index,q,expected in policies:
    got=answers[index];assert 'error' not in got,(q,got)
    assert got['complete'] and got['root_count']==len(expected),(q,got)
    for point in expected:assert sum(contains(cell['enclosure'],[point]) for cell in got['roots'])==1,(q,str(point),got)
    if got['tolerance_met']:
        for cell in got['roots']:
            a,b=map(f,cell['enclosure'][0]);minimum=0 if a<=0<=b else min(abs(a),abs(b))
            assert b-a<=max(f(1e-7),f(1e-6)*minimum)

inner_points=0
for index,q,known in scenarios:
    got=answers[index];assert 'error' not in got,(q,got)
    assert got['inside'] and got['resolution_met']
    for point in known:assert any(contains(b['box'],list(map(mp.mpf,point))) for b in got['inside']+got['unresolved'])
    predicate=q.get('formula',{'all':list(range(len(q['constraints'])))})
    for cell in got['inside']:
        for point in itertools.product(*[[mp.mpf(a),mp.mpf(a)/2+mp.mpf(b)/2,mp.mpf(b)] for a,b in cell['box']]):
            truths=[]
            for c in q['constraints']:
                v=valid_value(c['expression'],point,q['variables'])
                if v is None:truths.append(False);continue
                if 'range' in c:
                    a,b=c['range'];truths.append((a is None or mp.mpf(a)<=v) and (b is None or v<=mp.mpf(b)))
                else:truths.append(v<=mp.mpf(c['rhs']) if c['relation']=='<=' else v>=mp.mpf(c['rhs']) if c['relation']=='>=' else v==mp.mpf(c['rhs']))
            assert formula(predicate,truths),('scenario inner point violates formula',q,cell,tuple(map(str,point)))
            inner_points+=1
    if got['resolution_met']:
        policy=got['search']
        for cell in got['unresolved']:
            for i,(a,b) in enumerate(cell['box']):
                a,b=f(a),f(b);minimum=0 if a<=0<=b else min(abs(a),abs(b))
                assert b-a<=max(f(policy['absolute_tolerances'][i]),f(policy['relative_tolerance'])*minimum)

report={'passed':True,'seed':20261113,'rational_formula_models':len(cases),'exact_inner_formula_certificates':certificate_count,
        'rational_feasible_samples':feasible_samples,'configured_contractor_runs':len(contractions),'contractor_preserved_samples':preserved_contractions,
        'root_search_policy_cases':len(policies),'new_scenarios':len(scenarios),'high_precision_inner_points':inner_points}
(ROOT/'artifacts/predicate-oracle.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
