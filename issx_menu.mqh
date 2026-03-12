#ifndef __ISSX_MENU_MQH__
#define __ISSX_MENU_MQH__

#include <ISSX/issx_core.mqh>

#define ISSX_MENU_STAGE_COUNT 5

// ISSX MENU ENGINE v1.722

class ISSX_MenuEngine
  {
private:
   string m_prefix;
   string m_last_error;

   string Obj(const string key) const
     {
      return m_prefix+"_"+key;
     }

   bool EnsureLabel(const string name,
                    const int x,
                    const int y,
                    const string text,
                    const color clr,
                    const int size=8,
                    const bool bold=false)
     {
      if(ObjectFind(0,name)<0)
        {
         if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
           {
            m_last_error="create_label_failed";
            return false;
           }
        }

      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
      ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,name,OBJPROP_FONT,(bold?"Consolas Bold":"Consolas"));
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      return true;
     }

   bool EnsureButton(const string name,
                     const int x,
                     const int y,
                     const int w,
                     const int h,
                     const string text,
                     const color bg,
                     const color fg=clrWhite)
     {
      if(ObjectFind(0,name)<0)
        {
         if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
           {
            m_last_error="create_button_failed";
            return false;
           }
        }

      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
      ObjectSetInteger(0,name,OBJPROP_COLOR,fg);
      ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_STATE,false);
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      return true;
     }

   bool RenderStageSection(const int stage_index,
                           const int base_x,
                           const int top_y,
                           const string title,
                           const string line1,
                           const string line2,
                           const string line3,
                           const string line4,
                           const string line5,
                           const bool enabled,
                           const bool allow_toggle)
     {
      const string idx=IntegerToString(stage_index+1);
      const string button_name=Obj("STAGE_BTN_"+idx);
      const string title_name=Obj("STAGE_TITLE_"+idx);
      const string line_name_1=Obj("STAGE_LINE_"+idx+"_1");
      const string line_name_2=Obj("STAGE_LINE_"+idx+"_2");
      const string line_name_3=Obj("STAGE_LINE_"+idx+"_3");
      const string line_name_4=Obj("STAGE_LINE_"+idx+"_4");
      const string line_name_5=Obj("STAGE_LINE_"+idx+"_5");

      const color state_bg=(enabled ? clrDarkGreen : clrDimGray);
      const string state_text=(enabled?"ON":"OFF");
      const string button_text=title+" ["+state_text+"]"+(allow_toggle?"":" (locked)");

      if(!EnsureButton(button_name,base_x,top_y,208,16,button_text,state_bg))
         return false;
      if(!EnsureLabel(title_name,base_x+6,top_y+2,title,clrAqua,8,true))
         return false;

      if(!EnsureLabel(line_name_1,base_x+12,top_y+19,"- "+line1,clrSilver,7))
         return false;
      if(!EnsureLabel(line_name_2,base_x+12,top_y+31,"- "+line2,clrSilver,7))
         return false;
      if(!EnsureLabel(line_name_3,base_x+12,top_y+43,"- "+line3,clrSilver,7))
         return false;
      if(!EnsureLabel(line_name_4,base_x+12,top_y+55,"- "+line4,clrSilver,7))
         return false;
      if(!EnsureLabel(line_name_5,base_x+12,top_y+67,"- "+line5,clrSilver,7))
         return false;

      return true;
     }

public:
   void Init(const string unique_prefix)
     {
      m_prefix=unique_prefix;
      m_last_error="";
     }

   bool Build(const bool &enabled[])
     {
      m_last_error="";
      if(StringLen(m_prefix)==0)
        {
         m_last_error="menu_prefix_missing";
         return false;
        }

      if(ArraySize(enabled)<ISSX_MENU_STAGE_COUNT)
        {
         m_last_error="enabled_array_too_small";
         return false;
        }

      if(!EnsureLabel(Obj("TITLE"),8,145,"ISSX SYSTEM",clrGold,9,true))
         return false;

      int y=162;
      if(!RenderStageSection(0,8,y,"ISSX EA1 MARKET",
                             "Discovery",
                             "Cadence",
                             "Universe",
                             "Publish",
                             "Projection",
                             enabled[0],
                             false))
         return false;

      y+=86;
      if(!RenderStageSection(1,8,y,"ISSX EA2 HISTORY",
                             "Hydration",
                             "Readiness",
                             "Sync Status",
                             "Pipeline Input",
                             "Publish",
                             enabled[1],
                             true))
         return false;

      y+=86;
      if(!RenderStageSection(2,8,y,"ISSX EA3 SELECTION",
                             "Candidate Input",
                             "Frontier",
                             "Reserve",
                             "Continuity",
                             "Publish",
                             enabled[2],
                             true))
         return false;

      y+=86;
      if(!RenderStageSection(3,8,y,"ISSX EA4 CORRELATION",
                             "Pair Bounds",
                             "Correlation Results",
                             "Overlap",
                             "Permissions",
                             "Publish",
                             enabled[3],
                             true))
         return false;

      y+=86;
      if(!RenderStageSection(4,8,y,"ISSX EA5 CONTRACTS",
                             "Payload Build",
                             "Export Status",
                             "Schema",
                             "Freshness",
                             "Publish",
                             enabled[4],
                             true))
         return false;

      return true;
     }

   bool IsOwnedObject(const string object_name) const
     {
      if(StringLen(m_prefix)==0)
         return false;
      string owned_prefix=m_prefix+"_";
      const int owned_prefix_len=StringLen(owned_prefix);
      if(StringLen(object_name)<=owned_prefix_len)
         return false;
      return (StringSubstr(object_name,0,owned_prefix_len)==owned_prefix);
     }

   bool HandleClick(const string object_name,bool &enabled[],const bool allow_toggle=true)
     {
      m_last_error="";
      if(StringLen(m_prefix)==0)
        {
         m_last_error="prefix_missing";
         return false;
        }

      if(ArraySize(enabled)<ISSX_MENU_STAGE_COUNT)
        {
         m_last_error="enabled_array_too_small";
         return false;
        }

      if(!IsOwnedObject(object_name))
        {
         m_last_error="object_not_owned";
         return false;
        }

      const string owned_key=StringSubstr(object_name,StringLen(m_prefix)+1);
      if(StringFind(owned_key,"STAGE_BTN_")!=0)
        {
         m_last_error="object_not_actionable";
         return false;
        }

      const string row_token=StringSubstr(owned_key,10);
      const int row=(int)StringToInteger(row_token);
      if(StringLen(row_token)==0 || IntegerToString(row)!=row_token || row<1 || row>ISSX_MENU_STAGE_COUNT)
        {
         m_last_error="invalid_stage_token";
         return false;
        }

      if(!allow_toggle)
        {
         m_last_error="isolation_locked";
         return false;
        }

      const int idx=row-1;
      if(idx==0)
        {
         m_last_error="ea1_foundation_lock";
         return false;
        }

      enabled[idx]=!enabled[idx];
      return true;
     }

   string LastError() const { return m_last_error; }

   void Destroy()
     {
      if(StringLen(m_prefix)==0)
         return;

      ObjectDelete(0,Obj("TITLE"));
      for(int i=0;i<ISSX_MENU_STAGE_COUNT;i++)
        {
         const string idx=IntegerToString(i+1);
         ObjectDelete(0,Obj("STAGE_BTN_"+idx));
         ObjectDelete(0,Obj("STAGE_TITLE_"+idx));
         for(int j=1;j<=5;j++)
            ObjectDelete(0,Obj("STAGE_LINE_"+idx+"_"+IntegerToString(j)));
        }
     }
  };

#endif
