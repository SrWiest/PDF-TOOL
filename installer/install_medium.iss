// ===================================================================
// Inno Setup Script para PDF Merge Tool (MEDIUM)
// ===================================================================

; Inno Setup Script para PDF Merge Tool (MEDIUM)

#ifndef MyAppName
  #define MyAppName "PDF Merge Tool Medium"
#endif

#ifndef MyAppExeName
  #define MyAppExeName "pdf_merge_tool_win_medium.exe"
#endif

; Versão passada via /DMyAppVersion=... (workflow injeta). Fallback:
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0-dev"
#endif

#define MyAppPublisher "SrWiest"
#define MyAppURL "https://github.com/SrWiest/PDF-TOOL"

[Setup]
; GUID único para versão Medium
AppId={{2F1D9E3G-68F1-5F2D-AF1F-AFEA8G8A4BFA}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\PDF Merge Tool Medium
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=PDFMergeTool-Medium-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
LicenseFile=..\LICENSE
PrivilegesRequired=admin

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "contextmenu"; Description: "Adicionar ao menu de contexto do Windows"; GroupDescription: "Integração do Sistema"

[Files]
; Copiar todos os arquivos da build Medium
Source: "..\dist\pdf_merge_tool_win_medium\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\licenses\THIRD_PARTY_LICENSES.txt"; DestDir: "{app}\licenses"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: FileExists(ExpandConstant('..\licenses\THIRD_PARTY_LICENSES.txt'))

; Registro para menu de contexto (opcional)
Source: "context_menu_medium.reg"; DestDir: "{tmp}"; Flags: deleteafterinstall; Tasks: contextmenu

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{#MyAppName} (Command Line)"; Filename: "cmd.exe"; Parameters: "/k cd /d ""{app}"""; Comment: "Abrir linha de comando na pasta do {#MyAppName}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Registro para menu de contexto (se selecionado)
Root: HKCR; Subkey: "*\shell\PDFMergeMedium"; ValueType: string; ValueName: ""; ValueData: "Unir com PDF Merge Tool Medium"; Flags: uninsdeletekey; Tasks: contextmenu
Root: HKCR; Subkey: "*\shell\PDFMergeMedium\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: contextmenu

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\temp"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Log da instalação
    Log('PDF Merge Tool Medium instalado com sucesso em: ' + ExpandConstant('{app}'));
  end;
end;

// ===================================================================
// FIM DO ARQUIVO - PDF Merge Tool Medium
// ===================================================================
