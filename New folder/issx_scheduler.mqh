#ifndef __ISSX_SCHEDULER_MQH__
#define __ISSX_SCHEDULER_MQH__

#include <ISSX/issx_core.mqh>

// ISSX SCHEDULER v1.734
#define ISSX_SCHEDULER_MODULE_VERSION "1.734"

#define ISSX_SCHEDULER_MAX_STAGES 16
#define ISSX_SCHEDULER_TIMER_GUARD_MS 1

enum ISSX_SchedulerStagePriority
  {
   issx_sched_prio_critical = 0,   // market freshness, acquisition
   issx_sched_prio_high     = 1,   // history / snapshot maintenance
   issx_sched_prio_normal   = 2,   // analysis / intelligence
   issx_sched_prio_low      = 3    // publish / telemetry / optional work
  };

enum ISSX_SchedulerStageCadence
  {
   issx_sched_cadence_every_cycle = 0,
   issx_sched_cadence_tick_driven = 1,
   issx_sched_cadence_timed       = 2
  };

enum ISSX_SchedulerStageResult
  {
   issx_sched_result_none = 0,
   issx_sched_result_success,
   issx_sched_result_skipped,
   issx_sched_result_deferred,
   issx_sched_result_invalid_data,
   issx_sched_result_failed,
   issx_sched_result_budget_exceeded,
   issx_sched_result_not_ready
  };

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
   bool   m_budget_exhausted;
   int    m_skipped_budget;
   int    m_skipped_quota;
   int    m_stages_pending;
   int    m_stages_completed;
   int    m_stages_deferred;
   int    m_stages_failed;
   int    m_stages_invalid;
   int    m_stages_not_ready;
   int    m_stages_success;
   int    m_processed_count;

   string m_stage_names[ISSX_SCHEDULER_MAX_STAGES];
   long   m_stage_time_us[ISSX_SCHEDULER_MAX_STAGES];
   ulong  m_stage_last_run_us[ISSX_SCHEDULER_MAX_STAGES];
   ulong  m_stage_started_us[ISSX_SCHEDULER_MAX_STAGES];
   ulong  m_stage_finished_us[ISSX_SCHEDULER_MAX_STAGES];
   int    m_stage_last_batch_limit[ISSX_SCHEDULER_MAX_STAGES];

   int    m_stage_priority[ISSX_SCHEDULER_MAX_STAGES];
   bool   m_stage_essential[ISSX_SCHEDULER_MAX_STAGES];
   int    m_stage_cadence_type[ISSX_SCHEDULER_MAX_STAGES];
   int    m_stage_cadence_sec[ISSX_SCHEDULER_MAX_STAGES];

   int    m_stage_cycle_seen[ISSX_SCHEDULER_MAX_STAGES];
   int    m_stage_cycle_completed[ISSX_SCHEDULER_MAX_STAGES];
   int    m_stage_cycle_deferred[ISSX_SCHEDULER_MAX_STAGES];
   int    m_stage_cycle_failed[ISSX_SCHEDULER_MAX_STAGES];
   int    m_stage_cycle_invalid[ISSX_SCHEDULER_MAX_STAGES];
   int    m_stage_cycle_not_ready[ISSX_SCHEDULER_MAX_STAGES];

   string m_stage_last_reason[ISSX_SCHEDULER_MAX_STAGES];
   int    m_stage_last_result[ISSX_SCHEDULER_MAX_STAGES];

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
            m_stage_started_us[i]=0;
            m_stage_finished_us[i]=0;
            m_stage_last_batch_limit[i]=0;

            m_stage_priority[i]=issx_sched_prio_normal;
            m_stage_essential[i]=false;
            m_stage_cadence_type[i]=issx_sched_cadence_every_cycle;
            m_stage_cadence_sec[i]=0;

            m_stage_cycle_seen[i]=0;
            m_stage_cycle_completed[i]=0;
            m_stage_cycle_deferred[i]=0;
            m_stage_cycle_failed[i]=0;
            m_stage_cycle_invalid[i]=0;
            m_stage_cycle_not_ready[i]=0;

            m_stage_last_reason[i]="none";
            m_stage_last_result[i]=issx_sched_result_none;
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

   string ResultText(const int result) const
     {
      switch(result)
        {
         case issx_sched_result_success:         return "success";
         case issx_sched_result_skipped:         return "skipped";
         case issx_sched_result_deferred:        return "deferred";
         case issx_sched_result_invalid_data:    return "invalid_data";
         case issx_sched_result_failed:          return "failed";
         case issx_sched_result_budget_exceeded: return "budget_exceeded";
         case issx_sched_result_not_ready:       return "not_ready";
         default:                                return "none";
        }
     }

   string PriorityText(const int priority) const
     {
      switch(priority)
        {
         case issx_sched_prio_critical: return "critical";
         case issx_sched_prio_high:     return "high";
         case issx_sched_prio_normal:   return "normal";
         case issx_sched_prio_low:      return "low";
         default:                       return "normal";
        }
     }

   bool IsCadenceDue(const int idx) const
     {
      if(idx<0)
         return false;

      const int cadence_type=m_stage_cadence_type[idx];
      const int cadence_sec=m_stage_cadence_sec[idx];

      if(cadence_type==issx_sched_cadence_every_cycle)
         return true;

      if(cadence_type==issx_sched_cadence_tick_driven)
         return true;

      if(cadence_type==issx_sched_cadence_timed)
        {
         if(cadence_sec<=0)
            return true;

         if(m_stage_last_run_us[idx]<=0)
            return true;

         const ulong now_us=(ulong)GetMicrosecondCount();
         const ulong elapsed_us=now_us-m_stage_last_run_us[idx];
         return ((int)(elapsed_us/1000000)>=cadence_sec);
        }

      return true;
     }

   bool BudgetRemainingInternal(const int required_ms,const bool essential_stage) const
     {
      if(!m_enabled || !m_cycle_active)
         return true;

      const ulong elapsed_us=(ulong)GetMicrosecondCount()-m_cycle_start_us;
      const long elapsed_ms=(long)(elapsed_us/1000);
      const long remaining_ms=(long)m_cycle_budget_ms-elapsed_ms;
      const long guarded_required_ms=(long)MathMax(0,required_ms)+(long)ISSX_SCHEDULER_TIMER_GUARD_MS;

      if(remaining_ms>=guarded_required_ms)
         return true;

      // Essential stages get one last chance if we have not yet blown past budget badly.
      if(essential_stage && remaining_ms>0)
         return true;

      return false;
     }

   int EstimatedRequiredMs(const int idx,const int fallback_ms,const int item_limit=0) const
     {
      int required_ms=MathMax(0,fallback_ms);

      if(idx<0)
         return MathMax(1,required_ms);

      if(item_limit>0 && m_stage_time_us[idx]>0)
        {
         int prev_limit=m_stage_last_batch_limit[idx];
         if(prev_limit<=0)
            prev_limit=1;

         const double unit_us=((double)m_stage_time_us[idx])/((double)prev_limit);
         const double estimate_us=unit_us*(double)item_limit;
         required_ms=(int)MathCeil(estimate_us/1000.0);
        }

      if(required_ms<1)
         required_ms=1;

      return required_ms;
     }

   void MarkStageSeen(const int idx)
     {
      if(idx<0)
         return;

      if(m_stage_cycle_seen[idx]==0)
        {
         m_stage_cycle_seen[idx]=1;
         m_stages_pending++;
        }
     }

   void MarkStageResultInternal(const int idx,const int result,const string reason,const long elapsed_us=0)
     {
      if(idx<0)
         return;

      m_processed_count++;
      m_stage_last_result[idx]=result;
      m_stage_last_reason[idx]=reason;

      if(m_stage_started_us[idx]>0 && m_stage_finished_us[idx]<=0)
         m_stage_finished_us[idx]=(ulong)GetMicrosecondCount();

      if(elapsed_us>=0)
         m_stage_time_us[idx]=elapsed_us;

      if(result==issx_sched_result_success)
        {
         if(m_stage_cycle_completed[idx]==0)
           {
            m_stage_cycle_completed[idx]=1;
            m_stages_completed++;
            m_stages_success++;
           }
        }
      else if(result==issx_sched_result_skipped || result==issx_sched_result_deferred || result==issx_sched_result_budget_exceeded)
        {
         if(m_stage_cycle_deferred[idx]==0)
           {
            m_stage_cycle_deferred[idx]=1;
            m_stages_deferred++;
           }
        }
      else if(result==issx_sched_result_failed)
        {
         if(m_stage_cycle_failed[idx]==0)
           {
            m_stage_cycle_failed[idx]=1;
            m_stages_failed++;
           }
        }
      else if(result==issx_sched_result_invalid_data)
        {
         if(m_stage_cycle_invalid[idx]==0)
           {
            m_stage_cycle_invalid[idx]=1;
            m_stages_invalid++;
           }
        }
      else if(result==issx_sched_result_not_ready)
        {
         if(m_stage_cycle_not_ready[idx]==0)
           {
            m_stage_cycle_not_ready[idx]=1;
            m_stages_not_ready++;
           }
        }
     }

   bool ShouldPaceStage(const int idx) const
     {
      if(idx<0)
         return false;

      const ulong now_us=(ulong)GetMicrosecondCount();

      // Only non-essential stages get pacing suppression.
      if(m_stage_essential[idx])
         return false;

      if(m_stage_last_run_us[idx]>0 && (now_us-m_stage_last_run_us[idx])<250000)
         return true;

      return false;
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
      m_budget_exhausted=false;
      m_skipped_budget=0;
      m_skipped_quota=0;
      m_stages_pending=0;
      m_stages_completed=0;
      m_stages_deferred=0;
      m_stages_failed=0;
      m_stages_invalid=0;
      m_stages_not_ready=0;
      m_stages_success=0;
      m_processed_count=0;

      for(int i=0;i<ISSX_SCHEDULER_MAX_STAGES;i++)
        {
         m_stage_names[i]="";
         m_stage_time_us[i]=0;
         m_stage_last_run_us[i]=0;
         m_stage_started_us[i]=0;
         m_stage_finished_us[i]=0;
         m_stage_last_batch_limit[i]=0;

         m_stage_priority[i]=issx_sched_prio_normal;
         m_stage_essential[i]=false;
         m_stage_cadence_type[i]=issx_sched_cadence_every_cycle;
         m_stage_cadence_sec[i]=0;

         m_stage_cycle_seen[i]=0;
         m_stage_cycle_completed[i]=0;
         m_stage_cycle_deferred[i]=0;
         m_stage_cycle_failed[i]=0;
         m_stage_cycle_invalid[i]=0;
         m_stage_cycle_not_ready[i]=0;

         m_stage_last_reason[i]="none";
         m_stage_last_result[i]=issx_sched_result_none;
        }
     }

   void RegisterStage(const string stage_name,
                      const int priority=issx_sched_prio_normal,
                      const bool essential=false,
                      const int cadence_type=issx_sched_cadence_every_cycle,
                      const int cadence_sec=0)
     {
      int idx=StageIndex(stage_name);
      if(idx<0)
         return;

      m_stage_priority[idx]=priority;
      m_stage_essential[idx]=essential;
      m_stage_cadence_type[idx]=cadence_type;
      m_stage_cadence_sec[idx]=MathMax(0,cadence_sec);
     }

   bool BeginCycle()
     {
      m_cycle_no++;
      m_cycle_active=true;
      m_cycle_start_us=(ulong)GetMicrosecondCount();

      m_degraded=false;
      m_budget_exhausted=false;
      m_skipped_budget=0;
      m_skipped_quota=0;
      m_stages_pending=0;
      m_stages_completed=0;
      m_stages_deferred=0;
      m_stages_failed=0;
      m_stages_invalid=0;
      m_stages_not_ready=0;
      m_stages_success=0;
      m_processed_count=0;

      for(int i=0;i<ISSX_SCHEDULER_MAX_STAGES;i++)
        {
         m_stage_cycle_seen[i]=0;
         m_stage_cycle_completed[i]=0;
         m_stage_cycle_deferred[i]=0;
         m_stage_cycle_failed[i]=0;
         m_stage_cycle_invalid[i]=0;
         m_stage_cycle_not_ready[i]=0;
        }

      if(IsSampled())
         Print("scheduler_cycle_start cycle=",ISSX_Util::ULongToStringX(m_cycle_no),
               " enabled=",(m_enabled?"on":"off"),
               " budget_ms=",IntegerToString(m_cycle_budget_ms));

      return true;
     }

   bool BudgetRemaining(const int required_ms)
     {
      return BudgetRemainingInternal(required_ms,false);
     }

   bool CycleBudgetExceeded() const
     {
      if(!m_cycle_active)
         return false;
      const ulong elapsed_us=(ulong)GetMicrosecondCount()-m_cycle_start_us;
      return ((int)(elapsed_us/1000)>=m_cycle_budget_ms);
     }

   bool IsDegraded() const
     {
      return m_degraded;
     }

   long CycleElapsedMs() const
     {
      if(!m_cycle_active)
         return 0;
      const ulong elapsed_us=(ulong)GetMicrosecondCount()-m_cycle_start_us;
      return (long)(elapsed_us/1000);
     }

   bool RunStage(const string stage_name,const int budget_ms)
     {
      return RunStageEx(stage_name,budget_ms,issx_sched_prio_normal,false,issx_sched_cadence_every_cycle,0);
     }

   bool RunStageEx(const string stage_name,
                   const int budget_ms,
                   const int priority,
                   const bool essential,
                   const int cadence_type,
                   const int cadence_sec)
     {
      if(!m_enabled)
         return true;

      if(!m_cycle_active)
         return false;

      RegisterStage(stage_name,priority,essential,cadence_type,cadence_sec);

      const int idx=StageIndex(stage_name);
      if(idx<0)
         return false;

      MarkStageSeen(idx);

      if(m_budget_exhausted && !m_stage_essential[idx])
        {
         m_degraded=true;
         MarkStageResultInternal(idx,issx_sched_result_deferred,"budget_already_exhausted",0);
         if(IsSampled())
            Print("scheduler_stage_deferred stage=",stage_name," reason=budget_already_exhausted");
         return false;
        }

      if(!IsCadenceDue(idx))
        {
         m_degraded=true;
         MarkStageResultInternal(idx,issx_sched_result_deferred,"cadence_not_due",0);
         if(IsSampled())
            Print("scheduler_stage_deferred stage=",stage_name," reason=cadence_not_due");
         return false;
        }

      if(ShouldPaceStage(idx))
        {
         m_skipped_quota++;
         m_degraded=true;
         MarkStageResultInternal(idx,issx_sched_result_deferred,"pacing",0);
         if(IsSampled())
            Print("scheduler_stage_deferred stage=",stage_name," reason=pacing");
         return false;
        }

      const int required_ms=EstimatedRequiredMs(idx,budget_ms,0);
      if(!BudgetRemainingInternal(required_ms,m_stage_essential[idx]))
        {
         m_skipped_budget++;
         m_degraded=true;
         m_budget_exhausted=true;
         MarkStageResultInternal(idx,issx_sched_result_budget_exceeded,"budget_exceeded",0);
         if(IsSampled())
            Print("scheduler_stage_deferred stage=",stage_name,
                  " reason=budget_exceeded required_ms=",IntegerToString(required_ms),
                  " priority=",PriorityText(m_stage_priority[idx]),
                  " essential=",(m_stage_essential[idx]?"true":"false"));
         return false;
        }

      m_stage_last_run_us[idx]=(ulong)GetMicrosecondCount();
      m_stage_started_us[idx]=m_stage_last_run_us[idx];
      m_stage_finished_us[idx]=0;

      if(IsSampled())
         Print("scheduler_stage_allowed stage=",stage_name,
               " budget_ms=",IntegerToString(required_ms),
               " priority=",PriorityText(m_stage_priority[idx]),
               " essential=",(m_stage_essential[idx]?"true":"false"));

      return true;
     }

   bool RunBatch(const string stage_name,const int item_limit)
     {
      return RunBatchEx(stage_name,item_limit,issx_sched_prio_normal,false,issx_sched_cadence_every_cycle,0);
     }

   bool RunBatchEx(const string stage_name,
                   const int item_limit,
                   const int priority,
                   const bool essential,
                   const int cadence_type,
                   const int cadence_sec)
     {
      if(!m_enabled)
         return true;

      if(!m_cycle_active)
         return false;

      RegisterStage(stage_name,priority,essential,cadence_type,cadence_sec);

      const int idx=StageIndex(stage_name);
      if(idx<0)
         return false;

      MarkStageSeen(idx);

      if(m_budget_exhausted && !m_stage_essential[idx])
        {
         m_degraded=true;
         MarkStageResultInternal(idx,issx_sched_result_deferred,"budget_already_exhausted",0);
         if(IsSampled())
            Print("scheduler_stage_deferred stage=",stage_name," reason=budget_already_exhausted");
         return false;
        }

      if(!IsCadenceDue(idx))
        {
         m_degraded=true;
         MarkStageResultInternal(idx,issx_sched_result_deferred,"cadence_not_due",0);
         if(IsSampled())
            Print("scheduler_stage_deferred stage=",stage_name," reason=cadence_not_due");
         return false;
        }

      if(ShouldPaceStage(idx))
        {
         m_skipped_quota++;
         m_degraded=true;
         MarkStageResultInternal(idx,issx_sched_result_deferred,"pacing",0);
         if(IsSampled())
            Print("scheduler_stage_deferred stage=",stage_name," reason=pacing");
         return false;
        }

      int bounded=item_limit;
      if(bounded<0)
         bounded=0;

      if(bounded==0)
        {
         MarkStageResultInternal(idx,issx_sched_result_not_ready,"empty_batch",0);
         return false;
        }

      if(CycleElapsedMs()>=(m_cycle_budget_ms*80)/100 && !m_stage_essential[idx])
        {
         if(bounded>1)
            bounded=MathMax(1,bounded/2);
         m_degraded=true;
        }

      const int required_ms=EstimatedRequiredMs(idx,1,bounded);
      if(!BudgetRemainingInternal(required_ms,m_stage_essential[idx]))
        {
         m_skipped_budget++;
         m_degraded=true;
         m_budget_exhausted=true;
         MarkStageResultInternal(idx,issx_sched_result_budget_exceeded,"budget_exceeded",0);
         if(IsSampled())
            Print("scheduler_stage_deferred stage=",stage_name,
                  " reason=budget_exceeded required_ms=",IntegerToString(required_ms),
                  " batch_limit=",IntegerToString(bounded),
                  " priority=",PriorityText(m_stage_priority[idx]),
                  " essential=",(m_stage_essential[idx]?"true":"false"));
         return false;
        }

      m_stage_last_batch_limit[idx]=bounded;
      m_stage_last_run_us[idx]=(ulong)GetMicrosecondCount();
      m_stage_started_us[idx]=m_stage_last_run_us[idx];
      m_stage_finished_us[idx]=0;

      if(IsSampled())
         Print("scheduler_stage_allowed stage=",stage_name,
               " batch_limit=",IntegerToString(bounded),
               " priority=",PriorityText(m_stage_priority[idx]),
               " essential=",(m_stage_essential[idx]?"true":"false"));

      return true;
     }

   int LastBatchLimit(const string stage_name,const int fallback_limit)
     {
      if(!m_enabled)
         return fallback_limit;

      const int idx=StageIndex(stage_name);
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

   void MarkStageStarted(const string stage_name)
     {
      int idx=StageIndex(stage_name);
      if(idx<0)
         return;

      m_stage_started_us[idx]=(ulong)GetMicrosecondCount();
      m_stage_finished_us[idx]=0;
      m_stage_last_run_us[idx]=m_stage_started_us[idx];
     }

   void MarkStageFinished(const string stage_name,const long elapsed_us)
     {
      int idx=StageIndex(stage_name);
      if(idx<0)
         return;

      m_stage_finished_us[idx]=(ulong)GetMicrosecondCount();
      m_stage_time_us[idx]=MathMax(0,elapsed_us);
     }

   void MarkStageSkipped(const string stage_name,const string reason)
     {
      MarkStageResult(stage_name,issx_sched_result_skipped,reason,0);
     }

   void MarkStageInvalidData(const string stage_name,const string reason)
     {
      MarkStageResult(stage_name,issx_sched_result_invalid_data,reason,0);
     }

   long StageLastElapsedMs(const string stage_name)
     {
      int idx=StageIndex(stage_name);
      if(idx<0)
         return 0;
      return (long)(m_stage_time_us[idx]/1000);
     }

   ulong StageStartedUs(const string stage_name)
     {
      int idx=StageIndex(stage_name);
      if(idx<0)
         return 0;
      return m_stage_started_us[idx];
     }

   ulong StageFinishedUs(const string stage_name)
     {
      int idx=StageIndex(stage_name);
      if(idx<0)
         return 0;
      return m_stage_finished_us[idx];
     }

   void MarkStageResult(const string stage_name,const int result,const string reason,const long elapsed_us=0)
     {
      int idx=StageIndex(stage_name);
      if(idx<0)
         return;

      MarkStageResultInternal(idx,result,reason,elapsed_us);

      if(result==issx_sched_result_failed ||
         result==issx_sched_result_invalid_data ||
         result==issx_sched_result_not_ready ||
         result==issx_sched_result_deferred ||
         result==issx_sched_result_budget_exceeded)
         m_degraded=true;

      if(IsSampled() || result!=issx_sched_result_success)
         Print("scheduler_stage_result stage=",stage_name,
               " result=",ResultText(result),
               " reason=",reason,
               " elapsed_ms=",IntegerToString((int)(MathMax(0,elapsed_us)/1000)));
     }

   int StageLastResult(const string stage_name)
     {
      int idx=StageIndex(stage_name);
      if(idx<0)
         return issx_sched_result_none;
      return m_stage_last_result[idx];
     }

   string StageLastReason(const string stage_name)
     {
      int idx=StageIndex(stage_name);
      if(idx<0)
         return "unknown_stage";
      return m_stage_last_reason[idx];
     }

   void EndCycle()
     {
      if(!m_cycle_active)
         return;

      const ulong elapsed_us=(ulong)GetMicrosecondCount()-m_cycle_start_us;

      if(IsSampled() || m_degraded || m_budget_exhausted)
        {
         Print("scheduler_cycle_end cycle=",ISSX_Util::ULongToStringX(m_cycle_no),
               " elapsed_ms=",IntegerToString((int)(elapsed_us/1000)),
               " degraded=",(m_degraded?"true":"false"),
               " budget_exhausted=",(m_budget_exhausted?"true":"false"),
               " pending=",IntegerToString(m_stages_pending),
               " completed=",IntegerToString(m_stages_completed),
               " success=",IntegerToString(m_stages_success),
               " deferred=",IntegerToString(m_stages_deferred),
               " failed=",IntegerToString(m_stages_failed),
               " invalid=",IntegerToString(m_stages_invalid),
               " not_ready=",IntegerToString(m_stages_not_ready),
               " skipped_budget=",IntegerToString(m_skipped_budget),
               " skipped_quota=",IntegerToString(m_skipped_quota),
               " processed_count=",IntegerToString(m_processed_count));

         for(int i=0;i<ISSX_SCHEDULER_MAX_STAGES;i++)
           {
            if(m_stage_names[i]=="")
               continue;
            if(m_stage_cycle_seen[i]==0)
               continue;

            Print("scheduler_stage_telemetry stage=",m_stage_names[i],
                  " started_us=",ISSX_Util::ULongToStringX(m_stage_started_us[i]),
                  " finished_us=",ISSX_Util::ULongToStringX(m_stage_finished_us[i]),
                  " elapsed_ms=",IntegerToString((int)(m_stage_time_us[i]/1000)),
                  " outcome=",ResultText(m_stage_last_result[i]),
                  " reason=",m_stage_last_reason[i]);
           }
        }

      m_cycle_active=false;
     }
  };

#endif // __ISSX_SCHEDULER_MQH__