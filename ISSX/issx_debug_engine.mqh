#ifndef __ISSX_DEBUG_ENGINE_MQH__
#define __ISSX_DEBUG_ENGINE_MQH__

#define ISSX_DEBUG_EXPORT_ROOT_REL "ISSX\\debug_reports"

class ISSX_DebugEngine
  {
private:
   bool   m_ready;
   int    m_file_handle;
   string m_session_id;
   string m_file_name;
   string m_terminal_data_path;
   string m_terminal_common_data_path;
   string m_active_mode;
   string m_active_path;
   int    m_write_count;

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
      const ushort sep=(ushort)StringGetCharacter("\\",0);
      int n=StringSplit(normalized,sep,parts);
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
      return ISSX_DEBUG_EXPORT_ROOT_REL+"\\"+m_file_name;
     }

public:
   void Reset()
     {
      m_ready=false;
      m_file_handle=INVALID_HANDLE;
      m_session_id="";
      m_file_name="";
      m_terminal_data_path="";
      m_terminal_common_data_path="";
      m_active_mode="none";
      m_active_path="";
      m_write_count=0;
     }

   bool BeginSession(const string ea_name,const string symbol,const ENUM_TIMEFRAMES tf)
     {
      Reset();
      m_terminal_data_path=TerminalInfoString(TERMINAL_DATA_PATH);
      m_terminal_common_data_path=TerminalInfoString(TERMINAL_COMMONDATA_PATH);

      m_session_id=BuildTimestamp()+"_"+IntegerToString((int)ChartID())+"_"+IntegerToString((int)GetTickCount());
      m_file_name=ea_name+"_"+m_session_id+".log";

      const string common_rel=CommonRelativeName();
      EnsureFolderTree(ISSX_DEBUG_EXPORT_ROOT_REL,true);

      ResetLastError();
      m_file_handle=FileOpen(common_rel,FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(m_file_handle==INVALID_HANDLE)
        {
         const int common_err=GetLastError();
         PrintWithLevel("WARN","Common FileOpen failed err="+IntegerToString(common_err)+" rel="+common_rel);

         // Local-terminal fallback stays relative to MQL5/Files for safety.
         EnsureFolderTree(ISSX_DEBUG_EXPORT_ROOT_REL,false);
         ResetLastError();
         m_file_handle=FileOpen(common_rel,FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
         if(m_file_handle!=INVALID_HANDLE)
           {
            m_active_mode="local";
            m_active_path=common_rel;
           }
         if(m_file_handle==INVALID_HANDLE)
           {
            const int local_err=GetLastError();
            PrintWithLevel("ERROR","Local fallback FileOpen failed err="+IntegerToString(local_err)+" rel="+common_rel);
            return false;
           }
        }

      if(m_active_mode=="none")
        {
         m_active_mode="common";
         m_active_path=common_rel;
        }

      m_ready=true;
      PrintWithLevel("INFO","Debug session started rel="+common_rel+" mode="+m_active_mode+" terminal_data="+m_terminal_data_path+" terminal_common="+m_terminal_common_data_path);
      Write("INFO","session","begin","file_rel="+common_rel+" mode="+m_active_mode+" symbol="+symbol+" tf="+EnumToString(tf));
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
      FileWriteString(m_file_handle,line+"\r\n");
      m_write_count++;
      if((m_write_count%5)==0)
         FileFlush(m_file_handle);
     }

   void Close(const int deinit_reason)
     {
      Write("INFO","session","end","deinit_reason="+IntegerToString(deinit_reason));
      if(m_file_handle!=INVALID_HANDLE)
        {
         FileFlush(m_file_handle);
         FileClose(m_file_handle);
         m_file_handle=INVALID_HANDLE;
        }
      m_ready=false;
     }


   void Close(const int deinit_reason,const string detail)
     {
      Write("INFO","session","end_detail",detail);
      Close(deinit_reason);
     }

   string ActiveMode() const { return m_active_mode; }
   string ActivePath() const { return m_active_path; }

   bool IsReady() const { return m_ready; }
   string SessionId() const { return m_session_id; }
  };

#endif
