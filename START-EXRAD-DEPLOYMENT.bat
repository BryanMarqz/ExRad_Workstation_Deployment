@echo off
setlocal

:: Request Administrator privileges if the launcher is not already elevated.
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Start the modular PowerShell deployment entry point.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
endlocal
