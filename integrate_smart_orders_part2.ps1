# PowerShell script Part 2: Update functions in MainTradingEA.mq5
# Session 20 - Smart Pending Order System

$inputFile = "D:\JcampForexTrader\MT5_EAs\Experts\Jcamp_MainTradingEA.mq5"

Write-Host "Reading current file..." -ForegroundColor Cyan
$content = Get-Content -Path $inputFile -Raw -Encoding UTF8

Write-Host "Applying function modifications..." -ForegroundColor Cyan

# 1. Update OnInit() - Add smart pending info and initialization
$onInitOld = @'
   Print("Jcamp MainTradingEA - Initializing");
   Print("========================================");
'@

$onInitNew = @'
   Print("Jcamp MainTradingEA v3.00 - Initializing");
   Print("Session 20: Smart Pending Order System");
   Print("========================================");
'@

$content = $content -replace [regex]::Escape($onInitOld), $onInitNew

# Add Smart Pending status to OnInit() log
$onInitLog = @'
   Print("Magic Number: ", MagicNumber);
'@

$onInitLogNew = @'
   Print("Magic Number: ", MagicNumber);
   Print("Smart Pending Orders: ", (UseSmartPending ? "ENABLED" : "DISABLED"));
   if(UseSmartPending)
   {
      Print("  - Retracement Trigger: EMA20 + ", RetracementTriggerPips, " pips");
      Print("  - Extension Threshold: ", ExtensionThresholdPips, " pips");
      Print("  - Breakout Trigger: Swing + ", BreakoutTriggerPips, " pip");
      Print("  - Retracement Expiry: ", RetracementExpiryHours, " hours");
      Print("  - Breakout Expiry: ", BreakoutExpiryHours, " hours");
   }
'@

$content = $content -replace [regex]::Escape($onInitLog), $onInitLogNew

# Initialize SmartOrderManager in OnInit()
$performInit = @'
   performanceTracker = new PerformanceTracker(ExportFolder, MagicNumber, VerboseLogging);

   // Verify modules initialized
'@

$performInitNew = @'
   performanceTracker = new PerformanceTracker(ExportFolder, MagicNumber, VerboseLogging);

   // Session 20: Initialize Smart Order Manager
   smartOrderManager = new SmartOrderManager(MagicNumber,
                                             VerboseLogging,
                                             RetracementTriggerPips,
                                             ExtensionThresholdPips,
                                             MaxRetracementPips,
                                             SwingLookbackBars,
                                             BreakoutTriggerPips,
                                             MaxSwingDistancePips,
                                             RetracementExpiryHours,
                                             BreakoutExpiryHours);

   // Verify modules initialized
'@

$content = $content -replace [regex]::Escape($performInit), $performInitNew

# Update verification check in OnInit()
$verifyOld = @'
   if(signalReader == NULL || tradeExecutor == NULL ||
      positionManager == NULL || performanceTracker == NULL)
'@

$verifyNew = @'
   if(signalReader == NULL || tradeExecutor == NULL ||
      positionManager == NULL || performanceTracker == NULL ||
      smartOrderManager == NULL)
'@

$content = $content -replace [regex]::Escape($verifyOld), $verifyNew

# Add Smart Pending success message in OnInit()
$onInitSuccess = @'
   Print("MainTradingEA initialized successfully");

   return(INIT_SUCCEEDED);
'@

$onInitSuccessNew = @'
   Print("MainTradingEA v3.00 initialized successfully");
   if(UseSmartPending)
      Print("Smart Pending Order System is ACTIVE");

   return(INIT_SUCCEEDED);
'@

$content = $content -replace [regex]::Escape($onInitSuccess), $onInitSuccessNew

# 2. Add SmartOrderManager cleanup in OnDeinit()
$deinitCleanup = @'
   if(performanceTracker != NULL) delete performanceTracker;

   Print("MainTradingEA shutdown complete");
'@

$deinitCleanupNew = @'
   if(performanceTracker != NULL) delete performanceTracker;
   if(smartOrderManager != NULL) delete smartOrderManager;  // Session 20

   Print("MainTradingEA shutdown complete");
'@

$content = $content -replace [regex]::Escape($deinitCleanup), $deinitCleanupNew

# 3. Add UpdatePendingOrders() in OnTick()
$onTickUpdate = @'
   if(positionManager != NULL)
      positionManager.UpdatePositions();

   datetime currentTime = TimeCurrent();
'@

$onTickUpdateNew = @'
   if(positionManager != NULL)
      positionManager.UpdatePositions();

   // Session 20: Update pending orders (check cancellation conditions)
   if(smartOrderManager != NULL)
      smartOrderManager.UpdatePendingOrders();

   datetime currentTime = TimeCurrent();
'@

$content = $content -replace [regex]::Escape($onTickUpdate), $onTickUpdateNew

Write-Host "Writing updated file..." -ForegroundColor Cyan
$content | Out-File -FilePath $inputFile -Encoding UTF8 -NoNewline

Write-Host "Part 2 Complete! OnInit(), OnDeinit(), and OnTick() updated." -ForegroundColor Green
Write-Host "Now run Part 3 to update CheckAndExecuteSignals()" -ForegroundColor Yellow
