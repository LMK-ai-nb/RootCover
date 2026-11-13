"""Test a separate application against the real `moon package` archive.

No publish or registry download is performed. The workspace override points
only at the extracted archive, never at the developer's source checkout.
"""
from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess,sys,tempfile,zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.stdout.reconfigure(encoding='utf-8',errors='replace')
sys.stderr.reconfigure(encoding='utf-8',errors='replace')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--native',action='store_true');args=parser.parse_args()
    steps=[];report={'passed':False,'library_source':'extracted_moon_package','published':False,'registry_download':False}
    def run(cwd,*command):
        process=subprocess.run(command,cwd=cwd,capture_output=True,text=True,encoding='utf-8',errors='replace')
        steps.append({'command':list(command),'exit':process.returncode,'stdout':process.stdout,'stderr':process.stderr})
        if process.returncode:raise RuntimeError(' '.join(command)+'\n'+process.stdout+process.stderr)
        return process.stdout
    try:
        run(ROOT,'moon','package','--list')
        version=re.search(r'^version\s*=\s*"([^"]+)"',(ROOT/'moon.mod').read_text(encoding='utf-8'),re.M)[1]
        archive=ROOT/'_build/publish'/('LMK-ai-nb-rootcover-'+version+'.zip')
        (ROOT/'work').mkdir(exist_ok=True)
        sandbox=Path(tempfile.mkdtemp(prefix='package-consumer-',dir=ROOT/'work'))
        assert sandbox.resolve().is_relative_to((ROOT/'work').resolve())
        library=sandbox/'package';library.mkdir()
        with zipfile.ZipFile(archive) as z:
            assert z.testzip() is None
            for name in z.namelist():
                assert (library/name.replace('\\','/')).resolve().is_relative_to(library.resolve()),name
            z.extractall(library)
        assert (library/'moon.mod').is_file()
        assert not library.resolve().samefile(ROOT)
        consumer=sandbox/'consumer';consumer.mkdir()
        for name in ['moon.mod','moon.pkg','consumer_test.mbt']:
            shutil.copy2(ROOT/'tests/consumer'/name,consumer/name)
        manifest=(consumer/'moon.mod').read_text(encoding='utf-8')
        manifest=re.sub(r'LMK-ai-nb/rootcover@[^"\s]+','LMK-ai-nb/rootcover@'+version,manifest)
        (consumer/'moon.mod').write_text(manifest,encoding='utf-8')
        (sandbox/'moon.work').write_text('members = [\n  "./package",\n  "./consumer",\n]\n',encoding='utf-8')
        run(consumer,'moon','check','--target','all','--deny-warn')
        run(consumer,'moon','fmt','--check')
        targets=['wasm','wasm-gc','js']+(['native'] if args.native else [])
        results={}
        for target in targets:
            output=run(consumer,'moon','test','--package','verification/rootcover_consumer','--target',target,'--deny-warn')
            found=re.search(r'Total tests: (\d+), passed: (\d+), failed: (\d+)',output)
            assert found and tuple(map(int,found.groups()))==(5,5,0),output
            results[target]=5
        report.update({'passed':True,'module_version':version,'archive':archive.name,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'targets':results,'strict_all_target_static_check':True})
    finally:
        report['steps']=steps
        (ROOT/'artifacts').mkdir(exist_ok=True)
        (ROOT/'artifacts/package-consumer.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:value for key,value in report.items() if key!='steps'}),flush=True)

if __name__=='__main__':main()
