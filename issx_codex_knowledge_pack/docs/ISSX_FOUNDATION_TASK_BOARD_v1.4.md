ISSX FOUNDATION TASK BOARD v1.4
===============================

PURPOSE
-------

This is a fast-track board for one goal only:

GET THE FOUNDATIONAL ISSX PIPELINE WORKING ASAP.

This board is not for full hardening, full polish, or full architecture archaeology.
This board is for making the minimum serious foundation work correctly so the rest of ISSX can be turned on safely and usefully.

Foundation means:
- wrapper stays stable
- EA1 market discovery works correctly
- EA1 publish / projection / HUD truth works correctly
- EA2 history hydration works correctly
- EA3 selection can consume real upstream data
- EA4 correlation can consume real upstream data
- EA5 contracts/export can consume real upstream data

Guiding idea:
If EA1 and EA2 are wrong, everything downstream is false.
So this board prioritizes truth of data flow over feature completeness.

Hard operating rule:
- we do NOT turn everything on at once
- we finish EA1 fully, test it fully, debug it fully, and prove it
- only then do we move to EA2
- only after EA2 is proven do we move to EA3
- only after EA3 is proven do we move to EA4
- only after EA4 is proven do we move to EA5

Working style:
- optimize for speed
- optimize for large but controlled stage-local passes
- use multiple passes inside the same active stage
- first strengthen wrapper/system truth for the active stage
- then strengthen stage truth
- then implement or harden the deeper task
- then activate and test
- then only move forward when the active stage is truly proven


FOUNDATION SUCCESS DEFINITION
-----------------------------

Foundation is considered working only when all of the following are true:

1. wrapper stays alive under timer without instability
2. wrapper runs enabled stages truthfully under the chosen runtime gates
3. EA1 market discovery is deterministic and bounded
4. EA1 publish/projection surfaces are truthful and usable
5. EA2 history hydration is bounded and truthful
6. EA3 selection runs only on real upstream truth
7. EA4 correlation runs only on real upstream truth
8. EA5 contract/export runs only on real upstream truth
9. every enabled stage reports success / degraded / failed truthfully
10. no stage hides missing upstream truth behind fake “healthy” output
11. system-wide debug truth is strong enough to identify the real failing surface in one review pass
12. HUD reflects state truthfully and never computes business logic
13. persistence/export writes only what the stage/runtime/persistence contract actually produced
14. stage JSON/debug/export handoff is visibly correct and testable


CORE RULES
----------

Every Codex run must obey:

- ONE main task only
- ONE active stage focus only
- ONE currently-OFF stage enabled at most
- NO architecture redesign
- NO speculative cleanup
- repo-wide version bump every successful task

Always prefer:
- truthful degradation
- bounded execution
- deterministic output
- stage-by-stage enablement
- stage-local hardening before downstream activation
- broad but controlled related-surface edits when necessary
- multi-pass growth over tiny patches

Never:
- enable multiple new stages in one run
- accept fake readiness
- accept unbounded loops
- accept unbounded CopyRates pressure
- accept silent skips
- accept heartbeat-only “healthy” wrapper output when enabled stages did not run
- let HUD calculate systems or own business logic
- move to EA2 before EA1 is truly proven
- move to EA3 before EA2 is truly proven
- move to EA4 before EA3 is truly proven
- move to EA5 before EA4 is truly proven

Acceleration rule:
- keep stage isolation
- allow multiple isolated sub-steps inside the SAME active stage per run
- allow related module edits in the same run when required to make the active stage truthful, observable, runnable, publishable, or exportable
- use debug truth to fix failures immediately inside that stage only
- do not broaden a run across multiple new stages

Related-module rule:
- do NOT artificially limit related modules if the active stage requires them
- if 5 related modules are necessary to make the active stage truthful and testable, edit all 5 in the same run
- if the task is purely local to one stage objective, keep it isolated to that objective
- module count is governed by necessity and stage isolation, not by arbitrary caps

Defaults rule for newly introduced controls:
- newly added runtime controls, projection controls, or stage-local validation controls must default to TRUE when they are required for current foundation work
- exception: default FALSE is allowed only if TRUE would create unsafe cross-stage activation or unbounded runtime pressure
- every such exception must be justified explicitly in the report


TARGET PLATFORM RULES — METATRADER 5 / MQL5
-------------------------------------------

All code and prompts must assume:
- target platform is MetaTrader 5
- code must be valid MQL5 only
- do NOT generate MQL4 constructs

MQL5-specific constraints:
1. The EA pipeline runs from OnTimer, not OnTick.
2. Use OnInit / OnDeinit / OnTimer / OnTick / OnChartEvent correctly.
3. HUD/chart projection must use MT5 chart object APIs correctly.
4. HUD must use a single reusable object where practical, not recreate objects every timer pulse.
5. Server time for HUD must use a proper server/trade-server time source.
6. Class static members must be declared inside the class before being defined outside.
7. Do NOT define class statics that are not declared in the class.
8. Do NOT duplicate static definitions.
9. Do NOT generate blocking loops, wait loops, or Sleep-style timer blocking.
10. History and buffer access must remain bounded.
11. HUD updates must be timer-based, not tick-driven.
12. File/path logic must respect MT5 sandbox rules if used.
13. Chart labels must be visible, positioned, and updated without object storms.
14. Export/file writes must use MT5-safe file APIs and sandbox-safe paths.

Never allow these MQL4-drift patterns:
- LastError
- extern
- PositionSelectByIndex
- Ask
- Bid
- OrderSend
- OrderClose
- OrderSelect

Use valid MQL5 equivalents only.

Static-definition safety rule:
- if a class member is declared static in the class, define it once outside the class
- if it is not declared in the class, do NOT define it as ClassName::member
- remove duplicate bottom-of-file static definitions if present


ARCHITECTURE AWARENESS RULES
----------------------------

Based on the active root architecture:

- ISSX.mq5 is the wrapper/controller
- issx_core.mqh is the shared primitive layer
- issx_registry.mqh is the metadata/blueprint registry layer
- issx_runtime.mqh is the runtime state / budget / phase / queue layer
- issx_persistence.mqh is the persistence / handoff / projection layer
- issx_market_engine.mqh is EA1
- issx_history_engine.mqh is EA2
- issx_selection_engine.mqh is EA3
- issx_correlation_engine.mqh is EA4
- issx_contracts.mqh is EA5
- issx_ui.mqh is aggregate UI/debug/HUD projection
- issx_debug_engine.mqh is the file debug sink
- issx_menu.mqh is chart-button menu UI

Current root wrapper truth:
- wrapper owns lifecycle and gating
- stage engines own stage business logic
- persistence owns file projection/handoff/root writes
- UI owns projection only
- debug engine owns log writing only

Do not break these boundaries.

Business-logic boundary rule:
- stage JSON/debug/export content is built by the stage engines or aggregate UI layer
- file projection and root projection are persistence responsibilities
- wrapper may orchestrate and log, but must not absorb stage business logic
- HUD must only project already-computed state


VERSION RULE
------------

Current working repo version baseline:
- 1.703

Every completed task increments by exactly +1 using MQL5-safe formatting:
- 1.703 -> 1.704 -> 1.705 -> 1.706 -> 1.707 -> 1.708 ...

Every successful task must synchronize all versioned ISSX source files:
- ISSX/ISSX.mq5
- ISSX/issx_core.mqh
- ISSX/issx_registry.mqh
- ISSX/issx_runtime.mqh
- ISSX/issx_persistence.mqh
- ISSX/issx_market_engine.mqh
- ISSX/issx_history_engine.mqh
- ISSX/issx_selection_engine.mqh
- ISSX/issx_correlation_engine.mqh
- ISSX/issx_contracts.mqh
- ISSX/issx_ui.mqh
- ISSX/issx_debug_engine.mqh
- ISSX/issx_menu.mqh

Version stamp normalization rule:
- each .mqh file should contain ONE canonical version stamp only
- remove redundant repeated textual version stamps
- do not remove diagnostic signatures that are not canonical version stamps
- do not break include guards
- do not change logic for version cleanup alone


GLOBAL SAFETY RULES
-------------------

1. NO UNBOUNDED LOOPS
Search for:
- while(true)
- for(;;)
- retry-until-ready without cap
- wait loops on external state

2. NO MQL4 DRIFT
Search for:
- LastError
- extern
- PositionSelectByIndex
- Ask
- Bid
- OrderSend
- OrderClose
- OrderSelect

3. NO FALSE HEALTH
A skipped stage must not look healthy.
A failed stage must not look intentionally off.
A partial stage must not look fully ready.

4. NO HEAVY HISTORY STORMS
All CopyRates/CopyBuffer/CopyTime requests must stay bounded.

5. NO LOG STORMS
Debug must stay sampled and grep-friendly.

6. NO WRAPPER STAGE LOGIC LEAK
Wrapper may orchestrate and log.
Wrapper must not own stage business logic.

7. TIMER SAFETY
Each enabled stage must remain bounded inside timer-driven execution.
If timer budget is exceeded, report degraded truthfully.

8. NO FAKE KERNEL HEALTH
Wrapper must not report kernel ok as if useful work ran when no enabled stage work actually ran.

9. NO CROSS-STAGE CONTAMINATION
A hardening run may touch many related modules, but only for the active stage focus.
No hidden enablement or partial work for downstream stages.

10. DEBUG FIRST, THEN DEEPER FIX
For large-scale growth runs:
- first strengthen surface/system debug truth enough to expose the real blocker
- then implement the deeper fix
- then strengthen per-task/per-stage debug where needed
- then test/report

11. HUD IS READ-ONLY
HUD may project state only.
HUD must not compute, infer, trigger, or own:
- discovery
- hydration
- selection
- correlation
- contracts
- CopyRates/CopyBuffer/CopyTime logic
- engine decisions

12. NO CHART OBJECT STORM
HUD/chart projection must reuse objects.
Do not recreate UI objects every timer pulse.

13. PERSISTENCE MUST BE TRUTHFUL
No root export/debug/status/universe file may imply a stronger stage state than the actual stage state.

14. NO FAKE EXPORT SUCCESS
Building JSON strings is not the same as writing files successfully.
Report build success and write success separately when relevant.

15. EXPORT CADENCE MUST BE BOUNDED
No root or snapshot export may write every timer pulse unless explicitly justified and bounded.

16. WRAPPER INPUT DISCIPLINE
Remove or rename misleading temporary forensic inputs when they no longer match real behavior.
Inputs must describe real runtime meaning.


FOUNDATION DEBUG CONTRACT
-------------------------

Every enabled foundation stage must report:

- stage_state | requested=...
- stage_state | effective=...
- stage_init | success/skipped/failed
- stage_run | success/skipped/degraded/failed
- stage_reason | why off / why degraded / why failed
- stage_elapsed_us or stage_elapsed_ms where relevant
- bounded counters relevant to that stage

Required stage names:
- ea1_market
- ea2_history
- ea3_selection
- ea4_correlation
- ea5_contracts

Minimum wrapper/system visibility still required:
- minimal_debug_mode
- isolation_mode
- runtime_scheduler
- timer_heavy_work
- ui_projection

Additional required truth:
- no enabled stage may silently disappear from logs
- if a stage is enabled but not entered, wrapper must report why
- wrapper must not report kernel ok when enabled stage pipeline did not actually run
- system-wide debug for the active surface must make failure attribution obvious
- stage-specific debug must explain success / degraded / failed in one review pass

Debug layering model for accelerated runs:
1. wrapper/system truth for active surface
2. active-stage execution truth
3. stage task counters/reasons
4. stage publish/projection truth
5. HUD projection of already-computed truth

HUD debug contract:
- HUD must show current system/state truth only
- HUD must display server time
- HUD must show main systems and subsystem states
- HUD must show stage states
- HUD must show active-stage detail
- HUD must not claim health that is not already present in system state

Projection/export debug contract:
- stage JSON build success must be visible
- debug JSON build success must be visible
- persistence/root projection success/skipped/failed must be visible where relevant
- if files were not written, report why
- if root projections are intentionally disabled, report that explicitly


FOUNDATION OPERATING BASELINE
-----------------------------

Current assumed safe baseline:
- minimal_debug_mode = ON
- isolation_mode = ON
- runtime_scheduler = OFF
- timer_heavy_work = OFF
- tick_heavy_work = OFF
- menu_engine = OFF
- chart_ui_updates = OFF
- ui_projection = OFF
- ea1_market = ON
- ea2_history = OFF
- ea3_selection = OFF
- ea4_correlation = OFF
- ea5_contracts = OFF

This board starts from that baseline.

Important baseline interpretation:
- minimal_debug_mode ON does NOT mean shell-only mode
- heavy systems may remain OFF by baseline
- enabled EA pipeline stages must still execute
- wrapper must allow EA stage pipeline execution under minimal mode

Heavy-system activation rule:
- once debug truth is strong enough for the active stage, a run may enable one heavier system for that same stage
- heavy system activation must stay truthful, bounded, and reversible
- heavy-system activation exists to accelerate validation, not to blur stage boundaries

EA1-specific interpretation:
- EA1 is not considered finished until discovery, stage publish, root/debug/universe projection truth, and HUD truth are all tested and credible


ENTRY / EXIT GATES
------------------

Before a task starts:
- prior required task must be SUCCESS, or
- prior task may be DEGRADED only if explicitly allowed by report and does not falsify downstream truth

Before moving to next task:
- current task must report one of:
  - success
  - degraded with exact reason and explicit next-task allowance
  - failed with exact reason and next-task blocked
- no silent success
- no skipped-but-healthy outcome

Per-stage activation gate:
- EA2 may not activate until EA1 is foundation-proven
- EA3 may not activate until EA1 and EA2 truth is proven
- EA4 may not activate until upstream selection truth is proven
- EA5 may not activate until upstream correlation/export inputs are truthful

Hardening gate:
- after selecting the winning variant and confirming runtime, the next run must also harden meaningful flaws found in that winner if they affect truth, boundedness, determinism, observability, publish/projection/export truth, or MT5 compile/runtime safety

EA1 exit gate:
EA1 is foundation-proven only when ALL of the following are true:
- wrapper timer path is truthful
- EA1 runs for real
- discovery cadence is bounded
- discovery ordering is deterministic
- EA1 stage logs are sufficient
- EA1 stage publish builds successfully
- EA1 debug snapshot builds successfully
- EA1 persistence/projection path is tested for intended outputs
- HUD reflects EA1 truth correctly
- input surface no longer contains misleading foundation-blocking nonsense for EA1 validation

EA2 exit gate:
EA2 is foundation-proven only when hydration is bounded, readiness truth is honest, and its persistence/projection surfaces do not fake healthy history


DEVELOPMENT EXECUTION MODEL
---------------------------

Use this operating model for each Codex cycle:

1. Surface Debug Pass
- inspect primary surface
- inspect all related modules required for the active stage
- strengthen wrapper/system truth enough to expose the actual blocker
- confirm no forbidden patterns in touched paths

2. Stage Truth Pass
- strengthen active-stage run/init/reason/elapsed/counter truth
- strengthen build/publish/projection truth if in scope
- ensure logs explain what actually happened

3. Deep Task Pass
- implement or harden the active stage task
- include required related-module edits
- keep stage isolation intact

4. Activation / Validation Pass
- activate only what is needed for the active stage
- test runtime behavior
- verify enabled stage code actually ran if expected
- verify wrapper only orchestrated/logged
- verify MQL5-only correctness
- verify static-definition correctness
- sync version
- produce required report

Parallel Codex strategy:
- generate 4 isolated variants
- variants should be intentionally diverse
- pick one winner only
- discard the other 3
- after runtime confirmation, next run should:
  - continue current stage if not yet proven
  - or move to next stage only if current stage is fully proven
  - and harden flaws found in the winning previous task
- hardening must remain within same stage isolation

Variant diversity guidance:
- Variant A: minimal/surgical
- Variant B: telemetry/debug-heavy
- Variant C: defensive/safety-heavy
- Variant D: encapsulation/accessor/clean contract-heavy


FOUNDATION TASKS
----------------

TASK F0 — BASELINE SHELL TRUTH CHECK
Primary surface:
- ISSX/ISSX.mq5

Goal:
Confirm the wrapper shell is stable enough to support foundation activation.

Must verify:
- timer alive
- canonical g_timer_pulse_count only
- sampled timer logs
- no log storm
- no false health signals
- current OFF systems clearly reported as OFF

Success criteria:
- shell stable for multi-minute run
- low-pressure logs
- no compile/runtime drift

--------------------------------------------------

TASK F0.5 — KERNEL ACTIVATION UNDER MINIMAL MODE
Primary surface:
- ISSX/ISSX.mq5

Goal:
Ensure the enabled EA pipeline runs under minimal mode while heavy systems remain OFF, unless one heavier system is intentionally activated for the active stage validation run.

Must ensure:
- OnTimer reaches the kernel pipeline path
- enabled stage pipeline can execute when minimal_debug_mode=ON
- runtime_scheduler and timer_heavy_work may remain OFF without blocking EA stage execution, unless timer_heavy_work is intentionally enabled for current stage validation
- wrapper reports truth if kernel pipeline is skipped
- wrapper does not claim kernel ok when no enabled stage work actually ran
- all of the above remain MT5-correct

Success criteria:
- EA1 StageSlice (or equivalent enabled stage path) is actually reached under minimal mode or approved heavy active-stage path
- logs show enabled stage execution, not heartbeat-only shell behavior
- no scheduler/menu/UI side-effects outside current scope
- no wrapper instability

--------------------------------------------------

TASK F1 — EA1 MARKET DISCOVERY CADENCE
Primary surface:
- ISSX/issx_market_engine.mqh

Goal:
Make market discovery run at a bounded cadence instead of every timer pulse.

Must ensure:
- discovery does not run every pulse
- first useful discovery still happens
- cadence state resets correctly on boot/reset
- cadence is deterministic
- class statics / globals used for cadence compile correctly in MQL5

Suggested implementation target:
- discovery_minute_id or equivalent bounded cadence state

Success criteria:
- discovery bounded
- first run still occurs
- no repeated full-universe storm

--------------------------------------------------

TASK F2 — EA1 MARKET DISCOVERY DETERMINISM
Primary surface:
- ISSX/issx_market_engine.mqh

Goal:
Make discovered universe deterministic across runs and broker ordering.

Must ensure:
- symbol universe sorted before downstream use
- filters preserve deterministic ordering
- no broker-order-dependent loops remain in active discovery path
- deterministic ordering happens at one canonical universe handoff point
- wrapper reads telemetry only; discovery business logic stays in engine

Success criteria:
- same inputs -> same ordered symbol universe
- no hidden broker-order randomness

--------------------------------------------------

TASK F3 — EA1 MARKET SUPER-DEBUG
Primary surface:
- ISSX/issx_market_engine.mqh
- tightly coupled wrapper touch only if required

Goal:
Add focused super-debug for EA1 only.

Must report:
- discovery attempted or skipped
- discovery cadence reason
- number of raw symbols seen
- number accepted / degraded / rejected
- elapsed time
- success / degraded / failed marker
- reason if no useful universe produced

Success criteria:
- log review can explain exactly what EA1 did
- no log storm

--------------------------------------------------

TASK F3.5 — EA1 PUBLISH / PROJECTION TRUTH
Primary surface:
- ISSX/issx_market_engine.mqh
- ISSX/issx_persistence.mqh
- tightly coupled wrapper touch required if needed
- tightly coupled UI projection touch allowed if needed

Goal:
Make EA1 publish/build/projection truth explicit and testable.

Must ensure:
- stage JSON build success is visible
- debug snapshot JSON build success is visible
- universe dump build success is visible
- file projection/write success is visible where intended
- root debug/status/universe projection success is visible where intended
- “JSON built” and “file written” are not conflated
- export cadence is bounded and not every pulse unless intentionally justified
- persistence owns file writes, not the market engine

Success criteria:
- log review can explain exactly what EA1 built, what was written, what was skipped, and why
- no fake export success
- no file storm

--------------------------------------------------

TASK F3.75 — HUD PROJECTION LAYER
Primary surface:
- ISSX/issx_ui.mqh
- tightly coupled wrapper touch required
- tightly coupled state exposure touch only if required

Goal:
Add or repair a read-only HUD that displays current ISSX system state on chart.

Must ensure:
- HUD does not calculate systems
- HUD only displays already-computed state
- HUD updates from OnTimer path, not OnTick
- HUD uses MT5 chart object APIs correctly
- HUD reuses objects and does not recreate them every timer pulse
- HUD shows server time using a proper server/trade-server time source
- HUD shows all major feature states and subsystem states
- HUD shows all stage states
- HUD shows EA1 detail block when available
- fallback attach/wait banner does not override or hide active HUD

Minimum HUD content:
- version
- server time
- timer pulse
- kernel state/result
- minimal_debug_mode
- isolation_mode
- runtime_scheduler
- timer_heavy_work
- tick_heavy_work
- menu_engine
- chart_ui_updates
- ui_projection
- EA1 Market
- EA2 History
- EA3 Selection
- EA4 Correlation
- EA5 Contracts
- EA1 discovery state / symbol count / elapsed / reason
- EA1 publish/projection state if available

Success criteria:
- HUD is visible
- HUD is read-only
- HUD reflects actual current state
- no object storm
- no fake health projection

--------------------------------------------------

TASK F4 — EA1 ACTIVATE AS FOUNDATION-PROVEN
Primary surface:
- ISSX/issx_market_engine.mqh
- tightly coupled wrapper/persistence/UI touch only if required

Goal:
Run EA1 as the first proven active stage.

Must ensure:
- EA1 produces deterministic usable upstream truth
- no repeated heavy discovery
- no wrapper instability
- no fake-ready signals
- enabled EA1 actually runs under wrapper timer path
- wrapper only orchestrates/logs and does not absorb market logic
- if one heavier system was enabled for EA1 validation, it remains bounded and truthful
- HUD reflects EA1 truth correctly
- publish/projection/export truth is credible and tested
- misleading EA1-era forensic toggles are removed, renamed, or made truthful

Success criteria:
- EA1 judged SUCCESS
- next task allowed

--------------------------------------------------

TASK F5 — EA2 HISTORY HYDRATION BOUNDS
Primary surface:
- ISSX/issx_history_engine.mqh

Goal:
Make history hydration bounded and safe before enabling it.

Must ensure:
- max_symbols_per_slice or equivalent cap is respected
- CopyRates / related calls stay bounded
- no large synchronous history storm
- retries are bounded
- unsynchronized series do not cause heavy repeat storms
- per-slice hydration work stays bounded for timer execution
- bars-per-request cap exists if required
- warehouse shard/index writes remain bounded if active

Success criteria:
- bounded requests only
- no repeated heavy retries
- no terminal pressure spikes

--------------------------------------------------

TASK F6 — EA2 HISTORY READINESS TRUTH
Primary surface:
- ISSX/issx_history_engine.mqh

Goal:
Hydration must report honest readiness.

Must ensure:
- minimum-ready and deep-ready are distinct if both exist
- missing history does not appear fully ready
- partial hydration is reported as degraded, not success
- stale or unsynchronized data is visible
- projection/export does not overstate readiness

Success criteria:
- readiness is truthful
- no fake “history good” signal

--------------------------------------------------

TASK F7 — EA2 HISTORY SUPER-DEBUG
Primary surface:
- ISSX/issx_history_engine.mqh
- tightly coupled wrapper/persistence/UI touch only if required

Goal:
Add focused super-debug for EA2 only.

Must report:
- hydration attempt
- symbols processed this slice
- bounded request count
- sync/unavailable status
- retries/backoff status
- ready/degraded/failed result
- elapsed time
- warehouse/projection state if active

Success criteria:
- log review can explain exactly why hydration succeeded, degraded, or failed
- no file/log pressure storm

--------------------------------------------------

TASK F8 — ACTIVATE EA2 AS FOUNDATION-PROVEN
Primary surface:
- ISSX/issx_history_engine.mqh
- tightly coupled wrapper/persistence/UI touch only if required

Goal:
Turn ON EA2 only after EA1 is proven.

Must ensure:
- EA2 consumes real EA1 upstream data
- hydration remains bounded
- no repeated full-history storm
- readiness truth remains honest
- persistence/projection truth remains honest if active

Success criteria:
- EA2 judged SUCCESS
- next task allowed

--------------------------------------------------

TASK F9 — EA3 SELECTION INPUT TRUTH
Primary surface:
- ISSX/issx_selection_engine.mqh

Goal:
Ensure EA3 only runs on valid upstream truth.

Must ensure:
- selection does not treat incomplete EA1/EA2 state as fully ready
- bounded candidate processing
- no unstable flapping without explanation
- reserve/frontier logic does not pretend readiness
- upstream degraded state remains visible

Success criteria:
- EA3 respects upstream readiness truth
- bounded selection path

--------------------------------------------------

TASK F10 — EA3 SELECTION SUPER-DEBUG + ACTIVATE
Primary surface:
- ISSX/issx_selection_engine.mqh

Goal:
Add focused EA3 super-debug, then enable EA3 only.

Must report:
- candidate input counts
- rejected vs eligible counts
- frontier/reserve outputs
- degraded reasons
- success/failure markers
- elapsed time

Success criteria:
- EA3 judged SUCCESS
- next task allowed

--------------------------------------------------

TASK F11 — EA4 CORRELATION BOUNDS
Primary surface:
- ISSX/issx_correlation_engine.mqh

Goal:
Bound pair processing before enabling EA4.

Must ensure:
- no universe explosion
- pair comparisons capped
- degraded/abstain paths truthful
- no hidden O(n^2) blow-up on large sets without cap
- pair work remains safe inside timer slices

Success criteria:
- bounded pair work
- truthful abstention/degraded reasons

--------------------------------------------------

TASK F12 — EA4 CORRELATION SUPER-DEBUG + ACTIVATE
Primary surface:
- ISSX/issx_correlation_engine.mqh

Goal:
Add focused EA4 super-debug, then enable EA4 only.

Must report:
- symbols/pairs considered
- bounded pair count
- abstentions
- overlap/correlation result status
- degraded/failure reason
- elapsed time

Success criteria:
- EA4 judged SUCCESS
- next task allowed

--------------------------------------------------

TASK F13 — EA5 CONTRACT/EXPORT BOUNDS
Primary surface:
- ISSX/issx_contracts.mqh

Goal:
Ensure final export stays bounded and truthful before enablement.

Must ensure:
- payload generation bounded
- no export storm
- no false integrity/freshness signals
- partial upstream truth does not masquerade as final-good output
- output build remains safe under timer-driven execution

Success criteria:
- bounded final build
- truthful export contract state

--------------------------------------------------

TASK F14 — EA5 CONTRACTS SUPER-DEBUG + ACTIVATE
Primary surface:
- ISSX/issx_contracts.mqh

Goal:
Add focused EA5 super-debug, then enable EA5 only.

Must report:
- upstream readiness seen
- payload/export result
- bounded output counters
- degraded/failure reasons
- integrity/freshness visibility
- elapsed time

Success criteria:
- EA5 judged SUCCESS
- foundation pipeline judged working

--------------------------------------------------

TASK F15 — FOUNDATION INTEGRATION CHECK
Primary surface:
- ISSX/ISSX.mq5

Goal:
After EA1–EA5 are each proven individually, verify the full chain together.

Must ensure:
- EA1 -> EA2 -> EA3 -> EA4 -> EA5 chain runs coherently
- no stage lies about upstream truth
- no major timer pressure
- no log storm
- no hidden dependency break
- HUD still reflects system truth correctly if enabled
- root projections/export/status remain coherent across the chain

Success criteria:
- full foundational pipeline works together
- foundation complete


PRIORITY ORDER
--------------

Do these now, in this exact order:

0. TASK F0 — baseline shell truth check
0.5 TASK F0.5 — kernel activation under minimal mode
1. TASK F1 — EA1 market discovery cadence
2. TASK F2 — EA1 market discovery determinism
3. TASK F3 — EA1 market super-debug
3.5 TASK F3.5 — EA1 publish / projection truth
3.75 TASK F3.75 — HUD projection layer
4. TASK F4 — activate EA1 as foundation-proven
5. TASK F5 — EA2 history hydration bounds
6. TASK F6 — EA2 history readiness truth
7. TASK F7 — EA2 history super-debug
8. TASK F8 — activate EA2 as foundation-proven
9. TASK F9 — EA3 selection input truth
10. TASK F10 — EA3 selection super-debug + activate
11. TASK F11 — EA4 correlation bounds
12. TASK F12 — EA4 correlation super-debug + activate
13. TASK F13 — EA5 contracts/export bounds
14. TASK F14 — EA5 contracts super-debug + activate
15. TASK F15 — foundation integration check


STAGE-BATCH EXECUTION PLAN
--------------------------

Use broader runs inside one stage only.

EA1 run set:
- F0.5 + F1 + F2 + F3 + F3.5 + F3.75 + F4 hardening as needed
- wrapper + market + persistence + UI + debug + runtime + other directly related modules may be touched together if required
- only EA1 active
- one heavier system may be enabled for EA1 validation after debug truth is strong enough
- EA1 is NOT done until discovery, publish/projection truth, and HUD truth are all proven

EA2 run set:
- F5 + F6 + F7 + F8 hardening as needed
- history + wrapper + persistence + UI/debug/runtime + other directly related modules may be touched together if required
- only EA2 newly enabled after EA1 proven

EA3 run set:
- F9 + F10 hardening as needed
- selection + wrapper/debug/runtime/persistence + other directly related modules may be touched together if required
- only EA3 newly enabled after upstream truth proven

EA4 run set:
- F11 + F12 hardening as needed
- correlation + wrapper/debug/runtime/persistence + other directly related modules may be touched together if required
- only EA4 newly enabled after upstream truth proven

EA5 run set:
- F13 + F14 hardening as needed
- contracts + wrapper/debug/runtime/persistence + other directly related modules may be touched together if required
- only EA5 newly enabled after upstream truth proven

Final run:
- F15 only unless related wrapper/debug/runtime/persistence integration truth requires coupled touches

Note:
- stage isolation does not change
- batching is allowed only inside the same stage focus
- next run should also harden flaws found in the previously selected winning patch
- if related modules are necessary, edit them in the same run rather than forcing artificial fragmentation
- do not advance stages early just because one partial test looked good


PER-TASK REQUIRED REPORT
------------------------

Every Codex run must report:

PRIMARY ISSUE
PRIMARY SURFACE
RELATED GLOBAL ISSUES
OLD EAS FINDINGS
MODULE INVARIANT CHECK
SUGGESTED EXTRA CHECK RESULT
FIX
PATCH
TEST RESULT
- targeted stage/system
- enabled state
- observed behavior
- success / degraded / failed
- exact reason
- whether next task is allowed
VERSION BUMP
- previous version
- new version
- files updated
REGRESSION RISK

Additional report requirements:
- explicitly state whether enabled stage code actually ran
- explicitly state whether wrapper only orchestrated/logged
- explicitly state whether previous winning patch weaknesses were hardened in this run
- explicitly state which related modules were touched and why they were necessary
- explicitly state whether this run was:
  - debug-first
  - stage-truth
  - deep-task
  - mixed hardening
  - activation validation
- explicitly state whether a heavier system was enabled in this run and why
- explicitly state whether MQL5-only correctness was preserved
- explicitly state whether static-definition safety was preserved
- explicitly state whether publish/build/projection truth was validated if in scope
- explicitly state whether HUD was implemented, read-only, server-time correct, and actually visible if HUD was in scope
- explicitly state whether new controls defaulted to TRUE and why if they did not


PATCH SIZE POLICY
-----------------

Patch size is controlled by STAGE SCOPE and RELATED SURFACE, not by tiny line caps.

Soft limit:
- 300 lines net change

Standard run target:
- up to 600 lines net change

Heavy foundation run:
- up to 1000 lines net change

Hardening / activation run:
- up to 1200 lines net change

Absolute max:
- 1500 lines net change

Large patches are acceptable when ALL of the following are true:
- ONE active stage focus only
- changes are required to make that active stage truthful, bounded, deterministic, runnable, publishable, exportable, or observable
- related modules touched are necessary, not decorative
- no multi-stage enablement
- no architecture redesign
- report remains truthful and reviewable

Large patches are NOT acceptable when they:
- mix multiple new stage activations
- hide speculative cleanup inside foundation work
- blur failure attribution
- introduce broad unrelated refactors


NOTE
----

This board intentionally ignores non-foundation work for now:
- menu polish
- UI polish beyond foundation HUD/status projection
- persistence polish beyond required foundation export truth
- deep scheduler archaeology
- final hardening sweeps

Those can come later.

Right now the mission is:
GET THE FOUNDATION DATA PIPELINE WORKING TRUTHFULLY AND SAFELY.

And do it with:
- stage isolation
- fast multi-pass growth
- debug-first truth
- stage-truth first
- deep stage hardening
- activation/testing/reporting
- large but controlled related-surface edits when necessary
- MT5-correct implementation
- persistence truth
- HUD as a read-only projection layer


MANUAL CHECKLIST
----------------
ISSX FOUNDATION TRACKER — 3 TIER STATUS

Status values:
done
wip
pending

--------------------------------------------------
[global]
--------------------------------------------------

board_version=done
target_platform_mt5=done
mql5_only_rules_applied=done

current_repo_version=wip
current_step=wip
current_active_stage=done

foundation_complete=pending


--------------------------------------------------
[baseline]
--------------------------------------------------

f0_shell_stable=done
f0_no_log_storm=done
f0_false_health_removed=done
f0_timer_alive=done


--------------------------------------------------
[wrapper_runtime]
--------------------------------------------------

f0_5_kernel_path_reached=done
f0_5_enabled_stage_can_run_under_minimal=done
f0_5_kernel_result_truthful=done
f0_5_wrapper_orchestration_only=done

timer_heavy_work_intentionally_enabled=done
runtime_scheduler_kept_off=done


--------------------------------------------------
[ea1]
--------------------------------------------------

f1_cadence_done=done
f1_first_run_works=done
f1_same_minute_skip_works=done
f1_no_discovery_storm=done
f1_static_definition_safe=done


f2_determinism_done=done
f2_sorted_universe_done=done
f2_no_broker_order_dependency=done


f3_super_debug_done=done
f3_discovery_attempt_visible=done
f3_discovery_skip_visible=done
f3_discovery_success_visible=done
f3_reason_visible=done
f3_elapsed_visible=done


f3_5_publish_truth_done=wip
f3_5_stage_json_build_visible=wip
f3_5_debug_json_build_visible=wip
f3_5_universe_dump_visible=wip
f3_5_projection_write_visible=wip
f3_5_no_fake_export_success=wip


f3_75_hud_done=wip
f3_75_hud_read_only=done
f3_75_hud_server_time_done=done
f3_75_hud_main_systems_done=wip
f3_75_hud_subsystems_done=wip
f3_75_hud_stage_states_done=wip
f3_75_hud_ea1_detail_done=wip
f3_75_hud_no_object_storm=wip
f3_75_hud_visible=done


f4_ea1_runs_for_real=done
f4_ea1_publish_truth_proven=wip
f4_ea1_hud_truth_proven=wip
f4_ea1_foundation_proven=wip
f4_ea1_truthful_logs=wip


--------------------------------------------------
[ea2]
--------------------------------------------------

f5_bounds_done=pending
f5_copyrates_bounded=pending
f5_retry_cap_done=pending
f5_warehouse_writes_bounded=pending

f6_readiness_truth_done=pending
f6_partial_is_degraded=pending
f6_no_fake_ready=pending

f7_super_debug_done=pending
f8_ea2_foundation_proven=pending


--------------------------------------------------
[ea3]
--------------------------------------------------

f9_input_truth_done=pending
f9_bounded_selection=pending
f10_super_debug_done=pending
f10_ea3_foundation_proven=pending


--------------------------------------------------
[ea4]
--------------------------------------------------

f11_bounds_done=pending
f11_pair_cap_done=pending
f12_super_debug_done=pending
f12_ea4_foundation_proven=pending


--------------------------------------------------
[ea5]
--------------------------------------------------

f13_bounds_done=pending
f13_export_truth_done=pending
f14_super_debug_done=pending
f14_ea5_foundation_proven=pending


--------------------------------------------------
[integration]
--------------------------------------------------

f15_integration_done=pending
f15_full_chain_runs=pending
f15_no_hidden_dependency_break=pending
f15_root_projection_coherent=pending


--------------------------------------------------
[reporting]
--------------------------------------------------

last_run_success=wip
last_run_degraded=pending
last_run_failed=pending
last_run_reason_recorded=wip

next_task_allowed=wip
version_bump_synced=wip

hud_visible_in_terminal=done
publish_projection_truth_verified=wip
