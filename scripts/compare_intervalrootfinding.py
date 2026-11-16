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
    width_ratios=[];max_width=None;owners={}
    if is_regular:
        assert got['complete'] and all(got['root_count']==r['unique'] for r in runs),(case['name'],got,runs)
        max_width=0.0
        for run in runs:
            owners={i:[] for i in range(len(got['roots']))}
            for cell in run['cells']:
                hits=[i for i,root in enumerate(got['roots'])
                      if all(max(root['enclosure'][d][0],cell['box'][d][0])-1e-12<=min(root['enclosure'][d][1],cell['box'][d][1])
                             for d in range(len(cell['box'])))]
                assert len(hits)==1,('cell-not-uniquely-contained',case['name'],run['method'],cell['box'],hits)
                owners[hits[0]].append(cell)
            assert all(owners.values()),('root-without-cell',case['name'],run['method'],[i for i,v in owners.items() if not v])
            for i,root in enumerate(got['roots']):
                w=max(hi-lo for lo,hi in root['enclosure']);max_width=max(max_width,w)
                cw=max(c['box'][d][1]-c['box'][d][0] for c in owners[i] for d in range(len(c['box'])))
                if cw>0:width_ratios.append(w/cw)
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
                 'matched_cells':sum(len(v) for v in owners.values()) if is_regular else None,
                 'max_root_width':max_width if is_regular else None,
                 'median_width_ratio':sorted(width_ratios)[len(width_ratios)//2] if is_regular and width_ratios else None,
                 'julia':[{'method':r['method'],'unique':r['unique'],'unknown':r['unknown']} for r in runs]})
for row in rows:
    if row['rootcover_unique']==0 or row['rootcover_complete'] is False:
        assert row['matched_cells'] is None and row['max_root_width'] is None,row
report={'passed':True,'julia_version':baseline['julia_version'],'intervalrootfinding_version':baseline['intervalrootfinding_version'],'models':len(rows),
        'julia_method_runs':sum(len(c['reference']) for c in baseline['cases']),'regular_models_matching_both_methods':regular,
        'shared_singular_unresolved_models':singular,'semantic_differences':differences,'cases':rows,
        'scope':'finite functional regression, no full-API parity, performance or formal-correctness claim'}
payload=json.dumps(report,indent=2)
(ROOT/'artifacts/intervalrootfinding-comparison.json').write_text(payload,encoding='utf-8')
(ROOT/'docs/evidence/intervalrootfinding-comparison.json').write_text(payload+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='cases'}))
