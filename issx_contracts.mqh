#ifndef __ISSX_CONTRACTS_MQH__
#define __ISSX_CONTRACTS_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>
#include <ISSX/issx_market_engine.mqh>
#include <ISSX/issx_history_engine.mqh>
#include <ISSX/issx_selection_engine.mqh>
#include <ISSX/issx_correlation_engine.mqh>

#define ISSX_CONTRACTS_MODULE_VERSION            "1.732"
#define ISSX_CONTRACTS_STAGE_API_VERSION         "1.718"
#define ISSX_CONTRACTS_SERIALIZER_VERSION        "1.718"
#define ISSX_CONTRACTS_EXTERNAL_CONTRACT_VERSION "ea5_v1.723"
#define ISSX_CONTRACTS_OWNER_MODULE_NAME         "issx_contracts.mqh"
#define ISSX_CONTRACTS_FINGERPRINT_ALGO_VERSION  "utf8_canonical_v1"
#define ISSX_CONTRACTS_SOURCE_SNAPSHOT_ACCEPTED  "accepted_snapshot"
#define ISSX_CONTRACTS_SOURCE_SNAPSHOT_SAME_TICK "same_tick_accepted"
#define ISSX_EA5_MAX_EXPLAIN_REASONS             3
#define ISSX_EA5_DEFAULT_TARGET_BYTES            196608
#define ISSX_EA5_DEFAULT_HARD_MAX_BYTES          262144
#define ISSX_EA5_DEFAULT_PER_SYMBOL_BYTES        4096
#define ISSX_EA5_DEFAULT_MAX_BARS_TOTAL          32
#define ISSX_EA5_MAX_CONTRACTS_HARD_CAP          64

enum ISSX_EA5_AnswerMode
  {
   issx_ea5_answer_selection_first = 0,
   issx_ea5_answer_intelligence_enriched,
   issx_ea5_answer_degraded_selection_only
  };

enum ISSX_EA5_ExportProfile
  {
   issx_ea5_export_compact = 0,
   issx_ea5_export_standard,
   issx_ea5_export_intraday_rich
  };

struct ISSX_EA5_PayloadBudget
  {
   int target_bytes;
   int hard_max_bytes;
   int per_symbol_target_bytes;
   int max_bars_per_symbol_total;
   void Reset(){ target_bytes=ISSX_EA5_DEFAULT_TARGET_BYTES; hard_max_bytes=ISSX_EA5_DEFAULT_HARD_MAX_BYTES; per_symbol_target_bytes=ISSX_EA5_DEFAULT_PER_SYMBOL_BYTES; max_bars_per_symbol_total=ISSX_EA5_DEFAULT_MAX_BARS_TOTAL; }
  };

struct ISSX_EA5_AgeSurface
  {
   datetime export_generated_at;
   int ea1_age_sec;
   int ea2_age_sec;
   int ea3_age_sec;
   int ea4_age_sec;
   string source_generation_ids;
   void Reset(){ export_generated_at=0; ea1_age_sec=0; ea2_age_sec=0; ea3_age_sec=0; ea4_age_sec=-1; source_generation_ids=""; }
  };

struct ISSX_EA5_SourceSummary
  {
   string ea1_source_used;
   string ea2_source_used;
   string ea3_source_used;
   string ea4_source_used;
   ISSX_CohortState cohort_state;
   int max_fallback_depth_used;
   ISSX_CompatibilityClass compatibility_worst_class;
   ISSX_CompatibilityClass upstream_handoff_compatibility_class;
   bool recovery_publish_flag;
   ISSX_HandoffMode upstream_handoff_mode;
   bool upstream_handoff_same_tick_flag;
   bool upstream_partial_progress_flag;
   long upstream_handoff_sequence_no;
   string upstream_payload_hash;
   string upstream_policy_fingerprint;
   string source_snapshot_kind;
   bool ea4_attached_flag;
   bool ea4_abstained_flag;
   int ea4_signal_count;
   double fallback_read_ratio_1h;
   double fresh_accept_ratio_1h;
   double same_tick_handoff_ratio_1h;
   void Reset()
     {
      ea1_source_used=""; ea2_source_used=""; ea3_source_used=""; ea4_source_used="";
      cohort_state=issx_cohort_degraded;
      max_fallback_depth_used=0;
      compatibility_worst_class=issx_compatibility_incompatible;
      upstream_handoff_compatibility_class=issx_compatibility_incompatible;
      recovery_publish_flag=false;
      upstream_handoff_mode=issx_handoff_none;
      upstream_handoff_same_tick_flag=false;
      upstream_partial_progress_flag=false;
      upstream_handoff_sequence_no=0;
      upstream_payload_hash="";
      upstream_policy_fingerprint="";
      source_snapshot_kind=ISSX_CONTRACTS_SOURCE_SNAPSHOT_ACCEPTED;
      ea4_attached_flag=false;
      ea4_abstained_flag=true;
      ea4_signal_count=0;
      fallback_read_ratio_1h=0.0;
      fresh_accept_ratio_1h=0.0;
      same_tick_handoff_ratio_1h=0.0;
     }
  };

struct ISSX_EA5_ContradictionSummary
  {
   int contradiction_count;
   ISSX_ContradictionSeverity contradiction_severity_max;
   bool blocking_contradiction_present;
   string major_contradiction_flags;
   string contradiction_class_counts;
   string highest_blocking_contradiction_class;
   string contradiction_repair_state;
   void Reset()
     {
      contradiction_count=0;
      contradiction_severity_max=issx_contradiction_low;
      blocking_contradiction_present=false;
      major_contradiction_flags="";
      contradiction_class_counts="identity:0|session:0|spec:0|history_continuity:0|selection_ownership:0|intelligence_validity:0";
      highest_blocking_contradiction_class="none";
      contradiction_repair_state="none";
     }
  };

struct ISSX_EA5_MarketReadinessSummary
  {
   ISSX_TruthClass system_truth_class;
   ISSX_FreshnessClass system_freshness_class;
   ISSX_PublishabilityState system_publishability_state;
   int market_breadth_publishable;
   string bucket_coverage_quality;
   string dominant_degradation_reason;
   string dominant_penalty_family;
   bool safe_to_reason_normally;
   void Reset()
     {
      system_truth_class=issx_truth_weak;
      system_freshness_class=issx_freshness_stale;
      system_publishability_state=issx_publishability_not_ready;
      market_breadth_publishable=0;
      bucket_coverage_quality="unknown";
      dominant_degradation_reason="not_ready";
      dominant_penalty_family="unknown";
      safe_to_reason_normally=false;
     }
  };

struct ISSX_EA5_IntegrityBlock
  {
   bool present;
   bool usable;
   bool degraded;
   ISSX_AuthorityLevel authority_level;
   string primary_reason_if_not_usable;
   void Reset(){ present=false; usable=false; degraded=false; authority_level=issx_authority_degraded; primary_reason_if_not_usable=""; }
  };

struct ISSX_EA5_IntegrityTable
  {
   ISSX_EA5_IntegrityBlock classification;
   ISSX_EA5_IntegrityBlock observability;
   ISSX_EA5_IntegrityBlock tradeability;
   ISSX_EA5_IntegrityBlock session;
   ISSX_EA5_IntegrityBlock market;
   ISSX_EA5_IntegrityBlock history;
   ISSX_EA5_IntegrityBlock bucket_selection;
   ISSX_EA5_IntegrityBlock intelligence;
   ISSX_EA5_IntegrityBlock final_context;
   void Reset(){ classification.Reset(); observability.Reset(); tradeability.Reset(); session.Reset(); market.Reset(); history.Reset(); bucket_selection.Reset(); intelligence.Reset(); final_context.Reset(); }
  };

struct ISSX_EA5_ComparisonContract
  {
   bool safe_to_compare_bucket_score;
   bool safe_to_compare_final_rank;
   bool safe_to_compare_history_metrics;
   string comparison_limitations;
   double comparison_completeness_score;
   void Reset(){ safe_to_compare_bucket_score=false; safe_to_compare_final_rank=false; safe_to_compare_history_metrics=false; comparison_limitations=""; comparison_completeness_score=0.0; }
  };

struct ISSX_EA5_DecisionNeutrality
  {
   bool contains_directional_opinion;
   bool contains_trade_instruction;
   bool contains_execution_logic;
   bool contains_bias_projection;
   bool suitable_for_human_or_model_judgment;
   void Reset(){ contains_directional_opinion=false; contains_trade_instruction=false; contains_execution_logic=false; contains_bias_projection=false; suitable_for_human_or_model_judgment=true; }
  };

struct ISSX_EA5_OhlcBar
  {
   datetime t;
   double o;
   double h;
   double l;
   double c;
   long v;
   string s;
   void Reset(){ t=0; o=0.0; h=0.0; l=0.0; c=0.0; v=0; s=""; }
  };

struct ISSX_EA5_CompactOhlcPack
  {
   string pack_version;
   bool has_data;
   bool completed_bars_only;
   string source_note;
   ISSX_EA5_OhlcBar m5_last_12[];
   ISSX_EA5_OhlcBar m15_last_12[];
   ISSX_EA5_OhlcBar h1_last_8[];
   void Reset(){ pack_version="v1"; has_data=false; completed_bars_only=true; source_note="unavailable"; ArrayResize(m5_last_12,0); ArrayResize(m15_last_12,0); ArrayResize(h1_last_8,0); }
  };

struct ISSX_EA5_OptionalIntelligence
  {
   string symbol_norm;
   bool present;
   double nearest_peer_similarity;
   bool corr_valid;
   double corr_quality_score;
   string corr_reject_reason;
   bool duplicate_penalty_applied;
   bool corr_penalty_applied;
   bool session_overlap_penalty_applied;
   bool diversification_bonus_applied;
   double adjustment_confidence;
   ISSX_PortfolioRoleHint portfolio_role_hint;
   double structural_overlap_score;
   double statistical_overlap_score;
   bool intelligence_abstained;
   string abstention_reason;
   double intelligence_confidence;
   double intelligence_coverage_score;
   string pair_cache_status;
   string pair_cache_reuse_block_reason;
   string pair_validity_class;
   string pair_sample_alignment_class;
   string pair_window_freshness_class;
   string pair_regime_comparability_class;
   int sample_count;
   string diversification_confidence_class;
   string redundancy_risk_class;
   void Reset()
     {
      symbol_norm=""; present=false; nearest_peer_similarity=0.0; corr_valid=false; corr_quality_score=0.0;
      corr_reject_reason="not_available"; duplicate_penalty_applied=false; corr_penalty_applied=false; session_overlap_penalty_applied=false;
      diversification_bonus_applied=false; adjustment_confidence=0.0; portfolio_role_hint=issx_role_anchor;
      structural_overlap_score=0.0; statistical_overlap_score=0.0; intelligence_abstained=true; abstention_reason="ea4_not_attached";
      intelligence_confidence=0.0; intelligence_coverage_score=0.0; pair_cache_status="unavailable"; pair_cache_reuse_block_reason="ea4_not_attached";
      pair_validity_class="unknown_overlap"; pair_sample_alignment_class="unknown"; pair_window_freshness_class="unknown"; pair_regime_comparability_class="unknown";
      sample_count=0; diversification_confidence_class="unknown"; redundancy_risk_class="unknown";
     }
  };

struct ISSX_EA5_QualityState
  {
   ISSX_TruthClass truth_class;
   string truth_breakdown;
   ISSX_FreshnessClass freshness_class;
   string freshness_breakdown;
   double completeness_score;
   double comparison_completeness_score;
   double final_rank_confidence;
   double judgment_readiness_score;
   string authority_level_summary;
   ISSX_ContinuityOrigin continuity_origin;
   bool resumed_from_persistence;
   void Reset()
     {
      truth_class=issx_truth_weak; truth_breakdown=""; freshness_class=issx_freshness_stale; freshness_breakdown="";
      completeness_score=0.0; comparison_completeness_score=0.0; final_rank_confidence=0.0; judgment_readiness_score=0.0;
      authority_level_summary=""; continuity_origin=issx_continuity_fresh_boot; resumed_from_persistence=false;
     }
  };

struct ISSX_EA5_ContextState
  {
   double range_20m_points;
   double range_60m_points;
   double range_240m_points;
   double distance_from_day_open_points;
   double distance_from_prev_close_points;
   double pct_of_day_range;
   double pct_of_20m_range;
   double pct_of_60m_range;
   double pct_of_240m_range;
   double micro_noise_risk;
   double structure_clarity_score;
   double compression_score;
   double expansion_score;
   double breakout_proximity_score;
   double structure_stability_score;
   double holding_window_fit_20_60m;
   double holding_window_fit_60_180m;
   double holding_window_fit_180_480m;
   datetime session_open;
   double day_open;
   double rolling_1h_high;
   double rolling_1h_low;
   double rolling_4h_high;
   double rolling_4h_low;
   double range_position_day;
   double range_position_4h;
   double bar_progress_m5_pct;
   double bar_progress_m15_pct;
   string why_selected_top3;
   string why_penalized_top3;
   string why_not_higher_top3;
   string key_use_constraints;
   string symbol_digest;
   void Reset()
     {
      range_20m_points=0.0; range_60m_points=0.0; range_240m_points=0.0; distance_from_day_open_points=0.0; distance_from_prev_close_points=0.0;
      pct_of_day_range=0.0; pct_of_20m_range=0.0; pct_of_60m_range=0.0; pct_of_240m_range=0.0; micro_noise_risk=0.0;
      structure_clarity_score=0.0; compression_score=0.0; expansion_score=0.0; breakout_proximity_score=0.0; structure_stability_score=0.0;
      holding_window_fit_20_60m=0.0; holding_window_fit_60_180m=0.0; holding_window_fit_180_480m=0.0;
      session_open=0; day_open=0.0; rolling_1h_high=0.0; rolling_1h_low=0.0; rolling_4h_high=0.0; rolling_4h_low=0.0;
      range_position_day=0.0; range_position_4h=0.0; bar_progress_m5_pct=0.0; bar_progress_m15_pct=0.0;
      why_selected_top3=""; why_penalized_top3=""; why_not_higher_top3=""; key_use_constraints=""; symbol_digest="";
     }
  };

struct ISSX_EA5_ComparativeState
  {
   double bucket_local_composite;
   int bucket_rank;
   int bucket_top5_rank;
   bool won_by_strength;
   bool won_by_shortfall;
   bool won_on_hysteresis_only_flag;
   double bucket_competition_percentile;
   int bucket_member_quality_rank;
   double nearest_reserve_gap;
   string position_security_class;
   string frontier_entry_reason_primary;
   double frontier_confidence;
   string rankability_lane;
   bool exploratory_penalty_applied;
   double bucket_redundancy_penalty;
   string winner_archetype_class;
   bool reserve_promoted_for_diversity_flag;
   string redundancy_swap_reason;
   double nearest_peer_similarity;
   bool corr_valid;
   double corr_quality_score;
   string corr_reject_reason;
   bool duplicate_penalty_applied;
   bool corr_penalty_applied;
   bool session_overlap_penalty_applied;
   bool diversification_bonus_applied;
   double adjustment_confidence;
   string portfolio_role_hint;
   double structural_overlap_score;
   double statistical_overlap_score;
   string pair_validity_class;
   string pair_sample_alignment_class;
   string pair_window_freshness_class;
   string pair_regime_comparability_class;
   int sample_count;
   bool intelligence_abstained;
   string abstention_reason;
   string diversification_confidence_class;
   string redundancy_risk_class;
   double selection_utility_base_score;
   int final_rank;
   double marginal_value_score;
   void Reset()
     {
      bucket_local_composite=0.0; bucket_rank=0; bucket_top5_rank=0; won_by_strength=false; won_by_shortfall=false; won_on_hysteresis_only_flag=false;
      bucket_competition_percentile=0.0; bucket_member_quality_rank=0; nearest_reserve_gap=0.0; position_security_class="unknown"; frontier_entry_reason_primary="not_set";
      frontier_confidence=0.0; rankability_lane="blocked"; exploratory_penalty_applied=false; bucket_redundancy_penalty=0.0; winner_archetype_class="unknown";
      reserve_promoted_for_diversity_flag=false; redundancy_swap_reason="none"; nearest_peer_similarity=0.0; corr_valid=false; corr_quality_score=0.0;
      corr_reject_reason="not_available"; duplicate_penalty_applied=false; corr_penalty_applied=false; session_overlap_penalty_applied=false; diversification_bonus_applied=false;
      adjustment_confidence=0.0; portfolio_role_hint="unknown"; structural_overlap_score=0.0; statistical_overlap_score=0.0; pair_validity_class="unknown_overlap";
      pair_sample_alignment_class="unknown"; pair_window_freshness_class="unknown"; pair_regime_comparability_class="unknown"; sample_count=0; intelligence_abstained=true;
      abstention_reason="ea4_not_attached"; diversification_confidence_class="unknown"; redundancy_risk_class="unknown";
      selection_utility_base_score=0.0; final_rank=0; marginal_value_score=0.0;
     }
  };

struct ISSX_EA5_WinnerFreshnessSurface
  {
   int winner_history_age_m5_sec;
   int winner_history_age_m15_sec;
   int winner_history_age_h1_sec;
   string winner_history_age_by_tf;
   int winner_quote_age_sec;
   int winner_tradeability_refresh_age_sec;
   int winner_rank_refresh_age_sec;
   int winner_regime_refresh_age_sec;
   int winner_corr_refresh_age_sec;
   int winner_last_material_change_sec;
   void Reset()
     {
      winner_history_age_m5_sec=0; winner_history_age_m15_sec=0; winner_history_age_h1_sec=0; winner_history_age_by_tf="m5:0|m15:0|h1:0";
      winner_quote_age_sec=0; winner_tradeability_refresh_age_sec=0; winner_rank_refresh_age_sec=0; winner_regime_refresh_age_sec=0; winner_corr_refresh_age_sec=-1; winner_last_material_change_sec=0;
     }
  };

struct ISSX_EA5_WinnerRegimeBlock
  {
   string intraday_activity_state;
   string liquidity_regime_class;
   string volatility_regime_class;
   string expansion_state_class;
   string movement_quality_class;
   string movement_maturity_class;
   string session_phase_class;
   string tradability_now_class;
   string constructability_class;
   string holding_horizon_context;
   string movement_to_cost_efficiency_class;
   string early_move_quality_class;
   string diversification_confidence_class;
   string redundancy_risk_class;
   bool opportunity_with_caution_flag;
   void Reset()
     {
      intraday_activity_state="unknown"; liquidity_regime_class="unknown"; volatility_regime_class="unknown"; expansion_state_class="unknown";
      movement_quality_class="unknown"; movement_maturity_class="unknown"; session_phase_class="unknown"; tradability_now_class="unknown";
      constructability_class="unknown"; holding_horizon_context="unknown"; movement_to_cost_efficiency_class="unknown"; early_move_quality_class="unknown";
      diversification_confidence_class="unknown"; redundancy_risk_class="unknown"; opportunity_with_caution_flag=false;
     }
  };

struct ISSX_EA5_WinnerExplanationBlock
  {
   string selection_reason_summary;
   string selection_penalty_summary;
   string regime_summary;
   string execution_condition_summary;
   string diversification_context_summary;
   string winner_limitation_summary;
   string winner_confidence_class;
   void Reset(){ selection_reason_summary=""; selection_penalty_summary=""; regime_summary=""; execution_condition_summary=""; diversification_context_summary=""; winner_limitation_summary=""; winner_confidence_class="unknown"; }
  };

struct ISSX_EA5_SymbolContract
  {
   string symbol_raw;
   string symbol_norm;
   string canonical_root;
   string alias_family_id;
   string market_representation_id;
   string asset_class;
   string instrument_family;
   string theme_bucket;
   string equity_sector;
   string leader_bucket_id;
   string leader_bucket_type;
   double classification_reliability_score;
   string taxonomy_action_taken;
   string practical_market_state;
   string practical_market_state_reason_codes;
   double runtime_truth_score;
   double observation_density_score;
   double point;
   double tick_size;
   double contract_size;
   double volume_min;
   double volume_step;
   int stops_level;
   int freeze_level;
   string session_reconciliation_state;
   double session_truth_confidence;
   string session_phase;
   int minutes_since_session_open;
   int minutes_to_session_close;
   bool transition_penalty_active;
   double bid;
   double ask;
   double mid;
   double spread_now_points;
   double spread_median_short_points;
   double spread_p90_short_points;
   double spread_widening_ratio;
   double quote_interval_median_ms;
   double quote_interval_p90_ms;
   double quote_stall_rate;
   string tradeability_class;
   double structural_tradeability_score;
   double live_tradeability_score;
   double blended_tradeability_score;
   double entry_cost_score;
   double size_practicality_score;
   double economic_consistency_score;
   double all_in_cost_confidence;
   string commission_state;
   string swap_state;
   double history_data_quality_score;
   string tf_m5_trust;
   string tf_m15_trust;
   string tf_h1_trust;
   string history_provenance;
   string history_judgment_packet;
   ISSX_EA5_CompactOhlcPack compact_ohlc_pack;
   ISSX_EA5_ComparativeState comparative_state;
   ISSX_EA5_QualityState quality_state;
   ISSX_EA5_ContextState context_state;
   ISSX_EA5_IntegrityTable integrity_table;
   ISSX_EA5_ComparisonContract comparison_contract;
   ISSX_EA5_DecisionNeutrality decision_neutrality;
   ISSX_EA5_WinnerFreshnessSurface freshness_surface;
   ISSX_EA5_WinnerRegimeBlock regime_block;
   ISSX_EA5_WinnerExplanationBlock explanation_block;
   void Reset()
     {
      symbol_raw=""; symbol_norm=""; canonical_root=""; alias_family_id=""; market_representation_id="";
      asset_class=""; instrument_family=""; theme_bucket=""; equity_sector=""; leader_bucket_id=""; leader_bucket_type="unknown"; classification_reliability_score=0.0; taxonomy_action_taken="";
      practical_market_state="blocked"; practical_market_state_reason_codes=""; runtime_truth_score=0.0; observation_density_score=0.0;
      point=0.0; tick_size=0.0; contract_size=0.0; volume_min=0.0; volume_step=0.0; stops_level=0; freeze_level=0;
      session_reconciliation_state="unknown"; session_truth_confidence=0.0; session_phase="unknown"; minutes_since_session_open=0; minutes_to_session_close=0; transition_penalty_active=false;
      bid=0.0; ask=0.0; mid=0.0; spread_now_points=0.0; spread_median_short_points=0.0; spread_p90_short_points=0.0; spread_widening_ratio=0.0; quote_interval_median_ms=0.0; quote_interval_p90_ms=0.0; quote_stall_rate=0.0;
      tradeability_class="blocked"; structural_tradeability_score=0.0; live_tradeability_score=0.0; blended_tradeability_score=0.0; entry_cost_score=0.0; size_practicality_score=0.0; economic_consistency_score=0.0; all_in_cost_confidence=0.0; commission_state="unknown"; swap_state="unknown";
      history_data_quality_score=0.0; tf_m5_trust="cold"; tf_m15_trust="cold"; tf_h1_trust="cold"; history_provenance=""; history_judgment_packet="";
      compact_ohlc_pack.Reset(); comparative_state.Reset(); quality_state.Reset(); context_state.Reset(); integrity_table.Reset(); comparison_contract.Reset(); decision_neutrality.Reset(); freshness_surface.Reset(); regime_block.Reset(); explanation_block.Reset();
     }
  };

struct ISSX_EA5_State
  {
   ISSX_StageHeader header;
   ISSX_Manifest manifest;
   ISSX_RuntimeState runtime;
   ISSX_EA5_PayloadBudget payload_budget;
   ISSX_EA5_AnswerMode answer_mode;
   ISSX_EA5_ExportProfile export_profile;
   ISSX_EA5_SourceSummary source_summary;
   ISSX_EA5_AgeSurface age_surface;
   ISSX_EA5_ContradictionSummary contradiction_summary;
   ISSX_EA5_MarketReadinessSummary market_readiness_summary;
   string stage_api_version;
   string serializer_version;
   string owner_module_name;
   string owner_module_hash;
   string fingerprint_algorithm_version;
   string source_snapshot_kind;
   string external_contract_version;
   string why_export_is_thin;
   string why_publish_is_stale;
   string why_frontier_is_small;
   string why_intelligence_abstained;
   string largest_backlog_owner;
   string oldest_unserved_queue_family;
   bool legend_present;
   string legend_hash;
   bool degraded_flag;
   bool projection_partial_success_flag;
   int symbol_count;
   int debug_discovery_attempt_count;
   int debug_candidate_selected_count;
   int debug_symbols_started_count;
   int debug_symbols_completed_count;
   int debug_contract_build_count;
   int debug_skipped_missing_ea1_count;
   int debug_skipped_missing_ea2_count;
   int debug_skipped_capacity_count;
   int debug_optional_intelligence_count;
   int debug_batch_cap;
   int debug_estimated_export_bytes;
   bool debug_batch_truncated;
   string debug_batch_progress;
   string debug_ready_state;
   string debug_partial_state;
   string debug_error_conditions;
   string debug_persistence_interactions;
   ISSX_EA5_SymbolContract symbols[];
   void Reset()
     {
      ZeroMemory(header); ZeroMemory(manifest); runtime.Reset(); payload_budget.Reset();
      answer_mode=issx_ea5_answer_degraded_selection_only; export_profile=issx_ea5_export_standard; source_summary.Reset(); age_surface.Reset(); contradiction_summary.Reset(); market_readiness_summary.Reset();
      stage_api_version=ISSX_CONTRACTS_STAGE_API_VERSION; serializer_version=ISSX_CONTRACTS_SERIALIZER_VERSION; owner_module_name=ISSX_CONTRACTS_OWNER_MODULE_NAME; owner_module_hash="";
      fingerprint_algorithm_version=ISSX_CONTRACTS_FINGERPRINT_ALGO_VERSION; source_snapshot_kind=ISSX_CONTRACTS_SOURCE_SNAPSHOT_ACCEPTED; external_contract_version=ISSX_CONTRACTS_EXTERNAL_CONTRACT_VERSION;
      why_export_is_thin=""; why_publish_is_stale=""; why_frontier_is_small=""; why_intelligence_abstained=""; largest_backlog_owner="na"; oldest_unserved_queue_family="na";
      legend_present=false; legend_hash=""; degraded_flag=false; projection_partial_success_flag=false; symbol_count=0;
      debug_discovery_attempt_count=0; debug_candidate_selected_count=0; debug_symbols_started_count=0; debug_symbols_completed_count=0; debug_contract_build_count=0;
      debug_skipped_missing_ea1_count=0; debug_skipped_missing_ea2_count=0; debug_skipped_capacity_count=0; debug_optional_intelligence_count=0;
      debug_batch_cap=0; debug_estimated_export_bytes=0; debug_batch_truncated=false; debug_batch_progress="0/0";
      debug_ready_state="not_ready"; debug_partial_state="none"; debug_error_conditions="none"; debug_persistence_interactions="none";
      ArrayResize(symbols,0);
     }
  };

class ISSX_Contracts
  {
private:
   static double Clamp01(const double v){ if(v<0.0) return 0.0; if(v>1.0) return 1.0; return v; }
   static string SafeText(const string value,const string fallback_text){ return (ISSX_Util::IsEmpty(value) ? fallback_text : value); }
   static string ModuleOwnerHash(){ return ISSX_Hash::HashStringHex(string(ISSX_CONTRACTS_OWNER_MODULE_NAME)+"|"+string(ISSX_CONTRACTS_MODULE_VERSION)+"|"+string(ISSX_CONTRACTS_STAGE_API_VERSION)+"|"+string(ISSX_CONTRACTS_SERIALIZER_VERSION)+"|"+string(ISSX_CONTRACTS_EXTERNAL_CONTRACT_VERSION)+"|"+string(ISSX_CONTRACTS_FINGERPRINT_ALGO_VERSION)); }

   static int AgeSecFromMinuteId(const long current_minute_id,const long source_minute_id)
     {
      if(current_minute_id<=0 || source_minute_id<=0 || current_minute_id<source_minute_id) return 0;
      long delta=(current_minute_id-source_minute_id)*60;
      if(delta<0) delta=0;
      if(delta>2147483647) delta=2147483647;
      return (int)delta;
     }

   static ISSX_TruthClass TruthClassFromQualityScore(const double v)
     {
      if(v>=0.85) return issx_truth_strong;
      if(v>=0.65) return issx_truth_acceptable;
      if(v>=0.40) return issx_truth_degraded;
      return issx_truth_weak;
     }

   static string HandoffModeToString(const ISSX_HandoffMode v)
     {
      switch(v)
        {
         case issx_handoff_same_tick_accepted: return "same_tick_accepted";
         case issx_handoff_internal_current:   return "internal_current";
         case issx_handoff_internal_previous:  return "internal_previous";
         case issx_handoff_internal_last_good: return "internal_last_good";
         case issx_handoff_public_projection:  return "public_projection";
         default: return "none";
        }
     }

   static string TruthClassToString(const ISSX_TruthClass v)
     {
      switch(v)
        {
         case issx_truth_strong: return "strong";
         case issx_truth_acceptable: return "acceptable";
         case issx_truth_degraded: return "degraded";
         case issx_truth_weak: return "weak";
         default: return "weak";
        }
     }

   static string FreshnessClassToString(const ISSX_FreshnessClass v)
     {
      switch(v)
        {
         case issx_freshness_fresh: return "fresh";
         case issx_freshness_usable: return "usable";
         case issx_freshness_aging: return "aging";
         case issx_freshness_stale: return "stale";
         default: return "stale";
        }
     }

   static string AuthorityLevelToString(const ISSX_AuthorityLevel v){ return ISSX_Enum::AuthorityLevelToString(v); }

   static string ContinuityOriginToString(const ISSX_ContinuityOrigin v)
     {
      switch(v)
        {
         case issx_continuity_fresh_boot: return "fresh_boot";
         case issx_continuity_resumed_current: return "resumed_current";
         case issx_continuity_resumed_previous: return "resumed_previous";
         case issx_continuity_resumed_last_good: return "resumed_last_good";
         case issx_continuity_rebuilt_clean: return "rebuilt_clean";
         default: return "fresh_boot";
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

   static string CohortStateToString(const ISSX_CohortState v)
     {
      switch(v)
        {
         case issx_cohort_exact: return "exact";
         case issx_cohort_mixed: return "mixed";
         case issx_cohort_degraded: return "degraded";
         default: return "degraded";
        }
     }

   static string ContradictionSeverityToString(const ISSX_ContradictionSeverity v)
     {
      switch(v)
        {
         case issx_contradiction_low: return "low";
         case issx_contradiction_moderate: return "moderate";
         case issx_contradiction_high: return "high";
         case issx_contradiction_blocking: return "blocking";
         default: return "low";
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

   static string AnswerModeToString(const ISSX_EA5_AnswerMode v)
     {
      switch(v)
        {
         case issx_ea5_answer_selection_first: return "selection_first";
         case issx_ea5_answer_intelligence_enriched: return "intelligence_enriched";
         case issx_ea5_answer_degraded_selection_only: return "degraded_selection_only";
         default: return "degraded_selection_only";
        }
     }

   static string ExportProfileToString(const ISSX_EA5_ExportProfile v)
     {
      switch(v)
        {
         case issx_ea5_export_compact: return "compact";
         case issx_ea5_export_standard: return "standard";
         case issx_ea5_export_intraday_rich: return "intraday_rich";
         default: return "standard";
        }
     }

   static string LeaderBucketTypeToString(const int v)
     {
      switch(v)
        {
         case issx_leader_bucket_theme_bucket: return "theme_bucket";
         case issx_leader_bucket_equity_sector: return "equity_sector";
         default: return "unknown";
        }
     }

   static string TaxonomyActionToString(const int v)
     {
      switch(v)
        {
         case issx_taxonomy_accepted: return "accepted";
         case issx_taxonomy_theme_downgrade: return "theme_downgrade";
         case issx_taxonomy_quarantined: return "quarantined";
         case issx_taxonomy_manual_review_only: return "manual_review_only";
         default: return "manual_review_only";
        }
     }

   static string PracticalMarketStateToString(const int v)
     {
      switch(v)
        {
         case issx_market_open_usable: return "open_usable";
         case issx_market_open_cautious: return "open_cautious";
         case issx_market_quote_only: return "quote_only";
         case issx_market_closed_idle: return "closed_idle";
         case issx_market_blocked: return "blocked";
         default: return "blocked";
        }
     }

   static string TradeabilityClassToString(const int v)
     {
      switch(v)
        {
         case issx_tradeability_very_cheap: return "very_cheap";
         case issx_tradeability_cheap: return "cheap";
         case issx_tradeability_moderate: return "moderate";
         case issx_tradeability_expensive: return "expensive";
         case issx_tradeability_blocked: return "blocked";
         default: return "blocked";
        }
     }

   static string CommissionStateToString(const int v)
     {
      switch(v)
        {
         case issx_commission_known_nonzero: return "known_nonzero";
         case issx_commission_known_zero: return "known_zero";
         case issx_commission_unknown: return "unknown";
         default: return "unknown";
        }
     }

   static string SwapStateToString(const int v)
     {
      switch(v)
        {
         case issx_swap_known_nonzero: return "known_nonzero";
         case issx_swap_known_zero: return "known_zero";
         case issx_swap_unknown: return "unknown";
         default: return "unknown";
        }
     }

   static string PositionSecurityClassToString(const int v)
     {
      switch(v)
        {
         case issx_ea3_security_fragile: return "fragile";
         case issx_ea3_security_contested: return "contested";
         case issx_ea3_security_stable: return "stable";
         case issx_ea3_security_locked: return "locked";
         default: return "unknown";
        }
     }

   static string PortfolioRoleHintToString(const int v)
     {
      switch(v)
        {
         case issx_role_anchor: return "anchor";
         case issx_role_overlap_risk: return "overlap_risk";
         case issx_role_diversifier: return "diversifier";
         case issx_role_fragile_diversifier: return "fragile_diversifier";
         case issx_role_redundant: return "redundant";
         default: return "unknown";
        }
     }

   static string SessionPhaseToString(const int v)
     {
      switch(v)
        {
         case issx_ea1_session_pre_open: return "preopen";
         case issx_ea1_session_open:     return "open";
         case issx_ea1_session_mid:      return "mid";
         case issx_ea1_session_late:     return "late";
         case issx_ea1_session_rollover: return "transition";
         case issx_ea1_session_closed:   return "closed";
         default:                        return "unknown";
        }
     }

   static string TimeframeModeToString(const int v)
     {
      switch(v)
        {
         case issx_ea2_tfmode_cold: return "cold";
         case issx_ea2_tfmode_syncing: return "syncing";
         case issx_ea2_tfmode_minimal_ready: return "minimal_ready";
         case issx_ea2_tfmode_ranking_ready: return "ranking_ready";
         case issx_ea2_tfmode_intelligence_ready: return "intelligence_ready";
         case issx_ea2_tfmode_degraded: return "degraded";
         default: return "cold";
        }
     }

   static string TruthTimeframeToCompact(const int readiness,const ISSX_FreshnessClass freshness,const ISSX_TruthClass quality_class,const double continuity)
     {
      return TimeframeModeToString(readiness)+"|"+FreshnessClassToString(freshness)+"|"+TruthClassToString(quality_class)+"|"+DoubleToString(continuity,4);
     }

   static int FindEa2BySymbol(const ISSX_EA2_State &ea2,const string symbol_norm,const string symbol_raw)
     {
      for(int i=0;i<ArraySize(ea2.symbols);i++) if(ea2.symbols[i].symbol_norm==symbol_norm || ea2.symbols[i].symbol_raw==symbol_raw) return i;
      return -1;
     }

   static int FindOptionalIntelligence(const ISSX_EA5_OptionalIntelligence &arr[],const string symbol_norm)
     {
      for(int i=0;i<ArraySize(arr);i++) if(arr[i].symbol_norm==symbol_norm) return i;
      return -1;
     }

   static void PushReason(string &pipe,const string reason)
     {
      if(ISSX_Util::IsEmpty(reason)) return;
      if(ISSX_Util::IsEmpty(pipe)) pipe=reason;
      else if(StringFind(pipe,reason)<0) pipe+="|"+reason;
     }

   static void SeverityAccumulate(ISSX_ContradictionSeverity &dst,const ISSX_ContradictionSeverity src){ if((int)src>(int)dst) dst=src; }

   static double ComputeCompletenessScore(const ISSX_EA1_SymbolState &m,const ISSX_EA2_SymbolState &h,const ISSX_EA3_SymbolSelection &s,const bool has_intelligence)
     {
      double score=0.0;
      score+=(m.rankability_gate.identity_ready ? 0.10 : 0.0);
      score+=(m.rankability_gate.session_ready ? 0.10 : 0.0);
      score+=(m.rankability_gate.market_ready ? 0.10 : 0.0);
      score+=(m.rankability_gate.cost_ready ? 0.10 : 0.0);
      score+=(h.history_ready_for_ranking ? 0.20 : 0.0);
      score+=(s.selected_top5 ? 0.20 : (s.selected_frontier ? 0.10 : 0.0));
      score+=(has_intelligence ? 0.20 : 0.0);
      return Clamp01(score);
     }

   static double ComputeFinalRankConfidence(const ISSX_EA1_SymbolState &m,const ISSX_EA2_SymbolState &h,const ISSX_EA3_SymbolSelection &s,const ISSX_EA5_OptionalIntelligence &opt,const bool has_opt,const int contradiction_penalty_steps)
     {
      double base=0.35*s.bucket_local_composite+0.20*h.judgment.history_data_quality_score+0.15*m.classification_truth.classification_reliability_score+0.10*m.validated_runtime_truth.runtime_truth_score+0.10*m.tradeability_baseline.all_in_cost_confidence+0.10*(1.0-s.comparison_penalty);
      if(has_opt && opt.present){ base+=0.05*opt.adjustment_confidence; base+=0.05*opt.intelligence_confidence; }
      base-=0.08*contradiction_penalty_steps;
      if(s.won_on_hysteresis_only_flag) base*=0.92;
      if(m.symbol_lifecycle.resumed_from_persistence) base*=0.98;
      return Clamp01(base);
     }

   static ISSX_TruthClass FoldTruthClass(const ISSX_TruthClass a,const ISSX_TruthClass b,const ISSX_TruthClass c)
     {
      int worst=(int)a; if((int)b>worst) worst=(int)b; if((int)c>worst) worst=(int)c; return (ISSX_TruthClass)worst;
     }

   static ISSX_FreshnessClass FoldFreshnessClass(const ISSX_FreshnessClass a,const ISSX_FreshnessClass b,const ISSX_FreshnessClass c)
     {
      int worst=(int)a; if((int)b>worst) worst=(int)b; if((int)c>worst) worst=(int)c; return (ISSX_FreshnessClass)worst;
     }

   static void BuildHistoryCompactStrings(const ISSX_EA2_SymbolState &h,string &provenance_out,string &judgment_out)
     {
      provenance_out="profile="+SafeText(h.provenance.warm_or_deep_profile,"unknown")+"|tf="+SafeText(h.provenance.timeframes_used_for_active_metrics,"unknown")+"|sample="+IntegerToString(h.provenance.effective_sample_count)+"|compat="+TimeframeModeToString(h.tf[issx_ea2_tf_m15].mode)+"|repair="+DoubleToString(h.provenance.recent_repair_activity_score,4);
      judgment_out="usable="+DoubleToString(h.judgment.usable_range_score,4)+"|continuity="+DoubleToString(h.judgment.continuity_score,4)+"|stale="+DoubleToString(h.judgment.staleness_score,4)+"|gap="+DoubleToString(h.judgment.gap_risk_score,4)+"|metric="+DoubleToString(h.judgment.metric_trust_score,4)+"|quality="+DoubleToString(h.judgment.history_data_quality_score,4);
     }

   static void SeedContextState(ISSX_EA5_ContextState &ctx,const ISSX_EA2_SymbolState &h,const ISSX_EA3_SymbolSelection &s)
     {
      ctx.range_20m_points=h.hot_metrics.atr_points_m5;
      ctx.range_60m_points=h.hot_metrics.atr_points_m15*2.0;
      ctx.range_240m_points=h.hot_metrics.atr_points_m15*8.0;
      ctx.pct_of_day_range=Clamp01(h.structural_context.range_position_score);
      ctx.pct_of_20m_range=Clamp01(h.hot_metrics.close_location_percentile_recent);
      ctx.pct_of_60m_range=Clamp01(h.structural_context.range_position_score);
      ctx.pct_of_240m_range=Clamp01(0.50*h.structural_context.range_position_score+0.50*h.judgment.usable_range_score);
      ctx.micro_noise_risk=h.structural_context.micro_noise_risk;
      ctx.structure_clarity_score=h.structural_context.structure_clarity_score;
      ctx.compression_score=h.structural_context.compression_score;
      ctx.expansion_score=h.structural_context.expansion_score;
      ctx.breakout_proximity_score=h.structural_context.breakout_proximity_score;
      ctx.structure_stability_score=h.structural_context.structure_stability_score;
      ctx.holding_window_fit_20_60m=Clamp01(0.45*h.tf[issx_ea2_tf_m5].window_use_confidence+0.55*h.tf[issx_ea2_tf_m15].window_use_confidence);
      ctx.holding_window_fit_60_180m=Clamp01(0.60*h.tf[issx_ea2_tf_m15].window_use_confidence+0.40*h.tf[issx_ea2_tf_h1].window_use_confidence);
      ctx.holding_window_fit_180_480m=Clamp01(h.tf[issx_ea2_tf_h1].window_use_confidence);
      ctx.range_position_day=Clamp01(h.structural_context.range_position_score);
      ctx.range_position_4h=Clamp01(0.50*h.structural_context.range_position_score+0.50*h.structural_context.structure_stability_score);
      ctx.why_selected_top3=(s.selected_top5 ? "bucket_strength|trade_cost|history_quality" : "frontier_context|reserve_pressure|continuity");
      ctx.why_penalized_top3=(s.comparison_penalty>0.20 ? "comparison_penalty" : "none")+(h.provenance.temporary_rank_suspension ? "|history_recovery" : "")+(s.won_on_hysteresis_only_flag ? "|hysteresis_only" : "");
      ctx.why_not_higher_top3=(s.nearest_reserve_gap>0.0 ? "reserve_gap" : "none")+(s.replacement_pressure>0.50 ? "|replacement_pressure" : "")+(s.frontier_survival_risk>0.50 ? "|frontier_survival_risk" : "");
      ctx.key_use_constraints=(h.provenance.temporary_rank_suspension ? "recovery_history" : "none")+(s.spec_only_cheapness_flag ? "|spec_only_cheapness" : "")+(s.won_on_hysteresis_only_flag ? "|hysteresis_hold" : "");
      ctx.symbol_digest=SafeText(s.leader_bucket_id,"unknown")+"|"+SafeText(s.frontier_entry_reason_primary,"not_set")+"|comp="+DoubleToString(s.bucket_local_composite,4);
     }

   static void BuildIntegrityTable(ISSX_EA5_IntegrityTable &it,const ISSX_EA1_SymbolState &m,const ISSX_EA2_SymbolState &h,const ISSX_EA3_SymbolSelection &s,const ISSX_EA5_OptionalIntelligence &opt,const bool has_opt)
     {
      it.Reset();
      it.classification.present=true; it.classification.usable=(m.classification_truth.classification_reliability_score>=0.25); it.classification.degraded=!it.classification.usable; it.classification.authority_level=issx_authority_authoritative_validated; it.classification.primary_reason_if_not_usable=(it.classification.usable ? "" : "classification_reliability_low");
      it.observability.present=true; it.observability.usable=(m.validated_runtime_truth.runtime_truth_score>=0.25); it.observability.degraded=!it.observability.usable; it.observability.authority_level=issx_authority_authoritative_observed; it.observability.primary_reason_if_not_usable=(it.observability.usable ? "" : "runtime_truth_low");
      it.tradeability.present=true; it.tradeability.usable=(m.tradeability_baseline.tradeability_class!=issx_tradeability_blocked); it.tradeability.degraded=!it.tradeability.usable; it.tradeability.authority_level=issx_authority_authoritative_validated; it.tradeability.primary_reason_if_not_usable=(it.tradeability.usable ? "" : "tradeability_blocked");
      it.session.present=true; it.session.usable=(m.validated_runtime_truth.session_truth_confidence>=0.20); it.session.degraded=!it.session.usable; it.session.authority_level=issx_authority_authoritative_observed; it.session.primary_reason_if_not_usable=(it.session.usable ? "" : "session_truth_low");
      it.market.present=true; it.market.usable=(m.validated_runtime_truth.practical_market_state!=issx_market_blocked); it.market.degraded=!it.market.usable; it.market.authority_level=issx_authority_authoritative_observed; it.market.primary_reason_if_not_usable=(it.market.usable ? "" : "market_blocked");
      it.history.present=true; it.history.usable=h.history_ready_for_ranking; it.history.degraded=!it.history.usable; it.history.authority_level=issx_authority_authoritative_validated; it.history.primary_reason_if_not_usable=(it.history.usable ? "" : "history_not_ranking_ready");
      it.bucket_selection.present=true; it.bucket_selection.usable=(s.selected_top5 || s.selected_frontier); it.bucket_selection.degraded=!it.bucket_selection.usable; it.bucket_selection.authority_level=issx_authority_derived_comparative; it.bucket_selection.primary_reason_if_not_usable=(it.bucket_selection.usable ? "" : "not_selected");
      it.intelligence.present=(has_opt && opt.present); it.intelligence.usable=(has_opt && opt.present && !opt.intelligence_abstained && opt.adjustment_confidence>=0.20); it.intelligence.degraded=!it.intelligence.usable; it.intelligence.authority_level=(it.intelligence.present ? issx_authority_derived_comparative : issx_authority_degraded); it.intelligence.primary_reason_if_not_usable=(it.intelligence.usable ? "" : (has_opt ? opt.abstention_reason : "not_attached"));
      it.final_context.present=true; it.final_context.usable=(h.judgment.history_data_quality_score>=0.20); it.final_context.degraded=!it.final_context.usable; it.final_context.authority_level=issx_authority_advisory_context; it.final_context.primary_reason_if_not_usable=(it.final_context.usable ? "" : "context_quality_low");
     }

   static void BuildComparisonContract(ISSX_EA5_ComparisonContract &cc,const ISSX_EA2_SymbolState &h,const ISSX_EA3_SymbolSelection &s,const ISSX_EA5_OptionalIntelligence &opt,const bool has_opt)
     {
      cc.Reset();
      cc.safe_to_compare_bucket_score=(s.bucket_comparison_completeness>=0.45 && s.comparison_penalty<=0.45);
      cc.safe_to_compare_final_rank=(cc.safe_to_compare_bucket_score && h.history_ready_for_ranking);
      cc.safe_to_compare_history_metrics=(h.tf[issx_ea2_tf_m15].metric_compare_class>=issx_metric_compare_bucket_safe);
      cc.comparison_completeness_score=Clamp01(0.50*s.bucket_comparison_completeness+0.35*(1.0-s.comparison_penalty)+0.15*(has_opt && opt.present ? opt.intelligence_coverage_score : 0.0));
      if(!cc.safe_to_compare_final_rank) PushReason(cc.comparison_limitations,"final_rank_not_safe");
      if(!cc.safe_to_compare_history_metrics) PushReason(cc.comparison_limitations,"history_metric_compare_limited");
      if(!has_opt || !opt.present || opt.intelligence_abstained) PushReason(cc.comparison_limitations,"intelligence_missing_or_abstained");
     }

   static void AccumulateContradictionClassCount(string &counts,const string class_name)
     {
      string target=class_name+":";
      int pos=StringFind(counts,target);
      if(pos<0) return;
      int value_start=pos+StringLen(target);
      int next_delim=StringFind(counts,"|",value_start);
      string prefix=StringSubstr(counts,0,value_start);
      string value_text=(next_delim>=0 ? StringSubstr(counts,value_start,next_delim-value_start) : StringSubstr(counts,value_start));
      string suffix=(next_delim>=0 ? StringSubstr(counts,next_delim) : "");
      int current_value=(int)StringToInteger(value_text);
      counts=prefix+IntegerToString(current_value+1)+suffix;
     }

   static int ContradictionPenaltySteps(const ISSX_EA1_SymbolState &m,const ISSX_EA2_SymbolState &h,const ISSX_EA3_SymbolSelection &s,const ISSX_EA5_OptionalIntelligence &opt,const bool has_opt,string &flags_out,ISSX_ContradictionSeverity &sev_out,string &class_counts_out,string &highest_blocking_class_out)
     {
      int steps=0;
      flags_out="";
      sev_out=issx_contradiction_low;
      class_counts_out="identity:0|session:0|spec:0|history_continuity:0|selection_ownership:0|intelligence_validity:0";
      highest_blocking_class_out="none";

      if(m.tradeability_baseline.all_in_cost_confidence>=0.75 && m.tradeability_baseline.commission_state==issx_commission_unknown && m.tradeability_baseline.swap_state==issx_swap_unknown)
        {
         PushReason(flags_out,"cost_confidence_vs_unknown_fees");
         SeverityAccumulate(sev_out,issx_contradiction_high);
         AccumulateContradictionClassCount(class_counts_out,"spec");
         steps+=2;
        }

      if(m.validated_runtime_truth.runtime_truth_score>=0.65 && m.validated_runtime_truth.practical_market_state==issx_market_blocked)
        {
         PushReason(flags_out,"high_observability_while_blocked");
         SeverityAccumulate(sev_out,issx_contradiction_high);
         AccumulateContradictionClassCount(class_counts_out,"session");
         steps+=2;
        }

      if(h.history_ready_for_intelligence && h.trust_map.tf_m15_trust.quality_class==issx_truth_weak)
        {
         PushReason(flags_out,"history_intelligence_vs_weak_m15");
         SeverityAccumulate(sev_out,issx_contradiction_high);
         AccumulateContradictionClassCount(class_counts_out,"history_continuity");
         steps+=2;
        }

      if(s.selected_top5 && s.bucket_local_composite>=0.60 && s.comparison_penalty>=0.55)
        {
         PushReason(flags_out,"strong_bucket_vs_compare_penalty");
         SeverityAccumulate(sev_out,issx_contradiction_moderate);
         AccumulateContradictionClassCount(class_counts_out,"selection_ownership");
         steps+=1;
        }

      if(has_opt && opt.present)
        {
         if(opt.corr_penalty_applied && !opt.corr_valid)
           {
            PushReason(flags_out,"corr_penalty_without_valid_corr");
            SeverityAccumulate(sev_out,issx_contradiction_blocking);
            AccumulateContradictionClassCount(class_counts_out,"intelligence_validity");
            highest_blocking_class_out="intelligence_validity";
            steps+=3;
           }

         if(opt.diversification_bonus_applied && opt.intelligence_coverage_score<0.20)
           {
            PushReason(flags_out,"diversification_bonus_vs_low_coverage");
            SeverityAccumulate(sev_out,issx_contradiction_high);
            AccumulateContradictionClassCount(class_counts_out,"intelligence_validity");
            steps+=2;
           }
        }

      return steps;
     }

   static void SeedCompactOhlcUnavailable(ISSX_EA5_CompactOhlcPack &pack){ pack.Reset(); pack.source_note="completed_bar_pack_not_attached"; pack.has_data=false; pack.completed_bars_only=true; }

   static string OhlcArrayJson(const ISSX_EA5_OhlcBar &bars[])
     {
      string out="[";
      bool first=true;
      for(int i=0;i<ArraySize(bars);i++)
        {
         if(!first) out+=",";
         first=false;
         out+="["+ISSX_Util::LongToStringX((long)(bars[i].t))+","+DoubleToString(bars[i].o,6)+","+DoubleToString(bars[i].h,6)+","+DoubleToString(bars[i].l,6)+","+DoubleToString(bars[i].c,6)+","+ISSX_Util::LongToStringX(bars[i].v)+",\""+ISSX_Util::EscapeJson(bars[i].s)+"\"]";
        }
      out+="]";
      return out;
     }

   static string IntegrityBlockJson(const ISSX_EA5_IntegrityBlock &b)
     {
      return "{\"present\":"+ISSX_Util::BoolToString(b.present)+",\"usable\":"+ISSX_Util::BoolToString(b.usable)+",\"degraded\":"+ISSX_Util::BoolToString(b.degraded)+",\"authority_level\":\""+AuthorityLevelToString(b.authority_level)+"\",\"primary_reason_if_not_usable\":\""+ISSX_Util::EscapeJson(b.primary_reason_if_not_usable)+"\"}";
     }

   static string ComputeLegendHash(ISSX_FieldRegistry &field_registry,ISSX_EnumRegistry &enum_registry){ return ISSX_Hash::HashStringHex(field_registry.FingerprintHex()+"|"+enum_registry.FingerprintHex()+"|"+ISSX_CONTRACTS_EXTERNAL_CONTRACT_VERSION+"|"+ISSX_CONTRACTS_FINGERPRINT_ALGO_VERSION); }

   static string LegendJson(ISSX_FieldRegistry &field_registry,ISSX_EnumRegistry &enum_registry)
     {
      string legend_hash=ComputeLegendHash(field_registry,enum_registry);
      string out="{";
      out+="\"legend_version\":\""+ISSX_Util::EscapeJson(ISSX_LEGEND_VERSION)+"\"";
      out+=",\"legend_hash\":\""+legend_hash+"\"";
      out+=",\"legend\":{";
      out+="\"field_ownership\":\"central_registry\"";
      out+=",\"enum_catalog_compact\":\""+ISSX_Util::EscapeJson(enum_registry.ExportCompactJson())+"\"";
      out+=",\"score_catalog_compact\":\"selection_utility_base_score[0..1]|final_rank_confidence[0..1]|history_data_quality_score[0..1]|adjustment_confidence[0..1]\"";
      out+=",\"null_semantics\":\"explicit_null means unavailable; typed_unknown means unresolved; not_applicable_enum means structurally inapplicable\"";
      out+=",\"missing_data_policy\":\"missing is explicit, never neutral or zero by implication\"";
      out+=",\"freshness_policy\":\"freshness must be checked before reasoning; stale never means false\"";
      out+=",\"confidence_policy\":\"truth, freshness, completeness, and final_rank_confidence must be considered together\"";
      out+=",\"safe_use_rules\":\"descriptive_only|no_direction|no_trade_instruction|respect_integrity_table|respect_comparison_contract\"";
      out+=",\"score_non_meanings\":\"rank is not direction; penalty is not bearishness; structure is not trigger\"";
      out+=",\"minimum_read_order\":\"market_readiness_summary -> source_summary -> contradiction_summary -> symbol.integrity_table -> symbol.comparison_contract -> symbol.context_state\"";
      out+=",\"history_pack_rules\":\"compact_ohlc_pack uses completed bars only, oldest_to_newest, shared pack version\"";
      out+=",\"authority_levels\":\"authoritative_observed,authoritative_validated,derived_comparative,advisory_context,degraded\"";
      out+=",\"external_field_stability\":\"top_level=frozen|winner_identity=frozen|compact_ohlc_pack=frozen|regime_block=additive_safe|explanation_block=additive_safe|source_summary=frozen|state_semantics=frozen\"";
      out+="}}";
      return out;
     }

   static string ConsumerGuidanceJson()
     {
      return "{\"consumer_guidance\":{\"document_purpose\":\"winner-only descriptive market context for human/model reasoning\",\"descriptive_not_prescriptive\":true,\"contains_no_trade_instruction\":true,\"contains_no_directional_recommendation\":true,\"scores_are_comparative_not_predictive\":true,\"compare_only_within_declared_scales\":true,\"do_not_infer_direction_from_rank\":true,\"do_not_treat_missing_as_neutral\":true,\"use_truth_and_freshness_before_any_reasoning\":true,\"selection_backbone_is_ea3\":true,\"required_checks_before_conclusion\":\"integrity_table|comparison_contract|truth_class|freshness_class|source_summary|contradiction_summary\",\"forbidden_inferences\":\"direction_from_rank|signal_from_structure|safety_from_invalid_corr|neutrality_from_missing\",\"structure_fields_are_state_descriptors_only\":true,\"do_not_infer_break_direction_from_structure\":true}}";
     }

   static void PopulateWinnerFreshnessSurface(ISSX_EA5_WinnerFreshnessSurface &fs,const ISSX_EA5_State &state,const ISSX_EA1_SymbolState &m,const ISSX_EA2_State &ea2,const bool has_opt,const ISSX_EA5_OptionalIntelligence &opt)
     {
      fs.Reset();
      fs.winner_history_age_m5_sec=AgeSecFromMinuteId((long)(state.manifest.minute_id),(long)(ea2.manifest.minute_id));
      fs.winner_history_age_m15_sec=AgeSecFromMinuteId((long)(state.manifest.minute_id),(long)(ea2.manifest.minute_id));
      fs.winner_history_age_h1_sec=AgeSecFromMinuteId((long)(state.manifest.minute_id),(long)(ea2.manifest.minute_id));
      fs.winner_history_age_by_tf="m5:"+IntegerToString(fs.winner_history_age_m5_sec)+"|m15:"+IntegerToString(fs.winner_history_age_m15_sec)+"|h1:"+IntegerToString(fs.winner_history_age_h1_sec);
      fs.winner_regime_refresh_age_sec=AgeSecFromMinuteId((long)(state.manifest.minute_id),(long)(ea2.manifest.minute_id));
      fs.winner_corr_refresh_age_sec=(has_opt && opt.present ? 0 : -1);
      fs.winner_last_material_change_sec=(m.symbol_lifecycle.resumed_from_persistence ? 60 : 0);
     }

   static void PopulateWinnerRegimeBlock(ISSX_EA5_WinnerRegimeBlock &rb,const ISSX_EA1_SymbolState &m,const ISSX_EA2_SymbolState &h,const ISSX_EA5_OptionalIntelligence &opt,const bool has_opt)
     {
      rb.Reset();
      rb.intraday_activity_state=(h.hot_metrics.atr_points_m5>0.0 ? "active" : "unknown");
      rb.liquidity_regime_class=(m.validated_runtime_truth.spread_widening_ratio<=1.20 ? "acceptable" : "fragile");
      rb.volatility_regime_class=(h.hot_metrics.atr_points_m15>0.0 ? "normal" : "unknown");
      rb.expansion_state_class=(h.structural_context.expansion_score>=0.60 ? "expanding" : h.structural_context.compression_score>=0.60 ? "compressed" : "normal");
      rb.movement_quality_class=(h.structural_context.structure_clarity_score>=0.60 ? "orderly" : "noisy");
      rb.movement_maturity_class=(h.structural_context.structure_stability_score>=0.60 ? "mature" : "early");
      rb.session_phase_class=SessionPhaseToString(m.validated_runtime_truth.session_phase_class);
      rb.tradability_now_class=TradeabilityClassToString(m.tradeability_baseline.tradeability_class);
      rb.constructability_class=(h.judgment.history_data_quality_score>=0.60 ? "strong" : h.judgment.history_data_quality_score>=0.35 ? "acceptable" : "fragile");
      rb.holding_horizon_context=(h.tf[issx_ea2_tf_h1].window_use_confidence>=0.50 ? "extended_intraday" : h.tf[issx_ea2_tf_m15].window_use_confidence>=0.50 ? "mixed_intraday" : "short_intraday");
      rb.movement_to_cost_efficiency_class=(m.tradeability_baseline.entry_cost_score>=0.60 ? "acceptable" : "fragile");
      rb.early_move_quality_class=(h.structural_context.structure_stability_score>=0.50 ? "supported" : "uncertain");
      rb.diversification_confidence_class=(has_opt && opt.present && !opt.intelligence_abstained ? SafeText(opt.diversification_confidence_class,"supported") : "unknown");
      rb.redundancy_risk_class=(has_opt && opt.present ? SafeText(opt.redundancy_risk_class,(opt.structural_overlap_score>=0.60 ? "elevated" : "unknown")) : "unknown");
      rb.opportunity_with_caution_flag=(m.tradeability_baseline.tradeability_class==issx_tradeability_expensive || h.provenance.temporary_rank_suspension);
     }

   static void PopulateWinnerExplanationBlock(ISSX_EA5_WinnerExplanationBlock &eb,const ISSX_EA3_SymbolSelection &s,const ISSX_EA2_SymbolState &h,const ISSX_EA5_OptionalIntelligence &opt,const bool has_opt)
     {
      eb.Reset();
      eb.selection_reason_summary=(s.selected_top5 ? "selected on bucket strength, usable tradeability, and history quality" : "selected for frontier context");
      eb.selection_penalty_summary=(s.comparison_penalty>0.20 ? "comparison penalty active" : "no material selection penalty");
      eb.regime_summary=(h.structural_context.expansion_score>=0.60 ? "expanding intraday context" : h.structural_context.compression_score>=0.60 ? "compressed intraday context" : "mixed intraday context");
      eb.execution_condition_summary=(h.judgment.history_data_quality_score>=0.60 ? "history and structure reasonably usable" : "history or structure currently degraded");
      eb.diversification_context_summary=(has_opt && opt.present && !opt.intelligence_abstained ? "ea4 context attached with explicit overlap semantics" : "ea4 diversification context absent or abstained");
      eb.winner_limitation_summary=(s.won_on_hysteresis_only_flag ? "continuity support present" : h.provenance.temporary_rank_suspension ? "history recovery caution" : "no dominant limitation");
      eb.winner_confidence_class=(s.bucket_local_composite>=0.75 && h.judgment.history_data_quality_score>=0.60 ? "strong" : s.bucket_local_composite>=0.50 ? "acceptable" : "weak");
     }

public:
   static void ResetState(ISSX_EA5_State &state)
     {
      state.Reset();
      state.owner_module_hash=ModuleOwnerHash();
      ISSX_BudgetPolicy::ApplyStageDefaults(issx_stage_ea5,state.runtime.budgets);
      state.answer_mode=issx_ea5_answer_degraded_selection_only;
      state.export_profile=issx_ea5_export_intraday_rich;
     }

   static bool StageBoot(ISSX_EA5_State &state,const string firm_id)
     {
      ResetState(state);
      state.header.stage_id=issx_stage_ea5;
      state.header.firm_id=firm_id;
      state.manifest.stage_id=issx_stage_ea5;
      state.manifest.firm_id=firm_id;
      state.degraded_flag=true;
      state.source_snapshot_kind=ISSX_CONTRACTS_SOURCE_SNAPSHOT_ACCEPTED;
      return true;
     }

   static void SeedSourceSummary(ISSX_EA5_State &state,const ISSX_EA1_State &ea1,const ISSX_EA2_State &ea2,const ISSX_EA3_State &ea3,const int optional_intelligence_count)
     {
      state.source_summary.ea1_source_used="ea1_current";
      state.source_summary.ea2_source_used=(ea2.upstream_source_used=="" ? "ea2_current" : ea2.upstream_source_used);
      state.source_summary.ea3_source_used=(ea3.upstream_source_used=="" ? "ea3_current" : ea3.upstream_source_used);
      state.source_summary.ea4_source_used=(optional_intelligence_count>0 ? "ea4_attached" : "ea4_absent");
      state.source_summary.max_fallback_depth_used=MathMax(MathMax(0,ea2.fallback_depth_used),ea3.fallback_depth_used);
      state.source_summary.recovery_publish_flag=(ea2.recovery_publish_flag || ea3.recovery_publish_flag || ea1.resumed_from_persistence);
      state.source_summary.upstream_handoff_mode=issx_handoff_internal_current;
      state.source_summary.upstream_handoff_sequence_no=(long)(ea3.manifest.sequence_no);
      state.source_summary.upstream_payload_hash=ea3.manifest.payload_hash;
      state.source_summary.upstream_policy_fingerprint=ea3.manifest.policy_fingerprint;
      state.source_summary.fallback_read_ratio_1h=ea3.manifest.fallback_read_ratio_1h;
      state.source_summary.fresh_accept_ratio_1h=ea3.manifest.fresh_accept_ratio_1h;
      state.source_summary.same_tick_handoff_ratio_1h=ea3.manifest.same_tick_handoff_ratio_1h;
      state.source_summary.upstream_partial_progress_flag=(!ea2.stage_minimum_ready_flag || !ea3.stage_minimum_ready_flag);
      state.source_summary.upstream_handoff_compatibility_class=ea3.upstream_compatibility_class;
      state.source_summary.ea4_attached_flag=(optional_intelligence_count>0);
      state.source_summary.ea4_abstained_flag=(optional_intelligence_count<=0);
      state.source_summary.ea4_signal_count=optional_intelligence_count;
      if(ea3.manifest.handoff_mode==issx_handoff_same_tick_accepted || ea2.manifest.handoff_mode==issx_handoff_same_tick_accepted)
        {
         state.source_summary.upstream_handoff_mode=issx_handoff_same_tick_accepted;
         state.source_summary.upstream_handoff_same_tick_flag=true;
         state.source_summary.source_snapshot_kind=ISSX_CONTRACTS_SOURCE_SNAPSHOT_SAME_TICK;
        }
      ISSX_CompatibilityClass worst=issx_compatibility_exact;
      if(ea3.upstream_compatibility_class>worst) worst=ea3.upstream_compatibility_class;
      if((ISSX_CompatibilityClass)ea2.upstream_compatibility_class>worst) worst=(ISSX_CompatibilityClass)ea2.upstream_compatibility_class;
      state.source_summary.compatibility_worst_class=worst;
      state.source_summary.cohort_state=(worst==issx_compatibility_exact && !state.source_summary.recovery_publish_flag ? issx_cohort_exact : worst<=issx_compatibility_compatible ? issx_cohort_mixed : issx_cohort_degraded);
     }

   static void AttachOptionalIntelligence(ISSX_EA5_State &state,const ISSX_EA5_OptionalIntelligence &items[])
     {
      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         int idx=FindOptionalIntelligence(items,state.symbols[i].symbol_norm);
         if(idx<0) continue;
         ISSX_EA5_OptionalIntelligence opt=items[idx];
         state.symbols[i].comparative_state.nearest_peer_similarity=opt.nearest_peer_similarity;
         state.symbols[i].comparative_state.corr_valid=opt.corr_valid;
         state.symbols[i].comparative_state.corr_quality_score=opt.corr_quality_score;
         state.symbols[i].comparative_state.corr_reject_reason=opt.corr_reject_reason;
         state.symbols[i].comparative_state.duplicate_penalty_applied=opt.duplicate_penalty_applied;
         state.symbols[i].comparative_state.corr_penalty_applied=opt.corr_penalty_applied;
         state.symbols[i].comparative_state.session_overlap_penalty_applied=opt.session_overlap_penalty_applied;
         state.symbols[i].comparative_state.diversification_bonus_applied=opt.diversification_bonus_applied;
         state.symbols[i].comparative_state.adjustment_confidence=opt.adjustment_confidence;
         state.symbols[i].comparative_state.portfolio_role_hint=PortfolioRoleHintToString(opt.portfolio_role_hint);
         state.symbols[i].comparative_state.structural_overlap_score=opt.structural_overlap_score;
         state.symbols[i].comparative_state.statistical_overlap_score=opt.statistical_overlap_score;
         state.symbols[i].comparative_state.pair_validity_class=SafeText(opt.pair_validity_class,(opt.corr_valid ? "valid_low_overlap" : "unknown_overlap"));
         state.symbols[i].comparative_state.pair_sample_alignment_class=SafeText(opt.pair_sample_alignment_class,"unknown");
         state.symbols[i].comparative_state.pair_window_freshness_class=SafeText(opt.pair_window_freshness_class,"unknown");
         state.symbols[i].comparative_state.pair_regime_comparability_class=SafeText(opt.pair_regime_comparability_class,"unknown");
         state.symbols[i].comparative_state.sample_count=opt.sample_count;
         state.symbols[i].comparative_state.intelligence_abstained=opt.intelligence_abstained;
         state.symbols[i].comparative_state.abstention_reason=SafeText(opt.abstention_reason,"none");
         state.symbols[i].comparative_state.diversification_confidence_class=SafeText(opt.diversification_confidence_class,"unknown");
         state.symbols[i].comparative_state.redundancy_risk_class=SafeText(opt.redundancy_risk_class,"unknown");
        }
     }

   static void SetCompactOhlcPack(ISSX_EA5_State &state,const string symbol_norm,const ISSX_EA5_CompactOhlcPack &pack)
     {
      for(int i=0;i<ArraySize(state.symbols);i++) if(state.symbols[i].symbol_norm==symbol_norm){ state.symbols[i].compact_ohlc_pack=pack; return; }
     }

   static void BuildFromInputs(ISSX_EA5_State &state,const ISSX_EA1_State &ea1,const ISSX_EA2_State &ea2,const ISSX_EA3_State &ea3,const ISSX_EA5_OptionalIntelligence &optional_intelligence[])
     {
      ResetState(state);
      state.header.stage_id=issx_stage_ea5;
      state.header.schema_version=ISSX_SCHEMA_VERSION;
      state.header.schema_epoch=ISSX_SCHEMA_EPOCH;
      state.header.minute_id=(long)(ea3.manifest.minute_id);
      state.header.sequence_no=(long)(ea3.manifest.sequence_no);
      state.header.firm_id=ea3.header.firm_id;

      state.manifest.stage_id=issx_stage_ea5;
      state.manifest.schema_version=ISSX_SCHEMA_VERSION;
      state.manifest.schema_epoch=ISSX_SCHEMA_EPOCH;
      state.manifest.minute_id=(long)(ea3.manifest.minute_id);
      state.manifest.sequence_no=(long)(ea3.manifest.sequence_no);
      state.manifest.content_class=issx_content_partial;
      state.manifest.publish_reason=issx_publish_scheduled;
      state.manifest.taxonomy_hash=ea3.taxonomy_hash;
      state.manifest.comparator_registry_hash=ea3.comparator_registry_hash;
      state.manifest.universe_fingerprint=ea3.universe.frontier_universe_fingerprint;
      state.manifest.cohort_fingerprint=ea3.cohort_fingerprint;
      state.manifest.firm_id=ea3.manifest.firm_id;
      state.manifest.policy_fingerprint=ea3.manifest.policy_fingerprint;

      state.age_surface.export_generated_at=TimeTradeServer();
      state.age_surface.ea1_age_sec=AgeSecFromMinuteId((long)(state.manifest.minute_id),(long)(ea1.minute_id));
      state.age_surface.ea2_age_sec=AgeSecFromMinuteId((long)(state.manifest.minute_id),(long)(ea2.manifest.minute_id));
      state.age_surface.ea3_age_sec=AgeSecFromMinuteId((long)(state.manifest.minute_id),(long)(ea3.manifest.minute_id));
      state.age_surface.ea4_age_sec=(ArraySize(optional_intelligence)>0 ? 0 : -1);
      state.age_surface.source_generation_ids="ea1:na|ea2:"+ISSX_Util::LongToStringX((long)(ea2.manifest.sequence_no))+"|ea3:"+ISSX_Util::LongToStringX((long)(ea3.manifest.sequence_no))+"|ea4:"+(ArraySize(optional_intelligence)>0 ? "attached" : "na");

      SeedSourceSummary(state,ea1,ea2,ea3,ArraySize(optional_intelligence));
      state.source_snapshot_kind=state.source_summary.source_snapshot_kind;
      ArrayResize(state.symbols,0);

      int publishable=0;
      int final_rank=0;
      bool any_intel=false;
      double avg_truth=0.0;
      double avg_fresh=0.0;
      string dominant_degrade="";
      string dominant_penalty="";
      ISSX_ContradictionSeverity max_sev=issx_contradiction_low;
      int contradiction_count=0;
      bool blocking=false;
      string major_flags="";
      string contradiction_class_counts="identity:0|session:0|spec:0|history_continuity:0|selection_ownership:0|intelligence_validity:0";
      string highest_blocking_class="none";
      int selected_candidate_count=0;
      int symbol_started_count=0;
      int symbol_completed_count=0;
      int contract_build_count=0;
      int skipped_missing_ea1_count=0;
      int skipped_missing_ea2_count=0;
      int skipped_capacity_count=0;
      int optional_intelligence_count=0;
      bool batch_truncated=false;
      int safe_per_symbol_bytes=MathMax(512,state.payload_budget.per_symbol_target_bytes);
      int max_by_budget=MathMax(1,state.payload_budget.hard_max_bytes/safe_per_symbol_bytes);
      int batch_cap=MathMax(1,MathMin(ISSX_EA5_MAX_CONTRACTS_HARD_CAP,max_by_budget));

      state.debug_discovery_attempt_count=1;
      state.debug_candidate_selected_count=0;
      state.debug_symbols_started_count=0;
      state.debug_symbols_completed_count=0;
      state.debug_contract_build_count=0;
      state.debug_skipped_missing_ea1_count=0;
      state.debug_skipped_missing_ea2_count=0;
      state.debug_skipped_capacity_count=0;
      state.debug_optional_intelligence_count=0;
      state.debug_batch_cap=batch_cap;
      state.debug_estimated_export_bytes=0;
      state.debug_batch_truncated=false;
      state.debug_batch_progress="0/0";
      state.debug_ready_state="not_ready";
      state.debug_partial_state="none";
      state.debug_error_conditions="none";
      state.debug_persistence_interactions=(ea1.resumed_from_persistence ? "ea1_resumed_from_persistence" : (ea2.recovery_publish_flag || ea3.recovery_publish_flag ? "upstream_recovery_publish" : "none"));

      for(int i=0;i<ArraySize(ea3.symbols);i++)
        {
         ISSX_EA3_SymbolSelection s=ea3.symbols[i];
         if(!s.selected_top5) continue;
         selected_candidate_count++;

         if(contract_build_count>=batch_cap)
           {
            skipped_capacity_count++;
            batch_truncated=true;
            continue;
           }

         symbol_started_count++;

         int m_idx=-1;
         for(int j=0;j<ArraySize(ea1.symbols);j++)
           {
            if(ea1.symbols[j].normalized_identity.symbol_norm==s.symbol_norm || ea1.symbols[j].raw_broker_observation.symbol_raw==s.symbol_raw){ m_idx=j; break; }
           }

         int h_idx=FindEa2BySymbol(ea2,s.symbol_norm,s.symbol_raw);
         if(m_idx<0){ skipped_missing_ea1_count++; continue; }
         if(h_idx<0){ skipped_missing_ea2_count++; continue; }

         ISSX_EA1_SymbolState m=ea1.symbols[m_idx];
         ISSX_EA2_SymbolState h=ea2.symbols[h_idx];

         int opt_idx=FindOptionalIntelligence(optional_intelligence,s.symbol_norm);
         ISSX_EA5_OptionalIntelligence opt; opt.Reset();
         bool has_opt=(opt_idx>=0);
         if(has_opt)
           {
            opt=optional_intelligence[opt_idx];
            optional_intelligence_count++;
            if(opt.present && !opt.intelligence_abstained) any_intel=true;
           }

         ISSX_EA5_SymbolContract sc; sc.Reset();
         sc.symbol_raw=m.raw_broker_observation.symbol_raw;
         sc.symbol_norm=m.normalized_identity.symbol_norm;
         sc.canonical_root=m.normalized_identity.canonical_root;
         sc.alias_family_id=m.normalized_identity.alias_family_id;
         sc.market_representation_id=m.normalized_identity.market_representation_id;
         sc.asset_class=m.classification_truth.asset_class;
         sc.instrument_family=m.classification_truth.instrument_family;
         sc.theme_bucket=m.classification_truth.theme_bucket;
         sc.equity_sector=m.classification_truth.equity_sector;
         sc.leader_bucket_id=m.classification_truth.leader_bucket_id;
         sc.leader_bucket_type=LeaderBucketTypeToString((int)m.classification_truth.leader_bucket_type);
         sc.classification_reliability_score=m.classification_truth.classification_reliability_score;
         sc.taxonomy_action_taken=TaxonomyActionToString((int)m.classification_truth.taxonomy_action_taken);
         sc.practical_market_state=PracticalMarketStateToString((int)m.validated_runtime_truth.practical_market_state);
         sc.practical_market_state_reason_codes=m.validated_runtime_truth.practical_market_state_reason_codes;
         sc.runtime_truth_score=m.validated_runtime_truth.runtime_truth_score;
         sc.observation_density_score=m.validated_runtime_truth.observation_density_score;
         sc.point=m.raw_broker_observation.point;
         sc.tick_size=m.raw_broker_observation.tick_size;
         sc.contract_size=m.raw_broker_observation.contract_size;
         sc.volume_min=m.raw_broker_observation.volume_min;
         sc.volume_step=m.raw_broker_observation.volume_step;
         sc.stops_level=m.raw_broker_observation.stops_level;
         sc.freeze_level=m.raw_broker_observation.freeze_level;
         sc.session_reconciliation_state=SafeText(m.validated_runtime_truth.session_reconciliation_state,"unknown");
         sc.session_truth_confidence=m.validated_runtime_truth.session_truth_confidence;
         sc.session_phase=SessionPhaseToString((int)m.validated_runtime_truth.session_phase_class);
         sc.minutes_since_session_open=m.validated_runtime_truth.minutes_since_session_open;
         sc.minutes_to_session_close=m.validated_runtime_truth.minutes_to_session_close;
         sc.transition_penalty_active=m.validated_runtime_truth.transition_penalty_active;
         sc.bid=m.raw_broker_observation.quote_tick_snapshot.bid;
         sc.ask=m.raw_broker_observation.quote_tick_snapshot.ask;
         sc.mid=0.5*(sc.bid+sc.ask);
         sc.spread_now_points=(m.raw_broker_observation.point>0.0 ? (sc.ask-sc.bid)/m.raw_broker_observation.point : 0.0);
         sc.spread_median_short_points=m.validated_runtime_truth.spread_median_short_points;
         sc.spread_p90_short_points=m.validated_runtime_truth.spread_p90_short_points;
         sc.spread_widening_ratio=m.validated_runtime_truth.spread_widening_ratio;
         sc.quote_interval_median_ms=m.validated_runtime_truth.quote_interval_median_ms;
         sc.quote_interval_p90_ms=m.validated_runtime_truth.quote_interval_p90_ms;
         sc.quote_stall_rate=m.validated_runtime_truth.quote_stall_rate;
         sc.tradeability_class=TradeabilityClassToString((int)m.tradeability_baseline.tradeability_class);
         sc.structural_tradeability_score=m.tradeability_baseline.structural_tradeability_score;
         sc.live_tradeability_score=m.tradeability_baseline.live_tradeability_score;
         sc.blended_tradeability_score=m.tradeability_baseline.blended_tradeability_score;
         sc.entry_cost_score=m.tradeability_baseline.entry_cost_score;
         sc.size_practicality_score=m.tradeability_baseline.size_practicality_score;
         sc.economic_consistency_score=m.tradeability_baseline.economic_consistency_score;
         sc.all_in_cost_confidence=m.tradeability_baseline.all_in_cost_confidence;
         sc.commission_state=CommissionStateToString((int)m.tradeability_baseline.commission_state);
         sc.swap_state=SwapStateToString((int)m.tradeability_baseline.swap_state);
         sc.history_data_quality_score=h.judgment.history_data_quality_score;
         sc.tf_m5_trust=TruthTimeframeToCompact((int)h.trust_map.tf_m5_trust.readiness,h.trust_map.tf_m5_trust.freshness,h.trust_map.tf_m5_trust.quality_class,h.trust_map.tf_m5_trust.continuity);
         sc.tf_m15_trust=TruthTimeframeToCompact((int)h.trust_map.tf_m15_trust.readiness,h.trust_map.tf_m15_trust.freshness,h.trust_map.tf_m15_trust.quality_class,h.trust_map.tf_m15_trust.continuity);
         sc.tf_h1_trust=TruthTimeframeToCompact((int)h.trust_map.tf_h1_trust.readiness,h.trust_map.tf_h1_trust.freshness,h.trust_map.tf_h1_trust.quality_class,h.trust_map.tf_h1_trust.continuity);
         BuildHistoryCompactStrings(h,sc.history_provenance,sc.history_judgment_packet);
         SeedCompactOhlcUnavailable(sc.compact_ohlc_pack);

         sc.comparative_state.bucket_local_composite=s.bucket_local_composite;
         sc.comparative_state.bucket_rank=s.bucket_rank;
         sc.comparative_state.bucket_top5_rank=s.bucket_top5_rank;
         sc.comparative_state.won_by_strength=s.won_by_strength;
         sc.comparative_state.won_by_shortfall=s.won_by_shortfall;
         sc.comparative_state.won_on_hysteresis_only_flag=s.won_on_hysteresis_only_flag;
         sc.comparative_state.bucket_competition_percentile=s.bucket_competition_percentile;
         sc.comparative_state.bucket_member_quality_rank=s.bucket_member_quality_rank;
         sc.comparative_state.nearest_reserve_gap=s.nearest_reserve_gap;
         sc.comparative_state.position_security_class=PositionSecurityClassToString((int)s.position_security_class);
         sc.comparative_state.frontier_entry_reason_primary=SafeText(s.frontier_entry_reason_primary,"not_set");
         sc.comparative_state.frontier_confidence=s.frontier_confidence;
         sc.comparative_state.rankability_lane=(s.truth_class<=issx_truth_acceptable && h.history_ready_for_ranking ? "strong" : h.history_ready_for_ranking ? "usable" : (s.selected_frontier ? "exploratory" : "blocked"));
         sc.comparative_state.exploratory_penalty_applied=(sc.comparative_state.rankability_lane=="exploratory");
         sc.comparative_state.bucket_redundancy_penalty=Clamp01(s.comparison_penalty*0.50);
         sc.comparative_state.winner_archetype_class=(s.won_by_strength ? "strength_winner" : s.won_by_shortfall ? "thin_bucket_winner" : s.won_on_hysteresis_only_flag ? "continuity_winner" : "mixed_winner");

         if(has_opt)
           {
            sc.comparative_state.nearest_peer_similarity=opt.nearest_peer_similarity;
            sc.comparative_state.corr_valid=opt.corr_valid;
            sc.comparative_state.corr_quality_score=opt.corr_quality_score;
            sc.comparative_state.corr_reject_reason=SafeText(opt.corr_reject_reason,"not_available");
            sc.comparative_state.duplicate_penalty_applied=opt.duplicate_penalty_applied;
            sc.comparative_state.corr_penalty_applied=opt.corr_penalty_applied;
            sc.comparative_state.session_overlap_penalty_applied=opt.session_overlap_penalty_applied;
            sc.comparative_state.diversification_bonus_applied=opt.diversification_bonus_applied;
            sc.comparative_state.adjustment_confidence=opt.adjustment_confidence;
            sc.comparative_state.portfolio_role_hint=PortfolioRoleHintToString((int)opt.portfolio_role_hint);
            sc.comparative_state.structural_overlap_score=opt.structural_overlap_score;
            sc.comparative_state.statistical_overlap_score=opt.statistical_overlap_score;
            sc.comparative_state.pair_validity_class=SafeText(opt.pair_validity_class,(opt.corr_valid ? "valid_low_overlap" : "unknown_overlap"));
            sc.comparative_state.pair_sample_alignment_class=SafeText(opt.pair_sample_alignment_class,"unknown");
            sc.comparative_state.pair_window_freshness_class=SafeText(opt.pair_window_freshness_class,"unknown");
            sc.comparative_state.pair_regime_comparability_class=SafeText(opt.pair_regime_comparability_class,"unknown");
            sc.comparative_state.sample_count=opt.sample_count;
            sc.comparative_state.intelligence_abstained=opt.intelligence_abstained;
            sc.comparative_state.abstention_reason=SafeText(opt.abstention_reason,"none");
            sc.comparative_state.diversification_confidence_class=SafeText(opt.diversification_confidence_class,"unknown");
            sc.comparative_state.redundancy_risk_class=SafeText(opt.redundancy_risk_class,"unknown");
           }

         string contradiction_flags="";
         ISSX_ContradictionSeverity contradiction_sev=issx_contradiction_low;
         string local_class_counts="";
         string local_highest_blocking_class="none";
         int contradiction_steps=ContradictionPenaltySteps(m,h,s,opt,has_opt,contradiction_flags,contradiction_sev,local_class_counts,local_highest_blocking_class);

         sc.comparative_state.selection_utility_base_score=Clamp01(0.65*s.bucket_local_composite+0.20*h.judgment.history_data_quality_score+0.15*m.tradeability_baseline.blended_tradeability_score);
         sc.comparative_state.final_rank=++final_rank;
         sc.comparative_state.marginal_value_score=Clamp01(sc.comparative_state.selection_utility_base_score-0.25*s.comparison_penalty+(has_opt ? 0.10*opt.adjustment_confidence : 0.0));

         sc.quality_state.truth_class=FoldTruthClass(s.truth_class,TruthClassFromQualityScore(h.judgment.history_data_quality_score),issx_truth_acceptable);
         sc.quality_state.truth_breakdown="market="+DoubleToString(m.validated_runtime_truth.runtime_truth_score,4)+"|history="+DoubleToString(h.judgment.history_data_quality_score,4)+"|selection="+DoubleToString(s.bucket_local_composite,4);
         sc.quality_state.freshness_class=FoldFreshnessClass(s.freshness_class,h.freshness_class,m.symbol_lifecycle.resumed_from_persistence ? issx_freshness_aging : issx_freshness_fresh);
         sc.quality_state.freshness_breakdown="ea2="+FreshnessClassToString(h.freshness_class)+"|ea3="+FreshnessClassToString(s.freshness_class)+"|resumed="+ISSX_Util::BoolToString(m.symbol_lifecycle.resumed_from_persistence);
         sc.quality_state.completeness_score=ComputeCompletenessScore(m,h,s,(has_opt && opt.present));
         sc.quality_state.comparison_completeness_score=s.bucket_comparison_completeness;
         sc.quality_state.final_rank_confidence=ComputeFinalRankConfidence(m,h,s,opt,has_opt,contradiction_steps);
         sc.quality_state.judgment_readiness_score=Clamp01(0.45*sc.quality_state.completeness_score+0.35*sc.quality_state.final_rank_confidence+0.20*(1.0-s.comparison_penalty));
         sc.quality_state.authority_level_summary="classification=authoritative_validated|market=authoritative_observed|selection=derived_comparative|context=advisory_context";
         sc.quality_state.continuity_origin=m.symbol_lifecycle.continuity_origin;
         sc.quality_state.resumed_from_persistence=m.symbol_lifecycle.resumed_from_persistence;

         SeedContextState(sc.context_state,h,s);
         BuildIntegrityTable(sc.integrity_table,m,h,s,opt,has_opt);
         BuildComparisonContract(sc.comparison_contract,h,s,opt,has_opt);
         PopulateWinnerFreshnessSurface(sc.freshness_surface,state,m,ea2,has_opt,opt);
         PopulateWinnerRegimeBlock(sc.regime_block,m,h,opt,has_opt);
         PopulateWinnerExplanationBlock(sc.explanation_block,s,h,opt,has_opt);

         avg_truth+=(sc.quality_state.truth_class==issx_truth_strong ? 1.0 : sc.quality_state.truth_class==issx_truth_acceptable ? 0.75 : sc.quality_state.truth_class==issx_truth_degraded ? 0.45 : 0.20);
         avg_fresh+=(sc.quality_state.freshness_class==issx_freshness_fresh ? 1.0 : sc.quality_state.freshness_class==issx_freshness_usable ? 0.75 : sc.quality_state.freshness_class==issx_freshness_aging ? 0.45 : 0.20);

         if(sc.quality_state.truth_class>=issx_truth_degraded && ISSX_Util::IsEmpty(dominant_degrade)) dominant_degrade="truth_degraded";
         if(s.comparison_penalty>0.25 && ISSX_Util::IsEmpty(dominant_penalty)) dominant_penalty="comparison_penalty";

         if(contradiction_steps>0)
           {
            contradiction_count++;
            if(ISSX_Util::IsEmpty(major_flags)) major_flags=contradiction_flags; else major_flags+="|"+contradiction_flags;
            SeverityAccumulate(max_sev,contradiction_sev);
            if(contradiction_sev==issx_contradiction_blocking) blocking=true;
            if(local_highest_blocking_class!="none") highest_blocking_class=local_highest_blocking_class;

            string classes[6]={"identity","session","spec","history_continuity","selection_ownership","intelligence_validity"};
            for(int cc=0;cc<6;cc++)
              {
               string target=classes[cc]+":";
               int src_pos=StringFind(local_class_counts,target);
               if(src_pos>=0)
                 {
                  int src_start=src_pos+StringLen(target);
                  int src_delim=StringFind(local_class_counts,"|",src_start);
                  string src_value_text=(src_delim>=0 ? StringSubstr(local_class_counts,src_start,src_delim-src_start) : StringSubstr(local_class_counts,src_start));
                  int add_value=(int)StringToInteger(src_value_text);
                  for(int k=0;k<add_value;k++) AccumulateContradictionClassCount(contradiction_class_counts,classes[cc]);
                 }
              }
           }

         int n=ArraySize(state.symbols);
         if(ArrayResize(state.symbols,n+1)==(n+1))
           {
            state.symbols[n]=sc;
            publishable++;
            contract_build_count++;
            symbol_completed_count++;
           }
         else
           {
            if(state.debug_error_conditions=="none") state.debug_error_conditions="array_resize_failed";
            else state.debug_error_conditions+="|array_resize_failed";
           }
        }

      state.symbol_count=ArraySize(state.symbols);
      state.manifest.symbol_count=state.symbol_count;
      state.manifest.changed_symbol_count=state.symbol_count;
      state.header.symbol_count=state.symbol_count;
      state.header.changed_symbol_count=state.symbol_count;
      if(state.symbol_count>0){ avg_truth/=state.symbol_count; avg_fresh/=state.symbol_count; }

      state.market_readiness_summary.market_breadth_publishable=publishable;
      state.market_readiness_summary.bucket_coverage_quality=(publishable>=10 ? "broad" : publishable>=5 ? "adequate" : publishable>0 ? "thin" : "weak");
      state.market_readiness_summary.dominant_degradation_reason=(dominant_degrade=="" ? "none" : dominant_degrade);
      state.market_readiness_summary.dominant_penalty_family=(dominant_penalty=="" ? "none" : dominant_penalty);
      state.market_readiness_summary.safe_to_reason_normally=(publishable>0 && !blocking && state.source_summary.cohort_state!=issx_cohort_degraded);
      state.market_readiness_summary.system_truth_class=(avg_truth>=0.85 ? issx_truth_strong : avg_truth>=0.65 ? issx_truth_acceptable : avg_truth>=0.40 ? issx_truth_degraded : issx_truth_weak);
      state.market_readiness_summary.system_freshness_class=(avg_fresh>=0.85 ? issx_freshness_fresh : avg_fresh>=0.65 ? issx_freshness_usable : avg_fresh>=0.40 ? issx_freshness_aging : issx_freshness_stale);
      state.market_readiness_summary.system_publishability_state=(publishable<=0 ? issx_publishability_not_ready : blocking ? issx_publishability_usable_degraded : publishable>=8 ? issx_publishability_strong : publishable>=3 ? issx_publishability_usable : issx_publishability_usable_degraded);

      state.answer_mode=(any_intel && state.source_summary.cohort_state!=issx_cohort_degraded ? issx_ea5_answer_intelligence_enriched : (publishable>0 ? issx_ea5_answer_selection_first : issx_ea5_answer_degraded_selection_only));
      state.degraded_flag=(state.answer_mode==issx_ea5_answer_degraded_selection_only || blocking || state.source_summary.upstream_partial_progress_flag);
      state.projection_partial_success_flag=false;

      state.contradiction_summary.contradiction_count=contradiction_count;
      state.contradiction_summary.contradiction_severity_max=max_sev;
      state.contradiction_summary.blocking_contradiction_present=blocking;
      state.contradiction_summary.major_contradiction_flags=major_flags;
      state.contradiction_summary.contradiction_class_counts=contradiction_class_counts;
      state.contradiction_summary.highest_blocking_contradiction_class=highest_blocking_class;
      state.contradiction_summary.contradiction_repair_state=(blocking ? "blocking_unrepaired" : contradiction_count>0 ? "degraded_but_publishable" : "none");

      state.manifest.compatibility_class=state.source_summary.compatibility_worst_class;
      state.manifest.contradiction_count=contradiction_count;
      state.manifest.contradiction_severity_max=max_sev;
      state.manifest.degraded_flag=state.degraded_flag;
      state.manifest.fallback_depth_used=state.source_summary.max_fallback_depth_used;
      state.manifest.accepted_strong_count=(state.degraded_flag ? 0 : state.symbol_count);
      state.manifest.accepted_degraded_count=(state.degraded_flag ? state.symbol_count : 0);
      state.manifest.rejected_count=0;
      state.manifest.cooldown_count=0;
      state.manifest.stale_usable_count=(state.market_readiness_summary.system_freshness_class>=issx_freshness_aging ? state.symbol_count : 0);
      state.manifest.projection_partial_success_flag=state.projection_partial_success_flag;
      state.manifest.accepted_promotion_verified=false;
      state.manifest.legend_hash=state.legend_hash;
      state.manifest.stage_minimum_ready_flag=(state.symbol_count>0);
      state.manifest.stage_publishability_state=state.market_readiness_summary.system_publishability_state;
      state.manifest.handoff_mode=state.source_summary.upstream_handoff_mode;
      state.manifest.handoff_sequence_no=state.source_summary.upstream_handoff_sequence_no;
      state.manifest.fallback_read_ratio_1h=state.source_summary.fallback_read_ratio_1h;
      state.manifest.fresh_accept_ratio_1h=state.source_summary.fresh_accept_ratio_1h;
      state.manifest.same_tick_handoff_ratio_1h=state.source_summary.same_tick_handoff_ratio_1h;

      state.header.contradiction_count=contradiction_count;
      state.header.contradiction_severity_max=max_sev;
      state.header.degraded_flag=state.degraded_flag;
      state.header.fallback_depth_used=state.source_summary.max_fallback_depth_used;

      state.why_export_is_thin=(publishable>=5 ? "none" : publishable>0 ? "rankable_subset_thin" : "no_publishable_symbols");
      state.why_publish_is_stale=(state.market_readiness_summary.system_freshness_class>=issx_freshness_aging ? "upstream_aging" : "none");
      state.why_frontier_is_small=(publishable>=5 ? "none" : "frontier_depth_limited");
      state.why_intelligence_abstained=(any_intel ? "none" : "ea4_absent_or_abstained");
      state.largest_backlog_owner=(!ea2.stage_minimum_ready_flag ? "ea2" : !ea3.stage_minimum_ready_flag ? "ea3" : "none");
      state.oldest_unserved_queue_family=(!ea2.stage_minimum_ready_flag ? "history_deep_queue" : !ea3.stage_minimum_ready_flag ? "selection_frontier_queue" : "none");

      state.debug_candidate_selected_count=selected_candidate_count;
      state.debug_symbols_started_count=symbol_started_count;
      state.debug_symbols_completed_count=symbol_completed_count;
      state.debug_contract_build_count=contract_build_count;
      state.debug_skipped_missing_ea1_count=skipped_missing_ea1_count;
      state.debug_skipped_missing_ea2_count=skipped_missing_ea2_count;
      state.debug_skipped_capacity_count=skipped_capacity_count;
      state.debug_optional_intelligence_count=optional_intelligence_count;
      state.debug_batch_truncated=batch_truncated;
      state.debug_batch_progress=IntegerToString(contract_build_count)+"/"+IntegerToString(selected_candidate_count);
      state.debug_estimated_export_bytes=(contract_build_count*safe_per_symbol_bytes);
      state.debug_ready_state=(state.manifest.stage_minimum_ready_flag && state.market_readiness_summary.system_publishability_state!=issx_publishability_not_ready ? "ready" : "not_ready");
      state.debug_partial_state=((state.source_summary.upstream_partial_progress_flag || state.debug_batch_truncated || state.degraded_flag) ? "partial" : "none");
      if(state.debug_batch_truncated)
        {
         if(state.debug_error_conditions=="none") state.debug_error_conditions="batch_cap_reached";
         else state.debug_error_conditions+="|batch_cap_reached";
        }
      if(state.debug_estimated_export_bytes>state.payload_budget.hard_max_bytes)
        {
         if(state.debug_error_conditions=="none") state.debug_error_conditions="estimated_export_over_hard_max";
         else state.debug_error_conditions+="|estimated_export_over_hard_max";
        }
     }

   static bool StageSlice(ISSX_EA5_State &state,const ISSX_EA1_State &ea1,const ISSX_EA2_State &ea2,const ISSX_EA3_State &ea3,const ISSX_EA5_OptionalIntelligence &optional_intelligence[])
     {
      BuildFromInputs(state,ea1,ea2,ea3,optional_intelligence);
      return true;
     }

   static ISSX_AcceptanceResult EvaluateForGptExport(const ISSX_EA5_State &state)
     {
      ISSX_AcceptanceResult ar; ZeroMemory(ar);
      ar.accepted=false; ar.acceptance_type=issx_accept_rejected; ar.compatibility_class=state.manifest.compatibility_class;
      ar.compatibility_score=(state.source_summary.compatibility_worst_class==issx_compatibility_exact ? 100 : state.source_summary.compatibility_worst_class==issx_compatibility_compatible ? 80 : state.source_summary.compatibility_worst_class==issx_compatibility_compatible_degraded ? 60 : 0);
      ar.accepted_strong_count=(state.degraded_flag ? 0 : state.symbol_count);
      ar.accepted_degraded_count=(state.degraded_flag ? state.symbol_count : 0);
      ar.rejected_count=0; ar.cooldown_count=0;
      ar.stale_usable_count=(state.market_readiness_summary.system_freshness_class>=issx_freshness_aging ? state.symbol_count : 0);
      ar.contradiction_count=state.contradiction_summary.contradiction_count;
      ar.contradiction_severity_max=state.contradiction_summary.contradiction_severity_max;
      ar.blocking_contradiction_present=state.contradiction_summary.blocking_contradiction_present;

      if(state.symbol_count<=0){ ar.reason="no_publishable_symbols"; return ar; }
      if(state.market_readiness_summary.system_publishability_state==issx_publishability_not_ready){ ar.reason="publishability_not_ready"; return ar; }
      if(state.source_summary.compatibility_worst_class==issx_compatibility_incompatible){ ar.reason="incompatible_upstream"; return ar; }
      if(state.contradiction_summary.blocking_contradiction_present){ ar.accepted=true; ar.acceptance_type=issx_accept_degraded; ar.reason="accepted_degraded_due_to_blocking_contradictions"; return ar; }

      ar.accepted=true;
      ar.acceptance_type=((state.degraded_flag || state.source_summary.upstream_partial_progress_flag || state.market_readiness_summary.system_freshness_class>=issx_freshness_aging) ? issx_accept_degraded : issx_accept_gpt_export);
      ar.reason=(ar.acceptance_type==issx_accept_gpt_export ? "accepted_for_gpt_export" : "accepted_degraded");
      return ar;
     }

   static string BuildStageJson(const ISSX_EA5_State &state,ISSX_FieldRegistry &field_registry,ISSX_EnumRegistry &enum_registry)
     {
      string out="{";
      out+="\"producer\":\"ISSX ConsolidationCore\"";
      out+=",\"module_version\":\""+ISSX_Util::EscapeJson(ISSX_CONTRACTS_MODULE_VERSION)+"\"";
      out+=",\"stage\":\"ea5\"";
      out+=",\"schema_version\":\""+ISSX_Util::EscapeJson(ISSX_SCHEMA_VERSION)+"\"";
      out+=",\"schema_epoch\":"+IntegerToString(ISSX_SCHEMA_EPOCH);

      string legend=LegendJson(field_registry,enum_registry);
      out+=","+StringSubstr(legend,1,StringLen(legend)-2);

      out+=",\"contract_meta\":{";
      out+="\"stage_api_version\":\""+ISSX_Util::EscapeJson(state.stage_api_version)+"\"";
      out+=",\"serializer_version\":\""+ISSX_Util::EscapeJson(state.serializer_version)+"\"";
      out+=",\"external_contract_version\":\""+ISSX_Util::EscapeJson(state.external_contract_version)+"\"";
      out+=",\"owner_module_name\":\""+ISSX_Util::EscapeJson(state.owner_module_name)+"\"";
      out+=",\"owner_module_hash\":\""+ISSX_Util::EscapeJson(state.owner_module_hash)+"\"";
      out+=",\"policy_fingerprint\":\""+ISSX_Util::EscapeJson(state.manifest.policy_fingerprint)+"\"";
      out+=",\"fingerprint_algorithm_version\":\""+ISSX_Util::EscapeJson(state.fingerprint_algorithm_version)+"\"";
      out+=",\"source_snapshot_kind\":\""+ISSX_Util::EscapeJson(state.source_snapshot_kind)+"\"";
      out+=",\"legend_present\":"+ISSX_Util::BoolToString(state.legend_present);
      out+="}";

      out+=",\"minute_id\":"+ISSX_Util::LongToStringX((long)(state.manifest.minute_id));
      out+=",\"sequence_no\":"+ISSX_Util::LongToStringX((long)(state.manifest.sequence_no));
      out+=",\"answer_mode\":\""+AnswerModeToString(state.answer_mode)+"\"";
      out+=",\"export_profile\":\""+ExportProfileToString(state.export_profile)+"\"";
      out+=",\"degraded_flag\":"+ISSX_Util::BoolToString(state.degraded_flag);
      out+=",\"projection_partial_success_flag\":"+ISSX_Util::BoolToString(state.projection_partial_success_flag);

      out+=",\"payload_budget\":{\"target_bytes\":"+IntegerToString(state.payload_budget.target_bytes)+",\"hard_max_bytes\":"+IntegerToString(state.payload_budget.hard_max_bytes)+",\"per_symbol_target_bytes\":"+IntegerToString(state.payload_budget.per_symbol_target_bytes)+",\"max_bars_per_symbol_total\":"+IntegerToString(state.payload_budget.max_bars_per_symbol_total)+"}";

      out+=",\"age_surface\":{\"export_generated_at\":"+ISSX_Util::LongToStringX((long)(state.age_surface.export_generated_at))+",\"ea1_age_sec\":"+IntegerToString(state.age_surface.ea1_age_sec)+",\"ea2_age_sec\":"+IntegerToString(state.age_surface.ea2_age_sec)+",\"ea3_age_sec\":"+IntegerToString(state.age_surface.ea3_age_sec)+",\"ea4_age_sec\":"+IntegerToString(state.age_surface.ea4_age_sec)+",\"source_generation_ids\":\""+ISSX_Util::EscapeJson(state.age_surface.source_generation_ids)+"\"}";

      out+=",\"source_summary\":{";
      out+="\"ea1_source_used\":\""+ISSX_Util::EscapeJson(state.source_summary.ea1_source_used)+"\"";
      out+=",\"ea2_source_used\":\""+ISSX_Util::EscapeJson(state.source_summary.ea2_source_used)+"\"";
      out+=",\"ea3_source_used\":\""+ISSX_Util::EscapeJson(state.source_summary.ea3_source_used)+"\"";
      out+=",\"ea4_source_used\":\""+ISSX_Util::EscapeJson(state.source_summary.ea4_source_used)+"\"";
      out+=",\"cohort_state\":\""+CohortStateToString(state.source_summary.cohort_state)+"\"";
      out+=",\"max_fallback_depth_used\":"+IntegerToString(state.source_summary.max_fallback_depth_used);
      out+=",\"compatibility_worst_class\":\""+CompatibilityClassToString(state.source_summary.compatibility_worst_class)+"\"";
      out+=",\"upstream_handoff_compatibility_class\":\""+CompatibilityClassToString(state.source_summary.upstream_handoff_compatibility_class)+"\"";
      out+=",\"recovery_publish_flag\":"+ISSX_Util::BoolToString(state.source_summary.recovery_publish_flag);
      out+=",\"upstream_handoff_mode\":\""+HandoffModeToString(state.source_summary.upstream_handoff_mode)+"\"";
      out+=",\"upstream_handoff_same_tick_flag\":"+ISSX_Util::BoolToString(state.source_summary.upstream_handoff_same_tick_flag);
      out+=",\"upstream_partial_progress_flag\":"+ISSX_Util::BoolToString(state.source_summary.upstream_partial_progress_flag);
      out+=",\"upstream_handoff_sequence_no\":"+ISSX_Util::LongToStringX(state.source_summary.upstream_handoff_sequence_no);
      out+=",\"upstream_payload_hash\":\""+ISSX_Util::EscapeJson(state.source_summary.upstream_payload_hash)+"\"";
      out+=",\"upstream_policy_fingerprint\":\""+ISSX_Util::EscapeJson(state.source_summary.upstream_policy_fingerprint)+"\"";
      out+=",\"source_snapshot_kind\":\""+ISSX_Util::EscapeJson(state.source_summary.source_snapshot_kind)+"\"";
      out+=",\"ea4_attached_flag\":"+ISSX_Util::BoolToString(state.source_summary.ea4_attached_flag);
      out+=",\"ea4_abstained_flag\":"+ISSX_Util::BoolToString(state.source_summary.ea4_abstained_flag);
      out+=",\"ea4_signal_count\":"+IntegerToString(state.source_summary.ea4_signal_count);
      out+=",\"fallback_read_ratio_1h\":"+DoubleToString(state.source_summary.fallback_read_ratio_1h,6);
      out+=",\"fresh_accept_ratio_1h\":"+DoubleToString(state.source_summary.fresh_accept_ratio_1h,6);
      out+=",\"same_tick_handoff_ratio_1h\":"+DoubleToString(state.source_summary.same_tick_handoff_ratio_1h,6);
      out+="}";

      out+=",\"contradiction_summary\":{\"contradiction_count\":"+IntegerToString(state.contradiction_summary.contradiction_count)+",\"contradiction_severity_max\":\""+ContradictionSeverityToString(state.contradiction_summary.contradiction_severity_max)+"\",\"blocking_contradiction_present\":"+ISSX_Util::BoolToString(state.contradiction_summary.blocking_contradiction_present)+",\"major_contradiction_flags\":\""+ISSX_Util::EscapeJson(state.contradiction_summary.major_contradiction_flags)+"\",\"contradiction_class_counts\":\""+ISSX_Util::EscapeJson(state.contradiction_summary.contradiction_class_counts)+"\",\"highest_blocking_contradiction_class\":\""+ISSX_Util::EscapeJson(state.contradiction_summary.highest_blocking_contradiction_class)+"\",\"contradiction_repair_state\":\""+ISSX_Util::EscapeJson(state.contradiction_summary.contradiction_repair_state)+"\"}";

      string cg=ConsumerGuidanceJson();
      out+=","+StringSubstr(cg,1,StringLen(cg)-2);

      out+=",\"market_readiness_summary\":{\"system_truth_class\":\""+TruthClassToString(state.market_readiness_summary.system_truth_class)+"\",\"system_freshness_class\":\""+FreshnessClassToString(state.market_readiness_summary.system_freshness_class)+"\",\"system_publishability_state\":\""+PublishabilityStateToString(state.market_readiness_summary.system_publishability_state)+"\",\"market_breadth_publishable\":"+IntegerToString(state.market_readiness_summary.market_breadth_publishable)+",\"bucket_coverage_quality\":\""+ISSX_Util::EscapeJson(state.market_readiness_summary.bucket_coverage_quality)+"\",\"dominant_degradation_reason\":\""+ISSX_Util::EscapeJson(state.market_readiness_summary.dominant_degradation_reason)+"\",\"dominant_penalty_family\":\""+ISSX_Util::EscapeJson(state.market_readiness_summary.dominant_penalty_family)+"\",\"safe_to_reason_normally\":"+ISSX_Util::BoolToString(state.market_readiness_summary.safe_to_reason_normally)+"}";
      out+=",\"symptom_summaries\":{\"why_export_is_thin\":\""+ISSX_Util::EscapeJson(state.why_export_is_thin)+"\",\"why_publish_is_stale\":\""+ISSX_Util::EscapeJson(state.why_publish_is_stale)+"\",\"why_frontier_is_small\":\""+ISSX_Util::EscapeJson(state.why_frontier_is_small)+"\",\"why_intelligence_abstained\":\""+ISSX_Util::EscapeJson(state.why_intelligence_abstained)+"\",\"largest_backlog_owner\":\""+ISSX_Util::EscapeJson(state.largest_backlog_owner)+"\",\"oldest_unserved_queue_family\":\""+ISSX_Util::EscapeJson(state.oldest_unserved_queue_family)+"\"}";

      out+=",\"symbols\":[";
      bool first_symbol=true;
      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         ISSX_EA5_SymbolContract s=state.symbols[i];
         if(!first_symbol) out+=",";
         first_symbol=false;
         out+="{";
         out+="\"identity\":{\"symbol_raw\":\""+ISSX_Util::EscapeJson(s.symbol_raw)+"\",\"symbol_norm\":\""+ISSX_Util::EscapeJson(s.symbol_norm)+"\",\"canonical_root\":\""+ISSX_Util::EscapeJson(s.canonical_root)+"\",\"alias_family_id\":\""+ISSX_Util::EscapeJson(s.alias_family_id)+"\",\"market_representation_id\":\""+ISSX_Util::EscapeJson(s.market_representation_id)+"\"}";
         out+=",\"absolute_state\":{";
         out+="\"classification\":{\"asset_class\":\""+ISSX_Util::EscapeJson(s.asset_class)+"\",\"instrument_family\":\""+ISSX_Util::EscapeJson(s.instrument_family)+"\",\"theme_bucket\":\""+ISSX_Util::EscapeJson(s.theme_bucket)+"\",\"equity_sector\":\""+ISSX_Util::EscapeJson(s.equity_sector)+"\",\"leader_bucket_id\":\""+ISSX_Util::EscapeJson(s.leader_bucket_id)+"\",\"leader_bucket_type\":\""+ISSX_Util::EscapeJson(s.leader_bucket_type)+"\",\"classification_reliability_score\":"+DoubleToString(s.classification_reliability_score,6)+",\"taxonomy_action_taken\":\""+ISSX_Util::EscapeJson(s.taxonomy_action_taken)+"\"}";
         out+=",\"observability\":{\"practical_market_state\":\""+ISSX_Util::EscapeJson(s.practical_market_state)+"\",\"practical_market_state_reason_codes\":\""+ISSX_Util::EscapeJson(s.practical_market_state_reason_codes)+"\",\"runtime_truth_score\":"+DoubleToString(s.runtime_truth_score,6)+",\"observation_density_score\":"+DoubleToString(s.observation_density_score,6)+"}";
         out+=",\"spec\":{\"point\":"+DoubleToString(s.point,8)+",\"tick_size\":"+DoubleToString(s.tick_size,8)+",\"contract_size\":"+DoubleToString(s.contract_size,4)+",\"volume_min\":"+DoubleToString(s.volume_min,4)+",\"volume_step\":"+DoubleToString(s.volume_step,4)+",\"stops_level\":"+IntegerToString(s.stops_level)+",\"freeze_level\":"+IntegerToString(s.freeze_level)+"}";
         out+=",\"session\":{\"session_reconciliation_state\":\""+ISSX_Util::EscapeJson(s.session_reconciliation_state)+"\",\"session_truth_confidence\":"+DoubleToString(s.session_truth_confidence,6)+",\"session_phase\":\""+ISSX_Util::EscapeJson(s.session_phase)+"\",\"minutes_since_session_open\":"+IntegerToString(s.minutes_since_session_open)+",\"minutes_to_session_close\":"+IntegerToString(s.minutes_to_session_close)+",\"transition_penalty_active\":"+ISSX_Util::BoolToString(s.transition_penalty_active)+"}";
         out+=",\"market\":{\"bid\":"+DoubleToString(s.bid,6)+",\"ask\":"+DoubleToString(s.ask,6)+",\"mid\":"+DoubleToString(s.mid,6)+",\"spread_now_points\":"+DoubleToString(s.spread_now_points,4)+",\"spread_median_short_points\":"+DoubleToString(s.spread_median_short_points,4)+",\"spread_p90_short_points\":"+DoubleToString(s.spread_p90_short_points,4)+",\"spread_widening_ratio\":"+DoubleToString(s.spread_widening_ratio,6)+",\"quote_interval_median_ms\":"+DoubleToString(s.quote_interval_median_ms,3)+",\"quote_interval_p90_ms\":"+DoubleToString(s.quote_interval_p90_ms,3)+",\"quote_stall_rate\":"+DoubleToString(s.quote_stall_rate,6)+"}";
         out+=",\"cost\":{\"tradeability_class\":\""+ISSX_Util::EscapeJson(s.tradeability_class)+"\",\"structural_tradeability_score\":"+DoubleToString(s.structural_tradeability_score,6)+",\"live_tradeability_score\":"+DoubleToString(s.live_tradeability_score,6)+",\"blended_tradeability_score\":"+DoubleToString(s.blended_tradeability_score,6)+",\"entry_cost_score\":"+DoubleToString(s.entry_cost_score,6)+",\"size_practicality_score\":"+DoubleToString(s.size_practicality_score,6)+",\"economic_consistency_score\":"+DoubleToString(s.economic_consistency_score,6)+",\"all_in_cost_confidence\":"+DoubleToString(s.all_in_cost_confidence,6)+",\"commission_state\":\""+ISSX_Util::EscapeJson(s.commission_state)+"\",\"swap_state\":\""+ISSX_Util::EscapeJson(s.swap_state)+"\"}";
         out+=",\"history\":{\"history_data_quality_score\":"+DoubleToString(s.history_data_quality_score,6)+",\"tf_m5_trust\":\""+ISSX_Util::EscapeJson(s.tf_m5_trust)+"\",\"tf_m15_trust\":\""+ISSX_Util::EscapeJson(s.tf_m15_trust)+"\",\"tf_h1_trust\":\""+ISSX_Util::EscapeJson(s.tf_h1_trust)+"\",\"history_provenance\":\""+ISSX_Util::EscapeJson(s.history_provenance)+"\",\"history_judgment_packet\":\""+ISSX_Util::EscapeJson(s.history_judgment_packet)+"\",\"compact_ohlc_pack\":{\"pack_version\":\""+ISSX_Util::EscapeJson(s.compact_ohlc_pack.pack_version)+"\",\"has_data\":"+ISSX_Util::BoolToString(s.compact_ohlc_pack.has_data)+",\"completed_bars_only\":"+ISSX_Util::BoolToString(s.compact_ohlc_pack.completed_bars_only)+",\"source_note\":\""+ISSX_Util::EscapeJson(s.compact_ohlc_pack.source_note)+"\",\"m5_last_12\":"+OhlcArrayJson(s.compact_ohlc_pack.m5_last_12)+",\"m15_last_12\":"+OhlcArrayJson(s.compact_ohlc_pack.m15_last_12)+",\"h1_last_8\":"+OhlcArrayJson(s.compact_ohlc_pack.h1_last_8)+"}}";
         out+="}";
         out+=",\"comparative_state\":{";
         out+="\"selection\":{\"bucket_local_composite\":"+DoubleToString(s.comparative_state.bucket_local_composite,6)+",\"bucket_rank\":"+IntegerToString(s.comparative_state.bucket_rank)+",\"bucket_top5_rank\":"+IntegerToString(s.comparative_state.bucket_top5_rank)+",\"won_by_strength\":"+ISSX_Util::BoolToString(s.comparative_state.won_by_strength)+",\"won_by_shortfall\":"+ISSX_Util::BoolToString(s.comparative_state.won_by_shortfall)+",\"won_on_hysteresis_only_flag\":"+ISSX_Util::BoolToString(s.comparative_state.won_on_hysteresis_only_flag)+",\"bucket_competition_percentile\":"+DoubleToString(s.comparative_state.bucket_competition_percentile,6)+",\"bucket_member_quality_rank\":"+IntegerToString(s.comparative_state.bucket_member_quality_rank)+",\"nearest_reserve_gap\":"+DoubleToString(s.comparative_state.nearest_reserve_gap,6)+",\"position_security_class\":\""+ISSX_Util::EscapeJson(s.comparative_state.position_security_class)+"\",\"frontier_entry_reason_primary\":\""+ISSX_Util::EscapeJson(s.comparative_state.frontier_entry_reason_primary)+"\",\"frontier_confidence\":"+DoubleToString(s.comparative_state.frontier_confidence,6)+",\"rankability_lane\":\""+ISSX_Util::EscapeJson(s.comparative_state.rankability_lane)+"\",\"exploratory_penalty_applied\":"+ISSX_Util::BoolToString(s.comparative_state.exploratory_penalty_applied)+",\"bucket_redundancy_penalty\":"+DoubleToString(s.comparative_state.bucket_redundancy_penalty,6)+",\"winner_archetype_class\":\""+ISSX_Util::EscapeJson(s.comparative_state.winner_archetype_class)+"\",\"reserve_promoted_for_diversity_flag\":"+ISSX_Util::BoolToString(s.comparative_state.reserve_promoted_for_diversity_flag)+",\"redundancy_swap_reason\":\""+ISSX_Util::EscapeJson(s.comparative_state.redundancy_swap_reason)+"\"}";
         out+=",\"intelligence\":{\"nearest_peer_similarity\":"+DoubleToString(s.comparative_state.nearest_peer_similarity,6)+",\"corr_valid\":"+ISSX_Util::BoolToString(s.comparative_state.corr_valid)+",\"corr_quality_score\":"+DoubleToString(s.comparative_state.corr_quality_score,6)+",\"corr_reject_reason\":\""+ISSX_Util::EscapeJson(s.comparative_state.corr_reject_reason)+"\",\"duplicate_penalty_applied\":"+ISSX_Util::BoolToString(s.comparative_state.duplicate_penalty_applied)+",\"corr_penalty_applied\":"+ISSX_Util::BoolToString(s.comparative_state.corr_penalty_applied)+",\"session_overlap_penalty_applied\":"+ISSX_Util::BoolToString(s.comparative_state.session_overlap_penalty_applied)+",\"diversification_bonus_applied\":"+ISSX_Util::BoolToString(s.comparative_state.diversification_bonus_applied)+",\"adjustment_confidence\":"+DoubleToString(s.comparative_state.adjustment_confidence,6)+",\"portfolio_role_hint\":\""+ISSX_Util::EscapeJson(s.comparative_state.portfolio_role_hint)+"\",\"structural_overlap_score\":"+DoubleToString(s.comparative_state.structural_overlap_score,6)+",\"statistical_overlap_score\":"+DoubleToString(s.comparative_state.statistical_overlap_score,6)+",\"pair_validity_class\":\""+ISSX_Util::EscapeJson(s.comparative_state.pair_validity_class)+"\",\"pair_sample_alignment_class\":\""+ISSX_Util::EscapeJson(s.comparative_state.pair_sample_alignment_class)+"\",\"pair_window_freshness_class\":\""+ISSX_Util::EscapeJson(s.comparative_state.pair_window_freshness_class)+"\",\"pair_regime_comparability_class\":\""+ISSX_Util::EscapeJson(s.comparative_state.pair_regime_comparability_class)+"\",\"sample_count\":"+IntegerToString(s.comparative_state.sample_count)+",\"intelligence_abstained\":"+ISSX_Util::BoolToString(s.comparative_state.intelligence_abstained)+",\"abstention_reason\":\""+ISSX_Util::EscapeJson(s.comparative_state.abstention_reason)+"\",\"diversification_confidence_class\":\""+ISSX_Util::EscapeJson(s.comparative_state.diversification_confidence_class)+"\",\"redundancy_risk_class\":\""+ISSX_Util::EscapeJson(s.comparative_state.redundancy_risk_class)+"\"}";
         out+=",\"ranks\":{\"selection_utility_base_score\":"+DoubleToString(s.comparative_state.selection_utility_base_score,6)+",\"final_rank\":"+IntegerToString(s.comparative_state.final_rank)+",\"marginal_value_score\":"+DoubleToString(s.comparative_state.marginal_value_score,6)+"}}";
         out+=",\"quality_state\":{\"truth_class\":\""+TruthClassToString(s.quality_state.truth_class)+"\",\"truth_breakdown\":\""+ISSX_Util::EscapeJson(s.quality_state.truth_breakdown)+"\",\"freshness_class\":\""+FreshnessClassToString(s.quality_state.freshness_class)+"\",\"freshness_breakdown\":\""+ISSX_Util::EscapeJson(s.quality_state.freshness_breakdown)+"\",\"completeness_score\":"+DoubleToString(s.quality_state.completeness_score,6)+",\"comparison_completeness_score\":"+DoubleToString(s.quality_state.comparison_completeness_score,6)+",\"final_rank_confidence\":"+DoubleToString(s.quality_state.final_rank_confidence,6)+",\"judgment_readiness_score\":"+DoubleToString(s.quality_state.judgment_readiness_score,6)+",\"authority_level_summary\":\""+ISSX_Util::EscapeJson(s.quality_state.authority_level_summary)+"\",\"continuity_origin\":\""+ContinuityOriginToString(s.quality_state.continuity_origin)+"\",\"resumed_from_persistence\":"+ISSX_Util::BoolToString(s.quality_state.resumed_from_persistence)+"}";
         out+=",\"context_state\":{\"trade_judgment_context\":{\"range_20m_points\":"+DoubleToString(s.context_state.range_20m_points,4)+",\"range_60m_points\":"+DoubleToString(s.context_state.range_60m_points,4)+",\"range_240m_points\":"+DoubleToString(s.context_state.range_240m_points,4)+",\"distance_from_day_open_points\":"+DoubleToString(s.context_state.distance_from_day_open_points,4)+",\"distance_from_prev_close_points\":"+DoubleToString(s.context_state.distance_from_prev_close_points,4)+",\"pct_of_day_range\":"+DoubleToString(s.context_state.pct_of_day_range,6)+",\"pct_of_20m_range\":"+DoubleToString(s.context_state.pct_of_20m_range,6)+",\"pct_of_60m_range\":"+DoubleToString(s.context_state.pct_of_60m_range,6)+",\"pct_of_240m_range\":"+DoubleToString(s.context_state.pct_of_240m_range,6)+",\"micro_noise_risk\":"+DoubleToString(s.context_state.micro_noise_risk,6)+",\"structure_clarity_score\":"+DoubleToString(s.context_state.structure_clarity_score,6)+",\"compression_score\":"+DoubleToString(s.context_state.compression_score,6)+",\"expansion_score\":"+DoubleToString(s.context_state.expansion_score,6)+",\"breakout_proximity_score\":"+DoubleToString(s.context_state.breakout_proximity_score,6)+",\"structure_stability_score\":"+DoubleToString(s.context_state.structure_stability_score,6)+",\"holding_window_fit_20_60m\":"+DoubleToString(s.context_state.holding_window_fit_20_60m,6)+",\"holding_window_fit_60_180m\":"+DoubleToString(s.context_state.holding_window_fit_60_180m,6)+",\"holding_window_fit_180_480m\":"+DoubleToString(s.context_state.holding_window_fit_180_480m,6)+"},\"intraday_context\":{\"session_open\":"+ISSX_Util::LongToStringX((long)(s.context_state.session_open))+",\"day_open\":"+DoubleToString(s.context_state.day_open,6)+",\"rolling_1h_high\":"+DoubleToString(s.context_state.rolling_1h_high,6)+",\"rolling_1h_low\":"+DoubleToString(s.context_state.rolling_1h_low,6)+",\"rolling_4h_high\":"+DoubleToString(s.context_state.rolling_4h_high,6)+",\"rolling_4h_low\":"+DoubleToString(s.context_state.rolling_4h_low,6)+",\"range_position_day\":"+DoubleToString(s.context_state.range_position_day,6)+",\"range_position_4h\":"+DoubleToString(s.context_state.range_position_4h,6)+",\"bar_progress_m5_pct\":"+DoubleToString(s.context_state.bar_progress_m5_pct,6)+",\"bar_progress_m15_pct\":"+DoubleToString(s.context_state.bar_progress_m15_pct,6)+"},\"explain\":{\"why_selected_top3\":\""+ISSX_Util::EscapeJson(s.context_state.why_selected_top3)+"\",\"why_penalized_top3\":\""+ISSX_Util::EscapeJson(s.context_state.why_penalized_top3)+"\",\"why_not_higher_top3\":\""+ISSX_Util::EscapeJson(s.context_state.why_not_higher_top3)+"\",\"key_use_constraints\":\""+ISSX_Util::EscapeJson(s.context_state.key_use_constraints)+"\",\"symbol_digest\":\""+ISSX_Util::EscapeJson(s.context_state.symbol_digest)+"\"}}";
         out+=",\"freshness_surface\":{\"winner_history_age_m5_sec\":"+IntegerToString(s.freshness_surface.winner_history_age_m5_sec)+",\"winner_history_age_m15_sec\":"+IntegerToString(s.freshness_surface.winner_history_age_m15_sec)+",\"winner_history_age_h1_sec\":"+IntegerToString(s.freshness_surface.winner_history_age_h1_sec)+",\"winner_history_age_by_tf\":\""+ISSX_Util::EscapeJson(s.freshness_surface.winner_history_age_by_tf)+"\",\"winner_quote_age_sec\":"+IntegerToString(s.freshness_surface.winner_quote_age_sec)+",\"winner_tradeability_refresh_age_sec\":"+IntegerToString(s.freshness_surface.winner_tradeability_refresh_age_sec)+",\"winner_rank_refresh_age_sec\":"+IntegerToString(s.freshness_surface.winner_rank_refresh_age_sec)+",\"winner_regime_refresh_age_sec\":"+IntegerToString(s.freshness_surface.winner_regime_refresh_age_sec)+",\"winner_corr_refresh_age_sec\":"+IntegerToString(s.freshness_surface.winner_corr_refresh_age_sec)+",\"winner_last_material_change_sec\":"+IntegerToString(s.freshness_surface.winner_last_material_change_sec)+"}";
         out+=",\"regime_block\":{\"intraday_activity_state\":\""+ISSX_Util::EscapeJson(s.regime_block.intraday_activity_state)+"\",\"liquidity_regime_class\":\""+ISSX_Util::EscapeJson(s.regime_block.liquidity_regime_class)+"\",\"volatility_regime_class\":\""+ISSX_Util::EscapeJson(s.regime_block.volatility_regime_class)+"\",\"expansion_state_class\":\""+ISSX_Util::EscapeJson(s.regime_block.expansion_state_class)+"\",\"movement_quality_class\":\""+ISSX_Util::EscapeJson(s.regime_block.movement_quality_class)+"\",\"movement_maturity_class\":\""+ISSX_Util::EscapeJson(s.regime_block.movement_maturity_class)+"\",\"session_phase_class\":\""+ISSX_Util::EscapeJson(s.regime_block.session_phase_class)+"\",\"tradability_now_class\":\""+ISSX_Util::EscapeJson(s.regime_block.tradability_now_class)+"\",\"constructability_class\":\""+ISSX_Util::EscapeJson(s.regime_block.constructability_class)+"\",\"holding_horizon_context\":\""+ISSX_Util::EscapeJson(s.regime_block.holding_horizon_context)+"\",\"movement_to_cost_efficiency_class\":\""+ISSX_Util::EscapeJson(s.regime_block.movement_to_cost_efficiency_class)+"\",\"early_move_quality_class\":\""+ISSX_Util::EscapeJson(s.regime_block.early_move_quality_class)+"\",\"diversification_confidence_class\":\""+ISSX_Util::EscapeJson(s.regime_block.diversification_confidence_class)+"\",\"redundancy_risk_class\":\""+ISSX_Util::EscapeJson(s.regime_block.redundancy_risk_class)+"\",\"opportunity_with_caution_flag\":"+ISSX_Util::BoolToString(s.regime_block.opportunity_with_caution_flag)+"}";
         out+=",\"explanation_block\":{\"selection_reason_summary\":\""+ISSX_Util::EscapeJson(s.explanation_block.selection_reason_summary)+"\",\"selection_penalty_summary\":\""+ISSX_Util::EscapeJson(s.explanation_block.selection_penalty_summary)+"\",\"regime_summary\":\""+ISSX_Util::EscapeJson(s.explanation_block.regime_summary)+"\",\"execution_condition_summary\":\""+ISSX_Util::EscapeJson(s.explanation_block.execution_condition_summary)+"\",\"diversification_context_summary\":\""+ISSX_Util::EscapeJson(s.explanation_block.diversification_context_summary)+"\",\"winner_limitation_summary\":\""+ISSX_Util::EscapeJson(s.explanation_block.winner_limitation_summary)+"\",\"winner_confidence_class\":\""+ISSX_Util::EscapeJson(s.explanation_block.winner_confidence_class)+"\"}";
         out+=",\"integrity_table\":{\"classification\":"+IntegrityBlockJson(s.integrity_table.classification)+",\"observability\":"+IntegrityBlockJson(s.integrity_table.observability)+",\"tradeability\":"+IntegrityBlockJson(s.integrity_table.tradeability)+",\"session\":"+IntegrityBlockJson(s.integrity_table.session)+",\"market\":"+IntegrityBlockJson(s.integrity_table.market)+",\"history\":"+IntegrityBlockJson(s.integrity_table.history)+",\"bucket_selection\":"+IntegrityBlockJson(s.integrity_table.bucket_selection)+",\"intelligence\":"+IntegrityBlockJson(s.integrity_table.intelligence)+",\"final_context\":"+IntegrityBlockJson(s.integrity_table.final_context)+"}";
         out+=",\"comparison_contract\":{\"safe_to_compare_bucket_score\":"+ISSX_Util::BoolToString(s.comparison_contract.safe_to_compare_bucket_score)+",\"safe_to_compare_final_rank\":"+ISSX_Util::BoolToString(s.comparison_contract.safe_to_compare_final_rank)+",\"safe_to_compare_history_metrics\":"+ISSX_Util::BoolToString(s.comparison_contract.safe_to_compare_history_metrics)+",\"comparison_limitations\":\""+ISSX_Util::EscapeJson(s.comparison_contract.comparison_limitations)+"\",\"comparison_completeness_score\":"+DoubleToString(s.comparison_contract.comparison_completeness_score,6)+"}";
         out+=",\"decision_neutrality\":{\"contains_directional_opinion\":"+ISSX_Util::BoolToString(s.decision_neutrality.contains_directional_opinion)+",\"contains_trade_instruction\":"+ISSX_Util::BoolToString(s.decision_neutrality.contains_trade_instruction)+",\"contains_execution_logic\":"+ISSX_Util::BoolToString(s.decision_neutrality.contains_execution_logic)+",\"contains_bias_projection\":"+ISSX_Util::BoolToString(s.decision_neutrality.contains_bias_projection)+",\"suitable_for_human_or_model_judgment\":"+ISSX_Util::BoolToString(s.decision_neutrality.suitable_for_human_or_model_judgment)+"}";
         out+="}";
        }
      out+="]}";
      return out;
     }

   static string ToStageJson(const ISSX_EA5_State &state,ISSX_FieldRegistry &field_registry,ISSX_EnumRegistry &enum_registry){ return BuildStageJson(state,field_registry,enum_registry); }

   static string BuildDebugJson(const ISSX_EA5_State &state)
     {
      string out="{";
      out+="\"stage\":\"ea5_debug\"";
      out+=",\"module_version\":\""+ISSX_Util::EscapeJson(ISSX_CONTRACTS_MODULE_VERSION)+"\"";
      out+=",\"stage_api_version\":\""+ISSX_Util::EscapeJson(state.stage_api_version)+"\"";
      out+=",\"serializer_version\":\""+ISSX_Util::EscapeJson(state.serializer_version)+"\"";
      out+=",\"owner_module_hash\":\""+ISSX_Util::EscapeJson(state.owner_module_hash)+"\"";
      out+=",\"sequence_no\":"+ISSX_Util::LongToStringX((long)(state.manifest.sequence_no));
      out+=",\"minute_id\":"+ISSX_Util::LongToStringX((long)(state.manifest.minute_id));
      out+=",\"answer_mode\":\""+ISSX_Util::EscapeJson(AnswerModeToString(state.answer_mode))+"\"";
      out+=",\"export_profile\":\""+ISSX_Util::EscapeJson(ExportProfileToString(state.export_profile))+"\"";
      out+=",\"symbol_count\":"+IntegerToString(state.symbol_count);
      out+=",\"degraded_flag\":"+ISSX_Util::BoolToString(state.degraded_flag);
      out+=",\"projection_partial_success_flag\":"+ISSX_Util::BoolToString(state.projection_partial_success_flag);
      out+=",\"source_snapshot_kind\":\""+ISSX_Util::EscapeJson(state.source_snapshot_kind)+"\"";
      out+=",\"cohort_state\":\""+ISSX_Util::EscapeJson(CohortStateToString(state.source_summary.cohort_state))+"\"";
      out+=",\"compatibility_worst_class\":\""+ISSX_Util::EscapeJson(CompatibilityClassToString(state.source_summary.compatibility_worst_class))+"\"";
      out+=",\"upstream_partial_progress_flag\":"+ISSX_Util::BoolToString(state.source_summary.upstream_partial_progress_flag);
      out+=",\"contradiction_count\":"+IntegerToString(state.contradiction_summary.contradiction_count);
      out+=",\"contradiction_severity_max\":\""+ISSX_Util::EscapeJson(ContradictionSeverityToString(state.contradiction_summary.contradiction_severity_max))+"\"";
      out+=",\"blocking_contradiction_present\":"+ISSX_Util::BoolToString(state.contradiction_summary.blocking_contradiction_present);
      out+=",\"major_contradiction_flags\":\""+ISSX_Util::EscapeJson(state.contradiction_summary.major_contradiction_flags)+"\"";
      out+=",\"contradiction_class_counts\":\""+ISSX_Util::EscapeJson(state.contradiction_summary.contradiction_class_counts)+"\"";
      out+=",\"market_breadth_publishable\":"+IntegerToString(state.market_readiness_summary.market_breadth_publishable);
      out+=",\"stage_publishability_state\":\""+ISSX_Util::EscapeJson(PublishabilityStateToString(state.market_readiness_summary.system_publishability_state))+"\"";
      out+=",\"dominant_degradation_reason\":\""+ISSX_Util::EscapeJson(state.market_readiness_summary.dominant_degradation_reason)+"\"";
      out+=",\"dominant_penalty_family\":\""+ISSX_Util::EscapeJson(state.market_readiness_summary.dominant_penalty_family)+"\"";
      out+=",\"largest_backlog_owner\":\""+ISSX_Util::EscapeJson(state.largest_backlog_owner)+"\"";
      out+=",\"oldest_unserved_queue_family\":\""+ISSX_Util::EscapeJson(state.oldest_unserved_queue_family)+"\"";
      out+=",\"fallback_read_ratio_1h\":"+DoubleToString(state.source_summary.fallback_read_ratio_1h,6);
      out+=",\"fresh_accept_ratio_1h\":"+DoubleToString(state.source_summary.fresh_accept_ratio_1h,6);
      out+=",\"same_tick_handoff_ratio_1h\":"+DoubleToString(state.source_summary.same_tick_handoff_ratio_1h,6);
      out+=",\"contracts_discovery_attempt\":{\"attempt_count\":"+IntegerToString(state.debug_discovery_attempt_count)+",\"candidates_selected\":"+IntegerToString(state.debug_candidate_selected_count)+"}";
      out+=",\"contracts_symbol_start\":{\"count\":"+IntegerToString(state.debug_symbols_started_count)+",\"batch_cap\":"+IntegerToString(state.debug_batch_cap)+"}";
      out+=",\"contracts_symbol_complete\":{\"count\":"+IntegerToString(state.debug_symbols_completed_count)+",\"skipped_missing_ea1\":"+IntegerToString(state.debug_skipped_missing_ea1_count)+",\"skipped_missing_ea2\":"+IntegerToString(state.debug_skipped_missing_ea2_count)+"}";
      out+=",\"contracts_contract_build_start\":{\"selected_candidates\":"+IntegerToString(state.debug_candidate_selected_count)+"}";
      out+=",\"contracts_contract_build_complete\":{\"built\":"+IntegerToString(state.debug_contract_build_count)+",\"optional_intelligence_attached\":"+IntegerToString(state.debug_optional_intelligence_count)+"}";
      out+=",\"contracts_batch_start\":{\"cap\":"+IntegerToString(state.debug_batch_cap)+"}";
      out+=",\"contracts_batch_progress\":\""+ISSX_Util::EscapeJson(state.debug_batch_progress)+"\"";
      out+=",\"contracts_batch_complete\":{\"truncated\":"+ISSX_Util::BoolToString(state.debug_batch_truncated)+",\"skipped_capacity\":"+IntegerToString(state.debug_skipped_capacity_count)+"}";
      out+=",\"contracts_export_start\":{\"estimated_export_bytes\":"+IntegerToString(state.debug_estimated_export_bytes)+"}";
      out+=",\"contracts_export_complete\":{\"hard_max_bytes\":"+IntegerToString(state.payload_budget.hard_max_bytes)+",\"target_bytes\":"+IntegerToString(state.payload_budget.target_bytes)+"}";
      out+=",\"contracts_ready_state\":\""+ISSX_Util::EscapeJson(state.debug_ready_state)+"\"";
      out+=",\"contracts_partial_state\":\""+ISSX_Util::EscapeJson(state.debug_partial_state)+"\"";
      out+=",\"contracts_error_conditions\":\""+ISSX_Util::EscapeJson(state.debug_error_conditions)+"\"";
      out+=",\"contracts_persistence_interactions\":\""+ISSX_Util::EscapeJson(state.debug_persistence_interactions)+"\"";
      out+=",\"top_symbols\":[";
      bool first=true;
      int limit=MathMin(ArraySize(state.symbols),10);
      for(int i=0;i<limit;i++)
        {
         ISSX_EA5_SymbolContract sym=state.symbols[i];
         if(!first) out+=",";
         first=false;
         out+="{\"symbol_norm\":\""+ISSX_Util::EscapeJson(sym.symbol_norm)+"\",\"leader_bucket_id\":\""+ISSX_Util::EscapeJson(sym.leader_bucket_id)+"\",\"final_rank\":"+IntegerToString(sym.comparative_state.final_rank)+",\"final_rank_confidence\":"+DoubleToString(sym.quality_state.final_rank_confidence,6)+",\"truth_class\":\""+ISSX_Util::EscapeJson(TruthClassToString(sym.quality_state.truth_class))+"\",\"freshness_class\":\""+ISSX_Util::EscapeJson(FreshnessClassToString(sym.quality_state.freshness_class))+"\",\"rankability_lane\":\""+ISSX_Util::EscapeJson(sym.comparative_state.rankability_lane)+"\",\"pair_validity_class\":\""+ISSX_Util::EscapeJson(sym.comparative_state.pair_validity_class)+"\",\"constraints\":\""+ISSX_Util::EscapeJson(sym.context_state.key_use_constraints)+"\"}";
        }
      out+="]}";
      return out;
     }

   static string ToDebugJson(const ISSX_EA5_State &state){ return BuildDebugJson(state); }
   static string BuildDebugSnapshot(const ISSX_EA5_State &state){ return BuildDebugJson(state); }

   static bool StagePublish(ISSX_EA5_State &state,ISSX_FieldRegistry &field_registry,ISSX_EnumRegistry &enum_registry,string &stage_json,string &debug_json)
     {
      state.legend_hash=ComputeLegendHash(field_registry,enum_registry);
      state.legend_present=true;
      state.manifest.legend_hash=state.legend_hash;
      stage_json=BuildStageJson(state,field_registry,enum_registry);
      debug_json=BuildDebugJson(state);
      return (StringLen(stage_json)>2);
     }
  };



string ISSX_ContractsDiagTag()
  {
   return "contracts_diag_v174f";
  }


string ISSX_ContractsDebugSignature()
  {
   return ISSX_ContractsDiagTag();
  }

#endif // __ISSX_CONTRACTS_MQH__
