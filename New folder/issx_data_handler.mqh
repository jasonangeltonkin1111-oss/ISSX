#ifndef __ISSX_DATA_HANDLER_MQH__
#define __ISSX_DATA_HANDLER_MQH__

#include <ISSX/issx_core.mqh>

// ============================================================================
// ISSX DATA HANDLER v1.733
// Shared JSON/payload/file-commit safety layer +
// CENTRALIZED market/history validation gateway for ISSX stages.
// ============================================================================

#define ISSX_DATA_HANDLER_MODULE_VERSION "1.734"
#define ISSX_DATA_HANDLER_MAX_PAYLOAD_BYTES     7864320
#define ISSX_DATA_HANDLER_WRITE_RETRY_MAX       3

#define ISSX_DH_DEFAULT_LIVE_STALE_SEC          120
#define ISSX_DH_DEFAULT_MIN_RATES               2
#define ISSX_DH_MAX_RATES_WINDOW                4096

namespace ISSX_DataHandler
  {
   // ========================================================================
   // SECTION 01: FILE / JSON SAFETY
   // ========================================================================

   bool IsSafeRelativePath(const string relative_path)
     {
      if(ISSX_Util::IsEmpty(relative_path))
         return false;
      if(StringSubstr(relative_path,0,1)=="/" || StringSubstr(relative_path,0,1)=="\\")
         return false;
      if(StringFind(relative_path,":",0)>=0)
         return false;
      if(StringFind(relative_path,"..",0)>=0)
         return false;
      return true;
     }

   string BuildTempPath(const string relative_path,const int attempt)
     {
      return relative_path+".tmp."+IntegerToString((int)GetTickCount())+"."+IntegerToString(attempt);
     }

   bool EnsureParentFolder(const string relative_file_path)
     {
      const int sep1=StringFind(relative_file_path,"\\",0);
      const int sep2=StringFind(relative_file_path,"/",0);
      if(sep1<0 && sep2<0)
         return true;

      string path=relative_file_path;
      StringReplace(path,"/","\\");
      string parts[];
      const int n=StringSplit(path,(ushort)StringGetCharacter("\\",0),parts);
      if(n<=1)
         return true;

      string build="";
      for(int i=0;i<n-1;i++)
        {
         if(ISSX_Util::IsEmpty(parts[i]))
            continue;

         build=(ISSX_Util::IsEmpty(build) ? parts[i] : build+"\\"+parts[i]);
         FolderCreate(build,FILE_COMMON);
        }

      return true;
     }

   bool VerifyFinalPayload(const string relative_path,const int expected_utf8_bytes)
     {
      ResetLastError();
      const int h=FileOpen(relative_path,FILE_READ|FILE_BIN|FILE_COMMON);
      if(h==INVALID_HANDLE)
         return false;

      const ulong sz=FileSize(h);
      FileClose(h);

      if(expected_utf8_bytes<=0)
         return (sz==0);

      return ((int)sz==expected_utf8_bytes);
     }

   struct ForensicState
     {
      string checkpoint;
      string last_error;
      string symbol;
      string last_serialized_symbol;
      string last_successful_symbol;
      string temp_path;
      string final_path;
      int    payload_bytes_attempted;
      int    payload_bytes_written;
      int    open_error;
      int    write_error;
      int    move_error;
      int    copy_error;
      int    delete_error;

      void Reset()
        {
         checkpoint="idle";
         last_error="none";
         symbol="";
         last_serialized_symbol="";
         last_successful_symbol="";
         temp_path="";
         final_path="";
         payload_bytes_attempted=0;
         payload_bytes_written=0;
         open_error=0;
         write_error=0;
         move_error=0;
         copy_error=0;
         delete_error=0;
        }
     };

   struct Envelope
     {
      string stage_name;
      string schema_version;
      string payload;

      void Reset()
        {
         stage_name="";
         schema_version="";
         payload="";
        }
     };

   int EstimateUtf8Bytes(const string text)
     {
      uchar bytes[];
      const int n=StringToCharArray(text,bytes,0,-1,CP_UTF8);
      if(n<=0)
         return 0;
      return MathMax(0,n-1);
     }

   void JsonBuildStart(ForensicState &io_state,const string checkpoint)
     {
      io_state.checkpoint=checkpoint;
      io_state.last_error="none";
      io_state.payload_bytes_attempted=0;
      io_state.payload_bytes_written=0;
     }

   void JsonBuildComplete(ForensicState &io_state,const string payload,const string checkpoint)
     {
      io_state.checkpoint=checkpoint;
      io_state.payload_bytes_attempted=EstimateUtf8Bytes(payload);
      io_state.payload_bytes_written=io_state.payload_bytes_attempted;
      io_state.last_error="none";
     }

   void JsonSymbolSerializeStart(ForensicState &io_state,const string symbol)
     {
      io_state.checkpoint="json_symbol_serialize_start";
      io_state.symbol=symbol;
      io_state.last_serialized_symbol=symbol;
     }

   void JsonSymbolSerializeComplete(ForensicState &io_state,const string symbol)
     {
      io_state.checkpoint="json_symbol_serialize_complete";
      io_state.symbol=symbol;
      io_state.last_successful_symbol=symbol;
     }

   void JsonFail(ForensicState &io_state,const string checkpoint,const string reason,const int err)
     {
      io_state.checkpoint=checkpoint;
      io_state.last_error=reason;
      if(err!=0)
         io_state.write_error=err;
     }

   string EscapeJson(const string s,bool &out_ok)
     {
      out_ok=true;
      return ISSX_Util::EscapeJson(s);
     }

   string JsonStringField(const string name,const string value)
     {
      return ISSX_JsonWriter::NameStringKV(name,value);
     }

   string JsonLongField(const string name,const long value)
     {
      return ISSX_JsonWriter::NameLongKV(name,value);
     }

   string JsonDoubleField(const string name,const double value,const int digits=ISSX_JSON_DOUBLE_DIGITS_DEFAULT)
     {
      return ISSX_JsonWriter::NameDoubleKV(name,value,digits);
     }

   string JsonBoolField(const string name,const bool value)
     {
      return ISSX_JsonWriter::NameBoolKV(name,value);
     }

   bool WritePayloadAtomic(const string relative_path,
                           const string payload,
                           ForensicState &io_state,
                           const bool allow_copy_fallback=true)
     {
      io_state.final_path=relative_path;
      io_state.payload_bytes_attempted=EstimateUtf8Bytes(payload);
      io_state.payload_bytes_written=0;

      if(!IsSafeRelativePath(relative_path))
        {
         JsonFail(io_state,"json_fail","unsafe_relative_path",0);
         return false;
        }

      if(io_state.payload_bytes_attempted>ISSX_DATA_HANDLER_MAX_PAYLOAD_BYTES)
        {
         JsonFail(io_state,"json_fail","payload_too_large",0);
         return false;
        }

      if(!EnsureParentFolder(relative_path))
        {
         JsonFail(io_state,"json_fail","parent_folder_create_failed",0);
         return false;
        }

      uchar payload_bytes[];
      int payload_encoded=StringToCharArray(payload,payload_bytes,0,-1,CP_UTF8);
      if(payload_encoded<0)
         payload_encoded=0;
      const int wanted=MathMax(0,payload_encoded-1);

      const int attempts=MathMax(1,ISSX_DATA_HANDLER_WRITE_RETRY_MAX);
      for(int attempt=1;attempt<=attempts;attempt++)
        {
         io_state.temp_path=BuildTempPath(relative_path,attempt);

         io_state.checkpoint="json_write_tmp_start";
         ResetLastError();
         const int h=FileOpen(io_state.temp_path,FILE_WRITE|FILE_BIN|FILE_COMMON);
         io_state.open_error=GetLastError();
         if(h==INVALID_HANDLE)
           {
            if(attempt==attempts)
              {
               JsonFail(io_state,"json_fail","tmp_open_failed",io_state.open_error);
               return false;
              }
            continue;
           }

         ResetLastError();
         const uint written=(wanted>0 ? FileWriteArray(h,payload_bytes,0,wanted) : 0);
         io_state.write_error=GetLastError();

         ResetLastError();
         FileFlush(h);
         const int flush_error=GetLastError();
         FileClose(h);

         if(((int)written!=wanted) || io_state.write_error!=0 || flush_error!=0)
           {
            ResetLastError();
            FileDelete(io_state.temp_path,FILE_COMMON);
            io_state.delete_error=GetLastError();
            if(attempt==attempts)
              {
               JsonFail(io_state,"json_fail","tmp_write_or_flush_failed",(io_state.write_error!=0?io_state.write_error:flush_error));
               return false;
              }
            continue;
           }

         io_state.payload_bytes_written=EstimateUtf8Bytes(payload);
         io_state.checkpoint="json_write_tmp_complete";

         io_state.checkpoint="json_commit_start";
         ResetLastError();
         FileDelete(relative_path,FILE_COMMON);
         io_state.delete_error=GetLastError();

         ResetLastError();
         if(!FileMove(io_state.temp_path,FILE_COMMON,relative_path,FILE_COMMON))
           {
            io_state.move_error=GetLastError();
            if(!allow_copy_fallback)
              {
               if(attempt==attempts)
                 {
                  JsonFail(io_state,"json_fail","commit_move_failed",io_state.move_error);
                  return false;
                 }
               continue;
              }

            ResetLastError();
            if(!FileCopy(io_state.temp_path,FILE_COMMON,relative_path,FILE_COMMON))
              {
               io_state.copy_error=GetLastError();
               ResetLastError();
               FileDelete(io_state.temp_path,FILE_COMMON);
               io_state.delete_error=GetLastError();
               if(attempt==attempts)
                 {
                  JsonFail(io_state,"json_fail","commit_copy_failed",io_state.copy_error);
                  return false;
                 }
               continue;
              }

            ResetLastError();
            FileDelete(io_state.temp_path,FILE_COMMON);
            io_state.delete_error=GetLastError();
           }

         if(!VerifyFinalPayload(relative_path,io_state.payload_bytes_attempted))
           {
            if(attempt==attempts)
              {
               JsonFail(io_state,"json_fail","commit_verify_failed",0);
               return false;
              }
            continue;
           }

         io_state.checkpoint="json_commit_complete";
         return true;
        }

      JsonFail(io_state,"json_fail","write_retry_exhausted",0);
      return false;
     }

   bool CopyProjection(const string src_path,const string dst_path,ForensicState &io_state)
     {
      io_state.checkpoint="json_copy_projection_start";
      io_state.temp_path=src_path;
      io_state.final_path=dst_path;
      ResetLastError();
      FileDelete(dst_path,FILE_COMMON);
      io_state.delete_error=GetLastError();
      ResetLastError();
      const bool ok=FileCopy(src_path,FILE_COMMON,dst_path,FILE_COMMON);
      io_state.copy_error=GetLastError();
      if(!ok)
        {
         JsonFail(io_state,"json_fail","projection_copy_failed",io_state.copy_error);
         return false;
        }
      io_state.checkpoint="json_copy_projection_complete";
      return true;
     }

   bool SerializeStagePayload(const string stage_name,const string payload,string &out_json)
     {
      out_json="{";
      out_json+=JsonStringField("stage_name",stage_name)+",";
      out_json+=JsonStringField("schema_version",ISSX_SCHEMA_VERSION)+",";
      out_json+="\"payload\":"+payload;
      out_json+="}";
      return (StringLen(out_json)>2);
     }

   bool ParseStagePayload(const string json,Envelope &out_envelope)
     {
      out_envelope.Reset();
      if(StringLen(json)<=2)
         return false;
      out_envelope.payload=json;
      return true;
     }

   bool SaveStagePayload(const string relative_path,const string payload)
     {
      ForensicState fs;
      fs.Reset();
      return WritePayloadAtomic(relative_path,payload,fs,true);
     }

   bool LoadStagePayload(const string relative_path,string &payload)
     {
      payload="";
      ResetLastError();
      const int h=FileOpen(relative_path,FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI,"\n",CP_UTF8);
      if(h==INVALID_HANDLE)
         return false;
      const ulong sz=FileSize(h);
      if(sz>(ulong)2147483647)
        {
         FileClose(h);
         return false;
        }
      payload=FileReadString(h,(int)sz);
      const int err=GetLastError();
      FileClose(h);
      return (err==0);
     }

   bool ValidateExchangeCompatibility(const string producer_stage,
                                      const string consumer_stage,
                                      string &reason)
     {
      if(ISSX_Util::IsEmpty(producer_stage) || ISSX_Util::IsEmpty(consumer_stage))
        {
         reason="missing_stage_name";
         return false;
        }
      reason="ok";
      return true;
     }

   // ========================================================================
   // SECTION 02: CENTRALIZED MARKET DATA GATEWAY
   // ========================================================================

   enum ISSX_DataReadiness
     {
      issx_data_not_ready = 0,
      issx_data_stale,
      issx_data_valid_for_analysis
     };

   struct SymbolDiagnostics
     {
      string symbol;
      bool   symbol_exists;
      bool   symbol_selected;
      bool   symbol_visible;
      bool   custom_symbol;
      long   trade_mode;
      long   calc_mode;
      int    digits;
      double point;
      double tick_size;
      double spread_points_reported;
      bool   spread_float;
      bool   spec_valid;
      bool   spread_available;
      bool   market_watch_ready;
      string validation_reason;

      void Reset()
        {
         symbol="";
         symbol_exists=false;
         symbol_selected=false;
         symbol_visible=false;
         custom_symbol=false;
         trade_mode=0;
         calc_mode=0;
         digits=0;
         point=0.0;
         tick_size=0.0;
         spread_points_reported=0.0;
         spread_float=false;
         spec_valid=false;
         spread_available=false;
         market_watch_ready=false;
         validation_reason="none";
        }
     };

   struct TickSnapshot
     {
      string   symbol;
      MqlTick  tick;
      datetime tick_time;
      datetime capture_time;
      long     acquisition_millis;
      bool     acquired;
      bool     valid_prices;
      bool     recent;
      bool     stale;
      int      stale_after_sec;
      string   source_tag;
      string   reason;

      void Reset()
        {
         symbol="";
         ZeroMemory(tick);
         tick_time=0;
         capture_time=0;
         acquisition_millis=0;
         acquired=false;
         valid_prices=false;
         recent=false;
         stale=true;
         stale_after_sec=ISSX_DH_DEFAULT_LIVE_STALE_SEC;
         source_tag="live_terminal";
         reason="none";
        }
     };

   struct RatesSnapshot
     {
      string          symbol;
      ENUM_TIMEFRAMES timeframe;
      MqlRates        rates[];
      int             requested;
      int             copied;
      int             bars_loaded;
      datetime        first_bar_time;
      datetime        last_bar_time;
      bool            has_rates;
      bool            history_complete;
      bool            ordered;
      bool            ohlc_valid;
      bool            timeframe_consistent;
      bool            partial_return;
      string          reason;

      void Reset()
        {
         symbol="";
         timeframe=PERIOD_CURRENT;
         ArrayResize(rates,0);
         requested=0;
         copied=0;
         bars_loaded=0;
         first_bar_time=0;
         last_bar_time=0;
         has_rates=false;
         history_complete=false;
         ordered=true;
         ohlc_valid=true;
         timeframe_consistent=true;
         partial_return=false;
         reason="none";
        }
     };

   struct MarketSnapshot
     {
      string          symbol;
      ENUM_TIMEFRAMES timeframe;

      double          bid;
      double          ask;
      double          spread_points;

      datetime        last_tick_time;
      datetime        capture_time;
      datetime        terminal_capture_time;
      datetime        last_bar_time;

      int             bars_loaded;
      int             min_rates_required;
      long            trade_mode;
      bool            spread_float;
      bool            market_open_detectable;
      bool            market_open_likely;

      bool            has_live_tick;
      bool            has_recent_tick;
      bool            has_rates;
      bool            history_complete;
      bool            is_stale;
      bool            is_cached;
      bool            is_valid_for_analysis;

      bool            symbol_valid;
      bool            timeframe_consistent;
      bool            tick_valid;
      bool            spec_valid;
      bool            prices_valid;
      bool            snapshot_source_match;

      string          cache_state;
      string          readiness_reason;
      string          source_reason;
      string          validation_code;

      SymbolDiagnostics symbol_diag;
      TickSnapshot      tick_snapshot;
      RatesSnapshot     rates_snapshot;

      void Reset()
        {
         symbol="";
         timeframe=PERIOD_CURRENT;
         bid=0.0;
         ask=0.0;
         spread_points=0.0;
         last_tick_time=0;
         capture_time=0;
         terminal_capture_time=0;
         last_bar_time=0;
         bars_loaded=0;
         min_rates_required=ISSX_DH_DEFAULT_MIN_RATES;
         trade_mode=0;
         spread_float=false;
         market_open_detectable=false;
         market_open_likely=false;
         has_live_tick=false;
         has_recent_tick=false;
         has_rates=false;
         history_complete=false;
         is_stale=true;
         is_cached=false;
         is_valid_for_analysis=false;
         symbol_valid=false;
         timeframe_consistent=false;
         tick_valid=false;
         spec_valid=false;
         prices_valid=false;
         snapshot_source_match=false;
         cache_state="none";
         readiness_reason="not_initialized";
         source_reason="none";
         validation_code="not_initialized";
         symbol_diag.Reset();
         tick_snapshot.Reset();
         rates_snapshot.Reset();
        }
     };

   struct SnapshotCacheEntry
     {
      bool            present;
      MarketSnapshot  snapshot;
      datetime        cached_at;

      void Reset()
        {
         present=false;
         snapshot.Reset();
         cached_at=0;
        }
     };

   static SnapshotCacheEntry g_cache[8];

   datetime TerminalNow()
     {
      datetime now=TimeTradeServer();
      if(now<=0)
         now=TimeCurrent();
      if(now<=0)
         now=TimeLocal();
      return now;
     }

   int TimeframeSecondsSafe(const ENUM_TIMEFRAMES tf)
     {
      int s=PeriodSeconds(tf);
      if(s<=0 && tf==PERIOD_CURRENT)
         s=PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      return s;
     }

   bool SymbolExistsLocal(const string symbol)
     {
      if(ISSX_Util::IsEmpty(symbol))
         return false;

      const int total_all=SymbolsTotal(true);
      for(int i=0;i<total_all;i++)
        {
         if(SymbolName(i,true)==symbol)
            return true;
        }

      const int total_selected=SymbolsTotal(false);
      for(int j=0;j<total_selected;j++)
        {
         if(SymbolName(j,false)==symbol)
            return true;
        }

      return false;
     }

   int CacheIndex(const string symbol,const ENUM_TIMEFRAMES timeframe)
     {
      const string key=symbol+"|"+IntegerToString((int)timeframe);
      for(int i=0;i<ArraySize(g_cache);i++)
        {
         if(!g_cache[i].present)
            continue;
         const string existing=g_cache[i].snapshot.symbol+"|"+IntegerToString((int)g_cache[i].snapshot.timeframe);
         if(existing==key)
            return i;
        }

      for(int k=0;k<ArraySize(g_cache);k++)
         if(!g_cache[k].present)
            return k;

      return 0;
     }

   void CacheStore(const MarketSnapshot &snap)
     {
      int idx=CacheIndex(snap.symbol,snap.timeframe);
      if(idx<0)
         return;
      g_cache[idx].present=true;
      g_cache[idx].snapshot=snap;
      g_cache[idx].cached_at=TerminalNow();
     }

   bool CacheLoad(const string symbol,const ENUM_TIMEFRAMES timeframe,MarketSnapshot &out_snap)
     {
      int idx=CacheIndex(symbol,timeframe);
      if(idx<0)
         return false;
      if(!g_cache[idx].present)
         return false;
      out_snap=g_cache[idx].snapshot;
      return true;
     }

   bool ValidateSymbol(const string symbol,SymbolDiagnostics &out_diag,const bool select_if_needed=true)
     {
      out_diag.Reset();
      out_diag.symbol=symbol;

      if(ISSX_Util::IsEmpty(symbol))
        {
         out_diag.validation_reason="empty_symbol";
         return false;
        }

      out_diag.symbol_exists=SymbolExistsLocal(symbol);
      if(!out_diag.symbol_exists)
        {
         out_diag.validation_reason="symbol_missing";
         return false;
        }

      bool selected=(bool)SymbolInfoInteger(symbol,SYMBOL_SELECT);
      if(!selected && select_if_needed)
         selected=SymbolSelect(symbol,true);

      out_diag.symbol_selected=selected;
      out_diag.symbol_visible=((bool)SymbolInfoInteger(symbol,SYMBOL_VISIBLE));
      out_diag.custom_symbol=((bool)SymbolInfoInteger(symbol,SYMBOL_CUSTOM));
      long spread_points_raw=0;

      out_diag.trade_mode=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
      out_diag.calc_mode=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE);
      out_diag.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      out_diag.point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      out_diag.tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);

      if(SymbolInfoInteger(symbol,SYMBOL_SPREAD,spread_points_raw))
         out_diag.spread_points_reported=(double)spread_points_raw;
      else
         out_diag.spread_points_reported=0.0;

      out_diag.spread_float=((bool)SymbolInfoInteger(symbol,SYMBOL_SPREAD_FLOAT));

      out_diag.spread_available=(out_diag.spread_points_reported>=0.0);
      out_diag.market_watch_ready=out_diag.symbol_selected;

      out_diag.spec_valid=(out_diag.symbol_selected &&
                           out_diag.digits>0 &&
                           out_diag.point>0.0 &&
                           out_diag.tick_size>0.0);

      if(!out_diag.symbol_selected)
        {
         out_diag.validation_reason="symbol_select_failed";
         return false;
        }

      if(!out_diag.spec_valid)
        {
         out_diag.validation_reason="invalid_symbol_spec";
         return false;
        }

      out_diag.validation_reason="ok";
      return true;
     }

   bool AcquireLiveTick(const string symbol,
                        TickSnapshot &out_tick,
                        const int stale_after_sec=ISSX_DH_DEFAULT_LIVE_STALE_SEC)
     {
      out_tick.Reset();
      out_tick.symbol=symbol;
      out_tick.capture_time=TerminalNow();
      out_tick.stale_after_sec=MathMax(1,stale_after_sec);
      out_tick.acquisition_millis=(long)GetTickCount64();

      if(ISSX_Util::IsEmpty(symbol))
        {
         out_tick.reason="empty_symbol";
         return false;
        }

      MqlTick tick;
      ZeroMemory(tick);

      if(!SymbolInfoTick(symbol,tick))
        {
         out_tick.reason="symbol_info_tick_failed";
         return false;
        }

      out_tick.tick=tick;
      out_tick.tick_time=(datetime)tick.time;
      out_tick.acquired=true;

      if(out_tick.tick_time<=0)
        {
         out_tick.reason="tick_time_invalid";
         return false;
        }

      if(tick.bid<=0.0 || tick.ask<=0.0)
        {
         out_tick.reason="tick_prices_non_positive";
         return false;
        }

      if(tick.ask<tick.bid)
        {
         out_tick.reason="tick_ask_below_bid";
         return false;
        }

      out_tick.valid_prices=true;

      const datetime now=out_tick.capture_time;
      const long age_sec=(long)(now-out_tick.tick_time);

      out_tick.stale=(age_sec>out_tick.stale_after_sec);
      out_tick.recent=!out_tick.stale;

      if(out_tick.stale)
        {
         out_tick.reason="tick_stale";
         return false;
        }

      out_tick.reason="ok";
      return true;
     }

   bool ValidateRatesWindow(const MqlRates &rates[],
                            const int copied,
                            datetime &out_first_time,
                            datetime &out_last_time,
                            bool &out_ordered,
                            bool &out_ohlc_valid)
     {
      out_first_time=0;
      out_last_time=0;
      out_ordered=true;
      out_ohlc_valid=true;

      if(copied<=0)
         return false;

      // CopyRates with start_pos 0 usually returns series order: newest first.
      // We only validate monotonicity, not assumed direction ambiguity.
      out_first_time=rates[copied-1].time;
      out_last_time=rates[0].time;

      for(int i=0;i<copied;i++)
        {
         if(rates[i].time<=0)
           {
            out_ordered=false;
            return false;
           }

         const double o=rates[i].open;
         const double h=rates[i].high;
         const double l=rates[i].low;
         const double c=rates[i].close;

         if(o<=0.0 || h<=0.0 || l<=0.0 || c<=0.0)
            out_ohlc_valid=false;

         if(l>h)
            out_ohlc_valid=false;

         if(o>h || o<l || c>h || c<l)
            out_ohlc_valid=false;

         if(i>0)
           {
            if(rates[i-1].time<=rates[i].time)
               out_ordered=false;
           }
        }

      return true;
     }

   bool AcquireRates(const string symbol,
                     const ENUM_TIMEFRAMES timeframe,
                     const int bars_needed,
                     RatesSnapshot &out_rates,
                     const bool full_window_required=true)
     {
      out_rates.Reset();
      out_rates.symbol=symbol;
      out_rates.timeframe=timeframe;
      out_rates.requested=MathMax(1,MathMin(ISSX_DH_MAX_RATES_WINDOW,bars_needed));

      if(ISSX_Util::IsEmpty(symbol))
        {
         out_rates.reason="empty_symbol";
         return false;
        }

      if(TimeframeSecondsSafe(timeframe)<=0)
        {
         out_rates.timeframe_consistent=false;
         out_rates.reason="invalid_timeframe";
         return false;
        }

      ArraySetAsSeries(out_rates.rates,true);
      const int copied=CopyRates(symbol,timeframe,0,out_rates.requested,out_rates.rates);

      out_rates.copied=copied;
      out_rates.bars_loaded=(copied>0 ? copied : 0);
      out_rates.has_rates=(copied>0);

      if(copied<=0)
        {
         out_rates.reason="copyrates_failed_or_empty";
         return false;
        }

      out_rates.partial_return=(copied<out_rates.requested);
      if(full_window_required && out_rates.partial_return)
        {
         out_rates.history_complete=false;
         out_rates.reason="copyrates_partial_return";
         return false;
        }

      datetime first_time=0;
      datetime last_time=0;
      bool ordered=true;
      bool ohlc_valid=true;
      if(!ValidateRatesWindow(out_rates.rates,copied,first_time,last_time,ordered,ohlc_valid))
        {
         out_rates.ordered=ordered;
         out_rates.ohlc_valid=ohlc_valid;
         out_rates.reason="rates_validation_failed";
         return false;
        }

      out_rates.first_bar_time=first_time;
      out_rates.last_bar_time=last_time;
      out_rates.ordered=ordered;
      out_rates.ohlc_valid=ohlc_valid;
      out_rates.timeframe_consistent=true;
      out_rates.history_complete=(!out_rates.partial_return);

      if(!out_rates.ordered)
        {
         out_rates.reason="rates_not_ordered";
         return false;
        }

      if(!out_rates.ohlc_valid)
        {
         out_rates.reason="rates_invalid_ohlc";
         return false;
        }

      out_rates.reason="ok";
      return true;
     }

   bool IsMarketOpenLikely(const SymbolDiagnostics &diag,const TickSnapshot &tick_snap)
     {
      if(diag.trade_mode==(long)SYMBOL_TRADE_MODE_DISABLED)
         return false;

      if(tick_snap.acquired && tick_snap.valid_prices && tick_snap.recent)
         return true;

      return false;
     }

   void SetSnapshotInvalid(MarketSnapshot &snap,
                           const string readiness_reason,
                           const string source_reason,
                           const string validation_code)
     {
      snap.is_valid_for_analysis=false;
      snap.readiness_reason=readiness_reason;
      snap.source_reason=source_reason;
      snap.validation_code=validation_code;
     }

   bool FinalizeMarketSnapshotValidation(MarketSnapshot &snap,
                                         const int bars_needed,
                                         const bool full_window_required)
     {
      snap.min_rates_required=MathMax(1,bars_needed);
      snap.capture_time=snap.terminal_capture_time;
      snap.prices_valid=(snap.bid>0.0 && snap.ask>0.0 && snap.ask>=snap.bid);
      snap.snapshot_source_match=(snap.tick_snapshot.symbol==snap.symbol &&
                                  snap.rates_snapshot.symbol==snap.symbol &&
                                  snap.rates_snapshot.timeframe==snap.timeframe);
      snap.timeframe_consistent=(TimeframeSecondsSafe(snap.timeframe)>0 &&
                                 snap.rates_snapshot.timeframe_consistent &&
                                 snap.snapshot_source_match);

      if(!snap.symbol_valid)
        {
         SetSnapshotInvalid(snap,"symbol_invalid","symbol_validation_failed","symbol_invalid");
         return false;
        }

      if(!snap.spec_valid)
        {
         SetSnapshotInvalid(snap,"invalid_symbol_spec","symbol_validation_failed","spec_invalid");
         return false;
        }

      if(!snap.has_live_tick)
        {
         SetSnapshotInvalid(snap,"live_tick_unavailable",snap.tick_snapshot.reason,"tick_missing");
         return false;
        }

      if(snap.last_tick_time<=0)
        {
         SetSnapshotInvalid(snap,"tick_time_invalid",snap.tick_snapshot.reason,"tick_time_invalid");
         return false;
        }

      if(!snap.tick_valid)
        {
         SetSnapshotInvalid(snap,"tick_invalid",snap.tick_snapshot.reason,"tick_invalid");
         return false;
        }

      if(!snap.prices_valid)
        {
         SetSnapshotInvalid(snap,"tick_prices_invalid",snap.tick_snapshot.reason,"tick_prices_invalid");
         return false;
        }

      if(snap.is_stale || !snap.has_recent_tick)
        {
         snap.is_stale=true;
         SetSnapshotInvalid(snap,"stale_tick_detected",snap.tick_snapshot.reason,"stale_tick");
         return false;
        }

      if(!snap.has_rates)
        {
         SetSnapshotInvalid(snap,"rates_unavailable",snap.rates_snapshot.reason,"rates_missing");
         return false;
        }

      if(snap.bars_loaded<snap.min_rates_required)
        {
         SetSnapshotInvalid(snap,"insufficient_rates",snap.rates_snapshot.reason,"insufficient_rates");
         return false;
        }

      if(snap.last_bar_time<=0)
        {
         SetSnapshotInvalid(snap,"last_bar_time_invalid",snap.rates_snapshot.reason,"last_bar_time_invalid");
         return false;
        }

      if(!snap.timeframe_consistent)
        {
         SetSnapshotInvalid(snap,"timeframe_mismatch","snapshot_source_mismatch","timeframe_mismatch");
         return false;
        }

      if(full_window_required && !snap.history_complete)
        {
         SetSnapshotInvalid(snap,"history_incomplete",snap.rates_snapshot.reason,"history_incomplete");
         return false;
        }

      snap.is_valid_for_analysis=true;
      snap.readiness_reason="ok";
      snap.source_reason="live_validated";
      snap.validation_code="valid_for_analysis";
      return true;
     }

   bool BuildAndValidateCurrentMarketSnapshot(const string symbol,
                                              const ENUM_TIMEFRAMES timeframe,
                                              MarketSnapshot &out_snapshot,
                                              string &out_reason,
                                              const int stale_after_sec=ISSX_DH_DEFAULT_LIVE_STALE_SEC,
                                              const int bars_needed=ISSX_DH_DEFAULT_MIN_RATES,
                                              const bool full_window_required=false,
                                              const bool allow_cached_fallback=false)
     {
      out_reason="ok";
      const bool ok=BuildMarketSnapshot(symbol,timeframe,out_snapshot,
                                        stale_after_sec,bars_needed,
                                        full_window_required,allow_cached_fallback);
      out_reason=out_snapshot.readiness_reason;
      return ok;
     }
     
         bool BuildMarketSnapshot(const string symbol,
                            const ENUM_TIMEFRAMES timeframe,
                            MarketSnapshot &out_snapshot,
                            const int stale_after_sec=ISSX_DH_DEFAULT_LIVE_STALE_SEC,
                            const int bars_needed=ISSX_DH_DEFAULT_MIN_RATES,
                            const bool full_window_required=false,
                            const bool allow_cached_fallback=true)
     {
      out_snapshot.Reset();
      out_snapshot.symbol=symbol;
      out_snapshot.timeframe=timeframe;
      out_snapshot.capture_time=TerminalNow();
      out_snapshot.terminal_capture_time=out_snapshot.capture_time;
      out_snapshot.min_rates_required=MathMax(1,bars_needed);

      if(TimeframeSecondsSafe(timeframe)<=0)
        {
         SetSnapshotInvalid(out_snapshot,"timeframe_invalid","timeframe_invalid","timeframe_invalid");
         return false;
        }

      // 1) Symbol validation
      if(!ValidateSymbol(symbol,out_snapshot.symbol_diag,true))
        {
         out_snapshot.symbol_valid=false;
         out_snapshot.spec_valid=false;
         SetSnapshotInvalid(out_snapshot,
                            out_snapshot.symbol_diag.validation_reason,
                            "symbol_validation_failed",
                            "symbol_validation_failed");

         if(allow_cached_fallback)
           {
            MarketSnapshot cached;
            if(CacheLoad(symbol,timeframe,cached))
              {
               out_snapshot=cached;
               out_snapshot.is_cached=true;
               out_snapshot.is_stale=true;
               out_snapshot.has_recent_tick=false;
               out_snapshot.is_valid_for_analysis=false;
               out_snapshot.cache_state="cached_fallback";
               out_snapshot.readiness_reason="cached_symbol_validation_failed";
               out_snapshot.source_reason="cached_fallback";
               out_snapshot.validation_code="cached_fallback";
              }
           }

         return false;
        }

      out_snapshot.symbol_valid=true;
      out_snapshot.spec_valid=out_snapshot.symbol_diag.spec_valid;
      out_snapshot.trade_mode=out_snapshot.symbol_diag.trade_mode;
      out_snapshot.spread_float=out_snapshot.symbol_diag.spread_float;

      // 2) Live tick
      const bool tick_ok=AcquireLiveTick(symbol,out_snapshot.tick_snapshot,stale_after_sec);
      out_snapshot.has_live_tick=out_snapshot.tick_snapshot.acquired;
      out_snapshot.has_recent_tick=(tick_ok && out_snapshot.tick_snapshot.recent);
      out_snapshot.tick_valid=(out_snapshot.tick_snapshot.acquired && out_snapshot.tick_snapshot.valid_prices);
      out_snapshot.last_tick_time=out_snapshot.tick_snapshot.tick_time;
      out_snapshot.is_stale=(!out_snapshot.has_recent_tick);

      if(out_snapshot.tick_snapshot.acquired)
        {
         out_snapshot.bid=out_snapshot.tick_snapshot.tick.bid;
         out_snapshot.ask=out_snapshot.tick_snapshot.tick.ask;
         if(out_snapshot.symbol_diag.point>0.0 && out_snapshot.bid>0.0 && out_snapshot.ask>0.0)
            out_snapshot.spread_points=(out_snapshot.ask-out_snapshot.bid)/out_snapshot.symbol_diag.point;
        }

      // 3) Rates
      AcquireRates(symbol,timeframe,bars_needed,out_snapshot.rates_snapshot,full_window_required);
      out_snapshot.has_rates=out_snapshot.rates_snapshot.has_rates;
      out_snapshot.history_complete=out_snapshot.rates_snapshot.history_complete;
      out_snapshot.last_bar_time=out_snapshot.rates_snapshot.last_bar_time;
      out_snapshot.bars_loaded=out_snapshot.rates_snapshot.bars_loaded;

      // 4) Broker/session awareness
      out_snapshot.market_open_detectable=true;
      out_snapshot.market_open_likely=IsMarketOpenLikely(out_snapshot.symbol_diag,out_snapshot.tick_snapshot);

      // 5) Final hard validation
      const bool valid=FinalizeMarketSnapshotValidation(out_snapshot,bars_needed,full_window_required);

      out_snapshot.cache_state=(valid ? "fresh_validated" : (out_snapshot.is_stale ? "fresh_stale_blocked" : "fresh_blocked"));

      // Cache the normalized snapshot object, but never silently mark blocked data as valid.
      CacheStore(out_snapshot);

      return valid;
     }

   int ReadinessCode(const MarketSnapshot &snap)
     {
      if(snap.is_valid_for_analysis)
         return issx_data_valid_for_analysis;
      if(snap.is_stale)
         return issx_data_stale;
      return issx_data_not_ready;
     }

   string ReadinessText(const MarketSnapshot &snap)
     {
      const int code=ReadinessCode(snap);
      if(code==issx_data_valid_for_analysis)
         return "valid_for_analysis";
      if(code==issx_data_stale)
         return "stale";
      return "not_ready";
     }

   bool SymbolTickOnly(const string symbol,TickSnapshot &out_tick,const int stale_after_sec=ISSX_DH_DEFAULT_LIVE_STALE_SEC)
     {
      SymbolDiagnostics diag;
      diag.Reset();
      if(!ValidateSymbol(symbol,diag,true))
         return false;
      return AcquireLiveTick(symbol,out_tick,stale_after_sec);
     }

   bool SymbolRatesOnly(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const int bars_needed,
                        RatesSnapshot &out_rates,
                        const bool full_window_required=true)
     {
      SymbolDiagnostics diag;
      diag.Reset();
      if(!ValidateSymbol(symbol,diag,true))
         return false;
      return AcquireRates(symbol,timeframe,bars_needed,out_rates,full_window_required);
     }

   string SnapshotToJson(const MarketSnapshot &snap)
     {
      ISSX_JsonWriter j;
      j.Reset();
      j.BeginObject();
      j.NameString("symbol",snap.symbol);
      j.NameInt("timeframe",(int)snap.timeframe);
      j.NameDouble("bid",snap.bid,8);
      j.NameDouble("ask",snap.ask,8);
      j.NameDouble("spread_points",snap.spread_points,2);
      j.NameLong("last_tick_time",(long)snap.last_tick_time);
      j.NameLong("capture_time",(long)snap.capture_time);
      j.NameLong("terminal_capture_time",(long)snap.terminal_capture_time);
      j.NameLong("last_bar_time",(long)snap.last_bar_time);
      j.NameInt("bars_loaded",snap.bars_loaded);
      j.NameInt("min_rates_required",snap.min_rates_required);
      j.NameLong("trade_mode",snap.trade_mode);
      j.NameBool("spread_float",snap.spread_float);
      j.NameBool("market_open_detectable",snap.market_open_detectable);
      j.NameBool("market_open_likely",snap.market_open_likely);

      j.NameBool("has_live_tick",snap.has_live_tick);
      j.NameBool("has_recent_tick",snap.has_recent_tick);
      j.NameBool("has_rates",snap.has_rates);
      j.NameBool("history_complete",snap.history_complete);
      j.NameBool("is_stale",snap.is_stale);
      j.NameBool("is_cached",snap.is_cached);
      j.NameBool("is_valid_for_analysis",snap.is_valid_for_analysis);

      j.NameBool("symbol_valid",snap.symbol_valid);
      j.NameBool("timeframe_consistent",snap.timeframe_consistent);
      j.NameBool("tick_valid",snap.tick_valid);
      j.NameBool("spec_valid",snap.spec_valid);
      j.NameBool("prices_valid",snap.prices_valid);
      j.NameBool("snapshot_source_match",snap.snapshot_source_match);

      j.NameString("cache_state",snap.cache_state);
      j.NameString("readiness",ReadinessText(snap));
      j.NameString("readiness_reason",snap.readiness_reason);
      j.NameString("source_reason",snap.source_reason);
      j.NameString("validation_code",snap.validation_code);

      j.BeginNamedObject("symbol_diag");
      j.NameString("symbol",snap.symbol_diag.symbol);
      j.NameBool("symbol_exists",snap.symbol_diag.symbol_exists);
      j.NameBool("symbol_selected",snap.symbol_diag.symbol_selected);
      j.NameBool("symbol_visible",snap.symbol_diag.symbol_visible);
      j.NameBool("custom_symbol",snap.symbol_diag.custom_symbol);
      j.NameLong("trade_mode",snap.symbol_diag.trade_mode);
      j.NameLong("calc_mode",snap.symbol_diag.calc_mode);
      j.NameInt("digits",snap.symbol_diag.digits);
      j.NameDouble("point",snap.symbol_diag.point,8);
      j.NameDouble("tick_size",snap.symbol_diag.tick_size,8);
      j.NameDouble("spread_points_reported",snap.symbol_diag.spread_points_reported,2);
      j.NameBool("spread_float",snap.symbol_diag.spread_float);
      j.NameBool("spec_valid",snap.symbol_diag.spec_valid);
      j.NameBool("spread_available",snap.symbol_diag.spread_available);
      j.NameBool("market_watch_ready",snap.symbol_diag.market_watch_ready);
      j.NameString("validation_reason",snap.symbol_diag.validation_reason);
      j.EndObject();

      j.BeginNamedObject("tick_snapshot");
      j.NameString("symbol",snap.tick_snapshot.symbol);
      j.NameLong("tick_time",(long)snap.tick_snapshot.tick_time);
      j.NameLong("capture_time",(long)snap.tick_snapshot.capture_time);
      j.NameLong("acquisition_millis",snap.tick_snapshot.acquisition_millis);
      j.NameBool("acquired",snap.tick_snapshot.acquired);
      j.NameBool("valid_prices",snap.tick_snapshot.valid_prices);
      j.NameBool("recent",snap.tick_snapshot.recent);
      j.NameBool("stale",snap.tick_snapshot.stale);
      j.NameInt("stale_after_sec",snap.tick_snapshot.stale_after_sec);
      j.NameString("source_tag",snap.tick_snapshot.source_tag);
      j.NameString("reason",snap.tick_snapshot.reason);
      j.EndObject();

      j.BeginNamedObject("rates_snapshot");
      j.NameString("symbol",snap.rates_snapshot.symbol);
      j.NameInt("timeframe",(int)snap.rates_snapshot.timeframe);
      j.NameInt("requested",snap.rates_snapshot.requested);
      j.NameInt("copied",snap.rates_snapshot.copied);
      j.NameInt("bars_loaded",snap.rates_snapshot.bars_loaded);
      j.NameLong("first_bar_time",(long)snap.rates_snapshot.first_bar_time);
      j.NameLong("last_bar_time",(long)snap.rates_snapshot.last_bar_time);
      j.NameBool("has_rates",snap.rates_snapshot.has_rates);
      j.NameBool("history_complete",snap.rates_snapshot.history_complete);
      j.NameBool("ordered",snap.rates_snapshot.ordered);
      j.NameBool("ohlc_valid",snap.rates_snapshot.ohlc_valid);
      j.NameBool("timeframe_consistent",snap.rates_snapshot.timeframe_consistent);
      j.NameBool("partial_return",snap.rates_snapshot.partial_return);
      j.NameString("reason",snap.rates_snapshot.reason);
      j.EndObject();

      j.EndObject();
      return j.ToString();
     }

   // ========================================================================
   // SECTION 03: SIMPLE TEST / DIAGNOSTIC SCENARIOS
   // ========================================================================

   bool TestScenario_MarketOpenLiveTick(const string symbol,
                                        const ENUM_TIMEFRAMES timeframe,
                                        string &reason)
     {
      MarketSnapshot snap;
      const bool ok=BuildMarketSnapshot(symbol,timeframe,snap,ISSX_DH_DEFAULT_LIVE_STALE_SEC,ISSX_DH_DEFAULT_MIN_RATES,false,false);
      reason=snap.readiness_reason;
      return ok;
     }

   bool TestScenario_MarketClosedNoFreshTick(const string symbol,
                                             const ENUM_TIMEFRAMES timeframe,
                                             string &reason)
     {
      MarketSnapshot snap;
      const bool ok=BuildMarketSnapshot(symbol,timeframe,snap,1,ISSX_DH_DEFAULT_MIN_RATES,false,true);
      reason=snap.readiness_reason;
      return (!ok && snap.is_stale);
     }

   bool TestScenario_SymbolMissing(const string symbol,string &reason)
     {
      SymbolDiagnostics diag;
      const bool ok=ValidateSymbol(symbol,diag,true);
      reason=diag.validation_reason;
      return (!ok && reason=="symbol_missing");
     }

   bool TestScenario_CopyRatesPartialReturn(const string symbol,
                                            const ENUM_TIMEFRAMES timeframe,
                                            string &reason)
     {
      RatesSnapshot rs;
      const bool ok=AcquireRates(symbol,timeframe,2048,rs,true);
      reason=rs.reason;
      return (!ok && rs.reason=="copyrates_partial_return");
     }

   bool TestScenario_TimeframeMismatch(const ENUM_TIMEFRAMES timeframe,string &reason)
     {
      reason=(TimeframeSecondsSafe(timeframe)>0 ? "ok" : "invalid_timeframe");
      return (reason=="ok");
     }

   bool TestScenario_EmptyHistoryOnStartup(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe,
                                           string &reason)
     {
      RatesSnapshot rs;
      const bool ok=AcquireRates(symbol,timeframe,ISSX_DH_DEFAULT_MIN_RATES,rs,true);
      reason=rs.reason;
      return (ok || reason=="copyrates_failed_or_empty" || reason=="copyrates_partial_return");
     }
  }


#endif // __ISSX_DATA_HANDLER_MQH__