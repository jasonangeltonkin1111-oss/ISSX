#ifndef __ISSX_CONFIG_MQH__
#define __ISSX_CONFIG_MQH__

#include <ISSX/issx_core.mqh>

#define ISSX_CONFIG_MODULE_VERSION "1.734"

// Wrapper inputs (declared in ISSX.mq5)
#ifndef ISSX_CONFIG_INPUTS_PROVIDED
extern string InpFirmId;
extern bool   InpIncludeCustomSymbols;
extern int    InpEA1MaxSymbols;
extern int    InpEA1HydrationBatchSize;
extern int    InpEA1RollingBatchSize;
extern int    InpEA1RollingCadenceSec;
extern int    InpEA1RollingMaxSnapshots;
extern int    InpEA1PublishCadenceSec;
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
extern bool   InpEnableRuntimeSchedulerLayer;
extern int    InpSchedulerCycleBudgetMs;
#endif

struct ISSX_ConfigSnapshot
  {
   bool initialized;
   bool valid;

   // raw runtime intent
   bool safe_mode;
   bool run_first_cycle_in_oninit;
   bool bypass_locks;
   bool minimal_debug_mode;
   bool isolation_mode;

   // raw requested gates
   bool gate_runtime_scheduler_requested;
   bool gate_timer_heavy_requested;
   bool gate_menu_engine_requested;
   bool gate_chart_ui_requested;
   bool gate_tick_heavy_requested;
   bool gate_ui_projection_requested;

   // raw stage requests
   bool ea_requested[5];

   // effective runtime/stage flags
   bool runtime_scheduler_enabled;
   bool runtime_scheduler_layer_enabled;
   bool timer_heavy_work_enabled;
   bool tick_heavy_work_enabled;
   bool menu_engine_enabled;
   bool chart_ui_updates_enabled;
   bool ui_projection_enabled;
   bool ea_enabled[5];

   // market/history/scheduler settings
   bool include_custom_symbols;
   bool ea2_deep_profile_default;
   int  ea1_hydration_batch;
   int  ea1_max_symbols;
   int  ea1_rolling_batch_size;
   int  ea1_rolling_cadence_sec;
   int  ea1_rolling_max_snapshots;
   int  ea1_publish_cadence_sec;
   int  ea2_max_symbols_per_slice;
   int  scheduler_cycle_budget_ms;
   int  lock_stale_after_sec;

   // projection settings
   bool project_stage_status_root;
   bool project_universe_snapshot;
   bool project_debug_snapshots;

   // centralized derived effective values
   int  effective_publish_cadence_sec;
   int  effective_snapshot_retention;
   int  effective_rolling_batch_size;
   int  effective_scheduler_cycle_budget_ms;
   bool effective_projection_enabled;
   bool effective_publish_enabled;
   bool effective_any_kernel_stage_enabled;

   // identity
   string firm_id;
   string instance_tag;

   void Reset()
     {
      initialized=false;
      valid=true;

      safe_mode=false;
      run_first_cycle_in_oninit=false;
      bypass_locks=false;
      minimal_debug_mode=false;
      isolation_mode=false;

      gate_runtime_scheduler_requested=false;
      gate_timer_heavy_requested=false;
      gate_menu_engine_requested=false;
      gate_chart_ui_requested=false;
      gate_tick_heavy_requested=false;
      gate_ui_projection_requested=false;

      for(int i=0;i<5;i++)
        {
         ea_requested[i]=false;
         ea_enabled[i]=false;
        }

      runtime_scheduler_enabled=false;
      runtime_scheduler_layer_enabled=false;
      timer_heavy_work_enabled=false;
      tick_heavy_work_enabled=false;
      menu_engine_enabled=false;
      chart_ui_updates_enabled=false;
      ui_projection_enabled=false;

      include_custom_symbols=false;
      ea2_deep_profile_default=true;
      ea1_hydration_batch=25;
      ea1_max_symbols=0;
      ea1_rolling_batch_size=50;
      ea1_rolling_cadence_sec=3;
      ea1_rolling_max_snapshots=100;
      ea1_publish_cadence_sec=5;
      ea2_max_symbols_per_slice=128;
      scheduler_cycle_budget_ms=25;
      lock_stale_after_sec=90;

      project_stage_status_root=true;
      project_universe_snapshot=true;
      project_debug_snapshots=true;

      effective_publish_cadence_sec=5;
      effective_snapshot_retention=100;
      effective_rolling_batch_size=50;
      effective_scheduler_cycle_budget_ms=25;
      effective_projection_enabled=false;
      effective_publish_enabled=false;
      effective_any_kernel_stage_enabled=false;

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

bool HasBoolKey(const string key) const
  {
   return (FindKey(m_bool_keys,key) >= 0);
  }

bool HasIntKey(const string key) const
  {
   return (FindKey(m_int_keys,key) >= 0);
  }

bool HasDoubleKey(const string key) const
  {
   return (FindKey(m_double_keys,key) >= 0);
  }

bool HasStringKey(const string key) const
  {
   return (FindKey(m_string_keys,key) >= 0);
  }

void LogUnknownKey(const string type_name,const string key) const
  {
   Print("ISSX: config_unknown_key_lookup type=",type_name," key=",key);
  }
  
  bool RequireBoolKey(const string key)
  {
   if(HasBoolKey(key))
      return true;
   return LogValidationError(key,"missing required bool config key");
  }

bool RequireIntKey(const string key)
  {
   if(HasIntKey(key))
      return true;
   return LogValidationError(key,"missing required int config key");
  }

bool RequireStringKey(const string key)
  {
   if(HasStringKey(key))
      return true;
   return LogValidationError(key,"missing required string config key");
  }

bool AuditRequiredLookupKeys()
  {
   bool ok=true;

   // requested runtime gate keys
   ok=RequireBoolKey("gate_runtime_scheduler_requested") && ok;
   ok=RequireBoolKey("gate_timer_heavy_requested") && ok;
   ok=RequireBoolKey("gate_menu_engine_requested") && ok;
   ok=RequireBoolKey("gate_chart_ui_requested") && ok;
   ok=RequireBoolKey("gate_tick_heavy_requested") && ok;
   ok=RequireBoolKey("gate_ui_projection_requested") && ok;

   // effective runtime gate keys
   ok=RequireBoolKey("runtime_scheduler_enabled") && ok;
   ok=RequireBoolKey("runtime_scheduler_layer_enabled") && ok;
   ok=RequireBoolKey("timer_heavy_work_enabled") && ok;
   ok=RequireBoolKey("tick_heavy_work_enabled") && ok;
   ok=RequireBoolKey("menu_engine_enabled") && ok;
   ok=RequireBoolKey("chart_ui_updates_enabled") && ok;
   ok=RequireBoolKey("ui_projection_enabled") && ok;

   // projection keys
   ok=RequireBoolKey("project_stage_status_root") && ok;
   ok=RequireBoolKey("project_universe_snapshot") && ok;
   ok=RequireBoolKey("project_debug_snapshots") && ok;

   // stage request keys
   ok=RequireBoolKey("ea1_enabled") && ok;
   ok=RequireBoolKey("ea2_enabled") && ok;
   ok=RequireBoolKey("ea3_enabled") && ok;
   ok=RequireBoolKey("ea4_enabled") && ok;
   ok=RequireBoolKey("ea5_enabled") && ok;

   // stage effective keys
   ok=RequireBoolKey("ea1_enabled_effective") && ok;
   ok=RequireBoolKey("ea2_enabled_effective") && ok;
   ok=RequireBoolKey("ea3_enabled_effective") && ok;
   ok=RequireBoolKey("ea4_enabled_effective") && ok;
   ok=RequireBoolKey("ea5_enabled_effective") && ok;

   // effective derived truth keys
   ok=RequireIntKey("effective_publish_cadence_sec") && ok;
   ok=RequireIntKey("effective_snapshot_retention") && ok;
   ok=RequireIntKey("effective_rolling_batch_size") && ok;
   ok=RequireIntKey("effective_scheduler_cycle_budget_ms") && ok;
   ok=RequireBoolKey("effective_projection_enabled") && ok;
   ok=RequireBoolKey("effective_publish_enabled") && ok;
   ok=RequireBoolKey("effective_any_kernel_stage_enabled") && ok;

   // base int keys still used by existing wrapper/helpers
   ok=RequireIntKey("ea1_hydration_batch") && ok;
   ok=RequireIntKey("ea1_max_symbols") && ok;
   ok=RequireIntKey("ea1_rolling_batch_size") && ok;
   ok=RequireIntKey("ea1_rolling_cadence_sec") && ok;
   ok=RequireIntKey("ea1_rolling_max_snapshots") && ok;
   ok=RequireIntKey("ea1_publish_cadence_sec") && ok;
   ok=RequireIntKey("ea2_max_symbols_per_slice") && ok;
   ok=RequireIntKey("scheduler_cycle_budget_ms") && ok;
   ok=RequireIntKey("lock_stale_after_sec") && ok;

   // identity
   ok=RequireStringKey("firm_id") && ok;
   ok=RequireStringKey("instance_tag") && ok;

   return ok;
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

bool ValidateBoolDependency(const string key,const bool lhs,const bool rhs,const string detail)
  {
   if(!lhs || rhs)
      return true;
   return LogValidationError(key,detail);
  }

bool ValidateInvalidCombinations()
  {
   bool ok=true;

   if(GetBool("safe_mode"))
     {
      if(GetBool("gate_runtime_scheduler_requested"))
         ok=LogValidationError("safe_mode","safe_mode requires gate_runtime_scheduler_requested=false") && ok;
      if(GetBool("gate_timer_heavy_requested"))
         ok=LogValidationError("safe_mode","safe_mode requires gate_timer_heavy_requested=false") && ok;
      if(GetBool("run_first_cycle_in_oninit"))
         ok=LogValidationError("safe_mode","safe_mode requires run_first_cycle_in_oninit=false") && ok;
     }

   if(GetBool("minimal_debug_mode"))
     {
      if(GetBool("gate_runtime_scheduler_requested"))
         ok=LogValidationError("minimal_debug_mode","minimal_debug_mode incompatible with requested runtime scheduler") && ok;
      if(GetBool("gate_timer_heavy_requested"))
         ok=LogValidationError("minimal_debug_mode","minimal_debug_mode incompatible with requested timer heavy work") && ok;
      if(GetBool("gate_tick_heavy_requested"))
         ok=LogValidationError("minimal_debug_mode","minimal_debug_mode incompatible with requested tick heavy work") && ok;
      if(GetBool("gate_menu_engine_requested"))
         ok=LogValidationError("minimal_debug_mode","minimal_debug_mode incompatible with requested menu engine") && ok;
      if(GetBool("gate_chart_ui_requested"))
         ok=LogValidationError("minimal_debug_mode","minimal_debug_mode incompatible with requested chart ui updates") && ok;
      if(GetBool("gate_ui_projection_requested"))
         ok=LogValidationError("minimal_debug_mode","minimal_debug_mode incompatible with requested ui projection") && ok;
     }

   if(GetBool("isolation_mode"))
     {
      if(GetBool("ea2_enabled") || GetBool("ea3_enabled") || GetBool("ea4_enabled") || GetBool("ea5_enabled"))
         ok=LogValidationError("isolation_mode","isolation_mode requires ea2-ea5 requested off") && ok;
     }

   if(GetBool("runtime_scheduler_layer_enabled") && !GetBool("gate_runtime_scheduler_requested"))
      ok=LogValidationError("runtime_scheduler_layer_enabled","runtime scheduler layer requires gate_runtime_scheduler_requested=true") && ok;

   if(GetBool("project_stage_status_root") || GetBool("project_universe_snapshot") || GetBool("project_debug_snapshots"))
     {
      // allowed, but without ui projection request this becomes a projection-disabled state
     }

   return ok;
  }

void ComputeDerivedValues()
  {
   m_snapshot.effective_publish_cadence_sec=MathMax(1,GetInt("ea1_publish_cadence_sec"));
   m_snapshot.effective_snapshot_retention=MathMax(1,GetInt("ea1_rolling_max_snapshots"));
   m_snapshot.effective_rolling_batch_size=MathMax(1,GetInt("ea1_rolling_batch_size"));
   m_snapshot.effective_scheduler_cycle_budget_ms=MathMax(1,GetInt("scheduler_cycle_budget_ms"));

   m_snapshot.effective_projection_enabled=
      (m_snapshot.ui_projection_enabled &&
       (GetBool("project_stage_status_root") ||
        GetBool("project_universe_snapshot") ||
        GetBool("project_debug_snapshots")));

   m_snapshot.effective_publish_enabled=
      (m_snapshot.ea_enabled[0] &&
       m_snapshot.timer_heavy_work_enabled &&
       !m_snapshot.safe_mode);

   m_snapshot.effective_any_kernel_stage_enabled=
      (m_snapshot.ea_enabled[0] ||
       m_snapshot.ea_enabled[1] ||
       m_snapshot.ea_enabled[2] ||
       m_snapshot.ea_enabled[3] ||
       m_snapshot.ea_enabled[4]);

   SetInt("effective_publish_cadence_sec",m_snapshot.effective_publish_cadence_sec);
   SetInt("effective_snapshot_retention",m_snapshot.effective_snapshot_retention);
   SetInt("effective_rolling_batch_size",m_snapshot.effective_rolling_batch_size);
   SetInt("effective_scheduler_cycle_budget_ms",m_snapshot.effective_scheduler_cycle_budget_ms);
   SetBool("effective_projection_enabled",m_snapshot.effective_projection_enabled);
   SetBool("effective_publish_enabled",m_snapshot.effective_publish_enabled);
   SetBool("effective_any_kernel_stage_enabled",m_snapshot.effective_any_kernel_stage_enabled);
  }

void DumpConfigSummary() const
  {
   Print("ISSX: config_summary raw firm_id=",m_snapshot.firm_id,
         " instance_tag=",m_snapshot.instance_tag,
         " safe_mode=",(m_snapshot.safe_mode?"on":"off"),
         " minimal_debug=",(m_snapshot.minimal_debug_mode?"on":"off"),
         " isolation=",(m_snapshot.isolation_mode?"on":"off"));

   Print("ISSX: config_summary requested_gates runtime=",(m_snapshot.gate_runtime_scheduler_requested?"on":"off"),
         " timer=",(m_snapshot.gate_timer_heavy_requested?"on":"off"),
         " tick=",(m_snapshot.gate_tick_heavy_requested?"on":"off"),
         " menu=",(m_snapshot.gate_menu_engine_requested?"on":"off"),
         " chart=",(m_snapshot.gate_chart_ui_requested?"on":"off"),
         " ui_projection=",(m_snapshot.gate_ui_projection_requested?"on":"off"));

   Print("ISSX: config_summary effective_gates runtime=",(m_snapshot.runtime_scheduler_enabled?"on":"off"),
         " runtime_layer=",(m_snapshot.runtime_scheduler_layer_enabled?"on":"off"),
         " timer=",(m_snapshot.timer_heavy_work_enabled?"on":"off"),
         " tick=",(m_snapshot.tick_heavy_work_enabled?"on":"off"),
         " menu=",(m_snapshot.menu_engine_enabled?"on":"off"),
         " chart=",(m_snapshot.chart_ui_updates_enabled?"on":"off"),
         " ui_projection=",(m_snapshot.ui_projection_enabled?"on":"off"),
         " projection_effective=",(m_snapshot.effective_projection_enabled?"on":"off"));

   Print("ISSX: config_summary stages requested ea1=",(m_snapshot.ea_requested[0]?"on":"off"),
         " ea2=",(m_snapshot.ea_requested[1]?"on":"off"),
         " ea3=",(m_snapshot.ea_requested[2]?"on":"off"),
         " ea4=",(m_snapshot.ea_requested[3]?"on":"off"),
         " ea5=",(m_snapshot.ea_requested[4]?"on":"off"));

   Print("ISSX: config_summary stages effective ea1=",(m_snapshot.ea_enabled[0]?"on":"off"),
         " ea2=",(m_snapshot.ea_enabled[1]?"on":"off"),
         " ea3=",(m_snapshot.ea_enabled[2]?"on":"off"),
         " ea4=",(m_snapshot.ea_enabled[3]?"on":"off"),
         " ea5=",(m_snapshot.ea_enabled[4]?"on":"off"));

   Print("ISSX: config_summary limits ea1_max_symbols=",IntegerToString(m_snapshot.ea1_max_symbols),
         " ea1_hydration_batch=",IntegerToString(m_snapshot.ea1_hydration_batch),
         " ea1_rolling_batch_size=",IntegerToString(m_snapshot.effective_rolling_batch_size),
         " ea1_rolling_cadence_sec=",IntegerToString(m_snapshot.ea1_rolling_cadence_sec),
         " ea1_publish_cadence_sec=",IntegerToString(m_snapshot.effective_publish_cadence_sec),
         " ea1_snapshot_retention=",IntegerToString(m_snapshot.effective_snapshot_retention),
         " ea2_max_symbols_per_slice=",IntegerToString(m_snapshot.ea2_max_symbols_per_slice),
         " scheduler_cycle_budget_ms=",IntegerToString(m_snapshot.effective_scheduler_cycle_budget_ms),
         " lock_stale_after_sec=",IntegerToString(m_snapshot.lock_stale_after_sec));

   Print("ISSX: config_summary projection project_stage_status_root=",(m_snapshot.project_stage_status_root?"on":"off"),
         " project_universe_snapshot=",(m_snapshot.project_universe_snapshot?"on":"off"),
         " project_debug_snapshots=",(m_snapshot.project_debug_snapshots?"on":"off"),
         " projection_effective=",(m_snapshot.effective_projection_enabled?"on":"off"),
         " publish_enabled=",(m_snapshot.effective_publish_enabled?"on":"off"),
         " any_kernel_stage_enabled=",(m_snapshot.effective_any_kernel_stage_enabled?"on":"off"));

   if(!m_snapshot.valid)
      Print("ISSX: config_summary status=INVALID");
   else
      Print("ISSX: config_summary status=VALID");
  }
  
   void ComputeRuntimeFlags()
  {
   const bool safe_mode=GetBool("safe_mode");
   const bool minimal=GetBool("minimal_debug_mode");
   const bool req_runtime=GetBool("gate_runtime_scheduler_requested");
   const bool req_timer=GetBool("gate_timer_heavy_requested");
   const bool req_tick=GetBool("gate_tick_heavy_requested");
   const bool req_menu=GetBool("gate_menu_engine_requested");
   const bool req_chart=GetBool("gate_chart_ui_requested");
   const bool req_ui_projection=GetBool("gate_ui_projection_requested");

   m_snapshot.runtime_scheduler_enabled=(req_runtime && !minimal && !safe_mode);
   m_snapshot.timer_heavy_work_enabled=(req_timer && !minimal && !safe_mode);
   m_snapshot.tick_heavy_work_enabled=(req_tick && !minimal && !safe_mode);
   m_snapshot.menu_engine_enabled=(req_menu && !minimal && !safe_mode);
   m_snapshot.chart_ui_updates_enabled=(req_chart && !minimal && !safe_mode);
   m_snapshot.ui_projection_enabled=(req_ui_projection && !minimal && !safe_mode);

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

   m_snapshot.ea_requested[0]=GetBool("ea1_enabled");
   m_snapshot.ea_requested[1]=GetBool("ea2_enabled");
   m_snapshot.ea_requested[2]=GetBool("ea3_enabled");
   m_snapshot.ea_requested[3]=GetBool("ea4_enabled");
   m_snapshot.ea_requested[4]=GetBool("ea5_enabled");

   for(int i=0;i<5;i++)
      m_snapshot.ea_enabled[i]=m_snapshot.ea_requested[i];

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
   ArrayResize(m_bool_keys,0);   ArrayResize(m_bool_values,0);
   ArrayResize(m_int_keys,0);    ArrayResize(m_int_values,0);
   ArrayResize(m_double_keys,0); ArrayResize(m_double_values,0);
   ArrayResize(m_string_keys,0); ArrayResize(m_string_values,0);

   // raw wrapper inputs
   SetString("firm_id",InpFirmId);
   SetBool("include_custom_symbols",InpIncludeCustomSymbols);

   SetInt("ea1_max_symbols",InpEA1MaxSymbols);
   SetInt("ea1_hydration_batch",InpEA1HydrationBatchSize);
   SetInt("ea1_rolling_batch_size",InpEA1RollingBatchSize);
   SetInt("ea1_rolling_cadence_sec",InpEA1RollingCadenceSec);
   SetInt("ea1_rolling_max_snapshots",InpEA1RollingMaxSnapshots);
   SetInt("ea1_publish_cadence_sec",InpEA1PublishCadenceSec);

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
   SetBool("gate_chart_ui_updates_requested",InpGateChartUiUpdates);
   SetBool("gate_tick_heavy_requested",InpGateTickHeavyWork);
   SetBool("gate_ui_projection_requested",InpGateUiProjection);

   SetBool("runtime_scheduler_layer_enabled",InpEnableRuntimeSchedulerLayer);
   SetInt("scheduler_cycle_budget_ms",InpSchedulerCycleBudgetMs);

   // scalar validation
   ValidatePositiveInt("ea1_hydration_batch",GetInt("ea1_hydration_batch"));
   ValidateNonNegativeInt("ea1_max_symbols",GetInt("ea1_max_symbols"));
   ValidatePositiveInt("ea1_rolling_batch_size",GetInt("ea1_rolling_batch_size"));
   ValidatePositiveInt("ea1_rolling_cadence_sec",GetInt("ea1_rolling_cadence_sec"));
   ValidatePositiveInt("ea1_rolling_max_snapshots",GetInt("ea1_rolling_max_snapshots"));
   ValidatePositiveInt("ea1_publish_cadence_sec",GetInt("ea1_publish_cadence_sec"));
   ValidatePositiveInt("runtime_timer_seconds",ISSX_EVENT_TIMER_SEC);
   ValidatePositiveInt("lock_stale_after_sec",GetInt("lock_stale_after_sec"));
   ValidatePositiveInt("ea2_max_symbols_per_slice",GetInt("ea2_max_symbols_per_slice"));
   ValidatePositiveInt("scheduler_cycle_budget_ms",GetInt("scheduler_cycle_budget_ms"));

   // derived flags
   ComputeRuntimeFlags();
   ComputeStageFlags();

   // invalid combinations
   ValidateInvalidCombinations();

   // snapshot copy
   m_snapshot.safe_mode=GetBool("safe_mode");
   m_snapshot.run_first_cycle_in_oninit=GetBool("run_first_cycle_in_oninit");
   m_snapshot.bypass_locks=GetBool("bypass_locks");
   m_snapshot.minimal_debug_mode=GetBool("minimal_debug_mode");
   m_snapshot.isolation_mode=GetBool("isolation_mode");

   m_snapshot.gate_runtime_scheduler_requested=GetBool("gate_runtime_scheduler_requested");
   m_snapshot.gate_timer_heavy_requested=GetBool("gate_timer_heavy_requested");
   m_snapshot.gate_menu_engine_requested=GetBool("gate_menu_engine_requested");
   m_snapshot.gate_chart_ui_requested=GetBool("gate_chart_ui_requested");
   m_snapshot.gate_tick_heavy_requested=GetBool("gate_tick_heavy_requested");
   m_snapshot.gate_ui_projection_requested=GetBool("gate_ui_projection_requested");

   m_snapshot.runtime_scheduler_enabled=GetBool("runtime_scheduler_enabled");
   m_snapshot.runtime_scheduler_layer_enabled=GetBool("runtime_scheduler_layer_enabled");
   m_snapshot.timer_heavy_work_enabled=GetBool("timer_heavy_work_enabled");
   m_snapshot.tick_heavy_work_enabled=GetBool("tick_heavy_work_enabled");
   m_snapshot.menu_engine_enabled=GetBool("menu_engine_enabled");
   m_snapshot.chart_ui_updates_enabled=GetBool("chart_ui_updates_enabled");
   m_snapshot.ui_projection_enabled=GetBool("ui_projection_enabled");

   m_snapshot.include_custom_symbols=GetBool("include_custom_symbols");
   m_snapshot.ea2_deep_profile_default=GetBool("ea2_deep_profile_default");

   m_snapshot.project_stage_status_root=GetBool("project_stage_status_root");
   m_snapshot.project_universe_snapshot=GetBool("project_universe_snapshot");
   m_snapshot.project_debug_snapshots=GetBool("project_debug_snapshots");

   for(int i=0;i<5;i++)
     {
      m_snapshot.ea_requested[i]=GetBool((i==0)?"ea1_enabled":(i==1)?"ea2_enabled":(i==2)?"ea3_enabled":(i==3)?"ea4_enabled":"ea5_enabled");
      m_snapshot.ea_enabled[i]=GetBool((i==0)?"ea1_enabled_effective":(i==1)?"ea2_enabled_effective":(i==2)?"ea3_enabled_effective":(i==3)?"ea4_enabled_effective":"ea5_enabled_effective");
     }

   m_snapshot.ea1_hydration_batch=MathMax(1,GetInt("ea1_hydration_batch"));
   m_snapshot.ea1_max_symbols=MathMax(0,GetInt("ea1_max_symbols"));
   m_snapshot.ea1_rolling_batch_size=MathMax(1,GetInt("ea1_rolling_batch_size"));
   m_snapshot.ea1_rolling_cadence_sec=MathMax(1,GetInt("ea1_rolling_cadence_sec"));
   m_snapshot.ea1_rolling_max_snapshots=MathMax(1,GetInt("ea1_rolling_max_snapshots"));
   m_snapshot.ea1_publish_cadence_sec=MathMax(1,GetInt("ea1_publish_cadence_sec"));
   m_snapshot.ea2_max_symbols_per_slice=MathMax(1,GetInt("ea2_max_symbols_per_slice"));
   m_snapshot.scheduler_cycle_budget_ms=MathMax(1,GetInt("scheduler_cycle_budget_ms"));
   m_snapshot.lock_stale_after_sec=MathMax(1,GetInt("lock_stale_after_sec"));

   m_snapshot.firm_id=GetString("firm_id");
   m_snapshot.instance_tag=GetString("instance_tag");

   ComputeDerivedValues();
   AuditRequiredLookupKeys();

   m_snapshot.initialized=true;

   DumpConfigSummary();
   Print("ISSX: config_init_complete valid=",(m_snapshot.valid?"true":"false"));
  }

   bool GetBool(const string key) const
  {
   const int idx=FindKey(m_bool_keys,key);
   if(idx>=0)
      return m_bool_values[idx];
   LogUnknownKey("bool",key);
   return false;
  }

int GetInt(const string key) const
  {
   const int idx=FindKey(m_int_keys,key);
   if(idx>=0)
      return m_int_values[idx];
   LogUnknownKey("int",key);
   return 0;
  }

double GetDouble(const string key) const
  {
   const int idx=FindKey(m_double_keys,key);
   if(idx>=0)
      return m_double_values[idx];
   LogUnknownKey("double",key);
   return 0.0;
  }

string GetString(const string key) const
  {
   const int idx=FindKey(m_string_keys,key);
   if(idx>=0)
      return m_string_values[idx];
   LogUnknownKey("string",key);
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

   bool IsValid() const
     {
      return m_snapshot.valid;
     }
     
     int EffectivePublishCadenceSec() const
  {
   return m_snapshot.effective_publish_cadence_sec;
  }

int EffectiveSnapshotRetention() const
  {
   return m_snapshot.effective_snapshot_retention;
  }

int EffectiveRollingBatchSize() const
  {
   return m_snapshot.effective_rolling_batch_size;
  }

int EffectiveSchedulerCycleBudgetMs() const
  {
   return m_snapshot.effective_scheduler_cycle_budget_ms;
  }

bool EffectiveProjectionEnabled() const
  {
   return m_snapshot.effective_projection_enabled;
  }

bool EffectivePublishEnabled() const
  {
   return m_snapshot.effective_publish_enabled;
  }
};

#endif
