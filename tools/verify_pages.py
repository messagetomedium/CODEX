#!/usr/bin/env python3
"""Check the exact published Godot build from the GitHub-hosted deploy runner."""
import argparse
import json
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urljoin
from urllib.request import Request, urlopen


def verify(base_url, expected_commit):
    query = '?' + urlencode({'build': expected_commit})

    def read(path, limit=None):
        request = Request(urljoin(base_url.rstrip('/') + '/', path) + query)
        with urlopen(request, timeout=30) as response:
            return response.read() if limit is None else response.read(limit)

    version = json.loads(read('version.json'))
    if version.get('commit') != expected_commit:
        raise ValueError('Pages is still serving a different commit')
    if b'GODOT_CONFIG' not in read('index.html'):
        raise ValueError('The published page is not the exported Godot launcher')
    if read('index.pck', 4) != b'GDPC':
        raise ValueError('Godot PCK is missing or invalid')
    if read('index.wasm', 4) != b'\x00asm':
        raise ValueError('Godot WASM is missing or invalid')
    if b'Engine' not in read('index.js'):
        raise ValueError('Godot JavaScript loader is missing')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('url')
    parser.add_argument('commit')
    args = parser.parse_args()
    if not args.url.startswith('https://') or not re.fullmatch(r'[0-9a-f]{40}', args.commit):
        parser.error('Provide the HTTPS Pages URL and full commit SHA')
    for attempt in range(12):
        try:
            verify(args.url, args.commit)
        except (HTTPError, URLError, TimeoutError, ValueError, OSError) as error:
            print(f'Pages check {attempt + 1}/12: {error}', flush=True)
            if attempt == 11:
                return 1
            time.sleep(5)
        else:
            print(f'PASS: live Godot Web build at {args.url}; commit {args.commit}')
            return 0
    return 1


if __name__ == '__main__':
    sys.exit(main())
