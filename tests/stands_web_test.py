"""Normal Web startup: live synthetic MediaStream, real-time three-round play and audio output checks."""
import argparse
import io
import json
import time
from pathlib import Path
from PIL import Image, ImageChops
from playwright.sync_api import sync_playwright

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url',default='http://127.0.0.1:8765/')
parser.add_argument('--output',default='/workspace/artifacts/matryoshka-stands')
args=parser.parse_args();out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
INIT=r'''
window.__micMode='denied';window.__micRequests=0;window.__streams=[];
window.__crowd=[];window.__turnStarts=0;window.__turnStops=0;window.__opponentActive=false;window.__playerAt=0;window.__round=1;
window.__monitors=[];window.__micSpeakerConnections=0;
const connect=AudioNode.prototype.connect;
AudioNode.prototype.connect=function(target,...rest){
  if(this instanceof MediaStreamAudioSourceNode && target===this.context.destination)window.__micSpeakerConnections++;
  if(target===this.context.destination){
    const analyser=this.context.createAnalyser();analyser.fftSize=2048;
    connect.call(analyser,target);window.__monitors.push(analyser);
    return connect.call(this,analyser,...rest);
  }
  return connect.call(this,target,...rest);
};
window.__outputRms=()=>Math.max(0,...window.__monitors.map(a=>{
  const x=new Float32Array(a.fftSize);a.getFloatTimeDomainData(x);
  return Math.sqrt(x.reduce((s,v)=>s+v*v,0)/x.length);
}));
const start=AudioBufferSourceNode.prototype.start;
const stop=AudioBufferSourceNode.prototype.stop;
AudioBufferSourceNode.prototype.start=function(...x){
  const result=start.apply(this,x);
  if(this.buffer && this.buffer.duration>2.39 && this.buffer.duration<2.41){
    this.__crowdLog={at:performance.now(),duration:this.buffer.duration,loop:this.loop,stopped:null};
    const entry=this.__crowdLog;this.addEventListener('ended',()=>entry.ended=performance.now());
    window.__crowd.push(entry);if(!window.__opponentActive)window.__turnStarts++;window.__opponentActive=true;
  }
  return result;
};
AudioBufferSourceNode.prototype.stop=function(...x){
  if(this.__crowdLog && this.__crowdLog.stopped===null){
    this.__crowdLog.stopped=performance.now();window.__turnStops++;window.__opponentActive=false;window.__playerAt=performance.now();
  }
  return stop.apply(this,x);
};
async function syntheticStream(){
  const context=new AudioContext();await context.resume();
  const oscillator=context.createOscillator();oscillator.frequency.value=440;
  const gain=context.createGain();gain.gain.value=0;
  const destination=context.createMediaStreamDestination();
  oscillator.connect(gain);gain.connect(destination);oscillator.start();
  window.__streams.push(destination.stream);
  setInterval(()=>{
    const t=(performance.now()-window.__playerAt)/1000;
    gain.gain.value=window.__opponentActive ? .18 : ((t<.3 || (t-.3)%.45>.35) ? 0 : .18);
  },10);
  return destination.stream;
}
navigator.mediaDevices.getUserMedia=async()=>{
  window.__micRequests++;
  if(window.__micMode==='denied')throw new DOMException('Synthetic denial','NotAllowedError');
  if(window.__micMode==='pending')return new Promise(resolve=>{window.__releasePending=async()=>resolve(await syntheticStream())});
  return syntheticStream();
};
'''

def final_visible(page):
    im=Image.open(io.BytesIO(page.screenshot())).convert('RGB')
    return im.getpixel((260,190))==(250,246,237)

with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
    context=browser.new_context(viewport={'width':1280,'height':720})
    context.add_init_script(INIT)
    page=context.new_page();messages=[];errors=[];requests=[]
    page.on('console',lambda m:messages.append(m.type+': '+m.text))
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('request',lambda r:requests.append({'url':r.url,'method':r.method}))
    page.goto(args.url,wait_until='domcontentloaded')
    page.wait_for_function("document.querySelector('canvas')?.width > 0",timeout=60000)
    page.wait_for_timeout(1400)
    page.mouse.click(640,360);page.wait_for_timeout(750)
    page.screenshot(path=str(out/'normal-intro.png'))
    assert page.evaluate('window.__micRequests')==0
    # Select blue team in the existing popup, then request microphone.
    page.mouse.click(510,454);page.wait_for_timeout(250)
    page.mouse.click(640,590)
    page.wait_for_function("window.MatryoshkaMic?.status==='denied'",timeout=15000)
    page.wait_for_timeout(500)
    assert page.evaluate('window.__crowd.length')==0,'Sound started before microphone readiness'
    page.screenshot(path=str(out/'normal-mic-denied.png'))
    page.evaluate("window.__micMode='synthetic'")
    page.mouse.click(640,436)
    page.wait_for_function("window.MatryoshkaMic?.status==='active'",timeout=15000)
    page.wait_for_function('window.__opponentActive',timeout=10000)
    page.wait_for_function('window.__outputRms()>.0001',timeout=10000)
    page.wait_for_timeout(2650)
    assert page.evaluate('window.__crowd.length>=2 && window.__outputRms()>.0001'),'Opponent WAV did not continue audibly beyond its first loop'
    # Godot 4.5 Web loops samples by restarting sources on ended, rather than source.loop.
    page.screenshot(path=str(out/'normal-opponent.png'))
    page.wait_for_function('!window.__opponentActive',timeout=10000)
    page.wait_for_timeout(250)
    assert page.evaluate('window.__outputRms()')<.0001,'Opponent sound leaked into the player turn'
    assert page.evaluate('window.__micSpeakerConnections')==0,'Microphone was monitored to speakers'
    page.screenshot(path=str(out/'normal-player.png'))
    started=time.monotonic()
    results=[]
    for number in range(1,4):
        for attempt in range(1,4):
            # Readback screenshots can block a software WebGL renderer and distort
            # short voice bursts. Let normal frames run, then inspect the result.
            wait_ms=55800 if number==1 and attempt==1 else 60800
            page.wait_for_timeout(30000)
            page.wait_for_timeout(wait_ms-30000)
            assert final_visible(page),f'Round {number} did not finish at its deadline'
            assert not page.evaluate('window.__opponentActive'),'Round result left crowd audio running'
            page.wait_for_timeout(200)
            assert page.evaluate('window.__outputRms()')<.0001,'Audio output remained active under the result popup'
            page.screenshot(path=str(out/f'normal-result-{number}.png'))
            actual=Image.open(io.BytesIO(page.screenshot())).convert('RGB')
            if number<3:
                won=actual.getpixel((874,480))==(250,246,237)
            else:
                expected=Image.open(out/'game-win.png').convert('RGB')
                difference=ImageChops.difference(actual.crop((270,190,1010,260)),expected.crop((270,190,1010,260)))
                won=sum(max(pixel)>20 for pixel in difference.get_flattened_data())<10
            if won:break
            assert attempt<3,f'Synthetic voice did not win round {number} after retries'
            page.mouse.click(407,495)
            page.wait_for_function('window.__opponentActive',timeout=10000)
            print(f'Stands round {number}: exercised Retry after a completed non-win',flush=True)
        results.append({'round':number,'result':'win','attempts':attempt,'audio_off_at_result':True})
        print(f'Stands round {number}: win, opponent audio stopped',flush=True)
        if number<3:
            page.evaluate('(n)=>window.__round=n',number+1)
            page.mouse.click(874,495)
            page.wait_for_function('window.__opponentActive',timeout=10000)
            page.wait_for_timeout(250)
            assert not final_visible(page),'Next did not dismiss the common result popup'
            page.screenshot(path=str(out/f'normal-level-{number+1}.png'))
    # No new microphone request during any round transition.
    assert page.evaluate('window.__micRequests')==2,'Next created a second microphone session'
    expected_turns=6*sum(result['attempts'] for result in results)
    assert page.evaluate('window.__turnStarts')==expected_turns and page.evaluate('window.__turnStops')==expected_turns,'Each played round needs six audible opponent turns'
    assert page.evaluate('window.__crowd.every(x=>x.stopped!==null || x.ended)'),'A looping opponent source was not stopped'
    page.set_viewport_size({'width':1024,'height':768});page.wait_for_timeout(400)
    page.screenshot(path=str(out/'normal-game-final-4x3.png'))
    page.set_viewport_size({'width':1280,'height':720});page.wait_for_timeout(300)
    page.mouse.click(1190,49);page.wait_for_timeout(650)
    page.wait_for_function("!window.MatryoshkaMic && window.__streams.every(s=>s.getTracks().every(t=>t.readyState==='ended'))")
    assert not page.evaluate('window.__opponentActive')
    # Reset while permission is pending must cancel a late grant.
    page.evaluate("window.__micMode='pending'")
    page.mouse.click(640,360);page.wait_for_timeout(650);page.mouse.click(640,590)
    page.wait_for_function('!!window.__releasePending')
    page.mouse.click(1190,49);page.wait_for_timeout(650)
    page.evaluate('window.__releasePending()')
    page.wait_for_function("!window.MatryoshkaMic && window.__streams.every(s=>s.getTracks().every(t=>t.readyState==='ended'))")
    page.screenshot(path=str(out/'normal-reset-menu.png'))
    assert all(x['method']=='GET' for x in requests),'Unexpected voice upload or write request'
    bad=[x for x in messages if 'SCRIPT ERROR' in x or x.startswith('error: ERROR:')]
    assert not errors and not bad,errors+bad
    report={'result':'passed','physical_microphone_tested':False,'input':'Synthetic live Web Audio MediaStream through the normal microphone bridge','real_time_three_rounds':True,'play_seconds_after_first_player_turn':time.monotonic()-started,'results':results,'mic_requests':page.evaluate('window.__micRequests'),'crowd_sources':page.evaluate('window.__crowd'),'errors':errors,'console':messages,'requests':requests}
    browser.close()
(out/'stands-browser-log.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('STANDS BROWSER PASS: three real-time rounds, synthetic shared mic, actual audible opponent loop / silent player turns, Next, denial/retry, Reset and late grant cleanup; no physical microphone')
