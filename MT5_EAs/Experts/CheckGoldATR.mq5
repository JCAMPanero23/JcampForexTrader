//+------------------------------------------------------------------+
//|                                                CheckGoldATR.mq5 |
//|                                   Diagnostic Script for Gold ATR |
//+------------------------------------------------------------------+
#property copyright "Jcamp Forex Trader"
#property version   "1.00"
#property script_show_inputs

input string   GoldSymbol = "XAUUSD.r";        // Gold symbol
input int      ATRPeriod = 14;                 // ATR period
input bool     CompareTimeframes = true;       // Compare H1 vs H4 ATR

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("═══════════════════════════════════════════════");
    Print("GOLD ATR DIAGNOSTIC REPORT - SESSION 18 UPDATE");
    Print("═══════════════════════════════════════════════");
    Print("Symbol: ", GoldSymbol);
    Print("ATR Period: ", ATRPeriod);

    if(CompareTimeframes)
    {
        Print("\n🔍 COMPARING H1 vs H4 ATR:\n");

        // Test H1 (old setting)
        TestATRConfiguration(GoldSymbol, PERIOD_H1, ATRPeriod, 0.4, 30.0, 150.0, "OLD (Session 15-17)");

        Print("\n───────────────────────────────────────────────\n");

        // Test H4 (new setting)
        TestATRConfiguration(GoldSymbol, PERIOD_H4, ATRPeriod, 0.6, 50.0, 200.0, "NEW (Session 18)");
    }
    else
    {
        // Test single timeframe
        TestATRConfiguration(GoldSymbol, PERIOD_H4, ATRPeriod, 0.6, 50.0, 200.0, "Session 18 Settings");
    }

    Print("═══════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Test ATR Configuration                                            |
//+------------------------------------------------------------------+
void TestATRConfiguration(string symbol, ENUM_TIMEFRAMES tf, int period,
                          double multiplier, double minSL, double maxSL, string label)
{
    Print("📊 ", label, " (", EnumToString(tf), ")");
    Print("───────────────────────────────────────────────");

    //--- Get ATR value
    int atrHandle = iATR(symbol, tf, period);

    if(atrHandle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create ATR indicator");
        return;
    }

    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
    {
        Print("ERROR: Failed to copy ATR buffer");
        IndicatorRelease(atrHandle);
        return;
    }

    double atrValue = atrBuffer[0];

    //--- Calculate SL
    double calculatedSL = atrValue * multiplier;
    double finalSL = calculatedSL;
    if(finalSL < minSL) finalSL = minSL;
    if(finalSL > maxSL) finalSL = maxSL;

    //--- Calculate TP (Session 17 logic)
    int confidence = 105;
    double rrRatio = 2.5;  // Gold confidence 105 → capped at 2.5
    double tpDistance = finalSL * rrRatio;

    //--- Display
    Print("ATR Value: $", DoubleToString(atrValue, 2));
    Print("ATR Multiplier: ", multiplier);
    Print("Calculated SL: $", DoubleToString(calculatedSL, 2),
          " (ATR × multiplier)");
    Print("Min/Max Bounds: $", minSL, " / $", maxSL);
    Print("Final SL: $", DoubleToString(finalSL, 2));

    if(finalSL == minSL)
        Print("⚠️ HIT MINIMUM BOUND (ATR too low)");
    else if(finalSL == maxSL)
        Print("⚠️ HIT MAXIMUM BOUND (ATR very high)");
    else
        Print("✅ Within bounds (using ATR-calculated value)");

    Print("Take Profit: $", DoubleToString(tpDistance, 2),
          " (R:R 1:2.5, conf ", confidence, ")");

    //--- Risk assessment
    double riskPips = finalSL;
    if(riskPips < 40)
        Print("🚨 RISK: Too tight! Gold noise > $40/hour");
    else if(riskPips < 55)
        Print("⚠️  RISK: Marginal (50-55 acceptable in quiet markets)");
    else if(riskPips < 80)
        Print("✅ RISK: Good (55-80 normal range)");
    else if(riskPips < 120)
        Print("✅ RISK: Wide but safe (80-120 volatile markets)");
    else
        Print("⚠️  RISK: Very wide (>120 extreme volatility)");

    IndicatorRelease(atrHandle);
}
