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
#include <ISSX/issx_ui_test.mqh>

#define ISSX_UI_MODULE_VERSION "1.721"
#define ISSX_UI_DEBUG_MODULE_VERSION ISSX_UI_MODULE_VERSION
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
               const string scheduler_state,
               const string kernel_result,
               const string kernel_reason,
               const long kernel_elapsed_ms,
               const string broker,
               const string server,
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
      text+=" minimal_debug_mode="+(minimal_debug?"on":"off")+" isolation_mode="+(isolation_mode?"on":"off")+"\n";
      text+=" runtime_scheduler="+(gate_runtime_scheduler?"on":"off")+" timer_heavy_work="+(gate_timer_heavy?"on":"off")+" tick_heavy_work="+(gate_tick_heavy?"on":"off")+"\n";
      text+=" menu_engine="+(gate_menu_engine?"on":"off")+" chart_ui_updates="+(gate_chart_ui_updates?"on":"off")+" ui_projection="+(gate_ui_projection?"on":"off")+"\n";
      text+=" scheduler="+scheduler_state+" kernel="+kernel_result+" reason="+kernel_reason+" elapsed_ms="+IntegerToString((int)kernel_elapsed_ms)+"\n";
      text+=" boot="+boot_id+" broker="+broker+" server="+server+"\n";

      text+="STAGE STATES\n";
      text+=" EA1 Market="+ISSX_PublishabilityStateToString(ea1.stage_publishability_state)+" | run="+ea1_run+" | reason="+ea1_reason+"\n";
      text+=" EA2 History="+ISSX_PublishabilityStateToString(ea2.stage_publishability_state)+" | run="+ea2_run+" | reason="+ea2_reason+"\n";
      text+=" EA3 Selection="+ISSX_PublishabilityStateToString(ea3.stage_publishability_state)+" | run="+ea3_run+" | reason="+ea3_reason+"\n";
      text+=" EA4 Correlation="+ISSX_PublishabilityStateToString(ea4.stage_publishability_state)+" | run="+ea4_run+" | reason="+ea4_reason+"\n";
      text+=" EA5 Contracts="+ea5.debug_ready_state+" | run="+ea5_run+" | reason="+ea5_reason+"\n";

      text+="EA1 DETAIL\n";
      text+=" symbols_discovered="+IntegerToString(ea1.universe.broker_universe)+" active="+IntegerToString(ea1.universe.active_universe)+" publishable="+IntegerToString(ea1.universe.publishable_universe)+"\n";
      text+=" cadence_state="+ea1.discovery_status_reason+" discovery_minute_id="+IntegerToString(ea1.discovery_minute_id)+" last_discovery_elapsed_ms="+IntegerToString(ea1.discovery_elapsed_ms)+"\n";
      text+=" publish_state="+ea1_publish_state+" publish_checkpoint="+ea1.publish_last_checkpoint+" publish_error="+ea1.publish_last_error+"\n";
      text+=" projection_state="+last_cycle_status+" fx:create="+IntegerToString(m_fx.objects_created)+" update="+IntegerToString(m_fx.objects_updated)+" skip="+IntegerToString(m_fx.objects_skipped)+"\n";
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
