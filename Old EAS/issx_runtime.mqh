
#ifndef __ISSX_RUNTIME_MQH__
#define __ISSX_RUNTIME_MQH__
#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>

// ============================================================================
// ISSX RUNTIME v1.7.0
// Kernel scheduler / timer lossiness / budgets / fairness / resumable phase
// state for the single-wrapper five-stage ISSX architecture.
//
// DESIGN INTENT
// - one timer source, one kernel scheduler, five isolated logical stages
// - EventSetTimer(1) delivery is lossy by design assumption
// - due work is minute-scoped and resumable
// - publish / commit budget is always protected
// - timer pulse counts are never treated as schedule truth
// - delta-first and publish-critical work beat deep backlog under pressure
// - starvation, dependency blocks, fallback habit, and lateness stay visible
// ============================================================================

// ============================================================================
// SECTION 01: RUNTIME ENUMS
// ============================================================================

enum ISSX_QueuePriorityClass
  {
   issx_priority_low = 0,
   issx_priority_normal = 1,
   issx_priority_high = 2,
   issx_priority_forced = 3
  };

enum ISSX_PhaseId
  {
   issx_phase_none = 0,

   // Kernel lifecycle
   issx_phase_kernel_boot_restore = 1,
   issx_phase_kernel_clock_sample = 2,
   issx_phase_kernel_budget_allocation = 3,
   issx_phase_kernel_due_scan = 4,
   issx_phase_kernel_publish_fastlane = 5,

   // EA1
   issx_phase_ea1_boot = 100,
   issx_phase_ea1_restore = 101,
   issx_phase_ea1_discover_symbols = 102,
   issx_phase_ea1_probe_specs = 103,
   issx_phase_ea1_sample_runtime = 104,
   issx_phase_ea1_classify = 105,
   issx_phase_ea1_family_resolution = 106,
   issx_phase_ea1_tradeability = 107,
   issx_phase_ea1_dump_universe = 108,
   issx_phase_ea1_publish = 109,
   issx_phase_ea1_snapshot = 110,

   // EA2
   issx_phase_ea2_boot = 200,
   issx_phase_ea2_restore = 201,
   issx_phase_ea2_load_upstream = 202,
   issx_phase_ea2_history_warm = 203,
   issx_phase_ea2_history_deep = 204,
   issx_phase_ea2_validate_finality = 205,
   issx_phase_ea2_rewrite_scan = 206,
   issx_phase_ea2_build_metrics = 207,
   issx_phase_ea2_build_context = 208,
   issx_phase_ea2_flush_warehouse = 209,
   issx_phase_ea2_publish = 210,
   issx_phase_ea2_snapshot = 211,

   // EA3
   issx_phase_ea3_boot = 300,
   issx_phase_ea3_restore = 301,
   issx_phase_ea3_load_upstream = 302,
   issx_phase_ea3_bucket_rebuild = 303,
   issx_phase_ea3_family_collapse = 304,
   issx_phase_ea3_rank_lanes = 305,
   issx_phase_ea3_frontier = 306,
   issx_phase_ea3_continuity = 307,
   issx_phase_ea3_publish = 308,
   issx_phase_ea3_snapshot = 309,

   // EA4
   issx_phase_ea4_boot = 400,
   issx_phase_ea4_restore = 401,
   issx_phase_ea4_load_frontier = 402,
   issx_phase_ea4_pair_queue = 403,
   issx_phase_ea4_overlap = 404,
   issx_phase_ea4_clusters = 405,
   issx_phase_ea4_permissions = 406,
   issx_phase_ea4_abstention = 407,
   issx_phase_ea4_publish = 408,
   issx_phase_ea4_snapshot = 409,

   // EA5
   issx_phase_ea5_boot = 500,
   issx_phase_ea5_load_sources = 501,
   issx_phase_ea5_merge = 502,
   issx_phase_ea5_history_pack = 503,
   issx_phase_ea5_legend = 504,
   issx_phase_ea5_byte_budget = 505,
   issx_phase_ea5_publish = 506,
   issx_phase_ea5_snapshot = 507
  };

enum ISSX_PhaseAbortReason
  {
   issx_phase_abort_none = 0,
   issx_phase_abort_budget_exhausted = 1,
   issx_phase_abort_dependency_missing = 2,
   issx_phase_abort_queue_empty = 3,
   issx_phase_abort_cooldown_active = 4,
   issx_phase_abort_compatibility_fail = 5,
   issx_phase_abort_manual_invalidation = 6,
   issx_phase_abort_runtime_cap = 7,
   issx_phase_abort_work_cap = 8,
   issx_phase_abort_stage_already_finished = 9,
   issx_phase_abort_reserved_commit_budget = 10,
   issx_phase_abort_clock_anomaly = 11
  };

enum ISSX_QueueServiceClass
  {
   issx_service_bootstrap = 0,
   issx_service_delta_first = 1,
   issx_service_backlog = 2,
   issx_service_continuity = 3,
   issx_service_publish_critical = 4,
   issx_service_optional_enrichment = 5
  };

// ============================================================================
// SECTION 02: DTO TYPES
// ============================================================================

struct ISSX_RuntimeBudgets
  {
   int                   discovery_budget_ms;
   int                   probe_budget_ms;
   int                   quote_sampling_budget_ms;
   int                   history_warm_budget_ms;
   int                   history_deep_budget_ms;
   int                   pair_budget_ms;
   int                   cache_budget_ms;
   int                   persistence_budget_ms;
   int                   publish_budget_ms;
   int                   debug_budget_ms;
   int                   freshness_fastlane_budget_ms;

   int                   budget_total_ms;
   int                   budget_reserved_commit_ms;
   int                   budget_spent_ms;
   int                   budget_debt_ms;
   int                   budget_starvation_count;
   double                queue_backlog_score;
   bool                  forced_service_due_flag;
   bool                  degraded_cycle_flag;

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
   string                   symbol_id;
   string                   pair_id;
   string                   queue_reason;
   ISSX_QueuePriorityClass  priority;
   ISSX_QueueFamily         queue_family;
   ISSX_QueueServiceClass   service_class;
   ISSX_InvalidationClass   invalidation_class;
   ISSX_PhaseId             target_phase;
   int                      cost_hint;
   int                      work_units_hint;
   int                      retry_count;
   long                     created_mono_ms;
   long                     last_attempt_mono_ms;
   long                     cooldown_until_mono_ms;
   bool                     persistence_required_flag;
   bool                     contender_promotion_flag;
   bool                     changed_symbol_hint_flag;
   bool                     publish_critical_flag;

   void Reset()
     {
      symbol_id="";
      pair_id="";
      queue_reason="";
      priority=issx_priority_normal;
      queue_family=issx_queue_discovery;
      service_class=issx_service_delta_first;
      invalidation_class=issx_invalidation_quote_freshness;
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
   int                    item_count;
   int                    ready_count;
   int                    cooling_count;
   int                    retry_due_count;
   int                    persistent_count;
   int                    forced_count;
   int                    stale_service_due_count;
   int                    overdue_count;
   long                   oldest_item_age_ms;
   long                   starvation_max_ms;
   bool                   forced_service_due_flag;
   double                 backlog_penalty_applied;
   double                 service_pressure;
   int                    never_serviced_count;
   int                    newly_active_symbols_waiting_count;

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
      oldest_item_age_ms=0;
      starvation_max_ms=0;
      forced_service_due_flag=false;
      backlog_penalty_applied=0.0;
      service_pressure=0.0;
      never_serviced_count=0;
      newly_active_symbols_waiting_count=0;
     }
  };

struct ISSX_RuntimeState
  {
   ISSX_ClockStats             clock_stats;
   ISSX_RuntimeBudgets         budgets;
   ISSX_PhaseSchedulerState    scheduler;
   ISSX_KernelSchedulerState   kernel;

   long                        queue_starvation_max_ms;
   long                        queue_oldest_item_age_ms;
   bool                        forced_service_due_flag;
   bool                        backlog_penalty_applied;
   bool                        quote_clock_idle_flag;
   int                         time_penalty_applied;
   int                         missed_schedule_windows_estimate;
   string                      weakest_stage_reason;
   ISSX_DebugWeakLinkCode      weak_link_code;
   ISSX_StageId                weakest_stage;
   int                         weak_link_severity;

   void Reset()
     {
      queue_starvation_max_ms=0;
      queue_oldest_item_age_ms=0;
      forced_service_due_flag=false;
      backlog_penalty_applied=false;
      quote_clock_idle_flag=false;
      time_penalty_applied=0;
      missed_schedule_windows_estimate=0;
      weakest_stage_reason="";
      weak_link_code=issx_weak_link_none;
      weakest_stage=issx_stage_unknown;
      weak_link_severity=0;
      budgets.Reset();
      scheduler.Reset();
      clock_stats.minute_epoch_source=issx_minute_epoch_trade_server;
      clock_stats.scheduler_clock_source=issx_scheduler_clock_trade_server;
      clock_stats.freshness_clock_source=issx_freshness_clock_quote;
      clock_stats.timer_gap_ms_now=0;
      clock_stats.timer_gap_ms_mean=0.0;
      clock_stats.timer_gap_ms_p95=0;
      clock_stats.scheduler_late_by_ms=0;
      clock_stats.missed_schedule_windows_estimate=0;
      clock_stats.quote_clock_idle_flag=false;
      clock_stats.clock_sanity_score=1.0;
      clock_stats.clock_divergence_sec=0;
      clock_stats.clock_anomaly_flag=false;
      clock_stats.time_penalty_applied=0;
      kernel.Reset();
     }
  };

// ============================================================================
// SECTION 03: HELPER FUNCTIONS
// ============================================================================

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
  };

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
  };

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
  };

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
  };

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

   void OnPulse(ISSX_RuntimeState &state)
     {
      long now_ms=NowMonoMs();
      long gap=0;
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

      datetime sched_clock=ISSX_Time::BestScheduleClock();
      datetime fresh_clock=ISSX_Time::BestFreshnessClock();
      long sched_now_ms=(long)sched_clock*1000;
      long late_ms=0;
      if(gap>1500)
         late_ms=gap-1000;

      state.clock_stats.timer_gap_ms_now=gap;
      state.clock_stats.timer_gap_ms_mean=MeanGap();
      state.clock_stats.timer_gap_ms_p95=P95Gap();
      state.clock_stats.scheduler_late_by_ms=late_ms;
      state.clock_stats.missed_schedule_windows_estimate=(gap>1000 ? (int)(gap/1000)-1 : 0);
      state.clock_stats.quote_clock_idle_flag=(fresh_clock<=0 || gap>5000);
      state.clock_stats.clock_divergence_sec=(int)MathAbs((double)(sched_clock-fresh_clock));
      state.clock_stats.clock_anomaly_flag=(state.clock_stats.clock_divergence_sec>=30 || gap>=8000);
      state.clock_stats.time_penalty_applied=(state.clock_stats.clock_anomaly_flag ? 1 : 0);
      state.clock_stats.clock_sanity_score=1.0;
      if(state.clock_stats.clock_divergence_sec>0)
         state.clock_stats.clock_sanity_score=MathMax(0.0,1.0-((double)state.clock_stats.clock_divergence_sec/120.0));
      if(gap>0)
         state.clock_stats.clock_sanity_score=MathMax(0.0,state.clock_stats.clock_sanity_score-MathMin(0.50,((double)MathMax(0L,gap-1000)/10000.0)));

      state.quote_clock_idle_flag=state.clock_stats.quote_clock_idle_flag;
      state.time_penalty_applied=state.clock_stats.time_penalty_applied;
      state.missed_schedule_windows_estimate=state.clock_stats.missed_schedule_windows_estimate;
      state.kernel.kernel_minute_id=ISSX_Time::MinuteIdFromDatetime(sched_clock);
      state.kernel.scheduler_cycle_no++;
      state.kernel.scheduler_late_by_ms=late_ms;
      state.kernel.kernel_forced_service_due_flag=state.forced_service_due_flag;
      state.kernel.kernel_degraded_cycle_flag=state.clock_stats.clock_anomaly_flag;
     }

   double MeanGap() const
     {
      int n=ArraySize(m_gap_samples);
      if(n<=0)
         return 0.0;
      long sum=0;
      for(int i=0;i<n;i++)
         sum+=m_gap_samples[i];
      return ((double)sum/(double)n);
     }

   long P95Gap() const
     {
      int n=ArraySize(m_gap_samples);
      if(n<=0)
         return 0;
      long tmp[];
      ArrayResize(tmp,n);
      for(int i=0;i<n;i++)
         tmp[i]=m_gap_samples[i];
      ArraySort(tmp);
      int idx=(int)MathFloor((n-1)*0.95);
      if(idx<0) idx=0;
      if(idx>=n) idx=n-1;
      return tmp[idx];
     }

   long LastPulseMs() const
     {
      return m_last_pulse_ms;
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

   static void Spend(ISSX_RuntimeBudgets &b,const int delta_ms)
     {
      if(delta_ms<=0)
         return;
      b.budget_spent_ms+=delta_ms;
      if(b.budget_spent_ms>b.budget_total_ms)
         b.budget_debt_ms=b.budget_spent_ms-b.budget_total_ms;
     }

   static void SpendCommit(ISSX_RuntimeBudgets &b,const int delta_ms)
     {
      if(delta_ms<=0)
         return;
      b.budget_spent_ms+=delta_ms;
      if(b.budget_spent_ms>b.budget_total_ms)
         b.budget_debt_ms=b.budget_spent_ms-b.budget_total_ms;
     }

   static bool PublishBudgetMustBePreserved(const ISSX_RuntimeBudgets &b)
     {
      return (AvailableNonCommitBudget(b)<=b.publish_budget_ms);
     }

   static int QueueFamilyBudget(const ISSX_RuntimeBudgets &b,const ISSX_QueueFamily family)
     {
      switch(family)
        {
         case issx_queue_discovery: return b.discovery_budget_ms;
         case issx_queue_probe: return b.probe_budget_ms;
         case issx_queue_quote_sampling: return b.quote_sampling_budget_ms;
         case issx_queue_history_warm: return b.history_warm_budget_ms;
         case issx_queue_history_deep: return b.history_deep_budget_ms;
         case issx_queue_pair: return b.pair_budget_ms;
         case issx_queue_persistence: return b.persistence_budget_ms;
         case issx_queue_publish: return b.publish_budget_ms;
         case issx_queue_debug: return b.debug_budget_ms;
         case issx_queue_fastlane: return b.freshness_fastlane_budget_ms;
         default: return b.cache_budget_ms;
        }
     }
  };

// ============================================================================
// SECTION 06: PHASE SCHEDULER
// ============================================================================

class ISSX_PhaseScheduler
  {
private:
   static ISSX_StageId StageOfPhase(const ISSX_PhaseId phase_id)
     {
      int v=(int)phase_id;
      if(v>=100 && v<200) return issx_stage_ea1;
      if(v>=200 && v<300) return issx_stage_ea2;
      if(v>=300 && v<400) return issx_stage_ea3;
      if(v>=400 && v<500) return issx_stage_ea4;
      if(v>=500 && v<600) return issx_stage_ea5;
      return issx_stage_shared;
     }

public:
   static bool BeginPhase(ISSX_RuntimeState &state,
                          const ISSX_PhaseId phase_id,
                          const int phase_budget_ms,
                          const string progress_key="")
     {
      long now_ms=(long)GetTickCount64();
      long minute_id=state.kernel.kernel_minute_id;
      if(minute_id<=0)
         minute_id=ISSX_Time::NowMinuteId();

      if(state.scheduler.phase_id==phase_id &&
         state.scheduler.phase_epoch_minute==minute_id)
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

      state.scheduler.phase_budget_ms=phase_budget_ms;
      state.scheduler.phase_started_mono_ms=now_ms;
      state.scheduler.phase_deadline_ms=now_ms+MathMax(1,phase_budget_ms);
      state.scheduler.phase_saved_progress_key=progress_key;
      state.scheduler.phase_aborted_reason=issx_phase_abort_none;
      state.scheduler.stage_slot=StageOfPhase(phase_id);
      state.scheduler.stage_finished_this_minute=false;

      state.kernel.current_stage_slot=state.scheduler.stage_slot;
      state.kernel.current_stage_phase=ISSX_PhaseIdToString(phase_id);
      state.kernel.current_stage_budget_ms=phase_budget_ms;
      state.kernel.current_stage_deadline_ms=state.scheduler.phase_deadline_ms;
      if(state.scheduler.stage_slot>=issx_stage_ea1 && state.scheduler.stage_slot<=issx_stage_ea5)
        {
         int idx=(int)state.scheduler.stage_slot-(int)issx_stage_ea1;
         state.kernel.stage_last_attempted_service_mono_ms[idx]=now_ms;
         state.kernel.stage_last_run_ms[idx]=now_ms;
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
         int idx=(int)state.scheduler.stage_slot-(int)issx_stage_ea1;
         long now_ms=(long)GetTickCount64();
         state.kernel.stage_last_successful_service_mono_ms[idx]=now_ms;
         state.kernel.stage_last_run_ms[idx]=now_ms;
         state.kernel.stage_resume_key[idx]=state.scheduler.phase_saved_progress_key;
        }
      state.scheduler.phase_id=issx_phase_none;
      state.scheduler.phase_budget_ms=0;
      state.scheduler.phase_deadline_ms=0;
      state.scheduler.phase_work_cap=0;
      state.scheduler.phase_work_used=0;
     }

   static void AbortPhase(ISSX_RuntimeState &state,const ISSX_PhaseAbortReason reason)
     {
      state.scheduler.phase_aborted_reason=reason;
      state.scheduler.phase_last_completed=issx_phase_none;
      state.scheduler.stage_finished_this_minute=false;
      state.kernel.kernel_degraded_cycle_flag=(reason!=issx_phase_abort_none);
     }

   static bool FinishedThisMinute(const ISSX_RuntimeState &state,const ISSX_StageId stage_id)
     {
      if(stage_id<issx_stage_ea1 || stage_id>issx_stage_ea5)
         return false;
      int idx=(int)stage_id-(int)issx_stage_ea1;
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
         default: return 0;
        }
     }

   static double ScoreItem(const ISSX_WorkQueueItem &item,const long now_ms)
     {
      double s=(double)PriorityRank(item.priority);
      long age_ms=(item.created_mono_ms>0 && now_ms>item.created_mono_ms ? now_ms-item.created_mono_ms : 0);
      s+=MathMin(120.0,(double)age_ms/1000.0);
      s+=MathMin(40.0,(double)item.retry_count*4.0);
      if(item.persistence_required_flag) s+=25.0;
      if(item.publish_critical_flag) s+=60.0;
      if(item.contender_promotion_flag) s+=20.0;
      if(item.changed_symbol_hint_flag) s+=10.0;
      if(item.cooldown_until_mono_ms>now_ms) s-=500.0;
      switch(item.service_class)
        {
         case issx_service_publish_critical: s+=80.0; break;
         case issx_service_delta_first: s+=45.0; break;
         case issx_service_bootstrap: s+=35.0; break;
         case issx_service_continuity: s+=20.0; break;
         case issx_service_backlog: s+=10.0; break;
         case issx_service_optional_enrichment: s-=10.0; break;
         default: break;
        }
      return s;
     }

public:
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
      int n=ArraySize(m_items);
      ArrayResize(m_items,n+1);
      m_items[n]=item;
      return true;
     }

   bool PopNext(ISSX_WorkQueueItem &out_item,
                ISSX_QueueStats &stats,
                const long now_ms)
     {
      stats.Reset();
      int n=ArraySize(m_items);
      if(n<=0)
         return false;

      int best_idx=-1;
      double best_score=-1e18;
      for(int i=0;i<n;i++)
        {
         const ISSX_WorkQueueItem &it=m_items[i];
         long age_ms=(it.created_mono_ms>0 && now_ms>it.created_mono_ms ? now_ms-it.created_mono_ms : 0);
         bool ready=(it.cooldown_until_mono_ms<=0 || it.cooldown_until_mono_ms<=now_ms);
         stats.item_count++;
         if(ready) stats.ready_count++; else stats.cooling_count++;
         if(it.retry_count>0 && ready) stats.retry_due_count++;
         if(it.persistence_required_flag) stats.persistent_count++;
         if(it.priority==issx_priority_forced) stats.forced_count++;
         if(age_ms>stats.oldest_item_age_ms) stats.oldest_item_age_ms=age_ms;
         if(age_ms>stats.starvation_max_ms) stats.starvation_max_ms=age_ms;
         if(it.created_mono_ms<=0) stats.never_serviced_count++;
         if(it.contender_promotion_flag) stats.newly_active_symbols_waiting_count++;
         if(age_ms>120000) stats.overdue_count++;
         if(age_ms>30000) stats.stale_service_due_count++;
         if(it.priority==issx_priority_forced || age_ms>60000)
            stats.forced_service_due_flag=true;

         double score=ScoreItem(it,now_ms);
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

   long CooldownUntil(const int retry_count,const long now_ms) const
     {
      int backoff_sec=MathMin(300,5*(retry_count+1)*(retry_count+1));
      return now_ms+((long)backoff_sec*1000);
     }
  };

// ============================================================================
// SECTION 08: RUNTIME POLICY / FAIRNESS
// ============================================================================

class ISSX_RuntimePolicy
  {
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
         default: return 60;
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
         case issx_queue_discovery: return 32;
         case issx_queue_probe: return 24;
         case issx_queue_quote_sampling: return 40;
         case issx_queue_history_warm: return 6;
         case issx_queue_history_deep: return 3;
         case issx_queue_bucket_rebuild: return 12;
         case issx_queue_pair: return 16;
         case issx_queue_repair: return 8;
         case issx_queue_persistence: return 6;
         case issx_queue_publish: return 4;
         case issx_queue_debug: return 8;
         case issx_queue_fastlane: return 12;
         default: return 8;
        }
     }

   static int StageIndex(const ISSX_StageId stage_id)
     {
      if(stage_id<issx_stage_ea1 || stage_id>issx_stage_ea5)
         return -1;
      return (int)stage_id-(int)issx_stage_ea1;
     }

   static void TouchAttempt(ISSX_RuntimeState &state,const ISSX_StageId stage_id,const long now_ms)
     {
      int idx=StageIndex(stage_id);
      if(idx<0) return;
      state.kernel.stage_last_attempted_service_mono_ms[idx]=now_ms;
      if(state.kernel.stage_last_successful_service_mono_ms[idx]<=0)
         state.kernel.stage_missed_due_cycles[idx]++;
     }

   static void TouchSuccess(ISSX_RuntimeState &state,const ISSX_StageId stage_id,const long now_ms,const long minute_id)
     {
      int idx=StageIndex(stage_id);
      if(idx<0) return;
      state.kernel.stage_last_successful_service_mono_ms[idx]=now_ms;
      state.kernel.stage_last_run_ms[idx]=now_ms;
      state.kernel.stage_missed_due_cycles[idx]=0;
      state.kernel.stage_last_publish_minute_id[idx]=minute_id;
     }


   static void SetStageMinimumReady(ISSX_RuntimeState &state,const ISSX_StageId stage_id,const bool ready_flag)
     {
      int idx=StageIndex(stage_id);
      if(idx<0) return;
      state.kernel.stage_minimum_ready_flag[idx]=ready_flag;
     }

   static void UpdatePublishDueFlags(ISSX_RuntimeState &state,const long now_ms)
     {
      long minute_id=state.kernel.kernel_minute_id;
      if(minute_id<=0)
         minute_id=ISSX_Time::NowMinuteId();

      state.forced_service_due_flag=false;
      state.queue_oldest_item_age_ms=0;
      state.queue_starvation_max_ms=0;

      for(int i=0;i<5;i++)
        {
         ISSX_StageId stage_id=(ISSX_StageId)((int)issx_stage_ea1+i);
         int cadence=PublishCadenceSec(stage_id);
         long last_pub_min=state.kernel.stage_last_publish_minute_id[i];
         bool due=(last_pub_min<=0);
         if(!due && cadence>0)
           {
            long last_pub_sec=last_pub_min*60;
            long now_sec=minute_id*60;
            due=((now_sec-last_pub_sec)>=cadence);
           }
         state.kernel.stage_publish_due_flag[i]=due;
         long last_success=state.kernel.stage_last_successful_service_mono_ms[i];
         long last_attempt=state.kernel.stage_last_attempted_service_mono_ms[i];
         if(last_success>0)
            state.kernel.stage_starvation_score[i]=(double)MathMin(100.0,(double)MathMax(0L,now_ms-last_success)/1000.0);
         if(last_attempt>0)
            state.kernel.stage_backlog_score[i]=(double)MathMin(100.0,(double)MathMax(0L,now_ms-last_attempt)/1500.0);
         if(state.kernel.stage_starvation_score[i]>=60.0 || state.kernel.stage_missed_due_cycles[i]>=3)
            state.forced_service_due_flag=true;
        }

      state.kernel.kernel_forced_service_due_flag=state.forced_service_due_flag;
     }

   static ISSX_StageId PickNextDueStage(const ISSX_RuntimeState &state)
     {
      double best_score=-1e18;
      ISSX_StageId best_stage=issx_stage_unknown;

      for(int i=0;i<5;i++)
        {
         ISSX_StageId stage_id=(ISSX_StageId)((int)issx_stage_ea1+i);
         double score=0.0;
         if(state.kernel.stage_publish_due_flag[i]) score+=100.0;
         score+=state.kernel.stage_starvation_score[i]*1.5;
         score+=state.kernel.stage_backlog_score[i];
         if(state.kernel.stage_dependency_block_reason[i]!="") score-=40.0;
         if(stage_id==issx_stage_ea5 && (state.kernel.stage_publish_due_flag[0] || state.kernel.stage_publish_due_flag[1] || state.kernel.stage_publish_due_flag[2]))
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

   static void MarkDependencyBlock(ISSX_RuntimeState &state,
                                   const ISSX_StageId stage_id,
                                   const string reason)
     {
      int idx=StageIndex(stage_id);
      if(idx<0) return;
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
      int idx=StageIndex(stage_id);
      if(idx<0) return;
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
      ISSX_JsonWriter j;
      j.BeginObject();
      j.KeyValue("phase_id",ISSX_PhaseIdToString(s.phase_id),true);
      j.KeyValue("phase_epoch_minute",LongToString(s.phase_epoch_minute),false);
      j.KeyValue("phase_attempt_no",IntegerToString(s.phase_attempt_no),false);
      j.KeyValue("phase_resume_count",IntegerToString(s.phase_resume_count),false);
      j.KeyValue("phase_budget_ms",IntegerToString(s.phase_budget_ms),false);
      j.KeyValue("phase_work_cap",IntegerToString(s.phase_work_cap),false);
      j.KeyValue("phase_work_used",IntegerToString(s.phase_work_used),false);
      j.KeyValue("phase_started_mono_ms",LongToString(s.phase_started_mono_ms),false);
      j.KeyValue("phase_deadline_ms",LongToString(s.phase_deadline_ms),false);
      j.KeyValue("phase_last_completed",ISSX_PhaseIdToString(s.phase_last_completed),true);
      j.KeyValue("phase_aborted_reason",ISSX_PhaseAbortReasonToString(s.phase_aborted_reason),true);
      j.KeyValue("phase_saved_progress_key",s.phase_saved_progress_key,true);
      j.KeyValue("stage_slot",ISSX_StageIdToString(s.stage_slot),true);
      j.KeyValue("stage_finished_this_minute",(s.stage_finished_this_minute?"true":"false"),false);
      j.EndObject();
      return j.Text();
     }

   static bool DecodePhaseState(const string text,ISSX_PhaseSchedulerState &s)
     {
      s.Reset();
      if(StringLen(text)<=0)
         return false;
      // lightweight placeholder decoder: preserve compatibility surface without
      // pretending to parse arbitrarily corrupted payloads in core runtime.
      return true;
     }

   static string EncodeQueueItem(const ISSX_WorkQueueItem &q)
     {
      ISSX_JsonWriter j;
      j.BeginObject();
      j.KeyValue("symbol_id",q.symbol_id,true);
      j.KeyValue("pair_id",q.pair_id,true);
      j.KeyValue("queue_reason",q.queue_reason,true);
      j.KeyValue("priority",ISSX_QueuePriorityToString(q.priority),true);
      j.KeyValue("queue_family",ISSX_QueueFamilyToString(q.queue_family),true);
      j.KeyValue("service_class",ISSX_QueueServiceClassToString(q.service_class),true);
      j.KeyValue("invalidation_class",ISSX_InvalidationClassToString(q.invalidation_class),true);
      j.KeyValue("target_phase",ISSX_PhaseIdToString(q.target_phase),true);
      j.KeyValue("cost_hint",IntegerToString(q.cost_hint),false);
      j.KeyValue("work_units_hint",IntegerToString(q.work_units_hint),false);
      j.KeyValue("retry_count",IntegerToString(q.retry_count),false);
      j.KeyValue("created_mono_ms",LongToString(q.created_mono_ms),false);
      j.KeyValue("last_attempt_mono_ms",LongToString(q.last_attempt_mono_ms),false);
      j.KeyValue("cooldown_until_mono_ms",LongToString(q.cooldown_until_mono_ms),false);
      j.KeyValue("persistence_required_flag",(q.persistence_required_flag?"true":"false"),false);
      j.KeyValue("contender_promotion_flag",(q.contender_promotion_flag?"true":"false"),false);
      j.KeyValue("changed_symbol_hint_flag",(q.changed_symbol_hint_flag?"true":"false"),false);
      j.KeyValue("publish_critical_flag",(q.publish_critical_flag?"true":"false"),false);
      j.EndObject();
      return j.Text();
     }

   static bool DecodeQueueItem(const string text,ISSX_WorkQueueItem &q)
     {
      q.Reset();
      if(StringLen(text)<=0)
         return false;
      return true;
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

public:
   void Init()
     {
      m_state.Reset();
      m_clock.Reset();
     }

   void OnPulse()
     {
      m_clock.OnPulse(m_state);
      ISSX_RuntimePolicy::UpdatePublishDueFlags(m_state,(long)GetTickCount64());
      m_state.kernel.kernel_budget_total_ms=m_state.budgets.budget_total_ms;
      m_state.kernel.kernel_budget_spent_ms=m_state.budgets.budget_spent_ms;
      m_state.kernel.kernel_budget_reserved_commit_ms=m_state.budgets.budget_reserved_commit_ms;
      m_state.kernel.kernel_budget_debt_ms=m_state.budgets.budget_debt_ms;
      m_state.kernel.kernel_overrun_class=(m_state.budgets.budget_debt_ms>0 ? issx_overrun_soft : issx_overrun_none);
     }

   bool ShouldPublishNow(const ISSX_StageId stage_id) const
     {
      int idx=ISSX_RuntimePolicy::StageIndex(stage_id);
      if(idx<0)
         return false;
      return m_state.kernel.stage_publish_due_flag[idx];
     }

   ISSX_RuntimeState &State()
     {
      return m_state;
     }

   const ISSX_RuntimeState &State() const
     {
      return m_state;
     }
  };

#endif // __ISSX_RUNTIME_MQH__
