#property strict
#property version   "1.731"
#property description "ISSX single-wrapper consolidated kernel (safe attach wrapper)"

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_memory_guard.mqh>
#define ISSX_CONFIG_INPUTS_PROVIDED
#include <ISSX/issx_config.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_scheduler.mqh>
#include <ISSX/issx_persistence.mqh>
#include <ISSX/issx_data_handler.mqh>
#include <ISSX/issx_market_engine.mqh>
#include <ISSX/issx_history_engine.mqh>
#include <ISSX/issx_selection_engine.mqh>
#include <ISSX/issx_correlation_engine.mqh>
#include <ISSX/issx_contracts.mqh>
#include <ISSX/issx_menu.mqh>
#include <ISSX/issx_ui.mqh>
#include <ISSX/issx_debug_engine.mqh>
#include <ISSX/issx_error_codes.mqh>
#include <ISSX/issx_metrics.mqh>
#include <ISSX/issx_stage_registry.mqh>
#include <ISSX/issx_universe_manager.mqh>
#include <ISSX/issx_system_snapshot.mqh>
#include <ISSX/issx_telemetry.mqh>

input string InpFirmId                  = "default_firm";
input bool   InpIncludeCustomSymbols    = false;
input int    InpEA1MaxSymbols           = 2000;
input int    InpEA1HydrationBatchSize   = 25;
input bool   InpEA2DeepProfileDefault   = true;
input int    InpEA2MaxSymbolsPerSlice   = 128;
input bool   InpProjectStageStatusRoot  = true;
input bool   InpProjectUniverseSnapshot = true;
input bool   InpProjectDebugSnapshots   = true;
input int    InpLockStaleAfterSec       = 90;
input string InpInstanceTag             = "";

// debug / safety controls
input bool   InpSafeMode                = false; // true = attach + timer only, no kernel
input bool   InpRunFirstCycleInOnInit   = false; // keep false
input bool   InpBypassLocks             = true;  // keep true until lock logic is fixed
input bool   InpEnableEA1               = true;
input bool   InpEnableEA2               = false;
input bool   InpEnableEA3               = false;
input bool   InpEnableEA4               = false;
input bool   InpEnableEA5               = false;
input bool   InpIsolationMode            = true;  // force EA1-only during forensic pass

input bool   InpMinimalDebugMode        = false; // default: full EA1 foundation active
input bool   InpGateRuntimeScheduler    = true;  // enables runtime init + kernel pulse
input bool   InpGateTimerHeavyWork      = true;  // foundation default: enables ISSX_RunKernelCycle from timer
input bool   InpGateMenuEngine          = false;
input bool   InpGateChartUiUpdates      = false;
input bool   InpGateTickHeavyWork       = true;  // enables any non-trivial tick path
input bool   InpGateUiProjection        = true;  // foundation default: enable HUD projection
input bool   InpEnableRuntimeSchedulerLayer = false;
input int    InpSchedulerCycleBudgetMs  = 25;

ISSX_MemoryGuard   g_memory_guard;
ISSX_RegistryBundle   g_registry;
ISSX_StageRuntime     g_runtime;
ISSX_StageStateRegistry StageRegistry;
ISSX_Scheduler        g_scheduler;

ISSX_EA1_State      g_ea1;
ISSX_EA2_State      g_ea2;
ISSX_EA3_State      g_ea3;
ISSX_EA4_State      g_ea4;
ISSX_EA5_State      g_ea5;

ISSX_LockLease      g_lock;
string              g_boot_id                   = "";
string              g_instance_guid             = "";
string              g_writer_nonce              = "";
string              g_firm_id                   = "";
bool                g_bootstrapped              = false;
bool                g_runtime_ready             = false;
bool                g_first_cycle_done          = false;
bool                g_kernel_busy               = false;
long                g_writer_generation         = 0;
long                g_sequence_seed             = 0;
long                g_last_ea5_export_minute_id = 0;
ISSX_DebugEngine    g_debug;
ISSX_UI             g_ui;
ISSX_MenuEngine     g_menu;
ISSX_Config         Config;
ISSX_TelemetryEngine g_telemetry;
ISSX_MetricsBook    g_metrics;
ISSX_InfraStageRegistry g_stage_registry_infra;
string              g_last_system_snapshot = "";
bool                g_ea_enabled[5]={true,false,false,false,false};
string              g_last_checkpoint           = "boot";
bool                g_first_tick_logged         = false;
bool                g_first_timer_logged        = false;
bool                g_first_chart_event_logged  = false;
ulong               g_timer_pulse_count         = 0;
ulong               g_last_comment_pulse        = 0;
string              g_last_status_comment       = "";
bool                g_logged_timer_heavy_skip   = false;
bool                g_logged_tick_heavy_skip    = false;
bool                g_menu_initialized          = false;
ulong               g_timer_skip_runtime_not_ready_count = 0;
ulong               g_timer_skip_kernel_busy_count       = 0;
string              g_last_feature_runtime_scheduler = "";
string              g_last_feature_timer_heavy       = "";
string              g_last_feature_init_runtime_scheduler = "";
string              g_last_feature_run_tick_heavy         = "";
string              g_last_kernel_result             = "unknown";
string              g_last_kernel_reason             = "none";
long                g_last_kernel_elapsed_ms         = 0;
string              g_last_ea1_stage_run             = "skipped";
string              g_last_ea1_stage_reason          = "none";
long                g_last_ea1_stage_elapsed_ms      = 0;
string              g_last_ea2_stage_run             = "skipped";
string              g_last_ea2_stage_reason          = "none";
long                g_last_ea2_stage_elapsed_ms      = 0;
string              g_last_ea3_stage_run             = "skipped";
string              g_last_ea3_stage_reason          = "none";
long                g_last_ea3_stage_elapsed_ms      = 0;
string              g_last_ea4_stage_run             = "skipped";
string              g_last_ea4_stage_reason          = "none";
long                g_last_ea4_stage_elapsed_ms      = 0;
string              g_last_ea5_stage_run             = "skipped";
string              g_last_ea5_stage_reason          = "none";
long                g_last_ea5_stage_elapsed_ms      = 0;
string              g_last_ea1_publish_state         = "unknown";
string              g_last_ea1_publish_reason        = "none";
string              g_last_ea1_stage_json_state      = "unknown";
string              g_last_ea1_debug_json_state      = "unknown";
string              g_last_ea1_universe_build_state  = "unknown";
string              g_last_ea1_stage_write_state     = "unknown";
string              g_last_ea1_debug_write_state     = "unknown";
string              g_last_ea1_universe_write_state  = "unknown";
string              g_last_ea1_root_debug_state      = "unknown";
string              g_last_ea1_root_status_state     = "unknown";
string              g_last_ea1_root_universe_state   = "unknown";
int                 g_last_deinit_reason_code      = -1;
string              g_last_deinit_reason_text      = "none";
string              g_last_chart_action            = "none";
string              g_operator_server_name         = "";
string              g_operator_server_name_safe    = "";
string              g_operator_broker_name         = "";
long                g_operator_login_id            = 0;
string              g_market_json_file_name        = "";
string              g_market_log_file_name         = "";
string              g_market_json_relative_path    = "";
string              g_market_log_relative_path     = "";
string              g_operator_root_relative       = "ISSX";
string              g_startup_profile           = "unknown";

string ISSX_LongIdPart(const long value)
  {
   return ISSX_Util::LongToStringX(value);
  }

string ISSX_ULongIdPart(const ulong value)
  {
   return ISSX_Util::ULongToStringX(value);
  }

string ISSX_MakeTrioGenerationId(const long writer_generation,const long sequence_no)
  {
   return ISSX_LongIdPart(writer_generation)+"_"+ISSX_LongIdPart(sequence_no);
  }

long ISSX_CurrentKernelMinuteId()
  {
   long minute_id=(long)g_runtime.State().kernel.kernel_minute_id;
   if(minute_id<=0)
      minute_id=ISSX_Time::NowMinuteId();
   return minute_id;
  }

bool ISSX_IsEA5ExportDue(const long minute_id)
  {
   if(minute_id<=0)
      return false;
   if(g_last_ea5_export_minute_id<=0)
      return true;
   return ((minute_id-g_last_ea5_export_minute_id) >= ISSX_EA5_EXPORT_CADENCE_MIN);
  }

string ISSX_WrapperBootId()
  {
   return "boot_"+ISSX_LongIdPart((long)TimeLocal())+"_"+ISSX_LongIdPart((long)ChartID());
  }

string ISSX_WrapperInstanceGuid()
  {
   return "inst_"+ISSX_ULongIdPart((ulong)GetTickCount64())+"_"+ISSX_LongIdPart((long)MathRand());
  }

string ISSX_WrapperNonce()
  {
   return "nonce_"+ISSX_ULongIdPart((ulong)GetTickCount64())+"_"+ISSX_LongIdPart((long)MathRand());
  }

string ISSX_WrapperTerminalIdentity()
  {
   string company=TerminalInfoString(TERMINAL_COMPANY);
   string name=TerminalInfoString(TERMINAL_NAME);
   string path=TerminalInfoString(TERMINAL_PATH);
   return company+"|"+name+"|"+path;
  }

string ISSX_ResolveFirmId()
  {
   if(StringLen(Config.GetString("firm_id"))>0 && Config.GetString("firm_id")!="default_firm")
      return Config.GetString("firm_id");

   string broker=AccountInfoString(ACCOUNT_COMPANY);
   string server=AccountInfoString(ACCOUNT_SERVER);

   string id=broker+"_"+server;

   StringReplace(id," ","_");
   StringReplace(id,".","_");
   StringReplace(id,"-","_");
   StringReplace(id,"/","_");
   StringReplace(id,"\\","_");
   StringReplace(id,":","_");
   StringReplace(id,";","_");
   StringReplace(id,",","_");
   StringReplace(id,"|","_");
   StringReplace(id,"*","_");
   StringReplace(id,"?","_");
   StringReplace(id,"\"","_");
   StringReplace(id,"<","_");
   StringReplace(id,">","_");

   while(StringFind(id,"__")>=0)
      StringReplace(id,"__","_");

   if(StringLen(id)<=0)
      id="unknown_broker";

   return ISSX_OperatorSurface::SanitizeServerName(id);
  }

bool ISSX_BoolFromLooseString(const string v)
  {
   string t=ISSX_Util::Lower(ISSX_Util::Trim(v));
   return (t=="true" || t=="1" || t=="yes");
  }

ISSX_PublishabilityState ISSX_EA1PublishabilityToEnum(const string state_text)
  {
   string t=ISSX_Util::Lower(ISSX_Util::Trim(state_text));
   if(t=="strong")
      return issx_publishability_strong;
   if(t=="usable")
      return issx_publishability_usable;
   if(t=="usable_degraded" || t=="degraded")
      return issx_publishability_usable_degraded;
   if(t=="warmup" || t=="booting")
      return issx_publishability_warmup;
   return issx_publishability_not_ready;
  }

void ISSX_SeedHeader(ISSX_StageHeader &header,
                     const ISSX_StageId stage_id,
                     const long minute_id,
                     const int symbol_count,
                     const int changed_symbol_count,
                     const bool degraded_flag,
                     const int fallback_depth_used,
                     const string cohort_fingerprint,
                     const string universe_fingerprint,
                     const string policy_fingerprint)
  {
   header.Reset();
   header.stage_id=stage_id;
   header.firm_id=g_firm_id;
   header.minute_id=minute_id;
   header.sequence_no=++g_sequence_seed;
   header.writer_boot_id=g_boot_id;
   header.writer_nonce=g_writer_nonce;
   header.writer_generation=++g_writer_generation;
   header.trio_generation_id=ISSX_MakeTrioGenerationId(header.writer_generation,header.sequence_no);
   header.symbol_count=symbol_count;
   header.changed_symbol_count=changed_symbol_count;
   header.degraded_flag=degraded_flag;
   header.fallback_depth_used=fallback_depth_used;
   header.cohort_fingerprint=cohort_fingerprint;
   header.universe_fingerprint=universe_fingerprint;
   header.policy_fingerprint=policy_fingerprint;
   header.fingerprint_algorithm_version=ISSX_FINGERPRINT_ALGO_VERSION;
  }

void ISSX_SeedManifest(ISSX_Manifest &manifest,
                       const ISSX_StageHeader &header,
                       const ISSX_ContentClass content_class,
                       const ISSX_PublishReason publish_reason,
                       const ISSX_PublishabilityState publishability_state,
                       const bool minimum_ready_flag,
                       const int accepted_strong_count,
                       const int accepted_degraded_count)
  {
   manifest.Reset();
   manifest.stage_id=header.stage_id;
   manifest.firm_id=g_firm_id;
   manifest.sequence_no=header.sequence_no;
   manifest.minute_id=header.minute_id;
   manifest.writer_boot_id=header.writer_boot_id;
   manifest.writer_nonce=header.writer_nonce;
   manifest.writer_generation=header.writer_generation;
   manifest.trio_generation_id=header.trio_generation_id;
   manifest.symbol_count=header.symbol_count;
   manifest.changed_symbol_count=header.changed_symbol_count;
   manifest.content_class=content_class;
   manifest.publish_reason=publish_reason;
   manifest.cohort_fingerprint=header.cohort_fingerprint;
   manifest.policy_fingerprint=header.policy_fingerprint;
   manifest.fingerprint_algorithm_version=header.fingerprint_algorithm_version;
   manifest.universe_fingerprint=header.universe_fingerprint;
   manifest.degraded_flag=header.degraded_flag;
   manifest.fallback_depth_used=header.fallback_depth_used;
   manifest.accepted_strong_count=accepted_strong_count;
   manifest.accepted_degraded_count=accepted_degraded_count;
   manifest.stage_minimum_ready_flag=minimum_ready_flag;
   manifest.stage_publishability_state=publishability_state;
   manifest.handoff_mode=issx_handoff_internal_current;
   manifest.handoff_sequence_no=header.sequence_no;
  }

bool ISSX_PersistStageJson(const ISSX_StageId stage_id,
                           ISSX_StageHeader &header,
                           ISSX_Manifest &manifest,
                           const string payload_json)
  {
   if(StringLen(payload_json)<=2)
     {
      Print("ISSX: persist skipped, payload too small stage=",ISSX_StageIdToString(stage_id));
      return false;
     }

   if(!ISSX_SnapshotFlow::WriteCandidate(g_firm_id,stage_id,header,payload_json,manifest))
     {
      Print("ISSX: WriteCandidate failed stage=",ISSX_StageIdToString(stage_id));
      return false;
     }

   ISSX_StageHeader verify_header;
   ISSX_Manifest verify_manifest;
   string verify_payload="";
   verify_header.Reset();
   verify_manifest.Reset();

   if(!ISSX_SnapshotFlow::LoadCandidate(g_firm_id,stage_id,verify_header,verify_manifest,verify_payload))
     {
      Print("ISSX: LoadCandidate failed stage=",ISSX_StageIdToString(stage_id));
      return false;
     }

   if(!ISSX_Coherence::CandidateTrioCoherent(verify_header,verify_manifest,verify_payload))
     {
      Print("ISSX: CandidateTrioCoherent failed stage=",ISSX_StageIdToString(stage_id));
      return false;
     }

   ISSX_ProjectionOutcome outcome;
   outcome.Reset();

   if(!ISSX_SnapshotFlow::PromoteCandidate(g_firm_id,stage_id,manifest,outcome))
     {
      Print("ISSX: PromoteCandidate failed stage=",ISSX_StageIdToString(stage_id));
      return false;
     }

   ISSX_SnapshotFlow::PromoteLastGoodIfEligible(g_firm_id,stage_id,manifest);
   return true;
  }

int ISSX_CopyEA1Symbols(string &symbols[])
  {
   ArrayResize(symbols,0);
   const int n=ArraySize(g_ea1.symbols);
   if(n<=0)
      return 0;

   if(ArrayResize(symbols,n)!=n)
      return 0;

   int used=0;
   for(int i=0;i<n;i++)
     {
      string s=g_ea1.symbols[i].normalized_identity.symbol_norm;
      if(StringLen(s)==0)
         s=g_ea1.symbols[i].raw_broker_observation.symbol_raw;
      if(StringLen(s)==0)
         continue;
      symbols[used++]=s;
     }

   ArrayResize(symbols,used);
   return used;
  }

string ISSX_StageAlias(const ISSX_StageId stage_id)
  {
   return ISSX_OperatorSurface::StageAlias(stage_id);
  }

string ISSX_EA1StageStateFromRun(const string stage_run)
  {
   const string v=ISSX_Util::Lower(ISSX_Util::Trim(stage_run));
   if(v=="success")
      return ISSX_StageStateRegistry::StateToString(STAGE_READY);
   if(v=="degraded")
      return ISSX_StageStateRegistry::StateToString(STAGE_DEGRADED);
   if(v=="failed")
      return ISSX_StageStateRegistry::StateToString(STAGE_FAILED);
   if(v=="skipped")
      return ISSX_StageStateRegistry::StateToString(STAGE_SKIPPED);
   if(v=="running")
      return ISSX_StageStateRegistry::StateToString(STAGE_RUNNING);
   if(v=="init")
      return ISSX_StageStateRegistry::StateToString(STAGE_INIT);
   return ISSX_StageStateRegistry::StateToString(STAGE_OFF);
  }

int ISSX_EA1StageCodeFromRun(const string stage_run)
  {
   const string v=ISSX_Util::Lower(ISSX_Util::Trim(stage_run));
   if(v=="success")
      return STAGE_READY;
   if(v=="degraded")
      return STAGE_DEGRADED;
   if(v=="failed")
      return STAGE_FAILED;
   if(v=="skipped")
      return STAGE_SKIPPED;
   if(v=="running")
      return STAGE_RUNNING;
   if(v=="init")
      return STAGE_INIT;
   return STAGE_OFF;
  }

int ISSX_HealthCodeFromState(const int stage_state)
  {
   if(stage_state==STAGE_FAILED)
      return STAGE_HEALTH_FAILED;
   if(stage_state==STAGE_DEGRADED)
      return STAGE_HEALTH_DEGRADED;
   if(stage_state==STAGE_READY)
      return STAGE_HEALTH_HEALTHY;
   return STAGE_HEALTH_UNKNOWN;
  }

void ISSX_SyncEA1StageRegistry(const string stage_run,const string stage_reason,const long elapsed_ms,const bool emit_diag)
  {
   const string stage_name="ea1_market";
   const int stage_code=ISSX_EA1StageCodeFromRun(stage_run);
   const int health_code=ISSX_HealthCodeFromState(stage_code);

   const bool state_changed=StageRegistry.SetState(stage_name,stage_code);
   const bool reason_changed=StageRegistry.SetReason(stage_name,stage_reason);
   const bool elapsed_changed=StageRegistry.SetElapsed(stage_name,elapsed_ms);
   const bool health_changed=StageRegistry.SetHealth(stage_name,health_code);

   if(!emit_diag)
      return;

   if(state_changed || health_changed)
      g_debug.Write("INFO","stage_registry_update",stage_name,
                    "state="+ISSX_StageStateRegistry::StateToString(StageRegistry.GetState(stage_name))+
                    " health="+ISSX_StageStateRegistry::HealthToString(StageRegistry.GetHealth(stage_name)));

   if(reason_changed)
      g_debug.Write("INFO","stage_registry_reason",stage_name,StageRegistry.GetReason(stage_name));

   if(elapsed_changed)
      g_debug.Write("INFO","stage_registry_elapsed",stage_name,IntegerToString((int)StageRegistry.GetElapsed(stage_name)));
  }

void ISSX_ResolveOperatorContext()
  {
   g_operator_broker_name=AccountInfoString(ACCOUNT_COMPANY);
   g_operator_server_name=AccountInfoString(ACCOUNT_SERVER);
   if(ISSX_Util::IsEmpty(g_operator_server_name))
      g_operator_server_name="Unknown Server";
   g_operator_server_name_safe=ISSX_OperatorSurface::SanitizeServerName(g_operator_server_name);
   g_operator_login_id=(long)AccountInfoInteger(ACCOUNT_LOGIN);
   g_market_json_file_name=ISSX_OperatorSurface::OperatorFileName(issx_stage_ea1,g_operator_server_name,ISSX_JSON_EXT);
   g_market_log_file_name=ISSX_OperatorSurface::OperatorFileName(issx_stage_ea1,g_operator_server_name,".log");
   g_market_json_relative_path=ISSX_Util::JoinPath(g_operator_root_relative,g_market_json_file_name);
   g_market_log_relative_path=ISSX_Util::JoinPath(g_operator_root_relative,g_market_log_file_name);
  }

string ISSX_BuildEA1StageStatusJson()
  {
   ISSX_JsonWriter j;
   j.BeginObject();
   j.NameString("stage_alias",ISSX_StageAlias(issx_stage_ea1));
   j.NameString("internal_stage_id","ea1");
   j.NameString("stage_run",ISSX_EA1StageStateFromRun(g_last_ea1_stage_run));
   j.NameString("stage_reason",StageRegistry.GetReason("ea1_market"));
   j.NameInt("stage_elapsed_ms",(int)StageRegistry.GetElapsed("ea1_market"));
   j.NameString("publish_state",g_last_ea1_publish_state);
   j.NameString("publish_reason",g_last_ea1_publish_reason);
   j.NameBool("requested",Config.GetBool("ea1_enabled"));
   j.NameBool("effective",g_ea_enabled[0]);
   j.EndObject();
   return j.ToString();
  }

void ISSX_ResetEA1PublishStatus()
  {
   g_last_ea1_publish_state="unknown";
   g_last_ea1_publish_reason="none";
   g_last_ea1_stage_json_state="unknown";
   g_last_ea1_debug_json_state="unknown";
   g_last_ea1_universe_build_state="unknown";
   g_last_ea1_stage_write_state="unknown";
   g_last_ea1_debug_write_state="unknown";
   g_last_ea1_universe_write_state="unknown";
   g_last_ea1_root_debug_state="unknown";
   g_last_ea1_root_status_state="unknown";
   g_last_ea1_root_universe_state="unknown";
  }

void ISSX_ConvertEA4OptionalIntelligence(const ISSX_EA4_OptionalIntelligenceExport &src[],
                                         ISSX_EA5_OptionalIntelligence &dst[])
  {
   ArrayResize(dst,0);
   const int n=ArraySize(src);
   if(n<=0)
      return;

   if(ArrayResize(dst,n)!=n)
      return;

   for(int i=0;i<n;i++)
     {
      dst[i].Reset();
      dst[i].symbol_norm=src[i].symbol_norm;
      dst[i].present=true;
      dst[i].nearest_peer_similarity=src[i].nearest_peer_similarity;
      dst[i].corr_valid=src[i].corr_valid;
      dst[i].corr_quality_score=src[i].corr_quality_score;
      dst[i].corr_reject_reason=src[i].corr_reject_reason;
      dst[i].duplicate_penalty_applied=src[i].duplicate_penalty_applied;
      dst[i].corr_penalty_applied=src[i].corr_penalty_applied;
      dst[i].session_overlap_penalty_applied=src[i].session_overlap_penalty_applied;
      dst[i].diversification_bonus_applied=src[i].diversification_bonus_applied;
      dst[i].adjustment_confidence=src[i].adjustment_confidence;
      dst[i].portfolio_role_hint=src[i].portfolio_role_hint;
      dst[i].structural_overlap_score=src[i].structural_overlap_score;
      dst[i].statistical_overlap_score=src[i].statistical_overlap_score;
      dst[i].intelligence_abstained=src[i].intelligence_abstained;
      dst[i].abstention_reason=src[i].abstention_reason;
      dst[i].intelligence_confidence=src[i].intelligence_confidence;
      dst[i].intelligence_coverage_score=src[i].intelligence_coverage_score;
      dst[i].pair_cache_status=src[i].pair_cache_status;
      dst[i].pair_cache_reuse_block_reason=src[i].pair_cache_reuse_block_reason;
     }
  }

bool ISSX_ProjectEA1(const string stage_json,
                     const string broker_dump_json,
                     const string debug_snapshot_json,
                     string &out_reason)
  {
   out_reason="ok";
   ISSX_ResetEA1PublishStatus();

   g_debug.Write("INFO","ea1_publish","publish_prepare_operator_paths_start",
                 "checkpoint=publish_prepare_operator_paths_start root="+g_operator_root_relative+" json="+g_market_json_relative_path+" log="+g_market_log_relative_path);
   const bool operator_paths_ok=(StringLen(g_market_json_relative_path)>0 && StringLen(g_market_log_relative_path)>0);
   g_debug.Write((operator_paths_ok?"INFO":"ERROR"),"ea1_publish",(operator_paths_ok?"publish_prepare_operator_paths_ok":"publish_prepare_operator_paths_fail"),
                 "json_path="+g_market_json_relative_path+" log_path="+g_market_log_relative_path+" reason="+(operator_paths_ok?"ok":"empty_operator_path"));

   const bool stage_json_ok=(StringLen(stage_json)>2);
   const bool debug_json_ok=(StringLen(debug_snapshot_json)>2);
   const bool universe_json_ok=(StringLen(broker_dump_json)>2 || g_ea1.hydration_complete);

   g_last_ea1_stage_json_state=(stage_json_ok?"success":"failed");
   g_last_ea1_debug_json_state=(debug_json_ok?"success":"failed");
   g_last_ea1_universe_build_state=(universe_json_ok?"success":"failed");

   if(!stage_json_ok || !debug_json_ok || !universe_json_ok || !operator_paths_ok)
     {
      out_reason="build_or_paths_failed";
      g_last_ea1_publish_state="failed";
      g_last_ea1_publish_reason=out_reason;
      g_debug.Write("ERROR","ea1_publish","publish_failed",
                    "reason="+out_reason+" stage_json_len="+IntegerToString(StringLen(stage_json))+" debug_json_len="+IntegerToString(StringLen(debug_snapshot_json))+" market_json_len="+IntegerToString(StringLen(broker_dump_json)));
      return false;
     }

   ISSX_StageHeader header;
   ISSX_Manifest manifest;

   ISSX_SeedHeader(header,issx_stage_ea1,(long)g_ea1.minute_id,ArraySize(g_ea1.symbols),g_ea1.deltas.changed_symbol_count,g_ea1.degraded_flag,0,
                   g_ea1.cohort_fingerprint,g_ea1.universe.broker_universe_fingerprint,g_registry.SchemaFingerprintHex());

   const ISSX_PublishabilityState pub=ISSX_EA1PublishabilityToEnum(g_ea1.stage_publishability_state);
   ISSX_SeedManifest(manifest,header,issx_content_partial,issx_publish_scheduled,pub,g_ea1.stage_minimum_ready_flag,(g_ea1.publishable ? 1 : 0),(g_ea1.degraded_flag ? 1 : 0));
   manifest.taxonomy_hash=g_ea1.taxonomy_hash;
   manifest.comparator_registry_hash=g_ea1.comparator_registry_hash;

   g_debug.Write("INFO","ea1_publish","publish_persistence_handoff_start","checkpoint=publish_persistence_handoff_start owner=persistence stage=ea1");

   g_debug.Write("INFO","ea1_publish","publish_stage_write_start","path="+ISSX_PersistencePath::PayloadCurrent(g_firm_id,issx_stage_ea1)+" bytes="+IntegerToString(StringLen(stage_json)));
   const bool stage_write_ok=ISSX_PersistStageJson(issx_stage_ea1,header,manifest,stage_json);
   g_debug.Write((stage_write_ok?"INFO":"ERROR"),"ea1_publish",(stage_write_ok?"publish_persistence_handoff_success":"publish_persistence_handoff_fail"),"checkpoint="+(stage_write_ok?"publish_persistence_handoff_success":"publish_persistence_handoff_fail")+" stage=ea1");
   g_last_ea1_stage_write_state=(stage_write_ok?"success":"failed");
   g_debug.Write((stage_write_ok?"INFO":"ERROR"),"ea1_publish",(stage_write_ok?"publish_stage_write_success":"publish_stage_write_fail"),
                 "path="+ISSX_PersistencePath::PayloadCurrent(g_firm_id,issx_stage_ea1)+" reason="+(stage_write_ok?"ok":"persist_stage_json_failed"));

   bool universe_rotate_ok=true;
   bool universe_write_ok=true;
   string universe_current_path=ISSX_Util::JoinPath(ISSX_PersistencePath::UniverseDir(g_firm_id),ISSX_BIN_BROKER_UNIVERSE_CURRENT);
   if(StringLen(broker_dump_json)>2)
     {
      g_debug.Write("INFO","ea1_publish","publish_universe_write_start","checkpoint=publish_universe_write_start path="+universe_current_path+" owner=persistence");
      universe_rotate_ok=ISSX_BrokerUniverseDump::RotateCurrentToPrevious(g_firm_id);
      universe_write_ok=ISSX_BrokerUniverseDump::WriteCurrent(g_firm_id,broker_dump_json,manifest,true);
      g_debug.Write(((universe_rotate_ok && universe_write_ok)?"INFO":"ERROR"),"ea1_publish",((universe_rotate_ok && universe_write_ok)?"publish_universe_write_success":"publish_universe_write_fail"),
                    "path="+universe_current_path+" rotate="+(universe_rotate_ok?"ok":"fail")+" write="+(universe_write_ok?"ok":"fail")+" owner=persistence");
     }
   else
     {
      universe_write_ok=ISSX_FileIO::Exists(universe_current_path);
     }
   g_last_ea1_universe_write_state=((universe_rotate_ok && universe_write_ok)?"success":"failed");

   bool debug_write_ok=true;
   g_debug.Write("INFO","ea1_publish","publish_debug_write_start","checkpoint=publish_debug_write_start owner=persistence stage=ea1_debug_snapshot");
   if(Config.GetBool("project_debug_snapshots"))
      debug_write_ok=ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea1,debug_snapshot_json);
   g_last_ea1_debug_write_state=(debug_write_ok?"success":"failed");
   g_debug.Write((debug_write_ok?"INFO":"ERROR"),"ea1_publish",(debug_write_ok?"publish_debug_write_success":"publish_debug_write_fail"),
                 "owner=persistence enabled="+ISSX_OnOff(Config.GetBool("project_debug_snapshots"))+" state="+g_last_ea1_debug_write_state);

   ISSX_DataHandler::ForensicState fs_market;
   fs_market.Reset();
   g_debug.Write("INFO","ea1_publish","publish_root_status_write_start","checkpoint=publish_root_status_write_start final_path="+g_market_json_relative_path+" bytes="+IntegerToString(ISSX_DataHandler::EstimateUtf8Bytes(broker_dump_json)));
   bool operator_json_ok=false;
   if(StringLen(broker_dump_json)>2)
      operator_json_ok=ISSX_DataHandler::WritePayloadAtomic(g_market_json_relative_path,broker_dump_json,fs_market,true);
   else
      operator_json_ok=ISSX_DataHandler::CopyProjection(universe_current_path,g_market_json_relative_path,fs_market);
   g_last_ea1_root_status_state=(operator_json_ok?"success":"failed");
   g_debug.Write((operator_json_ok?"INFO":"ERROR"),"ea1_publish",(operator_json_ok?"publish_root_status_write_success":"publish_root_status_write_fail"),
                 "checkpoint="+fs_market.checkpoint+" temp_path="+fs_market.temp_path+" final_path="+fs_market.final_path+" bytes_attempted="+IntegerToString(fs_market.payload_bytes_attempted)+" bytes_written="+IntegerToString(fs_market.payload_bytes_written)+" open_err="+IntegerToString(fs_market.open_error)+" write_err="+IntegerToString(fs_market.write_error)+" move_err="+IntegerToString(fs_market.move_error)+" copy_err="+IntegerToString(fs_market.copy_error)+" delete_err="+IntegerToString(fs_market.delete_error));

   ISSX_DataHandler::ForensicState fs_debug;
   fs_debug.Reset();
   g_debug.Write("INFO","ea1_publish","publish_root_debug_write_start","checkpoint=publish_root_debug_write_start src="+g_debug.ActivePath()+" dst="+g_market_log_relative_path);
   const bool operator_log_projection_ok=ISSX_DataHandler::CopyProjection(g_debug.ActivePath(),g_market_log_relative_path,fs_debug);
   g_last_ea1_root_debug_state=(operator_log_projection_ok?"success":"failed");
   g_debug.Write((operator_log_projection_ok?"INFO":"ERROR"),"ea1_publish",(operator_log_projection_ok?"publish_root_debug_write_success":"publish_root_debug_write_fail"),
                 "checkpoint="+fs_debug.checkpoint+" src="+fs_debug.temp_path+" dst="+fs_debug.final_path+" copy_err="+IntegerToString(fs_debug.copy_error));

   g_debug.Write("INFO","ea1_publish","publish_root_projection_start","json="+g_market_json_relative_path+" log="+g_market_log_relative_path);
   const bool root_projection_ok=(operator_json_ok && operator_log_projection_ok);
   if(!root_projection_ok)
      g_debug.Write("WARN","ea1_publish","publish_degraded","reason=root_projection_failed");
   g_last_ea1_root_universe_state="skipped";
   g_debug.Write((root_projection_ok?"INFO":"ERROR"),"ea1_publish",(root_projection_ok?"publish_root_projection_ok":"publish_root_projection_fail"),
                 "json="+g_last_ea1_root_status_state+" log="+g_last_ea1_root_debug_state);

   const bool publish_ok=(stage_write_ok && debug_write_ok && universe_rotate_ok && universe_write_ok && root_projection_ok);
   g_ea1.publish_payload_bytes_written=(publish_ok ? (g_ea1.publish_stage_json_bytes+g_ea1.publish_debug_json_bytes+g_ea1.publish_universe_json_bytes) : 0);
   g_last_ea1_publish_state=(publish_ok?"success":"degraded");
   g_last_ea1_publish_reason=(publish_ok?"ok":"stage="+g_last_ea1_stage_write_state+" debug="+g_last_ea1_debug_write_state+" universe="+g_last_ea1_universe_write_state+" root_json="+g_last_ea1_root_status_state+" root_log="+g_last_ea1_root_debug_state);
   out_reason=g_last_ea1_publish_reason;

   g_debug.Write((publish_ok?"INFO":"ERROR"),"ea1_publish",(publish_ok?"publish_complete":"publish_failed"),
                 "reason="+out_reason+" internal="+g_last_ea1_stage_write_state+" universe="+g_last_ea1_universe_write_state+" debug="+g_last_ea1_debug_write_state+" root_json="+g_last_ea1_root_status_state+" root_log="+g_last_ea1_root_debug_state);
   return publish_ok;
  }


void ISSX_ProjectEA2(const string stage_json,
                     const string debug_snapshot_json)
  {
   g_ea2.header.writer_boot_id=g_boot_id;
   g_ea2.header.writer_nonce=g_writer_nonce;
   if(g_ea2.header.writer_generation<=0)
      g_ea2.header.writer_generation=++g_writer_generation;
   if(g_ea2.header.sequence_no<=0)
      g_ea2.header.sequence_no=++g_sequence_seed;
   if(g_ea2.header.trio_generation_id=="")
      g_ea2.header.trio_generation_id=ISSX_MakeTrioGenerationId(g_ea2.header.writer_generation,g_ea2.header.sequence_no);

   g_ea2.header.policy_fingerprint=g_registry.SchemaFingerprintHex();
   g_ea2.manifest.taxonomy_hash=g_ea1.taxonomy_hash;
   g_ea2.manifest.comparator_registry_hash=g_ea1.comparator_registry_hash;

   ISSX_PersistStageJson(issx_stage_ea2,g_ea2.header,g_ea2.manifest,stage_json);

   if(Config.GetBool("project_debug_snapshots"))
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea2,debug_snapshot_json);
  }

void ISSX_ProjectEA3(const string stage_json,
                     const string debug_snapshot_json)
  {
   g_ea3.header.writer_boot_id=g_boot_id;
   g_ea3.header.writer_nonce=g_writer_nonce;
   if(g_ea3.header.writer_generation<=0)
      g_ea3.header.writer_generation=++g_writer_generation;
   if(g_ea3.header.sequence_no<=0)
      g_ea3.header.sequence_no=++g_sequence_seed;
   if(g_ea3.header.trio_generation_id=="")
      g_ea3.header.trio_generation_id=ISSX_MakeTrioGenerationId(g_ea3.header.writer_generation,g_ea3.header.sequence_no);

   g_ea3.header.policy_fingerprint=g_registry.SchemaFingerprintHex();

   ISSX_PersistStageJson(issx_stage_ea3,g_ea3.header,g_ea3.manifest,stage_json);

   if(Config.GetBool("project_debug_snapshots"))
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea3,debug_snapshot_json);
  }

void ISSX_ProjectEA4(const string stage_json,
                     const string debug_snapshot_json)
  {
   g_ea4.header.writer_boot_id=g_boot_id;
   g_ea4.header.writer_nonce=g_writer_nonce;
   if(g_ea4.header.writer_generation<=0)
      g_ea4.header.writer_generation=++g_writer_generation;
   if(g_ea4.header.sequence_no<=0)
      g_ea4.header.sequence_no=++g_sequence_seed;
   if(g_ea4.header.trio_generation_id=="")
      g_ea4.header.trio_generation_id=ISSX_MakeTrioGenerationId(g_ea4.header.writer_generation,g_ea4.header.sequence_no);

   g_ea4.header.policy_fingerprint=g_registry.SchemaFingerprintHex();

   ISSX_PersistStageJson(issx_stage_ea4,g_ea4.header,g_ea4.manifest,stage_json);

   if(Config.GetBool("project_debug_snapshots"))
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea4,debug_snapshot_json);
  }

void ISSX_ProjectEA5(const string export_json,
                     const string debug_json)
  {
   g_ea5.header.writer_boot_id=g_boot_id;
   g_ea5.header.writer_nonce=g_writer_nonce;
   if(g_ea5.header.writer_generation<=0)
      g_ea5.header.writer_generation=++g_writer_generation;
   if(g_ea5.header.sequence_no<=0)
      g_ea5.header.sequence_no=++g_sequence_seed;
   if(g_ea5.header.trio_generation_id=="")
      g_ea5.header.trio_generation_id=ISSX_MakeTrioGenerationId(g_ea5.header.writer_generation,g_ea5.header.sequence_no);

   g_ea5.header.policy_fingerprint=g_registry.SchemaFingerprintHex();

   ISSX_PersistStageJson(issx_stage_ea5,g_ea5.header,g_ea5.manifest,export_json);
   ISSX_FileIO::WriteTextAtomic(ISSX_PersistencePath::RootExport(g_firm_id),export_json);

   if(Config.GetBool("project_debug_snapshots"))
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea5,debug_json);
  }


string ISSX_DeinitReasonText(const int reason)
  {
   switch(reason)
     {
      case REASON_PROGRAM:    return "program_remove";
      case REASON_REMOVE:     return "user_remove";
      case REASON_RECOMPILE:  return "recompile";
      case REASON_CHARTCHANGE:return "chart_change";
      case REASON_CHARTCLOSE: return "chart_close";
      case REASON_PARAMETERS: return "inputs_change";
      case REASON_ACCOUNT:    return "account_change";
      case REASON_TEMPLATE:   return "template_apply";
      case REASON_INITFAILED: return "init_failed";
      case REASON_CLOSE:      return "terminal_close";
     }
   return "unknown";
  }

void ISSX_LogFoundationStartupProfile(const bool ea1_enabled,const bool timer_heavy_enabled,const bool ui_projection_enabled)
  {
   if(!ea1_enabled && !timer_heavy_enabled && !ui_projection_enabled)
      g_startup_profile="shell_only";
   else if(ea1_enabled && timer_heavy_enabled && ui_projection_enabled)
      g_startup_profile="ea1_foundation_active";
   else
      g_startup_profile="invalid_contradictory";

   g_debug.Write((g_startup_profile=="invalid_contradictory"?"WARN":"INFO"),"startup","profile",
                 "mode="+g_startup_profile+
                 " minimal_debug="+ISSX_OnOff(Config.GetBool("minimal_debug_mode"))+
                 " isolation="+ISSX_OnOff(Config.GetBool("isolation_mode"))+
                 " ea1="+ISSX_OnOff(ea1_enabled)+
                 " timer_heavy="+ISSX_OnOff(timer_heavy_enabled)+
                 " ui_projection="+ISSX_OnOff(ui_projection_enabled));
  }

void ISSX_SetCheckpoint(const string cp)
  {
   g_last_checkpoint=cp;
   g_debug.Write("INFO","checkpoint","set",cp);
   g_telemetry.Checkpoint(cp);
  }

bool ISSX_IsGateOn(const bool gate_value,const bool minimal_default_on)
  {
   if(Config.GetBool("minimal_debug_mode"))
      return minimal_default_on;
   return gate_value;
  }

bool ISSX_IsTimerHeavyWorkOn()
  {
   return Config.GetBool("timer_heavy_work_enabled");
  }

bool ISSX_IsUiProjectionOn()
  {
   return Config.GetBool("ui_projection_enabled");
  }

ISSX_InfraStageState ISSX_EA1InfraStateFromRun(const string stage_run)
  {
   const string v=ISSX_Util::Lower(ISSX_Util::Trim(stage_run));
   if(v=="success")
      return issx_infra_stage_ready;
   if(v=="failed" || v=="error")
      return issx_infra_stage_degraded;
   if(v=="degraded")
      return issx_infra_stage_degraded;
   if(v=="blocked")
      return issx_infra_stage_blocked;
   return issx_infra_stage_booting;
  }

void ISSX_LogGateSnapshot()
  {
   const bool gate_runtime_scheduler=Config.GetBool("runtime_scheduler_enabled");
   const bool gate_timer_heavy=ISSX_IsTimerHeavyWorkOn();
   const bool gate_tick_heavy=Config.GetBool("tick_heavy_work_enabled");
   const bool gate_ui_projection=ISSX_IsUiProjectionOn();

   g_debug.Write("INFO","gates","snapshot",
                 "minimal_debug="+(Config.GetBool("minimal_debug_mode")?"on":"off")+
                 " runtime_scheduler="+(gate_runtime_scheduler?"on":"off")+
                 " timer_heavy_work="+(gate_timer_heavy?"on":"off")+
                 " tick_heavy_work="+(gate_tick_heavy?"on":"off")+
                 " ui_projection="+(gate_ui_projection?"on":"off"));
  }

string ISSX_OnOff(const bool value)
  {
   return (value?"on":"off");
  }


string ISSX_PublishTruth(const string state)
  {
   return (state=="success"?"yes":"no");
  }

string ISSX_StartupContradictionText()
  {
   return (g_startup_profile=="invalid_contradictory"?"yes":"no");
  }

void ISSX_LogFeatureStatus(const string category,const string feature_name,const string status_detail,string &last_status,const bool sampled)
  {
   if(status_detail!=last_status)
     {
      if(last_status!="")
         g_debug.Write("INFO","feature_change",feature_name,last_status+"->"+status_detail);
      g_debug.Write("INFO",category,feature_name,status_detail);
      last_status=status_detail;
      return;
     }

   if(sampled)
      g_debug.Write("INFO",category,feature_name,status_detail);
  }

string ISSX_FormatHudTime(const datetime t)
  {
   if(t<=0)
      return "na";
   return TimeToString(t,TIME_DATE|TIME_SECONDS);
  }

bool ISSX_RunUiProjectionSafe()
  {
   ISSX_SetCheckpoint("ui_projection_enter");

   if(!ISSX_IsUiProjectionOn())
     {
      g_debug.Write("INFO","ui","projection_skipped","disabled_by_gate");
      return true;
     }

   if(!Config.GetBool("project_stage_status_root") && !Config.GetBool("project_universe_snapshot") && !Config.GetBool("project_debug_snapshots"))
     {
      g_debug.Write("INFO","ui","projection_skipped","all ui projections disabled");
      return true;
     }

   // Avoid high-risk aggregate calls when modules are intentionally disabled during isolation.
   if(Config.GetBool("isolation_mode"))
     {
      g_debug.Write("INFO","ui","projection_isolation_mode","skipping BuildAggregate heavy projection");
      return true;
     }

   ISSX_DebugAggregate agg=ISSX_UI_Test::BuildAggregate(g_firm_id,g_runtime.State(),g_ea1,g_ea2,g_ea3,g_ea4,g_ea5);
   ISSX_UI_Test::ProjectDebugRoot(g_firm_id,agg);

   if(Config.GetBool("project_stage_status_root"))
      ISSX_UI_Test::ProjectStageStatusRoot(g_firm_id,agg);
   if(Config.GetBool("project_universe_snapshot"))
      ISSX_UI_Test::ProjectUniverseSnapshotRoot(g_firm_id,g_runtime.State());

   if(Config.GetBool("project_debug_snapshots"))
     {
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea1,ISSX_UI_Test::BuildStageSnapshotEA1(g_ea1));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea2,ISSX_UI_Test::BuildStageSnapshotEA2(g_ea2));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea3,ISSX_UI_Test::BuildStageSnapshotEA3(g_ea3));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea4,ISSX_UI_Test::BuildStageSnapshotEA4(g_ea4));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea5,ISSX_UI_Test::BuildStageSnapshotEA5(g_ea5));
     }

   ISSX_SetCheckpoint("ui_projection_ok");
   return true;
  }

void ISSX_RenderMenu()
  {
   if(!Config.GetBool("menu_engine_enabled"))
      return;

   if(!g_menu_initialized)
     {
      g_menu.Init("ISSX_MENU");
      g_menu_initialized=true;
      g_debug.Write("INFO","menu","init","prefix=ISSX_MENU");
     }

   if(!g_menu.Build(g_ea_enabled))
      g_debug.Write("WARN","menu","build_failed",g_menu.LastError());
  }

bool ISSX_RunKernelCycle(bool &ea1_stage_ran,string &ea1_stage_result,string &ea1_stage_reason)
  {
   ea1_stage_ran=false;
   ea1_stage_result="skipped";
   ea1_stage_reason="none";
   ISSX_SyncEA1StageRegistry("running","cycle_enter",0,true);
   ISSX_SetCheckpoint("kernel_cycle_enter");
   g_telemetry.Event("kernel_cycle_enter","kernel_cycle_enter");
   g_telemetry.StageStart(issx_telemetry_stage_kernel);
   g_last_kernel_reason="none";
   g_debug.Write("INFO","kernel","cycle_enter","bootstrapped="+(g_bootstrapped?"true":"false"));
   if(Config.GetBool("runtime_scheduler_enabled"))
      g_runtime.OnPulse();
   else
     {
      g_telemetry.Event("runtime_scheduler_state","skipped");
      g_debug.Write("INFO","kernel","runtime_scheduler_skipped","disabled_by_gate");
     }

   g_scheduler.BeginCycle();
   g_telemetry.ResetCycle();

   string stage_json="";
   string broker_dump_json="";
   string debug_json="";

   if(g_ea_enabled[0] && !g_bootstrapped)
     {
      ISSX_SetCheckpoint("ea1_stage_boot");
      g_debug.Write("INFO","ea1","stage_boot","start");
      g_ea1.Reset();
      if(!ISSX_MarketEngine::StageBoot(g_ea1))
        {
         ea1_stage_reason="stage_boot_failed";
         g_last_ea1_stage_run="failed";
         g_last_ea1_stage_reason=ea1_stage_reason;
         g_last_ea1_stage_elapsed_ms=0;
         ISSX_SyncEA1StageRegistry(g_last_ea1_stage_run,g_last_ea1_stage_reason,g_last_ea1_stage_elapsed_ms,true);
         g_debug.Write("ERROR","stage_init","ea1_market","failed reason="+ea1_stage_reason);
         g_scheduler.EndCycle();
         return false;
        }
      g_debug.Write("INFO","stage_init","ea1_market","success");
     }
   else
      g_debug.Write("INFO","stage_init","ea1_market","skipped reason=already_bootstrapped");

   if(!g_ea_enabled[0])
     {
      g_debug.Write("INFO","stage_run","ea1_market","skipped");
      g_debug.Write("INFO","stage_reason","ea1_market","requested_off");
      g_last_kernel_reason="no_enabled_stage";
      g_debug.Write("WARN","ea1","disabled","EA1 disabled - no critical module active");
      g_last_ea1_stage_run="skipped";
      g_last_ea1_stage_reason="requested_off";
      g_last_ea1_stage_elapsed_ms=0;
      ISSX_SyncEA1StageRegistry(g_last_ea1_stage_run,g_last_ea1_stage_reason,g_last_ea1_stage_elapsed_ms,true);
      ea1_stage_reason="requested_off";
      g_scheduler.EndCycle();
      return false;
     }

   ISSX_SetCheckpoint("ea1_stage_slice_enter");
   g_telemetry.StageStart(issx_telemetry_stage_ea1_market);
   g_debug.Write("INFO","ea1","stage_slice","enter");
   g_ea1.hydration_batch_size=MathMax(1,Config.GetInt("ea1_hydration_batch"));
   if(!g_scheduler.RunStage("ea1_market",10))
     {
      g_debug.Write("INFO","stage_run","ea1_market","skipped");
      g_debug.Write("INFO","stage_reason","ea1_market","scheduler_budget_or_quota");
      g_last_kernel_reason="scheduler_deferred_ea1";
      ea1_stage_result="skipped";
      ea1_stage_reason="scheduler_budget_or_quota";
      g_scheduler.EndCycle();
      return true;
     }
   const ulong ea1_stage_start_us=(ulong)GetMicrosecondCount();
   ea1_stage_ran=true;
   if(!ISSX_MarketEngine::StageSlice(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,Config.GetInt("ea1_max_symbols")))
     {
      g_debug.Write("INFO","stage_run","ea1_market","failed");
      g_debug.Write("INFO","stage_reason","ea1_market","stage_slice_returned_false");
      g_last_kernel_reason="ea1_stage_slice_false";
      g_debug.Write("WARN","ea1_market","discovery_failed","reason=stage_slice_returned_false");
      g_debug.Write("ERROR","ea1","stage_slice_failed","returned false");
      g_telemetry.Error(issx_telemetry_stage_ea1_market,1,"stage_slice_returned_false");
      ea1_stage_result="ERROR";
      ea1_stage_reason="stage_slice_returned_false";
      g_last_ea1_stage_run=ea1_stage_result;
      g_last_ea1_stage_reason=ea1_stage_reason;
      g_last_ea1_stage_elapsed_ms=0;
      ISSX_SyncEA1StageRegistry(g_last_ea1_stage_run,g_last_ea1_stage_reason,g_last_ea1_stage_elapsed_ms,true);
      g_debug.Write("ERROR","stage_run","ea1_market",ea1_stage_result);
      g_debug.Write("ERROR","stage_reason","ea1_market",ea1_stage_reason);
      g_scheduler.RecordStageTime("ea1_market",(long)((ulong)GetMicrosecondCount()-ea1_stage_start_us));
      g_scheduler.EndCycle();
      return false;
     }

   const long ea1_stage_elapsed_ms=(long)(((ulong)GetMicrosecondCount()-ea1_stage_start_us)/1000);
   g_scheduler.RecordStageTime("ea1_market",(long)((ulong)GetMicrosecondCount()-ea1_stage_start_us));

   g_debug.Write("INFO","ea1","stage_slice_ok","symbols="+IntegerToString(ArraySize(g_ea1.symbols)));
   g_telemetry.RecordSymbolProcessed("ea1_market",ArraySize(g_ea1.symbols));

   if(g_ea1.discovery_attempted)
      g_debug.Write("INFO","ea1_hydration","ea1_hydration_queue_created","total="+IntegerToString(g_ea1.hydration_total)+" batch="+IntegerToString(g_ea1.hydration_batch_size));

   if(g_ea1.runtime_state==EA1_STATE_HYDRATING)
     {
      g_debug.Write("INFO","ea1_hydration","ea1_hydration_cycle_start","cursor="+IntegerToString(g_ea1.hydration_cursor)+" total="+IntegerToString(g_ea1.hydration_total));
      if(g_ea1.hydration_last_symbol_start!="")
         g_debug.Write("INFO","ea1_hydration","ea1_hydration_symbol_start","symbol="+g_ea1.hydration_last_symbol_start);
      if(g_ea1.hydration_last_symbol_done!="")
         g_debug.Write("INFO","ea1_hydration","ea1_hydration_symbol_done","symbol="+g_ea1.hydration_last_symbol_done);
      g_debug.Write("INFO","ea1_hydration","ea1_hydration_progress","processed="+IntegerToString(g_ea1.hydration_processed)+" total="+IntegerToString(g_ea1.hydration_total)+" remaining="+IntegerToString(MathMax(0,g_ea1.hydration_total-g_ea1.hydration_processed)));
      g_telemetry.BatchProgress(issx_telemetry_stage_ea1_market,g_ea1.hydration_processed,g_ea1.hydration_total);
      g_telemetry.CursorPosition(issx_telemetry_stage_ea1_market,g_ea1.hydration_cursor,g_ea1.hydration_batch_size);
      g_telemetry.SymbolProgress(issx_telemetry_stage_ea1_market,g_ea1.hydration_last_symbol_done);
     }
   else if(g_ea1.hydration_complete)
      g_debug.Write("INFO","ea1_hydration","ea1_hydration_complete","processed="+IntegerToString(g_ea1.hydration_processed)+" total="+IntegerToString(g_ea1.hydration_total));

   if(g_ea1.discovery_attempted)
     {
      g_debug.Write("INFO","ea1_market","discovery_attempt","minute_id="+IntegerToString(g_ea1.minute_id));
      if(g_ea1.discovery_success)
        {
         string discovery_msg="raw_symbols="+IntegerToString(g_ea1.universe.broker_universe)+
                              " accepted="+IntegerToString(ArraySize(g_ea1.symbols))+
                              " rejected="+IntegerToString(g_ea1.counters.rejected_count)+
                              " degraded="+IntegerToString(g_ea1.counters.degraded_count)+
                              " elapsed_ms="+IntegerToString(g_ea1.discovery_elapsed_ms)+
                              " sort_applied="+(g_ea1.deterministic_sort_applied?"true":"false")+
                              " sort_basis="+g_ea1.deterministic_sort_basis+
                              " ordered_symbol_count="+IntegerToString(g_ea1.deterministic_sorted_count);
         if(g_ea1.discovery_no_change)
            discovery_msg+=" no_change=true";
         g_debug.Write("INFO","ea1_market","discovery_success",discovery_msg);
         ea1_stage_result=(g_ea1.degraded_flag ? "degraded" : "success");
         ea1_stage_reason=(g_ea1.degraded_flag ? "usable_degraded_universe" : "ready");
        }
      else
        {
         g_debug.Write("WARN","ea1_market","discovery_failed","reason="+g_ea1.discovery_status_reason+" elapsed_ms="+IntegerToString(g_ea1.discovery_elapsed_ms));
         ea1_stage_result="failed";
         ea1_stage_reason=g_ea1.discovery_status_reason;
        }
     }
   else if(g_ea1.discovery_skipped)
     {
      if(g_ea1.discovery_skip_streak<=3 || (g_timer_pulse_count%30)==1)
         g_debug.Write("INFO","ea1_market","discovery_skipped","reason="+g_ea1.discovery_status_reason+" minute_id="+IntegerToString(g_ea1.minute_id));
      if(g_ea1.runtime_state==EA1_STATE_HYDRATING)
        {
         ea1_stage_result="degraded";
         ea1_stage_reason="hydration_in_progress";
        }
      else if(g_ea1.runtime_state==EA1_STATE_READY)
        {
         ea1_stage_result=(g_ea1.degraded_flag?"degraded":"success");
         ea1_stage_reason=(g_ea1.degraded_flag?"ready_degraded":"ready");
        }
      else
        {
         ea1_stage_result="skipped";
         ea1_stage_reason=g_ea1.discovery_status_reason;
        }
     }

   g_debug.Write((ea1_stage_result=="failed"?"ERROR":"INFO"),"stage_run","ea1_market",ea1_stage_result);
   g_debug.Write((ea1_stage_result=="failed"?"ERROR":"INFO"),"stage_reason","ea1_market",ea1_stage_reason);
   g_debug.Write("INFO","stage_elapsed_ms","ea1_market",IntegerToString((int)ea1_stage_elapsed_ms));
   g_last_ea1_stage_run=ea1_stage_result;
   g_last_ea1_stage_reason=ea1_stage_reason;
   g_last_ea1_stage_elapsed_ms=ea1_stage_elapsed_ms;
   ISSX_SyncEA1StageRegistry(g_last_ea1_stage_run,g_last_ea1_stage_reason,g_last_ea1_stage_elapsed_ms,true);

   string ea1_stage_status_detail=ea1_stage_result;
   string ea1_stage_reason_detail=ea1_stage_reason;
   if(!g_ea1.discovery_attempted && g_ea1.discovery_skipped && g_ea1.runtime_state==EA1_STATE_HYDRATING)
     {
      ea1_stage_status_detail="degraded";
      ea1_stage_reason_detail="hydration_in_progress";
     }
   else if(!g_ea1.discovery_success && g_ea1.discovery_attempted)
     {
      ea1_stage_status_detail="failed";
      ea1_stage_reason_detail=g_ea1.discovery_status_reason;
     }
   else if(g_ea1.counters.degraded_count>0 || g_ea1.counters.accepted_degraded_count>0)
     {
      ea1_stage_status_detail="degraded";
      ea1_stage_reason_detail="accepted_degraded_or_exploratory";
     }
   g_debug.Write("INFO","stage_run","ea1_market",ea1_stage_status_detail);
   g_debug.Write("INFO","stage_reason","ea1_market",ea1_stage_reason_detail+" elapsed_ms="+IntegerToString((int)ea1_stage_elapsed_ms));
   g_debug.Write("INFO","stage_elapsed_ms","ea1_market","value="+IntegerToString((int)ea1_stage_elapsed_ms));

   if(ArraySize(g_ea1.symbols)<=0)
     {
      g_last_kernel_reason="ea1_zero_symbols";
      g_debug.Write("WARN","ea1","zero_symbols","skipping downstream stages");
      g_bootstrapped=true;
      g_scheduler.EndCycle();
      return true;
     }

   g_last_kernel_reason="ea1_ran";

   g_debug.Write("INFO","ea1","stage_publish","start");
   if(!g_ea1.hydration_complete)
     {
      ISSX_ResetEA1PublishStatus();
      g_debug.Write("INFO","ea1_publish","publish_skip_hydration","reason=hydration_not_complete processed="+IntegerToString(g_ea1.hydration_processed)+" total="+IntegerToString(g_ea1.hydration_total));
      g_ea1.publish_last_checkpoint="publish_skip_hydration";
      g_ea1.publish_last_error="hydration_not_complete";
      g_ea1.publish_elapsed_ms=0;
      g_ea1.publish_payload_bytes_attempted=0;
      g_ea1.publish_payload_bytes_written=0;
      g_last_ea1_publish_state="skipped";
      g_last_ea1_publish_reason="hydration_not_complete";
      g_last_ea1_stage_json_state="skipped";
      g_last_ea1_debug_json_state="skipped";
      g_last_ea1_universe_build_state="skipped";
      g_last_ea1_stage_write_state="skipped";
      g_last_ea1_debug_write_state="skipped";
      g_last_ea1_universe_write_state="skipped";
      g_last_ea1_root_status_state="skipped";
      g_last_ea1_root_debug_state="skipped";
      g_last_ea1_root_universe_state="skipped";
     }
   else
     {
      g_debug.Write("INFO","ea1_publish","publish_enter","checkpoint=publish_enter");
      g_debug.Write("INFO","ea1_publish","publish_preconditions_check","checkpoint=publish_preconditions_check hydration_complete="+ISSX_OnOff(g_ea1.hydration_complete)+" runtime_state="+ISSX_EA1_RuntimeStateText(g_ea1.runtime_state));
      g_debug.Write("INFO","ea1_publish","publish_build_stage_json_start","checkpoint=publish_build_stage_json_start");
      const bool stage_publish_ok=ISSX_MarketEngine::StagePublish(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,stage_json,broker_dump_json,debug_json);
      g_telemetry.Payload(issx_telemetry_stage_ea1_market,StringLen(stage_json));
      g_telemetry.RecordPayloadBytes("stage_json",StringLen(stage_json));
      g_telemetry.RecordPayloadBytes("debug_snapshot",StringLen(debug_json));
      g_telemetry.MemoryEstimate(issx_telemetry_stage_ea1_market,(long)StringLen(stage_json)+(long)StringLen(debug_json)+(long)StringLen(broker_dump_json));
      g_debug.Write((stage_publish_ok?"INFO":"ERROR"),"ea1_publish",(stage_publish_ok?"publish_build_stage_json_success":"publish_build_stage_json_fail"),
                    "stage_json_bytes="+IntegerToString(g_ea1.publish_stage_json_bytes)+
                    " debug_json_bytes="+IntegerToString(g_ea1.publish_debug_json_bytes)+
                    " universe_json_bytes="+IntegerToString(g_ea1.publish_universe_json_bytes)+
                    " symbol_count_used="+IntegerToString(g_ea1.publish_symbols_serialized)+
                    " checkpoint="+g_ea1.publish_last_checkpoint+
                    " elapsed_ms="+IntegerToString(g_ea1.publish_elapsed_ms)+
                    " reason="+(stage_publish_ok?"ok":g_ea1.publish_last_error));

      g_last_ea1_stage_json_state=(StringLen(stage_json)>2?"success":"failed");
      g_last_ea1_debug_json_state=(StringLen(debug_json)>2?"success":"failed");
      g_last_ea1_universe_build_state=(StringLen(broker_dump_json)>2?"success":"failed");
      if(stage_publish_ok)
        {
         g_debug.Write("INFO","ea1_publish","publish_build_debug_json_start","checkpoint=publish_build_debug_json_start");
         g_debug.Write("INFO","ea1_publish","publish_build_debug_json_success","bytes="+IntegerToString(g_ea1.publish_debug_json_bytes));
         g_debug.Write("INFO","ea1_publish","publish_build_universe_dump_start","checkpoint=publish_build_universe_dump_start");
         g_debug.Write("INFO","ea1_publish","publish_build_universe_dump_success","bytes="+IntegerToString(g_ea1.publish_universe_json_bytes)+" symbols="+IntegerToString(g_ea1.publish_symbols_serialized));
         g_debug.Write("INFO","ea1_publish","publish_payload_sizes","stage_json_bytes="+IntegerToString(g_ea1.publish_stage_json_bytes)+" debug_json_bytes="+IntegerToString(g_ea1.publish_debug_json_bytes)+" universe_json_bytes="+IntegerToString(g_ea1.publish_universe_json_bytes)+" symbol_count_used="+IntegerToString(g_ea1.publish_symbols_serialized));
        }
      else
        {
         if(g_ea1.publish_last_checkpoint=="publish_build_debug_json_fail")
            g_debug.Write("ERROR","ea1_publish","publish_build_debug_json_fail","reason="+g_ea1.publish_last_error);
         else if(g_ea1.publish_last_checkpoint=="publish_build_universe_dump_fail")
            g_debug.Write("ERROR","ea1_publish","publish_build_universe_dump_fail","reason="+g_ea1.publish_last_error);
         else if(g_ea1.publish_last_checkpoint=="publish_build_stage_json_fail")
            g_debug.Write("ERROR","ea1_publish","publish_build_stage_json_fail","reason="+g_ea1.publish_last_error);
         g_debug.Write("ERROR","ea1_publish","publish_failed","checkpoint="+g_ea1.publish_last_checkpoint+" reason="+g_ea1.publish_last_error);
        }
      string ea1_publish_reason="ok";
      bool publish_ok=false;
      if(stage_publish_ok)
        {
         g_debug.Write("INFO","ea1_publish","publish_file_projection_start",
                       "checkpoint=publish_file_projection_start universe_json_len="+IntegerToString(StringLen(broker_dump_json))+
                       " stage_json_len="+IntegerToString(StringLen(stage_json))+
                       " debug_json_len="+IntegerToString(StringLen(debug_json)));
         publish_ok=ISSX_ProjectEA1(stage_json,broker_dump_json,debug_json,ea1_publish_reason);
        }
      else
         ea1_publish_reason="stage_publish_build_failed_"+g_ea1.publish_last_error;

      if(!publish_ok)
     {
      g_debug.Write("WARN","ea1_publish","publish_degraded","reason="+ea1_publish_reason+" stage_json="+(stage_publish_ok?"ok":"fail"));
      if(ea1_stage_result=="success")
         ea1_stage_result="degraded";
      if(ea1_stage_reason=="ready")
         ea1_stage_reason="publish_degraded_"+ea1_publish_reason;
      g_last_ea1_stage_run=ea1_stage_result;
      g_last_ea1_stage_reason=ea1_stage_reason;
      ISSX_SyncEA1StageRegistry(g_last_ea1_stage_run,g_last_ea1_stage_reason,g_last_ea1_stage_elapsed_ms,true);
      g_debug.Write("INFO","stage_run","ea1_market",ea1_stage_result);
      g_debug.Write("INFO","stage_reason","ea1_market",ea1_stage_reason);
     }
   }

   g_telemetry.EndStage("ea1_market",(ea1_stage_result=="success"?"READY":"DEGRADED"));

   string ea1_symbols[];
   const int ea1_count=ISSX_CopyEA1Symbols(ea1_symbols);
   g_debug.Write("INFO","ea1","symbol_copy","count="+IntegerToString(ea1_count));

   if(ea1_count<=0)
     {
      g_debug.Write("WARN","ea1","symbol_copy_empty","ending cycle safely");
      g_bootstrapped=true;
      g_scheduler.EndCycle();
      return true;
     }

   if(g_ea_enabled[1] && !g_bootstrapped)
     {
      g_debug.Write("INFO","ea2","stage_boot","start");
      ISSX_HistoryEngine::StageBoot(g_ea2,ea1_symbols,Config.GetBool("ea2_deep_profile_default"));
     }

   if(g_ea_enabled[1])
     {
      g_telemetry.StageStart(issx_telemetry_stage_ea2_history);
      ISSX_SetCheckpoint("ea2_stage_slice_start");
      g_debug.Write("INFO","ea2","stage_slice","start");
      const int ea2_batch_limit=g_scheduler.LastBatchLimit("ea2_history",Config.GetInt("ea2_max_symbols_per_slice"));
      if(g_scheduler.RunBatch("ea2_history",ea2_batch_limit) && g_scheduler.RunStage("ea2_history",12))
        {
         const ulong ea2_stage_start_us=(ulong)GetMicrosecondCount();
         ISSX_HistoryEngine::StageSlice(g_ea2,ea1_symbols,Config.GetBool("ea2_deep_profile_default"),ea2_batch_limit);
         g_scheduler.RecordStageTime("ea2_history",(long)((ulong)GetMicrosecondCount()-ea2_stage_start_us));
         g_telemetry.RecordSymbolProcessed("ea2_history",g_ea2.forensic.batch_symbols_done);
         g_telemetry.RecordCopyRates(g_ea2.forensic.max_rates_returned);
        }
      else
         g_debug.Write("INFO","stage_run","ea2_history","skipped reason=scheduler_budget_or_quota");
      stage_json=ISSX_HistoryEngine::StagePublish(g_ea2);
      debug_json=ISSX_HistoryEngine::BuildDebugSnapshot(g_ea2);
      ISSX_ProjectEA2(stage_json,debug_json);
      g_last_ea2_stage_run=(g_ea2.stage_minimum_ready_flag ? (g_ea2.degraded_flag?"degraded":"success") : "blocked");
      g_last_ea2_stage_reason=g_ea2.dependency_block_reason;
      g_last_ea2_stage_elapsed_ms=0;
      g_telemetry.EndStage("ea2_history",(g_ea2.stage_minimum_ready_flag ? (g_ea2.degraded_flag?"DEGRADED":"READY") : "BLOCKED"));
     }
   else
     {
      g_debug.Write("INFO","ea2","disabled","stage skipped");
      g_last_ea2_stage_run="skipped";
      g_last_ea2_stage_reason="disabled";
      g_last_ea2_stage_elapsed_ms=0;
     }

   if(g_ea_enabled[2] && !g_bootstrapped)
     {
      g_debug.Write("INFO","ea3","stage_boot","start");
      ISSX_SelectionEngine::StageBoot(g_firm_id,g_ea1,g_ea2,g_ea3);
     }

   if(g_ea_enabled[2])
     {
      g_telemetry.StageStart(issx_telemetry_stage_ea3_selection);
      ISSX_SetCheckpoint("ea3_stage_slice_start");
      g_debug.Write("INFO","ea3","stage_slice","start");
      ISSX_SelectionEngine::StageSlice(g_firm_id,g_ea1,g_ea2,g_ea3);
      g_telemetry.RecordSymbolProcessed("ea3_selection",ArraySize(g_ea3.frontier));
      string ea3_debug="";
      ISSX_SelectionEngine::StagePublish(g_ea3,stage_json,ea3_debug);
      ISSX_ProjectEA3(stage_json,ea3_debug);
      g_last_ea3_stage_run="success";
      g_last_ea3_stage_reason=g_ea3.dependency_block_reason;
      g_last_ea3_stage_elapsed_ms=0;
      g_telemetry.EndStage("ea3_selection",(g_last_ea3_stage_run=="success"?"READY":"DEGRADED"));
     }
   else
     {
      g_debug.Write("INFO","ea3","disabled","stage skipped");
      g_last_ea3_stage_run="skipped";
      g_last_ea3_stage_reason="disabled";
      g_last_ea3_stage_elapsed_ms=0;
     }

   if(g_ea_enabled[3] && !g_bootstrapped)
     {
      g_debug.Write("INFO","ea4","stage_boot","start");
      ISSX_CorrelationEngine::StageBoot(g_ea4,g_firm_id);
     }

   if(g_ea_enabled[3])
     {
      g_telemetry.StageStart(issx_telemetry_stage_ea4_correlation);
      ISSX_SetCheckpoint("ea4_stage_slice_start");
      g_debug.Write("INFO","ea4","stage_slice","start");
      ISSX_CorrelationEngine::StageSlice(g_ea4,g_firm_id,g_ea1,g_ea3,ISSX_CurrentKernelMinuteId());
      g_telemetry.RecordSymbolProcessed("ea4_correlation",ArraySize(g_ea4.symbols));
      string ea4_debug="";
      ISSX_CorrelationEngine::StagePublish(g_ea4,stage_json,ea4_debug);
      ISSX_ProjectEA4(stage_json,ea4_debug);
      g_last_ea4_stage_run=(g_ea4.stage_minimum_ready_flag ? (g_ea4.degraded_flag?"degraded":"success") : "blocked");
      g_last_ea4_stage_reason=g_ea4.dependency_block_reason;
      g_last_ea4_stage_elapsed_ms=0;
      g_telemetry.EndStage("ea4_correlation",(g_ea4.stage_minimum_ready_flag ? (g_ea4.degraded_flag?"DEGRADED":"READY") : "BLOCKED"));
     }
   else
     {
      g_debug.Write("INFO","ea4","disabled","stage skipped");
      g_last_ea4_stage_run="skipped";
      g_last_ea4_stage_reason="disabled";
      g_last_ea4_stage_elapsed_ms=0;
     }

   ISSX_EA4_OptionalIntelligenceExport ea4_optional_intel[];
   ISSX_EA5_OptionalIntelligence optional_intel[];
   ArrayResize(ea4_optional_intel,0);
   ArrayResize(optional_intel,0);

   if(g_ea_enabled[4])
     {
      g_telemetry.StageStart(issx_telemetry_stage_ea5_contracts);
      ISSX_CorrelationEngine::ExportOptionalIntelligence(g_ea4,ea4_optional_intel);
      ISSX_ConvertEA4OptionalIntelligence(ea4_optional_intel,optional_intel);

      ISSX_SetCheckpoint("ea5_build_from_inputs");
      g_debug.Write("INFO","ea5","build_from_inputs","start");
      ISSX_Contracts::BuildFromInputs(g_ea5,g_ea1,g_ea2,g_ea3,optional_intel);

      const long current_minute_id=ISSX_CurrentKernelMinuteId();
      const bool ea5_export_due=(!g_bootstrapped || ISSX_IsEA5ExportDue(current_minute_id));

      if(ea5_export_due)
        {
         g_debug.Write("INFO","ea5","export_due","true");
         string export_json=ISSX_Contracts::ToStageJson(g_ea5,g_registry.fields,g_registry.enums);
         string ea5_debug=ISSX_Contracts::ToDebugJson(g_ea5);
         ISSX_ProjectEA5(export_json,ea5_debug);
         g_telemetry.Payload(issx_telemetry_stage_ea5_contracts,StringLen(export_json));
         g_telemetry.RecordPayloadBytes("export_payload",StringLen(export_json));
         g_telemetry.EstimateMemoryUsage("ea5_export",StringLen(export_json)+StringLen(ea5_debug));
         g_last_ea5_export_minute_id=current_minute_id;
         g_last_ea5_stage_run="success";
         g_last_ea5_stage_reason="export_due";
         g_last_ea5_stage_elapsed_ms=0;
        }
      g_telemetry.EndStage("ea5_contracts","READY");
     }
   else
     {
      g_debug.Write("INFO","ea5","disabled","stage skipped");
      g_last_ea5_stage_run="skipped";
      g_last_ea5_stage_reason="disabled";
      g_last_ea5_stage_elapsed_ms=0;
     }

   g_telemetry.StageStart(issx_telemetry_stage_ui);
   g_debug.Write("INFO","ui","aggregate","building snapshots");
   if(!ISSX_RunUiProjectionSafe())
     {
      g_debug.Write("WARN","ui","projection_failed","non-critical; continuing");
      g_telemetry.EndStage("ui","DEGRADED");
     }
   else
      g_telemetry.EndStage("ui","READY");
   g_bootstrapped=true;
   g_scheduler.EndCycle();
   g_debug.Write("INFO","kernel","cycle_exit","ok=true");
   return true;
  }

int OnInit()
  {
   ISSX_ResolveOperatorContext();
   if(!g_debug.BeginSession(g_market_log_relative_path,_Symbol,_Period,g_operator_server_name,g_operator_broker_name,g_operator_login_id))
      Print("ISSX: debug session failed to open");
   ISSX_SetCheckpoint("oninit_enter");
   g_telemetry.Init();
   g_telemetry.Event("system_boot","system_boot");
   g_debug.Write("INFO","lifecycle","oninit_start","build="+IntegerToString((int)__MQLBUILD__));
   g_debug.Write("INFO","debug","sink","mode="+g_debug.ActiveMode()+" path="+g_debug.ActivePath());

   Config.Init();

   MathSrand((uint)TimeLocal());

   g_scheduler.Reset();
   g_scheduler.Configure(InpEnableRuntimeSchedulerLayer,InpSchedulerCycleBudgetMs,15);

   g_boot_id        = ISSX_WrapperBootId();
   g_instance_guid  = ISSX_WrapperInstanceGuid();
   g_writer_nonce   = ISSX_WrapperNonce();
   g_firm_id        = ISSX_ResolveFirmId();

   g_debug.Write("INFO","context","identity","boot_id="+g_boot_id+" instance="+g_instance_guid+" nonce="+g_writer_nonce+" firm_id="+g_firm_id);
   g_debug.Write("INFO","context","terminal","company="+TerminalInfoString(TERMINAL_COMPANY)+" name="+TerminalInfoString(TERMINAL_NAME));
   g_debug.Write("INFO","context","account","broker="+g_operator_broker_name+" server="+g_operator_server_name+" login="+IntegerToString((int)g_operator_login_id));

   g_ea_enabled[0]=Config.IsEAEnabled(issx_stage_ea1);
   g_ea_enabled[1]=Config.IsEAEnabled(issx_stage_ea2);
   g_ea_enabled[2]=Config.IsEAEnabled(issx_stage_ea3);
   g_ea_enabled[3]=Config.IsEAEnabled(issx_stage_ea4);
   g_ea_enabled[4]=Config.IsEAEnabled(issx_stage_ea5);
   g_debug.Write("INFO","modules","states_forced",
                 "ea1="+(g_ea_enabled[0]?"on":"off")+
                 " ea2="+(g_ea_enabled[1]?"on":"off")+
                 " ea3="+(g_ea_enabled[2]?"on":"off")+
                 " ea4="+(g_ea_enabled[3]?"on":"off")+
                 " ea5="+(g_ea_enabled[4]?"on":"off")+" isolation="+(Config.GetBool("isolation_mode")?"true":"false"));

   const bool req_runtime_scheduler=Config.GetBool("gate_runtime_scheduler_requested");
   const bool req_timer_heavy=Config.GetBool("gate_timer_heavy_requested");
   const bool req_tick_heavy=Config.GetBool("gate_tick_heavy_requested");
   const bool req_ui_projection=Config.GetBool("gate_ui_projection_requested");

   const bool eff_runtime_scheduler=Config.GetBool("runtime_scheduler_enabled");
   const bool eff_timer_heavy=ISSX_IsTimerHeavyWorkOn();
   const bool eff_tick_heavy=ISSX_IsGateOn(req_tick_heavy,false);
   const bool eff_ui_projection=ISSX_IsUiProjectionOn();

   g_debug.Write("INFO","feature_state","session_snapshot",
                 "minimal_debug=requested="+ISSX_OnOff(Config.GetBool("minimal_debug_mode"))+" effective="+ISSX_OnOff(Config.GetBool("minimal_debug_mode"))+
                 " isolation=requested="+ISSX_OnOff(Config.GetBool("isolation_mode"))+" effective="+ISSX_OnOff(Config.GetBool("isolation_mode"))+
                 " runtime_scheduler=requested="+ISSX_OnOff(req_runtime_scheduler)+" effective="+ISSX_OnOff(eff_runtime_scheduler)+
                 " timer_heavy_work=requested="+ISSX_OnOff(req_timer_heavy)+" effective="+ISSX_OnOff(eff_timer_heavy)+
                 " tick_heavy_work=requested="+ISSX_OnOff(req_tick_heavy)+" effective="+ISSX_OnOff(eff_tick_heavy)+
                 " ui_projection=requested="+ISSX_OnOff(req_ui_projection)+" effective="+ISSX_OnOff(eff_ui_projection));

   g_debug.Write("INFO","feature_state","minimal_debug_mode","requested="+ISSX_OnOff(Config.GetBool("minimal_debug_mode"))+" effective="+ISSX_OnOff(Config.GetBool("minimal_debug_mode")));
   g_debug.Write("INFO","feature_state","isolation_mode","requested="+ISSX_OnOff(Config.GetBool("isolation_mode"))+" effective="+ISSX_OnOff(Config.GetBool("isolation_mode")));
   g_debug.Write("INFO","feature_state","runtime_scheduler","requested="+ISSX_OnOff(req_runtime_scheduler)+" effective="+ISSX_OnOff(eff_runtime_scheduler)+" reason="+(eff_runtime_scheduler?"active":(Config.GetBool("minimal_debug_mode")?"minimal_debug_mode":"gate_off")));
   g_debug.Write("INFO","feature_state","timer_heavy_work","requested="+ISSX_OnOff(req_timer_heavy)+" effective="+ISSX_OnOff(eff_timer_heavy)+" reason="+(eff_timer_heavy?"active":(Config.GetBool("minimal_debug_mode")?"minimal_debug_mode":"gate_off")));
   g_debug.Write("INFO","feature_state","tick_heavy_work","requested="+ISSX_OnOff(req_tick_heavy)+" effective="+ISSX_OnOff(eff_tick_heavy)+" reason="+(eff_tick_heavy?"active":(Config.GetBool("minimal_debug_mode")?"minimal_debug_mode":"gate_off")));
   g_debug.Write("INFO","feature_state","ui_projection","requested="+ISSX_OnOff(req_ui_projection)+" effective="+ISSX_OnOff(eff_ui_projection)+" reason="+(eff_ui_projection?"active":(Config.GetBool("minimal_debug_mode")?"minimal_debug_mode":"gate_off")));

   g_debug.Write("INFO","feature_state","ea1_market","requested="+ISSX_OnOff(Config.GetBool("ea1_enabled"))+" effective="+ISSX_OnOff(g_ea_enabled[0])+" reason="+((Config.GetBool("isolation_mode") && !Config.GetBool("ea1_enabled"))?"isolation_forced_on":(g_ea_enabled[0]?"active":"requested_off")));
   g_debug.Write("INFO","stage_state","ea1_market","requested="+ISSX_OnOff(Config.GetBool("ea1_enabled")));
   g_debug.Write("INFO","stage_state","ea1_market","effective="+ISSX_OnOff(g_ea_enabled[0]));
   g_debug.Write("INFO","feature_state","ea2_history","requested="+ISSX_OnOff(Config.GetBool("ea2_enabled"))+" effective="+ISSX_OnOff(g_ea_enabled[1])+" reason="+(g_ea_enabled[1]?"active":(Config.GetBool("isolation_mode")?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea3_selection","requested="+ISSX_OnOff(Config.GetBool("ea3_enabled"))+" effective="+ISSX_OnOff(g_ea_enabled[2])+" reason="+(g_ea_enabled[2]?"active":(Config.GetBool("isolation_mode")?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea4_correlation","requested="+ISSX_OnOff(Config.GetBool("ea4_enabled"))+" effective="+ISSX_OnOff(g_ea_enabled[3])+" reason="+(g_ea_enabled[3]?"active":(Config.GetBool("isolation_mode")?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea5_contracts","requested="+ISSX_OnOff(Config.GetBool("ea5_enabled"))+" effective="+ISSX_OnOff(g_ea_enabled[4])+" reason="+(g_ea_enabled[4]?"active":(Config.GetBool("isolation_mode")?"isolation_forced_off":"requested_off")));

   ISSX_LogFoundationStartupProfile(g_ea_enabled[0],eff_timer_heavy,eff_ui_projection);
   g_debug.Write("INFO","paths","operator_layout",
                 "operator_root="+g_operator_root_relative+"/"+
                 " market_json_path="+g_market_json_relative_path+
                 " market_log_path="+g_market_log_relative_path+
                 " persistence_root="+ISSX_PersistencePath::SharedDir(g_firm_id)+
                 " debug_sink="+g_debug.ActivePath());

  ISSX_LogGateSnapshot();

   if(!Config.IsValid())
     {
      const string invalid_reason="config_validation_failed";
      g_debug.Write("ERROR","startup","config_invalid",invalid_reason);
      g_debug.Write("ERROR","lifecycle","oninit_end","result=INIT_FAILED reason="+invalid_reason);
      return INIT_FAILED;
     }

   if(g_ea_enabled[0] && (!eff_timer_heavy || !eff_ui_projection))
     {
      const string block_reason="ea1_foundation_gate_off timer_heavy="+ISSX_OnOff(eff_timer_heavy)+" ui_projection="+ISSX_OnOff(eff_ui_projection);
      g_debug.Write("WARN","startup","profile_degraded",block_reason+" action=continue_without_self_kill");
     }

   // registry + runtime
   g_registry.SeedBlueprintV170();
   StageRegistry.Reset();
   g_stage_registry_infra.Reset();
   ISSX_SyncEA1StageRegistry("init","oninit",0,false);
   string runtime_init_state="skipped | reason="+(Config.GetBool("minimal_debug_mode")?"minimal_debug_mode":"gate_off");
   if(Config.GetBool("runtime_scheduler_enabled"))
     {
      g_runtime.Init();
      runtime_init_state="success";
     }
   else
      g_debug.Write("INFO","runtime","init_skipped","disabled_by_gate");
   ISSX_LogFeatureStatus("feature_init","runtime_scheduler",runtime_init_state,g_last_feature_init_runtime_scheduler,false);

   g_bootstrapped     = false;
   g_runtime_ready    = false;
   g_first_cycle_done = false;
   g_kernel_busy      = false;
   g_timer_pulse_count=0;
   g_timer_skip_runtime_not_ready_count=0;
   g_timer_skip_kernel_busy_count=0;

   int timer_sec=ISSX_EVENT_TIMER_SEC;
   if(timer_sec<1)
     {
      g_debug.Write("WARN","timer","invalid_interval","configured="+IntegerToString(ISSX_EVENT_TIMER_SEC)+" fallback=1");
      timer_sec=1;
     }

   if(!EventSetTimer(timer_sec))
     {
      g_debug.Write("ERROR","timer","event_set_failed","err="+IntegerToString(GetLastError()));
      g_debug.Write("ERROR","lifecycle","oninit_end","result=INIT_FAILED (critical timer failure)");
      return INIT_FAILED;
     }

   g_runtime_ready=true;
   g_debug.Write("INFO","timer","event_set_ok","sec="+IntegerToString(timer_sec));
   g_ui.Init(g_debug);
   g_debug.Write("INFO","lifecycle","oninit_end","result=INIT_SUCCEEDED");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_runtime_ready=false;
   g_bootstrapped=false;
   if(g_menu_initialized)
     {
      g_menu.Destroy();
      g_menu_initialized=false;
     }
   g_ui.Shutdown(g_debug);
   g_kernel_busy=false;
   g_last_deinit_reason_code=reason;
   g_last_deinit_reason_text=ISSX_DeinitReasonText(reason);
   g_debug.Write("INFO","lifecycle","ondeinit","reason="+IntegerToString(reason)+" reason_text="+g_last_deinit_reason_text+" last_checkpoint="+g_last_checkpoint+" self_remove=false");
   g_telemetry.Flush();
   g_debug.Close(reason,"last_checkpoint="+g_last_checkpoint+" file_mode="+g_debug.ActiveMode()+" file_path="+g_debug.ActivePath());
  }

void OnTimer()
  {
   if(!g_runtime_ready)
     {
      g_timer_skip_runtime_not_ready_count++;
      if((g_timer_skip_runtime_not_ready_count%30)==1)
         g_debug.Write("WARN","timer","skip","runtime_not_ready count="+ISSX_Util::ULongToStringX(g_timer_skip_runtime_not_ready_count));
      return;
     }

   if(g_kernel_busy)
     {
      g_timer_skip_kernel_busy_count++;
      if((g_timer_skip_kernel_busy_count%30)==1)
         g_debug.Write("WARN","timer","skip","kernel_busy count="+ISSX_Util::ULongToStringX(g_timer_skip_kernel_busy_count));
      return;
     }

   g_kernel_busy=true;

   g_memory_guard.ResetCycle();

   ISSX_SetCheckpoint("ontimer_enter");
   g_telemetry.Event("timer_heartbeat","timer_heartbeat");
   g_timer_pulse_count++;
   if(!g_first_timer_logged)
     {
      g_debug.Write("INFO","timer","first_heartbeat","first timer heartbeat reached");
      g_first_timer_logged=true;
     }
   const ulong timer_start_us=(ulong)GetMicrosecondCount();
   const bool sampled=((g_timer_pulse_count%15)==1);
   const bool gate_runtime_scheduler=Config.GetBool("runtime_scheduler_enabled");
   const bool gate_timer_heavy=ISSX_IsTimerHeavyWorkOn();

   if(sampled || !g_first_cycle_done)
      g_debug.Write("INFO","timer","enter","pulse="+ISSX_Util::ULongToStringX(g_timer_pulse_count));

   if(sampled || !g_first_cycle_done)
      g_debug.Write("INFO","timer","heartbeat",
                    "pulse="+ISSX_Util::ULongToStringX(g_timer_pulse_count)+
                    " first_cycle="+(!g_first_cycle_done?"true":"false")+
                    " minimal_mode="+(Config.GetBool("minimal_debug_mode")?"true":"false")+
                    " runtime_scheduler="+(gate_runtime_scheduler?"on":"off")+
                    " heavy_timer_work="+(gate_timer_heavy?"on":"off"));

   bool timer_cycle_ok=true;
   long timer_kernel_elapsed_ms=0;

   string runtime_scheduler_status="skipped | gate=off";
   if(gate_runtime_scheduler && !gate_timer_heavy)
      runtime_scheduler_status="skipped | gate=timer_heavy_off";

   string timer_heavy_status="skipped | gate=off";
   string kernel_reason="none";
   if(gate_timer_heavy)
     {
      const ulong kernel_start_us=(ulong)GetMicrosecondCount();
      bool ea1_stage_ran=false;
      string ea1_stage_result="skipped";
      string ea1_stage_reason="none";
      timer_cycle_ok=ISSX_RunKernelCycle(ea1_stage_ran,ea1_stage_result,ea1_stage_reason);
      timer_kernel_elapsed_ms=(long)(((ulong)GetMicrosecondCount()-kernel_start_us)/1000);
      if(!ea1_stage_ran)
        {
         timer_heavy_status="degraded | reason=no_enabled_stage_ran";
         timer_cycle_ok=false;
         kernel_reason="no_enabled_stage_ran";
        }
      else if(!timer_cycle_ok)
        {
         timer_heavy_status="failed | reason=kernel_cycle_false stage=ea1_market stage_reason="+ea1_stage_reason;
         kernel_reason="kernel_cycle_false";
        }
      else
        {
         timer_heavy_status="success | stage=ea1_market stage_run="+ea1_stage_result+" stage_reason="+ea1_stage_reason;
         kernel_reason="stage="+ea1_stage_result+" reason="+ea1_stage_reason;
        }
     }
   else
     {
      if(!g_logged_timer_heavy_skip)
        {
         g_debug.Write("INFO","timer","kernel_skip","disabled_by_gate");
         g_logged_timer_heavy_skip=true;
        }
      if(g_ea_enabled[0])
        {
         timer_cycle_ok=false;
         timer_heavy_status="degraded | reason=gate_off_enabled_stage";
         kernel_reason="timer_heavy_gate_off";
         g_last_ea1_stage_run="skipped";
         g_last_ea1_stage_reason="timer_heavy_gate_off";
         g_last_ea1_stage_elapsed_ms=0;
         ISSX_SyncEA1StageRegistry(g_last_ea1_stage_run,g_last_ea1_stage_reason,g_last_ea1_stage_elapsed_ms,true);
        }
      if((g_timer_pulse_count%30)==1)
         g_debug.Write("INFO","timer","minimal_heartbeat","pulse="+ISSX_Util::ULongToStringX(g_timer_pulse_count));
     }

   if(gate_runtime_scheduler && gate_timer_heavy)
      runtime_scheduler_status=(timer_cycle_ok ? "success" : "failed | reason=kernel_cycle_false");
   ISSX_LogFeatureStatus("feature_run","runtime_scheduler",runtime_scheduler_status,g_last_feature_runtime_scheduler,sampled);
   ISSX_LogFeatureStatus("feature_run","timer_heavy_work",timer_heavy_status,g_last_feature_timer_heavy,sampled);

   g_last_kernel_result=(timer_cycle_ok?"ok":"degraded");
   g_last_kernel_elapsed_ms=timer_kernel_elapsed_ms;
   g_telemetry.Metric("kernel_elapsed_ms",(double)timer_kernel_elapsed_ms);
   g_telemetry.LogSampledSummary((sampled || !timer_cycle_ok));
   if(kernel_reason=="none")
      kernel_reason=(gate_timer_heavy?"active":"timer_heavy_off");
   g_last_kernel_reason=kernel_reason;

   if(sampled || !timer_cycle_ok)
      g_debug.Write("INFO","timer","kernel_result",(timer_cycle_ok?"ok":"degraded")+" elapsed_ms="+IntegerToString((int)timer_kernel_elapsed_ms)+" timer_heavy="+(gate_timer_heavy?"on":"off")+" reason="+kernel_reason);

   const ulong elapsed_us=(ulong)GetMicrosecondCount()-timer_start_us;
   if(sampled || !timer_cycle_ok)
      g_debug.Write("INFO","timer","elapsed_us","value="+ISSX_Util::ULongToStringX(elapsed_us));

   g_debug.MarkStageExecution(issx_stage_ea1,g_last_ea1_stage_elapsed_ms);
   g_debug.MarkStageExecution(issx_stage_ea2,g_last_ea2_stage_elapsed_ms);
   g_debug.MarkStageExecution(issx_stage_ea3,g_last_ea3_stage_elapsed_ms);
   g_debug.MarkStageExecution(issx_stage_ea4,g_last_ea4_stage_elapsed_ms);
   g_debug.MarkStageExecution(issx_stage_ea5,g_last_ea5_stage_elapsed_ms);
   if(sampled)
      g_debug.FlushStageCountersSample();

   g_stage_registry_infra.SetState(issx_stage_ea1,ISSX_EA1InfraStateFromRun(g_last_ea1_stage_run));
   g_stage_registry_infra.SetReason(issx_stage_ea1,g_last_ea1_stage_reason);
   g_stage_registry_infra.SetElapsed(issx_stage_ea1,g_last_ea1_stage_elapsed_ms);
   g_metrics.RecordLatency(issx_stage_ea1,g_last_ea1_stage_elapsed_ms);
   g_metrics.RecordThroughput(issx_stage_ea1,g_ea1.universe.active_universe);
   g_metrics.RecordHydrationRateBps(issx_stage_ea2,g_ea2.forensic.max_rates_returned);
   g_metrics.RecordExportSize(issx_stage_ea1,g_ea1.publish_stage_json_bytes);
   g_last_system_snapshot=ISSX_SystemSnapshot::DumpSystemState(g_runtime.State(),
                                                               g_ea1.universe.broker_universe,
                                                               g_ea2.counters.symbols_total,
                                                               g_ea3.universe.frontier_universe,
                                                               g_ea4.universe.frontier_universe_count,
                                                               g_ea5.debug_contract_build_count,
                                                               (long)g_ea5.debug_estimated_export_bytes,
                                                               g_ea1.publish_last_error);
   if(sampled)
      g_debug.SampledLog("INFO","snapshot","system_state",g_last_system_snapshot,1);

   const bool req_runtime_scheduler=Config.GetBool("gate_runtime_scheduler_requested");
   const bool req_timer_heavy=Config.GetBool("gate_timer_heavy_requested");
   const bool req_ui_projection=Config.GetBool("gate_ui_projection_requested");
   const bool req_ea1=Config.GetBool("ea1_enabled");
   const bool eff_runtime_scheduler=Config.GetBool("runtime_scheduler_enabled");
   const bool eff_timer_heavy=ISSX_IsTimerHeavyWorkOn();
   const bool eff_ui_projection=ISSX_IsUiProjectionOn();

   g_ui.Render(g_debug,ISSX_ENGINE_VERSION,g_boot_id,ISSX_FormatHudTime(TimeTradeServer()),g_timer_pulse_count,
               Config.GetBool("minimal_debug_mode"),
               Config.GetBool("isolation_mode"),
               eff_runtime_scheduler,
               eff_timer_heavy,
               Config.GetBool("tick_heavy_work_enabled"),
               Config.GetBool("menu_engine_enabled"),
               Config.GetBool("chart_ui_updates_enabled"),
               eff_ui_projection,
               req_runtime_scheduler,
               req_timer_heavy,
               req_ui_projection,
               req_ea1,
               g_startup_profile,
               (eff_runtime_scheduler?"on":"off"),
               g_last_kernel_result,g_last_kernel_reason,g_last_kernel_elapsed_ms,
               g_operator_broker_name,g_operator_server_name,g_ea_enabled,
               g_ea1,g_ea2,g_ea3,g_ea4,g_ea5,
               g_last_ea1_stage_run,g_last_ea1_stage_reason,g_last_ea1_stage_elapsed_ms,g_last_ea1_publish_state,
               g_last_ea1_publish_reason,
               g_last_ea1_stage_json_state,g_last_ea1_debug_json_state,g_last_ea1_universe_build_state,
               g_last_ea1_stage_write_state,g_last_ea1_debug_write_state,g_last_ea1_universe_write_state,
               g_last_ea1_root_status_state,g_last_ea1_root_debug_state,
               g_last_ea2_stage_run,g_last_ea2_stage_reason,g_last_ea2_stage_elapsed_ms,
               g_last_ea3_stage_run,g_last_ea3_stage_reason,g_last_ea3_stage_elapsed_ms,
               g_last_ea4_stage_run,g_last_ea4_stage_reason,g_last_ea4_stage_elapsed_ms,
               g_last_ea5_stage_run,g_last_ea5_stage_reason,g_last_ea5_stage_elapsed_ms,
               g_last_kernel_result+"/"+g_last_kernel_reason);

   ISSX_RenderMenu();

   g_first_cycle_done=true;
   g_kernel_busy=false;

  }

void OnTick()
  {
   static long tick_count=0;
   tick_count++;
   if(!g_first_tick_logged)
     {
      g_debug.Write("INFO","tick","first_heartbeat","first tick heartbeat reached");
      g_first_tick_logged=true;
     }
   const bool tick_sampled=((tick_count%100)==0);
   if(!Config.GetBool("tick_heavy_work_enabled"))
     {
      if(!g_logged_tick_heavy_skip)
        {
         g_debug.Write("INFO","tick","heavy_work_skipped","disabled_by_gate");
         g_logged_tick_heavy_skip=true;
        }
      ISSX_LogFeatureStatus("feature_run","tick_heavy_work","skipped | reason="+(Config.GetBool("minimal_debug_mode")?"minimal_debug_mode":"gate_off"),g_last_feature_run_tick_heavy,tick_sampled);
      if(tick_sampled)
         g_debug.Write("INFO","tick","heartbeat","count="+IntegerToString((int)tick_count)+" mode=minimal");
      return;
     }

   ISSX_LogFeatureStatus("feature_run","tick_heavy_work","success",g_last_feature_run_tick_heavy,tick_sampled);
   if((tick_count%50)==0)
      g_debug.Write("INFO","tick","heartbeat","count="+IntegerToString((int)tick_count)+" mode=heavy_enabled");
  }


void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   const long event_lparam=lparam;
   const double event_dparam=dparam;

   if(id!=CHARTEVENT_OBJECT_CLICK)
      return;

   if(!g_menu_initialized || !Config.GetBool("menu_engine_enabled"))
      return;

   if(!g_menu.IsOwnedObject(sparam))
      return;

   bool allow_toggle=!Config.GetBool("isolation_mode");
   if(g_menu.HandleClick(sparam,g_ea_enabled,allow_toggle))
     {
      g_debug.Write("INFO","menu","toggle","object="+sparam+" state=ok lp="+ISSX_Util::LongToStringX(event_lparam)+" dp="+DoubleToString(event_dparam,2));
      g_menu.Build(g_ea_enabled);
     }
   else
      g_debug.Write("WARN","menu","toggle_denied","object="+sparam+" reason="+g_menu.LastError());
  }
