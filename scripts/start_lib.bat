@echo off
setlocal
cd /d %~dp0

:: Konfiguration
set "PORT=3000"
set "NODE_EXE=%~dp0..\node\node.exe"
set "NEXT_CLI=%~dp0..\app\node_modules\next\dist\bin\next"
set "APP_DIR=%~dp0..\app"

echo Prüfe, ob OpenLibry bereits läuft...

:: Prüfen, ob Port 3000 belegt ist
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
if %errorlevel% equ 0 (
    echo OpenLibry ist bereits aktiv. Öffne Browser...
    start http://localhost:%PORT%
    timeout /t 3 >nul
    exit
)

:: Falls nicht aktiv, Server starten
echo OpenLibry wird gestartet...
cd /d "%APP_DIR%"

:: Browser mit kurzer Verzögerung starten
start /b "" cmd /c "timeout /t 5 >nul && start http://localhost:%PORT%"

:: Den Next.js Server starten
"%NODE_EXE%" "%NEXT_CLI%" start -p %PORT%

pause