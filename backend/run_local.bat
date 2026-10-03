@echo off
title VanishLab Backend (Standalone Local Mode)
echo =======================================================
echo   Starting VanishLab Backend in Local Standalone Mode
echo =======================================================
echo.
cd /d "%~dp0"
..\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause
