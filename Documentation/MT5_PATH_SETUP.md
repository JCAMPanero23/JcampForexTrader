# MT5 MetaEditor Path Integration Guide

**Problem:** MT5 expects files in `C:\Users\...\AppData\Roaming\MetaQuotes\Terminal\...\MQL5\`
**Solution:** We want to develop in `D:\JcampForexTrader\MT5_EAs\`

---

## 🏆 Recommended: Symbolic Links (Option 1)

### Benefits
- ✅ Work in clean dev folder with git
- ✅ MT5 sees changes automatically (no copying)
- ✅ MetaEditor compiles directly
- ✅ Single source of truth

### Setup (One-time, 5 minutes)

**Step 1: Open Command Prompt as Administrator**
```
Windows Key → Type "cmd" → Right-click → "Run as administrator"
```

**Step 2: Navigate to MT5 Experts folder**
```cmd
cd C:\Users\Jcamp_Laptop\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts
```

**Step 3: Create symlink for Experts**
```cmd
mklink /D Jcamp D:\JcampForexTrader\MT5_EAs\Experts
```

**Step 4: Navigate to MT5 Include folder**
```cmd
cd ..\Include
```

**Step 5: Create symlink for Include**
```cmd
mklink /D JcampStrategies D:\JcampForexTrader\MT5_EAs\Include\JcampStrategies
```

**Step 6: Verify**
```cmd
dir
```

You should see:
```
<SYMLINK>      Jcamp [D:\JcampForexTrader\MT5_EAs\Experts]
<SYMLINK>      JcampStrategies [D:\JcampForexTrader\MT5_EAs\Include\JcampStrategies]
```

### Result

**In MetaEditor Navigator:**
```
Experts
├── Advisors
├── Examples
└── Jcamp                          ← Your EAs here!
    ├── Jcamp_CSM_AnalysisEA.mq5
    ├── Jcamp_Strategy_AnalysisEA.mq5
    └── Jcamp_MainTradingEA.mq5

Include
├── (Standard MT5 includes)
└── JcampStrategies                ← Your modules here!
    ├── Indicators
    │   ├── EmaCalculator.mqh
    │   └── ...
    └── Strategies
        ├── TrendRiderStrategy.mqh
        └── ...
```

**In your EA code:**
```mql5
#include <JcampStrategies/Indicators/EmaCalculator.mqh>
#include <JcampStrategies/Strategies/TrendRiderStrategy.mqh>
```

### Workflow

1. Edit files in `D:\JcampForexTrader\MT5_EAs\`
2. Open MetaEditor → See changes automatically
3. Compile in MetaEditor → Works directly
4. Commit changes → Git tracks `D:\JcampForexTrader\`

**No manual copying needed!**

---

## 📁 Alternative: Manual Sync (Option 2)

If you can't use symlinks (permissions, etc.), use the sync scripts.

### Setup

**Files created:**
- `sync_to_mt5.bat` - Copy dev folder → MT5
- `sync_from_mt5.bat` - Copy MT5 → dev folder

### Workflow A: Develop in D:\JcampForexTrader
1. Edit files in `D:\JcampForexTrader\MT5_EAs\`
2. Run `sync_to_mt5.bat`
3. Open MetaEditor → Compile
4. Test in MT5
5. Commit changes in `D:\JcampForexTrader\`

### Workflow B: Edit in MetaEditor
1. Open MetaEditor
2. Edit files in MT5 folder directly
3. Compile & test
4. Run `sync_from_mt5.bat` (copy back to dev folder)
5. Commit changes in `D:\JcampForexTrader\`

**⚠️ Warning:** Remember to sync! Easy to forget and lose changes.

---

## 🎯 Recommended Setup

**Best for most users: Symbolic Links (Option 1)**

**Advantages:**
- Zero manual effort
- No sync errors
- Git works normally
- Fastest workflow

**When to use Manual Sync (Option 2):**
- Can't get admin permissions
- Corporate/restricted environment
- Want explicit control over syncing

---

## 📋 Quick Reference

### MT5 Paths

**Your Installation:**
```
C:\Users\Jcamp_Laptop\AppData\Roaming\MetaQuotes\Terminal\
  └── D0E8209F77C8CF37AD8BF550E51FF075\MQL5\
      ├── Experts\
      │   └── Jcamp\              → symlink to D:\JcampForexTrader\MT5_EAs\Experts\
      └── Include\
          └── JcampStrategies\    → symlink to D:\JcampForexTrader\MT5_EAs\Include\JcampStrategies\
```

### Development Folder
```
D:\JcampForexTrader\MT5_EAs\
├── Experts\
│   ├── Jcamp_CSM_AnalysisEA.mq5
│   ├── Jcamp_Strategy_AnalysisEA.mq5
│   └── Jcamp_MainTradingEA.mq5
└── Include\
    └── JcampStrategies\
        ├── Indicators\
        └── Strategies\
```

---

## 🔧 Troubleshooting

### Symlink not working?
- Run Command Prompt as Administrator
- Check Windows version (symlinks require Windows Vista+)
- Verify paths are correct (no typos)

### MetaEditor doesn't see files?
- Restart MetaEditor after creating symlinks
- Check Navigator panel → Refresh (F5)
- Right-click Navigator → "Refresh"

### Can't delete symlink?
```cmd
REM Use rmdir, NOT del
rmdir Jcamp
```

### Want to remove symlinks?
```cmd
cd C:\Users\Jcamp_Laptop\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts
rmdir Jcamp

cd ..\Include
rmdir JcampStrategies
```

---

*Last Updated: January 18, 2026*
