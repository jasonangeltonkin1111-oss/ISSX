ISSX MASTER BLUEPRINT v1.7.2

CODING-READY BUILD SPEC

STATUS: SINGLE-EA CONSOLIDATED KERNEL BLUEPRINT — HARDENED MT5-SAFE REVISION + ANTI-DRIFT ENFORCEMENT EXPANSION

SCOPE: MT5-only one-wrapper analytics kernel + 5 logical internal stages + EA5 GPT-ready export

INTENT: patch-friendly evolution from current v1.5.0/v1.6.x/v1.7.0/v1.7.1 modules, one EA only, no monolith regression, strict compile governance, strict ownership discipline, strong persistence, rolling hydration, full broker/history internal dumps, bounded runtime, minute-scale readiness, honest degradation, broad-but-honest opportunity coverage, trader-handoff-ready winner context, and aggressive prevention of future compiler drift, contract drift, include drift, and assistant-induced mismatch cascades



IMPORTANT REALITY RULE

\- Literal “nothing can ever go wrong” is impossible in MT5.

\- This blueprint is designed so failure becomes:

&nbsp; 1) bounded

&nbsp; 2) visible

&nbsp; 3) recoverable

&nbsp; 4) non-silent

&nbsp; 5) non-drifting

&nbsp; 6) diagnosable at owner boundary

&nbsp; 7) less likely to recur after patching

&nbsp; 8) contract-auditable before compile fallout expands

&nbsp; 9) assistant-correctable with fewer patch waves

&nbsp; 10) isolated from unrelated modules whenever practical



CHANGE INTENT FROM v1.7.1

\- Preserve one human-facing EA:

&nbsp; - ISSX.mq5

\- Preserve 5 logical internal stages:

&nbsp; - ea1 MarketStateCore

&nbsp; - ea2 HistoryStateCore

&nbsp; - ea3 SelectionCore

&nbsp; - ea4 IntelligenceCore

&nbsp; - ea5 ConsolidationCore

\- Preserve stage ownership, stage contracts, stage persistence, stage acceptance, and stage failure boundaries.

\- Preserve the current 10 shared engine modules as the primary target.

\- Preserve non-directional design:

&nbsp; - no entry logic

&nbsp; - no SL/TP logic

&nbsp; - no long/short bias

&nbsp; - no portfolio/risk rules

\- Preserve broad symbol opportunity coverage without dishonest quality collapse.

\- Preserve timer realism, completed-bar discipline, generation coherence, and fallback honesty.

\- Preserve blueprint-first patch workflow.

\- Add hard contract-version governance.

\- Add hard compatibility-alias lifecycle doctrine.

\- Add hard include-path canonicalization doctrine.

\- Add hard owner-surface stability doctrine.

\- Add hard compile-gate and anti-cascade doctrine.

\- Add hard assistant self-audit doctrine before returning code.

\- Add hard symbol-name / enum-name / field-name drift prevention rules.

\- Add hard signature-lock and manifest-lock doctrine.

\- Add hard cross-file patch-wave completeness doctrine.

\- Add implementation guide language so future coding passes can build and patch ISSX with fewer regressions and fewer secondary error explosions.



======================================================================

0\. SYSTEM PURPOSE

======================================================================



ISSX is a single-EA, timer-driven, MT5 analytics kernel.



It contains 5 logical internal stages:

\- ea1 = MarketStateCore

\- ea2 = HistoryStateCore

\- ea3 = SelectionCore

\- ea4 = IntelligenceCore

\- ea5 = ConsolidationCore



GOALS

\- Eventual best-effort enumeration of terminal-known broker symbols with explicit unreadable / unresolved states

\- Stable family / alias dedupe

\- Truthful classification into theme buckets / optional equity sectors

\- Full-universe broker/spec/observability/session/tradeability truth

\- Full-universe history warehouse with rolling OHLC storage and integrity truth

\- Top 5 per bucket chosen by balanced intraday usability, truth, friction, activity, freshness, and diversity context

\- Sparse cross-symbol overlap intelligence on bounded frontier

\- Rich winner-only EA5 export every 10 minutes

\- Non-directional regime/context export strong enough for downstream scalp / intraday trade-idea generation

\- No directional signals in ISSX

\- Strong stage-local and kernel-level debug visibility

\- Internal persistence that handles safety and recovery

\- Runtime work that remains bounded on imperfect timer cadence

\- Rolling hydration that improves depth over time without stalling first useful output

\- Future indicator / strategy / library modules that can consume accepted stage truths cleanly



NON-GOALS

\- No direct trading in this version

\- No entry / stop / target output

\- No directional recommendation

\- No dense full-universe pairwise correlation

\- No single giant mega-payload as truth

\- No return to wrapper-driven orchestration

\- No silent reinterpretation of upstream facts

\- No wasteful full-rescan behavior every minute

\- No dependence on fallback as normal operating mode

\- No claim that all broker data or all history are instantly available on startup

\- No transformation of ISSX into a strategy engine, signal engine, or portfolio optimizer





ADDITIONAL PURPOSE HARDENING

\- ISSX must not only be architecturally correct; it must also be patch-stable under repeated chat-based modification.

\- Shared contract drift must be treated as a first-class failure domain equal in importance to persistence corruption or scheduler dishonesty.

\- The blueprint is not merely descriptive architecture; it is an operational anti-drift control system for future assistant work.



======================================================================

1\. NON-NEGOTIABLE GOVERNING RULES

======================================================================



RULE G1: ONE THIN WRAPPER, FIVE LOGICAL STAGES

\- Use one human-facing EA wrapper only:

&nbsp; - ISSX.mq5

\- Keep 5 logical internal stages:

&nbsp; - ea1..ea5

\- Put almost all logic in shared .mqh engine modules.

\- Wrapper owns orchestration only, not stage business logic.



RULE G2: STAGE ISOLATION SURVIVES TOPOLOGY CHANGE

\- One wrapper does not mean one logical stage.

\- Each stage must remain independently publishable, independently recoverable, independently diagnosable, and independently persistable.

\- A fault in ea4 must not silently corrupt ea1 accepted truth.



RULE G3: TRUTH STATE, WORK STATE, AND PROJECTION STATE ARE DISTINCT

\- Accepted truth state is authoritative stage truth.

\- Work progress state is resumable scheduler / queue / phase machinery.

\- Projection state is public / internal view material.

\- None may silently masquerade as another.



RULE G4: ROOT FILES ARE VIEWS, NOT TRUTH

\- Public outputs are convenience views only.

\- Internal accepted snapshot + manifest chain are authoritative truth.

\- Recovery never depends only on public JSON.



RULE G5: EA1-EA4 ARE DATA-RICH, MT5-ONLY

\- Upstream stages remain technical and MT5-facing.

\- They are not optimized for GPT.



RULE G6: EA5 IS THE ONLY PRIMARY EXTERNAL CONTRACT

\- EA5 is the only primary user-facing export.

\- EA5 must remain self-describing and closed-world.



RULE G7: TIMER DELIVERY IS LOSSY

\- Work is resumable and minute-scoped.

\- Never assume every timer beat is delivered.

\- Never infer scheduling correctness from timer pulse counts.

\- Publish freshness beats deep enrichment under deadline pressure.



RULE G8: EVERY EXPORTED FIELD HAS ONE OWNER

\- Ownership remains stage-specific.

\- The kernel wrapper owns no semantic market / history / selection / intelligence facts.



RULE G9: ACCEPTED CURRENT IS DISTINCT FROM CANDIDATE CURRENT

\- Candidate writes are not truth until accepted and promoted.

\- Same-cycle in-memory availability does not weaken this rule.



RULE G10: PHASE PROGRESS IS PERSISTED

\- Every stage must divide work into resumable phases.

\- Work resume is valid only if resume compatibility checks pass.



RULE G11: COMPATIBILITY PRECEDES FALLBACK

\- Internal current / previous / last\_good may only be consumed if compatibility checks pass.

\- Schema compatibility alone is insufficient where policy semantics changed.



RULE G12: CONTINUITY IS FIRST-CLASS TRUTH

\- Streaks, flaps, cooldowns, resumed states, stability windows, and repeated fallback states are authoritative operational facts.



RULE G13: BUDGETS MUST BE EXPLICIT

\- Every stage must account for bounded runtime budgets.

\- Commit and publish budgets are always reserved.

\- Every stage slice must also respect hard runtime cap and work-unit cap.



RULE G14: STRUCTURAL CONTEXT MAY EXIST, BUT NEVER AS SIGNAL

\- Structural metrics remain neutral context only.

\- Regime descriptors may exist, but must never encode directional bias.



RULE G15: FULL INTERNAL DUMPS ARE MANDATORY WHERE OWNED

\- EA1 must maintain a full broker-universe dump internally for readable stage-owned truth.

\- EA2 must maintain a full history-universe rolling warehouse internally for synchronized retained scope.

\- “Full” means complete for owned truth and current observable synchronized scope, not impossible omniscience.



RULE G16: FAST OUTPUT MUST NOT WAIT FOR DEEP COMPLETION

\- The kernel must publish minimum useful truth before full deep hydration completes.

\- Deep coverage improves over later cycles.



RULE G17: DEBUG MUST EXPOSE WEAK LINKS EARLY

\- Stage failures, readiness blocks, queue starvation, compatibility drops, repeated fallback, and publish degradation must be visible in structured trace lines and debug snapshots.



RULE G18: MAIN FLOW MUST BE STRONGER THAN FALLBACK FLOW

\- Fallback is emergency tooling, not normal flow.

\- Accepted current + valid phase resume + valid cache reuse + delta-first hydration are the primary operating path.



RULE G19: NEVER LET ONE STAGE STARVE THE WHOLE EXPERIENCE

\- Deep EA2 hydration must not starve EA1 freshness.

\- EA4 pair work must not starve EA3 frontier maintenance.

\- EA5 export must not starve upstream freshness work.

\- Optional enrichment must yield first.



RULE G20: NEVER LET ONE WEAK LINK SILENTLY BREAK EVERYTHING

\- Every stage must publish dependency block reasons and degradation causes.

\- Downstream stages must degrade honestly instead of deadlocking invisibly.



RULE G21: NO MONOLITH REGRESSION

\- The wrapper may never absorb ranking, correlation, acceptance, serializer, or stage file-flow logic.



RULE G22: UNKNOWN MUST NOT MASQUERADE AS SAFE

\- Unknown correlation must not look like low correlation.

\- Unknown history must not look like weak-but-usable history.

\- Unknown tradeability must not look like cheapness.

\- Missing must not look like zero.

\- Default-initialized state must not silently imply healthy or strong.



RULE G23: PUBLIC HEALTH MUST REFLECT FALLBACK HABIT

\- Prolonged fallback use, prolonged degraded publishes, or repeated same weak-link cycles must downgrade the kernel health banner even if outputs still exist.



RULE G24: BREADTH-WITH-HONESTY

\- ISSX should prefer truthful breadth over narrow false purity.

\- Mild-to-moderate uncertainty should usually reduce score, not erase candidacy.

\- Hard exclusion is reserved for severe integrity failures.

\- Soft penalties are preferred over binary exile whenever safety is not compromised.



RULE G25: RANKABILITY MUST BE ELASTIC, NOT BINARY-HEAVY

\- When strong candidates are thin, degrade honestly and widen comparison lanes rather than collapsing buckets prematurely.

\- Strong / usable / exploratory participation must remain visibly distinct.



RULE G26: NO PERMANENT LOW-RANK EXILE WITHOUT RECHECK

\- Any symbol that is eligible, not permanently blocked, and not family-merged away must periodically re-enter meaningful re-evaluation lanes.



RULE G27: TRADER-HANDOFF CONTEXT MUST REMAIN NON-DIRECTIONAL

\- Winner context may describe liquidity, volatility, movement, session phase, cleanliness, constructability, and redundancy.

\- It must never imply buy / sell, breakout direction, or execution advice.



RULE G28: WARNING-ZEROING IS MANDATORY

\- All compiler warnings that imply truncation, narrowing, sign-loss, silent defaulting, or suspicious shadowing are defects, not cosmetic noise.

\- ISSX should target zero warnings for all load-bearing code.



RULE G29: INCLUDE GRAPH GOVERNANCE IS MANDATORY

\- All internal ISSX includes must use angle-bracket form:

&nbsp; - <ISSX/...>

\- Mixed include style is forbidden for ISSX-owned files.

\- No module may rely on transitive includes for required types.



RULE G30: SHARED ENUM / TYPE OWNERSHIP IS MANDATORY

\- Shared semantic enums and shared DTOs may be owned only by issx\_core.mqh unless explicitly declared otherwise in this blueprint.

\- Registry may reference shared enums but may not redefine them.

\- UI may display shared enums but may not redefine them.

\- Engine modules may define only stage-local enums.



RULE G31: LEGACY COMPATIBILITY MAY EXIST ONLY IN CORE OR REGISTRY

\- Any historical alias, compatibility macro, or transitional helper may only be implemented in shared owner files.

\- Stage modules must not contain legacy-vs-new branching logic for shared contracts.



RULE G32: JSON / SNAPSHOT WRITER HAS ONE OWNER

\- ISSX\_JsonWriter is core-owned.

\- No stage may create a parallel JSON dialect, parallel writer, or duplicate shared JSON helper method family.



RULE G33: NO ACCIDENTAL COMPILE VIA INCLUDE ORDER

\- Every .mqh must include every header required for the symbols it directly uses.

\- No file may compile only because another unrelated header happened to include its dependency first.



RULE G34: COMPLETED-BAR TRUTH IS HARD

\- CopyRates index 0 is never assumed to be a completed bar.

\- Forming bars must be explicitly requested and explicitly flagged.

\- Any completed-bar pack that silently includes index 0 is invalid.



RULE G35: DETERMINISTIC ENCODING IS MANDATORY

\- All hashing, fingerprinting, and persistence string-to-byte conversions must use deterministic UTF-8 encoding.

\- Stable ordering before hashing is mandatory.



RULE G36: STAGE API SURFACE IS FIXED AND MANDATORY

Each stage class must expose exactly these minimum public entry points:

\- StageBoot

\- StageSlice

\- StagePublish

\- BuildDebugSnapshot

Optional:

\- BuildStageJson

\- BuildDebugJson

\- ExportOptionalIntelligence

Signatures must be stable across modules unless schema version or stage API version is intentionally changed.



RULE G37: SAFE DEFAULTS MUST BE UNKNOWN OR NA, NOT HEALTHY

\- Any default enum value for health / trust / validity / publishability / acceptance / readiness must map to Unknown, NotReady, NA, or equivalent.

\- Healthy / Strong / Safe may never be the zero-default unless explicitly justified and documented.







RULE G38: CONTRACT RENAMES MAY NEVER BE SILENT

\- If any shared enum member, field key, DTO field, helper name, stage API name, manifest field, or compatibility symbol is renamed, the owner module must preserve the prior name through an explicit compatibility alias layer for at least one blueprint version cycle unless the blueprint explicitly declares a hard removal.

\- Silent renames are forbidden.

\- “Search and replace later” is forbidden.

\- Downstream modules must not be forced to infer semantic replacement.



RULE G39: OWNER MODULE MUST EXPORT COMPATIBILITY SHIMS

\- When shared contract evolution occurs, only the owner module may provide compatibility macros / aliases / adapters.

\- Downstream stage files may consume the compatibility surface but may not define their own recovery aliases.

\- Core owns shared semantic aliasing.

\- Registry may own registry-local aliasing only where blueprint explicitly allows it.

\- Compatibility shims must be documented with:

&nbsp; - old symbol

&nbsp; - new symbol

&nbsp; - semantic equivalence class

&nbsp; - deprecation phase

&nbsp; - removal eligibility version



RULE G40: INCLUDE PATH IDENTITY MUST BE SINGULAR

\- The same ISSX file may not be included through multiple path identities.

\- If the canonical include path is `<ISSX/issx\_core.mqh>`, then including `"issx\_core.mqh"` anywhere is forbidden.

\- No relative-path alternative, mirrored include path, symlink-style alias path, or duplicate folder-root variant may exist in patched output.

\- Include guards do not excuse path duplication risk.



RULE G41: SHARED CONTRACT CHANGES REQUIRE PATCH-WAVE COMPLETENESS

\- Any change to a shared symbol owned by core / registry / persistence / runtime contract surfaces requires a same-wave audit of all dependent modules.

\- A patch is incomplete if owner and consumers are knowingly left out-of-sync.

\- “I only changed one file” does not excuse contract breakage if the change is cross-file by nature.

\- If full downstream repair cannot be performed in the current pass, the owner file must preserve compatibility via alias layer rather than breaking consumers.



RULE G42: FIRST COMPILE FAILURE MUST BE TREATED AS ROOT-CAUSE CANDIDATE

\- When multiple errors appear, the earliest shared-owner failure must be treated as the primary suspect until disproven.

\- Large downstream error floods must not trigger scattered local hacks before owner-surface audit is completed.

\- Parser spill, missing owner type, include drift, and compatibility rename failures outrank local syntax noise.



RULE G43: ASSISTANT MAY NOT “MODERNIZE” SEMANTIC NAMES WITHOUT COMPATIBILITY PLAN

\- Renaming `publishable` to `usable`, `full` to `strong`, or similar semantic modernizations is forbidden unless:

&nbsp; 1) the blueprint explicitly authorizes the migration,

&nbsp; 2) the owner file adds compatibility aliases,

&nbsp; 3) affected downstream consumers are patched in the same wave, or

&nbsp; 4) the assistant clearly states that the pass is an intentional coordinated migration.

\- Stylistic renames without compatibility planning are drift defects.



RULE G44: SHARED DTO SHAPE IS LOCKED BY VERSION

\- Adding, removing, or renaming DTO fields in shared structs is a contract change.

\- Contract changes require:

&nbsp; - schema version review

&nbsp; - serializer version review if persisted

&nbsp; - manifest compatibility review if surfaced

&nbsp; - consumer compile review

&nbsp; - reset/default review

\- DTO shape drift without version review is forbidden.



RULE G45: ENUM MEMBER EVOLUTION MUST PRESERVE SEMANTIC LATTICE

\- Shared enums may evolve only with explicit semantic mapping.

\- Removing an enum member requires either:

&nbsp; - alias mapping to successor meaning, or

&nbsp; - explicit hard removal declaration in blueprint plus same-wave downstream updates.

\- Reordering shared enum numeric values is forbidden unless proven safe and reviewed against persistence / arrays / switch logic / defaults.



RULE G46: DEFAULTS MUST NOT BECOME STRONGER DURING REFACTOR

\- No refactor may accidentally strengthen default semantics.

\- Unknown may degrade to blocked or remain unknown.

\- Unknown may never silently become usable / healthy / strong / publishable / valid / exact.

\- This rule applies to enums, booleans, empty strings, numeric zeroes, and omitted JSON fields.



RULE G47: COMPILER-QUIET QUICK FIXES ARE FORBIDDEN IF THEY HIDE OWNERSHIP DRIFT

\- Local stubs, duplicate enum definitions, blind casts, placeholder DTO clones, and fake helper recreations are forbidden even if they reduce errors temporarily.

\- A patch that compiles for the wrong ownership reasons is invalid.



RULE G48: BLUEPRINT ENFORCEMENT OVERRIDES CONVENIENCE PATCHING

\- If a fast patch conflicts with the blueprint and a slower blueprint-conformant patch is possible, the blueprint-conformant patch must be chosen.

\- Tactical expediency is not a valid reason to violate ownership doctrine.



RULE G49: CONTRACT DRIFT IS A FIRST-CLASS FAILURE DOMAIN

\- Drift between owner and consumer modules must be treated with the same seriousness as:

&nbsp; - corrupted persistence

&nbsp; - invalid candidate promotion

&nbsp; - unsafe completed-bar handling

&nbsp; - silent fallback misuse

\- Compile drift is not cosmetic.



RULE G50: SHARED STRING CONSTANTS MUST BE OWNER-LOCKED

\- Any repeated load-bearing field key, path key, snapshot key, debug key, trace code, or state label that appears across modules must be owner-defined once and referenced everywhere else.

\- Ad-hoc literal duplication across modules is forbidden for shared contract strings.



RULE G51: ASSISTANT MUST SELF-AUDIT FOR DRIFT BEFORE RETURNING PATCHED CODE

\- Before returning code, the assistant must explicitly verify internally:

&nbsp; - owner symbols referenced still exist

&nbsp; - renamed shared members have compatibility coverage

&nbsp; - include style is canonical

&nbsp; - no local duplicates of owner types were introduced

&nbsp; - changed signatures are coherent across declaration and use

&nbsp; - no semantically-stronger defaults were introduced

\- A returned patch without this self-audit is considered incomplete under this blueprint.



RULE G52: PLACEHOLDER TEXT MAY NEVER ENTER SOURCE PATCHES

\- Placeholders are allowed in blueprint documents only.

\- In actual code returns, omitted sections, TODO placeholders, and pseudo-code are forbidden unless the user explicitly requests a non-compilable design sketch.



RULE G53: OWNER HASH / MODULE HASH DRIFT MUST BE REVIEWED

\- If owner module name, owner module hash, serializer version, stage API version, schema version, or policy fingerprint meaning changes, manifest and compatibility implications must be reviewed in the same pass.

\- Owner metadata cannot drift silently from contract reality.



RULE G54: PATCHES MUST NOT EXPAND BLAST RADIUS NEEDLESSLY

\- When repairing one file, changes must be minimal but sufficient.

\- Broad renames across shared surfaces are forbidden unless specifically required.

\- Cosmetic normalization that increases downstream blast radius is prohibited during compile-fix passes.



RULE G55: BLUEPRINT FILE ITSELF IS A LIVE CONTROL SURFACE

\- This blueprint is not commentary.

\- It is binding operating instruction for future assistant behavior.

\- When ambiguity exists between convenience and enforcement, enforcement wins.



======================================================================

2\. FINAL TOPOLOGY

======================================================================



HUMAN-FACING WRAPPER

\- ISSX.mq5



LOGICAL INTERNAL STAGES



EA1 = MarketStateCore

\- full-universe identity

\- family resolution

\- classification

\- session truth

\- market truth

\- tradeability baseline

\- operational admission

\- symbol lifecycle

\- live friction baseline vs shock state

\- representative continuity memory

\- changed-symbol frontier hints

\- full broker-universe dump



EA2 = HistoryStateCore

\- full-universe history readiness

\- timeframe trust

\- compact metric prep

\- history integrity and comparison safety

\- bounded history queues

\- bar finality and rewrite detection

\- structural context prep

\- changed-symbol/timeframe hydration

\- full rolling history warehouse

\- intraday regime/context metric preparation



EA3 = SelectionCore

\- full-universe bucket tournament

\- top 5 per bucket

\- reserves

\- frontier build

\- bucket diagnostics

\- survivor continuity and churn control

\- bounded replacement discipline

\- delta-driven frontier updates

\- breadth-aware rankability lanes

\- diversity-aware final publish tie-break



EA4 = IntelligenceCore

\- frontier-only overlap

\- sparse similarity

\- bounded correlation

\- diversification / redundancy penalties

\- typed intelligence permissions

\- pair evidence cache

\- local frontier clustering

\- abstention memory

\- pair invalidation on member-shape drift and history/trust drift

\- diversification confidence surface



EA5 = ConsolidationCore

\- every 10 minutes rich winner export

\- compact merged contract

\- embedded legend

\- compact OHLC history pack

\- intraday decision context

\- no directional bias

\- explicit source / fallback / degradation summaries

\- trader-handoff-ready winner condition summaries



KERNEL PRINCIPLE

\- one timer source

\- one scheduler

\- five isolated logical stages

\- stage-local persistence remains separate

\- stage-local acceptance remains separate

\- stage-local publish remains separate

\- stage-local failure remains bounded and visible

\- same-tick handoff is an optimization, never a truth source replacement





======================================================================

3\. UNIVERSES

======================================================================



broker\_universe

\- all symbols terminal currently knows or exposes to enumeration



eligible\_universe

\- symbols that pass coarse identity / spec / readability screen



active\_universe

\- symbols monitored deeply enough for the current cycle



rankable\_universe

\- symbols with sufficient truth for bucket competition



frontier\_universe

\- symbols selected by EA3 for EA4 / EA5 context



publishable\_universe

\- symbols valid enough to appear in current EA5 export



RULES

\- EA1 discovers broker\_universe progressively and eventually.

\- EA2 hydrates full history universe only by rolling queue, never full deep scan every minute.

\- EA3 competes only rankable\_universe.

\- EA4 sees only frontier\_universe.

\- EA5 publishes only winners.



MANDATORY FINGERPRINTS PER APPLICABLE STAGE

\- broker\_universe\_fingerprint

\- eligible\_universe\_fingerprint

\- active\_universe\_fingerprint

\- rankable\_universe\_fingerprint

\- frontier\_universe\_fingerprint

\- publishable\_universe\_fingerprint



FINGERPRINT HARDENING RULES

\- stable canonical ordering before hashing is mandatory

\- fingerprint algorithm version must be recorded

\- enum / null normalization must be deterministic

\- transient selection order must not affect fingerprints

\- UTF-8 encoding must be used for byte-level derivation

\- no hashing of locale-dependent formatted strings



CHANGED DELTA FIELDS

\- changed\_symbol\_count

\- changed\_symbol\_ids compact

\- changed\_family\_count

\- changed\_bucket\_count if applicable

\- changed\_frontier\_count if applicable

\- changed\_timeframe\_count if applicable



COVERAGE VISIBILITY

\- percent\_universe\_touched\_recent

\- percent\_rankable\_revalidated\_recent

\- percent\_frontier\_revalidated\_recent

\- never\_serviced\_count

\- overdue\_service\_count

\- never\_ranked\_but\_eligible\_count

\- newly\_active\_symbols\_waiting\_count

\- near\_cutline\_recheck\_age\_max





======================================================================

4\. FILE / FOLDER LAYOUT

======================================================================



PUBLIC ROOT

Common/Files/FIRMS/<firm\_id>/ISSX/

&nbsp; issx\_export.json

&nbsp; issx\_debug.json

&nbsp; issx\_stage\_status.json optional

&nbsp; issx\_universe\_snapshot.json optional heartbeat projection only



INTERNAL

Common/Files/FIRMS/<firm\_id>/ISSX/persistence/shared/

Common/Files/FIRMS/<firm\_id>/ISSX/persistence/ea1/

Common/Files/FIRMS/<firm\_id>/ISSX/persistence/ea2/

Common/Files/FIRMS/<firm\_id>/ISSX/persistence/ea3/

Common/Files/FIRMS/<firm\_id>/ISSX/persistence/ea4/

Common/Files/FIRMS/<firm\_id>/ISSX/persistence/ea5/

Common/Files/FIRMS/<firm\_id>/ISSX/persistence/ea1/universe/

Common/Files/FIRMS/<firm\_id>/ISSX/persistence/ea2/history\_store/

Common/Files/FIRMS/<firm\_id>/ISSX/persistence/ea2/history\_index/

Common/Files/FIRMS/<firm\_id>/ISSX/debug/

Common/Files/FIRMS/<firm\_id>/ISSX/locks/

Common/Files/FIRMS/<firm\_id>/ISSX/schemas/

Common/Files/FIRMS/<firm\_id>/ISSX/hud/



LOCK FILE

\- issx.lock



PER-STAGE INTERNAL SNAPSHOT SET

Accepted:

\- header\_current.bin

\- payload\_current.bin

\- manifest\_current.json



Rollback:

\- header\_previous.bin

\- payload\_previous.bin

\- manifest\_previous.json



Clean fallback:

\- payload\_last\_good.bin

\- manifest\_last\_good.json optional



Candidate:

\- header\_candidate.bin

\- payload\_candidate.bin

\- manifest\_candidate.json



Optional state:

\- continuity\_state.bin

\- phase\_state.bin

\- queue\_state.bin

\- cache\_state.bin



OPTIONAL SHARDS

\- shard\_symbol\_registry.bin

\- shard\_history\_index.bin

\- shard\_bucket\_state.bin

\- shard\_pair\_cache.bin

\- shard\_context\_cache.bin

\- shard\_delta\_index.bin



EVENT-DRIVEN DEBUG SNAPSHOTS

Common/Files/FIRMS/<firm\_id>/ISSX/debug/

\- ea1\_debug\_snapshot.json optional

\- ea2\_debug\_snapshot.json optional

\- ea3\_debug\_snapshot.json optional

\- ea4\_debug\_snapshot.json optional

\- ea5\_debug\_snapshot.json optional



NO USELESS TMP FOLDER

\- Use bounded persistence classes and explicit candidate files instead.

\- Temporary write filenames may be used inside persistence implementation but are not a top-level workflow concept.



PATH CONSTRUCTION RULES

\- All file paths must be constructed deterministically.

\- All path segments must be stage-owned and explicit.

\- No stage may write into another stage’s folder.

\- Shared folder usage must be explicitly documented and schema-tagged.





PATH CANONICALIZATION ADDON

\- The canonical include-root identity for all ISSX-owned source files is:

&nbsp; - <ISSX/...>

\- The canonical runtime folder-root identity for persistence is:

&nbsp; - Common/Files/FIRMS/<firm\_id>/ISSX/

\- No alternate casing, mirrored folder, duplicate folder alias, or relative shortcut may be treated as equivalent.

\- If multiple physical copies of the same ISSX file exist in the environment, the assistant must assume drift risk and avoid relying on local ambiguity.

\- Source patching must target the canonical file text provided in chat.



======================================================================

5\. PERSISTENCE MODEL

======================================================================



5.1 AUTHORITATIVE PERSISTENCE

\- accepted internal current snapshot + manifest = truth

\- internal previous = rollback

\- internal last\_good = clean fallback

\- candidate set is not truth until accepted

\- public projections are views only



5.2 RECOVERY ORDER

For downstream reads:

1\. accepted same-tick in-memory handoff if compatibility passes

2\. internal accepted current

3\. internal previous

4\. internal last\_good

5\. public root only as optional diagnostic view, never stronger than internal accepted truth

6\. fail honest



5.3 BINARY HEADER DISCIPLINE

Every binary file must begin with a compact fixed header containing at minimum:

\- magic

\- stage\_id

\- schema\_version

\- schema\_epoch

\- storage\_version

\- writer\_generation

\- sequence\_no

\- record\_size or payload\_length

\- payload\_hash\_or\_crc

\- header\_hash\_or\_crc where applicable



RULES

\- binary payloads are never trusted by filename alone

\- layout mismatch is incompatible

\- partial compatibility on storage layout mismatch is forbidden

\- append-only evolution is preferred where practical



5.4 MANIFEST FIELDS

Mandatory:

\- stage\_id

\- firm\_id

\- schema\_version

\- schema\_epoch

\- storage\_version

\- sequence\_no

\- minute\_id

\- writer\_boot\_id

\- writer\_nonce

\- writer\_generation

\- trio\_generation\_id

\- payload\_hash

\- header\_hash

\- payload\_length

\- header\_length

\- symbol\_count

\- changed\_symbol\_count

\- content\_class

\- publish\_reason

\- cohort\_fingerprint

\- taxonomy\_hash

\- comparator\_registry\_hash

\- policy\_fingerprint

\- fingerprint\_algorithm\_version

\- universe\_fingerprint

\- compatibility\_class

\- contradiction\_count

\- contradiction\_severity\_max

\- degraded\_flag

\- fallback\_depth\_used

\- accepted\_strong\_count

\- accepted\_degraded\_count

\- rejected\_count

\- cooldown\_count

\- stale\_usable\_count

\- projection\_partial\_success\_flag

\- accepted\_promotion\_verified

\- stage\_minimum\_ready\_flag

\- stage\_publishability\_state

\- handoff\_mode

\- handoff\_sequence\_no

\- fallback\_read\_ratio\_1h

\- fresh\_accept\_ratio\_1h

\- same\_tick\_handoff\_ratio\_1h

\- legend\_hash (EA5 only)

\- stage\_api\_version

\- serializer\_version

\- writer\_codepage

\- source\_snapshot\_kind

\- resume\_compatibility\_class

\- owner\_module\_name

\- owner\_module\_hash



5.5 FILE GENERATION COHERENCE RULE

Accepted truth is valid only if header\_current, payload\_current, and manifest\_current agree on:

\- stage\_id

\- sequence\_no

\- writer\_generation

\- trio\_generation\_id

\- lengths

\- hashes



Mixed generation is invalid even if individual files are readable.



5.6 PUBLISH DISCIPLINE

Required order:

1\. build header + payload in memory

2\. load existing accepted current if present

3\. rotate accepted current to previous before overwrite

4\. retain backup until promoted readback verifies

5\. write candidate header

6\. write candidate payload

7\. write candidate manifest

8\. flush / close and validate candidate trio

9\. structural accept

10\. semantic accept

11\. promote candidate to accepted current

12\. verify promoted current readback

13\. mark accepted\_promotion\_verified

14\. promote last\_good only if semantic threshold met

15\. update in-memory accepted handoff cache

16\. project public output only if required by projection policy

17\. record projection outcomes separately



5.7 PARTIAL WRITE / ORPHAN CANDIDATE RULE

On boot or recovery:

\- orphan candidate sets may be inspected

\- candidate truth is never accepted merely because files exist

\- candidate truth requires structural + semantic validation and generation coherence

\- if current invalid and previous valid, prefer previous

\- if previous invalid and last\_good valid, prefer last\_good with visible degradation



5.8 SAME-TICK HANDOFF

Allowed only after upstream acceptance and promotion verification.

Must record:

\- upstream\_handoff\_mode

\- upstream\_handoff\_compatibility\_class

\- upstream\_handoff\_same\_tick\_flag

\- upstream\_handoff\_sequence\_no

\- upstream\_partial\_progress\_flag

\- upstream\_payload\_hash

\- upstream\_policy\_fingerprint



RULES

\- same-tick handoff never bypasses acceptance

\- same-tick handoff is immutable once exposed

\- downstream same-tick consumption must remain source-visible

\- downstream same-tick consumption must re-check consumer-sensitive compatibility



5.9 BROKER-UNIVERSE DUMP (EA1)

Mandatory internal store:

\- broker\_universe\_current.bin

\- broker\_universe\_previous.bin

\- broker\_universe\_manifest.json

\- broker\_universe\_snapshot.json optional



Content must include full EA1-owned truth for all known symbols:

\- raw broker observation

\- normalized identity

\- runtime truth

\- classification truth

\- tradeability baseline

\- rankability gate

\- lifecycle

\- fingerprints

\- drift class

\- changed-symbol state

\- symbol discovery state

\- symbol selection state

\- symbol synchronization state

\- property-read status



5.10 HISTORY WAREHOUSE (EA2)

Mandatory internal rolling store:

persistence/ea2/history\_store/

&nbsp; M5/<symbol>.bin

&nbsp; M15/<symbol>.bin

&nbsp; H1/<symbol>.bin

&nbsp; optional future TFs by policy



Mandatory index:

persistence/ea2/history\_index/

&nbsp; symbol\_registry.bin

&nbsp; timeframe\_index.bin

&nbsp; hydration\_cursor\_state.bin

&nbsp; dirty\_set.bin optional

&nbsp; bar\_store\_manifest.json



Per symbol / timeframe rolling store must include:

\- up to default 750 completed bars retained

\- rolling overwrite / cap discipline

\- bar records:

&nbsp; \[t,o,h,l,c,tick\_volume,spread,real\_volume,flags]

\- oldest\_bar\_time

\- newest\_bar\_time

\- retained\_bar\_count

\- last\_sync\_time

\- last\_complete\_bar\_time

\- last\_closed\_bar\_open\_time

\- rewrite\_count\_recent

\- recent\_rewrite\_span\_bars

\- gap\_count

\- finality\_state

\- continuity\_hash

\- trailing\_finality\_hash

\- storage\_version

\- warehouse\_quality metadata



5.11 HISTORY WAREHOUSE RULES

\- completed bars are authoritative for warehouse truth

\- live / forming bar is tracked separately and never silently mixed into completed-pack export

\- warehouse depth improves progressively across cycles

\- history storage is sharded by symbol and timeframe, never giant flat JSON

\- metric caches must bind to bar continuity and finality state

\- storage must remain bounded and rolling

\- unchanged shards should not be rewritten unnecessarily

\- dirty-set driven shard flush is preferred

\- full tree scans every cycle are forbidden



5.12 ROOT PROJECTION POLICY

Primary public outputs only:

\- issx\_export.json

\- issx\_debug.json



Optional:

\- issx\_stage\_status.json

\- issx\_universe\_snapshot.json heartbeat / event-driven only



Per-stage public roots are no longer mandatory normal output.



5.13 LOCK DISCIPLINE

issx.lock must contain at minimum:

\- lock\_owner\_boot\_id

\- lock\_owner\_instance\_guid

\- lock\_owner\_terminal\_identity

\- lock\_acquired\_time

\- lock\_heartbeat\_time

\- stale\_after\_sec



RULES

\- lock file presence alone does not prove live ownership

\- stale lock recovery must be explicit and logged

\- lock semantics are lease-style, not perfect cross-process mutual exclusion



5.14 PERSISTENCE WRITING SAFETY

\- All JSON / text outputs must use UTF-8.

\- All persistence writers must return success / failure and error code.

\- No write routine may silently ignore partial write.

\- No stage may treat “file exists” as equivalent to “file valid”.

\- Candidate write failure must never poison accepted current.







5.15 CONTRACT-DRIFT PERSISTENCE RULE

\- Persistence compatibility cannot be inferred from compile success alone.

\- If shared enums, DTOs, or manifest fields evolve, the assistant must review whether persisted values, serialized names, or semantic interpretations changed.

\- Structural compatibility is insufficient if semantic interpretation drifted.

\- Contract drift affecting persisted meaning must update policy\_fingerprint, and when binary interpretation changes materially, storage\_version must be reviewed.



5.16 VERSION CHANGE MATRIX RULE



The following versioned control surfaces must have explicit change triggers.

They may not drift by intuition, habit, or “seems different enough” judgment.



VERSION SURFACES

\- schema\_version

\- schema\_epoch

\- storage\_version

\- serializer\_version

\- stage\_api\_version

\- policy\_fingerprint

\- fingerprint\_algorithm\_version

\- owner\_module\_hash meaning

\- taxonomy\_hash

\- comparator\_registry\_hash



MANDATORY VERSION-CHANGE MATRIX

1\. schema\_version

\- change when shared DTO shape, JSON contract shape, manifest field set, or accepted payload interpretation changes

\- do not change for comments, formatting, or internal refactor with identical external/shared meaning



2\. schema\_epoch

\- change only for intentionally breaking schema eras where compatibility assumptions across prior eras are no longer safe

\- epoch change is stronger than ordinary schema\_version increment



3\. storage\_version

\- change when binary layout, shard layout, header layout, rolling store layout, or persistence decoding rules materially change

\- review required whenever record size, field ordering, binary enum meaning, or warehouse shard structure changes



4\. serializer\_version

\- change when serialization behavior changes despite same DTO shape

\- examples:

&nbsp; - field omission rules changed

&nbsp; - null encoding semantics changed

&nbsp; - ordering rules changed

&nbsp; - UTF-8 / hashing derivation rules changed

&nbsp; - numeric/string encoding rules changed



5\. stage\_api\_version

\- change when required public stage entry points, signatures, call expectations, or mandatory stage surface semantics change

\- additive helper methods alone do not require version bump unless required by contract



6\. policy\_fingerprint

\- change when semantic policy changes affect ranking, thresholds, acceptance, invalidation, fallback meaning, continuity behavior, lane participation, or compare safety interpretation

\- policy change may require no DTO change and still must update policy\_fingerprint



7\. fingerprint\_algorithm\_version

\- change when canonical ordering, normalization, byte conversion, hash algorithm, or null treatment for fingerprints changes



8\. owner\_module\_hash meaning

\- if owner module hash calculation method changes, that calculation meaning must be version-reviewed and documented

\- hash value drift caused by implementation edits is expected

\- hash meaning drift is a governance event



9\. taxonomy\_hash

\- change when classification taxonomy, bucket semantics, family normalization policy, or sector mapping semantics change



10\. comparator\_registry\_hash

\- change when comparator weights, comparator field set, tie-break logic class, penalty family set, or comparison registry semantics change



MANDATORY REVIEW RULE

\- Any patch affecting one version surface must explicitly review whether any other version surface must also change.

\- “Only one field changed” is not sufficient reasoning.



FORBIDDEN

\- silent version under-bump

\- blanket bump of all versions for convenience

\- policy change without policy\_fingerprint review

\- binary meaning drift without storage\_version review

\- API signature drift without stage\_api\_version review

======================================================================

6\. ACCEPTANCE MODEL

======================================================================



Acceptance types remain:

\- accepted\_for\_pipeline

\- accepted\_for\_ranking

\- accepted\_for\_intelligence

\- accepted\_for\_gpt\_export

\- accepted\_degraded

\- rejected



6.1 STRUCTURAL ACCEPTANCE

Checks:

\- schema compatibility

\- storage compatibility

\- stage / firm match

\- hashes / CRCs valid

\- candidate trio consistency

\- generation coherence

\- file completeness

\- monotonic sanity

\- binary header validity



6.2 SEMANTIC ACCEPTANCE

Checks:

\- required block completeness

\- required freshness

\- required confidence

\- required owner fields

\- valid null semantics

\- contradiction threshold

\- consumer compatibility class

\- policy\_fingerprint compatibility where consumer-sensitive

\- no forbidden semantic downgrades hidden as compatible



6.3 DISTRIBUTION TRACKING

Mandatory:

\- accepted\_strong\_count

\- accepted\_degraded\_count

\- rejected\_count

\- cooldown\_count

\- stale\_usable\_count



6.4 ADDITIONAL ONE-EA RULES

\- downstream same-tick handoff still requires full acceptance

\- no stage may consume upstream candidate pre-acceptance

\- stage-local acceptance failure must not zero unrelated stage truth

\- truth restore and work resume must be validated separately



6.5 QUALITY FLOOR RULE

\- candidate accepted truth may replace current only if semantic thresholds pass

\- severe quality collapse relative to coherent current may force accepted\_degraded or rejection by stage policy

\- this rule is to prevent structurally-valid but semantically-hollow truth regressions



6.6 CONTRADICTION TAXONOMY

Minimum contradiction classes:

\- identity contradiction

\- session contradiction

\- spec contradiction

\- history continuity contradiction

\- selection ownership contradiction

\- intelligence validity contradiction



Expose:

\- contradiction\_class\_counts

\- highest\_blocking\_contradiction\_class

\- contradiction\_repair\_state



6.7 RANKABILITY LANE RULE

Each EA3 candidate must map to one lane:

\- strong

\- usable

\- exploratory

\- blocked



RULES

\- strong and usable may fully compete

\- exploratory may compete with explicit confidence cap and score penalty

\- blocked may not compete

\- exploratory does not mean safe; it means allowed with visible weakness

\- mild uncertainty should degrade score before it erases candidacy



6.8 ACCEPTANCE ENUM RULE

\- Shared acceptance enums are core-owned.

\- Any legacy naming alias must resolve to the core-owned enum only.

\- No stage may define local acceptance enums with semantic overlap.







6.9 CONTRACT ACCEPTANCE PRECHECK

Before semantic acceptance logic is trusted, the following compile-time / contract-time assumptions must already hold:

\- owner symbol exists

\- consumer symbol resolves through owner or owner alias layer

\- no duplicate semantic enum ownership exists

\- no shared DTO field is being locally shadowed

\- no include-path ambiguity is hiding the true owner file

If these are violated, compile remediation must occur before semantic acceptance reasoning is treated as reliable.



6.10 ACCEPTANCE THRESHOLD OWNERSHIP RULE



Acceptance semantics may not be distributed informally across engines.

Thresholds must be owner-defined, documented, and version-reviewable.



OWNER

\- Canonical shared threshold definitions must be owned by:

&nbsp; - issx\_core.mqh for shared semantic threshold DTOs / enums / constants

&nbsp; - issx\_registry.mqh for registry metadata and documentation only if no semantic re-ownership occurs

\- Stage-local threshold values may exist only for stage-local business logic not consumed outside the stage

\- Any threshold consumed across stages, persisted, surfaced in JSON, or used in debug/HUD must be owner-locked



MANDATORY THRESHOLD FAMILIES

At minimum, define and review thresholds for:

\- minimum freshness

\- contradiction threshold

\- accepted\_degraded floor

\- accepted\_for\_pipeline floor

\- accepted\_for\_ranking floor

\- accepted\_for\_intelligence floor

\- accepted\_for\_gpt\_export floor

\- last\_good promotion floor

\- fallback usability floor

\- compare\_safe\_degraded floor

\- compare\_safe\_strong floor

\- exploratory lane participation floor

\- exploratory confidence cap conditions

\- bucket minimum publish floor

\- pair validity minimum floor

\- regime/context publish minimum floor



THRESHOLD TABLE REQUIREMENTS

Every load-bearing threshold definition must declare:

\- threshold\_name

\- owner\_module

\- semantic purpose

\- scope:

&nbsp; - structural

&nbsp; - semantic

&nbsp; - ranking

&nbsp; - intelligence

&nbsp; - export

&nbsp; - fallback

\- hard\_block vs soft\_penalty behavior

\- default value semantics

\- degradation behavior when unavailable

\- policy\_fingerprint sensitivity

\- persistence sensitivity if any

\- external contract sensitivity if any



RULES

\- hard thresholds must not be hidden as score penalties

\- soft penalties must not silently become hard blocks

\- threshold defaults must never be stronger than unknown / not\_ready / degraded-safe semantics

\- stage code may consume owner thresholds but may not silently fork them

\- threshold changes that alter stage behavior must trigger policy\_fingerprint review



FORBIDDEN

\- ad-hoc numeric literals repeated across modules for shared acceptance logic

\- local consumer threshold clones

\- hidden threshold drift via renamed constants

\- threshold meaning changes without owner review

======================================================================

7\. CLOCK / TIMER MODEL

======================================================================



CLOCK SOURCES

\- mono\_ms = internal elapsed timing / deadlines / starvation / service age

\- schedule\_clock = TimeTradeServer() or safe fallback for schedule anchoring only

\- quote\_clock = TimeCurrent() for quote freshness only



CLOCK OWNERSHIP RULES

\- mono\_ms is the only elapsed-time truth

\- schedule\_clock is never used for runtime budget calculations

\- quote\_clock is never used for scheduler cadence

\- clock divergence must be visible, not hidden



CLOCK FIELDS

\- minute\_epoch\_source

\- scheduler\_clock\_source

\- freshness\_clock\_source

\- timer\_gap\_ms\_now

\- timer\_gap\_ms\_mean

\- timer\_gap\_ms\_p95

\- scheduler\_late\_by\_ms

\- missed\_schedule\_windows\_estimate

\- quote\_clock\_idle\_flag

\- clock\_sanity\_score

\- clock\_divergence\_sec

\- clock\_anomaly\_flag

\- time\_penalty\_applied



TIMER MODEL

\- one EventSetTimer(1) source

\- one OnTimer-driven kernel scheduler

\- OnDeinit must tear timer down cleanly

\- one timer pulse may execute zero, one, or several bounded stage slices

\- no pulse assumes all five stages complete fully

\- timer count is never treated as schedule truth



PHASE SCHEDULER STATE

\- kernel\_minute\_id

\- scheduler\_cycle\_no

\- current\_stage\_slot

\- current\_stage\_phase

\- current\_stage\_budget\_ms

\- current\_stage\_deadline\_ms

\- stage\_last\_run\_ms\[ea1..ea5]

\- stage\_last\_publish\_minute\_id\[ea1..ea5]

\- stage\_publish\_due\_flag\[ea1..ea5]

\- stage\_minimum\_ready\_flag\[ea1..ea5]

\- stage\_backlog\_score\[ea1..ea5]

\- stage\_starvation\_score\[ea1..ea5]

\- stage\_dependency\_block\_reason\[ea1..ea5]

\- stage\_resume\_key\[ea1..ea5]

\- stage\_last\_successful\_service\_mono\_ms\[ea1..ea5]

\- stage\_last\_attempted\_service\_mono\_ms\[ea1..ea5]

\- stage\_missed\_due\_cycles\[ea1..ea5]

\- kernel\_budget\_total\_ms

\- kernel\_budget\_spent\_ms

\- kernel\_budget\_reserved\_commit\_ms

\- kernel\_budget\_debt\_ms

\- kernel\_forced\_service\_due\_flag

\- kernel\_degraded\_cycle\_flag

\- kernel\_overrun\_class



BUDGET CLASSES

\- discovery\_budget\_ms

\- probe\_budget\_ms

\- quote\_sampling\_budget\_ms

\- history\_warm\_budget\_ms

\- history\_deep\_budget\_ms

\- pair\_budget\_ms

\- cache\_budget\_ms

\- persistence\_budget\_ms

\- publish\_budget\_ms

\- debug\_budget\_ms

\- freshness\_fastlane\_budget\_ms



HARD SLICE CAP RULE

Every stage slice must observe both:

\- runtime cap in milliseconds

\- work-unit cap by stage-specific work type



Example work-unit families:

\- symbols scanned

\- probes attempted

\- copy requests

\- bars processed

\- buckets recomputed

\- pairs processed

\- files written

\- debug events emitted



KERNEL HARD RULES

\- never let ea5 consume work budget needed for ea1..ea4 freshness

\- never let deep ea2 hydration starve ea1 publish

\- never let ea4 pair work starve ea3 frontier maintenance

\- never let queue backlog steal reserved commit budget

\- never let same-minute finished work rerun unless invalidated

\- timer lossiness must not silently erase due work

\- freshness fast-lane must remain serviceable even during deep backlog



INVALIDATION CLASSES

\- quote\_freshness\_invalidation

\- tradeability\_invalidation

\- session\_boundary\_invalidation

\- history\_sync\_invalidation

\- frontier\_member\_change

\- family\_representative\_change

\- policy\_change\_invalidation

\- clock\_anomaly\_invalidation

\- activity\_regime\_invalidation



TIMER SAFETY RULES

\- Wrapper must call EventSetTimer in OnInit only after core stage objects are initialized.

\- Wrapper must call EventKillTimer in OnDeinit unconditionally.

\- Scheduler must record late\_by\_ms and missed\_windows\_estimate when observed.

\- Scheduler must not use timer pulse count as a correctness metric.

\- Any timer anomaly large enough to distort budgets must surface in debug and may trigger degradation.





======================================================================

8\. HYDRATION MENU AND COVERAGE

======================================================================



HYDRATION MENU CLASSES

1\. bootstrap work

2\. delta-first work

3\. backlog-clearing work

4\. continuity-preserving work

5\. publish-critical work

6\. optional enrichment work



RULES

\- delta-first > backlog-clearing

\- publish-critical budget is reserved

\- optional enrichment yields first under pressure

\- repair may preempt enrichment, not publish-critical forever

\- every queue family must receive eventual service

\- weighted fairness is preferred over naive strict priority

\- never-serviced items must gain service pressure over time



ROTATION STATE

\- discovery\_cursor

\- spec\_probe\_cursor

\- runtime\_sample\_cursor

\- history\_warm\_cursor

\- history\_deep\_cursor

\- bucket\_rebuild\_cursor optional

\- pair\_queue\_cursor

\- repair\_cursor



COVERAGE VISIBILITY

\- rotation\_window\_estimated\_cycles

\- percent\_universe\_touched\_recent

\- percent\_rankable\_revalidated\_recent

\- percent\_frontier\_revalidated\_recent

\- deep\_backlog\_remaining

\- never\_serviced\_count

\- overdue\_service\_count

\- coverage\_rankable\_recent\_pct

\- coverage\_frontier\_recent\_pct

\- history\_deep\_completion\_pct

\- winner\_cache\_dependence\_pct

\- sector\_cold\_backlog\_count

\- newly\_active\_symbols\_waiting\_count



ANTI-BLOAT RULE

\- full deep universe rescans every minute are forbidden

\- unchanged members must reuse validated truth and caches where safe

\- queues may be deferred, not starved indefinitely



MINIMUM STALE-SERVICE RULE

\- each major queue family must receive a guaranteed stale-service quota over time

\- delta-first work may jump ahead, but may not permanently exile cold / weak members



CONTENDER PROMOTION RULE

\- newly active, newly improved, or near-cutline symbols may receive bounded temporary priority uplift

\- this uplift must be explicit, time-limited, and visible

\- hot-set priority may dominate briefly, never permanently







======================================================================

9\. SHARED ENGINE MODULE TREE

======================================================================



PRIMARY TARGET: KEEP CURRENT 10 MODULES

1\. issx\_core.mqh

2\. issx\_runtime.mqh

3\. issx\_persistence.mqh

4\. issx\_registry.mqh

5\. issx\_market\_engine.mqh

6\. issx\_history\_engine.mqh

7\. issx\_selection\_engine.mqh

8\. issx\_correlation\_engine.mqh

9\. issx\_contracts.mqh

10\. issx\_ui\_test.mqh



PATCH-FRIENDLY CHANGE POLICY

\- Prefer efficient patching of current modules.

\- No drastic redesign that forces rebuild from zero.

\- Add scheduler-facing stage entry points where needed.

\- Add dump / warehouse helpers where needed.

\- Add debug / trace helpers where needed.

\- Add at most 2 optional grouped modules only if later proven necessary after integration testing.

\- Do not add modules merely for naming convenience.

\- Do not split ownership merely to work around compile errors.

\- Do not create “temporary helper” files that duplicate core-owned semantics.



MODULE RESPONSIBILITY MAP



issx\_core.mqh

\- owns shared enums

\- owns shared DTOs

\- owns shared constants

\- owns shared path/key constants

\- owns ISSX\_JsonWriter

\- owns ISSX\_Util

\- owns shared compatibility ordering helpers

\- owns legacy alias macros for shared contracts only

\- owns compatibility-alias bridge for renamed shared symbols

\- owns stage-index mapping unless intentionally delegated

\- must not own stage business logic



issx\_registry.mqh

\- owns field registry

\- owns field metadata

\- owns field normalization helpers

\- owns compatibility surfaces that reference core enums but do not redefine them

\- may document but may not re-own semantic enums

\- may not shadow field keys already owned by core constants

\- must not redefine semantic enums



issx\_runtime.mqh

\- kernel scheduler owner

\- stage dispatch helpers

\- due checks

\- budget allocation

\- starvation / fairness

\- dependency gating

\- slice cap enforcement

\- service-age accounting

\- invalidation handling

\- contender promotion handling

\- freshness fast-lane dispatch

\- stage-index mapping helpers if not owned by core

\- may not redefine phase / budget DTOs already shared



issx\_persistence.mqh

\- same-tick accepted handoff helpers

\- broker-universe dump primitives

\- history warehouse primitives

\- projection outcome tracking

\- generation coherence validation

\- lease-style lock helpers

\- dirty-shard batching helpers

\- serializer versioning

\- UTF-8 persistence encoding rules

\- may not redefine manifest/header shared structs locally



issx\_market\_engine.mqh

\- explicit stage boot / slice / publish / snapshot entries

\- full broker-universe dump assembly

\- discovery / selection / sync state machine

\- family confidence and representative stability support

\- stage-local enums only where not shared



issx\_history\_engine.mqh

\- explicit stage boot / slice / publish / snapshot entries

\- rolling warehouse hydration

\- per-symbol / timeframe storage management

\- history sync state machine

\- rewrite / finality classification

\- metric invalidation on continuity / finality drift

\- regime/context metric assembly for downstream non-directional use

\- stage-local enums only where not shared



issx\_selection\_engine.mqh

\- same business role as before

\- rankability lanes

\- opportunity-surface ranking inputs

\- diversity-aware final tie-break

\- quiet-decay vs churn-aware continuity behavior

\- exploratory penalty caps instead of blanket exile

\- must consume shared lane / confidence / state enums from owner surfaces



issx\_correlation\_engine.mqh

\- same business role as before

\- pair validity classes stricter than symbol validity

\- pair TTL and changed-pair prioritization

\- unknown-vs-low separation

\- diversification confidence classes

\- lightweight redundancy hints consumable by EA3 when available

\- must never recreate shared pair validity meanings locally



issx\_contracts.mqh

\- same business role as before

\- richer source / fallback age surface

\- winner-level broker / history richness and state semantics

\- trader-handoff-ready neutral summaries

\- symptom summaries

\- must consume shared field keys from owner constants when load-bearing



issx\_ui\_test.mqh

\- kernel HUD

\- structured stage trace lines

\- aggregated debug summary

\- stage weak-link reporting

\- event-driven debug snapshot projection

\- rate-limited trace policies

\- display-only consumer of shared enums / states / labels

\- may not redefine semantic state ownership



MODULE INCLUDE DOCTRINE

\- Each file includes what it directly uses.

\- No stage module may depend on transitive includes.

\- Core should not include stage modules.

\- Registry may include core only.

\- Runtime may include core, registry, persistence as needed.

\- Stage modules may include core, registry, persistence, and only specific upstream contract headers when necessary.

\- Contracts may include stage outputs but must not mutate them.

\- UI may include read-only status surfaces but must not own semantic state.



MODULE ANTI-DRIFT DOCTRINE

\- Shared-owner modules must be treated as contract roots.

\- Consumer modules must never silently fork semantics from roots.

\- If a consumer requires a helper missing from owner, the helper must be added to owner where ownership belongs rather than recreated locally.

\- If a patch changes any root contract, dependent modules must be audited before the patch is considered complete.



9.1 SHARED OWNER SURFACE INVENTORY RULE



ISSX must maintain a compact owner-surface inventory for all load-bearing shared contracts.

This inventory is a governance tool, not optional documentation.



MINIMUM INVENTORY COLUMNS

\- surface\_name

\- surface\_kind:

&nbsp; - enum

&nbsp; - DTO

&nbsp; - constant

&nbsp; - helper

&nbsp; - manifest field

&nbsp; - JSON field

&nbsp; - debug key

&nbsp; - stage API method

&nbsp; - serializer surface

\- owner\_module

\- consumer\_modules

\- persisted\_flag

\- exported\_flag

\- debug\_only\_flag

\- compatibility\_alias\_state:

&nbsp; - active\_primary

&nbsp; - bridged\_legacy

&nbsp; - removal\_announced

&nbsp; - removed\_by\_blueprint

\- policy\_sensitive\_flag

\- storage\_sensitive\_flag

\- external\_contract\_sensitive\_flag



MANDATORY COVERAGE

At minimum, the inventory must cover:

\- shared semantic enums

\- shared DTOs

\- shared field keys

\- shared path keys

\- manifest keys

\- stage API entry points

\- JSON writer helper family

\- compatibility aliases

\- externally surfaced EA5 field keys

\- shared debug / trace / HUD keys



RULES

\- if a symbol is shared and load-bearing, it must appear in the owner-surface inventory

\- if a symbol is persisted, the inventory must reflect persistence sensitivity

\- if a symbol is exported to EA5, the inventory must reflect external contract sensitivity

\- if a symbol is bridged, alias lifecycle state must be declared

\- inventory documentation must not become a shadow owner; owner remains the canonical code owner



PATCH-WAVE RULE

\- Any patch that changes a shared owner surface must review and update the inventory in the same wave where practical.

\- If full inventory update is not possible in the same pass, the patch must at minimum note the affected surfaces explicitly.



FORBIDDEN

\- undocumented shared owner surfaces

\- shared contract change with no owner/consumer visibility

\- alias existence without lifecycle visibility

======================================================================

10\. COMPILE GOVERNANCE, INCLUDE GOVERNANCE, TYPE OWNERSHIP

======================================================================



10.1 INCLUDE GOVERNANCE

\- All ISSX-owned includes must use:

&nbsp; - #include <ISSX/...>

\- Quoted includes for ISSX-owned files are forbidden.

\- Hybrid include style is forbidden.

\- Every file must include its direct dependencies explicitly.

\- Relying on wrapper include order is forbidden.

\- Relying on MetaEditor project-relative include coincidence is forbidden.

\- Relying on duplicated file presence in multiple include roots is forbidden.



10.2 ONE-DEFINITION RULE

\- Any shared semantic enum, shared struct, shared DTO, shared helper, or shared JSON writer method may have exactly one owner definition.

\- Duplicate definitions across core / registry / UI / engines are forbidden.

\- If backward compatibility is needed, use aliasing in the owner file only.

\- Copy-equivalent duplicate definitions are still duplicates and still forbidden.



10.3 SHARED ENUM OWNERSHIP

Shared semantic enums belong in issx\_core.mqh, including at minimum:

\- publishability

\- content class

\- compatibility class

\- acceptance enum

\- trace severity

\- HUD warning severity

\- contradiction classes

\- pair validity classes

\- readiness classes if shared

\- rankability lane if shared

\- any enum referenced by more than one module

\- any enum persisted to disk

\- any enum surfaced in JSON

\- any enum consumed by UI and at least one engine



10.4 STAGE-LOCAL ENUM OWNERSHIP

\- Stage-local enums belong only in their stage engine when they are not consumed outside that stage.

\- If later consumed across stages, they must be migrated to core or converted to a shared DTO.

\- “Consumed indirectly” still counts as consumed across stages if serialized, persisted, or projected.



10.5 LEGACY ALIAS POLICY

\- Legacy aliases are allowed only in core or registry.

\- Legacy aliases must be documented with:

&nbsp; - alias target

&nbsp; - reason

&nbsp; - deprecation status

&nbsp; - first version supported

&nbsp; - earliest version eligible for removal

\- No stage file may contain shared semantic alias macros.

\- Alias removal requires explicit blueprint authorization.



10.6 JSON WRITER SINGLE-OWNER POLICY

\- ISSX\_JsonWriter is core-owned.

\- Shared helper methods like KeyValue, BeginNamedArray, WriteString, WriteLong, NameString, NameInt, and all stable variants must exist in core only.

\- No module may define a competing JSON writer surface.

\- Cosmetic variations of the same helper family are still competing surfaces and forbidden.



10.7 STAGE INDEX MAPPING POLICY

\- Never assume enum numeric value equals stable array index unless explicitly guaranteed by core.

\- Provide StageIdToIndex helper in core or runtime.

\- UI and debug arrays must use mapping helpers, not raw enum casts.

\- Persisted enum values and in-memory stage-array indices must remain conceptually distinct unless blueprint explicitly guarantees equivalence.



10.8 SIGNATURE STABILITY POLICY

\- Shared method signatures are contract surfaces.

\- If a shared signature changes, all declarations and definitions must be updated in the same patch wave.

\- Overloads must differ by meaningful parameter list, never return type only.

\- Optional parameters must not silently change semantic behavior for existing call sites without compatibility review.

\- Reference-vs-value changes count as signature changes.



10.9 FORWARD DECLARATION POLICY

\- Use forward declarations only where legal and safe in MQL5.

\- If a type is used by value, it must be fully defined before use.

\- If a type is shared widely, prefer placing it in core rather than gaming include order.

\- Forward declarations may not be used to hide ownership confusion.



10.10 CLASS CLOSURE RULE

\- Every class must close exactly once.

\- Brace balance and parser continuity must be verified after edits.

\- Any compile error that suggests global-scope spill must trigger immediate brace / duplicate-block audit first.

\- Duplicate class tails, accidental repeated pasted blocks, and nested parser residue are first-priority suspects.



10.11 WARNING-ZEROING RULE

\- Truncation warnings, narrowing warnings, sign-loss warnings, shadowing warnings, and suspicious “expression has no effect” warnings are defects.

\- Fix by explicit cast, wider type, or corrected expression.

\- Do not ship load-bearing code with unresolved warning clusters.

\- Do not cast merely to silence; the cast must reflect semantic safety.



10.12 NO-ACCIDENTAL-COMPILE RULE

\- A file must compile for the right reasons.

\- “Compiles only when included after file X” is invalid.

\- “Compiles only because UI or wrapper brought in a hidden type” is invalid.

\- “Compiles because a duplicate owner exists elsewhere” is invalid.

\- “Compiles because old and new symbols coexist by accident” is invalid.



10.13 CANONICAL INCLUDE IDENTITY RULE

\- Every ISSX-owned file has exactly one canonical include identity.

\- The assistant must normalize every patched file to that identity.

\- No patch may leave mixed identities unresolved.

\- Canonical identity must match the blueprint owner tree.



10.14 SHARED CONTRACT RENAME PROTOCOL

If a shared owner symbol is renamed:

1\. keep old symbol via compatibility alias in owner

2\. add new symbol in owner

3\. document semantic mapping

4\. patch downstream consumers gradually or in same wave

5\. only remove old alias when blueprint explicitly allows

6\. never force same-pass consumer breakage without migration plan



10.15 COMPATIBILITY BRIDGE DOCTRINE

\- Core must carry bridging aliases for renamed shared enums, values, constants, and helper names where feasible.

\- Registry may carry bridging aliases for registry-local metadata identifiers only where ownership is registry-local.

\- Bridges must preserve meaning, not merely spelling.

\- Ambiguous one-to-many renames require explicit mapping note in blueprint or comments.



10.16 SHARED STRING KEY LOCK RULE

\- Shared field keys, debug keys, reason codes, path keys, and manifest keys must be constant-owned.

\- Engines and UI must not hardcode owner-shared keys when a constant exists or should exist.

\- Literal duplication that risks spelling drift is forbidden.



10.17 CROSS-FILE PATCH-WAVE COMPLETENESS RULE

\- A patch affecting a shared owner is incomplete unless one of the following is true:

&nbsp; 1) all downstream consumers are updated in the same wave, or

&nbsp; 2) backward compatibility bridge fully preserves existing consumers

\- “Will fix later” is not sufficient.



10.18 OWNER-SURFACE FREEZE RULE

\- Between intentional blueprint versions, shared owner surfaces are logically frozen.

\- Assistants may extend but not casually rename or redefine them.

\- Extension is preferred over mutation.

\- Mutation requires migration doctrine.



10.19 CONTRACT DIFF MANDATE

\- Before returning a patch that changes shared owner surfaces, the assistant must internally compare:

&nbsp; - removed symbols

&nbsp; - added symbols

&nbsp; - renamed symbols

&nbsp; - signature changes

&nbsp; - enum member changes

&nbsp; - default semantic changes

\- Any risky diff must be reconciled before response.



10.20 SECONDARY ERROR FLOOD RULE

\- If one shared owner failure can explain many later errors, the assistant must not patch late-file symptoms first.

\- Late-file symptom patching before owner stabilization is forbidden.



10.21 PARSER-COLLAPSE CONTAINMENT RULE

\- When errors indicate probable parser collapse, do not interpret downstream type failures as independent until brace / class continuity is checked.

\- Root parser repair precedes type repair.



10.22 COMPILER ERROR CLASSIFICATION RULE

Shared root-cause classes are ranked:

1\. duplicate pasted block / brace damage

2\. include path identity drift

3\. missing owner type from failed include

4\. contract rename without alias bridge

5\. signature drift

6\. local syntax defects

This ranking must guide repair order.



10.23 DEFAULT SEMANTIC LOCK RULE

\- If default enum / bool / numeric / string semantics change, the assistant must treat it as a contract change requiring explicit review.

\- “Cleaner defaults” is not a valid justification by itself.



10.24 VERSIONED DEPRECATION RULE

\- A shared contract symbol may be:

&nbsp; - active

&nbsp; - bridged\_deprecated

&nbsp; - removal\_announced

&nbsp; - removed\_by\_blueprint

\- Hard removal before removal\_announced + explicit blueprint approval is forbidden.



10.25 ASSISTANT RETURN SAFETY GATE

Before finalizing a code patch, the assistant must internally verify:

\- include style canonical

\- owner symbols still resolve

\- no duplicate shared owner added

\- no silent renames without alias

\- no stage-local contract shims created

\- signature coherence preserved

\- parser continuity preserved

\- warnings not cosmetically suppressed

If any gate fails, the patch is not blueprint-complete.



======================================================================

11\. FIELD REGISTRY AND ENUMS

======================================================================



All v1.5.0 / v1.6.x / v1.7.0 field registry and enum contracts remain valid unless superseded here.



Additional required registry coverage:

\- stage\_minimum\_ready\_flag

\- stage\_publishability\_state

\- upstream\_handoff\_mode

\- upstream\_handoff\_same\_tick\_flag

\- upstream\_partial\_progress\_flag

\- warehouse\_quality

\- warehouse\_retained\_bar\_count

\- dump\_sequence\_no

\- dump\_minute\_id

\- debug\_weak\_link\_code

\- dependency\_block\_reason

\- kernel\_degraded\_cycle\_flag

\- fallback\_read\_ratio\_1h

\- same\_tick\_handoff\_ratio\_1h

\- fresh\_accept\_ratio\_1h

\- policy\_fingerprint

\- fingerprint\_algorithm\_version

\- contradiction\_class\_counts

\- highest\_blocking\_contradiction\_class

\- coverage\_rankable\_recent\_pct

\- coverage\_frontier\_recent\_pct

\- history\_deep\_completion\_pct

\- winner\_cache\_dependence\_pct

\- clock\_divergence\_sec

\- scheduler\_late\_by\_ms

\- missed\_schedule\_windows\_estimate

\- pair\_validity\_class

\- pair\_sample\_alignment\_class

\- pair\_window\_freshness\_class

\- warehouse\_clip\_flag

\- warmup\_sufficient\_flag

\- effective\_lookback\_bars

\- rankability\_lane

\- exploratory\_penalty\_applied

\- intraday\_activity\_state

\- liquidity\_regime\_class

\- volatility\_regime\_class

\- expansion\_state\_class

\- movement\_quality\_class

\- movement\_maturity\_class

\- session\_phase\_class

\- tradability\_now\_class

\- holding\_horizon\_context

\- constructability\_class

\- diversification\_confidence\_class

\- redundancy\_risk\_class

\- selection\_reason\_summary

\- selection\_penalty\_summary

\- winner\_limitation\_summary

\- winner\_confidence\_class

\- opportunity\_with\_caution\_flag

\- early\_move\_quality\_class

\- movement\_to\_cost\_efficiency\_class



All warehouse-derived fields must declare:

\- direct\_or\_derived

\- authority\_level

\- stale\_policy

\- cache provenance if cached



All debug / diagnostic fields must be marked diagnostic, not factual market truth.



POLICY COMPATIBILITY RULE

\- Semantic policy changes that affect ranking, dedupe, thresholds, invalidation, retention, compare safety, or JSON meaning must update policy\_fingerprint.

\- Compatibility checks must use policy\_fingerprint where consumer-sensitive.



DEBUG KEY REGISTRY RULE

\- All debug / trace / HUD keys must be registered or declared in a stable debug key registry.

\- No ad-hoc string key invention inside stage code for shared debug fields.







ADDITIONAL FIELD / ENUM DRIFT RULES

\- Registry may document enum surfaces, but documented values must remain synchronized with core-owned enum meaning.

\- Registry documentation must never become a shadow definition.

\- If a core enum evolves, enum registry entries must be reviewed in the same patch wave.

\- Field registry names must consume core-owned constants where those constants exist.

\- If a field key exists as a core constant, registry code must not invent alternative spellings.

\- Shared field-key literals should be migrated toward core-owned constants over time rather than proliferated.



ENUM VALUE MIGRATION RULE

\- If enum string export labels change, the assistant must review:

&nbsp; - persisted JSON meaning

&nbsp; - debug meaning

&nbsp; - consumer interpretation

&nbsp; - compatibility shims

\- String label drift is a contract change even if enum numeric values remain stable.



======================================================================

12\. EA1 FULL SPEC

======================================================================



EA1 retains v1.5.0 / v1.6.x / v1.7.0 purpose and per-symbol blocks.



Mandatory additions:

\- full broker-universe dump persistence

\- dump sequence\_no and dump minute\_id

\- dump heartbeat policy

\- representative continuity persists even when public projection is skipped

\- stage boot entry

\- stage slice entry

\- stage publish entry

\- stage HUD / debug snapshot entry



EA1 SYMBOL DISCOVERY LIFECYCLE

Minimum distinct internal states:

\- discovered

\- selected

\- metadata\_readable

\- quote\_observable

\- synchronized

\- history\_addressable

\- trade\_permitted

\- custom\_symbol\_flag

\- property\_unavailable

\- select\_failed\_temp

\- select\_failed\_perm



RULES

\- these states must not be collapsed to one “usable” flag internally

\- unreadable, unknown, not-selected, and not-synced remain distinct

\- property-zero and property-unavailable must remain distinct



EA1 OUTPUT POLICY

\- public projection is no longer a mandatory ea1\_stage.json every cycle

\- internal full dump is mandatory

\- public universe snapshot is optional heartbeat / event-driven only

\- changed\_symbol\_count and changed\_symbol\_ids remain mandatory internally and for downstream handoff



EA1 HARD ADDITIONS

\- discovery must enumerate all terminal-known broker symbols eventually

\- deep spec probing remains queue-driven

\- symbol property failures must be stored, not discarded

\- no family representative switch on one-cycle noise

\- representative switch requires score margin + stability window + confidence

\- blocked tradeability may not enter rankable\_universe

\- selection into working set must be bounded; discovery does not imply permanent activation



EA1 SESSION HARDENING

Session truth must be layered:

\- declared\_session\_state

\- observed\_quote\_activity\_state

\- observed\_spread\_behavior\_state

\- trade\_permission\_state



Expose:

\- session\_truth\_class = declared\_only / observed\_supported / contradictory



Contradictory session truth must cap rankability.



EA1 FAMILY HARDENING

Family collapse should consider:

\- normalized identity

\- contract / spec signature

\- currency structure

\- calc mode / trade mode

\- continuity

\- observability

\- execution profile

\- spread / session / quote shape where materially different



Expose:

\- family\_resolution\_confidence

\- family\_rep\_stability\_window

\- family\_published\_rep vs family\_best\_now

\- execution\_profile\_distinct\_flag



EA1 CURRENT OPERATIONAL CONTEXT HARDENING

For downstream non-directional use, EA1 should assemble or support:

\- current\_quote\_liveness\_state

\- current\_friction\_state

\- spread\_state\_vs\_baseline

\- activity\_transition\_state

\- liquidity\_ramp\_state



These are operational context facts, not signals.



EA1 MT5-SAFE BUILD GUIDE

\- Do not assume SymbolSelect success implies property readability.

\- Separate “select failed” from “property unavailable”.

\- Store raw broker observation and normalized interpretation separately.

\- Avoid large static arrays for broker universe; use dynamic arrays with explicit bounds checks.

\- Write broker dump with schema-tagged manifest even if some fields are NA.





======================================================================

13\. EA2 FULL SPEC

======================================================================



EA2 retains v1.5.0 / v1.6.x / v1.7.0 purpose, trust map, judgment packet, and structural context rules.



Mandatory additions:

\- history warehouse is first-class owned persistence

\- per symbol / timeframe rolling OHLC storage

\- default retained completed bars:

&nbsp; - m5: 750

&nbsp; - m15: 750

&nbsp; - h1: 750

\- retention caps are policy-configurable but bounded

\- live / forming bar handled separately from completed warehouse bars

\- metric caches invalidate on bar rewrite / finality drift / alignment failure

\- stage boot / slice / publish / HUD entries mandatory



EA2 HISTORY READINESS STATE MACHINE

Minimum states per symbol / timeframe:

\- never\_requested

\- requested\_sync

\- partial\_available

\- syncing

\- compare\_unsafe

\- compare\_safe\_degraded

\- compare\_safe\_strong

\- degraded\_unstable

\- blocked



RULES

\- enough bars != good history

\- ranking\_ready != intelligence\_ready

\- handle existence != metric trust

\- synchronization pending != invalid

\- partial copy success != compare-safe

\- readiness must be earned, not inferred from one copy result



EA2 FINALITY HARDENING

\- index 0 is never treated as completed-bar truth

\- completed bars must come from verified closed-bar boundary only

\- last complete bar should be stability-checked, not assumed from position alone

\- finality classification should distinguish:

&nbsp; - stable

&nbsp; - watch

&nbsp; - unstable

&nbsp; - recovering



Rewrite classes:

\- benign\_last\_bar\_adjustment

\- short\_tail\_rewrite

\- structural\_gap\_rewrite

\- historical\_block\_rewrite



Each rewrite class must define invalidation horizon:

\- local metric window

\- timeframe cache

\- compare class

\- structural context

\- symbol-wide severe invalidation only when necessary



EA2 HISTORY WAREHOUSE HARD RULES

\- Copy / build / download lag must degrade honestly, not fake readiness

\- repaired history must survive stability cycles before regaining high compare class

\- full history refresh of all symbols every minute is forbidden

\- deep warehouse fill must continue rolling even after first usable publish

\- storage must remain sharded and bounded

\- warehouse must be future-ready for indicator / strategy consumers

\- warehouse is logically full-universe but physically progressive

\- in-memory active windows must be bounded; persistence owns deep truth



EA2 METRIC HARDENING

Every derived metric must carry:

\- effective\_lookback\_bars

\- warehouse\_clip\_flag

\- warmup\_sufficient\_flag



Metrics near retention boundary or thin warmup must not report high confidence.



EA2 NON-DIRECTIONAL REGIME / CONTEXT PACK

EA2 should prepare compact neutral metrics for downstream selection / export, including where practical:

\- intraday\_activity\_state

\- liquidity\_regime\_class

\- volatility\_regime\_class

\- expansion\_state\_class

\- movement\_quality\_class

\- movement\_maturity\_class

\- microstructure\_noise\_class

\- range\_efficiency\_class

\- noise\_to\_range\_ratio

\- bar\_overlap\_class

\- directional\_persistence\_class

\- two\_way\_rotation\_class

\- gap\_disruption\_class

\- recent\_compression\_expansion\_ratio

\- movement\_to\_cost\_efficiency\_class

\- constructability\_class



These are descriptive only.

They must never encode direction.



EA2 DOWNSTREAM RULE

\- EA3 may use degraded compare-safe subset first.

\- EA5 winner export may include richer winner history packet than the minimal compact pack if budget permits, but must remain bounded.

\- Low-trust or partial history must cap downstream scoring explicitly.



EA2 MT5-SAFE BUILD GUIDE

\- Never treat CopyRates index 0 as completed unless explicitly flagged as live/forming.

\- Explicitly skip index 0 for completed-pack generation.

\- Bind warehouse metrics to finality and continuity hashes.

\- Keep per-symbol writes bounded and dirty-set driven.

\- Never full-refresh the whole history tree every timer pulse.





======================================================================

14\. EA3 FULL SPEC

======================================================================



EA3 remains substantially as v1.5.0 / v1.6.x / v1.7.0:

\- bucket competition

\- family collapse before rank

\- top 5 per bucket

\- reserves

\- frontier

\- diagnostics

\- survivor continuity

\- bounded replacement

\- anti-sticky hysteresis decay



Additional hardening:

\- if EA2 history is still deepening, EA3 must continue with honest penalties instead of waiting indefinitely

\- weak buckets publish fewer than 5 rather than forcing filler

\- dependency\_block\_reason must be visible if rankable subset is too thin

\- no rank may silently treat degraded compare safety as full comparability



Bucket health additions:

\- bucket\_depth\_strong

\- bucket\_depth\_compare\_safe

\- bucket\_depth\_degraded

\- bucket\_confidence\_class

\- bucket\_instability\_reason

\- bucket\_opportunity\_density

\- bucket\_redundancy\_state

\- bucket\_primary\_thinning\_reason



RANKABILITY LANE PARTICIPATION

EA3 must evaluate candidates across:

\- strong lane

\- usable lane

\- exploratory lane



RULES

\- strong lane preferred

\- usable lane fully eligible with confidence drag

\- exploratory lane eligible with capped score / confidence and visible weakness tags

\- publish fewer than 5 only after exploratory lane has been genuinely attempted where policy permits



SELECTION PILLARS

EA3 winner ranking must be non-directional and balance:

1\. truth quality

2\. friction quality

3\. intraday activity quality

4\. intraday volatility usability

5\. constructability

6\. anti-redundancy

7\. freshness / emerging relevance

8\. continuity only near ties



Continuity hardening:

\- continuity protects against noisy replacement

\- continuity must not protect quiet decay

\- continuity bonus only within near-tie band

\- repeated weak survivals must decay

\- reserve and survivor explanations must record replacement\_reason\_code

\- freshness-weighted decay should remove stale campers



EMERGENCE HARDENING

EA3 should allow bounded uplift for symbols showing:

\- fresh activity improvement

\- improved tradeability-now state

\- improved compare safety

\- improved session support

\- near-cutline pressure with low redundancy



This is not a signal.

It is opportunity-surface context.



DIVERSITY-AWARE FINAL PUBLISH TIE-BREAK

After core scoring, EA3 should apply bounded soft penalties for already-selected winner similarity using:

\- family overlap

\- last valid redundancy hint

\- same session-shape dominance

\- volatility / liquidity regime similarity

\- behavior cluster similarity



RULES

\- this is a tie-band adjuster, not a hard exclusion

\- weak symbols may not leapfrog strong symbols merely because they are different

\- diversity should be preferred within comparable quality bands



Expose:

\- bucket\_redundancy\_penalty

\- winner\_archetype\_class

\- reserve\_promoted\_for\_diversity\_flag

\- redundancy\_swap\_reason



EA3 MT5-SAFE BUILD GUIDE

\- Never let exploratory lane candidates masquerade as strong.

\- If penalty model is incomplete, use honest fixed penalties rather than silent zero-penalty.

\- If not enough symbols exist, publish fewer than 5 rather than fake fillers.

\- Ensure score calculations use safe numeric widths.

\- Keep ranking code non-directional and structurally descriptive only.







======================================================================

15\. EA4 FULL SPEC

======================================================================



EA4 remains substantially as v1.5.0 / v1.6.x / v1.7.0:

\- frontier-only intelligence

\- structural overlap

\- bounded statistical overlap

\- pair cache

\- local clusters

\- abstention memory



Additional hardening:

\- honest abstention is preferred over stale fake intelligence

\- EA4 failure must not block EA5 selection\_first mode if other minima remain valid

\- pair work may never starve frontier freshness indefinitely

\- pair validity must be stricter than symbol validity



Pair validity requirements:

\- overlap coverage ratio

\- aligned sample count

\- timeframe trust compatibility

\- latest common completed bar time

\- no severe recent rewrite on either member

\- session comparability class

\- regime comparability class



Expose:

\- pair\_validity\_class

\- pair\_sample\_alignment\_class

\- pair\_window\_freshness\_class

\- sample\_count

\- abstained\_flag

\- diversification\_confidence\_class

\- redundancy\_risk\_class

\- pair\_regime\_comparability\_class



RULES

\- unknown must not silently map to low correlation

\- numerical pair metrics without validity class are forbidden

\- changed member history / trust / session / policy may invalidate pair cache

\- pair cache TTL and changed-pair priority queue are mandatory



PAIR OUTCOME SURFACE

At minimum, distinguish:

\- valid\_low\_overlap

\- valid\_high\_overlap

\- unknown\_overlap

\- provisional\_overlap

\- blocked\_overlap



EA4-lite redundancy hints may be consumed by EA3 when available, but:

\- they are never mandatory

\- they are never allowed to hide staleness

\- they must remain source-aged and confidence-tagged



EA4 MT5-SAFE BUILD GUIDE

\- Default pair state must be Unknown, not Low.

\- If pair cache data is stale or invalid, emit abstention or unknown, not numerical overlap.

\- Keep pair frontier bounded.

\- Any parser or brace edit in this file must trigger explicit class-boundary audit before other changes are trusted.







======================================================================

16\. EA5 FULL SPEC

======================================================================



EA5 remains the only primary external contract.

EA5 exports winners only.

EA5 export cadence remains every 10 minutes.



TOP-LEVEL PUBLIC OUTPUT

\- issx\_export.json



SOURCE RULE

\- EA5 may consume same-tick accepted upstream handoff after acceptance

\- EA5 must still record exact source / handoff / fallback visibility

\- source age and generation surface must be explicit



WINNER PAYLOAD RULE

For winners only, EA5 must include rich broker + history context, not minimal skeleton only.



Per winner, required broker / history richness includes:

\- identity

\- classification

\- observability

\- spec

\- session

\- market

\- cost

\- history quality

\- timeframe trust

\- history provenance

\- history judgment packet

\- compact\_ohlc\_pack minimum

\- active metric pack minimum for ranking / explanation

\- ATR fields used by selection / history logic if available

\- winner-level freshness surface

\- winner-level null / state semantics

\- non-directional regime / context block

\- any other winner-relevant broker / history facts required to minimize downstream guesswork



IMPORTANT SPLIT

\- Full broker truth and full history truth stay internal in EA1 / EA2 persistence.

\- EA5 remains winners-only and bounded.

\- EA5 must be rich enough that top symbols are effortless to reason over without hunting for missing broker / history context.



EA5 HISTORY PACK MINIMUM

compact\_ohlc\_pack:

\- m5\_last\_12

\- m15\_last\_12

\- h1\_last\_8



RULES

\- completed bars only unless explicitly flagged

\- no live / forming bar silently mixed in

\- oldest\_to\_newest ordering mandatory



EA5 PREFERRED WINNER HISTORY PACK

Preferred bounded default when budget allows:

\- m5\_last\_24

\- m15\_last\_16

\- h1\_last\_12



If byte pressure forces downgrade:

\- drop extended bars before dropping regime / context surfaces

\- preserve compact completed-bar core



EA5 OPTIONAL RICHER WINNER HISTORY

if budget allows:

\- extended recent bars for winners only

\- additional active metrics used by EA2 / EA3

\- no loser-rich payloads

\- no full-universe history dump in EA5



EA5 AGE SURFACE

Top-level:

\- export\_generated\_at

\- ea1\_age\_sec

\- ea2\_age\_sec

\- ea3\_age\_sec

\- ea4\_age\_sec optional

\- source\_generation\_ids



Winner-level where applicable:

\- winner\_history\_age\_by\_tf

\- winner\_quote\_age\_sec

\- winner\_tradeability\_refresh\_age\_sec

\- winner\_rank\_refresh\_age\_sec

\- winner\_regime\_refresh\_age\_sec

\- winner\_corr\_refresh\_age\_sec

\- winner\_last\_material\_change\_sec



EA5 WINNER NON-DIRECTIONAL REGIME BLOCK

Per winner, include where available:

\- intraday\_activity\_state

\- liquidity\_regime\_class

\- volatility\_regime\_class

\- expansion\_state\_class

\- movement\_quality\_class

\- movement\_maturity\_class

\- session\_phase\_class

\- tradability\_now\_class

\- constructability\_class

\- holding\_horizon\_context

\- movement\_to\_cost\_efficiency\_class

\- diversification\_confidence\_class

\- redundancy\_risk\_class

\- opportunity\_with\_caution\_flag



Possible descriptive intent:

\- dormant / waking / active / elevated / dislocated

\- compressed / normal / expanding / extended

\- orderly / noisy / fragmented / rotational

\- poor / acceptable / strong for intraday constructability

\- short\_intraday / mixed\_intraday / extended\_intraday context



These must remain descriptive only.



EA5 WINNER EXPLANATION BLOCK

Per winner, bounded and deterministic:

\- selection\_reason\_summary

\- selection\_penalty\_summary

\- regime\_summary

\- execution\_condition\_summary

\- diversification\_context\_summary

\- winner\_limitation\_summary

\- winner\_confidence\_class



These summaries must be:

\- short

\- factual

\- non-directional

\- derived from structured state, not freeform speculation



EA5 SYMPTOM SUMMARIES

Top-level user-facing symptom summaries should include:

\- why\_export\_is\_thin

\- why\_publish\_is\_stale

\- why\_frontier\_is\_small

\- why\_intelligence\_abstained

\- largest\_backlog\_owner

\- oldest\_unserved\_queue\_family



EA5 BYTE DISCIPLINE

\- target\_bytes

\- hard\_max\_bytes

\- per\_symbol\_target\_bytes

\- max\_bars\_per\_symbol\_total



Soft downgrade order:

1\. drop optional secondary explainers

2\. drop optional extended winner history

3\. keep winner regime / context block

4\. keep compact\_ohlc\_pack

5\. keep truth / freshness / completeness

6\. keep selection and intelligence core

7\. keep source\_summary and contradiction\_summary

8\. never drop legend / guidance / integrity / state semantics



EA5 MT5-SAFE BUILD GUIDE

\- Output strings must be UTF-8.

\- Always include state semantics even when data is degraded.

\- Never replace unknown with empty if empty can be misread as healthy.

\- Keep payload bounded before adding richer history.

\- No directional phrasing is allowed in summaries.







EA5 CONTRACT STABILITY RULE

\- EA5 external contract is the most user-facing stable surface and must resist naming churn.

\- Richness may expand.

\- Existing meaning may degrade honestly.

\- External field renames are forbidden unless bridged or versioned explicitly.

\- Empty string must not replace explicit unknown state semantics in winner-facing fields.



16.1A EA5 EXTERNAL FIELD STABILITY CLASSES



EA5 is the most user-facing stable contract surface in ISSX.

Therefore each externally surfaced EA5 field should be treated under one explicit stability class.



STABILITY CLASSES

\- frozen

\- additive\_safe

\- bridged\_deprecated

\- internal\_only



DEFINITIONS

1\. frozen

\- field name and baseline meaning are locked

\- rename is forbidden unless explicitly versioned or bridged

\- removal is forbidden without blueprint authorization



2\. additive\_safe

\- new field may be added without breaking prior consumers

\- existing meanings must remain intact

\- omission semantics must remain explicit



3\. bridged\_deprecated

\- old field remains temporarily supported through bridge or parallel export path

\- removal requires explicit deprecation lifecycle and blueprint approval



4\. internal\_only

\- field is not part of the external stable contract

\- may evolve more freely

\- must not silently leak into user-facing dependency assumptions



MANDATORY EA5 FIELD CLASSIFICATION

At minimum, classify:

\- top-level export identity fields

\- age/freshness fields

\- winner identity fields

\- compact\_ohlc\_pack

\- regime/context fields

\- explanation summary fields

\- source/fallback/degradation fields

\- legend and state-semantics fields



RULES

\- explicit unknown / degraded state fields should generally be treated as frozen or additive\_safe, not disposable

\- empty string must not replace an explicit state field merely to preserve superficial compatibility

\- summary text may evolve within meaning bounds, but structural explanation field names must remain stable

\- additive richness is preferred over mutation of existing meaning

\- external contract churn for cosmetic reasons is forbidden



BRIDGE RULE

\- if a frozen field must evolve, use one of:

&nbsp; 1) parallel new field + old bridged field

&nbsp; 2) explicit versioned contract expansion

&nbsp; 3) documented deprecation lifecycle

\- silent replacement is forbidden

======================================================================

17\. DEBUG / TRACE / HUD CONTRACT

======================================================================



PRIMARY DEBUG OUTPUT

\- issx\_debug.json



OPTIONAL

\- issx\_stage\_status.json

\- per-stage debug snapshots event-driven only



TRACE SEVERITY TIERS

\- error

\- warn

\- state\_change

\- sampled\_info



STRUCTURED TRACE LINES REQUIRED

Every stage must emit concise structured trace lines for:

\- boot restore result

\- upstream load result

\- phase start

\- phase stop

\- publish attempt

\- acceptance result

\- projection result

\- degrade reason

\- contradiction summary

\- queue starvation event

\- fallback event

\- dependency block event

\- repeated resume without completion

\- rewrite storm

\- never-serviced threshold breach

\- accepted-but-not-publishable plateau

\- newly active cold symbol waiting too long

\- diversity swap decision

\- contender promotion decision



TRACE RATE LIMITING

\- repeated identical trace emissions must be rate-limited

\- per-code cooldown is mandatory

\- debug must never become a bottleneck



KERNEL HUD

Rows:

1\. Identity

2\. Global Runtime

3\. Stage Ladder

4\. Universe Summary

5\. Warnings

6\. Sources / Recovery

7\. Queues

8\. Weak Links



STAGE LADDER MUST SHOW

For ea1..ea5:

\- publishability\_state

\- stage\_last\_publish\_age

\- stage\_backlog\_score

\- stage\_starvation\_score

\- dependency\_block\_reason

\- phase\_id

\- phase\_resume\_count

\- weak\_link\_code if any

\- accepted sequence number

\- last attempted age

\- last successful service age

\- fallback depth



HUD RULES

\- render only from precomputed counters

\- never scan live symbol arrays

\- emphasize publish age, backlog, degradation, dependency blocks, and starvation

\- one healthy banner must never hide a dead stage



WEAK LINK SCORING

Each stage should expose:

\- error\_weight

\- degrade\_weight

\- dependency\_weight

\- fallback\_weight



Kernel should expose:

\- weakest\_stage

\- weakest\_stage\_reason

\- weak\_link\_severity



OPPORTUNITY BLIND-SPOT DIAGNOSTICS

Kernel or debug should expose:

\- newly\_active\_symbols\_waiting\_count

\- sector\_cold\_backlog\_count

\- frontier\_refresh\_lag\_for\_new\_movers

\- selection\_latency\_risk\_class

\- never\_ranked\_but\_now\_observable\_count



DEBUG NORMALIZATION RULES

\- All shared debug keys must be registered.

\- Empty string must not silently mean “healthy” when a symbolic “none” or “na” is clearer.

\- Fallback usage must surface explicitly.

\- Repeated fallback habit must degrade public health state.



DEBUG CONTRACT DRIFT RULE

\- Shared trace codes, warning codes, weak-link labels, and HUD status keys must be treated as contract surfaces when consumed across modules.

\- Debug keys may evolve only through owner-controlled additions or documented alias bridging.

\- Ad-hoc spelling drift in debug fields is forbidden because it breaks operator visibility and test harness consistency.



======================================================================

18\. MT5-SAFE IMPLEMENTATION GUIDE

======================================================================



18.1 WRAPPER RULES

\- ISSX.mq5 owns orchestration only.

\- Wrapper may instantiate stage classes, call stage entry points, manage timer lifecycle, and project top-level outputs.

\- Wrapper may not own stage logic, ranking logic, correlation logic, persistence semantics, or JSON contract logic.

\- Wrapper may not compensate for missing owner contracts by declaring local shims.



18.2 INCLUDE RULES

\- Place ISSX folder under MetaTrader Include path.

\- Use <ISSX/...> includes only.

\- No file may depend on wrapper include order.

\- Every header must include core first if it uses core-owned types.

\- Never mix quoted and angle-bracket ISSX includes.

\- Never include the same ISSX file through two path identities.

\- Treat include-path normalization as mandatory repair, not cosmetic cleanup.



18.3 CLASS / METHOD RULES

\- No nested classes.

\- No return-type-only overloading.

\- No unsupported C++ idioms.

\- Avoid return-by-reference for ephemeral values.

\- If method is class-owned, declare it in class with MQL5-safe syntax.

\- Avoid static misuse inside class declarations.

\- If a helper is shared across modules, put it in the owner module rather than recreating it locally.



18.4 JSON RULES

\- Use ISSX\_JsonWriter only.

\- Define shared JSON methods in core only.

\- Use deterministic key naming.

\- Use UTF-8 for output.

\- No duplicate micro-writers inside stages.

\- Shared JSON helper renames require compatibility review just like enums.



18.5 ENUM RULES

\- Shared enum in core only.

\- Stage-local enum in stage only.

\- Legacy aliases in core / registry only.

\- Default enum value must be Unknown / NA / NotReady, not Healthy / Strong / Safe.

\- Enum member rename without alias bridge is forbidden.

\- Enum string-label drift must be reviewed as contract drift.



18.6 NUMERIC SAFETY RULES

\- Eliminate narrowing warnings.

\- Use explicit casts only when semantically safe.

\- Prefer wider type if truncation risk exists.

\- Never let symbol counts, indices, or queue lengths live in suspiciously narrow types.

\- Do not cast shared enum values just to “make it compile” if underlying ownership drift is unresolved.

18.6A NUMERIC WIDTH AND INDEX SAFETY MATRIX



Numeric width choices are contract-relevant in ISSX.

Counts, indices, sequence numbers, hashes, timestamps, and persisted numeric fields must not be improvised casually.



MANDATORY NUMERIC CLASSES

1\. counts and lengths

\- symbol counts

\- bar counts

\- queue lengths

\- bucket depths

\- file lengths

\- retained counts

RULE

\- use widths that cannot truncate realistic operating ranges

\- suspiciously narrow widths are forbidden for shared or persisted count surfaces



2\. indices and array slots

\- dynamic array indices

\- stage slot indices

\- frontier positions

\- bucket positions

RULE

\- raw enum numeric value must not be assumed safe as array index unless owner guarantees it

\- mapping helper is preferred for stage and semantic enums



3\. sequence and generation numbers

\- sequence\_no

\- writer\_generation

\- trio\_generation\_id

\- handoff\_sequence\_no

RULE

\- widths must preserve monotonic comparison safety over expected system lifetime

\- persisted sequence semantics must remain stable across refactors



4\. timestamps and time deltas

\- mono\_ms

\- schedule times

\- quote ages

\- freshness ages

\- publish ages

RULE

\- timestamp width must safely support arithmetic without silent overflow in expected runtime use

\- mixed-unit arithmetic must be explicit



5\. hashes / CRC / fingerprints

\- payload\_hash

\- header\_hash

\- universe\_fingerprint derivation inputs

RULE

\- widths and string encodings must preserve deterministic comparison

\- casts used only to suppress warnings are forbidden



6\. scores / penalties / weighted metrics

\- rank scores

\- penalty accumulators

\- confidence caps

RULE

\- widths must preserve ordering stability

\- no silent truncation that changes winner ordering



MANDATORY REVIEW TRIGGERS

Numeric width review is required when:

\- a field becomes persisted

\- a field becomes exported

\- a field becomes a loop/index driver

\- a field participates in hashing or fingerprinting

\- a field participates in score ordering

\- warnings indicate narrowing or sign-loss risk



FORBIDDEN

\- narrow local counters for shared operating surfaces

\- blind casts to silence warnings

\- enum-to-index assumptions without owner guarantee

\- signed/unsigned semantic confusion hidden by casts

18.7 ARRAY RULES

\- Dynamic arrays only where needed.

\- Always check ArraySize before indexing.

\- Never use enum raw numeric value as index without mapping helper.

\- Avoid silent resize failure assumptions.

\- Do not assume persisted enum numeric value equals current array slot mapping.



18.8 FILE I/O RULES

\- Always check FileOpen / FileWrite / FileClose results.

\- All persistence outputs must declare encoding.

\- No stage may claim write success without verification.

\- Partial write must be visible and degrade honestly.

\- File presence must never be treated as proof of owner-version compatibility.



18.9 HISTORY RULES

\- Completed bars exclude index 0 unless explicitly flagged.

\- Any live/forming-bar inclusion must be marked in output.

\- Finality / continuity must gate metric trust.

\- Completed-bar safety doctrine outranks convenience export packing.



18.10 PERSISTENCE RULES

\- Accepted, previous, last\_good, candidate remain distinct.

\- Same-tick handoff only after acceptance and promotion verification.

\- Manifest fields must stay coherent with header / payload.

\- If shared DTO or manifest semantics change, persistence compatibility review is mandatory.



18.11 DEBUG RULES

\- Rate limit repeated trace lines.

\- Keep trace code short and structured.

\- Debug must not become a bottleneck.

\- Debug is diagnostic, not semantic truth.

\- Shared debug labels must come from stable owner-defined surfaces where applicable.



18.12 PATCH RULES

\- Fix root causes before surface symptoms.

\- First audit include / brace / duplicate-owner failures.

\- Then audit missing types / helper drift / signature drift.

\- Then harden runtime honesty.

\- Then harden blueprint conformity.

\- Then perform contract drift self-audit before returning code.

\- Do not silently rename shared surfaces for aesthetic consistency.



18.13 ANTI-DRIFT PATCHING RULES

\- If a shared owner file is being changed, assume drift risk by default.

\- Review downstream compile implications before finalizing.

\- Prefer extension over mutation.

\- Prefer alias bridge over breaking rename.

\- Prefer canonicalization over local workaround.

\- Prefer owner repair over consumer shim.



18.14 ASSISTANT SELF-CHECKLIST BEFORE RETURNING CODE

The assistant must internally verify all of the following:

\- include identity canonicalized

\- no duplicated shared enums / DTOs / helpers added

\- no removed shared symbol still referenced unbridged

\- no renamed symbol lacks alias bridge

\- no stronger defaults introduced

\- no silent field-key spelling drift introduced

\- no unresolved shared signature mismatch introduced

\- no parser spill risk left obvious in edited block

\- no code returned that compiles only because of hidden transitive includes



======================================================================

19\. BUILD ORDER

======================================================================



Phase 1

\- patch blueprint-aligned core and registry if needed

\- preserve existing current work where compatible

\- add new registry coverage and policy\_fingerprint support

\- enforce include doctrine

\- enforce shared enum ownership

\- enforce compatibility-alias bridge where shared renames exist



Phase 2

\- patch issx\_runtime.mqh into kernel scheduler owner

\- patch issx\_persistence.mqh for handoff + dump + warehouse primitives + generation coherence

\- fix scheduler field coverage and numeric safety warnings

\- verify shared DTO / signature coherence against core



Phase 3

\- patch issx\_market\_engine.mqh for stage entry points + universe dump assembly + discovery state machine

\- verify no stage-local duplicates of shared owner surfaces exist



Phase 4

\- patch issx\_history\_engine.mqh for rolling history warehouse + sync / finality state machine + regime / context metric prep

\- explicitly enforce no-index-0 completed-bar discipline

\- verify finality / rewrite enums remain owner-consistent



Phase 5

\- patch issx\_selection\_engine.mqh for rankability lanes + opportunity-surface inputs + diversity-aware final tie-break

\- verify shared selection lane / confidence / bucket surfaces align with core / registry



Phase 6

\- patch issx\_contracts.mqh for source summary + richer winner broker / history packet support + symptom summaries + trader-handoff-ready neutral summaries

\- verify no user-facing contract renames occur without bridge/versioning



Phase 7

\- patch issx\_correlation\_engine.mqh for pair validity classes + diversification confidence + lightweight redundancy hints

\- explicitly audit class closure and duplicate block risk

\- verify unknown-vs-low separation remains owner-consistent



Phase 8

\- finalize issx\_ui\_test.mqh for kernel HUD, traces, weak-link reporting, aggregated debug summary, rate limiting

\- remove all duplicate shared enum ownership from UI

\- verify UI consumes but does not redefine shared labels or state surfaces



Phase 9

\- build ISSX.mq5 single wrapper

\- verify angle-bracket include discipline

\- verify EventSetTimer / EventKillTimer lifecycle

\- verify wrapper did not absorb compatibility shims that belong in owner modules



Phase 10

\- hardening

&nbsp; - semantic acceptance

&nbsp; - compatibility-aware fallback verification

&nbsp; - same-tick handoff verification

&nbsp; - warehouse stress

&nbsp; - timer-lossiness and schedule-lateness validation

&nbsp; - startup-to-usable validation

&nbsp; - file-generation coherence validation

&nbsp; - repeated fallback health downgrade validation

&nbsp; - breadth-with-honesty validation

&nbsp; - winner regime/context usefulness validation

&nbsp; - warning-zeroing validation

&nbsp; - shared contract drift validation

&nbsp; - include identity validation

&nbsp; - alias bridge validation

&nbsp; - owner-surface freeze validation

19.1 RELEASE GATE AND PATCH-READY VALIDATION



A patch is not considered blueprint-ready merely because it appears cleaner or compiles partially.

Readiness requires explicit gate checks.



MANDATORY RELEASE GATES

1\. compile gate

\- no compile errors in targeted files

\- no parser spill indicators

\- no declaration/definition mismatch in targeted surfaces



2\. warning gate

\- zero load-bearing warnings

\- no truncation, narrowing, sign-loss, unsafe enum/index conversion, suspicious shadowing, or expression-has-no-effect warnings in touched code



3\. include gate

\- all ISSX-owned includes canonicalized to <ISSX/...>

\- no mixed include-path identity

\- no hidden transitive-include dependency for directly-used symbols



4\. ownership gate

\- no duplicate shared semantic enum ownership

\- no duplicate shared DTO ownership

\- no duplicate shared JSON helper family

\- no consumer-local shim hiding owner drift



5\. contract drift gate

\- shared owner diffs reviewed

\- compatibility bridges added where required

\- no silent rename without alias or same-wave migration

\- no stronger default semantics introduced silently



6\. persistence gate

\- accepted/current/previous/last\_good/candidate separation preserved

\- generation coherence logic preserved

\- persistence version review performed where relevant



7\. completed-bar gate

\- no silent index 0 inclusion in completed-bar truth

\- compact OHLC pack remains completed-bar-safe unless explicitly flagged otherwise



8\. fallback honesty gate

\- fallback usage remains visible

\- degraded semantics remain explicit

\- unknown does not masquerade as healthy / safe / low-risk / low-correlation



9\. scheduler honesty gate

\- due-aware dispatch still exists where expected

\- reserved commit/publish budget not silently removed

\- deep work does not trivially starve freshness work



10\. external contract gate

\- EA5 field stability preserved

\- external field rename reviewed and bridged/versioned if needed

\- explicit unknown / degraded semantics preserved



PATCH COMPLETION RULE

\- A patch is blueprint-complete only after all relevant gates above have been checked.

\- “Compiles on my side” is insufficient without ownership and drift review.



FORBIDDEN

\- returning a patch as complete after compile-only validation

\- ignoring warning clusters in load-bearing logic

\- treating gate failure as acceptable because the patch is small

======================================================================

20\. STRESS HARNESS REQUIRED CASES

======================================================================



All v1.5.0 / v1.6.x / v1.7.0 stress cases remain relevant.



Additional mandatory cases:

1\. broker universe flood

\- large broker symbol set

\- first usable publish still appears without full deep probe completion



2\. history warehouse growth

\- many symbols still warming

\- first EA5 export still appears on time

\- warehouse deepens over later cycles



3\. same-tick handoff honesty

\- ea1 accepted current consumed by ea2 same cycle

\- source visibility remains explicit



4\. weak-link isolation

\- ea4 repeatedly faults

\- ea1-ea3 continue

\- ea5 downgrades honestly



5\. max-bars limitation / partial history

\- warehouse degrades honestly

\- compare class capped

\- no fake deep readiness



6\. queue starvation chaos

\- deep history backlog grows

\- ea1 freshness protected

\- ea3 still eventually serviced



7\. publish contention

\- several stages due in same minute

\- reserved commit budget still protects promotion



8\. restart with mixed partial cycle

\- accepted truth preserved

\- phase resume preserved only when compatible

\- no stage loses truth because another stage had not finished



9\. rewrite storm after reconnect

\- multiple symbol / timeframe stores rewrite tail segments after apparent stability

\- cache invalidation and downgrade honesty verified



10\. mixed generation persistence

\- candidate manifest valid, payload old generation, restart occurs

\- accepted selection rejects mixed trio



11\. taxonomy / family drift

\- broker renames / adds suffixes or remaps families mid-run

\- family collapse continuity and duplicate prevention verified



12\. history sync pending forever on subset

\- repeated unsynced symbols

\- backoff and no hot-loop verified



13\. lock stale recovery

\- crash leaves stale lock

\- new instance reclaims with explicit audit



14\. debug flood under fault loop

\- repeated same fault

\- rate limiting verified

\- debug never becomes bottleneck



15\. weekend / quote-stale market closed mode

\- quote clock stale

\- no false starvation or false panic freshness downgrade



16\. early liquid expansion emergence

\- symbol moves from ordinary to high activity during session transition

\- spread remains acceptable

\- history compare-safe is degraded but usable

\- symbol may enter contender / winner flow without waiting for deep completion



17\. sector redundancy trap

\- bucket has many similar high-score symbols

\- final top 5 should show better structural diversity without forcing weak fillers



18\. exploratory-lane honesty

\- exploratory candidates may appear only with visible confidence penalties

\- exploratory never masquerades as strong



19\. stale winner camping

\- formerly strong symbol loses current activity / freshness

\- continuity decays

\- fresher contender may replace within bounded policy



20\. low-correlation illusion test

\- unknown / stale pair evidence must never present as safe diversification



21\. include-order sabotage test

\- compile should not depend on unrelated header inclusion sequence



22\. duplicate-owner sabotage test

\- adding a shared enum to UI or engine must fail review and be caught



23\. UTF-8 fingerprint stability test

\- same logical content must hash identically across locale differences



24\. numeric narrowing test

\- compile warnings must be zero after type hardening



25\. completed-bar integrity test

\- compact packs must exclude index 0 unless explicitly flagged live







Additional mandatory cases:

26\. shared enum rename without downstream patch

\- owner introduces new enum member names

\- compatibility bridge must preserve compile stability

\- downstream files must still compile or fail only if blueprint explicitly allows hard break



27\. include-path dual-identity sabotage

\- one file included once via quoted path and once via angle-bracket path in different modules

\- build must be treated as invalid

\- patch must canonicalize include identity



28\. owner-helper duplication sabotage

\- stage or UI duplicates a shared helper from core

\- review must detect ownership breach

\- fix must remove duplicate, not tolerate it



29\. field-key spelling drift test

\- one module uses literal with minor spelling drift from core constant

\- contract audit must catch it

\- fix must unify on owner constant



30\. compatibility-alias removal too early test

\- old symbol still used downstream

\- owner removes alias prematurely

\- build review must reject the change



31\. DTO shape drift test

\- shared struct gains or renames field

\- downstream compile, reset logic, persistence, and serialization reviews must all be triggered



32\. semantic-default regression test

\- refactor changes unknown/not\_ready default to usable/healthy

\- review must reject as contract strengthening defect



33\. transitive-include illusion test

\- consumer compiles only because unrelated file included core dependency first

\- review must detect missing direct include and fix it



34\. assistant patch-wave incompleteness test

\- owner file changed but dependent files not updated

\- compatibility bridge or same-wave patch completeness must be enforced



35\. duplicate-root file presence test

\- multiple copies of ISSX-owned file exist in different include roots

\- assistant must not rely on accidental compile path resolution

\- canonical include doctrine must remain explicit



======================================================================

21\. FINAL HARD GUARANTEES THIS SPEC TRIES TO DELIVER

======================================================================



Guaranteed by design if coded correctly:

\- no silent root-only truth

\- no silent stage-boundary collapse

\- no family duplicate competition without explicit handling

\- no weak bucket filler by default

\- no corr penalty without validity context

\- no EA5 field without owner, meaning, and semantics

\- no null ambiguity in EA5

\- no direction language in EA5

\- no candidate snapshot silently treated as accepted truth

\- no fallback consumption without compatibility visibility

\- no full-universe deep recomputation every minute by default

\- no cache reuse without explicit invalidation

\- no loss of full broker truth simply because public roots are reduced

\- no loss of full history truth simply because EA5 remains winners-only

\- no one weak link silently breaking the whole experience without visibility

\- no timer-pulse-count dependency for scheduler correctness

\- no same-tick handoff bypass of acceptance

\- no mixed-generation trio accepted as coherent truth

\- no unknown correlation presented as low correlation

\- no breadth collapse from over-tight purity gates by design

\- no directional bias encoded in winner regime / context surfaces

\- no duplicate shared enum / type ownership by design

\- no accidental compile only via include order by design

\- no completed-bar pack silently including index 0 by design

\- no locale-dependent fingerprinting by design if UTF-8 rules are obeyed

\- no silent shared contract renames by design

\- no premature removal of shared compatibility symbols by design

\- no mixed include-path identity for ISSX-owned files by design

\- no assistant-local duplicate owner definitions as quick fixes by design

\- no owner-surface mutation without compatibility review by design



Not guaranteed because MT5 cannot guarantee them:

\- perfect timer cadence

\- perfect broker metadata

\- perfect history availability on first touch

\- zero runtime surprises

\- zero external corruption

\- universal full deep readiness in one minute

\- perfectly stable server / quote clocks under all terminal states

\- zero future human or assistant mistakes



The system handles those by:

\- accepted stage truth

\- rolling warehouse hydration

\- bounded runtime

\- same-tick accepted handoff

\- queue fairness

\- explicit degraded semantics

\- protected publish budgets

\- contradiction flags

\- dependency block reasons

\- weak-link debug visibility

\- policy-aware compatibility checks

\- generation-coherent persistence validation

\- fallback-ratio health visibility

\- breadth-with-honesty ranking

\- confidence-tagged trader-handoff context

\- strict compile governance

\- deterministic encoding / fingerprint rules

\- compatibility alias bridges

\- canonical include identity doctrine

\- owner-surface freeze doctrine

\- assistant self-audit gates

\- cross-file patch-wave completeness doctrine



======================================================================

22\. FINAL IMPLEMENTATION COMMANDMENTS

======================================================================



\- Keep 5 logical stages even though there is one EA

\- Keep the wrapper thin

\- Keep truth state, work state, and projection state distinct

\- Keep internals compact and indexed

\- Keep EA5 explicit and rich for winners

\- Keep full broker-universe truth internally

\- Keep full history-universe truth internally

\- Never let deep hydration block minimum useful output

\- Never let fallback become the normal path

\- Never let debug require archaeology to find the weak link

\- Never let stage-local degradation hide behind a healthy kernel banner

\- Never let invalid correlation look like safe low correlation

\- Never let missing look like zero

\- Never let rank look like direction

\- Never let warehouse growth become unbounded

\- Never full-scan the universe every timer pulse

\- Never bypass acceptance for same-tick handoff

\- Never collapse all stage persistence into one mega snapshot

\- Never rebuild from ground zero where efficient patching can adapt the current modules cleanly

\- Never infer schedule correctness from timer pulse count

\- Never trust index 0 as completed-bar truth

\- Never let schema compatibility stand in for policy compatibility

\- Never let repeated fallback survival pass as healthy normal flow

\- Never let quality hardening quietly become opportunity starvation

\- Never let unknown diversification masquerade as safe diversity

\- Never let winner context become directional under the excuse of being helpful

\- Never allow mixed include style for ISSX-owned files

\- Never redefine shared semantic enums outside core

\- Never hide compatibility shims inside stage code

\- Never let shared JSON helper names drift across modules

\- Never treat compiler warnings as harmless on load-bearing code

\- Never let a file compile only because another unrelated file included its dependencies

\- Never let default state imply healthy when the true state is unknown

\- Always use UTF-8 for deterministic hashing and persistence text outputs

\- Always document legacy aliases and transitional shims

\- Always verify brace integrity after parser-collapse fixes

\- Always prefer root-cause repair over symptom patching

\- Always prefer explicit honesty over quiet convenience





ADDITIONAL COMMANDMENTS

\- Never rename a shared contract symbol without bridge or full migration.

\- Never mutate owner surfaces casually during compile-fix work.

\- Never let canonical include identity drift.

\- Never use local duplication to mask missing owner definitions.

\- Never return a patch that is knowingly cross-file incomplete when compatibility bridge could prevent breakage.

\- Always treat shared contract drift as a primary failure mode.

\- Always prefer owner-controlled backward compatibility over downstream hacks.

\- Always self-audit changed shared surfaces before responding.



======================================================================

23\. FINAL WRAPPER RULE

======================================================================



Use one wrapper only:

\- ISSX.mq5



Internal machine stage IDs remain:

\- ea1

\- ea2

\- ea3

\- ea4

\- ea5



No human-facing stage wrapper filenames are used in this version.



======================================================================

24\. OPERATIONAL PATCH WORKFLOW + ARCHITECTURAL ENFORCEMENT ADDON

======================================================================



STATUS

\- This addon is mandatory for all future ISSX coding passes performed through chat.

\- It governs blueprint-first patching, text-file patch workflow, MT5 compiler remediation order, and architectural enforcement during repair.

\- It exists to prevent drift, compile-order hacks, duplicate ownership, wrapper bloat, symptom-only patching, silent contract renames, and assistant-induced mismatch cascades.



PURPOSE

\- Ensure future coding passes remain patch-friendly rather than rewrite-heavy.

\- Ensure blueprint doctrine is applied before compiler-error cleanup.

\- Ensure the assistant always works from the file pasted in chat as the active patch target.

\- Ensure returned code is copy-paste-ready for MetaEditor.

\- Ensure compile-error repair is root-cause-driven, not line-noise-driven.

\- Ensure all fixes move ISSX toward v1.7.2 governance rather than away from it.

\- Ensure shared-contract evolution remains backward-stable unless explicitly version-broken by the blueprint.



======================================================================

24.1 DEFAULT USER WORKFLOW

======================================================================



The expected workflow for all future ISSX work is:



STEP 1

\- I provide the master blueprint first.



STEP 2

\- I paste one ISSX source file into chat as plain text.

\- The pasted text is the active patch target for that pass.



STEP 3

\- The assistant audits the pasted file against the blueprint first.

\- The assistant patches the file toward blueprint compliance first.



STEP 4

\- The assistant returns the full updated file in one code block.

\- No omitted sections.

\- No placeholders.

\- No “rest unchanged”.

\- No pseudo-code.



STEP 5

\- I compile the returned file in MT5 / MetaEditor.



STEP 6

\- I paste the actual compile errors and warnings from MetaEditor.



STEP 7

\- The assistant fixes those compile errors against the already-blueprint-aligned file.



STEP 8

\- The assistant returns the full corrected file again in one code block.



This sequence is the default and must be followed unless I explicitly request a different order.





======================================================================

24.2 SOURCE-OF-TRUTH RULE FOR TEXT-UPLOADED FILES

======================================================================



When I paste a source file into chat:



\- That pasted file becomes the immediate authoritative source for that patch pass.

\- Do not assume hidden local files are newer.

\- Do not merge with imaginary unseen content.

\- Do not invent code from files I did not paste unless clearly required by ownership rules.

\- If the pasted file is truncated, malformed, or obviously incomplete, state that clearly before patching.

\- If the pasted file conflicts with the blueprint, patch toward the blueprint unless I explicitly request a temporary tactical workaround.



RULE

\- The assistant must treat the pasted source text as the active editable artifact for the current pass.





ADDITIONAL RULE

\- The pasted file is authoritative for editing, but not for ownership invention.

\- If the pasted file conflicts with known owner doctrine, repair toward owner doctrine rather than making the file self-contained by duplication.

\- If the pasted file appears to be a non-canonical include-path variant of an ISSX owner file, normalize content toward the canonical ISSX path doctrine in the returned result.



======================================================================

24.3 BLUEPRINT-FIRST EXECUTION RULE

======================================================================



Before fixing compiler errors, the assistant must first align the pasted file to the blueprint wherever the blueprint clearly governs the issue.



Examples of blueprint-first corrections:

\- convert quoted ISSX includes to angle-bracket ISSX includes

\- remove duplicate shared enums or DTOs from non-owner files

\- normalize toward thin-wrapper behavior

\- normalize public stage entry points toward required stage API

\- restore one-owner JSON helper discipline

\- restore shared-core enum ownership

\- restore completed-bar safety doctrine

\- restore persistence truth separation

\- restore owner-boundary semantics



REASON

\- Many MT5 compile failures are downstream symptoms of ownership drift, parser collapse, include-order dependence, or signature drift.

\- Blueprint-first patching reduces repeated compile-fix churn.





ADDITIONAL EXAMPLES OF BLUEPRINT-FIRST CORRECTIONS

\- add compatibility alias bridge when owner rename caused downstream drift

\- restore canonical include identity

\- replace duplicated shared string literals with owner constants where load-bearing

\- revert accidental stronger defaults to unknown/not\_ready semantics

\- restore shared DTO ownership when local copies appeared

\- undo assistant-introduced semantic “cleanup” that changed contract meaning



24.31A FILE-PASS AUDIT CHECKLIST



For every one-file ISSX patch pass, the assistant must internally audit the pasted file against at least these questions before returning code:



\- Does this file violate canonical <ISSX/...> include identity?

\- Does this file directly use any owner type without directly including its owner?

\- Does this file redefine any shared enum, DTO, constant, JSON helper, or debug key that belongs elsewhere?

\- Does this file introduce or preserve a silent rename of a shared contract?

\- Does this file strengthen any default semantic from unknown/not\_ready to usable/healthy/strong?

\- Does this file rely on transitive includes to compile?

\- Does this file hide an owner problem with a local shim or local literal duplication?

\- Does this file affect persistence meaning, completed-bar truth, or EA5 external semantics?

\- Does this file require same-wave owner or consumer review?



If any answer indicates drift risk, repair must prefer owner integrity over local convenience.



24.32A OWNER / CONSUMER REPAIR TABLE



Use this decision table when deciding where to patch:



\- shared enum missing or renamed

&nbsp; - repair location: core owner or core compatibility bridge



\- shared DTO field drift

&nbsp; - repair location: core owner + consumer audit + persistence review if persisted



\- shared field-key spelling drift

&nbsp; - repair location: owner constant surface



\- shared JSON helper mismatch

&nbsp; - repair location: core owner only



\- registry metadata mismatch with core enum meaning

&nbsp; - repair location: registry documentation/metadata, never enum redefinition



\- missing direct include for directly-used shared type

&nbsp; - repair location: consumer include site



\- parser spill / brace damage local to one file

&nbsp; - repair location: local file first



\- wrapper carrying stage business logic

&nbsp; - repair location: wrapper thinning + restore owner responsibility to proper module



\- EA5 external key rename pressure

&nbsp; - repair location: contract bridge / versioned external contract, never silent direct rename



\- local quick-fix duplicate of owner symbol

&nbsp; - repair location: remove local duplicate, repair owner or include root cause

======================================================================

24.4 FULL-FILE RETURN RULE

======================================================================



Unless I explicitly request a diff-only or snippet-only answer, always return:



\- the complete updated file

\- in one fenced code block

\- with no omitted middle sections

\- with no placeholders

\- with no commentary inside the code block

\- with no narrative mixed into code

\- with no partial fragments for load-bearing edits



This is mandatory because my workflow is direct copy-paste back into MT5 / MetaEditor.



FORBIDDEN OUTPUT FOR DEFAULT PATCH PASSES

\- “apply these changes manually”

\- “rest unchanged”

\- partial patch fragments for structural issues

\- pseudo-code replacements

\- abbreviated bodies with comments like “existing logic continues here”





======================================================================

24.5 NO-FRAGMENT RULE

======================================================================



For load-bearing repair work, do not return only snippets unless I explicitly ask for snippet-only help.



Examples of load-bearing work that require full-file return:

\- include cleanup

\- enum ownership cleanup

\- class closure repair

\- signature normalization

\- wrapper thinning

\- persistence-path repair

\- stage API normalization

\- parser-collapse repair

\- completed-bar safety repairs

\- warning-zeroing in broad sections



RULE

\- If the file can be returned fully, return the full file.





======================================================================

24.6 DEFAULT RESPONSE FORMAT FOR PATCH PASSES

======================================================================



For each coding pass, the assistant should respond in this structure:



A. AUDIT

\- concise bullets describing the main blueprint or compile issues found



B. UPDATED FILE

\- one full code block containing the complete updated file



C. NOTES

\- brief remaining cross-file risks, if any

\- brief statement whether issues appear local-only or cross-file



However, when I explicitly ask for “one complete codeblock only”, then the assistant must return only the code block and nothing else.







======================================================================

24.7 COMPILE-ERROR REPAIR RULE

======================================================================



When I provide MT5 / MetaEditor compile errors:



\- treat the error list as a real diagnostic surface

\- fix root causes, not cosmetic symptoms

\- expect parser-collapse cascades in MQL5

\- prioritize the earliest structural failure that can generate many secondary errors

\- preserve blueprint discipline while repairing

\- do not use quick hacks that violate ownership or architecture just to reduce error count



RULE

\- Compile repair happens after blueprint alignment unless a parser-collapse defect must be fixed immediately to make the file patchable at all.





ADDITIONAL RULE

\- If a compile failure plausibly originates from a shared-owner rename, include-path drift, or duplicate owner definition, repair that contract root before touching local symptom sites.

\- The assistant must assume error avalanches are common and must not count raw error volume as evidence of many independent defects.



======================================================================

24.8 MQL5 / MT5 ERROR TRIAGE ORDER

======================================================================



Always triage errors in this order:



PRIORITY A: parser / scope / class closure failures

\- missing brace

\- duplicate block

\- global-scope spill

\- class not closed

\- struct/class semicolon missing

\- accidental nested parser damage



PRIORITY B: include-path identity / owner-file visibility failures

\- quoted-vs-angle mismatch

\- same file reachable through multiple identities

\- missing owner-file include

\- hidden owner skipped because alternate include path already consumed guard

\- accidental compile success only via path coincidence



PRIORITY C: owner contract / compatibility drift failures

\- shared enum renamed without alias bridge

\- shared constant renamed without alias bridge

\- DTO field renamed/removed without downstream review

\- helper family drift

\- manifest field drift

\- signature drift at shared owner surface



PRIORITY D: declaration / definition mismatch

\- method declared but not defined

\- wrong parameter list

\- wrong constness

\- wrong scope resolution

\- overload differing only by return type

\- class-name drift



PRIORITY E: duplicate ownership failures

\- shared enum defined in multiple files

\- shared DTO duplicated

\- JSON helper duplicated

\- registry redefining core-owned semantics

\- UI redefining shared semantic enums

\- stage-local shim hiding shared-owner drift



PRIORITY F: narrowing / warning / MT5-safety failures

\- truncation

\- sign-loss

\- narrowing conversion

\- shadowing

\- suspicious dead expressions

\- unsafe enum-to-index assumptions

\- string/number conversion drift



PRIORITY G: runtime honesty / blueprint conformance defects

\- wrapper semantic leakage

\- scheduler bypass

\- candidate treated as truth

\- fallback dishonesty

\- completed-bar misuse

\- unknown mapped to safe / healthy / low



======================================================================

24.9 WARNING-ZEROING RULE FOR FUTURE PASSES

======================================================================



All warnings that imply risk in load-bearing code are defects.



This includes at minimum:

\- truncation warnings

\- narrowing warnings

\- sign-loss warnings

\- suspicious shadowing

\- suspicious defaulting

\- expression-has-no-effect warnings

\- unsafe enum/integer conversion warnings

\- string encoding drift where deterministic semantics matter



Fix warnings by:

\- widening types

\- using explicit semantically-safe casts

\- correcting index and count types

\- correcting helper signatures

\- correcting enum-mapping helpers

\- correcting loop/index arithmetic

\- correcting dead expressions

\- correcting ownership so types align naturally



DO NOT:

\- silence warnings cosmetically

\- cast blindly to hide defects

\- leave warning clusters unresolved in load-bearing logic



RULE

\- ISSX should target zero warnings for load-bearing code.





======================================================================

24.10 ARCHITECTURAL ENFORCEMENT DURING PATCHING

======================================================================



Every patch pass must enforce the following architecture rules where applicable:



1\. thin-wrapper doctrine

\- ISSX.mq5 owns orchestration only

\- wrapper must not absorb ranking logic

\- wrapper must not absorb correlation semantics

\- wrapper must not absorb stage-owned persistence semantics

\- wrapper must not absorb JSON contract semantics

\- wrapper may instantiate stages, call stage entry points, manage timer lifecycle, and coordinate top-level flow only



2\. five logical stages survive

\- one wrapper does not mean stage collapse

\- ea1..ea5 remain distinct logical owners

\- stage failure boundaries remain visible

\- stage acceptance remains local

\- stage persistence remains local

\- stage truth remains local



3\. truth / work / projection separation

\- accepted truth is not work progress

\- work progress is not public projection

\- public JSON is not authoritative truth

\- candidate current is not accepted current

\- same-cycle in-memory data is not automatically authoritative truth



4\. accepted-truth discipline

\- candidate files are never truth until accepted

\- same-tick handoff must not bypass acceptance

\- accepted current remains distinct from previous

\- last\_good remains distinct from previous

\- file existence never implies validity



5\. completed-bar discipline

\- CopyRates index 0 must never silently enter completed-bar truth

\- forming bar and completed bars must remain distinct

\- compact packs must use completed bars only unless explicitly flagged otherwise

\- if completed-bar safety cannot be proven in the pasted file, note the risk clearly



6\. unknown-is-not-safe discipline

\- unknown must never masquerade as safe

\- missing must never masquerade as zero

\- unknown overlap must never masquerade as low overlap

\- unknown tradeability must never masquerade as cheapness or usability

\- default enum state must not imply healthy / strong / safe unless explicitly justified





7\. shared-contract integrity

\- owner symbols must remain stable or bridged

\- rename drift must be repaired in owner, not consumer

\- shared string keys must not fork silently

\- DTO shape changes require contract review

\- helper family drift must be reconciled at owner boundary



8\. assistant anti-drift responsibility

\- the assistant must assume any shared-owner edit may affect many consumers

\- the assistant must self-audit for blast radius before returning code

\- the assistant must not prioritize elegance over compatibility

\- the assistant must not treat compile suppression as architectural success



======================================================================

24.11 INCLUDE GOVERNANCE ENFORCEMENT RULE

======================================================================



For every future patch pass:



\- all ISSX-owned includes must use angle-bracket form:

&nbsp; #include <ISSX/...>



\- quoted ISSX includes are forbidden

\- mixed include style for ISSX-owned files is forbidden

\- every file must include every dependency it directly uses

\- no file may depend on transitive includes to compile

\- no file may compile only because wrapper or UI happened to include a hidden dependency first



REQUIRED ASSISTANT BEHAVIOR

\- if a pasted file uses quoted ISSX includes, convert them to angle-bracket ISSX includes

\- if a file lacks a direct include for a directly-used type, add it

\- do not create shortcut hacks that bypass include doctrine





ADDITIONAL REQUIRED ASSISTANT BEHAVIOR

\- if pasted files mix canonical and non-canonical ISSX include identities, normalize all touched lines to canonical `<ISSX/...>` form

\- if the file likely compiled before only because of hidden include order, add direct includes rather than relying on context

\- never leave mixed quoted/angle ISSX includes in returned patched code



======================================================================

24.12 SHARED OWNERSHIP ENFORCEMENT RULE

======================================================================



During every patch pass, enforce these ownership rules:



CORE-OWNED

\- shared semantic enums

\- shared DTOs

\- shared constants

\- shared compatibility helpers

\- ISSX\_JsonWriter

\- shared path/key constants



REGISTRY-OWNED

\- field registry

\- field metadata

\- normalization helpers that reference core-owned semantics

\- compatibility surfaces that do not redefine semantic ownership



RUNTIME-OWNED

\- scheduler logic

\- due checks

\- budgeting

\- stage dispatch

\- starvation/fairness

\- invalidation routing

\- stage-index mapping if not in core



PERSISTENCE-OWNED

\- accepted/current/previous/last\_good/candidate persistence mechanics

\- generation coherence checks

\- same-tick accepted handoff helpers

\- lock helpers

\- warehouse shard primitives

\- projection outcome tracking



STAGE-OWNED

\- only stage-local enums if not shared across modules

\- only stage-local business logic

\- no redefinition of shared semantic enums

\- no local clone of JSON writer surfaces

\- no local clone of shared DTOs



UI-OWNED

\- display logic only

\- read-only debug / HUD / trace display logic

\- no shared semantic enum ownership

\- no duplicate owner types



RULE

\- If a shared semantic enum or helper is duplicated in a pasted file outside its owner, remove the duplicate and use the owner definition.





ADDITIONAL RULE

\- If a consumer file contains a local substitute for a core-owned or registry-owned symbol because the owner changed, remove the substitute and repair through owner compatibility or correct include dependency.

\- Owner violations are defects even when they reduce local compile errors.



======================================================================

24.13 JSON WRITER SINGLE-OWNER RULE

======================================================================



ISSX\_JsonWriter is core-owned.



Therefore:

\- no stage may create a parallel JSON writer family

\- no UI file may define competing writer helpers

\- no registry file may define competing writer helpers

\- helper names such as KeyValue, BeginNamedArray, WriteString, WriteLong, NameString, NameInt, and stable variants must remain core-owned only



PATCH RULE

\- If a pasted file creates a duplicate shared writer surface, remove it and bind usage back to the core-owned writer.





======================================================================

24.14 STAGE API NORMALIZATION RULE

======================================================================

Every stage class must move toward this public surface:



Mandatory public entry points:

\- StageBoot

\- StageSlice

\- StagePublish

\- BuildDebugSnapshot



Optional:

\- BuildStageJson

\- BuildDebugJson

\- ExportOptionalIntelligence



PATCH BEHAVIOR

\- If a stage file is supplied, normalize toward these entry points where feasible without unnecessary rewrite

\- do not add ad-hoc public APIs when one of the required surfaces should be used instead

\- do not preserve inconsistent public API drift just because it currently compiles



CONTRACT RULE

\- Shared signature changes must be kept coherent across declaration and definition in the same patch wave where possible



ADDITIONAL RULE

\- If public stage APIs already exist and are consumed widely, prefer additive compatibility wrappers over breaking renames unless blueprint explicitly requires hard replacement.

\- Do not “clean up” API names during unrelated compile-fix work.



======================================================================

24.15 WRAPPER THINNING ENFORCEMENT RULE

======================================================================



When patching ISSX.mq5, enforce:



ALLOWED WRAPPER RESPONSIBILITIES

\- instantiate stage objects

\- initialize runtime/kernel state

\- manage EventSetTimer and EventKillTimer

\- call runtime scheduler / dispatch entry points

\- coordinate top-level export invocation if still wrapper-owned by current integration phase

\- perform high-level orchestration only



FORBIDDEN WRAPPER RESPONSIBILITIES

\- stage ranking logic

\- stage correlation logic

\- stage acceptance semantics

\- stage file-promotion semantics

\- stage-owned manifest field composition

\- stage-owned candidate rotation logic

\- stage-owned JSON contract ownership

\- stage-owned broker/history semantic transformations



If a wrapper file currently contains these deeper responsibilities, patch it toward thinner ownership as far as can be safely achieved in the current pass.





======================================================================

24.16 SCHEDULER HONESTY ENFORCEMENT RULE

======================================================================



When runtime, wrapper, or stage dispatch code is supplied:



\- do not let scheduler logic exist only cosmetically

\- if due flags, cadence logic, publish intervals, starvation controls, or budget classes exist, dispatch must actually honor them

\- timer pulse count must never be treated as correctness truth

\- EA5 cadence must respect 10-minute policy unless explicit degraded/forced policy says otherwise

\- publish-critical budget must remain reserved

\- deep backlog work must not starve freshness work

\- optional enrichment must yield under pressure



If the pasted file bypasses the scheduler and brute-runs all stages every pulse, patch toward actual due-aware dispatch.





======================================================================

24.17 PERSISTENCE HONESTY ENFORCEMENT RULE

======================================================================



Whenever patching persistence-related code:



\- accepted current, previous, last\_good, and candidate must remain distinct

\- file existence must not imply file validity

\- candidate truth must not be consumed pre-acceptance

\- generation coherence must be checked

\- same-tick handoff must not bypass acceptance

\- public root files are views only, not authoritative truth

\- manifest richness must not be faked with healthy-looking defaults

\- promotion verification must remain explicit where supported



If a persistence field is declared but not truthfully populated, prefer honest NA / unknown / default-degraded semantics rather than fake certainty.





======================================================================

24.18 COMPLETED-BAR SAFETY ENFORCEMENT RULE

======================================================================



Whenever patching history code, metric code, export packs, or warehouse logic:



\- do not allow index 0 to silently enter completed-bar packs

\- if CopyRates is called from shift 0, make completed-bar exclusion explicit downstream

\- if live/forming bar is intentionally included, it must be explicitly flagged as live/forming

\- compact OHLC packs for EA5 must be completed-bar-safe by default

\- metric trust must respect finality and continuity state



If completed-bar safety cannot be fully proven from the pasted file alone, state that risk outside the code block.







======================================================================

24.19 CROSS-FILE DEPENDENCY RULE

======================================================================



When I paste only one file:



\- repair what is local to that file

\- do not fabricate duplicate owner definitions to make the file appear self-contained

\- do not shadow missing shared types locally

\- do not redefine shared enums to “fix” missing includes

\- note any real cross-file dependency risk outside the code block unless I explicitly requested codeblock-only output



Examples of forbidden fixes:

\- redefining a core enum in a stage file

\- recreating ISSX\_JsonWriter locally

\- duplicating a shared DTO in UI

\- adding compatibility shims in stage code that belong in core/registry

\- using quoted include shortcuts to avoid proper direct include repair



RULE

\- owner discipline is more important than local fake self-containment.





ADDITIONAL RULE

\- If the local fix logically belongs in a shared owner, do not implement a consumer-local fake.

\- If the owner file is not pasted but the consumer depends on owner compatibility, note the owner-file requirement outside code unless the user requested codeblock-only output.

\- For shared-owner rename fallout, the proper repair location is the owner, not each consumer.



======================================================================

24.20 TEMPORARY WORKAROUND RULE

======================================================================



If the fastest compile fix would conflict with the blueprint:



\- prefer the blueprint-conformant repair

\- use a temporary workaround only if explicitly necessary to unblock parser or compile progress

\- if a temporary workaround is used, it must be clearly considered temporary in the narrative response unless I requested codeblock-only output

\- temporary workarounds must not silently become permanent architecture



Examples of poor temporary behavior:

\- local enum duplication

\- wrapper absorbing stage ownership

\- silent cast storms to hide warning defects

\- using public root JSON as recovery truth

\- allowing unknown states to default to healthy



======================================================================

24.21 PATCH STYLE RULES

======================================================================



All returned code must follow these style rules:



\- patch existing architecture instead of rewriting unrelated parts

\- preserve names and contracts where compatible

\- minimize churn unrelated to the real defect

\- keep wrapper thin

\- preserve five logical stages

\- preserve one-owner doctrine

\- preserve non-directional design

\- preserve deterministic serialization semantics

\- preserve MT5-safe syntax

\- prefer explicit honesty over convenience

\- prefer root-cause repair over surface patching

\- avoid ornamental refactors during compile-fix passes



RULE

\- Do not use broad cosmetic rewrites as a substitute for disciplined repair.





ADDITIONAL STYLE RULE

\- Do not perform aesthetic renames on shared contract symbols during stability work.

\- Contract readability improvements are allowed only when compatibility bridges are added or when the change is explicitly requested as a migration.



======================================================================

24.22 ONE-FILE PASS DOCTRINE

======================================================================



When only one file is supplied, the assistant must:



\- audit the file against the blueprint

\- patch what is locally patchable

\- add direct includes where required

\- remove local ownership violations where possible

\- keep cross-file contracts intact

\- avoid fabricating unseen file changes

\- return the full updated file in one code block



If the fix depends on another file:

\- preserve correct ownership

\- do not invent local duplicates

\- leave the file architecturally correct relative to the expected owner module





======================================================================

24.23 MULTI-PASS EXECUTION DOCTRINE

======================================================================



The normal sequence should be:



PASS A

\- blueprint alignment of pasted file

\- include identity normalization

\- owner-violation cleanup

\- compatibility-bridge review if shared contract drift is implicated



PASS B

\- MT5 compile error repair using actual MetaEditor error list

\- earliest owner-root cause first



PASS C

\- warning-zeroing and ownership cleanup

\- removal of temporary local symptom patches if any were unavoidable



PASS D

\- runtime-honesty and persistence hardening if required



PASS E

\- deeper architecture normalization if still needed

\- contract consolidation onto canonical owner surfaces



This order should be followed unless a severe parser-collapse defect must be repaired immediately in PASS A to make the file usable.



======================================================================

24.24 MT5-SAFE PATCHING RULES

======================================================================



For all returned MQL5 code:



\- no nested classes

\- no return-type-only overloading

\- no unsupported C++ idioms

\- no unsafe ephemeral return-by-reference usage

\- dynamic arrays only where justified

\- always check ArraySize before indexing

\- never assume enum numeric value equals safe array index unless core guarantees it

\- use explicit mapping helpers for stage indices where required

\- always check file open/write/close outcomes

\- do not claim persistence success without verification where the file already supports verification

\- use UTF-8 for deterministic text output and hashing-related string byte conversions where applicable

\- fix suspiciously narrow integer widths

\- do not let counts/indices live in risky narrow types





======================================================================

24.25 ERROR INTERPRETATION GUIDE FOR METAEDITOR OUTPUT

======================================================================



When I paste compile errors, interpret them with this discipline:



\- repeated “unexpected token” often means earlier brace/class damage

\- “function already defined” often means duplicate block or duplicate ownership

\- “undeclared identifier” often means missing direct include or wrong owner location

\- “cannot convert enum/integer/string” often means shared contract drift or unsafe casts

\- clustered errors after one class often mean parser continuity loss

\- line numbers later in the file may be secondary fallout, not primary cause

\- many missing-type errors across many modules often indicate one failed owner include or one include-path identity problem

\- many missing enum-member errors often indicate one shared-contract rename without compatibility bridge



RULE

\- Fix the earliest structural or owner-contract cause first.



======================================================================

24.26 MANDATORY INSTRUCTION FOR THE ASSISTANT DURING FUTURE ISSX PASSES

======================================================================



When I paste an ISSX source file in chat, do this in order:



1\. audit it against the master blueprint

2\. identify any ownership, include, stage API, persistence, scheduler, completed-bar, MT5-safety, or shared-contract drift violations

3\. patch it toward blueprint compliance first

4\. normalize canonical include identity if needed

5\. add or preserve owner-layer compatibility bridges if shared renames are implicated

6\. return the full updated file in one code block

7\. wait for my actual MetaEditor compile errors

8\. fix those compile errors against the patched file

9\. return the full corrected file again in one code block

10\. preserve one-owner rule, angle-bracket include doctrine, MT5-safe syntax, warning-zeroing, completed-bar discipline, accepted-truth discipline, thin-wrapper doctrine, and backward-compatibility bridge doctrine

11\. never give snippet-only output unless I explicitly ask for snippets

12\. never invent duplicate shared enums, DTOs, or JSON helpers locally

13\. never prioritize quick compile hacks over blueprint ownership discipline

14\. always prefer root-cause architectural repair over cosmetic compile suppression

15\. be explicit about cross-file dependency limits when not in codeblock-only mode

16\. preserve non-directional design intent at all times

17\. preserve truthful degraded/unknown semantics rather than fabricating healthy defaults

18\. self-audit any changed shared owner surface before final response

19\. never silently rename shared contract symbols for aesthetic reasons

20\. never remove compatibility aliases early unless blueprint explicitly authorizes removal



======================================================================

24.27 STRICT RESPONSE TEMPLATE FOR FUTURE ISSX PATCH WORK

======================================================================



Default response template for coding passes:



A. AUDIT

\- 3 to 10 concise bullets on what is wrong relative to blueprint and/or compile errors



B. UPDATED FILE

\- one full code block containing the complete updated source file



C. NOTES

\- remaining cross-file risks if any

\- whether compile issues appear local-only or cross-file

\- whether any temporary workaround was required



SPECIAL OVERRIDE

\- If I explicitly request “one complete codeblock only”, then return only the code block and no extra narrative.





======================================================================

24.28 FINAL ENFORCEMENT COMMANDMENTS FOR CHAT-BASED ISSX PATCHING

======================================================================



\- Always use the blueprint as the governing contract.

\- Always treat the pasted file as the active patch target for that pass.

\- Always return the full updated file in one code block unless I explicitly request otherwise.

\- Never return placeholder-filled pseudo-files.

\- Never let compile-order hacks replace ownership repair.

\- Never redefine shared semantic enums outside their owner.

\- Never clone shared JSON helper families outside core.

\- Never let quoted ISSX includes remain in patched output.

\- Never rely on transitive includes for direct dependencies.

\- Never let wrapper convenience override thin-wrapper doctrine.

\- Never let same-tick handoff bypass acceptance.

\- Never let index 0 silently enter completed-bar truth.

\- Never let unknown state masquerade as healthy, safe, strong, low-risk, or low-correlation.

\- Never treat public root projection as authoritative truth.

\- Never use quick compile suppression instead of root-cause repair.

\- Never ship load-bearing warning clusters as “good enough”.

\- Always prefer explicit honesty over silent convenience.

\- Always preserve stage ownership and failure boundaries.

\- Always preserve patch-friendly evolution rather than unnecessary rewrite.

\- Always move the codebase toward v1.7.2 governance, not away from it.

\- Never silently rename shared contract symbols.

\- Never remove owner compatibility bridges prematurely.

\- Never mix ISSX include identities.

\- Never patch a consumer locally when the correct repair belongs in owner compatibility.

\- Always self-audit changed shared surfaces before sending code.



======================================================================

24.29 NEW: SHARED CONTRACT DRIFT PREVENTION PROTOCOL

======================================================================



When modifying any shared owner file (`issx\_core.mqh`, `issx\_registry.mqh`, `issx\_runtime.mqh`, `issx\_persistence.mqh` where shared DTO surfaces exist), the assistant must internally perform this protocol:



STEP 1: identify changed owner symbols

\- added

\- removed

\- renamed

\- retyped

\- signature-changed

\- default-changed

\- label-changed



STEP 2: classify each change

\- additive safe

\- additive risky

\- backward-compatible via alias

\- breaking unless same-wave migration

\- breaking and forbidden in current pass



STEP 3: apply safety action

\- additive safe → allow

\- additive risky → note and audit consumers

\- backward-compatible via alias → add bridge in owner

\- breaking unless same-wave migration → either patch all consumers same wave or revert to bridge plan

\- breaking and forbidden → do not return patch



STEP 4: verify no silent stronger defaults

STEP 5: verify no duplicate owner introduced

STEP 6: verify canonical include identity

STEP 7: only then finalize response



======================================================================

24.30 NEW: COMPATIBILITY ALIAS LIFECYCLE

======================================================================



Alias states:

\- active\_primary

\- bridged\_legacy

\- removal\_announced

\- removed\_by\_blueprint



Rules:

\- active\_primary = canonical current symbol

\- bridged\_legacy = older symbol still supported through owner bridge

\- removal\_announced = may remain present but must be marked for future coordinated removal

\- removed\_by\_blueprint = may only be removed after explicit blueprint authorization and consumer migration



Mandatory alias metadata where practical in comments or blueprint notes:

\- old symbol

\- new symbol

\- semantic mapping quality:

&nbsp; - exact\_equivalent

&nbsp; - degraded\_equivalent

&nbsp; - approximate\_bridge

\- first bridge version

\- earliest removal version



======================================================================

24.31 NEW: ASSISTANT PRE-RESPONSE DRIFT CHECKLIST

======================================================================



Before any ISSX code response, the assistant must internally answer YES to all:



\- Did I normalize ISSX includes to canonical identity?

\- Did I avoid redefining owner-owned symbols locally?

\- If I changed shared symbols, did I provide compatibility bridge or full migration?

\- Did I avoid semantic strengthening of defaults?

\- Did I avoid ad-hoc literal duplication for shared keys where owner constants exist?

\- Did I avoid aesthetic renames of shared contracts?

\- Did I fix root causes before symptom sites?

\- Did I avoid placeholder or pseudo-code in load-bearing output?

\- Did I preserve stage ownership boundaries?

\- Did I keep the wrapper thin?

\- Did I keep completed-bar safety intact?

\- Did I avoid compile suppression hacks?



If any answer is NO, the patch is incomplete.



======================================================================

24.32 NEW: OWNER VS CONSUMER REPAIR DECISION RULE

======================================================================



When a compile failure appears, choose repair location by this order:



1\. owner file if symbol ownership is shared

2\. include site if canonical include missing

3\. consumer file only if issue is truly local and non-shared

4\. never consumer-local duplicate if owner fix is correct



Examples:

\- missing shared enum member → repair in core or core alias bridge

\- missing field key constant → repair in owner constant surface

\- missing direct include → repair at include site

\- parser spill local to one file → repair locally

\- shared helper drift → repair at owner helper surface



======================================================================

24.33 NEW: FORBIDDEN ASSISTANT FAILURE PATTERNS

======================================================================



The assistant must never do any of the following in future ISSX passes:



\- rename shared enums for readability without compatibility bridge

\- rename shared constant names casually

\- rename shared publishability/content values casually

\- duplicate owner-owned DTOs in local files

\- create local stub enums to satisfy compile errors

\- mix `<ISSX/...>` and `"..."` ISSX includes

\- rely on “maybe another file defines this”

\- patch late-file symptoms before checking root owner failure

\- leave known cross-file contract drift unresolved without bridge

\- replace explicit unknown state with empty string for convenience

\- cast away type mismatches caused by ownership drift

\- return “rest unchanged” for load-bearing repairs



======================================================================

24.34 NEW: SAFE SHARED-CONTRACT EVOLUTION POLICY

======================================================================



Preferred evolution order:

1\. additive extension

2\. additive extension + alias bridge

3\. additive extension + same-wave consumer adoption

4\. deprecate old symbol

5\. only later remove with explicit blueprint authorization



Discouraged:

\- direct rename

\- direct removal

\- semantic substitution without bridge

\- silent label drift

\- consumer-local remapping



======================================================================

24.35 NEW: BLUEPRINT OVERRIDE HIERARCHY

======================================================================



When rules appear to conflict, apply this order:



1\. safety / honesty / accepted-truth doctrine

2\. owner-surface integrity

3\. canonical include identity

4\. backward-compatibility bridge doctrine

5\. thin-wrapper doctrine

6\. completed-bar safety

7\. warning-zeroing

8\. patch-minimality

9\. aesthetic cleanliness



Clean-looking code may never outrank owner integrity.



======================================================================

24.36 NEW: CANONICAL SHARED-SYMBOL MIGRATION EXAMPLE RULE

======================================================================



If a shared owner symbol evolves, apply this pattern:



OLD:

\- issx\_publishability\_publishable



NEW:

\- issx\_publishability\_usable



REQUIRED:

\- owner bridge preserving old symbol

\- downstream same-wave migration optional but preferred

\- no consumer-local shadow macros

\- no silent removal



Same rule applies to:

\- enum members

\- field constants

\- helper names

\- DTO field names where bridging is feasible

\- exported label strings when external contract would break



======================================================================

24.37 NEW: RESPONSE DISCIPLINE FOR BLUEPRINT ITSELF

======================================================================



When updating this blueprint in future:

\- keep unchanged sections explicitly marked if user requests placeholders

\- fully spell out all new anti-drift rules

\- do not compress or summarize new enforcement sections

\- treat blueprint edits as governance edits, not cosmetic edits



======================================================================

24.38 NEW: REVIEW FAILURE CONDITION

======================================================================



A proposed ISSX patch must be considered failed under this blueprint if any of the following are true:

\- shared symbol renamed without bridge

\- mixed ISSX include identity remains

\- consumer-local duplicate owner symbol introduced

\- root-cause owner failure left unresolved while symptom fixes applied

\- compile success would rely on hidden include order

\- stronger default semantics introduced silently

\- cross-file contract drift knowingly left unbridged

\- response contains placeholders in actual source patch

\- assistant used quick compile hacks over ownership repair



======================================================================

24.39 NEW: PATCH COMPLETION CONDITION

======================================================================



A proposed ISSX patch is blueprint-complete only when:

\- owner integrity is preserved

\- include identity is canonical

\- compatibility drift is bridged or migrated

\- parser continuity is preserved

\- warnings are handled honestly

\- stage boundaries remain intact

\- no fake self-containment was introduced

\- no hidden assumptions remain about transitive includes

\- no stronger defaults were introduced silently

\- returned code is directly usable in MetaEditor



======================================================================

24.40 NEW: FINAL DIRECTIVE TO FUTURE ASSISTANT PASSES

======================================================================



When working on ISSX, behave as if shared-contract drift is the default danger.

Do not trust apparent local simplicity.

Do not trust compile-error volume.

Do not trust accidental include success.

Do not trust cosmetic renames.

Do not trust local duplication.

Stabilize owner surfaces first.

Canonicalize includes second.

Repair consumers third.

Only then chase remaining local defects.



END OF OPERATIONAL PATCH WORKFLOW + ARCHITECTURAL ENFORCEMENT ADDON

======================================================================

25. SYSTEM-COMPLETE EXPANSION PACK (v1.7.2+)

======================================================================

PURPOSE

This section closes practical execution gaps between architectural doctrine and the shipped ISSX module set.

It defines concrete ownership maps, stage I/O contracts, lifecycle checkpoints, and failure playbooks that must be present for a truly complete ISSX build.

If any item below is missing in implementation, ISSX is considered architecturally partial even when compile succeeds.


25.1 AUTHORITATIVE REPOSITORY-TO-BLUEPRINT MAP

======================================================================

REQUIRED HUMAN-FACING WRAPPER

- ISSX.mq5

REQUIRED SHARED CONTRACT SURFACES

- issx_contracts.mqh (types, enums, DTOs, key constants)
- issx_registry.mqh (shared key registration / symbol tables / alias bridges)

REQUIRED SHARED KERNEL SERVICES

- issx_runtime.mqh (timer cadence, stage scheduling, budget guards)
- issx_persistence.mqh (snapshots, manifests, atomic candidate/current handoff)
- issx_core.mqh (composition, top-level orchestration glue)

REQUIRED STAGE ENGINES

- issx_market_engine.mqh (EA1)
- issx_history_engine.mqh (EA2)
- issx_selection_engine.mqh (EA3)
- issx_correlation_engine.mqh (EA4)

REQUIRED UI/INSPECTION SURFACE

- issx_ui_test.mqh (inspection-only panel/test render)

COMPLETENESS RULE

- If a new stage or service exists, blueprint ownership section must be updated first.
- If file set changes without blueprint map change, release is invalid.


25.2 STAGE INPUT/OUTPUT CONTRACT MATRIX (MANDATORY)

======================================================================

EA1 MARKETSTATECORE

- Inputs:
  - Terminal symbol roster and broker metadata
  - Session/tradeability probes
  - Visibility/selection observability
- Authoritative outputs:
  - Universe membership truth per symbol
  - Broker/spec/session/tradeability snapshot
  - Identity normalization / family linkage / alias confidence
  - Freshness stamps and unresolved-state reasons

EA2 HISTORYSTATECORE

- Inputs:
  - EA1 accepted universe and symbol identity mapping
  - MT5 bar series pulls (multi-timeframe)
- Authoritative outputs:
  - Rolling OHLC warehouse with continuity truth
  - Per-timeframe depth, gaps, stale windows, hydration quality
  - History integrity grades and reload advice

EA3 SELECTIONCORE

- Inputs:
  - EA1 tradability + friction + observability facts
  - EA2 continuity + freshness + usable-depth facts
- Authoritative outputs:
  - Bucketed top candidates (target top 5/bucket)
  - Rankability lane and exclusion reason taxonomy
  - Diversity/context metadata for downstream EA5 handoff

EA4 INTELLIGENCECORE

- Inputs:
  - EA3 accepted winners/frontier
  - EA2 synchronized history windows
- Authoritative outputs:
  - Sparse overlap/correlation structure on bounded frontier
  - Regime/context descriptors that remain non-directional
  - Confidence/explainability metadata for each derived metric

EA5 CONSOLIDATIONCORE

- Inputs:
  - EA1..EA4 accepted current only
- Authoritative outputs:
  - Exported winner-focused JSON/snapshot package
  - Strict health envelope (degradation flags, staleness, fallback usage)
  - Trader-handoff context without signal/entry semantics

MATRIX RULE

- No stage may read a downstream stage.
- No stage may consume another stage's candidate state as truth.
- Every consumed field must cite owner stage in contracts.


25.3 MINIMUM FIELD GROUPS REQUIRED FOR EA5 COMPLETENESS

======================================================================

Each exported winner record must contain, at minimum:

- Identity
  - canonical symbol
  - broker symbol
  - normalized alias/family tags
- Market usability
  - spread/friction posture
  - session state + near-session transitions
  - execution observability notes
- Data integrity
  - per-timeframe freshness and continuity grade
  - hydration depth + recent gap indicators
- Selection rationale
  - bucket id
  - rank score decomposition (components, weights, clamps)
  - lane/exclusion code if degraded
- Intelligence context
  - bounded overlap measures (where available)
  - regime/context tags and confidence
  - computation horizon and sample sufficiency flags
- Health envelope
  - per-stage generation ids
  - fallback flags + reason codes
  - publish age in seconds

FIELD INTEGRITY RULE

- Missing values must be encoded as unknown/na, never silently coerced to healthy defaults.


25.4 TIMER-DRIVEN LIFECYCLE CHECKPOINTS

======================================================================

Every timer cycle must explicitly pass these checkpoints:

1) TICK START SNAPSHOT
- capture now, cycle id, prior publish id, and carry-over work queues.

2) BUDGET ADMISSION
- assign per-stage budget slices before work begins.
- if timer lag exists, adjust quotas but do not skip health accounting.

3) STAGE WORK EXECUTION
- stage executes resumable units only.
- each unit records progress marker and partial diagnostics.

4) ACCEPTANCE GATE
- structural validity, semantic validity, continuity validity.
- candidate promoted to current only on full gate pass.

5) PERSISTENCE FLUSH
- write candidate artifacts first, then manifest, then atomic current handoff.
- record write status and checksum/hash evidence.

6) EA5 CONSOLIDATION + PUBLISH
- consume accepted current from EA1..EA4.
- attach freshness and fallback envelope.

7) POST-CYCLE HEALTH LOG
- emit stage timings, skipped work counts, and debt backlog.

CHECKPOINT RULE

- If any checkpoint is bypassed, cycle must be marked degraded and published health must say why.


25.5 FAILURE-CLASS PLAYBOOK (REQUIRED)

======================================================================

F1 CONTRACT DRIFT FAILURE

- Signal: compile/type mismatch on shared DTO/enums/keys.
- Mandatory response order:
  1. repair owner declaration
  2. add compatibility alias/shim if rename happened
  3. update consumers
  4. update manifest/version notes

F2 INCLUDE IDENTITY FAILURE

- Signal: duplicate path forms or accidental compile-by-order behavior.
- Mandatory response:
  - canonicalize includes to blueprint-approved path identity
  - remove duplicate local symbol shadows

F3 HISTORY CONTINUITY FAILURE

- Signal: depth present but gaps/staleness break usable continuity.
- Mandatory response:
  - degrade rankability lane honestly
  - trigger hydration catch-up windows
  - avoid false healthy promotion

F4 PERSISTENCE INTEGRITY FAILURE

- Signal: write interruption, orphan candidate, manifest mismatch.
- Mandatory response:
  - quarantine broken candidate
  - recover from last valid current
  - emit persistence error class in health envelope

F5 TIMER OVERRUN FAILURE

- Signal: repeated cycle budget exhaustion.
- Mandatory response:
  - cap expensive operations
  - prioritize continuity-critical units
  - carry debt forward with explicit counters

PLAYBOOK RULE

- Every failure class must map to machine-readable reason codes in the exported health envelope.


25.6 OBSERVABILITY PACK REQUIREMENTS

======================================================================

The following debug channels are mandatory:

- Stage cycle timing table (avg, p95, max)
- Queue debt table (units pending by stage)
- Acceptance table (pass/fail counts by taxonomy)
- Fallback table (class, frequency, duration)
- Persistence table (last successful write, last recover event)
- Publish table (age, generation coherence, envelope status)

OBSERVABILITY RULE

- If diagnostics are unavailable, exported health must include diagnostics_unavailable=true.


25.7 VERSIONING, MIGRATION, AND COMPATIBILITY COVENANT

======================================================================

- Blueprint version increments are mandatory when:
  - owner field names change
  - enum members change
  - reason-code taxonomy changes
  - manifest schema changes

- Backward bridge window must be defined for every external rename.

- Compatibility aliases must have:
  - introduction version
  - planned sunset version
  - migration completion criterion

- No alias may be removed unless consumer scan proves zero remaining dependency.


25.8 DEFINITION OF DONE FOR ANY FUTURE ISSX PATCH

======================================================================

A patch is complete only if all are true:

- Compile cleanly with warnings handled or explicitly justified.
- Stage boundaries unchanged unless blueprint explicitly revised.
- Owner/consumer contract map updated for every shared change.
- Persistence manifest version and migration note updated when required.
- Health envelope contains truthful fallback/degradation state.
- EA5 export remains non-directional and trader-handoff ready.
- Blueprint text updated where governance changed.

DONE RULE

- “Compiles” alone is never accepted as completion proof.


25.9 BLUEPRINT SELF-CONSISTENCY AUDIT BLOCK

======================================================================

Before release of any blueprint revision, perform this audit:

- Verify section references resolve to existing sections.
- Verify every mandatory rule has at least one owner module.
- Verify every owner module appears in repository map.
- Verify no contradictory instructions about fallback vs compatibility.
- Verify no instruction requires impossible MT5 guarantees.

If audit fails, blueprint is draft-only and cannot govern production patching.


END OF MASTER BLUEPRINT v1.7.2

