# ISSX Master System Debug / Architecture Validation Audit

## Scope
- Wrapper: `ISSX.mq5`
- Infrastructure: `issx_config.mqh`, `issx_telemetry.mqh`, `issx_ui.mqh`, `issx_data_handler.mqh`, `issx_scheduler.mqh`, `issx_registry.mqh`
- Runtime/Core: `issx_runtime.mqh`, `issx_core.mqh`
- Stage engines: `issx_market_engine.mqh`, `issx_history_engine.mqh`, `issx_selection_engine.mqh`, `issx_correlation_engine.mqh`, `issx_contracts.mqh`
- Other: `issx_persistence.mqh`, `issx_debug_engine.mqh`, `issx_menu.mqh`

## PRIMARY FINDINGS
1. **Wrapper orchestration is only partially clean**: lifecycle + timer + stage calls are centralized, but the wrapper still performs UI object management, JSON building, and direct file writes.
2. **Module ownership boundaries are violated in multiple places**:
   - UI calls are present outside `issx_ui.mqh`.
   - File IO is distributed across DataHandler, Persistence, DebugEngine, and wrapper-level helpers.
3. **Config integration is incomplete/fragile**:
   - `issx_config.mqh` is not explicitly included by `ISSX.mq5`.
   - `Config.Init()` call is absent in wrapper init path.
   - Direct `Inp*` reads are widespread in wrapper runtime path (not just bootstrap).
4. **Infrastructure modules are unevenly adopted**:
   - Scheduler/Telemetry/UI/Registry are wired and used.
   - Config and DataHandler are not used as exclusive ownership layers.
5. **Version synchronization is inconsistent**: wrapper is `1.716`; most modules are `1.714/1.715`.

---

## ARCHITECTURE VIOLATIONS

### A1) Wrapper performs chart object work (should be UI-owned)
- `ISSX.mq5` creates/updates/deletes HUD objects directly (`ObjectCreate`, `ObjectSet*`, `ObjectDelete`) in `ISSX_RefreshInlineHud`. This duplicates the UI module ownership.

### A2) Wrapper builds JSON payload directly
- `ISSX_BuildEA1StageStatusJson()` creates JSON in wrapper using `ISSX_JsonWriter`.
- This violates strict ownership expectation that serialization/building should be DataHandler (or dedicated serializer module) owned, not wrapper-owned.

### A3) Wrapper writes files outside DataHandler
- `ISSX_ProjectEA5()` writes root export via `ISSX_FileIO::WriteText(...)` directly.
- This bypasses DataHandler’s forensic/atomic write path.

### A4) Config module orchestration gap
- Wrapper does not explicitly include `issx_config.mqh` and no `Config.Init()` call was found in `OnInit()`.
- Yet wrapper calls `Config.Get*` and `Config.IsEAEnabled`, implying hidden coupling and fragile integration.

---

## MODULE OWNERSHIP ERRORS

### UI ownership violations
- Expected: only `issx_ui.mqh` invokes chart APIs.
- Actual: `ISSX.mq5` invokes chart APIs directly for HUD.

### Data handler ownership violations
- Expected: only `issx_data_handler.mqh` writes files.
- Actual:
  - `issx_persistence.mqh` does direct `FileOpen/FileClose/...`
  - `issx_debug_engine.mqh` does direct `FileOpen/FileWriteString/...`
  - `ISSX.mq5` calls `ISSX_FileIO::WriteText(...)`

### Config ownership violations
- Expected: runtime config reads through `Config.Get*` after centralized init.
- Actual: wrapper reads `Inp*` values in runtime path (scheduler setup, stage limits, gate decisions, feature-state logs).

### Telemetry ownership check
- Telemetry module appears read/observe-only (events, metrics, checkpoints). No file/chart mutation detected in telemetry module itself.

### Stage engine ownership check
- Stage engines inspected do not perform chart object operations or timer/scheduler ownership.
- No direct file IO detected in stage engine files listed above.

---

## DUPLICATED LOGIC

1. **HUD/UI duplication**
   - `issx_ui.mqh` provides HUD object lifecycle + render.
   - Wrapper also independently builds and paints an inline HUD.

2. **JSON/serialization duplication**
   - Stage modules produce stage/debug JSON (`StagePublish` / `ToStageJson`).
   - Wrapper additionally builds JSON status block (`ISSX_BuildEA1StageStatusJson`).

3. **File writer duplication**
   - DataHandler atomic writer exists.
   - Persistence and DebugEngine also own independent low-level file IO.
   - Wrapper writes file directly via `ISSX_FileIO::WriteText`.

4. **State tracking duplication (partial)**
   - Registry exists and is used.
   - Wrapper also keeps many parallel `g_last_ea*_*` status fields; this is operationally useful but duplicates some state semantics already represented in registry.

---

## MISSING MODULE INTEGRATION

1. **Config integration incomplete**
   - `Config.Init()` not observed in `OnInit`.
   - wrapper references `Config.*` without explicit include/initialization in visible wrapper include block.

2. **DataHandler non-exclusive**
   - Atomic forensic IO layer exists but is not enforced as single writer abstraction.

3. **Scheduler integration present**
   - `BeginCycle`/`EndCycle` + stage/batch methods are used in kernel loop.

4. **Telemetry integration present**
   - `Init`, `Event`, `StageStart/End`, `Metric`, `Flush` are wired.

5. **UI integration present but bypassed**
   - `g_ui.Init/Render/Shutdown` are used.
   - wrapper still performs parallel direct HUD rendering.

6. **Registry integration present**
   - `StageRegistry.Reset/SetState/GetState` are used in wrapper.

---

## UNUSED MODULES

1. **`issx_menu.mqh` appears disconnected**
   - Module exists and defines `ISSX_MenuEngine`.
   - Not included by wrapper include block and no active usage path found.

2. **`issx_config.mqh` include appears disconnected from wrapper include list**
   - Module exists and defines config abstraction but not explicitly included by wrapper.

---

## PIPELINE VALIDATION (EA1 → EA2 → EA3 → EA4 → EA5)

### Observed ordering
- Wrapper executes stages in expected order within the cycle: EA1 then EA2 then EA3 then EA4 then EA5.

### Upstream readiness gating
- **Partial**:
  - Wrapper does not enforce explicit hard precondition checks before all downstream stage calls.
  - Engines appear to carry internal dependency/block reasons and minimum-ready flags, but wrapper still calls slices based mainly on `g_ea_enabled[]` and scheduler gates.
- Risk: downstream stage invocation can occur even if upstream is degraded/not ready, relying on downstream internals for self-protection.

---

## TIMER / RUNTIME SAFETY

- No `Sleep()` or `while(true)` found in inspected files.
- Timer path is bounded by scheduler gates + staged calls.
- `g_kernel_busy` guard exists in wrapper timer path to prevent overlap.

Status: **generally safe** for bounded runtime path, with architecture caveats noted above.

---

## MT5 COMPLIANCE ISSUES

- Disallowed legacy trade globals/functions (`Ask`, `Bid`, `OrderSend`, `OrderClose`) were not found.
- `extern` is used in `issx_config.mqh` for wrapper input declarations (rule checklist flags this as disallowed pattern).
- `LastError` bare legacy symbol not used; `GetLastError()` is used (MT5-compliant).

---

## STATIC VARIABLE SAFETY

- Static class member identified in `issx_market_engine.mqh` has one declaration + one definition; no duplicate definition detected.
- Local static in wrapper `OnTick()` is benign.

Status: **no duplicate static-definition issue detected**.

---

## VERSION CONSISTENCY

- Wrapper: `1.716`.
- Core/Config/Telemetry/UI/Persistence/Market engine: `1.715`.
- Runtime/Registry/Selection/Correlation/Contracts/Menu/UI Test/Debug Engine/History engine: mostly `1.714`.

Status: **version mismatch present** across wrapper + infrastructure/runtime/stage modules.

---

## RECOMMENDED FIXES (SAFE, NON-REDESIGN)

1. **Remove wrapper direct HUD object handling**
   - Delete/retire inline HUD object code in wrapper and route all chart object rendering through `g_ui.Render` only.

2. **Enforce DataHandler as write boundary for operator-facing JSON/text outputs**
   - Replace wrapper direct `ISSX_FileIO::WriteText(...)` writes with DataHandler atomic methods.
   - Optionally centralize Persistence/DebugEngine writes behind dedicated infrastructure adapter if strict ownership is required.

3. **Normalize config orchestration**
   - Explicitly include `issx_config.mqh` in wrapper include list.
   - Call `Config.Init()` at start of `OnInit()` before any `Config.Get*` usage.
   - Replace runtime-path direct `Inp*` reads with `Config.Get*` values except for initial load into Config.

4. **Harden pipeline precondition checks in wrapper (light-touch)**
   - Before EA3/EA4/EA5 calls, gate on upstream minimum-ready/registry state to avoid unnecessary downstream execution attempts.
   - Keep engine self-checks as defense-in-depth.

5. **Version alignment sweep**
   - Synchronize module version constants/comments to one release target (e.g., 1.716) in a dedicated, low-risk versioning pass.

6. **Retire or rewire `issx_menu.mqh`**
   - If no longer used, remove from active architecture docs and mark deprecated.
   - If needed, explicitly include/integrate via wrapper gates.

---

## SAFE PATCH PLAN

1. **Patch 1 (UI boundary only)**
   - Remove wrapper chart-object calls; preserve behavior through `issx_ui.mqh` only.
   - No stage logic changes.

2. **Patch 2 (Config bootstrap + input reads)**
   - Add explicit `issx_config.mqh` include and `Config.Init()` in `OnInit`.
   - Convert runtime `Inp*` reads in wrapper to `Config.Get*`.

3. **Patch 3 (IO boundary)**
   - Route wrapper root export/file projection writes through DataHandler atomics.
   - Keep payload content unchanged.

4. **Patch 4 (Pipeline guardrails)**
   - Add wrapper-side upstream readiness checks for EA3/EA4/EA5 before invocation.
   - Do not change stage business computations.

5. **Patch 5 (Version sync + dead module cleanup)**
   - Align version constants/comments.
   - Decommission or integrate `issx_menu.mqh` explicitly.

Each patch remains isolated, reversible, and avoids redesigning stage algorithms.
