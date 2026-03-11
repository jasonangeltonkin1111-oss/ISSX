
//+------------------------------------------------------------------+
//|                                       EA1_MarketCore_Lean.mq5    |
//| Lean broker-truth observability core                             |
//| Timer-only, no trading, no chart logic                           |
//+------------------------------------------------------------------+
#property strict
#property version   "2.000"
#property description "EA1 lean market observability core"

#define EA_NAME                 "EA1"
#define EA_ENGINE_VERSION       "2.0"
#define EA_SCHEMA_VERSION       "2.4"
#define EA_BUILD_CHANNEL        "lean"
#define EA_STAGE_NAME           "symbols_universe"
#define EA_DEBUG_NAME           "debug"

#define MAX_SYMBOLS_HARD        5000
#define MAX_SESSIONS_PER_DAY    8
#define DAYS_PER_WEEK           7
#define TICK_RING_CAPACITY      32
#define INVALID_TIME_MSC        (-1)
#define INVALID_I32             (-2147483647)
#define INVALID_DBL             (EMPTY_VALUE)

#define EA1_PUBLISH_OFFSET_SEC  1
#define EA1_PUBLISH_WINDOW_SEC  15
#define EA1_PERSIST_SCHEMA_VERSION 1

#define RC3_OK                  0
#define RC3_WARMING_UP          1
#define RC3_MARKET_CLOSED       2
#define RC3_TRADE_DISABLED      3
#define RC3_QUOTE_UNAVAILABLE   4
#define RC3_EXPIRED_OR_DELISTED 5
#define RC3_HYDRATION_TIMEOUT   6
#define RC3_COOLED_DOWN         7

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
input int    InpPersistenceSaveBudget       = 10;
input int    InpPersistenceFreshMaxAgeSec   = 7200;
input int    InpPersistenceSaveEverySec     = 300;
input int    InpPersistenceMinSaveGapSec    = 300;
input int    InpPersistenceHistoryDeltaMs   = 5000;
input int    InpPersistenceMaxWritesPerMin  = 60;
input bool   InpPersistenceBackupEnabled    = true;
input string InpFirmSuffix                  = "";

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

enum ProvenanceValue
  {
   PV_NONE = 0,
   PV_OBSERVED,
   PV_PROBED,
   PV_DERIVED,
   PV_HEURISTIC,
   PV_FALLBACK
  };

enum CostState
  {
   COST_NONE = 0,
   COST_PARTIAL,
   COST_READY
  };

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
   AssetClass       asset_class;
   TradabilityClass tradability_class;
   SpecLevel        spec_level;
   bool             spec_partial;
   bool             spec_min_ready;
   string           canonical_symbol;
   string           class_key;
   string           canonical_group;
   string           classification_source;
   int              classification_confidence;
  };

struct SymbolSessionState
  {
   SessionWindow quote_sessions[DAYS_PER_WEEK * MAX_SESSIONS_PER_DAY];
   SessionWindow trade_sessions[DAYS_PER_WEEK * MAX_SESSIONS_PER_DAY];
   int           quote_session_count[DAYS_PER_WEEK];
   int           trade_session_count[DAYS_PER_WEEK];
   bool          quote_session_open_now;
   bool          trade_session_open_now;
   bool          fallback_used;
   bool          sessions_loaded;
   bool          sessions_truncated;
   int           session_confidence;
  };

struct TickRingItem
  {
   long         time_msc;
   double       bid;
   double       ask;
   double       last;
   double       volume_real;
   unsigned int flags;
  };

struct SymbolTickState
  {
   bool               tick_valid;
   long               last_tick_time;
   long               last_tick_time_msc;
   double             bid;
   double             ask;
   double             mid;
   double             spread_points;

   bool               snapshot_path_ok;
   bool               history_available;
   bool               history_fresh;
   bool               history_path_ok;
   TickPathMode       tick_path_mode;
   CopyTicksPhase     copyticks_phase;
   MarketOpenState    market_open_state;
   SymbolActivityClass activity_class;
   bool               copyticks_eligible_now;

   long               last_snapshot_seen_msc;
   long               last_copyticks_seen_msc;
   long               last_copied_msc;
   long               last_meaningful_history_msc;
   int                history_last_batch_count;
   int                history_append_count;
   int                history_same_ms_reject_count;
   int                copyticks_fail_count;
   datetime           copyticks_cooldown_until;

   datetime           next_snapshot_due_server;
   datetime           next_copyticks_due_server;
   datetime           active_watch_due_server;
   datetime           dead_watch_due_server;
   datetime           reopen_watch_due_server;

   TickRingItem       ring[TICK_RING_CAPACITY];
   int                ring_head;
   int                ring_count;
   long               ring_overwrite_count;
  };

struct SymbolCostState
  {
   CostState       cost_state;
   bool            spread_complete;
   bool            carry_complete;
   bool            margin_complete;
   bool            usable_for_costs;

   double          tick_value_effective;
   ProvenanceValue tick_value_provenance;
   double          value_per_tick_money;
   ProvenanceValue value_per_tick_provenance;
   double          value_per_point_money;
   ProvenanceValue value_per_point_provenance;
   double          spread_value_money_1lot;
   ProvenanceValue spread_value_provenance;
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

struct SymbolHydrationState
  {
   int       reason_code_3a;
   int       hydration_attempts;
   datetime  cooled_down_until;
   datetime  first_open_without_tick_time;
   bool      market_open_now;
   bool      expired_or_disabled;
   bool      dead_quote;
   bool      spec_sanity_ok;
   int       spec_quality;
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
   SymbolCostState        cost;
   SymbolHydrationState   hydration;
   SymbolSpecChangeState  spec_change;
   SymbolContinuityState  continuity;
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
   int    write_err;
   int    move_err;
   int    copy_err;
   int    delete_err;
   int    bytes;
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
   bool perf_warn;
  };

UniverseState g_universe;
ScheduleState g_schedule;

PublishMetaState g_publish_stage;
PublishMetaState g_publish_debug;
IoLastState      g_io_last;
IoCounterState   g_io_counters;
PerfState        g_perf;

datetime g_last_hud_render_time = 0;
datetime g_last_temp_cleanup    = 0;
datetime g_last_coverage_recount= 0;
datetime g_init_server_time     = 0;

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

int  g_schedule_cursor_persist_save   = 0;
int  g_persist_writes_this_minute     = 0;
long g_persist_writes_minute_id       = -1;

long g_persist_load_ok_count          = 0;
long g_persist_load_fail_count        = 0;
long g_persist_save_ok_count          = 0;
long g_persist_save_fail_count        = 0;
long g_persist_stale_discard_count    = 0;
long g_persist_corrupt_discard_count  = 0;
long g_persist_incompat_discard_count = 0;

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
int g_market_open_count         = 0;
int g_market_closed_count       = 0;
int g_dead_quote_count          = 0;
int g_missing_spec_count        = 0;
int g_missing_tick_count        = 0;

long g_dbg_spec_reads           = 0;
long g_dbg_snapshot_reads       = 0;
long g_dbg_copyticks_calls      = 0;
long g_dbg_margin_probe_calls   = 0;
long g_dbg_session_load_calls   = 0;
long g_dbg_recompute_base_calls = 0;

string JsonEscape(const string s);
string JsonString(const string s);
string JsonBool(const bool v);
string JsonInt(const int v);
string JsonLong(const long v);
string JsonLongOrNull(const long v);
string JsonDoubleOrNull6(const double v);
string JsonDouble6(const double v);
string JsonDateTimeOrNull(const datetime v);
string JsonStringOrNull(const string s);
string BuildEA1MarketJson();
string BuildEA1DebugJson();

int ClampInt(const int v, const int lo, const int hi)
  {
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
  }

bool IsKnownNumber(const double v)
  {
   if(v == INVALID_DBL) return false;
   return MathIsValidNumber(v);
  }

string LongToStringSafe(const long v)
  {
   return StringFormat("%I64d", v);
  }

string DoubleToSafeStr(const double v)
  {
   if(!IsKnownNumber(v)) return "null";
   return DoubleToString(v, 8);
  }

string DateTimeToSafeStr(const datetime v)
  {
   if(v <= 0) return "null";
   return TimeToString(v, TIME_DATE | TIME_SECONDS);
  }

string EnsureTrailingBackslash(const string s)
  {
   string out = s;
   if(StringLen(out) > 0 && StringSubstr(out, StringLen(out) - 1, 1) != "\\")
      out += "\\";
   return out;
  }

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
      string tail = StringSubstr(out, StringLen(out)-1, 1);
      if(tail == "." || tail == "_" || tail == " ")
         out = StringSubstr(out, 0, StringLen(out)-1);
      else
         break;
     }
   if(out == "") out = "UNKNOWN_FIRM";
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

long GetMinuteId(const datetime t)
  {
   if(t <= 0) return -1;
   return (long)(t / 60);
  }

bool IsPublishWindowOpen(const datetime t, const int offset_sec, const int window_sec)
  {
   if(t <= 0) return false;
   int sec_in_min = (int)(t % 60);
   return (sec_in_min >= offset_sec && sec_in_min < offset_sec + window_sec);
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
   g_io_last.open_err   = 0;
   g_io_last.write_err  = 0;
   g_io_last.move_err   = 0;
   g_io_last.copy_err   = 0;
   g_io_last.delete_err = 0;
   g_io_last.bytes      = 0;
   g_io_last.guard_ok   = false;
   g_io_counters.io_ok_count = 0;
   g_io_counters.io_fail_count = 0;
  }

void ResetPerfState()
  {
   g_perf.dur_step_total_ms = 0;
   g_perf.dur_hydrate_ms = 0;
   g_perf.dur_build_stage_ms = 0;
   g_perf.dur_write_tmp_ms = 0;
   g_perf.dur_commit_ms = 0;
   g_perf.dur_backup_ms = 0;
   g_perf.perf_warn = false;
  }

void ResetSpecObserved(SymbolSpecObserved &spec)
  {
   spec.digits = INVALID_I32;
   spec.point = INVALID_DBL;
   spec.contract_size = INVALID_DBL;
   spec.tick_size = INVALID_DBL;
   spec.tick_value = INVALID_DBL;
   spec.volume_min = INVALID_DBL;
   spec.volume_max = INVALID_DBL;
   spec.volume_step = INVALID_DBL;
   spec.trade_mode = INVALID_I32;
   spec.calc_mode = INVALID_I32;
   spec.margin_currency = "";
   spec.profit_currency = "";
   spec.swap_long = INVALID_DBL;
   spec.swap_short = INVALID_DBL;
  }

void ResetSpecDerived(SymbolSpecDerived &spec)
  {
   spec.asset_class = AC_UNKNOWN;
   spec.tradability_class = TC_UNKNOWN;
   spec.spec_level = SL_NONE;
   spec.spec_partial = false;
   spec.spec_min_ready = false;
   spec.canonical_symbol = "";
   spec.class_key = "";
   spec.canonical_group = "";
   spec.classification_source = "";
   spec.classification_confidence = 0;
  }

void ResetSessionState(SymbolSessionState &sess)
  {
   for(int i = 0; i < DAYS_PER_WEEK * MAX_SESSIONS_PER_DAY; i++)
     {
      sess.quote_sessions[i].active = false;
      sess.quote_sessions[i].start_hhmm = 0;
      sess.quote_sessions[i].end_hhmm = 0;
      sess.trade_sessions[i].active = false;
      sess.trade_sessions[i].start_hhmm = 0;
      sess.trade_sessions[i].end_hhmm = 0;
     }
   for(int d = 0; d < DAYS_PER_WEEK; d++)
     {
      sess.quote_session_count[d] = 0;
      sess.trade_session_count[d] = 0;
     }
   sess.quote_session_open_now = false;
   sess.trade_session_open_now = false;
   sess.fallback_used = false;
   sess.sessions_loaded = false;
   sess.sessions_truncated = false;
   sess.session_confidence = 0;
  }

void ResetTickState(SymbolTickState &tick)
  {
   tick.tick_valid = false;
   tick.last_tick_time = 0;
   tick.last_tick_time_msc = INVALID_TIME_MSC;
   tick.bid = 0.0;
   tick.ask = 0.0;
   tick.mid = 0.0;
   tick.spread_points = 0.0;

   tick.snapshot_path_ok = false;
   tick.history_available = false;
   tick.history_fresh = false;
   tick.history_path_ok = false;
   tick.tick_path_mode = TPM_NONE;
   tick.copyticks_phase = CT_NOT_STARTED;
   tick.market_open_state = MOS_UNKNOWN;
   tick.activity_class = SAC_UNKNOWN;
   tick.copyticks_eligible_now = false;

   tick.last_snapshot_seen_msc = INVALID_TIME_MSC;
   tick.last_copyticks_seen_msc = INVALID_TIME_MSC;
   tick.last_copied_msc = INVALID_TIME_MSC;
   tick.last_meaningful_history_msc = INVALID_TIME_MSC;
   tick.history_last_batch_count = 0;
   tick.history_append_count = 0;
   tick.history_same_ms_reject_count = 0;
   tick.copyticks_fail_count = 0;
   tick.copyticks_cooldown_until = 0;

   tick.next_snapshot_due_server = 0;
   tick.next_copyticks_due_server = 0;
   tick.active_watch_due_server = 0;
   tick.dead_watch_due_server = 0;
   tick.reopen_watch_due_server = 0;

   tick.ring_head = 0;
   tick.ring_count = 0;
   tick.ring_overwrite_count = 0;
   for(int i = 0; i < TICK_RING_CAPACITY; i++)
     {
      tick.ring[i].time_msc = INVALID_TIME_MSC;
      tick.ring[i].bid = 0.0;
      tick.ring[i].ask = 0.0;
      tick.ring[i].last = 0.0;
      tick.ring[i].volume_real = 0.0;
      tick.ring[i].flags = 0;
     }
  }

void ResetCostState(SymbolCostState &cost)
  {
   cost.cost_state = COST_NONE;
   cost.spread_complete = false;
   cost.carry_complete = false;
   cost.margin_complete = false;
   cost.usable_for_costs = false;

   cost.tick_value_effective = INVALID_DBL;
   cost.tick_value_provenance = PV_NONE;
   cost.value_per_tick_money = INVALID_DBL;
   cost.value_per_tick_provenance = PV_NONE;
   cost.value_per_point_money = INVALID_DBL;
   cost.value_per_point_provenance = PV_NONE;
   cost.spread_value_money_1lot = INVALID_DBL;
   cost.spread_value_provenance = PV_NONE;
   cost.carry_long_1lot = INVALID_DBL;
   cost.carry_long_provenance = PV_NONE;
   cost.carry_short_1lot = INVALID_DBL;
   cost.carry_short_provenance = PV_NONE;
   cost.margin_1lot_money_buy = INVALID_DBL;
   cost.margin_buy_provenance = PV_NONE;
   cost.margin_1lot_money_sell = INVALID_DBL;
   cost.margin_sell_provenance = PV_NONE;
   cost.notional_exposure_estimate_1lot = INVALID_DBL;
   cost.exposure_provenance = PV_NONE;
   cost.cost_confidence = 0;
  }

void ResetHydrationState(SymbolHydrationState &st)
  {
   st.reason_code_3a = RC3_WARMING_UP;
   st.hydration_attempts = 0;
   st.cooled_down_until = 0;
   st.first_open_without_tick_time = 0;
   st.market_open_now = false;
   st.expired_or_disabled = false;
   st.dead_quote = false;
   st.spec_sanity_ok = false;
   st.spec_quality = 0;
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

void ResetGlobalState()
  {
   ArrayResize(g_universe.symbols, 0);
   ArrayResize(g_universe.records, 0);
   g_universe.size = 0;

   g_schedule.timer_tick_count = 0;
   g_schedule.timer_overrun_count = 0;
   g_schedule.last_timer_server_time = 0;
   g_schedule.now_server_time = 0;
   g_schedule.now_utc_time = 0;
   g_schedule.last_cycle_ms = 0;
   g_schedule.timer_busy = false;
   g_schedule.cursor_subscribe = 0;
   g_schedule.cursor_spec = 0;
   g_schedule.cursor_session = 0;
   g_schedule.cursor_snapshot = 0;
   g_schedule.cursor_copyticks = 0;
   g_schedule.cursor_cost = 0;
   g_schedule.cursor_consistency = 0;
   g_schedule.last_debug_write_time = 0;

   ResetPublishState(g_publish_stage);
   ResetPublishState(g_publish_debug);
   ResetIoState();
   ResetPerfState();

   g_last_hud_render_time = 0;
   g_last_temp_cleanup = 0;
   g_last_coverage_recount = 0;
   g_init_server_time = 0;
  }

void UpdateScheduleClock()
  {
   g_schedule.now_server_time = TimeCurrent();
   g_schedule.now_utc_time = TimeGMT();
   g_schedule.last_timer_server_time = g_schedule.now_server_time;
  }

long ReadSymbolIntegerSafe(const string sym, const ENUM_SYMBOL_INFO_INTEGER prop, const long fallback)
  {
   long v = 0;
   ResetLastError();
   if(SymbolInfoInteger(sym, prop, v))
      return v;
   return fallback;
  }

double ReadSymbolDoubleSafe(const string sym, const ENUM_SYMBOL_INFO_DOUBLE prop, const double fallback)
  {
   double v = 0.0;
   ResetLastError();
   if(SymbolInfoDouble(sym, prop, v))
      return v;
   return fallback;
  }

string ReadSymbolStringSafe(const string sym, const ENUM_SYMBOL_INFO_STRING prop, const string fallback)
  {
   string v = "";
   ResetLastError();
   if(SymbolInfoString(sym, prop, v))
      return v;
   return fallback;
  }

bool IsMajorCurrency(const string ccy)
  {
   return (ccy == "USD" || ccy == "EUR" || ccy == "GBP" || ccy == "JPY" ||
           ccy == "CHF" || ccy == "CAD" || ccy == "AUD" || ccy == "NZD");
  }

bool IsUpperAlpha(const int c)
  {
   return (c >= 'A' && c <= 'Z');
  }

bool IsLikelyTickerStockSymbol(const string s)
  {
   int n = StringLen(s);
   if(n < 1 || n > 6) return false;
   for(int i = 0; i < n; i++)
     {
      int c = StringGetCharacter(s, i);
      if(!IsUpperAlpha(c)) return false;
     }
   return true;
  }

bool IsHKStockSymbol(string s)
  {
   StringToUpper(s);
   return (StringFind(s, ".XHKG", 0) >= 0 || StringFind(s, ".HK", 0) >= 0);
  }

bool IsLikelyStockFromCalcMode(const int calc_mode)
  {
#ifdef SYMBOL_CALC_MODE_EXCH_STOCKS
   if(calc_mode == SYMBOL_CALC_MODE_EXCH_STOCKS) return true;
#endif
#ifdef SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX
   if(calc_mode == SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX) return true;
#endif
   return false;
  }

string NormalizeSymbol(string s)
  {
   StringTrimLeft(s);
   StringTrimRight(s);
   StringToUpper(s);
   StringReplace(s, " ", "");
   return s;
  }

string BuildCanonicalSymbol(string s)
  {
   string out = NormalizeSymbol(s);
   int p = StringFind(out, ".", 0);
   if(p > 0) out = StringSubstr(out, 0, p);
   p = StringFind(out, "#", 0);
   if(p > 0) out = StringSubstr(out, 0, p);
   p = StringFind(out, "-", 0);
   if(p > 0) out = StringSubstr(out, 0, p);

   if(out == "US100" || out == "USTEC" || out == "NAS" || out == "NAS100") return "NAS100";
   if(out == "DJ" || out == "DJ30" || out == "WS30" || out == "US30") return "US30";
   if(out == "SPX" || out == "US500" || out == "SPX500") return "SPX500";
   if(out == "DE40" || out == "DAX" || out == "GER40") return "GER40";
   if(out == "XAUUSD" || out == "GOLD") return "XAUUSD";
   if(out == "XAGUSD" || out == "SILVER") return "XAGUSD";
   return out;
  }

bool IsFXCanonical(string s)
  {
   if(StringLen(s) < 6) return false;
   string a = StringSubstr(s, 0, 3);
   string b = StringSubstr(s, 3, 3);
   return (IsMajorCurrency(a) && IsMajorCurrency(b));
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

int FlatSessionIndex(const int day, const int slot)
  {
   return day * MAX_SESSIONS_PER_DAY + slot;
  }

bool IsTimeInsideSessions(const SessionWindow &arr[], const int day, const int hhmm_now)
  {
   int base = day * MAX_SESSIONS_PER_DAY;
   for(int i = 0; i < MAX_SESSIONS_PER_DAY; i++)
     {
      int idx = base + i;
      if(!arr[idx].active) continue;
      int start_hhmm = arr[idx].start_hhmm;
      int end_hhmm = arr[idx].end_hhmm;
      if(start_hhmm <= end_hhmm)
        {
         if(hhmm_now >= start_hhmm && hhmm_now <= end_hhmm) return true;
        }
      else
        {
         if(hhmm_now >= start_hhmm) return true;
        }
     }

   int prev_day = day - 1;
   if(prev_day < 0) prev_day = DAYS_PER_WEEK - 1;
   int prev_base = prev_day * MAX_SESSIONS_PER_DAY;

   for(int j = 0; j < MAX_SESSIONS_PER_DAY; j++)
     {
      int idx2 = prev_base + j;
      if(!arr[idx2].active) continue;
      int start2 = arr[idx2].start_hhmm;
      int end2 = arr[idx2].end_hhmm;
      if(start2 > end2 && hhmm_now <= end2) return true;
     }
   return false;
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
   return StringFormat("%08X", FNV1a32(s));
  }

string BuildSymbolIdentityHash(const SymbolRecord &rec)
  {
   return FNV1a32Hex(g_firm_id + "|" + rec.raw_symbol + "|" + rec.normalized_symbol);
  }

string BuildPersistenceFilePath(const SymbolRecord &rec)
  {
   return g_persistence_dir_ea1 + BuildSymbolIdentityHash(rec) + ".bin";
  }

string BuildPersistenceBackupPath(const SymbolRecord &rec)
  {
   return g_persistence_dir_ea1 + BuildSymbolIdentityHash(rec) + ".bak";
  }

string BuildUniverseFingerprint()
  {
   string acc = "";
   for(int i = 0; i < g_universe.size; i++)
     {
      if(i > 0) acc += "|";
      acc += g_universe.records[i].raw_symbol;
     }
   return FNV1a32Hex(acc);
  }

void InitFirmFiles()
  {
   g_firm_id   = BuildFirmId();
   g_firm_name = g_firm_id;

   string firms_root = "FIRMS\\";
   string firm_dir   = firms_root + g_firm_id + "\\";

   FolderCreate("FIRMS", FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir, 0, StringLen(firm_dir) - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "outputs\\", 0, StringLen(firm_dir + "outputs\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "persistence\\", 0, StringLen(firm_dir + "persistence\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "persistence\\ea1\\", 0, StringLen(firm_dir + "persistence\\ea1\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "tmp\\", 0, StringLen(firm_dir + "tmp\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "tmp\\ea1\\", 0, StringLen(firm_dir + "tmp\\ea1\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "locks\\", 0, StringLen(firm_dir + "locks\\") - 1), FILE_COMMON);

   g_base_dir            = firm_dir;
   g_outputs_dir         = firm_dir + "outputs\\";
   g_tmp_dir_ea1         = firm_dir + "tmp\\ea1\\";
   g_locks_dir           = firm_dir + "locks\\";
   g_persistence_dir_ea1 = firm_dir + "persistence\\ea1\\";

   g_stage_file             = firms_root + g_firm_id + "_symbols_universe.json";
   g_debug_json_file        = firms_root + g_firm_id + "_debug_ea1.json";
   g_stage_prev_file        = g_outputs_dir + g_firm_id + "_symbols_universe_prev.json";
   g_stage_backup_file      = g_outputs_dir + g_firm_id + "_symbols_universe_backup.json";
   g_debug_json_prev_file   = g_outputs_dir + g_firm_id + "_debug_ea1_prev.json";
   g_debug_json_backup_file = g_outputs_dir + g_firm_id + "_debug_ea1_backup.json";
  }

void InitSymbolRecord(SymbolRecord &rec, const string symbol)
  {
   rec.raw_symbol = symbol;
   rec.normalized_symbol = NormalizeSymbol(symbol);
   rec.selected_ok = false;
   rec.select_fail_count = 0;
   rec.base_dirty = true;
   rec.spec_dirty = true;
   rec.session_dirty = true;
   rec.tick_dirty = true;
   rec.cost_dirty = true;
   rec.last_spec_refresh_time = 0;
   rec.last_session_refresh_time = 0;
   rec.last_cost_refresh_time = 0;
   rec.last_margin_probe_time = 0;
   ResetSpecObserved(rec.spec_observed);
   ResetSpecDerived(rec.spec_derived);
   ResetSessionState(rec.session_state);
   ResetTickState(rec.tick_state);
   ResetCostState(rec.cost);
   ResetHydrationState(rec.hydration);
   ResetSpecChangeState(rec.spec_change);
   ResetContinuityState(rec.continuity);
  }

void BuildUniverse()
  {
   ArrayResize(g_universe.symbols, 0);
   ArrayResize(g_universe.records, 0);
   g_universe.size = 0;

   bool selected_only = InpUseMarketWatchOnly;
   int total = SymbolsTotal(selected_only);
   if(total <= 0) return;

   string temp_symbols[];
   ArrayResize(temp_symbols, total);

   int count = 0;
   for(int i = 0; i < total; i++)
     {
      string sym = SymbolName(i, selected_only);
      if(sym == "") continue;
      temp_symbols[count++] = sym;
     }

   ArrayResize(temp_symbols, count);
   SortStringsAscending(temp_symbols);

   int take = count;
   if(InpUniverseMaxSymbols > 0 && InpUniverseMaxSymbols < take) take = InpUniverseMaxSymbols;
   if(take > MAX_SYMBOLS_HARD) take = MAX_SYMBOLS_HARD;

   ArrayResize(g_universe.symbols, take);
   ArrayResize(g_universe.records, take);
   for(int j = 0; j < take; j++)
     {
      g_universe.symbols[j] = temp_symbols[j];
      InitSymbolRecord(g_universe.records[j], temp_symbols[j]);
     }
   g_universe.size = take;
  }

string BuildSpecHash(const SymbolRecord &rec)
  {
   string s = "";
   s += rec.raw_symbol + "|";
   s += IntegerToString(rec.spec_observed.digits) + "|";
   s += DoubleToSafeStr(rec.spec_observed.point) + "|";
   s += DoubleToSafeStr(rec.spec_observed.contract_size) + "|";
   s += DoubleToSafeStr(rec.spec_observed.tick_size) + "|";
   s += DoubleToSafeStr(rec.spec_observed.tick_value) + "|";
   s += DoubleToSafeStr(rec.spec_observed.volume_min) + "|";
   s += DoubleToSafeStr(rec.spec_observed.volume_max) + "|";
   s += DoubleToSafeStr(rec.spec_observed.volume_step) + "|";
   s += IntegerToString(rec.spec_observed.trade_mode) + "|";
   s += IntegerToString(rec.spec_observed.calc_mode) + "|";
   s += rec.spec_observed.margin_currency + "|";
   s += rec.spec_observed.profit_currency + "|";
   s += IntegerToString((int)rec.spec_derived.asset_class) + "|";
   s += IntegerToString((int)rec.spec_derived.tradability_class);
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
   rec.base_dirty = true;
   rec.continuity.persistence_dirty = true;
   rec.last_spec_refresh_time = g_schedule.now_server_time;
  }

void DeriveSpecState(SymbolRecord &rec)
  {
   bool digits_ok = (rec.spec_observed.digits != INVALID_I32 && rec.spec_observed.digits >= 0);
   bool point_ok  = (IsKnownNumber(rec.spec_observed.point) && rec.spec_observed.point > 0.0);
   bool mode_ok   = (rec.spec_observed.trade_mode != INVALID_I32 || rec.spec_observed.calc_mode != INVALID_I32);

   rec.spec_derived.spec_partial = false;
   rec.spec_derived.spec_min_ready = false;
   rec.spec_derived.spec_level = SL_NONE;

   if(digits_ok || point_ok || mode_ok)
     {
      rec.spec_derived.spec_partial = true;
      rec.spec_derived.spec_level = SL_PARTIAL;
     }

   if(digits_ok && point_ok && mode_ok)
     {
      rec.spec_derived.spec_min_ready = true;
      rec.spec_derived.spec_level = SL_MIN_READY;
     }
  }

void UpdateTradability(SymbolRecord &rec)
  {
   rec.spec_derived.tradability_class = TC_UNKNOWN;
   int mode = rec.spec_observed.trade_mode;
   if(mode == INVALID_I32) return;
   switch(mode)
     {
      case 0: rec.spec_derived.tradability_class = TC_DISABLED; return;
      case 3: rec.spec_derived.tradability_class = TC_CLOSE_ONLY; return;
      case 4: rec.spec_derived.tradability_class = TC_FULL_ACCESS; return;
      default: rec.spec_derived.tradability_class = TC_UNKNOWN; return;
     }
  }

void UpdateAssetClass(SymbolRecord &rec)
  {
   string c = BuildCanonicalSymbol(rec.normalized_symbol);
   rec.spec_derived.canonical_symbol = c;
   rec.spec_derived.asset_class = AC_CUSTOM;
   rec.spec_derived.class_key = "custom";
   rec.spec_derived.canonical_group = "custom";
   rec.spec_derived.classification_source = "fallback_custom";
   rec.spec_derived.classification_confidence = 20;

   if(IsFXCanonical(c))
     {
      rec.spec_derived.asset_class = AC_FX;
      rec.spec_derived.class_key = "fx";
      rec.spec_derived.canonical_group = "fx";
      rec.spec_derived.classification_source = "canonical_fx";
      rec.spec_derived.classification_confidence = 95;
      return;
     }

   if(c == "XAUUSD" || c == "XAGUSD" || c == "XPTUSD" || c == "XPDUSD" ||
      c == "XAU" || c == "XAG" || c == "XPT" || c == "XPD" || c == "GOLD" || c == "SILVER")
     {
      rec.spec_derived.asset_class = AC_METAL;
      rec.spec_derived.class_key = "metal";
      rec.spec_derived.canonical_group = "metal";
      rec.spec_derived.classification_source = "canonical_metal";
      rec.spec_derived.classification_confidence = 90;
      return;
     }

   if(StringFind(c, "BTC") >= 0 || StringFind(c, "ETH") >= 0 || StringFind(c, "SOL") >= 0 ||
      StringFind(c, "XRP") >= 0 || StringFind(c, "ADA") >= 0 || StringFind(c, "DOGE") >= 0)
     {
      rec.spec_derived.asset_class = AC_CRYPTO;
      rec.spec_derived.class_key = "crypto";
      rec.spec_derived.canonical_group = "crypto";
      rec.spec_derived.classification_source = "canonical_crypto";
      rec.spec_derived.classification_confidence = 85;
      return;
     }

   if(c == "US30" || c == "NAS100" || c == "SPX500" || c == "GER40" || c == "UK100" || c == "JP225" || c == "HK50")
     {
      rec.spec_derived.asset_class = AC_INDEX;
      rec.spec_derived.class_key = "index";
      rec.spec_derived.canonical_group = "index";
      rec.spec_derived.classification_source = "canonical_index";
      rec.spec_derived.classification_confidence = 90;
      return;
     }

   if(IsHKStockSymbol(rec.raw_symbol) || IsLikelyStockFromCalcMode(rec.spec_observed.calc_mode) ||
      (IsLikelyTickerStockSymbol(c) &&
       IsKnownNumber(rec.spec_observed.contract_size) && rec.spec_observed.contract_size == 1.0 &&
       IsKnownNumber(rec.spec_observed.volume_step) && rec.spec_observed.volume_step >= 1.0))
     {
      rec.spec_derived.asset_class = AC_STOCK;
      rec.spec_derived.class_key = "stock";
      rec.spec_derived.canonical_group = "stock";
      rec.spec_derived.classification_source = "stock_heuristic";
      rec.spec_derived.classification_confidence = 70;
      return;
     }
  }

void LoadSessions(SymbolRecord &rec)
  {
   ResetSessionState(rec.session_state);
   g_dbg_session_load_calls++;

   bool any_loaded = false;
   bool truncated = false;

   for(int day = 0; day < DAYS_PER_WEEK; day++)
     {
      datetime extra_from_q = 0, extra_to_q = 0, extra_from_t = 0, extra_to_t = 0;
      bool extra_quote = SymbolInfoSessionQuote(rec.raw_symbol, (ENUM_DAY_OF_WEEK)day, MAX_SESSIONS_PER_DAY, extra_from_q, extra_to_q);
      bool extra_trade = SymbolInfoSessionTrade(rec.raw_symbol, (ENUM_DAY_OF_WEEK)day, MAX_SESSIONS_PER_DAY, extra_from_t, extra_to_t);
      if(extra_quote || extra_trade) truncated = true;

      for(int slot = 0; slot < MAX_SESSIONS_PER_DAY; slot++)
        {
         datetime from_q = 0, to_q = 0, from_t = 0, to_t = 0;
         bool got_q = SymbolInfoSessionQuote(rec.raw_symbol, (ENUM_DAY_OF_WEEK)day, slot, from_q, to_q);
         bool got_t = SymbolInfoSessionTrade(rec.raw_symbol, (ENUM_DAY_OF_WEEK)day, slot, from_t, to_t);

         if(got_q)
           {
            int idxq = FlatSessionIndex(day, slot);
            rec.session_state.quote_sessions[idxq].active = true;
            rec.session_state.quote_sessions[idxq].start_hhmm = HHMMFromSeconds((int)from_q);
            rec.session_state.quote_sessions[idxq].end_hhmm = HHMMFromSeconds((int)to_q);
            rec.session_state.quote_session_count[day]++;
            any_loaded = true;
           }

         if(got_t)
           {
            int idxt = FlatSessionIndex(day, slot);
            rec.session_state.trade_sessions[idxt].active = true;
            rec.session_state.trade_sessions[idxt].start_hhmm = HHMMFromSeconds((int)from_t);
            rec.session_state.trade_sessions[idxt].end_hhmm = HHMMFromSeconds((int)to_t);
            rec.session_state.trade_session_count[day]++;
            any_loaded = true;
           }
        }
     }

   rec.session_state.sessions_loaded = any_loaded;
   rec.session_state.sessions_truncated = truncated;

   if(any_loaded)
     {
      rec.session_state.fallback_used = false;
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
         rec.session_state.fallback_used = true;
         rec.session_state.session_confidence = fallback_conf;
        }
     }

   rec.session_dirty = false;
   rec.base_dirty = true;
   rec.continuity.persistence_dirty = true;
   rec.last_session_refresh_time = g_schedule.now_server_time;
  }

void UpdateSessionOpenState(SymbolRecord &rec)
  {
   rec.session_state.quote_session_open_now = false;
   rec.session_state.trade_session_open_now = false;

   int day = DayOfWeekServer(g_schedule.now_server_time);
   int hhmm = HHMMFromDateTime(g_schedule.now_server_time);

   if(rec.session_state.sessions_loaded)
     {
      rec.session_state.quote_session_open_now = IsTimeInsideSessions(rec.session_state.quote_sessions, day, hhmm);
      rec.session_state.trade_session_open_now = IsTimeInsideSessions(rec.session_state.trade_sessions, day, hhmm);
      return;
     }

   if(rec.session_state.fallback_used)
     {
      if(rec.spec_derived.asset_class == AC_CRYPTO)
        {
         rec.session_state.quote_session_open_now = true;
         rec.session_state.trade_session_open_now = true;
        }
      else if(rec.spec_derived.asset_class == AC_FX || rec.spec_derived.asset_class == AC_METAL || rec.spec_derived.asset_class == AC_INDEX)
        {
         if(day >= 1 && day <= 5)
           {
            rec.session_state.quote_session_open_now = true;
            rec.session_state.trade_session_open_now = true;
           }
        }
     }
  }

bool IsRecentServerTickTime(const long tick_time_sec, const int fresh_sec)
  {
   if(g_schedule.now_server_time <= 0 || tick_time_sec <= 0 || fresh_sec <= 0) return false;
   long delta = (long)g_schedule.now_server_time - tick_time_sec;
   if(delta < 0) return false;
   return (delta <= fresh_sec);
  }

bool IsRecentServerTickTimeMsc(const long tick_time_msc, const int fresh_sec)
  {
   if(tick_time_msc <= 0 || fresh_sec <= 0) return false;
   return IsRecentServerTickTime((long)(tick_time_msc / 1000), fresh_sec);
  }

TickPathMode DeriveTickPathMode(const bool snapshot_ok, const bool history_ok)
  {
   if(snapshot_ok && history_ok) return TPM_BOTH;
   if(snapshot_ok) return TPM_SNAPSHOT_ONLY;
   if(history_ok) return TPM_COPYTICKS_ONLY;
   return TPM_NONE;
  }

bool CanBeHistoryReady(const CopyTicksPhase phase)
  {
   return (phase == CT_WARM || phase == CT_STEADY || phase == CT_DEGRADED);
  }

int GetLastRingIndex(const SymbolTickState &tick_state)
  {
   if(tick_state.ring_count <= 0) return -1;
   int idx = tick_state.ring_head - 1;
   if(idx < 0) idx = TICK_RING_CAPACITY - 1;
   return idx;
  }

bool AppendRingTick(SymbolRecord &rec, const MqlTick &tick)
  {
   int last_idx = GetLastRingIndex(rec.tick_state);
   if(last_idx >= 0)
     {
      TickRingItem prev = rec.tick_state.ring[last_idx];
      if(prev.time_msc == (long)tick.time_msc &&
         prev.bid == tick.bid &&
         prev.ask == tick.ask &&
         prev.last == tick.last &&
         prev.volume_real == tick.volume_real &&
         prev.flags == tick.flags)
        {
         rec.tick_state.history_same_ms_reject_count++;
         return false;
        }
     }

   int idx = rec.tick_state.ring_head;
   rec.tick_state.ring[idx].time_msc = (long)tick.time_msc;
   rec.tick_state.ring[idx].bid = tick.bid;
   rec.tick_state.ring[idx].ask = tick.ask;
   rec.tick_state.ring[idx].last = tick.last;
   rec.tick_state.ring[idx].volume_real = tick.volume_real;
   rec.tick_state.ring[idx].flags = tick.flags;

   rec.tick_state.ring_head++;
   if(rec.tick_state.ring_head >= TICK_RING_CAPACITY) rec.tick_state.ring_head = 0;
   if(rec.tick_state.ring_count < TICK_RING_CAPACITY) rec.tick_state.ring_count++;
   else rec.tick_state.ring_overwrite_count++;

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
         ticks[j+1] = ticks[j];
         j--;
        }
      ticks[j+1] = key;
     }
  }

void UpdateSymbolActivityState(SymbolRecord &rec)
  {
   MarketOpenState prev_market = rec.tick_state.market_open_state;
   SymbolActivityClass prev_activity = rec.tick_state.activity_class;

   rec.tick_state.market_open_state = MOS_UNKNOWN;
   rec.tick_state.activity_class = SAC_UNKNOWN;
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
   bool session_open_now = (rec.session_state.quote_session_open_now || rec.session_state.trade_session_open_now);

   if(rec.spec_derived.tradability_class == TC_DISABLED)
      rec.tick_state.market_open_state = MOS_CLOSED_NOW;
   else if(has_recent_quote)
      rec.tick_state.market_open_state = MOS_OPEN_NOW;
   else if(sessions_observed)
      rec.tick_state.market_open_state = (session_open_now ? MOS_OPEN_NOW : MOS_CLOSED_NOW);
   else if(sessions_fallback && has_any_tick_evidence)
      rec.tick_state.market_open_state = (session_open_now ? MOS_OPEN_NOW : MOS_CLOSED_NOW);
   else
      rec.tick_state.market_open_state = MOS_UNKNOWN;

   if(has_recent_quote) rec.tick_state.activity_class = SAC_ACTIVE;
   else if(rec.tick_state.market_open_state == MOS_CLOSED_NOW) rec.tick_state.activity_class = SAC_MARKET_CLOSED;
   else rec.tick_state.activity_class = SAC_DORMANT;

   if(g_schedule.now_server_time <= 0)
     {
      rec.tick_state.copyticks_eligible_now = true;
      rec.tick_state.next_snapshot_due_server = 0;
      return;
     }

   if(rec.tick_state.activity_class == SAC_ACTIVE)
      rec.tick_state.next_snapshot_due_server = g_schedule.now_server_time;
   else if(rec.tick_state.next_snapshot_due_server <= 0 || prev_activity != rec.tick_state.activity_class || prev_market != rec.tick_state.market_open_state)
      rec.tick_state.next_snapshot_due_server = g_schedule.now_server_time + MathMax(1, InpSnapshotClosedRecheckSec);

   int retry_sec = InpCopyTicksUnknownRecheckSec;
   if(rec.tick_state.activity_class == SAC_ACTIVE) retry_sec = InpCopyTicksActiveRecheckSec;
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED) retry_sec = InpCopyTicksClosedRecheckSec;
   else if(rec.tick_state.activity_class == SAC_DORMANT) retry_sec = has_any_tick_evidence ? InpCopyTicksDormantRecheckSec : InpCopyTicksUnknownRecheckSec;

   if(rec.tick_state.activity_class == SAC_ACTIVE)
      rec.tick_state.active_watch_due_server = g_schedule.now_server_time;
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
      rec.tick_state.reopen_watch_due_server = g_schedule.now_server_time + MathMax(1, retry_sec);
   else
      rec.tick_state.dead_watch_due_server = g_schedule.now_server_time + MathMax(1, retry_sec);

   if(rec.tick_state.activity_class == SAC_ACTIVE)
      rec.tick_state.next_copyticks_due_server = rec.tick_state.active_watch_due_server;
   else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED)
      rec.tick_state.next_copyticks_due_server = rec.tick_state.reopen_watch_due_server;
   else
      rec.tick_state.next_copyticks_due_server = rec.tick_state.dead_watch_due_server;

   if(rec.tick_state.copyticks_cooldown_until > g_schedule.now_server_time)
      rec.tick_state.copyticks_eligible_now = false;
   else if(rec.tick_state.next_copyticks_due_server <= 0)
      rec.tick_state.copyticks_eligible_now = true;
   else
      rec.tick_state.copyticks_eligible_now = (rec.tick_state.next_copyticks_due_server <= g_schedule.now_server_time);
  }

void UpdateHydrationState(SymbolRecord &rec)
  {
   rec.hydration.market_open_now = (rec.tick_state.market_open_state == MOS_OPEN_NOW);
   rec.hydration.expired_or_disabled = (rec.spec_derived.tradability_class == TC_DISABLED);

   rec.hydration.spec_sanity_ok =
      (rec.spec_derived.spec_min_ready &&
       IsKnownNumber(rec.spec_observed.point) && rec.spec_observed.point > 0.0 &&
       IsKnownNumber(rec.spec_observed.tick_size) && rec.spec_observed.tick_size > 0.0 &&
       IsKnownNumber(rec.spec_observed.contract_size) && rec.spec_observed.contract_size > 0.0 &&
       IsKnownNumber(rec.spec_observed.volume_step) && rec.spec_observed.volume_step > 0.0);

   int q = 0;
   if(rec.spec_derived.spec_partial) q += 25;
   if(rec.spec_derived.spec_min_ready) q += 35;
   if(IsKnownNumber(rec.spec_observed.contract_size) && rec.spec_observed.contract_size > 0.0) q += 10;
   if(IsKnownNumber(rec.spec_observed.tick_size) && rec.spec_observed.tick_size > 0.0) q += 10;
   if(IsKnownNumber(rec.spec_observed.tick_value) && rec.spec_observed.tick_value >= 0.0) q += 10;
   if(IsKnownNumber(rec.spec_observed.volume_step) && rec.spec_observed.volume_step > 0.0) q += 10;
   rec.hydration.spec_quality = ClampInt(q, 0, 100);

   if(rec.hydration.cooled_down_until > 0 && g_schedule.now_server_time >= rec.hydration.cooled_down_until)
     {
      rec.hydration.cooled_down_until = 0;
      rec.hydration.dead_quote = false;
      rec.hydration.hydration_attempts = 0;
     }

   if(rec.hydration.market_open_now && !rec.tick_state.snapshot_path_ok)
     {
      if(rec.hydration.first_open_without_tick_time <= 0)
         rec.hydration.first_open_without_tick_time = g_schedule.now_server_time;

      long missing_for = (long)g_schedule.now_server_time - (long)rec.hydration.first_open_without_tick_time;
      if(missing_for >= InpDeadQuoteAfterSec)
        {
         rec.hydration.dead_quote = true;
         if(rec.hydration.hydration_attempts < InpMaxHydrationAttempts)
            rec.hydration.hydration_attempts++;

         if(rec.hydration.hydration_attempts >= InpMaxHydrationAttempts)
            rec.hydration.cooled_down_until = g_schedule.now_server_time + MathMax(1, InpCopyTicksCooldownSec);
        }
     }
   else
     {
      rec.hydration.first_open_without_tick_time = 0;
      rec.hydration.dead_quote = false;
      rec.hydration.hydration_attempts = 0;
     }

   if(rec.hydration.cooled_down_until > 0 && g_schedule.now_server_time < rec.hydration.cooled_down_until)
      rec.hydration.reason_code_3a = RC3_COOLED_DOWN;
   else if(rec.hydration.expired_or_disabled)
      rec.hydration.reason_code_3a = RC3_EXPIRED_OR_DELISTED;
   else if(rec.spec_derived.tradability_class == TC_CLOSE_ONLY)
      rec.hydration.reason_code_3a = RC3_TRADE_DISABLED;
   else if(!rec.hydration.market_open_now)
      rec.hydration.reason_code_3a = RC3_MARKET_CLOSED;
   else if(rec.tick_state.snapshot_path_ok)
      rec.hydration.reason_code_3a = RC3_OK;
   else
     {
      long uptime = 0;
      if(g_init_server_time > 0 && g_schedule.now_server_time >= g_init_server_time)
         uptime = (long)g_schedule.now_server_time - (long)g_init_server_time;

      if(uptime < InpStartupGraceSec) rec.hydration.reason_code_3a = RC3_WARMING_UP;
      else if(rec.hydration.dead_quote) rec.hydration.reason_code_3a = RC3_HYDRATION_TIMEOUT;
      else rec.hydration.reason_code_3a = RC3_QUOTE_UNAVAILABLE;
     }
  }

void RecomputeBaseState(SymbolRecord &rec)
  {
   g_dbg_recompute_base_calls++;

   UpdateSessionOpenState(rec);
   UpdateSymbolActivityState(rec);

   bool snapshot_fresh = IsRecentServerTickTimeMsc(rec.tick_state.last_snapshot_seen_msc, InpActiveSnapshotFreshSec);
   bool history_fresh  = IsRecentServerTickTimeMsc(rec.tick_state.last_meaningful_history_msc, InpActiveSnapshotFreshSec);

   rec.tick_state.snapshot_path_ok = (rec.tick_state.tick_valid && snapshot_fresh);
   rec.tick_state.history_available = (rec.tick_state.ring_count > 0 && CanBeHistoryReady(rec.tick_state.copyticks_phase));
   rec.tick_state.history_fresh = (rec.tick_state.history_available && history_fresh &&
                                   rec.tick_state.copyticks_phase != CT_FAILING &&
                                   rec.tick_state.copyticks_phase != CT_COOLDOWN);
   rec.tick_state.history_path_ok = rec.tick_state.history_fresh;
   rec.tick_state.tick_path_mode = DeriveTickPathMode(rec.tick_state.snapshot_path_ok, rec.tick_state.history_path_ok);

   UpdateHydrationState(rec);
   rec.base_dirty = false;
  }

void ReadSnapshotTick(SymbolRecord &rec)
  {
   g_dbg_snapshot_reads++;
   MqlTick tick;
   ZeroMemory(tick);

   double old_bid = rec.tick_state.bid;
   double old_ask = rec.tick_state.ask;
   long old_time_msc = rec.tick_state.last_tick_time_msc;

   ResetLastError();
   bool ok = SymbolInfoTick(rec.raw_symbol, tick);
   if(!ok) return;
   if(tick.time <= 0) return;

   bool has_bid = (tick.bid > 0.0);
   bool has_ask = (tick.ask > 0.0);
   if(!(has_bid || has_ask)) return;

   bool materially_changed = (old_bid != tick.bid || old_ask != tick.ask || old_time_msc != (long)tick.time_msc);

   rec.tick_state.tick_valid = true;
   rec.tick_state.last_tick_time = (long)tick.time;
   rec.tick_state.last_tick_time_msc = (long)tick.time_msc;
   rec.tick_state.last_snapshot_seen_msc = (long)tick.time_msc;
   rec.tick_state.bid = tick.bid;
   rec.tick_state.ask = tick.ask;

   if(has_bid && has_ask)
     {
      rec.tick_state.mid = 0.5 * (tick.bid + tick.ask);
      if(IsKnownNumber(rec.spec_observed.point) && rec.spec_observed.point > 0.0)
         rec.tick_state.spread_points = (tick.ask - tick.bid) / rec.spec_observed.point;
     }
   else if(has_bid)
      rec.tick_state.mid = tick.bid;
   else
      rec.tick_state.mid = tick.ask;

   if(materially_changed)
     {
      rec.tick_dirty = true;
      rec.cost_dirty = true;
      rec.base_dirty = true;
     }
  }

bool ProbeMarginOneLot(SymbolRecord &rec, double &buy_margin, double &sell_margin)
  {
   g_dbg_margin_probe_calls++;
   buy_margin = INVALID_DBL;
   sell_margin = INVALID_DBL;
   if(!rec.selected_ok) return false;

   double price_buy = rec.tick_state.ask;
   double price_sell = rec.tick_state.bid;
   if(price_buy <= 0.0 && rec.tick_state.bid > 0.0) price_buy = rec.tick_state.bid;
   if(price_sell <= 0.0 && rec.tick_state.ask > 0.0) price_sell = rec.tick_state.ask;
   if(price_buy <= 0.0 || price_sell <= 0.0) return false;

   double out_margin = 0.0;
   bool ok_buy = OrderCalcMargin(ORDER_TYPE_BUY, rec.raw_symbol, 1.0, price_buy, out_margin);
   if(ok_buy) buy_margin = out_margin;
   out_margin = 0.0;
   bool ok_sell = OrderCalcMargin(ORDER_TYPE_SELL, rec.raw_symbol, 1.0, price_sell, out_margin);
   if(ok_sell) sell_margin = out_margin;
   return (ok_buy || ok_sell);
  }

void ComputeCostState(SymbolRecord &rec)
  {
   ResetCostState(rec.cost);

   bool tick_value_observed = (IsKnownNumber(rec.spec_observed.tick_value) && rec.spec_observed.tick_value >= 0.0);
   bool tick_size_ok = (IsKnownNumber(rec.spec_observed.tick_size) && rec.spec_observed.tick_size > 0.0);
   bool point_ok = (IsKnownNumber(rec.spec_observed.point) && rec.spec_observed.point > 0.0);
   bool spread_ok = (rec.tick_state.snapshot_path_ok &&
                     IsKnownNumber(rec.tick_state.spread_points) &&
                     rec.tick_state.spread_points >= 0.0 && point_ok);

   if(tick_value_observed)
     {
      rec.cost.tick_value_effective = rec.spec_observed.tick_value;
      rec.cost.tick_value_provenance = PV_OBSERVED;
     }

   if(IsKnownNumber(rec.cost.tick_value_effective) && tick_size_ok)
     {
      rec.cost.value_per_tick_money = rec.cost.tick_value_effective;
      rec.cost.value_per_tick_provenance = rec.cost.tick_value_provenance;
     }

   if(IsKnownNumber(rec.cost.tick_value_effective) && tick_size_ok && point_ok)
     {
      rec.cost.value_per_point_money = rec.cost.tick_value_effective * (rec.spec_observed.point / rec.spec_observed.tick_size);
      rec.cost.value_per_point_provenance = PV_DERIVED;
     }

   rec.cost.spread_complete = spread_ok;
   if(IsKnownNumber(rec.cost.value_per_point_money) && rec.cost.spread_complete)
     {
      rec.cost.spread_value_money_1lot = rec.tick_state.spread_points * rec.cost.value_per_point_money;
      rec.cost.spread_value_provenance = PV_DERIVED;
     }

   if(IsKnownNumber(rec.spec_observed.swap_long))
     {
      rec.cost.carry_long_1lot = rec.spec_observed.swap_long;
      rec.cost.carry_long_provenance = PV_OBSERVED;
     }

   if(IsKnownNumber(rec.spec_observed.swap_short))
     {
      rec.cost.carry_short_1lot = rec.spec_observed.swap_short;
      rec.cost.carry_short_provenance = PV_OBSERVED;
     }

   rec.cost.carry_complete = (IsKnownNumber(rec.cost.carry_long_1lot) && IsKnownNumber(rec.cost.carry_short_1lot));

   bool margin_probe_due = false;
   if(rec.last_margin_probe_time <= 0) margin_probe_due = true;
   else if((g_schedule.now_server_time - rec.last_margin_probe_time) >= MathMax(1, InpMarginProbeRefreshSec)) margin_probe_due = true;

   if(margin_probe_due && rec.tick_state.snapshot_path_ok)
     {
      double buy_margin = INVALID_DBL, sell_margin = INVALID_DBL;
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
      rec.cost.exposure_provenance = PV_HEURISTIC;
     }

   rec.cost.usable_for_costs = (rec.spec_derived.spec_min_ready &&
                                IsKnownNumber(rec.cost.value_per_point_money));

   bool any_meaningful =
      (IsKnownNumber(rec.cost.tick_value_effective) ||
       IsKnownNumber(rec.cost.value_per_tick_money) ||
       IsKnownNumber(rec.cost.value_per_point_money) ||
       IsKnownNumber(rec.cost.spread_value_money_1lot) ||
       IsKnownNumber(rec.cost.carry_long_1lot) ||
       IsKnownNumber(rec.cost.carry_short_1lot) ||
       IsKnownNumber(rec.cost.notional_exposure_estimate_1lot) ||
       rec.cost.spread_complete || rec.cost.carry_complete);

   if(IsKnownNumber(rec.cost.value_per_point_money) && rec.cost.spread_complete) rec.cost.cost_state = COST_READY;
   else if(any_meaningful) rec.cost.cost_state = COST_PARTIAL;
   else rec.cost.cost_state = COST_NONE;

   int conf = 0;
   if(rec.cost.tick_value_provenance == PV_OBSERVED) conf += 35;
   if(IsKnownNumber(rec.cost.value_per_point_money)) conf += 20;
   if(rec.cost.spread_complete) conf += 15;
   if(rec.cost.carry_complete) conf += 10;
   if(rec.cost.margin_complete) conf += 20;
   rec.cost.cost_confidence = ClampInt(conf, 0, 100);
  }

void RunSubscriptionBudget()
  {
   int n = g_universe.size;
   if(n <= 0) return;
   int work = MathMin(n, MathMax(1, InpSubscribeBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_subscribe++;
      if(g_schedule.cursor_subscribe >= n) g_schedule.cursor_subscribe = 0;

      if(g_universe.records[idx].selected_ok) continue;

      ResetLastError();
      bool ok = SymbolSelect(g_universe.records[idx].raw_symbol, true);
      if(ok) g_universe.records[idx].selected_ok = true;
      else g_universe.records[idx].select_fail_count++;

      g_universe.records[idx].base_dirty = true;
     }
  }

void RunSpecBudget()
  {
   int n = g_universe.size;
   if(n <= 0) return;
   int work = MathMin(n, MathMax(1, InpSpecBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_spec++;
      if(g_schedule.cursor_spec >= n) g_schedule.cursor_spec = 0;

      if(!g_universe.records[idx].selected_ok) continue;

      bool due = g_universe.records[idx].spec_dirty ||
                 g_universe.records[idx].last_spec_refresh_time <= 0 ||
                 (g_schedule.now_server_time - g_universe.records[idx].last_spec_refresh_time) >= MathMax(1, InpSpecRefreshSec);
      if(!due) continue;

      ReadSpecObserved(g_universe.records[idx]);
      DeriveSpecState(g_universe.records[idx]);
      UpdateTradability(g_universe.records[idx]);
      UpdateAssetClass(g_universe.records[idx]);
      RefreshSpecHash(g_universe.records[idx]);
      g_universe.records[idx].base_dirty = true;
     }
  }

void RunSessionBudget()
  {
   int n = g_universe.size;
   if(n <= 0) return;
   int work = MathMin(n, MathMax(1, InpSessionBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_session++;
      if(g_schedule.cursor_session >= n) g_schedule.cursor_session = 0;

      if(!g_universe.records[idx].selected_ok || !g_universe.records[idx].spec_derived.spec_partial) continue;

      bool due = !g_universe.records[idx].session_state.sessions_loaded ||
                 g_universe.records[idx].last_session_refresh_time <= 0 ||
                 (g_schedule.now_server_time - g_universe.records[idx].last_session_refresh_time) >= MathMax(1, InpSessionRefreshSec) ||
                 g_universe.records[idx].session_dirty;

      if(due)
         LoadSessions(g_universe.records[idx]);

      g_universe.records[idx].base_dirty = true;
     }
  }

void RunSnapshotBudget()
  {
   int n = g_universe.size;
   if(n <= 0) return;
   int work = MathMin(n, MathMax(1, InpSnapshotBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_snapshot++;
      if(g_schedule.cursor_snapshot >= n) g_schedule.cursor_snapshot = 0;

      if(!g_universe.records[idx].selected_ok || !g_universe.records[idx].spec_derived.spec_partial) continue;
      if(g_schedule.now_server_time > 0 && g_universe.records[idx].tick_state.next_snapshot_due_server > g_schedule.now_server_time) continue;

      g_universe.records[idx].tick_dirty = false;
      ReadSnapshotTick(g_universe.records[idx]);
      if(g_universe.records[idx].tick_dirty) g_universe.records[idx].base_dirty = true;
      else UpdateSymbolActivityState(g_universe.records[idx]);
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
         if(rec.tick_state.ring_count > 0) rec.tick_state.copyticks_phase = CT_STEADY;
         else rec.tick_state.copyticks_phase = CT_NOT_STARTED;
         int retry_sec = InpCopyTicksUnknownRecheckSec;
         if(rec.tick_state.activity_class == SAC_MARKET_CLOSED) retry_sec = InpCopyTicksClosedRecheckSec;
         else if(rec.tick_state.activity_class == SAC_DORMANT)
           {
            bool has_any_tick_evidence = (rec.tick_state.last_tick_time > 0 || rec.tick_state.last_snapshot_seen_msc > 0 ||
                                          rec.tick_state.last_meaningful_history_msc > 0 || rec.tick_state.ring_count > 0);
            retry_sec = has_any_tick_evidence ? InpCopyTicksDormantRecheckSec : InpCopyTicksUnknownRecheckSec;
           }
         rec.tick_state.next_copyticks_due_server = g_schedule.now_server_time + MathMax(1, retry_sec);
         return;
        }

      rec.tick_state.copyticks_fail_count++;
      if(rec.tick_state.copyticks_fail_count >= 3)
        {
         rec.tick_state.copyticks_phase = CT_COOLDOWN;
         rec.tick_state.copyticks_cooldown_until = g_schedule.now_server_time + MathMax(1, InpCopyTicksCooldownSec);
         rec.tick_state.next_copyticks_due_server = rec.tick_state.copyticks_cooldown_until;
         rec.continuity.persistence_dirty = true;
        }
      else
        {
         rec.tick_state.copyticks_phase = CT_FAILING;
         rec.tick_state.next_copyticks_due_server = g_schedule.now_server_time + MathMax(1, InpCopyTicksUnknownRecheckSec);
        }

      rec.base_dirty = true;
      return;
     }

   SortTicksAscending(ticks);

   int accepted = 0;
   long max_seen_msc = rec.tick_state.last_copyticks_seen_msc;
   long prev_meaningful = rec.tick_state.last_meaningful_history_msc;
   long prev_last_copied = rec.tick_state.last_copied_msc;

   if(rec.tick_state.copyticks_phase == CT_NOT_STARTED)
      rec.tick_state.copyticks_phase = CT_FIRST_SYNC;

   for(int i = 0; i < copied; i++)
     {
      if((long)ticks[i].time_msc <= 0) continue;
      if(rec.tick_state.last_copied_msc > 0 && (long)ticks[i].time_msc < rec.tick_state.last_copied_msc) continue;
      if((long)ticks[i].time_msc > max_seen_msc) max_seen_msc = (long)ticks[i].time_msc;
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
      rec.tick_state.copyticks_fail_count = 0;
      rec.tick_state.copyticks_cooldown_until = 0;
      rec.tick_state.last_meaningful_history_msc = rec.tick_state.last_copied_msc;
      rec.tick_state.copyticks_phase = (prev_last_copied <= 0 ? CT_WARM : CT_STEADY);
      rec.tick_dirty = true;
      rec.cost_dirty = true;
      rec.base_dirty = true;
      if(prev_meaningful <= 0 || (rec.tick_state.last_meaningful_history_msc - prev_meaningful) >= InpPersistenceHistoryDeltaMs)
         rec.continuity.persistence_dirty = true;
      rec.tick_state.next_copyticks_due_server = g_schedule.now_server_time + MathMax(1, InpCopyTicksActiveRecheckSec);
     }
   else
     {
      if(rec.tick_state.copyticks_phase == CT_STEADY) rec.tick_state.copyticks_phase = CT_DEGRADED;
      rec.base_dirty = true;
      int retry_sec = InpCopyTicksUnknownRecheckSec;
      if(rec.tick_state.activity_class == SAC_ACTIVE) retry_sec = InpCopyTicksActiveRecheckSec;
      else if(rec.tick_state.activity_class == SAC_MARKET_CLOSED) retry_sec = InpCopyTicksClosedRecheckSec;
      else if(rec.tick_state.activity_class == SAC_DORMANT) retry_sec = InpCopyTicksDormantRecheckSec;
      rec.tick_state.next_copyticks_due_server = g_schedule.now_server_time + MathMax(1, retry_sec);
     }
  }

void RunCopyTicksBudget()
  {
   int n = g_universe.size;
   if(n <= 0) return;
   int work = MathMin(n, MathMax(1, InpCopyTicksBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_copyticks++;
      if(g_schedule.cursor_copyticks >= n) g_schedule.cursor_copyticks = 0;

      UpdateSymbolActivityState(g_universe.records[idx]);
      if(!g_universe.records[idx].selected_ok || !g_universe.records[idx].spec_derived.spec_partial) continue;
      if(!g_universe.records[idx].tick_state.copyticks_eligible_now) continue;

      CopyTicksForSymbol(g_universe.records[idx]);
      g_universe.records[idx].base_dirty = true;
     }
  }

void RunCostBudget()
  {
   int n = g_universe.size;
   if(n <= 0) return;
   int work = MathMin(n, MathMax(1, InpCostBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_cost++;
      if(g_schedule.cursor_cost >= n) g_schedule.cursor_cost = 0;

      if(!g_universe.records[idx].selected_ok || !g_universe.records[idx].spec_derived.spec_partial) continue;

      bool due = g_universe.records[idx].cost_dirty ||
                 g_universe.records[idx].last_cost_refresh_time <= 0 ||
                 (g_schedule.now_server_time - g_universe.records[idx].last_cost_refresh_time) >= MathMax(1, InpCostRefreshSec);
      if(!due) continue;

      ComputeCostState(g_universe.records[idx]);
      g_universe.records[idx].last_cost_refresh_time = g_schedule.now_server_time;
      g_universe.records[idx].cost_dirty = false;
     }
  }

void RunConsistencyBudget()
  {
   int n = g_universe.size;
   if(n <= 0) return;
   int work = MathMin(n, MathMax(1, InpConsistencyBudgetPerCycle));

   for(int k = 0; k < work; k++)
     {
      int idx = g_schedule.cursor_consistency++;
      if(g_schedule.cursor_consistency >= n) g_schedule.cursor_consistency = 0;

      if(!g_universe.records[idx].base_dirty) continue;
      RecomputeBaseState(g_universe.records[idx]);
     }
  }

bool WriteBinString(const int h, const string s)
  {
   int len = StringLen(s);
   FileWriteInteger(h, len, INT_VALUE);
   if(len > 0) FileWriteString(h, s, len);
   return true;
  }

bool ReadBinString(const int h, string &s)
  {
   s = "";
   if(FileIsEnding(h)) return false;
   int len = FileReadInteger(h, INT_VALUE);
   if(len < 0 || len > 4096) return false;
   if(len == 0) return true;
   s = FileReadString(h, len);
   return (StringLen(s) == len);
  }

bool WriteBinDateTime(const int h, const datetime v) { FileWriteLong(h, (long)v); return true; }
bool ReadBinDateTime(const int h, datetime &v) { if(FileIsEnding(h)) return false; v = (datetime)FileReadLong(h); return true; }
bool WriteBinDouble(const int h, const double v) { FileWriteDouble(h, v); return true; }
bool ReadBinDouble(const int h, double &v) { if(FileIsEnding(h)) return false; v = FileReadDouble(h); return true; }
bool WriteBinLong(const int h, const long v) { FileWriteLong(h, v); return true; }
bool ReadBinLong(const int h, long &v) { if(FileIsEnding(h)) return false; v = FileReadLong(h); return true; }
bool WriteBinInt(const int h, const int v) { FileWriteInteger(h, v, INT_VALUE); return true; }
bool ReadBinInt(const int h, int &v) { if(FileIsEnding(h)) return false; v = FileReadInteger(h, INT_VALUE); return true; }

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
   if(rec.continuity.last_saved_copyticks_phase != (int)rec.tick_state.copyticks_phase)
      return true;

   if(rec.tick_state.last_meaningful_history_msc > 0)
     {
      if(rec.continuity.last_saved_history_msc <= 0) return true;
      long delta = rec.tick_state.last_meaningful_history_msc - rec.continuity.last_saved_history_msc;
      if(delta >= InpPersistenceHistoryDeltaMs) return true;
     }

   string new_hash = BuildPersistencePayloadHash(rec);
   if(rec.continuity.last_saved_payload_hash != new_hash) return true;

   return false;
  }

bool BestEffortPersistenceBackup(const string final_rel, const string backup_rel)
  {
   if(!InpPersistenceBackupEnabled) return false;
   if(!FileIsExist(final_rel, FILE_COMMON)) return false;
   if(FileIsExist(backup_rel, FILE_COMMON)) FileDelete(backup_rel, FILE_COMMON);
   ResetLastError();
   if(FileCopy(final_rel, FILE_COMMON, backup_rel, FILE_COMMON))
     {
      g_io_counters.io_ok_count++;
      return true;
     }
   g_io_counters.io_fail_count++;
   return false;
  }

bool SaveSymbolPersistence(SymbolRecord &rec)
  {
   string final_rel = BuildPersistenceFilePath(rec);
   string backup_rel = BuildPersistenceBackupPath(rec);
   string tmp_rel = final_rel + ".tmp";

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

   ok &= WriteBinInt(h, EA1_PERSIST_SCHEMA_VERSION);
   ok &= WriteBinString(h, "2.0");
   ok &= WriteBinString(h, "2.4");
   ok &= WriteBinString(h, BuildSymbolIdentityHash(rec));
   ok &= WriteBinString(h, rec.raw_symbol);
   ok &= WriteBinString(h, rec.normalized_symbol);
   ok &= WriteBinDateTime(h, save_time);
   ok &= WriteBinString(h, rec.spec_change.spec_hash);

   ok &= WriteBinInt(h, (int)rec.tick_state.copyticks_phase);
   ok &= WriteBinLong(h, rec.tick_state.last_snapshot_seen_msc);
   ok &= WriteBinLong(h, rec.tick_state.last_copyticks_seen_msc);
   ok &= WriteBinLong(h, rec.tick_state.last_copied_msc);
   ok &= WriteBinLong(h, rec.tick_state.last_meaningful_history_msc);
   ok &= WriteBinInt(h, rec.tick_state.copyticks_fail_count);
   ok &= WriteBinDateTime(h, rec.tick_state.copyticks_cooldown_until);
   ok &= WriteBinDateTime(h, rec.tick_state.next_copyticks_due_server);
   ok &= WriteBinDateTime(h, rec.tick_state.active_watch_due_server);
   ok &= WriteBinDateTime(h, rec.tick_state.dead_watch_due_server);
   ok &= WriteBinDateTime(h, rec.tick_state.reopen_watch_due_server);

   int keep = MathMin(rec.tick_state.ring_count, 16);
   ok &= WriteBinInt(h, keep);
   int start = rec.tick_state.ring_head - keep;
   while(start < 0) start += TICK_RING_CAPACITY;
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

   string final_rel = BuildPersistenceFilePath(rec);
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
   string eng_ver = "", bp_ver = "", ident = "", raw = "", norm = "", persisted_spec_hash = "";
   datetime saved_at = 0;

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
      eng_ver != "2.0" ||
      bp_ver != "2.4" ||
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

   int phase = 0;
   ok &= ReadBinInt(h, phase);
   rec.tick_state.copyticks_phase = (CopyTicksPhase)phase;
   ok &= ReadBinLong(h, rec.tick_state.last_snapshot_seen_msc);
   ok &= ReadBinLong(h, rec.tick_state.last_copyticks_seen_msc);
   ok &= ReadBinLong(h, rec.tick_state.last_copied_msc);
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
         if(rec.tick_state.ring_head >= TICK_RING_CAPACITY) rec.tick_state.ring_head = 0;
         if(rec.tick_state.ring_count < TICK_RING_CAPACITY) rec.tick_state.ring_count++;
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

   // Critical truth boundary: do not restore live selection or live snapshot truth
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
   rec.tick_state.history_available = (rec.tick_state.ring_count > 0 && CanBeHistoryReady(rec.tick_state.copyticks_phase));
   rec.tick_state.history_fresh = false;
   rec.tick_state.history_path_ok = false;
   rec.tick_state.tick_path_mode = TPM_NONE;

   rec.continuity.persistence_state = PTX_LOADED_FRESH;
   rec.continuity.persistence_loaded = true;
   rec.continuity.persistence_fresh = true;
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

void InitPersistence()
  {
   if(!InpPersistenceEnabled) return;
   for(int i = 0; i < g_universe.size; i++)
      LoadSymbolPersistence(g_universe.records[i]);
  }

void RunPersistenceSaveBudget()
  {
   if(!InpPersistenceEnabled) return;
   int n = g_universe.size;
   if(n <= 0 || g_schedule.now_server_time <= 0) return;

   long minute_id = GetMinuteId(g_schedule.now_server_time);
   if(g_persist_writes_minute_id != minute_id)
     {
      g_persist_writes_minute_id = minute_id;
      g_persist_writes_this_minute = 0;
     }

   int work = MathMin(n, MathMax(1, InpPersistenceSaveBudget));
   for(int k = 0; k < work; k++)
     {
      if(g_persist_writes_this_minute >= InpPersistenceMaxWritesPerMin) return;

      int idx = g_schedule_cursor_persist_save++;
      if(g_schedule_cursor_persist_save >= n) g_schedule_cursor_persist_save = 0;

      if(!g_universe.records[idx].selected_ok || !g_universe.records[idx].spec_derived.spec_partial) continue;

      long since_last_save = 0;
      if(g_universe.records[idx].continuity.last_persistence_save_time > 0)
         since_last_save = (long)g_schedule.now_server_time - (long)g_universe.records[idx].continuity.last_persistence_save_time;

      bool checkpoint_due = (g_universe.records[idx].continuity.last_persistence_save_time <= 0 ||
                             since_last_save >= MathMax(1, InpPersistenceSaveEverySec));
      bool min_gap_ok = (g_universe.records[idx].continuity.last_persistence_save_time <= 0 ||
                         since_last_save >= MathMax(1, InpPersistenceMinSaveGapSec));
      bool material_due = DidMaterialContinuityChange(g_universe.records[idx]);

      bool due = false;
      if(g_universe.records[idx].continuity.persistence_dirty && min_gap_ok) due = true;
      else if(material_due && min_gap_ok) due = true;
      else if(checkpoint_due && material_due) due = true;

      if(!due) continue;

      long uptime_sec = 0;
      if(g_init_server_time > 0 && g_schedule.now_server_time >= g_init_server_time)
         uptime_sec = (long)g_schedule.now_server_time - (long)g_init_server_time;
      if(uptime_sec < InpStartupGraceSec && !material_due) continue;

      if(SaveSymbolPersistence(g_universe.records[idx]))
         g_persist_writes_this_minute++;
     }
  }

void RecountCoverage()
  {
   g_selected_count = 0;
   g_spec_ready_count = 0;
   g_session_ready_count = 0;
   g_tick_ready_count = 0;
   g_history_ready_count = 0;
   g_both_path_ready_count = 0;
   g_active_symbol_count = 0;
   g_closed_symbol_count = 0;
   g_dormant_symbol_count = 0;
   g_cost_ready_count = 0;
   g_cost_usable_count = 0;
   g_market_open_count = 0;
   g_market_closed_count = 0;
   g_dead_quote_count = 0;
   g_missing_spec_count = 0;
   g_missing_tick_count = 0;

   for(int i = 0; i < g_universe.size; i++)
     {
      if(g_universe.records[i].selected_ok) g_selected_count++;
      if(g_universe.records[i].spec_derived.spec_min_ready) g_spec_ready_count++;
      if(g_universe.records[i].session_state.sessions_loaded || g_universe.records[i].session_state.fallback_used) g_session_ready_count++;
      if(g_universe.records[i].tick_state.snapshot_path_ok) g_tick_ready_count++;
      if(g_universe.records[i].tick_state.history_path_ok) g_history_ready_count++;
      if(g_universe.records[i].tick_state.tick_path_mode == TPM_BOTH) g_both_path_ready_count++;
      if(g_universe.records[i].tick_state.activity_class == SAC_ACTIVE) g_active_symbol_count++;
      else if(g_universe.records[i].tick_state.activity_class == SAC_MARKET_CLOSED) g_closed_symbol_count++;
      else if(g_universe.records[i].tick_state.activity_class == SAC_DORMANT) g_dormant_symbol_count++;
      if(g_universe.records[i].cost.cost_state == COST_READY) g_cost_ready_count++;
      if(g_universe.records[i].cost.usable_for_costs) g_cost_usable_count++;
      if(g_universe.records[i].hydration.market_open_now) g_market_open_count++;
      else g_market_closed_count++;
      if(g_universe.records[i].hydration.dead_quote) g_dead_quote_count++;
      if(!g_universe.records[i].spec_derived.spec_min_ready) g_missing_spec_count++;
      if(g_universe.records[i].hydration.market_open_now && !g_universe.records[i].tick_state.snapshot_path_ok) g_missing_tick_count++;
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
   if(rec.hydration.dead_quote) score += 55;
   if(rec.tick_state.copyticks_phase == CT_COOLDOWN) score += 45;
   else if(rec.tick_state.copyticks_phase == CT_FAILING) score += 35;
   else if(rec.tick_state.copyticks_phase == CT_DEGRADED) score += 15;

   if(rec.tick_state.activity_class == SAC_ACTIVE)
     {
      if(!rec.tick_state.snapshot_path_ok) score += 50;
      if(!rec.tick_state.history_available) score += 10;
      else if(!rec.tick_state.history_fresh) score += 5;
     }

   if(rec.cost.cost_state == COST_NONE && rec.spec_derived.spec_min_ready) score += 10;
   else if(rec.cost.cost_state == COST_PARTIAL) score += 5;

   score += rec.tick_state.copyticks_fail_count * 4;
   score += rec.select_fail_count * 3;
   return score;
  }

void SortWorstByScoreDescending(int &idxs[], int &scores[])
  {
   int n = ArraySize(scores);
   for(int i = 1; i < n; i++)
     {
      int key_score = scores[i];
      int key_idx = idxs[i];
      int j = i - 1;
      while(j >= 0 && scores[j] < key_score)
        {
         scores[j+1] = scores[j];
         idxs[j+1] = idxs[j];
         j--;
        }
      scores[j+1] = key_score;
      idxs[j+1] = key_idx;
     }
  }

void BuildWorstSymbolLists(int &worst_idx[], int &worst_score[])
  {
   ArrayResize(worst_idx, 0);
   ArrayResize(worst_score, 0);
   for(int i = 0; i < g_universe.size; i++)
     {
      int score = ScoreSymbolWorstness(g_universe.records[i]);
      if(score <= 0) continue;
      int sz = ArraySize(worst_idx);
      ArrayResize(worst_idx, sz + 1);
      ArrayResize(worst_score, sz + 1);
      worst_idx[sz] = i;
      worst_score[sz] = score;
     }
   SortWorstByScoreDescending(worst_idx, worst_score);
  }

string BuildWorstSymbolsText()
  {
   int worst_idx[];
   int worst_score[];
   BuildWorstSymbolLists(worst_idx, worst_score);
   int rows = MathMin(ArraySize(worst_idx), 5);
   if(rows <= 0) return "None\n";

   string out = "";
   for(int i = 0; i < rows; i++)
     {
      int idx = worst_idx[i];
      out += g_universe.records[idx].raw_symbol;
      out += " | ";
      out += IntegerToString(worst_score[i]);
      out += " | ";
      out += IntegerToString((int)g_universe.records[idx].tick_state.activity_class);
      out += " | ";
      out += IntegerToString((int)g_universe.records[idx].tick_state.tick_path_mode);
      out += " | ";
      out += IntegerToString((int)g_universe.records[idx].tick_state.copyticks_phase);
      out += "\n";
     }
   return out;
  }

void RenderHUD()
  {
   string text = "";
   text += EA_NAME + " " + EA_BUILD_CHANNEL + "\n";
   text += "Server: " + TimeToString(g_schedule.now_server_time, TIME_DATE | TIME_MINUTES) + "\n";
   text += "Universe: " + IntegerToString(g_universe.size) + "\n";
   text += "Selected: " + IntegerToString(g_selected_count) + "\n";
   text += "Spec Ready: " + IntegerToString(g_spec_ready_count) + "\n";
   text += "Snapshot Ready: " + IntegerToString(g_tick_ready_count) + "\n";
   text += "History Ready: " + IntegerToString(g_history_ready_count) + "\n";
   text += "Cost Ready: " + IntegerToString(g_cost_ready_count) + "\n";
   text += "Open: " + IntegerToString(g_market_open_count) + "\n";
   text += "Closed: " + IntegerToString(g_market_closed_count) + "\n";
   text += "Dead Quote: " + IntegerToString(g_dead_quote_count) + "\n";
   text += "PerfWarn: " + (g_perf.perf_warn ? "1" : "0") + "\n";
   text += "Stage OK: " + (g_publish_stage.ok ? "1" : "0") + "\n";
   text += "Debug OK: " + (g_publish_debug.ok ? "1" : "0") + "\n";
   text += "Firm: " + g_firm_id + "\n";
   text += "Worst:\n" + BuildWorstSymbolsText();
   Comment(text);
  }

bool PublishLockExists()
  {
   if(!InpEnablePublishLock) return false;
   string lock_path = g_locks_dir + "publish.lock";
   return FileIsExist(lock_path, FILE_COMMON);
  }

bool BestEffortPreservePrevious(const string current_rel, const string prev_rel)
  {
   if(!FileIsExist(current_rel, FILE_COMMON)) return false;
   if(FileIsExist(prev_rel, FILE_COMMON)) FileDelete(prev_rel, FILE_COMMON);
   ResetLastError();
   if(FileCopy(current_rel, FILE_COMMON, prev_rel, FILE_COMMON))
     {
      g_io_counters.io_ok_count++;
      return true;
     }
   g_io_counters.io_fail_count++;
   return false;
  }

string BuildTempFileName(const string tmp_dir, const string final_name, const long minute_id, const int write_seq)
  {
   return tmp_dir + final_name + "." + LongToStringSafe(minute_id) + "." + IntegerToString(write_seq) + ".tmp";
  }

bool WriteTextFileCommon(const string rel_path, const string content, int &bytes_written)
  {
   bytes_written = 0;
   g_io_last.last_file = rel_path;
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
   ResetLastError();
   if(FileMove(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      g_io_counters.io_ok_count++;
      return true;
     }

   if(FileIsExist(final_rel, FILE_COMMON))
      FileDelete(final_rel, FILE_COMMON);

   ResetLastError();
   if(FileMove(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      g_io_counters.io_ok_count++;
      return true;
     }

   ResetLastError();
   if(FileCopy(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      FileDelete(tmp_rel, FILE_COMMON);
      g_io_counters.io_ok_count++;
      return true;
     }

   g_io_counters.io_fail_count++;
   return false;
  }

bool BestEffortBackup(const string final_rel, const string backup_rel)
  {
   if(!InpEnableBackups) return false;
   if(!FileIsExist(final_rel, FILE_COMMON)) return false;
   if(FileIsExist(backup_rel, FILE_COMMON)) FileDelete(backup_rel, FILE_COMMON);
   ResetLastError();
   if(FileCopy(final_rel, FILE_COMMON, backup_rel, FILE_COMMON))
     {
      g_io_counters.io_ok_count++;
      return true;
     }
   g_io_counters.io_fail_count++;
   return false;
  }

string BuildCoverageOnlyJson()
  {
   string s = "{";
   s += "\"ready_tick_count\":" + IntegerToString(g_tick_ready_count) + ",";
   s += "\"ready_spec_count\":" + IntegerToString(g_spec_ready_count) + ",";
   s += "\"market_open_count\":" + IntegerToString(g_market_open_count) + ",";
   s += "\"market_closed_count\":" + IntegerToString(g_market_closed_count) + ",";
   s += "\"dead_quote_count\":" + IntegerToString(g_dead_quote_count) + ",";
   s += "\"missing_tick_count\":" + IntegerToString(g_missing_tick_count) + ",";
   s += "\"missing_spec_count\":" + IntegerToString(g_missing_spec_count);
   s += "}";
   return s;
  }

string BuildSymbolJson(const SymbolRecord &rec)
  {
   string s = "{";
   s += "\"raw_symbol\":" + JsonString(rec.raw_symbol) + ",";
   s += "\"norm_symbol\":" + JsonString(rec.normalized_symbol) + ",";

   s += "\"identity\":{";
   s += "\"raw_symbol\":" + JsonString(rec.raw_symbol) + ",";
   s += "\"norm_symbol\":" + JsonString(rec.normalized_symbol) + ",";
   s += "\"symbol_identity_hash\":" + JsonString(BuildSymbolIdentityHash(rec)) + ",";
   s += "\"asset_class\":" + JsonString(IntegerToString((int)rec.spec_derived.asset_class)) + ",";
   s += "\"class_key\":" + JsonString(rec.spec_derived.class_key) + ",";
   s += "\"canonical_group\":" + JsonString(rec.spec_derived.canonical_group) + ",";
   s += "\"classification_source\":" + JsonString(rec.spec_derived.classification_source) + ",";
   s += "\"classification_confidence\":" + IntegerToString(rec.spec_derived.classification_confidence);
   s += "},";

   s += "\"spec\":{";
   s += "\"digits\":" + JsonInt(rec.spec_observed.digits) + ",";
   s += "\"point\":" + JsonDoubleOrNull6(rec.spec_observed.point) + ",";
   s += "\"contract_size\":" + JsonDoubleOrNull6(rec.spec_observed.contract_size) + ",";
   s += "\"tick_size\":" + JsonDoubleOrNull6(rec.spec_observed.tick_size) + ",";
   s += "\"tick_value\":" + JsonDoubleOrNull6(rec.spec_observed.tick_value) + ",";
   s += "\"volume_min\":" + JsonDoubleOrNull6(rec.spec_observed.volume_min) + ",";
   s += "\"volume_max\":" + JsonDoubleOrNull6(rec.spec_observed.volume_max) + ",";
   s += "\"volume_step\":" + JsonDoubleOrNull6(rec.spec_observed.volume_step) + ",";
   s += "\"trade_mode\":" + JsonInt(rec.spec_observed.trade_mode) + ",";
   s += "\"calc_mode\":" + JsonInt(rec.spec_observed.calc_mode) + ",";
   s += "\"margin_currency\":" + JsonStringOrNull(rec.spec_observed.margin_currency) + ",";
   s += "\"profit_currency\":" + JsonStringOrNull(rec.spec_observed.profit_currency) + ",";
   s += "\"swap_long\":" + JsonDoubleOrNull6(rec.spec_observed.swap_long) + ",";
   s += "\"swap_short\":" + JsonDoubleOrNull6(rec.spec_observed.swap_short) + ",";
   s += "\"spec_partial\":" + JsonBool(rec.spec_derived.spec_partial) + ",";
   s += "\"spec_min_ready\":" + JsonBool(rec.spec_derived.spec_min_ready) + ",";
   s += "\"tradability_class\":" + JsonString(IntegerToString((int)rec.spec_derived.tradability_class)) + ",";
   s += "\"canonical_symbol\":" + JsonString(rec.spec_derived.canonical_symbol) + ",";
   s += "\"spec_hash\":" + JsonString(rec.spec_change.spec_hash);
   s += "},";

   s += "\"sessions\":{";
   s += "\"sessions_loaded\":" + JsonBool(rec.session_state.sessions_loaded) + ",";
   s += "\"sessions_truncated\":" + JsonBool(rec.session_state.sessions_truncated) + ",";
   s += "\"session_fallback\":" + JsonBool(rec.session_state.fallback_used) + ",";
   s += "\"session_confidence\":" + IntegerToString(rec.session_state.session_confidence) + ",";
   s += "\"quote_session_open_now\":" + JsonBool(rec.session_state.quote_session_open_now) + ",";
   s += "\"trade_session_open_now\":" + JsonBool(rec.session_state.trade_session_open_now);
   s += "},";

   s += "\"market_status\":{";
   s += "\"market_open_now\":" + JsonBool(rec.hydration.market_open_now) + ",";
   s += "\"reason_code\":" + IntegerToString(rec.hydration.reason_code_3a) + ",";
   s += "\"hydration_attempts\":" + IntegerToString(rec.hydration.hydration_attempts) + ",";
   s += "\"cooled_down_until\":" + JsonDateTimeOrNull(rec.hydration.cooled_down_until);
   s += "},";

   s += "\"market\":{";
   s += "\"bid\":" + JsonDouble6(rec.tick_state.snapshot_path_ok ? rec.tick_state.bid : 0.0) + ",";
   s += "\"ask\":" + JsonDouble6(rec.tick_state.snapshot_path_ok ? rec.tick_state.ask : 0.0) + ",";
   s += "\"mid\":" + JsonDouble6(rec.tick_state.snapshot_path_ok ? rec.tick_state.mid : 0.0) + ",";
   s += "\"spread_points\":" + JsonDouble6(rec.tick_state.snapshot_path_ok ? rec.tick_state.spread_points : 0.0);
   s += "},";

   s += "\"tick_history\":{";
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
   s += "\"tick_path_mode\":" + JsonString(IntegerToString((int)rec.tick_state.tick_path_mode)) + ",";
   s += "\"copyticks_phase\":" + JsonString(IntegerToString((int)rec.tick_state.copyticks_phase)) + ",";
   s += "\"ring_count\":" + IntegerToString(rec.tick_state.ring_count);
   s += "},";

   s += "\"cost\":{";
   s += "\"tick_value_effective\":" + JsonDoubleOrNull6(rec.cost.tick_value_effective) + ",";
   s += "\"value_per_tick_money\":" + JsonDoubleOrNull6(rec.cost.value_per_tick_money) + ",";
   s += "\"value_per_point_money\":" + JsonDoubleOrNull6(rec.cost.value_per_point_money) + ",";
   s += "\"spread_value_money_1lot\":" + JsonDoubleOrNull6(rec.cost.spread_value_money_1lot) + ",";
   s += "\"carry_long_1lot\":" + JsonDoubleOrNull6(rec.cost.carry_long_1lot) + ",";
   s += "\"carry_short_1lot\":" + JsonDoubleOrNull6(rec.cost.carry_short_1lot) + ",";
   s += "\"margin_1lot_money_buy\":" + JsonDoubleOrNull6(rec.cost.margin_1lot_money_buy) + ",";
   s += "\"margin_1lot_money_sell\":" + JsonDoubleOrNull6(rec.cost.margin_1lot_money_sell) + ",";
   s += "\"notional_exposure_estimate_1lot\":" + JsonDoubleOrNull6(rec.cost.notional_exposure_estimate_1lot) + ",";
   s += "\"cost_state\":" + JsonString(IntegerToString((int)rec.cost.cost_state)) + ",";
   s += "\"usable_for_costs\":" + JsonBool(rec.cost.usable_for_costs) + ",";
   s += "\"cost_confidence\":" + IntegerToString(rec.cost.cost_confidence);
   s += "},";

   s += "\"continuity\":{";
   s += "\"persistence_state\":" + JsonString(IntegerToString((int)rec.continuity.persistence_state)) + ",";
   s += "\"persistence_loaded\":" + JsonBool(rec.continuity.persistence_loaded) + ",";
   s += "\"persistence_fresh\":" + JsonBool(rec.continuity.persistence_fresh) + ",";
   s += "\"persistence_stale\":" + JsonBool(rec.continuity.persistence_stale) + ",";
   s += "\"persistence_corrupt\":" + JsonBool(rec.continuity.persistence_corrupt) + ",";
   s += "\"persistence_incompatible\":" + JsonBool(rec.continuity.persistence_incompatible) + ",";
   s += "\"resumed_from_persistence\":" + JsonBool(rec.continuity.resumed_from_persistence) + ",";
   s += "\"restarted_clean\":" + JsonBool(rec.continuity.restarted_clean) + ",";
   s += "\"persistence_age_sec\":" + IntegerToString(rec.continuity.persistence_age_sec) + ",";
   s += "\"continuity_origin\":" + JsonString(IntegerToString((int)rec.continuity.continuity_origin)) + ",";
   s += "\"continuity_last_good_server_time\":" + JsonDateTimeOrNull(rec.continuity.continuity_last_good_server_time);
   s += "}";

   s += "}";
   return s;
  }

string BuildEA1MarketJson()
  {
   string symbols = "[";
   for(int i = 0; i < g_universe.size; i++)
     {
      if(i > 0) symbols += ",";
      symbols += BuildSymbolJson(g_universe.records[i]);
     }
   symbols += "]";

   string out = "{";
   out += "\"producer\":\"EA1\",";
   out += "\"stage\":\"symbols_universe\",";
   out += "\"minute_id\":" + LongToStringSafe(g_publish_stage.minute_id) + ",";
   out += "\"universe_fingerprint\":" + JsonString(BuildUniverseFingerprint()) + ",";
   out += "\"universe\":{\"symbol_count\":" + IntegerToString(g_universe.size) + "},";
   out += "\"coverage\":" + BuildCoverageOnlyJson() + ",";
   out += "\"symbols\":" + symbols;
   out += "}";
   return out;
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
      if(i > 0) worst += ",";
      int idx = worst_idx[i];
      worst += "{";
      worst += "\"raw_symbol\":" + JsonString(g_universe.records[idx].raw_symbol) + ",";
      worst += "\"score\":" + IntegerToString(worst_score[i]) + ",";
      worst += "\"activity_class\":" + JsonString(IntegerToString((int)g_universe.records[idx].tick_state.activity_class)) + ",";
      worst += "\"tick_path_mode\":" + JsonString(IntegerToString((int)g_universe.records[idx].tick_state.tick_path_mode)) + ",";
      worst += "\"copyticks_phase\":" + JsonString(IntegerToString((int)g_universe.records[idx].tick_state.copyticks_phase)) + ",";
      worst += "\"snapshot_path_ok\":" + JsonBool(g_universe.records[idx].tick_state.snapshot_path_ok) + ",";
      worst += "\"history_path_ok\":" + JsonBool(g_universe.records[idx].tick_state.history_path_ok) + ",";
      worst += "\"market_open_now\":" + JsonBool(g_universe.records[idx].hydration.market_open_now) + ",";
      worst += "\"cost_state\":" + JsonString(IntegerToString((int)g_universe.records[idx].cost.cost_state)) + ",";
      worst += "\"persistence_state\":" + JsonString(IntegerToString((int)g_universe.records[idx].continuity.persistence_state));
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
   s += "\"perf\":{";
   s += "\"dur_step_total_ms\":" + IntegerToString(g_perf.dur_step_total_ms) + ",";
   s += "\"dur_hydrate_ms\":" + IntegerToString(g_perf.dur_hydrate_ms) + ",";
   s += "\"dur_build_stage_ms\":" + IntegerToString(g_perf.dur_build_stage_ms) + ",";
   s += "\"dur_write_tmp_ms\":" + IntegerToString(g_perf.dur_write_tmp_ms) + ",";
   s += "\"dur_commit_ms\":" + IntegerToString(g_perf.dur_commit_ms) + ",";
   s += "\"dur_backup_ms\":" + IntegerToString(g_perf.dur_backup_ms) + ",";
   s += "\"perf_warn\":" + JsonBool(g_perf.perf_warn);
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
   s += "\"engine_counts\":{";
   s += "\"spec_reads\":" + LongToStringSafe(g_dbg_spec_reads) + ",";
   s += "\"snapshot_reads\":" + LongToStringSafe(g_dbg_snapshot_reads) + ",";
   s += "\"copyticks_calls\":" + LongToStringSafe(g_dbg_copyticks_calls) + ",";
   s += "\"margin_probe_calls\":" + LongToStringSafe(g_dbg_margin_probe_calls) + ",";
   s += "\"session_load_calls\":" + LongToStringSafe(g_dbg_session_load_calls) + ",";
   s += "\"recompute_base_calls\":" + LongToStringSafe(g_dbg_recompute_base_calls);
   s += "},";
   s += "\"worst_symbols\":" + worst;
   s += "}";
   return s;
  }

void MaybePublishStage()
  {
   if(!InpPublishStageEnabled) return;
   if(g_schedule.now_server_time <= 0) return;

   long minute_id = GetMinuteId(g_schedule.now_server_time);
   if(minute_id < 0) return;
   if(!IsPublishWindowOpen(g_schedule.now_server_time, EA1_PUBLISH_OFFSET_SEC, EA1_PUBLISH_WINDOW_SEC)) return;
   if(g_publish_stage.last_published_minute_id >= minute_id) return;

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

   string tmp_rel = BuildTempFileName(g_tmp_dir_ea1, g_firm_id + "_symbols_universe.json", minute_id, g_publish_stage.write_seq);

   int bytes_written = 0;
   t0 = GetMicrosecondCount() / 1000;
   bool write_ok = WriteTextFileCommon(tmp_rel, json, bytes_written);
   g_perf.dur_write_tmp_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   if(!write_ok)
     {
      g_publish_stage.last_error = "write_tmp_failed";
      return;
     }

   g_io_last.guard_ok = (StringLen(json) >= 2 && StringSubstr(json, 0, 1) == "{" && StringSubstr(json, StringLen(json)-1, 1) == "}");
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
   if(!InpPublishDebugJsonEnabled) return;
   if(g_schedule.now_server_time <= 0) return;
   if(g_schedule.last_debug_write_time > 0 &&
      (g_schedule.now_server_time - g_schedule.last_debug_write_time) < MathMax(1, InpDebugWriteSec))
      return;

   long minute_id = GetMinuteId(g_schedule.now_server_time);
   if(minute_id < 0) return;

   g_publish_debug.attempted = true;
   g_publish_debug.ok = false;
   g_publish_debug.last_error = "";
   g_publish_debug.minute_id = minute_id;
   g_publish_debug.write_seq++;

   string json = BuildEA1DebugJson();
   string tmp_rel = BuildTempFileName(g_tmp_dir_ea1, g_firm_id + "_debug_ea1.json", minute_id, g_publish_debug.write_seq);

   int bytes_written = 0;
   if(!WriteTextFileCommon(tmp_rel, json, bytes_written))
     {
      g_publish_debug.last_error = "write_tmp_failed";
      return;
     }

   BestEffortPreservePrevious(g_debug_json_file, g_debug_json_prev_file);
   if(!CommitFileAtomic(tmp_rel, g_debug_json_file))
     {
      g_publish_debug.last_error = "commit_failed";
      return;
     }

   BestEffortBackup(g_debug_json_file, g_debug_json_backup_file);
   g_publish_debug.ok = true;
   g_publish_debug.last_published_minute_id = minute_id;
   g_schedule.last_debug_write_time = g_schedule.now_server_time;
  }

void MaybeCleanupTemp()
  {
   if(!InpEnableTempCleanup) return;
   if(g_schedule.now_server_time <= 0) return;
   if(g_last_temp_cleanup > 0 && (g_schedule.now_server_time - g_last_temp_cleanup) < InpTempCleanupEverySec)
      return;

   g_last_temp_cleanup = g_schedule.now_server_time;

   string patterns[2];
   patterns[0] = g_tmp_dir_ea1 + g_firm_id + "_symbols_universe.json*.tmp";
   patterns[1] = g_tmp_dir_ea1 + g_firm_id + "_debug_ea1.json*.tmp";

   for(int p = 0; p < 2; p++)
     {
      string found_name = "";
      long fh = FileFindFirst(patterns[p], found_name, FILE_COMMON);
      if(fh == INVALID_HANDLE) continue;

      do
        {
         if(found_name == "") continue;
         string full_path = g_tmp_dir_ea1 + found_name;
         int h = FileOpen(full_path, FILE_READ | FILE_BIN | FILE_COMMON);
         if(h != INVALID_HANDLE)
           {
            datetime mod_time = (datetime)FileGetInteger(h, FILE_MODIFY_DATE);
            FileClose(h);
            if(mod_time > 0 && (g_schedule.now_server_time - mod_time) >= InpTempCleanupAgeSec)
               FileDelete(full_path, FILE_COMMON);
           }
        }
      while(FileFindNext(fh, found_name));

      FileFindClose(fh);
     }
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
string JsonString(const string s) { return "\"" + JsonEscape(s) + "\""; }
string JsonBool(const bool v) { return v ? "true" : "false"; }
string JsonInt(const int v) { if(v == INVALID_I32) return "null"; return IntegerToString(v); }
string JsonLong(const long v) { return StringFormat("%I64d", v); }
string JsonLongOrNull(const long v) { if(v <= 0 || v == INVALID_TIME_MSC) return "null"; return JsonLong(v); }
string JsonDouble6(const double v) { return DoubleToString(v, 6); }
string JsonDoubleOrNull6(const double v) { if(!IsKnownNumber(v)) return "null"; return DoubleToString(v, 6); }
string JsonDateTimeOrNull(const datetime v) { if(v <= 0) return "null"; return JsonString(TimeToString(v, TIME_DATE | TIME_SECONDS)); }
string JsonStringOrNull(const string s) { if(s == "") return "null"; return JsonString(s); }

int OnInit()
  {
   ResetGlobalState();
   InitFirmFiles();
   BuildUniverse();
   g_init_server_time = TimeCurrent();
   InitPersistence();

   for(int i = 0; i < g_universe.size; i++)
      RecomputeBaseState(g_universe.records[i]);

   if(!EventSetTimer(MathMax(1, InpTimerIntervalSec)))
     {
      Print("Failed to start timer. Error=", GetLastError());
      return(INIT_FAILED);
     }

   if(InpShowHUD) Comment(EA_NAME, " ", EA_BUILD_CHANNEL, "\nInitializing...");
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

   if(InpShowHUD) Comment("");
  }

void OnTick()
  {
   // intentionally empty: timer-only EA
  }

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

   g_dbg_spec_reads = 0;
   g_dbg_snapshot_reads = 0;
   g_dbg_copyticks_calls = 0;
   g_dbg_margin_probe_calls = 0;
   g_dbg_session_load_calls = 0;
   g_dbg_recompute_base_calls = 0;

   ulong t_hydrate = GetMicrosecondCount() / 1000;

   RunSubscriptionBudget();
   RunSpecBudget();
   RunSessionBudget();
   RunSnapshotBudget();
   RunCopyTicksBudget();
   RunCostBudget();
   RunConsistencyBudget();
   RunPersistenceSaveBudget();

   g_perf.dur_hydrate_ms = (int)((GetMicrosecondCount() / 1000) - t_hydrate);

   if(g_last_coverage_recount == 0 || (g_schedule.now_server_time - g_last_coverage_recount) >= MathMax(1, InpCoverageRefreshSec))
     {
      RecountCoverage();
      g_last_coverage_recount = g_schedule.now_server_time;
     }

   if(InpShowHUD)
     {
      int hud_refresh_sec = MathMax(1, InpHudRefreshSec);
      if(g_last_hud_render_time == 0 || (g_schedule.now_server_time - g_last_hud_render_time) >= hud_refresh_sec)
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
   g_perf.perf_warn = (g_schedule.last_cycle_ms >= InpPerfWarnMs);
   g_schedule.timer_busy = false;
  }


