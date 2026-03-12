#ifndef __ISSX_SCHEDULER_MQH__
#define __ISSX_SCHEDULER_MQH__

#include <ISSX/issx_core.mqh>

// ISSX SCHEDULER v1.723
#define ISSX_SCHEDULER_MODULE_VERSION "1.725"

#define ISSX_SCHEDULER_MAX_STAGES 16
#define ISSX_SCHEDULER_TIMER_GUARD_MS 1

class ISSX_Scheduler
  {
private:
   bool   m_enabled;
   bool   m_cycle_active;
   ulong  m_cycle_no;
   ulong  m_cycle_start_us;
   int    m_cycle_budget_ms;
   int    m_sample_every;
   bool   m_degraded;
   int    m_skipped_budget;
   int    m_skipped_quota;

   string m_stage_names[ISSX_SCHEDULER_MAX_STAGES];
   long   m_stage_time_us[ISSX_SCHEDULER_MAX_STAGES];
   ulong  m_stage_last_run_us[ISSX_SCHEDULER_MAX_STAGES];
   int    m_stage_last_batch_limit[ISSX_SCHEDULER_MAX_STAGES];

   int StageIndex(const string stage_name)
     {
      for(int i=0;i<ISSX_SCHEDULER_MAX_STAGES;i++)
        {
         if(m_stage_names[i]==stage_name)
            return i;
         if(m_stage_names[i]=="")
           {
            m_stage_names[i]=stage_name;
            m_stage_time_us[i]=0;
            m_stage_last_run_us[i]=0;
            m_stage_last_batch_limit[i]=0;
            return i;
           }
        }
      return -1;
     }

   bool IsSampled() const
     {
      if(m_sample_every<=1)
         return true;
      return ((m_cycle_no%(ulong)m_sample_every)==1);
     }

public:
   void Configure(const bool enabled,const int cycle_budget_ms,const int sample_every=20)
     {
      m_enabled=enabled;
      m_cycle_budget_ms=MathMax(1,cycle_budget_ms);
      m_sample_every=MathMax(1,sample_every);
     }

   void Reset()
     {
      m_enabled=false;
      m_cycle_active=false;
      m_cycle_no=0;
      m_cycle_start_us=0;
      m_cycle_budget_ms=25;
      m_sample_every=20;
      m_degraded=false;
      m_skipped_budget=0;
      m_skipped_quota=0;
      for(int i=0;i<ISSX_SCHEDULER_MAX_STAGES;i++)
        {
         m_stage_names[i]="";
         m_stage_time_us[i]=0;
         m_stage_last_run_us[i]=0;
         m_stage_last_batch_limit[i]=0;
        }
     }

   bool BeginCycle()
     {
      m_cycle_no++;
      m_cycle_active=true;
      m_cycle_start_us=(ulong)GetMicrosecondCount();
      m_degraded=false;
      m_skipped_budget=0;
      m_skipped_quota=0;
      if(IsSampled())
         Print("scheduler_cycle_start cycle=",ISSX_Util::ULongToStringX(m_cycle_no)," enabled=",(m_enabled?"on":"off")," budget_ms=",IntegerToString(m_cycle_budget_ms));
      return true;
     }

   bool BudgetRemaining(const int required_ms)
     {
      if(!m_enabled || !m_cycle_active)
         return true;
      const ulong elapsed_us=(ulong)GetMicrosecondCount()-m_cycle_start_us;
      const long remaining_ms=(long)m_cycle_budget_ms-(long)(elapsed_us/1000);
      const long guarded_required_ms=(long)MathMax(0,required_ms)+(long)ISSX_SCHEDULER_TIMER_GUARD_MS;
      return (remaining_ms>=guarded_required_ms);
     }

   bool ShouldRunStage(const string stage_name)
     {
      if(!m_enabled)
         return true;
      if(!m_cycle_active)
         return false;
      int idx=StageIndex(stage_name);
      if(idx<0)
         return true;
      const ulong now_us=(ulong)GetMicrosecondCount();
      if(m_stage_last_run_us[idx]>0 && (now_us-m_stage_last_run_us[idx])<250000)
         return false;
      return true;
     }

   bool RunStage(const string stage_name,const int budget_ms)
     {
      if(!m_enabled)
         return true;
      if(!m_cycle_active)
         return false;
      const int required_ms=MathMax(0,budget_ms);
      if(!BudgetRemaining(required_ms))
        {
         m_skipped_budget++;
         m_degraded=true;
         if(IsSampled())
            Print("scheduler_stage_skipped_budget stage=",stage_name," required_ms=",IntegerToString(required_ms));
         return false;
        }
      if(!ShouldRunStage(stage_name))
        {
         m_skipped_quota++;
         m_degraded=true;
         if(IsSampled())
            Print("scheduler_stage_skipped_quota stage=",stage_name," reason=pacing");
         return false;
        }
      int idx=StageIndex(stage_name);
      if(idx>=0)
         m_stage_last_run_us[idx]=(ulong)GetMicrosecondCount();

      if(IsSampled())
         Print("scheduler_stage_allowed stage=",stage_name," budget_ms=",IntegerToString(required_ms));
      return true;
     }

   bool RunBatch(const string stage_name,const int item_limit)
     {
      if(!m_enabled)
         return true;
      if(!m_cycle_active)
         return false;
      int idx=StageIndex(stage_name);
      if(idx<0)
         return true;

      if(!ShouldRunStage(stage_name))
        {
         m_skipped_quota++;
         m_degraded=true;
         if(IsSampled())
            Print("scheduler_stage_skipped_quota stage=",stage_name," reason=pacing");
         return false;
        }

      int bounded=item_limit;
      if(bounded<0)
         bounded=0;

      int prev_limit=m_stage_last_batch_limit[idx];
      if(prev_limit<=0)
         prev_limit=1;

      const ulong elapsed_us=(ulong)GetMicrosecondCount()-m_cycle_start_us;
      const int elapsed_ms=(int)(elapsed_us/1000);
      if(elapsed_ms>=(m_cycle_budget_ms*80)/100)
        {
         if(bounded>1)
            bounded=MathMax(1,bounded/2);
         m_degraded=true;
        }

      int required_ms=1;
      if(m_stage_time_us[idx]>0 && bounded>0)
        {
         const double unit_us=((double)m_stage_time_us[idx])/((double)prev_limit);
         const double estimate_us=unit_us*(double)bounded;
         required_ms=(int)MathCeil(estimate_us/1000.0);
         if(required_ms<1)
            required_ms=1;
        }

      if(!BudgetRemaining(required_ms))
        {
         m_skipped_budget++;
         m_degraded=true;
         if(IsSampled())
            Print("scheduler_stage_skipped_budget stage=",stage_name," reason=batch_budget_exhausted required_ms=",IntegerToString(required_ms));
         return false;
        }

      m_stage_last_batch_limit[idx]=bounded;
      m_stage_last_run_us[idx]=(ulong)GetMicrosecondCount();

      if(IsSampled())
         Print("scheduler_stage_allowed stage=",stage_name," batch_limit=",IntegerToString(m_stage_last_batch_limit[idx]));
      return true;
     }

   int LastBatchLimit(const string stage_name,const int fallback_limit)
     {
      if(!m_enabled)
         return fallback_limit;
      int idx=StageIndex(stage_name);
      if(idx<0)
         return fallback_limit;
      if(m_stage_last_batch_limit[idx]<=0)
         return fallback_limit;
      return m_stage_last_batch_limit[idx];
     }

   void RecordStageTime(const string stage_name,const long elapsed_us)
     {
      int idx=StageIndex(stage_name);
      if(idx<0)
         return;
      m_stage_time_us[idx]=MathMax(0,elapsed_us);
      m_stage_last_run_us[idx]=(ulong)GetMicrosecondCount();
     }

   void EndCycle()
     {
      if(!m_cycle_active)
         return;
      const ulong elapsed_us=(ulong)GetMicrosecondCount()-m_cycle_start_us;
      if(IsSampled() || m_degraded)
         Print("scheduler_cycle_end cycle=",ISSX_Util::ULongToStringX(m_cycle_no),
               " elapsed_ms=",IntegerToString((int)(elapsed_us/1000)),
               " degraded=",(m_degraded?"true":"false"),
               " skipped_budget=",IntegerToString(m_skipped_budget),
               " skipped_quota=",IntegerToString(m_skipped_quota));
      m_cycle_active=false;
     }
  };

#endif // __ISSX_SCHEDULER_MQH__
