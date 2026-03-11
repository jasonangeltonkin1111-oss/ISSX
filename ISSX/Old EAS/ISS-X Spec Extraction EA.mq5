//+------------------------------------------------------------------+
//| ISS-X DeepSpec Harvester (Universe)                              |
//| Universal spec harvester across firms/brokers (older-build safe)  |
//| - NO trading, NO popups                                           |
//| - Proper JSON (no trailing commas)                                |
//| - STANDARD (readable) + RAW (enum scans) per symbol               |
//+------------------------------------------------------------------+
#property strict

input int  MaxTickAgeSeconds = 300;  // stale tick cutoff
input int  LogEvery          = 50;   // Print progress every N symbols
input int  EnumIntMax        = 220;  // scan range for integer props
input int  EnumDblMax        = 220;  // scan range for double props
input int  EnumStrMax        = 80;   // scan range for string props

string OUT_FILE = "iss_deepspec_universe.json";

//------------------------------------------------------------
string JsonEscape(string s)
{
   StringReplace(s, "\\", "\\\\");
   StringReplace(s, "\"", "\\\"");
   StringReplace(s, "\r", "\\r");
   StringReplace(s, "\n", "\\n");
   StringReplace(s, "\t", "\\t");
   return s;
}

void WL(int h, string s) { FileWriteString(h, s + "\n"); }

string B2S(bool v) { return (v ? "true" : "false"); }
string I2S(long v) { return IntegerToString((int)v); }
string D2S(double v, int digits) { return DoubleToString(v, digits); }

//------------------------------------------------------------
// Safe getters compatible with older builds
//------------------------------------------------------------
bool GetInt(const string sym, const ENUM_SYMBOL_INFO_INTEGER prop, long &outv)
{
   ResetLastError();
   return SymbolInfoInteger(sym, prop, outv);
}

bool GetDbl(const string sym, const ENUM_SYMBOL_INFO_DOUBLE prop, double &outv)
{
   ResetLastError();
   outv = SymbolInfoDouble(sym, prop);
   return (GetLastError() == 0);
}

string GetStr(const string sym, const ENUM_SYMBOL_INFO_STRING prop, bool &ok)
{
   ResetLastError();
   string v = SymbolInfoString(sym, prop);
   ok = (GetLastError() == 0);
   return v;
}

//------------------------------------------------------------
// Deterministic volume rounding to step
//------------------------------------------------------------
double RoundDownToStep(double vol, double step)
{
   if(step <= 0.0) return vol;
   double k = MathFloor(vol/step + 1e-8);
   return k * step;
}

//------------------------------------------------------------
// Session helpers (open/closed determination)
//------------------------------------------------------------
int SecOfDay(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return st.hour*3600 + st.min*60 + st.sec;
}

int NowSecOfDay(datetime now_server)
{
   MqlDateTime st;
   TimeToStruct(now_server, st);
   return st.hour*3600 + st.min*60 + st.sec;
}

bool InsideAnySessionTrade(const string sym, int dow, datetime now_server)
{
   int now_sec = NowSecOfDay(now_server);

   for(int idx=0; idx<64; idx++)
   {
      datetime from,to;
      if(!SymbolInfoSessionTrade(sym, (ENUM_DAY_OF_WEEK)dow, idx, from, to))
         break;

      int f = SecOfDay(from);
      int tt = SecOfDay(to);

      if(tt >= f)
      {
         if(now_sec >= f && now_sec <= tt) return true;
      }
      else
      {
         if(now_sec >= f || now_sec <= tt) return true;
      }
   }
   return false;
}

bool InsideAnySessionQuote(const string sym, int dow, datetime now_server)
{
   int now_sec = NowSecOfDay(now_server);

   for(int idx=0; idx<64; idx++)
   {
      datetime from,to;
      if(!SymbolInfoSessionQuote(sym, (ENUM_DAY_OF_WEEK)dow, idx, from, to))
         break;

      int f = SecOfDay(from);
      int tt = SecOfDay(to);

      if(tt >= f)
      {
         if(now_sec >= f && now_sec <= tt) return true;
      }
      else
      {
         if(now_sec >= f || now_sec <= tt) return true;
      }
   }
   return false;
}

//------------------------------------------------------------
// JSON key/value writers (comma-safe)
//------------------------------------------------------------
void WriteKV_Int(int h, bool &first, string key, long v)
{
   if(!first) WL(h, ",");
   first = false;
   WL(h, "\""+key+"\":"+I2S(v));
}

void WriteKV_Dbl(int h, bool &first, string key, double v, int digits)
{
   if(!first) WL(h, ",");
   first = false;
   WL(h, "\""+key+"\":"+D2S(v, digits));
}

void WriteKV_Bool(int h, bool &first, string key, bool v)
{
   if(!first) WL(h, ",");
   first = false;
   WL(h, "\""+key+"\":"+B2S(v));
}

void WriteKV_Str(int h, bool &first, string key, string v)
{
   if(!first) WL(h, ",");
   first = false;
   WL(h, "\""+key+"\":\""+JsonEscape(v)+"\"");
}

//------------------------------------------------------------
// Margin rate flags (arrays MUST be passed by reference on your build)
//------------------------------------------------------------
struct MarginRateFlags
{
   bool provided;
   bool unavailable;
   bool zero_returned;
};

void ComputeMarginRateFlags(const bool &ok_arr[], const double &init_arr[], const double &maint_arr[], int n, MarginRateFlags &f)
{
   f.provided = false;
   f.unavailable = true;
   f.zero_returned = false;

   bool any_ok = false;
   bool all_zero = true;

   for(int i=0;i<n;i++)
   {
      if(ok_arr[i])
      {
         any_ok = true;
         if(init_arr[i] != 0.0 || maint_arr[i] != 0.0) all_zero = false;
      }
   }

   f.provided = any_ok;
   f.unavailable = !any_ok;
   f.zero_returned = (any_ok && all_zero);
}

//------------------------------------------------------------
// Main
//------------------------------------------------------------
int OnInit()
{
   Print("ISS-X DeepSpec Harvester: START (no popups)");

   int total = SymbolsTotal(true);
   if(total <= 0)
   {
      Print("No symbols in Market Watch.");
      return INIT_SUCCEEDED;
   }

   // Sort symbols deterministically
   string syms[];
   ArrayResize(syms, total);
   for(int i=0;i<total;i++)
      syms[i] = SymbolName(i,true);
   ArraySort(syms);

   int h = FileOpen(OUT_FILE, FILE_WRITE|FILE_TXT);
   if(h == INVALID_HANDLE)
   {
      Print("FileOpen failed: ", OUT_FILE, " err=", GetLastError());
      return INIT_SUCCEEDED;
   }

   datetime t_server = TimeTradeServer();
   datetime t_gmt    = TimeGMT();

   // Root
   WL(h, "{");

   // Metadata (kept universal—no TERMINAL_SERVER usage)
   WL(h, "\"metadata\":{");
   bool mf = true;
   WriteKV_Int(h, mf, "account_login", (long)AccountInfoInteger(ACCOUNT_LOGIN));
   WriteKV_Str(h, mf, "account_currency", AccountInfoString(ACCOUNT_CURRENCY));
   WriteKV_Int(h, mf, "account_leverage", (long)AccountInfoInteger(ACCOUNT_LEVERAGE));
   WriteKV_Int(h, mf, "server_time", (long)t_server);
   WriteKV_Int(h, mf, "utc_time", (long)t_gmt);
   WriteKV_Int(h, mf, "max_tick_age_seconds", (long)MaxTickAgeSeconds);
   WriteKV_Int(h, mf, "universe_size", (long)total);
   WL(h, "\n},");

   // Symbols array
   WL(h, "\"symbols\":[");
   bool sym_first = true;

   ENUM_ORDER_TYPE types[6] =
   {
      ORDER_TYPE_BUY,
      ORDER_TYPE_SELL,
      ORDER_TYPE_BUY_LIMIT,
      ORDER_TYPE_SELL_LIMIT,
      ORDER_TYPE_BUY_STOP,
      ORDER_TYPE_SELL_STOP
   };

   for(int i=0;i<total;i++)
   {
      string s = syms[i];

      if(!sym_first) WL(h, ",");
      sym_first = false;

      WL(h, "{");
      bool top_first = true;

      WriteKV_Str(h, top_first, "symbol", s);

      // ---------------- STANDARD ----------------
      if(!top_first) WL(h, ",");
      top_first = false;
      WL(h, "\"standard\":{");

      // Identity
      WL(h, "\"identity\":{");
      bool id_first = true;
      bool okS=false;

      string desc = GetStr(s, (ENUM_SYMBOL_INFO_STRING)20, okS);
      if(!okS) desc = SymbolInfoString(s, SYMBOL_DESCRIPTION);

      string path = GetStr(s, (ENUM_SYMBOL_INFO_STRING)21, okS);
      if(!okS) path = SymbolInfoString(s, SYMBOL_PATH);

      string c_base = GetStr(s, (ENUM_SYMBOL_INFO_STRING)22, okS); if(!okS) c_base = SymbolInfoString(s, SYMBOL_CURRENCY_BASE);
      string c_prof = GetStr(s, (ENUM_SYMBOL_INFO_STRING)23, okS); if(!okS) c_prof = SymbolInfoString(s, SYMBOL_CURRENCY_PROFIT);
      string c_marg = GetStr(s, (ENUM_SYMBOL_INFO_STRING)24, okS); if(!okS) c_marg = SymbolInfoString(s, SYMBOL_CURRENCY_MARGIN);

      WriteKV_Str(h, id_first, "description", desc);
      WriteKV_Str(h, id_first, "path", path);
      WriteKV_Str(h, id_first, "currency_base", c_base);
      WriteKV_Str(h, id_first, "currency_profit", c_prof);
      WriteKV_Str(h, id_first, "currency_margin", c_marg);
      WL(h, "\n},");

      // Core
      WL(h, "\"core\":{");
      bool core_first = true;

      long lv=0;
      double dv=0;

      if(GetInt(s, SYMBOL_DIGITS, lv))             WriteKV_Int(h, core_first, "digits", lv);
      if(GetInt(s, SYMBOL_TRADE_CALC_MODE, lv))    WriteKV_Int(h, core_first, "trade_calc_mode", lv);
      if(GetInt(s, SYMBOL_TRADE_MODE, lv))         WriteKV_Int(h, core_first, "trade_mode", lv);
      if(GetInt(s, SYMBOL_TRADE_STOPS_LEVEL, lv))  WriteKV_Int(h, core_first, "stops_level", lv);
      if(GetInt(s, SYMBOL_TRADE_FREEZE_LEVEL, lv)) WriteKV_Int(h, core_first, "freeze_level", lv);

      if(GetDbl(s, SYMBOL_POINT, dv))               WriteKV_Dbl(h, core_first, "point", dv, 10);
      if(GetDbl(s, SYMBOL_TRADE_CONTRACT_SIZE, dv)) WriteKV_Dbl(h, core_first, "contract_size", dv, 4);
      if(GetDbl(s, SYMBOL_TRADE_TICK_SIZE, dv))     WriteKV_Dbl(h, core_first, "tick_size", dv, 10);
      if(GetDbl(s, SYMBOL_TRADE_TICK_VALUE, dv))    WriteKV_Dbl(h, core_first, "tick_value", dv, 6);
      if(GetDbl(s, SYMBOL_TRADE_TICK_VALUE_PROFIT, dv)) WriteKV_Dbl(h, core_first, "tick_value_profit", dv, 6);
      if(GetDbl(s, SYMBOL_TRADE_TICK_VALUE_LOSS, dv))   WriteKV_Dbl(h, core_first, "tick_value_loss", dv, 6);

      double vol_min=0, vol_max=0, vol_step=0;
      bool ok_vmin = GetDbl(s, SYMBOL_VOLUME_MIN, vol_min);
      bool ok_vmax = GetDbl(s, SYMBOL_VOLUME_MAX, vol_max);
      bool ok_vstep= GetDbl(s, SYMBOL_VOLUME_STEP, vol_step);

      if(ok_vmin)  WriteKV_Dbl(h, core_first, "volume_min", vol_min, 6);
      if(ok_vmax)  WriteKV_Dbl(h, core_first, "volume_max", vol_max, 6);
      if(ok_vstep) WriteKV_Dbl(h, core_first, "volume_step", vol_step, 6);

      if(GetInt(s, SYMBOL_SWAP_MODE, lv))           WriteKV_Int(h, core_first, "swap_mode", lv);
      if(GetDbl(s, SYMBOL_SWAP_LONG, dv))           WriteKV_Dbl(h, core_first, "swap_long", dv, 6);
      if(GetDbl(s, SYMBOL_SWAP_SHORT, dv))          WriteKV_Dbl(h, core_first, "swap_short", dv, 6);
      if(GetInt(s, SYMBOL_SWAP_ROLLOVER3DAYS, lv))  WriteKV_Int(h, core_first, "swap_rollover3days", lv);

      WL(h, "\n},");

      // Tick
      MqlTick tick;
      bool tick_ok = SymbolInfoTick(s, tick);
      datetime now_server = TimeTradeServer();
      long tick_age = tick_ok ? (long)(now_server - tick.time) : 2147483647;
      bool tick_fresh = (tick_ok && tick_age >= 0 && tick_age <= MaxTickAgeSeconds);

      WL(h, "\"tick\":{");
      bool tk_first = true;
      WriteKV_Bool(h, tk_first, "available", tick_ok);
      WriteKV_Int(h, tk_first, "age_seconds", tick_age);
      WriteKV_Bool(h, tk_first, "fresh", tick_fresh);
      if(tick_ok)
      {
         WriteKV_Dbl(h, tk_first, "bid", tick.bid, 10);
         WriteKV_Dbl(h, tk_first, "ask", tick.ask, 10);
         WriteKV_Int(h, tk_first, "time", (long)tick.time);
      }
      WL(h, "\n},");

      // Market state (open/closed)
      MqlDateTime st; TimeToStruct(now_server, st);
      int dow = st.day_of_week;

      bool inside_trade = InsideAnySessionTrade(s, dow, now_server);
      bool inside_quote = InsideAnySessionQuote(s, dow, now_server);
      bool market_open_flag = (inside_trade && tick_fresh);

      WL(h, "\"market_state\":{");
      bool ms_first = true;
      WriteKV_Int(h, ms_first, "server_time", (long)now_server);
      WriteKV_Int(h, ms_first, "utc_time", (long)TimeGMT());
      WriteKV_Int(h, ms_first, "day_of_week", (long)dow);
      WriteKV_Bool(h, ms_first, "inside_trade_session", inside_trade);
      WriteKV_Bool(h, ms_first, "inside_quote_session", inside_quote);
      WriteKV_Bool(h, ms_first, "market_open_flag", market_open_flag);

      string reason = "";
      if(market_open_flag) reason = "";
      else if(!tick_ok) reason = "NO_TICK";
      else if(!tick_fresh) reason = "STALE_TICK";
      else if(!inside_trade) reason = "OUTSIDE_TRADE_SESSION";
      else reason = "UNKNOWN";

      WriteKV_Str(h, ms_first, "reason_if_closed", reason);
      WL(h, "\n},");

      // Sessions
      WL(h, "\"sessions\":{");

      WL(h, "\"quote_sessions\":{");
      for(int d=0; d<7; d++)
      {
         WL(h, "\"day_"+IntegerToString(d)+"\":[");
         bool firstq = true;
         for(int si=0; si<64; si++)
         {
            datetime f,tto;
            if(!SymbolInfoSessionQuote(s, (ENUM_DAY_OF_WEEK)d, si, f, tto)) break;
            if(!firstq) WL(h, ",");
            firstq = false;
            WL(h, "{");
            bool qsf=true;
            WriteKV_Int(h, qsf, "from", (long)f);
            WriteKV_Int(h, qsf, "to", (long)tto);
            WL(h, "\n}");
         }
         WL(h, "]");
         if(d<6) WL(h, ",");
      }
      WL(h, "},");

      WL(h, "\"trade_sessions\":{");
      for(int d=0; d<7; d++)
      {
         WL(h, "\"day_"+IntegerToString(d)+"\":[");
         bool firstt = true;
         for(int si=0; si<64; si++)
         {
            datetime f,tto;
            if(!SymbolInfoSessionTrade(s, (ENUM_DAY_OF_WEEK)d, si, f, tto)) break;
            if(!firstt) WL(h, ",");
            firstt = false;
            WL(h, "{");
            bool tsf=true;
            WriteKV_Int(h, tsf, "from", (long)f);
            WriteKV_Int(h, tsf, "to", (long)tto);
            WL(h, "\n}");
         }
         WL(h, "]");
         if(d<6) WL(h, ",");
      }
      WL(h, "}");

      WL(h, "},");

      // Margin rate + flags
      bool mr_ok[6];
      double mr_init[6];
      double mr_maint[6];

      WL(h, "\"margin_rate\":{");
      WL(h, "\"rows\":[");
      bool row_first=true;

      for(int k=0;k<6;k++)
      {
         mr_init[k]=0; mr_maint[k]=0;
         ResetLastError();
         mr_ok[k] = SymbolInfoMarginRate(s, types[k], mr_init[k], mr_maint[k]);
         int err = GetLastError();

         if(!row_first) WL(h, ",");
         row_first=false;

         WL(h, "{");
         bool rf=true;
         WriteKV_Int(h, rf, "order_type", (long)types[k]);
         WriteKV_Dbl(h, rf, "initial", mr_init[k], 6);
         WriteKV_Dbl(h, rf, "maintenance", mr_maint[k], 6);
         WriteKV_Bool(h, rf, "success", mr_ok[k]);
         WriteKV_Int(h, rf, "error", (long)err);
         WL(h, "\n}");
      }
      WL(h, "],");

      MarginRateFlags flags;
      ComputeMarginRateFlags(mr_ok, mr_init, mr_maint, 6, flags);

      bool mrr_first=true;
      WriteKV_Bool(h, mrr_first, "margin_rate_provided", flags.provided);
      WriteKV_Bool(h, mrr_first, "margin_rate_zero_returned", flags.zero_returned);
      WriteKV_Bool(h, mrr_first, "margin_rate_unavailable", flags.unavailable);

      WL(h, "\n},");

      // OrderCalc Mode B
      double probe_vol = vol_min;
      if(ok_vmin && ok_vmax && ok_vstep)
      {
         if(1.0 >= vol_min && 1.0 <= vol_max) probe_vol = RoundDownToStep(1.0, vol_step);
         else probe_vol = RoundDownToStep(vol_min, vol_step);
         if(probe_vol < vol_min) probe_vol = vol_min;
      }

      double h1_close = 0.0;
      bool has_h1_close = false;
      if(!tick_fresh)
      {
         MqlRates rr[];
         if(CopyRates(s, PERIOD_H1, 0, 1, rr) > 0)
         {
            h1_close = rr[0].close;
            has_h1_close = true;
         }
      }

      WL(h, "\"ordercalc\":{");

      WL(h, "\"probe\":{");
      bool prf=true;
      WriteKV_Dbl(h, prf, "vol_min", vol_min, 6);
      WriteKV_Dbl(h, prf, "probe_volume", probe_vol, 6);
      WriteKV_Dbl(h, prf, "vol_step", vol_step, 6);
      WriteKV_Dbl(h, prf, "vol_max", vol_max, 6);
      WL(h, "\n},");

      // Margin probes
      WL(h, "\"margin_probes\":[");
      bool mp_first=true;

      int fail_count=0;
      int defer_count=0;
      int ok_count=0;

      for(int k=0;k<6;k++)
      {
         double price_used = 0.0;
         string src = "";

         if(tick_fresh)
         {
            double mid = (tick.bid + tick.ask) * 0.5;
            if(types[k] == ORDER_TYPE_BUY) { price_used = tick.ask; src="TICK_ASK"; }
            else if(types[k] == ORDER_TYPE_SELL) { price_used = tick.bid; src="TICK_BID"; }
            else { price_used = mid; src="TICK_MID"; }
         }
         else if(has_h1_close)
         {
            price_used = h1_close;
            src = "LAST_CLOSE_FALLBACK";
         }
         else
         {
            price_used = 0.0;
            src = "NO_PRICE";
         }

         double margin=0;
         ResetLastError();
         bool ok = OrderCalcMargin(types[k], s, probe_vol, price_used, margin);
         int err = GetLastError();

         bool deferred = (ok && margin == 0.0 && !market_open_flag);

         if(!ok) fail_count++;
         else if(deferred) defer_count++;
         else ok_count++;

         if(!mp_first) WL(h, ",");
         mp_first=false;

         WL(h, "{");
         bool pf=true;
         WriteKV_Int(h, pf, "order_type", (long)types[k]);
         WriteKV_Dbl(h, pf, "volume_used", probe_vol, 6);
         WriteKV_Dbl(h, pf, "price_used", price_used, 10);
         WriteKV_Str(h, pf, "price_source", src);
         WriteKV_Bool(h, pf, "success", ok);
         WriteKV_Dbl(h, pf, "margin", margin, 6);
         WriteKV_Int(h, pf, "error", (long)err);
         WriteKV_Bool(h, pf, "deferred", deferred);
         WL(h, "\n}");
      }
      WL(h, "],");

      // Profit probes
      double pointv=0, ticksizev=0;
      bool ok_point = GetDbl(s, SYMBOL_POINT, pointv);
      bool ok_tsz   = GetDbl(s, SYMBOL_TRADE_TICK_SIZE, ticksizev);

      double move = 0.0;
      if(ok_point) move = pointv;
      if(ok_tsz && ticksizev > 0.0 && ticksizev > move) move = ticksizev;

      WL(h, "\"profit_probes\":[");
      bool pp_first=true;

      double open_buy=0, open_sell=0;
      string open_src="";

      if(tick_fresh)
      {
         open_buy = tick.ask;
         open_sell = tick.bid;
         open_src = "TICK";
      }
      else if(has_h1_close)
      {
         open_buy = h1_close;
         open_sell = h1_close;
         open_src = "LAST_CLOSE_FALLBACK";
      }
      else
      {
         open_buy = 0;
         open_sell = 0;
         open_src = "NO_PRICE";
      }

      // BUY
      {
         double closep = open_buy + move;
         double profit=0;
         ResetLastError();
         bool ok = OrderCalcProfit(ORDER_TYPE_BUY, s, probe_vol, open_buy, closep, profit);
         int err = GetLastError();

         if(!pp_first) WL(h, ",");
         pp_first=false;

         WL(h, "{");
         bool pf=true;
         WriteKV_Str(h, pf, "side", "BUY");
         WriteKV_Dbl(h, pf, "volume_used", probe_vol, 6);
         WriteKV_Dbl(h, pf, "open_price", open_buy, 10);
         WriteKV_Dbl(h, pf, "close_price", closep, 10);
         WriteKV_Dbl(h, pf, "move", move, 10);
         WriteKV_Str(h, pf, "price_source", open_src);
         WriteKV_Bool(h, pf, "success", ok);
         WriteKV_Dbl(h, pf, "profit_delta", profit, 6);
         WriteKV_Int(h, pf, "error", (long)err);
         WL(h, "\n}");
      }

      // SELL
      {
         double closep = open_sell - move;
         double profit=0;
         ResetLastError();
         bool ok = OrderCalcProfit(ORDER_TYPE_SELL, s, probe_vol, open_sell, closep, profit);
         int err = GetLastError();

         if(!pp_first) WL(h, ",");
         pp_first=false;

         WL(h, "{");
         bool pf=true;
         WriteKV_Str(h, pf, "side", "SELL");
         WriteKV_Dbl(h, pf, "volume_used", probe_vol, 6);
         WriteKV_Dbl(h, pf, "open_price", open_sell, 10);
         WriteKV_Dbl(h, pf, "close_price", closep, 10);
         WriteKV_Dbl(h, pf, "move", move, 10);
         WriteKV_Str(h, pf, "price_source", open_src);
         WriteKV_Bool(h, pf, "success", ok);
         WriteKV_Dbl(h, pf, "profit_delta", profit, 6);
         WriteKV_Int(h, pf, "error", (long)err);
         WL(h, "\n}");
      }

      WL(h, "],");

      // ordercalc_status
      string status = "OK";
      string defer_reason = "";

      if(fail_count == 6) status = "FAILED";
      else if(fail_count > 0) status = "PARTIAL";
      else if(defer_count > 0) status = "DEFERRED";
      else status = "OK";

      if(status == "DEFERRED")
      {
         if(!inside_trade) defer_reason = "MARKET_CLOSED";
         else if(!tick_ok) defer_reason = "NO_TICK";
         else if(!tick_fresh) defer_reason = "STALE_TICK";
         else defer_reason = "ZERO_MARGIN_CLOSED";
      }
      else if(status == "FAILED") defer_reason = "ORDER_CALC_FAILED";
      else if(status == "PARTIAL") defer_reason = "MIXED_RESULTS";

      WL(h, "\"ordercalc_status\":{");
      bool osf=true;
      WriteKV_Str(h, osf, "status", status);
      WriteKV_Str(h, osf, "defer_reason", defer_reason);
      WriteKV_Int(h, osf, "ok_count", (long)ok_count);
      WriteKV_Int(h, osf, "deferred_count", (long)defer_count);
      WriteKV_Int(h, osf, "failed_count", (long)fail_count);
      WL(h, "\n}");

      WL(h, "}"); // end ordercalc

      WL(h, "}"); // end standard

      // ---------------- RAW COPY ----------------
      WL(h, ",\"raw_copy\":{");

      WL(h, "\"symbolinfo_integer\":{");
      bool rfi=true;
      for(int p=0; p<EnumIntMax; p++)
      {
         long v;
         ResetLastError();
         bool ok = SymbolInfoInteger(s, (ENUM_SYMBOL_INFO_INTEGER)p, v);
         if(ok)
         {
            if(!rfi) WL(h, ",");
            rfi=false;
            WL(h, "\""+IntegerToString(p)+"\":"+I2S(v));
         }
      }
      WL(h, "},");

      WL(h, "\"symbolinfo_double\":{");
      bool rfd=true;
      for(int p=0; p<EnumDblMax; p++)
      {
         ResetLastError();
         double v = SymbolInfoDouble(s, (ENUM_SYMBOL_INFO_DOUBLE)p);
         if(GetLastError() == 0)
         {
            if(!rfd) WL(h, ",");
            rfd=false;
            WL(h, "\""+IntegerToString(p)+"\":"+D2S(v,10));
         }
      }
      WL(h, "},");

      WL(h, "\"symbolinfo_string\":{");
      bool rfs=true;
      for(int p=0; p<EnumStrMax; p++)
      {
         bool ok;
         string v = GetStr(s, (ENUM_SYMBOL_INFO_STRING)p, ok);
         if(ok && StringLen(v) > 0)
         {
            if(!rfs) WL(h, ",");
            rfs=false;
            WL(h, "\""+IntegerToString(p)+"\":\""+JsonEscape(v)+"\"");
         }
      }
      WL(h, "}");

      WL(h, "}"); // end raw_copy

      WL(h, "}"); // end symbol object

      if(LogEvery > 0 && (i+1) % LogEvery == 0)
         Print("DeepSpec Harvester processed: ", i+1, " / ", total);
   }

   WL(h, "]"); // end symbols
   WL(h, "}"); // end root

   FileClose(h);

   Print("ISS-X DeepSpec Harvester: COMPLETE. File: MQL5\\Files\\", OUT_FILE);
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+