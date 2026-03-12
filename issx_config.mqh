#ifndef __ISSX_CONFIG_MQH__
#define __ISSX_CONFIG_MQH__

#include <ISSX/issx_core.mqh>

#define ISSX_CONFIG_MODULE_VERSION "1.726"

// Wrapper inputs (declared in ISSX.mq5)
#ifndef ISSX_CONFIG_INPUTS_PROVIDED
extern string InpFirmId;
extern bool   InpIncludeCustomSymbols;
extern int    InpEA1MaxSymbols;
extern int    InpEA1HydrationBatchSize;
extern bool   InpEA2DeepProfileDefault;
extern int    InpEA2MaxSymbolsPerSlice;
extern bool   InpProjectStageStatusRoot;
extern bool   InpProjectUniverseSnapshot;
extern bool   InpProjectDebugSnapshots;
extern int    InpLockStaleAfterSec;
extern string InpInstanceTag;
extern bool   InpSafeMode;
extern bool   InpRunFirstCycleInOnInit;
extern bool   InpBypassLocks;
extern bool   InpEnableEA1;
extern bool   InpEnableEA2;
extern bool   InpEnableEA3;
extern bool   InpEnableEA4;
extern bool   InpEnableEA5;
extern bool   InpIsolationMode;
extern bool   InpMinimalDebugMode;
extern bool   InpGateRuntimeScheduler;
extern bool   InpGateTimerHeavyWork;
extern bool   InpGateMenuEngine;
extern bool   InpGateChartUiUpdates;
extern bool   InpGateTickHeavyWork;
extern bool   InpGateUiProjection;
#endif

struct ISSX_ConfigSnapshot
  {
   bool initialized;
   bool valid;
   bool minimal_debug_mode;
   bool isolation_mode;
   bool runtime_scheduler_enabled;
   bool timer_heavy_work_enabled;
   bool tick_heavy_work_enabled;
   bool menu_engine_enabled;
   bool chart_ui_updates_enabled;
   bool ui_projection_enabled;
   bool ea_enabled[5];
   int ea1_hydration_batch;
   int ea1_max_symbols;
   int ea2_max_symbols_per_slice;
   int lock_stale_after_sec;
   string firm_id;
   string instance_tag;

   void Reset()
     {
      initialized=false;
      valid=true;
      minimal_debug_mode=false;
      isolation_mode=false;
      runtime_scheduler_enabled=false;
      timer_heavy_work_enabled=false;
      tick_heavy_work_enabled=false;
      menu_engine_enabled=false;
      chart_ui_updates_enabled=false;
      ui_projection_enabled=false;
      for(int i=0;i<5;i++)
         ea_enabled[i]=false;
      ea1_hydration_batch=25;
      ea1_max_symbols=0;
      ea2_max_symbols_per_slice=128;
      lock_stale_after_sec=90;
      firm_id="default_firm";
      instance_tag="";
     }
  };

class ISSX_Config
  {
private:
   ISSX_ConfigSnapshot m_snapshot;
   string m_bool_keys[];
   bool   m_bool_values[];
   string m_int_keys[];
   int    m_int_values[];
   string m_double_keys[];
   double m_double_values[];
   string m_string_keys[];
   string m_string_values[];

   int FindKey(const string &keys[],const string key) const
     {
      for(int i=0;i<ArraySize(keys);i++)
        {
         if(keys[i]==key)
            return i;
        }
      return -1;
     }

   void SetBool(const string key,const bool value)
     {
      const int idx=FindKey(m_bool_keys,key);
      if(idx>=0)
         m_bool_values[idx]=value;
      else
        {
         const int n=ArraySize(m_bool_keys);
         ArrayResize(m_bool_keys,n+1);
         ArrayResize(m_bool_values,n+1);
         m_bool_keys[n]=key;
         m_bool_values[n]=value;
        }
      Print("ISSX: config_value_loaded key=",key," type=bool value=",(value?"true":"false"));
     }

   void SetInt(const string key,const int value)
     {
      const int idx=FindKey(m_int_keys,key);
      if(idx>=0)
         m_int_values[idx]=value;
      else
        {
         const int n=ArraySize(m_int_keys);
         ArrayResize(m_int_keys,n+1);
         ArrayResize(m_int_values,n+1);
         m_int_keys[n]=key;
         m_int_values[n]=value;
        }
      Print("ISSX: config_value_loaded key=",key," type=int value=",IntegerToString(value));
     }

   void SetDouble(const string key,const double value)
     {
      const int idx=FindKey(m_double_keys,key);
      if(idx>=0)
         m_double_values[idx]=value;
      else
        {
         const int n=ArraySize(m_double_keys);
         ArrayResize(m_double_keys,n+1);
         ArrayResize(m_double_values,n+1);
         m_double_keys[n]=key;
         m_double_values[n]=value;
        }
      Print("ISSX: config_value_loaded key=",key," type=double value=",DoubleToString(value,8));
     }

   void SetString(const string key,const string value)
     {
      const int idx=FindKey(m_string_keys,key);
      if(idx>=0)
         m_string_values[idx]=value;
      else
        {
         const int n=ArraySize(m_string_keys);
         ArrayResize(m_string_keys,n+1);
         ArrayResize(m_string_values,n+1);
         m_string_keys[n]=key;
         m_string_values[n]=value;
        }
      Print("ISSX: config_value_loaded key=",key," type=string value=",value);
     }

   bool LogValidationError(const string key,const string detail)
     {
      m_snapshot.valid=false;
      Print("ISSX: config_validation_error key=",key," detail=",detail);
      return false;
     }

   bool ValidatePositiveInt(const string key,const int value)
     {
      if(value>0)
         return true;
      return LogValidationError(key,"must be > 0, got "+IntegerToString(value));
     }

   bool ValidateNonNegativeInt(const string key,const int value)
     {
      if(value>=0)
         return true;
      return LogValidationError(key,"must be >= 0, got "+IntegerToString(value));
     }

   void ComputeRuntimeFlags()
     {
      const bool minimal=GetBool("minimal_debug_mode");
      const bool req_runtime=GetBool("gate_runtime_scheduler_requested");
      const bool req_timer=GetBool("gate_timer_heavy_requested");
      const bool req_tick=GetBool("gate_tick_heavy_requested");
      const bool req_menu=GetBool("gate_menu_engine_requested");
      const bool req_chart=GetBool("gate_chart_ui_requested");
      const bool req_ui_projection=GetBool("gate_ui_projection_requested");

      const bool ea1_requested=GetBool("ea1_enabled");
      const bool isolation=GetBool("isolation_mode");
      const bool ea1_foundation_profile=(ea1_requested || isolation);

      m_snapshot.runtime_scheduler_enabled=(req_runtime && !minimal);
      m_snapshot.timer_heavy_work_enabled=(req_timer && !minimal);
      m_snapshot.tick_heavy_work_enabled=(req_tick && !minimal);
      m_snapshot.menu_engine_enabled=(req_menu && !minimal);
      m_snapshot.chart_ui_updates_enabled=(req_chart && !minimal);
      m_snapshot.ui_projection_enabled=(req_ui_projection && !minimal);

      if(ea1_foundation_profile)
        {
         if(!m_snapshot.timer_heavy_work_enabled)
            Print("ISSX: profile_normalization gate=timer_heavy_work_enabled reason=ea1_foundation_forced_on requested=",(req_timer?"on":"off")," minimal=",(minimal?"on":"off"));
         if(!m_snapshot.ui_projection_enabled)
            Print("ISSX: profile_normalization gate=ui_projection_enabled reason=ea1_foundation_forced_on requested=",(req_ui_projection?"on":"off")," minimal=",(minimal?"on":"off"));
         m_snapshot.timer_heavy_work_enabled=true;
         m_snapshot.ui_projection_enabled=true;
        }

      SetBool("runtime_scheduler_enabled",m_snapshot.runtime_scheduler_enabled);
      SetBool("timer_heavy_work_enabled",m_snapshot.timer_heavy_work_enabled);
      SetBool("tick_heavy_work_enabled",m_snapshot.tick_heavy_work_enabled);
      SetBool("menu_engine_enabled",m_snapshot.menu_engine_enabled);
      SetBool("chart_ui_updates_enabled",m_snapshot.chart_ui_updates_enabled);
      SetBool("ui_projection_enabled",m_snapshot.ui_projection_enabled);

      Print("ISSX: config_runtime_flag_computed flag=runtime_scheduler_enabled requested=",(req_runtime?"on":"off")," effective=",(m_snapshot.runtime_scheduler_enabled?"on":"off"));
      Print("ISSX: config_runtime_flag_computed flag=timer_heavy_work_enabled requested=",(req_timer?"on":"off")," effective=",(m_snapshot.timer_heavy_work_enabled?"on":"off"));
      Print("ISSX: config_runtime_flag_computed flag=tick_heavy_work_enabled requested=",(req_tick?"on":"off")," effective=",(m_snapshot.tick_heavy_work_enabled?"on":"off"));
      Print("ISSX: config_runtime_flag_computed flag=menu_engine_enabled requested=",(req_menu?"on":"off")," effective=",(m_snapshot.menu_engine_enabled?"on":"off"));
      Print("ISSX: config_runtime_flag_computed flag=chart_ui_updates_enabled requested=",(req_chart?"on":"off")," effective=",(m_snapshot.chart_ui_updates_enabled?"on":"off"));
      Print("ISSX: config_runtime_flag_computed flag=ui_projection_enabled requested=",(req_ui_projection?"on":"off")," effective=",(m_snapshot.ui_projection_enabled?"on":"off"));
     }

   void ComputeStageFlags()
     {
      const bool isolation=GetBool("isolation_mode");
      m_snapshot.ea_enabled[0]=GetBool("ea1_enabled");
      m_snapshot.ea_enabled[1]=GetBool("ea2_enabled");
      m_snapshot.ea_enabled[2]=GetBool("ea3_enabled");
      m_snapshot.ea_enabled[3]=GetBool("ea4_enabled");
      m_snapshot.ea_enabled[4]=GetBool("ea5_enabled");

      if(isolation)
        {
         m_snapshot.ea_enabled[0]=true;
         m_snapshot.ea_enabled[1]=false;
         m_snapshot.ea_enabled[2]=false;
         m_snapshot.ea_enabled[3]=false;
         m_snapshot.ea_enabled[4]=false;
        }

      SetBool("ea1_enabled_effective",m_snapshot.ea_enabled[0]);
      SetBool("ea2_enabled_effective",m_snapshot.ea_enabled[1]);
      SetBool("ea3_enabled_effective",m_snapshot.ea_enabled[2]);
      SetBool("ea4_enabled_effective",m_snapshot.ea_enabled[3]);
      SetBool("ea5_enabled_effective",m_snapshot.ea_enabled[4]);
     }

public:
   void Init()
     {
      Print("ISSX: config_init_start");
      m_snapshot.Reset();
      ArrayResize(m_bool_keys,0); ArrayResize(m_bool_values,0);
      ArrayResize(m_int_keys,0); ArrayResize(m_int_values,0);
      ArrayResize(m_double_keys,0); ArrayResize(m_double_values,0);
      ArrayResize(m_string_keys,0); ArrayResize(m_string_values,0);

      SetString("firm_id",InpFirmId);
      SetBool("include_custom_symbols",InpIncludeCustomSymbols);
      SetInt("ea1_max_symbols",InpEA1MaxSymbols);
      SetInt("ea1_hydration_batch",InpEA1HydrationBatchSize);
      SetBool("ea2_deep_profile_default",InpEA2DeepProfileDefault);
      SetInt("ea2_max_symbols_per_slice",InpEA2MaxSymbolsPerSlice);
      SetBool("project_stage_status_root",InpProjectStageStatusRoot);
      SetBool("project_universe_snapshot",InpProjectUniverseSnapshot);
      SetBool("project_debug_snapshots",InpProjectDebugSnapshots);
      SetInt("lock_stale_after_sec",InpLockStaleAfterSec);
      SetString("instance_tag",InpInstanceTag);
      SetBool("safe_mode",InpSafeMode);
      SetBool("run_first_cycle_in_oninit",InpRunFirstCycleInOnInit);
      SetBool("bypass_locks",InpBypassLocks);
      SetBool("ea1_enabled",InpEnableEA1);
      SetBool("ea2_enabled",InpEnableEA2);
      SetBool("ea3_enabled",InpEnableEA3);
      SetBool("ea4_enabled",InpEnableEA4);
      SetBool("ea5_enabled",InpEnableEA5);
      SetBool("isolation_mode",InpIsolationMode);
      SetBool("minimal_debug_mode",InpMinimalDebugMode);
      SetBool("gate_runtime_scheduler_requested",InpGateRuntimeScheduler);
      SetBool("gate_timer_heavy_requested",InpGateTimerHeavyWork);
      SetBool("gate_menu_engine_requested",InpGateMenuEngine);
      SetBool("gate_chart_ui_requested",InpGateChartUiUpdates);
      SetBool("gate_tick_heavy_requested",InpGateTickHeavyWork);
      SetBool("gate_ui_projection_requested",InpGateUiProjection);

      ValidatePositiveInt("ea1_hydration_batch",GetInt("ea1_hydration_batch"));
      ValidateNonNegativeInt("ea1_max_symbols",GetInt("ea1_max_symbols"));
      ValidatePositiveInt("runtime_timer_seconds",ISSX_EVENT_TIMER_SEC);
      ValidatePositiveInt("lock_stale_after_sec",GetInt("lock_stale_after_sec"));
      ValidatePositiveInt("ea2_max_symbols_per_slice",GetInt("ea2_max_symbols_per_slice"));

      ComputeRuntimeFlags();
      ComputeStageFlags();

      m_snapshot.minimal_debug_mode=GetBool("minimal_debug_mode");
      m_snapshot.isolation_mode=GetBool("isolation_mode");
      m_snapshot.ea1_hydration_batch=MathMax(1,GetInt("ea1_hydration_batch"));
      m_snapshot.ea1_max_symbols=MathMax(0,GetInt("ea1_max_symbols"));
      m_snapshot.ea2_max_symbols_per_slice=MathMax(1,GetInt("ea2_max_symbols_per_slice"));
      m_snapshot.lock_stale_after_sec=MathMax(1,GetInt("lock_stale_after_sec"));
      m_snapshot.firm_id=GetString("firm_id");
      m_snapshot.instance_tag=GetString("instance_tag");
      m_snapshot.initialized=true;

      Print("ISSX: config_init_complete valid=",(m_snapshot.valid?"true":"false"));
     }

   bool GetBool(const string key) const
     {
      const int idx=FindKey(m_bool_keys,key);
      if(idx>=0)
         return m_bool_values[idx];
      return false;
     }

   int GetInt(const string key) const
     {
      const int idx=FindKey(m_int_keys,key);
      if(idx>=0)
         return m_int_values[idx];
      return 0;
     }

   double GetDouble(const string key) const
     {
      const int idx=FindKey(m_double_keys,key);
      if(idx>=0)
         return m_double_values[idx];
      return 0.0;
     }

   string GetString(const string key) const
     {
      const int idx=FindKey(m_string_keys,key);
      if(idx>=0)
         return m_string_values[idx];
      return "";
     }

   bool IsEAEnabled(const ISSX_StageId stage_id) const
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return m_snapshot.ea_enabled[0];
         case issx_stage_ea2: return m_snapshot.ea_enabled[1];
         case issx_stage_ea3: return m_snapshot.ea_enabled[2];
         case issx_stage_ea4: return m_snapshot.ea_enabled[3];
         case issx_stage_ea5: return m_snapshot.ea_enabled[4];
         default:             return false;
        }
     }

   ISSX_ConfigSnapshot GetSnapshot() const
     {
      return m_snapshot;
     }
};

#endif
