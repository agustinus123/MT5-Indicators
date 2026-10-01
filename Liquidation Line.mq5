//+------------------------------------------------------------------+
//|                                   Liquidation_Final_Clean.mq5    |
//|                                  Copyright 2026, Gemini AI Labs  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini AI"
#property indicator_chart_window
#property indicator_plots 0

input double InpStopOutLevel = 50.0;      
input color  InpLineColor    = clrRed;      
input int    InpWidth        = 2;           

string obj_name = "LQD_FINAL_LINE";

//+------------------------------------------------------------------+
int OnInit() { 
    EventSetTimer(1); 
    return(INIT_SUCCEEDED); 
}

//+------------------------------------------------------------------+
// FUNGSI PEMBERSIHAN SAAT INDIKATOR DIHAPUS
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { 
    EventKillTimer(); 
    ObjectDelete(0, obj_name); // Hapus garis
    Comment("");               // Hapus teks statistik di pojok layar
    ChartRedraw();             // Paksa chart untuk refresh tampilan
}

void OnTimer() { Calculate(); }
int OnCalculate(const int r, const int p, const datetime &t[], const double &o[], const double &h[], const double &l[], const double &c[], const long &tv[], const long &v[], const int &s[]) 
{ Calculate(); return(r); }

//+------------------------------------------------------------------+
void Calculate() {
    double total_lots = 0;
    long   pos_type = -1;
    bool   found = false;
    double current_p = 0;

    for(int i = 0; i < PositionsTotal(); i++) {
        string pos_symbol = PositionGetSymbol(i);
        if(pos_symbol == _Symbol) {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket)) {
                total_lots += PositionGetDouble(POSITION_VOLUME);
                pos_type = PositionGetInteger(POSITION_TYPE);
                current_p = PositionGetDouble(POSITION_PRICE_CURRENT);
                found = true;
            }
        }
    }

    if(!found || total_lots <= 0) {
        ObjectDelete(0, obj_name);
        Comment(""); // Hapus teks jika posisi ditutup manual
        return;
    }

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double margin = AccountInfoDouble(ACCOUNT_MARGIN);

    // Rumus sesuai spek akun Anda: 1 Lot Cent = 100 USC per $1 move
    double usc_per_dollar_move = total_lots * 100.0; 
    double so_threshold = margin * (InpStopOutLevel / 100.0);
    double usable_usc   = equity - so_threshold;
    double distance = (usc_per_dollar_move > 0) ? (usable_usc / usc_per_dollar_move) : 0;
    
    double liq_p = (pos_type == POSITION_TYPE_BUY) ? (current_p - distance) : (current_p + distance);

    // Update Garis
    if(ObjectFind(0, obj_name) < 0) {
        ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, liq_p);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, InpLineColor);
        ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, InpWidth);
    } else {
        ObjectSetDouble(0, obj_name, OBJPROP_PRICE, liq_p);
    }
    
    // Update Teks Stat
    string msg = "=== MC CALCULATOR (CENT) ===\n";
    msg += "Equity   : " + DoubleToString(equity, 2) + " USC\n";
    msg += "Total Lot: " + DoubleToString(total_lots, 2) + " Lot Cent\n";
    msg += "Risk     : " + DoubleToString(usc_per_dollar_move, 2) + " USC per $1 move\n";
    msg += "---------------------------\n";
    msg += "EST. MC PRICE: " + DoubleToString(liq_p, 2);
    Comment(msg);
}
