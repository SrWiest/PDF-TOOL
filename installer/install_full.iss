// ===================================================================
// INÍCIO DO ARQUIVO COMPLETO E CORRIGIDO
// ===================================================================

; Inno Setup Script para PDF Merge Tool (FULL)

#ifndef MyAppName
  #define MyAppName "PDF Merge Tool"
#endif

#ifndef MyAppExeName
  #define MyAppExeName "pdf_merge_tool_win_full.exe"
#endif

; Versão passada via /DMyAppVersion=... (workflow injeta). Fallback:
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0-dev"
#endif

#define MyAppPublisher "SrWiest"
#define MyAppURL "https://github.com/SrWiest/PDF-TOOL"

[Setup]
; GUID direto com chaves duplas para gerar {GUID} final
AppId={{1E0C8E2F-57E0-4E1C-9F0E-9FD97F693AF9}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=PDFMergeTool-Setup
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

[Files]
; --- CORREÇÃO APLICADA AQUI ---
; A linha abaixo foi alterada para copiar todos os arquivos (*) da pasta de build do PyInstaller,
; que é o método correto para builds no modo "pasta".
Source: "..\dist\pdf_merge_tool_win_full\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\licenses\THIRD_PARTY_LICENSES.txt"; DestDir: "{app}\licenses"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: FileExists(ExpandConstant('..\licenses\THIRD_PARTY_LICENSES.txt'))

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"

// ===================================================================
// FIM DO ARQUIVO COMPLETO E CORRIGIDO
// ===================================================================
