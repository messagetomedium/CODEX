"""Optional Chromium smoke test. Serve build/web first; requires Python Playwright."""
from pathlib import Path
import argparse
import json
from playwright.sync_api import sync_playwright

parser=argparse.ArgumentParser()
parser.add_argument('--url',default='http://127.0.0.1:8765')
parser.add_argument('--output',default='build/browser-checks')
parser.add_argument('--browser',default='/usr/bin/chromium')
args=parser.parse_args()
out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
messages=[]; errors=[]; requests=[]; responses=[]
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path=args.browser,headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
 context=browser.new_context(viewport={'width':1280,'height':720},device_scale_factor=1)
 context.add_init_script('''window.micRequests=0;
 if(navigator.mediaDevices) navigator.mediaDevices.getUserMedia=()=>{window.micRequests++;return Promise.reject(new Error('Task 1 must not request microphone'));};''')
 page=context.new_page()
 page.on('console',lambda m: messages.append(m.type+': '+m.text))
 page.on('pageerror',lambda e: errors.append(str(e)))
 page.on('request',lambda r:requests.append(r.url))
 page.on('response',lambda r:responses.append({'url':r.url,'status':r.status}))
 page.goto(args.url,wait_until='networkidle')
 page.wait_for_function("!document.getElementById('status') || document.getElementById('status').style.display==='none'",timeout=60000)
 page.wait_for_timeout(1500)
 menu=page.screenshot(path=str(out/'menu.png'))
 page.mouse.click(640,360);page.mouse.move(0,0);page.wait_for_timeout(500)
 assert page.screenshot()==menu,'Disabled stands card navigated'
 page.mouse.click(1005,360);page.mouse.move(0,0);page.wait_for_timeout(500)
 assert page.screenshot()==menu,'Disabled commentator card navigated'
 page.mouse.click(275,360);page.mouse.move(0,0);page.wait_for_timeout(800)
 intro=page.screenshot(path=str(out/'intro.png'))
 assert intro!=menu,'Goal card did not open level'
 page.mouse.click(640,495);page.mouse.move(0,0);page.wait_for_timeout(700)
 diagnostic=page.screenshot(path=str(out/'after-start.png'))
 assert diagnostic!=intro and diagnostic!=menu,'Start did not replace popup'
 assert page.evaluate('window.micRequests')==0,'Unexpected microphone request'
 assert page.locator('audio,video').count()==0
 page.mouse.click(1190,49);page.mouse.move(0,0);page.wait_for_timeout(700)
 assert page.screenshot()==menu,'Reset did not restore menu'
 page.mouse.click(275,360);page.mouse.move(0,0);page.wait_for_timeout(700)
 assert page.screenshot()==intro,'Returning from menu must show intro'
 page.mouse.click(1190,49);page.mouse.move(0,0);page.wait_for_timeout(700)
 assert page.screenshot()==menu,'Reset from intro failed'
 page.set_viewport_size({'width':1024,'height':768});page.wait_for_timeout(700)
 page.screenshot(path=str(out/'menu-4x3.png'))
 canvas=page.locator('canvas').bounding_box()
 print('Canvas at 1024x768:',canvas)
 assert not errors,errors
 assert all(r['status']<400 or r['url'].endswith('/favicon.ico') for r in responses),responses
 bad=[m for m in messages if 'SCRIPT ERROR' in m or (m.startswith('error:') and '404' not in m)]
 assert not bad,bad
 print('BROWSER CHECKS PASSED: menu, two disabled cards, level + intro, start, no mic, reset from both states, re-entry, resize')
 print('Browser errors: none; optional favicon.ico returns 404; SwiftShader ReadPixels warnings recorded.')
 (out/'browser-log.json').write_text(json.dumps({'console':messages,'errors':errors,'requests':requests,'responses':responses,'result':'passed'},ensure_ascii=False,indent=2))
 browser.close()
