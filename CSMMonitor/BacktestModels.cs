using System;
using System.Collections.Generic;
using Newtonsoft.Json;

namespace JcampForexTrader.Backtest
{
    // Request Models
    public class BacktestRequest
    {
        [JsonProperty("symbol")]
        public string Symbol { get; set; }

        [JsonProperty("start_date")]
        public string StartDate { get; set; }

        [JsonProperty("end_date")]
        public string EndDate { get; set; }

        [JsonProperty("strategy")]
        public string Strategy { get; set; } = "both";

        [JsonProperty("initial_balance")]
        public double InitialBalance { get; set; } = 10000.0;

        [JsonProperty("risk_percent")]
        public double RiskPercent { get; set; } = 2.0;

        [JsonProperty("max_positions")]
        public int MaxPositions { get; set; } = 2;
    }

    // Response Models
    public class BacktestResponse
    {
        [JsonProperty("task_id")]
        public string TaskId { get; set; }

        [JsonProperty("status")]
        public string Status { get; set; }
    }

    public class BacktestStatus
    {
        [JsonProperty("task_id")]
        public string TaskId { get; set; }

        [JsonProperty("status")]
        public string Status { get; set; }

        [JsonProperty("progress")]
        public double Progress { get; set; }

        [JsonProperty("message")]
        public string Message { get; set; }

        [JsonProperty("eta_seconds")]
        public int? EtaSeconds { get; set; }

        [JsonProperty("started_at")]
        public string StartedAt { get; set; }

        [JsonProperty("completed_at")]
        public string CompletedAt { get; set; }
    }

    public class BacktestResults
    {
        [JsonProperty("task_id")]
        public string TaskId { get; set; }

        [JsonProperty("symbol")]
        public string Symbol { get; set; }

        [JsonProperty("start_date")]
        public string StartDate { get; set; }

        [JsonProperty("end_date")]
        public string EndDate { get; set; }

        [JsonProperty("strategy")]
        public string Strategy { get; set; }

        [JsonProperty("initial_balance")]
        public double InitialBalance { get; set; }

        [JsonProperty("final_balance")]
        public double FinalBalance { get; set; }

        [JsonProperty("net_profit")]
        public double NetProfit { get; set; }

        [JsonProperty("return_pct")]
        public double ReturnPct { get; set; }

        [JsonProperty("total_trades")]
        public int TotalTrades { get; set; }

        [JsonProperty("winning_trades")]
        public int WinningTrades { get; set; }

        [JsonProperty("losing_trades")]
        public int LosingTrades { get; set; }

        [JsonProperty("win_rate")]
        public double WinRate { get; set; }

        [JsonProperty("total_r")]
        public double TotalR { get; set; }

        [JsonProperty("avg_r")]
        public double AvgR { get; set; }

        [JsonProperty("max_r")]
        public double MaxR { get; set; }

        [JsonProperty("min_r")]
        public double MinR { get; set; }

        [JsonProperty("max_drawdown_pct")]
        public double MaxDrawdownPct { get; set; }

        [JsonProperty("max_drawdown_dollars")]
        public double MaxDrawdownDollars { get; set; }

        [JsonProperty("profit_factor")]
        public double ProfitFactor { get; set; }

        [JsonProperty("sharpe_ratio")]
        public double SharpeRatio { get; set; }

        [JsonProperty("max_consecutive_wins")]
        public int MaxConsecutiveWins { get; set; }

        [JsonProperty("max_consecutive_losses")]
        public int MaxConsecutiveLosses { get; set; }

        [JsonProperty("trend_rider")]
        public StrategyBreakdown TrendRider { get; set; }

        [JsonProperty("range_rider")]
        public StrategyBreakdown RangeRider { get; set; }

        [JsonProperty("trades")]
        public List<TradeRecord> Trades { get; set; }

        [JsonProperty("equity_curve")]
        public List<EquityPoint> EquityCurve { get; set; }
    }

    public class StrategyBreakdown
    {
        [JsonProperty("trades")]
        public int Trades { get; set; }

        [JsonProperty("wins")]
        public int Wins { get; set; }

        [JsonProperty("losses")]
        public int Losses { get; set; }

        [JsonProperty("total_r")]
        public double TotalR { get; set; }

        [JsonProperty("total_pl")]
        public double TotalPL { get; set; }

        [JsonProperty("win_rate")]
        public double WinRate { get; set; }

        [JsonProperty("avg_r")]
        public double AvgR { get; set; }
    }

    public class TradeRecord
    {
        [JsonProperty("position_id")]
        public int PositionId { get; set; }

        [JsonProperty("symbol")]
        public string Symbol { get; set; }

        [JsonProperty("side")]
        public string Side { get; set; }

        [JsonProperty("strategy")]
        public string Strategy { get; set; }

        [JsonProperty("confidence")]
        public double Confidence { get; set; }

        [JsonProperty("regime")]
        public string Regime { get; set; }

        [JsonProperty("entry_time")]
        public string EntryTime { get; set; }

        [JsonProperty("exit_time")]
        public string ExitTime { get; set; }

        [JsonProperty("entry_price")]
        public double EntryPrice { get; set; }

        [JsonProperty("exit_price")]
        public double? ExitPrice { get; set; }

        [JsonProperty("stop_loss")]
        public double StopLoss { get; set; }

        [JsonProperty("take_profit")]
        public double? TakeProfit { get; set; }

        [JsonProperty("r_multiple")]
        public double? RMultiple { get; set; }

        [JsonProperty("profit_loss")]
        public double? ProfitLoss { get; set; }

        [JsonProperty("exit_reason")]
        public string ExitReason { get; set; }
    }

    public class EquityPoint
    {
        [JsonProperty("timestamp")]
        public string Timestamp { get; set; }

        [JsonProperty("balance")]
        public double Balance { get; set; }

        [JsonProperty("r_multiple")]
        public double RMultiple { get; set; }

        [JsonProperty("cumulative_r")]
        public double CumulativeR { get; set; }

        [JsonProperty("strategy")]
        public string Strategy { get; set; }
    }

    public class HealthResponse
    {
        [JsonProperty("status")]
        public string Status { get; set; }

        [JsonProperty("version")]
        public string Version { get; set; }

        [JsonProperty("uptime_seconds")]
        public int UptimeSeconds { get; set; }
    }

    public class InfoResponse
    {
        [JsonProperty("version")]
        public string Version { get; set; }

        [JsonProperty("features")]
        public List<string> Features { get; set; }

        [JsonProperty("supported_symbols")]
        public List<string> SupportedSymbols { get; set; }

        [JsonProperty("supported_strategies")]
        public List<string> SupportedStrategies { get; set; }

        [JsonProperty("data_available")]
        public Dictionary<string, string> DataAvailable { get; set; }
    }

    // Multi-Pair Backtest Models (Phase 8.2)
    public class MultiPairBacktestRequest
    {
        [JsonProperty("pairs")]
        public List<string> Pairs { get; set; }

        [JsonProperty("strategies")]
        public List<string> Strategies { get; set; }

        [JsonProperty("start_date")]
        public string StartDate { get; set; }

        [JsonProperty("end_date")]
        public string EndDate { get; set; }

        [JsonProperty("timeframe")]
        public string Timeframe { get; set; } = "M15";

        [JsonProperty("config")]
        public BacktestConfig Config { get; set; }
    }

    public class BacktestConfig
    {
        [JsonProperty("initial_balance")]
        public double InitialBalance { get; set; } = 10000.0;

        [JsonProperty("risk_percent")]
        public double RiskPercent { get; set; } = 0.02;

        [JsonProperty("max_concurrent_positions")]
        public int MaxConcurrentPositions { get; set; } = 2;

        [JsonProperty("min_confidence")]
        public double MinConfidence { get; set; } = 50.0;

        [JsonProperty("take_profit_r")]
        public double TakeProfitR { get; set; } = 2.0;
    }

    public class MultiPairBacktestResults
    {
        [JsonProperty("trades")]
        public List<TradeRecord> Trades { get; set; }

        [JsonProperty("statistics")]
        public Statistics Statistics { get; set; }

        [JsonProperty("equity_curve")]
        public List<EquityPoint> EquityCurve { get; set; }

        [JsonProperty("pair_breakdown")]
        public Dictionary<string, PairStatistics> PairBreakdown { get; set; }

        [JsonProperty("strategy_breakdown")]
        public Dictionary<string, StrategyStatistics> StrategyBreakdown { get; set; }

        [JsonProperty("pair_chart_data")]
        public Dictionary<string, ChartData> PairChartData { get; set; }
    }

    public class Statistics
    {
        [JsonProperty("total_trades")]
        public int TotalTrades { get; set; }

        [JsonProperty("wins")]
        public int Wins { get; set; }

        [JsonProperty("losses")]
        public int Losses { get; set; }

        [JsonProperty("win_rate")]
        public double WinRate { get; set; }

        [JsonProperty("total_r")]
        public double TotalR { get; set; }

        [JsonProperty("avg_r")]
        public double AvgR { get; set; }

        [JsonProperty("max_drawdown")]
        public double MaxDrawdown { get; set; }

        [JsonProperty("sharpe_ratio")]
        public double SharpeRatio { get; set; }

        [JsonProperty("initial_balance")]
        public double InitialBalance { get; set; }

        [JsonProperty("final_balance")]
        public double FinalBalance { get; set; }

        [JsonProperty("net_profit")]
        public double NetProfit { get; set; }

        [JsonProperty("return_percent")]
        public double ReturnPercent { get; set; }
    }

    public class PairStatistics
    {
        [JsonProperty("trades")]
        public int Trades { get; set; }

        [JsonProperty("win_rate")]
        public double WinRate { get; set; }

        [JsonProperty("total_r")]
        public double TotalR { get; set; }
    }

    public class StrategyStatistics
    {
        [JsonProperty("trades")]
        public int Trades { get; set; }

        [JsonProperty("win_rate")]
        public double WinRate { get; set; }

        [JsonProperty("total_r")]
        public double TotalR { get; set; }
    }

    public class ChartData
    {
        [JsonProperty("symbol")]
        public string Symbol { get; set; }

        [JsonProperty("m15_candles")]
        public List<CandleData> M15Candles { get; set; }

        [JsonProperty("m1_candles")]
        public List<CandleData> M1Candles { get; set; }
    }

    // Note: CandleData is already defined in OhlcModels.cs
}
