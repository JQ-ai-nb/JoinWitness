"""Real Chromium checks: dynamic plans, exact evidence exports, safe rendering."""
import json,pathlib,sys
from playwright.sync_api import sync_playwright
root=pathlib.Path(__file__).resolve().parent.parent
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    page=browser.new_page(viewport={"width":1440,"height":1040},device_scale_factor=1)
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto(sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:4175',wait_until='networkidle')
    assert page.locator('#output-count').inner_text()=='7'
    assert page.locator('#issue-count').inner_text()=='1'
    assert page.locator('#materialize').is_disabled()
    with page.expect_download() as d:page.locator('.export-case').click()
    case=json.loads(pathlib.Path(d.value.path()).read_text(encoding='utf-8'))
    assert len(case['left']['rows'])+len(case['right']['rows'])==3
    assert case['witness']['scope']=='constructive'
    page.locator('.witness button').first.click()
    assert page.locator('tr.highlight').count()==3
    page.locator('#toggle-plan').click()
    assert page.locator('#output-count').inner_text()=='4'
    assert page.locator('#issue-count').inner_text()=='0'
    assert page.locator('#safe-status').inner_text()=='契约通过'
    page.locator('#materialize').click()
    assert page.locator('#pairs tbody tr').count()==4
    page.locator('[data-file="key-swap.json"]').click()
    page.wait_for_function("document.querySelector('#input').value.includes('migration_source')")
    assert page.locator('#output-count').inner_text()=='2'
    assert page.locator('.pair-stat strong').all_inner_texts()==['0','2','2']
    page.locator('[data-file="coverage-gap.json"]').click()
    page.wait_for_function("document.querySelector('#input').value.includes('device_registry')")
    assert page.locator('#missing-count').inner_text()=='3'
    assert page.locator('.export-case').count()==0
    assert page.locator('#toggle-plan').is_disabled()
    page.locator('details').evaluate('e=>e.open=true')
    source=json.loads((root/'examples/tenant-collision.json').read_text(encoding='utf-8'))
    source['left']['rows'][0]['id']='<img src=x onerror=alert(1)> 🔧'
    source['left']['rows'][0]['values'][1]='<script>alert(1)</script>'
    page.locator('#input').fill(json.dumps(source,ensure_ascii=False));page.locator('#inspect').click()
    assert '<img src=x onerror=alert(1)>' in page.locator('#left-body').inner_text()
    assert page.locator('#left-body img').count()==0
    assert page.locator('#left-body script').count()==0
    page.locator('#input').fill('{"schema_version":1,"schema_version":1}')
    page.locator('#inspect').click()
    assert page.locator('#error').is_visible()
    assert page.locator('#output-count').inner_text()=='—'
    assert page.locator('#export-report').is_disabled()
    assert page.locator('#left-body tr').count()==0
    page.reload(wait_until='networkidle')
    artifacts=root/'artifacts';artifacts.mkdir(exist_ok=True)
    page.screenshot(path=str(artifacts/'desktop.png'),full_page=True)
    page.set_viewport_size({'width':390,'height':844})
    page.reload(wait_until='networkidle')
    assert page.evaluate('document.documentElement.scrollWidth')==390
    page.locator('#toggle-plan').click()
    assert page.locator('#output-count').inner_text()=='4'
    page.screenshot(path=str(artifacts/'mobile.png'),full_page=True)
    assert not errors,errors
    browser.close()
    print('Browser checks passed: plan switching, constructive export, coverage, pair diff, XSS and mobile.')
