#ifndef __ISSX_DEBUG_ENGINE_MQH__
#define __ISSX_DEBUG_ENGINE_MQH__

#define ISSX_DEBUG_EXPORT_BASE "C:\\Users\\Jason\\AppData\\Roaming\\MetaQuotes\\Terminal\\43C1572456A3A33910D4FE26B1396DC3\\MQL5\\Include\\ISSX\\ISSX"
#define ISSX_DEBUG_EXPORT_REPORTS ISSX_DEBUG_EXPORT_BASE "\\debug_reports"

class ISSX_DebugEngine
  {
private:
   bool   m_ready;
   int    m_file_handle;
   string m_session_id;
   string m_file_name;

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

   bool EnsureFolder(const string full_path)
     {
      ResetLastError();
      if(FolderCreate(full_path))
         return true;
      const int err=GetLastError();
      if(err==0 || err==5019)
         return true;
      PrintWithLevel("WARN","FolderCreate failed path="+full_path+" err="+IntegerToString(err));
      return false;
     }

   string FallbackRelativeName() const
     {
      return "ISSX\\debug_reports\\"+m_file_name;
     }

public:
   void Reset()
     {
      m_ready=false;
      m_file_handle=INVALID_HANDLE;
      m_session_id="";
      m_file_name="";
     }

   bool BeginSession(const string ea_name,const string symbol,const ENUM_TIMEFRAMES tf)
     {
      Reset();
      m_session_id=BuildTimestamp()+"_"+IntegerToString((int)ChartID())+"_"+IntegerToString((int)GetTickCount());
      m_file_name=ea_name+"_"+m_session_id+".log";

      bool folder_ok=EnsureFolder(ISSX_DEBUG_EXPORT_BASE) && EnsureFolder(ISSX_DEBUG_EXPORT_REPORTS);
      string full_path=ISSX_DEBUG_EXPORT_REPORTS+"\\"+m_file_name;
      if(!folder_ok)
         PrintWithLevel("WARN","Debug folder prepare not fully successful; attempting file open anyway");

      ResetLastError();
      m_file_handle=FileOpen(full_path,FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(m_file_handle==INVALID_HANDLE)
        {
         const int abs_err=GetLastError();
         PrintWithLevel("WARN","FileOpen absolute failed err="+IntegerToString(abs_err)+" path="+full_path);

         const string fallback_rel=FallbackRelativeName();
         EnsureFolder("ISSX");
         EnsureFolder("ISSX\\debug_reports");
         ResetLastError();
         m_file_handle=FileOpen(fallback_rel,FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
         if(m_file_handle==INVALID_HANDLE)
           {
            const int fb_err=GetLastError();
            PrintWithLevel("ERROR","Fallback FileOpen failed err="+IntegerToString(fb_err)+" rel="+fallback_rel);
            return false;
           }

         m_ready=true;
         PrintWithLevel("INFO","Debug session started with fallback file="+fallback_rel);
         Write("INFO","session","begin","fallback_file="+fallback_rel+" symbol="+symbol+" tf="+EnumToString(tf));
         return true;
        }

      m_ready=true;
      PrintWithLevel("INFO","Debug session started file="+full_path);
      Write("INFO","session","begin","file="+full_path+" symbol="+symbol+" tf="+EnumToString(tf));
      return true;
     }

   void Write(const string level,const string area,const string event_name,const string detail)
     {
      const string line=BuildTimestamp()+" | "+level+" | "+area+" | "+event_name+" | "+detail;
      PrintWithLevel(level,area+"::"+event_name+" | "+detail);
      if(!m_ready || m_file_handle==INVALID_HANDLE)
         return;

      FileSeek(m_file_handle,0,SEEK_END);
      FileWriteString(m_file_handle,line+"\r\n");
      FileFlush(m_file_handle);
     }

   void Close(const int deinit_reason)
     {
      Write("INFO","session","end","deinit_reason="+IntegerToString(deinit_reason));
      if(m_file_handle!=INVALID_HANDLE)
        {
         FileClose(m_file_handle);
         m_file_handle=INVALID_HANDLE;
        }
      m_ready=false;
     }

   bool IsReady() const { return m_ready; }
   string SessionId() const { return m_session_id; }
  };

#endif
