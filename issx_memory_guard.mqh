#ifndef __ISSX_MEMORY_GUARD_MQH__
#define __ISSX_MEMORY_GUARD_MQH__

#include <ISSX/issx_core.mqh>

// ============================================================================
// ISSX MEMORY GUARD v1.732
// Lightweight, non-blocking runtime guardrails for allocation/loop diagnostics.
// Adds bounded rolling retention, duplicate prevention, corruption checks,
// array safety helpers, and long-session cleanup telemetry.
// ============================================================================

#define ISSX_MEMORY_GUARD_MODULE_VERSION "1.732"

#define ISSX_MEMORY_GUARD_MAX_SAFE_SYMBOLS            2000
#define ISSX_MEMORY_GUARD_MAX_SAFE_PAYLOAD_BYTES      5242880
#define ISSX_MEMORY_GUARD_MAX_SAFE_ARRAY_RESIZE       5000
#define ISSX_MEMORY_GUARD_MAX_SAFE_LOOP_ITERATIONS    100000

#define ISSX_MEMORY_GUARD_MAX_SNAPSHOTS_DEFAULT       256
#define ISSX_MEMORY_GUARD_MAX_NAME_LEN                96

struct ISSX_MemorySnapshotMeta
  {
   datetime timestamp;
   string   fingerprint;
   int      bytes;
   bool     valid;

   void Reset()
     {
      timestamp=0;
      fingerprint="";
      bytes=0;
      valid=false;
     }
  };

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
   uint  m_last_corruption_warn_cycle;

   // memory health counters
   int      m_active_snapshots;
   int      m_dropped_snapshots;
   int      m_duplicate_snapshots_blocked;
   int      m_invalid_snapshots_purged;
   int      m_max_observed_buffer_size;
   datetime m_latest_cleanup_time;

   // bounded rolling snapshot registry
   ISSX_MemorySnapshotMeta m_snapshots[];
   int                     m_snapshot_count;
   int                     m_snapshot_capacity;

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

   void LogCorruptionWarning(const string reason)
     {
      if(m_last_corruption_warn_cycle==m_cycle_id)
         return;
      m_last_corruption_warn_cycle=m_cycle_id;
      Print("[memory_guard] corruption reason=",reason,
            " active_snapshots=",m_active_snapshots,
            " dropped=",m_dropped_snapshots,
            " purged=",m_invalid_snapshots_purged,
            " cycle=",(int)m_cycle_id);
     }

   void UpdateSnapshotCounters()
     {
      m_active_snapshots=m_snapshot_count;
      if(m_active_snapshots>m_max_observed_buffer_size)
         m_max_observed_buffer_size=m_active_snapshots;
     }

   bool EnsureSnapshotCapacity(const int wanted)
     {
      if(wanted<0)
         return false;

      const int bounded=MathMax(0,MathMin(wanted,m_snapshot_capacity));
      const int resized=ArrayResize(m_snapshots,bounded);
      if(resized!=bounded)
         return false;

      return true;
     }

   void ShiftSnapshotsLeft(const int from_index,const int shift_by)
     {
      if(shift_by<=0 || from_index<0 || from_index>=m_snapshot_count)
         return;

      for(int i=from_index;i<m_snapshot_count-shift_by;i++)
         m_snapshots[i]=m_snapshots[i+shift_by];
     }

   bool IsDuplicateSnapshot(const datetime ts,const string fingerprint) const
     {
      if(m_snapshot_count<=0)
         return false;

      ISSX_MemorySnapshotMeta last=m_snapshots[m_snapshot_count-1];
      if(!last.valid)
         return false;

      return (last.timestamp==ts && last.fingerprint==fingerprint);
     }

   bool HasTimestampRegression(const datetime ts) const
     {
      if(m_snapshot_count<=0)
         return false;

      ISSX_MemorySnapshotMeta last=m_snapshots[m_snapshot_count-1];
      if(!last.valid)
         return false;

      return (ts>0 && last.timestamp>0 && ts<last.timestamp);
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
      m_last_corruption_warn_cycle=0;

      m_active_snapshots=0;
      m_dropped_snapshots=0;
      m_duplicate_snapshots_blocked=0;
      m_invalid_snapshots_purged=0;
      m_max_observed_buffer_size=0;
      m_latest_cleanup_time=0;

      m_snapshot_count=0;
      m_snapshot_capacity=ISSX_MEMORY_GUARD_MAX_SNAPSHOTS_DEFAULT;
      ArrayResize(m_snapshots,0);
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

   void ConfigureSnapshotCapacity(const int max_snapshots)
     {
      m_snapshot_capacity=MathMax(1,max_snapshots);

      if(m_snapshot_count>m_snapshot_capacity)
        {
         const int drop_count=m_snapshot_count-m_snapshot_capacity;
         ShiftSnapshotsLeft(0,drop_count);
         m_snapshot_count=m_snapshot_capacity;
         EnsureSnapshotCapacity(m_snapshot_count);
         m_dropped_snapshots+=drop_count;
        }

      UpdateSnapshotCounters();
     }

   bool IsValidIndex(const int index,const int size) const
     {
      if(size<=0)
         return false;
      return (index>=0 && index<size);
     }

   bool CanAccessArray(const int size) const
     {
      return (size>0);
     }

   bool GuardIndex(const string name,const int index,const int size) const
     {
      if(IsValidIndex(index,size))
         return true;

      Print("[memory_guard] array_bounds name=",name,
            " index=",index,
            " size=",size,
            " cycle=",(int)m_cycle_id);
      return false;
     }

   bool GuardResize(const string name,const int requested_size,const int resized_result)
     {
      TrackResize(name,requested_size);

      if(requested_size<0)
        {
         Print("[memory_guard] resize_fail name=",name,
               " requested=",requested_size,
               " reason=negative_size cycle=",(int)m_cycle_id);
         return false;
        }

      if(resized_result!=requested_size)
        {
         Print("[memory_guard] resize_fail name=",name,
               " requested=",requested_size,
               " actual=",resized_result,
               " cycle=",(int)m_cycle_id);
         return false;
        }

      return true;
     }

   void TrackResize(const string name,const int new_size)
     {
      m_total_array_resizes++;

      if(new_size>m_max_observed_buffer_size)
         m_max_observed_buffer_size=new_size;

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

      if(bytes>m_max_observed_buffer_size)
         m_max_observed_buffer_size=bytes;

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

   bool AddSnapshot(const datetime ts,const string fingerprint,const int bytes)
     {
      if(ts<=0)
        {
         LogCorruptionWarning("invalid_snapshot_timestamp");
         return false;
        }

      if(ISSX_Util::IsEmpty(fingerprint))
        {
         LogCorruptionWarning("empty_snapshot_fingerprint");
         return false;
        }

      if(bytes<0)
        {
         LogCorruptionWarning("negative_snapshot_bytes");
         return false;
        }

      if(IsDuplicateSnapshot(ts,fingerprint))
        {
         m_duplicate_snapshots_blocked++;
         return false;
        }

      if(HasTimestampRegression(ts))
        {
         LogCorruptionWarning("snapshot_time_regression");
         PurgeInvalidSnapshots();
        }

      if(m_snapshot_count>=m_snapshot_capacity)
        {
         if(m_snapshot_count>0)
           {
            ShiftSnapshotsLeft(0,1);
            m_snapshot_count--;
            m_dropped_snapshots++;
           }
        }

      const int wanted=m_snapshot_count+1;
      if(!EnsureSnapshotCapacity(wanted))
        {
         LogCorruptionWarning("snapshot_resize_failed");
         return false;
        }

      m_snapshots[m_snapshot_count].Reset();
      m_snapshots[m_snapshot_count].timestamp=ts;
      m_snapshots[m_snapshot_count].fingerprint=fingerprint;
      m_snapshots[m_snapshot_count].bytes=bytes;
      m_snapshots[m_snapshot_count].valid=true;
      m_snapshot_count++;

      UpdateSnapshotCounters();
      return true;
     }

   void PurgeInvalidSnapshots()
     {
      if(m_snapshot_count<=0)
        {
         m_latest_cleanup_time=TimeCurrent();
         UpdateSnapshotCounters();
         return;
        }

      int write_idx=0;
      datetime last_ts=0;

      for(int i=0;i<m_snapshot_count;i++)
        {
         if(!m_snapshots[i].valid)
           {
            m_invalid_snapshots_purged++;
            continue;
           }

         if(m_snapshots[i].timestamp<=0)
           {
            m_invalid_snapshots_purged++;
            continue;
           }

         if(last_ts>0 && m_snapshots[i].timestamp<last_ts)
           {
            m_invalid_snapshots_purged++;
            continue;
           }

         if(write_idx!=i)
            m_snapshots[write_idx]=m_snapshots[i];

         last_ts=m_snapshots[i].timestamp;
         write_idx++;
        }
        
if(write_idx<m_snapshot_count)
   LogCorruptionWarning("invalid_or_out_of_order_snapshots_purged");
   
      m_snapshot_count=write_idx;
      EnsureSnapshotCapacity(m_snapshot_count);
      m_latest_cleanup_time=TimeCurrent();
      UpdateSnapshotCounters();
     }

   void Cleanup()
     {
      PurgeInvalidSnapshots();
     }

   void ClearSnapshots()
     {
      m_snapshot_count=0;
      ArrayResize(m_snapshots,0);
      m_active_snapshots=0;
      m_latest_cleanup_time=TimeCurrent();
     }

   void OnDeinitCleanup()
     {
      ClearSnapshots();
      m_estimated_payload_bytes=0;
      m_total_array_resizes=0;
      m_total_allocations=0;
      m_large_allocation_warnings=0;
      m_loop_guard_hits=0;
     }

   int TotalArrayResizes() const { return m_total_array_resizes; }
   int TotalAllocations() const { return m_total_allocations; }
   int LargeAllocationWarnings() const { return m_large_allocation_warnings; }
   int LoopGuardHits() const { return m_loop_guard_hits; }
   long EstimatedPayloadBytes() const { return m_estimated_payload_bytes; }
   uint CycleId() const { return m_cycle_id; }

   int ActiveSnapshots() const { return m_active_snapshots; }
   int DroppedSnapshots() const { return m_dropped_snapshots; }
   int DuplicateSnapshotsBlocked() const { return m_duplicate_snapshots_blocked; }
   int InvalidSnapshotsPurged() const { return m_invalid_snapshots_purged; }
   int MaxObservedBufferSize() const { return m_max_observed_buffer_size; }
   datetime LatestCleanupTime() const { return m_latest_cleanup_time; }
   int SnapshotCount() const { return m_snapshot_count; }
   int SnapshotCapacity() const { return m_snapshot_capacity; }
  };

#endif // __ISSX_MEMORY_GUARD_MQH__