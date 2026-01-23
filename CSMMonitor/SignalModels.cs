using System;
using Newtonsoft.Json;

namespace JcampForexTrader
{
    // Root JSON structure matching MQL5 Strategy EA output
    public class SignalFileData
    {
        [JsonProperty("timestamp")]
        public string Timestamp { get; set; }

        [JsonProperty("symbol")]
        public string Symbol { get; set; }

        [JsonProperty("current_price")]
        public double CurrentPrice { get; set; }

        [JsonProperty("csm_data")]
        public CsmData CsmData { get; set; }

        [JsonProperty("trend_rider")]
        public StrategySignal TrendRider { get; set; }

        [JsonProperty("impulse_pullback")]
        public StrategySignal ImpulsePullback { get; set; }

        [JsonProperty("breakout_retest")]
        public StrategySignal BreakoutRetest { get; set; }

        [JsonProperty("overall_assessment")]
        public OverallAssessment OverallAssessment { get; set; }
    }

    public class CsmData
    {
        [JsonProperty("base_currency")]
        public string BaseCurrency { get; set; }

        [JsonProperty("quote_currency")]
        public string QuoteCurrency { get; set; }

        [JsonProperty("base_strength")]
        public double BaseStrength { get; set; }

        [JsonProperty("quote_strength")]
        public double QuoteStrength { get; set; }

        [JsonProperty("strength_differential")]
        public double StrengthDifferential { get; set; }

        [JsonProperty("csm_trend")]
        public string CsmTrend { get; set; }
    }

    public class StrategySignal
    {
        [JsonProperty("signal")]
        public string Signal { get; set; }

        [JsonProperty("confidence")]
        public int Confidence { get; set; }

        [JsonProperty("entry_price")]
        public double EntryPrice { get; set; }

        [JsonProperty("stop_loss")]
        public double StopLoss { get; set; }

        [JsonProperty("take_profit")]
        public double TakeProfit { get; set; }

        [JsonProperty("risk_reward")]
        public double RiskReward { get; set; }

        [JsonProperty("csm_confirmation")]
        public bool CsmConfirmation { get; set; }

        [JsonProperty("csm_differential")]
        public double CsmDifferential { get; set; }

        [JsonProperty("reasoning")]
        public string Reasoning { get; set; }

        [JsonProperty("component_scores")]
        public ComponentScores ComponentScores { get; set; }
    }

    public class ComponentScores
    {
        // Trend Rider components
        [JsonProperty("ema_align")]
        public int? EmaAlign { get; set; }

        [JsonProperty("adx")]
        public int? Adx { get; set; }

        [JsonProperty("rsi")]
        public int? Rsi { get; set; }

        [JsonProperty("csm")]
        public int? Csm { get; set; }

        // Impulse Pullback components
        [JsonProperty("impulse")]
        public int? Impulse { get; set; }

        [JsonProperty("fib")]
        public int? Fib { get; set; }

        // Breakout & Retest components
        [JsonProperty("level")]
        public int? Level { get; set; }

        [JsonProperty("breakout")]
        public int? Breakout { get; set; }

        [JsonProperty("volume")]
        public int? Volume { get; set; }

        [JsonProperty("retest")]
        public int? Retest { get; set; }
    }

    public class OverallAssessment
    {
        [JsonProperty("best_strategy")]
        public string BestStrategy { get; set; }

        [JsonProperty("highest_confidence")]
        public int HighestConfidence { get; set; }

        [JsonProperty("recommended_action")]
        public string RecommendedAction { get; set; }

        [JsonProperty("overall_ranking")]
        public double OverallRanking { get; set; }

        [JsonProperty("last_update")]
        public string LastUpdate { get; set; }
    }
}