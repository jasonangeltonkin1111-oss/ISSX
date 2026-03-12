#ifndef __ISSX_PERSISTENCE_MQH__
#define __ISSX_PERSISTENCE_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_registry.mqh>
#include <ISSX/issx_data_handler.mqh>

// ============================================================================
// ISSX PERSISTENCE v1.732
// Blueprint-aligned persistence / handoff / fallback / warehouse / lock helpers.
// Authoritative truth remains: accepted internal current + coherent manifest chain.
// ============================================================================

// ============================================================================
// SECTION 01: DTO TYPES
// ============================================================================

struct ISSX_ProjectionOutcome
  {
   bool   internal_commit_success;
   bool   root_stage_projection_success;
   bool   root_debug_projection_success;
   bool   root_status_projection_success;
   bool   root_universe_snapshot_success;
   bool   projection_partial_success_flag;
   int    debug_projection_fail_count;
   string last_projection_reason;

   void Reset()
     {
      internal_commit_success=false;
      root_stage_projection_success=false;
      root_debug_projection_success=false;
      root_status_projection_success=false;
      root_universe_snapshot_success=false;
      projection_partial_success_flag=false;
      debug_projection_fail_count=0;
      last_projection_reason="";
     }
  };

struct ISSX_CompatibilityCheck
  {
   ISSX_CompatibilityClass compatibility_class;
   int                     compatibility_score;
   string                  reason;
   bool                    firm_match;
   bool                    stage_match;
   bool                    schema_compatible;
   bool                    schema_epoch_compatible;
   bool                    storage_compatible;
   bool                    policy_compatible;
   bool                    required_block_presence;
   bool                    sequence_monotonic_sane;
   bool                    taxonomy_hash_compatible;
   bool                    comparator_registry_hash_compatible;
   bool                    universe_fingerprint_compatible;
   bool                    symbol_continuity_compatible;
   bool                    freshness_fit;
   bool                    content_class_fit;
   bool                    generation_coherent;
   bool                    header_payload_hash_match;
   bool                    consumer_compatible;

   void Reset()
     {
      compatibility_class=issx_compat_incompatible;
      compatibility_score=0;
      reason="";
      firm_match=false;
      stage_match=false;
      schema_compatible=false;
      schema_epoch_compatible=false;
      storage_compatible=false;
      policy_compatible=false;
      required_block_presence=false;
      sequence_monotonic_sane=false;
      taxonomy_hash_compatible=false;
      comparator_registry_hash_compatible=false;
      universe_fingerprint_compatible=false;
      symbol_continuity_compatible=false;
      freshness_fit=false;
      content_class_fit=false;
      generation_coherent=false;
      header_payload_hash_match=false;
      consumer_compatible=false;
     }
  };

struct ISSX_UpstreamReadOutcome
  {
   bool                    found;
   string                  upstream_source_used;
   string                  upstream_source_reason;
   ISSX_HandoffMode        upstream_handoff_mode;
   ISSX_CompatibilityClass upstream_compatibility_class;
   int                     upstream_compatibility_score;
   bool                    upstream_handoff_same_tick_flag;
   bool                    upstream_partial_progress_flag;
   long                    upstream_handoff_sequence_no;
   string                  upstream_payload_hash;
   string                  upstream_policy_fingerprint;
   int                     fallback_depth_used;
   double                  fallback_penalty_applied;
   ISSX_Manifest           manifest;
   ISSX_StageHeader        header;
   string                  payload_text;

   void Reset()
     {
      found=false;
      upstream_source_used="";
      upstream_source_reason="";
      upstream_handoff_mode=issx_handoff_none;
      upstream_compatibility_class=issx_compat_incompatible;
      upstream_compatibility_score=0;
      upstream_handoff_same_tick_flag=false;
      upstream_partial_progress_flag=false;
      upstream_handoff_sequence_no=0;
      upstream_payload_hash="";
      upstream_policy_fingerprint="";
      fallback_depth_used=0;
      fallback_penalty_applied=0.0;
      manifest.Reset();
      header.Reset();
      payload_text="";
     }
  };

struct ISSX_HandoffRecord
  {
   ISSX_StageId            stage_id;
   string                  firm_id;
   ISSX_HandoffMode        upstream_handoff_mode;
   ISSX_CompatibilityClass upstream_handoff_compatibility_class;
   bool                    upstream_handoff_same_tick_flag;
   bool                    upstream_partial_progress_flag;
   long                    upstream_handoff_sequence_no;
   string                  upstream_payload_hash;
   string                  upstream_policy_fingerprint;
   long                    writer_generation;
   string                  trio_generation_id;
   long                    minute_id;
   bool                    accepted_promotion_verified;

   void Reset()
     {
      stage_id=issx_stage_shared;
      firm_id="";
      upstream_handoff_mode=issx_handoff_none;
      upstream_handoff_compatibility_class=issx_compat_incompatible;
      upstream_handoff_same_tick_flag=false;
      upstream_partial_progress_flag=false;
      upstream_handoff_sequence_no=0;
      upstream_payload_hash="";
      upstream_policy_fingerprint="";
      writer_generation=0;
      trio_generation_id="";
      minute_id=0;
      accepted_promotion_verified=false;
     }
  };

struct ISSX_LockLease
  {
   string   lock_owner_boot_id;
   string   lock_owner_instance_guid;
   string   lock_owner_terminal_identity;
   datetime lock_acquired_time;
   datetime lock_heartbeat_time;
   int      stale_after_sec;

   void Reset()
     {
      lock_owner_boot_id="";
      lock_owner_instance_guid="";
      lock_owner_terminal_identity="";
      lock_acquired_time=0;
      lock_heartbeat_time=0;
      stale_after_sec=60;
     }
  };

struct ISSX_DirtyShardBatch
  {
   string shard_keys_csv;
   int    dirty_count;
   long   touched_minute_id;
   bool   flush_required;

   void Reset()
     {
      shard_keys_csv="";
      dirty_count=0;
      touched_minute_id=0;
      flush_required=false;
     }
  };

// ============================================================================
// SECTION 02: LOW-LEVEL FILE HELPERS
// ============================================================================

class ISSX_FileIO
  {
private:
   static uint Utf8Codepage()
     {
#ifdef CP_UTF8
      return (uint)CP_UTF8;
#else
      return (uint)65001;
#endif
     }

   static short NoDelimiter()
     {
      return (short)0;
     }

   static int LastSeparatorPos(const string path)
     {
      int pos=-1;
      int p=StringFind(path,ISSX_PATH_SEP,0);
      while(p>=0)
        {
         pos=p;
         p=StringFind(path,ISSX_PATH_SEP,p+1);
        }
     return pos;
     }

   static bool IsSafeRelativePath(const string relative_path)
     {
      if(ISSX_Util::IsEmpty(relative_path))
         return false;

      if(StringSubstr(relative_path,0,1)=="/" || StringSubstr(relative_path,0,1)=="\\")
         return false;

      if(StringFind(relative_path,":",0)>=0)
         return false;

      if(StringFind(relative_path,"..",0)>=0)
         return false;

      return true;
     }

public:
   static bool EnsureFolder(const string relative_path)
     {
      if(ISSX_Util::IsEmpty(relative_path))
         return false;

      string parts[];
      const ushort sep=(ushort)StringGetCharacter(ISSX_PATH_SEP,0);
      const int n=StringSplit(relative_path,sep,parts);

      if(n<=0)
         return false;

      string build="";
      for(int i=0;i<n;i++)
        {
         if(ISSX_Util::IsEmpty(parts[i]))
            continue;

         build=(ISSX_Util::IsEmpty(build) ? parts[i] : ISSX_Util::JoinPath(build,parts[i]));
         FolderCreate(build,FILE_COMMON);
        }

      return true;
     }

   static bool EnsureParentFolder(const string relative_file_path)
     {
      const int last=LastSeparatorPos(relative_file_path);
      if(last<=0)
         return true;

      return EnsureFolder(StringSubstr(relative_file_path,0,last));
     }

   static bool WriteTextAtomic(const string relative_path,const string text)
     {
      if(!IsSafeRelativePath(relative_path))
         return false;

      if(!EnsureParentFolder(relative_path))
         return false;

      ISSX_DataHandler::ForensicState fs;
      fs.Reset();
      return ISSX_DataHandler::WritePayloadAtomic(relative_path,text,fs,true);
     }

   static bool WriteText(const string relative_path,const string text)
     {
      return WriteTextAtomic(relative_path,text);
     }

   static bool ReadText(const string relative_path,string &out_text)
     {
      out_text="";

      if(!IsSafeRelativePath(relative_path))
         return false;

      ResetLastError();
      const int h=FileOpen(relative_path,
                           FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI,
                           NoDelimiter(),
                           Utf8Codepage());
      if(h==INVALID_HANDLE)
         return false;

      const ulong sz=FileSize(h);
      if(sz>(ulong)2147483647)
        {
         FileClose(h);
         return false;
        }

      ResetLastError();
      out_text=FileReadString(h);
      if(GetLastError()!=0)
        {
         FileClose(h);
         return false;
        }

      FileClose(h);
      return true;
     }

   // ---------------------------------------------------------------------
   // Legacy compatibility bridge retained in owner file for older consumers.
   // ---------------------------------------------------------------------
   static bool WriteAllTextUtf8(const string relative_path,const string text)
     {
      return WriteText(relative_path,text);
     }

   static bool ReadAllTextUtf8(const string relative_path,string &out_text)
     {
      return ReadText(relative_path,out_text);
     }

   static bool CopyText(const string src,const string dst)
     {
      if(!IsSafeRelativePath(src) || !IsSafeRelativePath(dst))
         return false;

      if(!EnsureParentFolder(dst))
         return false;
      ISSX_DataHandler::ForensicState fs;
      fs.Reset();
      if(ISSX_DataHandler::CopyProjection(src,dst,fs))
         return true;

      string s="";
      if(!ReadText(src,s))
         return false;
      return WriteText(dst,s);
     }

   static bool DeleteIfExists(const string relative_path)
     {
      if(!IsSafeRelativePath(relative_path))
         return false;

      if(!FileIsExist(relative_path,FILE_COMMON))
         return true;

      ResetLastError();
      return FileDelete(relative_path,FILE_COMMON);
     }

   static bool Exists(const string relative_path)
     {
      if(!IsSafeRelativePath(relative_path))
         return false;

      return FileIsExist(relative_path,FILE_COMMON);
     }

   static bool WriteTextIfChanged(const string relative_path,const string text)
     {
      string existing="";
      if(ReadText(relative_path,existing) && existing==text)
         return true;
      return WriteText(relative_path,text);
     }
  };

// ============================================================================
// SECTION 03: PATH BUILDERS
// ============================================================================

class ISSX_PersistencePath
  {
private:
   static string StageDir(const string firm_id,const ISSX_StageId stage_id)
     {
      return ISSX_Util::JoinPath(FirmRoot(firm_id),ISSX_Stage::PersistenceFolder(stage_id));
     }

public:
   static string FirmRoot(const string firm_id)
     {
      return ISSX_DIR_ROOT_NAME;
     }

   static string RootFile(const string firm_id,const string filename)
     {
      return ISSX_Util::JoinPath(FirmRoot(firm_id),filename);
     }

   static string RootExport(const string firm_id)            { return RootFile(firm_id,ISSX_ROOT_EXPORT); }
   static string RootDebug(const string firm_id)             { return RootFile(firm_id,ISSX_ROOT_DEBUG); }
   static string RootStageStatus(const string firm_id)       { return RootFile(firm_id,ISSX_ROOT_STAGE_STATUS); }
   static string RootUniverseSnapshot(const string firm_id)  { return RootFile(firm_id,ISSX_ROOT_UNIVERSE_SNAPSHOT); }

   // ---------------------------------------------------------------------
   // Legacy compatibility bridge retained in owner file for older UI callers.
   // ---------------------------------------------------------------------
   static string DebugRootFile(const string firm_id)         { return RootDebug(firm_id); }
   static string StageStatusRootFile(const string firm_id)   { return RootStageStatus(firm_id); }
   static string UniverseSnapshotFile(const string firm_id)  { return RootUniverseSnapshot(firm_id); }

   static string InternalDir(const string firm_id,const ISSX_StageId stage_id)
     {
      return StageDir(firm_id,stage_id);
     }

   static string InternalFile(const string firm_id,const ISSX_StageId stage_id,const string filename)
     {
      return ISSX_Util::JoinPath(StageDir(firm_id,stage_id),filename);
     }

   static string SharedDir(const string firm_id)
     {
      return ISSX_Util::JoinPath(ISSX_DIR_ROOT_NAME,ISSX_DIR_PERSISTENCE_SHARED);
     }

   static string DebugDir(const string firm_id)
     {
      return ISSX_Util::JoinPath(FirmRoot(firm_id),ISSX_DIR_DEBUG);
     }

   static string DebugFolder(const string firm_id)
     {
      string dir=DebugDir(firm_id);
      if(StringLen(dir)<=0)
         return "";
      if(StringSubstr(dir,StringLen(dir)-1,1)!=ISSX_PATH_SEP)
         dir+=ISSX_PATH_SEP;
      return dir;
     }

   static string LocksDir(const string firm_id)
     {
      return ISSX_Util::JoinPath(FirmRoot(firm_id),ISSX_DIR_LOCKS);
     }

   static string SchemasDir(const string firm_id)
     {
      return ISSX_Util::JoinPath(FirmRoot(firm_id),ISSX_DIR_SCHEMAS);
     }

   static string HudDir(const string firm_id)
     {
      return ISSX_Util::JoinPath(FirmRoot(firm_id),ISSX_DIR_HUD);
     }

   static string HudTextFile(const string firm_id)
     {
      return ISSX_Util::JoinPath(HudDir(firm_id),"issx_hud.txt");
     }

   static string LockFile(const string firm_id)
     {
      return ISSX_Util::JoinPath(LocksDir(firm_id),ISSX_LOCK_FILENAME);
     }

   static string DebugSnapshot(const string firm_id,const ISSX_StageId stage_id)
     {
      return ISSX_Util::JoinPath(DebugDir(firm_id),ISSX_Stage::DebugSnapshotFilename(stage_id));
     }

   static string UniverseDir(const string firm_id)
     {
      return ISSX_Util::JoinPath(FirmRoot(firm_id),ISSX_DIR_PERSISTENCE_EA1_UNIVERSE);
     }

   static string HistoryStoreDir(const string firm_id)
     {
      return ISSX_Util::JoinPath(FirmRoot(firm_id),ISSX_DIR_PERSISTENCE_EA2_HISTORY_STORE);
     }

   static string HistoryIndexDir(const string firm_id)
     {
      return ISSX_Util::JoinPath(FirmRoot(firm_id),ISSX_DIR_PERSISTENCE_EA2_HISTORY_INDEX);
     }

   static string HistoryTfDir(const string firm_id,const string tf)
     {
      return ISSX_Util::JoinPath(HistoryStoreDir(firm_id),tf);
     }

   static string HistoryShard(const string firm_id,const string tf,const string symbol)
     {
      return ISSX_Util::JoinPath(HistoryTfDir(firm_id,tf),symbol+ISSX_HISTORY_SYMBOL_SUFFIX);
     }

   static string HandoffPrefix(const string firm_id,const ISSX_StageId stage_id)
     {
      return ISSX_Util::JoinPath(SharedDir(firm_id),"handoff_"+ISSX_Stage::ToMachineId(stage_id));
     }

   static string HandoffHeaderFile(const string firm_id,const ISSX_StageId stage_id)
     {
      return HandoffPrefix(firm_id,stage_id)+"_header.json";
     }

   static string HandoffManifestFile(const string firm_id,const ISSX_StageId stage_id)
     {
      return HandoffPrefix(firm_id,stage_id)+"_manifest.json";
     }

   static string HandoffPayloadFile(const string firm_id,const ISSX_StageId stage_id)
     {
      return HandoffPrefix(firm_id,stage_id)+"_payload.bin";
     }

   static string HandoffRecordFile(const string firm_id,const ISSX_StageId stage_id)
     {
      return HandoffPrefix(firm_id,stage_id)+"_record.json";
     }

   static string HeaderCurrent(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_BIN_HEADER_CURRENT);
     }

   static string PayloadCurrent(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_BIN_PAYLOAD_CURRENT);
     }

   static string ManifestCurrent(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_JSON_MANIFEST_CURRENT);
     }

   static string HeaderPrevious(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_BIN_HEADER_PREVIOUS);
     }

   static string PayloadPrevious(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_BIN_PAYLOAD_PREVIOUS);
     }

   static string ManifestPrevious(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_JSON_MANIFEST_PREVIOUS);
     }

   static string HeaderCandidate(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_BIN_HEADER_CANDIDATE);
     }

   static string PayloadCandidate(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_BIN_PAYLOAD_CANDIDATE);
     }

   static string ManifestCandidate(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_JSON_MANIFEST_CANDIDATE);
     }

   static string PayloadLastGood(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_BIN_PAYLOAD_LASTGOOD);
     }

   static string ManifestLastGood(const string firm_id,const ISSX_StageId stage_id)
     {
      return InternalFile(firm_id,stage_id,ISSX_JSON_MANIFEST_LASTGOOD);
     }
  };

// ============================================================================
// SECTION 04: JSON EXTRACTION / SERIALIZATION
// ============================================================================

#ifndef ISSX_HISTORY_SYMBOL_SUFFIX
#define ISSX_HISTORY_SYMBOL_SUFFIX ".bin"
#endif

class ISSX_PersistEnum
  {
public:
   static string StageToString(const ISSX_StageId stage_id)
     {
      return ISSX_Stage::ToMachineId(stage_id);
     }

   static ISSX_StageId StageFromString(const string s)
     {
      string t=s;
      StringToLower(t);
      if(t=="ea1")    return issx_stage_ea1;
      if(t=="ea2")    return issx_stage_ea2;
      if(t=="ea3")    return issx_stage_ea3;
      if(t=="ea4")    return issx_stage_ea4;
      if(t=="ea5")    return issx_stage_ea5;
      if(t=="shared") return issx_stage_shared;
      return issx_stage_unknown;
     }
  };

class ISSX_PersistenceJson
  {
private:
   static int FindName(const string json,const string name)
     {
      return StringFind(json,"\""+name+"\":");
     }

   static string TrimRaw(const string v)
     {
      string t=v;
      StringTrimLeft(t);
      StringTrimRight(t);
      return t;
     }

public:
   static string ExtractRaw(const string json,const string name)
     {
      int p=FindName(json,name);
      if(p<0)
         return "";

      p+=StringLen(name)+3;

      while(p<StringLen(json))
        {
         const string ch=StringSubstr(json,p,1);
         if(ch!=" " && ch!="\t" && ch!="\r" && ch!="\n")
            break;
         p++;
        }

      if(p>=StringLen(json))
         return "";

      if(StringSubstr(json,p,1)=="\"")
        {
         int q=p+1;
         while(q<StringLen(json))
           {
            if(StringSubstr(json,q,1)=="\"" && StringSubstr(json,q-1,1)!="\\")
               break;
            q++;
           }
         return StringSubstr(json,p+1,q-p-1);
        }

      int q=p;
      while(q<StringLen(json))
        {
         const string ch=StringSubstr(json,q,1);
         if(ch=="," || ch=="}" || ch=="]")
            break;
         q++;
        }

      return TrimRaw(StringSubstr(json,p,q-p));
     }

   static string ExtractString(const string json,const string name,const string def="")
     {
      const string v=ExtractRaw(json,name);
      return (ISSX_Util::IsEmpty(v) ? def : v);
     }

   static long ExtractLong(const string json,const string name,const long def=0)
     {
      const string v=ExtractRaw(json,name);
      if(ISSX_Util::IsEmpty(v))
         return def;
      return (long)StringToInteger(v);
     }

   static double ExtractDouble(const string json,const string name,const double def=0.0)
     {
      const string v=ExtractRaw(json,name);
      if(ISSX_Util::IsEmpty(v))
         return def;
      return StringToDouble(v);
     }

   static bool ExtractBool(const string json,const string name,const bool def=false)
     {
      string t=ExtractRaw(json,name);
      StringToLower(t);
      if(t=="true")
         return true;
      if(t=="false")
         return false;
      return def;
     }
  };

class ISSX_PersistenceCodec
  {
public:
   static string BinaryHeaderToJson(const ISSX_BinaryHeader &h)
     {
      ISSX_JsonWriter w;
      w.Reset();
      w.BeginObject();
      w.NameInt("magic",h.magic);
      w.NameString("stage_id",ISSX_PersistEnum::StageToString(h.stage_id));
      w.NameString("schema_version",h.schema_version);
      w.NameInt("schema_epoch",h.schema_epoch);
      w.NameInt("storage_version",h.storage_version);
      w.NameInt("writer_generation",h.writer_generation);
      w.NameInt("sequence_no",h.sequence_no);
      w.NameInt("record_size",h.record_size);
      w.NameInt("payload_length",h.payload_length);
      w.NameString("payload_hash_or_crc",h.payload_hash_or_crc);
      w.NameString("header_hash_or_crc",h.header_hash_or_crc);
      w.EndObject();
      return w.ToString();
     }

   static bool JsonToBinaryHeader(const string json,ISSX_BinaryHeader &h)
     {
      h.Reset();
      h.magic=(int)ISSX_PersistenceJson::ExtractLong(json,"magic",ISSX_BINARY_MAGIC);
      h.stage_id=ISSX_PersistEnum::StageFromString(ISSX_PersistenceJson::ExtractString(json,"stage_id","shared"));
      h.schema_version=ISSX_PersistenceJson::ExtractString(json,"schema_version",ISSX_SCHEMA_VERSION);
      h.schema_epoch=(int)ISSX_PersistenceJson::ExtractLong(json,"schema_epoch",ISSX_SCHEMA_EPOCH);
      h.storage_version=(int)ISSX_PersistenceJson::ExtractLong(json,"storage_version",ISSX_STORAGE_VERSION);
      h.writer_generation=ISSX_PersistenceJson::ExtractLong(json,"writer_generation",0);
      h.sequence_no=ISSX_PersistenceJson::ExtractLong(json,"sequence_no",0);
      h.record_size=(int)ISSX_PersistenceJson::ExtractLong(json,"record_size",0);
      h.payload_length=(int)ISSX_PersistenceJson::ExtractLong(json,"payload_length",0);
      h.payload_hash_or_crc=ISSX_PersistenceJson::ExtractString(json,"payload_hash_or_crc","");
      h.header_hash_or_crc=ISSX_PersistenceJson::ExtractString(json,"header_hash_or_crc","");
      return true;
     }

   static string HeaderToJson(const ISSX_StageHeader &h)
     {
      ISSX_JsonWriter w;
      w.Reset();
      w.BeginObject();
      w.NameInt("magic",h.magic);
      w.NameString("stage_id",ISSX_PersistEnum::StageToString(h.stage_id));
      w.NameString("firm_id",h.firm_id);
      w.NameString("schema_version",h.schema_version);
      w.NameInt("schema_epoch",h.schema_epoch);
      w.NameInt("storage_version",h.storage_version);
      w.NameInt("writer_generation",h.writer_generation);
      w.NameInt("sequence_no",h.sequence_no);
      w.NameString("trio_generation_id",h.trio_generation_id);
      w.NameInt("record_size_or_payload_length",h.record_size_or_payload_length);
      w.NameInt("payload_length",h.payload_length);
      w.NameInt("header_length",h.header_length);
      w.NameString("payload_hash",h.payload_hash);
      w.NameString("header_hash",h.header_hash);
      w.NameInt("symbol_count",h.symbol_count);
      w.NameInt("changed_symbol_count",h.changed_symbol_count);
      w.NameInt("minute_id",h.minute_id);
      w.NameString("writer_boot_id",h.writer_boot_id);
      w.NameString("writer_nonce",h.writer_nonce);
      w.NameString("cohort_fingerprint",h.cohort_fingerprint);
      w.NameString("universe_fingerprint",h.universe_fingerprint);
      w.NameString("policy_fingerprint",h.policy_fingerprint);
      w.NameInt("fingerprint_algorithm_version",h.fingerprint_algorithm_version);
      w.NameInt("contradiction_count",h.contradiction_count);
      w.NameInt("contradiction_severity_max",(int)h.contradiction_severity_max);
      w.NameBool("degraded_flag",h.degraded_flag);
      w.NameInt("fallback_depth_used",h.fallback_depth_used);
      w.EndObject();
      return w.ToString();
     }

   static bool JsonToHeader(const string json,ISSX_StageHeader &h)
     {
      h.Reset();
      h.magic=(int)ISSX_PersistenceJson::ExtractLong(json,"magic",ISSX_BINARY_MAGIC);
      h.stage_id=ISSX_PersistEnum::StageFromString(ISSX_PersistenceJson::ExtractString(json,"stage_id","shared"));
      h.firm_id=ISSX_PersistenceJson::ExtractString(json,"firm_id","");
      h.schema_version=ISSX_PersistenceJson::ExtractString(json,"schema_version",ISSX_SCHEMA_VERSION);
      h.schema_epoch=(int)ISSX_PersistenceJson::ExtractLong(json,"schema_epoch",ISSX_SCHEMA_EPOCH);
      h.storage_version=(int)ISSX_PersistenceJson::ExtractLong(json,"storage_version",ISSX_STORAGE_VERSION);
      h.writer_generation=ISSX_PersistenceJson::ExtractLong(json,"writer_generation",0);
      h.sequence_no=ISSX_PersistenceJson::ExtractLong(json,"sequence_no",0);
      h.trio_generation_id=ISSX_PersistenceJson::ExtractString(json,"trio_generation_id","");
      h.record_size_or_payload_length=(int)ISSX_PersistenceJson::ExtractLong(json,"record_size_or_payload_length",0);
      h.payload_length=(int)ISSX_PersistenceJson::ExtractLong(json,"payload_length",0);
      h.header_length=(int)ISSX_PersistenceJson::ExtractLong(json,"header_length",0);
      h.payload_hash=ISSX_PersistenceJson::ExtractString(json,"payload_hash","");
      h.header_hash=ISSX_PersistenceJson::ExtractString(json,"header_hash","");
      h.symbol_count=(int)ISSX_PersistenceJson::ExtractLong(json,"symbol_count",0);
      h.changed_symbol_count=(int)ISSX_PersistenceJson::ExtractLong(json,"changed_symbol_count",0);
      h.minute_id=ISSX_PersistenceJson::ExtractLong(json,"minute_id",0);
      h.writer_boot_id=ISSX_PersistenceJson::ExtractString(json,"writer_boot_id","");
      h.writer_nonce=ISSX_PersistenceJson::ExtractString(json,"writer_nonce","");
      h.cohort_fingerprint=ISSX_PersistenceJson::ExtractString(json,"cohort_fingerprint","");
      h.universe_fingerprint=ISSX_PersistenceJson::ExtractString(json,"universe_fingerprint","");
      h.policy_fingerprint=ISSX_PersistenceJson::ExtractString(json,"policy_fingerprint","");
      h.fingerprint_algorithm_version=(int)ISSX_PersistenceJson::ExtractLong(json,"fingerprint_algorithm_version",ISSX_FINGERPRINT_ALGO_VERSION);
      h.contradiction_count=(int)ISSX_PersistenceJson::ExtractLong(json,"contradiction_count",0);
      h.contradiction_severity_max=(ISSX_ContradictionSeverity)ISSX_PersistenceJson::ExtractLong(json,"contradiction_severity_max",0);
      h.degraded_flag=ISSX_PersistenceJson::ExtractBool(json,"degraded_flag",false);
      h.fallback_depth_used=(int)ISSX_PersistenceJson::ExtractLong(json,"fallback_depth_used",0);
      return true;
     }

   static string ManifestToJson(const ISSX_Manifest &m)
     {
      ISSX_JsonWriter w;
      w.Reset();
      w.BeginObject();
      w.NameString("stage_id",ISSX_PersistEnum::StageToString(m.stage_id));
      w.NameString("firm_id",m.firm_id);
      w.NameString("schema_version",m.schema_version);
      w.NameInt("schema_epoch",m.schema_epoch);
      w.NameInt("storage_version",m.storage_version);
      w.NameInt("sequence_no",m.sequence_no);
      w.NameInt("minute_id",m.minute_id);
      w.NameString("writer_boot_id",m.writer_boot_id);
      w.NameString("writer_nonce",m.writer_nonce);
      w.NameInt("writer_generation",m.writer_generation);
      w.NameString("trio_generation_id",m.trio_generation_id);
      w.NameString("payload_hash",m.payload_hash);
      w.NameString("header_hash",m.header_hash);
      w.NameInt("payload_length",m.payload_length);
      w.NameInt("header_length",m.header_length);
      w.NameInt("symbol_count",m.symbol_count);
      w.NameInt("changed_symbol_count",m.changed_symbol_count);
      w.NameInt("content_class",(int)m.content_class);
      w.NameInt("publish_reason",(int)m.publish_reason);
      w.NameString("cohort_fingerprint",m.cohort_fingerprint);
      w.NameString("taxonomy_hash",m.taxonomy_hash);
      w.NameString("comparator_registry_hash",m.comparator_registry_hash);
      w.NameString("policy_fingerprint",m.policy_fingerprint);
      w.NameInt("fingerprint_algorithm_version",m.fingerprint_algorithm_version);
      w.NameString("universe_fingerprint",m.universe_fingerprint);
      w.NameInt("compatibility_class",(int)m.compatibility_class);
      w.NameInt("contradiction_count",m.contradiction_count);
      w.NameInt("contradiction_severity_max",(int)m.contradiction_severity_max);
      w.NameBool("degraded_flag",m.degraded_flag);
      w.NameInt("fallback_depth_used",m.fallback_depth_used);
      w.NameInt("accepted_strong_count",m.accepted_strong_count);
      w.NameInt("accepted_degraded_count",m.accepted_degraded_count);
      w.NameInt("rejected_count",m.rejected_count);
      w.NameInt("cooldown_count",m.cooldown_count);
      w.NameInt("stale_usable_count",m.stale_usable_count);
      w.NameBool("projection_partial_success_flag",m.projection_partial_success_flag);
      w.NameBool("accepted_promotion_verified",m.accepted_promotion_verified);
      w.NameBool("stage_minimum_ready_flag",m.stage_minimum_ready_flag);
      w.NameInt("stage_publishability_state",(int)m.stage_publishability_state);
      w.NameInt("handoff_mode",(int)m.handoff_mode);
      w.NameInt("handoff_sequence_no",m.handoff_sequence_no);
      w.NameDouble("fallback_read_ratio_1h",m.fallback_read_ratio_1h,6);
      w.NameDouble("fresh_accept_ratio_1h",m.fresh_accept_ratio_1h,6);
      w.NameDouble("same_tick_handoff_ratio_1h",m.same_tick_handoff_ratio_1h,6);
      w.NameString("legend_hash",m.legend_hash);
      w.EndObject();
      return w.ToString();
     }

   static bool JsonToManifest(const string json,ISSX_Manifest &m)
     {
      m.Reset();
      m.stage_id=ISSX_PersistEnum::StageFromString(ISSX_PersistenceJson::ExtractString(json,"stage_id","shared"));
      m.firm_id=ISSX_PersistenceJson::ExtractString(json,"firm_id","");
      m.schema_version=ISSX_PersistenceJson::ExtractString(json,"schema_version",ISSX_SCHEMA_VERSION);
      m.schema_epoch=(int)ISSX_PersistenceJson::ExtractLong(json,"schema_epoch",ISSX_SCHEMA_EPOCH);
      m.storage_version=(int)ISSX_PersistenceJson::ExtractLong(json,"storage_version",ISSX_STORAGE_VERSION);
      m.sequence_no=ISSX_PersistenceJson::ExtractLong(json,"sequence_no",0);
      m.minute_id=ISSX_PersistenceJson::ExtractLong(json,"minute_id",0);
      m.writer_boot_id=ISSX_PersistenceJson::ExtractString(json,"writer_boot_id","");
      m.writer_nonce=ISSX_PersistenceJson::ExtractString(json,"writer_nonce","");
      m.writer_generation=ISSX_PersistenceJson::ExtractLong(json,"writer_generation",0);
      m.trio_generation_id=ISSX_PersistenceJson::ExtractString(json,"trio_generation_id","");
      m.payload_hash=ISSX_PersistenceJson::ExtractString(json,"payload_hash","");
      m.header_hash=ISSX_PersistenceJson::ExtractString(json,"header_hash","");
      m.payload_length=(int)ISSX_PersistenceJson::ExtractLong(json,"payload_length",0);
      m.header_length=(int)ISSX_PersistenceJson::ExtractLong(json,"header_length",0);
      m.symbol_count=(int)ISSX_PersistenceJson::ExtractLong(json,"symbol_count",0);
      m.changed_symbol_count=(int)ISSX_PersistenceJson::ExtractLong(json,"changed_symbol_count",0);
      m.content_class=(ISSX_ContentClass)ISSX_PersistenceJson::ExtractLong(json,"content_class",(long)issx_content_empty);
      m.publish_reason=(ISSX_PublishReason)ISSX_PersistenceJson::ExtractLong(json,"publish_reason",(long)issx_publish_bootstrap);
      m.cohort_fingerprint=ISSX_PersistenceJson::ExtractString(json,"cohort_fingerprint","");
      m.taxonomy_hash=ISSX_PersistenceJson::ExtractString(json,"taxonomy_hash","");
      m.comparator_registry_hash=ISSX_PersistenceJson::ExtractString(json,"comparator_registry_hash","");
      m.policy_fingerprint=ISSX_PersistenceJson::ExtractString(json,"policy_fingerprint","");
      m.fingerprint_algorithm_version=(int)ISSX_PersistenceJson::ExtractLong(json,"fingerprint_algorithm_version",ISSX_FINGERPRINT_ALGO_VERSION);
      m.universe_fingerprint=ISSX_PersistenceJson::ExtractString(json,"universe_fingerprint","");
      m.compatibility_class=(ISSX_CompatibilityClass)ISSX_PersistenceJson::ExtractLong(json,"compatibility_class",(long)issx_compat_incompatible);
      m.contradiction_count=(int)ISSX_PersistenceJson::ExtractLong(json,"contradiction_count",0);
      m.contradiction_severity_max=(ISSX_ContradictionSeverity)ISSX_PersistenceJson::ExtractLong(json,"contradiction_severity_max",0);
      m.degraded_flag=ISSX_PersistenceJson::ExtractBool(json,"degraded_flag",false);
      m.fallback_depth_used=(int)ISSX_PersistenceJson::ExtractLong(json,"fallback_depth_used",0);
      m.accepted_strong_count=(int)ISSX_PersistenceJson::ExtractLong(json,"accepted_strong_count",0);
      m.accepted_degraded_count=(int)ISSX_PersistenceJson::ExtractLong(json,"accepted_degraded_count",0);
      m.rejected_count=(int)ISSX_PersistenceJson::ExtractLong(json,"rejected_count",0);
      m.cooldown_count=(int)ISSX_PersistenceJson::ExtractLong(json,"cooldown_count",0);
      m.stale_usable_count=(int)ISSX_PersistenceJson::ExtractLong(json,"stale_usable_count",0);
      m.projection_partial_success_flag=ISSX_PersistenceJson::ExtractBool(json,"projection_partial_success_flag",false);
      m.accepted_promotion_verified=ISSX_PersistenceJson::ExtractBool(json,"accepted_promotion_verified",false);
      m.stage_minimum_ready_flag=ISSX_PersistenceJson::ExtractBool(json,"stage_minimum_ready_flag",false);
      m.stage_publishability_state=(ISSX_PublishabilityState)ISSX_PersistenceJson::ExtractLong(json,"stage_publishability_state",0);
      m.handoff_mode=(ISSX_HandoffMode)ISSX_PersistenceJson::ExtractLong(json,"handoff_mode",(long)issx_handoff_none);
      m.handoff_sequence_no=ISSX_PersistenceJson::ExtractLong(json,"handoff_sequence_no",0);
      m.fallback_read_ratio_1h=ISSX_PersistenceJson::ExtractDouble(json,"fallback_read_ratio_1h",0.0);
      m.fresh_accept_ratio_1h=ISSX_PersistenceJson::ExtractDouble(json,"fresh_accept_ratio_1h",0.0);
      m.same_tick_handoff_ratio_1h=ISSX_PersistenceJson::ExtractDouble(json,"same_tick_handoff_ratio_1h",0.0);
      m.legend_hash=ISSX_PersistenceJson::ExtractString(json,"legend_hash","");
      return true;
     }

   static string HandoffRecordToJson(const ISSX_HandoffRecord &r)
     {
      ISSX_JsonWriter w;
      w.Reset();
      w.BeginObject();
      w.NameString("stage_id",ISSX_PersistEnum::StageToString(r.stage_id));
      w.NameString("firm_id",r.firm_id);
      w.NameInt("upstream_handoff_mode",(int)r.upstream_handoff_mode);
      w.NameInt("upstream_handoff_compatibility_class",(int)r.upstream_handoff_compatibility_class);
      w.NameBool("upstream_handoff_same_tick_flag",r.upstream_handoff_same_tick_flag);
      w.NameBool("upstream_partial_progress_flag",r.upstream_partial_progress_flag);
      w.NameInt("upstream_handoff_sequence_no",r.upstream_handoff_sequence_no);
      w.NameString("upstream_payload_hash",r.upstream_payload_hash);
      w.NameString("upstream_policy_fingerprint",r.upstream_policy_fingerprint);
      w.NameInt("writer_generation",r.writer_generation);
      w.NameString("trio_generation_id",r.trio_generation_id);
      w.NameInt("minute_id",r.minute_id);
      w.NameBool("accepted_promotion_verified",r.accepted_promotion_verified);
      w.EndObject();
      return w.ToString();
     }

   static bool JsonToHandoffRecord(const string json,ISSX_HandoffRecord &r)
     {
      r.Reset();
      r.stage_id=ISSX_PersistEnum::StageFromString(ISSX_PersistenceJson::ExtractString(json,"stage_id","shared"));
      r.firm_id=ISSX_PersistenceJson::ExtractString(json,"firm_id","");
      r.upstream_handoff_mode=(ISSX_HandoffMode)ISSX_PersistenceJson::ExtractLong(json,"upstream_handoff_mode",(long)issx_handoff_none);
      r.upstream_handoff_compatibility_class=(ISSX_CompatibilityClass)ISSX_PersistenceJson::ExtractLong(json,"upstream_handoff_compatibility_class",(long)issx_compat_incompatible);
      r.upstream_handoff_same_tick_flag=ISSX_PersistenceJson::ExtractBool(json,"upstream_handoff_same_tick_flag",false);
      r.upstream_partial_progress_flag=ISSX_PersistenceJson::ExtractBool(json,"upstream_partial_progress_flag",false);
      r.upstream_handoff_sequence_no=ISSX_PersistenceJson::ExtractLong(json,"upstream_handoff_sequence_no",0);
      r.upstream_payload_hash=ISSX_PersistenceJson::ExtractString(json,"upstream_payload_hash","");
      r.upstream_policy_fingerprint=ISSX_PersistenceJson::ExtractString(json,"upstream_policy_fingerprint","");
      r.writer_generation=ISSX_PersistenceJson::ExtractLong(json,"writer_generation",0);
      r.trio_generation_id=ISSX_PersistenceJson::ExtractString(json,"trio_generation_id","");
      r.minute_id=ISSX_PersistenceJson::ExtractLong(json,"minute_id",0);
      r.accepted_promotion_verified=ISSX_PersistenceJson::ExtractBool(json,"accepted_promotion_verified",false);
      return true;
     }

   static string LockToJson(const ISSX_LockLease &l)
     {
      ISSX_JsonWriter w;
      w.Reset();
      w.BeginObject();
      w.NameString("lock_owner_boot_id",l.lock_owner_boot_id);
      w.NameString("lock_owner_instance_guid",l.lock_owner_instance_guid);
      w.NameString("lock_owner_terminal_identity",l.lock_owner_terminal_identity);
      w.NameInt("lock_acquired_time",(long)l.lock_acquired_time);
      w.NameInt("lock_heartbeat_time",(long)l.lock_heartbeat_time);
      w.NameInt("stale_after_sec",l.stale_after_sec);
      w.EndObject();
      return w.ToString();
     }

   static bool JsonToLock(const string json,ISSX_LockLease &l)
     {
      l.Reset();
      l.lock_owner_boot_id=ISSX_PersistenceJson::ExtractString(json,"lock_owner_boot_id","");
      l.lock_owner_instance_guid=ISSX_PersistenceJson::ExtractString(json,"lock_owner_instance_guid","");
      l.lock_owner_terminal_identity=ISSX_PersistenceJson::ExtractString(json,"lock_owner_terminal_identity","");
      l.lock_acquired_time=(datetime)ISSX_PersistenceJson::ExtractLong(json,"lock_acquired_time",0);
      l.lock_heartbeat_time=(datetime)ISSX_PersistenceJson::ExtractLong(json,"lock_heartbeat_time",0);
      l.stale_after_sec=(int)ISSX_PersistenceJson::ExtractLong(json,"stale_after_sec",60);
      return true;
     }
  };

// ============================================================================
// SECTION 05: COHERENCE / COMPATIBILITY / ACCEPTANCE
// ============================================================================

class ISSX_Compatibility
  {
public:
   static ISSX_CompatibilityCheck Evaluate(const ISSX_Manifest &have,
                                           const ISSX_Manifest &need,
                                           const ISSX_StageHeader &header,
                                           const string payload_text,
                                           const int max_age_minutes=30)
     {
      ISSX_CompatibilityCheck c;
      c.Reset();

      c.firm_match=(have.firm_id==need.firm_id);
      c.stage_match=(have.stage_id==need.stage_id);
      c.schema_compatible=(have.schema_version==need.schema_version);
      c.schema_epoch_compatible=(have.schema_epoch==need.schema_epoch);
      c.storage_compatible=(have.storage_version==need.storage_version);
      c.policy_compatible=(ISSX_Util::IsEmpty(need.policy_fingerprint) || have.policy_fingerprint==need.policy_fingerprint);
      c.required_block_presence=(!ISSX_Util::IsEmpty(have.payload_hash) && !ISSX_Util::IsEmpty(have.header_hash));
      c.sequence_monotonic_sane=(have.sequence_no>0 && header.sequence_no==have.sequence_no && header.sequence_no>0);
      c.taxonomy_hash_compatible=(ISSX_Util::IsEmpty(need.taxonomy_hash) || have.taxonomy_hash==need.taxonomy_hash);
      c.comparator_registry_hash_compatible=(ISSX_Util::IsEmpty(need.comparator_registry_hash) || have.comparator_registry_hash==need.comparator_registry_hash);
      c.universe_fingerprint_compatible=(ISSX_Util::IsEmpty(need.universe_fingerprint) || have.universe_fingerprint==need.universe_fingerprint);
      c.symbol_continuity_compatible=(have.symbol_count>=0);
      c.freshness_fit=((need.minute_id<=0 || have.minute_id<=0) ? true : ((need.minute_id-have.minute_id)<=max_age_minutes));
      c.content_class_fit=(have.content_class>=issx_content_partial);
      c.generation_coherent=(header.writer_generation==have.writer_generation &&
                             header.sequence_no==have.sequence_no &&
                             header.trio_generation_id==have.trio_generation_id &&
                             header.payload_length==have.payload_length &&
                             header.header_length==have.header_length);
      c.header_payload_hash_match=(header.payload_hash==have.payload_hash &&
                                   header.header_hash==have.header_hash &&
                                   ISSX_Hash::HashStringHex(payload_text)==have.payload_hash &&
                                   header.payload_length==StringLen(payload_text));
      c.consumer_compatible=(c.schema_epoch_compatible && c.storage_compatible && c.policy_compatible);

      int score=0;
      if(c.firm_match) score+=10;
      if(c.stage_match) score+=10;
      if(c.schema_compatible) score+=8;
      if(c.schema_epoch_compatible) score+=10;
      if(c.storage_compatible) score+=10;
      if(c.policy_compatible) score+=10;
      if(c.required_block_presence) score+=8;
      if(c.sequence_monotonic_sane) score+=6;
      if(c.taxonomy_hash_compatible) score+=6;
      if(c.comparator_registry_hash_compatible) score+=6;
      if(c.universe_fingerprint_compatible) score+=6;
      if(c.symbol_continuity_compatible) score+=4;
      if(c.freshness_fit) score+=4;
      if(c.content_class_fit) score+=3;
      if(c.generation_coherent) score+=6;
      if(c.header_payload_hash_match) score+=3;
      c.compatibility_score=score;

      if(c.consumer_compatible && c.firm_match && c.stage_match && c.generation_coherent && c.header_payload_hash_match && c.freshness_fit)
         c.compatibility_class=issx_compat_exact;
      else if(c.schema_epoch_compatible && c.storage_compatible && c.firm_match && c.stage_match)
         c.compatibility_class=issx_compat_consumer_compatible;
      else if(c.schema_epoch_compatible && c.storage_compatible)
         c.compatibility_class=issx_compat_storage_compatible;
      else if(c.schema_compatible)
         c.compatibility_class=issx_compat_schema_only;
      else
         c.compatibility_class=issx_compat_incompatible;

      c.reason=IntegerToString(c.compatibility_score);
      return c;
     }
  };

class ISSX_Coherence
  {
public:
   static bool HeaderManifestAgree(const ISSX_StageHeader &header,const ISSX_Manifest &manifest)
     {
      return (header.stage_id==manifest.stage_id &&
              header.firm_id==manifest.firm_id &&
              header.schema_version==manifest.schema_version &&
              header.schema_epoch==manifest.schema_epoch &&
              header.storage_version==manifest.storage_version &&
              header.sequence_no==manifest.sequence_no &&
              header.writer_generation==manifest.writer_generation &&
              header.trio_generation_id==manifest.trio_generation_id &&
              header.payload_length==manifest.payload_length &&
              header.header_length==manifest.header_length &&
              header.payload_hash==manifest.payload_hash &&
              header.header_hash==manifest.header_hash);
     }

   static bool HeaderPayloadAgree(const ISSX_StageHeader &header,const string payload_text)
     {
      return (!ISSX_Util::IsEmpty(payload_text) &&
              header.payload_length==StringLen(payload_text) &&
              header.payload_hash==ISSX_Hash::HashStringHex(payload_text));
     }

   static bool CandidateTrioCoherent(const ISSX_StageHeader &header,const ISSX_Manifest &manifest,const string payload_text)
     {
      return (header.magic==ISSX_BINARY_MAGIC &&
              header.stage_id!=issx_stage_unknown &&
              !ISSX_Util::IsEmpty(header.firm_id) &&
              header.schema_epoch==ISSX_SCHEMA_EPOCH &&
              manifest.schema_epoch==ISSX_SCHEMA_EPOCH &&
              header.storage_version==ISSX_STORAGE_VERSION &&
              manifest.storage_version==ISSX_STORAGE_VERSION &&
              HeaderManifestAgree(header,manifest) &&
              HeaderPayloadAgree(header,payload_text));
     }

   static bool LastGoodCoherent(const ISSX_Manifest &manifest,const string payload_text)
     {
      return (!ISSX_Util::IsEmpty(manifest.firm_id) &&
              manifest.stage_id!=issx_stage_unknown &&
              manifest.schema_epoch==ISSX_SCHEMA_EPOCH &&
              manifest.storage_version==ISSX_STORAGE_VERSION &&
              !ISSX_Util::IsEmpty(payload_text) &&
              manifest.payload_length==StringLen(payload_text) &&
              manifest.payload_hash==ISSX_Hash::HashStringHex(payload_text));
     }
  };

class ISSX_Acceptance
  {
public:
   static bool StructuralAccept(const ISSX_StageHeader &header,
                                const ISSX_Manifest &manifest,
                                const string payload_text,
                                ISSX_AcceptanceResult &result)
     {
      result.Reset();
      result.accepted=false;
      result.acceptance_type=issx_acceptance_rejected;
      result.compatibility_class=issx_compat_incompatible;
      result.compatibility_score=0;
      result.reason="structural_rejected";

      if((header.stage_id==issx_stage_unknown) || header.stage_id!=manifest.stage_id)
        {
         result.error_code=ISSX_ACCEPTANCE_ERR_STAGE_MISMATCH;
         result.reason="stage_mismatch";
         return false;
        }

      if(ISSX_Util::IsEmpty(header.firm_id) || header.firm_id!=manifest.firm_id)
        {
         result.error_code=ISSX_ACCEPTANCE_ERR_FIRM_MISMATCH;
         result.reason="firm_mismatch";
         return false;
        }

      if(header.schema_version!=ISSX_SCHEMA_VERSION || manifest.schema_version!=ISSX_SCHEMA_VERSION)
        {
         result.error_code=ISSX_ACCEPTANCE_ERR_SCHEMA;
         result.reason="schema_version";
         return false;
        }

      if(header.schema_epoch!=ISSX_SCHEMA_EPOCH || manifest.schema_epoch!=ISSX_SCHEMA_EPOCH)
        {
         result.error_code=ISSX_ACCEPTANCE_ERR_SCHEMA;
         result.reason="schema_epoch";
         return false;
        }

      if(header.storage_version!=ISSX_STORAGE_VERSION || manifest.storage_version!=ISSX_STORAGE_VERSION)
        {
         result.error_code=ISSX_ACCEPTANCE_ERR_SCHEMA;
         result.reason="storage_version";
         return false;
        }

      if(ISSX_Util::IsEmpty(payload_text))
        {
         result.error_code=ISSX_ACCEPTANCE_ERR_INCOMPLETE;
         result.reason="empty_payload";
         return false;
        }

      if(!ISSX_Coherence::CandidateTrioCoherent(header,manifest,payload_text))
        {
         result.error_code=ISSX_ACCEPTANCE_ERR_MANIFEST;
         result.reason="generation_coherence";
         return false;
        }

      result.accepted=true;
      result.acceptance_type=(manifest.degraded_flag ? issx_acceptance_accepted_degraded : issx_acceptance_accepted_for_pipeline);
      result.error_code=ISSX_ACCEPTANCE_OK;
      result.reason="ok";
      result.compatibility_class=issx_compat_exact;
      result.compatibility_score=100;
      result.accepted_strong_count=manifest.accepted_strong_count;
      result.accepted_degraded_count=manifest.accepted_degraded_count;
      result.rejected_count=manifest.rejected_count;
      result.cooldown_count=manifest.cooldown_count;
      result.stale_usable_count=manifest.stale_usable_count;
      result.contradiction_count=manifest.contradiction_count;
      result.contradiction_severity_max=manifest.contradiction_severity_max;
      result.blocking_contradiction_present=(manifest.contradiction_severity_max>=issx_contradiction_blocking);
      return true;
     }
  };

// ============================================================================
// SECTION 06: SAME-TICK HANDOFF + SNAPSHOT FLOW
// ============================================================================

class ISSX_HandoffStore
  {
public:
   static bool WriteAccepted(const string firm_id,
                             const ISSX_StageId stage_id,
                             const ISSX_StageHeader &header,
                             const ISSX_Manifest &manifest,
                             const string payload_text)
     {
      if(!manifest.accepted_promotion_verified)
         return false;

      if(!ISSX_Coherence::CandidateTrioCoherent(header,manifest,payload_text))
         return false;

      ISSX_HandoffRecord r;
      r.Reset();
      r.stage_id=stage_id;
      r.firm_id=firm_id;
      r.upstream_handoff_mode=issx_handoff_same_tick_accepted;
      r.upstream_handoff_compatibility_class=issx_compat_exact;
      r.upstream_handoff_same_tick_flag=true;
      r.upstream_partial_progress_flag=false;
      r.upstream_handoff_sequence_no=manifest.sequence_no;
      r.upstream_payload_hash=manifest.payload_hash;
      r.upstream_policy_fingerprint=manifest.policy_fingerprint;
      r.writer_generation=manifest.writer_generation;
      r.trio_generation_id=manifest.trio_generation_id;
      r.minute_id=manifest.minute_id;
      r.accepted_promotion_verified=manifest.accepted_promotion_verified;

      bool ok=true;
      ok=ok && ISSX_FileIO::WriteText(ISSX_PersistencePath::HandoffHeaderFile(firm_id,stage_id),ISSX_PersistenceCodec::HeaderToJson(header));
      ok=ok && ISSX_FileIO::WriteText(ISSX_PersistencePath::HandoffManifestFile(firm_id,stage_id),ISSX_PersistenceCodec::ManifestToJson(manifest));
      ok=ok && ISSX_FileIO::WriteText(ISSX_PersistencePath::HandoffPayloadFile(firm_id,stage_id),payload_text);
      ok=ok && ISSX_FileIO::WriteText(ISSX_PersistencePath::HandoffRecordFile(firm_id,stage_id),ISSX_PersistenceCodec::HandoffRecordToJson(r));
      return ok;
     }

   static bool ReadAccepted(const string firm_id,
                            const ISSX_StageId stage_id,
                            ISSX_UpstreamReadOutcome &outcome)
     {
      outcome.Reset();

      string header_json="";
      string manifest_json="";
      string payload_text="";
      string record_json="";

      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::HandoffHeaderFile(firm_id,stage_id),header_json))
         return false;
      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::HandoffManifestFile(firm_id,stage_id),manifest_json))
         return false;
      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::HandoffPayloadFile(firm_id,stage_id),payload_text))
         return false;
      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::HandoffRecordFile(firm_id,stage_id),record_json))
         return false;

      ISSX_HandoffRecord r;
      r.Reset();

      ISSX_PersistenceCodec::JsonToHeader(header_json,outcome.header);
      ISSX_PersistenceCodec::JsonToManifest(manifest_json,outcome.manifest);
      ISSX_PersistenceCodec::JsonToHandoffRecord(record_json,r);
      outcome.payload_text=payload_text;

      if(!r.accepted_promotion_verified)
         return false;

      if(!ISSX_Coherence::CandidateTrioCoherent(outcome.header,outcome.manifest,outcome.payload_text))
         return false;

      outcome.found=true;
      outcome.upstream_source_used="same_tick_handoff";
      outcome.upstream_source_reason="accepted_same_tick_cache";
      outcome.upstream_handoff_mode=r.upstream_handoff_mode;
      outcome.upstream_compatibility_class=r.upstream_handoff_compatibility_class;
      outcome.upstream_compatibility_score=100;
      outcome.upstream_handoff_same_tick_flag=r.upstream_handoff_same_tick_flag;
      outcome.upstream_partial_progress_flag=r.upstream_partial_progress_flag;
      outcome.upstream_handoff_sequence_no=r.upstream_handoff_sequence_no;
      outcome.upstream_payload_hash=r.upstream_payload_hash;
      outcome.upstream_policy_fingerprint=r.upstream_policy_fingerprint;
      return true;
     }
  };

class ISSX_SnapshotFlow
  {
private:
   static bool RotateAcceptedToPrevious(const string hc,const string pc,const string mc,
                                        const string hp,const string pp,const string mp)
     {
      bool ok=true;

      if(ISSX_FileIO::Exists(hc))
         ok=ok && ISSX_FileIO::CopyText(hc,hp);
      if(ISSX_FileIO::Exists(pc))
         ok=ok && ISSX_FileIO::CopyText(pc,pp);
      if(ISSX_FileIO::Exists(mc))
         ok=ok && ISSX_FileIO::CopyText(mc,mp);

      return ok;
     }

public:
   static bool WriteCandidate(const string firm_id,
                              const ISSX_StageId stage_id,
                              ISSX_StageHeader &header,
                              const string payload_text,
                              ISSX_Manifest &manifest)
     {
      if(ISSX_Util::IsEmpty(firm_id))
         return false;
      if(stage_id==issx_stage_unknown)
         return false;
      if(ISSX_Util::IsEmpty(payload_text))
         return false;

      if(!ISSX_FileIO::EnsureFolder(ISSX_PersistencePath::FirmRoot(firm_id)))
         return false;
      if(!ISSX_FileIO::EnsureFolder(ISSX_PersistencePath::InternalDir(firm_id,stage_id)))
         return false;

      header.firm_id=firm_id;
      header.stage_id=stage_id;
      header.schema_version=ISSX_SCHEMA_VERSION;
      header.schema_epoch=ISSX_SCHEMA_EPOCH;
      header.storage_version=ISSX_STORAGE_VERSION;
      header.payload_length=StringLen(payload_text);
      header.record_size_or_payload_length=header.payload_length;
      header.payload_hash=ISSX_Hash::HashStringHex(payload_text);

      string header_json_preview=ISSX_PersistenceCodec::HeaderToJson(header);
      header.header_length=StringLen(header_json_preview);
      header.header_hash=ISSX_Hash::HashStringHex(header_json_preview);

      manifest.stage_id=stage_id;
      manifest.firm_id=firm_id;
      manifest.schema_version=ISSX_SCHEMA_VERSION;
      manifest.schema_epoch=ISSX_SCHEMA_EPOCH;
      manifest.storage_version=ISSX_STORAGE_VERSION;
      manifest.writer_generation=header.writer_generation;
      manifest.sequence_no=header.sequence_no;
      manifest.minute_id=header.minute_id;
      manifest.writer_boot_id=header.writer_boot_id;
      manifest.writer_nonce=header.writer_nonce;
      manifest.trio_generation_id=header.trio_generation_id;
      manifest.payload_hash=header.payload_hash;
      manifest.header_hash=header.header_hash;
      manifest.payload_length=header.payload_length;
      manifest.header_length=header.header_length;
      manifest.symbol_count=header.symbol_count;
      manifest.changed_symbol_count=header.changed_symbol_count;
      manifest.cohort_fingerprint=header.cohort_fingerprint;
      manifest.universe_fingerprint=header.universe_fingerprint;
      manifest.policy_fingerprint=header.policy_fingerprint;
      manifest.fingerprint_algorithm_version=header.fingerprint_algorithm_version;
      manifest.contradiction_count=header.contradiction_count;
      manifest.contradiction_severity_max=header.contradiction_severity_max;
      manifest.degraded_flag=header.degraded_flag;
      manifest.fallback_depth_used=header.fallback_depth_used;

      string header_json=ISSX_PersistenceCodec::HeaderToJson(header);
      manifest.header_hash=ISSX_Hash::HashStringHex(header_json);
      header.header_hash=manifest.header_hash;
      manifest.header_length=StringLen(header_json);
      header.header_length=manifest.header_length;

      header_json=ISSX_PersistenceCodec::HeaderToJson(header);
      const string manifest_json=ISSX_PersistenceCodec::ManifestToJson(manifest);

      bool ok=true;
      ok=ok && ISSX_FileIO::WriteText(ISSX_PersistencePath::HeaderCandidate(firm_id,stage_id),header_json);
      ok=ok && ISSX_FileIO::WriteText(ISSX_PersistencePath::PayloadCandidate(firm_id,stage_id),payload_text);
      ok=ok && ISSX_FileIO::WriteText(ISSX_PersistencePath::ManifestCandidate(firm_id,stage_id),manifest_json);
      if(!ok)
         return false;

      ISSX_StageHeader verify_header;
      ISSX_Manifest verify_manifest;
      string verify_payload="";
      verify_header.Reset();
      verify_manifest.Reset();
      if(!LoadCandidate(firm_id,stage_id,verify_header,verify_manifest,verify_payload))
         return false;

      return ISSX_Coherence::CandidateTrioCoherent(verify_header,verify_manifest,verify_payload);
     }

   static bool LoadCandidate(const string firm_id,
                             const ISSX_StageId stage_id,
                             ISSX_StageHeader &header,
                             ISSX_Manifest &manifest,
                             string &payload_text)
     {
      string h="";
      string m="";
      string p="";

      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::HeaderCandidate(firm_id,stage_id),h))
         return false;
      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::ManifestCandidate(firm_id,stage_id),m))
         return false;
      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::PayloadCandidate(firm_id,stage_id),p))
         return false;

      ISSX_PersistenceCodec::JsonToHeader(h,header);
      ISSX_PersistenceCodec::JsonToManifest(m,manifest);
      payload_text=p;
      return true;
     }

   static bool PromoteCandidate(const string firm_id,
                                const ISSX_StageId stage_id,
                                ISSX_Manifest &manifest,
                                ISSX_ProjectionOutcome &outcome)
     {
      outcome.Reset();

      ISSX_StageHeader candidate_header;
      ISSX_Manifest candidate_manifest;
      string candidate_payload="";

      candidate_header.Reset();
      candidate_manifest.Reset();

      if(!LoadCandidate(firm_id,stage_id,candidate_header,candidate_manifest,candidate_payload))
        {
         outcome.last_projection_reason="candidate_missing";
         return false;
        }

      if(!ISSX_Coherence::CandidateTrioCoherent(candidate_header,candidate_manifest,candidate_payload))
        {
         outcome.last_projection_reason="candidate_incoherent";
         return false;
        }

      const string hc=ISSX_PersistencePath::HeaderCurrent(firm_id,stage_id);
      const string pc=ISSX_PersistencePath::PayloadCurrent(firm_id,stage_id);
      const string mc=ISSX_PersistencePath::ManifestCurrent(firm_id,stage_id);
      const string hp=ISSX_PersistencePath::HeaderPrevious(firm_id,stage_id);
      const string pp=ISSX_PersistencePath::PayloadPrevious(firm_id,stage_id);
      const string mp=ISSX_PersistencePath::ManifestPrevious(firm_id,stage_id);
      const string hcand=ISSX_PersistencePath::HeaderCandidate(firm_id,stage_id);
      const string pcand=ISSX_PersistencePath::PayloadCandidate(firm_id,stage_id);
      const string mcand=ISSX_PersistencePath::ManifestCandidate(firm_id,stage_id);

      if(!RotateAcceptedToPrevious(hc,pc,mc,hp,pp,mp))
        {
         outcome.last_projection_reason="rotate_previous_failed";
         return false;
        }

      bool ok=true;
      ok=ok && ISSX_FileIO::CopyText(hcand,hc);
      ok=ok && ISSX_FileIO::CopyText(pcand,pc);
      ok=ok && ISSX_FileIO::CopyText(mcand,mc);

      ISSX_StageHeader verify_header;
      ISSX_Manifest verify_manifest;
      string verify_payload="";

      verify_header.Reset();
      verify_manifest.Reset();

      if(ok)
        {
         string h="";
         string m="";
         string p="";

         ok=ok && ISSX_FileIO::ReadText(hc,h);
         ok=ok && ISSX_FileIO::ReadText(mc,m);
         ok=ok && ISSX_FileIO::ReadText(pc,p);

         if(ok)
           {
            ISSX_PersistenceCodec::JsonToHeader(h,verify_header);
            ISSX_PersistenceCodec::JsonToManifest(m,verify_manifest);
            verify_payload=p;
            ok=ok && ISSX_Coherence::CandidateTrioCoherent(verify_header,verify_manifest,verify_payload);
           }
        }

      manifest=verify_manifest;
      manifest.accepted_promotion_verified=ok;

      if(ok)
         ok=ok && ISSX_FileIO::WriteText(mc,ISSX_PersistenceCodec::ManifestToJson(manifest));

      outcome.internal_commit_success=ok;
      outcome.last_projection_reason=(ok ? "ok" : ISSX_ErrorToString(ISSX_ERR_FILE_WRITE));

      if(ok)
         ok=ok && ISSX_HandoffStore::WriteAccepted(firm_id,stage_id,verify_header,manifest,verify_payload);

      outcome.internal_commit_success=ok;
      if(!ok)
         outcome.last_projection_reason=ISSX_ErrorToString(ISSX_ERR_FILE_WRITE);

      return ok;
     }

   static bool PromoteLastGoodIfEligible(const string firm_id,
                                         const ISSX_StageId stage_id,
                                         const ISSX_Manifest &manifest)
     {
      if(manifest.accepted_strong_count<=0 && !manifest.stage_minimum_ready_flag)
         return false;

      const string pc=ISSX_PersistencePath::PayloadCurrent(firm_id,stage_id);
      const string mc=ISSX_PersistencePath::ManifestCurrent(firm_id,stage_id);
      const string pl=ISSX_PersistencePath::PayloadLastGood(firm_id,stage_id);
      const string ml=ISSX_PersistencePath::ManifestLastGood(firm_id,stage_id);

      bool ok=true;
      ok=ok && ISSX_FileIO::CopyText(pc,pl);
      ok=ok && ISSX_FileIO::CopyText(mc,ml);
      return ok;
     }
  };

// ============================================================================
// SECTION 07: ROOT PROJECTION DISCIPLINE
// ============================================================================

class ISSX_RootProjection
  {
public:
   static bool ProjectRootView(const string firm_id,const string target_file,const string payload_text)
     {
      return ISSX_FileIO::WriteTextIfChanged(ISSX_PersistencePath::RootFile(firm_id,target_file),payload_text);
     }

   static bool ProjectFromAccepted(const string firm_id,
                                   const string export_payload,
                                   const string debug_payload,
                                   const string stage_status_payload,
                                   const string universe_snapshot_payload,
                                   ISSX_ProjectionOutcome &outcome)
     {
      bool export_ok=true;
      bool debug_ok=true;
      bool status_ok=true;
      bool universe_ok=true;

      if(!ISSX_Util::IsEmpty(export_payload))
         export_ok=ProjectRootView(firm_id,ISSX_ROOT_EXPORT,export_payload);
      if(!ISSX_Util::IsEmpty(debug_payload))
         debug_ok=ProjectRootView(firm_id,ISSX_ROOT_DEBUG,debug_payload);
      if(!ISSX_Util::IsEmpty(stage_status_payload))
         status_ok=ProjectRootView(firm_id,ISSX_ROOT_STAGE_STATUS,stage_status_payload);
      if(!ISSX_Util::IsEmpty(universe_snapshot_payload))
         universe_ok=ProjectRootView(firm_id,ISSX_ROOT_UNIVERSE_SNAPSHOT,universe_snapshot_payload);

      outcome.root_stage_projection_success=export_ok;
      outcome.root_debug_projection_success=debug_ok;
      outcome.root_status_projection_success=status_ok;
      outcome.root_universe_snapshot_success=universe_ok;
      outcome.projection_partial_success_flag=(outcome.internal_commit_success && (!export_ok || !debug_ok || !status_ok || !universe_ok));

      outcome.debug_projection_fail_count=0;
      if(!debug_ok)
         outcome.debug_projection_fail_count++;

      if(outcome.projection_partial_success_flag)
         outcome.last_projection_reason="partial_projection";
      else if(export_ok && debug_ok && status_ok && universe_ok)
         outcome.last_projection_reason="ok";
      else
         outcome.last_projection_reason="projection_failed";

      return (export_ok && debug_ok && status_ok && universe_ok);
     }
  };

// ============================================================================
// SECTION 08: FALLBACK READ ORDER / VISIBILITY
// ============================================================================

class ISSX_FallbackReader
  {
private:
   static bool ReadSnapshotAt(const string firm_id,
                              const ISSX_StageId stage_id,
                              const string header_name,
                              const string payload_name,
                              const string manifest_name,
                              ISSX_UpstreamReadOutcome &outcome)
     {
      string h="";
      string m="";
      string p="";

      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::InternalFile(firm_id,stage_id,header_name),h))
         return false;
      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::InternalFile(firm_id,stage_id,payload_name),p))
         return false;
      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::InternalFile(firm_id,stage_id,manifest_name),m))
         return false;

      ISSX_PersistenceCodec::JsonToHeader(h,outcome.header);
      ISSX_PersistenceCodec::JsonToManifest(m,outcome.manifest);
      outcome.payload_text=p;

      if(!ISSX_Coherence::CandidateTrioCoherent(outcome.header,outcome.manifest,outcome.payload_text))
         return false;

      return true;
     }

public:
   static bool ReadBestAvailable(const string firm_id,
                                 const ISSX_StageId stage_id,
                                 ISSX_UpstreamReadOutcome &outcome)
     {
      outcome.Reset();

      if(ISSX_HandoffStore::ReadAccepted(firm_id,stage_id,outcome))
        {
         outcome.fallback_depth_used=0;
         outcome.fallback_penalty_applied=0.0;
         return true;
        }

      if(ReadSnapshotAt(firm_id,stage_id,ISSX_BIN_HEADER_CURRENT,ISSX_BIN_PAYLOAD_CURRENT,ISSX_JSON_MANIFEST_CURRENT,outcome))
        {
         outcome.found=true;
         outcome.upstream_source_used="internal_current";
         outcome.upstream_source_reason="authoritative_internal_current";
         outcome.upstream_handoff_mode=issx_handoff_internal_current;
         outcome.upstream_compatibility_class=issx_compat_exact;
         outcome.upstream_compatibility_score=95;
         outcome.fallback_depth_used=1;
         outcome.upstream_handoff_sequence_no=outcome.manifest.sequence_no;
         outcome.upstream_payload_hash=outcome.manifest.payload_hash;
         outcome.upstream_policy_fingerprint=outcome.manifest.policy_fingerprint;
         return true;
        }

      if(ReadSnapshotAt(firm_id,stage_id,ISSX_BIN_HEADER_PREVIOUS,ISSX_BIN_PAYLOAD_PREVIOUS,ISSX_JSON_MANIFEST_PREVIOUS,outcome))
        {
         outcome.found=true;
         outcome.upstream_source_used="internal_previous";
         outcome.upstream_source_reason="rollback_previous";
         outcome.upstream_handoff_mode=issx_handoff_internal_previous;
         outcome.upstream_compatibility_class=issx_compat_consumer_compatible;
         outcome.upstream_compatibility_score=70;
         outcome.fallback_depth_used=2;
         outcome.fallback_penalty_applied=0.15;
         outcome.upstream_handoff_sequence_no=outcome.manifest.sequence_no;
         outcome.upstream_payload_hash=outcome.manifest.payload_hash;
         outcome.upstream_policy_fingerprint=outcome.manifest.policy_fingerprint;
         return true;
        }

      string manifest_lastgood_json="";
      string payload_lastgood="";

      if(ISSX_FileIO::ReadText(ISSX_PersistencePath::ManifestLastGood(firm_id,stage_id),manifest_lastgood_json) &&
         ISSX_FileIO::ReadText(ISSX_PersistencePath::PayloadLastGood(firm_id,stage_id),payload_lastgood))
        {
         outcome.manifest.Reset();
         outcome.header.Reset();
         ISSX_PersistenceCodec::JsonToManifest(manifest_lastgood_json,outcome.manifest);
         outcome.payload_text=payload_lastgood;

         if(ISSX_Coherence::LastGoodCoherent(outcome.manifest,outcome.payload_text) &&
            (outcome.manifest.accepted_promotion_verified || outcome.manifest.stage_minimum_ready_flag))
           {
            outcome.found=true;
            outcome.upstream_source_used="internal_last_good";
            outcome.upstream_source_reason="clean_fallback";
            outcome.upstream_handoff_mode=issx_handoff_internal_last_good;
            outcome.upstream_compatibility_class=issx_compat_policy_degraded;
            outcome.upstream_compatibility_score=55;
            outcome.fallback_depth_used=3;
            outcome.fallback_penalty_applied=0.25;
            outcome.upstream_handoff_sequence_no=outcome.manifest.sequence_no;
            outcome.upstream_payload_hash=outcome.manifest.payload_hash;
            outcome.upstream_policy_fingerprint=outcome.manifest.policy_fingerprint;
            return true;
           }
        }

      string root_text="";
      if(ISSX_FileIO::ReadText(ISSX_PersistencePath::RootExport(firm_id),root_text))
        {
         outcome.found=true;
         outcome.upstream_source_used="public_root";
         outcome.upstream_source_reason="diagnostic_projection_only";
         outcome.upstream_handoff_mode=issx_handoff_public_projection;
         outcome.upstream_compatibility_class=issx_compat_schema_only;
         outcome.upstream_compatibility_score=30;
         outcome.fallback_depth_used=4;
         outcome.fallback_penalty_applied=0.35;
         outcome.payload_text=root_text;
         return true;
        }

      outcome.upstream_source_used="fail_honest";
      outcome.upstream_source_reason="no_recoverable_source";
      return false;
     }
  };

// ============================================================================
// SECTION 09: LOCKS / SHARDS / DUMPS / WAREHOUSE
// ============================================================================

class ISSX_LockHelper
  {
public:
   static bool Read(const string firm_id,ISSX_LockLease &lock_state)
     {
      lock_state.Reset();

      string json="";
      if(!ISSX_FileIO::ReadText(ISSX_PersistencePath::LockFile(firm_id),json))
         return false;

      return ISSX_PersistenceCodec::JsonToLock(json,lock_state);
     }

   static bool IsStale(const ISSX_LockLease &lock_state,const datetime now_ts=0)
     {
      const datetime nowv=(now_ts>0 ? now_ts : ISSX_Time::BestScheduleClock());
      if(lock_state.lock_heartbeat_time<=0)
         return true;

      const int ttl=MathMax(1,lock_state.stale_after_sec);
      return ((int)(nowv-lock_state.lock_heartbeat_time)>ttl);
     }

   static bool Acquire(const string firm_id,
                       const string boot_id,
                       const string instance_guid,
                       const string terminal_identity,
                       const int stale_after_sec,
                       ISSX_LockLease &out_lock)
     {
      out_lock.Reset();

      ISSX_LockLease existing;
      existing.Reset();
      const bool has_existing=Read(firm_id,existing);

      if(has_existing && !IsStale(existing) &&
         (existing.lock_owner_boot_id!=boot_id ||
          existing.lock_owner_instance_guid!=instance_guid))
         return false;

      out_lock.lock_owner_boot_id=boot_id;
      out_lock.lock_owner_instance_guid=instance_guid;
      out_lock.lock_owner_terminal_identity=terminal_identity;
      out_lock.lock_acquired_time=ISSX_Time::BestScheduleClock();
      out_lock.lock_heartbeat_time=out_lock.lock_acquired_time;
      out_lock.stale_after_sec=MathMax(1,stale_after_sec);

      return ISSX_FileIO::WriteText(ISSX_PersistencePath::LockFile(firm_id),ISSX_PersistenceCodec::LockToJson(out_lock));
     }

   static bool Heartbeat(const string firm_id,ISSX_LockLease &lock_state)
     {
      lock_state.lock_heartbeat_time=ISSX_Time::BestScheduleClock();
      return ISSX_FileIO::WriteText(ISSX_PersistencePath::LockFile(firm_id),ISSX_PersistenceCodec::LockToJson(lock_state));
     }

   static bool Release(const string firm_id,const ISSX_LockLease &lock_state)
     {
      ISSX_LockLease existing;
      existing.Reset();

      if(Read(firm_id,existing))
        {
         if(existing.lock_owner_boot_id!=lock_state.lock_owner_boot_id ||
            existing.lock_owner_instance_guid!=lock_state.lock_owner_instance_guid)
            return false;
        }

      return ISSX_FileIO::DeleteIfExists(ISSX_PersistencePath::LockFile(firm_id));
     }
  };

class ISSX_BrokerUniverseDump
  {
public:
   static bool WriteCurrent(const string firm_id,const string payload_text,const ISSX_Manifest &manifest,const bool write_snapshot=false)
     {
      if(!ISSX_FileIO::EnsureFolder(ISSX_PersistencePath::UniverseDir(firm_id)))
         return false;

      const string dir=ISSX_PersistencePath::UniverseDir(firm_id);
      bool ok=true;

      ok=ok && ISSX_FileIO::WriteText(ISSX_Util::JoinPath(dir,ISSX_BIN_BROKER_UNIVERSE_CURRENT),payload_text);
      ok=ok && ISSX_FileIO::WriteText(ISSX_Util::JoinPath(dir,ISSX_JSON_BROKER_UNIVERSE_MANIFEST),ISSX_PersistenceCodec::ManifestToJson(manifest));

      if(write_snapshot)
         ok=ok && ISSX_FileIO::WriteText(ISSX_Util::JoinPath(dir,ISSX_JSON_BROKER_UNIVERSE_SNAPSHOT),payload_text);

      return ok;
     }

   static bool RotateCurrentToPrevious(const string firm_id)
     {
      const string dir=ISSX_PersistencePath::UniverseDir(firm_id);
      const string current=ISSX_Util::JoinPath(dir,ISSX_BIN_BROKER_UNIVERSE_CURRENT);
      const string previous=ISSX_Util::JoinPath(dir,ISSX_BIN_BROKER_UNIVERSE_PREVIOUS);

      return (!ISSX_FileIO::Exists(current) || ISSX_FileIO::CopyText(current,previous));
     }
  };

class ISSX_HistoryWarehouse
  {
public:
   static bool WriteShard(const string firm_id,const string tf,const string symbol,const string shard_payload)
     {
      return ISSX_FileIO::WriteText(ISSX_PersistencePath::HistoryShard(firm_id,tf,symbol),shard_payload);
     }

   static bool ReadShard(const string firm_id,const string tf,const string symbol,string &shard_payload)
     {
      return ISSX_FileIO::ReadText(ISSX_PersistencePath::HistoryShard(firm_id,tf,symbol),shard_payload);
     }

   static bool WriteIndexFile(const string firm_id,const string filename,const string payload)
     {
      return ISSX_FileIO::WriteText(ISSX_Util::JoinPath(ISSX_PersistencePath::HistoryIndexDir(firm_id),filename),payload);
     }

   static bool TouchRegistry(const string firm_id,
                             const string symbol_registry_payload,
                             const string timeframe_index_payload,
                             const string hydration_cursor_payload,
                             const string dirty_set_payload,
                             const string manifest_payload)
     {
      bool ok=true;
      ok=ok && WriteIndexFile(firm_id,ISSX_BIN_HISTORY_SYMBOL_REGISTRY,symbol_registry_payload);
      ok=ok && WriteIndexFile(firm_id,ISSX_BIN_HISTORY_TIMEFRAME_INDEX,timeframe_index_payload);
      ok=ok && WriteIndexFile(firm_id,ISSX_BIN_HISTORY_HYDRATION_CURSOR,hydration_cursor_payload);

      if(!ISSX_Util::IsEmpty(dirty_set_payload))
         ok=ok && WriteIndexFile(firm_id,ISSX_BIN_HISTORY_DIRTY_SET,dirty_set_payload);

      ok=ok && WriteIndexFile(firm_id,ISSX_JSON_BAR_STORE_MANIFEST,manifest_payload);
      return ok;
     }
  };

class ISSX_DirtyShardHelper
  {
private:
   static bool ContainsShardKey(const string csv,const string shard_key)
     {
      if(ISSX_Util::IsEmpty(csv) || ISSX_Util::IsEmpty(shard_key))
         return false;

      const string hay=","+csv+",";
      const string needle=","+shard_key+",";
      return (StringFind(hay,needle,0)>=0);
     }

public:
   static bool MarkDirty(ISSX_DirtyShardBatch &batch,const string shard_key,const long minute_id)
     {
      if(ISSX_Util::IsEmpty(shard_key))
         return false;

      if(!ContainsShardKey(batch.shard_keys_csv,shard_key))
        {
         batch.shard_keys_csv=(ISSX_Util::IsEmpty(batch.shard_keys_csv) ? shard_key : batch.shard_keys_csv+","+shard_key);
         batch.dirty_count++;
        }

      batch.touched_minute_id=minute_id;
      batch.flush_required=(batch.dirty_count>0);
      return true;
     }

   static bool Flush(const string firm_id,ISSX_DirtyShardBatch &batch)
     {
      if(!batch.flush_required)
         return true;

      const bool ok=ISSX_FileIO::WriteText(
         ISSX_Util::JoinPath(ISSX_PersistencePath::HistoryIndexDir(firm_id),ISSX_BIN_HISTORY_DIRTY_SET),
         batch.shard_keys_csv
      );

      if(ok)
         batch.Reset();

      return ok;
     }
  };

// ============================================================================
// SECTION 10: DISCIPLINE HELPERS / VALIDATORS
// ============================================================================

class ISSX_PersistenceDiscipline
  {
public:
   static bool ValidateCandidateTrioPresence(const string firm_id,const ISSX_StageId stage_id)
     {
      return ISSX_FileIO::Exists(ISSX_PersistencePath::HeaderCandidate(firm_id,stage_id)) &&
             ISSX_FileIO::Exists(ISSX_PersistencePath::PayloadCandidate(firm_id,stage_id)) &&
             ISSX_FileIO::Exists(ISSX_PersistencePath::ManifestCandidate(firm_id,stage_id));
     }

   static bool ValidateGenerationCoherence(const string firm_id,const ISSX_StageId stage_id)
     {
      ISSX_StageHeader h;
      ISSX_Manifest m;
      string p="";

      h.Reset();
      m.Reset();

      if(!ISSX_SnapshotFlow::LoadCandidate(firm_id,stage_id,h,m,p))
         return false;

      return ISSX_Coherence::CandidateTrioCoherent(h,m,p);
     }

   static bool ValidateAcceptedCurrent(const string firm_id,const ISSX_StageId stage_id)
     {
      ISSX_UpstreamReadOutcome outcome;
      outcome.Reset();

      return ISSX_FallbackReader::ReadBestAvailable(firm_id,stage_id,outcome) &&
             outcome.found &&
             (outcome.upstream_source_used=="same_tick_handoff" || outcome.upstream_source_used=="internal_current");
     }

   static bool AcceptedPromotionVerified(const ISSX_Manifest &manifest)
     {
      return manifest.accepted_promotion_verified;
     }
  };



string ISSX_PersistenceDiagTag()
  {
   return "persistence_diag_v174g";
  }


string ISSX_PersistenceDebugSignature()
  {
   return ISSX_PersistenceDiagTag();
  }

#endif // __ISSX_PERSISTENCE_MQH__
