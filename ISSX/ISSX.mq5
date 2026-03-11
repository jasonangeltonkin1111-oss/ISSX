#property strict
#property version   "9.999"
#property description "ISSX single-wrapper consolidated kernel (safe attach wrapper)"

#include <Trade/Trade.mqh>

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

input string InpFirmId                  = "default_firm";
input bool   InpIncludeCustomSymbols    = false;
input int    InpEA1MaxSymbols           = 0;
input bool   InpEA2DeepProfileDefault   = true;
input int    InpEA2MaxSymbolsPerSlice   = 128;
input bool   InpProjectStageStatusRoot  = true;
input bool   InpProjectUniverseSnapshot = true;
input bool   InpProjectDebugSnapshots   = true;
input int    InpLockStaleAfterSec       = 90;

// debug / safety controls
input bool   InpSafeMode                = false; // true = attach + timer only, no kernel
input bool   InpRunFirstCycleInOnInit   = false; // keep false
input bool   InpBypassLocks             = true;  // keep true until lock logic is fixed
input bool   InpEnableEA1               = true;
input bool   InpEnableEA2               = false;
input bool   InpEnableEA3               = false;
input bool   InpEnableEA4               = false;
input bool   InpEnableEA5               = false;
input bool   InpEnableChartMenu         = true;
input bool   InpEnableDebugReport       = true;
input int    InpHeartbeatTickModulo     = 30;
input long   InpMagicNumber             = 430157245;

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

CTrade              g_trade;

bool                g_module_enabled[5]={true,false,false,false,false};
bool                g_module_locked[5]={false,true,true,true,true};
string              g_module_name[5]={"EA1","EA2","EA3","EA4","EA5"};

string              g_ui_prefix                = "";
string              g_ui_bg                    = "";
string              g_ui_title                 = "";
string              g_ui_btns[5];
string              g_ui_subs[5];
bool                g_ui_ready                 = false;

string              g_debug_dir_primary        = "..\\Include\\ISSX\\ISSX\\Debug Reports\\";
string              g_debug_dir_fallback       = "ISSX\\Debug Reports\\";
string              g_debug_dir_active         = "";
string              g_debug_file_rel           = "";
bool                g_debug_ready              = false;
long                g_tick_count               = 0;

void ISSX_Log(const string msg,const bool force_print=true)
  {
   if(force_print)
      Print(msg);

   if(!InpEnableDebugReport || !g_debug_ready || StringLen(g_debug_file_rel)==0)
      return;

   int h=FileOpen(g_debug_file_rel,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE)
      return;

   FileSeek(h,0,SEEK_END);
   FileWriteString(h,TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS)+" | "+msg+"\r\n");
   FileClose(h);
  }

bool ISSX_EnsureFolderPath(const string folder)
  {
   string clean=folder;
   while(StringFind(clean,"\\\\")>=0)
      StringReplace(clean,"\\\\","\\");

   string acc="";
   int start=0;
   for(int i=0;i<StringLen(clean);i++)
     {
      if(StringGetCharacter(clean,i)!='\\')
         continue;
      string part=StringSubstr(clean,start,i-start);
      if(StringLen(part)<=0)
        {
         start=i+1;
         continue;
        }
      if(StringLen(acc)==0)
         acc=part;
      else
         acc=acc+"\\"+part;
      FolderCreate(acc);
      start=i+1;
     }
   return true;
  }

bool ISSX_BeginDebugReport()
  {
   if(!InpEnableDebugReport)
      return false;

   ISSX_EnsureFolderPath(g_debug_dir_primary);
   string stamp=TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS);
   StringReplace(stamp,".","-");
   StringReplace(stamp,":","-");
   StringReplace(stamp," ","_");

   g_debug_file_rel=g_debug_dir_primary+"ISSX_Debug_"+stamp+"_"+IntegerToString((int)ChartID())+".log";
   int h=FileOpen(g_debug_file_rel,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h!=INVALID_HANDLE)
     {
      g_debug_ready=true;
      g_debug_dir_active=g_debug_dir_primary;
      FileWriteString(h,"ISSX Debug Report\r\n");
      FileClose(h);
      Print("ISSX: debug report primary path active: ",g_debug_file_rel);
      return true;
     }

   const int err_primary=GetLastError();
   ISSX_EnsureFolderPath(g_debug_dir_fallback);
   g_debug_file_rel=g_debug_dir_fallback+"ISSX_Debug_"+stamp+"_"+IntegerToString((int)ChartID())+".log";
   h=FileOpen(g_debug_file_rel,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE)
     {
      Print("ISSX: debug report disabled; primary err=",err_primary," fallback err=",GetLastError());
      g_debug_ready=false;
      g_debug_file_rel="";
      g_debug_dir_active="";
      return false;
     }

   g_debug_ready=true;
   g_debug_dir_active=g_debug_dir_fallback;
   FileWriteString(h,"ISSX Debug Report\r\n");
   FileClose(h);
   Print("ISSX: debug report fallback path active: ",g_debug_file_rel);
   return true;
  }

void ISSX_WriteStartupDiagnostics()
  {
   MqlTick tick;
   const bool tick_ok=SymbolInfoTick(_Symbol,tick);
   ISSX_Log("STARTUP build="+IntegerToString((int)MQLInfoInteger(MQL_PROGRAM_BUILD))+" version=9.999 symbol="+_Symbol+" tf="+EnumToString((ENUM_TIMEFRAMES)_Period));
   ISSX_Log("STARTUP terminal data_path="+TerminalInfoString(TERMINAL_DATA_PATH));
   ISSX_Log("STARTUP account="+IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN))+" company="+AccountInfoString(ACCOUNT_COMPANY)+" server="+AccountInfoString(ACCOUNT_SERVER));
   ISSX_Log("STARTUP trade_allowed terminal="+IntegerToString((int)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))+" mql_trade_allowed="+IntegerToString((int)MQLInfoInteger(MQL_TRADE_ALLOWED)));
   ISSX_Log("STARTUP modules EA1="+(g_module_enabled[0]?"on":"off")+" EA2="+(g_module_enabled[1]?"on":"off")+" EA3="+(g_module_enabled[2]?"on":"off")+" EA4="+(g_module_enabled[3]?"on":"off")+" EA5="+(g_module_enabled[4]?"on":"off"));
   ISSX_Log("STARTUP symbol_tick_ok="+(tick_ok?"true":"false")+" bid="+DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits)+" ask="+DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits));
   ISSX_Log("STARTUP ui_ready="+(g_ui_ready?"true":"false")+" debug_path="+g_debug_file_rel);
  }

bool ISSX_CreateMenuLabel(const string name,const int x,const int y,const int w,const int h,const string txt,const color clr,const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER)
  {
   if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
     {
      ISSX_Log("UI create failed name="+name+" err="+IntegerToString(GetLastError()));
      return false;
     }
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   return true;
  }

bool ISSX_CreateMenuButton(const string name,const int x,const int y,const int w,const int h,const string txt,const color clr)
  {
   if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
     {
      ISSX_Log("UI button create failed name="+name+" err="+IntegerToString(GetLastError()));
      return false;
     }
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrBlack);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   return true;
  }

void ISSX_UpdateMenuState()
  {
   if(!g_ui_ready)
      return;
   for(int i=0;i<5;i++)
     {
      ObjectSetString(0,g_ui_btns[i],OBJPROP_TEXT,ISSX_UI_ModuleStateLabel(g_module_name[i],g_module_enabled[i],g_module_locked[i]));
      string sub="submenu: "+g_module_name[i]+" diagnostics";
      if(g_module_locked[i])
         sub=sub+" (internally disabled)";
      ObjectSetString(0,g_ui_subs[i],OBJPROP_TEXT,sub);
     }
  }

bool ISSX_BuildMenu()
  {
   if(!InpEnableChartMenu)
      return false;
   if(g_ui_ready)
      return true;

   g_ui_prefix="ISSX_UI_"+IntegerToString((int)ChartID())+"_";
   g_ui_title=g_ui_prefix+"TITLE";
   g_ui_bg=g_ui_prefix+"BG";

   ISSX_CreateMenuLabel(g_ui_bg,8,18,340,180,"",clrDimGray);
   ISSX_CreateMenuLabel(g_ui_title,12,22,300,18,"ISSX Main Menu (5 EAs)",clrAqua);

   int y=44;
   for(int i=0;i<5;i++)
     {
      g_ui_btns[i]=g_ui_prefix+"BTN_"+IntegerToString(i+1);
      g_ui_subs[i]=g_ui_prefix+"SUB_"+IntegerToString(i+1);
      ISSX_CreateMenuButton(g_ui_btns[i],12,y,120,18,g_module_name[i],clrSilver);
      ISSX_CreateMenuLabel(g_ui_subs[i],140,y+2,190,16,"submenu",clrSilver);
      y+=30;
     }

   g_ui_ready=true;
   ISSX_UpdateMenuState();
   ISSX_Log("UI menu build complete");
   return true;
  }

void ISSX_DestroyMenu()
  {
   if(!g_ui_ready)
      return;
   ObjectDelete(0,g_ui_bg);
   ObjectDelete(0,g_ui_title);
   for(int i=0;i<5;i++)
     {
      ObjectDelete(0,g_ui_btns[i]);
      ObjectDelete(0,g_ui_subs[i]);
     }
   g_ui_ready=false;
  }

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

bool ISSX_RunKernelCycle()
  {
   ISSX_Log("KERNEL enter");
   g_runtime.OnPulse();

   string stage_json="";
   string broker_dump_json="";
   string debug_json="";

   if(!g_module_enabled[0])
     {
      ISSX_Log("KERNEL skipped: EA1 disabled");
      return true;
     }

   if(!g_bootstrapped)
     {
      ISSX_Log("EA1 StageBoot");
      g_ea1.Reset();
      ISSX_MarketEngine::StageBoot(g_ea1);
     }

   ISSX_Log("EA1 StageSlice enter");
   if(!ISSX_MarketEngine::StageSlice(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,InpEA1MaxSymbols))
     {
      ISSX_Log("EA1 StageSlice failed");
      return false;
     }

   ISSX_Log("EA1 StageSlice ok symbols="+IntegerToString(ArraySize(g_ea1.symbols)));

   if(ArraySize(g_ea1.symbols)<=0)
     {
      ISSX_Log("EA1 produced zero symbols; skipping downstream stages");
      g_bootstrapped=true;
      return true;
     }

   ISSX_Log("EA1 StagePublish");
   ISSX_MarketEngine::StagePublish(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,stage_json,debug_json);
   ISSX_MarketEngine::BuildUniverseDump(g_ea1,g_firm_id,g_boot_id,g_writer_nonce,broker_dump_json);
   ISSX_ProjectEA1(stage_json,broker_dump_json,debug_json);

   string ea1_symbols[];
   const int ea1_count=ISSX_CopyEA1Symbols(ea1_symbols);
   ISSX_Log("EA1 symbol copy count="+IntegerToString(ea1_count));

   if(ea1_count<=0)
     {
      ISSX_Log("EA1 symbol copy empty; ending cycle safely");
      g_bootstrapped=true;
      return true;
     }

   if(!g_module_enabled[1] && !g_module_enabled[2] && !g_module_enabled[3] && !g_module_enabled[4])
     {
      ISSX_Log("EA2-EA5 disabled; EA1-only mode active");
      ISSX_DebugAggregate agg_ea1=ISSX_UI_Test::BuildAggregate(g_firm_id,g_runtime.State(),g_ea1,g_ea2,g_ea3,g_ea4,g_ea5);
      if(InpProjectStageStatusRoot)
         ISSX_UI_Test::ProjectStageStatusRoot(g_firm_id,agg_ea1);
      if(InpProjectUniverseSnapshot)
         ISSX_UI_Test::ProjectUniverseSnapshotRoot(g_firm_id,g_runtime.State());
      Comment("ISSX EA1-only mode | firm="+g_firm_id);
      g_bootstrapped=true;
      return true;
     }

   if(!g_bootstrapped)
     {
      Print("ISSX: EA2 StageBoot");
      ISSX_HistoryEngine::StageBoot(g_ea2,ea1_symbols,InpEA2DeepProfileDefault);
     }

   Print("ISSX: EA2 StageSlice");
   ISSX_HistoryEngine::StageSlice(g_ea2,ea1_symbols,InpEA2DeepProfileDefault,InpEA2MaxSymbolsPerSlice);
   stage_json=ISSX_HistoryEngine::StagePublish(g_ea2);
   debug_json=ISSX_HistoryEngine::BuildDebugSnapshot(g_ea2);
   ISSX_ProjectEA2(stage_json,debug_json);

   if(!g_bootstrapped)
     {
      Print("ISSX: EA3 StageBoot");
      ISSX_SelectionEngine::StageBoot(g_firm_id,g_ea1,g_ea2,g_ea3);
     }

   Print("ISSX: EA3 StageSlice");
   ISSX_SelectionEngine::StageSlice(g_firm_id,g_ea1,g_ea2,g_ea3);
   string ea3_debug="";
   ISSX_SelectionEngine::StagePublish(g_ea3,stage_json,ea3_debug);
   ISSX_ProjectEA3(stage_json,ea3_debug);

   if(!g_bootstrapped)
     {
      Print("ISSX: EA4 StageBoot");
      ISSX_CorrelationEngine::StageBoot(g_ea4,g_firm_id);
     }

   Print("ISSX: EA4 StageSlice");
   ISSX_CorrelationEngine::StageSlice(g_ea4,g_firm_id,g_ea1,g_ea3,ISSX_CurrentKernelMinuteId());
   string ea4_debug="";
   ISSX_CorrelationEngine::StagePublish(g_ea4,stage_json,ea4_debug);
   ISSX_ProjectEA4(stage_json,ea4_debug);

   ISSX_EA4_OptionalIntelligenceExport ea4_optional_intel[];
   ISSX_EA5_OptionalIntelligence optional_intel[];
   ArrayResize(ea4_optional_intel,0);
   ArrayResize(optional_intel,0);

   ISSX_CorrelationEngine::ExportOptionalIntelligence(g_ea4,ea4_optional_intel);
   ISSX_ConvertEA4OptionalIntelligence(ea4_optional_intel,optional_intel);

   Print("ISSX: EA5 BuildFromInputs");
   ISSX_Contracts::BuildFromInputs(g_ea5,g_ea1,g_ea2,g_ea3,optional_intel);

   const long current_minute_id=ISSX_CurrentKernelMinuteId();
   const bool ea5_export_due=(!g_bootstrapped || ISSX_IsEA5ExportDue(current_minute_id));

   if(ea5_export_due)
     {
      Print("ISSX: EA5 export due");
      string export_json=ISSX_Contracts::ToStageJson(g_ea5,g_registry.fields,g_registry.enums);
      string ea5_debug=ISSX_Contracts::ToDebugJson(g_ea5);
      ISSX_ProjectEA5(export_json,ea5_debug);
      g_last_ea5_export_minute_id=current_minute_id;
     }

   Print("ISSX: UI aggregate");
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

   Comment(ISSX_UI_Test::BuildHudText(agg));
   g_bootstrapped=true;
   ISSX_Log("KERNEL exit ok");
   return true;
  }

int OnInit()
  {
   g_module_enabled[0]=InpEnableEA1;
   g_module_enabled[1]=InpEnableEA2;
   g_module_enabled[2]=InpEnableEA3;
   g_module_enabled[3]=InpEnableEA4;
   g_module_enabled[4]=InpEnableEA5;

   g_module_locked[0]=false;
   g_module_locked[1]=true;
   g_module_locked[2]=true;
   g_module_locked[3]=true;
   g_module_locked[4]=true;

   g_module_enabled[1]=false;
   g_module_enabled[2]=false;
   g_module_enabled[3]=false;
   g_module_enabled[4]=false;

   ISSX_BeginDebugReport();
   ISSX_Log("INIT enter");

   MathSrand((uint)TimeLocal());

   g_boot_id        = ISSX_WrapperBootId();
   g_instance_guid  = ISSX_WrapperInstanceGuid();
   g_writer_nonce   = ISSX_WrapperNonce();
   g_firm_id        = ISSX_ResolveFirmId();

   ISSX_Log("INIT boot_id="+g_boot_id);
   ISSX_Log("INIT instance_guid="+g_instance_guid);
   ISSX_Log("INIT writer_nonce="+g_writer_nonce);
   ISSX_Log("INIT firm_id="+g_firm_id);

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   ISSX_Log("INIT trade magic="+IntegerToString((int)InpMagicNumber));

   // registry + runtime
   g_registry.SeedBlueprintV170();
   g_runtime.Init();

   g_bootstrapped     = false;
   g_runtime_ready    = true;
   g_first_cycle_done = false;
   g_kernel_busy      = false;

   ISSX_BuildMenu();
   ISSX_WriteStartupDiagnostics();

   const int timer_sec=ISSX_Runtime_NormalizeTimerSeconds(ISSX_EVENT_TIMER_SEC);
   if(!EventSetTimer(timer_sec))
     {
      ISSX_Log("INIT failed EventSetTimer err="+IntegerToString(GetLastError()));
      return INIT_FAILED;
     }

   ISSX_Log("INIT exit success");
   Comment("ISSX attached - waiting for timer");

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_kernel_busy=false;
   ISSX_DestroyMenu();

   ISSX_Log("DEINIT reason="+IntegerToString(reason)+" "+ISSX_Core_DeinitReasonToString(reason));
   ISSX_Log("SESSION SUMMARY attached="+(g_first_cycle_done?"true":"false")+" last_kernel_busy="+(g_kernel_busy?"true":"false"));
   Comment("");
  }

void OnTimer()
  {
   if(InpSafeMode)
     {
      ISSX_Log("TIMER safe mode heartbeat");
      return;
     }

   if(!g_runtime_ready)
     {
      ISSX_Log("TIMER skipped runtime not ready");
      return;
     }

   if(g_kernel_busy)
     {
      ISSX_Log("TIMER skipped kernel busy");
      return;
     }

   g_kernel_busy=true;

   ISSX_Log("TIMER start first_cycle="+((!g_first_cycle_done)?"true":"false"));

   bool ok=ISSX_RunKernelCycle();

   ISSX_Log("TIMER kernel result="+(ok?"ok":"fail"));

   g_first_cycle_done=true;
   g_kernel_busy=false;

   if(ok)
      Comment("ISSX running | firm="+g_firm_id);
   else
      Comment("ISSX degraded | firm="+g_firm_id);
  }

void OnTick()
  {
   g_tick_count++;
   if(InpHeartbeatTickModulo>0 && (g_tick_count%InpHeartbeatTickModulo)==0)
      ISSX_Log("TICK heartbeat symbol="+_Symbol+" bid="+DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits)+" ask="+DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits),false);
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id!=CHARTEVENT_OBJECT_CLICK || !g_ui_ready)
      return;

   for(int i=0;i<5;i++)
     {
      if(sparam!=g_ui_btns[i])
         continue;

      if(g_module_locked[i])
        {
         ISSX_Log("UI click ignored: "+g_module_name[i]+" locked off");
         ISSX_UpdateMenuState();
         return;
        }

      g_module_enabled[i]=!g_module_enabled[i];
      ISSX_Log("UI toggle "+g_module_name[i]+" -> "+(g_module_enabled[i]?"on":"off"));
      ISSX_UpdateMenuState();
      return;
     }
  }
