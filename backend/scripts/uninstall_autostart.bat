@echo off
set TARGET=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\VanishLab_Backend.vbs
if exist "%TARGET%" del /f /q "%TARGET%" >nul
echo VanishLab Backend Auto-Start removed from Windows Startup.
pause
