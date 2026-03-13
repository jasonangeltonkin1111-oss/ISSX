#ifndef __ISSX_REGISTRY_MQH__
#define __ISSX_REGISTRY_MQH__

#include <ISSX/issx_core.mqh>

// ============================================================================
// ISSX REGISTRY v1.732
// Central ownership metadata for fields, enum surfaces, comparator contracts,
// policy-sensitive fingerprints, owner-surface inventory, semantic warnings,
// and EA5 legend support.
//
// BLUEPRINT ALIGNMENT
// - every exported field has one owner
// - shared semantic enums remain core-owned only
// - registry references core enums but does not redefine them
// - debug/diagnostic fields are explicitly marked diagnostic
// - warehouse-derived fields declare provenance and stale policy
// - policy-sensitive compatibility remains fingerprint-visible
// - stable ordering / deterministic hashing surfaces are registry-visible
// - owner-surface inventory is maintained as governance metadata
// ============================================================================

// ============================================================================
// SECTION 00: REGISTRY-LOCAL COMPATIBILITY POLICY
// Shared semantic enums are core-owned only.
// This registry consumes core-owned enums and DTOs from
// <ISSX/issx_core.mqh> and must not redefine them locally.
// ============================================================================

// ============================================================================
// SECTION 01: DTO TYPES
// ============================================================================

struct ISSX_FieldMetadataEntry
  {
   string               field_name;
   ISSX_StageId         owner_ea;
   string               semantic_type;
   string               unit;
   int                  precision;
   bool                 allowed_null;
   ISSX_MissingPolicy   missing_policy;
   ISSX_StalePolicy     stale_policy;
   ISSX_DirectOrDerived direct_or_derived;
   ISSX_AuthorityLevel  authority_level;
   string               projection_policy;
   string               consumer_warning;
   bool                 cache_provenance_required;
   bool                 continuity_derived;
   bool                 non_directional;
   string               runtime_state_kind;

   void Reset()
     {
      field_name="";
      owner_ea=issx_stage_unknown;
      semantic_type="";
      unit="";
      precision=0;
      allowed_null=false;
      missing_policy=issx_missing_unknown;
      stale_policy=issx_stale_policy_unknown;
      direct_or_derived=issx_direct_or_derived_unknown;
      authority_level=issx_authority_unknown;
      projection_policy="";
      consumer_warning="";
      cache_provenance_required=false;
      continuity_derived=false;
      non_directional=false;
      runtime_state_kind="";
     }
  };

struct ISSX_EnumMetadataEntry
  {
   string enum_name;
   string allowed_values_csv;
   string compact_description;

   void Reset()
     {
      enum_name="";
      allowed_values_csv="";
      compact_description="";
     }
  };

struct ISSX_ComparatorMetadataEntry
  {
   string comparator_id;
   string human_label;
   string scope;
   string stable_ordering_rule_summary;
   string tie_break_note;
   bool   enabled;

   void Reset()
     {
      comparator_id="";
      human_label="";
      scope="";
      stable_ordering_rule_summary="";
      tie_break_note="";
      enabled=false;
     }
  };

// ============================================================================
// SECTION 02: FIELD REGISTRY
// ============================================================================

class ISSX_FieldRegistry
  {
private:
   ISSX_FieldMetadataEntry m_items[];

   int CompareText(const string a,const string b) const
     {
      return StringCompare(a,b);
     }

   string MissingPolicyToString(const ISSX_MissingPolicy v) const
     {
      return ISSX_Enum::MissingPolicyToString(v);
     }

   string StalePolicyToString(const ISSX_StalePolicy v) const
     {
      return ISSX_Enum::StalePolicyToString(v);
     }

   void BuildSortedIndices(int &indices[]) const
     {
      const int n=ArraySize(m_items);
      ArrayResize(indices,n);
      for(int i=0;i<n;i++)
         indices[i]=i;

      for(int i=0;i<n-1;i++)
        {
         int best=i;
         for(int j=i+1;j<n;j++)
           {
            const int a=indices[j];
            const int b=indices[best];
            if(CompareText(m_items[a].field_name,m_items[b].field_name)<0)
               best=j;
           }
         if(best!=i)
           {
            const int tmp=indices[i];
            indices[i]=indices[best];
            indices[best]=tmp;
           }
        }
     }

   bool StringStartsWith(const string value,const string prefix) const
     {
      const int lp=StringLen(prefix);
      if(lp<=0)
         return true;
      if(StringLen(value)<lp)
         return false;
      return (StringSubstr(value,0,lp)==prefix);
     }

   bool StringEndsWith(const string value,const string suffix) const
     {
      const int lv=StringLen(value);
      const int ls=StringLen(suffix);
      if(ls<=0)
         return true;
      if(ls>lv)
         return false;
      return (StringSubstr(value,lv-ls,ls)==suffix);
     }

   bool StringContains(const string value,const string needle) const
     {
      return (StringFind(value,needle)>=0);
     }

   bool IsDebugField(const string field_name) const
     {
      return StringStartsWith(field_name,"debug_")
          || StringStartsWith(field_name,"weakest_")
          || StringStartsWith(field_name,"why_")
          || StringStartsWith(field_name,"stage_last_")
          || StringStartsWith(field_name,"stage_backlog_")
          || StringStartsWith(field_name,"stage_starvation_")
          || StringStartsWith(field_name,"stage_dependency_")
          || StringStartsWith(field_name,"stage_resume_")
          || StringStartsWith(field_name,"stage_missed_")
          || field_name==ISSX_FIELD_DEBUG_WEAK_LINK_CODE
          || field_name==ISSX_FIELD_DEPENDENCY_BLOCK_REASON
          || field_name==ISSX_FIELD_WEAKEST_STAGE
          || field_name==ISSX_FIELD_WEAKEST_STAGE_REASON
          || field_name==ISSX_FIELD_WEAK_LINK_SEVERITY
          || field_name==ISSX_FIELD_ERROR_WEIGHT
          || field_name==ISSX_FIELD_DEGRADE_WEIGHT
          || field_name==ISSX_FIELD_DEPENDENCY_WEIGHT
          || field_name==ISSX_FIELD_FALLBACK_WEIGHT
          || field_name==ISSX_FIELD_LARGEST_BACKLOG_OWNER
          || field_name==ISSX_FIELD_OLDEST_UNSERVED_QUEUE_FAMILY
          || field_name==ISSX_FIELD_FRONTIER_REFRESH_LAG_FOR_NEW_MOVERS
          || field_name==ISSX_FIELD_SELECTION_LATENCY_RISK_CLASS
          || field_name==ISSX_FIELD_NEVER_RANKED_BUT_NOW_OBSERVABLE_COUNT
          || field_name==ISSX_FIELD_KERNEL_DEGRADED_CYCLE_FLAG
          || field_name==ISSX_FIELD_CONTRADICTION_REPAIR_STATE
          || field_name==ISSX_FIELD_STAGE_LAST_RUN_MS
          || field_name==ISSX_FIELD_STAGE_LAST_PUBLISH_MINUTE_ID
          || field_name==ISSX_FIELD_STAGE_PUBLISH_DUE_FLAG
          || field_name==ISSX_FIELD_STAGE_BACKLOG_SCORE
          || field_name==ISSX_FIELD_STAGE_STARVATION_SCORE
          || field_name==ISSX_FIELD_STAGE_DEPENDENCY_BLOCK_REASON
          || field_name==ISSX_FIELD_STAGE_RESUME_KEY
          || field_name==ISSX_FIELD_STAGE_LAST_SUCCESS_SERVICE_MONO_MS
          || field_name==ISSX_FIELD_STAGE_LAST_ATTEMPT_SERVICE_MONO_MS
          || field_name==ISSX_FIELD_STAGE_MISSED_DUE_CYCLES;
     }

   bool IsHistoryOrWarehouseField(const string field_name) const
     {
      return StringStartsWith(field_name,"history_")
          || StringStartsWith(field_name,"warehouse_")
          || field_name==ISSX_FIELD_EFFECTIVE_LOOKBACK_BARS
          || field_name==ISSX_FIELD_WARMUP_SUFFICIENT_FLAG
          || field_name==ISSX_FIELD_HISTORY_DEEP_COMPLETION_PCT
          || field_name==ISSX_FIELD_WINNER_CACHE_DEPENDENCE_PCT
          || field_name=="microstructure_noise_class"
          || field_name=="range_efficiency_class"
          || field_name=="noise_to_range_ratio"
          || field_name=="bar_overlap_class"
          || field_name=="directional_persistence_class"
          || field_name=="two_way_rotation_class"
          || field_name=="gap_disruption_class"
          || field_name=="recent_compression_expansion_ratio"
          || field_name=="finality_state"
          || field_name=="rewrite_class";
     }

   bool IsFingerprintOrHashField(const string field_name) const
     {
      return StringContains(field_name,"fingerprint")
          || StringContains(field_name,"_hash")
          || StringEndsWith(field_name,"hash");
     }

   bool IsSummaryField(const string field_name) const
     {
      return StringContains(field_name,"summary");
     }

   bool IsAgeField(const string field_name) const
     {
      return StringEndsWith(field_name,"_age_sec")
          || StringEndsWith(field_name,"_refresh_age_sec")
          || StringEndsWith(field_name,"_change_sec");
     }

   bool IsOptionalContextField(const string field_name) const
     {
      return field_name==ISSX_FIELD_DIVERSIFICATION_CONFIDENCE_CLASS
          || field_name==ISSX_FIELD_REDUNDANCY_RISK_CLASS
          || field_name==ISSX_FIELD_WINNER_CORR_REFRESH_AGE_SEC
          || field_name=="sample_count"
          || field_name=="abstained_flag"
          || field_name=="pair_regime_comparability_class"
          || field_name=="reserve_promoted_for_diversity_flag"
          || field_name=="redundancy_swap_reason"
          || field_name=="winner_archetype_class"
          || field_name=="bucket_redundancy_penalty";
     }

   ISSX_StageId InferOwner(const string field_name) const
     {
      if(StringStartsWith(field_name,"winner_")
         || StringStartsWith(field_name,"selection_reason_")
         || StringStartsWith(field_name,"selection_penalty_")
         || StringStartsWith(field_name,"winner_limitation_")
         || field_name==ISSX_FIELD_SELECTION_REASON_SUMMARY
         || field_name==ISSX_FIELD_SELECTION_PENALTY_SUMMARY
         || field_name==ISSX_FIELD_WINNER_LIMITATION_SUMMARY
         || field_name==ISSX_FIELD_WINNER_CONFIDENCE_CLASS
         || field_name==ISSX_FIELD_EXPORT_GENERATED_AT
         || field_name==ISSX_FIELD_EA1_AGE_SEC
         || field_name==ISSX_FIELD_EA2_AGE_SEC
         || field_name==ISSX_FIELD_EA3_AGE_SEC
         || field_name==ISSX_FIELD_EA4_AGE_SEC
         || field_name==ISSX_FIELD_SOURCE_GENERATION_IDS
         || field_name==ISSX_FIELD_REGIME_SUMMARY
         || field_name==ISSX_FIELD_EXECUTION_CONDITION_SUMMARY
         || field_name==ISSX_FIELD_DIVERSIFICATION_CONTEXT_SUMMARY
         || field_name==ISSX_FIELD_WHY_EXPORT_IS_THIN
         || field_name==ISSX_FIELD_WHY_PUBLISH_IS_STALE
         || field_name==ISSX_FIELD_WHY_FRONTIER_IS_SMALL
         || field_name==ISSX_FIELD_WHY_INTELLIGENCE_ABSTAINED
         || field_name==ISSX_FIELD_WINNER_HISTORY_AGE_BY_TF
         || field_name==ISSX_FIELD_WINNER_QUOTE_AGE_SEC
         || field_name==ISSX_FIELD_WINNER_TRADEABILITY_REFRESH_AGE_SEC
         || field_name==ISSX_FIELD_WINNER_RANK_REFRESH_AGE_SEC
         || field_name==ISSX_FIELD_WINNER_REGIME_REFRESH_AGE_SEC
         || field_name==ISSX_FIELD_WINNER_CORR_REFRESH_AGE_SEC
         || field_name==ISSX_FIELD_WINNER_LAST_MATERIAL_CHANGE_SEC)
         return issx_stage_ea5;

      if(StringStartsWith(field_name,"pair_")
         || field_name==ISSX_FIELD_PAIR_VALIDITY_CLASS
         || field_name==ISSX_FIELD_PAIR_SAMPLE_ALIGNMENT_CLASS
         || field_name==ISSX_FIELD_PAIR_WINDOW_FRESHNESS_CLASS
         || field_name==ISSX_FIELD_DIVERSIFICATION_CONFIDENCE_CLASS
         || field_name==ISSX_FIELD_REDUNDANCY_RISK_CLASS
         || field_name=="sample_count"
         || field_name=="abstained_flag")
         return issx_stage_ea4;

      if(StringStartsWith(field_name,"bucket_")
         || field_name==ISSX_FIELD_RANKABILITY_LANE
         || field_name==ISSX_FIELD_EXPLORATORY_PENALTY_APPLIED
         || field_name==ISSX_FIELD_SELECTION_LATENCY_RISK_CLASS
         || field_name==ISSX_FIELD_OPPORTUNITY_WITH_CAUTION_FLAG
         || field_name==ISSX_FIELD_EARLY_MOVE_QUALITY_CLASS
         || field_name=="winner_archetype_class"
         || field_name=="reserve_promoted_for_diversity_flag"
         || field_name=="redundancy_swap_reason")
         return issx_stage_ea3;

      if(IsHistoryOrWarehouseField(field_name)
         || field_name==ISSX_FIELD_INTRADAY_ACTIVITY_STATE
         || field_name==ISSX_FIELD_LIQUIDITY_REGIME_CLASS
         || field_name==ISSX_FIELD_VOLATILITY_REGIME_CLASS
         || field_name==ISSX_FIELD_EXPANSION_STATE_CLASS
         || field_name==ISSX_FIELD_MOVEMENT_QUALITY_CLASS
         || field_name==ISSX_FIELD_MOVEMENT_MATURITY_CLASS
         || field_name==ISSX_FIELD_SESSION_PHASE_CLASS
         || field_name==ISSX_FIELD_HOLDING_HORIZON_CONTEXT
         || field_name==ISSX_FIELD_CONSTRUCTABILITY_CLASS
         || field_name==ISSX_FIELD_MOVEMENT_TO_COST_EFFICIENCY_CLASS
         || field_name==ISSX_FIELD_COVERAGE_RANKABLE_RECENT_PCT
         || field_name==ISSX_FIELD_COVERAGE_FRONTIER_RECENT_PCT
         || field_name==ISSX_FIELD_HISTORY_DEEP_COMPLETION_PCT
         || field_name==ISSX_FIELD_WINNER_CACHE_DEPENDENCE_PCT)
         return issx_stage_ea2;

      if(StringStartsWith(field_name,"dump_")
         || StringStartsWith(field_name,"changed_")
         || StringStartsWith(field_name,"percent_universe_")
         || field_name==ISSX_FIELD_NEVER_RANKED_BUT_ELIGIBLE_COUNT
         || field_name==ISSX_FIELD_NEWLY_ACTIVE_SYMBOLS_WAITING_COUNT
         || field_name==ISSX_FIELD_NEAR_CUTLINE_RECHECK_AGE_MAX
         || field_name==ISSX_FIELD_TRADABILITY_NOW_CLASS
         || field_name==ISSX_FIELD_BROKER_UNIVERSE_FINGERPRINT
         || field_name==ISSX_FIELD_ELIGIBLE_UNIVERSE_FINGERPRINT
         || field_name==ISSX_FIELD_ACTIVE_UNIVERSE_FINGERPRINT
         || field_name==ISSX_FIELD_RANKABLE_UNIVERSE_FINGERPRINT
         || field_name==ISSX_FIELD_FRONTIER_UNIVERSE_FINGERPRINT
         || field_name==ISSX_FIELD_PUBLISHABLE_UNIVERSE_FINGERPRINT)
         return issx_stage_ea1;

      return issx_stage_shared;
     }

   string InferSemanticType(const string field_name) const
     {
      if(StringEndsWith(field_name,"_flag"))
         return "bool";
      if(StringEndsWith(field_name,"_count")
         || StringEndsWith(field_name,"_depth")
         || StringEndsWith(field_name,"_bars")
         || field_name==ISSX_FIELD_SEQUENCE_NO
         || field_name==ISSX_FIELD_DUMP_SEQUENCE_NO
         || field_name==ISSX_FIELD_HANDOFF_SEQUENCE_NO
         || field_name=="sample_count")
         return "int";
      if(StringEndsWith(field_name,"_pct")
         || StringEndsWith(field_name,"_ratio")
         || StringEndsWith(field_name,"_score")
         || StringEndsWith(field_name,"_efficiency")
         || StringContains(field_name,"_ratio_"))
         return "double";
      if(StringEndsWith(field_name,"_ms"))
         return "int64";
      if(StringEndsWith(field_name,"_sec"))
         return "int";
      if(IsFingerprintOrHashField(field_name))
         return "hash_hex";
      if(StringContains(field_name,"ids"))
         return "compact_id_list";
      if(IsSummaryField(field_name))
         return "summary_string";
      if(StringContains(field_name,"_class")
         || StringContains(field_name,"_state")
         || StringContains(field_name,"_reason")
         || StringContains(field_name,"_mode")
         || field_name==ISSX_FIELD_CONTENT_CLASS
         || field_name==ISSX_FIELD_COMPATIBILITY_CLASS
         || field_name==ISSX_FIELD_PUBLISH_REASON)
         return "enum_string";
      return "string";
     }

   string InferUnit(const string field_name) const
     {
      if(StringEndsWith(field_name,"_pct"))
         return "pct";
      if(StringEndsWith(field_name,"_ms"))
         return "ms";
      if(StringEndsWith(field_name,"_sec"))
         return "sec";
      if(StringEndsWith(field_name,"_bars"))
         return "bars";
      if(StringEndsWith(field_name,"_count") || StringEndsWith(field_name,"_depth"))
         return "count";
      return "";
     }

   int InferPrecision(const string field_name) const
     {
      if(StringEndsWith(field_name,"_pct"))
         return 2;
      if(StringEndsWith(field_name,"_ratio")
         || StringContains(field_name,"_ratio_")
         || StringEndsWith(field_name,"_efficiency")
         || StringEndsWith(field_name,"_score"))
         return 4;
      return 0;
     }

   bool InferAllowedNull(const string field_name) const
     {
      if(IsSummaryField(field_name)
         || StringContains(field_name,"limitation")
         || StringContains(field_name,"reason")
         || IsOptionalContextField(field_name))
         return true;
      return false;
     }

   ISSX_MissingPolicy InferMissingPolicy(const string field_name) const
     {
      if(IsSummaryField(field_name)
         || StringContains(field_name,"limitation")
         || StringStartsWith(field_name,"why_"))
         return issx_missing_ignore;

      if(StringStartsWith(field_name,"pair_")
         || field_name==ISSX_FIELD_DIVERSIFICATION_CONFIDENCE_CLASS
         || field_name==ISSX_FIELD_REDUNDANCY_RISK_CLASS
         || field_name==ISSX_FIELD_UPSTREAM_HANDOFF_MODE
         || field_name==ISSX_FIELD_SOURCE_SNAPSHOT_KIND
         || IsOptionalContextField(field_name))
         return issx_missing_unknown;

      return issx_missing_error;
     }

   ISSX_StalePolicy InferStalePolicy(const string field_name) const
     {
      if(IsDebugField(field_name))
         return issx_stale_not_time_sensitive;
      if(IsHistoryOrWarehouseField(field_name))
         return issx_stale_degrade_after_threshold;
      if(StringStartsWith(field_name,"pair_"))
         return issx_stale_degrade_after_threshold;
      if(StringContains(field_name,"quote_") || field_name==ISSX_FIELD_WINNER_QUOTE_AGE_SEC)
         return issx_stale_invalidate_after_threshold;
      if(StringContains(field_name,"rank_") || StringContains(field_name,"refresh_age"))
         return issx_stale_degrade_after_threshold;
      return issx_stale_valid_until_threshold;
     }

   ISSX_DirectOrDerived InferDirectOrDerived(const string field_name) const
     {
      if(IsHistoryOrWarehouseField(field_name)
         || StringContains(field_name,"regime")
         || StringContains(field_name,"quality")
         || StringContains(field_name,"efficiency")
         || StringContains(field_name,"confidence")
         || StringContains(field_name,"risk")
         || StringContains(field_name,"summary")
         || field_name==ISSX_FIELD_RANKABILITY_LANE
         || field_name==ISSX_FIELD_EXPLORATORY_PENALTY_APPLIED
         || field_name=="sample_count")
         return issx_derived_field;
      return issx_direct_field;
     }

   ISSX_AuthorityLevel InferAuthorityLevel(const string field_name) const
     {
      if(IsDebugField(field_name))
         return issx_authority_advisory;

      if(field_name==ISSX_FIELD_WHY_EXPORT_IS_THIN
         || field_name==ISSX_FIELD_WHY_PUBLISH_IS_STALE
         || field_name==ISSX_FIELD_WHY_FRONTIER_IS_SMALL
         || field_name==ISSX_FIELD_WHY_INTELLIGENCE_ABSTAINED
         || field_name==ISSX_FIELD_REGIME_SUMMARY
         || field_name==ISSX_FIELD_EXECUTION_CONDITION_SUMMARY
         || field_name==ISSX_FIELD_DIVERSIFICATION_CONTEXT_SUMMARY)
         return issx_authority_advisory;

      if(IsSummaryField(field_name))
         return issx_authority_derived;

      return issx_authority_validated;
     }

   string InferProjectionPolicy(const string field_name) const
     {
      if(IsDebugField(field_name))
         return "debug_only";
      if(StringStartsWith(field_name,"winner_")
         || StringStartsWith(field_name,"selection_")
         || field_name==ISSX_FIELD_REGIME_SUMMARY
         || field_name==ISSX_FIELD_EXECUTION_CONDITION_SUMMARY
         || field_name==ISSX_FIELD_DIVERSIFICATION_CONTEXT_SUMMARY)
         return "ea5_export";
      if(field_name==ISSX_FIELD_LOCK_OWNER_BOOT_ID
         || field_name==ISSX_FIELD_LOCK_OWNER_INSTANCE_GUID
         || field_name==ISSX_FIELD_LOCK_OWNER_TERMINAL_IDENTITY
         || field_name==ISSX_FIELD_LOCK_ACQUIRED_TIME
         || field_name==ISSX_FIELD_LOCK_HEARTBEAT_TIME
         || field_name==ISSX_FIELD_STALE_AFTER_SEC)
         return "internal_only";
      return "internal_and_debug";
     }

   string InferConsumerWarning(const string field_name) const
     {
      if(field_name==ISSX_FIELD_PAIR_VALIDITY_CLASS
         || field_name==ISSX_FIELD_PAIR_SAMPLE_ALIGNMENT_CLASS
         || field_name==ISSX_FIELD_PAIR_WINDOW_FRESHNESS_CLASS
         || field_name=="pair_regime_comparability_class")
         return "Pair metrics are invalid without validity context.";

      if(field_name==ISSX_FIELD_RANKABILITY_LANE || field_name==ISSX_FIELD_EXPLORATORY_PENALTY_APPLIED)
         return "Exploratory participation must remain visibly weaker than strong lane truth.";

      if(field_name==ISSX_FIELD_WAREHOUSE_CLIP_FLAG
         || field_name==ISSX_FIELD_EFFECTIVE_LOOKBACK_BARS
         || field_name==ISSX_FIELD_WARMUP_SUFFICIENT_FLAG)
         return "Metrics near retention or warmup limits must not present as high confidence.";

      if(field_name==ISSX_FIELD_SELECTION_REASON_SUMMARY
         || field_name==ISSX_FIELD_SELECTION_PENALTY_SUMMARY
         || field_name==ISSX_FIELD_WINNER_LIMITATION_SUMMARY
         || field_name==ISSX_FIELD_REGIME_SUMMARY
         || field_name==ISSX_FIELD_EXECUTION_CONDITION_SUMMARY
         || field_name==ISSX_FIELD_DIVERSIFICATION_CONTEXT_SUMMARY)
         return "Summary text must stay deterministic, factual, and non-directional.";

      if(field_name==ISSX_FIELD_POLICY_FINGERPRINT)
         return "Consumer-sensitive compatibility must check policy fingerprint, not schema alone.";

      if(field_name==ISSX_FIELD_TRADABILITY_NOW_CLASS)
         return "Unknown tradeability must not present as cheapness or usability.";

      if(field_name==ISSX_FIELD_DIVERSIFICATION_CONFIDENCE_CLASS
         || field_name==ISSX_FIELD_REDUNDANCY_RISK_CLASS)
         return "Unknown diversification must never masquerade as safe diversity.";

      return "";
     }

   bool InferCacheProvenanceRequired(const string field_name) const
     {
      return IsHistoryOrWarehouseField(field_name)
          || StringStartsWith(field_name,"pair_")
          || field_name==ISSX_FIELD_EFFECTIVE_LOOKBACK_BARS
          || field_name==ISSX_FIELD_WARMUP_SUFFICIENT_FLAG
          || field_name=="sample_count"
          || field_name=="pair_regime_comparability_class";
     }

   bool InferContinuityDerived(const string field_name) const
     {
      return StringStartsWith(field_name,"fallback_")
          || StringStartsWith(field_name,"same_tick_")
          || field_name==ISSX_FIELD_FRESH_ACCEPT_RATIO_1H;
     }

   bool InferNonDirectional(const string field_name) const
     {
      return field_name==ISSX_FIELD_INTRADAY_ACTIVITY_STATE
          || field_name==ISSX_FIELD_LIQUIDITY_REGIME_CLASS
          || field_name==ISSX_FIELD_VOLATILITY_REGIME_CLASS
          || field_name==ISSX_FIELD_EXPANSION_STATE_CLASS
          || field_name==ISSX_FIELD_MOVEMENT_QUALITY_CLASS
          || field_name==ISSX_FIELD_MOVEMENT_MATURITY_CLASS
          || field_name==ISSX_FIELD_SESSION_PHASE_CLASS
          || field_name==ISSX_FIELD_TRADABILITY_NOW_CLASS
          || field_name==ISSX_FIELD_HOLDING_HORIZON_CONTEXT
          || field_name==ISSX_FIELD_CONSTRUCTABILITY_CLASS
          || field_name==ISSX_FIELD_MOVEMENT_TO_COST_EFFICIENCY_CLASS
          || field_name==ISSX_FIELD_DIVERSIFICATION_CONFIDENCE_CLASS
          || field_name==ISSX_FIELD_REDUNDANCY_RISK_CLASS
          || field_name==ISSX_FIELD_OPPORTUNITY_WITH_CAUTION_FLAG
          || field_name==ISSX_FIELD_EARLY_MOVE_QUALITY_CLASS
          || field_name==ISSX_FIELD_SELECTION_REASON_SUMMARY
          || field_name==ISSX_FIELD_SELECTION_PENALTY_SUMMARY
          || field_name==ISSX_FIELD_WINNER_LIMITATION_SUMMARY
          || field_name==ISSX_FIELD_REGIME_SUMMARY
          || field_name==ISSX_FIELD_EXECUTION_CONDITION_SUMMARY
          || field_name==ISSX_FIELD_DIVERSIFICATION_CONTEXT_SUMMARY
          || field_name=="microstructure_noise_class"
          || field_name=="range_efficiency_class"
          || field_name=="noise_to_range_ratio"
          || field_name=="bar_overlap_class"
          || field_name=="directional_persistence_class"
          || field_name=="two_way_rotation_class"
          || field_name=="gap_disruption_class"
          || field_name=="recent_compression_expansion_ratio"
          || field_name=="winner_archetype_class";
     }

   string InferRuntimeStateKind(const string field_name) const
     {
      if(StringContains(field_name,"_class")
         || StringContains(field_name,"_state")
         || StringContains(field_name,"_reason")
         || StringContains(field_name,"_mode")
         || field_name==ISSX_FIELD_CONTENT_CLASS
         || field_name==ISSX_FIELD_COMPATIBILITY_CLASS
         || field_name==ISSX_FIELD_PUBLISH_REASON)
         return "enum_state";
      if(StringEndsWith(field_name,"_flag"))
         return "boolean_state";
      if(StringEndsWith(field_name,"_count")
         || StringEndsWith(field_name,"_depth")
         || StringEndsWith(field_name,"_bars"))
         return "counter_state";
      if(StringEndsWith(field_name,"_pct")
         || StringEndsWith(field_name,"_ratio")
         || StringEndsWith(field_name,"_score")
         || StringEndsWith(field_name,"_efficiency"))
         return "scalar_state";
      return "value_state";
     }

   string DirectOrDerivedToString(const ISSX_DirectOrDerived v) const
     {
      switch(v)
        {
         case issx_direct_field:  return "direct";
         case issx_derived_field: return "derived";
         default:                 return "unknown";
        }
     }

public:
   void Reset()
     {
      ArrayResize(m_items,0);
     }

   int Count() const
     {
      return ArraySize(m_items);
     }

   bool Exists(const string field_name) const
     {
      for(int i=0;i<ArraySize(m_items);i++)
         if(m_items[i].field_name==field_name)
            return true;
      return false;
     }

   int IndexOf(const string field_name) const
     {
      for(int i=0;i<ArraySize(m_items);i++)
         if(m_items[i].field_name==field_name)
            return i;
      return -1;
     }

   bool Add(const ISSX_FieldMetadataEntry &entry)
     {
      const int n=ArraySize(m_items);
      if(ISSX_Util::IsEmpty(entry.field_name))
         return false;
      if(!ISSX_Enum::StageIsValid(entry.owner_ea))
         return false;
      if(Exists(entry.field_name))
         return false;
      if(ArrayResize(m_items,n+1)!=(n+1))
         return false;
      m_items[n]=entry;
      return true;
     }

   bool AddField(const string field_name,
                 const ISSX_StageId owner_ea,
                 const string semantic_type,
                 const string unit,
                 const int precision,
                 const bool allowed_null,
                 const ISSX_MissingPolicy missing_policy,
                 const ISSX_StalePolicy stale_policy,
                 const ISSX_DirectOrDerived direct_or_derived,
                 const ISSX_AuthorityLevel authority_level,
                 const string projection_policy,
                 const string consumer_warning,
                 const bool cache_provenance_required,
                 const bool continuity_derived,
                 const bool non_directional,
                 const string runtime_state_kind)
     {
      ISSX_FieldMetadataEntry e;
      e.Reset();
      e.field_name=field_name;
      e.owner_ea=owner_ea;
      e.semantic_type=semantic_type;
      e.unit=unit;
      e.precision=precision;
      e.allowed_null=allowed_null;
      e.missing_policy=missing_policy;
      e.stale_policy=stale_policy;
      e.direct_or_derived=direct_or_derived;
      e.authority_level=authority_level;
      e.projection_policy=projection_policy;
      e.consumer_warning=consumer_warning;
      e.cache_provenance_required=cache_provenance_required;
      e.continuity_derived=continuity_derived;
      e.non_directional=non_directional;
      e.runtime_state_kind=runtime_state_kind;
      return Add(e);
     }

   bool RegisterBlueprintField(const string field_name)
     {
      return AddField(field_name,
                      InferOwner(field_name),
                      InferSemanticType(field_name),
                      InferUnit(field_name),
                      InferPrecision(field_name),
                      InferAllowedNull(field_name),
                      InferMissingPolicy(field_name),
                      InferStalePolicy(field_name),
                      InferDirectOrDerived(field_name),
                      InferAuthorityLevel(field_name),
                      InferProjectionPolicy(field_name),
                      InferConsumerWarning(field_name),
                      InferCacheProvenanceRequired(field_name),
                      InferContinuityDerived(field_name),
                      InferNonDirectional(field_name),
                      InferRuntimeStateKind(field_name));
     }

   bool Lookup(const string field_name,ISSX_FieldMetadataEntry &out_entry) const
     {
      const int idx=IndexOf(field_name);
      if(idx<0)
         return false;
      out_entry=m_items[idx];
      return true;
     }

      ISSX_ValidationResult Validate() const
     {
      for(int i=0;i<ArraySize(m_items);i++)
        {
         if(ISSX_Util::IsEmpty(m_items[i].field_name))
            return ISSX_Validate::Fail(2001,"field_name empty");
         if(!ISSX_Enum::StageIsValid(m_items[i].owner_ea))
            return ISSX_Validate::Fail(2002,"owner_ea invalid");
         if(ISSX_Util::IsEmpty(m_items[i].semantic_type))
            return ISSX_Validate::Fail(2003,"semantic_type empty");
         if(ISSX_Util::IsEmpty(m_items[i].projection_policy))
            return ISSX_Validate::Fail(2004,"projection_policy empty");
         if(ISSX_Util::IsEmpty(m_items[i].runtime_state_kind))
            return ISSX_Validate::Fail(2005,"runtime_state_kind empty");
         if(m_items[i].stale_policy==issx_stale_policy_unknown)
            return ISSX_Validate::Fail(2006,"stale_policy unknown");
         if(m_items[i].authority_level==issx_authority_advisory
            && m_items[i].direct_or_derived==issx_direct_field
            && !IsDebugField(m_items[i].field_name))
            return ISSX_Validate::Fail(2007,"advisory field may not be direct factual market truth");
         if(IsHistoryOrWarehouseField(m_items[i].field_name)
            && !m_items[i].cache_provenance_required)
            return ISSX_Validate::Fail(2008,"warehouse/history field missing cache provenance");
        }
      return ISSX_Validate::Ok();
     }

   string FingerprintHex() const
     {
      return ISSX_Hash::HashStringHex(ExportCompactJson());
     }

   string ExportCompactJson() const
     {
      int order[];
      BuildSortedIndices(order);

      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginArray();
      for(int k=0;k<ArraySize(order);k++)
        {
         const int i=order[k];
         jw.BeginObject();
         jw.NameString("field_name",m_items[i].field_name);
         jw.NameString("owner_ea",ISSX_Enum::StageToString(m_items[i].owner_ea));
         jw.NameString("semantic_type",m_items[i].semantic_type);
         jw.NameString("unit",m_items[i].unit);
         jw.NameInt("precision",(long)m_items[i].precision);
         jw.NameBool("allowed_null",m_items[i].allowed_null);
         jw.NameString("missing_policy",MissingPolicyToString(m_items[i].missing_policy));
         jw.NameString("stale_policy",StalePolicyToString(m_items[i].stale_policy));
         jw.NameString("direct_or_derived",DirectOrDerivedToString(m_items[i].direct_or_derived));
         jw.NameString("authority_level",ISSX_Enum::AuthorityLevelToString(m_items[i].authority_level));
         jw.NameString("projection_policy",m_items[i].projection_policy);
         jw.NameString("consumer_warning",m_items[i].consumer_warning);
         jw.NameBool("cache_provenance_required",m_items[i].cache_provenance_required);
         jw.NameBool("continuity_derived",m_items[i].continuity_derived);
         jw.NameBool("non_directional",m_items[i].non_directional);
         jw.NameString("runtime_state_kind",m_items[i].runtime_state_kind);
         jw.EndObject();
        }
      jw.EndArray();
      return jw.ToString();
     }

   void SeedBlueprintV172()
     {
      Reset();

      RegisterBlueprintField(ISSX_FIELD_STAGE_MINIMUM_READY_FLAG);
      RegisterBlueprintField(ISSX_FIELD_STAGE_PUBLISHABILITY_STATE);
      RegisterBlueprintField(ISSX_FIELD_UPSTREAM_HANDOFF_MODE);
      RegisterBlueprintField(ISSX_FIELD_UPSTREAM_HANDOFF_SAME_TICK_FLAG);
      RegisterBlueprintField(ISSX_FIELD_UPSTREAM_PARTIAL_PROGRESS_FLAG);
      RegisterBlueprintField(ISSX_FIELD_WAREHOUSE_QUALITY);
      RegisterBlueprintField(ISSX_FIELD_WAREHOUSE_RETAINED_BAR_COUNT);
      RegisterBlueprintField(ISSX_FIELD_DUMP_SEQUENCE_NO);
      RegisterBlueprintField(ISSX_FIELD_DUMP_MINUTE_ID);
      RegisterBlueprintField(ISSX_FIELD_DEBUG_WEAK_LINK_CODE);
      RegisterBlueprintField(ISSX_FIELD_DEPENDENCY_BLOCK_REASON);
      RegisterBlueprintField(ISSX_FIELD_KERNEL_DEGRADED_CYCLE_FLAG);
      RegisterBlueprintField(ISSX_FIELD_FALLBACK_READ_RATIO_1H);
      RegisterBlueprintField(ISSX_FIELD_SAME_TICK_HANDOFF_RATIO_1H);
      RegisterBlueprintField(ISSX_FIELD_FRESH_ACCEPT_RATIO_1H);
      RegisterBlueprintField(ISSX_FIELD_POLICY_FINGERPRINT);
      RegisterBlueprintField(ISSX_FIELD_FINGERPRINT_ALGO_VERSION);
      RegisterBlueprintField(ISSX_FIELD_CONTRADICTION_CLASS_COUNTS);
      RegisterBlueprintField(ISSX_FIELD_HIGHEST_BLOCKING_CONTRADICTION_CLASS);
      RegisterBlueprintField(ISSX_FIELD_CONTRADICTION_REPAIR_STATE);
      RegisterBlueprintField(ISSX_FIELD_COVERAGE_RANKABLE_RECENT_PCT);
      RegisterBlueprintField(ISSX_FIELD_COVERAGE_FRONTIER_RECENT_PCT);
      RegisterBlueprintField(ISSX_FIELD_HISTORY_DEEP_COMPLETION_PCT);
      RegisterBlueprintField(ISSX_FIELD_WINNER_CACHE_DEPENDENCE_PCT);
      RegisterBlueprintField(ISSX_FIELD_CLOCK_DIVERGENCE_SEC);
      RegisterBlueprintField(ISSX_FIELD_SCHEDULER_LATE_BY_MS);
      RegisterBlueprintField(ISSX_FIELD_MISSED_SCHEDULE_WINDOWS_ESTIMATE);
      RegisterBlueprintField(ISSX_FIELD_PAIR_VALIDITY_CLASS);
      RegisterBlueprintField(ISSX_FIELD_PAIR_SAMPLE_ALIGNMENT_CLASS);
      RegisterBlueprintField(ISSX_FIELD_PAIR_WINDOW_FRESHNESS_CLASS);
      RegisterBlueprintField(ISSX_FIELD_WAREHOUSE_CLIP_FLAG);
      RegisterBlueprintField(ISSX_FIELD_WARMUP_SUFFICIENT_FLAG);
      RegisterBlueprintField(ISSX_FIELD_EFFECTIVE_LOOKBACK_BARS);
      RegisterBlueprintField(ISSX_FIELD_RANKABILITY_LANE);
      RegisterBlueprintField(ISSX_FIELD_EXPLORATORY_PENALTY_APPLIED);
      RegisterBlueprintField(ISSX_FIELD_INTRADAY_ACTIVITY_STATE);
      RegisterBlueprintField(ISSX_FIELD_LIQUIDITY_REGIME_CLASS);
      RegisterBlueprintField(ISSX_FIELD_VOLATILITY_REGIME_CLASS);
      RegisterBlueprintField(ISSX_FIELD_EXPANSION_STATE_CLASS);
      RegisterBlueprintField(ISSX_FIELD_MOVEMENT_QUALITY_CLASS);
      RegisterBlueprintField(ISSX_FIELD_MOVEMENT_MATURITY_CLASS);
      RegisterBlueprintField(ISSX_FIELD_SESSION_PHASE_CLASS);
      RegisterBlueprintField(ISSX_FIELD_TRADABILITY_NOW_CLASS);
      RegisterBlueprintField(ISSX_FIELD_HOLDING_HORIZON_CONTEXT);
      RegisterBlueprintField(ISSX_FIELD_CONSTRUCTABILITY_CLASS);
      RegisterBlueprintField(ISSX_FIELD_DIVERSIFICATION_CONFIDENCE_CLASS);
      RegisterBlueprintField(ISSX_FIELD_REDUNDANCY_RISK_CLASS);
      RegisterBlueprintField(ISSX_FIELD_SELECTION_REASON_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_SELECTION_PENALTY_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_WINNER_LIMITATION_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_WINNER_CONFIDENCE_CLASS);
      RegisterBlueprintField(ISSX_FIELD_OPPORTUNITY_WITH_CAUTION_FLAG);
      RegisterBlueprintField(ISSX_FIELD_EARLY_MOVE_QUALITY_CLASS);
      RegisterBlueprintField(ISSX_FIELD_MOVEMENT_TO_COST_EFFICIENCY_CLASS);

      RegisterBlueprintField(ISSX_FIELD_BROKER_UNIVERSE_FINGERPRINT);
      RegisterBlueprintField(ISSX_FIELD_ELIGIBLE_UNIVERSE_FINGERPRINT);
      RegisterBlueprintField(ISSX_FIELD_ACTIVE_UNIVERSE_FINGERPRINT);
      RegisterBlueprintField(ISSX_FIELD_RANKABLE_UNIVERSE_FINGERPRINT);
      RegisterBlueprintField(ISSX_FIELD_FRONTIER_UNIVERSE_FINGERPRINT);
      RegisterBlueprintField(ISSX_FIELD_PUBLISHABLE_UNIVERSE_FINGERPRINT);
      RegisterBlueprintField(ISSX_FIELD_CHANGED_SYMBOL_COUNT);
      RegisterBlueprintField(ISSX_FIELD_CHANGED_SYMBOL_IDS);
      RegisterBlueprintField(ISSX_FIELD_CHANGED_FAMILY_COUNT);
      RegisterBlueprintField(ISSX_FIELD_CHANGED_BUCKET_COUNT);
      RegisterBlueprintField(ISSX_FIELD_CHANGED_FRONTIER_COUNT);
      RegisterBlueprintField(ISSX_FIELD_CHANGED_TIMEFRAME_COUNT);
      RegisterBlueprintField(ISSX_FIELD_PERCENT_UNIVERSE_TOUCHED_RECENT);
      RegisterBlueprintField(ISSX_FIELD_PERCENT_RANKABLE_REVALIDATED_RECENT);
      RegisterBlueprintField(ISSX_FIELD_PERCENT_FRONTIER_REVALIDATED_RECENT);
      RegisterBlueprintField(ISSX_FIELD_NEVER_SERVICED_COUNT);
      RegisterBlueprintField(ISSX_FIELD_OVERDUE_SERVICE_COUNT);
      RegisterBlueprintField(ISSX_FIELD_NEVER_RANKED_BUT_ELIGIBLE_COUNT);
      RegisterBlueprintField(ISSX_FIELD_NEWLY_ACTIVE_SYMBOLS_WAITING_COUNT);
      RegisterBlueprintField(ISSX_FIELD_NEAR_CUTLINE_RECHECK_AGE_MAX);

      RegisterBlueprintField(ISSX_FIELD_MINUTE_EPOCH_SOURCE);
      RegisterBlueprintField(ISSX_FIELD_SCHEDULER_CLOCK_SOURCE);
      RegisterBlueprintField(ISSX_FIELD_FRESHNESS_CLOCK_SOURCE);
      RegisterBlueprintField(ISSX_FIELD_TIMER_GAP_MS_NOW);
      RegisterBlueprintField(ISSX_FIELD_TIMER_GAP_MS_MEAN);
      RegisterBlueprintField(ISSX_FIELD_TIMER_GAP_MS_P95);
      RegisterBlueprintField(ISSX_FIELD_QUOTE_CLOCK_IDLE_FLAG);
      RegisterBlueprintField(ISSX_FIELD_CLOCK_SANITY_SCORE);
      RegisterBlueprintField(ISSX_FIELD_CLOCK_ANOMALY_FLAG);
      RegisterBlueprintField(ISSX_FIELD_TIME_PENALTY_APPLIED);
      RegisterBlueprintField(ISSX_FIELD_KERNEL_MINUTE_ID);
      RegisterBlueprintField(ISSX_FIELD_SCHEDULER_CYCLE_NO);
      RegisterBlueprintField(ISSX_FIELD_CURRENT_STAGE_SLOT);
      RegisterBlueprintField(ISSX_FIELD_CURRENT_STAGE_PHASE);
      RegisterBlueprintField(ISSX_FIELD_CURRENT_STAGE_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_CURRENT_STAGE_DEADLINE_MS);
      RegisterBlueprintField(ISSX_FIELD_STAGE_LAST_RUN_MS);
      RegisterBlueprintField(ISSX_FIELD_STAGE_LAST_PUBLISH_MINUTE_ID);
      RegisterBlueprintField(ISSX_FIELD_STAGE_PUBLISH_DUE_FLAG);
      RegisterBlueprintField(ISSX_FIELD_STAGE_BACKLOG_SCORE);
      RegisterBlueprintField(ISSX_FIELD_STAGE_STARVATION_SCORE);
      RegisterBlueprintField(ISSX_FIELD_STAGE_DEPENDENCY_BLOCK_REASON);
      RegisterBlueprintField(ISSX_FIELD_STAGE_RESUME_KEY);
      RegisterBlueprintField(ISSX_FIELD_STAGE_LAST_SUCCESS_SERVICE_MONO_MS);
      RegisterBlueprintField(ISSX_FIELD_STAGE_LAST_ATTEMPT_SERVICE_MONO_MS);
      RegisterBlueprintField(ISSX_FIELD_STAGE_MISSED_DUE_CYCLES);
      RegisterBlueprintField(ISSX_FIELD_KERNEL_BUDGET_TOTAL_MS);
      RegisterBlueprintField(ISSX_FIELD_KERNEL_BUDGET_SPENT_MS);
      RegisterBlueprintField(ISSX_FIELD_KERNEL_BUDGET_RESERVED_COMMIT_MS);
      RegisterBlueprintField(ISSX_FIELD_KERNEL_BUDGET_DEBT_MS);
      RegisterBlueprintField(ISSX_FIELD_KERNEL_FORCED_SERVICE_DUE_FLAG);
      RegisterBlueprintField(ISSX_FIELD_KERNEL_OVERRUN_CLASS);
      RegisterBlueprintField(ISSX_FIELD_DISCOVERY_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_PROBE_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_QUOTE_SAMPLING_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_HISTORY_WARM_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_HISTORY_DEEP_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_PAIR_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_CACHE_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_PERSISTENCE_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_PUBLISH_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_DEBUG_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_FRESHNESS_FASTLANE_BUDGET_MS);
      RegisterBlueprintField(ISSX_FIELD_DISCOVERY_CURSOR);
      RegisterBlueprintField(ISSX_FIELD_SPEC_PROBE_CURSOR);
      RegisterBlueprintField(ISSX_FIELD_RUNTIME_SAMPLE_CURSOR);
      RegisterBlueprintField(ISSX_FIELD_HISTORY_WARM_CURSOR);
      RegisterBlueprintField(ISSX_FIELD_HISTORY_DEEP_CURSOR);
      RegisterBlueprintField(ISSX_FIELD_BUCKET_REBUILD_CURSOR);
      RegisterBlueprintField(ISSX_FIELD_PAIR_QUEUE_CURSOR);
      RegisterBlueprintField(ISSX_FIELD_REPAIR_CURSOR);
      RegisterBlueprintField(ISSX_FIELD_ROTATION_WINDOW_ESTIMATED_CYCLES);
      RegisterBlueprintField(ISSX_FIELD_DEEP_BACKLOG_REMAINING);
      RegisterBlueprintField(ISSX_FIELD_SECTOR_COLD_BACKLOG_COUNT);

      RegisterBlueprintField(ISSX_FIELD_WEAKEST_STAGE);
      RegisterBlueprintField(ISSX_FIELD_WEAKEST_STAGE_REASON);
      RegisterBlueprintField(ISSX_FIELD_WEAK_LINK_SEVERITY);
      RegisterBlueprintField(ISSX_FIELD_ERROR_WEIGHT);
      RegisterBlueprintField(ISSX_FIELD_DEGRADE_WEIGHT);
      RegisterBlueprintField(ISSX_FIELD_DEPENDENCY_WEIGHT);
      RegisterBlueprintField(ISSX_FIELD_FALLBACK_WEIGHT);
      RegisterBlueprintField(ISSX_FIELD_FRONTIER_REFRESH_LAG_FOR_NEW_MOVERS);
      RegisterBlueprintField(ISSX_FIELD_SELECTION_LATENCY_RISK_CLASS);
      RegisterBlueprintField(ISSX_FIELD_NEVER_RANKED_BUT_NOW_OBSERVABLE_COUNT);
      RegisterBlueprintField(ISSX_FIELD_LARGEST_BACKLOG_OWNER);
      RegisterBlueprintField(ISSX_FIELD_OLDEST_UNSERVED_QUEUE_FAMILY);

      RegisterBlueprintField(ISSX_FIELD_EXPORT_GENERATED_AT);
      RegisterBlueprintField(ISSX_FIELD_EA1_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_EA2_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_EA3_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_EA4_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_SOURCE_GENERATION_IDS);
      RegisterBlueprintField(ISSX_FIELD_WINNER_HISTORY_AGE_BY_TF);
      RegisterBlueprintField(ISSX_FIELD_WINNER_QUOTE_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_WINNER_TRADEABILITY_REFRESH_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_WINNER_RANK_REFRESH_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_WINNER_REGIME_REFRESH_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_WINNER_CORR_REFRESH_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_WINNER_LAST_MATERIAL_CHANGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_REGIME_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_EXECUTION_CONDITION_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_DIVERSIFICATION_CONTEXT_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_WHY_EXPORT_IS_THIN);
      RegisterBlueprintField(ISSX_FIELD_WHY_PUBLISH_IS_STALE);
      RegisterBlueprintField(ISSX_FIELD_WHY_FRONTIER_IS_SMALL);
      RegisterBlueprintField(ISSX_FIELD_WHY_INTELLIGENCE_ABSTAINED);

      RegisterBlueprintField(ISSX_FIELD_STAGE_API_VERSION);
      RegisterBlueprintField(ISSX_FIELD_SERIALIZER_VERSION);
      RegisterBlueprintField(ISSX_FIELD_WRITER_CODEPAGE);
      RegisterBlueprintField(ISSX_FIELD_SOURCE_SNAPSHOT_KIND);
      RegisterBlueprintField(ISSX_FIELD_RESUME_COMPATIBILITY_CLASS);
      RegisterBlueprintField(ISSX_FIELD_OWNER_MODULE_NAME);
      RegisterBlueprintField(ISSX_FIELD_OWNER_MODULE_HASH);
      RegisterBlueprintField(ISSX_FIELD_OWNER_MODULE_HASH_MEANING_VERSION);
      RegisterBlueprintField(ISSX_FIELD_ACCEPTED_PROMOTION_VERIFIED);
      RegisterBlueprintField(ISSX_FIELD_PROJECTION_PARTIAL_SUCCESS_FLAG);
      RegisterBlueprintField(ISSX_FIELD_HANDOFF_SEQUENCE_NO);
      RegisterBlueprintField(ISSX_FIELD_HANDOFF_MODE);
      RegisterBlueprintField(ISSX_FIELD_LEGEND_HASH);
      RegisterBlueprintField(ISSX_FIELD_COMPATIBILITY_CLASS);
      RegisterBlueprintField(ISSX_FIELD_CONTENT_CLASS);
      RegisterBlueprintField(ISSX_FIELD_PUBLISH_REASON);
      RegisterBlueprintField(ISSX_FIELD_UNIVERSE_FINGERPRINT);
      RegisterBlueprintField(ISSX_FIELD_TAXONOMY_HASH);
      RegisterBlueprintField(ISSX_FIELD_COMPARATOR_REGISTRY_HASH);
      RegisterBlueprintField(ISSX_FIELD_COHORT_FINGERPRINT);
      RegisterBlueprintField(ISSX_FIELD_TRIO_GENERATION_ID);
      RegisterBlueprintField(ISSX_FIELD_PAYLOAD_HASH);
      RegisterBlueprintField(ISSX_FIELD_HEADER_HASH);
      RegisterBlueprintField(ISSX_FIELD_PAYLOAD_LENGTH);
      RegisterBlueprintField(ISSX_FIELD_HEADER_LENGTH);
      RegisterBlueprintField(ISSX_FIELD_SYMBOL_COUNT);
      RegisterBlueprintField(ISSX_FIELD_MINUTE_ID);
      RegisterBlueprintField(ISSX_FIELD_SEQUENCE_NO);
      RegisterBlueprintField(ISSX_FIELD_WRITER_GENERATION);
      RegisterBlueprintField(ISSX_FIELD_WRITER_BOOT_ID);
      RegisterBlueprintField(ISSX_FIELD_WRITER_NONCE);
      RegisterBlueprintField(ISSX_FIELD_FIRM_ID);
      RegisterBlueprintField(ISSX_FIELD_STAGE_ID);
      RegisterBlueprintField(ISSX_FIELD_SCHEMA_VERSION);
      RegisterBlueprintField(ISSX_FIELD_SCHEMA_EPOCH);
      RegisterBlueprintField(ISSX_FIELD_STORAGE_VERSION);

      RegisterBlueprintField(ISSX_FIELD_LOCK_OWNER_BOOT_ID);
      RegisterBlueprintField(ISSX_FIELD_LOCK_OWNER_INSTANCE_GUID);
      RegisterBlueprintField(ISSX_FIELD_LOCK_OWNER_TERMINAL_IDENTITY);
      RegisterBlueprintField(ISSX_FIELD_LOCK_ACQUIRED_TIME);
      RegisterBlueprintField(ISSX_FIELD_LOCK_HEARTBEAT_TIME);
      RegisterBlueprintField(ISSX_FIELD_STALE_AFTER_SEC);

      RegisterBlueprintField("microstructure_noise_class");
      RegisterBlueprintField("range_efficiency_class");
      RegisterBlueprintField("noise_to_range_ratio");
      RegisterBlueprintField("bar_overlap_class");
      RegisterBlueprintField("directional_persistence_class");
      RegisterBlueprintField("two_way_rotation_class");
      RegisterBlueprintField("gap_disruption_class");
      RegisterBlueprintField("recent_compression_expansion_ratio");
      RegisterBlueprintField("finality_state");
      RegisterBlueprintField("rewrite_class");

      RegisterBlueprintField("bucket_depth_strong");
      RegisterBlueprintField("bucket_depth_compare_safe");
      RegisterBlueprintField("bucket_depth_degraded");
      RegisterBlueprintField("bucket_confidence_class");
      RegisterBlueprintField("bucket_instability_reason");
      RegisterBlueprintField("bucket_opportunity_density");
      RegisterBlueprintField("bucket_redundancy_state");
      RegisterBlueprintField("bucket_primary_thinning_reason");
      RegisterBlueprintField("bucket_redundancy_penalty");
      RegisterBlueprintField("winner_archetype_class");
      RegisterBlueprintField("reserve_promoted_for_diversity_flag");
      RegisterBlueprintField("redundancy_swap_reason");

      RegisterBlueprintField("sample_count");
      RegisterBlueprintField("abstained_flag");
      RegisterBlueprintField("pair_regime_comparability_class");
     }

   void SeedBlueprintV171()
     {
      SeedBlueprintV172();
     }

   void SeedBlueprintV170()
     {
      SeedBlueprintV172();
     }

   void SeedBlueprintV150()
     {
      SeedBlueprintV172();
     }
  };

// ============================================================================
// SECTION 03: ENUM REGISTRY
// Registry documents enums; core still owns the actual enum definitions.
// ============================================================================

class ISSX_EnumRegistry
  {
private:
   ISSX_EnumMetadataEntry m_items[];

   int CompareText(const string a,const string b) const
     {
      return StringCompare(a,b);
     }

   void BuildSortedIndices(int &indices[]) const
     {
      const int n=ArraySize(m_items);
      ArrayResize(indices,n);
      for(int i=0;i<n;i++)
         indices[i]=i;

      for(int i=0;i<n-1;i++)
        {
         int best=i;
         for(int j=i+1;j<n;j++)
           {
            const int a=indices[j];
            const int b=indices[best];
            if(CompareText(m_items[a].enum_name,m_items[b].enum_name)<0)
               best=j;
           }
         if(best!=i)
           {
            const int tmp=indices[i];
            indices[i]=indices[best];
            indices[best]=tmp;
           }
        }
     }

public:
   void Reset()
     {
      ArrayResize(m_items,0);
     }

   int Count() const
     {
      return ArraySize(m_items);
     }

   bool Add(const string enum_name,const string allowed_values_csv,const string compact_description)
     {
      const int n=ArraySize(m_items);
      if(ISSX_Util::IsEmpty(enum_name))
         return false;
      for(int i=0;i<n;i++)
         if(m_items[i].enum_name==enum_name)
            return false;
      if(ArrayResize(m_items,n+1)!=(n+1))
         return false;
      m_items[n].Reset();
      m_items[n].enum_name=enum_name;
      m_items[n].allowed_values_csv=allowed_values_csv;
      m_items[n].compact_description=compact_description;
      return true;
     }

      ISSX_ValidationResult Validate() const
     {
      for(int i=0;i<ArraySize(m_items);i++)
        {
         if(ISSX_Util::IsEmpty(m_items[i].enum_name))
            return ISSX_Validate::Fail(2101,"enum_name empty");
         if(ISSX_Util::IsEmpty(m_items[i].allowed_values_csv))
            return ISSX_Validate::Fail(2102,"allowed_values_csv empty");
         if(ISSX_Util::IsEmpty(m_items[i].compact_description))
            return ISSX_Validate::Fail(2103,"compact_description empty");
        }
      return ISSX_Validate::Ok();
     }

   string FingerprintHex() const
     {
      return ISSX_Hash::HashStringHex(ExportCompactJson());
     }

   string ExportCompactJson() const
     {
      int order[];
      BuildSortedIndices(order);

      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginArray();
      for(int k=0;k<ArraySize(order);k++)
        {
         const int i=order[k];
         jw.BeginObject();
         jw.NameString("enum_name",m_items[i].enum_name);
         jw.NameString("allowed_values_csv",m_items[i].allowed_values_csv);
         jw.NameString("compact_description",m_items[i].compact_description);
         jw.EndObject();
        }
      jw.EndArray();
      return jw.ToString();
     }

   void SeedBlueprintV172()
     {
      Reset();
      Add("acceptance_type","unknown,accepted_for_pipeline,accepted_for_ranking,accepted_for_intelligence,accepted_for_gpt_export,accepted_degraded,rejected","Acceptance outcome.");
      Add("authority_level","unknown,observed,validated,derived,advisory,degraded","Registry authority level semantic.");
      Add("bucket_confidence_class","unknown,strong,usable,exploratory,blocked","Bucket confidence surface.");
      Add("compatibility_class","unknown,incompatible,schema_only,storage_compatible,policy_degraded,consumer_compatible,exact","Structural/semantic/policy compatibility outcome.");
      Add("content_class","unknown,empty,partial,usable,strong","Content class.");
      Add("contradiction_class","unknown,identity,session,spec,history_continuity,selection_ownership,intelligence_validity","Minimum contradiction taxonomy.");
      Add("debug_weak_link_code","unknown,none,dependency_block,fallback_habit,starvation,publish_stale,rewrite_storm,queue_backlog,acceptance_failure","Stage weak-link reason code.");
      Add("direct_or_derived","unknown,direct,derived","Field provenance class.");
      Add("diversification_confidence_class","unknown,low,moderate,high","Confidence in diversification evidence.");
      Add("expansion_state_class","unknown,compressed,normal,expanding,extended","Neutral expansion state.");
      Add("finality_state","unknown,stable,watch,unstable,recovering","Completed-bar finality class.");
      Add("history_readiness_state","unknown,never_requested,requested_sync,partial_available,syncing,compare_unsafe,compare_safe_degraded,compare_safe_strong,degraded_unstable,blocked","EA2 history readiness state.");
      Add("holding_horizon_context","unknown,short_intraday,mixed_intraday,extended_intraday","Neutral holding horizon context.");
      Add("hud_warning_severity","unknown,none,info,warn,error,blocking","HUD warning severity.");
      Add("hydration_menu_class","unknown,bootstrap,delta_first,backlog_clearing,continuity_preserving,publish_critical,optional_enrichment","Hydration menu scheduling class.");
      Add("invalidation_class","unknown,quote_freshness,tradeability,session_boundary,history_sync,frontier_member_change,family_representative_change,policy_change,clock_anomaly,activity_regime","Invalidation trigger family.");
      Add("intraday_activity_state","unknown,dormant,waking,active,elevated,dislocated","Neutral intraday activity state.");
      Add("liquidity_regime_class","unknown,poor,acceptable,strong,fragmented","Neutral liquidity regime.");
      Add("microstructure_noise_class","unknown,low,moderate,high","Neutral microstructure noise class.");
      Add("missing_policy","unknown,ignore,default,error","Missing/null semantic handling.");
      Add("movement_maturity_class","unknown,early,developing,mature,late,recovering","Neutral movement maturity.");
      Add("movement_quality_class","unknown,orderly,acceptable,noisy,fragmented,rotational","Neutral movement cleanliness.");
      Add("pair_regime_comparability_class","unknown,poor,usable,strong","Pair regime comparability surface.");
      Add("pair_sample_alignment_class","unknown,poor,usable,strong","Pair sample/bar alignment quality.");
      Add("pair_validity_class","unknown,unknown_overlap,valid_low_overlap,valid_high_overlap,provisional_overlap,blocked_overlap","Pair-overlap validity surface.");
      Add("pair_window_freshness_class","unknown,stale,usable,fresh","Freshness of pair evidence window.");
      Add("publish_reason","unknown,bootstrap,scheduled,recovery,material_change,degradation_transition,contradiction_transition,heartbeat,manual","Why a stage published.");
      Add("rankability_lane","unknown,strong,usable,exploratory,blocked","Elastic rankability lane for EA3.");
      Add("range_efficiency_class","unknown,poor,acceptable,strong","Neutral range efficiency class.");
      Add("redundancy_risk_class","unknown,low,moderate,high","Redundancy risk class.");
      Add("rewrite_class","unknown,none,benign_last_bar_adjustment,short_tail,structural_gap,historical_block","History rewrite classification.");
      Add("session_phase_class","unknown,pre_open,opening,active,late,close,closed","Neutral session phase.");
      Add("session_truth_class","unknown,declared_only,observed_supported,contradictory","Layered session truth support.");
      Add("stage_publishability_state","unknown,not_ready,blocked,warmup,usable_degraded,usable,strong","Stage output readiness and publishability state.");
      Add("stale_policy","unknown,valid_until_threshold,degrade_after_threshold,invalidate_after_threshold,not_time_sensitive","Stale-data policy.");
      Add("trace_severity","unknown,error,warn,state_change,sampled_info","Structured trace severity tier.");
      Add("tradability_now_class","unknown,blocked,poor,acceptable,strong,cautious","Current tradability-now state.");
      Add("two_way_rotation_class","unknown,low,moderate,high","Neutral two-way rotation descriptor.");
      Add("upstream_handoff_mode","unknown,none,same_tick_accepted,internal_current,internal_previous,internal_last_good,public_projection","Visibility-preserving upstream source mode.");
      Add("volatility_regime_class","unknown,compressed,normal,expanding,extended,dislocated","Neutral volatility regime.");
      Add("warehouse_quality","unknown,thin,degraded,usable,strong","History warehouse quality class.");
      Add("winner_archetype_class","unknown,anchor,diversifier,overlap_risk,fragile_diversifier,redundant","Winner archetype / portfolio-role hint.");
      Add("winner_confidence_class","unknown,strong,usable,exploratory,degraded,blocked","Winner confidence surface.");
      Add("bar_overlap_class","unknown,low,moderate,high","Neutral bar-overlap class.");
      Add("directional_persistence_class","unknown,low,moderate,high","Neutral directional persistence descriptor without trade direction intent.");
      Add("gap_disruption_class","unknown,low,moderate,high","Neutral gap disruption descriptor.");
      Add("constructability_class","unknown,poor,acceptable,strong,fragile","Neutral intraday constructability.");
      Add("queue_family","unknown,discovery,probe,quote_sampling,history_warm,history_deep,bucket_rebuild,pair,repair,persistence,publish,debug,fastlane","Runtime queue family.");
      Add("invalidation_class","unknown,quote_freshness,tradeability,session_boundary,history_sync,frontier_member_change,family_representative_change,policy_change,clock_anomaly,activity_regime","Invalidation trigger family.");
     }

   void SeedBlueprintV171()
     {
      SeedBlueprintV172();
     }

   void SeedBlueprintV170()
     {
      SeedBlueprintV172();
     }

   void SeedBlueprintV150()
     {
      SeedBlueprintV172();
     }
  };

// ============================================================================
// SECTION 04: COMPARATOR REGISTRY
// ============================================================================

class ISSX_ComparatorRegistry
  {
private:
   ISSX_ComparatorMetadataEntry m_items[];

   int CompareText(const string a,const string b) const
     {
      return StringCompare(a,b);
     }

   void BuildSortedIndices(int &indices[]) const
     {
      const int n=ArraySize(m_items);
      ArrayResize(indices,n);
      for(int i=0;i<n;i++)
         indices[i]=i;

      for(int i=0;i<n-1;i++)
        {
         int best=i;
         for(int j=i+1;j<n;j++)
           {
            const int a=indices[j];
            const int b=indices[best];
            if(CompareText(m_items[a].comparator_id,m_items[b].comparator_id)<0)
               best=j;
           }
         if(best!=i)
           {
            const int tmp=indices[i];
            indices[i]=indices[best];
            indices[best]=tmp;
           }
        }
     }

public:
   void Reset()
     {
      ArrayResize(m_items,0);
     }

   int Count() const
     {
      return ArraySize(m_items);
     }

   bool Add(const string comparator_id,
            const string human_label,
            const string scope,
            const string stable_ordering_rule_summary,
            const string tie_break_note,
            const bool enabled)
     {
      const int n=ArraySize(m_items);
      if(ISSX_Util::IsEmpty(comparator_id))
         return false;
      for(int i=0;i<n;i++)
         if(m_items[i].comparator_id==comparator_id)
            return false;
      if(ArrayResize(m_items,n+1)!=(n+1))
         return false;
      m_items[n].Reset();
      m_items[n].comparator_id=comparator_id;
      m_items[n].human_label=human_label;
      m_items[n].scope=scope;
      m_items[n].stable_ordering_rule_summary=stable_ordering_rule_summary;
      m_items[n].tie_break_note=tie_break_note;
      m_items[n].enabled=enabled;
      return true;
     }

   ISSX_ValidationResult Validate() const
     {
      for(int i=0;i<ArraySize(m_items);i++)
        {
         if(ISSX_Util::IsEmpty(m_items[i].comparator_id))
            return ISSX_Validate::Fail(2201,"comparator_id empty");
         if(ISSX_Util::IsEmpty(m_items[i].stable_ordering_rule_summary))
            return ISSX_Validate::Fail(2202,"comparator ordering summary empty");
        }
      return ISSX_Validate::Ok();
     }

   string FingerprintHex() const
     {
      return ISSX_Hash::HashStringHex(ExportCompactJson());
     }

   string ExportCompactJson() const
     {
      int order[];
      BuildSortedIndices(order);

      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginArray();
      for(int k=0;k<ArraySize(order);k++)
        {
         const int i=order[k];
         jw.BeginObject();
         jw.NameString("comparator_id",m_items[i].comparator_id);
         jw.NameString("human_label",m_items[i].human_label);
         jw.NameString("scope",m_items[i].scope);
         jw.NameString("stable_ordering_rule_summary",m_items[i].stable_ordering_rule_summary);
         jw.NameString("tie_break_note",m_items[i].tie_break_note);
         jw.NameBool("enabled",m_items[i].enabled);
         jw.EndObject();
        }
      jw.EndArray();
      return jw.ToString();
     }

   void SeedBlueprintV172()
     {
      Reset();
      Add("cmp_bucket_local",
          "Bucket Local",
          "ea3",
          "Non-directional ranking across truth, friction, activity, volatility usability, constructability, freshness, and near-tie continuity.",
          "Weak buckets publish fewer than five instead of forced filler.",
          true);

      Add("cmp_bucket_membership",
          "Bucket Membership",
          "ea3",
          "Family collapse, truth floor, bucket admission, and breadth-with-honesty eligibility.",
          "Hard exclusion is reserved for severe integrity failures.",
          true);

      Add("cmp_diversity_tiebreak",
          "Diversity Tie-Break",
          "ea3",
          "Bounded soft redundancy penalties within comparable quality bands using family, regime, session-shape, and behavior similarity.",
          "Difference alone may not leapfrog a materially stronger candidate.",
          true);

      Add("cmp_final_survivor",
          "Final Survivor",
          "ea5",
          "Selection backbone merged with source visibility, contradiction penalties, and bounded intelligence context.",
          "Winner context remains descriptive and non-directional.",
          true);

      Add("cmp_frontier_promotion",
          "Frontier Promotion",
          "ea3",
          "Frontier maintenance using survivor continuity, near-cutline pressure, contender uplift, and bounded replacement discipline.",
          "Stale campers decay and may yield to fresher contenders.",
          true);

      Add("cmp_preferred_variant",
          "Preferred Variant",
          "ea1",
          "Family representative selection across normalized identity, observability, execution profile, continuity, and friction baseline.",
          "One-cycle noise may not switch the published representative.",
          true);

      Add("cmp_rankability_lane",
          "Rankability Lane",
          "ea3",
          "Strong then usable then exploratory lane participation with visible confidence caps and explicit blocking.",
          "Exploratory may compete but never masquerade as strong.",
          true);

      Add("cmp_sparse_peer_priority",
          "Sparse Peer Priority",
          "ea4",
          "Pair servicing by changed-pair priority, validity class, freshness, overlap promise, TTL, and abstention memory.",
          "Unknown overlap must never be treated as low overlap.",
          true);

      Add("cmp_stable_universe",
          "Stable Universe",
          "shared",
          "Canonical universe ordering and fingerprint determinism for compatibility, drift, and cohort hashing.",
          "Transient selection order must never affect fingerprints.",
          true);
     }

   void SeedBlueprintV171()
     {
      SeedBlueprintV172();
     }

   void SeedBlueprintV170()
     {
      SeedBlueprintV172();
     }

   void SeedBlueprintV150()
     {
      SeedBlueprintV172();
     }
  };

// ============================================================================
// SECTION 05: OWNER-SURFACE INVENTORY
// Governance inventory for shared contract roots.
// ============================================================================

class ISSX_OwnerSurfaceInventory
  {
private:
   ISSX_OwnerSurfaceInventoryItem m_items[];

   int CompareText(const string a,const string b) const
     {
      return StringCompare(a,b);
     }

   void BuildSortedIndices(int &indices[]) const
     {
      const int n=ArraySize(m_items);
      ArrayResize(indices,n);
      for(int i=0;i<n;i++)
         indices[i]=i;

      for(int i=0;i<n-1;i++)
        {
         int best=i;
         for(int j=i+1;j<n;j++)
           {
            const int a=indices[j];
            const int b=indices[best];
            int cmp=CompareText(m_items[a].surface_name,m_items[b].surface_name);
            if(cmp==0)
               cmp=(int)m_items[a].surface_kind-(int)m_items[b].surface_kind;
            if(cmp<0)
               best=j;
           }
         if(best!=i)
           {
            const int tmp=indices[i];
            indices[i]=indices[best];
            indices[best]=tmp;
           }
        }
     }

public:
   void Reset()
     {
      ArrayResize(m_items,0);
     }

   int Count() const
     {
      return ArraySize(m_items);
     }

   bool Add(const string surface_name,
            const ISSX_SurfaceKind surface_kind,
            const string owner_module,
            const string consumer_modules_csv,
            const bool persisted_flag,
            const bool exported_flag,
            const bool debug_only_flag,
            const ISSX_CompatibilityAliasState compatibility_alias_state,
            const bool policy_sensitive_flag,
            const bool storage_sensitive_flag,
            const bool external_contract_sensitive_flag)
     {
      const int n=ArraySize(m_items);
      if(ISSX_Util::IsEmpty(surface_name))
         return false;
      if(surface_kind==issx_surface_kind_unknown)
         return false;
      if(ISSX_Util::IsEmpty(owner_module))
         return false;
      if(compatibility_alias_state==issx_alias_state_unknown)
         return false;

      for(int i=0;i<n;i++)
        {
         if(m_items[i].surface_name==surface_name && m_items[i].surface_kind==surface_kind)
            return false;
        }

      if(ArrayResize(m_items,n+1)!=(n+1))
         return false;

      m_items[n].Reset();
      m_items[n].surface_name=surface_name;
      m_items[n].surface_kind=surface_kind;
      m_items[n].owner_module=owner_module;
      m_items[n].consumer_modules=consumer_modules_csv;
      m_items[n].persisted_flag=persisted_flag;
      m_items[n].exported_flag=exported_flag;
      m_items[n].debug_only_flag=debug_only_flag;
      m_items[n].compatibility_alias_state=compatibility_alias_state;
      m_items[n].policy_sensitive_flag=policy_sensitive_flag;
      m_items[n].storage_sensitive_flag=storage_sensitive_flag;
      m_items[n].external_contract_sensitive_flag=external_contract_sensitive_flag;
      return true;
     }

   ISSX_ValidationResult Validate() const
     {
      for(int i=0;i<ArraySize(m_items);i++)
        {
         ISSX_ValidationResult r=ISSX_Validate::ValidateOwnerSurfaceInventoryItem(m_items[i]);
         if(!r.ok)
            return r;
        }
      return ISSX_Validate::Ok();
     }

   string FingerprintHex() const
     {
      return ISSX_Hash::HashStringHex(ExportCompactJson());
     }

   string ExportCompactJson() const
     {
      int order[];
      BuildSortedIndices(order);

      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginArray();
      for(int k=0;k<ArraySize(order);k++)
        {
         const int i=order[k];
         jw.BeginObject();
         jw.NameString("surface_name",m_items[i].surface_name);
         jw.NameString("surface_kind",ISSX_SurfaceKindToString(m_items[i].surface_kind));
         jw.NameString("owner_module",m_items[i].owner_module);
         jw.NameString("consumer_modules_csv",m_items[i].consumer_modules);
         jw.NameBool("persisted_flag",m_items[i].persisted_flag);
         jw.NameBool("exported_flag",m_items[i].exported_flag);
         jw.NameBool("debug_only_flag",m_items[i].debug_only_flag);
         jw.NameString("compatibility_alias_state",ISSX_CompatibilityAliasStateToString(m_items[i].compatibility_alias_state));
         jw.NameBool("policy_sensitive_flag",m_items[i].policy_sensitive_flag);
         jw.NameBool("storage_sensitive_flag",m_items[i].storage_sensitive_flag);
         jw.NameBool("external_contract_sensitive_flag",m_items[i].external_contract_sensitive_flag);
         jw.EndObject();
        }
      jw.EndArray();
      return jw.ToString();
     }

   void SeedBlueprintV172()
     {
      Reset();

      Add("shared_semantic_enums",
          issx_surface_kind_enum,
          "issx_core.mqh",
          "issx_registry.mqh,issx_runtime.mqh,issx_market_engine.mqh,issx_history_engine.mqh,issx_selection_engine.mqh,issx_correlation_engine.mqh,issx_contracts.mqh,issx_ui.mqh",
          true,
          true,
          false,
          issx_alias_state_active_primary,
          true,
          true,
          true);

      Add("shared_dtos",
          issx_surface_kind_dto,
          "issx_core.mqh",
          "issx_registry.mqh,issx_runtime.mqh,issx_persistence.mqh,issx_market_engine.mqh,issx_history_engine.mqh,issx_selection_engine.mqh,issx_correlation_engine.mqh,issx_contracts.mqh,issx_ui.mqh",
          true,
          true,
          false,
          issx_alias_state_active_primary,
          true,
          true,
          true);

      Add("shared_field_keys",
          issx_surface_kind_constant,
          "issx_core.mqh",
          "issx_registry.mqh,issx_persistence.mqh,issx_market_engine.mqh,issx_history_engine.mqh,issx_selection_engine.mqh,issx_correlation_engine.mqh,issx_contracts.mqh,issx_ui.mqh",
          true,
          true,
          false,
          issx_alias_state_active_primary,
          true,
          true,
          true);

      Add("shared_path_keys",
          issx_surface_kind_constant,
          "issx_core.mqh",
          "issx_persistence.mqh,issx_runtime.mqh,issx_market_engine.mqh,issx_history_engine.mqh,issx_contracts.mqh",
          true,
          false,
          false,
          issx_alias_state_active_primary,
          false,
          true,
          false);

      Add("manifest_keys",
          issx_surface_kind_manifest_field,
          "issx_core.mqh",
          "issx_persistence.mqh,issx_runtime.mqh,issx_market_engine.mqh,issx_history_engine.mqh,issx_selection_engine.mqh,issx_correlation_engine.mqh,issx_contracts.mqh,issx_ui.mqh",
          true,
          true,
          false,
          issx_alias_state_active_primary,
          true,
          true,
          true);

      Add("stage_api_entry_points",
          issx_surface_kind_stage_api_method,
          "issx_core.mqh",
          "issx_runtime.mqh,issx_market_engine.mqh,issx_history_engine.mqh,issx_selection_engine.mqh,issx_correlation_engine.mqh,issx_contracts.mqh,ISSX.mq5",
          false,
          false,
          false,
          issx_alias_state_active_primary,
          true,
          false,
          false);

      Add("json_writer_helper_family",
          issx_surface_kind_helper,
          "issx_core.mqh",
          "issx_registry.mqh,issx_persistence.mqh,issx_market_engine.mqh,issx_history_engine.mqh,issx_selection_engine.mqh,issx_correlation_engine.mqh,issx_contracts.mqh,issx_ui.mqh",
          false,
          true,
          false,
          issx_alias_state_active_primary,
          false,
          false,
          true);

      Add("shared_compatibility_aliases",
          issx_surface_kind_helper,
          "issx_core.mqh",
          "issx_registry.mqh,issx_runtime.mqh,issx_persistence.mqh,issx_market_engine.mqh,issx_history_engine.mqh,issx_selection_engine.mqh,issx_correlation_engine.mqh,issx_contracts.mqh,issx_ui.mqh",
          true,
          true,
          false,
          issx_alias_state_bridged_legacy,
          true,
          true,
          true);

      Add("ea5_external_field_keys",
          issx_surface_kind_json_field,
          "issx_core.mqh",
          "issx_contracts.mqh,issx_ui.mqh",
          false,
          true,
          false,
          issx_alias_state_active_primary,
          true,
          false,
          true);

      Add("shared_debug_trace_hud_keys",
          issx_surface_kind_debug_key,
          "issx_core.mqh",
          "issx_registry.mqh,issx_runtime.mqh,issx_market_engine.mqh,issx_history_engine.mqh,issx_selection_engine.mqh,issx_correlation_engine.mqh,issx_contracts.mqh,issx_ui.mqh",
          false,
          true,
          true,
          issx_alias_state_active_primary,
          true,
          false,
          false);

      Add("field_registry_metadata",
          issx_surface_kind_serializer,
          "issx_registry.mqh",
          "issx_runtime.mqh,issx_persistence.mqh,issx_contracts.mqh,issx_ui.mqh",
          false,
          true,
          false,
          issx_alias_state_active_primary,
          true,
          false,
          true);

      Add("enum_registry_metadata",
          issx_surface_kind_serializer,
          "issx_registry.mqh",
          "issx_runtime.mqh,issx_contracts.mqh,issx_ui.mqh",
          false,
          true,
          false,
          issx_alias_state_active_primary,
          false,
          false,
          false);

      Add("comparator_registry_metadata",
          issx_surface_kind_serializer,
          "issx_registry.mqh",
          "issx_selection_engine.mqh,issx_correlation_engine.mqh,issx_contracts.mqh,issx_ui.mqh",
          false,
          true,
          false,
          issx_alias_state_active_primary,
          true,
          false,
          false);

      Add("owner_surface_inventory",
          issx_surface_kind_serializer,
          "issx_registry.mqh",
          "issx_runtime.mqh,issx_ui.mqh,issx_contracts.mqh",
          false,
          true,
          false,
          issx_alias_state_active_primary,
          true,
          false,
          false);
     }

   void SeedBlueprintV171()
     {
      SeedBlueprintV172();
     }

   void SeedBlueprintV170()
     {
      SeedBlueprintV172();
     }

   void SeedBlueprintV150()
     {
      SeedBlueprintV172();
     }
  };

// ============================================================================
// SECTION 05B: STAGE STATE REGISTRY (RUNTIME STATE ONLY)
// ============================================================================

enum ISSX_StageStateCode
  {
   STAGE_OFF      =0,
   STAGE_INIT     =1,
   STAGE_RUNNING  =2,
   STAGE_READY    =3,
   STAGE_DEGRADED =4,
   STAGE_FAILED   =5,
   STAGE_SKIPPED  =6
  };

enum ISSX_StageHealthCode
  {
   STAGE_HEALTH_UNKNOWN  =0,
   STAGE_HEALTH_HEALTHY  =1,
   STAGE_HEALTH_DEGRADED =2,
   STAGE_HEALTH_FAILED   =3
  };

struct ISSXStageState
  {
   string   stage_name;
   int      state;
   string   reason;
   long     elapsed_ms;
   int      health_state;
   datetime last_update;

   void Reset()
     {
      stage_name="";
      state=STAGE_OFF;
      reason="none";
      elapsed_ms=0;
      health_state=STAGE_HEALTH_UNKNOWN;
      last_update=(datetime)0;
     }
  };

struct ISSXStageRegistration
  {
   string stage_name;
   bool   required_stage;
   bool   registered_flag;
   bool   enabled_flag;
   int    priority_order;
   string dependency_csv;
   string disabled_reason;
   datetime registered_at;

   void Reset()
     {
      stage_name="";
      required_stage=false;
      registered_flag=false;
      enabled_flag=false;
      priority_order=0;
      dependency_csv="";
      disabled_reason="none";
      registered_at=(datetime)0;
     }
  };

class ISSX_StageStateRegistry
  {
private:
   ISSXStageState        m_items[];
   ISSXStageRegistration m_specs[];
   long                  m_update_seq;

   int FindIndex(const string stage_name) const
     {
      const int n=ArraySize(m_items);
      for(int i=0;i<n;i++)
        {
         if(m_items[i].stage_name==stage_name)
            return i;
        }
      return -1;
     }

   int EnsureIndex(const string stage_name)
     {
      if(ISSX_Util::IsEmpty(stage_name))
         return -1;

      int idx=FindIndex(stage_name);
      if(idx>=0)
         return idx;

      const int n=ArraySize(m_items);
      if(ArrayResize(m_items,n+1)!=(n+1))
         return -1;

      idx=n;
      m_items[idx].Reset();
      m_items[idx].stage_name=stage_name;
      m_items[idx].last_update=TimeLocal();
      return idx;
     }

   int FindSpecIndex(const string stage_name) const
     {
      const int n=ArraySize(m_specs);
      for(int i=0;i<n;i++)
        {
         if(m_specs[i].stage_name==stage_name)
            return i;
        }
      return -1;
     }

   int EnsureSpecIndex(const string stage_name)
     {
      if(ISSX_Util::IsEmpty(stage_name))
         return -1;

      int idx=FindSpecIndex(stage_name);
      if(idx>=0)
         return idx;

      const int n=ArraySize(m_specs);
      if(ArrayResize(m_specs,n+1)!=(n+1))
         return -1;

      idx=n;
      m_specs[idx].Reset();
      m_specs[idx].stage_name=stage_name;
      return idx;
     }

   bool IsStateValid(const int state) const
     {
      return (state>=STAGE_OFF && state<=STAGE_SKIPPED);
     }

   bool IsHealthValid(const int health_state) const
     {
      return (health_state>=STAGE_HEALTH_UNKNOWN && health_state<=STAGE_HEALTH_FAILED);
     }

   string NormalizeReason(const string reason) const
     {
      if(ISSX_Util::IsEmpty(reason))
         return "none";
      return reason;
     }

   void Touch(const int idx)
     {
      if(idx<0 || idx>=ArraySize(m_items))
         return;
      m_items[idx].last_update=TimeLocal();
      m_update_seq++;
     }

   static string CanonicalRequiredStageName(const int idx)
     {
      switch(idx)
        {
         case 0: return "ea1_market";
         case 1: return "ea2_history";
         case 2: return "ea3_selection";
         case 3: return "ea4_correlation";
         case 4: return "ea5_contracts";
        }
      return "";
     }

   static string CanonicalDependenciesFor(const string stage_name)
     {
      if(stage_name=="ea1_market")
         return "runtime_ready,symbol_valid,live_tick,recent_tick,rates_valid";
      if(stage_name=="ea2_history")
         return "ea1_market,history_access";
      if(stage_name=="ea3_selection")
         return "ea1_market,ea2_history";
      if(stage_name=="ea4_correlation")
         return "ea3_selection";
      if(stage_name=="ea5_contracts")
         return "ea1_market,ea2_history,ea3_selection,ea4_correlation";
      return "";
     }

   bool ValidateOneRequiredStage(const string stage_name,string &reason) const
     {
      const int spec_idx=FindSpecIndex(stage_name);
      if(spec_idx<0)
        {
         reason="stage_missing";
         return false;
        }

      if(!m_specs[spec_idx].registered_flag)
        {
         reason="stage_not_registered";
         return false;
        }

      const int state_idx=FindIndex(stage_name);
      if(state_idx<0)
        {
         reason="stage_state_missing";
         return false;
        }

      if(!IsStateValid(m_items[state_idx].state))
        {
         reason="stage_state_invalid";
         return false;
        }

      if(m_specs[spec_idx].priority_order<=0)
        {
         reason="stage_priority_missing";
         return false;
        }

      if(ISSX_Util::IsEmpty(m_specs[spec_idx].dependency_csv))
        {
         reason="stage_dependency_missing";
         return false;
        }

      if(!m_specs[spec_idx].enabled_flag && ISSX_Util::IsEmpty(m_specs[spec_idx].disabled_reason))
        {
         reason="stage_disabled_reason_missing";
         return false;
        }

      reason="ok";
      return true;
     }

public:
   ISSX_StageStateRegistry()
     {
      Reset();
     }

   void Reset()
     {
      ArrayResize(m_items,0);
      ArrayResize(m_specs,0);
      m_update_seq=0;
     }

   void SeedCanonicalRequiredStages(const bool ea1_enabled,
                                    const bool ea2_enabled,
                                    const bool ea3_enabled,
                                    const bool ea4_enabled,
                                    const bool ea5_enabled)
     {
      Reset();

      RegisterStage("ea1_market",1,ea1_enabled,true,CanonicalDependenciesFor("ea1_market"),(ea1_enabled?"none":"requested_off"));
      RegisterStage("ea2_history",2,ea2_enabled,true,CanonicalDependenciesFor("ea2_history"),(ea2_enabled?"none":"requested_off"));
      RegisterStage("ea3_selection",3,ea3_enabled,true,CanonicalDependenciesFor("ea3_selection"),(ea3_enabled?"none":"requested_off"));
      RegisterStage("ea4_correlation",4,ea4_enabled,true,CanonicalDependenciesFor("ea4_correlation"),(ea4_enabled?"none":"requested_off"));
      RegisterStage("ea5_contracts",5,ea5_enabled,true,CanonicalDependenciesFor("ea5_contracts"),(ea5_enabled?"none":"requested_off"));

      EnsureIndex("ea1_market");
      EnsureIndex("ea2_history");
      EnsureIndex("ea3_selection");
      EnsureIndex("ea4_correlation");
      EnsureIndex("ea5_contracts");
     }

   int Count() const
     {
      return ArraySize(m_items);
     }

   int RegisteredStageCount() const
     {
      int total=0;
      for(int i=0;i<ArraySize(m_specs);i++)
         if(m_specs[i].registered_flag)
            total++;
      return total;
     }

   int RequiredStageCount() const
     {
      int total=0;
      for(int i=0;i<ArraySize(m_specs);i++)
         if(m_specs[i].required_stage)
            total++;
      return total;
     }

   bool Exists(const string stage_name) const
     {
      return (FindIndex(stage_name)>=0 || FindSpecIndex(stage_name)>=0);
     }

   bool RegisterStage(const string stage_name,
                      const int priority_order,
                      const bool enabled_flag,
                      const bool required_stage=true,
                      const string dependency_csv="",
                      const string disabled_reason="none")
     {
      if(ISSX_Util::IsEmpty(stage_name))
         return false;

      const int spec_idx=EnsureSpecIndex(stage_name);
      if(spec_idx<0)
         return false;

      m_specs[spec_idx].stage_name=stage_name;
      m_specs[spec_idx].required_stage=required_stage;
      m_specs[spec_idx].registered_flag=true;
      m_specs[spec_idx].enabled_flag=enabled_flag;
      m_specs[spec_idx].priority_order=priority_order;
      m_specs[spec_idx].dependency_csv=(ISSX_Util::IsEmpty(dependency_csv) ? CanonicalDependenciesFor(stage_name) : dependency_csv);
      m_specs[spec_idx].disabled_reason=(enabled_flag ? "none" : NormalizeReason(disabled_reason));
      m_specs[spec_idx].registered_at=TimeLocal();

      EnsureIndex(stage_name);
      return true;
     }

   bool SetEnabled(const string stage_name,const bool enabled_flag,const string disabled_reason="none")
     {
      const int spec_idx=EnsureSpecIndex(stage_name);
      if(spec_idx<0)
         return false;

      m_specs[spec_idx].enabled_flag=enabled_flag;
      m_specs[spec_idx].disabled_reason=(enabled_flag ? "none" : NormalizeReason(disabled_reason));
      m_specs[spec_idx].registered_flag=true;
      if(m_specs[spec_idx].registered_at<=0)
         m_specs[spec_idx].registered_at=TimeLocal();
      return true;
     }

   bool SetPriority(const string stage_name,const int priority_order)
     {
      const int spec_idx=EnsureSpecIndex(stage_name);
      if(spec_idx<0)
         return false;
      m_specs[spec_idx].priority_order=priority_order;
      m_specs[spec_idx].registered_flag=true;
      return true;
     }

   bool SetDependencies(const string stage_name,const string dependency_csv)
     {
      const int spec_idx=EnsureSpecIndex(stage_name);
      if(spec_idx<0)
         return false;
      m_specs[spec_idx].dependency_csv=NormalizeReason(dependency_csv);
      m_specs[spec_idx].registered_flag=true;
      return true;
     }

   bool SetState(const string stage_name,const int state)
     {
      if(!IsStateValid(state))
         return false;

      const int idx=EnsureIndex(stage_name);
      if(idx<0)
         return false;

      if(m_items[idx].state==state)
         return false;

      m_items[idx].state=state;
      Touch(idx);
      return true;
     }

   bool SetReason(const string stage_name,const string reason)
     {
      const int idx=EnsureIndex(stage_name);
      if(idx<0)
         return false;

      const string value=NormalizeReason(reason);
      if(m_items[idx].reason==value)
         return false;

      m_items[idx].reason=value;
      Touch(idx);
      return true;
     }

   bool SetElapsed(const string stage_name,const long elapsed_ms)
     {
      const int idx=EnsureIndex(stage_name);
      if(idx<0)
         return false;

      const long value=(elapsed_ms<0 ? 0 : elapsed_ms);
      if(m_items[idx].elapsed_ms==value)
         return false;

      m_items[idx].elapsed_ms=value;
      Touch(idx);
      return true;
     }

   bool SetHealth(const string stage_name,const int health_state)
     {
      if(!IsHealthValid(health_state))
         return false;

      const int idx=EnsureIndex(stage_name);
      if(idx<0)
         return false;

      if(m_items[idx].health_state==health_state)
         return false;

      m_items[idx].health_state=health_state;
      Touch(idx);
      return true;
     }

   int GetState(const string stage_name) const
     {
      const int idx=FindIndex(stage_name);
      if(idx<0)
         return STAGE_OFF;
      return m_items[idx].state;
     }

   string GetReason(const string stage_name) const
     {
      const int idx=FindIndex(stage_name);
      if(idx<0)
         return "none";
      return m_items[idx].reason;
     }

   long GetElapsed(const string stage_name) const
     {
      const int idx=FindIndex(stage_name);
      if(idx<0)
         return 0;
      return m_items[idx].elapsed_ms;
     }

   int GetHealth(const string stage_name) const
     {
      const int idx=FindIndex(stage_name);
      if(idx<0)
         return STAGE_HEALTH_UNKNOWN;
      return m_items[idx].health_state;
     }

   datetime GetLastUpdate(const string stage_name) const
     {
      const int idx=FindIndex(stage_name);
      if(idx<0)
         return (datetime)0;
      return m_items[idx].last_update;
     }

   bool GetSnapshot(const string stage_name,ISSXStageState &out_state) const
     {
      out_state.Reset();
      const int idx=FindIndex(stage_name);
      if(idx<0)
         return false;

      out_state=m_items[idx];
      return true;
     }

   bool IsRegistered(const string stage_name) const
     {
      const int spec_idx=FindSpecIndex(stage_name);
      if(spec_idx<0)
         return false;
      return m_specs[spec_idx].registered_flag;
     }

   bool IsEnabled(const string stage_name) const
     {
      const int spec_idx=FindSpecIndex(stage_name);
      if(spec_idx<0)
         return false;
      return m_specs[spec_idx].enabled_flag;
     }

   int GetPriority(const string stage_name) const
     {
      const int spec_idx=FindSpecIndex(stage_name);
      if(spec_idx<0)
         return 0;
      return m_specs[spec_idx].priority_order;
     }

   string GetDependencies(const string stage_name) const
     {
      const int spec_idx=FindSpecIndex(stage_name);
      if(spec_idx<0)
         return "";
      return m_specs[spec_idx].dependency_csv;
     }

   string GetDisabledReason(const string stage_name) const
     {
      const int spec_idx=FindSpecIndex(stage_name);
      if(spec_idx<0)
         return "stage_missing";
      return m_specs[spec_idx].disabled_reason;
     }

   bool ValidateRequiredStages(string &reason) const
     {
      reason="ok";

      for(int i=0;i<5;i++)
        {
         const string stage_name=CanonicalRequiredStageName(i);
         if(ISSX_Util::IsEmpty(stage_name))
            continue;

         string local_reason="ok";
         if(!ValidateOneRequiredStage(stage_name,local_reason))
           {
            reason=stage_name+"_"+local_reason;
            return false;
           }
        }

      return true;
     }

   string BuildRegistrySummary() const
     {
      string names="";
      string missing="";
      string disabled="";

      for(int i=0;i<5;i++)
        {
         const string stage_name=CanonicalRequiredStageName(i);
         if(i>0)
            names+=",";
         names+=stage_name;

         const int spec_idx=FindSpecIndex(stage_name);
         if(spec_idx<0 || !m_specs[spec_idx].registered_flag)
           {
            if(StringLen(missing)>0)
               missing+=",";
            missing+=stage_name;
            continue;
           }

         if(!m_specs[spec_idx].enabled_flag)
           {
            if(StringLen(disabled)>0)
               disabled+=",";
            disabled+=stage_name+"("+m_specs[spec_idx].disabled_reason+")";
           }
        }

      if(StringLen(missing)<=0)
         missing="none";
      if(StringLen(disabled)<=0)
         disabled="none";

      return "required_stage_count="+IntegerToString(5)+
             " registered_stage_count="+IntegerToString(RegisteredStageCount())+
             " names="+names+
             " missing_stages="+missing+
             " disabled_stages="+disabled;
     }

   void DumpRegistrySummary() const
     {
      Print("ISSX: stage_registry_summary ",BuildRegistrySummary());

      for(int i=0;i<5;i++)
        {
         const string stage_name=CanonicalRequiredStageName(i);
         const int spec_idx=FindSpecIndex(stage_name);
         const int state_idx=FindIndex(stage_name);

         string state_text="missing";
         string health_text="unknown";
         string reason_text="none";
         if(state_idx>=0)
           {
            state_text=StateToString(m_items[state_idx].state);
            health_text=HealthToString(m_items[state_idx].health_state);
            reason_text=m_items[state_idx].reason;
           }

         if(spec_idx<0)
           {
            Print("ISSX: stage_registry_item stage=",stage_name,
                  " registered=no state=",state_text,
                  " priority=0 enabled=unknown dependencies=missing reason=",reason_text);
            continue;
           }

         Print("ISSX: stage_registry_item stage=",stage_name,
               " registered=",(m_specs[spec_idx].registered_flag?"yes":"no"),
               " required=",(m_specs[spec_idx].required_stage?"yes":"no"),
               " enabled=",(m_specs[spec_idx].enabled_flag?"yes":"no"),
               " priority=",IntegerToString(m_specs[spec_idx].priority_order),
               " dependencies=",m_specs[spec_idx].dependency_csv,
               " disabled_reason=",m_specs[spec_idx].disabled_reason,
               " state=",state_text,
               " health=",health_text,
               " reason=",reason_text);
        }
     }

   long UpdateSequence() const
     {
      return m_update_seq;
     }

   static string StateToString(const int state)
     {
      switch(state)
        {
         case STAGE_OFF:      return "off";
         case STAGE_INIT:     return "init";
         case STAGE_RUNNING:  return "running";
         case STAGE_READY:    return "ready";
         case STAGE_DEGRADED: return "degraded";
         case STAGE_FAILED:   return "failed";
         case STAGE_SKIPPED:  return "skipped";
        }
      return "off";
     }

   static string HealthToString(const int health_state)
     {
      switch(health_state)
        {
         case STAGE_HEALTH_HEALTHY:  return "healthy";
         case STAGE_HEALTH_DEGRADED: return "degraded";
         case STAGE_HEALTH_FAILED:   return "failed";
        }
      return "unknown";
     }
  };

// ============================================================================
// SECTION 06: REGISTRY BUNDLE
// ============================================================================

class ISSX_RegistryBundle
  {
public:
   ISSX_FieldRegistry         fields;
   ISSX_EnumRegistry          enums;
   ISSX_ComparatorRegistry    comparators;
   ISSX_OwnerSurfaceInventory owner_surfaces;

   void SeedBlueprintV172()
     {
      fields.SeedBlueprintV172();
      enums.SeedBlueprintV172();
      comparators.SeedBlueprintV172();
      owner_surfaces.SeedBlueprintV172();
     }

   void SeedBlueprintV171()
     {
      SeedBlueprintV172();
     }

   void SeedBlueprintV170()
     {
      SeedBlueprintV172();
     }

   void SeedBlueprintV150()
     {
      SeedBlueprintV172();
     }

   ISSX_ValidationResult Validate() const
     {
      ISSX_ValidationResult r=fields.Validate();
      if(!r.ok)
         return r;
      r=enums.Validate();
      if(!r.ok)
         return r;
      r=comparators.Validate();
      if(!r.ok)
         return r;
      r=owner_surfaces.Validate();
      return r;
     }

   string SchemaFingerprintHex() const
     {
      return ISSX_Hash::HashStringHex(fields.FingerprintHex()
                                      +"|"+enums.FingerprintHex()
                                      +"|"+comparators.FingerprintHex()
                                      +"|"+owner_surfaces.FingerprintHex());
     }
  };



string ISSX_RegistryDiagTag()
  {
   return "registry_diag_v174f";
  }


string ISSX_RegistryDebugSignature()
  {
   return ISSX_RegistryDiagTag();
  }

#endif // __ISSX_REGISTRY_MQH__
