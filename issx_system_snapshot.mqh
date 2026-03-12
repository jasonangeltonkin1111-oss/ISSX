#ifndef __ISSX_SYSTEM_SNAPSHOT_MQH__
#define __ISSX_SYSTEM_SNAPSHOT_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_runtime.mqh>

// ISSX SYSTEM SNAPSHOT v1.727

class ISSX_SystemSnapshot
  {
public:
   static string DumpSystemState(const ISSX_RuntimeState &runtime_state,
                                 const int ea1_symbols,
                                 const int ea2_hydrated,
                                 const int ea3_frontier,
                                 const int ea4_pairs,
                                 const int ea5_exports,
                                 const long estimated_memory_bytes,
                                 const string last_error)
     {
      const int MAX_SNAPSHOT_ERROR_CHARS=256;
      string bounded_error=last_error;
      if(StringLen(bounded_error)>MAX_SNAPSHOT_ERROR_CHARS)
         bounded_error=StringSubstr(bounded_error,0,MAX_SNAPSHOT_ERROR_CHARS);

      double hydration_progress=0.0;
      if(ea1_symbols>0)
        {
         hydration_progress=(double)ea2_hydrated/(double)ea1_symbols;
         if(hydration_progress<0.0)
            hydration_progress=0.0;
         if(hydration_progress>1.0)
            hydration_progress=1.0;
        }

      ISSX_JsonWriter j;
      j.Reset();
      j.BeginObject();
      j.NameLong("cycle",runtime_state.scheduler_cycle_no);
      j.NameLong("kernel_minute",runtime_state.kernel.kernel_minute_id);

      j.BeginNamedObject("stage_states");
      j.NameInt("scheduler_stage",runtime_state.scheduler.stage_slot);
      j.NameBool("stage_finished_this_minute",runtime_state.scheduler.stage_finished_this_minute);
      j.NameInt("current_phase",runtime_state.current_phase);
      j.EndObject();

      j.BeginNamedObject("symbol_counts");
      j.NameInt("ea1_symbols",MathMax(0,ea1_symbols));
      j.NameInt("ea2_hydrated",MathMax(0,ea2_hydrated));
      j.NameInt("ea3_frontier",MathMax(0,ea3_frontier));
      j.NameInt("ea4_pairs",MathMax(0,ea4_pairs));
      j.NameInt("ea5_exports",MathMax(0,ea5_exports));
      j.EndObject();

      j.NameLong("memory_bytes",MathMax((long)0,estimated_memory_bytes));

      j.BeginNamedObject("runtime_flags");
      j.NameBool("forced_service_due",runtime_state.forced_service_due_flag);
      j.NameBool("degraded_cycle",runtime_state.budgets.degraded_cycle_flag);
      j.NameBool("quote_clock_idle",runtime_state.quote_clock_idle_flag);
      j.EndObject();

      j.NameDouble("hydration_progress",hydration_progress,4);
      j.NameString("last_error",bounded_error);
      j.EndObject();
      return j.ToString();
     }
  };

#endif
