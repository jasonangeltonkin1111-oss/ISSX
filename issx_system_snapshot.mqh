#ifndef __ISSX_SYSTEM_SNAPSHOT_MQH__
#define __ISSX_SYSTEM_SNAPSHOT_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_runtime.mqh>

// ISSX SYSTEM SNAPSHOT v1.728

class ISSX_SystemSnapshot
  {
public:
   static string SanitizeAndBoundText(const string value,const int max_chars)
     {
      string src=value;
      string out="";
      const int src_len=StringLen(src);
      for(int i=0;i<src_len && StringLen(out)<max_chars;i++)
        {
         const ushort ch=(ushort)StringGetCharacter(src,i);
         if(ch==0)
            continue;
         if(ch<32 && ch!='\r' && ch!='\n' && ch!='\t')
           {
            out+=" ";
            continue;
           }
         out+=ShortToString((short)ch);
        }
      return out;
     }

   static string HydrationStateLabel(const int symbols,const int hydrated)
     {
      if(symbols<=0)
         return (hydrated<=0 ? "not_applicable" : "invalid_counts");
      if(hydrated<=0)
         return "not_started";
      if(hydrated<symbols)
         return "in_progress";
      if(hydrated==symbols)
         return "complete";
      return "capped_overflow";
     }

   static string DumpSystemState(const ISSX_RuntimeState &runtime_state,
                                 const int ea1_symbols,
                                 const int ea2_hydrated,
                                 const int ea3_frontier,
                                 const int ea4_pairs,
                                 const int ea5_exports,
                                 const long estimated_memory_bytes,
                                 const string last_error)
     {
      const int MAX_SNAPSHOT_ERROR_CHARS=160;
      const int safe_ea1_symbols=MathMax(0,ea1_symbols);
      const int safe_ea2_hydrated=MathMax(0,ea2_hydrated);
      const int safe_ea3_frontier=MathMax(0,ea3_frontier);
      const int safe_ea4_pairs=MathMax(0,ea4_pairs);
      const int safe_ea5_exports=MathMax(0,ea5_exports);
      const string bounded_error=SanitizeAndBoundText(last_error,MAX_SNAPSHOT_ERROR_CHARS);

      double hydration_progress=0.0;
      if(safe_ea1_symbols>0)
        {
         hydration_progress=(double)safe_ea2_hydrated/(double)safe_ea1_symbols;
         if(hydration_progress<0.0)
            hydration_progress=0.0;
         if(hydration_progress>1.0)
            hydration_progress=1.0;
        }

      const ISSX_StageId stage_id=runtime_state.scheduler.stage_slot;
      const bool stage_is_known=(stage_id>=issx_stage_ea1 && stage_id<=issx_stage_ea5);
      const bool effective_forced_service_due=(runtime_state.forced_service_due_flag ||
                                               runtime_state.budgets.forced_service_due_flag ||
                                               runtime_state.kernel.kernel_forced_service_due_flag);
      const bool effective_degraded_cycle=(runtime_state.budgets.degraded_cycle_flag ||
                                           runtime_state.kernel.kernel_degraded_cycle_flag);

      ISSX_JsonWriter j;
      j.Reset();
      j.BeginObject();
      j.NameString("snapshot_schema","issx.system_snapshot.v1");
      j.NameLong("cycle",runtime_state.scheduler_cycle_no);
      j.NameLong("kernel_minute",runtime_state.kernel.kernel_minute_id);

      j.BeginNamedObject("stage_states");
      j.NameInt("scheduler_stage",(int)stage_id);
      j.NameString("scheduler_stage_label",ISSX_StageIdToString(stage_id));
      j.NameBool("scheduler_stage_known",stage_is_known);
      j.NameBool("stage_finished_this_minute",(stage_is_known && runtime_state.scheduler.stage_finished_this_minute));
      j.NameInt("current_phase",(int)runtime_state.current_phase);
      j.NameString("current_phase_label",ISSX_PhaseIdToString(runtime_state.current_phase));
      j.EndObject();

      j.BeginNamedObject("symbol_counts");
      j.NameInt("ea1_symbols",safe_ea1_symbols);
      j.NameInt("ea2_hydrated",safe_ea2_hydrated);
      j.NameInt("ea3_frontier",safe_ea3_frontier);
      j.NameInt("ea4_pairs",safe_ea4_pairs);
      j.NameInt("ea5_exports",safe_ea5_exports);
      j.EndObject();

      j.NameLong("memory_bytes",MathMax((long)0,estimated_memory_bytes));

      j.BeginNamedObject("runtime_flags");
      j.NameBool("forced_service_due",effective_forced_service_due);
      j.NameBool("degraded_cycle",effective_degraded_cycle);
      j.NameBool("quote_clock_idle",runtime_state.quote_clock_idle_flag);
      j.EndObject();

      j.NameDouble("hydration_progress",hydration_progress,4);
      j.NameString("hydration_state",HydrationStateLabel(safe_ea1_symbols,safe_ea2_hydrated));
      j.NameString("last_error",bounded_error);
      j.EndObject();
      return j.ToString();
     }
  };

#endif
