#ifndef __ISSX_TELEMETRY_MQH__
#define __ISSX_TELEMETRY_MQH__

// ============================================================================
// ISSX TELEMETRY ENGINE v1.723
// Infrastructure-only in-memory telemetry for structured diagnostics.
// ============================================================================

#define ISSX_TELEMETRY_VERSION         "1.726"
#define ISSX_TELEMETRY_MAX_EVENTS      256
#define ISSX_TELEMETRY_STAGE_COUNT     9

enum ISSX_TelemetryStageId
  {
   issx_telemetry_stage_ea1_market=0,
   issx_telemetry_stage_ea2_history,
   issx_telemetry_stage_ea3_selection,
   issx_telemetry_stage_ea4_correlation,
   issx_telemetry_stage_ea5_contracts,
   issx_telemetry_stage_system,
   issx_telemetry_stage_kernel,
   issx_telemetry_stage_runtime,
   issx_telemetry_stage_ui
  };

struct ISSX_TelemetryEvent
  {
   datetime timestamp;
   string   stage;
   string   event_type;
   string   message;
   double   value;
   string   symbol;
   long     cursor;

   void Reset()
     {
      timestamp=0;
      stage="";
      event_type="";
      message="";
      value=0.0;
      symbol="";
      cursor=-1;
     }
  };

struct ISSX_TelemetryStageSnapshot
  {
   string stage_name;
   string last_stage_run;
   string last_stage_reason;
   long   last_stage_elapsed_ms;
   long   symbols_processed;
   long   symbols_total;
   long   batch_cursor;
   long   batch_size;
   long   payload_bytes;
   long   estimated_memory;
   long   copyrates_calls;
   long   copyrates_bars;
   long   symbols_cycle;
   ulong  stage_begin_us;

   void Reset(const string name)
     {
      stage_name=name;
      last_stage_run="IDLE";
      last_stage_reason="none";
      last_stage_elapsed_ms=0;
      symbols_processed=0;
      symbols_total=0;
      batch_cursor=0;
      batch_size=0;
      payload_bytes=0;
      estimated_memory=0;
      copyrates_calls=0;
      copyrates_bars=0;
      symbols_cycle=0;
      stage_begin_us=0;
     }
  };

class ISSX_TelemetryEngine
  {
private:
   ISSX_TelemetryEvent         m_events[];
   ISSX_TelemetryStageSnapshot m_stage[];
   bool                        m_initialized;
   int                         m_count;
   int                         m_start;
   long                        m_total_events;
   long                        m_dropped_events;
   long                        m_cycle_count;
   string                      m_last_checkpoint;
   string                      m_last_stage_reason[];
   string                      m_last_stage_status[];
   long                        m_last_batch_processed[];
   long                        m_last_batch_total[];
   long                        m_last_batch_cursor[];
   long                        m_last_payload_bytes[];
   long                        m_last_memory_bytes[];
   int                         m_last_error_code[];
   string                      m_last_error_message[];
   long                        m_last_copyrates_reported_calls;

   string StageName(const ISSX_TelemetryStageId stage_id) const
     {
      switch(stage_id)
        {
         case issx_telemetry_stage_ea1_market:     return "EA1_MARKET";
         case issx_telemetry_stage_ea2_history:    return "EA2_HISTORY";
         case issx_telemetry_stage_ea3_selection:  return "EA3_SELECTION";
         case issx_telemetry_stage_ea4_correlation:return "EA4_CORRELATION";
         case issx_telemetry_stage_ea5_contracts:  return "EA5_CONTRACTS";
         case issx_telemetry_stage_system:         return "SYSTEM";
         case issx_telemetry_stage_kernel:         return "KERNEL";
         case issx_telemetry_stage_runtime:        return "RUNTIME";
         case issx_telemetry_stage_ui:             return "UI";
        }
      return "SYSTEM";
     }

   int StageIndex(const ISSX_TelemetryStageId stage_id) const
     {
      int idx=(int)stage_id;
      if(idx<0 || idx>=ISSX_TELEMETRY_STAGE_COUNT)
         return (int)issx_telemetry_stage_system;
      return idx;
     }

   ISSX_TelemetryStageId StageIdFromName(const string stage_name) const
     {
      string key=stage_name;
      StringToLower(key);
      if(key=="ea1_market")
         return issx_telemetry_stage_ea1_market;
      if(key=="ea2_history")
         return issx_telemetry_stage_ea2_history;
      if(key=="ea3_selection")
         return issx_telemetry_stage_ea3_selection;
      if(key=="ea4_correlation")
         return issx_telemetry_stage_ea4_correlation;
      if(key=="ea5_contracts")
         return issx_telemetry_stage_ea5_contracts;
      if(key=="kernel")
         return issx_telemetry_stage_kernel;
      if(key=="runtime")
         return issx_telemetry_stage_runtime;
      if(key=="ui")
         return issx_telemetry_stage_ui;
      return issx_telemetry_stage_system;
     }

   void Push(const ISSX_TelemetryStageId stage_id,
             const string event_type,
             const string message,
             const double value,
             const string symbol,
             const long cursor)
     {
      if(!m_initialized)
         return;

      if(m_count>0)
        {
         const int last_idx=(m_start+m_count-1)%ISSX_TELEMETRY_MAX_EVENTS;
         if(m_events[last_idx].stage==StageName(stage_id)
            && m_events[last_idx].event_type==event_type
            && m_events[last_idx].message==message
            && m_events[last_idx].value==value
            && m_events[last_idx].symbol==symbol
            && m_events[last_idx].cursor==cursor)
            return;
        }

      int write_index=0;
      if(m_count<ISSX_TELEMETRY_MAX_EVENTS)
        {
         write_index=(m_start+m_count)%ISSX_TELEMETRY_MAX_EVENTS;
         m_count++;
        }
      else
        {
         write_index=m_start;
         m_start=(m_start+1)%ISSX_TELEMETRY_MAX_EVENTS;
         m_dropped_events++;
        }

      ISSX_TelemetryEvent evt;
      evt.Reset();
      evt.timestamp=TimeCurrent();
      evt.stage=StageName(stage_id);
      evt.event_type=event_type;
      evt.message=message;
      evt.value=value;
      evt.symbol=symbol;
      evt.cursor=cursor;
      m_events[write_index]=evt;
      m_total_events++;
    }

   string ErrorTypeFromCode(const int code,const string message) const
     {
      if(code==0)
         return "error_unknown";
      const int abs_code=MathAbs(code);
      if(abs_code==4014 || abs_code==4016 || abs_code==4756)
         return "error_trade";
      if(abs_code>=4000 && abs_code<5000)
         return "error_runtime";
      if(abs_code>=5000 && abs_code<6000)
         return "error_io";
      string lc=message;
      StringToLower(lc);
      if(StringFind(lc,"memory")>=0 || StringFind(lc,"alloc")>=0)
         return "error_memory";
      if(StringFind(lc,"network")>=0 || StringFind(lc,"timeout")>=0)
         return "error_network";
      return "error_general";
     }

   string EventTypeFromStatus(const string status) const
     {
      if(status=="skipped" || status=="SKIPPED")
         return "stage_skipped";
      if(status=="degraded" || status=="DEGRADED" || status=="partial" || status=="PARTIAL")
         return "stage_degraded";
      if(status=="error" || status=="ERROR" || status=="failed" || status=="FAILED")
         return "stage_error";
      if(status=="blocked" || status=="BLOCKED")
         return "stage_blocked";
      return "stage_complete";
     }

public:
   void Init()
     {
      ArrayResize(m_events,ISSX_TELEMETRY_MAX_EVENTS);
      for(int i=0;i<ArraySize(m_events);i++)
         m_events[i].Reset();

      ArrayResize(m_stage,ISSX_TELEMETRY_STAGE_COUNT);
      for(int s=0;s<ISSX_TELEMETRY_STAGE_COUNT;s++)
         m_stage[s].Reset(StageName((ISSX_TelemetryStageId)s));

      m_count=0;
      m_start=0;
      m_total_events=0;
      m_dropped_events=0;
      m_cycle_count=0;
      m_last_checkpoint="";

      ArrayResize(m_last_stage_reason,ISSX_TELEMETRY_STAGE_COUNT);
      ArrayResize(m_last_stage_status,ISSX_TELEMETRY_STAGE_COUNT);
      ArrayResize(m_last_batch_processed,ISSX_TELEMETRY_STAGE_COUNT);
      ArrayResize(m_last_batch_total,ISSX_TELEMETRY_STAGE_COUNT);
      ArrayResize(m_last_batch_cursor,ISSX_TELEMETRY_STAGE_COUNT);
      ArrayResize(m_last_payload_bytes,ISSX_TELEMETRY_STAGE_COUNT);
      ArrayResize(m_last_memory_bytes,ISSX_TELEMETRY_STAGE_COUNT);
      ArrayResize(m_last_error_code,ISSX_TELEMETRY_STAGE_COUNT);
      ArrayResize(m_last_error_message,ISSX_TELEMETRY_STAGE_COUNT);
      for(int k=0;k<ISSX_TELEMETRY_STAGE_COUNT;k++)
        {
         m_last_stage_reason[k]="";
         m_last_stage_status[k]="";
         m_last_batch_processed[k]=-1;
         m_last_batch_total[k]=-1;
         m_last_batch_cursor[k]=-1;
         m_last_payload_bytes[k]=-1;
         m_last_memory_bytes[k]=-1;
         m_last_error_code[k]=-2147483647;
         m_last_error_message[k]="";
        }
      m_last_copyrates_reported_calls=0;

      m_initialized=true;

      Push(issx_telemetry_stage_system,"telemetry_init","telemetry_init",0.0,"",-1);
     }

   void Event(const string category,const string message)
     {
      Push(issx_telemetry_stage_system,category,message,0.0,"",-1);
     }

   void Checkpoint(const string name)
     {
      if(name==m_last_checkpoint)
         return;
      m_last_checkpoint=name;
      Push(issx_telemetry_stage_system,"checkpoint",name,0.0,"",-1);
     }

   void StageStart(const ISSX_TelemetryStageId stage_id)
     {
      if(!m_initialized)
         return;
      const int idx=StageIndex(stage_id);
      if(m_stage[idx].stage_begin_us>0 && m_stage[idx].last_stage_run=="RUNNING")
         return;
      m_stage[idx].last_stage_run="RUNNING";
      m_stage[idx].stage_begin_us=(ulong)GetMicrosecondCount();
      Push(stage_id,"stage_start","telemetry_stage_transition",0.0,"",-1);
     }

   void StageEnd(const ISSX_TelemetryStageId stage_id,const string status,const long elapsed_ms)
     {
      if(!m_initialized)
         return;
      const int idx=StageIndex(stage_id);
      if(m_stage[idx].stage_begin_us==0
         && m_last_stage_status[idx]==status
         && m_stage[idx].last_stage_elapsed_ms==elapsed_ms)
         return;
      m_stage[idx].last_stage_run=status;
      m_last_stage_status[idx]=status;
      m_stage[idx].last_stage_elapsed_ms=elapsed_ms;
      m_stage[idx].stage_begin_us=0;

      Push(stage_id,EventTypeFromStatus(status),"telemetry_stage_transition",(double)elapsed_ms,"",-1);
     }

   void StageReason(const ISSX_TelemetryStageId stage_id,const string reason)
     {
      if(!m_initialized)
         return;
      const int idx=StageIndex(stage_id);
      if(reason==m_last_stage_reason[idx])
         return;
      m_stage[idx].last_stage_reason=reason;
      m_last_stage_reason[idx]=reason;
      Push(stage_id,"error_context",reason,0.0,"",-1);
     }

   void Error(const ISSX_TelemetryStageId stage_id,const int code,const string message)
     {
      const int idx=StageIndex(stage_id);
      if(m_last_error_code[idx]==code && m_last_error_message[idx]==message)
         return;
      m_last_error_code[idx]=code;
      m_last_error_message[idx]=message;
      m_stage[idx].last_stage_run="ERROR";
      m_stage[idx].last_stage_reason=message;
      m_last_stage_reason[idx]=message;
      Push(stage_id,ErrorTypeFromCode(code,message),message,(double)code,"",-1);
     }

   void Metric(const string name,const double value)
     {
      Push(issx_telemetry_stage_system,name,"telemetry_metric_update",value,"",-1);
     }

   void SymbolProgress(const ISSX_TelemetryStageId stage_id,const string symbol)
     {
      Push(stage_id,"symbol_progress","symbol_progress",0.0,symbol,-1);
     }

   void BatchProgress(const ISSX_TelemetryStageId stage_id,const int processed,const int total)
     {
      const int idx=StageIndex(stage_id);
      m_stage[idx].symbols_processed=processed;
      m_stage[idx].symbols_total=total;
      m_stage[idx].symbols_cycle=(long)processed;
      m_stage[idx].batch_size=total;
      if(m_last_batch_processed[idx]==processed && m_last_batch_total[idx]==total)
         return;
      m_last_batch_processed[idx]=processed;
      m_last_batch_total[idx]=total;
      Push(stage_id,"batch_progress","batch_progress",(double)processed,"",(long)total);
     }

   void CursorPosition(const ISSX_TelemetryStageId stage_id,const int cursor,const int batch_size)
     {
      const int idx=StageIndex(stage_id);
      m_stage[idx].batch_cursor=cursor;
      m_stage[idx].batch_size=batch_size;
      if(m_last_batch_cursor[idx]==cursor && m_last_batch_total[idx]==batch_size)
         return;
      m_last_batch_cursor[idx]=cursor;
      m_last_batch_total[idx]=batch_size;
      Push(stage_id,"cursor_position","cursor_position",(double)cursor,"",(long)batch_size);
     }

   void Payload(const ISSX_TelemetryStageId stage_id,const int bytes)
     {
      const int idx=StageIndex(stage_id);
      if(m_last_payload_bytes[idx]==bytes)
         return;
      m_last_payload_bytes[idx]=bytes;
      m_stage[idx].payload_bytes=bytes;
      Push(stage_id,"json_payload_bytes","json_payload_bytes",(double)bytes,"",-1);
     }

   void MemoryEstimate(const ISSX_TelemetryStageId stage_id,const long bytes)
     {
      const int idx=StageIndex(stage_id);
      if(m_last_memory_bytes[idx]==bytes)
         return;
      m_last_memory_bytes[idx]=bytes;
      m_stage[idx].estimated_memory=bytes;
      Push(stage_id,"memory_estimate","memory_estimate",(double)bytes,"",-1);
      if(bytes>(64L*1024L*1024L))
         Push(stage_id,"allocation_warning","allocation_warning",(double)bytes,"",-1);
     }

   void ResetCycle()
     {
      if(!m_initialized)
         return;
      m_cycle_count++;
      for(int s=0;s<ISSX_TELEMETRY_STAGE_COUNT;s++)
        {
         m_stage[s].symbols_cycle=0;
         m_stage[s].copyrates_calls=0;
         m_stage[s].copyrates_bars=0;
        }
     }

   void BeginStage(const string stage)
     {
      StageStart(StageIdFromName(stage));
     }

   void EndStage(const string stage,const string status="READY")
     {
      const ISSX_TelemetryStageId stage_id=StageIdFromName(stage);
      const int idx=StageIndex(stage_id);
      long elapsed_ms=0;
      if(m_stage[idx].stage_begin_us>0)
         elapsed_ms=(long)(((ulong)GetMicrosecondCount()-m_stage[idx].stage_begin_us)/1000);
      StageEnd(stage_id,status,elapsed_ms);
     }

   void RecordSymbolProcessed(const string stage,const int count=1)
     {
      const int idx=StageIndex(StageIdFromName(stage));
      m_stage[idx].symbols_cycle+=MathMax(0,count);
      m_stage[idx].symbols_processed+=MathMax(0,count);
     }

   void RecordCopyRates(const int bars)
     {
      const int idx=StageIndex(issx_telemetry_stage_ea2_history);
      m_stage[idx].copyrates_calls++;
      m_stage[idx].copyrates_bars+=MathMax(0,bars);
      if((m_stage[idx].copyrates_calls-m_last_copyrates_reported_calls)>=32)
        {
         m_last_copyrates_reported_calls=m_stage[idx].copyrates_calls;
         Push(issx_telemetry_stage_ea2_history,"copyrates_pressure","copyrates_pressure",(double)m_stage[idx].copyrates_bars,"",-1);
        }
     }

   void RecordPayloadBytes(const string type,const int bytes)
     {
      Push(issx_telemetry_stage_system,"payload_bytes",type,(double)MathMax(0,bytes),"",-1);
     }

   void EstimateMemoryUsage(const string name,const int bytes)
     {
      Push(issx_telemetry_stage_system,"memory_estimate",name,(double)MathMax(0,bytes),"",-1);
     }

   void LogSampledSummary(const bool force=false)
     {
      if(!m_initialized)
         return;
      if(!force && ((m_cycle_count%10)!=1))
         return;
      const int ea1=StageIndex(issx_telemetry_stage_ea1_market);
      const int ea2=StageIndex(issx_telemetry_stage_ea2_history);
      const int ea5=StageIndex(issx_telemetry_stage_ea5_contracts);
      Print("[metrics] stage=ea1_market latency_ms=",(string)m_stage[ea1].last_stage_elapsed_ms,
            " symbols=",(string)m_stage[ea1].symbols_cycle);
      Print("[metrics] hydration symbols=",(string)m_stage[ea2].symbols_cycle,
            " copyrates_calls=",(string)m_stage[ea2].copyrates_calls,
            " copyrates_bars=",(string)m_stage[ea2].copyrates_bars);
      Print("[metrics] payload stage_json bytes=",(string)m_stage[ea5].payload_bytes,
            " memory_estimate=",(string)m_stage[ea5].estimated_memory);
     }

   void ArrayResizeEvent(const ISSX_TelemetryStageId stage_id,const int before_size,const int after_size)
     {
      Push(stage_id,"array_resize","array_resize",(double)after_size,"",(long)before_size);
     }

   void Flush()
     {
      Push(issx_telemetry_stage_system,"flush","telemetry_flush",(double)m_count,"",-1);
     }

   string LastStageRun(const ISSX_TelemetryStageId stage_id) const
     {
      return m_stage[StageIndex(stage_id)].last_stage_run;
     }

   string LastStageReason(const ISSX_TelemetryStageId stage_id) const
     {
      return m_stage[StageIndex(stage_id)].last_stage_reason;
     }

   long LastStageElapsedMs(const ISSX_TelemetryStageId stage_id) const
     {
      return m_stage[StageIndex(stage_id)].last_stage_elapsed_ms;
     }

   long SymbolsProcessed(const ISSX_TelemetryStageId stage_id) const
     {
      return m_stage[StageIndex(stage_id)].symbols_processed;
     }

   long SymbolsTotal(const ISSX_TelemetryStageId stage_id) const
     {
      return m_stage[StageIndex(stage_id)].symbols_total;
     }

   long BatchCursor(const ISSX_TelemetryStageId stage_id) const
     {
      return m_stage[StageIndex(stage_id)].batch_cursor;
     }

   long BatchSize(const ISSX_TelemetryStageId stage_id) const
     {
      return m_stage[StageIndex(stage_id)].batch_size;
     }

   long PayloadBytes(const ISSX_TelemetryStageId stage_id) const
     {
      return m_stage[StageIndex(stage_id)].payload_bytes;
     }

   long EstimatedMemory(const ISSX_TelemetryStageId stage_id) const
     {
      return m_stage[StageIndex(stage_id)].estimated_memory;
     }

   long EventCount() const
     {
      return m_count;
     }

   long DroppedEvents() const
     {
      return m_dropped_events;
     }

   string RecentEventSummary() const
     {
      if(m_count<=0)
         return "none";
      const int idx=(m_start+m_count-1)%ISSX_TELEMETRY_MAX_EVENTS;
      return m_events[idx].stage+"|"+m_events[idx].event_type+"|"+m_events[idx].message;
     }
  };

#endif // __ISSX_TELEMETRY_MQH__
