@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: --- KONFIGURATION ---
set "PORT=3000"
set "NODE_EXE=%~dp0..\node\node.exe"
set "APP_DIR=%~dp0..\app"
set "DB_FILE=%~dp0..\app\database\dev.db"
set "BACKUP_DIR=%~dp0..\app\database\backups"

echo ========================================
echo   OpenLibry Management System
echo ========================================

:: 1. BACKUP-ORDNER & ZEITSTEMPEL
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:: Datum holen (Format: YYYY-MM-DD)
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "STAMP=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%"
set "BACKUP_FILE=%BACKUP_DIR%\backup_%STAMP%.db"

:: 2. BACKUP DURCHFÜHREN (Nur wenn heute noch keins gemacht wurde)
if not exist "%BACKUP_FILE%" (
    echo [1/3] Erstelle Sicherheits-Backup...
    if exist "%DB_FILE%" (
        copy "%DB_FILE%" "%BACKUP_FILE%" /Y >nul
        echo [OK] Backup erstellt: backup_%STAMP%.db
        
        :: Alte Backups loeschen (aelter als 30 Tage)
        forfiles /p "%BACKUP_DIR%" /m *.db /d -30 /c "cmd /c del @path" 2>nul
    ) else (
        echo [!] Hinweis: Keine Datenbank zum Sichern gefunden.
    )
) else (
    echo [1/3] Backup fuer heute bereits vorhanden.
)

echo.

:: 3. PRÜFUNG: LÄUFT DER SERVER SCHON?
echo [2/3] Pruefe Instanz-Status...
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
if %errorlevel% equ 0 (
    echo [INFO] OpenLibry ist bereits aktiv. Oeffne Browser...
    start http://localhost:%PORT%
    timeout /t 3 >nul
    exit
)

:: 4. SERVER STARTEN
echo [3/3] OpenLibry wird gestartet...
cd /d "%APP_DIR%"

:: Browser mit Verzoegerung oeffnen
start /b "" cmd /c "timeout /t 5 >nul && start http://localhost:%PORT%"

:: Next.js Server ausfuehren
"%NODE_EXE%" "node_modules\next\dist\bin\next" start -p %PORT%

pause