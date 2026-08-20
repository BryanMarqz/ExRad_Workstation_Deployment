@echo off
setlocal

:: Try to find Ahk2Exe in common AutoHotkey v2 locations
set "AHK2EXE="
if exist "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" set "AHK2EXE=C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
if exist "C:\Program Files\AutoHotkey\v2\Compiler\Ahk2Exe.exe" set "AHK2EXE=C:\Program Files\AutoHotkey\v2\Compiler\Ahk2Exe.exe"
if exist "C:\Program Files (x86)\AutoHotkey\Compiler\Ahk2Exe.exe" set "AHK2EXE=C:\Program Files (x86)\AutoHotkey\Compiler\Ahk2Exe.exe"

if "%AHK2EXE%"=="" (
    echo ERROR: Ahk2Exe.exe not found. Make sure AutoHotkey is installed.
    pause
    exit /b 1
)

echo Found compiler: %AHK2EXE%
echo.
set "DIR=%~dp0"

echo Compiling FolderForward.ahk...
"%AHK2EXE%" /in "%DIR%FolderForward.ahk" /out "%DIR%FolderForward.exe"
echo Compiling FolderAccept.ahk...
"%AHK2EXE%" /in "%DIR%FolderAccept.ahk" /out "%DIR%FolderAccept.exe"
echo Compiling FolderReject.ahk...
"%AHK2EXE%" /in "%DIR%FolderReject.ahk" /out "%DIR%FolderReject.exe"
echo Compiling Play.ahk...
"%AHK2EXE%" /in "%DIR%Play.ahk" /out "%DIR%Play.exe"

echo.
echo Done! All 4 EXEs are in the same folder as this script.
pause
