"""Real Chromium interactions against local or hosted demo."""
from pathlib import Path
import json,sys,os
from playwright.sync_api import sync_playwright,expect
ROOT=Path(__file__).resolve().parents[1]
(ROOT/'artifacts').mkdir(exist_ok=True)
SHOTS=ROOT/('docs/assets' if os.environ.get('ROOTCOVER_UPDATE_SCREENSHOTS')=='1' else 'artifacts')
SHOTS.mkdir(parents=True,exist_ok=True)
def launch(p):
    """Prefer Playwright's bundled Chromium; fall back to an installed Chrome/Edge."""
    try:
        return p.chromium.launch(headless=True)
    except Exception:
        last=None
        for channel in ('chrome','msedge'):
            try:
                return p.chromium.launch(headless=True, channel=channel)
            except Exception as error:
                last=error
        raise last
with sync_playwright() as p:
    browser=launch(p)
    page=browser.new_page(viewport={'width':1440,'height':1200});errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto(sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:4188')
    expect(page.locator('#status')).to_have_text('分辨率已达 · 有未决');expect(page.locator('#root-count')).to_have_text('15')
    page.locator('[data-case="geometry"]').click()
    expect(page.locator('#status')).to_have_text('区域已解析');expect(page.locator('#root-count')).to_have_text('2')
    page.get_by_role('button',name='体验预算耗尽').click();expect(page.locator('#status')).to_have_text('仍有未决');assert int(page.locator('#unknown-count').inner_text())>0
    page.locator('[data-case="calibration"]').click();expect(page.locator('#root-count')).to_have_text('3')
    page.locator('#branch').click();expect(page.locator('#root-count')).to_have_text('1')
    with page.expect_download() as event:page.locator('#download').click()
    download=event.value;dest=ROOT/'artifacts/browser-report.json';download.save_as(dest)
    report=json.loads(dest.read_text(encoding='utf-8'));assert report['request']['box']==[[0,1]];assert report['result']['root_count']==1
    page.locator('[data-case="equilibrium"]').click();expect(page.locator('#status')).to_have_text('区域已解析');expect(page.locator('#root-count')).to_have_text('1')
    page.locator('[data-case="noisy_localization"]').click()
    expect(page.locator('#primary-label')).to_have_text('已确认可行盒')
    expect(page.locator('#root-count')).to_have_text('17');expect(page.locator('#unknown-count')).to_have_text('38')
    expect(page.locator('#status')).to_have_text('分辨率已达 · 有未决')
    with page.expect_download() as event:page.locator('#download').click()
    event.value.save_as(ROOT/'artifacts/paving-browser-report.json')
    report=json.loads((ROOT/'artifacts/paving-browser-report.json').read_text())
    assert report['result']['mode']=='feasibility' and report['result']['complete'] is False
    assert len(report['request']['constraints'])==3 and 'root_count' not in report['result']
    page.locator('[data-case="calibration"]').click();expect(page.locator('#primary-label')).to_have_text('已确认唯一解')
    page.locator('#tolerance-band').click();expect(page.locator('#primary-label')).to_have_text('已确认可行盒')
    expect(page.locator('#root-count')).to_have_text('33');expect(page.locator('#unknown-count')).to_have_text('6')
    for sample in ['robot_workspace','thermal_parameters','mixed_process']:
        page.locator(f'[data-case="{sample}"]').click()
        expect(page.locator('#status')).to_have_text('分辨率已达 · 有未决')
        assert int(page.locator('#root-count').inner_text())>0
    assert page.locator('[data-case]').count()==12,'twelve demo cases expected'
    page.locator('[data-case="bratu25"]').click()
    expect(page.locator('#status')).to_have_text('区域已解析',timeout=30000)
    assert page.locator('#case-description').inner_text().strip()!='','description must not be empty'
    expect(page.locator('#root-count')).to_have_text('1')
    expect(page.locator('#primary-label')).to_have_text('已确认唯一解')
    with page.expect_download() as event:page.locator('#download').click()
    event.value.save_as(ROOT/'artifacts/bratu-browser-report.json')
    bratu=json.loads((ROOT/'artifacts/bratu-browser-report.json').read_text(encoding='utf-8'))
    assert bratu['result']['root_count']==1 and bratu['result']['complete'] is True
    page.locator('[data-case="design_window6"]').click()
    expect(page.locator('#status')).to_have_text('分辨率已达 · 有未决',timeout=30000)
    assert page.locator('#case-description').inner_text().strip()!='','description must not be empty'
    expect(page.locator('#root-count')).to_have_text('750')
    expect(page.locator('#unknown-count')).to_have_text('1798')
    with page.expect_download() as event:page.locator('#download').click()
    event.value.save_as(ROOT/'artifacts/design-window-browser-report.json')
    window=json.loads((ROOT/'artifacts/design-window-browser-report.json').read_text(encoding='utf-8'))
    assert window['result']['resolution_met'] is True and len(window['result']['inside'])==750
    assert len(window['result']['unresolved'])==1798
    page.locator('[data-case="mixed_process"]').click()
    expect(page.locator('#status')).to_have_text('分辨率已达 · 有未决')
    page.locator('#contractors').select_option('none')
    expect(page.locator('#status')).to_have_text('分辨率已达 · 有未决')
    assert json.loads(page.locator('#request').input_value())['contractors']=={'propagation':False,'newton':False}
    page.locator('#request').fill('{"version":1,"version":1}');page.locator('#run').click();expect(page.locator('#status')).to_have_text('输入无效')
    page.locator('[data-case="geometry"]').click();expect(page.locator('#root-count')).to_have_text('2')
    q=json.loads(page.locator('#request').input_value());q['variables'][0]='<img src=x onerror=alert(1)>'
    page.locator('#request').fill(json.dumps(q));page.locator('#run').click();expect(page.locator('#status')).to_have_text('输入无效');assert page.locator('img').count()==0
    page.locator('[data-case="geometry"]').click();expect(page.locator('#root-count')).to_have_text('2')
    # Hold one sample fetch, then release it after a newer sample completed.
    # This checks real out-of-order delivery without relying on arbitrary sleeps.
    page.evaluate("""()=>{window.__originalFetch=window.fetch;window.fetch=(input,...args)=>String(input).includes('calibration.json')?new Promise(resolve=>{window.__releaseSample=()=>window.__originalFetch(input,...args).then(resolve)}):window.__originalFetch(input,...args);document.querySelector('[data-case="calibration"]').click();document.querySelector('[data-case="geometry"]').click();}""")
    expect(page.locator('#status')).to_have_text('区域已解析');expect(page.locator('#root-count')).to_have_text('2')
    page.evaluate('async()=>{await window.__releaseSample();window.fetch=window.__originalFetch;await Promise.resolve();}')
    assert json.loads(page.locator('#request').input_value())['variables']==['x','y']
    expect(page.locator('#root-count')).to_have_text('2')
    # Cancellation invalidates the in-flight sample before its response arrives.
    before=page.locator('#request').input_value()
    page.evaluate("""()=>{window.__originalFetch=window.fetch;window.fetch=(input,...args)=>new Promise(resolve=>{window.__releaseSample=()=>window.__originalFetch(input,...args).then(resolve)});document.querySelector('[data-case="calibration"]').click();}""")
    page.locator('#cancel').click();expect(page.locator('#status')).to_have_text('已停止')
    page.evaluate('async()=>{await window.__releaseSample();window.fetch=window.__originalFetch;await Promise.resolve();}')
    assert page.locator('#request').input_value()==before
    expect(page.locator('#status')).to_have_text('已停止')
    page.locator('[data-case="geometry"]').click();expect(page.locator('#status')).to_have_text('区域已解析')
    page.locator('[data-case="robust_localization"]').click()
    expect(page.locator('#root-count')).to_have_text('15');expect(page.locator('#unknown-count')).to_have_text('38')
    expect(page.locator('#legend-main')).to_have_text('整盒满足约束组合')
    with page.expect_download() as event:page.locator('#download').click()
    event.value.save_as(ROOT/'artifacts/logical-browser-report.json')
    logical=json.loads((ROOT/'artifacts/logical-browser-report.json').read_text())
    assert logical['request']['formula']['all'][1]['at_least']['count']==3
    assert logical['result']['certificate_kind']=='positive_formula_interval_truth'
    page.locator('#search-strategy').select_option('dfs')
    expect(page.locator('#status')).to_have_text('分辨率已达 · 有未决')
    assert json.loads(page.locator('#raw').text_content())['search']['strategy']=='dfs'
    page.locator('[data-case="design_alternatives"]').click()
    expect(page.locator('#root-count')).to_have_text('184')
    page.locator('[data-case="scaled_parameters"]').click()
    expect(page.locator('#status')).to_have_text('分辨率已达 · 有未决')
    assert json.loads(page.locator('#raw').text_content())['search']['absolute_tolerances']==[.05,.000005]
    page.locator('[data-case="robust_localization"]').click()
    expect(page.locator('#root-count')).to_have_text('15')
    page.screenshot(path=str(SHOTS/'workbench.png'),full_page=True)
    page.set_viewport_size({'width':390,'height':844})
    assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
    page.screenshot(path=str(ROOT/'artifacts/mobile.png'),full_page=True)
    session_page=browser.new_page(viewport={'width':1440,'height':1100})
    session_page.on('pageerror',lambda e:errors.append(str(e)))
    base=(sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:4188').rstrip('/')
    session_page.goto(base+'/session.html')
    expect(session_page.locator('#session-status')).to_have_text('准备就绪')
    session_page.locator('#session-steps').fill('10');session_page.locator('#session-start').click()
    expect(session_page.locator('#session-status')).to_have_text('已暂停，可继续')
    expect(session_page.locator('#session-assessments')).to_have_text('10')
    with session_page.expect_download() as event:session_page.locator('#session-save').click()
    checkpoint_path=ROOT/'artifacts/browser-session-checkpoint.json';event.value.save_as(checkpoint_path)
    checkpoint=json.loads(checkpoint_path.read_text());assert len(checkpoint['events'])==10
    session_page.locator('#session-steps').fill('7');session_page.locator('#session-continue').click()
    expect(session_page.locator('#session-assessments')).to_have_text('17')
    session_page.reload();expect(session_page.locator('#session-status')).to_have_text('准备就绪')
    session_page.locator('#session-file').set_input_files(str(checkpoint_path))
    expect(session_page.locator('#session-status')).to_have_text('已暂停，可继续')
    expect(session_page.locator('#session-assessments')).to_have_text('10')
    tampered=json.loads(json.dumps(checkpoint));tampered['events'][0]={'kind':'inside'}
    original_request=session_page.locator('#session-request').input_value()
    tampered['request']=json.dumps(json.loads(original_request),separators=(',',':'))
    assert tampered['request']!=original_request
    tampered_path=ROOT/'artifacts/browser-tampered-checkpoint.json';tampered_path.write_text(json.dumps(tampered),encoding='utf-8')
    session_page.locator('#session-file').set_input_files(str(tampered_path))
    expect(session_page.locator('#session-status')).to_contain_text('checkpoint')
    expect(session_page.locator('#session-status')).to_contain_text('原进度仍保留')
    expect(session_page.locator('#session-assessments')).to_have_text('10')
    expect(session_page.locator('#session-request')).to_have_value(original_request)
    expect(session_page.locator('#session-save')).to_be_enabled()
    session_page.locator('#session-steps').fill('7')
    session_page.locator('#session-continue').click()
    expect(session_page.locator('#session-assessments')).to_have_text('17')
    session_page.locator('#session-steps').fill('100')
    # Hold the next worker message so stopping cannot race a fast computation.
    session_page.evaluate("""()=>{window.__sessionPost=Worker.prototype.postMessage;Worker.prototype.postMessage=function(data){window.__heldSession={worker:this,data}};document.querySelector('#session-continue').click();}""")
    expect(session_page.locator('#session-status')).to_have_text('正在计算')
    session_page.locator('#session-cancel').click()
    session_page.evaluate('()=>{Worker.prototype.postMessage=window.__sessionPost;}')
    expect(session_page.locator('#session-status')).to_have_text('已停止，本步前的进度仍保留')
    expect(session_page.locator('#session-assessments')).to_have_text('17')
    session_page.locator('#session-continue').click()
    expect(session_page.locator('#session-assessments')).to_have_text('117')
    with session_page.expect_download() as event:session_page.locator('#session-report').click()
    event.value.save_as(ROOT/'artifacts/browser-session-result.json')
    saved=json.loads((ROOT/'artifacts/browser-session-result.json').read_text())
    assert saved['result']['session']['coverage']=='verified_from_initial_box'
    assert saved['result']['stats']['assessments']==117
    session_page.screenshot(path=str(SHOTS/'session.png'),full_page=True)
    session_page.set_viewport_size({'width':390,'height':844})
    assert session_page.evaluate('document.documentElement.scrollWidth<=innerWidth')
    session_page.screenshot(path=str(ROOT/'artifacts/session-mobile.png'),full_page=True)
    session_page.locator('#session-example').select_option('design_window6')
    expect(session_page.locator('#session-status')).to_have_text('准备就绪')
    assert len(json.loads(session_page.locator('#session-request').input_value())['variables']) == 6
    session_page.locator('#session-steps').fill('700')
    session_page.locator('#session-start').click()
    expect(session_page.locator('#session-assessments')).to_have_text('700')
    session_page.locator('#session-steps').fill('20000')
    session_page.locator('#session-continue').click()
    expect(session_page.locator('#session-assessments')).to_have_text('5191')
    expect(session_page.locator('#session-inside')).to_have_text('750')
    expect(session_page.locator('#session-unknown')).to_have_text('1798')
    expect(session_page.locator('#session-pending')).to_have_text('0')
    retry_page=browser.new_page(viewport={'width':900,'height':900})
    retry_page.on('pageerror',lambda e:errors.append(str(e)))
    def block_worker(route):route.abort('failed')
    retry_page.route('**/worker.js',block_worker)
    retry_page.goto(base+'/')
    expect(retry_page.locator('#status')).to_have_text('求解线程异常，请重试')
    expect(retry_page.locator('#run')).to_be_enabled()
    expect(retry_page.locator('#download')).to_be_disabled()
    retry_page.unroute('**/worker.js',block_worker)
    retry_page.locator('#run').click()
    expect(retry_page.locator('#status')).to_have_text('分辨率已达 · 有未决')
    expect(retry_page.locator('#root-count')).to_have_text('15')
    expect(retry_page.locator('#download')).to_be_enabled()
    assert not errors,errors
    (ROOT/'artifacts/browser-check.json').write_text(json.dumps({'passed':True,'base_url':base,'workbenches':2,'worker_load_failure_retry':True,'checkpoint_save_load_continue_cancel_export':True,'checkpoint_rejection_preserves_progress':True,'six_variable_design':True,'viewport_widths':[1440,390],'uncaught_errors':errors,'documentation_screenshots_updated':SHOTS==ROOT/'docs/assets'},indent=2)+'\n',encoding='utf-8')
    browser.close()
print('Chromium: both workbenches passed, including worker-load failure and retry, nonlinear/formula examples, checkpoint save/reload/verification/cancellation/export, the six-variable design model, duplicate JSON, injection, load races and 390px layouts.')
