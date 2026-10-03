@echo off
set ROOT_DIR=%~dp0
wscript.exe "%ROOT_DIR%backend\run_silent.vbs"
cd /d "%ROOT_DIR%frontend"
start "" flutter run -d windows
