//+------------------------------------------------------------------+
//|                                  Streak_Dominance_Final_Fixed.mq5|
//|                                  Copyright 2026, AI Collaborator |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AI Collaborator"
#property version   "7.10"
#property indicator_chart_window

input bool     ShowStats           = true;       
input int      InpMinStreak        = 4;          
input int      InpMaxHistory       = 5000;       
input color    InpBullColor        = clrLightGreen; 
input color    InpBearColor        = clrTomato;     
input color    InpBullStatsColor   = clrLime;       
input color    InpBearStatsColor   = clrTomato;     
input int      InpTransparency     = 60;         

int OnInit() { return(INIT_SUCCEEDED); }
void OnDeinit(const int reason) { ObjectsDeleteAll(0, "STRK_"); ObjectDelete(0, "SimpleDash"); ObjectDelete(0, "LookbackDash"); }

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
    if(rates_total < 100) return(0);
    ArraySetAsSeries(time, true); ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(open, true);

    // Kunci utama anti-repaint dan anti-error: Hanya update saat bar benar-benar ganti
    if(prev_calculated == rates_total) return(rates_total);
    
    ObjectsDeleteAll(0, "STRK_");

    int upCount = 0, downCount = 0;
    int limit = MathMin(rates_total - 50, InpMaxHistory);

    // Mulai dari j=1 untuk mengecualikan candle running
    for(int j = 1; j < limit; j++) {
        // Tentukan arah berdasarkan badan candle (Body Color)
        bool isBull = (close[j] > open[j]);
        bool isBear = (close[j] < open[j]);
        
        if(!isBull && !isBear) continue; 

        int hLen = 0;
        // Hitung ke belakang: pastikan candle k memiliki warna yang sama dengan candle j
        for(int k = j; k < limit; k++) {
            if(isBull && close[k] > open[k]) hLen++;
            else if(isBear && close[k] < open[k]) hLen++;
            else break; // Langsung berhenti jika warna candle berubah
        }

        if(hLen >= InpMinStreak) {
            if(isBull) upCount++; else downCount++;
            
            string objName = "STRK_" + TimeToString(time[j], TIME_DATE|TIME_MINUTES);
            // Gambar kotak dengan panjang (hLen) yang sudah akurat sesuai warna
            DrawBoxWithLabel(objName, j, hLen, (isBull?InpBullColor:InpBearColor), time, high, low);
            
            j += (hLen - 1); 
        }
    }

    if(ShowStats) {
        string domText = (upCount > downCount) ? "BULLISH DOMINANT" : (downCount > upCount ? "BEARISH DOMINANT" : "BALANCED");
        color domCol = (upCount > downCount) ? InpBullStatsColor : (downCount > upCount ? InpBearStatsColor : clrWhite);
        UpdateDash(StringFormat("DOMINANCE: %s | UP: %d | DOWN: %d", domText, upCount, downCount), 
                   StringFormat("DATA: %d CLOSED BARS", limit), domCol);
    }

    return(rates_total);
}

void UpdateDash(string t1, string t2, color c) {
    if(ObjectFind(0, "SimpleDash") < 0) ObjectCreate(0, "SimpleDash", OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, "SimpleDash", OBJPROP_TEXT, t1);
    ObjectSetInteger(0, "SimpleDash", OBJPROP_COLOR, c);
    ObjectSetInteger(0, "SimpleDash", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "SimpleDash", OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, "SimpleDash", OBJPROP_YDISTANCE, 45);

    if(ObjectFind(0, "LookbackDash") < 0) ObjectCreate(0, "LookbackDash", OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, "LookbackDash", OBJPROP_TEXT, t2);
    ObjectSetInteger(0, "LookbackDash", OBJPROP_COLOR, clrGray);
    ObjectSetInteger(0, "LookbackDash", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "LookbackDash", OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, "LookbackDash", OBJPROP_YDISTANCE, 65);
}

void DrawBoxWithLabel(string name, int s, int l, color c, const datetime &t[], const double &h[], const double &lw[]) {
    double mxH = h[s], mnL = lw[s];
    for(int i=s; i<s+l; i++) { 
        if(h[i]>mxH) mxH=h[i]; 
        if(lw[i]<mnL) mnL=lw[i]; 
    }
    
    if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t[s+l-1], mxH, t[s], mnL)) {
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_COLOR, c);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, ColorToARGB(c, (uchar)InpTransparency));
    }
    
    string lbl = name + "_L";
    if(ObjectCreate(0, lbl, OBJ_TEXT, 0, t[s], mnL)) {
        ObjectSetString(0, lbl, OBJPROP_TEXT, (string)l);
        ObjectSetInteger(0, lbl, OBJPROP_COLOR, c);
        ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, ANCHOR_UPPER);
    }
}
