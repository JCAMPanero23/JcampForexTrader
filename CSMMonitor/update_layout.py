#!/usr/bin/env python3
"""
Update MainWindow.xaml layout to match proposed design:
1. Make Asset cards scrollable
2. Update Signal Analysis tab to 3x2 grid
"""

import re

def make_asset_cards_scrollable(content):
    """Convert Asset cards section from Grid.Row layout to ScrollViewer with StackPanel"""

    # Step 1: Change Grid.RowDefinitions from 6 rows to 2 rows
    old_defs = '''                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>'''

    new_defs = '''                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>'''

    content = content.replace(old_defs, new_defs)

    # Step 2: Add ScrollViewer and StackPanel after ASSETS header
    old_header = '''                                <TextBlock Grid.Row="0" Text="ASSETS" FontSize="13" FontWeight="Bold"
                                          Foreground="#E0E0E0" Margin="4,0,0,8"/>

                                <!-- EURUSD Card -->
                                <Border Grid.Row="1" x:Name="EURUSDBorder"'''

    new_header = '''                                <TextBlock Grid.Row="0" Text="ASSETS" FontSize="13" FontWeight="Bold"
                                          Foreground="#E0E0E0" Margin="4,0,0,8"/>

                                <!-- Scrollable Asset Cards Container -->
                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                                    <StackPanel>
                                        <!-- EURUSD Card -->
                                        <Border x:Name="EURUSDBorder"'''

    content = content.replace(old_header, new_header)

    # Step 3: Remove Grid.Row attributes from other cards
    content = content.replace('<Border Grid.Row="2" x:Name="GBPUSDBorder"', '<Border x:Name="GBPUSDBorder"')
    content = content.replace('<Border Grid.Row="3" x:Name="AUDJPYBorder"', '<Border x:Name="AUDJPYBorder"')
    content = content.replace('<Border Grid.Row="4" x:Name="USDJPYBorder"', '<Border x:Name="USDJPYBorder"')
    content = content.replace('<Border Grid.Row="5" x:Name="USDCHFBorder"', '<Border x:Name="USDCHFBorder"')

    # Step 4: Add closing tags for ScrollViewer and StackPanel before </Grid>
    # Find the pattern after USDCHF card closes
    old_closing = '''                                </Border>
                            </Grid>
                        </Border>

                        <!-- RIGHT PANEL: Trade Details -->'''

    new_closing = '''                                </Border>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                        </Border>

                        <!-- RIGHT PANEL: Trade Details -->'''

    content = content.replace(old_closing, new_closing)

    return content


def update_signal_analysis_tab(content):
    """Update Signal Analysis tab from 2x2 to 3x2 grid (6 cards)"""

    # Find the UniformGrid line in Signal Analysis tab
    old_grid = '<UniformGrid Rows="2" Columns="2">'
    new_grid = '<UniformGrid Rows="2" Columns="3">'

    # Only replace in Signal Analysis section (around line 1187)
    # We need to be careful to only replace the right one
    signal_analysis_section_start = '<TabItem Header="SIGNAL ANALYSIS"'
    next_tab_start = '<TabItem Header="PERFORMANCE"'

    # Split content to isolate Signal Analysis section
    before_signal = content.split(signal_analysis_section_start)[0]
    signal_and_after = content.split(signal_analysis_section_start)[1]

    signal_section = signal_and_after.split(next_tab_start)[0]
    after_signal = next_tab_start + signal_and_after.split(next_tab_start)[1]

    # Update grid in signal section
    signal_section = signal_section.replace(old_grid, new_grid)

    # Reconstruct content
    content = before_signal + signal_analysis_section_start + signal_section + after_signal

    return content


def main():
    print("Reading MainWindow.xaml...")
    with open('MainWindow.xaml', 'r', encoding='utf-8') as f:
        content = f.read()

    print("Making Asset cards scrollable...")
    content = make_asset_cards_scrollable(content)

    print("Updating Signal Analysis tab to 3x2 grid...")
    content = update_signal_analysis_tab(content)

    print("Writing updated MainWindow.xaml...")
    with open('MainWindow.xaml', 'w', encoding='utf-8') as f:
        f.write(content)

    print("✅ Successfully updated MainWindow.xaml!")
    print("Changes:")
    print("  1. Asset cards section is now scrollable (Yellow section)")
    print("  2. Signal Analysis tab updated to 3x2 grid for 5+ pairs")


if __name__ == '__main__':
    main()
