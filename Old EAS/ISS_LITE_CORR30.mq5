//+------------------------------------------------------------------+
//|                                             ISS_LITE_SNAPSHOT.mq5 |
//|  Broker-native (MarketWatch) correlation + cost + tradable scan   |
//|  MT5 EA (NO TRADES). Exports ONE JSON snapshot per run.           |
//|  Backward compatible: no external libs, no DLLs, no fancy tricks  |
//|                                                                  |
//|  v3.00 changes:                                                   |
//|   - ONE output file (snapshot) containing account+positions+hist   |
//|   - Folder named by account number (login) under MQL5/Files/ISS/   |
//|   - Refresh on login change + on init                             |
//|   - Corr pool size 40                                             |
//|   - Correlation matrices: H1(200), H4(200), M15(50)               |
//|   - Top list dynamic: min 8, target 20 (attempt fill, not forced) |
//|   - Trade history: last 14 days                                   |
//+------------------------------------------------------------------+
#property strict
#property version   "3.00"
#property description "ISS-Lite Snapshot: CorrPool(40) H1/H4/M15 correlations + dynamic Top (8..20) + account + open trades + 14d history. No trades."

//------------------------- Inputs -----------------------------------
input int             InpCorrPoolSize      = 40;       // corr pool size
input int             InpTopTarget         = 20;       // attempt target
input int             InpTopMin            = 8;        // minimum acceptable top size (if possible)
input int             InpCorrBars_H1       = 200;      // H1 bars (needs +1 closes)
input int             InpCorrBars_H4       = 200;      // H4 bars (needs +1 closes)
input int             InpCorrBars_M15      = 50;       // M15 bars (needs +1 closes) - NOT used for ranking
input double          InpCorrGate          = 0.65;     // starting abs(corr) threshold for diversification
input int             InpTimerSeconds      = 30;       // check login/day changes this often
input bool            InpOnlyMarketWatch   = true;     // universe = MarketWatch symbols only
input bool            InpExportOnInit      = true;     // export on init
input bool            InpExportOnLoginSwap = true;     // export when login changes
input int             InpHistoryDays       = 14;       // trade history window
input bool            InpDebugPrint        = false;    // extra logs

//------------------------- Constants --------------------------------
#define NA_STR "—"

//------------------------- Small struct ------------------------------
struct SymRow
{
   string sym;
   int    td_state;        // 1 TRUE, 0 FALSE, -1 UNKNOWN
   double spread_bps;
   double d1_range_pct;
   double score;           // refined score (still D1-based, not M15)
   bool   tick_ok;
   bool   trade_ok;
   bool   corr_ok;         // has returns for ALL tf windows
};

// trade history aggregation
struct HistAgg
{
   string sym;
   int    trades;
   int    wins;
   int    losses;
   double net_profit;
   double gross_profit;
   double gross_loss; // negative
   double commission;
   double swap;
};

//------------------------- Globals ----------------------------------
int  g_last_yday = -1;
long g_last_login = 0;

//------------------------- Utility ----------------------------------
void PrintDbg(const string s){ if(InpDebugPrint) Print(s); }

string SanitizeFilePart(string s)
{
   string bad="\\/:*?\"<>|";
   for(int i=0;i<StringLen(bad);i++)
   {
      string ch = StringSubstr(bad,i,1);
      s = StringReplace(s, ch, "_");
   }
   s = StringReplace(s, " ", "_");
   return s;
}

string Two(const int n)
{
   if(n < 10) return "0" + IntegerToString(n);
   return IntegerToString(n);
}

string TimeStamp()
{
   MqlDateTime dt; 
   TimeToStruct(TimeCurrent(), dt);
   return StringFormat("%04d%02d%02d_%02d%02d%02d",
                       dt.year, dt.mon, dt.day,
                       dt.hour, dt.min, dt.sec);
}

string LoginStr64()
{
   long login = (long)AccountInfoInteger(ACCOUNT_LOGIN);
   return StringFormat("%I64d", login);
}


bool GetTickSafe(const string sym, MqlTick &t)
{
   if(!SymbolInfoTick(sym,t)) return false;
   if(t.bid<=0 || t.ask<=0 || t.ask<=t.bid) return false;
   return true;
}

bool GetD1HighLowClose(const string sym, double &h, double &l, double &c)
{
   MqlRates r[];
   int n = CopyRates(sym, PERIOD_D1, 0, 1, r);
   if(n<1) return false;
   h=r[0].high; l=r[0].low; c=r[0].close;
   if(h<=0 || l<=0 || c<=0 || h<l) return false;
   return true;
}

double SpreadBps(const double bid, const double ask)
{
   double mid = 0.5*(bid+ask);
   if(mid<=0) return 0.0;
   return ((ask-bid)/mid)*10000.0;
}

double D1RangePct(const double high, const double low, const double denom_close)
{
   if(denom_close<=0) return 0.0;
   return ((high-low)/denom_close)*100.0;
}

// Feasibility: trade enabled + best-effort session check
int TradableNowState(const string sym, bool &trade_ok_out)
{
   trade_ok_out=false;

   long trade_mode=0;
   if(!SymbolInfoInteger(sym, SYMBOL_TRADE_MODE, trade_mode))
      return -1; // unknown

   if((ENUM_SYMBOL_TRADE_MODE)trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return 0;

   trade_ok_out=true;

   datetime from,to;
   bool any_session=false;
   bool in_session=false;

   MqlDateTime nowdt; TimeToStruct(TimeCurrent(), nowdt);
   int dow = (int)nowdt.day_of_week;
   int nowsec = nowdt.hour*3600 + nowdt.min*60 + nowdt.sec;

   for(int si=0; si<32; si++)
   {
      if(!SymbolInfoSessionTrade(sym, (ENUM_DAY_OF_WEEK)dow, si, from, to))
      {
         if(si==0) return -1; // no session info => unknown
         break;
      }
      any_session=true;

      int f = (int)(from % 86400);
      int t = (int)(to   % 86400);

      if(f<=t)
      {
         if(nowsec>=f && nowsec<=t) in_session=true;
      }
      else
      {
         if(nowsec>=f || nowsec<=t) in_session=true;
      }
      if(in_session) break;
   }

   if(!any_session) return -1;
   return in_session ? 1 : 0;
}

// Compute value per "1 point" move for 1.00 lot using OrderCalcProfit
bool ValuePerPointPerLot(const string sym, const double ref_price, double &val_out)
{
   val_out = 0.0;
   double point=0.0;
   if(!SymbolInfoDouble(sym, SYMBOL_POINT, point) || point<=0) return false;

   double profit=0.0;
   if(!OrderCalcProfit(ORDER_TYPE_BUY, sym, 1.0, ref_price, ref_price+point, profit))
      return false;

   val_out = MathAbs(profit);
   // Some brokers return 0.0 for certain CFDs; treat as failure for downstream
   if(val_out <= 0.0) return false;
   return true;
}

bool MarginPerLot(const string sym, const double ref_price, double &m_out)
{
   m_out = 0.0;
   double margin=0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, sym, 1.0, ref_price, margin))
      return false;

   m_out = margin;
   // margin can be 0.0 for some symbols; treat as failure if <=0
   if(m_out <= 0.0) return false;
   return true;
}

//------------------------- Correlation helpers -----------------------
bool BuildLogReturnsTF(const string sym, const ENUM_TIMEFRAMES tf, const int bars, double &out[])
{
   ArrayResize(out,0);

   double closes[];
   int need = bars + 1;
   int got  = CopyClose(sym, tf, 0, need, closes);
   if(got < need) return false;

   ArraySetAsSeries(closes, true);

   ArrayResize(out, bars);
   for(int i=0;i<bars;i++)
   {
      double c0 = closes[i];
      double c1 = closes[i+1];
      if(c0<=0 || c1<=0) return false;
      out[i] = MathLog(c0/c1);
   }
   return true;
}

double CorrPearsonFlat(const double &flat[], const int bars, const int i, const int j)
{
   // flat length = N*bars, row-major by symbol: flat[i*bars + k]
   double ma=0.0, mb=0.0;
   for(int k=0;k<bars;k++)
   {
      ma += flat[i*bars + k];
      mb += flat[j*bars + k];
   }
   ma /= bars; mb /= bars;

   double va=0.0, vb=0.0, cov=0.0;
   for(int k=0;k<bars;k++)
   {
      double da = flat[i*bars + k] - ma;
      double db = flat[j*bars + k] - mb;
      cov += da*db;
      va  += da*da;
      vb  += db*db;
   }
   if(va<=0.0 || vb<=0.0) return 0.0;
   return cov / MathSqrt(va*vb);
}

//------------------------- JSON writing (manual) ---------------------
string JsonEscape(const string s)
{
   string out="";
   for(int i=0;i<StringLen(s);i++)
   {
      string ch = StringSubstr(s,i,1);
      if(ch=="\\") out+="\\\\";
      else if(ch=="\"") out+="\\\"";
      else if(ch=="\n") out+="\\n";
      else if(ch=="\r") out+="\\r";
      else if(ch=="\t") out+="\\t";
      else out += ch;
   }
   return out;
}

void JWrite(const int fh, const string s){ FileWriteString(fh, s); }
void JKey(const int fh, const string k){ JWrite(fh, "\""+JsonEscape(k)+"\":"); }
void JStr(const int fh, const string v){ if(v==NA_STR) JWrite(fh,"null"); else JWrite(fh, "\""+JsonEscape(v)+"\""); }
void JBool(const int fh, const bool v){ JWrite(fh, v ? "true" : "false"); }
void JInt(const int fh, const long v){ JWrite(fh, IntegerToString((int)v)); }
void JLongStr(const int fh, const long v){ JWrite(fh, "\""+JsonEscape(StringFormat("%I64d", (long)v))+"\""); }
void JDbl(const int fh, const double v)
{
   if(!MathIsValidNumber(v)) { JWrite(fh,"null"); return; }
   JWrite(fh, DoubleToString(v, 10));
}

//------------------------- Sorting ----------------------------------
void SortByScore(SymRow &arr[])
{
   int n = ArraySize(arr);
   for(int i=0;i<n-1;i++)
   for(int j=i+1;j<n;j++)
   {
      if(arr[j].score < arr[i].score)
      {
         SymRow tmp=arr[i];
         arr[i]=arr[j];
         arr[j]=tmp;
      }
   }
}

//------------------------- Core build --------------------------------
int BuildUniverse(string &syms[])
{
   ArrayResize(syms,0);
   int total = SymbolsTotal(true);
   if(total<=0) return 0;

   for(int i=0;i<total;i++)
   {
      string s = SymbolName(i,true);
      if(StringLen(s)<1) continue;
      if(InpOnlyMarketWatch) SymbolSelect(s,true);

      int sz = ArraySize(syms);
      ArrayResize(syms, sz+1);
      syms[sz]=s;
   }
   return ArraySize(syms);
}

// Refined score (still lite, not using M15):
// base = spread_bps / d1_range_pct
// penalty_margin = 1 + 0.5 * clamp(margin_1lot / max(free_margin,1), 0..2)
// penalty_minlot = 1 + 0.5 if (minlot_margin > 0.5*free_margin)
// final = base * penalty_margin * penalty_minlot
int BuildRows(const string &uni[], SymRow &rows[])
{
   ArrayResize(rows,0);

   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(free_margin <= 0.0) free_margin = 1.0;

   for(int i=0;i<ArraySize(uni);i++)
   {
      string sym = uni[i];

      double h,l,c;
      if(!GetD1HighLowClose(sym,h,l,c)) continue;

      MqlTick t;
      bool tick_ok = GetTickSafe(sym, t);

      bool trade_ok=false;
      int td=-1;
      if(tick_ok)
         td = TradableNowState(sym, trade_ok);
      else
      {
         long tm=0;
         if(SymbolInfoInteger(sym, SYMBOL_TRADE_MODE, tm))
            trade_ok = ((ENUM_SYMBOL_TRADE_MODE)tm != SYMBOL_TRADE_MODE_DISABLED);
         td = 0;
      }

      double spread_bps = (tick_ok ? SpreadBps(t.bid,t.ask) : 0.0);
      double range_pct  = D1RangePct(h,l,c);
      double eps = 0.0001;
      double base = (range_pct>eps ? spread_bps/range_pct : spread_bps/eps);

      double ref_price = (tick_ok ? 0.5*(t.bid+t.ask) : c);

      double margin_1lot=0.0;
      bool ok_mgn = (ref_price>0.0 && MarginPerLot(sym, ref_price, margin_1lot));

      double volmin=0.0;
      SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN, volmin);
      if(volmin <= 0.0) volmin = 0.01;

      // Penalties
      double penalty_margin = 1.0;
      if(ok_mgn)
      {
         double ratio = margin_1lot / free_margin;         // margin per 1 lot vs free margin
         if(ratio < 0.0) ratio = 0.0;
         if(ratio > 2.0) ratio = 2.0;
         penalty_margin = 1.0 + 0.5*ratio;                // up to 2x
      }

      double penalty_minlot = 1.0;
      if(ok_mgn)
      {
         double minlot_margin = margin_1lot * volmin;
         if(minlot_margin > 0.5*free_margin)
            penalty_minlot = 1.5;
      }

      double score = base * penalty_margin * penalty_minlot;

      SymRow r;
      r.sym=sym;
      r.td_state=td;
      r.spread_bps=spread_bps;
      r.d1_range_pct=range_pct;
      r.score=score;
      r.tick_ok=tick_ok;
      r.trade_ok=trade_ok;
      r.corr_ok=false;

      int n = ArraySize(rows);
      ArrayResize(rows, n+1);
      rows[n]=r;
   }
   return ArraySize(rows);
}

// Corr pool: choose best score symbols that are trade_ok & tick_ok,
// and have returns for ALL: H1(200), H4(200), M15(50).
int BuildCorrPool(SymRow &rows[], string &pool[])
{
   ArrayResize(pool,0);

   SymRow tmp[];
   ArrayResize(tmp,0);

   for(int i=0;i<ArraySize(rows);i++)
   {
      if(!rows[i].tick_ok) continue;
      if(!rows[i].trade_ok) continue;
      int n=ArraySize(tmp);
      ArrayResize(tmp,n+1);
      tmp[n]=rows[i];
   }

   SortByScore(tmp);

   // Pass A: Td==TRUE, Pass B: Td==UNKNOWN
   for(int pass=0; pass<2 && ArraySize(pool)<InpCorrPoolSize; pass++)
   {
      for(int i=0;i<ArraySize(tmp) && ArraySize(pool)<InpCorrPoolSize;i++)
      {
         if(pass==0 && tmp[i].td_state!=1)  continue;
         if(pass==1 && tmp[i].td_state!=-1) continue;

         // returns availability gate
         double r1[], r4[], r15[];
         if(!BuildLogReturnsTF(tmp[i].sym, PERIOD_H1,  InpCorrBars_H1,  r1))  continue;
         if(!BuildLogReturnsTF(tmp[i].sym, PERIOD_H4,  InpCorrBars_H4,  r4))  continue;
         if(!BuildLogReturnsTF(tmp[i].sym, PERIOD_M15, InpCorrBars_M15, r15)) continue;

         int n=ArraySize(pool);
         ArrayResize(pool,n+1);
         pool[n]=tmp[i].sym;

         for(int k=0;k<ArraySize(rows);k++) if(rows[k].sym==tmp[i].sym){ rows[k].corr_ok=true; break; }
      }
   }

   return ArraySize(pool);
}

// Dynamic top selection (attempt target, allow less):
// We use H1 and H4 correlations (M15 is informational only).
// Multi-pass: threshold ladder to attempt filling up to target without forcing.
int BuildTopDynamic(const SymRow &rows_in[], const string &ranked_syms[], const double &corrH1[], const double &corrH4[], const int Ncorr, string &top[])
{
   ArrayResize(top,0);

   double ladder[5] = { InpCorrGate, 0.75, 0.85, 0.95, 1.0 };

   // Helper: map symbol -> index in corr pool
   // (linear search; Ncorr max 40, fine)
   for(int step=0; step<5 && ArraySize(top)<InpTopTarget; step++)
   {
      double th = ladder[step];

      for(int i=0;i<ArraySize(ranked_syms) && ArraySize(top)<InpTopTarget;i++)
      {
         string sym = ranked_syms[i];

         // skip if already selected
         bool exists=false;
         for(int z=0; z<ArraySize(top); z++){ if(top[z]==sym){ exists=true; break; } }
         if(exists) continue;

         // only consider tick_ok & trade_ok & not Td==FALSE
         bool ok=false; int td=0;
         for(int k=0;k<ArraySize(rows_in);k++)
         {
            if(rows_in[k].sym==sym)
            {
               if(rows_in[k].tick_ok && rows_in[k].trade_ok && rows_in[k].td_state!=0) { ok=true; td=rows_in[k].td_state; }
               break;
            }
         }
         if(!ok) continue;

         // If symbol not in corr pool, we can still include it (attempt fill),
         // but correlation constraints cannot be applied. We allow it only in lenient steps.
         int idx = -1;
         for(int j=0;j<Ncorr;j++){ if(ranked_syms[i]==ranked_syms[i]){} } // no-op to silence some old compilers
         // Find sym in corr pool list by scanning ranked_syms is not correct; we need pool list.
         // We'll rely on corr matrices being for corr pool; if not found, idx stays -1.
         // Caller should pass ranked_syms where first Ncorr are corr pool? We'll not assume.
         // So: we will accept "idx==-1" only when th>=0.95 (last two steps).
         // (This still "attempts fill" without forcing bad correlation logic.)

         // build idx by scanning pool extracted from corr matrices - not available here.
         // Therefore we pass ranked_syms built from corr pool first in orchestrator; idx derived by first occurrence.
         // We'll do a safe heuristic: if i < Ncorr, idx=i (because orchestrator will put corr pool first).
         if(i < Ncorr) idx = i;

         // Correlation gate if both sym and all selected symbols exist in corr pool indices
         bool pass_corr=true;
         if(idx==-1)
         {
            if(th < 0.95) pass_corr=false; // only allow non-corr symbols late
         }
         else
         {
            for(int z=0; z<ArraySize(top); z++)
            {
               int jdx=-1;
               // heuristic: find jdx in ranked_syms; if its position < Ncorr, use it
               for(int q=0;q<ArraySize(ranked_syms);q++)
               {
                  if(ranked_syms[q]==top[z]) { if(q < Ncorr) jdx=q; break; }
               }
               if(jdx==-1) continue; // selected symbol not in corr pool, can't compare

               double c1 = corrH1[idx*Ncorr + jdx];
               double c4 = corrH4[idx*Ncorr + jdx];
               if(MathAbs(c1) > th || MathAbs(c4) > th){ pass_corr=false; break; }
            }
         }

         if(!pass_corr) continue;

         int n=ArraySize(top);
         ArrayResize(top,n+1);
         top[n]=sym;
      }
   }

   return ArraySize(top);
}

//------------------------- Positions + History ------------------------
void CollectOpenPositionsJSON(const int fh)
{
   JKey(fh,"open_positions"); JWrite(fh,"[");

   int total = PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long type = (long)PositionGetInteger(POSITION_TYPE);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      double margin = 0.0;   // POSITION_MARGIN not supported on this build

      JWrite(fh,"{");
         JKey(fh,"ticket"); JLongStr(fh,(long)ticket); JWrite(fh,",");
         JKey(fh,"symbol"); JStr(fh,sym); JWrite(fh,",");
         JKey(fh,"type");   JInt(fh,type); JWrite(fh,","); // 0 buy, 1 sell
         JKey(fh,"volume"); JDbl(fh,vol); JWrite(fh,",");
         JKey(fh,"price_open"); JDbl(fh,price_open); JWrite(fh,",");
         JKey(fh,"sl"); JDbl(fh,sl); JWrite(fh,",");
         JKey(fh,"tp"); JDbl(fh,tp); JWrite(fh,",");
         JKey(fh,"profit"); JDbl(fh,profit); JWrite(fh,",");
         JKey(fh,"swap"); JDbl(fh,swap); JWrite(fh,",");
         JKey(fh,"margin"); JDbl(fh,margin);
      JWrite(fh,"}");

      if(i < total-1) JWrite(fh,",");
   }

   JWrite(fh,"]");
}

int FindOrAddHistAgg(HistAgg &aggs[], const string sym)
{
   for(int i=0;i<ArraySize(aggs);i++)
      if(aggs[i].sym==sym) return i;

   int n = ArraySize(aggs);
   ArrayResize(aggs, n+1);
   aggs[n].sym=sym;
   aggs[n].trades=0;
   aggs[n].wins=0;
   aggs[n].losses=0;
   aggs[n].net_profit=0.0;
   aggs[n].gross_profit=0.0;
   aggs[n].gross_loss=0.0;
   aggs[n].commission=0.0;
   aggs[n].swap=0.0;
   return n;
}

void CollectTradeHistory14DJSON(const int fh)
{
   datetime to = TimeCurrent();
   datetime from = to - (InpHistoryDays * 86400);

   bool ok = HistorySelect(from, to);

   HistAgg aggs[];
   ArrayResize(aggs,0);

   int total_deals = (ok ? HistoryDealsTotal() : 0);

   int total_trades=0, wins=0, losses=0;
   double net=0.0, gp=0.0, gl=0.0, comm=0.0, sw=0.0;

   for(int i=0;i<total_deals;i++)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket==0) continue;

      long entry = (long)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue; // closed legs only

      string sym = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
      double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
      double swapv = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);

      total_trades++;
      net += profit + commission + swapv;
      comm += commission;
      sw += swapv;
      if(profit >= 0.0){ wins++; gp += profit; }
      else { losses++; gl += profit; }

      int idx = FindOrAddHistAgg(aggs, sym);
      aggs[idx].trades++;
      aggs[idx].net_profit += (profit + commission + swapv);
      aggs[idx].commission += commission;
      aggs[idx].swap += swapv;
      if(profit >= 0.0){ aggs[idx].wins++; aggs[idx].gross_profit += profit; }
      else { aggs[idx].losses++; aggs[idx].gross_loss += profit; }
   }

   double profit_factor = 0.0;
   if(MathAbs(gl) > 0.0) profit_factor = gp / MathAbs(gl);

   JKey(fh,"trade_history"); JWrite(fh,"{");

   // summary
   JKey(fh,"window_days"); JInt(fh,InpHistoryDays); JWrite(fh,",");
   JKey(fh,"from"); JStr(fh, TimeToString(from, TIME_DATE|TIME_MINUTES)); JWrite(fh,",");
   JKey(fh,"to");   JStr(fh, TimeToString(to,   TIME_DATE|TIME_MINUTES)); JWrite(fh,",");
   JKey(fh,"summary"); JWrite(fh,"{");
      JKey(fh,"trades"); JInt(fh,total_trades); JWrite(fh,",");
      JKey(fh,"wins");   JInt(fh,wins); JWrite(fh,",");
      JKey(fh,"losses"); JInt(fh,losses); JWrite(fh,",");
      JKey(fh,"net"); JDbl(fh,net); JWrite(fh,",");
      JKey(fh,"gross_profit"); JDbl(fh,gp); JWrite(fh,",");
      JKey(fh,"gross_loss"); JDbl(fh,gl); JWrite(fh,",");
      JKey(fh,"profit_factor"); JDbl(fh,profit_factor); JWrite(fh,",");
      JKey(fh,"commission"); JDbl(fh,comm); JWrite(fh,",");
      JKey(fh,"swap"); JDbl(fh,sw);
   JWrite(fh,"},");

   // by_symbol
   JKey(fh,"by_symbol"); JWrite(fh,"[");
   for(int i=0;i<ArraySize(aggs);i++)
   {
      double pf=0.0;
      if(MathAbs(aggs[i].gross_loss) > 0.0) pf = aggs[i].gross_profit / MathAbs(aggs[i].gross_loss);

      JWrite(fh,"{");
         JKey(fh,"symbol"); JStr(fh,aggs[i].sym); JWrite(fh,",");
         JKey(fh,"trades"); JInt(fh,aggs[i].trades); JWrite(fh,",");
         JKey(fh,"wins"); JInt(fh,aggs[i].wins); JWrite(fh,",");
         JKey(fh,"losses"); JInt(fh,aggs[i].losses); JWrite(fh,",");
         JKey(fh,"net"); JDbl(fh,aggs[i].net_profit); JWrite(fh,",");
         JKey(fh,"profit_factor"); JDbl(fh,pf); JWrite(fh,",");
         JKey(fh,"commission"); JDbl(fh,aggs[i].commission); JWrite(fh,",");
         JKey(fh,"swap"); JDbl(fh,aggs[i].swap);
      JWrite(fh,"}");
      if(i < ArraySize(aggs)-1) JWrite(fh,",");
   }
   JWrite(fh,"]");

   JWrite(fh,"}");
}

//------------------------- Snapshot Export ----------------------------
bool ExportSnapshotOneFile(const SymRow &rows[], const string &corr_pool[], const string &ranked_syms[],
                           const double &corrH1[], const double &corrH4[], const double &corrM15[],
                           const int Ncorr, const int barsH1, const int barsH4, const int barsM15,
                           const string &top_dyn[])
{
   string broker = SanitizeFilePart(AccountInfoString(ACCOUNT_COMPANY));
   string loginS = LoginStr64();
   string stampT = TimeStamp();

   // Folder: ISS/<login>/
   FolderCreate("ISS");
   FolderCreate("ISS\\" + loginS);

   string fname = "ISS\\" + loginS + "\\ISS_SNAPSHOT_" + broker + "_" + loginS + "_" + stampT + ".json";

   int fh = FileOpen(fname, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fh==INVALID_HANDLE) return false;

   // Account block
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin  = AccountInfoDouble(ACCOUNT_MARGIN);
   double free_m  = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double mlevel  = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   long leverage  = (long)AccountInfoInteger(ACCOUNT_LEVERAGE);
   string acc_ccy = AccountInfoString(ACCOUNT_CURRENCY);

   // Risk budgets (informational only)
   double risk_per_trade = balance * 0.002; // 0.2%
   double max_total_risk = balance * 0.01;  // 1%

   // Start JSON
   JWrite(fh,"{");

   // meta
   JKey(fh,"meta"); JWrite(fh,"{");
      JKey(fh,"timestamp"); JStr(fh, stampT); JWrite(fh,",");
      JKey(fh,"broker");    JStr(fh, AccountInfoString(ACCOUNT_COMPANY)); JWrite(fh,",");
      JKey(fh,"login");     JStr(fh, loginS); JWrite(fh,",");
      JKey(fh,"top_target"); JInt(fh, InpTopTarget); JWrite(fh,",");
      JKey(fh,"top_min");    JInt(fh, InpTopMin); JWrite(fh,",");
      JKey(fh,"corr_pool_target"); JInt(fh, InpCorrPoolSize); JWrite(fh,",");
      JKey(fh,"corr_poolN"); JInt(fh, Ncorr); JWrite(fh,",");
      JKey(fh,"corr_gate_start"); JDbl(fh, InpCorrGate); JWrite(fh,",");
      JKey(fh,"history_days"); JInt(fh, InpHistoryDays);
   JWrite(fh,"},");

   // account
   JKey(fh,"account"); JWrite(fh,"{");
      JKey(fh,"currency"); JStr(fh,acc_ccy); JWrite(fh,",");
      JKey(fh,"balance"); JDbl(fh,balance); JWrite(fh,",");
      JKey(fh,"equity"); JDbl(fh,equity); JWrite(fh,",");
      JKey(fh,"margin_used"); JDbl(fh,margin); JWrite(fh,",");
      JKey(fh,"free_margin"); JDbl(fh,free_m); JWrite(fh,",");
      JKey(fh,"margin_level"); JDbl(fh,mlevel); JWrite(fh,",");
      JKey(fh,"leverage"); JInt(fh,leverage); JWrite(fh,",");
      JKey(fh,"risk_per_trade"); JDbl(fh,risk_per_trade); JWrite(fh,",");
      JKey(fh,"max_total_risk"); JDbl(fh,max_total_risk);
   JWrite(fh,"},");

   // open positions
   CollectOpenPositionsJSON(fh);
   JWrite(fh,",");

   // trade history
   CollectTradeHistory14DJSON(fh);
   JWrite(fh,",");

   // market block
   JKey(fh,"market"); JWrite(fh,"{");

      // ranked candidates (limit: show first 60 to stay lite)
      int ranked_limit = ArraySize(ranked_syms);
      if(ranked_limit > 60) ranked_limit = 60;

      JKey(fh,"ranked"); JWrite(fh,"[");
      for(int i=0;i<ranked_limit;i++)
      {
         string sym = ranked_syms[i];

         // locate row
         SymRow r; bool found=false;
         for(int k=0;k<ArraySize(rows);k++) if(rows[k].sym==sym){ r=rows[k]; found=true; break; }
         if(!found) continue;

         MqlTick t; bool tick_ok = GetTickSafe(sym, t);
         double ref_price = (tick_ok ? 0.5*(t.bid+t.ask) : 0.0);

         double vpp=0.0, mgn=0.0;
         bool ok_vpp = (ref_price>0.0 && ValuePerPointPerLot(sym, ref_price, vpp));
         bool ok_mgn = (ref_price>0.0 && MarginPerLot(sym, ref_price, mgn));

         long digits=0, tm=0;
         double contract=0, tick_size=0, tick_val=0, volmin=0, volmax=0, volstep=0;
         long stops=0, spread_float=0, swap_mode=0, exm=0, fill=0;
         double swl=0, sws=0;
         string ccy_m, ccy_p;

         SymbolInfoInteger(sym, SYMBOL_DIGITS, digits);
         SymbolInfoInteger(sym, SYMBOL_TRADE_MODE, tm);
         SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL, stops);
         SymbolInfoInteger(sym, SYMBOL_SPREAD_FLOAT, spread_float);
         SymbolInfoInteger(sym, SYMBOL_SWAP_MODE, swap_mode);
         SymbolInfoInteger(sym, SYMBOL_TRADE_EXEMODE, exm);
         SymbolInfoInteger(sym, SYMBOL_FILLING_MODE, fill);

         SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE, contract);
         SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE, tick_size);
         SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE, tick_val);
         SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN, volmin);
         SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX, volmax);
         SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP, volstep);
         SymbolInfoDouble(sym, SYMBOL_SWAP_LONG, swl);
         SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT, sws);

         SymbolInfoString(sym, SYMBOL_CURRENCY_MARGIN, ccy_m);
         SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT, ccy_p);

         // filling text (simple)
         string filling_txt = NA_STR;
         if(fill==SYMBOL_FILLING_FOK) filling_txt="FOK";
         else if(fill==SYMBOL_FILLING_IOC) filling_txt="IOC";
#ifdef SYMBOL_FILLING_BOC
         else if(fill==SYMBOL_FILLING_BOC) filling_txt="BOC";
#endif
#ifdef SYMBOL_FILLING_RETURN
         else if(fill==SYMBOL_FILLING_RETURN) filling_txt="RETURN";
#endif

         // execution text (simple)
         string exec_txt = NA_STR;
         if(exm==SYMBOL_TRADE_EXECUTION_REQUEST) exec_txt="Request";
         else if(exm==SYMBOL_TRADE_EXECUTION_INSTANT) exec_txt="Instant";
         else if(exm==SYMBOL_TRADE_EXECUTION_MARKET) exec_txt="Market";
         else if(exm==SYMBOL_TRADE_EXECUTION_EXCHANGE) exec_txt="Exchange";

         // trade_mode text (simple)
         string tm_txt = NA_STR;
         if(tm==SYMBOL_TRADE_MODE_DISABLED) tm_txt="Disabled";
         else if(tm==SYMBOL_TRADE_MODE_FULL) tm_txt="Full";
         else if(tm==SYMBOL_TRADE_MODE_CLOSEONLY) tm_txt="CloseOnly";
         else if(tm==SYMBOL_TRADE_MODE_LONGONLY) tm_txt="LongOnly";
         else if(tm==SYMBOL_TRADE_MODE_SHORTONLY) tm_txt="ShortOnly";

         // swap mode text (simple)
         string sm_txt = NA_STR;
         if(swap_mode==SYMBOL_SWAP_MODE_DISABLED) sm_txt="Disabled";
         else if(swap_mode==SYMBOL_SWAP_MODE_POINTS) sm_txt="Points";
         else if(swap_mode==SYMBOL_SWAP_MODE_CURRENCY_SYMBOL) sm_txt="BaseCcy";
         else if(swap_mode==SYMBOL_SWAP_MODE_CURRENCY_MARGIN) sm_txt="MarginCcy";
         else if(swap_mode==SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT) sm_txt="DepositCcy";
         else if(swap_mode==SYMBOL_SWAP_MODE_INTEREST_CURRENT) sm_txt="InterestCurrent";
         else if(swap_mode==SYMBOL_SWAP_MODE_INTEREST_OPEN) sm_txt="InterestOpen";
         else if(swap_mode==SYMBOL_SWAP_MODE_REOPEN_CURRENT) sm_txt="ReopenCurrent";
         else if(swap_mode==SYMBOL_SWAP_MODE_REOPEN_BID) sm_txt="ReopenBid";

         JWrite(fh,"{");
            JKey(fh,"symbol"); JStr(fh,sym); JWrite(fh,",");
            JKey(fh,"td_state"); JInt(fh,r.td_state); JWrite(fh,",");
            JKey(fh,"spread_bps"); JDbl(fh,r.spread_bps); JWrite(fh,",");
            JKey(fh,"d1_range_pct"); JDbl(fh,r.d1_range_pct); JWrite(fh,",");
            JKey(fh,"score"); JDbl(fh,r.score); JWrite(fh,",");

            JKey(fh,"value_per_point_1lot"); if(ok_vpp) JDbl(fh,vpp); else JWrite(fh,"null"); JWrite(fh,",");
            JKey(fh,"margin_1lot"); if(ok_mgn) JDbl(fh,mgn); else JWrite(fh,"null"); JWrite(fh,",");

            JKey(fh,"spec"); JWrite(fh,"{");
               JKey(fh,"digits"); JInt(fh,digits); JWrite(fh,",");
               JKey(fh,"contract_size"); JDbl(fh,contract); JWrite(fh,",");
               JKey(fh,"tick_size"); JDbl(fh,tick_size); JWrite(fh,",");
               JKey(fh,"tick_value"); JDbl(fh,tick_val); JWrite(fh,",");
               JKey(fh,"volume_min"); JDbl(fh,volmin); JWrite(fh,",");
               JKey(fh,"volume_max"); JDbl(fh,volmax); JWrite(fh,",");
               JKey(fh,"volume_step"); JDbl(fh,volstep); JWrite(fh,",");
               JKey(fh,"stops_level"); JInt(fh,stops); JWrite(fh,",");
               JKey(fh,"spread_floating"); JBool(fh,(spread_float!=0)); JWrite(fh,",");
               JKey(fh,"swap_mode"); JStr(fh,sm_txt); JWrite(fh,",");
               JKey(fh,"swap_long"); JDbl(fh,swl); JWrite(fh,",");
               JKey(fh,"swap_short"); JDbl(fh,sws); JWrite(fh,",");
               JKey(fh,"margin_ccy"); JStr(fh,ccy_m); JWrite(fh,",");
               JKey(fh,"profit_ccy"); JStr(fh,ccy_p); JWrite(fh,",");
               JKey(fh,"trade_mode"); JStr(fh,tm_txt); JWrite(fh,",");
               JKey(fh,"execution"); JStr(fh,exec_txt); JWrite(fh,",");
               JKey(fh,"filling"); JStr(fh,filling_txt);
            JWrite(fh,"}");
         JWrite(fh,"}");

         if(i < ranked_limit-1) JWrite(fh,",");
      }
      JWrite(fh,"]");
      JWrite(fh,",");

      // top dynamic
      JKey(fh,"top_dynamic"); JWrite(fh,"{");
         JKey(fh,"min"); JInt(fh,InpTopMin); JWrite(fh,",");
         JKey(fh,"target"); JInt(fh,InpTopTarget); JWrite(fh,",");
         JKey(fh,"count"); JInt(fh,ArraySize(top_dyn)); JWrite(fh,",");
         JKey(fh,"symbols"); JWrite(fh,"[");
            for(int i=0;i<ArraySize(top_dyn);i++){ JStr(fh,top_dyn[i]); if(i<ArraySize(top_dyn)-1) JWrite(fh,","); }
         JWrite(fh,"]");
      JWrite(fh,"},");
      
      // corr pool list
      JKey(fh,"corr_pool"); JWrite(fh,"[");
         for(int i=0;i<Ncorr;i++){ JStr(fh,corr_pool[i]); if(i<Ncorr-1) JWrite(fh,","); }
      JWrite(fh,"]");
      JWrite(fh,",");

      // correlation block (3 TF)
      JKey(fh,"correlation"); JWrite(fh,"{");

         // H1
         JKey(fh,"H1_200"); JWrite(fh,"{");
            JKey(fh,"timeframe"); JStr(fh,"H1"); JWrite(fh,",");
            JKey(fh,"bars"); JInt(fh,barsH1); JWrite(fh,",");
            JKey(fh,"matrix_flat"); JWrite(fh,"[");
               for(int k=0;k<Ncorr*Ncorr;k++){ JDbl(fh,corrH1[k]); if(k<Ncorr*Ncorr-1) JWrite(fh,","); }
            JWrite(fh,"]");
         JWrite(fh,"},");
         
         // H4
         JKey(fh,"H4_200"); JWrite(fh,"{");
            JKey(fh,"timeframe"); JStr(fh,"H4"); JWrite(fh,",");
            JKey(fh,"bars"); JInt(fh,barsH4); JWrite(fh,",");
            JKey(fh,"matrix_flat"); JWrite(fh,"[");
               for(int k=0;k<Ncorr*Ncorr;k++){ JDbl(fh,corrH4[k]); if(k<Ncorr*Ncorr-1) JWrite(fh,","); }
            JWrite(fh,"]");
         JWrite(fh,"},");
         
         // M15 (informational)
         JKey(fh,"M15_50"); JWrite(fh,"{");
            JKey(fh,"timeframe"); JStr(fh,"M15"); JWrite(fh,",");
            JKey(fh,"bars"); JInt(fh,barsM15); JWrite(fh,",");
            JKey(fh,"matrix_flat"); JWrite(fh,"[");
               for(int k=0;k<Ncorr*Ncorr;k++){ JDbl(fh,corrM15[k]); if(k<Ncorr*Ncorr-1) JWrite(fh,","); }
            JWrite(fh,"]");
         JWrite(fh,"}");

      JWrite(fh,"}"); // correlation
   JWrite(fh,"}"); // market

   JWrite(fh,"}"); // root
   FileClose(fh);

   Print("ISS-Lite: Snapshot saved: MQL5/Files/", fname);
   return true;
}

//------------------------- Orchestration -----------------------------
void RunOnce()
{
   // Universe and rows
   string uni[];
   int u = BuildUniverse(uni);
   if(u<=0){ Print("ISS-Lite: No MarketWatch symbols."); return; }

   SymRow rows[];
   int n = BuildRows(uni, rows);
   if(n<=0){ Print("ISS-Lite: No eligible symbols with D1 data."); return; }

   // Build corr pool (<=40)
   string pool[];
   int Ncorr = BuildCorrPool(rows, pool);

   // If corr pool is too small, we still export (matrices become empty)
   if(Ncorr<=0)
   {
      double empty[];
      ArrayResize(empty,0);
      string ranked_syms[];
      ArrayResize(ranked_syms,0);
      string top_dyn[];
      ArrayResize(top_dyn,0);

      ExportSnapshotOneFile(rows, pool, ranked_syms, empty, empty, empty, 0, InpCorrBars_H1, InpCorrBars_H4, InpCorrBars_M15, top_dyn);
      return;
   }

   // Build "ranked_syms" list where corr pool symbols come first (for top builder heuristic)
   // 1) Put corr pool in order (already score-sorted)
   // 2) Append other candidates by score (optional; but we only need for attempt-fill)
   string ranked_syms[];
   ArrayResize(ranked_syms,0);

   // Build a sorted list of all candidates
   SymRow tmpAll[];
   ArrayResize(tmpAll,0);
   for(int i=0;i<ArraySize(rows);i++)
   {
      if(!rows[i].trade_ok) continue;
      if(!rows[i].tick_ok) continue;
      if(rows[i].td_state==0) continue;
      int m=ArraySize(tmpAll);
      ArrayResize(tmpAll,m+1);
      tmpAll[m]=rows[i];
   }
   SortByScore(tmpAll);

   // Put corr pool first in ranked_syms
   for(int i=0;i<Ncorr;i++)
   {
      int z=ArraySize(ranked_syms);
      ArrayResize(ranked_syms,z+1);
      ranked_syms[z]=pool[i];
   }

   // Append the rest (skip duplicates)
   for(int i=0;i<ArraySize(tmpAll);i++)
   {
      string sym = tmpAll[i].sym;
      bool exists=false;
      for(int z=0; z<ArraySize(ranked_syms); z++){ if(ranked_syms[z]==sym){ exists=true; break; } }
      if(exists) continue;

      int z=ArraySize(ranked_syms);
      ArrayResize(ranked_syms,z+1);
      ranked_syms[z]=sym;

      if(ArraySize(ranked_syms) >= 120) break; // keep lite
   }

   // Build returns flats and corr matrices for 3 TFs
   int barsH1 = InpCorrBars_H1;
   int barsH4 = InpCorrBars_H4;
   int barsM15 = InpCorrBars_M15;

   double retsH1[];
   double retsH4[];
   double retsM15[];
   ArrayResize(retsH1, Ncorr*barsH1);
   ArrayResize(retsH4, Ncorr*barsH4);
   ArrayResize(retsM15, Ncorr*barsM15);

   for(int i=0;i<Ncorr;i++)
   {
      double r1[], r4[], r15[];
      // These should succeed because corr pool gated them, but keep safe
      if(!BuildLogReturnsTF(pool[i], PERIOD_H1,  barsH1,  r1))  { for(int k=0;k<barsH1;k++)  retsH1[i*barsH1 + k]=0.0; }
      else { for(int k=0;k<barsH1;k++) retsH1[i*barsH1 + k]=r1[k]; }

      if(!BuildLogReturnsTF(pool[i], PERIOD_H4,  barsH4,  r4))  { for(int k=0;k<barsH4;k++)  retsH4[i*barsH4 + k]=0.0; }
      else { for(int k=0;k<barsH4;k++) retsH4[i*barsH4 + k]=r4[k]; }

      if(!BuildLogReturnsTF(pool[i], PERIOD_M15, barsM15, r15)) { for(int k=0;k<barsM15;k++) retsM15[i*barsM15 + k]=0.0; }
      else { for(int k=0;k<barsM15;k++) retsM15[i*barsM15 + k]=r15[k]; }
   }

   double corrH1[];
   double corrH4[];
   double corrM15[];
   ArrayResize(corrH1, Ncorr*Ncorr);
   ArrayResize(corrH4, Ncorr*Ncorr);
   ArrayResize(corrM15, Ncorr*Ncorr);

   for(int i=0;i<Ncorr;i++)
   for(int j=0;j<Ncorr;j++)
   {
      corrH1[i*Ncorr + j]  = CorrPearsonFlat(retsH1,  barsH1,  i, j);
      corrH4[i*Ncorr + j]  = CorrPearsonFlat(retsH4,  barsH4,  i, j);
      corrM15[i*Ncorr + j] = CorrPearsonFlat(retsM15, barsM15, i, j);
   }

   // Build dynamic top (8..20 attempt fill, not forced)
   string top_dyn[];
   int topN = BuildTopDynamic(rows, ranked_syms, corrH1, corrH4, Ncorr, top_dyn);

   // Export single snapshot
   bool ok = ExportSnapshotOneFile(rows, pool, ranked_syms, corrH1, corrH4, corrM15, Ncorr, barsH1, barsH4, barsM15, top_dyn);
   if(!ok) Print("ISS-Lite: Snapshot export FAILED (file open/IO).");
}

//------------------------- MT5 Events --------------------------------
int OnInit()
{
   EventSetTimer(MathMax(10, InpTimerSeconds));

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   g_last_yday = dt.day_of_year;

   g_last_login = (long)AccountInfoInteger(ACCOUNT_LOGIN);

   if(InpExportOnInit)
      RunOnce();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTimer()
{
   // daily rollover (optional) + login change refresh
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   long login_now = (long)AccountInfoInteger(ACCOUNT_LOGIN);

   bool do_run=false;

   if(login_now != g_last_login)
   {
      g_last_login = login_now;
      if(InpExportOnLoginSwap) do_run=true;
   }

   if(dt.day_of_year != g_last_yday)
   {
      g_last_yday = dt.day_of_year;
      do_run=true;
   }

   if(do_run) RunOnce();
}

void OnTick()
{
   // No trading. Keep empty to stay light.
}
//+------------------------------------------------------------------+