#property strict
#property version   "1.714"
#property description "ISSX single-wrapper consolidated kernel (safe attach wrapper)"

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_runtime.mqh>
#include <ISSX/issx_persistence.mqh>
#include <ISSX/issx_market_engine.mqh>
#include <ISSX/issx_history_engine.mqh>
#include <ISSX/issx_selection_engine.mqh>
#include <ISSX/issx_correlation_engine.mqh>
#include <ISSX/issx_contracts.mqh>
#include <ISSX/issx_ui_test.mqh>
#include <ISSX/issx_debug_engine.mqh>
#include <ISSX/issx_menu.mqh>

input string InpFirmId                  = "default_firm";
input bool   InpIncludeCustomSymbols    = false;
input int    InpEA1MaxSymbols           = 300;
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

input bool   InpMinimalDebugMode        = true;  // default: wrapper shell + heartbeat only
input bool   InpGateRuntimeScheduler    = false; // enables runtime init + kernel pulse
input bool   InpGateTimerHeavyWork      = true;  // foundation default: enables ISSX_RunKernelCycle from timer
input bool   InpGateMenuEngine          = true;  // foundation default: menu visibility with safety locks
input bool   InpGateChartUiUpdates      = true;  // foundation default: chart UI events for safe menu diagnostics
input bool   InpGateTickHeavyWork       = false; // enables any non-trivial tick path
input bool   InpGateUiProjection        = true;  // foundation default: enable HUD projection

ISSX_RegistryBundle g_registry;
ISSX_StageRuntime   g_runtime;

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
ISSX_MenuEngine     g_menu;
bool                g_ea_enabled[5]={true,false,false,false,false};
string              g_menu_prefix               = "";
string              g_last_checkpoint           = "boot";
bool                g_first_tick_logged         = false;
bool                g_first_timer_logged        = false;
bool                g_first_chart_event_logged  = false;
ulong               g_timer_pulse_count         = 0;
ulong               g_last_comment_pulse        = 0;
string              g_last_status_comment       = "";
bool                g_logged_timer_heavy_skip   = false;
bool                g_logged_tick_heavy_skip    = false;
bool                g_logged_chart_ui_skip      = false;
string              g_last_feature_runtime_scheduler = "";
string              g_last_feature_timer_heavy       = "";
string              g_last_feature_init_runtime_scheduler = "";
string              g_last_feature_init_menu_engine       = "";
string              g_last_feature_run_tick_heavy         = "";
string              g_last_feature_run_chart_ui           = "";
string              g_last_kernel_result             = "unknown";
string              g_last_kernel_reason             = "none";
long                g_last_kernel_elapsed_ms         = 0;
string              g_last_ea1_stage_run             = "skipped";
string              g_last_ea1_stage_reason          = "none";
long                g_last_ea1_stage_elapsed_ms      = 0;
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

#define ISSX_HUD_OBJECT_NAME "ISSX_HUD"

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
   if(StringLen(InpFirmId)>0 && InpFirmId!="default_firm")
      return InpFirmId;

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
   j.NameString("stage_run",g_last_ea1_stage_run);
   j.NameString("stage_reason",g_last_ea1_stage_reason);
   j.NameInt("stage_elapsed_ms",(int)g_last_ea1_stage_elapsed_ms);
   j.NameString("publish_state",g_last_ea1_publish_state);
   j.NameString("publish_reason",g_last_ea1_publish_reason);
   j.NameBool("requested",InpEnableEA1);
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
      g_debug.Write("ERROR","ea1_publish","publish_complete_fail",
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

   g_debug.Write("INFO","ea1_publish","publish_internal_write_start","path="+ISSX_PersistencePath::PayloadCurrent(g_firm_id,issx_stage_ea1)+" bytes="+IntegerToString(StringLen(stage_json)));
   const bool stage_write_ok=ISSX_PersistStageJson(issx_stage_ea1,header,manifest,stage_json);
   g_last_ea1_stage_write_state=(stage_write_ok?"success":"failed");
   g_debug.Write((stage_write_ok?"INFO":"ERROR"),"ea1_publish",(stage_write_ok?"publish_internal_write_ok":"publish_internal_write_fail"),
                 "path="+ISSX_PersistencePath::PayloadCurrent(g_firm_id,issx_stage_ea1)+" reason="+(stage_write_ok?"ok":"persist_stage_json_failed"));

   bool universe_rotate_ok=true;
   bool universe_write_ok=true;
   string universe_current_path=ISSX_Util::JoinPath(ISSX_PersistencePath::UniverseDir(g_firm_id),ISSX_BIN_BROKER_UNIVERSE_CURRENT);
   if(StringLen(broker_dump_json)>2)
     {
      universe_rotate_ok=ISSX_BrokerUniverseDump::RotateCurrentToPrevious(g_firm_id);
      universe_write_ok=ISSX_BrokerUniverseDump::WriteCurrent(g_firm_id,broker_dump_json,manifest,true);
     }
   else
     {
      universe_write_ok=ISSX_FileIO::Exists(universe_current_path);
     }
   g_last_ea1_universe_write_state=((universe_rotate_ok && universe_write_ok)?"success":"failed");

   bool debug_write_ok=true;
   if(InpProjectDebugSnapshots)
      debug_write_ok=ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea1,debug_snapshot_json);
   g_last_ea1_debug_write_state=(debug_write_ok?"success":"failed");

   g_debug.Write("INFO","ea1_publish","publish_operator_market_write_start","path="+g_market_json_relative_path+" bytes="+IntegerToString(StringLen(broker_dump_json)));
   ResetLastError();
   bool operator_json_ok=false;
   int operator_json_err=0;
   if(StringLen(broker_dump_json)>2)
      operator_json_ok=ISSX_FileIO::WriteText(g_market_json_relative_path,broker_dump_json);
   else
      operator_json_ok=ISSX_FileIO::CopyText(universe_current_path,g_market_json_relative_path);
   operator_json_err=GetLastError();
   g_last_ea1_root_status_state=(operator_json_ok?"success":"failed");
   g_debug.Write((operator_json_ok?"INFO":"ERROR"),"ea1_publish",(operator_json_ok?"publish_operator_market_write_ok":"publish_operator_market_write_fail"),
                 "path="+g_market_json_relative_path+" bytes="+IntegerToString(StringLen(broker_dump_json))+" last_error="+IntegerToString(operator_json_err));

   g_debug.Write("INFO","ea1_publish","publish_operator_debug_write_start","src="+g_debug.ActivePath()+" dst="+g_market_log_relative_path);
   ResetLastError();
   const bool operator_log_projection_ok=ISSX_FileIO::CopyText(g_debug.ActivePath(),g_market_log_relative_path);
   const int operator_log_err=GetLastError();
   g_last_ea1_root_debug_state=(operator_log_projection_ok?"success":"failed");
   g_debug.Write((operator_log_projection_ok?"INFO":"ERROR"),"ea1_publish",(operator_log_projection_ok?"publish_operator_debug_write_ok":"publish_operator_debug_write_fail"),
                 "path="+g_market_log_relative_path+" last_error="+IntegerToString(operator_log_err));

   g_debug.Write("INFO","ea1_publish","publish_root_projection_start","json="+g_market_json_relative_path+" log="+g_market_log_relative_path);
   const bool root_projection_ok=(operator_json_ok && operator_log_projection_ok);
   g_last_ea1_root_universe_state="skipped";
   g_debug.Write((root_projection_ok?"INFO":"ERROR"),"ea1_publish",(root_projection_ok?"publish_root_projection_ok":"publish_root_projection_fail"),
                 "json="+g_last_ea1_root_status_state+" log="+g_last_ea1_root_debug_state);

   const bool publish_ok=(stage_write_ok && debug_write_ok && universe_rotate_ok && universe_write_ok && root_projection_ok);
   g_last_ea1_publish_state=(publish_ok?"success":"degraded");
   g_last_ea1_publish_reason=(publish_ok?"ok":"operator_or_internal_write_failed");
   out_reason=g_last_ea1_publish_reason;

   g_debug.Write((publish_ok?"INFO":"ERROR"),"ea1_publish",(publish_ok?"publish_complete_ok":"publish_complete_fail"),
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

   if(InpProjectDebugSnapshots)
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

   if(InpProjectDebugSnapshots)
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

   if(InpProjectDebugSnapshots)
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
   ISSX_FileIO::WriteText(ISSX_PersistencePath::RootExport(g_firm_id),export_json);

   if(InpProjectDebugSnapshots)
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

void ISSX_LogFoundationStartupProfile(const bool ea1_enabled,const bool timer_heavy_enabled)
  {
   if(!ea1_enabled && !timer_heavy_enabled)
      g_startup_profile="shell_only";
   else if(ea1_enabled && timer_heavy_enabled)
      g_startup_profile="ea1_foundation_active";
   else
      g_startup_profile="invalid_contradictory";

   g_debug.Write((g_startup_profile=="invalid_contradictory"?"WARN":"INFO"),"startup","profile",
                 "mode="+g_startup_profile+
                 " minimal_debug="+ISSX_OnOff(InpMinimalDebugMode)+
                 " isolation="+ISSX_OnOff(InpIsolationMode)+
                 " ea1="+ISSX_OnOff(ea1_enabled)+
                 " timer_heavy="+ISSX_OnOff(timer_heavy_enabled));
  }

void ISSX_SetCheckpoint(const string cp)
  {
   g_last_checkpoint=cp;
   g_debug.Write("INFO","checkpoint","set",cp);
  }

bool ISSX_IsGateOn(const bool gate_value,const bool minimal_default_on)
  {
   if(InpMinimalDebugMode)
      return minimal_default_on;
   return gate_value;
  }

bool ISSX_IsTimerHeavyWorkOn()
  {
   if(InpGateTimerHeavyWork)
      return true;
   return ISSX_IsGateOn(InpGateTimerHeavyWork,false);
  }

bool ISSX_IsUiProjectionOn()
  {
   if(InpGateUiProjection)
      return true;
   return ISSX_IsGateOn(InpGateUiProjection,false);
  }

bool ISSX_IsMenuEngineOn()
  {
   if(InpGateMenuEngine)
      return true;
   return ISSX_IsGateOn(InpGateMenuEngine,false);
  }

bool ISSX_IsChartUiUpdatesOn()
  {
   if(InpGateChartUiUpdates)
      return true;
   return ISSX_IsGateOn(InpGateChartUiUpdates,false);
  }

void ISSX_LogGateSnapshot()
  {
   const bool gate_runtime_scheduler=ISSX_IsGateOn(InpGateRuntimeScheduler,false);
   const bool gate_timer_heavy=ISSX_IsTimerHeavyWorkOn();
   const bool gate_menu=ISSX_IsMenuEngineOn();
   const bool gate_chart_ui=ISSX_IsChartUiUpdatesOn();
   const bool gate_tick_heavy=ISSX_IsGateOn(InpGateTickHeavyWork,false);
   const bool gate_ui_projection=ISSX_IsUiProjectionOn();

   g_debug.Write("INFO","gates","snapshot",
                 "minimal_debug="+(InpMinimalDebugMode?"on":"off")+
                 " runtime_scheduler="+(gate_runtime_scheduler?"on":"off")+
                 " timer_heavy_work="+(gate_timer_heavy?"on":"off")+
                 " menu_engine="+(gate_menu?"on":"off")+
                 " chart_ui_updates="+(gate_chart_ui?"on":"off")+
                 " tick_heavy_work="+(gate_tick_heavy?"on":"off")+
                 " ui_projection="+(gate_ui_projection?"on":"off"));
  }

string ISSX_OnOff(const bool value)
  {
   return (value?"on":"off");
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

void ISSX_UpdateHUD()
  {
   if(!ISSX_IsUiProjectionOn())
      return;

   const bool gate_runtime_scheduler=ISSX_IsGateOn(InpGateRuntimeScheduler,false);
   const bool gate_timer_heavy=ISSX_IsTimerHeavyWorkOn();
   const bool gate_tick_heavy=ISSX_IsGateOn(InpGateTickHeavyWork,false);
   const bool gate_menu=ISSX_IsMenuEngineOn();
   const bool gate_chart_ui=ISSX_IsChartUiUpdatesOn();
   const bool gate_ui_projection=ISSX_IsUiProjectionOn();

   datetime server_time=TimeTradeServer();
   if(server_time<=0)
      server_time=TimeCurrent();

   string hud="ISSX Market HUD | v1.714 | pulse="+ISSX_Util::ULongToStringX(g_timer_pulse_count)+"\n";
   hud+="Broker="+g_operator_broker_name+" | Server="+g_operator_server_name+"\n";
   hud+="Kernel="+g_last_kernel_result+" ("+g_last_kernel_reason+") ms="+IntegerToString((int)g_last_kernel_elapsed_ms)+"\n";

   string market_state="READY";
   if(g_ea1.runtime_state==EA1_STATE_DISCOVERY)
      market_state="DISCOVERY";
   else if(g_ea1.runtime_state==EA1_STATE_HYDRATING)
      market_state="HYDRATING";

   hud+="Market="+market_state+" reason="+g_last_ea1_stage_reason+" discovered="+IntegerToString(g_ea1.universe.broker_universe)+" publishable="+IntegerToString(g_ea1.universe.publishable_universe)+"\n";
   hud+="symbols processed: "+IntegerToString(g_ea1.hydration_processed)+" / "+IntegerToString(g_ea1.hydration_total)+"\n";
   hud+="Discovery="+g_ea1.discovery_status_reason+" publish="+g_last_ea1_publish_state+"/"+g_last_ea1_publish_reason+"\n";
   hud+="Writes json="+g_last_ea1_root_status_state+" log="+g_last_ea1_root_debug_state+" internal="+g_last_ea1_stage_write_state+"\n";
   hud+="Files: "+g_market_json_file_name+" | "+g_market_log_file_name+"\n";
   hud+="History OFF | Selection OFF | Correlation OFF | Contracts OFF";

   if(ObjectFind(0,ISSX_HUD_OBJECT_NAME)<0)
     {
      if(!ObjectCreate(0,ISSX_HUD_OBJECT_NAME,OBJ_LABEL,0,0,0))
        {
         g_debug.Write("WARN","hud","create_failed","name="+ISSX_HUD_OBJECT_NAME);
         return;
        }
      ObjectSetInteger(0,ISSX_HUD_OBJECT_NAME,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,ISSX_HUD_OBJECT_NAME,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,ISSX_HUD_OBJECT_NAME,OBJPROP_YDISTANCE,10);
      ObjectSetInteger(0,ISSX_HUD_OBJECT_NAME,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,ISSX_HUD_OBJECT_NAME,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,ISSX_HUD_OBJECT_NAME,OBJPROP_COLOR,clrLightGray);
      ObjectSetInteger(0,ISSX_HUD_OBJECT_NAME,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,ISSX_HUD_OBJECT_NAME,OBJPROP_HIDDEN,true);
     }

   ObjectSetString(0,ISSX_HUD_OBJECT_NAME,OBJPROP_TEXT,hud);
  }

bool ISSX_RunUiProjectionSafe()
  {
   ISSX_SetCheckpoint("ui_projection_enter");

   if(!ISSX_IsUiProjectionOn())
     {
      g_debug.Write("INFO","ui","projection_skipped","disabled_by_gate");
      return true;
     }

   if(!InpProjectStageStatusRoot && !InpProjectUniverseSnapshot && !InpProjectDebugSnapshots)
     {
      g_debug.Write("INFO","ui","projection_skipped","all ui projections disabled");
      return true;
     }

   // Avoid high-risk aggregate calls when modules are intentionally disabled during isolation.
   if(InpIsolationMode)
     {
      g_debug.Write("INFO","ui","projection_isolation_mode","skipping BuildAggregate heavy projection");
      return true;
     }

   ISSX_DebugAggregate agg=ISSX_UI_Test::BuildAggregate(g_firm_id,g_runtime.State(),g_ea1,g_ea2,g_ea3,g_ea4,g_ea5);
   ISSX_UI_Test::ProjectDebugRoot(g_firm_id,agg);

   if(InpProjectStageStatusRoot)
      ISSX_UI_Test::ProjectStageStatusRoot(g_firm_id,agg);
   if(InpProjectUniverseSnapshot)
      ISSX_UI_Test::ProjectUniverseSnapshotRoot(g_firm_id,g_runtime.State());

   if(InpProjectDebugSnapshots)
     {
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea1,ISSX_UI_Test::BuildStageSnapshotEA1(g_ea1));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea2,ISSX_UI_Test::BuildStageSnapshotEA2(g_ea2));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea3,ISSX_UI_Test::BuildStageSnapshotEA3(g_ea3));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea4,ISSX_UI_Test::BuildStageSnapshotEA4(g_ea4));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea5,ISSX_UI_Test::BuildStageSnapshotEA5(g_ea5));
     }

   // HUD rendering is handled by ISSX_UpdateHUD() as a read-only chart projection.
   ISSX_SetCheckpoint("ui_projection_ok");
   return true;
  }

bool ISSX_RunKernelCycle(bool &ea1_stage_ran,string &ea1_stage_result,string &ea1_stage_reason)
  {
   ea1_stage_ran=false;
   ea1_stage_result="skipped";
   ea1_stage_reason="none";
   ISSX_SetCheckpoint("kernel_cycle_enter");
   g_last_kernel_reason="none";
   g_debug.Write("INFO","kernel","cycle_enter","bootstrapped="+(g_bootstrapped?"true":"false"));
   if(ISSX_IsGateOn(InpGateRuntimeScheduler,false))
      g_runtime.OnPulse();
   else
      g_debug.Write("INFO","kernel","runtime_scheduler_skipped","disabled_by_gate");

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
         g_debug.Write("ERROR","stage_init","ea1_market","failed reason="+ea1_stage_reason);
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
      ea1_stage_reason="requested_off";
      return false;
     }

   ISSX_SetCheckpoint("ea1_stage_slice_enter");
   g_debug.Write("INFO","stage_init","ea1_market","success");
   g_debug.Write("INFO","ea1","stage_slice","enter");
   ea1_stage_ran=true;
   g_ea1.hydration_batch_size=MathMax(1,InpEA1HydrationBatchSize);
   if(!ISSX_MarketEngine::StageSlice(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,InpEA1MaxSymbols))
     {
      g_debug.Write("INFO","stage_run","ea1_market","failed");
      g_debug.Write("INFO","stage_reason","ea1_market","stage_slice_returned_false");
      g_last_kernel_reason="ea1_stage_slice_false";
      g_debug.Write("WARN","ea1_market","discovery_failed","reason=stage_slice_returned_false");
      g_debug.Write("ERROR","ea1","stage_slice_failed","returned false");
      ea1_stage_result="failed";
      ea1_stage_reason="stage_slice_returned_false";
      g_debug.Write("ERROR","stage_run","ea1_market",ea1_stage_result);
      g_debug.Write("ERROR","stage_reason","ea1_market",ea1_stage_reason);
      return false;
     }


   g_debug.Write("INFO","ea1","stage_slice_ok","symbols="+IntegerToString(ArraySize(g_ea1.symbols)));

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
      ea1_stage_result="skipped";
      ea1_stage_reason=g_ea1.discovery_status_reason;
     }

   g_debug.Write((ea1_stage_result=="failed"?"ERROR":"INFO"),"stage_run","ea1_market",ea1_stage_result);
   g_debug.Write((ea1_stage_result=="failed"?"ERROR":"INFO"),"stage_reason","ea1_market",ea1_stage_reason);
   g_debug.Write("INFO","stage_elapsed_ms","ea1_market",IntegerToString(g_ea1.discovery_elapsed_ms));
   g_last_ea1_stage_run=ea1_stage_result;
   g_last_ea1_stage_reason=ea1_stage_reason;
   g_last_ea1_stage_elapsed_ms=g_ea1.discovery_elapsed_ms;

   string ea1_stage_status_detail="success";
   string ea1_stage_reason_detail="discovery_success";
   if(g_ea1.discovery_skipped)
     {
      ea1_stage_status_detail="skipped";
      ea1_stage_reason_detail=g_ea1.discovery_status_reason;
     }
   else if(!g_ea1.discovery_success)
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
   g_debug.Write("INFO","stage_reason","ea1_market",ea1_stage_reason_detail+" elapsed_ms="+IntegerToString(g_ea1.discovery_elapsed_ms));
   g_debug.Write("INFO","stage_elapsed_ms","ea1_market","value="+IntegerToString(g_ea1.discovery_elapsed_ms));

   if(ArraySize(g_ea1.symbols)<=0)
     {
      g_last_kernel_reason="ea1_zero_symbols";
      g_debug.Write("WARN","ea1","zero_symbols","skipping downstream stages");
      g_bootstrapped=true;
      return true;
     }

   g_last_kernel_reason="ea1_ran";

   g_debug.Write("INFO","ea1","stage_publish","start");
   if(!g_ea1.hydration_complete)
     {
      g_debug.Write("INFO","ea1_publish","publish_skip_hydration","reason=hydration_not_complete processed="+IntegerToString(g_ea1.hydration_processed)+" total="+IntegerToString(g_ea1.hydration_total));
      g_last_ea1_publish_state="skipped";
      g_last_ea1_publish_reason="hydration_not_complete";
     }
   else
     {
      g_debug.Write("INFO","ea1_publish","publish_enter","checkpoint=publish_enter");
      g_debug.Write("INFO","ea1_publish","publish_build_stage_json_start","checkpoint=publish_build_stage_json_start");
      const bool stage_publish_ok=ISSX_MarketEngine::StagePublish(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,stage_json,debug_json);
      g_debug.Write((stage_publish_ok?"INFO":"ERROR"),"ea1_publish",(stage_publish_ok?"publish_build_stage_json_ok":"publish_build_stage_json_fail"),
                    "len="+IntegerToString(StringLen(stage_json))+" reason="+(stage_publish_ok?"ok":"stage_publish_returned_false"));
      g_debug.Write("INFO","ea1_publish","publish_build_debug_json_start","checkpoint=publish_build_debug_json_start");
      const bool debug_json_ok=(StringLen(debug_json)>2);
      g_debug.Write((debug_json_ok?"INFO":"ERROR"),"ea1_publish",(debug_json_ok?"publish_build_debug_json_ok":"publish_build_debug_json_fail"),
                    "len="+IntegerToString(StringLen(debug_json))+" reason="+(debug_json_ok?"ok":"debug_json_too_small"));

      string ea1_publish_reason="ok";
      bool publish_ok=false;
      if(stage_publish_ok)
         publish_ok=ISSX_ProjectEA1(stage_json,"",debug_json,ea1_publish_reason);
      else
         ea1_publish_reason="stage_publish_build_failed";

      if(!publish_ok)
     {
      g_debug.Write("WARN","ea1_publish","degraded","reason="+ea1_publish_reason+" stage_json="+(stage_publish_ok?"ok":"fail"));
      if(ea1_stage_result=="success")
         ea1_stage_result="degraded";
      if(ea1_stage_reason=="ready")
         ea1_stage_reason="publish_degraded_"+ea1_publish_reason;
      g_last_ea1_stage_run=ea1_stage_result;
      g_last_ea1_stage_reason=ea1_stage_reason;
      g_debug.Write("INFO","stage_run","ea1_market",ea1_stage_result);
      g_debug.Write("INFO","stage_reason","ea1_market",ea1_stage_reason);
     }
   }

   string ea1_symbols[];
   const int ea1_count=ISSX_CopyEA1Symbols(ea1_symbols);
   g_debug.Write("INFO","ea1","symbol_copy","count="+IntegerToString(ea1_count));

   if(ea1_count<=0)
     {
      g_debug.Write("WARN","ea1","symbol_copy_empty","ending cycle safely");
      g_bootstrapped=true;
      return true;
     }

   if(g_ea_enabled[1] && !g_bootstrapped)
     {
      g_debug.Write("INFO","ea2","stage_boot","start");
      ISSX_HistoryEngine::StageBoot(g_ea2,ea1_symbols,InpEA2DeepProfileDefault);
     }

   if(g_ea_enabled[1])
     {
      ISSX_SetCheckpoint("ea2_stage_slice_start");
      g_debug.Write("INFO","ea2","stage_slice","start");
      ISSX_HistoryEngine::StageSlice(g_ea2,ea1_symbols,InpEA2DeepProfileDefault,InpEA2MaxSymbolsPerSlice);
      stage_json=ISSX_HistoryEngine::StagePublish(g_ea2);
      debug_json=ISSX_HistoryEngine::BuildDebugSnapshot(g_ea2);
      ISSX_ProjectEA2(stage_json,debug_json);
     }
   else
      g_debug.Write("INFO","ea2","disabled","stage skipped");

   if(g_ea_enabled[2] && !g_bootstrapped)
     {
      g_debug.Write("INFO","ea3","stage_boot","start");
      ISSX_SelectionEngine::StageBoot(g_firm_id,g_ea1,g_ea2,g_ea3);
     }

   if(g_ea_enabled[2])
     {
      ISSX_SetCheckpoint("ea3_stage_slice_start");
      g_debug.Write("INFO","ea3","stage_slice","start");
      ISSX_SelectionEngine::StageSlice(g_firm_id,g_ea1,g_ea2,g_ea3);
      string ea3_debug="";
      ISSX_SelectionEngine::StagePublish(g_ea3,stage_json,ea3_debug);
      ISSX_ProjectEA3(stage_json,ea3_debug);
     }
   else
      g_debug.Write("INFO","ea3","disabled","stage skipped");

   if(g_ea_enabled[3] && !g_bootstrapped)
     {
      g_debug.Write("INFO","ea4","stage_boot","start");
      ISSX_CorrelationEngine::StageBoot(g_ea4,g_firm_id);
     }

   if(g_ea_enabled[3])
     {
      ISSX_SetCheckpoint("ea4_stage_slice_start");
      g_debug.Write("INFO","ea4","stage_slice","start");
      ISSX_CorrelationEngine::StageSlice(g_ea4,g_firm_id,g_ea1,g_ea3,ISSX_CurrentKernelMinuteId());
      string ea4_debug="";
      ISSX_CorrelationEngine::StagePublish(g_ea4,stage_json,ea4_debug);
      ISSX_ProjectEA4(stage_json,ea4_debug);
     }
   else
      g_debug.Write("INFO","ea4","disabled","stage skipped");

   ISSX_EA4_OptionalIntelligenceExport ea4_optional_intel[];
   ISSX_EA5_OptionalIntelligence optional_intel[];
   ArrayResize(ea4_optional_intel,0);
   ArrayResize(optional_intel,0);

   if(g_ea_enabled[4])
     {
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
         g_last_ea5_export_minute_id=current_minute_id;
        }
     }
   else
      g_debug.Write("INFO","ea5","disabled","stage skipped");

   g_debug.Write("INFO","ui","aggregate","building snapshots");
   if(!ISSX_RunUiProjectionSafe())
      g_debug.Write("WARN","ui","projection_failed","non-critical; continuing");
   g_bootstrapped=true;
   g_debug.Write("INFO","kernel","cycle_exit","ok=true");
   return true;
  }

int OnInit()
  {
   ISSX_ResolveOperatorContext();
   if(!g_debug.BeginSession(g_market_log_relative_path,_Symbol,_Period,g_operator_server_name,g_operator_broker_name,g_operator_login_id))
      Print("ISSX: debug session failed to open");
   ISSX_SetCheckpoint("oninit_enter");
   g_debug.Write("INFO","lifecycle","oninit_start","build="+IntegerToString((int)__MQLBUILD__));
   g_debug.Write("INFO","debug","sink","mode="+g_debug.ActiveMode()+" path="+g_debug.ActivePath());

   MathSrand((uint)TimeLocal());

   g_boot_id        = ISSX_WrapperBootId();
   g_instance_guid  = ISSX_WrapperInstanceGuid();
   g_writer_nonce   = ISSX_WrapperNonce();
   g_firm_id        = ISSX_ResolveFirmId();

   g_debug.Write("INFO","context","identity","boot_id="+g_boot_id+" instance="+g_instance_guid+" nonce="+g_writer_nonce+" firm_id="+g_firm_id);
   g_debug.Write("INFO","context","terminal","company="+TerminalInfoString(TERMINAL_COMPANY)+" name="+TerminalInfoString(TERMINAL_NAME));
   g_debug.Write("INFO","context","account","broker="+g_operator_broker_name+" server="+g_operator_server_name+" login="+IntegerToString((int)g_operator_login_id));

   g_ea_enabled[0]=true;
   g_ea_enabled[1]=false;
   g_ea_enabled[2]=false;
   g_ea_enabled[3]=false;
   g_ea_enabled[4]=false;
   if(!InpIsolationMode)
     {
      g_ea_enabled[0]=InpEnableEA1;
      g_ea_enabled[1]=InpEnableEA2;
      g_ea_enabled[2]=InpEnableEA3;
      g_ea_enabled[3]=InpEnableEA4;
      g_ea_enabled[4]=InpEnableEA5;
     }
   g_debug.Write("INFO","modules","states_forced",
                 "ea1="+(g_ea_enabled[0]?"on":"off")+
                 " ea2="+(g_ea_enabled[1]?"on":"off")+
                 " ea3="+(g_ea_enabled[2]?"on":"off")+
                 " ea4="+(g_ea_enabled[3]?"on":"off")+
                 " ea5="+(g_ea_enabled[4]?"on":"off")+" isolation="+(InpIsolationMode?"true":"false"));

   const bool req_runtime_scheduler=InpGateRuntimeScheduler;
   const bool req_timer_heavy=InpGateTimerHeavyWork;
   const bool req_tick_heavy=InpGateTickHeavyWork;
   const bool req_menu_engine=InpGateMenuEngine;
   const bool req_chart_ui=InpGateChartUiUpdates;
   const bool req_ui_projection=InpGateUiProjection;

   const bool eff_runtime_scheduler=ISSX_IsGateOn(req_runtime_scheduler,false);
   const bool eff_timer_heavy=ISSX_IsTimerHeavyWorkOn();
   const bool eff_tick_heavy=ISSX_IsGateOn(req_tick_heavy,false);
   const bool eff_menu_engine=ISSX_IsMenuEngineOn();
   const bool eff_chart_ui=ISSX_IsChartUiUpdatesOn();
   const bool eff_ui_projection=ISSX_IsUiProjectionOn();

   g_debug.Write("INFO","feature_state","session_snapshot",
                 "minimal_debug=requested="+ISSX_OnOff(InpMinimalDebugMode)+" effective="+ISSX_OnOff(InpMinimalDebugMode)+
                 " isolation=requested="+ISSX_OnOff(InpIsolationMode)+" effective="+ISSX_OnOff(InpIsolationMode)+
                 " runtime_scheduler=requested="+ISSX_OnOff(req_runtime_scheduler)+" effective="+ISSX_OnOff(eff_runtime_scheduler)+
                 " timer_heavy_work=requested="+ISSX_OnOff(req_timer_heavy)+" effective="+ISSX_OnOff(eff_timer_heavy)+
                 " tick_heavy_work=requested="+ISSX_OnOff(req_tick_heavy)+" effective="+ISSX_OnOff(eff_tick_heavy)+
                 " menu_engine=requested="+ISSX_OnOff(req_menu_engine)+" effective="+ISSX_OnOff(eff_menu_engine)+
                 " chart_ui_updates=requested="+ISSX_OnOff(req_chart_ui)+" effective="+ISSX_OnOff(eff_chart_ui)+
                 " ui_projection=requested="+ISSX_OnOff(req_ui_projection)+" effective="+ISSX_OnOff(eff_ui_projection));

   g_debug.Write("INFO","feature_state","minimal_debug_mode","requested="+ISSX_OnOff(InpMinimalDebugMode)+" effective="+ISSX_OnOff(InpMinimalDebugMode));
   g_debug.Write("INFO","feature_state","isolation_mode","requested="+ISSX_OnOff(InpIsolationMode)+" effective="+ISSX_OnOff(InpIsolationMode));
   g_debug.Write("INFO","feature_state","runtime_scheduler","requested="+ISSX_OnOff(req_runtime_scheduler)+" effective="+ISSX_OnOff(eff_runtime_scheduler)+" reason="+(eff_runtime_scheduler?"active":(InpMinimalDebugMode?"minimal_debug_mode":"gate_off")));
   g_debug.Write("INFO","feature_state","timer_heavy_work","requested="+ISSX_OnOff(req_timer_heavy)+" effective="+ISSX_OnOff(eff_timer_heavy)+" reason="+(eff_timer_heavy?"active":(InpMinimalDebugMode?"minimal_debug_mode":"gate_off")));
   g_debug.Write("INFO","feature_state","tick_heavy_work","requested="+ISSX_OnOff(req_tick_heavy)+" effective="+ISSX_OnOff(eff_tick_heavy)+" reason="+(eff_tick_heavy?"active":(InpMinimalDebugMode?"minimal_debug_mode":"gate_off")));
   g_debug.Write("INFO","feature_state","menu_engine","requested="+ISSX_OnOff(req_menu_engine)+" effective="+ISSX_OnOff(eff_menu_engine)+" reason="+(eff_menu_engine?"active":(InpMinimalDebugMode?"minimal_debug_mode":"gate_off")));
   g_debug.Write("INFO","feature_state","chart_ui_updates","requested="+ISSX_OnOff(req_chart_ui)+" effective="+ISSX_OnOff(eff_chart_ui)+" reason="+(eff_chart_ui?"active":(InpMinimalDebugMode?"minimal_debug_mode":"gate_off")));
   g_debug.Write("INFO","feature_state","ui_projection","requested="+ISSX_OnOff(req_ui_projection)+" effective="+ISSX_OnOff(eff_ui_projection)+" reason="+(eff_ui_projection?"active":(InpMinimalDebugMode?"minimal_debug_mode":"gate_off")));

   g_debug.Write("INFO","feature_state","ea1_market","requested="+ISSX_OnOff(InpEnableEA1)+" effective="+ISSX_OnOff(g_ea_enabled[0])+" reason="+((InpIsolationMode && !InpEnableEA1)?"isolation_forced_on":(g_ea_enabled[0]?"active":"requested_off")));
   g_debug.Write("INFO","stage_state","ea1_market","requested="+ISSX_OnOff(InpEnableEA1));
   g_debug.Write("INFO","stage_state","ea1_market","effective="+ISSX_OnOff(g_ea_enabled[0]));
   g_debug.Write("INFO","feature_state","ea2_history","requested="+ISSX_OnOff(InpEnableEA2)+" effective="+ISSX_OnOff(g_ea_enabled[1])+" reason="+(g_ea_enabled[1]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea3_selection","requested="+ISSX_OnOff(InpEnableEA3)+" effective="+ISSX_OnOff(g_ea_enabled[2])+" reason="+(g_ea_enabled[2]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea4_correlation","requested="+ISSX_OnOff(InpEnableEA4)+" effective="+ISSX_OnOff(g_ea_enabled[3])+" reason="+(g_ea_enabled[3]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea5_contracts","requested="+ISSX_OnOff(InpEnableEA5)+" effective="+ISSX_OnOff(g_ea_enabled[4])+" reason="+(g_ea_enabled[4]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));

   ISSX_LogFoundationStartupProfile(g_ea_enabled[0],eff_timer_heavy);
   g_debug.Write("INFO","paths","operator_layout",
                 "operator_root="+g_operator_root_relative+"/"+
                 " market_json_path="+g_market_json_relative_path+
                 " market_log_path="+g_market_log_relative_path+
                 " persistence_root="+ISSX_PersistencePath::SharedDir(g_firm_id)+
                 " debug_sink="+g_debug.ActivePath());

   ISSX_LogGateSnapshot();

   // registry + runtime
   g_registry.SeedBlueprintV170();
   string runtime_init_state="skipped | reason="+(InpMinimalDebugMode?"minimal_debug_mode":"gate_off");
   if(ISSX_IsGateOn(InpGateRuntimeScheduler,false))
     {
      g_runtime.Init();
      runtime_init_state="success";
     }
   else
      g_debug.Write("INFO","runtime","init_skipped","disabled_by_gate");
   ISSX_LogFeatureStatus("feature_init","runtime_scheduler",runtime_init_state,g_last_feature_init_runtime_scheduler,false);

   g_bootstrapped     = false;
   g_runtime_ready    = true;
   g_first_cycle_done = false;
   g_kernel_busy      = false;

   g_menu_prefix="ISSX_MENU_OPERATOR_"+ISSX_LongIdPart((long)ChartID())+"_"+ISSX_LongIdPart((long)TimeLocal());
   string menu_init_state="skipped | reason="+(InpMinimalDebugMode?"minimal_debug_mode":"gate_off");
   if(ISSX_IsMenuEngineOn())
     {
      g_menu.Init(g_menu_prefix);
      if(!g_menu.Build(g_ea_enabled))
        {
         g_debug.Write("WARN","ui","menu_build_failed","non-critical UI failure, continuing | "+g_menu.LastError());
         menu_init_state="failed | reason=menu_build_failed";
        }
      else
        {
         g_debug.Write("INFO","ui","menu_build_ok","prefix="+g_menu_prefix);
         menu_init_state="success";
        }
     }
   else
      g_debug.Write("INFO","ui","menu_init_skipped","disabled_by_gate");
   ISSX_LogFeatureStatus("feature_init","menu_engine",menu_init_state,g_last_feature_init_menu_engine,false);

   if(!EventSetTimer(ISSX_EVENT_TIMER_SEC))
     {
      g_debug.Write("ERROR","timer","event_set_failed","err="+IntegerToString(GetLastError()));
      g_debug.Write("ERROR","lifecycle","oninit_end","result=INIT_FAILED (critical timer failure)");
      return INIT_FAILED;
     }

   g_debug.Write("INFO","timer","event_set_ok","sec="+IntegerToString(ISSX_EVENT_TIMER_SEC));
   g_debug.Write("INFO","lifecycle","oninit_end","result=INIT_SUCCEEDED");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_kernel_busy=false;
   if(ISSX_IsMenuEngineOn())
      g_menu.Destroy();
   ObjectDelete(0,ISSX_HUD_OBJECT_NAME);
   g_last_deinit_reason_code=reason;
   g_last_deinit_reason_text=ISSX_DeinitReasonText(reason);
   g_debug.Write("INFO","lifecycle","ondeinit","reason="+IntegerToString(reason)+" reason_text="+g_last_deinit_reason_text+" last_checkpoint="+g_last_checkpoint+" self_remove=false");
   g_debug.Close(reason,"last_checkpoint="+g_last_checkpoint+" file_mode="+g_debug.ActiveMode()+" file_path="+g_debug.ActivePath());
  }

void OnTimer()
  {
   if(!g_runtime_ready)
     {
      Print("ISSX: TIMER skipped runtime not ready");
      g_debug.Write("WARN","timer","skip","runtime_not_ready");
      return;
     }

   if(g_kernel_busy)
     {
      Print("ISSX: TIMER skipped kernel busy");
      g_debug.Write("WARN","timer","skip","kernel_busy");
      return;
     }

   g_kernel_busy=true;

   ISSX_SetCheckpoint("ontimer_enter");
   g_timer_pulse_count++;
   if(!g_first_timer_logged)
     {
      g_debug.Write("INFO","timer","first_heartbeat","first timer heartbeat reached");
      g_first_timer_logged=true;
     }
   const ulong timer_start_us=(ulong)GetMicrosecondCount();
   const bool sampled=((g_timer_pulse_count%15)==1);
   const bool gate_runtime_scheduler=ISSX_IsGateOn(InpGateRuntimeScheduler,false);
   const bool gate_timer_heavy=ISSX_IsTimerHeavyWorkOn();

   if(sampled || !g_first_cycle_done)
      g_debug.Write("INFO","timer","enter","pulse="+ISSX_Util::ULongToStringX(g_timer_pulse_count));

   if(sampled || !g_first_cycle_done)
      g_debug.Write("INFO","timer","heartbeat",
                    "pulse="+ISSX_Util::ULongToStringX(g_timer_pulse_count)+
                    " first_cycle="+(!g_first_cycle_done?"true":"false")+
                    " minimal_mode="+(InpMinimalDebugMode?"true":"false")+
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
   if(kernel_reason=="none")
      kernel_reason=(gate_timer_heavy?"active":"timer_heavy_off");
   g_last_kernel_reason=kernel_reason;

   if(sampled || !timer_cycle_ok)
      g_debug.Write("INFO","timer","kernel_result",(timer_cycle_ok?"ok":"degraded")+" elapsed_ms="+IntegerToString((int)timer_kernel_elapsed_ms)+" timer_heavy="+(gate_timer_heavy?"on":"off")+" reason="+kernel_reason);

   const ulong elapsed_us=(ulong)GetMicrosecondCount()-timer_start_us;
   if(sampled || !timer_cycle_ok)
      g_debug.Write("INFO","timer","elapsed_us","value="+ISSX_Util::ULongToStringX(elapsed_us));

   ISSX_UpdateHUD();

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
   if(!ISSX_IsGateOn(InpGateTickHeavyWork,false))
     {
      if(!g_logged_tick_heavy_skip)
        {
         g_debug.Write("INFO","tick","heavy_work_skipped","disabled_by_gate");
         g_logged_tick_heavy_skip=true;
        }
      ISSX_LogFeatureStatus("feature_run","tick_heavy_work","skipped | reason="+(InpMinimalDebugMode?"minimal_debug_mode":"gate_off"),g_last_feature_run_tick_heavy,tick_sampled);
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
   if(!g_first_chart_event_logged)
     {
      g_debug.Write("INFO","chart_event","first_heartbeat","first chart event reached");
      g_first_chart_event_logged=true;
     }
   g_debug.Write("INFO","chart_event","event","id="+IntegerToString(id)+" obj="+sparam+" lparam="+IntegerToString((int)lparam)+" dparam="+DoubleToString(dparam,4)+" requested_action=inspect effective_action=none");
   static long chart_event_count=0;
   chart_event_count++;
   const bool chart_sampled=((chart_event_count%25)==0);
   const bool chart_ui_on=ISSX_IsChartUiUpdatesOn();
   const bool menu_on=ISSX_IsMenuEngineOn();

   if(!chart_ui_on || !menu_on)
     {
      if(!g_logged_chart_ui_skip)
        {
         g_debug.Write("INFO","chart_event","ui_skip","chart_ui="+ISSX_OnOff(chart_ui_on)+" menu="+ISSX_OnOff(menu_on));
         g_logged_chart_ui_skip=true;
        }
      ISSX_LogFeatureStatus("feature_run","chart_ui_updates","skipped | reason=gate_off chart_ui="+ISSX_OnOff(chart_ui_on)+" menu="+ISSX_OnOff(menu_on),g_last_feature_run_chart_ui,chart_sampled);
      return;
     }

   ISSX_LogFeatureStatus("feature_run","chart_ui_updates","success",g_last_feature_run_chart_ui,chart_sampled);

   if(id==CHARTEVENT_OBJECT_CLICK)
     {
      if(!g_menu.IsOwnedObject(sparam))
        {
         if(chart_sampled)
            g_debug.Write("INFO","ui","menu_click_external","obj="+sparam);
         return;
        }

      const bool allow_toggle=(!InpIsolationMode);
      bool before_state[5];
      for(int i=0;i<5;i++)
         before_state[i]=g_ea_enabled[i];

      const bool clicked_ok=g_menu.HandleClick(sparam,g_ea_enabled,allow_toggle);
      if(clicked_ok)
        {
         const bool build_ok=g_menu.Build(g_ea_enabled);
         g_last_chart_action="menu_toggle_success obj="+sparam;
         g_debug.Write("INFO","ui","menu_toggle",
                       "obj="+sparam+
                       " allow_toggle="+(allow_toggle?"true":"false")+
                       " build="+(build_ok?"ok":"fail")+
                       " ea1="+(g_ea_enabled[0]?"on":"off")+
                       " ea2="+(g_ea_enabled[1]?"on":"off")+
                       " ea3="+(g_ea_enabled[2]?"on":"off")+
                       " ea4="+(g_ea_enabled[3]?"on":"off")+
                       " ea5="+(g_ea_enabled[4]?"on":"off"));
        }
      else
        {
         for(int i=0;i<5;i++)
            g_ea_enabled[i]=before_state[i];
         g_last_chart_action="menu_click_blocked reason="+g_menu.LastError();
         g_debug.Write("WARN","ui","menu_click_blocked",
                       "obj="+sparam+
                       " allow_toggle="+(allow_toggle?"true":"false")+
                       " requested_action=toggle_stage effective_action=blocked reason="+g_menu.LastError()+
                       " ea1="+(g_ea_enabled[0]?"on":"off")+
                       " timer_heavy="+ISSX_OnOff(ISSX_IsTimerHeavyWorkOn()));
        }
     }
  }
