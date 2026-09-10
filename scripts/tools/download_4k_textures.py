#!/usr/bin/env python3
# KokaKolya - Massive 4K/8K PBR Texture Downloader from Polyhaven CC0
import os, sys, json, time, threading, urllib.request, urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

REPO_ROOT      = Path(r'c:\Users\Никитос\Documents\KokaKolya')
TEXTURE_DIR    = REPO_ROOT / 'assets' / 'textures' / 'pbr' / 'polyhaven'
TARGET_SIZE_GB = 14.5
MAX_WORKERS    = 6
RESOLUTION     = '4k'
FORMAT         = 'jpg'

PRIORITY_TAGS = ['asphalt','road','concrete','pavement','metal','rust','industrial','brick','wall','gravel','paving','tile','wood','plank','rock','stone','ground','dirt','mud','plaster','stucco']
MAP_SUFFIXES  = {'diffuse':'_albedo','nor_gl':'_normal','rough':'_roughness','metal':'_metallic','ao':'_ao','disp':'_height','arm':'_arm'}

def current_size_gb():
    total = sum(f.stat().st_size for f in (REPO_ROOT/'assets'/'textures').rglob('*') if f.is_file())
    return total / (1024**3)

def download_file(url, dest):
    if dest.exists(): return 'skip'
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix('.tmp')
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'KokaKolya/1.0'})
        with urllib.request.urlopen(req, timeout=60) as r, open(tmp,'wb') as f:
            while chunk := r.read(65536): f.write(chunk)
        tmp.rename(dest)
        return 'ok'
    except Exception as e:
        if tmp.exists(): tmp.unlink()
        return f'fail:{e}'

def fetch_json(url):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'KokaKolya/1.0'})
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode())
    except: return None

def texture_priority(asset_id, asset_data):
    tags = [t.lower() for t in asset_data.get('tags',[])]
    cats = [c.lower() for c in asset_data.get('categories',[])]
    all_kw = tags + cats + [asset_id.lower()]
    score = asset_data.get('download_count',0) // 1000
    for kw in PRIORITY_TAGS:
        if any(kw in w for w in all_kw): score += 100
    return score

print('='*70)
print('  KokaKolya - 4K PBR Texture Mass Downloader')
print(f'  Target: {TARGET_SIZE_GB} GB  |  Workers: {MAX_WORKERS}  |  Res: {RESOLUTION}')
print('='*70)

print('\n[1/3] Fetching Polyhaven asset list...')
asset_list = fetch_json('https://api.polyhaven.com/assets?type=textures')
if not asset_list:
    print('ERROR: Cannot fetch asset list.'); sys.exit(1)
print(f'  Found {len(asset_list):,} textures.')

ranked = sorted(asset_list.items(), key=lambda kv: texture_priority(kv[0], kv[1]), reverse=True)
print(f'[2/3] Top-5: {[r[0] for r in ranked[:5]]}')

print('[3/3] Downloading...\n')
downloaded = skipped = failed = 0
lock = threading.Lock()
stop_flag = threading.Event()

def download_asset(args):
    global downloaded, skipped, failed
    asset_id, asset_data = args
    if stop_flag.is_set(): return
    if current_size_gb() >= TARGET_SIZE_GB:
        stop_flag.set(); return

    files_data = fetch_json(f'https://api.polyhaven.com/files/{asset_id}')
    if not files_data: return
    time.sleep(0.03)

    tex_dir = TEXTURE_DIR / asset_id
    for map_type, dest_suffix in MAP_SUFFIXES.items():
        if stop_flag.is_set(): return
        map_block = files_data.get(map_type, {})
        res_block = map_block.get(RESOLUTION, map_block.get('2k', map_block.get('1k', {})))
        fmt_block = res_block.get(FORMAT, res_block.get('png', {}))
        if not fmt_block: continue
        url = fmt_block.get('url')
        if not url: continue
        dest = tex_dir / f'{asset_id}{dest_suffix}_{RESOLUTION}.{FORMAT}'
        result = download_file(url, dest)
        with lock:
            if result == 'skip': skipped += 1
            elif result == 'ok':
                downloaded += 1
                sz = current_size_gb()
                if downloaded % 10 == 0 or sz > TARGET_SIZE_GB - 0.5:
                    print(f'  [{downloaded:>5}dl | {skipped:>5}sk | {failed:>3}fail] {sz:.3f} / {TARGET_SIZE_GB} GB  - {asset_id}')
                if sz >= TARGET_SIZE_GB: stop_flag.set()
            else: failed += 1

with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(download_asset, item) for item in ranked]
    for f in as_completed(futures):
        if stop_flag.is_set():
            print('\n  !! Target size reached, shutting down pool...')
            break

final = current_size_gb()
print(f'\nDONE: {downloaded} downloaded | {skipped} skipped | {failed} failed | {final:.3f} GB total')
