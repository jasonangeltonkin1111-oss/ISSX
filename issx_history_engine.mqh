#ifndef __ISSX_HISTORY_ENGINE_MQH__
#define __ISSX_HISTORY_ENGINE_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>

// ============================================================================
// ISSX HISTORY ENGINE v1.732
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
// - stage-owned warehouse shard payload assembly
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
// - unknown / degraded states stay explicit
// - stage-local publishability remains honest
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
   int                           bars_count;
   int                           effective_usable_bars;
   double                        sync_truth_score;
   double                        integrity_truth_score;
   double                        metric_truth_score;
   double                        alignment_truth_score;
   double                        time_alignment_score;
   double                        overlap_quality_score;
   double                        last_bar_finality_score;
   double                        partial_bar_contamination_score;
   double                        sample_depth_score;
   double                        sample_diversity_score;
   double                        metric_stability_score;
   ISSX_MetricSourceMode         metric_source_mode;
   string                        metric_build_state;
   string                        metric_rebuild_reason;
   datetime                      last_complete_bar_time;
   bool                          bar_time_monotonic_ok;
   double                        gap_density;
   double                        history_structure_score;
   double                        metric_input_sufficiency_score;
   bool                          metric_safe_for_cross_symbol_compare;
   ISSX_MetricCompareClass       metric_compare_class;
   bool                          usable_for_20m_to_90m;
   bool                          usable_for_90m_to_4h;
   bool                          usable_for_4h_to_8h;
   double                        window_use_confidence;
   int                           last_bar_rewrite_count_recent;
   double                        bar_hash_drift_score;
   double                        close_mutation_risk;
   ISSX_EA2_HistoryFinalityClass history_finality_class;
   int                           post_repair_stability_cycles;
   ISSX_MetricCompareClass       compare_class_cap_while_recovering;
   bool                          finality_recovery_gate;
   ISSX_EA2_TimeframeMode        mode;
   ISSX_EA2_HistoryReadinessState readiness_state;
   ISSX_EA2_RewriteClass         rewrite_class;
   ISSX_EA2_WarehouseQuality     warehouse_quality;
   int                           warehouse_retained_bar_count;
   int                           effective_lookback_bars;
   bool                          warehouse_clip_flag;
   bool                          warmup_sufficient_flag;
   datetime                      last_sync_time;
   datetime                      last_closed_bar_open_time;
   int                           recent_rewrite_span_bars;
   int                           gap_count;
   string                        finality_state;
   ulong                         continuity_hash;
   ulong                         trailing_finality_hash;
   int                           changed_flag_epoch;
   string                        hydration_reason;
   string                        tf_name;
   ENUM_TIMEFRAMES               timeframe;

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
      metric_rebuild_reason="na";
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
      bar_hash_drift_score=1.0;
      close_mutation_risk=1.0;
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
      hydration_reason="na";
      tf_name="na";
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
   string                      warm_or_deep_profile;
   string                      timeframes_used_for_active_metrics;
   datetime                    oldest_bar_used;
   datetime                    newest_bar_used;
   int                         effective_sample_count;
   string                      metric_degradation_reason;
   double                      recent_repair_activity_score;
   double                      history_flap_risk;
   double                      session_alignment_score;
   double                      active_session_bar_ratio;
   double                      dead_session_bar_ratio;
   double                      history_relevance_score;
   int                         flap_count_recent;
   double                      flap_severity_score;
   bool                        temporary_rank_suspension;
   int                         recovery_stability_cycles_required;
   int                         history_bloat_prevented_count;
   ISSX_EA2_ContinuityOrigin   continuity_origin;
   bool                        resumed_from_persistence;
   ISSX_EA2_CompatibilityClass source_compatibility_class;
   string                      history_store_path;
   string                      history_index_path;
   bool                        live_bar_tracked_separately;
   bool                        dirty_shard_flush_preferred;

   void Reset()
     {
      warm_or_deep_profile="cold";
      timeframes_used_for_active_metrics="na";
      oldest_bar_used=0;
      newest_bar_used=0;
      effective_sample_count=0;
      metric_degradation_reason="na";
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
      history_store_path="na";
      history_index_path="na";
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
      contradiction_flags="none";
      dominant_degradation_reason="na";
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

struct ISSX_EA2_UniverseState
  {
   int    broker_universe;
   int    eligible_universe;
   int    active_universe;
   int    rankable_universe;
   string broker_universe_fingerprint;
   string eligible_universe_fingerprint;
   string active_universe_fingerprint;
   string rankable_universe_fingerprint;
   string universe_drift_class;

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

struct ISSX_EA2_CoverageState
  {
   double percent_universe_touched_recent;
   double percent_rankable_revalidated_recent;
   double percent_frontier_revalidated_recent;
   double coverage_rankable_recent_pct;
   double coverage_frontier_recent_pct;
   double history_deep_completion_pct;
   int    never_serviced_count;
   int    overdue_service_count;
   int    newly_active_symbols_waiting_count;
   int    never_ranked_but_eligible_count;
   int    winner_cache_dependence_pct;

   void Reset()
     {
      percent_universe_touched_recent=0.0;
      percent_rankable_revalidated_recent=0.0;
      percent_frontier_revalidated_recent=0.0;
      coverage_rankable_recent_pct=0.0;
      coverage_frontier_recent_pct=0.0;
      history_deep_completion_pct=0.0;
      never_serviced_count=0;
      overdue_service_count=0;
      newly_active_symbols_waiting_count=0;
      never_ranked_but_eligible_count=0;
      winner_cache_dependence_pct=0;
     }
  };

struct ISSX_EA2_ForensicDiag
  {
   int    discovery_attempts;
   int    discovery_successes;
   int    symbol_started;
   int    symbol_completed;
   int    copyrates_attempts;
   int    copyrates_successes;
   int    copyrates_failures;
   int    batch_symbols_target;
   int    batch_symbols_done;
   int    persistence_write_attempts;
   int    persistence_write_successes;
   int    persistence_write_failures;
   int    persistence_index_attempts;
   int    persistence_index_successes;
   int    persistence_index_failures;
   int    max_rates_request;
   int    max_rates_returned;
   int    max_completed_retained;
   string last_error_code;
   string event_log_csv;

   void Reset()
     {
      discovery_attempts=0;
      discovery_successes=0;
      symbol_started=0;
      symbol_completed=0;
      copyrates_attempts=0;
      copyrates_successes=0;
      copyrates_failures=0;
      batch_symbols_target=0;
      batch_symbols_done=0;
      persistence_write_attempts=0;
      persistence_write_successes=0;
      persistence_write_failures=0;
      persistence_index_attempts=0;
      persistence_index_successes=0;
      persistence_index_failures=0;
      max_rates_request=0;
      max_rates_returned=0;
      max_completed_retained=0;
      last_error_code="none";
      event_log_csv="";
     }
  };

struct ISSX_EA2_State
  {
   ISSX_StageHeader            header;
   ISSX_Manifest               manifest;
   ISSX_RuntimeState           runtime;
   ISSX_EA2_UniverseState      universe;
   ISSX_EA2_DeltaState         delta;
   ISSX_EA2_CycleCounters      counters;
   ISSX_EA2_CoverageState      coverage;
   ISSX_EA2_CompatibilityClass upstream_compatibility_class;
   string                      upstream_source_used;
   string                      upstream_source_reason;
   int                         fallback_depth_used;
   double                      upstream_compatibility_score;
   double                      fallback_penalty_applied;
   bool                        projection_partial_success_flag;
   bool                        degraded_flag;
   bool                        recovery_publish_flag;
   bool                        stage_minimum_ready_flag;
   string                      stage_publishability_state;
   string                      dependency_block_reason;
   string                      debug_weak_link_code;
   int                         symbol_count;
   int                         stream_source_total;
   int                         stream_cursor;
   int                         stream_window_start;
   int                         stream_window_end;
   int                         stream_window_size;
   int                         stream_processed_total;
   int                         stream_cycles;
   bool                        stream_cycle_advanced;
   ISSX_EA2_SymbolState        symbols[];
   ISSX_EA2_ForensicDiag       forensic;

   void Reset()
     {
      header.Reset();
      manifest.Reset();
      runtime.Reset();
      universe.Reset();
      delta.Reset();
      counters.Reset();
      coverage.Reset();
      upstream_compatibility_class=issx_ea2_compatibility_incompatible;
      upstream_source_used="na";
      upstream_source_reason="na";
      fallback_depth_used=0;
      upstream_compatibility_score=0.0;
      fallback_penalty_applied=0.0;
      projection_partial_success_flag=false;
      degraded_flag=false;
      recovery_publish_flag=false;
      stage_minimum_ready_flag=false;
      stage_publishability_state="blocked";
      dependency_block_reason="na";
      debug_weak_link_code="none";
      symbol_count=0;
      stream_source_total=0;
      stream_cursor=0;
      stream_window_start=0;
      stream_window_end=0;
      stream_window_size=0;
      stream_processed_total=0;
      stream_cycles=0;
      stream_cycle_advanced=false;
      ArrayResize(symbols,0);
      forensic.Reset();
     }
  };

// ============================================================================
// SECTION 03: HELPERS
// ============================================================================

class ISSX_HistoryEngine
  {
private:
   static string NormalizeSymbolUpper(const string s)
     {
      string out=s;
      StringToUpper(out);
      return out;
     }

   static string TfNameByIndex(const int idx)
     {
      switch(idx)
        {
         case issx_ea2_tf_m5:  return "M5";
         case issx_ea2_tf_m15: return "M15";
         case issx_ea2_tf_h1:  return "H1";
         default:              return "NA";
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

   static int WarehouseRetentionCapByIndex(const int idx)
     {
      switch(idx)
        {
         case issx_ea2_tf_m5:  return 750;
         case issx_ea2_tf_m15: return 750;
         case issx_ea2_tf_h1:  return 750;
         default:              return 0;
        }
     }

   static int RequestedCompletedBarsByProfile(const int tf_index,const bool deep_profile)
     {
      const int warm=(tf_index==issx_ea2_tf_h1 ? 96 : 120);
      const int deep=(tf_index==issx_ea2_tf_h1 ? 256 : 320);
      return (deep_profile ? deep : warm);
     }

   static int SafePeriodSeconds(const ENUM_TIMEFRAMES tf)
     {
      const int sec=PeriodSeconds(tf);
      if(sec>0)
         return sec;

      switch(tf)
        {
         case PERIOD_M5:  return 300;
         case PERIOD_M15: return 900;
         case PERIOD_H1:  return 3600;
         default:         return 60;
        }
     }

   static string StagePersistencePath()
     {
      return "persistence/ea2/";
     }

   static string StageHistoryStorePath()
     {
      return "persistence/ea2/history_store/";
     }

   static string StageHistoryIndexPath()
     {
      return "persistence/ea2/history_index/";
     }

   static string StageIdString()
     {
      return "ea2";
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
         default:                           return "unstable";
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
         case issx_ea2_compatibility_exact:               return "exact";
         case issx_ea2_compatibility_compatible:          return "compatible";
         case issx_ea2_compatibility_compatible_degraded: return "compatible_degraded";
         case issx_ea2_compatibility_incompatible:        return "incompatible";
         default:                                         return "incompatible";
        }
     }

   static string AcceptanceTypeToStringLocal(const ISSX_AcceptanceType v)
     {
      switch(v)
        {
         case issx_acceptance_accepted_for_pipeline:     return "accepted_for_pipeline";
         case issx_acceptance_accepted_for_ranking:      return "accepted_for_ranking";
         case issx_acceptance_accepted_for_intelligence: return "accepted_for_intelligence";
         case issx_acceptance_accepted_for_gpt_export:   return "accepted_for_gpt_export";
         case issx_acceptance_accepted_degraded:         return "accepted_degraded";
         case issx_acceptance_rejected:                  return "rejected";
         default:                                        return "rejected";
        }
     }

   static string WarehouseQualityToStringLocal(const ISSX_EA2_WarehouseQuality v)
     {
      switch(v)
        {
         case issx_ea2_warehouse_quality_unknown:               return "unknown";
         case issx_ea2_warehouse_quality_cold:                  return "cold";
         case issx_ea2_warehouse_quality_partial:               return "partial";
         case issx_ea2_warehouse_quality_compare_safe_degraded: return "compare_safe_degraded";
         case issx_ea2_warehouse_quality_compare_safe_strong:   return "compare_safe_strong";
         default:                                               return "unknown";
        }
     }

   static string ReadinessStateToStringLocal(const ISSX_EA2_HistoryReadinessState v)
     {
      switch(v)
        {
         case issx_ea2_history_never_requested:       return "never_requested";
         case issx_ea2_history_requested_sync:        return "requested_sync";
         case issx_ea2_history_partial_available:     return "partial_available";
         case issx_ea2_history_syncing:               return "syncing";
         case issx_ea2_history_compare_unsafe:        return "compare_unsafe";
         case issx_ea2_history_compare_safe_degraded: return "compare_safe_degraded";
         case issx_ea2_history_compare_safe_strong:   return "compare_safe_strong";
         case issx_ea2_history_degraded_unstable:     return "degraded_unstable";
         case issx_ea2_history_blocked:               return "blocked";
         default:                                     return "never_requested";
        }
     }

   static string RewriteClassToStringLocal(const ISSX_EA2_RewriteClass v)
     {
      switch(v)
        {
         case issx_ea2_rewrite_none:                       return "none";
         case issx_ea2_rewrite_benign_last_bar_adjustment: return "benign_last_bar_adjustment";
         case issx_ea2_rewrite_short_tail_rewrite:         return "short_tail_rewrite";
         case issx_ea2_rewrite_structural_gap_rewrite:     return "structural_gap_rewrite";
         case issx_ea2_rewrite_historical_block_rewrite:   return "historical_block_rewrite";
         default:                                          return "none";
        }
     }

   static string ContinuityOriginToStringLocal(const ISSX_EA2_ContinuityOrigin v)
     {
      switch(v)
        {
         case issx_ea2_continuity_fresh_boot:        return "fresh_boot";
         case issx_ea2_continuity_resumed_current:   return "resumed_current";
         case issx_ea2_continuity_resumed_previous:  return "resumed_previous";
         case issx_ea2_continuity_resumed_last_good: return "resumed_last_good";
         case issx_ea2_continuity_rebuilt_clean:     return "rebuilt_clean";
         default:                                    return "fresh_boot";
        }
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

   static string ContradictionSeverityToString(const ISSX_EA2_ContradictionSeverity v)
     {
      switch(v)
        {
         case issx_ea2_contradiction_low:       return "low";
         case issx_ea2_contradiction_moderate:  return "moderate";
         case issx_ea2_contradiction_high:      return "high";
         case issx_ea2_contradiction_blocking:  return "blocking";
         default:                               return "low";
        }
     }

   static double Clamp01(const double v)
     {
      if(v<0.0)
         return 0.0;
      if(v>1.0)
         return 1.0;
      return v;
     }

   static void AppendCsvToken(string &dst,const string token)
     {
      if(ISSX_Util::IsEmpty(token))
         return;
      if(!ISSX_Util::IsEmpty(dst))
         dst += ",";
      dst += token;
     }

   static void AddForensicEvent(ISSX_EA2_State &st,const string event_name,const string detail="")
     {
      string packet=event_name;
      if(!ISSX_Util::IsEmpty(detail))
         packet += "("+detail+")";

      const int max_chars=2200;
      if(StringLen(st.forensic.event_log_csv)>=max_chars)
        {
         st.forensic.event_log_csv=StringSubstr(st.forensic.event_log_csv,StringLen(st.forensic.event_log_csv)-max_chars/2);
         if(!ISSX_Util::IsEmpty(st.forensic.event_log_csv))
            st.forensic.event_log_csv="...,"+st.forensic.event_log_csv;
        }
      AppendCsvToken(st.forensic.event_log_csv,packet);
     }

   static ulong HashMix(const ulong h,const ulong v)
     {
      return ((h ^ v) * 1099511628211ULL);
     }

   static ulong StableHashStringLocal(const string text)
     {
      const int n=StringLen(text);
      ulong h=1469598103934665603ULL;
      for(int i=0;i<n;i++)
        {
         const uint ch=(uint)StringGetCharacter(text,i);
         h=HashMix(h,(ulong)ch);
        }
      return h;
     }

   static ulong StableHashRatesWindow(const MqlRates &rates[],const int max_bars)
     {
      ulong h=1469598103934665603ULL;
      const int n=(int)ArraySize(rates);
      const int use=MathMin(n,max_bars);

      for(int i=0;i<use;i++)
        {
         h=HashMix(h,(ulong)rates[i].time);
         h=HashMix(h,(ulong)MathRound(rates[i].open*100000.0));
         h=HashMix(h,(ulong)MathRound(rates[i].high*100000.0));
         h=HashMix(h,(ulong)MathRound(rates[i].low*100000.0));
         h=HashMix(h,(ulong)MathRound(rates[i].close*100000.0));
         h=HashMix(h,(ulong)rates[i].tick_volume);
         h=HashMix(h,(ulong)rates[i].spread);
         h=HashMix(h,(ulong)rates[i].real_volume);
        }

      return h;
     }

   static string StableHashStringId(const string text)
     {
      const ulong positive_mask=(ulong)9223372036854775807;
      return IntegerToString((long)(StableHashStringLocal(text) & positive_mask));
     }

   static string BuildUniverseFingerprint(const ISSX_EA2_SymbolState &symbols[],
                                          const string scope_name,
                                          const bool only_touched=false,
                                          const bool only_rankable=false)
     {
      string ordered[];
      ArrayResize(ordered,0);

      const int n=(int)ArraySize(symbols);
      for(int i=0;i<n;i++)
        {
         const bool touched=(symbols[i].last_history_touch>0);
         const bool rankable=symbols[i].history_ready_for_ranking;

         if(only_touched && !touched)
            continue;
         if(only_rankable && !rankable)
            continue;

         const int k=ArraySize(ordered);
         ArrayResize(ordered,k+1);
         ordered[k]=symbols[i].symbol_norm;
        }

      ArraySort(ordered);

      string flat=scope_name + "|";
      for(int i=0;i<ArraySize(ordered);i++)
        {
         if(i>0)
            flat += "|";
         flat += ordered[i];
        }

      return StableHashStringId(flat);
     }

   static bool CopyCompletedRatesSafe(const string symbol,
                                      const ENUM_TIMEFRAMES tf,
                                      const int requested_completed_count,
                                      MqlRates &completed_rates[],
                                      bool &live_bar_present,
                                      int &raw_copied,
                                      int &last_error_code,
                                      int &requested_raw)
     {
      live_bar_present=false;
      ArrayResize(completed_rates,0);
      ArraySetAsSeries(completed_rates,true);

      const int want=MathMax(2,requested_completed_count+1);
      raw_copied=0;
      last_error_code=0;
      requested_raw=want;

      MqlRates raw_rates[];
      ArraySetAsSeries(raw_rates,true);

      ResetLastError();
      const int copied=CopyRates(symbol,tf,0,want,raw_rates);
      raw_copied=copied;
      last_error_code=GetLastError();
      if(copied<=1)
         return false;

      live_bar_present=true;

      const int completed_count=copied-1;
      ArrayResize(completed_rates,completed_count);

      for(int i=0;i<completed_count;i++)
         completed_rates[i]=raw_rates[i+1];

      ArraySetAsSeries(completed_rates,true);
      return (ArraySize(completed_rates)>0);
     }

   static bool TimeSeriesMonotonic(const MqlRates &rates[])
     {
      const int n=(int)ArraySize(rates);
      if(n<=1)
         return true;

      for(int i=0;i<n-1;i++)
        {
         if(rates[i].time<=rates[i+1].time)
            return false;
        }
      return true;
     }

   static int CountGaps(const MqlRates &rates[],const int seconds_per_bar)
     {
      const int n=(int)ArraySize(rates);
      if(n<=1 || seconds_per_bar<=0)
         return 0;

      int gaps=0;
      for(int i=0;i<n-1;i++)
        {
         const long dt=(long)(rates[i].time-rates[i+1].time);
         if(dt>(long)(seconds_per_bar*2))
            gaps++;
        }
      return gaps;
     }

   static double ApproxAtrPoints(const MqlRates &rates[],const double point,const int lookback)
     {
      const int n=(int)ArraySize(rates);
      if(n<=1 || point<=0.0)
         return 0.0;

      const int use=MathMin(n-1,lookback);
      if(use<=0)
         return 0.0;

      double sum=0.0;
      int cnt=0;
      for(int i=0;i<use;i++)
        {
         const double prev_close=rates[i+1].close;
         const double tr=MathMax(rates[i].high-rates[i].low,
                                 MathMax(MathAbs(rates[i].high-prev_close),MathAbs(rates[i].low-prev_close)));
         sum += tr/point;
         cnt++;
        }

      return (cnt>0 ? sum/(double)cnt : 0.0);
     }

   static double ReturnVolRatio(const MqlRates &rates[])
     {
      const int n=(int)ArraySize(rates);
      if(n<=8)
         return 0.0;

      double abs_sum=0.0;
      double net=0.0;
      int cnt=0;

      for(int i=0;i<n-1 && i<48;i++)
        {
         const double r=(rates[i].close-rates[i+1].close);
         abs_sum += MathAbs(r);
         net += r;
         cnt++;
        }

      if(cnt<=0 || abs_sum<=0.0)
         return 0.0;

      return Clamp01(MathAbs(net)/abs_sum);
     }

   static double BodyWickRatioMedian(const MqlRates &rates[],const double point)
     {
      const int n=(int)ArraySize(rates);
      if(n<=0)
         return 0.0;

      const int use=MathMin(n,24);
      double vals[];
      ArrayResize(vals,use);

      const double min_range=MathMax(point,0.00000001);

      for(int i=0;i<use;i++)
        {
         const double body=MathAbs(rates[i].close-rates[i].open);
         const double full=MathMax(rates[i].high-rates[i].low,min_range);
         vals[i]=body/full;
        }

      ArraySort(vals);
      if((use%2)==1)
         return vals[use/2];

      return 0.5*(vals[use/2-1]+vals[use/2]);
     }

   static double CloseLocationPercentileRecent(const MqlRates &rates[])
     {
      const int n=(int)ArraySize(rates);
      if(n<=0)
         return 0.0;

      const int use=MathMin(n,24);
      double sum=0.0;
      int cnt=0;

      for(int i=0;i<use;i++)
        {
         const double full=rates[i].high-rates[i].low;
         if(full<=0.0)
            continue;

         sum += (rates[i].close-rates[i].low)/full;
         cnt++;
        }

      return (cnt>0 ? Clamp01(sum/(double)cnt) : 0.0);
     }

   static int InsideOutsideCountRecent(const MqlRates &rates[])
     {
      const int n=(int)ArraySize(rates);
      if(n<=1)
         return 0;

      const int use=MathMin(n-1,24);
      int cnt=0;

      for(int i=0;i<use;i++)
        {
         const bool inside=(rates[i].high<=rates[i+1].high && rates[i].low>=rates[i+1].low);
         const bool outside=(rates[i].high>=rates[i+1].high && rates[i].low<=rates[i+1].low);
         if(inside || outside)
            cnt++;
        }

      return cnt;
     }

   static double OverlapPercentileRecent(const MqlRates &rates[],const double point)
     {
      const int n=(int)ArraySize(rates);
      if(n<=1)
         return 0.0;

      const int use=MathMin(n-1,24);
      double sum=0.0;
      int cnt=0;
      const double min_range=MathMax(point,0.00000001);

      for(int i=0;i<use;i++)
        {
         const double hi=MathMin(rates[i].high,rates[i+1].high);
         const double lo=MathMax(rates[i].low,rates[i+1].low);
         const double overlap=MathMax(0.0,hi-lo);
         const double full=MathMax(rates[i+1].high-rates[i+1].low,min_range);
         sum += overlap/full;
         cnt++;
        }

      return (cnt>0 ? Clamp01(sum/(double)cnt) : 0.0);
     }

   static ISSX_EA2_RewriteClass ClassifyRewriteClass(const ISSX_EA2_TimeframeBlock &tfb)
     {
      if(tfb.bars_count<=0)
         return issx_ea2_rewrite_historical_block_rewrite;
      if(tfb.gap_density>=0.35 || tfb.gap_count>=8)
         return issx_ea2_rewrite_historical_block_rewrite;
      if(tfb.gap_density>=0.15 || tfb.gap_count>=3)
         return issx_ea2_rewrite_structural_gap_rewrite;
      if(tfb.close_mutation_risk>=0.40 || tfb.last_bar_rewrite_count_recent>=2)
         return issx_ea2_rewrite_short_tail_rewrite;
      if(tfb.close_mutation_risk>=0.15)
         return issx_ea2_rewrite_benign_last_bar_adjustment;
      return issx_ea2_rewrite_none;
     }

   static ISSX_EA2_WarehouseQuality ClassifyWarehouseQuality(const ISSX_EA2_TimeframeBlock &tfb)
     {
      if(tfb.bars_count<=0)
         return issx_ea2_warehouse_quality_cold;
      if(tfb.metric_compare_class>=issx_metric_compare_frontier_safe && tfb.finality_recovery_gate)
         return issx_ea2_warehouse_quality_compare_safe_strong;
      if(tfb.metric_compare_class>=issx_metric_compare_bucket_safe)
         return issx_ea2_warehouse_quality_compare_safe_degraded;
      return issx_ea2_warehouse_quality_partial;
     }

   static ISSX_EA2_HistoryReadinessState ClassifyReadinessState(const ISSX_EA2_TimeframeBlock &tfb)
     {
      if(tfb.bars_count<=0)
         return issx_ea2_history_syncing;
      if(tfb.history_finality_class==issx_ea2_finality_unstable && tfb.metric_truth_score<0.30)
         return issx_ea2_history_degraded_unstable;
      if(tfb.mode==issx_ea2_tfmode_intelligence_ready)
         return issx_ea2_history_compare_safe_strong;
      if(tfb.mode==issx_ea2_tfmode_ranking_ready)
         return issx_ea2_history_compare_safe_degraded;
      if(tfb.mode==issx_ea2_tfmode_minimal_ready)
         return issx_ea2_history_partial_available;
      if(tfb.mode==issx_ea2_tfmode_syncing)
         return issx_ea2_history_syncing;
      return issx_ea2_history_compare_unsafe;
     }

   static string BuildHistoryShardPayload(const string symbol,
                                          const ISSX_EA2_TimeframeBlock &tf_block,
                                          const MqlRates &completed_rates[],
                                          const bool live_bar_tracked_separately)
     {
      ISSX_JsonWriter j;
      j.Reset();
      j.BeginObject();

      j.NameString("symbol",symbol);
      j.NameString("timeframe",tf_block.tf_name);
      j.NameInt("storage_version",ISSX_STORAGE_VERSION);
      j.NameBool("live_bar_tracked_separately",live_bar_tracked_separately);
      j.NameInt("oldest_bar_time",(ArraySize(completed_rates)>0 ? (long)completed_rates[ArraySize(completed_rates)-1].time : 0L));
      j.NameInt("newest_bar_time",(ArraySize(completed_rates)>0 ? (long)completed_rates[0].time : 0L));
      j.NameInt("retained_bar_count",tf_block.warehouse_retained_bar_count);
      j.NameInt("last_sync_time",(long)tf_block.last_sync_time);
      j.NameInt("last_complete_bar_time",(long)tf_block.last_complete_bar_time);
      j.NameInt("last_closed_bar_open_time",(long)tf_block.last_closed_bar_open_time);
      j.NameInt("rewrite_count_recent",tf_block.last_bar_rewrite_count_recent);
      j.NameInt("recent_rewrite_span_bars",tf_block.recent_rewrite_span_bars);
      j.NameInt("gap_count",tf_block.gap_count);
      j.NameString("finality_state",tf_block.finality_state);
      j.NameInt("continuity_hash",(long)tf_block.continuity_hash);
      j.NameInt("trailing_finality_hash",(long)tf_block.trailing_finality_hash);
      j.NameString("warehouse_quality",WarehouseQualityToStringLocal(tf_block.warehouse_quality));
      j.NameBool("warehouse_clip_flag",tf_block.warehouse_clip_flag);
      j.NameBool("warmup_sufficient_flag",tf_block.warmup_sufficient_flag);
      j.NameInt("effective_lookback_bars",tf_block.effective_lookback_bars);

      j.BeginArrayNamed("bars");
      for(int i=ArraySize(completed_rates)-1;i>=0;i--)
        {
         j.BeginObject();
         j.NameInt("t",(long)completed_rates[i].time);
         j.NameDouble("o",completed_rates[i].open,8);
         j.NameDouble("h",completed_rates[i].high,8);
         j.NameDouble("l",completed_rates[i].low,8);
         j.NameDouble("c",completed_rates[i].close,8);
         j.NameInt("tick_volume",(long)completed_rates[i].tick_volume);
         j.NameInt("spread",(long)completed_rates[i].spread);
         j.NameInt("real_volume",(long)completed_rates[i].real_volume);
         j.NameInt("flags",0);
         j.EndObject();
        }
      j.EndArray();

      j.EndObject();
      return j.ToString();
     }

   static bool WriteWarehouseShard(ISSX_EA2_State &st,
                                   const string firm_id,
                                   const ISSX_EA2_SymbolState &symbol_state,
                                   const int tf_index)
     {
      if(ISSX_Util::IsEmpty(firm_id))
         return false;
      if(tf_index<0 || tf_index>=issx_ea2_tf_count)
         return false;
      if(ISSX_Util::IsEmpty(symbol_state.symbol_raw))
         return false;

      MqlRates completed_rates[];
      bool live_bar_present=false;
      int raw_copied=0;
      int last_error_code=0;
      int requested_raw=0;
      const int retention=WarehouseRetentionCapByIndex(tf_index);
      st.forensic.persistence_write_attempts++;
      AddForensicEvent(st,"history_persistence_write_attempt",
                       symbol_state.symbol_norm+":"+TfNameByIndex(tf_index)+" retention="+IntegerToString(retention));

      if(!CopyCompletedRatesSafe(symbol_state.symbol_raw,TfValueByIndex(tf_index),retention,completed_rates,live_bar_present,raw_copied,last_error_code,requested_raw))
        {
         st.forensic.persistence_write_failures++;
         st.forensic.last_error_code=ISSX_ErrorToString(ISSX_ERR_COPYRATES)+"_"+IntegerToString(last_error_code);
         AddForensicEvent(st,"history_error_conditions",
                          "persist_copyrates_fail symbol="+symbol_state.symbol_norm+" tf="+TfNameByIndex(tf_index)+" err="+IntegerToString(last_error_code));
         return false;
        }

      st.forensic.max_rates_request=MathMax(st.forensic.max_rates_request,requested_raw);
      st.forensic.max_rates_returned=MathMax(st.forensic.max_rates_returned,raw_copied);
      st.forensic.max_completed_retained=MathMax(st.forensic.max_completed_retained,ArraySize(completed_rates));

      const string shard_payload=BuildHistoryShardPayload(symbol_state.symbol_raw,
                                                          symbol_state.tf[tf_index],
                                                          completed_rates,
                                                          live_bar_present);

      const bool ok=ISSX_HistoryWarehouse::WriteShard(firm_id,
                                                      TfNameByIndex(tf_index),
                                                      symbol_state.symbol_norm,
                                                      shard_payload);
      if(ok)
        {
         st.forensic.persistence_write_successes++;
         AddForensicEvent(st,"history_persistence_write_result",
                          "ok symbol="+symbol_state.symbol_norm+" tf="+TfNameByIndex(tf_index)+" retained="+IntegerToString(ArraySize(completed_rates)));
        }
      else
        {
         st.forensic.persistence_write_failures++;
         st.forensic.last_error_code=ISSX_ErrorToString(ISSX_ERR_FILE_WRITE);
         AddForensicEvent(st,"history_error_conditions",
                          "persist_write_fail symbol="+symbol_state.symbol_norm+" tf="+TfNameByIndex(tf_index));
        }
      return ok;
     }

   static bool TouchWarehouseIndexes(const string firm_id,
                                     ISSX_EA2_State &st)
     {
      if(ISSX_Util::IsEmpty(firm_id))
         return false;

      st.forensic.persistence_index_attempts++;
      AddForensicEvent(st,"history_persistence_index_attempt",
                       "symbols="+IntegerToString(st.symbol_count));

      ISSX_JsonWriter symbol_registry;
      symbol_registry.Reset();
      symbol_registry.BeginObject();
      symbol_registry.BeginArrayNamed("symbols");
      for(int i=0;i<ArraySize(st.symbols);i++)
         symbol_registry.ValueString(st.symbols[i].symbol_norm);
      symbol_registry.EndArray();
      symbol_registry.NameInt("symbol_count",st.symbol_count);
      symbol_registry.NameString("active_universe_fingerprint",st.universe.active_universe_fingerprint);
      symbol_registry.EndObject();

      ISSX_JsonWriter timeframe_index;
      timeframe_index.Reset();
      timeframe_index.BeginObject();
      timeframe_index.BeginArrayNamed("timeframes");
      timeframe_index.ValueString("M5");
      timeframe_index.ValueString("M15");
      timeframe_index.ValueString("H1");
      timeframe_index.EndArray();
      timeframe_index.NameInt("timeframe_count",issx_ea2_tf_count);
      timeframe_index.EndObject();

      ISSX_JsonWriter hydration_cursor;
      hydration_cursor.Reset();
      hydration_cursor.BeginObject();
      hydration_cursor.NameInt("symbol_count",st.symbol_count);
      hydration_cursor.NameInt("changed_symbol_count",st.delta.changed_symbol_count);
      hydration_cursor.NameInt("changed_timeframe_count",st.delta.changed_timeframe_count);
      hydration_cursor.NameInt("minute_id",(long)st.manifest.minute_id);
      hydration_cursor.NameDouble("history_deep_completion_pct",st.coverage.history_deep_completion_pct,4);
      hydration_cursor.EndObject();

      ISSX_JsonWriter dirty_set;
      dirty_set.Reset();
      dirty_set.BeginObject();
      dirty_set.NameString("changed_symbol_ids",st.delta.changed_symbol_ids);
      dirty_set.NameString("changed_timeframe_ids",st.delta.changed_timeframe_ids);
      dirty_set.NameInt("queue_driven_deep_count",st.delta.queue_driven_deep_count);
      dirty_set.NameInt("cache_reuse_count",st.delta.cache_reuse_count);
      dirty_set.EndObject();

      ISSX_JsonWriter manifest_json;
      manifest_json.Reset();
      manifest_json.BeginObject();
      manifest_json.NameString("stage_id",StageIdString());
      manifest_json.NameInt("storage_version",ISSX_STORAGE_VERSION);
      manifest_json.NameInt("symbol_count",st.symbol_count);
      manifest_json.NameInt("changed_symbol_count",st.delta.changed_symbol_count);
      manifest_json.NameInt("changed_timeframe_count",st.delta.changed_timeframe_count);
      manifest_json.NameString("active_universe_fingerprint",st.universe.active_universe_fingerprint);
      manifest_json.NameString("rankable_universe_fingerprint",st.universe.rankable_universe_fingerprint);
      manifest_json.EndObject();

      const bool ok=ISSX_HistoryWarehouse::TouchRegistry(firm_id,
                                                         symbol_registry.ToString(),
                                                         timeframe_index.ToString(),
                                                         hydration_cursor.ToString(),
                                                         dirty_set.ToString(),
                                                         manifest_json.ToString());
      if(ok)
        {
         st.forensic.persistence_index_successes++;
         AddForensicEvent(st,"history_persistence_index_result","ok");
        }
      else
        {
         st.forensic.persistence_index_failures++;
         st.forensic.last_error_code=ISSX_ErrorToString(ISSX_ERR_FILE_WRITE);
         AddForensicEvent(st,"history_error_conditions","persist_index_fail");
        }
      return ok;
     }

   static void ApplyTrustMap(ISSX_EA2_SymbolState &s)
     {
      s.trust_map.Reset();

      for(int i=0;i<issx_ea2_tf_count;i++)
        {
         ISSX_EA2_TimeframeTrust trust;
         trust.Reset();

         trust.continuity=Clamp01((double)s.tf[i].post_repair_stability_cycles/5.0);
         trust.quality_class=(s.tf[i].metric_truth_score>=0.80 ? issx_truth_strong :
                              s.tf[i].metric_truth_score>=0.60 ? issx_truth_acceptable :
                              s.tf[i].metric_truth_score>=0.40 ? issx_truth_degraded :
                                                                 issx_truth_weak);

         const datetime now=TimeCurrent();
         const long age_sec=(s.tf[i].last_complete_bar_time>0 ? (long)(now-s.tf[i].last_complete_bar_time) : 999999L);

         trust.freshness=(age_sec<=1800 ? issx_freshness_fresh :
                          age_sec<=7200 ? issx_freshness_usable :
                          age_sec<=21600 ? issx_freshness_aging :
                                           issx_freshness_stale);

         trust.readiness=s.tf[i].mode;

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

      const double continuity=(s.trust_map.tf_m5_trust.continuity + s.trust_map.tf_m15_trust.continuity + s.trust_map.tf_h1_trust.continuity)/3.0;
      const double staleness=((double)((int)s.trust_map.tf_m5_trust.freshness + (int)s.trust_map.tf_m15_trust.freshness + (int)s.trust_map.tf_h1_trust.freshness))/9.0;
      const double gap_risk=(s.tf[issx_ea2_tf_m5].gap_density + s.tf[issx_ea2_tf_m15].gap_density + s.tf[issx_ea2_tf_h1].gap_density)/3.0;
      const double usable=(s.tf[issx_ea2_tf_m5].window_use_confidence + s.tf[issx_ea2_tf_m15].window_use_confidence + s.tf[issx_ea2_tf_h1].window_use_confidence)/3.0;
      const double metric=(s.tf[issx_ea2_tf_m5].metric_truth_score + s.tf[issx_ea2_tf_m15].metric_truth_score + s.tf[issx_ea2_tf_h1].metric_truth_score)/3.0;

      s.judgment.usable_range_score=Clamp01(usable);
      s.judgment.continuity_score=Clamp01(continuity);
      s.judgment.staleness_score=Clamp01(1.0-staleness);
      s.judgment.gap_risk_score=Clamp01(gap_risk);
      s.judgment.metric_trust_score=Clamp01(metric);

      double q=(0.28*s.judgment.usable_range_score) +
               (0.24*s.judgment.continuity_score) +
               (0.24*s.judgment.metric_trust_score) +
               (0.12*(1.0-s.judgment.gap_risk_score)) +
               (0.12*(1.0-s.judgment.staleness_score));

      if(s.provenance.temporary_rank_suspension)
         q*=0.70;
      if(s.contradiction_present && s.contradiction_severity_max>=issx_ea2_contradiction_high)
         q*=0.75;

      s.judgment.history_data_quality_score=Clamp01(q);

      s.history_ready_for_ranking=
         (s.tf[issx_ea2_tf_m5].metric_compare_class>=issx_metric_compare_bucket_safe ||
          s.tf[issx_ea2_tf_m15].metric_compare_class>=issx_metric_compare_bucket_safe) &&
         (s.judgment.history_data_quality_score>=0.45) &&
         !s.provenance.temporary_rank_suspension &&
         !(s.contradiction_present && s.contradiction_severity_max>=issx_ea2_contradiction_blocking);

      s.history_ready_for_intelligence=
         (s.tf[issx_ea2_tf_m15].metric_compare_class>=issx_metric_compare_frontier_safe) &&
         (s.tf[issx_ea2_tf_h1].metric_compare_class>=issx_metric_compare_frontier_safe) &&
         (s.judgment.history_data_quality_score>=0.62) &&
         (s.provenance.recent_repair_activity_score<0.60) &&
         !(s.contradiction_present && s.contradiction_severity_max>=issx_ea2_contradiction_high);

      s.acceptance_type=
         (s.history_ready_for_intelligence ? issx_acceptance_accepted_for_intelligence :
          s.history_ready_for_ranking ? issx_acceptance_accepted_for_ranking :
          s.judgment.history_data_quality_score>=0.30 ? issx_acceptance_accepted_degraded :
                                                        issx_acceptance_rejected);

      s.truth_class=
         (s.judgment.history_data_quality_score>=0.80 ? issx_truth_strong :
          s.judgment.history_data_quality_score>=0.60 ? issx_truth_acceptable :
          s.judgment.history_data_quality_score>=0.35 ? issx_truth_degraded :
                                                        issx_truth_weak);

      s.freshness_class=
         (s.trust_map.tf_m5_trust.freshness<=issx_freshness_usable &&
          s.trust_map.tf_m15_trust.freshness<=issx_freshness_usable ? issx_freshness_fresh :
          s.trust_map.tf_h1_trust.freshness<=issx_freshness_usable ? issx_freshness_usable :
          s.trust_map.tf_m15_trust.freshness<=issx_freshness_aging ? issx_freshness_aging :
                                                                     issx_freshness_stale);

      s.dominant_degradation_reason="na";
      if(!s.history_ready_for_ranking)
         s.dominant_degradation_reason="comparison_not_safe";
      if(s.provenance.temporary_rank_suspension)
         s.dominant_degradation_reason="repair_stability_window";
      if(s.judgment.history_data_quality_score<0.30)
         s.dominant_degradation_reason="history_quality_too_low";
      if(s.contradiction_present && s.contradiction_severity_max>=issx_ea2_contradiction_high)
         s.dominant_degradation_reason="blocking_contradiction";
     }

   static void UpdateStructuralContext(ISSX_EA2_SymbolState &s)
     {
      const double a=s.hot_metrics.atr_points_m5;
      const double b=s.hot_metrics.atr_points_m15;
      const double eff=s.hot_metrics.spread_to_atr_efficiency;
      const double ov=s.hot_metrics.overlap_percentile_recent;
      const double loc=s.hot_metrics.close_location_percentile_recent;
      const double body=s.hot_metrics.body_wick_ratio_median;

      s.structural_context.compression_score=Clamp01((1.0-eff)*(1.0-body));
      s.structural_context.expansion_score=Clamp01(0.50*a/MathMax(1.0,b) + 0.50*body);
      s.structural_context.breakout_proximity_score=Clamp01(MathAbs(loc-0.5)*2.0);
      s.structural_context.range_position_score=Clamp01(loc);
      s.structural_context.structure_stability_score=Clamp01(0.5*s.hot_metrics.bar_continuity_score + 0.5*(1.0-s.tf[issx_ea2_tf_m15].close_mutation_risk));
      s.structural_context.micro_noise_risk=Clamp01(0.5*ov + 0.5*(1.0-body));
      s.structural_context.structure_clarity_score=Clamp01(0.4*body + 0.3*(1.0-ov) + 0.3*s.structural_context.structure_stability_score);
     }

   static void ScanContradictions(ISSX_EA2_SymbolState &s)
     {
      s.contradiction_present=false;
      s.contradiction_severity_max=issx_ea2_contradiction_low;
      s.contradiction_flags="none";

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
         if(s.contradiction_flags=="none")
            s.contradiction_flags="";
         if(s.contradiction_flags!="")
            s.contradiction_flags+="|";
         s.contradiction_flags+="frontier_safe_with_weak_overlap";
         if(s.contradiction_severity_max<issx_ea2_contradiction_moderate)
            s.contradiction_severity_max=issx_ea2_contradiction_moderate;
        }

      if(s.history_ready_for_intelligence &&
         s.provenance.recent_repair_activity_score>0.75)
        {
         s.contradiction_present=true;
         if(s.contradiction_flags=="none")
            s.contradiction_flags="";
         if(s.contradiction_flags!="")
            s.contradiction_flags+="|";
         s.contradiction_flags+="intelligence_ready_while_repair_severe";
         s.contradiction_severity_max=issx_ea2_contradiction_blocking;
        }

      if(ISSX_Util::IsEmpty(s.contradiction_flags))
         s.contradiction_flags="none";
     }

   static void UpdateCounters(ISSX_EA2_State &st)
     {
      st.counters.Reset();
      st.counters.symbols_total=ArraySize(st.symbols);
      st.symbol_count=st.counters.symbols_total;

      for(int i=0;i<ArraySize(st.symbols);i++)
        {
         if(st.symbols[i].acceptance_type==issx_acceptance_accepted_degraded)
            st.counters.symbols_degraded++;
         if(st.symbols[i].history_ready_for_ranking)
            st.counters.symbols_ranking_ready++;
         if(st.symbols[i].history_ready_for_intelligence)
            st.counters.symbols_intelligence_ready++;
         if(st.symbols[i].judgment.history_data_quality_score>=0.25)
            st.counters.symbols_minimal_ready++;
         if(st.symbols[i].provenance.temporary_rank_suspension)
            st.counters.temporary_rank_suspension_count++;
         if(st.symbols[i].contradiction_present)
           {
            st.counters.contradiction_count++;
            if(st.symbols[i].contradiction_severity_max>=issx_ea2_contradiction_blocking)
               st.counters.contradiction_blocking_count++;
           }

         for(int t=0;t<issx_ea2_tf_count;t++)
           {
            switch(st.symbols[i].tf[t].mode)
              {
               case issx_ea2_tfmode_cold:               st.counters.timeframes_cold++; break;
               case issx_ea2_tfmode_syncing:            st.counters.timeframes_syncing++; break;
               case issx_ea2_tfmode_ranking_ready:      st.counters.timeframes_ranking_ready++; break;
               case issx_ea2_tfmode_intelligence_ready: st.counters.timeframes_intelligence_ready++; break;
               case issx_ea2_tfmode_degraded:           st.counters.repairs_active++; break;
               default: break;
              }

            if(st.symbols[i].tf[t].history_finality_class==issx_ea2_finality_watch)
               st.counters.rewrite_watch_count++;
            if(st.symbols[i].tf[t].history_finality_class==issx_ea2_finality_recovering ||
               st.symbols[i].tf[t].history_finality_class==issx_ea2_finality_unstable)
               st.counters.repairs_active++;
           }
        }
     }

   static void UpdateCoverage(ISSX_EA2_State &st)
     {
      st.coverage.Reset();

      const int total=ArraySize(st.symbols);
      if(total<=0)
         return;

      int touched=0;
      int rankable=0;
      int deep_safe_tf=0;
      int total_tf=0;
      int overdue=0;
      int never_serviced=0;
      int never_ranked=0;

      const datetime now=TimeCurrent();

      for(int i=0;i<total;i++)
        {
         ISSX_EA2_SymbolState s=st.symbols[i];

         if(s.last_history_touch>0)
            touched++;
         else
            never_serviced++;

         if(!s.history_ready_for_ranking)
            never_ranked++;

         if(s.history_ready_for_ranking)
            rankable++;

         if(s.last_history_touch>0 && (long)(now-s.last_history_touch)>3600L)
            overdue++;

         for(int t=0;t<issx_ea2_tf_count;t++)
           {
            total_tf++;
            if(s.tf[t].metric_compare_class>=issx_metric_compare_bucket_safe)
               deep_safe_tf++;
           }
        }

      st.coverage.percent_universe_touched_recent=100.0*Clamp01((double)touched/(double)MathMax(1,total));
      st.coverage.percent_rankable_revalidated_recent=100.0*Clamp01((double)rankable/(double)MathMax(1,total));
      st.coverage.percent_frontier_revalidated_recent=st.coverage.percent_rankable_revalidated_recent;
      st.coverage.coverage_rankable_recent_pct=st.coverage.percent_rankable_revalidated_recent;
      st.coverage.coverage_frontier_recent_pct=st.coverage.percent_frontier_revalidated_recent;
      st.coverage.history_deep_completion_pct=100.0*Clamp01((double)deep_safe_tf/(double)MathMax(1,total_tf));
      st.coverage.never_serviced_count=never_serviced;
      st.coverage.overdue_service_count=overdue;
      st.coverage.never_ranked_but_eligible_count=never_ranked;
      st.coverage.newly_active_symbols_waiting_count=0;
      st.coverage.winner_cache_dependence_pct=0;
     }

   static void UpdateUniverseTruth(ISSX_EA2_State &st)
     {
      const int total=ArraySize(st.symbols);
      int active=0;
      int rankable=0;

      for(int i=0;i<total;i++)
        {
         if(st.symbols[i].last_history_touch>0)
            active++;
         if(st.symbols[i].history_ready_for_ranking)
            rankable++;
        }

      st.universe.broker_universe=total;
      st.universe.eligible_universe=total;
      st.universe.active_universe=active;
      st.universe.rankable_universe=rankable;
      st.universe.broker_universe_fingerprint=BuildUniverseFingerprint(st.symbols,"broker",false,false);
      st.universe.eligible_universe_fingerprint=BuildUniverseFingerprint(st.symbols,"eligible",false,false);
      st.universe.active_universe_fingerprint=BuildUniverseFingerprint(st.symbols,"active",true,false);
      st.universe.rankable_universe_fingerprint=BuildUniverseFingerprint(st.symbols,"rankable",false,true);

      if(active==0)
         st.universe.universe_drift_class="cold";
      else if(rankable<active)
         st.universe.universe_drift_class="partial";
      else
         st.universe.universe_drift_class="stable";
     }

   static void PopulateRegimeContext(ISSX_EA2_SymbolState &s)
     {
      s.hot_metrics.intraday_activity_state=
         (s.hot_metrics.atr_points_m5>=s.hot_metrics.atr_points_m15 && s.hot_metrics.atr_points_m5>0.0 ? "active" :
          s.hot_metrics.atr_points_m15>0.0 ? "mixed" : "dormant");

      s.hot_metrics.liquidity_regime_class=
         (s.hot_metrics.spread_to_atr_efficiency>=0.70 ? "strong" :
          s.hot_metrics.spread_to_atr_efficiency>=0.45 ? "acceptable" : "poor");

      s.hot_metrics.volatility_regime_class=
         (s.hot_metrics.atr_points_m15>=s.hot_metrics.atr_points_m5*1.20 ? "elevated" :
          s.hot_metrics.atr_points_m15>0.0 ? "normal" : "unknown");

      s.hot_metrics.expansion_state_class=
         (s.structural_context.expansion_score>=0.70 ? "expanding" :
          s.structural_context.compression_score>=0.70 ? "compressed" : "normal");

      s.hot_metrics.movement_quality_class=
         (s.structural_context.structure_clarity_score>=0.70 ? "orderly" :
          s.structural_context.micro_noise_risk>=0.65 ? "noisy" : "mixed");

      s.hot_metrics.movement_maturity_class=
         (s.hot_metrics.return_vol_ratio>=0.70 ? "extended" :
          s.hot_metrics.return_vol_ratio>=0.40 ? "developing" : "rotational");

      s.hot_metrics.microstructure_noise_class=
         (s.structural_context.micro_noise_risk>=0.70 ? "high_noise" :
          s.structural_context.micro_noise_risk>=0.45 ? "mixed_noise" : "low_noise");

      s.hot_metrics.range_efficiency_class=
         (s.hot_metrics.return_vol_ratio>=0.70 ? "efficient" :
          s.hot_metrics.return_vol_ratio>=0.45 ? "moderate" : "inefficient");

      s.hot_metrics.noise_to_range_ratio=Clamp01(1.0-s.hot_metrics.return_vol_ratio);

      s.hot_metrics.bar_overlap_class=
         (s.hot_metrics.overlap_percentile_recent>=0.70 ? "high_overlap" :
          s.hot_metrics.overlap_percentile_recent>=0.40 ? "mixed_overlap" : "low_overlap");

      s.hot_metrics.directional_persistence_class=
         (s.hot_metrics.return_vol_ratio>=0.72 ? "persistent" :
          s.hot_metrics.return_vol_ratio>=0.45 ? "mixed" : "two_way");

      s.hot_metrics.two_way_rotation_class=
         (s.hot_metrics.return_vol_ratio<0.40 ? "strong_rotation" :
          s.hot_metrics.return_vol_ratio<0.60 ? "mixed_rotation" : "limited_rotation");

      s.hot_metrics.gap_disruption_class=
         (s.hot_metrics.gap_penalty>=0.60 ? "disruptive" :
          s.hot_metrics.gap_penalty>=0.30 ? "present" : "low");

      s.hot_metrics.recent_compression_expansion_ratio=
         Clamp01((s.structural_context.expansion_score+0.0001)/(s.structural_context.compression_score+0.0001));

      s.hot_metrics.movement_to_cost_efficiency_class=
         (s.hot_metrics.spread_to_atr_efficiency>=0.70 && s.hot_metrics.return_vol_ratio>=0.45 ? "strong" :
          s.hot_metrics.spread_to_atr_efficiency>=0.45 ? "acceptable" : "poor");

      s.hot_metrics.constructability_class=
         (s.hot_metrics.spread_to_atr_efficiency>=0.70 &&
          s.structural_context.structure_clarity_score>=0.60 &&
          s.hot_metrics.gap_penalty<0.35 ? "strong" :
          s.hot_metrics.spread_to_atr_efficiency>=0.45 ? "acceptable" : "poor");
     }

   static void UpdateStageHealth(ISSX_EA2_State &st)
     {
      UpdateCounters(st);
      UpdateCoverage(st);
      UpdateUniverseTruth(st);

      st.stage_minimum_ready_flag=(st.counters.symbols_minimal_ready>0);

      if(!st.stage_minimum_ready_flag)
        {
         st.stage_publishability_state="blocked";
         st.dependency_block_reason="ea1_symbols_unavailable_or_history_cold";
         st.debug_weak_link_code="ea2_no_minimum_ready";
         st.degraded_flag=false;
         return;
        }

      if(st.counters.symbols_ranking_ready>0)
        {
         st.stage_publishability_state=(st.counters.symbols_intelligence_ready>0 ? "publishable" : "degraded_publishable");
         st.dependency_block_reason="none";
         st.debug_weak_link_code=(st.counters.symbols_intelligence_ready>0 ? "none" : "ea2_intelligence_thin");
         st.degraded_flag=(st.counters.symbols_intelligence_ready<=0);
         return;
        }

      st.stage_publishability_state="minimum_ready";
      st.dependency_block_reason="comparison_safe_subset_thin";
      st.debug_weak_link_code="ea2_ranking_thin";
      st.degraded_flag=true;
     }

public:
   static void PrepareEmptySymbol(ISSX_EA2_SymbolState &s,const string symbol)
     {
      s.Reset();
      s.symbol_raw=symbol;
      s.symbol_norm=NormalizeSymbolUpper(symbol);
      s.selected_for_hydration=true;
      s.sync_requested=true;

      for(int i=0;i<issx_ea2_tf_count;i++)
        {
         s.tf[i].Reset();
         s.tf[i].tf_name=TfNameByIndex(i);
         s.tf[i].timeframe=TfValueByIndex(i);
         s.tf[i].readiness_state=issx_ea2_history_never_requested;
         s.tf[i].last_sync_time=0;
         s.tf[i].warehouse_retained_bar_count=0;
         s.tf[i].effective_lookback_bars=0;
        }

      s.provenance.history_store_path=StageHistoryStorePath();
      s.provenance.history_index_path=StageHistoryIndexPath();
     }

   static bool HydrateSymbolTimeframe(ISSX_EA2_State &st,
                                      ISSX_EA2_SymbolState &s,
                                      const int tf_index,
                                      const double point,
                                      const bool deep_profile)
     {
      if(tf_index<0 || tf_index>=issx_ea2_tf_count)
         return false;

      MqlRates rates[];
      bool live_bar_present=false;
      int raw_copied=0;
      int last_error_code=0;
      int requested_raw=0;

      const int request_completed=RequestedCompletedBarsByProfile(tf_index,deep_profile);
      const datetime sync_time=TimeCurrent();
      st.forensic.copyrates_attempts++;
      AddForensicEvent(st,"history_copyrates_attempt",
                       s.symbol_norm+":"+TfNameByIndex(tf_index)+" completed_req="+IntegerToString(request_completed));

      s.tf[tf_index].readiness_state=issx_ea2_history_requested_sync;
      s.tf[tf_index].warehouse_retained_bar_count=0;
      s.tf[tf_index].effective_lookback_bars=0;
      s.tf[tf_index].warehouse_clip_flag=false;
      s.tf[tf_index].warmup_sufficient_flag=false;
      s.tf[tf_index].last_sync_time=sync_time;
      s.tf[tf_index].hydration_reason=(deep_profile ? "deep_queue" : "delta_first");
      s.tf[tf_index].tf_name=TfNameByIndex(tf_index);
      s.tf[tf_index].timeframe=TfValueByIndex(tf_index);

      if(!CopyCompletedRatesSafe(s.symbol_raw,TfValueByIndex(tf_index),request_completed,rates,live_bar_present,raw_copied,last_error_code,requested_raw))
        {
         st.forensic.copyrates_failures++;
         st.forensic.last_error_code=ISSX_ErrorToString(ISSX_ERR_COPYRATES)+"_"+IntegerToString(last_error_code);
         AddForensicEvent(st,"history_copyrates_result",
                          "fail symbol="+s.symbol_norm+" tf="+TfNameByIndex(tf_index)+" copied="+IntegerToString(raw_copied)+" err="+IntegerToString(last_error_code));
         AddForensicEvent(st,"history_error_conditions",
                          "copyrates_fail symbol="+s.symbol_norm+" tf="+TfNameByIndex(tf_index)+" err="+IntegerToString(last_error_code));
         s.tf[tf_index].Reset();
         s.tf[tf_index].tf_name=TfNameByIndex(tf_index);
         s.tf[tf_index].timeframe=TfValueByIndex(tf_index);
         s.tf[tf_index].metric_build_state="copy_failed";
         s.tf[tf_index].metric_rebuild_reason="copy_failed";
         s.tf[tf_index].mode=issx_ea2_tfmode_syncing;
         s.tf[tf_index].readiness_state=issx_ea2_history_syncing;
         s.tf[tf_index].last_sync_time=sync_time;
         s.tf[tf_index].hydration_reason=(deep_profile ? "deep_queue" : "delta_first");
         s.tf[tf_index].warehouse_quality=issx_ea2_warehouse_quality_cold;
         s.tf[tf_index].finality_state="unknown";
         s.tf[tf_index].rewrite_class=issx_ea2_rewrite_historical_block_rewrite;
         s.changed_tf_mask |= (1<<tf_index);
         s.changed_timeframe_count++;
         s.changed_since_last_publish=true;
         return false;
        }

      st.forensic.copyrates_successes++;
      st.forensic.max_rates_request=MathMax(st.forensic.max_rates_request,requested_raw);
      st.forensic.max_rates_returned=MathMax(st.forensic.max_rates_returned,raw_copied);
      st.forensic.max_completed_retained=MathMax(st.forensic.max_completed_retained,ArraySize(rates));
      AddForensicEvent(st,"history_copyrates_result",
                       "ok symbol="+s.symbol_norm+" tf="+TfNameByIndex(tf_index)+" copied="+IntegerToString(raw_copied)+" completed="+IntegerToString(ArraySize(rates)));

      s.tf[tf_index].Reset();
      s.tf[tf_index].tf_name=TfNameByIndex(tf_index);
      s.tf[tf_index].timeframe=TfValueByIndex(tf_index);
      s.tf[tf_index].bars_count=ArraySize(rates);
      s.tf[tf_index].effective_usable_bars=s.tf[tf_index].bars_count;
      s.tf[tf_index].last_complete_bar_time=(s.tf[tf_index].effective_usable_bars>0 ? rates[0].time : 0);
      s.tf[tf_index].bar_time_monotonic_ok=TimeSeriesMonotonic(rates);

      const int sec=SafePeriodSeconds(s.tf[tf_index].timeframe);
      const int gaps=CountGaps(rates,sec);
      s.tf[tf_index].gap_count=gaps;
      s.tf[tf_index].gap_density=(s.tf[tf_index].effective_usable_bars>0 ? (double)gaps/(double)MathMax(1,s.tf[tf_index].effective_usable_bars) : 1.0);

      const double min_target=(double)BarsTargetMinByIndex(tf_index);
      s.tf[tf_index].sample_depth_score=Clamp01((double)s.tf[tf_index].effective_usable_bars/MathMax(1.0,min_target));
      s.tf[tf_index].sample_diversity_score=Clamp01(1.0-s.tf[tf_index].gap_density);
      s.tf[tf_index].sync_truth_score=Clamp01(0.60*s.tf[tf_index].sample_depth_score + 0.40*s.tf[tf_index].sample_diversity_score);
      s.tf[tf_index].integrity_truth_score=Clamp01(0.50*(s.tf[tf_index].bar_time_monotonic_ok ? 1.0 : 0.0) + 0.50*(1.0-s.tf[tf_index].gap_density));

      s.tf[tf_index].last_bar_rewrite_count_recent=(gaps>0 ? MathMin(gaps,4) : 0);
      s.tf[tf_index].close_mutation_risk=Clamp01(s.tf[tf_index].gap_density*1.5);
      s.tf[tf_index].last_bar_finality_score=Clamp01(s.tf[tf_index].integrity_truth_score - s.tf[tf_index].close_mutation_risk*0.5);
      s.tf[tf_index].partial_bar_contamination_score=(live_bar_present ? 0.0 : 1.0);

      if(s.tf[tf_index].last_bar_finality_score>=0.80 && s.tf[tf_index].close_mutation_risk<0.20)
         s.tf[tf_index].history_finality_class=issx_ea2_finality_stable;
      else if(s.tf[tf_index].last_bar_finality_score>=0.60)
         s.tf[tf_index].history_finality_class=issx_ea2_finality_watch;
      else if(s.tf[tf_index].sample_depth_score>=0.30)
         s.tf[tf_index].history_finality_class=issx_ea2_finality_recovering;
      else
         s.tf[tf_index].history_finality_class=issx_ea2_finality_unstable;

      s.tf[tf_index].metric_truth_score=Clamp01(0.35*s.tf[tf_index].sync_truth_score +
                                                0.35*s.tf[tf_index].integrity_truth_score +
                                                0.30*(1.0-s.tf[tf_index].partial_bar_contamination_score));

      s.tf[tf_index].alignment_truth_score=Clamp01(0.60*s.tf[tf_index].integrity_truth_score + 0.40*(s.tf[tf_index].bar_time_monotonic_ok ? 1.0 : 0.0));
      s.tf[tf_index].time_alignment_score=s.tf[tf_index].alignment_truth_score;
      s.tf[tf_index].overlap_quality_score=Clamp01(1.0-s.tf[tf_index].gap_density);
      s.tf[tf_index].history_structure_score=Clamp01(0.50*s.tf[tf_index].integrity_truth_score + 0.50*s.tf[tf_index].sample_diversity_score);
      s.tf[tf_index].metric_input_sufficiency_score=Clamp01(0.70*s.tf[tf_index].sample_depth_score + 0.30*s.tf[tf_index].sample_diversity_score);
      s.tf[tf_index].metric_stability_score=Clamp01(0.50*s.tf[tf_index].history_structure_score + 0.50*(1.0-s.tf[tf_index].close_mutation_risk));
      s.tf[tf_index].metric_source_mode=issx_metric_source_direct;
      s.tf[tf_index].metric_build_state=(deep_profile ? "deep_built" : "warm_built");
      s.tf[tf_index].metric_rebuild_reason=(deep_profile ? "queue_deep_refresh" : "delta_warm_refresh");

      s.tf[tf_index].usable_for_20m_to_90m=(tf_index==issx_ea2_tf_m5 || tf_index==issx_ea2_tf_m15) && s.tf[tf_index].metric_truth_score>=0.45;
      s.tf[tf_index].usable_for_90m_to_4h=(tf_index==issx_ea2_tf_m15 || tf_index==issx_ea2_tf_h1) && s.tf[tf_index].metric_truth_score>=0.50;
      s.tf[tf_index].usable_for_4h_to_8h=(tf_index==issx_ea2_tf_h1) && s.tf[tf_index].metric_truth_score>=0.55;
      s.tf[tf_index].window_use_confidence=Clamp01(0.4*s.tf[tf_index].metric_truth_score +
                                                   0.3*s.tf[tf_index].overlap_quality_score +
                                                   0.3*s.tf[tf_index].metric_input_sufficiency_score);

      s.tf[tf_index].post_repair_stability_cycles=(s.tf[tf_index].history_finality_class==issx_ea2_finality_stable ? 5 :
                                                   s.tf[tf_index].history_finality_class==issx_ea2_finality_watch ? 3 :
                                                   s.tf[tf_index].history_finality_class==issx_ea2_finality_recovering ? 1 : 0);

      s.tf[tf_index].compare_class_cap_while_recovering=
         (s.tf[tf_index].history_finality_class==issx_ea2_finality_recovering ? issx_metric_compare_bucket_safe :
          s.tf[tf_index].history_finality_class==issx_ea2_finality_watch ? issx_metric_compare_frontier_safe :
                                                                           issx_metric_compare_global_safe);

      s.tf[tf_index].finality_recovery_gate=(s.tf[tf_index].post_repair_stability_cycles>=3);

      if(s.tf[tf_index].metric_truth_score>=0.82 && s.tf[tf_index].overlap_quality_score>=0.80 && s.tf[tf_index].finality_recovery_gate)
         s.tf[tf_index].metric_compare_class=issx_metric_compare_global_safe;
      else if(s.tf[tf_index].metric_truth_score>=0.68 && s.tf[tf_index].overlap_quality_score>=0.65 && s.tf[tf_index].finality_recovery_gate)
         s.tf[tf_index].metric_compare_class=issx_metric_compare_frontier_safe;
      else if(s.tf[tf_index].metric_truth_score>=0.48 && s.tf[tf_index].overlap_quality_score>=0.45)
         s.tf[tf_index].metric_compare_class=issx_metric_compare_bucket_safe;
      else
         s.tf[tf_index].metric_compare_class=issx_metric_compare_local_only;

      if(s.tf[tf_index].history_finality_class==issx_ea2_finality_recovering &&
         s.tf[tf_index].metric_compare_class>s.tf[tf_index].compare_class_cap_while_recovering)
         s.tf[tf_index].metric_compare_class=s.tf[tf_index].compare_class_cap_while_recovering;

      s.tf[tf_index].metric_safe_for_cross_symbol_compare=(s.tf[tf_index].metric_compare_class>=issx_metric_compare_bucket_safe);

      s.tf[tf_index].mode=
         (s.tf[tf_index].metric_compare_class>=issx_metric_compare_frontier_safe && s.tf[tf_index].history_finality_class==issx_ea2_finality_stable ? issx_ea2_tfmode_intelligence_ready :
          s.tf[tf_index].metric_compare_class>=issx_metric_compare_bucket_safe ? issx_ea2_tfmode_ranking_ready :
          s.tf[tf_index].metric_truth_score>=0.30 ? issx_ea2_tfmode_minimal_ready :
          s.tf[tf_index].bars_count>0 ? issx_ea2_tfmode_syncing :
                                        issx_ea2_tfmode_cold);

      if(s.tf[tf_index].history_finality_class==issx_ea2_finality_unstable && s.tf[tf_index].bars_count>0)
         s.tf[tf_index].mode=issx_ea2_tfmode_degraded;

      s.tf[tf_index].warehouse_retained_bar_count=MathMin(s.tf[tf_index].effective_usable_bars,WarehouseRetentionCapByIndex(tf_index));
      s.tf[tf_index].effective_lookback_bars=MathMin(s.tf[tf_index].effective_usable_bars,request_completed);
      s.tf[tf_index].warehouse_clip_flag=(s.tf[tf_index].effective_usable_bars>=WarehouseRetentionCapByIndex(tf_index));
      s.tf[tf_index].warmup_sufficient_flag=(s.tf[tf_index].effective_usable_bars>=BarsTargetMinByIndex(tf_index));
      s.tf[tf_index].last_sync_time=sync_time;
      s.tf[tf_index].last_closed_bar_open_time=(s.tf[tf_index].effective_usable_bars>0 ? rates[0].time : 0);
      s.tf[tf_index].recent_rewrite_span_bars=MathMin(s.tf[tf_index].gap_count*2,MathMax(0,s.tf[tf_index].effective_usable_bars));
      s.tf[tf_index].continuity_hash=StableHashRatesWindow(rates,MathMin(64,s.tf[tf_index].effective_usable_bars));
      s.tf[tf_index].trailing_finality_hash=StableHashRatesWindow(rates,MathMin(12,s.tf[tf_index].effective_usable_bars));
      s.tf[tf_index].bar_hash_drift_score=Clamp01((double)((long)(s.tf[tf_index].trailing_finality_hash%1000ULL))/1000.0);
      s.tf[tf_index].changed_flag_epoch=(int)sync_time;
      s.tf[tf_index].hydration_reason=(deep_profile ? "deep_queue" : "delta_first");
      s.tf[tf_index].rewrite_class=ClassifyRewriteClass(s.tf[tf_index]);
      s.tf[tf_index].warehouse_quality=ClassifyWarehouseQuality(s.tf[tf_index]);
      s.tf[tf_index].readiness_state=ClassifyReadinessState(s.tf[tf_index]);
      s.tf[tf_index].finality_state=FinalityClassToStringLocal(s.tf[tf_index].history_finality_class);

      s.changed_tf_mask |= (1<<tf_index);
      s.changed_timeframe_count++;
      s.changed_since_last_publish=true;
      s.last_history_touch=sync_time;
      return true;
     }

   static void BuildHotMetrics(ISSX_EA2_SymbolState &s,const double point,const double spread_points_now)
     {
      MqlRates m5[];
      MqlRates m15[];
      bool live_m5=false;
      bool live_m15=false;

      int raw5=0,raw15=0,err5=0,err15=0,want5=0,want15=0;
      const bool ok5=CopyCompletedRatesSafe(s.symbol_raw,PERIOD_M5,64,m5,live_m5,raw5,err5,want5);
      const bool ok15=CopyCompletedRatesSafe(s.symbol_raw,PERIOD_M15,64,m15,live_m15,raw15,err15,want15);

      s.hot_metrics.Reset();

      if(ok5)
        {
         s.hot_metrics.atr_points_m5=ApproxAtrPoints(m5,point,14);
         s.hot_metrics.bar_continuity_score=Clamp01(1.0-s.tf[issx_ea2_tf_m5].gap_density);
         s.hot_metrics.body_wick_ratio_median=BodyWickRatioMedian(m5,point);
         s.hot_metrics.overlap_percentile_recent=OverlapPercentileRecent(m5,point);
         s.hot_metrics.close_location_percentile_recent=CloseLocationPercentileRecent(m5);
         s.hot_metrics.inside_outside_bar_counts_recent=InsideOutsideCountRecent(m5);
        }

      if(ok15)
        {
         s.hot_metrics.atr_points_m15=ApproxAtrPoints(m15,point,14);
         s.hot_metrics.return_vol_ratio=ReturnVolRatio(m15);
        }

      const double atr_ref=MathMax(1.0,MathMax(s.hot_metrics.atr_points_m5,s.hot_metrics.atr_points_m15));
      s.hot_metrics.spread_to_atr_efficiency=Clamp01(1.0-(spread_points_now/atr_ref));
      s.hot_metrics.gap_penalty=Clamp01((s.tf[issx_ea2_tf_m5].gap_density+s.tf[issx_ea2_tf_m15].gap_density)/2.0);
     }

   static void UpdateProvenance(ISSX_EA2_SymbolState &s,const bool deep_profile)
     {
      s.provenance.warm_or_deep_profile=(deep_profile ? "deep" : "warm");
      s.provenance.timeframes_used_for_active_metrics="m5|m15|h1";
      s.provenance.oldest_bar_used=
         (s.tf[issx_ea2_tf_h1].last_complete_bar_time>0 ? s.tf[issx_ea2_tf_h1].last_complete_bar_time : s.tf[issx_ea2_tf_m15].last_complete_bar_time);
      s.provenance.newest_bar_used=
         (s.tf[issx_ea2_tf_m5].last_complete_bar_time>0 ? s.tf[issx_ea2_tf_m5].last_complete_bar_time : s.tf[issx_ea2_tf_m15].last_complete_bar_time);
      s.provenance.effective_sample_count=
         s.tf[issx_ea2_tf_m5].effective_usable_bars +
         s.tf[issx_ea2_tf_m15].effective_usable_bars +
         s.tf[issx_ea2_tf_h1].effective_usable_bars;

      s.provenance.metric_degradation_reason=(!s.history_ready_for_ranking ? "ranking_not_safe" : "na");
      s.provenance.recent_repair_activity_score=
         Clamp01((s.tf[issx_ea2_tf_m5].history_finality_class==issx_ea2_finality_recovering ? 0.4 : 0.0) +
                 (s.tf[issx_ea2_tf_m15].history_finality_class==issx_ea2_finality_recovering ? 0.3 : 0.0) +
                 (s.tf[issx_ea2_tf_h1].history_finality_class==issx_ea2_finality_recovering ? 0.3 : 0.0));

      s.provenance.history_flap_risk=Clamp01((double)(
         s.tf[issx_ea2_tf_m5].last_bar_rewrite_count_recent +
         s.tf[issx_ea2_tf_m15].last_bar_rewrite_count_recent +
         s.tf[issx_ea2_tf_h1].last_bar_rewrite_count_recent)/10.0);

      s.provenance.session_alignment_score=
         Clamp01((s.tf[issx_ea2_tf_m5].alignment_truth_score +
                  s.tf[issx_ea2_tf_m15].alignment_truth_score +
                  s.tf[issx_ea2_tf_h1].alignment_truth_score)/3.0);

      s.provenance.active_session_bar_ratio=Clamp01(0.60 + 0.40*s.provenance.session_alignment_score);
      s.provenance.dead_session_bar_ratio=Clamp01(1.0-s.provenance.active_session_bar_ratio);
      s.provenance.history_relevance_score=Clamp01(0.50*s.provenance.session_alignment_score + 0.50*s.judgment.usable_range_score);
      s.provenance.flap_count_recent=s.tf[issx_ea2_tf_m5].last_bar_rewrite_count_recent +
                                     s.tf[issx_ea2_tf_m15].last_bar_rewrite_count_recent +
                                     s.tf[issx_ea2_tf_h1].last_bar_rewrite_count_recent;
      s.provenance.flap_severity_score=Clamp01(s.provenance.history_flap_risk);

      s.provenance.temporary_rank_suspension=
         (s.tf[issx_ea2_tf_m15].history_finality_class==issx_ea2_finality_unstable ||
          s.tf[issx_ea2_tf_h1].history_finality_class==issx_ea2_finality_unstable);

      s.provenance.recovery_stability_cycles_required=(s.provenance.temporary_rank_suspension ? 3 : 0);
      s.provenance.history_bloat_prevented_count=(deep_profile ? 0 : 1);

      if(s.provenance.source_compatibility_class==issx_ea2_compatibility_incompatible)
         s.provenance.source_compatibility_class=issx_ea2_compatibility_compatible;
     }

   static void FinalizeSymbol(ISSX_EA2_SymbolState &s,const double point,const double spread_points_now,const bool deep_profile)
     {
      BuildHotMetrics(s,point,spread_points_now);
      ApplyTrustMap(s);
      UpdateJudgment(s);
      UpdateStructuralContext(s);
      PopulateRegimeContext(s);
      UpdateProvenance(s,deep_profile);
      ScanContradictions(s);
      UpdateJudgment(s);

      s.intraday_activity_state=s.hot_metrics.intraday_activity_state;
      s.liquidity_regime_class=s.hot_metrics.liquidity_regime_class;
      s.volatility_regime_class=s.hot_metrics.volatility_regime_class;
      s.expansion_state_class=s.hot_metrics.expansion_state_class;
      s.movement_quality_class=s.hot_metrics.movement_quality_class;
      s.movement_maturity_class=s.hot_metrics.movement_maturity_class;
      s.microstructure_noise_class=s.hot_metrics.microstructure_noise_class;
      s.range_efficiency_class=s.hot_metrics.range_efficiency_class;
      s.noise_to_range_ratio=s.hot_metrics.noise_to_range_ratio;
      s.bar_overlap_class=s.hot_metrics.bar_overlap_class;
      s.directional_persistence_class=s.hot_metrics.directional_persistence_class;
      s.two_way_rotation_class=s.hot_metrics.two_way_rotation_class;
      s.gap_disruption_class=s.hot_metrics.gap_disruption_class;
      s.recent_compression_expansion_ratio=s.hot_metrics.recent_compression_expansion_ratio;
      s.movement_to_cost_efficiency_class=s.hot_metrics.movement_to_cost_efficiency_class;
      s.constructability_class=s.hot_metrics.constructability_class;
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
      j.NameString("readiness_state",ReadinessStateToStringLocal(tf.readiness_state));
      j.NameString("rewrite_class",RewriteClassToStringLocal(tf.rewrite_class));
      j.NameString("warehouse_quality",WarehouseQualityToStringLocal(tf.warehouse_quality));
      j.NameInt("warehouse_retained_bar_count",tf.warehouse_retained_bar_count);
      j.NameInt("effective_lookback_bars",tf.effective_lookback_bars);
      j.NameBool("warehouse_clip_flag",tf.warehouse_clip_flag);
      j.NameBool("warmup_sufficient_flag",tf.warmup_sufficient_flag);
      j.NameInt("last_sync_time",(long)tf.last_sync_time);
      j.NameInt("last_closed_bar_open_time",(long)tf.last_closed_bar_open_time);
      j.NameInt("recent_rewrite_span_bars",tf.recent_rewrite_span_bars);
      j.NameInt("gap_count",tf.gap_count);
      j.NameString("finality_state",tf.finality_state);
      j.NameInt("continuity_hash",(long)tf.continuity_hash);
      j.NameInt("trailing_finality_hash",(long)tf.trailing_finality_hash);
     }

   static void WriteSymbolJson(ISSX_JsonWriter &j,const ISSX_EA2_SymbolState &s)
     {
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
      j.NameInt("oldest_bar_used",(long)s.provenance.oldest_bar_used);
      j.NameInt("newest_bar_used",(long)s.provenance.newest_bar_used);
      j.NameInt("effective_sample_count",s.provenance.effective_sample_count);
      j.NameString("metric_degradation_reason",s.provenance.metric_degradation_reason);
      j.NameDouble("recent_repair_activity_score",s.provenance.recent_repair_activity_score,4);
      j.NameDouble("history_flap_risk",s.provenance.history_flap_risk,4);
      j.NameDouble("session_alignment_score",s.provenance.session_alignment_score,4);
      j.NameDouble("active_session_bar_ratio",s.provenance.active_session_bar_ratio,4);
      j.NameDouble("dead_session_bar_ratio",s.provenance.dead_session_bar_ratio,4);
      j.NameDouble("history_relevance_score",s.provenance.history_relevance_score,4);
      j.NameInt("flap_count_recent",s.provenance.flap_count_recent);
      j.NameDouble("flap_severity_score",s.provenance.flap_severity_score,4);
      j.NameBool("temporary_rank_suspension",s.provenance.temporary_rank_suspension);
      j.NameInt("recovery_stability_cycles_required",s.provenance.recovery_stability_cycles_required);
      j.NameInt("history_bloat_prevented_count",s.provenance.history_bloat_prevented_count);
      j.NameString("continuity_origin",ContinuityOriginToStringLocal(s.provenance.continuity_origin));
      j.NameBool("resumed_from_persistence",s.provenance.resumed_from_persistence);
      j.NameString("source_compatibility_class",CompatibilityClassToStringLocal(s.provenance.source_compatibility_class));
      j.NameString("history_store_path",s.provenance.history_store_path);
      j.NameString("history_index_path",s.provenance.history_index_path);
      j.NameBool("live_bar_tracked_separately",s.provenance.live_bar_tracked_separately);
      j.NameBool("dirty_shard_flush_preferred",s.provenance.dirty_shard_flush_preferred);
      j.EndObject();

      j.BeginObjectNamed("regime_context");
      j.NameString("intraday_activity_state",s.intraday_activity_state);
      j.NameString("liquidity_regime_class",s.liquidity_regime_class);
      j.NameString("volatility_regime_class",s.volatility_regime_class);
      j.NameString("expansion_state_class",s.expansion_state_class);
      j.NameString("movement_quality_class",s.movement_quality_class);
      j.NameString("movement_maturity_class",s.movement_maturity_class);
      j.NameString("microstructure_noise_class",s.microstructure_noise_class);
      j.NameString("range_efficiency_class",s.range_efficiency_class);
      j.NameDouble("noise_to_range_ratio",s.noise_to_range_ratio,4);
      j.NameString("bar_overlap_class",s.bar_overlap_class);
      j.NameString("directional_persistence_class",s.directional_persistence_class);
      j.NameString("two_way_rotation_class",s.two_way_rotation_class);
      j.NameString("gap_disruption_class",s.gap_disruption_class);
      j.NameDouble("recent_compression_expansion_ratio",s.recent_compression_expansion_ratio,4);
      j.NameString("movement_to_cost_efficiency_class",s.movement_to_cost_efficiency_class);
      j.NameString("constructability_class",s.constructability_class);
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
      j.NameString("contradiction_severity_max",ContradictionSeverityToString(s.contradiction_severity_max));
      j.NameString("contradiction_flags",s.contradiction_flags);
      j.NameString("dominant_degradation_reason",s.dominant_degradation_reason);
     }

   static string BuildStageRootJson(const ISSX_EA2_State &st)
     {
      ISSX_EA2_State local_state=st;
      UpdateStageHealth(local_state);

      ISSX_JsonWriter j;
      j.Reset();
      j.BeginObject();

      j.NameString("stage_id",StageIdString());
      j.NameInt("sequence_no",(long)local_state.manifest.sequence_no);
      j.NameInt("minute_id",(long)local_state.manifest.minute_id);
      j.NameString("schema_version",local_state.manifest.schema_version);
      j.NameInt("schema_epoch",local_state.manifest.schema_epoch);
      j.NameString("upstream_source_used",local_state.upstream_source_used);
      j.NameString("upstream_source_reason",local_state.upstream_source_reason);
      j.NameString("upstream_compatibility_class",CompatibilityClassToStringLocal(local_state.upstream_compatibility_class));
      j.NameDouble("upstream_compatibility_score",local_state.upstream_compatibility_score,4);
      j.NameInt("fallback_depth_used",local_state.fallback_depth_used);
      j.NameDouble("fallback_penalty_applied",local_state.fallback_penalty_applied,4);
      j.NameBool("degraded_flag",local_state.degraded_flag);
      j.NameBool("recovery_publish_flag",local_state.recovery_publish_flag);
      j.NameBool("projection_partial_success_flag",local_state.projection_partial_success_flag);
      j.NameBool("stage_minimum_ready_flag",local_state.stage_minimum_ready_flag);
      j.NameString("stage_publishability_state",local_state.stage_publishability_state);
      j.NameString("dependency_block_reason",local_state.dependency_block_reason);
      j.NameString("debug_weak_link_code",local_state.debug_weak_link_code);

      j.BeginObjectNamed("universe");
      j.NameInt("broker_universe",local_state.universe.broker_universe);
      j.NameInt("eligible_universe",local_state.universe.eligible_universe);
      j.NameInt("active_universe",local_state.universe.active_universe);
      j.NameInt("rankable_universe",local_state.universe.rankable_universe);
      j.NameString("broker_universe_fingerprint",local_state.universe.broker_universe_fingerprint);
      j.NameString("eligible_universe_fingerprint",local_state.universe.eligible_universe_fingerprint);
      j.NameString("active_universe_fingerprint",local_state.universe.active_universe_fingerprint);
      j.NameString("rankable_universe_fingerprint",local_state.universe.rankable_universe_fingerprint);
      j.NameString("universe_drift_class",local_state.universe.universe_drift_class);
      j.EndObject();

      j.BeginObjectNamed("delta");
      j.NameInt("changed_symbol_count",local_state.delta.changed_symbol_count);
      j.NameString("changed_symbol_ids",local_state.delta.changed_symbol_ids);
      j.NameInt("changed_family_count",local_state.delta.changed_family_count);
      j.NameInt("changed_timeframe_count",local_state.delta.changed_timeframe_count);
      j.NameString("changed_timeframe_ids",local_state.delta.changed_timeframe_ids);
      j.NameInt("queue_driven_deep_count",local_state.delta.queue_driven_deep_count);
      j.NameInt("cache_reuse_count",local_state.delta.cache_reuse_count);
      j.EndObject();

      j.BeginObjectNamed("coverage");
      j.NameDouble("percent_universe_touched_recent",local_state.coverage.percent_universe_touched_recent,2);
      j.NameDouble("percent_rankable_revalidated_recent",local_state.coverage.percent_rankable_revalidated_recent,2);
      j.NameDouble("percent_frontier_revalidated_recent",local_state.coverage.percent_frontier_revalidated_recent,2);
      j.NameDouble("coverage_rankable_recent_pct",local_state.coverage.coverage_rankable_recent_pct,2);
      j.NameDouble("coverage_frontier_recent_pct",local_state.coverage.coverage_frontier_recent_pct,2);
      j.NameDouble("history_deep_completion_pct",local_state.coverage.history_deep_completion_pct,2);
      j.NameInt("never_serviced_count",local_state.coverage.never_serviced_count);
      j.NameInt("overdue_service_count",local_state.coverage.overdue_service_count);
      j.NameInt("newly_active_symbols_waiting_count",local_state.coverage.newly_active_symbols_waiting_count);
      j.NameInt("never_ranked_but_eligible_count",local_state.coverage.never_ranked_but_eligible_count);
      j.NameInt("winner_cache_dependence_pct",local_state.coverage.winner_cache_dependence_pct);
      j.EndObject();

      j.BeginObjectNamed("counters");
      j.NameInt("symbols_total",local_state.counters.symbols_total);
      j.NameInt("symbols_minimal_ready",local_state.counters.symbols_minimal_ready);
      j.NameInt("symbols_ranking_ready",local_state.counters.symbols_ranking_ready);
      j.NameInt("symbols_intelligence_ready",local_state.counters.symbols_intelligence_ready);
      j.NameInt("symbols_degraded",local_state.counters.symbols_degraded);
      j.NameInt("timeframes_cold",local_state.counters.timeframes_cold);
      j.NameInt("timeframes_syncing",local_state.counters.timeframes_syncing);
      j.NameInt("timeframes_ranking_ready",local_state.counters.timeframes_ranking_ready);
      j.NameInt("timeframes_intelligence_ready",local_state.counters.timeframes_intelligence_ready);
      j.NameInt("repairs_active",local_state.counters.repairs_active);
      j.NameInt("rewrite_watch_count",local_state.counters.rewrite_watch_count);
      j.NameInt("temporary_rank_suspension_count",local_state.counters.temporary_rank_suspension_count);
      j.NameInt("contradiction_count",local_state.counters.contradiction_count);
      j.NameInt("contradiction_blocking_count",local_state.counters.contradiction_blocking_count);
      j.EndObject();

      j.BeginObjectNamed("forensic");
      j.NameInt("history_discovery_attempt",local_state.forensic.discovery_attempts);
      j.NameInt("history_discovery_success",local_state.forensic.discovery_successes);
      j.NameInt("history_symbol_start",local_state.forensic.symbol_started);
      j.NameInt("history_symbol_complete",local_state.forensic.symbol_completed);
      j.NameInt("history_copyrates_attempt",local_state.forensic.copyrates_attempts);
      j.NameInt("history_copyrates_success",local_state.forensic.copyrates_successes);
      j.NameInt("history_copyrates_fail",local_state.forensic.copyrates_failures);
      j.NameInt("history_batch_symbols_target",local_state.forensic.batch_symbols_target);
      j.NameInt("history_batch_symbols_done",local_state.forensic.batch_symbols_done);
      j.NameInt("history_persistence_write_attempt",local_state.forensic.persistence_write_attempts);
      j.NameInt("history_persistence_write_success",local_state.forensic.persistence_write_successes);
      j.NameInt("history_persistence_write_fail",local_state.forensic.persistence_write_failures);
      j.NameInt("history_persistence_index_attempt",local_state.forensic.persistence_index_attempts);
      j.NameInt("history_persistence_index_success",local_state.forensic.persistence_index_successes);
      j.NameInt("history_persistence_index_fail",local_state.forensic.persistence_index_failures);
      j.NameInt("history_max_rates_request",local_state.forensic.max_rates_request);
      j.NameInt("history_max_rates_returned",local_state.forensic.max_rates_returned);
      j.NameInt("history_max_completed_retained",local_state.forensic.max_completed_retained);
      j.NameString("history_last_error_code",local_state.forensic.last_error_code);
      j.NameString("history_event_log",local_state.forensic.event_log_csv);
      j.EndObject();

      j.BeginArrayNamed("symbols");
      for(int i=0;i<ArraySize(local_state.symbols);i++)
        {
         j.BeginObject();
         WriteSymbolJson(j,local_state.symbols[i]);
         j.EndObject();
        }
      j.EndArray();

      j.EndObject();
      return j.ToString();
     }

   static bool RebuildStateFromSymbolList(ISSX_EA2_State &st,
                                          const string &symbols[],
                                          const bool deep_profile_default,
                                          const string firm_id="")
     {
      st.Reset();
      const int n=ArraySize(symbols);
      st.forensic.discovery_attempts++;
      st.forensic.batch_symbols_target=n;
      AddForensicEvent(st,"history_discovery_attempt",
                       "symbols="+IntegerToString(n)+" deep_default="+(deep_profile_default?"true":"false"));
      if(n<=0)
        {
         st.forensic.last_error_code=ISSX_ErrorToString(ISSX_ERR_SYMBOL_DISCOVERY);
         AddForensicEvent(st,"history_error_conditions","discovery_empty_symbol_list");
         return false;
        }

      st.forensic.discovery_successes++;
      AddForensicEvent(st,"history_discovery_success","symbols="+IntegerToString(n));

      ArrayResize(st.symbols,n);

      string changed_symbol_ids="";
      string changed_timeframe_ids="";

      for(int i=0;i<n;i++)
        {
         PrepareEmptySymbol(st.symbols[i],symbols[i]);
         st.forensic.symbol_started++;
         AddForensicEvent(st,"history_symbol_start",st.symbols[i].symbol_norm+" idx="+IntegerToString(i));

         double point=0.0;
         double bid=0.0;
         double ask=0.0;

         if(!SymbolInfoDouble(symbols[i],SYMBOL_POINT,point) || point<=0.0)
            point=_Point;

         SymbolInfoDouble(symbols[i],SYMBOL_BID,bid);
         SymbolInfoDouble(symbols[i],SYMBOL_ASK,ask);

         const double spread_points=((point>0.0 && ask>bid) ? (ask-bid)/point : 0.0);

         for(int t=0;t<issx_ea2_tf_count;t++)
           {
            const bool tf_deep=(deep_profile_default || t==issx_ea2_tf_h1);
            const bool hydrated=HydrateSymbolTimeframe(st,st.symbols[i],t,point,tf_deep);

            if(tf_deep)
               st.delta.queue_driven_deep_count++;
            else
               st.delta.cache_reuse_count++;

            if(!ISSX_Util::IsEmpty(firm_id) && hydrated)
               WriteWarehouseShard(st,firm_id,st.symbols[i],t);

           AppendCsvToken(changed_timeframe_ids,st.symbols[i].symbol_norm + ":" + TfNameByIndex(t));

            AddForensicEvent(st,"history_batch_progress",
                             "symbol="+st.symbols[i].symbol_norm+" tf="+TfNameByIndex(t)+" hydrated="+(hydrated?"true":"false")+
                             " done="+IntegerToString(st.forensic.symbol_completed)+"/"+IntegerToString(st.forensic.batch_symbols_target));
           }

         FinalizeSymbol(st.symbols[i],point,spread_points,deep_profile_default);
         AppendCsvToken(changed_symbol_ids,st.symbols[i].symbol_norm);
         st.forensic.symbol_completed++;
         st.forensic.batch_symbols_done=st.forensic.symbol_completed;
         AddForensicEvent(st,"history_symbol_complete",
                          st.symbols[i].symbol_norm+" changed_tf="+IntegerToString(st.symbols[i].changed_timeframe_count)+" ranking="+
                          (st.symbols[i].history_ready_for_ranking?"true":"false")+" intelligence="+
                          (st.symbols[i].history_ready_for_intelligence?"true":"false"));
        }

      st.delta.changed_symbol_count=n;
      st.delta.changed_symbol_ids=changed_symbol_ids;
      st.delta.changed_timeframe_count=n*issx_ea2_tf_count;
      st.delta.changed_timeframe_ids=changed_timeframe_ids;
      st.symbol_count=n;
      st.upstream_compatibility_class=issx_ea2_compatibility_compatible;
      st.upstream_source_used="ea1_root_or_internal";
      st.upstream_source_reason="delta_first_rebuild";
      st.upstream_compatibility_score=0.85;
      st.projection_partial_success_flag=false;

      UpdateStageHealth(st);
      st.recovery_publish_flag=st.degraded_flag;
      AddForensicEvent(st,(st.stage_minimum_ready_flag?"history_ready_state":"history_partial_state"),
                       "publishability="+st.stage_publishability_state+" reason="+st.dependency_block_reason);
      AddForensicEvent(st,"history_batch_complete",
                       "symbols_done="+IntegerToString(st.forensic.batch_symbols_done)+" copyrates_ok="+
                       IntegerToString(st.forensic.copyrates_successes)+" copyrates_fail="+IntegerToString(st.forensic.copyrates_failures));

      if(!ISSX_Util::IsEmpty(firm_id))
         TouchWarehouseIndexes(firm_id,st);

      return true;
     }

   static bool StageBoot(ISSX_EA2_State &st,
                         const string &symbols[],
                         const bool deep_profile_default,
                         const string firm_id="")
     {
      if(ArraySize(symbols)<=0)
        {
         st.Reset();
         AddForensicEvent(st,"history_error_conditions","stage_boot_empty_symbols");
         st.stage_minimum_ready_flag=false;
         st.stage_publishability_state="blocked";
         st.dependency_block_reason="ea1_symbols_unavailable";
         st.debug_weak_link_code="ea2_boot_empty";
         return false;
        }

      const bool ok=RebuildStateFromSymbolList(st,symbols,deep_profile_default,firm_id);
      if(!ok)
        {
         st.stage_minimum_ready_flag=false;
         st.stage_publishability_state="blocked";
         st.dependency_block_reason="ea1_symbols_unavailable";
         st.debug_weak_link_code="ea2_boot_empty";
        }
      return ok;
     }

   static bool StageSlice(ISSX_EA2_State &st,
                          const string &symbols[],
                          const bool deep_profile_default,
                          const int max_symbols_per_slice,
                          const string firm_id="")
     {
      const int source_count=ArraySize(symbols);
      int stream_source_total=MathMax(0,source_count);
      int stream_cycles=st.stream_cycles+1;
      int stream_cursor=st.stream_cursor;
      bool stream_cycle_advanced=false;

      if(source_count<=0)
        {
         AddForensicEvent(st,"history_error_conditions","stage_slice_empty_source");
         st.stage_minimum_ready_flag=false;
         st.stage_publishability_state="blocked";
         st.dependency_block_reason=ISSX_ErrorToString(ISSX_ERR_HISTORY_NOT_READY);
         st.debug_weak_link_code="ea2_slice_empty";
         return false;
        }

      const int slice_limit=(max_symbols_per_slice>0 ? max_symbols_per_slice : source_count);
      const int n=MathMin(source_count,slice_limit);
      if(n<=0)
        {
         AddForensicEvent(st,"history_error_conditions","stage_slice_zero_limit");
         st.stage_minimum_ready_flag=false;
         st.stage_publishability_state="blocked";
         st.dependency_block_reason=ISSX_ErrorToString(ISSX_ERR_HISTORY_NOT_READY);
         st.debug_weak_link_code="ea2_slice_empty";
         return false;
        }

      if(stream_cursor<0 || stream_cursor>=source_count)
         stream_cursor=0;
      const int stream_window_size=n;
      const int stream_window_start=stream_cursor;
      const int stream_window_end=MathMin(source_count,stream_window_start+n);

      string slice_symbols[];
      if(ArrayResize(slice_symbols,n)!=n)
        {
         AddForensicEvent(st,"history_error_conditions","stage_slice_resize_failed");
         st.stage_minimum_ready_flag=false;
         st.stage_publishability_state="blocked";
         st.dependency_block_reason=ISSX_ErrorToString(ISSX_ERR_MEMORY_ALLOC);
         st.debug_weak_link_code="ea2_slice_resize_failed";
         return false;
        }

      for(int i=0;i<n;i++)
        {
         int src_idx=stream_window_start+i;
         if(src_idx>=source_count)
            src_idx=source_count-1;
         slice_symbols[i]=symbols[src_idx];
        }

      const bool ok=RebuildStateFromSymbolList(st,slice_symbols,deep_profile_default,firm_id);
      if(!ok)
        {
         st.stage_minimum_ready_flag=false;
         st.stage_publishability_state="blocked";
         st.dependency_block_reason=ISSX_ErrorToString(ISSX_ERR_HISTORY_NOT_READY);
         st.debug_weak_link_code="ea2_slice_empty";
         return false;
        }

      int stream_processed_total=MathMin(source_count,stream_window_end);
      if(stream_window_end>=source_count)
        {
         stream_cursor=0;
         stream_processed_total=source_count;
         stream_cycle_advanced=true;
        }
      else
        {
         stream_cursor=stream_window_end;
        }

      st.stream_source_total=stream_source_total;
      st.stream_cursor=stream_cursor;
      st.stream_window_start=stream_window_start;
      st.stream_window_end=stream_window_end;
      st.stream_window_size=stream_window_size;
      st.stream_processed_total=stream_processed_total;
      st.stream_cycles=stream_cycles;
      st.stream_cycle_advanced=stream_cycle_advanced;

      AddForensicEvent(st,"history_batch_progress",
                       "cursor_start="+IntegerToString(st.stream_window_start)+
                       " cursor_end="+IntegerToString(st.stream_window_end)+
                       " source_total="+IntegerToString(st.stream_source_total));
      return true;
     }

   static string StagePublish(const ISSX_EA2_State &st)
     {
      return BuildStageRootJson(st);
     }

   static string BuildStageJson(const ISSX_EA2_State &st)
     {
      return BuildStageRootJson(st);
     }

   static string BuildDebugSnapshot(const ISSX_EA2_State &st)
     {
      ISSX_EA2_State local_state=st;
      UpdateStageHealth(local_state);

      ISSX_JsonWriter j;
      j.Reset();
      j.BeginObject();
      j.KeyValue("stage_id",StageIdString());
      j.KeyValue("stage_minimum_ready_flag",ISSX_Util::BoolToString(local_state.stage_minimum_ready_flag),false);
      j.KeyValue("stage_publishability_state",local_state.stage_publishability_state);
      j.KeyValue("dependency_block_reason",local_state.dependency_block_reason);
      j.KeyValue("debug_weak_link_code",local_state.debug_weak_link_code);
      j.KeyValue("symbol_count",IntegerToString(local_state.symbol_count),false);
      j.KeyValue("stream_source_total",IntegerToString(local_state.stream_source_total),false);
      j.KeyValue("stream_cursor",IntegerToString(local_state.stream_cursor),false);
      j.KeyValue("stream_window_start",IntegerToString(local_state.stream_window_start),false);
      j.KeyValue("stream_window_end",IntegerToString(local_state.stream_window_end),false);
      j.KeyValue("stream_window_size",IntegerToString(local_state.stream_window_size),false);
      j.KeyValue("stream_processed_total",IntegerToString(local_state.stream_processed_total),false);
      j.KeyValue("stream_cycles",IntegerToString(local_state.stream_cycles),false);
      j.KeyValue("stream_cycle_advanced",ISSX_Util::BoolToString(local_state.stream_cycle_advanced),false);
      j.KeyValue("changed_symbol_count",IntegerToString(local_state.delta.changed_symbol_count),false);
      j.KeyValue("changed_timeframe_count",IntegerToString(local_state.delta.changed_timeframe_count),false);
      j.KeyValue("history_store_path",StageHistoryStorePath());
      j.KeyValue("history_index_path",StageHistoryIndexPath());
      j.KeyValue("stage_persistence_path",StagePersistencePath());
      j.KeyValue("warehouse_policy","rolling_sharded_bounded");
      j.KeyValue("broker_universe",IntegerToString(local_state.universe.broker_universe),false);
      j.KeyValue("active_universe",IntegerToString(local_state.universe.active_universe),false);
      j.KeyValue("rankable_universe",IntegerToString(local_state.universe.rankable_universe),false);
      j.KeyValue("history_deep_completion_pct",DoubleToString(local_state.coverage.history_deep_completion_pct,2),false);
      j.KeyValue("percent_universe_touched_recent",DoubleToString(local_state.coverage.percent_universe_touched_recent,2),false);
      j.KeyValue("overdue_service_count",IntegerToString(local_state.coverage.overdue_service_count),false);
      j.KeyValue("never_serviced_count",IntegerToString(local_state.coverage.never_serviced_count),false);
      j.KeyValue("temporary_rank_suspension_count",IntegerToString(local_state.counters.temporary_rank_suspension_count),false);
      j.KeyValue("contradiction_count",IntegerToString(local_state.counters.contradiction_count),false);
      j.KeyValue("contradiction_blocking_count",IntegerToString(local_state.counters.contradiction_blocking_count),false);
      j.KeyValue("rewrite_watch_count",IntegerToString(local_state.counters.rewrite_watch_count),false);
      j.KeyValue("history_discovery_attempt",IntegerToString(local_state.forensic.discovery_attempts),false);
      j.KeyValue("history_discovery_success",IntegerToString(local_state.forensic.discovery_successes),false);
      j.KeyValue("history_symbol_start",IntegerToString(local_state.forensic.symbol_started),false);
      j.KeyValue("history_symbol_complete",IntegerToString(local_state.forensic.symbol_completed),false);
      j.KeyValue("history_copyrates_attempt",IntegerToString(local_state.forensic.copyrates_attempts),false);
      j.KeyValue("history_copyrates_success",IntegerToString(local_state.forensic.copyrates_successes),false);
      j.KeyValue("history_copyrates_fail",IntegerToString(local_state.forensic.copyrates_failures),false);
      j.KeyValue("history_batch_symbols_target",IntegerToString(local_state.forensic.batch_symbols_target),false);
      j.KeyValue("history_batch_symbols_done",IntegerToString(local_state.forensic.batch_symbols_done),false);
      j.KeyValue("stream_source_total",IntegerToString(local_state.stream_source_total),false);
      j.KeyValue("stream_cursor",IntegerToString(local_state.stream_cursor),false);
      j.KeyValue("stream_window_start",IntegerToString(local_state.stream_window_start),false);
      j.KeyValue("stream_window_end",IntegerToString(local_state.stream_window_end),false);
      j.KeyValue("stream_window_size",IntegerToString(local_state.stream_window_size),false);
      j.KeyValue("stream_processed_total",IntegerToString(local_state.stream_processed_total),false);
      j.KeyValue("stream_cycles",IntegerToString(local_state.stream_cycles),false);
      j.KeyValue("stream_cycle_advanced",ISSX_Util::BoolToString(local_state.stream_cycle_advanced),false);
      j.KeyValue("history_persistence_write_attempt",IntegerToString(local_state.forensic.persistence_write_attempts),false);
      j.KeyValue("history_persistence_write_success",IntegerToString(local_state.forensic.persistence_write_successes),false);
      j.KeyValue("history_persistence_write_fail",IntegerToString(local_state.forensic.persistence_write_failures),false);
      j.KeyValue("history_persistence_index_attempt",IntegerToString(local_state.forensic.persistence_index_attempts),false);
      j.KeyValue("history_persistence_index_success",IntegerToString(local_state.forensic.persistence_index_successes),false);
      j.KeyValue("history_persistence_index_fail",IntegerToString(local_state.forensic.persistence_index_failures),false);
      j.KeyValue("history_max_rates_request",IntegerToString(local_state.forensic.max_rates_request),false);
      j.KeyValue("history_max_rates_returned",IntegerToString(local_state.forensic.max_rates_returned),false);
      j.KeyValue("history_max_completed_retained",IntegerToString(local_state.forensic.max_completed_retained),false);
      j.KeyValue("history_last_error_code",local_state.forensic.last_error_code);
      j.KeyValue("history_event_log",local_state.forensic.event_log_csv);
      j.EndObject();
      return j.ToString();
     }

   static string BuildDebugJson(const ISSX_EA2_State &st)
     {
      return BuildDebugSnapshot(st);
     }

   static string ExportOptionalIntelligence(const ISSX_EA2_State &st)
     {
      return BuildStageRootJson(st);
     }
  };



string ISSX_HistoryDiagTag()
  {
   return "history_diag_v174f";
  }


string ISSX_HistoryEngineDebugSignature()
  {
   return ISSX_HistoryDiagTag();
  }

#endif // __ISSX_HISTORY_ENGINE_MQH__
