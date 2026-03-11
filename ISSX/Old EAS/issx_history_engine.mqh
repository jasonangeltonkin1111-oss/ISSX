
#ifndef __ISSX_HISTORY_ENGINE_MQH__
#define __ISSX_HISTORY_ENGINE_MQH__
#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>

// ============================================================================
// ISSX HISTORY ENGINE v1.5.0
// EA2 shared engine for HistoryStateCore.
//
// OWNERSHIP IN THIS MODULE
// - history synchronization truth
// - history integrity truth
// - timeframe trust map
// - compact metric prep
// - history comparison safety
// - bar finality and rewrite detection
// - neutral structural context
// - post-repair stability rules
// - changed-symbol / changed-timeframe hydration discipline
//
// DESIGN PRINCIPLES
// - completed bars are authoritative for warehouse truth
// - live/forming bar is tracked separately and never silently mixed into completed-pack export
// - enough bars != good history
// - ranking_ready != intelligence_ready
// - handle existence != metric trust
// - comparison-safe must be explicit
// - repaired history must survive stable cycles before regaining high compare class
// - downstream cadence uses delta-first hydration
// - full history refresh of all symbols every minute is forbidden
// ============================================================================

// ============================================================================
// SECTION 01: EA2 PHASE IDS / MODES
// ============================================================================

enum ISSX_EA2_PhaseId
  {
   issx_ea2_phase_load_upstream = 0,
   issx_ea2_phase_recover_state,
   issx_ea2_phase_hydrate_warm_history_delta_first,
   issx_ea2_phase_hydrate_deep_history_queue,
   issx_ea2_phase_validate_finality,
   issx_ea2_phase_build_metrics_delta_first,
   issx_ea2_phase_build_structural_context_delta_first,
   issx_ea2_phase_update_continuity,
   issx_ea2_phase_publish
  };

enum ISSX_EA2_TimeframeMode
  {
   issx_ea2_tfmode_cold = 0,
   issx_ea2_tfmode_syncing,
   issx_ea2_tfmode_minimal_ready,
   issx_ea2_tfmode_ranking_ready,
   issx_ea2_tfmode_intelligence_ready,
   issx_ea2_tfmode_degraded
  };

enum ISSX_EA2_HistoryReadinessState
  {
   issx_ea2_history_never_requested = 0,
   issx_ea2_history_requested_sync,
   issx_ea2_history_partial_available,
   issx_ea2_history_syncing,
   issx_ea2_history_compare_unsafe,
   issx_ea2_history_compare_safe_degraded,
   issx_ea2_history_compare_safe_strong,
   issx_ea2_history_degraded_unstable,
   issx_ea2_history_blocked
  };

enum ISSX_EA2_RewriteClass
  {
   issx_ea2_rewrite_none = 0,
   issx_ea2_rewrite_benign_last_bar_adjustment,
   issx_ea2_rewrite_short_tail_rewrite,
   issx_ea2_rewrite_structural_gap_rewrite,
   issx_ea2_rewrite_historical_block_rewrite
  };

enum ISSX_EA2_WarehouseQuality
  {
   issx_ea2_warehouse_quality_unknown = 0,
   issx_ea2_warehouse_quality_cold,
   issx_ea2_warehouse_quality_partial,
   issx_ea2_warehouse_quality_compare_safe_degraded,
   issx_ea2_warehouse_quality_compare_safe_strong
  };


enum ISSX_EA2_TimeframeId
  {
   issx_ea2_tf_m5 = 0,
   issx_ea2_tf_m15,
   issx_ea2_tf_h1,
   issx_ea2_tf_count
  };


enum ISSX_EA2_HistoryFinalityClass
  {
   issx_ea2_finality_stable = 0,
   issx_ea2_finality_watch,
   issx_ea2_finality_unstable,
   issx_ea2_finality_recovering
  };

enum ISSX_EA2_CompatibilityClass
  {
   issx_ea2_compatibility_exact = 0,
   issx_ea2_compatibility_compatible,
   issx_ea2_compatibility_compatible_degraded,
   issx_ea2_compatibility_incompatible
  };

enum ISSX_EA2_ContinuityOrigin
  {
   issx_ea2_continuity_fresh_boot = 0,
   issx_ea2_continuity_resumed_current,
   issx_ea2_continuity_resumed_previous,
   issx_ea2_continuity_resumed_last_good,
   issx_ea2_continuity_rebuilt_clean
  };

enum ISSX_EA2_ContradictionSeverity
  {
   issx_ea2_contradiction_low = 0,
   issx_ea2_contradiction_moderate,
   issx_ea2_contradiction_high,
   issx_ea2_contradiction_blocking
  };

// ============================================================================
// SECTION 02: DTO TYPES
// ============================================================================

struct ISSX_EA2_TimeframeTrust
  {
   ISSX_EA2_TimeframeMode readiness;
   ISSX_FreshnessClass    freshness;
   double                 continuity;
   ISSX_TruthClass        quality_class;

   void Reset()
     {
      readiness=issx_ea2_tfmode_cold;
      freshness=issx_freshness_stale;
      continuity=0.0;
      quality_class=issx_truth_weak;
     }
  };

struct ISSX_EA2_TimeframeBlock
  {
   int                     bars_count;
   int                     effective_usable_bars;
   double                  sync_truth_score;
   double                  integrity_truth_score;
   double                  metric_truth_score;
   double                  alignment_truth_score;
   double                  time_alignment_score;
   double                  overlap_quality_score;
   double                  last_bar_finality_score;
   double                  partial_bar_contamination_score;
   double                  sample_depth_score;
   double                  sample_diversity_score;
   double                  metric_stability_score;
   ISSX_MetricSourceMode   metric_source_mode;
   string                  metric_build_state;
   string                  metric_rebuild_reason;
   datetime                last_complete_bar_time;
   bool                    bar_time_monotonic_ok;
   double                  gap_density;
   double                  history_structure_score;
   double                  metric_input_sufficiency_score;
   bool                    metric_safe_for_cross_symbol_compare;
   ISSX_MetricCompareClass metric_compare_class;
   bool                    usable_for_20m_to_90m;
   bool                    usable_for_90m_to_4h;
   bool                    usable_for_4h_to_8h;
   double                  window_use_confidence;
   int                     last_bar_rewrite_count_recent;
   double                  bar_hash_drift_score;
   double                  close_mutation_risk;
   ISSX_EA2_HistoryFinalityClass history_finality_class;
   int                     post_repair_stability_cycles;
   ISSX_MetricCompareClass compare_class_cap_while_recovering;
   bool                    finality_recovery_gate;
   ISSX_EA2_TimeframeMode  mode;
   ISSX_EA2_HistoryReadinessState readiness_state;
   ISSX_EA2_RewriteClass    rewrite_class;
   ISSX_EA2_WarehouseQuality warehouse_quality;
   int                     warehouse_retained_bar_count;
   int                     effective_lookback_bars;
   bool                    warehouse_clip_flag;
   bool                    warmup_sufficient_flag;
   datetime                last_sync_time;
   datetime                last_closed_bar_open_time;
   int                     recent_rewrite_span_bars;
   int                     gap_count;
   string                  finality_state;
   ulong                   continuity_hash;
   ulong                   trailing_finality_hash;
   int                     changed_flag_epoch;
   string                  hydration_reason;
   string                  tf_name;
   ENUM_TIMEFRAMES         timeframe;

   void Reset()
     {
      bars_count=0;
      effective_usable_bars=0;
      sync_truth_score=0.0;
      integrity_truth_score=0.0;
      metric_truth_score=0.0;
      alignment_truth_score=0.0;
      time_alignment_score=0.0;
      overlap_quality_score=0.0;
      last_bar_finality_score=0.0;
      partial_bar_contamination_score=0.0;
      sample_depth_score=0.0;
      sample_diversity_score=0.0;
      metric_stability_score=0.0;
      metric_source_mode=issx_metric_source_direct;
      metric_build_state="cold";
      metric_rebuild_reason="";
      last_complete_bar_time=0;
      bar_time_monotonic_ok=false;
      gap_density=1.0;
      history_structure_score=0.0;
      metric_input_sufficiency_score=0.0;
      metric_safe_for_cross_symbol_compare=false;
      metric_compare_class=issx_metric_compare_local_only;
      usable_for_20m_to_90m=false;
      usable_for_90m_to_4h=false;
      usable_for_4h_to_8h=false;
      window_use_confidence=0.0;
      last_bar_rewrite_count_recent=0;
      bar_hash_drift_score=0.0;
      close_mutation_risk=0.0;
      history_finality_class=issx_ea2_finality_unstable;
      post_repair_stability_cycles=0;
      compare_class_cap_while_recovering=issx_metric_compare_local_only;
      finality_recovery_gate=false;
      mode=issx_ea2_tfmode_cold;
      readiness_state=issx_ea2_history_never_requested;
      rewrite_class=issx_ea2_rewrite_none;
      warehouse_quality=issx_ea2_warehouse_quality_unknown;
      warehouse_retained_bar_count=0;
      effective_lookback_bars=0;
      warehouse_clip_flag=false;
      warmup_sufficient_flag=false;
      last_sync_time=0;
      last_closed_bar_open_time=0;
      recent_rewrite_span_bars=0;
      gap_count=0;
      finality_state="unknown";
      continuity_hash=0;
      trailing_finality_hash=0;
      changed_flag_epoch=0;
      hydration_reason="";
      tf_name="";
      timeframe=PERIOD_CURRENT;
     }
  };

struct ISSX_EA2_HotMetrics
  {
   double atr_points_m5;
   double atr_points_m15;
   double return_vol_ratio;
   double spread_to_atr_efficiency;
   double bar_continuity_score;
   double gap_penalty;

   double body_wick_ratio_median;
   double overlap_percentile_recent;
   double close_location_percentile_recent;
   int    inside_outside_bar_counts_recent;
   string intraday_activity_state;
   string liquidity_regime_class;
   string volatility_regime_class;
   string expansion_state_class;
   string movement_quality_class;
   string movement_maturity_class;
   string microstructure_noise_class;
   string range_efficiency_class;
   double noise_to_range_ratio;
   string bar_overlap_class;
   string directional_persistence_class;
   string two_way_rotation_class;
   string gap_disruption_class;
   double recent_compression_expansion_ratio;
   string movement_to_cost_efficiency_class;
   string constructability_class;

   void Reset()
     {
      atr_points_m5=0.0;
      atr_points_m15=0.0;
      return_vol_ratio=0.0;
      spread_to_atr_efficiency=0.0;
      bar_continuity_score=0.0;
      gap_penalty=0.0;
      body_wick_ratio_median=0.0;
      overlap_percentile_recent=0.0;
      close_location_percentile_recent=0.0;
      inside_outside_bar_counts_recent=0;
      intraday_activity_state="unknown";
      liquidity_regime_class="unknown";
      volatility_regime_class="unknown";
      expansion_state_class="unknown";
      movement_quality_class="unknown";
      movement_maturity_class="unknown";
      microstructure_noise_class="unknown";
      range_efficiency_class="unknown";
      noise_to_range_ratio=0.0;
      bar_overlap_class="unknown";
      directional_persistence_class="unknown";
      two_way_rotation_class="unknown";
      gap_disruption_class="unknown";
      recent_compression_expansion_ratio=0.0;
      movement_to_cost_efficiency_class="unknown";
      constructability_class="unknown";
     }
  };

struct ISSX_EA2_StructuralContext
  {
   double compression_score;
   double expansion_score;
   double breakout_proximity_score;
   double range_position_score;
   double structure_stability_score;
   double micro_noise_risk;
   double structure_clarity_score;

   void Reset()
     {
      compression_score=0.0;
      expansion_score=0.0;
      breakout_proximity_score=0.0;
      range_position_score=0.0;
      structure_stability_score=0.0;
      micro_noise_risk=0.0;
      structure_clarity_score=0.0;
     }
  };

struct ISSX_EA2_HistoryProvenance
  {
   string                    warm_or_deep_profile;
   string                    timeframes_used_for_active_metrics;
   datetime                  oldest_bar_used;
   datetime                  newest_bar_used;
   int                       effective_sample_count;
   string                    metric_degradation_reason;
   double                    recent_repair_activity_score;
   double                    history_flap_risk;
   double                    session_alignment_score;
   double                    active_session_bar_ratio;
   double                    dead_session_bar_ratio;
   double                    history_relevance_score;
   int                       flap_count_recent;
   double                    flap_severity_score;
   bool                      temporary_rank_suspension;
   int                       recovery_stability_cycles_required;
   int                       history_bloat_prevented_count;
   ISSX_EA2_ContinuityOrigin     continuity_origin;
   bool                      resumed_from_persistence;
   ISSX_EA2_CompatibilityClass   source_compatibility_class;
   string                    history_store_path;
   string                    history_index_path;
   bool                      live_bar_tracked_separately;
   bool                      dirty_shard_flush_preferred;

   void Reset()
     {
      warm_or_deep_profile="cold";
      timeframes_used_for_active_metrics="";
      oldest_bar_used=0;
      newest_bar_used=0;
      effective_sample_count=0;
      metric_degradation_reason="";
      recent_repair_activity_score=0.0;
      history_flap_risk=0.0;
      session_alignment_score=0.0;
      active_session_bar_ratio=0.0;
      dead_session_bar_ratio=0.0;
      history_relevance_score=0.0;
      flap_count_recent=0;
      flap_severity_score=0.0;
      temporary_rank_suspension=false;
      recovery_stability_cycles_required=0;
      history_bloat_prevented_count=0;
      continuity_origin=issx_ea2_continuity_fresh_boot;
      resumed_from_persistence=false;
      source_compatibility_class=issx_ea2_compatibility_incompatible;
      history_store_path="";
      history_index_path="";
      live_bar_tracked_separately=true;
      dirty_shard_flush_preferred=true;
     }
  };

struct ISSX_EA2_HistoryJudgment
  {
   double usable_range_score;
   double continuity_score;
   double staleness_score;
   double gap_risk_score;
   double metric_trust_score;
   double history_data_quality_score;

   void Reset()
     {
      usable_range_score=0.0;
      continuity_score=0.0;
      staleness_score=1.0;
      gap_risk_score=1.0;
      metric_trust_score=0.0;
      history_data_quality_score=0.0;
     }
  };

struct ISSX_EA2_TimeframeMap
  {
   ISSX_EA2_TimeframeTrust tf_m5_trust;
   ISSX_EA2_TimeframeTrust tf_m15_trust;
   ISSX_EA2_TimeframeTrust tf_h1_trust;

   void Reset()
     {
      tf_m5_trust.Reset();
      tf_m15_trust.Reset();
      tf_h1_trust.Reset();
     }
  };

struct ISSX_EA2_SymbolState
  {
   string                    symbol_raw;
   string                    symbol_norm;
   bool                      selected_for_hydration;
   bool                      history_ready_for_ranking;
   bool                      history_ready_for_intelligence;
   bool                      changed_since_last_publish;
   bool                      marketwatch_selected;
   bool                      sync_requested;
   bool                      contradiction_present;
   ISSX_EA2_ContradictionSeverity contradiction_severity_max;
   string                    contradiction_flags;
   string                    dominant_degradation_reason;
   int                       changed_timeframe_count;
   int                       changed_tf_mask;
   datetime                  last_history_touch;
   datetime                  last_publish_touch;
   ISSX_EA2_TimeframeBlock   tf[issx_ea2_tf_count];
   ISSX_EA2_TimeframeMap     trust_map;
   ISSX_EA2_HotMetrics       hot_metrics;
   ISSX_EA2_StructuralContext structural_context;
   ISSX_EA2_HistoryProvenance provenance;
   ISSX_EA2_HistoryJudgment  judgment;
   ISSX_TruthClass           truth_class;
   ISSX_FreshnessClass       freshness_class;
   ISSX_AcceptanceType       acceptance_type;
   string                    intraday_activity_state;
   string                    liquidity_regime_class;
   string                    volatility_regime_class;
   string                    expansion_state_class;
   string                    movement_quality_class;
   string                    movement_maturity_class;
   string                    microstructure_noise_class;
   string                    range_efficiency_class;
   double                    noise_to_range_ratio;
   string                    bar_overlap_class;
   string                    directional_persistence_class;
   string                    two_way_rotation_class;
   string                    gap_disruption_class;
   double                    recent_compression_expansion_ratio;
   string                    movement_to_cost_efficiency_class;
   string                    constructability_class;

   void Reset()
     {
      symbol_raw="";
      symbol_norm="";
      selected_for_hydration=false;
      history_ready_for_ranking=false;
      history_ready_for_intelligence=false;
      changed_since_last_publish=false;
      marketwatch_selected=false;
      sync_requested=false;
      contradiction_present=false;
      contradiction_severity_max=issx_ea2_contradiction_low;
      contradiction_flags="";
      dominant_degradation_reason="";
      changed_timeframe_count=0;
      changed_tf_mask=0;
      last_history_touch=0;
      last_publish_touch=0;
      for(int i=0;i<issx_ea2_tf_count;i++)
         tf[i].Reset();
      trust_map.Reset();
      hot_metrics.Reset();
      structural_context.Reset();
      provenance.Reset();
      judgment.Reset();
      truth_class=issx_truth_weak;
      freshness_class=issx_freshness_stale;
      acceptance_type=issx_acceptance_rejected;
     }
  };

struct ISSX_EA2_UniverseState
  {
   int     broker_universe;
   int     eligible_universe;
   int     active_universe;
   int     rankable_universe;
   string  broker_universe_fingerprint;
   string  eligible_universe_fingerprint;
   string  active_universe_fingerprint;
   string  rankable_universe_fingerprint;
   string  universe_drift_class;

   void Reset()
     {
      broker_universe=0;
      eligible_universe=0;
      active_universe=0;
      rankable_universe=0;
      broker_universe_fingerprint="";
      eligible_universe_fingerprint="";
      active_universe_fingerprint="";
      rankable_universe_fingerprint="";
      universe_drift_class="none";
     }
  };

struct ISSX_EA2_DeltaState
  {
   int    changed_symbol_count;
   string changed_symbol_ids;
   int    changed_family_count;
   int    changed_timeframe_count;
   string changed_timeframe_ids;
   int    queue_driven_deep_count;
   int    cache_reuse_count;

   void Reset()
     {
      changed_symbol_count=0;
      changed_symbol_ids="";
      changed_family_count=0;
      changed_timeframe_count=0;
      changed_timeframe_ids="";
      queue_driven_deep_count=0;
      cache_reuse_count=0;
     }
  };

struct ISSX_EA2_CycleCounters
  {
   int symbols_total;
   int symbols_minimal_ready;
   int symbols_ranking_ready;
   int symbols_intelligence_ready;
   int symbols_degraded;
   int timeframes_cold;
   int timeframes_syncing;
   int timeframes_ranking_ready;
   int timeframes_intelligence_ready;
   int repairs_active;
   int rewrite_watch_count;
   int temporary_rank_suspension_count;
   int contradiction_count;
   int contradiction_blocking_count;

   void Reset()
     {
      symbols_total=0;
      symbols_minimal_ready=0;
      symbols_ranking_ready=0;
      symbols_intelligence_ready=0;
      symbols_degraded=0;
      timeframes_cold=0;
      timeframes_syncing=0;
      timeframes_ranking_ready=0;
      timeframes_intelligence_ready=0;
      repairs_active=0;
      rewrite_watch_count=0;
      temporary_rank_suspension_count=0;
      contradiction_count=0;
      contradiction_blocking_count=0;
     }
  };

struct ISSX_EA2_State
  {
   ISSX_StageHeader          header;
   ISSX_Manifest             manifest;
   ISSX_RuntimeState         runtime;
   ISSX_EA2_UniverseState    universe;
   ISSX_EA2_DeltaState       delta;
   ISSX_EA2_CycleCounters    counters;
   ISSX_EA2_CompatibilityClass   upstream_compatibility_class;
   string                    upstream_source_used;
   string                    upstream_source_reason;
   int                       fallback_depth_used;
   double                    upstream_compatibility_score;
   double                    fallback_penalty_applied;
   bool                      projection_partial_success_flag;
   bool                      degraded_flag;
   bool                      recovery_publish_flag;
   bool                      stage_minimum_ready_flag;
   string                    stage_publishability_state;
   string                    dependency_block_reason;
   string                    debug_weak_link_code;
   int                       symbol_count;
   ISSX_EA2_SymbolState      symbols[];

   void Reset()
     {
      ZeroMemory(header);
      ZeroMemory(manifest);
      runtime.Reset();
      universe.Reset();
      delta.Reset();
      counters.Reset();
      upstream_compatibility_class=issx_ea2_compatibility_incompatible;
      upstream_source_used="";
      upstream_source_reason="";
      fallback_depth_used=0;
      upstream_compatibility_score=0.0;
      fallback_penalty_applied=0.0;
      projection_partial_success_flag=false;
      degraded_flag=false;
      recovery_publish_flag=false;
      stage_minimum_ready_flag=false;
      stage_publishability_state="blocked";
      dependency_block_reason="";
      debug_weak_link_code="";
      symbol_count=0;
      ArrayResize(symbols,0);
     }
  };

// ============================================================================
// SECTION 03: HELPERS
// ============================================================================

class ISSX_HistoryEngine
  {
private:
   static string TfNameByIndex(const int idx)
     {
      switch(idx)
        {
         case issx_ea2_tf_m5:  return "m5";
         case issx_ea2_tf_m15: return "m15";
         case issx_ea2_tf_h1:  return "h1";
         default:              return "na";
        }
     }

   static ENUM_TIMEFRAMES TfValueByIndex(const int idx)
     {
      switch(idx)
        {
         case issx_ea2_tf_m5:  return PERIOD_M5;
         case issx_ea2_tf_m15: return PERIOD_M15;
         case issx_ea2_tf_h1:  return PERIOD_H1;
         default:              return PERIOD_CURRENT;
        }
     }

   static int BarsTargetMinByIndex(const int idx)
     {
      switch(idx)
        {
         case issx_ea2_tf_m5:  return 96;
         case issx_ea2_tf_m15: return 96;
         case issx_ea2_tf_h1:  return 64;
         default:              return 0;
        }
     }

   static string MetricCompareClassToStringLocal(const ISSX_MetricCompareClass v)
     {
      switch(v)
        {
         case issx_metric_compare_local_only:    return "local_only";
         case issx_metric_compare_bucket_safe:   return "bucket_safe";
         case issx_metric_compare_frontier_safe: return "frontier_safe";
         case issx_metric_compare_global_safe:   return "global_safe";
         default:                                return "local_only";
        }
     }

   static string FinalityClassToStringLocal(const ISSX_EA2_HistoryFinalityClass v)
     {
      switch(v)
        {
         case issx_ea2_finality_stable:     return "stable";
         case issx_ea2_finality_watch:      return "watch";
         case issx_ea2_finality_unstable:   return "unstable";
         case issx_ea2_finality_recovering: return "recovering";
         default:                               return "unstable";
        }
     }

   static string TruthClassToStringLocal(const ISSX_TruthClass v)
     {
      switch(v)
        {
         case issx_truth_strong:     return "strong";
         case issx_truth_acceptable: return "acceptable";
         case issx_truth_degraded:   return "degraded";
         case issx_truth_weak:       return "weak";
         default:                    return "weak";
        }
     }

   static string FreshnessClassToStringLocal(const ISSX_FreshnessClass v)
     {
      switch(v)
        {
         case issx_freshness_fresh:  return "fresh";
         case issx_freshness_usable: return "usable";
         case issx_freshness_aging:  return "aging";
         case issx_freshness_stale:  return "stale";
         default:                    return "stale";
        }
     }

   static string CompatibilityClassToStringLocal(const ISSX_EA2_CompatibilityClass v)
     {
      switch(v)
        {
         case issx_ea2_compatibility_exact:              return "exact";
         case issx_ea2_compatibility_compatible:         return "compatible";
         case issx_ea2_compatibility_compatible_degraded:return "compatible_degraded";
         case issx_ea2_compatibility_incompatible:       return "incompatible";
         default:                                    return "incompatible";
        }
     }

   static string AcceptanceTypeToStringLocal(const ISSX_AcceptanceType v)
     {
      switch(v)
        {
         case issx_acceptance_for_pipeline:     return "accepted_for_pipeline";
         case issx_acceptance_for_ranking:      return "accepted_for_ranking";
         case issx_acceptance_for_intelligence: return "accepted_for_intelligence";
         case issx_acceptance_for_gpt_export:   return "accepted_for_gpt_export";
         case issx_acceptance_degraded:         return "accepted_degraded";
         case issx_acceptance_rejected:         return "rejected";
         default:                               return "rejected";
        }
     }

   static double Clamp01(const double v)
     {
      if(v<0.0) return 0.0;
      if(v>1.0) return 1.0;
      return v;
     }

   static bool CopyRatesSafe(const string symbol,
                             const ENUM_TIMEFRAMES tf,
                             const int count,
                             MqlRates &rates[])
     {
      ArraySetAsSeries(rates,true);
      ResetLastError();
      int copied=CopyRates(symbol,tf,0,count,rates);
      if(copied<=0)
         return false;
      ArrayResize(rates,copied);
      return true;
     }

   static bool TimeSeriesMonotonic(const MqlRates &rates[])
     {
      int n=(int)ArraySize(rates);
      if(n<=1) return true;
      for(int i=n-1;i>0;i--)
        {
         if(rates[i].time>=rates[i-1].time)
            return false;
        }
      return true;
     }

   static int CountGaps(const MqlRates &rates[], const int seconds_per_bar)
     {
      int n=(int)ArraySize(rates);
      if(n<=1 || seconds_per_bar<=0) return 0;
      int gaps=0;
      for(int i=n-1;i>0;i--)
        {
         long dt=(long)(rates[i-1].time-rates[i].time);
         if(dt>(seconds_per_bar*2))
            gaps++;
        }
      return gaps;
     }

   static double MedianRangePoints(const MqlRates &rates[], const double point)
     {
      int n=(int)ArraySize(rates);
      if(n<=0 || point<=0.0) return 0.0;
      double vals[];
      ArrayResize(vals,n);
      for(int i=0;i<n;i++)
         vals[i]=(rates[i].high-rates[i].low)/point;
      ArraySort(vals);
      if((n%2)==1) return vals[n/2];
      return 0.5*(vals[n/2-1]+vals[n/2]);
     }

   static double ApproxAtrPoints(const MqlRates &rates[], const double point, const int lookback)
     {
      int n=(int)ArraySize(rates);
      if(n<=1 || point<=0.0) return 0.0;
      int use=MathMin(n-1,lookback);
      if(use<=0) return 0.0;
      double sum=0.0;
      int cnt=0;
      for(int i=0;i<use;i++)
        {
         double prev_close=rates[i+1].close;
         double tr=MathMax(rates[i].high-rates[i].low,
                           MathMax(MathAbs(rates[i].high-prev_close),MathAbs(rates[i].low-prev_close)));
         sum+=tr/point;
         cnt++;
        }
      return (cnt>0 ? sum/cnt : 0.0);
     }

   static double ReturnVolRatio(const MqlRates &rates[])
     {
      int n=(int)ArraySize(rates);
      if(n<=8) return 0.0;
      double abs_sum=0.0, net=0.0;
      int cnt=0;
      for(int i=0;i<n-1 && i<48;i++)
        {
         double r=(rates[i].close-rates[i+1].close);
         abs_sum+=MathAbs(r);
         net+=r;
         cnt++;
        }
      if(cnt<=0 || abs_sum<=0.0) return 0.0;
      return Clamp01(MathAbs(net)/abs_sum);
     }

   static double BodyWickRatioMedian(const MqlRates &rates[])
     {
      int n=(int)ArraySize(rates);
      if(n<=0) return 0.0;
      int use=MathMin(n,24);
      double vals[];
      ArrayResize(vals,use);
      for(int i=0;i<use;i++)
        {
         double body=MathAbs(rates[i].close-rates[i].open);
         double full=MathMax(rates[i].high-rates[i].low,_Point);
         vals[i]=body/full;
        }
      ArraySort(vals);
      if((use%2)==1) return vals[use/2];
      return 0.5*(vals[use/2-1]+vals[use/2]);
     }

   static double CloseLocationPercentileRecent(const MqlRates &rates[])
     {
      int n=(int)ArraySize(rates);
      if(n<=0) return 0.0;
      int use=MathMin(n,24);
      double sum=0.0;
      for(int i=0;i<use;i++)
        {
         double full=rates[i].high-rates[i].low;
         if(full<=0.0) continue;
         sum += (rates[i].close-rates[i].low)/full;
        }
      return Clamp01(sum/(double)use);
     }

   static int InsideOutsideCountRecent(const MqlRates &rates[])
     {
      int n=(int)ArraySize(rates);
      if(n<=1) return 0;
      int use=MathMin(n-1,24);
      int cnt=0;
      for(int i=0;i<use;i++)
        {
         bool inside=(rates[i].high<=rates[i+1].high && rates[i].low>=rates[i+1].low);
         bool outside=(rates[i].high>=rates[i+1].high && rates[i].low<=rates[i+1].low);
         if(inside || outside) cnt++;
        }
      return cnt;
     }

   static double OverlapPercentileRecent(const MqlRates &rates[])
     {
      int n=(int)ArraySize(rates);
      if(n<=1) return 0.0;
      int use=MathMin(n-1,24);
      double sum=0.0;
      for(int i=0;i<use;i++)
        {
         double hi=MathMin(rates[i].high,rates[i+1].high);
         double lo=MathMax(rates[i].low,rates[i+1].low);
         double overlap=MathMax(0.0,hi-lo);
         double full=MathMax(rates[i+1].high-rates[i+1].low,_Point);
         sum += overlap/full;
        }
      return Clamp01(sum/(double)use);
     }

   static void ApplyTrustMap(ISSX_EA2_SymbolState &s)
     {
      s.trust_map.Reset();

      for(int i=0;i<issx_ea2_tf_count;i++)
        {
         ISSX_EA2_TimeframeTrust trust;
         trust.Reset();

         trust.continuity=Clamp01((double)s.tf[i].post_repair_stability_cycles/5.0);
         trust.quality_class = (s.tf[i].metric_truth_score>=0.80 ? issx_truth_strong :
                                s.tf[i].metric_truth_score>=0.60 ? issx_truth_acceptable :
                                s.tf[i].metric_truth_score>=0.40 ? issx_truth_degraded :
                                                                   issx_truth_weak);

         datetime now=TimeCurrent();
         long age_sec=(s.tf[i].last_complete_bar_time>0 ? (long)(now-s.tf[i].last_complete_bar_time) : 999999);
         trust.freshness = (age_sec<=1800 ? issx_freshness_fresh :
                            age_sec<=7200 ? issx_freshness_usable :
                            age_sec<=21600 ? issx_freshness_aging :
                                             issx_freshness_stale);

         trust.readiness = s.tf[i].mode;

         switch(i)
           {
            case issx_ea2_tf_m5:  s.trust_map.tf_m5_trust=trust;  break;
            case issx_ea2_tf_m15: s.trust_map.tf_m15_trust=trust; break;
            case issx_ea2_tf_h1:  s.trust_map.tf_h1_trust=trust;  break;
           }
        }
     }

   static void UpdateJudgment(ISSX_EA2_SymbolState &s)
     {
      s.judgment.Reset();

      double continuity=(s.trust_map.tf_m5_trust.continuity + s.trust_map.tf_m15_trust.continuity + s.trust_map.tf_h1_trust.continuity)/3.0;
      double staleness = (double)((int)s.trust_map.tf_m5_trust.freshness + (int)s.trust_map.tf_m15_trust.freshness + (int)s.trust_map.tf_h1_trust.freshness) / 9.0;
      double gap_risk=(s.tf[issx_ea2_tf_m5].gap_density + s.tf[issx_ea2_tf_m15].gap_density + s.tf[issx_ea2_tf_h1].gap_density)/3.0;
      double usable=(s.tf[issx_ea2_tf_m5].window_use_confidence + s.tf[issx_ea2_tf_m15].window_use_confidence + s.tf[issx_ea2_tf_h1].window_use_confidence)/3.0;
      double metric=(s.tf[issx_ea2_tf_m5].metric_truth_score + s.tf[issx_ea2_tf_m15].metric_truth_score + s.tf[issx_ea2_tf_h1].metric_truth_score)/3.0;

      s.judgment.usable_range_score=Clamp01(usable);
      s.judgment.continuity_score=Clamp01(continuity);
      s.judgment.staleness_score=Clamp01(1.0-staleness);
      s.judgment.gap_risk_score=Clamp01(gap_risk);
      s.judgment.metric_trust_score=Clamp01(metric);

      double q = (0.28*s.judgment.usable_range_score) +
                 (0.24*s.judgment.continuity_score) +
                 (0.24*s.judgment.metric_trust_score) +
                 (0.12*(1.0-s.judgment.gap_risk_score)) +
                 (0.12*(1.0-s.judgment.staleness_score));

      if(s.provenance.temporary_rank_suspension)
         q*=0.70;
      if(s.contradiction_present && s.contradiction_severity_max>=issx_ea2_contradiction_high)
         q*=0.75;

      s.judgment.history_data_quality_score=Clamp01(q);

      s.history_ready_for_ranking =
         (s.tf[issx_ea2_tf_m5].metric_compare_class>=issx_metric_compare_bucket_safe ||
          s.tf[issx_ea2_tf_m15].metric_compare_class>=issx_metric_compare_bucket_safe) &&
         (s.judgment.history_data_quality_score>=0.45) &&
         !s.provenance.temporary_rank_suspension;

      s.history_ready_for_intelligence =
         (s.tf[issx_ea2_tf_m15].metric_compare_class>=issx_metric_compare_frontier_safe) &&
         (s.tf[issx_ea2_tf_h1].metric_compare_class>=issx_metric_compare_frontier_safe) &&
         (s.judgment.history_data_quality_score>=0.62) &&
         (s.provenance.recent_repair_activity_score<0.60);

      s.acceptance_type =
         (s.history_ready_for_intelligence ? issx_acceptance_for_intelligence :
          s.history_ready_for_ranking ? issx_acceptance_for_ranking :
          s.judgment.history_data_quality_score>=0.30 ? issx_acceptance_degraded :
                                                        issx_acceptance_rejected);

      s.truth_class =
         (s.judgment.history_data_quality_score>=0.80 ? issx_truth_strong :
          s.judgment.history_data_quality_score>=0.60 ? issx_truth_acceptable :
          s.judgment.history_data_quality_score>=0.35 ? issx_truth_degraded :
                                                        issx_truth_weak);

      s.freshness_class =
         (s.trust_map.tf_m5_trust.freshness<=issx_freshness_usable &&
          s.trust_map.tf_m15_trust.freshness<=issx_freshness_usable ? issx_freshness_fresh :
          s.trust_map.tf_h1_trust.freshness<=issx_freshness_usable ? issx_freshness_usable :
          s.trust_map.tf_m15_trust.freshness<=issx_freshness_aging ? issx_freshness_aging :
                                                                     issx_freshness_stale);

      s.dominant_degradation_reason="";
      if(!s.history_ready_for_ranking)
         s.dominant_degradation_reason="comparison_not_safe";
      if(s.provenance.temporary_rank_suspension)
         s.dominant_degradation_reason="repair_stability_window";
      if(s.judgment.history_data_quality_score<0.30)
         s.dominant_degradation_reason="history_quality_too_low";
     }

   static void UpdateStructuralContext(ISSX_EA2_SymbolState &s)
     {
      double a=s.hot_metrics.atr_points_m5;
      double b=s.hot_metrics.atr_points_m15;
      double eff=s.hot_metrics.spread_to_atr_efficiency;
      double ov=s.hot_metrics.overlap_percentile_recent;
      double loc=s.hot_metrics.close_location_percentile_recent;
      double body=s.hot_metrics.body_wick_ratio_median;

      s.structural_context.compression_score        = Clamp01((1.0-eff) * (1.0-body));
      s.structural_context.expansion_score          = Clamp01(0.50*a/MathMax(1.0,b) + 0.50*body);
      s.structural_context.breakout_proximity_score = Clamp01(MathAbs(loc-0.5)*2.0);
      s.structural_context.range_position_score     = Clamp01(loc);
      s.structural_context.structure_stability_score= Clamp01(0.5*s.hot_metrics.bar_continuity_score + 0.5*(1.0-s.tf[issx_ea2_tf_m15].close_mutation_risk));
      s.structural_context.micro_noise_risk         = Clamp01(0.5*ov + 0.5*(1.0-body));
      s.structural_context.structure_clarity_score  = Clamp01(0.4*body + 0.3*(1.0-ov) + 0.3*s.structural_context.structure_stability_score);
     }

   static void ScanContradictions(ISSX_EA2_SymbolState &s)
     {
      s.contradiction_present=false;
      s.contradiction_severity_max=issx_ea2_contradiction_low;
      s.contradiction_flags="";

      if(s.history_ready_for_ranking &&
         s.tf[issx_ea2_tf_m15].history_finality_class==issx_ea2_finality_unstable)
        {
         s.contradiction_present=true;
         s.contradiction_severity_max=issx_ea2_contradiction_high;
         s.contradiction_flags="ranking_ready_with_unstable_finality";
        }

      if(s.tf[issx_ea2_tf_h1].metric_compare_class>=issx_metric_compare_frontier_safe &&
         s.tf[issx_ea2_tf_h1].overlap_quality_score<0.35)
        {
         s.contradiction_present=true;
         if(s.contradiction_flags!="") s.contradiction_flags+="|";
         s.contradiction_flags+="frontier_safe_with_weak_overlap";
         if(s.contradiction_severity_max<issx_ea2_contradiction_moderate)
            s.contradiction_severity_max=issx_ea2_contradiction_moderate;
        }

      if(s.history_ready_for_intelligence &&
         s.provenance.recent_repair_activity_score>0.75)
        {
         s.contradiction_present=true;
         if(s.contradiction_flags!="") s.contradiction_flags+="|";
         s.contradiction_flags+="intelligence_ready_while_repair_severe";
         s.contradiction_severity_max=issx_ea2_contradiction_blocking;
        }
     }

   static void UpdateCounters(ISSX_EA2_State &st)
     {
      st.counters.Reset();
      st.counters.symbols_total=ArraySize(st.symbols);
      st.symbol_count=st.counters.symbols_total;

      for(int i=0;i<ArraySize(st.symbols);i++)
        {
         ISSX_EA2_SymbolState &s = st.symbols[i];
         if(s.acceptance_type==issx_acceptance_degraded) st.counters.symbols_degraded++;
         if(s.history_ready_for_ranking) st.counters.symbols_ranking_ready++;
         if(s.history_ready_for_intelligence) st.counters.symbols_intelligence_ready++;
         if(s.judgment.history_data_quality_score>=0.25) st.counters.symbols_minimal_ready++;
         if(s.provenance.temporary_rank_suspension) st.counters.temporary_rank_suspension_count++;
         if(s.contradiction_present)
           {
            st.counters.contradiction_count++;
            if(s.contradiction_severity_max>=issx_ea2_contradiction_blocking)
               st.counters.contradiction_blocking_count++;
           }

         for(int t=0;t<issx_ea2_tf_count;t++)
           {
            switch(st.symbols[i].tf[t].mode)
              {
               case issx_ea2_tfmode_cold:              st.counters.timeframes_cold++; break;
               case issx_ea2_tfmode_syncing:           st.counters.timeframes_syncing++; break;
               case issx_ea2_tfmode_ranking_ready:     st.counters.timeframes_ranking_ready++; break;
               case issx_ea2_tfmode_intelligence_ready:st.counters.timeframes_intelligence_ready++; break;
               case issx_ea2_tfmode_degraded:          st.counters.repairs_active++; break;
               default: break;
              }

            if(st.symbols[i].tf[t].history_finality_class==issx_ea2_finality_watch)
               st.counters.rewrite_watch_count++;
           }
        }
     }

public:
   static void PrepareEmptySymbol(ISSX_EA2_SymbolState &s,const string symbol)
     {
      s.Reset();
      s.symbol_raw=symbol;
      s.symbol_norm=ISSX_Util::Upper(symbol);

      for(int i=0;i<issx_ea2_tf_count;i++)
        {
         s.tf[i].Reset();
         s.tf[i].tf_name=TfNameByIndex(i);
         s.tf[i].timeframe=TfValueByIndex(i);
         s.tf[i].readiness_state=issx_ea2_history_never_requested;
         s.tf[i].last_sync_time=0;
        }
      s.provenance.history_store_path=ISSX_Path::StageFolder("ea2")+"history_store/";
      s.provenance.history_index_path=ISSX_Path::StageFolder("ea2")+"history_index/";
     }

   static bool HydrateSymbolTimeframe(ISSX_EA2_SymbolState &s,
                                      const int tf_index,
                                      const double point,
                                      const bool deep_profile)
     {
      if(tf_index<0 || tf_index>=issx_ea2_tf_count)
         return false;

      MqlRates rates[];
      int request=(deep_profile ? 320 : 120);
      s.tf[tf_index].readiness_state=issx_ea2_history_requested_sync;
      s.tf[tf_index].warehouse_retained_bar_count=0;
      s.tf[tf_index].effective_lookback_bars=0;
      s.tf[tf_index].warehouse_clip_flag=false;
      s.tf[tf_index].warmup_sufficient_flag=false;
      s.tf[tf_index].last_sync_time=TimeCurrent();
      if(!CopyRatesSafe(s.symbol_raw,TfValueByIndex(tf_index),request,rates))
        {
         s.tf[tf_index].Reset();
         s.tf[tf_index].tf_name=TfNameByIndex(tf_index);
         s.tf[tf_index].timeframe=TfValueByIndex(tf_index);
         s.tf[tf_index].metric_build_state="copy_failed";
         s.tf[tf_index].mode=issx_ea2_tfmode_syncing;
         s.changed_tf_mask |= (1<<tf_index);
         s.changed_timeframe_count++;
         return false;
        }

      ISSX_EA2_TimeframeBlock &tf = s.tf[tf_index];
      tf.Reset();
      tf.tf_name=TfNameByIndex(tf_index);
      tf.timeframe=TfValueByIndex(tf_index);
      tf.bars_count=ArraySize(rates);
      tf.effective_usable_bars=MathMax(0,tf.bars_count-1);
      tf.last_complete_bar_time=(tf.effective_usable_bars>0 ? rates[1].time : 0);
      tf.bar_time_monotonic_ok=TimeSeriesMonotonic(rates);

      int sec = PeriodSeconds(tf.timeframe);
      int gaps = CountGaps(rates,sec);
      tf.gap_density=(tf.effective_usable_bars>0 ? (double)gaps/(double)MathMax(1,tf.effective_usable_bars) : 1.0);

      double min_target=(double)BarsTargetMinByIndex(tf_index);
      tf.sample_depth_score=Clamp01((double)tf.effective_usable_bars/MathMax(1.0,min_target));
      tf.sample_diversity_score=Clamp01(1.0-tf.gap_density);
      tf.sync_truth_score=Clamp01(0.60*tf.sample_depth_score + 0.40*tf.sample_diversity_score);
      tf.integrity_truth_score=Clamp01(0.50*(tf.bar_time_monotonic_ok?1.0:0.0) + 0.50*(1.0-tf.gap_density));

      tf.last_bar_rewrite_count_recent=0;
      tf.bar_hash_drift_score=0.0;
      tf.close_mutation_risk=Clamp01(tf.gap_density*1.5);
      tf.last_bar_finality_score=Clamp01(tf.integrity_truth_score - tf.close_mutation_risk*0.5);
      tf.partial_bar_contamination_score=Clamp01((tf.bars_count>0 ? 0.15 : 1.0));

      if(tf.last_bar_finality_score>=0.80 && tf.close_mutation_risk<0.20)
         tf.history_finality_class=issx_ea2_finality_stable;
      else if(tf.last_bar_finality_score>=0.60)
         tf.history_finality_class=issx_ea2_finality_watch;
      else if(tf.sample_depth_score>=0.30)
         tf.history_finality_class=issx_ea2_finality_recovering;
      else
         tf.history_finality_class=issx_ea2_finality_unstable;

      tf.metric_truth_score=Clamp01(0.35*tf.sync_truth_score + 0.35*tf.integrity_truth_score + 0.30*(1.0-tf.partial_bar_contamination_score));
      tf.alignment_truth_score=Clamp01(0.60*tf.integrity_truth_score + 0.40*(tf.bar_time_monotonic_ok?1.0:0.0));
      tf.time_alignment_score=tf.alignment_truth_score;
      tf.overlap_quality_score=Clamp01(1.0-tf.gap_density);
      tf.history_structure_score=Clamp01(0.50*tf.integrity_truth_score + 0.50*tf.sample_diversity_score);
      tf.metric_input_sufficiency_score=Clamp01(0.70*tf.sample_depth_score + 0.30*tf.sample_diversity_score);
      tf.metric_stability_score=Clamp01(0.50*tf.history_structure_score + 0.50*(1.0-tf.close_mutation_risk));
      tf.metric_source_mode=issx_metric_source_direct;
      tf.metric_build_state=(deep_profile ? "deep_built" : "warm_built");
      tf.metric_rebuild_reason=(deep_profile ? "queue_deep_refresh" : "delta_warm_refresh");

      tf.usable_for_20m_to_90m = (tf_index==issx_ea2_tf_m5 || tf_index==issx_ea2_tf_m15) && tf.metric_truth_score>=0.45;
      tf.usable_for_90m_to_4h  = (tf_index==issx_ea2_tf_m15 || tf_index==issx_ea2_tf_h1) && tf.metric_truth_score>=0.50;
      tf.usable_for_4h_to_8h   = (tf_index==issx_ea2_tf_h1) && tf.metric_truth_score>=0.55;
      tf.window_use_confidence = Clamp01(0.4*tf.metric_truth_score + 0.3*tf.overlap_quality_score + 0.3*tf.metric_input_sufficiency_score);

      tf.post_repair_stability_cycles = (tf.history_finality_class==issx_ea2_finality_stable ? 5 :
                                         tf.history_finality_class==issx_ea2_finality_watch ? 3 :
                                         tf.history_finality_class==issx_ea2_finality_recovering ? 1 : 0);

      tf.compare_class_cap_while_recovering =
         (tf.history_finality_class==issx_ea2_finality_recovering ? issx_metric_compare_bucket_safe :
          tf.history_finality_class==issx_ea2_finality_watch ? issx_metric_compare_frontier_safe :
          issx_metric_compare_global_safe);

      tf.finality_recovery_gate = (tf.post_repair_stability_cycles>=3);

      if(tf.metric_truth_score>=0.82 && tf.overlap_quality_score>=0.80 && tf.finality_recovery_gate)
         tf.metric_compare_class=issx_metric_compare_global_safe;
      else if(tf.metric_truth_score>=0.68 && tf.overlap_quality_score>=0.65 && tf.finality_recovery_gate)
         tf.metric_compare_class=issx_metric_compare_frontier_safe;
      else if(tf.metric_truth_score>=0.48 && tf.overlap_quality_score>=0.45)
         tf.metric_compare_class=issx_metric_compare_bucket_safe;
      else
         tf.metric_compare_class=issx_metric_compare_local_only;

      if(tf.history_finality_class==issx_ea2_finality_recovering &&
         tf.metric_compare_class>tf.compare_class_cap_while_recovering)
         tf.metric_compare_class=tf.compare_class_cap_while_recovering;

      tf.metric_safe_for_cross_symbol_compare = (tf.metric_compare_class>=issx_metric_compare_bucket_safe);

      tf.mode =
         (tf.metric_compare_class>=issx_metric_compare_frontier_safe && tf.history_finality_class==issx_ea2_finality_stable ? issx_ea2_tfmode_intelligence_ready :
          tf.metric_compare_class>=issx_metric_compare_bucket_safe ? issx_ea2_tfmode_ranking_ready :
          tf.metric_truth_score>=0.30 ? issx_ea2_tfmode_minimal_ready :
          tf.bars_count>0 ? issx_ea2_tfmode_syncing :
                            issx_ea2_tfmode_cold);

      tf.changed_flag_epoch=(int)TimeCurrent();
      tf.hydration_reason=(deep_profile ? "deep_queue" : "delta_first");

      s.changed_tf_mask |= (1<<tf_index);
      s.changed_timeframe_count++;
      s.changed_since_last_publish=true;
      s.last_history_touch=TimeCurrent();
      return true;
     }

   static void BuildHotMetrics(ISSX_EA2_SymbolState &s,const double point,const double spread_points_now)
     {
      MqlRates m5[];
      MqlRates m15[];

      bool ok5 = CopyRatesSafe(s.symbol_raw,PERIOD_M5,64,m5);
      bool ok15= CopyRatesSafe(s.symbol_raw,PERIOD_M15,64,m15);

      s.hot_metrics.Reset();

      if(ok5)
        {
         s.hot_metrics.atr_points_m5=ApproxAtrPoints(m5,point,14);
         s.hot_metrics.bar_continuity_score=Clamp01(1.0-s.tf[issx_ea2_tf_m5].gap_density);
         s.hot_metrics.body_wick_ratio_median=BodyWickRatioMedian(m5);
         s.hot_metrics.overlap_percentile_recent=OverlapPercentileRecent(m5);
         s.hot_metrics.close_location_percentile_recent=CloseLocationPercentileRecent(m5);
         s.hot_metrics.inside_outside_bar_counts_recent=InsideOutsideCountRecent(m5);
        }

      if(ok15)
        {
         s.hot_metrics.atr_points_m15=ApproxAtrPoints(m15,point,14);
         s.hot_metrics.return_vol_ratio=ReturnVolRatio(m15);
        }

      double atr_ref=MathMax(1.0,MathMax(s.hot_metrics.atr_points_m5,s.hot_metrics.atr_points_m15));
      s.hot_metrics.spread_to_atr_efficiency=Clamp01(1.0-(spread_points_now/atr_ref));
      s.hot_metrics.gap_penalty=Clamp01((s.tf[issx_ea2_tf_m5].gap_density+s.tf[issx_ea2_tf_m15].gap_density)/2.0);
     }

   static void UpdateProvenance(ISSX_EA2_SymbolState &s,const bool deep_profile)
     {
      s.provenance.warm_or_deep_profile=(deep_profile ? "deep" : "warm");
      s.provenance.timeframes_used_for_active_metrics="m5|m15|h1";
      s.provenance.oldest_bar_used =
         (s.tf[issx_ea2_tf_h1].last_complete_bar_time>0 ? s.tf[issx_ea2_tf_h1].last_complete_bar_time : s.tf[issx_ea2_tf_m15].last_complete_bar_time);
      s.provenance.newest_bar_used =
         (s.tf[issx_ea2_tf_m5].last_complete_bar_time>0 ? s.tf[issx_ea2_tf_m5].last_complete_bar_time : s.tf[issx_ea2_tf_m15].last_complete_bar_time);
      s.provenance.effective_sample_count =
         s.tf[issx_ea2_tf_m5].effective_usable_bars +
         s.tf[issx_ea2_tf_m15].effective_usable_bars +
         s.tf[issx_ea2_tf_h1].effective_usable_bars;

      s.provenance.metric_degradation_reason = (!s.history_ready_for_ranking ? "ranking_not_safe" : "");
      s.provenance.recent_repair_activity_score =
         Clamp01((s.tf[issx_ea2_tf_m5].history_finality_class==issx_ea2_finality_recovering ? 0.4 : 0.0) +
                 (s.tf[issx_ea2_tf_m15].history_finality_class==issx_ea2_finality_recovering ? 0.3 : 0.0) +
                 (s.tf[issx_ea2_tf_h1].history_finality_class==issx_ea2_finality_recovering ? 0.3 : 0.0));

      s.provenance.history_flap_risk=Clamp01((double)(
         s.tf[issx_ea2_tf_m5].last_bar_rewrite_count_recent +
         s.tf[issx_ea2_tf_m15].last_bar_rewrite_count_recent +
         s.tf[issx_ea2_tf_h1].last_bar_rewrite_count_recent)/10.0);

      s.provenance.session_alignment_score =
         Clamp01((s.tf[issx_ea2_tf_m5].alignment_truth_score +
                  s.tf[issx_ea2_tf_m15].alignment_truth_score +
                  s.tf[issx_ea2_tf_h1].alignment_truth_score)/3.0);

      s.provenance.active_session_bar_ratio = Clamp01(0.60 + 0.40*s.provenance.session_alignment_score);
      s.provenance.dead_session_bar_ratio   = Clamp01(1.0-s.provenance.active_session_bar_ratio);
      s.provenance.history_relevance_score  = Clamp01(0.50*s.provenance.session_alignment_score + 0.50*s.judgment.usable_range_score);
      s.provenance.flap_count_recent = s.tf[issx_ea2_tf_m5].last_bar_rewrite_count_recent +
                                       s.tf[issx_ea2_tf_m15].last_bar_rewrite_count_recent +
                                       s.tf[issx_ea2_tf_h1].last_bar_rewrite_count_recent;
      s.provenance.flap_severity_score=Clamp01(s.provenance.history_flap_risk);
      s.provenance.temporary_rank_suspension =
         (s.tf[issx_ea2_tf_m15].history_finality_class==issx_ea2_finality_unstable ||
          s.tf[issx_ea2_tf_h1].history_finality_class==issx_ea2_finality_unstable);

      s.provenance.recovery_stability_cycles_required =
         (s.provenance.temporary_rank_suspension ? 3 : 0);

      s.provenance.history_bloat_prevented_count = (deep_profile ? 0 : 1);
      if(s.provenance.source_compatibility_class==issx_ea2_compatibility_incompatible)
         s.provenance.source_compatibility_class=issx_ea2_compatibility_compatible;
     }

   static void FinalizeSymbol(ISSX_EA2_SymbolState &s,const double point,const double spread_points_now,const bool deep_profile)
     {
      BuildHotMetrics(s,point,spread_points_now);
      ApplyTrustMap(s);
      UpdateJudgment(s);
      UpdateStructuralContext(s);
      UpdateProvenance(s,deep_profile);
      UpdateJudgment(s);
      ScanContradictions(s);
      UpdateJudgment(s);
     }


   static string BuildSymbolJson(const ISSX_EA2_SymbolState &s)
     {
      ISSX_JsonWriter j;
      j.Reset();
      j.BeginObject();

      j.NameString("symbol_raw",s.symbol_raw);
      j.NameString("symbol_norm",s.symbol_norm);
      j.NameBool("history_ready_for_ranking",s.history_ready_for_ranking);
      j.NameBool("history_ready_for_intelligence",s.history_ready_for_intelligence);
      j.NameString("truth_class",TruthClassToStringLocal(s.truth_class));
      j.NameString("freshness_class",FreshnessClassToStringLocal(s.freshness_class));
      j.NameString("acceptance_type",AcceptanceTypeToStringLocal(s.acceptance_type));

      j.BeginObjectNamed("history_judgment_packet");
      j.NameDouble("usable_range_score",s.judgment.usable_range_score,4);
      j.NameDouble("continuity_score",s.judgment.continuity_score,4);
      j.NameDouble("staleness_score",s.judgment.staleness_score,4);
      j.NameDouble("gap_risk_score",s.judgment.gap_risk_score,4);
      j.NameDouble("metric_trust_score",s.judgment.metric_trust_score,4);
      j.NameDouble("history_data_quality_score",s.judgment.history_data_quality_score,4);
      j.EndObject();

      j.BeginObjectNamed("timeframe_trust_map");
      j.BeginObjectNamed("tf_m5_trust");  WriteTrustJson(j,s.trust_map.tf_m5_trust);  j.EndObject();
      j.BeginObjectNamed("tf_m15_trust"); WriteTrustJson(j,s.trust_map.tf_m15_trust); j.EndObject();
      j.BeginObjectNamed("tf_h1_trust");  WriteTrustJson(j,s.trust_map.tf_h1_trust);  j.EndObject();
      j.EndObject();

      j.BeginObjectNamed("structural_context");
      j.NameDouble("compression_score",s.structural_context.compression_score,4);
      j.NameDouble("expansion_score",s.structural_context.expansion_score,4);
      j.NameDouble("breakout_proximity_score",s.structural_context.breakout_proximity_score,4);
      j.NameDouble("range_position_score",s.structural_context.range_position_score,4);
      j.NameDouble("structure_stability_score",s.structural_context.structure_stability_score,4);
      j.NameDouble("micro_noise_risk",s.structural_context.micro_noise_risk,4);
      j.NameDouble("structure_clarity_score",s.structural_context.structure_clarity_score,4);
      j.EndObject();

      j.BeginObjectNamed("history_provenance");
      j.NameString("warm_or_deep_profile",s.provenance.warm_or_deep_profile);
      j.NameString("timeframes_used_for_active_metrics",s.provenance.timeframes_used_for_active_metrics);
      j.NameInt("effective_sample_count",s.provenance.effective_sample_count);
      j.NameString("metric_degradation_reason",s.provenance.metric_degradation_reason);
      j.NameDouble("recent_repair_activity_score",s.provenance.recent_repair_activity_score,4);
      j.NameDouble("history_flap_risk",s.provenance.history_flap_risk,4);
      j.NameDouble("session_alignment_score",s.provenance.session_alignment_score,4);
      j.NameDouble("history_relevance_score",s.provenance.history_relevance_score,4);
      j.NameBool("temporary_rank_suspension",s.provenance.temporary_rank_suspension);
      j.NameInt("recovery_stability_cycles_required",s.provenance.recovery_stability_cycles_required);
      j.NameInt("history_bloat_prevented_count",s.provenance.history_bloat_prevented_count);
      j.NameString("source_compatibility_class",CompatibilityClassToStringLocal(s.provenance.source_compatibility_class));
      j.EndObject();

      j.BeginArrayNamed("timeframes");
      for(int i=0;i<issx_ea2_tf_count;i++)
        {
         j.BeginObject();
         WriteTimeframeJson(j,s.tf[i]);
         j.EndObject();
        }
      j.EndArray();

      j.NameBool("contradiction_present",s.contradiction_present);
      j.NameString("contradiction_flags",s.contradiction_flags);
      j.NameString("dominant_degradation_reason",s.dominant_degradation_reason);

      j.EndObject();
      return j.ToString();
     }

   static void WriteTrustJson(ISSX_JsonWriter &j,const ISSX_EA2_TimeframeTrust &t)
     {
      j.NameString("readiness",TimeframeModeToString(t.readiness));
      j.NameString("freshness",FreshnessClassToStringLocal(t.freshness));
      j.NameDouble("continuity",t.continuity,4);
      j.NameString("quality_class",TruthClassToStringLocal(t.quality_class));
     }

   static void WriteTimeframeJson(ISSX_JsonWriter &j,const ISSX_EA2_TimeframeBlock &tf)
     {
      j.NameString("tf",tf.tf_name);
      j.NameInt("bars_count",tf.bars_count);
      j.NameInt("effective_usable_bars",tf.effective_usable_bars);
      j.NameDouble("sync_truth_score",tf.sync_truth_score,4);
      j.NameDouble("integrity_truth_score",tf.integrity_truth_score,4);
      j.NameDouble("metric_truth_score",tf.metric_truth_score,4);
      j.NameDouble("alignment_truth_score",tf.alignment_truth_score,4);
      j.NameDouble("time_alignment_score",tf.time_alignment_score,4);
      j.NameDouble("overlap_quality_score",tf.overlap_quality_score,4);
      j.NameDouble("last_bar_finality_score",tf.last_bar_finality_score,4);
      j.NameDouble("partial_bar_contamination_score",tf.partial_bar_contamination_score,4);
      j.NameDouble("sample_depth_score",tf.sample_depth_score,4);
      j.NameDouble("sample_diversity_score",tf.sample_diversity_score,4);
      j.NameDouble("metric_stability_score",tf.metric_stability_score,4);
      j.NameString("metric_build_state",tf.metric_build_state);
      j.NameString("metric_rebuild_reason",tf.metric_rebuild_reason);
      j.NameInt("last_complete_bar_time",(long)tf.last_complete_bar_time);
      j.NameBool("bar_time_monotonic_ok",tf.bar_time_monotonic_ok);
      j.NameDouble("gap_density",tf.gap_density,4);
      j.NameDouble("history_structure_score",tf.history_structure_score,4);
      j.NameDouble("metric_input_sufficiency_score",tf.metric_input_sufficiency_score,4);
      j.NameBool("metric_safe_for_cross_symbol_compare",tf.metric_safe_for_cross_symbol_compare);
      j.NameString("metric_compare_class",MetricCompareClassToStringLocal(tf.metric_compare_class));
      j.NameBool("usable_for_20m_to_90m",tf.usable_for_20m_to_90m);
      j.NameBool("usable_for_90m_to_4h",tf.usable_for_90m_to_4h);
      j.NameBool("usable_for_4h_to_8h",tf.usable_for_4h_to_8h);
      j.NameDouble("window_use_confidence",tf.window_use_confidence,4);
      j.NameInt("last_bar_rewrite_count_recent",tf.last_bar_rewrite_count_recent);
      j.NameDouble("bar_hash_drift_score",tf.bar_hash_drift_score,4);
      j.NameDouble("close_mutation_risk",tf.close_mutation_risk,4);
      j.NameString("history_finality_class",FinalityClassToStringLocal(tf.history_finality_class));
      j.NameInt("post_repair_stability_cycles",tf.post_repair_stability_cycles);
      j.NameString("compare_class_cap_while_recovering",MetricCompareClassToStringLocal(tf.compare_class_cap_while_recovering));
      j.NameBool("finality_recovery_gate",tf.finality_recovery_gate);
      j.NameString("mode",TimeframeModeToString(tf.mode));
      j.NameString("hydration_reason",tf.hydration_reason);
     }

   static string TimeframeModeToString(const ISSX_EA2_TimeframeMode mode)
     {
      switch(mode)
        {
         case issx_ea2_tfmode_cold:               return "cold";
         case issx_ea2_tfmode_syncing:            return "syncing";
         case issx_ea2_tfmode_minimal_ready:      return "minimal_ready";
         case issx_ea2_tfmode_ranking_ready:      return "ranking_ready";
         case issx_ea2_tfmode_intelligence_ready: return "intelligence_ready";
         case issx_ea2_tfmode_degraded:           return "degraded";
         default:                                 return "cold";
        }
     }

   static string BuildStageRootJson(ISSX_EA2_State &st)
     {
      UpdateCounters(st);

      ISSX_JsonWriter j;
      j.Reset();
      j.BeginObject();

      j.NameString("stage_id","ea2");
      j.NameInt("sequence_no",(long)st.manifest.sequence_no);
      j.NameInt("minute_id",(long)st.manifest.minute_id);
      j.NameString("schema_version",st.manifest.schema_version);
      j.NameInt("schema_epoch",st.manifest.schema_epoch);
      j.NameString("upstream_source_used",st.upstream_source_used);
      j.NameString("upstream_source_reason",st.upstream_source_reason);
      j.NameString("upstream_compatibility_class",CompatibilityClassToStringLocal(st.upstream_compatibility_class));
      j.NameDouble("upstream_compatibility_score",st.upstream_compatibility_score,4);
      j.NameInt("fallback_depth_used",st.fallback_depth_used);
      j.NameDouble("fallback_penalty_applied",st.fallback_penalty_applied,4);
      j.NameBool("degraded_flag",st.degraded_flag);
      j.NameBool("recovery_publish_flag",st.recovery_publish_flag);

      j.BeginObjectNamed("universe");
      j.NameInt("broker_universe",st.universe.broker_universe);
      j.NameInt("eligible_universe",st.universe.eligible_universe);
      j.NameInt("active_universe",st.universe.active_universe);
      j.NameInt("rankable_universe",st.universe.rankable_universe);
      j.NameString("broker_universe_fingerprint",st.universe.broker_universe_fingerprint);
      j.NameString("eligible_universe_fingerprint",st.universe.eligible_universe_fingerprint);
      j.NameString("active_universe_fingerprint",st.universe.active_universe_fingerprint);
      j.NameString("rankable_universe_fingerprint",st.universe.rankable_universe_fingerprint);
      j.NameString("universe_drift_class",st.universe.universe_drift_class);
      j.EndObject();

      j.BeginObjectNamed("delta");
      j.NameInt("changed_symbol_count",st.delta.changed_symbol_count);
      j.NameString("changed_symbol_ids",st.delta.changed_symbol_ids);
      j.NameInt("changed_family_count",st.delta.changed_family_count);
      j.NameInt("changed_timeframe_count",st.delta.changed_timeframe_count);
      j.NameString("changed_timeframe_ids",st.delta.changed_timeframe_ids);
      j.NameInt("queue_driven_deep_count",st.delta.queue_driven_deep_count);
      j.NameInt("cache_reuse_count",st.delta.cache_reuse_count);
      j.EndObject();

      j.BeginObjectNamed("counters");
      j.NameInt("symbols_total",st.counters.symbols_total);
      j.NameInt("symbols_minimal_ready",st.counters.symbols_minimal_ready);
      j.NameInt("symbols_ranking_ready",st.counters.symbols_ranking_ready);
      j.NameInt("symbols_intelligence_ready",st.counters.symbols_intelligence_ready);
      j.NameInt("symbols_degraded",st.counters.symbols_degraded);
      j.NameInt("timeframes_cold",st.counters.timeframes_cold);
      j.NameInt("timeframes_syncing",st.counters.timeframes_syncing);
      j.NameInt("timeframes_ranking_ready",st.counters.timeframes_ranking_ready);
      j.NameInt("timeframes_intelligence_ready",st.counters.timeframes_intelligence_ready);
      j.NameInt("repairs_active",st.counters.repairs_active);
      j.NameInt("rewrite_watch_count",st.counters.rewrite_watch_count);
      j.NameInt("temporary_rank_suspension_count",st.counters.temporary_rank_suspension_count);
      j.NameInt("contradiction_count",st.counters.contradiction_count);
      j.NameInt("contradiction_blocking_count",st.counters.contradiction_blocking_count);
      j.EndObject();

      j.BeginArrayNamed("symbols");
      for(int i=0;i<ArraySize(st.symbols);i++)
         j.ValueString(BuildSymbolJson(st.symbols[i]));
      j.EndArray();

      j.EndObject();
      return j.ToString();
     }

   static bool RebuildStateFromSymbolList(ISSX_EA2_State &st,
                                          const string &symbols[],
                                          const bool deep_profile_default)
     {
      st.Reset();
      int n=ArraySize(symbols);
      if(n<=0)
         return false;

      ArrayResize(st.symbols,n);
      for(int i=0;i<n;i++)
        {
         PrepareEmptySymbol(st.symbols[i],symbols[i]);

         double point=0.0, bid=0.0, ask=0.0;
         if(!SymbolInfoDouble(symbols[i],SYMBOL_POINT,point)) point=_Point;
         SymbolInfoDouble(symbols[i],SYMBOL_BID,bid);
         SymbolInfoDouble(symbols[i],SYMBOL_ASK,ask);
         double spread_points=((point>0.0 && ask>bid) ? (ask-bid)/point : 0.0);

         for(int t=0;t<issx_ea2_tf_count;t++)
            HydrateSymbolTimeframe(st.symbols[i],t,point,deep_profile_default);

         FinalizeSymbol(st.symbols[i],point,spread_points,deep_profile_default);
        }

      UpdateCounters(st);
      st.delta.changed_symbol_count=n;
      st.delta.changed_timeframe_count=n*issx_ea2_tf_count;
      st.symbol_count=n;
      st.upstream_compatibility_class=issx_ea2_compatibility_compatible;
      st.upstream_source_used="ea1_root_or_internal";
      st.upstream_source_reason="delta_first_rebuild";
      st.upstream_compatibility_score=0.85;
      return true;
     }

   static bool StageBoot(ISSX_EA2_State &st,
                         const string &symbols[],
                         const bool deep_profile_default)
     {
      bool ok=RebuildStateFromSymbolList(st,symbols,deep_profile_default);
      st.stage_minimum_ready_flag=(st.symbol_count>0);
      st.stage_publishability_state=(st.stage_minimum_ready_flag ? "minimum_ready" : "blocked");
      st.dependency_block_reason=(st.stage_minimum_ready_flag ? "" : "ea1_symbols_unavailable");
      st.debug_weak_link_code=(st.stage_minimum_ready_flag ? "" : "ea2_boot_empty");
      return ok;
     }

   static bool StageSlice(ISSX_EA2_State &st,
                          const string &symbols[],
                          const bool deep_profile_default,
                          const int max_symbols_per_slice)
     {
      int n=MathMin(ArraySize(symbols),MathMax(1,max_symbols_per_slice));
      string slice_symbols[];
      ArrayResize(slice_symbols,n);
      for(int i=0;i<n;i++)
         slice_symbols[i]=symbols[i];

      bool ok=RebuildStateFromSymbolList(st,slice_symbols,deep_profile_default);
      st.stage_minimum_ready_flag=(st.symbol_count>0);
      st.stage_publishability_state=(st.stage_minimum_ready_flag ? (st.degraded_flag ? "degraded_publishable" : "publishable") : "blocked");
      st.dependency_block_reason=(st.stage_minimum_ready_flag ? "" : "history_not_ready");
      st.debug_weak_link_code=(st.degraded_flag ? "ea2_degraded_history" : "");
      return ok;
     }

   static string StagePublish(const ISSX_EA2_State &st)
     {
      return BuildStageRootJson(st);
     }

   static string BuildDebugSnapshot(const ISSX_EA2_State &st)
     {
      ISSX_JsonWriter j;
      j.BeginObject();
      j.KeyValue("stage_id","ea2");
      j.KeyValue("stage_minimum_ready_flag",ISSX_Util::BoolToString(st.stage_minimum_ready_flag),false);
      j.KeyValue("stage_publishability_state",st.stage_publishability_state);
      j.KeyValue("dependency_block_reason",st.dependency_block_reason);
      j.KeyValue("debug_weak_link_code",st.debug_weak_link_code);
      j.KeyValue("symbol_count",IntegerToString(st.symbol_count),false);
      j.KeyValue("changed_symbol_count",IntegerToString(st.delta.changed_symbol_count),false);
      j.KeyValue("changed_timeframe_count",IntegerToString(st.delta.changed_timeframe_count),false);
      j.KeyValue("history_store_path",ISSX_Path::StageFolder("ea2")+"history_store/");
      j.KeyValue("history_index_path",ISSX_Path::StageFolder("ea2")+"history_index/");
      j.KeyValue("warehouse_policy","rolling_sharded_bounded");
      j.EndObject();
      return j.ToString();
     }

  };

#endif // __ISSX_HISTORY_ENGINE_MQH__
