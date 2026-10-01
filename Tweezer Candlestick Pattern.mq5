//+------------------------------------------------------------------+
//|                                       Tweezer_Push_Alerts.mq5    |
//|                                  Copyright 2026, Gemini Custom   |
//+------------------------------------------------------------------+
#property copyright "Gemini AI"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

// Plot 1: Confirmed Top
#property indicator_label1  "Confirmed Top"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_width1  2

// Plot 2: Confirmed Bottom
#property indicator_label2  "Confirmed Bottom"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  2

// Plot 3: Potential / Early Top
#property indicator_label3  "Potential Top (Early Sell)"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrGold
#property indicator_width3  2

// Plot 4: Potential / Early Bottom
#property indicator_label4  "Potential Bottom (Early Buy)"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrDeepSkyBlue
#property indicator_width4  2

// Enum Opsi Mode Tampilan
enum ENUM_DISPLAY_MODE
  {
   SHOW_BOTH        = 0, // Tampilkan Keduanya
   SHOW_TOP_ONLY    = 1, // Tampilkan Top Saja
   SHOW_BOTTOM_ONLY = 2  // Tampilkan Bottom Saja
  };

// Input Parameters
input group "=== Performance Settings ==="
input int  InpMaxBars = 1000; // Batas Maksimum Bar Hitungan

input group "=== Alert Settings ==="
input bool AlertConfirmed = true;  // Popup PC: Tweezer CONFIRMED (Saat Close)
input bool PushConfirmed  = false; // Push HP: Tweezer CONFIRMED
input bool AlertPotential = false; // Popup PC: Tweezer POTENTIAL (Saat Wick/Running)
input bool PushPotential  = false; // Push HP: Tweezer POTENTIAL

input group "=== Display Settings ==="
input ENUM_DISPLAY_MODE InpDisplayMode = SHOW_BOTH; 
input bool ShowEarlyEntry = true; // Tampilkan Panah Sinyal Dini

input group "=== Tweezer Settings ==="
input double MinBodyPips  = 2.0;  // Ukuran Body Minimum Filter Doji (Pips)
input double MaxDiffPips  = 3.0;  // Toleransi Perbedaan Maksimum (Pips)
input bool   CheckShadow  = true; // Cek Kesejajaran High/Low (Shadow)
input bool   CheckBody    = true; // Cek Kesejajaran Body (Open/Close)

// Indicator Buffers
double BufferTweezerTop[];
double BufferTweezerBottom[];
double BufferPotTop[];
double BufferPotBottom[];

// Global Variables
bool showTop    = true;
bool showBottom = true;

int countTop    = 0;
int countBottom = 0;

string btnTopName    = "Btn_TweezerTop";
string btnBottomName = "Btn_TweezerBottom";

// Variabel Pencegah Alert Spam
datetime lastAlertConfirmed = 0;
datetime lastAlertPotTop    = 0;
datetime lastAlertPotBot    = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferTweezerTop, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

   SetIndexBuffer(1, BufferTweezerBottom, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_ARROW, 233);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

   SetIndexBuffer(2, BufferPotTop, INDICATOR_DATA);
   PlotIndexSetInteger(2, PLOT_ARROW, 234); 
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   SetIndexBuffer(3, BufferPotBottom, INDICATOR_DATA);
   PlotIndexSetInteger(3, PLOT_ARROW, 233); 
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);

   if(InpDisplayMode == SHOW_TOP_ONLY) { showBottom = false; }
   else if(InpDisplayMode == SHOW_BOTTOM_ONLY) { showTop = false; }

   UpdatePlotColors();
   CreateButtons();

   IndicatorSetString(INDICATOR_SHORTNAME, "Tweezer Detector + Push");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectDelete(0, btnTopName);
   ObjectDelete(0, btnBottomName);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   if(rates_total < 2) return 0;

   int start;
   
   if(prev_calculated == 0 || rates_total - prev_calculated > InpMaxBars)
     {
      start = MathMax(1, rates_total - InpMaxBars);
      ArrayInitialize(BufferTweezerTop, 0.0);
      ArrayInitialize(BufferTweezerBottom, 0.0);
      ArrayInitialize(BufferPotTop, 0.0);
      ArrayInitialize(BufferPotBottom, 0.0);
      
      lastAlertConfirmed = time[rates_total-1];
      lastAlertPotTop    = time[rates_total-1];
      lastAlertPotBot    = time[rates_total-1];
     }
   else
     {
      // Mundur 2 bar untuk membersihkan sisa sinyal temporary (Potential Ghosting)
      start = prev_calculated - 2; 
      if(start < 1) start = 1;
     }

   double pipsFactor = _Point * 10;
   double tolerance  = MaxDiffPips * pipsFactor;
   double minBody    = MinBodyPips * pipsFactor;

   for(int i = start; i < rates_total; i++)
     {
      BufferTweezerTop[i]    = 0.0;
      BufferTweezerBottom[i] = 0.0;
      BufferPotTop[i]        = 0.0;
      BufferPotBottom[i]     = 0.0;

      bool isRunningCandle = (i == rates_total - 1);

      double bodySize1 = MathAbs(close[i-1] - open[i-1]);
      if(bodySize1 < minBody) continue; 

      double bodySize2 = MathAbs(close[i] - open[i]);

      bool isC1Bull = close[i-1] > open[i-1];
      bool isC1Bear = close[i-1] < open[i-1];

      bool shadowTopMatch = (CheckShadow && MathAbs(high[i] - high[i-1]) <= tolerance);
      bool bodyTopMatch   = (CheckBody && MathAbs(close[i-1] - open[i]) <= tolerance);
      bool isTopPattern   = (shadowTopMatch || bodyTopMatch);

      bool shadowBotMatch = (CheckShadow && MathAbs(low[i] - low[i-1]) <= tolerance);
      bool bodyBotMatch   = (CheckBody && MathAbs(close[i-1] - open[i]) <= tolerance);
      bool isBotPattern   = (shadowBotMatch || bodyBotMatch);

      // --- 1. EVALUASI TWEEZER TOP ---
      if(isC1Bull && isTopPattern)
        {
         if(close[i] < open[i] && bodySize2 >= minBody) 
           {
            BufferTweezerTop[i] = high[i] + (10 * pipsFactor);
           }
         else if(isRunningCandle && ShowEarlyEntry)
           {
            BufferPotTop[i] = high[i] + (10 * pipsFactor);
           }
        }

      // --- 2. EVALUASI TWEEZER BOTTOM ---
      if(isC1Bear && isBotPattern)
        {
         if(close[i] > open[i] && bodySize2 >= minBody)
           {
            BufferTweezerBottom[i] = low[i] - (10 * pipsFactor);
           }
         else if(isRunningCandle && ShowEarlyEntry)
           {
            BufferPotBottom[i] = low[i] - (10 * pipsFactor);
           }
        }
     }

   // --- LOGIKA ALERT & PUSH NOTIFICATION ---
   string periodStr = EnumToString((ENUM_TIMEFRAMES)_Period);
   
   // 1. ALERT CONFIRMED
   if((AlertConfirmed || PushConfirmed) && time[rates_total-1] != lastAlertConfirmed)
     {
      string msg = "";
      if(BufferTweezerTop[rates_total-2] != 0.0 && showTop)
        {
         msg = Symbol() + " [" + periodStr + "] CONFIRMED: Tweezer Top (Bearish)";
         if(AlertConfirmed) Alert(msg);
         if(PushConfirmed) SendNotification(msg);
         lastAlertConfirmed = time[rates_total-1];
        }
      else if(BufferTweezerBottom[rates_total-2] != 0.0 && showBottom)
        {
         msg = Symbol() + " [" + periodStr + "] CONFIRMED: Tweezer Bottom (Bullish)";
         if(AlertConfirmed) Alert(msg);
         if(PushConfirmed) SendNotification(msg);
         lastAlertConfirmed = time[rates_total-1];
        }
     }

   // 2. ALERT POTENTIAL
   if(AlertPotential || PushPotential)
     {
      string msg = "";
      // Top Potential
      if(BufferPotTop[rates_total-1] != 0.0 && time[rates_total-1] != lastAlertPotTop && showTop)
        {
         msg = Symbol() + " [" + periodStr + "] POTENTIAL: Tweezer Top Wick Test (Early Sell)";
         if(AlertPotential) Alert(msg);
         if(PushPotential) SendNotification(msg);
         lastAlertPotTop = time[rates_total-1];
        }
      // Bottom Potential
      if(BufferPotBottom[rates_total-1] != 0.0 && time[rates_total-1] != lastAlertPotBot && showBottom)
        {
         msg = Symbol() + " [" + periodStr + "] POTENTIAL: Tweezer Bottom Wick Test (Early Buy)";
         if(AlertPotential) Alert(msg);
         if(PushPotential) SendNotification(msg);
         lastAlertPotBot = time[rates_total-1];
        }
     }

   // Update hitungan UI
   countTop = 0; countBottom = 0;
   int checkStart = MathMax(0, rates_total - InpMaxBars);
   for(int i = checkStart; i < rates_total; i++)
     {
      if(BufferTweezerTop[i] != 0.0) countTop++;
      if(BufferTweezerBottom[i] != 0.0) countBottom++;
     }

   UpdateButtonUI();
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Event Handler & UI Functions                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == btnTopName)
        {
         showTop = !showTop;
         UpdatePlotColors();
         UpdateButtonUI();
         ChartRedraw(0);
        }
      else if(sparam == btnBottomName)
        {
         showBottom = !showBottom;
         UpdatePlotColors();
         UpdateButtonUI();
         ChartRedraw(0);
        }
     }
  }

void UpdatePlotColors()
  {
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, showTop ? clrRed : clrNONE);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, showTop && ShowEarlyEntry ? clrGold : clrNONE);
   
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, showBottom ? clrLime : clrNONE);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, showBottom && ShowEarlyEntry ? clrDeepSkyBlue : clrNONE);
  }

void CreateButtons()
  {
   ObjectCreate(0, btnTopName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, btnTopName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnTopName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, btnTopName, OBJPROP_YDISTANCE, 25);
   ObjectSetInteger(0, btnTopName, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, btnTopName, OBJPROP_YSIZE, 26);
   ObjectSetInteger(0, btnTopName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnTopName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, btnTopName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, btnTopName, OBJPROP_SELECTABLE, false);

   ObjectCreate(0, btnBottomName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, btnBottomName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnBottomName, OBJPROP_XDISTANCE, 135);
   ObjectSetInteger(0, btnBottomName, OBJPROP_YDISTANCE, 25);
   ObjectSetInteger(0, btnBottomName, OBJPROP_XSIZE, 135);
   ObjectSetInteger(0, btnBottomName, OBJPROP_YSIZE, 26);
   ObjectSetInteger(0, btnBottomName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnBottomName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, btnBottomName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, btnBottomName, OBJPROP_SELECTABLE, false);

   UpdateButtonUI();
  }

void UpdateButtonUI()
  {
   string textTop = "TOP (" + IntegerToString(countTop) + "): " + (showTop ? "ON" : "OFF");
   ObjectSetString(0, btnTopName, OBJPROP_TEXT, textTop);
   ObjectSetInteger(0, btnTopName, OBJPROP_BGCOLOR, showTop ? clrCrimson : clrDimGray);
   ObjectSetInteger(0, btnTopName, OBJPROP_STATE, false);

   string textBottom = "BOTTOM (" + IntegerToString(countBottom) + "): " + (showBottom ? "ON" : "OFF");
   ObjectSetString(0, btnBottomName, OBJPROP_TEXT, textBottom);
   ObjectSetInteger(0, btnBottomName, OBJPROP_BGCOLOR, showBottom ? clrForestGreen : clrDimGray);
   ObjectSetInteger(0, btnBottomName, OBJPROP_STATE, false);
  }
//+------------------------------------------------------------------+
