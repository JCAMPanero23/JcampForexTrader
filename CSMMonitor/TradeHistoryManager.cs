using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json;

namespace JcampForexTrader
{
    // Wrapper for the MT5 exported JSON structure
    public class TradeHistoryFile
    {
        [JsonProperty("exported_at")]
        public string ExportedAt { get; set; }

        [JsonProperty("total_trades")]
        public int TotalTrades { get; set; }

        [JsonProperty("trades")]
        public List<TradeRecord> Trades { get; set; }
    }
    // Matches the JSON format from Main EA exactly
    public class TradeRecord
    {
        [JsonProperty("ticket")]
        public long Ticket { get; set; }

        [JsonProperty("symbol")]
        public string Symbol { get; set; }

        [JsonProperty("strategy")]
        public string Strategy { get; set; }

        [JsonProperty("type")]
        public string Type { get; set; }

        [JsonProperty("open_price")] // MT5 exports "open_price", not "entry_price"
        public double EntryPrice { get; set; }

        [JsonProperty("close_price")] // MT5 exports "close_price", not "exit_price"
        public double ExitPrice { get; set; }

        [JsonProperty("lots")]
        public double Lots { get; set; }

        [JsonProperty("profit")]
        public double Profit { get; set; }

        [JsonProperty("open_time")] // MT5 exports "open_time", not "entry_time"
        public string EntryTimeString { get; set; }

        [JsonProperty("close_time")] // MT5 exports "close_time", not "exit_time"
        public string ExitTimeString { get; set; }

        [JsonIgnore]
        public DateTime EntryTime
        {
            get
            {
                DateTime.TryParse(EntryTimeString, out DateTime result);
                // Convert from broker server time to local time (+2 hours offset)
                return result.AddHours(2);
            }
        }

        [JsonIgnore]
        public DateTime ExitTime
        {
            get
            {
                DateTime.TryParse(ExitTimeString, out DateTime result);
                // Convert from broker server time to local time (+2 hours offset)
                return result.AddHours(2);
            }
        }

        [JsonIgnore]
        public double RMultiple
        {
            get
            {
                double priceMove = Math.Abs(ExitPrice - EntryPrice);
                double risk = EntryPrice * 0.02;

                if (risk > 0)
                {
                    double rValue = priceMove / risk;
                    return Type == "BUY" ?
                        (ExitPrice > EntryPrice ? rValue : -rValue) :
                        (ExitPrice < EntryPrice ? rValue : -rValue);
                }
                return 0;
            }
        }

        [JsonIgnore]
        public string DisplayEntryTime => EntryTime.ToString("yyyy-MM-dd HH:mm");

        [JsonIgnore]
        public string DisplayExitTime => ExitTime.ToString("yyyy-MM-dd HH:mm");

        [JsonIgnore]
        public string DisplayProfit => Profit >= 0 ? $"+${Profit:F2}" : $"-${Math.Abs(Profit):F2}";

        [JsonIgnore]
        public string DisplayRMultiple => $"{RMultiple:F2}R";
    }

    public class TradeHistoryManager
    {
        private List<TradeRecord> allTrades = new List<TradeRecord>();
        private string dataPath;
        private FileSystemWatcher fileWatcher;
        private DateTime lastLoadTime = DateTime.MinValue;

        public event EventHandler TradesUpdated;

        public TradeHistoryManager(string csmDataPath)
        {
            dataPath = csmDataPath;
            System.Diagnostics.Debug.WriteLine($"📁 TradeHistoryManager initialized with path: {dataPath}");

            InitializeFileWatcher();
            LoadAllTrades();
        }

        private void InitializeFileWatcher()
        {
            try
            {
                fileWatcher = new FileSystemWatcher(dataPath);
                fileWatcher.Filter = "trade_history.json";
                fileWatcher.NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.Size;
                fileWatcher.Changed += (s, e) =>
                {
                    System.Diagnostics.Debug.WriteLine($"🔄 File watcher detected change in {e.Name}");
                    LoadAllTrades();
                };
                fileWatcher.EnableRaisingEvents = true;
                System.Diagnostics.Debug.WriteLine("✓ File watcher initialized successfully");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"✗ File watcher error: {ex.Message}");
            }
        }

        public void LoadAllTrades()
        {
            string tradeFile = Path.Combine(dataPath, "trade_history.json");

            System.Diagnostics.Debug.WriteLine($"\n=== Loading Trade History ===");
            System.Diagnostics.Debug.WriteLine($"📂 File path: {tradeFile}");
            System.Diagnostics.Debug.WriteLine($"📅 Last load: {lastLoadTime}");

            if (!File.Exists(tradeFile))
            {
                System.Diagnostics.Debug.WriteLine("⚠ Trade history file not found");
                System.Diagnostics.Debug.WriteLine($"   Expected location: {tradeFile}");
                System.Diagnostics.Debug.WriteLine("   Please ensure Main Trading EA is creating this file");
                allTrades = new List<TradeRecord>();
                return;
            }

            try
            {
                // Check if file was modified since last load
                var fileInfo = new FileInfo(tradeFile);
                var lastWriteTime = fileInfo.LastWriteTime;

                System.Diagnostics.Debug.WriteLine($"📝 File last modified: {lastWriteTime}");
                System.Diagnostics.Debug.WriteLine($"📏 File size: {fileInfo.Length} bytes");

                if (lastWriteTime <= lastLoadTime && allTrades.Count > 0)
                {
                    System.Diagnostics.Debug.WriteLine("⏭ File unchanged, skipping reload");
                    return;
                }

                string jsonContent = File.ReadAllText(tradeFile);
                System.Diagnostics.Debug.WriteLine($"📄 File content length: {jsonContent.Length} characters");

                if (string.IsNullOrWhiteSpace(jsonContent) || jsonContent.Trim() == "[]")
                {
                    System.Diagnostics.Debug.WriteLine("📭 Trade history file is empty or contains empty array");
                    allTrades = new List<TradeRecord>();
                    lastLoadTime = lastWriteTime;
                    return;
                }

                // Show first 200 characters for debugging
                string preview = jsonContent.Length > 200 ?
                    jsonContent.Substring(0, 200) + "..." :
                    jsonContent;
                System.Diagnostics.Debug.WriteLine($"📋 Content preview: {preview}");

                  var historyFile = JsonConvert.DeserializeObject<TradeHistoryFile>(jsonContent);

                  if (historyFile == null || historyFile.Trades == null)
                  {
                      System.Diagnostics.Debug.WriteLine("⚠ Deserialization returned null");
                      allTrades = new List<TradeRecord>();
                  }
                  else
                  {
                      allTrades = historyFile.Trades;
                      System.Diagnostics.Debug.WriteLine($"✓ Successfully loaded {allTrades.Count} trades (from {historyFile.TotalTrades} total)");

                    // Show details of loaded trades
                    if (allTrades.Count > 0)
                    {
                        System.Diagnostics.Debug.WriteLine("\n📊 Trade Summary:");
                        foreach (var trade in allTrades.Take(5))
                        {
                            System.Diagnostics.Debug.WriteLine($"   • Ticket {trade.Ticket}: {trade.Symbol} {trade.Type} | P/L: ${trade.Profit:F2} | R: {trade.RMultiple:F2}R");
                        }

                        if (allTrades.Count > 5)
                        {
                            System.Diagnostics.Debug.WriteLine($"   ... and {allTrades.Count - 5} more trades");
                        }
                    }
                }

                lastLoadTime = lastWriteTime;
                TradesUpdated?.Invoke(this, EventArgs.Empty);
                System.Diagnostics.Debug.WriteLine("✓ TradesUpdated event fired\n");
            }
            catch (JsonReaderException jsonEx)
            {
                System.Diagnostics.Debug.WriteLine($"✗ JSON parsing error: {jsonEx.Message}");
                System.Diagnostics.Debug.WriteLine($"   Position: Line {jsonEx.LineNumber}, Position {jsonEx.LinePosition}");
                allTrades = new List<TradeRecord>();
            }
            catch (JsonException jsonEx)
            {
                System.Diagnostics.Debug.WriteLine($"✗ JSON parsing error: {jsonEx.Message}");
                allTrades = new List<TradeRecord>();
            }
            catch (IOException ioEx)
            {
                System.Diagnostics.Debug.WriteLine($"✗ IO error reading file: {ioEx.Message}");
                // File might be locked, will retry on next update
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"✗ Unexpected error loading trades: {ex.Message}");
                System.Diagnostics.Debug.WriteLine($"   Stack: {ex.StackTrace}");
                allTrades = new List<TradeRecord>();
            }
        }

        public List<TradeRecord> GetAllTrades()
        {
            return new List<TradeRecord>(allTrades);
        }

        public List<TradeRecord> GetRecentTrades(int count = 20)
        {
            return allTrades
                .OrderByDescending(t => t.ExitTime)
                .Take(count)
                .ToList();
        }

        public List<TradeRecord> GetTradesByDateRange(DateTime startDate, DateTime endDate)
        {
            return allTrades
                .Where(t => t.EntryTime >= startDate && t.EntryTime <= endDate)
                .OrderByDescending(t => t.EntryTime)
                .ToList();
        }

        public List<TradeRecord> GetTradesBySymbol(string symbol)
        {
            return allTrades
                .Where(t => t.Symbol == symbol)
                .OrderByDescending(t => t.EntryTime)
                .ToList();
        }

        public List<TradeRecord> GetTradesByStrategy(string strategy)
        {
            return allTrades
                .Where(t => t.Strategy == strategy)
                .OrderByDescending(t => t.EntryTime)
                .ToList();
        }

        public TradeStatistics GetStatistics(List<TradeRecord> trades = null)
        {
            var tradesToAnalyze = trades ?? allTrades;

            if (tradesToAnalyze.Count == 0)
                return new TradeStatistics();

            int wins = tradesToAnalyze.Count(t => t.Profit > 0);
            int losses = tradesToAnalyze.Count(t => t.Profit <= 0);
            double totalProfit = tradesToAnalyze.Sum(t => t.Profit);
            double avgRMultiple = tradesToAnalyze.Average(t => t.RMultiple);
            double winRate = tradesToAnalyze.Count > 0 ? (double)wins / tradesToAnalyze.Count * 100 : 0;

            double grossProfit = tradesToAnalyze.Where(t => t.Profit > 0).Sum(t => t.Profit);
            double grossLoss = Math.Abs(tradesToAnalyze.Where(t => t.Profit < 0).Sum(t => t.Profit));
            double profitFactor = grossLoss > 0 ? grossProfit / grossLoss : 0;

            double maxDrawdown = 0;
            double peak = 0;
            double runningTotal = 0;

            foreach (var trade in tradesToAnalyze.OrderBy(t => t.ExitTime))
            {
                runningTotal += trade.Profit;
                if (runningTotal > peak)
                    peak = runningTotal;

                double drawdown = peak - runningTotal;
                if (drawdown > maxDrawdown)
                    maxDrawdown = drawdown;
            }

            double avgReturn = tradesToAnalyze.Average(t => t.Profit);
            double stdDev = CalculateStandardDeviation(tradesToAnalyze.Select(t => t.Profit).ToList());
            double sharpeRatio = stdDev > 0 ? avgReturn / stdDev : 0;

            return new TradeStatistics
            {
                TotalTrades = tradesToAnalyze.Count,
                Wins = wins,
                Losses = losses,
                WinRate = winRate,
                TotalProfit = totalProfit,
                AverageRMultiple = avgRMultiple,
                ProfitFactor = profitFactor,
                MaxDrawdown = maxDrawdown,
                SharpeRatio = sharpeRatio,
                BestTrade = tradesToAnalyze.OrderByDescending(t => t.RMultiple).FirstOrDefault(),
                WorstTrade = tradesToAnalyze.OrderBy(t => t.RMultiple).FirstOrDefault(),
                GrossProfit = grossProfit,
                GrossLoss = grossLoss
            };
        }

        public Dictionary<string, TradeStatistics> GetStatisticsByStrategy()
        {
            var result = new Dictionary<string, TradeStatistics>();

            var strategies = allTrades.Select(t => t.Strategy).Distinct();

            foreach (var strategy in strategies)
            {
                var strategyTrades = allTrades.Where(t => t.Strategy == strategy).ToList();
                result[strategy] = GetStatistics(strategyTrades);
            }

            return result;
        }

        public Dictionary<string, TradeStatistics> GetStatisticsBySymbol()
        {
            var result = new Dictionary<string, TradeStatistics>();

            var symbols = allTrades.Select(t => t.Symbol).Distinct();

            foreach (var symbol in symbols)
            {
                var symbolTrades = allTrades.Where(t => t.Symbol == symbol).ToList();
                result[symbol] = GetStatistics(symbolTrades);
            }

            return result;
        }

        public bool ExportToCSV(string filename, DateTime? startDate = null, DateTime? endDate = null,
                                string symbol = null, string strategy = null)
        {
            try
            {
                System.Diagnostics.Debug.WriteLine($"\n=== Exporting to CSV ===");
                System.Diagnostics.Debug.WriteLine($"📁 Target file: {filename}");

                var tradesToExport = allTrades.AsEnumerable();

                if (startDate.HasValue)
                {
                    tradesToExport = tradesToExport.Where(t => t.EntryTime >= startDate.Value);
                    System.Diagnostics.Debug.WriteLine($"📅 Filter: After {startDate.Value:yyyy-MM-dd}");
                }

                if (endDate.HasValue)
                {
                    tradesToExport = tradesToExport.Where(t => t.EntryTime <= endDate.Value);
                    System.Diagnostics.Debug.WriteLine($"📅 Filter: Before {endDate.Value:yyyy-MM-dd}");
                }

                if (!string.IsNullOrEmpty(symbol) && symbol != "All")
                {
                    tradesToExport = tradesToExport.Where(t => t.Symbol == symbol);
                    System.Diagnostics.Debug.WriteLine($"💱 Filter: Symbol = {symbol}");
                }

                if (!string.IsNullOrEmpty(strategy) && strategy != "All")
                {
                    tradesToExport = tradesToExport.Where(t => t.Strategy == strategy);
                    System.Diagnostics.Debug.WriteLine($"📈 Filter: Strategy = {strategy}");
                }

                var orderedTrades = tradesToExport.OrderBy(t => t.EntryTime).ToList();
                System.Diagnostics.Debug.WriteLine($"✓ {orderedTrades.Count} trades to export");

                using (var writer = new StreamWriter(filename))
                {
                    writer.WriteLine("Ticket,Symbol,Strategy,Type,Lots,Entry Price,Exit Price," +
                                   "Entry Time,Exit Time,Profit,R-Multiple");

                    foreach (var trade in orderedTrades)
                    {
                        writer.WriteLine($"{trade.Ticket}," +
                                       $"{trade.Symbol}," +
                                       $"{trade.Strategy}," +
                                       $"{trade.Type}," +
                                       $"{trade.Lots:F2}," +
                                       $"{trade.EntryPrice:F5}," +
                                       $"{trade.ExitPrice:F5}," +
                                       $"{trade.DisplayEntryTime}," +
                                       $"{trade.DisplayExitTime}," +
                                       $"{trade.Profit:F2}," +
                                       $"{trade.RMultiple:F2}");
                    }
                }

                System.Diagnostics.Debug.WriteLine($"✓ Export completed successfully");
                return true;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"✗ Export error: {ex.Message}");
                return false;
            }
        }

        private double CalculateStandardDeviation(List<double> values)
        {
            if (values.Count == 0)
                return 0;

            double avg = values.Average();
            double sumOfSquares = values.Sum(v => Math.Pow(v - avg, 2));
            return Math.Sqrt(sumOfSquares / values.Count);
        }
    }

    public class TradeStatistics
    {
        public int TotalTrades { get; set; }
        public int Wins { get; set; }
        public int Losses { get; set; }
        public double WinRate { get; set; }
        public double TotalProfit { get; set; }
        public double AverageRMultiple { get; set; }
        public double ProfitFactor { get; set; }
        public double MaxDrawdown { get; set; }
        public double SharpeRatio { get; set; }
        public double GrossProfit { get; set; }
        public double GrossLoss { get; set; }
        public TradeRecord BestTrade { get; set; }
        public TradeRecord WorstTrade { get; set; }
    }
}