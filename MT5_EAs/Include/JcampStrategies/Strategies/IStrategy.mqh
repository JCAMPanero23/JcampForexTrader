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
