# Place extracted MQL5 docs here

After running one of the extraction scripts in `scripts/`, this folder should contain the HTML help tree extracted from `knowledge/raw/mql5.chm`.

Recommended next steps after extraction:
1. run `python scripts/build_mql5_manifest.py`
2. run `python scripts/build_keyword_index.py`
3. commit the generated manifests if you want Codex to navigate the docs faster
