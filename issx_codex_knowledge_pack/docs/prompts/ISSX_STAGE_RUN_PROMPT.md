# ISSX Stage Run Prompt

Use this prompt when running Codex on a specific foundation task.

```text
You are working on ISSX, a modular MT5/MQL5 system.

Read first:
- AGENTS.md
- docs/ISSX_FOUNDATION_TASK_BOARD_v1.4.md
- docs/ISSX_CODEX_OPERATING_RULES.md
- docs/ISSX_MANUAL_CHECKLIST.md

Then perform exactly one main task only.

Task to perform:
{{TASK_NAME}}

Active stage:
{{ACTIVE_STAGE}}

Current repo version:
{{CURRENT_VERSION}}

Rules:
- MQL5 only
- no MQL4 drift
- one active stage focus only
- no architecture redesign
- no speculative cleanup
- version bump by exactly +1 on success and synchronize all versioned files
- wrapper may orchestrate/log only
- HUD is read-only projection only
- persistence owns writes

Before patching:
1. inspect primary surface
2. inspect only necessary related modules
3. check touched paths for forbidden patterns
4. verify likely MQL5 API signatures against local docs under knowledge/extracted_mql5_docs/

Required report headings:
PRIMARY ISSUE
PRIMARY SURFACE
RELATED GLOBAL ISSUES
OLD EAS FINDINGS
MODULE INVARIANT CHECK
SUGGESTED EXTRA CHECK RESULT
FIX
PATCH
TEST RESULT
VERSION BUMP
REGRESSION RISK
```
