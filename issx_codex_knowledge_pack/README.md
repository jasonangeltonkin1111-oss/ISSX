# ISSX Codex Knowledge Pack

This pack is designed to make Codex far more effective on the ISSX MT5/MQL5 codebase.

It includes:
- the raw `mql5.chm` reference file
- a Codex operating guide for ISSX
- Jason's foundation blueprint converted into Codex-friendly docs
- reusable prompts for stage-by-stage work
- Windows extraction scripts for turning the CHM into browsable HTML docs
- a local indexing script so Codex can search the extracted docs faster

## Recommended use

1. Put this pack at the root of your ISSX repo.
2. Extract `knowledge/raw/mql5.chm` using one of the scripts in `scripts/`.
3. Keep the extracted output under `knowledge/extracted_mql5_docs/`.
4. Commit the docs or at least keep them available in the same workspace Codex can read.
5. Keep `AGENTS.md` at the repo root so Codex reads the operating rules automatically.

## Important note

This pack includes the raw CHM because extraction could not be performed inside this environment. The included Windows scripts use your local `hh.exe` or PowerShell workflow to extract it on your machine.

## Folder map

- `knowledge/raw/` - raw documentation payloads
- `knowledge/extracted_mql5_docs/` - target folder for extracted HTML docs
- `docs/` - ISSX operating docs and blueprint files
- `docs/prompts/` - Codex prompts for specific task modes
- `scripts/` - helper scripts for extraction and indexing
- `config/` - config templates / allowlists
- `manifests/` - generated file manifests / indexes
