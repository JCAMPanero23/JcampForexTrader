using System;
using System.Windows;

namespace JcampForexTrader
{
    public partial class ExportOptionsDialog : Window
    {
        public DateTime? StartDate { get; private set; }
        public DateTime? EndDate { get; private set; }
        public string SelectedSymbol { get; private set; }
        public string SelectedStrategy { get; private set; }

        public ExportOptionsDialog()
        {
            InitializeComponent();
            
            // Set default dates
            StartDatePicker.SelectedDate = DateTime.Today.AddYears(-1);
            EndDatePicker.SelectedDate = DateTime.Today;

            // Populate combo boxes
            SymbolComboBox.Items.Add("All Symbols");
            SymbolComboBox.Items.Add("EURUSD");
            SymbolComboBox.Items.Add("GBPUSD");
            SymbolComboBox.Items.Add("GBPNZD");
            SymbolComboBox.SelectedIndex = 0;

            StrategyComboBox.Items.Add("All Strategies");
            StrategyComboBox.Items.Add("Trend Rider");
            StrategyComboBox.Items.Add("Impulse Pullback");
            StrategyComboBox.Items.Add("Breakout & Retest");
            StrategyComboBox.SelectedIndex = 0;
        }

        private void ExportButton_Click(object sender, RoutedEventArgs e)
        {
            // Get selected values
            StartDate = StartDatePicker.SelectedDate;
            EndDate = EndDatePicker.SelectedDate;
            
            SelectedSymbol = SymbolComboBox.SelectedItem.ToString();
            if (SelectedSymbol == "All Symbols")
                SelectedSymbol = null;

            SelectedStrategy = StrategyComboBox.SelectedItem.ToString();
            if (SelectedStrategy == "All Strategies")
                SelectedStrategy = null;

            // Validate dates
            if (StartDate.HasValue && EndDate.HasValue && StartDate > EndDate)
            {
                MessageBox.Show("Start date must be before end date",
                    "Invalid Date Range", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            DialogResult = true;
            Close();
        }

        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }

        // Quick date range buttons
        private void LastMonthButton_Click(object sender, RoutedEventArgs e)
        {
            EndDatePicker.SelectedDate = DateTime.Today;
            StartDatePicker.SelectedDate = DateTime.Today.AddMonths(-1);
        }

        private void Last3MonthsButton_Click(object sender, RoutedEventArgs e)
        {
            EndDatePicker.SelectedDate = DateTime.Today;
            StartDatePicker.SelectedDate = DateTime.Today.AddMonths(-3);
        }

        private void Last6MonthsButton_Click(object sender, RoutedEventArgs e)
        {
            EndDatePicker.SelectedDate = DateTime.Today;
            StartDatePicker.SelectedDate = DateTime.Today.AddMonths(-6);
        }

        private void LastYearButton_Click(object sender, RoutedEventArgs e)
        {
            EndDatePicker.SelectedDate = DateTime.Today;
            StartDatePicker.SelectedDate = DateTime.Today.AddYears(-1);
        }
    }
}

// XAML for ExportOptionsDialog.xaml:
/*
<Window x:Class="JcampForexTrader.ExportOptionsDialog"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Export Options" Height="400" Width="500"
        WindowStartupLocation="CenterOwner"
        Background="#1E1E1E"
        Foreground="White">
    
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <TextBlock Grid.Row="0" Text="Export Trade History" 
                   FontSize="20" FontWeight="Bold" Margin="0,0,0,20"/>

        <!-- Options -->
        <StackPanel Grid.Row="1">
            
            <!-- Date Range -->
            <TextBlock Text="Date Range" FontWeight="Bold" Margin="0,0,0,10"/>
            <Grid Margin="0,0,0,15">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                
                <TextBlock Grid.Column="0" Text="From:" VerticalAlignment="Center" Margin="0,0,10,0"/>
                <DatePicker Grid.Column="1" x:Name="StartDatePicker" Margin="0,0,10,0"/>
                
                <TextBlock Grid.Column="2" Text="To:" VerticalAlignment="Center" Margin="0,0,10,0"/>
                <DatePicker Grid.Column="3" x:Name="EndDatePicker"/>
            </Grid>

            <!-- Quick Date Buttons -->
            <TextBlock Text="Quick Select:" FontSize="12" Foreground="Gray" Margin="0,0,0,5"/>
            <WrapPanel Margin="0,0,0,20">
                <Button Content="Last Month" Width="90" Height="30" Margin="0,0,5,0" 
                        Click="LastMonthButton_Click" Background="#3E3E42" Foreground="White"/>
                <Button Content="Last 3 Months" Width="100" Height="30" Margin="0,0,5,0"
                        Click="Last3MonthsButton_Click" Background="#3E3E42" Foreground="White"/>
                <Button Content="Last 6 Months" Width="100" Height="30" Margin="0,0,5,0"
                        Click="Last6MonthsButton_Click" Background="#3E3E42" Foreground="White"/>
                <Button Content="Last Year" Width="90" Height="30"
                        Click="LastYearButton_Click" Background="#3E3E42" Foreground="White"/>
            </WrapPanel>

            <!-- Symbol Filter -->
            <TextBlock Text="Symbol Filter" FontWeight="Bold" Margin="0,0,0,10"/>
            <ComboBox x:Name="SymbolComboBox" Height="30" Margin="0,0,0,15"/>

            <!-- Strategy Filter -->
            <TextBlock Text="Strategy Filter" FontWeight="Bold" Margin="0,0,0,10"/>
            <ComboBox x:Name="StrategyComboBox" Height="30" Margin="0,0,0,15"/>

        </StackPanel>

        <!-- Buttons -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
            <Button Content="Export" Width="100" Height="35" Margin="0,0,10,0"
                    Background="#4CAF50" Foreground="White" Click="ExportButton_Click"/>
            <Button Content="Cancel" Width="100" Height="35"
                    Background="#F44336" Foreground="White" Click="CancelButton_Click"/>
        </StackPanel>
    </Grid>
</Window>
*/