#ifndef __ISSX_CORRELATION_ENGINE_MQH__
#define __ISSX_CORRELATION_ENGINE_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>
#include <ISSX/issx_market_engine.mqh>
#include <ISSX/issx_selection_engine.mqh>

// ============================================================================
// ISSX CORRELATION ENGINE v1.7.2
// EA4 shared engine for IntelligenceCore.
//
// OWNERSHIP IN THIS MODULE
// - frontier-only overlap intelligence
// - structural overlap facts
// - bounded statistical overlap facts
// - typed penalty permissioning
// - diversification / redundancy context
// - pair evidence cache
// - changed-pair priority queue
// - pair cache TTL
// - local frontier clustering
// - abstention memory
//
// DESIGN PRINCIPLES
// - frontier only; never full universe
// - no penalty without fact + permission + confidence
// - unknown overlap must never masquerade as low overlap
// - honest abstention beats stale fake intelligence
// - pair outcome surface:
//   valid_low_overlap / valid_high_overlap / unknown_overlap /
//   provisional_overlap / blocked_overlap
// - pair cache reuse must obey freshness / member-shape invalidation
// - clusters are local context only, not portfolio optimization advice
//
// HARDENING NOTES
// - core-owned ISSX_JsonWriter only
// - deterministic frontier / pair fingerprints
// - explicit unknown / none defaults
// - stage API normalized to blueprint v1.7.2
// - same-tick handoff is never implied here; upstream accepted truth only
// ============================================================================

#define ISSX_CORRELATION_ENGINE_MODULE_VERSION "1.7.2"
#define ISSX_CORRELATION_ENGINE_STAGE_API_VERSION "1.0"
#define ISSX_EA4_PAIR_CACHE_MAX_AGE_MINUTES    30
#define ISSX_EA4_FRONTIER_HARD_LIMIT           64
#define ISSX_EA4_MIN_OVERLAP_BARS              24
#define ISSX_EA4_MIN_PAIR_VARIATION            0.000001
#define ISSX_EA4_MIN_INTEL_CONFIDENCE          0.15

// ============================================================================
// SECTION 01: PHASE IDS / LOCAL ENUMS
// ============================================================================

enum ISSX_EA4_PhaseId
  {
   issx_ea4_phase_load_frontier = 0,
   issx_ea4_phase_restore_pair_cache,
   issx_ea4_phase_select_pair_queue,
   issx_ea4_phase_compute_structural_overlap,
   issx_ea4_phase_compute_statistical_overlap,
   issx_ea4_phase_derive_cluster_context,
   issx_ea4_phase_apply_permissions,
   issx_ea4_phase_update_abstention_memory,
   issx_ea4_phase_publish
  };

enum ISSX_EA4_PairCacheStatus
  {
   issx_ea4_pair_cache_unavailable = 0,
   issx_ea4_pair_cache_fresh,
   issx_ea4_pair_cache_aging,
   issx_ea4_pair_cache_stale,
   issx_ea4_pair_cache_invalidated
  };

enum ISSX_EA4_IntelligenceNullReason
  {
   issx_ea4_null_none = 0,
   issx_ea4_null_no_frontier,
   issx_ea4_null_not_enough_overlap,
   issx_ea4_null_stale_history,
   issx_ea4_null_budget_skipped,
   issx_ea4_null_duplicate_preempted,
   issx_ea4_null_member_shape_changed
  };

// ============================================================================
// SECTION 02: DTO TYPES
// ============================================================================

struct ISSX_EA4_StructuralOverlapFacts
  {
   bool   same_family_flag;
   bool   same_quote_currency_flag;
   bool   same_session_family_flag;
   bool   same_theme_flag;
   bool   same_risk_complex_flag;
   string overlap_fact_flags;

   void Reset()
     {
      same_family_flag=false;
      same_quote_currency_flag=false;
      same_session_family_flag=false;
      same_theme_flag=false;
      same_risk_complex_flag=false;
      overlap_fact_flags="none";
     }
  };

struct ISSX_EA4_StatisticalOverlapFacts
  {
   double                nearest_peer_similarity;
   bool                  corr_valid;
   double                corr_quality_score;
   string                corr_window_class;
   double                corr_overlap_ratio;
   ISSX_CorrRejectReason corr_reject_reason;
   int                   pair_evidence_count;
   int                   pair_overlap_bars;
   double                pair_alignment_score;
   double                pair_variation_score;
   double                pair_penalty_confidence;

   void Reset()
     {
      nearest_peer_similarity=0.0;
      corr_valid=false;
      corr_quality_score=0.0;
      corr_window_class="unknown";
      corr_overlap_ratio=0.0;
      corr_reject_reason=issx_corr_reject_budget_skipped;
      pair_evidence_count=0;
      pair_overlap_bars=0;
      pair_alignment_score=0.0;
      pair_variation_score=0.0;
      pair_penalty_confidence=0.0;
     }
  };

struct ISSX_EA4_AdjustmentPolicy
  {
   bool                  duplicate_penalty_applied;
   bool                  corr_penalty_applied;
   bool                  session_overlap_penalty_applied;
   bool                  diversification_bonus_applied;
   double                adjustment_confidence;
   ISSX_PenaltyBasisKind penalty_basis_kind;
   double                structural_overlap_score;
   double                statistical_overlap_score;
   string                structural_overlap_reason;
   string                statistical_overlap_quality;

   void Reset()
     {
      duplicate_penalty_applied=false;
      corr_penalty_applied=false;
      session_overlap_penalty_applied=false;
      diversification_bonus_applied=false;
      adjustment_confidence=0.0;
      penalty_basis_kind=issx_penalty_mixed;
      structural_overlap_score=0.0;
      statistical_overlap_score=0.0;
      structural_overlap_reason="unknown";
      statistical_overlap_quality="unknown";
     }
  };

struct ISSX_EA4_AbstentionCoverage
  {
   bool   intelligence_abstained;
   string abstention_reason;
   string abstained_blocks;
   double intelligence_confidence;
   double intelligence_coverage_score;
   double peer_set_quality_score;
   string intelligence_null_reason;
   bool   intelligence_soft_missing;

   void Reset()
     {
      intelligence_abstained=true;
      abstention_reason="not_computed";
      abstained_blocks="none";
      intelligence_confidence=0.0;
      intelligence_coverage_score=0.0;
      peer_set_quality_score=0.0;
      intelligence_null_reason="not_computed";
      intelligence_soft_missing=true;
     }
  };

struct ISSX_EA4_RoleCluster
  {
   ISSX_PortfolioRoleHint portfolio_role_hint;
   double                 role_hint_confidence;
   int                    local_cluster_id;
   int                    local_cluster_size;
   double                 local_cluster_density;
   string                 cluster_members_sample;
   string                 diversification_basis;
   string                 diversification_contributors;
   string                 diversification_limiters;
   double                 cluster_redundancy_score;
   double                 cluster_dispersion_score;

   void Reset()
     {
      portfolio_role_hint=issx_role_anchor;
      role_hint_confidence=0.0;
      local_cluster_id=-1;
      local_cluster_size=1;
      local_cluster_density=0.0;
      cluster_members_sample="none";
      diversification_basis="unknown";
      diversification_contributors="none";
      diversification_limiters="none";
      cluster_redundancy_score=0.0;
      cluster_dispersion_score=0.0;
     }
  };

struct ISSX_EA4_PairCacheRecord
  {
   string                   symbol_a;
   string                   symbol_b;
   ISSX_EA4_PairCacheStatus pair_cache_status;
   int                      pair_cache_age;
   long                     pair_last_valid_minute_id;
   ISSX_CorrRejectReason    pair_last_reject_reason;
   long                     pair_retry_after_minute_id;
   int                      pair_reject_streak;
   ISSX_FreshnessClass      pair_evidence_freshness;
   bool                     pair_shape_changed_flag;
   bool                     pair_evidence_invalidated_by_member_change;
   string                   pair_cache_reuse_block_reason;
   double                   cached_similarity;
   double                   cached_corr_quality;
   int                      cached_overlap_bars;
   ISSX_PairValidityClass   pair_validity_class;
   string                   pair_sample_alignment_class;
   string                   pair_window_freshness_class;
   int                      sample_count;
   bool                     abstained_flag;
   string                   pair_regime_comparability_class;
   bool                     pair_ttl_expired_flag;
   int                      pair_cache_ttl_minutes;
   long                     pair_next_priority_due_minute_id;
   bool                     changed_pair_priority_flag;
   string                   pair_outcome_surface;
   string                   diversification_confidence_class;
   string                   redundancy_risk_class;

   void Reset()
     {
      symbol_a="";
      symbol_b="";
      pair_cache_status=issx_ea4_pair_cache_unavailable;
      pair_cache_age=0;
      pair_last_valid_minute_id=0;
      pair_last_reject_reason=issx_corr_reject_budget_skipped;
      pair_retry_after_minute_id=0;
      pair_reject_streak=0;
      pair_evidence_freshness=issx_freshness_stale;
      pair_shape_changed_flag=false;
      pair_evidence_invalidated_by_member_change=false;
      pair_cache_reuse_block_reason="none";
      cached_similarity=0.0;
      cached_corr_quality=0.0;
      cached_overlap_bars=0;
      pair_validity_class=issx_pair_validity_unknown_overlap;
      pair_sample_alignment_class="unknown";
      pair_window_freshness_class="unknown";
      sample_count=0;
      abstained_flag=true;
      pair_regime_comparability_class="unknown";
      pair_ttl_expired_flag=false;
      pair_cache_ttl_minutes=ISSX_EA4_PAIR_CACHE_MAX_AGE_MINUTES;
      pair_next_priority_due_minute_id=0;
      changed_pair_priority_flag=false;
      pair_outcome_surface="unknown_overlap";
      diversification_confidence_class="unknown";
      redundancy_risk_class="unknown";
     }
  };

struct ISSX_EA4_SymbolIntelligence
  {
   string                           symbol_raw;
   string                           symbol_norm;
   string                           alias_family_id;
   string                           leader_bucket_id;
   ISSX_LeaderBucketType            leader_bucket_type;
   ISSX_EA4_StructuralOverlapFacts  structural_facts;
   ISSX_EA4_StatisticalOverlapFacts statistical_facts;
   ISSX_EA4_AdjustmentPolicy        adjustment;
   ISSX_EA4_AbstentionCoverage      abstention;
   ISSX_EA4_RoleCluster             cluster;
   string                           pair_cache_status;
   int                              pair_cache_age;
   long                             pair_last_valid_minute_id;
   ISSX_CorrRejectReason            pair_last_reject_reason;
   long                             pair_retry_after_minute_id;
   int                              pair_reject_streak;
   ISSX_FreshnessClass              pair_evidence_freshness;
   bool                             pair_shape_changed_flag;
   bool                             pair_evidence_invalidated_by_member_change;
   string                           pair_cache_reuse_block_reason;
   ISSX_PairValidityClass           pair_validity_class;
   string                           pair_sample_alignment_class;
   string                           pair_window_freshness_class;
   int                              sample_count;
   bool                             abstained_flag;
   string                           pair_regime_comparability_class;
   string                           diversification_confidence_class;
   string                           redundancy_risk_class;
   string                           pair_outcome_surface;
   bool                             changed_this_cycle;
   bool                             contradiction_present;
   ISSX_ContradictionSeverity       contradiction_severity_max;
   string                           contradiction_flags;

   void Reset()
     {
      symbol_raw="";
      symbol_norm="";
      alias_family_id="";
      leader_bucket_id="other";
      leader_bucket_type=issx_leader_bucket_theme_bucket;
      structural_facts.Reset();
      statistical_facts.Reset();
      adjustment.Reset();
      abstention.Reset();
      cluster.Reset();
      pair_cache_status="unavailable";
      pair_cache_age=0;
      pair_last_valid_minute_id=0;
      pair_last_reject_reason=issx_corr_reject_budget_skipped;
      pair_retry_after_minute_id=0;
      pair_reject_streak=0;
      pair_evidence_freshness=issx_freshness_stale;
      pair_shape_changed_flag=false;
      pair_evidence_invalidated_by_member_change=false;
      pair_cache_reuse_block_reason="none";
      pair_validity_class=issx_pair_validity_unknown_overlap;
      pair_sample_alignment_class="unknown";
      pair_window_freshness_class="unknown";
      sample_count=0;
      abstained_flag=true;
      pair_regime_comparability_class="unknown";
      diversification_confidence_class="unknown";
      redundancy_risk_class="unknown";
      pair_outcome_surface="unknown_overlap";
      changed_this_cycle=false;
      contradiction_present=false;
      contradiction_severity_max=issx_contradiction_low;
      contradiction_flags="none";
     }
  };

struct ISSX_EA4_UniverseState
  {
   int    frontier_universe_count;
   int    publishable_universe_count;
   string broker_universe_fingerprint;
   string eligible_universe_fingerprint;
   string active_universe_fingerprint;
   string frontier_universe_fingerprint;
   string publishable_universe_fingerprint;
   string frontier_drift_class;
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
      frontier_universe_count=0;
      publishable_universe_count=0;
      broker_universe_fingerprint="";
      eligible_universe_fingerprint="";
      active_universe_fingerprint="";
      frontier_universe_fingerprint="";
      publishable_universe_fingerprint="";
      frontier_drift_class="unknown";
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

struct ISSX_EA4_DeltaState
  {
   int    changed_frontier_count;
   int    changed_symbol_count;
   string changed_symbol_ids;
   int    changed_family_count;

   void Reset()
     {
      changed_frontier_count=0;
      changed_symbol_count=0;
      changed_symbol_ids="";
      changed_family_count=0;
     }
  };

struct ISSX_EA4_CycleCounters
  {
   int pair_attempted;
   int pair_reused;
   int pair_computed;
   int pair_abstained;
   int pair_invalidated;
   int contradiction_count;
   int abstained_symbol_count;

   void Reset()
     {
      pair_attempted=0;
      pair_reused=0;
      pair_computed=0;
      pair_abstained=0;
      pair_invalidated=0;
      contradiction_count=0;
      abstained_symbol_count=0;
     }
  };

struct ISSX_EA4_State
  {
   ISSX_StageHeader            header;
   ISSX_Manifest               manifest;
   ISSX_RuntimeState           runtime;
   ISSX_EA4_UniverseState      universe;
   ISSX_EA4_DeltaState         delta;
   ISSX_EA4_CycleCounters      counters;
   string                      upstream_source_used;
   string                      upstream_source_reason;
   ISSX_CompatibilityClass     upstream_compatibility_class;
   double                      upstream_compatibility_score;
   int                         fallback_depth_used;
   double                      fallback_penalty_applied;
   bool                        projection_partial_success_flag;
   bool                        degraded_flag;
   bool                        recovery_publish_flag;
   bool                        stage_minimum_ready_flag;
   ISSX_PublishabilityState    stage_publishability_state;
   string                      dependency_block_reason;
   ISSX_DebugWeakLinkCode      debug_weak_link_code;
   string                      taxonomy_hash;
   string                      comparator_registry_hash;
   string                      cohort_fingerprint;
   string                      policy_fingerprint;
   string                      fingerprint_algorithm_version;
   ISSX_EA4_SymbolIntelligence symbols[];
   ISSX_EA4_PairCacheRecord    pair_cache[];

   void Reset()
     {
      ZeroMemory(header);
      ZeroMemory(manifest);
      runtime.Reset();
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
      fingerprint_algorithm_version="sha256_hex_v1";
      ArrayResize(symbols,0);
      ArrayResize(pair_cache,0);
     }
  };

struct ISSX_EA4_OptionalIntelligenceExport
  {
   string                 symbol_norm;
   bool                   present;
   double                 nearest_peer_similarity;
   bool                   corr_valid;
   double                 corr_quality_score;
   string                 corr_reject_reason;
   bool                   duplicate_penalty_applied;
   bool                   corr_penalty_applied;
   bool                   session_overlap_penalty_applied;
   bool                   diversification_bonus_applied;
   double                 adjustment_confidence;
   ISSX_PortfolioRoleHint portfolio_role_hint;
   double                 structural_overlap_score;
   double                 statistical_overlap_score;
   bool                   intelligence_abstained;
   string                 abstention_reason;
   double                 intelligence_confidence;
   double                 intelligence_coverage_score;
   string                 pair_cache_status;
   string                 pair_cache_reuse_block_reason;

   void Reset()
     {
      symbol_norm="";
      present=false;
      nearest_peer_similarity=0.0;
      corr_valid=false;
      corr_quality_score=0.0;
      corr_reject_reason="not_available";
      duplicate_penalty_applied=false;
      corr_penalty_applied=false;
      session_overlap_penalty_applied=false;
      diversification_bonus_applied=false;
      adjustment_confidence=0.0;
      portfolio_role_hint=issx_role_anchor;
      structural_overlap_score=0.0;
      statistical_overlap_score=0.0;
      intelligence_abstained=true;
      abstention_reason="ea4_not_attached";
      intelligence_confidence=0.0;
      intelligence_coverage_score=0.0;
      pair_cache_status="unavailable";
      pair_cache_reuse_block_reason="ea4_not_attached";
     }
  };

// ============================================================================
// SECTION 03: ENGINE
// ============================================================================

class ISSX_CorrelationEngine
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

   static double SafeDiv(const double a,const double b)
     {
      if(MathAbs(b)<=0.0000000001)
         return 0.0;
      return (a/b);
     }

   static ISSX_PhaseId MapLocalPhaseToRuntimePhase(const ISSX_EA4_PhaseId local_phase)
     {
      switch(local_phase)
        {
         case issx_ea4_phase_load_frontier:               return issx_phase_ea4_load_frontier;
         case issx_ea4_phase_restore_pair_cache:          return issx_phase_ea4_restore;
         case issx_ea4_phase_select_pair_queue:           return issx_phase_ea4_load_frontier;
         case issx_ea4_phase_compute_structural_overlap:  return issx_phase_ea4_load_frontier;
         case issx_ea4_phase_compute_statistical_overlap: return issx_phase_ea4_load_frontier;
         case issx_ea4_phase_derive_cluster_context:      return issx_phase_ea4_restore;
         case issx_ea4_phase_apply_permissions:           return issx_phase_ea4_restore;
         case issx_ea4_phase_update_abstention_memory:    return issx_phase_ea4_restore;
         case issx_ea4_phase_publish:                     return issx_phase_ea4_publish;
         default:                                         return issx_phase_ea4_load_frontier;
        }
     }

   static bool BeginStagePhase(ISSX_RuntimeState &runtime,
                               const ISSX_EA4_PhaseId local_phase,
                               const int budget_ms,
                               const string label)
     {
      return ISSX_PhaseScheduler::BeginPhase(runtime,MapLocalPhaseToRuntimePhase(local_phase),budget_ms,label);
     }

   static string CorrRejectReasonToString(const ISSX_CorrRejectReason v)
     {
      switch(v)
        {
         case issx_corr_reject_not_enough_overlap:  return "not_enough_overlap";
         case issx_corr_reject_stale_history:       return "stale_history";
         case issx_corr_reject_low_variation:       return "low_variation";
         case issx_corr_reject_alignment_fail:      return "alignment_fail";
         case issx_corr_reject_budget_skipped:      return "budget_skipped";
         case issx_corr_reject_duplicate_preempted: return "duplicate_preempted";
         default:                                   return "budget_skipped";
        }
     }

   static string PairCacheStatusToString(const ISSX_EA4_PairCacheStatus v)
     {
      switch(v)
        {
         case issx_ea4_pair_cache_unavailable: return "unavailable";
         case issx_ea4_pair_cache_fresh:       return "fresh";
         case issx_ea4_pair_cache_aging:       return "aging";
         case issx_ea4_pair_cache_stale:       return "stale";
         case issx_ea4_pair_cache_invalidated: return "invalidated";
         default:                              return "unavailable";
        }
     }

   static string PublishabilityStateToString(const ISSX_PublishabilityState v)
     {
      switch(v)
        {
         case issx_publishability_not_ready:       return "not_ready";
         case issx_publishability_warmup:          return "warmup";
         case issx_publishability_usable_degraded: return "usable_degraded";
         case issx_publishability_usable:          return "usable";
         case issx_publishability_strong:          return "strong";
         default:                                  return "not_ready";
        }
     }

   static string CompatibilityClassToString(const ISSX_CompatibilityClass v)
     {
      switch(v)
        {
         case issx_compatibility_exact:               return "exact";
         case issx_compatibility_compatible:          return "compatible";
         case issx_compatibility_compatible_degraded: return "compatible_degraded";
         case issx_compatibility_incompatible:        return "incompatible";
         default:                                     return "incompatible";
        }
     }

   static string WeakLinkCodeToString(const ISSX_DebugWeakLinkCode v)
     {
      switch(v)
        {
         case issx_weak_link_none:             return "none";
         case issx_weak_link_dependency_block: return "dependency_block";
         case issx_weak_link_queue_backlog:    return "queue_backlog";
         case issx_weak_link_publish_stale:    return "publish_stale";
         default:                              return "none";
        }
     }

   static string PairValidityToSurface(const ISSX_PairValidityClass v)
     {
      switch(v)
        {
         case issx_pair_validity_valid_low_overlap:   return "valid_low_overlap";
         case issx_pair_validity_valid_high_overlap:  return "valid_high_overlap";
         case issx_pair_validity_provisional_overlap: return "provisional_overlap";
         case issx_pair_validity_blocked_overlap:     return "blocked_overlap";
         case issx_pair_validity_unknown_overlap:
         default:                                     return "unknown_overlap";
        }
     }

   static string RoleHintToString(const ISSX_PortfolioRoleHint v)
     {
      switch(v)
        {
         case issx_role_anchor:              return "anchor";
         case issx_role_overlap_risk:        return "overlap_risk";
         case issx_role_diversifier:         return "diversifier";
         case issx_role_fragile_diversifier: return "fragile_diversifier";
         case issx_role_redundant:           return "redundant";
         default:                            return "anchor";
        }
     }

   static string PenaltyBasisToString(const ISSX_PenaltyBasisKind v)
     {
      switch(v)
        {
         case issx_penalty_family:  return "family";
         case issx_penalty_session: return "session";
         case issx_penalty_returns: return "returns";
         case issx_penalty_bucket:  return "bucket";
         case issx_penalty_mixed:
         default:                   return "mixed";
        }
     }

   static string FreshnessClassToString(const ISSX_FreshnessClass v)
     {
      switch(v)
        {
         case issx_freshness_fresh:  return "fresh";
         case issx_freshness_usable: return "usable";
         case issx_freshness_aging:  return "aging";
         case issx_freshness_stale:
         default:                    return "stale";
        }
     }

   static string ContradictionSeverityToString(const ISSX_ContradictionSeverity v)
     {
      switch(v)
        {
         case issx_contradiction_low:      return "low";
         case issx_contradiction_moderate: return "moderate";
         case issx_contradiction_high:     return "high";
         case issx_contradiction_blocking: return "blocking";
         default:                          return "low";
        }
     }

   static string IntelligenceNullReasonToString(const ISSX_EA4_IntelligenceNullReason v)
     {
      switch(v)
        {
         case issx_ea4_null_no_frontier:           return "no_frontier";
         case issx_ea4_null_not_enough_overlap:    return "not_enough_overlap";
         case issx_ea4_null_stale_history:         return "stale_history";
         case issx_ea4_null_budget_skipped:        return "budget_skipped";
         case issx_ea4_null_duplicate_preempted:   return "duplicate_preempted";
         case issx_ea4_null_member_shape_changed:  return "member_shape_changed";
         case issx_ea4_null_none:
         default:                                  return "none";
        }
     }

   static string DeterminePairWindowFreshnessClass(const int pair_cache_age_minutes,
                                                   const bool ttl_expired_flag)
     {
      if(ttl_expired_flag)
         return "stale";
      if(pair_cache_age_minutes<=5)
         return "fresh";
      if(pair_cache_age_minutes<=ISSX_EA4_PAIR_CACHE_MAX_AGE_MINUTES)
         return "usable";
      return "aging";
     }

   static string DetermineDiversificationConfidenceClass(const ISSX_PairValidityClass validity,
                                                         const double confidence)
     {
      if(validity==issx_pair_validity_blocked_overlap)
         return "blocked";
      if(validity==issx_pair_validity_unknown_overlap)
         return "unknown";
      if(validity==issx_pair_validity_provisional_overlap)
         return (confidence>=0.35 ? "provisional" : "fragile");
      if(confidence>=0.70)
         return "strong";
      if(confidence>=0.35)
         return "usable";
      return "fragile";
     }

   static string DetermineRedundancyRiskClass(const double structural_overlap_score,
                                              const double statistical_overlap_score,
                                              const ISSX_PairValidityClass validity)
     {
      if(validity==issx_pair_validity_unknown_overlap)
         return "unknown";
      if(validity==issx_pair_validity_blocked_overlap)
         return "blocked";
      const double combined=Clamp01((structural_overlap_score*0.55)+(statistical_overlap_score*0.45));
      if(combined>=0.80)
         return "high";
      if(combined>=0.45)
         return "moderate";
      return "low";
     }

   static ISSX_PortfolioRoleHint DetermineRoleHint(const string redundancy_risk_class,
                                                   const string diversification_confidence_class)
     {
      if(redundancy_risk_class=="high")
         return issx_role_redundant;
      if(redundancy_risk_class=="moderate")
         return issx_role_overlap_risk;
      if(diversification_confidence_class=="strong")
         return issx_role_diversifier;
      if(diversification_confidence_class=="usable")
         return issx_role_fragile_diversifier;
      return issx_role_anchor;
     }

   static string DetermineDependencyBlockReason(const int frontier_count,
                                                const int abstained_symbol_count)
     {
      if(frontier_count<=0)
         return "frontier_empty";
      if(frontier_count==1)
         return "frontier_too_thin_for_pairs";
      if(abstained_symbol_count>=frontier_count)
         return "pair_evidence_provisional";
      return "none";
     }

   static int FindEA3SymbolByNorm(const ISSX_EA3_State &ea3,const string symbol_norm)
     {
      const int n=ArraySize(ea3.symbols);
      for(int i=0;i<n;i++)
        {
         if(ea3.symbols[i].symbol_norm==symbol_norm)
            return i;
        }
      return -1;
     }

   static int CountDistinctFrontierFamilies(const ISSX_EA4_State &state)
     {
      string seen[];
      ArrayResize(seen,0);

      const int n=ArraySize(state.symbols);
      for(int i=0;i<n;i++)
        {
         string fam=state.symbols[i].alias_family_id;
         if(fam=="")
            fam=state.symbols[i].symbol_norm;

         bool exists=false;
         for(int k=0;k<ArraySize(seen);k++)
           {
            if(seen[k]==fam)
              {
               exists=true;
               break;
              }
           }

         if(!exists)
           {
            const int m=ArraySize(seen);
            if(ArrayResize(seen,m+1)==(m+1))
               seen[m]=fam;
           }
        }

      return ArraySize(seen);
     }

   static string BuildStableFingerprint(const string &items[])
     {
      string local[];
      const int n=ArraySize(items);
      ArrayResize(local,n);
      for(int i=0;i<n;i++)
         local[i]=items[i];
      ArraySort(local);

      string packed="";
      for(int i=0;i<n;i++)
        {
         if(i>0)
            packed+="|";
         packed+=local[i];
        }
      return ISSX_Hash::HashStringHex(packed);
     }

   static string BuildPolicyFingerprint()
     {
      const string seed=
         "issx_ea4_policy|" +
         string(ISSX_CORRELATION_ENGINE_MODULE_VERSION) + "|" +
         "frontier_only|" +
         "unknown_not_low|" +
         "provisional_over_fake|" +
         "ttl_" + IntegerToString(ISSX_EA4_PAIR_CACHE_MAX_AGE_MINUTES) + "|" +
         "min_overlap_" + IntegerToString(ISSX_EA4_MIN_OVERLAP_BARS);
      return ISSX_Hash::HashStringHex(seed);
     }

   static int FindCache(const ISSX_EA4_State &state,const string a,const string b)
     {
      string x=a;
      string y=b;
      if(StringCompare(x,y)>0)
        {
         string t=x;
         x=y;
         y=t;
        }

      for(int i=0;i<ArraySize(state.pair_cache);i++)
         if(state.pair_cache[i].symbol_a==x && state.pair_cache[i].symbol_b==y)
            return i;

      return -1;
     }

   static int EnsureCache(ISSX_EA4_State &state,const string a,const string b)
     {
      string x=a;
      string y=b;
      if(StringCompare(x,y)>0)
        {
         string t=x;
         x=y;
         y=t;
        }

      int idx=FindCache(state,x,y);
      if(idx>=0)
         return idx;

      idx=ArraySize(state.pair_cache);
      if(ArrayResize(state.pair_cache,idx+1)!=(idx+1))
         return -1;

      state.pair_cache[idx].Reset();
      state.pair_cache[idx].symbol_a=x;
      state.pair_cache[idx].symbol_b=y;
      return idx;
     }

   static void AppendChangedSymbol(ISSX_EA4_State &state,const string symbol_norm)
     {
      if(symbol_norm=="")
         return;

      if(state.delta.changed_symbol_ids=="")
         state.delta.changed_symbol_ids=symbol_norm;
      else
         state.delta.changed_symbol_ids+="|"+symbol_norm;

      state.delta.changed_symbol_count++;
     }

   static double StructuralOverlapScore(const ISSX_EA4_StructuralOverlapFacts &f)
     {
      double score=0.0;
      if(f.same_family_flag)
         score+=0.40;
      if(f.same_quote_currency_flag)
         score+=0.15;
      if(f.same_session_family_flag)
         score+=0.15;
      if(f.same_theme_flag)
         score+=0.15;
      if(f.same_risk_complex_flag)
         score+=0.15;
      return Clamp01(score);
     }

   static void RefreshDerivedUniverseCoverage(ISSX_EA4_State &state,const int frontier_count)
     {
      state.universe.percent_universe_touched_recent=(frontier_count>0 ? 100.0 : 0.0);
      state.universe.percent_rankable_revalidated_recent=(frontier_count>0 ? 100.0 : 0.0);
      state.universe.percent_frontier_revalidated_recent=(frontier_count>0 ? 100.0 : 0.0);
      state.universe.never_serviced_count=0;
      state.universe.overdue_service_count=0;
      state.universe.never_ranked_but_eligible_count=0;
      state.universe.newly_active_symbols_waiting_count=MathMax(0,state.delta.changed_frontier_count-frontier_count);
      state.universe.near_cutline_recheck_age_max=0;
     }

   static void SetUnknownIntelligence(ISSX_EA4_SymbolIntelligence &item,
                                      const ISSX_EA4_IntelligenceNullReason null_reason,
                                      const bool no_frontier)
     {
      item.structural_facts.Reset();
      item.statistical_facts.Reset();
      item.adjustment.Reset();
      item.cluster.Reset();
      item.abstention.Reset();

      item.abstention.intelligence_abstained=true;
      item.abstention.abstention_reason=IntelligenceNullReasonToString(null_reason);
      item.abstention.abstained_blocks=(no_frontier ? "frontier|pair_overlap|cluster" : "pair_overlap|cluster");
      item.abstention.intelligence_null_reason=IntelligenceNullReasonToString(null_reason);
      item.abstention.intelligence_soft_missing=true;
      item.abstention.peer_set_quality_score=0.0;
      item.abstention.intelligence_confidence=0.0;
      item.abstention.intelligence_coverage_score=0.0;

      item.pair_cache_status="unavailable";
      item.pair_cache_age=0;
      item.pair_last_valid_minute_id=0;
      item.pair_last_reject_reason=(null_reason==issx_ea4_null_budget_skipped ? issx_corr_reject_budget_skipped : issx_corr_reject_not_enough_overlap);
      item.pair_retry_after_minute_id=0;
      item.pair_reject_streak=0;
      item.pair_evidence_freshness=issx_freshness_stale;
      item.pair_shape_changed_flag=false;
      item.pair_evidence_invalidated_by_member_change=false;
      item.pair_cache_reuse_block_reason=(no_frontier ? "frontier_empty" : "insufficient_frontier_overlap");
      item.pair_validity_class=issx_pair_validity_unknown_overlap;
      item.pair_sample_alignment_class="unknown";
      item.pair_window_freshness_class="unknown";
      item.sample_count=0;
      item.abstained_flag=true;
      item.pair_regime_comparability_class="unknown";
      item.diversification_confidence_class="unknown";
      item.redundancy_risk_class="unknown";
      item.pair_outcome_surface="unknown_overlap";

      item.adjustment.structural_overlap_score=0.0;
      item.adjustment.statistical_overlap_score=0.0;
      item.adjustment.adjustment_confidence=0.0;
      item.adjustment.penalty_basis_kind=issx_penalty_mixed;
      item.adjustment.structural_overlap_reason="unknown";
      item.adjustment.statistical_overlap_quality="unknown";

      item.cluster.portfolio_role_hint=issx_role_anchor;
      item.cluster.role_hint_confidence=0.0;
      item.cluster.local_cluster_id=-1;
      item.cluster.local_cluster_size=1;
      item.cluster.local_cluster_density=0.0;
      item.cluster.cluster_redundancy_score=0.0;
      item.cluster.cluster_dispersion_score=0.0;

      item.contradiction_present=false;
      item.contradiction_severity_max=issx_contradiction_low;
      item.contradiction_flags="none";
     }

   static void SetBestEffortPair(ISSX_EA4_State &state,
                                 const int symbol_index,
                                 const int peer_index,
                                 const long minute_id)
     {
      state.symbols[symbol_index].structural_facts.Reset();
      state.symbols[symbol_index].statistical_facts.Reset();
      state.symbols[symbol_index].adjustment.Reset();
      state.symbols[symbol_index].abstention.Reset();
      state.symbols[symbol_index].cluster.Reset();

      state.symbols[symbol_index].structural_facts.same_family_flag=
         (state.symbols[symbol_index].alias_family_id!="" &&
          state.symbols[symbol_index].alias_family_id==state.symbols[peer_index].alias_family_id);
      state.symbols[symbol_index].structural_facts.same_quote_currency_flag=false;
      state.symbols[symbol_index].structural_facts.same_session_family_flag=false;
      state.symbols[symbol_index].structural_facts.same_theme_flag=
         (state.symbols[symbol_index].leader_bucket_id!="" &&
          state.symbols[symbol_index].leader_bucket_id==state.symbols[peer_index].leader_bucket_id);
      state.symbols[symbol_index].structural_facts.same_risk_complex_flag=false;
      state.symbols[symbol_index].structural_facts.overlap_fact_flags="frontier_pair";

      state.symbols[symbol_index].statistical_facts.nearest_peer_similarity=0.50;
      state.symbols[symbol_index].statistical_facts.corr_valid=false;
      state.symbols[symbol_index].statistical_facts.corr_quality_score=0.25;
      state.symbols[symbol_index].statistical_facts.corr_window_class="bounded";
      state.symbols[symbol_index].statistical_facts.corr_overlap_ratio=Clamp01(SafeDiv((double)(ArraySize(state.symbols)-1),10.0));
      state.symbols[symbol_index].statistical_facts.corr_reject_reason=issx_corr_reject_not_enough_overlap;
      state.symbols[symbol_index].statistical_facts.pair_evidence_count=1;
      state.symbols[symbol_index].statistical_facts.pair_overlap_bars=0;
      state.symbols[symbol_index].statistical_facts.pair_alignment_score=0.0;
      state.symbols[symbol_index].statistical_facts.pair_variation_score=0.0;
      state.symbols[symbol_index].statistical_facts.pair_penalty_confidence=0.10;

      state.symbols[symbol_index].adjustment.duplicate_penalty_applied=false;
      state.symbols[symbol_index].adjustment.corr_penalty_applied=false;
      state.symbols[symbol_index].adjustment.session_overlap_penalty_applied=false;
      state.symbols[symbol_index].adjustment.diversification_bonus_applied=false;
      state.symbols[symbol_index].adjustment.adjustment_confidence=0.10;
      state.symbols[symbol_index].adjustment.penalty_basis_kind=issx_penalty_mixed;
      state.symbols[symbol_index].adjustment.structural_overlap_score=StructuralOverlapScore(state.symbols[symbol_index].structural_facts);
      state.symbols[symbol_index].adjustment.statistical_overlap_score=0.0;
      state.symbols[symbol_index].adjustment.structural_overlap_reason=state.symbols[symbol_index].structural_facts.overlap_fact_flags;
      state.symbols[symbol_index].adjustment.statistical_overlap_quality="unknown_overlap";

      state.symbols[symbol_index].abstention.intelligence_abstained=true;
      state.symbols[symbol_index].abstention.abstention_reason="unknown_overlap";
      state.symbols[symbol_index].abstention.abstained_blocks="statistical_overlap";
      state.symbols[symbol_index].abstention.intelligence_confidence=0.10;
      state.symbols[symbol_index].abstention.intelligence_coverage_score=Clamp01(SafeDiv((double)(ArraySize(state.symbols)-1),6.0));
      state.symbols[symbol_index].abstention.peer_set_quality_score=state.symbols[symbol_index].abstention.intelligence_coverage_score;
      state.symbols[symbol_index].abstention.intelligence_null_reason="not_enough_overlap";
      state.symbols[symbol_index].abstention.intelligence_soft_missing=true;

      state.symbols[symbol_index].cluster.local_cluster_id=symbol_index;
      state.symbols[symbol_index].cluster.local_cluster_size=2;
      state.symbols[symbol_index].cluster.local_cluster_density=0.10;
      state.symbols[symbol_index].cluster.cluster_members_sample=state.symbols[peer_index].symbol_norm;
      state.symbols[symbol_index].cluster.diversification_basis="provisional_pair";
      state.symbols[symbol_index].cluster.diversification_contributors="none";
      state.symbols[symbol_index].cluster.diversification_limiters="insufficient_pair_evidence";
      state.symbols[symbol_index].cluster.cluster_redundancy_score=0.10;
      state.symbols[symbol_index].cluster.cluster_dispersion_score=0.90;

      const ISSX_PairValidityClass validity=issx_pair_validity_provisional_overlap;
      const string diversification_confidence_class=DetermineDiversificationConfidenceClass(validity,state.symbols[symbol_index].abstention.intelligence_confidence);
      const string redundancy_risk_class=DetermineRedundancyRiskClass(state.symbols[symbol_index].adjustment.structural_overlap_score,
                                                                      state.symbols[symbol_index].adjustment.statistical_overlap_score,
                                                                      validity);

      state.symbols[symbol_index].cluster.portfolio_role_hint=DetermineRoleHint(redundancy_risk_class,diversification_confidence_class);
      state.symbols[symbol_index].cluster.role_hint_confidence=0.10;

      int cache_idx=EnsureCache(state,state.symbols[symbol_index].symbol_norm,state.symbols[peer_index].symbol_norm);
      if(cache_idx>=0)
        {
         state.pair_cache[cache_idx].pair_cache_status=issx_ea4_pair_cache_aging;
         state.pair_cache[cache_idx].pair_cache_age=0;
         state.pair_cache[cache_idx].pair_last_valid_minute_id=minute_id;
         state.pair_cache[cache_idx].pair_last_reject_reason=issx_corr_reject_not_enough_overlap;
         state.pair_cache[cache_idx].pair_retry_after_minute_id=minute_id+10;
         state.pair_cache[cache_idx].pair_reject_streak=1;
         state.pair_cache[cache_idx].pair_evidence_freshness=issx_freshness_usable;
         state.pair_cache[cache_idx].pair_shape_changed_flag=false;
         state.pair_cache[cache_idx].pair_evidence_invalidated_by_member_change=false;
         state.pair_cache[cache_idx].pair_cache_reuse_block_reason="fresh_pair_provisional";
         state.pair_cache[cache_idx].cached_similarity=state.symbols[symbol_index].statistical_facts.nearest_peer_similarity;
         state.pair_cache[cache_idx].cached_corr_quality=state.symbols[symbol_index].statistical_facts.corr_quality_score;
         state.pair_cache[cache_idx].cached_overlap_bars=0;
         state.pair_cache[cache_idx].pair_validity_class=validity;
         state.pair_cache[cache_idx].pair_sample_alignment_class="insufficient";
         state.pair_cache[cache_idx].pair_window_freshness_class=DeterminePairWindowFreshnessClass(state.pair_cache[cache_idx].pair_cache_age,false);
         state.pair_cache[cache_idx].sample_count=0;
         state.pair_cache[cache_idx].abstained_flag=true;
         state.pair_cache[cache_idx].pair_regime_comparability_class="unknown";
         state.pair_cache[cache_idx].pair_ttl_expired_flag=false;
         state.pair_cache[cache_idx].pair_cache_ttl_minutes=ISSX_EA4_PAIR_CACHE_MAX_AGE_MINUTES;
         state.pair_cache[cache_idx].pair_next_priority_due_minute_id=minute_id+10;
         state.pair_cache[cache_idx].changed_pair_priority_flag=true;
         state.pair_cache[cache_idx].pair_outcome_surface=PairValidityToSurface(validity);
         state.pair_cache[cache_idx].diversification_confidence_class=diversification_confidence_class;
         state.pair_cache[cache_idx].redundancy_risk_class=redundancy_risk_class;

         state.symbols[symbol_index].pair_cache_status=PairCacheStatusToString(state.pair_cache[cache_idx].pair_cache_status);
         state.symbols[symbol_index].pair_cache_age=state.pair_cache[cache_idx].pair_cache_age;
         state.symbols[symbol_index].pair_last_valid_minute_id=state.pair_cache[cache_idx].pair_last_valid_minute_id;
         state.symbols[symbol_index].pair_last_reject_reason=state.pair_cache[cache_idx].pair_last_reject_reason;
         state.symbols[symbol_index].pair_retry_after_minute_id=state.pair_cache[cache_idx].pair_retry_after_minute_id;
         state.symbols[symbol_index].pair_reject_streak=state.pair_cache[cache_idx].pair_reject_streak;
         state.symbols[symbol_index].pair_evidence_freshness=state.pair_cache[cache_idx].pair_evidence_freshness;
         state.symbols[symbol_index].pair_shape_changed_flag=state.pair_cache[cache_idx].pair_shape_changed_flag;
         state.symbols[symbol_index].pair_evidence_invalidated_by_member_change=state.pair_cache[cache_idx].pair_evidence_invalidated_by_member_change;
         state.symbols[symbol_index].pair_cache_reuse_block_reason=state.pair_cache[cache_idx].pair_cache_reuse_block_reason;
         state.symbols[symbol_index].pair_validity_class=state.pair_cache[cache_idx].pair_validity_class;
         state.symbols[symbol_index].pair_sample_alignment_class=state.pair_cache[cache_idx].pair_sample_alignment_class;
         state.symbols[symbol_index].pair_window_freshness_class=state.pair_cache[cache_idx].pair_window_freshness_class;
         state.symbols[symbol_index].sample_count=state.pair_cache[cache_idx].sample_count;
         state.symbols[symbol_index].abstained_flag=state.pair_cache[cache_idx].abstained_flag;
         state.symbols[symbol_index].pair_regime_comparability_class=state.pair_cache[cache_idx].pair_regime_comparability_class;
         state.symbols[symbol_index].diversification_confidence_class=state.pair_cache[cache_idx].diversification_confidence_class;
         state.symbols[symbol_index].redundancy_risk_class=state.pair_cache[cache_idx].redundancy_risk_class;
         state.symbols[symbol_index].pair_outcome_surface=state.pair_cache[cache_idx].pair_outcome_surface;
        }
      else
        {
         state.symbols[symbol_index].pair_cache_status="unavailable";
         state.symbols[symbol_index].pair_cache_reuse_block_reason="cache_unavailable";
         state.symbols[symbol_index].pair_validity_class=validity;
         state.symbols[symbol_index].pair_sample_alignment_class="insufficient";
         state.symbols[symbol_index].pair_window_freshness_class="fresh";
         state.symbols[symbol_index].sample_count=0;
         state.symbols[symbol_index].abstained_flag=true;
         state.symbols[symbol_index].pair_regime_comparability_class="unknown";
         state.symbols[symbol_index].diversification_confidence_class=diversification_confidence_class;
         state.symbols[symbol_index].redundancy_risk_class=redundancy_risk_class;
         state.symbols[symbol_index].pair_outcome_surface=PairValidityToSurface(validity);
        }
     }

   static void RefreshManifest(ISSX_EA4_State &state,const string firm_id)
     {
      const long minute_id=ISSX_Time::NowMinuteId();

      state.header.stage_id=issx_stage_ea4;
      state.header.firm_id=firm_id;
      state.header.schema_version=ISSX_SCHEMA_VERSION;
      state.header.schema_epoch=ISSX_SCHEMA_EPOCH;
      state.header.sequence_no=minute_id;
      state.header.minute_id=minute_id;
      state.header.writer_boot_id="ea4_correlation_core";
      state.header.writer_nonce=IntegerToString((int)minute_id);
      state.header.writer_generation=minute_id;
      state.header.symbol_count=ArraySize(state.symbols);
      state.header.changed_symbol_count=state.delta.changed_symbol_count;
      state.header.cohort_fingerprint=state.cohort_fingerprint;
      state.header.universe_fingerprint=state.universe.frontier_universe_fingerprint;
      state.header.contradiction_count=state.counters.contradiction_count;
      state.header.contradiction_severity_max=(state.counters.contradiction_count>0 ? issx_contradiction_blocking : issx_contradiction_low);
      state.header.degraded_flag=state.degraded_flag;
      state.header.fallback_depth_used=state.fallback_depth_used;

      state.manifest.stage_id=issx_stage_ea4;
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
      state.manifest.content_class=(state.degraded_flag ? issx_content_partial : issx_content_usable);
      state.manifest.publish_reason=issx_publish_scheduled;
      state.manifest.cohort_fingerprint=state.cohort_fingerprint;
      state.manifest.taxonomy_hash=state.taxonomy_hash;
      state.manifest.comparator_registry_hash=state.comparator_registry_hash;
      state.manifest.universe_fingerprint=state.universe.frontier_universe_fingerprint;
      state.manifest.compatibility_class=state.upstream_compatibility_class;
      state.manifest.contradiction_count=state.counters.contradiction_count;
      state.manifest.contradiction_severity_max=(state.counters.contradiction_count>0 ? issx_contradiction_blocking : issx_contradiction_low);
      state.manifest.degraded_flag=state.degraded_flag;
      state.manifest.fallback_depth_used=state.fallback_depth_used;
      state.manifest.accepted_strong_count=(ArraySize(state.symbols)-state.counters.abstained_symbol_count);
      state.manifest.accepted_degraded_count=state.counters.abstained_symbol_count;
      state.manifest.rejected_count=0;
      state.manifest.cooldown_count=0;
      state.manifest.stale_usable_count=state.counters.abstained_symbol_count;
      state.manifest.projection_partial_success_flag=state.projection_partial_success_flag;
      state.manifest.accepted_promotion_verified=false;
      state.manifest.stage_minimum_ready_flag=state.stage_minimum_ready_flag;
      state.manifest.stage_publishability_state=state.stage_publishability_state;
      state.manifest.handoff_mode=issx_handoff_loaded_internal_current;
      state.manifest.handoff_sequence_no=state.header.sequence_no;
      state.manifest.fallback_read_ratio_1h=0.0;
      state.manifest.fresh_accept_ratio_1h=0.0;
      state.manifest.same_tick_handoff_ratio_1h=0.0;
      state.manifest.legend_hash="";
     }

   static void WriteTopLevelJson(ISSX_JsonWriter &j,const ISSX_EA4_State &state)
     {
      j.NameString("stage","ea4");
      j.NameString("schema_version",ISSX_SCHEMA_VERSION);
      j.NameInt("schema_epoch",ISSX_SCHEMA_EPOCH);
      j.NameInt("minute_id",(long)state.manifest.minute_id);
      j.NameInt("sequence_no",(long)state.manifest.sequence_no);
      j.NameString("producer","issx_correlation_engine");
      j.NameString("module_version",ISSX_CORRELATION_ENGINE_MODULE_VERSION);
      j.NameString("stage_api_version",ISSX_CORRELATION_ENGINE_STAGE_API_VERSION);
      j.NameString("upstream_source_used",state.upstream_source_used);
      j.NameString("upstream_source_reason",state.upstream_source_reason);
      j.NameString("upstream_compatibility_class",CompatibilityClassToString(state.upstream_compatibility_class));
      j.NameDouble("upstream_compatibility_score",state.upstream_compatibility_score,4);
      j.NameInt("fallback_depth_used",state.fallback_depth_used);
      j.NameDouble("fallback_penalty_applied",state.fallback_penalty_applied,4);
      j.NameBool("degraded_flag",state.degraded_flag);
      j.NameBool("recovery_publish_flag",state.recovery_publish_flag);
      j.NameBool("projection_partial_success_flag",state.projection_partial_success_flag);
      j.NameBool("stage_minimum_ready_flag",state.stage_minimum_ready_flag);
      j.NameString("stage_publishability_state",PublishabilityStateToString(state.stage_publishability_state));
      j.NameString("dependency_block_reason",state.dependency_block_reason);
      j.NameString("debug_weak_link_code",WeakLinkCodeToString(state.debug_weak_link_code));
      j.NameString("policy_fingerprint",state.policy_fingerprint);
      j.NameString("fingerprint_algorithm_version",state.fingerprint_algorithm_version);
      j.NameString("taxonomy_hash",state.taxonomy_hash);
      j.NameString("comparator_registry_hash",state.comparator_registry_hash);
      j.NameString("cohort_fingerprint",state.cohort_fingerprint);
      j.NameString("why_intelligence_abstained",state.dependency_block_reason);
      j.NameInt("pair_cache_count",ArraySize(state.pair_cache));
      j.NameInt("frontier_pair_capacity",ArraySize(state.symbols));
     }

   static void WriteUniverseJson(ISSX_JsonWriter &j,const ISSX_EA4_UniverseState &u)
     {
      j.NameInt("frontier_universe_count",u.frontier_universe_count);
      j.NameInt("publishable_universe_count",u.publishable_universe_count);
      j.NameString("broker_universe_fingerprint",u.broker_universe_fingerprint);
      j.NameString("eligible_universe_fingerprint",u.eligible_universe_fingerprint);
      j.NameString("active_universe_fingerprint",u.active_universe_fingerprint);
      j.NameString("frontier_universe_fingerprint",u.frontier_universe_fingerprint);
      j.NameString("publishable_universe_fingerprint",u.publishable_universe_fingerprint);
      j.NameString("frontier_drift_class",u.frontier_drift_class);
      j.NameDouble("percent_universe_touched_recent",u.percent_universe_touched_recent,2);
      j.NameDouble("percent_rankable_revalidated_recent",u.percent_rankable_revalidated_recent,2);
      j.NameDouble("percent_frontier_revalidated_recent",u.percent_frontier_revalidated_recent,2);
      j.NameInt("never_serviced_count",u.never_serviced_count);
      j.NameInt("overdue_service_count",u.overdue_service_count);
      j.NameInt("never_ranked_but_eligible_count",u.never_ranked_but_eligible_count);
      j.NameInt("newly_active_symbols_waiting_count",u.newly_active_symbols_waiting_count);
      j.NameInt("near_cutline_recheck_age_max",u.near_cutline_recheck_age_max);
     }

   static void WriteDeltaJson(ISSX_JsonWriter &j,const ISSX_EA4_DeltaState &d)
     {
      j.NameInt("changed_frontier_count",d.changed_frontier_count);
      j.NameInt("changed_symbol_count",d.changed_symbol_count);
      j.NameString("changed_symbol_ids",d.changed_symbol_ids);
      j.NameInt("changed_family_count",d.changed_family_count);
     }

   static void WriteCountersJson(ISSX_JsonWriter &j,const ISSX_EA4_CycleCounters &c)
     {
      j.NameInt("pair_attempted",c.pair_attempted);
      j.NameInt("pair_reused",c.pair_reused);
      j.NameInt("pair_computed",c.pair_computed);
      j.NameInt("pair_abstained",c.pair_abstained);
      j.NameInt("pair_invalidated",c.pair_invalidated);
      j.NameInt("contradiction_count",c.contradiction_count);
      j.NameInt("abstained_symbol_count",c.abstained_symbol_count);
     }

   static void WriteSymbolJson(ISSX_JsonWriter &j,const ISSX_EA4_SymbolIntelligence &s)
     {
      j.NameString("symbol_raw",s.symbol_raw);
      j.NameString("symbol_norm",s.symbol_norm);
      j.NameString("alias_family_id",s.alias_family_id);
      j.NameString("leader_bucket_id",s.leader_bucket_id);
      j.NameInt("leader_bucket_type",(int)s.leader_bucket_type);

      j.NameBool("same_family_flag",s.structural_facts.same_family_flag);
      j.NameBool("same_quote_currency_flag",s.structural_facts.same_quote_currency_flag);
      j.NameBool("same_session_family_flag",s.structural_facts.same_session_family_flag);
      j.NameBool("same_theme_flag",s.structural_facts.same_theme_flag);
      j.NameBool("same_risk_complex_flag",s.structural_facts.same_risk_complex_flag);
      j.NameString("overlap_fact_flags",s.structural_facts.overlap_fact_flags);

      j.NameDouble("nearest_peer_similarity",s.statistical_facts.nearest_peer_similarity,6);
      j.NameBool("corr_valid",s.statistical_facts.corr_valid);
      j.NameDouble("corr_quality_score",s.statistical_facts.corr_quality_score,6);
      j.NameString("corr_window_class",s.statistical_facts.corr_window_class);
      j.NameDouble("corr_overlap_ratio",s.statistical_facts.corr_overlap_ratio,6);
      j.NameString("corr_reject_reason",CorrRejectReasonToString(s.statistical_facts.corr_reject_reason));
      j.NameInt("pair_evidence_count",s.statistical_facts.pair_evidence_count);
      j.NameInt("pair_overlap_bars",s.statistical_facts.pair_overlap_bars);
      j.NameDouble("pair_alignment_score",s.statistical_facts.pair_alignment_score,6);
      j.NameDouble("pair_variation_score",s.statistical_facts.pair_variation_score,6);
      j.NameDouble("pair_penalty_confidence",s.statistical_facts.pair_penalty_confidence,6);

      j.NameBool("duplicate_penalty_applied",s.adjustment.duplicate_penalty_applied);
      j.NameBool("corr_penalty_applied",s.adjustment.corr_penalty_applied);
      j.NameBool("session_overlap_penalty_applied",s.adjustment.session_overlap_penalty_applied);
      j.NameBool("diversification_bonus_applied",s.adjustment.diversification_bonus_applied);
      j.NameDouble("adjustment_confidence",s.adjustment.adjustment_confidence,6);
      j.NameString("penalty_basis_kind",PenaltyBasisToString(s.adjustment.penalty_basis_kind));
      j.NameDouble("structural_overlap_score",s.adjustment.structural_overlap_score,6);
      j.NameDouble("statistical_overlap_score",s.adjustment.statistical_overlap_score,6);
      j.NameString("structural_overlap_reason",s.adjustment.structural_overlap_reason);
      j.NameString("statistical_overlap_quality",s.adjustment.statistical_overlap_quality);

      j.NameBool("intelligence_abstained",s.abstention.intelligence_abstained);
      j.NameString("abstention_reason",s.abstention.abstention_reason);
      j.NameString("abstained_blocks",s.abstention.abstained_blocks);
      j.NameDouble("intelligence_confidence",s.abstention.intelligence_confidence,6);
      j.NameDouble("intelligence_coverage_score",s.abstention.intelligence_coverage_score,6);
      j.NameDouble("peer_set_quality_score",s.abstention.peer_set_quality_score,6);
      j.NameString("intelligence_null_reason",s.abstention.intelligence_null_reason);
      j.NameBool("intelligence_soft_missing",s.abstention.intelligence_soft_missing);

      j.NameString("portfolio_role_hint",RoleHintToString(s.cluster.portfolio_role_hint));
      j.NameDouble("role_hint_confidence",s.cluster.role_hint_confidence,6);
      j.NameInt("local_cluster_id",s.cluster.local_cluster_id);
      j.NameInt("local_cluster_size",s.cluster.local_cluster_size);
      j.NameDouble("local_cluster_density",s.cluster.local_cluster_density,6);
      j.NameString("cluster_members_sample",s.cluster.cluster_members_sample);
      j.NameString("diversification_basis",s.cluster.diversification_basis);
      j.NameString("diversification_contributors",s.cluster.diversification_contributors);
      j.NameString("diversification_limiters",s.cluster.diversification_limiters);
      j.NameDouble("cluster_redundancy_score",s.cluster.cluster_redundancy_score,6);
      j.NameDouble("cluster_dispersion_score",s.cluster.cluster_dispersion_score,6);

      j.NameString("pair_cache_status",s.pair_cache_status);
      j.NameInt("pair_cache_age",s.pair_cache_age);
      j.NameInt("pair_last_valid_minute_id",s.pair_last_valid_minute_id);
      j.NameString("pair_last_reject_reason",CorrRejectReasonToString(s.pair_last_reject_reason));
      j.NameInt("pair_retry_after_minute_id",s.pair_retry_after_minute_id);
      j.NameInt("pair_reject_streak",s.pair_reject_streak);
      j.NameString("pair_evidence_freshness",FreshnessClassToString(s.pair_evidence_freshness));
      j.NameBool("pair_shape_changed_flag",s.pair_shape_changed_flag);
      j.NameBool("pair_evidence_invalidated_by_member_change",s.pair_evidence_invalidated_by_member_change);
      j.NameString("pair_cache_reuse_block_reason",s.pair_cache_reuse_block_reason);
      j.NameString("pair_validity_class",PairValidityToSurface(s.pair_validity_class));
      j.NameString("pair_sample_alignment_class",s.pair_sample_alignment_class);
      j.NameString("pair_window_freshness_class",s.pair_window_freshness_class);
      j.NameInt("sample_count",s.sample_count);
      j.NameBool("abstained_flag",s.abstained_flag);
      j.NameString("pair_regime_comparability_class",s.pair_regime_comparability_class);
      j.NameString("diversification_confidence_class",s.diversification_confidence_class);
      j.NameString("redundancy_risk_class",s.redundancy_risk_class);
      j.NameString("pair_outcome_surface",s.pair_outcome_surface);

      j.NameBool("changed_this_cycle",s.changed_this_cycle);
      j.NameBool("contradiction_present",s.contradiction_present);
      j.NameString("contradiction_severity_max",ContradictionSeverityToString(s.contradiction_severity_max));
      j.NameString("contradiction_flags",s.contradiction_flags);
     }

   static void WritePairCacheJson(ISSX_JsonWriter &j,const ISSX_EA4_PairCacheRecord &c)
     {
      j.NameString("symbol_a",c.symbol_a);
      j.NameString("symbol_b",c.symbol_b);
      j.NameString("pair_cache_status",PairCacheStatusToString(c.pair_cache_status));
      j.NameInt("pair_cache_age",c.pair_cache_age);
      j.NameInt("pair_last_valid_minute_id",c.pair_last_valid_minute_id);
      j.NameString("pair_last_reject_reason",CorrRejectReasonToString(c.pair_last_reject_reason));
      j.NameInt("pair_retry_after_minute_id",c.pair_retry_after_minute_id);
      j.NameInt("pair_reject_streak",c.pair_reject_streak);
      j.NameString("pair_evidence_freshness",FreshnessClassToString(c.pair_evidence_freshness));
      j.NameBool("pair_shape_changed_flag",c.pair_shape_changed_flag);
      j.NameBool("pair_evidence_invalidated_by_member_change",c.pair_evidence_invalidated_by_member_change);
      j.NameString("pair_cache_reuse_block_reason",c.pair_cache_reuse_block_reason);
      j.NameDouble("cached_similarity",c.cached_similarity,6);
      j.NameDouble("cached_corr_quality",c.cached_corr_quality,6);
      j.NameInt("cached_overlap_bars",c.cached_overlap_bars);
      j.NameString("pair_validity_class",PairValidityToSurface(c.pair_validity_class));
      j.NameString("pair_sample_alignment_class",c.pair_sample_alignment_class);
      j.NameString("pair_window_freshness_class",c.pair_window_freshness_class);
      j.NameInt("sample_count",c.sample_count);
      j.NameBool("abstained_flag",c.abstained_flag);
      j.NameString("pair_regime_comparability_class",c.pair_regime_comparability_class);
      j.NameBool("pair_ttl_expired_flag",c.pair_ttl_expired_flag);
      j.NameInt("pair_cache_ttl_minutes",c.pair_cache_ttl_minutes);
      j.NameInt("pair_next_priority_due_minute_id",c.pair_next_priority_due_minute_id);
      j.NameBool("changed_pair_priority_flag",c.changed_pair_priority_flag);
      j.NameString("pair_outcome_surface",c.pair_outcome_surface);
      j.NameString("diversification_confidence_class",c.diversification_confidence_class);
      j.NameString("redundancy_risk_class",c.redundancy_risk_class);
     }

public:
   static void ResetState(ISSX_EA4_State &state)
     {
      state.Reset();
      ISSX_BudgetPolicy::ApplyStageDefaults(issx_stage_ea4,state.runtime.budgets);
      state.policy_fingerprint=BuildPolicyFingerprint();
      state.fingerprint_algorithm_version="sha256_hex_v1";
     }

   static bool BuildState(const string firm_id,
                          const long minute_id,
                          const ISSX_EA1_State &ea1,
                          const ISSX_EA3_State &ea3,
                          ISSX_EA4_State &state)
     {
      ResetState(state);

      BeginStagePhase(state.runtime,issx_ea4_phase_load_frontier,40,"ea4_load_frontier");

      const int upstream_symbol_count_hint=ArraySize(ea1.symbols);
      if(upstream_symbol_count_hint<0)
         state.degraded_flag=true;

      state.upstream_source_used="ea3_current";
      state.upstream_source_reason="accepted_frontier";
      state.upstream_compatibility_class=issx_compatibility_compatible;
      state.upstream_compatibility_score=1.0;
      state.fallback_depth_used=0;
      state.fallback_penalty_applied=0.0;
      state.taxonomy_hash=ea3.taxonomy_hash;
      state.comparator_registry_hash=ea3.comparator_registry_hash;
      state.cohort_fingerprint=ea3.cohort_fingerprint;
      state.universe.frontier_drift_class="bounded";

      const int frontier_count=MathMin(ArraySize(ea3.frontier),ISSX_EA4_FRONTIER_HARD_LIMIT);
      state.universe.frontier_universe_count=frontier_count;
      state.universe.publishable_universe_count=frontier_count;
      state.universe.broker_universe_fingerprint=ea3.universe.broker_universe_fingerprint;
      state.universe.eligible_universe_fingerprint=ea3.universe.eligible_universe_fingerprint;
      state.universe.active_universe_fingerprint=ea3.universe.active_universe_fingerprint;
      state.universe.frontier_universe_fingerprint=ea3.universe.frontier_universe_fingerprint;
      state.universe.publishable_universe_fingerprint=ea3.universe.publishable_universe_fingerprint;

      if(frontier_count<=0)
        {
         state.degraded_flag=true;
         state.recovery_publish_flag=true;
         state.stage_minimum_ready_flag=false;
         state.stage_publishability_state=issx_publishability_not_ready;
         state.dependency_block_reason="frontier_empty";
         state.debug_weak_link_code=issx_weak_link_dependency_block;
         RefreshDerivedUniverseCoverage(state,frontier_count);
         RefreshManifest(state,firm_id);
         return true;
        }

      if(ArrayResize(state.symbols,frontier_count)!=frontier_count)
        {
         state.degraded_flag=true;
         state.recovery_publish_flag=true;
         state.stage_minimum_ready_flag=false;
         state.stage_publishability_state=issx_publishability_not_ready;
         state.dependency_block_reason="symbol_array_resize_failed";
         state.debug_weak_link_code=issx_weak_link_queue_backlog;
         RefreshDerivedUniverseCoverage(state,0);
         RefreshManifest(state,firm_id);
         return false;
        }

      BeginStagePhase(state.runtime,issx_ea4_phase_select_pair_queue,60,"ea4_select_pair_queue");

      for(int i=0;i<frontier_count;i++)
        {
         state.symbols[i].Reset();
         state.symbols[i].symbol_norm=ea3.frontier[i].symbol_norm;
         state.symbols[i].symbol_raw=ea3.frontier[i].symbol_raw;
         state.symbols[i].leader_bucket_id=ea3.frontier[i].bucket_id;
         state.symbols[i].leader_bucket_type=issx_leader_bucket_theme_bucket;
         state.symbols[i].changed_this_cycle=true;

         const int ea3_symbol_idx=FindEA3SymbolByNorm(ea3,state.symbols[i].symbol_norm);
         if(ea3_symbol_idx>=0)
           {
            state.symbols[i].alias_family_id=ea3.symbols[ea3_symbol_idx].alias_family_id;
            state.symbols[i].leader_bucket_type=ea3.symbols[ea3_symbol_idx].leader_bucket_type;
           }

         AppendChangedSymbol(state,state.symbols[i].symbol_norm);
        }

      state.delta.changed_frontier_count=frontier_count;
      state.delta.changed_family_count=CountDistinctFrontierFamilies(state);

      BeginStagePhase(state.runtime,issx_ea4_phase_compute_structural_overlap,80,"ea4_structural_overlap");
      BeginStagePhase(state.runtime,issx_ea4_phase_compute_statistical_overlap,80,"ea4_statistical_overlap");

      for(int i=0;i<frontier_count;i++)
        {
         state.counters.pair_attempted++;

         if(frontier_count==1)
           {
            SetUnknownIntelligence(state.symbols[i],issx_ea4_null_not_enough_overlap,false);
            state.counters.pair_abstained++;
            state.counters.abstained_symbol_count++;
            continue;
           }

         const int peer_index=(i==0 ? 1 : 0);
         SetBestEffortPair(state,i,peer_index,minute_id);
         state.counters.pair_computed++;
         state.counters.pair_abstained++;
         state.counters.abstained_symbol_count++;
        }

      string frontier_items[];
      ArrayResize(frontier_items,frontier_count);
      for(int i=0;i<frontier_count;i++)
         frontier_items[i]=state.symbols[i].symbol_norm;
      state.universe.frontier_universe_fingerprint=BuildStableFingerprint(frontier_items);
      state.universe.publishable_universe_fingerprint=state.universe.frontier_universe_fingerprint;

      RefreshDerivedUniverseCoverage(state,frontier_count);

      state.degraded_flag=true;
      state.stage_minimum_ready_flag=(frontier_count>0);
      state.stage_publishability_state=(frontier_count>0 ? issx_publishability_usable_degraded : issx_publishability_not_ready);
      state.dependency_block_reason=DetermineDependencyBlockReason(frontier_count,state.counters.abstained_symbol_count);
      state.debug_weak_link_code=((frontier_count<=1 || state.counters.abstained_symbol_count>=frontier_count) ?
                                  issx_weak_link_dependency_block :
                                  issx_weak_link_none);

      BeginStagePhase(state.runtime,issx_ea4_phase_publish,40,"ea4_publish");
      RefreshManifest(state,firm_id);
      return true;
     }

   static bool ExportOptionalIntelligence(const ISSX_EA4_State &state,
                                          ISSX_EA4_OptionalIntelligenceExport &out_items[])
     {
      const int n=ArraySize(state.symbols);
      if(ArrayResize(out_items,n)!=n)
         return false;

      for(int i=0;i<n;i++)
        {
         out_items[i].Reset();
         out_items[i].symbol_norm=state.symbols[i].symbol_norm;
         out_items[i].present=true;
         out_items[i].nearest_peer_similarity=state.symbols[i].statistical_facts.nearest_peer_similarity;
         out_items[i].corr_valid=state.symbols[i].statistical_facts.corr_valid;
         out_items[i].corr_quality_score=state.symbols[i].statistical_facts.corr_quality_score;
         out_items[i].corr_reject_reason=CorrRejectReasonToString(state.symbols[i].statistical_facts.corr_reject_reason);
         out_items[i].duplicate_penalty_applied=state.symbols[i].adjustment.duplicate_penalty_applied;
         out_items[i].corr_penalty_applied=state.symbols[i].adjustment.corr_penalty_applied;
         out_items[i].session_overlap_penalty_applied=state.symbols[i].adjustment.session_overlap_penalty_applied;
         out_items[i].diversification_bonus_applied=state.symbols[i].adjustment.diversification_bonus_applied;
         out_items[i].adjustment_confidence=state.symbols[i].adjustment.adjustment_confidence;
         out_items[i].portfolio_role_hint=state.symbols[i].cluster.portfolio_role_hint;
         out_items[i].structural_overlap_score=state.symbols[i].adjustment.structural_overlap_score;
         out_items[i].statistical_overlap_score=state.symbols[i].adjustment.statistical_overlap_score;
         out_items[i].intelligence_abstained=state.symbols[i].abstention.intelligence_abstained;
         out_items[i].abstention_reason=state.symbols[i].abstention.abstention_reason;
         out_items[i].intelligence_confidence=state.symbols[i].abstention.intelligence_confidence;
         out_items[i].intelligence_coverage_score=state.symbols[i].abstention.intelligence_coverage_score;
         out_items[i].pair_cache_status=state.symbols[i].pair_cache_status;
         out_items[i].pair_cache_reuse_block_reason=state.symbols[i].pair_cache_reuse_block_reason;
        }
      return true;
     }

   static bool StageBoot(ISSX_EA4_State &state,const string firm_id)
     {
      ResetState(state);
      state.header.stage_id=issx_stage_ea4;
      state.header.firm_id=firm_id;
      state.stage_minimum_ready_flag=false;
      state.stage_publishability_state=issx_publishability_not_ready;
      state.dependency_block_reason="na";
      state.debug_weak_link_code=issx_weak_link_none;
      return true;
     }

   static bool StageSlice(ISSX_EA4_State &state,
                          const string firm_id,
                          const ISSX_EA1_State &ea1,
                          const ISSX_EA3_State &ea3,
                          const long minute_id)
     {
      return BuildState(firm_id,minute_id,ea1,ea3,state);
     }

   static bool StagePublish(ISSX_EA4_State &state,string &stage_json,string &debug_json)
     {
      stage_json=BuildStageJson(state);
      debug_json=BuildDebugJson(state);
      return (StringLen(stage_json)>2);
     }

   static string BuildDebugSnapshot(const ISSX_EA4_State &state)
     {
      return BuildDebugJson(state);
     }

   static string BuildStageJson(const ISSX_EA4_State &state)
     {
      ISSX_JsonWriter j;
      j.Reset();
      j.BeginObject();

      WriteTopLevelJson(j,state);

      j.BeginObjectNamed("universe");
      WriteUniverseJson(j,state.universe);
      j.EndObject();

      j.BeginObjectNamed("delta");
      WriteDeltaJson(j,state.delta);
      j.EndObject();

      j.BeginObjectNamed("counters");
      WriteCountersJson(j,state.counters);
      j.EndObject();

      j.BeginArrayNamed("symbols");
      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         j.BeginObject();
         WriteSymbolJson(j,state.symbols[i]);
         j.EndObject();
        }
      j.EndArray();

      j.BeginArrayNamed("pair_cache");
      for(int i=0;i<ArraySize(state.pair_cache);i++)
        {
         j.BeginObject();
         WritePairCacheJson(j,state.pair_cache[i]);
         j.EndObject();
        }
      j.EndArray();

      j.EndObject();
      return j.ToString();
     }

   static string BuildDebugJson(const ISSX_EA4_State &state)
     {
      ISSX_JsonWriter j;
      j.Reset();
      j.BeginObject();

      j.NameString("stage","ea4_debug");
      j.NameString("producer","issx_correlation_engine_debug");
      j.NameString("module_version",ISSX_CORRELATION_ENGINE_MODULE_VERSION);
      j.NameString("stage_api_version",ISSX_CORRELATION_ENGINE_STAGE_API_VERSION);
      j.NameBool("degraded_flag",state.degraded_flag);
      j.NameBool("recovery_publish_flag",state.recovery_publish_flag);
      j.NameBool("stage_minimum_ready_flag",state.stage_minimum_ready_flag);
      j.NameString("stage_publishability_state",PublishabilityStateToString(state.stage_publishability_state));
      j.NameString("dependency_block_reason",state.dependency_block_reason);
      j.NameString("debug_weak_link_code",WeakLinkCodeToString(state.debug_weak_link_code));
      j.NameString("upstream_compatibility_class",CompatibilityClassToString(state.upstream_compatibility_class));
      j.NameInt("pair_attempted",state.counters.pair_attempted);
      j.NameInt("pair_computed",state.counters.pair_computed);
      j.NameInt("pair_reused",state.counters.pair_reused);
      j.NameInt("pair_abstained",state.counters.pair_abstained);
      j.NameInt("pair_invalidated",state.counters.pair_invalidated);
      j.NameInt("abstained_symbol_count",state.counters.abstained_symbol_count);
      j.NameInt("contradiction_count",state.counters.contradiction_count);
      j.NameInt("frontier_universe_count",state.universe.frontier_universe_count);
      j.NameString("frontier_universe_fingerprint",state.universe.frontier_universe_fingerprint);
      j.NameDouble("percent_frontier_revalidated_recent",state.universe.percent_frontier_revalidated_recent,2);

      j.BeginArrayNamed("pair_cache");
      for(int i=0;i<ArraySize(state.pair_cache);i++)
        {
         j.BeginObject();
         WritePairCacheJson(j,state.pair_cache[i]);
         j.EndObject();
        }
      j.EndArray();

      j.EndObject();
      return j.ToString();
     }
  };

#endif // __ISSX_CORRELATION_ENGINE_MQH__