#ifndef __ISSX_ERROR_CODES_MQH__
#define __ISSX_ERROR_CODES_MQH__

#include <ISSX/issx_core.mqh>

// ISSX ERROR CODES v1.724
// Canonical error codes are defined in issx_core.mqh (ISSX_ErrorCode enum).
// Keep a single canonical enum source to prevent duplicated code definitions.

bool ISSX_IsCanonicalErrorCode(const ISSX_ErrorCode code)
  {
   const int raw_code = (int)code;
   if(raw_code < (int)ISSX_ERR_NONE || raw_code > (int)ISSX_ERR_UNKNOWN)
      return false;

   if(code == ISSX_ERR_UNKNOWN)
      return true;

   return (ISSX_ErrorToString(code) != "unknown");
  }

bool ISSX_TryParseErrorCode(const string code_token, ISSX_ErrorCode &out_code)
  {
   if(code_token == "none")              { out_code = ISSX_ERR_NONE;              return true; }
   if(code_token == "symbol_discovery")  { out_code = ISSX_ERR_SYMBOL_DISCOVERY;  return true; }
   if(code_token == "invalid_symbol")    { out_code = ISSX_ERR_INVALID_SYMBOL;    return true; }
   if(code_token == "copyrates")         { out_code = ISSX_ERR_COPYRATES;         return true; }
   if(code_token == "history_not_ready") { out_code = ISSX_ERR_HISTORY_NOT_READY; return true; }
   if(code_token == "memory_alloc")      { out_code = ISSX_ERR_MEMORY_ALLOC;      return true; }
   if(code_token == "json_build")        { out_code = ISSX_ERR_JSON_BUILD;        return true; }
   if(code_token == "file_write")        { out_code = ISSX_ERR_FILE_WRITE;        return true; }
   if(code_token == "stage_disabled")    { out_code = ISSX_ERR_STAGE_DISABLED;    return true; }
   if(code_token == "stage_skipped")     { out_code = ISSX_ERR_STAGE_SKIPPED;     return true; }
   if(code_token == "runtime_limit")     { out_code = ISSX_ERR_RUNTIME_LIMIT;     return true; }
   if(code_token == "timeout")           { out_code = ISSX_ERR_TIMEOUT;           return true; }
   if(code_token == "unknown")           { out_code = ISSX_ERR_UNKNOWN;           return true; }

   out_code = ISSX_ERR_UNKNOWN;
   return false;
  }

string ISSX_ErrorToMessage(const ISSX_ErrorCode code)
  {
   switch(code)
     {
      case ISSX_ERR_NONE:              return "No error detected.";
      case ISSX_ERR_SYMBOL_DISCOVERY:  return "Symbol discovery failed: required broker symbol metadata could not be resolved.";
      case ISSX_ERR_INVALID_SYMBOL:    return "Symbol validation failed: symbol is invalid, disabled, or unavailable in Market Watch.";
      case ISSX_ERR_COPYRATES:         return "History read failed: CopyRates returned no usable data for the requested symbol/timeframe.";
      case ISSX_ERR_HISTORY_NOT_READY: return "History is not ready: terminal has not synchronized enough bars yet.";
      case ISSX_ERR_MEMORY_ALLOC:      return "Memory allocation failed while preparing runtime buffers or transient containers.";
      case ISSX_ERR_JSON_BUILD:        return "JSON serialization failed while building an export or diagnostics payload.";
      case ISSX_ERR_FILE_WRITE:        return "File write failed: output path is unavailable or write operation was rejected.";
      case ISSX_ERR_STAGE_DISABLED:    return "Stage execution bypassed: stage is disabled by configuration or gating policy.";
      case ISSX_ERR_STAGE_SKIPPED:     return "Stage execution skipped: upstream prerequisites or readiness checks were not met.";
      case ISSX_ERR_RUNTIME_LIMIT:     return "Runtime guard triggered: execution exceeded configured time or resource budget.";
      case ISSX_ERR_TIMEOUT:           return "Operation timed out before completion.";
      case ISSX_ERR_UNKNOWN:           return "Unknown error classification; inspect raw context for the originating failure.";
     }

   return "Non-canonical error code value; code is outside ISSX_ErrorCode ownership range.";
  }

string ISSX_ErrorToDisplay(const ISSX_ErrorCode code)
  {
   return StringFormat("%s (%d): %s", ISSX_ErrorToString(code), (int)code, ISSX_ErrorToMessage(code));
  }

#endif
