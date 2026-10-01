//+------------------------------------------------------------------+
//|                                     BalanceEquityToUSD_Left.mq5  |
//|                                  Copyright 2026, Gemini AI       |
//+------------------------------------------------------------------+
#property copyright "Gemini AI"
#property indicator_chart_window

// Input Settings
input int      InpXOffset  = 20;          // Jarak dari Kiri (X)
input int      InpYOffset  = 50;          // Jarak dari Atas (Y)
input color    InpColor    = clrCyan;     // Warna Teks
input int      InpFontSize = 14;          // Ukuran Font
input string   InpFontName = "Trebuchet MS";

// Nama unik untuk dua label berbeda
string objBalance = "USD_Balance_Label";
string objEquity  = "USD_Equity_Label";

int OnInit()
{
   // Bersihkan objek lama
   ObjectDelete(0, objBalance);
   ObjectDelete(0, objEquity);

   // Buat Label Balance
   CreateLabel(objBalance, InpYOffset);
   
   // Buat Label Equity (diletakkan lebih rendah dari Balance)
   // Jarak baris otomatis menyesuaikan ukuran font (FontSize * 1.5)
   int equityY = InpYOffset + (int)(InpFontSize * 1.8);
   CreateLabel(objEquity, equityY);
   
   return(INIT_SUCCEEDED);
}

// Fungsi pembantu untuk membuat label agar kode lebih rapi
void CreateLabel(string name, int yDist)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpXOffset);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDist);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetString(0, name, OBJPROP_FONT, InpFontName);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void OnDeinit(const int reason)
{
   if(reason != REASON_CHARTCHANGE && reason != REASON_PARAMETERS)
   {
      ObjectDelete(0, objBalance);
      ObjectDelete(0, objEquity);
   }
}

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
   // Ambil data Balance dan Equity (USC)
   double balUSC = AccountInfoDouble(ACCOUNT_BALANCE);
   double eqUSC  = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Konversi ke USD
   double balUSD = balUSC / 100.0;
   double eqUSD  = eqUSC / 100.0;
   
   // Update Teks
   ObjectSetString(0, objBalance, OBJPROP_TEXT, "USD Balance: $" + DoubleToString(balUSD, 2));
   ObjectSetString(0, objEquity,  OBJPROP_TEXT, "USD Equity  : $" + DoubleToString(eqUSD, 2));
   
   return(rates_total);
}
