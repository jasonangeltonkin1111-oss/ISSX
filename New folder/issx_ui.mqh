#ifndef __ISSX_UI_MQH__
#define __ISSX_UI_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_market_engine.mqh>
#include <ISSX/issx_history_engine.mqh>
#include <ISSX/issx_selection_engine.mqh>
#include <ISSX/issx_correlation_engine.mqh>
#include <ISSX/issx_contracts.mqh>
#include <ISSX/issx_debug_engine.mqh>
#include <ISSX/issx_persistence.mqh>

#define ISSX_UI_MODULE_VERSION "1.734"
#define ISSX_UI_DEBUG_MODULE_VERSION ISSX_UI_MODULE_VERSION
#define ISSX_UI_TEST_MODULE_VERSION ISSX_UI_MODULE_VERSION
#define ISSX_HUD_PREFIX "ISSX_HUD_"
#define ISSX_HUD_MAIN_OBJECT "MAIN"

struct ISSX_HudForensics
  {
   int      objects_created;
   int      objects_updated;
   int      objects_skipped;
   datetime last_render_ts;

   void Reset()
     {
      objects_created=0;
      objects_updated=0;
      objects_skipped=0;
      last_render_ts=0;
     }
  };

class ISSX_UI
  {
private:
   ISSX_HudForensics m_fx;
   string            m_last_text;
   bool              m_initialized;

   string ObjName(const string suffix) { return string(ISSX_HUD_PREFIX)+suffix; }

   void ConfigureMainObject(const string name)
     {
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,12);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,18);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,name,OBJPROP_ZORDER,1000);
     }

   void Log(ISSX_DebugEngine &dbg,const string event_code,const string detail)
     {
      dbg.Write("INFO","hud",event_code,detail);
     }

   int CleanupByPrefix(const string prefix)
     {
      const int total=ObjectsTotal(0,-1,-1);
      int removed=0;
      for(int i=total-1;i>=0;i--)
        {
         string name=ObjectName(0,i,-1,-1);
         if(StringLen(name)<=0)
            continue;
         if(StringFind(name,prefix)!=0)
            continue;
         if(ObjectDelete(0,name))
            removed++;
        }
      return removed;
     }

   void EnsureMainObject(ISSX_DebugEngine &dbg)
     {
      string name=ObjName(ISSX_HUD_MAIN_OBJECT);
      if(ObjectFind(0,name)>=0)
        {
         m_fx.objects_skipped++;
         ConfigureMainObject(name);
         Log(dbg,"hud_object_skip_existing","name="+name);
         return;
        }
      ResetLastError();
      if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
        {
         Log(dbg,"hud_render_error","create_failed name="+name+" err="+IntegerToString((int)GetLastError()));
         return;
        }
      m_fx.objects_created++;
      Log(dbg,"hud_object_create","name="+name);
      ConfigureMainObject(name);
     }

public:
   void Init(ISSX_DebugEngine &dbg)
     {
      Log(dbg,"hud_init_start","prefix="+string(ISSX_HUD_PREFIX));
      m_fx.Reset();
      m_last_text="";
      Log(dbg,"hud_cleanup_start","prefix="+string(ISSX_HUD_PREFIX));
      const int removed=CleanupByPrefix(ISSX_HUD_PREFIX);
      Log(dbg,"hud_cleanup_complete","removed="+IntegerToString(removed));
      m_initialized=true;
      Log(dbg,"hud_init_complete","version="+string(ISSX_UI_MODULE_VERSION)+" ownership=canonical_issx_ui");
     }

   void Shutdown(ISSX_DebugEngine &dbg)
     {
      Log(dbg,"hud_cleanup_start","prefix="+string(ISSX_HUD_PREFIX));
      const int removed=CleanupByPrefix(ISSX_HUD_PREFIX);
      Log(dbg,"hud_cleanup_complete","removed="+IntegerToString(removed));
      m_initialized=false;
     }

   void Render(ISSX_DebugEngine &dbg,
               const string wrapper_version,
               const string boot_id,
               const string server_time_text,
               const ulong timer_pulse,
               const bool minimal_debug,
               const bool isolation_mode,
               const bool gate_runtime_scheduler,
               const bool gate_timer_heavy,
               const bool gate_tick_heavy,
               const bool gate_menu_engine,
               const bool gate_chart_ui_updates,
               const bool gate_ui_projection,
               const bool req_runtime_scheduler,
               const bool req_timer_heavy,
               const bool req_ui_projection,
               const bool req_ea1_enabled,
               const string startup_profile,
               const string scheduler_state,
               const string kernel_result,
               const string kernel_reason,
               const long kernel_elapsed_ms,
               const string broker,
               const string server,
               const long login_id,
               const bool &ea_enabled[],
               const ISSX_EA1_State &ea1,
               const ISSX_EA2_State &ea2,
               const ISSX_EA3_State &ea3,
               const ISSX_EA4_State &ea4,
               const ISSX_EA5_State &ea5,
               const string ea1_run,
               const string ea1_reason,
               const long ea1_elapsed_ms,
               const string ea1_publish_state,
               const string ea1_publish_reason,
               const string ea1_stage_json_state,
               const string ea1_debug_json_state,
               const string ea1_universe_build_state,
               const string ea1_stage_write_state,
               const string ea1_debug_write_state,
               const string ea1_universe_write_state,
               const string ea1_root_status_state,
               const string ea1_root_debug_state,
               const string ea2_run,
               const string ea2_reason,
               const long ea2_elapsed_ms,
               const string ea3_run,
               const string ea3_reason,
               const long ea3_elapsed_ms,
               const string ea4_run,
               const string ea4_reason,
               const long ea4_elapsed_ms,
               const string ea5_run,
               const string ea5_reason,
               const long ea5_elapsed_ms,
               const string last_cycle_status)
     {
      if(!m_initialized)
         Init(dbg);

      Log(dbg,"hud_render_cycle","pulse="+ISSX_Util::ULongToStringX(timer_pulse));
      EnsureMainObject(dbg);

      string text="ISSX SYSTEM STATUS\n";
      text+=" version="+wrapper_version+" ui="+string(ISSX_UI_MODULE_VERSION)+"\n";
      text+=" server_time="+server_time_text+" timer_pulse="+ISSX_Util::ULongToStringX(timer_pulse)+"\n";

      text+="SYSTEM STATE\n";
      text+=" minimal_debug_mode="+(minimal_debug?"on":"off")+" isolation_mode="+(isolation_mode?"on":"off")+" startup_profile="+startup_profile+"\n";
      text+=" runtime_scheduler=req:"+(req_runtime_scheduler?"on":"off")+" eff:"+(gate_runtime_scheduler?"on":"off")+" timer_heavy_work=req:"+(req_timer_heavy?"on":"off")+" eff:"+(gate_timer_heavy?"on":"off")+"\n";
      text+=" tick_heavy_work="+(gate_tick_heavy?"on":"off")+" menu_engine="+(gate_menu_engine?"on":"off")+" chart_ui_updates="+(gate_chart_ui_updates?"on":"off")+"\n";
      text+=" ui_projection=req:"+(req_ui_projection?"on":"off")+" eff:"+(gate_ui_projection?"on":"off")+" ea1_market=req:"+(req_ea1_enabled?"on":"off")+" eff:"+(ea_enabled[0]?"on":"off")+"\n";
      text+=" scheduler="+scheduler_state+" kernel="+kernel_result+" reason="+kernel_reason+" elapsed_ms="+IntegerToString((int)kernel_elapsed_ms)+"\n";
      text+=" boot="+boot_id+" broker="+broker+" server="+server+" login="+ISSX_Util::LongToStringX(login_id)+"\n";
      if(startup_profile=="invalid_contradictory")
         text+=" WARNING=invalid_contradictory_profile\n";

      text+="STAGE STATES\n";
      text+=" EA1 Market="+ea1.stage_publishability_state+" | run="+ea1_run+" | reason="+ea1_reason+" | elapsed_ms="+IntegerToString((int)ea1_elapsed_ms)+"\n";
      text+=" EA2 History="+ea2.stage_publishability_state+" | run="+ea2_run+" | reason="+ea2_reason+"\n";
      text+=" EA3 Selection="+ISSX_PublishabilityStateToString(ea3.stage_publishability_state)+" | run="+ea3_run+" | reason="+ea3_reason+"\n";
      text+=" EA4 Correlation="+ISSX_PublishabilityStateToString(ea4.stage_publishability_state)+" | run="+ea4_run+" | reason="+ea4_reason+"\n";
      text+=" EA5 Contracts="+ea5.debug_ready_state+" | run="+ea5_run+" | reason="+ea5_reason+"\n";

      text+="EA1 DETAIL\n";
      text+=" symbols_discovered="+IntegerToString(ea1.universe.broker_universe)+" active="+IntegerToString(ea1.universe.active_universe)+" publishable="+IntegerToString(ea1.universe.publishable_universe)+"\n";
      text+=" cadence_state="+ea1.discovery_status_reason+" discovery_minute_id="+IntegerToString(ea1.discovery_minute_id)+" last_discovery_elapsed_ms="+IntegerToString(ea1.discovery_elapsed_ms)+"\n";
      text+=" hydration_progress="+DoubleToString((ea1.hydration_total>0 ? (double)ea1.hydration_processed/(double)ea1.hydration_total : 0.0),4)+" hydration="+IntegerToString(ea1.hydration_processed)+"/"+IntegerToString(ea1.hydration_total)+" remaining="+IntegerToString(MathMax(0,ea1.hydration_total-ea1.hydration_processed))+" state="+(ea1.hydration_complete?"complete":"in_progress")+"\n";
      text+=" publish_state="+ea1_publish_state+" reason="+ea1_publish_reason+" checkpoint="+ea1.publish_last_checkpoint+" error="+ea1.publish_last_error+"\n";
      text+=" build:stage="+ea1_stage_json_state+" debug="+ea1_debug_json_state+" universe="+ea1_universe_build_state+"\n";
      text+=" write:stage="+ea1_stage_write_state+" debug="+ea1_debug_write_state+" universe="+ea1_universe_write_state+" root_status="+ea1_root_status_state+" root_debug="+ea1_root_debug_state+"\n";
      text+=" projection_state="+last_cycle_status+" fx:create="+IntegerToString(m_fx.objects_created)+" update="+IntegerToString(m_fx.objects_updated)+" skip="+IntegerToString(m_fx.objects_skipped)+"\n";
      const string obj=ObjName(ISSX_HUD_MAIN_OBJECT);
      if(text==m_last_text)
        {
         m_fx.objects_skipped++;
         Log(dbg,"hud_object_skip_existing","name="+obj+" reason=text_unchanged");
        }
      else
        {
         ResetLastError();
         if(ObjectSetString(0,obj,OBJPROP_TEXT,text))
           {
            m_fx.objects_updated++;
            Log(dbg,"hud_object_update","name="+obj);
            m_last_text=text;
            ChartRedraw(0);
           }
         else
            Log(dbg,"hud_render_error","update_failed name="+obj+" err="+IntegerToString((int)GetLastError()));
        }

      m_fx.last_render_ts=TimeCurrent();
      Log(dbg,"hud_update_cycle","created="+IntegerToString(m_fx.objects_created)+" updated="+IntegerToString(m_fx.objects_updated)+" skipped="+IntegerToString(m_fx.objects_skipped));
     }
  };


// ============================================================================
// ISSX UI DEBUG (merged into issx_ui.mqh)
// Kernel HUD / structured traces / weak-link reporting / event-driven debug
// snapshots / aggregated debug summary / trace rate limiting.
//
// DESIGN RULES
// - debug must expose weak links early
// - debug must never become the bottleneck
// - HUD renders only from precomputed counters and stage state summaries
// - public debug is a projection, never authoritative truth
// - stage-local snapshots remain stage-specific and event-driven
// - shared semantic enums remain core-owned
// - unknown / unavailable metrics must remain explicit and must not silently
//   masquerade as healthy, safe, or empty-good state
// ============================================================================

#define ISSX_TRACE_DEFAULT_COOLDOWN_MS         15000
#define ISSX_TRACE_MAX_RECENT_KEYS             256
#define ISSX_DEBUG_MAX_WARNINGS                32
#define ISSX_DEBUG_MAX_TRACE_LINES             128
#define ISSX_HUD_MAX_ROWS                      8
#define ISSX_DEBUG_UNKNOWN_COUNT               (-1)
#define ISSX_DEBUG_UNKNOWN_LONG                (-1)
#define ISSX_DEBUG_UNKNOWN_DOUBLE              (-1.0)

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
   long               minute_id;
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
   ISSX_StageId stage_id;
   string       publishability_state;
   long         stage_last_publish_age;
   double       stage_backlog_score;
   double       stage_starvation_score;
   string       dependency_block_reason;
   string       phase_id;
   int          phase_resume_count;
   string       weak_link_code;
   long         accepted_sequence_no;
   long         last_attempted_age;
   long         last_successful_service_age;
   int          fallback_depth;
   bool         minimum_ready_flag;
   bool         publish_due_flag;
   string       source_mode;

   void Reset()
     {
      stage_id=issx_stage_unknown;
      publishability_state="unknown";
      stage_last_publish_age=ISSX_DEBUG_UNKNOWN_LONG;
      stage_backlog_score=ISSX_DEBUG_UNKNOWN_DOUBLE;
      stage_starvation_score=ISSX_DEBUG_UNKNOWN_DOUBLE;
      dependency_block_reason="na";
      phase_id="na";
      phase_resume_count=0;
      weak_link_code="na";
      accepted_sequence_no=0;
      last_attempted_age=ISSX_DEBUG_UNKNOWN_LONG;
      last_successful_service_age=ISSX_DEBUG_UNKNOWN_LONG;
      fallback_depth=0;
      minimum_ready_flag=false;
      publish_due_flag=false;
      source_mode="na";
     }
  };

struct ISSX_HudWarning
  {
   ISSX_HudWarningSeverity severity;
   string                  code;
   string                  text;

   void Reset()
     {
      severity=issx_hud_warning_none;
      code="";
      text="";
     }
  };

struct ISSX_DebugAggregate
  {
   string              firm_id;
   string              engine_name;
   string              engine_version;
   string              weakest_stage;
   string              weakest_stage_reason;
   int                 weak_link_severity;
   bool                kernel_degraded_cycle_flag;
   long                timer_gap_ms_now;
   double              timer_gap_ms_mean;
   long                timer_gap_ms_p95;
   long                scheduler_late_by_ms;
   long                missed_schedule_windows_estimate;
   double              clock_divergence_sec;
   bool                quote_clock_idle_flag;
   bool                clock_anomaly_flag;
   datetime            server_time;
   long                kernel_minute_id;
   long                scheduler_cycle_no;
   long                queue_starvation_max_ms;
   long                queue_oldest_item_age_ms;
   long                never_serviced_count;
   long                overdue_service_count;
   long                newly_active_symbols_waiting_count;
   long                sector_cold_backlog_count;
   long                frontier_refresh_lag_for_new_movers;
   long                never_ranked_but_now_observable_count;
   string              largest_backlog_owner;
   string              oldest_unserved_queue_family;
   ISSX_StageLadderRow stage_rows[];
   ISSX_HudWarning     warnings[];
   ISSX_TraceLine      traces[];

   void Reset()
     {
      firm_id="";
      engine_name=ISSX_ENGINE_NAME;
      engine_version=ISSX_UI_TEST_MODULE_VERSION;
      weakest_stage="na";
      weakest_stage_reason="na";
      weak_link_severity=0;
      kernel_degraded_cycle_flag=false;
      timer_gap_ms_now=ISSX_DEBUG_UNKNOWN_LONG;
      timer_gap_ms_mean=ISSX_DEBUG_UNKNOWN_DOUBLE;
      timer_gap_ms_p95=ISSX_DEBUG_UNKNOWN_LONG;
      scheduler_late_by_ms=ISSX_DEBUG_UNKNOWN_LONG;
      missed_schedule_windows_estimate=ISSX_DEBUG_UNKNOWN_COUNT;
      clock_divergence_sec=ISSX_DEBUG_UNKNOWN_DOUBLE;
      quote_clock_idle_flag=false;
      clock_anomaly_flag=false;
      server_time=0;
      kernel_minute_id=0;
      scheduler_cycle_no=0;
      queue_starvation_max_ms=ISSX_DEBUG_UNKNOWN_LONG;
      queue_oldest_item_age_ms=ISSX_DEBUG_UNKNOWN_LONG;
      never_serviced_count=ISSX_DEBUG_UNKNOWN_COUNT;
      overdue_service_count=ISSX_DEBUG_UNKNOWN_COUNT;
      newly_active_symbols_waiting_count=ISSX_DEBUG_UNKNOWN_COUNT;
      sector_cold_backlog_count=ISSX_DEBUG_UNKNOWN_COUNT;
      frontier_refresh_lag_for_new_movers=ISSX_DEBUG_UNKNOWN_COUNT;
      never_ranked_but_now_observable_count=ISSX_DEBUG_UNKNOWN_COUNT;
      largest_backlog_owner="na";
      oldest_unserved_queue_family="na";
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
   static string TraceSeverityToString(const int v)
     {
      switch(v)
        {
         case issx_trace_error:         return "error";
         case issx_trace_warn:          return "warn";
         case issx_trace_state_change:  return "state_change";
         case issx_trace_sampled_info:  return "sampled_info";
         default:                       return "unknown";
        }
     }

   static string PublishabilityToString(const int v)
     {
      switch(v)
        {
         case issx_publishability_strong:
         case issx_publishability_usable:          return "publishable";
         case issx_publishability_usable_degraded: return "degraded";
         case issx_publishability_blocked:
         case issx_publishability_not_ready:
         case issx_publishability_warmup:          return "blocked";
         case issx_publishability_unknown:
         default:                                  return "unknown";
        }
     }

   static string StageIdToShortString(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return "ea1";
         case issx_stage_ea2: return "ea2";
         case issx_stage_ea3: return "ea3";
         case issx_stage_ea4: return "ea4";
         case issx_stage_ea5: return "ea5";
         case issx_stage_kernel:
         default:             return "na";
        }
     }

   static string BoolToWord(const bool v,const string yes_word="yes",const string no_word="no")
     {
      return (v ? yes_word : no_word);
     }

   static string LongToStringSafe(const long v,const string na_word="na")
     {
      return (v<0 ? na_word : LongToString(v));
     }

   static string DoubleToStringSafe(const double v,const int digits=2,const string na_word="na")
     {
      return (v<0.0 ? na_word : DoubleToString(v,digits));
     }

   static string NonEmptyOrNA(const string v,const string na_word="na")
     {
      return (ISSX_Util::IsEmpty(v) ? na_word : v);
     }
  };

class ISSX_UI_TraceLimiter
  {
private:
   ISSX_TraceCooldownEntry m_entries[];

   int FindKey(const string key) const
     {
      const int n=ArraySize(m_entries);
      for(int i=0;i<n;i++)
        {
         if(m_entries[i].key==key)
            return i;
        }
      return -1;
     }

   void PruneIfNeeded()
     {
      int n=ArraySize(m_entries);
      if(n<ISSX_TRACE_MAX_RECENT_KEYS)
         return;

      int remove_count=(n-ISSX_TRACE_MAX_RECENT_KEYS)+1;
      if(remove_count<1)
         remove_count=1;
      if(remove_count>n)
         remove_count=n;

      for(int i=0;i<remove_count;i++)
        {
         n=ArraySize(m_entries);
         for(int j=1;j<n;j++)
            m_entries[j-1]=m_entries[j];
         ArrayResize(m_entries,n-1);
        }
     }

public:
   void Reset()
     {
      ArrayResize(m_entries,0);
     }

   bool Allow(const string key,const long mono_ms,const long cooldown_ms)
     {
      if(cooldown_ms<=0)
         return true;

      const int idx=FindKey(key);
      if(idx<0)
        {
         ISSX_TraceCooldownEntry e;
         e.Reset();
         e.key=key;
         e.last_emit_mono_ms=mono_ms;
         e.emit_count=1;
         const int n=ArraySize(m_entries);
         ArrayResize(m_entries,n+1);
         m_entries[n]=e;
         PruneIfNeeded();
         return true;
        }

      long delta=mono_ms-m_entries[idx].last_emit_mono_ms;
      if(delta<0)
         delta=0;

      if(delta<cooldown_ms)
        {
         m_entries[idx].emit_count++;
         return false;
        }

      m_entries[idx].last_emit_mono_ms=mono_ms;
      m_entries[idx].emit_count++;
      return true;
     }
  };

class ISSX_UI_Test
  {
private:
   ISSX_UI_TraceLimiter m_trace_limiter;

   static long ValueOrUnknownLong(const long v)
     {
      return (v<0 ? ISSX_DEBUG_UNKNOWN_LONG : v);
     }

   static long ValueOrUnknownCount(const long v)
     {
      return (v<0 ? (long)ISSX_DEBUG_UNKNOWN_COUNT : v);
     }

   static double ValueOrUnknownDouble(const double v)
     {
      return (v<0.0 ? ISSX_DEBUG_UNKNOWN_DOUBLE : v);
     }

   static string ValueOrNA(const string v)
     {
      return ISSX_UI_Text::NonEmptyOrNA(v,"na");
     }

   static string StagePublishabilityWord(const int v)
     {
      switch(v)
        {
         case issx_publishability_strong:
         case issx_publishability_usable:          return "ready";
         case issx_publishability_usable_degraded: return "degraded";
         case issx_publishability_blocked:
         case issx_publishability_not_ready:
         case issx_publishability_warmup:          return "blocked";
         case issx_publishability_unknown:
         default:                                  return "unknown";
        }
     }

   static string StagePublishabilityWord(const string raw_state)
     {
      string v=raw_state;
      StringToLower(v);

      if(v=="strong" || v=="usable" || v=="publishable" || v=="ready" || v=="minimum_ready")
         return "ready";
      if(v=="usable_degraded" || v=="degraded_publishable" || v=="degraded")
         return "degraded";
      if(v=="blocked" || v=="not_ready" || v=="warmup")
         return "blocked";
      return "unknown";
     }

   static string WeakLinkCodeOrNA(const ISSX_DebugWeakLinkCode v)
     {
      return ISSX_UI_Text::NonEmptyOrNA(ISSX_DebugWeakLinkCodeToString(v),"na");
     }

   static long PublishAgeMsFromMinuteIds(const long current_minute_id,const long published_minute_id)
     {
      if(current_minute_id<=0 || published_minute_id<=0 || current_minute_id<published_minute_id)
         return ISSX_DEBUG_UNKNOWN_LONG;

      long delta_min=(current_minute_id-published_minute_id);
      if(delta_min<0)
         delta_min=0;

      if(delta_min>153722867280912L)
         return 9223372036854775807L;

      return delta_min*60000L;
     }

   static string WeakLinkCodeOrNA(const string v)
     {
      return ISSX_UI_Text::NonEmptyOrNA(v,"na");
     }

   static string DependencyReasonOrNA(const string v)
     {
      return ISSX_UI_Text::NonEmptyOrNA(v,"na");
     }

   static void PushWarning(ISSX_HudWarning &arr[],const ISSX_HudWarningSeverity severity,const string code,const string text)
     {
      const int n=ArraySize(arr);
      if(n>=ISSX_DEBUG_MAX_WARNINGS)
         return;
      ArrayResize(arr,n+1);
      arr[n].Reset();
      arr[n].severity=severity;
      arr[n].code=code;
      arr[n].text=text;
     }

   static void PushTrace(ISSX_TraceLine &arr[],const ISSX_TraceSeverity severity,const ISSX_StageId stage_id,
                         const string code,const string message,const string detail,
                         const long mono_ms,const long minute_id,const long sequence_no,
                         const bool rate_limited=false)
     {
      const int n=ArraySize(arr);
      if(n>=ISSX_DEBUG_MAX_TRACE_LINES)
         return;
      ArrayResize(arr,n+1);
      arr[n].Reset();
      arr[n].severity=severity;
      arr[n].stage_id=stage_id;
      arr[n].code=code;
      arr[n].message=message;
      arr[n].detail=detail;
      arr[n].mono_ms=mono_ms;
      arr[n].minute_id=minute_id;
      arr[n].sequence_no=sequence_no;
      arr[n].rate_limited=rate_limited;
     }

   static void AddStageWarningFromRow(ISSX_HudWarning &warnings[],const ISSX_StageLadderRow &row)
     {
      if(row.stage_id==issx_stage_unknown)
         return;

      const string stage_name=ISSX_UI_Text::StageIdToShortString(row.stage_id);

      if(row.publishability_state=="blocked")
         PushWarning(warnings,issx_hud_warning_error,stage_name+"_blocked",
                     stage_name+" publish blocked: "+row.dependency_block_reason);
      else if(row.publishability_state=="degraded")
         PushWarning(warnings,issx_hud_warning_warn,stage_name+"_degraded",
                     stage_name+" degraded: "+row.weak_link_code);

      if(row.stage_starvation_score>=0.0 && row.stage_starvation_score>=70.0)
         PushWarning(warnings,issx_hud_warning_warn,stage_name+"_starved",
                     stage_name+" starvation score elevated");

      if(row.fallback_depth>0)
         PushWarning(warnings,issx_hud_warning_warn,stage_name+"_fallback",
                     stage_name+" fallback depth "+IntegerToString(row.fallback_depth));
     }

   static string SnapshotReasonToString(const ISSX_DebugSnapshotReason reason)
     {
      switch(reason)
        {
         case issx_snapshot_reason_boot_restore:      return "boot_restore";
         case issx_snapshot_reason_publish_attempt:   return "publish_attempt";
         case issx_snapshot_reason_acceptance_result: return "acceptance_result";
         case issx_snapshot_reason_dependency_block:  return "dependency_block";
         case issx_snapshot_reason_fallback_event:    return "fallback_event";
         case issx_snapshot_reason_queue_starvation:  return "queue_starvation";
         case issx_snapshot_reason_rewrite_storm:     return "rewrite_storm";
         case issx_snapshot_reason_weak_link_change:  return "weak_link_change";
         case issx_snapshot_reason_manual:            return "manual";
         case issx_snapshot_reason_none:
         default:                                     return "none";
        }
     }

   static string BuildStageRowJson(const ISSX_StageLadderRow &row)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("stage_id",ISSX_UI_Text::StageIdToShortString(row.stage_id))+",";
      j+=ISSX_JsonWriter::NameStringKV("publishability_state",row.publishability_state)+",";
      j+=ISSX_JsonWriter::NameLongKV("stage_last_publish_age",row.stage_last_publish_age)+",";
      j+=ISSX_JsonWriter::NameDoubleKV("stage_backlog_score",row.stage_backlog_score,2)+",";
      j+=ISSX_JsonWriter::NameDoubleKV("stage_starvation_score",row.stage_starvation_score,2)+",";
      j+=ISSX_JsonWriter::NameStringKV("dependency_block_reason",row.dependency_block_reason)+",";
      j+=ISSX_JsonWriter::NameStringKV("phase_id",row.phase_id)+",";
      j+=ISSX_JsonWriter::NameIntKV("phase_resume_count",row.phase_resume_count)+",";
      j+=ISSX_JsonWriter::NameStringKV("weak_link_code",row.weak_link_code)+",";
      j+=ISSX_JsonWriter::NameLongKV("accepted_sequence_no",row.accepted_sequence_no)+",";
      j+=ISSX_JsonWriter::NameLongKV("last_attempted_age",row.last_attempted_age)+",";
      j+=ISSX_JsonWriter::NameLongKV("last_successful_service_age",row.last_successful_service_age)+",";
      j+=ISSX_JsonWriter::NameIntKV("fallback_depth",row.fallback_depth)+",";
      j+=ISSX_JsonWriter::NameBoolKV("minimum_ready_flag",row.minimum_ready_flag)+",";
      j+=ISSX_JsonWriter::NameBoolKV("publish_due_flag",row.publish_due_flag)+",";
      j+=ISSX_JsonWriter::NameStringKV("source_mode",row.source_mode);
      j+="}";
      return j;
     }

   static string BuildWarningJson(const ISSX_HudWarning &w)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("severity",ISSX_HudWarningSeverityToString(w.severity))+",";
      j+=ISSX_JsonWriter::NameStringKV("code",w.code)+",";
      j+=ISSX_JsonWriter::NameStringKV("text",w.text);
      j+="}";
      return j;
     }

   static string BuildTraceJson(const ISSX_TraceLine &t)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("severity",ISSX_UI_Text::TraceSeverityToString((int)t.severity))+",";
      j+=ISSX_JsonWriter::NameStringKV("stage_id",ISSX_UI_Text::StageIdToShortString(t.stage_id))+",";
      j+=ISSX_JsonWriter::NameStringKV("code",t.code)+",";
      j+=ISSX_JsonWriter::NameStringKV("message",t.message)+",";
      j+=ISSX_JsonWriter::NameStringKV("detail",t.detail)+",";
      j+=ISSX_JsonWriter::NameLongKV("mono_ms",t.mono_ms)+",";
      j+=ISSX_JsonWriter::NameLongKV("minute_id",t.minute_id)+",";
      j+=ISSX_JsonWriter::NameLongKV("sequence_no",t.sequence_no)+",";
      j+=ISSX_JsonWriter::NameBoolKV("rate_limited",t.rate_limited);
      j+="}";
      return j;
     }

   static string BuildAggregateJson(const ISSX_DebugAggregate &agg)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("engine_name",agg.engine_name)+",";
      j+=ISSX_JsonWriter::NameStringKV("engine_version",agg.engine_version)+",";
      j+=ISSX_JsonWriter::NameStringKV("firm_id",agg.firm_id)+",";
      j+=ISSX_JsonWriter::NameStringKV("weakest_stage",agg.weakest_stage)+",";
      j+=ISSX_JsonWriter::NameStringKV("weakest_stage_reason",agg.weakest_stage_reason)+",";
      j+=ISSX_JsonWriter::NameIntKV("weak_link_severity",agg.weak_link_severity)+",";
      j+=ISSX_JsonWriter::NameBoolKV("kernel_degraded_cycle_flag",agg.kernel_degraded_cycle_flag)+",";
      j+=ISSX_JsonWriter::NameLongKV("timer_gap_ms_now",agg.timer_gap_ms_now)+",";
      j+=ISSX_JsonWriter::NameDoubleKV("timer_gap_ms_mean",agg.timer_gap_ms_mean,2)+",";
      j+=ISSX_JsonWriter::NameLongKV("timer_gap_ms_p95",agg.timer_gap_ms_p95)+",";
      j+=ISSX_JsonWriter::NameLongKV("scheduler_late_by_ms",agg.scheduler_late_by_ms)+",";
      j+=ISSX_JsonWriter::NameLongKV("missed_schedule_windows_estimate",agg.missed_schedule_windows_estimate)+",";
      j+=ISSX_JsonWriter::NameDoubleKV("clock_divergence_sec",agg.clock_divergence_sec,2)+",";
      j+=ISSX_JsonWriter::NameBoolKV("quote_clock_idle_flag",agg.quote_clock_idle_flag)+",";
      j+=ISSX_JsonWriter::NameBoolKV("clock_anomaly_flag",agg.clock_anomaly_flag)+",";
      j+=ISSX_JsonWriter::NameLongKV("kernel_minute_id",agg.kernel_minute_id)+",";
      j+=ISSX_JsonWriter::NameLongKV("scheduler_cycle_no",agg.scheduler_cycle_no)+",";
      j+=ISSX_JsonWriter::NameLongKV("queue_starvation_max_ms",agg.queue_starvation_max_ms)+",";
      j+=ISSX_JsonWriter::NameLongKV("queue_oldest_item_age_ms",agg.queue_oldest_item_age_ms)+",";
      j+=ISSX_JsonWriter::NameLongKV("never_serviced_count",agg.never_serviced_count)+",";
      j+=ISSX_JsonWriter::NameLongKV("overdue_service_count",agg.overdue_service_count)+",";
      j+=ISSX_JsonWriter::NameLongKV("newly_active_symbols_waiting_count",agg.newly_active_symbols_waiting_count)+",";
      j+=ISSX_JsonWriter::NameLongKV("sector_cold_backlog_count",agg.sector_cold_backlog_count)+",";
      j+=ISSX_JsonWriter::NameLongKV("frontier_refresh_lag_for_new_movers",agg.frontier_refresh_lag_for_new_movers)+",";
      j+=ISSX_JsonWriter::NameLongKV("never_ranked_but_now_observable_count",agg.never_ranked_but_now_observable_count)+",";
      j+=ISSX_JsonWriter::NameStringKV("largest_backlog_owner",agg.largest_backlog_owner)+",";
      j+=ISSX_JsonWriter::NameStringKV("oldest_unserved_queue_family",agg.oldest_unserved_queue_family)+",";

      j+="\"stage_ladder\":[";
      const int stage_n=ArraySize(agg.stage_rows);
      for(int i=0;i<stage_n;i++)
        {
         if(i>0)
            j+=",";
         j+=BuildStageRowJson(agg.stage_rows[i]);
        }
      j+="],";

      j+="\"warnings\":[";
      const int warn_n=ArraySize(agg.warnings);
      for(int i=0;i<warn_n;i++)
        {
         if(i>0)
            j+=",";
         j+=BuildWarningJson(agg.warnings[i]);
        }
      j+="],";

      j+="\"traces\":[";
      const int trace_n=ArraySize(agg.traces);
      for(int i=0;i<trace_n;i++)
        {
         if(i>0)
            j+=",";
         j+=BuildTraceJson(agg.traces[i]);
        }
      j+="]";

      j+="}";
      return j;
     }

   static long NowMonoMs()
     {
      return (long)GetTickCount64();
     }

   static long AgeMsFrom(const long then_ms,const long now_ms)
     {
      if(then_ms<=0 || now_ms<=0)
         return ISSX_DEBUG_UNKNOWN_LONG;
      long d=now_ms-then_ms;
      if(d<0)
         d=0;
      return d;
     }

   static long AgeSecFromTime(const datetime t,const datetime now_time)
     {
      if(t<=0 || now_time<=0)
         return ISSX_DEBUG_UNKNOWN_LONG;
      long d=(long)(now_time-t);
      if(d<0)
         d=0;
      return d;
     }

   static int ClampWeakSeverity(const int v)
     {
      if(v<0)
         return 0;
      if(v>100)
         return 100;
      return v;
     }

   static int ComputeSeverityFromWeights(const ISSX_WeakLinkWeights &w)
     {
      int s=w.error_weight+w.degrade_weight+w.dependency_weight+w.fallback_weight;
      return ClampWeakSeverity(s);
     }

   static ISSX_WeakLinkWeights DeriveWeightsForRow(const ISSX_StageLadderRow &row)
     {
      ISSX_WeakLinkWeights w;
      w.Reset();

      if(row.publishability_state=="blocked")
         w.error_weight+=50;
      else if(row.publishability_state=="degraded")
         w.degrade_weight+=25;

      if(row.stage_starvation_score>=0.0)
        {
         if(row.stage_starvation_score>=90.0)
            w.dependency_weight+=25;
         else if(row.stage_starvation_score>=70.0)
            w.dependency_weight+=15;
        }

      if(row.fallback_depth>0)
         w.fallback_weight+=(10*MathMin(row.fallback_depth,3));

      if(row.dependency_block_reason!="na")
         w.dependency_weight+=10;

      return w;
     }

   static int FindWeakestStageIndex(const ISSX_StageLadderRow &rows[])
     {
      const int n=ArraySize(rows);
      if(n<=0)
         return -1;

      int best_idx=-1;
      int best_score=-1;
      for(int i=0;i<n;i++)
        {
         ISSX_WeakLinkWeights w=DeriveWeightsForRow(rows[i]);
         const int s=ComputeSeverityFromWeights(w);
         if(s>best_score)
           {
            best_score=s;
            best_idx=i;
           }
        }
      return best_idx;
     }

   static ISSX_StageLadderRow BuildStageKernelRow(const ISSX_RuntimeState &runtime_state,
                                                  const ISSX_StageId stage_id,
                                                  const long now_mono_ms)
     {
      ISSX_StageLadderRow row;
      row.Reset();
      row.stage_id=stage_id;

      const int idx=StageIdToIndex(stage_id);
      if(idx<0 || idx>=ISSX_STAGE_COUNT)
         return row;

      row.publishability_state="unknown";
      row.stage_last_publish_age=PublishAgeMsFromMinuteIds(runtime_state.kernel.kernel_minute_id,
                                                           runtime_state.kernel.stage_last_publish_minute_id[idx]);
      row.stage_backlog_score=ValueOrUnknownDouble(runtime_state.kernel.stage_backlog_score[idx]);
      row.stage_starvation_score=ValueOrUnknownDouble(runtime_state.kernel.stage_starvation_score[idx]);
      row.dependency_block_reason=DependencyReasonOrNA(runtime_state.kernel.stage_dependency_block_reason[idx]);
      row.phase_id=((runtime_state.scheduler.stage_slot==stage_id)
                    ? ValueOrNA(ISSX_Runtime::PhaseIdToString(runtime_state.scheduler.phase_id))
                    : "na");
      row.phase_resume_count=((runtime_state.scheduler.stage_slot==stage_id)
                              ? MathMax(0,runtime_state.scheduler.phase_resume_count)
                              : 0);
      row.weak_link_code=((runtime_state.weakest_stage==stage_id)
                          ? WeakLinkCodeOrNA(runtime_state.weak_link_code)
                          : "na");
      row.accepted_sequence_no=0;
      row.last_attempted_age=AgeMsFrom(runtime_state.kernel.stage_last_attempted_service_mono_ms[idx],now_mono_ms);
      row.last_successful_service_age=AgeMsFrom(runtime_state.kernel.stage_last_successful_service_mono_ms[idx],now_mono_ms);
      row.fallback_depth=0;
      row.minimum_ready_flag=runtime_state.kernel.stage_minimum_ready_flag[idx];
      row.publish_due_flag=runtime_state.kernel.stage_publish_due_flag[idx];
      row.source_mode="na";
      return row;
     }

   static ISSX_StageLadderRow BuildStageRowEA1(const ISSX_RuntimeState &runtime_state,
                                               const ISSX_EA1_State &ea1,
                                               const long now_mono_ms)
     {
      ISSX_StageLadderRow row=BuildStageKernelRow(runtime_state,issx_stage_ea1,now_mono_ms);
      row.publishability_state=StagePublishabilityWord(ea1.stage_publishability_state);
      row.dependency_block_reason=DependencyReasonOrNA(ea1.dependency_block_reason);
      row.weak_link_code=WeakLinkCodeOrNA(ea1.debug_weak_link_code);
      row.accepted_sequence_no=MathMax((long)0,(long)ea1.sequence_no);
      row.minimum_ready_flag=ea1.stage_minimum_ready_flag;
      row.source_mode="ea1_current";
      return row;
     }

   static ISSX_StageLadderRow BuildStageRowEA2(const ISSX_RuntimeState &runtime_state,
                                               const ISSX_EA2_State &ea2,
                                               const long now_mono_ms)
     {
      ISSX_StageLadderRow row=BuildStageKernelRow(runtime_state,issx_stage_ea2,now_mono_ms);
      row.publishability_state=StagePublishabilityWord(ea2.stage_publishability_state);
      row.dependency_block_reason=DependencyReasonOrNA(ea2.dependency_block_reason);
      row.weak_link_code=WeakLinkCodeOrNA(ea2.debug_weak_link_code);
      row.accepted_sequence_no=MathMax((long)0,(long)ea2.manifest.sequence_no);
      row.fallback_depth=MathMax(0,ea2.fallback_depth_used);
      row.minimum_ready_flag=ea2.stage_minimum_ready_flag;
      row.source_mode=ValueOrNA(ea2.upstream_source_used);
      return row;
     }

   static ISSX_StageLadderRow BuildStageRowEA3(const ISSX_RuntimeState &runtime_state,
                                               const ISSX_EA3_State &ea3,
                                               const long now_mono_ms)
     {
      ISSX_StageLadderRow row=BuildStageKernelRow(runtime_state,issx_stage_ea3,now_mono_ms);
      row.publishability_state=StagePublishabilityWord((int)ea3.stage_publishability_state);
      row.dependency_block_reason=DependencyReasonOrNA(ea3.dependency_block_reason);
      row.weak_link_code=WeakLinkCodeOrNA(ea3.debug_weak_link_code);
      row.accepted_sequence_no=MathMax((long)0,(long)ea3.manifest.sequence_no);
      row.fallback_depth=MathMax(0,ea3.fallback_depth_used);
      row.minimum_ready_flag=ea3.stage_minimum_ready_flag;
      row.source_mode=ValueOrNA(ea3.upstream_source_used);
      return row;
     }

   static ISSX_StageLadderRow BuildStageRowEA4(const ISSX_RuntimeState &runtime_state,
                                               const ISSX_EA4_State &ea4,
                                               const long now_mono_ms)
     {
      ISSX_StageLadderRow row=BuildStageKernelRow(runtime_state,issx_stage_ea4,now_mono_ms);
      row.publishability_state=StagePublishabilityWord((int)ea4.stage_publishability_state);
      row.dependency_block_reason=DependencyReasonOrNA(ea4.dependency_block_reason);
      row.weak_link_code=WeakLinkCodeOrNA(ea4.debug_weak_link_code);
      row.accepted_sequence_no=MathMax((long)0,(long)ea4.manifest.sequence_no);
      row.fallback_depth=MathMax(0,ea4.fallback_depth_used);
      row.minimum_ready_flag=ea4.stage_minimum_ready_flag;
      row.source_mode=ValueOrNA(ea4.upstream_source_used);
      return row;
     }

   static ISSX_StageLadderRow BuildStageRowEA5(const ISSX_RuntimeState &runtime_state,
                                               const ISSX_EA5_State &ea5,
                                               const long now_mono_ms)
     {
      ISSX_StageLadderRow row=BuildStageKernelRow(runtime_state,issx_stage_ea5,now_mono_ms);
      row.publishability_state=StagePublishabilityWord((int)ea5.market_readiness_summary.system_publishability_state);
      row.dependency_block_reason=ValueOrNA(ea5.why_export_is_thin);
      row.weak_link_code=((runtime_state.weakest_stage==issx_stage_ea5)
                          ? WeakLinkCodeOrNA(runtime_state.weak_link_code)
                          : "na");
      row.accepted_sequence_no=MathMax((long)0,(long)ea5.manifest.sequence_no);
      row.fallback_depth=MathMax(0,ea5.source_summary.max_fallback_depth_used);
      row.minimum_ready_flag=ea5.manifest.stage_minimum_ready_flag;
      row.source_mode=ISSX_UI_Text::NonEmptyOrNA(ea5.source_summary.ea3_source_used,"ea5_current");
      return row;
     }

   static void BuildStageRows(const ISSX_RuntimeState &runtime_state,
                              const ISSX_EA1_State &ea1,
                              const ISSX_EA2_State &ea2,
                              const ISSX_EA3_State &ea3,
                              const ISSX_EA4_State &ea4,
                              const ISSX_EA5_State &ea5,
                              ISSX_StageLadderRow &rows[])
     {
      ArrayResize(rows,0);
      const long now_mono_ms=NowMonoMs();

      ArrayResize(rows,5);
      rows[0]=BuildStageRowEA1(runtime_state,ea1,now_mono_ms);
      rows[1]=BuildStageRowEA2(runtime_state,ea2,now_mono_ms);
      rows[2]=BuildStageRowEA3(runtime_state,ea3,now_mono_ms);
      rows[3]=BuildStageRowEA4(runtime_state,ea4,now_mono_ms);
      rows[4]=BuildStageRowEA5(runtime_state,ea5,now_mono_ms);
     }

   static void BuildDefaultWarnings(const ISSX_DebugAggregate &agg,ISSX_HudWarning &warnings[])
     {
      ArrayResize(warnings,0);

      if(agg.kernel_degraded_cycle_flag)
         PushWarning(warnings,issx_hud_warning_warn,"kernel_degraded","kernel cycle degraded");

      if(agg.clock_anomaly_flag)
         PushWarning(warnings,issx_hud_warning_warn,"clock_anomaly","clock anomaly detected");

      if(agg.scheduler_late_by_ms>=0 && agg.scheduler_late_by_ms>5000)
         PushWarning(warnings,issx_hud_warning_warn,"scheduler_late","scheduler late beyond 5s");

      const int n=ArraySize(agg.stage_rows);
      for(int i=0;i<n;i++)
         AddStageWarningFromRow(warnings,agg.stage_rows[i]);
     }

   static void BuildDefaultTraces(const ISSX_DebugAggregate &agg,ISSX_TraceLine &traces[])
     {
      ArrayResize(traces,0);

      PushTrace(traces,issx_trace_state_change,issx_stage_kernel,"hud_refresh",
                "debug aggregate refreshed","",NowMonoMs(),agg.kernel_minute_id,agg.scheduler_cycle_no,false);

      if(agg.kernel_degraded_cycle_flag)
         PushTrace(traces,issx_trace_warn,issx_stage_kernel,"kernel_degraded",
                   "kernel running degraded cycle","",NowMonoMs(),agg.kernel_minute_id,agg.scheduler_cycle_no,false);

      const int n=ArraySize(agg.stage_rows);
      for(int i=0;i<n;i++)
        {
         const ISSX_StageLadderRow row=agg.stage_rows[i];
         if(row.publishability_state=="blocked")
            PushTrace(traces,issx_trace_error,row.stage_id,"dependency_block",
                      "stage blocked",row.dependency_block_reason,NowMonoMs(),agg.kernel_minute_id,row.accepted_sequence_no,false);
         else if(row.publishability_state=="degraded")
            PushTrace(traces,issx_trace_warn,row.stage_id,"stage_degraded",
                      "stage degraded",row.weak_link_code,NowMonoMs(),agg.kernel_minute_id,row.accepted_sequence_no,false);
        }
     }

   static void DetermineWeakestStage(ISSX_DebugAggregate &agg)
     {
      const int idx=FindWeakestStageIndex(agg.stage_rows);
      if(idx<0)
        {
         agg.weakest_stage="na";
         agg.weakest_stage_reason="na";
         agg.weak_link_severity=0;
         return;
        }

      const ISSX_StageLadderRow row=agg.stage_rows[idx];
      agg.weakest_stage=ISSX_UI_Text::StageIdToShortString(row.stage_id);
      if(row.publishability_state=="blocked")
         agg.weakest_stage_reason=ValueOrNA(row.dependency_block_reason);
      else if(row.publishability_state=="degraded")
         agg.weakest_stage_reason=ValueOrNA(row.weak_link_code);
      else
         agg.weakest_stage_reason="backlog";
      agg.weak_link_severity=ComputeSeverityFromWeights(DeriveWeightsForRow(row));
     }


   static string StageLongName(const ISSX_StageId stage_id)
     {
      if(stage_id==issx_stage_ea1) return "MarketStateCore";
      if(stage_id==issx_stage_ea2) return "HistoryStateCore";
      if(stage_id==issx_stage_ea3) return "SelectionCore";
      if(stage_id==issx_stage_ea4) return "IntelligenceCore";
      if(stage_id==issx_stage_ea5) return "ConsolidationCore";
      return ISSX_UI_Text::StageIdToShortString(stage_id);
     }

   static string BuildHudIdentityRow(const ISSX_DebugAggregate &agg)
     {
      return "ISSX SYSTEM STATUS | engine="+agg.engine_name+" v"+agg.engine_version+" | firm="+ISSX_UI_Text::NonEmptyOrNA(agg.firm_id,"na");
     }

   static string BuildHudRuntimeRow(const ISSX_DebugAggregate &agg)
     {
      string s="version="+agg.engine_version;
      s+=" | server_time="+((agg.server_time>0)
                            ? TimeToString(agg.server_time,TIME_DATE|TIME_SECONDS)
                            : "na");
      s+=" | timer_pulse="+LongToString(agg.scheduler_cycle_no);
      s+=" | kernel_minute="+LongToString(agg.kernel_minute_id);
      s+=" | degraded="+ISSX_UI_Text::BoolToWord(agg.kernel_degraded_cycle_flag);
      return s;
     }

   static string BuildHudStageRow(const ISSX_StageLadderRow &row)
     {
      string s=StageLongName(row.stage_id)+" ("+ISSX_UI_Text::StageIdToShortString(row.stage_id)+")";
      s+=" | pub="+row.publishability_state;
      s+=" | backlog="+ISSX_UI_Text::DoubleToStringSafe(row.stage_backlog_score,1);
      s+=" | starve="+ISSX_UI_Text::DoubleToStringSafe(row.stage_starvation_score,1);
      s+=" | last_pub_ms="+ISSX_UI_Text::LongToStringSafe(row.stage_last_publish_age);
      s+=" | dep="+ValueOrNA(row.dependency_block_reason);
      return s;
     }

   static string BuildHudWeakLinksRow(const ISSX_DebugAggregate &agg)
     {
      string s="WeakLinks | weakest="+ISSX_UI_Text::NonEmptyOrNA(agg.weakest_stage,"na");
      s+=" reason="+ISSX_UI_Text::NonEmptyOrNA(agg.weakest_stage_reason,"na");
      s+=" severity="+IntegerToString(agg.weak_link_severity);
      return s;
     }

   static string BuildHudQueuesRow(const ISSX_DebugAggregate &agg)
     {
      string s="Queues | oldest_family="+ISSX_UI_Text::NonEmptyOrNA(agg.oldest_unserved_queue_family,"na");
      s+=" backlog_owner="+ISSX_UI_Text::NonEmptyOrNA(agg.largest_backlog_owner,"na");
      s+=" oldest_age_ms="+ISSX_UI_Text::LongToStringSafe(agg.queue_oldest_item_age_ms);
      s+=" starvation_max_ms="+ISSX_UI_Text::LongToStringSafe(agg.queue_starvation_max_ms);
      return s;
     }

   static string BuildHudWarningsRow(const ISSX_HudWarning &warnings[])
     {
      string s="Warnings | ";
      const int n=ArraySize(warnings);
      if(n<=0)
         return s+"none";
      const int max_show=MathMin(n,3);
      for(int i=0;i<max_show;i++)
        {
         if(i>0)
            s+=" ; ";
         s+=warnings[i].code;
        }
      return s;
     }

public:
   ISSX_UI_Test()
     {
      m_trace_limiter.Reset();
     }

   void Reset()
     {
      m_trace_limiter.Reset();
     }

   bool AllowTrace(const string code,const long mono_ms,const long cooldown_ms=ISSX_TRACE_DEFAULT_COOLDOWN_MS)
     {
      return m_trace_limiter.Allow(code,mono_ms,cooldown_ms);
     }

   static ISSX_DebugAggregate BuildAggregate(const string firm_id,
                                           const ISSX_RuntimeState &runtime_state,
                                           const ISSX_EA1_State &ea1,
                                           const ISSX_EA2_State &ea2,
                                           const ISSX_EA3_State &ea3,
                                           const ISSX_EA4_State &ea4,
                                           const ISSX_EA5_State &ea5)
     {
      ISSX_DebugAggregate agg;
      agg.Reset();
      agg.firm_id=firm_id;

      agg.kernel_degraded_cycle_flag=runtime_state.kernel.kernel_degraded_cycle_flag;
      agg.kernel_minute_id=runtime_state.kernel.kernel_minute_id;
      agg.scheduler_cycle_no=runtime_state.scheduler_cycle_no;
      agg.timer_gap_ms_now=ValueOrUnknownLong(runtime_state.clock_stats.timer_gap_ms_now);
      agg.timer_gap_ms_mean=ValueOrUnknownDouble(runtime_state.clock_stats.timer_gap_ms_mean);
      agg.timer_gap_ms_p95=ValueOrUnknownLong(runtime_state.clock_stats.timer_gap_ms_p95);
      agg.scheduler_late_by_ms=ValueOrUnknownLong(runtime_state.clock_stats.scheduler_late_by_ms);
      agg.missed_schedule_windows_estimate=ValueOrUnknownCount(runtime_state.clock_stats.missed_schedule_windows_estimate);
      agg.clock_divergence_sec=ValueOrUnknownDouble(runtime_state.clock_stats.clock_divergence_sec);
      agg.quote_clock_idle_flag=runtime_state.clock_stats.quote_clock_idle_flag;
      agg.clock_anomaly_flag=runtime_state.clock_stats.clock_anomaly_flag;
      agg.server_time=ISSX_Time::BestScheduleClock();
      agg.queue_starvation_max_ms=ValueOrUnknownLong(runtime_state.queue_starvation_max_ms);
      agg.queue_oldest_item_age_ms=ValueOrUnknownLong(runtime_state.queue_oldest_item_age_ms);
      agg.never_serviced_count=ValueOrUnknownCount(ea3.universe.never_serviced_count);
      agg.overdue_service_count=ValueOrUnknownCount(ea3.universe.overdue_service_count);
      agg.newly_active_symbols_waiting_count=ValueOrUnknownCount(ea3.universe.newly_active_symbols_waiting_count);
      agg.sector_cold_backlog_count=(long)ISSX_DEBUG_UNKNOWN_COUNT;
      agg.frontier_refresh_lag_for_new_movers=(long)ISSX_DEBUG_UNKNOWN_COUNT;
      agg.never_ranked_but_now_observable_count=(long)ISSX_DEBUG_UNKNOWN_COUNT;
      agg.largest_backlog_owner=ValueOrNA(ea5.largest_backlog_owner);
      agg.oldest_unserved_queue_family=ValueOrNA(ea5.oldest_unserved_queue_family);

      BuildStageRows(runtime_state,ea1,ea2,ea3,ea4,ea5,agg.stage_rows);
      DetermineWeakestStage(agg);
      BuildDefaultWarnings(agg,agg.warnings);
      BuildDefaultTraces(agg,agg.traces);

      return agg;
     }

   static ISSX_DebugAggregate BuildAggregate(const string firm_id,const ISSX_RuntimeState &runtime_state)
     {
      ISSX_DebugAggregate agg;
      agg.Reset();
      agg.firm_id=firm_id;
      agg.kernel_degraded_cycle_flag=runtime_state.kernel.kernel_degraded_cycle_flag;
      agg.kernel_minute_id=runtime_state.kernel.kernel_minute_id;
      agg.scheduler_cycle_no=runtime_state.scheduler_cycle_no;
      agg.timer_gap_ms_now=ValueOrUnknownLong(runtime_state.clock_stats.timer_gap_ms_now);
      agg.timer_gap_ms_mean=ValueOrUnknownDouble(runtime_state.clock_stats.timer_gap_ms_mean);
      agg.timer_gap_ms_p95=ValueOrUnknownLong(runtime_state.clock_stats.timer_gap_ms_p95);
      agg.scheduler_late_by_ms=ValueOrUnknownLong(runtime_state.clock_stats.scheduler_late_by_ms);
      agg.missed_schedule_windows_estimate=ValueOrUnknownCount(runtime_state.clock_stats.missed_schedule_windows_estimate);
      agg.clock_divergence_sec=ValueOrUnknownDouble(runtime_state.clock_stats.clock_divergence_sec);
      agg.quote_clock_idle_flag=runtime_state.clock_stats.quote_clock_idle_flag;
      agg.clock_anomaly_flag=runtime_state.clock_stats.clock_anomaly_flag;
      agg.server_time=ISSX_Time::BestScheduleClock();
      agg.queue_starvation_max_ms=ValueOrUnknownLong(runtime_state.queue_starvation_max_ms);
      agg.queue_oldest_item_age_ms=ValueOrUnknownLong(runtime_state.queue_oldest_item_age_ms);
      agg.never_serviced_count=(long)ISSX_DEBUG_UNKNOWN_COUNT;
      agg.overdue_service_count=(long)ISSX_DEBUG_UNKNOWN_COUNT;
      agg.newly_active_symbols_waiting_count=(long)ISSX_DEBUG_UNKNOWN_COUNT;
      agg.sector_cold_backlog_count=(long)ISSX_DEBUG_UNKNOWN_COUNT;
      agg.frontier_refresh_lag_for_new_movers=(long)ISSX_DEBUG_UNKNOWN_COUNT;
      agg.never_ranked_but_now_observable_count=(long)ISSX_DEBUG_UNKNOWN_COUNT;
      agg.largest_backlog_owner="na";
      agg.oldest_unserved_queue_family="na";

      DetermineWeakestStage(agg);
      BuildDefaultWarnings(agg,agg.warnings);
      BuildDefaultTraces(agg,agg.traces);

      return agg;
     }

   static string BuildDebugJson(const ISSX_DebugAggregate &agg)
     {
      return BuildAggregateJson(agg);
     }

   static string BuildHudText(const ISSX_DebugAggregate &agg)
     {
      string lines[];
      ArrayResize(lines,0);

      int n=ArraySize(lines); ArrayResize(lines,n+1); lines[n]=BuildHudIdentityRow(agg);
      n=ArraySize(lines); ArrayResize(lines,n+1); lines[n]=BuildHudRuntimeRow(agg);

      n=ArraySize(lines); ArrayResize(lines,n+1); lines[n]="SYSTEM STATE | minimal_debug_mode=na isolation_mode=na runtime_scheduler=na timer_heavy_work=na tick_heavy_work=na";
      n=ArraySize(lines); ArrayResize(lines,n+1); lines[n]="SYSTEM STATE | menu_engine=na chart_ui_updates=na ui_projection=na";

      n=ArraySize(lines); ArrayResize(lines,n+1); lines[n]="STAGE STATES";
      const int stage_n=ArraySize(agg.stage_rows);
      for(int i=0;i<stage_n && i<5;i++)
        {
         const ISSX_StageLadderRow row=agg.stage_rows[i];
         n=ArraySize(lines); ArrayResize(lines,n+1);
         lines[n]=" "+StageLongName(row.stage_id)+" | pub="+row.publishability_state+" | dep="+ValueOrNA(row.dependency_block_reason);
        }

      n=ArraySize(lines); ArrayResize(lines,n+1); lines[n]="EA1 DETAIL";
      for(int i=0;i<stage_n && i<5;i++)
        {
         const ISSX_StageLadderRow row=agg.stage_rows[i];
         if(row.stage_id!=issx_stage_ea1)
            continue;
         n=ArraySize(lines); ArrayResize(lines,n+1);
         lines[n]=" symbols_discovered=na cadence_state="+row.phase_id+" last_discovery_time=na";
         n=ArraySize(lines); ArrayResize(lines,n+1);
         lines[n]=" publish_state="+row.publishability_state+" projection_state="+row.source_mode;
         break;
        }

      n=ArraySize(lines); ArrayResize(lines,n+1); lines[n]=BuildHudQueuesRow(agg);
      n=ArraySize(lines); ArrayResize(lines,n+1); lines[n]=BuildHudWeakLinksRow(agg);
      n=ArraySize(lines); ArrayResize(lines,n+1); lines[n]=BuildHudWarningsRow(agg.warnings);

      string out="";
      const int total=ArraySize(lines);
      for(int i=0;i<total;i++)
        {
         if(i>0)
            out+="\n";
         out+=lines[i];
        }
      return out;
     }

   static bool ProjectDebugJson(const string firm_id,const ISSX_DebugAggregate &agg)
     {
      const string path=ISSX_PersistencePath::DebugRootFile(firm_id);
      return ISSX_FileIO::WriteAllTextUtf8(path,BuildDebugJson(agg));
     }

   static bool ProjectHudText(const string firm_id,const ISSX_DebugAggregate &agg)
     {
      const string path=ISSX_PersistencePath::HudTextFile(firm_id);
      return ISSX_FileIO::WriteAllTextUtf8(path,BuildHudText(agg));
     }

   bool EmitTraceLine(const string firm_id,const ISSX_TraceLine &line) const
     {
      string path=ISSX_PersistencePath::DebugFolder(firm_id)+"issx_trace.log";
      string existing="";
      ISSX_FileIO::ReadAllTextUtf8(path,existing);

      string row=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
      row+=" | sev="+ISSX_UI_Text::TraceSeverityToString((int)line.severity);
      row+=" | stage="+ISSX_UI_Text::StageIdToShortString(line.stage_id);
      row+=" | code="+line.code;
      row+=" | msg="+line.message;
      if(!ISSX_Util::IsEmpty(line.detail))
         row+=" | detail="+line.detail;
      row+=" | minute="+LongToString(line.minute_id);
      row+=" | seq="+LongToString(line.sequence_no);

      if(!ISSX_Util::IsEmpty(existing))
         existing+="\n";
      existing+=row;
      return ISSX_FileIO::WriteAllTextUtf8(path,existing);
     }

   bool EmitStructuredTrace(const string firm_id,const ISSX_TraceSeverity severity,const ISSX_StageId stage_id,
                            const string code,const string message,const string detail="",
                            const long sequence_no=0,const long cooldown_ms=ISSX_TRACE_DEFAULT_COOLDOWN_MS)
     {
      const long mono_ms=NowMonoMs();
      const bool allowed=AllowTrace(code+"|"+ISSX_UI_Text::StageIdToShortString(stage_id),mono_ms,cooldown_ms);

      ISSX_TraceLine line;
      line.Reset();
      line.severity=severity;
      line.stage_id=stage_id;
      line.code=code;
      line.message=message;
      line.detail=detail;
      line.mono_ms=mono_ms;
      line.minute_id=0;
      line.sequence_no=sequence_no;
      line.rate_limited=!allowed;

      if(!allowed)
         return true;

      return EmitTraceLine(firm_id,line);
     }

   static string BuildStageSnapshotEA1(const ISSX_EA1_State &ea1)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("stage_id","ea1")+",";
      j+=ISSX_JsonWriter::NameStringKV("publishability_state",StagePublishabilityWord(ea1.stage_publishability_state))+",";
      j+=ISSX_JsonWriter::NameBoolKV("stage_minimum_ready_flag",ea1.stage_minimum_ready_flag)+",";
      j+=ISSX_JsonWriter::NameStringKV("dependency_block_reason",ValueOrNA(ea1.dependency_block_reason))+",";
      j+=ISSX_JsonWriter::NameLongKV("accepted_sequence_no",(long)ea1.sequence_no)+",";
      j+=ISSX_JsonWriter::NameIntKV("changed_symbol_count",ea1.deltas.changed_symbol_count)+",";
      j+=ISSX_JsonWriter::NameStringKV("broker_universe_fingerprint",ValueOrNA(ea1.universe.broker_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameStringKV("eligible_universe_fingerprint",ValueOrNA(ea1.universe.eligible_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameStringKV("active_universe_fingerprint",ValueOrNA(ea1.universe.active_universe_fingerprint));
      j+="}";
      return j;
     }

   static string BuildStageSnapshotEA2(const ISSX_EA2_State &ea2)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("stage_id","ea2")+",";
      j+=ISSX_JsonWriter::NameStringKV("publishability_state",StagePublishabilityWord(ea2.stage_publishability_state))+",";
      j+=ISSX_JsonWriter::NameBoolKV("stage_minimum_ready_flag",ea2.stage_minimum_ready_flag)+",";
      j+=ISSX_JsonWriter::NameStringKV("dependency_block_reason",ValueOrNA(ea2.dependency_block_reason))+",";
      j+=ISSX_JsonWriter::NameLongKV("accepted_sequence_no",(long)ea2.manifest.sequence_no)+",";
      j+=ISSX_JsonWriter::NameIntKV("changed_symbol_count",ea2.delta.changed_symbol_count)+",";
      j+=ISSX_JsonWriter::NameIntKV("changed_timeframe_count",ea2.delta.changed_timeframe_count)+",";
      j+=ISSX_JsonWriter::NameStringKV("active_universe_fingerprint",ValueOrNA(ea2.universe.active_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameDoubleKV("history_deep_completion_pct",ea2.coverage.history_deep_completion_pct,2);
      j+="}";
      return j;
     }

   static string BuildStageSnapshotEA3(const ISSX_EA3_State &ea3)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("stage_id","ea3")+",";
      j+=ISSX_JsonWriter::NameStringKV("publishability_state",StagePublishabilityWord((int)ea3.stage_publishability_state))+",";
      j+=ISSX_JsonWriter::NameBoolKV("stage_minimum_ready_flag",ea3.stage_minimum_ready_flag)+",";
      j+=ISSX_JsonWriter::NameStringKV("dependency_block_reason",ValueOrNA(ea3.dependency_block_reason))+",";
      j+=ISSX_JsonWriter::NameLongKV("accepted_sequence_no",(long)ea3.manifest.sequence_no)+",";
      j+=ISSX_JsonWriter::NameIntKV("changed_symbol_count",ea3.delta.changed_symbol_count)+",";
      j+=ISSX_JsonWriter::NameIntKV("changed_frontier_count",ea3.delta.changed_frontier_count)+",";
      j+=ISSX_JsonWriter::NameStringKV("rankable_universe_fingerprint",ValueOrNA(ea3.universe.rankable_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameStringKV("frontier_universe_fingerprint",ValueOrNA(ea3.universe.frontier_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameDoubleKV("coverage_rankable_recent_pct",ea3.universe.percent_rankable_revalidated_recent,2)+",";
      j+=ISSX_JsonWriter::NameDoubleKV("coverage_frontier_recent_pct",ea3.universe.percent_frontier_revalidated_recent,2);
      j+="}";
      return j;
     }

   static string BuildStageSnapshotEA4(const ISSX_EA4_State &ea4)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("stage_id","ea4")+",";
      j+=ISSX_JsonWriter::NameStringKV("publishability_state",StagePublishabilityWord((int)ea4.stage_publishability_state))+",";
      j+=ISSX_JsonWriter::NameBoolKV("stage_minimum_ready_flag",ea4.stage_minimum_ready_flag)+",";
      j+=ISSX_JsonWriter::NameStringKV("dependency_block_reason",ValueOrNA(ea4.dependency_block_reason))+",";
      j+=ISSX_JsonWriter::NameLongKV("accepted_sequence_no",(long)ea4.manifest.sequence_no)+",";
      j+=ISSX_JsonWriter::NameIntKV("changed_symbol_count",ea4.delta.changed_symbol_count)+",";
      j+=ISSX_JsonWriter::NameIntKV("changed_frontier_count",ea4.delta.changed_frontier_count)+",";
      j+=ISSX_JsonWriter::NameStringKV("frontier_universe_fingerprint",ValueOrNA(ea4.universe.frontier_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameDoubleKV("percent_frontier_revalidated_recent",ea4.universe.percent_frontier_revalidated_recent,2);
      j+="}";
      return j;
     }

   static string BuildStageSnapshotEA5(const ISSX_EA5_State &ea5)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("stage_id","ea5")+",";
      j+=ISSX_JsonWriter::NameStringKV("publishability_state",StagePublishabilityWord((int)ea5.market_readiness_summary.system_publishability_state))+",";
      j+=ISSX_JsonWriter::NameBoolKV("stage_minimum_ready_flag",ea5.manifest.stage_minimum_ready_flag)+",";
      j+=ISSX_JsonWriter::NameStringKV("dependency_block_reason",ValueOrNA(ea5.why_export_is_thin))+",";
      j+=ISSX_JsonWriter::NameLongKV("accepted_sequence_no",(long)ea5.manifest.sequence_no)+",";
      j+=ISSX_JsonWriter::NameIntKV("changed_symbol_count",ea5.manifest.changed_symbol_count)+",";
      j+=ISSX_JsonWriter::NameStringKV("publishable_universe_fingerprint",ValueOrNA(ea5.manifest.universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameLongKV("last_export_age_sec",AgeSecFromTime(ea5.age_surface.export_generated_at,TimeCurrent()))+",";
      j+=ISSX_JsonWriter::NameStringKV("export_health_state",ValueOrNA(ISSX_PublishabilityStateToString(ea5.market_readiness_summary.system_publishability_state)));
      j+="}";
      return j;
     }

   static bool ProjectStageSnapshot(const string firm_id,const ISSX_StageId stage_id,const string json)
     {
      const string file_name=ISSX_UI_Text::StageIdToShortString(stage_id)+"_debug_snapshot.json";
      const string path=ISSX_PersistencePath::DebugFolder(firm_id)+file_name;
      return ISSX_FileIO::WriteAllTextUtf8(path,json);
     }

   static string BuildUniverseSnapshotJson(const ISSX_EA1_State &ea1,const ISSX_EA2_State &ea2,const ISSX_EA3_State &ea3,
                                          const ISSX_EA4_State &ea4,const ISSX_EA5_State &ea5)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("engine_name",ISSX_ENGINE_NAME)+",";
      j+=ISSX_JsonWriter::NameStringKV("engine_version",ISSX_UI_TEST_MODULE_VERSION)+",";
      j+=ISSX_JsonWriter::NameStringKV("broker_universe_fingerprint",ValueOrNA(ea1.universe.broker_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameStringKV("eligible_universe_fingerprint",ValueOrNA(ea1.universe.eligible_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameStringKV("active_universe_fingerprint",ValueOrNA(ea2.universe.active_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameStringKV("rankable_universe_fingerprint",ValueOrNA(ea3.universe.rankable_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameStringKV("frontier_universe_fingerprint",ValueOrNA(ea4.universe.frontier_universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameStringKV("publishable_universe_fingerprint",ValueOrNA(ea5.manifest.universe_fingerprint))+",";
      j+=ISSX_JsonWriter::NameIntKV("ea1_changed_symbol_count",ea1.deltas.changed_symbol_count)+",";
      j+=ISSX_JsonWriter::NameIntKV("ea2_changed_symbol_count",ea2.delta.changed_symbol_count)+",";
      j+=ISSX_JsonWriter::NameIntKV("ea3_changed_symbol_count",ea3.delta.changed_symbol_count)+",";
      j+=ISSX_JsonWriter::NameIntKV("ea4_changed_symbol_count",ea4.delta.changed_symbol_count)+",";
      j+=ISSX_JsonWriter::NameIntKV("ea5_changed_symbol_count",ea5.manifest.changed_symbol_count);
      j+="}";
      return j;
     }

   static bool ProjectUniverseSnapshot(const string firm_id,const ISSX_EA1_State &ea1,const ISSX_EA2_State &ea2,const ISSX_EA3_State &ea3,
                                       const ISSX_EA4_State &ea4,const ISSX_EA5_State &ea5)
     {
      const string path=ISSX_PersistencePath::UniverseSnapshotFile(firm_id);
      return ISSX_FileIO::WriteAllTextUtf8(path,BuildUniverseSnapshotJson(ea1,ea2,ea3,ea4,ea5));
     }

   static bool ProjectAllStageSnapshots(const string firm_id,
                                        const ISSX_EA1_State &ea1,
                                        const ISSX_EA2_State &ea2,
                                        const ISSX_EA3_State &ea3,
                                        const ISSX_EA4_State &ea4,
                                        const ISSX_EA5_State &ea5)
     {
      bool ok=true;
      ok=(ProjectStageSnapshot(firm_id,issx_stage_ea1,BuildStageSnapshotEA1(ea1)) && ok);
      ok=(ProjectStageSnapshot(firm_id,issx_stage_ea2,BuildStageSnapshotEA2(ea2)) && ok);
      ok=(ProjectStageSnapshot(firm_id,issx_stage_ea3,BuildStageSnapshotEA3(ea3)) && ok);
      ok=(ProjectStageSnapshot(firm_id,issx_stage_ea4,BuildStageSnapshotEA4(ea4)) && ok);
      ok=(ProjectStageSnapshot(firm_id,issx_stage_ea5,BuildStageSnapshotEA5(ea5)) && ok);
      return ok;
     }


   static bool ProjectDebugRoot(const string firm_id,const ISSX_DebugAggregate &agg)
     {
      return ProjectDebugJson(firm_id,agg);
     }

   static bool ProjectStageStatusRoot(const string firm_id,const ISSX_DebugAggregate &agg)
     {
      const string path=ISSX_PersistencePath::RootStageStatus(firm_id);
      return ISSX_FileIO::WriteAllTextUtf8(path,BuildDebugJson(agg));
     }

   static bool ProjectUniverseSnapshotRoot(const string firm_id,const ISSX_RuntimeState &runtime_state)
     {
      string j="{";
      j+=ISSX_JsonWriter::NameStringKV("engine_name",ISSX_ENGINE_NAME)+",";
      j+=ISSX_JsonWriter::NameStringKV("engine_version",ISSX_UI_TEST_MODULE_VERSION)+",";
      j+=ISSX_JsonWriter::NameLongKV("kernel_minute_id",runtime_state.kernel.kernel_minute_id)+",";
      j+=ISSX_JsonWriter::NameLongKV("scheduler_cycle_no",runtime_state.scheduler_cycle_no)+",";
      j+=ISSX_JsonWriter::NameStringKV("weakest_stage",ISSX_UI_Text::StageIdToShortString(runtime_state.weakest_stage))+",";
      j+=ISSX_JsonWriter::NameStringKV("weakest_stage_reason",ValueOrNA(runtime_state.weakest_stage_reason));
      j+="}";
      return ISSX_FileIO::WriteAllTextUtf8(ISSX_PersistencePath::RootUniverseSnapshot(firm_id),j);
     }
  };



string ISSX_UITestDiagTag()
  {
   return "ui_diag_v174f";
  }


string ISSX_UITestDebugSignature()
  {
   return ISSX_UITestDiagTag();
  }

#endif
