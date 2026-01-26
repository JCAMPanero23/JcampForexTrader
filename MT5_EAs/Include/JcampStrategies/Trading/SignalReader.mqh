//+------------------------------------------------------------------+
//|                                           SignalReader.mqh        |
//|                                            JcampForexTrader       |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Signal Data Structure                                             |
//| Parsed from signal JSON files created by Strategy_AnalysisEA     |
//+------------------------------------------------------------------+
struct SignalData
{
   string   symbol;
   datetime timestamp;
   long     unixTime;
   string   strategy;        // "TREND_RIDER", "RANGE_RIDER", "NONE"
   int      signal;          // -1 = SELL, 0 = NEUTRAL, 1 = BUY
   string   signalText;      // "BUY", "SELL", "NEUTRAL"
   int      confidence;      // 0-135 for TREND_RIDER, 0-100 for RANGE_RIDER
   string   analysis;        // Breakdown text
   double   csmDiff;         // CSM difference
   string   regime;          // "TRENDING", "RANGING", "TRANSITIONAL"
   datetime exportedAt;
   bool     isValid;         // True if signal was successfully read
   double   stopLossDollars;     
   double   takeProfitDollars;   
};

//+------------------------------------------------------------------+
//| Signal Reader Class                                               |
//| Reads and parses JSON signal files from Strategy_AnalysisEA      |
//+------------------------------------------------------------------+
class SignalReader
{
private:
   string signalFolder;
   bool verboseLogging;

   // Cache last read signals to avoid re-reading unchanged files
   SignalData lastSignals[];

public:
   SignalReader(string folder = "CSM_Signals", bool verbose = false)
   {
      signalFolder = folder;
      verboseLogging = verbose;
      ArrayResize(lastSignals, 0);
   }

   ~SignalReader() {}

   //+------------------------------------------------------------------+
   //| Read Signal File for a Symbol                                    |
   //| Returns SignalData with isValid=true if successful               |
   //+------------------------------------------------------------------+
   SignalData ReadSignal(string symbol)
   {
      SignalData data;
      data.isValid = false;
      data.symbol = symbol;

      string filename = signalFolder + "\\" + symbol + "_signals.json";

      // Open file
      int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         if(verboseLogging)
            Print("WARNING: Signal file not found: ", filename);
         return data;
      }

      // Read entire file content
      string jsonContent = "";
      while(!FileIsEnding(handle))
      {
         jsonContent += FileReadString(handle);
      }
      FileClose(handle);

      // Parse JSON
      if(!ParseJSON(jsonContent, data))
      {
         Print("ERROR: Failed to parse signal JSON for ", symbol);
         return data;
      }

      data.isValid = true;

      if(verboseLogging)
      {
         Print("📊 Signal Read: ", symbol, " | ", data.signalText,
               " | Confidence: ", data.confidence, " | Strategy: ", data.strategy);
      }

      return data;
   }

   //+------------------------------------------------------------------+
   //| Read Signals for Multiple Symbols                                |
   //| Returns array of SignalData                                      |
   //+------------------------------------------------------------------+
   int ReadMultipleSignals(string symbolList, SignalData &signals[])
   {
      // Parse symbol list (comma-separated: "EURUSD,GBPUSD,GBPNZD")
      string symbols[];
      int count = ParseSymbolList(symbolList, symbols);

      ArrayResize(signals, count);

      int validCount = 0;
      for(int i = 0; i < count; i++)
      {
         signals[i] = ReadSignal(symbols[i]);
         if(signals[i].isValid)
            validCount++;
      }

      return validCount;
   }

   //+------------------------------------------------------------------+
   //| Check if Signal is Fresh (within max age)                        |
   //+------------------------------------------------------------------+
   bool IsSignalFresh(const SignalData &signal, int maxAgeMinutes = 30)
   {
      if(!signal.isValid)
         return false;

      datetime currentTime = TimeCurrent();
      int ageMinutes = (int)((currentTime - signal.timestamp) / 60);

      return ageMinutes <= maxAgeMinutes;
   }

   //+------------------------------------------------------------------+
   //| Check if Signal is Tradeable                                     |
   //| (Valid, fresh, non-neutral, meets confidence threshold)          |
   //+------------------------------------------------------------------+
   bool IsSignalTradeable(const SignalData &signal,
                          int minConfidence = 70,
                          int maxAgeMinutes = 30)
   {
      if(!signal.isValid)
         return false;

      if(!IsSignalFresh(signal, maxAgeMinutes))
         return false;

      if(signal.signal == 0) // NEUTRAL
         return false;

      if(signal.confidence < minConfidence)
         return false;

      return true;
   }

private:
   //+------------------------------------------------------------------+
   //| Parse Symbol List (Comma-separated)                              |
   //+------------------------------------------------------------------+
   int ParseSymbolList(string symbolList, string &symbols[])
   {
      ArrayResize(symbols, 0);

      string remaining = symbolList;
      StringTrimRight(remaining);
      StringTrimLeft(remaining);

      while(StringLen(remaining) > 0)
      {
         int commaPos = StringFind(remaining, ",");
         string symbol = "";

         if(commaPos >= 0)
         {
            symbol = StringSubstr(remaining, 0, commaPos);
            remaining = StringSubstr(remaining, commaPos + 1);
         }
         else
         {
            symbol = remaining;
            remaining = "";
         }

         StringTrimRight(symbol);
         StringTrimLeft(symbol);

         if(StringLen(symbol) > 0)
         {
            int size = ArraySize(symbols);
            ArrayResize(symbols, size + 1);
            symbols[size] = symbol;
         }
      }

      return ArraySize(symbols);
   }

   //+------------------------------------------------------------------+
   //| Parse JSON String to SignalData                                  |
   //| Simple JSON parser for our known format                          |
   //+------------------------------------------------------------------+
   bool ParseJSON(string json, SignalData &data)
   {
      // Extract values using simple string parsing
      // Format: "key": "value" or "key": number

      data.symbol = ExtractStringValue(json, "symbol");
      data.timestamp = StringToTime(ExtractStringValue(json, "timestamp"));
      data.unixTime = (long)ExtractIntValue(json, "unix_time");
      data.strategy = ExtractStringValue(json, "strategy");
      data.signal = ExtractIntValue(json, "signal");
      data.signalText = ExtractStringValue(json, "signal_text");
      data.confidence = ExtractIntValue(json, "confidence");
      data.analysis = ExtractStringValue(json, "analysis");
      data.csmDiff = ExtractDoubleValue(json, "csm_diff");
      data.regime = ExtractStringValue(json, "regime");
      data.exportedAt = StringToTime(ExtractStringValue(json, "exported_at"));
      data.stopLossDollars = ExtractDoubleValue(json, "stop_loss_dollars");     
      data.takeProfitDollars = ExtractDoubleValue(json, "take_profit_dollars");  
      // Validate required fields
      if(StringLen(data.symbol) == 0 || StringLen(data.signalText) == 0)
         return false;

      return true;
   }

   //+------------------------------------------------------------------+
   //| Extract String Value from JSON                                   |
   //+------------------------------------------------------------------+
   string ExtractStringValue(string json, string key)
   {
      string searchPattern = "\"" + key + "\": \"";
      int startPos = StringFind(json, searchPattern);

      if(startPos < 0)
         return "";

      startPos += StringLen(searchPattern);
      int endPos = StringFind(json, "\"", startPos);

      if(endPos < 0)
         return "";

      return StringSubstr(json, startPos, endPos - startPos);
   }

   //+------------------------------------------------------------------+
   //| Extract Integer Value from JSON                                  |
   //+------------------------------------------------------------------+
   int ExtractIntValue(string json, string key)
   {
      string searchPattern = "\"" + key + "\": ";
      int startPos = StringFind(json, searchPattern);

      if(startPos < 0)
         return 0;

      startPos += StringLen(searchPattern);

      // Find end (comma, newline, or closing brace)
      string remaining = StringSubstr(json, startPos);
      int endPos = StringFind(remaining, ",");
      if(endPos < 0) endPos = StringFind(remaining, "\n");
      if(endPos < 0) endPos = StringFind(remaining, "}");
      if(endPos < 0) endPos = StringLen(remaining);

      string valueStr = StringSubstr(remaining, 0, endPos);
      StringTrimRight(valueStr);
      StringTrimLeft(valueStr);

      return (int)StringToInteger(valueStr);
   }

   //+------------------------------------------------------------------+
   //| Extract Double Value from JSON                                   |
   //+------------------------------------------------------------------+
   double ExtractDoubleValue(string json, string key)
   {
      string searchPattern = "\"" + key + "\": ";
      int startPos = StringFind(json, searchPattern);

      if(startPos < 0)
         return 0.0;

      startPos += StringLen(searchPattern);

      // Find end (comma, newline, or closing brace)
      string remaining = StringSubstr(json, startPos);
      int endPos = StringFind(remaining, ",");
      if(endPos < 0) endPos = StringFind(remaining, "\n");
      if(endPos < 0) endPos = StringFind(remaining, "}");
      if(endPos < 0) endPos = StringLen(remaining);

      string valueStr = StringSubstr(remaining, 0, endPos);
      StringTrimRight(valueStr);
      StringTrimLeft(valueStr);

      return StringToDouble(valueStr);
   }
};
//+------------------------------------------------------------------+
