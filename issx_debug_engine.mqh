#ifndef __ISSX_DEBUG_ENGINE_MQH__
#define __ISSX_DEBUG_ENGINE_MQH__

#include <ISSX/issx_core.mqh>

#define ISSX_DEBUG_EXPORT_ROOT_REL "ISSX"

// ISSX DEBUG ENGINE v1.732

#define ISSX_DEBUG_STAGE_COUNT 5
#define ISSX_DEBUG_MAX_WRITES_PER_SESSION 4000
#define ISSX_DEBUG_RESERVED_IMPORTANT_WRITES 200
#define ISSX_DEBUG_SUPPRESSION_REPORT_EVERY 200
#define ISSX_DEBUG_SAMPLE_BUCKETS 64
#define ISSX_DEBUG_IO_FAIL_DISABLE_THRESHOLD 5
#define ISSX_DEBUG_IO_FAIL_REPORT_EVERY 20

enum ISSX_DebugErrorCategory
  {
   issx_debug_error_none=0,
   issx_debug_error_runtime,
   issx_debug_error_io,
   issx_debug_error_dependency,
   issx_debug_error_data,
   issx_debug_error_unknown
  };

string ISSX_DebugErrorCategoryToString(const ISSX_DebugErrorCategory category)
  {
   switch(category)
     {
      case issx_debug_error_runtime:    return "runtime";
      case issx_debug_error_io:         return "io";
      case issx_debug_error_dependency: return "dependency";
      case issx_debug_error_data:       return "data";
      case issx_debug_error_none:       return "none";
      default:                          return "unknown";
     }
  }

class ISSX_DebugEngine
  {
private:
   bool   m_ready;
   int    m_file_handle;
   string m_session_id;
   string m_file_name;
   string m_terminal_data_path;
   string m_terminal_common_data_path;
   long   m_write_count;
   long   m_write_attempt_count;
   long   m_sample_count;
   long   m_suppressed_count;
   bool   m_suppression_active;
   bool   m_suppression_warned;
   long   m_io_fail_count;
   long   m_io_fail_streak;
   bool   m_io_disabled;
   bool   m_io_disable_warned;
   string m_active_mode;
   string m_active_path;
   long   m_stage_exec_count[ISSX_DEBUG_STAGE_COUNT];
   long   m_stage_exec_total_ms[ISSX_DEBUG_STAGE_COUNT];
   long   m_stage_exec_max_ms[ISSX_DEBUG_STAGE_COUNT];
   long   m_category_error_count[6];
   string m_sample_keys[ISSX_DEBUG_SAMPLE_BUCKETS];
   long   m_sample_values[ISSX_DEBUG_SAMPLE_BUCKETS];

   void CloseHandleIfOpen()
     {
      if(m_file_handle!=INVALID_HANDLE)
        {
         FileFlush(m_file_handle);
         FileClose(m_file_handle);
         m_file_handle=INVALID_HANDLE;
        }
     }

   string BuildTimestamp() const
     {
      datetime now=TimeLocal();
      MqlDateTime dt;
      TimeToStruct(now,dt);
      return StringFormat("%04d%02d%02d_%02d%02d%02d",dt.year,dt.mon,dt.day,dt.hour,dt.min,dt.sec);
     }

   void PrintWithLevel(const string level,const string text)
     {
      Print("[ISSX][",level,"] ",text);
     }

   bool IsSafePathPart(const string part) const
     {
      if(part=="" || part=="." || part=="..")
         return false;
      for(int i=0;i<StringLen(part);i++)
        {
         const ushort ch=(ushort)StringGetCharacter(part,i);
         const bool is_digit=(ch>='0' && ch<='9');
         const bool is_upper=(ch>='A' && ch<='Z');
         const bool is_lower=(ch>='a' && ch<='z');
         const bool is_safe=(is_digit || is_upper || is_lower || ch=='_' || ch=='-' || ch=='.');
         if(!is_safe)
            return false;
        }
      return true;
     }

   string SanitizeRelativeLogPath(const string operator_log_file_name) const
     {
      string candidate=operator_log_file_name;
      StringTrimLeft(candidate);
      StringTrimRight(candidate);
      if(candidate=="")
         return "ISSX/Market_Unknown_Server.log";

      StringReplace(candidate,"\\","/");
      while(StringFind(candidate,"//")>=0)
         StringReplace(candidate,"//","/");

      if(StringFind(candidate,":")>=0 || StringSubstr(candidate,0,1)=="/" || StringFind(candidate,"..")>=0)
         return "ISSX/Market_Unknown_Server.log";

      string parts[];
      int n=StringSplit(candidate,'/',parts);
      if(n<=0)
         return "ISSX/Market_Unknown_Server.log";

      string normalized="";
      for(int i=0;i<n;i++)
        {
         if(!IsSafePathPart(parts[i]))
            return "ISSX/Market_Unknown_Server.log";
         normalized=(normalized=="" ? parts[i] : normalized+"/"+parts[i]);
        }

      if(StringLen(normalized)>220)
         return "ISSX/Market_Unknown_Server.log";
      if(StringFind(normalized,"ISSX/")!=0)
         normalized="ISSX/"+normalized;
      if(StringLen(normalized)<4 || StringSubstr(normalized,StringLen(normalized)-4)!=".log")
         normalized=normalized+".log";
      return normalized;
     }

   bool IsImportantEvent(const string level,const string event_name) const
     {
      if(level=="ERROR" || level=="WARN")
         return true;
      return (event_name=="first_heartbeat" || event_name=="slow_slice" || event_name=="begin" || event_name=="end" || event_name=="end_detail");
     }

   bool CanWriteLine(const bool important)
     {
      const long normal_budget=(ISSX_DEBUG_MAX_WRITES_PER_SESSION-ISSX_DEBUG_RESERVED_IMPORTANT_WRITES);
      if(m_write_attempt_count<normal_budget)
         return true;
      if(important && m_write_attempt_count<ISSX_DEBUG_MAX_WRITES_PER_SESSION)
         return true;

      m_suppressed_count++;
      m_suppression_active=true;
      if(!m_suppression_warned)
        {
         m_suppression_warned=true;
         PrintWithLevel("WARN","Debug write budget reached; suppression started mode="+m_active_mode+" path="+m_active_path+
                        " write_attempt_count="+IntegerToString((int)m_write_attempt_count));
        }
      else if((m_suppressed_count%ISSX_DEBUG_SUPPRESSION_REPORT_EVERY)==0)
        {
         PrintWithLevel("WARN","Debug suppression ongoing suppressed="+IntegerToString((int)m_suppressed_count));
        }
      return false;
     }

   int SampleBucketIndex(const string key) const
     {
      uint hash=2166136261;
      for(int i=0;i<StringLen(key);i++)
        {
         const uint ch=(uint)StringGetCharacter(key,i);
         hash^=ch;
         hash*=16777619;
        }
      return (int)(hash%ISSX_DEBUG_SAMPLE_BUCKETS);
     }

   long NextSampleCount(const string key)
     {
      int idx=SampleBucketIndex(key);
      for(int probe=0;probe<ISSX_DEBUG_SAMPLE_BUCKETS;probe++)
        {
         int slot=(idx+probe)%ISSX_DEBUG_SAMPLE_BUCKETS;
         if(m_sample_keys[slot]==key)
           {
            m_sample_values[slot]++;
            return m_sample_values[slot];
           }
         if(m_sample_keys[slot]=="")
           {
            m_sample_keys[slot]=key;
            m_sample_values[slot]=1;
            return 1;
           }
        }
      m_sample_keys[idx]=key;
      m_sample_values[idx]=0;
      m_sample_values[idx]++;
      return m_sample_values[idx];
     }

   bool EnsureFolderTree(const string relative_path,const bool use_common)
     {
      if(relative_path=="")
         return false;

      string normalized=relative_path;
      StringReplace(normalized,"/","\\");

      string parts[];
      int n=StringSplit(normalized,'\\',parts);
      if(n<=0)
         return false;

      string build="";
      for(int i=0;i<n;i++)
        {
         if(parts[i]=="")
            continue;

         build=(build=="" ? parts[i] : build+"\\"+parts[i]);
         if(use_common)
            FolderCreate(build,FILE_COMMON);
         else
            FolderCreate(build);
        }
      return true;
     }

   string CommonRelativeName() const
     {
      return m_file_name;
     }

public:
   ISSX_DebugEngine()
     {
      Reset();
     }

   void Reset()
     {
      CloseHandleIfOpen();
      m_ready=false;
      m_file_handle=INVALID_HANDLE;
      m_session_id="";
      m_file_name="";
      m_terminal_data_path="";
      m_terminal_common_data_path="";
      m_write_count=0;
      m_write_attempt_count=0;
      m_sample_count=0;
      m_suppressed_count=0;
      m_suppression_active=false;
      m_suppression_warned=false;
      m_io_fail_count=0;
      m_io_fail_streak=0;
      m_io_disabled=false;
      m_io_disable_warned=false;
      m_active_mode="inactive";
      m_active_path="";
      ArrayInitialize(m_stage_exec_count,0);
      ArrayInitialize(m_stage_exec_total_ms,0);
      ArrayInitialize(m_stage_exec_max_ms,0);
      ArrayInitialize(m_category_error_count,0);
      for(int k=0;k<ISSX_DEBUG_SAMPLE_BUCKETS;k++)
        {
         m_sample_keys[k]="";
         m_sample_values[k]=0;
        }
     }

   bool BeginSession(const string operator_log_file_name,const string symbol,const ENUM_TIMEFRAMES tf,const string server_name,const string broker_name,const long login_id)
     {
      Reset();
      m_terminal_data_path=TerminalInfoString(TERMINAL_DATA_PATH);
      m_terminal_common_data_path=TerminalInfoString(TERMINAL_COMMONDATA_PATH);

      m_session_id=BuildTimestamp()+"_"+IntegerToString((int)ChartID())+"_"+IntegerToString((int)GetTickCount());
      m_file_name=SanitizeRelativeLogPath(operator_log_file_name);

      const string common_rel=CommonRelativeName();
      const string local_rel=common_rel;

      string common_folder=common_rel;
      int slash_pos=StringFind(common_folder,"/",0);
      int last_slash=-1;
      while(slash_pos>=0)
        {
         last_slash=slash_pos;
         slash_pos=StringFind(common_folder,"/",slash_pos+1);
        }
      if(last_slash>0)
         common_folder=StringSubstr(common_folder,0,last_slash);
      else
         common_folder=ISSX_DEBUG_EXPORT_ROOT_REL;

      EnsureFolderTree(common_folder,true);
      ResetLastError();
      m_file_handle=FileOpen(common_rel,FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(m_file_handle!=INVALID_HANDLE)
        {
         m_active_mode="common";
         m_active_path=common_rel;
        }
      else
        {
         const int common_err=GetLastError();
         PrintWithLevel("WARN","Common FileOpen failed err="+IntegerToString(common_err)+" rel="+common_rel);

         EnsureFolderTree(common_folder,false);
         ResetLastError();
         m_file_handle=FileOpen(local_rel,FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
         if(m_file_handle!=INVALID_HANDLE)
           {
            m_active_mode="local";
            m_active_path=local_rel;
           }
         else
           {
            const int local_err=GetLastError();
            m_active_mode="terminal_only";
            m_active_path="";
            PrintWithLevel("ERROR","Local fallback FileOpen failed err="+IntegerToString(local_err)+" rel="+local_rel+" mode="+m_active_mode);
            return false;
           }
        }

      m_write_count=0;
      m_write_attempt_count=0;
      m_sample_count=0;
      m_ready=true;
      PrintWithLevel("INFO","Debug session started mode="+m_active_mode+" path="+m_active_path+
                     " terminal_data="+m_terminal_data_path+" terminal_common="+m_terminal_common_data_path);
      Write("INFO","session","begin",
            "mode="+m_active_mode+" path="+m_active_path+" symbol="+symbol+" tf="+EnumToString(tf));
      Write("INFO","session","header",
            "stage_alias=Market server="+server_name+" broker="+broker_name+" login="+IntegerToString((int)login_id)+" file="+m_file_name);
      return true;
     }

   void Write(const string level,const string area,const string event_name,const string detail)
     {
      const string line=BuildTimestamp()+" | "+level+" | "+area+" | "+event_name+" | "+detail;
      const bool important=IsImportantEvent(level,event_name);
      if(important)
         PrintWithLevel(level,area+"::"+event_name+" | "+detail);
      if(!m_ready || m_file_handle==INVALID_HANDLE)
         return;
      if(m_io_disabled)
         return;
      if(!CanWriteLine(important))
         return;
      m_write_attempt_count++;

      FileSeek(m_file_handle,0,SEEK_END);
      ResetLastError();
      const ulong chars_written=(ulong)FileWriteString(m_file_handle,line+"\r\n");
      if(chars_written>0)
        {
         m_write_count++;
         m_io_fail_streak=0;
         if((m_write_count%5)==0)
            FileFlush(m_file_handle);
        }
      else
        {
         m_io_fail_count++;
         m_io_fail_streak++;
         const int write_err=GetLastError();
         if(m_io_fail_count==1 || (m_io_fail_count%ISSX_DEBUG_IO_FAIL_REPORT_EVERY)==0)
            PrintWithLevel("ERROR","Write failed err="+IntegerToString(write_err)+" mode="+m_active_mode+" path="+m_active_path+
                           " fail_count="+IntegerToString((int)m_io_fail_count));
         if(m_io_fail_streak>=ISSX_DEBUG_IO_FAIL_DISABLE_THRESHOLD)
           {
            m_io_disabled=true;
            if(!m_io_disable_warned)
              {
               m_io_disable_warned=true;
               PrintWithLevel("WARN","Debug file output disabled after consecutive write failures mode="+m_active_mode+
                              " path="+m_active_path+" fail_streak="+IntegerToString((int)m_io_fail_streak));
              }
            CloseHandleIfOpen();
            m_ready=false;
            m_active_mode="terminal_only";
            m_active_path="";
           }
        }
     }

   void Flush()
     {
      if(m_file_handle!=INVALID_HANDLE)
         FileFlush(m_file_handle);
     }

   void Close(const int deinit_reason)
     {
      if(!m_ready && m_file_handle==INVALID_HANDLE)
        {
         CloseHandleIfOpen();
         m_active_mode="closed";
         m_active_path="";
         return;
        }
      const long writes_before_close=m_write_count;
      const long write_attempts_before_close=m_write_attempt_count;
      const long suppressed_before_close=m_suppressed_count;
      const long io_fail_before_close=m_io_fail_count;
      Write("INFO","session","end",
            "deinit_reason="+IntegerToString(deinit_reason)+
            " write_count="+IntegerToString((int)writes_before_close)+
            " write_attempt_count="+IntegerToString((int)write_attempts_before_close)+
            " suppressed="+IntegerToString((int)suppressed_before_close)+
            " io_fail_count="+IntegerToString((int)io_fail_before_close)+
            " mode="+m_active_mode+
            " path="+m_active_path);

      CloseHandleIfOpen();

      m_ready=false;
      m_active_mode="closed";
      m_active_path="";
     }

   void Close(const int deinit_reason,const string detail)
     {
      Write("INFO","session","end_detail",detail);
      Close(deinit_reason);
     }


   void MarkStageExecution(const ISSX_StageId stage_id,const long elapsed_ms)
     {
      int idx=(int)stage_id-1;
      if(idx<0 || idx>=ISSX_DEBUG_STAGE_COUNT)
         return;
      m_stage_exec_count[idx]++;
      m_stage_exec_total_ms[idx]+=elapsed_ms;
      if(elapsed_ms>m_stage_exec_max_ms[idx])
         m_stage_exec_max_ms[idx]=elapsed_ms;
     }

   void CategorizeError(const ISSX_DebugErrorCategory category,const string area,const string event_name,const string detail)
     {
      int idx=(int)category;
      if(idx<0 || idx>=ArraySize(m_category_error_count))
         idx=(int)issx_debug_error_unknown;
      m_category_error_count[idx]++;
      Write("ERROR",area,event_name,"category="+ISSX_DebugErrorCategoryToString((ISSX_DebugErrorCategory)idx)+" "+detail);
     }

   void SampledLog(const string level,const string area,const string event_name,const string detail,const long sample_every)
     {
      if(sample_every<=1)
        {
         Write(level,area,event_name,detail);
         return;
        }
      const string sample_key=level+"|"+area+"|"+event_name;
      const long sample_count=NextSampleCount(sample_key);
      m_sample_count++;
      if((sample_count%sample_every)==0)
         Write(level,area,event_name,detail);
     }

   void FlushStageCountersSample()
     {
      for(int i=0;i<ISSX_DEBUG_STAGE_COUNT;i++)
        {
         if(m_stage_exec_count[i]<=0)
            continue;
         const long avg_ms=m_stage_exec_total_ms[i]/m_stage_exec_count[i];
         Write("INFO","stage_timing","summary",
               "stage="+IntegerToString(i+1)+
               " count="+IntegerToString((int)m_stage_exec_count[i])+
               " avg_ms="+IntegerToString((int)avg_ms)+
               " max_ms="+IntegerToString((int)m_stage_exec_max_ms[i]));
        }
      for(int c=1;c<ArraySize(m_category_error_count);c++)
        {
         if(m_category_error_count[c]<=0)
            continue;
         Write("INFO","error_counters","summary",
               "category="+ISSX_DebugErrorCategoryToString((ISSX_DebugErrorCategory)c)+
               " count="+IntegerToString((int)m_category_error_count[c]));
        }
     }

   string ActiveMode() const { return m_active_mode; }
   string ActivePath() const { return m_active_path; }
   long WriteCount() const { return m_write_count; }

   bool IsReady() const { return m_ready; }
   string SessionId() const { return m_session_id; }
  };

#endif
