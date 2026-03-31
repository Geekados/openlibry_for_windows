@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: --- KONFIGURATION ---
set "PORT=3000"
set "KEEP_MAX_BACKUPS=20"
:: Langzeit-Archiv auf das Doppelte begrenzen
set /a "MAX_ARCHIVE_BACKUPS=%KEEP_MAX_BACKUPS% * 2"

set "NODE_EXE=%~dp0..\node\node.exe"
set "APP_DIR=%~dp0..\app"
set "BACKUP_BASE=%~dp0..\app\backups"
set "DB_SRC=%~dp0..\app\database"
set "IMG_SRC=%~dp0..\app\images"

echo ========================================
echo   OpenLibry Backup- und Start-System
echo ========================================

:: 1. VERZEICHNISSE ANLEGEN
if not exist "%BACKUP_BASE%\database\daily" mkdir "%BACKUP_BASE%\database\daily"
if not exist "%BACKUP_BASE%\database\archive" mkdir "%BACKUP_BASE%\database\archive"
if not exist "%BACKUP_BASE%\images" mkdir "%BACKUP_BASE%\images"

:: Datum (Zeitstempel) generieren (Format: YYYY-MM-DD)
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "STAMP_DAY=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%"
set "STAMP_MONTH=%datetime:~0,4%-%datetime:~4,2%"

:: 2. TÄGLICHE ROTATION (Die letzten %KEEP_MAX_BACKUPS% Tage)
set "DB_DAILY_ZIP=%BACKUP_BASE%\database\daily\bkp_db_daily_%STAMP_DAY%.zip"
if not exist "%DB_DAILY_ZIP%" (
    echo [1/5] Packe taegliches DB-Backup (%STAMP_DAY%)...
    powershell -Command "Compress-Archive -Path '%DB_SRC%' -DestinationPath '%DB_DAILY_ZIP%' -Force"
    
    pushd "%BACKUP_BASE%\database\daily"
    for /f "skip=%KEEP_MAX_BACKUPS% delims=" %%F in ('dir "bkp_db_daily_*.zip" /b /o-d') do (
        echo [DELETE] Entferne altes Tages-Backup: %%F
        del "%%F"
    )
    popd
)

:: 3. MONATLICHE LANGZEIT-SICHERUNG (Begrenzt auf %MAX_ARCHIVE_BACKUPS%)
set "DB_ARCHIVE_ZIP=%BACKUP_BASE%\database\archive\bkp_db_archive_%STAMP_MONTH%.zip"
if not exist "%DB_ARCHIVE_ZIP%" (
    echo [2/5] Erstelle neues Monats-Archiv der Datenbank (%STAMP_MONTH%)...
    powershell -Command "Compress-Archive -Path '%DB_SRC%' -DestinationPath '%DB_ARCHIVE_ZIP%' -Force"
    
    pushd "%BACKUP_BASE%\database\archive"
    for /f "skip=%MAX_ARCHIVE_BACKUPS% delims=" %%F in ('dir "bkp_db_archive_*.zip" /b /o-d') do (
        echo [DELETE] Entferne altes Monats-Archiv: %%F
        del "%%F"
    )
    popd
)

:: 4. BILDER-SICHERUNG (Monatlich, taeglich aktualisiert)
set "IMG_ZIP=%BACKUP_BASE%\images\bkp_images_%STAMP_MONTH%.zip"
echo [3/5] Aktualisiere Image-Backup (%STAMP_MONTH%)...
powershell -Command "if (Test-Path '%IMG_SRC%') { Compress-Archive -Path '%IMG_SRC%' -DestinationPath '%IMG_ZIP%' -Force }"

echo.

:: 3. PRÜFUNG: LÄUFT DER SERVER SCHON?
echo [4/5] Pruefe Instanz-Status...
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
if %errorlevel% equ 0 (
    echo [INFO] OpenLibry aktiv. Browser wird geoeffnet...
    start http://localhost:%PORT%
    timeout /t 3 >nul
    exit
)

:: 5. STARTVORGANG
echo [5/5] OpenLibry wird gestartet...
cd /d "%APP_DIR%"

:: Browser mit kurzer Verzögerung starten
start /b "" cmd /c "timeout /t 5 >nul && start http://localhost:%PORT%"

:: Der eigentliche Startbefehl (im Hintergrund via START /B)
:: Damit die Batch-Datei weiterlaufen und Eingaben abfangen kann
start /b "" "%NODE_EXE%" "node_modules\next\dist\bin\next" start -p %PORT% >nul 2>&1

:STATUS_LOOP
cls
echo ===========================================================
echo            OpenLibry läuft im Hintergrund
echo ===========================================================
echo.
echo  ZUGRIFF:
echo  Oeffne deinen Browser unter: http://localhost:%PORT%
echo.
echo  -----------------------------------------------------------
echo  WICHTIG:
echo  Dieses Fenster NICHT schliessen, waehrend du arbeitest!
echo  Die Datenbank ist aktiv.
echo  -----------------------------------------------------------
echo.
echo  BEENDEN:
echo  Druecke [Q] um OpenLibry sicher zu beenden.
echo.

:: Abfrage der Taste
set /p "userinput=Eingabe: "

if /i "%userinput%"=="q" (
    echo.
    echo [INFO] OpenLibry wird beendet...
    :: Beendet den Node-Prozess, der auf dem Port lauscht
    for /f "tokens=5" %%a in ('netstat -aon ^| findstr :%PORT% ^| findstr LISTENING') do taskkill /f /pid %%a >nul 2>&1
    echo [OK] Server gestoppt.
    timeout /t 2 >nul
    exit
)

:: Falls eine falsche Taste gedrückt wurde, springe zurück zum Status
goto STATUS_LOOP
