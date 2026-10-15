"""Web microphone integration with Chromium's synthetic capture, never a real mic."""
import argparse
import io
import json
import math
import random
import struct
import wave
from pathlib import Path

from PIL import Image
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url', default='http://127.0.0.1:8765')
parser.add_argument('--output', default='/workspace/artifacts/matryoshka-task-2')
parser.add_argument('--browser', default='/usr/bin/chromium')
args = parser.parse_args()
out = Path(args.output).resolve()
out.mkdir(parents=True, exist_ok=True)
# An artificial input fixture only; no recorded speech or playable app asset.
fixture = out / 'synthetic-input.wav'
with wave.open(str(fixture), 'wb') as audio:
    audio.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
    samples = bytearray()
    rng = random.Random(20261015)
    for i in range(480000):
        t = i / 48000
        envelope = 0.35 + 0.65 * abs(math.sin(2 * math.pi * 3.1 * t))
        pitch = 170 + 25 * math.sin(2 * math.pi * 0.7 * t)
        tone = math.sin(2 * math.pi * pitch * t) + 0.35 * math.sin(4 * math.pi * pitch * t)
        value = 0 if t < 1 or t >= 8.2 else 0.18 * envelope * tone + rng.uniform(-0.005, 0.005)
        samples.extend(struct.pack('<h', int(32767 * value)))
    audio.writeframes(samples)

INIT = r'''
window.__micMode = 'real';
window.__micRequests = 0;
window.__micStreams = [];
window.__monitorConnections = 0;
const originalConnect = AudioNode.prototype.connect;
AudioNode.prototype.connect = function(destination, ...rest) {
  if (this instanceof MediaStreamAudioSourceNode && destination instanceof AudioDestinationNode) window.__monitorConnections++;
  return originalConnect.call(this, destination, ...rest);
};
const originalGetUserMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
navigator.mediaDevices.getUserMedia = async constraints => {
  window.__micRequests++;
  const errors = {'denied':'NotAllowedError','not-found':'NotFoundError','busy':'NotReadableError'};
  if (errors[window.__micMode]) throw new DOMException('Synthetic browser error', errors[window.__micMode]);
  const stream = await originalGetUserMedia(constraints);
  window.__micStreams.push(stream);
  if (window.__micMode === 'pending') return new Promise(resolve => { window.__releasePending = () => resolve(stream); });
  return stream;
};
'''


def meter_fill(png):
    image = Image.open(io.BytesIO(png)).convert('RGB')
    return sum(1 for x in range(36, 267) for y in range(707, 711)
               if (lambda c: c[0] > 190 and c[1] > 150 and c[2] < 150)(image.getpixel((x, y))))


with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=args.browser, headless=True, args=[
        '--no-sandbox', '--enable-unsafe-swiftshader', '--disable-dev-shm-usage',
        '--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream',
        f'--use-file-for-fake-audio-capture={fixture}',
    ])
    context = browser.new_context(viewport={'width': 1280, 'height': 720}, device_scale_factor=1)
    context.add_init_script(INIT)
    page = context.new_page()
    messages, errors, requests = [], [], []
    page.on('console', lambda m: messages.append(m.type + ': ' + m.text))
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('request', lambda r: requests.append({'url': r.url, 'method': r.method}))

    def load(url=args.url):
        page.goto(url, wait_until='networkidle')
        page.wait_for_function("!document.getElementById('status') || document.getElementById('status').style.display==='none'", timeout=60000)
        page.mouse.move(0, 0)
        page.wait_for_timeout(800)

    def click(x, y, delay=500):
        page.mouse.click(x, y)
        page.mouse.move(0, 0)
        page.wait_for_timeout(delay)

    def reset():
        click(1190, 49, 650)
        page.wait_for_function("!window.MatryoshkaMic && window.__micStreams.every(s => s.getTracks().every(t => t.readyState === 'ended'))")

    def open_level():
        click(275, 360, 600)

    load()
    menu = page.screenshot(path=str(out / 'menu.png'))
    click(640, 360)
    assert page.screenshot() == menu, 'Disabled stands card navigated'
    click(1005, 360)
    assert page.screenshot() == menu, 'Disabled commentator card navigated'
    open_level()
    page.screenshot(path=str(out / 'intro.png'))
    assert page.evaluate('window.__micRequests') == 0, 'Intro requested microphone before Start'
    click(640, 495, 200)
    page.wait_for_function("window.MatryoshkaMic?.status === 'active'", timeout=15000)
    page.wait_for_function("window.MatryoshkaMic.sample().rms > 0.015", timeout=10000)
    active = page.screenshot()
    for _ in range(60):
        if meter_fill(active) > 5:
            break
        page.wait_for_timeout(100)
        active = page.screenshot()
    (out / 'microphone-active.png').write_bytes(active)
    assert meter_fill(active) > 5, 'Measured audio never reached the visible HUD meter'
    assert page.evaluate('window.__monitorConnections') == 0, 'Microphone was connected to speaker output'
    assert page.locator('audio,video').count() == 0
    reset()
    assert page.screenshot() == menu, 'Reset did not restore menu'

    for mode in ['denied', 'not-found', 'busy']:
        page.evaluate('(mode) => { window.__micMode = mode; }', mode)
        open_level()
        click(640, 495, 600)
        page.wait_for_function('(mode) => window.MatryoshkaMic?.status === mode', arg=mode)
        snapshot = page.screenshot(path=str(out / f'microphone-{mode}.png'))
        page.keyboard.down('w'); page.wait_for_timeout(400); page.keyboard.up('w')
        assert meter_fill(page.screenshot()) == 0, 'A public key silently replaced failed microphone'
        assert page.screenshot() == snapshot, 'Keyboard input changed the error state'
        page.evaluate("window.__micMode = 'real'")
        click(640, 436, 300)
        page.wait_for_function("window.MatryoshkaMic?.status === 'active'", timeout=15000)
        reset()
        assert page.screenshot() == menu

    page.evaluate("window.__micMode = 'pending'")
    open_level()
    click(640, 495, 200)
    page.wait_for_function("window.__releasePending && window.MatryoshkaMic?.status === 'pending'")
    click(1190, 49, 650)
    page.wait_for_function('!window.MatryoshkaMic')
    page.evaluate('window.__releasePending()')
    page.wait_for_function("window.__micStreams.every(s => s.getTracks().every(t => t.readyState === 'ended'))")
    assert page.screenshot() == menu, 'Late permission result reopened a reset session'
    assert page.evaluate('window.__monitorConnections') == 0
    assert all(r['method'] == 'GET' for r in requests), 'Unexpected outgoing POST/upload'

    load(args.url.rstrip('/') + '/?debug=1')
    open_level(); click(640, 495, 600)
    assert page.evaluate('window.__micRequests') == 0, 'Explicit debug mode requested a real microphone'
    page.keyboard.down('w'); page.wait_for_timeout(700)
    debug = page.screenshot(path=str(out / 'debug-input.png'))
    assert meter_fill(debug) > 5, 'Explicit keyboard debug did not drive the meter'
    page.keyboard.up('w'); page.wait_for_timeout(700)
    assert meter_fill(page.screenshot()) == 0, 'Debug key release did not return to silence'
    reset()
    page.set_viewport_size({'width': 1024, 'height': 768})
    page.wait_for_timeout(500)
    page.screenshot(path=str(out / 'menu-4x3.png'))

    bad = [m for m in messages if 'SCRIPT ERROR' in m or m.startswith('error: ERROR:')]
    assert not errors and not bad, errors + bad
    report = {'result': 'passed', 'physical_microphone_tested': False,
              'input': 'Chromium synthetic MediaStream capture; simulated denial/missing/busy',
              'console': messages, 'errors': errors, 'requests': requests}
    (out / 'browser-log.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    browser.close()
    print('BROWSER PASS: synthetic Web Audio RMS/HUD, denied/missing/busy retry, late permission reset, resource cleanup, no monitoring/upload, strict debug opt-in, menu/resize')
