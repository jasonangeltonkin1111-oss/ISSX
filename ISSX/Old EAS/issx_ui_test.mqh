
#ifndef __ISSX_UI_TEST_MQH__
#define __ISSX_UI_TEST_MQH__
#include <ISSX/issx_core.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>
#include <ISSX/issx_market_engine.mqh>
#include <ISSX/issx_history_engine.mqh>
#include <ISSX/issx_selection_engine.mqh>
#include <ISSX/issx_correlation_engine.mqh>
#include <ISSX/issx_contracts.mqh>

// ============================================================================
// ISSX UI TEST v1.7.0
// Kernel HUD / structured traces / weak-link reporting / event-driven debug
// snapshots / aggregated debug summary / trace rate limiting.
//
// DESIGN RULES
// - debug must expose weak links early
// - debug must never become the bottleneck
// - HUD renders only from precomputed counters and stage state summaries
// - public debug is a projection, never authoritative truth
// - stage-local snapshots remain stage-specific and event-driven
// ============================================================================

#define ISSX_UI_TEST_MODULE_VERSION            "1.7.0"
#define ISSX_TRACE_DEFAULT_COOLDOWN_MS         15000
#define ISSX_TRACE_MAX_RECENT_KEYS             256
#define ISSX_DEBUG_MAX_WARNINGS                32
#define ISSX_DEBUG_MAX_TRACE_LINES             128
#define ISSX_HUD_MAX_ROWS                      8

enum ISSX_TraceSeverity
  {
   issx_trace_error = 0,
   issx_trace_warn,
   issx_trace_state_change,
   issx_trace_sampled_info
  };

enum ISSX_DebugSnapshotReason
  {
   issx_snapshot_reason_none = 0,
   issx_snapshot_reason_boot_restore,
   issx_snapshot_reason_publish_attempt,
   issx_snapshot_reason_acceptance_result,
   issx_snapshot_reason_dependency_block,
   issx_snapshot_reason_fallback_event,
   issx_snapshot_reason_queue_starvation,
   issx_snapshot_reason_rewrite_storm,
   issx_snapshot_reason_weak_link_change,
   issx_snapshot_reason_manual
  };

struct ISSX_TraceLine
  {
   ISSX_TraceSeverity severity;
   ISSX_StageId       stage_id;
   string             code;
   string             message;
   string             detail;
   long               mono_ms;
   int                minute_id;
   long               sequence_no;
   bool               rate_limited;

   void Reset()
     {
      severity=issx_trace_sampled_info;
      stage_id=issx_stage_unknown;
      code="";
      message="";
      detail="";
      mono_ms=0;
      minute_id=0;
      sequence_no=0;
      rate_limited=false;
     }
  };

struct ISSX_WeakLinkWeights
  {
   int error_weight;
   int degrade_weight;
   int dependency_weight;
   int fallback_weight;

   void Reset()
     {
      error_weight=0;
      degrade_weight=0;
      dependency_weight=0;
      fallback_weight=0;
     }
  };

struct ISSX_StageLadderRow
  {
   ISSX_StageId              stage_id;
   string                    publishability_state;
   long                      stage_last_publish_age;
   double                    stage_backlog_score;
   double                    stage_starvation_score;
   string                    dependency_block_reason;
   string                    phase_id;
   int                       phase_resume_count;
   string                    weak_link_code;
   long                      accepted_sequence_no;
   long                      last_attempted_age;
   long                      last_successful_service_age;
   int                       fallback_depth;
   bool                      minimum_ready_flag;
   bool                      publish_due_flag;
   string                    source_mode;

   void Reset()
     {
      stage_id=issx_stage_unknown;
      publishability_state="not_ready";
      stage_last_publish_age=0;
      stage_backlog_score=0.0;
      stage_starvation_score=0.0;
      dependency_block_reason="";
      phase_id="none";
      phase_resume_count=0;
      weak_link_code="none";
      accepted_sequence_no=0;
      last_attempted_age=0;
      last_successful_service_age=0;
      fallback_depth=0;
      minimum_ready_flag=false;
      publish_due_flag=false;
      source_mode="";
     }
  };

struct ISSX_HudWarning
  {
   ISSX_HudWarningSeverity severity;
   string code;
   string text;

   void Reset()
     {
      severity=issx_hud_warning_none;
      code="";
      text="";
     }
  };

struct ISSX_DebugAggregate
  {
   string                 firm_id;
   string                 engine_name;
   string                 engine_version;
   string                 weakest_stage;
   string                 weakest_stage_reason;
   int                    weak_link_severity;
   bool                   kernel_degraded_cycle_flag;
   long                   timer_gap_ms_now;
   double                 timer_gap_ms_mean;
   long                   timer_gap_ms_p95;
   long                   scheduler_late_by_ms;
   int                    missed_schedule_windows_estimate;
   double                 clock_divergence_sec;
   bool                   quote_clock_idle_flag;
   bool                   clock_anomaly_flag;
   int                    kernel_minute_id;
   long                   scheduler_cycle_no;
   long                   queue_starvation_max_ms;
   long                   queue_oldest_item_age_ms;
   int                    never_serviced_count;
   int                    overdue_service_count;
   int                    newly_active_symbols_waiting_count;
   int                    sector_cold_backlog_count;
   int                    frontier_refresh_lag_for_new_movers;
   int                    never_ranked_but_now_observable_count;
   string                 largest_backlog_owner;
   string                 oldest_unserved_queue_family;
   ISSX_StageLadderRow    stage_rows[];
   ISSX_HudWarning        warnings[];
   ISSX_TraceLine         traces[];

   void Reset()
     {
      firm_id="";
      engine_name=ISSX_ENGINE_NAME;
      engine_version=ISSX_SCHEMA_VERSION;
      weakest_stage="";
      weakest_stage_reason="";
      weak_link_severity=0;
      kernel_degraded_cycle_flag=false;
      timer_gap_ms_now=0;
      timer_gap_ms_mean=0.0;
      timer_gap_ms_p95=0;
      scheduler_late_by_ms=0;
      missed_schedule_windows_estimate=0;
      clock_divergence_sec=0.0;
      quote_clock_idle_flag=false;
      clock_anomaly_flag=false;
      kernel_minute_id=0;
      scheduler_cycle_no=0;
      queue_starvation_max_ms=0;
      queue_oldest_item_age_ms=0;
      never_serviced_count=0;
      overdue_service_count=0;
      newly_active_symbols_waiting_count=0;
      sector_cold_backlog_count=0;
      frontier_refresh_lag_for_new_movers=0;
      never_ranked_but_now_observable_count=0;
      largest_backlog_owner="";
      oldest_unserved_queue_family="";
      ArrayResize(stage_rows,0);
      ArrayResize(warnings,0);
      ArrayResize(traces,0);
     }
  };

struct ISSX_TraceCooldownEntry
  {
   string key;
   long   last_emit_mono_ms;
   int    emit_count;

   void Reset()
     {
      key="";
      last_emit_mono_ms=0;
      emit_count=0;
     }
  };

class ISSX_UI_Text
  {
public:
   static string TraceSeverityToString(const ISSX_TraceSeverity v)
     {
      switch(v)
        {
         case issx_trace_error: return "error";
         case issx_trace_warn: return "warn";
         case issx_trace_state_change: return "state_change";
         default: return "sampled_info";
        }
     }

   static string PublishabilityToString(const ISSX_PublishabilityState v)
     {
      switch(v)
        {
         case issx_publishability_warmup: return "warmup";
         case issx_publishability_usable_degraded: return "usable_degraded";
         case issx_publishability_usable: return "usable";
         case issx_publishability_strong: return "strong";
         default: return "not_ready";
        }
     }

   static string PhaseToString(const ISSX_PhaseId v)
     {
      return IntegerToString((int)v);
     }

   static string BoolFlag(const bool v)
     {
      return v ? "true" : "false";
     }

   static string WeakLinkToString(const ISSX_DebugWeakLinkCode v)
     {
      return ISSX_Enum::WeakLinkCodeToString(v);
     }
  };

class ISSX_UI_TraceLimiter
  {
private:
   ISSX_TraceCooldownEntry m_entries[];

   int Find(const string key) const
     {
      const int n=ArraySize(m_entries);
      for(int i=0;i<n;i++)
         if(m_entries[i].key==key)
            return i;
      return -1;
     }

public:
   void Reset()
     {
      ArrayResize(m_entries,0);
     }

   bool Allow(const string key,const long mono_ms,const int cooldown_ms)
     {
      int idx=Find(key);
      if(idx<0)
        {
         idx=ArraySize(m_entries);
         ArrayResize(m_entries,idx+1);
         m_entries[idx].Reset();
         m_entries[idx].key=key;
         m_entries[idx].last_emit_mono_ms=mono_ms;
         m_entries[idx].emit_count=1;
         if(ArraySize(m_entries)>ISSX_TRACE_MAX_RECENT_KEYS)
            ArrayRemove(m_entries,0);
         return true;
        }

      const long delta=(mono_ms-m_entries[idx].last_emit_mono_ms);
      if(delta<cooldown_ms)
         return false;

      m_entries[idx].last_emit_mono_ms=mono_ms;
      m_entries[idx].emit_count++;
      return true;
     }
  };

class ISSX_UI_Test
  {
private:
   static void AppendWarning(ISSX_DebugAggregate &agg,const ISSX_HudWarningSeverity severity,const string code,const string text)
     {
      if(ArraySize(agg.warnings)>=ISSX_DEBUG_MAX_WARNINGS)
         return;
      const int n=ArraySize(agg.warnings);
      ArrayResize(agg.warnings,n+1);
      agg.warnings[n].Reset();
      agg.warnings[n].severity=severity;
      agg.warnings[n].code=code;
      agg.warnings[n].text=text;
     }

   static void AppendTrace(ISSX_DebugAggregate &agg,const ISSX_TraceSeverity severity,const ISSX_StageId stage_id,const string code,const string message,const string detail,const long mono_ms,const int minute_id,const long sequence_no,const bool rate_limited=false)
     {
      if(ArraySize(agg.traces)>=ISSX_DEBUG_MAX_TRACE_LINES)
         return;
      const int n=ArraySize(agg.traces);
      ArrayResize(agg.traces,n+1);
      agg.traces[n].Reset();
      agg.traces[n].severity=severity;
      agg.traces[n].stage_id=stage_id;
      agg.traces[n].code=code;
      agg.traces[n].message=message;
      agg.traces[n].detail=detail;
      agg.traces[n].mono_ms=mono_ms;
      agg.traces[n].minute_id=minute_id;
      agg.traces[n].sequence_no=sequence_no;
      agg.traces[n].rate_limited=rate_limited;
     }

   static long SafeAge(const long now_ms,const long then_ms)
     {
      if(now_ms<=0 || then_ms<=0 || now_ms<then_ms)
         return 0;
      return now_ms-then_ms;
     }

   static void SetRowCommon(ISSX_StageLadderRow &row,const ISSX_StageId stage_id,const string publishability_state,const bool minimum_ready_flag,const string dependency_block_reason,const string weak_link_code,const long accepted_sequence_no,const int fallback_depth,const ISSX_RuntimeState &runtime)
     {
      row.Reset();
      row.stage_id=stage_id;
      row.publishability_state=publishability_state;
      row.minimum_ready_flag=minimum_ready_flag;
      row.dependency_block_reason=dependency_block_reason;
      row.weak_link_code=weak_link_code;
      row.accepted_sequence_no=accepted_sequence_no;
      row.fallback_depth=fallback_depth;
      row.stage_backlog_score=runtime.budgets.queue_backlog_score;
      row.stage_starvation_score=(double)runtime.budgets.budget_starvation_count;
      row.phase_id=ISSX_UI_Text::PhaseToString(runtime.scheduler.phase_id);
      row.phase_resume_count=runtime.scheduler.phase_resume_count;
      row.last_attempted_age=SafeAge((long)runtime.scheduler.phase_started_mono_ms,(long)runtime.scheduler.phase_started_mono_ms);
      row.last_successful_service_age=0;
      row.stage_last_publish_age=0;
      row.publish_due_flag=runtime.kernel.stage_publish_due_flag[(int)stage_id];
     }

   static string BuildHudText(const ISSX_DebugAggregate &agg)
     {
      string out="";
      out+="ISSX v"+agg.engine_version+"\n";
      out+="firm="+agg.firm_id+" minute="+IntegerToString(agg.kernel_minute_id)+" cycle="+IntegerToString((int)agg.scheduler_cycle_no)+"\n";
      out+="weakest_stage="+agg.weakest_stage+" severity="+IntegerToString(agg.weak_link_severity)+" reason="+agg.weakest_stage_reason+"\n";
      out+="timer_gap_ms_now="+IntegerToString((int)agg.timer_gap_ms_now)+", timer_gap_ms_p95="+IntegerToString((int)agg.timer_gap_ms_p95)+", scheduler_late_by_ms="+IntegerToString((int)agg.scheduler_late_by_ms)+"\n";
      out+="never_serviced="+IntegerToString(agg.never_serviced_count)+", overdue="+IntegerToString(agg.overdue_service_count)+", newly_active_waiting="+IntegerToString(agg.newly_active_symbols_waiting_count)+"\n";
      const int rows=ArraySize(agg.stage_rows);
      for(int i=0;i<rows;i++)
        {
         out+=ISSX_Stage::ToMachineId(agg.stage_rows[i].stage_id)+": ";
         out+="pub="+agg.stage_rows[i].publishability_state;
         out+=", backlog="+DoubleToString(agg.stage_rows[i].stage_backlog_score,2);
         out+=", starvation="+DoubleToString(agg.stage_rows[i].stage_starvation_score,2);
         out+=", dep="+agg.stage_rows[i].dependency_block_reason;
         out+=", weak="+agg.stage_rows[i].weak_link_code;
         out+=", seq="+IntegerToString((int)agg.stage_rows[i].accepted_sequence_no);
         out+=", fallback="+IntegerToString(agg.stage_rows[i].fallback_depth);
         out+="\n";
        }
      return out;
     }

   static string AggregateToJson(const ISSX_DebugAggregate &agg)
     {
      ISSX_JsonWriter js;
      js.Reset();
      js.BeginObject();

      js.WriteString("engine_name",agg.engine_name);
      js.WriteString("engine_version",agg.engine_version);
      js.WriteString("firm_id",agg.firm_id);
      js.WriteLong("kernel_minute_id",agg.kernel_minute_id);
      js.WriteLong("scheduler_cycle_no",agg.scheduler_cycle_no);
      js.WriteString("weakest_stage",agg.weakest_stage);
      js.WriteString("weakest_stage_reason",agg.weakest_stage_reason);
      js.WriteLong("weak_link_severity",agg.weak_link_severity);
      js.WriteBool("kernel_degraded_cycle_flag",agg.kernel_degraded_cycle_flag);
      js.WriteLong("timer_gap_ms_now",agg.timer_gap_ms_now);
      js.WriteDouble("timer_gap_ms_mean",agg.timer_gap_ms_mean,3);
      js.WriteLong("timer_gap_ms_p95",agg.timer_gap_ms_p95);
      js.WriteLong("scheduler_late_by_ms",agg.scheduler_late_by_ms);
      js.WriteLong("missed_schedule_windows_estimate",agg.missed_schedule_windows_estimate);
      js.WriteDouble("clock_divergence_sec",agg.clock_divergence_sec,3);
      js.WriteBool("quote_clock_idle_flag",agg.quote_clock_idle_flag);
      js.WriteBool("clock_anomaly_flag",agg.clock_anomaly_flag);
      js.WriteLong("queue_starvation_max_ms",agg.queue_starvation_max_ms);
      js.WriteLong("queue_oldest_item_age_ms",agg.queue_oldest_item_age_ms);
      js.WriteLong("never_serviced_count",agg.never_serviced_count);
      js.WriteLong("overdue_service_count",agg.overdue_service_count);
      js.WriteLong("newly_active_symbols_waiting_count",agg.newly_active_symbols_waiting_count);
      js.WriteLong("sector_cold_backlog_count",agg.sector_cold_backlog_count);
      js.WriteLong("frontier_refresh_lag_for_new_movers",agg.frontier_refresh_lag_for_new_movers);
      js.WriteLong("never_ranked_but_now_observable_count",agg.never_ranked_but_now_observable_count);
      js.WriteString("largest_backlog_owner",agg.largest_backlog_owner);
      js.WriteString("oldest_unserved_queue_family",agg.oldest_unserved_queue_family);
      js.WriteString("hud_text",BuildHudText(agg));

      js.BeginNamedArray("stage_ladder");
      for(int i=0;i<ArraySize(agg.stage_rows);i++)
        {
         js.BeginObject();
         js.WriteString("stage_id",ISSX_Stage::ToMachineId(agg.stage_rows[i].stage_id));
         js.WriteString("publishability_state",agg.stage_rows[i].publishability_state);
         js.WriteLong("stage_last_publish_age",agg.stage_rows[i].stage_last_publish_age);
         js.WriteDouble("stage_backlog_score",agg.stage_rows[i].stage_backlog_score,3);
         js.WriteDouble("stage_starvation_score",agg.stage_rows[i].stage_starvation_score,3);
         js.WriteString("dependency_block_reason",agg.stage_rows[i].dependency_block_reason);
         js.WriteString("phase_id",agg.stage_rows[i].phase_id);
         js.WriteLong("phase_resume_count",agg.stage_rows[i].phase_resume_count);
         js.WriteString("weak_link_code",agg.stage_rows[i].weak_link_code);
         js.WriteLong("accepted_sequence_no",agg.stage_rows[i].accepted_sequence_no);
         js.WriteLong("last_attempted_age",agg.stage_rows[i].last_attempted_age);
         js.WriteLong("last_successful_service_age",agg.stage_rows[i].last_successful_service_age);
         js.WriteLong("fallback_depth",agg.stage_rows[i].fallback_depth);
         js.WriteBool("stage_minimum_ready_flag",agg.stage_rows[i].minimum_ready_flag);
         js.WriteBool("stage_publish_due_flag",agg.stage_rows[i].publish_due_flag);
         js.WriteString("source_mode",agg.stage_rows[i].source_mode);
         js.EndObject();
        }
      js.EndArray();

      js.BeginNamedArray("warnings");
      for(int i=0;i<ArraySize(agg.warnings);i++)
        {
         js.BeginObject();
         js.WriteString("severity",IntegerToString((int)agg.warnings[i].severity));
         js.WriteString("code",agg.warnings[i].code);
         js.WriteString("text",agg.warnings[i].text);
         js.EndObject();
        }
      js.EndArray();

      js.BeginNamedArray("traces");
      for(int i=0;i<ArraySize(agg.traces);i++)
        {
         js.BeginObject();
         js.WriteString("severity",ISSX_UI_Text::TraceSeverityToString(agg.traces[i].severity));
         js.WriteString("stage_id",ISSX_Stage::ToMachineId(agg.traces[i].stage_id));
         js.WriteString("code",agg.traces[i].code);
         js.WriteString("message",agg.traces[i].message);
         js.WriteString("detail",agg.traces[i].detail);
         js.WriteLong("mono_ms",agg.traces[i].mono_ms);
         js.WriteLong("minute_id",agg.traces[i].minute_id);
         js.WriteLong("sequence_no",agg.traces[i].sequence_no);
         js.WriteBool("rate_limited",agg.traces[i].rate_limited);
         js.EndObject();
        }
      js.EndArray();

      js.EndObject();
      return js.ToString();
     }

public:
   static ISSX_StageLadderRow RowFromEA1(const ISSX_EA1_State &s)
     {
      ISSX_StageLadderRow row;
      SetRowCommon(row,issx_stage_ea1,s.stage_publishability_state,(s.stage_minimum_ready_flag=="true"),s.dependency_block_reason,s.debug_weak_link_code,(long)s.sequence_no,0,s.runtime_stats);
      row.source_mode="accepted_current";
      return row;
     }

   static ISSX_StageLadderRow RowFromEA2(const ISSX_EA2_State &s)
     {
      ISSX_StageLadderRow row;
      SetRowCommon(row,issx_stage_ea2,s.stage_publishability_state,s.stage_minimum_ready_flag,s.dependency_block_reason,s.debug_weak_link_code,(long)s.header.sequence_no,s.fallback_depth_used,s.runtime);
      row.source_mode=s.upstream_source_used;
      return row;
     }

   static ISSX_StageLadderRow RowFromEA3(const ISSX_EA3_State &s)
     {
      ISSX_StageLadderRow row;
      SetRowCommon(row,issx_stage_ea3,ISSX_UI_Text::PublishabilityToString(s.stage_publishability_state),s.stage_minimum_ready_flag,s.dependency_block_reason,ISSX_UI_Text::WeakLinkToString(s.debug_weak_link_code),(long)s.header.sequence_no,s.fallback_depth_used,s.runtime);
      row.source_mode=s.upstream_source_used;
      return row;
     }

   static ISSX_StageLadderRow RowFromEA4(const ISSX_EA4_State &s)
     {
      ISSX_StageLadderRow row;
      SetRowCommon(row,issx_stage_ea4,ISSX_UI_Text::PublishabilityToString(s.stage_publishability_state),s.stage_minimum_ready_flag,s.dependency_block_reason,ISSX_UI_Text::WeakLinkToString(s.debug_weak_link_code),(long)s.header.sequence_no,s.fallback_depth_used,s.runtime);
      row.source_mode=s.upstream_source_used;
      return row;
     }

   static ISSX_StageLadderRow RowFromEA5(const ISSX_EA5_State &s)
     {
      ISSX_StageLadderRow row;
      SetRowCommon(row,issx_stage_ea5,ISSX_UI_Text::PublishabilityToString(s.manifest.stage_publishability_state),s.manifest.stage_minimum_ready_flag,s.source_summary.degrade_reason,ISSX_UI_Text::WeakLinkToString(s.runtime.weak_link_code),(long)s.header.sequence_no,(int)s.manifest.fallback_depth_used,s.runtime);
      row.source_mode=IntegerToString((int)s.source_summary.upstream_handoff_mode);
      return row;
     }

   static void AttachStageRows(ISSX_DebugAggregate &agg,const ISSX_EA1_State &ea1,const ISSX_EA2_State &ea2,const ISSX_EA3_State &ea3,const ISSX_EA4_State &ea4,const ISSX_EA5_State &ea5)
     {
      ArrayResize(agg.stage_rows,5);
      agg.stage_rows[0]=RowFromEA1(ea1);
      agg.stage_rows[1]=RowFromEA2(ea2);
      agg.stage_rows[2]=RowFromEA3(ea3);
      agg.stage_rows[3]=RowFromEA4(ea4);
      agg.stage_rows[4]=RowFromEA5(ea5);
     }

   static ISSX_DebugAggregate BuildAggregate(const string firm_id,const ISSX_RuntimeState &runtime,const ISSX_EA1_State &ea1,const ISSX_EA2_State &ea2,const ISSX_EA3_State &ea3,const ISSX_EA4_State &ea4,const ISSX_EA5_State &ea5)
     {
      ISSX_DebugAggregate agg;
      agg.Reset();
      agg.firm_id=firm_id;
      agg.kernel_minute_id=(int)runtime.kernel.kernel_minute_id;
      agg.scheduler_cycle_no=runtime.kernel.scheduler_cycle_no;
      agg.weakest_stage=ISSX_Stage::ToMachineId(runtime.weakest_stage);
      agg.weakest_stage_reason=runtime.weakest_stage_reason;
      agg.weak_link_severity=runtime.weak_link_severity;
      agg.kernel_degraded_cycle_flag=runtime.budgets.degraded_cycle_flag;
      agg.timer_gap_ms_now=runtime.clock_stats.timer_gap_ms_now;
      agg.timer_gap_ms_mean=runtime.clock_stats.timer_gap_ms_mean;
      agg.timer_gap_ms_p95=runtime.clock_stats.timer_gap_ms_p95;
      agg.scheduler_late_by_ms=runtime.clock_stats.scheduler_late_by_ms;
      agg.missed_schedule_windows_estimate=runtime.clock_stats.missed_schedule_windows_estimate;
      agg.clock_divergence_sec=runtime.clock_stats.clock_divergence_sec;
      agg.quote_clock_idle_flag=runtime.clock_stats.quote_clock_idle_flag;
      agg.clock_anomaly_flag=runtime.clock_stats.clock_anomaly_flag;
      agg.queue_starvation_max_ms=runtime.queue_starvation_max_ms;
      agg.queue_oldest_item_age_ms=runtime.queue_oldest_item_age_ms;
      agg.never_serviced_count=runtime.coverage.never_serviced_count;
      agg.overdue_service_count=runtime.coverage.overdue_service_count;
      agg.newly_active_symbols_waiting_count=runtime.coverage.newly_active_symbols_waiting_count;
      agg.sector_cold_backlog_count=runtime.coverage.sector_cold_backlog_count;
      agg.frontier_refresh_lag_for_new_movers=runtime.coverage.frontier_refresh_lag_for_new_movers;
      agg.never_ranked_but_now_observable_count=runtime.coverage.never_ranked_but_now_observable_count;
      agg.largest_backlog_owner=ea5.largest_backlog_owner;
      agg.oldest_unserved_queue_family=ea5.oldest_unserved_queue_family;
      AttachStageRows(agg,ea1,ea2,ea3,ea4,ea5);

      if(runtime.clock_stats.clock_anomaly_flag)
         AppendWarning(agg,issx_hud_warning_warn,"clock_anomaly","Clock divergence/anomaly flag is active");
      if(runtime.coverage.never_serviced_count>0)
         AppendWarning(agg,issx_hud_warning_warn,"never_serviced","Some queue members have never been serviced");
      if(runtime.coverage.newly_active_symbols_waiting_count>0)
         AppendWarning(agg,issx_hud_warning_warn,"newly_active_waiting","Newly active symbols are waiting for service");
      if(runtime.weak_link_severity>0)
         AppendWarning(agg,issx_hud_warning_warn,"weak_link",runtime.weakest_stage_reason);
      if(ea5.why_publish_is_stale!="")
         AppendWarning(agg,issx_hud_warning_warn,"publish_stale",ea5.why_publish_is_stale);
      if(ea5.why_export_is_thin!="")
         AppendWarning(agg,issx_hud_warning_info,"thin_export",ea5.why_export_is_thin);

      AppendTrace(agg,issx_trace_state_change,issx_stage_shared,"boot_restore_result","debug aggregate built","boot restore result visible",0,agg.kernel_minute_id,0,false);
      if(runtime.coverage.overdue_service_count>0)
         AppendTrace(agg,issx_trace_warn,issx_stage_shared,"queue_starvation_event","queue starvation event","overdue service count elevated",0,agg.kernel_minute_id,0,false);
      if(ea4.dependency_block_reason!="")
         AppendTrace(agg,issx_trace_warn,issx_stage_ea4,"dependency_block_event","dependency block event",ea4.dependency_block_reason,0,agg.kernel_minute_id,ea4.header.sequence_no,false);
      if(ea2.degraded_flag)
         AppendTrace(agg,issx_trace_warn,issx_stage_ea2,"degrade_reason","degrade reason","history engine degraded",0,agg.kernel_minute_id,ea2.header.sequence_no,false);
      return agg;
     }

   static bool ProjectDebugRoot(const string firm_id,const ISSX_DebugAggregate &agg)
     {
      return ISSX_FileIO::WriteText(ISSX_PersistencePath::RootDebug(firm_id),AggregateToJson(agg));
     }

   static bool ProjectStageStatusRoot(const string firm_id,const ISSX_DebugAggregate &agg)
     {
      ISSX_JsonWriter js;
      js.Reset();
      js.BeginObject();
      js.BeginNamedArray("stage_status");
      for(int i=0;i<ArraySize(agg.stage_rows);i++)
        {
         js.BeginObject();
         js.WriteString("stage_id",ISSX_Stage::ToMachineId(agg.stage_rows[i].stage_id));
         js.WriteString("publishability_state",agg.stage_rows[i].publishability_state);
         js.WriteBool("stage_minimum_ready_flag",agg.stage_rows[i].minimum_ready_flag);
         js.WriteString("dependency_block_reason",agg.stage_rows[i].dependency_block_reason);
         js.WriteString("weak_link_code",agg.stage_rows[i].weak_link_code);
         js.WriteLong("accepted_sequence_no",agg.stage_rows[i].accepted_sequence_no);
         js.EndObject();
        }
      js.EndArray();
      js.EndObject();
      return ISSX_FileIO::WriteText(ISSX_PersistencePath::RootStageStatus(firm_id),js.ToString());
     }

   static bool ProjectUniverseSnapshotRoot(const string firm_id,const ISSX_RuntimeState &runtime)
     {
      ISSX_JsonWriter js;
      js.Reset();
      js.BeginObject();
      js.WriteDouble("percent_universe_touched_recent",runtime.coverage.percent_universe_touched_recent,3);
      js.WriteDouble("percent_rankable_revalidated_recent",runtime.coverage.percent_rankable_revalidated_recent,3);
      js.WriteDouble("percent_frontier_revalidated_recent",runtime.coverage.percent_frontier_revalidated_recent,3);
      js.WriteLong("never_serviced_count",runtime.coverage.never_serviced_count);
      js.WriteLong("overdue_service_count",runtime.coverage.overdue_service_count);
      js.WriteLong("newly_active_symbols_waiting_count",runtime.coverage.newly_active_symbols_waiting_count);
      js.WriteLong("sector_cold_backlog_count",runtime.coverage.sector_cold_backlog_count);
      js.WriteLong("frontier_refresh_lag_for_new_movers",runtime.coverage.frontier_refresh_lag_for_new_movers);
      js.EndObject();
      return ISSX_FileIO::WriteText(ISSX_PersistencePath::RootUniverseSnapshot(firm_id),js.ToString());
     }

   static bool ProjectStageSnapshot(const string firm_id,const ISSX_StageId stage_id,const string json_payload)
     {
      return ISSX_FileIO::WriteText(ISSX_PersistencePath::DebugSnapshot(firm_id,stage_id),json_payload);
     }

   static string BuildStageSnapshotEA1(const ISSX_EA1_State &s)
     {
      ISSX_JsonWriter js;
      js.Reset();
      js.BeginObject();
      js.WriteString("stage_id","ea1");
      js.WriteLong("sequence_no",s.sequence_no);
      js.WriteLong("minute_id",s.minute_id);
      js.WriteBool("degraded_flag",s.degraded_flag);
      js.WriteString("publishability_state",s.stage_publishability_state);
      js.WriteString("dependency_block_reason",s.dependency_block_reason);
      js.WriteString("debug_weak_link_code",s.debug_weak_link_code);
      js.WriteLong("changed_symbol_count",s.deltas.changed_symbol_count);
      js.EndObject();
      return js.ToString();
     }

   static string BuildStageSnapshotEA2(const ISSX_EA2_State &s)
     {
      ISSX_JsonWriter js;
      js.Reset();
      js.BeginObject();
      js.WriteString("stage_id","ea2");
      js.WriteLong("sequence_no",s.header.sequence_no);
      js.WriteBool("degraded_flag",s.degraded_flag);
      js.WriteBool("stage_minimum_ready_flag",s.stage_minimum_ready_flag);
      js.WriteString("publishability_state",s.stage_publishability_state);
      js.WriteString("dependency_block_reason",s.dependency_block_reason);
      js.WriteString("debug_weak_link_code",s.debug_weak_link_code);
      js.WriteLong("symbol_count",s.symbol_count);
      js.EndObject();
      return js.ToString();
     }

   static string BuildStageSnapshotEA3(const ISSX_EA3_State &s)
     {
      ISSX_JsonWriter js;
      js.Reset();
      js.BeginObject();
      js.WriteString("stage_id","ea3");
      js.WriteLong("sequence_no",s.header.sequence_no);
      js.WriteBool("degraded_flag",s.degraded_flag);
      js.WriteBool("stage_minimum_ready_flag",s.stage_minimum_ready_flag);
      js.WriteString("publishability_state",ISSX_UI_Text::PublishabilityToString(s.stage_publishability_state));
      js.WriteString("dependency_block_reason",s.dependency_block_reason);
      js.WriteString("debug_weak_link_code",ISSX_UI_Text::WeakLinkToString(s.debug_weak_link_code));
      js.WriteLong("frontier_count",ArraySize(s.frontier));
      js.EndObject();
      return js.ToString();
     }

   static string BuildStageSnapshotEA4(const ISSX_EA4_State &s)
     {
      ISSX_JsonWriter js;
      js.Reset();
      js.BeginObject();
      js.WriteString("stage_id","ea4");
      js.WriteLong("sequence_no",s.header.sequence_no);
      js.WriteBool("degraded_flag",s.degraded_flag);
      js.WriteBool("stage_minimum_ready_flag",s.stage_minimum_ready_flag);
      js.WriteString("publishability_state",ISSX_UI_Text::PublishabilityToString(s.stage_publishability_state));
      js.WriteString("dependency_block_reason",s.dependency_block_reason);
      js.WriteString("debug_weak_link_code",ISSX_UI_Text::WeakLinkToString(s.debug_weak_link_code));
      js.WriteLong("pair_cache_count",ArraySize(s.pair_cache));
      js.EndObject();
      return js.ToString();
     }

   static string BuildStageSnapshotEA5(const ISSX_EA5_State &s)
     {
      ISSX_JsonWriter js;
      js.Reset();
      js.BeginObject();
      js.WriteString("stage_id","ea5");
      js.WriteLong("sequence_no",s.header.sequence_no);
      js.WriteBool("degraded_flag",s.degraded_flag);
      js.WriteBool("projection_partial_success_flag",s.projection_partial_success_flag);
      js.WriteString("why_export_is_thin",s.why_export_is_thin);
      js.WriteString("why_publish_is_stale",s.why_publish_is_stale);
      js.WriteString("why_frontier_is_small",s.why_frontier_is_small);
      js.WriteString("why_intelligence_abstained",s.why_intelligence_abstained);
      js.WriteString("largest_backlog_owner",s.largest_backlog_owner);
      js.WriteString("oldest_unserved_queue_family",s.oldest_unserved_queue_family);
      js.EndObject();
      return js.ToString();
     }

   static bool ProjectAllStageSnapshots(const string firm_id,const ISSX_EA1_State &ea1,const ISSX_EA2_State &ea2,const ISSX_EA3_State &ea3,const ISSX_EA4_State &ea4,const ISSX_EA5_State &ea5)
     {
      bool ok=true;
      ok=(ProjectStageSnapshot(firm_id,issx_stage_ea1,BuildStageSnapshotEA1(ea1)) && ok);
      ok=(ProjectStageSnapshot(firm_id,issx_stage_ea2,BuildStageSnapshotEA2(ea2)) && ok);
      ok=(ProjectStageSnapshot(firm_id,issx_stage_ea3,BuildStageSnapshotEA3(ea3)) && ok);
      ok=(ProjectStageSnapshot(firm_id,issx_stage_ea4,BuildStageSnapshotEA4(ea4)) && ok);
      ok=(ProjectStageSnapshot(firm_id,issx_stage_ea5,BuildStageSnapshotEA5(ea5)) && ok);
      return ok;
     }
  };

#endif // __ISSX_UI_TEST_MQH__
