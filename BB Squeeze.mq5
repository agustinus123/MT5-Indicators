//+------------------------------------------------------------------+
//|                                     BB_Squeeze_NonRepaint.mq5    |
//|                                  Copyright 2026, Custom Script   |
//|                                  Indikator BB dengan Squeeze     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "1.40"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   4

// Plot 1: Upper Band
#property indicator_label1  "Upper Band"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

// Plot 2: Middle Band
#property indicator_label2  "Middle Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Plot 3: Lower Band
#property indicator_label3  "Lower Band"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSeaGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

// Plot 4: Squeeze Visual (Dot Merah)
#property indicator_label4  "Squeeze Marker"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  2

// Input Parameter
input int      BandsPeriod = 20;       // Periode Bollinger Bands
input double   BandsDeviance = 2.0;    // Deviasi (Simpangan Baku)
input int      SqueezeMaPeriod = 50;   // Periode MA untuk Baseline Squeeze
input double   SqueezeFactor = 0.8;    // Faktor Squeeze (Lebar < Rata-rata * Faktor)
input int      MaxLookBack = 1000;     // Limit Bar ke belakang (0 = hitung semua)
input bool     WaitBarClose = true;    // True = Dot hanya muncul setelah candle close
input bool     EnableAlert = true;     // Aktifkan Pop-up Alert

// Buffer Indikator
double UpperBuffer[];
double MiddleBuffer[];
double LowerBuffer[];
double SqueezeMarkerBuffer[]; 
double WidthBuffer[];

int bb_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, UpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, MiddleBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SqueezeMarkerBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, WidthBuffer, INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(3, PLOT_ARROW, 159);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   bb_handle = iBands(_Symbol, _Period, BandsPeriod, 0, BandsDeviance, PRICE_CLOSE);
   if(bb_handle == INVALID_HANDLE)
   {
      Print("Gagal membuat handle iBands.");
      return(INIT_FAILED);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "BB Squeeze");
   return(INIT_SUCCEEDED);
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
   if(rates_total < MathMax(BandsPeriod, SqueezeMaPeriod)) return(0);

   int limit = prev_calculated - 1;
   if(limit < MathMax(BandsPeriod, SqueezeMaPeriod)) 
      limit = MathMax(BandsPeriod, SqueezeMaPeriod);
      
   if(MaxLookBack > 0 && limit < rates_total - MaxLookBack)
      limit = rates_total - MaxLookBack;

   if(prev_calculated == 0)
      ArrayInitialize(SqueezeMarkerBuffer, EMPTY_VALUE);

   double upper[], middle[], lower[];
   ArrayResize(upper, rates_total);
   ArrayResize(middle, rates_total);
   ArrayResize(lower, rates_total);

   if(CopyBuffer(bb_handle, 0, 0, rates_total, middle) <= 0) return(0);
   if(CopyBuffer(bb_handle, 1, 0, rates_total, upper) <= 0) return(0);
   if(CopyBuffer(bb_handle, 2, 0, rates_total, lower) <= 0) return(0);

   // --- KALKULASI BUFFER DAN DOT ---
   for(int i = limit; i < rates_total && !IsStopped(); i++)
   {
      UpperBuffer[i] = upper[i];
      MiddleBuffer[i] = middle[i];
      LowerBuffer[i] = lower[i];

      if(middle[i] != 0)
         WidthBuffer[i] = (upper[i] - lower[i]) / middle[i];
      else
         WidthBuffer[i] = 0;

      double sumWidth = 0;
      int count = 0;
      for(int j = 0; j < SqueezeMaPeriod; j++)
      {
         sumWidth += WidthBuffer[i - j];
         count++;
      }
      double avgWidth = (count > 0) ? (sumWidth / count) : 0;

      bool isSqueeze = (avgWidth > 0 && WidthBuffer[i] <= avgWidth * SqueezeFactor);

      // Logika Non-Repaint: Kosongkan dot pada candle yang sedang berjalan (rates_total - 1)
      if(WaitBarClose && i == rates_total - 1)
      {
         SqueezeMarkerBuffer[i] = EMPTY_VALUE;
      }
      else
      {
         if(isSqueeze)
            SqueezeMarkerBuffer[i] = middle[i]; 
         else
            SqueezeMarkerBuffer[i] = EMPTY_VALUE;
      }
   }

   // --- LOGIKA ALERT (HANYA DIEKSEKUSI SAAT PERGANTIAN CANDLE BARU) ---
   if(EnableAlert && rates_total > 4)
   {
      static datetime last_bar_time = 0;
      datetime current_bar_time = time[rates_total - 1];
      
      // Deteksi pergantian candle (waktu open candle saat ini berbeda dengan yang tersimpan)
      if(current_bar_time != last_bar_time)
      {
         if(last_bar_time != 0) // Abaikan alert saat indikator pertama kali dipasang
         {
            // Karena ini pergantian candle, kita cek status candle yang BARU SAJA CLOSE
            int c1 = rates_total - 2; // Candle yang baru close
            int c2 = rates_total - 3; // Candle sebelumnya
            int c3 = rates_total - 4; // Candle sebelumnya lagi
            
            // ALERT MULAI SQUEEZE: c1 ada dot, c2 ada dot, c3 kosong
            if(SqueezeMarkerBuffer[c1] != EMPTY_VALUE && 
               SqueezeMarkerBuffer[c2] != EMPTY_VALUE && 
               SqueezeMarkerBuffer[c3] == EMPTY_VALUE)
            {
               Alert(_Symbol, " [", EnumToString(_Period), "] - Squeeze Terkonfirmasi (2 Candle Sideways)!");
            }
            
            // ALERT SELESAI SQUEEZE: c1 kosong, c2 kosong, c3 ada dot
            if(SqueezeMarkerBuffer[c1] == EMPTY_VALUE && 
               SqueezeMarkerBuffer[c2] == EMPTY_VALUE && 
               SqueezeMarkerBuffer[c3] != EMPTY_VALUE)
            {
               Alert(_Symbol, " [", EnumToString(_Period), "] - Squeeze BERAKHIR! Siap-siap Breakout.");
            }
         }
         // Simpan waktu candle saat ini agar tidak berulang
         last_bar_time = current_bar_time; 
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
