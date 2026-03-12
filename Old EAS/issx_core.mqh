#ifndef __ISSX_CORE_MQH__
#define __ISSX_CORE_MQH__
// ============================================================================
// ISSX CORE v1.7.0
// Shared foundation for the consolidated single-EA / five-stage ISSX kernel.
//
// OWNERSHIP IN THIS MODULE
// - shared schema / storage / policy constants
// - central field-name keys
// - central enums and neutral classifications
// - stage header / manifest / acceptance / scheduler DTOs
// - compact utility helpers
// - time helpers
// - deterministic lightweight hashing fallback
// - compact JSON writer
// - path and stage helper functions
//
// DESIGN RULES
// - MT5 only
// - wrapper stays thin
// - truth state, work state, and projection state stay distinct
// - public root files are views, not authoritative truth
// - no market/history/selection business logic lives here
// ============================================================================

// ============================================================================
// SECTION 01: VERSION / CONSTANTS
// ============================================================================

#define ISSX_ENGINE_NAME                    "ISSX"
#define ISSX_ENGINE_FAMILY                  "ISSX_PIPELINE"
#define ISSX_ENGINE_VERSION                 "1.7.0"
#define ISSX_SCHEMA_VERSION                 "1.7.0"
#define ISSX_SCHEMA_EPOCH                   10700
#define ISSX_STORAGE_VERSION                1700
#define ISSX_POLICY_FINGERPRINT_VERSION     1700
#define ISSX_FINGERPRINT_ALGO_VERSION       2
#define ISSX_LEGEND_VERSION                 "1.7.0"

#define ISSX_BINARY_MAGIC                   0x49535358
#define ISSX_BINARY_MAGIC_ALT               0x49535358
#define ISSX_HASH_HEX_WIDTH                 16
#define ISSX_MAX_JSON_DEPTH                 64
#define ISSX_MAX_TRACE_CODE_LEN             96
#define ISSX_MAX_FIELD_NAME_LEN             96
#define ISSX_MAX_REASON_LEN                 256
#define ISSX_MAX_CHANGED_IDS                512
#define ISSX_MAX_SYMBOLS_PER_TRACE          32

#define ISSX_PATH_SEP                       "/"
#define ISSX_JSON_EXT                       ".json"
#define ISSX_BIN_EXT                        ".bin"

#define ISSX_DIR_ROOT_NAME                  "ISSX"
#define ISSX_DIR_FIRMS                      "FIRMS"
#define ISSX_DIR_PERSISTENCE                "persistence"
#define ISSX_DIR_PERSISTENCE_SHARED         "persistence/shared"
#define ISSX_DIR_PERSISTENCE_EA1            "persistence/ea1"
#define ISSX_DIR_PERSISTENCE_EA2            "persistence/ea2"
#define ISSX_DIR_PERSISTENCE_EA3            "persistence/ea3"
#define ISSX_DIR_PERSISTENCE_EA4            "persistence/ea4"
#define ISSX_DIR_PERSISTENCE_EA5            "persistence/ea5"
#define ISSX_DIR_PERSISTENCE_EA1_UNIVERSE   "persistence/ea1/universe"
#define ISSX_DIR_PERSISTENCE_EA2_HISTORY_STORE "persistence/ea2/history_store"
#define ISSX_DIR_PERSISTENCE_EA2_HISTORY_INDEX "persistence/ea2/history_index"
#define ISSX_DIR_DEBUG                      "debug"
#define ISSX_DIR_LOCKS                      "locks"
#define ISSX_DIR_SCHEMAS                    "schemas"
#define ISSX_DIR_HUD                        "hud"

#define ISSX_ROOT_EXPORT                    "issx_export.json"
#define ISSX_ROOT_DEBUG                     "issx_debug.json"
#define ISSX_ROOT_STAGE_STATUS              "issx_stage_status.json"
#define ISSX_ROOT_UNIVERSE_SNAPSHOT         "issx_universe_snapshot.json"

#define ISSX_LOCK_FILENAME                  "issx.lock"

#define ISSX_BIN_HEADER_CURRENT             "header_current.bin"
#define ISSX_BIN_HEADER_PREVIOUS            "header_previous.bin"
#define ISSX_BIN_HEADER_CANDIDATE           "header_candidate.bin"
#define ISSX_BIN_PAYLOAD_CURRENT            "payload_current.bin"
#define ISSX_BIN_PAYLOAD_PREVIOUS           "payload_previous.bin"
#define ISSX_BIN_PAYLOAD_LASTGOOD           "payload_last_good.bin"
#define ISSX_BIN_PAYLOAD_CANDIDATE          "payload_candidate.bin"
#define ISSX_JSON_MANIFEST_CURRENT          "manifest_current.json"
#define ISSX_JSON_MANIFEST_PREVIOUS         "manifest_previous.json"
#define ISSX_JSON_MANIFEST_LASTGOOD         "manifest_last_good.json"
#define ISSX_JSON_MANIFEST_CANDIDATE        "manifest_candidate.json"
#define ISSX_BIN_CONTINUITY_STATE           "continuity_state.bin"
#define ISSX_BIN_PHASE_STATE                "phase_state.bin"
#define ISSX_BIN_QUEUE_STATE                "queue_state.bin"
#define ISSX_BIN_CACHE_STATE                "cache_state.bin"

#define ISSX_BIN_BROKER_UNIVERSE_CURRENT    "broker_universe_current.bin"
#define ISSX_BIN_BROKER_UNIVERSE_PREVIOUS   "broker_universe_previous.bin"
#define ISSX_JSON_BROKER_UNIVERSE_MANIFEST  "broker_universe_manifest.json"
#define ISSX_JSON_BROKER_UNIVERSE_SNAPSHOT  "broker_universe_snapshot.json"

#define ISSX_BIN_HISTORY_SYMBOL_REGISTRY    "symbol_registry.bin"
#define ISSX_BIN_HISTORY_TIMEFRAME_INDEX    "timeframe_index.bin"
#define ISSX_BIN_HISTORY_HYDRATION_CURSOR   "hydration_cursor_state.bin"
#define ISSX_BIN_HISTORY_DIRTY_SET          "dirty_set.bin"
#define ISSX_JSON_BAR_STORE_MANIFEST        "bar_store_manifest.json"

#define ISSX_BIN_SHARD_SYMBOL_REGISTRY      "shard_symbol_registry.bin"
#define ISSX_BIN_SHARD_HISTORY_INDEX        "shard_history_index.bin"
#define ISSX_BIN_SHARD_BUCKET_STATE         "shard_bucket_state.bin"
#define ISSX_BIN_SHARD_PAIR_CACHE           "shard_pair_cache.bin"
#define ISSX_BIN_SHARD_CONTEXT_CACHE        "shard_context_cache.bin"
#define ISSX_BIN_SHARD_DELTA_INDEX          "shard_delta_index.bin"

#define ISSX_DEBUG_SNAPSHOT_EA1             "ea1_debug_snapshot.json"
#define ISSX_DEBUG_SNAPSHOT_EA2             "ea2_debug_snapshot.json"
#define ISSX_DEBUG_SNAPSHOT_EA3             "ea3_debug_snapshot.json"
#define ISSX_DEBUG_SNAPSHOT_EA4             "ea4_debug_snapshot.json"
#define ISSX_DEBUG_SNAPSHOT_EA5             "ea5_debug_snapshot.json"

#define ISSX_HISTORY_STORE_M5               "M5"
#define ISSX_HISTORY_STORE_M15              "M15"
#define ISSX_HISTORY_STORE_H1               "H1"

#define ISSX_DEFAULT_RETAINED_BARS_M5       750
#define ISSX_DEFAULT_RETAINED_BARS_M15      750
#define ISSX_DEFAULT_RETAINED_BARS_H1       750

#define ISSX_EVENT_TIMER_SEC                1
#define ISSX_EA5_EXPORT_CADENCE_MIN         10

#define ISSX_ACCEPTANCE_OK                  0
#define ISSX_ACCEPTANCE_ERR_INCOMPLETE      1001
#define ISSX_ACCEPTANCE_ERR_STAGE_MISMATCH  1002
#define ISSX_ACCEPTANCE_ERR_FIRM_MISMATCH   1003
#define ISSX_ACCEPTANCE_ERR_SCHEMA          1004
#define ISSX_ACCEPTANCE_ERR_SEQUENCE        1005
#define ISSX_ACCEPTANCE_ERR_HASH            1006
#define ISSX_ACCEPTANCE_ERR_FILESET         1007
#define ISSX_ACCEPTANCE_ERR_TOPBLOCK        1008
#define ISSX_ACCEPTANCE_ERR_PARSE           1009
#define ISSX_ACCEPTANCE_ERR_COMPATIBILITY   1010
#define ISSX_ACCEPTANCE_ERR_SEMANTIC        1011
#define ISSX_ACCEPTANCE_ERR_CANDIDATE_SET   1012
#define ISSX_ACCEPTANCE_ERR_MANIFEST        1013
#define ISSX_ACCEPTANCE_ERR_ROOT_PROJECTION 1014
#define ISSX_ACCEPTANCE_ERR_STORAGE         1015
#define ISSX_ACCEPTANCE_ERR_GENERATION      1016
#define ISSX_ACCEPTANCE_ERR_POLICY          1017
#define ISSX_ACCEPTANCE_ERR_COHERENCE       1018

// ============================================================================
// SECTION 02: FIELD KEY REGISTRY CONSTANTS
// These string constants provide a single spelling owner for shared field names.
// ============================================================================

#define ISSX_FIELD_STAGE_MINIMUM_READY_FLAG        "stage_minimum_ready_flag"
#define ISSX_FIELD_STAGE_PUBLISHABILITY_STATE      "stage_publishability_state"
#define ISSX_FIELD_UPSTREAM_HANDOFF_MODE           "upstream_handoff_mode"
#define ISSX_FIELD_UPSTREAM_HANDOFF_SAME_TICK_FLAG "upstream_handoff_same_tick_flag"
#define ISSX_FIELD_UPSTREAM_PARTIAL_PROGRESS_FLAG  "upstream_partial_progress_flag"
#define ISSX_FIELD_WAREHOUSE_QUALITY               "warehouse_quality"
#define ISSX_FIELD_WAREHOUSE_RETAINED_BAR_COUNT    "warehouse_retained_bar_count"
#define ISSX_FIELD_DUMP_SEQUENCE_NO                "dump_sequence_no"
#define ISSX_FIELD_DUMP_MINUTE_ID                  "dump_minute_id"
#define ISSX_FIELD_DEBUG_WEAK_LINK_CODE            "debug_weak_link_code"
#define ISSX_FIELD_DEPENDENCY_BLOCK_REASON         "dependency_block_reason"
#define ISSX_FIELD_KERNEL_DEGRADED_CYCLE_FLAG      "kernel_degraded_cycle_flag"
#define ISSX_FIELD_FALLBACK_READ_RATIO_1H          "fallback_read_ratio_1h"
#define ISSX_FIELD_SAME_TICK_HANDOFF_RATIO_1H      "same_tick_handoff_ratio_1h"
#define ISSX_FIELD_FRESH_ACCEPT_RATIO_1H           "fresh_accept_ratio_1h"
#define ISSX_FIELD_POLICY_FINGERPRINT              "policy_fingerprint"
#define ISSX_FIELD_FINGERPRINT_ALGO_VERSION        "fingerprint_algorithm_version"
#define ISSX_FIELD_CONTRADICTION_CLASS_COUNTS      "contradiction_class_counts"
#define ISSX_FIELD_HIGHEST_BLOCKING_CONTRADICTION  "highest_blocking_contradiction_class"
#define ISSX_FIELD_COVERAGE_RANKABLE_RECENT_PCT    "coverage_rankable_recent_pct"
#define ISSX_FIELD_COVERAGE_FRONTIER_RECENT_PCT    "coverage_frontier_recent_pct"
#define ISSX_FIELD_HISTORY_DEEP_COMPLETION_PCT     "history_deep_completion_pct"
#define ISSX_FIELD_WINNER_CACHE_DEPENDENCE_PCT     "winner_cache_dependence_pct"
#define ISSX_FIELD_CLOCK_DIVERGENCE_SEC            "clock_divergence_sec"
#define ISSX_FIELD_SCHEDULER_LATE_BY_MS            "scheduler_late_by_ms"
#define ISSX_FIELD_MISSED_SCHEDULE_WINDOWS_EST     "missed_schedule_windows_estimate"
#define ISSX_FIELD_PAIR_VALIDITY_CLASS             "pair_validity_class"
#define ISSX_FIELD_PAIR_SAMPLE_ALIGNMENT_CLASS     "pair_sample_alignment_class"
#define ISSX_FIELD_PAIR_WINDOW_FRESHNESS_CLASS     "pair_window_freshness_class"
#define ISSX_FIELD_WAREHOUSE_CLIP_FLAG             "warehouse_clip_flag"
#define ISSX_FIELD_WARMUP_SUFFICIENT_FLAG          "warmup_sufficient_flag"
#define ISSX_FIELD_EFFECTIVE_LOOKBACK_BARS         "effective_lookback_bars"
#define ISSX_FIELD_RANKABILITY_LANE                "rankability_lane"
#define ISSX_FIELD_EXPLORATORY_PENALTY_APPLIED     "exploratory_penalty_applied"
#define ISSX_FIELD_INTRADAY_ACTIVITY_STATE         "intraday_activity_state"
#define ISSX_FIELD_LIQUIDITY_REGIME_CLASS          "liquidity_regime_class"
#define ISSX_FIELD_VOLATILITY_REGIME_CLASS         "volatility_regime_class"
#define ISSX_FIELD_EXPANSION_STATE_CLASS           "expansion_state_class"
#define ISSX_FIELD_MOVEMENT_QUALITY_CLASS          "movement_quality_class"
#define ISSX_FIELD_MOVEMENT_MATURITY_CLASS         "movement_maturity_class"
#define ISSX_FIELD_SESSION_PHASE_CLASS             "session_phase_class"
#define ISSX_FIELD_TRADABILITY_NOW_CLASS           "tradability_now_class"
#define ISSX_FIELD_HOLDING_HORIZON_CONTEXT         "holding_horizon_context"
#define ISSX_FIELD_CONSTRUCTABILITY_CLASS          "constructability_class"
#define ISSX_FIELD_DIVERSIFICATION_CONFIDENCE      "diversification_confidence_class"
#define ISSX_FIELD_REDUNDANCY_RISK_CLASS           "redundancy_risk_class"
#define ISSX_FIELD_SELECTION_REASON_SUMMARY        "selection_reason_summary"
#define ISSX_FIELD_SELECTION_PENALTY_SUMMARY       "selection_penalty_summary"
#define ISSX_FIELD_WINNER_LIMITATION_SUMMARY       "winner_limitation_summary"
#define ISSX_FIELD_WINNER_CONFIDENCE_CLASS         "winner_confidence_class"
#define ISSX_FIELD_OPPORTUNITY_WITH_CAUTION_FLAG   "opportunity_with_caution_flag"
#define ISSX_FIELD_EARLY_MOVE_QUALITY_CLASS        "early_move_quality_class"
#define ISSX_FIELD_MOVEMENT_TO_COST_EFFICIENCY     "movement_to_cost_efficiency_class"

// universe / coverage / fingerprints
#define ISSX_FIELD_BROKER_UNIVERSE_FINGERPRINT     "broker_universe_fingerprint"
#define ISSX_FIELD_ELIGIBLE_UNIVERSE_FINGERPRINT   "eligible_universe_fingerprint"
#define ISSX_FIELD_ACTIVE_UNIVERSE_FINGERPRINT     "active_universe_fingerprint"
#define ISSX_FIELD_RANKABLE_UNIVERSE_FINGERPRINT   "rankable_universe_fingerprint"
#define ISSX_FIELD_FRONTIER_UNIVERSE_FINGERPRINT   "frontier_universe_fingerprint"
#define ISSX_FIELD_PUBLISHABLE_UNIVERSE_FINGERPRINT "publishable_universe_fingerprint"
#define ISSX_FIELD_CHANGED_SYMBOL_COUNT            "changed_symbol_count"
#define ISSX_FIELD_CHANGED_SYMBOL_IDS              "changed_symbol_ids"
#define ISSX_FIELD_CHANGED_FAMILY_COUNT            "changed_family_count"
#define ISSX_FIELD_CHANGED_BUCKET_COUNT            "changed_bucket_count"
#define ISSX_FIELD_CHANGED_FRONTIER_COUNT          "changed_frontier_count"
#define ISSX_FIELD_CHANGED_TIMEFRAME_COUNT         "changed_timeframe_count"
#define ISSX_FIELD_PERCENT_UNIVERSE_TOUCHED_RECENT "percent_universe_touched_recent"
#define ISSX_FIELD_PERCENT_RANKABLE_REVALIDATED    "percent_rankable_revalidated_recent"
#define ISSX_FIELD_PERCENT_FRONTIER_REVALIDATED    "percent_frontier_revalidated_recent"
#define ISSX_FIELD_NEVER_SERVICED_COUNT            "never_serviced_count"
#define ISSX_FIELD_OVERDUE_SERVICE_COUNT           "overdue_service_count"
#define ISSX_FIELD_NEVER_RANKED_BUT_ELIGIBLE_COUNT "never_ranked_but_eligible_count"
#define ISSX_FIELD_NEWLY_ACTIVE_SYMBOLS_WAITING    "newly_active_symbols_waiting_count"
#define ISSX_FIELD_NEAR_CUTLINE_RECHECK_AGE_MAX    "near_cutline_recheck_age_max"

// timer / scheduler / queue surface
#define ISSX_FIELD_MINUTE_EPOCH_SOURCE             "minute_epoch_source"
#define ISSX_FIELD_SCHEDULER_CLOCK_SOURCE          "scheduler_clock_source"
#define ISSX_FIELD_FRESHNESS_CLOCK_SOURCE          "freshness_clock_source"
#define ISSX_FIELD_TIMER_GAP_MS_NOW                "timer_gap_ms_now"
#define ISSX_FIELD_TIMER_GAP_MS_MEAN               "timer_gap_ms_mean"
#define ISSX_FIELD_TIMER_GAP_MS_P95                "timer_gap_ms_p95"
#define ISSX_FIELD_QUOTE_CLOCK_IDLE_FLAG           "quote_clock_idle_flag"
#define ISSX_FIELD_CLOCK_SANITY_SCORE              "clock_sanity_score"
#define ISSX_FIELD_CLOCK_ANOMALY_FLAG              "clock_anomaly_flag"
#define ISSX_FIELD_TIME_PENALTY_APPLIED            "time_penalty_applied"
#define ISSX_FIELD_KERNEL_MINUTE_ID                "kernel_minute_id"
#define ISSX_FIELD_SCHEDULER_CYCLE_NO              "scheduler_cycle_no"
#define ISSX_FIELD_CURRENT_STAGE_SLOT              "current_stage_slot"
#define ISSX_FIELD_CURRENT_STAGE_PHASE             "current_stage_phase"
#define ISSX_FIELD_CURRENT_STAGE_BUDGET_MS         "current_stage_budget_ms"
#define ISSX_FIELD_CURRENT_STAGE_DEADLINE_MS       "current_stage_deadline_ms"
#define ISSX_FIELD_KERNEL_BUDGET_TOTAL_MS          "kernel_budget_total_ms"
#define ISSX_FIELD_KERNEL_BUDGET_SPENT_MS          "kernel_budget_spent_ms"
#define ISSX_FIELD_KERNEL_BUDGET_RESERVED_COMMIT_MS "kernel_budget_reserved_commit_ms"
#define ISSX_FIELD_KERNEL_BUDGET_DEBT_MS           "kernel_budget_debt_ms"
#define ISSX_FIELD_KERNEL_FORCED_SERVICE_DUE_FLAG  "kernel_forced_service_due_flag"
#define ISSX_FIELD_KERNEL_OVERRUN_CLASS            "kernel_overrun_class"
#define ISSX_FIELD_DISCOVERY_BUDGET_MS             "discovery_budget_ms"
#define ISSX_FIELD_PROBE_BUDGET_MS                 "probe_budget_ms"
#define ISSX_FIELD_QUOTE_SAMPLING_BUDGET_MS        "quote_sampling_budget_ms"
#define ISSX_FIELD_HISTORY_WARM_BUDGET_MS          "history_warm_budget_ms"
#define ISSX_FIELD_HISTORY_DEEP_BUDGET_MS          "history_deep_budget_ms"
#define ISSX_FIELD_PAIR_BUDGET_MS                  "pair_budget_ms"
#define ISSX_FIELD_CACHE_BUDGET_MS                 "cache_budget_ms"
#define ISSX_FIELD_PERSISTENCE_BUDGET_MS           "persistence_budget_ms"
#define ISSX_FIELD_PUBLISH_BUDGET_MS               "publish_budget_ms"
#define ISSX_FIELD_DEBUG_BUDGET_MS                 "debug_budget_ms"
#define ISSX_FIELD_FRESHNESS_FASTLANE_BUDGET_MS    "freshness_fastlane_budget_ms"
#define ISSX_FIELD_DISCOVERY_CURSOR                "discovery_cursor"
#define ISSX_FIELD_SPEC_PROBE_CURSOR               "spec_probe_cursor"
#define ISSX_FIELD_RUNTIME_SAMPLE_CURSOR           "runtime_sample_cursor"
#define ISSX_FIELD_HISTORY_WARM_CURSOR             "history_warm_cursor"
#define ISSX_FIELD_HISTORY_DEEP_CURSOR             "history_deep_cursor"
#define ISSX_FIELD_BUCKET_REBUILD_CURSOR           "bucket_rebuild_cursor"
#define ISSX_FIELD_PAIR_QUEUE_CURSOR               "pair_queue_cursor"
#define ISSX_FIELD_REPAIR_CURSOR                   "repair_cursor"
#define ISSX_FIELD_ROTATION_WINDOW_ESTIMATED_CYCLES "rotation_window_estimated_cycles"
#define ISSX_FIELD_DEEP_BACKLOG_REMAINING          "deep_backlog_remaining"
#define ISSX_FIELD_SECTOR_COLD_BACKLOG_COUNT       "sector_cold_backlog_count"

// debug / weak link / health
#define ISSX_FIELD_WEAKEST_STAGE                   "weakest_stage"
#define ISSX_FIELD_WEAKEST_STAGE_REASON            "weakest_stage_reason"
#define ISSX_FIELD_WEAK_LINK_SEVERITY              "weak_link_severity"
#define ISSX_FIELD_ERROR_WEIGHT                    "error_weight"
#define ISSX_FIELD_DEGRADE_WEIGHT                  "degrade_weight"
#define ISSX_FIELD_DEPENDENCY_WEIGHT               "dependency_weight"
#define ISSX_FIELD_FALLBACK_WEIGHT                 "fallback_weight"
#define ISSX_FIELD_FRONTIER_REFRESH_LAG_NEW_MOVERS "frontier_refresh_lag_for_new_movers"
#define ISSX_FIELD_SELECTION_LATENCY_RISK_CLASS    "selection_latency_risk_class"
#define ISSX_FIELD_NEVER_RANKED_NOW_OBSERVABLE     "never_ranked_but_now_observable_count"

// winner / export freshness
#define ISSX_FIELD_EXPORT_GENERATED_AT             "export_generated_at"
#define ISSX_FIELD_EA1_AGE_SEC                     "ea1_age_sec"
#define ISSX_FIELD_EA2_AGE_SEC                     "ea2_age_sec"
#define ISSX_FIELD_EA3_AGE_SEC                     "ea3_age_sec"
#define ISSX_FIELD_EA4_AGE_SEC                     "ea4_age_sec"
#define ISSX_FIELD_SOURCE_GENERATION_IDS           "source_generation_ids"
#define ISSX_FIELD_WINNER_HISTORY_AGE_BY_TF        "winner_history_age_by_tf"
#define ISSX_FIELD_WINNER_QUOTE_AGE_SEC            "winner_quote_age_sec"
#define ISSX_FIELD_WINNER_TRADEABILITY_REFRESH_AGE "winner_tradeability_refresh_age_sec"
#define ISSX_FIELD_WINNER_RANK_REFRESH_AGE         "winner_rank_refresh_age_sec"
#define ISSX_FIELD_WINNER_REGIME_REFRESH_AGE       "winner_regime_refresh_age_sec"
#define ISSX_FIELD_WINNER_CORR_REFRESH_AGE         "winner_corr_refresh_age_sec"
#define ISSX_FIELD_WINNER_LAST_MATERIAL_CHANGE_SEC "winner_last_material_change_sec"
#define ISSX_FIELD_REGIME_SUMMARY                  "regime_summary"
#define ISSX_FIELD_EXECUTION_CONDITION_SUMMARY     "execution_condition_summary"
#define ISSX_FIELD_DIVERSIFICATION_CONTEXT_SUMMARY "diversification_context_summary"
#define ISSX_FIELD_WHY_EXPORT_IS_THIN              "why_export_is_thin"
#define ISSX_FIELD_WHY_PUBLISH_IS_STALE            "why_publish_is_stale"
#define ISSX_FIELD_WHY_FRONTIER_IS_SMALL           "why_frontier_is_small"
#define ISSX_FIELD_WHY_INTELLIGENCE_ABSTAINED      "why_intelligence_abstained"
#define ISSX_FIELD_LARGEST_BACKLOG_OWNER           "largest_backlog_owner"
#define ISSX_FIELD_OLDEST_UNSERVED_QUEUE_FAMILY    "oldest_unserved_queue_family"

// ============================================================================
// SECTION 03: SHARED ENUMS
// ============================================================================

enum ISSX_StageId
  {
   issx_stage_unknown = 0,
   issx_stage_shared  = 1,
   issx_stage_ea1     = 2,
   issx_stage_ea2     = 3,
   issx_stage_ea3     = 4,
   issx_stage_ea4     = 5,
   issx_stage_ea5     = 6
  };

enum ISSX_AcceptanceType
  {
   issx_acceptance_accepted_for_pipeline = 0,
   issx_acceptance_accepted_for_ranking  = 1,
   issx_acceptance_accepted_for_intelligence = 2,
   issx_acceptance_accepted_for_gpt_export   = 3,
   issx_acceptance_accepted_degraded         = 4,
   issx_acceptance_rejected                  = 5
  };

enum ISSX_PublishabilityState
  {
   issx_publishability_not_ready = 0,
   issx_publishability_blocked   = 1,
   issx_publishability_warmup    = 2,
   issx_publishability_usable_degraded = 3,
   issx_publishability_usable    = 4,
   issx_publishability_strong    = 5
  };

enum ISSX_CompatibilityClass
  {
   issx_compat_incompatible = 0,
   issx_compat_schema_only  = 1,
   issx_compat_storage_compatible = 2,
   issx_compat_policy_degraded    = 3,
   issx_compat_consumer_compatible = 4,
   issx_compat_exact              = 5
  };

enum ISSX_ContentClass
  {
   issx_content_empty   = 0,
   issx_content_partial = 1,
   issx_content_usable  = 2,
   issx_content_strong  = 3
  };

enum ISSX_PublishReason
  {
   issx_publish_bootstrap = 0,
   issx_publish_scheduled = 1,
   issx_publish_recovery  = 2,
   issx_publish_material_change = 3,
   issx_publish_degradation_transition = 4,
   issx_publish_contradiction_transition = 5,
   issx_publish_heartbeat = 6,
   issx_publish_manual = 7
  };

enum ISSX_HandoffMode
  {
   issx_handoff_none = 0,
   issx_handoff_same_tick_accepted = 1,
   issx_handoff_internal_current   = 2,
   issx_handoff_internal_previous  = 3,
   issx_handoff_internal_last_good = 4,
   issx_handoff_public_projection  = 5
  };

enum ISSX_ContradictionSeverity
  {
   issx_contradiction_none = 0,
   issx_contradiction_low = 1,
   issx_contradiction_moderate = 2,
   issx_contradiction_high = 3,
   issx_contradiction_blocking = 4
  };

enum ISSX_ContradictionClass
  {
   issx_contradiction_identity = 0,
   issx_contradiction_session = 1,
   issx_contradiction_spec = 2,
   issx_contradiction_history_continuity = 3,
   issx_contradiction_selection_ownership = 4,
   issx_contradiction_intelligence_validity = 5
  };

enum ISSX_RepairState
  {
   issx_repair_none = 0,
   issx_repair_cooldown = 1,
   issx_repair_reprobe_scheduled = 2,
   issx_repair_active = 3,
   issx_repair_temporarily_suspended = 4
  };

enum ISSX_RankabilityLane
  {
   issx_rankability_strong = 0,
   issx_rankability_usable = 1,
   issx_rankability_exploratory = 2,
   issx_rankability_blocked = 3
  };

enum ISSX_PairValidityClass
  {
   issx_pair_validity_unknown_overlap = 0,
   issx_pair_validity_valid_low_overlap = 1,
   issx_pair_validity_valid_high_overlap = 2,
   issx_pair_validity_provisional_overlap = 3,
   issx_pair_validity_blocked_overlap = 4
  };

enum ISSX_PairSampleAlignmentClass
  {
   issx_pair_alignment_unknown = 0,
   issx_pair_alignment_poor = 1,
   issx_pair_alignment_usable = 2,
   issx_pair_alignment_strong = 3
  };

enum ISSX_PairWindowFreshnessClass
  {
   issx_pair_window_freshness_unknown = 0,
   issx_pair_window_freshness_stale = 1,
   issx_pair_window_freshness_usable = 2,
   issx_pair_window_freshness_fresh = 3
  };

enum ISSX_DirectOrDerived
  {
   issx_direct_field = 0,
   issx_derived_field = 1
  };

enum ISSX_AuthorityLevel
  {
   issx_authority_observed = 0,
   issx_authority_validated = 1,
   issx_authority_derived = 2,
   issx_authority_advisory = 3,
   issx_authority_degraded = 4
  };

enum ISSX_StalePolicy
  {
   issx_stale_valid_until_threshold = 0,
   issx_stale_degrade_after_threshold = 1,
   issx_stale_invalidate_after_threshold = 2,
   issx_stale_not_time_sensitive = 3
  };

enum ISSX_MinuteEpochSource
  {
   issx_minute_epoch_trade_server = 0,
   issx_minute_epoch_time_current = 1,
   issx_minute_epoch_time_local = 2
  };

enum ISSX_SchedulerClockSource
  {
   issx_scheduler_clock_trade_server = 0,
   issx_scheduler_clock_time_current = 1,
   issx_scheduler_clock_time_local = 2
  };

enum ISSX_FreshnessClockSource
  {
   issx_freshness_clock_quote = 0,
   issx_freshness_clock_trade_server = 1,
   issx_freshness_clock_time_local = 2
  };

enum ISSX_KernelOverrunClass
  {
   issx_overrun_none = 0,
   issx_overrun_soft = 1,
   issx_overrun_hard = 2
  };

enum ISSX_HydrationMenuClass
  {
   issx_hydration_bootstrap_work = 0,
   issx_hydration_delta_first_work = 1,
   issx_hydration_backlog_clearing_work = 2,
   issx_hydration_continuity_preserving_work = 3,
   issx_hydration_publish_critical_work = 4,
   issx_hydration_optional_enrichment_work = 5
  };

enum ISSX_QueueFamily
  {
   issx_queue_discovery = 0,
   issx_queue_probe = 1,
   issx_queue_quote_sampling = 2,
   issx_queue_history_warm = 3,
   issx_queue_history_deep = 4,
   issx_queue_bucket_rebuild = 5,
   issx_queue_pair = 6,
   issx_queue_repair = 7,
   issx_queue_persistence = 8,
   issx_queue_publish = 9,
   issx_queue_debug = 10,
   issx_queue_fastlane = 11
  };

enum ISSX_InvalidationClass
  {
   issx_invalidation_quote_freshness = 0,
   issx_invalidation_tradeability = 1,
   issx_invalidation_session_boundary = 2,
   issx_invalidation_history_sync = 3,
   issx_invalidation_frontier_member_change = 4,
   issx_invalidation_family_representative_change = 5,
   issx_invalidation_policy_change = 6,
   issx_invalidation_clock_anomaly = 7,
   issx_invalidation_activity_regime = 8
  };

enum ISSX_DebugWeakLinkCode
  {
   issx_weak_link_none = 0,
   issx_weak_link_dependency_block = 1,
   issx_weak_link_fallback_habit = 2,
   issx_weak_link_starvation = 3,
   issx_weak_link_publish_stale = 4,
   issx_weak_link_rewrite_storm = 5,
   issx_weak_link_queue_backlog = 6,
   issx_weak_link_acceptance_failure = 7
  };

enum ISSX_TraceSeverity
  {
   issx_trace_error = 0,
   issx_trace_warn = 1,
   issx_trace_state_change = 2,
   issx_trace_sampled_info = 3
  };

enum ISSX_HistoryReadinessState
  {
   issx_history_never_requested = 0,
   issx_history_requested_sync = 1,
   issx_history_partial_available = 2,
   issx_history_syncing = 3,
   issx_history_compare_unsafe = 4,
   issx_history_compare_safe_degraded = 5,
   issx_history_compare_safe_strong = 6,
   issx_history_degraded_unstable = 7,
   issx_history_blocked = 8
  };

enum ISSX_HistoryFinalityClass
  {
   issx_history_finality_stable = 0,
   issx_history_finality_watch = 1,
   issx_history_finality_unstable = 2,
   issx_history_finality_recovering = 3
  };

enum ISSX_HistoryRewriteClass
  {
   issx_rewrite_none = 0,
   issx_rewrite_benign_last_bar_adjustment = 1,
   issx_rewrite_short_tail = 2,
   issx_rewrite_structural_gap = 3,
   issx_rewrite_historical_block = 4
  };

enum ISSX_DiscoveryLifecycleState
  {
   issx_symbol_discovered = 0,
   issx_symbol_selected = 1,
   issx_symbol_metadata_readable = 2,
   issx_symbol_quote_observable = 3,
   issx_symbol_synchronized = 4,
   issx_symbol_history_addressable = 5,
   issx_symbol_trade_permitted = 6,
   issx_symbol_custom_symbol_flag = 7,
   issx_symbol_property_unavailable = 8,
   issx_symbol_select_failed_temp = 9,
   issx_symbol_select_failed_perm = 10
  };

enum ISSX_SessionTruthClass
  {
   issx_session_truth_declared_only = 0,
   issx_session_truth_observed_supported = 1,
   issx_session_truth_contradictory = 2
  };

enum ISSX_ContextRegimeClass
  {
   issx_regime_unknown = 0,
   issx_regime_dormant = 1,
   issx_regime_waking = 2,
   issx_regime_active = 3,
   issx_regime_elevated = 4,
   issx_regime_dislocated = 5,
   issx_regime_compressed = 6,
   issx_regime_normal = 7,
   issx_regime_expanding = 8,
   issx_regime_extended = 9,
   issx_regime_orderly = 10,
   issx_regime_noisy = 11,
   issx_regime_fragmented = 12,
   issx_regime_rotational = 13,
   issx_regime_poor = 14,
   issx_regime_acceptable = 15,
   issx_regime_strong = 16,
   issx_regime_short_intraday = 17,
   issx_regime_mixed_intraday = 18,
   issx_regime_extended_intraday = 19
  };

enum ISSX_WarehouseQuality
  {
   issx_warehouse_quality_unknown = 0,
   issx_warehouse_quality_thin = 1,
   issx_warehouse_quality_degraded = 2,
   issx_warehouse_quality_usable = 3,
   issx_warehouse_quality_strong = 4
  };

enum ISSX_DiversificationConfidenceClass
  {
   issx_diversification_confidence_unknown = 0,
   issx_diversification_confidence_low = 1,
   issx_diversification_confidence_moderate = 2,
   issx_diversification_confidence_high = 3
  };

enum ISSX_RedundancyRiskClass
  {
   issx_redundancy_risk_unknown = 0,
   issx_redundancy_risk_low = 1,
   issx_redundancy_risk_moderate = 2,
   issx_redundancy_risk_high = 3
  };

// ============================================================================
// SECTION 04: DTO TYPES
// ============================================================================

struct ISSX_FieldSemantics
  {
   string                 field_name;
   ISSX_DirectOrDerived   direct_or_derived;
   ISSX_AuthorityLevel    authority_level;
   ISSX_StalePolicy       stale_policy;
   string                 cache_provenance;

   void Reset()
     {
      field_name="";
      direct_or_derived=issx_direct_field;
      authority_level=issx_authority_observed;
      stale_policy=issx_stale_valid_until_threshold;
      cache_provenance="";
     }
  };

struct ISSX_ValidationResult
  {
   bool   ok;
   int    code;
   string message;
  };

struct ISSX_BinaryHeader
  {
   int          magic;
   ISSX_StageId stage_id;
   string       schema_version;
   int          schema_epoch;
   int          storage_version;
   long         writer_generation;
   long         sequence_no;
   int          record_size;
   int          payload_length;
   string       payload_hash_or_crc;
   string       header_hash_or_crc;

   void Reset()
     {
      magic=ISSX_BINARY_MAGIC;
      stage_id=issx_stage_shared;
      schema_version=ISSX_SCHEMA_VERSION;
      schema_epoch=ISSX_SCHEMA_EPOCH;
      storage_version=ISSX_STORAGE_VERSION;
      writer_generation=0;
      sequence_no=0;
      record_size=0;
      payload_length=0;
      payload_hash_or_crc="";
      header_hash_or_crc="";
     }
  };

struct ISSX_StageHeader
  {
   int          magic;
   ISSX_StageId stage_id;
   string       firm_id;
   string       schema_version;
   int          schema_epoch;
   int          storage_version;
   long         writer_generation;
   long         sequence_no;
   string       trio_generation_id;
   int          record_size_or_payload_length;
   int          payload_length;
   int          header_length;
   string       payload_hash;
   string       header_hash;
   int          symbol_count;
   int          changed_symbol_count;
   long         minute_id;
   string       writer_boot_id;
   string       writer_nonce;
   string       cohort_fingerprint;
   string       universe_fingerprint;
   string       policy_fingerprint;
   int          fingerprint_algorithm_version;
   int          contradiction_count;
   ISSX_ContradictionSeverity contradiction_severity_max;
   bool         degraded_flag;
   int          fallback_depth_used;

   void Reset()
     {
      magic=ISSX_BINARY_MAGIC;
      stage_id=issx_stage_shared;
      firm_id="";
      schema_version=ISSX_SCHEMA_VERSION;
      schema_epoch=ISSX_SCHEMA_EPOCH;
      storage_version=ISSX_STORAGE_VERSION;
      writer_generation=0;
      sequence_no=0;
      trio_generation_id="";
      record_size_or_payload_length=0;
      payload_length=0;
      header_length=0;
      payload_hash="";
      header_hash="";
      symbol_count=0;
      changed_symbol_count=0;
      minute_id=0;
      writer_boot_id="";
      writer_nonce="";
      cohort_fingerprint="";
      universe_fingerprint="";
      policy_fingerprint="";
      fingerprint_algorithm_version=ISSX_FINGERPRINT_ALGO_VERSION;
      contradiction_count=0;
      contradiction_severity_max=issx_contradiction_none;
      degraded_flag=false;
      fallback_depth_used=0;
     }
  };

struct ISSX_Manifest
  {
   ISSX_StageId            stage_id;
   string                  firm_id;
   string                  schema_version;
   int                     schema_epoch;
   int                     storage_version;
   long                    sequence_no;
   long                    minute_id;
   string                  writer_boot_id;
   string                  writer_nonce;
   long                    writer_generation;
   string                  trio_generation_id;
   string                  payload_hash;
   string                  header_hash;
   int                     payload_length;
   int                     header_length;
   int                     symbol_count;
   int                     changed_symbol_count;
   ISSX_ContentClass       content_class;
   ISSX_PublishReason      publish_reason;
   string                  cohort_fingerprint;
   string                  taxonomy_hash;
   string                  comparator_registry_hash;
   string                  policy_fingerprint;
   int                     fingerprint_algorithm_version;
   string                  universe_fingerprint;
   ISSX_CompatibilityClass compatibility_class;
   int                     contradiction_count;
   ISSX_ContradictionSeverity contradiction_severity_max;
   bool                    degraded_flag;
   int                     fallback_depth_used;
   int                     accepted_strong_count;
   int                     accepted_degraded_count;
   int                     rejected_count;
   int                     cooldown_count;
   int                     stale_usable_count;
   bool                    projection_partial_success_flag;
   bool                    accepted_promotion_verified;
   bool                    stage_minimum_ready_flag;
   ISSX_PublishabilityState stage_publishability_state;
   ISSX_HandoffMode        handoff_mode;
   long                    handoff_sequence_no;
   double                  fallback_read_ratio_1h;
   double                  fresh_accept_ratio_1h;
   double                  same_tick_handoff_ratio_1h;
   string                  legend_hash;

   void Reset()
     {
      stage_id=issx_stage_shared;
      firm_id="";
      schema_version=ISSX_SCHEMA_VERSION;
      schema_epoch=ISSX_SCHEMA_EPOCH;
      storage_version=ISSX_STORAGE_VERSION;
      sequence_no=0;
      minute_id=0;
      writer_boot_id="";
      writer_nonce="";
      writer_generation=0;
      trio_generation_id="";
      payload_hash="";
      header_hash="";
      payload_length=0;
      header_length=0;
      symbol_count=0;
      changed_symbol_count=0;
      content_class=issx_content_empty;
      publish_reason=issx_publish_bootstrap;
      cohort_fingerprint="";
      taxonomy_hash="";
      comparator_registry_hash="";
      policy_fingerprint="";
      fingerprint_algorithm_version=ISSX_FINGERPRINT_ALGO_VERSION;
      universe_fingerprint="";
      compatibility_class=issx_compat_incompatible;
      contradiction_count=0;
      contradiction_severity_max=issx_contradiction_none;
      degraded_flag=false;
      fallback_depth_used=0;
      accepted_strong_count=0;
      accepted_degraded_count=0;
      rejected_count=0;
      cooldown_count=0;
      stale_usable_count=0;
      projection_partial_success_flag=false;
      accepted_promotion_verified=false;
      stage_minimum_ready_flag=false;
      stage_publishability_state=issx_publishability_not_ready;
      handoff_mode=issx_handoff_none;
      handoff_sequence_no=0;
      fallback_read_ratio_1h=0.0;
      fresh_accept_ratio_1h=0.0;
      same_tick_handoff_ratio_1h=0.0;
      legend_hash="";
     }
  };

struct ISSX_AcceptanceResult
  {
   bool                     accepted;
   ISSX_AcceptanceType      acceptance_type;
   int                      error_code;
   string                   reason;
   ISSX_CompatibilityClass  compatibility_class;
   int                      compatibility_score;
   int                      accepted_strong_count;
   int                      accepted_degraded_count;
   int                      rejected_count;
   int                      cooldown_count;
   int                      stale_usable_count;
   int                      contradiction_count;
   ISSX_ContradictionSeverity contradiction_severity_max;
   bool                     blocking_contradiction_present;
   string                   contradiction_class_counts;
   string                   highest_blocking_contradiction_class;
   string                   contradiction_repair_state;
   string                   policy_fingerprint;
   bool                     stage_minimum_ready_flag;
   ISSX_PublishabilityState stage_publishability_state;

   void Reset()
     {
      accepted=false;
      acceptance_type=issx_acceptance_rejected;
      error_code=ISSX_ACCEPTANCE_ERR_INCOMPLETE;
      reason="";
      compatibility_class=issx_compat_incompatible;
      compatibility_score=0;
      accepted_strong_count=0;
      accepted_degraded_count=0;
      rejected_count=0;
      cooldown_count=0;
      stale_usable_count=0;
      contradiction_count=0;
      contradiction_severity_max=issx_contradiction_none;
      blocking_contradiction_present=false;
      contradiction_class_counts="";
      highest_blocking_contradiction_class="";
      contradiction_repair_state="";
      policy_fingerprint="";
      stage_minimum_ready_flag=false;
      stage_publishability_state=issx_publishability_not_ready;
     }
  };

struct ISSX_ClockStats
  {
   ISSX_MinuteEpochSource    minute_epoch_source;
   ISSX_SchedulerClockSource scheduler_clock_source;
   ISSX_FreshnessClockSource freshness_clock_source;
   long                      timer_gap_ms_now;
   double                    timer_gap_ms_mean;
   long                      timer_gap_ms_p95;
   long                      scheduler_late_by_ms;
   int                       missed_schedule_windows_estimate;
   bool                      quote_clock_idle_flag;
   double                    clock_sanity_score;
   double                    clock_divergence_sec;
   bool                      clock_anomaly_flag;
   double                    time_penalty_applied;

   void Reset()
     {
      minute_epoch_source=issx_minute_epoch_trade_server;
      scheduler_clock_source=issx_scheduler_clock_trade_server;
      freshness_clock_source=issx_freshness_clock_quote;
      timer_gap_ms_now=0;
      timer_gap_ms_mean=0.0;
      timer_gap_ms_p95=0;
      scheduler_late_by_ms=0;
      missed_schedule_windows_estimate=0;
      quote_clock_idle_flag=false;
      clock_sanity_score=1.0;
      clock_divergence_sec=0.0;
      clock_anomaly_flag=false;
      time_penalty_applied=0.0;
     }
  };

struct ISSX_BudgetState
  {
   long discovery_budget_ms;
   long probe_budget_ms;
   long quote_sampling_budget_ms;
   long history_warm_budget_ms;
   long history_deep_budget_ms;
   long pair_budget_ms;
   long cache_budget_ms;
   long persistence_budget_ms;
   long publish_budget_ms;
   long debug_budget_ms;
   long freshness_fastlane_budget_ms;

   void Reset()
     {
      discovery_budget_ms=0;
      probe_budget_ms=0;
      quote_sampling_budget_ms=0;
      history_warm_budget_ms=0;
      history_deep_budget_ms=0;
      pair_budget_ms=0;
      cache_budget_ms=0;
      persistence_budget_ms=0;
      publish_budget_ms=0;
      debug_budget_ms=0;
      freshness_fastlane_budget_ms=0;
     }
  };

struct ISSX_RotationState
  {
   int discovery_cursor;
   int spec_probe_cursor;
   int runtime_sample_cursor;
   int history_warm_cursor;
   int history_deep_cursor;
   int bucket_rebuild_cursor;
   int pair_queue_cursor;
   int repair_cursor;

   void Reset()
     {
      discovery_cursor=0;
      spec_probe_cursor=0;
      runtime_sample_cursor=0;
      history_warm_cursor=0;
      history_deep_cursor=0;
      bucket_rebuild_cursor=0;
      pair_queue_cursor=0;
      repair_cursor=0;
     }
  };

struct ISSX_KernelSchedulerState
  {
   long                    kernel_minute_id;
   long                    scheduler_cycle_no;
   ISSX_StageId            current_stage_slot;
   string                  current_stage_phase;
   long                    current_stage_budget_ms;
   long                    current_stage_deadline_ms;
   long                    stage_last_run_ms[5];
   long                    stage_last_publish_minute_id[5];
   bool                    stage_publish_due_flag[5];
   bool                    stage_minimum_ready_flag[5];
   double                  stage_backlog_score[5];
   double                  stage_starvation_score[5];
   string                  stage_dependency_block_reason[5];
   string                  stage_resume_key[5];
   long                    stage_last_successful_service_mono_ms[5];
   long                    stage_last_attempted_service_mono_ms[5];
   int                     stage_missed_due_cycles[5];
   long                    kernel_budget_total_ms;
   long                    kernel_budget_spent_ms;
   long                    kernel_budget_reserved_commit_ms;
   long                    kernel_budget_debt_ms;
   bool                    kernel_forced_service_due_flag;
   bool                    kernel_degraded_cycle_flag;
   ISSX_KernelOverrunClass kernel_overrun_class;

   void Reset()
     {
      kernel_minute_id=0;
      scheduler_cycle_no=0;
      current_stage_slot=issx_stage_unknown;
      current_stage_phase="";
      current_stage_budget_ms=0;
      current_stage_deadline_ms=0;
      for(int i=0;i<5;i++)
        {
         stage_last_run_ms[i]=0;
         stage_last_publish_minute_id[i]=0;
         stage_publish_due_flag[i]=false;
         stage_minimum_ready_flag[i]=false;
         stage_backlog_score[i]=0.0;
         stage_starvation_score[i]=0.0;
         stage_dependency_block_reason[i]="";
         stage_resume_key[i]="";
         stage_last_successful_service_mono_ms[i]=0;
         stage_last_attempted_service_mono_ms[i]=0;
         stage_missed_due_cycles[i]=0;
        }
      kernel_budget_total_ms=0;
      kernel_budget_spent_ms=0;
      kernel_budget_reserved_commit_ms=0;
      kernel_budget_debt_ms=0;
      kernel_forced_service_due_flag=false;
      kernel_degraded_cycle_flag=false;
      kernel_overrun_class=issx_overrun_none;
     }
  };

struct ISSX_RootProjectionMeta
  {
   bool internal_commit_success;
   bool root_stage_projection_success;
   bool root_debug_projection_success;
   bool projection_partial_success_flag;
   int  debug_projection_fail_count;
   string root_sync_state;

   void Reset()
     {
      internal_commit_success=false;
      root_stage_projection_success=false;
      root_debug_projection_success=false;
      projection_partial_success_flag=false;
      debug_projection_fail_count=0;
      root_sync_state="";
     }
  };

struct ISSX_PublishResult
  {
   bool               ok;
   ISSX_PublishReason publish_reason;
   ISSX_ContentClass  content_class;
   string             payload_hash;
   string             header_hash;
   long               sequence_no;
   long               minute_id;
   ISSX_RootProjectionMeta projection;
   string             message;

   void Reset()
     {
      ok=false;
      publish_reason=issx_publish_bootstrap;
      content_class=issx_content_empty;
      payload_hash="";
      header_hash="";
      sequence_no=0;
      minute_id=0;
      projection.Reset();
      message="";
     }
  };

struct ISSX_ReadResult
  {
   bool                    ok;
   string                  upstream_source_used;
   string                  upstream_source_reason;
   ISSX_CompatibilityClass upstream_compatibility_class;
   int                     upstream_compatibility_score;
   int                     fallback_depth_used;
   double                  fallback_penalty_applied;
   ISSX_HandoffMode        upstream_handoff_mode;
   bool                    upstream_handoff_same_tick_flag;
   bool                    upstream_partial_progress_flag;
   long                    upstream_handoff_sequence_no;
   string                  upstream_payload_hash;
   string                  upstream_policy_fingerprint;
   string                  message;

   void Reset()
     {
      ok=false;
      upstream_source_used="";
      upstream_source_reason="";
      upstream_compatibility_class=issx_compat_incompatible;
      upstream_compatibility_score=0;
      fallback_depth_used=0;
      fallback_penalty_applied=0.0;
      upstream_handoff_mode=issx_handoff_none;
      upstream_handoff_same_tick_flag=false;
      upstream_partial_progress_flag=false;
      upstream_handoff_sequence_no=0;
      upstream_payload_hash="";
      upstream_policy_fingerprint="";
      message="";
     }
  };

struct ISSX_StageHealthSurface
  {
   ISSX_DebugWeakLinkCode weak_link_code;
   double error_weight;
   double degrade_weight;
   double dependency_weight;
   double fallback_weight;
   string dependency_block_reason;
   int fallback_depth;
   long accepted_sequence_no;
   long last_attempted_age_ms;
   long last_successful_service_age_ms;
   long stage_last_publish_age_sec;
   double stage_backlog_score;
   double stage_starvation_score;
   string phase_id;
   int phase_resume_count;
   ISSX_PublishabilityState publishability_state;

   void Reset()
     {
      weak_link_code=issx_weak_link_none;
      error_weight=0.0;
      degrade_weight=0.0;
      dependency_weight=0.0;
      fallback_weight=0.0;
      dependency_block_reason="";
      fallback_depth=0;
      accepted_sequence_no=0;
      last_attempted_age_ms=0;
      last_successful_service_age_ms=0;
      stage_last_publish_age_sec=0;
      stage_backlog_score=0.0;
      stage_starvation_score=0.0;
      phase_id="";
      phase_resume_count=0;
      publishability_state=issx_publishability_not_ready;
     }
  };

// ============================================================================
// SECTION 05: VALIDATION HELPERS
// ============================================================================

class ISSX_Validate
  {
public:
   static ISSX_ValidationResult Ok()
     {
      ISSX_ValidationResult r;
      r.ok=true;
      r.code=ISSX_ACCEPTANCE_OK;
      r.message="ok";
      return r;
     }

   static ISSX_ValidationResult Fail(const int code,const string message)
     {
      ISSX_ValidationResult r;
      r.ok=false;
      r.code=code;
      r.message=message;
      return r;
     }

   static ISSX_ValidationResult ValidateStageHeader(const ISSX_StageHeader &h)
     {
      if(h.magic!=ISSX_BINARY_MAGIC && h.magic!=ISSX_BINARY_MAGIC_ALT)
         return Fail(ISSX_ACCEPTANCE_ERR_STORAGE,"invalid binary magic");
      if(h.stage_id==issx_stage_unknown)
         return Fail(ISSX_ACCEPTANCE_ERR_STAGE_MISMATCH,"stage id missing");
      if(h.schema_epoch<=0 || h.storage_version<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_SCHEMA,"schema/storage missing");
      if(h.sequence_no<0 || h.writer_generation<0)
         return Fail(ISSX_ACCEPTANCE_ERR_SEQUENCE,"negative generation or sequence");
      if(h.payload_length<0 || h.header_length<0)
         return Fail(ISSX_ACCEPTANCE_ERR_FILESET,"negative lengths");
      return Ok();
     }

   static ISSX_ValidationResult ValidateManifestCoherence(const ISSX_StageHeader &h,const ISSX_Manifest &m)
     {
      if(h.stage_id!=m.stage_id)
         return Fail(ISSX_ACCEPTANCE_ERR_COHERENCE,"header/manifest stage mismatch");
      if(h.sequence_no!=m.sequence_no)
         return Fail(ISSX_ACCEPTANCE_ERR_COHERENCE,"header/manifest sequence mismatch");
      if(h.writer_generation!=m.writer_generation)
         return Fail(ISSX_ACCEPTANCE_ERR_GENERATION,"writer generation mismatch");
      if(h.trio_generation_id!=m.trio_generation_id)
         return Fail(ISSX_ACCEPTANCE_ERR_GENERATION,"trio generation mismatch");
      if(h.payload_length!=m.payload_length || h.header_length!=m.header_length)
         return Fail(ISSX_ACCEPTANCE_ERR_FILESET,"length mismatch");
      if(h.payload_hash!=m.payload_hash || h.header_hash!=m.header_hash)
         return Fail(ISSX_ACCEPTANCE_ERR_HASH,"hash mismatch");
      return Ok();
     }
  };

// ============================================================================
// SECTION 06: UTILITY HELPERS
// ============================================================================

class ISSX_Util
  {
public:
   static bool IsEmpty(const string s)
     {
      return (StringLen(s)==0);
     }

   static string BoolToString(const bool v)
     {
      return (v ? "true" : "false");
     }

   static string LongToStringX(const long v)
     {
      return StringFormat("%I64d",v);
     }

   static string IntToStringX(const int v)
     {
      return IntegerToString(v);
     }

   static string DoubleToStringX(const double v,const int digits=6)
     {
      return DoubleToString(v,digits);
     }

   static string SafeString(const string s)
     {
      return s;
     }

   static string TrimRightSep(const string s)
     {
      if(IsEmpty(s))
         return s;
      if(StringSubstr(s,StringLen(s)-1,1)==ISSX_PATH_SEP)
         return StringSubstr(s,0,StringLen(s)-1);
      return s;
     }

   static string JoinPath(const string a,const string b)
     {
      if(IsEmpty(a))
         return b;
      if(IsEmpty(b))
         return a;
      string aa=TrimRightSep(a);
      if(StringSubstr(b,0,1)==ISSX_PATH_SEP)
         return aa+b;
      return aa+ISSX_PATH_SEP+b;
     }

   static string JoinPath3(const string a,const string b,const string c)
     {
      return JoinPath(JoinPath(a,b),c);
     }

   static string EscapeJson(const string s)
     {
      string out=s;
      StringReplace(out,"\\","\\\\");
      StringReplace(out,"\"","\\\"");
      StringReplace(out,"\r","\\r");
      StringReplace(out,"\n","\\n");
      StringReplace(out,"\t","\\t");
      return out;
     }

   static string NormalizeNullLike(const string s)
     {
      string t=s;
      StringToLower(t);
      if(t=="null" || t=="none" || t=="n/a")
         return "";
      return s;
     }

   static string BoolFlag(const bool v,const string true_label,const string false_label)
     {
      return (v ? true_label : false_label);
     }
  };

// ============================================================================
// SECTION 07: TIME HELPERS
// ============================================================================

class ISSX_Time
  {
public:
   static datetime BestScheduleClock()
     {
      datetime t=TimeTradeServer();
      if(t<=0)
         t=TimeCurrent();
      if(t<=0)
         t=TimeLocal();
      return t;
     }

   static datetime BestFreshnessClock()
     {
      datetime t=TimeCurrent();
      if(t<=0)
         t=TimeTradeServer();
      if(t<=0)
         t=TimeLocal();
      return t;
     }

   static long MinuteIdFromDatetime(const datetime ts)
     {
      if(ts<=0)
         return 0;
      return (long)(ts/60);
     }

   static long NowMinuteId()
     {
      return MinuteIdFromDatetime(BestScheduleClock());
     }
  };

// ============================================================================
// SECTION 08: HASH HELPERS
// ============================================================================

class ISSX_Hash
  {
private:
   static ulong FNV1a64(const string s)
     {
      uchar bytes[];
      int n=StringToCharArray(s,bytes,0,WHOLE_ARRAY,CP_UTF8);
      ulong h=1469598103934665603;
      for(int i=0;i<n;i++)
        {
         h^=(ulong)bytes[i];
         h*=1099511628211;
        }
      return h;
     }

public:
   static string ULongToHex(const ulong v_in)
     {
      ulong v=v_in;
      string out="";
      for(int i=0;i<16;i++)
        {
         int nib=(int)(v & 0xF);
         string hex=(nib<10 ? IntegerToString(nib) : CharToString((ushort)('a'+(nib-10))));
         out=hex+out;
         v>>=4;
        }
      return out;
     }

   static string HashStringHex(const string s)
     {
      return ULongToHex(FNV1a64(s));
     }

   static string HashJoin3(const string a,const string b,const string c)
     {
      return HashStringHex(a+"|"+b+"|"+c);
     }
  };

// ============================================================================
// SECTION 09: JSON WRITER
// ============================================================================

class ISSX_JsonWriter
  {
private:
   string m_text;
   bool   m_need_comma[ISSX_MAX_JSON_DEPTH];
   int    m_depth;

   void PushContext()
     {
      if(m_depth<ISSX_MAX_JSON_DEPTH)
        {
         m_need_comma[m_depth]=false;
         m_depth++;
        }
     }

   void PopContext()
     {
      if(m_depth>0)
         m_depth--;
     }

   void WriteCommaIfNeeded()
     {
      if(m_depth>0 && m_need_comma[m_depth-1])
         m_text+=",";
      if(m_depth>0)
         m_need_comma[m_depth-1]=true;
     }

   void WriteNamePrefix(const string name)
     {
      WriteCommaIfNeeded();
      m_text+="\""+ISSX_Util::EscapeJson(name)+"\":";
     }

public:
   void Reset()
     {
      m_text="";
      ArrayInitialize(m_need_comma,false);
      m_depth=0;
     }

   void BeginObject()
     {
      WriteCommaIfNeeded();
      m_text+="{";
      PushContext();
     }

   void EndObject()
     {
      PopContext();
      m_text+="}";
     }

   void BeginArray()
     {
      WriteCommaIfNeeded();
      m_text+="[";
      PushContext();
     }

   void EndArray()
     {
      PopContext();
      m_text+="]";
     }

   void NameString(const string name,const string value)
     {
      WriteNamePrefix(name);
      m_text+="\""+ISSX_Util::EscapeJson(value)+"\"";
     }

   void NameInt(const string name,const long value)
     {
      WriteNamePrefix(name);
      m_text+=ISSX_Util::LongToStringX(value);
     }

   void NameDouble(const string name,const double value,const int digits=6)
     {
      WriteNamePrefix(name);
      m_text+=DoubleToString(value,digits);
     }

   void NameBool(const string name,const bool value)
     {
      WriteNamePrefix(name);
      m_text+=ISSX_Util::BoolToString(value);
     }

   void NameNull(const string name)
     {
      WriteNamePrefix(name);
      m_text+="null";
     }

   void ValueString(const string value)
     {
      WriteCommaIfNeeded();
      m_text+="\""+ISSX_Util::EscapeJson(value)+"\"";
     }

   void ValueInt(const long value)
     {
      WriteCommaIfNeeded();
      m_text+=ISSX_Util::LongToStringX(value);
     }

   string ToString() const
     {
      return m_text;
     }
  };

// ============================================================================
// SECTION 10: STAGE / PATH HELPERS
// ============================================================================

class ISSX_Stage
  {
public:
   static int ToStageIndex(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return 0;
         case issx_stage_ea2: return 1;
         case issx_stage_ea3: return 2;
         case issx_stage_ea4: return 3;
         case issx_stage_ea5: return 4;
         default: return -1;
        }
     }

   static string ToMachineId(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return "ea1";
         case issx_stage_ea2: return "ea2";
         case issx_stage_ea3: return "ea3";
         case issx_stage_ea4: return "ea4";
         case issx_stage_ea5: return "ea5";
         case issx_stage_shared: return "shared";
         default: return "unknown";
        }
     }

   static string ToCoreName(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return "MarketStateCore";
         case issx_stage_ea2: return "HistoryStateCore";
         case issx_stage_ea3: return "SelectionCore";
         case issx_stage_ea4: return "IntelligenceCore";
         case issx_stage_ea5: return "ConsolidationCore";
         default: return "UnknownCore";
        }
     }

   static string PersistenceFolder(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return ISSX_DIR_PERSISTENCE_EA1;
         case issx_stage_ea2: return ISSX_DIR_PERSISTENCE_EA2;
         case issx_stage_ea3: return ISSX_DIR_PERSISTENCE_EA3;
         case issx_stage_ea4: return ISSX_DIR_PERSISTENCE_EA4;
         case issx_stage_ea5: return ISSX_DIR_PERSISTENCE_EA5;
         case issx_stage_shared: return ISSX_DIR_PERSISTENCE_SHARED;
         default: return "";
        }
     }

   static string DebugSnapshotFilename(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return ISSX_DEBUG_SNAPSHOT_EA1;
         case issx_stage_ea2: return ISSX_DEBUG_SNAPSHOT_EA2;
         case issx_stage_ea3: return ISSX_DEBUG_SNAPSHOT_EA3;
         case issx_stage_ea4: return ISSX_DEBUG_SNAPSHOT_EA4;
         case issx_stage_ea5: return ISSX_DEBUG_SNAPSHOT_EA5;
         default: return ISSX_ROOT_DEBUG;
        }
     }
  };

class ISSX_Path
  {
public:
   static string RootFirmBase(const string firm_id)
     {
      return ISSX_Util::JoinPath3(ISSX_DIR_FIRMS,firm_id,ISSX_DIR_ROOT_NAME);
     }

   static string PublicRootFile(const string firm_id,const string filename)
     {
      return ISSX_Util::JoinPath(RootFirmBase(firm_id),filename);
     }

   static string InternalStageFile(const string firm_id,const ISSX_StageId stage_id,const string filename)
     {
      return ISSX_Util::JoinPath(ISSX_Util::JoinPath(RootFirmBase(firm_id),ISSX_Stage::PersistenceFolder(stage_id)),filename);
     }

   static string BrokerUniverseFile(const string firm_id,const string filename)
     {
      return ISSX_Util::JoinPath(ISSX_Util::JoinPath(RootFirmBase(firm_id),ISSX_DIR_PERSISTENCE_EA1_UNIVERSE),filename);
     }

   static string HistoryIndexFile(const string firm_id,const string filename)
     {
      return ISSX_Util::JoinPath(ISSX_Util::JoinPath(RootFirmBase(firm_id),ISSX_DIR_PERSISTENCE_EA2_HISTORY_INDEX),filename);
     }

   static string HistoryShardFile(const string firm_id,const string tf_dir,const string filename)
     {
      return ISSX_Util::JoinPath(ISSX_Util::JoinPath3(RootFirmBase(firm_id),ISSX_DIR_PERSISTENCE_EA2_HISTORY_STORE,tf_dir),filename);
     }

   static string DebugFile(const string firm_id,const string filename)
     {
      return ISSX_Util::JoinPath(ISSX_Util::JoinPath(RootFirmBase(firm_id),ISSX_DIR_DEBUG),filename);
     }

   static string LockFile(const string firm_id)
     {
      return ISSX_Util::JoinPath(ISSX_Util::JoinPath(RootFirmBase(firm_id),ISSX_DIR_LOCKS),ISSX_LOCK_FILENAME);
     }
  };

// ============================================================================
// SECTION 11: ENUM / LABEL HELPERS
// ============================================================================

string ISSX_StageIdToString(const ISSX_StageId v)
  {
   switch(v)
     {
      case issx_stage_shared: return "shared";
      case issx_stage_ea1: return "ea1";
      case issx_stage_ea2: return "ea2";
      case issx_stage_ea3: return "ea3";
      case issx_stage_ea4: return "ea4";
      case issx_stage_ea5: return "ea5";
      default: return "unknown";
     }
  }

string ISSX_PublishabilityStateToString(const ISSX_PublishabilityState v)
  {
   switch(v)
     {
      case issx_publishability_not_ready: return "not_ready";
      case issx_publishability_blocked: return "blocked";
      case issx_publishability_warmup: return "warmup";
      case issx_publishability_usable_degraded: return "usable_degraded";
      case issx_publishability_usable: return "usable";
      case issx_publishability_strong: return "strong";
      default: return "unknown";
     }
  }

string ISSX_CompatibilityClassToString(const ISSX_CompatibilityClass v)
  {
   switch(v)
     {
      case issx_compat_incompatible: return "incompatible";
      case issx_compat_schema_only: return "schema_only";
      case issx_compat_storage_compatible: return "storage_compatible";
      case issx_compat_policy_degraded: return "policy_degraded";
      case issx_compat_consumer_compatible: return "consumer_compatible";
      case issx_compat_exact: return "exact";
      default: return "unknown";
     }
  }

string ISSX_HandoffModeToString(const ISSX_HandoffMode v)
  {
   switch(v)
     {
      case issx_handoff_none: return "none";
      case issx_handoff_same_tick_accepted: return "same_tick_accepted";
      case issx_handoff_internal_current: return "internal_current";
      case issx_handoff_internal_previous: return "internal_previous";
      case issx_handoff_internal_last_good: return "internal_last_good";
      case issx_handoff_public_projection: return "public_projection";
      default: return "unknown";
     }
  }

string ISSX_RankabilityLaneToString(const ISSX_RankabilityLane v)
  {
   switch(v)
     {
      case issx_rankability_strong: return "strong";
      case issx_rankability_usable: return "usable";
      case issx_rankability_exploratory: return "exploratory";
      case issx_rankability_blocked: return "blocked";
      default: return "unknown";
     }
  }

string ISSX_PairValidityClassToString(const ISSX_PairValidityClass v)
  {
   switch(v)
     {
      case issx_pair_validity_unknown_overlap: return "unknown_overlap";
      case issx_pair_validity_valid_low_overlap: return "valid_low_overlap";
      case issx_pair_validity_valid_high_overlap: return "valid_high_overlap";
      case issx_pair_validity_provisional_overlap: return "provisional_overlap";
      case issx_pair_validity_blocked_overlap: return "blocked_overlap";
      default: return "unknown";
     }
  }

string ISSX_DebugWeakLinkCodeToString(const ISSX_DebugWeakLinkCode v)
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
      default: return "unknown";
     }
  }

string ISSX_InvalidationClassToString(const ISSX_InvalidationClass v)
  {
   switch(v)
     {
      case issx_invalidation_quote_freshness: return "quote_freshness_invalidation";
      case issx_invalidation_tradeability: return "tradeability_invalidation";
      case issx_invalidation_session_boundary: return "session_boundary_invalidation";
      case issx_invalidation_history_sync: return "history_sync_invalidation";
      case issx_invalidation_frontier_member_change: return "frontier_member_change";
      case issx_invalidation_family_representative_change: return "family_representative_change";
      case issx_invalidation_policy_change: return "policy_change_invalidation";
      case issx_invalidation_clock_anomaly: return "clock_anomaly_invalidation";
      case issx_invalidation_activity_regime: return "activity_regime_invalidation";
      default: return "unknown";
     }
  }

string ISSX_HistoryReadinessStateToString(const ISSX_HistoryReadinessState v)
  {
   switch(v)
     {
      case issx_history_never_requested: return "never_requested";
      case issx_history_requested_sync: return "requested_sync";
      case issx_history_partial_available: return "partial_available";
      case issx_history_syncing: return "syncing";
      case issx_history_compare_unsafe: return "compare_unsafe";
      case issx_history_compare_safe_degraded: return "compare_safe_degraded";
      case issx_history_compare_safe_strong: return "compare_safe_strong";
      case issx_history_degraded_unstable: return "degraded_unstable";
      case issx_history_blocked: return "blocked";
      default: return "unknown";
     }
  }

string ISSX_HistoryFinalityClassToString(const ISSX_HistoryFinalityClass v)
  {
   switch(v)
     {
      case issx_history_finality_stable: return "stable";
      case issx_history_finality_watch: return "watch";
      case issx_history_finality_unstable: return "unstable";
      case issx_history_finality_recovering: return "recovering";
      default: return "unknown";
     }
  }

string ISSX_HistoryRewriteClassToString(const ISSX_HistoryRewriteClass v)
  {
   switch(v)
     {
      case issx_rewrite_none: return "none";
      case issx_rewrite_benign_last_bar_adjustment: return "benign_last_bar_adjustment";
      case issx_rewrite_short_tail: return "short_tail_rewrite";
      case issx_rewrite_structural_gap: return "structural_gap_rewrite";
      case issx_rewrite_historical_block: return "historical_block_rewrite";
      default: return "unknown";
     }
  }

#endif // __ISSX_CORE_MQH__
