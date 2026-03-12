# AGENTS.md - ISSX Codex Operating Contract

You are working on ISSX, a modular MetaTrader 5 system written in MQL5.

## Prime objective
Get the foundation pipeline working truthfully and safely.

## Mandatory source priorities
1. Read `docs/ISSX_FOUNDATION_TASK_BOARD_v1.4.md` first.
2. Read `docs/ISSX_CODEX_OPERATING_RULES.md` second.
3. Read `docs/ISSX_MANUAL_CHECKLIST.md` third.
4. Use `knowledge/extracted_mql5_docs/` as the primary MQL5 reference.
5. If the extracted docs are missing, fall back to `knowledge/raw/mql5.chm` and report that reference coverage is degraded.

## Hard constraints
- Target platform is MetaTrader 5 only.
- Generate valid MQL5 only.
- Do not introduce MQL4 drift.
- The wrapper/controller is `ISSX/ISSX.mq5`.
- Respect module boundaries.
- HUD is read-only projection only.
- Persistence owns writes.
- Wrapper orchestrates and logs but does not absorb stage business logic.
- One main task only.
- One active stage focus only.
- Enable at most one currently-off stage in a run.
- No architecture redesign.
- No speculative cleanup.
- Every successful task increments repo version by exactly +1 and syncs all versioned ISSX files.

## Stage order
F0 -> F0.5 -> F1 -> F2 -> F3 -> F3.5 -> F3.75 -> F4 -> F5 -> F6 -> F7 -> F8 -> F9 -> F10 -> F11 -> F12 -> F13 -> F14 -> F15

## Runtime truths to preserve
- no false health
- no unbounded loops
- no unbounded CopyRates pressure
- no silent skips
- no fake export success
- no chart object storm
- no wrapper stage logic leak

## Reporting contract
Every run must report:
- PRIMARY ISSUE
- PRIMARY SURFACE
- RELATED GLOBAL ISSUES
- OLD EAS FINDINGS
- MODULE INVARIANT CHECK
- SUGGESTED EXTRA CHECK RESULT
- FIX
- PATCH
- TEST RESULT
- VERSION BUMP
- REGRESSION RISK

## MQL5 correctness checks
Before finalizing any patch, verify:
- event lifecycle correctness (`OnInit`, `OnDeinit`, `OnTimer`, `OnTick`, `OnChartEvent`)
- static member declaration/definition correctness
- bounded history access
- MT5-safe chart object handling
- MT5-safe file path handling
- no invented APIs or signatures

## Preferred working mode
Use large but controlled stage-local passes when needed. Favor debug-first truth, then stage-truth, then deeper task hardening, then activation validation.
