[Setup]
AppId={{A7302AFB-440A-44FF-A823-1AAB591F7EF5}}
AppName=OpenLibry
AppVersion=1.8
VersionInfoVersion=1.8.0
DefaultDirName={autopf}\OpenLibry
DefaultGroupName=OpenLibry
PrivilegesRequired=admin
OutputDir=C:\InnoInstaller\Output
OutputBaseFilename=OpenLibry_Setup_{#SetupSetting("AppVersion")}
Compression=lzma
SolidCompression=yes

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
; Erlaubt dem Nutzer zu wählen, ob ein Icon erstellt werden soll
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Programm-Dateien (Datenbank und .env beim Update schützen)
Source: "C:\InnoInstaller\OpenLibry_Build\app\*"; DestDir: "{app}\app"; Flags: recursesubdirs createallsubdirs; Excludes: "database\*; .env"
Source: "C:\InnoInstaller\OpenLibry_Build\app\.env"; DestDir: "{app}\app"; Flags: onlyifdoesntexist
Source: "C:\InnoInstaller\OpenLibry_Build\app\database\*"; DestDir: "{app}\app\database"; Flags: recursesubdirs createallsubdirs onlyifdoesntexist
Source: "C:\InnoInstaller\OpenLibry_Build\node\*"; DestDir: "{app}\node"; Flags: recursesubdirs createallsubdirs
Source: "C:\InnoInstaller\OpenLibry_Build\scripts\*"; DestDir: "{app}\scripts"; Flags: recursesubdirs createallsubdirs

[Dirs]
; Schreibrechte für Datenbank und Bilder vergeben
Name: "{app}\app\database"; Permissions: users-full
Name: "{app}\app\images"; Permissions: users-full

[Icons]
; Das Desktop-Icon (nur wenn Task ausgewählt)
Name: "{autodesktop}\OpenLibry"; Filename: "{app}\scripts\start_lib.bat"; IconFilename: "{app}\app\public\favicon.ico"; WorkingDir: "{app}\scripts"; Tasks: desktopicon
; Der Startmenü-Eintrag (immer dabei)
Name: "{group}\OpenLibry"; Filename: "{app}\scripts\start_lib.bat"; IconFilename: "{app}\app\public\favicon.ico"; WorkingDir: "{app}\scripts"
[Files]
; Die Textdatei in den scripts-Ordner kopieren
Source: "C:\InnoInstaller\OpenLibry_Build\scripts\LiesMich.txt"; DestDir: "{app}\scripts"; Flags: isreadme

[Run]
; 1. Die Anleitung im Editor öffnen 
Filename: "notepad.exe"; Parameters: "{app}\scripts\LiesMich.txt"; Description: "Anleitung (LiesMich.txt) anzeigen"; Flags: postinstall shellexec nowait

; 2. Das Programm/die Batch-Datei starten 
Filename: "{app}\scripts\start_lib.bat"; Description: "{cm:LaunchProgram,OpenLibry}"; Flags: postinstall shellexec nowait