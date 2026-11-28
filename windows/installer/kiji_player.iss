; Instalador de Kiji Player para Windows (Inno Setup 6).
; Se arma con `dart run tool/installer.dart`, que compila la app desde limpio y pasa la versión
; y la carpeta del runtime de Visual C++.
; Se instala para el usuario actual (sin pedir permisos de administrador). Al desinstalar no se
; borran los datos de Kiji (playlists, descargas, copias): quedan en la carpeta del usuario.

#ifndef AppVersion
  #error Falta /DAppVersion (usa tool/installer.dart)
#endif
#ifndef VcRuntime
  #error Falta /DVcRuntime (usa tool/installer.dart)
#endif

#define AppName "Kiji Player"
#define AppExe "kiji_player.exe"
#define Release "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{A6208702-5F89-413B-A283-44FC74F88E7C}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Kiji Player
AppPublisherURL=https://github.com/kijiplayer/kiji-player
AppSupportURL=https://github.com/kijiplayer/kiji-player/issues
AppUpdatesURL=https://github.com/kijiplayer/kiji-player/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
LicenseFile=..\..\LICENSE
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
OutputDir=..\..\build\installer
OutputBaseFilename=Kiji_Player_{#AppVersion}_Windows_Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Release}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Runtime de Visual C++ junto a la app (Flutter lo necesita y no todas las PC lo traen).
Source: "{#VcRuntime}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#VcRuntime}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#VcRuntime}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; «Iniciar Kiji al encender la PC» (0.9): la entrada la crea Kiji solo si el usuario lo prende.
; El instalador no la crea; al desinstalar se borra (ValueType none + dontcreatekey: no se escribe nada).
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "KijiPlayer"; Flags: uninsdeletevalue dontcreatekey
[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; "Actualizar" desde Kiji (0.8.4): Kiji abre este instalador en silencio con /KIJIUPDATE=1 y se
; cierra; al terminar, Kiji vuelve a abrirse sola (como la persona, aunque el instalador pidió permisos).
Filename: "{app}\{#AppExe}"; Flags: nowait runasoriginaluser; Check: IsKijiUpdate

[Code]
function IsKijiUpdate: Boolean;
begin
  Result := WizardSilent and (ExpandConstant('{param:KIJIUPDATE|0}') = '1');
end;
