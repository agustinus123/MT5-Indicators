//+------------------------------------------------------------------+
//|                                              FVG_Detector_MT5.mq5|
//|                                  Copyright 2026, Auto Generated  |
//|                                              https://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "1.40"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Input Parameters
input group "--- Pengaturan Tampilan ---"
input bool     InpShowConfirmed   = true;       // Tampilkan FVG Valid (Terbentuk)
input bool     InpShowPotential   = true;       // Tampilkan Potensi FVG (Candle Berjalan)
input bool     InpHideMitigated   = true;       // Sembunyikan FVG yang 100% dimitigasi
input color    InpBullColor       = clrLimeGreen;// Warna FVG Bullish (Hijau)
input color    InpBearColor       = clrCrimson; // Warna FVG Bearish (Merah)
input uchar    InpBoxTransparency = 60;         // Transparansi Box (0-255)
input double   InpMinBodySize     = 1.2;        // Min rasio body thd ATR (untuk candle pendorong)
input double   InpMinGapATR       = 0.1;        // Min tinggi gap FVG (rasio ATR, misal 0.1)
input int      InpHistoryBars     = 500;        // Batas history bar yang diproses
input int      InpExtendBars      = 10;         // Perpanjang FVG ke depan (jumlah bar)

//+------------------------------------------------------------------+
//| Custom initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "FVG_");
}

//+------------------------------------------------------------------+
//| Custom iteration function                                        |
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
   if(rates_total < 15) return(0);

   datetime time_arr[];
   double high_arr[], low_arr[], open_arr[], close_arr[];
   
   ArraySetAsSeries(time_arr, true);
   ArraySetAsSeries(high_arr, true);
   ArraySetAsSeries(low_arr, true);
   ArraySetAsSeries(open_arr, true);
   ArraySetAsSeries(close_arr, true);
   
   ArrayCopy(time_arr, time);
   ArrayCopy(high_arr, high);
   ArrayCopy(low_arr, low);
   ArrayCopy(open_arr, open);
   ArrayCopy(close_arr, close);

   int limit = rates_total - prev_calculated;

   // Hapus semua object HANYA saat indikator baru dipasang / chart direfresh
   if(prev_calculated == 0)
   {
      ObjectsDeleteAll(0, "FVG_Confirmed_");
      ObjectsDeleteAll(0, "FVG_Pot_");
      limit = MathMin(rates_total - 1, InpHistoryBars);
   }
   else if(limit > 0)
   {
      // Jika ada candle baru yang open, evaluasi 2 candle ke belakang
      limit += 2; 
   }

   double atr = 0;
   int atr_period = 14;
   for(int i = 1; i <= atr_period; i++) {
      atr += (high_arr[i] - low_arr[i]);
   }
   atr = atr / (double)atr_period;

   double min_gap_size = atr * InpMinGapATR;

   // 1. Deteksi FVG Valid (Confirmed) pada History
   if(InpShowConfirmed)
   {
      for(int i = limit; i >= 2; i--) 
      {
         int idx_left  = i + 1; // Candle ke-1 (paling lama)
         int idx_mid   = i;     // Candle ke-2 (tengah / pendorong)
         int idx_right = i - 1; // Candle ke-3 (baru saja close)

         if(idx_left >= rates_total || idx_right < 1) continue;

         datetime extend_time = time_arr[idx_right] + (InpExtendBars * PeriodSeconds());

         // ================= BULLISH FVG =================
         double bullGap = low_arr[idx_right] - high_arr[idx_left];
         if(low_arr[idx_right] > high_arr[idx_left] && bullGap >= min_gap_size)
         {
            double botPrice = high_arr[idx_left];
            double topPrice = low_arr[idx_right];
            string objName = "FVG_Confirmed_Bull_" + TimeToString(time_arr[idx_left], TIME_DATE|TIME_MINUTES);
            
            bool isMitigated = false;
            
            // Cek ke depan apakah sudah ada candle yang menutup penuh gap ini (Mitigasi 100%)
            if(InpHideMitigated)
            {
               for(int j = idx_right - 1; j >= 0; j--)
               {
                  if(low_arr[j] <= botPrice) // Harga drop menyentuh/melewati batas bawah gap
                  {
                     isMitigated = true;
                     break;
                  }
               }
            }
            
            if(isMitigated)
               ObjectDelete(0, objName);
            else
               DrawFVGBox(objName, time_arr[idx_left], topPrice, extend_time, botPrice, InpBullColor, STYLE_SOLID);
         }
         
         // ================= BEARISH FVG =================
         double bearGap = low_arr[idx_left] - high_arr[idx_right];
         if(high_arr[idx_right] < low_arr[idx_left] && bearGap >= min_gap_size)
         {
            double botPrice = high_arr[idx_right];
            double topPrice = low_arr[idx_left];
            string objName = "FVG_Confirmed_Bear_" + TimeToString(time_arr[idx_left], TIME_DATE|TIME_MINUTES);
            
            bool isMitigated = false;
            
            // Cek ke depan apakah sudah ada candle yang menutup penuh gap ini (Mitigasi 100%)
            if(InpHideMitigated)
            {
               for(int j = idx_right - 1; j >= 0; j--)
               {
                  if(high_arr[j] >= topPrice) // Harga naik menyentuh/melewati batas atas gap
                  {
                     isMitigated = true;
                     break;
                  }
               }
            }
            
            if(isMitigated)
               ObjectDelete(0, objName);
            else
               DrawFVGBox(objName, time_arr[idx_left], topPrice, extend_time, botPrice, InpBearColor, STYLE_SOLID);
         }
      }
   }
   
   // 2. Penghapusan Real-time untuk FVG yang tersentuh oleh pergerakan harga saat ini (Live Tick)
   if(InpHideMitigated && rates_total > 0)
   {
      int total_objects = ObjectsTotal(0, 0, -1);
      // Iterasi terbalik sangat penting saat kita ingin menghapus objek dalam loop
      for(int k = total_objects - 1; k >= 0; k--)
      {
         string obj_name = ObjectName(0, k, 0, -1);
         
         if(StringFind(obj_name, "FVG_Confirmed_Bull_") == 0)
         {
            double botPrice = ObjectGetDouble(0, obj_name, OBJPROP_PRICE, 1);
            if(low_arr[0] <= botPrice) ObjectDelete(0, obj_name);
         }
         else if(StringFind(obj_name, "FVG_Confirmed_Bear_") == 0)
         {
            double topPrice = ObjectGetDouble(0, obj_name, OBJPROP_PRICE, 0);
            if(high_arr[0] >= topPrice) ObjectDelete(0, obj_name);
         }
      }
   }

   // 3. Deteksi Potensi FVG (Real-time / Candle Berjalan)
   if(InpShowPotential && rates_total > 3)
   {
      bool hasPotBull = false;
      bool hasPotBear = false;

      double bodySize = MathAbs(close_arr[1] - open_arr[1]);
      
      if(atr > 0 && bodySize >= (atr * (InpMinBodySize / 2.0)))
      {
         double potBullGap = low_arr[0] - high_arr[2];
         if(low_arr[0] > high_arr[2] && potBullGap >= min_gap_size)
         {
            DrawFVGBox("FVG_Pot_Bull", time_arr[2], high_arr[2], time_arr[0], low_arr[0], InpBullColor, STYLE_DASH);
            hasPotBull = true;
         }
         
         double potBearGap = low_arr[2] - high_arr[0];
         if(high_arr[0] < low_arr[2] && potBearGap >= min_gap_size)
         {
            DrawFVGBox("FVG_Pot_Bear", time_arr[2], low_arr[2], time_arr[0], high_arr[0], InpBearColor, STYLE_DASH);
            hasPotBear = true;
         }
      }

      if(!hasPotBull) ObjectDelete(0, "FVG_Pot_Bull");
      if(!hasPotBear) ObjectDelete(0, "FVG_Pot_Bear");
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Fungsi helper untuk menggambar kotak FVG                         |
//+------------------------------------------------------------------+
void DrawFVGBox(string name, datetime t1, double p1, datetime t2, double p2, color col, ENUM_LINE_STYLE style)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   }
   
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, col);
}
