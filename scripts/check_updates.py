#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Skrypt GitHub Actions: sprawdza źródła OTA/WWW/RSS, wykrywa nowe wersje, aktualizuje plik state JSON
i (opcjonalnie) wysyła webhook. Działa bez uruchamiania aplikacji.

Wymaga: requests, pyyaml, feedparser, beautifulsoup4, defusedxml
"""

import os
import sys
import json
import time
import hashlib
import logging
from datetime import datetime, timezone

import yaml
import requests
import feedparser
from bs4 import BeautifulSoup

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
STATE_PATH = os.path.join(SCRIPT_DIR, 'state.json')
SOURCES_PATH = os.path.join(SCRIPT_DIR, 'sources.yaml')

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s')


def load_state():
    if os.path.exists(STATE_PATH):
        with open(STATE_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {"items": []}


def save_state(state):
    with open(STATE_PATH, 'w', encoding='utf-8') as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def load_sources():
    with open(SOURCES_PATH, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


def hash_item(item):
    s = f"{item['kind']}-{item['version']}-{item['build']}-{item['channel']}"
    return hashlib.sha256(s.encode('utf-8')).hexdigest()


def fetch_rss(url):
    feed = feedparser.parse(url)
    items = []
    for e in feed.entries:
        title = e.get('title', '')
        published = e.get('published', None)
        dt = None
        if published:
            try:
                dt = datetime(*e.published_parsed[:6], tzinfo=timezone.utc)
            except Exception:
                dt = None
        kind = guess_kind(title)
        if not kind:
            continue
        version, build, channel, beta_num = parse_title(title)
        items.append({
            'kind': kind,
            'version': version,
            'build': build,
            'channel': channel,
            'betaNumber': beta_num,
            # Jeżeli brak daty w RSS, nie nadawajmy "teraz" – zostawmy None, zostanie uzupełnione później przy scalaniu
            'publishedAt': (dt.isoformat() if dt else None),
            'status': 'announce_first',
            'deviceIdentifier': None,
        })
    return items


def fetch_html(url):
    # Minimalne parsowanie listy releasów z HTML Apple Developer Releases
    r = requests.get(url, timeout=30, headers={'User-Agent': 'AppleCheck/Actions'})
    r.raise_for_status()
    soup = BeautifulSoup(r.text, 'html.parser')
    items = []
    for card in soup.select('article a:has(h3)'):
        title = card.get_text(" ", strip=True)
        kind = guess_kind(title)
        if not kind:
            continue
        version, build, channel, beta_num = parse_title(title)
        items.append({
            'kind': kind,
            'version': version,
            'build': build,
            'channel': channel,
            'betaNumber': beta_num,
            # Nie znamy daty – zostaw None, downstream skoryguje jeśli znajdzie z innego źródła
            'publishedAt': None,
            'status': 'announce_first',
            'deviceIdentifier': None,
        })
    return items


def fetch_macos_catalog(url):
    # Uproszczone – parsowanie plist sucatalog: szukamy pól OSVersion/BuildVersion/PostDate
    r = requests.get(url, timeout=60, headers={'User-Agent': 'AppleCheck/Actions'})
    r.raise_for_status()
    try:
        import plistlib
        plist = plistlib.loads(r.content)
    except Exception:
        return []
    products = plist.get('Products', {})
    items = []
    for prod in products.values():
        os_version = prod.get('OSVersion')
        build = prod.get('BuildVersion')
        post_date = prod.get('PostDate')
        if not (os_version and build and post_date):
            continue
        if isinstance(post_date, datetime):
            dt = post_date
        else:
            try:
                dt = datetime.fromisoformat(str(post_date))
            except Exception:
                dt = None
        items.append({
            'kind': 'macOS',
            'version': os_version,
            'build': build,
            'channel': classify_channel(os_version),
            'publishedAt': (dt.replace(tzinfo=timezone.utc).isoformat() if dt else None),
            'status': 'device_first',
            'deviceIdentifier': None,
        })
    return items


def guess_kind(title: str):
    t = title.lower()
    if 'xcode' in t:
        return 'xcode'
    if 'ipados' in t:
        return 'iPadOS'
    if 'ios' in t:
        return 'iOS'
    if 'macos' in t:
        return 'macOS'
    if 'watchos' in t:
        return 'watchOS'
    if 'tvos' in t:
        return 'tvOS'
    return None


def parse_title(title: str):
    import re
    build = ''
    m = re.search(r'\(([A-Za-z0-9]+)\)', title)
    if m:
        build = m.group(1)
    channel = 'release'
    tl = title.lower()
    if 'beta' in tl:
        channel = 'developerBeta' if 'public beta' not in tl else 'publicBeta'
    elif 'rc' in tl:
        channel = 'rc'
    # Obsłuż wersje z kropkami i bez (np. "18")
    m2 = re.search(r'(\d+(?:\.\d+){0,3})', title)
    version = m2.group(1) if m2 else title
    m_beta = re.search(r'beta\s*(\d+)', title, re.I)
    beta_num = int(m_beta.group(1)) if m_beta else None
    return version, build, channel, beta_num


def classify_channel(version: str):
    v = version.lower()
    if 'beta' in v:
        return 'developerBeta'
    if 'rc' in v:
        return 'rc'
    return 'release'


def merge(www_items, ota_items):
    def norm_ver(s):
        return s.lower().replace('beta', '').replace('rc', '').strip()
    def key(item):
        return f"{item['kind']}-{item['channel']}-{norm_ver(item['version'])}"
    def cmp_build(a, b):
        return (a > b) - (a < b)
    m = {}
    for it in www_items:
        k = key(it)
        prev = m.get(k)
        if prev:
            if cmp_build(prev['build'], it['build']) == 0:
                it['status'] = 'confirmed'
        # Zachowaj nowszą wersję po numerze (nie dacie) i wyższy betaNumber
        if k in m:
            if version_greater(it['version'], m[k]['version']):
                m[k] = it
            elif version_equal(it['version'], m[k]['version']):
                # Priorytet kanałów: dev > public beta > rc > release
                rank = {'developerBeta': 3, 'publicBeta': 2, 'rc': 1, 'release': 0}
                r1 = rank.get(it['channel'], 0)
                r2 = rank.get(m[k]['channel'], 0)
                if r1 != r2:
                    if r1 > r2:
                        m[k] = it
                else:
                    b1 = it.get('betaNumber') or -1
                    b2 = m[k].get('betaNumber') or -1
                    if b1 > b2:
                        m[k] = it
        else:
            m[k] = it
    for it in ota_items:
        k = key(it)
        prev = m.get(k)
        if prev and cmp_build(prev['build'], it['build']) == 0:
            it['status'] = 'confirmed'
            # Priorytet OTA > WWW
        if k in m:
            if version_greater(it['version'], m[k]['version']):
                m[k] = it
            elif version_equal(it['version'], m[k]['version']):
                rank = {'developerBeta': 3, 'publicBeta': 2, 'rc': 1, 'release': 0}
                r1 = rank.get(it['channel'], 0)
                r2 = rank.get(m[k]['channel'], 0)
                if r1 != r2:
                    if r1 > r2:
                        m[k] = it
                else:
                    b1 = it.get('betaNumber') or -1
                    b2 = m[k].get('betaNumber') or -1
                    if b1 > b2:
                        m[k] = it
        else:
            m[k] = it
    return list(m.values())


def version_greater(a: str, b: str) -> bool:
    def parts(x: str):
        import re
        m = re.search(r'(\d+(?:\.\d+){0,3})', x.lower().replace('beta', '').replace('rc', ''))
        s = m.group(1) if m else '0'
        return [int(p) for p in s.split('.')]
    aa, bb = parts(a), parts(b)
    n = max(len(aa), len(bb))
    for i in range(n):
        ai = aa[i] if i < len(aa) else 0
        bi = bb[i] if i < len(bb) else 0
        if ai != bi:
            return ai > bi
    return False


def version_equal(a: str, b: str) -> bool:
    def parts(x: str):
        import re
        m = re.search(r'(\d+(?:\.\d+){0,3})', x.lower().replace('beta', '').replace('rc', ''))
        s = m.group(1) if m else '0'
        return [int(p) for p in s.split('.')]
    return parts(a) == parts(b)


def send_webhook(new_items):
    url = os.environ.get('WEBHOOK_URL')
    token = os.environ.get('WEBHOOK_TOKEN')
    if not url:
        logging.info('Brak WEBHOOK_URL – pomijam wysyłkę')
        return
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    payload = {'newReleases': new_items}
    try:
        r = requests.post(url, headers=headers, data=json.dumps(payload), timeout=30)
        logging.info('Webhook: %s %s', r.status_code, r.text[:200])
    except Exception as e:
        logging.error('Webhook błąd: %s', e)


def main():
    sources = load_sources()
    state = load_state()
    seen_hashes = {x['hash'] for x in state.get('items', [])}

    www_items = []
    for u in sources.get('www', []):
        if u.endswith('.rss'):
            www_items += fetch_rss(u)
        else:
            www_items += fetch_html(u)

    ota_items = []
    for u in sources.get('ota', []):
        if 'sucatalog' in u:
            ota_items += fetch_macos_catalog(u)

    merged = merge(www_items, ota_items)
    # Sort by date desc
    merged.sort(key=lambda x: x['publishedAt'], reverse=True)

    new_ones = []
    new_state_items = []
    for it in merged:
        h = hash_item(it)
        entry = {**it, 'hash': h}
        new_state_items.append(entry)
        if h not in seen_hashes:
            new_ones.append(it)

    state['items'] = new_state_items
    save_state(state)

    if new_ones:
        logging.info('Wykryto nowe wydania: %d', len(new_ones))
        send_webhook(new_ones)
    else:
        logging.info('Brak nowych wydań')


if __name__ == '__main__':
    main()


