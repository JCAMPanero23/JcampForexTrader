@echo off
REM Generate test signal files for CSMMonitor dashboard testing
REM Creates JSON files with component scores to test UI

set SIGNAL_PATH=C:\Users\Jcamp_Laptop\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files\CSM_Signals

echo.
echo ========================================
echo  Generating Test Signal Files
echo ========================================
echo.

REM ============================================================
REM EURUSD - BUY Signal with High Confidence (95/135)
REM Testing: All TrendRider components with bonuses
REM ============================================================
(
echo {
echo   "symbol": "EURUSD.r",
echo   "timestamp": "2026.02.07 01:30:00",
echo   "unix_time": 1770427800,
echo   "strategy": "TREND_RIDER",
echo   "signal": 1,
echo   "signal_text": "BUY",
echo   "confidence": 95,
echo   "analysis": "EMA+30 ADX+25 RSI+20 CSM+20",
echo   "csm_diff": 18.50,
echo   "regime": "REGIME_TRENDING",
echo   "dynamic_regime_triggered": false,
echo   "stop_loss_dollars": 50.00,
echo   "take_profit_dollars": 100.00,
echo   "components": {
echo     "ema_score": 30,
echo     "adx_score": 25,
echo     "rsi_score": 20,
echo     "csm_score": 20,
echo     "price_action_score": 0,
echo     "volume_score": 0,
echo     "mtf_score": 0,
echo     "proximity_score": 0,
echo     "rejection_score": 0,
echo     "stochastic_score": 0
echo   },
echo   "exported_at": "2026.02.07 01:30:00"
echo }
) > "%SIGNAL_PATH%\EURUSD.r_signals.json"
echo [1/4] EURUSD - BUY signal (95 confidence) - CREATED

REM ============================================================
REM GBPUSD - SELL Signal with Bonuses (120/135)
REM Testing: High confidence with bonus components
REM ============================================================
(
echo {
echo   "symbol": "GBPUSD.r",
echo   "timestamp": "2026.02.07 01:30:00",
echo   "unix_time": 1770427800,
echo   "strategy": "TREND_RIDER",
echo   "signal": -1,
echo   "signal_text": "SELL",
echo   "confidence": 120,
echo   "analysis": "EMA+30 ADX+25 RSI+20 CSM+25 PA+15 VOL+10 MTF+10",
echo   "csm_diff": -22.30,
echo   "regime": "REGIME_TRENDING",
echo   "dynamic_regime_triggered": false,
echo   "stop_loss_dollars": 50.00,
echo   "take_profit_dollars": 100.00,
echo   "components": {
echo     "ema_score": 30,
echo     "adx_score": 25,
echo     "rsi_score": 20,
echo     "csm_score": 25,
echo     "price_action_score": 15,
echo     "volume_score": 10,
echo     "mtf_score": 10,
echo     "proximity_score": 0,
echo     "rejection_score": 0,
echo     "stochastic_score": 0
echo   },
echo   "exported_at": "2026.02.07 01:30:00"
echo }
) > "%SIGNAL_PATH%\GBPUSD.r_signals.json"
echo [2/4] GBPUSD - SELL signal (120 confidence with bonuses) - CREATED

REM ============================================================
REM AUDJPY - NOT_TRADABLE (CSM Gate Blocked)
REM Testing: CSM gatekeeper blocking (no components expected)
REM ============================================================
(
echo {
echo   "symbol": "AUDJPY.r",
echo   "timestamp": "2026.02.07 01:30:00",
echo   "unix_time": 1770427800,
echo   "strategy": "NONE",
echo   "signal": 0,
echo   "signal_text": "NOT_TRADABLE",
echo   "confidence": 0,
echo   "analysis": "NOT_TRADABLE - CSM diff too low",
echo   "csm_diff": 12.40,
echo   "regime": "REGIME_TRENDING",
echo   "dynamic_regime_triggered": false,
echo   "stop_loss_dollars": 0.00,
echo   "take_profit_dollars": 0.00,
echo   "exported_at": "2026.02.07 01:30:00"
echo }
) > "%SIGNAL_PATH%\AUDJPY.r_signals.json"
echo [3/4] AUDJPY - NOT_TRADABLE (CSM blocked) - CREATED

REM ============================================================
REM XAUUSD - HOLD Signal (Gold TrendRider, partial components)
REM Testing: Signal=0 but strategy ran, showing what's missing
REM ============================================================
(
echo {
echo   "symbol": "XAUUSD.r",
echo   "timestamp": "2026.02.07 01:30:00",
echo   "unix_time": 1770427800,
echo   "strategy": "GOLD_TREND_RIDER",
echo   "signal": 0,
echo   "signal_text": "NEUTRAL",
echo   "confidence": 50,
echo   "analysis": "No EMA alignment",
echo   "csm_diff": 100.00,
echo   "regime": "REGIME_TRENDING",
echo   "dynamic_regime_triggered": false,
echo   "stop_loss_dollars": 0.00,
echo   "take_profit_dollars": 0.00,
echo   "components": {
echo     "ema_score": 0,
echo     "adx_score": 25,
echo     "rsi_score": 10,
echo     "csm_score": 25,
echo     "price_action_score": 0,
echo     "volume_score": 0,
echo     "mtf_score": 0,
echo     "proximity_score": 0,
echo     "rejection_score": 0,
echo     "stochastic_score": 0
echo   },
echo   "exported_at": "2026.02.07 01:30:00"
echo }
) > "%SIGNAL_PATH%\XAUUSD.r_signals.json"
echo [4/4] XAUUSD - HOLD signal (60 confidence, no EMA) - CREATED

echo.
echo ========================================
echo  Test Files Generated Successfully!
echo ========================================
echo.
echo Signal Files Created:
echo   - EURUSD: BUY @ 95 confidence
echo   - GBPUSD: SELL @ 120 confidence (with bonuses)
echo   - AUDJPY: NOT_TRADABLE (CSM blocked)
echo   - XAUUSD: HOLD @ 60 confidence (missing EMA)
echo.
echo Path: %SIGNAL_PATH%
echo.
echo Now open CSMMonitor to see the component data!
echo.
pause
