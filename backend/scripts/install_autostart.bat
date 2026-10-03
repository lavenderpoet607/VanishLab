@echo off
set SCRIPT_DIR=%~dp0
set VBS_SRC=%SCRIPT_DIR%..\run_silent.vbs
set STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
copy /y "%VBS_SRC%" "%STARTUP_DIR%\VanishLab_Backend.vbs" >nul
echo VanishLab Backend Auto-Start has been registered to Windows Startup.
echo The backend API will automatically run silently in the background on Windows boot.
pause
