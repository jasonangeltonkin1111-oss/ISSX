
#property strict
#property version   "1.000"
#property description "EA2 bounded history metrics core for locked EA1"

#define EA_NAME                       "EA2"
#define EA_ENGINE_VERSION             "1.0"
#define EA_SCHEMA_VERSION             "1.0"
#define EA_BUILD_CHANNEL              "history_metrics_final"

#define MAX_SYMBOLS_HARD              5000
#define MAX_RATES_WORK_PER_CYCLE      40
#define EVENT_RING_CAPACITY           64
#define DIAG_SAMPLE_CAP               20
#define WORST_SYMBOL_CAP              20

#define TF_COUNT                      4
#define TFIDX_M1                      0
#define TFIDX_M5                      1
#define TFIDX_M15                     2
#define TFIDX_D1                      3

#define CAP_M1                        256
#define CAP_M5                        256
#define CAP_M15                       256
#define CAP_D1                        64

#define READY_BARS_M1                 20
#define READY_BARS_M5                 20
#define READY_BARS_M15                20
#define READY_BARS_D1                 5
#define ATR_PERIOD                    14
#define ATR_MIN_BARS                  15

#define PERSIST_SCHEMA_VERSION        1

#define IO_OP_NONE                    0
#define IO_OP_READ                    1
#define IO_OP_WRITE_TMP               2
#define IO_OP_MOVE_COMMIT             3
#define IO_OP_COPY_COMMIT             4
#define IO_OP_BACKUP_COPY             5
#define IO_OP_DELETE_TMP              6

enum UpstreamSource
  {
   UPSRC_NONE = 0,
   UPSRC_CURRENT,
   UPSRC_PREVIOUS,
   UPSRC_LAST_GOOD
  };

enum TfPhase
  {
   TFP_NOT_STARTED = 0,
   TFP_BOOTSTRAP,
   TFP_STEADY,
   TFP_REPAIR,
   TFP_FAILING,
   TFP_COOLDOWN
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
   CO_PERSISTENCE,
   CO_RUNTIME_PRESERVED
  };

struct EventItem
  {
   datetime when_server;
   string   code;
   string   detail;
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
   int dur_upstream_read_ms;
   int dur_upstream_validate_ms;
   int dur_upstream_parse_ms;
   int dur_hydrate_ms;
   int dur_metric_compute_ms;
   int dur_build_stage_ms;
   int dur_build_debug_ms;
   int dur_write_tmp_ms;
   int dur_commit_ms;
   int dur_backup_ms;
   int dur_persist_load_ms;
   int dur_persist_save_ms;
   bool perf_warn;
  };

struct ScheduleState
  {
   long      timer_tick_count;
   long      timer_overrun_count;
   datetime  now_server_time;
   datetime  now_utc_time;
   datetime  last_timer_server_time;
   int       last_cycle_ms;
   bool      timer_busy;
   int       cursor_upstream;
   int       cursor_hydrate_symbol;
   int       cursor_metrics;
   int       cursor_persist_save;
   datetime  last_debug_write_time;
   datetime  last_stage_guard_time;
  };

struct UpstreamDiagState
  {
   bool           current_exists;
   bool           previous_exists;
   bool           current_valid;
   bool           previous_valid;
   bool           current_rejected;
   bool           previous_rejected;
   bool           last_good_applied;
   bool           active_valid;
   UpstreamSource source_used;
   long           active_minute_id;
   int            active_age_min;
   string         active_fingerprint;
   string         current_error;
   string         previous_error;
   string         active_reason;
   int            read_attempts_this_minute;
   long           read_attempt_minute_id;
   datetime       last_read_server_time;
   int            active_symbol_count;
  };

struct TfState
  {
   int       bars_loaded;
   int       bars_required;
   bool      ready;
   bool      coherent;
   bool      fresh;
   bool      stale;
   datetime  last_bar_time;
   int       bar_age_sec;
   int       fail_count;
   datetime  cooldown_until;
   datetime  next_due_server;
   datetime  last_attempt_server_time;
   datetime  last_success_server_time;
   datetime  last_hydrate_server_time;
   int       phase;
  };

struct SymbolState
  {
   string    raw_symbol;
   int       symbol_index_from_ea1;
   bool      upstream_join_key_present;

   bool      ea1_present;
   bool      ea1_valid;
   string    ea1_source_used;
   long      ea1_snapshot_minute_id;
   int       ea1_snapshot_age_min;
   string    ea1_universe_fingerprint;
   string    upstream_reason_code;
   bool      market_open_now_from_ea1;
   int       market_reason_code_from_ea1;
   double    spread_points_from_ea1;
   double    point_from_ea1;
   bool      spec_min_ready_from_ea1;
   bool      spread_current_enough_for_ratios;

   TfState   tf[TF_COUNT];

   datetime  m1_time[CAP_M1];
   double    m1_open[CAP_M1];
   double    m1_high[CAP_M1];
   double    m1_low[CAP_M1];
   double    m1_close[CAP_M1];

   datetime  m5_time[CAP_M5];
   double    m5_open[CAP_M5];
   double    m5_high[CAP_M5];
   double    m5_low[CAP_M5];
   double    m5_close[CAP_M5];

   datetime  m15_time[CAP_M15];
   double    m15_open[CAP_M15];
   double    m15_high[CAP_M15];
   double    m15_low[CAP_M15];
   double    m15_close[CAP_M15];

   datetime  d1_time[CAP_D1];
   double    d1_open[CAP_D1];
   double    d1_high[CAP_D1];
   double    d1_low[CAP_D1];
   double    d1_close[CAP_D1];

   bool      metrics_dirty;
   bool      metrics_partial;
   bool      metrics_min_ready;
   bool      spread_ratios_ready;
   bool      volatility_ready;
   bool      intraday_metrics_fresh;
   bool      publishable_metrics;

   double    atr_m1;
   double    atr_m5;
   double    atr_m15;
   double    atr_points_m1;
   double    atr_points_m5;
   double    atr_points_m15;
   double    volatility_accel;
   double    vol_expansion;
   double    spread_to_atr_m1_ratio;
   double    spread_to_atr_m5_ratio;

   string    data_reason_code;
   string    publish_reason_code;
   int       operational_health_score;
   string    summary_state;

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
   string    last_saved_payload_hash;
   datetime  saved_last_bar_time[TF_COUNT];
   string    persisted_fingerprint;
   long      persisted_minute_id;
   double    persisted_point;
  };

input string InpEA1FirmIdOverride            = "";
input string InpFirmSuffix                  = "";
input int    InpPerfWarnMs                  = 500;
input int    InpCoverageRefreshSec          = 5;
input int    InpDebugWriteSec               = 10;
input bool   InpShowHUD                     = true;
input int    InpHudRefreshSec               = 10;
input int    InpHudTopRows                  = 8;
input int    InpStagePublishOffsetSec       = 16;
input int    InpStagePublishWindowSec       = 20;
input bool   InpEnableBackups               = true;
input bool   InpEnablePublishLock           = true;
input bool   InpEnableTempCleanup           = true;
input int    InpTempCleanupAgeSec           = 900;
input int    InpTempCleanupEverySec         = 3600;

input int    InpUpstreamReadStartSec        = 10;
input int    InpUpstreamReadEndSec          = 14;
input int    InpUpstreamReadAttemptsPerMin  = 3;
input int    InpUpstreamStaleWarnMinutes    = 2;

input int    InpRatesBudgetPerCycle         = 40;
input int    InpMetricsBudgetPerCycle       = 200;

input int    InpM1RefreshSec                = 15;
input int    InpM5RefreshSec                = 45;
input int    InpM15RefreshSec               = 120;
input int    InpD1RefreshSec                = 1800;
input int    InpBootstrapRetrySec           = 10;
input int    InpRepairRetrySec              = 20;
input int    InpFailureCooldownBaseSec      = 15;
input int    InpFailureCooldownMaxSec       = 300;
input int    InpD1FailureCooldownBaseSec    = 180;
input int    InpOpenSpreadMaxAgeMin         = 2;
input int    InpClosedSpreadMaxAgeMin       = 60;

input bool   InpPersistenceEnabled          = true;
input int    InpPersistenceMaxAgeSec        = 7200;
input int    InpPersistenceSaveEverySec     = 300;
input int    InpPersistenceMinSaveGapSec    = 300;
input int    InpPersistenceSaveBudget       = 10;
input int    InpPersistenceMaxWritesPerMin  = 60;
input bool   InpPersistenceBackupEnabled    = true;

string g_firm_id                        = "";
string g_base_dir                       = "";
string g_outputs_dir                    = "";
string g_tmp_dir_ea2                    = "";
string g_locks_dir                      = "";
string g_persistence_dir_ea2            = "";
string g_ea1_stage_file                 = "";
string g_ea1_stage_prev_file            = "";
string g_stage_file                     = "";
string g_stage_prev_file                = "";
string g_stage_backup_file              = "";
string g_debug_file                     = "";
string g_debug_prev_file                = "";
string g_debug_backup_file              = "";

SymbolState g_symbols[];
int         g_symbol_count              = 0;
string      g_lookup_keys[];
int         g_lookup_vals[];
int         g_lookup_capacity           = 0;

bool        g_have_upstream             = false;
long        g_upstream_minute_id        = -1;
string      g_upstream_fingerprint      = "";
UpstreamSource g_upstream_source        = UPSRC_NONE;
string      g_upstream_symbols[];
double      g_upstream_points[];
bool        g_upstream_spec_ready[];
double      g_upstream_spreads[];
bool        g_upstream_market_open[];
int         g_upstream_market_reason[];
int         g_upstream_symbol_count     = 0;

ScheduleState     g_schedule;
PublishMetaState  g_publish_stage;
PublishMetaState  g_publish_debug;
IoLastState       g_io_last;
IoCounterState    g_io_counters;
PerfState         g_perf;
UpstreamDiagState g_upstream_diag;

EventItem    g_events[EVENT_RING_CAPACITY];
int          g_event_head               = 0;
int          g_event_count              = 0;

datetime     g_last_coverage_recount    = 0;
datetime     g_last_hud_render_time     = 0;
datetime     g_last_temp_cleanup        = 0;
long         g_persist_writes_minute_id = -1;
int          g_persist_writes_this_min  = 0;

int g_cov_ready_m1_count                = 0;
int g_cov_ready_m5_count                = 0;
int g_cov_ready_m15_count               = 0;
int g_cov_ready_d1_count                = 0;
int g_cov_fresh_m1_count                = 0;
int g_cov_metrics_partial_count         = 0;
int g_cov_publishable_count             = 0;

long g_cnt_upstream_reads               = 0;
long g_cnt_upstream_accepts             = 0;
long g_cnt_upstream_rejects             = 0;
long g_cnt_hydrate_calls                = 0;
long g_cnt_hydrate_success              = 0;
long g_cnt_hydrate_fail                 = 0;
long g_cnt_metrics_compute              = 0;
long g_cnt_stage_publish_ok             = 0;
long g_cnt_stage_publish_fail           = 0;
long g_cnt_debug_publish_ok             = 0;
long g_cnt_debug_publish_fail           = 0;
long g_cnt_persist_load_ok              = 0;
long g_cnt_persist_load_fail            = 0;
long g_cnt_persist_save_ok              = 0;
long g_cnt_persist_save_fail            = 0;
long g_cnt_persist_stale_discard        = 0;
long g_cnt_persist_corrupt_discard      = 0;
long g_cnt_persist_incompat_discard     = 0;


bool IsKnownNumber(const double v)
  {
   if(v == EMPTY_VALUE) return false;
   return MathIsValidNumber(v);
  }

string LongToStringSafe(const long v)
  {
   return StringFormat("%I64d", v);
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
string JsonLong(const long v) { return StringFormat("%I64d", v); }
string JsonInt(const int v) { return IntegerToString(v); }
string JsonLongOrNull(const long v) { if(v <= 0) return "null"; return JsonLong(v); }
string JsonDoubleOrNull6(const double v) { if(!IsKnownNumber(v)) return "null"; return DoubleToString(v, 6); }
string JsonDateTimeOrNull(const datetime v) { if(v <= 0) return "null"; return JsonString(TimeToString(v, TIME_DATE | TIME_SECONDS)); }
string JsonStringOrNull(const string s) { if(s == "") return "null"; return JsonString(s); }

uint FNV1a32(const string s)
  {
   uint h = 2166136261;
   int n = StringLen(s);
   for(int i = 0; i < n; i++)
     {
      h ^= (uint)StringGetCharacter(s, i);
      h *= 16777619;
     }
   return h;
  }

string FNV1a32Hex(const string s)
  {
   return StringFormat("%08X", FNV1a32(s));
  }

int ClampInt(const int v, const int lo, const int hi)
  {
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
  }

double MeaningfulRatio(const double numer, const double denom)
  {
   if(!IsKnownNumber(numer) || !IsKnownNumber(denom)) return EMPTY_VALUE;
   if(denom <= 0.0) return EMPTY_VALUE;
   if(denom < 0.0000001) return EMPTY_VALUE;
   return numer / denom;
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
      string tail = StringSubstr(out, StringLen(out) - 1, 1);
      if(tail == "." || tail == "_" || tail == " ")
         out = StringSubstr(out, 0, StringLen(out) - 1);
      else
         break;
     }
   if(out == "") out = "UNKNOWN_FIRM";
   return out;
  }

string BuildFirmId()
  {
   string firm = "";
   if(InpEA1FirmIdOverride != "")
      firm = SanitizeFirmName(InpEA1FirmIdOverride);
   else
      firm = SanitizeFirmName(AccountInfoString(ACCOUNT_COMPANY));

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

void UpdateScheduleClock()
  {
   g_schedule.now_server_time = TimeCurrent();
   g_schedule.now_utc_time = TimeGMT();
   g_schedule.last_timer_server_time = g_schedule.now_server_time;
  }

bool IsPublishWindowOpen(const datetime t, const int offset_sec, const int window_sec)
  {
   if(t <= 0) return false;
   int sec_in_min = (int)(t % 60);
   return (sec_in_min >= offset_sec && sec_in_min < offset_sec + window_sec);
  }

string TfLabel(const int tf_idx)
  {
   if(tf_idx == TFIDX_M1) return "M1";
   if(tf_idx == TFIDX_M5) return "M5";
   if(tf_idx == TFIDX_M15) return "M15";
   return "D1";
  }

ENUM_TIMEFRAMES TfEnum(const int tf_idx)
  {
   if(tf_idx == TFIDX_M1) return PERIOD_M1;
   if(tf_idx == TFIDX_M5) return PERIOD_M5;
   if(tf_idx == TFIDX_M15) return PERIOD_M15;
   return PERIOD_D1;
  }

int TfSeconds(const int tf_idx)
  {
   if(tf_idx == TFIDX_M1) return 60;
   if(tf_idx == TFIDX_M5) return 300;
   if(tf_idx == TFIDX_M15) return 900;
   return 86400;
  }

int TfReadyBars(const int tf_idx)
  {
   if(tf_idx == TFIDX_M1) return READY_BARS_M1;
   if(tf_idx == TFIDX_M5) return READY_BARS_M5;
   if(tf_idx == TFIDX_M15) return READY_BARS_M15;
   return READY_BARS_D1;
  }

int TfCapacity(const int tf_idx)
  {
   if(tf_idx == TFIDX_M1) return CAP_M1;
   if(tf_idx == TFIDX_M5) return CAP_M5;
   if(tf_idx == TFIDX_M15) return CAP_M15;
   return CAP_D1;
  }

int TfFreshThresholdSec(const int tf_idx)
  {
   if(tf_idx == TFIDX_M1) return 2 * 60;
   if(tf_idx == TFIDX_M5) return 2 * 300;
   if(tf_idx == TFIDX_M15) return 2 * 900;
   return 5 * 86400;
  }

int TfFreshBit(const int tf_idx)
  {
   if(tf_idx == TFIDX_M1) return 1;
   if(tf_idx == TFIDX_M5) return 2;
   if(tf_idx == TFIDX_M15) return 4;
   return 8;
  }

int TfSteadyRefreshSec(const int tf_idx)
  {
   if(tf_idx == TFIDX_M1) return MathMax(5, InpM1RefreshSec);
   if(tf_idx == TFIDX_M5) return MathMax(15, InpM5RefreshSec);
   if(tf_idx == TFIDX_M15) return MathMax(30, InpM15RefreshSec);
   return MathMax(300, InpD1RefreshSec);
  }

int TfJitterSec(const string sym, const int tf_idx, const int base_sec)
  {
   if(base_sec <= 1) return 0;
   string key = sym + "|" + TfLabel(tf_idx);
   int spread = MathMax(1, MathMin(base_sec / 4, 30));
   return (int)(FNV1a32(key) % (uint)spread);
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
   g_io_last.last_file = "";
   g_io_last.last_op = IO_OP_NONE;
   g_io_last.open_err = 0;
   g_io_last.write_err = 0;
   g_io_last.move_err = 0;
   g_io_last.copy_err = 0;
   g_io_last.delete_err = 0;
   g_io_last.bytes = 0;
   g_io_last.guard_ok = false;
   g_io_counters.io_ok_count = 0;
   g_io_counters.io_fail_count = 0;
  }

void ResetPerfState()
  {
   g_perf.dur_step_total_ms = 0;
   g_perf.dur_upstream_read_ms = 0;
   g_perf.dur_upstream_validate_ms = 0;
   g_perf.dur_upstream_parse_ms = 0;
   g_perf.dur_hydrate_ms = 0;
   g_perf.dur_metric_compute_ms = 0;
   g_perf.dur_build_stage_ms = 0;
   g_perf.dur_build_debug_ms = 0;
   g_perf.dur_write_tmp_ms = 0;
   g_perf.dur_commit_ms = 0;
   g_perf.dur_backup_ms = 0;
   g_perf.dur_persist_load_ms = 0;
   g_perf.dur_persist_save_ms = 0;
   g_perf.perf_warn = false;
  }

void ResetUpstreamDiag()
  {
   g_upstream_diag.current_exists = false;
   g_upstream_diag.previous_exists = false;
   g_upstream_diag.current_valid = false;
   g_upstream_diag.previous_valid = false;
   g_upstream_diag.current_rejected = false;
   g_upstream_diag.previous_rejected = false;
   g_upstream_diag.last_good_applied = false;
   g_upstream_diag.active_valid = g_have_upstream;
   g_upstream_diag.source_used = g_upstream_source;
   g_upstream_diag.active_minute_id = g_upstream_minute_id;
   g_upstream_diag.active_age_min = (g_have_upstream && g_schedule.now_server_time > 0 ? (int)(GetMinuteId(g_schedule.now_server_time) - g_upstream_minute_id) : 0);
   g_upstream_diag.active_fingerprint = g_upstream_fingerprint;
   g_upstream_diag.current_error = "";
   g_upstream_diag.previous_error = "";
   g_upstream_diag.active_reason = (g_have_upstream ? "active_ok" : "no_upstream");
   g_upstream_diag.last_read_server_time = 0;
   g_upstream_diag.active_symbol_count = g_upstream_symbol_count;
  }

void AddEvent(const string code, const string detail)
  {
   int idx = g_event_head;
   g_events[idx].when_server = g_schedule.now_server_time;
   g_events[idx].code = code;
   g_events[idx].detail = detail;
   g_event_head++;
   if(g_event_head >= EVENT_RING_CAPACITY) g_event_head = 0;
   if(g_event_count < EVENT_RING_CAPACITY) g_event_count++;
  }

void InitFirmFiles()
  {
   g_firm_id = BuildFirmId();

   string firms_root = "FIRMS\\";
   string firm_dir = firms_root + g_firm_id + "\\";

   FolderCreate("FIRMS", FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir, 0, StringLen(firm_dir) - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "outputs\\", 0, StringLen(firm_dir + "outputs\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "persistence\\", 0, StringLen(firm_dir + "persistence\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "persistence\\ea2\\", 0, StringLen(firm_dir + "persistence\\ea2\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "tmp\\", 0, StringLen(firm_dir + "tmp\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "tmp\\ea2\\", 0, StringLen(firm_dir + "tmp\\ea2\\") - 1), FILE_COMMON);
   FolderCreate(StringSubstr(firm_dir + "locks\\", 0, StringLen(firm_dir + "locks\\") - 1), FILE_COMMON);

   g_base_dir            = firm_dir;
   g_outputs_dir         = firm_dir + "outputs\\";
   g_tmp_dir_ea2         = firm_dir + "tmp\\ea2\\";
   g_locks_dir           = firm_dir + "locks\\";
   g_persistence_dir_ea2 = firm_dir + "persistence\\ea2\\";

   g_ea1_stage_file      = firms_root + g_firm_id + "_symbols_universe.json";
   g_ea1_stage_prev_file = g_outputs_dir + g_firm_id + "_symbols_universe_prev.json";

   g_stage_file          = firms_root + g_firm_id + "_history_metrics.json";
   g_stage_prev_file     = g_outputs_dir + g_firm_id + "_history_metrics_prev.json";
   g_stage_backup_file   = g_outputs_dir + g_firm_id + "_history_metrics_backup.json";
   g_debug_file          = firms_root + g_firm_id + "_debug_ea2.json";
   g_debug_prev_file     = g_outputs_dir + g_firm_id + "_debug_ea2_prev.json";
   g_debug_backup_file   = g_outputs_dir + g_firm_id + "_debug_ea2_backup.json";
  }

string BuildTempFileName(const string tmp_dir, const string final_name, const long minute_id, const int write_seq)
  {
   return tmp_dir + final_name + "." + LongToStringSafe(minute_id) + "." + IntegerToString(write_seq) + ".tmp";
  }

bool PublishLockExists()
  {
   if(!InpEnablePublishLock) return false;
   string lock_path = g_locks_dir + "publish.lock";
   return FileIsExist(lock_path, FILE_COMMON);
  }

bool WriteTextFileCommon(const string rel_path, const string content, int &bytes_written)
  {
   bytes_written = 0;
   g_io_last.last_file = rel_path;
   g_io_last.last_op = IO_OP_WRITE_TMP;
   g_io_last.open_err = 0;
   g_io_last.write_err = 0;
   g_io_last.bytes = 0;

   int h = FileOpen(rel_path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      g_io_last.open_err = GetLastError();
      g_io_counters.io_fail_count++;
      return false;
     }

   ResetLastError();
   FileWriteString(h, content);
   g_io_last.write_err = GetLastError();
   bytes_written = (int)FileTell(h);
   FileClose(h);

   if(g_io_last.write_err != 0)
     {
      g_io_counters.io_fail_count++;
      return false;
     }

   g_io_last.bytes = bytes_written;
   g_io_counters.io_ok_count++;
   return true;
  }

bool BestEffortPreservePrevious(const string current_rel, const string prev_rel)
  {
   if(!FileIsExist(current_rel, FILE_COMMON)) return false;
   g_io_last.last_file = prev_rel;
   g_io_last.last_op = IO_OP_BACKUP_COPY;
   g_io_last.copy_err = 0;
   g_io_last.delete_err = 0;
   if(FileIsExist(prev_rel, FILE_COMMON)) FileDelete(prev_rel, FILE_COMMON);
   ResetLastError();
   if(FileCopy(current_rel, FILE_COMMON, prev_rel, FILE_COMMON))
     {
      g_io_counters.io_ok_count++;
      return true;
     }
   g_io_last.copy_err = GetLastError();
   g_io_counters.io_fail_count++;
   return false;
  }

bool CommitFileAtomic(const string tmp_rel, const string final_rel)
  {
   g_io_last.last_file = final_rel;
   g_io_last.move_err = 0;
   g_io_last.copy_err = 0;
   g_io_last.delete_err = 0;

   g_io_last.last_op = IO_OP_MOVE_COMMIT;
   ResetLastError();
   if(FileMove(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      g_io_counters.io_ok_count++;
      return true;
     }
   g_io_last.move_err = GetLastError();

   if(FileIsExist(final_rel, FILE_COMMON))
     {
      g_io_last.last_op = IO_OP_DELETE_TMP;
      ResetLastError();
      FileDelete(final_rel, FILE_COMMON);
      g_io_last.delete_err = GetLastError();
     }

   g_io_last.last_op = IO_OP_MOVE_COMMIT;
   ResetLastError();
   if(FileMove(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      g_io_counters.io_ok_count++;
      return true;
     }
   g_io_last.move_err = GetLastError();

   g_io_last.last_op = IO_OP_COPY_COMMIT;
   ResetLastError();
   if(FileCopy(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      FileDelete(tmp_rel, FILE_COMMON);
      g_io_counters.io_ok_count++;
      return true;
     }

   g_io_last.copy_err = GetLastError();
   g_io_counters.io_fail_count++;
   return false;
  }

bool BestEffortBackup(const string final_rel, const string backup_rel)
  {
   if(!InpEnableBackups) return false;
   if(!FileIsExist(final_rel, FILE_COMMON)) return false;
   g_io_last.last_file = backup_rel;
   g_io_last.last_op = IO_OP_BACKUP_COPY;
   g_io_last.copy_err = 0;
   g_io_last.delete_err = 0;
   if(FileIsExist(backup_rel, FILE_COMMON)) FileDelete(backup_rel, FILE_COMMON);
   ResetLastError();
   if(FileCopy(final_rel, FILE_COMMON, backup_rel, FILE_COMMON))
     {
      g_io_counters.io_ok_count++;
      return true;
     }
   g_io_last.copy_err = GetLastError();
   g_io_counters.io_fail_count++;
   return false;
  }

string BuildSymbolIdentityHash(const string raw_symbol)
  {
   return FNV1a32Hex(g_firm_id + "|" + raw_symbol);
  }


string LowerStr(string s)
  {
   StringToLower(s);
   return s;
  }

string BuildPersistenceFilePath(const string raw_symbol)
  {
   return g_persistence_dir_ea2 + BuildSymbolIdentityHash(raw_symbol) + ".bin";
  }

string BuildPersistenceBackupPath(const string raw_symbol)
  {
   return g_persistence_dir_ea2 + BuildSymbolIdentityHash(raw_symbol) + ".bak";
  }

void ResetTfState(TfState &st, const int tf_idx)
  {
   st.bars_loaded = 0;
   st.bars_required = TfReadyBars(tf_idx);
   st.ready = false;
   st.coherent = false;
   st.fresh = false;
   st.stale = false;
   st.last_bar_time = 0;
   st.bar_age_sec = 0;
   st.fail_count = 0;
   st.cooldown_until = 0;
   st.next_due_server = 0;
   st.last_attempt_server_time = 0;
   st.last_success_server_time = 0;
   st.last_hydrate_server_time = 0;
   st.phase = TFP_NOT_STARTED;
  }

void ResetMetrics(SymbolState &sym)
  {
   sym.metrics_dirty = true;
   sym.metrics_partial = false;
   sym.metrics_min_ready = false;
   sym.spread_ratios_ready = false;
   sym.volatility_ready = false;
   sym.intraday_metrics_fresh = false;
   sym.publishable_metrics = false;
   sym.atr_m1 = EMPTY_VALUE;
   sym.atr_m5 = EMPTY_VALUE;
   sym.atr_m15 = EMPTY_VALUE;
   sym.atr_points_m1 = EMPTY_VALUE;
   sym.atr_points_m5 = EMPTY_VALUE;
   sym.atr_points_m15 = EMPTY_VALUE;
   sym.volatility_accel = EMPTY_VALUE;
   sym.vol_expansion = EMPTY_VALUE;
   sym.spread_to_atr_m1_ratio = EMPTY_VALUE;
   sym.spread_to_atr_m5_ratio = EMPTY_VALUE;
   sym.data_reason_code = "no_bars";
   sym.publish_reason_code = "not_written";
   sym.operational_health_score = 0;
   sym.summary_state = "WARMUP";
  }

void ResetPersistenceState(SymbolState &sym)
  {
   sym.persistence_state = PTX_NONE;
   sym.persistence_loaded = false;
   sym.persistence_fresh = false;
   sym.persistence_stale = false;
   sym.persistence_corrupt = false;
   sym.persistence_incompatible = false;
   sym.resumed_from_persistence = false;
   sym.restarted_clean = false;
   sym.persistence_age_sec = 0;
   sym.continuity_origin = CO_NONE;
   sym.continuity_last_good_server_time = 0;
   sym.last_persistence_save_time = 0;
   sym.persistence_dirty = true;
   sym.last_saved_payload_hash = "";
   for(int i = 0; i < TF_COUNT; i++)
      sym.saved_last_bar_time[i] = 0;
   sym.persisted_fingerprint = "";
   sym.persisted_minute_id = -1;
   sym.persisted_point = EMPTY_VALUE;
  }

void ResetSymbolState(SymbolState &sym, const string raw_symbol, const int idx_from_ea1)
  {
   sym.raw_symbol = raw_symbol;
   sym.symbol_index_from_ea1 = idx_from_ea1;
   sym.upstream_join_key_present = true;

   sym.ea1_present = true;
   sym.ea1_valid = true;
   sym.ea1_source_used = "";
   sym.ea1_snapshot_minute_id = -1;
   sym.ea1_snapshot_age_min = 0;
   sym.ea1_universe_fingerprint = "";
   sym.upstream_reason_code = "new_symbol";
   sym.market_open_now_from_ea1 = false;
   sym.market_reason_code_from_ea1 = 0;
   sym.spread_points_from_ea1 = EMPTY_VALUE;
   sym.point_from_ea1 = EMPTY_VALUE;
   sym.spec_min_ready_from_ea1 = false;
   sym.spread_current_enough_for_ratios = false;

   for(int i = 0; i < TF_COUNT; i++)
      ResetTfState(sym.tf[i], i);

   ArrayInitialize(sym.m1_time, 0);
   ArrayInitialize(sym.m1_open, 0.0);
   ArrayInitialize(sym.m1_high, 0.0);
   ArrayInitialize(sym.m1_low, 0.0);
   ArrayInitialize(sym.m1_close, 0.0);

   ArrayInitialize(sym.m5_time, 0);
   ArrayInitialize(sym.m5_open, 0.0);
   ArrayInitialize(sym.m5_high, 0.0);
   ArrayInitialize(sym.m5_low, 0.0);
   ArrayInitialize(sym.m5_close, 0.0);

   ArrayInitialize(sym.m15_time, 0);
   ArrayInitialize(sym.m15_open, 0.0);
   ArrayInitialize(sym.m15_high, 0.0);
   ArrayInitialize(sym.m15_low, 0.0);
   ArrayInitialize(sym.m15_close, 0.0);

   ArrayInitialize(sym.d1_time, 0);
   ArrayInitialize(sym.d1_open, 0.0);
   ArrayInitialize(sym.d1_high, 0.0);
   ArrayInitialize(sym.d1_low, 0.0);
   ArrayInitialize(sym.d1_close, 0.0);

   ResetMetrics(sym);
   ResetPersistenceState(sym);
  }

void ResetGlobalState()
  {
   ArrayResize(g_symbols, 0);
   g_symbol_count = 0;
   ArrayResize(g_lookup_keys, 0);
   ArrayResize(g_lookup_vals, 0);
   g_lookup_capacity = 0;

   g_have_upstream = false;
   g_upstream_minute_id = -1;
   g_upstream_fingerprint = "";
   g_upstream_source = UPSRC_NONE;
   ArrayResize(g_upstream_symbols, 0);
   ArrayResize(g_upstream_points, 0);
   ArrayResize(g_upstream_spec_ready, 0);
   ArrayResize(g_upstream_spreads, 0);
   ArrayResize(g_upstream_market_open, 0);
   ArrayResize(g_upstream_market_reason, 0);
   g_upstream_symbol_count = 0;

   g_schedule.timer_tick_count = 0;
   g_schedule.timer_overrun_count = 0;
   g_schedule.now_server_time = 0;
   g_schedule.now_utc_time = 0;
   g_schedule.last_timer_server_time = 0;
   g_schedule.last_cycle_ms = 0;
   g_schedule.timer_busy = false;
   g_schedule.cursor_upstream = 0;
   g_schedule.cursor_hydrate_symbol = 0;
   g_schedule.cursor_metrics = 0;
   g_schedule.cursor_persist_save = 0;
   g_schedule.last_debug_write_time = 0;
   g_schedule.last_stage_guard_time = 0;

   ResetPublishState(g_publish_stage);
   ResetPublishState(g_publish_debug);
   ResetIoState();
   ResetPerfState();
   ResetUpstreamDiag();

   g_event_head = 0;
   g_event_count = 0;
   for(int i = 0; i < EVENT_RING_CAPACITY; i++)
     {
      g_events[i].when_server = 0;
      g_events[i].code = "";
      g_events[i].detail = "";
     }

   g_last_coverage_recount = 0;
   g_last_hud_render_time = 0;
   g_last_temp_cleanup = 0;
   g_persist_writes_minute_id = -1;
   g_persist_writes_this_min = 0;

   g_cov_ready_m1_count = 0;
   g_cov_ready_m5_count = 0;
   g_cov_ready_m15_count = 0;
   g_cov_ready_d1_count = 0;
   g_cov_fresh_m1_count = 0;
   g_cov_metrics_partial_count = 0;
   g_cov_publishable_count = 0;
  }


void SkipWs(const string s, int &p, const int end_pos)
  {
   while(p < end_pos)
     {
      ushort c = (ushort)StringGetCharacter(s, p);
      if(c == ' ' || c == '\r' || c == '\n' || c == '\t')
         p++;
      else
         break;
     }
  }

int FindMatchingBrace(const string s, const int open_pos, const int end_pos)
  {
   if(open_pos < 0 || open_pos >= end_pos) return -1;
   int depth = 0;
   bool in_string = false;
   bool escaped = false;
   for(int i = open_pos; i < end_pos; i++)
     {
      ushort c = (ushort)StringGetCharacter(s, i);
      if(in_string)
        {
         if(escaped) escaped = false;
         else if(c == '\\') escaped = true;
         else if(c == '"') in_string = false;
         continue;
        }
      if(c == '"')
        {
         in_string = true;
         continue;
        }
      if(c == '{') depth++;
      else if(c == '}')
        {
         depth--;
         if(depth == 0) return i;
        }
     }
   return -1;
  }

int FindMatchingBracket(const string s, const int open_pos, const int end_pos)
  {
   if(open_pos < 0 || open_pos >= end_pos) return -1;
   int depth = 0;
   bool in_string = false;
   bool escaped = false;
   for(int i = open_pos; i < end_pos; i++)
     {
      ushort c = (ushort)StringGetCharacter(s, i);
      if(in_string)
        {
         if(escaped) escaped = false;
         else if(c == '\\') escaped = true;
         else if(c == '"') in_string = false;
         continue;
        }
      if(c == '"')
        {
         in_string = true;
         continue;
        }
      if(c == '[') depth++;
      else if(c == ']')
        {
         depth--;
         if(depth == 0) return i;
        }
     }
   return -1;
  }

int FindJsonKey(const string s, const string key, const int start_pos, const int end_pos)
  {
   string pat = "\"" + key + "\"";
   int p = StringFind(s, pat, start_pos);
   if(p < 0 || p >= end_pos) return -1;
   return p;
  }

bool ExtractJsonValueSlice(const string s, const string key, const int start_pos, const int end_pos, int &val_start, int &val_end)
  {
   val_start = -1;
   val_end = -1;
   int key_pos = FindJsonKey(s, key, start_pos, end_pos);
   if(key_pos < 0) return false;
   int p = key_pos + StringLen(key) + 2;
   while(p < end_pos)
     {
      ushort c = (ushort)StringGetCharacter(s, p);
      if(c == ':')
        {
         p++;
         break;
        }
      p++;
     }
   if(p >= end_pos) return false;
   SkipWs(s, p, end_pos);
   if(p >= end_pos) return false;

   ushort c0 = (ushort)StringGetCharacter(s, p);
   val_start = p;

   if(c0 == '"')
     {
      p++;
      bool escaped = false;
      while(p < end_pos)
        {
         ushort c = (ushort)StringGetCharacter(s, p);
         if(escaped) escaped = false;
         else if(c == '\\') escaped = true;
         else if(c == '"')
           {
            val_end = p;
            return true;
           }
         p++;
        }
      return false;
     }

   if(c0 == '{')
     {
      val_end = FindMatchingBrace(s, p, end_pos);
      return (val_end >= 0);
     }

   if(c0 == '[')
     {
      val_end = FindMatchingBracket(s, p, end_pos);
      return (val_end >= 0);
     }

   while(p < end_pos)
     {
      ushort c = (ushort)StringGetCharacter(s, p);
      if(c == ',' || c == '}' || c == ']')
        {
         val_end = p - 1;
         while(val_end >= val_start)
           {
            ushort t = (ushort)StringGetCharacter(s, val_end);
            if(t == ' ' || t == '\r' || t == '\n' || t == '\t')
               val_end--;
            else
               break;
           }
         return (val_end >= val_start);
        }
      p++;
     }
   val_end = end_pos - 1;
   return (val_end >= val_start);
  }

bool ParseJsonStringByKeyRange(const string s, const string key, const int start_pos, const int end_pos, string &out)
  {
   out = "";
   int a = -1, b = -1;
   if(!ExtractJsonValueSlice(s, key, start_pos, end_pos, a, b)) return false;
   if(a < 0 || b <= a) return false;
   if((ushort)StringGetCharacter(s, a) != '"') return false;
   string raw = StringSubstr(s, a + 1, b - a - 1);
   string val = "";
   bool esc = false;
   for(int i = 0; i < StringLen(raw); i++)
     {
      ushort c = (ushort)StringGetCharacter(raw, i);
      if(esc)
        {
         if(c == '"' || c == '\\' || c == '/')
            val += CharToString((uchar)c);
         else if(c == 'n') val += "\n";
         else if(c == 'r') val += "\r";
         else if(c == 't') val += "\t";
         else val += CharToString((uchar)c);
         esc = false;
        }
      else if(c == '\\')
         esc = true;
      else
         val += CharToString((uchar)c);
     }
   out = val;
   return true;
  }

bool ParseJsonLongByKeyRange(const string s, const string key, const int start_pos, const int end_pos, long &out)
  {
   out = 0;
   int a = -1, b = -1;
   if(!ExtractJsonValueSlice(s, key, start_pos, end_pos, a, b)) return false;
   string raw = StringSubstr(s, a, b - a + 1);
   StringTrimLeft(raw);
   StringTrimRight(raw);
   if(raw == "" || raw == "null") return false;
   out = (long)StringToInteger(raw);
   return true;
  }

bool ParseJsonIntByKeyRange(const string s, const string key, const int start_pos, const int end_pos, int &out)
  {
   long v = 0;
   if(!ParseJsonLongByKeyRange(s, key, start_pos, end_pos, v)) return false;
   out = (int)v;
   return true;
  }

bool ParseJsonDoubleByKeyRange(const string s, const string key, const int start_pos, const int end_pos, double &out)
  {
   out = EMPTY_VALUE;
   int a = -1, b = -1;
   if(!ExtractJsonValueSlice(s, key, start_pos, end_pos, a, b)) return false;
   string raw = StringSubstr(s, a, b - a + 1);
   StringTrimLeft(raw);
   StringTrimRight(raw);
   if(raw == "" || raw == "null") return false;
   out = StringToDouble(raw);
   return IsKnownNumber(out);
  }

bool ParseJsonBoolByKeyRange(const string s, const string key, const int start_pos, const int end_pos, bool &out)
  {
   out = false;
   int a = -1, b = -1;
   if(!ExtractJsonValueSlice(s, key, start_pos, end_pos, a, b)) return false;
   string raw = StringSubstr(s, a, b - a + 1);
   StringTrimLeft(raw);
   StringTrimRight(raw);
   if(raw == "true")
     {
      out = true;
      return true;
     }
   if(raw == "false")
     {
      out = false;
      return true;
     }
   return false;
  }

bool ReadTextFileCommon(const string rel_path, string &out, string &err)
  {
   out = "";
   err = "";
   g_io_last.last_file = rel_path;
   g_io_last.last_op = IO_OP_READ;
   g_io_last.open_err = 0;

   int h = FileOpen(rel_path, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      g_io_last.open_err = GetLastError();
      err = "open_failed";
      g_io_counters.io_fail_count++;
      return false;
     }

   while(!FileIsEnding(h))
      out += FileReadString(h);
   FileClose(h);

   g_io_counters.io_ok_count++;
   return true;
  }

bool MinimalJsonGuard(const string text)
  {
   int n = StringLen(text);
   if(n < 32) return false;
   int i = 0;
   while(i < n)
     {
      ushort c = (ushort)StringGetCharacter(text, i);
      if(c == ' ' || c == '\r' || c == '\n' || c == '\t') i++;
      else break;
     }
   int j = n - 1;
   while(j >= 0)
     {
      ushort c2 = (ushort)StringGetCharacter(text, j);
      if(c2 == ' ' || c2 == '\r' || c2 == '\n' || c2 == '\t') j--;
      else break;
     }
   if(i >= j) return false;
   return ((ushort)StringGetCharacter(text, i) == '{' && (ushort)StringGetCharacter(text, j) == '}');
  }

bool ParseUpstreamSnapshot(const string text,
                          long &minute_id,
                          string &fingerprint,
                          string &err,
                          string &symbols[],
                          double &points[],
                          bool &spec_ready[],
                          double &spreads[],
                          bool &market_open[],
                          int &market_reason[])
  {
   err = "";
   minute_id = -1;
   fingerprint = "";
   ArrayResize(symbols, 0);
   ArrayResize(points, 0);
   ArrayResize(spec_ready, 0);
   ArrayResize(spreads, 0);
   ArrayResize(market_open, 0);
   ArrayResize(market_reason, 0);

   int n = StringLen(text);
   if(n < 32)
     {
      err = "too_small";
      return false;
     }
   if(!MinimalJsonGuard(text))
     {
      err = "guard_fail";
      return false;
     }

   string producer = "";
   string stage = "";
   if(!ParseJsonStringByKeyRange(text, "producer", 0, n, producer))
     {
      err = "missing_producer";
      return false;
     }
   if(!ParseJsonStringByKeyRange(text, "stage", 0, n, stage))
     {
      err = "missing_stage";
      return false;
     }
   if(producer != "EA1")
     {
      err = "wrong_producer";
      return false;
     }
   if(stage != "symbols_universe")
     {
      err = "wrong_stage";
      return false;
     }

   if(!ParseJsonLongByKeyRange(text, "minute_id", 0, n, minute_id))
     {
      err = "missing_minute_id";
      return false;
     }
   if(!ParseJsonStringByKeyRange(text, "universe_fingerprint", 0, n, fingerprint))
     {
      err = "missing_fingerprint";
      return false;
     }

   int a = -1, b = -1;
   if(!ExtractJsonValueSlice(text, "symbols", 0, n, a, b))
     {
      err = "missing_symbols";
      return false;
     }
   if(a < 0 || b <= a || (ushort)StringGetCharacter(text, a) != '[')
     {
      err = "bad_symbols_array";
      return false;
     }

   int p = a + 1;
   int count = 0;
   while(p < b)
     {
      SkipWs(text, p, b);
      if(p >= b) break;
      ushort c = (ushort)StringGetCharacter(text, p);
      if(c == ',')
        {
         p++;
         continue;
        }
      if(c != '{')
        {
         p++;
         continue;
        }

      int obj_end = FindMatchingBrace(text, p, b + 1);
      if(obj_end < 0)
        {
         err = "bad_symbol_object";
         return false;
        }

      string raw_symbol = "";
      if(!ParseJsonStringByKeyRange(text, "raw_symbol", p, obj_end + 1, raw_symbol) || raw_symbol == "")
        {
         err = "missing_raw_symbol";
         return false;
        }

      int new_size = count + 1;
      ArrayResize(symbols, new_size);
      ArrayResize(points, new_size);
      ArrayResize(spec_ready, new_size);
      ArrayResize(spreads, new_size);
      ArrayResize(market_open, new_size);
      ArrayResize(market_reason, new_size);

      symbols[count] = raw_symbol;
      points[count] = EMPTY_VALUE;
      spec_ready[count] = false;
      spreads[count] = EMPTY_VALUE;
      market_open[count] = false;
      market_reason[count] = 0;

      int sa = -1, sb = -1;
      if(ExtractJsonValueSlice(text, "spec", p, obj_end + 1, sa, sb) && sa >= 0 && (ushort)StringGetCharacter(text, sa) == '{')
        {
         ParseJsonDoubleByKeyRange(text, "point", sa, sb + 1, points[count]);
         ParseJsonBoolByKeyRange(text, "spec_min_ready", sa, sb + 1, spec_ready[count]);
        }

      if(ExtractJsonValueSlice(text, "market", p, obj_end + 1, sa, sb) && sa >= 0 && (ushort)StringGetCharacter(text, sa) == '{')
         ParseJsonDoubleByKeyRange(text, "spread_points", sa, sb + 1, spreads[count]);

      if(ExtractJsonValueSlice(text, "market_status", p, obj_end + 1, sa, sb) && sa >= 0 && (ushort)StringGetCharacter(text, sa) == '{')
        {
         ParseJsonBoolByKeyRange(text, "market_open_now", sa, sb + 1, market_open[count]);
         ParseJsonIntByKeyRange(text, "reason_code", sa, sb + 1, market_reason[count]);
        }

      count++;
      p = obj_end + 1;
     }

   if(count <= 0)
     {
      err = "empty_symbols";
      return false;
     }

   return true;
  }


void ClearLookup()
  {
   g_lookup_capacity = 0;
   ArrayResize(g_lookup_keys, 0);
   ArrayResize(g_lookup_vals, 0);
  }

void BuildSymbolLookup()
  {
   ClearLookup();
   if(g_symbol_count <= 0) return;

   g_lookup_capacity = 1;
   while(g_lookup_capacity < g_symbol_count * 2)
      g_lookup_capacity <<= 1;

   ArrayResize(g_lookup_keys, g_lookup_capacity);
   ArrayResize(g_lookup_vals, g_lookup_capacity);
   for(int i = 0; i < g_lookup_capacity; i++)
     {
      g_lookup_keys[i] = "";
      g_lookup_vals[i] = -1;
     }

   for(int i = 0; i < g_symbol_count; i++)
     {
      string key = g_symbols[i].raw_symbol;
      int slot = (int)(FNV1a32(key) & (uint)(g_lookup_capacity - 1));
      while(true)
        {
         if(g_lookup_vals[slot] < 0)
           {
            g_lookup_keys[slot] = key;
            g_lookup_vals[slot] = i;
            break;
           }
         slot++;
         if(slot >= g_lookup_capacity) slot = 0;
        }
     }
  }

int FindSymbolIndex(const string raw_symbol)
  {
   if(g_lookup_capacity <= 0) return -1;
   int slot = (int)(FNV1a32(raw_symbol) & (uint)(g_lookup_capacity - 1));
   int guard = 0;
   while(guard < g_lookup_capacity)
     {
      if(g_lookup_vals[slot] < 0) return -1;
      if(g_lookup_keys[slot] == raw_symbol) return g_lookup_vals[slot];
      slot++;
      if(slot >= g_lookup_capacity) slot = 0;
      guard++;
     }
   return -1;
  }

bool SymbolContinuityCompatible(const SymbolState &old_sym, const string new_raw_symbol, const double new_point)
  {
   if(old_sym.raw_symbol != new_raw_symbol) return false;
   if(IsKnownNumber(old_sym.point_from_ea1) && IsKnownNumber(new_point))
     {
      if(MathAbs(old_sym.point_from_ea1 - new_point) > 0.0)
         return false;
     }
   return true;
  }

void MarkSymbolHealth(SymbolState &sym)
  {
   int score = 0;
   if(sym.ea1_valid) score += 20;
   if(sym.tf[TFIDX_M1].ready) score += 15;
   if(sym.tf[TFIDX_M5].ready) score += 15;
   if(sym.tf[TFIDX_M15].ready) score += 15;
   if(sym.publishable_metrics) score += 15;
   if(sym.metrics_min_ready) score += 10;
   if(sym.intraday_metrics_fresh) score += 10;
   if(sym.persistence_loaded && sym.persistence_fresh) score += 5;
   if(sym.market_open_now_from_ea1 && !sym.tf[TFIDX_M1].fresh) score -= 15;
   if(sym.market_open_now_from_ea1 && !sym.spread_current_enough_for_ratios) score -= 5;

   score = ClampInt(score, 0, 100);
   sym.operational_health_score = score;

   if(!sym.ea1_valid)
      sym.summary_state = "UNUSABLE";
   else if(sym.metrics_min_ready && sym.intraday_metrics_fresh)
      sym.summary_state = "GOOD";
   else if(sym.publishable_metrics)
      sym.summary_state = "PARTIAL";
   else if(sym.tf[TFIDX_M1].bars_loaded > 0 || sym.tf[TFIDX_M5].bars_loaded > 0 || sym.tf[TFIDX_M15].bars_loaded > 0)
      sym.summary_state = "WARMUP";
   else
      sym.summary_state = "DEGRADED";
  }

string BuildPersistencePayloadHash(const SymbolState &sym)
  {
   string s = "";
   s += sym.raw_symbol + "|";
   s += sym.ea1_universe_fingerprint + "|";
   s += LongToStringSafe(sym.ea1_snapshot_minute_id) + "|";
   for(int tf = 0; tf < TF_COUNT; tf++)
     {
      s += "|" + LongToStringSafe((long)sym.tf[tf].last_bar_time);
      s += "|" + IntegerToString(sym.tf[tf].bars_loaded);
     }
   return FNV1a32Hex(s);
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
   if(len < 0 || len > 8192) return false;
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

bool SaveSymbolPersistence(SymbolState &sym)
  {
   string final_rel = BuildPersistenceFilePath(sym.raw_symbol);
   string backup_rel = BuildPersistenceBackupPath(sym.raw_symbol);
   string tmp_rel = final_rel + ".tmp";

   int h = FileOpen(tmp_rel, FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      sym.persistence_state = PTX_SAVE_FAILED;
      sym.persistence_dirty = true;
      g_cnt_persist_save_fail++;
      return false;
     }

   bool ok = true;
   ok &= WriteBinInt(h, PERSIST_SCHEMA_VERSION);
   ok &= WriteBinString(h, EA_ENGINE_VERSION);
   ok &= WriteBinString(h, EA_SCHEMA_VERSION);
   ok &= WriteBinString(h, BuildSymbolIdentityHash(sym.raw_symbol));
   ok &= WriteBinString(h, sym.raw_symbol);
   ok &= WriteBinString(h, g_upstream_fingerprint);
   ok &= WriteBinLong(h, g_upstream_minute_id);
   ok &= WriteBinDateTime(h, g_schedule.now_server_time);
   ok &= WriteBinDouble(h, sym.point_from_ea1);

   for(int tf = 0; tf < TF_COUNT; tf++)
     {
      ok &= WriteBinInt(h, sym.tf[tf].bars_loaded);
      ok &= WriteBinDateTime(h, sym.tf[tf].last_bar_time);
     }

   int count = sym.tf[TFIDX_M1].bars_loaded;
   ok &= WriteBinInt(h, count);
   for(int i = 0; i < count; i++)
     {
      ok &= WriteBinDateTime(h, sym.m1_time[i]);
      ok &= WriteBinDouble(h, sym.m1_open[i]);
      ok &= WriteBinDouble(h, sym.m1_high[i]);
      ok &= WriteBinDouble(h, sym.m1_low[i]);
      ok &= WriteBinDouble(h, sym.m1_close[i]);
     }

   count = sym.tf[TFIDX_M5].bars_loaded;
   ok &= WriteBinInt(h, count);
   for(int j = 0; j < count; j++)
     {
      ok &= WriteBinDateTime(h, sym.m5_time[j]);
      ok &= WriteBinDouble(h, sym.m5_open[j]);
      ok &= WriteBinDouble(h, sym.m5_high[j]);
      ok &= WriteBinDouble(h, sym.m5_low[j]);
      ok &= WriteBinDouble(h, sym.m5_close[j]);
     }

   count = sym.tf[TFIDX_M15].bars_loaded;
   ok &= WriteBinInt(h, count);
   for(int k = 0; k < count; k++)
     {
      ok &= WriteBinDateTime(h, sym.m15_time[k]);
      ok &= WriteBinDouble(h, sym.m15_open[k]);
      ok &= WriteBinDouble(h, sym.m15_high[k]);
      ok &= WriteBinDouble(h, sym.m15_low[k]);
      ok &= WriteBinDouble(h, sym.m15_close[k]);
     }

   count = sym.tf[TFIDX_D1].bars_loaded;
   ok &= WriteBinInt(h, count);
   for(int m = 0; m < count; m++)
     {
      ok &= WriteBinDateTime(h, sym.d1_time[m]);
      ok &= WriteBinDouble(h, sym.d1_open[m]);
      ok &= WriteBinDouble(h, sym.d1_high[m]);
      ok &= WriteBinDouble(h, sym.d1_low[m]);
      ok &= WriteBinDouble(h, sym.d1_close[m]);
     }

   FileClose(h);

   if(!ok)
     {
      FileDelete(tmp_rel, FILE_COMMON);
      sym.persistence_state = PTX_SAVE_FAILED;
      sym.persistence_dirty = true;
      g_cnt_persist_save_fail++;
      return false;
     }

   if(InpPersistenceBackupEnabled)
      BestEffortBackup(final_rel, backup_rel);
   if(FileIsExist(final_rel, FILE_COMMON)) FileDelete(final_rel, FILE_COMMON);

   if(!FileMove(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
     {
      FileDelete(tmp_rel, FILE_COMMON);
      sym.persistence_state = PTX_SAVE_FAILED;
      sym.persistence_dirty = true;
      g_cnt_persist_save_fail++;
      return false;
     }

   sym.persistence_state = PTX_SAVED_OK;
   sym.persistence_loaded = true;
   sym.persistence_fresh = true;
   sym.persistence_stale = false;
   sym.persistence_corrupt = false;
   sym.persistence_incompatible = false;
   if(sym.continuity_origin == CO_NONE) sym.continuity_origin = CO_CLEAN;
   sym.last_persistence_save_time = g_schedule.now_server_time;
   sym.continuity_last_good_server_time = g_schedule.now_server_time;
   sym.persistence_dirty = false;
   sym.persisted_fingerprint = g_upstream_fingerprint;
   sym.persisted_minute_id = g_upstream_minute_id;
   sym.persisted_point = sym.point_from_ea1;
   sym.last_saved_payload_hash = BuildPersistencePayloadHash(sym);

   g_cnt_persist_save_ok++;
   AddEvent("persistence_saved", sym.raw_symbol);
   return true;
  }

bool LoadSymbolPersistence(SymbolState &sym)
  {
   ResetPersistenceState(sym);

   string final_rel = BuildPersistenceFilePath(sym.raw_symbol);
   string backup_rel = BuildPersistenceBackupPath(sym.raw_symbol);
   string use_rel = final_rel;
   if(!FileIsExist(use_rel, FILE_COMMON))
     {
      if(FileIsExist(backup_rel, FILE_COMMON))
         use_rel = backup_rel;
      else
        {
         sym.persistence_state = PTX_NOT_FOUND;
         sym.restarted_clean = true;
         sym.continuity_origin = CO_CLEAN;
         sym.persistence_dirty = true;
         AddEvent("persistence_missing", sym.raw_symbol);
         return false;
        }
     }

   int h = FileOpen(use_rel, FILE_READ | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      sym.persistence_state = PTX_CORRUPT_DISCARDED;
      sym.persistence_corrupt = true;
      sym.restarted_clean = true;
      sym.continuity_origin = CO_CLEAN;
      sym.persistence_dirty = true;
      g_cnt_persist_corrupt_discard++;
      g_cnt_persist_load_fail++;
      AddEvent("persistence_discarded_corrupt", sym.raw_symbol);
      return false;
     }

   bool ok = true;
   int schema = 0;
   string engine = "", schema_ver = "", ident = "", raw = "", fp = "";
   long up_minute = -1;
   datetime saved_at = 0;
   double saved_point = EMPTY_VALUE;

   ok &= ReadBinInt(h, schema);
   ok &= ReadBinString(h, engine);
   ok &= ReadBinString(h, schema_ver);
   ok &= ReadBinString(h, ident);
   ok &= ReadBinString(h, raw);
   ok &= ReadBinString(h, fp);
   ok &= ReadBinLong(h, up_minute);
   ok &= ReadBinDateTime(h, saved_at);
   ok &= ReadBinDouble(h, saved_point);

   if(!ok || schema != PERSIST_SCHEMA_VERSION || engine != EA_ENGINE_VERSION || ident != BuildSymbolIdentityHash(sym.raw_symbol) || raw != sym.raw_symbol)
     {
      FileClose(h);
      sym.persistence_state = PTX_INCOMPATIBLE_DISCARDED;
      sym.persistence_incompatible = true;
      sym.restarted_clean = true;
      sym.continuity_origin = CO_CLEAN;
      sym.persistence_dirty = true;
      g_cnt_persist_incompat_discard++;
      g_cnt_persist_load_fail++;
      AddEvent("persistence_discarded_incompatible", sym.raw_symbol);
      return false;
     }

   int age_sec = 0;
   if(g_schedule.now_server_time > 0 && saved_at > 0 && g_schedule.now_server_time >= saved_at)
      age_sec = (int)(g_schedule.now_server_time - saved_at);
   if(saved_at <= 0 || age_sec > InpPersistenceMaxAgeSec)
     {
      FileClose(h);
      sym.persistence_state = PTX_STALE_DISCARDED;
      sym.persistence_stale = true;
      sym.persistence_age_sec = age_sec;
      sym.restarted_clean = true;
      sym.continuity_origin = CO_CLEAN;
      sym.persistence_dirty = true;
      g_cnt_persist_stale_discard++;
      g_cnt_persist_load_fail++;
      AddEvent("persistence_discarded_stale", sym.raw_symbol);
      return false;
     }

   sym.persisted_fingerprint = fp;
   sym.persisted_minute_id = up_minute;
   sym.persisted_point = saved_point;

   for(int tf = 0; tf < TF_COUNT; tf++)
     {
      int count = 0;
      datetime last_bar = 0;
      ok &= ReadBinInt(h, count);
      ok &= ReadBinDateTime(h, last_bar);
      sym.tf[tf].bars_loaded = count;
      sym.tf[tf].last_bar_time = last_bar;
      sym.saved_last_bar_time[tf] = last_bar;
     }

   int count = 0;
   ok &= ReadBinInt(h, count);
   if(count < 0 || count > CAP_M1) ok = false;
   for(int i = 0; ok && i < count; i++)
     {
      ok &= ReadBinDateTime(h, sym.m1_time[i]);
      ok &= ReadBinDouble(h, sym.m1_open[i]);
      ok &= ReadBinDouble(h, sym.m1_high[i]);
      ok &= ReadBinDouble(h, sym.m1_low[i]);
      ok &= ReadBinDouble(h, sym.m1_close[i]);
     }
   sym.tf[TFIDX_M1].bars_loaded = count;

   count = 0;
   ok &= ReadBinInt(h, count);
   if(count < 0 || count > CAP_M5) ok = false;
   for(int j = 0; ok && j < count; j++)
     {
      ok &= ReadBinDateTime(h, sym.m5_time[j]);
      ok &= ReadBinDouble(h, sym.m5_open[j]);
      ok &= ReadBinDouble(h, sym.m5_high[j]);
      ok &= ReadBinDouble(h, sym.m5_low[j]);
      ok &= ReadBinDouble(h, sym.m5_close[j]);
     }
   sym.tf[TFIDX_M5].bars_loaded = count;

   count = 0;
   ok &= ReadBinInt(h, count);
   if(count < 0 || count > CAP_M15) ok = false;
   for(int k = 0; ok && k < count; k++)
     {
      ok &= ReadBinDateTime(h, sym.m15_time[k]);
      ok &= ReadBinDouble(h, sym.m15_open[k]);
      ok &= ReadBinDouble(h, sym.m15_high[k]);
      ok &= ReadBinDouble(h, sym.m15_low[k]);
      ok &= ReadBinDouble(h, sym.m15_close[k]);
     }
   sym.tf[TFIDX_M15].bars_loaded = count;

   count = 0;
   ok &= ReadBinInt(h, count);
   if(count < 0 || count > CAP_D1) ok = false;
   for(int m = 0; ok && m < count; m++)
     {
      ok &= ReadBinDateTime(h, sym.d1_time[m]);
      ok &= ReadBinDouble(h, sym.d1_open[m]);
      ok &= ReadBinDouble(h, sym.d1_high[m]);
      ok &= ReadBinDouble(h, sym.d1_low[m]);
      ok &= ReadBinDouble(h, sym.d1_close[m]);
     }
   sym.tf[TFIDX_D1].bars_loaded = count;

   FileClose(h);

   if(!ok)
     {
      sym.persistence_state = PTX_CORRUPT_DISCARDED;
      sym.persistence_corrupt = true;
      sym.restarted_clean = true;
      sym.continuity_origin = CO_CLEAN;
      sym.persistence_dirty = true;
      g_cnt_persist_corrupt_discard++;
      g_cnt_persist_load_fail++;
      AddEvent("persistence_discarded_corrupt", sym.raw_symbol);
      return false;
     }

   sym.persistence_state = PTX_LOADED_FRESH;
   sym.persistence_loaded = true;
   sym.persistence_fresh = true;
   sym.persistence_stale = false;
   sym.persistence_corrupt = false;
   sym.persistence_incompatible = false;
   sym.resumed_from_persistence = true;
   sym.restarted_clean = false;
   sym.persistence_age_sec = age_sec;
   sym.continuity_origin = CO_PERSISTENCE;
   sym.continuity_last_good_server_time = saved_at;
   sym.last_persistence_save_time = saved_at;
   sym.persistence_dirty = true;
   sym.last_saved_payload_hash = BuildPersistencePayloadHash(sym);

   for(int tf2 = 0; tf2 < TF_COUNT; tf2++)
     {
      sym.tf[tf2].ready = (sym.tf[tf2].bars_loaded >= TfReadyBars(tf2) && sym.tf[tf2].last_bar_time > 0);
      sym.tf[tf2].coherent = (sym.tf[tf2].bars_loaded > 0);
      sym.tf[tf2].phase = TFP_REPAIR;
      sym.tf[tf2].next_due_server = g_schedule.now_server_time;
     }

   g_cnt_persist_load_ok++;
   AddEvent("persistence_loaded", sym.raw_symbol);
   return true;
  }

void ApplyUpstreamToSymbol(SymbolState &sym, const int idx)
  {
   sym.ea1_present = true;
   sym.ea1_valid = true;
   if(g_upstream_source == UPSRC_CURRENT) sym.ea1_source_used = "current";
   else if(g_upstream_source == UPSRC_PREVIOUS) sym.ea1_source_used = "previous";
   else if(g_upstream_source == UPSRC_LAST_GOOD) sym.ea1_source_used = "last_good";
   else sym.ea1_source_used = "none";
   sym.ea1_snapshot_minute_id = g_upstream_minute_id;
   sym.ea1_snapshot_age_min = (int)(GetMinuteId(g_schedule.now_server_time) - g_upstream_minute_id);
   sym.ea1_universe_fingerprint = g_upstream_fingerprint;
   sym.market_open_now_from_ea1 = g_upstream_market_open[idx];
   sym.market_reason_code_from_ea1 = g_upstream_market_reason[idx];
   sym.spread_points_from_ea1 = g_upstream_spreads[idx];
   sym.point_from_ea1 = g_upstream_points[idx];
   sym.spec_min_ready_from_ea1 = g_upstream_spec_ready[idx];

   int max_age = sym.market_open_now_from_ea1 ? InpOpenSpreadMaxAgeMin : InpClosedSpreadMaxAgeMin;
   sym.spread_current_enough_for_ratios = (IsKnownNumber(sym.spread_points_from_ea1) && sym.ea1_snapshot_age_min <= max_age);

   if(!sym.metrics_dirty && !IsKnownNumber(sym.point_from_ea1))
     {
      sym.atr_points_m1 = EMPTY_VALUE;
      sym.atr_points_m5 = EMPTY_VALUE;
      sym.atr_points_m15 = EMPTY_VALUE;
      sym.volatility_accel = EMPTY_VALUE;
      sym.vol_expansion = EMPTY_VALUE;
      sym.spread_to_atr_m1_ratio = EMPTY_VALUE;
      sym.spread_to_atr_m5_ratio = EMPTY_VALUE;
     }
   sym.metrics_dirty = true;
   sym.persistence_dirty = true;
   sym.upstream_reason_code = "upstream_ok";
  }

void RebuildRuntimeFromUpstream()
  {
   SymbolState old_symbols[];
   int old_count = g_symbol_count;
   ArrayResize(old_symbols, old_count);
   for(int i = 0; i < old_count; i++)
      old_symbols[i] = g_symbols[i];

   ArrayResize(g_symbols, g_upstream_symbol_count);
   g_symbol_count = g_upstream_symbol_count;

   for(int j = 0; j < g_upstream_symbol_count; j++)
     {
      string raw_symbol = g_upstream_symbols[j];
      int old_idx = -1;
      for(int k = 0; k < old_count; k++)
        {
         if(old_symbols[k].raw_symbol == raw_symbol)
           {
            old_idx = k;
            break;
           }
        }

      if(old_idx >= 0 && SymbolContinuityCompatible(old_symbols[old_idx], raw_symbol, g_upstream_points[j]))
        {
         g_symbols[j] = old_symbols[old_idx];
         g_symbols[j].symbol_index_from_ea1 = j;
         g_symbols[j].upstream_join_key_present = true;
         g_symbols[j].continuity_origin = CO_RUNTIME_PRESERVED;
        }
      else
        {
         ResetSymbolState(g_symbols[j], raw_symbol, j);
         if(InpPersistenceEnabled)
           {
            ulong tload0 = GetMicrosecondCount() / 1000;
            LoadSymbolPersistence(g_symbols[j]);
            g_perf.dur_persist_load_ms += (int)((GetMicrosecondCount() / 1000) - tload0);
            if(g_symbols[j].persistence_loaded &&
               IsKnownNumber(g_symbols[j].persisted_point) &&
               IsKnownNumber(g_upstream_points[j]) &&
               MathAbs(g_symbols[j].persisted_point - g_upstream_points[j]) > 0.0)
              {
               ResetSymbolState(g_symbols[j], raw_symbol, j);
               g_symbols[j].persistence_state = PTX_INCOMPATIBLE_DISCARDED;
               g_symbols[j].persistence_incompatible = true;
               g_symbols[j].restarted_clean = true;
               g_symbols[j].continuity_origin = CO_CLEAN;
               g_cnt_persist_incompat_discard++;
               AddEvent("persistence_discarded_incompatible", raw_symbol);
              }
           }
         else
           {
            g_symbols[j].persistence_state = PTX_CLEAN_START;
            g_symbols[j].restarted_clean = true;
            g_symbols[j].continuity_origin = CO_CLEAN;
           }
        }

      ApplyUpstreamToSymbol(g_symbols[j], j);
      for(int tf = 0; tf < TF_COUNT; tf++)
        {
         if(g_symbols[j].tf[tf].next_due_server <= 0)
            g_symbols[j].tf[tf].next_due_server = g_schedule.now_server_time + TfJitterSec(raw_symbol, tf, MathMax(2, TfSteadyRefreshSec(tf)));
         if(g_symbols[j].tf[tf].bars_required <= 0)
            g_symbols[j].tf[tf].bars_required = TfReadyBars(tf);
        }
     }

   BuildSymbolLookup();
  }


bool AcceptCandidateSnapshot(const long cand_minute_id, const string cand_fingerprint)
  {
   if(cand_minute_id < 0 || cand_fingerprint == "") return false;
   if(!g_have_upstream) return true;
   if(cand_fingerprint == g_upstream_fingerprint) return true;
   if(cand_minute_id > g_upstream_minute_id) return true;
   return false;
  }

bool TryAcceptUpstreamFromText(const string text, const UpstreamSource src, const string src_label, bool &valid_flag, bool &rejected_flag, string &err_out)
  {
   valid_flag = false;
   rejected_flag = false;
   err_out = "";

   long cand_minute = -1;
   string cand_fp = "";
   string arr_symbols[];
   double arr_points[];
   bool arr_spec_ready[];
   double arr_spreads[];
   bool arr_open[];
   int arr_reason[];

   ulong t_parse0 = GetMicrosecondCount() / 1000;
   bool parsed = ParseUpstreamSnapshot(text, cand_minute, cand_fp, err_out, arr_symbols, arr_points, arr_spec_ready, arr_spreads, arr_open, arr_reason);
   g_perf.dur_upstream_parse_ms += (int)((GetMicrosecondCount() / 1000) - t_parse0);
   if(!parsed)
      return false;

   valid_flag = true;
   if(!AcceptCandidateSnapshot(cand_minute, cand_fp))
     {
      rejected_flag = true;
      err_out = "fingerprint_older_or_equal";
      g_cnt_upstream_rejects++;
      return false;
     }

   bool rebuild = (!g_have_upstream || cand_fp != g_upstream_fingerprint || ArraySize(arr_symbols) != g_symbol_count);
   g_upstream_minute_id = cand_minute;
   g_upstream_fingerprint = cand_fp;
   g_upstream_source = src;

   g_upstream_symbol_count = ArraySize(arr_symbols);
   ArrayResize(g_upstream_symbols, g_upstream_symbol_count);
   ArrayResize(g_upstream_points, g_upstream_symbol_count);
   ArrayResize(g_upstream_spec_ready, g_upstream_symbol_count);
   ArrayResize(g_upstream_spreads, g_upstream_symbol_count);
   ArrayResize(g_upstream_market_open, g_upstream_symbol_count);
   ArrayResize(g_upstream_market_reason, g_upstream_symbol_count);

   for(int i = 0; i < g_upstream_symbol_count; i++)
     {
      g_upstream_symbols[i] = arr_symbols[i];
      g_upstream_points[i] = arr_points[i];
      g_upstream_spec_ready[i] = arr_spec_ready[i];
      g_upstream_spreads[i] = arr_spreads[i];
      g_upstream_market_open[i] = arr_open[i];
      g_upstream_market_reason[i] = arr_reason[i];
     }

   g_have_upstream = true;
   if(rebuild)
     {
      RebuildRuntimeFromUpstream();
      if(src == UPSRC_CURRENT || src == UPSRC_PREVIOUS)
         AddEvent("fingerprint_changed_newer", cand_fp);
     }
   else
     {
      for(int j = 0; j < g_symbol_count; j++)
         ApplyUpstreamToSymbol(g_symbols[j], j);
     }

   g_upstream_diag.active_valid = true;
   g_upstream_diag.source_used = src;
   g_upstream_diag.active_minute_id = cand_minute;
   g_upstream_diag.active_age_min = (int)(GetMinuteId(g_schedule.now_server_time) - cand_minute);
   g_upstream_diag.active_fingerprint = cand_fp;
   g_upstream_diag.active_reason = src_label;
   g_upstream_diag.active_symbol_count = g_upstream_symbol_count;

   g_cnt_upstream_accepts++;
   AddEvent("upstream_" + src_label + "_ok", cand_fp);
   return true;
  }

void RunUpstreamRead()
  {
   if(g_schedule.now_server_time <= 0) return;

   long cur_minute = GetMinuteId(g_schedule.now_server_time);
   int sec_in_min = (int)(g_schedule.now_server_time % 60);

   if(g_upstream_diag.read_attempt_minute_id != cur_minute)
     {
      g_upstream_diag.read_attempt_minute_id = cur_minute;
      g_upstream_diag.read_attempts_this_minute = 0;
     }

   if(sec_in_min < InpUpstreamReadStartSec || sec_in_min > InpUpstreamReadEndSec)
      return;
   if(g_upstream_diag.read_attempts_this_minute >= InpUpstreamReadAttemptsPerMin)
      return;

   g_upstream_diag.read_attempts_this_minute++;
   int attempts_now = g_upstream_diag.read_attempts_this_minute;
   ResetUpstreamDiag();
   g_upstream_diag.read_attempt_minute_id = cur_minute;
   g_upstream_diag.read_attempts_this_minute = attempts_now;
   g_upstream_diag.last_read_server_time = g_schedule.now_server_time;

   g_cnt_upstream_reads++;
   ulong t0 = GetMicrosecondCount() / 1000;

   string current_text = "", prev_text = "", err = "";
   g_upstream_diag.current_exists = FileIsExist(g_ea1_stage_file, FILE_COMMON);
   g_upstream_diag.previous_exists = FileIsExist(g_ea1_stage_prev_file, FILE_COMMON);

   bool current_ok = false;
   bool prev_ok = false;
   bool current_reject = false;
   bool prev_reject = false;
   string current_err = "", prev_err = "";

   if(g_upstream_diag.current_exists && ReadTextFileCommon(g_ea1_stage_file, current_text, err))
      current_ok = TryAcceptUpstreamFromText(current_text, UPSRC_CURRENT, "current", g_upstream_diag.current_valid, current_reject, current_err);
   else if(g_upstream_diag.current_exists)
      current_err = err;
   else
      current_err = "missing";

   if(!current_ok)
     {
      if(current_reject) g_upstream_diag.current_rejected = true;
      g_upstream_diag.current_error = current_err;

      if(g_upstream_diag.previous_exists && ReadTextFileCommon(g_ea1_stage_prev_file, prev_text, err))
         prev_ok = TryAcceptUpstreamFromText(prev_text, UPSRC_PREVIOUS, "previous", g_upstream_diag.previous_valid, prev_reject, prev_err);
      else if(g_upstream_diag.previous_exists)
         prev_err = err;
      else
         prev_err = "missing";

      if(prev_reject) g_upstream_diag.previous_rejected = true;
      g_upstream_diag.previous_error = prev_err;
     }

   if(!current_ok && !prev_ok && g_have_upstream)
     {
      g_upstream_source = UPSRC_LAST_GOOD;
      g_upstream_diag.last_good_applied = true;
      g_upstream_diag.source_used = UPSRC_LAST_GOOD;
      g_upstream_diag.active_valid = true;
      g_upstream_diag.active_minute_id = g_upstream_minute_id;
      g_upstream_diag.active_age_min = (int)(GetMinuteId(g_schedule.now_server_time) - g_upstream_minute_id);
      g_upstream_diag.active_fingerprint = g_upstream_fingerprint;
      g_upstream_diag.active_reason = "last_good_applied";
      for(int i = 0; i < g_symbol_count; i++)
        {
         g_symbols[i].ea1_source_used = "last_good";
         g_symbols[i].ea1_snapshot_age_min = g_upstream_diag.active_age_min;
         g_symbols[i].spread_current_enough_for_ratios =
            (IsKnownNumber(g_symbols[i].spread_points_from_ea1) &&
             g_symbols[i].ea1_snapshot_age_min <= (g_symbols[i].market_open_now_from_ea1 ? InpOpenSpreadMaxAgeMin : InpClosedSpreadMaxAgeMin));
         g_symbols[i].upstream_reason_code = "last_good_applied";
         g_symbols[i].metrics_dirty = true;
        }
      AddEvent("upstream_last_good", g_upstream_fingerprint);
     }

   g_perf.dur_upstream_read_ms = (int)((GetMicrosecondCount() / 1000) - t0);
  }

bool IsTfFresh(const datetime last_bar, const int tf_idx)
  {
   if(last_bar <= 0 || g_schedule.now_server_time <= 0) return false;
   int age = (int)(g_schedule.now_server_time - last_bar);
   if(age < 0) return false;
   return (age <= TfFreshThresholdSec(tf_idx));
  }

int ComputeCooldownSec(const string raw_symbol, const int tf_idx, const int fail_count)
  {
   int base = (tf_idx == TFIDX_D1 ? InpD1FailureCooldownBaseSec : InpFailureCooldownBaseSec);
   int grow = base;
   for(int i = 1; i < fail_count; i++)
     {
      grow *= 2;
      if(grow >= InpFailureCooldownMaxSec)
        {
         grow = InpFailureCooldownMaxSec;
         break;
        }
     }
   return ClampInt(grow + TfJitterSec(raw_symbol, tf_idx, MathMax(2, grow)), base, InpFailureCooldownMaxSec);
  }

int DetermineRequestCount(const SymbolState &sym, const int tf_idx)
  {
   int cap = TfCapacity(tf_idx);
   int loaded = sym.tf[tf_idx].bars_loaded;
   int phase = sym.tf[tf_idx].phase;

   if(phase == TFP_NOT_STARTED || phase == TFP_BOOTSTRAP || loaded <= 0)
      return MathMin(cap + 8, cap);
   if(phase == TFP_REPAIR || phase == TFP_FAILING)
     {
      int req = MathMin(cap, TfReadyBars(tf_idx) + 48);
      if(tf_idx == TFIDX_D1) req = MathMin(cap, 16);
      return req;
     }
   if(tf_idx == TFIDX_M1) return MathMin(cap, 48);
   if(tf_idx == TFIDX_M5) return MathMin(cap, 48);
   if(tf_idx == TFIDX_M15) return MathMin(cap, 48);
   return MathMin(cap, 16);
  }

bool ValidateFetchedRates(const MqlRates &rates[], const int count, const int tf_idx, datetime &last_bar, int &age_sec)
  {
   last_bar = 0;
   age_sec = 0;
   if(count <= 0) return false;

   int tf_sec = TfSeconds(tf_idx);
   datetime current_bucket_open = (datetime)((long)(g_schedule.now_server_time / tf_sec) * tf_sec);

   datetime prev_t = 0;
   for(int i = 0; i < count; i++)
     {
      datetime t = rates[i].time;
      if(t <= 0) return false;
      if(prev_t > 0 && t <= prev_t) return false;
      if((int)(t % tf_sec) != 0) return false;
      if(t >= current_bucket_open) return false;
      if(rates[i].high < rates[i].low) return false;
      double hi_max = MathMax(rates[i].open, MathMax(rates[i].close, rates[i].low));
      double lo_min = MathMin(rates[i].open, MathMin(rates[i].close, rates[i].high));
      if(rates[i].high < hi_max) return false;
      if(rates[i].low > lo_min) return false;
      prev_t = t;
     }

   last_bar = rates[count - 1].time;
   age_sec = (int)(g_schedule.now_server_time - last_bar);
   if(age_sec < 0) age_sec = 0;
   return true;
  }

void CopyRatesIntoSymbol(SymbolState &sym, const int tf_idx, const MqlRates &rates[], const int count, const datetime last_bar, const int age_sec)
  {
   if(tf_idx == TFIDX_M1)
     {
      for(int i = 0; i < count; i++)
        {
         sym.m1_time[i] = rates[i].time;
         sym.m1_open[i] = rates[i].open;
         sym.m1_high[i] = rates[i].high;
         sym.m1_low[i] = rates[i].low;
         sym.m1_close[i] = rates[i].close;
        }
     }
   else if(tf_idx == TFIDX_M5)
     {
      for(int j = 0; j < count; j++)
        {
         sym.m5_time[j] = rates[j].time;
         sym.m5_open[j] = rates[j].open;
         sym.m5_high[j] = rates[j].high;
         sym.m5_low[j] = rates[j].low;
         sym.m5_close[j] = rates[j].close;
        }
     }
   else if(tf_idx == TFIDX_M15)
     {
      for(int k = 0; k < count; k++)
        {
         sym.m15_time[k] = rates[k].time;
         sym.m15_open[k] = rates[k].open;
         sym.m15_high[k] = rates[k].high;
         sym.m15_low[k] = rates[k].low;
         sym.m15_close[k] = rates[k].close;
        }
     }
   else
     {
      for(int m = 0; m < count; m++)
        {
         sym.d1_time[m] = rates[m].time;
         sym.d1_open[m] = rates[m].open;
         sym.d1_high[m] = rates[m].high;
         sym.d1_low[m] = rates[m].low;
         sym.d1_close[m] = rates[m].close;
        }
     }

   sym.tf[tf_idx].bars_loaded = count;
   sym.tf[tf_idx].coherent = true;
   sym.tf[tf_idx].last_bar_time = last_bar;
   sym.tf[tf_idx].bar_age_sec = age_sec;
   sym.tf[tf_idx].fresh = IsTfFresh(last_bar, tf_idx);
   sym.tf[tf_idx].stale = (count > 0 && !sym.tf[tf_idx].fresh);
   sym.tf[tf_idx].ready = (count >= TfReadyBars(tf_idx) && last_bar > 0);
   sym.tf[tf_idx].last_success_server_time = g_schedule.now_server_time;
   sym.tf[tf_idx].last_hydrate_server_time = g_schedule.now_server_time;
   sym.tf[tf_idx].fail_count = 0;
   sym.tf[tf_idx].cooldown_until = 0;
   sym.tf[tf_idx].phase = TFP_STEADY;
   sym.tf[tf_idx].next_due_server = g_schedule.now_server_time + TfSteadyRefreshSec(tf_idx) + TfJitterSec(sym.raw_symbol, tf_idx, TfSteadyRefreshSec(tf_idx));
   sym.metrics_dirty = true;
   sym.persistence_dirty = true;
  }

bool HydrateTimeframe(SymbolState &sym, const int tf_idx)
  {
   g_cnt_hydrate_calls++;
   sym.tf[tf_idx].last_attempt_server_time = g_schedule.now_server_time;

   int request_count = DetermineRequestCount(sym, tf_idx);
   MqlRates raw_rates[];
   ArrayResize(raw_rates, 0);

   ResetLastError();
   int copied = CopyRates(sym.raw_symbol, TfEnum(tf_idx), 0, request_count + 1, raw_rates);
   if(copied <= 1)
     {
      sym.tf[tf_idx].fail_count++;
      sym.tf[tf_idx].coherent = false;
      sym.tf[tf_idx].ready = false;
      sym.tf[tf_idx].fresh = false;
      sym.tf[tf_idx].stale = (sym.tf[tf_idx].bars_loaded > 0);
      sym.tf[tf_idx].phase = (sym.tf[tf_idx].fail_count >= 3 ? TFP_COOLDOWN : TFP_FAILING);
      int cd = ComputeCooldownSec(sym.raw_symbol, tf_idx, sym.tf[tf_idx].fail_count);
      sym.tf[tf_idx].cooldown_until = g_schedule.now_server_time + cd;
      sym.tf[tf_idx].next_due_server = sym.tf[tf_idx].cooldown_until;
      sym.metrics_dirty = true;
      g_cnt_hydrate_fail++;
      AddEvent(LowerStr(TfLabel(tf_idx)) + "_sync_fail", sym.raw_symbol);
      return false;
     }

   int usable = copied - 1;
   if(usable > TfCapacity(tf_idx)) usable = TfCapacity(tf_idx);

   MqlRates completed[];
   ArrayResize(completed, usable);
   for(int i = 0; i < usable; i++)
      completed[i] = raw_rates[i];

   datetime last_bar = 0;
   int age_sec = 0;
   if(!ValidateFetchedRates(completed, usable, tf_idx, last_bar, age_sec))
     {
      sym.tf[tf_idx].fail_count++;
      sym.tf[tf_idx].coherent = false;
      sym.tf[tf_idx].ready = false;
      sym.tf[tf_idx].fresh = false;
      sym.tf[tf_idx].phase = (sym.tf[tf_idx].fail_count >= 3 ? TFP_COOLDOWN : TFP_REPAIR);
      int cd2 = ComputeCooldownSec(sym.raw_symbol, tf_idx, sym.tf[tf_idx].fail_count);
      sym.tf[tf_idx].cooldown_until = g_schedule.now_server_time + cd2;
      sym.tf[tf_idx].next_due_server = sym.tf[tf_idx].cooldown_until;
      sym.metrics_dirty = true;
      g_cnt_hydrate_fail++;
      AddEvent(LowerStr(TfLabel(tf_idx)) + "_coherence_fail", sym.raw_symbol);
      return false;
     }

   CopyRatesIntoSymbol(sym, tf_idx, completed, usable, last_bar, age_sec);
   g_cnt_hydrate_success++;
   AddEvent(LowerStr(TfLabel(tf_idx)) + "_sync_ok", sym.raw_symbol);
   return true;
  }


double ComputeAtrForTf(const SymbolState &sym, const int tf_idx)
  {
   int count = sym.tf[tf_idx].bars_loaded;
   if(count < ATR_MIN_BARS) return EMPTY_VALUE;
   if(!sym.tf[tf_idx].coherent) return EMPTY_VALUE;

   double atr = 0.0;
   if(tf_idx == TFIDX_M1)
     {
      for(int i = 1; i <= ATR_PERIOD; i++)
        {
         double tr1 = sym.m1_high[i] - sym.m1_low[i];
         double tr2 = MathAbs(sym.m1_high[i] - sym.m1_close[i - 1]);
         double tr3 = MathAbs(sym.m1_low[i] - sym.m1_close[i - 1]);
         atr += MathMax(tr1, MathMax(tr2, tr3));
        }
      atr /= ATR_PERIOD;
      for(int j = ATR_PERIOD + 1; j < count; j++)
        {
         double tr1b = sym.m1_high[j] - sym.m1_low[j];
         double tr2b = MathAbs(sym.m1_high[j] - sym.m1_close[j - 1]);
         double tr3b = MathAbs(sym.m1_low[j] - sym.m1_close[j - 1]);
         double trb = MathMax(tr1b, MathMax(tr2b, tr3b));
         atr = ((atr * (ATR_PERIOD - 1)) + trb) / ATR_PERIOD;
        }
      return atr;
     }
   if(tf_idx == TFIDX_M5)
     {
      for(int k = 1; k <= ATR_PERIOD; k++)
        {
         double tr1c = sym.m5_high[k] - sym.m5_low[k];
         double tr2c = MathAbs(sym.m5_high[k] - sym.m5_close[k - 1]);
         double tr3c = MathAbs(sym.m5_low[k] - sym.m5_close[k - 1]);
         atr += MathMax(tr1c, MathMax(tr2c, tr3c));
        }
      atr /= ATR_PERIOD;
      for(int m = ATR_PERIOD + 1; m < count; m++)
        {
         double tr1d = sym.m5_high[m] - sym.m5_low[m];
         double tr2d = MathAbs(sym.m5_high[m] - sym.m5_close[m - 1]);
         double tr3d = MathAbs(sym.m5_low[m] - sym.m5_close[m - 1]);
         double trd = MathMax(tr1d, MathMax(tr2d, tr3d));
         atr = ((atr * (ATR_PERIOD - 1)) + trd) / ATR_PERIOD;
        }
      return atr;
     }
   if(tf_idx == TFIDX_M15)
     {
      for(int a = 1; a <= ATR_PERIOD; a++)
        {
         double tr1e = sym.m15_high[a] - sym.m15_low[a];
         double tr2e = MathAbs(sym.m15_high[a] - sym.m15_close[a - 1]);
         double tr3e = MathAbs(sym.m15_low[a] - sym.m15_close[a - 1]);
         atr += MathMax(tr1e, MathMax(tr2e, tr3e));
        }
      atr /= ATR_PERIOD;
      for(int b = ATR_PERIOD + 1; b < count; b++)
        {
         double tr1f = sym.m15_high[b] - sym.m15_low[b];
         double tr2f = MathAbs(sym.m15_high[b] - sym.m15_close[b - 1]);
         double tr3f = MathAbs(sym.m15_low[b] - sym.m15_close[b - 1]);
         double trf = MathMax(tr1f, MathMax(tr2f, tr3f));
         atr = ((atr * (ATR_PERIOD - 1)) + trf) / ATR_PERIOD;
        }
      return atr;
     }

   return EMPTY_VALUE;
  }

void ComputeMetrics(SymbolState &sym)
  {
   g_cnt_metrics_compute++;
   sym.atr_m1 = ComputeAtrForTf(sym, TFIDX_M1);
   sym.atr_m5 = ComputeAtrForTf(sym, TFIDX_M5);
   sym.atr_m15 = ComputeAtrForTf(sym, TFIDX_M15);

   if(IsKnownNumber(sym.point_from_ea1) && sym.point_from_ea1 > 0.0)
     {
      sym.atr_points_m1 = (IsKnownNumber(sym.atr_m1) ? sym.atr_m1 / sym.point_from_ea1 : EMPTY_VALUE);
      sym.atr_points_m5 = (IsKnownNumber(sym.atr_m5) ? sym.atr_m5 / sym.point_from_ea1 : EMPTY_VALUE);
      sym.atr_points_m15 = (IsKnownNumber(sym.atr_m15) ? sym.atr_m15 / sym.point_from_ea1 : EMPTY_VALUE);
     }
   else
     {
      sym.atr_points_m1 = EMPTY_VALUE;
      sym.atr_points_m5 = EMPTY_VALUE;
      sym.atr_points_m15 = EMPTY_VALUE;
     }

   double m1_per_min = sym.atr_points_m1;
   double m5_per_min = (IsKnownNumber(sym.atr_points_m5) ? sym.atr_points_m5 / 5.0 : EMPTY_VALUE);
   double m15_per_min = (IsKnownNumber(sym.atr_points_m15) ? sym.atr_points_m15 / 15.0 : EMPTY_VALUE);

   sym.volatility_accel = MeaningfulRatio(m1_per_min, m5_per_min);
   sym.vol_expansion = MeaningfulRatio(m5_per_min, m15_per_min);

   if(sym.spread_current_enough_for_ratios)
     {
      sym.spread_to_atr_m1_ratio = MeaningfulRatio(sym.spread_points_from_ea1, sym.atr_points_m1);
      sym.spread_to_atr_m5_ratio = MeaningfulRatio(sym.spread_points_from_ea1, sym.atr_points_m5);
     }
   else
     {
      sym.spread_to_atr_m1_ratio = EMPTY_VALUE;
      sym.spread_to_atr_m5_ratio = EMPTY_VALUE;
     }

   sym.volatility_ready = (IsKnownNumber(sym.volatility_accel) && IsKnownNumber(sym.vol_expansion));
   sym.spread_ratios_ready = (IsKnownNumber(sym.spread_to_atr_m1_ratio) || IsKnownNumber(sym.spread_to_atr_m5_ratio));
   sym.metrics_min_ready =
      (IsKnownNumber(sym.atr_m1) && IsKnownNumber(sym.atr_m5) && IsKnownNumber(sym.atr_m15) &&
       IsKnownNumber(sym.atr_points_m1) && IsKnownNumber(sym.atr_points_m5) && IsKnownNumber(sym.atr_points_m15) &&
       sym.volatility_ready);

   sym.publishable_metrics =
      (IsKnownNumber(sym.atr_m1) || IsKnownNumber(sym.atr_m5) || IsKnownNumber(sym.atr_m15) ||
       IsKnownNumber(sym.atr_points_m1) || IsKnownNumber(sym.atr_points_m5) || IsKnownNumber(sym.atr_points_m15) ||
       IsKnownNumber(sym.volatility_accel) || IsKnownNumber(sym.vol_expansion) ||
       IsKnownNumber(sym.spread_to_atr_m1_ratio) || IsKnownNumber(sym.spread_to_atr_m5_ratio));

   sym.metrics_partial = (sym.publishable_metrics && !sym.metrics_min_ready);
   sym.intraday_metrics_fresh = (sym.tf[TFIDX_M1].fresh && sym.tf[TFIDX_M5].fresh && sym.tf[TFIDX_M15].fresh);

   if(!sym.publishable_metrics)
     {
      if(sym.tf[TFIDX_M1].bars_loaded == 0 && sym.tf[TFIDX_M5].bars_loaded == 0 && sym.tf[TFIDX_M15].bars_loaded == 0)
         sym.data_reason_code = "no_bars";
      else if(sym.tf[TFIDX_M1].bars_loaded < ATR_MIN_BARS || sym.tf[TFIDX_M5].bars_loaded < ATR_MIN_BARS || sym.tf[TFIDX_M15].bars_loaded < ATR_MIN_BARS)
         sym.data_reason_code = "insufficient_bars";
      else if(!IsKnownNumber(sym.point_from_ea1))
         sym.data_reason_code = "point_missing";
      else
         sym.data_reason_code = "partial";
     }
   else if(sym.metrics_min_ready && sym.intraday_metrics_fresh)
      sym.data_reason_code = "metrics_ready";
   else if(sym.metrics_partial)
      sym.data_reason_code = "partial";
   else
      sym.data_reason_code = "stale_bars";

   if(!sym.spread_current_enough_for_ratios && sym.market_open_now_from_ea1)
      sym.data_reason_code = "stale_spread";

   MarkSymbolHealth(sym);
   sym.metrics_dirty = false;
  }

void RunMetricsComputeBudget()
  {
   if(g_symbol_count <= 0) return;
   int work = MathMin(g_symbol_count, MathMax(1, InpMetricsBudgetPerCycle));
   int done = 0;
   int scanned = 0;

   while(scanned < g_symbol_count && done < work)
     {
      int idx = g_schedule.cursor_metrics++;
      if(g_schedule.cursor_metrics >= g_symbol_count) g_schedule.cursor_metrics = 0;
      scanned++;
      if(!g_symbols[idx].metrics_dirty) continue;
      ComputeMetrics(g_symbols[idx]);
      done++;
     }
  }

void RecountCoverage()
  {
   g_cov_ready_m1_count = 0;
   g_cov_ready_m5_count = 0;
   g_cov_ready_m15_count = 0;
   g_cov_ready_d1_count = 0;
   g_cov_fresh_m1_count = 0;
   g_cov_metrics_partial_count = 0;
   g_cov_publishable_count = 0;

   for(int i = 0; i < g_symbol_count; i++)
     {
      if(g_symbols[i].tf[TFIDX_M1].ready) g_cov_ready_m1_count++;
      if(g_symbols[i].tf[TFIDX_M5].ready) g_cov_ready_m5_count++;
      if(g_symbols[i].tf[TFIDX_M15].ready) g_cov_ready_m15_count++;
      if(g_symbols[i].tf[TFIDX_D1].ready) g_cov_ready_d1_count++;
      if(g_symbols[i].tf[TFIDX_M1].fresh) g_cov_fresh_m1_count++;
      if(g_symbols[i].metrics_partial) g_cov_metrics_partial_count++;
      if(g_symbols[i].publishable_metrics) g_cov_publishable_count++;
     }
  }

bool SymbolTfDue(const SymbolState &sym, const int tf_idx)
  {
   if(sym.tf[tf_idx].cooldown_until > g_schedule.now_server_time) return false;
   if(sym.tf[tf_idx].next_due_server <= 0) return true;
   return (sym.tf[tf_idx].next_due_server <= g_schedule.now_server_time);
  }

int PickDueTf(SymbolState &sym)
  {
   int order[TF_COUNT] = {TFIDX_M1, TFIDX_M5, TFIDX_M15, TFIDX_D1};
   for(int i = 0; i < TF_COUNT; i++)
     {
      int tf = order[i];
      if(SymbolTfDue(sym, tf))
         return tf;
     }
   return -1;
  }

void RunRatesHydrationBudget()
  {
   if(!g_have_upstream || g_symbol_count <= 0) return;
   int budget = MathMin(MAX_RATES_WORK_PER_CYCLE, MathMax(1, InpRatesBudgetPerCycle));
   int symbols_done = 0;
   int scanned = 0;

   while(scanned < g_symbol_count && symbols_done < budget)
     {
      int idx = g_schedule.cursor_hydrate_symbol++;
      if(g_schedule.cursor_hydrate_symbol >= g_symbol_count) g_schedule.cursor_hydrate_symbol = 0;
      scanned++;

      int tf = PickDueTf(g_symbols[idx]);
      if(tf < 0) continue;
      HydrateTimeframe(g_symbols[idx], tf);
      symbols_done++;
     }
  }


int FreshBits(const SymbolState &sym)
  {
   int bits = 0;
   for(int tf = 0; tf < TF_COUNT; tf++)
      if(sym.tf[tf].fresh) bits |= TfFreshBit(tf);
   return bits;
  }

string BuildCoverageJson()
  {
   string s = "{";
   s += "\"ready_m1_count\":" + IntegerToString(g_cov_ready_m1_count) + ",";
   s += "\"ready_m5_count\":" + IntegerToString(g_cov_ready_m5_count) + ",";
   s += "\"ready_m15_count\":" + IntegerToString(g_cov_ready_m15_count) + ",";
   s += "\"ready_d1_count\":" + IntegerToString(g_cov_ready_d1_count) + ",";
   s += "\"fresh_m1_count\":" + IntegerToString(g_cov_fresh_m1_count) + ",";
   s += "\"metrics_partial_count\":" + IntegerToString(g_cov_metrics_partial_count) + ",";
   s += "\"publishable_count\":" + IntegerToString(g_cov_publishable_count);
   s += "}";
   return s;
  }

string BuildStageSymbolJson(const SymbolState &sym)
  {
   string s = "{";
   s += "\"raw_symbol\":" + JsonString(sym.raw_symbol) + ",";
   s += "\"hydration\":{";
   s += "\"ready_m1\":" + JsonBool(sym.tf[TFIDX_M1].ready) + ",";
   s += "\"ready_m5\":" + JsonBool(sym.tf[TFIDX_M5].ready) + ",";
   s += "\"ready_m15\":" + JsonBool(sym.tf[TFIDX_M15].ready) + ",";
   s += "\"ready_d1\":" + JsonBool(sym.tf[TFIDX_D1].ready) + ",";
   s += "\"bars_m1\":" + IntegerToString(sym.tf[TFIDX_M1].bars_loaded) + ",";
   s += "\"bars_m5\":" + IntegerToString(sym.tf[TFIDX_M5].bars_loaded) + ",";
   s += "\"bars_m15\":" + IntegerToString(sym.tf[TFIDX_M15].bars_loaded) + ",";
   s += "\"bars_d1\":" + IntegerToString(sym.tf[TFIDX_D1].bars_loaded) + ",";
   s += "\"last_bar_m1\":" + JsonDateTimeOrNull(sym.tf[TFIDX_M1].last_bar_time) + ",";
   s += "\"last_bar_m5\":" + JsonDateTimeOrNull(sym.tf[TFIDX_M5].last_bar_time) + ",";
   s += "\"last_bar_m15\":" + JsonDateTimeOrNull(sym.tf[TFIDX_M15].last_bar_time) + ",";
   s += "\"last_bar_d1\":" + JsonDateTimeOrNull(sym.tf[TFIDX_D1].last_bar_time) + ",";
   s += "\"fresh_bits\":" + IntegerToString(FreshBits(sym));
   s += "},";
   s += "\"metrics\":{";
   s += "\"atr_m1\":" + JsonDoubleOrNull6(sym.atr_m1) + ",";
   s += "\"atr_m5\":" + JsonDoubleOrNull6(sym.atr_m5) + ",";
   s += "\"atr_m15\":" + JsonDoubleOrNull6(sym.atr_m15) + ",";
   s += "\"atr_points_m1\":" + JsonDoubleOrNull6(sym.atr_points_m1) + ",";
   s += "\"atr_points_m5\":" + JsonDoubleOrNull6(sym.atr_points_m5) + ",";
   s += "\"atr_points_m15\":" + JsonDoubleOrNull6(sym.atr_points_m15) + ",";
   s += "\"volatility_accel\":" + JsonDoubleOrNull6(sym.volatility_accel) + ",";
   s += "\"vol_expansion\":" + JsonDoubleOrNull6(sym.vol_expansion) + ",";
   s += "\"spread_to_atr_m1_ratio\":" + JsonDoubleOrNull6(sym.spread_to_atr_m1_ratio) + ",";
   s += "\"spread_to_atr_m5_ratio\":" + JsonDoubleOrNull6(sym.spread_to_atr_m5_ratio);
   s += "}";
   s += "}";
   return s;
  }

string BuildStageJson()
  {
   string symbols = "[";
   for(int i = 0; i < g_symbol_count; i++)
     {
      if(i > 0) symbols += ",";
      symbols += BuildStageSymbolJson(g_symbols[i]);
     }
   symbols += "]";

   string out = "{";
   out += "\"producer\":\"EA2\",";
   out += "\"stage\":\"history_metrics\",";
   out += "\"minute_id\":" + LongToStringSafe(g_publish_stage.minute_id) + ",";
   out += "\"universe_fingerprint\":" + JsonString(g_upstream_fingerprint) + ",";
   out += "\"coverage\":" + BuildCoverageJson() + ",";
   out += "\"symbols\":" + symbols;
   out += "}";
   return out;
  }

int ScoreWorstSymbol(const SymbolState &sym)
  {
   int score = 0;
   if(!sym.tf[TFIDX_M1].ready) score += 20;
   if(!sym.tf[TFIDX_M5].ready) score += 15;
   if(!sym.tf[TFIDX_M15].ready) score += 15;
   if(sym.market_open_now_from_ea1 && !sym.tf[TFIDX_M1].fresh) score += 20;
   if(sym.market_open_now_from_ea1 && !sym.spread_current_enough_for_ratios) score += 10;
   score += sym.tf[TFIDX_M1].fail_count * 4;
   score += sym.tf[TFIDX_M5].fail_count * 3;
   score += sym.tf[TFIDX_M15].fail_count * 3;
   score += sym.tf[TFIDX_D1].fail_count * 1;
   if(!sym.publishable_metrics) score += 20;
   return score;
  }

void BuildWorstLists(int &idxs[], int &scores[])
  {
   ArrayResize(idxs, 0);
   ArrayResize(scores, 0);
   for(int i = 0; i < g_symbol_count; i++)
     {
      int sc = ScoreWorstSymbol(g_symbols[i]);
      if(sc <= 0) continue;
      int n = ArraySize(idxs);
      ArrayResize(idxs, n + 1);
      ArrayResize(scores, n + 1);
      idxs[n] = i;
      scores[n] = sc;
     }

   int n2 = ArraySize(scores);
   for(int a = 1; a < n2; a++)
     {
      int ks = scores[a];
      int ki = idxs[a];
      int b = a - 1;
      while(b >= 0 && scores[b] < ks)
        {
         scores[b + 1] = scores[b];
         idxs[b + 1] = idxs[b];
         b--;
        }
      scores[b + 1] = ks;
      idxs[b + 1] = ki;
     }
  }

string BuildRecentEventsJson()
  {
   string s = "[";
   int start = g_event_head - g_event_count;
   while(start < 0) start += EVENT_RING_CAPACITY;
   for(int i = 0; i < g_event_count; i++)
     {
      int idx = (start + i) % EVENT_RING_CAPACITY;
      if(i > 0) s += ",";
      s += "{";
      s += "\"when\":" + JsonDateTimeOrNull(g_events[idx].when_server) + ",";
      s += "\"code\":" + JsonString(g_events[idx].code) + ",";
      s += "\"detail\":" + JsonString(g_events[idx].detail);
      s += "}";
     }
   s += "]";
   return s;
  }

string BuildWorstSymbolsJson()
  {
   int idxs[];
   int scores[];
   BuildWorstLists(idxs, scores);

   string s = "[";
   int rows = MathMin(ArraySize(idxs), WORST_SYMBOL_CAP);
   for(int i = 0; i < rows; i++)
     {
      if(i > 0) s += ",";
      int idx = idxs[i];
      SymbolState sym = g_symbols[idx];
      s += "{";
      s += "\"raw_symbol\":" + JsonString(sym.raw_symbol) + ",";
      s += "\"score\":" + IntegerToString(scores[i]) + ",";
      s += "\"upstream_reason_code\":" + JsonString(sym.upstream_reason_code) + ",";
      s += "\"data_reason_code\":" + JsonString(sym.data_reason_code) + ",";
      s += "\"publish_reason_code\":" + JsonString(sym.publish_reason_code) + ",";
      s += "\"m1_fail_count\":" + IntegerToString(sym.tf[TFIDX_M1].fail_count) + ",";
      s += "\"m5_fail_count\":" + IntegerToString(sym.tf[TFIDX_M5].fail_count) + ",";
      s += "\"m15_fail_count\":" + IntegerToString(sym.tf[TFIDX_M15].fail_count) + ",";
      s += "\"d1_fail_count\":" + IntegerToString(sym.tf[TFIDX_D1].fail_count) + ",";
      s += "\"missing_point\":" + JsonBool(!IsKnownNumber(sym.point_from_ea1) || sym.point_from_ea1 <= 0.0) + ",";
      s += "\"missing_spread\":" + JsonBool(!IsKnownNumber(sym.spread_points_from_ea1)) + ",";
      s += "\"stale_spread\":" + JsonBool(IsKnownNumber(sym.spread_points_from_ea1) && !sym.spread_current_enough_for_ratios) + ",";
      s += "\"stale_m1\":" + JsonBool(sym.tf[TFIDX_M1].stale) + ",";
      s += "\"stale_m5\":" + JsonBool(sym.tf[TFIDX_M5].stale) + ",";
      s += "\"stale_m15\":" + JsonBool(sym.tf[TFIDX_M15].stale) + ",";
      s += "\"cooldown_active\":" + JsonBool(sym.tf[TFIDX_M1].cooldown_until > g_schedule.now_server_time || sym.tf[TFIDX_M5].cooldown_until > g_schedule.now_server_time || sym.tf[TFIDX_M15].cooldown_until > g_schedule.now_server_time || sym.tf[TFIDX_D1].cooldown_until > g_schedule.now_server_time) + ",";
      s += "\"resumed_from_persistence\":" + JsonBool(sym.resumed_from_persistence);
      s += "}";
     }
   s += "]";
   return s;
  }

string BuildDiagnosticSamplesJson()
  {
   string s = "[";
   int rows = MathMin(g_symbol_count, DIAG_SAMPLE_CAP);
   for(int i = 0; i < rows; i++)
     {
      if(i > 0) s += ",";
      SymbolState sym = g_symbols[i];
      s += "{";
      s += "\"raw_symbol\":" + JsonString(sym.raw_symbol) + ",";
      s += "\"upstream_reason_code\":" + JsonString(sym.upstream_reason_code) + ",";
      s += "\"data_reason_code\":" + JsonString(sym.data_reason_code) + ",";
      s += "\"publish_reason_code\":" + JsonString(sym.publish_reason_code) + ",";
      s += "\"m1_fail_count\":" + IntegerToString(sym.tf[TFIDX_M1].fail_count) + ",";
      s += "\"m5_fail_count\":" + IntegerToString(sym.tf[TFIDX_M5].fail_count) + ",";
      s += "\"m15_fail_count\":" + IntegerToString(sym.tf[TFIDX_M15].fail_count) + ",";
      s += "\"d1_fail_count\":" + IntegerToString(sym.tf[TFIDX_D1].fail_count) + ",";
      s += "\"missing_point\":" + JsonBool(!IsKnownNumber(sym.point_from_ea1) || sym.point_from_ea1 <= 0.0) + ",";
      s += "\"missing_spread\":" + JsonBool(!IsKnownNumber(sym.spread_points_from_ea1)) + ",";
      s += "\"stale_spread\":" + JsonBool(IsKnownNumber(sym.spread_points_from_ea1) && !sym.spread_current_enough_for_ratios) + ",";
      s += "\"stale_m1\":" + JsonBool(sym.tf[TFIDX_M1].stale) + ",";
      s += "\"stale_m5\":" + JsonBool(sym.tf[TFIDX_M5].stale) + ",";
      s += "\"stale_m15\":" + JsonBool(sym.tf[TFIDX_M15].stale) + ",";
      s += "\"cooldown_active\":" + JsonBool(sym.tf[TFIDX_M1].cooldown_until > g_schedule.now_server_time || sym.tf[TFIDX_M5].cooldown_until > g_schedule.now_server_time || sym.tf[TFIDX_M15].cooldown_until > g_schedule.now_server_time || sym.tf[TFIDX_D1].cooldown_until > g_schedule.now_server_time) + ",";
      s += "\"resumed_from_persistence\":" + JsonBool(sym.resumed_from_persistence);
      s += "}";
     }
   s += "]";
   return s;
  }

string BuildDebugJson()
  {
   string s = "{";
   s += "\"producer\":\"EA2\",";
   s += "\"stage\":\"debug\",";
   s += "\"minute_id\":" + LongToStringSafe(g_publish_debug.minute_id) + ",";
   s += "\"timing\":{";
   s += "\"timer_tick_count\":" + LongToStringSafe(g_schedule.timer_tick_count) + ",";
   s += "\"slip_count\":" + LongToStringSafe(g_schedule.timer_overrun_count) + ",";
   s += "\"last_timer_sec\":" + JsonDateTimeOrNull(g_schedule.last_timer_server_time) + ",";
   s += "\"last_cycle_ms\":" + IntegerToString(g_schedule.last_cycle_ms);
   s += "},";
   s += "\"schedules\":{";
   s += "\"cursor_hydrate_symbol\":" + IntegerToString(g_schedule.cursor_hydrate_symbol) + ",";
   s += "\"cursor_metrics\":" + IntegerToString(g_schedule.cursor_metrics) + ",";
   s += "\"cursor_persist_save\":" + IntegerToString(g_schedule.cursor_persist_save) + ",";
   s += "\"read_attempts_this_minute\":" + IntegerToString(g_upstream_diag.read_attempts_this_minute);
   s += "},";
   s += "\"paths\":{";
   s += "\"firm_id\":" + JsonString(g_firm_id) + ",";
   s += "\"ea1_current\":" + JsonString(g_ea1_stage_file) + ",";
   s += "\"ea1_previous\":" + JsonString(g_ea1_stage_prev_file) + ",";
   s += "\"stage_current\":" + JsonString(g_stage_file) + ",";
   s += "\"stage_prev\":" + JsonString(g_stage_prev_file) + ",";
   s += "\"stage_backup\":" + JsonString(g_stage_backup_file) + ",";
   s += "\"debug_current\":" + JsonString(g_debug_file) + ",";
   s += "\"debug_prev\":" + JsonString(g_debug_prev_file) + ",";
   s += "\"debug_backup\":" + JsonString(g_debug_backup_file) + ",";
   s += "\"tmp_dir\":" + JsonString(g_tmp_dir_ea2) + ",";
   s += "\"locks_dir\":" + JsonString(g_locks_dir) + ",";
   s += "\"persistence_dir\":" + JsonString(g_persistence_dir_ea2);
   s += "},";
   s += "\"upstream\":{";
   s += "\"current_exists\":" + JsonBool(g_upstream_diag.current_exists) + ",";
   s += "\"previous_exists\":" + JsonBool(g_upstream_diag.previous_exists) + ",";
   s += "\"current_valid\":" + JsonBool(g_upstream_diag.current_valid) + ",";
   s += "\"previous_valid\":" + JsonBool(g_upstream_diag.previous_valid) + ",";
   s += "\"last_good_applied\":" + JsonBool(g_upstream_diag.last_good_applied) + ",";
   s += "\"source_used\":" + JsonString(g_upstream_source == UPSRC_CURRENT ? "current" : g_upstream_source == UPSRC_PREVIOUS ? "previous" : g_upstream_source == UPSRC_LAST_GOOD ? "last_good" : "none") + ",";
   s += "\"upstream_minute_id\":" + LongToStringSafe(g_upstream_minute_id) + ",";
   s += "\"upstream_age\":" + IntegerToString(g_have_upstream ? (int)(GetMinuteId(g_schedule.now_server_time) - g_upstream_minute_id) : -1) + ",";
   s += "\"upstream_fingerprint\":" + JsonString(g_upstream_fingerprint) + ",";
   s += "\"current_error\":" + JsonString(g_upstream_diag.current_error) + ",";
   s += "\"previous_error\":" + JsonString(g_upstream_diag.previous_error);
   s += "},";
   s += "\"io_last\":{";
   s += "\"last_file\":" + JsonString(g_io_last.last_file) + ",";
   s += "\"last_op\":" + IntegerToString(g_io_last.last_op) + ",";
   s += "\"open_err\":" + IntegerToString(g_io_last.open_err) + ",";
   s += "\"write_err\":" + IntegerToString(g_io_last.write_err) + ",";
   s += "\"move_err\":" + IntegerToString(g_io_last.move_err) + ",";
   s += "\"copy_err\":" + IntegerToString(g_io_last.copy_err) + ",";
   s += "\"delete_err\":" + IntegerToString(g_io_last.delete_err) + ",";
   s += "\"bytes\":" + IntegerToString(g_io_last.bytes) + ",";
   s += "\"guard_ok\":" + JsonBool(g_io_last.guard_ok);
   s += "},";
   s += "\"io_counters\":{";
   s += "\"io_ok_count\":" + LongToStringSafe(g_io_counters.io_ok_count) + ",";
   s += "\"io_fail_count\":" + LongToStringSafe(g_io_counters.io_fail_count);
   s += "},";
   s += "\"perf\":{";
   s += "\"dur_step_total_ms\":" + IntegerToString(g_perf.dur_step_total_ms) + ",";
   s += "\"dur_upstream_read_ms\":" + IntegerToString(g_perf.dur_upstream_read_ms) + ",";
   s += "\"dur_upstream_validate_ms\":" + IntegerToString(g_perf.dur_upstream_validate_ms) + ",";
   s += "\"dur_upstream_parse_ms\":" + IntegerToString(g_perf.dur_upstream_parse_ms) + ",";
   s += "\"dur_hydrate_ms\":" + IntegerToString(g_perf.dur_hydrate_ms) + ",";
   s += "\"dur_metric_compute_ms\":" + IntegerToString(g_perf.dur_metric_compute_ms) + ",";
   s += "\"dur_build_stage_ms\":" + IntegerToString(g_perf.dur_build_stage_ms) + ",";
   s += "\"dur_build_debug_ms\":" + IntegerToString(g_perf.dur_build_debug_ms) + ",";
   s += "\"dur_write_tmp_ms\":" + IntegerToString(g_perf.dur_write_tmp_ms) + ",";
   s += "\"dur_commit_ms\":" + IntegerToString(g_perf.dur_commit_ms) + ",";
   s += "\"dur_backup_ms\":" + IntegerToString(g_perf.dur_backup_ms) + ",";
   s += "\"dur_persist_load_ms\":" + IntegerToString(g_perf.dur_persist_load_ms) + ",";
   s += "\"dur_persist_save_ms\":" + IntegerToString(g_perf.dur_persist_save_ms) + ",";
   s += "\"perf_warn\":" + JsonBool(g_perf.perf_warn);
   s += "},";
   s += "\"publish\":{";
   s += "\"stage_attempted\":" + JsonBool(g_publish_stage.attempted) + ",";
   s += "\"stage_ok\":" + JsonBool(g_publish_stage.ok) + ",";
   s += "\"stage_last_error\":" + JsonString(g_publish_stage.last_error) + ",";
   s += "\"debug_attempted\":" + JsonBool(g_publish_debug.attempted) + ",";
   s += "\"debug_ok\":" + JsonBool(g_publish_debug.ok) + ",";
   s += "\"debug_last_error\":" + JsonString(g_publish_debug.last_error);
   s += "},";
   s += "\"coverage\":" + BuildCoverageJson() + ",";
   s += "\"continuity\":{";
   s += "\"persist_load_ok_count\":" + LongToStringSafe(g_cnt_persist_load_ok) + ",";
   s += "\"persist_load_fail_count\":" + LongToStringSafe(g_cnt_persist_load_fail) + ",";
   s += "\"persist_save_ok_count\":" + LongToStringSafe(g_cnt_persist_save_ok) + ",";
   s += "\"persist_save_fail_count\":" + LongToStringSafe(g_cnt_persist_save_fail) + ",";
   s += "\"persist_stale_discard_count\":" + LongToStringSafe(g_cnt_persist_stale_discard) + ",";
   s += "\"persist_corrupt_discard_count\":" + LongToStringSafe(g_cnt_persist_corrupt_discard) + ",";
   s += "\"persist_incompat_discard_count\":" + LongToStringSafe(g_cnt_persist_incompat_discard);
   s += "},";
   s += "\"recent_events\":" + BuildRecentEventsJson() + ",";
   s += "\"engine_counts\":{";
   s += "\"upstream_reads\":" + LongToStringSafe(g_cnt_upstream_reads) + ",";
   s += "\"upstream_accepts\":" + LongToStringSafe(g_cnt_upstream_accepts) + ",";
   s += "\"upstream_rejects\":" + LongToStringSafe(g_cnt_upstream_rejects) + ",";
   s += "\"hydrate_calls\":" + LongToStringSafe(g_cnt_hydrate_calls) + ",";
   s += "\"hydrate_success\":" + LongToStringSafe(g_cnt_hydrate_success) + ",";
   s += "\"hydrate_fail\":" + LongToStringSafe(g_cnt_hydrate_fail) + ",";
   s += "\"metrics_compute\":" + LongToStringSafe(g_cnt_metrics_compute);
   s += "},";
   s += "\"failure_counts\":{";
   s += "\"stage_publish_fail\":" + LongToStringSafe(g_cnt_stage_publish_fail) + ",";
   s += "\"debug_publish_fail\":" + LongToStringSafe(g_cnt_debug_publish_fail);
   s += "},";
   s += "\"success_counts\":{";
   s += "\"stage_publish_ok\":" + LongToStringSafe(g_cnt_stage_publish_ok) + ",";
   s += "\"debug_publish_ok\":" + LongToStringSafe(g_cnt_debug_publish_ok);
   s += "},";
   s += "\"subsystem_status\":{";
   s += "\"upstream_present\":" + JsonBool(g_have_upstream) + ",";
   s += "\"symbol_count\":" + IntegerToString(g_symbol_count) + ",";
   s += "\"publishable_count\":" + IntegerToString(g_cov_publishable_count);
   s += "},";
   s += "\"scheduler_pressure\":{";
   s += "\"rates_budget\":" + IntegerToString(MathMin(MAX_RATES_WORK_PER_CYCLE, MathMax(1, InpRatesBudgetPerCycle))) + ",";
   s += "\"metrics_budget\":" + IntegerToString(MathMax(1, InpMetricsBudgetPerCycle));
   s += "},";
   s += "\"persistence_diagnostics\":{\"enabled\":" + JsonBool(InpPersistenceEnabled) + "},";
   s += "\"publish_diagnostics\":{\"publish_lock\":" + JsonBool(PublishLockExists()) + "},";
   s += "\"stage_guard_diagnostics\":{\"guard_ok\":" + JsonBool(g_io_last.guard_ok) + "},";
   s += "\"temp_cleanup_diagnostics\":{\"last_run\":" + JsonDateTimeOrNull(g_last_temp_cleanup) + "},";
   s += "\"diagnostic_samples\":" + BuildDiagnosticSamplesJson() + ",";
   s += "\"legends\":{\"fresh_bits\":\"1=M1,2=M5,4=M15,8=D1\"}";
   s += "}";
   return s;
  }
int ScoreBestSymbol(const SymbolState &sym)
  {
   int score = 0;

   if(sym.ea1_valid) score += 10;
   score += sym.operational_health_score;

   if(sym.metrics_min_ready) score += 20;
   else if(sym.publishable_metrics) score += 8;

   if(sym.intraday_metrics_fresh) score += 20;

   if(sym.tf[TFIDX_M1].fresh) score += 8;
   if(sym.tf[TFIDX_M5].fresh) score += 6;
   if(sym.tf[TFIDX_M15].fresh) score += 6;
   if(sym.tf[TFIDX_D1].fresh) score += 2;

   if(sym.spread_ratios_ready) score += 8;
   if(sym.volatility_ready) score += 8;

   if(sym.market_open_now_from_ea1 && sym.spread_current_enough_for_ratios) score += 6;

   score -= sym.tf[TFIDX_M1].fail_count * 4;
   score -= sym.tf[TFIDX_M5].fail_count * 3;
   score -= sym.tf[TFIDX_M15].fail_count * 3;
   score -= sym.tf[TFIDX_D1].fail_count * 1;

   return score;
  }

void BuildBestLists(int &idxs[], int &scores[])
  {
   ArrayResize(idxs, 0);
   ArrayResize(scores, 0);

   for(int i = 0; i < g_symbol_count; i++)
     {
      int sc = ScoreBestSymbol(g_symbols[i]);
      int n = ArraySize(idxs);
      ArrayResize(idxs, n + 1);
      ArrayResize(scores, n + 1);
      idxs[n] = i;
      scores[n] = sc;
     }

   int n2 = ArraySize(scores);
   for(int a = 1; a < n2; a++)
     {
      int ks = scores[a];
      int ki = idxs[a];
      int b = a - 1;
      while(b >= 0 && scores[b] < ks)
        {
         scores[b + 1] = scores[b];
         idxs[b + 1] = idxs[b];
         b--;
        }
      scores[b + 1] = ks;
      idxs[b + 1] = ki;
     }
  }

string BuildBestSymbolsText()
  {
   int idxs[];
   int scores[];
   BuildBestLists(idxs, scores);

   int rows = MathMin(ArraySize(idxs), MathMax(1, InpHudTopRows));
   if(rows <= 0) return "None\n";

   string out = "";
   for(int i = 0; i < rows; i++)
     {
      int idx = idxs[i];
      SymbolState sym = g_symbols[idx];

      out += sym.raw_symbol;
      out += " | H=" + IntegerToString(sym.operational_health_score);
      out += " | " + sym.summary_state;
      out += " | F=" + IntegerToString(FreshBits(sym));
      out += " | " + sym.data_reason_code;
      out += "\n";
     }
   return out;
  }

string UpstreamSourceLabel()
  {
   if(g_upstream_source == UPSRC_CURRENT) return "current";
   if(g_upstream_source == UPSRC_PREVIOUS) return "previous";
   if(g_upstream_source == UPSRC_LAST_GOOD) return "last_good";
   return "none";
  }

void RenderHUD()
  {
   string text = "";
   text += EA_NAME + " " + EA_BUILD_CHANNEL + "\n";
   text += "Server: " + TimeToString(g_schedule.now_server_time, TIME_DATE | TIME_MINUTES) + "\n";
   text += "Firm: " + g_firm_id + "\n";
   text += "Universe: " + IntegerToString(g_symbol_count) + "\n";
   text += "Upstream: " + UpstreamSourceLabel();
   text += " | AgeMin=" + IntegerToString(g_have_upstream ? (int)(GetMinuteId(g_schedule.now_server_time) - g_upstream_minute_id) : -1) + "\n";

   text += "Ready M1/M5/M15/D1: ";
   text += IntegerToString(g_cov_ready_m1_count) + "/";
   text += IntegerToString(g_cov_ready_m5_count) + "/";
   text += IntegerToString(g_cov_ready_m15_count) + "/";
   text += IntegerToString(g_cov_ready_d1_count) + "\n";

   text += "Fresh M1: " + IntegerToString(g_cov_fresh_m1_count) + "\n";
   text += "Publishable: " + IntegerToString(g_cov_publishable_count) + "\n";
   text += "Partial: " + IntegerToString(g_cov_metrics_partial_count) + "\n";

   text += "UpReads/Accept/Reject: ";
   text += LongToStringSafe(g_cnt_upstream_reads) + "/";
   text += LongToStringSafe(g_cnt_upstream_accepts) + "/";
   text += LongToStringSafe(g_cnt_upstream_rejects) + "\n";

   text += "Hydrate OK/Fail: ";
   text += LongToStringSafe(g_cnt_hydrate_success) + "/";
   text += LongToStringSafe(g_cnt_hydrate_fail) + "\n";

   text += "Persist L/S OK: ";
   text += LongToStringSafe(g_cnt_persist_load_ok) + "/";
   text += LongToStringSafe(g_cnt_persist_save_ok) + "\n";

   text += "CycleMs: " + IntegerToString(g_schedule.last_cycle_ms);
   text += " | Warn=" + (g_perf.perf_warn ? "1" : "0") + "\n";

   text += "Stage: " + (g_publish_stage.ok ? "1" : "0");
   text += " | Debug: " + (g_publish_debug.ok ? "1" : "0") + "\n";

   text += "Top Healthy:\n";
   text += BuildBestSymbolsText();

   Comment(text);
  }
  
  int OnInit()
  {
   ResetGlobalState();
   InitFirmFiles();
   UpdateScheduleClock();
   AddEvent("clean_restart_started", g_firm_id);

   if(!EventSetTimer(1))
      return INIT_FAILED;

   if(InpShowHUD)
      Comment(EA_NAME, " ", EA_BUILD_CHANNEL, "\nInitializing...");

   return INIT_SUCCEEDED;
  }
   
void MaybePublishStage()
  {
   if(!g_have_upstream || g_symbol_count <= 0 || g_schedule.now_server_time <= 0) return;

   long minute_id = GetMinuteId(g_schedule.now_server_time);
   if(minute_id < 0) return;
   if(!IsPublishWindowOpen(g_schedule.now_server_time, InpStagePublishOffsetSec, InpStagePublishWindowSec)) return;
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
      g_cnt_stage_publish_fail++;
      return;
     }

   ulong t0 = GetMicrosecondCount() / 1000;
   string json = BuildStageJson();
   g_perf.dur_build_stage_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   string tmp_rel = BuildTempFileName(g_tmp_dir_ea2, g_firm_id + "_history_metrics.json", minute_id, g_publish_stage.write_seq);
   int bytes_written = 0;

   t0 = GetMicrosecondCount() / 1000;
   bool write_ok = WriteTextFileCommon(tmp_rel, json, bytes_written);
   g_perf.dur_write_tmp_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   if(!write_ok)
     {
      g_publish_stage.last_error = "write_tmp_failed";
      g_cnt_stage_publish_fail++;
      return;
     }

   g_io_last.guard_ok = MinimalJsonGuard(json);
   BestEffortPreservePrevious(g_stage_file, g_stage_prev_file);

   t0 = GetMicrosecondCount() / 1000;
   bool commit_ok = CommitFileAtomic(tmp_rel, g_stage_file);
   g_perf.dur_commit_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   if(!commit_ok)
     {
      g_publish_stage.last_error = "commit_failed";
      g_cnt_stage_publish_fail++;
      return;
     }

   t0 = GetMicrosecondCount() / 1000;
   BestEffortBackup(g_stage_file, g_stage_backup_file);
   g_perf.dur_backup_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   g_publish_stage.ok = true;
   g_publish_stage.last_published_minute_id = minute_id;
   g_publish_stage.last_error = "";
   g_cnt_stage_publish_ok++;
   AddEvent("publish_stage_ok", g_stage_file);
  }

void MaybePublishDebug()
  {
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

   ulong t0 = GetMicrosecondCount() / 1000;
   string json = BuildDebugJson();
   g_perf.dur_build_debug_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   string tmp_rel = BuildTempFileName(g_tmp_dir_ea2, g_firm_id + "_debug_ea2.json", minute_id, g_publish_debug.write_seq);
   int bytes_written = 0;
   if(!WriteTextFileCommon(tmp_rel, json, bytes_written))
     {
      g_publish_debug.last_error = "write_tmp_failed";
      g_cnt_debug_publish_fail++;
      return;
     }

   BestEffortPreservePrevious(g_debug_file, g_debug_prev_file);
   if(!CommitFileAtomic(tmp_rel, g_debug_file))
     {
      g_publish_debug.last_error = "commit_failed";
      g_cnt_debug_publish_fail++;
      return;
     }

   BestEffortBackup(g_debug_file, g_debug_backup_file);
   g_publish_debug.ok = true;
   g_publish_debug.last_published_minute_id = minute_id;
   g_schedule.last_debug_write_time = g_schedule.now_server_time;
   g_cnt_debug_publish_ok++;
   AddEvent("publish_debug_ok", g_debug_file);
  }

void MaybeCleanupTemp()
  {
   if(!InpEnableTempCleanup || g_schedule.now_server_time <= 0) return;
   if(g_last_temp_cleanup > 0 && (g_schedule.now_server_time - g_last_temp_cleanup) < InpTempCleanupEverySec) return;

   g_last_temp_cleanup = g_schedule.now_server_time;

   string patterns[2];
   patterns[0] = g_tmp_dir_ea2 + g_firm_id + "_history_metrics.json*.tmp";
   patterns[1] = g_tmp_dir_ea2 + g_firm_id + "_debug_ea2.json*.tmp";

   for(int p = 0; p < 2; p++)
     {
      string found_name = "";
      long fh = FileFindFirst(patterns[p], found_name, FILE_COMMON);
      if(fh == INVALID_HANDLE) continue;

      do
        {
         if(found_name == "") continue;
         string full_path = g_tmp_dir_ea2 + found_name;
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

void RunPersistenceSaveBudget()
  {
   if(!InpPersistenceEnabled || g_symbol_count <= 0 || g_schedule.now_server_time <= 0) return;

   long minute_id = GetMinuteId(g_schedule.now_server_time);
   if(g_persist_writes_minute_id != minute_id)
     {
      g_persist_writes_minute_id = minute_id;
      g_persist_writes_this_min = 0;
     }

   int work = MathMin(g_symbol_count, MathMax(1, InpPersistenceSaveBudget));
   int done = 0;
   int scanned = 0;

   while(scanned < g_symbol_count && done < work)
     {
      if(g_persist_writes_this_min >= InpPersistenceMaxWritesPerMin) return;

      int idx = g_schedule.cursor_persist_save++;
      if(g_schedule.cursor_persist_save >= g_symbol_count) g_schedule.cursor_persist_save = 0;
      scanned++;


      if(!g_symbols[idx].persistence_dirty) continue;
      long since_last = (g_symbols[idx].last_persistence_save_time > 0 ? (long)(g_schedule.now_server_time - g_symbols[idx].last_persistence_save_time) : 999999);
      if(since_last < InpPersistenceMinSaveGapSec) continue;
      if(since_last < InpPersistenceSaveEverySec && g_symbols[idx].last_saved_payload_hash == BuildPersistencePayloadHash(g_symbols[idx])) continue;

      SaveSymbolPersistence(g_symbols[idx]);
      g_persist_writes_this_min++;
      done++;
     }
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   UpdateScheduleClock();

   if(InpPersistenceEnabled)
     {
      ulong t0 = GetMicrosecondCount() / 1000;
      for(int i = 0; i < g_symbol_count; i++)
        {
         if(g_symbols[i].tf[TFIDX_M1].bars_loaded > 0 ||
            g_symbols[i].tf[TFIDX_M5].bars_loaded > 0 ||
            g_symbols[i].tf[TFIDX_M15].bars_loaded > 0 ||
            g_symbols[i].tf[TFIDX_D1].bars_loaded > 0)
            SaveSymbolPersistence(g_symbols[i]);
        }
      g_perf.dur_persist_save_ms = (int)((GetMicrosecondCount() / 1000) - t0);
     }

   if(InpShowHUD) Comment("");
  }

void OnTick()
  {
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
   ResetPerfState();

   RunUpstreamRead();

   ulong t0 = GetMicrosecondCount() / 1000;
   RunRatesHydrationBudget();
   g_perf.dur_hydrate_ms = (int)((GetMicrosecondCount() / 1000) - t0);

   t0 = GetMicrosecondCount() / 1000;
   RunMetricsComputeBudget();
   g_perf.dur_metric_compute_ms = (int)((GetMicrosecondCount() / 1000) - t0);

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

t0 = GetMicrosecondCount() / 1000;
RunPersistenceSaveBudget();
g_perf.dur_persist_save_ms = (int)((GetMicrosecondCount() / 1000) - t0);

MaybePublishStage();
MaybePublishDebug();
MaybeCleanupTemp();

   g_schedule.last_cycle_ms = (int)(GetTickCount() - cycle_start);
   g_schedule.timer_tick_count++;
   g_perf.dur_step_total_ms = g_schedule.last_cycle_ms;
   g_perf.perf_warn = (g_schedule.last_cycle_ms >= InpPerfWarnMs);
   g_schedule.timer_busy = false;
  }
