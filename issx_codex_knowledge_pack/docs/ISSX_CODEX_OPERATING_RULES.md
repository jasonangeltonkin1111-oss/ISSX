# ISSX Codex Operating Rules

This file is the condensed operating contract for Codex when working on ISSX.

## What Codex should do first on every run
1. Identify the current active foundation task.
2. Identify the active stage.
3. Identify whether the task is debug-first, stage-truth, deep-task, mixed hardening, or activation validation.
4. Read only the minimum necessary related modules for that stage.
5. Check touched paths for forbidden patterns before patching.

## Architecture map
- `ISSX/ISSX.mq5` - wrapper/controller
- `ISSX/issx_core.mqh` - shared primitives
- `ISSX/issx_registry.mqh` - metadata / blueprint registry
- `ISSX/issx_runtime.mqh` - runtime state / budget / phase / queue
- `ISSX/issx_persistence.mqh` - persistence / projection / handoff
- `ISSX/issx_market_engine.mqh` - EA1
- `ISSX/issx_history_engine.mqh` - EA2
- `ISSX/issx_selection_engine.mqh` - EA3
- `ISSX/issx_correlation_engine.mqh` - EA4
- `ISSX/issx_contracts.mqh` - EA5
- `ISSX/issx_ui.mqh` - aggregate UI / HUD projection
- `ISSX/issx_debug_engine.mqh` - debug sink
- `ISSX/issx_menu.mqh` - chart-button menu UI

## Business-logic boundary
- stage engines own stage business logic
- persistence owns writes and handoffs
- UI owns projection only
- debug engine owns log writing only
- wrapper may orchestrate and log, but not absorb stage business logic

## Forbidden patterns
- `while(true)`
- `for(;;)`
- uncapped retry-until-ready loops
- MQL4 drift such as `extern`, `LastError`, `Ask`, `Bid`, `OrderSend`, `OrderClose`, `OrderSelect`, `PositionSelectByIndex`
- duplicate static definitions
- defining class statics that were never declared inside the class
- HUD code that computes business logic
- export code that reports build success as write success

## Debug ladder
1. wrapper/system truth for active surface
2. active-stage execution truth
3. stage task counters/reasons
4. stage publish/projection truth
5. HUD projection of already-computed truth

## Success standard
A task is only successful when the active stage is truthful, bounded, deterministic where required, observable in one review pass, MT5-correct, and version-synced.
