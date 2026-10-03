Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  Starting VanishLab Backend (Local Standalone Mode)" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$PythonPath = Join-Path (Split-Path -Parent $ScriptDir) ".venv\Scripts\python.exe"

if (-Not (Test-Path $PythonPath)) {
    Write-Host "Error: Virtual environment not found at $PythonPath" -ForegroundColor Red
    Exit 1
}

Write-Host "API Swagger Documentation will be available at: http://localhost:8000/docs" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the server." -ForegroundColor Yellow
Write-Host ""

& $PythonPath -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
