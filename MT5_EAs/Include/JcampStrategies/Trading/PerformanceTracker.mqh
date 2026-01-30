//+------------------------------------------------------------------+
//|                                      PerformanceTracker.mqh       |
//|                                            JcampForexTrader       |
//|                                                                   |
//| ✅ FIX (Jan 30, 2026): Persistent Trade History                  |
//| - JSON Import: Loads existing trades on startup                  |
//| - Merge Strategy: Adds new MT5 trades to JSON (no overwrites)    |
//| - Backup System: Creates backup before each export               |
//| - Source of Truth: trade_history.json (not volatile MT5)         |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| Trade Record Structure                                            |
//+------------------------------------------------------------------+
struct TradeRecord
{
   ulong    ticket;
   string   symbol;
   string   type;           // "BUY" or "SELL"
   datetime openTime;
   datetime closeTime;
   double   openPrice;
   double   closePrice;
   double   lots;
   double   profit;
   double   pips;
   string   strategy;       // From comment
   int      confidence;     // From comment
   string   comment;
};

//+------------------------------------------------------------------+
//| Performance Tracker Class                                         |
//| Tracks trading performance and exports data files                |
//+------------------------------------------------------------------+
class PerformanceTracker
{
private:
   string   exportFolder;
   int      magic;
   bool     verboseLogging;

   TradeRecord closedTrades[];
   datetime lastHistoryCheck;
   int      lastHistoryTotal;

public:
   PerformanceTracker(string folder = "CSM_Data", int magicNum = 100001, bool verbose = false)
   {
      exportFolder = folder;
      magic = magicNum;
      verboseLogging = verbose;

      ArrayResize(closedTrades, 0);
      lastHistoryCheck = 0;
      lastHistoryTotal = 0;

      // ✅ FIX: Load existing trade history (JSON import + MT5 scan)
      LoadTradeHistory();
   }

   ~PerformanceTracker() {}

   //+------------------------------------------------------------------+
   //| Update Performance (check for new closed trades)                 |
   //| Call this periodically (e.g., every 60 seconds)                  |
   //+------------------------------------------------------------------+
   void Update()
   {
      CheckForNewClosedTrades();
   }

   //+------------------------------------------------------------------+
   //| Export All Performance Data                                       |
   //| Call this periodically or on EA shutdown                          |
   //+------------------------------------------------------------------+
   void ExportAll()
   {
      ExportTradeHistory();
      ExportOpenPositions();
      ExportPerformanceStats();
   }

   //+------------------------------------------------------------------+
   //| Export Trade History to JSON                                     |
   //| ✅ FIX: Creates backup before overwriting                        |
   //+------------------------------------------------------------------+
   bool ExportTradeHistory()
   {
      string filename = exportFolder + "\\trade_history.json";

      // ✅ Create backup before overwriting (safety net)
      CreateBackup();

      // Build JSON
      string json = "{\n";
      json += "  \"exported_at\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\",\n";
      json += "  \"total_trades\": " + IntegerToString(ArraySize(closedTrades)) + ",\n";
      json += "  \"trades\": [\n";

      for(int i = 0; i < ArraySize(closedTrades); i++)
      {
         json += "    {\n";
         json += "      \"ticket\": " + IntegerToString((int)closedTrades[i].ticket) + ",\n";
         json += "      \"symbol\": \"" + closedTrades[i].symbol + "\",\n";
         json += "      \"type\": \"" + closedTrades[i].type + "\",\n";
         json += "      \"open_time\": \"" + TimeToString(closedTrades[i].openTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\",\n";
         json += "      \"close_time\": \"" + TimeToString(closedTrades[i].closeTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\",\n";
         json += "      \"open_price\": " + DoubleToString(closedTrades[i].openPrice, 5) + ",\n";
         json += "      \"close_price\": " + DoubleToString(closedTrades[i].closePrice, 5) + ",\n";
         json += "      \"lots\": " + DoubleToString(closedTrades[i].lots, 2) + ",\n";
         json += "      \"profit\": " + DoubleToString(closedTrades[i].profit, 2) + ",\n";
         json += "      \"pips\": " + DoubleToString(closedTrades[i].pips, 1) + ",\n";
         json += "      \"strategy\": \"" + closedTrades[i].strategy + "\",\n";
         json += "      \"confidence\": " + IntegerToString(closedTrades[i].confidence) + ",\n";
         json += "      \"comment\": \"" + closedTrades[i].comment + "\"\n";

         if(i < ArraySize(closedTrades) - 1)
            json += "    },\n";
         else
            json += "    }\n";
      }

      json += "  ]\n";
      json += "}";

      // Write to file
      int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to write trade_history.json");
         return false;
      }

      FileWriteString(handle, json);
      FileClose(handle);

      if(verboseLogging)
         Print("📊 Trade history exported: ", ArraySize(closedTrades), " trades");

      return true;
   }

   //+------------------------------------------------------------------+
   //| Export Open Positions to TXT                                     |
   //+------------------------------------------------------------------+
   bool ExportOpenPositions()
   {
      string filename = exportFolder + "\\positions.txt";

      string content = "OPEN POSITIONS\n";
      content += "==============\n";
      content += "Exported: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\n\n";

      int positionCount = 0;
      int totalPositions = PositionsTotal();

      for(int i = 0; i < totalPositions; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;

         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         string symbol = PositionGetString(POSITION_SYMBOL);
         string comment = PositionGetString(POSITION_COMMENT);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double lots = PositionGetDouble(POSITION_VOLUME);
         double profit = PositionGetDouble(POSITION_PROFIT);
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

         string typeStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";

         // Extract strategy from comment (format: "JcampCSM|TREND_RIDER|C88")
         string strategy = "UNKNOWN";
         if(StringFind(comment, "|") >= 0)
         {
            string parts[];
            int count = StringSplit(comment, '|', parts);
            if(count >= 2)
               strategy = parts[1];
         }

         content += "Ticket: " + IntegerToString((int)ticket) +
                    " | " + symbol + " " + typeStr +
                    " | Strategy: " + strategy +
                    " | Lots: " + DoubleToString(lots, 2) +
                    " | Entry: " + DoubleToString(openPrice, 5) +
                    " | Current: " + DoubleToString(currentPrice, 5) +
                    " | SL: " + DoubleToString(sl, 5) +
                    " | TP: " + DoubleToString(tp, 5) +
                    " | P&L: $" + DoubleToString(profit, 2) +
                    " | Time: " + TimeToString(openTime, TIME_DATE|TIME_MINUTES) + "\n";

         positionCount++;
      }

      if(positionCount == 0)
         content += "No open positions\n";

      // Write to file
      int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to write positions.txt");
         return false;
      }

      FileWriteString(handle, content);
      FileClose(handle);

      if(verboseLogging)
         Print("📊 Positions exported: ", positionCount, " open positions");

      return true;
   }

   //+------------------------------------------------------------------+
   //| Export Performance Statistics to TXT                             |
   //+------------------------------------------------------------------+
   bool ExportPerformanceStats()
   {
      string filename = exportFolder + "\\performance.txt";

      // Calculate statistics
      int totalTrades = ArraySize(closedTrades);
      int winners = 0;
      int losers = 0;
      double totalProfit = 0;
      double totalLoss = 0;
      double maxDrawdown = 0;
      double currentDrawdown = 0;
      double peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);

      for(int i = 0; i < totalTrades; i++)
      {
         if(closedTrades[i].profit > 0)
         {
            winners++;
            totalProfit += closedTrades[i].profit;
         }
         else
         {
            losers++;
            totalLoss += MathAbs(closedTrades[i].profit);
         }
      }

      double winRate = (totalTrades > 0) ? (winners * 100.0 / totalTrades) : 0;
      double profitFactor = (totalLoss > 0) ? (totalProfit / totalLoss) : 0;

      // Build content
      string content = "PERFORMANCE SUMMARY\n";
      content += "===================\n";
      content += "Exported: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\n\n";

      content += "Total Trades: " + IntegerToString(totalTrades) + "\n";
      content += "Winners: " + IntegerToString(winners) + " (" + DoubleToString(winRate, 1) + "%)\n";
      content += "Losers: " + IntegerToString(losers) + " (" + DoubleToString(100 - winRate, 1) + "%)\n";
      content += "Profit Factor: " + DoubleToString(profitFactor, 2) + "\n";
      content += "Total Profit: $" + DoubleToString(totalProfit - totalLoss, 2) + "\n\n";

      content += "Current Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
      content += "Current Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
      content += "Free Margin: $" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) + "\n";

      // Write to file
      int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to write performance.txt");
         return false;
      }

      FileWriteString(handle, content);
      FileClose(handle);

      if(verboseLogging)
         Print("📊 Performance stats exported");

      return true;
   }

private:
   //+------------------------------------------------------------------+
   //| Create Backup of Trade History JSON                              |
   //+------------------------------------------------------------------+
   void CreateBackup()
   {
      string sourceFile = exportFolder + "\\trade_history.json";
      string backupFile = exportFolder + "\\trade_history_backup.json";

      // Check if source exists
      if(!FileIsExist(sourceFile))
         return;

      // Read source
      int sourceHandle = FileOpen(sourceFile, FILE_READ|FILE_TXT|FILE_ANSI);
      if(sourceHandle == INVALID_HANDLE)
         return;

      string content = "";
      while(!FileIsEnding(sourceHandle))
      {
         content += FileReadString(sourceHandle);
      }
      FileClose(sourceHandle);

      // Write backup
      int backupHandle = FileOpen(backupFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(backupHandle == INVALID_HANDLE)
         return;

      FileWriteString(backupHandle, content);
      FileClose(backupHandle);

      if(verboseLogging)
         Print("💾 Backup created: trade_history_backup.json");
   }

   //+------------------------------------------------------------------+
   //| Load Trade History from JSON (Persistent Storage)                |
   //| Returns number of trades loaded from JSON file                   |
   //+------------------------------------------------------------------+
   int LoadTradeHistoryFromJSON()
   {
      string filename = exportFolder + "\\trade_history.json";

      // Check if file exists
      if(!FileIsExist(filename))
      {
         Print("ℹ️ No existing trade history JSON found (first run)");
         return 0;
      }

      // Open file
      int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         Print("❌ Failed to open trade_history.json for reading");
         return 0;
      }

      // Read entire file
      string jsonContent = "";
      while(!FileIsEnding(handle))
      {
         jsonContent += FileReadString(handle);
      }
      FileClose(handle);

      if(StringLen(jsonContent) == 0)
      {
         Print("⚠️ trade_history.json is empty");
         return 0;
      }

      // Parse JSON manually (MQL5 doesn't have native JSON parser)
      int tradesLoaded = ParseTradeHistoryJSON(jsonContent);

      if(tradesLoaded > 0)
         Print("✅ Loaded ", tradesLoaded, " trades from persistent JSON storage");
      else
         Print("⚠️ No trades found in JSON (may be corrupted)");

      return tradesLoaded;
   }

   //+------------------------------------------------------------------+
   //| Parse Trade History JSON Content                                 |
   //| Simple JSON parser for our specific format                       |
   //+------------------------------------------------------------------+
   int ParseTradeHistoryJSON(string json)
   {
      int tradesCount = 0;
      int pos = 0;

      // Find "trades": [ array
      int tradesArrayStart = StringFind(json, "\"trades\":");
      if(tradesArrayStart < 0)
         return 0;

      pos = tradesArrayStart;

      // Find each trade object { }
      while(true)
      {
         // Find next opening brace after current position
         int tradeStart = StringFind(json, "{", pos + 1);
         if(tradeStart < 0)
            break;

         // Find matching closing brace
         int tradeEnd = StringFind(json, "}", tradeStart);
         if(tradeEnd < 0)
            break;

         // Extract trade object
         string tradeJson = StringSubstr(json, tradeStart, tradeEnd - tradeStart + 1);

         // Parse this trade
         TradeRecord trade;
         if(ParseSingleTrade(tradeJson, trade))
         {
            // Add to array
            int size = ArraySize(closedTrades);
            ArrayResize(closedTrades, size + 1);
            closedTrades[size] = trade;
            tradesCount++;
         }

         // Move to next trade
         pos = tradeEnd;

         // Check if we've reached the end of trades array
         int nextComma = StringFind(json, ",", pos);
         int arrayEnd = StringFind(json, "]", pos);
         if(arrayEnd >= 0 && (nextComma < 0 || arrayEnd < nextComma))
            break; // End of array
      }

      return tradesCount;
   }

   //+------------------------------------------------------------------+
   //| Parse Single Trade from JSON Object                              |
   //+------------------------------------------------------------------+
   bool ParseSingleTrade(string tradeJson, TradeRecord &trade)
   {
      // Extract ticket (required)
      trade.ticket = (ulong)ExtractJSONNumber(tradeJson, "ticket");
      if(trade.ticket == 0)
         return false; // Invalid trade

      // Extract all fields
      trade.symbol = ExtractJSONString(tradeJson, "symbol");
      trade.type = ExtractJSONString(tradeJson, "type");
      trade.openTime = StringToTime(ExtractJSONString(tradeJson, "open_time"));
      trade.closeTime = StringToTime(ExtractJSONString(tradeJson, "close_time"));
      trade.openPrice = ExtractJSONNumber(tradeJson, "open_price");
      trade.closePrice = ExtractJSONNumber(tradeJson, "close_price");
      trade.lots = ExtractJSONNumber(tradeJson, "lots");
      trade.profit = ExtractJSONNumber(tradeJson, "profit");
      trade.pips = ExtractJSONNumber(tradeJson, "pips");
      trade.strategy = ExtractJSONString(tradeJson, "strategy");
      trade.confidence = (int)ExtractJSONNumber(tradeJson, "confidence");
      trade.comment = ExtractJSONString(tradeJson, "comment");

      return true;
   }

   //+------------------------------------------------------------------+
   //| Extract String Value from JSON                                   |
   //+------------------------------------------------------------------+
   string ExtractJSONString(string json, string key)
   {
      string searchPattern = "\"" + key + "\":";
      int pos = StringFind(json, searchPattern);
      if(pos < 0)
         return "";

      // Find opening quote of value
      int valueStart = StringFind(json, "\"", pos + StringLen(searchPattern));
      if(valueStart < 0)
         return "";

      // Find closing quote
      int valueEnd = StringFind(json, "\"", valueStart + 1);
      if(valueEnd < 0)
         return "";

      return StringSubstr(json, valueStart + 1, valueEnd - valueStart - 1);
   }

   //+------------------------------------------------------------------+
   //| Extract Number Value from JSON                                   |
   //+------------------------------------------------------------------+
   double ExtractJSONNumber(string json, string key)
   {
      string searchPattern = "\"" + key + "\":";
      int pos = StringFind(json, searchPattern);
      if(pos < 0)
         return 0;

      // Skip the pattern
      pos += StringLen(searchPattern);

      // Skip whitespace
      while(pos < StringLen(json) && (StringGetCharacter(json, pos) == ' ' || StringGetCharacter(json, pos) == '\n'))
         pos++;

      // Find end of number (comma, newline, or closing brace)
      int valueEnd = pos;
      while(valueEnd < StringLen(json))
      {
         ushort ch = StringGetCharacter(json, valueEnd);
         if(ch == ',' || ch == '\n' || ch == '\r' || ch == '}' || ch == ' ')
            break;
         valueEnd++;
      }

      string numStr = StringSubstr(json, pos, valueEnd - pos);
      return StringToDouble(numStr);
   }

   //+------------------------------------------------------------------+
   //| Check for New Closed Trades                                      |
   //+------------------------------------------------------------------+
   void CheckForNewClosedTrades()
   {
      // Re-select history to get latest deals
      HistorySelect(0, TimeCurrent());

      int totalNow = HistoryDealsTotal();

      // Only check if there are new deals (silent return - no log spam)
      if(totalNow == lastHistoryTotal)
         return;

      Print("========================================");
      Print("🆕 NEW DEALS DETECTED!");
      Print("Previous count: ", lastHistoryTotal);
      Print("Current count: ", totalNow);
      Print("New deals to process: ", totalNow - lastHistoryTotal);
      Print("========================================");

      for(int i = lastHistoryTotal; i < totalNow; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket <= 0)
         {
            Print("❌ Deal #", i, ": Invalid ticket");
            continue;
         }

         long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         string dealSymbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         string entryType = (dealEntry == DEAL_ENTRY_IN ? "IN" : (dealEntry == DEAL_ENTRY_OUT ? "OUT" : "INOUT"));

         Print("🔍 New Deal #", i, ": Ticket=", ticket,
               " | Magic=", dealMagic, (dealMagic == magic ? " ✅ MATCH" : " ❌ NO MATCH"),
               " | Entry=", entryType,
               " | Symbol=", dealSymbol,
               " | Profit=$", DoubleToString(dealProfit, 2));

         // Only track position exits
         if(dealEntry != DEAL_ENTRY_OUT)
         {
            Print("   → Skipped: Not a position exit (entry type = ", entryType, ")");
            continue;
         }

         // ✅ FIX: Check position's opening deal magic, not closing deal magic
         // When positions close by SL/TP/Manual, closing deal often has Magic=0
         // We need to verify the POSITION was opened by our EA
         ulong positionId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
         long positionMagic = GetPositionOpeningMagic(positionId);

         Print("   → Position ID: ", positionId, " | Opening Magic: ", positionMagic,
               (positionMagic == magic ? " ✅ MATCH" : " ❌ NO MATCH"));

         if(positionMagic != magic)
         {
            Print("   → Skipped: Position not opened by this EA (magic ", positionMagic, " vs ", magic, ")");
            continue;
         }

         // Record this trade
         Print("   ✅ Recording trade!");
         RecordClosedTrade(ticket);
      }

      lastHistoryTotal = totalNow;
      Print("========================================");
      Print("✅ New deals check complete");
      Print("========================================");
   }

   //+------------------------------------------------------------------+
   //| Record Closed Trade                                              |
   //+------------------------------------------------------------------+
   void RecordClosedTrade(ulong dealTicket)
   {
      ulong positionTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

      // ✅ FIX: Check if this trade already exists (prevent duplicates on EA restart)
      if(IsTradeAlreadyRecorded(positionTicket))
      {
         if(verboseLogging)
            Print("Trade #", positionTicket, " already recorded, skipping duplicate");
         return;
      }

      TradeRecord trade;
      trade.ticket = positionTicket;
      trade.symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      trade.type = (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) ? "SELL" : "BUY"; // Reversed
      trade.closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      trade.closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      trade.lots = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      trade.profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      trade.comment = ""; // Will be set from opening deal

      // ✅ FIX: Get open price AND comment from opening deal (DEAL_ENTRY_IN)
      // Closing deals often lose the original comment, especially with SL/TP
      if(HistorySelectByPosition(positionTicket))
      {
         int dealsTotal = HistoryDealsTotal();
         for(int i = 0; i < dealsTotal; i++)
         {
            ulong ticket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
               trade.openTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
               trade.openPrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
               trade.comment = HistoryDealGetString(ticket, DEAL_COMMENT); // ✅ Get comment from opening deal
               break;
            }
         }
      }

      // Calculate pips
      double point = SymbolInfoDouble(trade.symbol, SYMBOL_POINT);
      double priceDiff = MathAbs(trade.closePrice - trade.openPrice);
      trade.pips = priceDiff / (point * 10.0);

      // Parse strategy and confidence from comment (format: "JcampCSM|TREND_RIDER|C85")
      ParseComment(trade.comment, trade.strategy, trade.confidence);

      // Add to array
      int size = ArraySize(closedTrades);
      ArrayResize(closedTrades, size + 1);
      closedTrades[size] = trade;

      if(verboseLogging)
      {
         Print("💰 Trade Closed: #", trade.ticket, " | ", trade.symbol, " ", trade.type,
               " | Profit: $", trade.profit, " | Pips: ", trade.pips);
      }

      // ✅ REAL-TIME FIX: Export immediately for CSMMonitor real-time updates
      ExportTradeHistory();
      Print("📊 Trade history exported immediately (real-time update for monitor)");
   }

   //+------------------------------------------------------------------+
   //| Check if Trade Already Recorded (Prevent Duplicates)            |
   //+------------------------------------------------------------------+
   bool IsTradeAlreadyRecorded(ulong positionTicket)
   {
      for(int i = 0; i < ArraySize(closedTrades); i++)
      {
         if(closedTrades[i].ticket == positionTicket)
            return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Get Magic Number of Position Opening Deal                        |
   //| Returns magic number of the deal that opened this position      |
   //+------------------------------------------------------------------+
   long GetPositionOpeningMagic(ulong positionId)
   {
      // Select position history
      if(!HistorySelectByPosition(positionId))
         return 0;

      // Find the opening deal (ENTRY_IN)
      int dealsTotal = HistoryDealsTotal();
      for(int i = 0; i < dealsTotal; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket <= 0) continue;

         long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(dealEntry == DEAL_ENTRY_IN)
         {
            // Found the opening deal
            long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            return dealMagic;
         }
      }

      return 0; // No opening deal found
   }

   //+------------------------------------------------------------------+
   //| Parse Comment to Extract Strategy and Confidence                 |
   //+------------------------------------------------------------------+
   void ParseComment(string comment, string &strategy, int &confidence)
   {
      strategy = "UNKNOWN";
      confidence = 0;

      // Format: "JcampCSM|TREND_RIDER|C85"
      int pos1 = StringFind(comment, "|");
      if(pos1 < 0) return;

      int pos2 = StringFind(comment, "|", pos1 + 1);
      if(pos2 < 0) return;

      strategy = StringSubstr(comment, pos1 + 1, pos2 - pos1 - 1);

      string confStr = StringSubstr(comment, pos2 + 1);
      if(StringLen(confStr) > 1 && StringSubstr(confStr, 0, 1) == "C")
      {
         confidence = (int)StringToInteger(StringSubstr(confStr, 1));
      }
   }
     //+------------------------------------------------------------------+
     //| Load ALL Historical Trades (JSON + MT5 Merge Strategy)          |
     //| ✅ FIX: Import from JSON first, then scan MT5 for new trades    |
     //+------------------------------------------------------------------+
     void LoadTradeHistory()
     {
        Print("========================================");
        Print("🔄 LOADING TRADE HISTORY (PERSISTENT + MT5)");
        Print("========================================");

        // ✅ STEP 1: Load from persistent JSON storage (source of truth)
        int jsonTrades = LoadTradeHistoryFromJSON();
        Print("📁 Loaded from JSON: ", jsonTrades, " trades");

        // ✅ STEP 2: Scan MT5 for NEW trades not in JSON
        datetime startTime = D'2020.01.01';
        HistorySelect(startTime, TimeCurrent());

        int totalDeals = HistoryDealsTotal();
        int newTradesFound = 0;

        Print("🔍 Scanning MT5 history for new trades...");
        Print("MT5 deals in history: ", totalDeals);
        Print("Filtering for Magic Number: ", magic);
        Print("========================================");

        // Diagnostic counters
        int invalidTickets = 0;
        int positionExits = 0;
        int alreadyRecorded = 0;

        // Scan MT5 for trades not already in our JSON
        for(int i = 0; i < totalDeals; i++)
        {
           ulong ticket = HistoryDealGetTicket(i);
           if(ticket <= 0)
           {
              invalidTickets++;
              continue;
           }

           long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);

           // Skip non-exits (we only track closed positions)
           if(dealEntry != DEAL_ENTRY_OUT)
              continue;

           positionExits++;

           // Get position ID and check opening magic
           ulong positionId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
           long positionMagic = GetPositionOpeningMagic(positionId);

           // Skip if not our EA
           if(positionMagic != magic)
              continue;

           // ✅ KEY FIX: Check if this trade is already in our JSON
           if(IsTradeAlreadyRecorded(positionId))
           {
              alreadyRecorded++;
              continue; // Skip duplicates (already in persistent storage)
           }

           // This is a NEW trade from MT5 that's not in JSON yet
           RecordClosedTrade(ticket);
           newTradesFound++;

           if(verboseLogging)
           {
              Print("🆕 New trade found in MT5: Position #", positionId,
                    " (not in JSON, adding now)");
           }
        }

        Print("========================================");
        Print("📊 LOAD SUMMARY:");
        Print("  - Loaded from JSON (persistent): ", jsonTrades);
        Print("  - MT5 deals scanned: ", totalDeals);
        Print("  - Invalid tickets (skipped): ", invalidTickets);
        Print("  - Position exits found: ", positionExits);
        Print("  - Already recorded (in JSON): ", alreadyRecorded);
        Print("  - NEW trades from MT5: ", newTradesFound);
        Print("  - TOTAL trades now: ", ArraySize(closedTrades));
        Print("========================================");

        if(newTradesFound > 0)
        {
           Print("✅ ", newTradesFound, " new trades merged from MT5");
        }

        if(jsonTrades == 0 && newTradesFound == 0)
        {
           Print("ℹ️ No trade history found (clean account or first run)");
        }

        Print("✅ Trade history load complete");
        Print("========================================");

        // ✅ STEP 3: Export merged result to JSON (backup first)
        if(ArraySize(closedTrades) > 0)
        {
           CreateBackup(); // Backup old JSON before overwriting
           ExportTradeHistory();
        }

        // Track future deals from this point
        lastHistoryTotal = totalDeals;
     }

};
//+------------------------------------------------------------------+
