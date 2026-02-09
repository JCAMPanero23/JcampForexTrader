//+------------------------------------------------------------------+
//|                                        Jcamp_CSM_AnalysisEA.mq5  |
//|                                   CSM Alpha - 9 Currency System  |
//|                                              With Gold (XAU)     |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      "https://github.com/JCAMPanero23/JcampForexTrader"
#property version   "2.00"
#property description "CSM Alpha: Currency Strength Meter with Gold as 9th currency"
#property description "Calculates competitive strength scoring (0-100) for 9 currencies"
#property description "Exports to csm_current.txt for Strategy_AnalysisEA consumption"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "═══ CSM Configuration ═══"
input ENUM_TIMEFRAMES AnalysisTimeframe = PERIOD_H1;  // CSM Calculation Timeframe
input int    CSM_LookbackHours = 48;                  // CSM Lookback Period (hours)
input int    UpdateIntervalMinutes = 60;              // CSM Update Interval (minutes)

input group "═══ Export Settings ═══"
input string ExportFolder = "CSM_Data";               // Export folder name
input bool   VerboseLogging = true;                  // Verbose logging

input group "═══ Broker Settings ═══"
input string BrokerSuffix = ".r";                       // Broker symbol suffix (e.g., ".r")

//+------------------------------------------------------------------+
//| CSM DATA STRUCTURES                                               |
//+------------------------------------------------------------------+
struct CurrencyStrengthData
{
    string   currency;
    double   current_strength;
    double   strength_24h_ago;
    double   strength_change_24h;
    bool     data_valid;
    datetime last_update;
};

struct PairData
{
    string symbol;
    double current_price;
    double price_24h_ago;
    double price_change_24h;
    bool   is_synthetic;        // True for synthetic Gold pairs
    bool   symbol_available;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
// ✅ 9 CURRENCIES (with XAU - Gold)
string currencies[9] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD", "NZD", "XAU"};
CurrencyStrengthData csm_data[9];

// ✅ 21 PAIRS (16 traditional + 5 Gold pairs)
string pair_list[21] = {
    // Traditional currency pairs (16)
    "EURUSD", "GBPUSD", "USDJPY", "USDCHF",
    "USDCAD", "AUDUSD", "NZDUSD", "EURGBP",
    "GBPNZD", "AUDNZD", "NZDCAD", "NZDJPY",
    "GBPJPY", "GBPCHF", "GBPCAD", "EURJPY",
    // Gold pairs (1 real + 4 synthetic)
    "XAUUSD",   // Real Gold pair (broker provides)
    "XAUEUR",   // Synthetic: XAUUSD / EURUSD
    "XAUJPY",   // Synthetic: XAUUSD * USDJPY
    "XAUGBP",   // Synthetic: XAUUSD / GBPUSD
    "XAUAUD"    // Synthetic: XAUUSD / AUDUSD
};

PairData pair_data[21];

// Timing
datetime last_csm_update = 0;
int update_interval_seconds;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("\n╔════════════════════════════════════════════════════════════╗");
    Print("║         Jcamp CSM Analysis EA - Initialization            ║");
    Print("║              CSM Alpha - 9 Currency System                ║");
    Print("╚════════════════════════════════════════════════════════════╝\n");

    // Convert minutes to seconds
    update_interval_seconds = UpdateIntervalMinutes * 60;

    // Initialize CSM data
    for(int i = 0; i < 9; i++)
    {
        csm_data[i].currency = currencies[i];
        csm_data[i].current_strength = 50.0;
        csm_data[i].strength_24h_ago = 50.0;
        csm_data[i].strength_change_24h = 0.0;
        csm_data[i].data_valid = false;
        csm_data[i].last_update = 0;
    }

    // Initialize pair data
    for(int i = 0; i < 21; i++)
    {
        string symbol_name = pair_list[i] + BrokerSuffix;

        // Check if synthetic pair
        bool is_gold_synthetic = (pair_list[i] == "XAUEUR" ||
                                  pair_list[i] == "XAUJPY" ||
                                  pair_list[i] == "XAUGBP" ||
                                  pair_list[i] == "XAUAUD");

        pair_data[i].symbol = symbol_name;
        pair_data[i].current_price = 0.0;
        pair_data[i].price_24h_ago = 0.0;
        pair_data[i].price_change_24h = 0.0;
        pair_data[i].is_synthetic = is_gold_synthetic;
        pair_data[i].symbol_available = false;

        // Check if real pair is available
        if(!is_gold_synthetic)
        {
            if(SymbolInfoInteger(symbol_name, SYMBOL_SELECT))
            {
                pair_data[i].symbol_available = true;
                Print("✅ ", symbol_name, " available");
            }
            else
            {
                Print("⚠️  ", symbol_name, " not available");
            }
        }
        else
        {
            // Synthetic pairs always marked as available
            // (we'll calculate them from real pairs)
            pair_data[i].symbol_available = true;
            Print("🔨 ", pair_list[i], " (synthetic - will be calculated)");
        }
    }

    // Create export directory
    string folderPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + ExportFolder;
    Print("\n📁 Export folder: ", folderPath);

    // Initial CSM calculation
    Print("\n🔄 Running initial CSM calculation...");
    UpdateFullCSM();

    if(csm_data[0].data_valid)
    {
        Print("✅ Initial CSM calculation successful");
        ExportCSM();
        last_csm_update = TimeCurrent();  // ✅ FIX: Set initial timestamp
        Print("🕐 Next update in ", UpdateIntervalMinutes, " minutes (", TimeToString(last_csm_update + update_interval_seconds, TIME_DATE|TIME_MINUTES), ")");
    }
    else
    {
        Print("⚠️  Initial CSM calculation returned no data");
        Print("⚠️  Please check:");
        Print("   - Chart is receiving price updates (ticks)");
        Print("   - Symbols are available with suffix: ", BrokerSuffix);
    }

    Print("\n⏰ CSM will update every ", UpdateIntervalMinutes, " minutes");
    Print("═══════════════════════════════════════════════════════════\n");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("\n╔════════════════════════════════════════════════════════════╗");
    Print("║          Jcamp CSM Analysis EA - Shutdown                 ║");
    Print("╚════════════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if it's time to update CSM
    datetime currentTime = TimeCurrent();
    static int tick_count = 0;
    tick_count++;

    // Log first few ticks for debugging
    if(tick_count <= 3)
        Print("🔔 Tick #", tick_count, " received at ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));

    if(currentTime - last_csm_update >= update_interval_seconds)
    {
        Print("\n⏰ [", TimeToString(currentTime, TIME_DATE|TIME_MINUTES), "] CSM Update Triggered");
        Print("   Last update: ", TimeToString(last_csm_update, TIME_DATE|TIME_MINUTES));
        Print("   Time elapsed: ", (int)((currentTime - last_csm_update) / 60), " minutes");

        UpdateFullCSM();

        if(csm_data[0].data_valid)
        {
            ExportCSM();
            last_csm_update = currentTime;
            Print("✅ CSM exported successfully");
            Print("🕐 Next update at: ", TimeToString(currentTime + update_interval_seconds, TIME_DATE|TIME_MINUTES));

            if(VerboseLogging)
                PrintCSMSummary();
        }
        else
        {
            Print("❌ CSM calculation failed - no valid data");
            Print("   Check if symbols are available and chart is receiving quotes");
        }
    }
}

//+------------------------------------------------------------------+
//| Update Full CSM (9-currency system with Gold)                    |
//+------------------------------------------------------------------+
void UpdateFullCSM()
{
    // Reset all strengths to neutral (50.0)
    for(int i = 0; i < 9; i++)
    {
        csm_data[i].current_strength = 50.0;
        csm_data[i].strength_change_24h = 0.0;
        csm_data[i].data_valid = false;
    }

    // Calculate lookback bars
    double hoursPerBar = (double)PeriodSeconds(AnalysisTimeframe) / 3600.0;
    int bars_24h = (int)MathCeil(24.0 / hoursPerBar);

    // ═══════════════════════════════════════════════════════════════
    // STEP 1: Get prices for REAL pairs (needed for synthetic calc)
    // ═══════════════════════════════════════════════════════════════
    double xauusd_current = 0, xauusd_24h = 0;
    double eurusd_current = 0, eurusd_24h = 0;
    double gbpusd_current = 0, gbpusd_24h = 0;
    double audusd_current = 0, audusd_24h = 0;
    double usdjpy_current = 0, usdjpy_24h = 0;

    // Get XAUUSD (needed for all synthetic Gold pairs)
    int xauusd_idx = GetPairIndex("XAUUSD");
    if(xauusd_idx >= 0 && pair_data[xauusd_idx].symbol_available)
    {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(pair_data[xauusd_idx].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);
        if(copied > bars_24h)
        {
            xauusd_current = close[0];
            xauusd_24h = close[bars_24h];
        }
    }

    // Get EURUSD (for XAUEUR)
    int eurusd_idx = GetPairIndex("EURUSD");
    if(eurusd_idx >= 0 && pair_data[eurusd_idx].symbol_available)
    {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(pair_data[eurusd_idx].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);
        if(copied > bars_24h)
        {
            eurusd_current = close[0];
            eurusd_24h = close[bars_24h];
        }
    }

    // Get GBPUSD (for XAUGBP)
    int gbpusd_idx = GetPairIndex("GBPUSD");
    if(gbpusd_idx >= 0 && pair_data[gbpusd_idx].symbol_available)
    {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(pair_data[gbpusd_idx].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);
        if(copied > bars_24h)
        {
            gbpusd_current = close[0];
            gbpusd_24h = close[bars_24h];
        }
    }

    // Get AUDUSD (for XAUAUD)
    int audusd_idx = GetPairIndex("AUDUSD");
    if(audusd_idx >= 0 && pair_data[audusd_idx].symbol_available)
    {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(pair_data[audusd_idx].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);
        if(copied > bars_24h)
        {
            audusd_current = close[0];
            audusd_24h = close[bars_24h];
        }
    }

    // Get USDJPY (for XAUJPY)
    int usdjpy_idx = GetPairIndex("USDJPY");
    if(usdjpy_idx >= 0 && pair_data[usdjpy_idx].symbol_available)
    {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(pair_data[usdjpy_idx].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);
        if(copied > bars_24h)
        {
            usdjpy_current = close[0];
            usdjpy_24h = close[bars_24h];
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 2: Process ALL pairs (real + synthetic)
    // ═══════════════════════════════════════════════════════════════
    for(int i = 0; i < 21; i++)
    {
        if(!pair_data[i].symbol_available)
            continue;

        // Handle SYNTHETIC Gold pairs
        if(pair_data[i].is_synthetic)
        {
            if(pair_list[i] == "XAUEUR" && eurusd_current > 0 && xauusd_current > 0)
            {
                // XAUEUR = XAUUSD / EURUSD
                pair_data[i].current_price = xauusd_current / eurusd_current;
                pair_data[i].price_24h_ago = xauusd_24h / eurusd_24h;
            }
            else if(pair_list[i] == "XAUJPY" && usdjpy_current > 0 && xauusd_current > 0)
            {
                // XAUJPY = XAUUSD * USDJPY
                pair_data[i].current_price = xauusd_current * usdjpy_current;
                pair_data[i].price_24h_ago = xauusd_24h * usdjpy_24h;
            }
            else if(pair_list[i] == "XAUGBP" && gbpusd_current > 0 && xauusd_current > 0)
            {
                // XAUGBP = XAUUSD / GBPUSD
                pair_data[i].current_price = xauusd_current / gbpusd_current;
                pair_data[i].price_24h_ago = xauusd_24h / gbpusd_24h;
            }
            else if(pair_list[i] == "XAUAUD" && audusd_current > 0 && xauusd_current > 0)
            {
                // XAUAUD = XAUUSD / AUDUSD
                pair_data[i].current_price = xauusd_current / audusd_current;
                pair_data[i].price_24h_ago = xauusd_24h / audusd_24h;
            }

            // Calculate price change for synthetic pair
            if(pair_data[i].price_24h_ago > 0)
            {
                pair_data[i].price_change_24h =
                    (pair_data[i].current_price - pair_data[i].price_24h_ago) /
                    pair_data[i].price_24h_ago;
            }
        }
        else
        {
            // Handle REAL pairs
            double close[];
            ArraySetAsSeries(close, true);

            int copied = CopyClose(pair_data[i].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);

            if(copied > bars_24h)
            {
                pair_data[i].current_price = close[0];
                pair_data[i].price_24h_ago = close[bars_24h];

                if(pair_data[i].price_24h_ago > 0)
                {
                    pair_data[i].price_change_24h =
                        (pair_data[i].current_price - pair_data[i].price_24h_ago) /
                        pair_data[i].price_24h_ago;
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Calculate currency strengths from pair movements
    // ═══════════════════════════════════════════════════════════════
    for(int i = 0; i < 21; i++)
    {
        if(!pair_data[i].symbol_available)
            continue;

        double price_change = pair_data[i].price_change_24h;

        if(price_change == 0.0 && pair_data[i].price_24h_ago == 0.0)
            continue;

        // Weight certain pairs more heavily
        double weight = 1.0;
        if(pair_list[i] == "XAUUSD" || pair_list[i] == "EURUSD" || pair_list[i] == "GBPUSD")
            weight = 1.5;

        // Extract base and quote currencies
        string base_currency = StringSubstr(pair_list[i], 0, 3);
        string quote_currency = StringSubstr(pair_list[i], 3, 3);

        int base_idx = GetCurrencyIndex(base_currency);
        int quote_idx = GetCurrencyIndex(quote_currency);

        if(base_idx >= 0 && quote_idx >= 0)
        {
            // Multiply by 100 to make values larger for normalization
            double strength_change = price_change * 100.0 * 2.0 * weight;

            csm_data[base_idx].current_strength += strength_change;
            csm_data[base_idx].strength_change_24h += strength_change;

            csm_data[quote_idx].current_strength -= strength_change;
            csm_data[quote_idx].strength_change_24h -= strength_change;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 4: Normalize to 0-100 scale
    // ═══════════════════════════════════════════════════════════════
    NormalizeStrengthValues();

    // Mark all as valid
    datetime currentTime = TimeCurrent();
    for(int i = 0; i < 9; i++)
    {
        csm_data[i].data_valid = true;
        csm_data[i].last_update = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Normalize Strength Values to 0-100                               |
//+------------------------------------------------------------------+
void NormalizeStrengthValues()
{
    double min_strength = csm_data[0].current_strength;
    double max_strength = csm_data[0].current_strength;

    // Find min and max
    for(int i = 1; i < 9; i++)
    {
        if(csm_data[i].current_strength < min_strength)
            min_strength = csm_data[i].current_strength;
        if(csm_data[i].current_strength > max_strength)
            max_strength = csm_data[i].current_strength;
    }

    double range = max_strength - min_strength;

    if(range > 0.001)
    {
        // Normalize each currency to 0-100 scale
        for(int i = 0; i < 9; i++)
        {
            csm_data[i].current_strength =
                ((csm_data[i].current_strength - min_strength) / range) * 100.0;

            if(range > 0)
            {
                csm_data[i].strength_change_24h =
                    (csm_data[i].strength_change_24h / range) * 100.0;
            }
        }
    }
    else
    {
        // No range - set all to neutral (50.0)
        for(int i = 0; i < 9; i++)
        {
            csm_data[i].current_strength = 50.0;
        }
    }
}

//+------------------------------------------------------------------+
//| Get Currency Index                                                |
//+------------------------------------------------------------------+
int GetCurrencyIndex(string currency)
{
    for(int i = 0; i < 9; i++)
    {
        if(currencies[i] == currency)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Get Pair Index                                                    |
//+------------------------------------------------------------------+
int GetPairIndex(string pair)
{
    for(int i = 0; i < 21; i++)
    {
        if(pair_list[i] == pair)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Export CSM to File                                                |
//+------------------------------------------------------------------+
void ExportCSM()
{
    string filename = ExportFolder + "\\csm_current.txt";
    int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);

    if(handle == INVALID_HANDLE)
    {
        Print("❌ ERROR: Failed to open file for writing: ", filename);
        return;
    }

    // Write header
    FileWriteString(handle, "# CSM Alpha - 9 Currency Strength Meter\n");
    FileWriteString(handle, "# Updated: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n");
    FileWriteString(handle, "# Format: CURRENCY,STRENGTH\n\n");

    // Write currency strengths
    for(int i = 0; i < 9; i++)
    {
        if(csm_data[i].data_valid)
        {
            FileWriteString(handle, csm_data[i].currency + "," +
                          DoubleToString(csm_data[i].current_strength, 2) + "\n");
        }
    }

    FileClose(handle);

    if(VerboseLogging)
        Print("✅ CSM exported to: ", filename);
}

//+------------------------------------------------------------------+
//| Print CSM Summary                                                 |
//+------------------------------------------------------------------+
void PrintCSMSummary()
{
    Print("\n╔════════════════════════════════════════════╗");
    Print("║      CSM Alpha - Currency Strengths        ║");
    Print("╠════════════════════════════════════════════╣");

    for(int i = 0; i < 9; i++)
    {
        if(csm_data[i].data_valid)
        {
            string bar = "";
            int strength_bars = (int)(csm_data[i].current_strength / 5.0);
            for(int j = 0; j < strength_bars; j++)
                bar += "█";

            Print("║ ", csm_data[i].currency, ": ",
                  StringFormat("%5.1f", csm_data[i].current_strength),
                  " ", bar);
        }
    }

    Print("╚════════════════════════════════════════════╝\n");
}
//+------------------------------------------------------------------+
