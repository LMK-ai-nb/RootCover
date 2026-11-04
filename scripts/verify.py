"""Record actual commands and outputs; never convert a failed check to success."""
from pathlib import Path
import argparse,json,os,socket,subprocess,sys,time,urllib.request
sys.stdout.reconfigure(encoding="utf-8",errors="replace")
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--native',action='store_true');parser.add_argument('--browser',action='store_true');args=parser.parse_args()
    steps=[];server=None;ok=False
    def run(*cmd):
        start=time.perf_counter();p=subprocess.run(cmd,cwd=ROOT,text=True,encoding='utf-8',errors='replace',capture_output=True)
        steps.append({'command':list(cmd),'exit':p.returncode,'seconds':round(time.perf_counter()-start,4),'stdout':p.stdout,'stderr':p.stderr})
        print(' '.join(cmd),'=>',p.returncode,flush=True)
        if p.returncode==0 and (cmd[:2]==('moon','test') or cmd[:2]==('moon','version') or cmd[-1]=='tests/oracle.py'):print(p.stdout.strip(),flush=True)
        if p.returncode:print(p.stdout+p.stderr);raise RuntimeError('check failed')
    try:
        run('moon','version','--all');run('moon','check','--target','all','--deny-warn')
        targets=['wasm','wasm-gc','js']+(['native'] if args.native else [])
        for target in targets:
            run('moon','test','--target',target,'--deny-warn');run('moon','build','--target',target,'--deny-warn')
        run('moon','fmt','--check');run('moon','info');run('moon','run','cmd/demo')
        run('node','scripts/build.mjs');run('node','--test','tests/cli.test.mjs')
        run('moon','build','tests/probe','--target','js','--release','--deny-warn');run(sys.executable,'tests/oracle.py')
        run(sys.executable,'tests/paving_oracle.py')
        run(sys.executable,'scripts/package_check.py')
        if args.browser:
            with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
            env=os.environ.copy();env['PORT']=str(port)
            server=subprocess.Popen(['node','scripts/serve.mjs'],cwd=ROOT,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            for _ in range(70):
                try:
                    with urllib.request.urlopen(f'http://127.0.0.1:{port}',timeout=1):break
                except OSError:time.sleep(0.1)
            run(sys.executable,'tests/browser.py',f'http://127.0.0.1:{port}')
        ok=True
    finally:
        if server:server.terminate();server.wait(timeout=10)
        (ROOT/'artifacts').mkdir(exist_ok=True)
        (ROOT/'artifacts/validation.json').write_text(json.dumps({'passed':ok,'native_requested':args.native,'steps':steps},ensure_ascii=False,indent=2),encoding='utf-8')
    return 0 if ok else 1
if __name__=='__main__':raise SystemExit(main())
