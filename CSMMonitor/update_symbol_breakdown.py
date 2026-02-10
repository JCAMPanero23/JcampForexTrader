#!/usr/bin/env python3
"""
Update Per-Symbol Breakdown to show all 5 pairs (EURUSD, GBPUSD, AUDJPY, USDJPY, USDCHF)
"""

def update_per_symbol_breakdown(content):
    """Update Per-Symbol Breakdown section to include all 5 pairs"""

    # Update the header text
    old_header = 'Text="EUR·GBP·AUD·JPY·CHF"'
    new_header = 'Text="EUR·GBP·AUD·USDJPY·USDCHF"'
    content = content.replace(old_header, new_header)

    # Update the counts section - replace XAUUSD with USDJPY and add USDCHF
    old_counts = '''                                            <TextBlock x:Name="AUDJPYCount" Text="0" FontSize="13" FontWeight="Bold" Foreground="#D0D0D0" FontFamily="Consolas"/>
                                            <TextBlock Text=" · " FontSize="13" Foreground="#333333" Margin="2,0"/>
                                            <TextBlock x:Name="XAUUSDCount" Text="1" FontSize="13" FontWeight="Bold" Foreground="#4EC9B0" FontFamily="Consolas"/>
                                        </StackPanel>'''

    new_counts = '''                                            <TextBlock x:Name="AUDJPYCount" Text="0" FontSize="13" FontWeight="Bold" Foreground="#D0D0D0" FontFamily="Consolas"/>
                                            <TextBlock Text=" · " FontSize="13" Foreground="#333333" Margin="2,0"/>
                                            <TextBlock x:Name="USDJPYCount" Text="0" FontSize="13" FontWeight="Bold" Foreground="#D0D0D0" FontFamily="Consolas"/>
                                            <TextBlock Text=" · " FontSize="13" Foreground="#333333" Margin="2,0"/>
                                            <TextBlock x:Name="USDCHFCount" Text="0" FontSize="13" FontWeight="Bold" Foreground="#D0D0D0" FontFamily="Consolas"/>
                                        </StackPanel>'''

    content = content.replace(old_counts, new_counts)

    return content


def main():
    print("Reading MainWindow.xaml...")
    with open('MainWindow.xaml', 'r', encoding='utf-8') as f:
        content = f.read()

    print("Updating Per-Symbol Breakdown to show 5 pairs...")
    content = update_per_symbol_breakdown(content)

    print("Writing updated MainWindow.xaml...")
    with open('MainWindow.xaml', 'w', encoding='utf-8') as f:
        f.write(content)

    print("Done! Per-Symbol Breakdown now shows all 5 pairs (EURUSD, GBPUSD, AUDJPY, USDJPY, USDCHF)")


if __name__ == '__main__':
    main()
