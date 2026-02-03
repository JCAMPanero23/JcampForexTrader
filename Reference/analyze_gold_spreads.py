#!/usr/bin/env python3
"""
Gold (XAUUSD) Spread Analysis
Analyzes M1 spread data from full year 2025 to optimize trading parameters
"""

import pandas as pd
import numpy as np
from datetime import datetime
import sys

def analyze_gold_spreads(csv_path):
    """Comprehensive spread analysis with time-of-day patterns"""

    print("=" * 80)
    print("GOLD (XAUUSD) SPREAD ANALYSIS - Full Year 2025")
    print("=" * 80)
    print(f"\nLoading data from: {csv_path}")

    # Load CSV
    df = pd.read_csv(csv_path, sep='\t')

    # Convert spread from points to pips (Gold: 1 pip = 10 points)
    df['spread_pips'] = df['<SPREAD>'] / 10.0

    # Parse datetime
    df['datetime'] = pd.to_datetime(df['<DATE>'] + ' ' + df['<TIME>'], format='%Y.%m.%d %H:%M:%S')
    df['hour'] = df['datetime'].dt.hour
    df['day_of_week'] = df['datetime'].dt.dayofweek  # 0=Monday, 6=Sunday

    print(f"Total M1 bars: {len(df):,}")
    print(f"Date range: {df['datetime'].min()} to {df['datetime'].max()}")

    # ========================================
    # OVERALL SPREAD STATISTICS
    # ========================================
    print("\n" + "=" * 80)
    print("OVERALL SPREAD STATISTICS (Full Year)")
    print("=" * 80)

    stats = {
        'Min': df['spread_pips'].min(),
        'Max': df['spread_pips'].max(),
        'Mean': df['spread_pips'].mean(),
        'Median': df['spread_pips'].median(),
        'Std Dev': df['spread_pips'].std(),
        '25th Percentile': df['spread_pips'].quantile(0.25),
        '75th Percentile': df['spread_pips'].quantile(0.75),
        '90th Percentile': df['spread_pips'].quantile(0.90),
        '95th Percentile': df['spread_pips'].quantile(0.95),
        '99th Percentile': df['spread_pips'].quantile(0.99),
    }

    for key, value in stats.items():
        print(f"{key:20s}: {value:8.2f} pips")

    # ========================================
    # SPREAD DISTRIBUTION
    # ========================================
    print("\n" + "=" * 80)
    print("SPREAD DISTRIBUTION (% of time)")
    print("=" * 80)

    bins = [
        (0, 5, "0-5 pips (Excellent)"),
        (5, 10, "5-10 pips (Good)"),
        (10, 15, "10-15 pips (Acceptable)"),
        (15, 20, "15-20 pips (High)"),
        (20, 30, "20-30 pips (Very High)"),
        (30, 50, "30-50 pips (Extreme)"),
        (50, float('inf'), ">50 pips (Prohibitive)")
    ]

    for low, high, label in bins:
        if high == float('inf'):
            count = len(df[df['spread_pips'] >= low])
        else:
            count = len(df[(df['spread_pips'] >= low) & (df['spread_pips'] < high)])
        pct = (count / len(df)) * 100
        print(f"{label:30s}: {pct:6.2f}%  ({count:,} bars)")

    # ========================================
    # TIME-OF-DAY ANALYSIS (UTC+2 - Broker Time)
    # ========================================
    print("\n" + "=" * 80)
    print("HOURLY SPREAD PATTERNS (UTC+2 Broker Time)")
    print("=" * 80)
    print("Hour | Avg Spread | Min | Max | 90th % | Bars    | Quality")
    print("-" * 80)

    hourly_stats = df.groupby('hour')['spread_pips'].agg([
        ('avg', 'mean'),
        ('min', 'min'),
        ('max', 'max'),
        ('p90', lambda x: x.quantile(0.90)),
        ('count', 'count')
    ]).round(2)

    # Define trading sessions (UTC+2)
    # London: 09:00-17:00 UTC+2
    # NY: 14:30-22:00 UTC+2
    # Overlap: 14:30-17:00 UTC+2 (prime time)

    def get_session_quality(hour, avg_spread):
        if 14 <= hour <= 17:  # London/NY overlap
            session = "OVERLAP"
        elif 9 <= hour <= 17:  # London
            session = "LONDON"
        elif 14 <= hour <= 22:  # NY
            session = "NY"
        else:
            session = "OFF-HOURS"

        if avg_spread < 10:
            quality = "EXCELLENT"
        elif avg_spread < 15:
            quality = "GOOD"
        elif avg_spread < 20:
            quality = "ACCEPTABLE"
        else:
            quality = "POOR"

        return f"{session:10s} | {quality}"

    for hour in range(24):
        if hour in hourly_stats.index:
            row = hourly_stats.loc[hour]
            quality = get_session_quality(hour, row['avg'])
            print(f"{hour:02d}:00 | {row['avg']:10.2f} | {row['min']:3.0f} | {row['max']:3.0f} | "
                  f"{row['p90']:6.2f} | {int(row['count']):7,} | {quality}")

    # ========================================
    # SESSION-BASED ANALYSIS
    # ========================================
    print("\n" + "=" * 80)
    print("TRADING SESSION ANALYSIS")
    print("=" * 80)

    sessions = {
        'London/NY Overlap (14:30-17:00)': (df['hour'] >= 14) & (df['hour'] < 17),
        'London Only (09:00-14:30)': (df['hour'] >= 9) & (df['hour'] < 14),
        'NY Only (17:00-22:00)': (df['hour'] >= 17) & (df['hour'] <= 22),
        'Asian Session (22:00-09:00)': (df['hour'] < 9) | (df['hour'] >= 22),
        'Weekend/Off-Hours': df['day_of_week'].isin([5, 6])  # Saturday, Sunday
    }

    for session_name, mask in sessions.items():
        session_data = df[mask]['spread_pips']
        if len(session_data) > 0:
            print(f"\n{session_name}:")
            print(f"  Avg Spread:    {session_data.mean():6.2f} pips")
            print(f"  Median Spread: {session_data.median():6.2f} pips")
            print(f"  90th %ile:     {session_data.quantile(0.90):6.2f} pips")
            print(f"  % < 10 pips:   {(session_data < 10).sum() / len(session_data) * 100:6.2f}%")
            print(f"  % < 15 pips:   {(session_data < 15).sum() / len(session_data) * 100:6.2f}%")
            print(f"  Bars:          {len(session_data):,}")

    # ========================================
    # RECOMMENDATIONS
    # ========================================
    print("\n" + "=" * 80)
    print("OPTIMAL SPREAD MULTIPLIER RECOMMENDATIONS")
    print("=" * 80)

    # Calculate what % of spreads would pass at different multipliers
    base_spread = 2.0  # Current MaxSpreadPips in MainTradingEA

    print(f"\nBase MaxSpreadPips = {base_spread} pips")
    print("\nMultiplier | Max Allowed | % Bars Passing | Recommendation")
    print("-" * 80)

    multipliers = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 50.0, 100.0]

    for mult in multipliers:
        max_spread = base_spread * mult
        pass_rate = (df['spread_pips'] <= max_spread).sum() / len(df) * 100

        if pass_rate < 20:
            rec = "TOO RESTRICTIVE"
        elif pass_rate < 50:
            rec = "VERY LIMITED"
        elif pass_rate < 75:
            rec = "LIMITED"
        elif pass_rate < 90:
            rec = "GOOD BALANCE"
        elif pass_rate < 95:
            rec = "PERMISSIVE"
        else:
            rec = "VERY PERMISSIVE"

        print(f"{mult:10.1f} | {max_spread:11.1f} | {pass_rate:14.2f}% | {rec}")

    # ========================================
    # ACTIONABLE RECOMMENDATIONS
    # ========================================
    print("\n" + "=" * 80)
    print("ACTIONABLE RECOMMENDATIONS FOR PRODUCTION")
    print("=" * 80)

    overlap_avg = df[(df['hour'] >= 14) & (df['hour'] < 17)]['spread_pips'].mean()
    off_hours_avg = df[(df['hour'] < 9) | (df['hour'] >= 22)]['spread_pips'].mean()

    # Find optimal multiplier for 80-90% pass rate during overlap
    overlap_data = df[(df['hour'] >= 14) & (df['hour'] < 17)]
    target_spread_80 = overlap_data['spread_pips'].quantile(0.80)
    target_spread_90 = overlap_data['spread_pips'].quantile(0.90)

    optimal_mult_80 = target_spread_80 / base_spread
    optimal_mult_90 = target_spread_90 / base_spread

    print(f"\n1. SPREAD MULTIPLIER SETTING:")
    print(f"   Current (testing):  100.0x = 200 pips max (TOO PERMISSIVE)")
    print(f"   Recommended (80%):   {optimal_mult_80:.1f}x = {optimal_mult_80 * base_spread:.1f} pips max")
    print(f"   Recommended (90%):   {optimal_mult_90:.1f}x = {optimal_mult_90 * base_spread:.1f} pips max")
    print(f"   Conservative:        15.0x = 30 pips max (catches prime hours)")

    print(f"\n2. TRADING HOURS RECOMMENDATION:")
    print(f"   PRIME TIME:     14:30-17:00 UTC+2 (London/NY overlap)")
    print(f"                   Avg spread: {overlap_avg:.2f} pips")
    print(f"   AVOID:          22:00-09:00 UTC+2 (Asian/Off-hours)")
    print(f"                   Avg spread: {off_hours_avg:.2f} pips")

    print(f"\n3. SPREAD THRESHOLD LOGIC:")
    print(f"   EXCELLENT:      < 10 pips  (execute immediately)")
    print(f"   GOOD:           10-15 pips (acceptable for high confidence signals)")
    print(f"   ACCEPTABLE:     15-20 pips (only for very high confidence, 120+)")
    print(f"   REJECT:         > 20 pips  (skip trade)")

    print(f"\n4. IMPLEMENTATION IN MainTradingEA:")
    print(f"   Option A: Use multiplier 15.0x (simple, covers prime hours)")
    print(f"   Option B: Use time-based logic (complex, optimal)")
    print(f"             - Overlap hours: 20.0x multiplier")
    print(f"             - Other hours:   10.0x multiplier")

    print("\n" + "=" * 80)
    print("ANALYSIS COMPLETE")
    print("=" * 80)

if __name__ == '__main__':
    csv_path = r'D:\JcampForexTrader\Reference\XAUUSD.sml_M1_202501020105_202512312358.csv'
    try:
        analyze_gold_spreads(csv_path)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
