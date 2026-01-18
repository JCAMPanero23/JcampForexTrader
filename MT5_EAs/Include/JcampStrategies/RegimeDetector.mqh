//+------------------------------------------------------------------+
//|                                           RegimeDetector.mqh     |
//|                                   Jcamp Forex Trading System     |
//+------------------------------------------------------------------+
//| Description: Market regime detection using competitive scoring   |
//| Usage: #include <JcampStrategies/RegimeDetector.mqh>             |
//|                                                                   |
//| Scoring System (100-point competitive):                          |
//|   - ADX Analysis: 0-30 points                                    |
//|   - EMA Separation: 0-25 points                                  |
//|   - ATR Volatility: 0-20 points                                  |
//|   - Price Action: 0-25 points                                    |
//+------------------------------------------------------------------+

// Include indicator calculators
#include <JcampStrategies/Indicators/EmaCalculator.mqh>
#include <JcampStrategies/Indicators/AdxCalculator.mqh>
#include <JcampStrategies/Indicators/AtrCalculator.mqh>

//+------------------------------------------------------------------+
//| Market Regime Enumeration                                        |
//+------------------------------------------------------------------+
enum MARKET_REGIME
{
    REGIME_TRENDING,      // Clear directional trend
    REGIME_RANGING,       // Choppy sideways market
    REGIME_TRANSITIONAL   // Uncertain/mixed signals
};

//+------------------------------------------------------------------+
//| Calculate ATR expansion/contraction ratio                        |
//| Returns: Current ATR vs 10-bar average (1.0 = neutral)          |
//+------------------------------------------------------------------+
double CalculateATRRatio(string symbol, ENUM_TIMEFRAMES tf)
{
    double atr[];
    ArraySetAsSeries(atr, true);

    int handle = iATR(symbol, tf, 14);
    if(handle == INVALID_HANDLE) return 1.0;

    if(CopyBuffer(handle, 0, 0, 20, atr) <= 0)
    {
        IndicatorRelease(handle);
        return 1.0;
    }

    IndicatorRelease(handle);

    // Current ATR vs average of last 10 bars
    double currentATR = atr[0];
    double avgATR = 0;

    for(int i = 1; i <= 10; i++)
    {
        avgATR += atr[i];
    }
    avgATR /= 10.0;

    if(avgATR == 0) return 1.0;

    return currentATR / avgATR;
}

//+------------------------------------------------------------------+
//| Analyze price action for regime detection                        |
//| Returns: Score contribution (-25 to +25)                         |
//+------------------------------------------------------------------+
int AnalyzePriceActionRegime(string symbol, ENUM_TIMEFRAMES tf)
{
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);

    if(CopyHigh(symbol, tf, 0, 20, high) <= 0) return 0;
    if(CopyLow(symbol, tf, 0, 20, low) <= 0) return 0;
    if(CopyClose(symbol, tf, 0, 20, close) <= 0) return 0;

    // Count higher highs/higher lows (trending) vs inside bars (ranging)
    int higherHighs = 0;
    int lowerLows = 0;
    int insideBars = 0;

    for(int i = 1; i < 10; i++)
    {
        // Higher high
        if(high[i] > high[i+1])
            higherHighs++;

        // Lower low
        if(low[i] < low[i+1])
            lowerLows++;

        // Inside bar
        if(high[i] < high[i+1] && low[i] > low[i+1])
            insideBars++;
    }

    // Calculate recent range
    double recentHigh = high[0];
    double recentLow = low[0];

    for(int i = 1; i < 10; i++)
    {
        if(high[i] > recentHigh) recentHigh = high[i];
        if(low[i] < recentLow) recentLow = low[i];
    }

    double recentRange = recentHigh - recentLow;
    double currentPrice = close[0];
    double rangePercent = (currentPrice - recentLow) / recentRange;

    // Trending indicators
    if((higherHighs >= 6 || lowerLows >= 6) && insideBars <= 2)
    {
        return 25;  // Strong trend
    }
    else if((higherHighs >= 4 || lowerLows >= 4) && insideBars <= 3)
    {
        return 15;  // Moderate trend
    }
    // Ranging indicators
    else if(insideBars >= 4 || (rangePercent > 0.3 && rangePercent < 0.7))
    {
        return -25;  // Strong range
    }
    else if(insideBars >= 2)
    {
        return -15;  // Moderate range
    }

    return 0;  // Neutral
}

//+------------------------------------------------------------------+
//| Detect market regime using multi-factor analysis                 |
//| Parameters:                                                       |
//|   symbol - Trading pair                                          |
//|   trendingThreshold - Min % for TRENDING classification (55)     |
//|   rangingThreshold - Min % for RANGING classification (40)       |
//|   minADXForTrending - Min ADX value for strong trend (30)        |
//|   verboseLogging - Print detailed scoring breakdown              |
//| Returns: MARKET_REGIME enum                                      |
//+------------------------------------------------------------------+
MARKET_REGIME DetectMarketRegime(string symbol,
                                  double trendingThreshold = 55.0,
                                  double rangingThreshold = 40.0,
                                  double minADXForTrending = 30.0,
                                  bool verboseLogging = false)
{
    if(verboseLogging)
    {
        Print("\n╔════════════════════════════════════════════════════════════╗");
        Print("║              REGIME DETECTION ANALYSIS                    ║");
        Print("╚════════════════════════════════════════════════════════════╝");
        Print("Symbol: ", symbol);
    }

    // Get indicators from current timeframe (H1) and higher timeframe (H4)
    double adx_h1 = GetADX(symbol, PERIOD_H1, 14);
    double adx_h4 = GetADX(symbol, PERIOD_H4, 14);

    double ema20_h1 = GetEMA(symbol, PERIOD_H1, 20);
    double ema50_h1 = GetEMA(symbol, PERIOD_H1, 50);
    double ema100_h1 = GetEMA(symbol, PERIOD_H1, 100);

    double ema20_h4 = GetEMA(symbol, PERIOD_H4, 20);
    double ema50_h4 = GetEMA(symbol, PERIOD_H4, 50);

    double atr_h1 = GetATR(symbol, PERIOD_H1, 14);
    double atr_h4 = GetATR(symbol, PERIOD_H4, 14);

    // Calculate EMA separation (trend clarity indicator)
    double ema_sep_h1 = CalculateEMASeparation(symbol, ema20_h1, ema50_h1, ema100_h1);
    double ema_sep_h4 = CalculateEMASeparation(symbol, ema20_h4, ema50_h4, 0);

    // Calculate ATR expansion/contraction
    double atr_ratio = CalculateATRRatio(symbol, PERIOD_H1);

    // Score each component
    int trendingScore = 0;
    int rangingScore = 0;

    // ═══════════════════════════════════════════════════════════════
    // COMPONENT 1: ADX Analysis (Trend Strength)
    // ═══════════════════════════════════════════════════════════════

    if(adx_h1 > minADXForTrending && adx_h4 > minADXForTrending)
    {
        trendingScore += 30;  // Strong trend on both timeframes
        if(verboseLogging)
            Print("  ✓ ADX: TRENDING (+30) - H1:", DoubleToString(adx_h1, 1), " H4:", DoubleToString(adx_h4, 1));
    }
    else if(adx_h1 > 25 || adx_h4 > 25)
    {
        trendingScore += 15;  // Trend on one timeframe
        if(verboseLogging)
            Print("  ✓ ADX: WEAK TREND (+15) - H1:", DoubleToString(adx_h1, 1), " H4:", DoubleToString(adx_h4, 1));
    }
    else if(adx_h1 < 20 && adx_h4 < 20)
    {
        rangingScore += 30;   // Weak ADX = ranging
        if(verboseLogging)
            Print("  ✓ ADX: RANGING (+30) - H1:", DoubleToString(adx_h1, 1), " H4:", DoubleToString(adx_h4, 1));
    }
    else
    {
        rangingScore += 15;   // Mixed ADX
        if(verboseLogging)
            Print("  ✓ ADX: MIXED (+15) - H1:", DoubleToString(adx_h1, 1), " H4:", DoubleToString(adx_h4, 1));
    }

    // ═══════════════════════════════════════════════════════════════
    // COMPONENT 2: EMA Separation (Trend Clarity)
    // ═══════════════════════════════════════════════════════════════

    // Analyze H1 EMA separation (primary - 60% weight = 15 points max)
    if(ema_sep_h1 > 0.5)
    {
        trendingScore += 15;  // Wide H1 EMA = trending
    }
    else if(ema_sep_h1 > 0.3)
    {
        trendingScore += 8;   // Moderate H1 EMA = weak trend
    }
    else if(ema_sep_h1 < 0.2)
    {
        rangingScore += 15;   // Tight H1 EMA = ranging
    }
    else
    {
        rangingScore += 8;    // H1 mixed
    }

    // Analyze H4 EMA separation (confirmation - 40% weight = 10 points max)
    if(ema_sep_h4 > 0.5)
    {
        trendingScore += 10;  // H4 confirms trend
    }
    else if(ema_sep_h4 > 0.3)
    {
        trendingScore += 5;   // H4 weak trend
    }
    else if(ema_sep_h4 < 0.2)
    {
        rangingScore += 10;   // H4 confirms ranging
    }
    else
    {
        rangingScore += 5;    // H4 mixed
    }

    if(verboseLogging)
    {
        Print("  ✓ EMA: H1:", DoubleToString(ema_sep_h1, 2), "% H4:", DoubleToString(ema_sep_h4, 2), "%");
        Print("          H1 contribution: ",
                    (ema_sep_h1 < 0.2 ? "RANGING" : (ema_sep_h1 > 0.5 ? "TRENDING" : "MIXED")));
        Print("          H4 contribution: ",
                    (ema_sep_h4 < 0.2 ? "RANGING" : (ema_sep_h4 > 0.5 ? "TRENDING" : "MIXED")));
    }

    // ═══════════════════════════════════════════════════════════════
    // COMPONENT 3: ATR Volatility Analysis
    // ═══════════════════════════════════════════════════════════════

    if(atr_ratio > 1.2)
    {
        trendingScore += 20;  // Expanding volatility = trending
        if(verboseLogging)
            Print("  ✓ ATR: TRENDING (+20) - Ratio:", DoubleToString(atr_ratio, 2));
    }
    else if(atr_ratio > 1.0)
    {
        trendingScore += 10;
        if(verboseLogging)
            Print("  ✓ ATR: NEUTRAL (+10) - Ratio:", DoubleToString(atr_ratio, 2));
    }
    else if(atr_ratio < 0.8)
    {
        rangingScore += 20;   // Contracting volatility = ranging
        if(verboseLogging)
            Print("  ✓ ATR: RANGING (+20) - Ratio:", DoubleToString(atr_ratio, 2));
    }
    else
    {
        rangingScore += 10;
        if(verboseLogging)
            Print("  ✓ ATR: NEUTRAL (+10) - Ratio:", DoubleToString(atr_ratio, 2));
    }

    // ═══════════════════════════════════════════════════════════════
    // COMPONENT 4: Price Action Pattern (Recent bars analysis)
    // ═══════════════════════════════════════════════════════════════

    int paScore = AnalyzePriceActionRegime(symbol, PERIOD_H1);

    if(paScore > 0)
    {
        trendingScore += paScore;
        if(verboseLogging)
            Print("  ✓ PA: TRENDING (+", paScore, ")");
    }
    else if(paScore < 0)
    {
        rangingScore += MathAbs(paScore);
        if(verboseLogging)
            Print("  ✓ PA: RANGING (+", MathAbs(paScore), ")");
    }

    // ═══════════════════════════════════════════════════════════════
    // FINAL CLASSIFICATION
    // ═══════════════════════════════════════════════════════════════

    // Calculate total score
    int totalScore = trendingScore + rangingScore;

    // Calculate percentages
    double trendingPercent = (totalScore > 0) ? (trendingScore * 100.0 / totalScore) : 50.0;
    double rangingPercent = (totalScore > 0) ? (rangingScore * 100.0 / totalScore) : 50.0;

    MARKET_REGIME regime = REGIME_TRANSITIONAL;

    // ═══════════════════════════════════════════════════════════════
    // NEW LOGIC: Check for close scores first (within 5% = transitional)
    // ═══════════════════════════════════════════════════════════════

    double percentDiff = MathAbs(trendingPercent - rangingPercent);

    // If scores are very close (within 5%), it's TRANSITIONAL
    if(percentDiff < 5.0)
    {
        regime = REGIME_TRANSITIONAL;

        if(verboseLogging)
        {
            Print("⚠ Scores too close (", DoubleToString(percentDiff, 1),
                        "% difference) → TRANSITIONAL");
        }
    }
    // Clear trending market - REQUIRES STRONG SIGNALS
    else if(trendingPercent >= trendingThreshold)
    {
        regime = REGIME_TRENDING;
    }
    // Clear ranging market - MORE LENIENT
    else if(rangingPercent >= rangingThreshold)
    {
        regime = REGIME_RANGING;
    }
    // Default to transitional if neither threshold met
    else
    {
        regime = REGIME_TRANSITIONAL;
    }

    if(verboseLogging)
    {
        Print("\n═══ REGIME CLASSIFICATION ═══");
        Print("Trending Score: ", trendingScore, " (", DoubleToString(trendingPercent, 1), "%)");
        Print("Ranging Score: ", rangingScore, " (", DoubleToString(rangingPercent, 1), "%)");
        Print("Score Difference: ", DoubleToString(percentDiff, 1), "%");
        Print("REGIME: ", regime == REGIME_TRENDING ? "TRENDING" :
                                regime == REGIME_RANGING ? "RANGING" : "TRANSITIONAL");
        Print("═════════════════════════════\n");
    }

    return regime;
}
