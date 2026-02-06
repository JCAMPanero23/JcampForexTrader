# Session 13: Enhanced Signal Analysis Dashboard - Implementation Plan

**Date:** February 6, 2026
**Objective:** Show detailed strategy component breakdown in CSMMonitor Signal Analysis tab

---

## Current State Analysis

### Existing UI (MainWindow.xaml lines 1144-1391)
✅ **Already has:**
- Signal Analysis tab with 4 cards (EURUSD, GBPUSD, AUDJPY, XAUUSD)
- Overall signal status and confidence per pair
- TrendRider/RangeRider strategy sections
- Overall progress bars (0-135 for TR, 0-100 for RR)
- Analysis text showing score breakdown (e.g., "EMA+30 ADX+20 RSI+5 CSM+25")

### Current Signal JSON Structure
```json
{
  "symbol": "EURUSD.r",
  "timestamp": "2026.02.06 20:59:24",
  "strategy": "NONE",
  "signal": 0,
  "signal_text": "NEUTRAL",
  "confidence": 0,
  "analysis": "No valid signal",
  "csm_diff": 27.68,
  "regime": "REGIME_TRENDING"
}
```

❌ **Missing:**
- Individual component scores (EMA, ADX, RSI, CSM)
- Component max values (for progress bar calculation)
- Blocking reasons (why NOT_TRADABLE)
- Price Action, Volume, MTF bonus scores

---

## Implementation Steps

### Phase 1: Update MQ5 Signal Export Structure ⚙️

**Files to Modify:**
1. `MT5_EAs/Include/JcampStrategies/Strategies/IStrategy.mqh`
2. `MT5_EAs/Include/JcampStrategies/Strategies/TrendRiderStrategy.mqh`
3. `MT5_EAs/Include/JcampStrategies/Strategies/RangeRiderStrategy.mqh`
4. `MT5_EAs/Include/JcampStrategies/SignalExporter.mqh`

**Changes Required:**

#### 1.1 Update StrategySignal struct (IStrategy.mqh)
Add component score fields:
```cpp
struct StrategySignal
{
   // Existing fields
   int      signal;
   int      confidence;
   string   analysis;
   string   strategyName;
   double   stopLossDollars;
   double   takeProfitDollars;

   // NEW: TrendRider component scores
   int      emaScore;          // 0-30 points
   int      adxScore;          // 0-25 points
   int      rsiScore;          // 0-20 points
   int      csmScore;          // 0-25 points
   int      priceActionScore;  // 0-15 points (bonus)
   int      volumeScore;       // 0-10 points (bonus)
   int      mtfScore;          // 0-10 points (bonus)

   // NEW: RangeRider component scores
   int      rangeWidthScore;   // 0-40 points
   int      srQualityScore;    // 0-30 points
   int      bounceScore;       // 0-30 points
};
```

#### 1.2 Update TrendRiderStrategy (TrendRiderStrategy.mqh)
**Current behavior:** Calculates component scores but doesn't store them separately

**Changes needed:**
- Store individual scores in StrategySignal struct
- Lines 87-128 (bullish) and 133-174 (bearish)

Example:
```cpp
// OLD:
result.confidence += 30;
result.analysis += "EMA+30 ";

// NEW:
result.emaScore = 30;
result.confidence += result.emaScore;
result.analysis += "EMA+30 ";
```

#### 1.3 Update RangeRiderStrategy (RangeRiderStrategy.mqh)
Similar changes for range strategy component scores:
- Range width score (0-40)
- S/R quality score (0-30)
- Bounce position score (0-30)

#### 1.4 Update SignalExporter (SignalExporter.mqh)
Add component scores to JSON export:
```cpp
// In BuildJSON() function, add:
json += "  \"components\": {\n";
json += "    \"ema_score\": " + IntegerToString(signal.emaScore) + ",\n";
json += "    \"adx_score\": " + IntegerToString(signal.adxScore) + ",\n";
json += "    \"rsi_score\": " + IntegerToString(signal.rsiScore) + ",\n";
json += "    \"csm_score\": " + IntegerToString(signal.csmScore) + ",\n";
json += "    \"price_action_score\": " + IntegerToString(signal.priceActionScore) + ",\n";
json += "    \"volume_score\": " + IntegerToString(signal.volumeScore) + ",\n";
json += "    \"mtf_score\": " + IntegerToString(signal.mtfScore) + ",\n";
json += "    \"range_width_score\": " + IntegerToString(signal.rangeWidthScore) + ",\n";
json += "    \"sr_quality_score\": " + IntegerToString(signal.srQualityScore) + ",\n";
json += "    \"bounce_score\": " + IntegerToString(signal.bounceScore) + "\n";
json += "  },\n";
```

**Expected Output:**
```json
{
  "symbol": "EURUSD.r",
  "strategy": "TREND_RIDER",
  "signal": 0,
  "confidence": 80,
  "analysis": "EMA+30 ADX+20 RSI+10 CSM+20",
  "components": {
    "ema_score": 30,
    "adx_score": 20,
    "rsi_score": 10,
    "csm_score": 20,
    "price_action_score": 0,
    "volume_score": 0,
    "mtf_score": 0,
    "range_width_score": 0,
    "sr_quality_score": 0,
    "bounce_score": 0
  }
}
```

---

### Phase 2: Enhance XAML UI Layout 🎨

**File to Modify:** `CSMMonitor/MainWindow.xaml` (lines 1144-1391)

**Changes per Strategy Card:**

Replace current:
```xaml
<!-- Score Breakdown -->
<TextBlock x:Name="EURUSD_TR_Analysis_SA" Text="EMA+30 ADX+20 RSI+5 CSM+25"
           FontSize="10" Foreground="#9CDCFE" Opacity="0.7"/>
```

With detailed component view:
```xaml
<!-- Component Breakdown -->
<StackPanel Margin="0,6,0,0">
    <!-- EMA Alignment -->
    <Grid Margin="0,0,0,3">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="80"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="35"/>
        </Grid.ColumnDefinitions>
        <TextBlock Text="EMA" FontSize="9" Foreground="#E0E0E0" VerticalAlignment="Center"/>
        <ProgressBar Grid.Column="1" x:Name="EURUSD_TR_EMA_Bar"
                     Height="12" Minimum="0" Maximum="30" Value="0"
                     Foreground="#4EC9B0" Background="#1A1A1A" BorderThickness="0"/>
        <TextBlock Grid.Column="2" x:Name="EURUSD_TR_EMA_Text"
                   Text="0/30" FontSize="9" Foreground="#FFFFFF"
                   FontFamily="Consolas" TextAlignment="Right"/>
    </Grid>

    <!-- ADX Strength -->
    <Grid Margin="0,0,0,3">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="80"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="35"/>
        </Grid.ColumnDefinitions>
        <TextBlock Text="ADX" FontSize="9" Foreground="#E0E0E0" VerticalAlignment="Center"/>
        <ProgressBar Grid.Column="1" x:Name="EURUSD_TR_ADX_Bar"
                     Height="12" Minimum="0" Maximum="25" Value="0"
                     Foreground="#4EC9B0" Background="#1A1A1A" BorderThickness="0"/>
        <TextBlock Grid.Column="2" x:Name="EURUSD_TR_ADX_Text"
                   Text="0/25" FontSize="9" Foreground="#FFFFFF"
                   FontFamily="Consolas" TextAlignment="Right"/>
    </Grid>

    <!-- RSI Position -->
    <Grid Margin="0,0,0,3">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="80"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="35"/>
        </Grid.ColumnDefinitions>
        <TextBlock Text="RSI" FontSize="9" Foreground="#E0E0E0" VerticalAlignment="Center"/>
        <ProgressBar Grid.Column="1" x:Name="EURUSD_TR_RSI_Bar"
                     Height="12" Minimum="0" Maximum="20" Value="0"
                     Foreground="#4EC9B0" Background="#1A1A1A" BorderThickness="0"/>
        <TextBlock Grid.Column="2" x:Name="EURUSD_TR_RSI_Text"
                   Text="0/20" FontSize="9" Foreground="#FFFFFF"
                   FontFamily="Consolas" TextAlignment="Right"/>
    </Grid>

    <!-- CSM Support -->
    <Grid Margin="0,0,0,3">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="80"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="35"/>
        </Grid.ColumnDefinitions>
        <TextBlock Text="CSM" FontSize="9" Foreground="#E0E0E0" VerticalAlignment="Center"/>
        <ProgressBar Grid.Column="1" x:Name="EURUSD_TR_CSM_Bar"
                     Height="12" Minimum="0" Maximum="25" Value="0"
                     Foreground="#4EC9B0" Background="#1A1A1A" BorderThickness="0"/>
        <TextBlock Grid.Column="2" x:Name="EURUSD_TR_CSM_Text"
                   Text="0/25" FontSize="9" Foreground="#FFFFFF"
                   FontFamily="Consolas" TextAlignment="Right"/>
    </Grid>

    <!-- Bonus Scores (if non-zero) -->
    <TextBlock x:Name="EURUSD_TR_Bonus_Text"
               Text="Bonus: PA+15 VOL+10 MTF+10"
               FontSize="9" Foreground="#FFAA00"
               Margin="0,3,0,0" Visibility="Collapsed"/>
</StackPanel>
```

**UI Enhancements to Add:**
1. Orange warning border when NOT_TRADABLE
2. Red "NEEDS:" text showing missing requirements
3. Green checkmark icons for met requirements
4. Collapsible bonus scores section

---

### Phase 3: Update C# Code-Behind Parser 📊

**File to Modify:** `CSMMonitor/MainWindow.xaml.cs`

**Changes Required:**

#### 3.1 Create Component Score Data Class
```csharp
public class StrategyComponents
{
    // TrendRider scores
    public int EmaScore { get; set; }
    public int EmaMax { get; set; } = 30;
    public int AdxScore { get; set; }
    public int AdxMax { get; set; } = 25;
    public int RsiScore { get; set; }
    public int RsiMax { get; set; } = 20;
    public int CsmScore { get; set; }
    public int CsmMax { get; set; } = 25;

    // Bonus scores
    public int PriceActionScore { get; set; }
    public int VolumeScore { get; set; }
    public int MtfScore { get; set; }

    // RangeRider scores
    public int RangeWidthScore { get; set; }
    public int RangeWidthMax { get; set; } = 40;
    public int SrQualityScore { get; set; }
    public int SrQualityMax { get; set; } = 30;
    public int BounceScore { get; set; }
    public int BounceMax { get; set; } = 30;
}
```

#### 3.2 Update ParseSignalFile() Method
Add JSON parsing for components:
```csharp
// After parsing existing fields, add:
if (jsonObj.ContainsKey("components"))
{
    var components = jsonObj["components"] as Dictionary<string, object>;
    return new StrategyComponents
    {
        EmaScore = Convert.ToInt32(components["ema_score"]),
        AdxScore = Convert.ToInt32(components["adx_score"]),
        RsiScore = Convert.ToInt32(components["rsi_score"]),
        CsmScore = Convert.ToInt32(components["csm_score"]),
        PriceActionScore = Convert.ToInt32(components["price_action_score"]),
        VolumeScore = Convert.ToInt32(components["volume_score"]),
        MtfScore = Convert.ToInt32(components["mtf_score"]),
        RangeWidthScore = Convert.ToInt32(components["range_width_score"]),
        SrQualityScore = Convert.ToInt32(components["sr_quality_score"]),
        BounceScore = Convert.ToInt32(components["bounce_score"])
    };
}
```

#### 3.3 Update UI Binding Method
```csharp
private void UpdateSignalAnalysisCard(string symbol, StrategyComponents components)
{
    // Update TrendRider component bars
    EURUSD_TR_EMA_Bar.Value = components.EmaScore;
    EURUSD_TR_EMA_Text.Text = $"{components.EmaScore}/{components.EmaMax}";

    EURUSD_TR_ADX_Bar.Value = components.AdxScore;
    EURUSD_TR_ADX_Text.Text = $"{components.AdxScore}/{components.AdxMax}";

    EURUSD_TR_RSI_Bar.Value = components.RsiScore;
    EURUSD_TR_RSI_Text.Text = $"{components.RsiScore}/{components.RsiMax}";

    EURUSD_TR_CSM_Bar.Value = components.CsmScore;
    EURUSD_TR_CSM_Text.Text = $"{components.CsmScore}/{components.CsmMax}";

    // Show bonus scores if any
    int bonusTotal = components.PriceActionScore + components.VolumeScore + components.MtfScore;
    if (bonusTotal > 0)
    {
        EURUSD_TR_Bonus_Text.Text = $"Bonus: ";
        if (components.PriceActionScore > 0)
            EURUSD_TR_Bonus_Text.Text += $"PA+{components.PriceActionScore} ";
        if (components.VolumeScore > 0)
            EURUSD_TR_Bonus_Text.Text += $"VOL+{components.VolumeScore} ";
        if (components.MtfScore > 0)
            EURUSD_TR_Bonus_Text.Text += $"MTF+{components.MtfScore}";
        EURUSD_TR_Bonus_Text.Visibility = Visibility.Visible;
    }
    else
    {
        EURUSD_TR_Bonus_Text.Visibility = Visibility.Collapsed;
    }
}
```

---

### Phase 4: Add Visual Blocking Indicators ⚠️

**Blocking Reason Detection Logic:**
```csharp
private string GetBlockingReason(string signalText, double csmDiff, string regime, StrategyComponents components)
{
    if (signalText == "NOT_TRADABLE")
    {
        // CSM Gate block
        if (csmDiff < 15.0)
            return $"❌ BLOCKED: CSM differential too low ({csmDiff:F1} < 15.0)";

        // Transitional regime block
        if (regime == "REGIME_TRANSITIONAL")
            return "❌ BLOCKED: Market in TRANSITIONAL regime";

        // Gold range block
        if (symbol == "XAUUSD" && regime == "REGIME_RANGING")
            return "❌ BLOCKED: Gold only trades trends (not ranges)";
    }
    else if (signalText == "NEUTRAL")
    {
        // Strategy evaluated but didn't meet threshold
        List<string> missing = new List<string>();

        if (components.EmaScore == 0)
            missing.Add("EMA alignment");
        if (components.AdxScore < 15)
            missing.Add($"ADX strength ({components.AdxScore}/25)");
        if (components.RsiScore < 10)
            missing.Add($"RSI position ({components.RsiScore}/20)");
        if (components.CsmScore < 15)
            missing.Add($"CSM support ({components.CsmScore}/25)");

        if (missing.Count > 0)
            return "⚠️ NEEDS: " + string.Join(", ", missing);
    }

    return "";
}
```

**XAML Addition (per card):**
```xaml
<!-- Blocking/Warning Banner -->
<Border x:Name="EURUSD_Warning_Banner"
        Background="#7A5A4A"
        BorderBrush="#FF8C00"
        BorderThickness="1"
        CornerRadius="3"
        Padding="8,4"
        Margin="0,0,0,6"
        Visibility="Collapsed">
    <TextBlock x:Name="EURUSD_Warning_Text"
               Text="❌ BLOCKED: CSM differential too low (14.5 < 15.0)"
               FontSize="10"
               Foreground="#FFAA00"
               FontWeight="Bold"
               TextWrapping="Wrap"/>
</Border>
```

---

## Testing Checklist

### MQ5 Changes
- [ ] Compile all 3 EAs (CSM_AnalysisEA, Strategy_AnalysisEA, MainTradingEA)
- [ ] Deploy on demo MT5
- [ ] Verify signal JSON files contain `components` object
- [ ] Verify component scores add up to total confidence
- [ ] Test all 4 symbols (EURUSD, GBPUSD, AUDJPY, XAUUSD)

### C# Dashboard Changes
- [ ] Rebuild CSMMonitor project
- [ ] Verify component progress bars display correctly
- [ ] Test with NOT_TRADABLE signals (orange warning)
- [ ] Test with HOLD signals (gray, shows missing components)
- [ ] Test with BUY/SELL signals (green/red, shows full breakdown)
- [ ] Verify bonus scores only show when non-zero
- [ ] Test Gold card (TrendRider only, no RangeRider section)

### Visual Validation
- [ ] Take screenshots before/after changes
- [ ] Verify color scheme matches reference image
- [ ] Verify text is readable at all zoom levels
- [ ] Verify progress bars animate smoothly
- [ ] Verify 5-second auto-refresh works

---

## Files to Modify Summary

### MQ5 Files (4 files)
1. `MT5_EAs/Include/JcampStrategies/Strategies/IStrategy.mqh` (~20 lines added)
2. `MT5_EAs/Include/JcampStrategies/Strategies/TrendRiderStrategy.mqh` (~30 lines modified)
3. `MT5_EAs/Include/JcampStrategies/Strategies/RangeRiderStrategy.mqh` (~20 lines modified)
4. `MT5_EAs/Include/JcampStrategies/SignalExporter.mqh` (~25 lines added)

### C# Files (2 files)
1. `CSMMonitor/MainWindow.xaml` (~400 lines modified - 4 cards × ~100 lines each)
2. `CSMMonitor/MainWindow.xaml.cs` (~150 lines added)

---

## Expected Result

**User can see:**
- ✅ Exactly which strategy components are contributing (EMA, ADX, RSI, CSM)
- ✅ How far each component is from maximum (progress bars with X/Y labels)
- ✅ Why a signal is NOT_TRADABLE (CSM gate, regime block)
- ✅ What's missing for a HOLD to become BUY/SELL
- ✅ Bonus scores (Price Action, Volume, MTF) when present
- ✅ Clear visual distinction between system blocking vs strategy waiting

**Benefits:**
- 🎯 Better transparency into decision-making
- 🔍 Easier debugging (can see which component is weak)
- 📊 Confidence threshold tuning guidance (see which pairs almost qualified)
- 🎓 Educational (users learn what makes a strong signal)

---

**Status:** Ready for implementation
**Next:** Start with Phase 1 (MQ5 changes)
