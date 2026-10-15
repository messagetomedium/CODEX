"""Render the real booth, karaoke and shared popups through a local-only fixture."""
import argparse,json,re
from pathlib import Path
from playwright.sync_api import sync_playwright
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--url',default='http://127.0.0.1:8765/index.html')
p.add_argument('--output',default='/workspace/artifacts/matryoshka-commentator')
p.add_argument('--modes',nargs='+')
args=p.parse_args();out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
modes=args.modes or ['intro','host','player','level-2','level-3','result','loss','final']
with sync_playwright() as pw:
    browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
    context=browser.new_context(viewport={'width':1280,'height':720})
    context.add_init_script("const log=console.log.bind(console);console.log=(...x)=>{if(x.join(' ').includes('COMMENTATOR REVIEW READY:'))window.__ready=true;log(...x)};navigator.mediaDevices.getUserMedia=()=>{throw Error('Review fixture requested microphone')};")
    report=[]
    for mode in modes:
        page=context.new_page();messages=[];errors=[]
        page.on('console',lambda m:messages.append(m.type+': '+m.text));page.on('pageerror',lambda e:errors.append(str(e)))
        def route_html(route):
            response=route.fetch();body=response.text();match=re.search(r'const GODOT_CONFIG = (\{[^\n]+\});',body);assert match
            cfg=json.loads(match.group(1));cfg['args']=['--script','res://tests/commentator_visual_review.gd','--','--commentator-'+mode]
            route.fulfill(response=response,body=body[:match.start(1)]+json.dumps(cfg)+body[match.end(1):])
        page.route('**/index.html',route_html)
        page.goto(args.url,wait_until='domcontentloaded');page.wait_for_function('window.__ready===true',timeout=60000)
        page.screenshot(path=str(out/(mode+'.png')))
        if mode in ['intro','level-3','final']:
            page.set_viewport_size({'width':1024,'height':768});page.wait_for_timeout(400);page.screenshot(path=str(out/(mode+'-4x3.png')))
        bad=[m for m in messages if 'SCRIPT ERROR' in m or m.startswith('error: ERROR:')]
        assert not errors and not bad,errors+bad
        report.append({'mode':mode,'result':'passed','console':messages,'errors':errors});page.close()
    browser.close()
(out/'commentator-visual-log.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('COMMENTATOR VISUAL PASS: '+', '.join(modes)+'; local synthetic fixture')
