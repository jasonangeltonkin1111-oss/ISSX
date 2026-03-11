#ifndef __ISSX_RUNTIME_MQH__
#define __ISSX_RUNTIME_MQH__

#include <ISSX/issx_core.mqh>

// ============================================================================
// ISSX RUNTIME v1.7.2
// Canonical runtime owner for scheduler / timer-lossiness / budgets / fairness /
// resumable phase state in the single-wrapper five-stage ISSX architecture.
//
// OWNER DISCIPLINE
// - This file owns runtime-local scheduler, phase, queue, and budget surfaces.
// - Shared semantic enums / DTOs still belong to issx_core.mqh.
// - No stage business logic belongs here.
// - No duplicate shared JSON helper family is allowed here.
// - Include identity is canonicalized to <ISSX/...> only.
//
// HARDENING
// - preserved compatibility aliases for older code paths
// - defaults remain unknown / neutral unless explicitly sampled
// - decode helpers fail honest instead of pretending restore success
// - kernel budget surface sync is explicit and centralized
// - stage/phase ownership helpers are runtime-owned to reduce future drift
// - numeric helpers remain explicit to avoid narrowing / sign-loss warnings
// ============================================================================

// Backward-compatible aliases while the consolidated runtime owns the
// canonical scheduler / budget / runtime structs.
#define ISSX_RuntimeBudget ISSX_RuntimeBudgets
#define ISSX_PhaseState    ISSX_PhaseSchedulerState
#define ISSX_RuntimeStats  ISSX_RuntimeState

// Runtime owner metadata helpers.
// These are additive-safe and do not rename any existing public surface.
#define ISSX_RUNTIME_OWNER_MODULE_NAME   "issx_runtime.mqh"
#define ISSX_RUNTIME_STAGE_API_VERSION   ISSX_STAGE_API_VERSION
#define ISSX_RUNTIME_SERIALIZER_VERSION  ISSX_SERIALIZER_VERSION

#define ISSX_RUNTIME_UNKNOWN_AGE_MS      (-1L)
#define ISSX_RUNTIME_UNKNOWN_INT         (-1)
#define ISSX_RUNTIME_UNKNOWN_DOUBLE      (-1.0)

// ============================================================================
// SECTION 01: RUNTIME ENUMS
// ============================================================================

enum ISSX_QueuePriorityClass
  {
   issx_priority_unknown = 0,
   issx_priority_low     = 1,
   issx_priority_normal  = 2,
   issx_priority_high    = 3,
   issx_priority_forced  = 4
  };

enum ISSX_PhaseId
  {
   issx_phase_none = 0,

   // Kernel lifecycle
   issx_phase_kernel_boot_restore      = 1,
   issx_phase_kernel_clock_sample      = 2,
   issx_phase_kernel_budget_allocation = 3,
   issx_phase_kernel_due_scan          = 4,
   issx_phase_kernel_publish_fastlane  = 5,

   // EA1
   issx_phase_ea1_boot              = 100,
   issx_phase_ea1_restore           = 101,
   issx_phase_ea1_discover_symbols  = 102,
   issx_phase_ea1_probe_specs       = 103,
   issx_phase_ea1_sample_runtime    = 104,
   issx_phase_ea1_classify          = 105,
   issx_phase_ea1_family_resolution = 106,
   issx_phase_ea1_tradeability      = 107,
   issx_phase_ea1_dump_universe     = 108,
   issx_phase_ea1_publish           = 109,
   issx_phase_ea1_snapshot          = 110,

   // EA2
   issx_phase_ea2_boot              = 200,
   issx_phase_ea2_restore           = 201,
   issx_phase_ea2_load_upstream     = 202,
   issx_phase_ea2_history_warm      = 203,
   issx_phase_ea2_history_deep      = 204,
   issx_phase_ea2_validate_finality = 205,
   issx_phase_ea2_rewrite_scan      = 206,
   issx_phase_ea2_build_metrics     = 207,
   issx_phase_ea2_build_context     = 208,
   issx_phase_ea2_flush_warehouse   = 209,
   issx_phase_ea2_publish           = 210,
   issx_phase_ea2_snapshot          = 211,

   // EA3
   issx_phase_ea3_boot             = 300,
   issx_phase_ea3_restore          = 301,
   issx_phase_ea3_load_upstream    = 302,
   issx_phase_ea3_bucket_rebuild   = 303,
   issx_phase_ea3_family_collapse  = 304,
   issx_phase_ea3_rank_lanes       = 305,
   issx_phase_ea3_frontier         = 306,
   issx_phase_ea3_continuity       = 307,
   issx_phase_ea3_publish          = 308,
   issx_phase_ea3_snapshot         = 309,

   // EA4
   issx_phase_ea4_boot             = 400,
   issx_phase_ea4_restore          = 401,
   issx_phase_ea4_load_frontier    = 402,
   issx_phase_ea4_pair_queue       = 403,
   issx_phase_ea4_overlap          = 404,
   issx_phase_ea4_clusters         = 405,
   issx_phase_ea4_permissions      = 406,
   issx_phase_ea4_abstention       = 407,
   issx_phase_ea4_publish          = 408,
   issx_phase_ea4_snapshot         = 409,

   // EA5
   issx_phase_ea5_boot             = 500,
   issx_phase_ea5_load_sources     = 501,
   issx_phase_ea5_merge            = 502,
   issx_phase_ea5_history_pack     = 503,
   issx_phase_ea5_legend           = 504,
   issx_phase_ea5_byte_budget      = 505,
   issx_phase_ea5_publish          = 506,
   issx_phase_ea5_snapshot         = 507
  };

// Runtime-owned legacy phase compatibility aliases.
// These preserve older stage code while keeping canonical phase ownership here.
#define issx_phase_ea3_build_bucket_sets_delta_first  issx_phase_ea3_bucket_rebuild
#define issx_phase_ea3_rank_buckets                   issx_phase_ea3_rank_lanes
#define issx_phase_ea3_assign_reserves                issx_phase_ea3_frontier
#define issx_phase_ea3_build_frontier                 issx_phase_ea3_frontier
#define issx_phase_ea3_update_survivor_continuity     issx_phase_ea3_continuity

enum ISSX_PhaseAbortReason
  {
   issx_phase_abort_none                   = 0,
   issx_phase_abort_budget_exhausted       = 1,
   issx_phase_abort_dependency_missing     = 2,
   issx_phase_abort_queue_empty            = 3,
   issx_phase_abort_cooldown_active        = 4,
   issx_phase_abort_compatibility_fail     = 5,
   issx_phase_abort_manual_invalidation    = 6,
   issx_phase_abort_runtime_cap            = 7,
   issx_phase_abort_work_cap               = 8,
   issx_phase_abort_stage_already_finished = 9,
   issx_phase_abort_reserved_commit_budget = 10,
   issx_phase_abort_clock_anomaly          = 11
  };

enum ISSX_QueueServiceClass
  {
   issx_service_unknown             = 0,
   issx_service_bootstrap           = 1,
   issx_service_delta_first         = 2,
   issx_service_backlog             = 3,
   issx_service_continuity          = 4,
   issx_service_publish_critical    = 5,
   issx_service_optional_enrichment = 6
  };

// ============================================================================
// SECTION 02: DTO TYPES
// ============================================================================

struct ISSX_RuntimeBudgets
  {
   int    discovery_budget_ms;
   int    probe_budget_ms;
   int    quote_sampling_budget_ms;
   int    history_warm_budget_ms;
   int    history_deep_budget_ms;
   int    pair_budget_ms;
   int    cache_budget_ms;
   int    persistence_budget_ms;
   int    publish_budget_ms;
   int    debug_budget_ms;
   int    freshness_fastlane_budget_ms;

   int    budget_total_ms;
   int    budget_reserved_commit_ms;
   int    budget_spent_ms;
   int    budget_debt_ms;
   int    budget_starvation_count;
   double queue_backlog_score;
   bool   forced_service_due_flag;
   bool   degraded_cycle_flag;

   void Reset()
     {
      discovery_budget_ms=0;
      probe_budget_ms=0;
      quote_sampling_budget_ms=0;
      history_warm_budget_ms=0;
      history_deep_budget_ms=0;
      pair_budget_ms=0;
      cache_budget_ms=0;
      persistence_budget_ms=0;
      publish_budget_ms=0;
      debug_budget_ms=0;
      freshness_fastlane_budget_ms=0;

      budget_total_ms=0;
      budget_reserved_commit_ms=0;
      budget_spent_ms=0;
      budget_debt_ms=0;
      budget_starvation_count=0;
      queue_backlog_score=0.0;
      forced_service_due_flag=false;
      degraded_cycle_flag=false;
     }
  };

struct ISSX_PhaseSchedulerState
  {
   ISSX_PhaseId          phase_id;
   long                  phase_epoch_minute;
   int                   phase_attempt_no;
   int                   phase_resume_count;
   int                   phase_budget_ms;
   int                   phase_work_cap;
   int                   phase_work_used;
   long                  phase_started_mono_ms;
   long                  phase_deadline_ms;
   ISSX_PhaseId          phase_last_completed;
   ISSX_PhaseAbortReason phase_aborted_reason;
   string                phase_saved_progress_key;
   ISSX_StageId          stage_slot;
   bool                  stage_finished_this_minute;

   void Reset()
     {
      phase_id=issx_phase_none;
      phase_epoch_minute=0;
      phase_attempt_no=0;
      phase_resume_count=0;
      phase_budget_ms=0;
      phase_work_cap=0;
      phase_work_used=0;
      phase_started_mono_ms=0;
      phase_deadline_ms=0;
      phase_last_completed=issx_phase_none;
      phase_aborted_reason=issx_phase_abort_none;
      phase_saved_progress_key="";
      stage_slot=issx_stage_unknown;
      stage_finished_this_minute=false;
     }
  };

struct ISSX_WorkQueueItem
  {
   string                  symbol_id;
   string                  pair_id;
   string                  queue_reason;
   ISSX_QueuePriorityClass priority;
   ISSX_QueueFamily        queue_family;
   ISSX_QueueServiceClass  service_class;
   ISSX_InvalidationClass  invalidation_class;
   ISSX_PhaseId            target_phase;
   int                     cost_hint;
   int                     work_units_hint;
   int                     retry_count;
   long                    created_mono_ms;
   long                    last_attempt_mono_ms;
   long                    cooldown_until_mono_ms;
   bool                    persistence_required_flag;
   bool                    contender_promotion_flag;
   bool                    changed_symbol_hint_flag;
   bool                    publish_critical_flag;

   void Reset()
     {
      symbol_id="";
      pair_id="";
      queue_reason="";
      priority=issx_priority_unknown;
      queue_family=issx_queue_unknown;
      service_class=issx_service_unknown;
      invalidation_class=issx_invalidation_unknown;
      target_phase=issx_phase_none;
      cost_hint=1;
      work_units_hint=1;
      retry_count=0;
      created_mono_ms=0;
      last_attempt_mono_ms=0;
      cooldown_until_mono_ms=0;
      persistence_required_flag=false;
      contender_promotion_flag=false;
      changed_symbol_hint_flag=false;
      publish_critical_flag=false;
     }
  };

struct ISSX_QueueStats
  {
   int    item_count;
   int    ready_count;
   int    cooling_count;
   int    retry_due_count;
   int    persistent_count;
   int    forced_count;
   int    stale_service_due_count;
   int    overdue_count;
   long   oldest_item_age_ms;
   long   starvation_max_ms;
   bool   forced_service_due_flag;
   double backlog_penalty_applied;
   double service_pressure;
   int    never_serviced_count;
   int    newly_active_symbols_waiting_count;

   void Reset()
     {
      item_count=0;
      ready_count=0;
      cooling_count=0;
      retry_due_count=0;
      persistent_count=0;
      forced_count=0;
      stale_service_due_count=0;
      overdue_count=0;
      oldest_item_age_ms=ISSX_RUNTIME_UNKNOWN_AGE_MS;
      starvation_max_ms=ISSX_RUNTIME_UNKNOWN_AGE_MS;
      forced_service_due_flag=false;
      backlog_penalty_applied=0.0;
      service_pressure=0.0;
      never_serviced_count=0;
      newly_active_symbols_waiting_count=0;
     }
  };

struct ISSX_RuntimeState
  {
   ISSX_ClockStats           clock_stats;
   ISSX_RuntimeBudgets       budgets;
   ISSX_PhaseSchedulerState  scheduler;
   ISSX_KernelSchedulerState kernel;

   // ------------------------------------------------------------------------
   // Legacy compatibility surface still consumed by older stage modules.
   // Keep these mirrors here instead of forcing consumer-local hacks.
   // ------------------------------------------------------------------------
   long                      scheduler_cycle_no;
   int                       local_phase_id;
   ISSX_PhaseId              current_phase;
   string                    current_phase_label;

   long                      queue_starvation_max_ms;
   long                      queue_oldest_item_age_ms;
   bool                      forced_service_due_flag;
   bool                      backlog_penalty_applied;
   bool                      quote_clock_idle_flag;
   int                       time_penalty_applied;
   int                       missed_schedule_windows_estimate;
   string                    weakest_stage_reason;
   ISSX_DebugWeakLinkCode    weak_link_code;
   ISSX_StageId              weakest_stage;
   int                       weak_link_severity;

   void Reset()
     {
      scheduler_cycle_no=0;
      local_phase_id=(int)issx_phase_none;
      current_phase=issx_phase_none;
      current_phase_label="none";

      queue_starvation_max_ms=ISSX_RUNTIME_UNKNOWN_AGE_MS;
      queue_oldest_item_age_ms=ISSX_RUNTIME_UNKNOWN_AGE_MS;
      forced_service_due_flag=false;
      backlog_penalty_applied=false;
      quote_clock_idle_flag=false;
      time_penalty_applied=0;
      missed_schedule_windows_estimate=ISSX_RUNTIME_UNKNOWN_INT;
      weakest_stage_reason="";
      weak_link_code=issx_weak_link_unknown;
      weakest_stage=issx_stage_unknown;
      weak_link_severity=0;

      budgets.Reset();
      scheduler.Reset();
      clock_stats.Reset();
      kernel.Reset();
     }
  };

// ============================================================================
// SECTION 03: HELPER FUNCTIONS
// ============================================================================

string ISSX_Runtime_I64ToString(const long v)
  {
   return StringFormat("%I64d",v);
  }

int ISSX_Runtime_ClampLongToInt(const long v)
  {
   if(v>2147483647L)
      return 2147483647;
   if(v<-2147483648L)
      return -2147483648;
   return (int)v;
  }

int ISSX_Runtime_ClampDoubleToIntFloor(const double v)
  {
   if(v>2147483647.0)
      return 2147483647;
   if(v<-2147483648.0)
      return -2147483648;
   return (int)MathFloor(v);
  }

long ISSX_Runtime_MaxLong(const long a,const long b)
  {
   return (a>b ? a : b);
  }

long ISSX_Runtime_MinLong(const long a,const long b)
  {
   return (a<b ? a : b);
  }

int ISSX_Runtime_AbsDatetimeDiffSec(const datetime a,const datetime b)
  {
   long diff=(long)a-(long)b;
   if(diff<0)
      diff=-diff;
   return ISSX_Runtime_ClampLongToInt(diff);
  }

bool ISSX_Runtime_IsKernelPhase(const ISSX_PhaseId value)
  {
   return (value>=issx_phase_kernel_boot_restore && value<=issx_phase_kernel_publish_fastlane);
  }

bool ISSX_Runtime_IsPublishPhase(const ISSX_PhaseId value)
  {
   switch(value)
     {
      case issx_phase_ea1_publish:
      case issx_phase_ea2_publish:
      case issx_phase_ea3_publish:
      case issx_phase_ea4_publish:
      case issx_phase_ea5_publish:
         return true;
      default:
         return false;
     }
  }

ISSX_StageId ISSX_Runtime_StageOfPhase(const ISSX_PhaseId value)
  {
   const int v=(int)value;
   if(v>=100 && v<200) return issx_stage_ea1;
   if(v>=200 && v<300) return issx_stage_ea2;
   if(v>=300 && v<400) return issx_stage_ea3;
   if(v>=400 && v<500) return issx_stage_ea4;
   if(v>=500 && v<600) return issx_stage_ea5;
   return issx_stage_shared;
  }

string ISSX_PhaseIdToString(const ISSX_PhaseId value)
  {
   switch(value)
     {
      case issx_phase_none: return "none";
      case issx_phase_kernel_boot_restore: return "kernel_boot_restore";
      case issx_phase_kernel_clock_sample: return "kernel_clock_sample";
      case issx_phase_kernel_budget_allocation: return "kernel_budget_allocation";
      case issx_phase_kernel_due_scan: return "kernel_due_scan";
      case issx_phase_kernel_publish_fastlane: return "kernel_publish_fastlane";

      case issx_phase_ea1_boot: return "ea1_boot";
      case issx_phase_ea1_restore: return "ea1_restore";
      case issx_phase_ea1_discover_symbols: return "ea1_discover_symbols";
      case issx_phase_ea1_probe_specs: return "ea1_probe_specs";
      case issx_phase_ea1_sample_runtime: return "ea1_sample_runtime";
      case issx_phase_ea1_classify: return "ea1_classify";
      case issx_phase_ea1_family_resolution: return "ea1_family_resolution";
      case issx_phase_ea1_tradeability: return "ea1_tradeability";
      case issx_phase_ea1_dump_universe: return "ea1_dump_universe";
      case issx_phase_ea1_publish: return "ea1_publish";
      case issx_phase_ea1_snapshot: return "ea1_snapshot";

      case issx_phase_ea2_boot: return "ea2_boot";
      case issx_phase_ea2_restore: return "ea2_restore";
      case issx_phase_ea2_load_upstream: return "ea2_load_upstream";
      case issx_phase_ea2_history_warm: return "ea2_history_warm";
      case issx_phase_ea2_history_deep: return "ea2_history_deep";
      case issx_phase_ea2_validate_finality: return "ea2_validate_finality";
      case issx_phase_ea2_rewrite_scan: return "ea2_rewrite_scan";
      case issx_phase_ea2_build_metrics: return "ea2_build_metrics";
      case issx_phase_ea2_build_context: return "ea2_build_context";
      case issx_phase_ea2_flush_warehouse: return "ea2_flush_warehouse";
      case issx_phase_ea2_publish: return "ea2_publish";
      case issx_phase_ea2_snapshot: return "ea2_snapshot";

      case issx_phase_ea3_boot: return "ea3_boot";
      case issx_phase_ea3_restore: return "ea3_restore";
      case issx_phase_ea3_load_upstream: return "ea3_load_upstream";
      case issx_phase_ea3_bucket_rebuild: return "ea3_bucket_rebuild";
      case issx_phase_ea3_family_collapse: return "ea3_family_collapse";
      case issx_phase_ea3_rank_lanes: return "ea3_rank_lanes";
      case issx_phase_ea3_frontier: return "ea3_frontier";
      case issx_phase_ea3_continuity: return "ea3_continuity";
      case issx_phase_ea3_publish: return "ea3_publish";
      case issx_phase_ea3_snapshot: return "ea3_snapshot";

      case issx_phase_ea4_boot: return "ea4_boot";
      case issx_phase_ea4_restore: return "ea4_restore";
      case issx_phase_ea4_load_frontier: return "ea4_load_frontier";
      case issx_phase_ea4_pair_queue: return "ea4_pair_queue";
      case issx_phase_ea4_overlap: return "ea4_overlap";
      case issx_phase_ea4_clusters: return "ea4_clusters";
      case issx_phase_ea4_permissions: return "ea4_permissions";
      case issx_phase_ea4_abstention: return "ea4_abstention";
      case issx_phase_ea4_publish: return "ea4_publish";
      case issx_phase_ea4_snapshot: return "ea4_snapshot";

      case issx_phase_ea5_boot: return "ea5_boot";
      case issx_phase_ea5_load_sources: return "ea5_load_sources";
      case issx_phase_ea5_merge: return "ea5_merge";
      case issx_phase_ea5_history_pack: return "ea5_history_pack";
      case issx_phase_ea5_legend: return "ea5_legend";
      case issx_phase_ea5_byte_budget: return "ea5_byte_budget";
      case issx_phase_ea5_publish: return "ea5_publish";
      case issx_phase_ea5_snapshot: return "ea5_snapshot";
      default: return "unknown";
     }
  }

string ISSX_PhaseAbortReasonToString(const ISSX_PhaseAbortReason value)
  {
   switch(value)
     {
      case issx_phase_abort_none: return "none";
      case issx_phase_abort_budget_exhausted: return "budget_exhausted";
      case issx_phase_abort_dependency_missing: return "dependency_missing";
      case issx_phase_abort_queue_empty: return "queue_empty";
      case issx_phase_abort_cooldown_active: return "cooldown_active";
      case issx_phase_abort_compatibility_fail: return "compatibility_fail";
      case issx_phase_abort_manual_invalidation: return "manual_invalidation";
      case issx_phase_abort_runtime_cap: return "runtime_cap";
      case issx_phase_abort_work_cap: return "work_cap";
      case issx_phase_abort_stage_already_finished: return "stage_already_finished";
      case issx_phase_abort_reserved_commit_budget: return "reserved_commit_budget";
      case issx_phase_abort_clock_anomaly: return "clock_anomaly";
      default: return "unknown";
     }
  }

string ISSX_QueuePriorityToString(const ISSX_QueuePriorityClass value)
  {
   switch(value)
     {
      case issx_priority_low: return "low";
      case issx_priority_normal: return "normal";
      case issx_priority_high: return "high";
      case issx_priority_forced: return "forced";
      default: return "unknown";
     }
  }

string ISSX_QueueServiceClassToString(const ISSX_QueueServiceClass value)
  {
   switch(value)
     {
      case issx_service_bootstrap: return "bootstrap";
      case issx_service_delta_first: return "delta_first";
      case issx_service_backlog: return "backlog_clearing";
      case issx_service_continuity: return "continuity_preserving";
      case issx_service_publish_critical: return "publish_critical";
      case issx_service_optional_enrichment: return "optional_enrichment";
      default: return "unknown";
     }
  }

// ============================================================================
// SECTION 04: TIME MODEL / TIMER GAP STATS
// ============================================================================

class ISSX_RuntimeClock
  {
private:
   long m_gap_samples[];
   long m_last_pulse_ms;

   static long NowMonoMs()
     {
      return (long)GetTickCount64();
     }

public:
   void Reset()
     {
      ArrayResize(m_gap_samples,0);
      m_last_pulse_ms=0;
     }

   double MeanGap() const
     {
      const int n=ArraySize(m_gap_samples);
      if(n<=0)
         return ISSX_RUNTIME_UNKNOWN_DOUBLE;

      long sum=0;
      for(int i=0;i<n;i++)
         sum+=m_gap_samples[i];
      return ((double)sum/(double)n);
     }

   long P95Gap() const
     {
      const int n=ArraySize(m_gap_samples);
      if(n<=0)
         return ISSX_RUNTIME_UNKNOWN_AGE_MS;

      long tmp[];
      ArrayResize(tmp,n);
      for(int i=0;i<n;i++)
         tmp[i]=m_gap_samples[i];
      ArraySort(tmp);

      int idx=(int)MathFloor((double)(n-1)*0.95);
      if(idx<0)
         idx=0;
      if(idx>=n)
         idx=n-1;
      return tmp[idx];
     }

   long LastPulseMs() const
     {
      return m_last_pulse_ms;
     }

   void OnPulse(ISSX_RuntimeState &state)
     {
      const long now_ms=NowMonoMs();
      long gap=ISSX_RUNTIME_UNKNOWN_AGE_MS;
      if(m_last_pulse_ms>0 && now_ms>=m_last_pulse_ms)
         gap=now_ms-m_last_pulse_ms;
      m_last_pulse_ms=now_ms;

      if(gap>0)
        {
         int n=ArraySize(m_gap_samples);
         if(n>=128)
           {
            for(int i=1;i<n;i++)
               m_gap_samples[i-1]=m_gap_samples[i];
            n--;
            ArrayResize(m_gap_samples,n);
           }
         ArrayResize(m_gap_samples,n+1);
         m_gap_samples[n]=gap;
        }

      const datetime sched_clock=ISSX_Time::BestScheduleClock();
      const datetime fresh_clock=ISSX_Time::BestFreshnessClock();

      long late_ms=ISSX_RUNTIME_UNKNOWN_AGE_MS;
      if(gap>=0)
        {
         late_ms=0;
         if(gap>1500)
            late_ms=(gap-1000);
        }

      state.clock_stats.minute_epoch_source=ISSX_Time::BestMinuteEpochSource();
      state.clock_stats.scheduler_clock_source=ISSX_Time::BestSchedulerClockSource();
      state.clock_stats.freshness_clock_source=ISSX_Time::BestFreshnessClockSource();
      state.clock_stats.timer_gap_ms_now=gap;
      state.clock_stats.timer_gap_ms_p95=P95Gap();
      state.clock_stats.scheduler_late_by_ms=late_ms;
      state.clock_stats.timer_gap_ms_mean=MeanGap();
      state.clock_stats.missed_schedule_windows_estimate=(gap>1000 ? (int)(gap/1000)-1 : ISSX_RUNTIME_UNKNOWN_INT);
      state.clock_stats.quote_clock_idle_flag=(fresh_clock<=0 || gap>5000);
      state.clock_stats.clock_divergence_sec=(double)ISSX_Runtime_AbsDatetimeDiffSec(sched_clock,fresh_clock);
      state.clock_stats.clock_anomaly_flag=(state.clock_stats.clock_divergence_sec>=30.0 || gap>=8000);
      state.clock_stats.time_penalty_applied=(state.clock_stats.clock_anomaly_flag ? 1.0 : 0.0);

      state.clock_stats.clock_sanity_score=1.0;
      if(state.clock_stats.clock_divergence_sec>0.0)
         state.clock_stats.clock_sanity_score=
            MathMax(0.0,1.0-(state.clock_stats.clock_divergence_sec/120.0));

      if(gap>0)
        {
         const double gap_penalty=MathMin(0.50,((double)ISSX_Runtime_MaxLong(0L,gap-1000L)/10000.0));
         state.clock_stats.clock_sanity_score=
            MathMax(0.0,state.clock_stats.clock_sanity_score-gap_penalty);
        }

      state.quote_clock_idle_flag=state.clock_stats.quote_clock_idle_flag;
      state.time_penalty_applied=ISSX_Runtime_ClampDoubleToIntFloor(state.clock_stats.time_penalty_applied);
      state.missed_schedule_windows_estimate=state.clock_stats.missed_schedule_windows_estimate;

      state.kernel.kernel_minute_id=ISSX_Time::MinuteIdFromDatetime(sched_clock);
      state.kernel.scheduler_cycle_no++;
      state.scheduler_cycle_no=state.kernel.scheduler_cycle_no;

      state.kernel.kernel_forced_service_due_flag=state.forced_service_due_flag;
      state.kernel.kernel_degraded_cycle_flag=state.clock_stats.clock_anomaly_flag;

      state.local_phase_id=(int)state.scheduler.phase_id;
      state.current_phase=state.scheduler.phase_id;
      state.current_phase_label=ISSX_PhaseIdToString(state.scheduler.phase_id);
     }
  };

// ============================================================================
// SECTION 05: BUDGET HELPERS
// ============================================================================

class ISSX_BudgetPolicy
  {
public:
   static void ApplyStageDefaults(const ISSX_StageId stage_id,ISSX_RuntimeBudgets &b)
     {
      b.Reset();

      switch(stage_id)
        {
         case issx_stage_ea1:
            b.discovery_budget_ms=110;
            b.probe_budget_ms=150;
            b.quote_sampling_budget_ms=110;
            b.cache_budget_ms=70;
            b.persistence_budget_ms=120;
            b.publish_budget_ms=140;
            b.debug_budget_ms=25;
            b.freshness_fastlane_budget_ms=120;
            b.budget_total_ms=920;
            b.budget_reserved_commit_ms=220;
            break;

         case issx_stage_ea2:
            b.history_warm_budget_ms=170;
            b.history_deep_budget_ms=200;
            b.cache_budget_ms=70;
            b.persistence_budget_ms=120;
            b.publish_budget_ms=140;
            b.debug_budget_ms=20;
            b.freshness_fastlane_budget_ms=90;
            b.budget_total_ms=940;
            b.budget_reserved_commit_ms=240;
            break;

         case issx_stage_ea3:
            b.discovery_budget_ms=60;
            b.cache_budget_ms=90;
            b.persistence_budget_ms=120;
            b.publish_budget_ms=140;
            b.debug_budget_ms=20;
            b.freshness_fastlane_budget_ms=90;
            b.budget_total_ms=760;
            b.budget_reserved_commit_ms=220;
            break;

         case issx_stage_ea4:
            b.pair_budget_ms=210;
            b.cache_budget_ms=90;
            b.persistence_budget_ms=120;
            b.publish_budget_ms=120;
            b.debug_budget_ms=20;
            b.freshness_fastlane_budget_ms=60;
            b.budget_total_ms=740;
            b.budget_reserved_commit_ms=220;
            break;

         case issx_stage_ea5:
            b.cache_budget_ms=90;
            b.persistence_budget_ms=160;
            b.publish_budget_ms=180;
            b.debug_budget_ms=20;
            b.freshness_fastlane_budget_ms=40;
            b.budget_total_ms=700;
            b.budget_reserved_commit_ms=260;
            break;

         default:
            b.discovery_budget_ms=60;
            b.persistence_budget_ms=100;
            b.publish_budget_ms=100;
            b.debug_budget_ms=15;
            b.freshness_fastlane_budget_ms=50;
            b.budget_total_ms=600;
            b.budget_reserved_commit_ms=200;
            break;
        }
     }

   static int RemainingTotalBudget(const ISSX_RuntimeBudgets &b)
     {
      int remaining=b.budget_total_ms-b.budget_spent_ms;
      if(remaining<0)
         remaining=0;
      return remaining;
     }

   static int RemainingCommitBudget(const ISSX_RuntimeBudgets &b)
     {
      int consumed_non_commit=b.budget_spent_ms;
      if(consumed_non_commit<0)
         consumed_non_commit=0;

      int remaining_total=b.budget_total_ms-consumed_non_commit;
      if(remaining_total<0)
         remaining_total=0;

      if(remaining_total>b.budget_reserved_commit_ms)
         return b.budget_reserved_commit_ms;
      return remaining_total;
     }

   static int AvailableNonCommitBudget(const ISSX_RuntimeBudgets &b)
     {
      int free_ms=b.budget_total_ms-b.budget_reserved_commit_ms-b.budget_spent_ms;
      if(free_ms<0)
         free_ms=0;
      return free_ms;
     }

   static bool CanSpend(const ISSX_RuntimeBudgets &b,const int delta_ms)
     {
      if(delta_ms<=0)
         return true;
      return (AvailableNonCommitBudget(b)>=delta_ms);
     }

   static bool CanSpendCommit(const ISSX_RuntimeBudgets &b,const int delta_ms)
     {
      if(delta_ms<=0)
         return true;
      return (RemainingTotalBudget(b)>=delta_ms);
     }

   static void Spend(ISSX_RuntimeBudgets &b,const int delta_ms)
     {
      if(delta_ms<=0)
         return;

      b.budget_spent_ms+=delta_ms;
      if(b.budget_spent_ms>b.budget_total_ms)
         b.budget_debt_ms=(b.budget_spent_ms-b.budget_total_ms);
     }

   static void SpendCommit(ISSX_RuntimeBudgets &b,const int delta_ms)
     {
      if(delta_ms<=0)
         return;

      b.budget_spent_ms+=delta_ms;
      if(b.budget_spent_ms>b.budget_total_ms)
         b.budget_debt_ms=(b.budget_spent_ms-b.budget_total_ms);
     }

   static bool PublishBudgetMustBePreserved(const ISSX_RuntimeBudgets &b)
     {
      return (AvailableNonCommitBudget(b)<=b.publish_budget_ms);
     }

   static int QueueFamilyBudget(const ISSX_RuntimeBudgets &b,const ISSX_QueueFamily family)
     {
      switch(family)
        {
         case issx_queue_discovery:      return b.discovery_budget_ms;
         case issx_queue_probe:          return b.probe_budget_ms;
         case issx_queue_quote_sampling: return b.quote_sampling_budget_ms;
         case issx_queue_history_warm:   return b.history_warm_budget_ms;
         case issx_queue_history_deep:   return b.history_deep_budget_ms;
         case issx_queue_pair:           return b.pair_budget_ms;
         case issx_queue_persistence:    return b.persistence_budget_ms;
         case issx_queue_publish:        return b.publish_budget_ms;
         case issx_queue_debug:          return b.debug_budget_ms;
         case issx_queue_fastlane:       return b.freshness_fastlane_budget_ms;
         default:                        return b.cache_budget_ms;
        }
     }
  };

// ============================================================================
// SECTION 06: PHASE SCHEDULER
// ============================================================================

class ISSX_PhaseScheduler
  {
private:
   static void SyncKernelPhaseSurface(ISSX_RuntimeState &state)
     {
      state.kernel.current_stage_slot=state.scheduler.stage_slot;
      state.kernel.current_stage_phase=ISSX_PhaseIdToString(state.scheduler.phase_id);
      state.kernel.current_stage_budget_ms=(long)state.scheduler.phase_budget_ms;
      state.kernel.current_stage_deadline_ms=state.scheduler.phase_deadline_ms;
     }

public:
   static bool BeginPhase(ISSX_RuntimeState &state,
                          const ISSX_PhaseId phase_id,
                          const int phase_budget_ms,
                          const string progress_key="")
     {
      const long now_ms=(long)GetTickCount64();
      long minute_id=state.kernel.kernel_minute_id;
      if(minute_id<=0)
         minute_id=ISSX_Time::NowMinuteId();

      if(state.scheduler.phase_id==phase_id && state.scheduler.phase_epoch_minute==minute_id)
        {
         state.scheduler.phase_resume_count++;
         state.scheduler.phase_attempt_no++;
        }
      else
        {
         state.scheduler.phase_id=phase_id;
         state.scheduler.phase_epoch_minute=minute_id;
         state.scheduler.phase_attempt_no=1;
         state.scheduler.phase_resume_count=0;
         state.scheduler.phase_work_used=0;
        }

      state.scheduler.phase_budget_ms=MathMax(0,phase_budget_ms);
      state.scheduler.phase_started_mono_ms=now_ms;
      state.scheduler.phase_deadline_ms=(now_ms+(long)MathMax(1,phase_budget_ms));
      state.scheduler.phase_saved_progress_key=progress_key;
      state.scheduler.phase_aborted_reason=issx_phase_abort_none;
      state.scheduler.stage_slot=ISSX_Runtime_StageOfPhase(phase_id);
      state.scheduler.stage_finished_this_minute=false;

      state.local_phase_id=(int)phase_id;
      state.current_phase=phase_id;
      state.current_phase_label=ISSX_PhaseIdToString(phase_id);

      SyncKernelPhaseSurface(state);

      if(state.scheduler.stage_slot>=issx_stage_ea1 && state.scheduler.stage_slot<=issx_stage_ea5)
        {
         const int idx=StageIdToIndex(state.scheduler.stage_slot);
         if(idx>=0)
           {
            state.kernel.stage_last_attempted_service_mono_ms[idx]=now_ms;
            state.kernel.stage_last_run_ms[idx]=now_ms;
           }
        }
      return true;
     }

   static bool ResumeCompatible(const ISSX_RuntimeState &state,
                                const ISSX_PhaseId phase_id,
                                const string progress_key)
     {
      if(state.scheduler.phase_id!=phase_id)
         return false;
      if(state.scheduler.phase_saved_progress_key!=progress_key)
         return false;
      if(state.scheduler.phase_aborted_reason==issx_phase_abort_compatibility_fail)
         return false;
      return true;
     }

   static bool DeadlineHit(const ISSX_RuntimeState &state)
     {
      if(state.scheduler.phase_deadline_ms<=0)
         return false;
      return ((long)GetTickCount64()>=state.scheduler.phase_deadline_ms);
     }

   static bool WorkCapHit(const ISSX_RuntimeState &state)
     {
      if(state.scheduler.phase_work_cap<=0)
         return false;
      return (state.scheduler.phase_work_used>=state.scheduler.phase_work_cap);
     }

   static void ConsumeWork(ISSX_RuntimeState &state,const int units=1)
     {
      if(units>0)
         state.scheduler.phase_work_used+=units;
     }

   static void SetWorkCap(ISSX_RuntimeState &state,const int cap_units)
     {
      state.scheduler.phase_work_cap=MathMax(0,cap_units);
     }

   static void CompletePhase(ISSX_RuntimeState &state)
     {
      state.scheduler.phase_last_completed=state.scheduler.phase_id;
      state.scheduler.phase_aborted_reason=issx_phase_abort_none;
      state.scheduler.stage_finished_this_minute=true;

      if(state.scheduler.stage_slot>=issx_stage_ea1 && state.scheduler.stage_slot<=issx_stage_ea5)
        {
         const int idx=StageIdToIndex(state.scheduler.stage_slot);
         if(idx>=0)
           {
            const long now_ms=(long)GetTickCount64();
            state.kernel.stage_last_successful_service_mono_ms[idx]=now_ms;
            state.kernel.stage_last_run_ms[idx]=now_ms;
            state.kernel.stage_resume_key[idx]=state.scheduler.phase_saved_progress_key;
           }
        }

      state.scheduler.phase_id=issx_phase_none;
      state.scheduler.phase_budget_ms=0;
      state.scheduler.phase_deadline_ms=0;
      state.scheduler.phase_work_cap=0;
      state.scheduler.phase_work_used=0;

      state.local_phase_id=(int)issx_phase_none;
      state.current_phase=issx_phase_none;
      state.current_phase_label="none";

      SyncKernelPhaseSurface(state);
     }

   static void AbortPhase(ISSX_RuntimeState &state,const ISSX_PhaseAbortReason reason)
     {
      state.scheduler.phase_aborted_reason=reason;
      state.scheduler.phase_last_completed=issx_phase_none;
      state.scheduler.stage_finished_this_minute=false;
      state.kernel.kernel_degraded_cycle_flag=(reason!=issx_phase_abort_none);
      SyncKernelPhaseSurface(state);
     }

   static bool FinishedThisMinute(const ISSX_RuntimeState &state,const ISSX_StageId stage_id)
     {
      const int idx=StageIdToIndex(stage_id);
      if(idx<0)
         return false;

      long minute_id=state.kernel.kernel_minute_id;
      if(minute_id<=0)
         minute_id=ISSX_Time::NowMinuteId();

      return (state.kernel.stage_last_publish_minute_id[idx]==minute_id &&
              state.kernel.stage_last_run_ms[idx]>0);
     }
  };

// ============================================================================
// SECTION 07: WORK QUEUE
// ============================================================================

class ISSX_WorkQueue
  {
private:
   ISSX_WorkQueueItem m_items[];
   bool               m_initialized;

   static int PriorityRank(const ISSX_QueuePriorityClass p)
     {
      switch(p)
        {
         case issx_priority_forced: return 400;
         case issx_priority_high:   return 300;
         case issx_priority_normal: return 200;
         case issx_priority_low:    return 100;
         default:                   return 0;
        }
     }

   static double ScoreItem(const ISSX_WorkQueueItem &item,const long now_ms)
     {
      double s=(double)PriorityRank(item.priority);
      const long age_ms=(item.created_mono_ms>0 && now_ms>item.created_mono_ms ? now_ms-item.created_mono_ms : 0);

      s+=MathMin(120.0,(double)age_ms/1000.0);
      s+=MathMin(40.0,(double)item.retry_count*4.0);

      if(item.persistence_required_flag) s+=25.0;
      if(item.publish_critical_flag)     s+=60.0;
      if(item.contender_promotion_flag)  s+=20.0;
      if(item.changed_symbol_hint_flag)  s+=10.0;
      if(item.cooldown_until_mono_ms>now_ms) s-=500.0;

      switch(item.service_class)
        {
         case issx_service_publish_critical:    s+=80.0; break;
         case issx_service_delta_first:         s+=45.0; break;
         case issx_service_bootstrap:           s+=35.0; break;
         case issx_service_continuity:          s+=20.0; break;
         case issx_service_backlog:             s+=10.0; break;
         case issx_service_optional_enrichment: s-=10.0; break;
         default: break;
        }

      return s;
     }

public:
   ISSX_WorkQueue()
     {
      m_initialized=false;
     }

   void Init()
     {
      if(m_initialized)
         return;
      ArrayResize(m_items,0);
      m_initialized=true;
     }

   int Count() const
     {
      return ArraySize(m_items);
     }

   void Clear()
     {
      ArrayResize(m_items,0);
     }

   bool Enqueue(const ISSX_WorkQueueItem &item)
     {
      const int n=ArraySize(m_items);
      if(ArrayResize(m_items,n+1)!=(n+1))
         return false;
      m_items[n]=item;
      return true;
     }

   long CooldownUntil(const int retry_count,const long now_ms) const
     {
      const int backoff_sec=MathMin(300,5*(retry_count+1)*(retry_count+1));
      return (now_ms+((long)backoff_sec*1000));
     }

   bool PopNext(ISSX_WorkQueueItem &out_item,
                ISSX_QueueStats &stats,
                const long now_ms)
     {
      stats.Reset();

      const int n=ArraySize(m_items);
      if(n<=0)
         return false;

      int best_idx=-1;
      double best_score=-1.0e18;

      for(int i=0;i<n;i++)
        {
         const ISSX_WorkQueueItem it=m_items[i];
         const long age_ms=(it.created_mono_ms>0 && now_ms>it.created_mono_ms ? now_ms-it.created_mono_ms : 0);
         const bool ready=(it.cooldown_until_mono_ms<=0 || it.cooldown_until_mono_ms<=now_ms);

         stats.item_count++;
         if(ready) stats.ready_count++; else stats.cooling_count++;
         if(it.retry_count>0 && ready) stats.retry_due_count++;
         if(it.persistence_required_flag) stats.persistent_count++;
         if(it.priority==issx_priority_forced) stats.forced_count++;
         if(age_ms>stats.oldest_item_age_ms) stats.oldest_item_age_ms=age_ms;
         if(age_ms>stats.starvation_max_ms)  stats.starvation_max_ms=age_ms;
         if(it.created_mono_ms<=0) stats.never_serviced_count++;
         if(it.contender_promotion_flag) stats.newly_active_symbols_waiting_count++;
         if(age_ms>120000) stats.overdue_count++;
         if(age_ms>30000)  stats.stale_service_due_count++;
         if(it.priority==issx_priority_forced || age_ms>60000)
            stats.forced_service_due_flag=true;

         const double score=ScoreItem(it,now_ms);
         if(ready && score>best_score)
           {
            best_score=score;
            best_idx=i;
           }
        }

      stats.backlog_penalty_applied=(stats.overdue_count>0 ? MathMin(1.0,(double)stats.overdue_count/20.0) : 0.0);
      stats.service_pressure=(double)stats.ready_count + (double)stats.overdue_count*0.5 + (stats.forced_service_due_flag ? 2.0 : 0.0);

      if(best_idx<0)
         return false;

      out_item=m_items[best_idx];
      for(int j=best_idx+1;j<n;j++)
         m_items[j-1]=m_items[j];
      ArrayResize(m_items,n-1);
      return true;
     }
  };

// ============================================================================
// SECTION 08: RUNTIME POLICY / FAIRNESS
// ============================================================================

class ISSX_RuntimePolicy
  {
private:
   static void SyncKernelBudgetSurface(ISSX_RuntimeState &state)
     {
      state.kernel.kernel_budget_total_ms=(long)state.budgets.budget_total_ms;
      state.kernel.kernel_budget_spent_ms=(long)state.budgets.budget_spent_ms;
      state.kernel.kernel_budget_reserved_commit_ms=(long)state.budgets.budget_reserved_commit_ms;
      state.kernel.kernel_budget_debt_ms=(long)state.budgets.budget_debt_ms;

      if(state.budgets.budget_debt_ms>0)
         state.kernel.kernel_overrun_class=issx_overrun_soft;
      else
         state.kernel.kernel_overrun_class=issx_overrun_none;

      state.kernel.kernel_forced_service_due_flag=(state.kernel.kernel_forced_service_due_flag || state.budgets.forced_service_due_flag);
      state.kernel.kernel_degraded_cycle_flag=(state.kernel.kernel_degraded_cycle_flag || state.budgets.degraded_cycle_flag);
     }

public:
   static int PublishCadenceSec(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea5: return 600;
         case issx_stage_ea1:
         case issx_stage_ea2:
         case issx_stage_ea3:
         case issx_stage_ea4:
            return 60;
         default:
            return 60;
        }
     }

   static int HardMaximumInitialUsableSec(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return 60;
         case issx_stage_ea2: return 120;
         case issx_stage_ea3: return 120;
         case issx_stage_ea4: return 180;
         case issx_stage_ea5: return 120;
         default: return 180;
        }
     }

   static int DefaultWorkCap(const ISSX_QueueFamily queue_family)
     {
      switch(queue_family)
        {
         case issx_queue_discovery:      return 32;
         case issx_queue_probe:          return 24;
         case issx_queue_quote_sampling: return 40;
         case issx_queue_history_warm:   return 6;
         case issx_queue_history_deep:   return 3;
         case issx_queue_bucket_rebuild: return 12;
         case issx_queue_pair:           return 16;
         case issx_queue_repair:         return 8;
         case issx_queue_persistence:    return 6;
         case issx_queue_publish:        return 4;
         case issx_queue_debug:          return 8;
         case issx_queue_fastlane:       return 12;
         default:                        return 8;
        }
     }

   static int StageIndex(const ISSX_StageId stage_id)
     {
      return StageIdToIndex(stage_id);
     }

   static void ApplyStageBudget(ISSX_RuntimeState &state,const ISSX_StageId stage_id)
     {
      ISSX_BudgetPolicy::ApplyStageDefaults(stage_id,state.budgets);
      SyncKernelBudgetSurface(state);
     }

   static void TouchAttempt(ISSX_RuntimeState &state,const ISSX_StageId stage_id,const long now_ms)
     {
      const int idx=StageIndex(stage_id);
      if(idx<0)
         return;

      state.kernel.stage_last_attempted_service_mono_ms[idx]=now_ms;
      if(state.kernel.stage_last_successful_service_mono_ms[idx]<=0)
         state.kernel.stage_missed_due_cycles[idx]++;

      SyncKernelBudgetSurface(state);
     }

   static void TouchSuccess(ISSX_RuntimeState &state,const ISSX_StageId stage_id,const long now_ms,const long minute_id)
     {
      const int idx=StageIndex(stage_id);
      if(idx<0)
         return;

      state.kernel.stage_last_successful_service_mono_ms[idx]=now_ms;
      state.kernel.stage_last_run_ms[idx]=now_ms;
      state.kernel.stage_missed_due_cycles[idx]=0;
      state.kernel.stage_last_publish_minute_id[idx]=minute_id;

      SyncKernelBudgetSurface(state);
     }

   static void SetStageMinimumReady(ISSX_RuntimeState &state,const ISSX_StageId stage_id,const bool ready_flag)
     {
      const int idx=StageIndex(stage_id);
      if(idx<0)
         return;
      state.kernel.stage_minimum_ready_flag[idx]=ready_flag;
     }

   static void MarkDependencyBlock(ISSX_RuntimeState &state,
                                   const ISSX_StageId stage_id,
                                   const string reason)
     {
      const int idx=StageIndex(stage_id);
      if(idx<0)
         return;

      state.kernel.stage_dependency_block_reason[idx]=reason;
      if(reason!="")
        {
         state.weak_link_code=issx_weak_link_dependency_block;
         state.weakest_stage=stage_id;
         state.weakest_stage_reason=reason;
         state.weak_link_severity=MathMax(state.weak_link_severity,60);
        }
     }

   static void ClearDependencyBlock(ISSX_RuntimeState &state,const ISSX_StageId stage_id)
     {
      const int idx=StageIndex(stage_id);
      if(idx<0)
         return;
      state.kernel.stage_dependency_block_reason[idx]="";
     }

   static void ApplyQueuePressure(ISSX_RuntimeState &state,const ISSX_QueueStats &stats)
     {
      state.queue_oldest_item_age_ms=stats.oldest_item_age_ms;
      state.queue_starvation_max_ms=stats.starvation_max_ms;
      state.forced_service_due_flag=(state.forced_service_due_flag || stats.forced_service_due_flag);
      state.backlog_penalty_applied=(stats.backlog_penalty_applied>0.0);
      state.budgets.queue_backlog_score=stats.service_pressure;

      if(stats.forced_service_due_flag || stats.overdue_count>0)
        {
         state.budgets.forced_service_due_flag=true;
         state.kernel.kernel_forced_service_due_flag=true;
         state.weak_link_code=issx_weak_link_queue_backlog;
         state.weak_link_severity=MathMax(state.weak_link_severity,40);
        }

      SyncKernelBudgetSurface(state);
     }

   static void UpdatePublishDueFlags(ISSX_RuntimeState &state,const long now_ms)
     {
      long minute_id=state.kernel.kernel_minute_id;
      if(minute_id<=0)
         minute_id=ISSX_Time::NowMinuteId();

      state.forced_service_due_flag=false;
      state.queue_oldest_item_age_ms=ISSX_RUNTIME_UNKNOWN_AGE_MS;
      state.queue_starvation_max_ms=ISSX_RUNTIME_UNKNOWN_AGE_MS;

      for(int i=0;i<ISSX_STAGE_COUNT;i++)
        {
         const ISSX_StageId stage_id=StageIndexToId(i);
         const int cadence=PublishCadenceSec(stage_id);
         const long last_pub_min=state.kernel.stage_last_publish_minute_id[i];

         bool due=(last_pub_min<=0);
         if(!due && cadence>0)
           {
            const long last_pub_sec=(last_pub_min*60);
            const long now_sec=(minute_id*60);
            due=((now_sec-last_pub_sec)>=cadence);
           }
         state.kernel.stage_publish_due_flag[i]=due;

         const long last_success=state.kernel.stage_last_successful_service_mono_ms[i];
         const long last_attempt=state.kernel.stage_last_attempted_service_mono_ms[i];

         if(last_success>0)
            state.kernel.stage_starvation_score[i]=MathMin(100.0,(double)ISSX_Runtime_MaxLong(0L,now_ms-last_success)/1000.0);
         else
            state.kernel.stage_starvation_score[i]=0.0;

         if(last_attempt>0)
            state.kernel.stage_backlog_score[i]=MathMin(100.0,(double)ISSX_Runtime_MaxLong(0L,now_ms-last_attempt)/1500.0);
         else
            state.kernel.stage_backlog_score[i]=0.0;

         if(state.kernel.stage_starvation_score[i]>=60.0 || state.kernel.stage_missed_due_cycles[i]>=3)
            state.forced_service_due_flag=true;
        }

      state.kernel.kernel_forced_service_due_flag=state.forced_service_due_flag;
      SyncKernelBudgetSurface(state);
     }

   static ISSX_StageId PickNextDueStage(const ISSX_RuntimeState &state)
     {
      double best_score=-1.0e18;
      ISSX_StageId best_stage=issx_stage_unknown;

      for(int i=0;i<ISSX_STAGE_COUNT;i++)
        {
         const ISSX_StageId stage_id=StageIndexToId(i);
         double score=0.0;

         if(state.kernel.stage_publish_due_flag[i]) score+=100.0;
         score+=state.kernel.stage_starvation_score[i]*1.5;
         score+=state.kernel.stage_backlog_score[i];

         if(state.kernel.stage_dependency_block_reason[i]!="") score-=40.0;

         // Protect upstream freshness before deep downstream work.
         if(stage_id==issx_stage_ea5 &&
            (state.kernel.stage_publish_due_flag[0] || state.kernel.stage_publish_due_flag[1] || state.kernel.stage_publish_due_flag[2]))
            score-=60.0;

         if(stage_id==issx_stage_ea4 && state.kernel.stage_starvation_score[2]>=40.0)
            score-=35.0;

         if(stage_id==issx_stage_ea2 && state.kernel.stage_publish_due_flag[0])
            score-=25.0;

         if(score>best_score)
           {
            best_score=score;
            best_stage=stage_id;
           }
        }
      return best_stage;
     }
  };

// ============================================================================
// SECTION 09: RUNTIME CODEC
// ============================================================================

class ISSX_RuntimeCodec
  {
public:
   static string EncodePhaseState(const ISSX_PhaseSchedulerState &s)
     {
      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginObject();
      jw.NameString("phase_id",ISSX_PhaseIdToString(s.phase_id));
      jw.NameLong("phase_epoch_minute",s.phase_epoch_minute);
      jw.NameInt("phase_attempt_no",s.phase_attempt_no);
      jw.NameInt("phase_resume_count",s.phase_resume_count);
      jw.NameInt("phase_budget_ms",s.phase_budget_ms);
      jw.NameInt("phase_work_cap",s.phase_work_cap);
      jw.NameInt("phase_work_used",s.phase_work_used);
      jw.NameLong("phase_started_mono_ms",s.phase_started_mono_ms);
      jw.NameLong("phase_deadline_ms",s.phase_deadline_ms);
      jw.NameString("phase_last_completed",ISSX_PhaseIdToString(s.phase_last_completed));
      jw.NameString("phase_aborted_reason",ISSX_PhaseAbortReasonToString(s.phase_aborted_reason));
      jw.NameString("phase_saved_progress_key",s.phase_saved_progress_key);
      jw.NameString("stage_slot",ISSX_StageIdToString(s.stage_slot));
      jw.NameBool("stage_finished_this_minute",s.stage_finished_this_minute);
      jw.EndObject();
      return jw.ToString();
     }

   static bool DecodePhaseState(const string text,ISSX_PhaseSchedulerState &s)
     {
      // Honest degradation:
      // This runtime file does not own a JSON parser surface. Returning true
      // without decoding would violate accepted-truth and resume-honesty rules.
      s.Reset();
      if(StringLen(text)<=0)
         return false;
      return false;
     }

   static string EncodeQueueItem(const ISSX_WorkQueueItem &q)
     {
      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginObject();
      jw.NameString("symbol_id",q.symbol_id);
      jw.NameString("pair_id",q.pair_id);
      jw.NameString("queue_reason",q.queue_reason);
      jw.NameString("priority",ISSX_QueuePriorityToString(q.priority));
      jw.NameString("queue_family",ISSX_QueueFamilyToString(q.queue_family));
      jw.NameString("service_class",ISSX_QueueServiceClassToString(q.service_class));
      jw.NameString("invalidation_class",ISSX_InvalidationClassToString(q.invalidation_class));
      jw.NameString("target_phase",ISSX_PhaseIdToString(q.target_phase));
      jw.NameInt("cost_hint",q.cost_hint);
      jw.NameInt("work_units_hint",q.work_units_hint);
      jw.NameInt("retry_count",q.retry_count);
      jw.NameLong("created_mono_ms",q.created_mono_ms);
      jw.NameLong("last_attempt_mono_ms",q.last_attempt_mono_ms);
      jw.NameLong("cooldown_until_mono_ms",q.cooldown_until_mono_ms);
      jw.NameBool("persistence_required_flag",q.persistence_required_flag);
      jw.NameBool("contender_promotion_flag",q.contender_promotion_flag);
      jw.NameBool("changed_symbol_hint_flag",q.changed_symbol_hint_flag);
      jw.NameBool("publish_critical_flag",q.publish_critical_flag);
      jw.EndObject();
      return jw.ToString();
     }

   static bool DecodeQueueItem(const string text,ISSX_WorkQueueItem &q)
     {
      // Honest degradation:
      // this file can encode queue items deterministically, but it does not own
      // a parser implementation here. Do not pretend decode success.
      q.Reset();
      if(StringLen(text)<=0)
         return false;
      return false;
     }
  };

// ============================================================================
// SECTION 10: STAGE RUNTIME
// ============================================================================

class ISSX_StageRuntime
  {
private:
   ISSX_RuntimeState m_state;
   ISSX_RuntimeClock m_clock;

   static void SyncKernelBudgetSurface(ISSX_RuntimeState &state)
     {
      state.kernel.kernel_budget_total_ms=(long)state.budgets.budget_total_ms;
      state.kernel.kernel_budget_spent_ms=(long)state.budgets.budget_spent_ms;
      state.kernel.kernel_budget_reserved_commit_ms=(long)state.budgets.budget_reserved_commit_ms;
      state.kernel.kernel_budget_debt_ms=(long)state.budgets.budget_debt_ms;
      state.kernel.kernel_overrun_class=(state.budgets.budget_debt_ms>0 ? issx_overrun_soft : issx_overrun_none);
      state.kernel.kernel_forced_service_due_flag=(state.kernel.kernel_forced_service_due_flag || state.budgets.forced_service_due_flag);
      state.kernel.kernel_degraded_cycle_flag=(state.kernel.kernel_degraded_cycle_flag || state.budgets.degraded_cycle_flag);
     }

public:
   void Init()
     {
      m_state.Reset();
      m_clock.Reset();
      SyncKernelBudgetSurface(m_state);
     }

   void ApplyStageBudget(const ISSX_StageId stage_id)
     {
      ISSX_BudgetPolicy::ApplyStageDefaults(stage_id,m_state.budgets);
      SyncKernelBudgetSurface(m_state);
     }

   void OnPulse()
     {
      m_clock.OnPulse(m_state);
      ISSX_RuntimePolicy::UpdatePublishDueFlags(m_state,(long)GetTickCount64());
      SyncKernelBudgetSurface(m_state);
     }

   bool ShouldPublishNow(const ISSX_StageId stage_id) const
     {
      const int idx=StageIdToIndex(stage_id);
      if(idx<0)
         return false;
      return m_state.kernel.stage_publish_due_flag[idx];
     }

   ISSX_RuntimeState State() const
     {
      return m_state;
     }
  };

// ============================================================================
// SECTION 11: FACADE
// ============================================================================

class ISSX_Runtime
  {
public:
   static ISSX_RuntimeBudgets MakeDefaultBudget(const ISSX_StageId stage_id)
     {
      ISSX_RuntimeBudgets b;
      b.Reset();
      ISSX_BudgetPolicy::ApplyStageDefaults(stage_id,b);
      return b;
     }

   static ISSX_StageId StageOfPhase(const ISSX_PhaseId phase_id)
     {
      return ISSX_Runtime_StageOfPhase(phase_id);
     }

   static bool IsPublishPhase(const ISSX_PhaseId phase_id)
     {
      return ISSX_Runtime_IsPublishPhase(phase_id);
     }

   static bool IsKernelPhase(const ISSX_PhaseId phase_id)
     {
      return ISSX_Runtime_IsKernelPhase(phase_id);
     }

   static string PhaseIdToString(const ISSX_PhaseId phase_id)
     {
      return ISSX_PhaseIdToString(phase_id);
     }
  };

#endif // __ISSX_RUNTIME_MQH__