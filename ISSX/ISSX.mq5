#property strict
#property version   "9.999"
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

input group "ISSX Kernel Identity"
input string InpFirmId                       = "default_firm";

input group "Stage 1 - MarketStateCore"
input bool   InpMarketStateCoreEnabled       = true;
input bool   InpMarketStateIncludeCustom     = false;
input int    InpMarketStateMaxSymbols        = 0;

input group "Stage 2 - HistoryStateCore"
input bool   InpHistoryStateCoreEnabled      = true;
input bool   InpHistoryDeepProfileDefault    = true;
input int    InpHistoryMaxSymbolsPerSlice    = 128;

input group "Stage 3 - SelectionCore"
input bool   InpSelectionCoreEnabled         = true;

input group "Stage 4 - IntelligenceCore"
input bool   InpIntelligenceCoreEnabled      = true;

input group "Stage 5 - ConsolidationCore"
input bool   InpConsolidationCoreEnabled     = true;

input group "Projection & Persistence"
input bool   InpProjectionEnabled            = true;
input bool   InpProjectStageStatusRoot       = true;
input bool   InpProjectUniverseSnapshot      = true;
input bool   InpProjectDebugSnapshots        = true;
input bool   InpPersistenceEnabled           = true;
input int    InpPersistenceWriteMinSec       = 1;

input group "Safety, Locking & Forensics"
input int    InpLockStaleAfterSec            = 90;
input bool   InpSafeMode                     = false; // attach + timer only, no kernel
input bool   InpRunFirstCycleInOnInit        = false;
input bool   InpBypassLocks                  = true;
input bool   InpForensicDebugMode            = true;
input bool   InpKeepAliveNoWork              = false;
input int    InpTimerOverrunWarnMs           = 2500;
input int    InpStageFailThreshold           = 3;

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
ulong               g_kernel_busy_since_ms      = 0;
long                g_writer_generation         = 0;
long                g_sequence_seed             = 0;
long                g_last_ea5_export_minute_id = 0;
long                g_last_persist_write_sec     = 0;
int                 g_stage_fail_counts[6];
bool                g_stage_disabled[6];
bool                g_enable_market            = true;
bool                g_enable_history           = true;
bool                g_enable_selection         = true;
bool                g_enable_intelligence      = true;
bool                g_enable_consolidation     = true;
bool                g_enable_projection        = true;
bool                g_enable_persistence       = true;

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



void ISSX_ClampStageActivation()
  {
   g_enable_market=InpMarketStateCoreEnabled;
   g_enable_history=(InpHistoryStateCoreEnabled && g_enable_market);
   g_enable_selection=(InpSelectionCoreEnabled && g_enable_history);
   g_enable_intelligence=(InpIntelligenceCoreEnabled && g_enable_selection);
   g_enable_consolidation=(InpConsolidationCoreEnabled && g_enable_intelligence);
   g_enable_projection=InpProjectionEnabled;
   g_enable_persistence=InpPersistenceEnabled;

   if(InpHistoryStateCoreEnabled && !g_enable_market)
      Print("ISSX: clamp - HistoryStateCore disabled because MarketStateCore is off");
   if(InpSelectionCoreEnabled && !g_enable_history)
      Print("ISSX: clamp - SelectionCore disabled because HistoryStateCore is off");
   if(InpIntelligenceCoreEnabled && !g_enable_selection)
      Print("ISSX: clamp - IntelligenceCore disabled because SelectionCore is off");
   if(InpConsolidationCoreEnabled && !g_enable_intelligence)
      Print("ISSX: clamp - ConsolidationCore disabled because IntelligenceCore is off");
  }

int ISSX_StageIndex(const ISSX_StageId stage_id)
  {
   switch(stage_id)
     {
      case issx_stage_ea1: return 1;
      case issx_stage_ea2: return 2;
      case issx_stage_ea3: return 3;
      case issx_stage_ea4: return 4;
      case issx_stage_ea5: return 5;
     }
   return 0;
  }

bool ISSX_StageEnabled(const ISSX_StageId stage_id)
  {
   const int idx=ISSX_StageIndex(stage_id);
   if(idx<=0 || idx>=6)
      return true;
   return (!g_stage_disabled[idx]);
  }

void ISSX_RecordStageResult(const ISSX_StageId stage_id,const bool ok)
  {
   const int idx=ISSX_StageIndex(stage_id);
   if(idx<=0 || idx>=6)
      return;

   if(ok)
     {
      g_stage_fail_counts[idx]=0;
      return;
     }

   g_stage_fail_counts[idx]++;
   if(g_stage_fail_counts[idx]>=InpStageFailThreshold)
     {
      g_stage_disabled[idx]=true;
      Print("ISSX: emergency degrade disabling stage=",ISSX_StageIdToString(stage_id)," fail_count=",g_stage_fail_counts[idx]);
      ISSX_DebugEngine::MarkError("stage_disabled_"+ISSX_StageIdToString(stage_id),0);
     }
  }

bool ISSX_ShouldPersistNow()
  {
   if(!g_enable_persistence)
      return false;

   const long now_sec=(long)TimeLocal();
   if(g_last_persist_write_sec<=0)
      return true;

   return ((now_sec-g_last_persist_write_sec) >= InpPersistenceWriteMinSec);
  }

bool ISSX_LockAcquireOrBypass()
  {
   if(InpBypassLocks)
     {
      Print("ISSX: lock bypass enabled");
      return true;
     }

   if(!ISSX_LockHelper::Acquire(g_firm_id,g_boot_id,g_instance_guid,ISSX_WrapperTerminalIdentity(),InpLockStaleAfterSec,g_lock))
     {
      Print("ISSX: lock acquire failed");
      ISSX_DebugEngine::MarkError("lock_acquire_failed",GetLastError());
      return false;
     }

   return true;
  }

void ISSX_LockHeartbeatIfNeeded()
  {
   if(InpBypassLocks)
      return;

   if(!ISSX_LockHelper::Heartbeat(g_firm_id,g_lock))
     {
      Print("ISSX: lock heartbeat failed");
      ISSX_DebugEngine::MarkError("lock_heartbeat_failed",GetLastError());
     }
  }

int ISSX_CountEA2RankingReady(const ISSX_EA2_State &state)
  {
   int ready=0;
   const int n=ArraySize(state.symbols);
   for(int i=0;i<n;i++)
     {
      if(state.symbols[i].history_ready_for_ranking)
         ready++;
     }
   return ready;
  }

bool ISSX_PersistStageJson(const ISSX_StageId stage_id,
                           ISSX_StageHeader &header,
                           ISSX_Manifest &manifest,
                           const string payload_json)
  {
   ISSX_BREADCRUMB_STAGE_ENTER("persist_"+ISSX_StageIdToString(stage_id));

   if(!ISSX_ShouldPersistNow())
     {
      Print("ISSX: persist throttled stage=",ISSX_StageIdToString(stage_id));
      return true;
     }

   if(StringLen(payload_json)<=2)
     {
      Print("ISSX: persist skipped, payload too small stage=",ISSX_StageIdToString(stage_id));
      return false;
     }

   ISSX_BREADCRUMB_FILE("candidate_write_"+ISSX_StageIdToString(stage_id));
   if(!ISSX_SnapshotFlow::WriteCandidate(g_firm_id,stage_id,header,payload_json,manifest))
     {
      Print("ISSX: WriteCandidate failed stage=",ISSX_StageIdToString(stage_id));
      ISSX_BREADCRUMB_ERROR("write_candidate_failed");
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
   g_last_persist_write_sec=(long)TimeLocal();
   ISSX_BREADCRUMB_STAGE_DONE("persist_"+ISSX_StageIdToString(stage_id));
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


bool ISSX_HistoryPreflightSymbols(const string &symbols[])
  {
   const int n=ArraySize(symbols);
   if(n<=0)
      return false;

   int usable=0;
   for(int i=0;i<n;i++)
     {
      const string sym=symbols[i];
      if(StringLen(sym)<=0)
         continue;

      SymbolSelect(sym,true);
      const bool selected=(bool)SymbolInfoInteger(sym,SYMBOL_SELECT);
      const long bars=iBars(sym,PERIOD_M1);
      if(selected && bars>0)
         usable++;
     }

   Print("ISSX: history preflight usable_symbols=",usable," total=",n);
   return (usable>0);
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

   if(g_enable_projection && InpProjectDebugSnapshots)
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

   if(g_enable_projection && InpProjectDebugSnapshots)
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

   if(g_enable_projection && InpProjectDebugSnapshots)
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

   if(g_enable_projection && InpProjectDebugSnapshots)
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

   if(g_enable_persistence)
     {
      ISSX_PersistStageJson(issx_stage_ea5,g_ea5.header,g_ea5.manifest,export_json);
      ISSX_FileIO::WriteText(ISSX_PersistencePath::RootExport(g_firm_id),export_json);
     }

   if(g_enable_projection && InpProjectDebugSnapshots)
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea5,debug_json);
  }

bool ISSX_RunKernelCycle()
  {
   Print("ISSX: KERNEL ENTER");
   g_runtime.OnPulse();

   string stage_json="";
   string broker_dump_json="";
   string debug_json="";

   if(!g_enable_market)
     {
      Print("ISSX: MarketStateCore disabled, kernel in keepalive mode");
      return true;
     }

   if(!g_bootstrapped)
     {
      Print("ISSX: EA1 StageBoot");
      g_ea1.Reset();
      ISSX_MarketEngine::StageBoot(g_ea1);
     }

   Print("ISSX: EA1 StageSlice ENTER");
   if(!ISSX_MarketEngine::StageSlice(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,InpMarketStateMaxSymbols))
     {
      Print("ISSX: EA1 StageSlice FAILED");
      ISSX_RecordStageResult(issx_stage_ea1,false);
      return false;
     }

   ISSX_RecordStageResult(issx_stage_ea1,true);
   Print("ISSX: EA1 StageSlice OK symbols=",ArraySize(g_ea1.symbols));

   if(ArraySize(g_ea1.symbols)<=0)
     {
      Print("ISSX: EA1 produced zero symbols, skipping downstream stages");
      g_bootstrapped=true;
      return true;
     }

   Print("ISSX: EA1 StagePublish");
   ISSX_MarketEngine::StagePublish(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,stage_json,debug_json);
   ISSX_MarketEngine::BuildUniverseDump(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,broker_dump_json);
   ISSX_ProjectEA1(stage_json,broker_dump_json,debug_json);

   string ea1_symbols[];
   const int ea1_count=ISSX_CopyEA1Symbols(ea1_symbols);
   Print("ISSX: EA1 symbol copy count=",ea1_count);

   if(ea1_count<=0)
     {
      Print("ISSX: no EA1 symbols copied, ending cycle safely");
      g_bootstrapped=true;
      return true;
     }

   if(g_enable_history && ISSX_StageEnabled(issx_stage_ea2) && !ISSX_HistoryPreflightSymbols(ea1_symbols))
     {
      Print("ISSX: history preflight failed, skipping downstream stages");
      ISSX_RecordStageResult(issx_stage_ea2,false);
      return true;
     }

   if(g_enable_history && ISSX_StageEnabled(issx_stage_ea2) && !g_bootstrapped)
     {
      ISSX_BREADCRUMB_STAGE_ENTER("ea2_boot");
      Print("ISSX: EA2 StageBoot");
      ISSX_HistoryEngine::StageBoot(g_ea2,ea1_symbols,InpHistoryDeepProfileDefault);
      ISSX_BREADCRUMB_STAGE_DONE("ea2_boot");
     }

   if(g_enable_history && ISSX_StageEnabled(issx_stage_ea2))
     {
      ISSX_BREADCRUMB_STAGE_ENTER("ea2_slice");
      Print("ISSX: EA2 StageSlice");
      if(!ISSX_HistoryEngine::StageSlice(g_ea2,ea1_symbols,InpHistoryDeepProfileDefault,InpHistoryMaxSymbolsPerSlice))
     {
      Print("ISSX: EA2 StageSlice degraded");
      ISSX_RecordStageResult(issx_stage_ea2,false);
     }
      else
     {
      ISSX_RecordStageResult(issx_stage_ea2,true);
     }
      ISSX_BREADCRUMB_STAGE_DONE("ea2_slice");
      stage_json=ISSX_HistoryEngine::StagePublish(g_ea2);
      debug_json=ISSX_HistoryEngine::BuildDebugSnapshot(g_ea2);
      ISSX_ProjectEA2(stage_json,debug_json);
     }

   const int ea2_ready_count=ISSX_CountEA2RankingReady(g_ea2);
   if(!g_enable_history || !ISSX_StageEnabled(issx_stage_ea2) || ArraySize(g_ea2.symbols)<=0 || ea2_ready_count<=0)
     {
      Print("ISSX: EA2 insufficient history readiness; skipping EA3-EA5 this cycle symbols=",ArraySize(g_ea2.symbols)," ready=",ea2_ready_count);
      g_bootstrapped=true;
      return true;
     }

   if(g_enable_selection && ISSX_StageEnabled(issx_stage_ea3))
     {
      if(!g_bootstrapped)
        {
         Print("ISSX: EA3 StageBoot");
         ISSX_SelectionEngine::StageBoot(g_firm_id,g_ea1,g_ea2,g_ea3);
        }

      ISSX_BREADCRUMB_STAGE_ENTER("ea3_slice");
      Print("ISSX: EA3 StageSlice");
      ISSX_SelectionEngine::StageSlice(g_firm_id,g_ea1,g_ea2,g_ea3);
      ISSX_BREADCRUMB_STAGE_DONE("ea3_slice");
      string ea3_debug="";
      ISSX_SelectionEngine::StagePublish(g_ea3,stage_json,ea3_debug);
      ISSX_ProjectEA3(stage_json,ea3_debug);
      ISSX_RecordStageResult(issx_stage_ea3,true);
     }

   const int frontier_count=(g_enable_selection ? ArraySize(g_ea3.frontier) : 0);
   if(frontier_count<=0)
     {
      Print("ISSX: EA3 frontier empty; skipping EA4 this cycle");
      ArrayResize(g_ea4.symbols,0);
      ArrayResize(g_ea4.pair_cache,0);
     }
   else
     {
      if(g_enable_intelligence && ISSX_StageEnabled(issx_stage_ea4))
        {
         if(!g_bootstrapped)
           {
            Print("ISSX: EA4 StageBoot");
            ISSX_CorrelationEngine::StageBoot(g_ea4,g_firm_id);
           }

         ISSX_BREADCRUMB_STAGE_ENTER("ea4_slice");
         Print("ISSX: EA4 StageSlice");
         ISSX_CorrelationEngine::StageSlice(g_ea4,g_firm_id,g_ea1,g_ea3,ISSX_CurrentKernelMinuteId());
         ISSX_BREADCRUMB_STAGE_DONE("ea4_slice");
        }
     }
   string ea4_debug="";
   if(g_enable_intelligence && ISSX_StageEnabled(issx_stage_ea4))
     {
      ISSX_CorrelationEngine::StagePublish(g_ea4,stage_json,ea4_debug);
      ISSX_ProjectEA4(stage_json,ea4_debug);
      ISSX_RecordStageResult(issx_stage_ea4,true);
     }
   else
     {
      ISSX_RecordStageResult(issx_stage_ea4,false);
     }

   ISSX_EA4_OptionalIntelligenceExport ea4_optional_intel[];
   ISSX_EA5_OptionalIntelligence optional_intel[];
   ArrayResize(ea4_optional_intel,0);
   ArrayResize(optional_intel,0);

   ISSX_CorrelationEngine::ExportOptionalIntelligence(g_ea4,ea4_optional_intel);
   ISSX_ConvertEA4OptionalIntelligence(ea4_optional_intel,optional_intel);

   if(g_enable_consolidation && ISSX_StageEnabled(issx_stage_ea5))
     {
      ISSX_BREADCRUMB_STAGE_ENTER("ea5_build");
      Print("ISSX: EA5 BuildFromInputs");
      ISSX_Contracts::BuildFromInputs(g_ea5,g_ea1,g_ea2,g_ea3,optional_intel);
      ISSX_BREADCRUMB_STAGE_DONE("ea5_build");
     }

   const long current_minute_id=ISSX_CurrentKernelMinuteId();
   const bool ea5_export_due=(!g_bootstrapped || ISSX_IsEA5ExportDue(current_minute_id));

   if(g_enable_consolidation && ISSX_StageEnabled(issx_stage_ea5) && ea5_export_due)
     {
      Print("ISSX: EA5 export due");
      string export_json=ISSX_Contracts::ToStageJson(g_ea5,g_registry.fields,g_registry.enums);
      string ea5_debug=ISSX_Contracts::ToDebugJson(g_ea5);
      ISSX_ProjectEA5(export_json,ea5_debug);
      g_last_ea5_export_minute_id=current_minute_id;
      ISSX_RecordStageResult(issx_stage_ea5,true);
     }
   else if(g_enable_consolidation && ISSX_StageEnabled(issx_stage_ea5))
     {
      ISSX_RecordStageResult(issx_stage_ea5,false);
     }

   Print("ISSX: UI aggregate");
   ISSX_DebugAggregate agg=ISSX_UI_Test::BuildAggregate(g_firm_id,g_runtime.State(),g_ea1,g_ea2,g_ea3,g_ea4,g_ea5);
   if(g_enable_projection)
     {
      ISSX_UI_Test::ProjectDebugRoot(g_firm_id,agg);

      if(InpProjectStageStatusRoot)
         ISSX_UI_Test::ProjectStageStatusRoot(g_firm_id,agg);
      if(InpProjectUniverseSnapshot)
         ISSX_UI_Test::ProjectUniverseSnapshotRoot(g_firm_id,g_runtime.State());
     }

   if(g_enable_projection && InpProjectDebugSnapshots)
     {
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea1,ISSX_UI_Test::BuildStageSnapshotEA1(g_ea1));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea2,ISSX_UI_Test::BuildStageSnapshotEA2(g_ea2));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea3,ISSX_UI_Test::BuildStageSnapshotEA3(g_ea3));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea4,ISSX_UI_Test::BuildStageSnapshotEA4(g_ea4));
      ISSX_UI_Test::ProjectStageSnapshot(g_firm_id,issx_stage_ea5,ISSX_UI_Test::BuildStageSnapshotEA5(g_ea5));
     }

   Comment(ISSX_UI_Test::BuildHudText(agg));
   g_bootstrapped=true;
   Print("ISSX: KERNEL EXIT OK");
   return true;
  }

int OnInit()
  {
   Print("ISSX: INIT ENTER");

   MathSrand((uint)TimeLocal());

   g_boot_id        = ISSX_WrapperBootId();
   g_instance_guid  = ISSX_WrapperInstanceGuid();
   g_writer_nonce   = ISSX_WrapperNonce();
   g_firm_id        = ISSX_ResolveFirmId();

   Print("ISSX: boot_id=",g_boot_id);
   Print("ISSX: instance_guid=",g_instance_guid);
   Print("ISSX: writer_nonce=",g_writer_nonce);
   Print("ISSX: firm_id=",g_firm_id);

   ISSX_ClampStageActivation();

   // registry + runtime
   if(InpForensicDebugMode)
      ISSX_DebugEngine::Init(g_boot_id,g_instance_guid);
   Print("ISSX: module tags ",ISSX_CoreDiagTag(),"|",ISSX_RegistryDiagTag(),"|",ISSX_RuntimeDiagTag(),"|",ISSX_PersistenceDiagTag(),"|",ISSX_MarketDiagTag(),"|",ISSX_HistoryDiagTag(),"|",ISSX_SelectionDiagTag(),"|",ISSX_CorrelationDiagTag(),"|",ISSX_ContractsDiagTag(),"|",ISSX_UITestDiagTag());
   g_registry.SeedBlueprintV172();

   ISSX_ValidationResult vr=g_registry.Validate();
   if(!vr.ok)
     {
      Print("ISSX: registry validate failed owner=",vr.owner," code=",vr.code," msg=",vr.message);
      ISSX_BREADCRUMB_ERROR("registry_validate_failed");
      g_runtime_ready=false;
      return INIT_FAILED;
     }

   g_runtime.Init();

   g_bootstrapped     = false;
   g_runtime_ready    = true;
   g_first_cycle_done = false;
   g_kernel_busy      = false;
   g_kernel_busy_since_ms=0;
   g_last_persist_write_sec=0;
   for(int si=0;si<6;si++)
     {
      g_stage_fail_counts[si]=0;
      g_stage_disabled[si]=false;
     }

   if(!ISSX_LockAcquireOrBypass())
     {
      g_runtime_ready=false;
      return INIT_FAILED;
     }

   if(!EventSetTimer(ISSX_EVENT_TIMER_SEC))
     {
      Print("ISSX: EventSetTimer failed err=",GetLastError());
      ISSX_BREADCRUMB_ERROR("event_set_timer_failed");
      g_runtime_ready=false;
      return INIT_FAILED;
     }

   if(InpForensicDebugMode)
      ISSX_DebugEngine::SetTimerActive(true);
   if(InpRunFirstCycleInOnInit && !InpSafeMode && !InpKeepAliveNoWork)
     {
      Print("ISSX: first-cycle requested in OnInit");
      bool init_cycle_ok=ISSX_RunKernelCycle();
      Print("ISSX: first-cycle in OnInit result=",init_cycle_ok);
     }

   Print("ISSX: INIT EXIT");
   Comment("ISSX attached - waiting for timer");

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(InpForensicDebugMode)
      ISSX_DebugEngine::SetTimerActive(false);
   g_kernel_busy=false;
   g_kernel_busy_since_ms=0;

   if(!InpBypassLocks)
      ISSX_LockHelper::Release(g_firm_id,g_lock);

   if(InpForensicDebugMode)
      ISSX_DebugEngine::LogDeinit(reason);
   Print("ISSX: DEINIT reason=",reason);
   Comment("");
  }

void OnTimer()
  {
   if(!g_runtime_ready)
     {
      Print("ISSX: TIMER skipped runtime not ready");
      return;
     }

   if(g_kernel_busy)
     {
      const ulong now_ms=GetTickCount64();
      const ulong busy_for=(g_kernel_busy_since_ms>0 ? (now_ms-g_kernel_busy_since_ms) : 0);
      if(busy_for>(ulong)(ISSX_EVENT_TIMER_SEC*3000))
        {
         Print("ISSX: TIMER busy watchdog reset busy_for_ms=",(long)busy_for);
         g_kernel_busy=false;
         g_kernel_busy_since_ms=0;
        }
      else
        {
         Print("ISSX: TIMER skipped kernel busy");
         return;
        }
     }

   g_kernel_busy=true;
   g_kernel_busy_since_ms=GetTickCount64();
   if(InpForensicDebugMode)
     {
      ISSX_DebugEngine::SetKernelBusy(true);
      ISSX_DebugEngine::BeginCycle();
     }

   Print("ISSX: TIMER START first_cycle=",(!g_first_cycle_done));

   bool ok=true;

   if(InpKeepAliveNoWork || InpSafeMode)
     {
      Print("ISSX: keepalive/safe-mode timer heartbeat only");
      ok=true;
     }
   else
     {
      ok=ISSX_RunKernelCycle();
     }

   if(InpForensicDebugMode)
      ISSX_DebugEngine::EndCycle();
   ISSX_LockHeartbeatIfNeeded();

   const long cycle_elapsed=(long)(GetTickCount64()-g_kernel_busy_since_ms);
   if(cycle_elapsed>InpTimerOverrunWarnMs)
      Print("ISSX: TIMER overrun cycle_elapsed_ms=",cycle_elapsed," warn_ms=",InpTimerOverrunWarnMs);

   Print("ISSX: TIMER kernel result=",ok);

   g_first_cycle_done=true;
   g_kernel_busy=false;
   g_kernel_busy_since_ms=0;
   if(InpForensicDebugMode)
      ISSX_DebugEngine::SetKernelBusy(false);

   if(ok)
      Comment("ISSX running | firm="+g_firm_id);
   else
      Comment("ISSX degraded | firm="+g_firm_id);
  }

void OnTick()
  {
   // timer-driven wrapper by design
  }
