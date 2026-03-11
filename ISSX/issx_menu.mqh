#ifndef __ISSX_MENU_MQH__
#define __ISSX_MENU_MQH__

#define ISSX_MENU_ROWS 5

class ISSX_MenuEngine
  {
private:
   string m_prefix;
   string m_last_error;

   string Obj(const string key) const
     {
      return m_prefix+"_"+key;
     }

   bool CreateLabel(const string name,const int x,const int y,const string text,const color clr,const int size=9)
     {
      if(ObjectFind(0,name)<0)
        {
         ResetLastError();
         if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
           {
            m_last_error="ObjectCreate label failed name="+name+" err="+IntegerToString(GetLastError());
            return false;
           }
        }
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
      ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      return true;
     }

   bool CreateButton(const string name,const int x,const int y,const int w,const int h,const string text,const color bg)
     {
      if(ObjectFind(0,name)<0)
        {
         ResetLastError();
         if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
           {
            m_last_error="ObjectCreate button failed name="+name+" err="+IntegerToString(GetLastError());
            return false;
           }
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
      return true;
     }

public:
   void Init(const string unique_prefix)
     {
      m_prefix=unique_prefix;
      m_last_error="";
     }

   string LastError() const { return m_last_error; }

   bool Build(const bool &enabled[])
     {
      m_last_error="";
      if(StringLen(m_prefix)==0)
        {
         m_last_error="Empty menu prefix";
         return false;
        }

      if(!CreateLabel(Obj("TITLE"),12,10,"ISSX 5-EA Control",clrAqua,10))
         return false;

      for(int i=0;i<ISSX_MENU_ROWS;i++)
        {
         const int y=34+(i*44);
         string row=IntegerToString(i+1);
         string name="EA"+row;
         string state=(enabled[i] ? "ON" : "OFF");
         color bg=(enabled[i] ? clrDarkGreen : clrMaroon);

         if(!CreateButton(Obj("TOGGLE_"+row),12,y,90,18,name+" "+state,bg))
            return false;
         if(!CreateLabel(Obj("SUB_"+row),110,y+2,"submenu: status + diagnostics",clrSilver,8))
            return false;
        }
      return true;
     }

   bool HandleClick(const string object_name,bool &enabled[],const bool allow_ea2_to_ea5_changes)
     {
      for(int i=0;i<ISSX_MENU_ROWS;i++)
        {
         string row=IntegerToString(i+1);
         if(object_name==Obj("TOGGLE_"+row))
           {
            if(i>0 && !allow_ea2_to_ea5_changes)
              {
               m_last_error="EA"+row+" toggle blocked by isolation mode";
               return false;
              }
            enabled[i]=!enabled[i];
            return true;
           }
        }
      return false;
     }

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
