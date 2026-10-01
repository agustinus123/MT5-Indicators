//+------------------------------------------------------------------+
//|                       jy_CandleTimer.mq5                         |
//|                       Candle Countdown Timer                     |
//|                                                                  |
//| Fungsi:                                                          |
//| - Menampilkan waktu tersisa sebelum candle aktif ditutup.        |
//| - Timer diperbarui setiap 1 detik.                               |
//| - Label dapat mengikuti price line.                              |
//| - Posisi label dapat diatur melalui Input.                       |
//+------------------------------------------------------------------+

#property copyright "Jhon"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//+------------------------------------------------------------------+
//| Pilihan posisi timer                                              |
//+------------------------------------------------------------------+
enum ENUM_JY_TIMER_POSITION
{
   JY_PRICE_LINE,       // Mengikuti harga berjalan
   JY_TOP_RIGHT,        // Kanan atas chart
   JY_RIGHT_OF_CANDLE,  // Sebelah kanan candle aktif
   JY_AUTO              // Otomatis: mengikuti price line
};

//+------------------------------------------------------------------+
//| Input                                                             |
//+------------------------------------------------------------------+

// Posisi label timer
input ENUM_JY_TIMER_POSITION InpPosition = JY_PRICE_LINE;

// Warna tulisan timer
input color InpTimerColor = clrWhite;

// Ukuran font timer
input int InpFontSize = 10;

// Jenis font
input string InpFontName = "Arial";

// Jarak horizontal label dari candle / price line
input int InpXOffset = 10;

// Jarak vertikal label dari price line
input int InpYOffset = 0;

// Tampilkan background label
input bool InpShowBackground = false;

// Warna background label
input color InpBackgroundColor = clrBlack;

//+------------------------------------------------------------------+
//| Nama object timer                                                 |
//+------------------------------------------------------------------+
string TimerObjectName = "jy_CandleTimer_Label";

//+------------------------------------------------------------------+
//| Mendapatkan timeframe dalam detik                                 |
//+------------------------------------------------------------------+
int GetTimeframeSeconds()
{
   // PeriodSeconds() mengembalikan durasi timeframe chart
   int seconds = PeriodSeconds(_Period);

   // Jika gagal mendapatkan timeframe,
   // gunakan 60 detik sebagai fallback
   if(seconds <= 0)
      seconds = 60;

   return seconds;
}

//+------------------------------------------------------------------+
//| Membuat format waktu countdown                                    |
//+------------------------------------------------------------------+
string FormatTime(int seconds)
{
   // Pastikan tidak pernah menampilkan angka negatif
   if(seconds < 0)
      seconds = 0;

   // Hitung jam
   int hours = seconds / 3600;

   // Hitung menit
   int minutes = (seconds % 3600) / 60;

   // Hitung detik
   int secs = seconds % 60;

   // Jika terdapat jam, tampilkan HH:MM:SS
   if(hours > 0)
   {
      return StringFormat(
         "%02d:%02d:%02d",
         hours,
         minutes,
         secs
      );
   }

   // Jika kurang dari satu jam,
   // cukup tampilkan MM:SS
   return StringFormat(
      "%02d:%02d",
      minutes,
      secs
   );
}

//+------------------------------------------------------------------+
//| Menghitung sisa waktu candle                                     |
//+------------------------------------------------------------------+
int GetRemainingSeconds()
{
   // Waktu pembukaan candle aktif
   datetime candleOpenTime = iTime(_Symbol, _Period, 0);

   // Jika data candle belum tersedia
   if(candleOpenTime <= 0)
      return 0;

   // Durasi candle
   int timeframeSeconds = GetTimeframeSeconds();

   // Waktu candle berikutnya akan dimulai
   datetime candleCloseTime =
      candleOpenTime + timeframeSeconds;

   // Waktu server saat ini
   datetime currentTime = TimeCurrent();

   // Hitung waktu yang tersisa
   int remaining =
      (int)(candleCloseTime - currentTime);

   // Jangan pernah mengembalikan nilai negatif
   if(remaining < 0)
      remaining = 0;

   return remaining;
}

//+------------------------------------------------------------------+
//| Membuat object label                                              |
//+------------------------------------------------------------------+
void CreateTimerLabel()
{
   // Jika object belum ada, buat object baru
   if(ObjectFind(0, TimerObjectName) < 0)
   {
      ObjectCreate(
         0,
         TimerObjectName,
         OBJ_LABEL,
         0,
         0,
         0
      );
   }

   // Atur font
   ObjectSetString(
      0,
      TimerObjectName,
      OBJPROP_FONT,
      InpFontName
   );

   // Atur ukuran font
   ObjectSetInteger(
      0,
      TimerObjectName,
      OBJPROP_FONTSIZE,
      InpFontSize
   );

   // Atur warna tulisan
   ObjectSetInteger(
      0,
      TimerObjectName,
      OBJPROP_COLOR,
      InpTimerColor
   );

   // Nonaktifkan select agar label tidak mudah terseret
   ObjectSetInteger(
      0,
      TimerObjectName,
      OBJPROP_SELECTABLE,
      false
   );

   // Jangan tampilkan object di belakang candle
   ObjectSetInteger(
      0,
      TimerObjectName,
      OBJPROP_BACK,
      false
   );

   // Jangan mengganggu mouse/chart interaction
   ObjectSetInteger(
      0,
      TimerObjectName,
      OBJPROP_HIDDEN,
      true
   );

   // Jika menggunakan background,
   // gunakan rectangle label
   if(InpShowBackground)
   {
      ObjectSetInteger(
         0,
         TimerObjectName,
         OBJPROP_BGCOLOR,
         InpBackgroundColor
      );

      ObjectSetInteger(
         0,
         TimerObjectName,
         OBJPROP_BORDER_COLOR,
         InpBackgroundColor
      );
   }
}

//+------------------------------------------------------------------+
//| Update teks timer                                                 |
//+------------------------------------------------------------------+
void UpdateTimerText()
{
   // Hitung waktu tersisa
   int remaining = GetRemainingSeconds();

   // Format menjadi MM:SS atau HH:MM:SS
   string timerText = FormatTime(remaining);

   // Update tulisan label
   ObjectSetString(
      0,
      TimerObjectName,
      OBJPROP_TEXT,
      timerText
   );
}

//+------------------------------------------------------------------+
//| Posisi: kanan atas                                                |
//+------------------------------------------------------------------+
void SetPositionTopRight()
{
   // Gunakan anchor kanan atas
   ObjectSetInteger(
      0,
      TimerObjectName,
      OBJPROP_CORNER,
      CORNER_RIGHT_UPPER
   );

   // Anchor object berada di kanan atas
   ObjectSetInteger(
      0,
      TimerObjectName,
      OBJPROP_ANCHOR,
      ANCHOR_RIGHT_UPPER
   );

   // Jarak dari sisi kanan chart
   ObjectSetInteger(
      0,
      TimerObjectName,
      OBJPROP_XDISTANCE,
      InpXOffset
   );

   // Jarak dari sisi atas chart
   ObjectSetInteger(
      0,
      TimerObjectName,
      OBJPROP_YDISTANCE,
      10 + InpYOffset
   );
}

//+------------------------------------------------------------------+
//| Posisi: mengikuti price line                                      |
//+------------------------------------------------------------------+
void SetPositionPriceLine()
{
   // Dapatkan harga Bid saat ini
   double price = SymbolInfoDouble(
      _Symbol,
      SYMBOL_BID
   );

   // Jika Bid tidak tersedia,
   // gunakan Close candle aktif
   if(price <= 0)
      price = iClose(_Symbol, _Period, 0);

   // Ubah harga menjadi koordinat pixel chart
   int x;
   int y;

   bool converted = ChartTimePriceToXY(
      0,
      0,
      TimeCurrent(),
      price,
      x,
      y
   );

   // Jika konversi berhasil
   if(converted)
   {
      // Gunakan koordinat layar
      ObjectSetInteger(
         0,
         TimerObjectName,
         OBJPROP_CORNER,
         CORNER_LEFT_UPPER
      );

      // Anchor di sisi kiri label
      ObjectSetInteger(
         0,
         TimerObjectName,
         OBJPROP_ANCHOR,
         ANCHOR_LEFT
      );

      // Sedikit ke kanan dari price line
      ObjectSetInteger(
         0,
         TimerObjectName,
         OBJPROP_XDISTANCE,
         x + InpXOffset
      );

      // Posisi vertikal mengikuti harga
      ObjectSetInteger(
         0,
         TimerObjectName,
         OBJPROP_YDISTANCE,
         y + InpYOffset
      );
   }
}

//+------------------------------------------------------------------+
//| Posisi: kanan candle aktif                                        |
//+------------------------------------------------------------------+
void SetPositionRightOfCandle()
{
   // Ambil waktu candle aktif
   datetime candleTime =
      iTime(_Symbol, _Period, 0);

   // Ambil harga candle aktif
   double candleHigh =
      iHigh(_Symbol, _Period, 0);

   // Konversi waktu + harga ke koordinat layar
   int x;
   int y;

   bool converted = ChartTimePriceToXY(
      0,
      0,
      candleTime,
      candleHigh,
      x,
      y
   );

   if(converted)
   {
      // Gunakan koordinat layar
      ObjectSetInteger(
         0,
         TimerObjectName,
         OBJPROP_CORNER,
         CORNER_LEFT_UPPER
      );

      ObjectSetInteger(
         0,
         TimerObjectName,
         OBJPROP_ANCHOR,
         ANCHOR_LEFT
      );

      // Geser sedikit ke kanan
      ObjectSetInteger(
         0,
         TimerObjectName,
         OBJPROP_XDISTANCE,
         x + InpXOffset
      );

      // Geser sedikit ke bawah dari high candle
      ObjectSetInteger(
         0,
         TimerObjectName,
         OBJPROP_YDISTANCE,
         y + InpYOffset
      );
   }
}

//+------------------------------------------------------------------+
//| Update posisi label                                               |
//+------------------------------------------------------------------+
void UpdateTimerPosition()
{
   switch(InpPosition)
   {
      // Label mengikuti harga berjalan
      case JY_PRICE_LINE:
         SetPositionPriceLine();
         break;

      // Label tetap di kanan atas
      case JY_TOP_RIGHT:
         SetPositionTopRight();
         break;

      // Label berada di kanan candle aktif
      case JY_RIGHT_OF_CANDLE:
         SetPositionRightOfCandle();
         break;

      // Auto saat ini menggunakan price line
      case JY_AUTO:
         SetPositionPriceLine();
         break;
   }
}

//+------------------------------------------------------------------+
//| Inisialisasi indikator                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // Buat label timer
   CreateTimerLabel();

   // Set timer agar OnTimer() dipanggil setiap 1 detik
   EventSetTimer(1);

   // Update pertama
   UpdateTimerText();
   UpdateTimerPosition();

   // Redraw chart
   ChartRedraw();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Fungsi utama indikator                                            |
//+------------------------------------------------------------------+
int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
{
   // Update posisi ketika ada tick baru
   UpdateTimerPosition();

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer berjalan setiap 1 detik                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Update countdown
   UpdateTimerText();

   // Update posisi karena harga dapat berubah
   UpdateTimerPosition();

   // Refresh chart
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Ketika indikator dihapus                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Matikan timer
   EventKillTimer();

   // Hapus label dari chart
   ObjectDelete(
      0,
      TimerObjectName
   );
}
//+------------------------------------------------------------------+
