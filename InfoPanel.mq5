//+------------------------------------------------------------------+
//|                                                 JayInfoPanel.mq5 |
//|                                      Copyright 2026, AI Assistant|
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

//--- Input Parameters untuk Kustomisasi Tampilan
input int      InpXDistance = 20;            // Jarak dari Kanan
input int      InpYDistance = 20;            // Jarak dari Atas
input int      InpFontSize = 10;             // Ukuran Font
input string   InpFontName = "Trebuchet MS"; // Nama Font
input color    InpColorText = clrWhite;      // Warna Teks Umum
input color    InpColorTitle = clrWhite;     // Warna Judul
input color    InpColorSub = clrAqua;        // Warna == Day Trading ==
input color    InpColorProfit = clrLime;     // Warna Profit Positif
input color    InpColorLoss = clrRed;        // Warna Profit Negatif

string prefix = "JayPanel_";
string labelNames[9];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   for(int i=0; i<9; i++)
     {
      labelNames[i] = prefix + IntegerToString(i);
      CreateLabel(labelNames[i], i);
     }
   
   EventSetMillisecondTimer(1000); // Update setiap 1 detik
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   for(int i=0; i<9; i++) ObjectDelete(0, labelNames[i]);
   ChartRedraw();
  }

void OnTimer()
  {
   UpdatePanel();
  }

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[],
                const int &spread[])
  {
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Fungsi Membuat Label (Rata Kanan)                                |
//+------------------------------------------------------------------+
void CreateLabel(string name, int index)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER); // Mencegah teks terdorong keluar layar
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpXDistance);

   int lineSpacing = InpFontSize + 6;
   int yDist = InpYDistance + (index * lineSpacing);
   if(index >= 3) yDist += 5; // Spasi ekstra untuk section Day Trading
   
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDist);
   ObjectSetString(0, name, OBJPROP_FONT, InpFontName);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Fungsi Hitung Total Deposit Asli                                 |
//+------------------------------------------------------------------+
double GetTotalDeposit()
  {
   double deposit = 0;
   // Ambil seluruh history dari awal akun dibuat
   if(HistorySelect(0, TimeCurrent()))
     {
      int total = HistoryDealsTotal();
      for(int i=0; i<total; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
           {
            long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            // Jika tipe transaksinya BALANCE (Deposit) dan nilainya plus
            if(type == DEAL_TYPE_BALANCE && profit > 0) 
               deposit += profit;
           }
        }
     }
   return (deposit > 0) ? deposit : 1.0; // Return 1.0 agar tidak terjadi Division by Zero saat hitung persentase
  }

//+------------------------------------------------------------------+
//| Fungsi Hitung Profit Harian Asli (Hari Ini Saja)                 |
//+------------------------------------------------------------------+
double GetTodayProfit()
  {
   double profit_today = 0;
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0; // Set jam ke 00:00 hari ini
   datetime start_of_day = StructToTime(dt);
   
   if(HistorySelect(start_of_day, TimeCurrent()))
     {
      int total = HistoryDealsTotal();
      for(int i=0; i<total; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
           {
            long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
            // Jangan hitung transaksi Balance (Withdraw/Deposit) ke dalam profit harian
            if(type != DEAL_TYPE_BALANCE)
              {
               profit_today += HistoryDealGetDouble(ticket, DEAL_PROFIT);
               profit_today += HistoryDealGetDouble(ticket, DEAL_SWAP);
               profit_today += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
               profit_today += HistoryDealGetDouble(ticket, DEAL_FEE);
              }
           }
        }
     }
   return profit_today;
  }

//+------------------------------------------------------------------+
//| Update Data Panel Utama                                          |
//+------------------------------------------------------------------+
void UpdatePanel()
  {
   // 1. Ambil Data Akun Dasar
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   int open_positions = PositionsTotal();
   
   // 2. Kalkulasi Data Riwayat Asli
   double total_deposit = GetTotalDeposit();
   double net_profit = balance - total_deposit; // Total pertumbuhan murni (Growth)
   double growth_percent = (net_profit / total_deposit) * 100.0;
   
   double today_profit = GetTodayProfit();
   double opening_balance = balance - today_profit;
   
   double today_profit_percent = 0.0;
   if(opening_balance > 0) today_profit_percent = (today_profit / opening_balance) * 100.0;
   
   double floating_profit = equity - balance;
   double floating_percent = 0.0;
   if(balance > 0) floating_percent = (floating_profit / balance) * 100.0;

   // Baris 0: Judul (Sudah diganti menjadi Jay Trading)
   UpdateText(labelNames[0], "Jay Trading", InpColorTitle);
   
   // Baris 1: Deposit (Asli dari riwayat akun)
   UpdateText(labelNames[1], StringFormat("Deposit : %.2f", total_deposit), InpColorText);
   
   // Baris 2: Growth (Persentase + Nominal Total Profit)
   UpdateText(labelNames[2], StringFormat("Growth : %.2f%% (%.2f)", growth_percent, net_profit), InpColorText);
   
   // Baris 3: Pembatas
   UpdateText(labelNames[3], "== Day Trading ==", InpColorSub);
   
   // Baris 4: Opening Balance (Saldo di jam 00:00 server hari ini)
   UpdateText(labelNames[4], StringFormat("Opening Balance : %.2f", opening_balance), InpColorText);
   
   // Baris 5: Current Balance 
   UpdateText(labelNames[5], StringFormat("Current Balance : %.2f", balance), InpColorText);
   
   // Baris 6: Today's Profit
   UpdateText(labelNames[6], StringFormat("Today's Profit : %.2f%% (%.2f)", today_profit_percent, today_profit), InpColorText);
   
   // Baris 7: Profit Live (Floating Equity - Balance)
   color profColor = (floating_profit > 0) ? InpColorProfit : (floating_profit < 0 ? InpColorLoss : InpColorText);
   UpdateText(labelNames[7], StringFormat("Profit : %.2f%% (%.2f)", floating_percent, floating_profit), profColor);
   
   // Baris 8: Total Posisi Terbuka
   UpdateText(labelNames[8], StringFormat("Position : %d", open_positions), InpColorText);

   ChartRedraw();
  }

void UpdateText(string name, string text, color clr)
  {
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }
//+------------------------------------------------------------------+
