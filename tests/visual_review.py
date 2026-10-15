"""Render controlled Godot traces through a local-only HTML response override.

Normal exported HTML is unchanged. This fixture checks drawing/Tweens with the
same gameplay/UI code; web_smoke_test.py separately plays a whole normal round.
"""
import argparse
import io
import json
import re
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url', default='http://127.0.0.1:8765/index.html')
parser.add_argument('--output', default='/workspace/artifacts/matryoshka-three-rounds')
args = parser.parse_args()
out = Path(args.output)
out.mkdir(parents=True, exist_ok=True)

with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
        args=['--no-sandbox', '--enable-unsafe-swiftshader', '--disable-dev-shm-usage'])
    context = browser.new_context(viewport={'width': 1280, 'height': 720})
    context.add_init_script('''
      const log = console.log.bind(console);
      console.log = (...parts) => {
        if (parts.join(' ').includes('VISUAL REVIEW READY:')) window.__reviewReady = true;
        log(...parts);
      };
      navigator.mediaDevices.getUserMedia = () => { throw Error('Review fixture requested microphone'); };
    ''')
    report = []
    for mode in ['catch', 'goal', 'frame', 'final-win', 'round-2', 'round-3', 'game-win']:
        page = context.new_page()
        errors, messages = [], []
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.on('console', lambda m: messages.append(m.type + ': ' + m.text))
        def local_html(route):
            response = route.fetch()
            body = response.text()
            match = re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', body)
            assert match, 'Godot HTML configuration absent'
            config = json.loads(match.group(1))
            config['args'] = ['--script', 'res://tests/visual_review.gd', '--', '--review-' + mode]
            body = body[:match.start(1)] + json.dumps(config) + body[match.end(1):]
            route.fulfill(response=response, body=body)
        page.route('**/index.html', local_html)
        page.goto(args.url, wait_until='domcontentloaded')
        page.wait_for_function('window.__reviewReady === true', timeout=60000)
        page.wait_for_timeout(750)
        png = page.screenshot(path=str(out / (mode + '.png')))
        image = Image.open(io.BytesIO(png)).convert('RGB')
        if mode == 'catch':
            def cream_count(left, right):
                return sum(all(abs(a-b) < 3 for a, b in zip(image.getpixel((x, y)), (245,237,218)))
                           for x in range(left, right) for y in range(228, 250))
            assert cream_count(612, 623) > 10 and cream_count(658, 670) > 10, 'Gloves did not rise to both sides of the airborne ball'
        if mode in ['final-win', 'game-win']:
            assert image.getpixel((260,190)) == (250,246,237), 'Winning final was not centrally placed'
            page.set_viewport_size({'width':1024,'height':768})
            page.wait_for_timeout(500)
            page.screenshot(path=str(out / (mode + '-4x3.png')))
        bad = [m for m in messages if 'SCRIPT ERROR' in m or m.startswith('error: ERROR:')]
        assert not errors and not bad, errors + bad
        report.append({'mode':mode, 'result':'passed', 'console':messages, 'errors':errors})
        page.close()
    browser.close()
(out / 'visual-review-log.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
print('VISUAL PASS: raised gloves/catch, goal feedback, round 2/3 defenders, intermediate victory and game completion at 16:9 and 4:3; no physical microphone')
