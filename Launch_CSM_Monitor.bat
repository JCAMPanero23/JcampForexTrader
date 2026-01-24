@echo off
REM ========================================
REM JcampForexTrader - CSM Monitor Launcher
REM ========================================
REM
REM This script launches the CSM Monitor dashboard
REM for real-time forex trading monitoring
REM

echo.
echo ========================================
echo  JcampForexTrader - CSM Monitor
echo ========================================
echo.
echo Starting CSM Monitor...
echo.

REM Navigate to CSMMonitor folder
cd /d "%~dp0CSMMonitor"

REM Check if build exists
if not exist "bin\Debug\net8.0-windows\JcampForexTrader.exe" (
    echo ERROR: Application not built!
    echo Please build the project first using: dotnet build
    echo.
    pause
    exit /b 1
)

REM Launch the application
start "" "bin\Debug\net8.0-windows\JcampForexTrader.exe"

echo.
echo CSM Monitor launched successfully!
echo Check your taskbar for the application window.
echo.
echo Press any key to close this window...
pause >nul
