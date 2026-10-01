//+------------------------------------------------------------------+
//|                                                SMASlopeAngle.mq5 |
//|                                      Assistant / Gemini AI       |
//+------------------------------------------------------------------+
#property copyright "Assistant"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Input Parameters
input int              InpSMAPeriod       = 200;                // SMA Period
input double           InpScaleFactor     = 1.0;                // Faktor Skala (Gold: 1-10, Forex: 1000-10000)
input double           InpSidewaysAngle   = 5.0;                // Threshold Derajat Sideways (+/-)
input ENUM_BASE_CORNER InpCorner          = CORNER_RIGHT_UPPER; // Posisi Teks di Chart
input int              InpFontSize        = 12;                 // Ukuran Font

//--- Global Variables
int    handle_sma;
double sma_buffer[];
string label_name = "SMASlopeLabel_AI";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   handle_sma = iMA(_Symbol, _Period, InpSMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(handle_sma == INVALID_HANDLE)
     {
      Print("Gagal memuat indikator SMA");
      return(INIT_FAILED);
     }
     
   ArraySetAsSeries(sma_buffer, true);

   if(!ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0))
     {
      Print("Gagal membuat label teks!");
      return(INIT_FAILED);
     }
     
   ObjectSetInteger(0, label_name, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, 50);
   ObjectSetString(0, label_name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, label_name);
   IndicatorRelease(handle_sma);
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
   // Pastikan chart memiliki bar yang cukup (minimal sejumlah periode SMA + buffer)
   if(rates_total < InpSMAPeriod + 2) 
      return(0);

   // Ambil data SMA sebanyak periode (InpSMAPeriod + 2 untuk amannya)
   if(CopyBuffer(handle_sma, 0, 0, InpSMAPeriod + 2, sma_buffer) <= 0)
      return(0);

   // sma_buffer[1] adalah nilai SMA di candle terakhir yang sudah close
   // sma_buffer[InpSMAPeriod] adalah nilai SMA 200 bar yang lalu
   double sma_current = sma_buffer[1];
   double sma_past    = sma_buffer[InpSMAPeriod];

   // Hitung selisih harga (Sumbu Y)
   double diff_price  = sma_current - sma_past;
   
   // Jarak waktu/bar (Sumbu X) adalah sepanjang periode SMA itu sendiri
   double dx = InpSMAPeriod;

   // Kalikan Sumbu Y dengan Faktor Skala
   double scaled_dy = diff_price * InpScaleFactor;

   // Hitung derajat (Arctan(dy/dx)) 
   // Ini akan menghasilkan rata-rata sudut/kemiringan per bar selama 200 bar terakhir
   double angle_rad = MathArctan(scaled_dy / dx);
   double angle_deg = angle_rad * 180.0 / M_PI; // Konversi Radian ke Derajat

   // Tentukan Status dan Warna
   string status_text = "";
   color  status_color = clrWhite;

   if(MathAbs(angle_deg) <= InpSidewaysAngle)
     {
      status_text = "SIDEWAYS";
      status_color = clrYellow;
     }
   else if(angle_deg > 0)
     {
      status_text = "TREND NAIK (Up)";
      status_color = clrLime;
     }
   else
     {
      status_text = "TREND TURUN (Down)";
      status_color = clrRed;
     }

   // Format teks (menampilkan angka derajat dengan 2 desimal)
   string final_text = StringFormat("SMA %d : %s (%.2f°)", InpSMAPeriod, status_text, angle_deg);

   ObjectSetString(0, label_name, OBJPROP_TEXT, final_text);
   ObjectSetInteger(0, label_name, OBJPROP_COLOR, status_color);

   return(rates_total);
  }
//+------------------------------------------------------------------+
