@echo off
rem Tellarion.dev — Apple Keyboard Lang Switch
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "DIR=%~dp0"
set "PS1=%DIR%lang-switch.ps1"
set "PID_FILE=%DIR%lang-switch.pid"
set "VBS=%DIR%run-hidden.vbs"

if not exist "%PS1%" (
    echo [Tellarion.dev] [Ошибка] Не найден файл lang-switch.ps1
    pause
    exit /b 1
)

if not exist "%VBS%" (
    echo [Tellarion.dev] [Ошибка] Не найден файл run-hidden.vbs
    pause
    exit /b 1
)

:: Сначала останавливаем старые экземпляры
if exist "%DIR%stop.bat" call "%DIR%stop.bat" >nul 2>&1

:: Уже запущено?
if exist "%PID_FILE%" (
    for /f "usebackq delims=" %%P in ("%PID_FILE%") do set "OLD_PID=%%P"
    tasklist /FI "PID eq !OLD_PID!" 2>nul | find /I "powershell.exe" >nul
    if not errorlevel 1 (
        echo [Tellarion.dev] Переключение языка уже работает ^(PID !OLD_PID!^).
        echo Command+Space / Win+Space — смена языка.
        exit /b 0
    )
    del "%PID_FILE%" >nul 2>&1
)

:: Отключаем Alt+Shift для смены языка, чтобы не конфликтовал
reg add "HKCU\Keyboard Layout\Toggle" /v "Hotkey" /t REG_SZ /d "3" /f >nul 2>&1
reg add "HKCU\Keyboard Layout\Toggle" /v "Language Hotkey" /t REG_SZ /d "3" /f >nul 2>&1

wscript.exe //B //Nologo "%VBS%" "%PS1%" "%PID_FILE%"
ping 127.0.0.1 -n 2 >nul

if exist "%PID_FILE%" (
    for /f "usebackq delims=" %%P in ("%PID_FILE%") do set "NEW_PID=%%P"
    echo.
    echo [Tellarion.dev] Готово. Переключение языка запущено ^(PID !NEW_PID!^).
    echo.
    echo   Command + Space  ^(Win + Пробел^) — смена языка
    echo.
    echo Автозагрузка: Win+R → shell:startup → скопируйте ярлык на start.bat
    echo Остановить: stop.bat
) else (
    echo [Tellarion.dev] [Ошибка] Не удалось запустить скрипт.
    pause
    exit /b 1
)

endlocal
