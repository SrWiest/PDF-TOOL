#!/usr/bin/env bash
set -e

echo "[INFO] Criando estrutura de diretórios..."
mkdir -p src specs requirements installer licenses .github/workflows

echo "[INFO] Criando script principal..."
cat > src/pdf_merge_tool_win.py <<'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# PDF Merge Tool - Copyright (c) 2025 SrWiest
# Licença: Consulte LICENSE e THIRD_PARTY_LICENSES.txt
# (Este é o conteúdo do arquivo src/pdf_merge_tool_win.py,
# que é o ponto de entrada principal da aplicação.)
# O conteúdo real está no arquivo correspondente.
# Este bloco é apenas um placeholder para o script de criação de estrutura.
print("Este é um placeholder para o script principal.")
PYEOF



echo "[INFO] Requirements..."
cat > requirements/requirements-lite.txt <<'EOF'
PyPDF2
Pillow
# img2pdf (opcional, para recuperação de imagem)
pikepdf
EOF

cat > requirements/requirements-full.txt <<'EOF'
PyPDF2
Pillow
img2pdf
pdf2image
pytesseract
ocrmypdf
EOF

echo "[INFO] Inno Setup + .reg..."
cat > installer/install_full.iss <<'EOF'
#define MyAppName "PDF Merge Tool"
#define MyAppVersion GetEnv("GITHUB_REF_NAME")
#define MyAppPublisher "SrWiest"
#define MyExeLite "pdf_merge_tool_win_lite.exe"
#define MyExeFull "pdf_merge_tool_win_full.exe"

[Setup]
AppId={{4DA7F9C5-1A2B-4B66-AB55-248D12345679}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\PDFMergeTool
DisableProgramGroupPage=yes
OutputBaseFilename=PDFMergeTool-Setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Types]
Name: "full"; Description: "Completo (com OCR)"; Flags: iscustom
Name: "lite"; Description: "Leve (sem OCR)"

[Components]
Name: "core"; Description: "Ferramenta base"; Types: full lite; Flags: fixed
Name: "ocr"; Description: "Suporte OCR (Tesseract / ocrmypdf)"; Types: full

[Files]
Source: "..\dist\{#MyExeLite}"; DestDir: "{app}"; Components: core; Flags: ignoreversion
Source: "..\dist\{#MyExeFull}"; DestDir: "{app}"; Components: ocr; Flags: ignoreversion
Source: "context_menu_full.reg"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyExeLite}"; WorkingDir: "{app}"
Name: "{desktop}\{#MyAppName}"; Filename: "{app}\{#MyExeLite}"; WorkingDir: "{app}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Área de Trabalho"; GroupDescription: "Opções adicionais:"; Flags: unchecked

[Run]
Filename: "regedit.exe"; Parameters: "/s {app}\context_menu_full.reg"; Flags: runhidden; Check: WizardIsComponentSelected('ocr')

[Code]
function GetSelectedExe(): String;
begin
  if WizardIsComponentSelected('ocr') then
    Result := ExpandConstant('{app}\{#MyExeFull}')
  else
    Result := ExpandConstant('{app}\{#MyExeLite}');
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Lnk: String;
  SendToPath: String;
  ExeSel: String;
begin
  if CurStep = ssPostInstall then
  begin
    ExeSel := GetSelectedExe();
    if FileExists(ExpandConstant('{autoprograms}\{#MyAppName}.lnk')) then
      DeleteFile(ExpandConstant('{autoprograms}\{#MyAppName}.lnk'));
    CreateShellLink(ExpandConstant('{autoprograms}\{#MyAppName}.lnk'), ExeSel, '--auto-name --final-shrink', ExpandConstant('{app}'), 0, '');

    if FileExists(ExpandConstant('{desktop}\{#MyAppName}.lnk')) then
    begin
      DeleteFile(ExpandConstant('{desktop}\{#MyAppName}.lnk'));
      CreateShellLink(ExpandConstant('{desktop}\{#MyAppName}.lnk'), ExeSel, '--auto-name --final-shrink', ExpandConstant('{app}'), 0, '');
    end;

    SendToPath := ExpandConstant('{userappdata}\Microsoft\Windows\SendTo');
    Lnk := SendToPath + '\Unir PDFs (PDF Merge Tool).lnk';
    if FileExists(Lnk) then
      DeleteFile(Lnk);
    CreateShellLink(Lnk, ExeSel, '--auto-name --final-shrink', ExpandConstant('{app}'), 0, '');
  end;
end;
EOF

cat > installer/context_menu_full.reg <<'EOF'
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\SystemFileAssociations\.pdf\shell\PDFMergeTool]
@="Unir PDFs (PDF Merge Tool)"
"MultiSelectModel"="Document"

[HKEY_CLASSES_ROOT\SystemFileAssociations\.pdf\shell\PDFMergeTool\command]
@="\"C:\\Program Files\\PDFMergeTool\\pdf_merge_tool_win_full.exe\" --auto-name --final-shrink %*"
EOF

echo "[INFO] Workflow..."
cat > .github/workflows/build-windows-installer.yml <<'EOF'
name: Build Windows Installer

on:
  push:
    tags:
      - "v*"
  workflow_dispatch:

jobs:
  build:
    runs-on: windows-latest
    strategy:
      matrix:
        build-type: [lite, full]

    env:
      PMT_BUILD_VERSION: ${{ github.ref_name }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install base deps
        run: |
          python -m pip install --upgrade pip
          pip install pyinstaller

      - name: Install requirements (matrix)
        run: |
          if ("${{ matrix.build-type }}" -eq "lite") {
            pip install -r requirements/requirements-lite.txt
          } else {
            pip install -r requirements/requirements-full.txt
          }

      - name: Build (PyInstaller)
        run: |
            if ("${{ matrix.build-type }}" -eq "lite") {
              pyinstaller specs/pdf_merge_lite.spec
            } else {
              pyinstaller specs/pdf_merge_full.spec
            }
            dir dist

      - name: Install Inno Setup (only full)
        if: matrix.build-type == 'full'
        run: choco install innosetup --yes

      - name: Build Installer (only full)
        if: matrix.build-type == 'full'
        run: |
          cd installer
          "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" install_full.iss
          dir Output
          cd ..

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.build-type }}-artifacts
          path: |
            dist/*.exe
            installer/Output/*.exe
          if-no-files-found: ignore

EOF

cat > licenses/THIRD_PARTY_LICENSES.txt <<'EOF'
Componentes principais: PyPDF2 (BSD), Pillow (permissiva), img2pdf (LGPL-3.0),
pikepdf (MPL 2.0), pdf2image (MIT), pytesseract (Apache 2.0), ocrmypdf (Apache 2.0), Tesseract (Apache 2.0).
Ver documentação para detalhes de distribuição.
EOF

cat > README.md <<'EOF'
# PDF Merge Tool

Ferramenta para unir PDFs, remoção de páginas em branco, OCR (Full), shrink opcional (qpdf/pikepdf se presentes).
Build automático: criar tag v1.0.0 -> Actions gera artefatos.

Uso rápido:
pdf_merge_tool_win_lite.exe A.pdf B.pdf
pdf_merge_tool_win_full.exe A.pdf B.pdf --final-shrink --shrink-report

Versão:
pdf_merge_tool_win_full.exe --version
EOF

cat > .gitignore <<'EOF'
__pycache__/
*.pyc
dist/
build/
venv/
.env/
.idea/
.vscode/
*.log
EOF

echo "[OK] Estrutura criada. Agora revise src/pdf_merge_tool_win.py se está completo."
