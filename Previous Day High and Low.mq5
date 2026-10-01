//+------------------------------------------------------------------+
//|                                                PrevDayHighLow.mq5|
//|                                     Indikator PDH, PDL & 50% MT5 |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

//--- Konfigurasi Garis Previous Day High (PDH)
#property indicator_label1  "Prev Day High"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Konfigurasi Garis Previous Day Low (PDL)
#property indicator_label2  "Prev Day Low"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Konfigurasi Garis Previous Day 50% (Equilibrium)
#property indicator_label3  "Prev Day 50%"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Konfigurasi Garis Previous Day Open (PDO)
#property indicator_label4  "Prev Day Open"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_style4  STYLE_DASH
#property indicator_width4  1

//--- Konfigurasi Garis Previous Day Close (PDC)
#property indicator_label5  "Prev Day Close"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrLimeGreen
#property indicator_style5  STYLE_DASH
#property indicator_width5  1

//--- Array untuk menyimpan nilai garis
double PDHBuffer[];
double PDLBuffer[];
double PDMidBuffer[];
double PDOBuffer[];
double PDCBuffer[];

//+------------------------------------------------------------------+
//| Fungsi untuk membuat atau memperbarui label teks                 |
//+------------------------------------------------------------------+
void CreateOrUpdateLabel(string name, string text, datetime time, double price, color clr)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
     }
   
   ObjectMove(0, name, 0, time, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, PDHBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, PDLBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, PDMidBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, PDOBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, PDCBuffer, INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, "Label_PDH");
   ObjectDelete(0, "Label_PDL");
   ObjectDelete(0, "Label_50");
   ObjectDelete(0, "Label_PDO");
   ObjectDelete(0, "Label_PDC");
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
   if(rates_total < 1) return(0);

   if(Bars(_Symbol, PERIOD_D1) < 2 || !SeriesInfoInteger(_Symbol, PERIOD_D1, SERIES_SYNCHRONIZED))
      return(0);

   int start = prev_calculated - 1;
   if(start < 0) start = 0;

   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      datetime current_time = time[i];
      int daily_shift = iBarShift(_Symbol, PERIOD_D1, current_time);

      if(daily_shift >= 0)
        {
         // Ambil data High, Low, Open, Close harian sebelumnya
         double pdh = iHigh(_Symbol, PERIOD_D1, daily_shift + 1);
         double pdl = iLow(_Symbol, PERIOD_D1, daily_shift + 1);
         double pdo = iOpen(_Symbol, PERIOD_D1, daily_shift + 1);
         double pdc = iClose(_Symbol, PERIOD_D1, daily_shift + 1);
         
         if(pdh == 0.0 || pdl == 0.0 || pdo == 0.0 || pdc == 0.0)
           {
            if(i > rates_total - 100) 
               return(0); 
               
            PDHBuffer[i]   = 0.0;
            PDLBuffer[i]   = 0.0;
            PDMidBuffer[i] = 0.0;
            PDOBuffer[i]   = 0.0;
            PDCBuffer[i]   = 0.0;
            continue; 
           }
         
         double pd50 = (pdh + pdl) / 2.0;

         // PDH, PDL, 50% digambar ke seluruh history
         PDHBuffer[i]   = pdh;
         PDLBuffer[i]   = pdl;
         PDMidBuffer[i] = pd50;
         
         // PDO dan PDC HANYA digambar di candle hari ini (daily_shift == 0)
         if(daily_shift == 0)
           {
            PDOBuffer[i] = pdo;
            PDCBuffer[i] = pdc;
           }
         else
           {
            PDOBuffer[i] = 0.0;
            PDCBuffer[i] = 0.0;
           }
         
         // Update label
         if(i == rates_total - 1)
           {
            datetime label_time = current_time + PeriodSeconds(_Period) * 3;
            
            string text_pdh = " PDH (" + DoubleToString(pdh, _Digits) + ")";
            string text_pdl = " PDL (" + DoubleToString(pdl, _Digits) + ")";
            string text_50  = " 50% (" + DoubleToString(pd50, _Digits) + ")";
            string text_pdo = " PDO (" + DoubleToString(pdo, _Digits) + ")";
            string text_pdc = " PDC (" + DoubleToString(pdc, _Digits) + ")";
            
            CreateOrUpdateLabel("Label_PDH", text_pdh, label_time, pdh, clrRed);
            CreateOrUpdateLabel("Label_PDL", text_pdl, label_time, pdl, clrDodgerBlue);
            CreateOrUpdateLabel("Label_50",  text_50,  label_time, pd50, clrGray);
            CreateOrUpdateLabel("Label_PDO", text_pdo, label_time, pdo, clrOrange);
            CreateOrUpdateLabel("Label_PDC", text_pdc, label_time, pdc, clrLimeGreen);
           }
        }
      else
        {
         PDHBuffer[i]   = 0.0;
         PDLBuffer[i]   = 0.0;
         PDMidBuffer[i] = 0.0;
         PDOBuffer[i]   = 0.0;
         PDCBuffer[i]   = 0.0;
        }
     }
     
   return(rates_total);
  }
//+------------------------------------------------------------------+
