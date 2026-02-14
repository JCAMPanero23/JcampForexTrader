//+------------------------------------------------------------------+
//|                                           PositionTracker.mqh     |
//|                                            JcampForexTrader       |
//|                      Session 21 - Profit Lock + Chandelier       |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.10"
#property strict

//+------------------------------------------------------------------+
//| Position Data Structure (Enhanced for Session 21)                |
//+------------------------------------------------------------------+
struct PositionData
{
    ulong    ticket;
    string   symbol;
    string   strategy;               // TREND_RIDER, RANGE_RIDER, GOLD_TREND_RIDER
    int      signal;                 // 1=BUY, -1=SELL
    double   entryPrice;
    double   originalSLDistance;     // In price units (for R calculation)
    double   maxR;                   // Highest R-multiple achieved
    datetime entryTime;
    bool     trailingActivated;      // Has trailing started? (at +0.5R)
    int      currentPhase;           // 1, 2, or 3
    bool     breakevenSet;           // Has breakeven been set? (RangeRider only)
    double   highWaterMark;          // Track highest/lowest price for trailing
    bool     profitLocked;           // Session 21: Has 1.5R profit lock been triggered?
    bool     chandelierActive;       // Session 21: Is Chandelier trailing active?
};
