#ifndef __ISSX_MARKET_ENGINE_MQH__
#define __ISSX_MARKET_ENGINE_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>

// ============================================================================
// ISSX MARKET ENGINE v1.708
// EA1 shared engine for MarketStateCore.
//
// HARDENING NOTES
// - core-owned ISSX_JsonWriter only
// - no local JSON dialect
// - no local clone of shared semantic enums
// - deterministic universe fingerprints
// - explicit stage API normalization
// - explicit degraded / blocked semantics
// - patch-friendly EA1 full-universe dump projection
// - continuity-preserving stage slices
// - no silent state wipe on every StageSlice
// - stage builds JSON projections and leaves persistence/path ownership to the
//   owner runtime/persistence layer
// ============================================================================

#define ISSX_MARKET_ENGINE_MODULE_VERSION "1.708"

// ============================================================================
// SECTION 01: EA1 PHASE IDS
// ============================================================================

enum ISSX_EA1_PhaseId
  {
   issx_ea1_phase_none = 0,
   issx_ea1_phase_discover_symbols,
   issx_ea1_phase_normalize_identity,
   issx_ea1_phase_refresh_specs_delta_first,
   issx_ea1_phase_sample_runtime_delta_first,
   issx_ea1_phase_classify_symbols_delta_first,
   issx_ea1_phase_update_tradeability_delta_first,
   issx_ea1_phase_update_continuity,
   issx_ea1_phase_publish
  };

// ============================================================================
// SECTION 02: EA1 ADMISSION / LIFECYCLE ENUMS
// ============================================================================

enum ISSX_EA1_AdmissionState
  {
   issx_ea1_admission_listed = 0,
   issx_ea1_admission_metadata_ready,
   issx_ea1_admission_probe_ready,
   issx_ea1_admission_rank_candidate
  };

enum ISSX_EA1_LifecycleState
  {
   issx_ea1_lifecycle_new = 0,
   issx_ea1_lifecycle_stable,
   issx_ea1_lifecycle_changed,
   issx_ea1_lifecycle_cooling,
   issx_ea1_lifecycle_blocked
  };

enum ISSX_EA1_SessionPhase
  {
   issx_ea1_session_unknown = 0,
   issx_ea1_session_closed,
   issx_ea1_session_pre_open,
   issx_ea1_session_open,
   issx_ea1_session_mid,
   issx_ea1_session_late,
   issx_ea1_session_rollover
  };

// Legacy owner-side bridge for pre-v1.708 EA1 session labels.
#define issx_ea1_session_preopen    issx_ea1_session_pre_open
#define issx_ea1_session_transition issx_ea1_session_rollover


enum ISSX_EA1_RepresentationReason
  {
   issx_rep_reason_none = 0,
   issx_rep_reason_exact_root_match,
   issx_rep_reason_suffix_variant_detected,
   issx_rep_reason_prefix_variant_detected,
   issx_rep_reason_contract_token_detected,
   issx_rep_reason_family_alias_detected,
   issx_rep_reason_cost_better_variant,
   issx_rep_reason_session_better_variant,
   issx_rep_reason_continuity_lock
  };

enum ISSX_EA1_MarketStateReason
  {
   issx_market_reason_none = 0,
   issx_market_reason_quote_recent,
   issx_market_reason_quote_old,
   issx_market_reason_trade_disabled,
   issx_market_reason_session_closed,
   issx_market_reason_spec_incomplete,
   issx_market_reason_probe_pending,
   issx_market_reason_shock_spread,
   issx_market_reason_selection_required
  };

ISSX_PhaseId ISSX_EA1_MapToRuntimePhase(const ISSX_EA1_PhaseId phase)
  {
   switch(phase)
     {
      case issx_ea1_phase_discover_symbols:
         return issx_phase_ea1_discover_symbols;
      case issx_ea1_phase_normalize_identity:
         return issx_phase_ea1_family_resolution;
      case issx_ea1_phase_refresh_specs_delta_first:
         return issx_phase_ea1_probe_specs;
      case issx_ea1_phase_sample_runtime_delta_first:
         return issx_phase_ea1_sample_runtime;
      case issx_ea1_phase_classify_symbols_delta_first:
         return issx_phase_ea1_classify;
      case issx_ea1_phase_update_tradeability_delta_first:
         return issx_phase_ea1_tradeability;
      case issx_ea1_phase_update_continuity:
         return issx_phase_ea1_snapshot;
      case issx_ea1_phase_publish:
         return issx_phase_ea1_publish;
      case issx_ea1_phase_none:
      default:
         return issx_phase_none;
     }
  }

// ============================================================================
// SECTION 03: PER-SYMBOL BLOCKS
// ============================================================================

struct ISSX_EA1_RawBrokerObservation
  {
   string   symbol_raw;
   string   path;
   string   description;
   long     trade_mode;
   long     calc_mode;
   int      digits;
   double   point;
   double   tick_size;
   double   tick_value;
   double   tick_value_profit;
   double   tick_value_loss;
   double   contract_size;
   double   volume_min;
   double   volume_step;
   double   volume_max;
   int      stops_level;
   int      freeze_level;
   string   margin_currency;
   string   profit_currency;
   string   base_currency;
   string   quote_currency;
   bool     session_property_availability;
   bool     selection_state;
   bool     sync_state;
   bool     metadata_readable;
   bool     quote_observable;
   bool     synchronized_flag;
   bool     history_addressable;
   bool     trade_permitted;
   bool     custom_symbol_flag;
   bool     property_unavailable_flag;
   bool     select_failed_temp;
   bool     select_failed_perm;
   string   symbol_discovery_state;
   string   symbol_selection_state;
   string   symbol_synchronization_state;
   string   property_read_status;
   int      property_read_fail_mask;
   MqlTick  quote_tick_snapshot;
   datetime quote_time;
   datetime quote_last_seen;
   int      session_trade_windows;
   int      session_quote_windows;

   void Reset()
     {
      symbol_raw="";
      path="";
      description="";
      trade_mode=0;
      calc_mode=0;
      digits=0;
      point=0.0;
      tick_size=0.0;
      tick_value=0.0;
      tick_value_profit=0.0;
      tick_value_loss=0.0;
      contract_size=0.0;
      volume_min=0.0;
      volume_step=0.0;
      volume_max=0.0;
      stops_level=0;
      freeze_level=0;
      margin_currency="";
      profit_currency="";
      base_currency="";
      quote_currency="";
      session_property_availability=false;
      selection_state=false;
      sync_state=false;
      metadata_readable=false;
      quote_observable=false;
      synchronized_flag=false;
      history_addressable=false;
      trade_permitted=false;
      custom_symbol_flag=false;
      property_unavailable_flag=false;
      select_failed_temp=false;
      select_failed_perm=false;
      symbol_discovery_state="unknown";
      symbol_selection_state="unknown";
      symbol_synchronization_state="unknown";
      property_read_status="unknown";
      property_read_fail_mask=0;
      ZeroMemory(quote_tick_snapshot);
      quote_time=0;
      quote_last_seen=0;
      session_trade_windows=0;
      session_quote_windows=0;
     }
  };

struct ISSX_EA1_NormalizedIdentity
  {
   string                   symbol_norm;
   string                   canonical_root;
   string                   prefix_token;
   string                   suffix_token;
   string                   contract_token;
   string                   alias_family_id;
   string                   underlying_family_id;
   string                   market_representation_id;
   string                   execution_substitute_group_id;
   ISSX_RepresentationState representation_state;
   double                   representation_confidence;
   double                   family_resolution_confidence;
   int                      family_rep_stability_window;
   string                   family_published_rep;
   string                   family_best_now;
   bool                     execution_profile_distinct_flag;
   string                   representation_reason_codes;
   bool                     preferred_variant_flag;
   bool                     preferred_variant_locked;
   int                      preferred_variant_lock_age_cycles;
   string                   representative_switch_reason;
   double                   representative_switch_cost;
   double                   variant_flip_risk_score;
   double                   representation_stability_score;

   void Reset()
     {
      symbol_norm="";
      canonical_root="";
      prefix_token="";
      suffix_token="";
      contract_token="";
      alias_family_id="";
      underlying_family_id="";
      market_representation_id="";
      execution_substitute_group_id="";
      representation_state=issx_representation_unknown;
      representation_confidence=0.0;
      family_resolution_confidence=0.0;
      family_rep_stability_window=0;
      family_published_rep="";
      family_best_now="";
      execution_profile_distinct_flag=false;
      representation_reason_codes="none";
      preferred_variant_flag=false;
      preferred_variant_locked=false;
      preferred_variant_lock_age_cycles=0;
      representative_switch_reason="none";
      representative_switch_cost=0.0;
      variant_flip_risk_score=0.0;
      representation_stability_score=0.0;
     }
  };

struct ISSX_EA1_ValidatedRuntimeTruth
  {
   ISSX_ReadabilityState     readability_state;
   ISSX_UnknownReason        unknown_reason;
   bool                      declared_session_open;
   bool                      observed_quote_liveness;
   bool                      trade_permitted_now;
   bool                      quote_recent_flag;
   ISSX_PracticalMarketState practical_market_state;
   string                    practical_market_state_reason_codes;
   string                    session_reconciliation_state;
   double                    session_truth_confidence;
   int                       observation_samples_short;
   int                       observation_samples_medium;
   double                    observation_density_score;
   double                    observation_gap_risk;
   double                    market_sampling_quality_score;
   double                    spread_median_short_points;
   double                    spread_p90_short_points;
   double                    spread_widening_ratio;
   double                    quote_interval_median_ms;
   double                    quote_interval_p90_ms;
   double                    quote_stall_rate;
   double                    quote_burstiness_score;
   double                    current_vs_normal_spread_percentile;
   double                    current_vs_normal_quote_rate_percentile;
   double                    current_spread_points;
   double                    current_spread_money_per_lot;
   string                    current_friction_state;
   string                    spread_state_vs_baseline;
   string                    activity_transition_state;
   string                    liquidity_ramp_state;
   ISSX_EA1_SessionPhase     session_phase_class;
   int                       session_trade_windows;
   int                       session_quote_windows;
   bool                      property_zero_distinct_from_unavailable;
   bool                      synchronized_flag;
   bool                      history_addressable;
   bool                      selection_required_flag;
   double                    runtime_truth_score;
   ISSX_EA1_SessionPhase     session_phase;
   int                       minutes_since_session_open;
   int                       minutes_to_session_close;
   bool                      transition_penalty_active;

   void Reset()
     {
      readability_state=issx_readability_unknown;
      unknown_reason=issx_unknown_reason_unknown;
      declared_session_open=false;
      observed_quote_liveness=false;
      trade_permitted_now=false;
      quote_recent_flag=false;
      practical_market_state=issx_market_state_unknown;
      practical_market_state_reason_codes="unknown";
      session_reconciliation_state="unknown";
      session_truth_confidence=0.0;
      observation_samples_short=0;
      observation_samples_medium=0;
      observation_density_score=0.0;
      observation_gap_risk=1.0;
      market_sampling_quality_score=0.0;
      spread_median_short_points=0.0;
      spread_p90_short_points=0.0;
      spread_widening_ratio=0.0;
      quote_interval_median_ms=0.0;
      quote_interval_p90_ms=0.0;
      quote_stall_rate=1.0;
      quote_burstiness_score=0.0;
      current_vs_normal_spread_percentile=0.0;
      current_vs_normal_quote_rate_percentile=0.0;
      current_spread_points=0.0;
      current_spread_money_per_lot=0.0;
      current_friction_state="unknown";
      spread_state_vs_baseline="unknown";
      activity_transition_state="unknown";
      liquidity_ramp_state="unknown";
      session_phase_class=issx_ea1_session_unknown;
      session_trade_windows=0;
      session_quote_windows=0;
      property_zero_distinct_from_unavailable=false;
      synchronized_flag=false;
      history_addressable=false;
      selection_required_flag=false;
      runtime_truth_score=0.0;
      session_phase=issx_ea1_session_unknown;
      minutes_since_session_open=-1;
      minutes_to_session_close=-1;
      transition_penalty_active=false;
     }
  };

struct ISSX_EA1_ClassificationTruth
  {
   string                   asset_class;
   string                   instrument_family;
   string                   theme_bucket;
   string                   equity_sector;
   string                   leader_bucket_id;
   ISSX_LeaderBucketType    leader_bucket_type;
   string                   classification_source;
   double                   classification_confidence;
   double                   classification_reliability_score;
   string                   taxonomy_conflict_scope;
   ISSX_TaxonomyActionTaken taxonomy_action_taken;
   int                      taxonomy_revision;
   int                      bucket_assignment_stable_cycles;
   string                   bucket_assignment_change_reason;
   double                   taxonomy_change_severity;
   bool                     native_sector_present;
   bool                     native_industry_present;
   double                   native_taxonomy_quality;
   bool                     native_vs_manual_conflict;
   bool                     classification_hard_block;
   bool                     bucket_publishable;
   string                   taxonomy_hash;

   void Reset()
     {
      asset_class="unknown";
      instrument_family="unknown";
      theme_bucket="other";
      equity_sector="na";
      leader_bucket_id="other";
      leader_bucket_type=issx_leader_bucket_theme_bucket;
      classification_source="unknown";
      classification_confidence=0.0;
      classification_reliability_score=0.0;
      taxonomy_conflict_scope="none";
      taxonomy_action_taken=issx_taxonomy_manual_review_only;
      taxonomy_revision=0;
      bucket_assignment_stable_cycles=0;
      bucket_assignment_change_reason="none";
      taxonomy_change_severity=0.0;
      native_sector_present=false;
      native_industry_present=false;
      native_taxonomy_quality=0.0;
      native_vs_manual_conflict=false;
      classification_hard_block=false;
      bucket_publishable=false;
      taxonomy_hash="";
     }
  };

struct ISSX_EA1_TradeabilityBaseline
  {
   ISSX_TradeabilityClass tradeability_class;
   ISSX_CommissionState   commission_state;
   ISSX_SwapState         swap_state;
   double                 roundtrip_cost_points;
   double                 spread_cost_points;
   double                 commission_cost_money_per_lot;
   double                 commission_cost_points_equiv;
   double                 swap_long_money_per_lot;
   double                 swap_short_money_per_lot;
   double                 notional_tick_value_money;
   double                 minimum_ticket_money;
   bool                   blocked_for_trading;
   bool                   blocked_for_ranking;
   bool                   cost_complete;
   bool                   session_support_complete;
   bool                   tradeability_now_complete;
   double                 structural_tradeability_score;
   double                 live_tradeability_score;
   double                 blended_tradeability_score;
   double                 entry_cost_score;
   double                 size_practicality_score;
   double                 economic_consistency_score;
   double                 all_in_cost_confidence;
   double                 friction_quality_score;
   double                 spread_quality_score;
   double                 cost_quality_score;
   double                 fee_stability_score;
   double                 tradeability_penalty;
   string                 tradeability_reason_codes;
   string                 commission_reason_codes;
   string                 swap_reason_codes;
   string                 current_friction_state;
   string                 spread_state_vs_baseline;
   bool                   excessive_freeze_level_flag;
   bool                   excessive_stop_level_flag;

   void Reset()
     {
      tradeability_class=issx_tradeability_unknown;
      commission_state=issx_commission_unknown;
      swap_state=issx_swap_unknown;
      roundtrip_cost_points=0.0;
      spread_cost_points=0.0;
      commission_cost_money_per_lot=0.0;
      commission_cost_points_equiv=0.0;
      swap_long_money_per_lot=0.0;
      swap_short_money_per_lot=0.0;
      notional_tick_value_money=0.0;
      minimum_ticket_money=0.0;
      blocked_for_trading=false;
      blocked_for_ranking=false;
      cost_complete=false;
      session_support_complete=false;
      tradeability_now_complete=false;
      structural_tradeability_score=0.0;
      live_tradeability_score=0.0;
      blended_tradeability_score=0.0;
      entry_cost_score=0.0;
      size_practicality_score=0.0;
      economic_consistency_score=0.0;
      all_in_cost_confidence=0.0;
      friction_quality_score=0.0;
      spread_quality_score=0.0;
      cost_quality_score=0.0;
      fee_stability_score=0.0;
      tradeability_penalty=0.0;
      tradeability_reason_codes="unknown";
      commission_reason_codes="unknown";
      swap_reason_codes="unknown";
      current_friction_state="unknown";
      spread_state_vs_baseline="unknown";
      excessive_freeze_level_flag=false;
      excessive_stop_level_flag=false;
     }
  };

struct ISSX_EA1_RankabilityGate
  {
   bool                    eligible_flag;
   bool                    active_flag;
   bool                    rankable_flag;
   bool                    publishable_flag;
   bool                    hard_block_flag;
   bool                    exploratory_only_flag;
   bool                    compare_safe_degraded_flag;
   bool                    same_family_merged_away_flag;
   bool                    identity_ready;
   bool                    session_ready;
   bool                    market_ready;
   bool                    cost_ready;
   int                     acceptance_decision;
   string                  gate_reason_codes;
   string                  dependency_block_reason;
   double                  rankability_penalty;
   double                  readiness_score;
   double                  confidence_cap;
   int                     contradiction_count;
   ISSX_ContradictionClass highest_blocking_contradiction_class;

   void Reset()
  {
   eligible_flag=false;
   active_flag=false;
   rankable_flag=false;
   publishable_flag=false;
   hard_block_flag=false;
   exploratory_only_flag=false;
   compare_safe_degraded_flag=false;
   same_family_merged_away_flag=false;
   identity_ready=false;
   session_ready=false;
   market_ready=false;
   cost_ready=false;
   acceptance_decision=issx_acceptance_rejected;
   gate_reason_codes="unknown";
   dependency_block_reason="none";
   rankability_penalty=0.0;
   readiness_score=0.0;
   confidence_cap=0.0;
   contradiction_count=0;
   highest_blocking_contradiction_class=(ISSX_ContradictionClass)0;
  }
  };

struct ISSX_EA1_SymbolLifecycle
  {
   ISSX_EA1_AdmissionState      admission_state;
   ISSX_EA1_LifecycleState      lifecycle_state;
   ISSX_ContinuityOrigin        continuity_origin;
   bool                         resumed_from_persistence;
   int                          continuity_age_cycles;
   bool                         material_change_since_last_publish;
   ISSX_RepairState             repair_state;
   int                          retry_backoff_sec;
   datetime                     next_reprobe_time;
   int                          fault_streak;
   double                       fault_decay_score;
   ISSX_FailureEscalationClass  failure_escalation_class;
   bool                         forced_rebuild_required;
   string                       suspension_reason;
   string                       continuity_reason_codes;
   string                       owner_module_name;
   string                       owner_module_hash;

   void Reset()
     {
      admission_state=issx_ea1_admission_listed;
      lifecycle_state=issx_ea1_lifecycle_new;
      continuity_origin=issx_continuity_origin_unknown;
      resumed_from_persistence=false;
      continuity_age_cycles=0;
      material_change_since_last_publish=false;
      repair_state=issx_repair_none;
      retry_backoff_sec=0;
      next_reprobe_time=0;
      fault_streak=0;
      fault_decay_score=0.0;
      failure_escalation_class=issx_failure_escalation_unknown;
      forced_rebuild_required=false;
      suspension_reason="none";
      continuity_reason_codes="none";
      owner_module_name="issx_market_engine.mqh";
      owner_module_hash="";
     }
  };

struct ISSX_EA1_SymbolState
  {
   int                            symbol_id;
   ISSX_EA1_RawBrokerObservation  raw_broker_observation;
   ISSX_EA1_NormalizedIdentity    normalized_identity;
   ISSX_EA1_ValidatedRuntimeTruth validated_runtime_truth;
   ISSX_EA1_ClassificationTruth   classification_truth;
   ISSX_EA1_TradeabilityBaseline  tradeability_baseline;
   ISSX_EA1_RankabilityGate       rankability_gate;
   ISSX_EA1_SymbolLifecycle       symbol_lifecycle;
   string                         symbol_fingerprint;
   bool                           changed_since_last_cycle;
   bool                           changed_since_last_publish;
   bool                           touched_this_cycle;

   void Reset()
     {
      symbol_id=-1;
      raw_broker_observation.Reset();
      normalized_identity.Reset();
      validated_runtime_truth.Reset();
      classification_truth.Reset();
      tradeability_baseline.Reset();
      rankability_gate.Reset();
      symbol_lifecycle.Reset();
      symbol_fingerprint="";
      changed_since_last_cycle=false;
      changed_since_last_publish=false;
      touched_this_cycle=false;
     }
  };

struct ISSX_EA1_UniverseState
  {
   int    broker_universe;
   int    eligible_universe;
   int    active_universe;
   int    rankable_universe;
   int    frontier_hint_universe;
   int    publishable_universe;
   string broker_universe_fingerprint;
   string eligible_universe_fingerprint;
   string active_universe_fingerprint;
   string rankable_universe_fingerprint;
   string frontier_universe_fingerprint;
   string publishable_universe_fingerprint;
   double percent_universe_touched_recent;
   double percent_rankable_revalidated_recent;
   double percent_frontier_revalidated_recent;
   int    never_serviced_count;
   int    overdue_service_count;
   int    never_ranked_but_eligible_count;
   int    newly_active_symbols_waiting_count;
   int    near_cutline_recheck_age_max;

   void Reset()
     {
      broker_universe=0;
      eligible_universe=0;
      active_universe=0;
      rankable_universe=0;
      frontier_hint_universe=0;
      publishable_universe=0;
      broker_universe_fingerprint="";
      eligible_universe_fingerprint="";
      active_universe_fingerprint="";
      rankable_universe_fingerprint="";
      frontier_universe_fingerprint="";
      publishable_universe_fingerprint="";
      percent_universe_touched_recent=0.0;
      percent_rankable_revalidated_recent=0.0;
      percent_frontier_revalidated_recent=0.0;
      never_serviced_count=0;
      overdue_service_count=0;
      never_ranked_but_eligible_count=0;
      newly_active_symbols_waiting_count=0;
      near_cutline_recheck_age_max=0;
     }
  };

struct ISSX_EA1_DeltaState
  {
   int    changed_symbol_count;
   string changed_symbol_ids_compact;
   int    changed_family_count;
   int    changed_bucket_count;

   void Reset()
     {
      changed_symbol_count=0;
      changed_symbol_ids_compact="";
      changed_family_count=0;
      changed_bucket_count=0;
     }
  };

struct ISSX_EA1_CycleCounters
  {
   int listed_count;
   int metadata_ready_count;
   int probe_ready_count;
   int rank_candidate_count;
   int degraded_count;
   int blocked_count;
   int contradiction_count;
   int contradiction_severity_max;
   int changed_symbol_count;
   int accepted_strong_count;
   int accepted_degraded_count;
   int rejected_count;
   int cooldown_count;
   int stale_usable_count;

   void Reset()
     {
      listed_count=0;
      metadata_ready_count=0;
      probe_ready_count=0;
      rank_candidate_count=0;
      degraded_count=0;
      blocked_count=0;
      contradiction_count=0;
      contradiction_severity_max=0;
      changed_symbol_count=0;
      accepted_strong_count=0;
      accepted_degraded_count=0;
      rejected_count=0;
      cooldown_count=0;
      stale_usable_count=0;
     }
  };

struct ISSX_EA1_State
  {
   ISSX_EA1_SymbolState     symbols[];
   ISSX_EA1_UniverseState   universe;
   ISSX_EA1_DeltaState      deltas;
   ISSX_EA1_CycleCounters   counters;
   ISSX_RuntimeState        runtime_stats;
   ISSX_PhaseSchedulerState scheduler;
   ISSX_RuntimeBudgets      runtime_budget;
   int                      minute_id;
   int                      sequence_no;
   string                   taxonomy_hash;
   string                   comparator_registry_hash;
   string                   cohort_fingerprint;
   string                   policy_fingerprint;
   string                   fingerprint_algorithm_version;
   bool                     degraded_flag;
   bool                     publishable;
   bool                     resumed_from_persistence;
   int                      dump_sequence_no;
   int                      dump_minute_id;
   int                      discovery_minute_id;
   bool                     discovery_attempted;
   bool                     discovery_skipped;
   bool                     discovery_success;
   bool                     discovery_no_change;
   int                      discovery_elapsed_ms;
   int                      discovery_skip_streak;
   string                   discovery_status_reason;
   bool                     stage_minimum_ready_flag;
   string                   stage_publishability_state;
   string                   dependency_block_reason;
   string                   debug_weak_link_code;
   bool                     deterministic_sort_applied;
   int                      deterministic_sorted_count;
   string                   deterministic_sort_basis;

   void Reset()
     {
      ArrayResize(symbols,0);
      universe.Reset();
      deltas.Reset();
      counters.Reset();
      runtime_stats.Reset();
      scheduler.Reset();
      runtime_budget.Reset();
      minute_id=0;
      sequence_no=0;
      taxonomy_hash="";
      comparator_registry_hash="";
      cohort_fingerprint="";
      policy_fingerprint="";
      fingerprint_algorithm_version="sha256_hex_v1";
      degraded_flag=false;
      publishable=false;
      resumed_from_persistence=false;
      dump_sequence_no=0;
      dump_minute_id=0;
      discovery_minute_id=-1;
      discovery_attempted=false;
      discovery_skipped=false;
      discovery_success=false;
      discovery_no_change=false;
      discovery_elapsed_ms=0;
      discovery_skip_streak=0;
      discovery_status_reason="none";
      stage_minimum_ready_flag=false;
      stage_publishability_state="not_ready";
      dependency_block_reason="none";
      debug_weak_link_code="none";
      deterministic_sort_applied=false;
      deterministic_sorted_count=0;
      deterministic_sort_basis="none";
     }
  };

// ============================================================================
// SECTION 04: TAXONOMY
// ============================================================================

class ISSX_MarketTaxonomy
  {
private:
   static bool ContainsLower(const string haystack,const string needle)
     {
      string h=haystack;
      string n=needle;
      StringToLower(h);
      StringToLower(n);
      return (StringFind(h,n)>=0);
     }

   static string Normalize(const string s)
     {
      string r=s;
      StringTrimLeft(r);
      StringTrimRight(r);
      StringToLower(r);
      StringReplace(r,"."," ");
      StringReplace(r,"_"," ");
      StringReplace(r,"-"," ");
      while(StringFind(r,"  ")>=0)
         StringReplace(r,"  "," ");
      return r;
     }

   static void SetTheme(ISSX_EA1_ClassificationTruth &out_cls,
                        const string asset_class,
                        const string family,
                        const string bucket,
                        const string sector,
                        const ISSX_LeaderBucketType bucket_type,
                        const double confidence,
                        const string source)
     {
      out_cls.asset_class=asset_class;
      out_cls.instrument_family=family;
      out_cls.theme_bucket=bucket;
      out_cls.equity_sector=sector;
      out_cls.leader_bucket_id=(bucket_type==issx_leader_bucket_equity_sector ? sector : bucket);
      out_cls.leader_bucket_type=bucket_type;
      out_cls.classification_confidence=confidence;
      out_cls.classification_reliability_score=confidence;
      out_cls.classification_source=source;
      out_cls.bucket_publishable=(bucket!="other" || sector!="na");
      out_cls.taxonomy_action_taken=(confidence>=0.60 ? issx_taxonomy_accepted : issx_taxonomy_theme_downgrade);
      out_cls.classification_hard_block=false;
     }
   static void CopySymbolStateArray(const ISSX_EA1_SymbolState &src[],ISSX_EA1_SymbolState &dst[])
     {
      const int n=ArraySize(src);
      ArrayResize(dst,n);
      for(int i=0;i<n;i++)
         dst[i]=src[i];
     }
public:
   static void Classify(const string raw_symbol,
                        const string normalized_symbol,
                        const string canonical_root,
                        const string description,
                        const string path,
                        ISSX_EA1_ClassificationTruth &out_cls)
     {
      out_cls.Reset();

      string blob=Normalize(raw_symbol+" "+normalized_symbol+" "+canonical_root+" "+description+" "+path);

      if(ContainsLower(blob,"xau") || ContainsLower(blob,"gold"))
        {
         SetTheme(out_cls,"commodity","metal","metals","na",issx_leader_bucket_theme_bucket,0.95,"rule_metal");
         return;
        }

      if(ContainsLower(blob,"xag") || ContainsLower(blob,"silver"))
        {
         SetTheme(out_cls,"commodity","metal","metals","na",issx_leader_bucket_theme_bucket,0.93,"rule_metal");
         return;
        }

      if(ContainsLower(blob,"us30") || ContainsLower(blob,"dow") || ContainsLower(blob,"wall street"))
        {
         SetTheme(out_cls,"index","equity_index","indices","na",issx_leader_bucket_theme_bucket,0.92,"rule_index");
         return;
        }

      if(ContainsLower(blob,"nas100") || ContainsLower(blob,"nasdaq") || ContainsLower(blob,"ustec"))
        {
         SetTheme(out_cls,"index","equity_index","indices","na",issx_leader_bucket_theme_bucket,0.92,"rule_index");
         return;
        }

      if(ContainsLower(blob,"spx") || ContainsLower(blob,"sp500") || ContainsLower(blob,"us500"))
        {
         SetTheme(out_cls,"index","equity_index","indices","na",issx_leader_bucket_theme_bucket,0.92,"rule_index");
         return;
        }

      if(ContainsLower(blob,"ger40") || ContainsLower(blob,"dax"))
        {
         SetTheme(out_cls,"index","equity_index","indices","na",issx_leader_bucket_theme_bucket,0.89,"rule_index");
         return;
        }

      if(ContainsLower(blob,"uk100") || ContainsLower(blob,"ftse"))
        {
         SetTheme(out_cls,"index","equity_index","indices","na",issx_leader_bucket_theme_bucket,0.88,"rule_index");
         return;
        }

      if(ContainsLower(blob,"nikkei") || ContainsLower(blob,"jp225"))
        {
         SetTheme(out_cls,"index","equity_index","indices","na",issx_leader_bucket_theme_bucket,0.88,"rule_index");
         return;
        }

      if(ContainsLower(blob,"btc") || ContainsLower(blob,"bitcoin"))
        {
         SetTheme(out_cls,"crypto","crypto_spot","crypto","na",issx_leader_bucket_theme_bucket,0.95,"rule_crypto");
         return;
        }

      if(ContainsLower(blob,"eth") || ContainsLower(blob,"ethereum"))
        {
         SetTheme(out_cls,"crypto","crypto_spot","crypto","na",issx_leader_bucket_theme_bucket,0.92,"rule_crypto");
         return;
        }

      if(ContainsLower(blob,"brent") || ContainsLower(blob,"ukoil") || ContainsLower(blob,"xbrusd"))
        {
         SetTheme(out_cls,"commodity","energy","energy","na",issx_leader_bucket_theme_bucket,0.90,"rule_energy");
         return;
        }

      if(ContainsLower(blob,"wti") || ContainsLower(blob,"usoil") || ContainsLower(blob,"xtiusd"))
        {
         SetTheme(out_cls,"commodity","energy","energy","na",issx_leader_bucket_theme_bucket,0.90,"rule_energy");
         return;
        }

      if(ContainsLower(blob,"jpn225") || ContainsLower(blob,"hk50") || ContainsLower(blob,"china") || ContainsLower(blob,"hsi"))
        {
         SetTheme(out_cls,"index","equity_index","indices","na",issx_leader_bucket_theme_bucket,0.84,"rule_index");
         return;
        }

      string s=normalized_symbol;
      StringToUpper(s);
      if(StringLen(s)>=6)
        {
         string a=StringSubstr(s,0,3);
         string b=StringSubstr(s,3,3);

         bool a_ok=(a=="EUR" || a=="USD" || a=="GBP" || a=="JPY" || a=="AUD" || a=="NZD" || a=="CAD" || a=="CHF" || a=="NOK" || a=="SEK" || a=="SGD" || a=="HKD" || a=="ZAR");
         bool b_ok=(b=="EUR" || b=="USD" || b=="GBP" || b=="JPY" || b=="AUD" || b=="NZD" || b=="CAD" || b=="CHF" || b=="NOK" || b=="SEK" || b=="SGD" || b=="HKD" || b=="ZAR");

         if(a_ok && b_ok)
           {
            SetTheme(out_cls,"fx","spot_fx","fx","na",issx_leader_bucket_theme_bucket,0.86,"rule_fx");
            return;
           }
        }

      out_cls.asset_class="unknown";
      out_cls.instrument_family="unknown";
      out_cls.theme_bucket="other";
      out_cls.equity_sector="na";
      out_cls.leader_bucket_id="other";
      out_cls.leader_bucket_type=issx_leader_bucket_theme_bucket;
      out_cls.classification_source="fallback_other";
      out_cls.classification_confidence=0.30;
      out_cls.classification_reliability_score=0.30;
      out_cls.taxonomy_action_taken=issx_taxonomy_theme_downgrade;
      out_cls.bucket_publishable=false;
      out_cls.classification_hard_block=false;
     }
  };

// ============================================================================
// SECTION 05: MARKET ENGINE
// ============================================================================

int g_ea1_last_discovery_minute=-1;
int g_ea1_last_skip_log_minute=-1;
bool g_ea1_last_discovery_attempted=false;
bool g_ea1_last_discovery_skipped=false;
bool g_ea1_last_discovery_no_change=false;
int g_ea1_last_discovery_symbols=0;
long g_ea1_last_discovery_elapsed_ms=0;
string g_ea1_last_discovery_error="";

class ISSX_MarketEngine
  {
private:
   static int m_last_discovery_minute;

   static string SafeUpper(const string s)
     {
      string r=s;
      StringTrimLeft(r);
      StringTrimRight(r);
      StringToUpper(r);
      return r;
     }

   static string NormalizeSymbol(const string symbol)
     {
      string s=SafeUpper(symbol);

      int len=(int)StringLen(s);
      while(len>0)
        {
         ushort ch=(ushort)StringGetCharacter(s,len-1);
         bool keep_alpha_num=((ch>='A' && ch<='Z') || (ch>='0' && ch<='9'));
         if(keep_alpha_num)
            break;
         s=StringSubstr(s,0,len-1);
         len=(int)StringLen(s);
        }

      string suffixes[]={"MICRO","MINI","PRO","RAW","ECN","STD","CASH","SPOT","PLUS","NX","A","M","I","P"};
      for(int i=0;i<ArraySize(suffixes);i++)
        {
         string sf=suffixes[i];
         int slen=(int)StringLen(sf);
         if(StringLen(s)>slen && StringSubstr(s,StringLen(s)-slen)==sf)
           {
            string candidate=StringSubstr(s,0,StringLen(s)-slen);
            if(StringLen(candidate)>=6)
              {
               s=candidate;
               break;
              }
           }
        }

      return s;
     }

   static bool SafeSymbolBool(const string symbol,const ENUM_SYMBOL_INFO_INTEGER prop)
     {
      long v=0;
      if(!SymbolInfoInteger(symbol,prop,v))
         return false;
      return (v!=0);
     }

   static long SafeSymbolLong(const string symbol,const ENUM_SYMBOL_INFO_INTEGER prop,const long fallback=0)
     {
      long v=0;
      if(!SymbolInfoInteger(symbol,prop,v))
         return fallback;
      return v;
     }

   static int SafeSymbolInt(const string symbol,const ENUM_SYMBOL_INFO_INTEGER prop,const int fallback=0)
     {
      long v=0;
      if(!SymbolInfoInteger(symbol,prop,v))
         return fallback;
      return (int)v;
     }

   static double SafeSymbolDouble(const string symbol,const ENUM_SYMBOL_INFO_DOUBLE prop,const double fallback=0.0)
     {
      double v=0.0;
      if(!SymbolInfoDouble(symbol,prop,v))
         return fallback;
      return v;
     }

   static string SafeSymbolString(const string symbol,const ENUM_SYMBOL_INFO_STRING prop,const string fallback="")
     {
      string v="";
      if(!SymbolInfoString(symbol,prop,v))
         return fallback;
      return v;
     }

   static bool RefreshTick(const string symbol,MqlTick &tick)
     {
      ZeroMemory(tick);
      if(SymbolInfoTick(symbol,tick))
         return true;
      return false;
     }

   static string JoinReason(const string a,const string b)
     {
      if(a=="" || a=="none" || a=="unknown")
         return b;
      if(b=="" || b=="none" || b=="unknown")
         return a;
      if(StringFind(a,b)>=0)
         return a;
      return a+"|"+b;
     }

   static string HashString(const string s)
     {
      return ISSX_Hash::HashStringHex(s);
     }

   static string FingerprintArray(const string &items[])
     {
      string data="";
      int n=ArraySize(items);
      for(int i=0;i<n;i++)
        {
         if(i>0)
            data+="|";
         data+=items[i];
        }
      return HashString(data);
     }

   static void PushString(string &arr[],const string value)
     {
      int n=ArraySize(arr);
      ArrayResize(arr,n+1);
      arr[n]=value;
     }

   static string CompactChangedIds(const ISSX_EA1_SymbolState &symbols[])
     {
      string ids="";
      for(int i=0;i<ArraySize(symbols);i++)
        {
         if(!symbols[i].changed_since_last_cycle)
            continue;
         if(ids!="")
            ids+=",";
         ids+=IntegerToString(symbols[i].symbol_id);
        }
      if(ids=="")
         ids="none";
      return ids;
     }

   static void CopySymbolStateArray(const ISSX_EA1_SymbolState &src[],ISSX_EA1_SymbolState &dst[])
     {
      const int n=ArraySize(src);
      ArrayResize(dst,n);
      for(int i=0;i<n;i++)
         dst[i]=src[i];
     }

   static int FindPriorSymbolIndex(const ISSX_EA1_SymbolState &prior_symbols[],const string symbol)
     {
      for(int i=0;i<ArraySize(prior_symbols);i++)
         if(prior_symbols[i].raw_broker_observation.symbol_raw==symbol)
            return i;
      return -1;
     }

   static void RestorePriorContinuity(const ISSX_EA1_SymbolState &prior,ISSX_EA1_SymbolState &dst)
     {
      dst.symbol_lifecycle=prior.symbol_lifecycle;
      dst.normalized_identity.family_published_rep=prior.normalized_identity.family_published_rep;
      dst.normalized_identity.family_rep_stability_window=prior.normalized_identity.family_rep_stability_window;
      dst.normalized_identity.preferred_variant_locked=prior.normalized_identity.preferred_variant_locked;
      dst.normalized_identity.preferred_variant_lock_age_cycles=prior.normalized_identity.preferred_variant_lock_age_cycles;
      dst.changed_since_last_cycle=false;
      dst.changed_since_last_publish=false;
      dst.symbol_lifecycle.resumed_from_persistence=true;
      dst.symbol_lifecycle.continuity_origin=issx_continuity_resumed_current;
      dst.symbol_lifecycle.continuity_age_cycles=prior.symbol_lifecycle.continuity_age_cycles;
     }

   static void LoadRawObservation(const string symbol,ISSX_EA1_RawBrokerObservation &out_obs)
     {
      out_obs.Reset();
      out_obs.symbol_raw=symbol;
      out_obs.path=SafeSymbolString(symbol,SYMBOL_PATH,"");
      out_obs.description=SafeSymbolString(symbol,SYMBOL_DESCRIPTION,"");
      out_obs.trade_mode=SafeSymbolLong(symbol,SYMBOL_TRADE_MODE,0);
      out_obs.calc_mode=SafeSymbolLong(symbol,SYMBOL_TRADE_CALC_MODE,0);
      out_obs.digits=SafeSymbolInt(symbol,SYMBOL_DIGITS,0);
      out_obs.point=SafeSymbolDouble(symbol,SYMBOL_POINT,0.0);
      out_obs.tick_size=SafeSymbolDouble(symbol,SYMBOL_TRADE_TICK_SIZE,0.0);
      out_obs.tick_value=SafeSymbolDouble(symbol,SYMBOL_TRADE_TICK_VALUE,0.0);
      out_obs.tick_value_profit=SafeSymbolDouble(symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT,0.0);
      out_obs.tick_value_loss=SafeSymbolDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS,0.0);
      out_obs.contract_size=SafeSymbolDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE,0.0);
      out_obs.volume_min=SafeSymbolDouble(symbol,SYMBOL_VOLUME_MIN,0.0);
      out_obs.volume_step=SafeSymbolDouble(symbol,SYMBOL_VOLUME_STEP,0.0);
      out_obs.volume_max=SafeSymbolDouble(symbol,SYMBOL_VOLUME_MAX,0.0);
      out_obs.stops_level=SafeSymbolInt(symbol,SYMBOL_TRADE_STOPS_LEVEL,0);
      out_obs.freeze_level=SafeSymbolInt(symbol,SYMBOL_TRADE_FREEZE_LEVEL,0);
      out_obs.margin_currency=SafeSymbolString(symbol,SYMBOL_CURRENCY_MARGIN,"");
      out_obs.profit_currency=SafeSymbolString(symbol,SYMBOL_CURRENCY_PROFIT,"");
      out_obs.base_currency=SafeSymbolString(symbol,SYMBOL_CURRENCY_BASE,"");
      out_obs.quote_currency=SafeSymbolString(symbol,SYMBOL_CURRENCY_PROFIT,"");
      out_obs.selection_state=SafeSymbolBool(symbol,SYMBOL_SELECT);
      out_obs.sync_state=SafeSymbolBool(symbol,SYMBOL_VISIBLE);
      out_obs.metadata_readable=(out_obs.digits>0 || out_obs.point>0.0 || out_obs.contract_size>0.0 || out_obs.volume_min>0.0);
      out_obs.trade_permitted=(out_obs.trade_mode!=0);
      out_obs.custom_symbol_flag=SafeSymbolBool(symbol,SYMBOL_CUSTOM);
      out_obs.synchronized_flag=SafeSymbolBool(symbol,SYMBOL_SELECT);
      out_obs.history_addressable=true;
      out_obs.property_unavailable_flag=!out_obs.metadata_readable;
      out_obs.select_failed_temp=false;
      out_obs.select_failed_perm=false;
      out_obs.symbol_discovery_state="discovered";
      out_obs.symbol_selection_state=(out_obs.selection_state ? "selected" : "not_selected");
      out_obs.symbol_synchronization_state=(out_obs.sync_state ? "synchronized" : "unsynchronized");
      out_obs.property_read_status=(out_obs.metadata_readable ? "metadata_readable" : "property_unavailable");
      out_obs.property_read_fail_mask=(out_obs.metadata_readable ? 0 : 1);
      out_obs.session_property_availability=true;
      out_obs.session_trade_windows=0;
      out_obs.session_quote_windows=0;

      MqlTick tick;
      if(RefreshTick(symbol,tick))
        {
         out_obs.quote_tick_snapshot=tick;
         out_obs.quote_time=(datetime)tick.time;
         out_obs.quote_last_seen=(datetime)tick.time;
         out_obs.quote_observable=true;
        }
      else
        {
         ZeroMemory(out_obs.quote_tick_snapshot);
         out_obs.quote_time=0;
         out_obs.quote_last_seen=0;
         out_obs.quote_observable=false;
        }
     }

   static void NormalizeIdentity(const ISSX_EA1_RawBrokerObservation &obs,ISSX_EA1_NormalizedIdentity &out_id)
     {
      out_id.Reset();

      string norm=NormalizeSymbol(obs.symbol_raw);
      out_id.symbol_norm=norm;
      out_id.canonical_root=norm;
      out_id.alias_family_id=norm;
      out_id.underlying_family_id=norm;
      out_id.market_representation_id=norm;
      out_id.execution_substitute_group_id=norm;
      out_id.representation_state=issx_representation_canonical;
      out_id.representation_confidence=0.85;
      out_id.family_resolution_confidence=0.80;
      out_id.family_rep_stability_window=1;
      out_id.family_published_rep=obs.symbol_raw;
      out_id.family_best_now=obs.symbol_raw;
      out_id.representation_reason_codes="exact_root";

      int len=(int)StringLen(obs.symbol_raw);
      int j=0;
      while(j<len && !((StringGetCharacter(obs.symbol_raw,j)>='A' && StringGetCharacter(obs.symbol_raw,j)<='Z') || (StringGetCharacter(obs.symbol_raw,j)>='a' && StringGetCharacter(obs.symbol_raw,j)<='z')))
         j++;
      if(j>0)
        {
         out_id.prefix_token=StringSubstr(obs.symbol_raw,0,j);
         out_id.representation_reason_codes=JoinReason(out_id.representation_reason_codes,"prefix_variant");
        }

      int tail=len-1;
      while(tail>=0 && !((StringGetCharacter(obs.symbol_raw,tail)>='A' && StringGetCharacter(obs.symbol_raw,tail)<='Z') || (StringGetCharacter(obs.symbol_raw,tail)>='a' && StringGetCharacter(obs.symbol_raw,tail)<='z') || (StringGetCharacter(obs.symbol_raw,tail)>='0' && StringGetCharacter(obs.symbol_raw,tail)<='9')))
         tail--;
      if(tail<len-1)
        {
         out_id.suffix_token=StringSubstr(obs.symbol_raw,tail+1);
         out_id.representation_reason_codes=JoinReason(out_id.representation_reason_codes,"suffix_variant");
        }

      out_id.preferred_variant_flag=true;
      out_id.preferred_variant_locked=true;
      out_id.preferred_variant_lock_age_cycles=1;
      out_id.representation_stability_score=0.80;
     }

   static string SessionPhaseText(const ISSX_EA1_SessionPhase phase)
     {
      switch(phase)
        {
         case issx_ea1_session_closed:   return "closed";
         case issx_ea1_session_pre_open: return "pre_open";
         case issx_ea1_session_open:     return "open";
         case issx_ea1_session_mid:      return "mid";
         case issx_ea1_session_late:     return "late";
         case issx_ea1_session_rollover: return "rollover";
         default:                        return "unknown";
        }
     }

   static void BuildRuntimeTruth(const ISSX_EA1_RawBrokerObservation &obs,ISSX_EA1_ValidatedRuntimeTruth &out_rt)
     {
      out_rt.Reset();

      out_rt.readability_state=(obs.metadata_readable ? issx_readability_full : issx_readability_unreadable);
      out_rt.unknown_reason=(obs.metadata_readable ? issx_unknown_not_applicable : issx_unknown_true_unknown);
      out_rt.declared_session_open=obs.trade_permitted;
      out_rt.observed_quote_liveness=obs.quote_observable;
      out_rt.trade_permitted_now=obs.trade_permitted;
      out_rt.quote_recent_flag=(obs.quote_last_seen>0 && (TimeCurrent()-obs.quote_last_seen)<=120);
      out_rt.synchronized_flag=obs.synchronized_flag;
      out_rt.history_addressable=obs.history_addressable;
      out_rt.selection_required_flag=!obs.selection_state;
      out_rt.property_zero_distinct_from_unavailable=(obs.property_unavailable_flag && obs.point==0.0);

      if(!obs.metadata_readable)
        {
         out_rt.practical_market_state=issx_market_blocked;
         out_rt.practical_market_state_reason_codes="spec_incomplete";
         out_rt.current_friction_state="unknown";
         out_rt.spread_state_vs_baseline="unknown";
         out_rt.activity_transition_state="unknown";
         out_rt.liquidity_ramp_state="unknown";
         out_rt.session_reconciliation_state="declared_only";
         out_rt.session_phase_class=issx_ea1_session_unknown;
         return;
        }

      if(obs.quote_observable)
        {
         double bid=obs.quote_tick_snapshot.bid;
         double ask=obs.quote_tick_snapshot.ask;
         double point=(obs.point>0.0 ? obs.point : 0.00001);
         out_rt.current_spread_points=((ask>bid && point>0.0) ? ((ask-bid)/point) : 0.0);
         out_rt.spread_median_short_points=out_rt.current_spread_points;
         out_rt.spread_p90_short_points=out_rt.current_spread_points*1.20;
         out_rt.spread_widening_ratio=1.0;
         out_rt.quote_interval_median_ms=1000.0;
         out_rt.quote_interval_p90_ms=5000.0;
         out_rt.quote_stall_rate=(out_rt.quote_recent_flag ? 0.0 : 1.0);
         out_rt.quote_burstiness_score=(out_rt.quote_recent_flag ? 0.70 : 0.10);
         out_rt.observation_samples_short=1;
         out_rt.observation_samples_medium=1;
         out_rt.observation_density_score=(out_rt.quote_recent_flag ? 0.75 : 0.25);
         out_rt.observation_gap_risk=(out_rt.quote_recent_flag ? 0.15 : 0.85);
         out_rt.market_sampling_quality_score=(out_rt.quote_recent_flag ? 0.80 : 0.35);
         out_rt.current_vs_normal_spread_percentile=0.50;
         out_rt.current_vs_normal_quote_rate_percentile=(out_rt.quote_recent_flag ? 0.70 : 0.20);
         out_rt.current_friction_state=(out_rt.current_spread_points<=20.0 ? "normal" : "elevated");
         out_rt.spread_state_vs_baseline=(out_rt.current_spread_points<=20.0 ? "at_or_below_baseline" : "above_baseline");
         out_rt.activity_transition_state=(out_rt.quote_recent_flag ? "active" : "cooling");
         out_rt.liquidity_ramp_state=(out_rt.quote_recent_flag ? "supported" : "thin");
         out_rt.session_truth_confidence=(out_rt.quote_recent_flag ? 0.80 : 0.45);
         out_rt.session_phase_class=(out_rt.quote_recent_flag ? issx_ea1_session_open : issx_ea1_session_closed);
         out_rt.session_reconciliation_state=(obs.trade_permitted ? "observed_supported" : "contradictory");

         if(obs.trade_permitted && out_rt.quote_recent_flag)
            out_rt.practical_market_state=issx_market_open_usable;
         else if(obs.trade_permitted)
            out_rt.practical_market_state=issx_market_open_cautious;
         else
            out_rt.practical_market_state=issx_market_quote_only;
        }
      else
        {
         out_rt.observation_density_score=0.0;
         out_rt.observation_gap_risk=1.0;
         out_rt.market_sampling_quality_score=0.0;
         out_rt.session_truth_confidence=(obs.trade_permitted ? 0.35 : 0.80);
         out_rt.session_phase_class=(obs.trade_permitted ? issx_ea1_session_pre_open : issx_ea1_session_closed);
         out_rt.session_reconciliation_state=(obs.trade_permitted ? "declared_only" : "observed_supported");
         out_rt.current_friction_state="unknown";
         out_rt.spread_state_vs_baseline="unknown";
         out_rt.activity_transition_state="dormant";
         out_rt.liquidity_ramp_state="thin";
         out_rt.practical_market_state=(obs.trade_permitted ? issx_market_open_cautious : issx_market_closed_idle);
        }

      string reasons="none";
      if(!obs.trade_permitted)
         reasons=JoinReason(reasons,"trade_disabled");
      if(!out_rt.quote_recent_flag)
         reasons=JoinReason(reasons,"quote_old");
      if(obs.property_unavailable_flag)
         reasons=JoinReason(reasons,"spec_incomplete");
      if(out_rt.selection_required_flag)
         reasons=JoinReason(reasons,"selection_required");
      out_rt.practical_market_state_reason_codes=reasons;
      out_rt.current_spread_money_per_lot=obs.tick_value*out_rt.current_spread_points;
      out_rt.session_trade_windows=obs.session_trade_windows;
      out_rt.session_quote_windows=obs.session_quote_windows;
      out_rt.session_phase=out_rt.session_phase_class;
      out_rt.transition_penalty_active=(out_rt.session_phase_class==issx_ea1_session_pre_open
                                        || out_rt.session_phase_class==issx_ea1_session_rollover);
      if(out_rt.session_phase_class==issx_ea1_session_open)
        {
         out_rt.minutes_since_session_open=0;
         out_rt.minutes_to_session_close=0;
        }
      else
        {
         out_rt.minutes_since_session_open=-1;
         out_rt.minutes_to_session_close=-1;
        }
      out_rt.runtime_truth_score=MathMax(0.0,MathMin(1.0,
                                0.45*out_rt.session_truth_confidence
                              + 0.35*out_rt.observation_density_score
                              + 0.20*out_rt.market_sampling_quality_score));
     }

   static void BuildTradeability(const ISSX_EA1_RawBrokerObservation &obs,
                                 const ISSX_EA1_ValidatedRuntimeTruth &rt,
                                 ISSX_EA1_TradeabilityBaseline &out_tb)
     {
      out_tb.Reset();

      double point=(obs.point>0.0 ? obs.point : 0.00001);
      double spread_points=rt.current_spread_points;
      double tick_size=(obs.tick_size>0.0 ? obs.tick_size : point);
      double tick_value=(obs.tick_value>0.0 ? obs.tick_value : obs.tick_value_profit);
      if(tick_value<=0.0)
         tick_value=obs.tick_value_loss;

      out_tb.spread_cost_points=spread_points;
      out_tb.commission_cost_money_per_lot=0.0;
      out_tb.commission_cost_points_equiv=0.0;
      out_tb.swap_long_money_per_lot=0.0;
      out_tb.swap_short_money_per_lot=0.0;
      out_tb.notional_tick_value_money=tick_value;
      out_tb.minimum_ticket_money=(obs.volume_min>0.0 ? obs.volume_min : 0.01) * MathMax(1.0,tick_value);
      out_tb.excessive_freeze_level_flag=(obs.freeze_level>50);
      out_tb.excessive_stop_level_flag=(obs.stops_level>50);
      out_tb.current_friction_state=rt.current_friction_state;
      out_tb.spread_state_vs_baseline=rt.spread_state_vs_baseline;

      if(!obs.metadata_readable)
        {
         out_tb.tradeability_class=issx_tradeability_blocked;
         out_tb.blocked_for_trading=true;
         out_tb.blocked_for_ranking=true;
         out_tb.tradeability_penalty=1.0;
         out_tb.tradeability_reason_codes="spec_incomplete";
         return;
        }

      if(tick_size>0.0 && tick_value>0.0)
        {
         out_tb.roundtrip_cost_points=spread_points;
         out_tb.cost_complete=true;
         out_tb.commission_state=issx_commission_known_zero;
         out_tb.swap_state=issx_swap_known_zero;
        }
      else
        {
         out_tb.roundtrip_cost_points=spread_points;
         out_tb.cost_complete=false;
         out_tb.commission_state=issx_commission_unknown;
         out_tb.swap_state=issx_swap_unknown;
        }

      out_tb.session_support_complete=true;
      out_tb.tradeability_now_complete=(rt.practical_market_state!=issx_market_state_unknown);

      if(!obs.trade_permitted || rt.practical_market_state==issx_market_blocked)
        {
         out_tb.tradeability_class=issx_tradeability_blocked;
         out_tb.blocked_for_trading=true;
         out_tb.blocked_for_ranking=true;
         out_tb.tradeability_penalty=1.0;
         out_tb.tradeability_reason_codes="trade_disabled";
        }
      else if(spread_points<=8.0)
        {
         out_tb.tradeability_class=issx_tradeability_very_cheap;
         out_tb.tradeability_penalty=0.0;
         out_tb.tradeability_reason_codes="very_cheap";
        }
      else if(spread_points<=15.0)
        {
         out_tb.tradeability_class=issx_tradeability_cheap;
         out_tb.tradeability_penalty=0.10;
         out_tb.tradeability_reason_codes="cheap";
        }
      else if(spread_points<=35.0)
        {
         out_tb.tradeability_class=issx_tradeability_moderate;
         out_tb.tradeability_penalty=0.30;
         out_tb.tradeability_reason_codes="moderate";
        }
      else
        {
         out_tb.tradeability_class=issx_tradeability_expensive;
         out_tb.tradeability_penalty=0.65;
         out_tb.tradeability_reason_codes="expensive";
        }

      out_tb.friction_quality_score=(out_tb.tradeability_class==issx_tradeability_very_cheap ? 1.00 :
                                     out_tb.tradeability_class==issx_tradeability_cheap      ? 0.80 :
                                     out_tb.tradeability_class==issx_tradeability_moderate   ? 0.55 :
                                     out_tb.tradeability_class==issx_tradeability_expensive  ? 0.20 : 0.0);
      out_tb.spread_quality_score=MathMax(0.0,1.0-(spread_points/50.0));
      out_tb.cost_quality_score=(out_tb.cost_complete ? out_tb.spread_quality_score : 0.30);
      out_tb.fee_stability_score=(rt.quote_recent_flag ? 0.80 : 0.45);
      out_tb.entry_cost_score=out_tb.cost_quality_score;
      out_tb.structural_tradeability_score=MathMax(0.0,MathMin(1.0,
                                             0.55*out_tb.spread_quality_score
                                           + 0.45*out_tb.cost_quality_score));
      out_tb.live_tradeability_score=MathMax(0.0,MathMin(1.0,
                                       0.65*out_tb.friction_quality_score
                                     + 0.35*out_tb.fee_stability_score));
      out_tb.blended_tradeability_score=MathMax(0.0,MathMin(1.0,
                                          0.50*out_tb.structural_tradeability_score
                                        + 0.50*out_tb.live_tradeability_score));
      out_tb.size_practicality_score=(obs.volume_min<=0.0 ? 0.0 :
                                      obs.volume_min<=0.10 ? 1.00 :
                                      obs.volume_min<=0.50 ? 0.70 :
                                      obs.volume_min<=1.00 ? 0.45 : 0.20);
      out_tb.economic_consistency_score=(out_tb.cost_complete ? out_tb.fee_stability_score : 0.30);
      out_tb.all_in_cost_confidence=(out_tb.cost_complete ? 0.85 : 0.35);

      if(out_tb.excessive_freeze_level_flag)
         out_tb.tradeability_reason_codes=JoinReason(out_tb.tradeability_reason_codes,"freeze_high");
      if(out_tb.excessive_stop_level_flag)
         out_tb.tradeability_reason_codes=JoinReason(out_tb.tradeability_reason_codes,"stops_high");
      if(!out_tb.cost_complete)
         out_tb.tradeability_reason_codes=JoinReason(out_tb.tradeability_reason_codes,"cost_partial");
     }

   static void BuildRankability(ISSX_EA1_SymbolState &io_symbol)
     {
      io_symbol.rankability_gate.Reset();

      io_symbol.rankability_gate.eligible_flag=(io_symbol.raw_broker_observation.metadata_readable && !io_symbol.raw_broker_observation.custom_symbol_flag);
      io_symbol.rankability_gate.active_flag=(io_symbol.validated_runtime_truth.quote_recent_flag || io_symbol.raw_broker_observation.trade_permitted);
      io_symbol.rankability_gate.hard_block_flag=(io_symbol.tradeability_baseline.blocked_for_ranking || io_symbol.classification_truth.classification_hard_block);
      io_symbol.rankability_gate.compare_safe_degraded_flag=(io_symbol.validated_runtime_truth.readability_state==issx_readability_full);
      io_symbol.rankability_gate.same_family_merged_away_flag=false;
      io_symbol.rankability_gate.identity_ready=(!ISSX_Util::IsEmpty(io_symbol.normalized_identity.symbol_norm));
      io_symbol.rankability_gate.session_ready=(io_symbol.validated_runtime_truth.session_phase_class!=issx_ea1_session_unknown
                                                && io_symbol.validated_runtime_truth.session_truth_confidence>0.0);
      io_symbol.rankability_gate.market_ready=(io_symbol.validated_runtime_truth.practical_market_state!=issx_market_state_unknown);
      io_symbol.rankability_gate.cost_ready=(io_symbol.tradeability_baseline.cost_complete
                                             || io_symbol.tradeability_baseline.tradeability_now_complete);
      io_symbol.rankability_gate.readiness_score=0.0;
      io_symbol.rankability_gate.confidence_cap=0.0;
      io_symbol.rankability_gate.rankability_penalty=0.0;

      if(io_symbol.rankability_gate.hard_block_flag)
        {
         io_symbol.rankability_gate.rankable_flag=false;
         io_symbol.rankability_gate.publishable_flag=false;
         io_symbol.rankability_gate.acceptance_decision=issx_acceptance_rejected;
         io_symbol.rankability_gate.gate_reason_codes="hard_block";
         io_symbol.rankability_gate.dependency_block_reason="tradeability_block";
         io_symbol.rankability_gate.confidence_cap=0.0;
         return;
        }

      if(!io_symbol.rankability_gate.eligible_flag)
        {
         io_symbol.rankability_gate.rankable_flag=false;
         io_symbol.rankability_gate.publishable_flag=false;
         io_symbol.rankability_gate.acceptance_decision=issx_acceptance_rejected;
         io_symbol.rankability_gate.gate_reason_codes="not_eligible";
         io_symbol.rankability_gate.dependency_block_reason="metadata_unreadable";
         io_symbol.rankability_gate.confidence_cap=0.0;
         return;
        }

      io_symbol.rankability_gate.readiness_score=0.30;
      if(io_symbol.validated_runtime_truth.readability_state==issx_readability_full)
         io_symbol.rankability_gate.readiness_score+=0.25;
      if(io_symbol.tradeability_baseline.cost_complete)
         io_symbol.rankability_gate.readiness_score+=0.15;
      if(io_symbol.validated_runtime_truth.quote_recent_flag)
         io_symbol.rankability_gate.readiness_score+=0.15;
      if(io_symbol.classification_truth.bucket_publishable)
         io_symbol.rankability_gate.readiness_score+=0.15;

      io_symbol.rankability_gate.rankability_penalty=io_symbol.tradeability_baseline.tradeability_penalty;
      if(!io_symbol.validated_runtime_truth.quote_recent_flag)
         io_symbol.rankability_gate.rankability_penalty+=0.10;
      if(!io_symbol.tradeability_baseline.cost_complete)
         io_symbol.rankability_gate.rankability_penalty+=0.15;
      if(!io_symbol.classification_truth.bucket_publishable)
         io_symbol.rankability_gate.rankability_penalty+=0.25;

      io_symbol.rankability_gate.exploratory_only_flag=(io_symbol.rankability_gate.readiness_score<0.70 || io_symbol.rankability_gate.rankability_penalty>0.45);
      io_symbol.rankability_gate.rankable_flag=(io_symbol.rankability_gate.readiness_score>=0.45);
      io_symbol.rankability_gate.publishable_flag=(io_symbol.rankability_gate.readiness_score>=0.60 && io_symbol.rankability_gate.rankability_penalty<=0.70);
      io_symbol.rankability_gate.confidence_cap=(io_symbol.rankability_gate.exploratory_only_flag ? 0.55 : 0.95);

      if(io_symbol.rankability_gate.publishable_flag)
         io_symbol.rankability_gate.acceptance_decision=(io_symbol.rankability_gate.exploratory_only_flag ? issx_acceptance_accepted_degraded : issx_acceptance_accepted_for_ranking);
      else if(io_symbol.rankability_gate.rankable_flag)
         io_symbol.rankability_gate.acceptance_decision=issx_acceptance_accepted_degraded;
      else
         io_symbol.rankability_gate.acceptance_decision=issx_acceptance_rejected;

      io_symbol.rankability_gate.gate_reason_codes="rankable";
      if(io_symbol.rankability_gate.exploratory_only_flag)
         io_symbol.rankability_gate.gate_reason_codes=JoinReason(io_symbol.rankability_gate.gate_reason_codes,"exploratory");
      if(!io_symbol.tradeability_baseline.cost_complete)
         io_symbol.rankability_gate.gate_reason_codes=JoinReason(io_symbol.rankability_gate.gate_reason_codes,"cost_partial");
      if(!io_symbol.validated_runtime_truth.quote_recent_flag)
         io_symbol.rankability_gate.gate_reason_codes=JoinReason(io_symbol.rankability_gate.gate_reason_codes,"quote_old");
      if(!io_symbol.classification_truth.bucket_publishable)
         io_symbol.rankability_gate.gate_reason_codes=JoinReason(io_symbol.rankability_gate.gate_reason_codes,"bucket_weak");

      io_symbol.rankability_gate.dependency_block_reason=(io_symbol.rankability_gate.rankable_flag ? "none" : "insufficient_truth");
io_symbol.rankability_gate.highest_blocking_contradiction_class=(ISSX_ContradictionClass)0;
io_symbol.rankability_gate.contradiction_count=0;
     }

   static string BuildSymbolFingerprint(const ISSX_EA1_SymbolState &s)
     {
      string blob=
         s.raw_broker_observation.symbol_raw+"|"+
         s.normalized_identity.symbol_norm+"|"+
         IntegerToString((int)s.validated_runtime_truth.practical_market_state)+"|"+
         s.classification_truth.theme_bucket+"|"+
         s.classification_truth.equity_sector+"|"+
         IntegerToString((int)s.tradeability_baseline.tradeability_class)+"|"+
         IntegerToString(s.rankability_gate.acceptance_decision)+"|"+
         s.rankability_gate.gate_reason_codes+"|"+
         s.tradeability_baseline.tradeability_reason_codes;
      return HashString(blob);
     }

   static void UpdateContinuityAndChanges(const string previous_fingerprint,ISSX_EA1_SymbolState &io_symbol)
     {
      io_symbol.symbol_fingerprint=BuildSymbolFingerprint(io_symbol);
      io_symbol.changed_since_last_cycle=(previous_fingerprint!="" && previous_fingerprint!=io_symbol.symbol_fingerprint);
      io_symbol.changed_since_last_publish=io_symbol.changed_since_last_cycle;
      io_symbol.touched_this_cycle=true;

      if(previous_fingerprint=="")
        {
         io_symbol.symbol_lifecycle.lifecycle_state=issx_ea1_lifecycle_new;
         io_symbol.symbol_lifecycle.continuity_origin=issx_continuity_fresh_boot;
         io_symbol.symbol_lifecycle.continuity_age_cycles=1;
        }
      else if(io_symbol.changed_since_last_cycle)
        {
         io_symbol.symbol_lifecycle.lifecycle_state=issx_ea1_lifecycle_changed;
         io_symbol.symbol_lifecycle.continuity_age_cycles=0;
         io_symbol.symbol_lifecycle.material_change_since_last_publish=true;
         io_symbol.symbol_lifecycle.continuity_reason_codes="material_change";
        }
      else
        {
         io_symbol.symbol_lifecycle.lifecycle_state=issx_ea1_lifecycle_stable;
         io_symbol.symbol_lifecycle.continuity_age_cycles++;
         io_symbol.symbol_lifecycle.material_change_since_last_publish=false;
         io_symbol.symbol_lifecycle.continuity_reason_codes="stable";
        }

      if(io_symbol.rankability_gate.hard_block_flag)
         io_symbol.symbol_lifecycle.lifecycle_state=issx_ea1_lifecycle_blocked;

      if(io_symbol.rankability_gate.rankable_flag)
         io_symbol.symbol_lifecycle.admission_state=issx_ea1_admission_rank_candidate;
      else if(io_symbol.raw_broker_observation.metadata_readable)
         io_symbol.symbol_lifecycle.admission_state=issx_ea1_admission_metadata_ready;
      else
         io_symbol.symbol_lifecycle.admission_state=issx_ea1_admission_listed;

      io_symbol.symbol_lifecycle.owner_module_hash=HashString(ISSX_MARKET_ENGINE_MODULE_VERSION+"|"+io_symbol.raw_broker_observation.symbol_raw);
     }

   static void UpdateUniverseFingerprints(ISSX_EA1_State &io_state)
     {
      string broker_ids[];
      string eligible_ids[];
      string active_ids[];
      string rankable_ids[];
      string publishable_ids[];

      for(int i=0;i<ArraySize(io_state.symbols);i++)
        {
         PushString(broker_ids,io_state.symbols[i].raw_broker_observation.symbol_raw);

         if(io_state.symbols[i].rankability_gate.eligible_flag)
            PushString(eligible_ids,io_state.symbols[i].raw_broker_observation.symbol_raw);
         if(io_state.symbols[i].rankability_gate.active_flag)
            PushString(active_ids,io_state.symbols[i].raw_broker_observation.symbol_raw);
         if(io_state.symbols[i].rankability_gate.rankable_flag)
            PushString(rankable_ids,io_state.symbols[i].raw_broker_observation.symbol_raw);
         if(io_state.symbols[i].rankability_gate.publishable_flag)
            PushString(publishable_ids,io_state.symbols[i].raw_broker_observation.symbol_raw);
        }

      io_state.universe.broker_universe_fingerprint=FingerprintArray(broker_ids);
      io_state.universe.eligible_universe_fingerprint=FingerprintArray(eligible_ids);
      io_state.universe.active_universe_fingerprint=FingerprintArray(active_ids);
      io_state.universe.rankable_universe_fingerprint=FingerprintArray(rankable_ids);
      io_state.universe.frontier_universe_fingerprint=io_state.universe.rankable_universe_fingerprint;
      io_state.universe.publishable_universe_fingerprint=FingerprintArray(publishable_ids);
      io_state.cohort_fingerprint=io_state.universe.rankable_universe_fingerprint;
      io_state.deltas.changed_symbol_ids_compact=CompactChangedIds(io_state.symbols);
     }

   static void ResetPostDiscoveryCounters(ISSX_EA1_CycleCounters &c)
     {
      c.metadata_ready_count=0;
      c.probe_ready_count=0;
      c.rank_candidate_count=0;
      c.degraded_count=0;
      c.blocked_count=0;
      c.contradiction_count=0;
      c.contradiction_severity_max=0;
      c.changed_symbol_count=0;
      c.accepted_strong_count=0;
      c.accepted_degraded_count=0;
      c.rejected_count=0;
      c.cooldown_count=0;
      c.stale_usable_count=0;
     }

   static string TradeabilityClassText(const ISSX_TradeabilityClass v)
     {
      switch(v)
        {
         case issx_tradeability_very_cheap: return "very_cheap";
         case issx_tradeability_cheap:      return "cheap";
         case issx_tradeability_moderate:   return "moderate";
         case issx_tradeability_expensive:  return "expensive";
         case issx_tradeability_blocked:    return "blocked";
         default:                           return "unknown";
        }
     }

   static string PracticalMarketStateText(const ISSX_PracticalMarketState v)
     {
      switch(v)
        {
         case issx_market_open_usable:   return "open_usable";
         case issx_market_open_cautious: return "open_cautious";
         case issx_market_quote_only:    return "quote_only";
         case issx_market_closed_idle:   return "closed_idle";
         case issx_market_blocked:       return "blocked";
         default:                        return "unknown";
        }
     }

   static string RepresentationStateText(const ISSX_RepresentationState v)
     {
      switch(v)
        {
         case issx_representation_canonical: return "canonical";
         case issx_representation_variant:   return "variant";
         case issx_representation_uncertain: return "uncertain";
         default:                            return "unknown";
        }
     }

   static string ReadabilityStateText(const ISSX_ReadabilityState v)
     {
      switch(v)
        {
         case issx_readability_full:       return "full";
         case issx_readability_unreadable: return "unreadable";
         default:                          return "unknown";
        }
     }

   static string AcceptanceDecisionText(const int v)
     {
      switch(v)
        {
         case issx_acceptance_accepted_for_pipeline:     return "accepted_for_pipeline";
         case issx_acceptance_accepted_for_ranking:      return "accepted_for_ranking";
         case issx_acceptance_accepted_for_intelligence: return "accepted_for_intelligence";
         case issx_acceptance_accepted_for_gpt_export:   return "accepted_for_gpt_export";
         case issx_acceptance_accepted_degraded:         return "accepted_degraded";
         case issx_acceptance_rejected:                  return "rejected";
         default:                                        return "unknown";
        }
     }

   static string LeaderBucketTypeText(const ISSX_LeaderBucketType v)
     {
      switch(v)
        {
         case issx_leader_bucket_theme_bucket:  return "theme_bucket";
         case issx_leader_bucket_equity_sector: return "equity_sector";
         default:                               return "unknown";
        }
     }

   static string TaxonomyActionText(const ISSX_TaxonomyActionTaken v)
     {
      switch(v)
        {
         case issx_taxonomy_accepted:           return "accepted";
         case issx_taxonomy_theme_downgrade:    return "theme_downgrade";
         case issx_taxonomy_quarantined:        return "quarantined";
         case issx_taxonomy_manual_review_only: return "manual_review_only";
         default:                               return "unknown";
        }
     }

   static string ContinuityOriginText(const ISSX_ContinuityOrigin v)
     {
      switch(v)
        {
         case issx_continuity_fresh_boot:        return "fresh_boot";
         case issx_continuity_resumed_current:   return "resumed_current";
         case issx_continuity_resumed_previous:  return "resumed_previous";
         case issx_continuity_resumed_last_good: return "resumed_last_good";
         case issx_continuity_rebuilt_clean:     return "rebuilt_clean";
         default:                                return "unknown";
        }
     }

   static string FailureEscalationText(const ISSX_FailureEscalationClass v)
     {
      switch(v)
        {
         case issx_failure_transient_fail: return "transient_fail";
         case issx_failure_suspended:      return "suspended";
         default:                          return "unknown";
        }
     }

   static string RepairStateText(const ISSX_RepairState v)
     {
      const int repair_value=(int)v;
      if(repair_value==(int)issx_repair_none)
         return "none";

      // Core-compat bridge:
      // do not hard-reference owner enum members that may not exist in older core.
      if(repair_value==1)
         return "pending";
      if(repair_value==2)
         return "in_progress";
      if(repair_value==3)
         return "waiting_stability";
      if(repair_value==4)
         return "failed";

      return "unknown";
     }

   static string HudSeverityText(const int v)
     {
      switch(v)
        {
         case 1:  return "info";
         case 2:  return "warn";
         case 3:  return "error";
         default: return "none";
        }
     }

   static string StagePublishabilityText(const string raw_state)
     {
      if(raw_state=="")
         return "not_ready";
      return raw_state;
     }

   static void WriteRawObservationJson(ISSX_JsonWriter &j,const ISSX_EA1_RawBrokerObservation &o)
     {
      j.BeginNamedObject("raw_broker_observation");
      j.NameString("symbol_raw",o.symbol_raw);
      j.NameString("path",o.path);
      j.NameString("description",o.description);
      j.NameLong("trade_mode",o.trade_mode);
      j.NameLong("calc_mode",o.calc_mode);
      j.NameInt("digits",o.digits);
      j.NameDouble("point",o.point,8);
      j.NameDouble("tick_size",o.tick_size,8);
      j.NameDouble("tick_value",o.tick_value,6);
      j.NameDouble("tick_value_profit",o.tick_value_profit,6);
      j.NameDouble("tick_value_loss",o.tick_value_loss,6);
      j.NameDouble("contract_size",o.contract_size,2);
      j.NameDouble("volume_min",o.volume_min,4);
      j.NameDouble("volume_step",o.volume_step,4);
      j.NameDouble("volume_max",o.volume_max,4);
      j.NameInt("stops_level",o.stops_level);
      j.NameInt("freeze_level",o.freeze_level);
      j.NameString("margin_currency",o.margin_currency);
      j.NameString("profit_currency",o.profit_currency);
      j.NameString("base_currency",o.base_currency);
      j.NameString("quote_currency",o.quote_currency);
      j.NameBool("session_property_availability",o.session_property_availability);
      j.NameBool("selection_state",o.selection_state);
      j.NameBool("sync_state",o.sync_state);
      j.NameBool("metadata_readable",o.metadata_readable);
      j.NameBool("quote_observable",o.quote_observable);
      j.NameBool("synchronized_flag",o.synchronized_flag);
      j.NameBool("history_addressable",o.history_addressable);
      j.NameBool("trade_permitted",o.trade_permitted);
      j.NameBool("custom_symbol_flag",o.custom_symbol_flag);
      j.NameBool("property_unavailable_flag",o.property_unavailable_flag);
      j.NameBool("select_failed_temp",o.select_failed_temp);
      j.NameBool("select_failed_perm",o.select_failed_perm);
      j.NameString("symbol_discovery_state",o.symbol_discovery_state);
      j.NameString("symbol_selection_state",o.symbol_selection_state);
      j.NameString("symbol_synchronization_state",o.symbol_synchronization_state);
      j.NameString("property_read_status",o.property_read_status);
      j.NameInt("property_read_fail_mask",o.property_read_fail_mask);
      j.NameLong("quote_time",(long)o.quote_time);
      j.NameLong("quote_last_seen",(long)o.quote_last_seen);
      j.NameInt("session_trade_windows",o.session_trade_windows);
      j.NameInt("session_quote_windows",o.session_quote_windows);
      j.EndObject();
     }

   static void WriteIdentityJson(ISSX_JsonWriter &j,const ISSX_EA1_NormalizedIdentity &id)
     {
      j.BeginNamedObject("normalized_identity");
      j.NameString("symbol_norm",id.symbol_norm);
      j.NameString("canonical_root",id.canonical_root);
      j.NameString("prefix_token",id.prefix_token);
      j.NameString("suffix_token",id.suffix_token);
      j.NameString("contract_token",id.contract_token);
      j.NameString("alias_family_id",id.alias_family_id);
      j.NameString("underlying_family_id",id.underlying_family_id);
      j.NameString("market_representation_id",id.market_representation_id);
      j.NameString("execution_substitute_group_id",id.execution_substitute_group_id);
      j.NameString("representation_state",RepresentationStateText(id.representation_state));
      j.NameDouble("representation_confidence",id.representation_confidence,4);
      j.NameDouble("family_resolution_confidence",id.family_resolution_confidence,4);
      j.NameInt("family_rep_stability_window",id.family_rep_stability_window);
      j.NameString("family_published_rep",id.family_published_rep);
      j.NameString("family_best_now",id.family_best_now);
      j.NameBool("execution_profile_distinct_flag",id.execution_profile_distinct_flag);
      j.NameString("representation_reason_codes",id.representation_reason_codes);
      j.NameBool("preferred_variant_flag",id.preferred_variant_flag);
      j.NameBool("preferred_variant_locked",id.preferred_variant_locked);
      j.NameInt("preferred_variant_lock_age_cycles",id.preferred_variant_lock_age_cycles);
      j.NameString("representative_switch_reason",id.representative_switch_reason);
      j.NameDouble("representative_switch_cost",id.representative_switch_cost,4);
      j.NameDouble("variant_flip_risk_score",id.variant_flip_risk_score,4);
      j.NameDouble("representation_stability_score",id.representation_stability_score,4);
      j.EndObject();
     }

   static void WriteRuntimeTruthJson(ISSX_JsonWriter &j,const ISSX_EA1_ValidatedRuntimeTruth &rt)
     {
      j.BeginNamedObject("validated_runtime_truth");
      j.NameString("readability_state",ReadabilityStateText(rt.readability_state));
      j.NameInt("unknown_reason",(int)rt.unknown_reason);
      j.NameBool("declared_session_open",rt.declared_session_open);
      j.NameBool("observed_quote_liveness",rt.observed_quote_liveness);
      j.NameBool("trade_permitted_now",rt.trade_permitted_now);
      j.NameBool("quote_recent_flag",rt.quote_recent_flag);
      j.NameString("practical_market_state",PracticalMarketStateText(rt.practical_market_state));
      j.NameString("practical_market_state_reason_codes",rt.practical_market_state_reason_codes);
      j.NameString("session_reconciliation_state",rt.session_reconciliation_state);
      j.NameDouble("session_truth_confidence",rt.session_truth_confidence,4);
      j.NameInt("observation_samples_short",rt.observation_samples_short);
      j.NameInt("observation_samples_medium",rt.observation_samples_medium);
      j.NameDouble("observation_density_score",rt.observation_density_score,4);
      j.NameDouble("observation_gap_risk",rt.observation_gap_risk,4);
      j.NameDouble("market_sampling_quality_score",rt.market_sampling_quality_score,4);
      j.NameDouble("spread_median_short_points",rt.spread_median_short_points,2);
      j.NameDouble("spread_p90_short_points",rt.spread_p90_short_points,2);
      j.NameDouble("spread_widening_ratio",rt.spread_widening_ratio,4);
      j.NameDouble("quote_interval_median_ms",rt.quote_interval_median_ms,2);
      j.NameDouble("quote_interval_p90_ms",rt.quote_interval_p90_ms,2);
      j.NameDouble("quote_stall_rate",rt.quote_stall_rate,4);
      j.NameDouble("quote_burstiness_score",rt.quote_burstiness_score,4);
      j.NameDouble("current_vs_normal_spread_percentile",rt.current_vs_normal_spread_percentile,4);
      j.NameDouble("current_vs_normal_quote_rate_percentile",rt.current_vs_normal_quote_rate_percentile,4);
      j.NameDouble("current_spread_points",rt.current_spread_points,2);
      j.NameDouble("current_spread_money_per_lot",rt.current_spread_money_per_lot,6);
      j.NameString("current_friction_state",rt.current_friction_state);
      j.NameString("spread_state_vs_baseline",rt.spread_state_vs_baseline);
      j.NameString("activity_transition_state",rt.activity_transition_state);
      j.NameString("liquidity_ramp_state",rt.liquidity_ramp_state);
      j.NameString("session_phase_class",SessionPhaseText(rt.session_phase_class));
      j.NameInt("session_trade_windows",rt.session_trade_windows);
      j.NameInt("session_quote_windows",rt.session_quote_windows);
      j.NameBool("property_zero_distinct_from_unavailable",rt.property_zero_distinct_from_unavailable);
      j.NameBool("synchronized_flag",rt.synchronized_flag);
      j.NameBool("history_addressable",rt.history_addressable);
      j.NameBool("selection_required_flag",rt.selection_required_flag);
      j.EndObject();
     }

   static void WriteClassificationJson(ISSX_JsonWriter &j,const ISSX_EA1_ClassificationTruth &cls)
     {
      j.BeginNamedObject("classification_truth");
      j.NameString("asset_class",cls.asset_class);
      j.NameString("instrument_family",cls.instrument_family);
      j.NameString("theme_bucket",cls.theme_bucket);
      j.NameString("equity_sector",cls.equity_sector);
      j.NameString("leader_bucket_id",cls.leader_bucket_id);
      j.NameString("leader_bucket_type",LeaderBucketTypeText(cls.leader_bucket_type));
      j.NameString("classification_source",cls.classification_source);
      j.NameDouble("classification_confidence",cls.classification_confidence,4);
      j.NameDouble("classification_reliability_score",cls.classification_reliability_score,4);
      j.NameString("taxonomy_conflict_scope",cls.taxonomy_conflict_scope);
      j.NameString("taxonomy_action_taken",TaxonomyActionText(cls.taxonomy_action_taken));
      j.NameInt("taxonomy_revision",cls.taxonomy_revision);
      j.NameInt("bucket_assignment_stable_cycles",cls.bucket_assignment_stable_cycles);
      j.NameString("bucket_assignment_change_reason",cls.bucket_assignment_change_reason);
      j.NameDouble("taxonomy_change_severity",cls.taxonomy_change_severity,4);
      j.NameBool("native_sector_present",cls.native_sector_present);
      j.NameBool("native_industry_present",cls.native_industry_present);
      j.NameDouble("native_taxonomy_quality",cls.native_taxonomy_quality,4);
      j.NameBool("native_vs_manual_conflict",cls.native_vs_manual_conflict);
      j.NameBool("classification_hard_block",cls.classification_hard_block);
      j.NameBool("bucket_publishable",cls.bucket_publishable);
      j.NameString("taxonomy_hash",cls.taxonomy_hash);
      j.EndObject();
     }

   static void WriteTradeabilityJson(ISSX_JsonWriter &j,const ISSX_EA1_TradeabilityBaseline &tb)
     {
      j.BeginNamedObject("tradeability_baseline");
      j.NameString("tradeability_class",TradeabilityClassText(tb.tradeability_class));
      j.NameInt("commission_state",(int)tb.commission_state);
      j.NameInt("swap_state",(int)tb.swap_state);
      j.NameDouble("roundtrip_cost_points",tb.roundtrip_cost_points,2);
      j.NameDouble("spread_cost_points",tb.spread_cost_points,2);
      j.NameDouble("commission_cost_money_per_lot",tb.commission_cost_money_per_lot,6);
      j.NameDouble("commission_cost_points_equiv",tb.commission_cost_points_equiv,4);
      j.NameDouble("swap_long_money_per_lot",tb.swap_long_money_per_lot,6);
      j.NameDouble("swap_short_money_per_lot",tb.swap_short_money_per_lot,6);
      j.NameDouble("notional_tick_value_money",tb.notional_tick_value_money,6);
      j.NameDouble("minimum_ticket_money",tb.minimum_ticket_money,6);
      j.NameBool("blocked_for_trading",tb.blocked_for_trading);
      j.NameBool("blocked_for_ranking",tb.blocked_for_ranking);
      j.NameBool("cost_complete",tb.cost_complete);
      j.NameBool("session_support_complete",tb.session_support_complete);
      j.NameBool("tradeability_now_complete",tb.tradeability_now_complete);
      j.NameDouble("friction_quality_score",tb.friction_quality_score,4);
      j.NameDouble("spread_quality_score",tb.spread_quality_score,4);
      j.NameDouble("cost_quality_score",tb.cost_quality_score,4);
      j.NameDouble("fee_stability_score",tb.fee_stability_score,4);
      j.NameDouble("tradeability_penalty",tb.tradeability_penalty,4);
      j.NameString("tradeability_reason_codes",tb.tradeability_reason_codes);
      j.NameString("commission_reason_codes",tb.commission_reason_codes);
      j.NameString("swap_reason_codes",tb.swap_reason_codes);
      j.NameString("current_friction_state",tb.current_friction_state);
      j.NameString("spread_state_vs_baseline",tb.spread_state_vs_baseline);
      j.NameBool("excessive_freeze_level_flag",tb.excessive_freeze_level_flag);
      j.NameBool("excessive_stop_level_flag",tb.excessive_stop_level_flag);
      j.EndObject();
     }

   static void WriteRankabilityJson(ISSX_JsonWriter &j,const ISSX_EA1_RankabilityGate &gate)
     {
      j.BeginNamedObject("rankability_gate");
      j.NameBool("eligible_flag",gate.eligible_flag);
      j.NameBool("active_flag",gate.active_flag);
      j.NameBool("rankable_flag",gate.rankable_flag);
      j.NameBool("publishable_flag",gate.publishable_flag);
      j.NameBool("hard_block_flag",gate.hard_block_flag);
      j.NameBool("exploratory_only_flag",gate.exploratory_only_flag);
      j.NameBool("compare_safe_degraded_flag",gate.compare_safe_degraded_flag);
      j.NameBool("same_family_merged_away_flag",gate.same_family_merged_away_flag);
      j.NameString("acceptance_decision",AcceptanceDecisionText(gate.acceptance_decision));
      j.NameString("gate_reason_codes",gate.gate_reason_codes);
      j.NameString("dependency_block_reason",gate.dependency_block_reason);
      j.NameDouble("rankability_penalty",gate.rankability_penalty,4);
      j.NameDouble("readiness_score",gate.readiness_score,4);
      j.NameDouble("confidence_cap",gate.confidence_cap,4);
      j.NameInt("contradiction_count",gate.contradiction_count);
      j.NameInt("highest_blocking_contradiction_class",(int)gate.highest_blocking_contradiction_class);
      j.EndObject();
     }

   static void WriteLifecycleJson(ISSX_JsonWriter &j,const ISSX_EA1_SymbolLifecycle &life)
     {
      j.BeginNamedObject("symbol_lifecycle");
      j.NameInt("admission_state",(int)life.admission_state);
      j.NameInt("lifecycle_state",(int)life.lifecycle_state);
      j.NameString("continuity_origin",ContinuityOriginText(life.continuity_origin));
      j.NameBool("resumed_from_persistence",life.resumed_from_persistence);
      j.NameInt("continuity_age_cycles",life.continuity_age_cycles);
      j.NameBool("material_change_since_last_publish",life.material_change_since_last_publish);
      j.NameString("repair_state",RepairStateText(life.repair_state));
      j.NameInt("retry_backoff_sec",life.retry_backoff_sec);
      j.NameLong("next_reprobe_time",(long)life.next_reprobe_time);
      j.NameInt("fault_streak",life.fault_streak);
      j.NameDouble("fault_decay_score",life.fault_decay_score,4);
      j.NameString("failure_escalation_class",FailureEscalationText(life.failure_escalation_class));
      j.NameBool("forced_rebuild_required",life.forced_rebuild_required);
      j.NameString("suspension_reason",life.suspension_reason);
      j.NameString("continuity_reason_codes",life.continuity_reason_codes);
      j.NameString("owner_module_name",life.owner_module_name);
      j.NameString("owner_module_hash",life.owner_module_hash);
      j.EndObject();
     }

   static string BuildUniverseDumpJson(const ISSX_EA1_State &state,
                                       const string firm_id,
                                       const string writer_boot_id,
                                       const string writer_nonce)
     {
      ISSX_JsonWriter j;
      j.BeginObject();
      j.NameString("stage_id","ea1");
      j.NameString("owner_module_name","issx_market_engine.mqh");
      j.NameString("owner_module_hash",HashString(ISSX_MARKET_ENGINE_MODULE_VERSION));
      j.NameString("firm_id",firm_id);
      j.NameString("writer_boot_id",writer_boot_id);
      j.NameString("writer_nonce",writer_nonce);
      j.NameString("schema_version",ISSX_SCHEMA_VERSION);
      j.NameInt("schema_epoch",ISSX_SCHEMA_EPOCH);
      j.NameInt("storage_version",ISSX_STORAGE_VERSION);
      j.NameInt("stage_api_version",ISSX_STAGE_API_VERSION);
      j.NameInt("serializer_version",ISSX_SERIALIZER_VERSION);
      j.NameString("policy_fingerprint",state.policy_fingerprint);
      j.NameString("taxonomy_hash",state.taxonomy_hash);
      j.NameString("comparator_registry_hash",state.comparator_registry_hash);
      j.NameString("fingerprint_algorithm_version",state.fingerprint_algorithm_version);
      j.NameInt("minute_id",state.minute_id);
      j.NameInt("sequence_no",state.sequence_no);
      j.NameInt("dump_sequence_no",state.dump_sequence_no);
      j.NameInt("dump_minute_id",state.dump_minute_id);
      j.NameBool("stage_minimum_ready_flag",state.stage_minimum_ready_flag);
      j.NameString("stage_publishability_state",StagePublishabilityText(state.stage_publishability_state));
      j.NameBool("degraded_flag",state.degraded_flag);
      j.NameBool("publishable",state.publishable);
      j.NameString("dependency_block_reason",state.dependency_block_reason);
      j.NameString("debug_weak_link_code",state.debug_weak_link_code);

      j.BeginNamedObject("universe");
      j.NameInt("broker_universe",state.universe.broker_universe);
      j.NameInt("eligible_universe",state.universe.eligible_universe);
      j.NameInt("active_universe",state.universe.active_universe);
      j.NameInt("rankable_universe",state.universe.rankable_universe);
      j.NameInt("frontier_hint_universe",state.universe.frontier_hint_universe);
      j.NameInt("publishable_universe",state.universe.publishable_universe);
      j.NameString("broker_universe_fingerprint",state.universe.broker_universe_fingerprint);
      j.NameString("eligible_universe_fingerprint",state.universe.eligible_universe_fingerprint);
      j.NameString("active_universe_fingerprint",state.universe.active_universe_fingerprint);
      j.NameString("rankable_universe_fingerprint",state.universe.rankable_universe_fingerprint);
      j.NameString("frontier_universe_fingerprint",state.universe.frontier_universe_fingerprint);
      j.NameString("publishable_universe_fingerprint",state.universe.publishable_universe_fingerprint);
      j.NameDouble("percent_universe_touched_recent",state.universe.percent_universe_touched_recent,4);
      j.NameDouble("percent_rankable_revalidated_recent",state.universe.percent_rankable_revalidated_recent,4);
      j.NameDouble("percent_frontier_revalidated_recent",state.universe.percent_frontier_revalidated_recent,4);
      j.NameInt("never_serviced_count",state.universe.never_serviced_count);
      j.NameInt("overdue_service_count",state.universe.overdue_service_count);
      j.NameInt("never_ranked_but_eligible_count",state.universe.never_ranked_but_eligible_count);
      j.NameInt("newly_active_symbols_waiting_count",state.universe.newly_active_symbols_waiting_count);
      j.NameInt("near_cutline_recheck_age_max",state.universe.near_cutline_recheck_age_max);
      j.EndObject();

      j.BeginNamedObject("deltas");
      j.NameInt("changed_symbol_count",state.deltas.changed_symbol_count);
      j.NameString("changed_symbol_ids_compact",state.deltas.changed_symbol_ids_compact);
      j.NameInt("changed_family_count",state.deltas.changed_family_count);
      j.NameInt("changed_bucket_count",state.deltas.changed_bucket_count);
      j.EndObject();

      j.BeginNamedObject("counters");
      j.NameInt("listed_count",state.counters.listed_count);
      j.NameInt("metadata_ready_count",state.counters.metadata_ready_count);
      j.NameInt("probe_ready_count",state.counters.probe_ready_count);
      j.NameInt("rank_candidate_count",state.counters.rank_candidate_count);
      j.NameInt("degraded_count",state.counters.degraded_count);
      j.NameInt("blocked_count",state.counters.blocked_count);
      j.NameInt("contradiction_count",state.counters.contradiction_count);
      j.NameString("contradiction_severity_max",HudSeverityText(state.counters.contradiction_severity_max));
      j.NameInt("changed_symbol_count",state.counters.changed_symbol_count);
      j.NameInt("accepted_strong_count",state.counters.accepted_strong_count);
      j.NameInt("accepted_degraded_count",state.counters.accepted_degraded_count);
      j.NameInt("rejected_count",state.counters.rejected_count);
      j.NameInt("cooldown_count",state.counters.cooldown_count);
      j.NameInt("stale_usable_count",state.counters.stale_usable_count);
      j.EndObject();

      j.BeginNamedArray("symbols");
      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         j.BeginObject();
         j.NameInt("symbol_id",state.symbols[i].symbol_id);
         j.NameString("symbol_fingerprint",state.symbols[i].symbol_fingerprint);
         j.NameBool("changed_since_last_cycle",state.symbols[i].changed_since_last_cycle);
         j.NameBool("changed_since_last_publish",state.symbols[i].changed_since_last_publish);
         j.NameBool("touched_this_cycle",state.symbols[i].touched_this_cycle);
         WriteRawObservationJson(j,state.symbols[i].raw_broker_observation);
         WriteIdentityJson(j,state.symbols[i].normalized_identity);
         WriteRuntimeTruthJson(j,state.symbols[i].validated_runtime_truth);
         WriteClassificationJson(j,state.symbols[i].classification_truth);
         WriteTradeabilityJson(j,state.symbols[i].tradeability_baseline);
         WriteRankabilityJson(j,state.symbols[i].rankability_gate);
         WriteLifecycleJson(j,state.symbols[i].symbol_lifecycle);
         j.EndObject();
        }
      j.EndArray();

      j.EndObject();
      return j.ToString();
     }

   static string BuildStageSummaryJson(const ISSX_EA1_State &state)
     {
      ISSX_JsonWriter j;
      j.BeginObject();
      j.NameString("stage_id","ea1");
      j.NameInt("minute_id",state.minute_id);
      j.NameInt("sequence_no",state.sequence_no);
      j.NameBool("stage_minimum_ready_flag",state.stage_minimum_ready_flag);
      j.NameString("stage_publishability_state",StagePublishabilityText(state.stage_publishability_state));
      j.NameBool("degraded_flag",state.degraded_flag);
      j.NameBool("publishable",state.publishable);
      j.NameString("dependency_block_reason",state.dependency_block_reason);
      j.NameString("debug_weak_link_code",state.debug_weak_link_code);
      j.NameInt("broker_universe",state.universe.broker_universe);
      j.NameInt("eligible_universe",state.universe.eligible_universe);
      j.NameInt("active_universe",state.universe.active_universe);
      j.NameInt("rankable_universe",state.universe.rankable_universe);
      j.NameInt("publishable_universe",state.universe.publishable_universe);
      j.NameInt("changed_symbol_count",state.deltas.changed_symbol_count);
      j.NameString("changed_symbol_ids_compact",state.deltas.changed_symbol_ids_compact);
      j.EndObject();
      return j.ToString();
     }

   static void UpdateGlobalStateFlags(ISSX_EA1_State &io_state)
     {
      io_state.stage_minimum_ready_flag=(io_state.universe.broker_universe>0 && io_state.universe.eligible_universe>0);
      io_state.publishable=(io_state.universe.publishable_universe>0);
      io_state.degraded_flag=(io_state.counters.accepted_degraded_count>0 || io_state.counters.rejected_count>0);

      if(io_state.publishable && !io_state.degraded_flag)
         io_state.stage_publishability_state="strong";
      else if(io_state.publishable)
         io_state.stage_publishability_state="usable_degraded";
      else if(io_state.stage_minimum_ready_flag)
         io_state.stage_publishability_state="warmup";
      else
         io_state.stage_publishability_state="not_ready";

      io_state.dependency_block_reason=(io_state.stage_minimum_ready_flag ? "none" : "broker_universe_thin");
      io_state.debug_weak_link_code=(io_state.publishable ? "none" :
                                     io_state.universe.broker_universe<=0 ? "ea1_no_symbols" :
                                     io_state.universe.eligible_universe<=0 ? "ea1_unreadable_universe" :
                                     "ea1_rankable_thin");
     }

   static bool WriteInternalUniverseDump(const ISSX_EA1_State &state,
                                         const string firm_id,
                                         const string writer_boot_id,
                                         const string writer_nonce)
     {
      string json=BuildUniverseDumpJson(state,firm_id,writer_boot_id,writer_nonce);
      return (json!="");
     }

public:
   static void InitState(ISSX_EA1_State &io_state)
     {
      io_state.Reset();
      io_state.runtime_budget=ISSX_Runtime::MakeDefaultBudget(issx_stage_ea1);
      io_state.scheduler.phase_id=ISSX_EA1_MapToRuntimePhase(issx_ea1_phase_none);
      io_state.scheduler.phase_budget_ms=150;
      io_state.scheduler.phase_saved_progress_key="ea1_discovery";
      io_state.taxonomy_hash=ISSX_Hash::HashStringHex("ea1_taxonomy_"+ISSX_MARKET_ENGINE_MODULE_VERSION);
      io_state.comparator_registry_hash=ISSX_Hash::HashStringHex("ea1_registry_"+ISSX_MARKET_ENGINE_MODULE_VERSION);
      io_state.policy_fingerprint=ISSX_Hash::HashStringHex("ea1_policy_"+ISSX_MARKET_ENGINE_MODULE_VERSION);
      io_state.fingerprint_algorithm_version="sha256_hex_v1";
      m_last_discovery_minute=-1;
     }

   static bool DiscoverUniverse(ISSX_EA1_State &io_state,
                             const bool include_custom_symbols=false,
                             const int max_symbols=0)
  {
   ISSX_EA1_SymbolState prior_symbols[];
   CopySymbolStateArray(io_state.symbols,prior_symbols);

   io_state.universe.Reset();
   io_state.deltas.Reset();
   io_state.counters.Reset();

      const int total=SymbolsTotal(false);
      io_state.universe.broker_universe=(total>0 ? total : 0);

      ArrayResize(io_state.symbols,0);

      // Ported/adapted from legacy EA1_MarketCore.mq5 BuildUniverse sorting:
      // keep symbol traversal deterministic so continuity/fingerprints do not
      // drift when broker enumeration order changes across sessions.
      string discovered_symbols[];
      ArrayResize(discovered_symbols,0);
      for(int i=0;i<total;i++)
        {
         string symbol=SymbolName(i,false);
         if(symbol=="")
            continue;

         int n=ArraySize(discovered_symbols);
         ArrayResize(discovered_symbols,n+1);
         discovered_symbols[n]=symbol;
        }
      if(ArraySize(discovered_symbols)>1)
         ISSX_Util::SortStringsInPlace(discovered_symbols);

      int accepted_count=0;
      for(int i=0;i<ArraySize(discovered_symbols);i++)
        {
         const string symbol=discovered_symbols[i];

         bool is_custom=SafeSymbolBool(symbol,SYMBOL_CUSTOM);
         if(!include_custom_symbols && is_custom)
            continue;

         if(max_symbols>0 && accepted_count>=max_symbols)
            break;

         int new_index=ArraySize(io_state.symbols);
         ArrayResize(io_state.symbols,new_index+1);
         io_state.symbols[new_index].Reset();
         io_state.symbols[new_index].symbol_id=accepted_count;

         LoadRawObservation(symbol,io_state.symbols[new_index].raw_broker_observation);

         int prior_index=FindPriorSymbolIndex(prior_symbols,symbol);
         if(prior_index>=0)
            RestorePriorContinuity(prior_symbols[prior_index],io_state.symbols[new_index]);

         accepted_count++;
         io_state.counters.listed_count++;
        }

      io_state.universe.active_universe=0;
      io_state.universe.eligible_universe=0;
      io_state.universe.rankable_universe=0;
      io_state.universe.frontier_hint_universe=0;
      io_state.universe.publishable_universe=0;
      return (accepted_count>0);
     }

   static void BuildIdentityPhase(ISSX_EA1_State &io_state)
     {
      io_state.scheduler.phase_id=ISSX_EA1_MapToRuntimePhase(issx_ea1_phase_normalize_identity);
      for(int i=0;i<ArraySize(io_state.symbols);i++)
         NormalizeIdentity(io_state.symbols[i].raw_broker_observation,io_state.symbols[i].normalized_identity);
     }

   static void CanonicalizeDeterministicOrder(ISSX_EA1_State &io_state)
     {
      const int n=ArraySize(io_state.symbols);
      if(n<=1)
        {
         io_state.deterministic_sort_applied=(n>0);
         io_state.deterministic_sorted_count=n;
         io_state.deterministic_sort_basis="symbol_norm";
         return;
        }

      for(int i=0;i<n-1;i++)
        {
         int best=i;
         string best_key=io_state.symbols[i].normalized_identity.symbol_norm;
         if(best_key=="")
            best_key=io_state.symbols[i].raw_broker_observation.symbol_raw;

         for(int j=i+1;j<n;j++)
           {
            string key=io_state.symbols[j].normalized_identity.symbol_norm;
            if(key=="")
               key=io_state.symbols[j].raw_broker_observation.symbol_raw;
            if(StringCompare(key,best_key)<0)
              {
               best=j;
               best_key=key;
              }
           }

         if(best!=i)
           {
            ISSX_EA1_SymbolState tmp=io_state.symbols[i];
            io_state.symbols[i]=io_state.symbols[best];
            io_state.symbols[best]=tmp;
           }
        }

      for(int k=0;k<n;k++)
         io_state.symbols[k].symbol_id=k;

      io_state.deterministic_sort_applied=true;
      io_state.deterministic_sorted_count=n;
      io_state.deterministic_sort_basis="symbol_norm";
     }

   static void BuildRuntimePhase(ISSX_EA1_State &io_state)
     {
      io_state.scheduler.phase_id=ISSX_EA1_MapToRuntimePhase(issx_ea1_phase_sample_runtime_delta_first);
      for(int i=0;i<ArraySize(io_state.symbols);i++)
         BuildRuntimeTruth(io_state.symbols[i].raw_broker_observation,io_state.symbols[i].validated_runtime_truth);
     }

   static void BuildClassificationPhase(ISSX_EA1_State &io_state)
     {
      io_state.scheduler.phase_id=ISSX_EA1_MapToRuntimePhase(issx_ea1_phase_classify_symbols_delta_first);
      for(int i=0;i<ArraySize(io_state.symbols);i++)
        {
         ISSX_MarketTaxonomy::Classify(io_state.symbols[i].raw_broker_observation.symbol_raw,
                                       io_state.symbols[i].normalized_identity.symbol_norm,
                                       io_state.symbols[i].normalized_identity.canonical_root,
                                       io_state.symbols[i].raw_broker_observation.description,
                                       io_state.symbols[i].raw_broker_observation.path,
                                       io_state.symbols[i].classification_truth);
        }
     }

   static void BuildTradeabilityPhase(ISSX_EA1_State &io_state)
     {
      io_state.scheduler.phase_id=ISSX_EA1_MapToRuntimePhase(issx_ea1_phase_update_tradeability_delta_first);
      for(int i=0;i<ArraySize(io_state.symbols);i++)
         BuildTradeability(io_state.symbols[i].raw_broker_observation,
                           io_state.symbols[i].validated_runtime_truth,
                           io_state.symbols[i].tradeability_baseline);
     }

   static void BuildGateAndContinuityPhase(ISSX_EA1_State &io_state)
     {
      io_state.scheduler.phase_id=ISSX_EA1_MapToRuntimePhase(issx_ea1_phase_update_continuity);
      io_state.universe.eligible_universe=0;
      io_state.universe.active_universe=0;
      io_state.universe.rankable_universe=0;
      io_state.universe.publishable_universe=0;
      io_state.universe.frontier_hint_universe=0;
      io_state.deltas.Reset();
      ResetPostDiscoveryCounters(io_state.counters);

      for(int i=0;i<ArraySize(io_state.symbols);i++)
        {
         string previous_fingerprint=io_state.symbols[i].symbol_fingerprint;

         BuildRankability(io_state.symbols[i]);
         UpdateContinuityAndChanges(previous_fingerprint,io_state.symbols[i]);

         if(io_state.symbols[i].rankability_gate.eligible_flag)
            io_state.universe.eligible_universe++;
         if(io_state.symbols[i].rankability_gate.active_flag)
            io_state.universe.active_universe++;
         if(io_state.symbols[i].rankability_gate.rankable_flag)
            io_state.universe.rankable_universe++;
         if(io_state.symbols[i].rankability_gate.publishable_flag)
            io_state.universe.publishable_universe++;

         if(io_state.symbols[i].changed_since_last_cycle)
            io_state.counters.changed_symbol_count++;

         switch(io_state.symbols[i].rankability_gate.acceptance_decision)
           {
            case issx_acceptance_accepted_for_ranking:
               io_state.counters.accepted_strong_count++;
               break;
            case issx_acceptance_accepted_degraded:
               io_state.counters.accepted_degraded_count++;
               break;
            case issx_acceptance_rejected:
               io_state.counters.rejected_count++;
               break;
            default:
               io_state.counters.stale_usable_count++;
               break;
           }

         if(io_state.symbols[i].rankability_gate.hard_block_flag)
            io_state.counters.blocked_count++;
         else if(io_state.symbols[i].rankability_gate.exploratory_only_flag)
            io_state.counters.degraded_count++;

         if(io_state.symbols[i].raw_broker_observation.metadata_readable)
            io_state.counters.metadata_ready_count++;
         if(io_state.symbols[i].validated_runtime_truth.readability_state==issx_readability_full)
            io_state.counters.probe_ready_count++;
         if(io_state.symbols[i].rankability_gate.rankable_flag)
            io_state.counters.rank_candidate_count++;
        }

      io_state.universe.frontier_hint_universe=io_state.universe.rankable_universe;
      io_state.deltas.changed_symbol_count=io_state.counters.changed_symbol_count;
      io_state.deltas.changed_family_count=io_state.counters.changed_symbol_count;
      io_state.deltas.changed_bucket_count=io_state.counters.changed_symbol_count;

      if(io_state.universe.broker_universe>0)
         io_state.universe.percent_universe_touched_recent=(100.0*(double)ArraySize(io_state.symbols)/(double)io_state.universe.broker_universe);
      else
         io_state.universe.percent_universe_touched_recent=0.0;

      if(io_state.universe.rankable_universe>0)
         io_state.universe.percent_rankable_revalidated_recent=100.0;
      else
         io_state.universe.percent_rankable_revalidated_recent=0.0;

      io_state.universe.percent_frontier_revalidated_recent=(io_state.universe.frontier_hint_universe>0 ? 100.0 : 0.0);
      io_state.universe.never_serviced_count=0;
      io_state.universe.overdue_service_count=0;
      io_state.universe.never_ranked_but_eligible_count=MathMax(0,io_state.universe.eligible_universe-io_state.universe.rankable_universe);
      io_state.universe.newly_active_symbols_waiting_count=0;
      io_state.universe.near_cutline_recheck_age_max=0;

      UpdateUniverseFingerprints(io_state);
      UpdateGlobalStateFlags(io_state);
     }

   static bool RefreshDiscoveryOnly(ISSX_EA1_State &io_state)
     {
      io_state.scheduler.phase_id=ISSX_EA1_MapToRuntimePhase(issx_ea1_phase_discover_symbols);
      return DiscoverUniverse(io_state,false,0);
     }

   static void AdvanceOneCycle(ISSX_EA1_State &io_state)
     {
      io_state.minute_id=(int)(TimeCurrent()/60);
      const bool discovery_due=(m_last_discovery_minute<0 || io_state.minute_id!=m_last_discovery_minute);
      if(discovery_due)
        {
         RefreshDiscoveryOnly(io_state);
         io_state.discovery_minute_id=io_state.minute_id;
         m_last_discovery_minute=io_state.minute_id;
        }
      BuildIdentityPhase(io_state);
      CanonicalizeDeterministicOrder(io_state);
      BuildRuntimePhase(io_state);
      BuildClassificationPhase(io_state);
      BuildTradeabilityPhase(io_state);
      BuildGateAndContinuityPhase(io_state);
      io_state.sequence_no++;
      io_state.dump_sequence_no=io_state.sequence_no;
      io_state.dump_minute_id=io_state.minute_id;
      io_state.discovery_minute_id=io_state.minute_id;
     }

   static bool BuildUniverseDump(const ISSX_EA1_State &state,
                                 const string firm_id,
                                 const string writer_boot_id,
                                 const string writer_nonce,
                                 string &out_json)
     {
      out_json=BuildUniverseDumpJson(state,firm_id,writer_boot_id,writer_nonce);
      return (out_json!="");
     }

public:
   static bool StageBoot(ISSX_EA1_State &io_state)
     {
      InitState(io_state);
      io_state.minute_id=(int)(TimeCurrent()/60);
      io_state.sequence_no=0;
      io_state.dump_sequence_no=0;
      io_state.dump_minute_id=io_state.minute_id;
      io_state.discovery_minute_id=-1;
      m_last_discovery_minute=-1;
      io_state.resumed_from_persistence=false;
      io_state.stage_publishability_state="not_ready";

      return true;
     }

   static bool StageBoot(ISSX_EA1_State &io_state,
                         const string firm_id,
                         const string writer_boot_id,
                         const string writer_nonce)
     {
      if(!StageBoot(io_state))
         return false;

      string unused_json="";
      BuildUniverseDump(io_state,firm_id,writer_boot_id,writer_nonce,unused_json);
      return true;
     }

   static bool StageSlice(ISSX_EA1_State &io_state,
                          const string firm_id,
                          const string writer_boot_id,
                          const string writer_nonce,
                          const int max_symbols=0)
     {
      io_state.discovery_attempted=false;
      io_state.discovery_skipped=false;
      io_state.discovery_success=false;
      io_state.discovery_no_change=false;
      io_state.discovery_elapsed_ms=0;
      io_state.discovery_status_reason="none";

      int current_minute=(int)(TimeCurrent()/60);
      io_state.minute_id=current_minute;

      io_state.discovery_attempted=false;
      io_state.discovery_skipped=false;
      io_state.discovery_success=false;
      io_state.discovery_no_change=false;
      io_state.discovery_elapsed_ms=0;
      io_state.discovery_status_reason="none";

      const bool discovery_due=(io_state.sequence_no<=0 || io_state.discovery_minute_id!=current_minute);
      if(discovery_due)
        {
         io_state.discovery_attempted=true;
         const int symbols_before=ArraySize(io_state.symbols);
         const ulong t0=GetTickCount();
         const bool discovery_ok=DiscoverUniverse(io_state,false,max_symbols);
         io_state.discovery_elapsed_ms=(int)(GetTickCount()-t0);
         io_state.discovery_success=discovery_ok;
         io_state.discovery_no_change=(ArraySize(io_state.symbols)==symbols_before);
         io_state.discovery_minute_id=current_minute;
         io_state.discovery_skip_streak=0;
         io_state.discovery_status_reason=(discovery_ok ? "discovery_success" : "no_symbols_discovered");
        }
      else
        {
         io_state.discovery_skipped=true;
         io_state.discovery_skip_streak++;
         io_state.discovery_status_reason="cadence_same_minute";
         io_state.discovery_elapsed_ms=0;
      }

      if(max_symbols>0 && ArraySize(io_state.symbols)>max_symbols)
         ArrayResize(io_state.symbols,max_symbols);

      BuildIdentityPhase(io_state);
      CanonicalizeDeterministicOrder(io_state);
      BuildRuntimePhase(io_state);
      BuildClassificationPhase(io_state);
      BuildTradeabilityPhase(io_state);
      BuildGateAndContinuityPhase(io_state);

      io_state.sequence_no++;
      io_state.dump_sequence_no=io_state.sequence_no;
      io_state.dump_minute_id=io_state.minute_id;

      return true;
     }

   static bool StagePublish(ISSX_EA1_State &io_state,
                            const string firm_id,
                            const string writer_boot_id,
                            const string writer_nonce,
                            string &out_stage_json,
                            string &out_debug_snapshot_json)
     {
      io_state.scheduler.phase_id=ISSX_EA1_MapToRuntimePhase(issx_ea1_phase_publish);
      out_stage_json=BuildStageSummaryJson(io_state);
      out_debug_snapshot_json=BuildDebugSnapshotJson(io_state,firm_id,writer_boot_id,writer_nonce);

      if(out_stage_json=="")
         return false;
      if(out_debug_snapshot_json=="")
         return false;

      return WriteInternalUniverseDump(io_state,firm_id,writer_boot_id,writer_nonce);
     }

   static string BuildDebugSnapshotJson(const ISSX_EA1_State &state,
                                        const string firm_id,
                                        const string writer_boot_id,
                                        const string writer_nonce)
     {
      ISSX_JsonWriter j;
      j.BeginObject();
      j.NameString("stage_id","ea1");
      j.NameString("owner_module_name","issx_market_engine.mqh");
      j.NameString("owner_module_hash",HashString(ISSX_MARKET_ENGINE_MODULE_VERSION));
      j.NameString("firm_id",firm_id);
      j.NameString("writer_boot_id",writer_boot_id);
      j.NameString("writer_nonce",writer_nonce);
      j.NameString("schema_version",ISSX_SCHEMA_VERSION);
      j.NameString("policy_fingerprint",state.policy_fingerprint);
      j.NameString("taxonomy_hash",state.taxonomy_hash);
      j.NameString("comparator_registry_hash",state.comparator_registry_hash);
      j.NameString("fingerprint_algorithm_version",state.fingerprint_algorithm_version);
      j.NameBool("stage_minimum_ready_flag",state.stage_minimum_ready_flag);
      j.NameString("stage_publishability_state",StagePublishabilityText(state.stage_publishability_state));
      j.NameBool("degraded_flag",state.degraded_flag);
      j.NameBool("publishable",state.publishable);
      j.NameString("dependency_block_reason",state.dependency_block_reason);
      j.NameString("debug_weak_link_code",state.debug_weak_link_code);
      j.NameInt("broker_universe",state.universe.broker_universe);
      j.NameInt("eligible_universe",state.universe.eligible_universe);
      j.NameInt("active_universe",state.universe.active_universe);
      j.NameInt("rankable_universe",state.universe.rankable_universe);
      j.NameInt("publishable_universe",state.universe.publishable_universe);
      j.NameInt("changed_symbol_count",state.deltas.changed_symbol_count);
      j.NameString("changed_symbol_ids_compact",state.deltas.changed_symbol_ids_compact);
      j.NameInt("listed_count",state.counters.listed_count);
      j.NameInt("metadata_ready_count",state.counters.metadata_ready_count);
      j.NameInt("probe_ready_count",state.counters.probe_ready_count);
      j.NameInt("rank_candidate_count",state.counters.rank_candidate_count);
      j.NameInt("degraded_count",state.counters.degraded_count);
      j.NameInt("blocked_count",state.counters.blocked_count);
      j.NameInt("accepted_strong_count",state.counters.accepted_strong_count);
      j.NameInt("accepted_degraded_count",state.counters.accepted_degraded_count);
      j.NameInt("rejected_count",state.counters.rejected_count);
      j.NameInt("cooldown_count",state.counters.cooldown_count);
      j.NameInt("stale_usable_count",state.counters.stale_usable_count);
      j.NameString("contradiction_severity_max",HudSeverityText(state.counters.contradiction_severity_max));
      j.NameString("broker_universe_fingerprint",state.universe.broker_universe_fingerprint);
      j.NameString("eligible_universe_fingerprint",state.universe.eligible_universe_fingerprint);
      j.NameString("active_universe_fingerprint",state.universe.active_universe_fingerprint);
      j.NameString("rankable_universe_fingerprint",state.universe.rankable_universe_fingerprint);
      j.NameString("frontier_universe_fingerprint",state.universe.frontier_universe_fingerprint);
      j.NameString("publishable_universe_fingerprint",state.universe.publishable_universe_fingerprint);
      j.NameDouble("percent_universe_touched_recent",state.universe.percent_universe_touched_recent,4);
      j.NameDouble("percent_rankable_revalidated_recent",state.universe.percent_rankable_revalidated_recent,4);
      j.NameDouble("percent_frontier_revalidated_recent",state.universe.percent_frontier_revalidated_recent,4);
      j.NameInt("never_serviced_count",state.universe.never_serviced_count);
      j.NameInt("overdue_service_count",state.universe.overdue_service_count);
      j.NameInt("newly_active_symbols_waiting_count",state.universe.newly_active_symbols_waiting_count);
      j.NameInt("never_ranked_but_eligible_count",state.universe.never_ranked_but_eligible_count);
      j.NameInt("contradiction_count",state.counters.contradiction_count);
      j.NameInt("contradiction_severity_max",state.counters.contradiction_severity_max);
      j.NameInt("phase_id",(int)state.scheduler.phase_id);
      j.NameInt("sequence_no",state.sequence_no);
      j.NameInt("minute_id",state.minute_id);
      j.EndObject();
      return j.ToString();
     }

   static string BuildStageJson(const ISSX_EA1_State &state)
     {
      return BuildStageSummaryJson(state);
     }

   static string BuildDebugSnapshot(const ISSX_EA1_State &state)
     {
      return BuildDebugSnapshotJson(state,"","","");
     }

   static string BuildDebugJson(const ISSX_EA1_State &state)
     {
      return BuildDebugSnapshot(state);
     }

   static string ExportOptionalIntelligence(const ISSX_EA1_State &state)
     {
      return BuildStageJson(state);
     }
  };



string ISSX_MarketDiagTag()
  {
   return "market_diag_v172f";
  }


string ISSX_MarketEngineDebugSignature()
  {
   return ISSX_MarketDiagTag();
  }

int ISSX_MarketEngine::m_last_discovery_minute=-1;

#endif // __ISSX_MARKET_ENGINE_MQH__
