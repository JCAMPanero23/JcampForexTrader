using System;
using System.IO;
using System.Windows;

namespace JcampForexTrader
{
    /// <summary>
    /// Currency Strength Monitor Application
    /// Advanced Currency Strength Trading System (ACSTS)
    /// </summary>
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            // Setup global exception handling
            this.DispatcherUnhandledException += App_DispatcherUnhandledException;
            AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;

            // Ensure output directory exists
            EnsureDirectoriesExist();

            base.OnStartup(e);
        }

        private void App_DispatcherUnhandledException(object sender,
            System.Windows.Threading.DispatcherUnhandledExceptionEventArgs e)
        {
            string errorMessage = $"Unhandled exception occurred:\n{e.Exception.Message}\n\n" +
                                 $"Stack trace:\n{e.Exception.StackTrace}";

            MessageBox.Show(errorMessage, "CSM Monitor Error",
                          MessageBoxButton.OK, MessageBoxImage.Error);

            LogError(e.Exception);
            e.Handled = true;
        }

        private void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            Exception ex = (Exception)e.ExceptionObject;
            string errorMessage = $"Critical unhandled exception:\n{ex.Message}";

            MessageBox.Show(errorMessage, "CSM Monitor Critical Error",
                          MessageBoxButton.OK, MessageBoxImage.Error);

            LogError(ex);
        }

        private void EnsureDirectoriesExist()
        {
            try
            {
                // Create application data directory
                string appDataPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                    "JcampForexTrader"
                );

                if (!Directory.Exists(appDataPath))
                {
                    Directory.CreateDirectory(appDataPath);
                }

                // Create logs directory
                string logsPath = Path.Combine(appDataPath, "Logs");
                if (!Directory.Exists(logsPath))
                {
                    Directory.CreateDirectory(logsPath);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to create application directories: {ex.Message}",
                              "Initialization Error", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private void LogError(Exception ex)
        {
            try
            {
                string logPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                    "JcampForexTrader", "Logs", $"error_{DateTime.Now:yyyyMMdd}.log"
                );

                string logEntry = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] ERROR: {ex.Message}\n" +
                                 $"Stack Trace: {ex.StackTrace}\n" +
                                 $"----------------------------------------\n";

                File.AppendAllText(logPath, logEntry);
            }
            catch
            {
                // If logging fails, there's not much we can do
            }
        }
    }
}