"""Real Chromium interactions against local or hosted demo."""
from pathlib import Path
import json,sys
from playwright.sync_api import sync_playwright,expect
ROOT=Path(__file__).resolve().parents[1]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
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
    (ROOT/'docs/assets').mkdir(parents=True,exist_ok=True)
    page.screenshot(path=str(ROOT/'docs/assets/workbench.png'),full_page=True)
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
    tampered_path=ROOT/'artifacts/browser-tampered-checkpoint.json';tampered_path.write_text(json.dumps(tampered),encoding='utf-8')
    session_page.locator('#session-file').set_input_files(str(tampered_path))
    expect(session_page.locator('#session-continue')).to_be_disabled()
    expect(session_page.locator('#session-assessments')).to_have_text('—')
    expect(session_page.locator('#session-status')).to_contain_text('checkpoint')
    session_page.locator('#session-file').set_input_files(str(checkpoint_path))
    expect(session_page.locator('#session-assessments')).to_have_text('10')
    # Hold the next worker message so stopping cannot race a fast computation.
    session_page.evaluate("""()=>{window.__sessionPost=Worker.prototype.postMessage;Worker.prototype.postMessage=function(data){window.__heldSession={worker:this,data}};document.querySelector('#session-continue').click();}""")
    expect(session_page.locator('#session-status')).to_have_text('正在计算')
    session_page.locator('#session-cancel').click()
    session_page.evaluate('()=>{Worker.prototype.postMessage=window.__sessionPost;}')
    expect(session_page.locator('#session-status')).to_have_text('已停止，本步前的进度仍保留')
    expect(session_page.locator('#session-assessments')).to_have_text('10')
    session_page.locator('#session-continue').click()
    expect(session_page.locator('#session-assessments')).to_have_text('110')
    with session_page.expect_download() as event:session_page.locator('#session-report').click()
    event.value.save_as(ROOT/'artifacts/browser-session-result.json')
    saved=json.loads((ROOT/'artifacts/browser-session-result.json').read_text())
    assert saved['result']['session']['coverage']=='verified_from_initial_box'
    assert saved['result']['stats']['assessments']==110
    session_page.screenshot(path=str(ROOT/'docs/assets/session.png'),full_page=True)
    session_page.set_viewport_size({'width':390,'height':844})
    assert session_page.evaluate('document.documentElement.scrollWidth<=innerWidth')
    session_page.screenshot(path=str(ROOT/'artifacts/session-mobile.png'),full_page=True)
    assert not errors,errors
    browser.close()
print('Chromium: both workbenches passed, including nonlinear/formula examples, checkpoint save/reload/verification/cancellation/export, duplicate JSON, injection, load races and 390px layouts.')
