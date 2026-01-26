//+------------------------------------------------------------------+
//|                                      PerformanceTracker.mqh       |
//|                                            JcampForexTrader       |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
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

      // Load existing trade history
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
   //+------------------------------------------------------------------+
   bool ExportTradeHistory()
   {
      string filename = exportFolder + "\\trade_history.json";

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
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double lots = PositionGetDouble(POSITION_VOLUME);
         double profit = PositionGetDouble(POSITION_PROFIT);
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

         string typeStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";

         content += "Ticket: " + IntegerToString((int)ticket) +
                    " | " + symbol + " " + typeStr +
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
   //| Check for New Closed Trades                                      |
   //+------------------------------------------------------------------+
   void CheckForNewClosedTrades()
   {
      int totalNow = HistoryDealsTotal();

      // Only check if there are new deals
      if(totalNow == lastHistoryTotal)
         return;

      HistorySelect(0, TimeCurrent());

      for(int i = lastHistoryTotal; i < totalNow; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket <= 0) continue;

         // Only track deals from this EA
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
            continue;

         // Only track position exits
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;

         // Record this trade
         RecordClosedTrade(ticket);
      }

      lastHistoryTotal = totalNow;
   }

   //+------------------------------------------------------------------+
   //| Record Closed Trade                                              |
   //+------------------------------------------------------------------+
   void RecordClosedTrade(ulong dealTicket)
   {
      TradeRecord trade;

      ulong positionTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      trade.ticket = positionTicket;
      trade.symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      trade.type = (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) ? "SELL" : "BUY"; // Reversed
      trade.closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      trade.closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      trade.lots = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      trade.profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      trade.comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);

      // Get open price from position history
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
     //| Load ALL Historical Trades from MT5 Account History             |
     //| Exports all closed trades on EA startup                          |
     //+------------------------------------------------------------------+
     void LoadTradeHistory()
     {
        // Select all history from start of 2020
        datetime startTime = D'2020.01.01';
        HistorySelect(startTime, TimeCurrent());

        int totalDeals = HistoryDealsTotal();

        if(verboseLogging)
           Print("📜 Scanning ", totalDeals, " historical deals for magic ", magic);

        // Scan all deals for position exits with our magic number
        for(int i = 0; i < totalDeals; i++)
        {
           ulong ticket = HistoryDealGetTicket(i);
           if(ticket <= 0) continue;

           // Only our EA's trades
           if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
              continue;

           // Only position exits
           if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
              continue;

           // Record this closed trade
           RecordClosedTrade(ticket);
        }

        Print("✅ Loaded ", ArraySize(closedTrades), " historical trades");

        // Export immediately for CSMMonitor
        if(ArraySize(closedTrades) > 0)
        {
           ExportTradeHistory();
        }

        // Track future deals from this point
        lastHistoryTotal = totalDeals;
     }

};
//+------------------------------------------------------------------+
