from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
docs = root / 'knowledge' / 'extracted_mql5_docs'
out = root / 'manifests' / 'mql5_docs_manifest.json'

entries = []
for p in sorted(docs.rglob('*')):
    if p.is_file():
        entries.append({
            'path': str(p.relative_to(root)).replace('\\', '/'),
            'suffix': p.suffix.lower(),
            'size': p.stat().st_size,
        })

out.write_text(json.dumps({'count': len(entries), 'files': entries}, indent=2), encoding='utf-8')
print(f'Wrote {out} with {len(entries)} files')
