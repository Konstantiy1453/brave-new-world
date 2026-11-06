"""Verify SHA-256 manifests after extracting the handoff ZIPs. Python 3.9+."""
import hashlib
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parent
require_art = '--require-art' in sys.argv
failed = []
count = 0
for kind in ('MAIN', 'ART'):
    manifest = root / ('MANIFEST_'+kind+'.json')
    if not manifest.exists():
        if kind == 'MAIN' or require_art:
            failed.append('Missing '+manifest.name)
        else:
            print('ART: not installed; use --require-art after merging both packages.')
        continue
    data = json.loads(manifest.read_text('utf-8'))
    for entry in data['files']:
        path = root / entry['path']
        if not path.resolve().is_relative_to(root.resolve()) or not path.is_file():
            failed.append('Missing or unsafe '+entry['path'])
            continue
        digest = hashlib.sha256()
        with path.open('rb') as f:
            for block in iter(lambda:f.read(4*1024*1024), b''):
                digest.update(block)
        if path.stat().st_size != entry['bytes'] or digest.hexdigest() != entry['sha256']:
            failed.append('Changed '+entry['path'])
        count += 1
    print(kind+': checked '+str(len(data['files']))+' manifest entries')
for problem in failed:
    print('FAIL:', problem)
print(('FAIL' if failed else 'PASS')+': '+str(count)+' files checked')
sys.exit(1 if failed else 0)
