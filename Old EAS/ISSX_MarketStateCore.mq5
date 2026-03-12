#property strict
#property version   "1.10"
#property description "ISSX MarketStateCore (EA1) thin wrapper"

#include <ISSX/issx_engine.mqh>

input string InpFirmId                = "";
input bool   InpRunSmokeOnInit        = true;
input bool   InpWriteDebugRoot        = true;
input bool   InpRenderHudOnChart      = true;
input int    InpHeartbeatDebugSeconds = 60;
input int    InpMaxSymbolsPerCycle    = 0;     // 0 = all broker-known symbols
input bool   InpIncludeCustomSymbols  = false; // false = skip custom symbols

struct ISSX_EA1_RawSpec
  {
   string symbol_raw;
   string path;
   string description;

   long   trade_mode;
   long   calc_mode;
   long   digits;

   double point;
   double tick_size;
   double tick_value;
   double tick_value_profit;
   double tick_value_loss;
   double contract_size;

   double volume_min;
   double volume_step;
   double volume_max;

   long   stops_level;
   long   freeze_level;

   string margin_currency;
   string profit_currency;
   string base_currency;
   string quote_currency;

   double swap_long;
   double swap_short;
   long   swap_mode;

   bool   session_trade_available;
   bool   session_quote_available;
   int    session_window_count;
   int    session_quote_window_count;

   bool   selected;
   bool   custom_symbol;
   bool   visible;
   bool   tick_ok;
   long   tick_time_msc;
   double tick_bid;
   double tick_ask;
   double tick_last;

   int    property_fail_count;
   bool   metadata_ready;

   void Reset()
     {
      symbol_raw="";
      path="";
      description="";
      trade_mode=0;
      calc_mode=0;
      digits=0;
      point=0.0;
      tick_size=0.0;
      tick_value=0.0;
      tick_value_profit=0.0;
      tick_value_loss=0.0;
      contract_size=0.0;
      volume_min=0.0;
      volume_step=0.0;
      volume_max=0.0;
      stops_level=0;
      freeze_level=0;
      margin_currency="";
      profit_currency="";
      base_currency="";
      quote_currency="";
      swap_long=0.0;
      swap_short=0.0;
      swap_mode=0;
      session_trade_available=false;
      session_quote_available=false;
      session_window_count=0;
      session_quote_window_count=0;
      selected=false;
      custom_symbol=false;
      visible=false;
      tick_ok=false;
      tick_time_msc=0;
      tick_bid=0.0;
      tick_ask=0.0;
      tick_last=0.0;
      property_fail_count=0;
      metadata_ready=false;
     }
  };

struct ISSX_EA1_GateInfo
  {
   bool   identity_ready;
   bool   sync_ready;
   bool   session_ready;
   bool   market_ready;
   bool   spec_ready;
   bool   cost_ready;
   bool   rankability_gate_ready;
   bool   gate_passed;
   string primary_block_reason;
   string secondary_block_reason;
   bool   recoverable_next_cycle;
   double gate_confidence;
   int    gate_pass_cycles;
   int    gate_flap_count;

   void Reset()
     {
      identity_ready=false;
      sync_ready=false;
      session_ready=false;
      market_ready=false;
      spec_ready=false;
      cost_ready=false;
      rankability_gate_ready=false;
      gate_passed=false;
      primary_block_reason="";
      secondary_block_reason="";
      recoverable_next_cycle=false;
      gate_confidence=0.0;
      gate_pass_cycles=0;
      gate_flap_count=0;
     }
  };

struct ISSX_EA1_CycleCounters
  {
   int broker_universe;
   int eligible_universe;
   int active_universe;
   int frontier_universe;
   int rankable_universe;

   int pulse_open_usable;
   int pulse_open_cautious;
   int pulse_quote_only;
   int pulse_blocked;

   int custom_symbol_count;
   int selected_symbol_count;

   int fx_count;
   int metal_count;
   int crypto_count;
   int index_count;
   int other_count;

   int bucket_fx_major_count;
   int bucket_fx_cross_count;
   int bucket_metals_count;
   int bucket_crypto_count;
   int bucket_indices_count;
   int bucket_other_count;

   int very_cheap_count;
   int cheap_count;
   int moderate_count;
   int expensive_count;
   int blocked_tradeability_count;

   int missing_tick_count;
   int session_ambiguous_count;
   int metadata_degraded_count;
   int rejected_count;
   int gate_pass_count;

   void Reset()
     {
      broker_universe=0;
      eligible_universe=0;
      active_universe=0;
      frontier_universe=0;
      rankable_universe=0;

      pulse_open_usable=0;
      pulse_open_cautious=0;
      pulse_quote_only=0;
      pulse_blocked=0;

      custom_symbol_count=0;
      selected_symbol_count=0;

      fx_count=0;
      metal_count=0;
      crypto_count=0;
      index_count=0;
      other_count=0;

      bucket_fx_major_count=0;
      bucket_fx_cross_count=0;
      bucket_metals_count=0;
      bucket_crypto_count=0;
      bucket_indices_count=0;
      bucket_other_count=0;

      very_cheap_count=0;
      cheap_count=0;
      moderate_count=0;
      expensive_count=0;
      blocked_tradeability_count=0;

      missing_tick_count=0;
      session_ambiguous_count=0;
      metadata_degraded_count=0;
      rejected_count=0;
      gate_pass_count=0;
     }
  };

class CISSXMarketStateCoreApp
  {
private:
   string                  m_firm_id;
   string                  m_boot_id;
   long                    m_sequence_no;
   long                    m_started_ms;
   long                    m_last_timer_ms;
   long                    m_last_debug_publish_ms;
   long                    m_last_scan_ms;
   ISSX_FieldRegistry      m_field_reg;
   ISSX_EnumRegistry       m_enum_reg;
   ISSX_ComparatorRegistry m_cmp_reg;
   ISSX_EA1_State          m_state;
   ISSX_HudSnapshot        m_hud;
   ISSX_WarningAccumulator m_warns;
   string                  m_last_report;

   ISSX_EA1_RawSpec        m_specs[];
   ISSX_EA1_GateInfo       m_gates[];

private:
   static string IntToStr(const long v)
     {
      return StringFormat("%I64d",v);
     }

   static string LowerNoSpaces(const string s)
     {
      string out=ISSX_Util::Lower(ISSX_Util::Trim(s));
      StringReplace(out," ","");
      return out;
     }
     
   static string LowerTrim(const string s)
     {
      return ISSX_Util::Lower(ISSX_Util::Trim(s));
     }
     
        static string UpperTrim(const string s)
     {
      string out=ISSX_Util::Trim(s);
      StringToUpper(out);
      return out;
     }
     
   static bool IsAsciiLetter(const ushort ch)
     {
      return ((ch>='A' && ch<='Z') || (ch>='a' && ch<='z'));
     }

   static bool IsAsciiDigit(const ushort ch)
     {
      return (ch>='0' && ch<='9');
     }

   static string LettersOnlyPrefix(const string s)
     {
      string out="";
      for(int i=0;i<StringLen(s);i++)
        {
         ushort ch=(ushort)StringGetCharacter(s,i);
         if(IsAsciiLetter(ch))
            out+=ShortToString((short)ch);
         else
            break;
        }
      return out;
     }

   static string LettersOnlySuffix(const string s)
     {
      string out="";
      for(int i=StringLen(s)-1;i>=0;i--)
        {
         ushort ch=(ushort)StringGetCharacter(s,i);
         if(IsAsciiLetter(ch))
            out=ShortToString((short)ch)+out;
         else
            break;
        }
      return out;
     }

   static string ExtractCanonicalRoot(const string symbol)
     {
      string s=ISSX_Util::Trim(symbol);
      string letters="";
      for(int i=0;i<StringLen(s);i++)
        {
         ushort ch=(ushort)StringGetCharacter(s,i);
         if(IsAsciiLetter(ch))
            letters+=ShortToString((short)ch);
        }

      if(StringLen(letters)>=6)
         return ISSX_Util::Lower(StringSubstr(letters,0,6));
      if(StringLen(letters)>0)
         return ISSX_Util::Lower(letters);

      return LowerNoSpaces(symbol);
     }

   static string DeriveQuoteCurrency(const string canonical_root)
     {
      if(StringLen(canonical_root)>=6)
         return StringSubstr(canonical_root,3,3);
      return "";
     }

   static bool IsKnownCurrency(const string ccy)
     {
      string u=UpperTrim(ccy);
      return (u=="USD" || u=="EUR" || u=="GBP" || u=="JPY" || u=="CHF" || u=="CAD" ||
              u=="AUD" || u=="NZD" || u=="SGD" || u=="HKD" || u=="CNH" || u=="SEK" ||
              u=="NOK" || u=="DKK" || u=="ZAR" || u=="MXN" || u=="TRY" || u=="PLN" ||
              u=="CZK" || u=="HUF");
     }

   static string SafeQuoteCurrencyForAsset(const string asset_class,const string canonical_root,const string broker_profit_ccy)
     {
      string q=UpperTrim(broker_profit_ccy);
      if(asset_class=="fx" || asset_class=="metal" || asset_class=="crypto")
        {
         string d=UpperTrim(DeriveQuoteCurrency(canonical_root));
         if(IsKnownCurrency(d))
            return d;
         if(IsKnownCurrency(q))
            return q;
        }
      return "";
     }

   static bool HasEconomicallyValidQuote(const bool tick_ok,const double bid,const double ask,const double point)
     {
      if(!tick_ok) return false;
      if(point<=0.0) return false;
      if(bid<=0.0 || ask<=0.0) return false;
      if(ask<bid) return false;
      return true;
     }

   static string JoinCsv2(const string a,const string b)
     {
      if(ISSX_Util::IsEmpty(a)) return b;
      if(ISSX_Util::IsEmpty(b)) return a;
      return a+","+b;
     }

   static string DetectAssetClass(const string symbol_lc,const string path_lc,const string desc_lc)
     {
      if(StringFind(symbol_lc,"xau")>=0 || StringFind(symbol_lc,"xag")>=0 || StringFind(desc_lc,"gold")>=0 || StringFind(desc_lc,"silver")>=0)
         return "metal";

      if(StringFind(symbol_lc,"btc")>=0 || StringFind(symbol_lc,"eth")>=0 || StringFind(symbol_lc,"crypto")>=0 ||
         StringFind(desc_lc,"crypto")>=0 || StringFind(desc_lc,"bitcoin")>=0 || StringFind(desc_lc,"ethereum")>=0)
         return "crypto";

      if(StringFind(path_lc,"indices")>=0 || StringFind(desc_lc,"index")>=0 ||
         StringFind(symbol_lc,"us30")>=0 || StringFind(symbol_lc,"nas")>=0 || StringFind(symbol_lc,"spx")>=0 ||
         StringFind(symbol_lc,"ger")>=0 || StringFind(symbol_lc,"uk100")>=0 || StringFind(symbol_lc,"jp225")>=0)
         return "index";

      if(StringLen(symbol_lc)>=6)
        {
         bool first6letters=true;
         for(int i=0;i<6;i++)
           {
            ushort ch=(ushort)StringGetCharacter(symbol_lc,i);
            if(!(ch>='a' && ch<='z'))
              {
               first6letters=false;
               break;
              }
           }
         if(first6letters)
            return "fx";
        }

      return "other";
     }

   static string DetectInstrumentFamily(const string asset_class,const string symbol_lc,const string canonical_root)
     {
      if(asset_class=="metal")
         return "metals";
      if(asset_class=="crypto")
         return "crypto";
      if(asset_class=="index")
         return "index_cfd";
      if(asset_class=="fx")
        {
         string base=(StringLen(canonical_root)>=3 ? StringSubstr(canonical_root,0,3) : "");
         string quote=(StringLen(canonical_root)>=6 ? StringSubstr(canonical_root,3,3) : "");
         bool base_major=(base=="eur" || base=="gbp" || base=="aud" || base=="nzd" || base=="usd" || base=="cad" || base=="chf" || base=="jpy");
         bool quote_major=(quote=="eur" || quote=="gbp" || quote=="aud" || quote=="nzd" || quote=="usd" || quote=="cad" || quote=="chf" || quote=="jpy");
         if(base_major && quote_major)
            return "fx_spot";
         return "fx_other";
        }
      return "other";
     }

   static string DetectThemeBucket(const string asset_class,const string canonical_root,const string symbol_lc)
     {
      if(asset_class=="metal")
         return "metals";
      if(asset_class=="crypto")
         return "crypto_major";
      if(asset_class=="index")
         return "indices";
      if(asset_class=="fx")
        {
         string base=(StringLen(canonical_root)>=3 ? StringSubstr(canonical_root,0,3) : "");
         string quote=(StringLen(canonical_root)>=6 ? StringSubstr(canonical_root,3,3) : "");
         bool base_major=(base=="eur" || base=="gbp" || base=="aud" || base=="nzd" || base=="usd" || base=="cad" || base=="chf" || base=="jpy");
         bool quote_major=(quote=="eur" || quote=="gbp" || quote=="aud" || quote=="nzd" || quote=="usd" || quote=="cad" || quote=="chf" || quote=="jpy");
         if(base_major && quote_major)
           {
            if(base=="usd" || quote=="usd")
               return "fx_major";
            if((base=="eur" && quote=="gbp") || (base=="eur" && quote=="jpy") || (base=="gbp" && quote=="jpy"))
               return "fx_major";
           }
         return "fx_cross";
        }
      return "other";
     }

   static ISSX_TradeabilityClass TradeabilityFromSpreadPts(const double spread_pts,const bool market_ready,const long trade_mode)
     {
      if(!market_ready || trade_mode==SYMBOL_TRADE_MODE_DISABLED)
         return issx_tradeability_blocked;
      if(spread_pts<=0.0)
         return issx_tradeability_moderate;
      if(spread_pts<=5.0)
         return issx_tradeability_very_cheap;
      if(spread_pts<=15.0)
         return issx_tradeability_cheap;
      if(spread_pts<=40.0)
         return issx_tradeability_moderate;
      return issx_tradeability_expensive;
     }

   static double Clamp01(const double v)
     {
      if(v<0.0) return 0.0;
      if(v>1.0) return 1.0;
      return v;
     }

   static string CurrentServerTimeText()
     {
      datetime t=TimeTradeServer();
      if(t<=0)
         t=TimeLocal();
      return TimeToString(t,TIME_SECONDS);
     }
     
   static int NowSecondsOfDay()
     {
      datetime t=TimeTradeServer();
      if(t<=0)
         t=TimeLocal();
      MqlDateTime dt;
      TimeToStruct(t,dt);
      return dt.hour*3600 + dt.min*60 + dt.sec;
     }

   static ENUM_DAY_OF_WEEK CurrentDow()
     {
      datetime t=TimeTradeServer();
      if(t<=0)
         t=TimeLocal();
      MqlDateTime dt;
      TimeToStruct(t,dt);
      return (ENUM_DAY_OF_WEEK)dt.day_of_week;
     }

   static int SessionSeconds(datetime t)
     {
      MqlDateTime dt;
      TimeToStruct(t,dt);
      return dt.hour*3600 + dt.min*60 + dt.sec;
     }

   static bool GetInteger(const string symbol,const ENUM_SYMBOL_INFO_INTEGER prop,long &out_v)
     {
      out_v=0;
      return SymbolInfoInteger(symbol,prop,out_v);
     }

   static bool GetDouble(const string symbol,const ENUM_SYMBOL_INFO_DOUBLE prop,double &out_v)
     {
      out_v=0.0;
      return SymbolInfoDouble(symbol,prop,out_v);
     }

   static bool GetString(const string symbol,const ENUM_SYMBOL_INFO_STRING prop,string &out_v)
     {
      out_v="";
      return SymbolInfoString(symbol,prop,out_v);
     }

   static int CountTradeSessionsToday(const string symbol,bool &available,int &minutes_since_open,int &minutes_to_close,bool &transition_penalty_active)
     {
      available=false;
      minutes_since_open=0;
      minutes_to_close=0;
      transition_penalty_active=false;

      ENUM_DAY_OF_WEEK dow=CurrentDow();
      int now_sec=NowSecondsOfDay();

      int count=0;
      bool in_window=false;
      int best_open=0;
      int best_close=0;

      for(uint idx=0; idx<10; idx++)
        {
         datetime from=0;
         datetime to=0;
         if(!SymbolInfoSessionTrade(symbol,dow,idx,from,to))
            break;

         available=true;
         count++;

         int fs=SessionSeconds(from);
         int ts=SessionSeconds(to);
         if(ts<=fs)
            ts+=24*3600;

         int check_now=now_sec;
         if(check_now<fs)
            check_now+=24*3600;

         if(check_now>=fs && check_now<=ts)
           {
            in_window=true;
            best_open=fs;
            best_close=ts;
           }
        }

      if(in_window)
        {
         int check_now=now_sec;
         if(check_now<best_open)
            check_now+=24*3600;
         minutes_since_open=(check_now-best_open)/60;
         minutes_to_close=(best_close-check_now)/60;
         transition_penalty_active=(minutes_since_open<=10 || minutes_to_close<=10);
        }

      return count;
     }

   static int CountQuoteSessionsToday(const string symbol,bool &available)
     {
      available=false;
      ENUM_DAY_OF_WEEK dow=CurrentDow();
      int count=0;
      for(uint idx=0; idx<10; idx++)
        {
         datetime from=0;
         datetime to=0;
         if(!SymbolInfoSessionQuote(symbol,dow,idx,from,to))
            break;
         available=true;
         count++;
        }
      return count;
     }

   static void AddSample(string &csv,const string item,const int max_items=8)
     {
      if(ISSX_Util::IsEmpty(item))
         return;
      int count=1;
      for(int i=0;i<StringLen(csv);i++)
         if(StringGetCharacter(csv,i)==',')
            count++;
      if(ISSX_Util::IsEmpty(csv))
        {
         csv=item;
         return;
        }
      if(count>=max_items)
         return;
      csv+=","+item;
     }

   void ResetHud()
     {
      ISSX_HudRenderer::ResetSnapshot(m_hud);
      m_hud.engine_name=ISSX_ENGINE_NAME;
      m_hud.firm_id=m_firm_id;
      m_hud.stage_id=issx_stage_ea1;
      m_hud.server_time_text=CurrentServerTimeText();
      m_hud.hud_legend_text="Legend: B=broker E=eligible A=active R=rankable | O=open C=cautious Q=quote-only X=blocked";
     }

   void RenderHudNow()
     {
      Comment(ISSX_HudRenderer::Render(m_hud));
     }

   void UpdateHudFromCounters(const ISSX_ClockStats &clock_stats,
                           const ISSX_EA1_CycleCounters &counters,
                           const long minute_id,
                           const ISSX_PublishReason publish_reason,
                           const ISSX_RootSyncState root_sync_state)
  {
   ISSX_WarningEntry top;

   ResetHud();
m_hud.server_time_text = CurrentServerTimeText();
   m_hud.mono_ms=ISSX_Time::MonoMs();
   m_hud.uptime_ms=(m_started_ms>0 ? (m_hud.mono_ms-m_started_ms) : 0);
   m_hud.minute_id=minute_id;

   // lifecycle: final post-cycle HUD should show ready state
   m_hud.phase_text="ready";
   m_hud.scan_text="ready";
   m_hud.sync_text=(root_sync_state==issx_root_sync_unknown ? "pending" : "sync");
   m_hud.is_warmup=false;
   m_hud.is_ready=true;

   m_hud.broker_universe=counters.broker_universe;
   m_hud.eligible_universe=counters.eligible_universe;
   m_hud.active_universe=counters.active_universe;
   m_hud.frontier_universe=counters.rankable_universe;

   m_hud.open_usable=counters.pulse_open_usable;
   m_hud.open_cautious=counters.pulse_open_cautious;
   m_hud.quote_only=counters.pulse_quote_only;
   m_hud.blocked=counters.pulse_blocked;

   m_hud.publish_profile_or_answer_mode="ea1_market_core";
   m_hud.cohort_integrity=(m_warns.Count()>0 ? issx_cohort_degraded : issx_cohort_exact);
   m_hud.root_sync_state=root_sync_state;
   m_hud.sequence_no=m_sequence_no;
   m_hud.publish_reason=publish_reason;
   m_hud.last_publish_age_sec=0;

   if(m_warns.Top(top))
      m_hud.top_warning_code=top.code;
   else
      m_hud.top_warning_code="none";

   m_hud.warning_count=m_warns.Count();

   // fixed degraded bug here
   m_hud.degraded_flag=(counters.metadata_degraded_count>0 ||
                        counters.session_ambiguous_count>0 ||
                        m_warns.Count()>0);

   m_hud.stale_flag=(counters.missing_tick_count>0 && counters.active_universe<=0);
   m_hud.timer_gap_ms_now=clock_stats.timer_gap_ms_now;
   m_hud.timer_gap_ms_mean=clock_stats.timer_gap_ms_mean;
  }

   string BuildStageJson(const long minute_id,
                         const string content_hash,
                         const string writer_nonce,
                         const ISSX_EA1_CycleCounters &counters) const
     {
      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginObject();
      jw.NameString("producer",ISSX_ENGINE_NAME);
      jw.NameString("stage_id","ea1");
      jw.NameString("stage_name",ISSX_Enum::StagePublicName(issx_stage_ea1));
      jw.NameString("firm_id",m_firm_id);
      jw.NameString("schema_version",ISSX_SCHEMA_VERSION);
      jw.NameInt("schema_epoch",ISSX_SCHEMA_EPOCH);
      jw.NameInt("sequence_no",m_sequence_no);
      jw.NameInt("minute_id",minute_id);
      jw.NameString("content_hash",content_hash);
      jw.NameString("writer_boot_id",m_boot_id);
      jw.NameString("writer_nonce",writer_nonce);

      jw.BeginObjectNamed("universe");
      jw.NameInt("broker_universe",counters.broker_universe);
      jw.NameInt("eligible_universe",counters.eligible_universe);
      jw.NameInt("active_universe",counters.active_universe);
      jw.NameInt("rankable_universe",counters.rankable_universe);
      jw.NameInt("frontier_universe",0);
      jw.EndObject();

      jw.BeginArrayNamed("symbols");
      int n=ArraySize(m_state.identities);
      for(int i=0;i<n;i++)
        {
         jw.BeginObject();

         jw.NameString("symbol_raw",m_state.identities[i].symbol_raw);
         jw.NameString("symbol_norm",m_state.identities[i].symbol_norm);
         jw.NameString("canonical_root",m_state.identities[i].canonical_root);
         jw.NameString("path",m_specs[i].path);
         jw.NameString("description",m_specs[i].description);
         jw.NameString("prefix_token",m_state.identities[i].prefix_token);
         jw.NameString("suffix_token",m_state.identities[i].suffix_token);
         jw.NameString("contract_token",m_state.identities[i].contract_token);
         jw.NameString("alias_family_id",m_state.identities[i].alias_family_id);
         jw.NameString("underlying_family_id",m_state.identities[i].underlying_family_id);
         jw.NameString("market_representation_id",m_state.identities[i].market_representation_id);
         jw.NameString("execution_substitute_group_id",m_state.identities[i].execution_substitute_group_id);
         jw.NameString("representation_state",ISSX_Enum::RepresentationStateToString(m_state.identities[i].representation_state));
         jw.NameDouble("representation_confidence",m_state.identities[i].representation_confidence,2);
         jw.NameString("representation_reason_codes",m_state.identities[i].representation_reason_codes);
         jw.NameBool("preferred_variant_flag",m_state.identities[i].preferred_variant_flag);
         jw.NameBool("preferred_variant_locked",m_state.identities[i].preferred_variant_locked);
         jw.NameDouble("representation_stability_score",m_state.identities[i].representation_stability_score,2);

         jw.NameInt("trade_mode",m_specs[i].trade_mode);
         jw.NameInt("calc_mode",m_specs[i].calc_mode);
         jw.NameInt("digits",m_specs[i].digits);
         jw.NameDouble("point",m_specs[i].point,8);
         jw.NameDouble("tick_size",m_specs[i].tick_size,8);
         jw.NameDouble("tick_value",m_specs[i].tick_value,6);
         jw.NameDouble("tick_value_profit",m_specs[i].tick_value_profit,6);
         jw.NameDouble("tick_value_loss",m_specs[i].tick_value_loss,6);
         jw.NameDouble("contract_size",m_specs[i].contract_size,4);
         jw.NameDouble("volume_min",m_specs[i].volume_min,4);
         jw.NameDouble("volume_step",m_specs[i].volume_step,4);
         jw.NameDouble("volume_max",m_specs[i].volume_max,4);
         jw.NameInt("stops_level",m_specs[i].stops_level);
         jw.NameInt("freeze_level",m_specs[i].freeze_level);
         jw.NameString("margin_currency",m_specs[i].margin_currency);
         jw.NameString("profit_currency",m_specs[i].profit_currency);
         jw.NameString("base_currency",m_specs[i].base_currency);
         jw.NameString("quote_currency",m_specs[i].quote_currency);
         jw.NameDouble("swap_long",m_specs[i].swap_long,4);
         jw.NameDouble("swap_short",m_specs[i].swap_short,4);
         jw.NameInt("swap_mode",m_specs[i].swap_mode);
         jw.NameBool("selected",m_specs[i].selected);
         jw.NameBool("custom_symbol",m_specs[i].custom_symbol);
         jw.NameBool("session_trade_available",m_specs[i].session_trade_available);
         jw.NameBool("session_quote_available",m_specs[i].session_quote_available);
         jw.NameInt("session_window_count",m_specs[i].session_window_count);
         jw.NameInt("quote_session_window_count",m_specs[i].session_quote_window_count);
         jw.NameBool("tick_ok",m_specs[i].tick_ok);
         jw.NameInt("tick_time_msc",m_specs[i].tick_time_msc);
         jw.NameInt("property_fail_count",m_specs[i].property_fail_count);

         jw.NameString("asset_class",m_state.classifications[i].asset_class);
         jw.NameString("instrument_family",m_state.classifications[i].instrument_family);
         jw.NameString("theme_bucket",m_state.classifications[i].theme_bucket);
         jw.NameString("equity_sector",m_state.classifications[i].equity_sector);
         jw.NameString("leader_bucket_id",m_state.classifications[i].leader_bucket_id);
         jw.NameString("leader_bucket_type",ISSX_Enum::LeaderBucketTypeToString(m_state.classifications[i].leader_bucket_type));
         jw.NameString("classification_source",m_state.classifications[i].classification_source);
         jw.NameDouble("classification_confidence",m_state.classifications[i].classification_confidence,2);
         jw.NameDouble("classification_reliability_score",m_state.classifications[i].classification_reliability_score,2);
         jw.NameString("taxonomy_conflict_scope",m_state.classifications[i].taxonomy_conflict_scope);
         jw.NameString("taxonomy_action_taken",ISSX_Enum::TaxonomyActionTakenToString(m_state.classifications[i].taxonomy_action_taken));
         jw.NameBool("native_sector_present",m_state.classifications[i].native_sector_present);
         jw.NameBool("native_industry_present",m_state.classifications[i].native_industry_present);
         jw.NameDouble("native_taxonomy_quality",m_state.classifications[i].native_taxonomy_quality,2);
         jw.NameBool("native_vs_manual_conflict",m_state.classifications[i].native_vs_manual_conflict);
         jw.NameDouble("taxonomy_reliability_score",m_state.classifications[i].taxonomy_reliability_score,2);
         jw.NameBool("classification_needs_review",m_state.classifications[i].classification_needs_review);

         jw.NameDouble("property_truth_score",m_state.markets[i].property_truth_score,2);
         jw.NameString("readability_state",ISSX_Enum::ReadabilityStateToString(m_state.markets[i].readability_state));
         jw.NameString("unknown_reason",ISSX_Enum::UnknownReasonToString(m_state.markets[i].unknown_reason));
         jw.NameInt("property_read_fail_mask",m_state.markets[i].property_read_fail_mask);
         jw.NameBool("requires_marketwatch_selection",m_state.markets[i].requires_marketwatch_selection);
         jw.NameBool("requires_runtime_probe",m_state.markets[i].requires_runtime_probe);
         jw.NameBool("native_taxonomy_availability",m_state.markets[i].native_taxonomy_availability);
         jw.NameBool("session_counter_availability",m_state.markets[i].session_counter_availability);

         jw.NameString("session_reconciliation_state",m_state.sessions[i].session_reconciliation_state);
         jw.NameDouble("session_truth_confidence",m_state.sessions[i].session_truth_confidence,2);
         jw.NameInt("session_phase",m_state.sessions[i].session_phase);
         jw.NameInt("minutes_since_session_open",m_state.sessions[i].minutes_since_session_open);
         jw.NameInt("minutes_to_session_close",m_state.sessions[i].minutes_to_session_close);
         jw.NameBool("transition_penalty_active",m_state.sessions[i].transition_penalty_active);

         jw.NameString("practical_market_state",ISSX_Enum::PracticalMarketStateToString(m_state.markets[i].practical_market_state));
         jw.NameString("practical_market_state_reason_codes",m_state.markets[i].practical_market_state_reason_codes);
         jw.NameDouble("runtime_truth_score",m_state.markets[i].runtime_truth_score,2);
         jw.NameInt("observation_samples_short",m_state.markets[i].observation_samples_short);
         jw.NameInt("observation_samples_medium",m_state.markets[i].observation_samples_medium);
         jw.NameDouble("observation_density_score",m_state.markets[i].observation_density_score,2);
         jw.NameDouble("observation_gap_risk",m_state.markets[i].observation_gap_risk,2);
         jw.NameDouble("market_sampling_quality_score",m_state.markets[i].market_sampling_quality_score,2);
         jw.NameDouble("bid",m_state.markets[i].bid,8);
         jw.NameDouble("ask",m_state.markets[i].ask,8);
         jw.NameDouble("mid",m_state.markets[i].mid,8);
         jw.NameDouble("spread_now_points",m_state.markets[i].spread_now_points,1);
         jw.NameDouble("spread_median_short_points",m_state.markets[i].spread_median_short_points,1);
         jw.NameDouble("spread_p90_short_points",m_state.markets[i].spread_p90_short_points,1);
         jw.NameDouble("spread_widening_ratio",m_state.markets[i].spread_widening_ratio,2);
         jw.NameDouble("quote_interval_median_ms",m_state.markets[i].quote_interval_median_ms,1);
         jw.NameDouble("quote_interval_p90_ms",m_state.markets[i].quote_interval_p90_ms,1);
         jw.NameDouble("quote_stall_rate",m_state.markets[i].quote_stall_rate,2);
         jw.NameDouble("quote_burstiness_score",m_state.markets[i].quote_burstiness_score,2);
         jw.NameDouble("current_vs_normal_spread_percentile",m_state.markets[i].current_vs_normal_spread_percentile,1);
         jw.NameDouble("current_vs_normal_quote_rate_percentile",m_state.markets[i].current_vs_normal_quote_rate_percentile,1);

         jw.NameString("tradeability_class",ISSX_Enum::TradeabilityClassToString(m_state.costs[i].tradeability_class));
         jw.NameString("commission_state",ISSX_Enum::CommissionStateToString(m_state.costs[i].commission_state));
         jw.NameString("swap_state",ISSX_Enum::SwapStateToString(m_state.costs[i].swap_state));
         jw.NameDouble("structural_tradeability_score",m_state.costs[i].structural_tradeability_score,2);
         jw.NameDouble("live_tradeability_score",m_state.costs[i].live_tradeability_score,2);
         jw.NameDouble("blended_tradeability_score",m_state.costs[i].blended_tradeability_score,2);
         jw.NameDouble("entry_cost_score",m_state.costs[i].entry_cost_score,2);
         jw.NameDouble("holding_cost_visibility_score",m_state.costs[i].holding_cost_visibility_score,2);
         jw.NameDouble("size_practicality_score",m_state.costs[i].size_practicality_score,2);
         jw.NameDouble("economic_consistency_score",m_state.costs[i].economic_consistency_score,2);
         jw.NameDouble("microstructure_safety_score",m_state.costs[i].microstructure_safety_score,2);
         jw.NameDouble("min_lot_risk_fit_score",m_state.costs[i].min_lot_risk_fit_score,2);
         jw.NameDouble("step_lot_precision_score",m_state.costs[i].step_lot_precision_score,2);
         jw.NameDouble("small_account_usability_score",m_state.costs[i].small_account_usability_score,2);
         jw.NameDouble("all_in_cost_confidence",m_state.costs[i].all_in_cost_confidence,2);
         jw.NameString("structural_cost_reason_codes",m_state.costs[i].structural_cost_reason_codes);
         jw.NameString("live_cost_reason_codes",m_state.costs[i].live_cost_reason_codes);
         jw.NameInt("cost_shock_count_recent",m_state.costs[i].cost_shock_count_recent);
         jw.NameString("quote_burstiness_regime",m_state.costs[i].quote_burstiness_regime);
         jw.NameString("practical_execution_friction_class",m_state.costs[i].practical_execution_friction_class);
         jw.NameString("toxicity_flags",m_state.costs[i].toxicity_flags);
         jw.NameString("toxicity_primary",m_state.costs[i].toxicity_primary);
         jw.NameDouble("toxicity_score",m_state.costs[i].toxicity_score,2);
         jw.NameInt("toxicity_holdoff_minutes",m_state.costs[i].toxicity_holdoff_minutes);

         jw.NameBool("identity_ready",m_gates[i].identity_ready);
         jw.NameBool("sync_ready",m_gates[i].sync_ready);
         jw.NameBool("session_ready",m_gates[i].session_ready);
         jw.NameBool("market_ready",m_gates[i].market_ready);
         jw.NameBool("spec_ready",m_gates[i].spec_ready);
         jw.NameBool("cost_ready",m_gates[i].cost_ready);
         jw.NameBool("rankability_gate_ready",m_gates[i].rankability_gate_ready);
         jw.NameBool("gate_passed",m_gates[i].gate_passed);
         jw.NameString("primary_block_reason",m_gates[i].primary_block_reason);
         jw.NameString("secondary_block_reason",m_gates[i].secondary_block_reason);
         jw.NameBool("recoverable_next_cycle",m_gates[i].recoverable_next_cycle);
         jw.NameDouble("gate_confidence",m_gates[i].gate_confidence,2);
         jw.NameInt("gate_pass_cycles",m_gates[i].gate_pass_cycles);
         jw.NameInt("gate_flap_count",m_gates[i].gate_flap_count);

         jw.EndObject();
        }
      jw.EndArray();

      jw.EndObject();
      return jw.ToString();
     }

   string BuildDebugJson(const long minute_id,
                         const ISSX_PublishReason publish_reason,
                         const ISSX_ClockStats &clock_stats,
                         const ISSX_EA1_CycleCounters &counters,
                         const ISSX_ValidationResult &state_validation) const
     {
      string quote_only_samples="";
      string blocked_samples="";
      string expensive_samples="";
      string rejected_samples="";

      int n=ArraySize(m_state.identities);
      for(int i=0;i<n;i++)
        {
         string sym=m_state.identities[i].symbol_raw;
         if(m_state.markets[i].practical_market_state==issx_market_quote_only)
            AddSample(quote_only_samples,sym);
         if(m_state.markets[i].practical_market_state==issx_market_blocked)
            AddSample(blocked_samples,sym);
         if(m_state.costs[i].tradeability_class==issx_tradeability_expensive)
            AddSample(expensive_samples,sym);
         if(!m_gates[i].gate_passed)
            AddSample(rejected_samples,sym+"("+m_gates[i].primary_block_reason+")");
        }

      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginObject();

      jw.NameString("stage_id","ea1");
      jw.NameString("stage_name",ISSX_Enum::StagePublicName(issx_stage_ea1));
      jw.NameString("firm_id",m_firm_id);
      jw.NameInt("sequence_no",m_sequence_no);
      jw.NameInt("minute_id",minute_id);
      jw.NameString("publish_reason",ISSX_Enum::PublishReasonToString(publish_reason));

      jw.BeginObjectNamed("firm_resolution");
      jw.NameString("resolved_firm_id",m_firm_id);
      jw.NameString("account_company",AccountInfoString(ACCOUNT_COMPANY));
      jw.NameString("account_server",AccountInfoString(ACCOUNT_SERVER));
      jw.NameInt("account_login",(long)AccountInfoInteger(ACCOUNT_LOGIN));
      jw.EndObject();

      jw.BeginObjectNamed("paths");
      jw.NameString("stage_root_path",ISSX_Paths::StageRootPath(m_firm_id,issx_stage_ea1));
      jw.NameString("debug_root_path",ISSX_Paths::DebugRootPath(m_firm_id,issx_stage_ea1));
      jw.NameString("payload_current_path",ISSX_Paths::PayloadCurrentPath(m_firm_id,issx_stage_ea1));
      jw.NameString("manifest_current_path",ISSX_Paths::ManifestCurrentPath(m_firm_id,issx_stage_ea1));
      jw.EndObject();

      jw.BeginObjectNamed("registries");
      jw.NameInt("field_count",m_field_reg.Count());
      jw.NameInt("enum_count",m_enum_reg.Count());
      jw.NameInt("comparator_count",m_cmp_reg.Count());
      jw.NameString("field_hash",m_field_reg.FingerprintHex());
      jw.NameString("enum_hash",m_enum_reg.FingerprintHex());
      jw.NameString("comparator_hash",m_cmp_reg.FingerprintHex());
      jw.EndObject();

      jw.BeginObjectNamed("validation");
      jw.NameBool("state_ok",state_validation.ok);
      jw.NameInt("state_code",state_validation.code);
      jw.NameString("state_message",state_validation.message);
      jw.EndObject();

      jw.BeginObjectNamed("universe");
      jw.NameInt("broker_universe",counters.broker_universe);
      jw.NameInt("eligible_universe",counters.eligible_universe);
      jw.NameInt("active_universe",counters.active_universe);
      jw.NameInt("rankable_universe",counters.rankable_universe);
      jw.NameInt("custom_symbol_count",counters.custom_symbol_count);
      jw.NameInt("selected_symbol_count",counters.selected_symbol_count);
      jw.EndObject();

      jw.BeginObjectNamed("market_pulse");
      jw.NameInt("open_usable",counters.pulse_open_usable);
      jw.NameInt("open_cautious",counters.pulse_open_cautious);
      jw.NameInt("quote_only",counters.pulse_quote_only);
      jw.NameInt("blocked",counters.pulse_blocked);
      jw.NameInt("missing_tick_count",counters.missing_tick_count);
      jw.NameInt("session_ambiguous_count",counters.session_ambiguous_count);
      jw.NameInt("metadata_degraded_count",counters.metadata_degraded_count);
      jw.EndObject();

      jw.BeginObjectNamed("classification_counts");
      jw.NameInt("fx",counters.fx_count);
      jw.NameInt("metal",counters.metal_count);
      jw.NameInt("crypto",counters.crypto_count);
      jw.NameInt("index",counters.index_count);
      jw.NameInt("other",counters.other_count);
      jw.NameInt("bucket_fx_major",counters.bucket_fx_major_count);
      jw.NameInt("bucket_fx_cross",counters.bucket_fx_cross_count);
      jw.NameInt("bucket_metals",counters.bucket_metals_count);
      jw.NameInt("bucket_crypto",counters.bucket_crypto_count);
      jw.NameInt("bucket_indices",counters.bucket_indices_count);
      jw.NameInt("bucket_other",counters.bucket_other_count);
      jw.EndObject();

      jw.BeginObjectNamed("tradeability_counts");
      jw.NameInt("very_cheap",counters.very_cheap_count);
      jw.NameInt("cheap",counters.cheap_count);
      jw.NameInt("moderate",counters.moderate_count);
      jw.NameInt("expensive",counters.expensive_count);
      jw.NameInt("blocked",counters.blocked_tradeability_count);
      jw.EndObject();

      jw.BeginObjectNamed("gate_counts");
      jw.NameInt("gate_pass_count",counters.gate_pass_count);
      jw.NameInt("rejected_count",counters.rejected_count);
      jw.EndObject();

      jw.BeginObjectNamed("timing");
      jw.NameInt("timer_gap_ms_now",clock_stats.timer_gap_ms_now);
      jw.NameDouble("timer_gap_ms_mean",clock_stats.timer_gap_ms_mean,1);
      jw.NameInt("timer_gap_ms_p95",clock_stats.timer_gap_ms_p95);
      jw.NameDouble("clock_sanity_score",clock_stats.clock_sanity_score,2);
      jw.EndObject();

      jw.BeginObjectNamed("samples");
      jw.NameString("quote_only_symbols",quote_only_samples);
      jw.NameString("blocked_symbols",blocked_samples);
      jw.NameString("expensive_symbols",expensive_samples);
      jw.NameString("rejected_symbols",rejected_samples);
      jw.EndObject();

      jw.BeginObjectNamed("warnings");
      ISSX_WarningEntry top;
      if(m_warns.Top(top))
        {
         jw.NameString("top_warning_code",top.code);
         jw.NameString("top_warning_severity",ISSX_Enum::HudWarningSeverityToString(top.severity));
         jw.NameString("top_warning_message",top.message);
        }
      else
        {
         jw.NameString("top_warning_code","none");
         jw.NameString("top_warning_severity","info");
         jw.NameString("top_warning_message","");
        }
      jw.NameInt("warning_count",m_warns.Count());
      jw.EndObject();

      jw.EndObject();
      return jw.ToString();
     }

   bool PopulateEA1State(const int max_symbols,ISSX_EA1_CycleCounters &counters)
     {
      counters.Reset();
      m_state.Reset();
      ArrayResize(m_specs,0);
      ArrayResize(m_gates,0);
      m_warns.Reset();

      int total=SymbolsTotal(false);
      if(total<0)
         total=0;
      counters.broker_universe=total;

      int limit=total;
      if(max_symbols>0 && max_symbols<limit)
         limit=max_symbols;

      for(int i=0;i<limit;i++)
        {
         string symbol=SymbolName(i,false);
         if(ISSX_Util::IsEmpty(symbol))
            continue;

         long custom_v=0;
         GetInteger(symbol,SYMBOL_CUSTOM,custom_v);
         bool custom_symbol=(custom_v!=0);
         if(custom_symbol && !InpIncludeCustomSymbols)
            continue;

         int idx=ArraySize(m_state.identities);
         ArrayResize(m_state.identities,idx+1);
         ArrayResize(m_state.families,idx+1);
         ArrayResize(m_state.classifications,idx+1);
         ArrayResize(m_state.sessions,idx+1);
         ArrayResize(m_state.markets,idx+1);
         ArrayResize(m_state.costs,idx+1);
         ArrayResize(m_specs,idx+1);
         ArrayResize(m_gates,idx+1);

         m_state.identities[idx].Reset();
         m_state.families[idx].Reset();
         m_state.classifications[idx].Reset();
         m_state.sessions[idx].Reset();
         m_state.markets[idx].Reset();
         m_state.costs[idx].Reset();
         m_specs[idx].Reset();
         m_gates[idx].Reset();

         string symbol_lc=LowerNoSpaces(symbol);
         string canonical_root=ExtractCanonicalRoot(symbol);
         string path="";
         string description="";
         string margin_ccy="";
         string profit_ccy="";
         string base_ccy="";

         long selected_v=0, visible_v=0, trade_mode=0, calc_mode=0, digits=0, stops_level=0, freeze_level=0, swap_mode=0;
         double point=0.0, tick_size=0.0, tick_value=0.0, tick_value_profit=0.0, tick_value_loss=0.0;
         double contract_size=0.0, volume_min=0.0, volume_step=0.0, volume_max=0.0, swap_long=0.0, swap_short=0.0;

         int fail_count=0;
         if(!GetString(symbol,SYMBOL_PATH,path)) fail_count++;
         if(!GetString(symbol,SYMBOL_DESCRIPTION,description)) fail_count++;
         if(!GetString(symbol,SYMBOL_CURRENCY_MARGIN,margin_ccy)) fail_count++;
         if(!GetString(symbol,SYMBOL_CURRENCY_PROFIT,profit_ccy)) fail_count++;
         if(!GetString(symbol,SYMBOL_CURRENCY_BASE,base_ccy)) fail_count++;

         if(!GetInteger(symbol,SYMBOL_SELECT,selected_v)) fail_count++;
         GetInteger(symbol,SYMBOL_VISIBLE,visible_v);
         if(!GetInteger(symbol,SYMBOL_TRADE_MODE,trade_mode)) fail_count++;
         if(!GetInteger(symbol,SYMBOL_TRADE_CALC_MODE,calc_mode)) fail_count++;
         if(!GetInteger(symbol,SYMBOL_DIGITS,digits)) fail_count++;
         if(!GetInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL,stops_level)) fail_count++;
         if(!GetInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL,freeze_level)) fail_count++;
         GetInteger(symbol,SYMBOL_SWAP_MODE,swap_mode);

         if(!GetDouble(symbol,SYMBOL_POINT,point)) fail_count++;
         if(!GetDouble(symbol,SYMBOL_TRADE_TICK_SIZE,tick_size)) fail_count++;
         if(!GetDouble(symbol,SYMBOL_TRADE_TICK_VALUE,tick_value)) fail_count++;
         GetDouble(symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT,tick_value_profit);
         GetDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS,tick_value_loss);
         if(!GetDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE,contract_size)) fail_count++;
         if(!GetDouble(symbol,SYMBOL_VOLUME_MIN,volume_min)) fail_count++;
         if(!GetDouble(symbol,SYMBOL_VOLUME_STEP,volume_step)) fail_count++;
         if(!GetDouble(symbol,SYMBOL_VOLUME_MAX,volume_max)) fail_count++;
         GetDouble(symbol,SYMBOL_SWAP_LONG,swap_long);
         GetDouble(symbol,SYMBOL_SWAP_SHORT,swap_short);

         bool selected=(selected_v!=0);
         bool visible=(visible_v!=0);
         if(selected)
            counters.selected_symbol_count++;
         if(custom_symbol)
            counters.custom_symbol_count++;

         MqlTick tick;
         bool tick_ok=SymbolInfoTick(symbol,tick);
         long tick_age_sec=-1;
         if(tick_ok && tick.time_msc>0)
           {
            long now_msc=(long)TimeCurrent()*1000;
            tick_age_sec=(now_msc - (long)tick.time_msc)/1000;
            if(tick_age_sec<0)
               tick_age_sec=0;
           }
         bool valid_quote=HasEconomicallyValidQuote(tick_ok,tick.bid,tick.ask,point);

         bool trade_session_available=false;
         bool quote_session_available=false;
         int minutes_since_open=0;
         int minutes_to_close=0;
         bool transition_penalty=false;
         int trade_windows=CountTradeSessionsToday(symbol,trade_session_available,minutes_since_open,minutes_to_close,transition_penalty);
         int quote_windows=CountQuoteSessionsToday(symbol,quote_session_available);

         string path_lc=LowerTrim(path);
         string desc_lc=LowerTrim(description);
         ISSX_SectorDecision sector_decision=ISSX_SectorEngine::Classify(symbol,path,description);
         string asset_class=sector_decision.asset_class;
         string instrument_family=sector_decision.instrument_family;
         string theme_bucket=sector_decision.theme_bucket;

         string prefix_token=LettersOnlyPrefix(symbol);
         string suffix_token=LettersOnlySuffix(symbol);
         string contract_token="";
         if(StringFind(symbol,".")>=0 || StringFind(symbol,"#")>=0 || StringFind(symbol,"-")>=0 || StringFind(symbol,"_")>=0)
            contract_token=symbol;

         m_specs[idx].symbol_raw=symbol;
         m_specs[idx].path=path;
         m_specs[idx].description=description;
         m_specs[idx].trade_mode=trade_mode;
         m_specs[idx].calc_mode=calc_mode;
         m_specs[idx].digits=digits;
         m_specs[idx].point=point;
         m_specs[idx].tick_size=tick_size;
         m_specs[idx].tick_value=tick_value;
         m_specs[idx].tick_value_profit=tick_value_profit;
         m_specs[idx].tick_value_loss=tick_value_loss;
         m_specs[idx].contract_size=contract_size;
         m_specs[idx].volume_min=volume_min;
         m_specs[idx].volume_step=volume_step;
         m_specs[idx].volume_max=volume_max;
         m_specs[idx].stops_level=stops_level;
         m_specs[idx].freeze_level=freeze_level;
         m_specs[idx].margin_currency=margin_ccy;
         m_specs[idx].profit_currency=profit_ccy;
         m_specs[idx].base_currency=base_ccy;
         m_specs[idx].quote_currency=SafeQuoteCurrencyForAsset(asset_class,canonical_root,profit_ccy);
         m_specs[idx].swap_long=swap_long;
         m_specs[idx].swap_short=swap_short;
         m_specs[idx].swap_mode=swap_mode;
         m_specs[idx].session_trade_available=trade_session_available;
         m_specs[idx].session_quote_available=quote_session_available;
         m_specs[idx].session_window_count=trade_windows;
         m_specs[idx].session_quote_window_count=quote_windows;
         m_specs[idx].selected=selected;
         m_specs[idx].custom_symbol=custom_symbol;
         m_specs[idx].visible=visible;
         m_specs[idx].tick_ok=tick_ok;
         m_specs[idx].tick_time_msc=(tick_ok ? (long)tick.time_msc : 0);
         m_specs[idx].tick_bid=(tick_ok ? tick.bid : 0.0);
         m_specs[idx].tick_ask=(tick_ok ? tick.ask : 0.0);
         m_specs[idx].tick_last=(tick_ok ? tick.last : 0.0);
         m_specs[idx].property_fail_count=fail_count;
         m_specs[idx].metadata_ready=(fail_count<=3 && point>0.0 && volume_min>=0.0);

         m_state.identities[idx].symbol_raw=symbol;
         m_state.identities[idx].symbol_norm=symbol_lc;
         m_state.identities[idx].canonical_root=canonical_root;
         m_state.identities[idx].path=path;
         m_state.identities[idx].description=description;
         m_state.identities[idx].prefix_token=prefix_token;
         m_state.identities[idx].suffix_token=suffix_token;
         m_state.identities[idx].contract_token=contract_token;
         m_state.identities[idx].alias_family_id=canonical_root;
         m_state.identities[idx].underlying_family_id=canonical_root;
         m_state.identities[idx].market_representation_id=symbol_lc;
         m_state.identities[idx].execution_substitute_group_id=canonical_root;
         m_state.identities[idx].representation_state=(suffix_token=="" && prefix_token==LettersOnlyPrefix(canonical_root) ? issx_representation_canonical : issx_representation_variant);
         m_state.identities[idx].representation_confidence=(StringLen(canonical_root)>=6 ? 0.90 : 0.60);
         m_state.identities[idx].representation_reason_codes=(suffix_token=="" ? "clean_root" : "suffix_variant");
         m_state.identities[idx].preferred_variant_flag=(suffix_token=="");
         m_state.identities[idx].preferred_variant_locked=true;
         m_state.identities[idx].preferred_variant_lock_age_cycles=1;
         m_state.identities[idx].representative_switch_reason="stable_on_current_cycle";
         m_state.identities[idx].representative_switch_cost=0.0;
         m_state.identities[idx].variant_flip_risk_score=(suffix_token=="" ? 0.10 : 0.40);
         m_state.identities[idx].representation_stability_score=(suffix_token=="" ? 0.90 : 0.65);
         m_state.identities[idx].admission_state=(m_specs[idx].metadata_ready ? issx_symbol_admission_metadata_ready : issx_symbol_admission_listed);

         m_state.families[idx].alias_family_id=canonical_root;
         m_state.families[idx].representative_symbol=symbol;
         m_state.families[idx].duplicate_collapsed=false;
         m_state.families[idx].family_ready=(StringLen(canonical_root)>0);
         m_state.families[idx].family_confidence=(StringLen(canonical_root)>=6 ? 0.90 : 0.55);

         ISSX_SectorEngine::ApplyToState(symbol,path,description,m_state.classifications[idx]);

         bool session_ready=false;
         string session_state="session_unknown";
         int session_phase=0;

         if(trade_mode==SYMBOL_TRADE_MODE_DISABLED)
           {
            session_state="session_window_closed";
            session_ready=false;
            session_phase=0;
           }
         else if(trade_session_available && trade_windows>0)
           {
            if(minutes_to_close>0 || minutes_since_open>0)
              {
               session_state="session_window_open";
               session_ready=true;
               session_phase=1;
              }
            else
              {
               session_state="session_window_ambiguous";
               session_ready=true;
               session_phase=1;
               counters.session_ambiguous_count++;
              }
           }
         else if(valid_quote)
           {
            session_state="quote_observed_no_session_table";
            session_ready=true;
            session_phase=1;
            counters.session_ambiguous_count++;
           }
         else
           {
            session_state="session_window_unknown";
            session_ready=false;
            counters.session_ambiguous_count++;
           }

         m_state.sessions[idx].session_reconciliation_state=session_state;
         m_state.sessions[idx].session_truth_confidence=(trade_session_available ? 0.80 : (tick_ok ? 0.55 : 0.30));
         m_state.sessions[idx].session_phase=session_phase;
         m_state.sessions[idx].minutes_since_session_open=minutes_since_open;
         m_state.sessions[idx].minutes_to_session_close=minutes_to_close;
         m_state.sessions[idx].transition_penalty_active=transition_penalty;
         m_state.sessions[idx].session_ready=session_ready;

         m_state.markets[idx].native_taxonomy_availability=(m_state.classifications[idx].native_sector_present || m_state.classifications[idx].native_industry_present);
         m_state.markets[idx].session_counter_availability=(trade_session_available || quote_session_available);

         double spread_pts=0.0;
         if(valid_quote)
            spread_pts=(tick.ask-tick.bid)/point;

         m_state.markets[idx].property_truth_score=(fail_count<=1 ? 0.95 : (fail_count<=3 ? 0.75 : (fail_count<=6 ? 0.50 : 0.20)));
         m_state.markets[idx].readability_state=(fail_count<=1 ? issx_readability_readable_full : (fail_count<=6 ? issx_readability_readable_partial : issx_readability_unreadable));
         m_state.markets[idx].unknown_reason=(!selected ? issx_unknown_not_selected : (!tick_ok ? issx_unknown_not_synced : issx_unknown_true_unknown));
         m_state.markets[idx].property_read_fail_mask=fail_count;
         m_state.markets[idx].requires_marketwatch_selection=(!selected && !visible);
         m_state.markets[idx].requires_runtime_probe=(!tick_ok);
         m_state.markets[idx].native_taxonomy_availability=(m_state.classifications[idx].native_sector_present || m_state.classifications[idx].native_industry_present);
         m_state.markets[idx].session_counter_availability=(trade_session_available || quote_session_available);
         m_state.markets[idx].observation_samples_short=(valid_quote ? 1 : 0);
         m_state.markets[idx].observation_samples_medium=(tick_ok ? 1 : 0);
         m_state.markets[idx].observation_gap_risk=(tick_ok ? Clamp01((double)MathMax(0,(int)tick_age_sec)/30.0) : 1.0);
         m_state.markets[idx].market_sampling_quality_score=(valid_quote ? 0.75 : (tick_ok ? 0.35 : 0.10));

         if(trade_mode==SYMBOL_TRADE_MODE_DISABLED)
           {
            m_state.markets[idx].practical_market_state=issx_market_blocked;
            m_state.markets[idx].practical_market_state_reason_codes="trade_mode_disabled";
            m_state.markets[idx].runtime_truth_score=0.10;
            m_state.markets[idx].observation_density_score=0.05;
            m_state.markets[idx].market_ready=false;
            counters.pulse_blocked++;
           }
         else if(valid_quote && tick_age_sec<=15)
           {
            m_state.markets[idx].practical_market_state=(spread_pts>40.0 ? issx_market_open_cautious : issx_market_open_usable);
            m_state.markets[idx].practical_market_state_reason_codes=(spread_pts>40.0 ? "tick_present_spread_wide" : "tick_present");
            m_state.markets[idx].runtime_truth_score=(spread_pts>40.0 ? 0.70 : 0.85);
            m_state.markets[idx].observation_density_score=(tick_age_sec<=2 ? 0.90 : 0.75);
            m_state.markets[idx].bid=tick.bid;
            m_state.markets[idx].ask=tick.ask;
            m_state.markets[idx].mid=(tick.bid+tick.ask)/2.0;
            m_state.markets[idx].spread_now_points=spread_pts;
            m_state.markets[idx].spread_median_short_points=spread_pts;
            m_state.markets[idx].spread_p90_short_points=spread_pts;
            m_state.markets[idx].spread_widening_ratio=1.0;
            m_state.markets[idx].quote_interval_median_ms=(tick_age_sec<=1 ? 1000.0 : (double)tick_age_sec*1000.0);
            m_state.markets[idx].quote_interval_p90_ms=(tick_age_sec<=1 ? 1000.0 : (double)tick_age_sec*1500.0);
            m_state.markets[idx].quote_stall_rate=(tick_age_sec>5 ? 0.50 : 0.05);
            m_state.markets[idx].market_ready=true;

            if(m_state.markets[idx].practical_market_state==issx_market_open_cautious)
               counters.pulse_open_cautious++;
            else
               counters.pulse_open_usable++;

            counters.active_universe++;
           }
         else if(valid_quote)
           {
            m_state.markets[idx].practical_market_state=issx_market_quote_only;
            m_state.markets[idx].practical_market_state_reason_codes="stale_tick";
            m_state.markets[idx].runtime_truth_score=0.45;
            m_state.markets[idx].observation_density_score=0.25;
            m_state.markets[idx].bid=tick.bid;
            m_state.markets[idx].ask=tick.ask;
            m_state.markets[idx].mid=(tick.bid+tick.ask)/2.0;
            m_state.markets[idx].spread_now_points=spread_pts;
            m_state.markets[idx].spread_median_short_points=spread_pts;
            m_state.markets[idx].spread_p90_short_points=spread_pts;
            m_state.markets[idx].spread_widening_ratio=1.0;
            m_state.markets[idx].quote_interval_median_ms=(double)MathMax(1000,(int)tick_age_sec*1000);
            m_state.markets[idx].quote_interval_p90_ms=(double)MathMax(1500,(int)tick_age_sec*1200);
            m_state.markets[idx].quote_stall_rate=0.70;
            m_state.markets[idx].market_ready=false;
            counters.pulse_quote_only++;
           }
         else
           {
            m_state.markets[idx].practical_market_state=issx_market_quote_only;
            m_state.markets[idx].practical_market_state_reason_codes="no_tick";
            m_state.markets[idx].runtime_truth_score=0.25;
            m_state.markets[idx].observation_density_score=0.10;
            m_state.markets[idx].market_ready=false;
            counters.pulse_quote_only++;
            counters.missing_tick_count++;
           }

         m_state.markets[idx].quote_burstiness_score=(tick_ok ? Clamp01((double)MathMax(0,(int)15-(int)MathMin(15,tick_age_sec))/15.0) : 0.0);
         m_state.markets[idx].current_vs_normal_spread_percentile=(spread_pts<=0.0 ? 0.0 : MathMin(100.0,spread_pts));
         m_state.markets[idx].current_vs_normal_quote_rate_percentile=(tick_ok ? MathMax(0.0,100.0 - MathMin(100.0,(double)tick_age_sec*6.0)) : 0.0);

         m_state.costs[idx].tradeability_class=TradeabilityFromSpreadPts(spread_pts,m_state.markets[idx].market_ready,trade_mode);
         m_state.costs[idx].commission_state=issx_commission_unknown;
         if(MathAbs(swap_long)>0.0000001 || MathAbs(swap_short)>0.0000001)
            m_state.costs[idx].swap_state=issx_swap_known_nonzero;
         else
            m_state.costs[idx].swap_state=issx_swap_known_zero;

         double structural=0.0;
         if(point>0.0 && tick_size>0.0 && contract_size>0.0 && volume_step>0.0)
            structural=0.80;
         else if(point>0.0 && contract_size>0.0)
            structural=0.55;

         if(trade_mode==SYMBOL_TRADE_MODE_DISABLED)
            structural=0.0;

         double live=(m_state.markets[idx].market_ready ? (spread_pts<=15.0 ? 0.80 : (spread_pts<=40.0 ? 0.55 : 0.25)) : 0.15);
         double entry_cost=(spread_pts<=0.0 ? 0.30 : Clamp01(1.0-(MathMin(spread_pts,120.0)/120.0)));
         double size_score=(volume_min<=0.01 ? 0.85 : (volume_min<=0.10 ? 0.60 : 0.25));
         double step_score=(volume_step<=0.01 ? 0.85 : (volume_step<=0.10 ? 0.60 : 0.30));
         double econ_score=((tick_value>0.0 || tick_value_profit>0.0 || tick_value_loss>0.0) ? 0.75 : 0.35);
         double hold_cost=((m_state.costs[idx].swap_state==issx_swap_known_nonzero || m_state.costs[idx].swap_state==issx_swap_known_zero) ? 0.75 : 0.25);

         m_state.costs[idx].structural_tradeability_score=structural;
         m_state.costs[idx].live_tradeability_score=live;
         m_state.costs[idx].blended_tradeability_score=(structural+live)/2.0;
         m_state.costs[idx].entry_cost_score=entry_cost;
         m_state.costs[idx].holding_cost_visibility_score=hold_cost;
         m_state.costs[idx].size_practicality_score=size_score;
         m_state.costs[idx].economic_consistency_score=econ_score;
         m_state.costs[idx].microstructure_safety_score=(m_state.markets[idx].market_ready ? 0.70 : 0.25);
         m_state.costs[idx].min_lot_risk_fit_score=size_score;
         m_state.costs[idx].step_lot_precision_score=step_score;
         m_state.costs[idx].small_account_usability_score=(size_score+step_score)/2.0;
         m_state.costs[idx].all_in_cost_confidence=((hold_cost+econ_score)/2.0);
         m_state.costs[idx].structural_cost_reason_codes=(point>0.0 && contract_size>0.0 ? "spec_complete" : "spec_partial");
         m_state.costs[idx].live_cost_reason_codes=(m_state.markets[idx].market_ready ? (spread_pts>40.0 ? "spread_wide" : "live_quote_ok") : "market_not_ready");
         m_state.costs[idx].cost_shock_count_recent=(spread_pts>80.0 ? 1 : 0);
         m_state.costs[idx].quote_burstiness_regime=(m_state.markets[idx].quote_burstiness_score>0.70 ? "bursty" : "stable");
         m_state.costs[idx].practical_execution_friction_class=(m_state.costs[idx].tradeability_class==issx_tradeability_very_cheap ? "low" :
                                                                (m_state.costs[idx].tradeability_class==issx_tradeability_cheap ? "contained" :
                                                                (m_state.costs[idx].tradeability_class==issx_tradeability_moderate ? "moderate" : "high")));
         m_state.costs[idx].toxicity_flags=(spread_pts>80.0 ? "wide_spread" : "");
         m_state.costs[idx].toxicity_primary=(spread_pts>80.0 ? "wide_spread" : "");
         m_state.costs[idx].toxicity_score=(spread_pts>80.0 ? 0.85 : (spread_pts>40.0 ? 0.45 : 0.10));
         m_state.costs[idx].toxicity_holdoff_minutes=(spread_pts>80.0 ? 10 : (spread_pts>40.0 ? 3 : 0));
         m_state.costs[idx].cost_ready=(m_state.costs[idx].tradeability_class!=issx_tradeability_blocked);

         bool eligible=(m_specs[idx].metadata_ready && StringLen(canonical_root)>0);
         if(eligible)
            counters.eligible_universe++;
         else
            counters.metadata_degraded_count++;

         m_gates[idx].identity_ready=(StringLen(canonical_root)>0);
         m_gates[idx].sync_ready=(selected || visible || tick_ok);
         m_gates[idx].session_ready=m_state.sessions[idx].session_ready;
         m_gates[idx].market_ready=m_state.markets[idx].market_ready;
         m_gates[idx].spec_ready=m_specs[idx].metadata_ready;
         m_gates[idx].cost_ready=m_state.costs[idx].cost_ready;
         m_gates[idx].rankability_gate_ready=(m_gates[idx].identity_ready && m_gates[idx].spec_ready && m_gates[idx].session_ready && m_gates[idx].market_ready && m_gates[idx].cost_ready);
         m_gates[idx].gate_passed=(eligible && m_gates[idx].rankability_gate_ready);
         m_gates[idx].recoverable_next_cycle=(!tick_ok || !selected || !m_state.sessions[idx].session_ready);
         m_gates[idx].gate_confidence=Clamp01(
            (m_gates[idx].identity_ready ? 0.20 : 0.0) +
            (m_gates[idx].spec_ready ? 0.20 : 0.0) +
            (m_gates[idx].session_ready ? 0.20 : 0.0) +
            (m_gates[idx].market_ready ? 0.20 : 0.0) +
            (m_gates[idx].cost_ready ? 0.20 : 0.0)
         );
         m_gates[idx].gate_pass_cycles=(m_gates[idx].gate_passed ? 1 : 0);
         m_gates[idx].gate_flap_count=0;

         if(!m_gates[idx].identity_ready)
            m_gates[idx].primary_block_reason="identity_unresolved";
         else if(!m_gates[idx].spec_ready)
            m_gates[idx].primary_block_reason="metadata_incomplete";
         else if(!m_gates[idx].session_ready)
            m_gates[idx].primary_block_reason="session_not_ready";
         else if(!m_gates[idx].market_ready)
            m_gates[idx].primary_block_reason="market_not_ready";
         else if(!m_gates[idx].cost_ready)
            m_gates[idx].primary_block_reason="tradeability_blocked";
         else
            m_gates[idx].primary_block_reason="none";

         if(!m_gates[idx].sync_ready)
            m_gates[idx].secondary_block_reason="not_selected_or_visible";
         else if(custom_symbol)
            m_gates[idx].secondary_block_reason="custom_symbol";
         else if(fail_count>0)
            m_gates[idx].secondary_block_reason="property_read_partial";
         else
            m_gates[idx].secondary_block_reason="none";

         if(m_gates[idx].gate_passed)
           {
            counters.rankable_universe++;
            counters.gate_pass_count++;
            m_state.identities[idx].admission_state=issx_symbol_admission_rank_candidate;
           }
         else
           {
            counters.rejected_count++;
            if(m_gates[idx].primary_block_reason=="market_not_ready")
               m_warns.Add("market_not_ready",issx_hud_warn_notice,symbol+" market not ready");
            else if(m_gates[idx].primary_block_reason=="tradeability_blocked")
               m_warns.Add("blocked_tradeability",issx_hud_warn_warn,symbol+" tradeability blocked");
           }

         if(asset_class=="fx") counters.fx_count++;
         else if(asset_class=="metal") counters.metal_count++;
         else if(asset_class=="crypto") counters.crypto_count++;
         else if(asset_class=="index") counters.index_count++;
         else counters.other_count++;

         if(theme_bucket=="fx_major") counters.bucket_fx_major_count++;
         else if(theme_bucket=="fx_cross") counters.bucket_fx_cross_count++;
         else if(theme_bucket=="metals") counters.bucket_metals_count++;
         else if(theme_bucket=="crypto_major") counters.bucket_crypto_count++;
         else if(theme_bucket=="indices") counters.bucket_indices_count++;
         else counters.bucket_other_count++;

         switch(m_state.costs[idx].tradeability_class)
           {
            case issx_tradeability_very_cheap: counters.very_cheap_count++; break;
            case issx_tradeability_cheap:      counters.cheap_count++; break;
            case issx_tradeability_moderate:   counters.moderate_count++; break;
            case issx_tradeability_expensive:  counters.expensive_count++; break;
            case issx_tradeability_blocked:
            default:                           counters.blocked_tradeability_count++; break;
           }

         if(spread_pts>80.0)
            m_warns.Add("wide_spread",issx_hud_warn_warn,symbol+" spread "+DoubleToString(spread_pts,1)+" pts");
         if(!tick_ok && trade_mode!=SYMBOL_TRADE_MODE_DISABLED)
            m_warns.Add("missing_tick",issx_hud_warn_notice,symbol+" no tick observed");
         if(fail_count>5)
            m_warns.Add("metadata_degraded",issx_hud_warn_notice,symbol+" property reads partial");
        }

      return true;
     }

public:
   CISSXMarketStateCoreApp()
     {
      m_firm_id="";
      m_boot_id="";
      m_sequence_no=0;
      m_last_scan_ms = 0;
      m_started_ms=0;
      m_last_timer_ms=0;
      m_last_debug_publish_ms=0;
      m_last_report="";
      ISSX_HudRenderer::ResetSnapshot(m_hud);
      ArrayResize(m_specs,0);
      ArrayResize(m_gates,0);
     }

   int Init(const string requested_firm_id,const bool run_smoke)
  {
   m_firm_id=ISSX_Firm::ResolveFirmId(requested_firm_id);
   m_boot_id="ea1_boot_"+IntToStr(ISSX_Time::MonoMs());
   m_started_ms=ISSX_Time::MonoMs();
   m_last_timer_ms=0;
   m_last_debug_publish_ms=0;
   m_sequence_no=0;

   ResetHud();
   m_hud.mono_ms=ISSX_Time::MonoMs();
   m_hud.uptime_ms=0;
   m_hud.minute_id=0;

   m_hud.phase_text="warmup";
   m_hud.scan_text="loading";
   m_hud.sync_text="pending";
   m_hud.is_warmup=true;
   m_hud.is_ready=false;

   m_hud.publish_profile_or_answer_mode="ea1_market_core";
   m_hud.sequence_no=0;
   m_hud.last_publish_age_sec=-1;
   m_hud.top_warning_code="none";
   m_hud.warning_count=0;
   m_hud.timer_gap_ms_now=0;
   m_hud.timer_gap_ms_mean=0.0;

   if(InpRenderHudOnChart)
      RenderHudNow();

   if(!ISSX_Persistence::EnsureFirmTree(m_firm_id))
        {
         ISSX_Debug::Log(issx_stage_ea1,m_firm_id,"EnsureFirmTree failed");
         return INIT_FAILED;
        }

      ISSX_RegistrySeeds::SeedAll(m_field_reg,m_enum_reg,m_cmp_reg);
      ISSX_PipelineServices::InitEA1(m_state);

      ISSX_ValidationResult frv=m_field_reg.Validate();
      ISSX_ValidationResult erv=m_enum_reg.Validate();
      ISSX_ValidationResult crv=m_cmp_reg.Validate();

      if(!frv.ok || !erv.ok || !crv.ok)
        {
         ISSX_Debug::Log(issx_stage_ea1,m_firm_id,"registry validation failed");
         return INIT_FAILED;
        }

      if(run_smoke)
        {
         bool ok=ISSX_TestHarness::RunSmokeCore(m_firm_id,m_last_report);
         Print(m_last_report);
         if(!ok)
           {
            ISSX_Debug::Log(issx_stage_ea1,m_firm_id,"shared smoke failed");
            return INIT_FAILED;
           }
        }

      EventSetTimer(1);
      ISSX_Debug::Log(issx_stage_ea1,m_firm_id,"init ok");
      return INIT_SUCCEEDED;
     }

   void Deinit(const int reason)
     {
      EventKillTimer();
      ISSX_Debug::Log(issx_stage_ea1,m_firm_id,"deinit reason="+IntegerToString(reason));
     }

   void OnTimer(const bool write_debug_root,const bool render_hud,const int heartbeat_debug_seconds,const int max_symbols)
  {
   long now_ms=ISSX_Time::MonoMs();
   long gap_ms=(m_last_timer_ms>0 ? now_ms-m_last_timer_ms : 0);
   m_last_timer_ms=now_ms;

   ISSX_ClockStats clock_stats;
   ISSX_Time::ResetClockStats(clock_stats);
   ISSX_Time::RollingGapUpdate(clock_stats,gap_ms);

   // show immediate loading HUD before heavy scan/publish work
ResetHud();
m_hud.server_time_text = CurrentServerTimeText();
m_hud.mono_ms = now_ms;
   m_hud.minute_id=0;

   m_hud.phase_text="warmup";
   m_hud.scan_text="loading";
   m_hud.sync_text="pending";
   m_hud.is_warmup=true;
   m_hud.is_ready=false;

   m_hud.publish_profile_or_answer_mode="ea1_market_core";
   m_hud.sequence_no=m_sequence_no;
   m_hud.last_publish_age_sec=-1;
   m_hud.top_warning_code="none";
   m_hud.warning_count=0;
   m_hud.timer_gap_ms_now=clock_stats.timer_gap_ms_now;
   m_hud.timer_gap_ms_mean=clock_stats.timer_gap_ms_mean;

   if(render_hud)
      RenderHudNow();

ISSX_EA1_CycleCounters counters;
counters.Reset();
   if(now_ms - m_last_scan_ms > 10000)
{
   PopulateEA1State(max_symbols,counters);
   m_last_scan_ms = now_ms;
}

      ISSX_ValidationResult stv=ISSX_PipelineServices::ValidateEA1(m_state);

      ISSX_MinuteEpochSource min_src=issx_minute_epoch_unknown;
      long minute_id=ISSX_Time::MinuteIdNow(min_src);

      m_sequence_no++;

      ISSX_PublishReason publish_reason=(m_sequence_no==1 ? issx_publish_reason_bootstrap : issx_publish_reason_heartbeat);

      string writer_nonce="n"+IntToStr(m_sequence_no);
      string prehash="ea1|"+m_firm_id+"|"+IntToStr(m_sequence_no)+"|"+IntToStr(minute_id)+"|"+IntToStr(counters.broker_universe)+"|"+IntToStr(counters.eligible_universe)+"|"+IntToStr(counters.active_universe)+"|"+IntToStr(counters.rankable_universe);
      string content_hash=ISSX_Hash::HashStringHex(prehash);

      string root_stage_json=BuildStageJson(minute_id,content_hash,writer_nonce,counters);
      string root_debug_json=BuildDebugJson(minute_id,publish_reason,clock_stats,counters,stv);

      uchar payload_bytes[];
      StringToCharArray(root_stage_json,payload_bytes,0,WHOLE_ARRAY,CP_UTF8);
      int n=ArraySize(payload_bytes);
      if(n>0 && payload_bytes[n-1]==0)
         ArrayResize(payload_bytes,n-1);

      ISSX_Manifest manifest;
      ISSX_ManifestTools::Reset(manifest);
      manifest.stage_id=issx_stage_ea1;
      manifest.firm_id=m_firm_id;
      manifest.schema_version=ISSX_SCHEMA_VERSION;
      manifest.schema_epoch=ISSX_SCHEMA_EPOCH;
      manifest.sequence_no=m_sequence_no;
      manifest.minute_id=minute_id;
      manifest.writer_boot_id=m_boot_id;
      manifest.writer_nonce=writer_nonce;
      manifest.writer_generation=1;
      manifest.payload_hash=ISSX_Hash::HashBytesHex(payload_bytes);
      manifest.header_hash=ISSX_Hash::HashStringHex("ea1_header|"+m_firm_id+"|"+IntToStr(m_sequence_no)+"|"+IntToStr(minute_id));
      manifest.symbol_count=ArraySize(m_state.identities);
      manifest.changed_symbol_count=manifest.symbol_count;
      manifest.content_class=issx_content_snapshot;
      manifest.publish_reason=publish_reason;
      manifest.cohort_fingerprint=ISSX_Hash::HashStringHex("cohort|ea1|"+IntToStr(counters.rankable_universe));
      manifest.taxonomy_hash=ISSX_Hash::HashStringHex("taxonomy|ea1|heuristic");
      manifest.comparator_registry_hash=m_cmp_reg.FingerprintHex();
      manifest.legend_hash="";

      bool should_write_debug=write_debug_root;
      if(heartbeat_debug_seconds>0 && (now_ms-m_last_debug_publish_ms)<(long)heartbeat_debug_seconds*1000)
         should_write_debug=false;

      ISSX_PublishResult pr=ISSX_Persistence::PublishSnapshot(
         m_firm_id,
         issx_stage_ea1,
         manifest,
         payload_bytes,
         root_stage_json,
         (should_write_debug ? root_debug_json : "{}")
      );

      if(should_write_debug)
         m_last_debug_publish_ms=now_ms;

      if(!pr.ok)
        {
         ISSX_Debug::Log(issx_stage_ea1,m_firm_id,"publish failed: "+pr.message);
         m_warns.Add("publish_failed",issx_hud_warn_error,pr.message);
        }

      UpdateHudFromCounters(clock_stats,counters,minute_id,publish_reason,pr.root_sync_state);

      if(render_hud)
         RenderHudNow();
     }
  };

CISSXMarketStateCoreApp g_app;

int OnInit()
  {
   return g_app.Init(InpFirmId,InpRunSmokeOnInit);
  }

void OnDeinit(const int reason)
  {
   g_app.Deinit(reason);
  }

void OnTick()
  {
   // timer-driven EA; tick handler kept only as a harmless stub
  }

void OnTimer()
  {
   g_app.OnTimer(InpWriteDebugRoot,InpRenderHudOnChart,InpHeartbeatDebugSeconds,InpMaxSymbolsPerCycle);
  }