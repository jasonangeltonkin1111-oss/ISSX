#ifndef __ISSX_MENU_MQH__
#define __ISSX_MENU_MQH__

#define ISSX_MENU_ROWS 5

// ISSX MENU ENGINE v1.707

class ISSX_MenuEngine
  {
private:
   string m_prefix;
   string m_last_error;

   string Obj(const string key) const
     {
      return m_prefix+"_"+key;
     }

   void CreateLabel(const string name,const int x,const int y,const string text,const color clr,const int size=9)
     {
      if(ObjectFind(0,name)<0)
        {
         if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
            return;
        }
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
      ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
      ObjectSetString(0,name,OBJPROP_TEXT,text);
     }

   void CreateButton(const string name,const int x,const int y,const int w,const int h,const string text,const color bg)
     {
      if(ObjectFind(0,name)<0)
        {
         if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
            return;
        }
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_STATE,false);
     }

public:
   void Init(const string unique_prefix)
     {
      m_prefix=unique_prefix;
      m_last_error="";
     }

   bool Build(const bool &enabled[])
     {
      if(StringLen(m_prefix)==0)
        {
         m_last_error="menu_prefix_missing";
         return false;
        }

      CreateLabel(Obj("TITLE"),12,10,"ISSX 5-EA Control",clrAqua,10);
      for(int i=0;i<ISSX_MENU_ROWS;i++)
        {
         const int y=34+(i*44);
         string row=IntegerToString(i+1);
         string name="EA"+row;
         string state=(enabled[i] ? "ON" : "OFF");
         color bg=(enabled[i] ? clrDarkGreen : clrMaroon);

         CreateButton(Obj("TOGGLE_"+row),12,y,90,18,name+" "+state,bg);
         CreateLabel(Obj("SUB_"+row),110,y+2,"submenu: runtime status + diagnostics",clrSilver,8);
        }
      return true;
     }

   bool HandleClick(const string object_name,bool &enabled[],const bool allow_toggle=true)
     {
      m_last_error="";
      if(StringLen(m_prefix)==0)
        {
         m_last_error="prefix_missing";
         return false;
        }

      string owned_prefix=m_prefix+"_";
      int owned_prefix_len=StringLen(owned_prefix);
      if(StringLen(object_name)<=owned_prefix_len || StringSubstr(object_name,0,owned_prefix_len)!=owned_prefix)
        {
         m_last_error="object_not_owned";
         return false;
        }

      string owned_key=StringSubstr(object_name,owned_prefix_len);
      if(StringFind(owned_key,"TOGGLE_")!=0)
        {
         m_last_error="object_not_owned";
         return false;
        }

      string row_token=StringSubstr(owned_key,7);
      int row=(int)StringToInteger(row_token);
      if(StringLen(row_token)==0 || IntegerToString(row)!=row_token || row<1 || row>ISSX_MENU_ROWS)
        {
         m_last_error="invalid_toggle_state";
         return false;
        }

      if(!allow_toggle)
        {
         m_last_error="isolation_locked";
         return false;
        }

      int idx=row-1;
      enabled[idx]=!enabled[idx];
      return true;
     }

   string LastError() const { return m_last_error; }

   void Destroy()
     {
      if(StringLen(m_prefix)==0)
         return;
      ObjectDelete(0,Obj("TITLE"));
      for(int i=0;i<ISSX_MENU_ROWS;i++)
        {
         string row=IntegerToString(i+1);
         ObjectDelete(0,Obj("TOGGLE_"+row));
         ObjectDelete(0,Obj("SUB_"+row));
        }
     }
  };

#endif
