#ifndef __ISSX_METRICS_MQH__
#define __ISSX_METRICS_MQH__

#include <ISSX/issx_core.mqh>

// ISSX METRICS v1.723

struct ISSX_MetricStage
  {
   long stage_latency_ms;
   long throughput_symbols;
   long hydration_rate_bps;
   long export_size_bytes;

   void Reset()
     {
      stage_latency_ms=0;
      throughput_symbols=0;
      hydration_rate_bps=0;
      export_size_bytes=0;
     }
  };

class ISSX_MetricsBook
  {
private:
   ISSX_MetricStage m_rows[5];

   int Idx(const ISSX_StageId stage_id) const
     {
      const int i=(int)stage_id-1;
      if(i<0 || i>=5)
         return -1;
      return i;
     }

public:
   void Reset()
     {
      for(int i=0;i<5;i++)
         m_rows[i].Reset();
     }

   void RecordLatency(const ISSX_StageId stage_id,const long ms)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].stage_latency_ms=ms;
     }

   void RecordThroughput(const ISSX_StageId stage_id,const long symbols)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].throughput_symbols=symbols;
     }

   void RecordHydrationRateBps(const ISSX_StageId stage_id,const long bps)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].hydration_rate_bps=bps;
     }

   void RecordExportSize(const ISSX_StageId stage_id,const long bytes)
     {
      const int i=Idx(stage_id);
      if(i>=0)
         m_rows[i].export_size_bytes=bytes;
     }

   // Backward-compatible aliases.
   void RecordCopyRates(const ISSX_StageId stage_id,const long bars) { RecordHydrationRateBps(stage_id,bars); }
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
