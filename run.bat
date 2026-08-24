@echo off
setlocal
:: Automatically request Administrator privileges if not already elevated
net session >nul 2>&1
if errorlevel 1 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Download and verify any missing installers before opening the deployment tool
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Download-Installers.ps1"
if errorlevel 1 (
    echo.
    echo The installer download step failed. Review the error above.
    pause
    exit /b 1
)

:: Run setup.ps1 with execution policy bypassed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
