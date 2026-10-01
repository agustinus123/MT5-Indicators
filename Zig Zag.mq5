#property copyright "Copyright 2024"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

// Plot 1: Garis Histori (Hijau) - Fixed
#property indicator_label1  "ZigZag Fixed"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: Garis Terakhir (Merah) - Dynamic
#property indicator_label2  "ZigZag Dynamic"
#property indicator_type2   DRAW_SECTION
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  2

// Input
input int InpDepth    = 12;
input int InpDeviation = 5;
input int InpBackstep  = 3;

// Buffers
double BufferFixed[];   // Buffer Hijau
double BufferDynamic[]; // Buffer Merah

int handleZZ;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufferFixed, INDICATOR_DATA);
   SetIndexBuffer(1, BufferDynamic, INDICATOR_DATA);
   
   // Set nilai kosong agar tidak ditarik ke harga 0
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   
   // Ambil data dari ZigZag bawaan
   handleZZ = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpDepth, InpDeviation, InpBackstep);
   
   if(handleZZ == INVALID_HANDLE) return(INIT_FAILED);
   
   return(INIT_SUCCEEDED);
}

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
   double tempZZ[];
   ArraySetAsSeries(tempZZ, true);
   
   // Ambil data ZigZag asli (Buffer 0)
   if(CopyBuffer(handleZZ, 0, 0, rates_total, tempZZ) < 0) return(0);

   // Bersihkan buffer setiap kali kalkulasi
   ArrayInitialize(BufferFixed, 0.0);
   ArrayInitialize(BufferDynamic, 0.0);

   int lastIdx = -1;
   int secondLastIdx = -1;
   int thirdLastIdx = -1;

   // 1. Cari 3 titik ZigZag terakhir dari data mentah
   int found = 0;
   for(int i = 0; i < rates_total; i++)
   {
      // ZigZag MT5 memberikan nilai 0 atau EMPTY_VALUE (sangat besar) jika tidak ada titik
      if(tempZZ[i] > 0 && tempZZ[i] < 1000000)
      {
         if(found == 0) lastIdx = i;
         if(found == 1) secondLastIdx = i;
         if(found == 2) thirdLastIdx = i;
         found++;
         
         // Masukkan semua titik ke Buffer Hijau dulu
         BufferFixed[rates_total - 1 - i] = tempZZ[i];
      }
   }

   // 2. Logika Pemisahan:
   // Titik 'lastIdx' adalah titik yang masih bergerak (merah).
   // Kita hapus titik itu dari Hijau, lalu pindahkan ke Merah.
   if(lastIdx != -1 && secondLastIdx != -1)
   {
      int posLast = rates_total - 1 - lastIdx;
      int posSecond = rates_total - 1 - secondLastIdx;

      // Hapus titik terakhir dari garis hijau
      BufferFixed[posLast] = 0.0;
      
      // Buat garis merah dari titik kedua terakhir ke titik paling ujung
      BufferDynamic[posSecond] = tempZZ[secondLastIdx];
      BufferDynamic[posLast] = tempZZ[lastIdx];
   }

   return(rates_total);
}
