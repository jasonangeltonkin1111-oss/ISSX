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

#define ISSX_UI_MODULE_VERSION "1.717"
#define ISSX_HUD_PREFIX "ISSX_HUD_"
#define ISSX_HUD_MAIN_OBJECT "ISSX_HUD_MAIN"

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
         Log(dbg,"hud_object_skip_existing","name="+name);
         return;
        }
      if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
        {
         Log(dbg,"hud_render_error","create_failed name="+name+" err="+IntegerToString((int)GetLastError()));
         return;
        }
      m_fx.objects_created++;
      Log(dbg,"hud_object_create","name="+name);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,6);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,8);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrLightGray);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
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
      Log(dbg,"hud_init_complete","version="+string(ISSX_UI_MODULE_VERSION));
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
               const ulong timer_pulse,
               const bool minimal_debug,
               const bool isolation_mode,
               const string scheduler_state,
               const string kernel_result,
               const string kernel_reason,
               const long kernel_elapsed_ms,
               const string broker,
               const string server,
               const bool ea_enabled[],
               const ISSX_EA1_State &ea1,
               const ISSX_EA2_State &ea2,
               const ISSX_EA3_State &ea3,
               const ISSX_EA4_State &ea4,
               const ISSX_EA5_State &ea5,
               const string ea1_run,
               const string ea1_reason,
               const long ea1_elapsed_ms,
               const string ea1_publish_state,
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

      string text="ISSX HUD v"+wrapper_version+" (ui="+string(ISSX_UI_MODULE_VERSION)+")\n";
      text+="SYSTEM\n";
      text+=" boot="+boot_id+" broker="+broker+" server="+server+" pulse="+ISSX_Util::ULongToStringX(timer_pulse)+"\n";
      text+=" kernel="+kernel_result+" reason="+kernel_reason+" elapsed_ms="+IntegerToString((int)kernel_elapsed_ms)+" scheduler="+scheduler_state+"\n";
      text+=" debug_min="+(minimal_debug?"on":"off")+" isolation="+(isolation_mode?"on":"off")+" cycle="+last_cycle_status+"\n";
      text+=" fx:create="+IntegerToString(m_fx.objects_created)+" update="+IntegerToString(m_fx.objects_updated)+" skip="+IntegerToString(m_fx.objects_skipped)+"\n";

      text+="EA1 MARKET\n";
      text+=" enabled="+(ea_enabled[0]?"on":"off")+" effective="+ea1.stage_publishability_state+" run="+ea1_run+" reason="+ea1_reason+" elapsed="+IntegerToString((int)ea1_elapsed_ms)+"ms\n";
      text+=" discovery="+(ea1.discovery_attempted?"attempted":"idle")+" accepted="+IntegerToString(ea1.counters.accepted_strong_count+ea1.counters.accepted_degraded_count)+" rejected="+IntegerToString(ea1.counters.rejected_count)+" degraded="+IntegerToString(ea1.counters.degraded_count)+"\n";
      text+=" hydration="+IntegerToString(ea1.hydration_processed)+"/"+IntegerToString(ea1.hydration_total)+" batch="+IntegerToString(ea1.hydration_batch_size)+" publish="+ea1_publish_state+" gate="+ea1.dependency_block_reason+"\n";
      text+=" publish_ckpt="+ea1.publish_last_checkpoint+" publish_err="+ea1.publish_last_error+" bytes="+IntegerToString(ea1.publish_stage_json_bytes)+"\n";

      text+="EA2 HISTORY\n";
      text+=" enabled="+(ea_enabled[1]?"on":"off")+" effective="+ISSX_Enum::PublishabilityStateToString(ea2.stage_publishability_state)+" run="+ea2_run+" reason="+ea2_reason+" elapsed="+IntegerToString((int)ea2_elapsed_ms)+"ms\n";
      text+=" readiness="+(ea2.stage_minimum_ready_flag?"ready":"not_ready")+" copyrates="+IntegerToString(ea2.forensic.copyrates_successes)+"/"+IntegerToString(ea2.forensic.copyrates_attempts)+" retries="+IntegerToString(ea2.forensic.copyrates_failures)+" partial="+(ea2.projection_partial_success_flag?"partial":"none")+"\n";

      text+="EA3 SELECTION\n";
      text+=" enabled="+(ea_enabled[2]?"on":"off")+" effective="+ISSX_Enum::PublishabilityStateToString(ea3.stage_publishability_state)+" run="+ea3_run+" reason="+ea3_reason+" elapsed="+IntegerToString((int)ea3_elapsed_ms)+"ms\n";
      text+=" candidates="+IntegerToString(ea3.universe.active_universe)+" frontier="+IntegerToString(ea3.universe.frontier_universe)+" bounded="+IntegerToString(ea3.universe.publishable_universe)+" readiness="+(ea3.stage_minimum_ready_flag?"ready":"not_ready")+"\n";

      text+="EA4 CORRELATION\n";
      text+=" enabled="+(ea_enabled[3]?"on":"off")+" effective="+ISSX_Enum::PublishabilityStateToString(ea4.stage_publishability_state)+" run="+ea4_run+" reason="+ea4_reason+" elapsed="+IntegerToString((int)ea4_elapsed_ms)+"ms\n";
      text+=" workload="+IntegerToString(ea4.universe.frontier_universe_count)+" batch="+IntegerToString(ea4.forensic.pair_cursor)+"/"+IntegerToString(ea4.forensic.pair_batch_end_cursor)+" matrix="+ea4.forensic.error_conditions+" partial="+(ea4.forensic.partial_ready_flag?"partial":"none")+"\n";

      text+="EA5 CONTRACTS\n";
      text+=" enabled="+(ea_enabled[4]?"on":"off")+" effective="+ea5.debug_ready_state+" run="+ea5_run+" reason="+ea5_reason+" elapsed="+IntegerToString((int)ea5_elapsed_ms)+"ms\n";
      text+=" attempted="+IntegerToString(ea5.debug_discovery_attempt_count)+" built="+IntegerToString(ea5.debug_contract_build_count)+" unresolved="+ea5.why_publish_is_stale+" export="+ea5.debug_persistence_interactions+" payload="+IntegerToString(ea5.debug_estimated_export_bytes)+"\n";

      const string obj=ObjName(ISSX_HUD_MAIN_OBJECT);
      if(text==m_last_text)
        {
         m_fx.objects_skipped++;
         Log(dbg,"hud_object_skip_existing","name="+obj+" reason=text_unchanged");
        }
      else
        {
         if(ObjectSetString(0,obj,OBJPROP_TEXT,text))
           {
            m_fx.objects_updated++;
            Log(dbg,"hud_object_update","name="+obj);
            m_last_text=text;
           }
         else
            Log(dbg,"hud_render_error","update_failed name="+obj+" err="+IntegerToString((int)GetLastError()));
        }

      m_fx.last_render_ts=TimeCurrent();
      Log(dbg,"hud_update_cycle","created="+IntegerToString(m_fx.objects_created)+" updated="+IntegerToString(m_fx.objects_updated)+" skipped="+IntegerToString(m_fx.objects_skipped));
     }
  };

#endif
