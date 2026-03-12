#ifndef __ISSX_UNIVERSE_MANAGER_MQH__
#define __ISSX_UNIVERSE_MANAGER_MQH__

#include <ISSX/issx_core.mqh>

// ============================================================================
// ISSX UNIVERSE MANAGER v1.718
// Canonical symbol-universe infrastructure shared by wrapper and stage handoff.
// ============================================================================

#define ISSX_UNIVERSE_MANAGER_MODULE_VERSION "1.718"

class ISSX_UniverseManager
  {
private:
   string            m_universe[];
   string            m_frontier[];
   string            m_selected[];

   static string NormalizeOne(const string symbol)
     {
      return ISSX_Util::Upper(ISSX_Util::Trim(symbol));
     }

   static void NormalizeArray(string &io_symbols[])
     {
      const int n=ArraySize(io_symbols);
      for(int i=0;i<n;i++)
         io_symbols[i]=NormalizeOne(io_symbols[i]);
     }

   static int CompactNonEmpty(string &io_symbols[])
     {
      const int n=ArraySize(io_symbols);
      int used=0;
      for(int i=0;i<n;i++)
        {
         if(StringLen(io_symbols[i])<=0)
            continue;
         io_symbols[used++]=io_symbols[i];
        }
      ArrayResize(io_symbols,used);
      return used;
     }

   static int SortUnique(string &io_symbols[])
     {
      int n=CompactNonEmpty(io_symbols);
      if(n<=1)
         return n;

      ArraySort(io_symbols);
      int used=1;
      for(int i=1;i<n;i++)
        {
         if(io_symbols[i]==io_symbols[used-1])
            continue;
         io_symbols[used++]=io_symbols[i];
        }
      ArrayResize(io_symbols,used);
      return used;
     }

   static int CopyIn(const string &source[],string &target[])
     {
      const int n=ArraySize(source);
      ArrayResize(target,n);
      for(int i=0;i<n;i++)
         target[i]=source[i];
      return n;
     }

public:
   void Reset()
     {
      ArrayResize(m_universe,0);
      ArrayResize(m_frontier,0);
      ArrayResize(m_selected,0);
     }

   int SetUniverse(const string &symbols[])
     {
      CopyIn(symbols,m_universe);
      NormalizeSymbols(m_universe);
      FilterSymbols(m_universe);
      SortUniverse();
      return ArraySize(m_universe);
     }

   int SetFrontier(const string &symbols[])
     {
      CopyIn(symbols,m_frontier);
      NormalizeSymbols(m_frontier);
      FilterSymbols(m_frontier);
      SortAndDedupe(m_frontier);
      return ArraySize(m_frontier);
     }

   int SetSelected(const string &symbols[])
     {
      CopyIn(symbols,m_selected);
      NormalizeSymbols(m_selected);
      FilterSymbols(m_selected);
      SortAndDedupe(m_selected);
      return ArraySize(m_selected);
     }

   int GetAllSymbols(string &out_symbols[])
     {
      CopyIn(m_universe,out_symbols);
      return ArraySize(out_symbols);
     }

   int GetFrontier(string &out_symbols[])
     {
      if(ArraySize(m_frontier)<=0)
         return GetAllSymbols(out_symbols);
      CopyIn(m_frontier,out_symbols);
      return ArraySize(out_symbols);
     }

   int GetSelected(string &out_symbols[])
     {
      CopyIn(m_selected,out_symbols);
      return ArraySize(out_symbols);
     }

   int SortUniverse()
     {
      return SortAndDedupe(m_universe);
     }

   int SortAndDedupe(string &io_symbols[])
     {
      return SortUnique(io_symbols);
     }

   int FilterSymbols(string &io_symbols[])
     {
      return CompactNonEmpty(io_symbols);
     }

   void NormalizeSymbols(string &io_symbols[])
     {
      NormalizeArray(io_symbols);
     }
  };

#endif // __ISSX_UNIVERSE_MANAGER_MQH__
