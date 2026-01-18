@echo off
REM Sync from MT5 MQL5 folder back to JcampForexTrader
REM Use this if you edit directly in MetaEditor

set SOURCE=C:\Users\Jcamp_Laptop\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5
set DEST=D:\JcampForexTrader\MT5_EAs

echo Syncing files FROM MT5 to dev folder...

REM Copy Experts
xcopy /Y /E "%SOURCE%\Experts\Jcamp\*" "%DEST%\Experts\"

REM Copy Include modules
xcopy /Y /E "%SOURCE%\Include\JcampStrategies\*" "%DEST%\Include\JcampStrategies\"

echo.
echo Sync complete!
echo.
echo Files copied to:
echo   %DEST%\Experts\
echo   %DEST%\Include\JcampStrategies\
echo.
echo REMEMBER: Commit changes to git!
echo.
pause
