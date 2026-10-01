//+------------------------------------------------------------------+
//|                                        StochZigZagDivergence.mq5 |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2
#property indicator_minimum 0
#property indicator_maximum 100

//--- plot Levels
#property indicator_level1  20
#property indicator_level2  50
#property indicator_level3  80
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT

//--- plot Stochastic %K
#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot Stochastic %D
#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Inputs (Stochastic)
input int inp_KPeriod       = 14;     // Stochastic %K Period
input int inp_DPeriod       = 3;      // Stochastic %D Period
input int inp_Slowing       = 3;      // Stochastic Slowing

//--- Inputs (ZigZag & Divergence)
input int inp_ZZDepth       = 12;     // ZigZag Depth
input int inp_ZZDeviation   = 5;      // ZigZag Deviation
input int inp_ZZBackstep    = 3;      // ZigZag Backstep
input double inp_Tolerance  = 5.0;    // Toleransi Stochastic Datar (Poin)
input int inp_MaxBars       = 500;    // Maksimal Bar History Divergensi
input bool inp_RequireCross = true;   // Wajib Konfirmasi Stochastic Cross Signal Line

//--- Inputs (Alerts & Notifications)
input bool inp_EnableAlerts = true;   // Tampilkan Pop-up & Suara
input bool inp_EnablePush   = true;   // Kirim Push Notification ke HP
input int inp_AlertCandles  = 3;      // Ingatkan sampai X candle ke depan

//--- Inputs (Visual)
input color inp_BullColor   = clrLimeGreen; // Warna Garis Bullish
input color inp_BearColor   = clrRed;       // Warna Garis Bearish

//--- Buffers (Layar)
double BufferK[];
double BufferD[];

//--- Buffers (Kalkulasi Internal)
double BaseK[];
double BufferZigZag[]; 

//--- Handles & Variables Global
int zigzag_handle;
int subwindow_id = -1;
string last_drawn_main_line = "";
string last_drawn_sub_line  = "";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);
   SetIndexBuffer(2, BaseK, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferZigZag, INDICATOR_CALCULATIONS);
   
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "Stoch Divergence");

   zigzag_handle = iCustom(Symbol(), Period(), "Examples\\ZigZag", inp_ZZDepth, inp_ZZDeviation, inp_ZZBackstep);
   if(zigzag_handle == INVALID_HANDLE) 
     { Print("Gagal memuat ZigZag!"); return(INIT_FAILED); }

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "StochDiv_");
  }

void DrawDivergenceLine(string name, int window, datetime time1, double price1, datetime time2, double price2, color lineColor)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TREND, window, time1, price1, time2, price2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
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
   if(rates_total < inp_KPeriod) return 0;

   // Cache subwindow ID sekali saja
   if(subwindow_id < 0) subwindow_id = ChartWindowFind();

   int limit = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   // 1. KALKULASI STOCHASTIC (INCRMENTAL UNTUK MENCEGAH FLICKER)
   for (int i = limit; i < rates_total; i++)
     {
      double min_low = low[i];
      double max_high = high[i];
      
      int start_idx = i - inp_KPeriod + 1;
      if (start_idx < 0) start_idx = 0;

      for (int k = start_idx; k <= i; k++)
        {
         if (low[k] < min_low) min_low = low[k];
         if (high[k] > max_high) max_high = high[k];
        }

      if (max_high != min_low)
         BaseK[i] = (close[i] - min_low) / (max_high - min_low) * 100.0;
      else
         BaseK[i] = (i > 0) ? BaseK[i-1] : 50.0;
     }

   for (int i = limit; i < rates_total; i++)
     {
      double sum = 0;
      int start_idx = i - inp_Slowing + 1;
      if (start_idx < 0) start_idx = 0;
      for (int k = start_idx; k <= i; k++) sum += BaseK[k];
      BufferK[i] = sum / (i - start_idx + 1);
     }

   for (int i = limit; i < rates_total; i++)
     {
      double sum = 0;
      int start_idx = i - inp_DPeriod + 1;
      if (start_idx < 0) start_idx = 0;
      for (int k = start_idx; k <= i; k++) sum += BufferK[k];
      BufferD[i] = sum / (i - start_idx + 1);
     }

   // 2. PEMROSESAN GRAFIK & DIVERGENSI (HANYA SAAT CANDLE BARU / LOAD AWAL)
   static datetime last_bar_time = 0;
   static datetime last_alert_time = 0;
   static int alert_count = 0;
   
   datetime current_time = time[rates_total - 1];

   if(current_time != last_bar_time || prev_calculated == 0)
     {
      last_bar_time = current_time;

      // Copy buffer ZigZag
      double tempZZ[];
      if(CopyBuffer(zigzag_handle, 0, 0, rates_total, tempZZ) > 0)
        {
         for(int i = 0; i < rates_total; i++) BufferZigZag[i] = tempZZ[i];
        }

      // Hapus seluruh garis lama saat buka candle baru
      ObjectsDeleteAll(0, "StochDiv_");

      string valid_objects = "";
      datetime latest_div_time = 0;
      string latest_div_msg = "";
      
      int div_limit = MathMax(0, rates_total - inp_MaxBars);
      int loop_end = rates_total - 1; 

      for(int i = div_limit; i < loop_end; i++)
        {
         if(BufferZigZag[i] > 0.0 && BufferZigZag[i] != EMPTY_VALUE)
           {
            bool isPeak = (MathAbs(BufferZigZag[i] - high[i]) < Point());
            bool isTrough = (MathAbs(BufferZigZag[i] - low[i]) < Point());
            
            // CEK BEARISH DIVERGENCE (PUNCAK)
            if(isPeak)
              {
               bool crossConfirmed = true;
               if(inp_RequireCross)
                 {
                  crossConfirmed = false;
                  for(int c = i; c < rates_total; c++)
                    {
                     if(BufferK[c] < BufferD[c]) { crossConfirmed = true; break; }
                    }
                 }
               if(!crossConfirmed) continue;

               int stoch_idx_current = i;
               double max_stoch = BufferK[i];
               for(int k = MathMax(0, i-2); k <= MathMin(rates_total-1, i+2); k++) {
                   if(BufferK[k] > max_stoch && BufferK[k] != EMPTY_VALUE) { max_stoch = BufferK[k]; stoch_idx_current = k; }
               }
               
               double price_current = high[i], stoch_current = max_stoch;

               for(int j = i - 1; j >= 0; j--)
                 {
                  if(BufferZigZag[j] > 0.0 && BufferZigZag[j] != EMPTY_VALUE && MathAbs(BufferZigZag[j] - high[j]) < Point())
                    {
                     int stoch_idx_prev = j;
                     double max_stoch_j = BufferK[j];
                     for(int k = MathMax(0, j-2); k <= MathMin(rates_total-1, j+2); k++) {
                         if(BufferK[k] > max_stoch_j && BufferK[k] != EMPTY_VALUE) { max_stoch_j = BufferK[k]; stoch_idx_prev = k; }
                     }
                     
                     double price_prev = high[j], stoch_prev = max_stoch_j;
                     
                     bool isRegularBearish = (price_current > price_prev && stoch_current <= (stoch_prev + inp_Tolerance));
                     bool isHiddenBearish  = (price_current < price_prev && stoch_current >= (stoch_prev - inp_Tolerance));
                     
                     if(isRegularBearish || isHiddenBearish)
                       {
                        string main_name = "StochDiv_Main_Bear_" + TimeToString(time[j]) + "_" + TimeToString(time[i]);
                        string sub_name  = "StochDiv_Sub_Bear_"  + TimeToString(time[j]) + "_" + TimeToString(time[i]);
                        
                        DrawDivergenceLine(main_name, 0, time[j], price_prev, time[i], price_current, inp_BearColor);
                        DrawDivergenceLine(sub_name, subwindow_id, time[stoch_idx_prev], stoch_prev, time[stoch_idx_current], stoch_current, inp_BearColor);
                        
                        last_drawn_main_line = main_name;
                        last_drawn_sub_line  = sub_name;

                        if(time[i] > latest_div_time)
                          {
                           latest_div_time = time[i];
                           latest_div_msg = (isRegularBearish ? "Regular Bearish" : "Hidden Bearish") + " Div: " + Symbol() + " (" + EnumToString(Period()) + ")";
                          }
                       }
                     break; 
                    }
                 }
              }

            // CEK BULLISH DIVERGENCE (LEMBAH)
            if(isTrough)
              {
               bool crossConfirmed = true;
               if(inp_RequireCross)
                 {
                  crossConfirmed = false;
                  for(int c = i; c < rates_total; c++)
                    {
                     if(BufferK[c] > BufferD[c]) { crossConfirmed = true; break; }
                    }
                 }
               if(!crossConfirmed) continue;

               int stoch_idx_current = i;
               double min_stoch = BufferK[i];
               for(int k = MathMax(0, i-2); k <= MathMin(rates_total-1, i+2); k++) {
                   if(BufferK[k] < min_stoch && BufferK[k] != EMPTY_VALUE) { min_stoch = BufferK[k]; stoch_idx_current = k; }
               }
               
               double price_current = low[i], stoch_current = min_stoch;

               for(int j = i - 1; j >= 0; j--)
                 {
                  if(BufferZigZag[j] > 0.0 && BufferZigZag[j] != EMPTY_VALUE && MathAbs(BufferZigZag[j] - low[j]) < Point())
                    {
                     int stoch_idx_prev = j;
                     double min_stoch_j = BufferK[j];
                     for(int k = MathMax(0, j-2); k <= MathMin(rates_total-1, j+2); k++) {
                         if(BufferK[k] < min_stoch_j && BufferK[k] != EMPTY_VALUE) { min_stoch_j = BufferK[k]; stoch_idx_prev = k; }
                     }
                     
                     double price_prev = low[j], stoch_prev = min_stoch_j;
                     
                     bool isRegularBullish = (price_current < price_prev && stoch_current >= (stoch_prev - inp_Tolerance));
                     bool isHiddenBullish  = (price_current > price_prev && stoch_current <= (stoch_prev + inp_Tolerance));
                     
                     if(isRegularBullish || isHiddenBullish)
                       {
                        string main_name = "StochDiv_Main_Bull_" + TimeToString(time[j]) + "_" + TimeToString(time[i]);
                        string sub_name  = "StochDiv_Sub_Bull_"  + TimeToString(time[j]) + "_" + TimeToString(time[i]);
                        
                        DrawDivergenceLine(main_name, 0, time[j], price_prev, time[i], price_current, inp_BullColor);
                        DrawDivergenceLine(sub_name, subwindow_id, time[stoch_idx_prev], stoch_prev, time[stoch_idx_current], stoch_current, inp_BullColor);
                        
                        last_drawn_main_line = main_name;
                        last_drawn_sub_line  = sub_name;

                        if(time[i] > latest_div_time)
                          {
                           latest_div_time = time[i];
                           latest_div_msg = (isRegularBullish ? "Regular Bullish" : "Hidden Bullish") + " Div: " + Symbol() + " (" + EnumToString(Period()) + ")";
                          }
                       }
                     break; 
                    }
                 }
              }
           }
        }

      // ALERT SYSTEM
      if(latest_div_time > 0)
        {
         if(prev_calculated > 0)
           {
            if(latest_div_time > last_alert_time)
              {
               last_alert_time = latest_div_time;
               alert_count = 1;
               string final_msg = latest_div_msg + " [Baru Terbentuk]";
               if(inp_EnableAlerts) Alert(final_msg);
               if(inp_EnablePush) SendNotification(final_msg);
              }
            else if(latest_div_time == last_alert_time && alert_count < inp_AlertCandles)
              {
               alert_count++;
               string final_msg = latest_div_msg + " [Peringatan " + IntegerToString(alert_count) + "/" + IntegerToString(inp_AlertCandles) + "]";
               if(inp_EnableAlerts) Alert(final_msg);
               if(inp_EnablePush) SendNotification(final_msg);
              }
           }
         else if(prev_calculated == 0)
           {
            last_alert_time = latest_div_time;
            alert_count = inp_AlertCandles;
           }
        }
     }
   else
     {
      // 3. INTRA-CANDLE REAL-TIME REFRESH (Ringan & Tanpa Flicker)
      // Jika candle berjalan menembus level swing aktif, langsung hapus garis aktif tersebut
      if(last_drawn_main_line != "" && ObjectFind(0, last_drawn_main_line) >= 0)
        {
         double p2 = ObjectGetDouble(0, last_drawn_main_line, OBJPROP_PRICE, 1);
         if(StringFind(last_drawn_main_line, "Bull") >= 0 && low[rates_total - 1] < p2)
           {
            ObjectDelete(0, last_drawn_main_line);
            ObjectDelete(0, last_drawn_sub_line);
            last_drawn_main_line = "";
            last_drawn_sub_line = "";
           }
         else if(StringFind(last_drawn_main_line, "Bear") >= 0 && high[rates_total - 1] > p2)
           {
            ObjectDelete(0, last_drawn_main_line);
            ObjectDelete(0, last_drawn_sub_line);
            last_drawn_main_line = "";
            last_drawn_sub_line = "";
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
