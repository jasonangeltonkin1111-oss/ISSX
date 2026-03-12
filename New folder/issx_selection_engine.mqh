#ifndef __ISSX_SELECTION_ENGINE_MQH__
#define __ISSX_SELECTION_ENGINE_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>
#include <ISSX/issx_market_engine.mqh>
#include <ISSX/issx_history_engine.mqh>

// ============================================================================
// ISSX SELECTION ENGINE v1.722
// EA3 shared engine for SelectionCore.
//
// BLUEPRINT ALIGNMENT NOTES
// - canonical ISSX include identity only
// - no duplicate shared-owner enums / DTOs / JSON writers
// - stage API normalized to StageBoot / StageSlice / StagePublish / BuildDebugSnapshot
// - family collapse happens before rank
// - publish fewer than 5 when bucket truth is weak
// - continuity protects near ties only; repeated weak holds decay
// - completed-bar safety is upstream-owned by EA2 and consumed as truth class / freshness class
// - degraded / unknown semantics remain explicit
// ============================================================================

#define ISSX_SELECTION_ENGINE_MODULE_VERSION "1.732"
#define ISSX_SELECTION_ENGINE_STAGE_API_VERSION "ea3_stage_api_v1"
#define ISSX_SELECTION_ENGINE_SERIALIZER_VERSION "ea3_json_v1"

#define ISSX_EA3_TOP5_LIMIT                  5
#define ISSX_EA3_RESERVE_LIMIT               3
#define ISSX_EA3_FRONTIER_SOFT_LIMIT         48
#define ISSX_EA3_DEBUG_FRONTIER_LIMIT        12
#define ISSX_EA3_MAX_CANDIDATES_PER_CYCLE    1024
#define ISSX_EA3_MAX_RANKED_PER_BUCKET       256
#define ISSX_EA3_PROGRESS_LOG_STEP           64

// ============================================================================
// SECTION 01: PHASE IDS / LOCAL ENUMS
// ============================================================================

enum ISSX_EA3_PhaseId
  {
   issx_ea3_phase_load_upstream = 0,
   issx_ea3_phase_restore_survivor_state,
   issx_ea3_phase_build_bucket_sets_delta_first,
   issx_ea3_phase_collapse_families,
   issx_ea3_phase_rank_buckets,
   issx_ea3_phase_assign_reserves,
   issx_ea3_phase_build_frontier,
   issx_ea3_phase_update_survivor_continuity,
   issx_ea3_phase_publish
  };

enum ISSX_EA3_PositionSecurityClass
  {
   issx_ea3_security_fragile = 0,
   issx_ea3_security_contested,
   issx_ea3_security_stable,
   issx_ea3_security_locked
  };

enum ISSX_EA3_BucketStrengthClass
  {
   issx_ea3_bucket_weak = 0,
   issx_ea3_bucket_fair,
   issx_ea3_bucket_strong
  };

// ============================================================================
// SECTION 02: DTOs / STATE
// ============================================================================

struct ISSX_EA3_HysteresisKnobs
  {
   double enter_threshold;
   double hold_threshold;
   double override_gap;
   double weak_hold_decay_step;
   int    max_weak_hold_count;

   void Reset()
     {
      enter_threshold=0.45;
      hold_threshold=0.40;
      override_gap=0.08;
      weak_hold_decay_step=0.05;
      max_weak_hold_count=3;
     }
  };

struct ISSX_EA3_SurvivorMemory
  {
   string symbol_norm;
   string bucket_id;
   bool   was_top5;
   bool   was_frontier;
   int    survivor_age_cycles;
   int    weak_hold_count;
   int    last_seen_minute_id;

   void Reset()
     {
      symbol_norm="";
      bucket_id="";
      was_top5=false;
      was_frontier=false;
      survivor_age_cycles=0;
      weak_hold_count=0;
      last_seen_minute_id=0;
     }
  };

struct ISSX_EA3_SymbolSelection
  {
   string                         symbol_raw;
   string                         symbol_norm;
   string                         canonical_root;
   string                         alias_family_id;
   string                         leader_bucket_id;
   ISSX_LeaderBucketType          leader_bucket_type;

   double                         observability_score;
   double                         trade_cost_usability_score;
   double                         history_data_quality_score;
   double                         classification_reliability_score;
   double                         stability_score;

   double                         bucket_local_composite;
   int                            bucket_rank;
   int                            bucket_top5_rank;
   bool                           won_by_strength;
   bool                           won_by_shortfall;
   bool                           won_on_hysteresis_only_flag;
   double                         bucket_competition_percentile;
   int                            bucket_member_quality_rank;
   double                         nearest_reserve_gap;
   double                         replacement_pressure;
   ISSX_EA3_PositionSecurityClass position_security_class;
   string                         not_top5_reason_primary;
   string                         not_top5_reason_secondary;
   string                         reserve_promotion_condition;
   string                         reserve_blockers;
   double                         reserve_confidence;
   int                            reserve_age_cycles;
   string                         frontier_entry_reason_primary;
   string                         frontier_entry_reason_secondary;
   double                         frontier_confidence;
   double                         frontier_survival_risk;
   double                         peer_comparability_score;
   double                         bucket_comparison_completeness;
   double                         comparison_penalty;
   bool                           spec_only_cheapness_flag;
   double                         micro_cleanliness_score;
   double                         overlap_noise_score;
   double                         range_efficiency_score;
   int                            survivor_age_cycles;
   double                         survivor_churn_penalty;
   string                         upstream_instability_sources;
   int                            incumbent_weak_hold_count;
   double                         hysteresis_decay_score;
   bool                           challenger_override_ready;

   bool                           selected_top5;
   bool                           selected_reserve;
   bool                           selected_frontier;
   bool                           duplicate_family_rejected;
   bool                           rankable;
   ISSX_RankabilityLane           rankability_lane;
   double                         exploratory_penalty_applied;
   string                         replacement_reason_code;
   string                         winner_archetype_class;
   bool                           reserve_promoted_for_diversity_flag;
   string                         redundancy_swap_reason;
   string                         dependency_block_reason;
   ISSX_TruthClass                truth_class;
   ISSX_FreshnessClass            freshness_class;
   ISSX_AcceptanceType            acceptance_type;

   void Reset()
     {
      symbol_raw="";
      symbol_norm="";
      canonical_root="";
      alias_family_id="";
      leader_bucket_id="other";
      leader_bucket_type=issx_leader_bucket_theme_bucket;

      observability_score=0.0;
      trade_cost_usability_score=0.0;
      history_data_quality_score=0.0;
      classification_reliability_score=0.0;
      stability_score=0.0;

      bucket_local_composite=0.0;
      bucket_rank=0;
      bucket_top5_rank=0;
      won_by_strength=false;
      won_by_shortfall=false;
      won_on_hysteresis_only_flag=false;
      bucket_competition_percentile=0.0;
      bucket_member_quality_rank=0;
      nearest_reserve_gap=0.0;
      replacement_pressure=0.0;
      position_security_class=issx_ea3_security_fragile;
      not_top5_reason_primary="none";
      not_top5_reason_secondary="none";
      reserve_promotion_condition="none";
      reserve_blockers="none";
      reserve_confidence=0.0;
      reserve_age_cycles=0;
      frontier_entry_reason_primary="none";
      frontier_entry_reason_secondary="none";
      frontier_confidence=0.0;
      frontier_survival_risk=1.0;
      peer_comparability_score=0.0;
      bucket_comparison_completeness=0.0;
      comparison_penalty=0.0;
      spec_only_cheapness_flag=false;
      micro_cleanliness_score=0.0;
      overlap_noise_score=0.0;
      range_efficiency_score=0.0;
      survivor_age_cycles=0;
      survivor_churn_penalty=0.0;
      upstream_instability_sources="none";
      incumbent_weak_hold_count=0;
      hysteresis_decay_score=0.0;
      challenger_override_ready=false;

      selected_top5=false;
      selected_reserve=false;
      selected_frontier=false;
      duplicate_family_rejected=false;
      rankable=false;
      rankability_lane=issx_rankability_blocked;
      exploratory_penalty_applied=0.0;
      replacement_reason_code="none";
      winner_archetype_class="unknown";
      reserve_promoted_for_diversity_flag=false;
      redundancy_swap_reason="none";
      dependency_block_reason="none";
      truth_class=issx_truth_unknown;
      freshness_class=issx_freshness_unknown;
      acceptance_type=issx_acceptance_rejected;
     }
  };

struct ISSX_EA3_BucketState
  {
   string                       bucket_id;
   ISSX_LeaderBucketType        bucket_type;
   string                       bucket_label;
   int                          member_indices[];
   int                          ranked_indices[];
   int                          reserve_indices[];
   int                          top5_indices[];
   int                          frontier_indices[];
   int                          strong_count;
   int                          compare_safe_count;
   int                          degraded_count;
   ISSX_EA3_BucketStrengthClass strength_class;
   string                       bucket_confidence_class;
   string                       bucket_instability_reason;
   double                       bucket_opportunity_density;
   string                       bucket_redundancy_state;
   string                       bucket_primary_thinning_reason;
   double                       bucket_redundancy_penalty;

   void Reset()
     {
      bucket_id="other";
      bucket_type=issx_leader_bucket_theme_bucket;
      bucket_label="other";
      ArrayResize(member_indices,0);
      ArrayResize(ranked_indices,0);
      ArrayResize(reserve_indices,0);
      ArrayResize(top5_indices,0);
      ArrayResize(frontier_indices,0);
      strong_count=0;
      compare_safe_count=0;
      degraded_count=0;
      strength_class=issx_ea3_bucket_weak;
      bucket_confidence_class="unknown";
      bucket_instability_reason="none";
      bucket_opportunity_density=0.0;
      bucket_redundancy_state="unknown";
      bucket_primary_thinning_reason="none";
      bucket_redundancy_penalty=0.0;
     }
  };

struct ISSX_EA3_FrontierItem
  {
   string symbol_raw;
   string symbol_norm;
   string bucket_id;
   int    bucket_rank;
   double frontier_confidence;
   double frontier_survival_risk;
   string entry_reason_primary;
   string entry_reason_secondary;
   bool   selected_top5;
   bool   selected_reserve;

   void Reset()
     {
      symbol_norm="";
      bucket_id="";
      bucket_rank=0;
      frontier_confidence=0.0;
      frontier_survival_risk=1.0;
      entry_reason_primary="none";
      entry_reason_secondary="none";
      selected_top5=false;
      selected_reserve=false;
     }
  };

struct ISSX_EA3_UniverseState
  {
   int    broker_universe;
   int    eligible_universe;
   int    active_universe;
   int    rankable_universe;
   int    frontier_universe;
   int    publishable_universe;
   string broker_universe_fingerprint;
   string eligible_universe_fingerprint;
   string active_universe_fingerprint;
   string rankable_universe_fingerprint;
   string frontier_universe_fingerprint;
   string publishable_universe_fingerprint;
   string universe_drift_class;
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
      frontier_universe=0;
      publishable_universe=0;
      broker_universe_fingerprint="";
      eligible_universe_fingerprint="";
      active_universe_fingerprint="";
      rankable_universe_fingerprint="";
      frontier_universe_fingerprint="";
      publishable_universe_fingerprint="";
      universe_drift_class="none";
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

struct ISSX_EA3_DeltaState
  {
   int    changed_bucket_count;
   int    changed_frontier_count;
   int    changed_symbol_count;
   string changed_bucket_ids_compact;
   string changed_symbol_ids_compact;

   void Reset()
     {
      changed_bucket_count=0;
      changed_frontier_count=0;
      changed_symbol_count=0;
      changed_bucket_ids_compact="";
      changed_symbol_ids_compact="";
     }
  };

struct ISSX_EA3_CycleCounters
  {
   int strong_lane_count;
   int usable_lane_count;
   int exploratory_lane_count;
   int blocked_count;
   int top5_count;
   int reserve_count;
   int frontier_count;
   int duplicate_family_reject_count;
   int selected_by_hysteresis_count;
   int selected_by_shortfall_count;
   int reserve_promoted_for_diversity_count;
   int accepted_strong_count;
   int accepted_degraded_count;
   int rejected_count;
   int stale_usable_count;

   void Reset()
     {
      strong_lane_count=0;
      usable_lane_count=0;
      exploratory_lane_count=0;
      blocked_count=0;
      top5_count=0;
      reserve_count=0;
      frontier_count=0;
      duplicate_family_reject_count=0;
      selected_by_hysteresis_count=0;
      selected_by_shortfall_count=0;
      reserve_promoted_for_diversity_count=0;
      accepted_strong_count=0;
      accepted_degraded_count=0;
      rejected_count=0;
      stale_usable_count=0;
     }
  };

struct ISSX_EA3_State
  {
   ISSX_StageHeader         header;
   ISSX_Manifest            manifest;
   ISSX_RuntimeState        runtime;
   ISSX_EA3_HysteresisKnobs hysteresis;
   ISSX_EA3_UniverseState   universe;
   ISSX_EA3_DeltaState      delta;
   ISSX_EA3_CycleCounters   counters;
   string                   upstream_source_used;
   string                   upstream_source_reason;
   ISSX_CompatibilityClass  upstream_compatibility_class;
   double                   upstream_compatibility_score;
   int                      fallback_depth_used;
   double                   fallback_penalty_applied;
   bool                     projection_partial_success_flag;
   bool                     degraded_flag;
   bool                     recovery_publish_flag;
   bool                     stage_minimum_ready_flag;
   ISSX_PublishabilityState stage_publishability_state;
   string                   dependency_block_reason;
   ISSX_DebugWeakLinkCode   debug_weak_link_code;
   string                   taxonomy_hash;
   string                   comparator_registry_hash;
   string                   cohort_fingerprint;
   string                   policy_fingerprint;
   int                      fingerprint_algorithm_version;
   ISSX_EA3_SurvivorMemory  survivor_memory[];
   ISSX_EA3_SymbolSelection symbols[];
   ISSX_EA3_BucketState     buckets[];
   ISSX_EA3_FrontierItem    frontier[];

   void Reset()
     {
      header.Reset();
      manifest.Reset();
      runtime.Reset();
      hysteresis.Reset();
      universe.Reset();
      delta.Reset();
      counters.Reset();
      upstream_source_used="none";
      upstream_source_reason="none";
      upstream_compatibility_class=issx_compatibility_incompatible;
      upstream_compatibility_score=0.0;
      fallback_depth_used=0;
      fallback_penalty_applied=0.0;
      projection_partial_success_flag=false;
      degraded_flag=false;
      recovery_publish_flag=false;
      stage_minimum_ready_flag=false;
      stage_publishability_state=issx_publishability_not_ready;
      dependency_block_reason="na";
      debug_weak_link_code=issx_weak_link_none;
      taxonomy_hash="";
      comparator_registry_hash="";
      cohort_fingerprint="";
      policy_fingerprint="";
      fingerprint_algorithm_version=ISSX_FINGERPRINT_ALGO_VERSION;
      ArrayResize(survivor_memory,0);
      ArrayResize(symbols,0);
      ArrayResize(buckets,0);
      ArrayResize(frontier,0);
     }
  };

// ============================================================================
// SECTION 03: SELECTION ENGINE
// ============================================================================

class ISSX_SelectionEngine
  {
private:
   static double Clamp01(const double v)
     {
      if(v<0.0)
         return 0.0;
      if(v>1.0)
         return 1.0;
      return v;
     }

   static ISSX_PhaseId MapLocalPhaseToRuntimePhase(const ISSX_EA3_PhaseId local_phase)
     {
      switch(local_phase)
        {
         case issx_ea3_phase_load_upstream:                 return issx_phase_ea3_load_upstream;
         case issx_ea3_phase_restore_survivor_state:        return issx_phase_ea3_restore;
         case issx_ea3_phase_build_bucket_sets_delta_first: return issx_phase_ea3_build_bucket_sets_delta_first;
         case issx_ea3_phase_collapse_families:             return issx_phase_ea3_family_collapse;
         case issx_ea3_phase_rank_buckets:                  return issx_phase_ea3_rank_buckets;
         case issx_ea3_phase_assign_reserves:               return issx_phase_ea3_assign_reserves;
         case issx_ea3_phase_build_frontier:                return issx_phase_ea3_build_frontier;
         case issx_ea3_phase_update_survivor_continuity:    return issx_phase_ea3_update_survivor_continuity;
         case issx_ea3_phase_publish:                       return issx_phase_ea3_publish;
         default:                                           return issx_phase_none;
        }
     }

   static void ResetRuntimeForPhase(ISSX_EA3_State &state,ISSX_EA3_PhaseId phase_id)
     {
      state.runtime.local_phase_id=(int)phase_id;
      state.runtime.current_phase=MapLocalPhaseToRuntimePhase(phase_id);
      state.runtime.current_phase_label=ISSX_Runtime::PhaseIdToString(state.runtime.current_phase);
     }

   static string PhaseToText(ISSX_EA3_PhaseId phase_id)
     {
      switch(phase_id)
        {
         case issx_ea3_phase_load_upstream:                 return "load_upstream";
         case issx_ea3_phase_restore_survivor_state:        return "restore_survivor_state";
         case issx_ea3_phase_build_bucket_sets_delta_first: return "build_bucket_sets_delta_first";
         case issx_ea3_phase_collapse_families:             return "collapse_families";
         case issx_ea3_phase_rank_buckets:                  return "rank_buckets";
         case issx_ea3_phase_assign_reserves:               return "assign_reserves";
         case issx_ea3_phase_build_frontier:                return "build_frontier";
         case issx_ea3_phase_update_survivor_continuity:    return "update_survivor_continuity";
         case issx_ea3_phase_publish:                       return "publish";
         default:                                           return "unknown";
        }
     }

   static string RankabilityLaneToText(const ISSX_RankabilityLane lane)
     {
      switch(lane)
        {
         case issx_rankability_strong:      return "strong";
         case issx_rankability_usable:      return "usable";
         case issx_rankability_exploratory: return "exploratory";
         default:                           return "blocked";
        }
     }

   static string PublishabilityToText(const ISSX_PublishabilityState state_value)
     {
      switch(state_value)
        {
         case issx_publishability_strong:          return "strong";
         case issx_publishability_usable:          return "usable";
         case issx_publishability_usable_degraded: return "usable_degraded";
         case issx_publishability_warmup:          return "warmup";
         default:                                  return "not_ready";
        }
     }

   static string CompatibilityToText(const ISSX_CompatibilityClass v)
     {
      if(v==issx_compat_exact)               return "same_tick";
      if(v==issx_compat_consumer_compatible) return "current";
      if(v==issx_compat_storage_compatible)  return "previous";
      if(v==issx_compat_policy_degraded)     return "last_good";
      if(v==issx_compat_schema_only)         return "schema_only";
      if(v==issx_compat_incompatible)        return "incompatible";
      return "unknown";
     }

   static string WeakLinkCodeToText(const ISSX_DebugWeakLinkCode v)
     {
      if(v==issx_weak_link_publish_stale)    return "publish_stale";
      if(v==issx_weak_link_queue_backlog)    return "rankable_thin";
      if(v==issx_weak_link_dependency_block) return "upstream_missing";
      if(v==issx_weak_link_family_collapse)  return "family_collapse";
      if(v==issx_weak_link_frontier_thin)    return "frontier_thin";
      if(v==issx_weak_link_bucket_depth)     return "bucket_depth";
      return "none";
     }

   static string BucketStrengthToText(const ISSX_EA3_BucketStrengthClass v)
     {
      switch(v)
        {
         case issx_ea3_bucket_strong: return "strong";
         case issx_ea3_bucket_fair:   return "fair";
         default:                     return "weak";
        }
     }

   static string SecurityClassToText(const ISSX_EA3_PositionSecurityClass v)
     {
      switch(v)
        {
         case issx_ea3_security_locked:    return "locked";
         case issx_ea3_security_stable:    return "stable";
         case issx_ea3_security_contested: return "contested";
         default:                          return "fragile";
        }
     }

   static string TruthClassToText(const ISSX_TruthClass v)
     {
      if(v==issx_truth_strong)     return "verified";
      if(v==issx_truth_acceptable) return "partial";
      if(v==issx_truth_degraded)   return "estimated";
      return "unknown";
     }

   static string FreshnessClassToText(const ISSX_FreshnessClass v)
     {
      if(v==issx_freshness_fresh)  return "fresh";
      if(v==issx_freshness_usable) return "recent";
      if(v==issx_freshness_aging)  return "stale";
      if(v==issx_freshness_stale)  return "expired";
      return "unknown";
     }

   static void SelectionDebug(const string event_name,const string details)
     {
      Print("ISSX_EA3 ",event_name,": ",details);
     }

   static string SelectionBoolText(const bool v)
     {
      return (v ? "true" : "false");
     }

   static bool IsCandidateCapacityExceeded(ISSX_EA3_State &state)
     {
      return (ArraySize(state.symbols)>=ISSX_EA3_MAX_CANDIDATES_PER_CYCLE);
     }


   static bool IsUsableHistory(ISSX_EA2_SymbolState &ea2_symbol)
     {
      return (ea2_symbol.history_ready_for_ranking || ea2_symbol.acceptance_type>=issx_acceptance_for_ranking);
     }

   static bool HasCompareSafeTrust(ISSX_EA2_SymbolState &ea2_symbol)
     {
      if(ea2_symbol.tf[issx_ea2_tf_m5].metric_compare_class>=issx_metric_compare_bucket_safe)
         return true;
      if(ea2_symbol.tf[issx_ea2_tf_m15].metric_compare_class>=issx_metric_compare_bucket_safe)
         return true;
      if(ea2_symbol.tf[issx_ea2_tf_h1].metric_compare_class>=issx_metric_compare_bucket_safe)
         return true;
      return false;
     }

   static bool IsTradeabilityBlocked(const ISSX_TradeabilityClass v)
     {
      return (v==issx_tradeability_blocked);
     }

   static double RuntimeTruthScoreCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      double s=0.45*Clamp01(ea1_symbol.validated_runtime_truth.session_truth_confidence)
              +0.25*Clamp01(ea1_symbol.validated_runtime_truth.observation_density_score)
              +0.20*(ea1_symbol.validated_runtime_truth.observed_quote_liveness ? 1.0 : 0.0)
              +0.10*(ea1_symbol.validated_runtime_truth.quote_recent_flag ? 1.0 : 0.0);
      return Clamp01(s);
     }

   static double BlendedTradeabilityScoreCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      double s=0.35*Clamp01(ea1_symbol.tradeability_baseline.friction_quality_score)
              +0.25*Clamp01(ea1_symbol.tradeability_baseline.spread_quality_score)
              +0.25*Clamp01(ea1_symbol.tradeability_baseline.cost_quality_score)
              +0.15*Clamp01(ea1_symbol.tradeability_baseline.fee_stability_score);
      s*=(1.0-0.50*Clamp01(ea1_symbol.tradeability_baseline.tradeability_penalty));
      if(ea1_symbol.tradeability_baseline.blocked_for_ranking || ea1_symbol.tradeability_baseline.blocked_for_trading)
         s=0.0;
      return Clamp01(s);
     }

   static double EntryCostScoreCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      return Clamp01(0.60*ea1_symbol.tradeability_baseline.cost_quality_score
                    +0.40*ea1_symbol.tradeability_baseline.spread_quality_score);
     }

   static double SizePracticalityScoreCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      double s=1.0;
      if(ea1_symbol.tradeability_baseline.minimum_ticket_money>0.0)
         s=1.0/(1.0+ea1_symbol.tradeability_baseline.minimum_ticket_money);
      if(ea1_symbol.tradeability_baseline.excessive_stop_level_flag)
         s*=0.80;
      if(ea1_symbol.tradeability_baseline.excessive_freeze_level_flag)
         s*=0.85;
      return Clamp01(s);
     }

   static double EconomicConsistencyScoreCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      double s=0.50*Clamp01(ea1_symbol.tradeability_baseline.cost_quality_score)
              +0.50*Clamp01(ea1_symbol.tradeability_baseline.fee_stability_score);
      if(!ea1_symbol.tradeability_baseline.cost_complete)
         s*=0.60;
      return Clamp01(s);
     }

   static double MicrostructureSafetyScoreCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      double s=0.60*Clamp01(ea1_symbol.tradeability_baseline.spread_quality_score)
              +0.40*(1.0-Clamp01(ea1_symbol.validated_runtime_truth.spread_widening_ratio));
      if(ea1_symbol.tradeability_baseline.excessive_freeze_level_flag)
         s*=0.75;
      if(ea1_symbol.tradeability_baseline.excessive_stop_level_flag)
         s*=0.85;
      return Clamp01(s);
     }

   static double SmallAccountUsabilityScoreCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      double s=1.0;
      if(ea1_symbol.tradeability_baseline.minimum_ticket_money>0.0)
         s=1.0/(1.0+0.50*ea1_symbol.tradeability_baseline.minimum_ticket_money);
      return Clamp01(s);
     }

   static double ToxicityScoreCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      return Clamp01(0.70*ea1_symbol.tradeability_baseline.tradeability_penalty
                    +0.30*ea1_symbol.validated_runtime_truth.spread_widening_ratio);
     }

   static double LiveCostDeviationScoreCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      return Clamp01(ea1_symbol.validated_runtime_truth.current_vs_normal_spread_percentile);
     }

   static double TaxonomyReliabilityScoreCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      return Clamp01(0.60*ea1_symbol.classification_truth.classification_reliability_score
                    +0.40*ea1_symbol.classification_truth.native_taxonomy_quality);
     }

   static bool ClassificationNeedsReviewCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      return (ea1_symbol.classification_truth.taxonomy_action_taken==issx_taxonomy_manual_review_only
              || ea1_symbol.classification_truth.taxonomy_conflict_scope!="none"
              || ea1_symbol.classification_truth.classification_hard_block);
     }

   static double GatePassCyclesCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      double s=0.0;
      if(ea1_symbol.rankability_gate.rankable_flag)
         s+=0.55;
      if(ea1_symbol.rankability_gate.publishable_flag)
         s+=0.25;
      s+=0.20*Clamp01(ea1_symbol.rankability_gate.readiness_score);
      return Clamp01(s);
     }

   static double GateFlapCountCompat(ISSX_EA1_SymbolState &ea1_symbol)
     {
      return Clamp01((double)ea1_symbol.rankability_gate.contradiction_count/5.0);
     }

   static ISSX_RankabilityLane DeriveLane(ISSX_EA1_SymbolState &ea1_symbol,ISSX_EA2_SymbolState &ea2_symbol)
     {
      if(ea1_symbol.rankability_gate.hard_block_flag || ea1_symbol.rankability_gate.same_family_merged_away_flag)
         return issx_rankability_blocked;

      if(!ea1_symbol.rankability_gate.rankable_flag)
        {
         if(ea1_symbol.rankability_gate.exploratory_only_flag && IsUsableHistory(ea2_symbol))
            return issx_rankability_exploratory;
         return issx_rankability_blocked;
        }

      if(IsTradeabilityBlocked(ea1_symbol.tradeability_baseline.tradeability_class))
         return issx_rankability_blocked;

      if(ea2_symbol.history_ready_for_ranking && HasCompareSafeTrust(ea2_symbol) && ea1_symbol.classification_truth.bucket_publishable)
         return issx_rankability_strong;

      if(IsUsableHistory(ea2_symbol))
         return issx_rankability_usable;

      if(ea1_symbol.rankability_gate.exploratory_only_flag)
         return issx_rankability_exploratory;

      return issx_rankability_blocked;
     }

   static bool IsSymbolRankable(ISSX_EA1_SymbolState &ea1_symbol,ISSX_EA2_SymbolState &ea2_symbol)
     {
      if(!ea1_symbol.rankability_gate.rankable_flag)
         return false;
      if(ea1_symbol.rankability_gate.hard_block_flag)
         return false;
      if(IsTradeabilityBlocked(ea1_symbol.tradeability_baseline.tradeability_class))
         return false;
      if(ea1_symbol.tradeability_baseline.blocked_for_ranking)
         return false;
      if(!ea2_symbol.history_ready_for_ranking)
         return false;
      if(ea2_symbol.judgment.history_data_quality_score<0.25)
         return false;
      if(ea1_symbol.classification_truth.classification_reliability_score<0.20)
         return false;
      return true;
     }

   static double ComputeObservabilityScore(ISSX_EA1_SymbolState &ea1_symbol)
     {
      const double obs=0.45*RuntimeTruthScoreCompat(ea1_symbol)
                      +0.25*ea1_symbol.validated_runtime_truth.observation_density_score
                      +0.20*(1.0-Clamp01(ea1_symbol.validated_runtime_truth.observation_gap_risk))
                      +0.10*ea1_symbol.validated_runtime_truth.market_sampling_quality_score;
      return Clamp01(obs);
     }

   static double ComputeTradeCostUsabilityScore(ISSX_EA1_SymbolState &ea1_symbol)
     {
      double base=0.35*BlendedTradeabilityScoreCompat(ea1_symbol)
                 +0.20*EntryCostScoreCompat(ea1_symbol)
                 +0.15*SizePracticalityScoreCompat(ea1_symbol)
                 +0.10*EconomicConsistencyScoreCompat(ea1_symbol)
                 +0.10*MicrostructureSafetyScoreCompat(ea1_symbol)
                 +0.10*SmallAccountUsabilityScoreCompat(ea1_symbol);

      base*=(1.0-0.15*ToxicityScoreCompat(ea1_symbol));
      base*=(1.0-0.10*LiveCostDeviationScoreCompat(ea1_symbol));
      if(IsTradeabilityBlocked(ea1_symbol.tradeability_baseline.tradeability_class))
         base=0.0;

      return Clamp01(base);
     }

   static double ComputeHistoryQualityScore(ISSX_EA2_SymbolState &ea2_symbol)
     {
      double s=0.60*ea2_symbol.judgment.history_data_quality_score
              +0.15*ea2_symbol.judgment.metric_trust_score
              +0.15*ea2_symbol.judgment.continuity_score
              +0.10*(1.0-ea2_symbol.judgment.gap_risk_score);

      if(!ea2_symbol.history_ready_for_ranking)
         s*=0.50;
      if(ea2_symbol.provenance.temporary_rank_suspension)
         s*=0.35;

      return Clamp01(s);
     }

   static double ComputeClassificationReliabilityScore(ISSX_EA1_SymbolState &ea1_symbol)
     {
      double s=0.55*ea1_symbol.classification_truth.classification_reliability_score
              +0.25*TaxonomyReliabilityScoreCompat(ea1_symbol)
              +0.10*ea1_symbol.classification_truth.classification_confidence
              +0.10*Clamp01((double)ea1_symbol.classification_truth.bucket_assignment_stable_cycles/10.0);

      if(ClassificationNeedsReviewCompat(ea1_symbol))
         s*=0.70;
      if(ea1_symbol.classification_truth.native_vs_manual_conflict)
         s*=0.85;

      return Clamp01(s);
     }

   static double ComputeStabilityScore(ISSX_EA1_SymbolState &ea1_symbol,
                                       ISSX_EA2_SymbolState &ea2_symbol,
                                       const int survivor_age_cycles,
                                       const int weak_hold_count)
     {
      double recovery_component=1.0;
      if(ea2_symbol.provenance.recovery_stability_cycles_required>0 && ea2_symbol.provenance.flap_count_recent>0)
         recovery_component=0.5;

      double s=0.25*GatePassCyclesCompat(ea1_symbol)
              +0.20*Clamp01((double)ea1_symbol.classification_truth.bucket_assignment_stable_cycles/10.0)
              +0.20*(1.0-GateFlapCountCompat(ea1_symbol))
              +0.15*(1.0-Clamp01(ea2_symbol.provenance.history_flap_risk))
              +0.20*Clamp01(recovery_component);

      if(survivor_age_cycles>0)
        {
         s=0.75*s + 0.25*Clamp01((double)survivor_age_cycles/10.0);
         s*=(1.0-0.10*Clamp01((double)weak_hold_count/5.0));
        }

      return Clamp01(s);
     }

   static double ComputeComposite(ISSX_EA3_SymbolSelection &s)
     {
      return Clamp01(0.40*s.trade_cost_usability_score
                    +0.20*s.observability_score
                    +0.20*s.history_data_quality_score
                    +0.10*s.classification_reliability_score
                    +0.10*s.stability_score);
     }

   static double ComputePeerComparability(ISSX_EA2_SymbolState &ea2_symbol)
     {
      double c=0.0;

      if(ea2_symbol.tf[issx_ea2_tf_m5].metric_compare_class>=issx_metric_compare_bucket_safe)
         c+=0.33;
      if(ea2_symbol.tf[issx_ea2_tf_m15].metric_compare_class>=issx_metric_compare_bucket_safe)
         c+=0.33;
      if(ea2_symbol.tf[issx_ea2_tf_h1].metric_compare_class>=issx_metric_compare_bucket_safe)
         c+=0.34;

      if(ea2_symbol.provenance.temporary_rank_suspension)
         c*=0.5;

      return Clamp01(c);
     }

   static double ComputeComparisonPenalty(ISSX_EA3_SymbolSelection &s)
     {
      const double lack=1.0-s.peer_comparability_score;
      return Clamp01(0.55*lack + 0.45*(1.0-s.bucket_comparison_completeness));
     }

   static double ComputeMicroCleanlinessScore(ISSX_EA1_SymbolState &ea1_symbol,ISSX_EA2_SymbolState &ea2_symbol)
     {
      const double s=0.35*MicrostructureSafetyScoreCompat(ea1_symbol)
                    +0.25*(1.0-Clamp01(ea2_symbol.structural_context.micro_noise_risk))
                    +0.20*ea2_symbol.structural_context.structure_clarity_score
                    +0.20*(1.0-Clamp01(ea1_symbol.validated_runtime_truth.quote_burstiness_score));
      return Clamp01(s);
     }

   static double ComputeRangeEfficiencyScore(ISSX_EA2_SymbolState &ea2_symbol)
     {
      const double s=0.40*ea2_symbol.hot_metrics.spread_to_atr_efficiency
                    +0.30*ea2_symbol.judgment.usable_range_score
                    +0.30*ea2_symbol.structural_context.structure_stability_score;
      return Clamp01(s);
     }

   static double ComputeOverlapNoiseScore(ISSX_EA1_SymbolState &ea1_symbol,ISSX_EA2_SymbolState &ea2_symbol)
     {
      const double s=0.50*Clamp01(ea1_symbol.validated_runtime_truth.quote_burstiness_score)
                    +0.25*Clamp01(ea1_symbol.validated_runtime_truth.spread_widening_ratio)
                    +0.25*Clamp01(ea2_symbol.structural_context.micro_noise_risk);
      return Clamp01(s);
     }

   static int FindEA2Index(ISSX_EA2_State &ea2,const string symbol_norm)
     {
      for(int i=0;i<ArraySize(ea2.symbols);i++)
         if(ea2.symbols[i].symbol_norm==symbol_norm)
            return i;
      return -1;
     }

   static int FindSurvivorMemory(ISSX_EA3_State &state,const string symbol_norm)
     {
      for(int i=0;i<ArraySize(state.survivor_memory);i++)
         if(state.survivor_memory[i].symbol_norm==symbol_norm)
            return i;
      return -1;
     }

   static int FindBucket(ISSX_EA3_State &state,const string bucket_id,const ISSX_LeaderBucketType bucket_type)
     {
      for(int i=0;i<ArraySize(state.buckets);i++)
         if(state.buckets[i].bucket_id==bucket_id && state.buckets[i].bucket_type==bucket_type)
            return i;
      return -1;
     }

   static int EnsureBucket(ISSX_EA3_State &state,const string bucket_id,const ISSX_LeaderBucketType bucket_type)
     {
      int idx=FindBucket(state,bucket_id,bucket_type);
      if(idx>=0)
         return idx;

      idx=ArraySize(state.buckets);
      ArrayResize(state.buckets,idx+1);
      state.buckets[idx].Reset();
      state.buckets[idx].bucket_id=bucket_id;
      state.buckets[idx].bucket_type=bucket_type;
      state.buckets[idx].bucket_label=bucket_id;
      return idx;
     }

   static void PushIndex(int &arr[],const int value)
     {
      const int n=ArraySize(arr);
      ArrayResize(arr,n+1);
      arr[n]=value;
     }

   static bool ContainsString(string &arr[],const string value)
     {
      for(int i=0;i<ArraySize(arr);i++)
         if(arr[i]==value)
            return true;
      return false;
     }

   static bool ContainsInt(int &arr[],const int value)
     {
      for(int i=0;i<ArraySize(arr);i++)
         if(arr[i]==value)
            return true;
      return false;
     }

   static void CopySurvivorMemoryArray(ISSX_EA3_SurvivorMemory &src[],ISSX_EA3_SurvivorMemory &dst[])
     {
      const int n=ArraySize(src);
      ArrayResize(dst,n);
      for(int i=0;i<n;i++)
         dst[i]=src[i];
     }

   static void CopyFrontierSymbolNorms(ISSX_EA3_FrontierItem &src[],string &dst[])
     {
      const int n=ArraySize(src);
      ArrayResize(dst,n);
      for(int i=0;i<n;i++)
         dst[i]=src[i].symbol_norm;
     }

   static bool ContainsFrontierSymbol(ISSX_EA3_FrontierItem &frontier_items[],const string symbol_norm)
     {
      for(int i=0;i<ArraySize(frontier_items);i++)
         if(frontier_items[i].symbol_norm==symbol_norm)
            return true;
      return false;
     }

   static int CountFrontierMembershipChanges(string &previous_frontier[],ISSX_EA3_FrontierItem &current_frontier[])
     {
      int changed=0;

      for(int i=0;i<ArraySize(previous_frontier);i++)
         if(!ContainsFrontierSymbol(current_frontier,previous_frontier[i]))
            changed++;

      for(int j=0;j<ArraySize(current_frontier);j++)
         if(!ContainsString(previous_frontier,current_frontier[j].symbol_norm))
            changed++;

      return changed;
     }

   static string BuildStableFingerprint(string &items[])
     {
      string local[];
      const int n=ArraySize(items);

      ArrayResize(local,n);
      for(int i=0;i<n;i++)
         local[i]=items[i];

      ISSX_Util::SortStringsInPlace(local);

      string joined="";
      for(int j=0;j<n;j++)
        {
         if(j>0)
            joined+="|";
         joined+=local[j];
        }

      return ISSX_Hash::HashStringHex(joined);
     }

   static int FamilyRepresentativeForBucket(ISSX_EA3_State &state,const int bucket_idx,const string alias_family_id)
     {
      int    best=-1;
      double best_score=-1.0;
      const int n=ArraySize(state.buckets[bucket_idx].member_indices);

      for(int i=0;i<n;i++)
        {
         const int sym_idx=state.buckets[bucket_idx].member_indices[i];
         if(state.symbols[sym_idx].alias_family_id!=alias_family_id)
            continue;

         const double continuity_bonus=Clamp01((double)state.symbols[sym_idx].survivor_age_cycles/10.0)*0.03;
         const double score=state.symbols[sym_idx].bucket_local_composite+continuity_bonus;

         if(best<0 || score>best_score)
           {
            best=sym_idx;
            best_score=score;
           }
        }

      return best;
     }

   static void SortIndicesByComposite(ISSX_EA3_State &state,int &indices[])
     {
      const int n=ArraySize(indices);
      for(int i=0;i<n-1;i++)
        {
         int best=i;
         for(int j=i+1;j<n;j++)
           {
            const int idx_a=indices[j];
            const int idx_b=indices[best];

            if(state.symbols[idx_a].bucket_local_composite>state.symbols[idx_b].bucket_local_composite)
               best=j;
            else if(state.symbols[idx_a].bucket_local_composite==state.symbols[idx_b].bucket_local_composite)
              {
               if(state.symbols[idx_a].stability_score>state.symbols[idx_b].stability_score)
                  best=j;
               else if(state.symbols[idx_a].stability_score==state.symbols[idx_b].stability_score &&
                       state.symbols[idx_a].peer_comparability_score>state.symbols[idx_b].peer_comparability_score)
                  best=j;
              }
           }

         if(best!=i)
           {
            const int tmp=indices[i];
            indices[i]=indices[best];
            indices[best]=tmp;
           }
        }
     }

   static bool WasTop5LastCycle(ISSX_EA3_State &state,const string symbol_norm)
     {
      const int idx=FindSurvivorMemory(state,symbol_norm);
      return (idx>=0 && state.survivor_memory[idx].was_top5);
     }

   static void RefreshDerivedUniverseCoverage(ISSX_EA3_State &state)
     {
      state.universe.percent_universe_touched_recent=
         (state.universe.broker_universe>0 ? 100.0*(double)state.universe.active_universe/(double)state.universe.broker_universe : 0.0);

      state.universe.percent_rankable_revalidated_recent=
         (state.universe.rankable_universe>0 ? 100.0 : 0.0);

      state.universe.percent_frontier_revalidated_recent=
         (state.universe.frontier_universe>0 ? 100.0 : 0.0);

      state.universe.never_serviced_count=MathMax(0,state.universe.eligible_universe-state.universe.active_universe);
      state.universe.overdue_service_count=0;
      state.universe.never_ranked_but_eligible_count=MathMax(0,state.universe.eligible_universe-state.universe.rankable_universe);
      state.universe.newly_active_symbols_waiting_count=MathMax(0,state.universe.active_universe-state.universe.frontier_universe);
      state.universe.near_cutline_recheck_age_max=0;
     }

   static void UpdateHeaderAndManifest(ISSX_EA3_State &state,const string firm_id)
     {
      const int minute_id=(int)ISSX_Time::NowMinuteId();

      state.header.Reset();
      state.header.stage_id=issx_stage_ea3;
      state.header.firm_id=firm_id;
      state.header.sequence_no=state.runtime.scheduler_cycle_no;
      state.header.minute_id=minute_id;
      state.header.symbol_count=ArraySize(state.symbols);
      state.header.changed_symbol_count=state.delta.changed_symbol_count;
      state.header.degraded_flag=state.degraded_flag;
      state.header.fallback_depth_used=state.fallback_depth_used;
      state.header.cohort_fingerprint=state.cohort_fingerprint;
      state.header.universe_fingerprint=state.universe.frontier_universe_fingerprint;
      state.header.policy_fingerprint=state.policy_fingerprint;
      state.header.fingerprint_algorithm_version=state.fingerprint_algorithm_version;
      state.header.writer_generation=state.runtime.scheduler_cycle_no;
      state.header.trio_generation_id=ISSX_Util::LongToStringX((long)state.runtime.scheduler_cycle_no)+"_"+ISSX_Util::LongToStringX((long)minute_id);

      state.manifest.Reset();
      state.manifest.stage_id=issx_stage_ea3;
      state.manifest.firm_id=firm_id;
      state.manifest.sequence_no=state.header.sequence_no;
      state.manifest.minute_id=state.header.minute_id;
      state.manifest.writer_generation=state.header.writer_generation;
      state.manifest.trio_generation_id=state.header.trio_generation_id;
      state.manifest.symbol_count=state.header.symbol_count;
      state.manifest.changed_symbol_count=state.header.changed_symbol_count;
      state.manifest.content_class=issx_content_partial;
      state.manifest.publish_reason=issx_publish_scheduled;
      state.manifest.cohort_fingerprint=state.cohort_fingerprint;
      state.manifest.taxonomy_hash=state.taxonomy_hash;
      state.manifest.comparator_registry_hash=state.comparator_registry_hash;
      state.manifest.policy_fingerprint=state.policy_fingerprint;
      state.manifest.fingerprint_algorithm_version=state.fingerprint_algorithm_version;
      state.manifest.universe_fingerprint=state.universe.frontier_universe_fingerprint;
      state.manifest.degraded_flag=state.degraded_flag;
      state.manifest.fallback_depth_used=state.fallback_depth_used;
      state.manifest.accepted_strong_count=state.counters.accepted_strong_count;
      state.manifest.accepted_degraded_count=state.counters.accepted_degraded_count;
      state.manifest.rejected_count=state.counters.rejected_count;
      state.manifest.stale_usable_count=state.counters.stale_usable_count;
      state.manifest.stage_minimum_ready_flag=state.stage_minimum_ready_flag;
      state.manifest.stage_publishability_state=state.stage_publishability_state;
      state.manifest.projection_partial_success_flag=state.projection_partial_success_flag;
      state.manifest.handoff_mode=issx_handoff_internal_current;
      state.manifest.handoff_sequence_no=state.header.sequence_no;
     }

   static void InheritUpstreamContext(ISSX_EA3_State &state,ISSX_EA1_State &ea1,ISSX_EA2_State &ea2)
     {
      state.taxonomy_hash=ea1.taxonomy_hash;
      state.comparator_registry_hash=ea1.comparator_registry_hash;
      state.cohort_fingerprint=ea1.cohort_fingerprint;
      state.policy_fingerprint=ea1.policy_fingerprint;
      state.fingerprint_algorithm_version=ISSX_FINGERPRINT_ALGO_VERSION;

      state.universe.broker_universe=ea1.universe.broker_universe;
      state.universe.eligible_universe=ea1.universe.eligible_universe;
      state.universe.active_universe=ea1.universe.active_universe;
      state.universe.rankable_universe=ea2.universe.rankable_universe;
      state.universe.broker_universe_fingerprint=ea1.universe.broker_universe_fingerprint;
      state.universe.eligible_universe_fingerprint=ea1.universe.eligible_universe_fingerprint;
      state.universe.active_universe_fingerprint=ea1.universe.active_universe_fingerprint;
      state.universe.rankable_universe_fingerprint=ea2.universe.rankable_universe_fingerprint;
      state.universe.universe_drift_class=ea2.universe.universe_drift_class;

      state.upstream_source_used="same_tick";
      state.upstream_source_reason="ea1_ea2_accepted_current";
      state.upstream_compatibility_class=issx_compatibility_same_tick;
      state.upstream_compatibility_score=1.0;
      state.fallback_depth_used=0;
      state.fallback_penalty_applied=0.0;
      state.projection_partial_success_flag=false;
      state.degraded_flag=false;
      state.recovery_publish_flag=false;
      state.stage_minimum_ready_flag=false;
      state.stage_publishability_state=issx_publishability_not_ready;
      state.dependency_block_reason="none";
      state.debug_weak_link_code=issx_weak_link_none;
     }

   static void RestoreSurvivorMemory(ISSX_EA3_State &state,ISSX_EA3_SurvivorMemory &previous_memory[])
     {
      CopySurvivorMemoryArray(previous_memory,state.survivor_memory);
     }

   static void BuildBucketSets(ISSX_EA3_State &state,ISSX_EA1_State &ea1,ISSX_EA2_State &ea2)
     {
      ArrayResize(state.symbols,0);
      ArrayResize(state.buckets,0);
      state.counters.Reset();
      state.delta.Reset();

      SelectionDebug("selection_batch_start",
                     "phase=build_bucket_sets ea1_symbols="+ISSX_Util::IntToStringX(ArraySize(ea1.symbols))+
                     " ea2_symbols="+ISSX_Util::IntToStringX(ArraySize(ea2.symbols))+
                     " candidate_cap="+ISSX_Util::IntToStringX(ISSX_EA3_MAX_CANDIDATES_PER_CYCLE));

      for(int i=0;i<ArraySize(ea1.symbols);i++)
        {
         if((i>0) && ((i%ISSX_EA3_PROGRESS_LOG_STEP)==0))
            SelectionDebug("selection_batch_progress",
                           "phase=build_bucket_sets scanned="+ISSX_Util::IntToStringX(i)+
                           " candidates="+ISSX_Util::IntToStringX(ArraySize(state.symbols))+
                           " buckets="+ISSX_Util::IntToStringX(ArraySize(state.buckets)));

         SelectionDebug("selection_discovery_attempt",
                        "symbol_norm="+ea1.symbols[i].normalized_identity.symbol_norm+
                        " index="+ISSX_Util::IntToStringX(i));

         const int hidx=FindEA2Index(ea2,ea1.symbols[i].normalized_identity.symbol_norm);
         if(hidx<0)
           {
            SelectionDebug("selection_candidate_filtered",
                           "symbol_norm="+ea1.symbols[i].normalized_identity.symbol_norm+
                           " reason=missing_ea2_history_link");
            continue;
           }

         ISSX_EA3_SymbolSelection s;
         s.Reset();

         s.symbol_raw=ea1.symbols[i].raw_broker_observation.symbol_raw;
         s.symbol_norm=ea1.symbols[i].normalized_identity.symbol_norm;
         s.canonical_root=ea1.symbols[i].normalized_identity.canonical_root;
         s.alias_family_id=ea1.symbols[i].normalized_identity.alias_family_id;
         s.leader_bucket_id=ea1.symbols[i].classification_truth.leader_bucket_id;
         s.leader_bucket_type=ea1.symbols[i].classification_truth.leader_bucket_type;
         s.rankability_lane=DeriveLane(ea1.symbols[i],ea2.symbols[hidx]);
         s.rankable=IsSymbolRankable(ea1.symbols[i],ea2.symbols[hidx]);
         s.truth_class=ea2.symbols[hidx].truth_class;
         s.freshness_class=ea2.symbols[hidx].freshness_class;
         s.acceptance_type=ea2.symbols[hidx].acceptance_type;

         if(s.rankability_lane==issx_rankability_strong)
            state.counters.strong_lane_count++;
         else if(s.rankability_lane==issx_rankability_usable)
            state.counters.usable_lane_count++;
         else if(s.rankability_lane==issx_rankability_exploratory)
            state.counters.exploratory_lane_count++;
         else
            state.counters.blocked_count++;

         s.observability_score=ComputeObservabilityScore(ea1.symbols[i]);
         s.trade_cost_usability_score=ComputeTradeCostUsabilityScore(ea1.symbols[i]);
         s.history_data_quality_score=ComputeHistoryQualityScore(ea2.symbols[hidx]);
         s.classification_reliability_score=ComputeClassificationReliabilityScore(ea1.symbols[i]);
         s.peer_comparability_score=ComputePeerComparability(ea2.symbols[hidx]);
         s.bucket_comparison_completeness=s.peer_comparability_score;
         s.comparison_penalty=ComputeComparisonPenalty(s);
         s.micro_cleanliness_score=ComputeMicroCleanlinessScore(ea1.symbols[i],ea2.symbols[hidx]);
         s.range_efficiency_score=ComputeRangeEfficiencyScore(ea2.symbols[hidx]);
         s.overlap_noise_score=ComputeOverlapNoiseScore(ea1.symbols[i],ea2.symbols[hidx]);
         s.spec_only_cheapness_flag=(!ea2.symbols[hidx].history_ready_for_ranking &&
                                     ea1.symbols[i].tradeability_baseline.tradeability_class<=issx_tradeability_cheap);

         const int mem_idx=FindSurvivorMemory(state,s.symbol_norm);
         if(mem_idx>=0)
           {
            s.survivor_age_cycles=state.survivor_memory[mem_idx].survivor_age_cycles;
            s.incumbent_weak_hold_count=state.survivor_memory[mem_idx].weak_hold_count;
           }

         s.stability_score=ComputeStabilityScore(ea1.symbols[i],ea2.symbols[hidx],s.survivor_age_cycles,s.incumbent_weak_hold_count);
         s.bucket_local_composite=ComputeComposite(s);
         s.bucket_local_composite*=1.0-0.25*s.comparison_penalty;

         if(s.rankability_lane==issx_rankability_exploratory)
           {
            s.exploratory_penalty_applied=0.20;
            s.bucket_local_composite*=0.80;
            s.dependency_block_reason="exploratory_quality_cap";
           }

         s.upstream_instability_sources=(ea2.symbols[hidx].provenance.history_flap_risk>0.50 ? "history_flap" : "none");
         if(GateFlapCountCompat(ea1.symbols[i])>0.0)
            s.upstream_instability_sources=(s.upstream_instability_sources=="none" ? "rank_gate_flap" : s.upstream_instability_sources+"|rank_gate_flap");

         if(mem_idx>=0 && state.survivor_memory[mem_idx].was_top5)
           {
            s.hysteresis_decay_score=Clamp01((double)state.survivor_memory[mem_idx].weak_hold_count/10.0);
            s.bucket_local_composite*=1.0-(s.hysteresis_decay_score*state.hysteresis.weak_hold_decay_step);
           }

         if(s.leader_bucket_id=="")
            s.leader_bucket_id="other";

         if(ea1.symbols[i].changed_since_last_cycle || ea2.symbols[hidx].changed_since_last_publish)
           {
            state.delta.changed_symbol_count++;
            state.delta.changed_symbol_ids_compact=(state.delta.changed_symbol_ids_compact=="" ? s.symbol_norm : state.delta.changed_symbol_ids_compact+"|"+s.symbol_norm);
           }

         if(IsCandidateCapacityExceeded(state))
           {
            state.degraded_flag=true;
            state.projection_partial_success_flag=true;
            state.dependency_block_reason="candidate_cap_reached";
            state.debug_weak_link_code=issx_weak_link_queue_backlog;
            SelectionDebug("selection_error_conditions",
                           "reason=candidate_cap_reached cap="+ISSX_Util::IntToStringX(ISSX_EA3_MAX_CANDIDATES_PER_CYCLE));
            break;
           }

         const int out_idx=ArraySize(state.symbols);
         ArrayResize(state.symbols,out_idx+1);
         state.symbols[out_idx]=s;

         const int bucket_idx=EnsureBucket(state,s.leader_bucket_id,s.leader_bucket_type);
         PushIndex(state.buckets[bucket_idx].member_indices,out_idx);

         SelectionDebug("selection_candidate_added",
                        "symbol_norm="+s.symbol_norm+
                        " bucket="+s.leader_bucket_id+
                        " lane="+RankabilityLaneToText(s.rankability_lane)+
                        " composite="+DoubleToString(s.bucket_local_composite,6));
        }

      string bucket_keys[];
      ArrayResize(bucket_keys,0);

      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         SelectionDebug("selection_batch_progress",
                        "phase=bucket_health bucket="+state.buckets[b].bucket_id+
                        " members="+ISSX_Util::IntToStringX(ArraySize(state.buckets[b].member_indices)));
         const int n=ArraySize(state.buckets[b].member_indices);
         state.buckets[b].strong_count=0;
         state.buckets[b].compare_safe_count=0;
         state.buckets[b].degraded_count=0;

         for(int i=0;i<n;i++)
           {
            const int idx=state.buckets[b].member_indices[i];
            if(state.symbols[idx].rankability_lane==issx_rankability_strong)
               state.buckets[b].strong_count++;
            if(state.symbols[idx].peer_comparability_score>=0.66)
               state.buckets[b].compare_safe_count++;
            if(state.symbols[idx].rankability_lane==issx_rankability_usable || state.symbols[idx].rankability_lane==issx_rankability_exploratory)
               state.buckets[b].degraded_count++;
           }

         if(state.buckets[b].strong_count>=ISSX_EA3_TOP5_LIMIT)
            state.buckets[b].strength_class=issx_ea3_bucket_strong;
         else if(state.buckets[b].strong_count+state.buckets[b].compare_safe_count>=3)
            state.buckets[b].strength_class=issx_ea3_bucket_fair;
         else
            state.buckets[b].strength_class=issx_ea3_bucket_weak;

         state.buckets[b].bucket_confidence_class=(state.buckets[b].strength_class==issx_ea3_bucket_strong ? "strong"
                                                 : state.buckets[b].strength_class==issx_ea3_bucket_fair ? "moderate"
                                                 : "weak");
         state.buckets[b].bucket_instability_reason=(state.buckets[b].strong_count<=0 ? "thin_strong_lane" : "none");
         state.buckets[b].bucket_opportunity_density=Clamp01((double)ArraySize(state.buckets[b].member_indices)/10.0);
         state.buckets[b].bucket_redundancy_state="unchecked";
         state.buckets[b].bucket_primary_thinning_reason=(state.buckets[b].degraded_count>state.buckets[b].strong_count ? "degraded_mix" : "none");
         state.buckets[b].bucket_redundancy_penalty=Clamp01((double)(n-state.buckets[b].strong_count)/(double)MathMax(1,n))*0.15;

         const int k=ArraySize(bucket_keys);
         ArrayResize(bucket_keys,k+1);
         bucket_keys[k]=state.buckets[b].bucket_id+"#"+ISSX_Util::IntToStringX((int)state.buckets[b].bucket_type);
        }

      state.universe.rankable_universe_fingerprint=BuildStableFingerprint(bucket_keys);
      state.universe.publishable_universe_fingerprint=state.universe.rankable_universe_fingerprint;

      SelectionDebug("selection_batch_complete",
                     "phase=build_bucket_sets candidates="+ISSX_Util::IntToStringX(ArraySize(state.symbols))+
                     " buckets="+ISSX_Util::IntToStringX(ArraySize(state.buckets))+
                     " changed_symbols="+ISSX_Util::IntToStringX(state.delta.changed_symbol_count));
     }

   static void CollapseFamilies(ISSX_EA3_State &state)
     {
      SelectionDebug("selection_batch_start","phase=collapse_families buckets="+ISSX_Util::IntToStringX(ArraySize(state.buckets)));

      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         int kept_indices[];
         ArrayResize(kept_indices,0);

         string seen_families[];
         ArrayResize(seen_families,0);

         const int n=ArraySize(state.buckets[b].member_indices);
         for(int i=0;i<n;i++)
           {
            const int idx=state.buckets[b].member_indices[i];
            string fam=state.symbols[idx].alias_family_id;
            if(StringLen(fam)<=0)
               fam=state.symbols[idx].symbol_norm;

            if(ContainsString(seen_families,fam))
              {
               state.symbols[idx].duplicate_family_rejected=true;
               state.symbols[idx].not_top5_reason_primary="family_collapse";
               state.counters.duplicate_family_reject_count++;
               SelectionDebug("selection_candidate_filtered",
                              "symbol_norm="+state.symbols[idx].symbol_norm+" reason=family_collapse bucket="+state.buckets[b].bucket_id);
               continue;
              }

            const int rep=FamilyRepresentativeForBucket(state,b,fam);
            if(rep==idx)
              {
               PushIndex(kept_indices,idx);
               const int sf=ArraySize(seen_families);
               ArrayResize(seen_families,sf+1);
               seen_families[sf]=fam;
              }
            else
              {
               state.symbols[idx].duplicate_family_rejected=true;
               state.symbols[idx].not_top5_reason_primary="family_collapse";
               state.counters.duplicate_family_reject_count++;
               SelectionDebug("selection_candidate_filtered",
                              "symbol_norm="+state.symbols[idx].symbol_norm+" reason=family_collapse_non_rep bucket="+state.buckets[b].bucket_id);
              }
           }

         ArrayResize(state.buckets[b].member_indices,ArraySize(kept_indices));
         for(int j=0;j<ArraySize(kept_indices);j++)
            state.buckets[b].member_indices[j]=kept_indices[j];

         state.buckets[b].bucket_redundancy_state=(ArraySize(kept_indices)<n ? "family_collapsed" : "clean");
         if(ArraySize(kept_indices)<n)
           {
            state.delta.changed_bucket_count++;
            state.delta.changed_bucket_ids_compact=(state.delta.changed_bucket_ids_compact=="" ? state.buckets[b].bucket_id : state.delta.changed_bucket_ids_compact+"|"+state.buckets[b].bucket_id);
           }
        }
      SelectionDebug("selection_batch_complete",
                     "phase=collapse_families duplicate_rejects="+ISSX_Util::IntToStringX(state.counters.duplicate_family_reject_count));
     }

   static void RankBuckets(ISSX_EA3_State &state)
     {
      SelectionDebug("selection_batch_start","phase=rank_buckets buckets="+ISSX_Util::IntToStringX(ArraySize(state.buckets)));

      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         int ranked[];
         ArrayResize(ranked,0);

         const int member_n=ArraySize(state.buckets[b].member_indices);
         for(int i=0;i<member_n;i++)
           {
            const int idx=state.buckets[b].member_indices[i];
            if(state.symbols[idx].rankability_lane==issx_rankability_blocked)
               continue;
            PushIndex(ranked,idx);
           }

         if(ArraySize(ranked)>ISSX_EA3_MAX_RANKED_PER_BUCKET)
           {
            SelectionDebug("selection_error_conditions",
                           "reason=ranked_bucket_cap bucket="+state.buckets[b].bucket_id+
                           " before="+ISSX_Util::IntToStringX(ArraySize(ranked))+
                           " cap="+ISSX_Util::IntToStringX(ISSX_EA3_MAX_RANKED_PER_BUCKET));
            ArrayResize(ranked,ISSX_EA3_MAX_RANKED_PER_BUCKET);
            state.degraded_flag=true;
            state.projection_partial_success_flag=true;
           }

         SortIndicesByComposite(state,ranked);

         ArrayResize(state.buckets[b].ranked_indices,ArraySize(ranked));
         for(int j=0;j<ArraySize(ranked);j++)
            state.buckets[b].ranked_indices[j]=ranked[j];
        }

      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         ArrayResize(state.buckets[b].top5_indices,0);

         const int n=ArraySize(state.buckets[b].ranked_indices);
         for(int i=0;i<n;i++)
           {
            const int idx=state.buckets[b].ranked_indices[i];

            if((i>0) && ((i%ISSX_EA3_PROGRESS_LOG_STEP)==0))
               SelectionDebug("selection_batch_progress",
                              "phase=rank_buckets bucket="+state.buckets[b].bucket_id+
                              " progress="+ISSX_Util::IntToStringX(i)+"/"+ISSX_Util::IntToStringX(n));

            state.symbols[idx].bucket_rank=i+1;
            state.symbols[idx].bucket_member_quality_rank=i+1;
            state.symbols[idx].bucket_competition_percentile=(n>1 ? 1.0-((double)i/(double)(n-1)) : 1.0);

            if(i<ISSX_EA3_TOP5_LIMIT && n>ISSX_EA3_TOP5_LIMIT)
               state.symbols[idx].nearest_reserve_gap=state.symbols[idx].bucket_local_composite
                                                     -state.symbols[state.buckets[b].ranked_indices[ISSX_EA3_TOP5_LIMIT]].bucket_local_composite;
            else
               state.symbols[idx].nearest_reserve_gap=0.0;

            bool allow_select=(i<ISSX_EA3_TOP5_LIMIT);
            if(allow_select && state.symbols[idx].bucket_local_composite<state.hysteresis.enter_threshold)
              {
               const bool incumbent=WasTop5LastCycle(state,state.symbols[idx].symbol_norm) &&
                                    state.symbols[idx].bucket_local_composite>=state.hysteresis.hold_threshold;

               if(!incumbent)
                 {
                  allow_select=false;
                  state.symbols[idx].not_top5_reason_primary="below_enter_threshold";
                  SelectionDebug("selection_candidate_filtered",
                                 "symbol_norm="+state.symbols[idx].symbol_norm+" reason=below_enter_threshold");
                 }
               else
                 {
                  state.symbols[idx].won_on_hysteresis_only_flag=true;
                  state.counters.selected_by_hysteresis_count++;
                 }
              }

            if(allow_select)
              {
               PushIndex(state.buckets[b].top5_indices,idx);
               state.symbols[idx].selected_top5=true;
               state.symbols[idx].bucket_top5_rank=ArraySize(state.buckets[b].top5_indices);
               state.symbols[idx].won_by_strength=(state.symbols[idx].rankability_lane==issx_rankability_strong);
               state.symbols[idx].won_by_shortfall=(state.symbols[idx].rankability_lane!=issx_rankability_strong);
               state.symbols[idx].winner_archetype_class=
                  (state.symbols[idx].rankability_lane==issx_rankability_strong ? "strong_primary"
                   : state.symbols[idx].rankability_lane==issx_rankability_usable ? "usable_support"
                   : "exploratory_fill");

               state.symbols[idx].replacement_reason_code=
                  (state.symbols[idx].won_on_hysteresis_only_flag ? "hysteresis_hold"
                   : state.symbols[idx].won_by_strength ? "strength_win"
                   : "shortfall_fill");

               state.symbols[idx].position_security_class=
                  (state.symbols[idx].bucket_top5_rank<=2 ? issx_ea3_security_locked
                   : state.symbols[idx].bucket_top5_rank<=4 ? issx_ea3_security_stable
                   : issx_ea3_security_contested);

               state.counters.top5_count++;
               SelectionDebug("selection_rank_calculated",
                              "symbol_norm="+state.symbols[idx].symbol_norm+
                              " bucket="+state.buckets[b].bucket_id+
                              " rank="+ISSX_Util::IntToStringX(state.symbols[idx].bucket_rank)+
                              " top5_rank="+ISSX_Util::IntToStringX(state.symbols[idx].bucket_top5_rank));
              }
            else
              {
               state.symbols[idx].position_security_class=issx_ea3_security_fragile;
               if(state.symbols[idx].not_top5_reason_primary=="none")
                  state.symbols[idx].not_top5_reason_primary="rank_cutline";
              }
           }

         if(ArraySize(state.buckets[b].top5_indices)<ISSX_EA3_TOP5_LIMIT && n>0)
           {
            for(int j=0;j<n && ArraySize(state.buckets[b].top5_indices)<ISSX_EA3_TOP5_LIMIT;j++)
              {
               const int idx=state.buckets[b].ranked_indices[j];
               if(state.symbols[idx].selected_top5)
                  continue;
               if(state.symbols[idx].rankability_lane==issx_rankability_blocked)
                  continue;

               if(state.buckets[b].strength_class==issx_ea3_bucket_weak &&
                  state.symbols[idx].rankability_lane==issx_rankability_exploratory &&
                  state.symbols[idx].bucket_local_composite<0.30)
                  continue;

               state.symbols[idx].selected_top5=true;
               state.symbols[idx].won_by_shortfall=true;
               state.symbols[idx].bucket_top5_rank=ArraySize(state.buckets[b].top5_indices)+1;
               state.symbols[idx].replacement_reason_code="shortfall_fill";
               state.symbols[idx].winner_archetype_class=(state.symbols[idx].rankability_lane==issx_rankability_exploratory ? "exploratory_fill" : "shortfall_fill");
               PushIndex(state.buckets[b].top5_indices,idx);
               state.counters.selected_by_shortfall_count++;
               state.counters.top5_count++;
               SelectionDebug("selection_rank_calculated",
                              "symbol_norm="+state.symbols[idx].symbol_norm+
                              " bucket="+state.buckets[b].bucket_id+
                              " rank="+ISSX_Util::IntToStringX(state.symbols[idx].bucket_rank)+
                              " top5_rank="+ISSX_Util::IntToStringX(state.symbols[idx].bucket_top5_rank));
              }
           }

         if(ArraySize(state.buckets[b].top5_indices)<=0)
            state.buckets[b].bucket_primary_thinning_reason="empty_after_rank";
         else if(ArraySize(state.buckets[b].top5_indices)<ISSX_EA3_TOP5_LIMIT)
            state.buckets[b].bucket_primary_thinning_reason="published_fewer_than_5";
        }
     }

   static void AssignReserves(ISSX_EA3_State &state)
     {
      SelectionDebug("selection_batch_start",
                     "phase=assign_reserves buckets="+ISSX_Util::IntToStringX(ArraySize(state.buckets))+
                     " top5_count="+ISSX_Util::IntToStringX(state.counters.top5_count));

      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         ArrayResize(state.buckets[b].reserve_indices,0);

         const int n=ArraySize(state.buckets[b].ranked_indices);
         for(int i=0;i<n && ArraySize(state.buckets[b].reserve_indices)<ISSX_EA3_RESERVE_LIMIT;i++)
           {
            const int idx=state.buckets[b].ranked_indices[i];
            if(state.symbols[idx].selected_top5)
               continue;

            PushIndex(state.buckets[b].reserve_indices,idx);
            state.symbols[idx].selected_reserve=true;
            state.symbols[idx].reserve_confidence=Clamp01(0.75*state.symbols[idx].bucket_local_composite + 0.25*state.symbols[idx].peer_comparability_score);
            state.symbols[idx].reserve_age_cycles=state.symbols[idx].survivor_age_cycles;
            state.symbols[idx].reserve_promotion_condition="winner_dropout_or_truth_gain";
            state.symbols[idx].reserve_blockers=(state.symbols[idx].rankability_lane==issx_rankability_exploratory ? "exploratory_penalty"
                                                : state.symbols[idx].comparison_penalty>0.40 ? "comparison_penalty"
                                                : "none");
            state.symbols[idx].reserve_promoted_for_diversity_flag=false;
            state.counters.reserve_count++;
            SelectionDebug("selection_rank_calculated",
                           "symbol_norm="+state.symbols[idx].symbol_norm+
                           " reserve_confidence="+DoubleToString(state.symbols[idx].reserve_confidence,6));
           }

         for(int i=0;i<ArraySize(state.buckets[b].top5_indices);i++)
           {
            const int top_idx=state.buckets[b].top5_indices[i];
            if(ArraySize(state.buckets[b].reserve_indices)>0)
               state.symbols[top_idx].nearest_reserve_gap=
                  state.symbols[top_idx].bucket_local_composite
                  -state.symbols[state.buckets[b].reserve_indices[0]].bucket_local_composite;
            else
               state.symbols[top_idx].nearest_reserve_gap=state.symbols[top_idx].bucket_local_composite;

            state.symbols[top_idx].replacement_pressure=Clamp01(1.0-state.symbols[top_idx].nearest_reserve_gap);
           }
        }
      SelectionDebug("selection_batch_complete",
                     "phase=assign_reserves reserve_count="+ISSX_Util::IntToStringX(state.counters.reserve_count));
     }

   static void BuildFrontier(ISSX_EA3_State &state)
     {
      SelectionDebug("selection_batch_start","phase=build_frontier buckets="+ISSX_Util::IntToStringX(ArraySize(state.buckets)));

      string previous_frontier[];
      ArrayResize(previous_frontier,0);
      CopyFrontierSymbolNorms(state.frontier,previous_frontier);

      ArrayResize(state.frontier,0);

      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         ArrayResize(state.buckets[b].frontier_indices,0);

         const int topn=ArraySize(state.buckets[b].top5_indices);
         for(int i=0;i<topn;i++)
           {
            const int idx=state.buckets[b].top5_indices[i];
            if(idx<0 || idx>=ArraySize(state.symbols))
              {
               Print("ISSX_EA3 BuildFrontier: skipping invalid top5 index=",idx," bucket=",b);
               continue;
              }

            const int out=ArraySize(state.frontier);
            ArrayResize(state.frontier,out+1);
            state.frontier[out].Reset();
             state.frontier[out].symbol_raw=state.symbols[idx].symbol_raw;
            state.frontier[out].symbol_norm=state.symbols[idx].symbol_norm;
            state.frontier[out].bucket_id=state.buckets[b].bucket_id;
            state.frontier[out].bucket_rank=state.symbols[idx].bucket_rank;
            state.frontier[out].frontier_confidence=Clamp01(state.symbols[idx].bucket_local_composite);
            state.frontier[out].frontier_survival_risk=Clamp01(0.55*state.symbols[idx].replacement_pressure + 0.45*state.symbols[idx].hysteresis_decay_score);
            state.frontier[out].entry_reason_primary="bucket_top5";
            state.frontier[out].entry_reason_secondary=state.symbols[idx].winner_archetype_class;
            state.frontier[out].selected_top5=true;

            state.symbols[idx].selected_frontier=true;
            state.symbols[idx].frontier_entry_reason_primary="bucket_top5";
            state.symbols[idx].frontier_entry_reason_secondary=state.symbols[idx].winner_archetype_class;
            state.symbols[idx].frontier_confidence=state.frontier[out].frontier_confidence;
            state.symbols[idx].frontier_survival_risk=state.frontier[out].frontier_survival_risk;

            PushIndex(state.buckets[b].frontier_indices,idx);
           }

         const int resn=ArraySize(state.buckets[b].reserve_indices);
         for(int j=0;j<resn && ArraySize(state.frontier)<ISSX_EA3_FRONTIER_SOFT_LIMIT;j++)
           {
            const int idx=state.buckets[b].reserve_indices[j];
            if(idx<0 || idx>=ArraySize(state.symbols))
              {
               Print("ISSX_EA3 BuildFrontier: skipping invalid reserve index=",idx," bucket=",b);
               continue;
              }

            const int out=ArraySize(state.frontier);
            ArrayResize(state.frontier,out+1);
            state.frontier[out].Reset();
             state.frontier[out].symbol_raw=state.symbols[idx].symbol_raw;
            state.frontier[out].symbol_norm=state.symbols[idx].symbol_norm;
            state.frontier[out].bucket_id=state.buckets[b].bucket_id;
            state.frontier[out].bucket_rank=state.symbols[idx].bucket_rank;
            state.frontier[out].frontier_confidence=Clamp01(0.90*state.symbols[idx].reserve_confidence);
            state.frontier[out].frontier_survival_risk=Clamp01(1.0-state.frontier[out].frontier_confidence);
            state.frontier[out].entry_reason_primary="reserve";
            state.frontier[out].entry_reason_secondary=state.symbols[idx].reserve_promotion_condition;
            state.frontier[out].selected_reserve=true;

            state.symbols[idx].selected_frontier=true;
            state.symbols[idx].frontier_entry_reason_primary="reserve";
            state.symbols[idx].frontier_entry_reason_secondary=state.symbols[idx].reserve_promotion_condition;
            state.symbols[idx].frontier_confidence=state.frontier[out].frontier_confidence;
            state.symbols[idx].frontier_survival_risk=state.frontier[out].frontier_survival_risk;

            PushIndex(state.buckets[b].frontier_indices,idx);
           }
        }

      string current_frontier_symbols[];
      ArrayResize(current_frontier_symbols,ArraySize(state.frontier));
      for(int i=0;i<ArraySize(state.frontier);i++)
         current_frontier_symbols[i]=state.frontier[i].symbol_norm;

      state.universe.frontier_universe=ArraySize(state.frontier);
      state.universe.publishable_universe=ArraySize(state.frontier);
      state.universe.frontier_universe_fingerprint=BuildStableFingerprint(current_frontier_symbols);
      state.universe.publishable_universe_fingerprint=state.universe.frontier_universe_fingerprint;
      state.delta.changed_frontier_count=CountFrontierMembershipChanges(previous_frontier,state.frontier);
      state.counters.frontier_count=ArraySize(state.frontier);

      if(ArraySize(state.frontier)<=0)
        {
         state.degraded_flag=true;
         state.dependency_block_reason="frontier_empty";
         state.debug_weak_link_code=issx_weak_link_frontier_thin;
         SelectionDebug("selection_error_conditions","reason=frontier_empty");
        }

      SelectionDebug("selection_batch_complete",
                     "phase=build_frontier frontier_count="+ISSX_Util::IntToStringX(ArraySize(state.frontier))+
                     " changed_frontier="+ISSX_Util::IntToStringX(state.delta.changed_frontier_count));
     }

   static void UpdateSurvivorContinuity(ISSX_EA3_State &state)
     {
      ISSX_EA3_SurvivorMemory next_mem[];
      ArrayResize(next_mem,0);

      int turnover_count=0;

      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         if(!state.symbols[i].selected_top5 && !state.symbols[i].selected_frontier && !state.symbols[i].selected_reserve)
            continue;

         const int old_idx=FindSurvivorMemory(state,state.symbols[i].symbol_norm);

         ISSX_EA3_SurvivorMemory m;
         m.Reset();
         m.symbol_norm=state.symbols[i].symbol_norm;
         m.bucket_id=state.symbols[i].leader_bucket_id;
         m.was_top5=state.symbols[i].selected_top5;
         m.was_frontier=state.symbols[i].selected_frontier;
         m.survivor_age_cycles=(old_idx>=0 ? state.survivor_memory[old_idx].survivor_age_cycles+1 : 1);
         m.weak_hold_count=(state.symbols[i].won_on_hysteresis_only_flag
                            ? (old_idx>=0 ? state.survivor_memory[old_idx].weak_hold_count+1 : 1)
                            : 0);
         m.last_seen_minute_id=(int)ISSX_Time::NowMinuteId();

         if(old_idx<0)
            turnover_count++;

         const int n=ArraySize(next_mem);
         ArrayResize(next_mem,n+1);
         next_mem[n]=m;

         state.symbols[i].survivor_age_cycles=m.survivor_age_cycles;
         state.symbols[i].reserve_age_cycles=m.survivor_age_cycles;
         state.symbols[i].incumbent_weak_hold_count=m.weak_hold_count;
         state.symbols[i].hysteresis_decay_score=Clamp01((double)m.weak_hold_count/5.0);
         state.symbols[i].challenger_override_ready=(state.symbols[i].replacement_pressure<0.20 &&
                                                     state.symbols[i].bucket_local_composite>=state.hysteresis.enter_threshold+0.05);
         state.symbols[i].survivor_churn_penalty=Clamp01((double)turnover_count/10.0);
        }

      ArrayResize(state.survivor_memory,ArraySize(next_mem));
      for(int j=0;j<ArraySize(next_mem);j++)
         state.survivor_memory[j]=next_mem[j];
     }

   static void EvaluateStageHealth(ISSX_EA3_State &state)
     {
      state.stage_minimum_ready_flag=(state.counters.top5_count>0 || state.counters.frontier_count>0);

      if(state.counters.top5_count>=ISSX_EA3_TOP5_LIMIT)
         state.stage_publishability_state=issx_publishability_strong;
      else if(state.counters.top5_count>0)
         state.stage_publishability_state=(state.degraded_flag ? issx_publishability_usable_degraded : issx_publishability_usable);
      else if(state.universe.rankable_universe>0)
         state.stage_publishability_state=issx_publishability_warmup;
      else
         state.stage_publishability_state=issx_publishability_not_ready;

      if(state.counters.top5_count<=0 && state.universe.rankable_universe<=0)
        {
         state.degraded_flag=true;
         state.dependency_block_reason="rankable_universe_empty";
         state.debug_weak_link_code=issx_weak_link_rankable_thin;
         SelectionDebug("selection_error_conditions","reason=rankable_universe_empty");
        }
      else if(state.counters.top5_count<=0)
        {
         state.degraded_flag=true;
         state.dependency_block_reason="top5_empty";
         state.debug_weak_link_code=issx_weak_link_bucket_depth;
        }
      else if(state.counters.duplicate_family_reject_count>0 && state.counters.top5_count<=2)
        {
         state.debug_weak_link_code=issx_weak_link_family_collapse;
        }

      state.counters.accepted_strong_count=(state.stage_publishability_state==issx_publishability_strong ? state.counters.top5_count : 0);
      state.counters.accepted_degraded_count=((state.stage_publishability_state==issx_publishability_usable ||
                                               state.stage_publishability_state==issx_publishability_usable_degraded)
                                              ? state.counters.top5_count : 0);
      state.counters.rejected_count=state.counters.blocked_count;
      state.counters.stale_usable_count=(state.degraded_flag ? state.counters.usable_lane_count : 0);

      SelectionDebug("selection_ready_state",
                     "minimum_ready="+SelectionBoolText(state.stage_minimum_ready_flag)+
                     " publishability="+PublishabilityToText(state.stage_publishability_state)+
                     " top5="+ISSX_Util::IntToStringX(state.counters.top5_count)+
                     " frontier="+ISSX_Util::IntToStringX(state.counters.frontier_count));

      if(state.stage_publishability_state==issx_publishability_warmup ||
         state.stage_publishability_state==issx_publishability_not_ready ||
         state.projection_partial_success_flag ||
         state.degraded_flag)
         SelectionDebug("selection_partial_state",
                        "publishability="+PublishabilityToText(state.stage_publishability_state)+
                        " degraded="+SelectionBoolText(state.degraded_flag)+
                        " partial_projection="+SelectionBoolText(state.projection_partial_success_flag)+
                        " dependency_block="+state.dependency_block_reason);
     }

   static void AppendJsonEscaped(string &json,const string value)
     {
      json+="\""+ISSX_JsonWriter::Escape(value)+"\"";
     }

   static void BuildBucketsJson(ISSX_EA3_State &state,string &json)
     {
      json+="\"buckets\":[";
      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         if(b>0)
            json+=",";
         json+="{";
         json+="\"bucket_id\":";
         AppendJsonEscaped(json,state.buckets[b].bucket_id);
         json+=",\"bucket_type\":";
         AppendJsonEscaped(json,ISSX_Util::IntToStringX((int)state.buckets[b].bucket_type));
         json+=",\"bucket_label\":";
         AppendJsonEscaped(json,state.buckets[b].bucket_label);
         json+=",\"strength_class\":";
         AppendJsonEscaped(json,BucketStrengthToText(state.buckets[b].strength_class));
         json+=",\"bucket_confidence_class\":";
         AppendJsonEscaped(json,state.buckets[b].bucket_confidence_class);
         json+=",\"bucket_instability_reason\":";
         AppendJsonEscaped(json,state.buckets[b].bucket_instability_reason);
         json+=",\"bucket_opportunity_density\":";
         json+=DoubleToString(state.buckets[b].bucket_opportunity_density,6);
         json+=",\"bucket_redundancy_state\":";
         AppendJsonEscaped(json,state.buckets[b].bucket_redundancy_state);
         json+=",\"bucket_primary_thinning_reason\":";
         AppendJsonEscaped(json,state.buckets[b].bucket_primary_thinning_reason);
         json+=",\"bucket_redundancy_penalty\":";
         json+=DoubleToString(state.buckets[b].bucket_redundancy_penalty,6);
         json+=",\"bucket_depth_strong\":";
         json+=ISSX_Util::IntToStringX(state.buckets[b].strong_count);
         json+=",\"bucket_depth_compare_safe\":";
         json+=ISSX_Util::IntToStringX(state.buckets[b].compare_safe_count);
         json+=",\"bucket_depth_degraded\":";
         json+=ISSX_Util::IntToStringX(state.buckets[b].degraded_count);
         json+=",\"member_count\":";
         json+=ISSX_Util::IntToStringX(ArraySize(state.buckets[b].member_indices));
         json+=",\"top5_count\":";
         json+=ISSX_Util::IntToStringX(ArraySize(state.buckets[b].top5_indices));
         json+=",\"reserve_count\":";
         json+=ISSX_Util::IntToStringX(ArraySize(state.buckets[b].reserve_indices));
         json+="}";
        }
      json+="]";
     }

   static void BuildSymbolsJson(ISSX_EA3_State &state,string &json)
     {
      json+="\"symbols\":[";
      bool first=true;
      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         if(!state.symbols[i].selected_top5 && !state.symbols[i].selected_reserve && !state.symbols[i].selected_frontier)
            continue;

         if(!first)
            json+=",";
         first=false;

         json+="{";
         json+="\"symbol_raw\":";
         AppendJsonEscaped(json,state.symbols[i].symbol_raw);
         json+=",\"symbol_norm\":";
         AppendJsonEscaped(json,state.symbols[i].symbol_norm);
         json+=",\"canonical_root\":";
         AppendJsonEscaped(json,state.symbols[i].canonical_root);
         json+=",\"alias_family_id\":";
         AppendJsonEscaped(json,state.symbols[i].alias_family_id);
         json+=",\"leader_bucket_id\":";
         AppendJsonEscaped(json,state.symbols[i].leader_bucket_id);
         json+=",\"leader_bucket_type\":";
         AppendJsonEscaped(json,ISSX_Util::IntToStringX((int)state.symbols[i].leader_bucket_type));
         json+=",\"observability_score\":";
         json+=DoubleToString(state.symbols[i].observability_score,6);
         json+=",\"trade_cost_usability_score\":";
         json+=DoubleToString(state.symbols[i].trade_cost_usability_score,6);
         json+=",\"history_data_quality_score\":";
         json+=DoubleToString(state.symbols[i].history_data_quality_score,6);
         json+=",\"classification_reliability_score\":";
         json+=DoubleToString(state.symbols[i].classification_reliability_score,6);
         json+=",\"stability_score\":";
         json+=DoubleToString(state.symbols[i].stability_score,6);
         json+=",\"bucket_local_composite\":";
         json+=DoubleToString(state.symbols[i].bucket_local_composite,6);
         json+=",\"bucket_rank\":";
         json+=ISSX_Util::IntToStringX(state.symbols[i].bucket_rank);
         json+=",\"bucket_top5_rank\":";
         json+=ISSX_Util::IntToStringX(state.symbols[i].bucket_top5_rank);
         json+=",\"won_by_strength\":";
         json+=(state.symbols[i].won_by_strength ? "true" : "false");
         json+=",\"won_by_shortfall\":";
         json+=(state.symbols[i].won_by_shortfall ? "true" : "false");
         json+=",\"won_on_hysteresis_only_flag\":";
         json+=(state.symbols[i].won_on_hysteresis_only_flag ? "true" : "false");
         json+=",\"bucket_competition_percentile\":";
         json+=DoubleToString(state.symbols[i].bucket_competition_percentile,6);
         json+=",\"bucket_member_quality_rank\":";
         json+=ISSX_Util::IntToStringX(state.symbols[i].bucket_member_quality_rank);
         json+=",\"nearest_reserve_gap\":";
         json+=DoubleToString(state.symbols[i].nearest_reserve_gap,6);
         json+=",\"replacement_pressure\":";
         json+=DoubleToString(state.symbols[i].replacement_pressure,6);
         json+=",\"position_security_class\":";
         AppendJsonEscaped(json,SecurityClassToText(state.symbols[i].position_security_class));
         json+=",\"not_top5_reason_primary\":";
         AppendJsonEscaped(json,state.symbols[i].not_top5_reason_primary);
         json+=",\"not_top5_reason_secondary\":";
         AppendJsonEscaped(json,state.symbols[i].not_top5_reason_secondary);
         json+=",\"reserve_promotion_condition\":";
         AppendJsonEscaped(json,state.symbols[i].reserve_promotion_condition);
         json+=",\"reserve_blockers\":";
         AppendJsonEscaped(json,state.symbols[i].reserve_blockers);
         json+=",\"reserve_confidence\":";
         json+=DoubleToString(state.symbols[i].reserve_confidence,6);
         json+=",\"reserve_age_cycles\":";
         json+=ISSX_Util::IntToStringX(state.symbols[i].reserve_age_cycles);
         json+=",\"frontier_entry_reason_primary\":";
         AppendJsonEscaped(json,state.symbols[i].frontier_entry_reason_primary);
         json+=",\"frontier_entry_reason_secondary\":";
         AppendJsonEscaped(json,state.symbols[i].frontier_entry_reason_secondary);
         json+=",\"frontier_confidence\":";
         json+=DoubleToString(state.symbols[i].frontier_confidence,6);
         json+=",\"frontier_survival_risk\":";
         json+=DoubleToString(state.symbols[i].frontier_survival_risk,6);
         json+=",\"peer_comparability_score\":";
         json+=DoubleToString(state.symbols[i].peer_comparability_score,6);
         json+=",\"bucket_comparison_completeness\":";
         json+=DoubleToString(state.symbols[i].bucket_comparison_completeness,6);
         json+=",\"comparison_penalty\":";
         json+=DoubleToString(state.symbols[i].comparison_penalty,6);
         json+=",\"spec_only_cheapness_flag\":";
         json+=(state.symbols[i].spec_only_cheapness_flag ? "true" : "false");
         json+=",\"micro_cleanliness_score\":";
         json+=DoubleToString(state.symbols[i].micro_cleanliness_score,6);
         json+=",\"overlap_noise_score\":";
         json+=DoubleToString(state.symbols[i].overlap_noise_score,6);
         json+=",\"range_efficiency_score\":";
         json+=DoubleToString(state.symbols[i].range_efficiency_score,6);
         json+=",\"survivor_age_cycles\":";
         json+=ISSX_Util::IntToStringX(state.symbols[i].survivor_age_cycles);
         json+=",\"survivor_churn_penalty\":";
         json+=DoubleToString(state.symbols[i].survivor_churn_penalty,6);
         json+=",\"upstream_instability_sources\":";
         AppendJsonEscaped(json,state.symbols[i].upstream_instability_sources);
         json+=",\"incumbent_weak_hold_count\":";
         json+=ISSX_Util::IntToStringX(state.symbols[i].incumbent_weak_hold_count);
         json+=",\"hysteresis_decay_score\":";
         json+=DoubleToString(state.symbols[i].hysteresis_decay_score,6);
         json+=",\"challenger_override_ready\":";
         json+=(state.symbols[i].challenger_override_ready ? "true" : "false");
         json+=",\"selected_top5\":";
         json+=(state.symbols[i].selected_top5 ? "true" : "false");
         json+=",\"selected_reserve\":";
         json+=(state.symbols[i].selected_reserve ? "true" : "false");
         json+=",\"selected_frontier\":";
         json+=(state.symbols[i].selected_frontier ? "true" : "false");
         json+=",\"duplicate_family_rejected\":";
         json+=(state.symbols[i].duplicate_family_rejected ? "true" : "false");
         json+=",\"rankable\":";
         json+=(state.symbols[i].rankable ? "true" : "false");
         json+=",\"rankability_lane\":";
         AppendJsonEscaped(json,RankabilityLaneToText(state.symbols[i].rankability_lane));
         json+=",\"exploratory_penalty_applied\":";
         json+=DoubleToString(state.symbols[i].exploratory_penalty_applied,6);
         json+=",\"replacement_reason_code\":";
         AppendJsonEscaped(json,state.symbols[i].replacement_reason_code);
         json+=",\"winner_archetype_class\":";
         AppendJsonEscaped(json,state.symbols[i].winner_archetype_class);
         json+=",\"reserve_promoted_for_diversity_flag\":";
         json+=(state.symbols[i].reserve_promoted_for_diversity_flag ? "true" : "false");
         json+=",\"redundancy_swap_reason\":";
         AppendJsonEscaped(json,state.symbols[i].redundancy_swap_reason);
         json+=",\"dependency_block_reason\":";
         AppendJsonEscaped(json,state.symbols[i].dependency_block_reason);
         json+=",\"truth_class\":";
         AppendJsonEscaped(json,TruthClassToText(state.symbols[i].truth_class));
         json+=",\"freshness_class\":";
         AppendJsonEscaped(json,FreshnessClassToText(state.symbols[i].freshness_class));
         json+=",\"acceptance_type\":";
         AppendJsonEscaped(json,ISSX_Util::IntToStringX((int)state.symbols[i].acceptance_type));
         json+="}";
        }
      json+="]";
     }

   static void BuildFrontierJson(ISSX_EA3_State &state,string &json)
     {
      json+="\"frontier\":[";
      for(int i=0;i<ArraySize(state.frontier);i++)
        {
         if(i>0)
            json+=",";
         json+="{";
         json+="\"symbol_norm\":";
         AppendJsonEscaped(json,state.frontier[i].symbol_norm);
         json+=",\"bucket_id\":";
         AppendJsonEscaped(json,state.frontier[i].bucket_id);
         json+=",\"bucket_rank\":";
         json+=ISSX_Util::IntToStringX(state.frontier[i].bucket_rank);
         json+=",\"frontier_confidence\":";
         json+=DoubleToString(state.frontier[i].frontier_confidence,6);
         json+=",\"frontier_survival_risk\":";
         json+=DoubleToString(state.frontier[i].frontier_survival_risk,6);
         json+=",\"entry_reason_primary\":";
         AppendJsonEscaped(json,state.frontier[i].entry_reason_primary);
         json+=",\"entry_reason_secondary\":";
         AppendJsonEscaped(json,state.frontier[i].entry_reason_secondary);
         json+=",\"selected_top5\":";
         json+=(state.frontier[i].selected_top5 ? "true" : "false");
         json+=",\"selected_reserve\":";
         json+=(state.frontier[i].selected_reserve ? "true" : "false");
         json+="}";
        }
      json+="]";
     }

   static string BuildStageJsonInternal(ISSX_EA3_State &state)
     {
      string json="{";

      json+="\"stage_id\":\"ea3\"";
      json+=",\"module_version\":";
      AppendJsonEscaped(json,ISSX_SELECTION_ENGINE_MODULE_VERSION);
      json+=",\"stage_api_version\":";
      AppendJsonEscaped(json,ISSX_SELECTION_ENGINE_STAGE_API_VERSION);
      json+=",\"serializer_version\":";
      AppendJsonEscaped(json,ISSX_SELECTION_ENGINE_SERIALIZER_VERSION);
      json+=",\"phase\":";
      AppendJsonEscaped(json,PhaseToText((ISSX_EA3_PhaseId)state.runtime.local_phase_id));
      json+=",\"upstream_source_used\":";
      AppendJsonEscaped(json,state.upstream_source_used);
      json+=",\"upstream_source_reason\":";
      AppendJsonEscaped(json,state.upstream_source_reason);
      json+=",\"upstream_compatibility_class\":";
      AppendJsonEscaped(json,CompatibilityToText(state.upstream_compatibility_class));
      json+=",\"upstream_compatibility_score\":";
      json+=DoubleToString(state.upstream_compatibility_score,6);
      json+=",\"fallback_depth_used\":";
      json+=ISSX_Util::IntToStringX(state.fallback_depth_used);
      json+=",\"fallback_penalty_applied\":";
      json+=DoubleToString(state.fallback_penalty_applied,6);
      json+=",\"projection_partial_success_flag\":";
      json+=(state.projection_partial_success_flag ? "true" : "false");
      json+=",\"degraded_flag\":";
      json+=(state.degraded_flag ? "true" : "false");
      json+=",\"recovery_publish_flag\":";
      json+=(state.recovery_publish_flag ? "true" : "false");
      json+=",\"stage_minimum_ready_flag\":";
      json+=(state.stage_minimum_ready_flag ? "true" : "false");
      json+=",\"stage_publishability_state\":";
      AppendJsonEscaped(json,PublishabilityToText(state.stage_publishability_state));
      json+=",\"dependency_block_reason\":";
      AppendJsonEscaped(json,state.dependency_block_reason);
      json+=",\"debug_weak_link_code\":";
      AppendJsonEscaped(json,WeakLinkCodeToText(state.debug_weak_link_code));
      json+=",\"taxonomy_hash\":";
      AppendJsonEscaped(json,state.taxonomy_hash);
      json+=",\"comparator_registry_hash\":";
      AppendJsonEscaped(json,state.comparator_registry_hash);
      json+=",\"cohort_fingerprint\":";
      AppendJsonEscaped(json,state.cohort_fingerprint);
      json+=",\"policy_fingerprint\":";
      AppendJsonEscaped(json,state.policy_fingerprint);
      json+=",\"fingerprint_algorithm_version\":";
      json+=ISSX_Util::IntToStringX(state.fingerprint_algorithm_version);

      json+=",\"universe\":{";
      json+="\"broker_universe\":";
      json+=ISSX_Util::IntToStringX(state.universe.broker_universe);
      json+=",\"eligible_universe\":";
      json+=ISSX_Util::IntToStringX(state.universe.eligible_universe);
      json+=",\"active_universe\":";
      json+=ISSX_Util::IntToStringX(state.universe.active_universe);
      json+=",\"rankable_universe\":";
      json+=ISSX_Util::IntToStringX(state.universe.rankable_universe);
      json+=",\"frontier_universe\":";
      json+=ISSX_Util::IntToStringX(state.universe.frontier_universe);
      json+=",\"publishable_universe\":";
      json+=ISSX_Util::IntToStringX(state.universe.publishable_universe);
      json+=",\"broker_universe_fingerprint\":";
      AppendJsonEscaped(json,state.universe.broker_universe_fingerprint);
      json+=",\"eligible_universe_fingerprint\":";
      AppendJsonEscaped(json,state.universe.eligible_universe_fingerprint);
      json+=",\"active_universe_fingerprint\":";
      AppendJsonEscaped(json,state.universe.active_universe_fingerprint);
      json+=",\"rankable_universe_fingerprint\":";
      AppendJsonEscaped(json,state.universe.rankable_universe_fingerprint);
      json+=",\"frontier_universe_fingerprint\":";
      AppendJsonEscaped(json,state.universe.frontier_universe_fingerprint);
      json+=",\"publishable_universe_fingerprint\":";
      AppendJsonEscaped(json,state.universe.publishable_universe_fingerprint);
      json+=",\"universe_drift_class\":";
      AppendJsonEscaped(json,state.universe.universe_drift_class);
      json+=",\"percent_universe_touched_recent\":";
      json+=DoubleToString(state.universe.percent_universe_touched_recent,6);
      json+=",\"percent_rankable_revalidated_recent\":";
      json+=DoubleToString(state.universe.percent_rankable_revalidated_recent,6);
      json+=",\"percent_frontier_revalidated_recent\":";
      json+=DoubleToString(state.universe.percent_frontier_revalidated_recent,6);
      json+=",\"never_serviced_count\":";
      json+=ISSX_Util::IntToStringX(state.universe.never_serviced_count);
      json+=",\"overdue_service_count\":";
      json+=ISSX_Util::IntToStringX(state.universe.overdue_service_count);
      json+=",\"never_ranked_but_eligible_count\":";
      json+=ISSX_Util::IntToStringX(state.universe.never_ranked_but_eligible_count);
      json+=",\"newly_active_symbols_waiting_count\":";
      json+=ISSX_Util::IntToStringX(state.universe.newly_active_symbols_waiting_count);
      json+=",\"near_cutline_recheck_age_max\":";
      json+=ISSX_Util::IntToStringX(state.universe.near_cutline_recheck_age_max);
      json+="}";

      json+=",\"delta\":{";
      json+="\"changed_bucket_count\":";
      json+=ISSX_Util::IntToStringX(state.delta.changed_bucket_count);
      json+=",\"changed_frontier_count\":";
      json+=ISSX_Util::IntToStringX(state.delta.changed_frontier_count);
      json+=",\"changed_symbol_count\":";
      json+=ISSX_Util::IntToStringX(state.delta.changed_symbol_count);
      json+=",\"changed_bucket_ids_compact\":";
      AppendJsonEscaped(json,state.delta.changed_bucket_ids_compact);
      json+=",\"changed_symbol_ids_compact\":";
      AppendJsonEscaped(json,state.delta.changed_symbol_ids_compact);
      json+="}";

      json+=",\"counters\":{";
      json+="\"strong_lane_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.strong_lane_count);
      json+=",\"usable_lane_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.usable_lane_count);
      json+=",\"exploratory_lane_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.exploratory_lane_count);
      json+=",\"blocked_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.blocked_count);
      json+=",\"top5_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.top5_count);
      json+=",\"reserve_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.reserve_count);
      json+=",\"frontier_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.frontier_count);
      json+=",\"duplicate_family_reject_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.duplicate_family_reject_count);
      json+=",\"selected_by_hysteresis_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.selected_by_hysteresis_count);
      json+=",\"selected_by_shortfall_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.selected_by_shortfall_count);
      json+=",\"reserve_promoted_for_diversity_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.reserve_promoted_for_diversity_count);
      json+=",\"accepted_strong_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.accepted_strong_count);
      json+=",\"accepted_degraded_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.accepted_degraded_count);
      json+=",\"rejected_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.rejected_count);
      json+=",\"stale_usable_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.stale_usable_count);
      json+="}";

      json+=",\"hysteresis\":{";
      json+="\"enter_threshold\":";
      json+=DoubleToString(state.hysteresis.enter_threshold,6);
      json+=",\"hold_threshold\":";
      json+=DoubleToString(state.hysteresis.hold_threshold,6);
      json+=",\"override_gap\":";
      json+=DoubleToString(state.hysteresis.override_gap,6);
      json+=",\"weak_hold_decay_step\":";
      json+=DoubleToString(state.hysteresis.weak_hold_decay_step,6);
      json+=",\"max_weak_hold_count\":";
      json+=ISSX_Util::IntToStringX(state.hysteresis.max_weak_hold_count);
      json+="}";

      json+=",\"survivor_memory\":[";
      for(int i=0;i<ArraySize(state.survivor_memory);i++)
        {
         if(i>0)
            json+=",";
         json+="{";
         json+="\"symbol_norm\":";
         AppendJsonEscaped(json,state.survivor_memory[i].symbol_norm);
         json+=",\"bucket_id\":";
         AppendJsonEscaped(json,state.survivor_memory[i].bucket_id);
         json+=",\"was_top5\":";
         json+=(state.survivor_memory[i].was_top5 ? "true" : "false");
         json+=",\"was_frontier\":";
         json+=(state.survivor_memory[i].was_frontier ? "true" : "false");
         json+=",\"survivor_age_cycles\":";
         json+=ISSX_Util::IntToStringX(state.survivor_memory[i].survivor_age_cycles);
         json+=",\"weak_hold_count\":";
         json+=ISSX_Util::IntToStringX(state.survivor_memory[i].weak_hold_count);
         json+=",\"last_seen_minute_id\":";
         json+=ISSX_Util::IntToStringX(state.survivor_memory[i].last_seen_minute_id);
         json+="}";
        }
      json+="],";

      BuildBucketsJson(state,json);
      json+=",";
      BuildSymbolsJson(state,json);
      json+=",";
      BuildFrontierJson(state,json);

      json+="}";
      return json;
     }

   static string BuildDebugJsonInternal(ISSX_EA3_State &state)
     {
      string json="{";
      json+="\"ea3_debug\":{";
      json+="\"module_version\":";
      AppendJsonEscaped(json,ISSX_SELECTION_ENGINE_MODULE_VERSION);
      json+=",\"stage_api_version\":";
      AppendJsonEscaped(json,ISSX_SELECTION_ENGINE_STAGE_API_VERSION);
      json+=",\"serializer_version\":";
      AppendJsonEscaped(json,ISSX_SELECTION_ENGINE_SERIALIZER_VERSION);
      json+=",\"phase\":";
      AppendJsonEscaped(json,PhaseToText((ISSX_EA3_PhaseId)state.runtime.local_phase_id));
      json+=",\"publishability\":";
      AppendJsonEscaped(json,PublishabilityToText(state.stage_publishability_state));
      json+=",\"weak_link\":";
      AppendJsonEscaped(json,WeakLinkCodeToText(state.debug_weak_link_code));
      json+=",\"dependency_block_reason\":";
      AppendJsonEscaped(json,state.dependency_block_reason);
      json+=",\"top5_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.top5_count);
      json+=",\"reserve_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.reserve_count);
      json+=",\"frontier_count\":";
      json+=ISSX_Util::IntToStringX(state.counters.frontier_count);
      json+=",\"rankable_universe\":";
      json+=ISSX_Util::IntToStringX(state.universe.rankable_universe);
      json+=",\"changed_symbol_count\":";
      json+=ISSX_Util::IntToStringX(state.delta.changed_symbol_count);
      json+=",\"changed_bucket_count\":";
      json+=ISSX_Util::IntToStringX(state.delta.changed_bucket_count);
      json+=",\"changed_frontier_count\":";
      json+=ISSX_Util::IntToStringX(state.delta.changed_frontier_count);
      json+=",\"degraded_flag\":";
      json+=(state.degraded_flag ? "true" : "false");

      json+=",\"top_frontier\":[";
      const int limit=MathMin(ArraySize(state.frontier),ISSX_EA3_DEBUG_FRONTIER_LIMIT);
      for(int i=0;i<limit;i++)
        {
         if(i>0)
            json+=",";
         json+="{";
         json+="\"symbol_norm\":";
         AppendJsonEscaped(json,state.frontier[i].symbol_norm);
         json+=",\"bucket_id\":";
         AppendJsonEscaped(json,state.frontier[i].bucket_id);
         json+=",\"frontier_confidence\":";
         json+=DoubleToString(state.frontier[i].frontier_confidence,6);
         json+=",\"frontier_survival_risk\":";
         json+=DoubleToString(state.frontier[i].frontier_survival_risk,6);
         json+=",\"entry_reason_primary\":";
         AppendJsonEscaped(json,state.frontier[i].entry_reason_primary);
         json+="}";
        }
      json+="]";

      json+="}}";
      return json;
     }

public:
   static void ResetState(ISSX_EA3_State &state)
     {
      state.Reset();
     }

   static bool BuildFromInputs(const string firm_id,
                               ISSX_EA1_State &ea1,
                               ISSX_EA2_State &ea2,
                               ISSX_EA3_State &state)
     {
      SelectionDebug("selection_batch_start",
                     "phase=build_from_inputs firm="+firm_id+
                     " ea1_symbols="+ISSX_Util::IntToStringX(ArraySize(ea1.symbols))+
                     " ea2_symbols="+ISSX_Util::IntToStringX(ArraySize(ea2.symbols)));

      const long prev_cycle_no=state.runtime.scheduler_cycle_no;

      ISSX_EA3_SurvivorMemory previous_survivor_memory[];
      ArrayResize(previous_survivor_memory,0);
      CopySurvivorMemoryArray(state.survivor_memory,previous_survivor_memory);

      ResetState(state);
      state.runtime.scheduler_cycle_no=prev_cycle_no+1;

      InheritUpstreamContext(state,ea1,ea2);

      ResetRuntimeForPhase(state,issx_ea3_phase_load_upstream);

      ResetRuntimeForPhase(state,issx_ea3_phase_restore_survivor_state);
      RestoreSurvivorMemory(state,previous_survivor_memory);

      ResetRuntimeForPhase(state,issx_ea3_phase_build_bucket_sets_delta_first);
      BuildBucketSets(state,ea1,ea2);

      ResetRuntimeForPhase(state,issx_ea3_phase_collapse_families);
      CollapseFamilies(state);

      ResetRuntimeForPhase(state,issx_ea3_phase_rank_buckets);
      RankBuckets(state);

      ResetRuntimeForPhase(state,issx_ea3_phase_assign_reserves);
      AssignReserves(state);

      ResetRuntimeForPhase(state,issx_ea3_phase_build_frontier);
      BuildFrontier(state);

      ResetRuntimeForPhase(state,issx_ea3_phase_update_survivor_continuity);
      UpdateSurvivorContinuity(state);

      RefreshDerivedUniverseCoverage(state);
      EvaluateStageHealth(state);
      UpdateHeaderAndManifest(state,firm_id);

      ResetRuntimeForPhase(state,issx_ea3_phase_publish);

      SelectionDebug("selection_batch_complete",
                     "phase=build_from_inputs cycle="+ISSX_Util::LongToStringX((long)state.runtime.scheduler_cycle_no)+
                     " symbols="+ISSX_Util::IntToStringX(ArraySize(state.symbols))+
                     " top5="+ISSX_Util::IntToStringX(state.counters.top5_count)+
                     " reserve="+ISSX_Util::IntToStringX(state.counters.reserve_count)+
                     " frontier="+ISSX_Util::IntToStringX(state.counters.frontier_count));
      return true;
     }

   static bool StageBoot(const string firm_id,
                         ISSX_EA1_State &ea1,
                         ISSX_EA2_State &ea2,
                         ISSX_EA3_State &state)
     {
      return BuildFromInputs(firm_id,ea1,ea2,state);
     }

   static bool StageSlice(const string firm_id,
                          ISSX_EA1_State &ea1,
                          ISSX_EA2_State &ea2,
                          ISSX_EA3_State &state)
     {
      return BuildFromInputs(firm_id,ea1,ea2,state);
     }

   static bool StagePublish(ISSX_EA3_State &state,string &stage_json,string &debug_json)
     {
      stage_json=BuildStageJsonInternal(state);
      debug_json=BuildDebugJsonInternal(state);
      return (StringLen(stage_json)>2);
     }

   static string BuildDebugSnapshot(ISSX_EA3_State &state)
     {
      return BuildDebugJsonInternal(state);
     }

   static string BuildStageJson(ISSX_EA3_State &state)
     {
      return BuildStageJsonInternal(state);
     }

   static string BuildDebugJson(ISSX_EA3_State &state)
     {
      return BuildDebugJsonInternal(state);
     }

   static string ExportOptionalIntelligence(ISSX_EA3_State &state)
     {
      return BuildStageJsonInternal(state);
     }
  };



string ISSX_SelectionDiagTag()
  {
   return "selection_diag_v174f";
  }


string ISSX_SelectionEngineDebugSignature()
  {
   return ISSX_SelectionDiagTag();
  }

#endif // __ISSX_SELECTION_ENGINE_MQH__
