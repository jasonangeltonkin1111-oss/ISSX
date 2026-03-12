
#ifndef __ISSX_SELECTION_ENGINE_MQH__
#define __ISSX_SELECTION_ENGINE_MQH__
#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>
#include <ISSX/issx_market_engine.mqh>
#include <ISSX/issx_history_engine.mqh>

// ============================================================================
// ISSX SELECTION ENGINE v1.7.0
// EA3 shared engine for SelectionCore.
//
// OWNERSHIP IN THIS MODULE
// - bucket competitions
// - top 5 per bucket
// - reserve ladders
// - frontier assembly
// - bucket truth diagnostics
// - survivor continuity
// - hysteresis and anti-sticky decay
// - bounded replacement discipline
// - delta-driven frontier updates
//
// DESIGN PRINCIPLES
// - family collapse happens before rank
// - publish fewer than 5 if bucket truth is weak
// - survivor age alone must never outrank truth floor
// - repeated weak hysteresis holds decay
// - replacement budget must be bounded per cycle
// - no directional content
// ============================================================================

#define ISSX_SELECTION_ENGINE_MODULE_VERSION "1.5.0"
#define ISSX_EA3_TOP5_LIMIT                 5
#define ISSX_EA3_RESERVE_LIMIT              3
#define ISSX_EA3_FRONTIER_SOFT_LIMIT        48

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

enum ISSX_EA3_BucketDepthQuality
  {
   issx_ea3_depth_shallow = 0,
   issx_ea3_depth_adequate,
   issx_ea3_depth_deep
  };

// ============================================================================
// SECTION 02: DTO TYPES
// ============================================================================

struct ISSX_EA3_HysteresisKnobs
  {
   double enter_threshold;
   double hold_threshold;
   int    max_replacements_per_cycle;
   int    min_hold_cycles;
   int    promote_cooldown;

   void Reset()
     {
      enter_threshold=0.55;
      hold_threshold=0.50;
      max_replacements_per_cycle=4;
      min_hold_cycles=2;
      promote_cooldown=1;
     }
  };

struct ISSX_EA3_BucketDiagnostics
  {
   double                     bucket_truth_score;
   double                     bucket_publishability_score;
   double                     bucket_competition_strength;
   double                     bucket_duplication_pressure;
   double                     bucket_tradeability_median;
   double                     bucket_truth_median;
   double                     bucket_history_median;
   double                     bucket_top5_confidence_median;
   double                     bucket_top5_truth_floor;
   double                     bucket_rotation_pressure_score;
   ISSX_PublishabilityState   bucket_publishability_state;
   string                     bucket_shortfall_root_causes;
   string                     bucket_shortfall_reason;
   int                        duplicate_collapsed_count;
   int                        blocked_tradeability_count;
   int                        weak_history_count;
   int                        weak_observability_count;
   int                        weak_classification_count;
   ISSX_EA3_BucketStrengthClass bucket_strength_class;
   ISSX_EA3_BucketDepthQuality  bucket_depth_quality;
   int                        bucket_depth_strong;
   int                        bucket_depth_compare_safe;
   int                        bucket_depth_degraded;
   string                     bucket_confidence_class;
   string                     bucket_instability_reason;
   double                     bucket_opportunity_density;
   string                     bucket_redundancy_state;
   string                     bucket_primary_thinning_reason;
   double                     bucket_redundancy_penalty;
   double                     bucket_churn_score;
   int                        survivor_turnover_count_recent;

   void Reset()
     {
      bucket_truth_score=0.0;
      bucket_publishability_score=0.0;
      bucket_competition_strength=0.0;
      bucket_duplication_pressure=0.0;
      bucket_tradeability_median=0.0;
      bucket_truth_median=0.0;
      bucket_history_median=0.0;
      bucket_top5_confidence_median=0.0;
      bucket_top5_truth_floor=0.0;
      bucket_rotation_pressure_score=0.0;
      bucket_publishability_state=issx_publishability_not_ready;
      bucket_shortfall_root_causes="";
      bucket_shortfall_reason="";
      duplicate_collapsed_count=0;
      blocked_tradeability_count=0;
      weak_history_count=0;
      weak_observability_count=0;
      weak_classification_count=0;
      bucket_strength_class=issx_ea3_bucket_weak;
      bucket_depth_quality=issx_ea3_depth_shallow;
      bucket_depth_strong=0;
      bucket_depth_compare_safe=0;
      bucket_depth_degraded=0;
      bucket_confidence_class="weak";
      bucket_instability_reason="";
      bucket_opportunity_density=0.0;
      bucket_redundancy_state="unknown";
      bucket_primary_thinning_reason="";
      bucket_redundancy_penalty=0.0;
      bucket_churn_score=0.0;
      survivor_turnover_count_recent=0;
     }
  };

struct ISSX_EA3_SymbolSelection
  {
   string                     symbol_raw;
   string                     symbol_norm;
   string                     canonical_root;
   string                     alias_family_id;
   string                     leader_bucket_id;
   ISSX_LeaderBucketType      leader_bucket_type;

   double                     observability_score;
   double                     trade_cost_usability_score;
   double                     history_data_quality_score;
   double                     classification_reliability_score;
   double                     stability_score;

   double                     bucket_local_composite;
   int                        bucket_rank;
   int                        bucket_top5_rank;
   bool                       won_by_strength;
   bool                       won_by_shortfall;
   bool                       won_on_hysteresis_only_flag;
   double                     bucket_competition_percentile;
   int                        bucket_member_quality_rank;
   double                     nearest_reserve_gap;
   double                     replacement_pressure;
   ISSX_EA3_PositionSecurityClass position_security_class;
   string                     not_top5_reason_primary;
   string                     not_top5_reason_secondary;
   string                     reserve_promotion_condition;
   string                     reserve_blockers;
   double                     reserve_confidence;
   int                        reserve_age_cycles;
   string                     frontier_entry_reason_primary;
   string                     frontier_entry_reason_secondary;
   double                     frontier_confidence;
   double                     frontier_survival_risk;
   double                     peer_comparability_score;
   double                     bucket_comparison_completeness;
   double                     comparison_penalty;
   bool                       spec_only_cheapness_flag;
   double                     micro_cleanliness_score;
   double                     overlap_noise_score;
   double                     range_efficiency_score;
   int                        survivor_age_cycles;
   double                     survivor_churn_penalty;
   string                     upstream_instability_sources;
   int                        incumbent_weak_hold_count;
   double                     hysteresis_decay_score;
   bool                       challenger_override_ready;

   bool                       selected_top5;
   bool                       selected_reserve;
   bool                       selected_frontier;
   bool                       duplicate_family_rejected;
   bool                       rankable;
   ISSX_RankabilityLane       rankability_lane;
   double                     exploratory_penalty_applied;
   string                     replacement_reason_code;
   string                     winner_archetype_class;
   bool                       reserve_promoted_for_diversity_flag;
   string                     redundancy_swap_reason;
   string                     dependency_block_reason;
   ISSX_TruthClass            truth_class;
   ISSX_FreshnessClass        freshness_class;
   ISSX_AcceptanceType        acceptance_type;
   ISSX_ContradictionSeverity contradiction_severity_max;

   void Reset()
     {
      symbol_raw="";
      symbol_norm="";
      canonical_root="";
      alias_family_id="";
      leader_bucket_id="";
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
      not_top5_reason_primary="";
      not_top5_reason_secondary="";
      reserve_promotion_condition="";
      reserve_blockers="";
      reserve_confidence=0.0;
      reserve_age_cycles=0;
      frontier_entry_reason_primary="";
      frontier_entry_reason_secondary="";
      frontier_confidence=0.0;
      frontier_survival_risk=0.0;
      peer_comparability_score=0.0;
      bucket_comparison_completeness=0.0;
      comparison_penalty=0.0;
      spec_only_cheapness_flag=false;
      micro_cleanliness_score=0.0;
      overlap_noise_score=0.0;
      range_efficiency_score=0.0;
      survivor_age_cycles=0;
      survivor_churn_penalty=0.0;
      upstream_instability_sources="";
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
      replacement_reason_code="";
      winner_archetype_class="unknown";
      reserve_promoted_for_diversity_flag=false;
      redundancy_swap_reason="";
      dependency_block_reason="";
      truth_class=issx_truth_weak;
      freshness_class=issx_freshness_stale;
      acceptance_type=issx_accept_rejected;
      contradiction_severity_max=issx_contradiction_low;
     }
  };

struct ISSX_EA3_BucketState
  {
   string                    bucket_id;
   ISSX_LeaderBucketType     bucket_type;
   ISSX_EA3_BucketDiagnostics diagnostics;
   int                       member_indices[];
   int                       ranked_indices[];
   int                       top5_indices[];
   int                       reserve_indices[];
   int                       changed_members_this_cycle;
   bool                      changed_this_cycle;

   void Reset()
     {
      bucket_id="";
      bucket_type=issx_leader_bucket_theme_bucket;
      diagnostics.Reset();
      ArrayResize(member_indices,0);
      ArrayResize(ranked_indices,0);
      ArrayResize(top5_indices,0);
      ArrayResize(reserve_indices,0);
      changed_members_this_cycle=0;
      changed_this_cycle=false;
     }
  };

struct ISSX_EA3_FrontierItem
  {
   int    symbol_index;
   string symbol_norm;
   string symbol_raw;
   string bucket_id;
   double frontier_promotion_score;
   double frontier_confidence;
   string entry_reason_primary;
   string entry_reason_secondary;

   void Reset()
     {
      symbol_index=-1;
      symbol_norm="";
      symbol_raw="";
      bucket_id="";
      frontier_promotion_score=0.0;
      frontier_confidence=0.0;
      entry_reason_primary="";
      entry_reason_secondary="";
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
   int    promote_cooldown_remaining;
   double last_composite;
   long   last_minute_id;

   void Reset()
     {
      symbol_norm="";
      bucket_id="";
      was_top5=false;
      was_frontier=false;
      survivor_age_cycles=0;
      weak_hold_count=0;
      promote_cooldown_remaining=0;
      last_composite=0.0;
      last_minute_id=0;
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
     }
  };

struct ISSX_EA3_DeltaState
  {
   int    changed_symbol_count;
   string changed_symbol_ids;
   int    changed_family_count;
   int    changed_bucket_count;
   int    changed_frontier_count;

   void Reset()
     {
      changed_symbol_count=0;
      changed_symbol_ids="";
      changed_family_count=0;
      changed_bucket_count=0;
      changed_frontier_count=0;
     }
  };

struct ISSX_EA3_CycleCounters
  {
   int selected_symbols_total;
   int bucket_count;
   int frontier_count;
   int reserve_count;
   int duplicate_collapsed_count;
   int blocked_tradeability_count;
   int weak_history_count;
   int weak_observability_count;
   int weak_classification_count;
   int hysteresis_hold_count;
   int hysteresis_weak_decay_count;
   int challenger_override_count;
   int survivor_turnover_count_recent;
   int contradiction_count;
   int blocking_contradiction_count;

   void Reset()
     {
      selected_symbols_total=0;
      bucket_count=0;
      frontier_count=0;
      reserve_count=0;
      duplicate_collapsed_count=0;
      blocked_tradeability_count=0;
      weak_history_count=0;
      weak_observability_count=0;
      weak_classification_count=0;
      hysteresis_hold_count=0;
      hysteresis_weak_decay_count=0;
      challenger_override_count=0;
      survivor_turnover_count_recent=0;
      contradiction_count=0;
      blocking_contradiction_count=0;
     }
  };

struct ISSX_EA3_State
  {
   ISSX_StageHeader          header;
   ISSX_Manifest             manifest;
   ISSX_RuntimeState         runtime;
   ISSX_EA3_HysteresisKnobs  hysteresis;
   ISSX_EA3_UniverseState    universe;
   ISSX_EA3_DeltaState       delta;
   ISSX_EA3_CycleCounters    counters;
   string                    upstream_source_used;
   string                    upstream_source_reason;
   ISSX_CompatibilityClass   upstream_compatibility_class;
   double                    upstream_compatibility_score;
   int                       fallback_depth_used;
   double                    fallback_penalty_applied;
   bool                      projection_partial_success_flag;
   bool                      degraded_flag;
   bool                      recovery_publish_flag;
   bool                      stage_minimum_ready_flag;
   ISSX_PublishabilityState  stage_publishability_state;
   string                    dependency_block_reason;
   ISSX_DebugWeakLinkCode    debug_weak_link_code;
   string                    taxonomy_hash;
   string                    comparator_registry_hash;
   string                    cohort_fingerprint;
   ISSX_EA3_SurvivorMemory   survivor_memory[];
   ISSX_EA3_SymbolSelection  symbols[];
   ISSX_EA3_BucketState      buckets[];
   ISSX_EA3_FrontierItem     frontier[];

   void Reset()
     {
      ZeroMemory(header);
      ZeroMemory(manifest);
      runtime.Reset();
      hysteresis.Reset();
      universe.Reset();
      delta.Reset();
      counters.Reset();
      upstream_source_used="";
      upstream_source_reason="";
      upstream_compatibility_class=issx_compatibility_incompatible;
      upstream_compatibility_score=0.0;
      fallback_depth_used=0;
      fallback_penalty_applied=0.0;
      projection_partial_success_flag=false;
      degraded_flag=false;
      recovery_publish_flag=false;
      stage_minimum_ready_flag=false;
      stage_publishability_state=issx_publishability_not_ready;
      dependency_block_reason="";
      debug_weak_link_code=issx_weak_link_none;
      taxonomy_hash="";
      comparator_registry_hash="";
      cohort_fingerprint="";
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
      if(v<0.0) return 0.0;
      if(v>1.0) return 1.0;
      return v;
     }

   static double MedianFromArray(double &vals[])
     {
      int n=ArraySize(vals);
      if(n<=0) return 0.0;
      ArraySort(vals);
      if((n%2)==1) return vals[n/2];
      return 0.5*(vals[n/2-1]+vals[n/2]);
     }

   static string PositionSecurityClassToString(const ISSX_EA3_PositionSecurityClass v)
     {
      switch(v)
        {
         case issx_ea3_security_fragile:   return "fragile";
         case issx_ea3_security_contested: return "contested";
         case issx_ea3_security_stable:    return "stable";
         case issx_ea3_security_locked:    return "locked";
         default:                          return "fragile";
        }
     }

   static string BucketStrengthClassToString(const ISSX_EA3_BucketStrengthClass v)
     {
      switch(v)
        {
         case issx_ea3_bucket_weak:   return "weak";
         case issx_ea3_bucket_fair:   return "fair";
         case issx_ea3_bucket_strong: return "strong";
         default:                     return "weak";
        }
     }

   static string BucketDepthQualityToString(const ISSX_EA3_BucketDepthQuality v)
     {
      switch(v)
        {
         case issx_ea3_depth_shallow:  return "shallow";
         case issx_ea3_depth_adequate: return "adequate";
         case issx_ea3_depth_deep:     return "deep";
         default:                      return "shallow";
        }
     }

   static string PublishabilityStateToString(const ISSX_PublishabilityState v)
     {
      switch(v)
        {
         case issx_publishability_not_ready:      return "not_ready";
         case issx_publishability_warmup:         return "warmup";
         case issx_publishability_usable_degraded:return "usable_degraded";
         case issx_publishability_usable:         return "usable";
         case issx_publishability_strong:         return "strong";
         default:                                 return "not_ready";
        }
     }

   static string TruthClassToString(const ISSX_TruthClass v)
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

   static string FreshnessClassToString(const ISSX_FreshnessClass v)
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


   static string CompatibilityClassToString(const ISSX_CompatibilityClass v)
     {
      switch(v)
        {
         case issx_compatibility_exact:              return "exact";
         case issx_compatibility_compatible:         return "compatible";
         case issx_compatibility_compatible_degraded:return "compatible_degraded";
         case issx_compatibility_incompatible:       return "incompatible";
         default:                                    return "incompatible";
        }
     }

   static string AcceptanceTypeToString(const ISSX_AcceptanceType v)
     {
      switch(v)
        {
         case issx_accept_pipeline:     return "accepted_for_pipeline";
         case issx_accept_ranking:      return "accepted_for_ranking";
         case issx_accept_intelligence: return "accepted_for_intelligence";
         case issx_accept_gpt_export:   return "accepted_for_gpt_export";
         case issx_accept_degraded:     return "accepted_degraded";
         case issx_accept_rejected:     return "rejected";
         default:                       return "rejected";
        }
     }


   static string RankabilityLaneToString(const ISSX_RankabilityLane v)
     {
      switch(v)
        {
         case issx_rankability_strong:      return "strong";
         case issx_rankability_usable:      return "usable";
         case issx_rankability_exploratory: return "exploratory";
         case issx_rankability_blocked:     return "blocked";
         default:                           return "blocked";
        }
     }

   static int FindSurvivorMemory(const ISSX_EA3_State &state,const string symbol_norm)
     {
      for(int i=0;i<ArraySize(state.survivor_memory);i++)
         if(state.survivor_memory[i].symbol_norm==symbol_norm)
            return i;
      return -1;
     }

   static int FindBucket(const ISSX_EA3_State &state,const string bucket_id,const ISSX_LeaderBucketType bucket_type)
     {
      for(int i=0;i<ArraySize(state.buckets);i++)
         if(state.buckets[i].bucket_id==bucket_id && state.buckets[i].bucket_type==bucket_type)
            return i;
      return -1;
     }

   static int EnsureBucket(ISSX_EA3_State &state,const string bucket_id,const ISSX_LeaderBucketType bucket_type)
     {
      int idx=FindBucket(state,bucket_id,bucket_type);
      if(idx>=0) return idx;
      idx=ArraySize(state.buckets);
      ArrayResize(state.buckets,idx+1);
      state.buckets[idx].Reset();
      state.buckets[idx].bucket_id=bucket_id;
      state.buckets[idx].bucket_type=bucket_type;
      return idx;
     }

   static void PushIndex(int &arr[],const int value)
     {
      int n=ArraySize(arr);
      ArrayResize(arr,n+1);
      arr[n]=value;
     }

   static bool IsTradeabilityBlocked(const ISSX_TradeabilityClass v)
     {
      return (v==issx_tradeability_blocked);
     }

   static bool IsSymbolRankable(const ISSX_EA1_SymbolState &ea1,const ISSX_EA2_SymbolState &ea2)
     {
      if(!ea1.rankability_gate.gate_passed)
         return false;
      if(IsTradeabilityBlocked(ea1.tradeability_baseline.tradeability_class))
         return false;
      if(!ea2.history_ready_for_ranking)
         return false;
      if(ea2.judgment.history_data_quality_score<0.25)
         return false;
      if(ea1.classification_truth.classification_reliability_score<0.20)
         return false;
      return true;
     }

   static double ComputeObservabilityScore(const ISSX_EA1_SymbolState &ea1)
     {
      const ISSX_EA1_ValidatedRuntimeTruth &v=ea1.validated_runtime_truth;
      double obs=0.45*v.runtime_truth_score
                +0.25*v.observation_density_score
                +0.20*(1.0-Clamp01(v.observation_gap_risk))
                +0.10*v.market_sampling_quality_score;
      return Clamp01(obs);
     }

   static double ComputeTradeCostUsabilityScore(const ISSX_EA1_SymbolState &ea1)
     {
      const ISSX_EA1_TradeabilityBaseline &t=ea1.tradeability_baseline;
      double base=0.35*t.blended_tradeability_score
                 +0.20*t.entry_cost_score
                 +0.15*t.size_practicality_score
                 +0.10*t.economic_consistency_score
                 +0.10*t.microstructure_safety_score
                 +0.10*t.small_account_usability_score;

      base *= (1.0-0.15*Clamp01(t.toxicity_score));
      base *= (1.0-0.10*Clamp01(t.live_cost_deviation_score));
      if(IsTradeabilityBlocked(t.tradeability_class))
         base=0.0;
      return Clamp01(base);
     }

   static double ComputeHistoryQualityScore(const ISSX_EA2_SymbolState &ea2)
     {
      double s=0.60*ea2.judgment.history_data_quality_score
              +0.15*ea2.judgment.metric_trust_score
              +0.15*ea2.judgment.continuity_score
              +0.10*(1.0-ea2.judgment.gap_risk_score);
      if(!ea2.history_ready_for_ranking)
         s*=0.50;
      if(ea2.provenance.temporary_rank_suspension)
         s*=0.35;
      return Clamp01(s);
     }

   static double ComputeClassificationReliabilityScore(const ISSX_EA1_SymbolState &ea1)
     {
      const ISSX_EA1_ClassificationTruth &c=ea1.classification_truth;
      double s=0.55*c.classification_reliability_score
              +0.25*c.taxonomy_reliability_score
              +0.10*c.classification_confidence
              +0.10*Clamp01((double)c.bucket_assignment_stable_cycles/10.0);
      if(c.classification_needs_review)
         s*=0.70;
      if(c.native_vs_manual_conflict)
         s*=0.85;
      return Clamp01(s);
     }

   static double ComputeStabilityScore(const ISSX_EA1_SymbolState &ea1,const ISSX_EA2_SymbolState &ea2,const int survivor_age_cycles,const int weak_hold_count)
     {
      double recovery_component=1.0;
      if(ea2.provenance.recovery_stability_cycles_required>0 && ea2.provenance.flap_count_recent>0)
         recovery_component=0.5;

      double s=0.25*Clamp01((double)ea1.rankability_gate.gate_pass_cycles/10.0)
              +0.20*Clamp01((double)ea1.classification_truth.bucket_assignment_stable_cycles/10.0)
              +0.20*(1.0-Clamp01((double)ea1.rankability_gate.gate_flap_count/10.0))
              +0.15*(1.0-Clamp01(ea2.provenance.history_flap_risk))
              +0.20*Clamp01(recovery_component);
      if(survivor_age_cycles>0)
        {
         s=0.75*s + 0.25*Clamp01((double)survivor_age_cycles/10.0);
         s*= (1.0-0.10*Clamp01((double)weak_hold_count/5.0));
        }
      return Clamp01(s);
     }

   static double ComputeComposite(const ISSX_EA3_SymbolSelection &s)
     {
      return Clamp01(0.40*s.trade_cost_usability_score
                    +0.20*s.observability_score
                    +0.20*s.history_data_quality_score
                    +0.10*s.classification_reliability_score
                    +0.10*s.stability_score);
     }

   static double ComputePeerComparability(const ISSX_EA2_SymbolState &ea2)
     {
      double c=0.0;
      if(ea2.tf[issx_ea2_tf_m5].metric_compare_class>=issx_metric_compare_bucket_safe) c+=0.33;
      if(ea2.tf[issx_ea2_tf_m15].metric_compare_class>=issx_metric_compare_bucket_safe) c+=0.33;
      if(ea2.tf[issx_ea2_tf_h1].metric_compare_class>=issx_metric_compare_bucket_safe) c+=0.34;
      if(ea2.provenance.temporary_rank_suspension)
         c*=0.5;
      return Clamp01(c);
     }

   static double ComputeComparisonPenalty(const ISSX_EA3_SymbolSelection &s)
     {
      double lack=1.0-s.peer_comparability_score;
      return Clamp01(0.55*lack + 0.45*(1.0-s.bucket_comparison_completeness));
     }

   static double ComputeMicroCleanlinessScore(const ISSX_EA1_SymbolState &ea1,const ISSX_EA2_SymbolState &ea2)
     {
      double s=0.35*ea1.tradeability_baseline.microstructure_safety_score
              +0.25*(1.0-Clamp01(ea2.structural_context.micro_noise_risk))
              +0.20*ea2.structural_context.structure_clarity_score
              +0.20*(1.0-Clamp01(ea1.validated_runtime_truth.quote_burstiness_score));
      return Clamp01(s);
     }

   static double ComputeRangeEfficiencyScore(const ISSX_EA2_SymbolState &ea2)
     {
      double s=0.40*ea2.hot_metrics.spread_to_atr_efficiency
              +0.30*ea2.judgment.usable_range_score
              +0.30*ea2.structural_context.structure_stability_score;
      return Clamp01(s);
     }

   static double ComputeOverlapNoiseScore(const ISSX_EA1_SymbolState &ea1,const ISSX_EA2_SymbolState &ea2)
     {
      double s=0.50*Clamp01(ea1.validated_runtime_truth.quote_burstiness_score)
              +0.25*Clamp01(ea1.validated_runtime_truth.spread_widening_ratio)
              +0.25*Clamp01(ea2.structural_context.micro_noise_risk);
      return Clamp01(s);
     }

   static int FamilyRepresentativeForBucket(const ISSX_EA3_State &state,const int bucket_idx,const string alias_family_id)
     {
      int best=-1;
      double best_score=-1.0;
      const int n=ArraySize(state.buckets[bucket_idx].member_indices);
      for(int i=0;i<n;i++)
        {
         int sym_idx=state.buckets[bucket_idx].member_indices[i];
         const ISSX_EA3_SymbolSelection &s=state.symbols[sym_idx];
         if(s.alias_family_id!=alias_family_id)
            continue;
         double hold_bonus=Clamp01((double)s.survivor_age_cycles/10.0)*0.03;
         double score=s.bucket_local_composite-hold_bonus; // lower hold advantage during family collapse
         if(best<0 || score>best_score)
           {
            best=sym_idx;
            best_score=score;
           }
        }
      return best;
     }

   static void SortIndicesByComposite(const ISSX_EA3_State &state,int &indices[])
     {
      int n=ArraySize(indices);
      for(int i=0;i<n-1;i++)
        {
         int best=i;
         for(int j=i+1;j<n;j++)
           {
            const ISSX_EA3_SymbolSelection &a=state.symbols[indices[j]];
            const ISSX_EA3_SymbolSelection &b=state.symbols[indices[best]];
            if(a.bucket_local_composite>b.bucket_local_composite)
               best=j;
            else if(a.bucket_local_composite==b.bucket_local_composite &&
                    a.stability_score>b.stability_score)
               best=j;
           }
         if(best!=i)
           {
            int tmp=indices[i];
            indices[i]=indices[best];
            indices[best]=tmp;
           }
        }
     }

   static bool WasTop5LastCycle(const ISSX_EA3_State &state,const string symbol_norm)
     {
      int idx=FindSurvivorMemory(state,symbol_norm);
      return (idx>=0 && state.survivor_memory[idx].was_top5);
     }


   static void BuildBucketDiagnostics(ISSX_EA3_State &state,ISSX_EA3_BucketState &bucket)
     {
      int n=ArraySize(bucket.ranked_indices);
      double trade_vals[], truth_vals[], hist_vals[], conf_vals[];
      ArrayResize(trade_vals,0); ArrayResize(truth_vals,0); ArrayResize(hist_vals,0); ArrayResize(conf_vals,0);

      bucket.diagnostics.Reset();
      for(int i=0;i<n;i++)
        {
         const ISSX_EA3_SymbolSelection &s=state.symbols[bucket.ranked_indices[i]];
         int k=ArraySize(trade_vals); ArrayResize(trade_vals,k+1); trade_vals[k]=s.trade_cost_usability_score;
         k=ArraySize(truth_vals); ArrayResize(truth_vals,k+1); truth_vals[k]=(s.observability_score+s.classification_reliability_score+s.stability_score)/3.0;
         k=ArraySize(hist_vals); ArrayResize(hist_vals,k+1); hist_vals[k]=s.history_data_quality_score;
         k=ArraySize(conf_vals); ArrayResize(conf_vals,k+1); conf_vals[k]=s.bucket_local_composite;

         if(s.trade_cost_usability_score<0.25) bucket.diagnostics.blocked_tradeability_count++;
         if(s.history_data_quality_score<0.35) bucket.diagnostics.weak_history_count++;
         if(s.observability_score<0.35) bucket.diagnostics.weak_observability_count++;
         if(s.classification_reliability_score<0.35) bucket.diagnostics.weak_classification_count++;
         if(s.duplicate_family_rejected) bucket.diagnostics.duplicate_collapsed_count++;
        }

      bucket.diagnostics.bucket_tradeability_median = MedianFromArray(trade_vals);
      bucket.diagnostics.bucket_truth_median        = MedianFromArray(truth_vals);
      bucket.diagnostics.bucket_history_median      = MedianFromArray(hist_vals);
      bucket.diagnostics.bucket_top5_confidence_median = MedianFromArray(conf_vals);
      for(int i=0;i<n;i++)
        {
         const ISSX_EA3_SymbolSelection &s=state.symbols[bucket.ranked_indices[i]];
         if(s.rankability_lane==issx_rankability_strong)
            bucket.diagnostics.bucket_depth_strong++;
         else if(s.rankability_lane==issx_rankability_usable)
            bucket.diagnostics.bucket_depth_compare_safe++;
         else if(s.rankability_lane==issx_rankability_exploratory)
            bucket.diagnostics.bucket_depth_degraded++;
        }
      bucket.diagnostics.bucket_truth_score = Clamp01(0.40*bucket.diagnostics.bucket_truth_median
                                                    +0.35*bucket.diagnostics.bucket_history_median
                                                    +0.25*bucket.diagnostics.bucket_tradeability_median);
      bucket.diagnostics.bucket_publishability_score = Clamp01(0.50*bucket.diagnostics.bucket_truth_score
                                                             +0.30*bucket.diagnostics.bucket_top5_confidence_median
                                                             +0.20*Clamp01((double)MathMin(n,ISSX_EA3_TOP5_LIMIT)/(double)ISSX_EA3_TOP5_LIMIT));
      bucket.diagnostics.bucket_competition_strength = Clamp01((n>1 ? state.symbols[bucket.ranked_indices[0]].bucket_local_composite
                                                                     - state.symbols[bucket.ranked_indices[n-1]].bucket_local_composite
                                                                   : bucket.diagnostics.bucket_top5_confidence_median));
      bucket.diagnostics.bucket_duplication_pressure = Clamp01((double)bucket.diagnostics.duplicate_collapsed_count/(double)MathMax(1,n));
      bucket.diagnostics.bucket_rotation_pressure_score = Clamp01((double)bucket.diagnostics.survivor_turnover_count_recent/(double)ISSX_EA3_TOP5_LIMIT);

      int top_n=ArraySize(bucket.top5_indices);
      double floor=1.0;
      for(int i=0;i<top_n;i++)
        {
         double v=state.symbols[bucket.top5_indices[i]].bucket_local_composite;
         if(i==0 || v<floor) floor=v;
        }
      bucket.diagnostics.bucket_top5_truth_floor=(top_n>0 ? floor : 0.0);

      if(top_n<=0 || bucket.diagnostics.bucket_truth_score<0.30)
         bucket.diagnostics.bucket_publishability_state=issx_publishability_not_ready;
      else if(bucket.diagnostics.bucket_publishability_score<0.45)
         bucket.diagnostics.bucket_publishability_state=issx_publishability_usable_degraded;
      else if(bucket.diagnostics.bucket_publishability_score<0.70)
         bucket.diagnostics.bucket_publishability_state=issx_publishability_usable;
      else
         bucket.diagnostics.bucket_publishability_state=issx_publishability_strong;

      if(n<ISSX_EA3_TOP5_LIMIT)
         bucket.diagnostics.bucket_shortfall_root_causes="depth_shortfall";
      if(bucket.diagnostics.blocked_tradeability_count>0)
         bucket.diagnostics.bucket_shortfall_root_causes = (bucket.diagnostics.bucket_shortfall_root_causes=="" ? "blocked_tradeability" : bucket.diagnostics.bucket_shortfall_root_causes+"|blocked_tradeability");
      if(bucket.diagnostics.weak_history_count>0)
         bucket.diagnostics.bucket_shortfall_root_causes = (bucket.diagnostics.bucket_shortfall_root_causes=="" ? "weak_history" : bucket.diagnostics.bucket_shortfall_root_causes+"|weak_history");

      if(top_n<=0) bucket.diagnostics.bucket_shortfall_reason="no_rankable_members";
      else if(top_n<ISSX_EA3_TOP5_LIMIT) bucket.diagnostics.bucket_shortfall_reason="published_fewer_than_5";
      else bucket.diagnostics.bucket_shortfall_reason="none";

      if(bucket.diagnostics.bucket_publishability_score<0.40)
         bucket.diagnostics.bucket_strength_class=issx_ea3_bucket_weak;
      else if(bucket.diagnostics.bucket_publishability_score<0.70)
         bucket.diagnostics.bucket_strength_class=issx_ea3_bucket_fair;
      else
         bucket.diagnostics.bucket_strength_class=issx_ea3_bucket_strong;

      if(n<5) bucket.diagnostics.bucket_depth_quality=issx_ea3_depth_shallow;
      else if(n<10) bucket.diagnostics.bucket_depth_quality=issx_ea3_depth_adequate;
      else bucket.diagnostics.bucket_depth_quality=issx_ea3_depth_deep;
     }

   static void ScanLocalContradictions(ISSX_EA3_State &state)
     {
      state.counters.contradiction_count=0;
      state.counters.blocking_contradiction_count=0;

      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         ISSX_EA3_SymbolSelection &s=state.symbols[i];
         s.contradiction_severity_max=issx_contradiction_low;

         if(s.selected_top5 && s.bucket_local_composite>=0.70 && s.history_data_quality_score<0.30)
           {
            s.contradiction_severity_max=issx_contradiction_high;
            state.counters.contradiction_count++;
           }
         if(s.selected_frontier && s.frontier_confidence>=0.70 && s.upstream_instability_sources!="")
           {
            if(s.contradiction_severity_max<issx_contradiction_moderate)
               s.contradiction_severity_max=issx_contradiction_moderate;
            state.counters.contradiction_count++;
           }
         if(s.selected_top5 && s.duplicate_family_rejected)
           {
            s.contradiction_severity_max=issx_contradiction_blocking;
            state.counters.contradiction_count++;
            state.counters.blocking_contradiction_count++;
           }
        }
     }

   static void RefreshManifest(ISSX_EA3_State &state,const string firm_id)
     {
      long minute_id=ISSX_Time::NowMinuteId();

      state.header.stage_id=issx_stage_ea3;
      state.header.firm_id=firm_id;
      state.header.schema_version=ISSX_SCHEMA_VERSION;
      state.header.schema_epoch=ISSX_SCHEMA_EPOCH;
      state.header.sequence_no=minute_id;
      state.header.minute_id=minute_id;
      state.header.writer_boot_id="ea3_selection_core";
      state.header.writer_nonce=IntegerToString((int)minute_id);
      state.header.writer_generation=minute_id;
      state.header.symbol_count=ArraySize(state.symbols);
      state.header.changed_symbol_count=state.delta.changed_symbol_count;
      state.header.cohort_fingerprint=state.cohort_fingerprint;
      state.header.universe_fingerprint=state.universe.rankable_universe_fingerprint;
      state.header.contradiction_count=state.counters.contradiction_count;
      state.header.contradiction_severity_max=(state.counters.blocking_contradiction_count>0 ? issx_contradiction_blocking : issx_contradiction_low);
      state.header.degraded_flag=state.degraded_flag;
      state.header.fallback_depth_used=state.fallback_depth_used;

      state.manifest.stage_id=issx_stage_ea3;
      state.manifest.firm_id=firm_id;
      state.manifest.schema_version=ISSX_SCHEMA_VERSION;
      state.manifest.schema_epoch=ISSX_SCHEMA_EPOCH;
      state.manifest.sequence_no=state.header.sequence_no;
      state.manifest.minute_id=minute_id;
      state.manifest.writer_boot_id=state.header.writer_boot_id;
      state.manifest.writer_nonce=state.header.writer_nonce;
      state.manifest.writer_generation=state.header.writer_generation;
      state.manifest.symbol_count=ArraySize(state.symbols);
      state.manifest.changed_symbol_count=state.delta.changed_symbol_count;
      state.manifest.content_class=(ArraySize(state.frontier)>0 ? issx_content_usable : issx_content_partial);
      state.manifest.publish_reason=issx_publish_scheduled;
      state.manifest.cohort_fingerprint=state.cohort_fingerprint;
      state.manifest.taxonomy_hash=state.taxonomy_hash;
      state.manifest.comparator_registry_hash=state.comparator_registry_hash;
      state.manifest.universe_fingerprint=state.universe.rankable_universe_fingerprint;
      state.manifest.compatibility_class=state.upstream_compatibility_class;
      state.manifest.contradiction_count=state.counters.contradiction_count;
      state.manifest.contradiction_severity_max=(state.counters.blocking_contradiction_count>0 ? issx_contradiction_blocking : issx_contradiction_low);
      state.manifest.degraded_flag=state.degraded_flag;
      state.manifest.fallback_depth_used=state.fallback_depth_used;
      state.manifest.accepted_strong_count=state.counters.selected_symbols_total;
      state.manifest.accepted_degraded_count=(state.degraded_flag ? state.counters.frontier_count : 0);
      state.manifest.rejected_count=MathMax(0,ArraySize(state.symbols)-state.counters.selected_symbols_total);
      state.manifest.cooldown_count=0;
      state.manifest.stale_usable_count=0;
      state.manifest.projection_partial_success_flag=state.projection_partial_success_flag;
      state.manifest.accepted_promotion_verified=false;
      state.manifest.stage_minimum_ready_flag=state.stage_minimum_ready_flag;
      state.manifest.stage_publishability_state=state.stage_publishability_state;
      state.manifest.handoff_mode=issx_handoff_loaded_internal_current;
      state.manifest.handoff_sequence_no=state.header.sequence_no;
      state.manifest.fallback_read_ratio_1h=0.0;
      state.manifest.fresh_accept_ratio_1h=1.0;
      state.manifest.same_tick_handoff_ratio_1h=0.0;
      state.manifest.legend_hash="";
     }

public:
   static void ResetState(ISSX_EA3_State &state)
     {
      state.Reset();
      ISSX_BudgetPolicy::ApplyStageDefaults(issx_stage_ea3,state.runtime.budgets);
     }

   static void InheritUpstreamContext(ISSX_EA3_State &state,
                                      const ISSX_EA1_State &ea1,
                                      const ISSX_EA2_State &ea2)
     {
      state.universe.broker_universe=ea1.universe.broker_universe;
      state.universe.eligible_universe=ea1.universe.eligible_universe;
      state.universe.active_universe=ea1.universe.active_universe;
      state.universe.rankable_universe=ea2.universe.rankable_universe;
      state.universe.broker_universe_fingerprint=ea1.universe.broker_universe_fingerprint;
      state.universe.eligible_universe_fingerprint=ea1.universe.eligible_universe_fingerprint;
      state.universe.active_universe_fingerprint=ea1.universe.active_universe_fingerprint;
      state.universe.rankable_universe_fingerprint=ea2.universe.rankable_universe_fingerprint;
      state.universe.universe_drift_class=ea2.universe.universe_drift_class;

      state.upstream_source_used="ea1_current|ea2_current";
      state.upstream_source_reason="exact_input";
      state.upstream_compatibility_class=issx_compatibility_exact;
      state.upstream_compatibility_score=1.0;
      state.fallback_depth_used=0;
      state.fallback_penalty_applied=0.0;
      state.taxonomy_hash=ea1.taxonomy_hash;
      state.comparator_registry_hash=ea1.comparator_registry_hash;
      state.cohort_fingerprint=ISSX_Hash::HashStringHex(ea1.universe.rankable_universe_fingerprint+"|"+ea2.universe.rankable_universe_fingerprint);
     }

   static void SeedSymbolsFromInputs(ISSX_EA3_State &state,
                                     const ISSX_EA1_State &ea1,
                                     const ISSX_EA2_State &ea2)
     {
      ArrayResize(state.symbols,0);
      state.counters.Reset();
      state.delta.Reset();

      int n1=ArraySize(ea1.symbols);
      int n2=ArraySize(ea2.symbols);

      for(int i=0;i<n1;i++)
        {
         const ISSX_EA1_SymbolState &m=ea1.symbols[i];
         int hidx=-1;
         for(int j=0;j<n2;j++)
           {
            if(ea2.symbols[j].symbol_norm==m.normalized_identity.symbol_norm ||
               ea2.symbols[j].symbol_raw==m.raw_broker_observation.symbol_raw)
              {
               hidx=j;
               break;
              }
           }
         if(hidx<0)
            continue;

         const ISSX_EA2_SymbolState &h=ea2.symbols[hidx];
         ISSX_EA3_SymbolSelection s;
         s.Reset();

         s.symbol_raw=m.raw_broker_observation.symbol_raw;
         s.symbol_norm=m.normalized_identity.symbol_norm;
         s.canonical_root=m.normalized_identity.canonical_root;
         s.alias_family_id=m.normalized_identity.alias_family_id;
         s.leader_bucket_id=m.classification_truth.leader_bucket_id;
         s.leader_bucket_type=m.classification_truth.leader_bucket_type;
         s.rankable=IsSymbolRankable(m,h);

         s.observability_score=ComputeObservabilityScore(m);
         s.trade_cost_usability_score=ComputeTradeCostUsabilityScore(m);
         s.history_data_quality_score=ComputeHistoryQualityScore(h);
         s.classification_reliability_score=ComputeClassificationReliabilityScore(m);

         int mem_idx=FindSurvivorMemory(state,s.symbol_norm);
         int mem_age=(mem_idx>=0 ? state.survivor_memory[mem_idx].survivor_age_cycles : 0);
         int mem_weak=(mem_idx>=0 ? state.survivor_memory[mem_idx].weak_hold_count : 0);
         s.stability_score=ComputeStabilityScore(m,h,mem_age,mem_weak);
         s.bucket_local_composite=ComputeComposite(s);
         if(s.rankability_lane==issx_rankability_exploratory)
            s.bucket_local_composite=Clamp01(s.bucket_local_composite-s.exploratory_penalty_applied);
         s.peer_comparability_score=ComputePeerComparability(h);
         s.bucket_comparison_completeness=s.peer_comparability_score;
         s.comparison_penalty=ComputeComparisonPenalty(s);
         s.micro_cleanliness_score=ComputeMicroCleanlinessScore(m,h);
         s.overlap_noise_score=ComputeOverlapNoiseScore(m,h);
         s.range_efficiency_score=ComputeRangeEfficiencyScore(h);
         s.spec_only_cheapness_flag=(s.trade_cost_usability_score>=0.70 && s.history_data_quality_score<0.30);
         if(!s.rankable)
           {
            s.rankability_lane=issx_rankability_blocked;
            s.dependency_block_reason="insufficient_rankable_truth";
           }
         else if(s.observability_score>=0.65 && s.trade_cost_usability_score>=0.55 && s.history_data_quality_score>=0.60 && s.peer_comparability_score>=0.55)
           {
            s.rankability_lane=issx_rankability_strong;
           }
         else if(s.observability_score>=0.45 && s.trade_cost_usability_score>=0.35 && s.history_data_quality_score>=0.40)
           {
            s.rankability_lane=issx_rankability_usable;
           }
         else
           {
            s.rankability_lane=issx_rankability_exploratory;
            s.exploratory_penalty_applied=0.12;
            s.dependency_block_reason="exploratory_quality_cap";
           }
         s.upstream_instability_sources=(h.provenance.history_flap_risk>0.50 ? "history_flap" : "");
         if(m.rankability_gate.gate_flap_count>0)
            s.upstream_instability_sources=(s.upstream_instability_sources=="" ? "rank_gate_flap" : s.upstream_instability_sources+"|rank_gate_flap");
         if(mem_idx>=0)
           {
            s.survivor_age_cycles=state.survivor_memory[mem_idx].survivor_age_cycles;
            s.incumbent_weak_hold_count=state.survivor_memory[mem_idx].weak_hold_count;
            s.hysteresis_decay_score=Clamp01((double)state.survivor_memory[mem_idx].weak_hold_count/5.0);
           }

         if(!s.rankable)
           {
            s.not_top5_reason_primary="truth_floor";
            s.acceptance_type=issx_accept_rejected;
            s.truth_class=issx_truth_weak;
           }
         else
           {
            s.acceptance_type=(s.history_data_quality_score>=0.35 ? issx_accept_ranking : issx_accept_degraded);
            s.truth_class=(s.bucket_local_composite>=0.70 ? issx_truth_strong :
                          (s.bucket_local_composite>=0.50 ? issx_truth_acceptable :
                          (s.bucket_local_composite>=0.35 ? issx_truth_degraded : issx_truth_weak)));
           }
         s.freshness_class=(h.freshness_class==issx_freshness_stale ? issx_freshness_aging : h.freshness_class);
         s.winner_archetype_class=(s.trade_cost_usability_score>=0.65 && s.history_data_quality_score>=0.60 ? "clean_intraday" :
                                  (s.rankability_lane==issx_rankability_exploratory ? "exploratory_context" :
                                  (s.peer_comparability_score>=0.60 ? "balanced_rankable" : "emerging_rankable")));

         int idx=ArraySize(state.symbols);
         ArrayResize(state.symbols,idx+1);
         state.symbols[idx]=s;

         if(m.changed_this_cycle || h.changed_since_last_publish)
           {
            state.delta.changed_symbol_count++;
            state.delta.changed_symbol_ids=(state.delta.changed_symbol_ids=="" ? s.symbol_norm : state.delta.changed_symbol_ids+"|"+s.symbol_norm);
           }

         if(!s.rankable)
           {
            if(IsTradeabilityBlocked(m.tradeability_baseline.tradeability_class)) state.counters.blocked_tradeability_count++;
            if(s.history_data_quality_score<0.35) state.counters.weak_history_count++;
            if(s.observability_score<0.35) state.counters.weak_observability_count++;
            if(s.classification_reliability_score<0.35) state.counters.weak_classification_count++;
            continue;
           }

         int bucket_idx=EnsureBucket(state,s.leader_bucket_id,s.leader_bucket_type);
         PushIndex(state.buckets[bucket_idx].member_indices,idx);
         if(m.changed_this_cycle || h.changed_since_last_publish)
            state.buckets[bucket_idx].changed_members_this_cycle++;
        }

      state.counters.bucket_count=ArraySize(state.buckets);
     }

   static void CollapseFamilies(ISSX_EA3_State &state)
     {
      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         ISSX_EA3_BucketState &bucket=state.buckets[b];
         ArrayResize(bucket.ranked_indices,0);

         string seen_families[];
         ArrayResize(seen_families,0);

         for(int i=0;i<ArraySize(bucket.member_indices);i++)
           {
            int sym_idx=bucket.member_indices[i];
            const ISSX_EA3_SymbolSelection &s=state.symbols[sym_idx];
            string fam=s.alias_family_id;
            if(fam=="") fam=s.symbol_norm;

            bool seen=false;
            for(int k=0;k<ArraySize(seen_families);k++)
              {
               if(seen_families[k]==fam)
                 {
                  seen=true;
                  break;
                 }
              }
            if(seen)
               continue;

            int winner=FamilyRepresentativeForBucket(state,b,fam);
            if(winner>=0)
              {
               PushIndex(bucket.ranked_indices,winner);
               int n=ArraySize(seen_families);
               ArrayResize(seen_families,n+1);
               seen_families[n]=fam;
              }
           }

         for(int i=0;i<ArraySize(bucket.member_indices);i++)
           {
            int sym_idx=bucket.member_indices[i];
            bool kept=false;
            for(int k=0;k<ArraySize(bucket.ranked_indices);k++)
               if(bucket.ranked_indices[k]==sym_idx)
                 { kept=true; break; }
            if(!kept)
              {
               state.symbols[sym_idx].duplicate_family_rejected=true;
               state.symbols[sym_idx].not_top5_reason_primary="family_collapse";
               state.counters.duplicate_collapsed_count++;
              }
           }

         SortIndicesByComposite(state,bucket.ranked_indices);
        }
     }

   static void RankBuckets(ISSX_EA3_State &state)
     {
      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         ISSX_EA3_BucketState &bucket=state.buckets[b];
         ArrayResize(bucket.top5_indices,0);

         int n=ArraySize(bucket.ranked_indices);
         for(int i=0;i<n;i++)
           {
            int idx=bucket.ranked_indices[i];
            ISSX_EA3_SymbolSelection &s=state.symbols[idx];

            s.bucket_rank=i+1;
            s.bucket_member_quality_rank=i+1;
            s.bucket_competition_percentile=(n>1 ? 1.0-((double)i/(double)(n-1)) : 1.0);
            s.nearest_reserve_gap=(i<ISSX_EA3_TOP5_LIMIT || n<=ISSX_EA3_TOP5_LIMIT ? 0.0
                                   : state.symbols[bucket.ranked_indices[ISSX_EA3_TOP5_LIMIT-1]].bucket_local_composite-s.bucket_local_composite);

            bool allow_select = (i<ISSX_EA3_TOP5_LIMIT);
            if(allow_select && s.bucket_local_composite<state.hysteresis.enter_threshold)
              {
               bool incumbent=WasTop5LastCycle(state,s.symbol_norm) && s.survivor_age_cycles>=state.hysteresis.min_hold_cycles;
               if(incumbent && s.bucket_local_composite>=state.hysteresis.hold_threshold)
                 {
                  s.won_on_hysteresis_only_flag=true;
                  state.counters.hysteresis_hold_count++;
                  allow_select=true;
                 }
               else
                 {
                  allow_select=false;
                  s.not_top5_reason_primary="below_enter_threshold";
                 }
              }

            if(allow_select)
              {
               s.selected_top5=true;
               s.bucket_top5_rank=ArraySize(bucket.top5_indices)+1;
               s.won_by_strength=(s.bucket_local_composite>=state.hysteresis.enter_threshold);
               s.won_by_shortfall=(n<ISSX_EA3_TOP5_LIMIT);
               s.replacement_reason_code=(s.won_by_strength ? "strength_win" : (s.won_on_hysteresis_only_flag ? "hysteresis_hold" : "shortfall_fill"));
               PushIndex(bucket.top5_indices,idx);
              }
           }

         // enforce publish fewer than 5 if weak bucket
         if(ArraySize(bucket.top5_indices)>0)
           {
            double floor=1.0;
            for(int i=0;i<ArraySize(bucket.top5_indices);i++)
              {
               double c=state.symbols[bucket.top5_indices[i]].bucket_local_composite;
               if(i==0 || c<floor) floor=c;
              }
            if(floor<0.25)
              {
               ArrayResize(bucket.top5_indices,MathMax(1,ArraySize(bucket.top5_indices)-1));
               bucket.diagnostics.bucket_primary_thinning_reason="weak_bucket_floor";
               for(int i=0;i<ArraySize(state.symbols);i++)
                  if(state.symbols[i].selected_top5 && state.symbols[i].leader_bucket_id==bucket.bucket_id)
                     if(state.symbols[i].bucket_top5_rank>ArraySize(bucket.top5_indices))
                        state.symbols[i].selected_top5=false;
              }
           }

         BuildBucketDiagnostics(state,bucket);

         for(int i=0;i<ArraySize(bucket.top5_indices);i++)
           {
            ISSX_EA3_SymbolSelection &s=state.symbols[bucket.top5_indices[i]];
            double margin=(ArraySize(bucket.ranked_indices)>ArraySize(bucket.top5_indices) ?
                          s.bucket_local_composite-state.symbols[bucket.ranked_indices[ArraySize(bucket.top5_indices)]].bucket_local_composite
                          : s.bucket_local_composite);
            s.replacement_pressure=Clamp01(1.0-margin);
            if(s.replacement_pressure<0.15) s.position_security_class=issx_ea3_security_locked;
            else if(s.replacement_pressure<0.30) s.position_security_class=issx_ea3_security_stable;
            else if(s.replacement_pressure<0.50) s.position_security_class=issx_ea3_security_contested;
            else s.position_security_class=issx_ea3_security_fragile;
           }
        }
     }

   static void AssignReserves(ISSX_EA3_State &state)
     {
      state.counters.reserve_count=0;
      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         ISSX_EA3_BucketState &bucket=state.buckets[b];
         ArrayResize(bucket.reserve_indices,0);

         int start=ArraySize(bucket.top5_indices);
         for(int i=start;i<ArraySize(bucket.ranked_indices) && ArraySize(bucket.reserve_indices)<ISSX_EA3_RESERVE_LIMIT;i++)
           {
            int idx=bucket.ranked_indices[i];
            ISSX_EA3_SymbolSelection &s=state.symbols[idx];
            s.selected_reserve=true;
            s.reserve_confidence=Clamp01(0.65*s.bucket_local_composite + 0.35*s.peer_comparability_score);
            s.reserve_promotion_condition="incumbent_drop_or_truth_gain";
            s.reserve_blockers=(s.comparison_penalty>0.40 ? "comparison_penalty" : "");
            s.reserve_promoted_for_diversity_flag=false;
            PushIndex(bucket.reserve_indices,idx);
            state.counters.reserve_count++;
           }

         for(int i=0;i<ArraySize(bucket.top5_indices);i++)
           {
            ISSX_EA3_SymbolSelection &top=state.symbols[bucket.top5_indices[i]];
            if(ArraySize(bucket.reserve_indices)>0)
               top.nearest_reserve_gap=top.bucket_local_composite-state.symbols[bucket.reserve_indices[0]].bucket_local_composite;
            else
               top.nearest_reserve_gap=top.bucket_local_composite;
           }
        }
     }

   static void BuildFrontier(ISSX_EA3_State &state)
     {
      ArrayResize(state.frontier,0);

      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         ISSX_EA3_BucketState &bucket=state.buckets[b];

         for(int i=0;i<ArraySize(bucket.top5_indices);i++)
           {
            int idx=bucket.top5_indices[i];
            ISSX_EA3_SymbolSelection &s=state.symbols[idx];

            double hold_bonus=Clamp01((double)s.survivor_age_cycles/10.0)*0.05;
            double challenger_bonus=(s.challenger_override_ready ? 0.04 : 0.0);
            double truth_floor=Clamp01((s.observability_score+s.history_data_quality_score+s.classification_reliability_score)/3.0);
            double freshness_adj=(s.freshness_class==issx_freshness_fresh ? 0.03 :
                                 (s.freshness_class==issx_freshness_usable ? 0.01 : -0.03));
            double continuity_bonus=Clamp01((double)s.survivor_age_cycles/10.0)*0.03;
            double instability_penalty=0.08*Clamp01((double)s.incumbent_weak_hold_count/5.0) + 0.10*s.comparison_penalty;
            s.hysteresis_decay_score=Clamp01((double)s.incumbent_weak_hold_count/5.0);
            s.frontier_confidence=Clamp01(0.50*s.bucket_local_composite
                                         +0.20*truth_floor
                                         +0.15*s.peer_comparability_score
                                         +0.15*(1.0-s.comparison_penalty));
            double promotion_score=Clamp01(s.bucket_local_composite + hold_bonus + challenger_bonus + continuity_bonus + freshness_adj - instability_penalty);

            s.selected_frontier=true;
            s.frontier_entry_reason_primary=(s.won_by_strength ? "bucket_top5_strength" : "bucket_top5_shortfall");
            s.frontier_entry_reason_secondary=(s.won_on_hysteresis_only_flag ? "hysteresis_hold" : "frontier_standard");
            s.frontier_survival_risk=Clamp01(0.55*s.replacement_pressure + 0.45*s.hysteresis_decay_score);
            s.redundancy_swap_reason=(s.comparison_penalty>=0.40 ? "high_similarity_penalty" : "");

            int f=ArraySize(state.frontier);
            ArrayResize(state.frontier,f+1);
            state.frontier[f].Reset();
            state.frontier[f].symbol_index=idx;
            state.frontier[f].symbol_norm=s.symbol_norm;
            state.frontier[f].symbol_raw=s.symbol_raw;
            state.frontier[f].bucket_id=s.leader_bucket_id;
            state.frontier[f].frontier_promotion_score=promotion_score;
            state.frontier[f].frontier_confidence=s.frontier_confidence;
            state.frontier[f].entry_reason_primary=s.frontier_entry_reason_primary;
            state.frontier[f].entry_reason_secondary=s.frontier_entry_reason_secondary;
           }
        }

      // sort frontier by promotion score and cap softly
      int n=ArraySize(state.frontier);
      for(int i=0;i<n-1;i++)
        {
         int best=i;
         for(int j=i+1;j<n;j++)
            if(state.frontier[j].frontier_promotion_score>state.frontier[best].frontier_promotion_score)
               best=j;
         if(best!=i)
           {
            ISSX_EA3_FrontierItem tmp=state.frontier[i];
            state.frontier[i]=state.frontier[best];
            state.frontier[best]=tmp;
           }
        }
      if(n>ISSX_EA3_FRONTIER_SOFT_LIMIT)
         ArrayResize(state.frontier,ISSX_EA3_FRONTIER_SOFT_LIMIT);

      state.universe.frontier_universe=ArraySize(state.frontier);
      state.universe.publishable_universe=ArraySize(state.frontier);
      state.counters.frontier_count=ArraySize(state.frontier);
      state.universe.frontier_universe_fingerprint=ISSX_Hash::HashStringHex(IntegerToString(state.counters.frontier_count)+"|"+state.delta.changed_symbol_ids);
      state.universe.publishable_universe_fingerprint=state.universe.frontier_universe_fingerprint;
     }

   static void UpdateSurvivorContinuity(ISSX_EA3_State &state)
     {
      ISSX_EA3_SurvivorMemory next_mem[];
      ArrayResize(next_mem,0);

      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         ISSX_EA3_SymbolSelection &s=state.symbols[i];
         if(!(s.selected_top5 || s.selected_frontier || s.selected_reserve))
            continue;

         int old_idx=FindSurvivorMemory(state,s.symbol_norm);
         ISSX_EA3_SurvivorMemory mem;
         mem.Reset();
         mem.symbol_norm=s.symbol_norm;
         mem.bucket_id=s.leader_bucket_id;
         mem.was_top5=s.selected_top5;
         mem.was_frontier=s.selected_frontier;
         mem.last_composite=s.bucket_local_composite;
         mem.last_minute_id=ISSX_Time::NowMinuteId();

         if(old_idx>=0)
           {
            mem.survivor_age_cycles=state.survivor_memory[old_idx].survivor_age_cycles+1;
            mem.weak_hold_count=state.survivor_memory[old_idx].weak_hold_count;
            mem.promote_cooldown_remaining=MathMax(0,state.survivor_memory[old_idx].promote_cooldown_remaining-1);

            if(s.won_on_hysteresis_only_flag)
              {
               mem.weak_hold_count++;
               state.counters.hysteresis_weak_decay_count++;
              }
            if(s.challenger_override_ready)
               state.counters.challenger_override_count++;
           }
         else
           {
            mem.survivor_age_cycles=1;
            mem.weak_hold_count=0;
            mem.promote_cooldown_remaining=state.hysteresis.promote_cooldown;
            state.counters.survivor_turnover_count_recent++;
           }

         int n=ArraySize(next_mem);
         ArrayResize(next_mem,n+1);
         next_mem[n]=mem;

         s.survivor_age_cycles=mem.survivor_age_cycles;
         s.reserve_age_cycles=mem.survivor_age_cycles;
         s.incumbent_weak_hold_count=mem.weak_hold_count;
         s.hysteresis_decay_score=Clamp01((double)mem.weak_hold_count/5.0);
         s.challenger_override_ready=(s.replacement_pressure<0.20 && s.bucket_local_composite>=state.hysteresis.enter_threshold+0.05);
         s.survivor_churn_penalty=Clamp01((double)state.counters.survivor_turnover_count_recent/10.0);
        }

      ArrayResize(state.survivor_memory,ArraySize(next_mem));
      for(int i=0;i<ArraySize(next_mem);i++)
         state.survivor_memory[i]=next_mem[i];

      for(int b=0;b<ArraySize(state.buckets);b++)
         state.buckets[b].diagnostics.survivor_turnover_count_recent=state.counters.survivor_turnover_count_recent;
     }

   static bool BuildFromInputs(const string firm_id,
                               const ISSX_EA1_State &ea1,
                               const ISSX_EA2_State &ea2,
                               ISSX_EA3_State &state)
     {
      ResetState(state);
      InheritUpstreamContext(state,ea1,ea2);

      ISSX_PhaseScheduler::BeginPhase(state.runtime,issx_phase_ea3_load_upstream,60,"ea3_load");
      SeedSymbolsFromInputs(state,ea1,ea2);

      ISSX_PhaseScheduler::BeginPhase(state.runtime,issx_phase_ea3_build_bucket_sets_delta_first,80,"ea3_bucket");
      CollapseFamilies(state);

      ISSX_PhaseScheduler::BeginPhase(state.runtime,issx_phase_ea3_rank_buckets,120,"ea3_rank");
      RankBuckets(state);

      ISSX_PhaseScheduler::BeginPhase(state.runtime,issx_phase_ea3_assign_reserves,60,"ea3_reserves");
      AssignReserves(state);

      ISSX_PhaseScheduler::BeginPhase(state.runtime,issx_phase_ea3_build_frontier,80,"ea3_frontier");
      BuildFrontier(state);

      ISSX_PhaseScheduler::BeginPhase(state.runtime,issx_phase_ea3_update_survivor_continuity,60,"ea3_survivor");
      UpdateSurvivorContinuity(state);

      ScanLocalContradictions(state);

      state.counters.selected_symbols_total=0;
      for(int i=0;i<ArraySize(state.symbols);i++)
         if(state.symbols[i].selected_top5)
            state.counters.selected_symbols_total++;

      state.delta.changed_bucket_count=0;
      state.delta.changed_frontier_count=state.counters.frontier_count;
      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         if(state.buckets[b].changed_members_this_cycle>0)
            state.delta.changed_bucket_count++;
         state.buckets[b].changed_this_cycle=(state.buckets[b].changed_members_this_cycle>0);
        }

      state.universe.rankable_universe=0;
      for(int i=0;i<ArraySize(state.symbols);i++)
         if(state.symbols[i].rankable)
            state.universe.rankable_universe++;

      state.degraded_flag=(state.counters.frontier_count<=0 || state.counters.selected_symbols_total<=0);
      state.stage_minimum_ready_flag=(state.universe.rankable_universe>0);
      state.stage_publishability_state=(state.counters.selected_symbols_total>=ISSX_EA3_TOP5_LIMIT ? issx_publishability_strong :
                                       (state.counters.selected_symbols_total>0 ? (state.degraded_flag ? issx_publishability_usable_degraded : issx_publishability_usable) :
                                       (state.stage_minimum_ready_flag ? issx_publishability_warmup : issx_publishability_not_ready)));
      state.dependency_block_reason=(state.universe.rankable_universe<=0 ? "rankable_subset_too_thin" :
                                    (state.counters.selected_symbols_total<=0 ? "no_publishable_bucket_survivors" : ""));
      state.debug_weak_link_code=(state.dependency_block_reason!="" ? issx_weak_link_dependency_block :
                                 (state.degraded_flag ? issx_weak_link_queue_backlog : issx_weak_link_none));
      RefreshManifest(state,firm_id);
      return true;
     }


   static bool StageBoot(const string firm_id,
                         const ISSX_EA1_State &ea1,
                         const ISSX_EA2_State &ea2,
                         ISSX_EA3_State &state)
     {
      return BuildFromInputs(firm_id,ea1,ea2,state);
     }

   static bool StageSlice(const string firm_id,
                          const ISSX_EA1_State &ea1,
                          const ISSX_EA2_State &ea2,
                          ISSX_EA3_State &state)
     {
      return BuildFromInputs(firm_id,ea1,ea2,state);
     }

   static bool StagePublish(const ISSX_EA3_State &state,string &stage_json,string &debug_json)
     {
      stage_json=ToStageJson(state);
      debug_json=ToDebugJson(state);
      return (StringLen(stage_json)>2);
     }

   static string BuildDebugSnapshot(const ISSX_EA3_State &state)
     {
      return ToDebugJson(state);
     }

   static string ToStageJson(const ISSX_EA3_State &state)
     {
      string out="{";
      out+="\"stage\":\"ea3\"";
      out+=",\"schema_version\":\""+ISSX_Util::EscapeJson(ISSX_SCHEMA_VERSION)+"\"";
      out+=",\"schema_epoch\":"+IntegerToString(ISSX_SCHEMA_EPOCH);
      out+=",\"minute_id\":"+IntegerToString((int)state.manifest.minute_id);
      out+=",\"sequence_no\":"+IntegerToString((int)state.manifest.sequence_no);
      out+=",\"upstream_source_used\":\""+ISSX_Util::EscapeJson(state.upstream_source_used)+"\"";
      out+=",\"upstream_source_reason\":\""+ISSX_Util::EscapeJson(state.upstream_source_reason)+"\"";
      out+=",\"compatibility_class\":\""+CompatibilityClassToString(state.upstream_compatibility_class)+"\"";
      out+=",\"degraded_flag\":"+ISSX_Util::BoolToString(state.degraded_flag);

      out+=",\"buckets\":[";
      bool first=true;
      for(int b=0;b<ArraySize(state.buckets);b++)
        {
         if(!first) out+=",";
         first=false;
         out+="{";
         out+="\"bucket_id\":\""+ISSX_Util::EscapeJson(state.buckets[b].bucket_id)+"\"";
         out+=",\"bucket_strength_class\":\""+BucketStrengthClassToString(state.buckets[b].diagnostics.bucket_strength_class)+"\"";
         out+=",\"bucket_depth_quality\":\""+BucketDepthQualityToString(state.buckets[b].diagnostics.bucket_depth_quality)+"\"";
         out+=",\"bucket_publishability_state\":\""+PublishabilityStateToString(state.buckets[b].diagnostics.bucket_publishability_state)+"\"";
         out+=",\"bucket_truth_score\":"+DoubleToString(state.buckets[b].diagnostics.bucket_truth_score,6);
         out+=",\"bucket_publishability_score\":"+DoubleToString(state.buckets[b].diagnostics.bucket_publishability_score,6);
         out+=",\"bucket_top5_truth_floor\":"+DoubleToString(state.buckets[b].diagnostics.bucket_top5_truth_floor,6);
         out+=",\"member_count\":"+IntegerToString(ArraySize(state.buckets[b].member_indices));
         out+=",\"top5_count\":"+IntegerToString(ArraySize(state.buckets[b].top5_indices));
         out+=",\"reserve_count\":"+IntegerToString(ArraySize(state.buckets[b].reserve_indices));
         out+="}";
        }
      out+="]";

      out+=",\"symbols\":[";
      first=true;
      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         const ISSX_EA3_SymbolSelection &s=state.symbols[i];
         if(!s.selected_top5 && !s.selected_reserve && !s.selected_frontier)
            continue;
         if(!first) out+=",";
         first=false;
         out+="{";
         out+="\"symbol_raw\":\""+ISSX_Util::EscapeJson(s.symbol_raw)+"\"";
         out+=",\"symbol_norm\":\""+ISSX_Util::EscapeJson(s.symbol_norm)+"\"";
         out+=",\"leader_bucket_id\":\""+ISSX_Util::EscapeJson(s.leader_bucket_id)+"\"";
         out+=",\"bucket_local_composite\":"+DoubleToString(s.bucket_local_composite,6);
         out+=",\"bucket_rank\":"+IntegerToString(s.bucket_rank);
         out+=",\"bucket_top5_rank\":"+IntegerToString(s.bucket_top5_rank);
         out+=",\"selected_top5\":"+ISSX_Util::BoolToString(s.selected_top5);
         out+=",\"selected_reserve\":"+ISSX_Util::BoolToString(s.selected_reserve);
         out+=",\"selected_frontier\":"+ISSX_Util::BoolToString(s.selected_frontier);
         out+=",\"frontier_entry_reason_primary\":\""+ISSX_Util::EscapeJson(s.frontier_entry_reason_primary)+"\"";
         out+=",\"frontier_confidence\":"+DoubleToString(s.frontier_confidence,6);
         out+=",\"peer_comparability_score\":"+DoubleToString(s.peer_comparability_score,6);
         out+=",\"comparison_penalty\":"+DoubleToString(s.comparison_penalty,6);
         out+=",\"position_security_class\":\""+PositionSecurityClassToString(s.position_security_class)+"\"";
         out+=",\"truth_class\":\""+TruthClassToString(s.truth_class)+"\"";
         out+=",\"freshness_class\":\""+FreshnessClassToString(s.freshness_class)+"\"";
         out+=",\"acceptance_type\":\""+AcceptanceTypeToString(s.acceptance_type)+"\"";
         out+="}";
        }
      out+="]";

      out+="}";
      return out;
     }

   static string ToDebugJson(const ISSX_EA3_State &state)
     {
      string out="{";
      out+="\"stage\":\"ea3_debug\"";
      out+=",\"bucket_count\":"+IntegerToString(ArraySize(state.buckets));
      out+=",\"frontier_count\":"+IntegerToString(ArraySize(state.frontier));
      out+=",\"changed_symbol_count\":"+IntegerToString(state.delta.changed_symbol_count);
      out+=",\"changed_bucket_count\":"+IntegerToString(state.delta.changed_bucket_count);
      out+=",\"changed_frontier_count\":"+IntegerToString(state.delta.changed_frontier_count);
      out+=",\"duplicate_collapsed_count\":"+IntegerToString(state.counters.duplicate_collapsed_count);
      out+=",\"hysteresis_hold_count\":"+IntegerToString(state.counters.hysteresis_hold_count);
      out+=",\"hysteresis_weak_decay_count\":"+IntegerToString(state.counters.hysteresis_weak_decay_count);
      out+=",\"challenger_override_count\":"+IntegerToString(state.counters.challenger_override_count);
      out+=",\"survivor_turnover_count_recent\":"+IntegerToString(state.counters.survivor_turnover_count_recent);
      out+=",\"contradiction_count\":"+IntegerToString(state.counters.contradiction_count);
      out+=",\"blocking_contradiction_count\":"+IntegerToString(state.counters.blocking_contradiction_count);

      out+=",\"top_frontier\":[";
      bool first=true;
      int limit=MathMin(ArraySize(state.frontier),12);
      for(int i=0;i<limit;i++)
        {
         if(!first) out+=",";
         first=false;
         out+="{";
         out+="\"symbol_norm\":\""+ISSX_Util::EscapeJson(state.frontier[i].symbol_norm)+"\"";
         out+=",\"bucket_id\":\""+ISSX_Util::EscapeJson(state.frontier[i].bucket_id)+"\"";
         out+=",\"frontier_promotion_score\":"+DoubleToString(state.frontier[i].frontier_promotion_score,6);
         out+=",\"frontier_confidence\":"+DoubleToString(state.frontier[i].frontier_confidence,6);
         out+=",\"entry_reason_primary\":\""+ISSX_Util::EscapeJson(state.frontier[i].entry_reason_primary)+"\"";
         out+="}";
        }
      out+="]";

      out+="}";
      return out;
     }

  };

#endif // __ISSX_SELECTION_ENGINE_MQH__
