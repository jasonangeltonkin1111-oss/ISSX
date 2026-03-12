
#property strict
#property version   "1.7.0"
#property description "ISSX single-wrapper consolidated kernel (v1.7.0)"

#include "issx_core.mqh"
#include "issx_registry.mqh"
#include "issx_runtime.mqh"
#include "issx_persistence.mqh"
#include "issx_market_engine.mqh"
#include "issx_history_engine.mqh"
#include "issx_selection_engine.mqh"
#include "issx_correlation_engine.mqh"
#include "issx_contracts.mqh"
#include "issx_ui.mqh"

input string InpFirmId                  = "default_firm";
input bool   InpIncludeCustomSymbols    = false;
input int    InpEA1MaxSymbols           = 0;
input bool   InpEA2DeepProfileDefault   = true;
input int    InpEA2MaxSymbolsPerSlice   = 128;
input bool   InpProjectStageStatusRoot  = true;
input bool   InpProjectUniverseSnapshot = true;
input bool   InpProjectDebugSnapshots   = true;
input int    InpLockStaleAfterSec       = 90;

ISSX_RegistryBundle g_registry;
ISSX_StageRuntime   g_runtime;

ISSX_EA1_State      g_ea1;
ISSX_EA2_State      g_ea2;
ISSX_EA3_State      g_ea3;
ISSX_EA4_State      g_ea4;
ISSX_EA5_State      g_ea5;

ISSX_LockLease      g_lock;
string              g_boot_id = "";
string              g_instance_guid = "";
string              g_writer_nonce = "";
bool                g_bootstrapped = false;
long                g_writer_generation = 0;
long                g_sequence_seed = 0;

string ISSX_WrapperBootId()
  {
   return "boot_"+IntegerToString((int)TimeLocal())+"_"+IntegerToString((int)ChartID());
  }

string ISSX_WrapperInstanceGuid()
  {
   return "inst_"+IntegerToString((int)GetTickCount64())+"_"+IntegerToString((int)MathRand());
  }

string ISSX_WrapperNonce()
  {
   return "nonce_"+IntegerToString((int)GetTickCount64())+"_"+IntegerToString((int)MathRand());
  }

string ISSX_WrapperTerminalIdentity()
  {
   string company=TerminalInfoString(TERMINAL_COMPANY);
   string name=TerminalInfoString(TERMINAL_NAME);
   string path=TerminalInfoString(TERMINAL_PATH);
   return company+"|"+name+"|"+path;
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
   header.firm_id=InpFirmId;
   header.minute_id=minute_id;
   header.sequence_no=++g_sequence_seed;
   header.writer_boot_id=g_boot_id;
   header.writer_nonce=g_writer_nonce;
   header.writer_generation=++g_writer_generation;
   header.trio_generation_id=IntegerToString((int)header.writer_generation)+"_"+IntegerToString((int)header.sequence_no);
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
   manifest.firm_id=InpFirmId;
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
      return false;

   if(!ISSX_SnapshotFlow::WriteCandidate(InpFirmId,stage_id,header,payload_json,manifest))
      return false;

   ISSX_StageHeader verify_header;
   ISSX_Manifest verify_manifest;
   string verify_payload="";
   verify_header.Reset();
   verify_manifest.Reset();
   if(!ISSX_SnapshotFlow::LoadCandidate(InpFirmId,stage_id,verify_header,verify_manifest,verify_payload))
      return false;

   if(!ISSX_Coherence::CandidateTrioCoherent(verify_header,verify_manifest,verify_payload))
      return false;

   ISSX_ProjectionOutcome outcome;
   outcome.Reset();
   if(!ISSX_SnapshotFlow::PromoteCandidate(InpFirmId,stage_id,manifest,outcome))
      return false;

   ISSX_SnapshotFlow::PromoteLastGoodIfEligible(InpFirmId,stage_id,manifest);
   return true;
  }

int ISSX_CopyEA1Symbols(string &symbols[])
  {
   ArrayResize(symbols,0);
   const int n=ArraySize(g_ea1.symbols);
   if(n<=0)
      return 0;

   ArrayResize(symbols,n);
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
   ISSX_PublishabilityState pub=issx_publishability_not_ready;
   if(g_ea1.stage_publishability_state=="publishable") pub=issx_publishability_publishable;
   else if(g_ea1.stage_publishability_state=="degraded") pub=issx_publishability_degraded;
   else if(g_ea1.stage_publishability_state=="blocked") pub=issx_publishability_blocked;
   else if(g_ea1.stage_publishability_state=="booting") pub=issx_publishability_booting;
   ISSX_SeedManifest(manifest,header,issx_content_full,issx_publish_scheduled,pub,(g_ea1.stage_minimum_ready_flag=="true"),(g_ea1.publishable?1:0),(g_ea1.degraded_flag?1:0));
   manifest.taxonomy_hash=g_ea1.taxonomy_hash;
   manifest.comparator_registry_hash=g_ea1.comparator_registry_hash;
   ISSX_PersistStageJson(issx_stage_ea1,header,manifest,stage_json);
   ISSX_BrokerUniverseDump::RotateCurrentToPrevious(InpFirmId);
   ISSX_BrokerUniverseDump::WriteCurrent(InpFirmId,broker_dump_json,manifest,true);
   if(InpProjectDebugSnapshots)
      ISSX_UI_Test::ProjectStageSnapshot(InpFirmId,issx_stage_ea1,debug_snapshot_json);
  }

void ISSX_ProjectEA2(const string stage_json,
                     const string debug_snapshot_json)
  {
   g_ea2.header.writer_boot_id=g_boot_id;
   g_ea2.header.writer_nonce=g_writer_nonce;
   if(g_ea2.header.writer_generation<=0) g_ea2.header.writer_generation=++g_writer_generation;
   if(g_ea2.header.sequence_no<=0) g_ea2.header.sequence_no=++g_sequence_seed;
   if(g_ea2.header.trio_generation_id=="") g_ea2.header.trio_generation_id=IntegerToString((int)g_ea2.header.writer_generation)+"_"+IntegerToString((int)g_ea2.header.sequence_no);
   g_ea2.header.policy_fingerprint=g_registry.SchemaFingerprintHex();
   g_ea2.manifest.taxonomy_hash=g_ea1.taxonomy_hash;
   g_ea2.manifest.comparator_registry_hash=g_ea1.comparator_registry_hash;
   ISSX_PersistStageJson(issx_stage_ea2,g_ea2.header,g_ea2.manifest,stage_json);
   if(InpProjectDebugSnapshots)
      ISSX_UI_Test::ProjectStageSnapshot(InpFirmId,issx_stage_ea2,debug_snapshot_json);
  }

void ISSX_ProjectEA3(const string stage_json,
                     const string debug_snapshot_json)
  {
   g_ea3.header.writer_boot_id=g_boot_id;
   g_ea3.header.writer_nonce=g_writer_nonce;
   if(g_ea3.header.writer_generation<=0) g_ea3.header.writer_generation=++g_writer_generation;
   if(g_ea3.header.sequence_no<=0) g_ea3.header.sequence_no=++g_sequence_seed;
   if(g_ea3.header.trio_generation_id=="") g_ea3.header.trio_generation_id=IntegerToString((int)g_ea3.header.writer_generation)+"_"+IntegerToString((int)g_ea3.header.sequence_no);
   g_ea3.header.policy_fingerprint=g_registry.SchemaFingerprintHex();
   ISSX_PersistStageJson(issx_stage_ea3,g_ea3.header,g_ea3.manifest,stage_json);
   if(InpProjectDebugSnapshots)
      ISSX_UI_Test::ProjectStageSnapshot(InpFirmId,issx_stage_ea3,debug_snapshot_json);
  }

void ISSX_ProjectEA4(const string stage_json,
                     const string debug_snapshot_json)
  {
   g_ea4.header.writer_boot_id=g_boot_id;
   g_ea4.header.writer_nonce=g_writer_nonce;
   if(g_ea4.header.writer_generation<=0) g_ea4.header.writer_generation=++g_writer_generation;
   if(g_ea4.header.sequence_no<=0) g_ea4.header.sequence_no=++g_sequence_seed;
   if(g_ea4.header.trio_generation_id=="") g_ea4.header.trio_generation_id=IntegerToString((int)g_ea4.header.writer_generation)+"_"+IntegerToString((int)g_ea4.header.sequence_no);
   g_ea4.header.policy_fingerprint=g_registry.SchemaFingerprintHex();
   ISSX_PersistStageJson(issx_stage_ea4,g_ea4.header,g_ea4.manifest,stage_json);
   if(InpProjectDebugSnapshots)
      ISSX_UI_Test::ProjectStageSnapshot(InpFirmId,issx_stage_ea4,debug_snapshot_json);
  }

void ISSX_ProjectEA5(const string export_json,
                     const string debug_json)
  {
   g_ea5.header.writer_boot_id=g_boot_id;
   g_ea5.header.writer_nonce=g_writer_nonce;
   if(g_ea5.header.writer_generation<=0) g_ea5.header.writer_generation=++g_writer_generation;
   if(g_ea5.header.sequence_no<=0) g_ea5.header.sequence_no=++g_sequence_seed;
   if(g_ea5.header.trio_generation_id=="") g_ea5.header.trio_generation_id=IntegerToString((int)g_ea5.header.writer_generation)+"_"+IntegerToString((int)g_ea5.header.sequence_no);
   g_ea5.header.policy_fingerprint=g_registry.SchemaFingerprintHex();
   ISSX_PersistStageJson(issx_stage_ea5,g_ea5.header,g_ea5.manifest,export_json);
   ISSX_FileIO::WriteText(ISSX_PersistencePath::RootExport(InpFirmId),export_json);
   if(InpProjectDebugSnapshots)
      ISSX_UI_Test::ProjectStageSnapshot(InpFirmId,issx_stage_ea5,debug_json);
  }

bool ISSX_RunKernelCycle()
  {
   g_runtime.OnPulse();
   ISSX_LockHelper::Heartbeat(InpFirmId,g_lock);

   string stage_json="";
   string broker_dump_json="";
   string debug_json="";

   if(!g_bootstrapped)
     {
      g_ea1.Reset();
      ISSX_MarketEngine::StageBoot(g_ea1);
     }

   if(!ISSX_MarketEngine::StageSlice(g_ea1,InpIncludeCustomSymbols,InpEA1MaxSymbols))
      return false;

   ISSX_MarketEngine::StagePublish(g_ea1,InpFirmId,g_boot_id,g_writer_nonce,stage_json,broker_dump_json,debug_json);
   ISSX_ProjectEA1(stage_json,broker_dump_json,debug_json);

   string ea1_symbols[];
   ISSX_CopyEA1Symbols(ea1_symbols);

   if(!g_bootstrapped)
      ISSX_HistoryEngine::StageBoot(g_ea2,ea1_symbols,InpEA2DeepProfileDefault);
   ISSX_HistoryEngine::StageSlice(g_ea2,ea1_symbols,InpEA2DeepProfileDefault,InpEA2MaxSymbolsPerSlice);
   stage_json=ISSX_HistoryEngine::StagePublish(g_ea2);
   debug_json=ISSX_HistoryEngine::BuildDebugSnapshot(g_ea2);
   ISSX_ProjectEA2(stage_json,debug_json);

   if(!g_bootstrapped)
      ISSX_SelectionEngine::StageBoot(InpFirmId,g_ea1,g_ea2,g_ea3);
   ISSX_SelectionEngine::StageSlice(InpFirmId,g_ea1,g_ea2,g_ea3);
   string ea3_debug="";
   ISSX_SelectionEngine::StagePublish(g_ea3,stage_json,ea3_debug);
   ISSX_ProjectEA3(stage_json,ea3_debug);

   if(!g_bootstrapped)
      ISSX_CorrelationEngine::StageBoot(g_ea4,InpFirmId);
   ISSX_CorrelationEngine::StageSlice(g_ea4,InpFirmId,g_ea1,g_ea2,g_ea3,(long)g_runtime.State().kernel.kernel_minute_id);
   string ea4_debug="";
   ISSX_CorrelationEngine::StagePublish(g_ea4,stage_json,ea4_debug);
   ISSX_ProjectEA4(stage_json,ea4_debug);

   ISSX_EA5_OptionalIntelligence optional_intel[];
   ArrayResize(optional_intel,0);
   ISSX_CorrelationEngine::ExportOptionalIntelligence(g_ea4,optional_intel);
   ISSX_Contracts::BuildFromInputs(g_ea5,g_ea1,g_ea2,g_ea3,optional_intel);
   string export_json=ISSX_Contracts::ToStageJson(g_ea5,g_registry.fields,g_registry.enums);
   string ea5_debug=ISSX_Contracts::ToDebugJson(g_ea5);
   ISSX_ProjectEA5(export_json,ea5_debug);

   ISSX_DebugAggregate agg=ISSX_UI_Test::BuildAggregate(InpFirmId,g_runtime.State(),g_ea1,g_ea2,g_ea3,g_ea4,g_ea5);
   ISSX_UI_Test::ProjectDebugRoot(InpFirmId,agg);
   if(InpProjectStageStatusRoot)
      ISSX_UI_Test::ProjectStageStatusRoot(InpFirmId,agg);
   if(InpProjectUniverseSnapshot)
      ISSX_UI_Test::ProjectUniverseSnapshotRoot(InpFirmId,g_runtime.State());
   if(InpProjectDebugSnapshots)
     {
      ISSX_UI_Test::ProjectStageSnapshot(InpFirmId,issx_stage_ea1,ISSX_UI_Test::BuildStageSnapshotEA1(g_ea1));
      ISSX_UI_Test::ProjectStageSnapshot(InpFirmId,issx_stage_ea2,ISSX_UI_Test::BuildStageSnapshotEA2(g_ea2));
      ISSX_UI_Test::ProjectStageSnapshot(InpFirmId,issx_stage_ea3,ISSX_UI_Test::BuildStageSnapshotEA3(g_ea3));
      ISSX_UI_Test::ProjectStageSnapshot(InpFirmId,issx_stage_ea4,ISSX_UI_Test::BuildStageSnapshotEA4(g_ea4));
      ISSX_UI_Test::ProjectStageSnapshot(InpFirmId,issx_stage_ea5,ISSX_UI_Test::BuildStageSnapshotEA5(g_ea5));
     }

   Comment(ISSX_UI_Test::BuildHudText(agg));
   g_bootstrapped=true;
   return true;
  }

int OnInit()
  {
   MathSrand((uint)TimeLocal());
   g_boot_id=ISSX_WrapperBootId();
   g_instance_guid=ISSX_WrapperInstanceGuid();
   g_writer_nonce=ISSX_WrapperNonce();
   g_registry.SeedBlueprintV170();
   g_runtime.Init();

   if(!ISSX_LockHelper::Acquire(InpFirmId,g_boot_id,g_instance_guid,ISSX_WrapperTerminalIdentity(),InpLockStaleAfterSec,g_lock))
     {
      Print("ISSX: failed to acquire lock for firm ",InpFirmId);
      return INIT_FAILED;
     }

   EventSetTimer(1);
   if(!ISSX_RunKernelCycle())
      Print("ISSX: initial kernel cycle completed with degradation/failure");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ISSX_LockHelper::Release(InpFirmId,g_lock);
   Comment("");
  }

void OnTimer()
  {
   if(!ISSX_RunKernelCycle())
      Print("ISSX: timer cycle degraded for firm ",InpFirmId);
  }

void OnTick()
  {
   // Thin wrapper by design: timer-driven only.
  }
