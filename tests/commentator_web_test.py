"""Normal exported startup, real synthetic Web Audio and three one-minute levels."""
import argparse,io,json,time
from pathlib import Path
from PIL import Image,ImageChops
from playwright.sync_api import sync_playwright
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--url',default='http://127.0.0.1:8765/');p.add_argument('--output',default='/workspace/artifacts/matryoshka-commentator');args=p.parse_args()
out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
levels=json.loads(Path('data/config/commentator_levels.json').read_text())['levels']
INIT=r'''
window.__mode='denied';window.__requests=0;window.__streams=[];window.__round=0;window.__start=Infinity;window.__delay=0;window.__monitor=0;window.__speech=false;
const connect=AudioNode.prototype.connect;AudioNode.prototype.connect=function(target,...rest){if(this instanceof MediaStreamAudioSourceNode && target===this.context.destination)window.__monitor++;return connect.call(this,target,...rest)};
let wasActive=false;
setInterval(()=>{const active=window.MatryoshkaMic?.status==='active';if(active&&!wasActive)window.__start=performance.now()+window.__delay;wasActive=active},5);
async function synthetic(){
 const context=new AudioContext();await context.resume();const oscillator=context.createOscillator();const gain=context.createGain();const destination=context.createMediaStreamDestination();oscillator.connect(gain);gain.connect(destination);gain.gain.value=0;oscillator.start();window.__streams.push(destination.stream);
 setInterval(()=>{let normalized=0;const t=(performance.now()-window.__start)/1000;const data=window.__levels[window.__round];if(window.__speech && data && t>=0 && t<60){const turn=data.turns.find(x=>t>=x.start_sec&&t<x.end_sec);if(turn?.speaker==='host')normalized=1;else{const word=turn?.words?.find(w=>t>=w.start_sec&&t<w.end_sec);if(word){const phase=(t-word.start_sec)/(word.end_sec-word.start_sec);normalized=phase>.04&&phase<.80?(word.emphasis ? .72 : .40):.14}}}gain.gain.value=normalized>0?Math.SQRT2*(.0054+.0946*normalized):0},10);
 return destination.stream;
}
navigator.mediaDevices.getUserMedia=async()=>{window.__requests++;if(window.__mode==='denied')throw new DOMException('Synthetic denial','NotAllowedError');if(window.__mode==='pending')return new Promise(resolve=>window.__late=async()=>resolve(await synthetic()));return synthetic()};
'''
with sync_playwright() as pw:
    browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
    context=browser.new_context(viewport={'width':1280,'height':720});context.add_init_script('window.__levels='+json.dumps(levels)+';'+INIT)
    page=context.new_page();messages=[];errors=[];requests=[]
    page.on('console',lambda m:messages.append(m.type+': '+m.text));page.on('pageerror',lambda e:errors.append(str(e)));page.on('request',lambda r:requests.append({'url':r.url,'method':r.method}))
    page.goto(args.url,wait_until='domcontentloaded');page.wait_for_function("document.querySelector('canvas')?.width>0",timeout=60000);page.wait_for_timeout(1400)
    page.mouse.click(1005,360);page.wait_for_timeout(650);page.screenshot(path=str(out/'normal-intro.png'))
    assert page.evaluate('window.__requests')==0,'Intro requested microphone'
    page.mouse.click(640,495);page.wait_for_function("window.MatryoshkaMic?.status==='denied'");page.wait_for_timeout(400);page.screenshot(path=str(out/'normal-denied.png'))
    page.evaluate("window.__mode='synthetic';window.__speech=true;window.__delay=0")
    page.mouse.click(640,436);page.wait_for_function("window.MatryoshkaMic?.status==='active'",timeout=15000)
    page.wait_for_timeout(6200);page.screenshot(path=str(out/'normal-player.png'))
    results=[];started=time.monotonic()
    for number in range(1,4):
        wait_ms=55000 if number==1 else 61000
        page.wait_for_timeout(30000);page.wait_for_timeout(wait_ms-30000)
        png=page.screenshot(path=str(out/f'normal-result-{number}.png'));actual=Image.open(io.BytesIO(png)).convert('RGB')
        if number<3:
            assert actual.getpixel((260,190))==(250,246,237),'Intermediate popup absent'
            assert actual.getpixel((874,480))==(250,246,237),f'Rhythmic synthetic voice did not pass level {number}'
        else:
            expected=Image.open(out/'final.png').convert('RGB')
            diff=ImageChops.difference(actual.crop((180,130,1100,205)),expected.crop((180,130,1100,205)))
            assert sum(max(px)>20 for px in diff.get_flattened_data())<12,'Third level did not reach successful campaign final'
        results.append({'level':number,'result':'pass','duration_sec':60});print(f'Commentator browser: level {number} passed',flush=True)
        if number<3:
            page.evaluate('(i)=>{window.__round=i;window.__start=performance.now()+180}',number)
            page.mouse.click(874,495)
    assert page.evaluate('window.__requests')==2,'Next opened another microphone session'
    assert page.evaluate('window.__monitor')==0,'Microphone was connected to speakers'
    page.set_viewport_size({'width':1024,'height':768});page.wait_for_timeout(400);page.screenshot(path=str(out/'normal-final-4x3.png'))
    page.set_viewport_size({'width':1280,'height':720});page.wait_for_timeout(200)
    page.mouse.click(1190,49);page.wait_for_timeout(650);page.wait_for_function("!window.MatryoshkaMic && window.__streams.every(s=>s.getTracks().every(t=>t.readyState==='ended'))")
    page.evaluate("window.__mode='pending'");page.mouse.click(1005,360);page.wait_for_timeout(650);page.mouse.click(640,495);page.wait_for_function('!!window.__late')
    page.mouse.click(1190,49);page.wait_for_timeout(650);page.evaluate('window.__late()');page.wait_for_function("!window.MatryoshkaMic && window.__streams.every(s=>s.getTracks().every(t=>t.readyState==='ended'))")
    assert all(r['method']=='GET' for r in requests),'Unexpected upload/write request'
    bad=[m for m in messages if 'SCRIPT ERROR' in m or m.startswith('error: ERROR:')];assert not errors and not bad,errors+bad
    report={'result':'passed','physical_microphone_tested':False,'input':'Synthetic live MediaStream through unchanged Web Audio bridge','results':results,'elapsed_after_first_player_sec':time.monotonic()-started,'errors':errors,'console':messages,'requests':requests}
    browser.close()
(out/'commentator-browser-log.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('COMMENTATOR BROWSER PASS: three real-time levels, denied/retry, one microphone, global Reset and late grant cleanup; no monitoring or upload')
