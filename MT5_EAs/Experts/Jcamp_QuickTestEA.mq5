//+------------------------------------------------------------------+
//|                                           Jcamp_QuickTestEA.mq5  |
//|                                            JcampForexTrader       |
//|  Quick Testing EA - Auto-trades every X minutes for testing      |
//|  trade history export, CSMMonitor updates, and performance       |
//|  tracking without waiting for real signals                        |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

//--- Include performance tracker for trade history export
#include <JcampStrategies/Trading/PerformanceTracker.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "═══ TESTING SETTINGS ═══"
input bool   EnableTestTrading = true;                  // Enable test trading
input int    TestIntervalMinutes = 5;                   // Trade every X minutes
input bool   TestAllSymbols = true;                     // Rotate through all 4 symbols
input bool   AlternateBuySell = true;                   // Alternate BUY/SELL directions

input group "═══ POSITION SETTINGS ═══"
input double TestLotSize = 0.01;                        // Lot size (micro lots recommended)
input int    StopLossPips = 30;                         // Stop loss in pips
input int    TakeProfitPips = 60;                       // Take profit in pips (2R)
input bool   EnableAutoClose = true;                    // Auto-close positions
input int    AutoCloseMinutes = 3;                      // Auto-close after X minutes

input group "═══ SAFETY SETTINGS ═══"
input int    MaxTestPositions = 4;                      // Max total test positions
input int    MaxPositionsPerSymbol = 1;                 // Max positions per symbol
input bool   VerboseLogging = true;                     // Detailed logging

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
const int MAGIC_NUMBER = 999999;  // Easy to identify test trades
const string TEST_STRATEGY = "QUICK_TEST";

// Symbol rotation
string testSymbols[4] = {"EURUSD", "GBPUSD", "AUDJPY", "XAUUSD"};
int currentSymbolIndex = 0;
bool lastTradeWasBuy = false;

// Timing
datetime lastTradeTime = 0;
datetime lastAutoCloseCheck = 0;

// Performance tracker
PerformanceTracker* perfTracker = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("═══════════════════════════════════════════════════════════");
    Print("🧪 QUICK TEST EA - Trade History Testing Tool");
    Print("═══════════════════════════════════════════════════════════");
    Print("Version: 1.00");
    Print("Symbol: ", _Symbol);
    Print("Magic Number: ", MAGIC_NUMBER);
    Print("");

    // Initialize performance tracker (auto-loads existing history)
    perfTracker = new PerformanceTracker("CSM_Data", MAGIC_NUMBER, VerboseLogging);

    Print("Settings:");
    Print("  - Test Trading: ", EnableTestTrading ? "ENABLED" : "DISABLED");
    Print("  - Test Interval: ", TestIntervalMinutes, " minutes");
    Print("  - Test All Symbols: ", TestAllSymbols ? "YES" : "NO (current symbol only)");
    Print("  - Alternate Buy/Sell: ", AlternateBuySell ? "YES" : "NO");
    Print("  - Lot Size: ", TestLotSize);
    Print("  - SL/TP: ", StopLossPips, "/", TakeProfitPips, " pips");
    Print("  - Auto-close: ", EnableAutoClose ? "YES (" : "NO", EnableAutoClose ? IntegerToString(AutoCloseMinutes) + " min)" : "");
    Print("");
    Print("🚨 WARNING: This EA will automatically trade every ", TestIntervalMinutes, " minutes!");
    Print("🚨 Use MICRO LOTS only for testing purposes!");
    Print("");
    Print("═══════════════════════════════════════════════════════════");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🧪 Quick Test EA stopped. Reason: ", reason);

    // Cleanup
    if(perfTracker != NULL)
    {
        delete perfTracker;
        perfTracker = NULL;
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!EnableTestTrading)
        return;

    // Check for new trade opportunity
    CheckForNewTrade();

    // Check for auto-close (every 30 seconds)
    if(EnableAutoClose && TimeCurrent() - lastAutoCloseCheck >= 30)
    {
        CheckAutoClose();
        lastAutoCloseCheck = TimeCurrent();
    }

    // Update performance tracker (exports history)
    if(perfTracker != NULL)
        perfTracker.Update();
}

//+------------------------------------------------------------------+
//| Check if it's time to open a new test trade                      |
//+------------------------------------------------------------------+
void CheckForNewTrade()
{
    datetime currentTime = TimeCurrent();
    int minutesSinceLastTrade = (int)((currentTime - lastTradeTime) / 60);

    // Wait for interval to pass
    if(minutesSinceLastTrade < TestIntervalMinutes)
        return;

    // Check position limits
    int totalPositions = CountTestPositions("");
    if(totalPositions >= MaxTestPositions)
    {
        if(VerboseLogging)
            Print("⚠️ Max test positions reached (", totalPositions, "/", MaxTestPositions, ")");
        return;
    }

    // Determine which symbol to trade
    string symbolToTrade = DetermineNextSymbol();

    // Check per-symbol limit
    int symbolPositions = CountTestPositions(symbolToTrade);
    if(symbolPositions >= MaxPositionsPerSymbol)
    {
        if(VerboseLogging)
            Print("⚠️ Max positions for ", symbolToTrade, " reached (", symbolPositions, "/", MaxPositionsPerSymbol, ")");

        // Try next symbol
        currentSymbolIndex = (currentSymbolIndex + 1) % 4;
        return;
    }

    // Determine trade direction
    ENUM_ORDER_TYPE tradeType = DetermineTradeDirection();

    // Open test trade
    OpenTestTrade(symbolToTrade, tradeType);

    lastTradeTime = currentTime;
}

//+------------------------------------------------------------------+
//| Determine which symbol to trade next                             |
//+------------------------------------------------------------------+
string DetermineNextSymbol()
{
    if(!TestAllSymbols)
        return _Symbol;  // Just use current chart symbol

    // Rotate through symbols
    string symbol = testSymbols[currentSymbolIndex];
    currentSymbolIndex = (currentSymbolIndex + 1) % 4;

    return symbol;
}

//+------------------------------------------------------------------+
//| Determine trade direction (BUY or SELL)                          |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE DetermineTradeDirection()
{
    if(!AlternateBuySell)
        return ORDER_TYPE_BUY;  // Always buy if not alternating

    // Alternate
    lastTradeWasBuy = !lastTradeWasBuy;
    return lastTradeWasBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

//+------------------------------------------------------------------+
//| Open a test trade                                                 |
//+------------------------------------------------------------------+
void OpenTestTrade(string symbol, ENUM_ORDER_TYPE orderType)
{
    // Get symbol info
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

    // Adjust for broker suffix
    string tradingSymbol = symbol;
    if(!SymbolSelect(symbol, true))
    {
        // Try with .sml suffix
        tradingSymbol = symbol + ".sml";
        if(!SymbolSelect(tradingSymbol, true))
        {
            Print("❌ ERROR: Symbol ", symbol, " not found!");
            return;
        }
    }

    // Get current price
    double price;
    if(orderType == ORDER_TYPE_BUY)
        price = SymbolInfoDouble(tradingSymbol, SYMBOL_ASK);
    else
        price = SymbolInfoDouble(tradingSymbol, SYMBOL_BID);

    if(price <= 0)
    {
        Print("❌ ERROR: Invalid price for ", tradingSymbol);
        return;
    }

    // Calculate SL/TP
    double pipSize = point;
    if(digits == 3 || digits == 5)
        pipSize = point * 10;  // Account for 5-digit brokers

    // Special handling for Gold (XAUUSD)
    double sl, tp;
    if(StringFind(symbol, "XAU") >= 0)
    {
        // Gold: dollar-based stops
        sl = orderType == ORDER_TYPE_BUY ? price - StopLossPips : price + StopLossPips;
        tp = orderType == ORDER_TYPE_BUY ? price + TakeProfitPips : price - TakeProfitPips;
    }
    else
    {
        // Forex: pip-based stops
        sl = orderType == ORDER_TYPE_BUY ? price - (StopLossPips * pipSize) : price + (StopLossPips * pipSize);
        tp = orderType == ORDER_TYPE_BUY ? price + (TakeProfitPips * pipSize) : price - (TakeProfitPips * pipSize);
    }

    // Normalize prices
    price = NormalizeDouble(price, digits);
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);

    // Create comment
    string comment = StringFormat("QUICK_TEST %s @%d conf",
                                  orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", 100);

    // Prepare request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = tradingSymbol;
    request.volume = TestLotSize;
    request.type = orderType;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = MAGIC_NUMBER;
    request.comment = comment;
    request.type_filling = ORDER_FILLING_FOK;

    // Try ORDER_FILLING_IOC if FOK fails
    bool success = false;
    if(!OrderSend(request, result))
    {
        request.type_filling = ORDER_FILLING_IOC;
        if(!OrderSend(request, result))
        {
            request.type_filling = ORDER_FILLING_RETURN;
            success = OrderSend(request, result);
        }
    }

    // Check result
    if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
    {
        Print("🧪 TEST TRADE OPENED:");
        Print("   Symbol: ", tradingSymbol);
        Print("   Type: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
        Print("   Ticket: #", result.order);
        Print("   Price: ", price);
        Print("   SL: ", sl, " | TP: ", tp);
        Print("   Lot: ", TestLotSize);
        Print("   Strategy: ", TEST_STRATEGY);

        // Export trade to history immediately
        if(perfTracker != NULL)
        {
            perfTracker.ExportTradeHistory();
            Print("   ✓ Trade exported to history");
        }
    }
    else
    {
        Print("❌ TEST TRADE FAILED:");
        Print("   Symbol: ", tradingSymbol);
        Print("   Type: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
        Print("   Error: ", result.retcode, " - ", GetErrorDescription(result.retcode));
    }
}

//+------------------------------------------------------------------+
//| Check for positions to auto-close                                |
//+------------------------------------------------------------------+
void CheckAutoClose()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;

        // Only close our test positions
        if(PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER)
            continue;

        // Check how long position has been open
        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
        int minutesOpen = (int)((TimeCurrent() - openTime) / 60);

        if(minutesOpen >= AutoCloseMinutes)
        {
            ClosePosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Close a position                                                  |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
        return;

    string symbol = PositionGetString(POSITION_SYMBOL);
    double volume = PositionGetDouble(POSITION_VOLUME);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = volume;
    request.type = posType == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.position = ticket;
    request.price = posType == POSITION_TYPE_BUY ?
                    SymbolInfoDouble(symbol, SYMBOL_BID) :
                    SymbolInfoDouble(symbol, SYMBOL_ASK);
    request.deviation = 10;
    request.magic = MAGIC_NUMBER;
    request.type_filling = ORDER_FILLING_FOK;

    // Try ORDER_FILLING_IOC if FOK fails
    bool success = false;
    if(!OrderSend(request, result))
    {
        request.type_filling = ORDER_FILLING_IOC;
        if(!OrderSend(request, result))
        {
            request.type_filling = ORDER_FILLING_RETURN;
            success = OrderSend(request, result);
        }
    }

    if(result.retcode == TRADE_RETCODE_DONE)
    {
        Print("🧪 TEST POSITION AUTO-CLOSED:");
        Print("   Ticket: #", ticket);
        Print("   Symbol: ", symbol);
        Print("   Reason: ", AutoCloseMinutes, " minutes elapsed");

        // Export updated history
        if(perfTracker != NULL)
        {
            perfTracker.ExportTradeHistory();
            Print("   ✓ History updated");
        }
    }
}

//+------------------------------------------------------------------+
//| Count test positions                                              |
//+------------------------------------------------------------------+
int CountTestPositions(string symbol)
{
    int count = 0;

    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;

        if(PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER)
            continue;

        if(symbol != "" && PositionGetString(POSITION_SYMBOL) != symbol)
            continue;

        count++;
    }

    return count;
}

//+------------------------------------------------------------------+
//| Get error description                                             |
//+------------------------------------------------------------------+
string GetErrorDescription(uint errorCode)
{
    switch(errorCode)
    {
        case TRADE_RETCODE_DONE: return "Done";
        case TRADE_RETCODE_PLACED: return "Placed";
        case TRADE_RETCODE_REJECT: return "Rejected";
        case TRADE_RETCODE_CANCEL: return "Cancelled";
        case TRADE_RETCODE_NO_MONEY: return "No money";
        case TRADE_RETCODE_INVALID: return "Invalid request";
        case TRADE_RETCODE_INVALID_VOLUME: return "Invalid volume";
        case TRADE_RETCODE_INVALID_PRICE: return "Invalid price";
        case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops";
        case TRADE_RETCODE_TRADE_DISABLED: return "Trade disabled";
        case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
        default: return "Unknown error";
    }
}
//+------------------------------------------------------------------+
