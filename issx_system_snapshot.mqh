#ifndef __ISSX_SYSTEM_SNAPSHOT_MQH__
#define __ISSX_SYSTEM_SNAPSHOT_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_runtime.mqh>

// ISSX SYSTEM SNAPSHOT v1.722

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
      string s="{";
      s+="\"cycle\":"+IntegerToString((int)runtime_state.scheduler_cycle_no)+",";
      s+="\"kernel_minute\":"+IntegerToString((int)runtime_state.kernel.kernel_minute_id)+",";
      s+="\"ea1_symbols\":"+IntegerToString(ea1_symbols)+",";
      s+="\"ea2_hydrated\":"+IntegerToString(ea2_hydrated)+",";
      s+="\"ea3_frontier\":"+IntegerToString(ea3_frontier)+",";
      s+="\"ea4_pairs\":"+IntegerToString(ea4_pairs)+",";
      s+="\"ea5_exports\":"+IntegerToString(ea5_exports)+",";
      s+="\"memory_bytes\":"+LongToString(estimated_memory_bytes)+",";
      s+="\"last_error\":\""+last_error+"\"";
      s+="}";
      return s;
     }
  };

#endif
