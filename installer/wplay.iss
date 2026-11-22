; wPlay — Windows installer script (Inno Setup 6)
;
; Compiled by the GitHub Actions workflow (build-windows.yml) on the
; windows-2022 runner, which ships Inno Setup preinstalled. It packages
; the portable dist/ bundle produced by the "Bundle portable package"
; step into a single wPlay-Setup.exe with Start Menu / desktop
; shortcuts and an uninstaller.
;
; All relative paths below are relative to THIS script's folder
; (installer/), so dist/ and assets/ are reached via "..\".

#define AppName "wPlay"
#define AppVersion "0.1.0"
#define AppExeName "wplay.exe"

[Setup]
AppId={{A499B9C6-222C-493F-AC4E-2ECED39CB0FE}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=wPlay
AppSupportURL=https://github.com/elyos141299/wplay
DefaultDirName={autopf}\wPlay
DefaultGroupName=wPlay
DisableProgramGroupPage=yes
; Per-user install: no administrator prompt.
PrivilegesRequired=lowest
OutputDir=..\installer-output
OutputBaseFilename=wPlay-Setup
SetupIconFile=..\assets\wplay.ico
LicenseFile=..\licenses\AGPL-3.0.txt
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\dist\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\wPlay"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{group}\Uninstall wPlay"; Filename: "{uninstallexe}"
Name: "{autodesktop}\wPlay"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch wPlay"; Flags: nowait postinstall skipifsilent
