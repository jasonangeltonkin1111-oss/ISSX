#ifndef __ISSX_MEMORY_GUARD_MQH__
#define __ISSX_MEMORY_GUARD_MQH__

#include <ISSX/issx_core.mqh>

// ============================================================================
// ISSX MEMORY GUARD v1.718
// Lightweight, non-blocking runtime guardrails for allocation/loop diagnostics.
// ============================================================================

#define ISSX_MEMORY_GUARD_MAX_SAFE_SYMBOLS            2000
#define ISSX_MEMORY_GUARD_MAX_SAFE_PAYLOAD_BYTES      5242880
#define ISSX_MEMORY_GUARD_MAX_SAFE_ARRAY_RESIZE       5000
#define ISSX_MEMORY_GUARD_MAX_SAFE_LOOP_ITERATIONS    100000

class ISSX_MemoryGuard
  {
private:
   uint  m_cycle_id;
   int   m_total_array_resizes;
   int   m_total_allocations;
   int   m_large_allocation_warnings;
   int   m_loop_guard_hits;
   long  m_estimated_payload_bytes;

   uint  m_last_resize_warn_cycle;
   uint  m_last_payload_warn_cycle;
   uint  m_last_alloc_warn_cycle;
   uint  m_last_loop_warn_cycle;

   void LogResizeWarning(const string name,const int new_size)
     {
      if(m_last_resize_warn_cycle==m_cycle_id)
         return;
      m_last_resize_warn_cycle=m_cycle_id;
      Print("[memory_guard] resize name=",name," size=",new_size,
            " safe_resize=",ISSX_MEMORY_GUARD_MAX_SAFE_ARRAY_RESIZE,
            " safe_symbols=",ISSX_MEMORY_GUARD_MAX_SAFE_SYMBOLS,
            " cycle=",(int)m_cycle_id);
     }

   void LogPayloadWarning(const string name,const int bytes)
     {
      if(m_last_payload_warn_cycle==m_cycle_id)
         return;
      m_last_payload_warn_cycle=m_cycle_id;
      Print("[memory_guard] payload large name=",name," bytes=",bytes,
            " safe_bytes=",ISSX_MEMORY_GUARD_MAX_SAFE_PAYLOAD_BYTES,
            " cycle=",(int)m_cycle_id);
     }

   void LogAllocationWarning(const string name,const int bytes)
     {
      if(m_last_alloc_warn_cycle==m_cycle_id)
         return;
      m_last_alloc_warn_cycle=m_cycle_id;
      Print("[memory_guard] allocation large name=",name," bytes=",bytes,
            " safe_bytes=",ISSX_MEMORY_GUARD_MAX_SAFE_PAYLOAD_BYTES,
            " cycle=",(int)m_cycle_id);
     }

   void LogLoopWarning(const string name,const int iteration)
     {
      if(m_last_loop_warn_cycle==m_cycle_id)
         return;
      m_last_loop_warn_cycle=m_cycle_id;
      Print("[memory_guard] loop_guard name=",name," iteration=",iteration,
            " safe_iterations=",ISSX_MEMORY_GUARD_MAX_SAFE_LOOP_ITERATIONS,
            " cycle=",(int)m_cycle_id);
     }

public:
   ISSX_MemoryGuard()
     {
      m_cycle_id=0;
      m_total_array_resizes=0;
      m_total_allocations=0;
      m_large_allocation_warnings=0;
      m_loop_guard_hits=0;
      m_estimated_payload_bytes=0;
      m_last_resize_warn_cycle=0;
      m_last_payload_warn_cycle=0;
      m_last_alloc_warn_cycle=0;
      m_last_loop_warn_cycle=0;
     }

   void ResetCycle()
     {
      m_cycle_id++;
      m_total_array_resizes=0;
      m_total_allocations=0;
      m_large_allocation_warnings=0;
      m_loop_guard_hits=0;
      m_estimated_payload_bytes=0;

      if(m_cycle_id==0)
         m_cycle_id=1;
     }

   void TrackResize(const string name,const int new_size)
     {
      m_total_array_resizes++;

      if(new_size>ISSX_MEMORY_GUARD_MAX_SAFE_ARRAY_RESIZE ||
         new_size>ISSX_MEMORY_GUARD_MAX_SAFE_SYMBOLS)
         LogResizeWarning(name,new_size);
     }

   void EstimatePayload(const string name,const int bytes)
     {
      if(bytes<=0)
         return;

      m_estimated_payload_bytes+=(long)bytes;

      if(bytes>ISSX_MEMORY_GUARD_MAX_SAFE_PAYLOAD_BYTES ||
         m_estimated_payload_bytes>ISSX_MEMORY_GUARD_MAX_SAFE_PAYLOAD_BYTES)
         LogPayloadWarning(name,bytes);
     }

   void WarnIfLargeAllocation(const string name,const int bytes)
     {
      if(bytes<=0)
         return;

      m_total_allocations++;

      if(bytes>ISSX_MEMORY_GUARD_MAX_SAFE_PAYLOAD_BYTES)
        {
         m_large_allocation_warnings++;
         LogAllocationWarning(name,bytes);
        }
     }

   void LoopGuardCheck(const string name,const int iteration)
     {
      if(iteration<=ISSX_MEMORY_GUARD_MAX_SAFE_LOOP_ITERATIONS)
         return;

      m_loop_guard_hits++;

      const int delta=iteration-ISSX_MEMORY_GUARD_MAX_SAFE_LOOP_ITERATIONS;
      if(delta==1 || (delta%50000)==0)
         LogLoopWarning(name,iteration);
     }

   int TotalArrayResizes() const { return m_total_array_resizes; }
   int TotalAllocations() const { return m_total_allocations; }
   int LargeAllocationWarnings() const { return m_large_allocation_warnings; }
   int LoopGuardHits() const { return m_loop_guard_hits; }
   long EstimatedPayloadBytes() const { return m_estimated_payload_bytes; }
   uint CycleId() const { return m_cycle_id; }
  };

#endif // __ISSX_MEMORY_GUARD_MQH__
