//+------------------------------------------------------------------+
//|                                              CentLotTracker.mq5  |
//|                                       Custom Cent Lot Statistic  |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

// --- Input Parameter ---
input bool   AutoDetectColor = true;     // Auto Detect Background Color
input color  ManualTextColor = clrWhite; // Text Color (If Auto = false)

// Nama objek label (menggunakan 2 label untuk 2 baris)
string labelVolName  = "CentLotStat_Volume";
string labelInfoName = "CentLotStat_Info";

//+------------------------------------------------------------------+
//| Fungsi Bantuan untuk Membuat Label                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, int y_dist)
  {
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
     {
      Print("Gagal membuat label ", name, "! Error: ", GetLastError());
      return;
     }
   
   // Mengatur posisi di pojok kiri bawah (Corner Left Lower)
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 15);     // Jarak dari kiri
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_dist); // Jarak dari bawah
   
   // Desain teks
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Membuat 2 baris label dengan jarak berbeda dari bawah
   CreateLabel(labelVolName, 42);  // Baris atas (jarak 42 pixel dari bawah)
   CreateLabel(labelInfoName, 25); // Baris bawah (jarak 25 pixel dari bawah)
   
   // Terapkan warna pertama kali
   UpdateTextColor();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Hapus teks dari chart saat indikator dilepas
   ObjectDelete(0, labelVolName);
   ObjectDelete(0, labelInfoName);
  }

//+------------------------------------------------------------------+
//| Fungsi untuk mendeteksi dan memperbarui warna teks               |
//+------------------------------------------------------------------+
void UpdateTextColor()
  {
   color textColor = ManualTextColor; // Default warna manual
   
   if(AutoDetectColor)
     {
      // Deteksi warna background chart saat ini
      long bgColor = ChartGetInteger(0, CHART_COLOR_BACKGROUND);

      // Ekstrak nilai RGB
      int r = (int)(bgColor & 0xFF);
      int g = (int)((bgColor >> 8) & 0xFF);
      int b = (int)((bgColor >> 16) & 0xFF);

      // Hitung kecerahan (Luminance)
      double luminance = (0.299 * r) + (0.587 * g) + (0.114 * b);

      // Tentukan warna berdasarkan tingkat kecerahan background
      textColor = (luminance > 128) ? clrBlack : clrWhite;
     }

   // Terapkan warna ke kedua baris
   ObjectSetInteger(0, labelVolName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, labelInfoName, OBJPROP_COLOR, textColor);
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
   double total_cent_lots = 0.0;
   int    total_positions = 0;
   double total_value     = 0.0; // Untuk menghitung harga rata-rata
   
   // Looping seluruh posisi yang sedang terbuka
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i); // Mengunci tiket posisi
      if(ticket > 0)
        {
         // Memfilter agar hanya menghitung pada pair di chart ini saja
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            double vol = PositionGetDouble(POSITION_VOLUME);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            
            total_cent_lots += vol;
            total_value += (vol * open_price); // Mengakumulasi nilai (Lot x Harga)
            total_positions++;                 // Menambah jumlah posisi
           }
        }
     }
   
   // Konversi lot cent ke standar
   double total_standard_lots = total_cent_lots / 100.0; 
   
   // Menghitung harga rata-rata (Weighted Average)
   double avg_price = 0.0;
   if(total_cent_lots > 0)
     {
      avg_price = total_value / total_cent_lots;
     }
   
   // Format output teks Baris 1 (Volume)
   string textVol = StringFormat("Volume: %.2f Lot Cent | %.4f Lot Standar", total_cent_lots, total_standard_lots);
   
   // Format output teks Baris 2 (Posisi & Harga Rata-rata)
   string textInfo = "Posisi Terbuka: 0 | Harga Rata-rata: 0.0"; // Default jika tidak ada posisi
   if(total_positions > 0)
     {
      // %.*f digunakan agar jumlah desimal harga otomatis menyesuaikan dengan digit pair (misal XAUUSD 2 digit, EURUSD 5 digit)
      textInfo = StringFormat("Posisi Terbuka: %d | Harga Rata-rata: %.*f", total_positions, _Digits, avg_price);
     }
   
   // Update warna jika user merubah warna background secara live
   UpdateTextColor();
   
   // Update teks di chart secara real-time
   ObjectSetString(0, labelVolName, OBJPROP_TEXT, textVol);
   ObjectSetString(0, labelInfoName, OBJPROP_TEXT, textInfo);
   
   ChartRedraw(0);
   
   return(rates_total);
  }
//+------------------------------------------------------------------+
