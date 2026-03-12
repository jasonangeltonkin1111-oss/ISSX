#ifndef __ISSX_CORE_MQH__
#define __ISSX_CORE_MQH__
// ============================================================================
// ISSX CORE v1.723
// Shared foundation for the consolidated single-EA / five-stage ISSX kernel.
//
// HARDENING NOTES
// - upgraded owner surface to blueprint v1.723 governance
// - preserved shared semantic ownership in core only
// - expanded field-key ownership for manifest / scheduler / debug / EA5 surfaces
// - added compatibility-alias lifecycle and external-contract stability enums
// - added shared threshold definition DTOs for owner-locked acceptance governance
// - strengthened validation for manifest/header coherence and owner metadata
// - preserved compatibility bridges in core instead of forcing consumer-local hacks
// - retained deterministic UTF-8 hashing and canonical ordering helpers
// ============================================================================

// ============================================================================
// SECTION 01: VERSION / CONSTANTS
// ============================================================================

#define ISSX_ENGINE_NAME                              "ISSX"
#define ISSX_ENGINE_FAMILY                            "ISSX_PIPELINE"
#define ISSX_ENGINE_VERSION                           "1.733"
#define ISSX_SCHEMA_VERSION                           "1.718"
#define ISSX_SCHEMA_EPOCH                             10702
#define ISSX_STORAGE_VERSION                          1721
#define ISSX_STAGE_API_VERSION                        1721
#define ISSX_SERIALIZER_VERSION                       1721
#define ISSX_POLICY_FINGERPRINT_VERSION               1721
#define ISSX_FINGERPRINT_ALGO_VERSION                 4
#define ISSX_LEGEND_VERSION                           "1.718"
#define ISSX_OWNER_MODULE_NAME_CORE                   "issx_core.mqh"
#define ISSX_OWNER_MODULE_HASH_MEANING_VERSION        1

#define ISSX_BINARY_MAGIC                             0x49535358
#define ISSX_BINARY_MAGIC_ALT                         0x49535358
#define ISSX_HASH_HEX_WIDTH                           16
#define ISSX_MAX_JSON_DEPTH                           64
#define ISSX_MAX_TRACE_CODE_LEN                       96
#define ISSX_MAX_FIELD_NAME_LEN                       96
#define ISSX_MAX_REASON_LEN                           256
#define ISSX_MAX_CHANGED_IDS                          512
#define ISSX_MAX_SYMBOLS_PER_TRACE                    32
#define ISSX_MAX_POLICY_FINGERPRINT_LEN               128
#define ISSX_MAX_SURFACE_NAME_LEN                     128
#define ISSX_MAX_OWNER_MODULE_NAME_LEN                96
#define ISSX_STAGE_COUNT                              5
#define ISSX_JSON_DOUBLE_DIGITS_DEFAULT               6

#define ISSX_NUMERIC_UNKNOWN_LONG                     (-1L)
#define ISSX_NUMERIC_UNKNOWN_INT                      (-1)
#define ISSX_NUMERIC_UNKNOWN_DOUBLE                   (-1.0)

#define ISSX_PATH_SEP                                 "/"
#define ISSX_JSON_EXT                                 ".json"
#define ISSX_BIN_EXT                                  ".bin"

#define ISSX_DIR_ROOT_NAME                            "ISSX"
#define ISSX_DIR_FIRMS                                "FIRMS"
#define ISSX_DIR_PERSISTENCE                          "persistence"
#define ISSX_DIR_PERSISTENCE_SHARED                   "persistence"
#define ISSX_DIR_PERSISTENCE_EA1                      "persistence/ea1"
#define ISSX_DIR_PERSISTENCE_EA2                      "persistence/ea2"
#define ISSX_DIR_PERSISTENCE_EA3                      "persistence/ea3"
#define ISSX_DIR_PERSISTENCE_EA4                      "persistence/ea4"
#define ISSX_DIR_PERSISTENCE_EA5                      "persistence/ea5"
#define ISSX_DIR_PERSISTENCE_EA1_UNIVERSE             "persistence/ea1/universe"
#define ISSX_DIR_PERSISTENCE_EA2_HISTORY_STORE        "persistence/ea2/history_store"
#define ISSX_DIR_PERSISTENCE_EA2_HISTORY_INDEX        "persistence/ea2/history_index"
#define ISSX_DIR_DEBUG                                "debug"
#define ISSX_DIR_LOCKS                                "locks"
#define ISSX_DIR_SCHEMAS                              "schemas"
#define ISSX_DIR_HUD                                  "hud"

#define ISSX_ROOT_EXPORT                              "issx_export.json"
#define ISSX_ROOT_DEBUG                               "issx_debug.json"
#define ISSX_ROOT_STAGE_STATUS                        "issx_stage_status.json"
#define ISSX_ROOT_UNIVERSE_SNAPSHOT                   "issx_universe_snapshot.json"

#define ISSX_LOCK_FILENAME                            "issx.lock"

#define ISSX_BIN_HEADER_CURRENT                       "header_current.bin"
#define ISSX_BIN_HEADER_PREVIOUS                      "header_previous.bin"
#define ISSX_BIN_HEADER_CANDIDATE                     "header_candidate.bin"
#define ISSX_BIN_PAYLOAD_CURRENT                      "payload_current.bin"
#define ISSX_BIN_PAYLOAD_PREVIOUS                     "payload_previous.bin"
#define ISSX_BIN_PAYLOAD_LASTGOOD                     "payload_last_good.bin"
#define ISSX_BIN_PAYLOAD_CANDIDATE                    "payload_candidate.bin"
#define ISSX_JSON_MANIFEST_CURRENT                    "manifest_current.json"
#define ISSX_JSON_MANIFEST_PREVIOUS                   "manifest_previous.json"
#define ISSX_JSON_MANIFEST_LASTGOOD                   "manifest_last_good.json"
#define ISSX_JSON_MANIFEST_CANDIDATE                  "manifest_candidate.json"
#define ISSX_BIN_CONTINUITY_STATE                     "continuity_state.bin"
#define ISSX_BIN_PHASE_STATE                          "phase_state.bin"
#define ISSX_BIN_QUEUE_STATE                          "queue_state.bin"
#define ISSX_BIN_CACHE_STATE                          "cache_state.bin"

#define ISSX_BIN_BROKER_UNIVERSE_CURRENT              "broker_universe_current.bin"
#define ISSX_BIN_BROKER_UNIVERSE_PREVIOUS             "broker_universe_previous.bin"
#define ISSX_JSON_BROKER_UNIVERSE_MANIFEST            "broker_universe_manifest.json"
#define ISSX_JSON_BROKER_UNIVERSE_SNAPSHOT            "broker_universe_snapshot.json"

#define ISSX_BIN_HISTORY_SYMBOL_REGISTRY              "symbol_registry.bin"
#define ISSX_BIN_HISTORY_TIMEFRAME_INDEX              "timeframe_index.bin"
#define ISSX_BIN_HISTORY_HYDRATION_CURSOR             "hydration_cursor_state.bin"
#define ISSX_BIN_HISTORY_DIRTY_SET                    "dirty_set.bin"
#define ISSX_JSON_BAR_STORE_MANIFEST                  "bar_store_manifest.json"

#define ISSX_BIN_SHARD_SYMBOL_REGISTRY                "shard_symbol_registry.bin"
#define ISSX_BIN_SHARD_HISTORY_INDEX                  "shard_history_index.bin"
#define ISSX_BIN_SHARD_BUCKET_STATE                   "shard_bucket_state.bin"
#define ISSX_BIN_SHARD_PAIR_CACHE                     "shard_pair_cache.bin"
#define ISSX_BIN_SHARD_CONTEXT_CACHE                  "shard_context_cache.bin"
#define ISSX_BIN_SHARD_DELTA_INDEX                    "shard_delta_index.bin"

#define ISSX_DEBUG_SNAPSHOT_EA1                       "ea1_debug_snapshot.json"
#define ISSX_DEBUG_SNAPSHOT_EA2                       "ea2_debug_snapshot.json"
#define ISSX_DEBUG_SNAPSHOT_EA3                       "ea3_debug_snapshot.json"
#define ISSX_DEBUG_SNAPSHOT_EA4                       "ea4_debug_snapshot.json"
#define ISSX_DEBUG_SNAPSHOT_EA5                       "ea5_debug_snapshot.json"

#define ISSX_HISTORY_STORE_M5                         "M5"
#define ISSX_HISTORY_STORE_M15                        "M15"
#define ISSX_HISTORY_STORE_H1                         "H1"
#define ISSX_HISTORY_SYMBOL_SUFFIX                    ".bin"

#define ISSX_DEFAULT_RETAINED_BARS_M5                 750
#define ISSX_DEFAULT_RETAINED_BARS_M15                750
#define ISSX_DEFAULT_RETAINED_BARS_H1                 750

#define ISSX_EVENT_TIMER_SEC                          1
#define ISSX_EA5_EXPORT_CADENCE_MIN                   10

#define ISSX_WRITER_CODEPAGE_UTF8                     "UTF-8"
#define ISSX_SOURCE_SNAPSHOT_KIND_UNKNOWN             "unknown"
#define ISSX_SOURCE_SNAPSHOT_KIND_ACCEPTED            "accepted_current"
#define ISSX_SOURCE_SNAPSHOT_KIND_PREVIOUS            "previous"
#define ISSX_SOURCE_SNAPSHOT_KIND_LAST_GOOD           "last_good"
#define ISSX_SOURCE_SNAPSHOT_KIND_CANDIDATE           "candidate"
#define ISSX_SOURCE_SNAPSHOT_KIND_HANDOFF             "same_tick_handoff"
#define ISSX_SOURCE_SNAPSHOT_KIND_PUBLIC_ROOT         "public_root_view"

#define ISSX_STAGE_API_METHOD_STAGE_BOOT              "StageBoot"
#define ISSX_STAGE_API_METHOD_STAGE_SLICE             "StageSlice"
#define ISSX_STAGE_API_METHOD_STAGE_PUBLISH           "StagePublish"
#define ISSX_STAGE_API_METHOD_BUILD_DEBUG_SNAPSHOT    "BuildDebugSnapshot"
#define ISSX_STAGE_API_METHOD_BUILD_STAGE_JSON        "BuildStageJson"
#define ISSX_STAGE_API_METHOD_BUILD_DEBUG_JSON        "BuildDebugJson"
#define ISSX_STAGE_API_METHOD_EXPORT_OPTIONAL_INTEL   "ExportOptionalIntelligence"

#define ISSX_ACCEPTANCE_OK                            0
#define ISSX_ACCEPTANCE_ERR_INCOMPLETE                1001
#define ISSX_ACCEPTANCE_ERR_STAGE_MISMATCH            1002
#define ISSX_ACCEPTANCE_ERR_FIRM_MISMATCH             1003
#define ISSX_ACCEPTANCE_ERR_SCHEMA                    1004
#define ISSX_ACCEPTANCE_ERR_SEQUENCE                  1005
#define ISSX_ACCEPTANCE_ERR_HASH                      1006
#define ISSX_ACCEPTANCE_ERR_FILESET                   1007
#define ISSX_ACCEPTANCE_ERR_TOPBLOCK                  1008
#define ISSX_ACCEPTANCE_ERR_PARSE                     1009
#define ISSX_ACCEPTANCE_ERR_COMPATIBILITY             1010
#define ISSX_ACCEPTANCE_ERR_SEMANTIC                  1011
#define ISSX_ACCEPTANCE_ERR_CANDIDATE_SET             1012
#define ISSX_ACCEPTANCE_ERR_MANIFEST                  1013
#define ISSX_ACCEPTANCE_ERR_ROOT_PROJECTION           1014
#define ISSX_ACCEPTANCE_ERR_STORAGE                   1015
#define ISSX_ACCEPTANCE_ERR_GENERATION                1016
#define ISSX_ACCEPTANCE_ERR_POLICY                    1017
#define ISSX_ACCEPTANCE_ERR_COHERENCE                 1018
#define ISSX_ACCEPTANCE_ERR_OWNER                     1019
#define ISSX_ACCEPTANCE_ERR_RESUME                    1020
#define ISSX_ACCEPTANCE_ERR_HEADER                    1021
#define ISSX_ACCEPTANCE_ERR_DEFAULT_SEMANTIC          1022
#define ISSX_ACCEPTANCE_ERR_STAGE_INDEX               1023
#define ISSX_ACCEPTANCE_ERR_SOURCE_KIND               1024
#define ISSX_ACCEPTANCE_ERR_THRESHOLD                 1025
#define ISSX_ACCEPTANCE_ERR_INCLUDE_DRIFT             1026
#define ISSX_ACCEPTANCE_ERR_ALIAS_DRIFT               1027

// Canonical runtime/pipeline error classification for deterministic diagnostics.
enum ISSX_ErrorCode
  {
   ISSX_ERR_NONE = 0,

   // DISCOVERY
   ISSX_ERR_SYMBOL_DISCOVERY,
   ISSX_ERR_INVALID_SYMBOL,

   // HISTORY
   ISSX_ERR_COPYRATES,
   ISSX_ERR_HISTORY_NOT_READY,

   // MEMORY
   ISSX_ERR_MEMORY_ALLOC,

   // PERSISTENCE
   ISSX_ERR_JSON_BUILD,
   ISSX_ERR_FILE_WRITE,

   // RUNTIME
   ISSX_ERR_STAGE_DISABLED,
   ISSX_ERR_STAGE_SKIPPED,
   ISSX_ERR_RUNTIME_LIMIT,
   ISSX_ERR_TIMEOUT,

   ISSX_ERR_UNKNOWN
  };

string ISSX_ErrorToString(const ISSX_ErrorCode code)
  {
   switch(code)
     {
      case ISSX_ERR_NONE:              return "none";
      case ISSX_ERR_SYMBOL_DISCOVERY:  return "symbol_discovery";
      case ISSX_ERR_INVALID_SYMBOL:    return "invalid_symbol";
      case ISSX_ERR_COPYRATES:         return "copyrates";
      case ISSX_ERR_HISTORY_NOT_READY: return "history_not_ready";
      case ISSX_ERR_MEMORY_ALLOC:      return "memory_alloc";
      case ISSX_ERR_JSON_BUILD:        return "json_build";
      case ISSX_ERR_FILE_WRITE:        return "file_write";
      case ISSX_ERR_STAGE_DISABLED:    return "stage_disabled";
      case ISSX_ERR_STAGE_SKIPPED:     return "stage_skipped";
      case ISSX_ERR_RUNTIME_LIMIT:     return "runtime_limit";
      case ISSX_ERR_TIMEOUT:           return "timeout";
      case ISSX_ERR_UNKNOWN:           return "unknown";
     }
   return "unknown";
  }

#define ISSX_THRESHOLD_MIN_FRESHNESS                  "minimum_freshness"
#define ISSX_THRESHOLD_CONTRADICTION_LIMIT            "contradiction_threshold"
#define ISSX_THRESHOLD_ACCEPTED_DEGRADED_FLOOR        "accepted_degraded_floor"
#define ISSX_THRESHOLD_ACCEPTED_PIPELINE_FLOOR        "accepted_for_pipeline_floor"
#define ISSX_THRESHOLD_ACCEPTED_RANKING_FLOOR         "accepted_for_ranking_floor"
#define ISSX_THRESHOLD_ACCEPTED_INTELLIGENCE_FLOOR    "accepted_for_intelligence_floor"
#define ISSX_THRESHOLD_ACCEPTED_EXPORT_FLOOR          "accepted_for_gpt_export_floor"
#define ISSX_THRESHOLD_LAST_GOOD_PROMOTION_FLOOR      "last_good_promotion_floor"
#define ISSX_THRESHOLD_FALLBACK_USABILITY_FLOOR       "fallback_usability_floor"
#define ISSX_THRESHOLD_COMPARE_SAFE_DEGRADED_FLOOR    "compare_safe_degraded_floor"
#define ISSX_THRESHOLD_COMPARE_SAFE_STRONG_FLOOR      "compare_safe_strong_floor"
#define ISSX_THRESHOLD_EXPLORATORY_PARTICIPATION      "exploratory_lane_participation_floor"
#define ISSX_THRESHOLD_EXPLORATORY_CONFIDENCE_CAP     "exploratory_confidence_cap_conditions"
#define ISSX_THRESHOLD_BUCKET_MIN_PUBLISH_FLOOR       "bucket_minimum_publish_floor"
#define ISSX_THRESHOLD_PAIR_VALIDITY_MIN_FLOOR        "pair_validity_minimum_floor"
#define ISSX_THRESHOLD_REGIME_PUBLISH_MIN_FLOOR       "regime_context_publish_minimum_floor"

// ============================================================================
// SECTION 02: FIELD KEY REGISTRY CONSTANTS
// ============================================================================

#define ISSX_FIELD_STAGE_MINIMUM_READY_FLAG              "stage_minimum_ready_flag"
#define ISSX_FIELD_STAGE_PUBLISHABILITY_STATE            "stage_publishability_state"
#define ISSX_FIELD_UPSTREAM_HANDOFF_MODE                 "upstream_handoff_mode"
#define ISSX_FIELD_UPSTREAM_HANDOFF_COMPATIBILITY_CLASS  "upstream_handoff_compatibility_class"
#define ISSX_FIELD_UPSTREAM_HANDOFF_SAME_TICK_FLAG       "upstream_handoff_same_tick_flag"
#define ISSX_FIELD_UPSTREAM_PARTIAL_PROGRESS_FLAG        "upstream_partial_progress_flag"
#define ISSX_FIELD_WAREHOUSE_QUALITY                     "warehouse_quality"
#define ISSX_FIELD_WAREHOUSE_RETAINED_BAR_COUNT          "warehouse_retained_bar_count"
#define ISSX_FIELD_DUMP_SEQUENCE_NO                      "dump_sequence_no"
#define ISSX_FIELD_DUMP_MINUTE_ID                        "dump_minute_id"
#define ISSX_FIELD_DEBUG_WEAK_LINK_CODE                  "debug_weak_link_code"
#define ISSX_FIELD_DEPENDENCY_BLOCK_REASON               "dependency_block_reason"
#define ISSX_FIELD_STAGE_DEPENDENCY_BLOCK_REASON        ISSX_FIELD_DEPENDENCY_BLOCK_REASON
#define ISSX_FIELD_KERNEL_DEGRADED_CYCLE_FLAG            "kernel_degraded_cycle_flag"
#define ISSX_FIELD_FALLBACK_READ_RATIO_1H                "fallback_read_ratio_1h"
#define ISSX_FIELD_SAME_TICK_HANDOFF_RATIO_1H            "same_tick_handoff_ratio_1h"
#define ISSX_FIELD_FRESH_ACCEPT_RATIO_1H                 "fresh_accept_ratio_1h"
#define ISSX_FIELD_POLICY_FINGERPRINT                    "policy_fingerprint"
#define ISSX_FIELD_FINGERPRINT_ALGO_VERSION              "fingerprint_algorithm_version"
#define ISSX_FIELD_CONTRADICTION_CLASS_COUNTS            "contradiction_class_counts"
#define ISSX_FIELD_HIGHEST_BLOCKING_CONTRADICTION_CLASS  "highest_blocking_contradiction_class"
#define ISSX_FIELD_CONTRADICTION_REPAIR_STATE            "contradiction_repair_state"
#define ISSX_FIELD_COVERAGE_RANKABLE_RECENT_PCT          "coverage_rankable_recent_pct"
#define ISSX_FIELD_COVERAGE_FRONTIER_RECENT_PCT          "coverage_frontier_recent_pct"
#define ISSX_FIELD_HISTORY_DEEP_COMPLETION_PCT           "history_deep_completion_pct"
#define ISSX_FIELD_WINNER_CACHE_DEPENDENCE_PCT           "winner_cache_dependence_pct"
#define ISSX_FIELD_CLOCK_DIVERGENCE_SEC                  "clock_divergence_sec"
#define ISSX_FIELD_SCHEDULER_LATE_BY_MS                  "scheduler_late_by_ms"
#define ISSX_FIELD_MISSED_SCHEDULE_WINDOWS_ESTIMATE      "missed_schedule_windows_estimate"
#define ISSX_FIELD_PAIR_VALIDITY_CLASS                   "pair_validity_class"
#define ISSX_FIELD_PAIR_SAMPLE_ALIGNMENT_CLASS           "pair_sample_alignment_class"
#define ISSX_FIELD_PAIR_WINDOW_FRESHNESS_CLASS           "pair_window_freshness_class"
#define ISSX_FIELD_WAREHOUSE_CLIP_FLAG                   "warehouse_clip_flag"
#define ISSX_FIELD_WARMUP_SUFFICIENT_FLAG                "warmup_sufficient_flag"
#define ISSX_FIELD_EFFECTIVE_LOOKBACK_BARS               "effective_lookback_bars"
#define ISSX_FIELD_RANKABILITY_LANE                      "rankability_lane"
#define ISSX_FIELD_EXPLORATORY_PENALTY_APPLIED           "exploratory_penalty_applied"
#define ISSX_FIELD_INTRADAY_ACTIVITY_STATE               "intraday_activity_state"
#define ISSX_FIELD_LIQUIDITY_REGIME_CLASS                "liquidity_regime_class"
#define ISSX_FIELD_VOLATILITY_REGIME_CLASS               "volatility_regime_class"
#define ISSX_FIELD_EXPANSION_STATE_CLASS                 "expansion_state_class"
#define ISSX_FIELD_MOVEMENT_QUALITY_CLASS                "movement_quality_class"
#define ISSX_FIELD_MOVEMENT_MATURITY_CLASS               "movement_maturity_class"
#define ISSX_FIELD_SESSION_PHASE_CLASS                   "session_phase_class"
#define ISSX_FIELD_TRADABILITY_NOW_CLASS                 "tradability_now_class"
#define ISSX_FIELD_HOLDING_HORIZON_CONTEXT               "holding_horizon_context"
#define ISSX_FIELD_CONSTRUCTABILITY_CLASS                "constructability_class"
#define ISSX_FIELD_DIVERSIFICATION_CONFIDENCE_CLASS      "diversification_confidence_class"
#define ISSX_FIELD_REDUNDANCY_RISK_CLASS                 "redundancy_risk_class"
#define ISSX_FIELD_SELECTION_REASON_SUMMARY              "selection_reason_summary"
#define ISSX_FIELD_SELECTION_PENALTY_SUMMARY             "selection_penalty_summary"
#define ISSX_FIELD_WINNER_LIMITATION_SUMMARY             "winner_limitation_summary"
#define ISSX_FIELD_WINNER_CONFIDENCE_CLASS               "winner_confidence_class"
#define ISSX_FIELD_OPPORTUNITY_WITH_CAUTION_FLAG         "opportunity_with_caution_flag"
#define ISSX_FIELD_EARLY_MOVE_QUALITY_CLASS              "early_move_quality_class"
#define ISSX_FIELD_MOVEMENT_TO_COST_EFFICIENCY_CLASS     "movement_to_cost_efficiency_class"

#define ISSX_FIELD_BROKER_UNIVERSE_FINGERPRINT           "broker_universe_fingerprint"
#define ISSX_FIELD_ELIGIBLE_UNIVERSE_FINGERPRINT         "eligible_universe_fingerprint"
#define ISSX_FIELD_ACTIVE_UNIVERSE_FINGERPRINT           "active_universe_fingerprint"
#define ISSX_FIELD_RANKABLE_UNIVERSE_FINGERPRINT         "rankable_universe_fingerprint"
#define ISSX_FIELD_FRONTIER_UNIVERSE_FINGERPRINT         "frontier_universe_fingerprint"
#define ISSX_FIELD_PUBLISHABLE_UNIVERSE_FINGERPRINT      "publishable_universe_fingerprint"
#define ISSX_FIELD_CHANGED_SYMBOL_COUNT                  "changed_symbol_count"
#define ISSX_FIELD_CHANGED_SYMBOL_IDS                    "changed_symbol_ids"
#define ISSX_FIELD_CHANGED_FAMILY_COUNT                  "changed_family_count"
#define ISSX_FIELD_CHANGED_BUCKET_COUNT                  "changed_bucket_count"
#define ISSX_FIELD_CHANGED_FRONTIER_COUNT                "changed_frontier_count"
#define ISSX_FIELD_CHANGED_TIMEFRAME_COUNT               "changed_timeframe_count"
#define ISSX_FIELD_PERCENT_UNIVERSE_TOUCHED_RECENT       "percent_universe_touched_recent"
#define ISSX_FIELD_PERCENT_RANKABLE_REVALIDATED_RECENT   "percent_rankable_revalidated_recent"
#define ISSX_FIELD_PERCENT_FRONTIER_REVALIDATED_RECENT   "percent_frontier_revalidated_recent"
#define ISSX_FIELD_NEVER_SERVICED_COUNT                  "never_serviced_count"
#define ISSX_FIELD_OVERDUE_SERVICE_COUNT                 "overdue_service_count"
#define ISSX_FIELD_NEVER_RANKED_BUT_ELIGIBLE_COUNT       "never_ranked_but_eligible_count"
#define ISSX_FIELD_NEWLY_ACTIVE_SYMBOLS_WAITING_COUNT    "newly_active_symbols_waiting_count"
#define ISSX_FIELD_NEAR_CUTLINE_RECHECK_AGE_MAX          "near_cutline_recheck_age_max"

#define ISSX_FIELD_MINUTE_EPOCH_SOURCE                   "minute_epoch_source"
#define ISSX_FIELD_SCHEDULER_CLOCK_SOURCE                "scheduler_clock_source"
#define ISSX_FIELD_FRESHNESS_CLOCK_SOURCE                "freshness_clock_source"
#define ISSX_FIELD_TIMER_GAP_MS_NOW                      "timer_gap_ms_now"
#define ISSX_FIELD_TIMER_GAP_MS_MEAN                     "timer_gap_ms_mean"
#define ISSX_FIELD_TIMER_GAP_MS_P95                      "timer_gap_ms_p95"
#define ISSX_FIELD_QUOTE_CLOCK_IDLE_FLAG                 "quote_clock_idle_flag"
#define ISSX_FIELD_CLOCK_SANITY_SCORE                    "clock_sanity_score"
#define ISSX_FIELD_CLOCK_ANOMALY_FLAG                    "clock_anomaly_flag"
#define ISSX_FIELD_TIME_PENALTY_APPLIED                  "time_penalty_applied"
#define ISSX_FIELD_KERNEL_MINUTE_ID                      "kernel_minute_id"
#define ISSX_FIELD_SCHEDULER_CYCLE_NO                    "scheduler_cycle_no"
#define ISSX_FIELD_CURRENT_STAGE_SLOT                    "current_stage_slot"
#define ISSX_FIELD_CURRENT_STAGE_PHASE                   "current_stage_phase"
#define ISSX_FIELD_CURRENT_STAGE_BUDGET_MS               "current_stage_budget_ms"
#define ISSX_FIELD_CURRENT_STAGE_DEADLINE_MS             "current_stage_deadline_ms"
#define ISSX_FIELD_STAGE_LAST_RUN_MS                     "stage_last_run_ms"
#define ISSX_FIELD_STAGE_LAST_PUBLISH_MINUTE_ID          "stage_last_publish_minute_id"
#define ISSX_FIELD_STAGE_PUBLISH_DUE_FLAG                "stage_publish_due_flag"
#define ISSX_FIELD_STAGE_BACKLOG_SCORE                   "stage_backlog_score"
#define ISSX_FIELD_STAGE_STARVATION_SCORE                "stage_starvation_score"
#define ISSX_FIELD_STAGE_RESUME_KEY                      "stage_resume_key"
#define ISSX_FIELD_STAGE_LAST_SUCCESS_SERVICE_MONO_MS    "stage_last_successful_service_mono_ms"
#define ISSX_FIELD_STAGE_LAST_ATTEMPT_SERVICE_MONO_MS    "stage_last_attempted_service_mono_ms"
#define ISSX_FIELD_STAGE_MISSED_DUE_CYCLES               "stage_missed_due_cycles"
#define ISSX_FIELD_KERNEL_BUDGET_TOTAL_MS                "kernel_budget_total_ms"
#define ISSX_FIELD_KERNEL_BUDGET_SPENT_MS                "kernel_budget_spent_ms"
#define ISSX_FIELD_KERNEL_BUDGET_RESERVED_COMMIT_MS      "kernel_budget_reserved_commit_ms"
#define ISSX_FIELD_KERNEL_BUDGET_DEBT_MS                 "kernel_budget_debt_ms"
#define ISSX_FIELD_KERNEL_FORCED_SERVICE_DUE_FLAG        "kernel_forced_service_due_flag"
#define ISSX_FIELD_KERNEL_OVERRUN_CLASS                  "kernel_overrun_class"
#define ISSX_FIELD_DISCOVERY_BUDGET_MS                   "discovery_budget_ms"
#define ISSX_FIELD_PROBE_BUDGET_MS                       "probe_budget_ms"
#define ISSX_FIELD_QUOTE_SAMPLING_BUDGET_MS              "quote_sampling_budget_ms"
#define ISSX_FIELD_HISTORY_WARM_BUDGET_MS                "history_warm_budget_ms"
#define ISSX_FIELD_HISTORY_DEEP_BUDGET_MS                "history_deep_budget_ms"
#define ISSX_FIELD_PAIR_BUDGET_MS                        "pair_budget_ms"
#define ISSX_FIELD_CACHE_BUDGET_MS                       "cache_budget_ms"
#define ISSX_FIELD_PERSISTENCE_BUDGET_MS                 "persistence_budget_ms"
#define ISSX_FIELD_PUBLISH_BUDGET_MS                     "publish_budget_ms"
#define ISSX_FIELD_DEBUG_BUDGET_MS                       "debug_budget_ms"
#define ISSX_FIELD_FRESHNESS_FASTLANE_BUDGET_MS          "freshness_fastlane_budget_ms"
#define ISSX_FIELD_DISCOVERY_CURSOR                      "discovery_cursor"
#define ISSX_FIELD_SPEC_PROBE_CURSOR                     "spec_probe_cursor"
#define ISSX_FIELD_RUNTIME_SAMPLE_CURSOR                 "runtime_sample_cursor"
#define ISSX_FIELD_HISTORY_WARM_CURSOR                   "history_warm_cursor"
#define ISSX_FIELD_HISTORY_DEEP_CURSOR                   "history_deep_cursor"
#define ISSX_FIELD_BUCKET_REBUILD_CURSOR                 "bucket_rebuild_cursor"
#define ISSX_FIELD_PAIR_QUEUE_CURSOR                     "pair_queue_cursor"
#define ISSX_FIELD_REPAIR_CURSOR                         "repair_cursor"
#define ISSX_FIELD_ROTATION_WINDOW_ESTIMATED_CYCLES      "rotation_window_estimated_cycles"
#define ISSX_FIELD_DEEP_BACKLOG_REMAINING                "deep_backlog_remaining"
#define ISSX_FIELD_SECTOR_COLD_BACKLOG_COUNT             "sector_cold_backlog_count"

#define ISSX_FIELD_WEAKEST_STAGE                         "weakest_stage"
#define ISSX_FIELD_WEAKEST_STAGE_REASON                  "weakest_stage_reason"
#define ISSX_FIELD_WEAK_LINK_SEVERITY                    "weak_link_severity"
#define ISSX_FIELD_ERROR_WEIGHT                          "error_weight"
#define ISSX_FIELD_DEGRADE_WEIGHT                        "degrade_weight"
#define ISSX_FIELD_DEPENDENCY_WEIGHT                     "dependency_weight"
#define ISSX_FIELD_FALLBACK_WEIGHT                       "fallback_weight"
#define ISSX_FIELD_FRONTIER_REFRESH_LAG_FOR_NEW_MOVERS   "frontier_refresh_lag_for_new_movers"
#define ISSX_FIELD_SELECTION_LATENCY_RISK_CLASS          "selection_latency_risk_class"
#define ISSX_FIELD_NEVER_RANKED_BUT_NOW_OBSERVABLE_COUNT "never_ranked_but_now_observable_count"

#define ISSX_FIELD_EXPORT_GENERATED_AT                   "export_generated_at"
#define ISSX_FIELD_EA1_AGE_SEC                           "ea1_age_sec"
#define ISSX_FIELD_EA2_AGE_SEC                           "ea2_age_sec"
#define ISSX_FIELD_EA3_AGE_SEC                           "ea3_age_sec"
#define ISSX_FIELD_EA4_AGE_SEC                           "ea4_age_sec"
#define ISSX_FIELD_SOURCE_GENERATION_IDS                 "source_generation_ids"
#define ISSX_FIELD_WINNER_HISTORY_AGE_BY_TF              "winner_history_age_by_tf"
#define ISSX_FIELD_WINNER_QUOTE_AGE_SEC                  "winner_quote_age_sec"
#define ISSX_FIELD_WINNER_TRADEABILITY_REFRESH_AGE_SEC   "winner_tradeability_refresh_age_sec"
#define ISSX_FIELD_WINNER_RANK_REFRESH_AGE_SEC           "winner_rank_refresh_age_sec"
#define ISSX_FIELD_WINNER_REGIME_REFRESH_AGE_SEC         "winner_regime_refresh_age_sec"
#define ISSX_FIELD_WINNER_CORR_REFRESH_AGE_SEC           "winner_corr_refresh_age_sec"
#define ISSX_FIELD_WINNER_LAST_MATERIAL_CHANGE_SEC       "winner_last_material_change_sec"
#define ISSX_FIELD_REGIME_SUMMARY                        "regime_summary"
#define ISSX_FIELD_EXECUTION_CONDITION_SUMMARY           "execution_condition_summary"
#define ISSX_FIELD_DIVERSIFICATION_CONTEXT_SUMMARY       "diversification_context_summary"
#define ISSX_FIELD_WHY_EXPORT_IS_THIN                    "why_export_is_thin"
#define ISSX_FIELD_WHY_PUBLISH_IS_STALE                  "why_publish_is_stale"
#define ISSX_FIELD_WHY_FRONTIER_IS_SMALL                 "why_frontier_is_small"
#define ISSX_FIELD_WHY_INTELLIGENCE_ABSTAINED            "why_intelligence_abstained"
#define ISSX_FIELD_LARGEST_BACKLOG_OWNER                 "largest_backlog_owner"
#define ISSX_FIELD_OLDEST_UNSERVED_QUEUE_FAMILY          "oldest_unserved_queue_family"

#define ISSX_FIELD_STAGE_API_VERSION                     "stage_api_version"
#define ISSX_FIELD_SERIALIZER_VERSION                    "serializer_version"
#define ISSX_FIELD_WRITER_CODEPAGE                       "writer_codepage"
#define ISSX_FIELD_SOURCE_SNAPSHOT_KIND                  "source_snapshot_kind"
#define ISSX_FIELD_RESUME_COMPATIBILITY_CLASS            "resume_compatibility_class"
#define ISSX_FIELD_OWNER_MODULE_NAME                     "owner_module_name"
#define ISSX_FIELD_OWNER_MODULE_HASH                     "owner_module_hash"
#define ISSX_FIELD_OWNER_MODULE_HASH_MEANING_VERSION     "owner_module_hash_meaning_version"
#define ISSX_FIELD_ACCEPTED_PROMOTION_VERIFIED           "accepted_promotion_verified"
#define ISSX_FIELD_PROJECTION_PARTIAL_SUCCESS_FLAG       "projection_partial_success_flag"
#define ISSX_FIELD_HANDOFF_SEQUENCE_NO                   "handoff_sequence_no"
#define ISSX_FIELD_HANDOFF_MODE                          "handoff_mode"
#define ISSX_FIELD_LEGEND_HASH                           "legend_hash"
#define ISSX_FIELD_COMPATIBILITY_CLASS                   "compatibility_class"
#define ISSX_FIELD_CONTENT_CLASS                         "content_class"
#define ISSX_FIELD_PUBLISH_REASON                        "publish_reason"
#define ISSX_FIELD_UNIVERSE_FINGERPRINT                  "universe_fingerprint"
#define ISSX_FIELD_TAXONOMY_HASH                         "taxonomy_hash"
#define ISSX_FIELD_COMPARATOR_REGISTRY_HASH              "comparator_registry_hash"
#define ISSX_FIELD_COHORT_FINGERPRINT                    "cohort_fingerprint"
#define ISSX_FIELD_TRIO_GENERATION_ID                    "trio_generation_id"
#define ISSX_FIELD_PAYLOAD_HASH                          "payload_hash"
#define ISSX_FIELD_HEADER_HASH                           "header_hash"
#define ISSX_FIELD_PAYLOAD_LENGTH                        "payload_length"
#define ISSX_FIELD_HEADER_LENGTH                         "header_length"
#define ISSX_FIELD_SYMBOL_COUNT                          "symbol_count"
#define ISSX_FIELD_MINUTE_ID                             "minute_id"
#define ISSX_FIELD_SEQUENCE_NO                           "sequence_no"
#define ISSX_FIELD_WRITER_GENERATION                     "writer_generation"
#define ISSX_FIELD_WRITER_BOOT_ID                        "writer_boot_id"
#define ISSX_FIELD_WRITER_NONCE                          "writer_nonce"
#define ISSX_FIELD_FIRM_ID                               "firm_id"
#define ISSX_FIELD_STAGE_ID                              "stage_id"
#define ISSX_FIELD_SCHEMA_VERSION                        "schema_version"
#define ISSX_FIELD_SCHEMA_EPOCH                          "schema_epoch"
#define ISSX_FIELD_STORAGE_VERSION                       "storage_version"
#define ISSX_FIELD_ACCEPTANCE_TYPE                       "acceptance_type"
#define ISSX_FIELD_ACCEPTANCE_ERROR_CODE                 "acceptance_error_code"
#define ISSX_FIELD_ACCEPTANCE_REASON                     "acceptance_reason"
#define ISSX_FIELD_ACCEPTED_STRONG_COUNT                 "accepted_strong_count"
#define ISSX_FIELD_ACCEPTED_DEGRADED_COUNT               "accepted_degraded_count"
#define ISSX_FIELD_REJECTED_COUNT                        "rejected_count"
#define ISSX_FIELD_COOLDOWN_COUNT                        "cooldown_count"
#define ISSX_FIELD_STALE_USABLE_COUNT                    "stale_usable_count"
#define ISSX_FIELD_CONTRADICTION_COUNT                   "contradiction_count"
#define ISSX_FIELD_CONTRADICTION_SEVERITY_MAX            "contradiction_severity_max"
#define ISSX_FIELD_DEGRADED_FLAG                         "degraded_flag"
#define ISSX_FIELD_FALLBACK_DEPTH_USED                   "fallback_depth_used"
#define ISSX_FIELD_COMPATIBILITY_SCORE                   "compatibility_score"
#define ISSX_FIELD_BLOCKING_CONTRADICTION_PRESENT        "blocking_contradiction_present"

#define ISSX_FIELD_LOCK_OWNER_BOOT_ID                    "lock_owner_boot_id"
#define ISSX_FIELD_LOCK_OWNER_INSTANCE_GUID              "lock_owner_instance_guid"
#define ISSX_FIELD_LOCK_OWNER_TERMINAL_IDENTITY          "lock_owner_terminal_identity"
#define ISSX_FIELD_LOCK_ACQUIRED_TIME                    "lock_acquired_time"
#define ISSX_FIELD_LOCK_HEARTBEAT_TIME                   "lock_heartbeat_time"
#define ISSX_FIELD_STALE_AFTER_SEC                       "stale_after_sec"

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
   issx_acceptance_unknown                    = 0,
   issx_acceptance_accepted_for_pipeline      = 1,
   issx_acceptance_accepted_for_ranking       = 2,
   issx_acceptance_accepted_for_intelligence  = 3,
   issx_acceptance_accepted_for_gpt_export    = 4,
   issx_acceptance_accepted_degraded          = 5,
   issx_acceptance_rejected                   = 6
  };

enum ISSX_PublishabilityState
  {
   issx_publishability_unknown         = 0,
   issx_publishability_not_ready       = 1,
   issx_publishability_blocked         = 2,
   issx_publishability_warmup          = 3,
   issx_publishability_usable_degraded = 4,
   issx_publishability_usable          = 5,
   issx_publishability_strong          = 6
  };

// Legacy compatibility bridge for pre-v1.718 shared labels.
// Shared compatibility aliases remain core-owned only.
#define issx_publishability_publishable       issx_publishability_usable
#define issx_publishability_degraded          issx_publishability_usable_degraded
#define issx_stage_publishability_unknown     issx_publishability_unknown
#define issx_stage_publishability_ready       issx_publishability_usable
#define issx_stage_publishability_degraded    issx_publishability_usable_degraded
#define issx_stage_publishability_blocked     issx_publishability_blocked
#define issx_stage_kernel                     issx_stage_shared

enum ISSX_CompatibilityClass
  {
   issx_compat_unknown              = 0,
   issx_compat_incompatible         = 1,
   issx_compat_schema_only          = 2,
   issx_compat_storage_compatible   = 3,
   issx_compat_policy_degraded      = 4,
   issx_compat_consumer_compatible  = 5,
   issx_compat_exact                = 6
  };

enum ISSX_ContentClass
  {
   issx_content_unknown = 0,
   issx_content_empty   = 1,
   issx_content_partial = 2,
   issx_content_usable  = 3,
   issx_content_strong  = 4
  };

enum ISSX_PublishReason
  {
   issx_publish_reason_unknown            = 0,
   issx_publish_bootstrap                 = 1,
   issx_publish_scheduled                 = 2,
   issx_publish_recovery                  = 3,
   issx_publish_material_change           = 4,
   issx_publish_degradation_transition    = 5,
   issx_publish_contradiction_transition  = 6,
   issx_publish_heartbeat                 = 7,
   issx_publish_manual                    = 8
  };

enum ISSX_HandoffMode
  {
   issx_handoff_unknown            = 0,
   issx_handoff_none               = 1,
   issx_handoff_same_tick_accepted = 2,
   issx_handoff_internal_current   = 3,
   issx_handoff_internal_previous  = 4,
   issx_handoff_internal_last_good = 5,
   issx_handoff_public_projection  = 6
  };

enum ISSX_ContradictionSeverity
  {
   issx_contradiction_severity_unknown = 0,
   issx_contradiction_none             = 1,
   issx_contradiction_low              = 2,
   issx_contradiction_moderate         = 3,
   issx_contradiction_high             = 4,
   issx_contradiction_blocking         = 5
  };

enum ISSX_ContradictionClass
  {
   issx_contradiction_class_unknown         = 0,
   issx_contradiction_identity              = 1,
   issx_contradiction_session               = 2,
   issx_contradiction_spec                  = 3,
   issx_contradiction_history_continuity    = 4,
   issx_contradiction_selection_ownership   = 5,
   issx_contradiction_intelligence_validity = 6
  };

enum ISSX_RepairState
  {
   issx_repair_unknown               = 0,
   issx_repair_none                  = 1,
   issx_repair_cooldown              = 2,
   issx_repair_reprobe_scheduled     = 3,
   issx_repair_active                = 4,
   issx_repair_temporarily_suspended = 5
  };

enum ISSX_RankabilityLane
  {
   issx_rankability_unknown     = 0,
   issx_rankability_strong      = 1,
   issx_rankability_usable      = 2,
   issx_rankability_exploratory = 3,
   issx_rankability_blocked     = 4
  };

enum ISSX_PairValidityClass
  {
   issx_pair_validity_unknown             = 0,
   issx_pair_validity_unknown_overlap     = 1,
   issx_pair_validity_valid_low_overlap   = 2,
   issx_pair_validity_valid_high_overlap  = 3,
   issx_pair_validity_provisional_overlap = 4,
   issx_pair_validity_blocked_overlap     = 5
  };

enum ISSX_PairSampleAlignmentClass
  {
   issx_pair_alignment_unknown = 0,
   issx_pair_alignment_poor    = 1,
   issx_pair_alignment_usable  = 2,
   issx_pair_alignment_strong  = 3
  };

enum ISSX_PairWindowFreshnessClass
  {
   issx_pair_window_freshness_unknown = 0,
   issx_pair_window_freshness_stale   = 1,
   issx_pair_window_freshness_usable  = 2,
   issx_pair_window_freshness_fresh   = 3
  };

enum ISSX_DirectOrDerived
  {
   issx_direct_or_derived_unknown = 0,
   issx_direct_field              = 1,
   issx_derived_field             = 2
  };

enum ISSX_AuthorityLevel
  {
   issx_authority_unknown   = 0,
   issx_authority_observed  = 1,
   issx_authority_validated = 2,
   issx_authority_derived   = 3,
   issx_authority_advisory  = 4,
   issx_authority_degraded  = 5
  };

enum ISSX_StalePolicy
  {
   issx_stale_policy_unknown             = 0,
   issx_stale_valid_until_threshold      = 1,
   issx_stale_degrade_after_threshold    = 2,
   issx_stale_invalidate_after_threshold = 3,
   issx_stale_not_time_sensitive         = 4
  };

enum ISSX_MissingPolicy
  {
   issx_missing_unknown = 0,
   issx_missing_ignore  = 1,
   issx_missing_default = 2,
   issx_missing_error   = 3
  };

enum ISSX_TruthClass
  {
   issx_truth_unknown    = 0,
   issx_truth_strong     = 1,
   issx_truth_acceptable = 2,
   issx_truth_degraded   = 3,
   issx_truth_weak       = 4
  };

enum ISSX_FreshnessClass
  {
   issx_freshness_unknown = 0,
   issx_freshness_fresh   = 1,
   issx_freshness_usable  = 2,
   issx_freshness_aging   = 3,
   issx_freshness_stale   = 4
  };

enum ISSX_RepresentationState
  {
   issx_representation_unknown   = 0,
   issx_representation_canonical = 1,
   issx_representation_variant   = 2,
   issx_representation_uncertain = 3
  };

enum ISSX_ReadabilityState
  {
   issx_readability_unknown    = 0,
   issx_readability_full       = 1,
   issx_readability_unreadable = 2
  };

enum ISSX_UnknownReason
  {
   issx_unknown_reason_unknown = 0,
   issx_unknown_not_applicable = 1,
   issx_unknown_true_unknown   = 2
  };

enum ISSX_PracticalMarketState
  {
   issx_market_state_unknown   = 0,
   issx_market_open_usable     = 1,
   issx_market_open_cautious   = 2,
   issx_market_quote_only      = 3,
   issx_market_closed_idle     = 4,
   issx_market_blocked         = 5
  };

enum ISSX_LeaderBucketType
  {
   issx_leader_bucket_unknown       = 0,
   issx_leader_bucket_theme_bucket  = 1,
   issx_leader_bucket_equity_sector = 2
  };

enum ISSX_TaxonomyActionTaken
  {
   issx_taxonomy_action_unknown     = 0,
   issx_taxonomy_accepted           = 1,
   issx_taxonomy_theme_downgrade    = 2,
   issx_taxonomy_quarantined        = 3,
   issx_taxonomy_manual_review_only = 4
  };

enum ISSX_TradeabilityClass
  {
   issx_tradeability_unknown    = 0,
   issx_tradeability_very_cheap = 1,
   issx_tradeability_cheap      = 2,
   issx_tradeability_moderate   = 3,
   issx_tradeability_expensive  = 4,
   issx_tradeability_blocked    = 5
  };

enum ISSX_CommissionState
  {
   issx_commission_unknown       = 0,
   issx_commission_known_nonzero = 1,
   issx_commission_known_zero    = 2
  };

enum ISSX_SwapState
  {
   issx_swap_unknown       = 0,
   issx_swap_known_nonzero = 1,
   issx_swap_known_zero    = 2
  };

enum ISSX_ContinuityOrigin
  {
   issx_continuity_origin_unknown    = 0,
   issx_continuity_fresh_boot        = 1,
   issx_continuity_resumed_current   = 2,
   issx_continuity_resumed_previous  = 3,
   issx_continuity_resumed_last_good = 4,
   issx_continuity_rebuilt_clean     = 5
  };

enum ISSX_FailureEscalationClass
  {
   issx_failure_escalation_unknown = 0,
   issx_failure_transient_fail     = 1,
   issx_failure_suspended          = 2
  };

enum ISSX_MetricSourceMode
  {
   issx_metric_source_unknown = 0,
   issx_metric_source_direct  = 1,
   issx_metric_source_cached  = 2,
   issx_metric_source_blended = 3
  };

enum ISSX_MetricCompareClass
  {
   issx_metric_compare_unknown       = 0,
   issx_metric_compare_local_only    = 1,
   issx_metric_compare_bucket_safe   = 2,
   issx_metric_compare_frontier_safe = 3,
   issx_metric_compare_global_safe   = 4
  };

enum ISSX_CorrRejectReason
  {
   issx_corr_reject_unknown             = 0,
   issx_corr_reject_not_enough_overlap  = 1,
   issx_corr_reject_stale_history       = 2,
   issx_corr_reject_low_variation       = 3,
   issx_corr_reject_alignment_fail      = 4,
   issx_corr_reject_budget_skipped      = 5,
   issx_corr_reject_duplicate_preempted = 6
  };

enum ISSX_PenaltyBasisKind
  {
   issx_penalty_basis_unknown = 0,
   issx_penalty_family        = 1,
   issx_penalty_session       = 2,
   issx_penalty_returns       = 3,
   issx_penalty_bucket        = 4,
   issx_penalty_mixed         = 5
  };

enum ISSX_PortfolioRoleHint
  {
   issx_role_unknown             = 0,
   issx_role_anchor              = 1,
   issx_role_overlap_risk        = 2,
   issx_role_diversifier         = 3,
   issx_role_fragile_diversifier = 4,
   issx_role_redundant           = 5
  };

enum ISSX_MinuteEpochSource
  {
   issx_minute_epoch_unknown      = 0,
   issx_minute_epoch_trade_server = 1,
   issx_minute_epoch_time_current = 2,
   issx_minute_epoch_time_local   = 3
  };

enum ISSX_SchedulerClockSource
  {
   issx_scheduler_clock_unknown      = 0,
   issx_scheduler_clock_trade_server = 1,
   issx_scheduler_clock_time_current = 2,
   issx_scheduler_clock_time_local   = 3
  };

enum ISSX_FreshnessClockSource
  {
   issx_freshness_clock_unknown      = 0,
   issx_freshness_clock_quote        = 1,
   issx_freshness_clock_trade_server = 2,
   issx_freshness_clock_time_local   = 3
  };

enum ISSX_KernelOverrunClass
  {
   issx_overrun_unknown = 0,
   issx_overrun_none    = 1,
   issx_overrun_soft    = 2,
   issx_overrun_hard    = 3
  };

enum ISSX_HydrationMenuClass
  {
   issx_hydration_unknown_work               = 0,
   issx_hydration_bootstrap_work             = 1,
   issx_hydration_delta_first_work           = 2,
   issx_hydration_backlog_clearing_work      = 3,
   issx_hydration_continuity_preserving_work = 4,
   issx_hydration_publish_critical_work      = 5,
   issx_hydration_optional_enrichment_work   = 6
  };

enum ISSX_QueueFamily
  {
   issx_queue_unknown        = 0,
   issx_queue_discovery      = 1,
   issx_queue_probe          = 2,
   issx_queue_quote_sampling = 3,
   issx_queue_history_warm   = 4,
   issx_queue_history_deep   = 5,
   issx_queue_bucket_rebuild = 6,
   issx_queue_pair           = 7,
   issx_queue_repair         = 8,
   issx_queue_persistence    = 9,
   issx_queue_publish        = 10,
   issx_queue_debug          = 11,
   issx_queue_fastlane       = 12
  };

enum ISSX_InvalidationClass
  {
   issx_invalidation_unknown                      = 0,
   issx_invalidation_quote_freshness              = 1,
   issx_invalidation_tradeability                 = 2,
   issx_invalidation_session_boundary             = 3,
   issx_invalidation_history_sync                 = 4,
   issx_invalidation_frontier_member_change       = 5,
   issx_invalidation_family_representative_change = 6,
   issx_invalidation_policy_change                = 7,
   issx_invalidation_clock_anomaly                = 8,
   issx_invalidation_activity_regime              = 9
  };

enum ISSX_DebugWeakLinkCode
  {
   issx_weak_link_unknown            = 0,
   issx_weak_link_none               = 1,
   issx_weak_link_dependency_block   = 2,
   issx_weak_link_fallback_habit     = 3,
   issx_weak_link_starvation         = 4,
   issx_weak_link_publish_stale      = 5,
   issx_weak_link_rewrite_storm      = 6,
   issx_weak_link_queue_backlog      = 7,
   issx_weak_link_acceptance_failure = 8
  };

enum ISSX_TraceSeverity
  {
   issx_trace_unknown      = 0,
   issx_trace_error        = 1,
   issx_trace_warn         = 2,
   issx_trace_state_change = 3,
   issx_trace_sampled_info = 4
  };

enum ISSX_HudWarningSeverity
  {
   issx_hud_warning_unknown  = 0,
   issx_hud_warning_none     = 1,
   issx_hud_warning_info     = 2,
   issx_hud_warning_warn     = 3,
   issx_hud_warning_error    = 4,
   issx_hud_warning_blocking = 5
  };

#define ISSX_HUDWarningSeverity ISSX_HudWarningSeverity

enum ISSX_HistoryReadinessState
  {
   issx_history_readiness_unknown      = 0,
   issx_history_never_requested        = 1,
   issx_history_requested_sync         = 2,
   issx_history_partial_available      = 3,
   issx_history_syncing                = 4,
   issx_history_compare_unsafe         = 5,
   issx_history_compare_safe_degraded  = 6,
   issx_history_compare_safe_strong    = 7,
   issx_history_degraded_unstable      = 8,
   issx_history_blocked                = 9
  };

enum ISSX_HistoryFinalityClass
  {
   issx_history_finality_unknown    = 0,
   issx_history_finality_stable     = 1,
   issx_history_finality_watch      = 2,
   issx_history_finality_unstable   = 3,
   issx_history_finality_recovering = 4
  };

enum ISSX_HistoryRewriteClass
  {
   issx_rewrite_unknown                    = 0,
   issx_rewrite_none                       = 1,
   issx_rewrite_benign_last_bar_adjustment = 2,
   issx_rewrite_short_tail                 = 3,
   issx_rewrite_structural_gap             = 4,
   issx_rewrite_historical_block           = 5
  };

enum ISSX_DiscoveryLifecycleState
  {
   issx_symbol_state_unknown        = 0,
   issx_symbol_discovered           = 1,
   issx_symbol_selected             = 2,
   issx_symbol_metadata_readable    = 3,
   issx_symbol_quote_observable     = 4,
   issx_symbol_synchronized         = 5,
   issx_symbol_history_addressable  = 6,
   issx_symbol_trade_permitted      = 7,
   issx_symbol_custom_symbol_flag   = 8,
   issx_symbol_property_unavailable = 9,
   issx_symbol_select_failed_temp   = 10,
   issx_symbol_select_failed_perm   = 11
  };

enum ISSX_SessionTruthClass
  {
   issx_session_truth_unknown            = 0,
   issx_session_truth_declared_only      = 1,
   issx_session_truth_observed_supported = 2,
   issx_session_truth_contradictory      = 3
  };

enum ISSX_ContextRegimeClass
  {
   issx_regime_unknown           = 0,
   issx_regime_dormant           = 1,
   issx_regime_waking            = 2,
   issx_regime_active            = 3,
   issx_regime_elevated          = 4,
   issx_regime_dislocated        = 5,
   issx_regime_compressed        = 6,
   issx_regime_normal            = 7,
   issx_regime_expanding         = 8,
   issx_regime_extended          = 9,
   issx_regime_orderly           = 10,
   issx_regime_noisy             = 11,
   issx_regime_fragmented        = 12,
   issx_regime_rotational        = 13,
   issx_regime_poor              = 14,
   issx_regime_acceptable        = 15,
   issx_regime_strong            = 16,
   issx_regime_short_intraday    = 17,
   issx_regime_mixed_intraday    = 18,
   issx_regime_extended_intraday = 19
  };

enum ISSX_WarehouseQuality
  {
   issx_warehouse_quality_unknown  = 0,
   issx_warehouse_quality_thin     = 1,
   issx_warehouse_quality_degraded = 2,
   issx_warehouse_quality_usable   = 3,
   issx_warehouse_quality_strong   = 4
  };

enum ISSX_DiversificationConfidenceClass
  {
   issx_diversification_confidence_unknown  = 0,
   issx_diversification_confidence_low      = 1,
   issx_diversification_confidence_moderate = 2,
   issx_diversification_confidence_high     = 3
  };

enum ISSX_RedundancyRiskClass
  {
   issx_redundancy_risk_unknown  = 0,
   issx_redundancy_risk_low      = 1,
   issx_redundancy_risk_moderate = 2,
   issx_redundancy_risk_high     = 3
  };

enum ISSX_CohortState
  {
   issx_cohort_unknown   = 0,
   issx_cohort_exact     = 1,
   issx_cohort_mixed     = 2,
   issx_cohort_degraded  = 3,
   issx_cohort_blocked   = 4
  };

enum ISSX_CompatibilityAliasState
  {
   issx_alias_state_unknown              = 0,
   issx_alias_state_active_primary       = 1,
   issx_alias_state_bridged_legacy       = 2,
   issx_alias_state_removal_announced    = 3,
   issx_alias_state_removed_by_blueprint = 4
  };

enum ISSX_ExternalFieldStabilityClass
  {
   issx_external_field_stability_unknown             = 0,
   issx_external_field_stability_frozen              = 1,
   issx_external_field_stability_additive_safe       = 2,
   issx_external_field_stability_bridged_deprecated  = 3,
   issx_external_field_stability_internal_only       = 4
  };

enum ISSX_SurfaceKind
  {
   issx_surface_kind_unknown          = 0,
   issx_surface_kind_enum             = 1,
   issx_surface_kind_dto              = 2,
   issx_surface_kind_constant         = 3,
   issx_surface_kind_helper           = 4,
   issx_surface_kind_manifest_field   = 5,
   issx_surface_kind_json_field       = 6,
   issx_surface_kind_debug_key        = 7,
   issx_surface_kind_stage_api_method = 8,
   issx_surface_kind_serializer       = 9
  };

enum ISSX_ThresholdScope
  {
   issx_threshold_scope_unknown       = 0,
   issx_threshold_scope_structural    = 1,
   issx_threshold_scope_semantic      = 2,
   issx_threshold_scope_ranking       = 3,
   issx_threshold_scope_intelligence  = 4,
   issx_threshold_scope_export        = 5,
   issx_threshold_scope_fallback      = 6
  };

enum ISSX_ThresholdBehavior
  {
   issx_threshold_behavior_unknown      = 0,
   issx_threshold_behavior_hard_block   = 1,
   issx_threshold_behavior_soft_penalty = 2
  };

// ============================================================================
// SECTION 03B: LEGACY COMPATIBILITY MACROS
// ============================================================================

#define ISSX_STAGE_SHARED                        issx_stage_shared
#define ISSX_STAGE_EA1                           issx_stage_ea1
#define ISSX_STAGE_EA2                           issx_stage_ea2
#define ISSX_STAGE_EA3                           issx_stage_ea3
#define ISSX_STAGE_EA4                           issx_stage_ea4
#define ISSX_STAGE_EA5                           issx_stage_ea5

#define ISSX_DIRECT                              issx_direct_field
#define ISSX_DERIVED                             issx_derived_field

#define ISSX_AUTH_ACCEPTED                       issx_authority_validated
#define ISSX_AUTH_DERIVED                        issx_authority_derived
#define ISSX_AUTH_DIAGNOSTIC                     issx_authority_advisory

#define ISSX_STALE_STRICT_FRESH                  issx_stale_invalidate_after_threshold
#define ISSX_STALE_USABLE_IF_RECENT              issx_stale_degrade_after_threshold
#define ISSX_STALE_CARRY_WITH_AGE                issx_stale_valid_until_threshold
#define ISSX_STALE_DEGRADED_ALLOWED              issx_stale_degrade_after_threshold
#define ISSX_STALE_DIAGNOSTIC_ONLY               issx_stale_not_time_sensitive

#define ISSX_MISSING_FORBID                      issx_missing_error
#define ISSX_MISSING_ALLOW_NULL                  issx_missing_ignore
#define ISSX_MISSING_ALLOW_MISSING               issx_missing_ignore
#define ISSX_MISSING_UNKNOWN_MEANS_UNKNOWN       issx_missing_unknown

#define issx_acceptance_for_pipeline             issx_acceptance_accepted_for_pipeline
#define issx_acceptance_for_ranking              issx_acceptance_accepted_for_ranking
#define issx_acceptance_for_intelligence         issx_acceptance_accepted_for_intelligence
#define issx_acceptance_for_gpt_export           issx_acceptance_accepted_for_gpt_export
#define issx_acceptance_degraded                 issx_acceptance_accepted_degraded
#define issx_accept_rejected                     issx_acceptance_rejected

#define issx_accept_pipeline                     issx_acceptance_accepted_for_pipeline
#define issx_accept_ranking                      issx_acceptance_accepted_for_ranking
#define issx_accept_intelligence                 issx_acceptance_accepted_for_intelligence
#define issx_accept_gpt_export                   issx_acceptance_accepted_for_gpt_export
#define issx_accept_degraded                     issx_acceptance_accepted_degraded

#define issx_compatibility_exact                 issx_compat_exact
#define issx_compatibility_compatible            issx_compat_consumer_compatible
#define issx_compatibility_compatible_degraded   issx_compat_policy_degraded

#define issx_cohort_state_unknown                issx_cohort_unknown
#define issx_cohort_state_cold                   issx_cohort_unknown
#define issx_cohort_state_warming                issx_cohort_mixed
#define issx_cohort_state_active                 issx_cohort_exact
#define issx_cohort_state_degraded               issx_cohort_degraded
#define issx_cohort_state_blocked                issx_cohort_blocked

#define issx_authority_authoritative_observed    issx_authority_observed
#define issx_authority_authoritative_validated   issx_authority_validated
#define issx_authority_derived_comparative       issx_authority_derived
#define issx_authority_advisory_context          issx_authority_advisory

#define issx_handoff_loaded_internal_current     issx_handoff_internal_current
#define issx_handoff_loaded_internal_previous    issx_handoff_internal_previous
#define issx_handoff_loaded_last_good            issx_handoff_internal_last_good

#define issx_publishability_publishable          issx_publishability_usable
#define issx_publishability_usable_strong        issx_publishability_strong
#define issx_pair_validity_low_overlap           issx_pair_validity_valid_low_overlap
#define issx_pair_validity_high_overlap          issx_pair_validity_valid_high_overlap

// -----------------------------------------------------------------------------
// Legacy compatibility aliases required by downstream stage files still using
// pre-v1.718 shared names.
// -----------------------------------------------------------------------------

// Compatibility-class legacy aliases
#define issx_compatibility_unknown               issx_compat_unknown
#define issx_compatibility_incompatible          issx_compat_incompatible
#define issx_compatibility_same_tick             issx_compat_exact
#define issx_compatibility_current               issx_compat_consumer_compatible
#define issx_compatibility_previous              issx_compat_storage_compatible
#define issx_compatibility_last_good             issx_compat_policy_degraded
#define issx_compatibility_schema_only           issx_compat_schema_only
#define issx_compatibility_policy_degraded       issx_compat_policy_degraded

// Truth-class legacy aliases
#define issx_truth_verified                      issx_truth_strong
#define issx_truth_partial                       issx_truth_acceptable
#define issx_truth_estimated                     issx_truth_degraded

// Freshness-class legacy aliases
#define issx_freshness_recent                    issx_freshness_usable
#define issx_freshness_expired                   issx_freshness_stale

// Weak-link legacy aliases
#define issx_weak_link_rankable_thin             issx_weak_link_queue_backlog
#define issx_weak_link_bucket_depth              issx_weak_link_queue_backlog
#define issx_weak_link_family_collapse           issx_weak_link_dependency_block
#define issx_weak_link_frontier_thin             issx_weak_link_dependency_block
#define issx_weak_link_upstream_missing          issx_weak_link_dependency_block

// ============================================================================
// SECTION 04: DTO TYPES
// ============================================================================

struct ISSX_FieldSemantics
  {
   string               field_name;
   ISSX_DirectOrDerived direct_or_derived;
   ISSX_AuthorityLevel  authority_level;
   ISSX_StalePolicy     stale_policy;
   string               cache_provenance;

   void Reset()
     {
      field_name="";
      direct_or_derived=issx_direct_or_derived_unknown;
      authority_level=issx_authority_unknown;
      stale_policy=issx_stale_policy_unknown;
      cache_provenance="";
     }
  };

struct ISSX_ThresholdDefinition
  {
   string                  threshold_name;
   string                  owner_module;
   string                  semantic_purpose;
   ISSX_ThresholdScope     scope;
   ISSX_ThresholdBehavior  behavior;
   double                  default_value;
   string                  default_value_semantics;
   string                  degradation_behavior;
   bool                    policy_fingerprint_sensitive;
   bool                    persistence_sensitive;
   bool                    external_contract_sensitive;

   void Reset()
     {
      threshold_name="";
      owner_module=ISSX_OWNER_MODULE_NAME_CORE;
      semantic_purpose="";
      scope=issx_threshold_scope_unknown;
      behavior=issx_threshold_behavior_unknown;
      default_value=0.0;
      default_value_semantics="unknown";
      degradation_behavior="";
      policy_fingerprint_sensitive=false;
      persistence_sensitive=false;
      external_contract_sensitive=false;
     }
  };

struct ISSX_OwnerSurfaceInventoryItem
  {
   string                        surface_name;
   ISSX_SurfaceKind              surface_kind;
   string                        owner_module;
   string                        consumer_modules;
   bool                          persisted_flag;
   bool                          exported_flag;
   bool                          debug_only_flag;
   ISSX_CompatibilityAliasState  compatibility_alias_state;
   bool                          policy_sensitive_flag;
   bool                          storage_sensitive_flag;
   bool                          external_contract_sensitive_flag;

   void Reset()
     {
      surface_name="";
      surface_kind=issx_surface_kind_unknown;
      owner_module=ISSX_OWNER_MODULE_NAME_CORE;
      consumer_modules="";
      persisted_flag=false;
      exported_flag=false;
      debug_only_flag=false;
      compatibility_alias_state=issx_alias_state_unknown;
      policy_sensitive_flag=false;
      storage_sensitive_flag=false;
      external_contract_sensitive_flag=false;
     }
  };

struct ISSX_ValidationResult
  {
   bool   ok;
   int    code;
   string message;

   void Reset()
     {
      ok=false;
      code=ISSX_ACCEPTANCE_ERR_INCOMPLETE;
      message="";
     }
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
      stage_id=issx_stage_unknown;
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
   int                        magic;
   ISSX_StageId               stage_id;
   string                     firm_id;
   string                     schema_version;
   int                        schema_epoch;
   int                        storage_version;
   long                       writer_generation;
   long                       sequence_no;
   string                     trio_generation_id;
   int                        record_size_or_payload_length;
   int                        payload_length;
   int                        header_length;
   string                     payload_hash;
   string                     header_hash;
   int                        symbol_count;
   int                        changed_symbol_count;
   long                       minute_id;
   string                     writer_boot_id;
   string                     writer_nonce;
   string                     cohort_fingerprint;
   string                     universe_fingerprint;
   string                     policy_fingerprint;
   int                        fingerprint_algorithm_version;
   int                        contradiction_count;
   ISSX_ContradictionSeverity contradiction_severity_max;
   bool                       degraded_flag;
   int                        fallback_depth_used;

   void Reset()
     {
      magic=ISSX_BINARY_MAGIC;
      stage_id=issx_stage_unknown;
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
      contradiction_severity_max=issx_contradiction_severity_unknown;
      degraded_flag=false;
      fallback_depth_used=0;
     }
  };

struct ISSX_Manifest
  {
   ISSX_StageId               stage_id;
   string                     firm_id;
   string                     schema_version;
   int                        schema_epoch;
   int                        storage_version;
   long                       sequence_no;
   long                       minute_id;
   string                     writer_boot_id;
   string                     writer_nonce;
   long                       writer_generation;
   string                     trio_generation_id;
   string                     payload_hash;
   string                     header_hash;
   int                        payload_length;
   int                        header_length;
   int                        symbol_count;
   int                        changed_symbol_count;
   ISSX_ContentClass          content_class;
   ISSX_PublishReason         publish_reason;
   string                     cohort_fingerprint;
   string                     taxonomy_hash;
   string                     comparator_registry_hash;
   string                     policy_fingerprint;
   int                        fingerprint_algorithm_version;
   string                     universe_fingerprint;
   ISSX_CompatibilityClass    compatibility_class;
   int                        contradiction_count;
   ISSX_ContradictionSeverity contradiction_severity_max;
   bool                       degraded_flag;
   int                        fallback_depth_used;
   int                        accepted_strong_count;
   int                        accepted_degraded_count;
   int                        rejected_count;
   int                        cooldown_count;
   int                        stale_usable_count;
   bool                       projection_partial_success_flag;
   bool                       accepted_promotion_verified;
   bool                       stage_minimum_ready_flag;
   ISSX_PublishabilityState   stage_publishability_state;
   ISSX_HandoffMode           handoff_mode;
   long                       handoff_sequence_no;
   double                     fallback_read_ratio_1h;
   double                     fresh_accept_ratio_1h;
   double                     same_tick_handoff_ratio_1h;
   string                     legend_hash;
   int                        stage_api_version;
   int                        serializer_version;
   string                     writer_codepage;
   string                     source_snapshot_kind;
   ISSX_CompatibilityClass    resume_compatibility_class;
   string                     owner_module_name;
   string                     owner_module_hash;
   int                        owner_module_hash_meaning_version;

   void Reset()
     {
      stage_id=issx_stage_unknown;
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
      content_class=issx_content_unknown;
      publish_reason=issx_publish_reason_unknown;
      cohort_fingerprint="";
      taxonomy_hash="";
      comparator_registry_hash="";
      policy_fingerprint="";
      fingerprint_algorithm_version=ISSX_FINGERPRINT_ALGO_VERSION;
      universe_fingerprint="";
      compatibility_class=issx_compat_unknown;
      contradiction_count=0;
      contradiction_severity_max=issx_contradiction_severity_unknown;
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
      stage_publishability_state=issx_publishability_unknown;
      handoff_mode=issx_handoff_unknown;
      handoff_sequence_no=0;
      fallback_read_ratio_1h=0.0;
      fresh_accept_ratio_1h=0.0;
      same_tick_handoff_ratio_1h=0.0;
      legend_hash="";
      stage_api_version=ISSX_STAGE_API_VERSION;
      serializer_version=ISSX_SERIALIZER_VERSION;
      writer_codepage=ISSX_WRITER_CODEPAGE_UTF8;
      source_snapshot_kind=ISSX_SOURCE_SNAPSHOT_KIND_UNKNOWN;
      resume_compatibility_class=issx_compat_unknown;
      owner_module_name=ISSX_OWNER_MODULE_NAME_CORE;
      owner_module_hash="";
      owner_module_hash_meaning_version=ISSX_OWNER_MODULE_HASH_MEANING_VERSION;
     }
  };

struct ISSX_AcceptanceResult
  {
   bool                       accepted;
   ISSX_AcceptanceType        acceptance_type;
   int                        error_code;
   string                     reason;
   ISSX_CompatibilityClass    compatibility_class;
   int                        compatibility_score;
   int                        accepted_strong_count;
   int                        accepted_degraded_count;
   int                        rejected_count;
   int                        cooldown_count;
   int                        stale_usable_count;
   int                        contradiction_count;
   ISSX_ContradictionSeverity contradiction_severity_max;
   bool                       blocking_contradiction_present;
   string                     contradiction_class_counts;
   string                     highest_blocking_contradiction_class;
   string                     contradiction_repair_state;
   string                     policy_fingerprint;
   bool                       stage_minimum_ready_flag;
   ISSX_PublishabilityState   stage_publishability_state;

   void Reset()
     {
      accepted=false;
      acceptance_type=issx_acceptance_unknown;
      error_code=ISSX_ACCEPTANCE_ERR_INCOMPLETE;
      reason="";
      compatibility_class=issx_compat_unknown;
      compatibility_score=0;
      accepted_strong_count=0;
      accepted_degraded_count=0;
      rejected_count=0;
      cooldown_count=0;
      stale_usable_count=0;
      contradiction_count=0;
      contradiction_severity_max=issx_contradiction_severity_unknown;
      blocking_contradiction_present=false;
      contradiction_class_counts="";
      highest_blocking_contradiction_class="";
      contradiction_repair_state="";
      policy_fingerprint="";
      stage_minimum_ready_flag=false;
      stage_publishability_state=issx_publishability_unknown;
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
      minute_epoch_source=issx_minute_epoch_unknown;
      scheduler_clock_source=issx_scheduler_clock_unknown;
      freshness_clock_source=issx_freshness_clock_unknown;
      timer_gap_ms_now=ISSX_NUMERIC_UNKNOWN_LONG;
      timer_gap_ms_mean=ISSX_NUMERIC_UNKNOWN_DOUBLE;
      timer_gap_ms_p95=ISSX_NUMERIC_UNKNOWN_LONG;
      scheduler_late_by_ms=ISSX_NUMERIC_UNKNOWN_LONG;
      missed_schedule_windows_estimate=ISSX_NUMERIC_UNKNOWN_INT;
      quote_clock_idle_flag=false;
      clock_sanity_score=ISSX_NUMERIC_UNKNOWN_DOUBLE;
      clock_divergence_sec=ISSX_NUMERIC_UNKNOWN_DOUBLE;
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
   long                    stage_last_run_ms[ISSX_STAGE_COUNT];
   long                    stage_last_publish_minute_id[ISSX_STAGE_COUNT];
   bool                    stage_publish_due_flag[ISSX_STAGE_COUNT];
   bool                    stage_minimum_ready_flag[ISSX_STAGE_COUNT];
   double                  stage_backlog_score[ISSX_STAGE_COUNT];
   double                  stage_starvation_score[ISSX_STAGE_COUNT];
   string                  stage_dependency_block_reason[ISSX_STAGE_COUNT];
   string                  stage_resume_key[ISSX_STAGE_COUNT];
   long                    stage_last_successful_service_mono_ms[ISSX_STAGE_COUNT];
   long                    stage_last_attempted_service_mono_ms[ISSX_STAGE_COUNT];
   int                     stage_missed_due_cycles[ISSX_STAGE_COUNT];
   long                    kernel_budget_total_ms;
   long                    kernel_budget_spent_ms;
   long                    kernel_budget_reserved_commit_ms;
   long                    kernel_budget_debt_ms;
   long                    scheduler_late_by_ms;
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
      for(int i=0;i<ISSX_STAGE_COUNT;i++)
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
      scheduler_late_by_ms=ISSX_NUMERIC_UNKNOWN_LONG;
      kernel_forced_service_due_flag=false;
      kernel_degraded_cycle_flag=false;
      kernel_overrun_class=issx_overrun_unknown;
     }
  };

struct ISSX_RootProjectionMeta
  {
   bool   internal_commit_success;
   bool   root_stage_projection_success;
   bool   root_debug_projection_success;
   bool   projection_partial_success_flag;
   int    debug_projection_fail_count;
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
   bool                    ok;
   ISSX_PublishReason      publish_reason;
   ISSX_ContentClass       content_class;
   string                  payload_hash;
   string                  header_hash;
   long                    sequence_no;
   long                    minute_id;
   ISSX_RootProjectionMeta projection;
   string                  message;

   void Reset()
     {
      ok=false;
      publish_reason=issx_publish_reason_unknown;
      content_class=issx_content_unknown;
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
      upstream_compatibility_class=issx_compat_unknown;
      upstream_compatibility_score=0;
      fallback_depth_used=0;
      fallback_penalty_applied=0.0;
      upstream_handoff_mode=issx_handoff_unknown;
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
   ISSX_DebugWeakLinkCode   weak_link_code;
   double                   error_weight;
   double                   degrade_weight;
   double                   dependency_weight;
   double                   fallback_weight;
   string                   dependency_block_reason;
   int                      fallback_depth;
   long                     accepted_sequence_no;
   long                     last_attempted_age_ms;
   long                     last_successful_service_age_ms;
   long                     stage_last_publish_age_sec;
   double                   stage_backlog_score;
   double                   stage_starvation_score;
   string                   phase_id;
   int                      phase_resume_count;
   ISSX_PublishabilityState publishability_state;

   void Reset()
     {
      weak_link_code=issx_weak_link_unknown;
      error_weight=0.0;
      degrade_weight=0.0;
      dependency_weight=0.0;
      fallback_weight=0.0;
      dependency_block_reason="";
      fallback_depth=0;
      accepted_sequence_no=0;
      last_attempted_age_ms=ISSX_NUMERIC_UNKNOWN_LONG;
      last_successful_service_age_ms=ISSX_NUMERIC_UNKNOWN_LONG;
      stage_last_publish_age_sec=ISSX_NUMERIC_UNKNOWN_LONG;
      stage_backlog_score=0.0;
      stage_starvation_score=0.0;
      phase_id="";
      phase_resume_count=0;
      publishability_state=issx_publishability_unknown;
     }
  };

struct ISSX_LockInfo
  {
   string lock_owner_boot_id;
   string lock_owner_instance_guid;
   string lock_owner_terminal_identity;
   long   lock_acquired_time;
   long   lock_heartbeat_time;
   int    stale_after_sec;

   void Reset()
     {
      lock_owner_boot_id="";
      lock_owner_instance_guid="";
      lock_owner_terminal_identity="";
      lock_acquired_time=0;
      lock_heartbeat_time=0;
      stale_after_sec=0;
     }
  };

// ============================================================================
// SECTION 05: VALIDATION HELPERS
// ============================================================================

class ISSX_Validate
  {
private:
   static bool IsKnownSourceSnapshotKind(const string kind)
     {
      return (kind==ISSX_SOURCE_SNAPSHOT_KIND_UNKNOWN ||
              kind==ISSX_SOURCE_SNAPSHOT_KIND_ACCEPTED ||
              kind==ISSX_SOURCE_SNAPSHOT_KIND_PREVIOUS ||
              kind==ISSX_SOURCE_SNAPSHOT_KIND_LAST_GOOD ||
              kind==ISSX_SOURCE_SNAPSHOT_KIND_CANDIDATE ||
              kind==ISSX_SOURCE_SNAPSHOT_KIND_HANDOFF ||
              kind==ISSX_SOURCE_SNAPSHOT_KIND_PUBLIC_ROOT);
     }

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

   static ISSX_ValidationResult ValidateStageId(const ISSX_StageId stage_id)
     {
      if(stage_id==issx_stage_shared)
         return Ok();
      if(stage_id>=issx_stage_ea1 && stage_id<=issx_stage_ea5)
         return Ok();
      return Fail(ISSX_ACCEPTANCE_ERR_STAGE_MISMATCH,"invalid stage id");
     }

   static ISSX_ValidationResult ValidateStageIndex(const int stage_index)
     {
      if(stage_index<0 || stage_index>=ISSX_STAGE_COUNT)
         return Fail(ISSX_ACCEPTANCE_ERR_STAGE_INDEX,"invalid stage index");
      return Ok();
     }

   static ISSX_ValidationResult ValidateBinaryHeader(const ISSX_BinaryHeader &h)
     {
      ISSX_ValidationResult sr=ValidateStageId(h.stage_id);
      if(!sr.ok)
         return sr;
      if(h.magic!=ISSX_BINARY_MAGIC && h.magic!=ISSX_BINARY_MAGIC_ALT)
         return Fail(ISSX_ACCEPTANCE_ERR_HEADER,"invalid binary magic");
      if(StringLen(h.schema_version)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_SCHEMA,"schema version missing");
      if(h.schema_epoch<=0 || h.storage_version<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_SCHEMA,"schema/storage missing");
      if(h.sequence_no<0 || h.writer_generation<0)
         return Fail(ISSX_ACCEPTANCE_ERR_SEQUENCE,"negative generation or sequence");
      if(h.record_size<0 || h.payload_length<0)
         return Fail(ISSX_ACCEPTANCE_ERR_FILESET,"negative record or payload size");
      if(h.payload_length>0 && StringLen(h.payload_hash_or_crc)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_HASH,"payload hash missing");
      if(StringLen(h.header_hash_or_crc)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_HASH,"header hash missing");
      return Ok();
     }

   static ISSX_ValidationResult ValidateStageHeader(const ISSX_StageHeader &h)
     {
      ISSX_ValidationResult sr=ValidateStageId(h.stage_id);
      if(!sr.ok)
         return sr;
      if(h.magic!=ISSX_BINARY_MAGIC && h.magic!=ISSX_BINARY_MAGIC_ALT)
         return Fail(ISSX_ACCEPTANCE_ERR_HEADER,"invalid binary magic");
      if(StringLen(h.firm_id)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_FIRM_MISMATCH,"firm id missing");
      if(StringLen(h.schema_version)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_SCHEMA,"schema version missing");
      if(h.schema_epoch<=0 || h.storage_version<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_SCHEMA,"schema/storage missing");
      if(h.sequence_no<0 || h.writer_generation<0)
         return Fail(ISSX_ACCEPTANCE_ERR_SEQUENCE,"negative generation or sequence");
      if(StringLen(h.trio_generation_id)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_GENERATION,"trio generation missing");
      if(h.payload_length<0 || h.header_length<0 || h.record_size_or_payload_length<0)
         return Fail(ISSX_ACCEPTANCE_ERR_FILESET,"negative lengths");
      if(h.fingerprint_algorithm_version<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_POLICY,"fingerprint algorithm version missing");
      if(h.symbol_count<0 || h.changed_symbol_count<0)
         return Fail(ISSX_ACCEPTANCE_ERR_HEADER,"negative symbol counts");
      if(h.changed_symbol_count>h.symbol_count)
         return Fail(ISSX_ACCEPTANCE_ERR_HEADER,"changed count exceeds symbol count");
      if(h.contradiction_count<0 || h.fallback_depth_used<0)
         return Fail(ISSX_ACCEPTANCE_ERR_HEADER,"negative contradiction or fallback counters");
      if(h.payload_length>0 && StringLen(h.payload_hash)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_HASH,"payload hash missing");
      if(StringLen(h.header_hash)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_HASH,"header hash missing");
      if(StringLen(h.policy_fingerprint)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_POLICY,"policy fingerprint missing");
      if(h.fingerprint_algorithm_version!=ISSX_FINGERPRINT_ALGO_VERSION)
         return Fail(ISSX_ACCEPTANCE_ERR_POLICY,"fingerprint algorithm version mismatch");
      return Ok();
     }

   static ISSX_ValidationResult ValidateManifest(const ISSX_Manifest &m)
     {
      ISSX_ValidationResult sr=ValidateStageId(m.stage_id);
      if(!sr.ok)
         return sr;
      if(StringLen(m.firm_id)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_FIRM_MISMATCH,"manifest firm id missing");
      if(StringLen(m.schema_version)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_SCHEMA,"manifest schema version missing");
      if(m.schema_epoch<=0 || m.storage_version<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_SCHEMA,"manifest schema/storage missing");
      if(m.stage_api_version<=0 || m.serializer_version<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"manifest api/serializer version missing");
      if(m.owner_module_hash_meaning_version<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_OWNER,"owner module hash meaning version missing");
      if(StringLen(m.writer_codepage)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"manifest writer codepage missing");
      if(m.writer_codepage!=ISSX_WRITER_CODEPAGE_UTF8)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"manifest writer codepage must be UTF-8");
      if(StringLen(m.owner_module_name)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_OWNER,"owner module name missing");
      if(StringLen(m.owner_module_hash)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_OWNER,"owner module hash missing");
      if(StringLen(m.trio_generation_id)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_GENERATION,"manifest trio generation missing");
      if(m.payload_length<0 || m.header_length<0)
         return Fail(ISSX_ACCEPTANCE_ERR_FILESET,"manifest negative lengths");
      if(m.symbol_count<0 || m.changed_symbol_count<0)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"manifest negative symbol counts");
      if(m.changed_symbol_count>m.symbol_count)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"manifest changed count exceeds symbol count");
      if(m.accepted_strong_count<0 || m.accepted_degraded_count<0 || m.rejected_count<0 || m.cooldown_count<0 || m.stale_usable_count<0)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"manifest negative acceptance counters");
      if(m.contradiction_count<0 || m.fallback_depth_used<0)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"manifest negative contradiction or fallback counters");
      if(m.payload_length>0 && StringLen(m.payload_hash)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_HASH,"manifest payload hash missing");
      if(StringLen(m.header_hash)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_HASH,"manifest header hash missing");
      if(StringLen(m.policy_fingerprint)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_POLICY,"manifest policy fingerprint missing");
      if(m.fingerprint_algorithm_version<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_POLICY,"manifest fingerprint algorithm version missing");
      if(!IsKnownSourceSnapshotKind(m.source_snapshot_kind))
         return Fail(ISSX_ACCEPTANCE_ERR_SOURCE_KIND,"manifest source snapshot kind invalid");
      return Ok();
     }

   static ISSX_ValidationResult ValidateManifestCoherence(const ISSX_StageHeader &h,const ISSX_Manifest &m)
     {
      if(h.stage_id!=m.stage_id)
         return Fail(ISSX_ACCEPTANCE_ERR_COHERENCE,"header/manifest stage mismatch");
      if(h.firm_id!=m.firm_id)
         return Fail(ISSX_ACCEPTANCE_ERR_COHERENCE,"header/manifest firm mismatch");
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
      if(h.policy_fingerprint!=m.policy_fingerprint)
         return Fail(ISSX_ACCEPTANCE_ERR_POLICY,"policy fingerprint mismatch");
      if(h.universe_fingerprint!=m.universe_fingerprint)
         return Fail(ISSX_ACCEPTANCE_ERR_COHERENCE,"universe fingerprint mismatch");
      if(h.symbol_count!=m.symbol_count || h.changed_symbol_count!=m.changed_symbol_count)
         return Fail(ISSX_ACCEPTANCE_ERR_COHERENCE,"symbol count mismatch");
      return Ok();
     }

   static ISSX_ValidationResult ValidateThresholdDefinition(const ISSX_ThresholdDefinition &d)
     {
      if(StringLen(d.threshold_name)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_THRESHOLD,"threshold name missing");
      if(StringLen(d.owner_module)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_THRESHOLD,"threshold owner missing");
      if(d.scope==issx_threshold_scope_unknown)
         return Fail(ISSX_ACCEPTANCE_ERR_THRESHOLD,"threshold scope missing");
      if(d.behavior==issx_threshold_behavior_unknown)
         return Fail(ISSX_ACCEPTANCE_ERR_THRESHOLD,"threshold behavior missing");
      return Ok();
     }

   static ISSX_ValidationResult ValidateFieldSemantics(const ISSX_FieldSemantics &s)
     {
      if(StringLen(s.field_name)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"field semantics name missing");
      if(s.direct_or_derived==issx_direct_or_derived_unknown)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"field semantics direct_or_derived missing");
      if(s.authority_level==issx_authority_unknown)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"field semantics authority level missing");
      if(s.stale_policy==issx_stale_policy_unknown)
         return Fail(ISSX_ACCEPTANCE_ERR_MANIFEST,"field semantics stale policy missing");
      return Ok();
     }

   static ISSX_ValidationResult ValidateOwnerSurfaceInventoryItem(const ISSX_OwnerSurfaceInventoryItem &i)
     {
      if(StringLen(i.surface_name)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_OWNER,"owner surface name missing");
      if(i.surface_kind==issx_surface_kind_unknown)
         return Fail(ISSX_ACCEPTANCE_ERR_OWNER,"owner surface kind missing");
      if(StringLen(i.owner_module)<=0)
         return Fail(ISSX_ACCEPTANCE_ERR_OWNER,"owner surface module missing");
      if(i.compatibility_alias_state==issx_alias_state_unknown)
         return Fail(ISSX_ACCEPTANCE_ERR_ALIAS_DRIFT,"owner surface alias state missing");
      return Ok();
     }
  };

// ============================================================================
// SECTION 06: UTILITY HELPERS
// ============================================================================

class ISSX_Util
  {
private:
   static void SwapStrings(string &a,string &b)
     {
      string t=a;
      a=b;
      b=t;
     }

public:
   static bool IsEmpty(const string s)
     {
      return (StringLen(s)==0);
     }

   static string BoolToString(const bool v)
     {
      return (v ? "true" : "false");
     }

   static string IntToStringX(const int v)
     {
      return IntegerToString(v);
     }

   static string LongToStringX(const long v)
     {
      return StringFormat("%I64d",v);
     }

   static string UIntToStringX(const uint v)
     {
      return StringFormat("%u",v);
     }

   static string ULongToStringX(const ulong v)
     {
      return StringFormat("%I64u",v);
     }

   static string DoubleToStringX(const double v,const int digits=ISSX_JSON_DOUBLE_DIGITS_DEFAULT)
     {
      return DoubleToString(v,digits);
     }

   static string SafeString(const string s)
     {
      return s;
     }

   static string Lower(const string s)
     {
      string t=s;
      StringToLower(t);
      return t;
     }

   static string Upper(const string s)
     {
      string t=s;
      StringToUpper(t);
      return t;
     }

   static string NormalizeNullLike(const string s)
     {
      string t=Lower(s);
      if(t=="null" || t=="none" || t=="n/a" || t=="na")
         return "";
      return s;
     }

   static string NormalizeContractString(const string s)
     {
      return Trim(NormalizeNullLike(s));
     }

   static string NormalizeFieldKey(const string s)
     {
      return Lower(Trim(NormalizeNullLike(s)));
     }

   static string Trim(const string s)
     {
      string t=s;
      StringTrimLeft(t);
      StringTrimRight(t);
      return t;
     }

   static string TrimRightSep(const string s)
     {
      int len=StringLen(s);
      if(len<=0)
         return s;
      if(StringSubstr(s,len-1,1)==ISSX_PATH_SEP)
         return StringSubstr(s,0,len-1);
      return s;
     }

   static string TrimLeftSep(const string s)
     {
      int len=StringLen(s);
      if(len<=0)
         return s;
      if(StringSubstr(s,0,1)==ISSX_PATH_SEP)
         return StringSubstr(s,1);
      return s;
     }

   static string JoinPath(const string a,const string b)
     {
      if(IsEmpty(a))
         return b;
      if(IsEmpty(b))
         return a;
      string aa=TrimRightSep(a);
      string bb=TrimLeftSep(b);
      return aa+ISSX_PATH_SEP+bb;
     }

   static string JoinPath3(const string a,const string b,const string c)
     {
      return JoinPath(JoinPath(a,b),c);
     }

   static string JoinPath4(const string a,const string b,const string c,const string d)
     {
      return JoinPath(JoinPath3(a,b,c),d);
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

   static int SafeArrayIndex(const int index,const int size)
     {
      if(size<=0 || index<0 || index>=size)
         return -1;
      return index;
     }

   static void SortStringsInPlace(string &items[])
     {
      int n=ArraySize(items);
      if(n<=1)
         return;

      for(int i=0;i<n-1;i++)
        {
         for(int j=i+1;j<n;j++)
           {
            if(items[j]<items[i])
               SwapStrings(items[i],items[j]);
           }
        }
     }

   static void CopyStringArray(const string &src[],string &dst[])
     {
      int n=ArraySize(src);
      ArrayResize(dst,n);
      for(int i=0;i<n;i++)
         dst[i]=src[i];
     }

   static string CanonicalJoin(const string &items[])
     {
      string out="";
      int n=ArraySize(items);
      for(int i=0;i<n;i++)
        {
         if(i>0)
            out+="|";
         out+=NormalizeNullLike(items[i]);
        }
      return out;
     }

   static string CanonicalJoinSorted(const string &items[])
     {
      string copy[];
      CopyStringArray(items,copy);
      SortStringsInPlace(copy);
      return CanonicalJoin(copy);
     }
  };

string LongToString(const long v)
  {
   return ISSX_Util::LongToStringX(v);
  }

string ULongToString(const ulong v)
  {
   return ISSX_Util::ULongToStringX(v);
  }

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

   static ISSX_MinuteEpochSource BestMinuteEpochSource()
     {
      datetime t=TimeTradeServer();
      if(t>0)
         return issx_minute_epoch_trade_server;
      t=TimeCurrent();
      if(t>0)
         return issx_minute_epoch_time_current;
      return issx_minute_epoch_time_local;
     }

   static ISSX_SchedulerClockSource BestSchedulerClockSource()
     {
      datetime t=TimeTradeServer();
      if(t>0)
         return issx_scheduler_clock_trade_server;
      t=TimeCurrent();
      if(t>0)
         return issx_scheduler_clock_time_current;
      return issx_scheduler_clock_time_local;
     }

   static ISSX_FreshnessClockSource BestFreshnessClockSource()
     {
      datetime t=TimeCurrent();
      if(t>0)
         return issx_freshness_clock_quote;
      t=TimeTradeServer();
      if(t>0)
         return issx_freshness_clock_trade_server;
      return issx_freshness_clock_time_local;
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

   static long SecondsAge(const datetime ts,const datetime now_ts=0)
     {
      datetime n=now_ts;
      if(n<=0)
         n=BestFreshnessClock();
      if(ts<=0 || n<=0)
         return -1;
      return (long)(n-ts);
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
      int raw_n=StringToCharArray(s,bytes,0,WHOLE_ARRAY,CP_UTF8);
      int n=raw_n;
      if(n>0 && bytes[n-1]==0)
         n--;

      const ulong fnv_offset=(ulong)0xCBF29CE484222325;
      const ulong fnv_prime =(ulong)0x100000001B3;
      ulong h=fnv_offset;

      for(int i=0;i<n;i++)
        {
         h ^= (ulong)bytes[i];
         h *= fnv_prime;
        }
      return h;
     }

public:
   static string ULongToHex(const ulong v_in)
     {
      const string hex_digits="0123456789abcdef";
      ulong v=v_in;
      string out="";
      for(int i=0;i<16;i++)
        {
         int nib=(int)(v & 0x0F);
         out=StringSubstr(hex_digits,nib,1)+out;
         v>>=4;
        }
      return out;
     }

   static string HashStringHex(const string s)
     {
      return ULongToHex(FNV1a64(s));
     }

   static string HashJoin2(const string a,const string b)
     {
      return HashStringHex(a+"|"+b);
     }

   static string HashJoin3(const string a,const string b,const string c)
     {
      return HashStringHex(a+"|"+b+"|"+c);
     }

   static string HashJoin4(const string a,const string b,const string c,const string d)
     {
      return HashStringHex(a+"|"+b+"|"+c+"|"+d);
     }

   static string HashCanonicalStrings(const string &items[])
     {
      return HashStringHex(ISSX_Util::CanonicalJoin(items));
     }

   static string HashCanonicalStringsSorted(const string &items[])
     {
      return HashStringHex(ISSX_Util::CanonicalJoinSorted(items));
     }

   static string HashCanonicalKeyValue(const string key,const string value)
     {
      return HashStringHex(ISSX_Util::NormalizeContractString(key)+"="+ISSX_Util::NormalizeContractString(value));
     }

   static string CoreOwnerModuleHash()
     {
      return HashJoin4(ISSX_OWNER_MODULE_NAME_CORE,ISSX_ENGINE_VERSION,ISSX_SCHEMA_VERSION,ISSX_WRITER_CODEPAGE_UTF8);
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

public:
   ISSX_JsonWriter()
     {
      Reset();
     }

   static string Escape(const string s)
     {
      return ISSX_Util::EscapeJson(s);
     }

   static string NameStringKV(const string name,const string value)
     {
      return "\"" + ISSX_Util::EscapeJson(name) + "\":\"" + ISSX_Util::EscapeJson(value) + "\"";
     }

   static string NameIntKV(const string name,const long value)
     {
      return "\"" + ISSX_Util::EscapeJson(name) + "\":" + ISSX_Util::LongToStringX(value);
     }

   static string NameLongKV(const string name,const long value)
     {
      return NameIntKV(name,value);
     }

   static string NameDoubleKV(const string name,const double value,const int digits=ISSX_JSON_DOUBLE_DIGITS_DEFAULT)
     {
      return "\"" + ISSX_Util::EscapeJson(name) + "\":" + ISSX_Util::DoubleToStringX(value,digits);
     }

   static string NameBoolKV(const string name,const bool value)
     {
      return "\"" + ISSX_Util::EscapeJson(name) + "\":" + (value ? "true" : "false");
     }

   static string NameNullKV(const string name)
     {
      return "\"" + ISSX_Util::EscapeJson(name) + "\":null";
     }

   void Reset()
     {
      m_text="";
      m_depth=0;
      for(int i=0;i<ISSX_MAX_JSON_DEPTH;i++)
         m_need_comma[i]=false;
     }

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

   void BeginNamedObject(const string name)
     {
      WriteNamePrefix(name);
      m_text+="{";
      PushContext();
     }

   void BeginObjectNamed(const string name)
     {
      BeginNamedObject(name);
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

   void BeginNamedArray(const string name)
     {
      WriteNamePrefix(name);
      m_text+="[";
      PushContext();
     }

   void BeginArrayNamed(const string name)
     {
      BeginNamedArray(name);
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

   void NameLong(const string name,const long value)
     {
      NameInt(name,value);
     }

   void NameUInt(const string name,const ulong value)
     {
      WriteNamePrefix(name);
      m_text+=ISSX_Util::ULongToStringX(value);
     }

   void NameDouble(const string name,const double value,const int digits=ISSX_JSON_DOUBLE_DIGITS_DEFAULT)
     {
      WriteNamePrefix(name);
      m_text+=ISSX_Util::DoubleToStringX(value,digits);
     }

   void NameBool(const string name,const bool value)
     {
      WriteNamePrefix(name);
      m_text+=(value ? "true" : "false");
     }

   void NameNull(const string name)
     {
      WriteNamePrefix(name);
      m_text+="null";
     }

   void NameEnumString(const string name,const string enum_value)
     {
      NameString(name,enum_value);
     }

   void WriteString(const string name,const string value)
     {
      NameString(name,value);
     }

   void WriteLong(const string name,const long value)
     {
      NameInt(name,value);
     }

   void WriteInt(const string name,const int value)
     {
      NameInt(name,(long)value);
     }

   void WriteDouble(const string name,const double value,const int digits=ISSX_JSON_DOUBLE_DIGITS_DEFAULT)
     {
      NameDouble(name,value,digits);
     }

   void WriteBool(const string name,const bool value)
     {
      NameBool(name,value);
     }

   void WriteNull(const string name)
     {
      NameNull(name);
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

   void ValueDouble(const double value,const int digits=ISSX_JSON_DOUBLE_DIGITS_DEFAULT)
     {
      WriteCommaIfNeeded();
      m_text+=ISSX_Util::DoubleToStringX(value,digits);
     }

   void ValueBool(const bool value)
     {
      WriteCommaIfNeeded();
      m_text+=(value ? "true" : "false");
     }

   void ValueNull()
     {
      WriteCommaIfNeeded();
      m_text+="null";
     }

   string KeyValue(const string key,const string value,const bool quoted=true)
     {
      if(quoted)
         return "\"" + ISSX_Util::EscapeJson(key) + "\":\"" + ISSX_Util::EscapeJson(value) + "\"";
      return "\"" + ISSX_Util::EscapeJson(key) + "\":" + value;
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
   static bool IsKernelStage(const ISSX_StageId stage_id)
     {
      return (stage_id>=issx_stage_ea1 && stage_id<=issx_stage_ea5);
     }

   static int StageCount()
     {
      return ISSX_STAGE_COUNT;
     }

   static int ToStageIndex(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return 0;
         case issx_stage_ea2: return 1;
         case issx_stage_ea3: return 2;
         case issx_stage_ea4: return 3;
         case issx_stage_ea5: return 4;
         default:             return -1;
        }
     }

   static ISSX_StageId FromStageIndex(const int index)
     {
      switch(index)
        {
         case 0: return issx_stage_ea1;
         case 1: return issx_stage_ea2;
         case 2: return issx_stage_ea3;
         case 3: return issx_stage_ea4;
         case 4: return issx_stage_ea5;
         default: return issx_stage_unknown;
        }
     }

   static string ToMachineId(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1:    return "ea1";
         case issx_stage_ea2:    return "ea2";
         case issx_stage_ea3:    return "ea3";
         case issx_stage_ea4:    return "ea4";
         case issx_stage_ea5:    return "ea5";
         case issx_stage_shared: return "shared";
         default:                return "unknown";
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
         default:             return "UnknownCore";
        }
     }

   static string PersistenceFolder(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1:    return ISSX_DIR_PERSISTENCE_EA1;
         case issx_stage_ea2:    return ISSX_DIR_PERSISTENCE_EA2;
         case issx_stage_ea3:    return ISSX_DIR_PERSISTENCE_EA3;
         case issx_stage_ea4:    return ISSX_DIR_PERSISTENCE_EA4;
         case issx_stage_ea5:    return ISSX_DIR_PERSISTENCE_EA5;
         case issx_stage_shared: return ISSX_DIR_PERSISTENCE_SHARED;
         default:                return "";
        }
     }

   static string StageFolder(const ISSX_StageId stage_id)
     {
      return PersistenceFolder(stage_id);
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
         default:             return ISSX_ROOT_DEBUG;
        }
     }
  };

string StageFolder(const ISSX_StageId stage_id)
  {
   return ISSX_Stage::StageFolder(stage_id);
  }

int StageIdToIndex(const ISSX_StageId stage_id)
  {
   return ISSX_Stage::ToStageIndex(stage_id);
  }

ISSX_StageId StageIndexToId(const int index)
  {
   return ISSX_Stage::FromStageIndex(index);
  }

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

   static string SchemaFile(const string firm_id,const string filename)
     {
      return ISSX_Util::JoinPath(ISSX_Util::JoinPath(RootFirmBase(firm_id),ISSX_DIR_SCHEMAS),filename);
     }

   static string HudFile(const string firm_id,const string filename)
     {
      return ISSX_Util::JoinPath(ISSX_Util::JoinPath(RootFirmBase(firm_id),ISSX_DIR_HUD),filename);
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
      case issx_stage_ea1:    return "ea1";
      case issx_stage_ea2:    return "ea2";
      case issx_stage_ea3:    return "ea3";
      case issx_stage_ea4:    return "ea4";
      case issx_stage_ea5:    return "ea5";
      default:                return "unknown";
     }
  }

string ISSX_AcceptanceTypeToString(const ISSX_AcceptanceType v)
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

string ISSX_PublishabilityStateToString(const ISSX_PublishabilityState v)
  {
   switch(v)
     {
      case issx_publishability_not_ready:       return "not_ready";
      case issx_publishability_blocked:         return "blocked";
      case issx_publishability_warmup:          return "warmup";
      case issx_publishability_usable_degraded: return "usable_degraded";
      case issx_publishability_usable:          return "usable";
      case issx_publishability_strong:          return "strong";
      default:                                  return "unknown";
     }
  }

string ISSX_CompatibilityClassToString(const ISSX_CompatibilityClass v)
  {
   switch(v)
     {
      case issx_compat_incompatible:        return "incompatible";
      case issx_compat_schema_only:         return "schema_only";
      case issx_compat_storage_compatible:  return "storage_compatible";
      case issx_compat_policy_degraded:     return "policy_degraded";
      case issx_compat_consumer_compatible: return "consumer_compatible";
      case issx_compat_exact:               return "exact";
      default:                              return "unknown";
     }
  }

string ISSX_ContentClassToString(const ISSX_ContentClass v)
  {
   switch(v)
     {
      case issx_content_empty:   return "empty";
      case issx_content_partial: return "partial";
      case issx_content_usable:  return "usable";
      case issx_content_strong:  return "strong";
      default:                   return "unknown";
     }
  }

string ISSX_PublishReasonToString(const ISSX_PublishReason v)
  {
   switch(v)
     {
      case issx_publish_bootstrap:                return "bootstrap";
      case issx_publish_scheduled:                return "scheduled";
      case issx_publish_recovery:                 return "recovery";
      case issx_publish_material_change:          return "material_change";
      case issx_publish_degradation_transition:   return "degradation_transition";
      case issx_publish_contradiction_transition: return "contradiction_transition";
      case issx_publish_heartbeat:                return "heartbeat";
      case issx_publish_manual:                   return "manual";
      default:                                    return "unknown";
     }
  }

string ISSX_HandoffModeToString(const ISSX_HandoffMode v)
  {
   switch(v)
     {
      case issx_handoff_none:               return "none";
      case issx_handoff_same_tick_accepted: return "same_tick_accepted";
      case issx_handoff_internal_current:   return "internal_current";
      case issx_handoff_internal_previous:  return "internal_previous";
      case issx_handoff_internal_last_good: return "internal_last_good";
      case issx_handoff_public_projection:  return "public_projection";
      default:                              return "unknown";
     }
  }

string ISSX_RankabilityLaneToString(const ISSX_RankabilityLane v)
  {
   switch(v)
     {
      case issx_rankability_strong:      return "strong";
      case issx_rankability_usable:      return "usable";
      case issx_rankability_exploratory: return "exploratory";
      case issx_rankability_blocked:     return "blocked";
      default:                           return "unknown";
     }
  }

string ISSX_PairValidityClassToString(const ISSX_PairValidityClass v)
  {
   switch(v)
     {
      case issx_pair_validity_unknown_overlap:     return "unknown_overlap";
      case issx_pair_validity_valid_low_overlap:   return "valid_low_overlap";
      case issx_pair_validity_valid_high_overlap:  return "valid_high_overlap";
      case issx_pair_validity_provisional_overlap: return "provisional_overlap";
      case issx_pair_validity_blocked_overlap:     return "blocked_overlap";
      default:                                     return "unknown";
     }
  }

string ISSX_PairSampleAlignmentClassToString(const ISSX_PairSampleAlignmentClass v)
  {
   switch(v)
     {
      case issx_pair_alignment_poor:   return "poor";
      case issx_pair_alignment_usable: return "usable";
      case issx_pair_alignment_strong: return "strong";
      default:                         return "unknown";
     }
  }

string ISSX_PairWindowFreshnessClassToString(const ISSX_PairWindowFreshnessClass v)
  {
   switch(v)
     {
      case issx_pair_window_freshness_stale:  return "stale";
      case issx_pair_window_freshness_usable: return "usable";
      case issx_pair_window_freshness_fresh:  return "fresh";
      default:                                return "unknown";
     }
  }

string ISSX_DebugWeakLinkCodeToString(const ISSX_DebugWeakLinkCode v)
  {
   switch(v)
     {
      case issx_weak_link_none:               return "none";
      case issx_weak_link_dependency_block:   return "dependency_block";
      case issx_weak_link_fallback_habit:     return "fallback_habit";
      case issx_weak_link_starvation:         return "starvation";
      case issx_weak_link_publish_stale:      return "publish_stale";
      case issx_weak_link_rewrite_storm:      return "rewrite_storm";
      case issx_weak_link_queue_backlog:      return "queue_backlog";
      case issx_weak_link_acceptance_failure: return "acceptance_failure";
      default:                                return "unknown";
     }
  }

string ISSX_InvalidationClassToString(const ISSX_InvalidationClass v)
  {
   switch(v)
     {
      case issx_invalidation_quote_freshness:              return "quote_freshness_invalidation";
      case issx_invalidation_tradeability:                 return "tradeability_invalidation";
      case issx_invalidation_session_boundary:             return "session_boundary_invalidation";
      case issx_invalidation_history_sync:                 return "history_sync_invalidation";
      case issx_invalidation_frontier_member_change:       return "frontier_member_change";
      case issx_invalidation_family_representative_change: return "family_representative_change";
      case issx_invalidation_policy_change:                return "policy_change_invalidation";
      case issx_invalidation_clock_anomaly:                return "clock_anomaly_invalidation";
      case issx_invalidation_activity_regime:              return "activity_regime_invalidation";
      default:                                             return "unknown";
     }
  }

string ISSX_QueueFamilyToString(const ISSX_QueueFamily v)
  {
   switch(v)
     {
      case issx_queue_discovery:      return "discovery";
      case issx_queue_probe:          return "probe";
      case issx_queue_quote_sampling: return "quote_sampling";
      case issx_queue_history_warm:   return "history_warm";
      case issx_queue_history_deep:   return "history_deep";
      case issx_queue_bucket_rebuild: return "bucket_rebuild";
      case issx_queue_pair:           return "pair";
      case issx_queue_repair:         return "repair";
      case issx_queue_persistence:    return "persistence";
      case issx_queue_publish:        return "publish";
      case issx_queue_debug:          return "debug";
      case issx_queue_fastlane:       return "fastlane";
      default:                        return "unknown";
     }
  }

string ISSX_HistoryReadinessStateToString(const ISSX_HistoryReadinessState v)
  {
   switch(v)
     {
      case issx_history_never_requested:       return "never_requested";
      case issx_history_requested_sync:        return "requested_sync";
      case issx_history_partial_available:     return "partial_available";
      case issx_history_syncing:               return "syncing";
      case issx_history_compare_unsafe:        return "compare_unsafe";
      case issx_history_compare_safe_degraded: return "compare_safe_degraded";
      case issx_history_compare_safe_strong:   return "compare_safe_strong";
      case issx_history_degraded_unstable:     return "degraded_unstable";
      case issx_history_blocked:               return "blocked";
      default:                                 return "unknown";
     }
  }

string ISSX_HistoryFinalityClassToString(const ISSX_HistoryFinalityClass v)
  {
   switch(v)
     {
      case issx_history_finality_stable:     return "stable";
      case issx_history_finality_watch:      return "watch";
      case issx_history_finality_unstable:   return "unstable";
      case issx_history_finality_recovering: return "recovering";
      default:                               return "unknown";
     }
  }

string ISSX_HistoryRewriteClassToString(const ISSX_HistoryRewriteClass v)
  {
   switch(v)
     {
      case issx_rewrite_none:                        return "none";
      case issx_rewrite_benign_last_bar_adjustment: return "benign_last_bar_adjustment";
      case issx_rewrite_short_tail:                  return "short_tail_rewrite";
      case issx_rewrite_structural_gap:              return "structural_gap_rewrite";
      case issx_rewrite_historical_block:            return "historical_block_rewrite";
      default:                                       return "unknown";
     }
  }

string ISSX_TraceSeverityToString(const ISSX_TraceSeverity v)
  {
   switch(v)
     {
      case issx_trace_error:        return "error";
      case issx_trace_warn:         return "warn";
      case issx_trace_state_change: return "state_change";
      case issx_trace_sampled_info: return "sampled_info";
      default:                      return "unknown";
     }
  }

string ISSX_HudWarningSeverityToString(const ISSX_HudWarningSeverity v)
  {
   switch(v)
     {
      case issx_hud_warning_none:     return "none";
      case issx_hud_warning_info:     return "info";
      case issx_hud_warning_warn:     return "warn";
      case issx_hud_warning_error:    return "error";
      case issx_hud_warning_blocking: return "blocking";
      default:                        return "unknown";
     }
  }

string ISSX_CompatibilityAliasStateToString(const ISSX_CompatibilityAliasState v)
  {
   switch(v)
     {
      case issx_alias_state_active_primary:       return "active_primary";
      case issx_alias_state_bridged_legacy:       return "bridged_legacy";
      case issx_alias_state_removal_announced:    return "removal_announced";
      case issx_alias_state_removed_by_blueprint: return "removed_by_blueprint";
      default:                                    return "unknown";
     }
  }

string ISSX_ExternalFieldStabilityClassToString(const ISSX_ExternalFieldStabilityClass v)
  {
   switch(v)
     {
      case issx_external_field_stability_frozen:             return "frozen";
      case issx_external_field_stability_additive_safe:      return "additive_safe";
      case issx_external_field_stability_bridged_deprecated: return "bridged_deprecated";
      case issx_external_field_stability_internal_only:      return "internal_only";
      default:                                               return "unknown";
     }
  }

string ISSX_SurfaceKindToString(const ISSX_SurfaceKind v)
  {
   switch(v)
     {
      case issx_surface_kind_enum:             return "enum";
      case issx_surface_kind_dto:              return "DTO";
      case issx_surface_kind_constant:         return "constant";
      case issx_surface_kind_helper:           return "helper";
      case issx_surface_kind_manifest_field:   return "manifest_field";
      case issx_surface_kind_json_field:       return "json_field";
      case issx_surface_kind_debug_key:        return "debug_key";
      case issx_surface_kind_stage_api_method: return "stage_api_method";
      case issx_surface_kind_serializer:       return "serializer_surface";
      default:                                 return "unknown";
     }
  }

string ISSX_ThresholdScopeToString(const ISSX_ThresholdScope v)
  {
   switch(v)
     {
      case issx_threshold_scope_structural:   return "structural";
      case issx_threshold_scope_semantic:     return "semantic";
      case issx_threshold_scope_ranking:      return "ranking";
      case issx_threshold_scope_intelligence: return "intelligence";
      case issx_threshold_scope_export:       return "export";
      case issx_threshold_scope_fallback:     return "fallback";
      default:                                return "unknown";
     }
  }

string ISSX_ThresholdBehaviorToString(const ISSX_ThresholdBehavior v)
  {
   switch(v)
     {
      case issx_threshold_behavior_hard_block:   return "hard_block";
      case issx_threshold_behavior_soft_penalty: return "soft_penalty";
      default:                                   return "unknown";
     }
  }

// ============================================================================
// SECTION 12: COMPATIBILITY WRAPPERS
// ============================================================================

class ISSX_Json
  {
public:
   static string KV(const string key,const string value,const bool quoted=true)
     {
      if(quoted)
         return "\"" + ISSX_Util::EscapeJson(key) + "\":\"" + ISSX_Util::EscapeJson(value) + "\"";
      return "\"" + ISSX_Util::EscapeJson(key) + "\":" + value;
     }
  };

class ISSX_Enum
  {
public:
   static bool StageIsValid(const ISSX_StageId v)
     {
      return (v==issx_stage_shared) || (v>=issx_stage_ea1 && v<=issx_stage_ea5);
     }

   static string StageToString(const ISSX_StageId v)
     {
      return ISSX_StageIdToString(v);
     }

   static string AuthorityLevelToString(const ISSX_AuthorityLevel v)
     {
      switch(v)
        {
         case issx_authority_observed:  return "authoritative_observed";
         case issx_authority_validated: return "authoritative_validated";
         case issx_authority_derived:   return "derived_comparative";
         case issx_authority_advisory:  return "advisory_context";
         case issx_authority_degraded:  return "degraded";
         default:                       return "unknown";
        }
     }

   static string MissingPolicyToString(const ISSX_MissingPolicy v)
     {
      switch(v)
        {
         case issx_missing_ignore:  return "ignore";
         case issx_missing_default: return "default";
         case issx_missing_error:   return "error";
         default:                   return "unknown";
        }
     }

   static string StalePolicyToString(const ISSX_StalePolicy v)
     {
      switch(v)
        {
         case issx_stale_valid_until_threshold:      return "valid_until_threshold";
         case issx_stale_degrade_after_threshold:    return "degrade_after_threshold";
         case issx_stale_invalidate_after_threshold: return "invalidate_after_threshold";
         case issx_stale_not_time_sensitive:         return "not_time_sensitive";
         default:                                    return "unknown";
        }
     }

   static string WeakLinkCodeToString(const ISSX_DebugWeakLinkCode v)
     {
      return ISSX_DebugWeakLinkCodeToString(v);
     }
  };

class ISSX_OperatorSurface
  {
public:
   static string StageAlias(const ISSX_StageId stage_id)
     {
      switch(stage_id)
        {
         case issx_stage_ea1: return "Market";
         case issx_stage_ea2: return "History";
         case issx_stage_ea3: return "Selection";
         case issx_stage_ea4: return "Correlation";
         case issx_stage_ea5: return "Contracts";
         default:             return "Unknown";
        }
     }

   static string SanitizeServerName(const string raw_server)
     {
      string s=ISSX_Util::Trim(raw_server);
      if(ISSX_Util::IsEmpty(s))
         s="Unknown_Server";

      StringReplace(s," ","_");
      StringReplace(s,"-","_");
      StringReplace(s,"/","_");
      StringReplace(s,"\\","_");
      StringReplace(s,":","_");
      StringReplace(s,"*","_");
      StringReplace(s,"?","_");
      StringReplace(s,"\"","_");
      StringReplace(s,"<","_");
      StringReplace(s,">","_");
      StringReplace(s,"|","_");

      while(StringFind(s,"__")>=0)
         StringReplace(s,"__","_");
      if(StringLen(s)>0 && StringSubstr(s,0,1)=="_")
         s=StringSubstr(s,1);
      if(StringLen(s)>0 && StringSubstr(s,StringLen(s)-1,1)=="_")
         s=StringSubstr(s,0,StringLen(s)-1);
      if(ISSX_Util::IsEmpty(s))
         s="Unknown_Server";
      return s;
     }

   static string OperatorFileName(const ISSX_StageId stage_id,const string server_name,const string ext_with_dot)
     {
      return StageAlias(stage_id)+"_"+SanitizeServerName(server_name)+ext_with_dot;
     }
  };



string ISSX_CoreDiagTag()
  {
   return "core_diag_v174f";
  }


string ISSX_CoreDebugSignature()
  {
   return ISSX_CoreDiagTag();
  }

#endif // __ISSX_CORE_MQH__
