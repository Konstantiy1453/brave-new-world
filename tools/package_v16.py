"""Package the frozen v1.6 workspace without user data or editor caches."""
from pathlib import Path
import hashlib, json, zipfile, shutil

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'delivery' / 'v16'
OUT.mkdir(parents=True, exist_ok=True)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def allowed(path):
    return not any(x in {'.godot', '__pycache__'} for x in path.parts) and path.suffix not in {'.bak', '.tmp'}

def put_tree(z, folder, prefix):
    for path in sorted(folder.rglob('*')):
        if path.is_file() and allowed(path):
            z.write(path, str(Path(prefix) / path.relative_to(folder)))

with zipfile.ZipFile(OUT / 'ColonyCharter-1.6-Windows-x64.zip', 'w', zipfile.ZIP_DEFLATED, 6) as z:
    for file in (ROOT / 'build/v16').iterdir():
        if file.is_file() and file.suffix in {'.exe', '.pck', '.txt', '.md'}:
            z.write(file, file.name)
    z.write(ROOT / 'README.md', '中文说明.md')
    put_tree(z, ROOT / 'docs/v16', 'docs')
    for p in (ROOT / 'game/data/v16').glob('*.json'):
        z.write(p, '验收存档/' + p.name)

with zipfile.ZipFile(OUT / 'ColonyCharter-1.6-Source.zip', 'w', zipfile.ZIP_DEFLATED, 6) as z:
    put_tree(z, ROOT / 'game', 'game')
    put_tree(z, ROOT / 'docs/v16', 'docs/v16')
    for p in (ROOT / 'docs').glob('*.md'):
        z.write(p, 'docs/' + p.name)
    put_tree(z, ROOT / 'docs/superpowers/plans', 'docs/superpowers/plans')
    for p in (ROOT / 'saves').glob('*.json'):
        z.write(p, 'saves/' + p.name)
    for p in (ROOT / 'tools').iterdir():
        if p.is_file() and p.suffix in {'.ps1', '.gd', '.py'}:
            z.write(p, 'tools/' + p.name)
    for name in ['README.md', 'DEMO_AGENT_PROMPT.txt', 'docs/GODOT_LICENSE.txt', 'docs/GODOT_COPYRIGHT.txt']:
        z.write(ROOT / name, name)

with zipfile.ZipFile(OUT / 'ColonyCharter-1.6-Evidence.zip', 'w', zipfile.ZIP_DEFLATED, 6) as z:
    for p in sorted((ROOT / 'evidence/v16').iterdir()):
        if p.is_file() and p.suffix in {'.json', '.log', '.txt', '.py'}:
            z.write(p, p.name)
    for directory in ['screenshots_verified', 'screenshots_targets_delivery', 'scroll_source', 'manual_screenshots']:
        put_tree(z, ROOT / 'evidence/v16' / directory, directory)
    put_tree(z, ROOT / 'docs/v16', 'docs')

report = {'version': '1.6.0', 'archives': [], 'checks': {}}
for p in OUT.glob('*.zip'):
    with zipfile.ZipFile(p) as z:
        bad = z.testzip()
        if bad:
            raise RuntimeError(f'{p}: corrupt entry {bad}')
        if 'Windows' in p.name:
            for name in ['ColonyCharter.exe', 'ColonyCharter.pck']:
                if hashlib.sha256(z.read(name)).hexdigest().upper() != digest(ROOT / 'build/v16' / name):
                    raise RuntimeError('Packaged executable identity mismatch')
    report['archives'].append({'path': str(p.relative_to(ROOT)), 'sha256': digest(p), 'bytes': p.stat().st_size})
report['checks'] = {'all_zip_entries_crc_valid': True, 'exe_pck_match_verified_build': True, 'source_editor_cache_excluded': True}
(OUT / 'PACKAGE_MANIFEST.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=True, indent=2))
