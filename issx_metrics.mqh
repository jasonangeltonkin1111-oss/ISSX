#ifndef __ISSX_METRICS_MQH__
#define __ISSX_METRICS_MQH__

#include <ISSX/issx_core.mqh>

// ISSX METRICS v1.724

struct ISSX_MetricStage
  {
   long stage_latency_ms;
   long throughput_items_per_slice;
   long hydration_bars;
   long export_size_bytes;

   // Backward-compatible alias for legacy surfaces that still read the old name.
   long hydration_rate_bps;

   void Reset()
     {
      stage_latency_ms=ISSX_NUMERIC_UNKNOWN_LONG;
      throughput_items_per_slice=ISSX_NUMERIC_UNKNOWN_LONG;
      hydration_bars=ISSX_NUMERIC_UNKNOWN_LONG;
      export_size_bytes=ISSX_NUMERIC_UNKNOWN_LONG;
     }

   // Backward-compatible field views (legacy metric naming).
   long ThroughputSymbols() const { return throughput_items_per_slice; }
   long HydrationRateBps() const { return hydration_bars; }
  };

class ISSX_MetricsBook
  {
private:
   ISSX_MetricStage m_rows[ISSX_STAGE_COUNT];

   static long NormalizeNonNegativeLong(const long value)
     {
      if(value<0)
         return 0;
      return value;
     }

   int Idx(const ISSX_StageId stage_id) const
     {
      return ISSX_Stage::ToStageIndex(stage_id);
     }

public:
   void Reset()
     {
      for(int i=0;i<ISSX_STAGE_COUNT;i++)
         m_rows[i].Reset();
     }

   void RecordLatency(const ISSX_StageId stage_id,const long ms)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].stage_latency_ms=NormalizeNonNegativeLong(ms);
     }

   void RecordThroughput(const ISSX_StageId stage_id,const long items_per_slice)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].throughput_items_per_slice=items_per_slice;
     }

   void RecordHydrationBars(const ISSX_StageId stage_id,const long bars)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].hydration_bars=bars;
     }

   void RecordExportSize(const ISSX_StageId stage_id,const long bytes)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].export_size_bytes=NormalizeNonNegativeLong(bytes);
     }

   // Backward-compatible aliases.
   void RecordHydrationRateBps(const ISSX_StageId stage_id,const long bars) { RecordHydrationBars(stage_id,bars); }
   void RecordCopyRates(const ISSX_StageId stage_id,const long bars) { RecordHydrationBars(stage_id,bars); }
   void RecordPayloadSize(const ISSX_StageId stage_id,const long bytes) { RecordExportSize(stage_id,bytes); }

   ISSX_MetricStage Get(const ISSX_StageId stage_id) const
     {
      const int i=Idx(stage_id);
      ISSX_MetricStage r;
      r.Reset();
      if(i>=0)
         r=m_rows[i];
      return r;
     }
  };

#endif
