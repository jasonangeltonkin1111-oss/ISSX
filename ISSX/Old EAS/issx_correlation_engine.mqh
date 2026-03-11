
#ifndef __ISSX_CORRELATION_ENGINE_MQH__
#define __ISSX_CORRELATION_ENGINE_MQH__
#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>
#include <ISSX/issx_market_engine.mqh>
#include <ISSX/issx_history_engine.mqh>
#include <ISSX/issx_selection_engine.mqh>

// ============================================================================
// ISSX CORRELATION ENGINE v1.7.0
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
// - corr invalid must never masquerade as low correlation
// - honest abstention beats stale
// - pair outcome surface: valid_low_overlap / valid_high_overlap / unknown_overlap / provisional_overlap / blocked_overlap fake intelligence
// - pair cache reuse must obey freshness / member-shape invalidation
// - clusters are local context only, not portfolio optimization advice
// ============================================================================

#define ISSX_CORRELATION_ENGINE_MODULE_VERSION "1.7.0"
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
      overlap_fact_flags="";
     }
  };

struct ISSX_EA4_StatisticalOverlapFacts
  {
   double                    nearest_peer_similarity;
   bool                      corr_valid;
   double                    corr_quality_score;
   string                    corr_window_class;
   double                    corr_overlap_ratio;
   ISSX_CorrRejectReason     corr_reject_reason;
   int                       pair_evidence_count;
   int                       pair_overlap_bars;
   double                    pair_alignment_score;
   double                    pair_variation_score;
   double                    pair_penalty_confidence;

   void Reset()
     {
      nearest_peer_similarity=0.0;
      corr_valid=false;
      corr_quality_score=0.0;
      corr_window_class="none";
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
   bool                    duplicate_penalty_applied;
   bool                    corr_penalty_applied;
   bool                    session_overlap_penalty_applied;
   bool                    diversification_bonus_applied;
   double                  adjustment_confidence;
   ISSX_PenaltyBasisKind   penalty_basis_kind;
   double                  structural_overlap_score;
   double                  statistical_overlap_score;
   string                  structural_overlap_reason;
   string                  statistical_overlap_quality;

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
      structural_overlap_reason="";
      statistical_overlap_quality="";
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
      abstained_blocks="";
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
      cluster_members_sample="";
      diversification_basis="";
      diversification_contributors="";
      diversification_limiters="";
      cluster_redundancy_score=0.0;
      cluster_dispersion_score=0.0;
     }
  };

struct ISSX_EA4_PairCacheRecord
  {
   string                 symbol_a;
   string                 symbol_b;
   ISSX_EA4_PairCacheStatus pair_cache_status;
   int                    pair_cache_age;
   long                   pair_last_valid_minute_id;
   ISSX_CorrRejectReason  pair_last_reject_reason;
   long                   pair_retry_after_minute_id;
   int                    pair_reject_streak;
   ISSX_FreshnessClass    pair_evidence_freshness;
   bool                   pair_shape_changed_flag;
   bool                   pair_evidence_invalidated_by_member_change;
   string                 pair_cache_reuse_block_reason;
   double                 cached_similarity;
   double                 cached_corr_quality;
   int                    cached_overlap_bars;
   ISSX_PairValidityClass pair_validity_class;
   string                 pair_sample_alignment_class;
   string                 pair_window_freshness_class;
   int                    sample_count;
   bool                   abstained_flag;
   string                 pair_regime_comparability_class;
   bool                   pair_ttl_expired_flag;
   int                    pair_cache_ttl_minutes;
   long                   pair_next_priority_due_minute_id;
   bool                   changed_pair_priority_flag;
   string                 pair_outcome_surface;
   string                 diversification_confidence_class;
   string                 redundancy_risk_class;

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
      pair_cache_reuse_block_reason="";
      cached_similarity=0.0;
      cached_corr_quality=0.0;
      cached_overlap_bars=0;
      pair_validity_class=issx_pair_validity_unknown;
      pair_sample_alignment_class="unknown";
      pair_window_freshness_class="unknown";
      sample_count=0;
      abstained_flag=false;
      pair_regime_comparability_class="unknown";
      pair_ttl_expired_flag=false;
      pair_cache_ttl_minutes=0;
      pair_next_priority_due_minute_id=0;
      changed_pair_priority_flag=false;
      pair_outcome_surface="unknown_overlap";
      diversification_confidence_class="unknown";
      redundancy_risk_class="unknown";
     }
  };

struct ISSX_EA4_SymbolIntelligence
  {
   string                       symbol_raw;
   string                       symbol_norm;
   string                       alias_family_id;
   string                       leader_bucket_id;
   ISSX_LeaderBucketType        leader_bucket_type;
   ISSX_EA4_StructuralOverlapFacts structural_facts;
   ISSX_EA4_StatisticalOverlapFacts statistical_facts;
   ISSX_EA4_AdjustmentPolicy    adjustment;
   ISSX_EA4_AbstentionCoverage  abstention;
   ISSX_EA4_RoleCluster         cluster;
   string                       pair_cache_status;
   int                          pair_cache_age;
   long                         pair_last_valid_minute_id;
   ISSX_CorrRejectReason        pair_last_reject_reason;
   long                         pair_retry_after_minute_id;
   int                          pair_reject_streak;
   ISSX_FreshnessClass          pair_evidence_freshness;
   bool                         pair_shape_changed_flag;
   bool                         pair_evidence_invalidated_by_member_change;
   string                       pair_cache_reuse_block_reason;
   ISSX_PairValidityClass       pair_validity_class;
   string                       pair_sample_alignment_class;
   string                       pair_window_freshness_class;
   int                          sample_count;
   bool                         abstained_flag;
   string                       pair_regime_comparability_class;
   string                       diversification_confidence_class;
   string                       redundancy_risk_class;
   string                       pair_outcome_surface;
   bool                         changed_this_cycle;
   bool                         contradiction_present;
   ISSX_ContradictionSeverity   contradiction_severity_max;
   string                       contradiction_flags;

   void Reset()
     {
      symbol_raw="";
      symbol_norm="";
      alias_family_id="";
      leader_bucket_id="";
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
      pair_cache_reuse_block_reason="";
      pair_validity_class=issx_pair_validity_unknown;
      pair_sample_alignment_class="unknown";
      pair_window_freshness_class="unknown";
      sample_count=0;
      abstained_flag=false;
      pair_regime_comparability_class="unknown";
      diversification_confidence_class="unknown";
      redundancy_risk_class="unknown";
      pair_outcome_surface="unknown_overlap";
      changed_this_cycle=false;
      contradiction_present=false;
      contradiction_severity_max=issx_contradiction_low;
      contradiction_flags="";
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

   void Reset()
     {
      frontier_universe_count=0;
      publishable_universe_count=0;
      broker_universe_fingerprint="";
      eligible_universe_fingerprint="";
      active_universe_fingerprint="";
      frontier_universe_fingerprint="";
      publishable_universe_fingerprint="";
      frontier_drift_class="none";
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
   ISSX_StageHeader          header;
   ISSX_Manifest             manifest;
   ISSX_RuntimeState         runtime;
   ISSX_EA4_UniverseState    universe;
   ISSX_EA4_DeltaState       delta;
   ISSX_EA4_CycleCounters    counters;
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
   ISSX_EA4_SymbolIntelligence symbols[];
   ISSX_EA4_PairCacheRecord  pair_cache[];

   void Reset()
     {
      ZeroMemory(header);
      ZeroMemory(manifest);
      runtime.Reset();
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
      ArrayResize(symbols,0);
      ArrayResize(pair_cache,0);
     }
  };

// Optional export hook for EA5 wrapper integration without forcing a contracts include.
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
      if(v<0.0) return 0.0;
      if(v>1.0) return 1.0;
      return v;
     }

   static double SafeDiv(const double a,const double b)
     {
      if(MathAbs(b)<=0.0000000001)
         return 0.0;
      return a/b;
     }

   static string CorrRejectReasonToString(const ISSX_CorrRejectReason v)
     {
      switch(v)
        {
         case issx_corr_reject_not_enough_overlap: return "not_enough_overlap";
         case issx_corr_reject_stale_history:      return "stale_history";
         case issx_corr_reject_low_variation:      return "low_variation";
         case issx_corr_reject_alignment_fail:     return "alignment_fail";
         case issx_corr_reject_budget_skipped:     return "budget_skipped";
         case issx_corr_reject_duplicate_preempted:return "duplicate_preempted";
         default:                                  return "budget_skipped";
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
         case issx_publishability_not_ready: return "not_ready";
         case issx_publishability_warmup: return "warmup";
         case issx_publishability_usable_degraded: return "usable_degraded";
         case issx_publishability_usable: return "usable";
         case issx_publishability_strong: return "strong";
         default: return "not_ready";
        }
     }

   static string CompatibilityClassToString(const ISSX_CompatibilityClass v)
     {
      switch(v)
        {
         case issx_compatibility_exact: return "exact";
         case issx_compatibility_compatible: return "compatible";
         case issx_compatibility_compatible_degraded: return "compatible_degraded";
         case issx_compatibility_incompatible: return "incompatible";
         default: return "incompatible";
        }
     }

   static string WeakLinkCodeToString(const ISSX_DebugWeakLinkCode v)
     {
      switch(v)
        {
         case issx_weak_link_none: return "none";
         case issx_weak_link_dependency_block: return "dependency_block";
         case issx_weak_link_fallback_habit: return "fallback_habit";
         case issx_weak_link_starvation: return "starvation";
         case issx_weak_link_publish_stale: return "publish_stale";
         case issx_weak_link_rewrite_storm: return "rewrite_storm";
         case issx_weak_link_queue_backlog: return "queue_backlog";
         case issx_weak_link_acceptance_failure: return "acceptance_failure";
         default: return "none";
        }
     }

   static string PairOutcomeSurfaceToString(const ISSX_PairValidityClass v)
     {
      return ISSX_Util::PairValidityClassToString(v);
     }

   static string RoleHintToString(const ISSX_PortfolioRoleHint v)
     {
      switch(v)
        {
         case issx_role_anchor:               return "anchor";
         case issx_role_overlap_risk:         return "overlap_risk";
         case issx_role_diversifier:          return "diversifier";
         case issx_role_fragile_diversifier:  return "fragile_diversifier";
         case issx_role_redundant:            return "redundant";
         default:                             return "anchor";
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
         case issx_penalty_mixed:   return "mixed";
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
         case issx_freshness_stale:  return "stale";
         default:                    return "stale";
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

   static string ContradictionSeverityToString(const ISSX_ContradictionSeverity v)
     {
      switch(v)
        {
         case issx_contradiction_low:       return "low";
         case issx_contradiction_moderate:  return "moderate";
         case issx_contradiction_high:      return "high";
         case issx_contradiction_blocking:  return "blocking";
         default:                           return "low";
        }
     }

   static int FindEA1Symbol(const ISSX_EA1_State &state,const string symbol_norm)
     {
      for(int i=0;i<ArraySize(state.symbols);i++)
         if(state.symbols[i].normalized_identity.symbol_norm==symbol_norm)
            return i;
      return -1;
     }

   static int FindEA2Symbol(const ISSX_EA2_State &state,const string symbol_norm)
     {
      for(int i=0;i<ArraySize(state.symbols);i++)
         if(state.symbols[i].symbol_norm==symbol_norm)
            return i;
      return -1;
     }

   static int FindFrontier(const ISSX_EA3_State &state,const string symbol_norm)
     {
      for(int i=0;i<ArraySize(state.frontier);i++)
         if(state.frontier[i].symbol_norm==symbol_norm)
            return i;
      return -1;
     }

   static int FindSelection(const ISSX_EA3_State &state,const string symbol_norm)
     {
      for(int i=0;i<ArraySize(state.symbols);i++)
         if(state.symbols[i].symbol_norm==symbol_norm)
            return i;
      return -1;
     }

   static int FindCache(const ISSX_EA4_State &state,const string a,const string b)
     {
      string x=a, y=b;
      if(StringCompare(x,y)>0)
        {
         string t=x; x=y; y=t;
        }
      for(int i=0;i<ArraySize(state.pair_cache);i++)
         if(state.pair_cache[i].symbol_a==x && state.pair_cache[i].symbol_b==y)
            return i;
      return -1;
     }

   static int EnsureCache(ISSX_EA4_State &state,const string a,const string b)
     {
      string x=a, y=b;
      if(StringCompare(x,y)>0)
        {
         string t=x; x=y; y=t;
        }
      int idx=FindCache(state,x,y);
      if(idx>=0) return idx;
      idx=ArraySize(state.pair_cache);
      ArrayResize(state.pair_cache,idx+1);
      state.pair_cache[idx].Reset();
      state.pair_cache[idx].symbol_a=x;
      state.pair_cache[idx].symbol_b=y;
      return idx;
     }

   static bool SameSessionFamily(const ISSX_EA1_SymbolState &a,const ISSX_EA1_SymbolState &b)
     {
      return (a.validated_runtime_truth.practical_market_state==b.validated_runtime_truth.practical_market_state);
     }

   static bool SameRiskComplex(const ISSX_EA1_SymbolState &a,const ISSX_EA1_SymbolState &b)
     {
      return (a.classification_truth.asset_class==b.classification_truth.asset_class
              && a.classification_truth.instrument_family==b.classification_truth.instrument_family);
     }

   static double ComputeStructuralOverlapScore(const ISSX_EA4_StructuralOverlapFacts &f)
     {
      double score=0.0;
      if(f.same_family_flag)         score+=0.40;
      if(f.same_quote_currency_flag) score+=0.15;
      if(f.same_session_family_flag) score+=0.15;
      if(f.same_theme_flag)          score+=0.15;
      if(f.same_risk_complex_flag)   score+=0.15;
      return Clamp01(score);
     }

   static double ComputeVariationScore(const ISSX_EA2_SymbolState &a,const ISSX_EA2_SymbolState &b)
     {
      double v1=MathAbs(a.hot_metrics.return_vol_ratio)+MathAbs(a.hot_metrics.atr_points_m15)*0.0001;
      double v2=MathAbs(b.hot_metrics.return_vol_ratio)+MathAbs(b.hot_metrics.atr_points_m15)*0.0001;
      return 0.5*(v1+v2);
     }

   static double ComputeAlignmentScore(const ISSX_EA2_SymbolState &a,const ISSX_EA2_SymbolState &b)
     {
      double x=0.40*MathMin(a.judgment.continuity_score,b.judgment.continuity_score)
              +0.30*MathMin(a.judgment.metric_trust_score,b.judgment.metric_trust_score)
              +0.30*MathMin(a.provenance.session_alignment_score,b.provenance.session_alignment_score);
      return Clamp01(x);
     }

   static int ComputeOverlapBars(const ISSX_EA2_SymbolState &a,const ISSX_EA2_SymbolState &b)
     {
      int bars=(int)MathFloor(MathMin(a.tf[issx_ea2_tf_m15].effective_usable_bars,
                                      b.tf[issx_ea2_tf_m15].effective_usable_bars));
      return bars;
     }

   static double ComputeSimilarityApprox(const ISSX_EA2_SymbolState &a,const ISSX_EA2_SymbolState &b)
     {
      double spread_eff=1.0-MathAbs(a.hot_metrics.spread_to_atr_efficiency-b.hot_metrics.spread_to_atr_efficiency);
      double vol_match=1.0-MathAbs(a.hot_metrics.return_vol_ratio-b.hot_metrics.return_vol_ratio);
      double cont_match=1.0-MathAbs(a.hot_metrics.bar_continuity_score-b.hot_metrics.bar_continuity_score);
      double struct_match=1.0-MathAbs(a.structural_context.structure_clarity_score-b.structural_context.structure_clarity_score);
      return Clamp01(0.30*Clamp01(spread_eff)+0.30*Clamp01(vol_match)+0.20*Clamp01(cont_match)+0.20*Clamp01(struct_match));
     }

   static void BuildStructuralFacts(const ISSX_EA1_SymbolState &a,
                                    const ISSX_EA1_SymbolState &b,
                                    ISSX_EA4_StructuralOverlapFacts &out)
     {
      out.Reset();
      out.same_family_flag=(a.normalized_identity.alias_family_id!="" &&
                            a.normalized_identity.alias_family_id==b.normalized_identity.alias_family_id);
      out.same_quote_currency_flag=(a.raw_broker_observation.quote_currency!="" &&
                                    a.raw_broker_observation.quote_currency==b.raw_broker_observation.quote_currency);
      out.same_session_family_flag=SameSessionFamily(a,b);
      out.same_theme_flag=(a.classification_truth.leader_bucket_id!="" &&
                           a.classification_truth.leader_bucket_id==b.classification_truth.leader_bucket_id);
      out.same_risk_complex_flag=SameRiskComplex(a,b);

      string flags="";
      if(out.same_family_flag)         flags+="family,";
      if(out.same_quote_currency_flag) flags+="quote,";
      if(out.same_session_family_flag) flags+="session,";
      if(out.same_theme_flag)          flags+="theme,";
      if(out.same_risk_complex_flag)   flags+="risk_complex,";
      out.overlap_fact_flags=flags;
      if(StringLen(out.overlap_fact_flags)>0 && StringSubstr(out.overlap_fact_flags,StringLen(out.overlap_fact_flags)-1)==",")
         out.overlap_fact_flags=StringSubstr(out.overlap_fact_flags,0,StringLen(out.overlap_fact_flags)-1);
     }

   static void BuildStatisticalFacts(const ISSX_EA2_SymbolState &a,
                                     const ISSX_EA2_SymbolState &b,
                                     ISSX_EA4_StatisticalOverlapFacts &out)
     {
      out.Reset();
      out.pair_overlap_bars=ComputeOverlapBars(a,b);
      out.corr_overlap_ratio=Clamp01(SafeDiv((double)out.pair_overlap_bars,96.0));
      out.pair_alignment_score=ComputeAlignmentScore(a,b);
      out.pair_variation_score=ComputeVariationScore(a,b);

      if(!a.history_ready_for_intelligence || !b.history_ready_for_intelligence)
        {
         out.corr_valid=false;
         out.corr_reject_reason=issx_corr_reject_stale_history;
         out.corr_quality_score=0.0;
         out.corr_window_class="none";
         out.pair_penalty_confidence=0.0;
         return;
        }

      if(out.pair_overlap_bars<ISSX_EA4_MIN_OVERLAP_BARS)
        {
         out.corr_valid=false;
         out.corr_reject_reason=issx_corr_reject_not_enough_overlap;
         out.corr_quality_score=0.0;
         out.corr_window_class="short";
         out.pair_penalty_confidence=0.0;
         return;
        }

      if(out.pair_variation_score<ISSX_EA4_MIN_PAIR_VARIATION)
        {
         out.corr_valid=false;
         out.corr_reject_reason=issx_corr_reject_low_variation;
         out.corr_quality_score=0.0;
         out.corr_window_class="short";
         out.pair_penalty_confidence=0.0;
         return;
        }

      out.corr_valid=true;
      out.corr_reject_reason=issx_corr_reject_budget_skipped;
      out.nearest_peer_similarity=ComputeSimilarityApprox(a,b);
      out.corr_quality_score=Clamp01(0.40*out.corr_overlap_ratio + 0.35*out.pair_alignment_score + 0.25*Clamp01(out.pair_variation_score));
      out.corr_window_class=(out.pair_overlap_bars>=96 ? "medium" : "short");
      out.pair_evidence_count=1;
      out.pair_penalty_confidence=Clamp01(0.50*out.corr_quality_score + 0.50*out.nearest_peer_similarity);
     }

   static void BuildAdjustment(const ISSX_EA4_StructuralOverlapFacts &sf,
                               const ISSX_EA4_StatisticalOverlapFacts &st,
                               ISSX_EA4_AdjustmentPolicy &out)
     {
      out.Reset();
      out.structural_overlap_score=ComputeStructuralOverlapScore(sf);
      out.statistical_overlap_score=(st.corr_valid ? Clamp01(st.nearest_peer_similarity*st.corr_quality_score) : 0.0);
      out.structural_overlap_reason=sf.overlap_fact_flags;
      out.statistical_overlap_quality=(st.corr_valid ? "valid" : CorrRejectReasonToString(st.corr_reject_reason));

      if(sf.same_family_flag)
        {
         out.duplicate_penalty_applied=true;
         out.penalty_basis_kind=issx_penalty_family;
        }

      if(st.corr_valid && out.statistical_overlap_score>=0.55)
        {
         out.corr_penalty_applied=true;
         if(!out.duplicate_penalty_applied)
            out.penalty_basis_kind=issx_penalty_returns;
        }

      if(sf.same_session_family_flag && !sf.same_family_flag)
        {
         out.session_overlap_penalty_applied=true;
         if(!out.duplicate_penalty_applied && !out.corr_penalty_applied)
            out.penalty_basis_kind=issx_penalty_session;
        }

      if(!sf.same_family_flag && st.corr_valid && out.statistical_overlap_score<=0.35)
        {
         out.diversification_bonus_applied=true;
         if(!out.duplicate_penalty_applied && !out.corr_penalty_applied && !out.session_overlap_penalty_applied)
            out.penalty_basis_kind=issx_penalty_bucket;
        }

      out.adjustment_confidence=Clamp01(0.45*out.structural_overlap_score
                                        +0.55*(st.corr_valid ? st.pair_penalty_confidence : 0.20*st.corr_overlap_ratio));
     }

   static void UpdateAbstention(ISSX_EA4_SymbolIntelligence &item,
                                const ISSX_EA4_StatisticalOverlapFacts &st,
                                const int peer_count)
     {
      item.abstention.Reset();
      item.abstention.peer_set_quality_score=Clamp01(SafeDiv((double)peer_count,6.0));

      if(peer_count<=0)
        {
         item.abstention.intelligence_abstained=true;
         item.abstention.abstention_reason="no_frontier_peers";
         item.abstention.abstained_blocks="statistical_overlap,cluster";
         item.abstention.intelligence_null_reason="no_frontier";
         item.abstention.intelligence_soft_missing=false;
         return;
        }

      if(!st.corr_valid)
        {
         item.abstention.intelligence_abstained=true;
         item.abstention.abstention_reason=CorrRejectReasonToString(st.corr_reject_reason);
         item.abstention.abstained_blocks="statistical_overlap";
         item.abstention.intelligence_null_reason=CorrRejectReasonToString(st.corr_reject_reason);
         item.abstention.intelligence_soft_missing=true;
         item.abstention.intelligence_coverage_score=Clamp01(0.35*item.abstention.peer_set_quality_score);
         item.abstention.intelligence_confidence=Clamp01(0.25*item.abstention.peer_set_quality_score);
         return;
        }

      item.abstention.intelligence_abstained=false;
      item.abstention.abstention_reason="";
      item.abstention.abstained_blocks="";
      item.abstention.intelligence_null_reason="none";
      item.abstention.intelligence_soft_missing=false;
      item.abstention.intelligence_coverage_score=Clamp01(0.60*item.abstention.peer_set_quality_score+0.40*st.corr_overlap_ratio);
      item.abstention.intelligence_confidence=Clamp01(0.50*st.corr_quality_score+0.50*st.pair_penalty_confidence);
     }

   static void DeriveRoleCluster(ISSX_EA4_SymbolIntelligence &item,
                                 const ISSX_EA4_StructuralOverlapFacts &sf,
                                 const ISSX_EA4_StatisticalOverlapFacts &st,
                                 const int cluster_id,
                                 const int cluster_size,
                                 const string cluster_members_sample)
     {
      item.cluster.Reset();
      item.cluster.local_cluster_id=cluster_id;
      item.cluster.local_cluster_size=(cluster_size<=0 ? 1 : cluster_size);
      item.cluster.cluster_members_sample=cluster_members_sample;
      item.cluster.local_cluster_density=Clamp01(0.50*ComputeStructuralOverlapScore(sf)
                                                 +0.50*(st.corr_valid ? st.nearest_peer_similarity : 0.0));
      item.cluster.cluster_redundancy_score=Clamp01(0.60*ComputeStructuralOverlapScore(sf)
                                                    +0.40*(st.corr_valid ? st.nearest_peer_similarity : 0.0));
      item.cluster.cluster_dispersion_score=Clamp01(1.0-item.cluster.cluster_redundancy_score);

      if(sf.same_family_flag || item.adjustment.duplicate_penalty_applied)
        {
         item.cluster.portfolio_role_hint=issx_role_redundant;
         item.cluster.role_hint_confidence=Clamp01(0.50+0.50*item.cluster.cluster_redundancy_score);
         item.cluster.diversification_basis="family";
         item.cluster.diversification_limiters="family_overlap";
        }
      else
      if(st.corr_valid && item.adjustment.statistical_overlap_score>=0.60)
        {
         item.cluster.portfolio_role_hint=issx_role_overlap_risk;
         item.cluster.role_hint_confidence=Clamp01(0.45+0.50*item.adjustment.statistical_overlap_score);
         item.cluster.diversification_basis="returns";
         item.cluster.diversification_limiters="return_overlap";
        }
      else
      if(item.adjustment.diversification_bonus_applied)
        {
         item.cluster.portfolio_role_hint=issx_role_diversifier;
         item.cluster.role_hint_confidence=Clamp01(0.40+0.45*item.cluster.cluster_dispersion_score);
         item.cluster.diversification_basis="low_overlap";
         item.cluster.diversification_contributors="structural+statistical";
        }
      else
        {
         item.cluster.portfolio_role_hint=issx_role_anchor;
         item.cluster.role_hint_confidence=Clamp01(0.35+0.35*item.abstention.intelligence_confidence);
         item.cluster.diversification_basis="frontier_context";
        }

      if(item.abstention.intelligence_abstained && item.cluster.portfolio_role_hint==issx_role_diversifier)
         item.cluster.portfolio_role_hint=issx_role_fragile_diversifier;
     }

   static void ScanLocalContradictions(ISSX_EA4_SymbolIntelligence &item)
     {
      item.contradiction_present=false;
      item.contradiction_severity_max=issx_contradiction_low;
      item.contradiction_flags="";

      if(item.adjustment.corr_penalty_applied && !item.statistical_facts.corr_valid)
        {
         item.contradiction_present=true;
         item.contradiction_severity_max=issx_contradiction_blocking;
         item.contradiction_flags+="corr_penalty_without_valid_corr,";
        }

      if(item.adjustment.diversification_bonus_applied && item.abstention.peer_set_quality_score<0.20)
        {
         item.contradiction_present=true;
         if(item.contradiction_severity_max<issx_contradiction_high)
            item.contradiction_severity_max=issx_contradiction_high;
         item.contradiction_flags+="diversification_bonus_with_weak_peer_coverage,";
        }

      if(item.pair_cache_status=="fresh" && item.pair_cache_age>ISSX_EA4_PAIR_CACHE_MAX_AGE_MINUTES)
        {
         item.contradiction_present=true;
         if(item.contradiction_severity_max<issx_contradiction_high)
            item.contradiction_severity_max=issx_contradiction_high;
         item.contradiction_flags+="pair_cache_reused_beyond_threshold,";
        }

      if(StringLen(item.contradiction_flags)>0 && StringSubstr(item.contradiction_flags,StringLen(item.contradiction_flags)-1)==",")
         item.contradiction_flags=StringSubstr(item.contradiction_flags,0,StringLen(item.contradiction_flags)-1);
     }

   static void AppendChangedSymbol(ISSX_EA4_State &state,const string symbol_norm)
     {
      if(state.delta.changed_symbol_ids=="")
         state.delta.changed_symbol_ids=symbol_norm;
      else
         state.delta.changed_symbol_ids+=","+symbol_norm;
      state.delta.changed_symbol_count++;
     }

   static void UpdateManifest(ISSX_EA4_State &state,const string firm_id)
     {
      state.header.stage_id=issx_stage_ea4;
      state.header.firm_id=firm_id;
      state.header.schema_version=ISSX_SCHEMA_VERSION;
      state.header.schema_epoch=ISSX_SCHEMA_EPOCH;
      state.header.symbol_count=ArraySize(state.symbols);
      state.header.changed_symbol_count=state.delta.changed_symbol_count;
      state.header.writer_boot_id="ea4_boot";
      state.header.writer_nonce="ea4_nonce";
      string stage_hash=ISSX_Util::HashStringHex(BuildStageJson(state));
      state.header.payload_hash=stage_hash;
      state.header.header_hash=stage_hash;
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
      state.manifest.minute_id=state.header.minute_id;
      state.manifest.writer_boot_id=state.header.writer_boot_id;
      state.manifest.writer_nonce=state.header.writer_nonce;
      state.manifest.writer_generation=state.header.writer_generation;
      state.manifest.payload_hash=state.header.payload_hash;
      state.manifest.header_hash=state.header.header_hash;
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
      state.manifest.accepted_strong_count=ArraySize(state.symbols)-state.counters.abstained_symbol_count;
      state.manifest.accepted_degraded_count=state.counters.abstained_symbol_count;
      state.manifest.rejected_count=0;
      state.manifest.cooldown_count=0;
      state.manifest.stale_usable_count=state.counters.abstained_symbol_count;
      state.manifest.projection_partial_success_flag=state.projection_partial_success_flag;
      state.manifest.accepted_promotion_verified=false;
      state.manifest.legend_hash="";
     }

        }
      js.EndArray();
      return js.ToString();
     }

public:
   static void ResetState(ISSX_EA4_State &state)
     {
      state.Reset();
     }

   static bool BuildState(const string firm_id,
                          const ISSX_EA1_State &ea1,
                          const ISSX_EA2_State &ea2,
                          const ISSX_EA3_State &ea3,
                          ISSX_EA4_State &state)
     {
      state.Reset();
      state.header.stage_id=issx_stage_ea4;
      state.header.sequence_no=ea3.header.sequence_no+1;
      state.header.minute_id=ea3.header.minute_id;
      state.header.writer_generation=ea3.header.writer_generation+1;
      state.upstream_source_used="ea3_current";
      state.upstream_source_reason="accepted_frontier";
      state.upstream_compatibility_class=issx_compatibility_exact;
      state.upstream_compatibility_score=1.0;
      state.fallback_depth_used=0;
      state.taxonomy_hash=ea3.taxonomy_hash;
      state.comparator_registry_hash=ea3.comparator_registry_hash;
      state.cohort_fingerprint=ea3.cohort_fingerprint;
      state.universe.frontier_universe_count=MathMin(ArraySize(ea3.frontier),ISSX_EA4_FRONTIER_HARD_LIMIT);
      state.universe.publishable_universe_count=state.universe.frontier_universe_count;
      state.universe.frontier_universe_fingerprint=ea3.universe.frontier_universe_fingerprint;
      state.universe.publishable_universe_fingerprint=ea3.universe.frontier_universe_fingerprint;
      state.universe.active_universe_fingerprint=ea3.universe.active_universe_fingerprint;
      state.universe.eligible_universe_fingerprint=ea3.universe.eligible_universe_fingerprint;
      state.universe.broker_universe_fingerprint=ea3.universe.broker_universe_fingerprint;

      if(ArraySize(ea3.frontier)<=0)
        {
         state.degraded_flag=true;
         state.recovery_publish_flag=true;
         UpdateManifest(state,firm_id);
         return true;
        }

      int frontier_count=MathMin(ArraySize(ea3.frontier),ISSX_EA4_FRONTIER_HARD_LIMIT);
      ArrayResize(state.symbols,frontier_count);

      for(int i=0;i<frontier_count;i++)
        {
         state.symbols[i].Reset();
         const ISSX_EA3_FrontierItem &fi=ea3.frontier[i];
         int idx1=FindEA1Symbol(ea1,fi.symbol_norm);
         int idx2=FindEA2Symbol(ea2,fi.symbol_norm);
         int idx3=FindSelection(ea3,fi.symbol_norm);

         state.symbols[i].symbol_norm=fi.symbol_norm;
         state.symbols[i].symbol_raw=fi.symbol_raw;
         if(idx1>=0)
           {
            state.symbols[i].alias_family_id=ea1.symbols[idx1].normalized_identity.alias_family_id;
            state.symbols[i].leader_bucket_id=ea1.symbols[idx1].classification_truth.leader_bucket_id;
            state.symbols[i].leader_bucket_type=ea1.symbols[idx1].classification_truth.leader_bucket_type;
           }
         if(idx3>=0)
            state.symbols[i].changed_this_cycle=ea3.symbols[idx3].selected_frontier;
         AppendChangedSymbol(state,fi.symbol_norm);
        }

      // Pairwise frontier scan: keep best peer only per symbol.
      for(int i=0;i<frontier_count;i++)
        {
         int idx1a=FindEA1Symbol(ea1,state.symbols[i].symbol_norm);
         int idx2a=FindEA2Symbol(ea2,state.symbols[i].symbol_norm);
         if(idx1a<0 || idx2a<0)
           {
            state.symbols[i].abstention.intelligence_abstained=true;
            state.symbols[i].abstention.abstention_reason="upstream_missing";
            state.symbols[i].abstention.abstained_blocks="structural_overlap,statistical_overlap";
            state.symbols[i].abstention.intelligence_null_reason="upstream_missing";
            state.degraded_flag=true;
            state.counters.abstained_symbol_count++;
            continue;
           }

         const ISSX_EA1_SymbolState &a1=ea1.symbols[idx1a];
         const ISSX_EA2_SymbolState &a2=ea2.symbols[idx2a];

         double best_score=-1.0;
         int    best_j=-1;
         ISSX_EA4_StructuralOverlapFacts best_sf;
         ISSX_EA4_StatisticalOverlapFacts best_st;
         ISSX_EA4_AdjustmentPolicy best_adj;
         best_sf.Reset(); best_st.Reset(); best_adj.Reset();

         int peer_count=0;
         int cluster_size=1;
         string cluster_members="";

         for(int j=0;j<frontier_count;j++)
           {
            if(i==j) continue;
            peer_count++;

            int idx1b=FindEA1Symbol(ea1,state.symbols[j].symbol_norm);
            int idx2b=FindEA2Symbol(ea2,state.symbols[j].symbol_norm);
            if(idx1b<0 || idx2b<0)
               continue;

            state.counters.pair_attempted++;

            const ISSX_EA1_SymbolState &b1=ea1.symbols[idx1b];
            const ISSX_EA2_SymbolState &b2=ea2.symbols[idx2b];

            ISSX_EA4_StructuralOverlapFacts sf; sf.Reset();
            ISSX_EA4_StatisticalOverlapFacts st; st.Reset();
            ISSX_EA4_AdjustmentPolicy adj; adj.Reset();

            BuildStructuralFacts(a1,b1,sf);
            BuildStatisticalFacts(a2,b2,st);
            BuildAdjustment(sf,st,adj);

            int cache_idx=EnsureCache(state,state.symbols[i].symbol_norm,state.symbols[j].symbol_norm);
            state.pair_cache[cache_idx].pair_cache_age=0;
            state.pair_cache[cache_idx].pair_last_valid_minute_id=state.header.minute_id;
            state.pair_cache[cache_idx].pair_last_reject_reason=st.corr_reject_reason;
            state.pair_cache[cache_idx].pair_evidence_freshness=(st.corr_valid ? issx_freshness_fresh : issx_freshness_usable);
            state.pair_cache[cache_idx].pair_cache_status=(st.corr_valid ? issx_ea4_pair_cache_fresh : issx_ea4_pair_cache_aging);
            state.pair_cache[cache_idx].cached_similarity=st.nearest_peer_similarity;
            state.pair_cache[cache_idx].cached_corr_quality=st.corr_quality_score;
            state.pair_cache[cache_idx].cached_overlap_bars=st.pair_overlap_bars;
            state.pair_cache[cache_idx].pair_validity_class=(st.corr_valid
                                                             ? (st.nearest_peer_similarity>=0.65 ? issx_pair_validity_valid_high_overlap : issx_pair_validity_valid_low_overlap)
                                                             : (st.pair_overlap_bars>0 ? issx_pair_validity_provisional_overlap : issx_pair_validity_unknown));
            state.pair_cache[cache_idx].pair_sample_alignment_class=(st.corr_valid ? "aligned" : "partial");
            state.pair_cache[cache_idx].pair_window_freshness_class=FreshnessClassToString(state.pair_cache[cache_idx].pair_evidence_freshness);
            state.pair_cache[cache_idx].sample_count=st.pair_overlap_bars;
            state.pair_cache[cache_idx].abstained_flag=!st.corr_valid;
            state.pair_cache[cache_idx].pair_regime_comparability_class=(sf.same_session_profile_flag ? "comparable" : "mixed");
            state.pair_cache[cache_idx].pair_ttl_expired_flag=false;
            state.pair_cache[cache_idx].pair_cache_ttl_minutes=60;
            state.pair_cache[cache_idx].pair_next_priority_due_minute_id=state.header.minute_id+10;
            state.pair_cache[cache_idx].changed_pair_priority_flag=st.shape_changed_flag;
            state.pair_cache[cache_idx].pair_outcome_surface=PairOutcomeSurfaceToString(state.pair_cache[cache_idx].pair_validity_class);
            state.pair_cache[cache_idx].diversification_confidence_class=(st.corr_valid ? "moderate" : "low");
            state.pair_cache[cache_idx].redundancy_risk_class=((sf.same_family_flag || (st.corr_valid && st.nearest_peer_similarity>=0.65)) ? "high" : "moderate");
            state.counters.pair_computed++;

            double score=Clamp01(0.45*adj.structural_overlap_score
                                 +0.55*(st.corr_valid ? st.nearest_peer_similarity : 0.15*st.corr_overlap_ratio));
            if(sf.same_family_flag || sf.same_theme_flag || (st.corr_valid && st.nearest_peer_similarity>0.65))
              {
               cluster_size++;
               if(StringLen(cluster_members)<64)
                 {
                  if(cluster_members!="") cluster_members+=",";
                  cluster_members+=state.symbols[j].symbol_norm;
                 }
              }

            if(score>best_score)
              {
               best_score=score;
               best_j=j;
               best_sf=sf;
               best_st=st;
               best_adj=adj;
              }
           }

         if(best_j<0)
           {
            UpdateAbstention(state.symbols[i],best_st,peer_count);
            DeriveRoleCluster(state.symbols[i],best_sf,best_st,i,cluster_size,cluster_members);
            state.counters.abstained_symbol_count++;
            continue;
           }

         state.symbols[i].structural_facts=best_sf;
         state.symbols[i].statistical_facts=best_st;
         state.symbols[i].adjustment=best_adj;
         UpdateAbstention(state.symbols[i],best_st,peer_count);
         DeriveRoleCluster(state.symbols[i],best_sf,best_st,i,cluster_size,cluster_members);

         int best_cache=FindCache(state,state.symbols[i].symbol_norm,state.symbols[best_j].symbol_norm);
         if(best_cache>=0)
           {
            state.symbols[i].pair_cache_status=PairCacheStatusToString(state.pair_cache[best_cache].pair_cache_status);
            state.symbols[i].pair_cache_age=state.pair_cache[best_cache].pair_cache_age;
            state.symbols[i].pair_last_valid_minute_id=state.pair_cache[best_cache].pair_last_valid_minute_id;
            state.symbols[i].pair_last_reject_reason=state.pair_cache[best_cache].pair_last_reject_reason;
            state.symbols[i].pair_retry_after_minute_id=state.pair_cache[best_cache].pair_retry_after_minute_id;
            state.symbols[i].pair_reject_streak=state.pair_cache[best_cache].pair_reject_streak;
            state.symbols[i].pair_evidence_freshness=state.pair_cache[best_cache].pair_evidence_freshness;
            state.symbols[i].pair_shape_changed_flag=state.pair_cache[best_cache].pair_shape_changed_flag;
            state.symbols[i].pair_evidence_invalidated_by_member_change=state.pair_cache[best_cache].pair_evidence_invalidated_by_member_change;
            state.symbols[i].pair_cache_reuse_block_reason=state.pair_cache[best_cache].pair_cache_reuse_block_reason;
           }

         if(state.symbols[i].abstention.intelligence_abstained)
           {
            state.counters.abstained_symbol_count++;
            state.counters.pair_abstained++;
           }

         ScanLocalContradictions(state.symbols[i]);
         if(state.symbols[i].contradiction_present)
            state.counters.contradiction_count++;
        }

      state.delta.changed_frontier_count=frontier_count;
      state.delta.changed_family_count=0;
      state.degraded_flag=(state.counters.abstained_symbol_count>0);
      state.stage_minimum_ready_flag=(frontier_count>0);
      state.stage_publishability_state=(frontier_count<=0 ? issx_publishability_not_ready
                                                          : (state.degraded_flag ? issx_publishability_usable_degraded : issx_publishability_usable));
      state.dependency_block_reason=(frontier_count<=0 ? "frontier_empty" : "");
      state.debug_weak_link_code=(state.degraded_flag ? issx_weak_link_dependency_block : issx_weak_link_none);
      UpdateManifest(state,firm_id);
      return true;
     }

   static void ExportOptionalIntelligence(const ISSX_EA4_State &state,
                                          ISSX_EA4_OptionalIntelligenceExport &out_items[])
     {
      ArrayResize(out_items,ArraySize(state.symbols));
      for(int i=0;i<ArraySize(state.symbols);i++)
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
     }



   static bool StageBoot(ISSX_EA4_State &state,const string firm_id)
     {
      state.Reset();
      state.header.stage_id=issx_stage_ea4;
      state.header.firm_id=firm_id;
      state.stage_minimum_ready_flag=false;
      state.stage_publishability_state=issx_publishability_not_ready;
      state.dependency_block_reason="";
      state.debug_weak_link_code=issx_weak_link_none;
      return true;
     }

   static bool StageSlice(ISSX_EA4_State &state,
                          const string firm_id,
                          const ISSX_EA1_State &ea1,
                          const ISSX_EA2_State &ea2,
                          const ISSX_EA3_State &ea3,
                          const long minute_id)
     {
      return BuildState(state,firm_id,minute_id,ea1,ea2,ea3);
     }

   static bool StagePublish(ISSX_EA4_State &state,string &stage_json,string &debug_json)
     {
      stage_json=BuildStageJson(state);
      debug_json=BuildDebugJson(state);
      return true;
     }

   static string BuildDebugSnapshot(const ISSX_EA4_State &state)
     {
      return BuildDebugJson(state);
     }

   static string BuildStageJson(const ISSX_EA4_State &state)
     {
      string json="{";
      json+="\"producer\":\"issx_correlation_engine\"";
      json+=",\"module_version\":\""+ISSX_Util::EscapeJson(ISSX_CORRELATION_ENGINE_MODULE_VERSION)+"\"";
      json+=",\"sequence_no\":"+IntegerToString((int)state.header.sequence_no);
      json+=",\"minute_id\":"+IntegerToString((int)state.header.minute_id);
      json+=",\"upstream_source_used\":\""+ISSX_Util::EscapeJson(state.upstream_source_used)+"\"";
      json+=",\"upstream_compatibility_class\":\""+ISSX_Util::EscapeJson(CompatibilityClassToString(state.upstream_compatibility_class))+"\"";
      json+=",\"degraded_flag\":"+ISSX_Util::BoolToString(state.degraded_flag);
      json+=",\"frontier_universe_count\":"+IntegerToString(state.universe.frontier_universe_count);
      json+=",\"changed_frontier_count\":"+IntegerToString(state.delta.changed_frontier_count);
      json+=",\"changed_symbol_ids\":\""+ISSX_Util::EscapeJson(state.delta.changed_symbol_ids)+"\"";
      json+=",\"contradiction_count\":"+IntegerToString(state.counters.contradiction_count);
      json+=",\"symbols\":[";
      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         if(i>0) json+=",";
         const ISSX_EA4_SymbolIntelligence &s=state.symbols[i];
         json+="{";
         json+="\"symbol_raw\":\""+ISSX_Util::EscapeJson(s.symbol_raw)+"\"";
         json+=",\"symbol_norm\":\""+ISSX_Util::EscapeJson(s.symbol_norm)+"\"";
         json+=",\"leader_bucket_id\":\""+ISSX_Util::EscapeJson(s.leader_bucket_id)+"\"";
         json+=",\"overlap_fact_flags\":\""+ISSX_Util::EscapeJson(s.structural_facts.overlap_fact_flags)+"\"";
         json+=",\"nearest_peer_similarity\":"+DoubleToString(s.statistical_facts.nearest_peer_similarity,6);
         json+=",\"corr_valid\":"+ISSX_Util::BoolToString(s.statistical_facts.corr_valid);
         json+=",\"corr_quality_score\":"+DoubleToString(s.statistical_facts.corr_quality_score,6);
         json+=",\"corr_reject_reason\":\""+ISSX_Util::EscapeJson(CorrRejectReasonToString(s.statistical_facts.corr_reject_reason))+"\"";
         json+=",\"duplicate_penalty_applied\":"+ISSX_Util::BoolToString(s.adjustment.duplicate_penalty_applied);
         json+=",\"corr_penalty_applied\":"+ISSX_Util::BoolToString(s.adjustment.corr_penalty_applied);
         json+=",\"session_overlap_penalty_applied\":"+ISSX_Util::BoolToString(s.adjustment.session_overlap_penalty_applied);
         json+=",\"diversification_bonus_applied\":"+ISSX_Util::BoolToString(s.adjustment.diversification_bonus_applied);
         json+=",\"adjustment_confidence\":"+DoubleToString(s.adjustment.adjustment_confidence,6);
         json+=",\"penalty_basis_kind\":\""+ISSX_Util::EscapeJson(PenaltyBasisToString(s.adjustment.penalty_basis_kind))+"\"";
         json+=",\"intelligence_abstained\":"+ISSX_Util::BoolToString(s.abstention.intelligence_abstained);
         json+=",\"abstention_reason\":\""+ISSX_Util::EscapeJson(s.abstention.abstention_reason)+"\"";
         json+=",\"intelligence_confidence\":"+DoubleToString(s.abstention.intelligence_confidence,6);
         json+=",\"intelligence_coverage_score\":"+DoubleToString(s.abstention.intelligence_coverage_score,6);
         json+=",\"portfolio_role_hint\":\""+ISSX_Util::EscapeJson(RoleHintToString(s.cluster.portfolio_role_hint))+"\"";
         json+=",\"role_hint_confidence\":"+DoubleToString(s.cluster.role_hint_confidence,6);
         json+=",\"local_cluster_id\":"+IntegerToString(s.cluster.local_cluster_id);
         json+=",\"local_cluster_size\":"+IntegerToString(s.cluster.local_cluster_size);
         json+=",\"local_cluster_density\":"+DoubleToString(s.cluster.local_cluster_density,6);
         json+=",\"cluster_members_sample\":\""+ISSX_Util::EscapeJson(s.cluster.cluster_members_sample)+"\"";
         json+=",\"pair_cache_status\":\""+ISSX_Util::EscapeJson(s.pair_cache_status)+"\"";
         json+=",\"pair_cache_age\":"+IntegerToString(s.pair_cache_age);
         json+=",\"pair_evidence_freshness\":\""+ISSX_Util::EscapeJson(FreshnessClassToString(s.pair_evidence_freshness))+"\"";
         json+=",\"pair_cache_reuse_block_reason\":\""+ISSX_Util::EscapeJson(s.pair_cache_reuse_block_reason)+"\"";
         json+=",\"contradiction_present\":"+ISSX_Util::BoolToString(s.contradiction_present);
         json+=",\"contradiction_severity_max\":\""+ISSX_Util::EscapeJson(ContradictionSeverityToString(s.contradiction_severity_max))+"\"";
         json+=",\"contradiction_flags\":\""+ISSX_Util::EscapeJson(s.contradiction_flags)+"\"";
         json+="}";
        }
      json+="]}";
      return json;
     }


   static string BuildDebugJson(const ISSX_EA4_State &state)
     {
      string json="{";
      json+="\"producer\":\"issx_correlation_engine_debug\"";
      json+=",\"pair_attempted\":"+IntegerToString(state.counters.pair_attempted);
      json+=",\"pair_computed\":"+IntegerToString(state.counters.pair_computed);
      json+=",\"pair_reused\":"+IntegerToString(state.counters.pair_reused);
      json+=",\"pair_abstained\":"+IntegerToString(state.counters.pair_abstained);
      json+=",\"pair_invalidated\":"+IntegerToString(state.counters.pair_invalidated);
      json+=",\"abstained_symbol_count\":"+IntegerToString(state.counters.abstained_symbol_count);
      json+=",\"contradiction_count\":"+IntegerToString(state.counters.contradiction_count);
      json+=",\"frontier_universe_fingerprint\":\""+ISSX_Util::EscapeJson(state.universe.frontier_universe_fingerprint)+"\"";
      json+=",\"pair_cache\":[";
      for(int i=0;i<ArraySize(state.pair_cache);i++)
        {
         if(i>0) json+=",";
         json+="{";
         json+="\"symbol_a\":\""+ISSX_Util::EscapeJson(state.pair_cache[i].symbol_a)+"\"";
         json+=",\"symbol_b\":\""+ISSX_Util::EscapeJson(state.pair_cache[i].symbol_b)+"\"";
         json+=",\"pair_cache_status\":\""+ISSX_Util::EscapeJson(PairCacheStatusToString(state.pair_cache[i].pair_cache_status))+"\"";
         json+=",\"pair_cache_age\":"+IntegerToString(state.pair_cache[i].pair_cache_age);
         json+=",\"pair_last_reject_reason\":\""+ISSX_Util::EscapeJson(CorrRejectReasonToString(state.pair_cache[i].pair_last_reject_reason))+"\"";
         json+=",\"pair_evidence_freshness\":\""+ISSX_Util::EscapeJson(FreshnessClassToString(state.pair_cache[i].pair_evidence_freshness))+"\"";
         json+=",\"pair_shape_changed_flag\":"+ISSX_Util::BoolToString(state.pair_cache[i].pair_shape_changed_flag);
         json+=",\"pair_evidence_invalidated_by_member_change\":"+ISSX_Util::BoolToString(state.pair_cache[i].pair_evidence_invalidated_by_member_change);
         json+=",\"pair_cache_reuse_block_reason\":\""+ISSX_Util::EscapeJson(state.pair_cache[i].pair_cache_reuse_block_reason)+"\"";
         json+="}";
        }
      json+="]}";
      return json;
     }

  };


#endif // __ISSX_CORRELATION_ENGINE_MQH__
