@echo off
setlocal

:: Request Administrator privileges if the launcher is not already elevated.
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Start the modular PowerShell deployment entry point.
if not exist "%~dp0Deployment\setup.ps1" (
    echo Deployment\setup.ps1 is missing. Extract the complete deployment folder before running this launcher.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Deployment\setup.ps1"
set "deploymentExitCode=%errorlevel%"
if not "%deploymentExitCode%"=="0" pause
endlocal & exit /b %deploymentExitCode%
