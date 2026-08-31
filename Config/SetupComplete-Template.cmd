@echo off
rem ExRad unattended-answer cleanup. Runs as SYSTEM before the login screen.
del /f /q "%WINDIR%\Panther\ExRad-Unattend.xml" 2>nul
del /f /q "%WINDIR%\Panther\unattend.xml" 2>nul
del /f /q "%WINDIR%\System32\Sysprep\Panther\unattend.xml" 2>nul
del /f /q "%WINDIR%\System32\Sysprep\unattend.xml" 2>nul
