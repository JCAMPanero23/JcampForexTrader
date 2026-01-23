using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using JcampForexTrader.Backtest;
using JcampForexTrader.Services;

namespace JcampForexTrader
{
    public partial class BacktestWindow : Window
    {
        private readonly BacktestApiClient _apiClient;
        private string _currentTaskId;
        private MultiPairBacktestResults _currentMultiPairResults; // Phase 8.2

        public BacktestWindow()
        {
            InitializeComponent();
            _apiClient = new BacktestApiClient("http://localhost:8001");

            // Set default dates to January 2024
            StartDatePicker.SelectedDate = new DateTime(2024, 1, 1);
            EndDatePicker.SelectedDate = new DateTime(2024, 1, 31);

            // Check API health on load
            CheckApiHealthAsync();
        }

        // Phase 8.2: Get selected pairs from checkboxes
        private List<string> GetSelectedPairs()
        {
            var pairs = new List<string>();
            if (EurusdCheckbox.IsChecked == true) pairs.Add("EURUSD");
            if (GbpusdCheckbox.IsChecked == true) pairs.Add("GBPUSD");
            if (UsdjpyCheckbox.IsChecked == true) pairs.Add("USDJPY");
            if (AudusdCheckbox.IsChecked == true) pairs.Add("AUDUSD");
            if (UsdcadCheckbox.IsChecked == true) pairs.Add("USDCAD");
            if (NzdusdCheckbox.IsChecked == true) pairs.Add("NZDUSD");
            return pairs;
        }

        // Phase 8.2: Get selected strategies
        private List<string> GetSelectedStrategies()
        {
            var strategy = ((System.Windows.Controls.ComboBoxItem)StrategyComboBox.SelectedItem).Content.ToString();

            if (strategy == "both")
                return new List<string> { "trend_rider", "range_rider" };
            else
                return new List<string> { strategy };
        }

        private async void CheckApiHealthAsync()
        {
            try
            {
                var health = await _apiClient.CheckHealthAsync();
                StatusTextBlock.Text = $"API Server: {health.Status} (v{health.Version})";
            }
            catch (Exception ex)
            {
                StatusTextBlock.Text = $"API Server: Offline";
                MessageBox.Show(
                    $"Cannot connect to Python API server.\n\nMake sure the server is running at http://localhost:8001\n\nError: {ex.Message}",
                    "API Connection Error",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
            }
        }

        private async void RunBacktestButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // Validate inputs
                if (!ValidateInputs())
                    return;

                // Get selected pairs
                var selectedPairs = GetSelectedPairs();

                // Disable button and switch to progress tab
                RunBacktestButton.IsEnabled = false;
                ResultsTabControl.SelectedIndex = 0; // Progress tab

                // Reset progress
                ProgressBar.Value = 0;
                ProgressTextBlock.Text = "0%";
                StatusTextBlock.Text = "Submitting backtest...";

                // Create progress reporter
                var progress = new Progress<BacktestStatus>(status =>
                {
                    ProgressBar.Value = status.Progress;
                    ProgressTextBlock.Text = $"{status.Progress:F1}%";
                    StatusTextBlock.Text = status.Message;
                });

                // Phase 8.2: Check if single-pair or multi-pair
                if (selectedPairs.Count == 1)
                {
                    // Single-pair: Use existing endpoint (backward compatible)
                    var request = new BacktestRequest
                    {
                        Symbol = selectedPairs[0],
                        StartDate = StartDatePicker.SelectedDate?.ToString("yyyy-MM-dd"),
                        EndDate = EndDatePicker.SelectedDate?.ToString("yyyy-MM-dd"),
                        Strategy = ((System.Windows.Controls.ComboBoxItem)StrategyComboBox.SelectedItem).Content.ToString(),
                        InitialBalance = double.Parse(InitialBalanceTextBox.Text),
                        RiskPercent = double.Parse(RiskPercentTextBox.Text),
                        MaxPositions = int.Parse(MaxPositionsTextBox.Text)
                    };

                    var results = await _apiClient.RunBacktestAsync(request, progress);
                    _currentTaskId = results.TaskId;
                    DisplayResults(results);
                }
                else
                {
                    // Multi-pair: Use new endpoint
                    var request = new MultiPairBacktestRequest
                    {
                        Pairs = selectedPairs,
                        Strategies = GetSelectedStrategies(),
                        StartDate = StartDatePicker.SelectedDate?.ToString("yyyy-MM-dd"),
                        EndDate = EndDatePicker.SelectedDate?.ToString("yyyy-MM-dd"),
                        Config = new BacktestConfig
                        {
                            InitialBalance = double.Parse(InitialBalanceTextBox.Text),
                            RiskPercent = double.Parse(RiskPercentTextBox.Text) / 100.0, // Convert to decimal
                            MaxConcurrentPositions = int.Parse(MaxPositionsTextBox.Text),
                            MinConfidence = 50.0,
                            TakeProfitR = 2.0
                        }
                    };

                    var results = await _apiClient.RunMultiPairBacktestAsync(request, progress);
                    _currentMultiPairResults = results;
                    DisplayMultiPairResults(results);
                }

                // Enable chart viewer button
                ViewChartButton.IsEnabled = true;

                // Switch to summary tab
                ResultsTabControl.SelectedIndex = 1; // Summary tab
                StatusTextBlock.Text = $"Backtest completed successfully! {(selectedPairs.Count == 1 ? "1 pair" : selectedPairs.Count + " pairs")} tested.";

            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    $"Backtest failed:\n\n{ex.Message}",
                    "Backtest Error",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error);

                StatusTextBlock.Text = "Backtest failed";
            }
            finally
            {
                RunBacktestButton.IsEnabled = true;
            }
        }

        private bool ValidateInputs()
        {
            // Phase 8.2: Validate at least one pair selected
            var selectedPairs = GetSelectedPairs();
            if (selectedPairs.Count == 0)
            {
                MessageBox.Show("Please select at least one pair", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                return false;
            }

            if (!StartDatePicker.SelectedDate.HasValue)
            {
                MessageBox.Show("Please select a start date", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                return false;
            }

            if (!EndDatePicker.SelectedDate.HasValue)
            {
                MessageBox.Show("Please select an end date", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                return false;
            }

            if (StartDatePicker.SelectedDate >= EndDatePicker.SelectedDate)
            {
                MessageBox.Show("Start date must be before end date", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                return false;
            }

            if (!double.TryParse(InitialBalanceTextBox.Text, out double balance) || balance <= 0)
            {
                MessageBox.Show("Initial balance must be a positive number", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                return false;
            }

            if (!double.TryParse(RiskPercentTextBox.Text, out double risk) || risk <= 0 || risk > 10)
            {
                MessageBox.Show("Risk percent must be between 0.1 and 10", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                return false;
            }

            if (!int.TryParse(MaxPositionsTextBox.Text, out int positions) || positions <= 0 || positions > 10)
            {
                MessageBox.Show("Max positions must be between 1 and 10", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                return false;
            }

            return true;
        }

        private void DisplayResults(BacktestResults results)
        {
            // Performance Metrics
            TotalTradesText.Text = results.TotalTrades.ToString();
            WinRateText.Text = $"{results.WinRate:F2}%";
            TotalRText.Text = $"{results.TotalR:F2}";
            AvgRText.Text = $"{results.AvgR:F3}";
            NetProfitText.Text = $"${results.NetProfit:F2}";
            ReturnPctText.Text = $"{results.ReturnPct:F2}%";
            ProfitFactorText.Text = $"{results.ProfitFactor:F2}";
            SharpeRatioText.Text = $"{results.SharpeRatio:F3}";
            MaxDrawdownText.Text = $"{results.MaxDrawdownPct:F2}%";
            MaxDrawdownDollarsText.Text = $"${results.MaxDrawdownDollars:F2}";
            MaxConsecutiveWinsText.Text = results.MaxConsecutiveWins.ToString();
            MaxConsecutiveLossesText.Text = results.MaxConsecutiveLosses.ToString();

            // Strategy Breakdown
            if (results.TrendRider != null)
            {
                TrendRiderBreakdownText.Text = $"Trend Rider: {results.TrendRider.Trades} trades, " +
                    $"{results.TrendRider.WinRate:F1}% win rate, {results.TrendRider.TotalR:F2} total R";
            }
            else
            {
                TrendRiderBreakdownText.Text = "Trend Rider: No trades";
            }

            if (results.RangeRider != null)
            {
                RangeRiderBreakdownText.Text = $"Range Rider: {results.RangeRider.Trades} trades, " +
                    $"{results.RangeRider.WinRate:F1}% win rate, {results.RangeRider.TotalR:F2} total R";
            }
            else
            {
                RangeRiderBreakdownText.Text = "Range Rider: No trades";
            }

            // Trades
            TradesDataGrid.ItemsSource = results.Trades;
        }

        // Phase 8.2: Display multi-pair backtest results
        private void DisplayMultiPairResults(MultiPairBacktestResults results)
        {
            // Performance Metrics
            TotalTradesText.Text = results.Statistics.TotalTrades.ToString();
            WinRateText.Text = $"{results.Statistics.WinRate:F2}%";
            TotalRText.Text = $"{results.Statistics.TotalR:F2}";
            AvgRText.Text = $"{results.Statistics.AvgR:F3}";
            NetProfitText.Text = $"${results.Statistics.NetProfit:F2}";
            ReturnPctText.Text = $"{results.Statistics.ReturnPercent:F2}%";

            // Calculate profit factor from trades
            var wins = results.Trades.Where(t => t.RMultiple > 0).Sum(t => t.ProfitLoss ?? 0);
            var losses = Math.Abs(results.Trades.Where(t => t.RMultiple < 0).Sum(t => t.ProfitLoss ?? 0));
            ProfitFactorText.Text = losses > 0 ? $"{(wins / losses):F2}" : "N/A";

            SharpeRatioText.Text = $"{results.Statistics.SharpeRatio:F3}";
            MaxDrawdownText.Text = $"{results.Statistics.MaxDrawdown:F2}%";
            MaxDrawdownDollarsText.Text = $"${(results.Statistics.InitialBalance * results.Statistics.MaxDrawdown / 100):F2}";

            // Calculate consecutive wins/losses
            int maxWins = 0, maxLosses = 0, currentWins = 0, currentLosses = 0;
            foreach (var trade in results.Trades.OrderBy(t => t.EntryTime))
            {
                if (trade.RMultiple > 0)
                {
                    currentWins++;
                    currentLosses = 0;
                    maxWins = Math.Max(maxWins, currentWins);
                }
                else if (trade.RMultiple < 0)
                {
                    currentLosses++;
                    currentWins = 0;
                    maxLosses = Math.Max(maxLosses, currentLosses);
                }
            }
            MaxConsecutiveWinsText.Text = maxWins.ToString();
            MaxConsecutiveLossesText.Text = maxLosses.ToString();

            // Strategy Breakdown (BUG3 fix: use uppercase keys to match Python API)
            if (results.StrategyBreakdown.ContainsKey("TREND_RIDER"))
            {
                var tr = results.StrategyBreakdown["TREND_RIDER"];
                TrendRiderBreakdownText.Text = $"Trend Rider: {tr.Trades} trades, " +
                    $"{tr.WinRate:F1}% win rate, {tr.TotalR:F2} total R";
            }
            else
            {
                TrendRiderBreakdownText.Text = "Trend Rider: No trades";
            }

            if (results.StrategyBreakdown.ContainsKey("RANGE_RIDER"))
            {
                var rr = results.StrategyBreakdown["RANGE_RIDER"];
                RangeRiderBreakdownText.Text = $"Range Rider: {rr.Trades} trades, " +
                    $"{rr.WinRate:F1}% win rate, {rr.TotalR:F2} total R";
            }
            else
            {
                RangeRiderBreakdownText.Text = "Range Rider: No trades";
            }

            // Trades
            TradesDataGrid.ItemsSource = results.Trades;
        }

        private async void ViewChartButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // Phase 8.2.2: Check if multi-pair results available
                if (_currentMultiPairResults != null)
                {
                    // Multi-pair: Launch chart viewer with multi-pair results
                    var multiChartViewer = new ChartViewerWindow(_currentMultiPairResults);
                    multiChartViewer.Show();
                    StatusTextBlock.Text = $"Chart viewer opened successfully! Loaded {_currentMultiPairResults.PairChartData.Count} pairs.";
                    return;
                }

                // Single-pair: Use existing chart viewer
                if (string.IsNullOrEmpty(_currentTaskId))
                {
                    MessageBox.Show(
                        "No backtest results available. Please run a backtest first.",
                        "No Data",
                        MessageBoxButton.OK,
                        MessageBoxImage.Information);
                    return;
                }

                // Disable button while loading
                ViewChartButton.IsEnabled = false;
                StatusTextBlock.Text = "Loading chart data...";

                // Fetch OHLC data
                var ohlcData = await _apiClient.GetOhlcDataAsync(_currentTaskId);

                // Launch chart viewer window with taskId for M1 data loading
                var singleChartViewer = new ChartViewerWindow(ohlcData, _currentTaskId);
                singleChartViewer.Show();

                StatusTextBlock.Text = "Chart viewer opened successfully! Loading M1 data for smooth playback...";
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    $"Failed to load chart data:\n\n{ex.Message}",
                    "Chart Viewer Error",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error);

                StatusTextBlock.Text = "Failed to load chart data";
            }
            finally
            {
                ViewChartButton.IsEnabled = true;
            }
        }

        protected override void OnClosed(EventArgs e)
        {
            base.OnClosed(e);
            _apiClient?.Dispose();
        }

        private void AudusdCheckbox_Checked(object sender, RoutedEventArgs e)
        {

        }
    }
}
