//+------------------------------------------------------------------+
//|                                           SignalExporter.mqh      |
//|                                            JcampForexTrader       |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

#include "Strategies/IStrategy.mqh"

//+------------------------------------------------------------------+
//| Signal Export Data Structure                                     |
//+------------------------------------------------------------------+
struct SignalExportData
{
   string   symbol;
   datetime timestamp;
   string   strategyName;
   int      signal;          // -1 = SELL, 0 = NEUTRAL, 1 = BUY
   int      confidence;
   string   analysis;        // Breakdown of scoring
   double   csmDiff;         // CSM difference used
   string   regime;          // TRENDING/RANGING/TRANSITIONAL
   double   stopLossDollars;    // ATR-based stop loss (0 = use default) 
   double   takeProfitDollars;  // ATR-based take profit (0 = use default) 
};

//+------------------------------------------------------------------+
//| Signal Exporter Class                                             |
//| Exports strategy signals to JSON files for MainTradingEA         |
//+------------------------------------------------------------------+
class SignalExporter
{
private:
   string exportFolder;
   bool verboseLogging;

public:
   SignalExporter(string folder = "CSM_Signals", bool verbose = false)
   {
      exportFolder = folder;
      verboseLogging = verbose;

      // Create export folder if it doesn't exist
      CreateExportFolder();
   }

   ~SignalExporter() {}

   //+------------------------------------------------------------------+
   //| Export Signal to JSON File                                       |
   //| Creates {SYMBOL}_signals.json (e.g., EURUSD_signals.json)       |
   //+------------------------------------------------------------------+
   bool ExportSignal(const SignalExportData &data)
   {
      string filename = exportFolder + "\\" + data.symbol + "_signals.json";

      // Build JSON content
      string json = BuildJSON(data);

      // Write to file
      int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to open file for writing: ", filename);
         Print("Error code: ", GetLastError());
         return false;
      }

      FileWriteString(handle, json);
      FileClose(handle);

      if(verboseLogging)
         Print("Signal exported to: ", filename);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Export Signal from Strategy Result                               |
   //+------------------------------------------------------------------+
   bool ExportSignalFromStrategy(string symbol,
                                  const StrategySignal &signal,
                                  double csmDiff,
                                  string regime)
   {
      SignalExportData data;
      data.symbol = symbol;
      data.timestamp = TimeCurrent();
      data.strategyName = signal.strategyName;
      data.signal = signal.signal;
      data.confidence = signal.confidence;
      data.analysis = signal.analysis;
      data.csmDiff = csmDiff;
      data.regime = regime;
      data.stopLossDollars = 0;  
      data.takeProfitDollars = 0;  
      
      return ExportSignal(data);
   }

   //+------------------------------------------------------------------+
   //| Clear Signal File (no valid signal)                              |
   //+------------------------------------------------------------------+
   bool ClearSignal(string symbol)
   {
      SignalExportData data;
      data.symbol = symbol;
      data.timestamp = TimeCurrent();
      data.strategyName = "NONE";
      data.signal = 0;
      data.confidence = 0;
      data.analysis = "No valid signal";
      data.csmDiff = 0;
      data.regime = "UNKNOWN";

      return ExportSignal(data);
   }

private:
   //+------------------------------------------------------------------+
   //| Create Export Folder                                             |
   //+------------------------------------------------------------------+
   void CreateExportFolder()
   {
      // MT5 Files folder is: Terminal_Data_Folder/MQL5/Files/
      // No need to create, MT5 handles it
      // Just ensure folder path is valid
      if(StringLen(exportFolder) == 0)
         exportFolder = "CSM_Signals";
   }

   //+------------------------------------------------------------------+
   //| Build JSON String                                                |
   //+------------------------------------------------------------------+
   string BuildJSON(const SignalExportData &data)
   {
      string json = "{\n";
      json += "  \"symbol\": \"" + data.symbol + "\",\n";
      json += "  \"timestamp\": \"" + TimeToString(data.timestamp, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\",\n";
      json += "  \"unix_time\": " + IntegerToString((long)data.timestamp) + ",\n";
      json += "  \"strategy\": \"" + data.strategyName + "\",\n";
      json += "  \"signal\": " + IntegerToString(data.signal) + ",\n";
      json += "  \"signal_text\": \"" + SignalToText(data.signal) + "\",\n";
      json += "  \"confidence\": " + IntegerToString(data.confidence) + ",\n";
      json += "  \"analysis\": \"" + data.analysis + "\",\n";
      json += "  \"csm_diff\": " + DoubleToString(data.csmDiff, 2) + ",\n";
      json += "  \"regime\": \"" + data.regime + "\",\n";

      // Prevent NaN values in JSON (invalid JSON format)
      double slDollars = (data.stopLossDollars != data.stopLossDollars) ? 0.0 : data.stopLossDollars; // NaN check: NaN != NaN
      double tpDollars = (data.takeProfitDollars != data.takeProfitDollars) ? 0.0 : data.takeProfitDollars; // NaN check: NaN != NaN

      json += "  \"stop_loss_dollars\": " + DoubleToString(slDollars, 2) + ",\n";
      json += "  \"take_profit_dollars\": " + DoubleToString(tpDollars, 2) + ",\n";
      json += "  \"exported_at\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\"\n";
      json += "}";

      return json;
   }

   //+------------------------------------------------------------------+
   //| Convert Signal to Text                                           |
   //+------------------------------------------------------------------+
   string SignalToText(int signal)
   {
      if(signal > 0) return "BUY";
      else if(signal < 0) return "SELL";
      else return "NEUTRAL";
   }
};
//+------------------------------------------------------------------+
