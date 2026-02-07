📋 The "GV Upgrade" Guide for Claude
Save this content as Documentation/CODE_UPDATE_GUIDE_TICKS.md or copy/paste it directly to Claude.

Request: Upgrade Jcamp Architecture to Global Variables (Tick Speed)
Context: We are integrating Tick Charts (Custom Symbols) into the Jcamp ecosystem. The current JSON-based signal system is too slow for tick-based scalping. We need to switch the execution trigger to MT5 Global Variables (GVs) while keeping the JSONs for the dashboard logging.

Goal: Modify Jcamp_Strategy_AnalysisEA to WRITE Global Variables and Jcamp_MainTradingEA to READ them.

Part 1: Modify Jcamp_Strategy_AnalysisEA.mq5 (The Writer)
Task: Update the ProcessStrategy or ExportSignals function to write a simple integer status to a Global Variable immediately after a signal is confirmed.

Requirements:

GV Naming Convention: JCAMP_SIG_{SYMBOL} (e.g., JCAMP_SIG_XAUUSD).

GV Values:

1 = BUY

-1 = SELL

0 = NEUTRAL / FLAT

999 = CLOSE_ALL (Panic/Exit signal)

Timestamp GV: Also write JCAMP_TIME_{SYMBOL} with the current server time (TimeCurrent()) so the receiver knows if the signal is stale.

Code Snippet Implementation:

C++
// Add this helper function to Strategy_AnalysisEA
void UpdateGlobalVariableSignal(string symbol, int signalType) {
    string gvName = "JCAMP_SIG_" + symbol;
    string gvTime = "JCAMP_TIME_" + symbol;
    
    // 1=Buy, -1=Sell, 0=Neutral
    if(GlobalVariableSet(gvName, signalType) > 0) {
        GlobalVariableSet(gvTime, (double)TimeCurrent());
        if(VerboseLogging) Print("GV Updated: ", gvName, " = ", signalType);
    } else {
        Print("Error writing Global Variable: ", GetLastError());
    }
}

// CALL THIS function right after you write the JSON file
// Example inside OnTick():
// if (newSignal) {
//    ExportSignalToJson(...);         <-- Keep this for Dashboard
//    UpdateGlobalVariableSignal(...); <-- Add this for MainTradingEA
// }
Part 2: Modify Jcamp_MainTradingEA.mq5 (The Reader)
Task: Update the OnTick loop to check Global Variables instead of reading JSON files.

Requirements:

Polling Frequency: Check GVs on every tick. It is lightweight.

Stale Data Protection: Check JCAMP_TIME_{SYMBOL}. If the time difference (TimeCurrent() - gvTime) is > 10 seconds, ignore the signal (it's old).

Execution Logic:

If GV = 1 and we have NO Buy position -> Open BUY.

If GV = -1 and we have NO Sell position -> Open SELL.

If GV = 0 -> Do nothing (or manage trailing stops).

Code Snippet Implementation:

C++
// Replace the old "ReadSignalFile" logic with this:
void CheckGlobalVariableSignals() {
    string symbols[] = {"EURUSD", "GBPUSD", "AUDJPY", "XAUUSD"};
    
    for(int i=0; i<ArraySize(symbols); i++) {
        string sym = symbols[i];
        string gvName = "JCAMP_SIG_" + sym;
        string gvTime = "JCAMP_TIME_" + sym;
        
        if(!GlobalVariableCheck(gvName)) continue; // No signal yet
        
        double signalVal = GlobalVariableGet(gvName);
        double signalTime = GlobalVariableGet(gvTime);
        
        // 1. Safety Check: Is signal stale? (> 30 seconds old)
        if(TimeCurrent() - (datetime)signalTime > 30) {
            if(VerboseLogging) Print("Signal Stale for ", sym);
            continue; 
        }
        
        // 2. Execute
        if(signalVal == 1.0) {
            TradeExecutor.ExecuteBuy(sym, ...);
            // Optional: Reset GV to 0 immediately to prevent double-entry
            // GlobalVariableSet(gvName, 0); 
        }
        else if(signalVal == -1.0) {
            TradeExecutor.ExecuteSell(sym, ...);
        }
    }
}
Part 3: Verification Checklist
After the AI writes the code, verify these 3 points manually:

Global Variable Window: Open MT5 -> Tools -> Global Variables (F3). Do you see JCAMP_SIG_XAUUSD appearing when the Strategy EA runs?

Latency: The MainTradingEA should execute the trade instantly when the GV changes value.

Symbol Suffixes: Ensure the UpdateGlobalVariableSignal function handles broker suffixes (e.g., if the chart is XAUUSD.sml, the GV should still ideally be standardized to JCAMP_SIG_XAUUSD or match the chart name exactly—prefer matching the chart name to avoid confusion).

🚀 Execution Plan
Step 1: Give Part 1 prompt to Claude. Compile Strategy_AnalysisEA.

Step 2: Give Part 2 prompt to Claude. Compile MainTradingEA.

Step 3: Open a Demo XAUUSD_Tick233 chart (using your new Service) and attach the Strategy EA.

Step 4: Watch the "Global Variables" window (F3) in MT5. As soon as you see a 1 or -1 pop up, your MainTradingEA should fire a trade instantly.