#ifndef __ISSX_DEBUG_ENGINE_MQH__
#define __ISSX_DEBUG_ENGINE_MQH__

#include <ISSX/issx_core.mqh>

#define ISSX_DEBUG_EXPORT_ROOT_REL "ISSX"

// ISSX DEBUG ENGINE v1.722

#define ISSX_DEBUG_STAGE_COUNT 5

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
   string m_active_mode;
   string m_active_path;
   long   m_stage_exec_count[ISSX_DEBUG_STAGE_COUNT];
   long   m_stage_exec_total_ms[ISSX_DEBUG_STAGE_COUNT];
   long   m_stage_exec_max_ms[ISSX_DEBUG_STAGE_COUNT];
   long   m_category_error_count[6];

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
      m_ready=false;
      m_file_handle=INVALID_HANDLE;
      m_session_id="";
      m_file_name="";
      m_terminal_data_path="";
      m_terminal_common_data_path="";
      m_write_count=0;
      m_active_mode="inactive";
      m_active_path="";
      ArrayInitialize(m_stage_exec_count,0);
      ArrayInitialize(m_stage_exec_total_ms,0);
      ArrayInitialize(m_stage_exec_max_ms,0);
      ArrayInitialize(m_category_error_count,0);
     }

   bool BeginSession(const string operator_log_file_name,const string symbol,const ENUM_TIMEFRAMES tf,const string server_name,const string broker_name,const long login_id)
     {
      Reset();
      m_terminal_data_path=TerminalInfoString(TERMINAL_DATA_PATH);
      m_terminal_common_data_path=TerminalInfoString(TERMINAL_COMMONDATA_PATH);

      m_session_id=BuildTimestamp()+"_"+IntegerToString((int)ChartID())+"_"+IntegerToString((int)GetTickCount());
      m_file_name=(ISSX_Util::IsEmpty(operator_log_file_name) ? "ISSX/Market_Unknown_Server.log" : operator_log_file_name);

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
      const bool important=(level=="ERROR" || level=="WARN" || event_name=="first_heartbeat" || event_name=="slow_slice");
      if(important)
         PrintWithLevel(level,area+"::"+event_name+" | "+detail);
      if(!m_ready || m_file_handle==INVALID_HANDLE)
         return;

      FileSeek(m_file_handle,0,SEEK_END);
      const ulong chars_written=(ulong)FileWriteString(m_file_handle,line+"\r\n");
      if(chars_written>0)
        {
         m_write_count++;
         if((m_write_count%5)==0)
            FileFlush(m_file_handle);
        }
      else
        {
         const int write_err=GetLastError();
         PrintWithLevel("WARN","Write failed err="+IntegerToString(write_err)+" mode="+m_active_mode+" path="+m_active_path);
        }
     }

   void Flush()
     {
      if(m_file_handle!=INVALID_HANDLE)
         FileFlush(m_file_handle);
     }

   void Close(const int deinit_reason)
     {
      const long writes_before_close=m_write_count;
      Write("INFO","session","end",
            "deinit_reason="+IntegerToString(deinit_reason)+
            " write_count="+IntegerToString((int)writes_before_close)+
            " mode="+m_active_mode+
            " path="+m_active_path);

      if(m_file_handle!=INVALID_HANDLE)
        {
         FileFlush(m_file_handle);
         FileClose(m_file_handle);
         m_file_handle=INVALID_HANDLE;
        }

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
      if((m_write_count%sample_every)==0)
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
