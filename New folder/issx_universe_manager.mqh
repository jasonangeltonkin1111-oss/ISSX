#ifndef __ISSX_UNIVERSE_MANAGER_MQH__
#define __ISSX_UNIVERSE_MANAGER_MQH__

#include <ISSX/issx_core.mqh>

// ISSX UNIVERSE MANAGER v1.723

class ISSX_UniverseManager
  {
public:
   static string CanonicalSymbol(const string symbol)
     {
      string out=symbol;
      const int n=StringLen(out);

      int start=0;
      while(start<n)
        {
         const ushort c=(ushort)StringGetCharacter(out,start);
         if(c!=' ' && c!='\t' && c!='\r' && c!='\n')
            break;
         start++;
        }

      int end=n-1;
      while(end>=start)
        {
         const ushort c=(ushort)StringGetCharacter(out,end);
         if(c!=' ' && c!='\t' && c!='\r' && c!='\n')
            break;
         end--;
        }

      if(start>0 || end<n-1)
         out=(end>=start ? StringSubstr(out,start,end-start+1) : "");

      StringToUpper(out);
      return out;
     }

   static bool IsSameCanonicalSymbol(const string a,const string b)
     {
      return CanonicalSymbol(a)==CanonicalSymbol(b);
     }

   static int CompareSymbols(const string a,const string b)
     {
      const string ca=CanonicalSymbol(a);
      const string cb=CanonicalSymbol(b);
      const int primary=StringCompare(ca,cb);
      if(primary!=0)
         return primary;
      return StringCompare(a,b);
     }

   static void SortSymbols(string &symbols[])
     {
      const int n=ArraySize(symbols);
      for(int i=1;i<n;i++)
        {
         string key=symbols[i];
         int j=i-1;
         while(j>=0 && CompareSymbols(symbols[j],key)>0)
           {
            symbols[j+1]=symbols[j];
            j--;
           }
         symbols[j+1]=key;
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
         if(IsSameCanonicalSymbol(symbols[i],symbols[w-1]))
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
