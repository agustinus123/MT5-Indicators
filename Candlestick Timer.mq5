//+------------------------------------------------------------------+
//|                                           CandleTimer_Pro.mq5    |
//|                                  Copyright 2026, Gemini AI       |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini AI"
#property link      "https://www.mql5.com"
#property version   "1.10"
#property indicator_chart_window

// --- Input User ---
input color            InpColor    = clrCyan;           // Warna Teks
input int              InpFontSize = 14;               // Ukuran Font
input ENUM_BASE_CORNER InpCorner   = CORNER_RIGHT_UPPER; // Posisi Pojok Layar
input int              InpXOffset  = 20;               // Jarak Horizontal (X)
input int              InpYOffset  = 20;               // Jarak Vertikal (Y)

// --- Variabel Global ---
string obj_name = "CandleTimerLabel";

//+------------------------------------------------------------------+
//| Fungsi Inisialisasi                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   // Timer 1 detik untuk update countdown
   EventSetTimer(1);
   
   // Inisialisasi awal objek teks
   CreateTimerObject();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Fungsi Deinisialisasi (Hapus objek saat indikator dilepas)       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectDelete(0, obj_name);
}

//+------------------------------------------------------------------+
//| Fungsi Utama (Dijalankan setiap ada Tick baru)                   |
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
   UpdateTimer();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Fungsi Timer (Dijalankan setiap 1 detik)                         |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateTimer();
}

//+------------------------------------------------------------------+
//| Fungsi Membuat Objek Label                                       |
//+------------------------------------------------------------------+
void CreateTimerObject()
{
   if(ObjectFind(0, obj_name) < 0)
   {
      ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
      
      // Mengatur Font ke Consolas agar lebar angka sama (monospaced)
      ObjectSetString(0, obj_name, OBJPROP_FONT, "Consolas");
      
      // Jarak dari pojok
      ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, InpXOffset);
      ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, InpYOffset);
   }
}

//+------------------------------------------------------------------+
//| Fungsi Perhitungan & Update Tampilan                             |
//+------------------------------------------------------------------+
void UpdateTimer()
{
   // Pastikan objek ada
   CreateTimerObject();

   // Hitung sisa waktu
   datetime serverTime    = TimeCurrent();
   int      periodSeconds = PeriodSeconds();
   datetime barStartTime  = iTime(_Symbol, _Period, 0);
   
   long remainingSeconds = (long)(barStartTime + periodSeconds) - (long)serverTime;
   
   if(remainingSeconds < 0) remainingSeconds = 0;
   
   // Format ke HH:MM:SS
   int hours   = (int)(remainingSeconds / 3600);
   int minutes = (int)((remainingSeconds % 3600) / 60);
   int seconds = (int)(remainingSeconds % 60);
   
   string timeStr;
   if(hours > 0)
      timeStr = StringFormat("%02d:%02d:%02d", hours, minutes, seconds);
   else
      timeStr = StringFormat("%02d:%02d", minutes, seconds);

   // --- LOGIKA FIX ANCHOR AGAR TIDAK KEPOTONG ---
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, InpCorner);
   
   // Jika di kanan, anchor di kanan. Jika di kiri, anchor di kiri.
   if(InpCorner == CORNER_RIGHT_UPPER || InpCorner == CORNER_RIGHT_LOWER)
      ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_RIGHT);
   else
      ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_LEFT);

   // Update Teks dan Properti
   ObjectSetString(0, obj_name, OBJPROP_TEXT, "Next Candle: " + timeStr);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, InpColor);
   ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, InpFontSize);
   
   ChartRedraw();
}
