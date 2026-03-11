#ifndef __ISSX_DEBUG_ENGINE_MQH__
#define __ISSX_DEBUG_ENGINE_MQH__

#include <ISSX/issx_core.mqh>
#include <ISSX/issx_persistence.mqh>

struct ISSX_ForensicState
  {
   string boot_id;
   string session_id;
   long   init_ms;
   long   cycle_no;
   long   last_cycle_start_ms;
   long   last_cycle_elapsed_ms;
   bool   timer_active;
   bool   kernel_busy;
   string last_stage_entered;
   string last_stage_completed;
   string last_function;
   string last_file;
   string last_error_context;
   int    last_error_code;

   void Reset()
     {
      boot_id="";
      session_id="";
      init_ms=0;
      cycle_no=0;
      last_cycle_start_ms=0;
      last_cycle_elapsed_ms=0;
      timer_active=false;
      kernel_busy=false;
      last_stage_entered="";
      last_stage_completed="";
      last_function="";
      last_file="";
      last_error_context="";
      last_error_code=0;
     }
  };

class ISSX_DebugEngine
  {
private:
   static ISSX_ForensicState m_state;

public:
   static void Init(const string boot_id,const string session_id)
     {
      m_state.Reset();
      m_state.boot_id=boot_id;
      m_state.session_id=session_id;
      m_state.init_ms=(long)GetTickCount64();
     }

   static void SetTimerActive(const bool active)
     {
      m_state.timer_active=active;
     }

   static void SetKernelBusy(const bool busy)
     {
      m_state.kernel_busy=busy;
     }

   static void BeginCycle()
     {
      m_state.cycle_no++;
      m_state.last_cycle_start_ms=(long)GetTickCount64();
     }

   static void EndCycle()
     {
      const long now_ms=(long)GetTickCount64();
      if(m_state.last_cycle_start_ms>0)
         m_state.last_cycle_elapsed_ms=(now_ms-m_state.last_cycle_start_ms);
     }

   static void StageEnter(const string stage_name)
     {
      m_state.last_stage_entered=stage_name;
      m_state.last_function=stage_name;
     }

   static void StageDone(const string stage_name)
     {
      m_state.last_stage_completed=stage_name;
     }

   static void MarkFunction(const string function_name)
     {
      m_state.last_function=function_name;
     }

   static void MarkFile(const string file_path)
     {
      m_state.last_file=file_path;
     }

   static void MarkError(const string context,const int err=0)
     {
      m_state.last_error_context=context;
      m_state.last_error_code=(err!=0 ? err : GetLastError());
     }

   static string DeinitReasonToString(const int reason)
     {
      switch(reason)
        {
         case REASON_PROGRAM:   return "program";
         case REASON_REMOVE:    return "remove";
         case REASON_RECOMPILE: return "recompile";
         case REASON_CHARTCHANGE:return "chartchange";
         case REASON_CHARTCLOSE:return "chartclose";
         case REASON_PARAMETERS:return "parameters";
         case REASON_ACCOUNT:   return "account";
         case REASON_TEMPLATE:  return "template";
         case REASON_INITFAILED:return "initfailed";
         case REASON_CLOSE:     return "terminal_close";
        }
      return "unknown";
     }

   static string BuildForensicJson(const string event_name)
     {
      ISSX_JsonWriter w;
      w.BeginObject();
      w.WriteString("event",event_name);
      w.WriteString("boot_id",m_state.boot_id);
      w.WriteString("session_id",m_state.session_id);
      w.WriteLong("uptime_ms",(long)GetTickCount64()-m_state.init_ms);
      w.WriteLong("cycle_no",m_state.cycle_no);
      w.WriteLong("last_cycle_elapsed_ms",m_state.last_cycle_elapsed_ms);
      w.WriteBool("timer_active",m_state.timer_active);
      w.WriteBool("kernel_busy",m_state.kernel_busy);
      w.WriteString("last_stage_entered",m_state.last_stage_entered);
      w.WriteString("last_stage_completed",m_state.last_stage_completed);
      w.WriteString("last_function",m_state.last_function);
      w.WriteString("last_file",m_state.last_file);
      w.WriteString("last_error_context",m_state.last_error_context);
      w.WriteInt("last_error_code",m_state.last_error_code);
      w.WriteLong("chart_id",(long)ChartID());
      w.WriteString("symbol",_Symbol);
      w.WriteInt("period",(int)_Period);
      w.WriteLong("login",(long)AccountInfoInteger(ACCOUNT_LOGIN));
      w.WriteString("server",AccountInfoString(ACCOUNT_SERVER));
      w.WriteString("terminal_name",TerminalInfoString(TERMINAL_NAME));
      w.WriteString("terminal_company",TerminalInfoString(TERMINAL_COMPANY));
      w.WriteLong("terminal_build",(long)TerminalInfoInteger(TERMINAL_BUILD));
      w.EndObject();
      return w.ToString();
     }

   static bool WriteForensicReport(const string event_name)
     {
      string file_name="ISSX_forensics_"+m_state.session_id+".json";
      return ISSX_FileIO::WriteText(file_name,BuildForensicJson(event_name));
     }

   static void LogDeinit(const int reason)
     {
      const string reason_text=DeinitReasonToString(reason);
      Print("ISSX FORENSICS: deinit reason=",reason," (",reason_text,")"
            ," cycle=",m_state.cycle_no
            ," last_stage_entered=",m_state.last_stage_entered
            ," last_stage_completed=",m_state.last_stage_completed
            ," last_error_context=",m_state.last_error_context
            ," last_error_code=",m_state.last_error_code
            ," timer_active=",m_state.timer_active
            ," kernel_busy=",m_state.kernel_busy
            ," last_cycle_elapsed_ms=",m_state.last_cycle_elapsed_ms);
      WriteForensicReport("deinit_"+reason_text);
     }
  };

ISSX_ForensicState ISSX_DebugEngine::m_state;

#define ISSX_BREADCRUMB_STAGE_ENTER(name) ISSX_DebugEngine::StageEnter(name)
#define ISSX_BREADCRUMB_STAGE_DONE(name)  ISSX_DebugEngine::StageDone(name)
#define ISSX_BREADCRUMB_FUNC(name)        ISSX_DebugEngine::MarkFunction(name)
#define ISSX_BREADCRUMB_FILE(path)        ISSX_DebugEngine::MarkFile(path)
#define ISSX_BREADCRUMB_ERROR(ctx)        ISSX_DebugEngine::MarkError(ctx,GetLastError())

#endif // __ISSX_DEBUG_ENGINE_MQH__
