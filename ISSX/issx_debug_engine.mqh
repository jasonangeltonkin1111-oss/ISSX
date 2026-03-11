#ifndef __ISSX_DEBUG_ENGINE_MQH__
#define __ISSX_DEBUG_ENGINE_MQH__

// Requested Windows base path for debug exports.
// MQL5 FileOpen cannot reliably write arbitrary absolute OS paths.
// We log absolute intent and map writes to FILE_COMMON fallback-compatible relative paths.
#define ISSX_DEBUG_EXPORT_BASE "C:\\Users\\Jason\\AppData\\Roaming\\MetaQuotes\\Terminal\\43C1572456A3A33910D4FE26B1396DC3\\MQL5\\Include\\ISSX\\ISSX"
#define ISSX_DEBUG_EXPORT_REPORTS "C:\\Users\\Jason\\AppData\\Roaming\\MetaQuotes\\Terminal\\43C1572456A3A33910D4FE26B1396DC3\\MQL5\\Include\\ISSX\\ISSX\\debug_reports"

#define ISSX_DEBUG_REL_PRIMARY  "ISSX\\ISSX\\debug_reports"
#define ISSX_DEBUG_REL_FALLBACK "ISSX\\debug_reports"

class ISSX_DebugEngine
  {
private:
   bool   m_ready;
   int    m_file_handle;
   string m_session_id;
   string m_file_name;
   string m_active_mode;
   string m_active_path;

   string BuildTimestamp() const
     {
      MqlDateTime dt;
      TimeToStruct(TimeLocal(),dt);
      return StringFormat("%04d%02d%02d_%02d%02d%02d",dt.year,dt.mon,dt.day,dt.hour,dt.min,dt.sec);
     }

   void PrintLine(const string level,const string text) const
     {
      Print("[ISSX][",level,"] ",text);
     }

   bool EnsureFolderCommon(const string rel_path)
     {
      ResetLastError();
      if(FolderCreate(rel_path,FILE_COMMON))
         return true;
      const int err=GetLastError();
      if(err==0 || err==5019)
         return true;
      PrintLine("WARN","DEBUG FOLDER CREATE FAILED rel="+rel_path+" err="+IntegerToString(err));
      return false;
     }

   bool OpenFileCommon(const string rel_root)
     {
      string rel_file=rel_root+"\\"+m_file_name;
      ResetLastError();
      m_file_handle=FileOpen(rel_file,FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(m_file_handle==INVALID_HANDLE)
        {
         const int err=GetLastError();
         PrintLine("ERROR","DEBUG FILE OPEN FAILED rel="+rel_file+" err="+IntegerToString(err));
         return false;
        }

      m_active_mode="FILE_COMMON";
      m_active_path=rel_file;
      m_ready=true;
      return true;
     }

public:
   void Reset()
     {
      m_ready=false;
      m_file_handle=INVALID_HANDLE;
      m_session_id="";
      m_file_name="";
      m_active_mode="none";
      m_active_path="";
     }

   bool BeginSession(const string ea_name,const string symbol,const ENUM_TIMEFRAMES tf)
     {
      Reset();

      PrintLine("INFO","DEBUG INIT START");
      PrintLine("INFO","DEBUG REQUESTED ABS BASE="+ISSX_DEBUG_EXPORT_BASE);
      PrintLine("INFO","DEBUG REQUESTED ABS REPORTS="+ISSX_DEBUG_EXPORT_REPORTS);
      PrintLine("INFO","DEBUG TERMINAL_DATA_PATH="+TerminalInfoString(TERMINAL_DATA_PATH));
      PrintLine("INFO","DEBUG TERMINAL_COMMONDATA_PATH="+TerminalInfoString(TERMINAL_COMMONDATA_PATH));

      m_session_id=BuildTimestamp()+"_"+IntegerToString((int)ChartID())+"_"+IntegerToString((int)GetTickCount());
      m_file_name=ea_name+"_"+m_session_id+".log";

      // Primary mapped path (closest structure to requested absolute Include\ISSX\ISSX\debug_reports)
      bool primary_folder_ok=EnsureFolderCommon("ISSX");
      primary_folder_ok = EnsureFolderCommon("ISSX\\ISSX") && primary_folder_ok;
      primary_folder_ok = EnsureFolderCommon(ISSX_DEBUG_REL_PRIMARY) && primary_folder_ok;

      if(primary_folder_ok && OpenFileCommon(ISSX_DEBUG_REL_PRIMARY))
        {
         Write("INFO","debug","first_write","DEBUG FIRST WRITE OK mode="+m_active_mode+" path="+m_active_path+" symbol="+symbol+" tf="+EnumToString(tf));
         return true;
        }

      PrintLine("WARN","DEBUG PRIMARY OPEN FAILED, TRYING FALLBACK="+ISSX_DEBUG_REL_FALLBACK);
      EnsureFolderCommon("ISSX");
      EnsureFolderCommon(ISSX_DEBUG_REL_FALLBACK);
      if(OpenFileCommon(ISSX_DEBUG_REL_FALLBACK))
        {
         Write("INFO","debug","first_write","DEBUG FIRST WRITE OK mode="+m_active_mode+" path="+m_active_path+" symbol="+symbol+" tf="+EnumToString(tf));
         return true;
        }

      PrintLine("ERROR","DEBUG ENGINE RUNNING IN PRINT-ONLY MODE; FILE LOGGING DISABLED");
      return false;
     }

   void Write(const string level,const string area,const string event_name,const string detail)
     {
      string line=BuildTimestamp()+" | "+level+" | "+area+" | "+event_name+" | "+detail;
      PrintLine(level,area+"::"+event_name+" | "+detail);

      if(!m_ready || m_file_handle==INVALID_HANDLE)
         return;

      FileSeek(m_file_handle,0,SEEK_END);
      FileWriteString(m_file_handle,line+"\r\n");
      FileFlush(m_file_handle);
     }

   void WriteCritical(const string area,const string event_name,const string detail)
     {
      Write("ERROR",area,event_name,detail);
     }

   void Close(const int deinit_reason,const string summary)
     {
      Write("INFO","lifecycle","session_end","deinit_reason="+IntegerToString(deinit_reason)+" summary="+summary);
      if(m_file_handle!=INVALID_HANDLE)
        {
         FileFlush(m_file_handle);
         FileClose(m_file_handle);
         m_file_handle=INVALID_HANDLE;
        }
      m_ready=false;
     }

   bool IsReady() const { return m_ready; }
   string SessionId() const { return m_session_id; }
   string ActivePath() const { return m_active_path; }
   string ActiveMode() const { return m_active_mode; }
  };

#endif
