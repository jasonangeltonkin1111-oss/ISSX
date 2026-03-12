#property strict
#property version   "1.7.2"
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
input int    InpEA1MaxSymbols           = 0;
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
input bool   InpGateTimerHeavyWork      = false; // enables ISSX_RunKernelCycle from timer
input bool   InpGateMenuEngine          = false; // enables menu build/interaction
input bool   InpGateChartUiUpdates      = false; // enables chart click handling
input bool   InpGateTickHeavyWork       = false; // enables any non-trivial tick path
input bool   InpGateUiProjection        = false; // enables UI projection/hud in kernel

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

   return id;
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

void ISSX_ProjectEA1(const string stage_json,
                     const string broker_dump_json,
                     const string debug_snapshot_json)
  {
   ISSX_StageHeader header;
   ISSX_Manifest manifest;

   ISSX_SeedHeader(header,
                   issx_stage_ea1,
                   (long)g_ea1.minute_id,
                   ArraySize(g_ea1.symbols),
                   g_ea1.deltas.changed_symbol_count,
                   g_ea1.degraded_flag,
                   0,
                   g_ea1.cohort_fingerprint,
                   g_ea1.universe.broker_universe_fingerprint,
                   g_registry.SchemaFingerprintHex());

   const ISSX_PublishabilityState pub=ISSX_EA1PublishabilityToEnum(g_ea1.stage_publishability_state);

   ISSX_SeedManifest(manifest,
                     header,
                     issx_content_partial,
                     issx_publish_scheduled,
                     pub,
                     g_ea1.stage_minimum_ready_flag,
                     (g_ea1.publishable ? 1 : 0),
                     (g_ea1.degraded_flag ? 1 : 0));

   manifest.taxonomy_hash=g_ea1.taxonomy_hash;
   manifest.comparator_registry_hash=g_ea1.comparator_registry_hash;

   ISSX_PersistStageJson(issx_stage_ea1,header,manifest,stage_json);
   ISSX_BrokerUniverseDump::RotateCurrentToPrevious(g_firm_id);
   ISSX_BrokerUniverseDump::WriteCurrent(g_firm_id,broker_dump_json,manifest,true);

   if(InpProjectDebugSnapshots)
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea1,debug_snapshot_json);
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

void ISSX_LogGateSnapshot()
  {
   const bool gate_runtime_scheduler=ISSX_IsGateOn(InpGateRuntimeScheduler,false);
   const bool gate_timer_heavy=ISSX_IsGateOn(InpGateTimerHeavyWork,false);
   const bool gate_menu=ISSX_IsGateOn(InpGateMenuEngine,false);
   const bool gate_chart_ui=ISSX_IsGateOn(InpGateChartUiUpdates,false);
   const bool gate_tick_heavy=ISSX_IsGateOn(InpGateTickHeavyWork,false);
   const bool gate_ui_projection=ISSX_IsGateOn(InpGateUiProjection,false);

   g_debug.Write("INFO","gates","snapshot",
                 "minimal_debug="+(InpMinimalDebugMode?"on":"off")+
                 " runtime_scheduler="+(gate_runtime_scheduler?"on":"off")+
                 " timer_heavy_work="+(gate_timer_heavy?"on":"off")+
                 " menu_engine="+(gate_menu?"on":"off")+
                 " chart_ui_updates="+(gate_chart_ui?"on":"off")+
                 " tick_heavy_work="+(gate_tick_heavy?"on":"off")+
                 " ui_projection="+(gate_ui_projection?"on":"off"));
  }

bool ISSX_RunUiProjectionSafe()
  {
   ISSX_SetCheckpoint("ui_projection_enter");

   if(!ISSX_IsGateOn(InpGateUiProjection,false))
     {
      g_debug.Write("INFO","ui","projection_skipped","disabled_by_gate");
      return true;
     }

   if(!InpProjectStageStatusRoot && !InpProjectUniverseSnapshot && !InpProjectDebugSnapshots)
     {
      ISSX_LogFeatureLifecycle("feature_run","ui_projection","skipped | reason=all_projection_switches_off",g_last_run_ui_projection,false);
      g_debug.Write("INFO","ui","projection_skipped","all ui projections disabled");
      return true;
     }

   // Avoid high-risk aggregate calls when modules are intentionally disabled during isolation.
   if(InpIsolationMode)
     {
      ISSX_LogFeatureLifecycle("feature_run","ui_projection","skipped | reason=isolation_mode",g_last_run_ui_projection,false);
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

   ISSX_LogFeatureLifecycle("feature_run","ui_projection","success",g_last_run_ui_projection,false);
   Comment(ISSX_UI_Test::BuildHudText(agg));
   ISSX_SetCheckpoint("ui_projection_ok");
   return true;
  }

bool ISSX_RunKernelCycle()
  {
   ISSX_SetCheckpoint("kernel_cycle_enter");
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
      ISSX_MarketEngine::StageBoot(g_ea1);
     }

   if(!g_ea_enabled[0])
     {
      g_debug.Write("WARN","ea1","disabled","EA1 disabled - no critical module active");
      return false;
     }

   ISSX_SetCheckpoint("ea1_stage_slice_enter");
   g_debug.Write("INFO","ea1","stage_slice","enter");
   if(!ISSX_MarketEngine::StageSlice(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,InpEA1MaxSymbols))
     {
      g_debug.Write("ERROR","ea1","stage_slice_failed","returned false");
      return false;
     }

   g_debug.Write("INFO","ea1","stage_slice_ok","symbols="+IntegerToString(ArraySize(g_ea1.symbols)));

   if(ArraySize(g_ea1.symbols)<=0)
     {
      g_debug.Write("WARN","ea1","zero_symbols","skipping downstream stages");
      g_bootstrapped=true;
      return true;
     }

   g_debug.Write("INFO","ea1","stage_publish","start");
   ISSX_MarketEngine::StagePublish(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,stage_json,debug_json);
   ISSX_MarketEngine::BuildUniverseDump(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,broker_dump_json);
   ISSX_ProjectEA1(stage_json,broker_dump_json,debug_json);

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
   if(!g_debug.BeginSession("ISSX",_Symbol,_Period))
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
   g_debug.Write("INFO","context","account","server="+AccountInfoString(ACCOUNT_SERVER)+" login="+IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)));

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
   ISSX_LogGateSnapshot();

   const bool req_runtime_scheduler=InpGateRuntimeScheduler;
   const bool req_timer_heavy=InpGateTimerHeavyWork;
   const bool req_tick_heavy=InpGateTickHeavyWork;
   const bool req_menu_engine=InpGateMenuEngine;
   const bool req_chart_ui=InpGateChartUiUpdates;
   const bool req_ui_projection=InpGateUiProjection;

   const bool eff_runtime_scheduler=ISSX_IsGateOn(req_runtime_scheduler,false);
   const bool eff_timer_heavy=ISSX_IsGateOn(req_timer_heavy,false);
   const bool eff_tick_heavy=ISSX_IsGateOn(req_tick_heavy,false);
   const bool eff_menu_engine=ISSX_IsGateOn(req_menu_engine,false);
   const bool eff_chart_ui=ISSX_IsGateOn(req_chart_ui,false);
   const bool eff_ui_projection=ISSX_IsGateOn(req_ui_projection,false);

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
   g_debug.Write("INFO","feature_state","ea2_history","requested="+ISSX_OnOff(InpEnableEA2)+" effective="+ISSX_OnOff(g_ea_enabled[1])+" reason="+(g_ea_enabled[1]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea3_selection","requested="+ISSX_OnOff(InpEnableEA3)+" effective="+ISSX_OnOff(g_ea_enabled[2])+" reason="+(g_ea_enabled[2]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea4_correlation","requested="+ISSX_OnOff(InpEnableEA4)+" effective="+ISSX_OnOff(g_ea_enabled[3])+" reason="+(g_ea_enabled[3]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea5_contracts","requested="+ISSX_OnOff(InpEnableEA5)+" effective="+ISSX_OnOff(g_ea_enabled[4])+" reason="+(g_ea_enabled[4]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));

   ISSX_LogGateSnapshot();

   const bool req_runtime_scheduler=InpGateRuntimeScheduler;
   const bool req_timer_heavy=InpGateTimerHeavyWork;
   const bool req_tick_heavy=InpGateTickHeavyWork;
   const bool req_menu_engine=InpGateMenuEngine;
   const bool req_chart_ui=InpGateChartUiUpdates;
   const bool req_ui_projection=InpGateUiProjection;

   const bool eff_runtime_scheduler=ISSX_IsGateOn(req_runtime_scheduler,false);
   const bool eff_timer_heavy=ISSX_IsGateOn(req_timer_heavy,false);
   const bool eff_tick_heavy=ISSX_IsGateOn(req_tick_heavy,false);
   const bool eff_menu_engine=ISSX_IsGateOn(req_menu_engine,false);
   const bool eff_chart_ui=ISSX_IsGateOn(req_chart_ui,false);
   const bool eff_ui_projection=ISSX_IsGateOn(req_ui_projection,false);

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
   g_debug.Write("INFO","feature_state","ea2_history","requested="+ISSX_OnOff(InpEnableEA2)+" effective="+ISSX_OnOff(g_ea_enabled[1])+" reason="+(g_ea_enabled[1]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea3_selection","requested="+ISSX_OnOff(InpEnableEA3)+" effective="+ISSX_OnOff(g_ea_enabled[2])+" reason="+(g_ea_enabled[2]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea4_correlation","requested="+ISSX_OnOff(InpEnableEA4)+" effective="+ISSX_OnOff(g_ea_enabled[3])+" reason="+(g_ea_enabled[3]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));
   g_debug.Write("INFO","feature_state","ea5_contracts","requested="+ISSX_OnOff(InpEnableEA5)+" effective="+ISSX_OnOff(g_ea_enabled[4])+" reason="+(g_ea_enabled[4]?"active":(InpIsolationMode?"isolation_forced_off":"requested_off")));

   ISSX_LogGateSnapshot();

   // registry + runtime
   g_registry.SeedBlueprintV170();
   if(ISSX_IsGateOn(InpGateRuntimeScheduler,false))
      g_runtime.Init();
   else
      g_debug.Write("INFO","runtime","init_skipped","disabled_by_gate");

   g_bootstrapped     = false;
   g_runtime_ready    = true;
   g_first_cycle_done = false;
   g_kernel_busy      = false;

   g_menu_prefix="ISSX_MENU_"+ISSX_LongIdPart((long)ChartID())+"_"+ISSX_LongIdPart((long)TimeLocal());
   if(ISSX_IsGateOn(InpGateMenuEngine,false))
     {
      g_menu.Init(g_menu_prefix);
      if(!g_menu.Build(g_ea_enabled))
         g_debug.Write("WARN","ui","menu_build_failed","non-critical UI failure, continuing | "+g_menu.LastError());
      else
         g_debug.Write("INFO","ui","menu_build_ok","prefix="+g_menu_prefix);
     }
   else
      g_debug.Write("INFO","ui","menu_init_skipped","disabled_by_gate");

   if(!EventSetTimer(ISSX_EVENT_TIMER_SEC))
     {
      g_debug.Write("ERROR","timer","event_set_failed","err="+IntegerToString(GetLastError()));
      g_debug.Write("ERROR","lifecycle","oninit_end","result=INIT_FAILED (critical timer failure)");
      return INIT_FAILED;
     }

   g_debug.Write("INFO","timer","event_set_ok","sec="+IntegerToString(ISSX_EVENT_TIMER_SEC));
   g_debug.Write("INFO","lifecycle","oninit_end","result=INIT_SUCCEEDED");
   Comment("ISSX attached - waiting for timer");

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_kernel_busy=false;
   if(ISSX_IsGateOn(InpGateMenuEngine,false))
      g_menu.Destroy();
   g_debug.Write("INFO","lifecycle","ondeinit","reason="+IntegerToString(reason)+" last_checkpoint="+g_last_checkpoint);
   g_debug.Close(reason,"last_checkpoint="+g_last_checkpoint+" file_mode="+g_debug.ActiveMode()+" file_path="+g_debug.ActivePath());
   Comment("");
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
   const bool sampled=ISSX_ShouldSampleTimerDetail();
   const bool gate_runtime_scheduler=ISSX_IsGateOn(InpGateRuntimeScheduler,false);
   const bool gate_timer_heavy=ISSX_IsGateOn(InpGateTimerHeavyWork,false);

   if(sampled || !g_first_cycle_done)
      g_debug.Write("INFO","timer","enter","pulse="+ISSX_Util::ULongToStringX(g_timer_pulse_count));

   if(sampled || !g_first_cycle_done)
      g_debug.Write("INFO","timer","heartbeat",
                    "pulse="+ISSX_Util::ULongToStringX(g_timer_pulse_count)+
                    " first_cycle="+(!g_first_cycle_done?"true":"false")+
                    " minimal_mode="+(InpMinimalDebugMode?"true":"false")+
                    " runtime_scheduler="+(gate_runtime_scheduler?"on":"off")+
                    " heavy_timer_work="+(gate_timer_heavy?"on":"off"));

   bool ok=true;
   long kernel_elapsed_ms=0;

   string runtime_scheduler_status="skipped | gate=off";
   if(gate_runtime_scheduler && !gate_timer_heavy)
      runtime_scheduler_status="skipped | gate=timer_heavy_off";

   string timer_heavy_status="skipped | gate=off";
   if(gate_timer_heavy)
     {
      const ulong kernel_start_us=(ulong)GetMicrosecondCount();
      ok=ISSX_RunKernelCycle();
      kernel_elapsed_ms=(long)(((ulong)GetMicrosecondCount()-kernel_start_us)/1000);
      timer_heavy_status=(ok ? "success" : "failed | reason=kernel_cycle_false");
     }
   else
     {
      if(!g_logged_timer_heavy_skip)
        {
         g_debug.Write("INFO","timer","kernel_skip","disabled_by_gate");
         g_logged_timer_heavy_skip=true;
        }
      if((g_timer_pulse_count%30)==1)
         g_debug.Write("INFO","timer","minimal_heartbeat","pulse="+ISSX_Util::ULongToStringX(g_timer_pulse_count));
     }

   bool ok=true;
   long kernel_elapsed_ms=0;
   if(ISSX_IsGateOn(InpGateTimerHeavyWork,false))
     {
      const long kernel_start_ms=(long)GetTickCount64();
      ok=ISSX_RunKernelCycle();
      kernel_elapsed_ms=(long)GetTickCount64()-kernel_start_ms;
     }
   else
     {
      if(!g_logged_timer_heavy_skip)
        {
         g_debug.Write("INFO","timer","kernel_skip","disabled_by_gate");
         g_logged_timer_heavy_skip=true;
        }
      if((g_timer_pulse_count%30)==1)
         g_debug.Write("INFO","timer","minimal_heartbeat","pulse="+ISSX_Util::ULongToStringX(g_timer_pulse_count));
     }

   if((g_timer_pulse_count%15)==1 || !ok)
      g_debug.Write("INFO","timer","kernel_result",(ok?"ok":"degraded"));

   g_first_cycle_done=true;
   g_kernel_busy=false;

   string status=(ok ? "ISSX running | firm="+g_firm_id : "ISSX degraded | firm="+g_firm_id);
   if(status!=g_last_status_comment || (g_timer_pulse_count-g_last_comment_pulse)>=15)
     {
      Comment(status);
      g_last_status_comment=status;
      g_last_comment_pulse=g_timer_pulse_count;
     }
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
   if(!ISSX_IsGateOn(InpGateTickHeavyWork,false))
     {
      if(!g_logged_tick_heavy_skip)
        {
         g_debug.Write("INFO","tick","heavy_work_skipped","disabled_by_gate");
         g_logged_tick_heavy_skip=true;
        }
      if((tick_count%100)==0)
         g_debug.Write("INFO","tick","heartbeat","count="+IntegerToString((int)tick_count)+" mode=minimal");
      return;
     }

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
   g_debug.Write("INFO","chart_event","event","id="+IntegerToString(id)+" obj="+sparam);
   if(!ISSX_IsGateOn(InpGateChartUiUpdates,false) || !ISSX_IsGateOn(InpGateMenuEngine,false))
     {
      if(!g_logged_chart_ui_skip)
        {
         g_debug.Write("INFO","chart_event","ui_skip","disabled_by_gate");
         g_logged_chart_ui_skip=true;
        }
      return;
     }

   if(id==CHARTEVENT_OBJECT_CLICK)
     {
      if(g_menu.HandleClick(sparam,g_ea_enabled,!InpIsolationMode))
        {
         ISSX_LogFeatureLifecycle("feature_run","chart_ui_updates","success",g_last_run_chart_ui_updates,false);
         g_menu.Build(g_ea_enabled);
         g_debug.Write("INFO","ui","menu_toggle",
                       "ea1="+(g_ea_enabled[0]?"on":"off")+
                       " ea2="+(g_ea_enabled[1]?"on":"off")+
                       " ea3="+(g_ea_enabled[2]?"on":"off")+
                       " ea4="+(g_ea_enabled[3]?"on":"off")+
                       " ea5="+(g_ea_enabled[4]?"on":"off")+" isolation="+(InpIsolationMode?"true":"false"));
        }
      else
        {
         ISSX_LogFeatureLifecycle("feature_run","chart_ui_updates","failed | reason="+g_menu.LastError(),g_last_run_chart_ui_updates,false);
         g_debug.Write("WARN","ui","menu_click_ignored",g_menu.LastError());
        }
     }
  }
