#ifndef __ISSX_DATA_HANDLER_MQH__
#define __ISSX_DATA_HANDLER_MQH__

#include <ISSX/issx_core.mqh>

// ============================================================================
// ISSX DATA HANDLER v1.715
// Shared JSON/payload/file-commit safety layer for ISSX stages.
// ============================================================================

#define ISSX_DATA_HANDLER_MODULE_VERSION "1.715"

namespace ISSX_DataHandler
  {
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

   static int EstimateUtf8Bytes(const string text)
     {
      uchar bytes[];
      const int n=StringToCharArray(text,bytes,0,-1,CP_UTF8);
      if(n<=0)
         return 0;
      return MathMax(0,n-1);
     }

   static void JsonBuildStart(ForensicState &io_state,const string checkpoint)
     {
      io_state.checkpoint=checkpoint;
      io_state.last_error="none";
      io_state.payload_bytes_attempted=0;
      io_state.payload_bytes_written=0;
     }

   static void JsonBuildComplete(ForensicState &io_state,const string payload,const string checkpoint)
     {
      io_state.checkpoint=checkpoint;
      io_state.payload_bytes_attempted=EstimateUtf8Bytes(payload);
      io_state.payload_bytes_written=io_state.payload_bytes_attempted;
      io_state.last_error="none";
     }

   static void JsonSymbolSerializeStart(ForensicState &io_state,const string symbol)
     {
      io_state.checkpoint="json_symbol_serialize_start";
      io_state.symbol=symbol;
      io_state.last_serialized_symbol=symbol;
     }

   static void JsonSymbolSerializeComplete(ForensicState &io_state,const string symbol)
     {
      io_state.checkpoint="json_symbol_serialize_complete";
      io_state.symbol=symbol;
      io_state.last_successful_symbol=symbol;
     }

   static void JsonFail(ForensicState &io_state,const string checkpoint,const string reason,const int err)
     {
      io_state.checkpoint=checkpoint;
      io_state.last_error=reason;
      if(err!=0)
         io_state.write_error=err;
     }

   static string EscapeJson(const string s,bool &out_ok)
     {
      out_ok=true;
      return ISSX_Util::EscapeJson(s);
     }

   static string JsonStringField(const string name,const string value)
     {
      return ISSX_JsonWriter::NameStringKV(name,value);
     }

   static string JsonLongField(const string name,const long value)
     {
      return ISSX_JsonWriter::NameLongKV(name,value);
     }

   static string JsonDoubleField(const string name,const double value,const int digits=ISSX_JSON_DOUBLE_DIGITS_DEFAULT)
     {
      return ISSX_JsonWriter::NameDoubleKV(name,value,digits);
     }

   static string JsonBoolField(const string name,const bool value)
     {
      return ISSX_JsonWriter::NameBoolKV(name,value);
     }

   static bool WritePayloadAtomic(const string relative_path,
                                  const string payload,
                                  ForensicState &io_state,
                                  const bool allow_copy_fallback=true)
     {
      io_state.final_path=relative_path;
      io_state.temp_path=relative_path+".tmp";
      io_state.payload_bytes_attempted=EstimateUtf8Bytes(payload);
      io_state.payload_bytes_written=0;

      io_state.checkpoint="json_write_tmp_start";
      ResetLastError();
      const int h=FileOpen(io_state.temp_path,
                           FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI,
                           "\n",
                           CP_UTF8);
      io_state.open_error=GetLastError();
      if(h==INVALID_HANDLE)
        {
         JsonFail(io_state,"json_fail","tmp_open_failed",io_state.open_error);
         return false;
        }

      const int wanted=StringLen(payload);
      ResetLastError();
      const uint written=FileWriteString(h,payload,wanted);
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
         JsonFail(io_state,"json_fail","tmp_write_or_flush_failed",(io_state.write_error!=0?io_state.write_error:flush_error));
         return false;
        }

      io_state.payload_bytes_written=EstimateUtf8Bytes(payload);
      io_state.checkpoint="json_write_tmp_complete";

      io_state.checkpoint="json_commit_start";
      ResetLastError();
      FileDelete(relative_path,FILE_COMMON);
      io_state.delete_error=GetLastError();

      ResetLastError();
      if(!FileMove(io_state.temp_path,0,relative_path,FILE_COMMON))
        {
         io_state.move_error=GetLastError();
         if(!allow_copy_fallback)
           {
            JsonFail(io_state,"json_fail","commit_move_failed",io_state.move_error);
            return false;
           }

         ResetLastError();
         if(!FileCopy(io_state.temp_path,0,relative_path,FILE_COMMON))
           {
            io_state.copy_error=GetLastError();
            ResetLastError();
            FileDelete(io_state.temp_path,FILE_COMMON);
            io_state.delete_error=GetLastError();
            JsonFail(io_state,"json_fail","commit_copy_failed",io_state.copy_error);
            return false;
           }

         ResetLastError();
         FileDelete(io_state.temp_path,FILE_COMMON);
         io_state.delete_error=GetLastError();
        }

      io_state.checkpoint="json_commit_complete";
      return true;
     }

   static bool CopyProjection(const string src_path,const string dst_path,ForensicState &io_state)
     {
      io_state.checkpoint="json_copy_projection_start";
      io_state.temp_path=src_path;
      io_state.final_path=dst_path;
      ResetLastError();
      FileDelete(dst_path,FILE_COMMON);
      io_state.delete_error=GetLastError();
      ResetLastError();
      const bool ok=FileCopy(src_path,0,dst_path,FILE_COMMON);
      io_state.copy_error=GetLastError();
      if(!ok)
        {
         JsonFail(io_state,"json_fail","projection_copy_failed",io_state.copy_error);
         return false;
        }
      io_state.checkpoint="json_copy_projection_complete";
      return true;
     }

   static bool SerializeStagePayload(const string stage_name,const string payload,string &out_json)
     {
      out_json="{";
      out_json+=JsonStringField("stage_name",stage_name)+",";
      out_json+=JsonStringField("schema_version",ISSX_SCHEMA_VERSION)+",";
      out_json+="\"payload\":"+payload;
      out_json+="}";
      return (StringLen(out_json)>2);
     }

   static bool ParseStagePayload(const string json,Envelope &out_envelope)
     {
      out_envelope.Reset();
      if(StringLen(json)<=2)
         return false;
      // Parser migration deferred: current pass focuses on safe serialization/write path.
      out_envelope.payload=json;
      return true;
     }

   static bool SaveStagePayload(const string relative_path,const string payload)
     {
      ForensicState fs;
      fs.Reset();
      return WritePayloadAtomic(relative_path,payload,fs,true);
     }

   static bool LoadStagePayload(const string relative_path,string &payload)
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

   static bool ValidateExchangeCompatibility(const string producer_stage,
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
