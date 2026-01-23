using System;
using System.Collections.Generic;
using Newtonsoft.Json;

namespace JcampForexTrader.Backtest
{
    /// <summary>
    /// Playback mode for chart viewer
    /// </summary>
    public enum PlaybackMode
    {
        Standard,       // Jump between bars (M15)
        RealM1          // Use real M1 data for smooth movement
    }

    /// <summary>
    /// OHLC Candlestick data for chart visualization
    /// </summary>
    public class OhlcData
    {
        [JsonProperty("symbol")]
        public string Symbol { get; set; }

        [JsonProperty("start_date")]
        public string StartDate { get; set; }

        [JsonProperty("end_date")]
        public string EndDate { get; set; }

        [JsonProperty("timeframe")]
        public string Timeframe { get; set; }

        [JsonProperty("candles")]
        public List<CandleData> Candles { get; set; }

        [JsonProperty("trades")]
        public List<TradeWithLevels> Trades { get; set; }

        [JsonProperty("pip_size")]
        public double PipSize { get; set; }

        [JsonProperty("decimal_places")]
        public int DecimalPlaces { get; set; }

        // M1 candles for enhanced playback
        public List<CandleData> M1Candles { get; set; }
    }

    /// <summary>
    /// Individual candlestick bar data
    /// </summary>
    public class CandleData
    {
        [JsonProperty("timestamp")]
        public string Timestamp { get; set; }

        [JsonProperty("open")]
        public double Open { get; set; }

        [JsonProperty("high")]
        public double High { get; set; }

        [JsonProperty("low")]
        public double Low { get; set; }

        [JsonProperty("close")]
        public double Close { get; set; }

        [JsonProperty("ema_fast")]
        public double? EmaFast { get; set; }

        [JsonProperty("ema_mid")]
        public double? EmaMid { get; set; }

        [JsonProperty("ema_slow")]
        public double? EmaSlow { get; set; }

        [JsonProperty("rsi")]
        public double? Rsi { get; set; }

        [JsonProperty("adx")]
        public double? Adx { get; set; }

        // H1 EMAs from Python (pre-calculated with warmup)
        [JsonProperty("ema_20_h1")]
        public double? Ema20H1Python { get; set; }

        [JsonProperty("ema_50_h1")]
        public double? Ema50H1Python { get; set; }

        [JsonProperty("ema_100_h1")]
        public double? Ema100H1Python { get; set; }

        // Multi-timeframe EMAs for alignment analysis
        // M15 timeframe EMAs
        public double? Ema20_M15 { get; set; }
        public double? Ema50_M15 { get; set; }
        public double? Ema100_M15 { get; set; }

        // H1 timeframe EMAs
        public double? Ema20_H1 { get; set; }
        public double? Ema50_H1 { get; set; }
        public double? Ema100_H1 { get; set; }

        public DateTime GetDateTime()
        {
            return DateTime.Parse(Timestamp);
        }

        public bool IsBullish => Close > Open;
    }

    /// <summary>
    /// Trade with TP/SL levels for visualization
    /// </summary>
    public class TradeWithLevels
    {
        [JsonProperty("ticket_number")]
        public int TicketNumber { get; set; }

        [JsonProperty("symbol")]
        public string Symbol { get; set; }

        [JsonProperty("side")]
        public string Side { get; set; }

        [JsonProperty("strategy")]
        public string Strategy { get; set; }

        [JsonProperty("entry_time")]
        public string EntryTime { get; set; }

        [JsonProperty("exit_time")]
        public string ExitTime { get; set; }

        [JsonProperty("entry_price")]
        public double EntryPrice { get; set; }

        [JsonProperty("exit_price")]
        public double? ExitPrice { get; set; }

        [JsonProperty("stop_loss")]
        public double? StopLoss { get; set; }

        [JsonProperty("take_profit")]
        public double? TakeProfit { get; set; }

        [JsonProperty("r_multiple")]
        public double? RMultiple { get; set; }

        [JsonProperty("profit_loss")]
        public double? ProfitLoss { get; set; }

        [JsonProperty("exit_reason")]
        public string ExitReason { get; set; }

        [JsonProperty("is_win")]
        public bool IsWin { get; set; }

        public DateTime GetEntryTime()
        {
            return DateTime.Parse(EntryTime);
        }

        public DateTime? GetExitTime()
        {
            return string.IsNullOrEmpty(ExitTime) ? (DateTime?)null : DateTime.Parse(ExitTime);
        }

        public bool IsLong => Side == "LONG";
        public bool IsShort => Side == "SHORT";
        public bool IsClosed => !string.IsNullOrEmpty(ExitTime);

        public int GetPipsToTP(double pipSize)
        {
            if (!TakeProfit.HasValue) return 0;
            double diff = IsLong ? (TakeProfit.Value - EntryPrice) : (EntryPrice - TakeProfit.Value);
            return (int)Math.Round(diff / pipSize);
        }

        public int GetPipsToSL(double pipSize)
        {
            if (!StopLoss.HasValue) return 0;
            double diff = IsLong ? (EntryPrice - StopLoss.Value) : (StopLoss.Value - EntryPrice);
            return (int)Math.Round(diff / pipSize);
        }

        public double GetLiveRMultiple(double currentPrice)
        {
            if (!StopLoss.HasValue) return 0;

            double risk = Math.Abs(EntryPrice - StopLoss.Value);
            if (risk == 0) return 0;

            double profit = IsLong ? (currentPrice - EntryPrice) : (EntryPrice - currentPrice);
            return profit / risk;
        }
    }

    /// <summary>
    /// Color theme for dark mode chart
    /// </summary>
    public static class ChartColors
    {
        // Candle colors
        public static System.Windows.Media.Color BullishBody = System.Windows.Media.Color.FromRgb(0, 255, 0);      // Bright green
        public static System.Windows.Media.Color BullishWick = System.Windows.Media.Color.FromRgb(0, 153, 0);      // 30% darker
        public static System.Windows.Media.Color BearishBody = System.Windows.Media.Color.FromRgb(255, 0, 0);      // Red
        public static System.Windows.Media.Color BearishWick = System.Windows.Media.Color.FromRgb(153, 0, 0);      // 30% darker

        // Background & Grid
        public static System.Windows.Media.Color Background = System.Windows.Media.Color.FromRgb(0, 0, 0);         // Black
        public static System.Windows.Media.Color Grid = System.Windows.Media.Color.FromArgb(204, 204, 204, 204);   // 80% grey

        // Trade boxes (75% opacity)
        public static System.Windows.Media.Color TPBox = System.Windows.Media.Color.FromArgb(191, 0, 255, 0);      // Green 75%
        public static System.Windows.Media.Color SLBox = System.Windows.Media.Color.FromArgb(191, 255, 0, 0);      // Red 75%

        // Pending orders (90% opacity)
        public static System.Windows.Media.Color PendingBox = System.Windows.Media.Color.FromArgb(230, 128, 128, 128); // Grey 90%

        // Trade lines
        public static System.Windows.Media.Color WinLine = System.Windows.Media.Color.FromRgb(0, 255, 0);          // Green
        public static System.Windows.Media.Color LossLine = System.Windows.Media.Color.FromRgb(255, 0, 0);         // Red

        // Indicators
        public static System.Windows.Media.Color EmaFast = System.Windows.Media.Color.FromRgb(41, 98, 255);        // Blue
        public static System.Windows.Media.Color EmaMid = System.Windows.Media.Color.FromRgb(255, 109, 0);         // Orange
        public static System.Windows.Media.Color EmaSlow = System.Windows.Media.Color.FromRgb(156, 39, 176);       // Purple
    }
}
