//+------------------------------------------------------------------+
//|                                                   IStrategy.mqh   |
//|                                            JcampForexTrader       |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Strategy Signal Result Structure                                 |
//+------------------------------------------------------------------+
struct StrategySignal
{
   int      signal;          // -1 = SELL, 0 = NEUTRAL, 1 = BUY
   int      confidence;      // Confidence score (0-100 or 0-135 depending on strategy)
   string   analysis;        // Breakdown of scoring components
   string   strategyName;    // Name of the strategy that generated this signal

   // Optional: ATR-based SL/TP (used by Gold strategy)
   double   stopLossDollars;    // Stop loss in dollars (0 = use default)
   double   takeProfitDollars;  // Take profit in dollars (0 = use default)

   // Component scores for detailed dashboard visualization
   // TrendRider components (0-135 total)
   int      emaScore;           // EMA Alignment: 0-30 points
   int      adxScore;           // ADX Strength: 0-25 points
   int      rsiScore;           // RSI Position: 0-20 points (shared with RangeRider)
   int      csmScore;           // CSM Support: 0-25 points (shared with RangeRider)
   int      priceActionScore;   // Price Action: 0-15 points (bonus)
   int      volumeScore;        // Volume: 0-10 points (bonus, shared with RangeRider)
   int      mtfScore;           // Multi-Timeframe: 0-10 points (bonus)

   // RangeRider components (0-100 total)
   int      proximityScore;     // Boundary Proximity: 0-15 points
   int      rejectionScore;     // Rejection Pattern: 0-15 points
   int      stochasticScore;    // Stochastic: 0-15 points
   // Note: rsiScore, csmScore, volumeScore are shared between strategies
};

//+------------------------------------------------------------------+
//| Interface: IStrategy                                              |
//| Purpose: Base interface for all trading strategies               |
//+------------------------------------------------------------------+
class IStrategy
{
public:
   // Virtual destructor
   virtual ~IStrategy() {}

   // Analyze market and generate trading signal
   // Parameters:
   //   symbol       - Trading symbol (e.g., "EURUSD")
   //   timeframe    - Analysis timeframe
   //   csmDiff      - CSM difference (baseCurrency - quoteCurrency)
   //   result       - Output: signal, confidence, and analysis
   // Returns:
   //   true if signal generated, false otherwise
   virtual bool Analyze(string symbol,
                       ENUM_TIMEFRAMES timeframe,
                       double csmDiff,
                       StrategySignal &result) = 0;

   // Get strategy name
   virtual string GetName() = 0;

   // Get minimum confidence threshold for this strategy
   virtual int GetMinConfidence() = 0;

   // Check if signal meets minimum confidence threshold
   virtual bool IsValidSignal(const StrategySignal &signal)
   {
      return (signal.signal != 0 && signal.confidence >= GetMinConfidence());
   }
};

//+------------------------------------------------------------------+
