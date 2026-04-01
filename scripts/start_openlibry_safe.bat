@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: --- 1. KONFIGURATION ---
set "PORT=3000"
set "NODE_DIR=%~dp0..\node"
set "NODE_EXE=%NODE_DIR%\node.exe"
set "APP_DIR=%~dp0..\app"
set "DB_FILE=%APP_DIR%\database\dev.db"
set "PRISMA_CLI=%APP_DIR%\node_modules\prisma\build\index.js"

set "PATH=%NODE_DIR%;%PATH%"

cls
echo ===========================================================
echo             OpenLibry SAFE MODE ^(Diagnose^)
echo ===========================================================
echo.
echo [DEBUG] System-Check wird ausgefuehrt...
echo.

:: --- 2. UMGEBUNGSPRÜFUNG ---
echo [1] Pruefe Komponenten:
if exist "%NODE_EXE%" (echo   - Node.exe: OK) else (echo   - [FEHLER] Node.exe fehlt!)
if exist "%APP_DIR%"  (echo   - App-Ordner: OK) else (echo   - [FEHLER] App-Ordner fehlt!)
if exist "%PRISMA_CLI%" (echo   - Prisma-CLI: OK) else (echo   - [WARN] Prisma-CLI nicht gefunden.)

:: --- 3. DATENBANK-DIAGNOSE (Keine Änderungen!) ---
echo.
echo [2] Datenbank-Status:
if not exist "%DB_FILE%" (
    echo   - [!] dev.db FEHLT! (Erster Start oder Datei geloescht?)
) else (
    echo   - dev.db gefunden.
    echo   - Pruefe Migrations-Status (Read-Only)...
    
    cd /d "%APP_DIR%"
    :: Wir nutzen migrate status, machen aber kein deploy!
    "%NODE_EXE%" "%PRISMA_CLI%" migrate status > temp_status.txt 2>&1
    set "MIGRATE_EXIT=!errorlevel!"
    
    if !MIGRATE_EXIT! equ 0 (
        echo   - [OK] Datenbank ist synchron mit dem Schema.
    ) else (
        echo   - [!] MIGRATION NOETIG! (Schema-Aenderungen stehen aus)
        echo     HINWEIS: Nutze das Standard-Start-Skript fuer das Update.
    )
    del temp_status.txt >nul 2>&1
)

:: --- 4. PORT-CHECK ---
echo.
echo [3] Netzwerk-Check:
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
if %errorlevel% equ 0 (
    echo   - [!] Port %PORT% ist bereits BELEGT.
    echo     Browser wird geoeffnet, kein neuer Serverstart moeglich.
    start http://localhost:%PORT%
    pause
    exit
) else (
    echo   - Port %PORT% ist frei.
)

:: --- 5. START DER APPLIKATION ---
echo.
echo [4] Starte Applikation im Debug-Modus...
echo     (Ausgaben werden hier direkt angezeigt)
echo.

cd /d "%APP_DIR%"
:: Browser-Start
start /b "" cmd /c "timeout /t 5 >nul && start http://localhost:%PORT%"

:: Start ohne '>nul 2>&1', damit man alle Fehlermeldungen von Next.js sieht
"%NODE_EXE%" "node_modules\next\dist\bin\next" start -p %PORT%

echo.
echo Server wurde beendet oder konnte nicht starten.
pause