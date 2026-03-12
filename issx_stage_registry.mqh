#ifndef __ISSX_STAGE_REGISTRY_MQH__
#define __ISSX_STAGE_REGISTRY_MQH__

#include <ISSX/issx_core.mqh>

// ISSX STAGE REGISTRY INFRA v1.722

enum ISSX_InfraStageState
  {
   issx_infra_stage_unknown=0,
   issx_infra_stage_booting,
   issx_infra_stage_ready,
   issx_infra_stage_degraded,
   issx_infra_stage_blocked
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

class ISSX_InfraStageRegistry
  {
private:
   ISSX_InfraStageRecord m_rows[5];

   int Idx(const ISSX_StageId stage_id) const
     {
      const int i=(int)stage_id-1;
      if(i<0 || i>=5)
         return -1;
      return i;
     }

public:
   void Reset()
     {
      for(int i=0;i<5;i++)
        {
         m_rows[i].Reset();
         m_rows[i].stage_id=(ISSX_StageId)(i+1);
        }
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
      m_rows[i].reason=reason;
      m_rows[i].update_mono_ms=(long)GetTickCount64();
     }

   void SetElapsed(const ISSX_StageId stage_id,const long elapsed_ms)
     {
      const int i=Idx(stage_id);
      if(i<0)
         return;
      m_rows[i].elapsed_ms=elapsed_ms;
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
  };

#endif
