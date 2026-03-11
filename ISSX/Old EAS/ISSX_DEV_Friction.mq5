//+------------------------------------------------------------------+
//| ISSX_DEV_Friction.mq5                                            |
//| DEV EA #1 (Blueprint-Strict): Universe + LightSpec + Friction +   |
//| Stage A candidates export (NO trading, deterministic, isolated)   |
//|                                                                  |
//| ISS-X v12 STABLE+EIM (DEV Module)                                |
//| Stage order preserved:                                           |
//|   Step 0 Metadata → Step 1 Universe → Step 2 LightSpec(+TickProbe)|
//|   Step 3 Friction Sampling → Step 4 Stage A ranking/export        |
//|                                                                  |
//| TEST EXPORT MODE (per your request):                             |
//|   Only 2 JSON outputs + binary state:                            |
//|     - iss_snapshot_latest.json                                   |
//|     - iss_snapshot_YYYYMMDD_HHMMSS.json                          |
//|     - iss_friction_state.bin (persistent ring buffers)           |
//|                                                                  |
//| NOTE: This DEV EA does NOT do: Structural, Battlefield, EIM,      |
//| Correlation, DeepSpec, Calendar, Fundamentals.                    |
//+------------------------------------------------------------------+
#property strict
#property version   "12.00"
#property description "ISSX DEV EA #1: Universe + LightSpec + Friction + StageA (NO trading)"

//==============================
// ISS-X VERSIONING
//==============================
#define ISS_VERSION    "12.00"
#define SCHEMA_VERSION "12.00"

//==============================
// INPUTS (Blueprint subset for DEV #1)
//==============================
input int  SampleSeconds            = 10;
input int  FrictionWindowMinutes    = 60;
input int  RecomputeMinutes         = 60;     // hourly refresh (final rule)
input int  MaxSymbolsPerSampleTick  = 60;     // round-robin sampling budget
input int  MaxTickAgeSeconds        = 300;    // stale tick cutoff (critical)

input int  StageA_K_Default         = 50;
input int  ATR_Period               = 14;     // iATR PERIOD_H1

input bool EnablePopups             = false;  // popups only AFTER verified disk writes
input int  LogEvery                 = 50;     // Print progress every N sampling ticks

// Snapshot outputs (2 JSON files only: latest + stamped)
input bool EnableSnapshotStamped    = true;   // if false: latest only (still deterministic)

//==============================
// INTERNAL CONSTANTS
//==============================
#define TF_ATR PERIOD_H1
#define TINY   1e-12
#define MAX_RING_HARD_CAP 10000  // safety
#define INF_AGE 2147483647

// Quantization (ordering stability)
#define Q_SPREAD_TO_ATR   10
#define Q_SPREAD_BPS       8
#define Q_STABILITY_RATIO 10
#define Q_TICK_DENSITY     8

//==============================
// GLOBALS (Isolation / Paths)
//==============================
string g_out_folder    = "";
string g_engine_tag    = "Friction";
string g_folder_prefix = "ISSX_DEV_";

//==============================
// GLOBALS (Universe)
//==============================
string g_syms[];          // sorted universe symbols
int    g_universe_n = 0;

// round-robin pointer for sampling (persisted in state file, appended)
int    g_rr_index = 0;

//==============================
// GLOBALS (Timing)
//==============================
datetime g_last_sample_time    = 0;
datetime g_last_recompute_time = 0;

//==============================
// STATE LOAD STATUS (exported)
//==============================
string g_state_load_status  = "NOT_ATTEMPTED"; // OK / MISSING / MISMATCH_RESET / READ_ERROR / NOT_ATTEMPTED
string g_state_load_message = "";

//==============================
// LIGHTSPEC (minimal subset for friction/stageA)
//==============================
struct LightSpec
{
   // identity
   string description;
   string path;
   string currency_base;
   string currency_profit;
   string currency_margin;

   // core integers
   long digits;
   long trade_calc_mode;
   long trade_mode;
   long stops_level;
   long freeze_level;
   long swap_mode;
   long swap_rollover3days;

   // core doubles
   double point;
   double contract_size;
   double tick_size;
   double tick_value;
   double tick_value_profit;
   double tick_value_loss;

   double volume_min;
   double volume_max;
   double volume_step;

   double swap_long;
   double swap_short;

   // availability flags
   bool has_point;
   bool has_tick_size;
   bool has_contract_size;
   bool has_tick_value;
   bool has_tick_value_profit;
   bool has_tick_value_loss;

   bool has_vol_min;
   bool has_vol_max;
   bool has_vol_step;

   bool has_swap_long;
   bool has_swap_short;
};

LightSpec g_ls[];   // parallel to g_syms

//==============================
// FRICTION RING BUFFER (persistent)
//==============================
struct FrictionBuf
{
   // ring arrays
   int    tsec[];     // server-time seconds (int) for sample time
   double spread[];   // spread in points at that time

   int head;          // next write index
   int count;         // number of valid samples stored (<= capacity)

   // last tick state (latest probe)
   bool tick_available;
   int  tick_last_error;
   long tick_age_seconds;    // last measured (or INF)
   double last_bid;
   double last_ask;
   datetime last_tick_time;  // tick.time if available
};

FrictionBuf g_fb[];   // parallel to g_syms

int g_ring_capacity        = 0;
int g_min_samples_required = 0;

//==============================
// JSON HELPERS (comma-safe, deterministic)
//==============================
string JsonEscape(string s)
{
   StringReplace(s, "\\", "\\\\");
   StringReplace(s, "\"", "\\\"");
   StringReplace(s, "\r", "\\r");
   StringReplace(s, "\n", "\\n");
   StringReplace(s, "\t", "\\t");
   return s;
}
string B2S(bool v) { return (v ? "true" : "false"); }
string I2S(long v) { return IntegerToString((int)v); }
string L2S(long v) { return IntegerToString((int)v); }
string D2S(double v, int digits) { return DoubleToString(v, digits); }

double Q(double v, int digits)
{
   return NormalizeDouble(v, digits);
}

//==============================
// FILE / ATOMIC WRITE HELPERS
//==============================
string Sanitize(string s)
{
   StringReplace(s," ","_");
   StringReplace(s,"/","_");
   StringReplace(s,"\\","_");
   StringReplace(s,":","_");
   StringReplace(s,"*","_");
   StringReplace(s,"?","_");
   StringReplace(s,"\"","_");
   StringReplace(s,"<","_");
   StringReplace(s,">","_");
   StringReplace(s,"|","_");
   return s;
}

string Stamp(datetime t_server)
{
   // Deterministic timestamp string: YYYYMMDD_HHMMSS (server time)
   MqlDateTime st; TimeToStruct(t_server, st);
   return StringFormat("%04d%02d%02d_%02d%02d%02d", st.year, st.mon, st.day, st.hour, st.min, st.sec);
}

bool EnsureFolder(string folder_rel)
{
   ResetLastError();
   if(FolderCreate(folder_rel))
      return true;

   int err = GetLastError();
   // 5019 = ERR_FILE_ALREADY_EXISTS (common)
   if(err == 5019 || err == 0)
      return true;

   return false;
}

bool BasicJsonLooksValid(const string &content)
{
   int n = StringLen(content);
   if(n < 2) return false;
   // strip leading whitespace
   int i = 0;
   while(i < n)
   {
      ushort ch = StringGetCharacter(content, i);
      if(ch!=' ' && ch!='\n' && ch!='\r' && ch!='\t') break;
      i++;
   }
   if(i >= n) return false;
   if(StringGetCharacter(content, i) != '{') return false;

   // strip trailing whitespace
   int j = n - 1;
   while(j >= 0)
   {
      ushort ch2 = StringGetCharacter(content, j);
      if(ch2!=' ' && ch2!='\n' && ch2!='\r' && ch2!='\t') break;
      j--;
   }
   if(j < 0) return false;
   if(StringGetCharacter(content, j) != '}') return false;

   return true;
}

bool AtomicWriteText(const string rel_final, const string content, string &err_out)
{
   err_out = "";

   if(!BasicJsonLooksValid(content))
   {
      err_out = "content failed basic JSON sanity (must start '{' and end '}')";
      return false;
   }

   string rel_tmp = rel_final + ".tmp";

   ResetLastError();
   int h = FileOpen(rel_tmp, FILE_WRITE|FILE_TXT);
   if(h == INVALID_HANDLE)
   {
      err_out = "FileOpen(tmp) failed err=" + IntegerToString(GetLastError());
      return false;
   }

   FileWriteString(h, content);
   FileFlush(h);

   ulong sz = FileSize(h);     // <-- IMPORTANT: sz defined here
   FileClose(h);

   if(sz < 2)
   {
            if(FileIsExist(rel_tmp)) FileDelete(rel_tmp);
      return false;
   }

   // verify tmp exists and is readable
   ResetLastError();
   int vr = FileOpen(rel_tmp, FILE_READ|FILE_TXT);
   if(vr == INVALID_HANDLE)
   {
      err_out = "Verify open(tmp) failed err=" + IntegerToString(GetLastError());
      return false;
   }
   FileClose(vr);

   // replace final (strict)
   if(FileIsExist(rel_final))
   {
      ResetLastError();
      if(!FileDelete(rel_final))
      {
         err_out = "FileDelete(final) failed err=" + IntegerToString(GetLastError());
         return false;
      }
   }

   ResetLastError();
   if(!FileMove(rel_tmp, 0, rel_final, 0))
   {
      err_out = "FileMove(tmp->final) failed err=" + IntegerToString(GetLastError());
      return false;
   }

   // final verify
   ResetLastError();
   int vf = FileOpen(rel_final, FILE_READ|FILE_TXT);
   if(vf == INVALID_HANDLE)
   {
      err_out = "Verify open(final) failed err=" + IntegerToString(GetLastError());
      return false;
   }
   FileClose(vf);

   return true;
}

//==============================
// TIME HELPERS (server time preferred; deterministic fallback)
//==============================
datetime NowServer(bool &used_fallback)
{
   used_fallback = false;
   datetime t = TimeTradeServer();
   if(t <= 0)
   {
      used_fallback = true;
      t = TimeCurrent();
   }
   return t;
}

//==============================
// BINARY STATE PERSISTENCE (friction buffers)
//==============================
string StateFileRel() { return (g_out_folder + "iss_friction_state.bin"); }

bool SaveFrictionState(string &err_out)
{
   err_out = "";
   string fn  = StateFileRel();
   string tmp = fn + ".tmp";

   ResetLastError();
   int h = FileOpen(tmp, FILE_WRITE|FILE_BIN);
   if(h == INVALID_HANDLE)
   {
      err_out = "Save: FileOpen(tmp) failed err=" + IntegerToString(GetLastError());
      return false;
   }

   // header (keep backward compatible layout; append extras at end only)
   FileWriteString(h, ISS_VERSION);
   FileWriteInteger(h, 0, INT_VALUE); // separator/int marker (deterministic)
   FileWriteString(h, SCHEMA_VERSION);
   FileWriteInteger(h, SampleSeconds, INT_VALUE);
   FileWriteInteger(h, FrictionWindowMinutes, INT_VALUE);
   FileWriteInteger(h, MaxTickAgeSeconds, INT_VALUE);
   FileWriteInteger(h, g_universe_n, INT_VALUE);
   FileWriteInteger(h, g_ring_capacity, INT_VALUE);

   for(int i=0;i<g_universe_n;i++)
   {
      FileWriteString(h, g_syms[i]);

      // store last tick state
      FileWriteInteger(h, (g_fb[i].tick_available ? 1 : 0), INT_VALUE);
      FileWriteInteger(h, (int)g_fb[i].tick_age_seconds, INT_VALUE);
      FileWriteInteger(h, (int)g_fb[i].tick_last_error, INT_VALUE);
      FileWriteDouble(h, g_fb[i].last_bid);
      FileWriteDouble(h, g_fb[i].last_ask);
      FileWriteInteger(h, (int)g_fb[i].last_tick_time, INT_VALUE);

      // ring
      FileWriteInteger(h, g_fb[i].count, INT_VALUE);
      FileWriteInteger(h, g_fb[i].head, INT_VALUE);

      int cap = g_ring_capacity;
      for(int k=0;k<cap;k++)
         FileWriteInteger(h, g_fb[i].tsec[k], INT_VALUE);
      for(int k=0;k<cap;k++)
         FileWriteDouble(h, g_fb[i].spread[k]);
   }

   // append optional extras (backward compatible)
   FileWriteInteger(h, g_rr_index, INT_VALUE);

   FileFlush(h);
   FileClose(h);

   // atomic replace
   if(FileIsExist(fn))
   {
      ResetLastError();
      if(!FileDelete(fn))
      {
         err_out = "Save: FileDelete(final) failed err=" + IntegerToString(GetLastError());
         return false;
      }
   }

   ResetLastError();
   if(!FileMove(tmp, 0, fn, 0))
   {
      err_out = "Save: FileMove failed err=" + IntegerToString(GetLastError());
      return false;
   }

   return true;
}

bool LoadFrictionState(string &err_out)
{
   err_out = "";
   string fn = StateFileRel();

   if(!FileIsExist(fn))
   {
      err_out = "state file missing (first run)";
      return false; // not fatal
   }

   ResetLastError();
   int h = FileOpen(fn, FILE_READ|FILE_BIN);
   if(h == INVALID_HANDLE)
   {
      err_out = "Load: FileOpen failed err=" + IntegerToString(GetLastError());
      return false;
   }

   // read header
   string ver    = FileReadString(h);
   int    sep    = FileReadInteger(h, INT_VALUE);
   string schema = FileReadString(h);

   int ss  = FileReadInteger(h, INT_VALUE);
   int fwm = FileReadInteger(h, INT_VALUE);
   int mta = FileReadInteger(h, INT_VALUE);
   int n   = FileReadInteger(h, INT_VALUE);
   int cap = FileReadInteger(h, INT_VALUE);

   bool ok = true;
   if(ver != ISS_VERSION) ok=false;
   if(schema != SCHEMA_VERSION) ok=false;
   if(ss != SampleSeconds) ok=false;
   if(fwm != FrictionWindowMinutes) ok=false;
   if(mta != MaxTickAgeSeconds) ok=false;
   if(n  != g_universe_n) ok=false;
   if(cap!= g_ring_capacity) ok=false;

   if(!ok)
   {
      FileClose(h);
      err_out = "Load: schema mismatch → reset state";
      return false;
   }

   // read per symbol (file order is whatever it was saved with; we match by symbol)
   for(int j=0;j<n;j++)
   {
      string sym = FileReadString(h);

      int tick_av   = FileReadInteger(h, INT_VALUE);
      int tick_age  = FileReadInteger(h, INT_VALUE);
      int tick_err  = FileReadInteger(h, INT_VALUE);
      double lb     = FileReadDouble(h);
      double la     = FileReadDouble(h);
      int ltt       = FileReadInteger(h, INT_VALUE);

      int cnt       = FileReadInteger(h, INT_VALUE);
      int head      = FileReadInteger(h, INT_VALUE);

      // validate cnt/head (corruption hardening)
      if(cnt < 0 || cnt > cap) cnt = 0;
      if(head < 0 || head >= cap) head = 0;

      int idx = -1;
      for(int i=0;i<g_universe_n;i++)
      {
         if(g_syms[i] == sym) { idx = i; break; }
      }

      int tarr[];
      double sarr[];
      ArrayResize(tarr, cap);
      ArrayResize(sarr, cap);

      for(int k=0;k<cap;k++) tarr[k] = FileReadInteger(h, INT_VALUE);
      for(int k=0;k<cap;k++) sarr[k] = FileReadDouble(h);

      if(idx >= 0)
      {
         g_fb[idx].tick_available   = (tick_av == 1);
         g_fb[idx].tick_age_seconds = (long)tick_age;
         g_fb[idx].tick_last_error  = tick_err;
         g_fb[idx].last_bid         = lb;
         g_fb[idx].last_ask         = la;
         g_fb[idx].last_tick_time   = (datetime)ltt;

         g_fb[idx].count = cnt;
         g_fb[idx].head  = head;

         // ensure arrays are sized (they should be after RingInit)
         if(ArraySize(g_fb[idx].tsec) != cap)   ArrayResize(g_fb[idx].tsec, cap);
         if(ArraySize(g_fb[idx].spread) != cap) ArrayResize(g_fb[idx].spread, cap);

         for(int k=0;k<cap;k++) g_fb[idx].tsec[k]   = tarr[k];
         for(int k=0;k<cap;k++) g_fb[idx].spread[k] = sarr[k];
      }
   }

   // optional appended rr_index (if present)
   if(!FileIsEnding(h))
   {
      int rr = FileReadInteger(h, INT_VALUE);
      if(rr >= 0 && rr < g_universe_n) g_rr_index = rr;
   }

   FileClose(h);
   return true;
}

//==============================
// RING BUFFER OPS
//==============================
void RingInit(int idx)
{
   ArrayResize(g_fb[idx].tsec, g_ring_capacity);
   ArrayResize(g_fb[idx].spread, g_ring_capacity);

   for(int k=0;k<g_ring_capacity;k++)
   {
      g_fb[idx].tsec[k]   = 0;
      g_fb[idx].spread[k] = 0.0;
   }

   g_fb[idx].head = 0;
   g_fb[idx].count = 0;

   g_fb[idx].tick_available = false;
   g_fb[idx].tick_last_error = 0;
   g_fb[idx].tick_age_seconds = INF_AGE;
   g_fb[idx].last_bid = 0.0;
   g_fb[idx].last_ask = 0.0;
   g_fb[idx].last_tick_time = 0;
}

void PruneRing(int idx, int now_sec)
{
   int window_sec = FrictionWindowMinutes * 60;
   if(window_sec <= 0) return;

   int cap = g_ring_capacity;
   int cnt = g_fb[idx].count;

   if(cnt <= 0) return;
   if(cnt > cap) cnt = cap; // safety

   int new_t[];
   double new_s[];
   ArrayResize(new_t, cap);
   ArrayResize(new_s, cap);

   int keep = 0;

   for(int j=0;j<cnt;j++)
   {
      int pos = g_fb[idx].head - cnt + j;
      while(pos < 0) pos += cap;
      if(pos >= cap) pos %= cap;

      int ts = g_fb[idx].tsec[pos];
      double sp = g_fb[idx].spread[pos];

      if(ts > 0)
      {
         int age = now_sec - ts;
         if(age >= 0 && age <= window_sec)
         {
            new_t[keep] = ts;
            new_s[keep] = sp;
            keep++;
         }
      }
   }

   for(int k=0;k<cap;k++)
   {
      if(k < keep)
      {
         g_fb[idx].tsec[k]   = new_t[k];
         g_fb[idx].spread[k] = new_s[k];
      }
      else
      {
         g_fb[idx].tsec[k]   = 0;
         g_fb[idx].spread[k] = 0.0;
      }
   }

   g_fb[idx].count = keep;
   g_fb[idx].head  = (keep % cap);
}

void RingAddSample(int idx, int tsec, double spread_points)
{
   int cap = g_ring_capacity;

   g_fb[idx].tsec[g_fb[idx].head]   = tsec;
   g_fb[idx].spread[g_fb[idx].head] = spread_points;

   g_fb[idx].head++;
   if(g_fb[idx].head >= cap) g_fb[idx].head = 0;

   if(g_fb[idx].count < cap) g_fb[idx].count++;
}

//==============================
// UNIVERSE + LIGHTSPEC SAFE FETCHERS
//==============================
bool GetIntSafe(const string sym, const ENUM_SYMBOL_INFO_INTEGER prop, long &outv)
{
   ResetLastError();
   bool ok = SymbolInfoInteger(sym, prop, outv);
   return ok;
}

bool GetDblSafe(const string sym, const ENUM_SYMBOL_INFO_DOUBLE prop, double &outv)
{
   ResetLastError();
   bool ok = SymbolInfoDouble(sym, prop, outv);
   return ok;
}

bool GetStrSafe(const string sym, const ENUM_SYMBOL_INFO_STRING prop, string &outv)
{
   ResetLastError();
   bool ok = SymbolInfoString(sym, prop, outv);
   return ok;
}

void BuildUniverse()
{
   int total = SymbolsTotal(true);
   if(total < 0) total = 0;

   ArrayResize(g_syms, total);
   int count = 0;

   for(int i=0;i<total;i++)
   {
      string s = SymbolName(i, true);
      if(s == "") continue;

      // Universe = Market Watch only (SymbolName(i,true) already implies it)
      // SymbolSelect is still called best-effort to ensure subsequent SymbolInfo works.
      SymbolSelect(s, true);

      g_syms[count] = s;
      count++;
   }

   g_universe_n = count;
   ArrayResize(g_syms, g_universe_n);
   ArraySort(g_syms);

   ArrayResize(g_ls, g_universe_n);
   ArrayResize(g_fb, g_universe_n);

   int window_sec = FrictionWindowMinutes * 60;
   int expected = 0;
   if(SampleSeconds > 0 && window_sec > 0)
      expected = (window_sec / SampleSeconds);

   g_ring_capacity = expected + 4;
   if(g_ring_capacity < 16) g_ring_capacity = 16;
   if(g_ring_capacity > MAX_RING_HARD_CAP) g_ring_capacity = MAX_RING_HARD_CAP;

   int q = (expected * 25) / 100;
   if(q < 5) q = 5;
   g_min_samples_required = q;

   for(int i=0;i<g_universe_n;i++)
      RingInit(i);

   // keep rr in range
   if(g_rr_index < 0 || g_rr_index >= g_universe_n) g_rr_index = 0;
}

void CaptureLightSpecAll()
{
   for(int i=0;i<g_universe_n;i++)
   {
      string s = g_syms[i];
      LightSpec ls;

      ls.description = "";
      ls.path = "";
      ls.currency_base = "";
      ls.currency_profit = "";
      ls.currency_margin = "";

      GetStrSafe(s, SYMBOL_DESCRIPTION, ls.description);
      GetStrSafe(s, SYMBOL_PATH, ls.path);
      GetStrSafe(s, SYMBOL_CURRENCY_BASE, ls.currency_base);
      GetStrSafe(s, SYMBOL_CURRENCY_PROFIT, ls.currency_profit);
      GetStrSafe(s, SYMBOL_CURRENCY_MARGIN, ls.currency_margin);

      ls.digits = 0;
      ls.trade_calc_mode = 0;
      ls.trade_mode = 0;
      ls.stops_level = 0;
      ls.freeze_level = 0;
      ls.swap_mode = 0;
      ls.swap_rollover3days = 0;

      GetIntSafe(s, SYMBOL_DIGITS, ls.digits);
      GetIntSafe(s, SYMBOL_TRADE_CALC_MODE, ls.trade_calc_mode);
      GetIntSafe(s, SYMBOL_TRADE_MODE, ls.trade_mode);
      GetIntSafe(s, SYMBOL_TRADE_STOPS_LEVEL, ls.stops_level);
      GetIntSafe(s, SYMBOL_TRADE_FREEZE_LEVEL, ls.freeze_level);
      GetIntSafe(s, SYMBOL_SWAP_MODE, ls.swap_mode);
      GetIntSafe(s, SYMBOL_SWAP_ROLLOVER3DAYS, ls.swap_rollover3days);

      ls.point = 0;
      ls.contract_size = 0;
      ls.tick_size = 0;
      ls.tick_value = 0;
      ls.tick_value_profit = 0;
      ls.tick_value_loss = 0;

      ls.volume_min = 0;
      ls.volume_max = 0;
      ls.volume_step = 0;

      ls.swap_long = 0;
      ls.swap_short = 0;

      ls.has_point = GetDblSafe(s, SYMBOL_POINT, ls.point);
      ls.has_contract_size = GetDblSafe(s, SYMBOL_TRADE_CONTRACT_SIZE, ls.contract_size);

      ls.has_tick_size = GetDblSafe(s, SYMBOL_TRADE_TICK_SIZE, ls.tick_size);
      ls.has_tick_value = GetDblSafe(s, SYMBOL_TRADE_TICK_VALUE, ls.tick_value);
      ls.has_tick_value_profit = GetDblSafe(s, SYMBOL_TRADE_TICK_VALUE_PROFIT, ls.tick_value_profit);
      ls.has_tick_value_loss = GetDblSafe(s, SYMBOL_TRADE_TICK_VALUE_LOSS, ls.tick_value_loss);

      ls.has_vol_min  = GetDblSafe(s, SYMBOL_VOLUME_MIN, ls.volume_min);
      ls.has_vol_max  = GetDblSafe(s, SYMBOL_VOLUME_MAX, ls.volume_max);
      ls.has_vol_step = GetDblSafe(s, SYMBOL_VOLUME_STEP, ls.volume_step);

      ls.has_swap_long = GetDblSafe(s, SYMBOL_SWAP_LONG, ls.swap_long);
      ls.has_swap_short = GetDblSafe(s, SYMBOL_SWAP_SHORT, ls.swap_short);

      g_ls[i] = ls;
   }
}

void ProbeTicksAll(datetime now_server)
{
   for(int i=0;i<g_universe_n;i++)
   {
      MqlTick tk;
      ResetLastError();
      bool ok = SymbolInfoTick(g_syms[i], tk);
      int err = GetLastError();

      g_fb[i].tick_available = ok;
      g_fb[i].tick_last_error = (ok ? 0 : err);

      if(!ok)
      {
         g_fb[i].tick_age_seconds = INF_AGE;
         g_fb[i].last_bid = 0.0;
         g_fb[i].last_ask = 0.0;
         g_fb[i].last_tick_time = 0;
         continue;
      }

      long age = (long)(now_server - tk.time);
      if(age < 0) age = INF_AGE;

      g_fb[i].tick_age_seconds = age;
      g_fb[i].last_bid = tk.bid;
      g_fb[i].last_ask = tk.ask;
      g_fb[i].last_tick_time = tk.time;
   }
}

//==============================
// SAMPLING (Timer A)
//==============================
void SamplingTick()
{
   if(g_universe_n <= 0) return;
   if(MaxSymbolsPerSampleTick <= 0) return;

   bool used_fallback = false;
   datetime now_server = NowServer(used_fallback);
   int now_sec = (int)now_server;

   int budget = MaxSymbolsPerSampleTick;
   if(budget > g_universe_n) budget = g_universe_n;

   for(int j=0;j<budget;j++)
   {
      int idx = g_rr_index;
      g_rr_index++;
      if(g_rr_index >= g_universe_n) g_rr_index = 0;

      PruneRing(idx, now_sec);

      MqlTick tk;
      ResetLastError();
      bool ok = SymbolInfoTick(g_syms[idx], tk);
      int err = GetLastError();

      g_fb[idx].tick_available = ok;
      g_fb[idx].tick_last_error = (ok ? 0 : err);

      if(!ok)
      {
         g_fb[idx].tick_age_seconds = INF_AGE;
         g_fb[idx].last_bid = 0.0;
         g_fb[idx].last_ask = 0.0;
         g_fb[idx].last_tick_time = 0;
         continue;
      }

      long age = (long)(now_server - tk.time);
      if(age < 0) age = INF_AGE;

      g_fb[idx].tick_age_seconds = age;
      g_fb[idx].last_bid = tk.bid;
      g_fb[idx].last_ask = tk.ask;
      g_fb[idx].last_tick_time = tk.time;

      // Only add friction sample if tick is fresh and point is available
      if(age <= MaxTickAgeSeconds)
      {
         if(!g_ls[idx].has_point) continue;
         double pt = g_ls[idx].point;
         if(pt <= 0.0) continue;

         double spread_points = (tk.ask - tk.bid) / pt;
         if(spread_points < 0.0) continue;

         RingAddSample(idx, now_sec, spread_points);
      }
   }
}

//==============================
// STAGE A METRICS + SORT
//==============================
struct StageAItem
{
   string symbol;
   int    universe_index;

   int    samples;
   double spread_mean;
   double spread_std;
   double stability_ratio;
   double spread_bps;
   double spread_to_atr;
   bool   atr_missing;
   int    spikes;
   double tick_density;

   bool   tick_ok;
   long   tick_age;

   int    stageA_rank;
};

double Mean(double &x[], int n)
{
   if(n <= 0) return 0.0;
   double sum = 0.0;
   for(int i=0;i<n;i++) sum += x[i];
   return sum / (double)n;
}

double StdDevSample(double &x[], int n, double mean)
{
   if(n < 2) return 0.0;
   double acc = 0.0;
   for(int i=0;i<n;i++)
   {
      double d = x[i] - mean;
      acc += d*d;
   }
   double var = acc / (double)(n - 1);
   if(var < 0.0) var = 0.0;
   return MathSqrt(var);
}

int CountSpikes3Sigma(double &x[], int n, double mean, double sd)
{
   if(n <= 0) return 0;
   if(sd <= 0.0) return 0;
   double thr = mean + 3.0 * sd;
   int c = 0;
   for(int i=0;i<n;i++)
      if(x[i] > thr) c++;
   return c;
}

bool GetATRPoints(const string sym, double point, double &atr_points)
{
   atr_points = 0.0;
   if(point <= 0.0) return false;

   int hATR = iATR(sym, TF_ATR, ATR_Period);
   if(hATR == INVALID_HANDLE) return false;

   double buf[];
   ArrayResize(buf, 1);

   int got = CopyBuffer(hATR, 0, 0, 1, buf);
   IndicatorRelease(hATR);

   if(got < 1) return false;

   double atr_price = buf[0];
   if(atr_price <= 0.0) return false;

   atr_points = atr_price / point;
   if(atr_points <= 0.0) return false;

   return true;
}

void SortStageA(StageAItem &arr[], int n)
{
   // stable insertion sort (n is small; bounded by StageA_K_Default)
   for(int i=1;i<n;i++)
   {
      StageAItem key = arr[i];
      int j = i - 1;

      while(j >= 0)
      {
         int cmp = 0;

         // 1) atr_missing false first
         if(key.atr_missing != arr[j].atr_missing)
            cmp = (key.atr_missing ? 1 : -1);

         // 2) spread_to_atr asc
         else if(key.spread_to_atr < arr[j].spread_to_atr) cmp = -1;
         else if(key.spread_to_atr > arr[j].spread_to_atr) cmp =  1;

         // 3) spread_bps asc
         else if(key.spread_bps < arr[j].spread_bps)       cmp = -1;
         else if(key.spread_bps > arr[j].spread_bps)       cmp =  1;

         // 4) stability_ratio asc
         else if(key.stability_ratio < arr[j].stability_ratio) cmp = -1;
         else if(key.stability_ratio > arr[j].stability_ratio) cmp =  1;

         // 5) spikes asc
         else if(key.spikes < arr[j].spikes)               cmp = -1;
         else if(key.spikes > arr[j].spikes)               cmp =  1;

         // 6) tick_density desc
         else if(key.tick_density > arr[j].tick_density)   cmp = -1;
         else if(key.tick_density < arr[j].tick_density)   cmp =  1;

         // 7) symbol asc
         else if(key.symbol < arr[j].symbol)               cmp = -1;
         else if(key.symbol > arr[j].symbol)               cmp =  1;
         else cmp = 0;

         if(cmp < 0)
         {
            arr[j+1] = arr[j];
            j--;
         }
         else break;
      }

      arr[j+1] = key;
   }
}

bool BuildStageA(StageAItem &out_stageA[], int &out_n, int &stale_count, int &sampled_symbols_count)
{
   out_n = 0;
   stale_count = 0;
   sampled_symbols_count = 0;

   if(g_universe_n <= 0) return false;

   int Kcap = StageA_K_Default;
   if(Kcap > g_universe_n) Kcap = g_universe_n;
   if(Kcap < 0) Kcap = 0;

   StageAItem tmp[];
   ArrayResize(tmp, g_universe_n);

   bool used_fallback = false;
   datetime now_server = NowServer(used_fallback);
   int now_sec = (int)now_server;

   int cand = 0;

   // Expected samples for normalized density (deterministic)
   int expected = 0;
   if(SampleSeconds > 0 && FrictionWindowMinutes > 0)
      expected = (FrictionWindowMinutes * 60) / SampleSeconds;

   for(int i=0;i<g_universe_n;i++)
   {
      PruneRing(i, now_sec);

      bool tick_ok = g_fb[i].tick_available;
      long age = g_fb[i].tick_age_seconds;
      bool stale = (!tick_ok || age > MaxTickAgeSeconds);

      if(stale) stale_count++;

      int cnt = g_fb[i].count;
      if(cnt > 0) sampled_symbols_count++;

      // Stage A candidates exclude stale AND require min samples
      if(stale) continue;
      if(cnt < g_min_samples_required) continue;

      double xs[];
      ArrayResize(xs, cnt);

      int cap = g_ring_capacity;
      for(int j=0;j<cnt;j++)
      {
         int pos = g_fb[i].head - cnt + j;
         while(pos < 0) pos += cap;
         if(pos >= cap) pos %= cap;
         xs[j] = g_fb[i].spread[pos];
      }

      double mean = Mean(xs, cnt);
      double sd   = StdDevSample(xs, cnt, mean);

      double stab = (mean > TINY ? (sd / mean) : 0.0);
      int spikes  = CountSpikes3Sigma(xs, cnt, mean, sd);

      double bid = g_fb[i].last_bid;
      double ask = g_fb[i].last_ask;
      double mid = (bid + ask) * 0.5;

      double spread_bps = 0.0;
      if(mid > TINY)
         spread_bps = ((ask - bid) / mid) * 10000.0;

      double atr_pts = 0.0;
      double pt = (g_ls[i].has_point ? g_ls[i].point : 0.0);
      bool atr_ok = GetATRPoints(g_syms[i], pt, atr_pts);

      double spread_to_atr = atr_ok ? (mean / atr_pts) : 1e100;
      bool atr_missing = !atr_ok;

      double density = 0.0;
      if(expected > 0) density = (double)cnt / (double)expected; // normalized [0..1+] proxy

      // Quantize ordering-sensitive fields (determinism)
      spread_to_atr = Q(spread_to_atr, Q_SPREAD_TO_ATR);
      spread_bps    = Q(spread_bps, Q_SPREAD_BPS);
      stab          = Q(stab, Q_STABILITY_RATIO);
      density       = Q(density, Q_TICK_DENSITY);

      StageAItem it;
      it.symbol = g_syms[i];
      it.universe_index = i;
      it.samples = cnt;
      it.spread_mean = mean;
      it.spread_std  = sd;
      it.stability_ratio = stab;
      it.spread_bps = spread_bps;
      it.spread_to_atr = spread_to_atr;
      it.atr_missing = atr_missing;
      it.spikes = spikes;
      it.tick_density = density;
      it.tick_ok = tick_ok;
      it.tick_age = age;
      it.stageA_rank = 0;

      tmp[cand] = it;
      cand++;
   }

   ArrayResize(tmp, cand);

   SortStageA(tmp, cand);

   int take = Kcap;
   if(take > cand) take = cand;

   ArrayResize(out_stageA, take);
   for(int i=0;i<take;i++)
   {
      out_stageA[i] = tmp[i];
      out_stageA[i].stageA_rank = i + 1;
   }

   out_n = take;
   return true;
}

//==============================
// SNAPSHOT JSON BUILDER (single combined snapshot)
//==============================
string BuildSnapshotJson(StageAItem &stageA[], int stageA_n, int stale_count, int sampled_symbols_count)
{
   bool used_fallback = false;
   datetime t_server = NowServer(used_fallback);
   datetime t_utc    = TimeGMT();

   int Kcap = StageA_K_Default;
   if(Kcap > g_universe_n) Kcap = g_universe_n;
   if(Kcap < 0) Kcap = 0;

   bool degraded = false;
   string degraded_reason = "";
   if(g_universe_n < 5)
   {
      degraded = true;
      degraded_reason = "UNIVERSE_TOO_SMALL";
   }

   // We keep run_truth_status aligned with DEV #1 stage; export extra flags without changing logic.
   string run_truth_status = (degraded ? "DEGRADED" : "COMPUTED");

   string js = "{\n";

   // --- metadata (Step 0) ---
   js += "  \"iss_version\":\""+string(ISS_VERSION)+"\",\n";
   js += "  \"schema_version\":\""+string(SCHEMA_VERSION)+"\",\n";
   js += "  \"engine\":\"ISSX_DEV_Friction\",\n";
   js += "  \"account_login\":"+L2S((long)AccountInfoInteger(ACCOUNT_LOGIN))+",\n";
   js += "  \"account_currency\":\""+JsonEscape(AccountInfoString(ACCOUNT_CURRENCY))+"\",\n";
   js += "  \"leverage\":"+L2S((long)AccountInfoInteger(ACCOUNT_LEVERAGE))+",\n";
   js += "  \"broker\":\""+JsonEscape(AccountInfoString(ACCOUNT_COMPANY))+"\",\n";
   js += "  \"server\":\""+JsonEscape(AccountInfoString(ACCOUNT_SERVER))+"\",\n";
   js += "  \"terminal_build\":"+L2S((long)TerminalInfoInteger(TERMINAL_BUILD))+",\n";
   js += "  \"server_time\":"+L2S((long)t_server)+",\n";
   js += "  \"utc_time\":"+L2S((long)t_utc)+",\n";
   js += "  \"server_time_fallback_used\":"+string(B2S(used_fallback))+",\n";

   // --- params ---
   js += "  \"params\":{\n";
   js += "    \"SampleSeconds\":"+I2S(SampleSeconds)+",\n";
   js += "    \"FrictionWindowMinutes\":"+I2S(FrictionWindowMinutes)+",\n";
   js += "    \"RecomputeMinutes\":"+I2S(RecomputeMinutes)+",\n";
   js += "    \"MaxSymbolsPerSampleTick\":"+I2S(MaxSymbolsPerSampleTick)+",\n";
   js += "    \"MaxTickAgeSeconds\":"+I2S(MaxTickAgeSeconds)+",\n";
   js += "    \"StageA_K_Default\":"+I2S(StageA_K_Default)+",\n";
   js += "    \"ATR_Period\":"+I2S(ATR_Period)+",\n";
   js += "    \"EnablePopups\":"+string(B2S(EnablePopups))+",\n";
   js += "    \"LogEvery\":"+I2S(LogEvery)+",\n";
   js += "    \"EnableSnapshotStamped\":"+string(B2S(EnableSnapshotStamped))+"\n";
   js += "  },\n";

   // --- state ---
   js += "  \"state\":{\n";
   js += "    \"load_status\":\""+JsonEscape(g_state_load_status)+"\",\n";
   js += "    \"load_message\":\""+JsonEscape(g_state_load_message)+"\",\n";
   js += "    \"rr_index\":"+I2S(g_rr_index)+"\n";
   js += "  },\n";

   // --- derived ---
   js += "  \"derived\":{\n";
   js += "    \"universe_size\":"+I2S(g_universe_n)+",\n";
   js += "    \"ring_capacity\":"+I2S(g_ring_capacity)+",\n";
   js += "    \"min_samples_required\":"+I2S(g_min_samples_required)+",\n";
   js += "    \"stageA_k_cap\":"+I2S(Kcap)+",\n";
   js += "    \"stale_symbols_count\":"+I2S(stale_count)+",\n";
   js += "    \"sampled_symbols_count\":"+I2S(sampled_symbols_count)+",\n";
   js += "    \"stageA_count\":"+I2S(stageA_n)+"\n";
   js += "  },\n";

   // --- universe ---
   js += "  \"universe\":{\n";
   js += "    \"symbols\":[\n";
   for(int i=0;i<g_universe_n;i++)
   {
      js += "      \""+JsonEscape(g_syms[i])+"\"";
      if(i < g_universe_n-1) js += ",";
      js += "\n";
   }
   js += "    ]\n";
   js += "  },\n";

   // --- lightspec (Step 2) ---
   js += "  \"lightspec\":[\n";
   for(int i=0;i<g_universe_n;i++)
   {
      LightSpec ls = g_ls[i];

      js += "    {\n";
      js += "      \"symbol\":\""+JsonEscape(g_syms[i])+"\",\n";
      js += "      \"identity\":{\n";
      js += "        \"description\":\""+JsonEscape(ls.description)+"\",\n";
      js += "        \"path\":\""+JsonEscape(ls.path)+"\",\n";
      js += "        \"currency_base\":\""+JsonEscape(ls.currency_base)+"\",\n";
      js += "        \"currency_profit\":\""+JsonEscape(ls.currency_profit)+"\",\n";
      js += "        \"currency_margin\":\""+JsonEscape(ls.currency_margin)+"\"\n";
      js += "      },\n";
      js += "      \"core\":{\n";
      js += "        \"digits\":"+L2S(ls.digits)+",\n";
      js += "        \"trade_calc_mode\":"+L2S(ls.trade_calc_mode)+",\n";
      js += "        \"trade_mode\":"+L2S(ls.trade_mode)+",\n";
      js += "        \"stops_level\":"+L2S(ls.stops_level)+",\n";
      js += "        \"freeze_level\":"+L2S(ls.freeze_level)+",\n";
      js += "        \"swap_mode\":"+L2S(ls.swap_mode)+",\n";
      js += "        \"swap_rollover3days\":"+L2S(ls.swap_rollover3days)+",\n";

      js += "        \"point\":" + (ls.has_point ? D2S(ls.point,10) : "null") + ",\n";
      js += "        \"contract_size\":" + (ls.has_contract_size ? D2S(ls.contract_size,4) : "null") + ",\n";
      js += "        \"tick_size\":" + (ls.has_tick_size ? D2S(ls.tick_size,10) : "null") + ",\n";
      js += "        \"tick_value\":" + (ls.has_tick_value ? D2S(ls.tick_value,6) : "null") + ",\n";
      js += "        \"tick_value_profit\":" + (ls.has_tick_value_profit ? D2S(ls.tick_value_profit,6) : "null") + ",\n";
      js += "        \"tick_value_loss\":" + (ls.has_tick_value_loss ? D2S(ls.tick_value_loss,6) : "null") + ",\n";

      js += "        \"volume_min\":" + (ls.has_vol_min ? D2S(ls.volume_min,6) : "null") + ",\n";
      js += "        \"volume_max\":" + (ls.has_vol_max ? D2S(ls.volume_max,6) : "null") + ",\n";
      js += "        \"volume_step\":" + (ls.has_vol_step ? D2S(ls.volume_step,6) : "null") + ",\n";

      js += "        \"swap_long\":" + (ls.has_swap_long ? D2S(ls.swap_long,6) : "null") + ",\n";
      js += "        \"swap_short\":" + (ls.has_swap_short ? D2S(ls.swap_short,6) : "null") + "\n";
      js += "      }\n";
      js += "    }";
      if(i < g_universe_n-1) js += ",";
      js += "\n";
   }
   js += "  ],\n";

   // --- friction summary (Step 3) ---
   js += "  \"friction\":[\n";

   int now_sec = (int)t_server;
   for(int i=0;i<g_universe_n;i++)
   {
      PruneRing(i, now_sec);
      int cnt = g_fb[i].count;

      double xs[];
      ArrayResize(xs, cnt);

      int cap = g_ring_capacity;
      for(int j=0;j<cnt;j++)
      {
         int pos = g_fb[i].head - cnt + j;
         while(pos < 0) pos += cap;
         if(pos >= cap) pos %= cap;
         xs[j] = g_fb[i].spread[pos];
      }

      double mean = Mean(xs, cnt);
      double sd   = StdDevSample(xs, cnt, mean);
      double stab = (mean > TINY ? (sd / mean) : 0.0);

      bool tick_ok = g_fb[i].tick_available;
      long age = g_fb[i].tick_age_seconds;
      bool stale = (!tick_ok || age > MaxTickAgeSeconds);

      js += "    {\n";
      js += "      \"symbol\":\""+JsonEscape(g_syms[i])+"\",\n";
      js += "      \"tick\":{\n";
      js += "        \"available\":"+string(B2S(tick_ok))+",\n";
      js += "        \"last_error\":"+I2S(g_fb[i].tick_last_error)+",\n";
      js += "        \"age_seconds\":"+L2S(age)+",\n";
      js += "        \"fresh\":"+string(B2S(tick_ok && !stale))+",\n";
      js += "        \"bid\":"+D2S(g_fb[i].last_bid,10)+",\n";
      js += "        \"ask\":"+D2S(g_fb[i].last_ask,10)+",\n";
      js += "        \"time\":"+L2S((long)g_fb[i].last_tick_time)+"\n";
      js += "      },\n";
      js += "      \"stats\":{\n";
      js += "        \"samples\":"+I2S(cnt)+",\n";
      js += "        \"spread_mean_points\":"+D2S(mean,6)+",\n";
      js += "        \"spread_std_points\":"+D2S(sd,6)+",\n";
      js += "        \"spread_stability_ratio\":"+D2S(stab,8)+",\n";
      js += "        \"stale\":"+string(B2S(stale))+"\n";
      js += "      }\n";
      js += "    }";
      if(i < g_universe_n-1) js += ",";
      js += "\n";
   }
   js += "  ],\n";

   // --- stageA candidates (Step 4) ---
   js += "  \"stageA\":{\n";
   js += "    \"k_default\":"+I2S(StageA_K_Default)+",\n";
   js += "    \"k_cap\":"+I2S(Kcap)+",\n";
   js += "    \"min_samples_required\":"+I2S(g_min_samples_required)+",\n";
   js += "    \"count\":"+I2S(stageA_n)+",\n";
   js += "    \"symbols\":[\n";
   for(int i=0;i<stageA_n;i++)
   {
      StageAItem it = stageA[i];
      js += "      {\n";
      js += "        \"symbol\":\""+JsonEscape(it.symbol)+"\",\n";
      js += "        \"stageA_rank\":"+I2S(it.stageA_rank)+",\n";
      js += "        \"samples\":"+I2S(it.samples)+",\n";
      js += "        \"spread_mean_points\":"+D2S(it.spread_mean,6)+",\n";
      js += "        \"spread_std_points\":"+D2S(it.spread_std,6)+",\n";
      js += "        \"spread_stability_ratio\":"+D2S(it.stability_ratio,8)+",\n";
      js += "        \"spread_bps\":"+D2S(it.spread_bps,4)+",\n";
      js += "        \"atr_missing\":"+string(B2S(it.atr_missing))+",\n";
      js += "        \"spread_to_atr\":"+D2S(it.spread_to_atr,8)+",\n";
      js += "        \"spikes\":"+I2S(it.spikes)+",\n";
      js += "        \"tick_density_proxy\":"+D2S(it.tick_density,8)+",\n";
      js += "        \"tick_age_seconds\":"+L2S(it.tick_age)+"\n";
      js += "      }";
      if(i < stageA_n-1) js += ",";
      js += "\n";
   }
   js += "    ]\n";
   js += "  },\n";

   // --- system health (DEV #1 minimal) ---
   js += "  \"system_health\":{\n";
   js += "    \"universe_size\":"+I2S(g_universe_n)+",\n";
   js += "    \"stale_symbols_count\":"+I2S(stale_count)+",\n";
   js += "    \"stageA_count\":"+I2S(stageA_n)+",\n";
   js += "    \"run_truth_status\":\""+run_truth_status+"\",\n";
   js += "    \"degraded_reasons\":[";
   if(degraded) js += "\""+degraded_reason+"\"";
   js += "]\n";
   js += "  }\n";

   js += "}\n";
   return js;
}

//==============================
// EXPORT WRAPPER (2 JSON files + binary state)
//==============================
bool ExportSnapshot(StageAItem &stageA[], int stageA_n, int stale_count, int sampled_symbols_count, string &final_error)
{
   final_error = "";

   bool used_fallback = false;
   datetime t_server = NowServer(used_fallback);
   string stamp = Stamp(t_server);

   string snapshot = BuildSnapshotJson(stageA, stageA_n, stale_count, sampled_symbols_count);

   string err;
   if(!AtomicWriteText(g_out_folder+"iss_snapshot_latest.json", snapshot, err))
   {
      final_error = "snapshot_latest: " + err;
      return false;
   }

   if(EnableSnapshotStamped)
   {
      if(!AtomicWriteText(g_out_folder+"iss_snapshot_"+stamp+".json", snapshot, err))
      {
         final_error = "snapshot_stamp: " + err;
         return false;
      }
   }

   if(!SaveFrictionState(err))
   {
      final_error = "save_state: " + err;
      return false;
   }

   return true;
}

//==============================
// RECOMPUTE (Timer B)
//==============================
void RecomputeCycle()
{
   // Step 1
   BuildUniverse();

   // Step 2
   CaptureLightSpecAll();

   // Load state (ring buffers continuity)
   string load_err = "";
   bool loaded_ok = LoadFrictionState(load_err);

   if(loaded_ok)
   {
      g_state_load_status = "OK";
      g_state_load_message = "";
   }
   else
   {
      if(load_err == "state file missing (first run)")
         g_state_load_status = "MISSING";
      else if(StringFind(load_err, "schema mismatch") >= 0)
         g_state_load_status = "MISMATCH_RESET";
      else
         g_state_load_status = "READ_ERROR";

      g_state_load_message = load_err;
      if(load_err != "")
         Print("ISSX_DEV_Friction: state reset/not loaded: ", load_err);
   }

   // Tick probe pass for deterministic recompute (does NOT add to ring)
   bool used_fallback = false;
   datetime now_server = NowServer(used_fallback);
   ProbeTicksAll(now_server);

   int now_sec = (int)now_server;
   for(int i=0;i<g_universe_n;i++)
      PruneRing(i, now_sec);

   // Step 4
   StageAItem stageA[];
   int stageA_n = 0;
   int stale_count = 0;
   int sampled_symbols_count = 0;

   BuildStageA(stageA, stageA_n, stale_count, sampled_symbols_count);

   // Export snapshot
   string err;
   bool ok = ExportSnapshot(stageA, stageA_n, stale_count, sampled_symbols_count, err);

   if(ok)
   {
      string msg = "ISSX_DEV_Friction: snapshot export complete (atomic + state saved). "
                   "Universe=" + IntegerToString(g_universe_n) +
                   " StageA=" + IntegerToString(stageA_n) +
                   " Stale=" + IntegerToString(stale_count) +
                   " SampledSyms=" + IntegerToString(sampled_symbols_count);

      Print(msg);
      if(EnablePopups) Alert(msg);
   }
   else
   {
      string msg = "ISSX_DEV_Friction: EXPORT ERROR: " + err;
      Print(msg);
      if(EnablePopups) Alert(msg);
   }
}

//==============================
// INIT / DEINIT / TIMER
//==============================
void BuildDevFolder()
{
   string broker = Sanitize(AccountInfoString(ACCOUNT_COMPANY));
   string server = Sanitize(AccountInfoString(ACCOUNT_SERVER));
   long login    = AccountInfoInteger(ACCOUNT_LOGIN);

   g_out_folder = g_folder_prefix + g_engine_tag + "_" + broker + "_" + server + "_" + (string)login + "\\";
   EnsureFolder(g_out_folder);
}

int OnInit()
{
   BuildDevFolder();

   BuildUniverse();
   CaptureLightSpecAll();

   g_state_load_status = "NOT_ATTEMPTED";
   g_state_load_message = "";

   string err;
   bool ok = LoadFrictionState(err);
   if(ok)
   {
      g_state_load_status = "OK";
      g_state_load_message = "";
   }
   else
   {
      if(err == "state file missing (first run)")
         g_state_load_status = "MISSING";
      else if(StringFind(err, "schema mismatch") >= 0)
         g_state_load_status = "MISMATCH_RESET";
      else
         g_state_load_status = "READ_ERROR";

      g_state_load_message = err;
      if(err != "")
         Print("ISSX_DEV_Friction: state reset/not loaded: ", err);
   }

   EventSetTimer(1);

   bool used_fallback = false;
   datetime now = NowServer(used_fallback);
   g_last_sample_time = now;
   g_last_recompute_time = 0;

   Print("ISSX_DEV_Friction: START. Folder=MQL5\\Files\\", g_out_folder,
         " Universe=", g_universe_n,
         " RingCap=", g_ring_capacity,
         " MinSamples=", g_min_samples_required,
         " StateLoad=", g_state_load_status);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   string err;
   SaveFrictionState(err);

   Print("ISSX_DEV_Friction: STOP. reason=", reason);
}

void OnTimer()
{
   bool used_fallback = false;
   datetime now = NowServer(used_fallback);

   if(SampleSeconds > 0 && (now - g_last_sample_time) >= SampleSeconds)
   {
      g_last_sample_time = now;
      SamplingTick();

      if(LogEvery > 0 && g_universe_n > 0)
      {
         static long sample_ticks = 0;
         sample_ticks++;
         if(sample_ticks % LogEvery == 0)
            Print("ISSX_DEV_Friction: sampling tick#", sample_ticks, " rr=", g_rr_index);
      }
   }

   if(RecomputeMinutes > 0 && (now - g_last_recompute_time) >= (RecomputeMinutes * 60))
   {
      g_last_recompute_time = now;
      RecomputeCycle();
   }
}
//+------------------------------------------------------------------+