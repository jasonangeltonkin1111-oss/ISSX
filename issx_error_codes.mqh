#ifndef __ISSX_ERROR_CODES_MQH__
#define __ISSX_ERROR_CODES_MQH__

#include <ISSX/issx_core.mqh>

// ISSX ERROR CODES v1.723
// Canonical error codes are defined in issx_core.mqh (ISSX_ErrorCode enum).
// Keep a single canonical enum source to prevent duplicated code definitions.

bool ISSX_IsCanonicalErrorCode(const ISSX_ErrorCode code)
  {
   switch(code)
     {
      case ISSX_ERR_NONE:
      case ISSX_ERR_SYMBOL_DISCOVERY:
      case ISSX_ERR_INVALID_SYMBOL:
      case ISSX_ERR_COPYRATES:
      case ISSX_ERR_HISTORY_NOT_READY:
      case ISSX_ERR_MEMORY_ALLOC:
      case ISSX_ERR_JSON_BUILD:
      case ISSX_ERR_FILE_WRITE:
      case ISSX_ERR_STAGE_DISABLED:
      case ISSX_ERR_STAGE_SKIPPED:
      case ISSX_ERR_RUNTIME_LIMIT:
      case ISSX_ERR_TIMEOUT:
      case ISSX_ERR_UNKNOWN:
         return true;
     }
   return false;
  }

string ISSX_ErrorToMessage(const ISSX_ErrorCode code)
  {
   switch(code)
     {
      case ISSX_ERR_NONE:              return "No error.";
      case ISSX_ERR_SYMBOL_DISCOVERY:  return "Failed to discover required trading symbol data.";
      case ISSX_ERR_INVALID_SYMBOL:    return "Trading symbol is invalid or unavailable.";
      case ISSX_ERR_COPYRATES:         return "Rate copy/read operation failed.";
      case ISSX_ERR_HISTORY_NOT_READY: return "History data is not ready yet.";
      case ISSX_ERR_MEMORY_ALLOC:      return "Memory allocation failed.";
      case ISSX_ERR_JSON_BUILD:        return "Failed to build JSON payload.";
      case ISSX_ERR_FILE_WRITE:        return "Failed to write output file.";
      case ISSX_ERR_STAGE_DISABLED:    return "Pipeline stage is disabled.";
      case ISSX_ERR_STAGE_SKIPPED:     return "Pipeline stage was skipped.";
      case ISSX_ERR_RUNTIME_LIMIT:     return "Runtime limit exceeded.";
      case ISSX_ERR_TIMEOUT:           return "Operation timed out.";
      case ISSX_ERR_UNKNOWN:           return "Unknown error.";
     }
   return "Unknown error code.";
  }

#endif
