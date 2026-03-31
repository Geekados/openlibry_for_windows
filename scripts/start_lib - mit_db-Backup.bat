@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: --- 1. KONFIGURATION ---
set "PORT=3000"
set "KEEP_MAX_BACKUPS=20"
:: Archiv-Begrenzung (z.B. 40 Monate)
set /a "MAX_ARCHIVE_BACKUPS=%KEEP_MAX_BACKUPS% * 2"

:: Pfade setzen
set "NODE_DIR=%~dp0..\node"
set "NODE_EXE=%NODE_DIR%\node.exe"
set "APP_DIR=%~dp0..\app"
set "BACKUP_BASE=%APP_DIR%\backups"
set "DB_DIR=%APP_DIR%\database"
set "DB_FILE=%DB_DIR%\dev.db"
set "IMG_SRC=%APP_DIR%\images"

:: Node in den Pfad aufnehmen
set "PATH=%NODE_DIR%;%PATH%"

cls
echo ===========================================================
echo            OpenLibry Backup- und Start-System
echo ===========================================================

:: --- 2. VERZEICHNISSE PRUEFEN (Self-Healing) ---
if not exist "%DB_DIR%" mkdir "%DB_DIR%"
if not exist "%BACKUP_BASE%\database\daily" mkdir "%BACKUP_BASE%\database\daily"
if not exist "%BACKUP_BASE%\database\archive" mkdir "%BACKUP_BASE%\database\archive"
if not exist "%IMG_SRC%" mkdir "%IMG_SRC%"
if not exist "%BACKUP_BASE%\images" mkdir "%BACKUP_BASE%\images"

:: Zeitstempel generieren
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "STAMP_DAY=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%"
set "STAMP_MONTH=%datetime:~0,4%-%datetime:~4,2%"

:: --- 3. BACKUP-LOGIK (Taeglich, Monatlich, Bilder) ---
if exist "%DB_FILE%" (
    echo [1/5] Verwalte Datensicherungen...
    
    :: A. TÄGLICHE ROTATION
    set "DB_DAILY_ZIP=%BACKUP_BASE%\database\daily\bkp_db_daily_%STAMP_DAY%.zip"
    if not exist "!DB_DAILY_ZIP!" (
        echo [STEP] Erstelle taegliches DB-Backup (%STAMP_DAY%)...
        powershell -Command "Compress-Archive -Path '%DB_DIR%' -DestinationPath '!DB_DAILY_ZIP!' -Force"
        pushd "%BACKUP_BASE%\database\daily"
        for /f "skip=%KEEP_MAX_BACKUPS% delims=" %%F in ('dir "bkp_db_daily_*.zip" /b /o-d') do del "%%F"
        popd
    )

    :: B. MONATLICHE LANGZEIT-SICHERUNG
    set "DB_ARCHIVE_ZIP=%BACKUP_BASE%\database\archive\bkp_db_archive_%STAMP_MONTH%.zip"
    if not exist "!DB_ARCHIVE_ZIP!" (
        echo [STEP] Erstelle neues Monats-Archiv (%STAMP_MONTH%)...
        powershell -Command "Compress-Archive -Path '%DB_DIR%' -DestinationPath '!DB_ARCHIVE_ZIP!' -Force"
        pushd "%BACKUP_BASE%\database\archive"
        for /f "skip=%MAX_ARCHIVE_BACKUPS% delims=" %%F in ('dir "bkp_db_archive_*.zip" /b /o-d') do del "%%F"
        popd
    )

    :: C. BILDER-SICHERUNG (Monatlich aktualisiert)
    set "IMG_ZIP=%BACKUP_BASE%\images\bkp_images_%STAMP_MONTH%.zip"
    if exist "%IMG_SRC%" (
        echo [STEP] Aktualisiere Image-Backup (%STAMP_MONTH%)...
        powershell -Command "Compress-Archive -Path '%IMG_SRC%' -DestinationPath '!IMG_ZIP!' -Force"
    )
)

:: --- 4. DATENBANK-CHECK ^& SICHERE MIGRATION ---
echo [2/5] Pruefe Datenbank-Integritaet...
cd /d "%APP_DIR%"

if not exist "%DB_FILE%" (
    echo [INFO] Keine Datenbank gefunden. Initialisiere neue Struktur...
    call npx prisma db push --accept-data-loss >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Datenbank erfolgreich erstellt.
    ) else (
        echo [FEHLER] Initialisierung fehlgeschlagen.
        pause & exit
    )
) else (
    :: Migration-Status pruefen (Update-Logik für Datenbank-Migration)
    call npx prisma migrate status >nul 2>&1
    if !errorlevel! neq 0 (
        echo [!] Datenbank-Update erforderlich.
        echo [STEP] Erstelle Sicherheitskopie: dev.db.migrate...
        copy /y "%DB_FILE%" "%DB_DIR%\dev.db.migrate" >nul
        
        echo [STEP] Fuehre Migration aus...
        call npx prisma migrate deploy >nul 2>&1
        
        if !errorlevel! equ 0 (
            echo [OK] Update erfolgreich abgeschlossen.
        ) else (
            echo.
            echo ########## FEHLER BEIM UPDATE ##########
            echo Die Datenbank-Migration ist fehlgeschlagen.
            echo Deine Originaldaten sind in 'dev.db.migrate' gesichert.
            echo ########################################
            pause & exit
        )
    ) else (
        echo [OK] Datenbank ist auf dem neuesten Stand.
    )
)
cd /d "%~dp0"

:: --- 5. PORT-CHECK (Instanz-Pruefung) ---
echo [3/5] Pruefe Port %PORT%...
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
if %errorlevel% equ 0 (
    echo [INFO] OpenLibry bereits aktiv. Browser wird geoeffnet...
    start http://localhost:%PORT%
    timeout /t 3 >nul
    exit
)

:: --- 6. SERVER-START ^& UI ---
echo [4/5] OpenLibry wird gestartet...
cd /d "%APP_DIR%"
start /b "" cmd /c "timeout /t 5 >nul && start http://localhost:%PORT%"
start /b "" "%NODE_EXE%" "node_modules\next\dist\bin\next" start -p %PORT% >nul 2>&1

:STATUS_LOOP
cls
echo ===========================================================
echo            OpenLibry laeuft im Hintergrund
echo ===========================================================
echo.
echo  ADRESSE: http://localhost:%PORT%
echo.
echo  -----------------------------------------------------------
echo  WICHTIG:
echo  Dieses Fenster NICHT schliessen, waehrend du arbeitest!
echo  Die Datenbank und openLibry sind aktiv.
echo  -----------------------------------------------------------
echo.
echo  BEENDEN:
echo  Tippe [Q] und druecke Enter, um OpenLibry sicher zu beenden.
echo.

set /p "userinput=Eingabe: "
if /i "%userinput%"=="q" (
    echo.
    echo [INFO] OpenLibry wird beendet...
    for /f "tokens=5" %%a in ('netstat -aon ^| findstr :%PORT% ^| findstr LISTENING') do taskkill /f /pid %%a >nul 2>&1
    echo [OK] Server gestoppt.
    timeout /t 2 >nul
    exit
)
goto STATUS_LOOP
