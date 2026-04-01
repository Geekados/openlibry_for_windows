@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: --- 1. KONFIGURATION ---
set "PORT=3000"
set "KEEP_MAX_BACKUPS=20"
set /a "MAX_ARCHIVE_BACKUPS=%KEEP_MAX_BACKUPS% * 2"

set "NODE_DIR=%~dp0..\node"
set "NODE_EXE=%NODE_DIR%\node.exe"
set "APP_DIR=%~dp0..\app"
set "DB_DIR=%APP_DIR%\database"
set "DB_FILE=%DB_DIR%\dev.db"
set "IMG_SRC=%APP_DIR%\images"
set "BACKUP_BASE=%APP_DIR%\backups"

set "PATH=%NODE_DIR%;%PATH%"

cls
echo ===========================================================
echo               OpenLibry Backup- und Start-System
echo ===========================================================

:: --- 2. ORDNER-CHECK (Self-Healing) ---
if not exist "%DB_DIR%" mkdir "%DB_DIR%"
if not exist "%DB_DIR%\custom" mkdir "%DB_DIR%\custom"
if not exist "%BACKUP_BASE%\database\daily" mkdir "%BACKUP_BASE%\database\daily"
if not exist "%BACKUP_BASE%\database\archive" mkdir "%BACKUP_BASE%\database\archive"
if not exist "%IMG_SRC%" mkdir "%IMG_SRC%"
if not exist "%BACKUP_BASE%\images" mkdir "%BACKUP_BASE%\images"

:: --- 3. ZEITSTEMPEL (Robust via PowerShell) ---
set "STAMP_DAY=no-date"
set "STAMP_MONTH=no-month"
for /f "tokens=1,2 delims= " %%A in ('powershell -Command "Get-Date -Format 'yyyy-MM-dd yyyy-MM'"') do (
    set "STAMP_DAY=%%A"
    set "STAMP_MONTH=%%B"
)

:: --- 4. BACKUP-LOGIK (Lineare Struktur) ---
:: Falls keine DB da ist, koennen wir das DB-Backup ueberspringen, 
:: aber das Image-Backup wollen wir trotzdem pruefen.
if not exist "%DB_FILE%" goto IMG_BACKUP

echo [1/5] Verwalte Datensicherungen...

:: A. TÄGLICHE DB-ROTATION
set "DB_DAILY_ZIP=%BACKUP_BASE%\database\daily\bkp_db_daily_%STAMP_DAY%.zip"
if exist "!DB_DAILY_ZIP!" goto SKIP_DAILY
    echo [STEP] Erstelle taegliches DB-Backup...
    powershell -Command "Compress-Archive -Path '%DB_DIR%' -DestinationPath '!DB_DAILY_ZIP!' -Force"
    pushd "%BACKUP_BASE%\database\daily"
    for /f "skip=%KEEP_MAX_BACKUPS% delims=" %%F in ('dir "bkp_db_daily_*.zip" /b /o-d') do del "%%F"
    popd
:SKIP_DAILY

:: B. MONATLICHE DB-LANGZEIT-SICHERUNG
set "DB_ARCHIVE_ZIP=%BACKUP_BASE%\database\archive\bkp_db_archive_%STAMP_MONTH%.zip"
if exist "!DB_ARCHIVE_ZIP!" goto SKIP_ARCHIVE
    echo [STEP] Erstelle neues Monats-Archiv...
    powershell -Command "Compress-Archive -Path '%DB_DIR%' -DestinationPath '!DB_ARCHIVE_ZIP!' -Force"
    pushd "%BACKUP_BASE%\database\archive"
    for /f "skip=%MAX_ARCHIVE_BACKUPS% delims=" %%F in ('dir "bkp_db_archive_*.zip" /b /o-d') do del "%%F"
    popd
:SKIP_ARCHIVE

:IMG_BACKUP
:: C. BILDER-SICHERUNG (Monatlich aktualisiert)
if not exist "%IMG_SRC%" goto DB_CHECK
set "IMG_ZIP=%BACKUP_BASE%\images\bkp_images_%STAMP_MONTH%.zip"
:: Wir aktualisieren das Image-Zip nur, wenn es noch nicht existiert (fuer diesen Monat)
if exist "!IMG_ZIP!" goto DB_CHECK
    echo [STEP] Aktualisiere Image-Backup (%STAMP_MONTH%)...
    powershell -Command "Compress-Archive -Path '%IMG_SRC%' -DestinationPath '!IMG_ZIP!' -Force"

:DB_CHECK
:: --- 5. DATENBANK-CHECK & MIGRATION ---
echo [2/5] Pruefe Datenbank-Integritaet...
cd /d "%APP_DIR%"
set "PRISMA_RUN="%NODE_EXE%" node_modules\prisma\build\index.js"

if not exist "%DB_FILE%" (
    echo [INFO] Initialisiere neue Struktur...
    call %PRISMA_RUN% migrate deploy
    if !errorlevel! neq 0 call %PRISMA_RUN% db push --accept-data-loss
    goto START_SERVER
)

call %PRISMA_RUN% migrate status >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] Datenbank ist aktuell.
    goto START_SERVER
)

echo [!] Update erforderlich. Sichere Datenbank...
copy /y "%DB_FILE%" "%DB_DIR%\dev.db.migrate" >nul
call %PRISMA_RUN% migrate deploy
if !errorlevel! neq 0 (
    echo [FEHLER] Migration fehlgeschlagen.
    pause & exit
)



:START_SERVER

cd /d "%~dp0"
:: --- 6. PORT-CHECK & START ---
echo [3/5] Pruefe Port %PORT%...
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
if %errorlevel% equ 0 (
    start http://localhost:%PORT%
    exit
)

echo [4/5] OpenLibry startet...
cd /d "%APP_DIR%"
start /b "" cmd /c "timeout /t 5 >nul && start http://localhost:%PORT%"
start /b "" "%NODE_EXE%" "node_modules\next\dist\bin\next" start -p %PORT% >nul 2>&1

:STATUS_LOOP
cls
echo ===========================================================
echo               OpenLibry laeuft im Hintergrund
echo ===========================================================
echo.
echo  ADRESSE: http://localhost:%PORT%
echo.
echo  -----------------------------------------------------------
echo  WICHTIG: Fenster NICHT schliessen!
echo  -----------------------------------------------------------
echo.
echo  BROWSER: Tippe [B] und Enter, um OpenLibry im Browser zu oeffnen.
echo.
echo  BEENDEN: Tippe [Q] und Enter zum Beenden.
echo.

set "userinput="
set /p "userinput=Eingabe: "

if /i "%userinput%" equ "b" (
    start http://localhost:%PORT%
    goto STATUS_LOOP
)

if /i "%userinput%" neq "q" goto STATUS_LOOP

echo.
echo [INFO] Beende alle OpenLibry-Prozesse...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :%PORT%') do (
    taskkill /f /t /pid %%a >nul 2>&1
)
taskkill /f /im node.exe /fi "WINDOWTITLE eq next-server*" >nul 2>&1
echo [OK] Beenden-Befehle gesendet.
timeout /t 2 >nul
exit
