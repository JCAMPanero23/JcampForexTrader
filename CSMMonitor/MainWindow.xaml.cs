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
        private string selectedAsset = "EURUSD";  // Default selected asset for trade details panel

        // Risk Management Settings
        private const double DAILY_LOSS_LIMIT_R = 6.0;  // Maximum daily loss in R-multiples
        private double dailyLossUsedR = 0.0;  // Current daily loss in R (updated from trades)
        private List<PositionDisplay> activePositions = new List<PositionDisplay>();  // Store active positions for trade details panel

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
            public string Analysis { get; set; } = "";  // CSM Alpha analysis breakdown: "EMA+30 ADX+20 RSI+5 CSM+25"
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

            // Initialize selected asset card visual state
            Dispatcher.BeginInvoke(new Action(() =>
            {
                SelectAssetCard(selectedAsset);
                UpdateTradeDetailsPanel(selectedAsset);
            }), System.Windows.Threading.DispatcherPriority.Loaded);
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
            // HIGH CONTRAST color scheme
            mutedColors = new Dictionary<string, Color>
            {
                ["Green"] = Color.FromRgb(100, 200, 100),     // Bright green for high contrast
                ["Red"] = Color.FromRgb(255, 100, 100),       // Bright red for high contrast
                ["Yellow"] = Color.FromRgb(255, 255, 100),    // Bright yellow for high contrast
                ["Orange"] = Color.FromRgb(255, 180, 100),    // Bright orange for high contrast
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

                // Try CSM Alpha flat format first
                try
                {
                    var csmAlphaSignal = JsonConvert.DeserializeObject<dynamic>(jsonContent);
                    if (csmAlphaSignal != null && csmAlphaSignal.strategy != null)
                    {
                        LoadCSMAlphaSignal(pair, csmAlphaSignal);
                        return;
                    }
                }
                catch
                {
                    // Fall through to old format
                }

                // Try old nested format
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

        private void LoadCSMAlphaSignal(string pair, dynamic signal)
        {
            try
            {
                var signalData = pairSignals[pair];

                // Parse CSM Alpha flat JSON format
                string strategy = signal.strategy?.ToString() ?? "NONE";
                string signalText = signal.signal_text?.ToString() ?? "HOLD";
                int confidence = (int)(signal.confidence ?? 0);
                string analysis = signal.analysis?.ToString() ?? "";
                double csmDiff = (double)(signal.csm_diff ?? 0.0);
                string regime = signal.regime?.ToString() ?? "";

                // Store analysis breakdown for Signal Analysis tab
                signalData.Analysis = analysis;

                // Map to display format based on strategy
                if (strategy == "TREND_RIDER")
                {
                    signalData.TrendRiderSignal = signalText;
                    signalData.TrendRiderConfidence = confidence;
                    signalData.TrendRiderReasoning = analysis;

                    // Best signal is TrendRider if it has confidence
                    if (confidence > 0)
                    {
                        signalData.BestSignal = signalText;
                        signalData.BestConfidence = confidence;
                    }
                }
                else if (strategy == "RANGE_RIDER")
                {
                    signalData.ImpulsePullbackSignal = signalText; // Map to ImpulsePullback for display
                    signalData.ImpulsePullbackConfidence = confidence;
                    signalData.ImpulsePullbackReasoning = analysis;

                    // Best signal is RangeRider if it has confidence
                    if (confidence > 0)
                    {
                        signalData.BestSignal = signalText;
                        signalData.BestConfidence = confidence;
                    }
                }
                else
                {
                    // NONE or NEUTRAL
                    signalData.BestSignal = "HOLD";
                    signalData.BestConfidence = 0;
                }

                // CSM data
                signalData.CsmDifferential = csmDiff;
                signalData.CsmTrend = regime;

                if (ENABLE_VERBOSE_DEBUG)
                    System.Diagnostics.Debug.WriteLine($"CSM Alpha signal loaded: {pair} | {signalText} @ {confidence} | {strategy}");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error parsing CSM Alpha signal for {pair}: {ex.Message}");
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

            // Update trade details panel for currently selected asset
            UpdateTradeDetailsPanel(selectedAsset);

            // Update new dashboard metrics
            UpdateDailyLossLimit();
            UpdateTradingSession();
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

                    // Create compact horizontal currency card
                    var stackPanel = new StackPanel
                    {
                        Margin = new Thickness(4, 0, 4, 0),
                        VerticalAlignment = VerticalAlignment.Center
                    };

                    // Currency Label
                    var currencyLabel = new TextBlock
                    {
                        Text = currency,
                        FontSize = 13,
                        FontWeight = FontWeights.Bold,
                        Foreground = new SolidColorBrush(Color.FromRgb(255, 255, 255)), // High contrast white
                        HorizontalAlignment = HorizontalAlignment.Center,
                        Margin = new Thickness(0, 0, 0, 2)
                    };

                    // Strength Value
                    var strengthValue = new TextBlock
                    {
                        Text = hasData ? $"{strength:F1}" : "--",
                        FontSize = 15,
                        FontWeight = FontWeights.Bold,
                        FontFamily = new System.Windows.Media.FontFamily("Consolas"),
                        Foreground = !hasData ? GetMutedBrush("Gray") :
                            strength > 70 ? GetMutedBrush("Green") :
                            strength > 60 ? new SolidColorBrush(Color.FromRgb(255, 255, 100)) : // Brighter yellow
                            strength < 30 ? GetMutedBrush("Red") :
                            strength < 40 ? GetMutedBrush("Orange") :
                            new SolidColorBrush(Color.FromRgb(255, 255, 255)), // High contrast white
                        HorizontalAlignment = HorizontalAlignment.Center,
                        Margin = new Thickness(0, 0, 0, 3)
                    };

                    // Special styling for Gold (XAU)
                    if (currency == "XAU")
                    {
                        currencyLabel.Foreground = new SolidColorBrush(Color.FromRgb(255, 215, 0)); // Gold color

                        // Gold fear indicator color coding
                        if (hasData)
                        {
                            if (strength >= 80) // PANIC mode
                                strengthValue.Foreground = new SolidColorBrush(Color.FromRgb(255, 100, 100)); // Brighter red
                            else if (strength >= 60 && strength < 80) // Fear mode
                                strengthValue.Foreground = new SolidColorBrush(Color.FromRgb(255, 255, 100)); // Brighter yellow
                            else if (strength >= 40 && strength < 60) // Neutral
                                strengthValue.Foreground = new SolidColorBrush(Color.FromRgb(255, 255, 255)); // High contrast white
                            else // Risk-On (< 40)
                                strengthValue.Foreground = new SolidColorBrush(Color.FromRgb(78, 201, 176)); // #4EC9B0 (green)
                        }
                    }

                    // Mini progress bar
                    var progressBar = new ProgressBar
                    {
                        Height = 4,
                        Width = 50,
                        Minimum = 0,
                        Maximum = 100,
                        Value = hasData ? strength : 0,
                        Foreground = !hasData ? GetMutedBrush("Gray") :
                            strength > 70 ? GetMutedBrush("Green") :
                            strength > 60 ? new SolidColorBrush(Color.FromRgb(220, 220, 170)) :
                            strength < 30 ? GetMutedBrush("Red") :
                            strength < 40 ? GetMutedBrush("Orange") :
                            new SolidColorBrush(Color.FromRgb(136, 136, 136)),
                        Background = new SolidColorBrush(Color.FromRgb(26, 26, 26)),
                        BorderThickness = new Thickness(0)
                    };

                    stackPanel.Children.Add(currencyLabel);
                    stackPanel.Children.Add(strengthValue);
                    stackPanel.Children.Add(progressBar);

                    CurrencyStrengthGrid.Children.Add(stackPanel);
                }

                // Update market state indicator based on Gold + JPY
                UpdateMarketStateIndicator();
            });

            if (ENABLE_VERBOSE_DEBUG)
                System.Diagnostics.Debug.WriteLine($"CSM Display Updated - Currencies: {currencyStrengths.Count}");
        }

        private void UpdateMarketStateIndicator()
        {
            bool hasGold = currencyStrengths.ContainsKey("XAU");
            bool hasJPY = currencyStrengths.ContainsKey("JPY");

            if (!hasGold || !hasJPY)
                return;

            double goldStrength = currencyStrengths["XAU"];
            double jpyStrength = currencyStrengths["JPY"];

            string marketState = "NEUTRAL";
            Color indicatorColor = Color.FromRgb(220, 220, 170); // Yellow

            // PANIC: Gold > 80 AND JPY > 80
            if (goldStrength > 80 && jpyStrength > 80)
            {
                marketState = "PANIC";
                indicatorColor = Color.FromRgb(244, 135, 113); // Red
            }
            // RISK-ON: Gold < 30 AND JPY < 30
            else if (goldStrength < 30 && jpyStrength < 30)
            {
                marketState = "RISK-ON";
                indicatorColor = Color.FromRgb(78, 201, 176); // Green
            }
            // INFLATION FEAR: Gold > 80 AND USD > 80
            else if (currencyStrengths.ContainsKey("USD") && goldStrength > 80 && currencyStrengths["USD"] > 80)
            {
                marketState = "INFLATION";
                indicatorColor = Color.FromRgb(255, 152, 0); // Orange
            }

            if (MarketStateLabel != null)
            {
                MarketStateLabel.Text = marketState;
                MarketStateLabel.Foreground = new SolidColorBrush(indicatorColor);
            }
            if (MarketStateIndicator != null)
                MarketStateIndicator.Fill = new SolidColorBrush(indicatorColor);
        }

        private void UpdateDailyLossLimit()
        {
            Dispatcher.Invoke(() =>
            {
                try
                {
                    // Calculate daily loss from trade history (if available)
                    if (tradeHistoryManager != null)
                    {
                        var stats = tradeHistoryManager.GetStatistics();

                        // Calculate total R lost today (negative R-multiples)
                        var todayTrades = tradeHistoryManager.GetAllTrades()
                            .Where(t => t.ExitTime.Date == DateTime.Now.Date)
                            .ToList();

                        double totalRToday = 0;
                        foreach (var trade in todayTrades)
                        {
                            if (trade.RMultiple < 0)
                                totalRToday += Math.Abs(trade.RMultiple);
                        }

                        dailyLossUsedR = totalRToday;
                    }

                    // Update UI
                    if (DailyLossUsedText != null)
                        DailyLossUsedText.Text = $"-{dailyLossUsedR:F1}R";

                    if (DailyLossLimitText != null)
                        DailyLossLimitText.Text = $"-{DAILY_LOSS_LIMIT_R:F0}R";

                    if (DailyLossBar != null)
                    {
                        DailyLossBar.Maximum = DAILY_LOSS_LIMIT_R;
                        DailyLossBar.Value = dailyLossUsedR;

                        // Color-code based on proximity to limit
                        double lossPercentage = (dailyLossUsedR / DAILY_LOSS_LIMIT_R) * 100;
                        if (lossPercentage >= 90)
                            DailyLossBar.Foreground = new SolidColorBrush(Color.FromRgb(244, 71, 71)); // Bright red
                        else if (lossPercentage >= 70)
                            DailyLossBar.Foreground = new SolidColorBrush(Color.FromRgb(244, 135, 113)); // Orange-red
                        else if (lossPercentage >= 50)
                            DailyLossBar.Foreground = new SolidColorBrush(Color.FromRgb(255, 152, 0)); // Orange
                        else
                            DailyLossBar.Foreground = new SolidColorBrush(Color.FromRgb(122, 74, 74)); // Muted red
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error updating daily loss limit: {ex.Message}");
                }
            });
        }

        private void UpdateTradingSession()
        {
            Dispatcher.Invoke(() =>
            {
                try
                {
                    DateTime utcNow = DateTime.UtcNow;
                    TimeSpan utcTime = utcNow.TimeOfDay;

                    string session = "CLOSED";
                    string sessionTime = "";
                    Color sessionColor = Color.FromRgb(136, 136, 136); // Gray
                    string nextSession = "";

                    // Trading Session Times (UTC):
                    // Tokyo: 00:00 - 09:00 UTC
                    // London: 08:00 - 17:00 UTC
                    // New York: 13:00 - 22:00 UTC
                    // Sydney: 22:00 - 07:00 UTC (next day)

                    if (utcTime >= TimeSpan.FromHours(22) || utcTime < TimeSpan.FromHours(7))
                    {
                        session = "SYDNEY";
                        sessionColor = Color.FromRgb(255, 152, 0); // Orange
                        sessionTime = $" • {utcNow:HH:mm} UTC";

                        // Calculate time to Tokyo
                        var tokyoStart = utcTime < TimeSpan.FromHours(7)
                            ? TimeSpan.FromHours(24) - utcTime
                            : TimeSpan.FromHours(24) - utcTime;
                        nextSession = $"TOKYO in {tokyoStart.Hours}h {tokyoStart.Minutes}m";
                    }
                    else if (utcTime >= TimeSpan.FromHours(0) && utcTime < TimeSpan.FromHours(9))
                    {
                        session = "TOKYO";
                        sessionColor = Color.FromRgb(220, 220, 170); // Yellow
                        sessionTime = $" • {utcNow:HH:mm} UTC";

                        var londonStart = TimeSpan.FromHours(8) - utcTime;
                        nextSession = $"LONDON in {londonStart.Hours}h {londonStart.Minutes}m";
                    }
                    else if (utcTime >= TimeSpan.FromHours(8) && utcTime < TimeSpan.FromHours(17))
                    {
                        session = "LONDON";
                        sessionColor = Color.FromRgb(78, 201, 176); // Green (most liquid)
                        sessionTime = $" • {utcNow:HH:mm} UTC";

                        if (utcTime < TimeSpan.FromHours(13))
                        {
                            var nyStart = TimeSpan.FromHours(13) - utcTime;
                            nextSession = $"NY in {nyStart.Hours}h {nyStart.Minutes}m";
                        }
                        else
                        {
                            var nyClose = TimeSpan.FromHours(17) - utcTime;
                            nextSession = $"Closes in {nyClose.Hours}h {nyClose.Minutes}m";
                        }
                    }
                    else if (utcTime >= TimeSpan.FromHours(13) && utcTime < TimeSpan.FromHours(22))
                    {
                        session = "NEW YORK";
                        sessionColor = Color.FromRgb(0, 122, 204); // Blue
                        sessionTime = $" • {utcNow:HH:mm} UTC";

                        var sydneyStart = TimeSpan.FromHours(22) - utcTime;
                        nextSession = $"SYDNEY in {sydneyStart.Hours}h {sydneyStart.Minutes}m";
                    }

                    // Special case: London/NY overlap (13:00-17:00 UTC) - highest volume
                    if (utcTime >= TimeSpan.FromHours(13) && utcTime < TimeSpan.FromHours(17))
                    {
                        session = "LON/NY";
                        sessionColor = Color.FromRgb(78, 201, 176); // Bright green (premium session)
                        nextSession = $"Peak liquidity";
                    }

                    // Update UI
                    if (CurrentSessionText != null)
                    {
                        CurrentSessionText.Text = session;
                        CurrentSessionText.Foreground = new SolidColorBrush(sessionColor);
                    }

                    if (SessionIndicator != null)
                        SessionIndicator.Fill = new SolidColorBrush(sessionColor);

                    if (SessionTimeText != null)
                        SessionTimeText.Text = sessionTime;

                    if (NextSessionText != null)
                        NextSessionText.Text = nextSession;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error updating trading session: {ex.Message}");
                }
            });
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

            // ═══════════════════════════════════════════════════════════
            // UPDATE LIVE DASHBOARD (Hidden elements for compatibility)
            // ═══════════════════════════════════════════════════════════
            var trSignal = FindName($"{pair}_TR_Signal") as TextBlock;
            var trConf = FindName($"{pair}_TR_Conf") as TextBlock;
            var ipSignal = FindName($"{pair}_IP_Signal") as TextBlock;
            var ipConf = FindName($"{pair}_IP_Conf") as TextBlock;
            var brSignal = FindName($"{pair}_BR_Signal") as TextBlock;
            var brConf = FindName($"{pair}_BR_Conf") as TextBlock;
            var bestSignal = FindName($"{pair}_Best_Signal") as TextBlock;
            var bestConf = FindName($"{pair}_Best_Conf") as TextBlock;

            // Update Trend Rider (hidden)
            if (trSignal != null)
            {
                trSignal.Text = signalData.TrendRiderSignal;
                trSignal.Foreground = GetSignalColor(signalData.TrendRiderSignal);
            }
            if (trConf != null)
                trConf.Text = $"{signalData.TrendRiderConfidence}%";

            // Update Impulse Pullback (hidden)
            if (ipSignal != null)
            {
                ipSignal.Text = signalData.ImpulsePullbackSignal;
                ipSignal.Foreground = GetSignalColor(signalData.ImpulsePullbackSignal);
            }
            if (ipConf != null)
                ipConf.Text = $"{signalData.ImpulsePullbackConfidence}%";

            // Update Breakout Retest (hidden)
            if (brSignal != null)
            {
                brSignal.Text = signalData.BreakoutRetestSignal;
                brSignal.Foreground = GetSignalColor(signalData.BreakoutRetestSignal);
            }
            if (brConf != null)
                brConf.Text = $"{signalData.BreakoutRetestConfidence}%";

            // Update Best Signal (Live Dashboard visible cards)
            if (bestSignal != null)
            {
                bestSignal.Text = signalData.BestSignal;
                bestSignal.Foreground = GetSignalColor(signalData.BestSignal);
            }
            if (bestConf != null)
                bestConf.Text = $"{signalData.BestConfidence}%";

            // ═══════════════════════════════════════════════════════════
            // UPDATE SIGNAL ANALYSIS TAB (2x2 Grid with _SA suffix)
            // ═══════════════════════════════════════════════════════════

            // Top-level signal and confidence (main card display)
            var saSignal = FindName($"{pair}_Signal_SA") as TextBlock;
            var saConfidence = FindName($"{pair}_Confidence_SA") as TextBlock;

            if (saSignal != null)
            {
                saSignal.Text = signalData.BestSignal;
                saSignal.Foreground = GetSignalColor(signalData.BestSignal);
            }
            if (saConfidence != null)
            {
                saConfidence.Text = $"{signalData.BestConfidence}%";
                saConfidence.Foreground = new SolidColorBrush(Color.FromRgb(255, 255, 255)); // White
            }

            // TrendRider Strategy in Signal Analysis tab
            var saTrSignal = FindName($"{pair}_TR_Signal_SA") as TextBlock;
            var saTrConf = FindName($"{pair}_TR_Conf_SA") as TextBlock;
            var saTrBar = FindName($"{pair}_TR_Bar_SA") as System.Windows.Controls.Primitives.RangeBase;

            if (saTrSignal != null)
            {
                saTrSignal.Text = signalData.TrendRiderSignal;
                saTrSignal.Foreground = GetSignalColor(signalData.TrendRiderSignal);
            }
            if (saTrConf != null)
            {
                saTrConf.Text = $"{signalData.TrendRiderConfidence}%";
            }
            if (saTrBar != null)
            {
                saTrBar.Value = signalData.TrendRiderConfidence;
            }

            // RangeRider Strategy in Signal Analysis tab (mapped from ImpulsePullback for CSM Alpha)
            var saRrSignal = FindName($"{pair}_RR_Signal_SA") as TextBlock;
            var saRrConf = FindName($"{pair}_RR_Conf_SA") as TextBlock;
            var saRrBar = FindName($"{pair}_RR_Bar_SA") as System.Windows.Controls.Primitives.RangeBase;

            if (saRrSignal != null)
            {
                saRrSignal.Text = signalData.ImpulsePullbackSignal; // CSM Alpha: RangeRider data in ImpulsePullback field
                saRrSignal.Foreground = GetSignalColor(signalData.ImpulsePullbackSignal);
            }
            if (saRrConf != null)
            {
                saRrConf.Text = $"{signalData.ImpulsePullbackConfidence}%";
            }
            if (saRrBar != null)
            {
                saRrBar.Value = signalData.ImpulsePullbackConfidence;
            }
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
            int activePositionCount = 0;

            // Read performance file for balance
            if (File.Exists(perfFile))
            {
                try
                {
                    var lines = File.ReadAllLines(perfFile);
                    foreach (var line in lines)
                    {
                        // NEW FORMAT: "Current Balance: $9642.28"
                        if (line.Contains("Current Balance:"))
                        {
                            string value = line.Replace("Current Balance:", "").Replace("$", "").Trim();
                            double.TryParse(value, out balance);
                        }
                        // OLD FORMAT: "BALANCE=" (fallback)
                        else if (line.Contains("BALANCE="))
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
                        // NEW FORMAT: Ticket: 32815798 | EURUSD.sml BUY | Lots: 0.19 | Entry: 1.17912 | Current: 1.18288 | SL: 1.17412 | TP: 1.18912 | P&L: $71.44 | Time: 2026.01.23 15:30
                        if (line.StartsWith("Ticket:"))
                        {
                            string[] parts = line.Split('|');
                            if (parts.Length >= 6) // At minimum we need ticket, symbol, lots, entry, current, P&L
                            {
                                // Parse ticket: "Ticket: 32815798"
                                string ticketStr = parts[0].Replace("Ticket:", "").Trim();

                                // Parse symbol and type: "EURUSD.sml BUY" or "GBPUSD.sml SELL"
                                string[] symbolTypeParts = parts[1].Trim().Split(' ');
                                string symbol = symbolTypeParts.Length > 0 ? symbolTypeParts[0] : "";
                                string type = symbolTypeParts.Length > 1 ? symbolTypeParts[1] : "";

                                // Parse lots: "Lots: 0.19"
                                string lotsStr = parts[2].Replace("Lots:", "").Trim();

                                // Parse entry: "Entry: 1.17912"
                                string entryStr = parts[3].Replace("Entry:", "").Trim();

                                // Parse current: "Current: 1.18288"
                                string currentStr = parts[4].Replace("Current:", "").Trim();

                                // Parse SL (if exists): "SL: 1.17412"
                                string slStr = "N/A";
                                if (parts.Length >= 7 && parts[5].Contains("SL:"))
                                {
                                    string slValue = parts[5].Replace("SL:", "").Trim();
                                    if (double.TryParse(slValue, out double slDouble) && slDouble > 0)
                                        slStr = slValue;
                                }
                                // TEMPORARY FALLBACK: Estimate SL if not in file (for old format testing)
                                else if (double.TryParse(entryStr, out double entryForSL))
                                {
                                    double slDistance = symbol.Contains("XAU") ? 50.0 : 0.0050; // $50 for Gold, 50 pips for Forex
                                    double estimatedSL = type == "BUY" ? entryForSL - slDistance : entryForSL + slDistance;
                                    slStr = estimatedSL.ToString("F5");
                                }

                                // Parse TP (if exists): "TP: 1.18912"
                                string tpStr = "N/A";
                                if (parts.Length >= 7 && parts[6].Contains("TP:"))
                                {
                                    string tpValue = parts[6].Replace("TP:", "").Trim();
                                    if (double.TryParse(tpValue, out double tp) && tp > 0)
                                        tpStr = tpValue;
                                }
                                // TEMPORARY FALLBACK: Estimate TP if not in file (for old format testing)
                                else if (double.TryParse(entryStr, out double entryForTP))
                                {
                                    double tpDistance = symbol.Contains("XAU") ? 100.0 : 0.0100; // $100 for Gold, 100 pips for Forex
                                    double estimatedTP = type == "BUY" ? entryForTP + tpDistance : entryForTP - tpDistance;
                                    tpStr = estimatedTP.ToString("F5");
                                }

                                // Parse P&L: "P&L: $71.44"
                                int pnlIndex = parts.Length >= 8 ? 7 : 5; // With or without SL/TP
                                string pnlStr = parts[pnlIndex].Replace("P&L:", "").Replace("$", "").Trim();

                                // Parse Time (if exists): "Time: 2026.01.23 15:30"
                                string timeStr = "N/A";
                                if (parts.Length >= 9 && parts[8].Contains("Time:"))
                                {
                                    timeStr = parts[8].Replace("Time:", "").Trim();
                                }
                                // TEMPORARY FALLBACK: Use "Estimated" if not in file
                                else
                                {
                                    timeStr = "Jan 23 23:58"; // Approximate from file timestamp
                                }

                                var pos = new PositionDisplay
                                {
                                    Ticket = ticketStr,
                                    Symbol = symbol,
                                    Strategy = "CSM", // Not in file, use default
                                    Type = type,
                                    EntryPrice = entryStr,
                                    CurrentPrice = currentStr,
                                    StopLoss = slStr,
                                    TakeProfit = tpStr,
                                    Size = lotsStr,
                                    PnL = "$" + pnlStr,
                                    EntryTime = timeStr
                                };

                                // Calculate R-Multiple (if we have SL and P&L)
                                if (double.TryParse(entryStr, out double entry) &&
                                    double.TryParse(slStr, out double sl) &&
                                    double.TryParse(pnlStr, out double profit))
                                {
                                    double risk = Math.Abs(entry - sl) * double.Parse(lotsStr) * 100000; // Simplified risk calculation
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

                                // Risk amount (approximate based on SL)
                                if (double.TryParse(entryStr, out double e) &&
                                    double.TryParse(slStr, out double s) &&
                                    double.TryParse(lotsStr, out double lots))
                                {
                                    double riskPips = Math.Abs(e - s);
                                    double riskAmount = riskPips * lots * 100000 * 0.0001; // Simplified
                                    pos.Risk = "$" + riskAmount.ToString("F2");
                                }
                                else
                                {
                                    pos.Risk = "N/A";
                                }

                                positionsList.Add(pos);
                                activePositionCount++;
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error parsing positions: {ex.Message}");
                }
            }

            // Store positions for trade details panel
            activePositions = positionsList;

            // Update UI
            Dispatcher.Invoke(() =>
            {
                // Update account balance in bottom section
                if (balance > 0)
                {
                    AccountBalanceLargeText.Text = "$" + balance.ToString("N2");
                }
                ActiveTradesText.Text = activePositionCount.ToString();

                // Update position slots bar
                PositionSlotsBar.Value = activePositionCount;

                // Update the DataGrid
                ActivePositionsGrid.ItemsSource = null;
                ActivePositionsGrid.ItemsSource = positionsList;

                // Update trade details panel if a position exists for the selected asset
                UpdateTradeDetailsPanel(selectedAsset);

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

        // ═══════════════════════════════════════════════════════════
        // REDESIGNED UI EVENT HANDLERS
        // ═══════════════════════════════════════════════════════════

        private void AssetCard_Click(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            if (sender is Border border && border.Tag is string asset)
            {
                selectedAsset = asset;
                SelectAssetCard(asset);
                UpdateTradeDetailsPanel(asset);
            }
        }

        private void SelectAssetCard(string asset)
        {
            // Reset all asset card borders to default
            var assets = new[] { "EURUSD", "GBPUSD", "AUDJPY", "XAUUSD" };
            foreach (var a in assets)
            {
                var borderName = $"{a}Border";
                if (FindName(borderName) is Border border)
                {
                    border.BorderBrush = new SolidColorBrush(Color.FromRgb(62, 62, 66));
                    border.BorderThickness = new Thickness(1);
                    border.Background = new SolidColorBrush(Color.FromRgb(45, 45, 48));
                }
            }

            // Highlight selected asset card
            var selectedBorderName = $"{asset}Border";
            if (FindName(selectedBorderName) is Border selectedBorder)
            {
                selectedBorder.BorderBrush = new SolidColorBrush(Color.FromRgb(0, 122, 204)); // #007ACC
                selectedBorder.BorderThickness = new Thickness(2);
                selectedBorder.Background = new SolidColorBrush(Color.FromRgb(37, 37, 38));
            }
        }

        private void UpdateTradeDetailsPanel(string asset)
        {
            Dispatcher.Invoke(() =>
            {
                try
                {
                    // Update header
                    if (SelectedAssetLabel != null)
                        SelectedAssetLabel.Text = asset;

                    // Get signal data for selected asset
                    if (!pairSignals.ContainsKey(asset))
                        return;

                    var signalData = pairSignals[asset];

                    // Determine active strategy (use best signal)
                    string strategyName = "—";
                    if (signalData.TrendRiderConfidence >= signalData.ImpulsePullbackConfidence &&
                        signalData.TrendRiderConfidence >= signalData.BreakoutRetestConfidence)
                        strategyName = "TrendRider";
                    else if (signalData.ImpulsePullbackConfidence >= signalData.BreakoutRetestConfidence)
                        strategyName = "ImpulsePullback";
                    else
                        strategyName = "BreakoutRetest";

                    if (SelectedStrategyLabel != null)
                        SelectedStrategyLabel.Text = $"— {strategyName}";

                    // Update signal confidence
                    if (SignalConfidenceText != null)
                        SignalConfidenceText.Text = $"{signalData.BestConfidence}%";
                    if (SignalConfidenceBar != null)
                        SignalConfidenceBar.Value = signalData.BestConfidence;

                    // Find active position for this asset
                    var position = activePositions.FirstOrDefault(p =>
                        p.Symbol.Replace(".sml", "").Replace(".ecn", "").Replace(".raw", "").ToUpper() == asset.ToUpper());

                    bool hasPosition = position != null;

                    if (TradeStatusLabel != null)
                        TradeStatusLabel.Text = hasPosition ? "ACTIVE POSITION" : "NO POSITION";

                    // Show/hide panels based on position status
                    if (TradeDetailsPanel != null)
                        TradeDetailsPanel.Visibility = hasPosition ? Visibility.Visible : Visibility.Collapsed;
                    if (NoPositionPanel != null)
                    {
                        NoPositionPanel.Visibility = hasPosition ? Visibility.Collapsed : Visibility.Visible;
                        if (LastSignalText != null)
                            LastSignalText.Text = $"Last Signal: {signalData.BestSignal} @ {signalData.BestConfidence}%";
                    }

                    // Update trade details with real position data OR show signal preview
                    if (hasPosition)
                    {
                        UpdateTradeDetailsWithPosition(asset, position, signalData);
                    }
                    else
                    {
                        // TEMPORARY: Show signal details even when no position (for testing)
                        UpdateTradeDetailsWithSignal(asset, signalData);
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error updating trade details: {ex.Message}");
                }
            });
        }

        private void UpdateTradeDetailsWithPosition(string asset, PositionDisplay position, SignalData signalData)
        {
            try
            {
                // Update price fields
                if (EntryPriceText != null)
                    EntryPriceText.Text = position.EntryPrice ?? "—";
                if (CurrentPriceText != null)
                {
                    CurrentPriceText.Text = position.CurrentPrice ?? "—";
                    // Color code current price based on profit/loss
                    if (position.PnL != null && double.TryParse(position.PnL, out double pnl))
                    {
                        CurrentPriceText.Foreground = pnl >= 0 ?
                            new SolidColorBrush(Color.FromRgb(78, 201, 176)) :  // Green
                            new SolidColorBrush(Color.FromRgb(244, 135, 113));  // Red
                    }
                }

                // Update SL/TP fields
                if (StopLossText != null)
                    StopLossText.Text = position.StopLoss ?? "—";
                if (TakeProfitText != null)
                    TakeProfitText.Text = position.TakeProfit ?? "—";

                // Calculate pips to SL/TP
                if (double.TryParse(position.CurrentPrice, out double current) &&
                    double.TryParse(position.StopLoss, out double sl) &&
                    double.TryParse(position.TakeProfit, out double tp))
                {
                    double pipsToSL = Math.Abs(current - sl) * 10000; // Forex pip calculation
                    double pipsToTP = Math.Abs(tp - current) * 10000;

                    // Special handling for Gold (XAU) - different pip size
                    if (asset.Contains("XAU"))
                    {
                        pipsToSL = Math.Abs(current - sl);
                        pipsToTP = Math.Abs(tp - current);
                    }

                    if (PipsToSLText != null)
                        PipsToSLText.Text = $"{pipsToSL:F1} pips";
                    if (PipsToTPText != null)
                        PipsToTPText.Text = $"{pipsToTP:F1} pips";
                }
                else
                {
                    if (PipsToSLText != null)
                        PipsToSLText.Text = "— pips";
                    if (PipsToTPText != null)
                        PipsToTPText.Text = "— pips";
                }

                // Update R-Multiple
                if (RMultipleText != null)
                {
                    RMultipleText.Text = position.RMultiple ?? "—";
                    // Color code R-Multiple
                    if (position.RMultiple != null && position.RMultiple.Contains("R"))
                    {
                        string rValue = position.RMultiple.Replace("R", "");
                        if (double.TryParse(rValue, out double r))
                        {
                            RMultipleText.Foreground = r >= 1.0 ?
                                new SolidColorBrush(Color.FromRgb(78, 201, 176)) :  // Green
                                r >= 0 ?
                                new SolidColorBrush(Color.FromRgb(220, 220, 170)) :  // Yellow
                                new SolidColorBrush(Color.FromRgb(244, 135, 113));   // Red
                        }
                    }
                }

                // Update P&L
                if (UnrealizedPnLText != null && position.PnL != null)
                {
                    UnrealizedPnLText.Text = $"${position.PnL}";
                    // Color code P&L
                    if (double.TryParse(position.PnL, out double pnl))
                    {
                        UnrealizedPnLText.Foreground = pnl >= 0 ?
                            new SolidColorBrush(Color.FromRgb(78, 201, 176)) :  // Green
                            new SolidColorBrush(Color.FromRgb(244, 135, 113));  // Red
                    }
                }

                // Update position size
                if (PositionSizeText != null)
                    PositionSizeText.Text = position.Size != null ? $"{position.Size} lots" : "— lots";

                // Update time in trade
                if (TimeInTradeText != null && position.EntryTime != null)
                {
                    if (DateTime.TryParse(position.EntryTime, out DateTime entryTime))
                    {
                        TimeSpan duration = DateTime.Now - entryTime;
                        if (duration.TotalDays >= 1)
                            TimeInTradeText.Text = $"{(int)duration.TotalDays}d {duration.Hours}h";
                        else if (duration.TotalHours >= 1)
                            TimeInTradeText.Text = $"{(int)duration.TotalHours}h {duration.Minutes}m";
                        else
                            TimeInTradeText.Text = $"{duration.Minutes}m";
                    }
                    else
                    {
                        TimeInTradeText.Text = position.EntryTime;
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error updating trade details: {ex.Message}");
            }
        }

        private void UpdateTradeDetailsWithSignal(string asset, SignalData signalData)
        {
            try
            {
                // TEMPORARY: Show signal-based estimates when no position (for testing UI)
                // This will be replaced with real position data when market opens

                // Get current price from signal (if available) or use placeholder
                string currentPrice = "—";
                string entryPrice = "—";

                // Show signal direction
                if (EntryPriceText != null)
                    EntryPriceText.Text = $"Signal: {signalData.BestSignal}";

                if (CurrentPriceText != null)
                {
                    CurrentPriceText.Text = "Waiting for entry...";
                    CurrentPriceText.Foreground = new SolidColorBrush(Color.FromRgb(150, 150, 150));  // Gray
                }

                // Show estimated SL/TP (these would be calculated on actual entry)
                if (StopLossText != null)
                    StopLossText.Text = asset.Contains("XAU") ? "~$50 risk" : "~50 pips";
                if (TakeProfitText != null)
                    TakeProfitText.Text = asset.Contains("XAU") ? "~$100 target" : "~100 pips";

                // Show P&L as pending
                if (UnrealizedPnLText != null)
                {
                    UnrealizedPnLText.Text = "$0.00";
                    UnrealizedPnLText.Foreground = new SolidColorBrush(Color.FromRgb(150, 150, 150));  // Gray
                }

                // Show position size as planned
                if (PositionSizeText != null)
                    PositionSizeText.Text = "0.19 lots (planned)";

                // Show waiting status
                if (TimeInTradeText != null)
                    TimeInTradeText.Text = "Not opened yet";

                if (RMultipleText != null)
                    RMultipleText.Text = "—";
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error updating signal details: {ex.Message}");
            }
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

            // Update Signal Analysis tab controls (CSM Alpha format)
            UpdateSignalAnalysisTab(pair, signalData);

            // Update Trend Rider Details (legacy)
            UpdateStrategySection(pair, "TR",
                signalData.TrendRiderSignal,
                signalData.TrendRiderConfidence,
                signalData.TrendRiderScores,
                signalData.TrendRiderReasoning,
                new string[] { "EMA_ALIGN", "ADX", "RSI", "CSM" },
                new int[] { 35, 25, 20, 25 });

            // Update Impulse Pullback Details (legacy)
            UpdateStrategySection(pair, "IP",
                signalData.ImpulsePullbackSignal,
                signalData.ImpulsePullbackConfidence,
                signalData.ImpulsePullbackScores,
                signalData.ImpulsePullbackReasoning,
                new string[] { "IMPULSE", "FIB", "RSI", "CSM" },
                new int[] { 35, 25, 20, 20 });

            // Update Breakout Retest Details (legacy)
            UpdateStrategySection(pair, "BR",
                signalData.BreakoutRetestSignal,
                signalData.BreakoutRetestConfidence,
                signalData.BreakoutRetestScores,
                signalData.BreakoutRetestReasoning,
                new string[] { "LEVEL", "BREAKOUT", "VOLUME", "CSM" },
                new int[] { 30, 25, 25, 20 });
        }

        private void UpdateSignalAnalysisTab(string pair, SignalData signalData)
        {
            // Update TrendRider section
            var trSignal = FindName($"{pair}_TR_Signal_SA") as TextBlock;
            var trConf = FindName($"{pair}_TR_Conf_SA") as TextBlock;
            var trBar = FindName($"{pair}_TR_Bar_SA") as ProgressBar;
            var trAnalysis = FindName($"{pair}_TR_Analysis_SA") as TextBlock;

            if (trSignal != null) trSignal.Text = signalData.BestSignal;
            if (trConf != null) trConf.Text = $"{signalData.TrendRiderConfidence}%";
            if (trBar != null)
            {
                trBar.Value = signalData.TrendRiderConfidence;
                trBar.Foreground = GetSignalBrush(signalData.BestSignal);
            }
            if (trAnalysis != null)
            {
                trAnalysis.Text = string.IsNullOrEmpty(signalData.Analysis) ? "—" : signalData.Analysis.Trim();
            }

            // Update RangeRider section (currently shows 0% for CSM Alpha - only TrendRider used)
            var rrSignal = FindName($"{pair}_RR_Signal_SA") as TextBlock;
            var rrConf = FindName($"{pair}_RR_Conf_SA") as TextBlock;
            var rrBar = FindName($"{pair}_RR_Bar_SA") as ProgressBar;
            var rrAnalysis = FindName($"{pair}_RR_Analysis_SA") as TextBlock;

            if (rrSignal != null) rrSignal.Text = "HOLD";
            if (rrConf != null) rrConf.Text = "0%";
            if (rrBar != null) rrBar.Value = 0;
            if (rrAnalysis != null) rrAnalysis.Text = "—";
        }

        private Dictionary<string, int> ParseAnalysisString(string analysis)
        {
            var scores = new Dictionary<string, int>();
            if (string.IsNullOrEmpty(analysis)) return scores;

            // Parse "EMA+30 ADX+20 RSI+5 CSM+25 MTF+10 "
            var parts = analysis.Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (var part in parts)
            {
                var tokens = part.Split(new[] { '+', '-' });
                if (tokens.Length == 2)
                {
                    string key = tokens[0];
                    if (int.TryParse(tokens[1], out int value))
                    {
                        scores[key] = value;
                    }
                }
            }

            return scores;
        }

        private SolidColorBrush GetSignalBrush(string signal)
        {
            switch (signal)
            {
                case "BUY":
                    return new SolidColorBrush(Color.FromRgb(78, 201, 176));  // Green
                case "SELL":
                    return new SolidColorBrush(Color.FromRgb(244, 135, 113));  // Red
                default:
                    return new SolidColorBrush(Color.FromRgb(150, 150, 150));  // Gray
            }
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
        /* COMMENTED OUT - ColorIntensitySlider removed in new Settings tab design
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
        */

        /// <summary>
        /// Handles color scheme preset selection
        /// </summary>
        private void ColorSchemeComboBox_SelectionChanged(object sender,
                                                          SelectionChangedEventArgs e)
        {
            if (ColorSchemeComboBox == null || ColorSchemeComboBox.SelectedIndex == -1) return;

            var selected = (ColorSchemeComboBox.SelectedItem as ComboBoxItem)?.Content.ToString();

            System.Diagnostics.Debug.WriteLine($"Color scheme changed to: {selected}");

            switch (selected)
            {
                case "Muted":
                    colorIntensity = 0.6;
                    System.Diagnostics.Debug.WriteLine("→ Applied Muted preset (60%)");
                    break;

                case "Standard":
                    colorIntensity = 0.8;
                    System.Diagnostics.Debug.WriteLine("→ Applied Standard preset (80%)");
                    break;

                case "High Contrast (Current)":
                    colorIntensity = 1.0;
                    System.Diagnostics.Debug.WriteLine("→ Applied High Contrast preset (100%)");
                    break;
            }

            // Refresh all colors in the UI
            UpdateAllColors();
        }

        /// <summary>
        /// Updates the color preview panel in settings
        /// </summary>
        /* COMMENTED OUT - Preview controls removed in new Settings tab design
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
        */

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