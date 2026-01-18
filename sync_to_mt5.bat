@echo off
REM Sync JcampForexTrader to MT5 MQL5 folder

set SOURCE=D:\JcampForexTrader\MT5_EAs
set MT5_PATH=C:\Users\Jcamp_Laptop\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5

echo Syncing files to MT5...

REM Create destination folders if they don't exist
if not exist "%MT5_PATH%\Experts\Jcamp\" mkdir "%MT5_PATH%\Experts\Jcamp"
if not exist "%MT5_PATH%\Include\JcampStrategies\" mkdir "%MT5_PATH%\Include\JcampStrategies"

REM Copy Experts
xcopy /Y /E "%SOURCE%\Experts\*" "%MT5_PATH%\Experts\Jcamp\"

REM Copy Include modules
xcopy /Y /E "%SOURCE%\Include\JcampStrategies\*" "%MT5_PATH%\Include\JcampStrategies\"

echo.
echo Sync complete!
echo.
echo Files copied to:
echo   Experts: %MT5_PATH%\Experts\Jcamp\
echo   Include: %MT5_PATH%\Include\JcampStrategies\
echo.
pause
