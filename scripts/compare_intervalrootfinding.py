"""Compare saved, actually executed Julia Newton/Krawczyk results with this build.
No timing ranking; unknown boxes need not have matching counts or subdivisions.
"""
from pathlib import Path
import json,subprocess
ROOT=Path(__file__).resolve().parents[1]
reference=ROOT/'artifacts/intervalrootfinding-reference.json'
if not reference.exists():reference=ROOT/'docs/evidence/intervalrootfinding-reference.json'
baseline=json.loads(reference.read_text(encoding='utf-8'))
queries=[{'kind':'solve','request':c['request']} for c in baseline['cases']]
p=subprocess.run(['node','tests/oracle_bridge.mjs'],cwd=ROOT,input='\n'.join(json.dumps(q) for q in queries)+'\n',text=True,encoding='utf-8',capture_output=True,check=True,timeout=120)
answers=[json.loads(s) for s in p.stdout.splitlines()]
assert len(answers)==len(queries)
rows=[];regular=0;singular=0;differences=[]
for case,got in zip(baseline['cases'],answers):
    assert 'error' not in got,(case['name'],got)
    runs=case['reference'];assert all('error' not in r for r in runs),case
    is_regular=all(r['unknown']==0 for r in runs)
    if is_regular:
        assert got['complete'] and all(got['root_count']==r['unique'] for r in runs),(case['name'],got,runs)
        for root in got['roots']:
            for run in runs:
                assert any(all(max(a,c)<=min(b,d) for (a,b),(c,d) in zip(root['enclosure'],cell['box'])) for cell in run['cells']),(case['name'],root,run)
        regular+=1
    elif case['name']=='pole_without_root':
        # 1/x cannot be zero at any defined point. HC4 rejects numerator 1
        # against the required product 0*x; this does not certify the pole defined.
        assert got['complete'] and got['root_count']==0
        differences.append({'name':case['name'],'reason':'RootCover excludes 1/x=0 algebraically on defined points; Julia retains an unknown box at the pole.'})
    else:
        assert not got['complete'] and got['root_count']==0 and got['unresolved'],(case['name'],got)
        singular+=1
    rows.append({'name':case['name'],'rootcover_unique':got['root_count'],'rootcover_unresolved':len(got['unresolved']),'rootcover_complete':got['complete'],
                 'julia':[{'method':r['method'],'unique':r['unique'],'unknown':r['unknown']} for r in runs]})
report={'passed':True,'julia_version':baseline['julia_version'],'intervalrootfinding_version':baseline['intervalrootfinding_version'],'models':len(rows),
        'julia_method_runs':sum(len(c['reference']) for c in baseline['cases']),'regular_models_matching_both_methods':regular,
        'shared_singular_unresolved_models':singular,'semantic_differences':differences,'cases':rows,
        'scope':'finite functional regression, no full-API parity, performance or formal-correctness claim'}
(ROOT/'artifacts/intervalrootfinding-comparison.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='cases'}))
