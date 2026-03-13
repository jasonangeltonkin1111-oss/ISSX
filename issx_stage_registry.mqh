#ifndef __ISSX_STAGE_REGISTRY_MQH__
#define __ISSX_STAGE_REGISTRY_MQH__

#include <ISSX/issx_core.mqh>

// ISSX STAGE REGISTRY INFRA v1.734

enum ISSX_InfraStageState
  {
   issx_infra_stage_unknown=0,
   issx_infra_stage_booting,
   issx_infra_stage_ready,
   issx_infra_stage_degraded,
   issx_infra_stage_blocked
  };

struct ISSX_InfraStageSpec
  {
   ISSX_StageId stage_id;
   string       stage_name;
   bool         required_stage;
   bool         registered_flag;
   bool         enabled_flag;
   int          priority_order;
   string       dependency_csv;
   string       disabled_reason;

   void Reset()
     {
      stage_id=issx_stage_unknown;
      stage_name="";
      required_stage=false;
      registered_flag=false;
      enabled_flag=false;
      priority_order=0;
      dependency_csv="";
      disabled_reason="none";
     }
  };
  
struct ISSX_InfraStageRecord
  {
   ISSX_StageId         stage_id;
   ISSX_InfraStageState state;
   string               reason;
   long                 elapsed_ms;
   long                 update_mono_ms;

   void Reset()
     {
      stage_id=issx_stage_unknown;
      state=issx_infra_stage_unknown;
      reason="none";
      elapsed_ms=0;
      update_mono_ms=0;
     }
  };

#define ISSX_INFRA_STAGE_COUNT 5

class ISSX_InfraStageRegistry
  {
private:
   ISSX_InfraStageRecord m_rows[ISSX_INFRA_STAGE_COUNT];
   ISSX_InfraStageSpec   m_specs[ISSX_INFRA_STAGE_COUNT];

   ISSX_StageId StageIdAt(const int index) const
     {
      switch(index)
        {
         case 0: return issx_stage_ea1;
         case 1: return issx_stage_ea2;
         case 2: return issx_stage_ea3;
         case 3: return issx_stage_ea4;
         case 4: return issx_stage_ea5;
         default: return issx_stage_unknown;
        }
     }

   int Idx(const ISSX_StageId stage_id) const
     {
      for(int i=0;i<ISSX_INFRA_STAGE_COUNT;i++)
        {
         if(StageIdAt(i)==stage_id)
            return i;
        }
      return -1;
     }

   string CanonicalStageName(const ISSX_StageId stage_id) const
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return "ea1_market";
         case issx_stage_ea2: return "ea2_history";
         case issx_stage_ea3: return "ea3_selection";
         case issx_stage_ea4: return "ea4_correlation";
         case issx_stage_ea5: return "ea5_contracts";
         default:             return "unknown";
        }
     }

   string CanonicalDependencies(const ISSX_StageId stage_id) const
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return "runtime_ready,symbol_valid,live_tick,recent_tick,rates_valid,snapshot_valid";
         case issx_stage_ea2: return "ea1_market,history_access";
         case issx_stage_ea3: return "ea1_market,ea2_history";
         case issx_stage_ea4: return "ea3_selection";
         case issx_stage_ea5: return "ea1_market,ea2_history,ea3_selection,ea4_correlation";
         default:             return "";
        }
     }

   string NormalizeReason(const string reason) const
     {
      if(ISSX_Util::IsEmpty(reason))
         return "none";
      return reason;
     }

public:
   void Reset()
     {
      for(int i=0;i<ISSX_INFRA_STAGE_COUNT;i++)
        {
         const ISSX_StageId sid=StageIdAt(i);

         m_rows[i].Reset();
         m_rows[i].stage_id=sid;

         m_specs[i].Reset();
         m_specs[i].stage_id=sid;
         m_specs[i].stage_name=CanonicalStageName(sid);
         m_specs[i].required_stage=true;
         m_specs[i].registered_flag=true;
         m_specs[i].enabled_flag=false;
         m_specs[i].priority_order=i+1;
         m_specs[i].dependency_csv=CanonicalDependencies(sid);
         m_specs[i].disabled_reason="requested_off";
        }
     }

   void SeedCanonicalRequiredStages(const bool ea1_enabled,
                                    const bool ea2_enabled,
                                    const bool ea3_enabled,
                                    const bool ea4_enabled,
                                    const bool ea5_enabled)
     {
      Reset();

      SetEnabled(issx_stage_ea1,ea1_enabled,(ea1_enabled?"none":"requested_off"));
      SetEnabled(issx_stage_ea2,ea2_enabled,(ea2_enabled?"none":"requested_off"));
      SetEnabled(issx_stage_ea3,ea3_enabled,(ea3_enabled?"none":"requested_off"));
      SetEnabled(issx_stage_ea4,ea4_enabled,(ea4_enabled?"none":"requested_off"));
      SetEnabled(issx_stage_ea5,ea5_enabled,(ea5_enabled?"none":"requested_off"));
     }

   int RequiredStageCount() const
     {
      int n=0;
      for(int i=0;i<ISSX_INFRA_STAGE_COUNT;i++)
         if(m_specs[i].required_stage)
            n++;
      return n;
     }

   int RegisteredStageCount() const
     {
      int n=0;
      for(int i=0;i<ISSX_INFRA_STAGE_COUNT;i++)
         if(m_specs[i].registered_flag)
            n++;
      return n;
     }

   string StageName(const ISSX_StageId stage_id) const
     {
      const int i=Idx(stage_id);
      if(i<0)
         return "unknown";
      return m_specs[i].stage_name;
     }

   bool Exists(const ISSX_StageId stage_id) const
     {
      const int i=Idx(stage_id);
      return (i>=0);
     }

   bool IsRegistered(const ISSX_StageId stage_id) const
     {
      const int i=Idx(stage_id);
      if(i<0)
         return false;
      return m_specs[i].registered_flag;
     }

   bool IsEnabled(const ISSX_StageId stage_id) const
     {
      const int i=Idx(stage_id);
      if(i<0)
         return false;
      return m_specs[i].enabled_flag;
     }

   int Priority(const ISSX_StageId stage_id) const
     {
      const int i=Idx(stage_id);
      if(i<0)
         return 0;
      return m_specs[i].priority_order;
     }

   string Dependencies(const ISSX_StageId stage_id) const
     {
      const int i=Idx(stage_id);
      if(i<0)
         return "";
      return m_specs[i].dependency_csv;
     }

   string DisabledReason(const ISSX_StageId stage_id) const
     {
      const int i=Idx(stage_id);
      if(i<0)
         return "stage_missing";
      return m_specs[i].disabled_reason;
     }

   void SetEnabled(const ISSX_StageId stage_id,const bool enabled_flag,const string disabled_reason="none")
     {
      const int i=Idx(stage_id);
      if(i<0)
         return;
      m_specs[i].enabled_flag=enabled_flag;
      m_specs[i].disabled_reason=(enabled_flag ? "none" : NormalizeReason(disabled_reason));
     }

   void SetPriority(const ISSX_StageId stage_id,const int priority_order)
     {
      const int i=Idx(stage_id);
      if(i<0)
         return;
      m_specs[i].priority_order=priority_order;
     }

   void SetDependencies(const ISSX_StageId stage_id,const string dependency_csv)
     {
      const int i=Idx(stage_id);
      if(i<0)
         return;
      m_specs[i].dependency_csv=NormalizeReason(dependency_csv);
     }

   void SetState(const ISSX_StageId stage_id,const ISSX_InfraStageState state)
     {
      const int i=Idx(stage_id);
      if(i<0)
         return;
      m_rows[i].state=state;
      m_rows[i].update_mono_ms=(long)GetTickCount64();
     }

   void SetReason(const ISSX_StageId stage_id,const string reason)
     {
      const int i=Idx(stage_id);
      if(i<0)
         return;
      m_rows[i].reason=NormalizeReason(reason);
      m_rows[i].update_mono_ms=(long)GetTickCount64();
     }

   void SetElapsed(const ISSX_StageId stage_id,const long elapsed_ms)
     {
      const int i=Idx(stage_id);
      if(i<0)
         return;
      m_rows[i].elapsed_ms=(elapsed_ms<0 ? 0 : elapsed_ms);
      m_rows[i].update_mono_ms=(long)GetTickCount64();
     }

   ISSX_InfraStageRecord Get(const ISSX_StageId stage_id) const
     {
      const int i=Idx(stage_id);
      ISSX_InfraStageRecord r;
      r.Reset();
      if(i>=0)
         r=m_rows[i];
      return r;
     }

   ISSX_InfraStageSpec GetSpec(const ISSX_StageId stage_id) const
     {
      const int i=Idx(stage_id);
      ISSX_InfraStageSpec s;
      s.Reset();
      if(i>=0)
         s=m_specs[i];
      return s;
     }

   bool ValidateRequiredStages(string &reason) const
     {
      reason="ok";

      for(int i=0;i<ISSX_INFRA_STAGE_COUNT;i++)
        {
         if(!m_specs[i].required_stage)
            continue;

         if(ISSX_Util::IsEmpty(m_specs[i].stage_name))
           {
            reason="stage_name_missing";
            return false;
           }

         if(!m_specs[i].registered_flag)
           {
            reason=m_specs[i].stage_name+"_not_registered";
            return false;
           }

         if(m_specs[i].priority_order<=0)
           {
            reason=m_specs[i].stage_name+"_priority_missing";
            return false;
           }

         if(ISSX_Util::IsEmpty(m_specs[i].dependency_csv))
           {
            reason=m_specs[i].stage_name+"_dependency_missing";
            return false;
           }

         if(!m_specs[i].enabled_flag && ISSX_Util::IsEmpty(m_specs[i].disabled_reason))
           {
            reason=m_specs[i].stage_name+"_disabled_reason_missing";
            return false;
           }

         if(m_rows[i].stage_id==issx_stage_unknown)
           {
            reason=m_specs[i].stage_name+"_state_missing";
            return false;
           }

         if(!m_specs[i].enabled_flag && m_rows[i].reason=="none")
           {
            reason=m_specs[i].stage_name+"_off_reason_missing";
            return false;
           }
        }

      return true;
     }

   string BuildSummary() const
     {
      string names="";
      string missing="";
      string disabled="";

      for(int i=0;i<ISSX_INFRA_STAGE_COUNT;i++)
        {
         if(i>0)
            names+=",";

         names+=m_specs[i].stage_name;

         if(!m_specs[i].registered_flag)
           {
            if(StringLen(missing)>0)
               missing+=",";
            missing+=m_specs[i].stage_name;
           }

         if(!m_specs[i].enabled_flag)
           {
            if(StringLen(disabled)>0)
               disabled+=",";
            disabled+=m_specs[i].stage_name+"("+m_specs[i].disabled_reason+")";
           }
        }

      if(StringLen(missing)<=0)
         missing="none";
      if(StringLen(disabled)<=0)
         disabled="none";

      return "required_stage_count="+IntegerToString(RequiredStageCount())+
             " registered_stage_count="+IntegerToString(RegisteredStageCount())+
             " names="+names+
             " missing_stages="+missing+
             " disabled_stages="+disabled;
     }

   void DumpSummary() const
     {
      Print("ISSX: stage_registry_summary ",BuildSummary());

      for(int i=0;i<ISSX_INFRA_STAGE_COUNT;i++)
        {
         Print("ISSX: stage_registry_item",
               " stage=",m_specs[i].stage_name,
               " required=",(m_specs[i].required_stage?"yes":"no"),
               " registered=",(m_specs[i].registered_flag?"yes":"no"),
               " enabled=",(m_specs[i].enabled_flag?"yes":"no"),
               " priority=",IntegerToString(m_specs[i].priority_order),
               " dependencies=",m_specs[i].dependency_csv,
               " disabled_reason=",m_specs[i].disabled_reason,
               " state=",IntegerToString((int)m_rows[i].state),
               " reason=",m_rows[i].reason,
               " elapsed_ms=",ISSX_Util::LongToStringX(m_rows[i].elapsed_ms));
        }
     }
  };

#undef ISSX_INFRA_STAGE_COUNT
#endif
