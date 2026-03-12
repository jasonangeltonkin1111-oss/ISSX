#ifndef __ISSX_SYSTEM_SNAPSHOT_MQH__
#define __ISSX_SYSTEM_SNAPSHOT_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_runtime.mqh>

// ISSX SYSTEM SNAPSHOT v1.723

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

      string s="{";
      s+="\"cycle\":"+IntegerToString((int)runtime_state.scheduler_cycle_no)+",";
      s+="\"kernel_minute\":"+IntegerToString((int)runtime_state.kernel.kernel_minute_id)+",";
      s+="\"stage_states\":{";
      s+="\"scheduler_stage\":"+IntegerToString((int)runtime_state.scheduler.stage_slot)+",";
      s+="\"stage_finished_this_minute\":"+(runtime_state.scheduler.stage_finished_this_minute ? "true" : "false")+",";
      s+="\"current_phase\":"+IntegerToString((int)runtime_state.current_phase)+"},";
      s+="\"symbol_counts\":{";
      s+="\"ea1_symbols\":"+IntegerToString(ea1_symbols)+",";
      s+="\"ea2_hydrated\":"+IntegerToString(ea2_hydrated)+",";
      s+="\"ea3_frontier\":"+IntegerToString(ea3_frontier)+",";
      s+="\"ea4_pairs\":"+IntegerToString(ea4_pairs)+",";
      s+="\"ea5_exports\":"+IntegerToString(ea5_exports)+"},";
      s+="\"ea2_hydrated\":"+IntegerToString(ea2_hydrated)+",";
      s+="\"ea3_frontier\":"+IntegerToString(ea3_frontier)+",";
      s+="\"ea4_pairs\":"+IntegerToString(ea4_pairs)+",";
      s+="\"ea5_exports\":"+IntegerToString(ea5_exports)+",";
      s+="\"memory_bytes\":"+LongToString(estimated_memory_bytes)+",";
      s+="\"runtime_flags\":{";
      s+="\"forced_service_due\":"+(runtime_state.forced_service_due_flag ? "true" : "false")+",";
      s+="\"degraded_cycle\":"+(runtime_state.budgets.degraded_cycle_flag ? "true" : "false")+",";
      s+="\"quote_clock_idle\":"+(runtime_state.quote_clock_idle_flag ? "true" : "false")+"},";
      s+="\"hydration_progress\":"+ISSX_Util::DoubleToStringX(hydration_progress,4)+",";
      s+="\"last_error\":\""+ISSX_Util::EscapeJson(bounded_error)+"\"";
      s+="}";
      return s;
     }
  };

#endif
