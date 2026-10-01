//+------------------------------------------------------------------+
//|                                        TickVelocityDashboard.mq5 |
//|                                     Copyright 2026, Jhon A Yahya |
//+------------------------------------------------------------------+
#property copyright "Jhon A Yahya"
#property version   "1.21"
#property indicator_chart_window
#property indicator_plots 0

//--- Input Parameters
input int                   InpSeconds         = 10;                 // Waktu Ukur (detik)
input double                InpTPSThreshold    = 4.0;                // Batas Speed (Ticks/Sec)
input double                InpPPSThreshold    = 20.0;               // Batas Jarak (Points/Sec)
input ENUM_BASE_CORNER      InpCorner          = CORNER_RIGHT_UPPER; // Posisi Panel
input int                   InpXOffset         = 20;
input int                   InpYOffset         = 20;

//--- Nama-nama Object (GUI)
string prefix     = "TickVel_";
string obj_bg     = prefix + "BG";
string obj_title  = prefix + "Title";
string obj_status = prefix + "Status";
string obj_tps    = prefix + "TPS";
string obj_pps    = prefix + "PPS";

//+------------------------------------------------------------------+
//| Fungsi Membuat Label Teks                                        |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int font_size, color clr, bool bold = false)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Trebuchet MS Bold" : "Trebuchet MS");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Proteksi Anti-Crash: Cegah user memasukkan angka 0 detik
   if(InpSeconds <= 0)
     {
      Print("Error: Waktu Ukur (InpSeconds) tidak boleh 0!");
      return(INIT_PARAMETERS_INCORRECT);
     }

   // 1. Buat Background
   if(ObjectFind(0, obj_bg) < 0)
      ObjectCreate(0, obj_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      
   ObjectSetInteger(0, obj_bg, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, obj_bg, OBJPROP_XDISTANCE, InpXOffset);
   ObjectSetInteger(0, obj_bg, OBJPROP_YDISTANCE, InpYOffset);
   ObjectSetInteger(0, obj_bg, OBJPROP_XSIZE, 160);
   ObjectSetInteger(0, obj_bg, OBJPROP_YSIZE, 100); 
   ObjectSetInteger(0, obj_bg, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, obj_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, obj_bg, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, obj_bg, OBJPROP_BACK, false);
   ObjectSetInteger(0, obj_bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj_bg, OBJPROP_HIDDEN, true);

   // 2. Buat Teks
   CreateLabel(obj_title, "MARKET VELOCITY", InpXOffset + 15, InpYOffset + 10, 9, clrWhite);
   CreateLabel(obj_status, "WAITING...", InpXOffset + 25, InpYOffset + 30, 11, clrGray, true);
   CreateLabel(obj_tps, "0.00 TPS", InpXOffset + 50, InpYOffset + 55, 9, clrSilver);
   CreateLabel(obj_pps, "0.00 Pts/s", InpXOffset + 45, InpYOffset + 75, 9, clrSilver);

   EventSetTimer(1); 
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, prefix);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Update fungsi logika                                             |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   MqlTick ticks[];
   
   // PERBAIKAN: Ambil milidetik langsung dari server (Lebih stabil untuk CopyTicks)
   ulong time_now = (ulong)SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC);
   
   // Fallback jika market libur/tutup
   if(time_now == 0) time_now = (ulong)TimeCurrent() * 1000;
   
   ulong time_from = time_now - (InpSeconds * 1000);

   int copied = CopyTicks(_Symbol, ticks, COPY_TICKS_ALL, time_from, 0);

   if(copied > 0)
     {
      double tps = (double)copied / InpSeconds;
      
      double total_points = 0;
      
      // PERBAIKAN: Proteksi _Point Zero Divide Error
      double point_val = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point_val == 0) point_val = 0.00001; 
      
      if(copied > 1)
        {
         for(int i = 1; i < copied; i++)
           {
            total_points += MathAbs(ticks[i].bid - ticks[i-1].bid) / point_val;
           }
        }
      double pps = total_points / InpSeconds;
      
      ObjectSetString(0, obj_tps, OBJPROP_TEXT, DoubleToString(tps, 2) + " TPS");
      ObjectSetString(0, obj_pps, OBJPROP_TEXT, DoubleToString(pps, 2) + " Pts/s");
      
      if(tps >= InpTPSThreshold && pps >= InpPPSThreshold)
        {
         ObjectSetString(0, obj_status, OBJPROP_TEXT, "TRENDING/RAMAI");
         ObjectSetInteger(0, obj_status, OBJPROP_COLOR, clrLimeGreen);
         ObjectSetInteger(0, obj_bg, OBJPROP_COLOR, clrLimeGreen); 
        }
      else if(tps >= InpTPSThreshold && pps < InpPPSThreshold)
        {
         ObjectSetString(0, obj_status, OBJPROP_TEXT, "CHOPPY/RANGING");
         ObjectSetInteger(0, obj_status, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, obj_bg, OBJPROP_COLOR, clrGold); 
        }
      else
        {
         ObjectSetString(0, obj_status, OBJPROP_TEXT, "MARKET SEPI");
         ObjectSetInteger(0, obj_status, OBJPROP_COLOR, clrDarkGray);
         ObjectSetInteger(0, obj_bg, OBJPROP_COLOR, clrDimGray);
        }
        
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//| PERBAIKAN: Menggunakan formasi OnCalculate full untuk hindari bug|
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   UpdateDashboard();
   return(rates_total);
  }

void OnTimer()
  {
   UpdateDashboard();
  }
//+------------------------------------------------------------------+
