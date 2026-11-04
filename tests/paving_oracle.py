"""Exact interval certificates, analytic set checks and rational-grid coverage."""
from pathlib import Path
from fractions import Fraction as F
import ast,itertools,json,random,subprocess
from reference_math import f,dual
ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(20261105)
requests=[json.loads((ROOT/'examples'/f'{name}.json').read_text()) for name in ['noisy_localization','calibration_band']]
for i in range(34):
    n=1 if i<15 else 2 if i<30 else 3
    names=[f'x{k}' for k in range(n)]
    expression='+'.join(f'({rng.randint(-3,3)/4})*{name}^2+({rng.randint(-3,3)/4})*{name}' for name in names)
    constraints=[{'expression':expression,'range':[-0.25,0.5]}]
    if i%3==0:constraints.append({'expression':names[0],'range':[-0.75,0.875]})
    requests.append({'version':1,'mode':'feasibility','variables':names,'constraints':constraints,'box':[[-1,1] for _ in names],'options':{'tolerance':0.0625 if n==1 else 0.25,'max_assessments':4000}})
budget=json.loads(json.dumps(requests[0]));budget['options']['max_assessments']=1;requests.append(budget)
messages=[{'kind':'solve','request':q} for q in requests]
p=subprocess.run(['node','tests/oracle_bridge.mjs'],cwd=ROOT,input='\n'.join(json.dumps(x) for x in messages)+'\n',text=True,capture_output=True,check=True,timeout=120)
answers=[json.loads(line) for line in p.stdout.splitlines()];assert len(answers)==len(requests)
certificates=0;sample_points=0
for q,r in zip(requests,answers):
    assert 'error' not in r,r
    assert r['mode']=='feasibility' and 'root_count' not in r
    assert r['complete']==(not r['unresolved'])
    assert r['definitely_empty']==(r['complete'] and not r['inside'])
    assert r['inner_box_count']==len(r['inside'])
    assert len(r['inside'])+len(r['unresolved'])+r['stats']['excluded']==r['stats']['splits']+1
    domain=[tuple(map(f,a)) for a in q['box']]
    all_boxes=[[tuple(map(f,a)) for a in b['box']] for b in r['inside']+r['unresolved']]
    for box in all_boxes:
        assert len(box)==len(domain)
        assert all(lo<=a<=b<=hi for (a,b),(lo,hi) in zip(box,domain))
    for i,a in enumerate(all_boxes):
        for b in all_boxes[:i]:
            assert not all(max(x[0],y[0])<min(x[1],y[1]) for x,y in zip(a,b)),('positive-volume overlap',q)
    expressions=[ast.parse(c['expression'].replace('^','**'),mode='eval').body for c in q['constraints']]
    allowed=[tuple(map(f,c['range'])) for c in q['constraints']]
    for cell in r['inside']:
        box=[tuple(map(f,a)) for a in cell['box']]
        assert len(cell['ranges'])==len(allowed)
        for e,target,reported in zip(expressions,allowed,cell['ranges']):
            exact,_=dual(e,box,q['variables']);lo,hi=map(f,reported)
            assert target[0]<=lo<=exact[0]<=exact[1]<=hi<=target[1],(q,cell)
        certificates+=1
    if r['resolution_met']:
        assert all(all(b-a<=f(q['options']['tolerance']) for a,b in cell) for cell in all_boxes[len(r['inside']):])
    k=64 if len(domain)==1 else 12 if len(domain)==2 else 4
    axes=[[lo+(hi-lo)*F(i,k) for i in range(k+1)] for lo,hi in domain]
    for point in itertools.product(*axes):
        sample_points+=1;box=[(x,x) for x in point]
        feasible=all(target[0]<=dual(e,box,q['variables'])[0][0]<=target[1] for e,target in zip(expressions,allowed))
        if feasible:
            assert any(all(a<=x<=b for (a,b),x in zip(cell,point)) for cell in all_boxes),('lost feasible sample',q,point)
report={'systems':len(requests),'exact_inner_box_replays':certificates,'rational_grid_points':sample_points,'passed':True}
(ROOT/'artifacts/paving-oracle.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
