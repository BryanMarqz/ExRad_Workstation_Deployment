@echo off
:: Automatically request Administrator privileges if not already elevated
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Run setup.ps1 with execution policy bypassed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
