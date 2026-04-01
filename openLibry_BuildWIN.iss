; --- PRÄPROZESSOR DEFINITIONEN ---
#define MyBuildPath "C:\InnoInstaller\OpenLibry_Build"
#define MyAppName "OpenLibry"
#define MyAppVersion "1.8.1"

[Setup]
AppId={{A7302AFB-440A-44FF-A823-1AAB591F7EF5}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
DefaultDirName={autopf}\OpenLibry
DefaultGroupName=OpenLibry
UninstallDisplayIcon={app}\app\public\favicon.ico
Compression=lzma2
SolidCompression=yes
OutputDir=.\Output
OutputBaseFilename=OpenLibry_Setup_v{#MyAppVersion}
ShowLanguageDialog=no
DisableProgramGroupPage=yes
AppendDefaultGroupName=yes
CreateUninstallRegKey=yes
PrivilegesRequired=admin

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Files]
; 1. SYSTEM-KRITISCHE USER-DATEIEN
Source: "{#MyBuildPath}\app\.env"; DestDir: "{app}\app"; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#MyBuildPath}\app\database\dev.db"; DestDir: "{app}\app\database"; Flags: onlyifdoesntexist uninsneveruninstall skipifsourcedoesntexist

; 2. PROGRAMM-DATEIEN (Flag 'uninsrestartdelete' ENTFERNT)
Source: "{#MyBuildPath}\app\*"; DestDir: "{app}\app"; \
    Flags: recursesubdirs createallsubdirs ignoreversion restartreplace; \
    Excludes: "database\dev.db, .env, images\*, backups\*"

; 3. NODE & SCRIPTS
Source: "{#MyBuildPath}\node\*"; DestDir: "{app}\node"; Flags: recursesubdirs createallsubdirs
Source: "{#MyBuildPath}\scripts\*"; DestDir: "{app}\scripts"; Flags: recursesubdirs createallsubdirs

; 4. Handbuch & Readme
Source: "{#MyBuildPath}\LIESMICH.txt"; DestDir: "{app}"; Flags: isreadme
Source: "{#MyBuildPath}\Handbuch_Backup.pdf"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
Name: "{app}\app\database"; Permissions: users-full; Flags: uninsneveruninstall
Name: "{app}\app\images"; Permissions: users-full; Flags: uninsneveruninstall
Name: "{app}\app\backups"; Permissions: users-full; Flags: uninsneveruninstall
Name: "{app}\app\backups\database"; Permissions: users-full; Flags: uninsneveruninstall
Name: "{app}\app\backups\database\daily"; Permissions: users-full; Flags: uninsneveruninstall
Name: "{app}\app\backups\database\archive"; Permissions: users-full; Flags: uninsneveruninstall
Name: "{app}\app\backups\images"; Permissions: users-full; Flags: uninsneveruninstall

[Icons]
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\scripts\start_openlibry.bat"; IconFilename: "{app}\app\public\favicon.ico"
Name: "{group}\{#MyAppName} starten"; Filename: "{app}\scripts\start_openlibry.bat"; IconFilename: "{app}\app\public\favicon.ico"
Name: "{group}\Meine Backups anzeigen"; Filename: "{win}\explorer.exe"; Parameters: "/root,""{app}\app\backups"""; IconFilename: "{app}\app\public\favicon.ico"
Name: "{group}\Customs-Ordner"; Filename: "{win}\explorer.exe"; Parameters: "/root,""{app}\app\database\custom"""; IconFilename: "{sys}\shell32.dll"; IconIndex: 3
Name: "{group}\Support-Tools\Handbuch & Hilfe (PDF)"; Filename: "{app}\Handbuch_Backup.pdf"
Name: "{group}\Support-Tools\OpenLibry Webseite besuchen"; Filename: "https://openlibry.de"
Name: "{group}\Support-Tools\{#MyAppName} Safe Mode (Diagnose)"; Filename: "{app}\scripts\start_openlibry_safe.bat"
Name: "{group}\{#MyAppName} deinstallieren"; Filename: "{uninstallexe}"; IconFilename: "{sys}\shell32.dll"; IconIndex: 31

[Run]
Filename: "{win}\notepad.exe"; Parameters: "{app}\LIESMICH.txt"; Description: "Liesmich-Datei oeffnen"; Flags: postinstall shellexec skipifsilent

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    MsgBox('Installation von {#MyAppName} erfolgreich!' #13#10#13#10 +
           'WICHTIGE HINWEISE:' #13#10 +
           '- Startet die App immer ueber das Desktop-Icon.' #13#10 +
           '- Bei Problemen findet Ihr im Startmenue unter "Support-Tools" den Safe Mode.' #13#10#13#10 +
           '- Sicherungen liegen unter: ' + ExpandConstant('{app}\app\backups') + #13#10#13#10 +
           'Viel Freude mit OpenLibry!', 
           mbInformation, MB_OK);
  end;
end;
procedure CurUninstallStepChanged(UninstallStep: TUninstallStep);
begin
  // Erst wenn die Deinstallation komplett abgeschlossen ist (post-uninstall)
  if UninstallStep = usPostUninstall then
  begin
    MsgBox('Die Programmdateien von {#MyAppName} wurden erfolgreich entfernt.' #13#10#13#10 +
           'HINWEIS: Deine persönlichen Daten (Datenbank, Bilder, Backups und .env) ' +
           'wurden nicht gelöscht und befinden sich weiterhin im Installationsverzeichnis.', 
           mbInformation, MB_OK);
  end;
end;
