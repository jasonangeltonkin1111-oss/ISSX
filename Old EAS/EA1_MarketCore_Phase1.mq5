//+------------------------------------------------------------------+
//|                                        EA1_MarketCore_Phase1.mq5 |
//|                      Phase 1 foundation for EA1_MarketCore_FINAL |
//|                            Timer-only, no-chart observability EA |
//+------------------------------------------------------------------+
#property strict
#property version   "1.100"
#property description "EA1 stable timer-only market observability core"

//====================================================================
// 1. Includes
//====================================================================
// No includes required for Phase 1.

//====================================================================
// 2. Constants
//====================================================================
#define EA_NAME                 "EA1"
#define EA_ENGINE_VERSION       "1.0"
#define EA_SCHEMA_VERSION       "2.4"
#define EA_BUILD_CHANNEL        "stable"
#define EA_STAGE_NAME           "symbols_universe"
#define EA_DEBUG_NAME           "debug"

#define MAX_SYMBOLS_HARD        5000
#define MAX_SESSIONS_PER_DAY    8
#define DAYS_PER_WEEK           7
#define HUD_WORST_LIMIT         8
#define INVALID_TIME_MSC        (-1)
#define INVALID_I32             (-2147483647)
#define INVALID_DBL             (EMPTY_VALUE)

#define TICK_RING_CAPACITY      64
#define EVENT_RING_CAPACITY     8

#define EA1_PUBLISH_OFFSET_SEC  1
#define EA1_PUBLISH_WINDOW_SEC  15

#define IO_OP_NONE              0
#define IO_OP_WRITE_TMP         1
#define IO_OP_MOVE_COMMIT       2
#define IO_OP_COPY_COMMIT       3
#define IO_OP_BACKUP_COPY       4
#define IO_OP_DELETE_TMP        5

#define RC3_OK                  0
#define RC3_WARMING_UP          1
#define RC3_MARKET_CLOSED       2
#define RC3_TRADE_DISABLED      3
#define RC3_QUOTE_UNAVAILABLE   4
#define RC3_EXPIRED_OR_DELISTED 5
#define RC3_HYDRATION_TIMEOUT   6
#define RC3_COOLED_DOWN         7

//====================================================================
// 3. Inputs
//====================================================================
input bool   InpUseMarketWatchOnly          = true;
input int    InpUniverseMaxSymbols          = 0;
input int    InpTimerIntervalSec            = 5;

input int    InpSubscribeBudgetPerCycle     = 80;
input int    InpSpecBudgetPerCycle          = 40;
input int    InpSessionBudgetPerCycle       = 40;
input int    InpSnapshotBudgetPerCycle      = 80;
input int    InpCopyTicksBudgetPerCycle     = 20;
input int    InpCopyTicksFetchPerSymbol     = 32;
input int    InpCopyTicksCooldownSec        = 20;
input int    InpCostBudgetPerCycle          = 20;
input int    InpConsistencyBudgetPerCycle   = 128;

input int    InpActiveSnapshotFreshSec      = 120;
input int    InpSnapshotClosedRecheckSec    = 30;
input int    InpCopyTicksActiveRecheckSec   = 3;
input int    InpCopyTicksClosedRecheckSec   = 180;
input int    InpCopyTicksDormantRecheckSec  = 21600;
input int    InpCopyTicksUnknownRecheckSec  = 900;

input int    InpPerfWarnMs                  = 500;
input int    InpWorstRows                   = 5;
input bool   InpShowHUD                     = true;
input int    InpHudRefreshSec               = 10;
input int    InpDebugWriteSec               = 10;
input int    InpDebugSymbolRows             = 20;

input int    InpStartupGraceSec             = 90;
input int    InpMaxHydrationAttempts        = 3;
input int    InpDeadQuoteAfterSec           = 120;
input int    InpSessionRefreshSec           = 3600;
input int    InpSpecRefreshSec              = 3600;
input int    InpCoverageRefreshSec          = 5;
input int    InpCostRefreshSec              = 60;
input int    InpMarginProbeRefreshSec       = 300;

input bool   InpPublishStageEnabled         = true;
input bool   InpPublishDebugJsonEnabled     = true;
input bool   InpEnableBackups               = true;
input bool   InpEnableTempCleanup           = true;
input bool   InpEnablePublishLock           = true;
input int    InpTempCleanupAgeSec           = 600;
input int    InpTempCleanupEverySec         = 3600;

input bool   InpPersistenceEnabled          = true;
input int    InpPersistenceLoadBudget       = 300;
input int    InpPersistenceSaveBudget       = 10;
input int    InpPersistenceFreshMaxAgeSec   = 7200;

// old save cadence kept, but now acts mainly as checkpoint cadence
input int    InpPersistenceSaveEverySec     = 300;

// stronger throttles
input int    InpPersistenceMinSaveGapSec    = 300;
input int    InpPersistenceHistoryDeltaMs   = 5000;
input int    InpPersistenceMaxWritesPerMin  = 60;

input bool   InpPersistenceBackupEnabled    = true;
input bool   InpEnableQuirkLayer            = true;
input string InpFirmSuffix = "";
//====================================================================
// 4. Enums
//====================================================================
enum AssetClass
  {
   AC_UNKNOWN = 0,
   AC_FX,
   AC_METAL,
   AC_INDEX,
   AC_STOCK,
   AC_CRYPTO,
   AC_COMMODITY,
   AC_CUSTOM
  };

enum SymbolState
  {
   SS_NEW = 0,
   SS_SELECTED,
   SS_SPEC_PARTIAL,
   SS_SPEC_MIN_READY,
   SS_SESSION_PARTIAL,
   SS_SESSION_READY,
   SS_SNAPSHOT_PARTIAL,
   SS_SNAPSHOT_VALID,
   SS_HISTORY_VALID
  };

enum ReasonCode
  {
   RC_OK = 0,
   RC_INIT,
   RC_SELECT_FAILED,
   RC_SPEC_PARTIAL,
   RC_SESSION_FALLBACK,
   RC_NO_TICK,
   RC_INVALID_TICK,
   RC_COPYTICKS_WARMUP,
   RC_COPYTICKS_FAILING,
   RC_MARKET_CLOSED,
   RC_DORMANT_SYMBOL,
   RC_UNKNOWN
  };

enum SpecLevel
  {
   SL_NONE = 0,
   SL_PARTIAL,
   SL_MIN_READY
  };

enum TradabilityClass
  {
   TC_UNKNOWN = 0,
   TC_FULL_ACCESS,
   TC_CLOSE_ONLY,
   TC_DISABLED
  };

enum MarketOpenState
  {
   MOS_UNKNOWN = 0,
   MOS_OPEN_NOW,
   MOS_CLOSED_NOW
  };

enum SymbolActivityClass
  {
   SAC_UNKNOWN = 0,
   SAC_ACTIVE,
   SAC_MARKET_CLOSED,
   SAC_DORMANT
  };

enum TickPathMode
  {
   TPM_NONE = 0,
   TPM_SNAPSHOT_ONLY,
   TPM_COPYTICKS_ONLY,
   TPM_BOTH
  };

enum CopyTicksPhase
  {
   CT_NOT_STARTED = 0,
   CT_FIRST_SYNC,
   CT_WARM,
   CT_STEADY,
   CT_DEGRADED,
   CT_FAILING,
   CT_COOLDOWN
  };

enum Phase2EventType
  {
   EVT_NONE = 0,
   EVT_COPYTICKS_START,
   EVT_COPYTICKS_FIRST_SYNC,
   EVT_COPYTICKS_APPEND,
   EVT_COPYTICKS_SAME_MS_REJECT,
   EVT_COPYTICKS_FAIL,
   EVT_COPYTICKS_COOLDOWN_ENTER,
   EVT_COPYTICKS_RECOVER,
   EVT_HISTORY_READY,
   EVT_HISTORY_DEGRADED
  };

enum ProvenanceValue
  {
   PV_NONE = 0,
   PV_OBSERVED,
   PV_PROBED,
   PV_DERIVED,
   PV_HEURISTIC,
   PV_MANUAL,
   PV_FALLBACK
  };

enum CostState
  {
   COST_NONE = 0,
   COST_PARTIAL,
   COST_READY
  };

enum SummaryState
  {
   SUM_UNKNOWN = 0,
   SUM_GOOD,
   SUM_PARTIAL,
   SUM_DEGRADED,
   SUM_WARMUP,
   SUM_UNUSABLE
  };

enum DataReasonCode
  {
   DRC_NONE = 0,
   DRC_OK,
   DRC_SELECT_FAILED,
   DRC_SPEC_PARTIAL,
   DRC_NO_TICK,
   DRC_COPYTICKS_WARMUP,
   DRC_COPYTICKS_FAILING,
   DRC_MARKET_CLOSED,
   DRC_DORMANT,
   DRC_COST_PARTIAL,
   DRC_UNKNOWN
  };

enum TradabilityReasonCode
  {
   TRC_NONE = 0,
   TRC_OK,
   TRC_UNKNOWN,
   TRC_DISABLED,
   TRC_CLOSE_ONLY,
   TRC_NOT_FULL_ACCESS
  };
  
  enum PublishReasonCode
  {
   PRC_NONE = 0,
   PRC_OK,
   PRC_NOT_WRITTEN_YET,
   PRC_WRITE_FAILED,
   PRC_UNKNOWN
  };

enum SpecStateEx
  {
   SPX_NONE = 0,
   SPX_PARTIAL,
   SPX_READY
  };

enum SessionStateEx
  {
   SSX_NONE = 0,
   SSX_FALLBACK,
   SSX_READY
  };

enum TradeStateEx
  {
   TSX_UNKNOWN = 0,
   TSX_DISABLED,
   TSX_CLOSE_ONLY,
   TSX_FULL
  };

enum PublishStateEx
  {
   PSX_NONE = 0,
   PSX_OK,
   PSX_FAILING
  };
  
  enum SectorId
  {
   SID_FX_MAJOR = 0,
   SID_FX_MINOR = 1,
   SID_FX_EXOTIC = 2,
   SID_METALS = 3,
   SID_INDICES = 4,
   SID_ENERGY = 5,
   SID_COMMODITIES = 6,
   SID_CRYPTO = 7,
   SID_STOCKS = 8,
   SID_RATES = 9,
   SID_OTHER = 10
  };

enum HydrationStateEx
  {
   HDE_NEW = 0,
   HDE_SELECTED,
   HDE_SPEC_READY,
   HDE_SESSION_CHECKED,
   HDE_MARKET_OPEN,
   HDE_MARKET_CLOSED,
   HDE_EXPIRED_OR_DISABLED,
   HDE_TICK_PENDING,
   HDE_TICK_READY,
   HDE_DEAD_QUOTE,
   HDE_COOLED_DOWN
  };
  
  enum PersistenceStateEx
  {
   PTX_NONE = 0,
   PTX_NOT_FOUND,
   PTX_LOADED_FRESH,
   PTX_STALE_DISCARDED,
   PTX_CORRUPT_DISCARDED,
   PTX_INCOMPATIBLE_DISCARDED,
   PTX_CLEAN_START,
   PTX_SAVED_OK,
   PTX_SAVE_FAILED
  };

enum ContinuityOrigin
  {
   CO_NONE = 0,
   CO_CLEAN,
   CO_PERSISTENCE
  };

enum QuirkFlags
  {
   QF_NONE                   = 0,
   QF_CLASSIFY_ALIAS         = 1,
   QF_FORCE_SESSION_FALLBACK = 2,
   QF_IGNORE_ZERO_TICKVALUE  = 4,
   QF_MANUAL_COMMISSION      = 8,
   QF_DISABLE_MARGIN_PROBE   = 16
  };
  
//====================================================================
// 5. Structs
//====================================================================
struct SessionWindow
  {
   bool active;
   int  start_hhmm;
   int  end_hhmm;
  };

struct SymbolSpecObserved
  {
   int    digits;
   double point;
   double contract_size;
   double tick_size;
   double tick_value;
   double volume_min;
   double volume_max;
   double volume_step;
   int    trade_mode;
   int    calc_mode;
   string margin_currency;
   string profit_currency;
   double swap_long;
   double swap_short;
  };

struct SymbolSpecDerived
  {
   AssetClass        asset_class;
   TradabilityClass  tradability_class;
   SpecLevel         spec_level;
   bool              spec_min_ready;
   bool              spec_partial;
   string            canonical_symbol;
   string            class_key;
   string            canonical_group;
   string            classification_source;
   int               classification_confidence;
  };

struct SymbolSessionState
  {
   SessionWindow   quote_sessions[DAYS_PER_WEEK * MAX_SESSIONS_PER_DAY];
   SessionWindow   trade_sessions[DAYS_PER_WEEK * MAX_SESSIONS_PER_DAY];
   int             quote_session_count[DAYS_PER_WEEK];
   int             trade_session_count[DAYS_PER_WEEK];
   bool            quote_session_open_now;
   bool            trade_session_open_now;
   bool            fallback_used;
   bool            sessions_loaded;
   bool            sessions_truncated;
   ProvenanceValue session_source;
   int             session_confidence;
  };

struct TickRingItem
  {
   long            time_msc;
   double          bid;
   double          ask;
   double          last;
   double          volume_real;
   unsigned int    flags;
  };

struct Phase2Event
  {
   datetime        server_time;
   Phase2EventType type;
   long            tick_time_msc;
  };

struct SymbolTickState
  {
   // Phase 1 snapshot fields
   bool         tick_valid;
   long         last_tick_time;
   long         last_tick_time_msc;
   double       bid;
   double       ask;
   double       mid;
   double       spread_points;

   // Phase 2 path split
   bool         snapshot_path_ok;

   // retained history state must be separated from live-now truth
   bool         history_available;
   bool         history_fresh;
   bool         history_path_ok;

   TickPathMode tick_path_mode;
   CopyTicksPhase copyticks_phase;

   // Phase 2 market/activity truth
   MarketOpenState     market_open_state;
   SymbolActivityClass activity_class;
   bool                copyticks_eligible_now;

   // Phase 2 history tracking
   long         last_snapshot_seen_msc;
   long         last_copyticks_seen_msc;
   long         last_copied_msc;
   long         last_meaningful_snapshot_msc;
   long         last_meaningful_history_msc;
   int          history_last_batch_count;
   int          history_append_count;
   int          history_same_ms_reject_count;
   int          copyticks_fail_count;
   datetime     copyticks_cooldown_until;

   // Watch scheduling
   datetime     next_snapshot_due_server;
   datetime     next_copyticks_due_server;
   datetime     active_watch_due_server;
   datetime     dead_watch_due_server;
   datetime     reopen_watch_due_server;

   // Ring buffer
   TickRingItem ring[TICK_RING_CAPACITY];
   int          ring_head;
   int          ring_count;
   long         ring_overwrite_count;

   // Small event ring
   Phase2Event  events[EVENT_RING_CAPACITY];
   int          event_head;
   int          event_count;
  };

struct SymbolHealthState
  {
   SymbolState state;
   ReasonCode  reason;
   bool        usable_for_observation;
   bool        spec_ready;
   bool        session_ready;
   bool        tick_ready;
  };

struct SymbolCapabilityState
  {
   bool can_select;
   bool can_snapshot;
   bool can_copyticks;
   bool can_sessions;
   bool can_probe_profit;
   bool can_probe_margin;
   bool can_trade_full;
   bool can_trade_close_only;
   bool has_tick_value_observed;
   bool has_commission_observed;
  };

struct SymbolCostState
  {
   CostState       cost_state;

   bool            spread_complete;
   bool            commission_complete;
   bool            carry_complete;
   bool            margin_complete;
   bool            friction_complete;

   bool            usable_for_costs;

   double          tick_value_effective;
   ProvenanceValue tick_value_provenance;

   double          value_per_tick_money;
   ProvenanceValue value_per_tick_provenance;

   double          value_per_point_money;
   ProvenanceValue value_per_point_provenance;

   double          spread_value_money_1lot;
   ProvenanceValue spread_value_provenance;

   double          commission_value_effective;
   ProvenanceValue commission_provenance;

   double          carry_long_1lot;
   ProvenanceValue carry_long_provenance;

   double          carry_short_1lot;
   ProvenanceValue carry_short_provenance;

   double          margin_1lot_money_buy;
   ProvenanceValue margin_buy_provenance;

   double          margin_1lot_money_sell;
   ProvenanceValue margin_sell_provenance;

   double          notional_exposure_estimate_1lot;
   ProvenanceValue exposure_provenance;

   int             cost_confidence;
  };

struct SymbolHealthPhase3State
  {
   SummaryState          summary_state;
   DataReasonCode        data_reason_code;
   TradabilityReasonCode tradability_reason_code;
   PublishReasonCode     publish_reason_code;

   SpecStateEx           spec_state_ex;
   SessionStateEx        session_state_ex;
   TradeStateEx          trade_state_ex;
   PublishStateEx        publish_state_ex;

   bool                  tick_silence_expected;
   bool                  tick_silence_unexpected;

   bool                  usable_for_sessions;
   bool                  usable_for_costs;
   bool                  usable_for_trading_future;

   int                   health_quote;
   int                   health_spec;
   int                   health_session;
   int                   health_cost;
   int                   health_publish;
   int                   health_continuity;
   int                   health_overall;
   int                   operational_health_score;

   bool                  market_status_open_now;
   bool                  expected_market_open_now;
  };

struct SymbolHydration3AState
  {
   HydrationStateEx state_ex;
   int              reason_code_3a;
   int              hydration_attempts;
   datetime         cooled_down_until;
   datetime         first_open_without_tick_time;
   bool             quote_session_open;
   bool             trade_session_open;
   bool             market_open_now;
   bool             expired_or_disabled;
   bool             dead_quote;
   bool             spec_sanity_ok;
   int              spec_quality;
   int              sector_id;
  };

struct SymbolSpecChangeState
  {
   string   spec_hash;
   int      spec_change_count;
   datetime last_spec_change_time_server;
   string   last_material_change_reason;
  };

struct SymbolContinuityState
  {
   PersistenceStateEx persistence_state;

   bool      persistence_loaded;
   bool      persistence_fresh;
   bool      persistence_stale;
   bool      persistence_corrupt;
   bool      persistence_incompatible;

   bool      resumed_from_persistence;
   bool      restarted_clean;

   int       persistence_age_sec;
   ContinuityOrigin continuity_origin;
   datetime  continuity_last_good_server_time;

   datetime  last_persistence_save_time;
   bool      persistence_dirty;
   bool      loaded_once;

   // material-save throttling / no-op skip
   long      last_saved_history_msc;
   int       last_saved_copyticks_phase;
   string    last_saved_payload_hash;
  };

struct SymbolRecord
  {
   string                 raw_symbol;
   string                 normalized_symbol;
   bool                   selected_ok;
   int                    select_fail_count;

   bool                   base_dirty;
   bool                   spec_dirty;
   bool                   session_dirty;
   bool                   tick_dirty;
   bool                   cost_dirty;

   datetime               last_spec_refresh_time;
datetime               last_session_refresh_time;
datetime               last_cost_refresh_time;
datetime               last_margin_probe_time;

   SymbolSpecObserved     spec_observed;
   SymbolSpecDerived      spec_derived;
   SymbolSessionState     session_state;
   SymbolTickState        tick_state;
   SymbolHealthState      health;
   SymbolCapabilityState   capability;
   SymbolCostState         cost;
   SymbolHealthPhase3State health3;
   SymbolHydration3AState  hydration3a;
   SymbolSpecChangeState   spec_change;
   SymbolContinuityState   continuity;
  };

struct UniverseState
  {
   string       symbols[];
   SymbolRecord records[];
   int          size;
  };

struct ScheduleState
  {
   long      timer_tick_count;
   long      timer_overrun_count;
   datetime  last_timer_server_time;
   datetime  now_server_time;
   datetime  now_utc_time;
   int       last_cycle_ms;
   bool      timer_busy;
   int       cursor_subscribe;
   int       cursor_spec;
   int       cursor_session;
   int       cursor_snapshot;
   int       cursor_copyticks;
   int       cursor_cost;
   int       cursor_consistency;
   datetime  last_debug_write_time;
   datetime  last_main_dump_write_time;
  };

struct PublishMetaState
  {
   long      minute_id;
   int       write_seq;
   long      last_published_minute_id;
   bool      attempted;
   bool      ok;
   string    last_error;
   bool      publish_skipped_lock;
  };

struct IoLastState
  {
   string last_file;
   int    last_op;
   int    open_err;
   int    read_err;
   int    write_err;
   int    move_err;
   int    copy_err;
   int    delete_err;
   int    bytes;
   int    size;
   bool   guard_ok;
  };

struct IoCounterState
  {
   long io_ok_count;
   long io_fail_count;
  };

struct PerfState
  {
   int dur_step_total_ms;
   int dur_hydrate_ms;
   int dur_build_stage_ms;
   int dur_write_tmp_ms;
   int dur_commit_ms;
   int dur_backup_ms;
   int dur_read_ms;
   int dur_validate_ms;
   int dur_parse_ms;
   bool perf_warn;
  };


//====================================================================
// 6. Global State
//====================================================================
UniverseState g_universe;
ScheduleState g_schedule;

int g_selected_count            = 0;
int g_spec_ready_count          = 0;
int g_session_ready_count       = 0;
int g_tick_ready_count          = 0;
int g_history_ready_count       = 0;
int g_both_path_ready_count     = 0;
int g_active_symbol_count       = 0;
int g_closed_symbol_count       = 0;
int g_dormant_symbol_count      = 0;
int g_cost_ready_count          = 0;
int g_cost_usable_count         = 0;
int g_coverage_cursor           = 0;

datetime g_last_hud_render_time = 0;
datetime g_init_server_time     = 0;
datetime g_last_temp_cleanup    = 0;
datetime g_last_coverage_recount= 0;

PublishMetaState g_publish_stage;
PublishMetaState g_publish_debug;
IoLastState      g_io_last;
bool g_debug_commit_pending = false;
IoCounterState   g_io_counters;
PerfState        g_perf;
long g_dbg_recompute_base_calls      = 0;
long g_dbg_recompute_base_skip_calls = 0;
long g_dbg_spec_reads                = 0;
long g_dbg_snapshot_reads            = 0;
long g_dbg_copyticks_calls           = 0;
long g_dbg_margin_probe_calls        = 0;
long g_dbg_session_load_calls        = 0;
long g_dbg_activity_refresh_calls    = 0;
int g_sector_counts[11];

int g_market_open_count         = 0;
int g_market_closed_count       = 0;
int g_expired_or_disabled_count = 0;
int g_dead_quote_count          = 0;
int g_cooled_down_count         = 0;
int g_missing_tick_count        = 0;
int g_missing_spec_count        = 0;
int g_spec_sanity_ok_count      = 0;

string g_firm_name              = "";
string g_firm_id                = "";
string g_base_dir               = "";
string g_outputs_dir            = "";
string g_tmp_dir_ea1            = "";
string g_locks_dir              = "";
string g_persistence_dir_ea1    = "";

string g_stage_file             = "";
string g_stage_prev_file        = "";
string g_stage_backup_file      = "";

string g_debug_json_file        = "";
string g_debug_json_prev_file   = "";
string g_debug_json_backup_file = "";

int  g_schedule_cursor_persist_load   = 0;
int  g_schedule_cursor_persist_save   = 0;

long g_persist_load_ok_count          = 0;
long g_persist_load_fail_count        = 0;
long g_persist_save_ok_count          = 0;
long g_persist_save_fail_count        = 0;
long g_persist_stale_discard_count    = 0;
long g_persist_corrupt_discard_count  = 0;
long g_persist_incompat_discard_count = 0;

int  g_persist_writes_this_minute     = 0;
long g_persist_writes_minute_id       = -1;

#define EA1_PERSIST_SCHEMA_VERSION    1
#define EA1_ENGINE_VERSION_STR        EA_ENGINE_VERSION
#define EA1_BLUEPRINT_VERSION_STR     EA_SCHEMA_VERSION
//====================================================================
// Forward Declarations
//====================================================================
void   ResetGlobalState();
void   InitFirmFiles();
void   BuildUniverse();
void   InitSymbolRecord(SymbolRecord &rec, const string symbol);

void   RunSubscriptionBudget();
void   RunSpecBudget();
void   RunSessionBudget();
void   RunSnapshotBudget();
void   RunCostBudget();
void   RunCopyTicksBudget();

void   ReadSpecObserved(SymbolRecord &rec);
void   DeriveSpecState(SymbolRecord &rec);
void   UpdateTradability(SymbolRecord &rec);
void   UpdateAssetClass(SymbolRecord &rec);
void   UpdateHealthFromSpec(SymbolRecord &rec);

void   LoadSessions(SymbolRecord &rec);
void   UpdateSessionOpenState(SymbolRecord &rec);
void   UpdateHealthFromSessions(SymbolRecord &rec);

void   ReadSnapshotTick(SymbolRecord &rec);
void   UpdateHealthFromSnapshot(SymbolRecord &rec);
void   CopyTicksForSymbol(SymbolRecord &rec);

void   RenderHUD();
string BuildWorstSymbolsText();

void   UpdateScheduleClock();
void   RecountCoverage();
void   RecountCoverage3A();

void   ResetSpecObserved(SymbolSpecObserved &spec);
void   ResetSpecDerived(SymbolSpecDerived &spec);
void   ResetSessionState(SymbolSessionState &sess);
void   ResetTickState(SymbolTickState &tick);
void   ResetCapabilityState(SymbolCapabilityState &cap);
void   ResetCostState(SymbolCostState &cost);
void   ResetHealthPhase3State(SymbolHealthPhase3State &h3);
void   ResetHydration3AState(SymbolHydration3AState &st);

void   ResetSpecChangeState(SymbolSpecChangeState &st);
void   ResetContinuityState(SymbolContinuityState &st);

void   InitPhase4Persistence();
void   RunPersistenceLoadBudget();
void   RunPersistenceSaveBudget();

string BuildSpecHash(const SymbolRecord &rec);
void   RefreshSpecHash(SymbolRecord &rec);

string BuildPersistenceFilePath(const SymbolRecord &rec);
string BuildPersistenceBackupPath(const SymbolRecord &rec);

bool   SaveSymbolPersistence(SymbolRecord &rec);
bool   LoadSymbolPersistence(SymbolRecord &rec);

bool   WriteBinString(const int h, const string s);
bool   ReadBinString(const int h, string &s);

string PersistenceStateExToString(const PersistenceStateEx v);
string ContinuityOriginToString(const ContinuityOrigin v);

string BuildSymbolContinuityJson(const SymbolRecord &rec);
int    GetSymbolQuirkFlags(const SymbolRecord &rec);

void   RecomputeBaseState(SymbolRecord &rec);
void   MarkBaseDirty(SymbolRecord &rec);
void   RunConsistencyBudget();
void   RefreshActivityOnly(SymbolRecord &rec);
void   UpdateSymbolActivityState(SymbolRecord &rec);
void   BuildWorstSymbolLists(int &worst_idx[], int &worst_score[]);

void   ComputeSymbolCapabilityState(SymbolRecord &rec);
void   ComputeSymbolCostState(SymbolRecord &rec);
void   ComputeSymbolHealthPhase3(SymbolRecord &rec);
bool   ProbeMarginOneLot(SymbolRecord &rec, double &buy_margin, double &sell_margin);

void   AddSymbolEvent(SymbolRecord &rec, const Phase2EventType type, const long tick_time_msc);
bool   AppendRingTick(SymbolRecord &rec, const MqlTick &tick);
int    GetLastRingIndex(const SymbolTickState &tick_state);
bool   CanBeHistoryReady(const CopyTicksPhase phase);
bool   IsCopyTicksDueNow(const SymbolRecord &rec);
bool   IsRecentServerTickTime(const long tick_time_sec, const int fresh_sec);
bool   IsRecentServerTickTimeMsc(const long tick_time_msc, const int fresh_sec);
void   SortTicksAscending(MqlTick &ticks[]);
bool   IsKnownNumber(const double v);
string SanitizeFirmName(string s);
string NormalizeSymbol(string s);
string BuildCanonicalSymbol(string s);
string LatestEventToString(const SymbolRecord &rec);
string BuildCoverageSummaryJson();
string BuildCoverageOnlyJson();

TickPathMode DeriveTickPathMode(const bool snapshot_ok, const bool history_ok);
bool   DidMaterialContinuityChange(SymbolRecord &rec);
string BuildPersistencePayloadHash(const SymbolRecord &rec);

void   RunFinalConsistencyPass();
bool   IsFXCanonical(string s);
bool   IsHKStockSymbol(string s);
bool   IsLikelyStockFromCalcMode(const int calc_mode);
bool   IsLikelyTickerStockSymbol(const string s);
bool   IsMajorCurrency(const string ccy);
bool   IsUpperAlpha(const int c);
bool   IsTimeInsideSessions(const SessionWindow &arr[], const int day, const int hhmm_now);

long   ReadSymbolIntegerSafe(const string sym, const ENUM_SYMBOL_INFO_INTEGER prop, const long fallback);
double ReadSymbolDoubleSafe(const string sym, const ENUM_SYMBOL_INFO_DOUBLE prop, const double fallback);
string ReadSymbolStringSafe(const string sym, const ENUM_SYMBOL_INFO_STRING prop, const string fallback);

int    FlatSessionIndex(const int day, const int slot);
int    HHMMFromSeconds(const int seconds_in_day);
int    HHMMFromDateTime(const datetime t);
int    DayOfWeekServer(const datetime t);
int    ScoreSymbolWorstness(SymbolRecord &rec);
int    SumWeekSessionCounts(const int &counts[]);
int    ClampInt(const int v, const int lo, const int hi);

void   SortStringsAscending(string &arr[]);
void   SortWorstByScoreDescending(int &idxs[], int &scores[]);

string BoolTo01(const bool v);
string DoubleToSafeStr(const double v);
string IntToSafeStr(const int v);
string LongToSafeStr(const long v);
string LongToStringSafe(const long v);
string StringToSafeStr(const string v);
string DateTimeToSafeStr(const datetime v);
string DateTimeToMinuteStr(const datetime v);
string AssetClassToString(const AssetClass v);
string SpecLevelToString(const SpecLevel v);
string TradabilityClassToString(const TradabilityClass v);
string MarketOpenStateToString(const MarketOpenState v);
string SymbolActivityClassToString(const SymbolActivityClass v);
string TickPathModeToString(const TickPathMode v);
string CopyTicksPhaseToString(const CopyTicksPhase v);
string Phase2EventTypeToString(const Phase2EventType v);
string ProvenanceValueToString(const ProvenanceValue v);
string CostStateToString(const CostState v);
string SummaryStateToString(const SummaryState v);
string DataReasonCodeToString(const DataReasonCode v);
string TradabilityReasonCodeToString(const TradabilityReasonCode v);
string PublishReasonCodeToString(const PublishReasonCode v);
string SpecStateExToString(const SpecStateEx v);
string SessionStateExToString(const SessionStateEx v);
string TradeStateExToString(const TradeStateEx v);
string PublishStateExToString(const PublishStateEx v);
string SymbolStateToString(const SymbolState st);
string ReasonCodeToString(const ReasonCode rc);
string HydrationStateExToString(const HydrationStateEx st);
string IoOpToString(const int op);

void   ResetPublishState(PublishMetaState &st);
void   ResetIoState();
void   ResetPerfState();

string BuildFirmId();
string EnsureTrailingBackslash(const string s);

long   GetMinuteId(const datetime t);
bool   IsPublishWindowOpen(const datetime t, const int offset_sec, const int window_sec);
bool   PublishLockExists();
void   MaybePublishStage();
void   MaybePublishDebugJson();
void   MaybeCleanupTemp();

bool   WriteTextFileCommon(const string rel_path, const string content, int &bytes_written);
bool   CommitFileAtomic(const string tmp_rel, const string final_rel);
bool   BestEffortPreservePrevious(const string current_rel, const string prev_rel);
bool   BestEffortBackup(const string final_rel, const string backup_rel);
bool   BestEffortPersistenceBackup(const string final_rel, const string backup_rel);
string BuildTempFileName(const string tmp_dir, const string final_name, const long minute_id, const int write_seq);

string JsonEscape(const string s);
string JsonBool(const bool v);
string JsonInt(const int v);
string JsonLong(const long v);
string JsonDouble6(const double v);
string JsonDoubleOrNull6(const double v);
string JsonString(const string s);
string JsonDateTime(const datetime v);
string JsonDateTimeOrNull(const datetime v);
string JsonLongOrNull(const long v);

uint   FNV1a32(const string s);
string FNV1a32Hex(const string s);
string BuildUniverseFingerprint();
string BuildSymbolIdentityHash(const SymbolRecord &rec);

void   UpdateHydration3A(SymbolRecord &rec);
void   UpdateSectorClassification(SymbolRecord &rec);
int    DeriveSectorId(SymbolRecord &rec);
int    DeriveReasonCode3A(SymbolRecord &rec);
int    DeriveSpecQuality(SymbolRecord &rec);
bool   DeriveSpecSanityOk(SymbolRecord &rec);

string BuildEA1MarketJson();
string BuildEA1DebugJson();

string BuildMetaJson(const string schema_name,
                     const string producer,
                     const long minute_id,
                     const int seq,
                     const string content_hash)
  {
   string s = "{";
   s += "\"schema_name\":" + JsonString(schema_name) + ",";
   s += "\"schema_version\":\"2.4\",";
   s += "\"producer\":" + JsonString(producer) + ",";
   s += "\"producer_version\":\"Phase4\",";
   s += "\"seq\":" + IntegerToString(seq) + ",";
   s += "\"generated_at_server\":" + JsonDateTime(g_schedule.now_server_time) + ",";
   s += "\"generated_at_utc\":" + JsonDateTime(g_schedule.now_utc_time) + ",";
   s += "\"minute_id\":" + LongToStringSafe(minute_id) + ",";
   s += "\"content_hash\":" + JsonString(content_hash) + ",";
   s += "\"firm_id\":" + JsonString(g_firm_id) + ",";
   s += "\"universe_fingerprint\":" + JsonString(BuildUniverseFingerprint()) + ",";
   s += "\"universe_size\":" + IntegerToString(g_universe.size);
   s += "}";
   return s;
  }
       
string BuildSpecHash(const SymbolRecord &rec)
  {
   string s = "";
   s += rec.raw_symbol + "|";
   s += IntToSafeStr(rec.spec_observed.digits) + "|";
   s += DoubleToSafeStr(rec.spec_observed.point) + "|";
   s += DoubleToSafeStr(rec.spec_observed.contract_size) + "|";
   s += DoubleToSafeStr(rec.spec_observed.tick_size) + "|";
   s += DoubleToSafeStr(rec.spec_observed.tick_value) + "|";
   s += DoubleToSafeStr(rec.spec_observed.volume_min) + "|";
   s += DoubleToSafeStr(rec.spec_observed.volume_max) + "|";
   s += DoubleToSafeStr(rec.spec_observed.volume_step) + "|";
   s += IntToSafeStr(rec.spec_observed.trade_mode) + "|";
   s += IntToSafeStr(rec.spec_observed.calc_mode) + "|";
   s += StringToSafeStr(rec.spec_observed.margin_currency) + "|";
   s += StringToSafeStr(rec.spec_observed.profit_currency) + "|";
   s += AssetClassToString(rec.spec_derived.asset_class) + "|";
   s += TradabilityClassToString(rec.spec_derived.tradability_class);

   return FNV1a32Hex(s);
  }

void RefreshSpecHash(SymbolRecord &rec)
  {
   string new_hash = BuildSpecHash(rec);

   if(rec.spec_change.spec_hash == "")
     {
      rec.spec_change.spec_hash = new_hash;
      return;
     }

   if(rec.spec_change.spec_hash != new_hash)
     {
      rec.spec_change.spec_hash = new_hash;
      rec.spec_change.spec_change_count++;
      rec.spec_change.last_spec_change_time_server = g_schedule.now_server_time;
      rec.spec_change.last_material_change_reason = "observed_spec_changed";
      rec.cost_dirty = true;
      rec.continuity.persistence_dirty = true;
     }
  }
                       
string BuildUniverseSummaryJson();
string BuildCoverageSummaryJson();
string BuildIdentityJson(const SymbolRecord &rec);
string BuildSymbolSpecJson(const SymbolRecord &rec);
string BuildSymbolSessionsJson(const SymbolRecord &rec);
string BuildSymbolMarketStatusJson(const SymbolRecord &rec);
string BuildSymbolMarketJson(const SymbolRecord &rec);
string BuildSymbolTickHistoryJson(const SymbolRecord &rec);
string BuildSymbolCostJson(const SymbolRecord &rec);
string BuildSymbolCapabilitiesJson(const SymbolRecord &rec);
string BuildSymbolContinuityJson(const SymbolRecord &rec);
string BuildSymbolStateSummaryJson(const SymbolRecord &rec);
string BuildSymbolHealthJson(const SymbolRecord &rec);
string BuildSymbolJson(const SymbolRecord &rec);

string BuildSessionsTodayJson(const SessionWindow &arr[], const int day);
string SectorIdToStringKey(const int sector_id);

//====================================================================
// 7. Lifecycle Functions
//====================================================================
int OnInit()
  {
   ResetGlobalState();
   InitFirmFiles();
   BuildUniverse();

   g_init_server_time = TimeCurrent();
   InitPhase4Persistence();

   for(int i = 0; i < g_universe.size; i++)
      RecomputeBaseState(g_universe.records[i]);

   if(!EventSetTimer(MathMax(1, InpTimerIntervalSec)))
     {
      Print("Failed to start timer. Error=", GetLastError());
      return(INIT_FAILED);
     }

   if(InpShowHUD)
      Comment(EA_NAME, " ", EA_BUILD_CHANNEL, "\nInitializing...");

   return(INIT_SUCCEEDED);
  }
  
  void OnDeinit(const int reason)
  {
   EventKillTimer();

   if(InpPersistenceEnabled)
     {
      UpdateScheduleClock();

      for(int i = 0; i < g_universe.size; i++)
        {
         if(g_universe.records[i].selected_ok || g_universe.records[i].spec_derived.spec_partial)
            SaveSymbolPersistence(g_universe.records[i]);
        }
     }

   if(InpShowHUD)
      Comment("");
  }
  
void OnTick()
  {
  }
//====================================================================
// 8. Timer Engine
//====================================================================
void OnTimer()
  {
   if(g_schedule.timer_busy)
     {
      g_schedule.timer_overrun_count++;
      return;
     }

   g_schedule.timer_busy = true;
   ulong cycle_start = GetTickCount();

   UpdateScheduleClock();

   g_dbg_recompute_base_calls      = 0;
   g_dbg_recompute_base_skip_calls = 0;
   g_dbg_spec_reads                = 0;
   g_dbg_snapshot_reads            = 0;
   g_dbg_copyticks_calls           = 0;
   g_dbg_margin_probe_calls        = 0;
   g_dbg_session_load_calls        = 0;
   g_dbg_activity_refresh_calls    = 0;

   ulong t_hydrate = GetMicrosecondCount() / 1000;

   RunSubscriptionBudget();
   RunSpecBudget();
   RunSessionBudget();
   RunSnapshotBudget();
   RunCostBudget();
   RunCopyTicksBudget();
   RunConsistencyBudget();

   RunPersistenceSaveBudget();

   g_perf.dur_hydrate_ms = (int)((GetMicrosecondCount() / 1000) - t_hydrate);

   if(g_last_coverage_recount == 0 ||
      (g_schedule.now_server_time - g_last_coverage_recount) >= MathMax(1, InpCoverageRefreshSec))
     {
      RecountCoverage();
      RecountCoverage3A();
      g_last_coverage_recount = g_schedule.now_server_time;
     }

   if(InpShowHUD && g_schedule.now_server_time > 0)
     {
      int hud_refresh_sec = MathMax(1, InpHudRefreshSec);

      if(g_last_hud_render_time == 0 ||
         (g_schedule.now_server_time - g_last_hud_render_time) >= hud_refresh_sec)
        {
         RenderHUD();
         g_last_hud_render_time = g_schedule.now_server_time;
        }
     }

   MaybePublishStage();
   MaybePublishDebugJson();
   MaybeCleanupTemp();

   g_schedule.last_cycle_ms = (int)(GetTickCount() - cycle_start);
   g_schedule.timer_tick_count++;

   g_perf.dur_step_total_ms = g_schedule.last_cycle_ms;
   g_perf.perf_warn         = (g_schedule.last_cycle_ms >= InpPerfWarnMs);

   g_schedule.timer_busy = false;
  }

// 9. Universe Manager
//====================================================================
void BuildUniverse()
  {
   ArrayResize(g_universe.symbols, 0);
   ArrayResize(g_universe.records, 0);
   g_universe.size = 0;

   bool selected_only = InpUseMarketWatchOnly;
   int total = SymbolsTotal(selected_only);
   if(total <= 0)
      return;

   string temp_symbols[];
   ArrayResize(temp_symbols, total);

   int count = 0;
   for(int i = 0; i < total; i++)
     {
      string sym = SymbolName(i, selected_only);
      if(sym == "")
         continue;

      temp_symbols[count] = sym;
      count++;
     }

   ArrayResize(temp_symbols, count);
   SortStringsAscending(temp_symbols);

   int take = count;
   int cap = InpUniverseMaxSymbols;
   if(cap > 0 && cap < take)
      take = cap;
   if(take > MAX_SYMBOLS_HARD)
      take = MAX_SYMBOLS_HARD;

   ArrayResize(g_universe.symbols, take);
   ArrayResize(g_universe.records, take);

   for(int j = 0; j < take; j++)
     {
      g_universe.symbols[j] = temp_symbols[j];
      InitSymbolRecord(g_universe.records[j], temp_symbols[j]);
     }

   g_universe.size = take;
  }

void InitSymbolRecord(SymbolRecord &rec, const string symbol)
  {
   rec.raw_symbol        = symbol;
   rec.normalized_symbol = NormalizeSymbol(symbol);
   rec.selected_ok       = false;
   rec.select_fail_count = 0;

   rec.base_dirty             = true;
   rec.spec_dirty             = true;
   rec.session_dirty          = true;
   rec.tick_dirty             = true;
   rec.cost_dirty             = true;
   rec.last_spec_refresh_time    = 0;
rec.last_session_refresh_time = 0;
rec.last_cost_refresh_time    = 0;
rec.last_margin_probe_time    = 0;

   ResetSpecObserved(rec.spec_observed);
   ResetSpecDerived(rec.spec_derived);

   ResetSessionState(rec.session_state);
   
   ResetTickState(rec.tick_state);
   ResetCapabilityState(rec.capability);
   ResetCostState(rec.cost);
   ResetHealthPhase3State(rec.health3);
   ResetHydration3AState(rec.hydration3a);
   ResetSpecChangeState(rec.spec_change);
   ResetContinuityState(rec.continuity);
   
   rec.health.state                  = SS_NEW;
   rec.health.reason                 = RC_INIT;
   rec.health.usable_for_observation = false;
   rec.health.spec_ready             = false;
   rec.health.session_ready          = false;
   rec.health.tick_ready             = false;
  }

//====================================================================
// 10. Subscription Manager
//====================================================================

void MarkBaseDirty(SymbolRecord &rec)
  {
   rec.base_dirty = true;
  }

void RunConsistencyBudget()
  {
   int n = g_universe.size;
   if(n <= 0)
      return;

   int work = MathMin(n, MathMax(1, InpConsistencyBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_consistency;
      g_schedule.cursor_consistency++;
      if(g_schedule.cursor_consistency >= n)
         g_schedule.cursor_consistency = 0;

      if(!g_universe.records[idx].base_dirty)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      MarkBaseDirty(g_universe.records[idx]);
      g_universe.records[idx].base_dirty = false;
     }
  }
  
void RunSubscriptionBudget()
  {
   int n = g_universe.size;
   if(n <= 0)
      return;

   int work = MathMin(n, MathMax(1, InpSubscribeBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_subscribe;
      g_schedule.cursor_subscribe++;
      if(g_schedule.cursor_subscribe >= n)
         g_schedule.cursor_subscribe = 0;

      if(g_universe.records[idx].selected_ok)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      ResetLastError();
      bool ok = SymbolSelect(g_universe.records[idx].raw_symbol, true);

      if(ok)
         g_universe.records[idx].selected_ok = true;
      else
         g_universe.records[idx].select_fail_count++;

      MarkBaseDirty(g_universe.records[idx]);
     }
  }

//====================================================================
// 11. Spec Engine
//====================================================================
void RunSpecBudget()
  {
   int n = g_universe.size;
   if(n <= 0)
      return;

   int work = MathMin(n, MathMax(1, InpSpecBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_spec;
      g_schedule.cursor_spec++;
      if(g_schedule.cursor_spec >= n)
         g_schedule.cursor_spec = 0;

      if(!g_universe.records[idx].selected_ok)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      bool due = false;

      if(g_universe.records[idx].spec_dirty)
         due = true;
      else if(g_universe.records[idx].last_spec_refresh_time <= 0)
         due = true;
      else if((g_schedule.now_server_time - g_universe.records[idx].last_spec_refresh_time) >= MathMax(1, InpSpecRefreshSec))
         due = true;

      if(!due)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      ReadSpecObserved(g_universe.records[idx]);
      DeriveSpecState(g_universe.records[idx]);
      UpdateTradability(g_universe.records[idx]);
      UpdateAssetClass(g_universe.records[idx]);
      RefreshSpecHash(g_universe.records[idx]);
      MarkBaseDirty(g_universe.records[idx]);
     }
  }

void ReadSpecObserved(SymbolRecord &rec)
  {
   string sym = rec.raw_symbol;
g_dbg_spec_reads++;
   rec.spec_observed.digits          = (int)ReadSymbolIntegerSafe(sym, SYMBOL_DIGITS, INVALID_I32);
   rec.spec_observed.point           = ReadSymbolDoubleSafe(sym, SYMBOL_POINT, INVALID_DBL);
   rec.spec_observed.contract_size   = ReadSymbolDoubleSafe(sym, SYMBOL_TRADE_CONTRACT_SIZE, INVALID_DBL);
   rec.spec_observed.tick_size       = ReadSymbolDoubleSafe(sym, SYMBOL_TRADE_TICK_SIZE, INVALID_DBL);
   rec.spec_observed.tick_value      = ReadSymbolDoubleSafe(sym, SYMBOL_TRADE_TICK_VALUE, INVALID_DBL);
   rec.spec_observed.volume_min      = ReadSymbolDoubleSafe(sym, SYMBOL_VOLUME_MIN, INVALID_DBL);
   rec.spec_observed.volume_max      = ReadSymbolDoubleSafe(sym, SYMBOL_VOLUME_MAX, INVALID_DBL);
   rec.spec_observed.volume_step     = ReadSymbolDoubleSafe(sym, SYMBOL_VOLUME_STEP, INVALID_DBL);
   rec.spec_observed.trade_mode      = (int)ReadSymbolIntegerSafe(sym, SYMBOL_TRADE_MODE, INVALID_I32);
   rec.spec_observed.calc_mode       = (int)ReadSymbolIntegerSafe(sym, SYMBOL_TRADE_CALC_MODE, INVALID_I32);
   rec.spec_observed.margin_currency = ReadSymbolStringSafe(sym, SYMBOL_CURRENCY_MARGIN, "");
   rec.spec_observed.profit_currency = ReadSymbolStringSafe(sym, SYMBOL_CURRENCY_PROFIT, "");
   rec.spec_observed.swap_long       = ReadSymbolDoubleSafe(sym, SYMBOL_SWAP_LONG, INVALID_DBL);
   rec.spec_observed.swap_short      = ReadSymbolDoubleSafe(sym, SYMBOL_SWAP_SHORT, INVALID_DBL);
   rec.spec_dirty = false;
   rec.cost_dirty = true;
   rec.continuity.persistence_dirty = true;
   rec.base_dirty = true;
   rec.last_spec_refresh_time = g_schedule.now_server_time;
  }

void DeriveSpecState(SymbolRecord &rec)
  {
   bool digits_ok = (rec.spec_observed.digits != INVALID_I32 && rec.spec_observed.digits >= 0);
   bool point_ok  = (IsKnownNumber(rec.spec_observed.point) && rec.spec_observed.point > 0.0);
   bool mode_ok   = (rec.spec_observed.trade_mode != INVALID_I32 || rec.spec_observed.calc_mode != INVALID_I32);

   rec.spec_derived.spec_partial   = false;
   rec.spec_derived.spec_min_ready = false;
   rec.spec_derived.spec_level     = SL_NONE;

   if(digits_ok || point_ok || mode_ok)
     {
      rec.spec_derived.spec_partial = true;
      rec.spec_derived.spec_level   = SL_PARTIAL;
     }

   if(digits_ok && point_ok && mode_ok)
     {
      rec.spec_derived.spec_min_ready = true;
      rec.spec_derived.spec_level     = SL_MIN_READY;
     }
  }

void UpdateTradability(SymbolRecord &rec)
  {
   rec.spec_derived.tradability_class = TC_UNKNOWN;

   int mode = rec.spec_observed.trade_mode;
   if(mode == INVALID_I32)
      return;

   // MT5 ENUM_SYMBOL_TRADE_MODE numeric mapping:
   // 0 = SYMBOL_TRADE_MODE_DISABLED
   // 1 = SYMBOL_TRADE_MODE_LONGONLY
   // 2 = SYMBOL_TRADE_MODE_SHORTONLY
   // 3 = SYMBOL_TRADE_MODE_CLOSEONLY
   // 4 = SYMBOL_TRADE_MODE_FULL

   switch(mode)
     {
      case 0:
         rec.spec_derived.tradability_class = TC_DISABLED;
         return;

      case 3:
         rec.spec_derived.tradability_class = TC_CLOSE_ONLY;
         return;

      case 4:
         rec.spec_derived.tradability_class = TC_FULL_ACCESS;
         return;

      default:
         rec.spec_derived.tradability_class = TC_UNKNOWN;
         return;
     }
  }

void UpdateAssetClass(SymbolRecord &rec)
  {
   string c = BuildCanonicalSymbol(rec.normalized_symbol);

   rec.spec_derived.canonical_symbol          = c;
   rec.spec_derived.asset_class               = AC_CUSTOM;
   rec.spec_derived.class_key                 = "custom";
   rec.spec_derived.canonical_group           = "custom";
   rec.spec_derived.classification_source     = "fallback_custom";
   rec.spec_derived.classification_confidence = 20;

   if(IsFXCanonical(c))
     {
      rec.spec_derived.asset_class               = AC_FX;
      rec.spec_derived.class_key                 = "fx";
      rec.spec_derived.canonical_group           = "fx";
      rec.spec_derived.classification_source     = "canonical_fx";
      rec.spec_derived.classification_confidence = 95;
      return;
     }

   if(c == "XAUUSD" || c == "XAGUSD" || c == "XPTUSD" || c == "XPDUSD" ||
      c == "XAU" || c == "XAG" || c == "XPT" || c == "XPD" ||
      c == "GOLD" || c == "SILVER")
     {
      rec.spec_derived.asset_class               = AC_METAL;
      rec.spec_derived.class_key                 = "metal";
      rec.spec_derived.canonical_group           = "metal";
      rec.spec_derived.classification_source     = "canonical_metal";
      rec.spec_derived.classification_confidence = 90;
      return;
     }

   if(StringFind(c, "BTC") >= 0 || StringFind(c, "ETH") >= 0 || StringFind(c, "SOL") >= 0 ||
      StringFind(c, "XRP") >= 0 || StringFind(c, "ADA") >= 0 || StringFind(c, "DOGE") >= 0 ||
      StringFind(c, "LTC") >= 0 || StringFind(c, "BCH") >= 0)
     {
      rec.spec_derived.asset_class               = AC_CRYPTO;
      rec.spec_derived.class_key                 = "crypto";
      rec.spec_derived.canonical_group           = "crypto";
      rec.spec_derived.classification_source     = "canonical_crypto";
      rec.spec_derived.classification_confidence = 85;
      return;
     }

   if(c == "US30" || c == "NAS100" || c == "SPX500" || c == "GER40" ||
      c == "UK100" || c == "JP225" || c == "HK50")
     {
      rec.spec_derived.asset_class               = AC_INDEX;
      rec.spec_derived.class_key                 = "index";
      rec.spec_derived.canonical_group           = "index";
      rec.spec_derived.classification_source     = "canonical_index";
      rec.spec_derived.classification_confidence = 90;
      return;
     }

   if(IsHKStockSymbol(rec.raw_symbol))
     {
      rec.spec_derived.asset_class               = AC_STOCK;
      rec.spec_derived.class_key                 = "stock";
      rec.spec_derived.canonical_group           = "stock";
      rec.spec_derived.classification_source     = "hk_stock_suffix";
      rec.spec_derived.classification_confidence = 85;
      return;
     }

   if(IsLikelyStockFromCalcMode(rec.spec_observed.calc_mode))
     {
      rec.spec_derived.asset_class               = AC_STOCK;
      rec.spec_derived.class_key                 = "stock";
      rec.spec_derived.canonical_group           = "stock";
      rec.spec_derived.classification_source     = "calc_mode_stock";
      rec.spec_derived.classification_confidence = 75;
      return;
     }

   if(IsKnownNumber(rec.spec_observed.contract_size) && rec.spec_observed.contract_size == 100000.0)
     {
      rec.spec_derived.asset_class               = AC_FX;
      rec.spec_derived.class_key                 = "fx";
      rec.spec_derived.canonical_group           = "fx";
      rec.spec_derived.classification_source     = "contract_size_fx";
      rec.spec_derived.classification_confidence = 60;
      return;
     }

   if(IsLikelyTickerStockSymbol(c) &&
      IsKnownNumber(rec.spec_observed.contract_size) &&
      rec.spec_observed.contract_size == 1.0 &&
      IsKnownNumber(rec.spec_observed.volume_step) &&
      rec.spec_observed.volume_step >= 1.0 &&
      rec.spec_observed.trade_mode == 4)
     {
      rec.spec_derived.asset_class               = AC_STOCK;
      rec.spec_derived.class_key                 = "stock";
      rec.spec_derived.canonical_group           = "stock";
      rec.spec_derived.classification_source     = "ticker_stock_heuristic";
      rec.spec_derived.classification_confidence = 55;
      return;
     }
  }

     
int DeriveSectorId(SymbolRecord &rec)
  {
   string c = rec.spec_derived.canonical_symbol;

   if(rec.spec_derived.asset_class == AC_FX)
     {
      string a = "";
      string b = "";
      if(StringLen(c) >= 6)
        {
         a = StringSubstr(c, 0, 3);
         b = StringSubstr(c, 3, 3);
        }

      bool a_major = IsMajorCurrency(a);
      bool b_major = IsMajorCurrency(b);

      if(a_major && b_major)
        {
         bool has_usd = (a == "USD" || b == "USD");
         if(has_usd)
            return SID_FX_MAJOR;
         return SID_FX_MINOR;
        }

      return SID_FX_EXOTIC;
     }

   if(rec.spec_derived.asset_class == AC_METAL)
      return SID_METALS;

   if(rec.spec_derived.asset_class == AC_INDEX)
      return SID_INDICES;

   if(rec.spec_derived.asset_class == AC_CRYPTO)
      return SID_CRYPTO;

   if(rec.spec_derived.asset_class == AC_STOCK)
      return SID_STOCKS;

   if(StringFind(c, "WTI") >= 0 || StringFind(c, "BRENT") >= 0 || StringFind(c, "OIL") >= 0 || StringFind(c, "NGAS") >= 0)
      return SID_ENERGY;

   if(StringFind(c, "BOND") >= 0 || StringFind(c, "NOTE") >= 0 || StringFind(c, "BUND") >= 0)
      return SID_RATES;

   if(rec.spec_derived.asset_class == AC_COMMODITY)
      return SID_COMMODITIES;

   return SID_OTHER;
  }

bool DeriveSpecSanityOk(SymbolRecord &rec)
  {
   if(!rec.spec_derived.spec_min_ready)
      return false;

   if(!IsKnownNumber(rec.spec_observed.point) || rec.spec_observed.point <= 0.0)
      return false;

   if(!IsKnownNumber(rec.spec_observed.tick_size) || rec.spec_observed.tick_size <= 0.0)
      return false;

   if(!IsKnownNumber(rec.spec_observed.contract_size) || rec.spec_observed.contract_size <= 0.0)
      return false;

   if(!IsKnownNumber(rec.spec_observed.volume_step) || rec.spec_observed.volume_step <= 0.0)
      return false;

   return true;
  }

int DeriveSpecQuality(SymbolRecord &rec)
  {
   int q = 0;

   if(rec.spec_derived.spec_partial)   q += 25;
   if(rec.spec_derived.spec_min_ready) q += 35;
   if(IsKnownNumber(rec.spec_observed.contract_size) && rec.spec_observed.contract_size > 0.0) q += 10;
   if(IsKnownNumber(rec.spec_observed.tick_size) && rec.spec_observed.tick_size > 0.0) q += 10;
   if(IsKnownNumber(rec.spec_observed.tick_value) && rec.spec_observed.tick_value >= 0.0) q += 10;
   if(IsKnownNumber(rec.spec_observed.volume_step) && rec.spec_observed.volume_step > 0.0) q += 10;

   return ClampInt(q, 0, 100);
  }

int DeriveReasonCode3A(SymbolRecord &rec)
  {
   if(rec.hydration3a.cooled_down_until > 0 && g_schedule.now_server_time < rec.hydration3a.cooled_down_until)
      return RC3_COOLED_DOWN;

   if(rec.hydration3a.expired_or_disabled)
      return RC3_EXPIRED_OR_DELISTED;

   if(rec.spec_derived.tradability_class == TC_DISABLED || rec.spec_derived.tradability_class == TC_CLOSE_ONLY)
      return RC3_TRADE_DISABLED;

   if(!rec.hydration3a.market_open_now)
      return RC3_MARKET_CLOSED;

   if(rec.tick_state.snapshot_path_ok)
      return RC3_OK;

   long uptime = 0;
   if(g_init_server_time > 0 && g_schedule.now_server_time >= g_init_server_time)
      uptime = (long)g_schedule.now_server_time - (long)g_init_server_time;

   if(uptime < InpStartupGraceSec)
      return RC3_WARMING_UP;

   if(rec.hydration3a.dead_quote)
      return RC3_HYDRATION_TIMEOUT;

   if(rec.hydration3a.hydration_attempts > 0)
      return RC3_QUOTE_UNAVAILABLE;

   return RC3_WARMING_UP;
  }

void UpdateSectorClassification(SymbolRecord &rec)
  {
   rec.hydration3a.sector_id = DeriveSectorId(rec);
  }

void UpdateHydration3A(SymbolRecord &rec)
  {
   rec.hydration3a.quote_session_open = rec.session_state.quote_session_open_now;
   rec.hydration3a.trade_session_open = rec.session_state.trade_session_open_now;
   rec.hydration3a.market_open_now    = (rec.tick_state.market_open_state == MOS_OPEN_NOW);

   rec.hydration3a.expired_or_disabled =
      (rec.spec_derived.tradability_class == TC_DISABLED);

   rec.hydration3a.spec_sanity_ok = DeriveSpecSanityOk(rec);
   rec.hydration3a.spec_quality   = DeriveSpecQuality(rec);

   UpdateSectorClassification(rec);

   if(rec.hydration3a.cooled_down_until > 0 &&
      g_schedule.now_server_time >= rec.hydration3a.cooled_down_until)
     {
      rec.hydration3a.cooled_down_until  = 0;
      rec.hydration3a.dead_quote         = false;
      rec.hydration3a.hydration_attempts = 0;
     }

   if(!rec.selected_ok)
      rec.hydration3a.state_ex = HDE_NEW;
   else if(!rec.spec_derived.spec_partial)
      rec.hydration3a.state_ex = HDE_SELECTED;
   else if(!rec.spec_derived.spec_min_ready)
      rec.hydration3a.state_ex = HDE_SELECTED;
   else if(rec.hydration3a.expired_or_disabled)
      rec.hydration3a.state_ex = HDE_EXPIRED_OR_DISABLED;
   else if(!rec.hydration3a.market_open_now)
      rec.hydration3a.state_ex = HDE_MARKET_CLOSED;
   else if(rec.tick_state.snapshot_path_ok)
      rec.hydration3a.state_ex = HDE_TICK_READY;
   else
      rec.hydration3a.state_ex = HDE_TICK_PENDING;

   if(rec.hydration3a.market_open_now && !rec.tick_state.snapshot_path_ok)
     {
      if(rec.hydration3a.first_open_without_tick_time <= 0)
         rec.hydration3a.first_open_without_tick_time = g_schedule.now_server_time;

      long missing_for = (long)g_schedule.now_server_time - (long)rec.hydration3a.first_open_without_tick_time;

      if(missing_for >= InpDeadQuoteAfterSec)
        {
         rec.hydration3a.dead_quote = true;

         if(rec.hydration3a.hydration_attempts < InpMaxHydrationAttempts)
            rec.hydration3a.hydration_attempts++;

         if(rec.hydration3a.hydration_attempts >= InpMaxHydrationAttempts)
           {
            rec.hydration3a.cooled_down_until = g_schedule.now_server_time + InpCopyTicksCooldownSec;
            rec.hydration3a.state_ex          = HDE_COOLED_DOWN;
           }
         else
           {
            rec.hydration3a.state_ex = HDE_DEAD_QUOTE;
           }
        }
     }
   else
     {
      rec.hydration3a.first_open_without_tick_time = 0;
      rec.hydration3a.dead_quote                   = false;
      rec.hydration3a.hydration_attempts           = 0;
     }

   if(rec.hydration3a.cooled_down_until > 0 &&
      g_schedule.now_server_time < rec.hydration3a.cooled_down_until)
      rec.hydration3a.state_ex = HDE_COOLED_DOWN;

   rec.hydration3a.reason_code_3a = DeriveReasonCode3A(rec);
  }

void UpdateHealthFromSpec(SymbolRecord &rec)
  {
   RecomputeBaseState(rec);
  }

//====================================================================
// 12. Session Engine
//====================================================================
void RunSessionBudget()
  {
   int n = g_universe.size;
   if(n <= 0)
      return;

   int work = MathMin(n, MathMax(1, InpSessionBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_session;
      g_schedule.cursor_session++;
      if(g_schedule.cursor_session >= n)
         g_schedule.cursor_session = 0;

      if(!g_universe.records[idx].selected_ok)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      if(!g_universe.records[idx].spec_derived.spec_partial)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      if(g_universe.records[idx].session_state.sessions_loaded &&
         g_universe.records[idx].last_session_refresh_time > 0 &&
         (g_schedule.now_server_time - g_universe.records[idx].last_session_refresh_time) < MathMax(1, InpSessionRefreshSec))
        {
         UpdateSessionOpenState(g_universe.records[idx]);
         RefreshActivityOnly(g_universe.records[idx]);
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      LoadSessions(g_universe.records[idx]);
      UpdateSessionOpenState(g_universe.records[idx]);
      RecomputeBaseState(g_universe.records[idx]);
     }
  }
  
void ResetPublishState(PublishMetaState &st)
  {
   st.minute_id = -1;
   st.write_seq = 0;
   st.last_published_minute_id = -1;
   st.attempted = false;
   st.ok = false;
   st.last_error = "";
   st.publish_skipped_lock = false;
  }

void ResetIoState()
  {
   g_io_last.last_file  = "";
   g_io_last.last_op    = IO_OP_NONE;
   g_io_last.open_err   = 0;
   g_io_last.read_err   = 0;
   g_io_last.write_err  = 0;
   g_io_last.move_err   = 0;
   g_io_last.copy_err   = 0;
   g_io_last.delete_err = 0;
   g_io_last.bytes      = 0;
   g_io_last.size       = 0;
   g_io_last.guard_ok   = false;

   g_io_counters.io_ok_count   = 0;
   g_io_counters.io_fail_count = 0;
  }

void ResetPerfState()
  {
   g_perf.dur_step_total_ms   = 0;
   g_perf.dur_hydrate_ms      = 0;
   g_perf.dur_build_stage_ms  = 0;
   g_perf.dur_write_tmp_ms    = 0;
   g_perf.dur_commit_ms       = 0;
   g_perf.dur_backup_ms       = 0;
   g_perf.dur_read_ms         = 0;
   g_perf.dur_validate_ms     = 0;
   g_perf.dur_parse_ms        = 0;
   g_perf.perf_warn           = false;
  }

void ResetHydration3AState(SymbolHydration3AState &st)
  {
   st.state_ex                     = HDE_NEW;
   st.reason_code_3a               = RC3_WARMING_UP;
   st.hydration_attempts           = 0;
   st.cooled_down_until            = 0;
   st.first_open_without_tick_time = 0;
   st.quote_session_open           = false;
   st.trade_session_open           = false;
   st.market_open_now              = false;
   st.expired_or_disabled          = false;
   st.dead_quote                   = false;
   st.spec_sanity_ok               = false;
   st.spec_quality                 = 0;
   st.sector_id                    = SID_OTHER;
  }

void ResetSpecChangeState(SymbolSpecChangeState &st)
  {
   st.spec_hash = "";
   st.spec_change_count = 0;
   st.last_spec_change_time_server = 0;
   st.last_material_change_reason = "";
  }

void ResetContinuityState(SymbolContinuityState &st)
  {
   st.persistence_state = PTX_NONE;

   st.persistence_loaded = false;
   st.persistence_fresh = false;
   st.persistence_stale = false;
   st.persistence_corrupt = false;
   st.persistence_incompatible = false;

   st.resumed_from_persistence = false;
   st.restarted_clean = false;

   st.persistence_age_sec = 0;
   st.continuity_origin = CO_NONE;
   st.continuity_last_good_server_time = 0;

   st.last_persistence_save_time = 0;
   st.persistence_dirty = true;
   st.loaded_once = false;

   st.last_saved_history_msc = INVALID_TIME_MSC;
   st.last_saved_copyticks_phase = (int)CT_NOT_STARTED;
   st.last_saved_payload_hash = "";
  }
  
  void InitPhase4Persistence()
  {
   if(!InpPersistenceEnabled)
      return;

   for(int i = 0; i < g_universe.size; i++)
      LoadSymbolPersistence(g_universe.records[i]);
  }
  
  void RunPersistenceLoadBudget()
  {
   // Persistence is loaded only once in OnInit() through InitPhase4Persistence().
   // Do not reload from disk during live timer cycles.
   return;
  }

void RunPersistenceSaveBudget()
  {
   if(!InpPersistenceEnabled)
      return;

   int n = g_universe.size;
   if(n <= 0 || g_schedule.now_server_time <= 0)
      return;

   long minute_id = GetMinuteId(g_schedule.now_server_time);
   if(g_persist_writes_minute_id != minute_id)
     {
      g_persist_writes_minute_id = minute_id;
      g_persist_writes_this_minute = 0;
     }

   int work = MathMin(n, MathMax(1, InpPersistenceSaveBudget));

   for(int k = 0; k < work; k++)
     {
      if(g_persist_writes_this_minute >= InpPersistenceMaxWritesPerMin)
         return;

      int idx = g_schedule_cursor_persist_save++;
      if(g_schedule_cursor_persist_save >= n)
         g_schedule_cursor_persist_save = 0;

      if(!g_universe.records[idx].selected_ok || !g_universe.records[idx].spec_derived.spec_partial)
         continue;

      long since_last_save = 0;
      if(g_universe.records[idx].continuity.last_persistence_save_time > 0)
         since_last_save =
            (long)g_schedule.now_server_time -
            (long)g_universe.records[idx].continuity.last_persistence_save_time;

      bool checkpoint_due =
         (g_universe.records[idx].continuity.last_persistence_save_time <= 0) ||
         (since_last_save >= MathMax(1, InpPersistenceSaveEverySec));

      bool min_gap_ok =
         (g_universe.records[idx].continuity.last_persistence_save_time <= 0) ||
         (since_last_save >= MathMax(1, InpPersistenceMinSaveGapSec));

      bool material_due = DidMaterialContinuityChange(g_universe.records[idx]);

      bool due = false;

      if(g_universe.records[idx].continuity.persistence_dirty && min_gap_ok)
         due = true;
      else if(material_due && min_gap_ok)
         due = true;
      else if(checkpoint_due && material_due)
         due = true;

      if(!due)
         continue;

      long uptime_sec = 0;
      if(g_init_server_time > 0 && g_schedule.now_server_time >= g_init_server_time)
         uptime_sec = (long)g_schedule.now_server_time - (long)g_init_server_time;

      bool startup_phase = (uptime_sec < InpStartupGraceSec);

      if(startup_phase && !material_due)
         continue;

      if(SaveSymbolPersistence(g_universe.records[idx]))
         g_persist_writes_this_minute++;
     }
  }

  
void LoadSessions(SymbolRecord &rec)
  {
   ResetSessionState(rec.session_state);
g_dbg_session_load_calls++;

   bool any_loaded = false;
   bool truncated  = false;

   for(int day = 0; day < DAYS_PER_WEEK; day++)
     {
      datetime extra_from_q = 0;
      datetime extra_to_q   = 0;
      datetime extra_from_t = 0;
      datetime extra_to_t   = 0;

      bool extra_quote = SymbolInfoSessionQuote(rec.raw_symbol, (ENUM_DAY_OF_WEEK)day, MAX_SESSIONS_PER_DAY, extra_from_q, extra_to_q);
      bool extra_trade = SymbolInfoSessionTrade(rec.raw_symbol, (ENUM_DAY_OF_WEEK)day, MAX_SESSIONS_PER_DAY, extra_from_t, extra_to_t);

      if(extra_quote || extra_trade)
         truncated = true;

      for(int slot = 0; slot < MAX_SESSIONS_PER_DAY; slot++)
        {
         datetime from_q = 0;
         datetime to_q   = 0;
         datetime from_t = 0;
         datetime to_t   = 0;

         bool got_q = SymbolInfoSessionQuote(rec.raw_symbol, (ENUM_DAY_OF_WEEK)day, slot, from_q, to_q);
         bool got_t = SymbolInfoSessionTrade(rec.raw_symbol, (ENUM_DAY_OF_WEEK)day, slot, from_t, to_t);

         if(got_q)
           {
            int idxq = FlatSessionIndex(day, slot);
            rec.session_state.quote_sessions[idxq].active     = true;
            rec.session_state.quote_sessions[idxq].start_hhmm = HHMMFromSeconds((int)from_q);
            rec.session_state.quote_sessions[idxq].end_hhmm   = HHMMFromSeconds((int)to_q);
            rec.session_state.quote_session_count[day]++;
            any_loaded = true;
           }

         if(got_t)
           {
            int idxt = FlatSessionIndex(day, slot);
            rec.session_state.trade_sessions[idxt].active     = true;
            rec.session_state.trade_sessions[idxt].start_hhmm = HHMMFromSeconds((int)from_t);
            rec.session_state.trade_sessions[idxt].end_hhmm   = HHMMFromSeconds((int)to_t);
            rec.session_state.trade_session_count[day]++;
            any_loaded = true;
           }
        }
     }

   rec.session_state.sessions_loaded    = any_loaded;
   rec.session_state.sessions_truncated = truncated;

   if(any_loaded)
     {
      rec.session_state.fallback_used      = false;
      rec.session_state.session_source     = PV_OBSERVED;
      rec.session_state.session_confidence = truncated ? 85 : 100;
     }
   else
     {
      bool allow_fallback = false;
      int fallback_conf = 0;

      if(rec.spec_derived.asset_class == AC_FX || rec.spec_derived.asset_class == AC_CRYPTO)
        {
         allow_fallback = true;
         fallback_conf = 60;
        }
      else if(rec.spec_derived.asset_class == AC_METAL || rec.spec_derived.asset_class == AC_INDEX)
        {
         allow_fallback = true;
         fallback_conf = 35;
        }

      if(allow_fallback)
        {
         rec.session_state.fallback_used      = true;
         rec.session_state.session_source     = PV_FALLBACK;
         rec.session_state.session_confidence = fallback_conf;
        }
      else
        {
         rec.session_state.fallback_used      = false;
         rec.session_state.session_source     = PV_NONE;
         rec.session_state.session_confidence = 0;
        }
     }

   rec.session_dirty = false;
   rec.continuity.persistence_dirty = true;
   rec.base_dirty = true;
   rec.last_session_refresh_time = g_schedule.now_server_time;
  }

void UpdateSessionOpenState(SymbolRecord &rec)
  {
   rec.session_state.quote_session_open_now = false;
   rec.session_state.trade_session_open_now = false;

   int day = DayOfWeekServer(g_schedule.now_server_time);
   int now_hhmm = HHMMFromDateTime(g_schedule.now_server_time);

   if(rec.session_state.sessions_loaded)
     {
      rec.session_state.quote_session_open_now = IsTimeInsideSessions(rec.session_state.quote_sessions, day, now_hhmm);
      rec.session_state.trade_session_open_now = IsTimeInsideSessions(rec.session_state.trade_sessions, day, now_hhmm);
      return;
     }

   if(rec.session_state.fallback_used)
     {
      if(rec.spec_derived.asset_class == AC_CRYPTO)
        {
         rec.session_state.quote_session_open_now = true;
         rec.session_state.trade_session_open_now = true;
         return;
        }

      if(rec.spec_derived.asset_class == AC_FX ||
         rec.spec_derived.asset_class == AC_METAL ||
         rec.spec_derived.asset_class == AC_INDEX)
        {
         if(day >= 1 && day <= 5)
           {
            rec.session_state.quote_session_open_now = true;
            rec.session_state.trade_session_open_now = true;
           }
        }
     }
  }
  
void UpdateHealthFromSessions(SymbolRecord &rec)
  {
   RecomputeBaseState(rec);
  }
//====================================================================
// 13. Snapshot Tick Engine
//====================================================================
void RunSnapshotBudget()
  {
   int n = g_universe.size;
   if(n <= 0)
      return;

   int work = MathMin(n, MathMax(1, InpSnapshotBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_snapshot;
      g_schedule.cursor_snapshot++;
      if(g_schedule.cursor_snapshot >= n)
         g_schedule.cursor_snapshot = 0;

      if(!g_universe.records[idx].selected_ok)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      if(!g_universe.records[idx].spec_derived.spec_partial)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      if(g_schedule.now_server_time > 0 &&
         g_universe.records[idx].tick_state.next_snapshot_due_server > g_schedule.now_server_time)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      g_universe.records[idx].tick_dirty = false;
      ReadSnapshotTick(g_universe.records[idx]);

      if(g_universe.records[idx].tick_dirty)
        {
         MarkBaseDirty(g_universe.records[idx]);
         g_universe.records[idx].tick_dirty = false;
        }
      else
        {
         RefreshActivityOnly(g_universe.records[idx]);
        }
     }
  }


void ReadSnapshotTick(SymbolRecord &rec)
  {
   g_dbg_snapshot_reads++;

   MqlTick tick;
   ZeroMemory(tick);

   double old_bid      = rec.tick_state.bid;
   double old_ask      = rec.tick_state.ask;
   long   old_time_msc = rec.tick_state.last_tick_time_msc;

   ResetLastError();
   bool ok = SymbolInfoTick(rec.raw_symbol, tick);
   if(!ok)
      return;

   bool has_bid    = (tick.bid > 0.0);
   bool has_ask    = (tick.ask > 0.0);
   bool valid_time = (tick.time > 0);

   if(!valid_time)
      return;

   bool changed_bid  = (old_bid != tick.bid);
   bool changed_ask  = (old_ask != tick.ask);
   bool changed_time = (old_time_msc != (long)tick.time_msc);
   bool materially_changed = (changed_bid || changed_ask || changed_time);

   if(has_bid || has_ask)
     {
      rec.tick_state.tick_valid                   = true;
      rec.tick_state.last_tick_time               = (long)tick.time;
      rec.tick_state.last_tick_time_msc           = (long)tick.time_msc;
      rec.tick_state.last_snapshot_seen_msc       = (long)tick.time_msc;
      rec.tick_state.last_meaningful_snapshot_msc = (long)tick.time_msc;
      rec.tick_state.snapshot_path_ok             = true;
      rec.tick_state.bid                          = tick.bid;
      rec.tick_state.ask                          = tick.ask;

      if(has_bid && has_ask)
        {
         rec.tick_state.mid = 0.5 * (tick.bid + tick.ask);

         if(IsKnownNumber(rec.spec_observed.point) && rec.spec_observed.point > 0.0)
            rec.tick_state.spread_points = (tick.ask - tick.bid) / rec.spec_observed.point;
        }
      else if(has_bid)
        {
         rec.tick_state.mid = tick.bid;
        }
      else if(has_ask)
        {
         rec.tick_state.mid = tick.ask;
        }

      if(materially_changed)
        {
         rec.cost_dirty = true;
         rec.tick_dirty = true;
         rec.base_dirty = true;

         // snapshot churn is live truth, not restart continuity
         // do NOT dirty persistence on ordinary bid/ask/time updates
        
        }     
     }
  }

void UpdateHealthFromSnapshot(SymbolRecord &rec)
  {
   RecomputeBaseState(rec);
  }

//====================================================================
// 13A. CopyTicks Engine
//====================================================================
void RunCostBudget()
  {
   int n = g_universe.size;
   if(n <= 0)
      return;

   int work = MathMin(n, MathMax(1, InpCostBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_cost;
      g_schedule.cursor_cost++;

      if(g_schedule.cursor_cost >= n)
         g_schedule.cursor_cost = 0;

      if(!g_universe.records[idx].selected_ok)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      if(!g_universe.records[idx].spec_derived.spec_partial)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      bool due = false;

      if(g_universe.records[idx].cost_dirty)
         due = true;
      else if(g_universe.records[idx].last_cost_refresh_time <= 0)
         due = true;
      else if((g_schedule.now_server_time - g_universe.records[idx].last_cost_refresh_time) >= MathMax(1, InpCostRefreshSec))
         due = true;

      if(!due)
        {
         g_dbg_recompute_base_skip_calls++;
         continue;
        }

      UpdateHydration3A(g_universe.records[idx]);
      ComputeSymbolCapabilityState(g_universe.records[idx]);
      ComputeSymbolCostState(g_universe.records[idx]);
      g_universe.records[idx].last_cost_refresh_time = g_schedule.now_server_time;
      g_universe.records[idx].cost_dirty = false;
      ComputeSymbolHealthPhase3(g_universe.records[idx]);
     }
  }
  
void RecountCoverage()
  {
   int n = g_universe.size;

   g_selected_count        = 0;
   g_spec_ready_count      = 0;
   g_session_ready_count   = 0;
   g_tick_ready_count      = 0;
   g_history_ready_count   = 0;
   g_both_path_ready_count = 0;
   g_active_symbol_count   = 0;
   g_closed_symbol_count   = 0;
   g_dormant_symbol_count  = 0;
   g_cost_ready_count      = 0;
   g_cost_usable_count     = 0;
   g_coverage_cursor       = 0;

   if(n <= 0)
      return;

   for(int idx = 0; idx < n; idx++)
     {
      if(g_universe.records[idx].selected_ok)
         g_selected_count++;

      if(g_universe.records[idx].health.spec_ready)
         g_spec_ready_count++;

      if(g_universe.records[idx].health.session_ready)
         g_session_ready_count++;

      if(g_universe.records[idx].tick_state.snapshot_path_ok)
         g_tick_ready_count++;

      if(g_universe.records[idx].tick_state.history_path_ok)
         g_history_ready_count++;

      if(g_universe.records[idx].tick_state.tick_path_mode == TPM_BOTH)
         g_both_path_ready_count++;

      if(g_universe.records[idx].tick_state.activity_class == SAC_ACTIVE)
         g_active_symbol_count++;
      else if(g_universe.records[idx].tick_state.activity_class == SAC_MARKET_CLOSED)
         g_closed_symbol_count++;
      else if(g_universe.records[idx].tick_state.activity_class == SAC_DORMANT)
         g_dormant_symbol_count++;

      if(g_universe.records[idx].cost.cost_state == COST_READY)
         g_cost_ready_count++;

      if(g_universe.records[idx].cost.usable_for_costs)
         g_cost_usable_count++;
     }
  }

void RecountCoverage3A()
  {
   for(int i = 0; i < 11; i++)
      g_sector_counts[i] = 0;

   g_market_open_count         = 0;
   g_market_closed_count       = 0;
   g_expired_or_disabled_count = 0;
   g_dead_quote_count          = 0;
   g_cooled_down_count         = 0;
   g_missing_tick_count        = 0;
   g_missing_spec_count        = 0;
   g_spec_sanity_ok_count      = 0;

   for(int i = 0; i < g_universe.size; i++)
     {
      int sid = ClampInt(g_universe.records[i].hydration3a.sector_id, 0, 10);
      g_sector_counts[sid]++;

      if(g_universe.records[i].hydration3a.market_open_now)
         g_market_open_count++;
      else
         g_market_closed_count++;

      if(g_universe.records[i].hydration3a.expired_or_disabled)
         g_expired_or_disabled_count++;

      if(g_universe.records[i].hydration3a.dead_quote)
         g_dead_quote_count++;

      if(g_universe.records[i].hydration3a.cooled_down_until > g_schedule.now_server_time &&
         g_universe.records[i].hydration3a.cooled_down_until > 0)
         g_cooled_down_count++;

      if(!g_universe.records[i].tick_state.snapshot_path_ok &&
         g_universe.records[i].hydration3a.market_open_now)
         g_missing_tick_count++;

      if(!g_universe.records[i].spec_derived.spec_min_ready)
         g_missing_spec_count++;

      if(g_universe.records[i].hydration3a.spec_sanity_ok)
         g_spec_sanity_ok_count++;
     }
  }

void RunCopyTicksBudget()
  {
   int n = g_universe.size;
   if(n <= 0)
      return;

   int work = MathMax(1, MathMin(n, InpCopyTicksBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_copyticks;
      g_schedule.cursor_copyticks++;

      if(g_schedule.cursor_copyticks >= n)
         g_schedule.cursor_copyticks = 0;

      // refresh activity state before scheduling decisions
      RefreshActivityOnly(g_universe.records[idx]);

      // skip if not eligible yet
      if(!g_universe.records[idx].tick_state.copyticks_eligible_now)
         continue;

      CopyTicksForSymbol(g_universe.records[idx]);
      MarkBaseDirty(g_universe.records[idx]);
     }
  }

void CopyTicksForSymbol(SymbolRecord &rec)
  {
   g_dbg_copyticks_calls++;

   if(g_schedule.now_server_time != 0 && rec.tick_state.copyticks_cooldown_until > g_schedule.now_server_time)
     {
      rec.tick_state.copyticks_phase = CT_COOLDOWN;
      rec.tick_state.next_copyticks_due_server = rec.tick_state.copyticks_cooldown_until;
      return;
     }

   CopyTicksPhase prev_phase = rec.tick_state.copyticks_phase;

   if(rec.tick_state.copyticks_phase == CT_NOT_STARTED)
      AddSymbolEvent(rec, EVT_COPYTICKS_START, INVALID_TIME_MSC);

   long prev_last_copied = rec.tick_state.last_copied_msc;

   MqlTick ticks[];
   ArrayResize(ticks, 0);

   uint flags = COPY_TICKS_INFO | COPY_TICKS_TRADE;
   ulong from_msc = 0;
   if(rec.tick_state.last_copied_msc > 0)
      from_msc = (ulong)rec.tick_state.last_copied_msc;

   int fetch_count = MathMax(1, InpCopyTicksFetchPerSymbol);

   ResetLastError();
   int copied = (int)CopyTicks(rec.raw_symbol, ticks, flags, from_msc, fetch_count);

   rec.tick_state.history_last_batch_count = 0;

   if(copied <= 0)
  {
   if(rec.tick_state.activity_class == SAC_MARKET_CLOSED || rec.tick_state.activity_class == SAC_DORMANT)
     {
      rec.tick_state.copyticks_fail_count = 0;

      if(rec.tick_state.ring_count > 0)
         rec.tick_state.copyticks_phase = CT_STEADY;
      else
         rec.tick_state.copyticks_phase = CT_NOT_STARTED;

      bool has_any_tick_evidence =
         (rec.tick_state.last_tick_time > 0 ||
          rec.tick_state.last_snapshot_seen_msc > 0 ||
          rec.tick_state.last_meaningful_history_msc > 0 ||
          rec.tick_state.ring_count > 0);

      int retry_sec = InpCopyTicksUnknownRecheckSec;

      if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
        {
         retry_sec = InpCopyTicksClosedRecheckSec;
        }
      else if(rec.tick_state.activity_class == SAC_DORMANT)
        {
         // Only use very long dormant delay if we have real evidence this symbol is actually dormant.
         retry_sec = has_any_tick_evidence
                     ? InpCopyTicksDormantRecheckSec
                     : InpCopyTicksUnknownRecheckSec;
        }

      rec.tick_state.next_copyticks_due_server = g_schedule.now_server_time + MathMax(1, retry_sec);
      return;
     }

   rec.tick_state.copyticks_fail_count++;

      if(rec.tick_state.copyticks_fail_count >= 3)
        {
         CopyTicksPhase old_phase = rec.tick_state.copyticks_phase;
         datetime old_cooldown_until = rec.tick_state.copyticks_cooldown_until;

         rec.tick_state.copyticks_phase = CT_COOLDOWN;
         rec.base_dirty = true;
         rec.tick_state.copyticks_cooldown_until = g_schedule.now_server_time + MathMax(1, InpCopyTicksCooldownSec);
         rec.tick_state.next_copyticks_due_server = rec.tick_state.copyticks_cooldown_until;
         AddSymbolEvent(rec, EVT_COPYTICKS_COOLDOWN_ENTER, INVALID_TIME_MSC);

         if(old_phase != rec.tick_state.copyticks_phase ||
            old_cooldown_until != rec.tick_state.copyticks_cooldown_until)
            rec.continuity.persistence_dirty = true;
        }
      else
        {
         rec.tick_state.copyticks_phase = CT_FAILING;
         rec.base_dirty = true;

         int retry_sec = InpCopyTicksUnknownRecheckSec;
         if(rec.tick_state.activity_class == SAC_ACTIVE)
            retry_sec = InpCopyTicksActiveRecheckSec;
         else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
            retry_sec = InpCopyTicksClosedRecheckSec;
         else if(rec.tick_state.activity_class == SAC_DORMANT)
            retry_sec = InpCopyTicksDormantRecheckSec;

         rec.tick_state.next_copyticks_due_server = g_schedule.now_server_time + MathMax(1, retry_sec);
         AddSymbolEvent(rec, EVT_COPYTICKS_FAIL, INVALID_TIME_MSC);
        }

      return;
     }

   SortTicksAscending(ticks);

   int accepted = 0;
   long max_seen_msc = rec.tick_state.last_copyticks_seen_msc;

   if(prev_last_copied <= 0)
     {
      rec.tick_state.copyticks_phase = CT_FIRST_SYNC;
      AddSymbolEvent(rec, EVT_COPYTICKS_FIRST_SYNC, INVALID_TIME_MSC);
     }

   for(int i = 0; i < copied; i++)
     {
      if((long)ticks[i].time_msc <= 0)
         continue;

      if(rec.tick_state.last_copied_msc > 0 && (long)ticks[i].time_msc < rec.tick_state.last_copied_msc)
         continue;

      if((long)ticks[i].time_msc > max_seen_msc)
         max_seen_msc = (long)ticks[i].time_msc;

      if(AppendRingTick(rec, ticks[i]))
        {
         accepted++;

         if((long)ticks[i].time_msc > rec.tick_state.last_copied_msc)
            rec.tick_state.last_copied_msc = (long)ticks[i].time_msc;
        }
     }

   rec.tick_state.history_last_batch_count = accepted;

   if(max_seen_msc > rec.tick_state.last_copyticks_seen_msc)
      rec.tick_state.last_copyticks_seen_msc = max_seen_msc;

   if(accepted > 0)
     {
      CopyTicksPhase old_phase = rec.tick_state.copyticks_phase;
      datetime old_cooldown_until = rec.tick_state.copyticks_cooldown_until;
      long old_meaningful_history_msc = rec.tick_state.last_meaningful_history_msc;

      rec.tick_state.copyticks_fail_count = 0;
      rec.tick_state.copyticks_cooldown_until = 0;
      rec.tick_state.last_meaningful_history_msc = rec.tick_state.last_copied_msc;
      rec.tick_dirty = true;
      rec.cost_dirty = true;
      rec.base_dirty = true;

      if(prev_last_copied <= 0)
         rec.tick_state.copyticks_phase = CT_WARM;
      else
         rec.tick_state.copyticks_phase = CT_STEADY;

      bool material_change = false;
      if(old_phase != rec.tick_state.copyticks_phase)
         material_change = true;
      if(old_cooldown_until != rec.tick_state.copyticks_cooldown_until)
         material_change = true;
      if(old_meaningful_history_msc <= 0 ||
         (rec.tick_state.last_meaningful_history_msc - old_meaningful_history_msc) >= InpPersistenceHistoryDeltaMs)
         material_change = true;

      if(material_change)
         rec.continuity.persistence_dirty = true;

      if(prev_phase == CT_FAILING || prev_phase == CT_COOLDOWN)
         AddSymbolEvent(rec, EVT_COPYTICKS_RECOVER, rec.tick_state.last_copied_msc);

      AddSymbolEvent(rec, EVT_COPYTICKS_APPEND, rec.tick_state.last_copied_msc);

      if(CanBeHistoryReady(rec.tick_state.copyticks_phase))
         AddSymbolEvent(rec, EVT_HISTORY_READY, rec.tick_state.last_copied_msc);

      rec.tick_state.active_watch_due_server = g_schedule.now_server_time + MathMax(1, InpCopyTicksActiveRecheckSec);
      rec.tick_state.next_copyticks_due_server = rec.tick_state.active_watch_due_server;
     }
   else
     {
      if(prev_last_copied > 0 && rec.tick_state.ring_count > 0)
        {
         if(rec.tick_state.copyticks_phase == CT_WARM || rec.tick_state.copyticks_phase == CT_FIRST_SYNC)
            rec.tick_state.copyticks_phase = CT_STEADY;
        }
      else
        {
         if(rec.tick_state.copyticks_phase == CT_FIRST_SYNC)
           {
            rec.tick_state.copyticks_phase = CT_WARM;
            rec.base_dirty = true;
           }
         else if(rec.tick_state.copyticks_phase == CT_STEADY)
           {
            rec.tick_state.copyticks_phase = CT_DEGRADED;
            rec.base_dirty = true;
           }
         else if(rec.tick_state.copyticks_phase == CT_FAILING)
           {
            rec.tick_state.copyticks_phase = CT_DEGRADED;
            rec.base_dirty = true;
           }
        }

      int retry_sec = InpCopyTicksUnknownRecheckSec;
      if(rec.tick_state.activity_class == SAC_ACTIVE)
         retry_sec = InpCopyTicksActiveRecheckSec;
      else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
         retry_sec = InpCopyTicksClosedRecheckSec;
      else if(rec.tick_state.activity_class == SAC_DORMANT)
         retry_sec = InpCopyTicksDormantRecheckSec;

      rec.tick_state.next_copyticks_due_server = g_schedule.now_server_time + MathMax(1, retry_sec);
     }
  }

bool IsRecentServerTickTime(const long tick_time_sec, const int fresh_sec)
  {
   if(g_schedule.now_server_time <= 0 || tick_time_sec <= 0 || fresh_sec <= 0)
      return false;

   long delta = (long)g_schedule.now_server_time - tick_time_sec;
   if(delta < 0)
      return false;

   return (delta <= fresh_sec);
  }

bool IsRecentServerTickTimeMsc(const long tick_time_msc, const int fresh_sec)
  {
   if(tick_time_msc <= 0 || fresh_sec <= 0)
      return false;

   return IsRecentServerTickTime((long)(tick_time_msc / 1000), fresh_sec);
  }

bool IsCopyTicksDueNow(const SymbolRecord &rec)
  {
   // Bootstrap rule:
   // If we have never attempted CopyTicks and have no snapshot/history evidence yet,
   // allow one immediate attempt.
   if(rec.tick_state.copyticks_phase == CT_NOT_STARTED &&
      rec.selected_ok &&
      rec.spec_derived.spec_partial &&
      rec.tick_state.last_tick_time <= 0 &&
      rec.tick_state.last_meaningful_history_msc <= 0 &&
      rec.tick_state.ring_count == 0)
      return true;

   if(g_schedule.now_server_time <= 0)
      return true;

   if(rec.tick_state.copyticks_cooldown_until > g_schedule.now_server_time)
      return false;

   if(rec.tick_state.next_copyticks_due_server <= 0)
      return true;

   return (rec.tick_state.next_copyticks_due_server <= g_schedule.now_server_time);
  }

void RefreshActivityOnly(SymbolRecord &rec)
  {
   g_dbg_activity_refresh_calls++;
   UpdateSymbolActivityState(rec);
  }

void UpdateSymbolActivityState(SymbolRecord &rec)
  {
   MarketOpenState prev_market_state = rec.tick_state.market_open_state;
   SymbolActivityClass prev_activity = rec.tick_state.activity_class;

   rec.tick_state.market_open_state      = MOS_UNKNOWN;
   rec.tick_state.activity_class         = SAC_UNKNOWN;
   rec.tick_state.copyticks_eligible_now = false;

   bool snapshot_recent = IsRecentServerTickTime(rec.tick_state.last_tick_time, InpActiveSnapshotFreshSec);
   bool history_recent  = IsRecentServerTickTimeMsc(rec.tick_state.last_meaningful_history_msc, InpActiveSnapshotFreshSec);
   bool has_recent_quote = (snapshot_recent || history_recent);

   bool has_any_tick_evidence =
      (rec.tick_state.last_tick_time > 0 ||
       rec.tick_state.last_snapshot_seen_msc > 0 ||
       rec.tick_state.last_meaningful_history_msc > 0 ||
       rec.tick_state.ring_count > 0);

   bool sessions_observed = rec.session_state.sessions_loaded;
   bool sessions_fallback = rec.session_state.fallback_used;
   bool session_open_now  = (rec.session_state.quote_session_open_now || rec.session_state.trade_session_open_now);

   if(rec.spec_derived.tradability_class == TC_DISABLED)
     {
      rec.tick_state.market_open_state = MOS_CLOSED_NOW;
     }
   else if(has_recent_quote)
     {
      rec.tick_state.market_open_state = MOS_OPEN_NOW;
     }
   else if(sessions_observed)
     {
      rec.tick_state.market_open_state = (session_open_now ? MOS_OPEN_NOW : MOS_CLOSED_NOW);
     }
   else if(sessions_fallback && has_any_tick_evidence)
     {
      rec.tick_state.market_open_state = (session_open_now ? MOS_OPEN_NOW : MOS_CLOSED_NOW);
     }
   else
     {
      rec.tick_state.market_open_state = MOS_UNKNOWN;
     }

   if(has_recent_quote)
      rec.tick_state.activity_class = SAC_ACTIVE;
   else if(rec.tick_state.market_open_state == MOS_CLOSED_NOW)
      rec.tick_state.activity_class = SAC_MARKET_CLOSED;
   else
      rec.tick_state.activity_class = SAC_DORMANT;

   if(g_schedule.now_server_time <= 0)
     {
      rec.tick_state.copyticks_eligible_now = true;
      rec.tick_state.next_snapshot_due_server = 0;
      return;
     }

   if(rec.tick_state.activity_class == SAC_ACTIVE)
     {
      rec.tick_state.next_snapshot_due_server = g_schedule.now_server_time;
     }
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
     {
      if(rec.tick_state.next_snapshot_due_server <= 0 ||
         prev_activity != SAC_MARKET_CLOSED ||
         prev_market_state != MOS_CLOSED_NOW)
         rec.tick_state.next_snapshot_due_server = g_schedule.now_server_time + MathMax(1, InpSnapshotClosedRecheckSec);
     }
   else
     {
      if(rec.tick_state.next_snapshot_due_server <= 0 ||
         prev_activity != SAC_DORMANT)
         rec.tick_state.next_snapshot_due_server = g_schedule.now_server_time + MathMax(1, InpSnapshotClosedRecheckSec);
     }

   string key = rec.normalized_symbol;
   if(key == "")
      key = rec.raw_symbol;

   int hash = 0;
   int key_len = StringLen(key);
   for(int i = 0; i < key_len; i++)
     {
      hash = (hash * 131 + StringGetCharacter(key, i)) & 0x7fffffff;
     }

   int closed_spread  = 0;
   int dormant_spread = 0;

   int closed_window = MathMax(1, InpCopyTicksClosedRecheckSec);
   if(closed_window > 1)
      closed_spread = hash % closed_window;

   int dormant_window = MathMax(1, InpCopyTicksDormantRecheckSec);
   if(dormant_window > 1)
      dormant_spread = hash % dormant_window;

   if(rec.tick_state.activity_class == SAC_ACTIVE)
     {
      if(prev_activity != SAC_ACTIVE || rec.tick_state.active_watch_due_server <= 0)
         rec.tick_state.active_watch_due_server = g_schedule.now_server_time;

      rec.tick_state.next_copyticks_due_server = rec.tick_state.active_watch_due_server;
     }
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
     {
      if(prev_activity != SAC_MARKET_CLOSED || prev_market_state != MOS_CLOSED_NOW || rec.tick_state.reopen_watch_due_server <= 0)
         rec.tick_state.reopen_watch_due_server = g_schedule.now_server_time + 1 + closed_spread;

      rec.tick_state.next_copyticks_due_server = rec.tick_state.reopen_watch_due_server;
     }
   else
     {
      if(prev_activity != SAC_DORMANT || rec.tick_state.dead_watch_due_server <= 0)
         rec.tick_state.dead_watch_due_server = g_schedule.now_server_time + 1 + dormant_spread;

      rec.tick_state.next_copyticks_due_server = rec.tick_state.dead_watch_due_server;
     }

   rec.tick_state.copyticks_eligible_now = IsCopyTicksDueNow(rec);
  }

//====================================================================
// 14. HUD Renderer
//====================================================================
void RenderHUD()
  {
   string text = "";

   text += EA_NAME + " " + EA_BUILD_CHANNEL + "\n";
   text += "Server: " + DateTimeToMinuteStr(g_schedule.now_server_time) + "\n";
   text += "Universe: " + IntegerToString(g_universe.size) + "\n";
   text += "Selected: " + IntegerToString(g_selected_count) + "\n";
   text += "Spec Ready: " + IntegerToString(g_spec_ready_count) + "\n";
   text += "Snapshot Ready: " + IntegerToString(g_tick_ready_count) + "\n";
   text += "History Ready: " + IntegerToString(g_history_ready_count) + "\n";
   text += "Cost Ready: " + IntegerToString(g_cost_ready_count) + "\n";
   text += "Open: " + IntegerToString(g_market_open_count) + "\n";
   text += "Closed: " + IntegerToString(g_market_closed_count) + "\n";
   text += "Dead Quote: " + IntegerToString(g_dead_quote_count) + "\n";
   text += "PerfWarn: " + BoolTo01(g_perf.perf_warn) + "\n";
   text += "Stage OK: " + BoolTo01(g_publish_stage.ok) + "\n";
   text += "Debug OK: " + BoolTo01(g_publish_debug.ok) + "\n";
   text += "Firm: " + g_firm_id + "\n";
   text += "Worst:\n" + BuildWorstSymbolsText();

   Comment(text);
  }

string BuildWorstSymbolsText()
  {
   int worst_idx[];
   int worst_score[];
   BuildWorstSymbolLists(worst_idx, worst_score);

   int rows = MathMin(MathMin(ArraySize(worst_idx), MathMax(1, InpWorstRows)), HUD_WORST_LIMIT);
   if(rows <= 0)
      return "None\n";

   string out = "";
   for(int j = 0; j < rows; j++)
     {
      int idx = worst_idx[j];
      out += g_universe.records[idx].raw_symbol;
      out += " | ";
      out += SymbolStateToString(g_universe.records[idx].health.state);
      out += " | ";
      out += ReasonCodeToString(g_universe.records[idx].health.reason);
      out += " | ";
      out += SymbolActivityClassToString(g_universe.records[idx].tick_state.activity_class);
      out += " | ";
      out += TickPathModeToString(g_universe.records[idx].tick_state.tick_path_mode);
      out += " | CT=" + CopyTicksPhaseToString(g_universe.records[idx].tick_state.copyticks_phase);
      out += "\n";
     }

   return out;
  }

//====================================================================
// 15. Helper Utilities
//====================================================================

string SanitizeFirmName(string s)
  {
   string out = s;

   StringTrimLeft(out);
   StringTrimRight(out);

   StringReplace(out, "\\", "_");
   StringReplace(out, "/", "_");
   StringReplace(out, ":", "_");
   StringReplace(out, "*", "_");
   StringReplace(out, "?", "_");
   StringReplace(out, "\"", "_");
   StringReplace(out, "<", "_");
   StringReplace(out, ">", "_");
   StringReplace(out, "|", "_");
   StringReplace(out, " ", "_");

   while(StringLen(out) > 0)
     {
      string tail = StringSubstr(out, StringLen(out) - 1, 1);
      if(tail == "." || tail == "_" || tail == " ")
         out = StringSubstr(out, 0, StringLen(out) - 1);
      else
         break;
     }

   if(out == "")
      out = "UNKNOWN_FIRM";

   return out;
  }

bool ProbeMarginOneLot(SymbolRecord &rec, double &buy_margin, double &sell_margin)
  {
  g_dbg_margin_probe_calls++;
   buy_margin = INVALID_DBL;
   sell_margin = INVALID_DBL;

   if(!rec.selected_ok)
      return false;

   double price_buy = rec.tick_state.ask;
   double price_sell = rec.tick_state.bid;

   if(price_buy <= 0.0 && rec.tick_state.bid > 0.0)
      price_buy = rec.tick_state.bid;

   if(price_sell <= 0.0 && rec.tick_state.ask > 0.0)
      price_sell = rec.tick_state.ask;

   if(price_buy <= 0.0 || price_sell <= 0.0)
      return false;

   double out_margin = 0.0;
   bool ok_buy = OrderCalcMargin(ORDER_TYPE_BUY, rec.raw_symbol, 1.0, price_buy, out_margin);
   if(ok_buy)
      buy_margin = out_margin;

   out_margin = 0.0;
   bool ok_sell = OrderCalcMargin(ORDER_TYPE_SELL, rec.raw_symbol, 1.0, price_sell, out_margin);
   if(ok_sell)
      sell_margin = out_margin;

   return (ok_buy || ok_sell);
  }

string BuildSymbolMarketStatusJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"quote_session_open\":" + JsonBool(rec.hydration3a.quote_session_open) + ",";
   s += "\"trade_session_open\":" + JsonBool(rec.hydration3a.trade_session_open) + ",";
   s += "\"market_open_now\":" + JsonBool(rec.hydration3a.market_open_now) + ",";
   s += "\"reason_code\":" + IntegerToString(rec.hydration3a.reason_code_3a) + ",";
   s += "\"last_tick_time\":" + JsonLongOrNull(rec.tick_state.last_tick_time) + ",";
   s += "\"hydration_attempts\":" + IntegerToString(rec.hydration3a.hydration_attempts) + ",";
   s += "\"cooled_down_until\":" + JsonDateTimeOrNull(rec.hydration3a.cooled_down_until);
   s += "}";
   return s;
  }

string BuildReasonCode3ALegendJson()
  {
   string s = "{";
   s += "\"0\":\"ok\",";
   s += "\"1\":\"warming_up\",";
   s += "\"2\":\"market_closed\",";
   s += "\"3\":\"trade_disabled\",";
   s += "\"4\":\"quote_unavailable\",";
   s += "\"5\":\"expired_or_delisted\",";
   s += "\"6\":\"hydration_timeout\",";
   s += "\"7\":\"cooled_down\"";
   s += "}";
   return s;
  }

string BuildSectorLegendJson()
  {
   string s = "{";
   s += "\"0\":\"fx_major\",";
   s += "\"1\":\"fx_minor\",";
   s += "\"2\":\"fx_exotic\",";
   s += "\"3\":\"metals\",";
   s += "\"4\":\"indices\",";
   s += "\"5\":\"energy\",";
   s += "\"6\":\"commodities\",";
   s += "\"7\":\"crypto\",";
   s += "\"8\":\"stocks\",";
   s += "\"9\":\"rates\",";
   s += "\"10\":\"other\"";
   s += "}";
   return s;
  }

string BuildTradeModeLegendJson()
  {
   string s = "{";
   s += "\"0\":\"disabled\",";
   s += "\"1\":\"longonly\",";
   s += "\"2\":\"shortonly\",";
   s += "\"3\":\"closeonly\",";
   s += "\"4\":\"full\"";
   s += "}";
   return s;
  }

string BuildLegendsJson()
  {
   string s = "{";
   s += "\"reason_code_3a\":" + BuildReasonCode3ALegendJson() + ",";
   s += "\"sector_id\":" + BuildSectorLegendJson() + ",";
   s += "\"trade_mode\":" + BuildTradeModeLegendJson();
   s += "}";
   return s;
  }

string JsonEscape(const string s)
  {
   string out = s;
   StringReplace(out, "\\", "\\\\");
   StringReplace(out, "\"", "\\\"");
   StringReplace(out, "\r", "\\r");
   StringReplace(out, "\n", "\\n");
   StringReplace(out, "\t", "\\t");
   return out;
  }

string JsonBool(const bool v)     { return v ? "true" : "false"; }
string JsonInt(const int v)       { return IntegerToString(v); }
string JsonLong(const long v)     { return StringFormat("%I64d", v); }
string JsonString(const string s) { return "\"" + JsonEscape(s) + "\""; }

string JsonDouble6(const double v)
  {
   return DoubleToString(v, 6);
  }

string JsonDoubleOrNull6(const double v)
  {
   if(!IsKnownNumber(v))
      return "null";
   return DoubleToString(v, 6);
  }

string JsonDateTime(const datetime v)
  {
   return JsonString(TimeToString(v, TIME_DATE | TIME_SECONDS));
  }

string JsonDateTimeOrNull(const datetime v)
  {
   if(v <= 0)
      return "null";
   return JsonDateTime(v);
  }

string JsonLongOrNull(const long v)
  {
   if(v <= 0 || v == INVALID_TIME_MSC)
      return "null";
   return JsonLong(v);
  }
  
  uint FNV1a32(const string s)
  {
   uint h = 2166136261;
   int n = StringLen(s);

   for(int i = 0; i < n; i++)
     {
      uint c = (uint)StringGetCharacter(s, i);
      h ^= c;
      h *= 16777619;
     }

   return h;
  }

string FNV1a32Hex(const string s)
  {
   uint h = FNV1a32(s);
   return StringFormat("%08X", h);
  }
  
  long GetMinuteId(const datetime t)
  {
   if(t <= 0)
      return -1;
   return (long)(t / 60);
  }

bool BestEffortPreservePrevious(const string current_rel, const string prev_rel)
  {
   if(!FileIsExist(current_rel, FILE_COMMON))
      return false;

   if(FileIsExist(prev_rel, FILE_COMMON))
      FileDelete(prev_rel, FILE_COMMON);

   ResetLastError();
   if(FileCopy(current_rel, FILE_COMMON, prev_rel, FILE_COMMON))
     {
      g_io_last.copy_err   = 0;
      g_io_last.delete_err = 0;
      g_io_counters.io_ok_count++;
      return true;
     }
     
   g_io_last.copy_err = GetLastError();
   g_io_counters.io_fail_count++;
   return false;
  }

string BuildUniverseFingerprint()
  {
   string acc = "";
   for(int i = 0; i < g_universe.size; i++)
     {
      if(i > 0)
         acc += "|";
      acc += g_universe.records[i].raw_symbol;
     }
   return FNV1a32Hex(acc);
  }

string BuildPersistenceFilePath(const SymbolRecord &rec)
  {
   return g_persistence_dir_ea1 + BuildSymbolIdentityHash(rec) + ".bin";
  }

string BuildPersistenceBackupPath(const SymbolRecord &rec)
  {
   return g_persistence_dir_ea1 + BuildSymbolIdentityHash(rec) + ".bak";
  }

string BuildSymbolIdentityHash(const SymbolRecord &rec)
  {
   string basis = g_firm_id + "|" + rec.raw_symbol + "|" + rec.normalized_symbol;
   return FNV1a32Hex(basis);
  }

bool IsPublishWindowOpen(const datetime t, const int offset_sec, const int window_sec)
  {
   if(t <= 0)
      return false;

   int sec_in_min = (int)(t % 60);
   return (sec_in_min >= offset_sec && sec_in_min < offset_sec + window_sec);
  }

bool PublishLockExists()
  {
   if(!InpEnablePublishLock)
      return false;

   string lock_path = g_locks_dir + "publish.lock";
   return FileIsExist(lock_path, FILE_COMMON);
  }
  
  bool WriteBinString(const int h, const string s)
  {
   int len = StringLen(s);
   FileWriteInteger(h, len, INT_VALUE);
   if(len > 0)
      FileWriteString(h, s, len);
   return true;
  }

bool ReadBinString(const int h, string &s)
  {
   s = "";

   if(FileIsEnding(h))
      return false;

   int len = FileReadInteger(h, INT_VALUE);
   if(len < 0 || len > 4096)
      return false;

   if(len == 0)
     {
      s = "";
      return true;
     }

   s = FileReadString(h, len);
   return (StringLen(s) == len);
  }

bool WriteBinBool(const int h, const bool v)
{
   FileWriteInteger(h, v ? 1 : 0, CHAR_VALUE);
   return true;
}

bool ReadBinBool(const int h, bool &v)
{
   if(FileIsEnding(h))
      return false;
   v = (FileReadInteger(h, CHAR_VALUE) != 0);
   return true;
}

bool WriteBinDateTime(const int h, const datetime v)
{
   FileWriteLong(h, (long)v);
   return true;
}

bool ReadBinDateTime(const int h, datetime &v)
{
   if(FileIsEnding(h))
      return false;
   v = (datetime)FileReadLong(h);
   return true;
}

bool WriteBinDouble(const int h, const double v)
{
   FileWriteDouble(h, v);
   return true;
}

bool ReadBinDouble(const int h, double &v)
{
   if(FileIsEnding(h))
      return false;
   v = FileReadDouble(h);
   return true;
}

bool WriteBinLong(const int h, const long v)
{
   FileWriteLong(h, v);
   return true;
}

bool ReadBinLong(const int h, long &v)
{
   if(FileIsEnding(h))
      return false;
   v = FileReadLong(h);
   return true;
}

bool WriteBinInt(const int h, const int v)
{
   FileWriteInteger(h, v, INT_VALUE);
   return true;
}

bool ReadBinInt(const int h, int &v)
{
   if(FileIsEnding(h))
      return false;
   v = FileReadInteger(h, INT_VALUE);
   return true;
}

bool SaveSymbolPersistence(SymbolRecord &rec)
  {
   string final_rel  = BuildPersistenceFilePath(rec);
   string backup_rel = BuildPersistenceBackupPath(rec);
   string tmp_rel    = final_rel + ".tmp";

   int h = FileOpen(tmp_rel, FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      rec.continuity.persistence_state = PTX_SAVE_FAILED;
      rec.continuity.persistence_dirty = true;
      g_persist_save_fail_count++;
      return false;
     }

   bool ok = true;
   datetime save_time = g_schedule.now_server_time;
   string payload_hash = BuildPersistencePayloadHash(rec);

   // header
   ok &= WriteBinInt(h, EA1_PERSIST_SCHEMA_VERSION);
   ok &= WriteBinString(h, EA1_ENGINE_VERSION_STR);
   ok &= WriteBinString(h, EA1_BLUEPRINT_VERSION_STR);
   ok &= WriteBinString(h, BuildSymbolIdentityHash(rec));
   ok &= WriteBinString(h, rec.raw_symbol);
   ok &= WriteBinString(h, rec.normalized_symbol);
   ok &= WriteBinDateTime(h, save_time);

   // compatibility anchor
   ok &= WriteBinString(h, rec.spec_change.spec_hash);

   // core continuity only
   ok &= WriteBinInt(h, (int)rec.tick_state.copyticks_phase);
   ok &= WriteBinLong(h, rec.tick_state.last_snapshot_seen_msc);
   ok &= WriteBinLong(h, rec.tick_state.last_copyticks_seen_msc);
   ok &= WriteBinLong(h, rec.tick_state.last_copied_msc);
   ok &= WriteBinLong(h, rec.tick_state.last_meaningful_snapshot_msc);
   ok &= WriteBinLong(h, rec.tick_state.last_meaningful_history_msc);
   ok &= WriteBinInt(h, rec.tick_state.copyticks_fail_count);
   ok &= WriteBinDateTime(h, rec.tick_state.copyticks_cooldown_until);
   ok &= WriteBinDateTime(h, rec.tick_state.next_copyticks_due_server);
   ok &= WriteBinDateTime(h, rec.tick_state.active_watch_due_server);
   ok &= WriteBinDateTime(h, rec.tick_state.dead_watch_due_server);
   ok &= WriteBinDateTime(h, rec.tick_state.reopen_watch_due_server);

   // keep only a bounded tail of the ring
   int keep = MathMin(rec.tick_state.ring_count, 16);
   ok &= WriteBinInt(h, keep);

   int start = rec.tick_state.ring_head - keep;
   while(start < 0)
      start += TICK_RING_CAPACITY;

   for(int i = 0; i < keep; i++)
     {
      int idx = (start + i) % TICK_RING_CAPACITY;
      ok &= WriteBinLong(h, rec.tick_state.ring[idx].time_msc);
      ok &= WriteBinDouble(h, rec.tick_state.ring[idx].bid);
      ok &= WriteBinDouble(h, rec.tick_state.ring[idx].ask);
      ok &= WriteBinDouble(h, rec.tick_state.ring[idx].last);
      ok &= WriteBinDouble(h, rec.tick_state.ring[idx].volume_real);
      ok &= WriteBinLong(h, (long)rec.tick_state.ring[idx].flags);
     }

   // continuity metadata
   ok &= WriteBinDateTime(h, rec.last_spec_refresh_time);
   ok &= WriteBinDateTime(h, rec.last_session_refresh_time);
   ok &= WriteBinDateTime(h, rec.last_cost_refresh_time);
   ok &= WriteBinDateTime(h, rec.last_margin_probe_time);

   FileClose(h);

   if(!ok)
     {
      FileDelete(tmp_rel, FILE_COMMON);
      rec.continuity.persistence_state = PTX_SAVE_FAILED;
      rec.continuity.persistence_dirty = true;
      g_persist_save_fail_count++;
      return false;
     }

   BestEffortPersistenceBackup(final_rel, backup_rel);

   if(FileIsExist(final_rel, FILE_COMMON))
      FileDelete(final_rel, FILE_COMMON);

   if(!FileMove(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      FileDelete(tmp_rel, FILE_COMMON);
      rec.continuity.persistence_state = PTX_SAVE_FAILED;
      rec.continuity.persistence_dirty = true;
      g_persist_save_fail_count++;
      return false;
     }

   rec.continuity.persistence_state = PTX_SAVED_OK;
rec.continuity.persistence_loaded = true;
rec.continuity.persistence_fresh = true;
rec.continuity.persistence_stale = false;
rec.continuity.persistence_corrupt = false;
rec.continuity.persistence_incompatible = false;

// Do NOT change origin semantics here.
// Saving state does not mean this session resumed from persistence.
rec.continuity.restarted_clean = false;
if(rec.continuity.continuity_origin == CO_NONE)
   rec.continuity.continuity_origin = CO_CLEAN;

rec.continuity.persistence_age_sec = 0;
rec.continuity.last_persistence_save_time = save_time;
rec.continuity.continuity_last_good_server_time = save_time;
rec.continuity.persistence_dirty = false;
rec.continuity.loaded_once = true;

   rec.continuity.last_saved_history_msc = rec.tick_state.last_meaningful_history_msc;
   rec.continuity.last_saved_copyticks_phase = (int)rec.tick_state.copyticks_phase;
   rec.continuity.last_saved_payload_hash = payload_hash;

   g_persist_save_ok_count++;
   return true;
  }

bool LoadSymbolPersistence(SymbolRecord &rec)
  {
   ResetContinuityState(rec.continuity);
   rec.continuity.loaded_once = true;

   string final_rel  = BuildPersistenceFilePath(rec);
   string backup_rel = BuildPersistenceBackupPath(rec);

   string use_path = final_rel;
   if(!FileIsExist(use_path, FILE_COMMON))
     {
      if(FileIsExist(backup_rel, FILE_COMMON))
         use_path = backup_rel;
      else
        {
         rec.continuity.persistence_state = PTX_NOT_FOUND;
         rec.continuity.restarted_clean = true;
         rec.continuity.continuity_origin = CO_CLEAN;
         rec.continuity.persistence_dirty = true;
         return false;
        }
     }

   int h = FileOpen(use_path, FILE_READ | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      rec.continuity.persistence_state = PTX_CORRUPT_DISCARDED;
      rec.continuity.persistence_corrupt = true;
      rec.continuity.restarted_clean = true;
      rec.continuity.continuity_origin = CO_CLEAN;
      rec.continuity.persistence_dirty = true;
      g_persist_corrupt_discard_count++;
      g_persist_load_fail_count++;
      return false;
     }

   bool ok = true;

   int schema_ver = 0;
   string eng_ver = "";
   string bp_ver = "";
   string ident = "";
   string raw = "";
   string norm = "";
   datetime saved_at = 0;
   string persisted_spec_hash = "";

   ok &= ReadBinInt(h, schema_ver);
   ok &= ReadBinString(h, eng_ver);
   ok &= ReadBinString(h, bp_ver);
   ok &= ReadBinString(h, ident);
   ok &= ReadBinString(h, raw);
   ok &= ReadBinString(h, norm);
   ok &= ReadBinDateTime(h, saved_at);

   if(!ok)
     {
      FileClose(h);
      rec.continuity.persistence_state = PTX_CORRUPT_DISCARDED;
      rec.continuity.persistence_corrupt = true;
      rec.continuity.restarted_clean = true;
      rec.continuity.continuity_origin = CO_CLEAN;
      rec.continuity.persistence_dirty = true;
      g_persist_corrupt_discard_count++;
      g_persist_load_fail_count++;
      return false;
     }

   if(schema_ver != EA1_PERSIST_SCHEMA_VERSION ||
      eng_ver != EA1_ENGINE_VERSION_STR ||
      bp_ver != EA1_BLUEPRINT_VERSION_STR ||
      ident != BuildSymbolIdentityHash(rec) ||
      raw != rec.raw_symbol ||
      norm != rec.normalized_symbol)
     {
      FileClose(h);
      rec.continuity.persistence_state = PTX_INCOMPATIBLE_DISCARDED;
      rec.continuity.persistence_incompatible = true;
      rec.continuity.restarted_clean = true;
      rec.continuity.continuity_origin = CO_CLEAN;
      rec.continuity.persistence_dirty = true;
      g_persist_incompat_discard_count++;
      g_persist_load_fail_count++;
      return false;
     }

   int age_sec = 0;
   if(g_init_server_time > 0 && saved_at > 0 && g_init_server_time >= saved_at)
      age_sec = (int)(g_init_server_time - saved_at);

   if(saved_at <= 0 || age_sec > InpPersistenceFreshMaxAgeSec)
     {
      FileClose(h);
      rec.continuity.persistence_state = PTX_STALE_DISCARDED;
      rec.continuity.persistence_stale = true;
      rec.continuity.persistence_age_sec = age_sec;
      rec.continuity.restarted_clean = true;
      rec.continuity.continuity_origin = CO_CLEAN;
      rec.continuity.persistence_dirty = true;
      g_persist_stale_discard_count++;
      g_persist_load_fail_count++;
      return false;
     }

   ResetTickState(rec.tick_state);

ok &= ReadBinString(h, persisted_spec_hash);
// NOTE:
// persisted_spec_hash is intentionally loaded but not yet enforced here.
// Live spec is refreshed later in the normal spec engine, and compatibility
// comparison is deferred until a proper post-refresh reconciliation path exists.

{
   int v = 0;
   ok &= ReadBinInt(h, v);
   rec.tick_state.copyticks_phase = (CopyTicksPhase)v;
}

ok &= ReadBinLong(h, rec.tick_state.last_snapshot_seen_msc);
ok &= ReadBinLong(h, rec.tick_state.last_copyticks_seen_msc);
ok &= ReadBinLong(h, rec.tick_state.last_copied_msc);
ok &= ReadBinLong(h, rec.tick_state.last_meaningful_snapshot_msc);
ok &= ReadBinLong(h, rec.tick_state.last_meaningful_history_msc);
ok &= ReadBinInt(h, rec.tick_state.copyticks_fail_count);
ok &= ReadBinDateTime(h, rec.tick_state.copyticks_cooldown_until);
ok &= ReadBinDateTime(h, rec.tick_state.next_copyticks_due_server);
ok &= ReadBinDateTime(h, rec.tick_state.active_watch_due_server);
ok &= ReadBinDateTime(h, rec.tick_state.dead_watch_due_server);
ok &= ReadBinDateTime(h, rec.tick_state.reopen_watch_due_server);

int keep = 0;
ok &= ReadBinInt(h, keep);
keep = ClampInt(keep, 0, 16);

for(int i = 0; i < keep; i++)
  {
   TickRingItem item;
   item.time_msc = INVALID_TIME_MSC;
   item.bid = 0.0;
   item.ask = 0.0;
   item.last = 0.0;
   item.volume_real = 0.0;
   item.flags = 0;

   long flags_long = 0;
   ok &= ReadBinLong(h, item.time_msc);
   ok &= ReadBinDouble(h, item.bid);
   ok &= ReadBinDouble(h, item.ask);
   ok &= ReadBinDouble(h, item.last);
   ok &= ReadBinDouble(h, item.volume_real);
   ok &= ReadBinLong(h, flags_long);
   item.flags = (uint)flags_long;

   if(ok)
     {
      int idx = rec.tick_state.ring_head;
      rec.tick_state.ring[idx] = item;
      rec.tick_state.ring_head++;
      if(rec.tick_state.ring_head >= TICK_RING_CAPACITY)
         rec.tick_state.ring_head = 0;

      if(rec.tick_state.ring_count < TICK_RING_CAPACITY)
         rec.tick_state.ring_count++;
     }
  }

ok &= ReadBinDateTime(h, rec.last_spec_refresh_time);
ok &= ReadBinDateTime(h, rec.last_session_refresh_time);
ok &= ReadBinDateTime(h, rec.last_cost_refresh_time);
ok &= ReadBinDateTime(h, rec.last_margin_probe_time);

FileClose(h);

if(!ok)
  {
   rec.continuity.persistence_state = PTX_CORRUPT_DISCARDED;
   rec.continuity.persistence_corrupt = true;
   rec.continuity.restarted_clean = true;
   rec.continuity.continuity_origin = CO_CLEAN;
   rec.continuity.persistence_dirty = true;
   g_persist_corrupt_discard_count++;
   g_persist_load_fail_count++;
   return false;
  }

rec.selected_ok = false;
rec.spec_dirty = true;
rec.session_dirty = true;
rec.tick_dirty = true;
rec.cost_dirty = true;

rec.tick_state.tick_valid = false;
rec.tick_state.bid = 0.0;
rec.tick_state.ask = 0.0;
rec.tick_state.mid = 0.0;
rec.tick_state.spread_points = 0.0;

rec.tick_state.snapshot_path_ok = false;
rec.tick_state.history_available =
   (rec.tick_state.ring_count > 0 &&
    CanBeHistoryReady(rec.tick_state.copyticks_phase));
rec.tick_state.history_fresh = false;
rec.tick_state.history_path_ok = false;
rec.tick_state.tick_path_mode = TPM_NONE;

rec.continuity.persistence_state = PTX_LOADED_FRESH;
rec.continuity.persistence_loaded = true;
rec.continuity.persistence_fresh = true;
rec.continuity.persistence_stale = false;
rec.continuity.persistence_corrupt = false;
rec.continuity.persistence_incompatible = false;
rec.continuity.resumed_from_persistence = true;
rec.continuity.restarted_clean = false;
rec.continuity.persistence_age_sec = age_sec;
rec.continuity.continuity_origin = CO_PERSISTENCE;
rec.continuity.continuity_last_good_server_time = saved_at;
rec.continuity.last_persistence_save_time = saved_at;
rec.continuity.persistence_dirty = false;
rec.continuity.last_saved_history_msc = rec.tick_state.last_meaningful_history_msc;
rec.continuity.last_saved_copyticks_phase = (int)rec.tick_state.copyticks_phase;
rec.continuity.last_saved_payload_hash = BuildPersistencePayloadHash(rec);

g_persist_load_ok_count++;

rec.base_dirty = true;
return true;
}

   bool WriteTextFileCommon(const string rel_path, const string content, int &bytes_written)
  {
   bytes_written = 0;

   g_io_last.last_file = rel_path;
   g_io_last.last_op   = IO_OP_WRITE_TMP;
   g_io_last.write_err = 0;

   int handle = FileOpen(rel_path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      g_io_last.open_err = GetLastError();
      g_io_counters.io_fail_count++;
      return false;
     }

   FileWriteString(handle, content);
   bytes_written = (int)FileTell(handle);
   FileClose(handle);

   g_io_last.bytes = bytes_written;
   g_io_counters.io_ok_count++;
   return true;
  }

bool CommitFileAtomic(const string tmp_rel, const string final_rel)
  {
   g_io_last.last_file = final_rel;
   g_io_last.last_op   = IO_OP_MOVE_COMMIT;
   g_io_last.move_err  = 0;
   g_io_last.copy_err  = 0;
   g_io_last.delete_err= 0;

   ResetLastError();
   if(FileMove(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      g_io_last.move_err   = 0;
      g_io_last.copy_err   = 0;
      g_io_last.delete_err = 0;
      g_io_counters.io_ok_count++;
      return true;
     }

   g_io_last.move_err = GetLastError();

   if(FileIsExist(final_rel, FILE_COMMON))
     {
      ResetLastError();
      FileDelete(final_rel, FILE_COMMON);
      g_io_last.delete_err = GetLastError();
     }

   ResetLastError();
   if(FileMove(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      g_io_last.move_err   = 0;
      g_io_last.copy_err   = 0;
      g_io_last.delete_err = 0;
      g_io_counters.io_ok_count++;
      return true;
     }

   g_io_last.move_err = GetLastError();

   g_io_last.last_op = IO_OP_COPY_COMMIT;
   ResetLastError();
   if(FileCopy(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      FileDelete(tmp_rel, FILE_COMMON);
      g_io_last.move_err   = 0;
      g_io_last.copy_err   = 0;
      g_io_last.delete_err = 0;
      g_io_counters.io_ok_count++;
      return true;
     }

   g_io_last.copy_err = GetLastError();
   g_io_counters.io_fail_count++;
   return false;
  }

bool BestEffortBackup(const string final_rel, const string backup_rel)
  {
   if(!InpEnableBackups)
      return false;

   if(!FileIsExist(final_rel, FILE_COMMON))
      return false;

   g_io_last.last_file = backup_rel;
   g_io_last.last_op   = IO_OP_BACKUP_COPY;
   g_io_last.copy_err  = 0;

   if(FileIsExist(backup_rel, FILE_COMMON))
      FileDelete(backup_rel, FILE_COMMON);

   ResetLastError();
   if(FileCopy(final_rel, FILE_COMMON, backup_rel, FILE_COMMON))
     {
      g_io_last.copy_err   = 0;
      g_io_last.delete_err = 0;
      g_io_counters.io_ok_count++;
      return true;
     }

   g_io_last.copy_err = GetLastError();
   g_io_counters.io_fail_count++;
   return false;
  }

bool BestEffortPersistenceBackup(const string final_rel, const string backup_rel)
  {
   if(!InpPersistenceBackupEnabled)
      return false;

   if(!FileIsExist(final_rel, FILE_COMMON))
      return false;

   g_io_last.last_file = backup_rel;
   g_io_last.last_op   = IO_OP_BACKUP_COPY;
   g_io_last.copy_err  = 0;

   if(FileIsExist(backup_rel, FILE_COMMON))
      FileDelete(backup_rel, FILE_COMMON);

   ResetLastError();
   if(FileCopy(final_rel, FILE_COMMON, backup_rel, FILE_COMMON))
     {
      g_io_last.copy_err   = 0;
      g_io_last.delete_err = 0;
      g_io_counters.io_ok_count++;
      return true;
     }

   g_io_last.copy_err = GetLastError();
   g_io_counters.io_fail_count++;
   return false;
  }

string BuildTempFileName(const string tmp_dir, const string final_name, const long minute_id, const int write_seq)
  {
   return tmp_dir + final_name + "." + LongToStringSafe(minute_id) + "." + IntegerToString(write_seq) + ".tmp";
  }
  
  string BuildUniverseSummaryJson()
  {
   string s = "{";
   s += "\"first_index\":0,";
   s += "\"last_index\":" + IntegerToString(MathMax(0, g_universe.size - 1)) + ",";
   s += "\"symbol_count\":" + IntegerToString(g_universe.size);
   s += "}";
   return s;
  }

string SectorIdToStringKey(const int sector_id)
  {
   return IntegerToString(ClampInt(sector_id, 0, 10));
  }

string BuildSectorCountsJson()
  {
   string s = "{";
   for(int i = 0; i <= 10; i++)
     {
      if(i > 0) s += ",";
      s += JsonString(SectorIdToStringKey(i)) + ":" + IntegerToString(g_sector_counts[i]);
     }
   s += "}";
   return s;
  }

string BuildCoverageOnlyJson()
  {
   string s = "{";
   s += "\"ready_tick_count\":" + IntegerToString(g_tick_ready_count) + ",";
   s += "\"ready_spec_count\":" + IntegerToString(g_spec_ready_count) + ",";
   s += "\"spec_sanity_ok_count\":" + IntegerToString(g_spec_sanity_ok_count) + ",";
   s += "\"market_open_count\":" + IntegerToString(g_market_open_count) + ",";
   s += "\"market_closed_count\":" + IntegerToString(g_market_closed_count) + ",";
   s += "\"expired_or_disabled_count\":" + IntegerToString(g_expired_or_disabled_count) + ",";
   s += "\"dead_quote_count\":" + IntegerToString(g_dead_quote_count) + ",";
   s += "\"cooled_down_count\":" + IntegerToString(g_cooled_down_count) + ",";
   s += "\"missing_tick_count\":" + IntegerToString(g_missing_tick_count) + ",";
   s += "\"missing_spec_count\":" + IntegerToString(g_missing_spec_count);
   s += "}";
   return s;
  }

string BuildCoverageSummaryJson()
  {
   return BuildCoverageOnlyJson();
  }

string BuildSessionsTodayJson(const SessionWindow &arr[], const int day)
  {
   string s = "[";
   int base = day * MAX_SESSIONS_PER_DAY;
   int emitted = 0;

   for(int i = 0; i < MAX_SESSIONS_PER_DAY && emitted < 2; i++)
     {
      int idx = base + i;
      if(!arr[idx].active)
         continue;

      if(emitted > 0)
         s += ",";

      s += "{";
      s += "\"start_hhmm\":" + IntegerToString(arr[idx].start_hhmm) + ",";
      s += "\"end_hhmm\":" + IntegerToString(arr[idx].end_hhmm);
      s += "}";

      emitted++;
     }

   s += "]";
   return s;
  }

string BuildSymbolSpecJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"digits\":" + IntToSafeStr(rec.spec_observed.digits) + ",";
   s += "\"point\":" + JsonDoubleOrNull6(rec.spec_observed.point) + ",";
   s += "\"contract_size\":" + JsonDoubleOrNull6(rec.spec_observed.contract_size) + ",";
   s += "\"tick_size\":" + JsonDoubleOrNull6(rec.spec_observed.tick_size) + ",";
   s += "\"tick_value\":" + JsonDoubleOrNull6(rec.spec_observed.tick_value) + ",";
   s += "\"volume_min\":" + JsonDoubleOrNull6(rec.spec_observed.volume_min) + ",";
   s += "\"volume_max\":" + JsonDoubleOrNull6(rec.spec_observed.volume_max) + ",";
   s += "\"volume_step\":" + JsonDoubleOrNull6(rec.spec_observed.volume_step) + ",";
   s += "\"trade_mode\":" + IntToSafeStr(rec.spec_observed.trade_mode) + ",";
   s += "\"calc_mode\":" + IntToSafeStr(rec.spec_observed.calc_mode) + ",";
   s += "\"margin_currency\":" + JsonStringOrNull(rec.spec_observed.margin_currency) + ",";
   s += "\"profit_currency\":" + JsonStringOrNull(rec.spec_observed.profit_currency) + ",";
   s += "\"swap_long\":" + JsonDoubleOrNull6(rec.spec_observed.swap_long) + ",";
   s += "\"swap_short\":" + JsonDoubleOrNull6(rec.spec_observed.swap_short) + ",";
   s += "\"tradability_class\":" + JsonString(TradabilityClassToString(rec.spec_derived.tradability_class)) + ",";
   s += "\"spec_marketdata_ready\":" + JsonBool(rec.spec_derived.spec_min_ready) + ",";
   s += "\"trade_contract_ready\":" + JsonBool(IsKnownNumber(rec.spec_observed.contract_size) && rec.spec_observed.contract_size > 0.0) + ",";
   s += "\"spec_confidence\":" + IntegerToString(rec.hydration3a.spec_quality) + ",";
   s += "\"spec_completeness\":" + IntegerToString(rec.hydration3a.spec_quality) + ",";
   s += "\"spec_hash\":" + JsonString(rec.spec_change.spec_hash) + ",";
   s += "\"spec_change_count\":" + IntegerToString(rec.spec_change.spec_change_count) + ",";
   s += "\"last_spec_change_time_server\":" + JsonDateTimeOrNull(rec.spec_change.last_spec_change_time_server) + ",";
   s += "\"last_material_change_reason\":" + JsonString(rec.spec_change.last_material_change_reason);
   s += "}";
   return s;
  }



string BuildIdentityJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"raw_symbol\":" + JsonString(rec.raw_symbol) + ",";
   s += "\"norm_symbol\":" + JsonString(rec.normalized_symbol) + ",";
   s += "\"asset_class\":" + JsonString(AssetClassToString(rec.spec_derived.asset_class)) + ",";
   s += "\"class_key\":" + JsonString(rec.spec_derived.class_key) + ",";
   s += "\"canonical_group\":" + JsonString(rec.spec_derived.canonical_group) + ",";
   s += "\"classification_source\":" + JsonString(rec.spec_derived.classification_source) + ",";
   s += "\"classification_confidence\":" + IntegerToString(rec.spec_derived.classification_confidence) + ",";
   s += "\"symbol_identity_hash\":" + JsonString(BuildSymbolIdentityHash(rec));
   s += "}";
   return s;
  }

string BuildSymbolSessionsJson(const SymbolRecord &rec)
  {
   int day = DayOfWeekServer(g_schedule.now_server_time);

   string s = "{";
   s += "\"session_source\":" + JsonString(ProvenanceValueToString(rec.session_state.session_source)) + ",";
   s += "\"session_confidence\":" + IntegerToString(rec.session_state.session_confidence) + ",";
   s += "\"session_fallback\":" + JsonBool(rec.session_state.fallback_used) + ",";
   s += "\"sessions_truncated\":" + JsonBool(rec.session_state.sessions_truncated) + ",";
   s += "\"quote_session_open_now\":" + JsonBool(rec.session_state.quote_session_open_now) + ",";
   s += "\"trade_session_open_now\":" + JsonBool(rec.session_state.trade_session_open_now) + ",";
   s += "\"quote_sessions_today\":" + BuildSessionsTodayJson(rec.session_state.quote_sessions, day) + ",";
   s += "\"trade_sessions_today\":" + BuildSessionsTodayJson(rec.session_state.trade_sessions, day) + ",";
   s += "\"quote_sessions_week_total\":" + IntegerToString(SumWeekSessionCounts(rec.session_state.quote_session_count)) + ",";
   s += "\"trade_sessions_week_total\":" + IntegerToString(SumWeekSessionCounts(rec.session_state.trade_session_count));
   s += "}";
   return s;
  }

string BuildSymbolMarketJson(const SymbolRecord &rec)
  {
   double bid = 0.0;
   double ask = 0.0;
   double mid = 0.0;
   double spread_points = 0.0;
   double tick_age_sec = 0.0;

   if(rec.tick_state.snapshot_path_ok)
     {
      bid = rec.tick_state.bid;
      ask = rec.tick_state.ask;
      mid = rec.tick_state.mid;

      if(IsKnownNumber(rec.tick_state.spread_points))
         spread_points = rec.tick_state.spread_points;

      if(g_schedule.now_server_time > 0 && rec.tick_state.last_tick_time > 0)
        {
         long age = (long)g_schedule.now_server_time - rec.tick_state.last_tick_time;
         if(age > 0)
            tick_age_sec = (double)age;
        }
     }

   string s = "{";
   s += "\"bid\":" + JsonDouble6(bid) + ",";
   s += "\"ask\":" + JsonDouble6(ask) + ",";
   s += "\"mid\":" + JsonDouble6(mid) + ",";
   s += "\"spread_points\":" + JsonDouble6(spread_points) + ",";
   s += "\"tick_age_sec\":" + JsonDouble6(tick_age_sec);
   s += "}";
   return s;
  }

string BuildSymbolTickHistoryJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"last_snapshot_seen_msc\":" + JsonLongOrNull(rec.tick_state.last_snapshot_seen_msc) + ",";
   s += "\"last_tick_time\":" + JsonLongOrNull(rec.tick_state.last_tick_time) + ",";
   s += "\"last_tick_time_msc\":" + JsonLongOrNull(rec.tick_state.last_tick_time_msc) + ",";
   s += "\"last_copyticks_seen_msc\":" + JsonLongOrNull(rec.tick_state.last_copyticks_seen_msc) + ",";
   s += "\"last_copied_msc\":" + JsonLongOrNull(rec.tick_state.last_copied_msc) + ",";
   s += "\"last_meaningful_history_msc\":" + JsonLongOrNull(rec.tick_state.last_meaningful_history_msc) + ",";
   s += "\"snapshot_path_ok\":" + JsonBool(rec.tick_state.snapshot_path_ok) + ",";
   s += "\"history_available\":" + JsonBool(rec.tick_state.history_available) + ",";
   s += "\"history_fresh\":" + JsonBool(rec.tick_state.history_fresh) + ",";
   s += "\"history_path_ok\":" + JsonBool(rec.tick_state.history_path_ok) + ",";
   s += "\"tick_path_mode\":" + JsonString(TickPathModeToString(rec.tick_state.tick_path_mode)) + ",";
   s += "\"copyticks_phase\":" + JsonString(CopyTicksPhaseToString(rec.tick_state.copyticks_phase)) + ",";
   s += "\"ring_count\":" + IntegerToString(rec.tick_state.ring_count) + ",";
   s += "\"ring_overwrite_count\":" + LongToStringSafe(rec.tick_state.ring_overwrite_count);
   s += "}";
   return s;
  }

string BuildSymbolStateSummaryJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"summary_state\":" + JsonString(SummaryStateToString(rec.health3.summary_state)) + ",";
   s += "\"data_reason_code\":" + JsonString(DataReasonCodeToString(rec.health3.data_reason_code)) + ",";
   s += "\"tradability_reason_code\":" + JsonString(TradabilityReasonCodeToString(rec.health3.tradability_reason_code)) + ",";
   s += "\"publish_reason_code\":" + JsonString(PublishReasonCodeToString(rec.health3.publish_reason_code)) + ",";
   s += "\"tick_silence_expected\":" + JsonBool(rec.health3.tick_silence_expected) + ",";
   s += "\"tick_silence_unexpected\":" + JsonBool(rec.health3.tick_silence_unexpected) + ",";
   s += "\"usable_for_observation\":" + JsonBool(rec.health.usable_for_observation) + ",";
   s += "\"usable_for_sessions\":" + JsonBool(rec.health3.usable_for_sessions) + ",";
   s += "\"usable_for_costs\":" + JsonBool(rec.health3.usable_for_costs) + ",";
   s += "\"usable_for_trading_future\":" + JsonBool(rec.health3.usable_for_trading_future);
   s += "}";
   return s;
  }

string BuildSymbolHealthJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"health_quote\":" + IntegerToString(rec.health3.health_quote) + ",";
   s += "\"health_spec\":" + IntegerToString(rec.health3.health_spec) + ",";
   s += "\"health_session\":" + IntegerToString(rec.health3.health_session) + ",";
   s += "\"health_cost\":" + IntegerToString(rec.health3.health_cost) + ",";
   s += "\"health_publish\":" + IntegerToString(rec.health3.health_publish) + ",";
   s += "\"health_continuity\":" + IntegerToString(rec.health3.health_continuity) + ",";
   s += "\"health_overall\":" + IntegerToString(rec.health3.health_overall) + ",";
   s += "\"operational_health_score\":" + IntegerToString(rec.health3.operational_health_score) + ",";
   s += "\"market_status_open_now\":" + JsonBool(rec.health3.market_status_open_now) + ",";
   s += "\"expected_market_open_now\":" + JsonBool(rec.health3.expected_market_open_now);
   s += "}";
   return s;
  }

string BuildSymbolCostJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"tick_value_effective\":" + JsonDoubleOrNull6(rec.cost.tick_value_effective) + ",";
   s += "\"tick_value_source\":" + JsonString(ProvenanceValueToString(rec.cost.tick_value_provenance)) + ",";
   s += "\"value_per_tick_money\":" + JsonDoubleOrNull6(rec.cost.value_per_tick_money) + ",";
   s += "\"value_per_tick_source\":" + JsonString(ProvenanceValueToString(rec.cost.value_per_tick_provenance)) + ",";
   s += "\"value_per_point_money\":" + JsonDoubleOrNull6(rec.cost.value_per_point_money) + ",";
   s += "\"value_per_point_source\":" + JsonString(ProvenanceValueToString(rec.cost.value_per_point_provenance)) + ",";
   s += "\"spread_points_live\":" + JsonDoubleOrNull6(rec.tick_state.spread_points) + ",";
   s += "\"spread_value_money_1lot\":" + JsonDoubleOrNull6(rec.cost.spread_value_money_1lot) + ",";
   s += "\"spread_value_source\":" + JsonString(ProvenanceValueToString(rec.cost.spread_value_provenance)) + ",";
   s += "\"margin_1lot_money_buy\":" + JsonDoubleOrNull6(rec.cost.margin_1lot_money_buy) + ",";
   s += "\"margin_buy_source\":" + JsonString(ProvenanceValueToString(rec.cost.margin_buy_provenance)) + ",";
   s += "\"margin_1lot_money_sell\":" + JsonDoubleOrNull6(rec.cost.margin_1lot_money_sell) + ",";
   s += "\"margin_sell_source\":" + JsonString(ProvenanceValueToString(rec.cost.margin_sell_provenance)) + ",";
   s += "\"commission_value_effective\":" + JsonDoubleOrNull6(rec.cost.commission_value_effective) + ",";
   s += "\"commission_source\":" + JsonString(ProvenanceValueToString(rec.cost.commission_provenance)) + ",";
   s += "\"carry_long_1lot\":" + JsonDoubleOrNull6(rec.cost.carry_long_1lot) + ",";
   s += "\"carry_short_1lot\":" + JsonDoubleOrNull6(rec.cost.carry_short_1lot) + ",";
   s += "\"carry_source\":" + JsonString(ProvenanceValueToString(rec.cost.carry_long_provenance)) + ",";
   s += "\"exposure_1lot_money\":" + JsonDoubleOrNull6(rec.cost.notional_exposure_estimate_1lot) + ",";
   s += "\"exposure_source\":" + JsonString(ProvenanceValueToString(rec.cost.exposure_provenance)) + ",";
   s += "\"spread_complete\":" + JsonBool(rec.cost.spread_complete) + ",";
   s += "\"commission_complete\":" + JsonBool(rec.cost.commission_complete) + ",";
   s += "\"carry_complete\":" + JsonBool(rec.cost.carry_complete) + ",";
   s += "\"margin_complete\":" + JsonBool(rec.cost.margin_complete) + ",";
   s += "\"friction_complete\":" + JsonBool(rec.cost.friction_complete) + ",";
   s += "\"usable_for_costs\":" + JsonBool(rec.cost.usable_for_costs) + ",";
   s += "\"cost_confidence\":" + IntegerToString(rec.cost.cost_confidence);
   s += "}";
   return s;
  }

string BuildSymbolCapabilitiesJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"can_select\":" + JsonBool(rec.capability.can_select) + ",";
   s += "\"can_snapshot\":" + JsonBool(rec.capability.can_snapshot) + ",";
   s += "\"can_copyticks\":" + JsonBool(rec.capability.can_copyticks) + ",";
   s += "\"can_sessions\":" + JsonBool(rec.capability.can_sessions) + ",";
   s += "\"can_probe_profit\":" + JsonBool(rec.capability.can_probe_profit) + ",";
   s += "\"can_probe_margin\":" + JsonBool(rec.capability.can_probe_margin) + ",";
   s += "\"can_trade_full\":" + JsonBool(rec.capability.can_trade_full) + ",";
   s += "\"can_trade_close_only\":" + JsonBool(rec.capability.can_trade_close_only) + ",";
   s += "\"has_tick_value_observed\":" + JsonBool(rec.capability.has_tick_value_observed) + ",";
   s += "\"has_commission_observed\":" + JsonBool(rec.capability.has_commission_observed);
   s += "}";
   return s;
  }
  
string BuildSymbolJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"raw_symbol\":" + JsonString(rec.raw_symbol) + ",";
   s += "\"norm_symbol\":" + JsonString(rec.normalized_symbol) + ",";
   s += "\"sector_id\":" + IntegerToString(ClampInt(rec.hydration3a.sector_id, 0, 10)) + ",";
   s += "\"identity\":" + BuildIdentityJson(rec) + ",";
   s += "\"spec\":" + BuildSymbolSpecJson(rec) + ",";
   s += "\"sessions\":" + BuildSymbolSessionsJson(rec) + ",";
   s += "\"market_status\":" + BuildSymbolMarketStatusJson(rec) + ",";
   s += "\"market\":" + BuildSymbolMarketJson(rec) + ",";
   s += "\"tick_history\":" + BuildSymbolTickHistoryJson(rec) + ",";
   s += "\"cost\":" + BuildSymbolCostJson(rec) + ",";
   s += "\"capabilities\":" + BuildSymbolCapabilitiesJson(rec) + ",";
   s += "\"continuity\":" + BuildSymbolContinuityJson(rec) + ",";
   s += "\"state_summary\":" + BuildSymbolStateSummaryJson(rec) + ",";
   s += "\"health\":" + BuildSymbolHealthJson(rec);
   s += "}";
   return s;
  }

string BuildSymbolContinuityJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"persistence_state\":" + JsonString(PersistenceStateExToString(rec.continuity.persistence_state)) + ",";
   s += "\"persistence_loaded\":" + JsonBool(rec.continuity.persistence_loaded) + ",";
   s += "\"persistence_fresh\":" + JsonBool(rec.continuity.persistence_fresh) + ",";
   s += "\"persistence_stale\":" + JsonBool(rec.continuity.persistence_stale) + ",";
   s += "\"persistence_corrupt\":" + JsonBool(rec.continuity.persistence_corrupt) + ",";
   s += "\"persistence_incompatible\":" + JsonBool(rec.continuity.persistence_incompatible) + ",";
   s += "\"resumed_from_persistence\":" + JsonBool(rec.continuity.resumed_from_persistence) + ",";
   s += "\"restarted_clean\":" + JsonBool(rec.continuity.restarted_clean) + ",";
   s += "\"persistence_age_sec\":" + IntegerToString(rec.continuity.persistence_age_sec) + ",";
   s += "\"continuity_origin\":" + JsonString(ContinuityOriginToString(rec.continuity.continuity_origin)) + ",";
   s += "\"continuity_last_good_server_time\":" + JsonDateTimeOrNull(rec.continuity.continuity_last_good_server_time);
   s += "}";
   return s;
  }

string BuildEA1MarketJson()
  {
   string symbols = "[";
   for(int i = 0; i < g_universe.size; i++)
     {
      if(i > 0)
         symbols += ",";
      symbols += BuildSymbolJson(g_universe.records[i]);
     }
   symbols += "]";

   string out = "{";
   out += "\"producer\":\"EA1\",";
   out += "\"stage\":\"symbols_universe\",";
   out += "\"minute_id\":" + LongToStringSafe(g_publish_stage.minute_id) + ",";
   out += "\"universe_fingerprint\":" + JsonString(BuildUniverseFingerprint()) + ",";
   out += "\"universe\":" + BuildUniverseSummaryJson() + ",";
   out += "\"sector_counts\":" + BuildSectorCountsJson() + ",";
   out += "\"coverage\":" + BuildCoverageOnlyJson() + ",";
   out += "\"symbols\":" + symbols;
   out += "}";

   return out;
  }
  
  string IoOpToString(const int op)
  {
   switch(op)
     {
      case IO_OP_WRITE_TMP:   return "write_tmp";
      case IO_OP_MOVE_COMMIT: return "move_commit";
      case IO_OP_COPY_COMMIT: return "copy_commit";
      case IO_OP_BACKUP_COPY: return "backup_copy";
      case IO_OP_DELETE_TMP:  return "delete_tmp";
     }
   return "none";
  }

string HydrationStateExToString(const HydrationStateEx st)
  {
   switch(st)
     {
      case HDE_NEW:                 return "new";
      case HDE_SELECTED:            return "selected";
      case HDE_SPEC_READY:          return "spec_ready";
      case HDE_SESSION_CHECKED:     return "session_checked";
      case HDE_MARKET_OPEN:         return "market_open";
      case HDE_MARKET_CLOSED:       return "market_closed";
      case HDE_EXPIRED_OR_DISABLED: return "expired_or_disabled";
      case HDE_TICK_PENDING:        return "tick_pending";
      case HDE_TICK_READY:          return "tick_ready";
      case HDE_DEAD_QUOTE:          return "dead_quote";
      case HDE_COOLED_DOWN:         return "cooled_down";
     }
   return "new";
  }

string BuildEA1DebugJson()
  {
   int worst_idx[];
   int worst_score[];
   BuildWorstSymbolLists(worst_idx, worst_score);

   string worst = "[";
   int rows = MathMin(ArraySize(worst_idx), MathMax(1, InpDebugSymbolRows));
   for(int i = 0; i < rows; i++)
     {
      if(i > 0)
         worst += ",";

      int idx = worst_idx[i];
      worst += "{";
      worst += "\"raw_symbol\":" + JsonString(g_universe.records[idx].raw_symbol) + ",";
      worst += "\"summary_state\":" + JsonString(SummaryStateToString(g_universe.records[idx].health3.summary_state)) + ",";
      worst += "\"data_reason_code\":" + JsonString(DataReasonCodeToString(g_universe.records[idx].health3.data_reason_code)) + ",";
      worst += "\"tradability_reason_code\":" + JsonString(TradabilityReasonCodeToString(g_universe.records[idx].health3.tradability_reason_code)) + ",";
      worst += "\"tick_path_mode\":" + JsonString(TickPathModeToString(g_universe.records[idx].tick_state.tick_path_mode)) + ",";
      worst += "\"copyticks_phase\":" + JsonString(CopyTicksPhaseToString(g_universe.records[idx].tick_state.copyticks_phase)) + ",";
      worst += "\"snapshot_path_ok\":" + JsonBool(g_universe.records[idx].tick_state.snapshot_path_ok) + ",";
      worst += "\"history_path_ok\":" + JsonBool(g_universe.records[idx].tick_state.history_path_ok) + ",";
      worst += "\"market_open_now\":" + JsonBool(g_universe.records[idx].hydration3a.market_open_now) + ",";
      worst += "\"cost_state\":" + JsonString(CostStateToString(g_universe.records[idx].cost.cost_state)) + ",";
      worst += "\"persistence_state\":" + JsonString(PersistenceStateExToString(g_universe.records[idx].continuity.persistence_state)) + ",";
      worst += "\"score\":" + IntegerToString(worst_score[i]);
      worst += "}";
     }
   worst += "]";

   string s = "{";

   s += "\"producer\":\"EA1\",";
   s += "\"stage\":\"debug\",";
   s += "\"minute_id\":" + LongToStringSafe(g_publish_debug.minute_id) + ",";

   s += "\"timing\":{";
   s += "\"timer_tick_count\":" + LongToStringSafe(g_schedule.timer_tick_count) + ",";
   s += "\"slip_count\":" + LongToStringSafe(g_schedule.timer_overrun_count) + ",";
   s += "\"last_timer_sec\":" + JsonDateTimeOrNull(g_schedule.last_timer_server_time);
   s += "},";

   s += "\"schedules\":{";
   s += "\"cursor_subscribe\":" + IntegerToString(g_schedule.cursor_subscribe) + ",";
   s += "\"cursor_spec\":" + IntegerToString(g_schedule.cursor_spec) + ",";
   s += "\"cursor_session\":" + IntegerToString(g_schedule.cursor_session) + ",";
   s += "\"cursor_snapshot\":" + IntegerToString(g_schedule.cursor_snapshot) + ",";
   s += "\"cursor_copyticks\":" + IntegerToString(g_schedule.cursor_copyticks) + ",";
   s += "\"cursor_cost\":" + IntegerToString(g_schedule.cursor_cost);
   s += "},";

   s += "\"paths\":{";
   s += "\"firm_id\":" + JsonString(g_firm_id) + ",";
   s += "\"base_dir\":" + JsonString(g_base_dir) + ",";
   s += "\"stage_current\":" + JsonString(g_stage_file) + ",";
   s += "\"stage_prev\":" + JsonString(g_stage_prev_file) + ",";
   s += "\"stage_backup\":" + JsonString(g_stage_backup_file) + ",";
   s += "\"debug_current\":" + JsonString(g_debug_json_file) + ",";
   s += "\"debug_prev\":" + JsonString(g_debug_json_prev_file) + ",";
   s += "\"debug_backup\":" + JsonString(g_debug_json_backup_file) + ",";
   s += "\"tmp_dir\":" + JsonString(g_tmp_dir_ea1) + ",";
   s += "\"locks_dir\":" + JsonString(g_locks_dir) + ",";
   s += "\"persistence_dir\":" + JsonString(g_persistence_dir_ea1);
   s += "},";

   s += "\"io_last\":{";
   s += "\"last_file\":" + JsonString(g_io_last.last_file) + ",";
   s += "\"last_op\":" + JsonString(IoOpToString(g_io_last.last_op)) + ",";
   s += "\"open_err\":" + IntegerToString(g_io_last.open_err) + ",";
   s += "\"read_err\":" + IntegerToString(g_io_last.read_err) + ",";
   s += "\"write_err\":" + IntegerToString(g_io_last.write_err) + ",";
   s += "\"move_err\":" + IntegerToString(g_io_last.move_err) + ",";
   s += "\"copy_err\":" + IntegerToString(g_io_last.copy_err) + ",";
   s += "\"delete_err\":" + IntegerToString(g_io_last.delete_err) + ",";
   s += "\"bytes\":" + IntegerToString(g_io_last.bytes) + ",";
   s += "\"size\":" + IntegerToString(g_io_last.size) + ",";
   s += "\"guard_ok\":" + JsonBool(g_io_last.guard_ok);
   s += "},";

   s += "\"io_counters\":{";
   s += "\"io_ok_count\":" + LongToStringSafe(g_io_counters.io_ok_count) + ",";
   s += "\"io_fail_count\":" + LongToStringSafe(g_io_counters.io_fail_count);
   s += "},";

   s += "\"perf\":{";
   s += "\"dur_step_total_ms\":" + IntegerToString(g_perf.dur_step_total_ms) + ",";
   s += "\"dur_hydrate_ms\":" + IntegerToString(g_perf.dur_hydrate_ms) + ",";
   s += "\"dur_build_stage_ms\":" + IntegerToString(g_perf.dur_build_stage_ms) + ",";
   s += "\"dur_write_tmp_ms\":" + IntegerToString(g_perf.dur_write_tmp_ms) + ",";
   s += "\"dur_commit_ms\":" + IntegerToString(g_perf.dur_commit_ms) + ",";
   s += "\"dur_backup_ms\":" + IntegerToString(g_perf.dur_backup_ms) + ",";
   s += "\"dur_read_ms\":" + IntegerToString(g_perf.dur_read_ms) + ",";
   s += "\"dur_validate_ms\":" + IntegerToString(g_perf.dur_validate_ms) + ",";
   s += "\"dur_parse_ms\":" + IntegerToString(g_perf.dur_parse_ms) + ",";
   s += "\"perf_warn\":" + JsonBool(g_perf.perf_warn);
   s += "},";

   s += "\"publish\":{";
   s += "\"stage_attempted\":" + JsonBool(g_publish_stage.attempted) + ",";
   s += "\"stage_ok\":" + JsonBool(g_publish_stage.ok) + ",";
   s += "\"stage_last_error\":" + JsonString(g_publish_stage.last_error) + ",";
   s += "\"stage_publish_skipped_lock\":" + JsonBool(g_publish_stage.publish_skipped_lock) + ",";
   s += "\"debug_attempted\":" + JsonBool(g_publish_debug.attempted) + ",";
   s += "\"debug_ok\":" + JsonBool(g_publish_debug.ok) + ",";
   s += "\"debug_commit_pending\":" + JsonBool(g_debug_commit_pending) + ",";
   s += "\"debug_last_error\":" + JsonString(g_publish_debug.last_error);
   s += "},";

   s += "\"coverage\":" + BuildCoverageOnlyJson() + ",";

   s += "\"continuity\":{";
   s += "\"persist_load_ok_count\":" + LongToStringSafe(g_persist_load_ok_count) + ",";
   s += "\"persist_load_fail_count\":" + LongToStringSafe(g_persist_load_fail_count) + ",";
   s += "\"persist_save_ok_count\":" + LongToStringSafe(g_persist_save_ok_count) + ",";
   s += "\"persist_save_fail_count\":" + LongToStringSafe(g_persist_save_fail_count) + ",";
   s += "\"persist_stale_discard_count\":" + LongToStringSafe(g_persist_stale_discard_count) + ",";
   s += "\"persist_corrupt_discard_count\":" + LongToStringSafe(g_persist_corrupt_discard_count) + ",";
   s += "\"persist_incompat_discard_count\":" + LongToStringSafe(g_persist_incompat_discard_count);
   s += "},";

   s += "\"recent_events\":[],";
   s += "\"worst_symbols\":" + worst + ",";

   s += "\"engine_counts\":{";
   s += "\"recompute_base_calls\":" + LongToStringSafe(g_dbg_recompute_base_calls) + ",";
   s += "\"recompute_base_skip_calls\":" + LongToStringSafe(g_dbg_recompute_base_skip_calls) + ",";
   s += "\"spec_reads\":" + LongToStringSafe(g_dbg_spec_reads) + ",";
   s += "\"snapshot_reads\":" + LongToStringSafe(g_dbg_snapshot_reads) + ",";
   s += "\"copyticks_calls\":" + LongToStringSafe(g_dbg_copyticks_calls) + ",";
   s += "\"margin_probe_calls\":" + LongToStringSafe(g_dbg_margin_probe_calls) + ",";
   s += "\"session_load_calls\":" + LongToStringSafe(g_dbg_session_load_calls) + ",";
   s += "\"activity_refresh_calls\":" + LongToStringSafe(g_dbg_activity_refresh_calls);
   s += "},";

   s += "\"failure_counts\":{";
   s += "\"io_fail_count\":" + LongToStringSafe(g_io_counters.io_fail_count) + ",";
   s += "\"persist_save_fail_count\":" + LongToStringSafe(g_persist_save_fail_count) + ",";
   s += "\"persist_load_fail_count\":" + LongToStringSafe(g_persist_load_fail_count);
   s += "},";

   s += "\"success_counts\":{";
   s += "\"io_ok_count\":" + LongToStringSafe(g_io_counters.io_ok_count) + ",";
   s += "\"persist_save_ok_count\":" + LongToStringSafe(g_persist_save_ok_count) + ",";
   s += "\"persist_load_ok_count\":" + LongToStringSafe(g_persist_load_ok_count);
   s += "},";

   s += "\"diagnostic_samples\":[],";
   s += "\"legends\":" + BuildLegendsJson();

   s += "}";

   return s;
  }
  
  void MaybePublishStage()
  {
   if(!InpPublishStageEnabled)
      return;

   if(g_schedule.now_server_time <= 0)
      return;

   long minute_id = GetMinuteId(g_schedule.now_server_time);
   if(minute_id < 0)
      return;

   if(!IsPublishWindowOpen(g_schedule.now_server_time, EA1_PUBLISH_OFFSET_SEC, EA1_PUBLISH_WINDOW_SEC))
      return;

   if(g_publish_stage.last_published_minute_id >= minute_id)
      return;

   g_publish_stage.attempted = true;
   g_publish_stage.ok = false;
   g_publish_stage.last_error = "";
   g_publish_stage.publish_skipped_lock = false;
   g_publish_stage.minute_id = minute_id;
   g_publish_stage.write_seq++;

   if(PublishLockExists())
     {
      g_publish_stage.publish_skipped_lock = true;
      g_publish_stage.last_error = "publish_lock";
      return;
     }

   ulong t0 = GetMicrosecondCount() / 1000;
   string json = BuildEA1MarketJson();
   g_perf.dur_build_stage_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   string tmp_rel = BuildTempFileName(g_tmp_dir_ea1,
                                      g_firm_id + "_symbols_universe.json",
                                      minute_id,
                                      g_publish_stage.write_seq);

   int bytes_written = 0;
   t0 = GetMicrosecondCount() / 1000;
   bool write_ok = WriteTextFileCommon(tmp_rel, json, bytes_written);
   g_perf.dur_write_tmp_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   if(!write_ok)
     {
      g_publish_stage.last_error = "write_tmp_failed";
      return;
     }

   g_io_last.guard_ok = (StringLen(json) >= 2 &&
                         StringSubstr(json, 0, 1) == "{" &&
                         StringSubstr(json, StringLen(json) - 1, 1) == "}");

   BestEffortPreservePrevious(g_stage_file, g_stage_prev_file);

   t0 = GetMicrosecondCount() / 1000;
   bool commit_ok = CommitFileAtomic(tmp_rel, g_stage_file);
   g_perf.dur_commit_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   if(!commit_ok)
     {
      g_publish_stage.last_error = "commit_failed";
      return;
     }

   t0 = GetMicrosecondCount() / 1000;
   BestEffortBackup(g_stage_file, g_stage_backup_file);
   g_perf.dur_backup_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   g_publish_stage.ok = true;
   g_publish_stage.last_published_minute_id = minute_id;
   g_publish_stage.last_error = "";
  }
  
  void MaybePublishDebugJson()
  {
   if(!InpPublishDebugJsonEnabled)
      return;

   if(g_schedule.now_server_time <= 0)
      return;

   if(g_schedule.last_debug_write_time > 0)
     {
      if((g_schedule.now_server_time - g_schedule.last_debug_write_time) < MathMax(1, InpDebugWriteSec))
         return;
     }

   long minute_id = GetMinuteId(g_schedule.now_server_time);
   if(minute_id < 0)
      return;

   g_publish_debug.attempted = true;
   g_publish_debug.last_error = "";
   g_publish_debug.publish_skipped_lock = false;
   g_publish_debug.minute_id = minute_id;
   g_publish_debug.write_seq++;
g_debug_commit_pending = false;

string json = BuildEA1DebugJson();
   string tmp_rel = BuildTempFileName(g_tmp_dir_ea1,
                                      g_firm_id + "_debug_ea1.json",
                                      minute_id,
                                      g_publish_debug.write_seq);

   int bytes_written = 0;
   if(!WriteTextFileCommon(tmp_rel, json, bytes_written))
     {
      g_publish_debug.ok = false;
      g_publish_debug.last_error = "write_tmp_failed";
      g_debug_commit_pending = false;
      return;
     }

   g_io_last.guard_ok = (StringLen(json) >= 2 &&
                         StringSubstr(json, 0, 1) == "{" &&
                         StringSubstr(json, StringLen(json) - 1, 1) == "}");

   BestEffortPreservePrevious(g_debug_json_file, g_debug_json_prev_file);

   if(!CommitFileAtomic(tmp_rel, g_debug_json_file))
     {
      g_publish_debug.ok = false;
      g_publish_debug.last_error = "commit_failed";
      g_debug_commit_pending = false;
      return;
     }

   BestEffortBackup(g_debug_json_file, g_debug_json_backup_file);

   g_publish_debug.ok = true;
   g_publish_debug.last_published_minute_id = minute_id;
   g_publish_debug.last_error = "";
   g_schedule.last_debug_write_time = g_schedule.now_server_time;
   g_debug_commit_pending = false;
  }
  
  string JsonStringOrNull(const string s)
  {
   if(s == "")
      return "null";
   return JsonString(s);
  }
  
  void MaybeCleanupTemp()
  {
   if(!InpEnableTempCleanup)
      return;

   if(g_schedule.now_server_time <= 0)
      return;

   if(g_last_temp_cleanup > 0)
     {
      if((g_schedule.now_server_time - g_last_temp_cleanup) < InpTempCleanupEverySec)
         return;
     }

   g_last_temp_cleanup = g_schedule.now_server_time;

   string patterns[2];
   patterns[0] = g_tmp_dir_ea1 + g_firm_id + "_symbols_universe.json*.tmp";
   patterns[1] = g_tmp_dir_ea1 + g_firm_id + "_debug_ea1.json*.tmp";

   for(int p = 0; p < 2; p++)
     {
      string found_name = "";
      long h = FileFindFirst(patterns[p], found_name, (int)FILE_COMMON);
      if(h == INVALID_HANDLE)
         continue;

      do
        {
         if(found_name == "")
            continue;

         string full_path = g_tmp_dir_ea1 + found_name;

         int fh = FileOpen(full_path, FILE_READ | FILE_BIN | FILE_COMMON);
         if(fh != INVALID_HANDLE && fh >= 0)
           {
            datetime mod_time = (datetime)FileGetInteger(fh, FILE_MODIFY_DATE);
            FileClose(fh);

            if(mod_time > 0 && (g_schedule.now_server_time - mod_time) >= InpTempCleanupAgeSec)
               FileDelete(full_path, FILE_COMMON);
           }
        }
      while(FileFindNext(h, found_name));

      FileFindClose(h);
     }
  }

string EnsureTrailingBackslash(const string s)
  {
   string out = s;
   int n = StringLen(out);
   if(n <= 0)
      return "";
   if(StringSubstr(out, n - 1, 1) != "\\")
      out += "\\";
   return out;
  }

string BuildFirmId()
  {
   string firm = SanitizeFirmName(AccountInfoString(ACCOUNT_COMPANY));
   string suffix = SanitizeFirmName(InpFirmSuffix);

   if(suffix != "" && suffix != "UNKNOWN_FIRM")
      return firm + "_" + suffix;

   return firm;
  }

void InitFirmFiles()
  {
   g_firm_id   = BuildFirmId();
   g_firm_name = g_firm_id;

   string firms_root = "FIRMS\\";
   string firm_dir   = firms_root + g_firm_id + "\\";

   // Root
   FolderCreate("FIRMS", FILE_COMMON);

   // Firm-private tree
   FolderCreate(StringSubstr(firm_dir, 0, StringLen(firm_dir) - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "outputs\\",        0, StringLen(firm_dir + "outputs\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "persistence\\",    0, StringLen(firm_dir + "persistence\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "persistence\\ea1\\",0, StringLen(firm_dir + "persistence\\ea1\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "tmp\\",            0, StringLen(firm_dir + "tmp\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "tmp\\ea1\\",       0, StringLen(firm_dir + "tmp\\ea1\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "locks\\",          0, StringLen(firm_dir + "locks\\") - 1), FILE_COMMON);

   // Base dirs
   g_base_dir            = firm_dir;
   g_outputs_dir         = firm_dir + "outputs\\";
   g_tmp_dir_ea1         = firm_dir + "tmp\\ea1\\";
   g_locks_dir           = firm_dir + "locks\\";
   g_persistence_dir_ea1 = firm_dir + "persistence\\ea1\\";

   // Canonical CURRENT human-facing files must live directly under FILE_COMMON\FIRMS\
   g_stage_file             = firms_root + g_firm_id + "_symbols_universe.json";
   g_debug_json_file        = firms_root + g_firm_id + "_debug_ea1.json";

   // Supporting human-facing files must live under FILE_COMMON\FIRMS\<firm_id>\outputs\
   g_stage_prev_file        = g_outputs_dir + g_firm_id + "_symbols_universe_prev.json";
   g_stage_backup_file      = g_outputs_dir + g_firm_id + "_symbols_universe_backup.json";
   g_debug_json_prev_file   = g_outputs_dir + g_firm_id + "_debug_ea1_prev.json";
   g_debug_json_backup_file = g_outputs_dir + g_firm_id + "_debug_ea1_backup.json";
  }

void ResetGlobalState()
  {
   ArrayResize(g_universe.symbols, 0);
   ArrayResize(g_universe.records, 0);
   g_universe.size = 0;

   g_schedule.timer_tick_count          = 0;
   g_schedule.timer_overrun_count       = 0;
   g_schedule.last_timer_server_time    = 0;
   g_schedule.now_server_time           = 0;
   g_schedule.now_utc_time              = 0;
   g_schedule.last_cycle_ms             = 0;
   g_schedule.timer_busy                = false;
   g_schedule.cursor_subscribe          = 0;
   g_schedule.cursor_spec               = 0;
   g_schedule.cursor_session            = 0;
   g_schedule.cursor_snapshot           = 0;
   g_schedule.cursor_copyticks          = 0;
   g_schedule.cursor_cost               = 0;
   g_schedule.cursor_consistency        = 0;
   g_schedule.last_debug_write_time     = 0;
   g_schedule.last_main_dump_write_time = 0;

   g_selected_count            = 0;
   g_spec_ready_count          = 0;
   g_session_ready_count       = 0;
   g_tick_ready_count          = 0;
   g_history_ready_count       = 0;
   g_both_path_ready_count     = 0;
   g_active_symbol_count       = 0;
   g_closed_symbol_count       = 0;
   g_dormant_symbol_count      = 0;
   g_cost_ready_count          = 0;
   g_cost_usable_count         = 0;
   g_coverage_cursor           = 0;

   g_last_hud_render_time      = 0;
   g_init_server_time          = 0;
   g_last_temp_cleanup         = 0;
   g_last_coverage_recount     = 0;

   g_firm_name                 = "";
   g_firm_id                   = "";
   g_base_dir                  = "";
   g_outputs_dir               = "";
   g_tmp_dir_ea1               = "";
   g_locks_dir                 = "";
   g_persistence_dir_ea1       = "";

   g_stage_file                = "";
   g_stage_prev_file           = "";
   g_stage_backup_file         = "";
   g_debug_json_file           = "";
   g_debug_json_prev_file      = "";
   g_debug_json_backup_file    = "";

   ResetPublishState(g_publish_stage);
   ResetPublishState(g_publish_debug);
   g_debug_commit_pending = false;
   ResetIoState();
   ResetPerfState();
   
   for(int i = 0; i < 11; i++)
      g_sector_counts[i] = 0;

   g_market_open_count         = 0;
   g_market_closed_count       = 0;
   g_expired_or_disabled_count = 0;
   g_dead_quote_count          = 0;
   g_cooled_down_count         = 0;
   g_missing_tick_count        = 0;
   g_missing_spec_count        = 0;
   g_spec_sanity_ok_count      = 0;
  }

void UpdateScheduleClock()
  {
   g_schedule.now_server_time = TimeCurrent();
   g_schedule.now_utc_time    = TimeGMT();
   g_schedule.last_timer_server_time = g_schedule.now_server_time;
  }

void ResetSpecObserved(SymbolSpecObserved &spec)
  {
   spec.digits          = INVALID_I32;
   spec.point           = INVALID_DBL;
   spec.contract_size   = INVALID_DBL;
   spec.tick_size       = INVALID_DBL;
   spec.tick_value      = INVALID_DBL;
   spec.volume_min      = INVALID_DBL;
   spec.volume_max      = INVALID_DBL;
   spec.volume_step     = INVALID_DBL;
   spec.trade_mode      = INVALID_I32;
   spec.calc_mode       = INVALID_I32;
   spec.margin_currency = "";
   spec.profit_currency = "";
   spec.swap_long       = INVALID_DBL;
   spec.swap_short      = INVALID_DBL;
  }

void ResetSpecDerived(SymbolSpecDerived &spec)
  {
   spec.asset_class                = AC_UNKNOWN;
   spec.tradability_class          = TC_UNKNOWN;
   spec.spec_level                 = SL_NONE;
   spec.spec_min_ready             = false;
   spec.spec_partial               = false;
   spec.canonical_symbol           = "";
   spec.class_key                  = "";
   spec.canonical_group            = "";
   spec.classification_source      = "";
   spec.classification_confidence  = 0;
  }

void ResetSessionState(SymbolSessionState &sess)
  {
   for(int i = 0; i < DAYS_PER_WEEK * MAX_SESSIONS_PER_DAY; i++)
     {
      sess.quote_sessions[i].active     = false;
      sess.quote_sessions[i].start_hhmm = 0;
      sess.quote_sessions[i].end_hhmm   = 0;

      sess.trade_sessions[i].active     = false;
      sess.trade_sessions[i].start_hhmm = 0;
      sess.trade_sessions[i].end_hhmm   = 0;
     }

   for(int d = 0; d < DAYS_PER_WEEK; d++)
     {
      sess.quote_session_count[d] = 0;
      sess.trade_session_count[d] = 0;
     }

   sess.quote_session_open_now = false;
   sess.trade_session_open_now = false;
   sess.fallback_used          = false;
   sess.sessions_loaded        = false;
   sess.sessions_truncated     = false;
   sess.session_source         = PV_NONE;
   sess.session_confidence     = 0;
  }

void ResetTickState(SymbolTickState &tick)
  {
   tick.tick_valid                   = false;
   tick.last_tick_time               = 0;
   tick.last_tick_time_msc           = INVALID_TIME_MSC;
   tick.bid                          = 0.0;
   tick.ask                          = 0.0;
   tick.mid                          = 0.0;
   tick.spread_points                = 0.0;

   tick.snapshot_path_ok             = false;
   tick.history_available            = false;
   tick.history_fresh                = false;
   tick.history_path_ok              = false;
   tick.tick_path_mode               = TPM_NONE;
   tick.copyticks_phase              = CT_NOT_STARTED;

   tick.market_open_state            = MOS_UNKNOWN;
   tick.activity_class               = SAC_UNKNOWN;
   tick.copyticks_eligible_now       = false;

   tick.last_snapshot_seen_msc       = INVALID_TIME_MSC;
   tick.last_copyticks_seen_msc      = INVALID_TIME_MSC;
   tick.last_copied_msc              = INVALID_TIME_MSC;
   tick.last_meaningful_snapshot_msc = INVALID_TIME_MSC;
   tick.last_meaningful_history_msc  = INVALID_TIME_MSC;
   tick.history_last_batch_count     = 0;
   tick.history_append_count         = 0;
   tick.history_same_ms_reject_count = 0;
   tick.copyticks_fail_count         = 0;
   tick.copyticks_cooldown_until     = 0;

   tick.next_snapshot_due_server     = 0;
   tick.next_copyticks_due_server    = 0;
   tick.active_watch_due_server      = 0;
   tick.dead_watch_due_server        = 0;
   tick.reopen_watch_due_server      = 0;

   tick.ring_head                    = 0;
   tick.ring_count                   = 0;
   tick.ring_overwrite_count         = 0;

   for(int i = 0; i < TICK_RING_CAPACITY; i++)
     {
      tick.ring[i].time_msc     = INVALID_TIME_MSC;
      tick.ring[i].bid          = 0.0;
      tick.ring[i].ask          = 0.0;
      tick.ring[i].last         = 0.0;
      tick.ring[i].volume_real  = 0.0;
      tick.ring[i].flags        = 0;
     }

   tick.event_head = 0;
   tick.event_count = 0;

   for(int j = 0; j < EVENT_RING_CAPACITY; j++)
     {
      tick.events[j].server_time   = 0;
      tick.events[j].type          = EVT_NONE;
      tick.events[j].tick_time_msc = INVALID_TIME_MSC;
     }
  }

void ResetCapabilityState(SymbolCapabilityState &cap)
  {
   cap.can_select              = false;
   cap.can_snapshot            = false;
   cap.can_copyticks           = false;
   cap.can_sessions            = false;
   cap.can_probe_profit        = false;
   cap.can_probe_margin        = false;
   cap.can_trade_full          = false;
   cap.can_trade_close_only    = false;
   cap.has_tick_value_observed = false;
   cap.has_commission_observed = false;
  }

void ResetCostState(SymbolCostState &cost)
  {
   cost.cost_state                     = COST_NONE;

   cost.spread_complete                = false;
   cost.commission_complete            = false;
   cost.carry_complete                 = false;
   cost.margin_complete                = false;
   cost.friction_complete              = false;

   cost.usable_for_costs               = false;

   cost.tick_value_effective           = INVALID_DBL;
   cost.tick_value_provenance          = PV_NONE;

   cost.value_per_tick_money           = INVALID_DBL;
   cost.value_per_tick_provenance      = PV_NONE;

   cost.value_per_point_money          = INVALID_DBL;
   cost.value_per_point_provenance     = PV_NONE;

   cost.spread_value_money_1lot        = INVALID_DBL;
   cost.spread_value_provenance        = PV_NONE;

   cost.commission_value_effective     = INVALID_DBL;
   cost.commission_provenance          = PV_NONE;

   cost.carry_long_1lot                = INVALID_DBL;
   cost.carry_long_provenance          = PV_NONE;

   cost.carry_short_1lot               = INVALID_DBL;
   cost.carry_short_provenance         = PV_NONE;

   cost.margin_1lot_money_buy          = INVALID_DBL;
   cost.margin_buy_provenance          = PV_NONE;

   cost.margin_1lot_money_sell         = INVALID_DBL;
   cost.margin_sell_provenance         = PV_NONE;

   cost.notional_exposure_estimate_1lot= INVALID_DBL;
   cost.exposure_provenance            = PV_NONE;

   cost.cost_confidence                = 0;
  }

void ResetHealthPhase3State(SymbolHealthPhase3State &h3)
  {
   h3.summary_state             = SUM_UNKNOWN;
   h3.data_reason_code          = DRC_NONE;
   h3.tradability_reason_code   = TRC_NONE;
   h3.publish_reason_code       = PRC_NOT_WRITTEN_YET;

   h3.spec_state_ex             = SPX_NONE;
   h3.session_state_ex          = SSX_NONE;
   h3.trade_state_ex            = TSX_UNKNOWN;
   h3.publish_state_ex          = PSX_NONE;

   h3.tick_silence_expected     = false;
   h3.tick_silence_unexpected   = false;

   h3.usable_for_sessions       = false;
   h3.usable_for_costs          = false;
   h3.usable_for_trading_future = false;

   h3.health_quote              = 0;
   h3.health_spec               = 0;
   h3.health_session            = 0;
   h3.health_cost               = 0;
   h3.health_publish            = 0;
   h3.health_continuity         = 0;
   h3.health_overall            = 0;
   h3.operational_health_score  = 0;

   h3.market_status_open_now    = false;
   h3.expected_market_open_now  = false;
  }

void ComputeSymbolCapabilityState(SymbolRecord &rec)
  {
   bool base_ready = (rec.selected_ok && rec.spec_derived.spec_partial);

   rec.capability.can_select              = rec.selected_ok;
   rec.capability.can_snapshot            = (base_ready && rec.tick_state.copyticks_phase != CT_COOLDOWN);
   rec.capability.can_copyticks           = (base_ready &&
                                             rec.tick_state.copyticks_phase != CT_FAILING &&
                                             rec.tick_state.copyticks_phase != CT_COOLDOWN);
   rec.capability.can_sessions            = base_ready;
   rec.capability.can_probe_profit        = false;
   rec.capability.can_probe_margin =
      (base_ready && ((GetSymbolQuirkFlags(rec) & QF_DISABLE_MARGIN_PROBE) == 0));
   rec.capability.can_trade_full          = (rec.spec_derived.tradability_class == TC_FULL_ACCESS);
   rec.capability.can_trade_close_only    = (rec.spec_derived.tradability_class == TC_CLOSE_ONLY);
   rec.capability.has_tick_value_observed = IsKnownNumber(rec.spec_observed.tick_value);
   rec.capability.has_commission_observed = false;
  }

void ComputeSymbolCostState(SymbolRecord &rec)
  {
   ResetCostState(rec.cost);

   bool tick_value_observed = (IsKnownNumber(rec.spec_observed.tick_value) &&
                               rec.spec_observed.tick_value >= 0.0);

   bool tick_size_ok = (IsKnownNumber(rec.spec_observed.tick_size) &&
                        rec.spec_observed.tick_size > 0.0);

   bool point_ok = (IsKnownNumber(rec.spec_observed.point) &&
                    rec.spec_observed.point > 0.0);

   bool spread_ok = (rec.tick_state.snapshot_path_ok &&
                     IsKnownNumber(rec.tick_state.spread_points) &&
                     rec.tick_state.spread_points >= 0.0 &&
                     point_ok);

   bool carry_long_ok = IsKnownNumber(rec.spec_observed.swap_long);
   bool carry_short_ok = IsKnownNumber(rec.spec_observed.swap_short);

   if(tick_value_observed)
     {
      rec.cost.tick_value_effective  = rec.spec_observed.tick_value;
      rec.cost.tick_value_provenance = PV_OBSERVED;
     }

   if(IsKnownNumber(rec.cost.tick_value_effective) && tick_size_ok)
     {
      rec.cost.value_per_tick_money      = rec.cost.tick_value_effective;
      rec.cost.value_per_tick_provenance = rec.cost.tick_value_provenance;
     }

   if(IsKnownNumber(rec.cost.tick_value_effective) && tick_size_ok && point_ok)
     {
      rec.cost.value_per_point_money      = rec.cost.tick_value_effective * (rec.spec_observed.point / rec.spec_observed.tick_size);
      rec.cost.value_per_point_provenance = PV_DERIVED;
     }

   rec.cost.spread_complete = spread_ok;

   if(IsKnownNumber(rec.cost.value_per_point_money) && rec.cost.spread_complete)
     {
      rec.cost.spread_value_money_1lot = rec.tick_state.spread_points * rec.cost.value_per_point_money;
      rec.cost.spread_value_provenance = PV_DERIVED;
     }

   rec.cost.commission_complete        = false;
   rec.cost.commission_value_effective = INVALID_DBL;
   rec.cost.commission_provenance      = PV_NONE;

   if(carry_long_ok)
     {
      rec.cost.carry_long_1lot       = rec.spec_observed.swap_long;
      rec.cost.carry_long_provenance = PV_OBSERVED;
     }

   if(carry_short_ok)
     {
      rec.cost.carry_short_1lot       = rec.spec_observed.swap_short;
      rec.cost.carry_short_provenance = PV_OBSERVED;
     }

   rec.cost.carry_complete = (carry_long_ok && carry_short_ok);

   rec.cost.margin_complete        = false;
   rec.cost.margin_1lot_money_buy  = INVALID_DBL;
   rec.cost.margin_buy_provenance  = PV_NONE;
   rec.cost.margin_1lot_money_sell = INVALID_DBL;
   rec.cost.margin_sell_provenance = PV_NONE;

   bool margin_probe_due = false;

   if(rec.last_margin_probe_time <= 0)
      margin_probe_due = true;
   else if((g_schedule.now_server_time - rec.last_margin_probe_time) >= MathMax(1, InpMarginProbeRefreshSec))
      margin_probe_due = true;

   if(margin_probe_due && rec.tick_state.snapshot_path_ok)
     {
      double buy_margin = INVALID_DBL;
      double sell_margin = INVALID_DBL;

      if(ProbeMarginOneLot(rec, buy_margin, sell_margin))
        {
         if(IsKnownNumber(buy_margin))
           {
            rec.cost.margin_1lot_money_buy = buy_margin;
            rec.cost.margin_buy_provenance = PV_PROBED;
           }

         if(IsKnownNumber(sell_margin))
           {
            rec.cost.margin_1lot_money_sell = sell_margin;
            rec.cost.margin_sell_provenance = PV_PROBED;
           }

         rec.cost.margin_complete = (IsKnownNumber(rec.cost.margin_1lot_money_buy) &&
                                     IsKnownNumber(rec.cost.margin_1lot_money_sell));
        }

      rec.last_margin_probe_time = g_schedule.now_server_time;
     }

   if(rec.spec_derived.asset_class == AC_FX &&
      IsKnownNumber(rec.spec_observed.contract_size) &&
      rec.spec_observed.contract_size > 0.0)
     {
      rec.cost.notional_exposure_estimate_1lot = rec.spec_observed.contract_size;
      rec.cost.exposure_provenance             = PV_HEURISTIC;
     }

   rec.cost.friction_complete = (rec.cost.spread_complete &&
                                 rec.cost.commission_complete &&
                                 rec.cost.carry_complete &&
                                 rec.cost.margin_complete);

   rec.cost.usable_for_costs = (rec.spec_derived.spec_min_ready &&
                                IsKnownNumber(rec.cost.value_per_point_money));

   bool any_meaningful = false;
   if(IsKnownNumber(rec.cost.tick_value_effective)) any_meaningful = true;
   if(IsKnownNumber(rec.cost.value_per_tick_money)) any_meaningful = true;
   if(IsKnownNumber(rec.cost.value_per_point_money)) any_meaningful = true;
   if(IsKnownNumber(rec.cost.spread_value_money_1lot)) any_meaningful = true;
   if(IsKnownNumber(rec.cost.carry_long_1lot)) any_meaningful = true;
   if(IsKnownNumber(rec.cost.carry_short_1lot)) any_meaningful = true;
   if(IsKnownNumber(rec.cost.notional_exposure_estimate_1lot)) any_meaningful = true;
   if(rec.cost.spread_complete || rec.cost.carry_complete) any_meaningful = true;

   if(IsKnownNumber(rec.cost.value_per_point_money) && rec.cost.spread_complete)
      rec.cost.cost_state = COST_READY;
   else if(any_meaningful)
      rec.cost.cost_state = COST_PARTIAL;
   else
      rec.cost.cost_state = COST_NONE;

   int conf = 0;
   if(rec.cost.tick_value_provenance == PV_OBSERVED)
      conf += 35;
   if(IsKnownNumber(rec.cost.value_per_point_money))
      conf += 20;
   if(rec.cost.spread_complete)
      conf += 15;
   if(rec.cost.carry_complete)
      conf += 10;
   if(rec.cost.margin_complete)
      conf += 20;

   rec.cost.cost_confidence = ClampInt(conf, 0, 100);
  }

void ComputeSymbolHealthPhase3(SymbolRecord &rec)
  {
   PublishReasonCode old_publish_reason = rec.health3.publish_reason_code;
   PublishStateEx    old_publish_state  = rec.health3.publish_state_ex;
   int               old_health_publish = rec.health3.health_publish;

   ResetHealthPhase3State(rec.health3);

   rec.health3.publish_reason_code = old_publish_reason;
   rec.health3.publish_state_ex    = old_publish_state;
   rec.health3.health_publish      = old_health_publish;

   rec.health3.market_status_open_now   = (rec.tick_state.market_open_state == MOS_OPEN_NOW);
   rec.health3.expected_market_open_now = rec.health3.market_status_open_now;

   if(rec.spec_derived.spec_min_ready)
      rec.health3.spec_state_ex = SPX_READY;
   else if(rec.spec_derived.spec_partial)
      rec.health3.spec_state_ex = SPX_PARTIAL;
   else
      rec.health3.spec_state_ex = SPX_NONE;

   if(rec.session_state.sessions_loaded)
      rec.health3.session_state_ex = SSX_READY;
   else if(rec.session_state.fallback_used)
      rec.health3.session_state_ex = SSX_FALLBACK;
   else
      rec.health3.session_state_ex = SSX_NONE;

   if(rec.spec_derived.tradability_class == TC_FULL_ACCESS)
      rec.health3.trade_state_ex = TSX_FULL;
   else if(rec.spec_derived.tradability_class == TC_CLOSE_ONLY)
      rec.health3.trade_state_ex = TSX_CLOSE_ONLY;
   else if(rec.spec_derived.tradability_class == TC_DISABLED)
      rec.health3.trade_state_ex = TSX_DISABLED;
   else
      rec.health3.trade_state_ex = TSX_UNKNOWN;

   if(g_publish_stage.attempted && !g_publish_stage.ok && g_publish_stage.last_error != "")
     {
      rec.health3.publish_reason_code = PRC_WRITE_FAILED;
      rec.health3.publish_state_ex    = PSX_FAILING;
      rec.health3.health_publish      = 0;
     }
   else if(g_publish_debug.attempted && !g_publish_debug.ok && g_publish_debug.last_error != "")
     {
      rec.health3.publish_reason_code = PRC_WRITE_FAILED;
      rec.health3.publish_state_ex    = PSX_FAILING;
      rec.health3.health_publish      = 0;
     }
   else if(g_publish_stage.ok || g_publish_debug.ok)
     {
      rec.health3.publish_reason_code = PRC_OK;
      rec.health3.publish_state_ex    = PSX_OK;
      rec.health3.health_publish      = 100;
     }
   else
     {
      rec.health3.publish_reason_code = PRC_NOT_WRITTEN_YET;
      rec.health3.publish_state_ex    = PSX_NONE;
      rec.health3.health_publish      = 0;
      
     }

   rec.health3.tick_silence_expected   = (rec.tick_state.activity_class == SAC_MARKET_CLOSED ||
                                          rec.tick_state.activity_class == SAC_DORMANT);
   rec.health3.tick_silence_unexpected = (rec.tick_state.activity_class == SAC_ACTIVE &&
                                          rec.tick_state.tick_path_mode == TPM_NONE);

   if(!rec.selected_ok)
      rec.health3.data_reason_code = DRC_SELECT_FAILED;
   else if(!rec.spec_derived.spec_partial)
      rec.health3.data_reason_code = DRC_SPEC_PARTIAL;
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
      rec.health3.data_reason_code = DRC_MARKET_CLOSED;
   else if(rec.tick_state.activity_class == SAC_DORMANT)
      rec.health3.data_reason_code = DRC_DORMANT;
   else if(rec.tick_state.copyticks_phase == CT_FIRST_SYNC || rec.tick_state.copyticks_phase == CT_WARM)
      rec.health3.data_reason_code = DRC_COPYTICKS_WARMUP;
   else if(rec.tick_state.copyticks_phase == CT_FAILING || rec.tick_state.copyticks_phase == CT_COOLDOWN)
      rec.health3.data_reason_code = DRC_COPYTICKS_FAILING;
   else if(rec.tick_state.tick_path_mode == TPM_NONE)
      rec.health3.data_reason_code = DRC_NO_TICK;
   else if(rec.cost.cost_state == COST_PARTIAL)
      rec.health3.data_reason_code = DRC_COST_PARTIAL;
   else if(rec.tick_state.tick_path_mode != TPM_NONE)
      rec.health3.data_reason_code = DRC_OK;
   else
      rec.health3.data_reason_code = DRC_UNKNOWN;

   if(rec.spec_derived.tradability_class == TC_FULL_ACCESS)
      rec.health3.tradability_reason_code = TRC_OK;
   else if(rec.spec_derived.tradability_class == TC_CLOSE_ONLY)
      rec.health3.tradability_reason_code = TRC_CLOSE_ONLY;
   else if(rec.spec_derived.tradability_class == TC_DISABLED)
      rec.health3.tradability_reason_code = TRC_DISABLED;
   else if(rec.spec_derived.tradability_class == TC_UNKNOWN)
      rec.health3.tradability_reason_code = TRC_UNKNOWN;
   else
      rec.health3.tradability_reason_code = TRC_NOT_FULL_ACCESS;

   rec.health3.usable_for_sessions = (rec.session_state.sessions_loaded || rec.session_state.fallback_used);
   rec.health3.usable_for_costs    = rec.cost.usable_for_costs;

   bool vol_min_ok  = IsKnownNumber(rec.spec_observed.volume_min);
   bool vol_max_ok  = IsKnownNumber(rec.spec_observed.volume_max);
   bool vol_step_ok = IsKnownNumber(rec.spec_observed.volume_step);
   bool contract_ok = (IsKnownNumber(rec.spec_observed.contract_size) &&
                       rec.spec_observed.contract_size > 0.0);

   rec.health3.usable_for_trading_future = (rec.spec_derived.tradability_class == TC_FULL_ACCESS &&
                                            rec.spec_derived.spec_min_ready &&
                                            contract_ok &&
                                            vol_min_ok &&
                                            vol_max_ok &&
                                            vol_step_ok);

   if(rec.tick_state.snapshot_path_ok)
      rec.health3.health_quote = 100;
   else if(rec.tick_state.history_path_ok)
      rec.health3.health_quote = 75;
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
      rec.health3.health_quote = 40;
   else if(rec.tick_state.activity_class == SAC_DORMANT)
      rec.health3.health_quote = 20;
   else
      rec.health3.health_quote = 0;

   if(rec.spec_derived.spec_min_ready)
      rec.health3.health_spec = 100;
   else if(rec.spec_derived.spec_partial)
      rec.health3.health_spec = 60;
   else
      rec.health3.health_spec = 0;

   if(rec.session_state.sessions_loaded)
      rec.health3.health_session = 100;
   else if(rec.session_state.fallback_used)
      rec.health3.health_session = 60;
   else if(rec.tick_state.activity_class == SAC_ACTIVE)
      rec.health3.health_session = 20;
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
      rec.health3.health_session = 40;
   else
      rec.health3.health_session = 0;

   rec.health3.health_cost = rec.cost.cost_confidence;

   if(rec.continuity.resumed_from_persistence && rec.continuity.persistence_fresh)
      rec.health3.health_continuity = 100;
   else if(rec.continuity.restarted_clean)
      rec.health3.health_continuity = 50;
   else if(rec.continuity.persistence_stale || rec.continuity.persistence_corrupt || rec.continuity.persistence_incompatible)
      rec.health3.health_continuity = 20;
   else
      rec.health3.health_continuity = 0;

   rec.health3.operational_health_score =
      (30 * rec.health3.health_quote +
       25 * rec.health3.health_spec +
       15 * rec.health3.health_session +
       15 * rec.health3.health_cost +
       15 * rec.health3.health_continuity) / 100;

   rec.health3.health_overall = rec.health3.operational_health_score;

   if(!rec.selected_ok || !rec.spec_derived.spec_partial)
      rec.health3.summary_state = SUM_UNUSABLE;
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED && !rec.health3.tick_silence_unexpected)
     {
      if(rec.health3.operational_health_score >= 80)
         rec.health3.summary_state = SUM_GOOD;
      else
         rec.health3.summary_state = SUM_PARTIAL;
     }
   else if(rec.tick_state.copyticks_phase == CT_FIRST_SYNC || rec.tick_state.copyticks_phase == CT_WARM)
      rec.health3.summary_state = SUM_WARMUP;
   else if(rec.tick_state.copyticks_phase == CT_FAILING || rec.tick_state.copyticks_phase == CT_COOLDOWN || rec.health3.tick_silence_unexpected)
      rec.health3.summary_state = SUM_DEGRADED;
   else if(rec.health3.operational_health_score >= 80)
      rec.health3.summary_state = SUM_GOOD;
   else if(rec.health3.operational_health_score >= 45)
      rec.health3.summary_state = SUM_PARTIAL;
   else
      rec.health3.summary_state = SUM_DEGRADED;
  }

int ClampInt(const int v, const int lo, const int hi)
  {
   if(v < lo)
      return lo;
   if(v > hi)
      return hi;
   return v;
  }

bool CanBeHistoryReady(const CopyTicksPhase phase)
  {
   if(phase == CT_WARM)     return true;
   if(phase == CT_STEADY)   return true;
   if(phase == CT_DEGRADED) return true;
   return false;
  }

void RecomputeBaseState(SymbolRecord &rec)
  {
   g_dbg_recompute_base_calls++;

   bool prev_snapshot_ok = rec.tick_state.snapshot_path_ok;
   bool prev_history_ok  = rec.tick_state.history_path_ok;

   UpdateSymbolActivityState(rec);

   bool snapshot_fresh = IsRecentServerTickTimeMsc(rec.tick_state.last_snapshot_seen_msc, InpActiveSnapshotFreshSec);
   bool history_fresh  = IsRecentServerTickTimeMsc(rec.tick_state.last_meaningful_history_msc, InpActiveSnapshotFreshSec);

   rec.tick_state.snapshot_path_ok = (rec.tick_state.tick_valid && snapshot_fresh);

   rec.tick_state.history_available =
      (rec.tick_state.ring_count > 0 &&
       CanBeHistoryReady(rec.tick_state.copyticks_phase));

   rec.tick_state.history_fresh =
      (rec.tick_state.history_available &&
       history_fresh &&
       rec.tick_state.copyticks_phase != CT_FAILING &&
       rec.tick_state.copyticks_phase != CT_COOLDOWN);

   rec.tick_state.history_path_ok = rec.tick_state.history_fresh;

   rec.tick_state.tick_path_mode =
      DeriveTickPathMode(rec.tick_state.snapshot_path_ok,
                         rec.tick_state.history_path_ok);

   if(prev_snapshot_ok && !rec.tick_state.snapshot_path_ok)
      rec.cost_dirty = true;

   if(prev_history_ok && !rec.tick_state.history_path_ok)
      rec.continuity.persistence_dirty = true;

   rec.health.spec_ready             = rec.spec_derived.spec_min_ready;
   rec.health.session_ready          = (rec.session_state.sessions_loaded || rec.session_state.fallback_used);
   rec.health.tick_ready             = (rec.tick_state.tick_path_mode != TPM_NONE);
   rec.health.usable_for_observation = (rec.selected_ok &&
                                        rec.spec_derived.spec_partial &&
                                        (rec.tick_state.tick_path_mode != TPM_NONE ||
                                         rec.tick_state.activity_class == SAC_MARKET_CLOSED));

   if(!rec.selected_ok)
     {
      rec.health.state  = SS_NEW;
      rec.health.reason = (rec.select_fail_count > 0 ? RC_SELECT_FAILED : RC_INIT);
     }
   else if(!rec.spec_derived.spec_partial)
     {
      rec.health.state  = SS_SELECTED;
      rec.health.reason = RC_INIT;
     }
   else if(!rec.spec_derived.spec_min_ready)
     {
      rec.health.state  = SS_SPEC_PARTIAL;
      rec.health.reason = RC_SPEC_PARTIAL;
     }
   else if(rec.tick_state.tick_path_mode == TPM_BOTH || rec.tick_state.tick_path_mode == TPM_SNAPSHOT_ONLY)
     {
      rec.health.state  = SS_SNAPSHOT_VALID;
      rec.health.reason = RC_OK;
     }
   else if(rec.tick_state.tick_path_mode == TPM_COPYTICKS_ONLY)
     {
      rec.health.state  = SS_HISTORY_VALID;
      rec.health.reason = RC_OK;
     }
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
     {
      rec.health.state  = SS_SESSION_READY;
      rec.health.reason = RC_MARKET_CLOSED;
     }
   else if(rec.tick_state.activity_class == SAC_DORMANT)
     {
      rec.health.state  = SS_SNAPSHOT_PARTIAL;
      rec.health.reason = RC_DORMANT_SYMBOL;
     }
   else if(rec.tick_state.copyticks_phase == CT_FIRST_SYNC || rec.tick_state.copyticks_phase == CT_WARM)
     {
      rec.health.state  = SS_SNAPSHOT_PARTIAL;
      rec.health.reason = RC_COPYTICKS_WARMUP;
     }
   else if(rec.tick_state.copyticks_phase == CT_FAILING || rec.tick_state.copyticks_phase == CT_COOLDOWN)
     {
      rec.health.state  = SS_SNAPSHOT_PARTIAL;
      rec.health.reason = RC_COPYTICKS_FAILING;
     }
   else if(rec.session_state.fallback_used)
     {
      rec.health.state  = SS_SESSION_PARTIAL;
      rec.health.reason = RC_SESSION_FALLBACK;
     }
   else if(rec.session_state.sessions_loaded)
     {
      rec.health.state  = SS_SNAPSHOT_PARTIAL;
      rec.health.reason = RC_NO_TICK;
     }
   else
     {
      rec.health.state  = SS_SPEC_MIN_READY;
      rec.health.reason = RC_NO_TICK;
     }

   UpdateHydration3A(rec);
   ComputeSymbolCapabilityState(rec);

   if(rec.cost_dirty ||
      rec.last_cost_refresh_time <= 0 ||
      (g_schedule.now_server_time - rec.last_cost_refresh_time) >= MathMax(1, InpCostRefreshSec))
     {
      // cost engine owns actual recomputation
     }

   ComputeSymbolHealthPhase3(rec);
  }
   
void AddSymbolEvent(SymbolRecord &rec, const Phase2EventType type, const long tick_time_msc)
  {
   int idx = rec.tick_state.event_head;

   rec.tick_state.events[idx].server_time   = g_schedule.now_server_time;
   rec.tick_state.events[idx].type          = type;
   rec.tick_state.events[idx].tick_time_msc = tick_time_msc;

   rec.tick_state.event_head++;
   if(rec.tick_state.event_head >= EVENT_RING_CAPACITY)
      rec.tick_state.event_head = 0;

   if(rec.tick_state.event_count < EVENT_RING_CAPACITY)
      rec.tick_state.event_count++;
  }

int GetLastRingIndex(const SymbolTickState &tick_state)
  {
   if(tick_state.ring_count <= 0)
      return -1;

   int idx = tick_state.ring_head - 1;
   if(idx < 0)
      idx = TICK_RING_CAPACITY - 1;

   return idx;
  }

bool AppendRingTick(SymbolRecord &rec, const MqlTick &tick)
  {
   int last_idx = GetLastRingIndex(rec.tick_state);

   if(last_idx >= 0)
     {
      TickRingItem prev = rec.tick_state.ring[last_idx];

      if(prev.time_msc == (long)tick.time_msc)
        {
         bool same_bid    = (prev.bid == tick.bid);
         bool same_ask    = (prev.ask == tick.ask);
         bool same_last   = (prev.last == tick.last);
         bool same_vol    = (prev.volume_real == tick.volume_real);
         bool same_flags  = (prev.flags == tick.flags);

         if(same_bid && same_ask && same_last && same_vol && same_flags)
           {
            rec.tick_state.history_same_ms_reject_count++;
            AddSymbolEvent(rec, EVT_COPYTICKS_SAME_MS_REJECT, (long)tick.time_msc);
            return false;
           }
        }
     }

   int idx = rec.tick_state.ring_head;

   rec.tick_state.ring[idx].time_msc    = (long)tick.time_msc;
   rec.tick_state.ring[idx].bid         = tick.bid;
   rec.tick_state.ring[idx].ask         = tick.ask;
   rec.tick_state.ring[idx].last        = tick.last;
   rec.tick_state.ring[idx].volume_real = tick.volume_real;
   rec.tick_state.ring[idx].flags       = tick.flags;

   rec.tick_state.ring_head++;
   if(rec.tick_state.ring_head >= TICK_RING_CAPACITY)
      rec.tick_state.ring_head = 0;

   if(rec.tick_state.ring_count < TICK_RING_CAPACITY)
      rec.tick_state.ring_count++;
   else
      rec.tick_state.ring_overwrite_count++;

   rec.tick_state.history_append_count++;
   return true;
  }

void SortTicksAscending(MqlTick &ticks[])
  {
   int n = ArraySize(ticks);
   for(int i = 1; i < n; i++)
     {
      MqlTick key = ticks[i];
      int j = i - 1;

      while(j >= 0 && ticks[j].time_msc > key.time_msc)
        {
         ticks[j + 1] = ticks[j];
         j--;
        }

      ticks[j + 1] = key;
     }
  }

string PersistenceStateExToString(const PersistenceStateEx v)
  {
   switch(v)
     {
      case PTX_NONE:                   return "none";
      case PTX_NOT_FOUND:              return "not_found";
      case PTX_LOADED_FRESH:           return "loaded_fresh";
      case PTX_STALE_DISCARDED:        return "stale_discarded";
      case PTX_CORRUPT_DISCARDED:      return "corrupt_discarded";
      case PTX_INCOMPATIBLE_DISCARDED: return "incompatible_discarded";
      case PTX_CLEAN_START:            return "clean_start";
      case PTX_SAVED_OK:               return "saved_ok";
      case PTX_SAVE_FAILED:            return "save_failed";
     }
   return "none";
  }

int GetSymbolQuirkFlags(const SymbolRecord &rec)
  {
   int flags = QF_NONE;

   if(!InpEnableQuirkLayer)
      return flags;

   if(rec.spec_derived.asset_class == AC_FX && rec.spec_observed.tick_value == 0.0)
      flags |= QF_IGNORE_ZERO_TICKVALUE;

   return flags;
  }

string ContinuityOriginToString(const ContinuityOrigin v)
  {
   switch(v)
     {
      case CO_NONE:        return "none";
      case CO_CLEAN:       return "clean";
      case CO_PERSISTENCE: return "persistence";
     }
   return "none";
  }

string LatestEventToString(const SymbolRecord &rec)
  {
   if(rec.tick_state.event_count <= 0)
      return "null";

   int idx = rec.tick_state.event_head - 1;
   if(idx < 0)
      idx = EVENT_RING_CAPACITY - 1;

   if(rec.tick_state.events[idx].type == EVT_NONE)
      return "null";

   return Phase2EventTypeToString(rec.tick_state.events[idx].type);
  }

bool IsUpperAlpha(const int c)
  {
   if(c < 'A')
      return false;
   if(c > 'Z')
      return false;
   return true;
  }

bool IsLikelyTickerStockSymbol(const string s)
  {
   int n = StringLen(s);
   if(n < 1 || n > 6)
      return false;

   for(int i = 0; i < n; i++)
     {
      int c = StringGetCharacter(s, i);
      if(!IsUpperAlpha(c))
         return false;
     }

   return true;
  }
  
string BuildCanonicalSymbol(string s)
  {
   string out = s;
   StringToUpper(out);
   StringTrimLeft(out);
   StringTrimRight(out);
   StringReplace(out, " ", "");

   int p = StringFind(out, ".", 0);
   if(p > 0)
      out = StringSubstr(out, 0, p);

   int q = StringFind(out, "#", 0);
   if(q > 0)
      out = StringSubstr(out, 0, q);

   int r = StringFind(out, "-", 0);
   if(r > 0)
      out = StringSubstr(out, 0, r);

   if(out == "US100" || out == "USTEC" || out == "NAS" || out == "NAS100")
      return "NAS100";

   if(out == "DJ" || out == "DJ30" || out == "WS30" || out == "US30")
      return "US30";

   if(out == "SPX" || out == "US500" || out == "SPX500")
      return "SPX500";

   if(out == "DE40" || out == "DAX" || out == "GER40")
      return "GER40";

   if(out == "XAUUSD" || out == "GOLD")
      return "XAUUSD";

   if(out == "XAGUSD" || out == "SILVER")
      return "XAGUSD";

   return out;
  }

bool IsFXCanonical(string s)
  {
   if(StringLen(s) < 6)
      return false;

   string a = StringSubstr(s, 0, 3);
   string b = StringSubstr(s, 3, 3);

   if(!IsMajorCurrency(a))
      return false;
   if(!IsMajorCurrency(b))
      return false;

   return true;
  }

bool IsHKStockSymbol(string s)
  {
   string u = s;
   StringToUpper(u);

   if(StringFind(u, ".XHKG", 0) >= 0)
      return true;
   if(StringFind(u, ".HK", 0) >= 0)
      return true;

   return false;
  }

bool IsLikelyStockFromCalcMode(const int calc_mode)
  {
#ifdef SYMBOL_CALC_MODE_EXCH_STOCKS
   if(calc_mode == SYMBOL_CALC_MODE_EXCH_STOCKS)
      return true;
#endif
#ifdef SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX
   if(calc_mode == SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX)
      return true;
#endif
   return false;
  }

string NormalizeSymbol(string s)
  {
   string out = s;
   StringTrimLeft(out);
   StringTrimRight(out);
   StringToUpper(out);
   StringReplace(out, " ", "");
   return out;
  }

bool IsMajorCurrency(const string ccy)
  {
   if(ccy == "USD") return true;
   if(ccy == "EUR") return true;
   if(ccy == "GBP") return true;
   if(ccy == "JPY") return true;
   if(ccy == "CHF") return true;
   if(ccy == "CAD") return true;
   if(ccy == "AUD") return true;
   if(ccy == "NZD") return true;
   return false;
  }

long ReadSymbolIntegerSafe(const string sym, const ENUM_SYMBOL_INFO_INTEGER prop, const long fallback)
  {
   ResetLastError();
   long v = 0;
   if(SymbolInfoInteger(sym, prop, v))
      return v;
   return fallback;
  }

double ReadSymbolDoubleSafe(const string sym, const ENUM_SYMBOL_INFO_DOUBLE prop, const double fallback)
  {
   ResetLastError();
   double v = 0.0;
   if(SymbolInfoDouble(sym, prop, v))
      return v;
   return fallback;
  }

string ReadSymbolStringSafe(const string sym, const ENUM_SYMBOL_INFO_STRING prop, const string fallback)
  {
   ResetLastError();
   string v = "";
   if(SymbolInfoString(sym, prop, v))
      return v;
   return fallback;
  }

int FlatSessionIndex(const int day, const int slot)
  {
   return day * MAX_SESSIONS_PER_DAY + slot;
  }

int HHMMFromSeconds(const int seconds_in_day)
  {
   int h = seconds_in_day / 3600;
   int m = (seconds_in_day % 3600) / 60;
   return h * 100 + m;
  }

int HHMMFromDateTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int DayOfWeekServer(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

bool IsTimeInsideSessions(const SessionWindow &arr[], const int day, const int hhmm_now)
  {
   int base = day * MAX_SESSIONS_PER_DAY;

   for(int i = 0; i < MAX_SESSIONS_PER_DAY; i++)
     {
      int idx = base + i;
      if(!arr[idx].active)
         continue;

      int start_hhmm = arr[idx].start_hhmm;
      int end_hhmm   = arr[idx].end_hhmm;

      if(start_hhmm <= end_hhmm)
        {
         if(hhmm_now >= start_hhmm && hhmm_now <= end_hhmm)
            return true;
        }
      else
        {
         if(hhmm_now >= start_hhmm)
            return true;
        }
     }

   int prev_day = day - 1;
   if(prev_day < 0)
      prev_day = DAYS_PER_WEEK - 1;

   int prev_base = prev_day * MAX_SESSIONS_PER_DAY;

   for(int j = 0; j < MAX_SESSIONS_PER_DAY; j++)
     {
      int idx2 = prev_base + j;
      if(!arr[idx2].active)
         continue;

      int start2 = arr[idx2].start_hhmm;
      int end2   = arr[idx2].end_hhmm;

      if(start2 > end2)
        {
         if(hhmm_now <= end2)
            return true;
        }
     }

   return false;
  }

void SortStringsAscending(string &arr[])
  {
   int n = ArraySize(arr);
   for(int i = 1; i < n; i++)
     {
      string key = arr[i];
      int j = i - 1;

      while(j >= 0 && StringCompare(arr[j], key) > 0)
        {
         arr[j + 1] = arr[j];
         j--;
        }

      arr[j + 1] = key;
     }
  }

int ScoreSymbolWorstness(SymbolRecord &rec)
  {
   int score = 0;

   if(!rec.selected_ok)
     {
      if(rec.select_fail_count >= 3) score += 100;
      else if(rec.select_fail_count == 2) score += 60;
      else if(rec.select_fail_count == 1) score += 25;
      return score;
     }

   if(!rec.spec_derived.spec_partial) score += 70;
   else if(!rec.spec_derived.spec_min_ready) score += 35;

   if(rec.hydration3a.dead_quote) score += 55;

   if(rec.tick_state.copyticks_phase == CT_COOLDOWN) score += 45;
   else if(rec.tick_state.copyticks_phase == CT_FAILING) score += 35;
   else if(rec.tick_state.copyticks_phase == CT_DEGRADED) score += 15;

   if(rec.tick_state.activity_class == SAC_ACTIVE)
     {
      if(!rec.tick_state.snapshot_path_ok) score += 50;

      // retained history absence matters, but much less than missing live snapshot
      if(!rec.tick_state.history_available) score += 10;
      else if(!rec.tick_state.history_fresh) score += 5;
     }
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
     {
      // closed market should not be punished heavily
      if(!rec.health.session_ready) score += 10;
     }
   else if(rec.tick_state.activity_class == SAC_DORMANT)
     {
      if(rec.tick_state.copyticks_phase == CT_FAILING) score += 8;
      if(rec.tick_state.copyticks_phase == CT_COOLDOWN) score += 12;
     }

   if(rec.cost.cost_state == COST_NONE && rec.spec_derived.spec_min_ready)
      score += 10;
   else if(rec.cost.cost_state == COST_PARTIAL)
      score += 5;

   score += rec.tick_state.copyticks_fail_count * 4;
   score += rec.select_fail_count * 3;

   return score;
  }

void BuildWorstSymbolLists(int &worst_idx[], int &worst_score[])
  {
   ArrayResize(worst_idx, 0);
   ArrayResize(worst_score, 0);

   for(int i = 0; i < g_universe.size; i++)
     {
      int score = ScoreSymbolWorstness(g_universe.records[i]);
      if(score <= 0)
         continue;

      int sz = ArraySize(worst_idx);
      ArrayResize(worst_idx, sz + 1);
      ArrayResize(worst_score, sz + 1);
      worst_idx[sz]   = i;
      worst_score[sz] = score;
     }

   SortWorstByScoreDescending(worst_idx, worst_score);
  }

int SumWeekSessionCounts(const int &counts[])
  {
   int total = 0;
   for(int i = 0; i < DAYS_PER_WEEK; i++)
      total += counts[i];
   return total;
  }

void SortWorstByScoreDescending(int &idxs[], int &scores[])
  {
   int n = ArraySize(scores);
   for(int i = 1; i < n; i++)
     {
      int key_score = scores[i];
      int key_idx   = idxs[i];
      int j = i - 1;

      while(j >= 0 && scores[j] < key_score)
        {
         scores[j + 1] = scores[j];
         idxs[j + 1]   = idxs[j];
         j--;
        }

      scores[j + 1] = key_score;
      idxs[j + 1]   = key_idx;
     }
  }

TickPathMode DeriveTickPathMode(const bool snapshot_ok, const bool history_ok)
  {
   if(snapshot_ok && history_ok) return TPM_BOTH;
   if(snapshot_ok)               return TPM_SNAPSHOT_ONLY;
   if(history_ok)                return TPM_COPYTICKS_ONLY;
   return TPM_NONE;
  }

string BuildPersistencePayloadHash(const SymbolRecord &rec)
  {
   string s = "";
   s += rec.raw_symbol + "|";
   s += rec.spec_change.spec_hash + "|";
   s += IntegerToString((int)rec.tick_state.copyticks_phase) + "|";
   s += LongToStringSafe(rec.tick_state.last_copied_msc) + "|";
   s += LongToStringSafe(rec.tick_state.last_meaningful_history_msc) + "|";
   s += DateTimeToSafeStr(rec.tick_state.copyticks_cooldown_until) + "|";
   s += IntegerToString(rec.tick_state.ring_count);
   return FNV1a32Hex(s);
  }

bool DidMaterialContinuityChange(SymbolRecord &rec)
  {
   // phase change
   if(rec.continuity.last_saved_copyticks_phase != (int)rec.tick_state.copyticks_phase)
      return true;

   // meaningful history progressed enough
   if(rec.tick_state.last_meaningful_history_msc > 0)
     {
      if(rec.continuity.last_saved_history_msc <= 0)
         return true;

      long delta = rec.tick_state.last_meaningful_history_msc - rec.continuity.last_saved_history_msc;
      if(delta >= InpPersistenceHistoryDeltaMs)
         return true;
     }

   // payload changed
   string new_hash = BuildPersistencePayloadHash(rec);
   if(rec.continuity.last_saved_payload_hash != new_hash)
      return true;

   return false;
  }

void RunFinalConsistencyPass()
  {
   for(int i = 0; i < g_universe.size; i++)
     {
      if(!g_universe.records[i].base_dirty)
         continue;

      RecomputeBaseState(g_universe.records[i]);
      g_universe.records[i].base_dirty = false;
     }
  }

bool IsKnownNumber(const double v)
  {
   if(v == INVALID_DBL)
      return false;
   if(!MathIsValidNumber(v))
      return false;
   return true;
  }

string BoolTo01(const bool v)
  {
   if(v)
      return "1";
   return "0";
  }

string DoubleToSafeStr(const double v)
  {
   if(!IsKnownNumber(v))
      return "null";
   return DoubleToString(v, 8);
  }

string IntToSafeStr(const int v)
  {
   if(v == INVALID_I32)
      return "null";
   return IntegerToString(v);
  }

string LongToSafeStr(const long v)
  {
   if(v == INVALID_TIME_MSC || v <= 0)
      return "null";
   return StringFormat("%I64d", v);
  }

string LongToStringSafe(const long v)
  {
   return StringFormat("%I64d", v);
  }
  
string StringToSafeStr(const string v)
  {
   if(v == "")
      return "null";
   return v;
  }

string DateTimeToSafeStr(const datetime v)
  {
   if(v <= 0)
      return "null";
   return TimeToString(v, TIME_DATE | TIME_SECONDS);
  }

string DateTimeToMinuteStr(const datetime v)
  {
   if(v <= 0)
      return "null";
   return TimeToString(v, TIME_DATE | TIME_MINUTES);
  }
  
  string ProvenanceValueToString(const ProvenanceValue v)
  {
   switch(v)
     {
      case PV_NONE:      return "PV_NONE";
      case PV_OBSERVED:  return "PV_OBSERVED";
      case PV_PROBED:    return "PV_PROBED";
      case PV_DERIVED:   return "PV_DERIVED";
      case PV_HEURISTIC: return "PV_HEURISTIC";
      case PV_MANUAL:    return "PV_MANUAL";
      case PV_FALLBACK:  return "PV_FALLBACK";
     }
   return "PV_NONE";
  }

string CostStateToString(const CostState v)
  {
   switch(v)
     {
      case COST_NONE:    return "COST_NONE";
      case COST_PARTIAL: return "COST_PARTIAL";
      case COST_READY:   return "COST_READY";
     }
   return "COST_NONE";
  }

string SummaryStateToString(const SummaryState v)
  {
   switch(v)
     {
      case SUM_UNKNOWN:  return "SUM_UNKNOWN";
      case SUM_GOOD:     return "SUM_GOOD";
      case SUM_PARTIAL:  return "SUM_PARTIAL";
      case SUM_DEGRADED: return "SUM_DEGRADED";
      case SUM_WARMUP:   return "SUM_WARMUP";
      case SUM_UNUSABLE: return "SUM_UNUSABLE";
     }
   return "SUM_UNKNOWN";
  }

string DataReasonCodeToString(const DataReasonCode v)
  {
   switch(v)
     {
      case DRC_NONE:               return "DRC_NONE";
      case DRC_OK:                 return "DRC_OK";
      case DRC_SELECT_FAILED:      return "DRC_SELECT_FAILED";
      case DRC_SPEC_PARTIAL:       return "DRC_SPEC_PARTIAL";
      case DRC_NO_TICK:            return "DRC_NO_TICK";
      case DRC_COPYTICKS_WARMUP:   return "DRC_COPYTICKS_WARMUP";
      case DRC_COPYTICKS_FAILING:  return "DRC_COPYTICKS_FAILING";
      case DRC_MARKET_CLOSED:      return "DRC_MARKET_CLOSED";
      case DRC_DORMANT:            return "DRC_DORMANT";
      case DRC_COST_PARTIAL:       return "DRC_COST_PARTIAL";
      case DRC_UNKNOWN:            return "DRC_UNKNOWN";
     }
   return "DRC_UNKNOWN";
  }

string TradabilityReasonCodeToString(const TradabilityReasonCode v)
  {
   switch(v)
     {
      case TRC_NONE:            return "TRC_NONE";
      case TRC_OK:              return "TRC_OK";
      case TRC_UNKNOWN:         return "TRC_UNKNOWN";
      case TRC_DISABLED:        return "TRC_DISABLED";
      case TRC_CLOSE_ONLY:      return "TRC_CLOSE_ONLY";
      case TRC_NOT_FULL_ACCESS: return "TRC_NOT_FULL_ACCESS";
     }
   return "TRC_UNKNOWN";
  }
  
  string PublishReasonCodeToString(const PublishReasonCode v)
  {
   switch(v)
     {
      case PRC_NONE:            return "PRC_NONE";
      case PRC_OK:              return "PRC_OK";
      case PRC_NOT_WRITTEN_YET: return "PRC_NOT_WRITTEN_YET";
      case PRC_WRITE_FAILED:    return "PRC_WRITE_FAILED";
      case PRC_UNKNOWN:         return "PRC_UNKNOWN";
     }
   return "PRC_UNKNOWN";
  }

string SpecStateExToString(const SpecStateEx v)
  {
   switch(v)
     {
      case SPX_NONE:    return "SPX_NONE";
      case SPX_PARTIAL: return "SPX_PARTIAL";
      case SPX_READY:   return "SPX_READY";
     }
   return "SPX_NONE";
  }

string SessionStateExToString(const SessionStateEx v)
  {
   switch(v)
     {
      case SSX_NONE:     return "SSX_NONE";
      case SSX_FALLBACK: return "SSX_FALLBACK";
      case SSX_READY:    return "SSX_READY";
     }
   return "SSX_NONE";
  }

string TradeStateExToString(const TradeStateEx v)
  {
   switch(v)
     {
      case TSX_UNKNOWN:    return "TSX_UNKNOWN";
      case TSX_DISABLED:   return "TSX_DISABLED";
      case TSX_CLOSE_ONLY: return "TSX_CLOSE_ONLY";
      case TSX_FULL:       return "TSX_FULL";
     }
   return "TSX_UNKNOWN";
  }

string PublishStateExToString(const PublishStateEx v)
  {
   switch(v)
     {
      case PSX_NONE:    return "PSX_NONE";
      case PSX_OK:      return "PSX_OK";
      case PSX_FAILING: return "PSX_FAILING";
     }
   return "PSX_NONE";
  }
  
string AssetClassToString(const AssetClass v)
  {
   switch(v)
     {
      case AC_UNKNOWN:   return "UNKNOWN";
      case AC_FX:        return "FX";
      case AC_METAL:     return "METAL";
      case AC_INDEX:     return "INDEX";
      case AC_STOCK:     return "STOCK";
      case AC_CRYPTO:    return "CRYPTO";
      case AC_COMMODITY: return "COMMODITY";
      case AC_CUSTOM:    return "CUSTOM";
     }
   return "UNKNOWN";
  }

string SpecLevelToString(const SpecLevel v)
  {
   switch(v)
     {
      case SL_NONE:      return "NONE";
      case SL_PARTIAL:   return "PARTIAL";
      case SL_MIN_READY: return "MIN_READY";
     }
   return "NONE";
  }

string TradabilityClassToString(const TradabilityClass v)
  {
   switch(v)
     {
      case TC_UNKNOWN:     return "UNKNOWN";
      case TC_FULL_ACCESS: return "FULL_ACCESS";
      case TC_CLOSE_ONLY:  return "CLOSE_ONLY";
      case TC_DISABLED:    return "DISABLED";
     }
   return "UNKNOWN";
  }

string MarketOpenStateToString(const MarketOpenState v)
  {
   switch(v)
     {
      case MOS_UNKNOWN:    return "UNKNOWN";
      case MOS_OPEN_NOW:   return "OPEN_NOW";
      case MOS_CLOSED_NOW: return "CLOSED_NOW";
     }
   return "UNKNOWN";
  }

string SymbolActivityClassToString(const SymbolActivityClass v)
  {
   switch(v)
     {
      case SAC_UNKNOWN:        return "UNKNOWN";
      case SAC_ACTIVE:         return "ACTIVE";
      case SAC_MARKET_CLOSED:  return "MARKET_CLOSED";
      case SAC_DORMANT:        return "DORMANT";
     }
   return "UNKNOWN";
  }

string TickPathModeToString(const TickPathMode v)
  {
   switch(v)
     {
      case TPM_NONE:           return "NONE";
      case TPM_SNAPSHOT_ONLY:  return "SNAPSHOT_ONLY";
      case TPM_COPYTICKS_ONLY: return "COPYTICKS_ONLY";
      case TPM_BOTH:           return "BOTH";
     }
   return "NONE";
  }

string CopyTicksPhaseToString(const CopyTicksPhase v)
  {
   switch(v)
     {
      case CT_NOT_STARTED: return "NOT_STARTED";
      case CT_FIRST_SYNC:  return "FIRST_SYNC";
      case CT_WARM:        return "WARM";
      case CT_STEADY:      return "STEADY";
      case CT_DEGRADED:    return "DEGRADED";
      case CT_FAILING:     return "FAILING";
      case CT_COOLDOWN:    return "COOLDOWN";
     }
   return "NOT_STARTED";
  }

string Phase2EventTypeToString(const Phase2EventType v)
  {
   switch(v)
     {
      case EVT_NONE:                     return "NONE";
      case EVT_COPYTICKS_START:          return "COPYTICKS_START";
      case EVT_COPYTICKS_FIRST_SYNC:     return "COPYTICKS_FIRST_SYNC";
      case EVT_COPYTICKS_APPEND:         return "COPYTICKS_APPEND";
      case EVT_COPYTICKS_SAME_MS_REJECT: return "COPYTICKS_SAME_MS_REJECT";
      case EVT_COPYTICKS_FAIL:           return "COPYTICKS_FAIL";
      case EVT_COPYTICKS_COOLDOWN_ENTER: return "COPYTICKS_COOLDOWN_ENTER";
      case EVT_COPYTICKS_RECOVER:        return "COPYTICKS_RECOVER";
      case EVT_HISTORY_READY:            return "HISTORY_READY";
      case EVT_HISTORY_DEGRADED:         return "HISTORY_DEGRADED";
     }
   return "NONE";
  }

string SymbolStateToString(const SymbolState st)
  {
   switch(st)
     {
      case SS_NEW:              return "NEW";
      case SS_SELECTED:         return "SELECTED";
      case SS_SPEC_PARTIAL:     return "SPEC_PARTIAL";
      case SS_SPEC_MIN_READY:   return "SPEC_READY";
      case SS_SESSION_PARTIAL:  return "SESSION_PARTIAL";
      case SS_SESSION_READY:    return "SESSION_READY";
      case SS_SNAPSHOT_PARTIAL: return "SNAPSHOT_PARTIAL";
      case SS_SNAPSHOT_VALID:   return "SNAPSHOT_VALID";
      case SS_HISTORY_VALID:    return "HISTORY_VALID";
     }
   return "UNKNOWN";
  }

string ReasonCodeToString(const ReasonCode rc)
  {
   switch(rc)
     {
      case RC_OK:                return "OK";
      case RC_INIT:              return "INIT";
      case RC_SELECT_FAILED:     return "SELECT_FAILED";
      case RC_SPEC_PARTIAL:      return "SPEC_PARTIAL";
      case RC_SESSION_FALLBACK:  return "SESSION_FALLBACK";
      case RC_NO_TICK:           return "NO_TICK";
      case RC_INVALID_TICK:      return "INVALID_TICK";
      case RC_COPYTICKS_WARMUP:  return "COPYTICKS_WARMUP";
      case RC_COPYTICKS_FAILING: return "COPYTICKS_FAILING";
      case RC_MARKET_CLOSED:     return "MARKET_CLOSED";
      case RC_DORMANT_SYMBOL:    return "DORMANT_SYMBOL";
      case RC_UNKNOWN:           return "UNKNOWN";
     }
   return "UNKNOWN";
  }

