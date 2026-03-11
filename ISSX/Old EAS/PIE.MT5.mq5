//+------------------------------------------------------------------+
//|                                                PIE.mq5           |
//|  PIE v4.3.0-LTS-JSON — Batch 1–4 (ONE SHOT)                      |
//|  Analytics-only. Deterministic. NO TRADING.                      |
//|                                                                  |
//|  Batch 1: Universe (deterministic) + fingerprint + mode detect    |
//|  Batch 2: Normalize + sector classification + counts + present    |
//|  Batch 3: Tick + Spec + Cost Truth (SymbolInfo cache + probes)    |
//|  Batch 4: Backfill + rolling ring buffers + deterministic backoff |
//|                                                                  |
//|  OUTPUTS (FILE_COMMON) — PLAIN JSON (UTF-8) + BACKUPS:           |
//|    - <firm>_<server>_<login>_rotation.json        (minute edge)   |
//|    - <firm>_<server>_<login>_rotation_backup.json (previous)      |
//|    - <firm>_<server>_<login>_universe.json        (30 min / cmd)  |
//|    - <firm>_<server>_<login>_universe_backup.json (previous)      |
//|    - <firm>_<server>_<login>_debug.json           (1 Hz heartbeat)|
//|    - <firm>_<server>_<login>_debug_backup.json    (minute edge)   |
//|                                                                  |
//|  HARD RULES:                                                     |
//|   - EventSetTimer(1) only. All logic in OnTimer.                 |
//|   - OnTick does nothing.                                         |
//|   - Publish JSON builders are cache-only: MUST NOT call           |
//|     CopyRates/OrderCalc*/SymbolInfo*/AccountInfo* inside builders |
//+------------------------------------------------------------------+
#property strict
#property description "PIE v4.3.0-LTS-JSON Batch 1–4 (UTF-8 JSON, deterministic, analytics-only)"
#property version   "4.300"
#define NAN EMPTY_VALUE
// ----------------------------
// Enums + minimal logging
// ----------------------------
enum DebugLevel { DBG_OFF=0, DBG_ERROR=1, DBG_WARN=2, DBG_INFO=3, DBG_TRACE=4 };
enum PieModule  { MODULE_TIMER=1, MODULE_DEBUG=2, MODULE_UNIVERSE=3, MODULE_IO=4, MODULE_SPEC=5, MODULE_TICK=6, MODULE_BACKFILL=7, MODULE_RANK=8 };

#define PIE_LOG_INFO(module, code, msg, a, b)  Print("[INFO] m=", (int)module, " c=", (int)code, " ", msg, " a=", a, " b=", b)
#define PIE_LOG_WARN(module, code, msg, a, b)  Print("[WARN] m=", (int)module, " c=", (int)code, " ", msg, " a=", a, " b=", b)
#define PIE_LOG_ERR(module, code, msg, a, b)   Print("[ERROR] m=", (int)module, " c=", (int)code, " ", msg, " a=", a, " b=", b)

// ----------------------------
// Inputs
// ----------------------------
input int    InpDebugLevel          = 3;
input bool   InpDbgHUD              = true;
input string InpCommandsFile        = "commands.txt";

// Universe inputs
input bool   InpOnlyMarketWatch     = false;
input int    InpUniverseMaxSymbols  = 0;   // 0=auto cap at 2000, else clamp 50..2000

// Batch 3 budgets (per second)
input int    InpTickBudgetPerSec    = 450; // LARGE clamp 250..450; SMALL/MED all-per-sec
input int    InpSpecBudgetPerSec    = 25;  // clamp 10..60
input int    InpProbeMinIntervalSec = 10;  // per symbol throttle for probes

// Batch 4 budgets (per second)
input int    InpBackfillBudgetPerSec= 6;   // clamp 3..10 (CopyRates heavy)

// Universe publish cadence
input int    InpUniverseWriteEverySec = 1800; // 30 minutes default

// Enable universe publish
input bool   InpEnableUniversePublish = true;

// ----------------------------
// Helpers
// ----------------------------
int PIE_ClampInt(const int v, const int lo, const int hi)
{
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

string PIE_SanitizeName(string s, const string fallback)
{
   StringTrimLeft(s); StringTrimRight(s);

   StringReplace(s, " ", "_");
   StringReplace(s, "/", "_");
   StringReplace(s, "\\", "_");
   StringReplace(s, "<", "_");
   StringReplace(s, ">", "_");
   StringReplace(s, ":", "_");
   StringReplace(s, "\"", "_");
   StringReplace(s, "|", "_");
   StringReplace(s, "?", "_");
   StringReplace(s, "*", "_");

   while(StringLen(s) > 0)
   {
      int last = (int)StringLen(s) - 1;
      ushort c = (ushort)StringGetCharacter(s, last);
      if(c == (ushort)'.' || c == (ushort)' ' || c == (ushort)'_')
         s = StringSubstr(s, 0, last);
      else
         break;
   }
   if(s == "") s = fallback;
   return s;
}

// minimal JSON escape for values
string PIE_JsonEscape(const string s)
{
   string out = "";
   const int n = (int)StringLen(s);
   for(int i=0;i<n;i++)
   {
      ushort c = (ushort)StringGetCharacter(s,i);
      if(c == 0)               { out += " ";    continue; }
      if(c == '\"')            { out += "\\\""; continue; }
      if(c == '\\')            { out += "\\\\"; continue; }
      if(c == '\n')            { out += "\\n";  continue; }
      if(c == '\r')            { out += "\\r";  continue; }
      if(c == '\t')            { out += "\\t";  continue; }
      if(c < 32)               { out += " ";    continue; }
      out += StringSubstr(s, i, 1);
   }
   return out;
}

// JSON guard (WARN-ONLY): validate outer braces, reject embedded NUL.
bool PIE_JsonGuardWarnOnly(const string fileName, const string json)
{
   const int L = (int)StringLen(json);
   if(L < 2)
   {
      if(InpDebugLevel>=DBG_WARN) Print("[WARN] JSON too short: ", fileName, " len=", L);
      return false;
   }

   for(int k=0;k<L;k++)
   {
      if((ushort)StringGetCharacter(json,k) == 0)
      {
         if(InpDebugLevel>=DBG_WARN) Print("[WARN] JSON contains NUL: ", fileName);
         return false;
      }
   }

   int i = 0;
   while(i < L)
   {
      ushort c = (ushort)StringGetCharacter(json, i);
      if(c > 32) break;
      i++;
   }
   if(i >= L || (ushort)StringGetCharacter(json, i) != (ushort)'{')
   {
      if(InpDebugLevel>=DBG_WARN) Print("[WARN] JSON does not start with '{': ", fileName);
      return false;
   }

   int j = L - 1;
   while(j >= 0)
   {
      ushort c = (ushort)StringGetCharacter(json, j);
      if(c > 32) break;
      j--;
   }
   if(j < 0 || (ushort)StringGetCharacter(json, j) != (ushort)'}')
   {
      if(InpDebugLevel>=DBG_WARN) Print("[WARN] JSON does not end with '}': ", fileName);
      return false;
   }

   return true;
}

// FNV-1a 32-bit hash for deterministic fingerprints
uint PIE_FNV1a32_Init() { return 2166136261u; }
uint PIE_FNV1a32_Update(uint h, const string s)
{
   const int n = (int)StringLen(s);
   for(int i=0;i<n;i++)
   {
      const ushort c = (ushort)StringGetCharacter(s,i);

      // low byte
      h ^= (uint)(c & 0x00FF);
      h *= 16777619u;

      // high byte
      h ^= (uint)((c >> 8) & 0x00FF);
      h *= 16777619u;
   }
   return h;
}
string PIE_U32ToHex(const uint v) { return StringFormat("%08X", (long)v); }

// deterministic float serialization (finite clamp, -0 normalize)
bool PIE_IsFinite(const double x)
{
   if(x == EMPTY_VALUE) return false;       // our NaN-sentinel
   if(x != x) return false;                 // real NaN (if it ever occurs)
   if(x > 1e12 || x < -1e12) return false;  // cap
   return true;
}
string PIE_JsonBool(const bool b) { return (b ? "true" : "false"); }

string PIE_JsonFloatOrNull(const double x, const int prec)
{
   if(!PIE_IsFinite(x)) return "null";
   double y = x;
   double tiny = 0.5 * MathPow(10.0, -prec);
   if(MathAbs(y) < tiny) y = 0.0;
   return DoubleToString(y, prec);
}

// ----------------------------
// Sectors (Batch 2)
// ----------------------------
enum PieSectorId
{
   PIE_SECTOR_FX_MAJOR=0,
   PIE_SECTOR_FX_CROSS=1,
   PIE_SECTOR_FX_EXOTIC=2,
   PIE_SECTOR_INDEX_US=3,
   PIE_SECTOR_INDEX_EU=4,
   PIE_SECTOR_INDEX_ASIA=5,
   PIE_SECTOR_METAL=6,
   PIE_SECTOR_ENERGY=7,
   PIE_SECTOR_CRYPTO=8,
   PIE_SECTOR_STOCK=9,
   PIE_SECTOR_OTHER=10
};
#define PIE_SECTOR_COUNT 11
static int  g_sector_counts[PIE_SECTOR_COUNT];
static int  g_sector_rule_version = 1;

string PIE_SectorName(const int sid)
{
   if(sid==PIE_SECTOR_FX_MAJOR)   return "FX_MAJOR";
   if(sid==PIE_SECTOR_FX_CROSS)   return "FX_CROSS";
   if(sid==PIE_SECTOR_FX_EXOTIC)  return "FX_EXOTIC";
   if(sid==PIE_SECTOR_INDEX_US)   return "INDEX_US";
   if(sid==PIE_SECTOR_INDEX_EU)   return "INDEX_EU";
   if(sid==PIE_SECTOR_INDEX_ASIA) return "INDEX_ASIA";
   if(sid==PIE_SECTOR_METAL)      return "METAL";
   if(sid==PIE_SECTOR_ENERGY)     return "ENERGY";
   if(sid==PIE_SECTOR_CRYPTO)     return "CRYPTO";
   if(sid==PIE_SECTOR_STOCK)      return "STOCK";
   return "OTHER";
}

string PIE_BuildSectorCountsJSON()
{
   string js = "{";
   for(int i=0;i<PIE_SECTOR_COUNT;i++)
   {
      if(i>0) js += ",";
      js += "\"" + PIE_SectorName(i) + "\":" + IntegerToString(g_sector_counts[i]);
   }
   js += "}";
   return js;
}

string PIE_BuildSectorPresentJSON()
{
   // array of sector names, enum order, only where count>0
   string js = "[";
   bool first = true;
   for(int i=0;i<PIE_SECTOR_COUNT;i++)
   {
      if(g_sector_counts[i] <= 0) continue;
      if(!first) js += ",";
      first = false;
      js += "\"" + PIE_SectorName(i) + "\"";
   }
   js += "]";
   return js;
}

// ----------------------------
// Stress + per-step diagnostics
// ----------------------------
struct StressCounters
{
   int      timer_tick_count;
   int      timer_slip_count;
   datetime last_timer_sec;

   int io_ok;
   int io_fail;
};
static StressCounters g_st;

struct StepDiag
{
   int processed;
   int ok_count;
   int fail_count;
   int skipped;
   int last_error;
};
static StepDiag g_diag_tick;
static StepDiag g_diag_spec;
static StepDiag g_diag_probe_vpp;
static StepDiag g_diag_probe_margin;

static StepDiag g_diag_bf_m1;
static StepDiag g_diag_bf_m5;
static StepDiag g_diag_bf_m15;
static StepDiag g_diag_bf_d1;

struct PublishDiag
{
   bool rotation_due;
   bool universe_due;
   bool rotation_attempted;
   bool universe_attempted;
   bool rotation_ok;
   bool universe_ok;
   bool debug_ok;
   bool debug_backup_ok;
   int  last_error_rotation;
   int  last_error_universe;
   int  last_error_debug;
   int  last_error_debug_backup;
};
static PublishDiag g_pub;

// IO last diagnostics (latest op)
struct IoLast
{
   string last_file;
   string last_op;
   int open_err;
   int write_err;
   int copy_err;
   int move_err;
   int delete_err;
   int bytes;
   long size;
};
static IoLast g_io_last;

// ----------------------------
// GLOBAL STATE
// ----------------------------
static long     g_last_publish_minute = -1;
static datetime g_last_cmd_poll_sec   = 0;

static string   g_broker_company      = "";
static string   g_broker_server       = "";
static string   g_account_currency    = "";
static long     g_account_login       = 0;

static string   g_terminal_name       = "";
static long     g_terminal_build      = 0;
static string   g_common_path         = "";

// Firm/server sanitized + prefix
static string   g_firm_s        = "";
static string   g_server_s      = "";
static string   g_prefix        = "";

// Filenames (JSON)
static string g_rotation_json         = "";
static string g_rotation_backup_json  = "";
static string g_universe_json         = "";
static string g_universe_backup_json  = "";
static string g_debug_json            = "";
static string g_debug_backup_json     = "";

// Universe
static string   g_symbols[];
static int      g_universe_n          = 0;
static int      g_universe_selected   = 0;
static uint     g_universe_fp         = 0;
static bool     g_universe_changed    = false;
static string   g_universe_first      = "";
static string   g_universe_last       = "";

// Mode
enum Mode { MODE_SMALL=0, MODE_MEDIUM=1, MODE_LARGE=2 };
static Mode g_mode = MODE_SMALL;
static int  g_active_target = 0;

// Snapshot triggers
static datetime g_last_universe_write_time = 0;
static bool     g_cmd_dump_universe = false;

// Step cursors (deterministic)
static int g_tick_cursor = 0;
static int g_spec_cursor = 0;

// Backfill cursors
enum PieTfId { TF_M1=0, TF_M5=1, TF_M15=2, TF_D1=3 };
static int g_bf_tf_turn = 0;
static int g_bf_cursor[4];

// ----------------------------
// Batch 4 ring buffers constants
// ----------------------------
#define PIE_M1_RING  90
#define PIE_M5_RING  90
#define PIE_M15_RING 90
#define PIE_D1_RING  60

#define PIE_M1_READY_MIN  20
#define PIE_M5_READY_MIN  14
#define PIE_M15_READY_MIN 14
#define PIE_D1_READY_MIN  14

// freshness bits
#define PIE_FRESH_M1  (1<<0)
#define PIE_FRESH_M5  (1<<1)
#define PIE_FRESH_M15 (1<<2)
#define PIE_FRESH_D1  (1<<3)

// ----------------------------
// Symbol State (Batch 1–4)
// ----------------------------
enum SpecQuality { SPEC_LOW=0, SPEC_MED=1, SPEC_HIGH=2 };

struct SymState
{
   // Identity
   string sym_raw;
   string sym_norm;
   int    sector_id;
   int    sector_rule_version;

   uint   spec_fingerprint;

   // Tick cache
   double   bid, ask, mid;
   double   point;
   int      digits;
   double   tick_size;
   datetime tick_time;
   int      tick_age_sec;
   double   spread_points;
   double   spread_ticks;
   bool     ready_tick;

   // Spec
   double contract_size;
   double vol_min, vol_max, vol_step;
   long   trade_mode;
   long   calc_mode;
   long   margin_mode;
   string profit_currency;
   string margin_currency;
   bool   ready_spec;

   // Probes (cost truth)
   double value_per_point_money; // NaN => null
   double value_per_tick_money;  // NaN => null
   double margin_1lot_money;     // NaN => null

   // Derived friction
   double spread_cost_money;     // NaN => null
   double total_friction_money;  // NaN => null
   double total_friction_points; // NaN => null

   // Quality
   int      spec_quality;
   int      spec_probe_ok_vpp;
   int      spec_probe_ok_margin;
   datetime spec_last_probe_time;

   // Batch 4 — Backfill scheduling + readiness + freshness
   datetime next_try_m1, next_try_m5, next_try_m15, next_try_d1;
   int      fail_m1, fail_m5, fail_m15, fail_d1;

   datetime last_bar_m1, last_bar_m5, last_bar_m15, last_bar_d1;
   int      bars_m1, bars_m5, bars_m15, bars_d1;

   bool     ready_m1, ready_m5, ready_m15, ready_d1;
   int      fresh_bits;

   // Batch 4 — Ring buffers (fixed size arrays)
   datetime m1_time[PIE_M1_RING];
   double   m1_open[PIE_M1_RING];
   double   m1_high[PIE_M1_RING];
   double   m1_low[PIE_M1_RING];
   double   m1_close[PIE_M1_RING];
   int      m1_head;
   int      m1_count;

   datetime m5_time[PIE_M5_RING];
   double   m5_open[PIE_M5_RING];
   double   m5_high[PIE_M5_RING];
   double   m5_low[PIE_M5_RING];
   double   m5_close[PIE_M5_RING];
   int      m5_head;
   int      m5_count;

   datetime m15_time[PIE_M15_RING];
   double   m15_open[PIE_M15_RING];
   double   m15_high[PIE_M15_RING];
   double   m15_low[PIE_M15_RING];
   double   m15_close[PIE_M15_RING];
   int      m15_head;
   int      m15_count;

   datetime d1_time[PIE_D1_RING];
   double   d1_open[PIE_D1_RING];
   double   d1_high[PIE_D1_RING];
   double   d1_low[PIE_D1_RING];
   double   d1_close[PIE_D1_RING];
   int      d1_head;
   int      d1_count;
};
static SymState g_states[];
static int g_spec_q_counts[3];

// ----------------------------
// Batch 2: Normalize + Sector Classification
// ----------------------------
bool PIE_IsUpperAZ(const ushort c) { return (c >= 'A' && c <= 'Z'); }
string PIE_ToUpper(const string s) { string x=s; StringToUpper(x); return x; }

string PIE_NormalizeSym(const string sym_raw)
{
   string s = PIE_ToUpper(sym_raw);

   int dot = StringFind(s, ".", 0);
   if(dot > 0) s = StringSubstr(s, 0, dot);

   int hsh = StringFind(s, "#", 0);
   if(hsh > 0) s = StringSubstr(s, 0, hsh);

   StringReplace(s, " ", "");

   if(StringFind(s, "CASH", 0) >= 0)
   {
      int hy = StringFind(s, "-", 0);
      if(hy > 0) s = StringSubstr(s, 0, hy);
   }

   StringTrimLeft(s); StringTrimRight(s);
   return s;
}

bool PIE_IsISOCCY(const string t3)
{
   if(t3=="USD"||t3=="EUR"||t3=="JPY"||t3=="GBP"||t3=="CHF"||t3=="CAD"||t3=="AUD"||t3=="NZD") return true;
   if(t3=="SEK"||t3=="NOK"||t3=="DKK"||t3=="PLN"||t3=="CZK"||t3=="HUF"||t3=="TRY"||t3=="ZAR") return true;
   if(t3=="MXN"||t3=="BRL"||t3=="CLP"||t3=="COP"||t3=="ARS") return true;
   if(t3=="RUB"||t3=="CNY"||t3=="CNH"||t3=="HKD"||t3=="SGD"||t3=="INR"||t3=="KRW"||t3=="TWD") return true;
   return false;
}
bool PIE_IsMajorCCY(const string t3)
{
   return (t3=="USD"||t3=="EUR"||t3=="JPY"||t3=="GBP"||t3=="CHF"||t3=="CAD"||t3=="AUD"||t3=="NZD");
}
bool PIE_IsFX6(const string s)
{
   if(StringLen(s) < 6) return false;
   for(int i=0;i<6;i++)
   {
      ushort c = (ushort)StringGetCharacter(s, i);
      if(!PIE_IsUpperAZ(c)) return false;
   }
   return true;
}
bool PIE_ContainsAny(const string s, const string tokens_csv)
{
   int start = 0;
   int L = (int)StringLen(tokens_csv);
   while(start < L)
   {
      int comma = StringFind(tokens_csv, ",", start);
      if(comma < 0) comma = L;
      string tok = StringSubstr(tokens_csv, start, comma-start);
      StringTrimLeft(tok); StringTrimRight(tok);
      if(tok != "" && StringFind(s, tok, 0) >= 0) return true;
      start = comma + 1;
   }
   return false;
}

int PIE_SectorClassify(const string sym_raw, const string sym_norm)
{
   if(PIE_ContainsAny(sym_norm, "XAU,XAG,XPT,XPD,GOLD,SILVER,PLAT,PALL")) return PIE_SECTOR_METAL;
   if(PIE_ContainsAny(sym_norm, "OIL,WTI,BRENT,UKOIL,USOIL,NG,GAS,NATGAS")) return PIE_SECTOR_ENERGY;
   if(PIE_ContainsAny(sym_norm, "BTC,ETH,LTC,XRP,SOL,ADA,DOGE,DOT,AVAX,BCH,BNB")) return PIE_SECTOR_CRYPTO;

   if(PIE_ContainsAny(sym_norm, "US30,US500,SPX,SP500,NDX,NAS,NAS100,USTEC,US100,DJ,WS30")) return PIE_SECTOR_INDEX_US;
   if(PIE_ContainsAny(sym_norm, "DE40,GER40,DAX,UK100,FTSE,FR40,CAC,EU50,STOXX,ESX")) return PIE_SECTOR_INDEX_EU;
   if(PIE_ContainsAny(sym_norm, "JP225,NIKKEI,NIK,HK50,HSI,AUS200,ASX,N25")) return PIE_SECTOR_INDEX_ASIA;

   if(PIE_IsFX6(sym_norm))
   {
      string base = StringSubstr(sym_norm, 0, 3);
      string quote= StringSubstr(sym_norm, 3, 3);
      if(PIE_IsISOCCY(base) && PIE_IsISOCCY(quote))
      {
         bool bMaj = PIE_IsMajorCCY(base);
         bool qMaj = PIE_IsMajorCCY(quote);
         if(bMaj && qMaj) return PIE_SECTOR_FX_MAJOR;
         if(bMaj || qMaj) return PIE_SECTOR_FX_CROSS;
         return PIE_SECTOR_FX_EXOTIC;
      }
   }

   long cm = 0;
   if(SymbolInfoInteger(sym_raw, SYMBOL_TRADE_CALC_MODE, cm))
   {
      if(cm == SYMBOL_CALC_MODE_EXCH_STOCKS) return PIE_SECTOR_STOCK;
   }

   return PIE_SECTOR_OTHER;
}

void PIE_SectorAssignAll()
{
   for(int i=0;i<PIE_SECTOR_COUNT;i++) g_sector_counts[i] = 0;

   const int N = g_universe_n;
   for(int i=0;i<N;i++)
   {
      SymState s = g_states[i];
      s.sector_rule_version = g_sector_rule_version;
      s.sym_norm = PIE_NormalizeSym(s.sym_raw);

      int sid = PIE_SectorClassify(s.sym_raw, s.sym_norm);
      if(sid < 0 || sid >= PIE_SECTOR_COUNT) sid = PIE_SECTOR_OTHER;
      s.sector_id = sid;
      g_sector_counts[sid]++;
   }
}

// ----------------------------
// Mode detect (Batch 1)
// ----------------------------
void PIE_ModeDetect(const int N)
{
   if(N <= 120) g_mode = MODE_SMALL;
   else if(N <= 400) g_mode = MODE_MEDIUM;
   else g_mode = MODE_LARGE;

   if(g_mode == MODE_LARGE)
   {
      int tgt = (int)MathRound(N * 0.18);
      if(tgt < 200) tgt = 200;
      if(tgt > 350) tgt = 350;
      g_active_target = tgt;
   }
   else g_active_target = 0;
}

// ----------------------------
// Reset symbol state (universe rebuild)
// ----------------------------
void PIE_ResetRingsAndBackfill(SymState &s)
{
   s.next_try_m1 = 0; s.next_try_m5 = 0; s.next_try_m15 = 0; s.next_try_d1 = 0;
   s.fail_m1 = 0; s.fail_m5 = 0; s.fail_m15 = 0; s.fail_d1 = 0;

   s.last_bar_m1 = 0; s.last_bar_m5 = 0; s.last_bar_m15 = 0; s.last_bar_d1 = 0;
   s.bars_m1 = 0; s.bars_m5 = 0; s.bars_m15 = 0; s.bars_d1 = 0;

   s.ready_m1 = false; s.ready_m5 = false; s.ready_m15 = false; s.ready_d1 = false;
   s.fresh_bits = 0;

   s.m1_head = 0; s.m1_count = 0;
   s.m5_head = 0; s.m5_count = 0;
   s.m15_head = 0; s.m15_count = 0;
   s.d1_head = 0; s.d1_count = 0;

   // No need to clear all arrays each rebuild (expensive); ring_count=0 makes them ignored.
}

// ----------------------------
// Universe build (Batch 1)
// ----------------------------
void PIE_UniverseBuild()
{
   g_universe_changed  = false;
   g_universe_selected = 0;

   const bool mw = InpOnlyMarketWatch;
   const int total = SymbolsTotal(mw);

   int cap = InpUniverseMaxSymbols;
   if(cap > 0) cap = PIE_ClampInt(cap, 50, 2000);
   else        cap = (total > 2000 ? 2000 : total);

   string tmp[];
   ArrayResize(tmp, total);
   int count = 0;

   for(int i=0;i<total;i++)
   {
      string sym = SymbolName(i, mw);
      if(sym == "") continue;
      tmp[count++] = sym;
   }
   ArrayResize(tmp, count);

   if(count > 1) ArraySort(tmp); // lex ascending

   const int take = (cap < count ? cap : count);

   // IMPORTANT: set universe size + mode BEFORE mode-dependent logic
   g_universe_n = take;
   PIE_ModeDetect(g_universe_n);

   ArrayResize(g_symbols, take);
   ArrayResize(g_states, take);

   for(int i=0;i<take;i++)
   {
      g_symbols[i] = tmp[i];

      SymState s = g_states[i];

      s.sym_raw = tmp[i];
      s.sym_norm = "";
      s.sector_id = PIE_SECTOR_OTHER;
      s.sector_rule_version = 0;

      s.spec_fingerprint = 0;

      // Tick
      s.bid = 0.0; s.ask = 0.0; s.mid = 0.0;
      s.point = 0.0; s.digits = 0; s.tick_size = 0.0;
      s.tick_time = 0; s.tick_age_sec = 999999;
      s.spread_points = 0.0; s.spread_ticks = 0.0;
      s.ready_tick = false;

      // Spec
      s.contract_size = 0.0;
      s.vol_min = 0.0; s.vol_max = 0.0; s.vol_step = 0.0;
      s.trade_mode = 0; s.calc_mode = 0; s.margin_mode = 0;
      s.profit_currency = ""; s.margin_currency = "";
      s.ready_spec = false;

      // Probes
      s.value_per_point_money = (double)NAN;
      s.value_per_tick_money  = (double)NAN;
      s.margin_1lot_money     = (double)NAN;

      // friction
      s.spread_cost_money     = (double)NAN;
      s.total_friction_money  = (double)NAN;
      s.total_friction_points = (double)NAN;

      // quality
      s.spec_quality = SPEC_LOW;
      s.spec_probe_ok_vpp = 0;
      s.spec_probe_ok_margin = 0;
      s.spec_last_probe_time = 0;

      PIE_ResetRingsAndBackfill(s);
   }

   // Best-effort SymbolSelect streaming (deterministic cap by mode)
   if(!mw)
   {
      int stream_cap = 350;
      if(g_mode == MODE_MEDIUM) stream_cap = 250;
      if(g_mode == MODE_SMALL)  stream_cap = take;

      for(int i=0;i<take;i++)
      {
         if(i < stream_cap)
         {
            if(SymbolSelect(g_symbols[i], true))
               g_universe_selected++;
         }
      }
   }
   else g_universe_selected = take;

   g_universe_first = (take > 0 ? g_symbols[0] : "");
   g_universe_last  = (take > 0 ? g_symbols[take-1] : "");

   // Fingerprint
   uint h = PIE_FNV1a32_Init();
   h = PIE_FNV1a32_Update(h, IntegerToString(take));
   h = PIE_FNV1a32_Update(h, "\n");
   for(int i=0;i<take;i++)
   {
      h = PIE_FNV1a32_Update(h, g_symbols[i]);
      h = PIE_FNV1a32_Update(h, "\n");
   }

   if(g_universe_fp != 0 && h != g_universe_fp)
      g_universe_changed = true;

   g_universe_fp = h;

   // Reset cursors
   g_tick_cursor = 0;
   g_spec_cursor = 0;
   g_bf_tf_turn = 0;
   for(int t=0;t<4;t++) g_bf_cursor[t] = 0;

   PIE_LOG_INFO(MODULE_UNIVERSE, 2001, "Universe built", g_universe_n, (int)g_universe_changed);
}

void PIE_RebuildUniverseNow()
{
   PIE_UniverseBuild();
   PIE_SectorAssignAll();
   g_last_publish_minute = -1; // force minute publish
   PIE_LOG_WARN(MODULE_UNIVERSE, 2009, "Universe rebuilt via command", g_universe_n, PIE_U32ToHex(g_universe_fp));
}

// ----------------------------
// Commands
// ----------------------------
void PIE_ApplyCommand(const string cmd_line)
{
   string s = cmd_line;
   StringTrimLeft(s); StringTrimRight(s);
   if(s == "") return;

   if(StringCompare(s, "FORCE_PUBLISH", false) == 0)
   {
      g_last_publish_minute = -1;
      PIE_LOG_WARN(MODULE_DEBUG, 1004, "CMD:FORCE_PUBLISH", 0, 0);
      return;
   }
   if(StringCompare(s, "REBUILD_UNIVERSE", false) == 0)
   {
      PIE_RebuildUniverseNow();
      PIE_LOG_WARN(MODULE_DEBUG, 1005, "CMD:REBUILD_UNIVERSE", 0, 0);
      return;
   }
   if(StringCompare(s, "DUMP_UNIVERSE", false) == 0)
   {
      g_cmd_dump_universe = true;
      PIE_LOG_WARN(MODULE_DEBUG, 1010, "CMD:DUMP_UNIVERSE", 0, 0);
      return;
   }

   PIE_LOG_WARN(MODULE_DEBUG, 1099, "CMD:UNKNOWN", 0, 0);
}

void PIE_PollCommandsOncePerSecond(const datetime now_server)
{
   if(now_server == g_last_cmd_poll_sec) return;
   g_last_cmd_poll_sec = now_server;

   if(!FileIsExist(InpCommandsFile, FILE_COMMON)) return;

   int h = FileOpen(InpCommandsFile, FILE_READ|FILE_TXT|FILE_COMMON);
   if(h == INVALID_HANDLE) return;

   int sz = (int)FileSize(h);
   string all = (sz > 0 ? FileReadString(h, sz) : "");
   FileClose(h);

   StringTrimLeft(all); StringTrimRight(all);
   if(all == "") return;

   int start = 0, len = (int)StringLen(all);
   while(start < len)
   {
      int nl = StringFind(all, "\n", start);
      if(nl < 0) nl = len;
      string line = StringSubstr(all, start, nl-start);
      StringTrimLeft(line); StringTrimRight(line);
      if(line != "") PIE_ApplyCommand(line);
      start = nl + 1;
   }

   // clear file best-effort
   int w = FileOpen(InpCommandsFile, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(w != INVALID_HANDLE) { FileWriteString(w, ""); FileClose(w); }
}

// ----------------------------
// Spec fingerprint (cache-only computation from cached fields)
// ----------------------------
uint PIE_ComputeSpecFingerprintByIndex(const int i)
{
   uint h = PIE_FNV1a32_Init();
   SymState s = g_states[i];

   h = PIE_FNV1a32_Update(h, s.sym_raw);                     h = PIE_FNV1a32_Update(h, "\n");
   h = PIE_FNV1a32_Update(h, IntegerToString(s.digits));     h = PIE_FNV1a32_Update(h, "\n");
   h = PIE_FNV1a32_Update(h, DoubleToString(s.point, 12));   h = PIE_FNV1a32_Update(h, "\n");
   h = PIE_FNV1a32_Update(h, DoubleToString(s.tick_size, 12));h= PIE_FNV1a32_Update(h, "\n");
   h = PIE_FNV1a32_Update(h, DoubleToString(s.contract_size,12));h=PIE_FNV1a32_Update(h,"\n");
   h = PIE_FNV1a32_Update(h, DoubleToString(s.vol_step, 12));h = PIE_FNV1a32_Update(h, "\n");
   h = PIE_FNV1a32_Update(h, IntegerToString((int)s.calc_mode)); h = PIE_FNV1a32_Update(h, "\n");
   h = PIE_FNV1a32_Update(h, IntegerToString((int)s.margin_mode));h= PIE_FNV1a32_Update(h,"\n");
   h = PIE_FNV1a32_Update(h, s.profit_currency);             h = PIE_FNV1a32_Update(h, "\n");
   h = PIE_FNV1a32_Update(h, s.margin_currency);             h = PIE_FNV1a32_Update(h, "\n");

   return h;
}

// ----------------------------
// Batch 3: Tick step (budgeted, cursor-driven)
// ----------------------------
void PIE_TickStep(const datetime now_server)
{
   g_diag_tick.processed = 0;
   g_diag_tick.ok_count = 0;
   g_diag_tick.fail_count = 0;
   g_diag_tick.skipped = 0;
   g_diag_tick.last_error = 0;

   const int N = g_universe_n;
   if(N <= 0) return;

   int budget = N;
   if(g_mode == MODE_LARGE) budget = PIE_ClampInt(InpTickBudgetPerSec, 250, 450);
   else budget = N;

   for(int k=0; k<budget; k++)
   {
      int i = g_tick_cursor++;
      if(g_tick_cursor >= N) g_tick_cursor = 0;
      if(i < 0 || i >= N) { g_diag_tick.skipped++; continue; }

      SymState s = g_states[i];
      const string sym = s.sym_raw;

      ResetLastError();
      MqlTick t;
      bool ok = SymbolInfoTick(sym, t);
      int err = GetLastError();

      g_diag_tick.processed++;

      if(ok && t.bid > 0.0 && t.ask > 0.0)
      {
         s.bid = t.bid;
         s.ask = t.ask;
         s.mid = (t.bid + t.ask) * 0.5;
         s.tick_time = (datetime)t.time;

         int age = (int)(now_server - (datetime)t.time);
         if(age < 0) age = 0;
         s.tick_age_sec = age;
         s.ready_tick = true;

         g_diag_tick.ok_count++;
      }
      else
      {
         // keep previous cache; update readiness if never got tick
         if(s.tick_time <= 0) s.ready_tick = false;
         g_diag_tick.fail_count++;
         if(err != 0) g_diag_tick.last_error = err;
      }

      // Minimal fill if missing (avoid heavy repeats)
      if(s.digits == 0)
      {
         long d=0;
         ResetLastError();
         if(SymbolInfoInteger(sym, SYMBOL_DIGITS, d)) s.digits = (int)d;
      }
      if(s.point <= 0.0)
      {
         double p=0.0;
         ResetLastError();
         if(SymbolInfoDouble(sym, SYMBOL_POINT, p)) s.point = p;
      }
      if(s.tick_size <= 0.0)
      {
         double ts=0.0;
         ResetLastError();
         if(SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE, ts)) s.tick_size = ts;
      }

      if(s.bid > 0.0 && s.ask > 0.0)
      {
         s.spread_points = (s.ask - s.bid);
         if(s.point > 0.0) s.spread_ticks = s.spread_points / s.point;
         else              s.spread_ticks = 0.0;
      }
      else
      {
         s.spread_points = 0.0;
         s.spread_ticks = 0.0;
      }
   }
}

// ----------------------------
// Batch 3: Probes (cost truth)
// ----------------------------
bool PIE_ProbeValuePerPoint(const string sym, const double point, const double price, double &out_vpp, int &out_err)
{
   out_vpp = (double)NAN;
   out_err = 0;

   if(point <= 0.0 || price <= 0.0) return false;

   double profit_delta = 0.0;
   ResetLastError();
   bool ok = OrderCalcProfit(ORDER_TYPE_BUY, sym, 1.0, price, price + point, profit_delta);
   out_err = GetLastError();

   if(!ok) return false;
   if(!PIE_IsFinite(profit_delta)) return false;

   out_vpp = profit_delta;
   return true;
}

bool PIE_ProbeMargin1Lot(const string sym, const double price, double &out_margin, int &out_err)
{
   out_margin = (double)NAN;
   out_err = 0;

   if(price <= 0.0) return false;

   double margin = 0.0;
   ResetLastError();
   bool ok = OrderCalcMargin(ORDER_TYPE_BUY, sym, 1.0, price, margin);
   out_err = GetLastError();

   if(!ok) return false;
   if(!PIE_IsFinite(margin) || margin <= 0.0) return false;

   out_margin = margin;
   return true;
}

// ----------------------------
// Batch 3: Spec + cost truth step (budgeted, deterministic)
// ----------------------------
void PIE_SpecMarketStep(const datetime now_server)
{
   g_diag_spec.processed = 0;
   g_diag_spec.ok_count = 0;
   g_diag_spec.fail_count = 0;
   g_diag_spec.skipped = 0;
   g_diag_spec.last_error = 0;

   // probe diags are per second
   g_diag_probe_vpp.processed = 0;
   g_diag_probe_vpp.ok_count = 0;
   g_diag_probe_vpp.fail_count = 0;
   g_diag_probe_vpp.skipped = 0;
   g_diag_probe_vpp.last_error = 0;

   g_diag_probe_margin.processed = 0;
   g_diag_probe_margin.ok_count = 0;
   g_diag_probe_margin.fail_count = 0;
   g_diag_probe_margin.skipped = 0;
   g_diag_probe_margin.last_error = 0;

   const int N = g_universe_n;
   if(N <= 0) return;

   int budget = PIE_ClampInt(InpSpecBudgetPerSec, 10, 60);

   for(int k=0; k<budget; k++)
   {
      int i = g_spec_cursor++;
      if(g_spec_cursor >= N) g_spec_cursor = 0;
      if(i < 0 || i >= N) { g_diag_spec.skipped++; continue; }

      SymState s = g_states[i];
      const string sym = s.sym_raw;

      g_diag_spec.processed++;

      // Panel fields (cached)
      long   digits=0;
      double point=0.0, tick_size=0.0, contract_size=0.0;
      double vmin=0.0, vmax=0.0, vstep=0.0;
      long   trade_mode=0, calc_mode=0, margin_mode=0;

      int last_err_local = 0;

      ResetLastError(); if(SymbolInfoInteger(sym, SYMBOL_DIGITS, digits)) s.digits = (int)digits; else last_err_local = GetLastError();
      ResetLastError(); if(SymbolInfoDouble(sym, SYMBOL_POINT, point))    s.point  = point;      else if(last_err_local==0) last_err_local = GetLastError();
      ResetLastError(); if(SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE, tick_size)) s.tick_size = tick_size; else if(last_err_local==0) last_err_local = GetLastError();
      ResetLastError(); if(SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE, contract_size)) s.contract_size = contract_size; else if(last_err_local==0) last_err_local = GetLastError();

      // volume
      ResetLastError(); SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN, vmin);
      ResetLastError(); SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX, vmax);
      ResetLastError(); SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP, vstep);
      s.vol_min = vmin; s.vol_max = vmax; s.vol_step = vstep;

      // modes
      ResetLastError(); SymbolInfoInteger(sym, SYMBOL_TRADE_MODE, trade_mode);
      ResetLastError(); SymbolInfoInteger(sym, SYMBOL_TRADE_CALC_MODE, calc_mode);
      ResetLastError(); SymbolInfoInteger(sym, SYMBOL_TRADE_CALC_MODE, margin_mode);

      s.trade_mode  = trade_mode;
      s.calc_mode   = calc_mode;
      s.margin_mode = margin_mode;

      // currencies (strings)
      s.profit_currency = SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT);
      s.margin_currency = SymbolInfoString(sym, SYMBOL_CURRENCY_MARGIN);

      // readiness
      bool ok_panel = (s.point > 0.0 && s.contract_size > 0.0 && s.vol_step > 0.0 && s.digits >= 0 && s.digits <= 12);
      s.ready_spec = ok_panel;

      // fingerprint from cached fields
      s.spec_fingerprint = PIE_ComputeSpecFingerprintByIndex(i);

      // price for probes
      double price = s.mid;
      if(price <= 0.0) price = s.bid;
      if(price <= 0.0)
      {
         ResetLastError();
         double lastp = SymbolInfoDouble(sym, SYMBOL_LAST);
         if(lastp > 0.0) price = lastp;
      }
      if(price <= 0.0 && s.ask > 0.0) price = s.ask;

      // probe throttle
      bool can_probe = (InpProbeMinIntervalSec <= 0) || ((int)(now_server - s.spec_last_probe_time) >= InpProbeMinIntervalSec);

      int ok_vpp = s.spec_probe_ok_vpp;
      int ok_m   = s.spec_probe_ok_margin;

      if(ok_panel && can_probe && price > 0.0)
      {
         // VPP probe
         g_diag_probe_vpp.processed++;
         double vpp = (double)NAN;
         int err_vpp = 0;
         bool got_vpp = PIE_ProbeValuePerPoint(sym, s.point, price, vpp, err_vpp);
         if(got_vpp)
         {
            s.value_per_point_money = vpp;
            ok_vpp = 1;
            g_diag_probe_vpp.ok_count++;

            // tick value from vpp
            if(s.tick_size > 0.0 && s.point > 0.0)
            {
               double vpt = vpp * (s.tick_size / s.point);
               if(PIE_IsFinite(vpt) && vpt > 0.0) s.value_per_tick_money = vpt;
            }
         }
         else
         {
            g_diag_probe_vpp.fail_count++;
            if(err_vpp != 0) g_diag_probe_vpp.last_error = err_vpp;
         }

         // margin probe
         g_diag_probe_margin.processed++;
         double m1 = (double)NAN;
         int err_m = 0;
         bool got_m = PIE_ProbeMargin1Lot(sym, price, m1, err_m);
         if(got_m)
         {
            s.margin_1lot_money = m1;
            ok_m = 1;
            g_diag_probe_margin.ok_count++;
         }
         else
         {
            g_diag_probe_margin.fail_count++;
            if(err_m != 0) g_diag_probe_margin.last_error = err_m;
         }

         s.spec_last_probe_time = now_server;
      }
      else
      {
         // skipped probe due to throttle or missing panel/price
         g_diag_probe_vpp.skipped++;
         g_diag_probe_margin.skipped++;
      }

      // spec quality
      int quality = SPEC_LOW;
      if(ok_panel && ok_vpp==1 && ok_m==1) quality = SPEC_HIGH;
      else if(ok_panel && ok_vpp==1)       quality = SPEC_MED;
      else                                 quality = SPEC_LOW;

      s.spec_quality = quality;
      s.spec_probe_ok_vpp = ok_vpp;
      s.spec_probe_ok_margin = ok_m;

      // friction (derived from cached spread + cached value_per_tick_money)
      double spread_cost = (double)NAN;
      if(PIE_IsFinite(s.spread_ticks) && PIE_IsFinite(s.value_per_tick_money))
      {
         spread_cost = s.spread_ticks * s.value_per_tick_money;
         if(!PIE_IsFinite(spread_cost) || spread_cost < 0.0) spread_cost = (double)NAN;
      }
      s.spread_cost_money = spread_cost;
      s.total_friction_money = spread_cost;

      if(s.point > 0.0 && PIE_IsFinite(s.spread_points))
      {
         double pts = s.spread_points / s.point;
         s.total_friction_points = (PIE_IsFinite(pts) ? pts : (double)NAN);
      }
      else s.total_friction_points = (double)NAN;

      // spec diag ok/fail
      if(ok_panel) g_diag_spec.ok_count++;
      else
      {
         g_diag_spec.fail_count++;
         if(last_err_local != 0) g_diag_spec.last_error = last_err_local;
      }
   }

   // summary rebuild (once per second ok)
   g_spec_q_counts[0]=g_spec_q_counts[1]=g_spec_q_counts[2]=0;

   for(int i=0;i<N;i++)
   {
      int q = g_states[i].spec_quality;
      if(q < 0) q = 0; if(q > 2) q = 2;
      g_spec_q_counts[q]++;
   }
}

// ----------------------------
// Batch 4: Ring append helpers (fixed size)
// ----------------------------
void PIE_RingAppend_M1(SymState &s, const MqlRates &r)
{
   const int idx = s.m1_head;
   s.m1_time[idx]  = (datetime)r.time;
   s.m1_open[idx]  = r.open;
   s.m1_high[idx]  = r.high;
   s.m1_low[idx]   = r.low;
   s.m1_close[idx] = r.close;

   s.m1_head = (s.m1_head + 1) % PIE_M1_RING;
   if(s.m1_count < PIE_M1_RING) s.m1_count++;
   s.last_bar_m1 = (datetime)r.time;
}

void PIE_RingAppend_M5(SymState &s, const MqlRates &r)
{
   const int idx = s.m5_head;
   s.m5_time[idx]  = (datetime)r.time;
   s.m5_open[idx]  = r.open;
   s.m5_high[idx]  = r.high;
   s.m5_low[idx]   = r.low;
   s.m5_close[idx] = r.close;

   s.m5_head = (s.m5_head + 1) % PIE_M5_RING;
   if(s.m5_count < PIE_M5_RING) s.m5_count++;
   s.last_bar_m5 = (datetime)r.time;
}

void PIE_RingAppend_M15(SymState &s, const MqlRates &r)
{
   const int idx = s.m15_head;
   s.m15_time[idx]  = (datetime)r.time;
   s.m15_open[idx]  = r.open;
   s.m15_high[idx]  = r.high;
   s.m15_low[idx]   = r.low;
   s.m15_close[idx] = r.close;

   s.m15_head = (s.m15_head + 1) % PIE_M15_RING;
   if(s.m15_count < PIE_M15_RING) s.m15_count++;
   s.last_bar_m15 = (datetime)r.time;
}

void PIE_RingAppend_D1(SymState &s, const MqlRates &r)
{
   const int idx = s.d1_head;
   s.d1_time[idx]  = (datetime)r.time;
   s.d1_open[idx]  = r.open;
   s.d1_high[idx]  = r.high;
   s.d1_low[idx]   = r.low;
   s.d1_close[idx] = r.close;

   s.d1_head = (s.d1_head + 1) % PIE_D1_RING;
   if(s.d1_count < PIE_D1_RING) s.d1_count++;
   s.last_bar_d1 = (datetime)r.time;
}

// deterministic power-of-two backoff with cap
int PIE_BackoffNextSec(const int base_sec, int fail_count)
{
   if(fail_count < 0) fail_count = 0;
   if(fail_count > 10) fail_count = 10;
   int mult = 1;
   for(int i=0;i<fail_count;i++) mult *= 2; // deterministic
   int sec = base_sec * mult;
   if(sec > 300) sec = 300;
   if(sec < base_sec) sec = base_sec;
   return sec;
}

// ----------------------------
// Batch 4: Backfill one TF
// ----------------------------
bool PIE_BackfillOneTF(SymState &s, const datetime now_server, const int tf_id, StepDiag &diag)
{
   diag.processed++;
   const string sym = s.sym_raw;

   ENUM_TIMEFRAMES tf;
   int ring_size;
   int base_sec;

   // references are NOT allowed as locals in MT5, so we branch per TF
   if(tf_id == TF_M1)
   {
      tf = PERIOD_M1; ring_size = PIE_M1_RING; base_sec = 3;

      if(s.next_try_m1 > 0 && now_server < s.next_try_m1) { diag.skipped++; return false; }

      if(s.m1_count < ring_size)
      {
         MqlRates rates[];
         ArraySetAsSeries(rates, true);

         ResetLastError();
         int got = CopyRates(sym, tf, 0, ring_size, rates);
         int err = GetLastError();

         if(got >= 1)
         {
            s.m1_head = 0; s.m1_count = 0;
            for(int j=got-1; j>=0; j--) PIE_RingAppend_M1(s, rates[j]);

            s.bars_m1 = s.m1_count;
            s.fail_m1 = 0;
            s.next_try_m1 = 0;

            diag.ok_count++;
            return true;
         }

         s.fail_m1++; if(s.fail_m1 > 10) s.fail_m1 = 10;
         s.next_try_m1 = now_server + PIE_BackoffNextSec(base_sec, s.fail_m1);
         diag.fail_count++; if(err != 0) diag.last_error = err;
         return false;
      }

      // incremental
      MqlRates r2[];
      ArraySetAsSeries(r2, true);

      ResetLastError();
      int got2 = CopyRates(sym, tf, 0, 2, r2);
      int err2 = GetLastError();

      if(got2 >= 1)
      {
         datetime t0 = (datetime)r2[0].time;
         if(t0 != s.last_bar_m1) PIE_RingAppend_M1(s, r2[0]);

         s.bars_m1 = s.m1_count;
         s.fail_m1 = 0;
         s.next_try_m1 = 0;

         diag.ok_count++;
         return true;
      }

      s.fail_m1++; if(s.fail_m1 > 10) s.fail_m1 = 10;
      s.next_try_m1 = now_server + PIE_BackoffNextSec(base_sec, s.fail_m1);
      diag.fail_count++; if(err2 != 0) diag.last_error = err2;
      return false;
   }
   else if(tf_id == TF_M5)
   {
      tf = PERIOD_M5; ring_size = PIE_M5_RING; base_sec = 6;

      if(s.next_try_m5 > 0 && now_server < s.next_try_m5) { diag.skipped++; return false; }

      if(s.m5_count < ring_size)
      {
         MqlRates rates[];
         ArraySetAsSeries(rates, true);

         ResetLastError();
         int got = CopyRates(sym, tf, 0, ring_size, rates);
         int err = GetLastError();

         if(got >= 1)
         {
            s.m5_head = 0; s.m5_count = 0;
            for(int j=got-1; j>=0; j--) PIE_RingAppend_M5(s, rates[j]);

            s.bars_m5 = s.m5_count;
            s.fail_m5 = 0;
            s.next_try_m5 = 0;

            diag.ok_count++;
            return true;
         }

         s.fail_m5++; if(s.fail_m5 > 10) s.fail_m5 = 10;
         s.next_try_m5 = now_server + PIE_BackoffNextSec(base_sec, s.fail_m5);
         diag.fail_count++; if(err != 0) diag.last_error = err;
         return false;
      }

      MqlRates r2[];
      ArraySetAsSeries(r2, true);

      ResetLastError();
      int got2 = CopyRates(sym, tf, 0, 2, r2);
      int err2 = GetLastError();

      if(got2 >= 1)
      {
         datetime t0 = (datetime)r2[0].time;
         if(t0 != s.last_bar_m5) PIE_RingAppend_M5(s, r2[0]);

         s.bars_m5 = s.m5_count;
         s.fail_m5 = 0;
         s.next_try_m5 = 0;

         diag.ok_count++;
         return true;
      }

      s.fail_m5++; if(s.fail_m5 > 10) s.fail_m5 = 10;
      s.next_try_m5 = now_server + PIE_BackoffNextSec(base_sec, s.fail_m5);
      diag.fail_count++; if(err2 != 0) diag.last_error = err2;
      return false;
   }
   else if(tf_id == TF_M15)
   {
      tf = PERIOD_M15; ring_size = PIE_M15_RING; base_sec = 12;

      if(s.next_try_m15 > 0 && now_server < s.next_try_m15) { diag.skipped++; return false; }

      if(s.m15_count < ring_size)
      {
         MqlRates rates[];
         ArraySetAsSeries(rates, true);

         ResetLastError();
         int got = CopyRates(sym, tf, 0, ring_size, rates);
         int err = GetLastError();

         if(got >= 1)
         {
            s.m15_head = 0; s.m15_count = 0;
            for(int j=got-1; j>=0; j--) PIE_RingAppend_M15(s, rates[j]);

            s.bars_m15 = s.m15_count;
            s.fail_m15 = 0;
            s.next_try_m15 = 0;

            diag.ok_count++;
            return true;
         }

         s.fail_m15++; if(s.fail_m15 > 10) s.fail_m15 = 10;
         s.next_try_m15 = now_server + PIE_BackoffNextSec(base_sec, s.fail_m15);
         diag.fail_count++; if(err != 0) diag.last_error = err;
         return false;
      }

      MqlRates r2[];
      ArraySetAsSeries(r2, true);

      ResetLastError();
      int got2 = CopyRates(sym, tf, 0, 2, r2);
      int err2 = GetLastError();

      if(got2 >= 1)
      {
         datetime t0 = (datetime)r2[0].time;
         if(t0 != s.last_bar_m15) PIE_RingAppend_M15(s, r2[0]);

         s.bars_m15 = s.m15_count;
         s.fail_m15 = 0;
         s.next_try_m15 = 0;

         diag.ok_count++;
         return true;
      }

      s.fail_m15++; if(s.fail_m15 > 10) s.fail_m15 = 10;
      s.next_try_m15 = now_server + PIE_BackoffNextSec(base_sec, s.fail_m15);
      diag.fail_count++; if(err2 != 0) diag.last_error = err2;
      return false;
   }
   else // TF_D1
   {
      tf = PERIOD_D1; ring_size = PIE_D1_RING; base_sec = 60;

      if(s.next_try_d1 > 0 && now_server < s.next_try_d1) { diag.skipped++; return false; }

      if(s.d1_count < ring_size)
      {
         MqlRates rates[];
         ArraySetAsSeries(rates, true);

         ResetLastError();
         int got = CopyRates(sym, tf, 0, ring_size, rates);
         int err = GetLastError();

         if(got >= 1)
         {
            s.d1_head = 0; s.d1_count = 0;
            for(int j=got-1; j>=0; j--) PIE_RingAppend_D1(s, rates[j]);

            s.bars_d1 = s.d1_count;
            s.fail_d1 = 0;
            s.next_try_d1 = 0;

            diag.ok_count++;
            return true;
         }

         s.fail_d1++; if(s.fail_d1 > 10) s.fail_d1 = 10;
         s.next_try_d1 = now_server + PIE_BackoffNextSec(base_sec, s.fail_d1);
         diag.fail_count++; if(err != 0) diag.last_error = err;
         return false;
      }

      MqlRates r2[];
      ArraySetAsSeries(r2, true);

      ResetLastError();
      int got2 = CopyRates(sym, tf, 0, 2, r2);
      int err2 = GetLastError();

      if(got2 >= 1)
      {
         datetime t0 = (datetime)r2[0].time;
         if(t0 != s.last_bar_d1) PIE_RingAppend_D1(s, r2[0]);

         s.bars_d1 = s.d1_count;
         s.fail_d1 = 0;
         s.next_try_d1 = 0;

         diag.ok_count++;
         return true;
      }

      s.fail_d1++; if(s.fail_d1 > 10) s.fail_d1 = 10;
      s.next_try_d1 = now_server + PIE_BackoffNextSec(base_sec, s.fail_d1);
      diag.fail_count++; if(err2 != 0) diag.last_error = err2;
      return false;
   }
}

// ----------------------------
// Batch 4: Backfill step (budgeted, cursor-driven, deterministic)
// ----------------------------
void PIE_BackfillStep(const datetime now_server)
{
   // reset per-second diags
   g_diag_bf_m1.processed = g_diag_bf_m1.ok_count = g_diag_bf_m1.fail_count = g_diag_bf_m1.skipped = g_diag_bf_m1.last_error = 0;
   g_diag_bf_m5.processed = g_diag_bf_m5.ok_count = g_diag_bf_m5.fail_count = g_diag_bf_m5.skipped = g_diag_bf_m5.last_error = 0;
   g_diag_bf_m15.processed = g_diag_bf_m15.ok_count = g_diag_bf_m15.fail_count = g_diag_bf_m15.skipped = g_diag_bf_m15.last_error = 0;
   g_diag_bf_d1.processed = g_diag_bf_d1.ok_count = g_diag_bf_d1.fail_count = g_diag_bf_d1.skipped = g_diag_bf_d1.last_error = 0;

   const int N = g_universe_n;
   if(N <= 0) return;

   int budget = PIE_ClampInt(InpBackfillBudgetPerSec, 3, 10);

   for(int step=0; step<budget; step++)
   {
      int tf_id = g_bf_tf_turn;
      g_bf_tf_turn = (g_bf_tf_turn + 1) % 4;

      int i = g_bf_cursor[tf_id]++;
      if(g_bf_cursor[tf_id] >= N) g_bf_cursor[tf_id] = 0;
      if(i < 0 || i >= N) continue;

      SymState s = g_states[i];

      if(tf_id == TF_M1) PIE_BackfillOneTF(s, now_server, TF_M1, g_diag_bf_m1);
      else if(tf_id == TF_M5) PIE_BackfillOneTF(s, now_server, TF_M5, g_diag_bf_m5);
      else if(tf_id == TF_M15) PIE_BackfillOneTF(s, now_server, TF_M15, g_diag_bf_m15);
      else PIE_BackfillOneTF(s, now_server, TF_D1, g_diag_bf_d1);
   }

   // Update readiness + freshness bits
   for(int i=0;i<N;i++)
   {
      SymState s = g_states[i];

      s.ready_m1  = (s.m1_count  >= PIE_M1_READY_MIN);
      s.ready_m5  = (s.m5_count  >= PIE_M5_READY_MIN);
      s.ready_m15 = (s.m15_count >= PIE_M15_READY_MIN);
      s.ready_d1  = (s.d1_count  >= PIE_D1_READY_MIN);

      int fb = 0;
      if(s.last_bar_m1 > 0 && (int)(now_server - s.last_bar_m1) <= 120) fb |= PIE_FRESH_M1;
      if(s.last_bar_m5 > 0 && (int)(now_server - s.last_bar_m5) <= 600) fb |= PIE_FRESH_M5;
      if(s.last_bar_m15 > 0 && (int)(now_server - s.last_bar_m15) <= 1800) fb |= PIE_FRESH_M15;
      if(s.last_bar_d1 > 0 && (int)(now_server - s.last_bar_d1) <= 86400) fb |= PIE_FRESH_D1;
      s.fresh_bits = fb;
   }
}

// ----------------------------
// UTF-8 JSON IO (atomic best-effort) + previous backup
// ----------------------------
void PIE_IoLastReset(const string file, const string op)
{
   g_io_last.last_file = file;
   g_io_last.last_op   = op;
   g_io_last.open_err = 0;
   g_io_last.write_err = 0;
   g_io_last.copy_err = 0;
   g_io_last.move_err = 0;
   g_io_last.delete_err = 0;
   g_io_last.bytes = 0;
   g_io_last.size = -1;
}

bool PIE_FileCopyBestEffort(const string src, const string dst, int &out_copy_err)
{
   out_copy_err = 0;
   ResetLastError();
   bool ok = FileCopy(src, FILE_COMMON, dst, FILE_COMMON);
   if(!ok) out_copy_err = GetLastError();
   return ok;
}

bool PIE_WriteJsonAtomicFinal(const string finalName, const string json, int &out_open_err, int &out_write_err, int &out_copy_err, int &out_del_err, int &out_bytes, long &out_size)
{
   out_open_err = 0; out_write_err = 0; out_copy_err = 0; out_del_err = 0;
   out_bytes = 0; out_size = -1;

   string tmpName = finalName + ".tmp";

   if(FileIsExist(tmpName, FILE_COMMON))
   {
      ResetLastError();
      if(!FileDelete(tmpName, FILE_COMMON)) out_del_err = GetLastError();
   }

   // Convert to UTF-8 bytes
   uchar buf[];
   int len = StringToCharArray(json, buf, 0, WHOLE_ARRAY, CP_UTF8);
   if(len < 0) len = 0;
   int bytes_to_write = (len > 0 ? len - 1 : 0);

   ResetLastError();
   int h = FileOpen(tmpName, FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(h == INVALID_HANDLE)
   {
      out_open_err = GetLastError();
      return false;
   }

   bool ok_write = true;
if(bytes_to_write > 0)
{
   ResetLastError();
   uint written = (uint)FileWriteArray(h, buf, 0, bytes_to_write);
   if(written != (uint)bytes_to_write)
   {
      ok_write = false;
      out_write_err = GetLastError();
   }
}
   FileFlush(h);
   FileClose(h);

   out_bytes = bytes_to_write;

   // warn-only JSON guard (does not block)
   PIE_JsonGuardWarnOnly(finalName, json);

   // copy tmp -> final
   ResetLastError();
   bool ok_copy = FileCopy(tmpName, FILE_COMMON, finalName, FILE_COMMON);
   if(!ok_copy) out_copy_err = GetLastError();

   // delete tmp best effort
   ResetLastError();
   if(FileIsExist(tmpName, FILE_COMMON))
      if(!FileDelete(tmpName, FILE_COMMON)) out_del_err = GetLastError();

   // size verify
   int rf = FileOpen(finalName, FILE_READ|FILE_BIN|FILE_COMMON);
   if(rf != INVALID_HANDLE) { out_size = (long)FileSize(rf); FileClose(rf); }

   if(out_open_err!=0 || out_write_err!=0 || out_copy_err!=0) return false;
   if(!ok_write) return false;
   if(out_size <= 0) return false;
   return true;
}

bool PIE_WriteJsonWithPrevBackup(const string finalName, const string backupName, const string json, int &out_last_err)
{
   out_last_err = 0;

   PIE_IoLastReset(finalName, "write_json");

   // Copy previous final -> backup (previous successful)
   if(FileIsExist(finalName, FILE_COMMON))
   {
      int ce_old=0;
      PIE_FileCopyBestEffort(finalName, backupName, ce_old);
      // do not fail on backup copy; record as io_last.copy_err only if no other op yet
      if(ce_old != 0) g_io_last.copy_err = ce_old;
   }

   int oe=0,we=0,ce=0,de=0,bytes=0; long sz=-1;
   bool ok = PIE_WriteJsonAtomicFinal(finalName, json, oe,we,ce,de,bytes,sz);

   g_io_last.open_err = oe;
   g_io_last.write_err = we;
   g_io_last.copy_err = (g_io_last.copy_err!=0 ? g_io_last.copy_err : ce);
   g_io_last.delete_err = de;
   g_io_last.bytes = bytes;
   g_io_last.size = sz;

   if(ok) g_st.io_ok++;
   else   g_st.io_fail++;

   if(!ok)
   {
      out_last_err = (ce!=0 ? ce : (we!=0 ? we : (oe!=0 ? oe : 0)));
      if(InpDebugLevel >= DBG_WARN)
         Print("[WARN] json write failed file=", finalName, " open=",oe," write=",we," copy=",ce," del=",de," size=",sz);
   }
   return ok;
}

bool PIE_CopyDebugBackupAtMinuteEdge(int &out_err)
{
   out_err = 0;
   PIE_IoLastReset(g_debug_backup_json, "copy_debug_backup");

   int ce=0;
   bool ok = PIE_FileCopyBestEffort(g_debug_json, g_debug_backup_json, ce);

   g_io_last.copy_err = ce;
   g_io_last.size = -1;
   g_io_last.bytes = 0;

   if(!ok) out_err = ce;
   return ok;
}

// ----------------------------
// Coverage counters (cache-only)
// ----------------------------
void PIE_ComputeCoverage(int &ready_tick, int &ready_spec, int &ready_m1, int &ready_m5, int &ready_m15, int &ready_d1,
                         int &missing_tick, int &missing_spec, int &missing_m1, int &missing_m5, int &missing_m15, int &missing_d1)
{
   ready_tick=ready_spec=ready_m1=ready_m5=ready_m15=ready_d1=0;
   missing_tick=missing_spec=missing_m1=missing_m5=missing_m15=missing_d1=0;

   const int N = g_universe_n;
   for(int i=0;i<N;i++)
   {
      SymState s = g_states[i];

      if(s.ready_tick) ready_tick++; else missing_tick++;
      if(s.ready_spec) ready_spec++; else missing_spec++;

      if(s.ready_m1) ready_m1++; else missing_m1++;
      if(s.ready_m5) ready_m5++; else missing_m5++;
      if(s.ready_m15) ready_m15++; else missing_m15++;
      if(s.ready_d1) ready_d1++; else missing_d1++;
   }
}

// ----------------------------
// Top-5 per sector selection (cache-only)
// Ranking chain (LTS):
// 1 spread_ticks ASC (nulls last)
// 2 tick_age_sec ASC
// 3 total_friction_money ASC (nulls last)
// 4 spec_quality DESC
// 5 sym_raw ASC
// ----------------------------
double PIE_KeyNullLast(const double x)
{
   if(!PIE_IsFinite(x)) return 1e18;
   return x;
}

int PIE_CmpSymbolIdx(const int a, const int b)
{
const SymState A = g_states[a];
const SymState B = g_states[b];

   double aspread = PIE_KeyNullLast(A.spread_ticks);
   double bspread = PIE_KeyNullLast(B.spread_ticks);
   if(aspread < bspread) return -1;
   if(aspread > bspread) return 1;

   int aage = A.tick_age_sec;
   int bage = B.tick_age_sec;
   if(aage < bage) return -1;
   if(aage > bage) return 1;

   double afric = PIE_KeyNullLast(A.total_friction_money);
   double bfric = PIE_KeyNullLast(B.total_friction_money);
   if(afric < bfric) return -1;
   if(afric > bfric) return 1;

   int aq = A.spec_quality;
   int bq = B.spec_quality;
   if(aq > bq) return -1;
   if(aq < bq) return 1;

   // tie-break sym_raw ascending
   int sc = StringCompare(A.sym_raw, B.sym_raw, false);
   if(sc < 0) return -1;
   if(sc > 0) return 1;
   return 0;
}

bool PIE_IsEligibleForTop(const SymState &s)
{
   if(!s.ready_tick) return false;
   if(!s.ready_spec) return false;
   if(s.spec_quality == SPEC_LOW) return false;
   // optional inactivity gate (neutral): if tick_age very high, exclude
   if(s.tick_age_sec > 600) return false;
   return true;
}

void PIE_InsertTop5Flat(int &top_flat[], const int base, int &top_count, const int cand)
{
   // base = sector_id*5
   if(top_count <= 0)
   {
      top_flat[base+0] = cand;
      top_count = 1;
      return;
   }

   if(top_count == 5)
   {
      int last = top_flat[base+4];
      if(PIE_CmpSymbolIdx(cand, last) >= 0) return;
   }

   int pos = top_count;
   for(int i=0;i<top_count;i++)
   {
      if(PIE_CmpSymbolIdx(cand, top_flat[base+i]) < 0) { pos = i; break; }
   }

   if(top_count < 5) top_count++;

   for(int j=top_count-1; j>pos; j--)
      top_flat[base+j] = top_flat[base+(j-1)];

   top_flat[base+pos] = cand;
   if(top_count > 5) top_count = 5;
}

void PIE_ComputeTopBySectorFlat(int &top_flat[], int &top_count_by_sector[])
{
   // init
   for(int sid=0; sid<PIE_SECTOR_COUNT; sid++)
   {
      top_count_by_sector[sid] = 0;
      int base = sid*5;
      for(int k=0;k<5;k++) top_flat[base+k] = -1;
   }

   const int N = g_universe_n;
   for(int i=0;i<N;i++)
   {
      const SymState s = g_states[i];
      if(!PIE_IsEligibleForTop(s)) continue;

      int sid = s.sector_id;
      if(sid < 0 || sid >= PIE_SECTOR_COUNT) sid = PIE_SECTOR_OTHER;

      int base = sid*5;
      PIE_InsertTop5Flat(top_flat, base, top_count_by_sector[sid], i);
   }
}

// ----------------------------
// JSON builders (CACHE-ONLY)
// ----------------------------
string PIE_BuildSymbolBlockJSON(const SymState &s, const int prec)
{
   string js = "{";

   js += "\"id\":\"" + PIE_JsonEscape(s.sym_raw) + "\"";
   js += ",\"norm\":\"" + PIE_JsonEscape(s.sym_norm) + "\"";
   js += ",\"sector_id\":\"" + PIE_SectorName(s.sector_id) + "\"";

   // spec
   js += ",\"spec\":{";
   js += "\"digits\":" + IntegerToString(s.digits);
   js += ",\"point\":" + PIE_JsonFloatOrNull(s.point, prec);
   js += ",\"tick_size\":" + PIE_JsonFloatOrNull(s.tick_size, prec);
   js += ",\"contract_size\":" + PIE_JsonFloatOrNull(s.contract_size, prec);
   js += ",\"vol_min\":" + PIE_JsonFloatOrNull(s.vol_min, prec);
   js += ",\"vol_max\":" + PIE_JsonFloatOrNull(s.vol_max, prec);
   js += ",\"vol_step\":" + PIE_JsonFloatOrNull(s.vol_step, prec);
   js += ",\"trade_mode\":" + IntegerToString((int)s.trade_mode);
   js += ",\"calc_mode\":" + IntegerToString((int)s.calc_mode);
   js += ",\"margin_mode\":" + IntegerToString((int)s.margin_mode);
   js += ",\"profit_currency\":\"" + PIE_JsonEscape(s.profit_currency) + "\"";
   js += ",\"margin_currency\":\"" + PIE_JsonEscape(s.margin_currency) + "\"";
   js += ",\"spec_quality\":" + IntegerToString(s.spec_quality);
   js += "}";

   // market
   js += ",\"market\":{";
   js += "\"bid\":" + PIE_JsonFloatOrNull(s.bid, prec);
   js += ",\"ask\":" + PIE_JsonFloatOrNull(s.ask, prec);
   js += ",\"mid\":" + PIE_JsonFloatOrNull(s.mid, prec);
   js += ",\"spread_points\":" + PIE_JsonFloatOrNull(s.spread_points, prec);
   js += ",\"spread_ticks\":" + PIE_JsonFloatOrNull(s.spread_ticks, prec);
   js += ",\"tick_age_sec\":" + IntegerToString(s.tick_age_sec);
   js += "}";

   // cost
   js += ",\"cost\":{";
   js += "\"value_per_point_money\":" + PIE_JsonFloatOrNull(s.value_per_point_money, prec);
   js += ",\"value_per_tick_money\":" + PIE_JsonFloatOrNull(s.value_per_tick_money, prec);
   js += ",\"margin_1lot_money\":" + PIE_JsonFloatOrNull(s.margin_1lot_money, prec);
   js += ",\"spread_cost_money\":" + PIE_JsonFloatOrNull(s.spread_cost_money, prec);
   js += ",\"total_friction_money\":" + PIE_JsonFloatOrNull(s.total_friction_money, prec);
   js += ",\"total_friction_points\":" + PIE_JsonFloatOrNull(s.total_friction_points, prec);
   js += "}";

   // hydration / history status (Batch 4)
   js += ",\"hydration\":{";
   js += "\"ready_tick\":" + PIE_JsonBool(s.ready_tick);
   js += ",\"ready_spec\":" + PIE_JsonBool(s.ready_spec);
   js += ",\"ready_m1\":" + PIE_JsonBool(s.ready_m1);
   js += ",\"ready_m5\":" + PIE_JsonBool(s.ready_m5);
   js += ",\"ready_m15\":" + PIE_JsonBool(s.ready_m15);
   js += ",\"ready_d1\":" + PIE_JsonBool(s.ready_d1);
   js += ",\"bars_m1\":" + IntegerToString(s.bars_m1);
   js += ",\"bars_m5\":" + IntegerToString(s.bars_m5);
   js += ",\"bars_m15\":" + IntegerToString(s.bars_m15);
   js += ",\"bars_d1\":" + IntegerToString(s.bars_d1);
   js += ",\"last_bar_m1\":" + IntegerToString((long)s.last_bar_m1);
   js += ",\"last_bar_m5\":" + IntegerToString((long)s.last_bar_m5);
   js += ",\"last_bar_m15\":" + IntegerToString((long)s.last_bar_m15);
   js += ",\"last_bar_d1\":" + IntegerToString((long)s.last_bar_d1);
   js += ",\"fresh_bits\":" + IntegerToString(s.fresh_bits);
   js += "}";

   js += "}";

   return js;
}

string PIE_BuildRotationJSON(const datetime now_server, const datetime now_utc)
{
   int top_flat[];
int top_count_by_sector[];
ArrayResize(top_flat, PIE_SECTOR_COUNT*5);
ArrayResize(top_count_by_sector, PIE_SECTOR_COUNT);

PIE_ComputeTopBySectorFlat(top_flat, top_count_by_sector);

   // status + degraded reasons
   int ready_tick, ready_spec, ready_m1, ready_m5, ready_m15, ready_d1;
   int missing_tick, missing_spec, missing_m1, missing_m5, missing_m15, missing_d1;
   PIE_ComputeCoverage(ready_tick, ready_spec, ready_m1, ready_m5, ready_m15, ready_d1,
                       missing_tick, missing_spec, missing_m1, missing_m5, missing_m15, missing_d1);

   string status = "OK";
   string reasons = "[";
   bool firstR = true;
   if(g_universe_n <= 0) { status = "DEGRADED"; if(!firstR) reasons += ","; firstR=false; reasons += "\"universe_empty\""; }
   if(ready_tick <= 0)   { status = "DEGRADED"; if(!firstR) reasons += ","; firstR=false; reasons += "\"tick_coverage_low\""; }
   if(ready_spec <= 0)   { status = "DEGRADED"; if(!firstR) reasons += ","; firstR=false; reasons += "\"spec_coverage_low\""; }
   if(ready_m1 <= 0)     { status = "DEGRADED"; if(!firstR) reasons += ","; firstR=false; reasons += "\"history_m1_partial\""; }
   reasons += "]";

   string mode_str = (g_mode==MODE_SMALL ? "SMALL" : (g_mode==MODE_MEDIUM ? "MEDIUM" : "LARGE"));

   int tick_budget = (g_mode==MODE_LARGE ? PIE_ClampInt(InpTickBudgetPerSec,250,450) : g_universe_n);
   int spec_budget = PIE_ClampInt(InpSpecBudgetPerSec,10,60);
   int bf_budget   = PIE_ClampInt(InpBackfillBudgetPerSec,3,10);

   string js = "{";

   // meta (stable order)
   js += "\"meta\":{";
   js += "\"schema_version\":\"4.3.0\"";
   js += ",\"feature_version\":\"4.3.0-lts-b1-4\"";
   js += ",\"time_server\":" + IntegerToString((long)now_server);
   js += ",\"time_utc\":" + IntegerToString((long)now_utc);
   js += ",\"broker_company\":\"" + PIE_JsonEscape(g_broker_company) + "\"";
   js += ",\"server\":\"" + PIE_JsonEscape(g_broker_server) + "\"";
   js += ",\"login\":" + IntegerToString(g_account_login);
   js += ",\"account_currency\":\"" + PIE_JsonEscape(g_account_currency) + "\"";
   js += ",\"universe_count\":" + IntegerToString(g_universe_n);
   js += ",\"universe_fingerprint\":\"" + PIE_U32ToHex(g_universe_fp) + "\"";
   js += ",\"mode\":\"" + mode_str + "\"";
   js += ",\"active_target\":" + IntegerToString(g_active_target);
   js += ",\"status\":\"" + status + "\"";
   js += ",\"degraded_reasons\":" + reasons;
   js += ",\"spec_quality_summary\":{";
   js += "\"low\":" + IntegerToString(g_spec_q_counts[0]);
   js += ",\"med\":" + IntegerToString(g_spec_q_counts[1]);
   js += ",\"high\":" + IntegerToString(g_spec_q_counts[2]);
   js += "}";
   js += ",\"sector_counts\":" + PIE_BuildSectorCountsJSON();
   js += ",\"sector_present\":" + PIE_BuildSectorPresentJSON();
   js += ",\"budgets\":{";
   js += "\"tick_per_sec\":" + IntegerToString(tick_budget);
   js += ",\"spec_per_sec\":" + IntegerToString(spec_budget);
   js += ",\"backfill_per_sec\":" + IntegerToString(bf_budget);
   js += "}";
   js += ",\"serialization\":{\"float_precision\":6,\"null_policy\":\"null_for_missing\",\"finite_policy\":\"null_if_nonfinite\"}";
   js += "}";

   // universe
   js += ",\"universe\":{";
   js += "\"only_marketwatch\":" + PIE_JsonBool(InpOnlyMarketWatch);
   js += ",\"universe_max_symbols\":" + IntegerToString(InpUniverseMaxSymbols);
   js += ",\"count\":" + IntegerToString(g_universe_n);
   js += ",\"selected\":" + IntegerToString(g_universe_selected);
   js += ",\"first\":\"" + PIE_JsonEscape(g_universe_first) + "\"";
   js += ",\"last\":\"" + PIE_JsonEscape(g_universe_last) + "\"";
   js += "}";

   // top_by_sector
   js += ",\"top_by_sector\":{";
   for(int sid=0; sid<PIE_SECTOR_COUNT; sid++)
   {
      if(sid>0) js += ",";
      js += "\"" + PIE_SectorName(sid) + "\":[";
      for(int k=0;k<top_count_by_sector[sid];k++)
      {
         if(k>0) js += ",";
         int idx = top_flat[sid*5 + k];
         if(idx >= 0 && idx < g_universe_n)
            js += PIE_BuildSymbolBlockJSON(g_states[idx], 6);
         else
            js += "null";
      }
      js += "]";
   }
   js += "}";

   js += "}";

   return js;
}

string PIE_BuildUniverseJSON(const datetime now_server, const datetime now_utc)
{
   string mode_str = (g_mode==MODE_SMALL ? "SMALL" : (g_mode==MODE_MEDIUM ? "MEDIUM" : "LARGE"));

   string js = "{";
   js += "\"meta\":{";
   js += "\"schema_version\":\"4.3.0\"";
   js += ",\"feature_version\":\"4.3.0-lts-b1-4\"";
   js += ",\"kind\":\"universe_snapshot\"";
   js += ",\"time_server\":" + IntegerToString((long)now_server);
   js += ",\"time_utc\":" + IntegerToString((long)now_utc);
   js += ",\"broker_company\":\"" + PIE_JsonEscape(g_broker_company) + "\"";
   js += ",\"server\":\"" + PIE_JsonEscape(g_broker_server) + "\"";
   js += ",\"login\":" + IntegerToString(g_account_login);
   js += ",\"account_currency\":\"" + PIE_JsonEscape(g_account_currency) + "\"";
   js += ",\"universe_count\":" + IntegerToString(g_universe_n);
   js += ",\"universe_fingerprint\":\"" + PIE_U32ToHex(g_universe_fp) + "\"";
   js += ",\"mode\":\"" + mode_str + "\"";
   js += ",\"sector_counts\":" + PIE_BuildSectorCountsJSON();
   js += ",\"sector_present\":" + PIE_BuildSectorPresentJSON();
   js += ",\"serialization\":{\"float_precision\":12,\"null_policy\":\"null_for_missing\",\"finite_policy\":\"null_if_nonfinite\"}";
   js += "}";

   js += ",\"symbols\":[";
   for(int i=0;i<g_universe_n;i++)
   {
      if(i>0) js += ",";
      js += PIE_BuildSymbolBlockJSON(g_states[i], 12);
   }
   js += "]";

   js += "}";

   return js;
}

string PIE_BuildDebugJSON(const datetime now_server, const datetime now_utc, const bool publish_due, const bool rotation_due, const bool universe_due)
{
   int ready_tick, ready_spec, ready_m1, ready_m5, ready_m15, ready_d1;
   int missing_tick, missing_spec, missing_m1, missing_m5, missing_m15, missing_d1;
   PIE_ComputeCoverage(ready_tick, ready_spec, ready_m1, ready_m5, ready_m15, ready_d1,
                       missing_tick, missing_spec, missing_m1, missing_m5, missing_m15, missing_d1);

   string mode_str = (g_mode==MODE_SMALL ? "SMALL" : (g_mode==MODE_MEDIUM ? "MEDIUM" : "LARGE"));
   const string fp_hex = PIE_U32ToHex(g_universe_fp);

   int limit = (g_universe_n < 5 ? g_universe_n : 5);
   string first5 = "";
   string last5  = "";

   for(int i=0;i<limit;i++)
   {
      if(i>0) first5 += ",";
      first5 += "\"" + PIE_JsonEscape(g_symbols[i]) + "\"";
   }
   for(int i=0;i<limit;i++)
   {
      int idx = g_universe_n - limit + i;
      if(idx < 0) idx = 0;
      if(idx >= g_universe_n) idx = g_universe_n - 1;
      if(i>0) last5 += ",";
      last5 += "\"" + PIE_JsonEscape(g_symbols[idx]) + "\"";
   }

   string js = "{";

   js += "\"schema_version\":\"4.3.0\"";
   js += ",\"feature_version\":\"4.3.0-lts-b1-4\"";
   js += ",\"batch\":\"BATCH4\"";
   js += ",\"now_server\":" + IntegerToString((long)now_server);
   js += ",\"now_utc\":" + IntegerToString((long)now_utc);
   js += ",\"minute_id\":" + IntegerToString((long)(now_server/60));
   js += ",\"last_publish_minute\":" + IntegerToString(g_last_publish_minute);
   js += ",\"publish_due\":" + PIE_JsonBool(publish_due);

   js += ",\"universe\":{";
   js += "\"count\":" + IntegerToString(g_universe_n);
   js += ",\"fingerprint\":\"" + fp_hex + "\"";
   js += ",\"selected\":" + IntegerToString(g_universe_selected);
   js += ",\"mode\":\"" + mode_str + "\"";
   js += ",\"first5\":[" + first5 + "]";
   js += ",\"last5\":[" + last5 + "]";
   js += "}";

   js += ",\"sector_counts\":" + PIE_BuildSectorCountsJSON();
   js += ",\"sector_present\":" + PIE_BuildSectorPresentJSON();

   // coverage
   js += ",\"coverage\":{";
   js += "\"ready_tick\":" + IntegerToString(ready_tick);
   js += ",\"ready_spec\":" + IntegerToString(ready_spec);
   js += ",\"ready_m1\":" + IntegerToString(ready_m1);
   js += ",\"ready_m5\":" + IntegerToString(ready_m5);
   js += ",\"ready_m15\":" + IntegerToString(ready_m15);
   js += ",\"ready_d1\":" + IntegerToString(ready_d1);
   js += ",\"missing_tick\":" + IntegerToString(missing_tick);
   js += ",\"missing_spec\":" + IntegerToString(missing_spec);
   js += ",\"missing_m1\":" + IntegerToString(missing_m1);
   js += ",\"missing_m5\":" + IntegerToString(missing_m5);
   js += ",\"missing_m15\":" + IntegerToString(missing_m15);
   js += ",\"missing_d1\":" + IntegerToString(missing_d1);
   js += ",\"spec_quality\":{";
   js += "\"low\":" + IntegerToString(g_spec_q_counts[0]);
   js += ",\"med\":" + IntegerToString(g_spec_q_counts[1]);
   js += ",\"high\":" + IntegerToString(g_spec_q_counts[2]);
   js += "}";
   js += "}";

   // per-step results
   js += ",\"steps\":{";
   js += "\"tick_step\":{";
   js += "\"processed\":" + IntegerToString(g_diag_tick.processed);
   js += ",\"ok\":" + IntegerToString(g_diag_tick.ok_count);
   js += ",\"fail\":" + IntegerToString(g_diag_tick.fail_count);
   js += ",\"skipped\":" + IntegerToString(g_diag_tick.skipped);
   js += ",\"last_error\":" + IntegerToString(g_diag_tick.last_error);
   js += "}";

   js += ",\"spec_step\":{";
   js += "\"processed\":" + IntegerToString(g_diag_spec.processed);
   js += ",\"ok\":" + IntegerToString(g_diag_spec.ok_count);
   js += ",\"fail\":" + IntegerToString(g_diag_spec.fail_count);
   js += ",\"skipped\":" + IntegerToString(g_diag_spec.skipped);
   js += ",\"last_error\":" + IntegerToString(g_diag_spec.last_error);
   js += "}";

   js += ",\"probes\":{";
   js += "\"vpp\":{";
   js += "\"attempt\":" + IntegerToString(g_diag_probe_vpp.processed);
   js += ",\"ok\":" + IntegerToString(g_diag_probe_vpp.ok_count);
   js += ",\"fail\":" + IntegerToString(g_diag_probe_vpp.fail_count);
   js += ",\"skipped\":" + IntegerToString(g_diag_probe_vpp.skipped);
   js += ",\"last_error\":" + IntegerToString(g_diag_probe_vpp.last_error);
   js += "}";
   js += ",\"margin\":{";
   js += "\"attempt\":" + IntegerToString(g_diag_probe_margin.processed);
   js += ",\"ok\":" + IntegerToString(g_diag_probe_margin.ok_count);
   js += ",\"fail\":" + IntegerToString(g_diag_probe_margin.fail_count);
   js += ",\"skipped\":" + IntegerToString(g_diag_probe_margin.skipped);
   js += ",\"last_error\":" + IntegerToString(g_diag_probe_margin.last_error);
   js += "}";
   js += "}";

   js += ",\"backfill\":{";
   js += "\"m1\":{";
   js += "\"processed\":" + IntegerToString(g_diag_bf_m1.processed);
   js += ",\"ok\":" + IntegerToString(g_diag_bf_m1.ok_count);
   js += ",\"fail\":" + IntegerToString(g_diag_bf_m1.fail_count);
   js += ",\"skipped\":" + IntegerToString(g_diag_bf_m1.skipped);
   js += ",\"last_error\":" + IntegerToString(g_diag_bf_m1.last_error);
   js += "}";
   js += ",\"m5\":{";
   js += "\"processed\":" + IntegerToString(g_diag_bf_m5.processed);
   js += ",\"ok\":" + IntegerToString(g_diag_bf_m5.ok_count);
   js += ",\"fail\":" + IntegerToString(g_diag_bf_m5.fail_count);
   js += ",\"skipped\":" + IntegerToString(g_diag_bf_m5.skipped);
   js += ",\"last_error\":" + IntegerToString(g_diag_bf_m5.last_error);
   js += "}";
   js += ",\"m15\":{";
   js += "\"processed\":" + IntegerToString(g_diag_bf_m15.processed);
   js += ",\"ok\":" + IntegerToString(g_diag_bf_m15.ok_count);
   js += ",\"fail\":" + IntegerToString(g_diag_bf_m15.fail_count);
   js += ",\"skipped\":" + IntegerToString(g_diag_bf_m15.skipped);
   js += ",\"last_error\":" + IntegerToString(g_diag_bf_m15.last_error);
   js += "}";
   js += ",\"d1\":{";
   js += "\"processed\":" + IntegerToString(g_diag_bf_d1.processed);
   js += ",\"ok\":" + IntegerToString(g_diag_bf_d1.ok_count);
   js += ",\"fail\":" + IntegerToString(g_diag_bf_d1.fail_count);
   js += ",\"skipped\":" + IntegerToString(g_diag_bf_d1.skipped);
   js += ",\"last_error\":" + IntegerToString(g_diag_bf_d1.last_error);
   js += "}";
   js += "}";

   js += "}"; // steps

   // publish outcomes (actual)
   js += ",\"publish\":{";
   js += "\"rotation_due\":" + PIE_JsonBool(rotation_due);
   js += ",\"universe_due\":" + PIE_JsonBool(universe_due);
   js += ",\"rotation_attempted\":" + PIE_JsonBool(g_pub.rotation_attempted);
   js += ",\"universe_attempted\":" + PIE_JsonBool(g_pub.universe_attempted);
   js += ",\"rotation_ok\":" + PIE_JsonBool(g_pub.rotation_ok);
   js += ",\"universe_ok\":" + PIE_JsonBool(g_pub.universe_ok);
   js += ",\"debug_ok\":" + PIE_JsonBool(g_pub.debug_ok);
   js += ",\"debug_backup_ok\":" + PIE_JsonBool(g_pub.debug_backup_ok);
   js += ",\"last_error_rotation\":" + IntegerToString(g_pub.last_error_rotation);
   js += ",\"last_error_universe\":" + IntegerToString(g_pub.last_error_universe);
   js += ",\"last_error_debug\":" + IntegerToString(g_pub.last_error_debug);
   js += ",\"last_error_debug_backup\":" + IntegerToString(g_pub.last_error_debug_backup);
   js += "}";

   // files
   js += ",\"files\":{";
   js += "\"rotation_json\":\"" + PIE_JsonEscape(g_rotation_json) + "\"";
   js += ",\"rotation_backup_json\":\"" + PIE_JsonEscape(g_rotation_backup_json) + "\"";
   js += ",\"universe_json\":\"" + PIE_JsonEscape(g_universe_json) + "\"";
   js += ",\"universe_backup_json\":\"" + PIE_JsonEscape(g_universe_backup_json) + "\"";
   js += ",\"debug_json\":\"" + PIE_JsonEscape(g_debug_json) + "\"";
   js += ",\"debug_backup_json\":\"" + PIE_JsonEscape(g_debug_backup_json) + "\"";
   js += "}";

   // io_last
   js += ",\"io_last\":{";
   js += "\"last_file\":\"" + PIE_JsonEscape(g_io_last.last_file) + "\"";
   js += ",\"last_op\":\"" + PIE_JsonEscape(g_io_last.last_op) + "\"";
   js += ",\"open_err\":" + IntegerToString(g_io_last.open_err);
   js += ",\"write_err\":" + IntegerToString(g_io_last.write_err);
   js += ",\"copy_err\":" + IntegerToString(g_io_last.copy_err);
   js += ",\"move_err\":" + IntegerToString(g_io_last.move_err);
   js += ",\"delete_err\":" + IntegerToString(g_io_last.delete_err);
   js += ",\"bytes\":" + IntegerToString(g_io_last.bytes);
   js += ",\"size\":" + IntegerToString((long)g_io_last.size);
   js += "}";

   // stress
   js += ",\"stress\":{";
   js += "\"timer\":{\"tick_count\":" + IntegerToString(g_st.timer_tick_count) + ",\"slip_count\":" + IntegerToString(g_st.timer_slip_count) + "}";
   js += ",\"io\":{\"ok\":" + IntegerToString(g_st.io_ok) + ",\"fail\":" + IntegerToString(g_st.io_fail) + "}";
   js += "}";

   js += "}";

   return js;
}

// ----------------------------
// HUD (optional)
// ----------------------------
void PIE_HUD(const datetime now_server)
{
   if(!InpDbgHUD) return;
   if(InpDebugLevel < DBG_INFO) return;

   string mode_str = (g_mode==MODE_SMALL ? "SMALL" : (g_mode==MODE_MEDIUM ? "MEDIUM" : "LARGE"));
   Comment("PIE v4.3.0 Batch1–4 HUD\n",
           "server_time=", TimeToString(now_server, TIME_DATE|TIME_SECONDS), "\n",
           "mode=", mode_str, " N=", g_universe_n, " fp=", PIE_U32ToHex(g_universe_fp), "\n",
           "spec_q low/med/high=", g_spec_q_counts[0], "/", g_spec_q_counts[1], "/", g_spec_q_counts[2], "\n",
           "io_last: op=", g_io_last.last_op, " file=", g_io_last.last_file, " open=", g_io_last.open_err, " write=", g_io_last.write_err,
           " copy=", g_io_last.copy_err, " del=", g_io_last.delete_err, " size=", g_io_last.size, "\n",
           "timer slips=", g_st.timer_slip_count);
}

// ----------------------------
// MT5 Lifecycle
// ----------------------------
int OnInit()
{
   // Account + terminal info (allowed outside publish)
   g_account_login    = (long)AccountInfoInteger(ACCOUNT_LOGIN);
   g_broker_company   = AccountInfoString(ACCOUNT_COMPANY);
   g_broker_server    = AccountInfoString(ACCOUNT_SERVER);
   g_account_currency = AccountInfoString(ACCOUNT_CURRENCY);

   g_terminal_name    = TerminalInfoString(TERMINAL_NAME);
   g_terminal_build   = (long)TerminalInfoInteger(TERMINAL_BUILD);
   g_common_path      = TerminalInfoString(TERMINAL_COMMONDATA_PATH);

   g_firm_s   = PIE_SanitizeName(g_broker_company, "UNKNOWN_FIRM");
   g_server_s = PIE_SanitizeName(g_broker_server, "UNKNOWN_SERVER");
   g_prefix   = g_firm_s + "_" + g_server_s + "_" + IntegerToString(g_account_login) + "_";

   // JSON outputs
   g_rotation_json        = g_prefix + "rotation.json";
   g_rotation_backup_json = g_prefix + "rotation_backup.json";
   g_universe_json        = g_prefix + "universe.json";
   g_universe_backup_json = g_prefix + "universe_backup.json";
   g_debug_json           = g_prefix + "debug.json";
   g_debug_backup_json    = g_prefix + "debug_backup.json";

   // init counters
   ZeroMemory(g_st);
   g_st.last_timer_sec = 0;

   // init io_last
   PIE_IoLastReset("", "");

   // build universe + classify
   PIE_UniverseBuild();
   PIE_SectorAssignAll();

   if(!EventSetTimer(1))
   {
      Print("[FAULT] EventSetTimer failed");
      return(INIT_FAILED);
   }

   const datetime now_server = TimeCurrent();
   const datetime now_utc    = TimeGMT();

   g_last_publish_minute = (long)(now_server / 60);
   g_last_universe_write_time = 0;

   // warm cache (budgeted)
   PIE_TickStep(now_server);
   PIE_SpecMarketStep(now_server);
   PIE_BackfillStep(now_server);

   // initial publish (best-effort)
   int err_rot=0;
   string rot = PIE_BuildRotationJSON(now_server, now_utc);
   PIE_WriteJsonWithPrevBackup(g_rotation_json, g_rotation_backup_json, rot, err_rot);

   int err_uni=0;
   if(InpEnableUniversePublish)
   {
      string uni = PIE_BuildUniverseJSON(now_server, now_utc);
      if(PIE_WriteJsonWithPrevBackup(g_universe_json, g_universe_backup_json, uni, err_uni))
         g_last_universe_write_time = now_server;
   }

   // initial debug
   ZeroMemory(g_pub);
   g_pub.debug_ok = false;

   bool publish_due = false;
   bool rotation_due = true;
   bool universe_due = (InpEnableUniversePublish ? true : false);

   string dbg = PIE_BuildDebugJSON(now_server, now_utc, publish_due, rotation_due, universe_due);
   int err_dbg=0;
   g_pub.debug_ok = PIE_WriteJsonWithPrevBackup(g_debug_json, g_debug_backup_json, dbg, err_dbg); // debug backup here acts as previous debug; minute-edge snapshot later
   g_pub.last_error_debug = err_dbg;

   // Copy minute-edge debug backup snapshot immediately (best-effort)
   int err_db=0;
   g_pub.debug_backup_ok = PIE_CopyDebugBackupAtMinuteEdge(err_db);
   g_pub.last_error_debug_backup = err_db;

   PIE_LOG_INFO(MODULE_TIMER, 1, "PIE Init", 0, 0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Comment("");
   PIE_LOG_WARN(MODULE_TIMER, 3, "PIE Deinit", reason, 0);
}

void OnTick() { return; }

void OnTimer()
{
   const datetime now_server = TimeCurrent();
   const datetime now_utc    = TimeGMT();

   // timer cadence
   g_st.timer_tick_count++;
   if(g_st.last_timer_sec > 0)
   {
      if(now_server != (g_st.last_timer_sec + 1))
         g_st.timer_slip_count++;
   }
   g_st.last_timer_sec = now_server;

   // reset publish diag for this second
   ZeroMemory(g_pub);
   g_pub.last_error_rotation = 0;
   g_pub.last_error_universe = 0;
   g_pub.last_error_debug = 0;
   g_pub.last_error_debug_backup = 0;

   // Commands (once per second)
   PIE_PollCommandsOncePerSecond(now_server);

   // Steps (budgeted)
   PIE_TickStep(now_server);
   PIE_SpecMarketStep(now_server);
   PIE_BackfillStep(now_server);

   // Determine schedules
   const long cur_min = (long)(now_server / 60);
   const bool publish_due = (cur_min > g_last_publish_minute);

   const bool rotation_due = publish_due;
   bool universe_due = false;

   if(InpEnableUniversePublish)
   {
      int every = (InpUniverseWriteEverySec <= 0 ? 1800 : InpUniverseWriteEverySec);
      if(g_last_universe_write_time <= 0) universe_due = true;
      else if((int)(now_server - g_last_universe_write_time) >= every) universe_due = true;
      if(g_cmd_dump_universe) universe_due = true;
   }
   else
   {
      universe_due = false;
      g_cmd_dump_universe = false;
   }

   // Publish rotation at minute edge (cache-only builder)
   if(rotation_due)
   {
      g_pub.rotation_due = true;
      g_pub.rotation_attempted = true;

      string rot = PIE_BuildRotationJSON(now_server, now_utc);
      int err_rot=0;
      bool ok_rot = PIE_WriteJsonWithPrevBackup(g_rotation_json, g_rotation_backup_json, rot, err_rot);
      g_pub.rotation_ok = ok_rot;
      g_pub.last_error_rotation = err_rot;

      g_last_publish_minute = cur_min; // update after attempt
   }

   // Publish universe (30min or command) (cache-only builder)
   if(universe_due)
   {
      g_pub.universe_due = true;
      g_pub.universe_attempted = true;

      string uni = PIE_BuildUniverseJSON(now_server, now_utc);
      int err_uni=0;
      bool ok_uni = PIE_WriteJsonWithPrevBackup(g_universe_json, g_universe_backup_json, uni, err_uni);
      g_pub.universe_ok = ok_uni;
      g_pub.last_error_universe = err_uni;

      if(ok_uni) g_last_universe_write_time = now_server;
      g_cmd_dump_universe = false;
   }

   // Always publish debug (cache-only builder)
   {
      int err_dbg=0;
      string dbg = PIE_BuildDebugJSON(now_server, now_utc, publish_due, rotation_due, universe_due);
      bool ok_dbg = PIE_WriteJsonAtomicFinal(g_debug_json, dbg,
                                            g_io_last.open_err, g_io_last.write_err, g_io_last.copy_err, g_io_last.delete_err,
                                            g_io_last.bytes, g_io_last.size);
      // note: above updates only raw values; keep io_last names
      g_io_last.last_file = g_debug_json;
      g_io_last.last_op   = "write_debug_json";

      if(ok_dbg) g_st.io_ok++; else g_st.io_fail++;
      g_pub.debug_ok = ok_dbg;
      if(!ok_dbg)
      {
         err_dbg = (g_io_last.copy_err!=0 ? g_io_last.copy_err : (g_io_last.write_err!=0 ? g_io_last.write_err : g_io_last.open_err));
      }
      g_pub.last_error_debug = err_dbg;
   }

   // Minute-edge debug backup snapshot
   if(rotation_due)
   {
      int err_db=0;
      bool ok_db = PIE_CopyDebugBackupAtMinuteEdge(err_db);
      g_pub.debug_backup_ok = ok_db;
      g_pub.last_error_debug_backup = err_db;
   }

   PIE_HUD(now_server);
}
//+------------------------------------------------------------------+