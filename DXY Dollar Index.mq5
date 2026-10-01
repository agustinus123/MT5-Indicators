//+------------------------------------------------------------------+
//|                  jy_Synthetic_DXY.mq5                            |
//|                  Synthetic Dollar Index                          |
//|                                                                  |
//|  Versi 2.00 - Optimized                                          |
//|  Menghindari iBarShift/iClose berulang yang dapat membuat MT5     |
//|  freeze ketika histori candle sangat banyak.                     |
//+------------------------------------------------------------------+

#property copyright "Jhon"
#property version   "2.00"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot DXY
#property indicator_label1  "Synthetic DXY"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1

//--- Plot MA
#property indicator_label2  "DXY MA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  1


//==================================================================
// INPUT
//==================================================================

//--- Suffix broker
input string jy_Suffix = "c";

//--- Jumlah candle maksimum yang dihitung
//--- Tujuannya supaya indikator tetap ringan.
input int jy_MaxBars = 3000;

//--- Periode MA
input int jy_MAPeriod = 13;


//==================================================================
// BUFFER
//==================================================================

double jy_DXYBuffer[];
double jy_MABuffer[];


//==================================================================
// ARRAY DATA HARGA
//==================================================================

double jy_EURUSD[];
double jy_USDJPY[];
double jy_GBPUSD[];
double jy_USDCAD[];
double jy_USDSEK[];
double jy_USDCHF[];


//==================================================================
// NAMA SYMBOL
//==================================================================

string jy_EURUSD_Symbol;
string jy_USDJPY_Symbol;
string jy_GBPUSD_Symbol;
string jy_USDCAD_Symbol;
string jy_USDSEK_Symbol;
string jy_USDCHF_Symbol;


//==================================================================
// CEK APAKAH DATA SYMBOL TERSEDIA
//==================================================================

bool jy_CheckSymbol(string symbol)
{
   //--- Pastikan symbol tersedia di Market Watch
   if(!SymbolSelect(symbol, true))
   {
      Print("jy_DXY ERROR: Tidak bisa memilih symbol ", symbol);
      return false;
   }

   return true;
}


//==================================================================
// HITUNG SATU NILAI DXY
//==================================================================

double jy_CalculateDXY(
   double eurusd,
   double usdjpy,
   double gbpusd,
   double usdcad,
   double usdsek,
   double usdchf
)
{
   //--- Pastikan semua harga valid
   if(eurusd <= 0 ||
      usdjpy <= 0 ||
      gbpusd <= 0 ||
      usdcad <= 0 ||
      usdsek <= 0 ||
      usdchf <= 0)
   {
      return EMPTY_VALUE;
   }


   //===============================================================
   // Rumus resmi DXY
   //
   // DXY =
   // 50.14348112
   // × EURUSD^-0.576
   // × USDJPY^0.136
   // × GBPUSD^-0.119
   // × USDCAD^0.091
   // × USDSEK^0.042
   // × USDCHF^0.036
   //===============================================================

   double dxy =
      50.14348112
      * MathPow(eurusd, -0.576)
      * MathPow(usdjpy,  0.136)
      * MathPow(gbpusd, -0.119)
      * MathPow(usdcad,  0.091)
      * MathPow(usdsek,  0.042)
      * MathPow(usdchf,  0.036);

   return dxy;
}


//==================================================================
// ON INIT
//==================================================================

int OnInit()
{
   //--- Hubungkan buffer DXY
   SetIndexBuffer(
      0,
      jy_DXYBuffer,
      INDICATOR_DATA
   );

   //--- Hubungkan buffer MA
   SetIndexBuffer(
      1,
      jy_MABuffer,
      INDICATOR_DATA
   );


   //--- Gunakan indexing seperti chart MT5
   ArraySetAsSeries(
      jy_DXYBuffer,
      true
   );

   ArraySetAsSeries(
      jy_MABuffer,
      true
   );


   //--- Buat nama symbol berdasarkan suffix broker
   jy_EURUSD_Symbol = "EURUSD" + jy_Suffix;
   jy_USDJPY_Symbol = "USDJPY" + jy_Suffix;
   jy_GBPUSD_Symbol = "GBPUSD" + jy_Suffix;
   jy_USDCAD_Symbol = "USDCAD" + jy_Suffix;
   jy_USDSEK_Symbol = "USDSEK" + jy_Suffix;
   jy_USDCHF_Symbol = "USDCHF" + jy_Suffix;


   //--- Pastikan semua symbol tersedia
   if(!jy_CheckSymbol(jy_EURUSD_Symbol))
      return INIT_FAILED;

   if(!jy_CheckSymbol(jy_USDJPY_Symbol))
      return INIT_FAILED;

   if(!jy_CheckSymbol(jy_GBPUSD_Symbol))
      return INIT_FAILED;

   if(!jy_CheckSymbol(jy_USDCAD_Symbol))
      return INIT_FAILED;

   if(!jy_CheckSymbol(jy_USDSEK_Symbol))
      return INIT_FAILED;

   if(!jy_CheckSymbol(jy_USDCHF_Symbol))
      return INIT_FAILED;


   //--- Nama indikator
   IndicatorSetString(
      INDICATOR_SHORTNAME,
      "Synthetic DXY MA(" +
      IntegerToString(jy_MAPeriod) +
      ")"
   );


   //--- Empty value
   PlotIndexSetDouble(
      0,
      PLOT_EMPTY_VALUE,
      EMPTY_VALUE
   );

   PlotIndexSetDouble(
      1,
      PLOT_EMPTY_VALUE,
      EMPTY_VALUE
   );


   Print(
      "jy_DXY: Initialized successfully. Symbols: ",
      jy_EURUSD_Symbol, ", ",
      jy_USDJPY_Symbol, ", ",
      jy_GBPUSD_Symbol, ", ",
      jy_USDCAD_Symbol, ", ",
      jy_USDSEK_Symbol, ", ",
      jy_USDCHF_Symbol
   );


   return INIT_SUCCEEDED;
}


//==================================================================
// ON CALCULATE
//==================================================================

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
   //--- Minimal candle
   if(rates_total < 2)
      return 0;


   //===============================================================
   // Tentukan jumlah candle yang akan dihitung
   //===============================================================

   int bars_to_calculate = rates_total;

   if(bars_to_calculate > jy_MaxBars)
      bars_to_calculate = jy_MaxBars;


   //===============================================================
   // Tentukan apakah ini perhitungan pertama
   //===============================================================

   bool first_calculation = (prev_calculated == 0);


   //===============================================================
   // Pada kalkulasi pertama:
   // ambil seluruh histori yang diperlukan.
   //
   // Pada tick berikutnya:
   // hanya ambil 2 candle terakhir.
   //
   // Ini jauh lebih ringan daripada memanggil iClose()
   // berkali-kali.
   //===============================================================

   int copy_count;

   if(first_calculation)
      copy_count = bars_to_calculate;
   else
      copy_count = 2;


   //===============================================================
   // Resize array harga
   //===============================================================

   ArrayResize(jy_EURUSD, copy_count);
   ArrayResize(jy_USDJPY, copy_count);
   ArrayResize(jy_GBPUSD, copy_count);
   ArrayResize(jy_USDCAD, copy_count);
   ArrayResize(jy_USDSEK, copy_count);
   ArrayResize(jy_USDCHF, copy_count);


   //--- Gunakan series indexing
   ArraySetAsSeries(jy_EURUSD, true);
   ArraySetAsSeries(jy_USDJPY, true);
   ArraySetAsSeries(jy_GBPUSD, true);
   ArraySetAsSeries(jy_USDCAD, true);
   ArraySetAsSeries(jy_USDSEK, true);
   ArraySetAsSeries(jy_USDCHF, true);


   //===============================================================
   // COPY DATA HARGA
   //===============================================================

   int copied_eur =
      CopyClose(
         jy_EURUSD_Symbol,
         PERIOD_CURRENT,
         0,
         copy_count,
         jy_EURUSD
      );

   int copied_jpy =
      CopyClose(
         jy_USDJPY_Symbol,
         PERIOD_CURRENT,
         0,
         copy_count,
         jy_USDJPY
      );

   int copied_gbp =
      CopyClose(
         jy_GBPUSD_Symbol,
         PERIOD_CURRENT,
         0,
         copy_count,
         jy_GBPUSD
      );

   int copied_cad =
      CopyClose(
         jy_USDCAD_Symbol,
         PERIOD_CURRENT,
         0,
         copy_count,
         jy_USDCAD
      );

   int copied_sek =
      CopyClose(
         jy_USDSEK_Symbol,
         PERIOD_CURRENT,
         0,
         copy_count,
         jy_USDSEK
      );

   int copied_chf =
      CopyClose(
         jy_USDCHF_Symbol,
         PERIOD_CURRENT,
         0,
         copy_count,
         jy_USDCHF
      );


   //===============================================================
   // Pastikan semua data berhasil diperoleh
   //===============================================================

   if(copied_eur < copy_count ||
      copied_jpy < copy_count ||
      copied_gbp < copy_count ||
      copied_cad < copy_count ||
      copied_sek < copy_count ||
      copied_chf < copy_count)
   {
      //--- Jangan melakukan perhitungan berat lagi.
      //--- Tunggu data tersedia pada tick berikutnya.

      Print(
         "jy_DXY: Menunggu data pair. ",
         "EUR=", copied_eur,
         " JPY=", copied_jpy,
         " GBP=", copied_gbp,
         " CAD=", copied_cad,
         " SEK=", copied_sek,
         " CHF=", copied_chf
      );

      return prev_calculated;
   }


   //===============================================================
   // TENTUKAN INDEX PERHITUNGAN
   //===============================================================

   int start;

   if(first_calculation)
   {
      //--- Hitung semua histori
      start = bars_to_calculate - 1;
   }
   else
   {
      //--- Hanya update candle 0 dan 1
      start = 1;
   }


   //===============================================================
   // HITUNG DXY
   //===============================================================

   for(int i = start; i >= 0; i--)
   {
      //--- Pastikan index tidak keluar array
      if(i >= copy_count)
         continue;


      //--- Hitung DXY
      jy_DXYBuffer[i] =
         jy_CalculateDXY(
            jy_EURUSD[i],
            jy_USDJPY[i],
            jy_GBPUSD[i],
            jy_USDCAD[i],
            jy_USDSEK[i],
            jy_USDCHF[i]
         );
   }


   //===============================================================
   // HITUNG MOVING AVERAGE
   //===============================================================

   if(first_calculation)
   {
      //--- Bersihkan MA terlebih dahulu
      for(int i = 0; i < bars_to_calculate; i++)
         jy_MABuffer[i] = EMPTY_VALUE;


      //--- MA membutuhkan jumlah candle minimal
      if(bars_to_calculate >= jy_MAPeriod)
      {
         for(int i = 0;
             i <= bars_to_calculate - jy_MAPeriod;
             i++)
         {
            double sum = 0.0;
            bool valid = true;


            //--- Hitung SMA
            for(int j = 0; j < jy_MAPeriod; j++)
            {
               double value = jy_DXYBuffer[i + j];

               if(value == EMPTY_VALUE)
               {
                  valid = false;
                  break;
               }

               sum += value;
            }


            if(valid)
               jy_MABuffer[i] =
                  sum / jy_MAPeriod;
         }
      }
   }
   else
   {
      //--- Update MA untuk candle terbaru
      for(int i = 1; i >= 0; i--)
      {
         if(i + jy_MAPeriod > rates_total)
            continue;

         double sum = 0.0;
         bool valid = true;


         for(int j = 0; j < jy_MAPeriod; j++)
         {
            double value =
               jy_DXYBuffer[i + j];

            if(value == EMPTY_VALUE)
            {
               valid = false;
               break;
            }

            sum += value;
         }


         if(valid)
            jy_MABuffer[i] =
               sum / jy_MAPeriod;
         else
            jy_MABuffer[i] =
               EMPTY_VALUE;
      }
   }


   return rates_total;
}
//+------------------------------------------------------------------+
