@echo off
rem Tellarion.dev — Apple Keyboard Lang Switch
chcp 65001 >nul
setlocal

set "PID_FILE=%~dp0lang-switch.pid"
set "PS1=%~dp0lang-switch.ps1"

if exist "%PID_FILE%" (
    for /f "usebackq delims=" %%P in ("%PID_FILE%") do taskkill /PID %%P /F >nul 2>&1
    del "%PID_FILE%" >nul 2>&1
)

powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*lang-switch.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1

echo [Tellarion.dev] Переключение языка остановлено.
endlocal
