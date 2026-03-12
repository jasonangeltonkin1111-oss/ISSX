
#ifndef __ISSX_MARKET_ENGINE_MQH__
#define __ISSX_MARKET_ENGINE_MQH__
#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>

// ============================================================================
// ISSX MARKET ENGINE v1.7.0
// EA1 shared engine for MarketStateCore.
//
// OWNERSHIP IN THIS MODULE
// - broker universe discovery
// - identity normalization
// - family / alias / representative resolution
// - classification orchestration
// - sector/theme/taxonomy heuristics (integrated here by blueprint rule)
// - session model
// - market model
// - cost model
// - friction baseline vs shock logic
// - symbol lifecycle state
// - rankability gate
// - changed-symbol frontier hints for downstream hydration
//
// BLUEPRINT ALIGNMENT
// - thin wrapper compatible
// - MT5-only upstream truth
// - sector engine absorbed here (no separate taxonomy module)
// - delta-first refresh model
// - bounded minute-cadence execution
// - no directional outputs
// ============================================================================

#define ISSX_MARKET_ENGINE_MODULE_VERSION "1.7.0"

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
   issx_ea1_lifecycle_suspended
  };

enum ISSX_EA1_SessionPhase
  {
   issx_ea1_session_unknown = 0,
   issx_ea1_session_preopen,
   issx_ea1_session_open,
   issx_ea1_session_transition,
   issx_ea1_session_closed
  };

enum ISSX_EA1_RepresentationReason
  {
   issx_rep_reason_none = 0,
   issx_rep_reason_exact_symbol,
   issx_rep_reason_prefix_suffix_trimmed,
   issx_rep_reason_contract_suffix_removed,
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

// ============================================================================
// SECTION 03: PER-SYMBOL BLOCKS
// ============================================================================
struct ISSX_EA1_RawBrokerObservation
  {
   string  symbol_raw;
   string  path;
   string  description;
   long    trade_mode;
   long    calc_mode;
   int     digits;
   double  point;
   double  tick_size;
   double  tick_value;
   double  tick_value_profit;
   double  tick_value_loss;
   double  contract_size;
   double  volume_min;
   double  volume_step;
   double  volume_max;
   int     stops_level;
   int     freeze_level;
   string  margin_currency;
   string  profit_currency;
   string  base_currency;
   string  quote_currency;
   bool    session_property_availability;
   bool    selection_state;
   bool    sync_state;
   bool    metadata_readable;
   bool    quote_observable;
   bool    synchronized_flag;
   bool    history_addressable;
   bool    trade_permitted;
   bool    custom_symbol_flag;
   bool    property_unavailable_flag;
   bool    select_failed_temp;
   bool    select_failed_perm;
   string  symbol_discovery_state;
   string  symbol_selection_state;
   string  symbol_synchronization_state;
   string  property_read_status;
   int     property_read_fail_mask;
   MqlTick quote_tick_snapshot;
   datetime quote_time;
   datetime quote_last_seen;
   int     session_trade_windows;
   int     session_quote_windows;

   void Reset()
     {
      symbol_raw=""; path=""; description="";
      trade_mode=0; calc_mode=0; digits=0;
      point=0.0; tick_size=0.0; tick_value=0.0; tick_value_profit=0.0; tick_value_loss=0.0; contract_size=0.0;
      volume_min=0.0; volume_step=0.0; volume_max=0.0;
      stops_level=0; freeze_level=0;
      margin_currency=""; profit_currency=""; base_currency=""; quote_currency="";
      session_property_availability=false; selection_state=false; sync_state=false;
      metadata_readable=false; quote_observable=false; synchronized_flag=false; history_addressable=false;
      trade_permitted=false; custom_symbol_flag=false; property_unavailable_flag=false; select_failed_temp=false; select_failed_perm=false;
      symbol_discovery_state=""; symbol_selection_state=""; symbol_synchronization_state=""; property_read_status=""; property_read_fail_mask=0;
      ZeroMemory(quote_tick_snapshot);
      quote_time=0; quote_last_seen=0;
      session_trade_windows=0; session_quote_windows=0;
     }
  };

struct ISSX_EA1_NormalizedIdentity
  {
   string                     symbol_norm;
   string                     canonical_root;
   string                     prefix_token;
   string                     suffix_token;
   string                     contract_token;
   string                     alias_family_id;
   string                     underlying_family_id;
   string                     market_representation_id;
   string                     execution_substitute_group_id;
   ISSX_RepresentationState   representation_state;
   double                     representation_confidence;
   double                     family_resolution_confidence;
   int                        family_rep_stability_window;
   string                     family_published_rep;
   string                     family_best_now;
   bool                       execution_profile_distinct_flag;
   string                     representation_reason_codes;
   bool                       preferred_variant_flag;
   bool                       preferred_variant_locked;
   int                        preferred_variant_lock_age_cycles;
   string                     representative_switch_reason;
   double                     representative_switch_cost;
   double                     variant_flip_risk_score;
   double                     representation_stability_score;

   void Reset()
     {
      symbol_norm=""; canonical_root=""; prefix_token=""; suffix_token=""; contract_token="";
      alias_family_id=""; underlying_family_id=""; market_representation_id=""; execution_substitute_group_id="";
      representation_state=issx_representation_uncertain;
      representation_confidence=0.0; family_resolution_confidence=0.0; family_rep_stability_window=0; family_published_rep=""; family_best_now=""; execution_profile_distinct_flag=false; representation_reason_codes="";
      preferred_variant_flag=false; preferred_variant_locked=false; preferred_variant_lock_age_cycles=0;
      representative_switch_reason=""; representative_switch_cost=0.0; variant_flip_risk_score=0.0; representation_stability_score=0.0;
     }
  };

struct ISSX_EA1_ValidatedRuntimeTruth
  {
   double                   property_truth_score;
   double                   runtime_truth_score;
   ISSX_ReadabilityState    readability_state;
   ISSX_UnknownReason       unknown_reason;
   int                      property_read_fail_mask;
   bool                     requires_marketwatch_selection;
   bool                     requires_runtime_probe;
   bool                     native_taxonomy_availability;
   bool                     session_counter_availability;
   ISSX_PracticalMarketState practical_market_state;
   string                   practical_market_state_reason_codes;
   string                   session_reconciliation_state;
   double                   session_truth_confidence;
   int                      observation_samples_short;
   int                      observation_samples_medium;
   double                   observation_density_score;
   double                   observation_gap_risk;
   double                   market_sampling_quality_score;
   double                   spread_median_short_points;
   double                   spread_p90_short_points;
   double                   spread_widening_ratio;
   double                   quote_interval_median_ms;
   double                   quote_interval_p90_ms;
   double                   quote_stall_rate;
   double                   quote_burstiness_score;
   double                   current_vs_normal_spread_percentile;
   double                   current_vs_normal_quote_rate_percentile;
   ISSX_EA1_SessionPhase    session_phase;
   int                      minutes_since_session_open;
   int                      minutes_to_session_close;
   bool                     transition_penalty_active;

   void Reset()
     {
      property_truth_score=0.0; runtime_truth_score=0.0;
      readability_state=issx_readability_unreadable; unknown_reason=issx_unknown_true_unknown;
      property_read_fail_mask=0; requires_marketwatch_selection=false; requires_runtime_probe=false;
      native_taxonomy_availability=false; session_counter_availability=false;
      practical_market_state=issx_market_blocked; practical_market_state_reason_codes="";
      session_reconciliation_state=""; session_truth_confidence=0.0;
      observation_samples_short=0; observation_samples_medium=0;
      observation_density_score=0.0; observation_gap_risk=0.0; market_sampling_quality_score=0.0;
      spread_median_short_points=0.0; spread_p90_short_points=0.0; spread_widening_ratio=0.0;
      quote_interval_median_ms=0.0; quote_interval_p90_ms=0.0; quote_stall_rate=0.0; quote_burstiness_score=0.0;
      current_vs_normal_spread_percentile=0.0; current_vs_normal_quote_rate_percentile=0.0;
      session_phase=issx_ea1_session_unknown; minutes_since_session_open=-1; minutes_to_session_close=-1; transition_penalty_active=false;
     }
  };

struct ISSX_EA1_ClassificationTruth
  {
   string                    asset_class;
   string                    instrument_family;
   string                    theme_bucket;
   string                    equity_sector;
   string                    leader_bucket_id;
   ISSX_LeaderBucketType     leader_bucket_type;
   string                    classification_source;
   double                    classification_confidence;
   double                    classification_reliability_score;
   string                    taxonomy_conflict_scope;
   ISSX_TaxonomyActionTaken  taxonomy_action_taken;
   int                       taxonomy_revision;
   int                       bucket_assignment_stable_cycles;
   string                    bucket_assignment_change_reason;
   double                    taxonomy_change_severity;
   bool                      native_sector_present;
   bool                      native_industry_present;
   double                    native_taxonomy_quality;
   bool                      native_vs_manual_conflict;
   double                    taxonomy_reliability_score;
   bool                      classification_needs_review;

   void Reset()
     {
      asset_class=""; instrument_family=""; theme_bucket=""; equity_sector=""; leader_bucket_id="";
      leader_bucket_type=issx_leader_bucket_theme_bucket;
      classification_source=""; classification_confidence=0.0; classification_reliability_score=0.0;
      taxonomy_conflict_scope=""; taxonomy_action_taken=issx_taxonomy_manual_review_only;
      taxonomy_revision=0; bucket_assignment_stable_cycles=0; bucket_assignment_change_reason=""; taxonomy_change_severity=0.0;
      native_sector_present=false; native_industry_present=false; native_taxonomy_quality=0.0;
      native_vs_manual_conflict=false; taxonomy_reliability_score=0.0; classification_needs_review=false;
     }
  };

struct ISSX_EA1_TradeabilityBaseline
  {
   double                  structural_tradeability_score;
   double                  live_tradeability_score;
   double                  blended_tradeability_score;
   double                  entry_cost_score;
   double                  holding_cost_visibility_score;
   double                  size_practicality_score;
   double                  economic_consistency_score;
   double                  microstructure_safety_score;
   double                  min_lot_risk_fit_score;
   double                  step_lot_precision_score;
   double                  small_account_usability_score;
   ISSX_TradeabilityClass  tradeability_class;
   ISSX_CommissionState    commission_state;
   ISSX_SwapState          swap_state;
   double                  all_in_cost_confidence;
   string                  structural_cost_reason_codes;
   string                  live_cost_reason_codes;
   int                     cost_shock_count_recent;
   string                  quote_burstiness_regime;
   string                  practical_execution_friction_class;
   string                  toxicity_flags;
   string                  toxicity_primary;
   double                  toxicity_score;
   int                     toxicity_holdoff_minutes;
   double                  live_cost_deviation_score;
   double                  spread_regime_shift_score;
   double                  cost_baseline_confidence;
   bool                    cost_reprobe_needed;
   string                  tradability_now_class;

   void Reset()
     {
      structural_tradeability_score=0.0; live_tradeability_score=0.0; blended_tradeability_score=0.0;
      entry_cost_score=0.0; holding_cost_visibility_score=0.0; size_practicality_score=0.0; economic_consistency_score=0.0;
      microstructure_safety_score=0.0; min_lot_risk_fit_score=0.0; step_lot_precision_score=0.0; small_account_usability_score=0.0;
      tradeability_class=issx_tradeability_blocked; commission_state=issx_commission_unknown; swap_state=issx_swap_unknown;
      all_in_cost_confidence=0.0; structural_cost_reason_codes=""; live_cost_reason_codes="";
      cost_shock_count_recent=0; quote_burstiness_regime=""; practical_execution_friction_class="";
      toxicity_flags=""; toxicity_primary=""; toxicity_score=0.0; toxicity_holdoff_minutes=0;
      live_cost_deviation_score=0.0; spread_regime_shift_score=0.0; cost_baseline_confidence=0.0; cost_reprobe_needed=false; tradability_now_class="";
     }
  };

struct ISSX_EA1_RankabilityGate
  {
   bool    identity_ready;
   bool    sync_ready;
   bool    session_ready;
   bool    market_ready;
   bool    spec_ready;
   bool    cost_ready;
   bool    rankability_gate_ready;
   bool    gate_passed;
   string  primary_block_reason;
   string  secondary_block_reason;
   bool    recoverable_next_cycle;
   double  gate_confidence;
   int     gate_pass_cycles;
   int     gate_flap_count;

   void Reset()
     {
      identity_ready=false; sync_ready=false; session_ready=false; market_ready=false; spec_ready=false; cost_ready=false;
      rankability_gate_ready=false; gate_passed=false; primary_block_reason=""; secondary_block_reason="";
      recoverable_next_cycle=false; gate_confidence=0.0; gate_pass_cycles=0; gate_flap_count=0;
     }
  };

struct ISSX_EA1_SymbolLifecycle
  {
   ISSX_EA1_LifecycleState     lifecycle_state;
   ISSX_ContinuityOrigin       continuity_origin;
   bool                        resumed_from_persistence;
   int                         continuity_age_cycles;
   bool                        material_change_since_last_publish;
   ISSX_RepairState            repair_state;
   int                         retry_backoff_sec;
   datetime                    next_reprobe_time;
   int                         fault_streak;
   double                      fault_decay_score;
   ISSX_FailureEscalationClass failure_escalation_class;
   bool                        forced_rebuild_required;
   string                      suspension_reason;
   int                         recovery_decay_cycles_remaining;
   ISSX_EA1_AdmissionState     admission_state;

   void Reset()
     {
      lifecycle_state=issx_ea1_lifecycle_new; continuity_origin=issx_continuity_fresh_boot;
      resumed_from_persistence=false; continuity_age_cycles=0; material_change_since_last_publish=false;
      repair_state=issx_repair_none; retry_backoff_sec=0; next_reprobe_time=0;
      fault_streak=0; fault_decay_score=0.0; failure_escalation_class=issx_failure_transient_fail;
      forced_rebuild_required=false; suspension_reason=""; recovery_decay_cycles_remaining=0;
      admission_state=issx_ea1_admission_listed;
     }
  };

struct ISSX_EA1_SymbolState
  {
   int                           symbol_id;
   ISSX_EA1_RawBrokerObservation raw_broker_observation;
   ISSX_EA1_NormalizedIdentity   normalized_identity;
   ISSX_EA1_ValidatedRuntimeTruth validated_runtime_truth;
   ISSX_EA1_ClassificationTruth  classification_truth;
   ISSX_EA1_TradeabilityBaseline tradeability_baseline;
   ISSX_EA1_RankabilityGate      rankability_gate;
   ISSX_EA1_SymbolLifecycle      symbol_lifecycle;
   uint                          content_hash;
   bool                          changed_this_cycle;

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
      content_hash=0;
      changed_this_cycle=false;
     }
  };

// ============================================================================
// SECTION 04: AGGREGATE STATE / DELTA / COUNTERS
// ============================================================================
struct ISSX_EA1_UniverseState
  {
   int    broker_universe;
   int    eligible_universe;
   int    active_universe;
   int    rankable_universe;
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
      broker_universe=0; eligible_universe=0; active_universe=0; rankable_universe=0;
      broker_universe_fingerprint=""; eligible_universe_fingerprint=""; active_universe_fingerprint="";
      rankable_universe_fingerprint=""; frontier_universe_fingerprint=""; publishable_universe_fingerprint="";
      universe_drift_class="none"; percent_universe_touched_recent=0.0; percent_rankable_revalidated_recent=0.0; percent_frontier_revalidated_recent=0.0; never_serviced_count=0; overdue_service_count=0; never_ranked_but_eligible_count=0; newly_active_symbols_waiting_count=0; near_cutline_recheck_age_max=0;
     }
  };

struct ISSX_EA1_DeltaState
  {
   int    changed_symbol_count;
   string changed_symbol_ids;
   int    changed_family_count;
   int    changed_bucket_count;
   int    changed_frontier_count;

   void Reset()
     {
      changed_symbol_count=0; changed_symbol_ids=""; changed_family_count=0; changed_bucket_count=0; changed_frontier_count=0;
     }
  };

struct ISSX_EA1_CycleCounters
  {
   int listed_count;
   int metadata_ready_count;
   int probe_ready_count;
   int rank_candidate_count;
   int blocked_tradeability_count;
   int cooldown_count;
   int representative_switch_count;
   int classification_review_count;
   int contradiction_count;
   ISSX_ContradictionSeverity contradiction_severity_max;

   void Reset()
     {
      listed_count=0; metadata_ready_count=0; probe_ready_count=0; rank_candidate_count=0;
      blocked_tradeability_count=0; cooldown_count=0; representative_switch_count=0; classification_review_count=0;
      contradiction_count=0; contradiction_severity_max=issx_contradiction_low;
     }
  };

struct ISSX_EA1_State
  {
   ISSX_EA1_SymbolState symbols[];
   ISSX_EA1_UniverseState universe;
   ISSX_EA1_DeltaState deltas;
   ISSX_EA1_CycleCounters counters;
   ISSX_RuntimeStats runtime_stats;
   ISSX_PhaseState scheduler;
   ISSX_RuntimeBudget runtime_budget;
   int minute_id;
   int sequence_no;
   string taxonomy_hash;
   string comparator_registry_hash;
   string cohort_fingerprint;
   bool degraded_flag;
   bool publishable;
   bool resumed_from_persistence;
   int dump_sequence_no;
   int dump_minute_id;
   string stage_minimum_ready_flag;
   string stage_publishability_state;
   string dependency_block_reason;
   string debug_weak_link_code;

   void Reset()
     {
      ArrayResize(symbols,0);
      universe.Reset();
      deltas.Reset();
      counters.Reset();
      runtime_stats.Reset();
      scheduler.Reset();
      runtime_budget.Reset();
      minute_id=0; sequence_no=0;
      taxonomy_hash=""; comparator_registry_hash=""; cohort_fingerprint="";
      degraded_flag=false; publishable=false; resumed_from_persistence=false; dump_sequence_no=0; dump_minute_id=0; stage_minimum_ready_flag="false"; stage_publishability_state="booting"; dependency_block_reason=""; debug_weak_link_code="none";
     }
  };

// ============================================================================
// SECTION 05: INTEGRATED CLASSIFICATION / TAXONOMY HEURISTICS
// ============================================================================
class ISSX_MarketTaxonomy
  {
private:
   static string L(const string s)
     {
      return ISSX_Util::Lower(ISSX_Util::Trim(s));
     }

   static string U(const string s)
     {
      string out=ISSX_Util::Trim(s);
      StringToUpper(out);
      return out;
     }

   static bool Contains(const string haystack_lc,const string needle_lc)
     {
      return (StringFind(haystack_lc,needle_lc)>=0);
     }

   static bool IsAsciiUpperLetter(const ushort ch)
     {
      return (ch>='A' && ch<='Z');
     }

   static bool IsAsciiDigit(const ushort ch)
     {
      return (ch>='0' && ch<='9');
     }

   static bool IsKnownCurrency(const string ccy_up)
     {
      return (ccy_up=="USD" || ccy_up=="EUR" || ccy_up=="GBP" || ccy_up=="JPY" ||
              ccy_up=="CHF" || ccy_up=="CAD" || ccy_up=="AUD" || ccy_up=="NZD" ||
              ccy_up=="SEK" || ccy_up=="NOK" || ccy_up=="DKK" || ccy_up=="ZAR" ||
              ccy_up=="MXN" || ccy_up=="TRY" || ccy_up=="PLN" || ccy_up=="CZK" ||
              ccy_up=="HUF" || ccy_up=="CNH" || ccy_up=="HKD" || ccy_up=="SGD");
     }

   static bool IsFxLike(const string root_up)
     {
      if(StringLen(root_up)!=6) return false;
      string a=StringSubstr(root_up,0,3);
      string b=StringSubstr(root_up,3,3);
      return IsKnownCurrency(a) && IsKnownCurrency(b);
     }

   static bool IsMetalLike(const string root_up)
     {
      if(StringLen(root_up)!=6) return false;
      string a=StringSubstr(root_up,0,3);
      string b=StringSubstr(root_up,3,3);
      return (a=="XAU" || a=="XAG" || a=="XPT" || a=="XPD") && IsKnownCurrency(b);
     }

   static bool IsCryptoBase(const string base_up)
     {
      return (base_up=="BTC" || base_up=="ETH" || base_up=="BNB" || base_up=="SOL" ||
              base_up=="ADA" || base_up=="XRP" || base_up=="DOGE" || base_up=="LTC" ||
              base_up=="BCH" || base_up=="DOT" || base_up=="AVAX" || base_up=="LINK" ||
              base_up=="MATIC" || base_up=="TRX" || base_up=="ETC" || base_up=="ATOM");
     }

   static bool IsCryptoLike(const string root_up)
     {
      if(StringLen(root_up)<6) return false;
      string q3=StringSubstr(root_up,StringLen(root_up)-3,3);
      if(!IsKnownCurrency(q3)) return false;
      string base=StringSubstr(root_up,0,StringLen(root_up)-3);
      return IsCryptoBase(base);
     }

   static bool IsIndexLike(const string root_up)
     {
      string u=U(root_up);
      return (u=="US30" || u=="US100" || u=="NAS100" || u=="SPX500" || u=="GER40" ||
              u=="UK100" || u=="EU50" || u=="FRA40" || u=="JPN225" || u=="AUS200" || u=="HK50");
     }

   static bool IsEnergyLike(const string root_up)
     {
      string u=U(root_up);
      return (u=="BRENT" || u=="WTI" || u=="UKOIL" || u=="USOIL" || u=="NGAS" || u=="NATGAS");
     }

   static bool IsSoftCommodityLike(const string root_up)
     {
      string u=L(root_up);
      return Contains(u,"coffee") || Contains(u,"cocoa") || Contains(u,"sugar") ||
             Contains(u,"corn") || Contains(u,"wheat") || Contains(u,"soy");
     }

   static bool IsVolatilityIndex(const string root_up)
     {
      string u=U(root_up);
      return (u=="VIX" || u=="VIXM" || u=="VOLX");
     }

   static string NormalizeRoot(const string symbol_raw)
     {
      string s=ISSX_Util::Trim(symbol_raw);
      StringToUpper(s);
      int n=StringLen(s);

      int start=0;
      while(start<n)
        {
         ushort ch=(ushort)StringGetCharacter(s,start);
         if(IsAsciiUpperLetter(ch) || IsAsciiDigit(ch) || ch=='_')
            break;
         start++;
        }

      int end=n-1;
      while(end>=start)
        {
         ushort ch=(ushort)StringGetCharacter(s,end);
         if(IsAsciiUpperLetter(ch) || IsAsciiDigit(ch) || ch=='_')
            break;
         end--;
        }

      if(end<start)
         return s;

      s=StringSubstr(s,start,end-start+1);

      while(StringLen(s)>0)
        {
         int last=StringLen(s)-1;
         ushort ch=(ushort)StringGetCharacter(s,last);
         if(IsAsciiDigit(ch))
            s=StringSubstr(s,0,last);
         else
            break;
        }

      string compact="";
      for(int i=0;i<StringLen(s);i++)
        {
         ushort ch=(ushort)StringGetCharacter(s,i);
         if(IsAsciiUpperLetter(ch) || IsAsciiDigit(ch))
            compact += StringSubstr(s,i,1);
        }
      return compact;
     }

public:
   static void Classify(const string symbol_raw,
                        const string symbol_norm,
                        const string canonical_root,
                        const string description,
                        const string path,
                        ISSX_EA1_ClassificationTruth &out_ct)
     {
      out_ct.Reset();

      string root = U((canonical_root!="") ? canonical_root : symbol_norm);
      string desc = L(description + " " + path + " " + symbol_raw);

      out_ct.classification_source = "issx_market_engine";
      out_ct.taxonomy_action_taken = issx_taxonomy_accepted;
      out_ct.taxonomy_revision = 1;
      out_ct.classification_confidence = 0.65;
      out_ct.classification_reliability_score = 0.65;
      out_ct.taxonomy_reliability_score = 0.65;

      if(IsFxLike(root))
        {
         out_ct.asset_class = "fx";
         out_ct.instrument_family = "spot_fx";
         out_ct.theme_bucket = "fx_major";
         out_ct.leader_bucket_id = "fx_major";
         out_ct.leader_bucket_type = issx_leader_bucket_theme_bucket;

         string base=StringSubstr(root,0,3);
         string quote=StringSubstr(root,3,3);
         if((base=="USD" || quote=="USD") && (base=="EUR" || quote=="EUR" || base=="JPY" || quote=="JPY" || base=="GBP" || quote=="GBP"))
            out_ct.theme_bucket = "fx_major";
         else if(base=="TRY" || quote=="TRY" || base=="ZAR" || quote=="ZAR" || base=="MXN" || quote=="MXN")
            out_ct.theme_bucket = "fx_em";
         else
            out_ct.theme_bucket = "fx_cross";

         out_ct.leader_bucket_id = out_ct.theme_bucket;
         out_ct.classification_confidence = 0.92;
         out_ct.classification_reliability_score = 0.90;
         out_ct.taxonomy_reliability_score = 0.90;
         return;
        }

      if(IsMetalLike(root))
        {
         out_ct.asset_class = "commodity";
         out_ct.instrument_family = "metals";
         out_ct.theme_bucket = "metals";
         out_ct.leader_bucket_id = "metals";
         out_ct.leader_bucket_type = issx_leader_bucket_theme_bucket;
         out_ct.classification_confidence = 0.92;
         out_ct.classification_reliability_score = 0.90;
         out_ct.taxonomy_reliability_score = 0.90;
         return;
        }

      if(IsCryptoLike(root))
        {
         out_ct.asset_class = "crypto";
         out_ct.instrument_family = "crypto_cfds";
         out_ct.theme_bucket = "crypto";
         out_ct.leader_bucket_id = "crypto";
         out_ct.leader_bucket_type = issx_leader_bucket_theme_bucket;
         out_ct.classification_confidence = 0.90;
         out_ct.classification_reliability_score = 0.88;
         out_ct.taxonomy_reliability_score = 0.88;
         return;
        }

      if(IsIndexLike(root))
        {
         out_ct.asset_class = "index";
         out_ct.instrument_family = "equity_index";
         out_ct.theme_bucket = "indices";
         out_ct.leader_bucket_id = "indices";
         out_ct.leader_bucket_type = issx_leader_bucket_theme_bucket;
         out_ct.classification_confidence = 0.90;
         out_ct.classification_reliability_score = 0.86;
         out_ct.taxonomy_reliability_score = 0.86;
         return;
        }

      if(IsEnergyLike(root))
        {
         out_ct.asset_class = "commodity";
         out_ct.instrument_family = "energy";
         out_ct.theme_bucket = "energy";
         out_ct.leader_bucket_id = "energy";
         out_ct.leader_bucket_type = issx_leader_bucket_theme_bucket;
         out_ct.classification_confidence = 0.88;
         out_ct.classification_reliability_score = 0.84;
         out_ct.taxonomy_reliability_score = 0.84;
         return;
        }

      if(IsSoftCommodityLike(root))
        {
         out_ct.asset_class = "commodity";
         out_ct.instrument_family = "softs";
         out_ct.theme_bucket = "softs";
         out_ct.leader_bucket_id = "softs";
         out_ct.leader_bucket_type = issx_leader_bucket_theme_bucket;
         out_ct.classification_confidence = 0.84;
         out_ct.classification_reliability_score = 0.80;
         out_ct.taxonomy_reliability_score = 0.80;
         return;
        }

      if(IsVolatilityIndex(root))
        {
         out_ct.asset_class = "index";
         out_ct.instrument_family = "volatility_index";
         out_ct.theme_bucket = "volatility";
         out_ct.leader_bucket_id = "volatility";
         out_ct.leader_bucket_type = issx_leader_bucket_theme_bucket;
         out_ct.classification_confidence = 0.82;
         out_ct.classification_reliability_score = 0.78;
         out_ct.taxonomy_reliability_score = 0.78;
         return;
        }

      if(Contains(desc,"stock") || Contains(desc,"share") || Contains(desc,"equity") || Contains(desc,"nyse") || Contains(desc,"nasdaq"))
        {
         out_ct.asset_class = "equity";
         out_ct.instrument_family = "single_stock";
         out_ct.theme_bucket = "equities";
         out_ct.leader_bucket_id = "equities";
         out_ct.leader_bucket_type = issx_leader_bucket_theme_bucket;
         out_ct.classification_confidence = 0.70;
         out_ct.classification_reliability_score = 0.66;
         out_ct.taxonomy_reliability_score = 0.66;

         if(Contains(desc,"technology") || Contains(desc,"software") || Contains(desc,"semiconductor"))
           {
            out_ct.equity_sector = "technology";
            out_ct.leader_bucket_id = "technology";
            out_ct.leader_bucket_type = issx_leader_bucket_equity_sector;
            out_ct.native_sector_present = true;
           }
         else if(Contains(desc,"bank") || Contains(desc,"financial"))
           {
            out_ct.equity_sector = "financials";
            out_ct.leader_bucket_id = "financials";
            out_ct.leader_bucket_type = issx_leader_bucket_equity_sector;
            out_ct.native_sector_present = true;
           }
         else if(Contains(desc,"energy"))
           {
            out_ct.equity_sector = "energy";
            out_ct.leader_bucket_id = "energy";
            out_ct.leader_bucket_type = issx_leader_bucket_equity_sector;
            out_ct.native_sector_present = true;
           }
         return;
        }

      out_ct.asset_class = "other";
      out_ct.instrument_family = "unclassified";
      out_ct.theme_bucket = "other";
      out_ct.leader_bucket_id = "other";
      out_ct.leader_bucket_type = issx_leader_bucket_theme_bucket;
      out_ct.classification_confidence = 0.30;
      out_ct.classification_reliability_score = 0.25;
      out_ct.taxonomy_reliability_score = 0.25;
      out_ct.classification_needs_review = true;
      out_ct.taxonomy_action_taken = issx_taxonomy_theme_downgrade;
      out_ct.taxonomy_conflict_scope = "low_confidence_unclassified";
     }

   static string ExtractCanonicalRoot(const string symbol_raw)
     {
      return NormalizeRoot(symbol_raw);
     }
  };

// ============================================================================
// SECTION 06: MARKET ENGINE
// ============================================================================
class ISSX_MarketEngine
  {
private:
   static uint HashSymbolState(const ISSX_EA1_SymbolState &s)
     {
      string src =
         s.raw_broker_observation.symbol_raw + "|" +
         s.normalized_identity.symbol_norm + "|" +
         s.normalized_identity.canonical_root + "|" +
         s.classification_truth.leader_bucket_id + "|" +
         IntegerToString((int)s.classification_truth.leader_bucket_type) + "|" +
         IntegerToString((int)s.tradeability_baseline.tradeability_class) + "|" +
         IntegerToString((int)s.validated_runtime_truth.practical_market_state) + "|" +
         IntegerToString((int)s.rankability_gate.gate_passed) + "|" +
         IntegerToString((int)s.symbol_lifecycle.lifecycle_state);
      return ISSX_Util::Hash32(src);
     }

   static string JoinReason2(const string a,const string b)
     {
      if(a=="" && b=="") return "";
      if(a=="") return b;
      if(b=="") return a;
      return a + "|" + b;
     }

   static string SafeSymbolPath(const string symbol)
     {
      string p="";
      SymbolInfoString(symbol,SYMBOL_PATH,p);
      return p;
     }

   static string SafeSymbolDesc(const string symbol)
     {
      string d="";
      SymbolInfoString(symbol,SYMBOL_DESCRIPTION,d);
      return d;
     }

   static string SafeCurrency(const string symbol,ENUM_SYMBOL_INFO_STRING prop)
     {
      string s="";
      SymbolInfoString(symbol,prop,s);
      return s;
     }

   static bool LoadRawObservation(const string symbol, ISSX_EA1_RawBrokerObservation &out_obs)
     {
      out_obs.Reset();
      out_obs.symbol_raw=symbol;
      out_obs.path=SafeSymbolPath(symbol);
      out_obs.description=SafeSymbolDesc(symbol);

      long lv=0;
      double dv=0.0;

      if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE,lv)) out_obs.property_read_fail_mask |= 1; else out_obs.trade_mode=lv;
      if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE,lv)) out_obs.property_read_fail_mask |= 2; else out_obs.calc_mode=lv;
      if(!SymbolInfoInteger(symbol,SYMBOL_DIGITS,lv)) out_obs.property_read_fail_mask |= 4; else out_obs.digits=(int)lv;

      if(!SymbolInfoDouble(symbol,SYMBOL_POINT,dv)) out_obs.property_read_fail_mask |= 8; else out_obs.point=dv;
      if(!SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE,dv)) out_obs.property_read_fail_mask |= 16; else out_obs.tick_size=dv;
      if(!SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE,dv)) out_obs.property_read_fail_mask |= 32; else out_obs.tick_value=dv;
      if(!SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT,dv)) out_obs.property_read_fail_mask |= 64; else out_obs.tick_value_profit=dv;
      if(!SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS,dv)) out_obs.property_read_fail_mask |= 128; else out_obs.tick_value_loss=dv;
      if(!SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE,dv)) out_obs.property_read_fail_mask |= 256; else out_obs.contract_size=dv;
      if(!SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN,dv)) out_obs.property_read_fail_mask |= 512; else out_obs.volume_min=dv;
      if(!SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP,dv)) out_obs.property_read_fail_mask |= 1024; else out_obs.volume_step=dv;
      if(!SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX,dv)) out_obs.property_read_fail_mask |= 2048; else out_obs.volume_max=dv;
      if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL,lv)) out_obs.property_read_fail_mask |= 4096; else out_obs.stops_level=(int)lv;
      if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL,lv)) out_obs.property_read_fail_mask |= 8192; else out_obs.freeze_level=(int)lv;

      out_obs.margin_currency=SafeCurrency(symbol,SYMBOL_CURRENCY_MARGIN);
      out_obs.profit_currency=SafeCurrency(symbol,SYMBOL_CURRENCY_PROFIT);
      out_obs.base_currency  =SafeCurrency(symbol,SYMBOL_CURRENCY_BASE);
      out_obs.quote_currency =out_obs.profit_currency;

      out_obs.selection_state = (bool)SymbolInfoInteger(symbol,SYMBOL_SELECT);
      out_obs.sync_state      = (bool)SymbolInfoInteger(symbol,SYMBOL_EXIST);
      out_obs.metadata_readable = (out_obs.property_read_fail_mask==0);
      out_obs.synchronized_flag = out_obs.sync_state;
      out_obs.history_addressable = out_obs.sync_state;
      out_obs.trade_permitted = (out_obs.trade_mode!=SYMBOL_TRADE_MODE_DISABLED);
      out_obs.custom_symbol_flag = (bool)SymbolInfoInteger(symbol,SYMBOL_CUSTOM);
      out_obs.property_unavailable_flag = (out_obs.property_read_fail_mask!=0);
      out_obs.select_failed_temp = false;
      out_obs.select_failed_perm = false;
      out_obs.symbol_discovery_state = "discovered";
      out_obs.symbol_selection_state = (out_obs.selection_state ? "selected" : "not_selected");
      out_obs.symbol_synchronization_state = (out_obs.synchronized_flag ? "synchronized" : "unsynchronized");
      out_obs.property_read_status = (out_obs.property_read_fail_mask==0 ? "metadata_readable" : "property_unavailable");

      MqlTick tick;
      if(SymbolInfoTick(symbol,tick))
        {
         out_obs.quote_tick_snapshot=tick;
         out_obs.quote_time=(datetime)tick.time;
         out_obs.quote_last_seen=(datetime)tick.time;
         out_obs.quote_observable=true;
        }
      else
        {
         out_obs.quote_observable=false;
        }
      out_obs.session_property_availability = true;
      return true;
     }

   static void NormalizeIdentity(const ISSX_EA1_RawBrokerObservation &obs, ISSX_EA1_NormalizedIdentity &out_ni)
     {
      out_ni.Reset();
      out_ni.symbol_norm = ISSX_Util::Upper(obs.symbol_raw);
      out_ni.canonical_root = ISSX_MarketTaxonomy::ExtractCanonicalRoot(out_ni.symbol_norm);
      out_ni.alias_family_id = out_ni.canonical_root;
      out_ni.underlying_family_id = out_ni.canonical_root;
      out_ni.market_representation_id = out_ni.canonical_root;
      out_ni.execution_substitute_group_id = out_ni.canonical_root;
      out_ni.representation_state = issx_representation_canonical;
      out_ni.representation_confidence = (out_ni.canonical_root!="") ? 0.90 : 0.20;
      out_ni.family_resolution_confidence = out_ni.representation_confidence;
      out_ni.family_rep_stability_window = 1;
      out_ni.family_published_rep = out_ni.canonical_root;
      out_ni.family_best_now = out_ni.canonical_root;
      out_ni.execution_profile_distinct_flag = false;
      out_ni.preferred_variant_flag = true;
      out_ni.preferred_variant_locked = true;
      out_ni.preferred_variant_lock_age_cycles = 1;
      out_ni.representation_stability_score = 0.85;
      out_ni.variant_flip_risk_score = 0.05;
      out_ni.representation_reason_codes = "canonical_root";
      if(out_ni.canonical_root != out_ni.symbol_norm)
        {
         out_ni.representation_state = issx_representation_variant;
         out_ni.representation_reason_codes = "trimmed_variant";
        }
     }

   static void BuildRuntimeTruth(const ISSX_EA1_RawBrokerObservation &obs, ISSX_EA1_ValidatedRuntimeTruth &out_rt)
     {
      out_rt.Reset();
      out_rt.property_read_fail_mask = obs.property_read_fail_mask;
      out_rt.requires_marketwatch_selection = !obs.selection_state;
      out_rt.requires_runtime_probe = false;
      out_rt.native_taxonomy_availability = (obs.description!="");
      out_rt.session_counter_availability = obs.session_property_availability;
      out_rt.property_truth_score = (obs.property_read_fail_mask==0 ? 0.95 : 0.55);
      out_rt.runtime_truth_score = out_rt.property_truth_score;
      out_rt.readability_state = (obs.symbol_raw!="" ? issx_readability_full : issx_readability_unreadable);
      out_rt.unknown_reason = (obs.symbol_raw!="" ? issx_unknown_not_applicable : issx_unknown_true_unknown);

      double spread_points = 0.0;
      if(obs.point>0.0 && obs.quote_tick_snapshot.ask>0.0 && obs.quote_tick_snapshot.bid>0.0)
         spread_points = (obs.quote_tick_snapshot.ask - obs.quote_tick_snapshot.bid) / obs.point;
      out_rt.spread_median_short_points = spread_points;
      out_rt.spread_p90_short_points = spread_points;
      out_rt.spread_widening_ratio = 1.0;
      out_rt.quote_interval_median_ms = 1000.0;
      out_rt.quote_interval_p90_ms = 1500.0;
      out_rt.quote_stall_rate = (obs.quote_time>0 ? 0.05 : 1.0);
      out_rt.quote_burstiness_score = 0.20;
      out_rt.current_vs_normal_spread_percentile = 0.50;
      out_rt.current_vs_normal_quote_rate_percentile = 0.50;
      out_rt.observation_samples_short = (obs.quote_time>0 ? 1 : 0);
      out_rt.observation_samples_medium = (obs.quote_time>0 ? 1 : 0);
      out_rt.observation_density_score = (obs.quote_time>0 ? 0.70 : 0.10);
      out_rt.observation_gap_risk = (obs.quote_time>0 ? 0.15 : 0.90);
      out_rt.market_sampling_quality_score = out_rt.observation_density_score;
      out_rt.session_truth_confidence = obs.session_property_availability ? 0.70 : 0.35;
      out_rt.session_reconciliation_state = obs.session_property_availability ? "direct_properties" : "fallback_unknown";
      out_rt.declared_session_state = (obs.session_property_availability ? "declared_available" : "declared_unknown");
      out_rt.observed_quote_activity_state = (obs.quote_time>0 ? "observed_supported" : "quote_stale");
      out_rt.observed_spread_behavior_state = (spread_points>0.0 ? (spread_points<=15.0 ? "supported" : "wide") : "unknown");
      out_rt.trade_permission_state = (obs.trade_permitted ? "trade_permitted" : "trade_blocked");
      out_rt.session_truth_class = (obs.session_property_availability && obs.quote_time>0 ? "observed_supported" : (obs.session_property_availability ? "declared_only" : "contradictory"));
      out_rt.current_quote_liveness_state = (obs.quote_time>0 ? "live" : "stale");
      out_rt.current_friction_state = (spread_points<=15.0 && spread_points>0.0 ? "normal" : (spread_points<=50.0 && spread_points>0.0 ? "elevated" : "stressed"));
      out_rt.spread_state_vs_baseline = (spread_points<=15.0 && spread_points>0.0 ? "near_baseline" : (spread_points<=50.0 && spread_points>0.0 ? "moderately_wide" : "dislocated"));
      out_rt.activity_transition_state = (obs.quote_time>0 ? "active" : "idle");
      out_rt.liquidity_ramp_state = (obs.quote_time>0 && spread_points>0.0 && spread_points<=20.0 ? "supported" : "thin");

      if(obs.trade_mode==SYMBOL_TRADE_MODE_DISABLED)
        {
         out_rt.practical_market_state = issx_market_blocked;
         out_rt.practical_market_state_reason_codes = "trade_disabled";
        }
      else if(!obs.selection_state)
        {
         out_rt.practical_market_state = issx_market_quote_only;
         out_rt.practical_market_state_reason_codes = "marketwatch_selection_required";
        }
      else if(spread_points>0.0 && spread_points<=15.0)
        {
         out_rt.practical_market_state = issx_market_open_usable;
         out_rt.practical_market_state_reason_codes = "quotes_recent";
        }
      else if(spread_points>15.0 && spread_points<=50.0)
        {
         out_rt.practical_market_state = issx_market_open_cautious;
         out_rt.practical_market_state_reason_codes = "spread_wide";
        }
      else if(obs.quote_time>0)
        {
         out_rt.practical_market_state = issx_market_quote_only;
         out_rt.practical_market_state_reason_codes = "quotes_only";
        }
      else
        {
         out_rt.practical_market_state = issx_market_closed_idle;
         out_rt.practical_market_state_reason_codes = "no_recent_quote";
        }

      if(out_rt.practical_market_state==issx_market_open_usable || out_rt.practical_market_state==issx_market_open_cautious)
        {
         out_rt.session_phase = issx_ea1_session_open;
         out_rt.minutes_since_session_open = 60;
         out_rt.minutes_to_session_close = 300;
        }
      else if(out_rt.practical_market_state==issx_market_closed_idle)
        {
         out_rt.session_phase = issx_ea1_session_closed;
         out_rt.minutes_since_session_open = -1;
         out_rt.minutes_to_session_close = -1;
        }
      else
        {
         out_rt.session_phase = issx_ea1_session_transition;
         out_rt.transition_penalty_active = true;
         out_rt.minutes_since_session_open = 0;
         out_rt.minutes_to_session_close = 0;
        }
     }

   static void BuildTradeability(const ISSX_EA1_RawBrokerObservation &obs,
                                 const ISSX_EA1_ValidatedRuntimeTruth &rt,
                                 ISSX_EA1_TradeabilityBaseline &out_tb)
     {
      out_tb.Reset();

      double spread_points = rt.spread_median_short_points;
      double step = obs.volume_step;
      double minv = obs.volume_min;

      out_tb.structural_tradeability_score = (obs.contract_size>0.0 && step>0.0 && minv>0.0) ? 0.85 : 0.35;
      if(spread_points<=0.0)
         out_tb.live_tradeability_score = 0.20;
      else if(spread_points<=10.0)
         out_tb.live_tradeability_score = 0.92;
      else if(spread_points<=20.0)
         out_tb.live_tradeability_score = 0.76;
      else if(spread_points<=40.0)
         out_tb.live_tradeability_score = 0.52;
      else
         out_tb.live_tradeability_score = 0.20;

      out_tb.entry_cost_score = out_tb.live_tradeability_score;
      out_tb.holding_cost_visibility_score = (obs.tick_value!=0.0 ? 0.80 : 0.45);
      out_tb.size_practicality_score = (minv<=0.10 ? 0.90 : (minv<=1.00 ? 0.60 : 0.20));
      out_tb.economic_consistency_score = (obs.tick_value>=0.0 && obs.tick_size>0.0 ? 0.85 : 0.30);
      out_tb.microstructure_safety_score = (obs.freeze_level<=10 ? 0.80 : 0.50);
      out_tb.min_lot_risk_fit_score = out_tb.size_practicality_score;
      out_tb.step_lot_precision_score = (step>0.0 && step<=0.10 ? 0.85 : 0.55);
      out_tb.small_account_usability_score = 0.5*(out_tb.size_practicality_score + out_tb.step_lot_precision_score);

      out_tb.blended_tradeability_score =
         0.40*out_tb.entry_cost_score +
         0.20*out_tb.structural_tradeability_score +
         0.15*out_tb.size_practicality_score +
         0.10*out_tb.economic_consistency_score +
         0.15*out_tb.microstructure_safety_score;

      out_tb.commission_state = (obs.tick_value!=0.0 ? issx_commission_known_zero : issx_commission_unknown);
      out_tb.swap_state = issx_swap_unknown;
      out_tb.all_in_cost_confidence = (out_tb.commission_state!=issx_commission_unknown ? 0.65 : 0.35);
      out_tb.structural_cost_reason_codes = "spec_cost_inputs";
      out_tb.live_cost_reason_codes = "spread_sample_live";
      out_tb.cost_shock_count_recent = (rt.spread_widening_ratio>2.0 ? 1 : 0);
      out_tb.quote_burstiness_regime = (rt.quote_burstiness_score>0.70 ? "burst" : "normal");
      out_tb.tradability_now_class = (out_tb.live_tradeability_score>=0.80 ? "strong" : (out_tb.live_tradeability_score>=0.50 ? "acceptable" : "poor"));
      out_tb.practical_execution_friction_class = (spread_points<=10.0 ? "low" : (spread_points<=25.0 ? "moderate" : "high"));
      out_tb.toxicity_flags = (rt.transition_penalty_active ? "session_transition" : "");
      out_tb.toxicity_primary = out_tb.toxicity_flags;
      out_tb.toxicity_score = (rt.transition_penalty_active ? 0.60 : 0.10);
      out_tb.toxicity_holdoff_minutes = (rt.transition_penalty_active ? 15 : 0);
      out_tb.live_cost_deviation_score = (rt.spread_widening_ratio>1.5 ? 0.60 : 0.10);
      out_tb.spread_regime_shift_score = out_tb.live_cost_deviation_score;
      out_tb.cost_baseline_confidence = 0.70;
      out_tb.cost_reprobe_needed = (rt.quote_stall_rate>0.50);

      if(rt.practical_market_state==issx_market_blocked)
         out_tb.tradeability_class = issx_tradeability_blocked;
      else if(out_tb.blended_tradeability_score>=0.85)
         out_tb.tradeability_class = issx_tradeability_very_cheap;
      else if(out_tb.blended_tradeability_score>=0.68)
         out_tb.tradeability_class = issx_tradeability_cheap;
      else if(out_tb.blended_tradeability_score>=0.45)
         out_tb.tradeability_class = issx_tradeability_moderate;
      else if(out_tb.blended_tradeability_score>0.0)
         out_tb.tradeability_class = issx_tradeability_expensive;
      else
         out_tb.tradeability_class = issx_tradeability_blocked;
     }

   static void BuildGate(const ISSX_EA1_NormalizedIdentity &ni,
                         const ISSX_EA1_ValidatedRuntimeTruth &rt,
                         const ISSX_EA1_ClassificationTruth &ct,
                         const ISSX_EA1_TradeabilityBaseline &tb,
                         ISSX_EA1_RankabilityGate &out_gate)
     {
      out_gate.Reset();

      out_gate.identity_ready = (ni.canonical_root!="");
      out_gate.sync_ready = (rt.readability_state!=issx_readability_unreadable);
      out_gate.session_ready = (rt.session_truth_confidence>=0.35);
      out_gate.market_ready = (rt.practical_market_state!=issx_market_blocked);
      out_gate.spec_ready = (tb.structural_tradeability_score>=0.35);
      out_gate.cost_ready = (tb.tradeability_class!=issx_tradeability_blocked);
      out_gate.rankability_gate_ready = out_gate.identity_ready && out_gate.sync_ready && out_gate.session_ready && out_gate.spec_ready;
      out_gate.gate_passed = out_gate.rankability_gate_ready && out_gate.market_ready && out_gate.cost_ready;

      if(!out_gate.identity_ready) out_gate.primary_block_reason="identity_not_ready";
      else if(!out_gate.sync_ready) out_gate.primary_block_reason="sync_not_ready";
      else if(!out_gate.market_ready) out_gate.primary_block_reason="market_blocked";
      else if(!out_gate.cost_ready) out_gate.primary_block_reason="cost_blocked";
      else if(ct.classification_confidence<0.25) out_gate.primary_block_reason="classification_weak";
      else out_gate.primary_block_reason="";

      if(tb.tradeability_class==issx_tradeability_expensive)
         out_gate.secondary_block_reason="cost_expensive";
      else if(rt.transition_penalty_active)
         out_gate.secondary_block_reason="session_transition";
      else if(ct.classification_needs_review)
         out_gate.secondary_block_reason="classification_review";
      else
         out_gate.secondary_block_reason="";

      out_gate.recoverable_next_cycle = !out_gate.gate_passed;
      out_gate.gate_confidence = 0.20 +
                                 0.15*(out_gate.identity_ready?1.0:0.0) +
                                 0.15*(out_gate.sync_ready?1.0:0.0) +
                                 0.15*(out_gate.session_ready?1.0:0.0) +
                                 0.20*(out_gate.market_ready?1.0:0.0) +
                                 0.15*(out_gate.spec_ready?1.0:0.0);
     }

   static void BuildLifecycle(const bool had_prior_state,
                              const bool changed,
                              const ISSX_EA1_RankabilityGate &gate,
                              ISSX_EA1_SymbolLifecycle &io_lc)
     {
      if(!had_prior_state)
         io_lc.Reset();

      io_lc.material_change_since_last_publish = changed;

      if(io_lc.repair_state==issx_repair_cooldown)
         io_lc.lifecycle_state = issx_ea1_lifecycle_cooling;
      else if(!gate.gate_passed && !gate.recoverable_next_cycle)
         io_lc.lifecycle_state = issx_ea1_lifecycle_suspended;
      else if(changed)
         io_lc.lifecycle_state = issx_ea1_lifecycle_changed;
      else if(had_prior_state)
         io_lc.lifecycle_state = issx_ea1_lifecycle_stable;
      else
         io_lc.lifecycle_state = issx_ea1_lifecycle_new;

      if(gate.gate_passed)
         io_lc.admission_state = issx_ea1_admission_rank_candidate;
      else if(gate.identity_ready && gate.sync_ready)
         io_lc.admission_state = issx_ea1_admission_probe_ready;
      else if(gate.identity_ready)
         io_lc.admission_state = issx_ea1_admission_metadata_ready;
      else
         io_lc.admission_state = issx_ea1_admission_listed;

      if(changed) io_lc.continuity_age_cycles = 0;
      else io_lc.continuity_age_cycles++;

      if(io_lc.lifecycle_state==issx_ea1_lifecycle_suspended)
        {
         io_lc.failure_escalation_class = issx_failure_suspended;
         io_lc.suspension_reason = gate.primary_block_reason;
        }
     }

   static void ScanContradictions(ISSX_EA1_SymbolState &io_state, ISSX_EA1_CycleCounters &io_counters)
     {
      if(io_state.validated_runtime_truth.observation_density_score>=0.8 &&
         io_state.validated_runtime_truth.practical_market_state==issx_market_blocked)
        {
         io_counters.contradiction_count++;
         io_counters.contradiction_severity_max=issx_contradiction_high;
        }

      if(io_state.tradeability_baseline.all_in_cost_confidence>=0.7 &&
         io_state.tradeability_baseline.commission_state==issx_commission_unknown &&
         io_state.tradeability_baseline.swap_state==issx_swap_unknown)
        {
         io_counters.contradiction_count++;
         if(io_counters.contradiction_severity_max<issx_contradiction_moderate)
            io_counters.contradiction_severity_max=issx_contradiction_moderate;
        }

      if(io_state.classification_truth.taxonomy_action_taken==issx_taxonomy_accepted &&
         io_state.classification_truth.classification_confidence<0.30 &&
         io_state.classification_truth.taxonomy_conflict_scope!="")
        {
         io_counters.contradiction_count++;
         if(io_counters.contradiction_severity_max<issx_contradiction_high)
            io_counters.contradiction_severity_max=issx_contradiction_high;
        }
     }

public:
   static void InitState(ISSX_EA1_State &io_state)
     {
      io_state.Reset();
      io_state.runtime_budget = ISSX_Runtime::MakeDefaultBudget(issx_stage_ea1);
      io_state.scheduler.phase_id = issx_ea1_phase_discover_symbols;
      io_state.scheduler.phase_budget_ms = 150;
      io_state.scheduler.phase_saved_progress_key = "ea1_discovery";
      io_state.taxonomy_hash = ISSX_FieldRegistry::TaxonomyHash();
      io_state.comparator_registry_hash = ISSX_ComparatorRegistry::RegistryHash();
     }

   static bool DiscoverUniverse(ISSX_EA1_State &io_state,
                                const bool include_custom_symbols=false,
                                const int max_symbols=0)
     {
      int total = SymbolsTotal(include_custom_symbols);
      if(total<0) total=0;
      int take = (max_symbols>0 && max_symbols<total ? max_symbols : total);

      ArrayResize(io_state.symbols,take);
      io_state.universe.Reset();
      io_state.deltas.Reset();
      io_state.counters.Reset();
      io_state.universe.broker_universe = total;

      for(int i=0;i<take;i++)
        {
         string symbol=SymbolName(i,include_custom_symbols);
         io_state.symbols[i].Reset();
         io_state.symbols[i].symbol_id=i;
         LoadRawObservation(symbol, io_state.symbols[i].raw_broker_observation);
         io_state.counters.listed_count++;
        }

      io_state.universe.active_universe = take;
      io_state.universe.eligible_universe = take;
      io_state.universe.broker_universe_fingerprint = IntegerToString(total) + ":" + IntegerToString(take);
      io_state.universe.active_universe_fingerprint = io_state.universe.broker_universe_fingerprint;
      io_state.universe.eligible_universe_fingerprint = io_state.universe.broker_universe_fingerprint;
      return (take>0);
     }

   static void BuildIdentityPhase(ISSX_EA1_State &io_state)
     {
      for(int i=0;i<ArraySize(io_state.symbols);i++)
         NormalizeIdentity(io_state.symbols[i].raw_broker_observation, io_state.symbols[i].normalized_identity);
     }

   static void BuildRuntimePhase(ISSX_EA1_State &io_state)
     {
      for(int i=0;i<ArraySize(io_state.symbols);i++)
         BuildRuntimeTruth(io_state.symbols[i].raw_broker_observation, io_state.symbols[i].validated_runtime_truth);
     }

   static void BuildClassificationPhase(ISSX_EA1_State &io_state)
     {
      for(int i=0;i<ArraySize(io_state.symbols);i++)
        {
         ISSX_EA1_SymbolState &s = io_state.symbols[i];
         ISSX_MarketTaxonomy::Classify(s.raw_broker_observation.symbol_raw,
                                       s.normalized_identity.symbol_norm,
                                       s.normalized_identity.canonical_root,
                                       s.raw_broker_observation.description,
                                       s.raw_broker_observation.path,
                                       s.classification_truth);
        }
     }

   static void BuildTradeabilityPhase(ISSX_EA1_State &io_state)
     {
      for(int i=0;i<ArraySize(io_state.symbols);i++)
         BuildTradeability(io_state.symbols[i].raw_broker_observation,
                           io_state.symbols[i].validated_runtime_truth,
                           io_state.symbols[i].tradeability_baseline);
     }

   static void BuildGateAndContinuityPhase(ISSX_EA1_State &io_state)
     {
      io_state.universe.rankable_universe = 0;
      io_state.deltas.Reset();
      io_state.counters.Reset();

      string delta_ids="";

      for(int i=0;i<ArraySize(io_state.symbols);i++)
        {
         ISSX_EA1_SymbolState &s = io_state.symbols[i];
         BuildGate(s.normalized_identity, s.validated_runtime_truth, s.classification_truth, s.tradeability_baseline, s.rankability_gate);

         uint new_hash = HashSymbolState(s);
         bool changed = (s.content_hash!=0 && s.content_hash!=new_hash);
         s.changed_this_cycle = (s.content_hash==0 || changed);
         s.content_hash = new_hash;

         BuildLifecycle(true, s.changed_this_cycle, s.rankability_gate, s.symbol_lifecycle);

         if(s.rankability_gate.gate_passed)
            io_state.universe.rankable_universe++;

         if(s.changed_this_cycle)
           {
            io_state.deltas.changed_symbol_count++;
            if(delta_ids!="") delta_ids += ",";
            delta_ids += IntegerToString(s.symbol_id);
           }

         if(s.tradeability_baseline.tradeability_class==issx_tradeability_blocked)
            io_state.counters.blocked_tradeability_count++;
         if(s.symbol_lifecycle.repair_state==issx_repair_cooldown)
            io_state.counters.cooldown_count++;
         if(s.classification_truth.classification_needs_review)
            io_state.counters.classification_review_count++;

         ScanContradictions(s, io_state.counters);
        }

      io_state.deltas.changed_symbol_ids = delta_ids;
      io_state.universe.rankable_universe_fingerprint =
         IntegerToString(io_state.universe.rankable_universe) + ":" + IntegerToString(io_state.deltas.changed_symbol_count);
      io_state.universe.percent_universe_touched_recent = (io_state.universe.broker_universe>0 ? (100.0 * io_state.universe.active_universe / io_state.universe.broker_universe) : 0.0);
      io_state.universe.percent_rankable_revalidated_recent = (io_state.universe.rankable_universe>0 ? 100.0 : 0.0);
      io_state.universe.percent_frontier_revalidated_recent = (io_state.universe.frontier_universe_fingerprint!="" ? 100.0 : 0.0);
      io_state.universe.never_serviced_count = MathMax(0, io_state.universe.eligible_universe - io_state.universe.active_universe);
      io_state.universe.overdue_service_count = 0;
      io_state.universe.never_ranked_but_eligible_count = MathMax(0, io_state.universe.eligible_universe - io_state.universe.rankable_universe);
      io_state.universe.newly_active_symbols_waiting_count = MathMax(0, io_state.deltas.changed_symbol_count - io_state.universe.rankable_universe);
      io_state.universe.near_cutline_recheck_age_max = 0;
      io_state.publishable = (io_state.universe.active_universe>0);
      io_state.degraded_flag = (io_state.universe.rankable_universe<=0);
      io_state.dump_sequence_no = io_state.sequence_no;
      io_state.dump_minute_id = io_state.minute_id;
      io_state.stage_minimum_ready_flag = (io_state.universe.eligible_universe>0 ? "true" : "false");
      io_state.stage_publishability_state = (io_state.publishable ? (io_state.degraded_flag ? "degraded" : "publishable") : "blocked");
      io_state.dependency_block_reason = (io_state.publishable ? "" : "no_active_universe");
      io_state.debug_weak_link_code = (io_state.degraded_flag ? "rankable_universe_empty" : "none");
     }

   static bool RunFullBuild(ISSX_EA1_State &io_state,
                            const bool include_custom_symbols=false,
                            const int max_symbols=0)
     {
      InitState(io_state);
      if(!DiscoverUniverse(io_state, include_custom_symbols, max_symbols))
         return false;
      BuildIdentityPhase(io_state);
      BuildRuntimePhase(io_state);
      BuildClassificationPhase(io_state);
      BuildTradeabilityPhase(io_state);
      BuildGateAndContinuityPhase(io_state);
      return true;
     }

   static bool StageBoot(ISSX_EA1_State &io_state,
                         const string firm_id,
                         const string writer_boot_id,
                         const string writer_nonce)
     {
      (void)firm_id;
      (void)writer_boot_id;
      (void)writer_nonce;
      InitState(io_state);
      io_state.resumed_from_persistence=false;
      io_state.stage_publishability_state="booting";
      io_state.stage_minimum_ready_flag="false";
      return true;
     }

   static bool StageSlice(ISSX_EA1_State &io_state,
                          const bool include_custom_symbols=false,
                          const int max_symbols=0)
     {
      bool ok = RunFullBuild(io_state,include_custom_symbols,max_symbols);
      io_state.stage_publishability_state = (ok ? (io_state.publishable ? (io_state.degraded_flag ? "degraded" : "publishable") : "blocked") : "error");
      io_state.stage_minimum_ready_flag = (ok && io_state.universe.eligible_universe>0 ? "true" : "false");
      return ok;
     }

   static bool StagePublish(ISSX_EA1_State &io_state,
                            const string firm_id,
                            const string writer_boot_id,
                            const string writer_nonce,
                            string &out_stage_json,
                            string &out_broker_dump_json,
                            string &out_debug_snapshot_json)
     {
      out_stage_json = BuildStageRootJson(io_state,firm_id,writer_boot_id,writer_nonce);
      out_broker_dump_json = BuildBrokerUniverseDumpJson(io_state,firm_id,writer_boot_id,writer_nonce);
      out_debug_snapshot_json = BuildDebugSnapshotJson(io_state,firm_id,writer_boot_id,writer_nonce);
      return true;
     }

   static string BuildBrokerUniverseDumpJson(const ISSX_EA1_State &state,
                                             const string firm_id,
                                             const string writer_boot_id,
                                             const string writer_nonce)
     {
      string json="{";
      json += ISSX_Json::KV("stage_id","ea1",true);
      json += ISSX_Json::KV("content_class","broker_universe_dump",true);
      json += ISSX_Json::KV("firm_id",firm_id,true);
      json += ISSX_Json::KV("schema_version",ISSX_SCHEMA_VERSION,true);
      json += ISSX_Json::KV("writer_boot_id",writer_boot_id,true);
      json += ISSX_Json::KV("writer_nonce",writer_nonce,true);
      json += ISSX_Json::KV("dump_sequence_no",state.dump_sequence_no,false,true);
      json += ISSX_Json::KV("dump_minute_id",state.dump_minute_id,false,true);
      json += ISSX_Json::KV("broker_universe",state.universe.broker_universe,false,true);
      json += ISSX_Json::KV("eligible_universe",state.universe.eligible_universe,false,true);
      json += ISSX_Json::KV("active_universe",state.universe.active_universe,false,true);
      json += ISSX_Json::KV("rankable_universe",state.universe.rankable_universe,false,true);
      json += ISSX_Json::KV("broker_universe_fingerprint",state.universe.broker_universe_fingerprint,true);
      json += ISSX_Json::KV("eligible_universe_fingerprint",state.universe.eligible_universe_fingerprint,true);
      json += ISSX_Json::KV("active_universe_fingerprint",state.universe.active_universe_fingerprint,true);
      json += ISSX_Json::KV("rankable_universe_fingerprint",state.universe.rankable_universe_fingerprint,true);
      json += ISSX_Json::KV("changed_symbol_count",state.deltas.changed_symbol_count,false,true);
      json += ISSX_Json::KV("changed_symbol_ids",state.deltas.changed_symbol_ids,true);
      json += "\"symbols\":[";
      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         const ISSX_EA1_SymbolState &s=state.symbols[i];
         if(i>0) json += ",";
         json += "{";
         json += ISSX_Json::KV("symbol_id",s.symbol_id,false,true);
         json += ISSX_Json::KV("symbol_raw",s.raw_broker_observation.symbol_raw,true);
         json += ISSX_Json::KV("symbol_norm",s.normalized_identity.symbol_norm,true);
         json += ISSX_Json::KV("canonical_root",s.normalized_identity.canonical_root,true);
         json += ISSX_Json::KV("runtime_truth_score",s.validated_runtime_truth.runtime_truth_score,false,true);
         json += ISSX_Json::KV("theme_bucket",s.classification_truth.theme_bucket,true);
         json += ISSX_Json::KV("tradability_now_class",s.tradeability_baseline.tradability_now_class,true);
         json += ISSX_Json::KV("gate_passed",s.rankability_gate.gate_passed,false,true);
         json += ISSX_Json::KV("lifecycle_state",(int)s.symbol_lifecycle.lifecycle_state,false,true);
         json += ISSX_Json::KV("drift_class",state.universe.universe_drift_class,true);
         json += ISSX_Json::KV("changed_symbol_state",s.changed_this_cycle,false,true);
         json += ISSX_Json::KV("symbol_discovery_state",s.raw_broker_observation.symbol_discovery_state,true);
         json += ISSX_Json::KV("symbol_selection_state",s.raw_broker_observation.symbol_selection_state,true);
         json += ISSX_Json::KV("symbol_synchronization_state",s.raw_broker_observation.symbol_synchronization_state,true);
         json += ISSX_Json::KV("property_read_status",s.raw_broker_observation.property_read_status,true);
         json += "}";
        }
      json += "]}";
      return json;
     }

   static string BuildDebugSnapshotJson(const ISSX_EA1_State &state,
                                        const string firm_id,
                                        const string writer_boot_id,
                                        const string writer_nonce)
     {
      string json="{";
      json += ISSX_Json::KV("stage_id","ea1",true);
      json += ISSX_Json::KV("firm_id",firm_id,true);
      json += ISSX_Json::KV("writer_boot_id",writer_boot_id,true);
      json += ISSX_Json::KV("writer_nonce",writer_nonce,true);
      json += ISSX_Json::KV("stage_minimum_ready_flag",state.stage_minimum_ready_flag,true);
      json += ISSX_Json::KV("stage_publishability_state",state.stage_publishability_state,true);
      json += ISSX_Json::KV("dependency_block_reason",state.dependency_block_reason,true);
      json += ISSX_Json::KV("debug_weak_link_code",state.debug_weak_link_code,true);
      json += ISSX_Json::KV("changed_symbol_count",state.deltas.changed_symbol_count,false,true);
      json += ISSX_Json::KV("broker_universe",state.universe.broker_universe,false,true);
      json += ISSX_Json::KV("eligible_universe",state.universe.eligible_universe,false,true);
      json += ISSX_Json::KV("active_universe",state.universe.active_universe,false,true);
      json += ISSX_Json::KV("rankable_universe",state.universe.rankable_universe,false,true);
      json += ISSX_Json::KV("percent_universe_touched_recent",state.universe.percent_universe_touched_recent,false,true);
      json += ISSX_Json::KV("percent_rankable_revalidated_recent",state.universe.percent_rankable_revalidated_recent,false,true);
      json += ISSX_Json::KV("percent_frontier_revalidated_recent",state.universe.percent_frontier_revalidated_recent,false,true);
      json += ISSX_Json::KV("never_serviced_count",state.universe.never_serviced_count,false,true);
      json += ISSX_Json::KV("overdue_service_count",state.universe.overdue_service_count,false,true);
      json += ISSX_Json::KV("newly_active_symbols_waiting_count",state.universe.newly_active_symbols_waiting_count,false,false);
      json += "}";
      return json;
     }

   static string BuildStageRootJson(const ISSX_EA1_State &state,
                                    const string firm_id,
                                    const string writer_boot_id,
                                    const string writer_nonce)
     {
      string json="{";
      json += ISSX_Json::KV("stage_id","ea1",true);
      json += ISSX_Json::KV("firm_id",firm_id,true);
      json += ISSX_Json::KV("schema_version",ISSX_SCHEMA_VERSION,true);
      json += ISSX_Json::KV("schema_epoch",ISSX_SCHEMA_EPOCH,false,true);
      json += ISSX_Json::KV("sequence_no",state.sequence_no,false,true);
      json += ISSX_Json::KV("minute_id",state.minute_id,false,true);
      json += ISSX_Json::KV("writer_boot_id",writer_boot_id,true);
      json += ISSX_Json::KV("writer_nonce",writer_nonce,true);
      json += ISSX_Json::KV("broker_universe",state.universe.broker_universe,false,true);
      json += ISSX_Json::KV("eligible_universe",state.universe.eligible_universe,false,true);
      json += ISSX_Json::KV("active_universe",state.universe.active_universe,false,true);
      json += ISSX_Json::KV("rankable_universe",state.universe.rankable_universe,false,true);
      json += ISSX_Json::KV("changed_symbol_count",state.deltas.changed_symbol_count,false,true);
      json += ISSX_Json::KV("changed_symbol_ids",state.deltas.changed_symbol_ids,true);
      json += ISSX_Json::KV("degraded_flag",state.degraded_flag,false,false);
      json += ISSX_Json::KV("publishable",state.publishable,false,false);
      json += "\"symbols\":[";
      for(int i=0;i<ArraySize(state.symbols);i++)
        {
         const ISSX_EA1_SymbolState &s=state.symbols[i];
         if(i>0) json += ",";
         json += "{";
         json += ISSX_Json::KV("symbol_id",s.symbol_id,false,true);
         json += ISSX_Json::KV("symbol_raw",s.raw_broker_observation.symbol_raw,true);
         json += ISSX_Json::KV("symbol_norm",s.normalized_identity.symbol_norm,true);
         json += ISSX_Json::KV("canonical_root",s.normalized_identity.canonical_root,true);
         json += ISSX_Json::KV("alias_family_id",s.normalized_identity.alias_family_id,true);
         json += ISSX_Json::KV("family_resolution_confidence",s.normalized_identity.family_resolution_confidence,false,true);
         json += ISSX_Json::KV("family_rep_stability_window",s.normalized_identity.family_rep_stability_window,false,true);
         json += ISSX_Json::KV("family_published_rep",s.normalized_identity.family_published_rep,true);
         json += ISSX_Json::KV("family_best_now",s.normalized_identity.family_best_now,true);
         json += ISSX_Json::KV("execution_profile_distinct_flag",s.normalized_identity.execution_profile_distinct_flag,false,true);
         json += ISSX_Json::KV("leader_bucket_id",s.classification_truth.leader_bucket_id,true);
         json += ISSX_Json::KV("leader_bucket_type",(int)s.classification_truth.leader_bucket_type,false,true);
         json += ISSX_Json::KV("tradeability_class",(int)s.tradeability_baseline.tradeability_class,false,true);
         json += ISSX_Json::KV("practical_market_state",(int)s.validated_runtime_truth.practical_market_state,false,true);
         json += ISSX_Json::KV("gate_passed",s.rankability_gate.gate_passed,false,false);
         json += ISSX_Json::KV("continuity_origin",(int)s.symbol_lifecycle.continuity_origin,false,false);
         json += ISSX_Json::KV("material_change_since_last_publish",s.symbol_lifecycle.material_change_since_last_publish,false,false);
         json += "\"classification\":{";
         json += ISSX_Json::KV("asset_class",s.classification_truth.asset_class,true);
         json += ISSX_Json::KV("instrument_family",s.classification_truth.instrument_family,true);
         json += ISSX_Json::KV("theme_bucket",s.classification_truth.theme_bucket,true);
         json += ISSX_Json::KV("equity_sector",s.classification_truth.equity_sector,true);
         json += ISSX_Json::KV("classification_confidence",s.classification_truth.classification_confidence,false,false);
         json += ISSX_Json::KV("classification_reliability_score",s.classification_truth.classification_reliability_score,false,false);
         json += ISSX_Json::KV("taxonomy_action_taken",(int)s.classification_truth.taxonomy_action_taken,false,false);
         json += "},";
         json += "\"runtime\":{";
         json += ISSX_Json::KV("runtime_truth_score",s.validated_runtime_truth.runtime_truth_score,false,true);
         json += ISSX_Json::KV("observation_density_score",s.validated_runtime_truth.observation_density_score,false,true);
         json += ISSX_Json::KV("spread_median_short_points",s.validated_runtime_truth.spread_median_short_points,false,true);
         json += ISSX_Json::KV("quote_stall_rate",s.validated_runtime_truth.quote_stall_rate,false,true);
         json += ISSX_Json::KV("session_truth_class",s.validated_runtime_truth.session_truth_class,true);
         json += ISSX_Json::KV("current_quote_liveness_state",s.validated_runtime_truth.current_quote_liveness_state,true);
         json += ISSX_Json::KV("current_friction_state",s.validated_runtime_truth.current_friction_state,true);
         json += ISSX_Json::KV("spread_state_vs_baseline",s.validated_runtime_truth.spread_state_vs_baseline,true);
         json += ISSX_Json::KV("activity_transition_state",s.validated_runtime_truth.activity_transition_state,true);
         json += ISSX_Json::KV("liquidity_ramp_state",s.validated_runtime_truth.liquidity_ramp_state,false,true);
         json += "},";
         json += "\"tradeability\":{";
         json += ISSX_Json::KV("structural_tradeability_score",s.tradeability_baseline.structural_tradeability_score,false,true);
         json += ISSX_Json::KV("live_tradeability_score",s.tradeability_baseline.live_tradeability_score,false,true);
         json += ISSX_Json::KV("blended_tradeability_score",s.tradeability_baseline.blended_tradeability_score,false,true);
         json += ISSX_Json::KV("all_in_cost_confidence",s.tradeability_baseline.all_in_cost_confidence,false,true);
         json += ISSX_Json::KV("tradability_now_class",s.tradeability_baseline.tradability_now_class,true,false);
         json += "}";
         json += "}";
        }
      json += "]}";
      return json;
     }
  };

#endif
