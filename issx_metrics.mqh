#ifndef __ISSX_METRICS_MQH__
#define __ISSX_METRICS_MQH__

#include <ISSX/issx_core.mqh>

// ISSX METRICS v1.724

struct ISSX_MetricStage
  {
   long stage_latency_ms;
   long throughput_symbols;
   long hydration_bars;
   long export_size_bytes;

   // Backward-compatible alias for legacy surfaces that still read the old name.
   long hydration_rate_bps;

   void Reset()
     {
      stage_latency_ms=0;
      throughput_symbols=0;
      hydration_bars=0;
      export_size_bytes=0;
      hydration_rate_bps=0;
     }

   void SetHydrationBars(const long bars)
     {
      const long normalized=(bars<0 ? 0 : bars);
      hydration_bars=normalized;
      // Keep the deprecated field mirrored so older consumers stay truthful.
      hydration_rate_bps=normalized;
     }
  };

class ISSX_MetricsBook
  {
private:
   ISSX_MetricStage m_rows[ISSX_STAGE_COUNT];

   int Idx(const ISSX_StageId stage_id) const
     {
      return ISSX_Stage::ToStageIndex(stage_id);
     }

   static long NormalizeNonNegative(const long value)
     {
      return (value<0 ? 0 : value);
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
         m_rows[i].stage_latency_ms=NormalizeNonNegative(ms);
     }

   void RecordThroughput(const ISSX_StageId stage_id,const long symbols)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].throughput_symbols=NormalizeNonNegative(symbols);
     }

   // Hydration is a bars-count dimension, not bytes/sec.
   void RecordHydrationBars(const ISSX_StageId stage_id,const long bars)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].SetHydrationBars(bars);
     }

   void RecordHydrationRateBps(const ISSX_StageId stage_id,const long bars)
     {
      RecordHydrationBars(stage_id,bars);
     }

   void RecordExportSize(const ISSX_StageId stage_id,const long bytes)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].export_size_bytes=NormalizeNonNegative(bytes);
     }

   // Backward-compatible aliases.
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
