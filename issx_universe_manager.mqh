#ifndef __ISSX_UNIVERSE_MANAGER_MQH__
#define __ISSX_UNIVERSE_MANAGER_MQH__

#include <ISSX/issx_core.mqh>

// ISSX UNIVERSE MANAGER v1.722

class ISSX_UniverseManager
  {
public:
   static void SortSymbols(string &symbols[])
     {
      const int n=ArraySize(symbols);
      for(int i=0;i<n-1;i++)
        {
         int best=i;
         for(int j=i+1;j<n;j++)
           {
            if(StringCompare(symbols[j],symbols[best])<0)
               best=j;
           }
         if(best!=i)
           {
            string tmp=symbols[i];
            symbols[i]=symbols[best];
            symbols[best]=tmp;
           }
        }
     }

   static void UniqueInPlace(string &symbols[])
     {
      SortSymbols(symbols);
      const int n=ArraySize(symbols);
      if(n<=1)
         return;

      int w=1;
      for(int i=1;i<n;i++)
        {
         if(symbols[i]==symbols[w-1])
            continue;
         symbols[w]=symbols[i];
         w++;
        }
      ArrayResize(symbols,w);
     }

   static int FrontierCount(const int total,const int cap)
     {
      if(total<=0)
         return 0;
      if(cap<=0)
         return total;
      return MathMin(total,cap);
     }
  };

#endif
