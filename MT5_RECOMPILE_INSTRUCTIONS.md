# MT5 EA Recompile Instructions

## Why Recompile is Needed

The PerformanceTracker.mqh file was enhanced to export SL, TP, and Entry Time data.
The current positions.txt file (from Jan 23) uses the OLD format without these fields.

## Steps to Recompile and Deploy

### 1. Open MetaEditor
- In MT5 Terminal, press **F4** (or Tools → MetaQuotes Language Editor)

### 2. Open the Main Trading EA
- Navigate to: **Experts → Jcamp → Jcamp_MainTradingEA.mq5**
- Or use: File → Open → Browse to the symlinked location

### 3. Compile
- Press **F7** (or Build → Compile)
- Check for errors in the "Errors" tab (should be 0 errors)
- You should see: "0 error(s), 0 warning(s)" or similar

### 4. Restart the EA in MT5 Terminal

**Option A: Remove and Re-add**
1. In MT5, find the chart where MainTradingEA is running
2. Right-click chart → Expert Advisors → Remove
3. Drag Jcamp_MainTradingEA.ex5 from Navigator back onto the chart
4. Click "Allow Algo Trading" → OK

**Option B: Refresh**
1. In Navigator panel, right-click "Expert Advisors" → Refresh
2. The recompiled .ex5 will reload automatically on next tick

### 5. Verify Fresh Export

After EA runs (when market reopens or ticks occur):
```
Check file timestamp:
C:\Users\Jcamp_Laptop\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files\CSM_Data\positions.txt
```

**New format should look like:**
```
Ticket: 123456 | EURUSD.sml BUY | Lots: 0.19 | Entry: 1.17912 | Current: 1.18288 | SL: 1.17412 | TP: 1.18912 | P&L: $71.44 | Time: 2026.01.25 15:30
```

### 6. Restart CSM Monitor

Once fresh data is exported:
```
D:\JcampForexTrader\CSMMonitor\bin\Debug\net8.0-windows\JcampForexTrader.exe
```

## Expected Results

After recompile + fresh export:
- ✅ Stop Loss: Actual prices (not N/A)
- ✅ Take Profit: Actual prices (not N/A)
- ✅ R-Multiple: Calculated values (not N/A)
- ✅ Risk Amount: Calculated $ amounts (not N/A)
- ✅ Entry Time: Timestamps (not N/A)

## Troubleshooting

**If data still shows N/A:**
1. Check Experts tab in MT5 for errors
2. Verify EA is running (green "AutoTrading" button)
3. Wait for market activity (weekend = no ticks = no exports)
4. Check file timestamp to confirm fresh export

**If market is closed:**
- Forex markets closed on weekends
- EA only exports on tick events
- Wait until Sunday evening when market reopens
