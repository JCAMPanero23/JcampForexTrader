# PowerShell script to integrate SmartOrderManager into MainTradingEA.mq5
# Session 20 - Smart Pending Order System

$backupFile = "D:\JcampForexTrader\MT5_EAs\Experts\Jcamp_MainTradingEA.mq5.backup"
$outputFile = "D:\JcampForexTrader\MT5_EAs\Experts\Jcamp_MainTradingEA.mq5"

Write-Host "Reading backup file..." -ForegroundColor Cyan
$content = Get-Content -Path $backupFile -Raw -Encoding UTF8

Write-Host "Applying modifications..." -ForegroundColor Cyan

# 1. Add SmartOrderManager include
$content = $content -replace '#include <JcampStrategies/Trading/PerformanceTracker.mqh>',
'#include <JcampStrategies/Trading/PerformanceTracker.mqh>
#include <JcampStrategies/Trading/SmartOrderManager.mqh>  // Session 20: Smart Pending Orders'

# 2. Update version
$content = $content -replace '#property version   "2.10"', '#property version   "3.00"'

# 3. Update description
$content = $content -replace 'CSM Alpha Main Trading EA - 5 Asset System \(Session 19\)',
'CSM Alpha Main Trading EA - Session 20: Smart Pending Orders'

# 4. Add smart pending parameters
$smartParams = @'

// --- Smart Pending Order System (Session 20) ---
input group "SMART PENDING ORDER SYSTEM"
input bool   UseSmartPending = true;                    // Enable Smart Pending Orders
input int    RetracementTriggerPips = 3;                // Retracement entry: EMA20 + X pips
input int    ExtensionThresholdPips = 15;               // Price > EMA20 + X = extended (use retracement)
input int    MaxRetracementPips = 30;                   // Cancel if price retraces beyond this
input int    SwingLookbackBars = 20;                    // Bars to find swing high/low
input int    BreakoutTriggerPips = 1;                   // Breakout entry: Swing + X pips
input int    MaxSwingDistancePips = 30;                 // Max distance to swing (use market if farther)
input int    RetracementExpiryHours = 4;                // Retracement order expiry time
input int    BreakoutExpiryHours = 8;                   // Breakout order expiry time
'@

$content = $content -replace '(input int MaxTotalPositions = 3;)', "`$1`n$smartParams"

# 5. Add SmartOrderManager global variable
$content = $content -replace '(PerformanceTracker\* performanceTracker;)',
"`$1`nSmartOrderManager*  smartOrderManager;   // Session 20: Smart pending orders"

Write-Host "Writing output file..." -ForegroundColor Cyan
$content | Out-File -FilePath $outputFile -Encoding UTF8 -NoNewline

Write-Host "Part 1 Complete! File structure updated." -ForegroundColor Green
Write-Host "Now run Part 2 to update OnInit(), OnTick(), and CheckAndExecuteSignals()" -ForegroundColor Yellow
