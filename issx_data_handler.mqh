#ifndef __ISSX_DATA_HANDLER_MQH__
#define __ISSX_DATA_HANDLER_MQH__

#include <ISSX/issx_core.mqh>

// ============================================================================
// ISSX DATA HANDLER v1.731
// Shared JSON/payload/file-commit safety layer for ISSX stages.
// ============================================================================

#define ISSX_DATA_HANDLER_MODULE_VERSION "1.731"
#define ISSX_DATA_HANDLER_MAX_PAYLOAD_BYTES 7864320
#define ISSX_DATA_HANDLER_WRITE_RETRY_MAX   3

namespace ISSX_DataHandler
  {
   bool IsSafeRelativePath(const string relative_path)
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

   string BuildTempPath(const string relative_path,const int attempt)
     {
      return relative_path+".tmp."+IntegerToString((int)GetTickCount())+"."+IntegerToString(attempt);
     }

   bool EnsureParentFolder(const string relative_file_path)
     {
      const int sep1=StringFind(relative_file_path,"\\",0);
      const int sep2=StringFind(relative_file_path,"/",0);
      if(sep1<0 && sep2<0)
         return true;

      string path=relative_file_path;
      StringReplace(path,"/","\\");
      string parts[];
      const int n=StringSplit(path,(ushort)StringGetCharacter("\\",0),parts);
      if(n<=1)
         return true;

      string build="";
      for(int i=0;i<n-1;i++)
        {
         if(ISSX_Util::IsEmpty(parts[i]))
            continue;

         build=(ISSX_Util::IsEmpty(build) ? parts[i] : build+"\\"+parts[i]);
         FolderCreate(build,FILE_COMMON);
        }

      return true;
     }

   bool VerifyFinalPayload(const string relative_path,const int expected_utf8_bytes)
     {
      ResetLastError();
      const int h=FileOpen(relative_path,FILE_READ|FILE_BIN|FILE_COMMON);
      if(h==INVALID_HANDLE)
         return false;

      const ulong sz=FileSize(h);
      FileClose(h);

      if(expected_utf8_bytes<=0)
         return (sz==0);

      return ((int)sz==expected_utf8_bytes);
     }

   struct ForensicState
     {
      string checkpoint;
      string last_error;
      string symbol;
      string last_serialized_symbol;
      string last_successful_symbol;
      string temp_path;
      string final_path;
      int    payload_bytes_attempted;
      int    payload_bytes_written;
      int    open_error;
      int    write_error;
      int    move_error;
      int    copy_error;
      int    delete_error;

      void Reset()
        {
         checkpoint="idle";
         last_error="none";
         symbol="";
         last_serialized_symbol="";
         last_successful_symbol="";
         temp_path="";
         final_path="";
         payload_bytes_attempted=0;
         payload_bytes_written=0;
         open_error=0;
         write_error=0;
         move_error=0;
         copy_error=0;
         delete_error=0;
        }
     };

   struct Envelope
     {
      string stage_name;
      string schema_version;
      string payload;

      void Reset()
        {
         stage_name="";
         schema_version="";
         payload="";
        }
     };

   int EstimateUtf8Bytes(const string text)
     {
      uchar bytes[];
      const int n=StringToCharArray(text,bytes,0,-1,CP_UTF8);
      if(n<=0)
         return 0;
      return MathMax(0,n-1);
     }

   void JsonBuildStart(ForensicState &io_state,const string checkpoint)
     {
      io_state.checkpoint=checkpoint;
      io_state.last_error="none";
      io_state.payload_bytes_attempted=0;
      io_state.payload_bytes_written=0;
     }

   void JsonBuildComplete(ForensicState &io_state,const string payload,const string checkpoint)
     {
      io_state.checkpoint=checkpoint;
      io_state.payload_bytes_attempted=EstimateUtf8Bytes(payload);
      io_state.payload_bytes_written=io_state.payload_bytes_attempted;
      io_state.last_error="none";
     }

   void JsonSymbolSerializeStart(ForensicState &io_state,const string symbol)
     {
      io_state.checkpoint="json_symbol_serialize_start";
      io_state.symbol=symbol;
      io_state.last_serialized_symbol=symbol;
     }

   void JsonSymbolSerializeComplete(ForensicState &io_state,const string symbol)
     {
      io_state.checkpoint="json_symbol_serialize_complete";
      io_state.symbol=symbol;
      io_state.last_successful_symbol=symbol;
     }

   void JsonFail(ForensicState &io_state,const string checkpoint,const string reason,const int err)
     {
      io_state.checkpoint=checkpoint;
      io_state.last_error=reason;
      if(err!=0)
         io_state.write_error=err;
     }

   string EscapeJson(const string s,bool &out_ok)
     {
      out_ok=true;
      return ISSX_Util::EscapeJson(s);
     }

   string JsonStringField(const string name,const string value)
     {
      return ISSX_JsonWriter::NameStringKV(name,value);
     }

   string JsonLongField(const string name,const long value)
     {
      return ISSX_JsonWriter::NameLongKV(name,value);
     }

   string JsonDoubleField(const string name,const double value,const int digits=ISSX_JSON_DOUBLE_DIGITS_DEFAULT)
     {
      return ISSX_JsonWriter::NameDoubleKV(name,value,digits);
     }

   string JsonBoolField(const string name,const bool value)
     {
      return ISSX_JsonWriter::NameBoolKV(name,value);
     }

   bool WritePayloadAtomic(const string relative_path,
                                  const string payload,
                                  ForensicState &io_state,
                                  const bool allow_copy_fallback=true)
     {
      io_state.final_path=relative_path;
      io_state.payload_bytes_attempted=EstimateUtf8Bytes(payload);
      io_state.payload_bytes_written=0;

      if(!IsSafeRelativePath(relative_path))
        {
         JsonFail(io_state,"json_fail","unsafe_relative_path",0);
         return false;
        }

      if(io_state.payload_bytes_attempted>ISSX_DATA_HANDLER_MAX_PAYLOAD_BYTES)
        {
         JsonFail(io_state,"json_fail","payload_too_large",0);
         return false;
        }

      if(!EnsureParentFolder(relative_path))
        {
         JsonFail(io_state,"json_fail","parent_folder_create_failed",0);
         return false;
        }

      uchar payload_bytes[];
      int payload_encoded=StringToCharArray(payload,payload_bytes,0,-1,CP_UTF8);
      if(payload_encoded<0)
         payload_encoded=0;
      const int wanted=MathMax(0,payload_encoded-1);

      const int attempts=MathMax(1,ISSX_DATA_HANDLER_WRITE_RETRY_MAX);
      for(int attempt=1;attempt<=attempts;attempt++)
        {
         io_state.temp_path=BuildTempPath(relative_path,attempt);

         io_state.checkpoint="json_write_tmp_start";
         ResetLastError();
         const int h=FileOpen(io_state.temp_path,
                              FILE_WRITE|FILE_BIN|FILE_COMMON);
         io_state.open_error=GetLastError();
         if(h==INVALID_HANDLE)
           {
            if(attempt==attempts)
              {
               JsonFail(io_state,"json_fail","tmp_open_failed",io_state.open_error);
               return false;
              }
            continue;
           }

         ResetLastError();
         const uint written=(wanted>0 ? FileWriteArray(h,payload_bytes,0,wanted) : 0);
         io_state.write_error=GetLastError();

         ResetLastError();
         FileFlush(h);
         const int flush_error=GetLastError();
         FileClose(h);

         if(((int)written!=wanted) || io_state.write_error!=0 || flush_error!=0)
           {
            ResetLastError();
            FileDelete(io_state.temp_path,FILE_COMMON);
            io_state.delete_error=GetLastError();
            if(attempt==attempts)
              {
               JsonFail(io_state,"json_fail","tmp_write_or_flush_failed",(io_state.write_error!=0?io_state.write_error:flush_error));
               return false;
              }
            continue;
           }

         io_state.payload_bytes_written=EstimateUtf8Bytes(payload);
         io_state.checkpoint="json_write_tmp_complete";

         io_state.checkpoint="json_commit_start";
         ResetLastError();
         FileDelete(relative_path,FILE_COMMON);
         io_state.delete_error=GetLastError();

         ResetLastError();
         if(!FileMove(io_state.temp_path,FILE_COMMON,relative_path,FILE_COMMON))
           {
            io_state.move_error=GetLastError();
            if(!allow_copy_fallback)
              {
               if(attempt==attempts)
                 {
                  JsonFail(io_state,"json_fail","commit_move_failed",io_state.move_error);
                  return false;
                 }
               continue;
              }

            ResetLastError();
            if(!FileCopy(io_state.temp_path,FILE_COMMON,relative_path,FILE_COMMON))
              {
               io_state.copy_error=GetLastError();
               ResetLastError();
               FileDelete(io_state.temp_path,FILE_COMMON);
               io_state.delete_error=GetLastError();
               if(attempt==attempts)
                 {
                  JsonFail(io_state,"json_fail","commit_copy_failed",io_state.copy_error);
                  return false;
                 }
               continue;
              }

            ResetLastError();
            FileDelete(io_state.temp_path,FILE_COMMON);
            io_state.delete_error=GetLastError();
           }

         if(!VerifyFinalPayload(relative_path,io_state.payload_bytes_attempted))
           {
            if(attempt==attempts)
              {
               JsonFail(io_state,"json_fail","commit_verify_failed",0);
               return false;
              }
            continue;
           }

         io_state.checkpoint="json_commit_complete";
         return true;
        }

      JsonFail(io_state,"json_fail","write_retry_exhausted",0);
      return false;
     }

   bool CopyProjection(const string src_path,const string dst_path,ForensicState &io_state)
     {
      io_state.checkpoint="json_copy_projection_start";
      io_state.temp_path=src_path;
      io_state.final_path=dst_path;
      ResetLastError();
      FileDelete(dst_path,FILE_COMMON);
      io_state.delete_error=GetLastError();
      ResetLastError();
      const bool ok=FileCopy(src_path,FILE_COMMON,dst_path,FILE_COMMON);
      io_state.copy_error=GetLastError();
      if(!ok)
        {
         JsonFail(io_state,"json_fail","projection_copy_failed",io_state.copy_error);
         return false;
        }
      io_state.checkpoint="json_copy_projection_complete";
      return true;
     }

   bool SerializeStagePayload(const string stage_name,const string payload,string &out_json)
     {
      out_json="{";
      out_json+=JsonStringField("stage_name",stage_name)+",";
      out_json+=JsonStringField("schema_version",ISSX_SCHEMA_VERSION)+",";
      out_json+="\"payload\":"+payload;
      out_json+="}";
      return (StringLen(out_json)>2);
     }

   bool ParseStagePayload(const string json,Envelope &out_envelope)
     {
      out_envelope.Reset();
      if(StringLen(json)<=2)
         return false;
      // Parser migration deferred: current pass focuses on safe serialization/write path.
      out_envelope.payload=json;
      return true;
     }

   bool SaveStagePayload(const string relative_path,const string payload)
     {
      ForensicState fs;
      fs.Reset();
      return WritePayloadAtomic(relative_path,payload,fs,true);
     }

   bool LoadStagePayload(const string relative_path,string &payload)
     {
      payload="";
      ResetLastError();
      const int h=FileOpen(relative_path,FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI,"\n",CP_UTF8);
      if(h==INVALID_HANDLE)
         return false;
      const ulong sz=FileSize(h);
      if(sz>(ulong)2147483647)
        {
         FileClose(h);
         return false;
        }
      payload=FileReadString(h,(int)sz);
      const int err=GetLastError();
      FileClose(h);
      return (err==0);
     }

   bool ValidateExchangeCompatibility(const string producer_stage,
                                             const string consumer_stage,
                                             string &reason)
     {
      if(ISSX_Util::IsEmpty(producer_stage) || ISSX_Util::IsEmpty(consumer_stage))
        {
         reason="missing_stage_name";
         return false;
        }
      reason="ok";
      return true;
     }
  }

#endif // __ISSX_DATA_HANDLER_MQH__
