#ifndef __ISSX_REGISTRY_MQH__
#define __ISSX_REGISTRY_MQH__
#include <ISSX/issx_core.mqh>

// ============================================================================
// ISSX REGISTRY v1.7.0
// Central ownership metadata for fields, enums, comparator contracts,
// policy-sensitive fingerprints, semantic warnings, and EA5 legend support.
//
// BLUEPRINT ALIGNMENT
// - every exported field has one owner
// - all v1.7.0 added fields are centrally registered
// - debug/diagnostic fields are explicitly marked diagnostic
// - warehouse-derived fields declare provenance and stale policy
// - policy-sensitive compatibility remains fingerprint-visible
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
  };

struct ISSX_EnumMetadataEntry
  {
   string enum_name;
   string allowed_values_csv;
   string compact_description;
  };

struct ISSX_ComparatorMetadataEntry
  {
   string comparator_id;
   string human_label;
   string scope;
   string stable_ordering_rule_summary;
   string tie_break_note;
   bool   enabled;
  };

// ============================================================================
// SECTION 02: FIELD REGISTRY
// ============================================================================

class ISSX_FieldRegistry
  {
private:
   ISSX_FieldMetadataEntry m_items[];

   bool StringStartsWith(const string value,const string prefix) const
     {
      if(StringLen(prefix)<=0)
         return true;
      return StringSubstr(value,0,StringLen(prefix))==prefix;
     }

   bool StringEndsWith(const string value,const string suffix) const
     {
      int lv=StringLen(value);
      int ls=StringLen(suffix);
      if(ls<=0)
         return true;
      if(ls>lv)
         return false;
      return StringSubstr(value,lv-ls,ls)==suffix;
     }

   ISSX_StageId InferOwner(const string field_name) const
     {
      if(StringFind(field_name,"winner_")==0 ||
         StringFind(field_name,"selection_reason_")==0 ||
         StringFind(field_name,"selection_penalty_")==0 ||
         StringFind(field_name,"winner_limitation_")==0 ||
         field_name=="regime_summary" ||
         field_name=="execution_condition_summary" ||
         field_name=="diversification_context_summary" ||
         field_name=="why_export_is_thin" ||
         field_name=="why_publish_is_stale" ||
         field_name=="why_frontier_is_small" ||
         field_name=="why_intelligence_abstained")
         return ISSX_STAGE_EA5;

      if(StringFind(field_name,"pair_")==0 ||
         field_name=="diversification_confidence_class" ||
         field_name=="redundancy_risk_class")
         return ISSX_STAGE_EA4;

      if(StringFind(field_name,"bucket_")==0 ||
         field_name=="rankability_lane" ||
         field_name=="exploratory_penalty_applied" ||
         field_name=="selection_latency_risk_class" ||
         field_name=="reserve_promoted_for_diversity_flag" ||
         field_name=="redundancy_swap_reason" ||
         field_name=="winner_archetype_class" ||
         field_name=="opportunity_with_caution_flag" ||
         field_name=="early_move_quality_class")
         return ISSX_STAGE_EA3;

      if(StringFind(field_name,"history_")==0 ||
         StringFind(field_name,"warehouse_")==0 ||
         field_name=="effective_lookback_bars" ||
         field_name=="warmup_sufficient_flag" ||
         field_name=="intraday_activity_state" ||
         field_name=="liquidity_regime_class" ||
         field_name=="volatility_regime_class" ||
         field_name=="expansion_state_class" ||
         field_name=="movement_quality_class" ||
         field_name=="movement_maturity_class" ||
         field_name=="session_phase_class" ||
         field_name=="holding_horizon_context" ||
         field_name=="constructability_class" ||
         field_name=="movement_to_cost_efficiency_class" ||
         field_name=="coverage_rankable_recent_pct" ||
         field_name=="coverage_frontier_recent_pct" ||
         field_name=="history_deep_completion_pct" ||
         field_name=="winner_cache_dependence_pct")
         return ISSX_STAGE_EA2;

      if(StringFind(field_name,"dump_")==0 ||
         StringFind(field_name,"changed_")==0 ||
         StringFind(field_name,"percent_universe_")==0 ||
         field_name=="never_ranked_but_eligible_count" ||
         field_name=="newly_active_symbols_waiting_count" ||
         field_name=="near_cutline_recheck_age_max" ||
         field_name=="current_quote_liveness_state" ||
         field_name=="current_friction_state" ||
         field_name=="spread_state_vs_baseline" ||
         field_name=="activity_transition_state" ||
         field_name=="liquidity_ramp_state" ||
         field_name=="tradability_now_class")
         return ISSX_STAGE_EA1;

      return ISSX_STAGE_SHARED;
     }

   string InferSemanticType(const string field_name) const
     {
      if(StringEndsWith(field_name,"_flag"))
         return "bool";
      if(StringEndsWith(field_name,"_count") || StringEndsWith(field_name,"_depth") || StringEndsWith(field_name,"_bars"))
         return "int";
      if(StringEndsWith(field_name,"_pct") || StringEndsWith(field_name,"_ratio") || StringEndsWith(field_name,"_score") || StringEndsWith(field_name,"_efficiency"))
         return "double";
      if(StringEndsWith(field_name,"_ms"))
         return "int64";
      if(StringEndsWith(field_name,"_sec"))
         return "int";
      if(StringFind(field_name,"_class")>0 || StringFind(field_name,"_state")>0 || StringFind(field_name,"_reason")>0 || StringFind(field_name,"_mode")>0)
         return "enum_string";
      if(StringFind(field_name,"summary")>=0)
         return "summary_string";
      if(StringFind(field_name,"fingerprint")>=0 || StringFind(field_name,"hash")>=0)
         return "hash_hex";
      if(StringFind(field_name,"ids")>=0)
         return "compact_id_list";
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
      if(StringEndsWith(field_name,"_ratio") || StringEndsWith(field_name,"_efficiency"))
         return 4;
      return 0;
     }

   bool InferAllowedNull(const string field_name) const
     {
      if(StringFind(field_name,"summary")>=0 ||
         StringFind(field_name,"reason")>=0 ||
         StringFind(field_name,"limitation")>=0 ||
         StringFind(field_name,"confidence_class")>=0 ||
         StringFind(field_name,"corr_refresh_age")>=0)
         return true;
      return false;
     }

   ISSX_MissingPolicy InferMissingPolicy(const string field_name) const
     {
      if(StringFind(field_name,"summary")>=0 || StringFind(field_name,"limitation")>=0)
         return ISSX_MISSING_ALLOW_NULL;
      if(StringFind(field_name,"corr_")==0 ||
         field_name=="diversification_confidence_class" ||
         field_name=="redundancy_risk_class")
         return ISSX_MISSING_UNKNOWN_MEANS_UNKNOWN;
      return ISSX_MISSING_FORBID;
     }

   ISSX_StalePolicy InferStalePolicy(const string field_name) const
     {
      if(StringFind(field_name,"debug_")==0 || StringFind(field_name,"weakest_")==0 || StringFind(field_name,"why_")==0)
         return ISSX_STALE_DIAGNOSTIC_ONLY;
      if(StringFind(field_name,"history_")==0 || StringFind(field_name,"warehouse_")==0)
         return ISSX_STALE_DEGRADED_ALLOWED;
      if(StringFind(field_name,"quote_")==0 || field_name=="winner_quote_age_sec")
         return ISSX_STALE_STRICT_FRESH;
      if(StringFind(field_name,"rank_")>=0 || StringFind(field_name,"refresh_age")>=0)
         return ISSX_STALE_USABLE_IF_RECENT;
      return ISSX_STALE_CARRY_WITH_AGE;
     }

   ISSX_DirectOrDerived InferDirectOrDerived(const string field_name) const
     {
      if(StringFind(field_name,"history_")==0 ||
         StringFind(field_name,"warehouse_")==0 ||
         StringFind(field_name,"regime")>=0 ||
         StringFind(field_name,"quality")>=0 ||
         StringFind(field_name,"efficiency")>=0 ||
         StringFind(field_name,"confidence")>=0 ||
         StringFind(field_name,"risk")>=0)
         return ISSX_DERIVED;
      return ISSX_DIRECT;
     }

   ISSX_AuthorityLevel InferAuthorityLevel(const string field_name) const
     {
      if(StringFind(field_name,"debug_")==0 ||
         StringFind(field_name,"weakest_")==0 ||
         StringFind(field_name,"why_")==0 ||
         field_name=="selection_latency_risk_class")
         return ISSX_AUTH_DIAGNOSTIC;
      if(StringFind(field_name,"summary")>=0)
         return ISSX_AUTH_DERIVED;
      return ISSX_AUTH_ACCEPTED;
     }

   string InferProjectionPolicy(const string field_name) const
     {
      if(StringFind(field_name,"debug_")==0 || StringFind(field_name,"weakest_")==0)
         return "debug_only";
      if(StringFind(field_name,"winner_")==0 ||
         StringFind(field_name,"selection_")==0 ||
         field_name=="regime_summary" ||
         field_name=="execution_condition_summary" ||
         field_name=="diversification_context_summary")
         return "ea5_export";
      return "internal_and_debug";
     }

   string InferConsumerWarning(const string field_name) const
     {
      if(field_name=="pair_validity_class" ||
         field_name=="pair_sample_alignment_class" ||
         field_name=="pair_window_freshness_class")
         return "Pair metrics are invalid without validity context.";
      if(field_name=="rankability_lane" || field_name=="exploratory_penalty_applied")
         return "Exploratory participation must remain visibly weaker than strong lane truth.";
      if(field_name=="warehouse_clip_flag" || field_name=="effective_lookback_bars" || field_name=="warmup_sufficient_flag")
         return "Metrics near retention/warmup limits must not present as high confidence.";
      if(field_name=="selection_reason_summary" || field_name=="selection_penalty_summary" || field_name=="winner_limitation_summary")
         return "Summary text must stay deterministic, factual, and non-directional.";
      return "";
     }

   bool InferCacheProvenanceRequired(const string field_name) const
     {
      return (StringFind(field_name,"warehouse_")==0 ||
              StringFind(field_name,"history_")==0 ||
              StringFind(field_name,"pair_")==0 ||
              field_name=="effective_lookback_bars" ||
              field_name=="warmup_sufficient_flag");
     }

   bool InferContinuityDerived(const string field_name) const
     {
      return (StringFind(field_name,"fallback_")==0 ||
              StringFind(field_name,"same_tick_")==0 ||
              field_name=="fresh_accept_ratio_1h" ||
              field_name=="family_rep_stability_window");
     }

   bool InferNonDirectional(const string field_name) const
     {
      return (field_name=="intraday_activity_state" ||
              field_name=="liquidity_regime_class" ||
              field_name=="volatility_regime_class" ||
              field_name=="expansion_state_class" ||
              field_name=="movement_quality_class" ||
              field_name=="movement_maturity_class" ||
              field_name=="session_phase_class" ||
              field_name=="tradability_now_class" ||
              field_name=="holding_horizon_context" ||
              field_name=="constructability_class" ||
              field_name=="movement_to_cost_efficiency_class" ||
              field_name=="diversification_confidence_class" ||
              field_name=="redundancy_risk_class" ||
              field_name=="opportunity_with_caution_flag" ||
              field_name=="early_move_quality_class" ||
              field_name=="winner_archetype_class");
     }

   string InferRuntimeStateKind(const string field_name) const
     {
      if(StringFind(field_name,"_class")>0 || StringFind(field_name,"_state")>0 || StringFind(field_name,"_reason")>0 || StringFind(field_name,"_mode")>0)
         return "enum_state";
      if(StringEndsWith(field_name,"_flag"))
         return "boolean_state";
      if(StringEndsWith(field_name,"_count") || StringEndsWith(field_name,"_depth") || StringEndsWith(field_name,"_bars"))
         return "counter_state";
      if(StringEndsWith(field_name,"_pct") || StringEndsWith(field_name,"_ratio") || StringEndsWith(field_name,"_score"))
         return "scalar_state";
      return "value_state";
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
      if(ISSX_Util::IsEmpty(entry.field_name))
         return false;
      if(!ISSX_Enum::StageIsValid(entry.owner_ea))
         return false;
      if(Exists(entry.field_name))
         return false;
      int n=ArraySize(m_items);
      ArrayResize(m_items,n+1);
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
      int idx=IndexOf(field_name);
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
            return ISSX_Validate::Fail(1,"field_name empty");
         if(!ISSX_Enum::StageIsValid(m_items[i].owner_ea))
            return ISSX_Validate::Fail(2,"owner_ea invalid");
         if(ISSX_Util::IsEmpty(m_items[i].semantic_type))
            return ISSX_Validate::Fail(3,"semantic_type empty");
         if(m_items[i].authority_level==ISSX_AUTH_DIAGNOSTIC && m_items[i].direct_or_derived==ISSX_DIRECT)
            return ISSX_Validate::Fail(4,"diagnostic field may not be direct authority");
         if((StringFind(m_items[i].field_name,"warehouse_")==0 || StringFind(m_items[i].field_name,"history_")==0) &&
            !m_items[i].cache_provenance_required)
            return ISSX_Validate::Fail(5,"warehouse/history field missing cache provenance");
         if(m_items[i].non_directional && StringFind(m_items[i].consumer_warning,"directional")>=0)
            return ISSX_Validate::Fail(6,"non-directional field warning invalid");
        }
      return ISSX_Validate::Ok();
     }

   string FingerprintHex() const
     {
      return ISSX_Hash::HashStringHex(ExportCompactJson());
     }

   string ExportCompactJson() const
     {
      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginArray();
      for(int i=0;i<ArraySize(m_items);i++)
        {
         jw.BeginObject();
         jw.NameString("field_name",m_items[i].field_name);
         jw.NameString("owner_ea",ISSX_Enum::StageToString(m_items[i].owner_ea));
         jw.NameString("semantic_type",m_items[i].semantic_type);
         jw.NameString("unit",m_items[i].unit);
         jw.NameInt("precision",m_items[i].precision);
         jw.NameBool("allowed_null",m_items[i].allowed_null);
         jw.NameString("missing_policy",IntegerToString((int)m_items[i].missing_policy));
         jw.NameString("stale_policy",IntegerToString((int)m_items[i].stale_policy));
         jw.NameString("direct_or_derived",IntegerToString((int)m_items[i].direct_or_derived));
         jw.NameString("authority_level",IntegerToString((int)m_items[i].authority_level));
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

   void SeedBlueprintV170()
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
      RegisterBlueprintField(ISSX_FIELD_HIGHEST_BLOCKING_CONTRADICTION);
      RegisterBlueprintField(ISSX_FIELD_COVERAGE_RANKABLE_RECENT_PCT);
      RegisterBlueprintField(ISSX_FIELD_COVERAGE_FRONTIER_RECENT_PCT);
      RegisterBlueprintField(ISSX_FIELD_HISTORY_DEEP_COMPLETION_PCT);
      RegisterBlueprintField(ISSX_FIELD_WINNER_CACHE_DEPENDENCE_PCT);
      RegisterBlueprintField(ISSX_FIELD_CLOCK_DIVERGENCE_SEC);
      RegisterBlueprintField(ISSX_FIELD_SCHEDULER_LATE_BY_MS);
      RegisterBlueprintField(ISSX_FIELD_MISSED_SCHEDULE_WINDOWS_EST);
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
      RegisterBlueprintField(ISSX_FIELD_DIVERSIFICATION_CONFIDENCE);
      RegisterBlueprintField(ISSX_FIELD_REDUNDANCY_RISK_CLASS);
      RegisterBlueprintField(ISSX_FIELD_SELECTION_REASON_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_SELECTION_PENALTY_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_WINNER_LIMITATION_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_WINNER_CONFIDENCE_CLASS);
      RegisterBlueprintField(ISSX_FIELD_OPPORTUNITY_WITH_CAUTION_FLAG);
      RegisterBlueprintField(ISSX_FIELD_EARLY_MOVE_QUALITY_CLASS);
      RegisterBlueprintField(ISSX_FIELD_MOVEMENT_TO_COST_EFFICIENCY);
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
      RegisterBlueprintField(ISSX_FIELD_PERCENT_RANKABLE_REVALIDATED);
      RegisterBlueprintField(ISSX_FIELD_PERCENT_FRONTIER_REVALIDATED);
      RegisterBlueprintField(ISSX_FIELD_NEVER_SERVICED_COUNT);
      RegisterBlueprintField(ISSX_FIELD_OVERDUE_SERVICE_COUNT);
      RegisterBlueprintField(ISSX_FIELD_NEVER_RANKED_BUT_ELIGIBLE_COUNT);
      RegisterBlueprintField(ISSX_FIELD_NEWLY_ACTIVE_SYMBOLS_WAITING);
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
      RegisterBlueprintField(ISSX_FIELD_FRONTIER_REFRESH_LAG_NEW_MOVERS);
      RegisterBlueprintField(ISSX_FIELD_SELECTION_LATENCY_RISK_CLASS);
      RegisterBlueprintField(ISSX_FIELD_NEVER_RANKED_NOW_OBSERVABLE);
      RegisterBlueprintField(ISSX_FIELD_EXPORT_GENERATED_AT);
      RegisterBlueprintField(ISSX_FIELD_EA1_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_EA2_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_EA3_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_EA4_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_SOURCE_GENERATION_IDS);
      RegisterBlueprintField(ISSX_FIELD_WINNER_HISTORY_AGE_BY_TF);
      RegisterBlueprintField(ISSX_FIELD_WINNER_QUOTE_AGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_WINNER_TRADEABILITY_REFRESH_AGE);
      RegisterBlueprintField(ISSX_FIELD_WINNER_RANK_REFRESH_AGE);
      RegisterBlueprintField(ISSX_FIELD_WINNER_REGIME_REFRESH_AGE);
      RegisterBlueprintField(ISSX_FIELD_WINNER_CORR_REFRESH_AGE);
      RegisterBlueprintField(ISSX_FIELD_WINNER_LAST_MATERIAL_CHANGE_SEC);
      RegisterBlueprintField(ISSX_FIELD_REGIME_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_EXECUTION_CONDITION_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_DIVERSIFICATION_CONTEXT_SUMMARY);
      RegisterBlueprintField(ISSX_FIELD_WHY_EXPORT_IS_THIN);
      RegisterBlueprintField(ISSX_FIELD_WHY_PUBLISH_IS_STALE);
      RegisterBlueprintField(ISSX_FIELD_WHY_FRONTIER_IS_SMALL);
      RegisterBlueprintField(ISSX_FIELD_WHY_INTELLIGENCE_ABSTAINED);
      RegisterBlueprintField(ISSX_FIELD_LARGEST_BACKLOG_OWNER);
      RegisterBlueprintField(ISSX_FIELD_OLDEST_UNSERVED_QUEUE_FAMILY);
     }

   void SeedBlueprintV150()
     {
      SeedBlueprintV170();
     }
  };

// ============================================================================
// SECTION 03: ENUM REGISTRY
// ============================================================================

class ISSX_EnumRegistry
  {
private:
   ISSX_EnumMetadataEntry m_items[];

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
      if(ISSX_Util::IsEmpty(enum_name))
         return false;
      for(int i=0;i<ArraySize(m_items);i++)
         if(m_items[i].enum_name==enum_name)
            return false;
      int n=ArraySize(m_items);
      ArrayResize(m_items,n+1);
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
            return ISSX_Validate::Fail(10,"enum_name empty");
         if(ISSX_Util::IsEmpty(m_items[i].allowed_values_csv))
            return ISSX_Validate::Fail(11,"allowed_values_csv empty");
        }
      return ISSX_Validate::Ok();
     }

   string FingerprintHex() const
     {
      return ISSX_Hash::HashStringHex(ExportCompactJson());
     }

   string ExportCompactJson() const
     {
      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginArray();
      for(int i=0;i<ArraySize(m_items);i++)
        {
         jw.BeginObject();
         jw.NameString("enum_name",m_items[i].enum_name);
         jw.NameString("allowed_values_csv",m_items[i].allowed_values_csv);
         jw.NameString("compact_description",m_items[i].compact_description);
         jw.EndObject();
        }
      jw.EndArray();
      return jw.ToString();
     }

   void SeedBlueprintV170()
     {
      Reset();
      Add("stage_publishability_state","not_ready,minimum_ready,degraded,publishable,blocked","Stage output readiness and public publishability.");
      Add("upstream_handoff_mode","none,same_tick_memory,accepted_current,accepted_previous,last_good,public_projection","Visibility-preserving upstream source mode.");
      Add("warehouse_quality","unknown,thin,warming,usable,strong,clipped,unstable","History warehouse quality class.");
      Add("debug_weak_link_code","none,dependency,backlog,starvation,fallback,rejection,contradiction,publish,clock,queue,rewrite,coverage","Stage weak-link reason code.");
      Add("compatibility_class","incompatible,structural_only,semantic_degraded,compatible,compatible_policy_locked","Structural/semantic/policy compatibility outcome.");
      Add("contradiction_class","none,identity,session,spec,history_continuity,selection_ownership,intelligence_validity","Minimum contradiction taxonomy.");
      Add("rankability_lane","strong,usable,exploratory,blocked","Elastic rankability lane for EA3.");
      Add("pair_validity_class","valid_low_overlap,valid_high_overlap,unknown_overlap,provisional_overlap,blocked_overlap","Pair-overlap validity surface.");
      Add("pair_sample_alignment_class","aligned,strongly_aligned,partially_aligned,misaligned,unknown","Pair sample/bar alignment quality.");
      Add("pair_window_freshness_class","fresh,usable,aging,stale,unknown","Freshness of pair evidence window.");
      Add("intraday_activity_state","dormant,waking,active,elevated,dislocated,unknown","Neutral intraday activity state.");
      Add("liquidity_regime_class","poor,acceptable,strong,stressed,fragmented,unknown","Neutral liquidity regime.");
      Add("volatility_regime_class","compressed,normal,expanding,extended,dislocated,unknown","Neutral volatility regime.");
      Add("expansion_state_class","compressed,normal,expanding,extended,recovering,unknown","Neutral expansion state.");
      Add("movement_quality_class","orderly,acceptable,noisy,fragmented,rotational,unknown","Neutral movement cleanliness.");
      Add("movement_maturity_class","early,developing,mature,late,recovering,unknown","Neutral movement maturity.");
      Add("session_phase_class","pre_open,opening,active,late,close,closed,unknown","Neutral session phase.");
      Add("tradability_now_class","blocked,poor,acceptable,strong,cautious,unknown","Current tradability-now state.");
      Add("holding_horizon_context","very_short_intraday,short_intraday,mixed_intraday,extended_intraday,unknown","Neutral holding horizon context.");
      Add("constructability_class","poor,acceptable,strong,fragile,unknown","Neutral intraday constructability.");
      Add("diversification_confidence_class","none,low,moderate,high,unknown","Confidence in diversification evidence.");
      Add("redundancy_risk_class","low,moderate,high,severe,unknown","Redundancy risk class.");
      Add("winner_confidence_class","strong,usable,exploratory,degraded,blocked","Winner confidence surface.");
      Add("history_readiness_state","never_requested,requested_sync,partial_available,syncing,compare_unsafe,compare_safe_degraded,compare_safe_strong,degraded_unstable,blocked","EA2 history readiness state.");
      Add("finality_state","stable,watch,unstable,recovering,unknown","Completed-bar finality class.");
      Add("rewrite_class","benign_last_bar_adjustment,short_tail_rewrite,structural_gap_rewrite,historical_block_rewrite","History rewrite classification.");
      Add("session_truth_class","declared_only,observed_supported,contradictory,unknown","Layered session truth support.");
      Add("hydration_menu_class","bootstrap,delta_first,backlog_clearing,continuity_preserving,publish_critical,optional_enrichment","Hydration menu scheduling class.");
      Add("invalidation_class","quote_freshness_invalidation,tradeability_invalidation,session_boundary_invalidation,history_sync_invalidation,frontier_member_change,family_representative_change,policy_change_invalidation,clock_anomaly_invalidation,activity_regime_invalidation","Invalidation trigger family.");
      Add("trace_severity","error,warn,state_change,sampled_info","Structured trace severity tier.");
      Add("content_class","snapshot,dump,warehouse,index,projection,debug,contract,cache,continuity,phase,queue","Persistence content class.");
      Add("publish_reason","scheduled,deadline,material_change,recovery,heartbeat,manual,dependency_released,forced_minimum_ready","Why a stage published.");
      Add("authority_level","authoritative,accepted,derived,diagnostic","Registry authority level semantic.");
      Add("direct_or_derived","direct,derived,mixed","Field provenance class.");
      Add("missing_policy","forbid,allow_null,allow_missing,unknown_means_unknown","Missing/null semantic handling.");
      Add("stale_policy","strict_fresh,usable_if_recent,carry_with_age,degraded_allowed,diagnostic_only","Stale-data policy.");
     }

   void SeedBlueprintV150()
     {
      SeedBlueprintV170();
     }
  };

// ============================================================================
// SECTION 04: COMPARATOR REGISTRY
// ============================================================================

class ISSX_ComparatorRegistry
  {
private:
   ISSX_ComparatorMetadataEntry m_items[];

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
      if(ISSX_Util::IsEmpty(comparator_id))
         return false;
      for(int i=0;i<ArraySize(m_items);i++)
         if(m_items[i].comparator_id==comparator_id)
            return false;
      int n=ArraySize(m_items);
      ArrayResize(m_items,n+1);
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
         if(ISSX_Util::IsEmpty(m_items[i].comparator_id))
            return ISSX_Validate::Fail(20,"comparator_id empty");
      return ISSX_Validate::Ok();
     }

   string FingerprintHex() const
     {
      return ISSX_Hash::HashStringHex(ExportCompactJson());
     }

   string ExportCompactJson() const
     {
      ISSX_JsonWriter jw;
      jw.Reset();
      jw.BeginArray();
      for(int i=0;i<ArraySize(m_items);i++)
        {
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

   void SeedBlueprintV170()
     {
      Reset();
      Add("cmp_stable_universe","Stable Universe","shared","canonical universe ordering and fingerprint determinism for compatibility, drift, and cohort hashing","transient selection order must never affect fingerprints",true);
      Add("cmp_preferred_variant","Preferred Variant","ea1","family representative selection across normalized identity, observability, execution profile, continuity, and friction baseline","one-cycle noise may not switch the published representative",true);
      Add("cmp_rankability_lane","Rankability Lane","ea3","strong then usable then exploratory lane participation with visible confidence caps and explicit blocking","exploratory may compete but never masquerade as strong",true);
      Add("cmp_bucket_membership","Bucket Membership","ea3","family collapse, truth floor, bucket admission, and breadth-with-honesty eligibility","hard exclusion reserved for severe integrity failures",true);
      Add("cmp_bucket_local","Bucket Local","ea3","non-directional ranking across truth, friction, activity, volatility usability, constructability, freshness, and continuity near ties","weak buckets publish fewer than five instead of forced filler",true);
      Add("cmp_diversity_tiebreak","Diversity Tie-Break","ea3","bounded soft redundancy penalties within comparable quality bands using family, regime, session-shape, and behavior similarity","difference alone may not leapfrog a materially stronger candidate",true);
      Add("cmp_frontier_promotion","Frontier Promotion","ea3","frontier maintenance using survivor continuity, near-cutline pressure, contender uplift, and bounded replacement discipline","stale campers decay and may yield to fresher contenders",true);
      Add("cmp_sparse_peer_priority","Sparse Peer Priority","ea4","pair servicing by changed-pair priority, validity class, freshness, overlap promise, TTL, and abstention memory","unknown overlap must not be treated as low overlap",true);
      Add("cmp_final_survivor","Final Survivor","ea5","selection backbone merged with source visibility, contradiction penalties, and bounded intelligence context","winner context remains descriptive and non-directional",true);
     }

   void SeedBlueprintV150()
     {
      SeedBlueprintV170();
     }
  };

// ============================================================================
// SECTION 05: REGISTRY BUNDLE
// ============================================================================

class ISSX_RegistryBundle
  {
public:
   ISSX_FieldRegistry      fields;
   ISSX_EnumRegistry       enums;
   ISSX_ComparatorRegistry comparators;

   void SeedBlueprintV170()
     {
      fields.SeedBlueprintV170();
      enums.SeedBlueprintV170();
      comparators.SeedBlueprintV170();
     }

   void SeedBlueprintV150()
     {
      SeedBlueprintV170();
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
      return r;
     }

   string SchemaFingerprintHex() const
     {
      return ISSX_Hash::HashStringHex(fields.FingerprintHex()+"|"+enums.FingerprintHex()+"|"+comparators.FingerprintHex());
     }
  };

#endif // __ISSX_REGISTRY_MQH__
