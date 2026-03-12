
#property strict
#property version   "1.000"
#property description "EA3 bounded intelligence core for locked EA1 and authoritative EA2"

#define EA3_NAME                         "EA3"
#define EA3_STAGE                        "intelligence"
#define EA3_DEBUG_STAGE                  "debug"
#define EA3_ENGINE_VERSION               "1.0"
#define EA3_PERSIST_SCHEMA_VERSION       1

#define MAX_SYMBOLS_HARD                 5000
#define PERSIST_RING_CAP                 20
#define MAX_EVENTS                       50
#define MAX_WORST_SYMBOLS                20
#define MAX_CANDIDATE_SAMPLES            10
#define MAX_DIAGNOSTIC_SAMPLES           10
#define MAX_CORR_DIAG                    10
#define MAX_LEADER_ROWS                  512
#define MAX_PAIR_ROWS                    64
#define MAX_BASKET_ROWS                  16
#define MAX_SECTORS_TRACKED              256

#define SRC_NONE                         0
#define SRC_CURRENT                      1
#define SRC_PREVIOUS                     2
#define SRC_LAST_GOOD                    3

#define ENGINE_INIT                      0
#define ENGINE_UPSTREAM_WAIT             1
#define ENGINE_WARMUP                    2
#define ENGINE_STEADY                    3
#define ENGINE_DEGRADED                  4

#define INTEGRITY_UPSTREAM_MISSING       0
#define INTEGRITY_EA1_ONLY               1
#define INTEGRITY_EA1_STALE              2
#define INTEGRITY_EA2_STALE              3
#define INTEGRITY_FINGERPRINT_MISMATCH   4
#define INTEGRITY_FULL                   5

#define HORIZON_NONE                     0
#define HORIZON_SCALP                    1
#define HORIZON_INTRADAY                 2
#define HORIZON_SWING                    3

#define PSTATUS_NONE                     0
#define PSTATUS_BLOCKED                  1
#define PSTATUS_WATCH                    2
#define PSTATUS_QUALIFIED                3
#define PSTATUS_STRONG                   4

input string InpFirmId = "";
input bool   InpAllowClosedMarkets = false;
input bool   InpShowHUD = true;
input int    InpHudRefreshSec = 5;
input int    InpHudTopRows = 8;
input int    InpMaxLeadersPerSector = 5;
input int    InpMaxUsableUpstreamAgeMin = 10;
input int    InpSymbolComputeBudget = 200;
input int    InpCandidatePoolBuildBudget = 200;
input int    InpCorrelationPairBudget = 200;
input int    InpPersistenceLoadBudget = 50;
input int    InpPersistenceSaveBudget = 20;
input int    InpCandidatePoolCap = 24;
input int    InpCorrelationPairsCap = 20;
input double InpHardSimilarityThreshold = 0.90;
input double InpSoftSimilarityThreshold = 0.85;
input int    InpMaxBasketSize = 8;
input int    InpBasketCoolingCycles = 2;
input int    InpPersistenceSaveCadenceSec = 300;
input int    InpContinuityFreshnessMaxAgeSec = 7200;
input int    InpTempCleanupCadenceSec = 3600;
input int    InpTempCleanupAgeSec = 900;
input int    InpReadWindowStartSec = 20;
input int    InpReadWindowEndSec = 24;
input int    InpPublishOffsetSec = 26;
input int    InpPublishWindowSec = 20;
input int    InpDebugCadenceSec = 10;
input double InpMeaningfulAtrFloor = 0.5;
input double InpExpansionAfterCompressionBoost = 5.0;

struct EA1SymbolRec
{
   string raw_symbol;
   string asset_class;
   string class_key;
   bool   market_open_now;
   int    reason_code;
   bool   has_sector_id;
   int    sector_id;
};

struct EA2SymbolRec
{
   string raw_symbol;
   bool   ready_m1;
   bool   ready_m5;
   bool   ready_m15;
   bool   ready_d1;
   int    fresh_bits;
   double atr_points_m1;
   double atr_points_m5;
   double atr_points_m15;
   double volatility_accel;
   double vol_expansion;
   double spread_to_atr_m1_ratio;
   double spread_to_atr_m5_ratio;
};

struct UpstreamEA1Snapshot
{
   bool   valid;
   int    source_used;
   long   minute_id;
   string fingerprint;
   bool   current_valid;
   bool   prev_valid;
   bool   last_good_applied;
   EA1SymbolRec symbols[];
};

struct UpstreamEA2Snapshot
{
   bool   valid;
   int    source_used;
   long   minute_id;
   string fingerprint;
   bool   current_valid;
   bool   prev_valid;
   bool   last_good_applied;
   EA2SymbolRec symbols[];
};

struct CycleSnapshot
{
   bool ea1_valid;
   bool ea2_valid;
   int  ea1_source_used;
   int  ea2_source_used;
   long ea1_minute_id;
   long ea2_minute_id;
   int  ea1_age_min;
   int  ea2_age_min;
   bool ea1_stale;
   bool ea2_stale;
   string ea1_fingerprint;
   string ea2_fingerprint;
   bool fingerprint_match;
   int  ea2_lag_minutes;
   datetime accepted_server_time;
   int  symbol_count;
};

struct SymbolState
{
   string raw_symbol;
   int    symbol_index_from_ea1;
   string symbol_identity_hash;
   int    sector_id_from_ea1;
   string sector_id_source;
   string asset_class_from_ea1;
   string class_key_from_ea1;

   bool   ea1_present;
   bool   ea1_valid;
   bool   market_open_now_from_ea1;
   int    market_reason_code_from_ea1;

   bool   ea2_present;
   bool   ea2_valid;
   bool   ready_m1_from_ea2;
   bool   ready_m5_from_ea2;
   bool   ready_m15_from_ea2;
   bool   ready_d1_from_ea2;
   int    fresh_bits_from_ea2;
   double atr_points_m1_from_ea2;
   double atr_points_m5_from_ea2;
   double atr_points_m15_from_ea2;
   double volatility_accel_from_ea2;
   double vol_expansion_from_ea2;
   double spread_to_atr_m1_ratio_from_ea2;
   double spread_to_atr_m5_ratio_from_ea2;

   bool   intraday_horizon_ok;
   bool   overnight_risk_flag;
   int    max_horizon_class;
   int    precursor_status;
   double precursor_index_s;
   double precursor_index_i;
   double precursor_index_h;
   double compression_ratio;
   double range_surprise_z;
   double persistence_ratio_5;
   double micro_expansion_ratio;
   bool   candidate_eligible;
   double candidate_score;
   int    sector_leader_rank;
   bool   basket_selected;
   bool   correlation_pool_member;

   bool   intelligence_dirty;
   datetime last_compute_server_time;
   string data_reason_code;
   string publish_reason_code;
   string summary_state;
   int    input_integrity_state;

   string persistence_state;
   bool   persistence_loaded;
   bool   persistence_fresh;
   bool   persistence_stale;
   bool   persistence_corrupt;
   bool   persistence_incompatible;
   bool   resumed_from_persistence;
   bool   restarted_clean;
   int    persistence_age_sec;
   string continuity_origin;
   datetime continuity_last_good_server_time;

   int    persist_ring_count;
   int    persist_ring_write_idx;
   double persist_recent_i[PERSIST_RING_CAP];
   bool   persist_loaded_attempted;
   bool   persist_save_pending;
   datetime last_persist_save_time;
   int    basket_cooling_remaining;
   int    last_basket_selected_cycle;
};

struct LeaderRow
{
   int    sector_id;
   int    symbol_index;
   int    leader_rank;
   double leader_score;
};

struct PairRow
{
   int    a;
   int    b;
   double similarity;
   bool   same_sector;
};

struct BasketRow
{
   int    symbol_index;
   int    slot;
};

struct EventRow
{
   datetime ts;
   string   msg;
};

struct PerfState
{
   int dur_total_ms;
   int dur_read_ea1_ms;
   int dur_validate_ea1_ms;
   int dur_parse_ea1_ms;
   int dur_read_ea2_ms;
   int dur_validate_ea2_ms;
   int dur_parse_ea2_ms;
   int dur_intelligence_ms;
   int dur_correlation_ms;
   int dur_basket_ms;
   int dur_build_ms;
   int dur_write_tmp_ms;
   int dur_commit_ms;
   int dur_backup_ms;
   int dur_persist_load_ms;
   int dur_persist_save_ms;
};

struct IoCounters
{
   int stage_write_ok;
   int stage_write_fail;
   int debug_write_ok;
   int debug_write_fail;
   int backup_ok;
   int backup_fail;
   int skipped_same_payload;
   int read_ea1_attempts;
   int read_ea2_attempts;
   int read_ea1_accepts;
   int read_ea2_accepts;
   int read_ea1_rejects;
   int read_ea2_rejects;
};

string g_firm_id = "";
string g_firms_root = "FIRMS\\";
string g_firm_dir = "";
string g_outputs_dir = "";
string g_tmp_dir = "";
string g_tmp_dir_ea3 = "";
string g_persist_dir_ea3 = "";
string g_locks_dir = "";

string g_ea1_current_file = "";
string g_ea1_prev_file = "";
string g_ea2_current_file = "";
string g_ea2_prev_file = "";

string g_stage_file = "";
string g_stage_prev_file = "";
string g_stage_backup_file = "";
string g_debug_file = "";
string g_debug_prev_file = "";
string g_debug_backup_file = "";

bool   g_engine_running = false;
int    g_engine_state = ENGINE_INIT;
bool   g_policy_dirty = true;
int    g_cycle_counter = 0;
int    g_timer_tick_count = 0;
int    g_overrun_count = 0;
int    g_cycle_skip_count = 0;
ulong  g_last_timer_us = 0;
int    g_engine_clock_drift_ms = 0;
bool   g_have_cycle = false;
datetime g_last_publish_time = 0;
datetime g_last_debug_time = 0;
datetime g_last_persist_scan_time = 0;
datetime g_last_cleanup_time = 0;
int    g_write_seq = 0;
int    g_debug_write_seq = 0;

PerfState g_perf;
IoCounters g_io;

UpstreamEA1Snapshot g_ea1_last_good;
UpstreamEA2Snapshot g_ea2_last_good;
CycleSnapshot g_cycle;

SymbolState g_symbols[];
int         g_symbol_count = 0;

LeaderRow   g_leaders[];
int         g_leader_count = 0;

PairRow     g_pairs[];
int         g_pair_count = 0;

BasketRow   g_basket[];
int         g_basket_count = 0;

int         g_candidate_pool[];
int         g_candidate_pool_count = 0;

EventRow    g_events[MAX_EVENTS];
int         g_event_count = 0;

uint        g_last_stage_payload_hash = 0;
uint        g_last_debug_payload_hash = 0;
datetime    g_write_backoff_until = 0;
int         g_write_failure_streak = 0;

int         g_rr_compute_cursor = 0;
int         g_rr_load_cursor = 0;
int         g_rr_save_cursor = 0;
bool        g_universe_dirty = true;
bool        g_leaders_dirty = true;
bool        g_corr_dirty = true;
bool        g_basket_dirty = true;
bool        g_counts_dirty = true;

int         g_cov_intraday_horizon_ok_count = 0;
int         g_cov_overnight_risk_flag_count = 0;
int         g_cov_candidates_count = 0;
int         g_cov_sector_leaders_count = 0;
int         g_cov_correlation_pairs_count = 0;
int         g_cov_basket_selected_count = 0;

int         g_hsum_none_count = 0;
int         g_hsum_scalp_count = 0;
int         g_hsum_intraday_count = 0;
int         g_hsum_swing_count = 0;
int         g_hsum_blocked_count = 0;
int         g_hsum_watch_count = 0;
int         g_hsum_qualified_count = 0;
int         g_hsum_strong_count = 0;

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
string JsonBool(const bool v)
{
   if(v) return "true";
   return "false";
}
string JsonInt(const int v) { return IntegerToString(v); }

string LongToStr64(const long v)
{
   return StringFormat("%I64d", v);
}

string JsonLong(const long v) { return LongToStr64(v); }

string SafeDoubleToString(const double v, const int digits)
{
   if(v == EMPTY_VALUE) return "null";
   return DoubleToString(v, digits);
}

string JsonDoubleOrNull(const double v, const int digits)
{
   if(v == EMPTY_VALUE) return "null";
   return DoubleToString(v, digits);
}

string JsonStringOrNull(const string s)
{
   if(s == "") return "null";
   return JsonString(s);
}

int ClampInt(const int v, const int lo, const int hi)
{
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

double ClampDouble(const double v, const double lo, const double hi)
{
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

bool IsKnownNumber(const double v)
{
   return (v != EMPTY_VALUE);
}

string LowerTrim(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   StringToLower(s);
   return s;
}

int StatusStrength(const int status)
{
   if(status == PSTATUS_STRONG) return 4;
   if(status == PSTATUS_QUALIFIED) return 3;
   if(status == PSTATUS_WATCH) return 2;
   if(status == PSTATUS_BLOCKED) return 1;
   return 0;
}

string IntegrityToString(const int v)
{
   if(v == INTEGRITY_FULL) return "FULL";
   if(v == INTEGRITY_EA1_ONLY) return "EA1_ONLY";
   if(v == INTEGRITY_EA1_STALE) return "EA1_STALE";
   if(v == INTEGRITY_EA2_STALE) return "EA2_STALE";
   if(v == INTEGRITY_FINGERPRINT_MISMATCH) return "FINGERPRINT_MISMATCH";
   return "UPSTREAM_MISSING";
}

string HorizonToString(const int v)
{
   if(v == HORIZON_SCALP) return "SCALP";
   if(v == HORIZON_INTRADAY) return "INTRADAY";
   if(v == HORIZON_SWING) return "SWING";
   return "NONE";
}

string PrecursorStatusToString(const int v)
{
   if(v == PSTATUS_BLOCKED) return "BLOCKED";
   if(v == PSTATUS_WATCH) return "WATCH";
   if(v == PSTATUS_QUALIFIED) return "QUALIFIED";
   if(v == PSTATUS_STRONG) return "STRONG";
   return "NONE";
}

string EngineStateToString(const int v)
{
   if(v == ENGINE_UPSTREAM_WAIT) return "UPSTREAM_WAIT";
   if(v == ENGINE_WARMUP) return "WARMUP";
   if(v == ENGINE_STEADY) return "STEADY";
   if(v == ENGINE_DEGRADED) return "DEGRADED";
   return "INIT";
}

string SourceToString(const int v)
{
   if(v == SRC_CURRENT) return "SRC_CURRENT";
   if(v == SRC_PREVIOUS) return "SRC_PREVIOUS";
   if(v == SRC_LAST_GOOD) return "SRC_LAST_GOOD";
   return "SRC_NONE";
}

uint FNV1a32(const string s)
{
   uint h = 2166136261;
   for(int i=0;i<StringLen(s);i++)
   {
      uchar c = (uchar)StringGetCharacter(s, i);
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

long GetMinuteId()
{
   return (long)(TimeCurrent() / 60);
}

void ResetPerf()
{
   g_perf.dur_total_ms = 0;
   g_perf.dur_read_ea1_ms = 0;
   g_perf.dur_validate_ea1_ms = 0;
   g_perf.dur_parse_ea1_ms = 0;
   g_perf.dur_read_ea2_ms = 0;
   g_perf.dur_validate_ea2_ms = 0;
   g_perf.dur_parse_ea2_ms = 0;
   g_perf.dur_intelligence_ms = 0;
   g_perf.dur_correlation_ms = 0;
   g_perf.dur_basket_ms = 0;
   g_perf.dur_build_ms = 0;
   g_perf.dur_write_tmp_ms = 0;
   g_perf.dur_commit_ms = 0;
   g_perf.dur_backup_ms = 0;
   g_perf.dur_persist_load_ms = 0;
   g_perf.dur_persist_save_ms = 0;
}

void AddEvent(const string msg)
{
   int idx = g_event_count;
   if(idx < MAX_EVENTS)
   {
      g_events[idx].ts = TimeCurrent();
      g_events[idx].msg = msg;
      g_event_count++;
      return;
   }
   for(int i=1;i<MAX_EVENTS;i++)
      g_events[i-1] = g_events[i];
   g_events[MAX_EVENTS-1].ts = TimeCurrent();
   g_events[MAX_EVENTS-1].msg = msg;
}

bool EnsureDir(const string path)
{
   string p = path;
   if(StringLen(p) <= 0) return false;
   if(StringSubstr(p, StringLen(p)-1, 1) == "\\")
      p = StringSubstr(p, 0, StringLen(p)-1);
   return FolderCreate(p, FILE_COMMON);
}

void InitFirmFiles()
{
   string firm = InpFirmId;
   if(firm == "")
   {
      firm = AccountInfoString(ACCOUNT_COMPANY);
      if(firm == "") firm = AccountInfoString(ACCOUNT_SERVER);
   }
   g_firm_id = SanitizeFirmName(firm);
   g_firm_dir = g_firms_root + g_firm_id + "\\";
   g_outputs_dir = g_firm_dir + "outputs\\";
   g_tmp_dir = g_firm_dir + "tmp\\";
   g_tmp_dir_ea3 = g_tmp_dir + "ea3\\";
   g_persist_dir_ea3 = g_firm_dir + "persistence\\ea3\\";
   g_locks_dir = g_firm_dir + "locks\\";

   EnsureDir("FIRMS");
   EnsureDir(g_firm_dir);
   EnsureDir(g_outputs_dir);
   EnsureDir(g_tmp_dir);
   EnsureDir(g_tmp_dir_ea3);
   EnsureDir(g_persist_dir_ea3);
   EnsureDir(g_locks_dir);

   g_ea1_current_file = g_firms_root + g_firm_id + "_symbols_universe.json";
   g_ea1_prev_file    = g_outputs_dir + g_firm_id + "_symbols_universe_prev.json";
   g_ea2_current_file = g_firms_root + g_firm_id + "_history_metrics.json";
   g_ea2_prev_file    = g_outputs_dir + g_firm_id + "_history_metrics_prev.json";

   g_stage_file       = g_firms_root + g_firm_id + "_intelligence.json";
   g_stage_prev_file  = g_outputs_dir + g_firm_id + "_intelligence_prev.json";
   g_stage_backup_file= g_outputs_dir + g_firm_id + "_intelligence_backup.json";
   g_debug_file       = g_firms_root + g_firm_id + "_debug_ea3.json";
   g_debug_prev_file  = g_outputs_dir + g_firm_id + "_debug_ea3_prev.json";
   g_debug_backup_file= g_outputs_dir + g_firm_id + "_debug_ea3_backup.json";
}

bool ReadTextFileCommon(const string rel, string &out)
{
   out = "";
   if(!FileIsExist(rel, FILE_COMMON))
      return false;

   int h = FileOpen(rel, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;

   while(!FileIsEnding(h))
      out += FileReadString(h);

   FileClose(h);
   return (StringLen(out) > 1);
}

bool WriteTextFileCommon(const string rel, const string text, int &bytes_written)
{
   bytes_written = 0;
   int h = FileOpen(rel, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;

   FileWriteString(h, text);
   bytes_written = (int)FileTell(h);
   FileFlush(h);
   FileClose(h);

   return (bytes_written > 0);
}

bool BestEffortPreservePrevious(const string current_rel, const string prev_rel)
{
   if(!FileIsExist(current_rel, FILE_COMMON))
      return true;

   FileDelete(prev_rel, FILE_COMMON);

   if(FileCopy(current_rel, FILE_COMMON, prev_rel, FILE_COMMON))
      return true;

   return false;
}

string BuildTempFileName(const string tmp_dir, const string final_name, const long minute_id, const int seq)
{
   return tmp_dir + final_name + "." + LongToStr64(minute_id) + "." + IntegerToString(seq) + ".tmp";
}

bool CommitFileAtomic(const string tmp_rel, const string final_rel)
{
   FileDelete(final_rel, FILE_COMMON);
   if(FileMove(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
      return true;
   FileDelete(final_rel, FILE_COMMON);
   if(FileCopy(tmp_rel, FILE_COMMON, final_rel, FILE_COMMON))
   {
      FileDelete(tmp_rel, FILE_COMMON);
      return true;
   }
   return false;
}

bool BestEffortBackup(const string current_rel, const string backup_rel)
{
   FileDelete(backup_rel, FILE_COMMON);
   if(FileCopy(current_rel, FILE_COMMON, backup_rel, FILE_COMMON))
      return true;
   return false;
}

int SkipWs(const string s, int p)
{
   int n = StringLen(s);
   while(p < n)
   {
      uchar c = (uchar)StringGetCharacter(s, p);
      if(c == ' ' || c == '\r' || c == '\n' || c == '\t') p++;
      else break;
   }
   return p;
}

int FindMatching(const string s, int start, const int open_c, const int close_c)
{
   int n = StringLen(s);
   int depth = 0;
   bool in_str = false;
   bool esc = false;
   for(int i=start;i<n;i++)
   {
      uchar c = (uchar)StringGetCharacter(s, i);
      if(in_str)
      {
         if(esc) { esc = false; continue; }
         if(c == '\\') { esc = true; continue; }
         if(c == '"') in_str = false;
         continue;
      }
      if(c == '"') { in_str = true; continue; }
      if(c == (uint)open_c) depth++;
      else if(c == (uint)close_c)
      {
         depth--;
         if(depth == 0) return i;
      }
   }
   return -1;
}

int FindKeyValueStart(const string s, const string key, int from_pos=0)
{
   string pat = "\"" + key + "\"";
   int p = StringFind(s, pat, from_pos);
   if(p < 0) return -1;
   p = StringFind(s, ":", p + StringLen(pat));
   if(p < 0) return -1;
   p++;
   return SkipWs(s, p);
}

bool JsonReadStringKey(const string s, const string key, string &out, int from_pos=0)
{
   out = "";
   int p = FindKeyValueStart(s, key, from_pos);
   if(p < 0) return false;
   if((uint)StringGetCharacter(s, p) != '"') return false;
   p++;
   string r = "";
   bool esc = false;
   int n = StringLen(s);
   for(int i=p;i<n;i++)
   {
      uchar c = (uchar)StringGetCharacter(s, i);
      if(esc)
      {
         if(c == 'n') r += "\n";
         else if(c == 'r') r += "\r";
         else if(c == 't') r += "\t";
         else r += StringSubstr(s, i, 1);
         esc = false;
         continue;
      }
      if(c == '\\') { esc = true; continue; }
      if(c == '"') { out = r; return true; }
      r += StringSubstr(s, i, 1);
   }
   return false;
}

bool JsonReadBoolKey(const string s, const string key, bool &out, int from_pos=0)
{
   out = false;
   int p = FindKeyValueStart(s, key, from_pos);
   if(p < 0) return false;
   if(StringSubstr(s, p, 4) == "true") { out = true; return true; }
   if(StringSubstr(s, p, 5) == "false") { out = false; return true; }
   return false;
}

bool JsonReadLongKey(const string s, const string key, long &out, int from_pos=0)
{
   out = 0;
   int p = FindKeyValueStart(s, key, from_pos);
   if(p < 0) return false;
   int n = StringLen(s);
   int i = p;
   while(i < n)
   {
      uchar c = (uchar)StringGetCharacter(s, i);
      bool ok = ((c >= '0' && c <= '9') || c == '-' || c == '+');
      if(!ok) break;
      i++;
   }
   string t = StringSubstr(s, p, i - p);
   if(t == "") return false;
   out = StringToInteger(t);
   return true;
}

bool JsonReadIntKey(const string s, const string key, int &out, int from_pos=0)
{
   long v = 0;
   if(!JsonReadLongKey(s, key, v, from_pos)) return false;
   out = (int)v;
   return true;
}

bool JsonReadDoubleKey(const string s, const string key, double &out, int from_pos=0)
{
   out = EMPTY_VALUE;
   int p = FindKeyValueStart(s, key, from_pos);
   if(p < 0) return false;
   if(StringSubstr(s, p, 4) == "null") return false;
   int n = StringLen(s);
   int i = p;
   while(i < n)
   {
      uchar c = (uchar)StringGetCharacter(s, i);
      bool ok = ((c >= '0' && c <= '9') || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E');
      if(!ok) break;
      i++;
   }
   string t = StringSubstr(s, p, i - p);
   if(t == "") return false;
   out = StringToDouble(t);
   return true;
}

bool JsonExtractObjectKey(const string s, const string key, string &obj, int from_pos=0)
{
   obj = "";
   int p = FindKeyValueStart(s, key, from_pos);
   if(p < 0) return false;
   if(StringGetCharacter(s, p) != '{') return false;
   int q = FindMatching(s, p, '{', '}');
   if(q < 0) return false;
   obj = StringSubstr(s, p, q - p + 1);
   return true;
}

bool JsonExtractArrayKey(const string s, const string key, string &arr, int from_pos=0)
{
   arr = "";
   int p = FindKeyValueStart(s, key, from_pos);
   if(p < 0) return false;
   if(StringGetCharacter(s, p) != '[') return false;
   int q = FindMatching(s, p, '[', ']');
   if(q < 0) return false;
   arr = StringSubstr(s, p, q - p + 1);
   return true;
}

int JsonSplitTopObjects(const string arr, string &objs[])
{
   ArrayResize(objs, 0);
   int n = StringLen(arr);
   int p = SkipWs(arr, 0);
   if(p >= n || (uint)StringGetCharacter(arr, p) != '[') return 0;
   p++;
   int count = 0;
   bool in_str = false;
   bool esc = false;
   int depth = 0;
   int obj_start = -1;
   for(int i=p;i<n;i++)
   {
      uchar c = (uchar)StringGetCharacter(arr, i);
      if(in_str)
      {
         if(esc) { esc = false; continue; }
         if(c == '\\') { esc = true; continue; }
         if(c == '"') in_str = false;
         continue;
      }
      if(c == '"') { in_str = true; continue; }
      if(c == '{')
      {
         if(depth == 0) obj_start = i;
         depth++;
      }
      else if(c == '}')
      {
         depth--;
         if(depth == 0 && obj_start >= 0)
         {
            ArrayResize(objs, count + 1);
            objs[count] = StringSubstr(arr, obj_start, i - obj_start + 1);
            count++;
            obj_start = -1;
         }
      }
   }
   return count;
}

bool JsonGuardOk(const string s)
{
   if(StringLen(s) < 20) return false;
   int p = SkipWs(s, 0);
   if(p < 0 || p >= StringLen(s) || StringGetCharacter(s, p) != '{') return false;
   return (StringFind(s, "\"producer\"") >= 0 && StringFind(s, "\"stage\"") >= 0 && StringFind(s, "\"symbols\"") >= 0);
}

bool ParseEA1Snapshot(const string text, UpstreamEA1Snapshot &snap)
{
   snap.valid = false;
   snap.minute_id = 0;
   snap.fingerprint = "";
   ArrayResize(snap.symbols, 0);

   string producer = "", stage = "", arr = "";
   if(!JsonReadStringKey(text, "producer", producer)) return false;
   if(!JsonReadStringKey(text, "stage", stage)) return false;
   if(producer != "EA1" || stage != "symbols_universe") return false;
   if(!JsonReadLongKey(text, "minute_id", snap.minute_id)) return false;
   if(!JsonReadStringKey(text, "universe_fingerprint", snap.fingerprint)) return false;
   if(!JsonExtractArrayKey(text, "symbols", arr)) return false;

   string objs[];
   int cnt = JsonSplitTopObjects(arr, objs);
   if(cnt <= 0 || cnt > MAX_SYMBOLS_HARD) return false;

   ArrayResize(snap.symbols, cnt);
   for(int i=0;i<cnt;i++)
   {
      string o = objs[i];
      string identity = "", market_status = "";
      if(!JsonReadStringKey(o, "raw_symbol", snap.symbols[i].raw_symbol)) return false;
      if(!JsonExtractObjectKey(o, "identity", identity)) return false;
      if(!JsonReadStringKey(identity, "asset_class", snap.symbols[i].asset_class)) return false;
      if(!JsonReadStringKey(identity, "class_key", snap.symbols[i].class_key)) return false;
      if(!JsonExtractObjectKey(o, "market_status", market_status)) return false;
      if(!JsonReadBoolKey(market_status, "market_open_now", snap.symbols[i].market_open_now)) return false;
      if(!JsonReadIntKey(market_status, "reason_code", snap.symbols[i].reason_code)) return false;
      int sector = 0;
      if(JsonReadIntKey(o, "sector_id", sector))
      {
         snap.symbols[i].has_sector_id = true;
         snap.symbols[i].sector_id = sector;
      }
      else
      {
         snap.symbols[i].has_sector_id = false;
         snap.symbols[i].sector_id = 0;
      }
   }
   snap.valid = true;
   return true;
}

bool ParseEA2Snapshot(const string text, UpstreamEA2Snapshot &snap)
{
   snap.valid = false;
   snap.minute_id = 0;
   snap.fingerprint = "";
   ArrayResize(snap.symbols, 0);

   string producer = "", stage = "", arr = "";
   if(!JsonReadStringKey(text, "producer", producer)) return false;
   if(!JsonReadStringKey(text, "stage", stage)) return false;
   if(producer != "EA2" || stage != "history_metrics") return false;
   if(!JsonReadLongKey(text, "minute_id", snap.minute_id)) return false;
   if(!JsonReadStringKey(text, "universe_fingerprint", snap.fingerprint)) return false;
   if(!JsonExtractArrayKey(text, "symbols", arr)) return false;

   string objs[];
   int cnt = JsonSplitTopObjects(arr, objs);
   if(cnt <= 0 || cnt > MAX_SYMBOLS_HARD) return false;
   ArrayResize(snap.symbols, cnt);

   for(int i=0;i<cnt;i++)
   {
      string o = objs[i];
      string hydration = "", metrics = "";
      if(!JsonReadStringKey(o, "raw_symbol", snap.symbols[i].raw_symbol)) return false;
      if(!JsonExtractObjectKey(o, "hydration", hydration)) return false;
      if(!JsonExtractObjectKey(o, "metrics", metrics)) return false;
      if(!JsonReadBoolKey(hydration, "ready_m1", snap.symbols[i].ready_m1)) return false;
      if(!JsonReadBoolKey(hydration, "ready_m5", snap.symbols[i].ready_m5)) return false;
      if(!JsonReadBoolKey(hydration, "ready_m15", snap.symbols[i].ready_m15)) return false;
      if(!JsonReadBoolKey(hydration, "ready_d1", snap.symbols[i].ready_d1)) return false;
      if(!JsonReadIntKey(hydration, "fresh_bits", snap.symbols[i].fresh_bits)) return false;
      JsonReadDoubleKey(metrics, "atr_points_m1", snap.symbols[i].atr_points_m1);
      JsonReadDoubleKey(metrics, "atr_points_m5", snap.symbols[i].atr_points_m5);
      JsonReadDoubleKey(metrics, "atr_points_m15", snap.symbols[i].atr_points_m15);
      JsonReadDoubleKey(metrics, "volatility_accel", snap.symbols[i].volatility_accel);
      JsonReadDoubleKey(metrics, "vol_expansion", snap.symbols[i].vol_expansion);
      JsonReadDoubleKey(metrics, "spread_to_atr_m1_ratio", snap.symbols[i].spread_to_atr_m1_ratio);
      JsonReadDoubleKey(metrics, "spread_to_atr_m5_ratio", snap.symbols[i].spread_to_atr_m5_ratio);
   }
   snap.valid = true;
   return true;
}

bool IsAcceptableNewSnapshotEA1(const UpstreamEA1Snapshot &cand, const UpstreamEA1Snapshot &last_good)
{
   if(!cand.valid) return false;
   if(!last_good.valid) return true;
   if(cand.fingerprint == last_good.fingerprint) return true;
   if(cand.minute_id > last_good.minute_id) return true;
   return false;
}

bool IsAcceptableNewSnapshotEA2(const UpstreamEA2Snapshot &cand, const UpstreamEA2Snapshot &last_good)
{
   if(!cand.valid) return false;
   if(!last_good.valid) return true;
   if(cand.fingerprint == last_good.fingerprint) return true;
   if(cand.minute_id > last_good.minute_id) return true;
   return false;
}

bool TryLoadEA1FromFile(const string rel, UpstreamEA1Snapshot &snap, bool &valid)
{
   valid = false;
   string text = "";
   if(!ReadTextFileCommon(rel, text)) return false;
   if(!JsonGuardOk(text)) return false;
   valid = ParseEA1Snapshot(text, snap);
   return true;
}

bool TryLoadEA2FromFile(const string rel, UpstreamEA2Snapshot &snap, bool &valid)
{
   valid = false;
   string text = "";
   if(!ReadTextFileCommon(rel, text)) return false;
   if(!JsonGuardOk(text)) return false;
   valid = ParseEA2Snapshot(text, snap);
   return true;
}

bool AcceptEA1Snapshot()
{
   long t0 = (long)(GetMicrosecondCount() / 1000);
   UpstreamEA1Snapshot current_snap, prev_snap, selected;
   bool valid = false;
   bool has_file = TryLoadEA1FromFile(g_ea1_current_file, current_snap, valid);
   g_io.read_ea1_attempts++;
   g_ea1_last_good.current_valid = valid;
   if(has_file && valid && IsAcceptableNewSnapshotEA1(current_snap, g_ea1_last_good))
   {
      current_snap.source_used = SRC_CURRENT;
      current_snap.current_valid = true;
      current_snap.prev_valid = false;
      current_snap.last_good_applied = false;
      g_ea1_last_good = current_snap;
      g_io.read_ea1_accepts++;
      g_perf.dur_read_ea1_ms = (int)((GetMicrosecondCount()/1000)-t0);
      return true;
   }
   if(has_file && !valid) g_io.read_ea1_rejects++;

   valid = false;
   has_file = TryLoadEA1FromFile(g_ea1_prev_file, prev_snap, valid);
   g_ea1_last_good.prev_valid = valid;
   if(has_file && valid && IsAcceptableNewSnapshotEA1(prev_snap, g_ea1_last_good))
   {
      prev_snap.source_used = SRC_PREVIOUS;
      prev_snap.current_valid = current_snap.valid;
      prev_snap.prev_valid = true;
      prev_snap.last_good_applied = false;
      g_ea1_last_good = prev_snap;
      g_io.read_ea1_accepts++;
      g_perf.dur_read_ea1_ms = (int)((GetMicrosecondCount()/1000)-t0);
      return true;
   }
   if(has_file && !valid) g_io.read_ea1_rejects++;

   if(g_ea1_last_good.valid)
   {
      g_ea1_last_good.source_used = SRC_LAST_GOOD;
      g_ea1_last_good.last_good_applied = true;
      g_perf.dur_read_ea1_ms = (int)((GetMicrosecondCount()/1000)-t0);
      return true;
   }
   g_perf.dur_read_ea1_ms = (int)((GetMicrosecondCount()/1000)-t0);
   return false;
}

bool AcceptEA2Snapshot()
{
   long t0 = (long)(GetMicrosecondCount() / 1000);
   UpstreamEA2Snapshot current_snap, prev_snap;
   bool valid = false;
   bool has_file = TryLoadEA2FromFile(g_ea2_current_file, current_snap, valid);
   g_io.read_ea2_attempts++;
   g_ea2_last_good.current_valid = valid;
   if(has_file && valid && IsAcceptableNewSnapshotEA2(current_snap, g_ea2_last_good))
   {
      current_snap.source_used = SRC_CURRENT;
      current_snap.current_valid = true;
      current_snap.prev_valid = false;
      current_snap.last_good_applied = false;
      g_ea2_last_good = current_snap;
      g_io.read_ea2_accepts++;
      g_perf.dur_read_ea2_ms = (int)((GetMicrosecondCount()/1000)-t0);
      return true;
   }
   if(has_file && !valid) g_io.read_ea2_rejects++;

   valid = false;
   has_file = TryLoadEA2FromFile(g_ea2_prev_file, prev_snap, valid);
   g_ea2_last_good.prev_valid = valid;
   if(has_file && valid && IsAcceptableNewSnapshotEA2(prev_snap, g_ea2_last_good))
   {
      prev_snap.source_used = SRC_PREVIOUS;
      prev_snap.current_valid = current_snap.valid;
      prev_snap.prev_valid = true;
      prev_snap.last_good_applied = false;
      g_ea2_last_good = prev_snap;
      g_io.read_ea2_accepts++;
      g_perf.dur_read_ea2_ms = (int)((GetMicrosecondCount()/1000)-t0);
      return true;
   }
   if(has_file && !valid) g_io.read_ea2_rejects++;

   if(g_ea2_last_good.valid)
   {
      g_ea2_last_good.source_used = SRC_LAST_GOOD;
      g_ea2_last_good.last_good_applied = true;
      g_perf.dur_read_ea2_ms = (int)((GetMicrosecondCount()/1000)-t0);
      return true;
   }
   g_perf.dur_read_ea2_ms = (int)((GetMicrosecondCount()/1000)-t0);
   return false;
}

bool IsReadWindowNow()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int sec = dt.sec;
   if(sec >= InpReadWindowStartSec && sec <= InpReadWindowEndSec) return true;
   if(!g_ea1_last_good.valid || !g_ea2_last_good.valid) return true;
   return false;
}

void FreezeCycleSnapshot()
{
   g_cycle.ea1_valid = g_ea1_last_good.valid;
   g_cycle.ea2_valid = g_ea2_last_good.valid;
   g_cycle.ea1_source_used = g_ea1_last_good.source_used;
   g_cycle.ea2_source_used = g_ea2_last_good.source_used;
   g_cycle.ea1_minute_id = g_ea1_last_good.minute_id;
   g_cycle.ea2_minute_id = g_ea2_last_good.minute_id;
   g_cycle.ea1_fingerprint = g_ea1_last_good.fingerprint;
   g_cycle.ea2_fingerprint = g_ea2_last_good.fingerprint;
   g_cycle.accepted_server_time = TimeCurrent();

   long now_minute = GetMinuteId();
   g_cycle.ea1_age_min = (g_cycle.ea1_valid ? (int)(now_minute - g_cycle.ea1_minute_id) : 999999);
   g_cycle.ea2_age_min = (g_cycle.ea2_valid ? (int)(now_minute - g_cycle.ea2_minute_id) : 999999);
   g_cycle.ea1_stale = (g_cycle.ea1_age_min > 2);
   g_cycle.ea2_stale = (g_cycle.ea2_age_min > 2);
   g_cycle.fingerprint_match = (g_cycle.ea1_valid && g_cycle.ea2_valid && g_cycle.ea1_fingerprint == g_cycle.ea2_fingerprint);
   g_cycle.ea2_lag_minutes = 0;
   if(g_cycle.ea1_valid && g_cycle.ea2_valid)
      g_cycle.ea2_lag_minutes = (int)(g_cycle.ea1_minute_id - g_cycle.ea2_minute_id);
   g_cycle.symbol_count = ArraySize(g_ea1_last_good.symbols);

   if(g_cycle.ea2_valid)
   {
      if(g_cycle.ea2_minute_id > g_cycle.ea1_minute_id) g_cycle.ea2_valid = false;
      if(!g_cycle.fingerprint_match) g_cycle.ea2_valid = false;
   }
   g_have_cycle = g_cycle.ea1_valid;
}

int SectorFromClassKey(const string class_key)
{
   string k = LowerTrim(class_key);
   if(k == "fx") return 1;
   if(k == "index") return 2;
   if(k == "crypto") return 3;
   if(k == "metal") return 4;
   if(k == "energy") return 5;
   if(k == "stock" || k == "equity") return 6;
   if(k == "etf") return 7;
   if(k == "bond") return 8;
   if(k == "rate") return 9;
   if(k == "custom") return 10;
   return 99;
}

int SectorFromAssetClass(const string asset_class)
{
   string a = LowerTrim(asset_class);
   if(a == "1") return 1;
   if(a == "2") return 2;
   if(a == "3") return 4;
   if(a == "4") return 6;
   if(a == "5") return 3;
   if(a == "6") return 5;
   if(a == "7") return 10;
   if(a == "8") return 7;
   long iv = StringToInteger(a);
   if(iv > 0 && iv < 100) return (int)iv;
   uint h = FNV1a32(a);
   int bucket = (int)((ulong)h % 50ULL);
   return 100 + bucket;
}

int SectorHashBucket(const string raw_symbol, const string class_key, const string asset_class)
{
   string basis = raw_symbol + "|" + class_key + "|" + asset_class;
   uint h = FNV1a32(basis);
   int bucket = (int)((ulong)h % 100ULL);
   return 200 + bucket;
}

string BuildIdentityHash(const string raw_symbol, const string class_key, const int sector_id)
{
   return FNV1a32Hex(raw_symbol + "|" + class_key + "|" + IntegerToString(sector_id));
}

void ResetSymbolState(SymbolState &s)
{
   s.raw_symbol = "";
   s.symbol_index_from_ea1 = -1;
   s.symbol_identity_hash = "";
   s.sector_id_from_ea1 = 0;
   s.sector_id_source = "";

   s.asset_class_from_ea1 = "";
   s.class_key_from_ea1 = "";

   s.ea1_present = false;
   s.ea1_valid = false;
   s.market_open_now_from_ea1 = false;
   s.market_reason_code_from_ea1 = -1;

   s.ea2_present = false;
   s.ea2_valid = false;
   s.ready_m1_from_ea2 = false;
   s.ready_m5_from_ea2 = false;
   s.ready_m15_from_ea2 = false;
   s.ready_d1_from_ea2 = false;
   s.fresh_bits_from_ea2 = 0;
   s.atr_points_m1_from_ea2 = EMPTY_VALUE;
   s.atr_points_m5_from_ea2 = EMPTY_VALUE;
   s.atr_points_m15_from_ea2 = EMPTY_VALUE;
   s.volatility_accel_from_ea2 = EMPTY_VALUE;
   s.vol_expansion_from_ea2 = EMPTY_VALUE;
   s.spread_to_atr_m1_ratio_from_ea2 = EMPTY_VALUE;
   s.spread_to_atr_m5_ratio_from_ea2 = EMPTY_VALUE;

   s.intraday_horizon_ok = false;
   s.overnight_risk_flag = true;
   s.max_horizon_class = HORIZON_NONE;
   s.precursor_status = PSTATUS_NONE;
   s.precursor_index_s = EMPTY_VALUE;
   s.precursor_index_i = EMPTY_VALUE;
   s.precursor_index_h = EMPTY_VALUE;
   s.compression_ratio = EMPTY_VALUE;
   s.range_surprise_z = EMPTY_VALUE;
   s.persistence_ratio_5 = EMPTY_VALUE;
   s.micro_expansion_ratio = EMPTY_VALUE;
   s.candidate_eligible = false;
   s.candidate_score = EMPTY_VALUE;
   s.sector_leader_rank = 0;
   s.basket_selected = false;
   s.correlation_pool_member = false;

   s.intelligence_dirty = true;
   s.last_compute_server_time = 0;
   s.data_reason_code = "RESET";
   s.publish_reason_code = "RESET";
   s.summary_state = "RESET";
   s.input_integrity_state = INTEGRITY_UPSTREAM_MISSING;

   s.persistence_state = "INIT";
   s.persistence_loaded = false;
   s.persistence_fresh = false;
   s.persistence_stale = false;
   s.persistence_corrupt = false;
   s.persistence_incompatible = false;
   s.resumed_from_persistence = false;
   s.restarted_clean = true;
   s.persistence_age_sec = 0;
   s.continuity_origin = "NONE";
   s.continuity_last_good_server_time = 0;

   s.persist_ring_count = 0;
   s.persist_ring_write_idx = 0;
   for(int i=0;i<PERSIST_RING_CAP;i++) s.persist_recent_i[i] = EMPTY_VALUE;
   s.persist_loaded_attempted = false;
   s.persist_save_pending = false;
   s.last_persist_save_time = 0;
   s.basket_cooling_remaining = 0;
   s.last_basket_selected_cycle = -1;
}

int FindEA2IndexBySymbol(const string raw_symbol)
{
   int n = ArraySize(g_ea2_last_good.symbols);
   for(int i=0;i<n;i++)
      if(g_ea2_last_good.symbols[i].raw_symbol == raw_symbol)
         return i;
   return -1;
}

bool UniverseNeedsRebuild()
{
   if(!g_ea1_last_good.valid) return false;
   if(g_symbol_count != ArraySize(g_ea1_last_good.symbols)) return true;
   if(g_symbol_count <= 0) return true;
   for(int i=0;i<g_symbol_count;i++)
   {
      if(g_symbols[i].raw_symbol != g_ea1_last_good.symbols[i].raw_symbol)
         return true;
   }
   return g_universe_dirty;
}

void RebuildUniverse()
{
   int cnt = ArraySize(g_ea1_last_good.symbols);
   if(cnt <= 0 || cnt > MAX_SYMBOLS_HARD) return;

   SymbolState old_symbols[];
   int old_count = g_symbol_count;
   ArrayResize(old_symbols, old_count);
   for(int i=0;i<old_count;i++) old_symbols[i] = g_symbols[i];

   ArrayResize(g_symbols, cnt);
   g_symbol_count = cnt;

   for(int i=0;i<cnt;i++)
   {
      ResetSymbolState(g_symbols[i]);
      g_symbols[i].raw_symbol = g_ea1_last_good.symbols[i].raw_symbol;
      g_symbols[i].symbol_index_from_ea1 = i;

      int match = -1;
      for(int j=0;j<old_count;j++)
      {
         if(old_symbols[j].raw_symbol == g_symbols[i].raw_symbol)
         {
            match = j;
            break;
         }
      }
      if(match >= 0)
      {
         SymbolState prev = old_symbols[match];
         g_symbols[i].persist_ring_count = prev.persist_ring_count;
         g_symbols[i].persist_ring_write_idx = prev.persist_ring_write_idx;
         for(int k=0;k<PERSIST_RING_CAP;k++) g_symbols[i].persist_recent_i[k] = prev.persist_recent_i[k];
         g_symbols[i].persist_loaded_attempted = prev.persist_loaded_attempted;
         g_symbols[i].persistence_loaded = prev.persistence_loaded;
         g_symbols[i].persistence_fresh = prev.persistence_fresh;
         g_symbols[i].persistence_stale = prev.persistence_stale;
         g_symbols[i].persistence_corrupt = prev.persistence_corrupt;
         g_symbols[i].persistence_incompatible = prev.persistence_incompatible;
         g_symbols[i].resumed_from_persistence = prev.resumed_from_persistence;
         g_symbols[i].restarted_clean = prev.restarted_clean;
         g_symbols[i].persistence_age_sec = prev.persistence_age_sec;
         g_symbols[i].continuity_origin = prev.continuity_origin;
         g_symbols[i].continuity_last_good_server_time = prev.continuity_last_good_server_time;
         g_symbols[i].last_persist_save_time = prev.last_persist_save_time;
      }
   }

   g_rr_compute_cursor = 0;
   g_rr_load_cursor = 0;
   g_rr_save_cursor = 0;
   g_leader_count = 0;
   g_pair_count = 0;
   g_basket_count = 0;
   ArrayResize(g_leaders, 0);
   ArrayResize(g_pairs, 0);
   ArrayResize(g_basket, 0);
   ArrayResize(g_candidate_pool, 0);
   g_candidate_pool_count = 0;
   g_universe_dirty = false;
   g_leaders_dirty = true;
   g_corr_dirty = true;
   g_basket_dirty = true;
   g_counts_dirty = true;
   AddEvent("Universe rebuilt: " + IntegerToString(cnt) + " symbols");
}

void MergeAcceptedEAInputs()
{
   for(int i=0;i<g_symbol_count;i++)
   {
      EA1SymbolRec r1 = g_ea1_last_good.symbols[i];
      bool dirty_before = g_symbols[i].intelligence_dirty;

      bool old_market_open = g_symbols[i].market_open_now_from_ea1;
      int old_reason = g_symbols[i].market_reason_code_from_ea1;
      int old_fresh_bits = g_symbols[i].fresh_bits_from_ea2;
      bool old_r1 = g_symbols[i].ready_m1_from_ea2;
      bool old_r5 = g_symbols[i].ready_m5_from_ea2;
      bool old_r15 = g_symbols[i].ready_m15_from_ea2;
      bool old_rd1 = g_symbols[i].ready_d1_from_ea2;
      double old_atr1 = g_symbols[i].atr_points_m1_from_ea2;
      double old_atr5 = g_symbols[i].atr_points_m5_from_ea2;
      double old_atr15 = g_symbols[i].atr_points_m15_from_ea2;
      double old_va = g_symbols[i].volatility_accel_from_ea2;
      double old_ve = g_symbols[i].vol_expansion_from_ea2;
      double old_s1 = g_symbols[i].spread_to_atr_m1_ratio_from_ea2;
      double old_s5 = g_symbols[i].spread_to_atr_m5_ratio_from_ea2;
      int old_sector = g_symbols[i].sector_id_from_ea1;
      string old_sector_source = g_symbols[i].sector_id_source;

      g_symbols[i].ea1_present = true;
      g_symbols[i].ea1_valid = true;
      g_symbols[i].raw_symbol = r1.raw_symbol;
      g_symbols[i].asset_class_from_ea1 = r1.asset_class;
      g_symbols[i].class_key_from_ea1 = r1.class_key;
      g_symbols[i].market_open_now_from_ea1 = r1.market_open_now;
      g_symbols[i].market_reason_code_from_ea1 = r1.reason_code;

      if(r1.has_sector_id)
      {
         g_symbols[i].sector_id_from_ea1 = r1.sector_id;
         g_symbols[i].sector_id_source = "EA1";
      }
      else
      {
         int bucket = SectorFromClassKey(r1.class_key);
         if(bucket != 99)
         {
            g_symbols[i].sector_id_from_ea1 = bucket;
            g_symbols[i].sector_id_source = "DERIVED_CLASS_KEY";
         }
         else
         {
            bucket = SectorFromAssetClass(r1.asset_class);
            if(bucket > 0)
            {
               g_symbols[i].sector_id_from_ea1 = bucket;
               g_symbols[i].sector_id_source = "DERIVED_ASSET_CLASS";
            }
            else
            {
               g_symbols[i].sector_id_from_ea1 = SectorHashBucket(r1.raw_symbol, r1.class_key, r1.asset_class);
               g_symbols[i].sector_id_source = "DERIVED_HASH";
            }
         }
      }
      g_symbols[i].symbol_identity_hash = BuildIdentityHash(g_symbols[i].raw_symbol, g_symbols[i].class_key_from_ea1, g_symbols[i].sector_id_from_ea1);

      g_symbols[i].ea2_present = false;
      g_symbols[i].ea2_valid = false;
      g_symbols[i].ready_m1_from_ea2 = false;
      g_symbols[i].ready_m5_from_ea2 = false;
      g_symbols[i].ready_m15_from_ea2 = false;
      g_symbols[i].ready_d1_from_ea2 = false;
      g_symbols[i].fresh_bits_from_ea2 = 0;
      g_symbols[i].atr_points_m1_from_ea2 = EMPTY_VALUE;
      g_symbols[i].atr_points_m5_from_ea2 = EMPTY_VALUE;
      g_symbols[i].atr_points_m15_from_ea2 = EMPTY_VALUE;
      g_symbols[i].volatility_accel_from_ea2 = EMPTY_VALUE;
      g_symbols[i].vol_expansion_from_ea2 = EMPTY_VALUE;
      g_symbols[i].spread_to_atr_m1_ratio_from_ea2 = EMPTY_VALUE;
      g_symbols[i].spread_to_atr_m5_ratio_from_ea2 = EMPTY_VALUE;

      if(g_cycle.ea2_valid)
      {
         int idx2 = FindEA2IndexBySymbol(g_symbols[i].raw_symbol);
         if(idx2 >= 0)
         {
            EA2SymbolRec r2 = g_ea2_last_good.symbols[idx2];
            g_symbols[i].ea2_present = true;
            g_symbols[i].ea2_valid = true;
            g_symbols[i].ready_m1_from_ea2 = r2.ready_m1;
            g_symbols[i].ready_m5_from_ea2 = r2.ready_m5;
            g_symbols[i].ready_m15_from_ea2 = r2.ready_m15;
            g_symbols[i].ready_d1_from_ea2 = r2.ready_d1;
            g_symbols[i].fresh_bits_from_ea2 = r2.fresh_bits;
            g_symbols[i].atr_points_m1_from_ea2 = r2.atr_points_m1;
            g_symbols[i].atr_points_m5_from_ea2 = r2.atr_points_m5;
            g_symbols[i].atr_points_m15_from_ea2 = r2.atr_points_m15;
            g_symbols[i].volatility_accel_from_ea2 = r2.volatility_accel;
            g_symbols[i].vol_expansion_from_ea2 = r2.vol_expansion;
            g_symbols[i].spread_to_atr_m1_ratio_from_ea2 = r2.spread_to_atr_m1_ratio;
            g_symbols[i].spread_to_atr_m5_ratio_from_ea2 = r2.spread_to_atr_m5_ratio;
         }
      }

      if(old_market_open != g_symbols[i].market_open_now_from_ea1 || old_reason != g_symbols[i].market_reason_code_from_ea1 ||
         old_fresh_bits != g_symbols[i].fresh_bits_from_ea2 || old_r1 != g_symbols[i].ready_m1_from_ea2 || old_r5 != g_symbols[i].ready_m5_from_ea2 ||
         old_r15 != g_symbols[i].ready_m15_from_ea2 || old_rd1 != g_symbols[i].ready_d1_from_ea2 || old_atr1 != g_symbols[i].atr_points_m1_from_ea2 ||
         old_atr5 != g_symbols[i].atr_points_m5_from_ea2 || old_atr15 != g_symbols[i].atr_points_m15_from_ea2 || old_va != g_symbols[i].volatility_accel_from_ea2 ||
         old_ve != g_symbols[i].vol_expansion_from_ea2 || old_s1 != g_symbols[i].spread_to_atr_m1_ratio_from_ea2 || old_s5 != g_symbols[i].spread_to_atr_m5_ratio_from_ea2 ||
         old_sector != g_symbols[i].sector_id_from_ea1 || old_sector_source != g_symbols[i].sector_id_source || g_policy_dirty)
         g_symbols[i].intelligence_dirty = true;
      else
         g_symbols[i].intelligence_dirty = dirty_before;

      g_symbols[i].sector_leader_rank = 0;
      g_symbols[i].basket_selected = false;
      g_symbols[i].correlation_pool_member = false;
   }
   g_policy_dirty = false;
   g_leaders_dirty = true;
   g_corr_dirty = true;
   g_basket_dirty = true;
   g_counts_dirty = true;
}

bool HasFreshBit(const int bits, const int mask_bit)
{
   return ((bits & mask_bit) == mask_bit);
}

double MeanOfRecent(const SymbolState &s, const int max_count, int &used)
{
   used = 0;
   double sum = 0.0;
   int take = MathMin(max_count, s.persist_ring_count);
   for(int i=0;i<take;i++)
   {
      int idx = (s.persist_ring_write_idx - 1 - i + PERSIST_RING_CAP) % PERSIST_RING_CAP;
      double v = s.persist_recent_i[idx];
      if(IsKnownNumber(v))
      {
         sum += v;
         used++;
      }
   }
   if(used <= 0) return EMPTY_VALUE;
   return sum / (double)used;
}

double StdDevOfRecent(const SymbolState &s, const int max_count, const double mean, int &used)
{
   used = 0;
   double sumsq = 0.0;
   int take = MathMin(max_count, s.persist_ring_count);
   for(int i=0;i<take;i++)
   {
      int idx = (s.persist_ring_write_idx - 1 - i + PERSIST_RING_CAP) % PERSIST_RING_CAP;
      double v = s.persist_recent_i[idx];
      if(IsKnownNumber(v))
      {
         double d = v - mean;
         sumsq += d * d;
         used++;
      }
   }
   if(used <= 1) return EMPTY_VALUE;
   return MathSqrt(sumsq / (double)used);
}

double SpreadThreshold(const string class_key, const string asset_class)
{
   string k = LowerTrim(class_key);
   if(k == "fx") return 0.25;
   if(k == "index") return 0.40;
   if(k == "crypto") return 0.80;
   string a = LowerTrim(asset_class);
   if(a == "1") return 0.25;
   if(a == "2") return 0.40;
   if(a == "5") return 0.80;
   return 0.35;
}

void NullEA2Dependent(SymbolState &s)
{
   s.precursor_index_s = EMPTY_VALUE;
   s.precursor_index_i = EMPTY_VALUE;
   s.precursor_index_h = EMPTY_VALUE;
   s.compression_ratio = EMPTY_VALUE;
   s.range_surprise_z = EMPTY_VALUE;
   s.persistence_ratio_5 = EMPTY_VALUE;
   s.micro_expansion_ratio = EMPTY_VALUE;
   s.candidate_eligible = false;
   s.candidate_score = EMPTY_VALUE;
   s.intraday_horizon_ok = false;
   s.overnight_risk_flag = true;
   s.max_horizon_class = HORIZON_NONE;
   s.precursor_status = PSTATUS_NONE;
}

void ComputeInputIntegrity(SymbolState &s)
{
   if(!s.ea1_present)
   {
      s.input_integrity_state = INTEGRITY_UPSTREAM_MISSING;
      return;
   }
   if(g_cycle.ea1_age_min > InpMaxUsableUpstreamAgeMin)
   {
      s.input_integrity_state = INTEGRITY_EA1_STALE;
      return;
   }
   if(!g_cycle.ea2_valid)
   {
      if(g_ea2_last_good.valid && g_ea1_last_good.valid && g_ea2_last_good.fingerprint != g_ea1_last_good.fingerprint)
         s.input_integrity_state = INTEGRITY_FINGERPRINT_MISMATCH;
      else
         s.input_integrity_state = INTEGRITY_EA1_ONLY;
      return;
   }
   if(g_cycle.ea2_age_min > InpMaxUsableUpstreamAgeMin)
   {
      s.input_integrity_state = INTEGRITY_EA2_STALE;
      return;
   }
   if(!s.ea2_present)
   {
      s.input_integrity_state = INTEGRITY_EA1_ONLY;
      return;
   }
   s.input_integrity_state = INTEGRITY_FULL;
}

void ComputeSymbolIntelligence(SymbolState &s)
{
   ComputeInputIntegrity(s);

   if(s.input_integrity_state != INTEGRITY_FULL)
   {
      if(s.input_integrity_state == INTEGRITY_EA1_ONLY || s.input_integrity_state == INTEGRITY_FINGERPRINT_MISMATCH || s.input_integrity_state == INTEGRITY_UPSTREAM_MISSING)
         NullEA2Dependent(s);
   }

   bool has_usable_ea2 = (s.ea2_present && s.ea2_valid && s.input_integrity_state != INTEGRITY_UPSTREAM_MISSING && s.input_integrity_state != INTEGRITY_FINGERPRINT_MISMATCH);

   if(!has_usable_ea2)
   {
      NullEA2Dependent(s);
      s.data_reason_code = IntegrityToString(s.input_integrity_state);
      s.publish_reason_code = "EA1_EMIT_ONLY";
      s.summary_state = "PARTIAL";
      s.last_compute_server_time = TimeCurrent();
      s.intelligence_dirty = false;
      return;
   }

   bool fresh_m1 = HasFreshBit(s.fresh_bits_from_ea2, 1);
   bool fresh_m5 = HasFreshBit(s.fresh_bits_from_ea2, 2);
   bool fresh_m15 = HasFreshBit(s.fresh_bits_from_ea2, 4);

   s.intraday_horizon_ok = false;
   if(s.input_integrity_state == INTEGRITY_FULL &&
      s.ready_m1_from_ea2 && s.ready_m5_from_ea2 && s.ready_m15_from_ea2 &&
      g_cycle.ea1_age_min <= InpMaxUsableUpstreamAgeMin && g_cycle.ea2_age_min <= InpMaxUsableUpstreamAgeMin)
   {
      if(s.market_open_now_from_ea1)
      {
         if(fresh_m1 && fresh_m5 && fresh_m15)
            s.intraday_horizon_ok = true;
      }
      else if(InpAllowClosedMarkets)
      {
         s.intraday_horizon_ok = true;
      }
   }

   int h_score = 0;
   if(s.ready_m1_from_ea2) h_score += 20;
   if(s.ready_m5_from_ea2) h_score += 20;
   if(s.ready_m15_from_ea2) h_score += 20;
   if(s.ready_d1_from_ea2) h_score += 10;
   if(fresh_m1) h_score += 10;
   if(fresh_m5) h_score += 10;
   if(fresh_m15) h_score += 10;
   if(!s.market_open_now_from_ea1 && !InpAllowClosedMarkets) h_score = MathMin(h_score, 60);
   s.precursor_index_h = (double)ClampInt(h_score, 0, 100);

   s.precursor_index_s = EMPTY_VALUE;
   double spread_sum = 0.0;
   int spread_count = 0;
   if(IsKnownNumber(s.spread_to_atr_m1_ratio_from_ea2))
   {
      spread_sum += ClampDouble(s.spread_to_atr_m1_ratio_from_ea2, 0.0, 1000.0);
      spread_count++;
   }
   if(IsKnownNumber(s.spread_to_atr_m5_ratio_from_ea2))
   {
      spread_sum += ClampDouble(s.spread_to_atr_m5_ratio_from_ea2, 0.0, 1000.0);
      spread_count++;
   }
   if(spread_count > 0)
   {
      double avg_ratio = spread_sum / (double)spread_count;
      double threshold = SpreadThreshold(s.class_key_from_ea1, s.asset_class_from_ea1);
      s.precursor_index_s = ClampDouble(100.0 * (1.0 - (avg_ratio / threshold)), 0.0, 100.0);
   }

   s.precursor_index_i = EMPTY_VALUE;
  if(IsKnownNumber(s.volatility_accel_from_ea2) && IsKnownNumber(s.vol_expansion_from_ea2))
   {
      double a = ClampDouble((s.volatility_accel_from_ea2 - 1.0) / 1.0, -1.0, 1.0);
      double e = ClampDouble((s.vol_expansion_from_ea2 - 1.0) / 1.0, -1.0, 1.0);
      s.precursor_index_i = ClampDouble(50.0 + 20.0*a + 20.0*e + 10.0*(a*e), 0.0, 100.0);
   }

   s.compression_ratio = EMPTY_VALUE;
   if(IsKnownNumber(s.atr_points_m1_from_ea2) && IsKnownNumber(s.atr_points_m5_from_ea2) &&
      s.atr_points_m1_from_ea2 > InpMeaningfulAtrFloor && s.atr_points_m5_from_ea2 > InpMeaningfulAtrFloor)
   {
      s.compression_ratio = s.atr_points_m1_from_ea2 / s.atr_points_m5_from_ea2;
   }

   s.micro_expansion_ratio = EMPTY_VALUE;
   if(IsKnownNumber(s.atr_points_m1_from_ea2) && IsKnownNumber(s.atr_points_m15_from_ea2) &&
      s.atr_points_m1_from_ea2 > InpMeaningfulAtrFloor && s.atr_points_m15_from_ea2 > InpMeaningfulAtrFloor)
   {
      s.micro_expansion_ratio = (s.atr_points_m1_from_ea2 * 15.0) / s.atr_points_m15_from_ea2;
   }

   s.persistence_ratio_5 = EMPTY_VALUE;
   s.range_surprise_z = EMPTY_VALUE;
   if(IsKnownNumber(s.precursor_index_i) && s.persistence_fresh)
   {
      int used = 0;
      double m5 = MeanOfRecent(s, 5, used);
      if(used >= 3 && IsKnownNumber(m5) && m5 >= 10.0)
         s.persistence_ratio_5 = s.precursor_index_i / m5;

      int used20 = 0;
      double m20 = MeanOfRecent(s, 20, used20);
      if(used20 >= 8 && IsKnownNumber(m20) && m20 >= 10.0)
      {
         int usedsd = 0;
         double sd20 = StdDevOfRecent(s, 20, m20, usedsd);
         if(usedsd >= 8 && IsKnownNumber(sd20) && sd20 >= 1.0)
            s.range_surprise_z = ClampDouble((s.precursor_index_i - m20) / sd20, -4.0, 4.0);
      }
   }

   if(!IsKnownNumber(s.precursor_index_i) || !IsKnownNumber(s.precursor_index_h))
      s.precursor_status = PSTATUS_NONE;
   else if(!s.intraday_horizon_ok)
      s.precursor_status = PSTATUS_BLOCKED;
   else if(s.precursor_index_h < 70.0)
      s.precursor_status = PSTATUS_WATCH;
   else if(IsKnownNumber(s.precursor_index_s) && s.precursor_index_s < 40.0)
      s.precursor_status = PSTATUS_WATCH;
   else if(s.precursor_index_i >= 70.0 && s.precursor_index_h >= 80.0 &&
           ((IsKnownNumber(s.range_surprise_z) && s.range_surprise_z >= 1.0) ||
            (IsKnownNumber(s.persistence_ratio_5) && s.persistence_ratio_5 >= 1.10)))
      s.precursor_status = PSTATUS_STRONG;
   else if(s.precursor_index_i >= 60.0 && s.precursor_index_h >= 70.0)
      s.precursor_status = PSTATUS_QUALIFIED;
   else
      s.precursor_status = PSTATUS_WATCH;

   s.max_horizon_class = HORIZON_NONE;
   if(s.ready_m1_from_ea2 && s.ready_m5_from_ea2)
      s.max_horizon_class = HORIZON_SCALP;
   if(s.intraday_horizon_ok && s.precursor_status >= PSTATUS_WATCH)
      s.max_horizon_class = HORIZON_INTRADAY;
   if(s.intraday_horizon_ok && s.ready_d1_from_ea2 && s.input_integrity_state == INTEGRITY_FULL && g_cycle.ea2_age_min <= 2)
      s.max_horizon_class = HORIZON_SWING;

   s.overnight_risk_flag = true;
   if(s.max_horizon_class == HORIZON_SWING && s.ready_d1_from_ea2 && s.input_integrity_state == INTEGRITY_FULL && s.persistence_fresh)
      s.overnight_risk_flag = false;

   bool prefilter = (IsKnownNumber(s.precursor_index_i) && s.precursor_index_i >= 50.0 &&
                     IsKnownNumber(s.precursor_index_h) && s.precursor_index_h >= 60.0);

   s.candidate_eligible = false;
   s.candidate_score = EMPTY_VALUE;
   if(s.intraday_horizon_ok &&
      (s.precursor_status == PSTATUS_QUALIFIED || s.precursor_status == PSTATUS_STRONG) &&
      s.input_integrity_state == INTEGRITY_FULL &&
      IsKnownNumber(s.atr_points_m1_from_ea2) && s.atr_points_m1_from_ea2 > InpMeaningfulAtrFloor &&
      IsKnownNumber(s.atr_points_m5_from_ea2) && s.atr_points_m5_from_ea2 > InpMeaningfulAtrFloor)
   {
      s.candidate_eligible = true;
      if(IsKnownNumber(s.precursor_index_s))
         s.candidate_score = 0.50 * s.precursor_index_i + 0.30 * s.precursor_index_s + 0.20 * s.precursor_index_h;
      else
         s.candidate_score = 0.60 * s.precursor_index_i + 0.40 * s.precursor_index_h;

      bool expansion_after_compression = (IsKnownNumber(s.compression_ratio) && IsKnownNumber(s.micro_expansion_ratio) && IsKnownNumber(s.precursor_index_i) &&
                                          s.compression_ratio < 0.85 && s.micro_expansion_ratio > 1.20 && s.precursor_index_i >= 55.0);
      if(expansion_after_compression)
         s.candidate_score += ClampDouble(InpExpansionAfterCompressionBoost, 0.0, 5.0);

      s.candidate_score = ClampDouble(s.candidate_score, 0.0, 100.0);
   }

   if(!prefilter)
      s.correlation_pool_member = false;

   s.data_reason_code = IntegrityToString(s.input_integrity_state);
   s.publish_reason_code = "READY";
   s.summary_state = (s.input_integrity_state == INTEGRITY_FULL ? "FULL" : "PARTIAL");
   s.last_compute_server_time = TimeCurrent();
   s.intelligence_dirty = false;
   s.persist_save_pending = true;
}

void RunPersistenceLoadBudget()
{
   long t0 = (long)(GetMicrosecondCount()/1000);
   if(g_symbol_count <= 0) return;
   int budget = MathMax(1, InpPersistenceLoadBudget);
   for(int step=0; step<budget && step<g_symbol_count; step++)
   {
      if(g_rr_load_cursor >= g_symbol_count) g_rr_load_cursor = 0;
      int idx = g_rr_load_cursor;
      g_rr_load_cursor++;

      if(g_symbols[idx].persist_loaded_attempted) continue;
      g_symbols[idx].persist_loaded_attempted = true;

      string rel = g_persist_dir_ea3 + g_symbols[idx].symbol_identity_hash + ".bin";
      int h = FileOpen(rel, FILE_READ | FILE_BIN | FILE_COMMON);
      if(h == INVALID_HANDLE)
      {
         g_symbols[idx].persistence_state = "MISSING";
         g_symbols[idx].persistence_loaded = false;
         g_symbols[idx].persistence_fresh = false;
         g_symbols[idx].restarted_clean = true;
         continue;
      }

      int schema = FileReadInteger(h, INT_VALUE);
      string engine = FileReadString(h);
      string raw_symbol = FileReadString(h);
      string id_hash = FileReadString(h);
      string fingerprint = FileReadString(h);
      long minute_id = (long)FileReadLong(h);
      datetime saved_at = (datetime)FileReadLong(h);
      int saved_status = FileReadInteger(h, INT_VALUE);
      double saved_score = FileReadDouble(h);
      int ring_count = FileReadInteger(h, INT_VALUE);
      int ring_write_idx = FileReadInteger(h, INT_VALUE);

      bool ok = true;
      if(schema != EA3_PERSIST_SCHEMA_VERSION) ok = false;
      if(engine != EA3_ENGINE_VERSION) ok = false;
      if(raw_symbol != g_symbols[idx].raw_symbol) ok = false;
      if(id_hash != g_symbols[idx].symbol_identity_hash) ok = false;
      if(fingerprint != g_cycle.ea1_fingerprint) ok = false;
      int age_sec = (int)(TimeCurrent() - saved_at);
      g_symbols[idx].persistence_age_sec = age_sec;
      if(age_sec > InpContinuityFreshnessMaxAgeSec) ok = false;

      if(ok)
      {
         g_symbols[idx].persist_ring_count = ClampInt(ring_count, 0, PERSIST_RING_CAP);
         g_symbols[idx].persist_ring_write_idx = ClampInt(ring_write_idx, 0, PERSIST_RING_CAP - 1);
         for(int i=0;i<PERSIST_RING_CAP;i++)
         {
            double v = FileReadDouble(h);
            if(v < 0.0) v = EMPTY_VALUE;
            g_symbols[idx].persist_recent_i[i] = v;
         }
         g_symbols[idx].persistence_loaded = true;
         g_symbols[idx].persistence_fresh = true;
         g_symbols[idx].persistence_stale = false;
         g_symbols[idx].persistence_corrupt = false;
         g_symbols[idx].persistence_incompatible = false;
         g_symbols[idx].resumed_from_persistence = true;
         g_symbols[idx].restarted_clean = false;
         g_symbols[idx].continuity_origin = "PERSISTENCE";
         g_symbols[idx].continuity_last_good_server_time = saved_at;
         g_symbols[idx].persistence_state = "LOADED";
      }
      else
      {
         g_symbols[idx].persistence_loaded = false;
         g_symbols[idx].persistence_fresh = false;
         g_symbols[idx].persistence_stale = (g_symbols[idx].persistence_age_sec > InpContinuityFreshnessMaxAgeSec);
         g_symbols[idx].persistence_corrupt = false;
         g_symbols[idx].persistence_incompatible = true;
         g_symbols[idx].resumed_from_persistence = false;
         g_symbols[idx].restarted_clean = true;
         g_symbols[idx].persistence_state = "DISCARDED";
         g_symbols[idx].persist_ring_count = 0;
         g_symbols[idx].persist_ring_write_idx = 0;
         for(int i=0;i<PERSIST_RING_CAP;i++) g_symbols[idx].persist_recent_i[i] = EMPTY_VALUE;
      }
      FileClose(h);
      g_symbols[idx].intelligence_dirty = true;
   }
   g_perf.dur_persist_load_ms = (int)((GetMicrosecondCount()/1000)-t0);
}

void AppendRecentI(SymbolState &s, const double value)
{
   if(!IsKnownNumber(value)) return;
   s.persist_recent_i[s.persist_ring_write_idx] = value;
   s.persist_ring_write_idx = (s.persist_ring_write_idx + 1) % PERSIST_RING_CAP;
   if(s.persist_ring_count < PERSIST_RING_CAP) s.persist_ring_count++;
   s.persistence_fresh = true;
   s.persistence_loaded = true;
   s.continuity_last_good_server_time = TimeCurrent();
   s.persistence_age_sec = 0;
   s.persist_save_pending = true;
}

void RunSymbolComputeBudget()
{
   long t0 = (long)(GetMicrosecondCount()/1000);
   if(g_symbol_count <= 0) return;
   int budget = MathMax(1, InpSymbolComputeBudget);
   for(int step=0; step<budget && step<g_symbol_count; step++)
   {
      if(g_rr_compute_cursor >= g_symbol_count) g_rr_compute_cursor = 0;
      int idx = g_rr_compute_cursor;
      g_rr_compute_cursor++;
      if(!g_symbols[idx].intelligence_dirty) continue;
      ComputeSymbolIntelligence(g_symbols[idx]);
      if(IsKnownNumber(g_symbols[idx].precursor_index_i))
         AppendRecentI(g_symbols[idx], g_symbols[idx].precursor_index_i);
      g_leaders_dirty = true;
      g_corr_dirty = true;
      g_basket_dirty = true;
      g_counts_dirty = true;
   }
   g_perf.dur_intelligence_ms = (int)((GetMicrosecondCount()/1000)-t0);
}

bool CandidateBetter(const int ia, const int ib)
{
   double sa = (IsKnownNumber(g_symbols[ia].candidate_score) ? g_symbols[ia].candidate_score : -1.0);
   double sb = (IsKnownNumber(g_symbols[ib].candidate_score) ? g_symbols[ib].candidate_score : -1.0);
   if(sa > sb) return true;
   if(sa < sb) return false;
   int pa = StatusStrength(g_symbols[ia].precursor_status);
   int pb = StatusStrength(g_symbols[ib].precursor_status);
   if(pa > pb) return true;
   if(pa < pb) return false;
   if(g_symbols[ia].symbol_index_from_ea1 < g_symbols[ib].symbol_index_from_ea1) return true;
   if(g_symbols[ia].symbol_index_from_ea1 > g_symbols[ib].symbol_index_from_ea1) return false;
   return (g_symbols[ia].raw_symbol < g_symbols[ib].raw_symbol);
}

void SortIndicesByCandidate(int &arr[])
{
   int n = ArraySize(arr);
   for(int i=1;i<n;i++)
   {
      int key = arr[i];
      int j = i - 1;
      while(j >= 0 && CandidateBetter(key, arr[j]))
      {
         arr[j+1] = arr[j];
         j--;
      }
      arr[j+1] = key;
   }
}

void BuildCandidatePoolAndLeaders()
{
   long t0 = (long)(GetMicrosecondCount()/1000);
   g_leader_count = 0;
   ArrayResize(g_leaders, 0);
   ArrayResize(g_candidate_pool, 0);
   g_candidate_pool_count = 0;

   int eligible_idx[];
   ArrayResize(eligible_idx, 0);
   for(int i=0;i<g_symbol_count;i++)
   {
      g_symbols[i].sector_leader_rank = 0;
      g_symbols[i].correlation_pool_member = false;
      if(g_symbols[i].candidate_eligible)
      {
         int n = ArraySize(eligible_idx);
         ArrayResize(eligible_idx, n+1);
         eligible_idx[n] = i;
      }
   }
   SortIndicesByCandidate(eligible_idx);

   int sector_ids[];
   int sector_counts[];
   ArrayResize(sector_ids, 0);
   ArrayResize(sector_counts, 0);

   for(int e=0;e<ArraySize(eligible_idx);e++)
   {
      int idx = eligible_idx[e];
      int sid = g_symbols[idx].sector_id_from_ea1;
      int pos = -1;
      for(int k=0;k<ArraySize(sector_ids);k++)
      {
         if(sector_ids[k] == sid) { pos = k; break; }
      }
      if(pos < 0)
      {
         int n = ArraySize(sector_ids);
         ArrayResize(sector_ids, n+1);
         ArrayResize(sector_counts, n+1);
         sector_ids[n] = sid;
         sector_counts[n] = 0;
         pos = n;
      }
      if(sector_counts[pos] < InpMaxLeadersPerSector)
      {
         sector_counts[pos]++;
         g_symbols[idx].sector_leader_rank = sector_counts[pos];
         int lc = g_leader_count;
         ArrayResize(g_leaders, lc + 1);
         g_leaders[lc].sector_id = sid;
         g_leaders[lc].symbol_index = idx;
         g_leaders[lc].leader_rank = sector_counts[pos];
         g_leaders[lc].leader_score = g_symbols[idx].candidate_score;
         g_leader_count++;
      }
   }

   int pool_per_sector[];
   ArrayResize(pool_per_sector, ArraySize(sector_ids));
   for(int i=0;i<ArraySize(pool_per_sector);i++) pool_per_sector[i] = 0;

   for(int pass=0; pass<2; pass++)
   {
      for(int e=0; e<ArraySize(eligible_idx) && g_candidate_pool_count < InpCandidatePoolCap && e < InpCandidatePoolBuildBudget; e++)
      {
         int idx = eligible_idx[e];
         int sid = g_symbols[idx].sector_id_from_ea1;
         int spos = -1;
         for(int k=0;k<ArraySize(sector_ids);k++) if(sector_ids[k] == sid) { spos = k; break; }
         if(spos < 0) continue;

         bool already = false;
         for(int j=0;j<g_candidate_pool_count;j++) if(g_candidate_pool[j] == idx) { already = true; break; }
         if(already) continue;

         if(pass == 0)
         {
            if(pool_per_sector[spos] == 0)
            {
               ArrayResize(g_candidate_pool, g_candidate_pool_count+1);
               g_candidate_pool[g_candidate_pool_count++] = idx;
               g_symbols[idx].correlation_pool_member = true;
               pool_per_sector[spos]++;
            }
         }
         else
         {
            if(pool_per_sector[spos] < 3)
            {
               ArrayResize(g_candidate_pool, g_candidate_pool_count+1);
               g_candidate_pool[g_candidate_pool_count++] = idx;
               g_symbols[idx].correlation_pool_member = true;
               pool_per_sector[spos]++;
            }
         }
      }
   }

   SortIndicesByCandidate(g_candidate_pool);
   g_leaders_dirty = false;
   g_perf.dur_correlation_ms = (int)((GetMicrosecondCount()/1000)-t0);
}

double SimilarityForPair(const SymbolState &a, const SymbolState &b, int &meaningful_dims)
{
   meaningful_dims = 0;
   double av[6];
   double bv[6];

   av[0] = (IsKnownNumber(a.precursor_index_s) ? a.precursor_index_s / 100.0 : 0.0);
   bv[0] = (IsKnownNumber(b.precursor_index_s) ? b.precursor_index_s / 100.0 : 0.0);
   if(IsKnownNumber(a.precursor_index_s) && IsKnownNumber(b.precursor_index_s)) meaningful_dims++;

   av[1] = (IsKnownNumber(a.precursor_index_i) ? a.precursor_index_i / 100.0 : 0.0);
   bv[1] = (IsKnownNumber(b.precursor_index_i) ? b.precursor_index_i / 100.0 : 0.0);
   if(IsKnownNumber(a.precursor_index_i) && IsKnownNumber(b.precursor_index_i)) meaningful_dims++;

   av[2] = (IsKnownNumber(a.precursor_index_h) ? a.precursor_index_h / 100.0 : 0.0);
   bv[2] = (IsKnownNumber(b.precursor_index_h) ? b.precursor_index_h / 100.0 : 0.0);
   if(IsKnownNumber(a.precursor_index_h) && IsKnownNumber(b.precursor_index_h)) meaningful_dims++;

   av[3] = (IsKnownNumber(a.compression_ratio) ? ClampDouble(a.compression_ratio, 0.0, 3.0) / 3.0 : 0.0);
   bv[3] = (IsKnownNumber(b.compression_ratio) ? ClampDouble(b.compression_ratio, 0.0, 3.0) / 3.0 : 0.0);
   if(IsKnownNumber(a.compression_ratio) && IsKnownNumber(b.compression_ratio)) meaningful_dims++;

   av[4] = (IsKnownNumber(a.micro_expansion_ratio) ? ClampDouble(a.micro_expansion_ratio, 0.0, 3.0) / 3.0 : 0.0);
   bv[4] = (IsKnownNumber(b.micro_expansion_ratio) ? ClampDouble(b.micro_expansion_ratio, 0.0, 3.0) / 3.0 : 0.0);
   if(IsKnownNumber(a.micro_expansion_ratio) && IsKnownNumber(b.micro_expansion_ratio)) meaningful_dims++;

   av[5] = (IsKnownNumber(a.range_surprise_z) ? ClampDouble(a.range_surprise_z, -4.0, 4.0) / 4.0 : 0.0);
   bv[5] = (IsKnownNumber(b.range_surprise_z) ? ClampDouble(b.range_surprise_z, -4.0, 4.0) / 4.0 : 0.0);
   if(IsKnownNumber(a.range_surprise_z) && IsKnownNumber(b.range_surprise_z)) meaningful_dims++;

   if(meaningful_dims < 3) return EMPTY_VALUE;

   double dot = 0.0, na = 0.0, nb = 0.0;
   for(int i=0;i<6;i++)
   {
      dot += av[i] * bv[i];
      na += av[i] * av[i];
      nb += bv[i] * bv[i];
   }
   if(na <= 0.0 || nb <= 0.0) return EMPTY_VALUE;
   return ClampDouble(dot / (MathSqrt(na) * MathSqrt(nb)), -1.0, 1.0);
}

bool PairBetter(const PairRow &a, const PairRow &b)
{
   if(a.similarity > b.similarity) return true;
   if(a.similarity < b.similarity) return false;
   string aa = g_symbols[a.a].raw_symbol;
   string ba = g_symbols[b.a].raw_symbol;
   if(aa < ba) return true;
   if(aa > ba) return false;
   return (g_symbols[a.b].raw_symbol < g_symbols[b.b].raw_symbol);
}

void SortPairs(PairRow &arr[])
{
   int n = ArraySize(arr);
   for(int i=1;i<n;i++)
   {
      PairRow key = arr[i];
      int j = i - 1;
      while(j >= 0 && PairBetter(key, arr[j]))
      {
         arr[j+1] = arr[j];
         j--;
      }
      arr[j+1] = key;
   }
}

double BasketSimilarityThreshold(const bool soft_retry)
{
   return (soft_retry ? InpSoftSimilarityThreshold : InpHardSimilarityThreshold);
}

bool TooSimilarToBasket(const int symbol_idx, const bool soft_retry)
{
   double threshold = BasketSimilarityThreshold(soft_retry);
   for(int i=0;i<g_basket_count;i++)
   {
      int other = g_basket[i].symbol_index;
      int meaningful = 0;
      double sim = SimilarityForPair(g_symbols[symbol_idx], g_symbols[other], meaningful);
      if(IsKnownNumber(sim) && sim >= threshold)
         return true;
   }
   return false;
}

void ComputeCorrelationPairs()
{
   long t0 = (long)(GetMicrosecondCount()/1000);
   g_pair_count = 0;
   ArrayResize(g_pairs, 0);

   int evals = 0;
   PairRow tmp_pairs[];
   ArrayResize(tmp_pairs, 0);

   for(int i=0;i<g_candidate_pool_count;i++)
   {
      for(int j=i+1;j<g_candidate_pool_count;j++)
      {
         if(evals >= InpCorrelationPairBudget) break;
         evals++;
         int a = g_candidate_pool[i];
         int b = g_candidate_pool[j];
         int meaningful = 0;
         double sim = SimilarityForPair(g_symbols[a], g_symbols[b], meaningful);
         if(!IsKnownNumber(sim)) continue;
         if(sim < InpHardSimilarityThreshold) continue;

         int n = ArraySize(tmp_pairs);
         ArrayResize(tmp_pairs, n+1);
         tmp_pairs[n].a = a;
         tmp_pairs[n].b = b;
         tmp_pairs[n].similarity = sim;
         tmp_pairs[n].same_sector = (g_symbols[a].sector_id_from_ea1 == g_symbols[b].sector_id_from_ea1);
      }
      if(evals >= InpCorrelationPairBudget) break;
   }

   SortPairs(tmp_pairs);
   int keep = MathMin(ArraySize(tmp_pairs), InpCorrelationPairsCap);
   ArrayResize(g_pairs, keep);
   for(int i=0;i<keep;i++) g_pairs[i] = tmp_pairs[i];
   g_pair_count = keep;
   g_corr_dirty = false;
   g_perf.dur_correlation_ms = (int)((GetMicrosecondCount()/1000)-t0);
}

void BuildDiverseBasket()
{
   long t0 = (long)(GetMicrosecondCount()/1000);
   for(int i=0;i<g_symbol_count;i++) g_symbols[i].basket_selected = false;
   g_basket_count = 0;
   ArrayResize(g_basket, 0);

   if(g_candidate_pool_count <= 0)
   {
      g_basket_dirty = false;
      g_perf.dur_basket_ms = (int)((GetMicrosecondCount()/1000)-t0);
      return;
   }

   int sector_used[];
   ArrayResize(sector_used, 0);

   for(int pass=0; pass<2; pass++)
   {
      bool soft_retry = (pass == 1);
      for(int i=0; i<g_candidate_pool_count && g_basket_count < InpMaxBasketSize; i++)
      {
         int idx = g_candidate_pool[i];
         if(!g_symbols[idx].candidate_eligible) continue;

         bool already = false;
         for(int b=0;b<g_basket_count;b++) if(g_basket[b].symbol_index == idx) { already = true; break; }
         if(already) continue;

         int sid = g_symbols[idx].sector_id_from_ea1;
         bool sector_seen = false;
         for(int k=0;k<ArraySize(sector_used);k++) if(sector_used[k] == sid) { sector_seen = true; break; }

         if(pass == 0 && sector_seen) continue;
         if(TooSimilarToBasket(idx, soft_retry)) continue;

         ArrayResize(g_basket, g_basket_count+1);
         g_basket[g_basket_count].symbol_index = idx;
         g_basket[g_basket_count].slot = g_basket_count + 1;
         g_basket_count++;
         g_symbols[idx].basket_selected = true;
         g_symbols[idx].basket_cooling_remaining = MathMax(g_symbols[idx].basket_cooling_remaining, InpBasketCoolingCycles);
         g_symbols[idx].last_basket_selected_cycle = g_cycle_counter;

         if(!sector_seen)
         {
            int n = ArraySize(sector_used);
            ArrayResize(sector_used, n+1);
            sector_used[n] = sid;
         }
      }
   }

   for(int i=0;i<g_symbol_count;i++)
   {
      if(!g_symbols[i].basket_selected && g_symbols[i].basket_cooling_remaining > 0)
         g_symbols[i].basket_cooling_remaining--;
   }

   g_basket_dirty = false;
   g_perf.dur_basket_ms = (int)((GetMicrosecondCount()/1000)-t0);
}

void RecountCoverage()
{
   g_cov_intraday_horizon_ok_count = 0;
   g_cov_overnight_risk_flag_count = 0;
   g_cov_candidates_count = 0;
   g_cov_sector_leaders_count = g_leader_count;
   g_cov_correlation_pairs_count = g_pair_count;
   g_cov_basket_selected_count = g_basket_count;

   g_hsum_none_count = 0;
   g_hsum_scalp_count = 0;
   g_hsum_intraday_count = 0;
   g_hsum_swing_count = 0;
   g_hsum_blocked_count = 0;
   g_hsum_watch_count = 0;
   g_hsum_qualified_count = 0;
   g_hsum_strong_count = 0;

   for(int i=0;i<g_symbol_count;i++)
   {
      SymbolState s = g_symbols[i];

      if(s.intraday_horizon_ok) g_cov_intraday_horizon_ok_count++;
      if(s.overnight_risk_flag) g_cov_overnight_risk_flag_count++;
      if(s.candidate_eligible) g_cov_candidates_count++;

      if(s.max_horizon_class == HORIZON_NONE) g_hsum_none_count++;
      else if(s.max_horizon_class == HORIZON_SCALP) g_hsum_scalp_count++;
      else if(s.max_horizon_class == HORIZON_INTRADAY) g_hsum_intraday_count++;
      else if(s.max_horizon_class == HORIZON_SWING) g_hsum_swing_count++;

      if(s.precursor_status == PSTATUS_BLOCKED) g_hsum_blocked_count++;
      else if(s.precursor_status == PSTATUS_WATCH) g_hsum_watch_count++;
      else if(s.precursor_status == PSTATUS_QUALIFIED) g_hsum_qualified_count++;
      else if(s.precursor_status == PSTATUS_STRONG) g_hsum_strong_count++;
   }
   g_counts_dirty = false;
}

string BuildStageJson()
{
   long t0 = (long)(GetMicrosecondCount()/1000);
   string s = "{";
   s += "\"producer\":\"EA3\",";
   s += "\"stage\":\"intelligence\",";
   s += "\"minute_id\":" + LongToStr64(g_cycle.ea1_minute_id) + ",";
   s += "\"universe_fingerprint\":" + JsonString(g_cycle.ea1_fingerprint) + ",";

   s += "\"coverage\":{";
   s += "\"intraday_horizon_ok_count\":" + IntegerToString(g_cov_intraday_horizon_ok_count) + ",";
   s += "\"overnight_risk_flag_count\":" + IntegerToString(g_cov_overnight_risk_flag_count) + ",";
   s += "\"candidates_count\":" + IntegerToString(g_cov_candidates_count) + ",";
   s += "\"sector_leaders_count\":" + IntegerToString(g_cov_sector_leaders_count) + ",";
   s += "\"correlation_pairs_count\":" + IntegerToString(g_cov_correlation_pairs_count) + ",";
   s += "\"basket_selected_count\":" + IntegerToString(g_cov_basket_selected_count);
   s += "},";

   s += "\"horizon_summary\":{";
   s += "\"none_count\":" + IntegerToString(g_hsum_none_count) + ",";
   s += "\"scalp_count\":" + IntegerToString(g_hsum_scalp_count) + ",";
   s += "\"intraday_count\":" + IntegerToString(g_hsum_intraday_count) + ",";
   s += "\"swing_count\":" + IntegerToString(g_hsum_swing_count) + ",";
   s += "\"blocked_count\":" + IntegerToString(g_hsum_blocked_count) + ",";
   s += "\"watch_count\":" + IntegerToString(g_hsum_watch_count) + ",";
   s += "\"qualified_count\":" + IntegerToString(g_hsum_qualified_count) + ",";
   s += "\"strong_count\":" + IntegerToString(g_hsum_strong_count);
   s += "},";

   s += "\"leaders_by_sector\":{";
   int sector_count = 0;
   int seen_sector_ids[];
   ArrayResize(seen_sector_ids, 0);
   for(int i=0;i<g_leader_count;i++)
   {
      bool seen=false;
      for(int j=0;j<ArraySize(seen_sector_ids);j++) if(seen_sector_ids[j] == g_leaders[i].sector_id) { seen=true; break; }
      if(!seen)
      {
         int n = ArraySize(seen_sector_ids);
         ArrayResize(seen_sector_ids, n+1);
         seen_sector_ids[n] = g_leaders[i].sector_id;
         sector_count++;
      }
   }
   s += "\"sector_count\":" + IntegerToString(sector_count) + ",";
   s += "\"sectors\":[";
   for(int ss=0; ss<ArraySize(seen_sector_ids); ss++)
   {
      if(ss > 0) s += ",";
      int sid = seen_sector_ids[ss];
      s += "{";
      s += "\"sector_id\":" + IntegerToString(sid) + ",";
      s += "\"leaders\":[";
      bool first = true;
      for(int i=0;i<g_leader_count;i++)
      {
         if(g_leaders[i].sector_id != sid) continue;
         int idx = g_leaders[i].symbol_index;
         if(!first) s += ",";
         first = false;
         s += "{";
         s += "\"raw_symbol\":" + JsonString(g_symbols[idx].raw_symbol) + ",";
         s += "\"leader_rank\":" + IntegerToString(g_leaders[i].leader_rank) + ",";
         s += "\"leader_score\":" + JsonDoubleOrNull(g_leaders[i].leader_score, 6) + ",";
         s += "\"precursor_status\":" + JsonString(PrecursorStatusToString(g_symbols[idx].precursor_status)) + ",";
         s += "\"intraday_horizon_ok\":" + JsonBool(g_symbols[idx].intraday_horizon_ok) + ",";
         s += "\"max_horizon_class\":" + JsonString(HorizonToString(g_symbols[idx].max_horizon_class));
         s += "}";
      }
      s += "]";
      s += "}";
   }
   s += "]";
   s += "},";

   s += "\"correlation_summary\":{";
   s += "\"basis\":\"bounded_feature_similarity\",";
   s += "\"candidate_pool_count\":" + IntegerToString(g_candidate_pool_count) + ",";
   s += "\"pair_count\":" + IntegerToString(g_pair_count) + ",";
   s += "\"similarity_threshold\":" + JsonDoubleOrNull(InpHardSimilarityThreshold, 6) + ",";
   s += "\"top_pairs\":[";
   for(int i=0;i<g_pair_count;i++)
   {
      if(i > 0) s += ",";
      s += "{";
      s += "\"raw_symbol_a\":" + JsonString(g_symbols[g_pairs[i].a].raw_symbol) + ",";
      s += "\"raw_symbol_b\":" + JsonString(g_symbols[g_pairs[i].b].raw_symbol) + ",";
      s += "\"similarity\":" + JsonDoubleOrNull(g_pairs[i].similarity, 6) + ",";
      s += "\"same_sector\":" + JsonBool(g_pairs[i].same_sector);
      s += "}";
   }
   s += "]";
   s += "},";

   s += "\"diverse_basket\":{";
   s += "\"enabled\":true,";
   s += "\"max_size\":" + IntegerToString(InpMaxBasketSize) + ",";
   s += "\"selected_count\":" + IntegerToString(g_basket_count) + ",";
   s += "\"symbols\":[";
   for(int i=0;i<g_basket_count;i++)
   {
      int idx = g_basket[i].symbol_index;
      if(i > 0) s += ",";
      s += "{";
      s += "\"slot\":" + IntegerToString(g_basket[i].slot) + ",";
      s += "\"raw_symbol\":" + JsonString(g_symbols[idx].raw_symbol) + ",";
      s += "\"sector_id\":" + IntegerToString(g_symbols[idx].sector_id_from_ea1) + ",";
      s += "\"selection_score\":" + JsonDoubleOrNull(g_symbols[idx].candidate_score, 6) + ",";
      s += "\"precursor_status\":" + JsonString(PrecursorStatusToString(g_symbols[idx].precursor_status)) + ",";
      s += "\"max_horizon_class\":" + JsonString(HorizonToString(g_symbols[idx].max_horizon_class));
      s += "}";
   }
   s += "]";
   s += "},";

   s += "\"symbols\":[";
   for(int i=0;i<g_symbol_count;i++)
   {
      SymbolState x = g_symbols[i];
      if(i > 0) s += ",";
      s += "{";
      s += "\"raw_symbol\":" + JsonString(x.raw_symbol) + ",";
      s += "\"horizon\":{";
      s += "\"intraday_horizon_ok\":" + JsonBool(x.intraday_horizon_ok) + ",";
      s += "\"overnight_risk_flag\":" + JsonBool(x.overnight_risk_flag) + ",";
      s += "\"max_horizon_class\":" + JsonString(HorizonToString(x.max_horizon_class));
      s += "},";
      s += "\"impulse_stats\":{";
      s += "\"precursor_status\":" + JsonString(PrecursorStatusToString(x.precursor_status)) + ",";
      s += "\"precursor_index_s\":" + JsonDoubleOrNull(x.precursor_index_s, 6) + ",";
      s += "\"precursor_index_i\":" + JsonDoubleOrNull(x.precursor_index_i, 6) + ",";
      s += "\"precursor_index_h\":" + JsonDoubleOrNull(x.precursor_index_h, 6) + ",";
      s += "\"compression_ratio\":" + JsonDoubleOrNull(x.compression_ratio, 6) + ",";
      s += "\"range_surprise_z\":" + JsonDoubleOrNull(x.range_surprise_z, 6) + ",";
      s += "\"persistence_ratio_5\":" + JsonDoubleOrNull(x.persistence_ratio_5, 6) + ",";
      s += "\"micro_expansion_ratio\":" + JsonDoubleOrNull(x.micro_expansion_ratio, 6);
      s += "}";
      s += "}";
   }
   s += "]";
   s += "}";
   g_perf.dur_build_ms = (int)((GetMicrosecondCount()/1000)-t0);
   return s;
}

double WorstnessScore(const SymbolState &s)
{
   double score = 0.0;
   if(s.input_integrity_state != INTEGRITY_FULL) score += 50.0;
   if(!s.ea2_present) score += 20.0;
   if(s.precursor_status == PSTATUS_NONE) score += 10.0;
   if(!s.intraday_horizon_ok) score += 5.0;
   if(s.persistence_corrupt || s.persistence_incompatible) score += 15.0;
   return score;
}

void SortWorstIndices(int &arr[])
{
   int n = ArraySize(arr);
   for(int i=1;i<n;i++)
   {
      int key = arr[i];
      int j = i - 1;
      while(j >= 0)
      {
         double sk = WorstnessScore(g_symbols[key]);
         double sj = WorstnessScore(g_symbols[arr[j]]);
         if(sk > sj) { arr[j+1] = arr[j]; j--; continue; }
         if(sk < sj) break;
         if(g_symbols[key].symbol_index_from_ea1 < g_symbols[arr[j]].symbol_index_from_ea1) { arr[j+1] = arr[j]; j--; continue; }
         break;
      }
      arr[j+1] = key;
   }
}

string BuildDebugJson()
{
   string s = "{";
   s += "\"producer\":\"EA3\",";
   s += "\"stage\":\"debug\",";
   s += "\"minute_id\":" + LongToStr64(g_cycle.ea1_minute_id) + ",";

   s += "\"timing\":{";
   s += "\"dur_total_ms\":" + IntegerToString(g_perf.dur_total_ms) + ",";
   s += "\"dur_read_ea1_ms\":" + IntegerToString(g_perf.dur_read_ea1_ms) + ",";
   s += "\"dur_validate_ea1_ms\":" + IntegerToString(g_perf.dur_validate_ea1_ms) + ",";
   s += "\"dur_parse_ea1_ms\":" + IntegerToString(g_perf.dur_parse_ea1_ms) + ",";
   s += "\"dur_read_ea2_ms\":" + IntegerToString(g_perf.dur_read_ea2_ms) + ",";
   s += "\"dur_validate_ea2_ms\":" + IntegerToString(g_perf.dur_validate_ea2_ms) + ",";
   s += "\"dur_parse_ea2_ms\":" + IntegerToString(g_perf.dur_parse_ea2_ms) + ",";
   s += "\"dur_intelligence_ms\":" + IntegerToString(g_perf.dur_intelligence_ms) + ",";
   s += "\"dur_correlation_ms\":" + IntegerToString(g_perf.dur_correlation_ms) + ",";
   s += "\"dur_basket_ms\":" + IntegerToString(g_perf.dur_basket_ms) + ",";
   s += "\"dur_build_ms\":" + IntegerToString(g_perf.dur_build_ms) + ",";
   s += "\"dur_write_tmp_ms\":" + IntegerToString(g_perf.dur_write_tmp_ms) + ",";
   s += "\"dur_commit_ms\":" + IntegerToString(g_perf.dur_commit_ms) + ",";
   s += "\"dur_backup_ms\":" + IntegerToString(g_perf.dur_backup_ms) + ",";
   s += "\"dur_persistence_load_ms\":" + IntegerToString(g_perf.dur_persist_load_ms) + ",";
   s += "\"dur_persistence_save_ms\":" + IntegerToString(g_perf.dur_persist_save_ms);
   s += "},";

   s += "\"schedules\":{";
   s += "\"engine_state\":" + JsonString(EngineStateToString(g_engine_state)) + ",";
   s += "\"timer_tick_count\":" + IntegerToString(g_timer_tick_count) + ",";
   s += "\"overrun_count\":" + IntegerToString(g_overrun_count) + ",";
   s += "\"cycle_skip_count\":" + IntegerToString(g_cycle_skip_count) + ",";
   s += "\"engine_clock_drift_ms\":" + IntegerToString(g_engine_clock_drift_ms) + ",";
   s += "\"cycle_counter\":" + IntegerToString(g_cycle_counter) + ",";
   s += "\"write_backoff_until\":" + LongToStr64((long)g_write_backoff_until);
   s += "},";

   s += "\"paths\":{";
   s += "\"firm_id\":" + JsonString(g_firm_id) + ",";
   s += "\"ea1_current\":" + JsonString(g_ea1_current_file) + ",";
   s += "\"ea1_previous\":" + JsonString(g_ea1_prev_file) + ",";
   s += "\"ea2_current\":" + JsonString(g_ea2_current_file) + ",";
   s += "\"ea2_previous\":" + JsonString(g_ea2_prev_file) + ",";
   s += "\"stage_file\":" + JsonString(g_stage_file) + ",";
   s += "\"debug_file\":" + JsonString(g_debug_file) + ",";
   s += "\"tmp_dir\":" + JsonString(g_tmp_dir_ea3) + ",";
   s += "\"persistence_dir\":" + JsonString(g_persist_dir_ea3);
   s += "},";

   s += "\"upstream\":{";
   s += "\"ea1_source_used\":" + JsonString(SourceToString(g_cycle.ea1_source_used)) + ",";
   s += "\"ea2_source_used\":" + JsonString(SourceToString(g_cycle.ea2_source_used)) + ",";
   s += "\"ea1_current_valid\":" + JsonBool(g_ea1_last_good.current_valid) + ",";
   s += "\"ea1_prev_valid\":" + JsonBool(g_ea1_last_good.prev_valid) + ",";
   s += "\"ea1_last_good_applied\":" + JsonBool(g_ea1_last_good.last_good_applied) + ",";
   s += "\"ea2_current_valid\":" + JsonBool(g_ea2_last_good.current_valid) + ",";
   s += "\"ea2_prev_valid\":" + JsonBool(g_ea2_last_good.prev_valid) + ",";
   s += "\"ea2_last_good_applied\":" + JsonBool(g_ea2_last_good.last_good_applied) + ",";
   s += "\"ea1_minute_id\":" + LongToStr64(g_cycle.ea1_minute_id) + ",";
   s += "\"ea2_minute_id\":" + LongToStr64(g_cycle.ea2_minute_id) + ",";
   s += "\"ea1_age_min\":" + IntegerToString(g_cycle.ea1_age_min) + ",";
   s += "\"ea2_age_min\":" + IntegerToString(g_cycle.ea2_age_min) + ",";
   s += "\"ea2_lag_minutes\":" + IntegerToString(g_cycle.ea2_lag_minutes) + ",";
   s += "\"fingerprint_match\":" + JsonBool(g_cycle.fingerprint_match) + ",";
   s += "\"ea1_fingerprint\":" + JsonString(g_cycle.ea1_fingerprint) + ",";
   s += "\"ea2_fingerprint\":" + JsonString(g_cycle.ea2_fingerprint);
   s += "},";

   s += "\"io_last\":{";
   s += "\"write_failure_streak\":" + IntegerToString(g_write_failure_streak) + ",";
   s += "\"last_stage_hash\":" + JsonString(StringFormat("%08X", (uint)g_last_stage_payload_hash)) + ",";
   s += "\"last_debug_hash\":" + JsonString(StringFormat("%08X", (uint)g_last_debug_payload_hash));
   s += "},";

   s += "\"io_counters\":{";
   s += "\"stage_write_ok\":" + IntegerToString(g_io.stage_write_ok) + ",";
   s += "\"stage_write_fail\":" + IntegerToString(g_io.stage_write_fail) + ",";
   s += "\"debug_write_ok\":" + IntegerToString(g_io.debug_write_ok) + ",";
   s += "\"debug_write_fail\":" + IntegerToString(g_io.debug_write_fail) + ",";
   s += "\"backup_ok\":" + IntegerToString(g_io.backup_ok) + ",";
   s += "\"backup_fail\":" + IntegerToString(g_io.backup_fail) + ",";
   s += "\"skipped_same_payload\":" + IntegerToString(g_io.skipped_same_payload) + ",";
   s += "\"read_ea1_attempts\":" + IntegerToString(g_io.read_ea1_attempts) + ",";
   s += "\"read_ea2_attempts\":" + IntegerToString(g_io.read_ea2_attempts) + ",";
   s += "\"read_ea1_accepts\":" + IntegerToString(g_io.read_ea1_accepts) + ",";
   s += "\"read_ea2_accepts\":" + IntegerToString(g_io.read_ea2_accepts) + ",";
   s += "\"read_ea1_rejects\":" + IntegerToString(g_io.read_ea1_rejects) + ",";
   s += "\"read_ea2_rejects\":" + IntegerToString(g_io.read_ea2_rejects);
   s += "},";

   s += "\"perf\":{";
   s += "\"symbol_count\":" + IntegerToString(g_symbol_count) + ",";
   s += "\"candidate_pool_count\":" + IntegerToString(g_candidate_pool_count) + ",";
   s += "\"leader_count\":" + IntegerToString(g_leader_count) + ",";
   s += "\"pair_count\":" + IntegerToString(g_pair_count) + ",";
   s += "\"basket_count\":" + IntegerToString(g_basket_count);
   s += "},";

   s += "\"publish\":{";
   s += "\"stage_file\":" + JsonString(g_stage_file) + ",";
   s += "\"debug_file\":" + JsonString(g_debug_file) + ",";
   s += "\"stage_last_publish_time\":" + LongToStr64((long)g_last_publish_time) + ",";
   s += "\"debug_last_publish_time\":" + LongToStr64((long)g_last_debug_time);
   s += "},";

   s += "\"coverage\":{";
   s += "\"intraday_horizon_ok_count\":" + IntegerToString(g_cov_intraday_horizon_ok_count) + ",";
   s += "\"overnight_risk_flag_count\":" + IntegerToString(g_cov_overnight_risk_flag_count) + ",";
   s += "\"candidates_count\":" + IntegerToString(g_cov_candidates_count) + ",";
   s += "\"sector_leaders_count\":" + IntegerToString(g_cov_sector_leaders_count) + ",";
   s += "\"correlation_pairs_count\":" + IntegerToString(g_cov_correlation_pairs_count) + ",";
   s += "\"basket_selected_count\":" + IntegerToString(g_cov_basket_selected_count);
   s += "},";

   int loaded_count=0, stale_count=0, incompatible_count=0;
   for(int i=0;i<g_symbol_count;i++)
   {
      if(g_symbols[i].persistence_loaded) loaded_count++;
      if(g_symbols[i].persistence_stale) stale_count++;
      if(g_symbols[i].persistence_incompatible) incompatible_count++;
   }

   s += "\"continuity\":{";
   s += "\"loaded_count\":" + IntegerToString(loaded_count) + ",";
   s += "\"stale_count\":" + IntegerToString(stale_count) + ",";
   s += "\"incompatible_count\":" + IntegerToString(incompatible_count);
   s += "},";

   s += "\"recent_events\":[";
   for(int i=0;i<g_event_count;i++)
   {
      if(i > 0) s += ",";
      s += "{";
      s += "\"ts\":" + LongToStr64((long)g_events[i].ts) + ",";
      s += "\"msg\":" + JsonString(g_events[i].msg);
      s += "}";
   }
   s += "],";

   int worst_idx[];
   ArrayResize(worst_idx, g_symbol_count);
   for(int i=0;i<g_symbol_count;i++) worst_idx[i] = i;
   SortWorstIndices(worst_idx);
   int worst_keep = MathMin(g_symbol_count, MAX_WORST_SYMBOLS);

   s += "\"worst_symbols\":[";
   for(int i=0;i<worst_keep;i++)
   {
      int idx = worst_idx[i];
      if(i > 0) s += ",";
      s += "{";
      s += "\"raw_symbol\":" + JsonString(g_symbols[idx].raw_symbol) + ",";
      s += "\"input_integrity_state\":" + JsonString(IntegrityToString(g_symbols[idx].input_integrity_state)) + ",";
      s += "\"publish_reason_code\":" + JsonString(g_symbols[idx].publish_reason_code) + ",";
      s += "\"sector_id_source\":" + JsonString(g_symbols[idx].sector_id_source);
      s += "}";
   }
   s += "],";

   s += "\"engine_counts\":{";
   s += "\"symbols\":" + IntegerToString(g_symbol_count) + ",";
   s += "\"leaders\":" + IntegerToString(g_leader_count) + ",";
   s += "\"pairs\":" + IntegerToString(g_pair_count) + ",";
   s += "\"basket\":" + IntegerToString(g_basket_count);
   s += "},";

   s += "\"failure_counts\":{";
   s += "\"write_failure_streak\":" + IntegerToString(g_write_failure_streak) + ",";
   s += "\"overrun_count\":" + IntegerToString(g_overrun_count);
   s += "},";

   s += "\"success_counts\":{";
   s += "\"read_ea1_accepts\":" + IntegerToString(g_io.read_ea1_accepts) + ",";
   s += "\"read_ea2_accepts\":" + IntegerToString(g_io.read_ea2_accepts) + ",";
   s += "\"stage_write_ok\":" + IntegerToString(g_io.stage_write_ok) + ",";
   s += "\"debug_write_ok\":" + IntegerToString(g_io.debug_write_ok);
   s += "},";

   s += "\"subsystem_status\":{";
   s += "\"engine_state\":" + JsonString(EngineStateToString(g_engine_state)) + ",";
   s += "\"have_cycle\":" + JsonBool(g_have_cycle) + ",";
   s += "\"leaders_dirty\":" + JsonBool(g_leaders_dirty) + ",";
   s += "\"corr_dirty\":" + JsonBool(g_corr_dirty) + ",";
   s += "\"basket_dirty\":" + JsonBool(g_basket_dirty);
   s += "},";

   s += "\"correlation_diagnostics\":[";
   int corr_keep = MathMin(g_pair_count, MAX_CORR_DIAG);
   for(int i=0;i<corr_keep;i++)
   {
      if(i > 0) s += ",";
      s += "{";
      s += "\"raw_symbol_a\":" + JsonString(g_symbols[g_pairs[i].a].raw_symbol) + ",";
      s += "\"raw_symbol_b\":" + JsonString(g_symbols[g_pairs[i].b].raw_symbol) + ",";
      s += "\"similarity\":" + JsonDoubleOrNull(g_pairs[i].similarity, 6);
      s += "}";
   }
   s += "],";

   s += "\"basket_diagnostics\":[";
   for(int i=0;i<g_basket_count;i++)
   {
      int idx = g_basket[i].symbol_index;
      if(i > 0) s += ",";
      s += "{";
      s += "\"slot\":" + IntegerToString(g_basket[i].slot) + ",";
      s += "\"raw_symbol\":" + JsonString(g_symbols[idx].raw_symbol) + ",";
      s += "\"selection_score\":" + JsonDoubleOrNull(g_symbols[idx].candidate_score, 6) + ",";
      s += "\"sector_id\":" + IntegerToString(g_symbols[idx].sector_id_from_ea1);
      s += "}";
   }
   s += "],";

   s += "\"candidate_samples\":[";
   int cand_keep = MathMin(g_candidate_pool_count, MAX_CANDIDATE_SAMPLES);
   for(int i=0;i<cand_keep;i++)
   {
      int idx = g_candidate_pool[i];
      if(i > 0) s += ",";
      s += "{";
      s += "\"raw_symbol\":" + JsonString(g_symbols[idx].raw_symbol) + ",";
      s += "\"candidate_score\":" + JsonDoubleOrNull(g_symbols[idx].candidate_score, 6) + ",";
      s += "\"precursor_status\":" + JsonString(PrecursorStatusToString(g_symbols[idx].precursor_status)) + ",";
      s += "\"sector_id_source\":" + JsonString(g_symbols[idx].sector_id_source);
      s += "}";
   }
   s += "],";

   s += "\"diagnostic_samples\":[";
   int diag_keep = MathMin(g_symbol_count, MAX_DIAGNOSTIC_SAMPLES);
   for(int i=0;i<diag_keep;i++)
   {
      if(i > 0) s += ",";
      s += "{";
      s += "\"raw_symbol\":" + JsonString(g_symbols[i].raw_symbol) + ",";
      s += "\"input_integrity_state\":" + JsonString(IntegrityToString(g_symbols[i].input_integrity_state)) + ",";
      s += "\"sector_id\":" + IntegerToString(g_symbols[i].sector_id_from_ea1) + ",";
      s += "\"sector_id_source\":" + JsonString(g_symbols[i].sector_id_source) + ",";
      s += "\"persistence_state\":" + JsonString(g_symbols[i].persistence_state);
      s += "}";
   }
   s += "],";

   s += "\"legends\":{";
   s += "\"sector_id_source\":[\"EA1\",\"DERIVED_CLASS_KEY\",\"DERIVED_ASSET_CLASS\",\"DERIVED_HASH\"],";
   s += "\"input_integrity_state\":[\"FULL\",\"EA1_ONLY\",\"EA1_STALE\",\"EA2_STALE\",\"FINGERPRINT_MISMATCH\",\"UPSTREAM_MISSING\"]";
   s += "}";

   s += "}";
   return s;
}

bool MaybeWritePayload(const string final_rel, const string prev_rel, const string backup_rel, const string payload, bool is_debug)
{
   if(TimeCurrent() < g_write_backoff_until)
      return false;

   uint h = FNV1a32(payload);
   if((!is_debug && h == g_last_stage_payload_hash) || (is_debug && h == g_last_debug_payload_hash))
   {
      g_io.skipped_same_payload++;
      return true;
   }

   long minute_id = (g_have_cycle && g_cycle.ea1_minute_id > 0 ? g_cycle.ea1_minute_id : GetMinuteId());
   int seq = (is_debug ? (++g_debug_write_seq) : (++g_write_seq));
   string final_name = (is_debug ? (g_firm_id + "_debug_ea3.json") : (g_firm_id + "_intelligence.json"));
   string tmp_rel = BuildTempFileName(g_tmp_dir_ea3, final_name, minute_id, seq);

   int bytes_written = 0;
   long t0 = (long)(GetMicrosecondCount()/1000);
   bool ok = WriteTextFileCommon(tmp_rel, payload, bytes_written);
   g_perf.dur_write_tmp_ms = (int)((GetMicrosecondCount()/1000)-t0);
   if(!ok)
   {
      g_write_failure_streak++;
      g_write_backoff_until = TimeCurrent() + 10;
      if(is_debug) g_io.debug_write_fail++; else g_io.stage_write_fail++;
      AddEvent("Write tmp failed: " + final_name);
      return false;
   }

   BestEffortPreservePrevious(final_rel, prev_rel);

   t0 = (long)(GetMicrosecondCount()/1000);
   ok = CommitFileAtomic(tmp_rel, final_rel);
   g_perf.dur_commit_ms = (int)((GetMicrosecondCount()/1000)-t0);
   if(!ok)
   {
      g_write_failure_streak++;
      g_write_backoff_until = TimeCurrent() + 10;
      if(is_debug) g_io.debug_write_fail++; else g_io.stage_write_fail++;
      AddEvent("Commit failed: " + final_name);
      return false;
   }

   t0 = (long)(GetMicrosecondCount()/1000);
   bool bak = BestEffortBackup(final_rel, backup_rel);
   g_perf.dur_backup_ms = (int)((GetMicrosecondCount()/1000)-t0);
   if(bak) g_io.backup_ok++;
   else g_io.backup_fail++;

   g_write_failure_streak = 0;
   g_write_backoff_until = 0;
   if(is_debug)
   {
      g_last_debug_payload_hash = h;
      g_io.debug_write_ok++;
      g_last_debug_time = TimeCurrent();
   }
   else
   {
      g_last_stage_payload_hash = h;
      g_io.stage_write_ok++;
      g_last_publish_time = TimeCurrent();
   }
   return true;
}

void RunPersistenceSaveBudget()
{
   long t0 = (long)(GetMicrosecondCount()/1000);
   if(g_symbol_count <= 0) return;
   if((TimeCurrent() - g_last_persist_scan_time) < InpPersistenceSaveCadenceSec)
   {
      g_perf.dur_persist_save_ms = (int)((GetMicrosecondCount()/1000)-t0);
      return;
   }
   g_last_persist_scan_time = TimeCurrent();

   int budget = MathMax(1, InpPersistenceSaveBudget);
   for(int step=0; step<budget && step<g_symbol_count; step++)
   {
      if(g_rr_save_cursor >= g_symbol_count) g_rr_save_cursor = 0;
      int idx = g_rr_save_cursor;
      g_rr_save_cursor++;

      if(!g_symbols[idx].persist_save_pending) continue;
      if((TimeCurrent() - g_symbols[idx].last_persist_save_time) < InpPersistenceSaveCadenceSec) continue;
      string rel = g_persist_dir_ea3 + g_symbols[idx].symbol_identity_hash + ".bin";
      int h = FileOpen(rel, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(h == INVALID_HANDLE) continue;

      FileWriteInteger(h, EA3_PERSIST_SCHEMA_VERSION, INT_VALUE);
      FileWriteString(h, EA3_ENGINE_VERSION);
      FileWriteString(h, g_symbols[idx].raw_symbol);
      FileWriteString(h, g_symbols[idx].symbol_identity_hash);
      FileWriteString(h, g_cycle.ea1_fingerprint);
      FileWriteLong(h, g_cycle.ea1_minute_id);
      FileWriteLong(h, (long)TimeCurrent());
      FileWriteInteger(h, g_symbols[idx].precursor_status, INT_VALUE);
      FileWriteDouble(h, (IsKnownNumber(g_symbols[idx].candidate_score) ? g_symbols[idx].candidate_score : -1.0));
      FileWriteInteger(h, g_symbols[idx].persist_ring_count, INT_VALUE);
      FileWriteInteger(h, g_symbols[idx].persist_ring_write_idx, INT_VALUE);
      for(int i=0;i<PERSIST_RING_CAP;i++) FileWriteDouble(h, (IsKnownNumber(g_symbols[idx].persist_recent_i[i]) ? g_symbols[idx].persist_recent_i[i] : -1.0));
      FileClose(h);

      g_symbols[idx].last_persist_save_time = TimeCurrent();
      g_symbols[idx].persist_save_pending = false;
   }
   g_perf.dur_persist_save_ms = (int)((GetMicrosecondCount()/1000)-t0);
}

void MaybeCleanupTemp()
{
   if((TimeCurrent() - g_last_cleanup_time) < InpTempCleanupCadenceSec) return;
   g_last_cleanup_time = TimeCurrent();
}

bool IsPublishWindowOpen()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int sec = dt.sec;
   if(sec < InpPublishOffsetSec) return false;
   if(sec > InpPublishOffsetSec + InpPublishWindowSec) return false;
   return true;
}

void PublishIfDue()
{
   // Always write debug on cadence, even when upstream/cycle is missing.
   if((TimeCurrent() - g_last_debug_time) >= InpDebugCadenceSec || g_last_debug_time == 0)
   {
      string debug_json = BuildDebugJson();
      MaybeWritePayload(g_debug_file, g_debug_prev_file, g_debug_backup_file, debug_json, true);
   }

   // Stage file still requires a valid EA1 cycle and publish window.
   if(!g_have_cycle || !g_cycle.ea1_valid) return;
   if(!IsPublishWindowOpen()) return;

   if(g_counts_dirty) RecountCoverage();
   string stage_json = BuildStageJson();
   MaybeWritePayload(g_stage_file, g_stage_prev_file, g_stage_backup_file, stage_json, false);
}

void UpdateEngineState()
{
   if(!g_have_cycle || !g_cycle.ea1_valid)
      g_engine_state = ENGINE_UPSTREAM_WAIT;
   else if(!g_cycle.ea2_valid)
      g_engine_state = ENGINE_DEGRADED;
   else if(g_cycle.ea1_age_min > 2 || g_cycle.ea2_age_min > 2)
      g_engine_state = ENGINE_DEGRADED;
   else if(g_candidate_pool_count <= 0)
      g_engine_state = ENGINE_WARMUP;
   else
      g_engine_state = ENGINE_STEADY;
}

string BuildHudTopRows()
{
   string out = "";
   int shown = 0;

   for(int i=0; i<g_symbol_count && shown < InpHudTopRows; i++)
   {
      if(!g_symbols[i].candidate_eligible) continue;

      out += g_symbols[i].raw_symbol;
      out += " | ";
      out += PrecursorStatusToString(g_symbols[i].precursor_status);
      out += " | ";
      out += HorizonToString(g_symbols[i].max_horizon_class);
      out += " | score=";
      out += (IsKnownNumber(g_symbols[i].candidate_score) ? DoubleToString(g_symbols[i].candidate_score, 1) : "n/a");
      out += "\n";
      shown++;
   }

   if(out == "")
      out = "No eligible candidates yet\n";

   return out;
}

void RenderHUD()
{
   string hud = "";
   hud += EA3_NAME + " " + EA3_STAGE + "\n";
   hud += "Firm: " + g_firm_id + "\n";
   hud += "Engine: " + EngineStateToString(g_engine_state) + "\n";
   hud += "Cycle: " + IntegerToString(g_cycle_counter) + "\n";
   hud += "EA1 ok: " + (g_ea1_last_good.valid ? "1" : "0");
   hud += " | EA2 ok: " + (g_ea2_last_good.valid ? "1" : "0") + "\n";
   hud += "Have cycle: " + (g_have_cycle ? "1" : "0") + "\n";
   hud += "Symbols: " + IntegerToString(g_symbol_count);
   hud += " | Candidates: " + IntegerToString(g_cov_candidates_count) + "\n";
   hud += "Stage writes ok/fail: " + IntegerToString(g_io.stage_write_ok) + "/" + IntegerToString(g_io.stage_write_fail) + "\n";
   hud += "Debug writes ok/fail: " + IntegerToString(g_io.debug_write_ok) + "/" + IntegerToString(g_io.debug_write_fail) + "\n";
   hud += "Read EA1 ok/rej: " + IntegerToString(g_io.read_ea1_accepts) + "/" + IntegerToString(g_io.read_ea1_rejects) + "\n";
   hud += "Read EA2 ok/rej: " + IntegerToString(g_io.read_ea2_accepts) + "/" + IntegerToString(g_io.read_ea2_rejects) + "\n";
   hud += "Last stage: " + g_stage_file + "\n";
   hud += "Last debug: " + g_debug_file + "\n";
   hud += "Top rows:\n" + BuildHudTopRows();

   Comment(hud);
}

int OnInit()
{
   InitFirmFiles();
   ResetPerf();
   EventSetTimer(1);
   g_engine_state = ENGINE_INIT;
   AddEvent("EA3 initialized for firm " + g_firm_id);

   if(InpShowHUD)
      RenderHUD();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(InpShowHUD) Comment("");
}

void OnTick()
{
}

void OnTimer()
{
   if(g_engine_running)
   {
      g_overrun_count++;
      return;
   }

   g_engine_running = true;
   ulong cycle_start_ms = GetMicrosecondCount() / 1000;
   ResetPerf();
   g_timer_tick_count++;

   ulong now_us = GetMicrosecondCount();
   if(g_last_timer_us > 0)
   {
      long diff_ms = (long)((now_us - g_last_timer_us) / 1000);
      g_engine_clock_drift_ms = (int)(diff_ms - 1000);
      if(MathAbs(g_engine_clock_drift_ms) > 3000)
      {
         g_cycle_skip_count++;
         g_rr_compute_cursor = 0;
      }
   }
   g_last_timer_us = now_us;

   if(IsReadWindowNow())
   {
      AcceptEA1Snapshot();
      AcceptEA2Snapshot();
      if(g_ea1_last_good.valid)
      {
         FreezeCycleSnapshot();
         if(UniverseNeedsRebuild())
            RebuildUniverse();
         MergeAcceptedEAInputs();
      }
   }

   if(g_have_cycle)
   {
      RunPersistenceLoadBudget();
      RunSymbolComputeBudget();
      if(g_leaders_dirty) BuildCandidatePoolAndLeaders();
      if(g_corr_dirty) ComputeCorrelationPairs();
      if(g_basket_dirty) BuildDiverseBasket();
      if(g_counts_dirty) RecountCoverage();
      UpdateEngineState();
      PublishIfDue();
      RunPersistenceSaveBudget();
   }
   else
   {
      g_engine_state = ENGINE_UPSTREAM_WAIT;
   }

   g_cycle_counter++;
   g_perf.dur_total_ms = (int)((GetMicrosecondCount()/1000) - cycle_start_ms);
      if(InpShowHUD)
      RenderHUD();
   g_engine_running = false;
}
