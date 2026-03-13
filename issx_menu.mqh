#ifndef __ISSX_MENU_MQH__
#define __ISSX_MENU_MQH__

#include <ISSX/issx_core.mqh>

#define ISSX_MENU_STAGE_COUNT 5
#define ISSX_MENU_MAX_ROWS    64

// ISSX MENU ENGINE v1.734

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

   bool AddSection(const string key,const string title,int &row)
     {
      if(row>=ISSX_MENU_MAX_ROWS)
         return false;
      if(!EnsureLabel(Obj("ROW_"+IntegerToString(row)+"_"+key),8,145+(row*13),"["+title+"]",clrGold,8,true))
         return false;
      row++;
      return true;
     }

   bool AddLine(const string key,const string text,int &row,const color clr=clrSilver)
     {
      if(row>=ISSX_MENU_MAX_ROWS)
         return false;
      if(!EnsureLabel(Obj("ROW_"+IntegerToString(row)+"_"+key),12,145+(row*13),text,clr,8,false))
         return false;
      row++;
      return true;
     }

   bool RenderStageButton(const int stage_index,const bool enabled,const bool allow_toggle)
     {
      const string idx=IntegerToString(stage_index+1);
      const string label=(stage_index==0?"EA1":"EA"+idx);
      const color state_bg=(enabled ? clrDarkGreen : clrDimGray);
      const string state_text=(enabled?"ON":"OFF");
      const string button_text=label+" ["+state_text+"]"+(allow_toggle?"":" (locked)");
      return EnsureButton(Obj("STAGE_BTN_"+idx),240,145+(stage_index*20),150,18,button_text,state_bg);
     }

public:
   void Init(const string unique_prefix)
     {
      m_prefix=unique_prefix;
      m_last_error="";
     }

   bool Build(const bool &enabled[],
              const string broker,
              const string server,
              const long login,
              const string instance_tag,
              const string runtime_state,
              const int ea1_max_symbols,
              const int ea1_hydration_batch,
              const int ea1_rolling_batch,
              const int ea1_rolling_cadence,
              const int ea1_publish_cadence,
              const bool proj_stage_status,
              const bool proj_universe,
              const bool proj_debug,
              const bool chart_ui_updates,
              const bool ui_projection,
              const bool runtime_scheduler,
              const int cycle_budget_ms,
              const bool tick_heavy,
              const bool isolation_mode)
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

      int row=0;
      if(!AddSection("SYSTEM","SYSTEM",row)) return false;
      if(!AddLine("SYS_1","broker="+broker,row)) return false;
      if(!AddLine("SYS_2","server="+server+" login="+ISSX_Util::LongToStringX(login),row)) return false;
      if(!AddLine("SYS_3","instance="+instance_tag,row)) return false;
      if(!AddLine("SYS_4","runtime_state="+runtime_state,row)) return false;

      if(!AddSection("STAGES","STAGES",row)) return false;
      if(!AddLine("STG_1","EA1="+(enabled[0]?"on":"off")+" EA2="+(enabled[1]?"on":"off")+" EA3="+(enabled[2]?"on":"off"),row)) return false;
      if(!AddLine("STG_2","EA4="+(enabled[3]?"on":"off")+" EA5="+(enabled[4]?"on":"off"),row)) return false;

      if(!AddSection("EA1","EA1 / HYDRATION",row)) return false;
      if(!AddLine("EA1_1","max_symbols="+IntegerToString(ea1_max_symbols),row)) return false;
      if(!AddLine("EA1_2","hydration_batch_size="+IntegerToString(ea1_hydration_batch),row)) return false;
      if(!AddLine("EA1_3","rolling_batch_size="+IntegerToString(ea1_rolling_batch),row)) return false;
      if(!AddLine("EA1_4","rolling_cadence="+IntegerToString(ea1_rolling_cadence)+"s publish_cadence="+IntegerToString(ea1_publish_cadence)+"s",row)) return false;

      if(!AddSection("PROJ","PROJECTION",row)) return false;
      if(!AddLine("PRJ_1","stage_status_root="+(proj_stage_status?"on":"off")+" universe_snapshot="+(proj_universe?"on":"off"),row)) return false;
      if(!AddLine("PRJ_2","debug_snapshots="+(proj_debug?"on":"off")+" hud_projection="+(ui_projection?"on":"off"),row)) return false;
      if(!AddLine("PRJ_3","chart_ui_updates="+(chart_ui_updates?"on":"off"),row)) return false;

      if(!AddSection("SCHED","SCHEDULER / RUNTIME",row)) return false;
      if(!AddLine("SCH_1","runtime_scheduler="+(runtime_scheduler?"on":"off")+" cycle_budget_ms="+IntegerToString(cycle_budget_ms),row)) return false;
      if(!AddLine("SCH_2","tick_heavy="+(tick_heavy?"on":"off")+" isolation_mode="+(isolation_mode?"on":"off"),row)) return false;

      for(int i=0;i<ISSX_MENU_STAGE_COUNT;i++)
        {
         if(!RenderStageButton(i,enabled[i],i>0 && !isolation_mode))
            return false;
        }

      return true;
     }

   bool IsOwnedObject(const string object_name) const
     {
      if(StringLen(m_prefix)==0)
         return false;
      string owned_prefix=m_prefix+"_";
      if(StringSubstr(object_name,0,StringLen(owned_prefix))!=owned_prefix)
         return false;
      return (ObjectFind(0,object_name)>=0);
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

      const int total=ObjectsTotal(0,-1,-1);
      for(int i=total-1;i>=0;i--)
        {
         const string name=ObjectName(0,i,-1,-1);
         if(StringFind(name,m_prefix+"_")==0)
            ObjectDelete(0,name);
        }
     }
  };

#endif
