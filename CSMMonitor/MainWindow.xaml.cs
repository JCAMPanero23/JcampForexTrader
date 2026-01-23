using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using Newtonsoft.Json;
using IOPath = System.IO.Path;

namespace JcampForexTrader
{
    public partial class MainWindow : Window
    {
        // DEBUG FLAG: Set to false to suppress verbose debug output
        private const bool ENABLE_VERBOSE_DEBUG = false;

        private TradeHistoryManager tradeHistoryManager;
        private DispatcherTimer refreshTimer;
        private string csmDataPath;
        private Dictionary<string, double> currencyStrengths;
        private Dictionary<string, SignalData> pairSignals;
        private double colorIntensity = 0.6;  // Default 60% intensity
        private Dictionary<string, Color> mutedColors;
        private const double MIN_CONFIDENCE_THRESHOLD = 30.0;  // Testing mode (change to 60.0 for production)
        private const double MIN_CSM_DIFFERENTIAL = 5.0;        // Testing mode (change to 20.0 for production)

        public class SignalData
        {
            public string TrendRiderSignal { get; set; } = "HOLD";
            public int TrendRiderConfidence { get; set; } = 0;
            public string TrendRiderReasoning { get; set; } = "";
            public Dictionary<string, int> TrendRiderScores { get; set; } = new Dictionary<string, int>();

            public string ImpulsePullbackSignal { get; set; } = "HOLD";
            public int ImpulsePullbackConfidence { get; set; } = 0;
            public string ImpulsePullbackReasoning { get; set; } = "";
            public Dictionary<string, int> ImpulsePullbackScores { get; set; } = new Dictionary<string, int>();

            public string BreakoutRetestSignal { get; set; } = "HOLD";
            public int BreakoutRetestConfidence { get; set; } = 0;
            public string BreakoutRetestReasoning { get; set; } = "";
            public Dictionary<string, int> BreakoutRetestScores { get; set; } = new Dictionary<string, int>();

            public string BestSignal { get; set; } = "HOLD";
            public int BestConfidence { get; set; } = 0;

            // Additional JSON fields
            public double CsmDifferential { get; set; } = 0;
            public string CsmTrend { get; set; } = "";
        }

        public class PositionDisplay
        {
            [JsonIgnore]
            public string Ticket { get; set; }
            [JsonIgnore]
            public string Symbol { get; set; }
            [JsonIgnore]
            public string Strategy { get; set; }
            [JsonIgnore]
            public string Type { get; set; }
            [JsonIgnore]
            public string EntryPrice { get; set; }
            [JsonIgnore]
            public string CurrentPrice { get; set; }
            [JsonIgnore]
            public string StopLoss { get; set; }
            [JsonIgnore]
            public string TakeProfit { get; set; }
            [JsonIgnore]
            public string Size { get; set; }
            [JsonIgnore]
            public string PnL { get; set; }
            [JsonIgnore]
            public string RMultiple { get; set; }
            [JsonIgnore]
            public string Risk { get; set; }
            [JsonIgnore]
            public string EntryTime { get; set; }
        }
        public MainWindow()
        {
            InitializeComponent();
            InitializeMutedColors();
            InitializeData();
            InitializeTimer();
            UpdateDisplay();
        }

        private void InitializeData()
        {
            // Find CSM_Data directory
            string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            csmDataPath = IOPath.Combine(userProfile, "AppData", "Roaming", "MetaQuotes", "Terminal");

            bool pathFound = false;

            if (Directory.Exists(csmDataPath))
            {
                var terminalDirs = Directory.GetDirectories(csmDataPath);
                foreach (var dir in terminalDirs)
                {
                    string possiblePath = IOPath.Combine(dir, "MQL5", "Files", "CSM_Data");
                    if (Directory.Exists(possiblePath))
                    {
                        csmDataPath = possiblePath;
                        pathFound = true;
                        break;
                    }
                }
            }

            // Set the path in the textbox and show status
            Dispatcher.Invoke(() => {
                if (MT5PathTextBox != null)
                {
                    MT5PathTextBox.Text = csmDataPath;
                }

                if (!pathFound)
                {
                    StatusText.Text = "⚠️ CSM_Data directory not found! Please set path in Settings.";
                    ConnectionStatus.Text = "Path Invalid";
                    ConnectionIndicator.Fill = new SolidColorBrush(Colors.Orange);
                }
            });

            currencyStrengths = new Dictionary<string, double>();
            pairSignals = new Dictionary<string, SignalData>
            {
                ["EURUSD"] = new SignalData(),
                ["GBPUSD"] = new SignalData(),
                ["AUDJPY"] = new SignalData(),
                ["XAUUSD"] = new SignalData()
            };
            // Initialize trade history manager
            if (pathFound && Directory.Exists(csmDataPath))
            {
                try
                {
                    tradeHistoryManager = new TradeHistoryManager(csmDataPath);
                    tradeHistoryManager.TradesUpdated += (s, e) =>
                    {
                        Dispatcher.Invoke(() => UpdatePerformanceMetrics());
                    };
                    System.Diagnostics.Debug.WriteLine("Trade History Manager initialized");
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Failed to initialize Trade History Manager: {ex.Message}");
                }
            };
        }

        private void InitializeMutedColors()
        {
            mutedColors = new Dictionary<string, Color>
            {
                ["Green"] = Color.FromRgb(74, 111, 74),      // #4A6F4A
                ["Red"] = Color.FromRgb(122, 74, 74),        // #7A4A4A
                ["Yellow"] = Color.FromRgb(122, 122, 74),    // #7A7A4A
                ["Orange"] = Color.FromRgb(122, 90, 74),     // #7A5A4A
                ["Blue"] = Color.FromRgb(74, 90, 122),       // #4A5A7A
                ["Purple"] = Color.FromRgb(106, 74, 122),    // #6A4A7A
                ["Gray"] = Color.FromRgb(136, 136, 136)      // #888888
            };

            System.Diagnostics.Debug.WriteLine("✓ Muted colors initialized");
        }

        private SolidColorBrush GetMutedBrush(string colorName)
        {
            if (!mutedColors.ContainsKey(colorName))
            {
                System.Diagnostics.Debug.WriteLine($"⚠ Color '{colorName}' not found, using Gray");
                return new SolidColorBrush(mutedColors["Gray"]);
            }

            Color baseColor = mutedColors[colorName];

            // Apply intensity adjustment (0.3 to 1.0)
            byte r = (byte)(baseColor.R * colorIntensity);
            byte g = (byte)(baseColor.G * colorIntensity);
            byte b = (byte)(baseColor.B * colorIntensity);

            return new SolidColorBrush(Color.FromRgb(r, g, b));
        }
        private void InitializeTimer()
        {
            refreshTimer = new DispatcherTimer();
            refreshTimer.Interval = TimeSpan.FromSeconds(5);
            refreshTimer.Tick += RefreshTimer_Tick;
            refreshTimer.Start();
        }

        private void RefreshTimer_Tick(object sender, EventArgs e)
        {
            UpdateDisplay();
        }

        private void UpdateDisplay()
        {
            try
            {
                LoadCSMData();
                LoadSignalData();
                LoadAccountInfo();
                UpdatePerformanceMetrics();
                UpdateUI();
                ConnectionStatus.Text = "Connected";
                ConnectionIndicator.Fill = new SolidColorBrush(Colors.Green);
            }
            catch (Exception ex)
            {
                ConnectionStatus.Text = "Error: " + ex.Message;
                ConnectionIndicator.Fill = new SolidColorBrush(Colors.Red);
                System.Diagnostics.Debug.WriteLine($"Update Display Error: {ex}");
            }
        }

        private void UpdatePerformanceMetrics()
        {
            // NOTE: Debug output temporarily disabled for EMA debugging (Nov 27, 2025)
            if (ENABLE_VERBOSE_DEBUG)
                System.Diagnostics.Debug.WriteLine("=== UpdatePerformanceMetrics Called ===");

            if (tradeHistoryManager == null)
            {
                if (ENABLE_VERBOSE_DEBUG)
                    System.Diagnostics.Debug.WriteLine("✗ TradeHistoryManager is null");
                return;
            }

            try
            {
                var allTrades = tradeHistoryManager.GetAllTrades();
                if (ENABLE_VERBOSE_DEBUG)
                    System.Diagnostics.Debug.WriteLine($"📊 Total trades loaded: {allTrades.Count}");

                if (allTrades.Count == 0)
                {
                    if (ENABLE_VERBOSE_DEBUG)
                        System.Diagnostics.Debug.WriteLine("⚠ No trades to display - clearing metrics");

                    // Set default values when no trades exist
                    Dispatcher.Invoke(() =>
                    {
                        DailyPnLText.Text = "$0.00";
                        DailyPnLText.Foreground = new SolidColorBrush(Colors.Gray);
                        WinRateText.Text = "0.0%";
                        AvgRMultipleText.Text = "0.00R";

                        TotalReturnText.Text = "$0.00";
                        TotalReturnText.Foreground = new SolidColorBrush(Colors.Gray);
                        WinRateDetailText.Text = "0.0%";
                        WinLossText.Text = "0W / 0L";
                        ProfitFactorText.Text = "0.00";
                        MaxDrawdownText.Text = "$0.00";
                        SharpeRatioText.Text = "0.00";

                        TradeHistoryGrid.ItemsSource = null;
                        TotalTradesText.Text = "0";
                        AverageRText.Text = "0.00R";

                        StrategyPerformanceGrid.ItemsSource = null;
                    });
                    return;
                }

                var stats = tradeHistoryManager.GetStatistics();
                if (ENABLE_VERBOSE_DEBUG)
                    System.Diagnostics.Debug.WriteLine($"✓ Statistics calculated: WinRate={stats.WinRate:F1}%, Profit=${stats.TotalProfit:F2}");

                Dispatcher.Invoke(() =>
                {
                    // Dashboard metrics (Live Dashboard tab)
                    DailyPnLText.Text = "$" + stats.TotalProfit.ToString("F2");
                    // Use muted colors
                    DailyPnLText.Foreground = stats.TotalProfit >= 0 ?
                        GetMutedBrush("Green") : GetMutedBrush("Red");
                    WinRateText.Text = stats.WinRate.ToString("F1") + "%";
                    AvgRMultipleText.Text = stats.AverageRMultiple.ToString("F2") + "R";

                    // Performance tab - Key metrics
                    TotalReturnText.Text = "$" + stats.TotalProfit.ToString("F2");
                    // Use muted colors
                    TotalReturnText.Foreground = stats.TotalProfit >= 0 ?
                        GetMutedBrush("Green") : GetMutedBrush("Red");
                    WinRateDetailText.Text = stats.WinRate.ToString("F1") + "%";
                    WinLossText.Text = $"{stats.Wins}W / {stats.Losses}L";
                    ProfitFactorText.Text = stats.ProfitFactor.ToString("F2");
                    MaxDrawdownText.Text = "$" + stats.MaxDrawdown.ToString("F2");
                    SharpeRatioText.Text = stats.SharpeRatio.ToString("F2");

                    // Trade History Grid (R-Multiple Analysis tab)
                    var recentTrades = tradeHistoryManager.GetRecentTrades(50);
                    if (ENABLE_VERBOSE_DEBUG)
                        System.Diagnostics.Debug.WriteLine($"📋 Recent trades for grid: {recentTrades.Count}");

                    var displayTrades = recentTrades.Select(t => new
                    {
                        Date = t.DisplayExitTime,
                        Symbol = t.Symbol,
                        Strategy = t.Strategy,
                        Type = t.Type,
                        PnL = t.DisplayProfit,
                        RMultiple = t.DisplayRMultiple,
                        Risk = "2%"
                    }).ToList();

                    TradeHistoryGrid.ItemsSource = displayTrades;
                    TotalTradesText.Text = stats.TotalTrades.ToString();
                    AverageRText.Text = stats.AverageRMultiple.ToString("F2") + "R";

                    // Strategy Performance Grid
                    var strategyStats = tradeHistoryManager.GetStatisticsByStrategy();
                    if (ENABLE_VERBOSE_DEBUG)
                        System.Diagnostics.Debug.WriteLine($"📈 Strategy stats: {strategyStats.Count} strategies");

                    var strategyDisplay = strategyStats.Select(kvp => new
                    {
                        Strategy = kvp.Key,
                        TotalTrades = kvp.Value.TotalTrades,
                        Wins = kvp.Value.Wins,
                        Losses = kvp.Value.Losses,
                        WinRate = kvp.Value.WinRate.ToString("F1") + "%",
                        AvgR = kvp.Value.AverageRMultiple.ToString("F2") + "R",
                        BestR = kvp.Value.BestTrade?.RMultiple.ToString("F2") + "R" ?? "N/A",
                        WorstR = kvp.Value.WorstTrade?.RMultiple.ToString("F2") + "R" ?? "N/A",
                        TotalPnL = "$" + kvp.Value.TotalProfit.ToString("F2"),
                        ProfitFactor = kvp.Value.ProfitFactor.ToString("F2")
                    }).ToList();

                    StrategyPerformanceGrid.ItemsSource = strategyDisplay;

                    if (ENABLE_VERBOSE_DEBUG)
                        System.Diagnostics.Debug.WriteLine("✓ All performance metrics updated successfully");
                });
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"✗ Error updating metrics: {ex.Message}");
                System.Diagnostics.Debug.WriteLine($"   Stack: {ex.StackTrace}");
            }
        }

        private void LoadCSMData()
        {
            string csmFile = IOPath.Combine(csmDataPath, "csm_current.txt");

            if (!File.Exists(csmFile))
            {
                StatusText.Text = $"⚠️ Waiting for CSM data file: {csmFile}";
                return;
            }

            try
            {
                var lines = File.ReadAllLines(csmFile);
                int currenciesLoaded = 0;

                foreach (var line in lines)
                {
                    // Skip comments and empty lines
                    if (string.IsNullOrWhiteSpace(line) || line.StartsWith("#"))
                        continue;

                    // CSM Alpha format: "CURRENCY,STRENGTH" (comma-separated)
                    if (line.Contains(","))
                    {
                        var parts = line.Split(',');
                        if (parts.Length == 2)
                        {
                            string currency = parts[0].Trim();
                            if (double.TryParse(parts[1].Trim(), out double strength))
                            {
                                currencyStrengths[currency] = strength;
                                currenciesLoaded++;
                            }
                        }
                    }

                    // Legacy format support: "CURRENCY=STRENGTH" (equals sign)
                    else if (line.Contains("=") && !line.StartsWith("[") && !line.StartsWith("TIMESTAMP="))
                    {
                        var parts = line.Split('=');
                        if (parts.Length == 2)
                        {
                            string currency = parts[0].Trim();
                            if (double.TryParse(parts[1].Trim(), out double strength))
                            {
                                currencyStrengths[currency] = strength;
                                currenciesLoaded++;
                            }
                        }
                    }
                }

                // Update status with data quality
                if (currenciesLoaded > 0)
                {
                    StatusText.Text = $"✓ CSM data loaded: {currenciesLoaded} currencies";
                    LastUpdateStatusText.Text = DateTime.Now.ToString("HH:mm:ss");
                }
                else
                {
                    StatusText.Text = "⚠️ CSM file exists but no valid data found";
                }
            }
            catch (Exception ex)
            {
                StatusText.Text = $"❌ Error reading CSM file: {ex.Message}";
            }
        }

        private void LoadSignalData()
        {
            // Signal files are in CSM_Signals folder (sibling to CSM_Data)
            string signalPath = csmDataPath.Replace("CSM_Data", "CSM_Signals");

            // CSM Alpha: Handle broker suffix (.sml) for some symbols
            var pairMappings = new Dictionary<string, string>
            {
                ["EURUSD"] = "EURUSD.sml",
                ["GBPUSD"] = "GBPUSD.sml",
                ["AUDJPY"] = "AUDJPY",
                ["XAUUSD"] = "XAUUSD.sml"
            };

            foreach (var kvp in pairMappings)
            {
                string displayPair = kvp.Key;      // EURUSD (for display)
                string filePair = kvp.Value;        // EURUSD.sml (for file name)

                // Look for JSON file first, fallback to TXT if not found
                string jsonFile = IOPath.Combine(signalPath, $"{filePair}_signals.json");
                string txtFile = IOPath.Combine(signalPath, $"{filePair}_signals.txt");

                try
                {
                    if (File.Exists(jsonFile))
                    {
                        LoadSignalFromJSON(displayPair, jsonFile);
                        if (ENABLE_VERBOSE_DEBUG)
                            System.Diagnostics.Debug.WriteLine($"Loaded {displayPair} from JSON");
                    }
                    else if (File.Exists(txtFile))
                    {
                        // Fallback to TXT format for backward compatibility
                        LoadSignalFromTXT(displayPair, txtFile);
                        if (ENABLE_VERBOSE_DEBUG)
                            System.Diagnostics.Debug.WriteLine($"Loaded {displayPair} from TXT (fallback)");
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error loading {displayPair} signals: {ex.Message}");
                }
            }
        }

        private void LoadSignalFromJSON(string pair, string filePath)
        {
            try
            {
                string jsonContent = File.ReadAllText(filePath);
                var signalFile = JsonConvert.DeserializeObject<SignalFileData>(jsonContent);

                if (signalFile == null)
                    return;

                var signalData = pairSignals[pair];

                // Load Trend Rider data
                if (signalFile.TrendRider != null)
                {
                    signalData.TrendRiderSignal = signalFile.TrendRider.Signal ?? "HOLD";
                    signalData.TrendRiderConfidence = signalFile.TrendRider.Confidence;
                    signalData.TrendRiderReasoning = signalFile.TrendRider.Reasoning ?? "";

                    // Extract component scores
                    if (signalFile.TrendRider.ComponentScores != null)
                    {
                        var scores = signalFile.TrendRider.ComponentScores;
                        signalData.TrendRiderScores["EMA_ALIGN"] = scores.EmaAlign ?? 0;
                        signalData.TrendRiderScores["ADX"] = scores.Adx ?? 0;
                        signalData.TrendRiderScores["RSI"] = scores.Rsi ?? 0;
                        signalData.TrendRiderScores["CSM"] = scores.Csm ?? 0;
                    }
                }

                // Load Impulse Pullback data
                if (signalFile.ImpulsePullback != null)
                {
                    signalData.ImpulsePullbackSignal = signalFile.ImpulsePullback.Signal ?? "HOLD";
                    signalData.ImpulsePullbackConfidence = signalFile.ImpulsePullback.Confidence;
                    signalData.ImpulsePullbackReasoning = signalFile.ImpulsePullback.Reasoning ?? "";

                    if (signalFile.ImpulsePullback.ComponentScores != null)
                    {
                        var scores = signalFile.ImpulsePullback.ComponentScores;
                        signalData.ImpulsePullbackScores["IMPULSE"] = scores.Impulse ?? 0;
                        signalData.ImpulsePullbackScores["FIB"] = scores.Fib ?? 0;
                        signalData.ImpulsePullbackScores["RSI"] = scores.Rsi ?? 0;
                        signalData.ImpulsePullbackScores["CSM"] = scores.Csm ?? 0;
                    }
                }

                // Load Breakout & Retest data
                if (signalFile.BreakoutRetest != null)
                {
                    signalData.BreakoutRetestSignal = signalFile.BreakoutRetest.Signal ?? "HOLD";
                    signalData.BreakoutRetestConfidence = signalFile.BreakoutRetest.Confidence;
                    signalData.BreakoutRetestReasoning = signalFile.BreakoutRetest.Reasoning ?? "";

                    if (signalFile.BreakoutRetest.ComponentScores != null)
                    {
                        var scores = signalFile.BreakoutRetest.ComponentScores;
                        signalData.BreakoutRetestScores["LEVEL"] = scores.Level ?? 0;
                        signalData.BreakoutRetestScores["BREAKOUT"] = scores.Breakout ?? 0;
                        signalData.BreakoutRetestScores["VOLUME"] = scores.Volume ?? 0;
                        signalData.BreakoutRetestScores["CSM"] = scores.Csm ?? 0;
                    }
                }

                // Load Overall Assessment
                if (signalFile.OverallAssessment != null)
                {
                    signalData.BestSignal = signalFile.OverallAssessment.RecommendedAction ?? "HOLD";
                    signalData.BestConfidence = signalFile.OverallAssessment.HighestConfidence;
                }

                // Load CSM data
                if (signalFile.CsmData != null)
                {
                    signalData.CsmDifferential = signalFile.CsmData.StrengthDifferential;
                    signalData.CsmTrend = signalFile.CsmData.CsmTrend ?? "";
                }
            }
            catch (JsonException jsonEx)
            {
                System.Diagnostics.Debug.WriteLine($"JSON parse error for {pair}: {jsonEx.Message}");
                StatusText.Text = $"⚠️ JSON parse error for {pair}";
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error reading {pair} JSON: {ex.Message}");
            }
        }

        private void LoadSignalFromTXT(string pair, string filePath)
        {
            // Keep TXT parsing for backward compatibility
            var lines = File.ReadAllLines(filePath);
            var signalData = pairSignals[pair];
            string currentSection = "";

            foreach (var line in lines)
            {
                if (line.Contains("[TREND_RIDER]"))
                    currentSection = "TREND_RIDER";
                else if (line.Contains("[IMPULSE_PULLBACK]"))
                    currentSection = "IMPULSE_PULLBACK";
                else if (line.Contains("[BREAKOUT_RETEST]"))
                    currentSection = "BREAKOUT_RETEST";
                else if (line.Contains("[OVERALL_ASSESSMENT]"))
                    currentSection = "OVERALL";

                if (line.Contains("="))
                {
                    var parts = line.Split('=');
                    if (parts.Length == 2)
                    {
                        string key = parts[0].Trim();
                        string value = parts[1].Trim();

                        switch (currentSection)
                        {
                            case "TREND_RIDER":
                                if (key == "SIGNAL") signalData.TrendRiderSignal = value;
                                else if (key == "CONFIDENCE" && int.TryParse(value, out int trConf))
                                    signalData.TrendRiderConfidence = trConf;
                                else if (key == "REASONING")
                                {
                                    signalData.TrendRiderReasoning = value;
                                    signalData.TrendRiderScores = ParseReasoningScores(value);
                                }
                                break;

                            case "IMPULSE_PULLBACK":
                                if (key == "SIGNAL") signalData.ImpulsePullbackSignal = value;
                                else if (key == "CONFIDENCE" && int.TryParse(value, out int ipConf))
                                    signalData.ImpulsePullbackConfidence = ipConf;
                                else if (key == "REASONING")
                                {
                                    signalData.ImpulsePullbackReasoning = value;
                                    signalData.ImpulsePullbackScores = ParseReasoningScores(value);
                                }
                                break;

                            case "BREAKOUT_RETEST":
                                if (key == "SIGNAL") signalData.BreakoutRetestSignal = value;
                                else if (key == "CONFIDENCE" && int.TryParse(value, out int brConf))
                                    signalData.BreakoutRetestConfidence = brConf;
                                else if (key == "REASONING")
                                {
                                    signalData.BreakoutRetestReasoning = value;
                                    signalData.BreakoutRetestScores = ParseReasoningScores(value);
                                }
                                break;

                            case "OVERALL":
                                if (key == "RECOMMENDED_ACTION") signalData.BestSignal = value;
                                else if (key == "HIGHEST_CONFIDENCE" && int.TryParse(value, out int bestConf))
                                    signalData.BestConfidence = bestConf;
                                break;
                        }
                    }
                }
            }
        }

        private Dictionary<string, int> ParseReasoningScores(string reasoning)
        {
            var scores = new Dictionary<string, int>();

            if (string.IsNullOrEmpty(reasoning))
                return scores;

            // Parse format: "EMA_ALIGN:30,ADX:20,RSI:10,CSM:25"
            var parts = reasoning.Split(',');
            foreach (var part in parts)
            {
                var keyValue = part.Split(':');
                if (keyValue.Length == 2)
                {
                    string key = keyValue[0].Trim();
                    if (int.TryParse(keyValue[1].Trim(), out int value))
                    {
                        scores[key] = value;
                    }
                }
            }

            return scores;
        }

        private void UpdateUI()
        {
            // Update Currency Strength Display with inline values
            UpdateCurrencyStrengthDisplay();

            // Update Signal Displays
            UpdateSignalDisplay("EURUSD");
            UpdateSignalDisplay("GBPUSD");
            UpdateSignalDisplay("AUDJPY");
            UpdateSignalDisplay("XAUUSD");

            UpdateStrategyDetails("EURUSD");
            UpdateStrategyDetails("GBPUSD");
            UpdateStrategyDetails("AUDJPY");
            UpdateStrategyDetails("XAUUSD");

            UpdateStatusPanels();
        }

        private void UpdateCurrencyStrengthDisplay()
        {
            // Force UI update on dispatcher thread
            Dispatcher.Invoke(() =>
            {
                CurrencyStrengthGrid.Children.Clear();

                string[] currencies = { "USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD", "NZD", "XAU" };

                foreach (string currency in currencies)
                {
                    bool hasData = currencyStrengths.ContainsKey(currency);
                    double strength = hasData ? currencyStrengths[currency] : 50.0;

                    var border = new Border
                    {
                        BorderThickness = new Thickness(2),
                        CornerRadius = new CornerRadius(8),
                        Margin = new Thickness(5),
                        Padding = new Thickness(15),
                        Background = new SolidColorBrush(Color.FromRgb(45, 45, 48)),
                        MinHeight = 80,
                        MinWidth = 120
                    };

                    // Border color
                    if (!hasData)
                        border.BorderBrush = GetMutedBrush("Gray");
                    else if (strength > 70)
                        border.BorderBrush = GetMutedBrush("Green");
                    else if (strength > 40)
                        border.BorderBrush = GetMutedBrush("Orange");
                    else
                        border.BorderBrush = GetMutedBrush("Red");

                    var stackPanel = new StackPanel
                    {
                        HorizontalAlignment = HorizontalAlignment.Center,
                        VerticalAlignment = VerticalAlignment.Center
                    };

                    // SINGLE value display with equals sign
                    var strengthValue = new TextBlock
                    {
                        Text = hasData ? $"{currency} = {strength:F1}" : $"{currency} = --",
                        FontSize = 18,
                        FontWeight = FontWeights.Bold,
                        Foreground = hasData ?
                            new SolidColorBrush(Color.FromRgb(204, 204, 204)) :  // Muted white
                            GetMutedBrush("Gray"),
                        HorizontalAlignment = HorizontalAlignment.Center
                    };

                    var indicatorText = new TextBlock
                    {
                        Text = hasData ? "●" : "○",
                        FontSize = 16,
                        Foreground = !hasData ? GetMutedBrush("Gray") :
                            strength > 70 ? GetMutedBrush("Green") :
                            strength > 60 ? GetMutedBrush("Yellow") :
                            strength < 30 ? GetMutedBrush("Red") :
                            strength < 40 ? GetMutedBrush("Orange") :
                            GetMutedBrush("Gray"),
                        HorizontalAlignment = HorizontalAlignment.Center,
                        Margin = new Thickness(0, 5, 0, 0)
                    };

                    stackPanel.Children.Add(strengthValue);
                    stackPanel.Children.Add(indicatorText);

                    border.Child = stackPanel;
                    CurrencyStrengthGrid.Children.Add(border);
                }
            });

            if (ENABLE_VERBOSE_DEBUG)
                System.Diagnostics.Debug.WriteLine($"CSM Display Updated - Currencies: {currencyStrengths.Count}");
        }

        private void UpdateSignalDisplay(string pair)
        {
            // ═══════════════════════════════════════════════════════════
            // SAFETY: Check for null before accessing
            // ═══════════════════════════════════════════════════════════
            if (pairSignals == null)
            {
                System.Diagnostics.Debug.WriteLine($"⚠ pairSignals is null - cannot update {pair}");
                return;
            }

            if (!pairSignals.ContainsKey(pair))
                return;

            var signalData = pairSignals[pair];

            // Find the controls for this pair
            var trSignal = FindName($"{pair}_TR_Signal") as TextBlock;
            var trConf = FindName($"{pair}_TR_Conf") as TextBlock;
            var ipSignal = FindName($"{pair}_IP_Signal") as TextBlock;
            var ipConf = FindName($"{pair}_IP_Conf") as TextBlock;
            var brSignal = FindName($"{pair}_BR_Signal") as TextBlock;
            var brConf = FindName($"{pair}_BR_Conf") as TextBlock;
            var bestSignal = FindName($"{pair}_Best_Signal") as TextBlock;
            var bestConf = FindName($"{pair}_Best_Conf") as TextBlock;

            // Update Trend Rider
            if (trSignal != null)
            {
                trSignal.Text = signalData.TrendRiderSignal;
                trSignal.Foreground = GetSignalColor(signalData.TrendRiderSignal);
            }
            if (trConf != null)
                trConf.Text = $"{signalData.TrendRiderConfidence}%";

            // Update Impulse Pullback
            if (ipSignal != null)
            {
                ipSignal.Text = signalData.ImpulsePullbackSignal;
                ipSignal.Foreground = GetSignalColor(signalData.ImpulsePullbackSignal);
            }
            if (ipConf != null)
                ipConf.Text = $"{signalData.ImpulsePullbackConfidence}%";

            // Update Breakout Retest
            if (brSignal != null)
            {
                brSignal.Text = signalData.BreakoutRetestSignal;
                brSignal.Foreground = GetSignalColor(signalData.BreakoutRetestSignal);
            }
            if (brConf != null)
                brConf.Text = $"{signalData.BreakoutRetestConfidence}%";

            // Update Best Signal
            if (bestSignal != null)
            {
                bestSignal.Text = signalData.BestSignal;
                bestSignal.Foreground = GetSignalColor(signalData.BestSignal);
            }
            if (bestConf != null)
                bestConf.Text = $"{signalData.BestConfidence}%";
        }

        private SolidColorBrush GetSignalColor(string signal)
        {
            switch (signal?.ToUpper())
            {
                case "BUY":
                    return GetMutedBrush("Green");  // Was: LightGreen
                case "SELL":
                    return GetMutedBrush("Red");    // Was: LightCoral
                case "HOLD":
                default:
                    return GetMutedBrush("Gray");   // Was: LightGray
            }
        }

        private void LoadAccountInfo()
        {
            string perfFile = IOPath.Combine(csmDataPath, "performance.txt");
            string posFile = IOPath.Combine(csmDataPath, "positions.txt");

            double balance = 0;
            bool autoTradingActive = false;
            int activePositions = 0;

            // Read performance file for balance
            if (File.Exists(perfFile))
            {
                try
                {
                    var lines = File.ReadAllLines(perfFile);
                    foreach (var line in lines)
                    {
                        if (line.Contains("BALANCE="))
                        {
                            string value = line.Split('=')[1].Trim();
                            double.TryParse(value, out balance);
                        }
                        else if (line.Contains("AUTO_TRADING="))
                        {
                            string value = line.Split('=')[1].Trim();
                            autoTradingActive = value.ToUpper() == "TRUE" || value == "1";
                        }
                    }
                }
                catch { }
            }

            // Parse positions file
            var positionsList = new List<PositionDisplay>();

            if (File.Exists(posFile))
            {
                try
                {
                    var lines = File.ReadAllLines(posFile);
                    foreach (var line in lines)
                    {
                        if (line.StartsWith("POSITION="))
                        {
                            // Format: POSITION=ticket|symbol|strategy|type|entry|current|sl|tp|lots|profit|time
                            string data = line.Substring(9); // Remove "POSITION="
                            string[] parts = data.Split('|');

                            if (parts.Length >= 11)
                            {
                                var pos = new PositionDisplay
                                {
                                    Ticket = parts[0],
                                    Symbol = parts[1],
                                    Strategy = parts[2],
                                    Type = parts[3],
                                    EntryPrice = parts[4],
                                    CurrentPrice = parts[5],
                                    StopLoss = parts[6],
                                    TakeProfit = parts[7],
                                    Size = parts[8],
                                    PnL = parts[9],
                                    EntryTime = parts[10]
                                };

                                // Calculate R-Multiple (if SL exists)
                                if (double.TryParse(parts[4], out double entry) &&
                                    double.TryParse(parts[6], out double sl) &&
                                    double.TryParse(parts[9], out double profit))
                                {
                                    double risk = Math.Abs(entry - sl);
                                    if (risk > 0)
                                    {
                                        double rMultiple = profit / risk;
                                        pos.RMultiple = rMultiple.ToString("F2") + "R";
                                    }
                                    else
                                    {
                                        pos.RMultiple = "N/A";
                                    }
                                }
                                else
                                {
                                    pos.RMultiple = "N/A";
                                }

                                // Risk amount (not in file, calculate or use N/A)
                                pos.Risk = "N/A";

                                positionsList.Add(pos);
                                activePositions++;
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error parsing positions: {ex.Message}");
                }
            }

            // Update UI
            Dispatcher.Invoke(() =>
            {
                AccountBalanceText.Text = balance.ToString("F2");
                ActiveTradesText.Text = activePositions.ToString();

                // Update the DataGrid
                ActivePositionsGrid.ItemsSource = null;
                ActivePositionsGrid.ItemsSource = positionsList;

                if (autoTradingActive)
                {
                    TradingIndicator.Fill = new SolidColorBrush(Colors.LightGreen);
                }
                else
                {
                    TradingIndicator.Fill = new SolidColorBrush(Colors.Gray);
                }
            });
        }

        private void RefreshButton_Click(object sender, RoutedEventArgs e)
        {
            UpdateDisplay();
        }

        private void SettingsButton_Click(object sender, RoutedEventArgs e)
        {
            MessageBox.Show("Settings functionality coming soon!", "Settings",
                          MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void BrowseButton_Click(object sender, RoutedEventArgs e)
        {
            // Validate the current path
            string pathToValidate = MT5PathTextBox?.Text ?? csmDataPath;

            if (string.IsNullOrWhiteSpace(pathToValidate))
            {
                MessageBox.Show("Please enter a path to validate.", "Validation",
                               MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (Directory.Exists(pathToValidate))
            {
                // Check for required files
                string csmFile = IOPath.Combine(pathToValidate, "csm_current.txt");
                bool hasCSM = File.Exists(csmFile);

                // CSM Alpha: Signal files are in CSM_Signals folder (sibling to CSM_Data)
                string signalPath = pathToValidate.Replace("CSM_Data", "CSM_Signals");

                // CSM Alpha: 4 assets with broker suffix mapping
                var pairMappings = new Dictionary<string, string>
                {
                    ["EURUSD"] = "EURUSD.sml",
                    ["GBPUSD"] = "GBPUSD.sml",
                    ["AUDJPY"] = "AUDJPY",
                    ["XAUUSD"] = "XAUUSD.sml"
                };

                int jsonFilesFound = 0;
                int txtFilesFound = 0;

                foreach (var kvp in pairMappings)
                {
                    string filePair = kvp.Value;
                    if (File.Exists(IOPath.Combine(signalPath, $"{filePair}_signals.json")))
                        jsonFilesFound++;
                    if (File.Exists(IOPath.Combine(signalPath, $"{filePair}_signals.txt")))
                        txtFilesFound++;
                }

                string result = $"✓ Directory exists\n" +
                               $"✓ CSM file: {(hasCSM ? "Found" : "Not found")}\n" +
                               $"✓ JSON signal files: {jsonFilesFound}/4 found (CSM Alpha)\n" +
                               $"✓ TXT signal files: {txtFilesFound}/4 found\n\n" +
                               (hasCSM && (jsonFilesFound > 0 || txtFilesFound > 0) ?
                                "Path is valid!" :
                                "Path exists but missing data files.");

                MessageBox.Show(result, "Path Validation",
                               MessageBoxButton.OK,
                               hasCSM ? MessageBoxImage.Information : MessageBoxImage.Warning);

                if (hasCSM)
                {
                    csmDataPath = pathToValidate;
                    ConnectionStatus.Text = "Connected";
                    // Reinitialize trade history manager with new path
                    try
                    {
                        tradeHistoryManager = new TradeHistoryManager(csmDataPath);
                        tradeHistoryManager.TradesUpdated += (s, e) =>
                        {
                            Dispatcher.Invoke(() => UpdatePerformanceMetrics());
                        };
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine($"Failed to reinitialize Trade History Manager: {ex.Message}");
                    }

                    ConnectionIndicator.Fill = new SolidColorBrush(Colors.Green);
                    UpdateDisplay();
                }
            }
            else
            {
                MessageBox.Show($"❌ Directory does not exist:\n{pathToValidate}\n\n" +
                               "Please check the path and try again.",
                               "Invalid Path",
                               MessageBoxButton.OK, MessageBoxImage.Error);

                ConnectionStatus.Text = "Invalid Path";
                ConnectionIndicator.Fill = new SolidColorBrush(Colors.Red);
            }
        }

        private void SaveSettingsButton_Click(object sender, RoutedEventArgs e)
        {
            MessageBox.Show("Settings saved successfully!", "Settings",
                          MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void ResetSettingsButton_Click(object sender, RoutedEventArgs e)
        {
            var result = MessageBox.Show("Reset all settings to default values?", "Confirm Reset",
                                       MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (result == MessageBoxResult.Yes)
            {
                MessageBox.Show("Settings reset to defaults!", "Settings Reset",
                              MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void ExportDataButton_Click(object sender, RoutedEventArgs e)
        {
            if (tradeHistoryManager == null)
            {
                MessageBox.Show("No trade history available to export.", "Export",
                              MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var dialog = new Microsoft.Win32.SaveFileDialog();
            dialog.DefaultExt = ".csv";
            dialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*";
            dialog.FileName = $"ACSTS_TradeHistory_{DateTime.Now:yyyyMMdd}.csv";

            bool? result = dialog.ShowDialog();
            if (result == true)
            {
                try
                {
                    bool success = tradeHistoryManager.ExportToCSV(dialog.FileName);

                    if (success)
                    {
                        MessageBox.Show($"Trade history exported successfully to:\n{dialog.FileName}",
                                      "Export Complete",
                                      MessageBoxButton.OK,
                                      MessageBoxImage.Information);
                    }
                    else
                    {
                        MessageBox.Show("Export failed. Check the debug log for details.",
                                      "Export Error",
                                      MessageBoxButton.OK,
                                      MessageBoxImage.Error);
                    }
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Export failed: {ex.Message}", "Export Error",
                                  MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void BacktestButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var backtestWindow = new BacktestWindow();
                backtestWindow.Show();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to open backtest window: {ex.Message}",
                              "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void AboutButton_Click(object sender, RoutedEventArgs e)
        {
            string aboutText = "Advanced Currency Strength Trading System (ACSTS)\n" +
                             "Professional Trading Monitor v2.0 (JSON Support)\n\n" +
                             "Features:\n" +
                             "• Real-time Currency Strength Meter\n" +
                             "• Multi-strategy signal analysis\n" +
                             "• JSON & TXT format support\n" +
                             "• Risk management monitoring\n" +
                             "• Performance tracking\n\n" +
                             "© 2025 ACSTS Professional Trading System";

            MessageBox.Show(aboutText, "About ACSTS Monitor",
                          MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void BrowsePathButton_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new Microsoft.Win32.OpenFileDialog();
            dialog.Title = "Select any file in the CSM_Data folder";
            dialog.Filter = "Data files (*.txt;*.json)|*.txt;*.json|All files (*.*)|*.*";
            dialog.CheckFileExists = false;
            dialog.CheckPathExists = true;

            bool? result = dialog.ShowDialog();
            if (result == true)
            {
                string selectedDirectory = System.IO.Path.GetDirectoryName(dialog.FileName);
                MT5PathTextBox.Text = selectedDirectory;
            }
        }

        private void ExportCSMDataToCSV(string fileName)
        {
            using (var writer = new StreamWriter(fileName))
            {
                writer.WriteLine("Currency,Strength,Timestamp");

                foreach (var kvp in currencyStrengths)
                {
                    writer.WriteLine($"{kvp.Key},{kvp.Value:F2},{DateTime.Now:yyyy-MM-dd HH:mm:ss}");
                }

                writer.WriteLine();
                writer.WriteLine("Pair,Signal,Confidence");

                foreach (var kvp in pairSignals)
                {
                    var signal = kvp.Value;
                    writer.WriteLine($"{kvp.Key} TR,{signal.TrendRiderSignal},{signal.TrendRiderConfidence}");
                    writer.WriteLine($"{kvp.Key} IP,{signal.ImpulsePullbackSignal},{signal.ImpulsePullbackConfidence}");
                    writer.WriteLine($"{kvp.Key} BR,{signal.BreakoutRetestSignal},{signal.BreakoutRetestConfidence}");
                }
            }
        }

        private void UpdateStrategyDetails(string pair)
        {
            // ═══════════════════════════════════════════════════════════
            // SAFETY: Check for null before accessing
            // ═══════════════════════════════════════════════════════════
            if (pairSignals == null)
            {
                System.Diagnostics.Debug.WriteLine($"⚠ pairSignals is null - cannot update strategy details for {pair}");
                return;
            }

            if (!pairSignals.ContainsKey(pair))
                return;

            var signalData = pairSignals[pair];

            // Update Trend Rider Details
            UpdateStrategySection(pair, "TR",
                signalData.TrendRiderSignal,
                signalData.TrendRiderConfidence,
                signalData.TrendRiderScores,
                signalData.TrendRiderReasoning,
                new string[] { "EMA_ALIGN", "ADX", "RSI", "CSM" },
                new int[] { 35, 25, 20, 25 });

            // Update Impulse Pullback Details
            UpdateStrategySection(pair, "IP",
                signalData.ImpulsePullbackSignal,
                signalData.ImpulsePullbackConfidence,
                signalData.ImpulsePullbackScores,
                signalData.ImpulsePullbackReasoning,
                new string[] { "IMPULSE", "FIB", "RSI", "CSM" },
                new int[] { 35, 25, 20, 20 });

            // Update Breakout Retest Details
            UpdateStrategySection(pair, "BR",
                signalData.BreakoutRetestSignal,
                signalData.BreakoutRetestConfidence,
                signalData.BreakoutRetestScores,
                signalData.BreakoutRetestReasoning,
                new string[] { "LEVEL", "BREAKOUT", "VOLUME", "CSM" },
                new int[] { 30, 25, 25, 20 });
        }

        private void UpdateStrategySection(string pair, string strategy, string signal,
            int confidence, Dictionary<string, int> scores, string reasoning,
            string[] scoreKeys, int[] maxValues)
        {
            // Update details text
            var detailsText = FindName($"{pair}_{strategy}_Details") as TextBlock;
            if (detailsText != null)
            {
                detailsText.Text = $"Signal: {signal} ({confidence}%)";
                detailsText.Foreground = GetSignalColor(signal);
            }

            // Update progress bars based on strategy type
            if (strategy == "TR")
            {
                UpdateProgressBar($"{pair}_TR_EMA", scores.ContainsKey("EMA_ALIGN") ? scores["EMA_ALIGN"] : 0, maxValues[0]);
                UpdateProgressBar($"{pair}_TR_ADX", scores.ContainsKey("ADX") ? scores["ADX"] : 0, maxValues[1]);
                UpdateProgressBar($"{pair}_TR_RSI", scores.ContainsKey("RSI") ? scores["RSI"] : 0, maxValues[2]);
                UpdateProgressBar($"{pair}_TR_CSM", scores.ContainsKey("CSM") ? scores["CSM"] : 0, maxValues[3]);
            }
            else if (strategy == "IP")
            {
                UpdateProgressBar($"{pair}_IP_Impulse", scores.ContainsKey("IMPULSE") ? scores["IMPULSE"] : 0, maxValues[0]);
                UpdateProgressBar($"{pair}_IP_Fib", scores.ContainsKey("FIB") ? scores["FIB"] : 0, maxValues[1]);
                UpdateProgressBar($"{pair}_IP_RSI", scores.ContainsKey("RSI") ? scores["RSI"] : 0, maxValues[2]);
                UpdateProgressBar($"{pair}_IP_CSM", scores.ContainsKey("CSM") ? scores["CSM"] : 0, maxValues[3]);
            }
            else if (strategy == "BR")
            {
                UpdateProgressBar($"{pair}_BR_Level", scores.ContainsKey("LEVEL") ? scores["LEVEL"] : 0, maxValues[0]);
                UpdateProgressBar($"{pair}_BR_Breakout", scores.ContainsKey("BREAKOUT") ? scores["BREAKOUT"] : 0, maxValues[1]);
                UpdateProgressBar($"{pair}_BR_Volume", scores.ContainsKey("VOLUME") ? scores["VOLUME"] : 0, maxValues[2]);
                UpdateProgressBar($"{pair}_BR_CSM", scores.ContainsKey("CSM") ? scores["CSM"] : 0, maxValues[3]);
            }

            // Update reasoning text
            var reasoningText = FindName($"{pair}_{strategy}_Reasoning") as TextBlock;
            if (reasoningText != null)
            {
                reasoningText.Text = $"Reasoning: {reasoning}";
            }
        }

        private void UpdateProgressBar(string name, int value, int maximum)
        {
            var progressBar = FindName(name) as ProgressBar;
            if (progressBar != null)
            {
                progressBar.Maximum = maximum;
                progressBar.Value = value;

                double percentage = maximum > 0 ? (double)value / maximum * 100 : 0;

                if (percentage >= 80)
                    progressBar.Foreground = GetMutedBrush("Green");      // Was: LightGreen
                else if (percentage >= 50)
                    progressBar.Foreground = GetMutedBrush("Yellow");     // Was: Yellow
                else if (percentage >= 25)
                    progressBar.Foreground = GetMutedBrush("Orange");     // Was: Orange
                else
                    progressBar.Foreground = GetMutedBrush("Red");        // Was: Red
            }
        }
        // ═══════════════════════════════════════════════════════════
        // NEW: COLOR SETTINGS EVENT HANDLERS
        // ═══════════════════════════════════════════════════════════

        /// <summary>
        /// Handles color intensity slider changes
        /// </summary>
        private void ColorIntensitySlider_ValueChanged(object sender,
                                                       RoutedPropertyChangedEventArgs<double> e)
        {
            // Prevent execution during initialization
            if (ColorIntensityValue == null) return;

            colorIntensity = e.NewValue;

            // Update display text
            ColorIntensityValue.Text = $"{(int)(colorIntensity * 100)}%";

            System.Diagnostics.Debug.WriteLine($"Color intensity changed to: {colorIntensity:F2}");

            // Update preview panels
            UpdateColorPreview();

            // Refresh all colors in the UI
            UpdateAllColors();
        }

        /// <summary>
        /// Handles color scheme preset selection
        /// </summary>
        private void ColorSchemeComboBox_SelectionChanged(object sender,
                                                          SelectionChangedEventArgs e)
        {
            if (ColorSchemeComboBox.SelectedIndex == -1) return;
            if (ColorIntensitySlider == null) return;  // Prevent execution during init

            var selected = (ColorSchemeComboBox.SelectedItem as ComboBoxItem)?.Content.ToString();

            System.Diagnostics.Debug.WriteLine($"Color scheme changed to: {selected}");

            switch (selected)
            {
                case "Muted Dark (Recommended)":
                    colorIntensity = 0.6;
                    System.Diagnostics.Debug.WriteLine("→ Applied Muted Dark preset (60%)");
                    break;

                case "Standard Dark":
                    colorIntensity = 0.8;
                    System.Diagnostics.Debug.WriteLine("→ Applied Standard Dark preset (80%)");
                    break;

                case "High Contrast":
                    colorIntensity = 1.0;
                    System.Diagnostics.Debug.WriteLine("→ Applied High Contrast preset (100%)");
                    break;

                case "Soft Monochrome":
                    colorIntensity = 0.4;
                    System.Diagnostics.Debug.WriteLine("→ Applied Soft Monochrome preset (40%)");
                    break;

                case "Deep Blue":
                    colorIntensity = 0.7;
                    System.Diagnostics.Debug.WriteLine("→ Applied Deep Blue preset (70%)");
                    break;
            }

            // Update slider to match
            ColorIntensitySlider.Value = colorIntensity;

            // Update preview and all UI colors
            UpdateColorPreview();
            UpdateAllColors();
        }

        /// <summary>
        /// Updates the color preview panel in settings
        /// </summary>
        private void UpdateColorPreview()
        {
            if (PreviewBuyBorder == null || PreviewSellBorder == null || PreviewHoldBorder == null)
                return;

            // Update preview borders with current intensity
            PreviewBuyBorder.Background = GetMutedBrush("Green");
            PreviewSellBorder.Background = GetMutedBrush("Red");
            PreviewHoldBorder.Background = GetMutedBrush("Yellow");

            if (PreviewProgressBar != null)
            {
                PreviewProgressBar.Foreground = GetMutedBrush("Green");
            }

            System.Diagnostics.Debug.WriteLine("✓ Color preview updated");
        }

        /// <summary>
        /// Refreshes all colors in the UI
        /// </summary>
        private void UpdateAllColors()
        {
            try
            {
                System.Diagnostics.Debug.WriteLine("=== Updating All UI Colors ===");

                // ═══════════════════════════════════════════════════════════
                // CRITICAL: Check if data structures are initialized
                // Event handlers can fire during XAML initialization
                // ═══════════════════════════════════════════════════════════
                if (pairSignals == null || currencyStrengths == null)
                {
                    System.Diagnostics.Debug.WriteLine("⚠ Data not initialized yet - skipping color update");
                    return;
                }

                // Refresh signal displays for all pairs
                UpdateSignalDisplay("EURUSD");
                UpdateSignalDisplay("GBPUSD");
                UpdateSignalDisplay("AUDJPY");
                UpdateSignalDisplay("XAUUSD");

                // Refresh strategy details for all pairs
                UpdateStrategyDetails("EURUSD");
                UpdateStrategyDetails("GBPUSD");
                UpdateStrategyDetails("AUDJPY");
                UpdateStrategyDetails("XAUUSD");

                // Refresh currency strength display
                UpdateCurrencyStrengthDisplay();

                // Refresh performance metrics if available
                if (tradeHistoryManager != null)
                {
                    UpdatePerformanceMetrics();
                }

                System.Diagnostics.Debug.WriteLine("✓ All colors updated successfully");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"❌ Error updating colors: {ex.Message}");
                System.Diagnostics.Debug.WriteLine($"   Stack: {ex.StackTrace}");
            }
        }
        private void UpdateStatusPanels()
        {
            if (pairSignals == null)
                return;

            try
            {
                // Update all 9 status panels
                UpdateStrategyStatusPanel("EURUSD", "TR", pairSignals["EURUSD"].TrendRiderSignal,
                                         pairSignals["EURUSD"].TrendRiderConfidence,
                                         pairSignals["EURUSD"].CsmDifferential);

                UpdateStrategyStatusPanel("EURUSD", "IP", pairSignals["EURUSD"].ImpulsePullbackSignal,
                                         pairSignals["EURUSD"].ImpulsePullbackConfidence,
                                         pairSignals["EURUSD"].CsmDifferential);

                UpdateStrategyStatusPanel("EURUSD", "BR", pairSignals["EURUSD"].BreakoutRetestSignal,
                                         pairSignals["EURUSD"].BreakoutRetestConfidence,
                                         pairSignals["EURUSD"].CsmDifferential);

                UpdateStrategyStatusPanel("GBPUSD", "TR", pairSignals["GBPUSD"].TrendRiderSignal,
                                         pairSignals["GBPUSD"].TrendRiderConfidence,
                                         pairSignals["GBPUSD"].CsmDifferential);

                UpdateStrategyStatusPanel("GBPUSD", "IP", pairSignals["GBPUSD"].ImpulsePullbackSignal,
                                         pairSignals["GBPUSD"].ImpulsePullbackConfidence,
                                         pairSignals["GBPUSD"].CsmDifferential);

                UpdateStrategyStatusPanel("GBPUSD", "BR", pairSignals["GBPUSD"].BreakoutRetestSignal,
                                         pairSignals["GBPUSD"].BreakoutRetestConfidence,
                                         pairSignals["GBPUSD"].CsmDifferential);

                UpdateStrategyStatusPanel("AUDJPY", "TR", pairSignals["AUDJPY"].TrendRiderSignal,
                                         pairSignals["AUDJPY"].TrendRiderConfidence,
                                         pairSignals["AUDJPY"].CsmDifferential);

                UpdateStrategyStatusPanel("AUDJPY", "IP", pairSignals["AUDJPY"].ImpulsePullbackSignal,
                                         pairSignals["AUDJPY"].ImpulsePullbackConfidence,
                                         pairSignals["AUDJPY"].CsmDifferential);

                UpdateStrategyStatusPanel("AUDJPY", "BR", pairSignals["AUDJPY"].BreakoutRetestSignal,
                                         pairSignals["AUDJPY"].BreakoutRetestConfidence,
                                         pairSignals["AUDJPY"].CsmDifferential);

                UpdateStrategyStatusPanel("XAUUSD", "TR", pairSignals["XAUUSD"].TrendRiderSignal,
                                         pairSignals["XAUUSD"].TrendRiderConfidence,
                                         pairSignals["XAUUSD"].CsmDifferential);

                UpdateStrategyStatusPanel("XAUUSD", "IP", pairSignals["XAUUSD"].ImpulsePullbackSignal,
                                         pairSignals["XAUUSD"].ImpulsePullbackConfidence,
                                         pairSignals["XAUUSD"].CsmDifferential);

                UpdateStrategyStatusPanel("XAUUSD", "BR", pairSignals["XAUUSD"].BreakoutRetestSignal,
                                         pairSignals["XAUUSD"].BreakoutRetestConfidence,
                                         pairSignals["XAUUSD"].CsmDifferential);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error updating status panels: {ex.Message}");
            }
        }

        // ================================================================
        // CORE LOGIC - Updates a single strategy status panel
        // ================================================================

        private void UpdateStrategyStatusPanel(string pair, string strategy, string signal,
                                               int confidence, double csmDifferential)
        {
            try
            {
                // Find all controls for this panel
                var statusIndicator = FindName($"{pair}_{strategy}_StatusIndicator") as Ellipse;
                var statusText = FindName($"{pair}_{strategy}_StatusText") as TextBlock;
                var confidenceValue = FindName($"{pair}_{strategy}_ConfidenceValue") as TextBlock;
                var confidenceBar = FindName($"{pair}_{strategy}_ConfidenceBar") as ProgressBar;
                var confidencePercent = FindName($"{pair}_{strategy}_ConfidencePercent") as TextBlock;
                var csmDiffValue = FindName($"{pair}_{strategy}_CsmDiffValue") as TextBlock;
                var csmDiffBar = FindName($"{pair}_{strategy}_CsmDiffBar") as ProgressBar;
                var csmDiffPercent = FindName($"{pair}_{strategy}_CsmDiffPercent") as TextBlock;
                var blockingReason = FindName($"{pair}_{strategy}_BlockingReason") as TextBlock;
                var needsText = FindName($"{pair}_{strategy}_NeedsText") as TextBlock;
                var statusPanel = FindName($"{pair}_{strategy}_StatusPanel") as Border;

                // Null check
                if (statusIndicator == null || statusText == null || confidenceValue == null ||
                    confidenceBar == null || confidencePercent == null || csmDiffValue == null ||
                    csmDiffBar == null || csmDiffPercent == null || blockingReason == null ||
                    needsText == null || statusPanel == null)
                {
                    System.Diagnostics.Debug.WriteLine($"⚠ Status panel controls not found for {pair}_{strategy}");
                    return;
                }

                // Calculate percentages (how close to threshold)
                double confidencePercentage = (confidence / MIN_CONFIDENCE_THRESHOLD) * 100.0;
                double csmDiffPercentage = (Math.Abs(csmDifferential) / MIN_CSM_DIFFERENTIAL) * 100.0;

                // Cap at 100%
                confidencePercentage = Math.Min(confidencePercentage, 100.0);
                csmDiffPercentage = Math.Min(csmDiffPercentage, 100.0);

                // Determine overall status (lowest percentage is the blocker)
                double overallPercentage = Math.Min(confidencePercentage, csmDiffPercentage);
                bool confidenceBlocking = confidencePercentage < csmDiffPercentage;

                // Update confidence row
                confidenceValue.Text = $"{confidence}% / {MIN_CONFIDENCE_THRESHOLD:F0}%";
                confidenceBar.Value = confidencePercentage;
                confidencePercent.Text = $"{confidencePercentage:F0}%";

                // Update CSM differential row
                csmDiffValue.Text = $"{Math.Abs(csmDifferential):F1} / {MIN_CSM_DIFFERENTIAL:F1}";
                csmDiffBar.Value = csmDiffPercentage;
                csmDiffPercent.Text = $"{csmDiffPercentage:F0}%";

                // Color code progress bars based on percentage
                confidenceBar.Foreground = GetProgressBarColor(confidencePercentage);
                csmDiffBar.Foreground = GetProgressBarColor(csmDiffPercentage);

                // Determine status based on signal
                if (signal == "BUY" || signal == "SELL")
                {
                    // READY TO TRADE
                    statusIndicator.Fill = new SolidColorBrush(Color.FromRgb(0x4A, 0x6F, 0x4A)); // Green
                    statusText.Text = $"READY - {signal} Signal Active";
                    statusText.Foreground = new SolidColorBrush(Color.FromRgb(0x4A, 0x6F, 0x4A));
                    statusPanel.BorderBrush = new SolidColorBrush(Color.FromRgb(0x4A, 0x6F, 0x4A));

                    blockingReason.Text = $"✓ All requirements met - {signal} signal generated";
                    blockingReason.Foreground = new SolidColorBrush(Color.FromRgb(0x4A, 0x6F, 0x4A));

                    needsText.Text = "📊 Ready for trade execution";
                    needsText.Foreground = new SolidColorBrush(Color.FromRgb(0x4A, 0x6F, 0x4A));
                }
                else
                {
                    // HOLDING - Determine why

                    // Set indicator color based on overall progress
                    if (overallPercentage >= 80)
                    {
                        // CLOSE to signal - Yellow
                        statusIndicator.Fill = new SolidColorBrush(Color.FromRgb(0x7A, 0x7A, 0x4A));
                        statusText.Text = "WAITING - Close to Signal";
                        statusPanel.BorderBrush = new SolidColorBrush(Color.FromRgb(0x7A, 0x7A, 0x4A));
                    }
                    else if (overallPercentage >= 50)
                    {
                        // MODERATE progress - Orange
                        statusIndicator.Fill = new SolidColorBrush(Color.FromRgb(0x7A, 0x5A, 0x4A));
                        statusText.Text = "HOLDING - Moderate Progress";
                        statusPanel.BorderBrush = new SolidColorBrush(Color.FromRgb(0x7A, 0x5A, 0x4A));
                    }
                    else
                    {
                        // FAR from signal - Red
                        statusIndicator.Fill = new SolidColorBrush(Color.FromRgb(0x7A, 0x4A, 0x4A));
                        statusText.Text = "HOLDING - Requirements Not Met";
                        statusPanel.BorderBrush = new SolidColorBrush(Color.FromRgb(0x7A, 0x4A, 0x4A));
                    }

                    statusText.Foreground = new SolidColorBrush(Color.FromRgb(0xCC, 0xCC, 0xCC));

                    // Determine primary blocker
                    if (confidence < MIN_CONFIDENCE_THRESHOLD && Math.Abs(csmDifferential) < MIN_CSM_DIFFERENTIAL)
                    {
                        // BOTH blocking
                        if (confidenceBlocking)
                        {
                            blockingReason.Text = $"⚠️ BLOCKING: Confidence too low (primary), CSM also insufficient";

                            double confidenceNeeded = MIN_CONFIDENCE_THRESHOLD - confidence;
                            double csmNeeded = MIN_CSM_DIFFERENTIAL - Math.Abs(csmDifferential);
                            needsText.Text = $"📊 NEEDS: {confidenceNeeded:F0}% more confidence, {csmNeeded:F1} CSM points";
                        }
                        else
                        {
                            blockingReason.Text = $"⚠️ BLOCKING: CSM differential too low (primary), confidence also insufficient";

                            double csmNeeded = MIN_CSM_DIFFERENTIAL - Math.Abs(csmDifferential);
                            double confidenceNeeded = MIN_CONFIDENCE_THRESHOLD - confidence;
                            needsText.Text = $"📊 NEEDS: {csmNeeded:F1} CSM points, {confidenceNeeded:F0}% confidence";
                        }
                    }
                    else if (confidence < MIN_CONFIDENCE_THRESHOLD)
                    {
                        // ONLY confidence blocking
                        blockingReason.Text = $"⚠️ BLOCKING: Confidence below threshold ({MIN_CONFIDENCE_THRESHOLD:F0}%)";

                        double confidenceNeeded = MIN_CONFIDENCE_THRESHOLD - confidence;
                        needsText.Text = $"📊 NEEDS: {confidenceNeeded:F0}% more confidence to meet threshold";
                    }
                    else if (Math.Abs(csmDifferential) < MIN_CSM_DIFFERENTIAL)
                    {
                        // ONLY CSM blocking
                        blockingReason.Text = $"⚠️ BLOCKING: CSM differential below threshold ({MIN_CSM_DIFFERENTIAL:F1})";

                        double csmNeeded = MIN_CSM_DIFFERENTIAL - Math.Abs(csmDifferential);
                        needsText.Text = $"📊 NEEDS: {csmNeeded:F1} more CSM points to meet threshold";
                    }
                    else
                    {
                        // Requirements met but no signal (shouldn't happen, but handle it)
                        blockingReason.Text = "⚠️ Thresholds met - Waiting for technical confirmation";
                        needsText.Text = "📊 Monitoring for entry opportunity";
                    }

                    // Keep blocking reason in orange
                    blockingReason.Foreground = new SolidColorBrush(Color.FromRgb(0xFF, 0x98, 0x00));
                    needsText.Foreground = new SolidColorBrush(Color.FromRgb(0x88, 0x88, 0x88));
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error updating {pair}_{strategy} status panel: {ex.Message}");
            }
        }

        // ================================================================
        // HELPER METHOD - Get color based on percentage
        // ================================================================

        private SolidColorBrush GetProgressBarColor(double percentage)
        {
            if (percentage >= 80)
                return new SolidColorBrush(Color.FromRgb(0x4A, 0x6F, 0x4A)); // Green - Close
            else if (percentage >= 50)
                return new SolidColorBrush(Color.FromRgb(0x7A, 0x7A, 0x4A)); // Yellow - Moderate
            else if (percentage >= 25)
                return new SolidColorBrush(Color.FromRgb(0x7A, 0x5A, 0x4A)); // Orange - Low
            else
                return new SolidColorBrush(Color.FromRgb(0x7A, 0x4A, 0x4A)); // Red - Very Low
        }
    }
}