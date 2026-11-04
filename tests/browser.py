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
    expect(page.locator('#status')).to_have_text('区域已解析');expect(page.locator('#root-count')).to_have_text('2')
    page.get_by_role('button',name='体验预算耗尽').click();expect(page.locator('#status')).to_have_text('仍有未决');expect(page.locator('#unknown-count')).to_have_text('2')
    page.locator('[data-case="calibration"]').click();expect(page.locator('#root-count')).to_have_text('3')
    page.locator('#branch').click();expect(page.locator('#root-count')).to_have_text('1')
    with page.expect_download() as event:page.locator('#download').click()
    download=event.value;dest=ROOT/'artifacts/browser-report.json';download.save_as(dest)
    report=json.loads(dest.read_text(encoding='utf-8'));assert report['request']['box']==[[0,1]];assert report['result']['root_count']==1
    page.locator('[data-case="equilibrium"]').click();expect(page.locator('#status')).to_have_text('区域已解析');expect(page.locator('#root-count')).to_have_text('1')
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
    (ROOT/'docs/assets').mkdir(parents=True,exist_ok=True)
    page.screenshot(path=str(ROOT/'docs/assets/workbench.png'),full_page=True)
    page.set_viewport_size({'width':390,'height':844})
    assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
    page.screenshot(path=str(ROOT/'artifacts/mobile.png'),full_page=True)
    assert not errors,errors
    browser.close()
print('Chromium: geometry, budget, branches, equilibrium, export, duplicate JSON, injection and 390px layout passed.')
