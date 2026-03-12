from pathlib import Path
import json, re

root = Path(__file__).resolve().parents[1]
docs = root / 'knowledge' / 'extracted_mql5_docs'
out = root / 'manifests' / 'mql5_keyword_index.json'

keywords = {
    'events': ['OnInit', 'OnDeinit', 'OnTimer', 'OnTick', 'OnChartEvent'],
    'history': ['CopyRates', 'CopyTime', 'CopyBuffer', 'SeriesInfoInteger'],
    'trade': ['CTrade', 'PositionSelect', 'OrderCalcMargin', 'OrderCalcProfit'],
    'files': ['FileOpen', 'FileWrite', 'FileReadString', 'FILE_COMMON'],
    'ui': ['ObjectCreate', 'ObjectSetInteger', 'ObjectSetString', 'ChartID'],
}

text_exts = {'.html', '.htm', '.txt', '.md', '.xml', '.js', '.css'}
index = {k: [] for k in keywords}

for p in docs.rglob('*'):
    if p.is_file() and p.suffix.lower() in text_exts:
        try:
            txt = p.read_text(encoding='utf-8', errors='ignore')
        except Exception:
            continue
        for bucket, terms in keywords.items():
            for term in terms:
                if re.search(r'\b' + re.escape(term) + r'\b', txt):
                    index[bucket].append(str(p.relative_to(root)).replace('\\', '/'))
                    break

for k in index:
    index[k] = sorted(set(index[k]))

out.write_text(json.dumps(index, indent=2), encoding='utf-8')
print(f'Wrote {out}')
