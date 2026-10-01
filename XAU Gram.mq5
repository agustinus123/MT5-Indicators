//+------------------------------------------------------------------+
//|                                         XAUUSD_Gram_Tracker.mq5 |
//|                                     Copyright 2026, Gemini AI    |
//|                                                                  |
//| Indikator untuk menghitung total posisi emas dalam satuan Gram   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini AI"
#property version   "1.50"
#property indicator_chart_window

// --- INPUT USER ---
enum Enum_Account { Standard, Cent };
input Enum_Account AccountType = Standard; // Pilih: Standard atau Cent
input color TextColor          = clrGold;   // Warna Tulisan
input int FontSize             = 14;        // Ukuran Tulisan
input int X_Position           = 30;        // Jarak dari Kiri
input int Y_Position           = 50;        // Jarak dari Atas

// Nama objek teks di layar
string objName = "XAU_Gram_Label";

//+------------------------------------------------------------------+
//| Fungsi Inisialisasi                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Fungsi Deinisialisasi                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, objName);
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Fungsi Calculate                                                 |
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
   HitungDanTampilkan();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Fungsi Timer                                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   HitungDanTampilkan();
}

//+------------------------------------------------------------------+
//| LOGIKA UTAMA                                                     |
//+------------------------------------------------------------------+
void HitungDanTampilkan()
{
   double totalLots = 0;
   int positionCount = 0;

   // Periksa semua posisi yang terbuka
   for(int i = 0; i < PositionsTotal(); i++)
   {
      // Ambil tiket posisi
      ulong ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(ticket))
      {
         // Ambil nama simbol posisi
         string symbol = PositionGetString(POSITION_SYMBOL);
         
         // PERBAIKAN: Menggunakan fungsi StringToUpper yang mengembalikan nilai
         // Ini lebih stabil dan jarang menyebabkan error pada kompiler MT5
         string symUpper = symbol;
         StringToUpper(symUpper); 
         
         // Cek apakah mengandung XAUUSD atau GOLD
         if(StringFind(symUpper, "XAUUSD") >= 0 || StringFind(symUpper, "GOLD") >= 0)
         {
            totalLots += PositionGetDouble(POSITION_VOLUME);
            positionCount++;
         }
      }
   }

   // Rumus Konversi
   // 1 Lot Standard = 100 oz = 3110.35 Gram
   double gramFactor = 3110.35; 
   
   if(AccountType == Cent)
   {
      gramFactor = gramFactor / 100.0;
   }

   double totalGrams = totalLots * gramFactor;

   // Tampilan Visual
   string modeText = (AccountType == Cent) ? "CENT" : "STANDARD";
   string displayStr = StringFormat("XAUUSD [%s] | Posisi: %d | Total: %.2f Gram", 
                                    modeText, positionCount, totalGrams);

   // Update Objek di Chart
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   }
   
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, X_Position);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, Y_Position);
   ObjectSetString(0, objName, OBJPROP_TEXT, displayStr);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, TextColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
   
   ChartRedraw();
}
