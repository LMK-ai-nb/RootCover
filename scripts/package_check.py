"""Inspect the real Moon package archive, not an assumed source-file list."""
from pathlib import Path
import json,re,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[1]
subprocess.run(['moon','package','--list'],cwd=ROOT,check=True,capture_output=True)
p=ROOT/'_build/publish/LMK-ai-nb-rootcover-0.1.0.zip'
private_contact = re.compile(rb'(?<![0-9])1[3-9][0-9]{9}(?![0-9])|[A-Za-z0-9_.+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
with zipfile.ZipFile(p) as z:
    assert z.testzip() is None
    for entry in z.infolist():
        parts=Path(entry.filename.replace('\\','/')).parts
        assert not any(x in parts for x in ['work','deliverables','.git','artifacts']),entry.filename
        data=z.read(entry)
        if 'third_party' not in parts:
            assert not private_contact.search(data),entry.filename
    names=[x.replace('\\','/') for x in z.namelist()]
    for name in ['interval.mbt','polynomial.mbt','krawczyk.mbt','solver.mbt','parser.mbt','format.mbt','LICENSE']:
        assert any(x==name or x.endswith('/'+name) for x in names),name
report={'archive':p.name,'files':len(names),'bytes':p.stat().st_size,'privacy_scan':'passed'}
(ROOT/'artifacts').mkdir(exist_ok=True)
(ROOT/'artifacts/package-check.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
