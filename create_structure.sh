#!/usr/bin/env bash
set -e

echo "[INFO] Criando estrutura de diretórios..."
mkdir -p src specs requirements installer licenses .github/workflows

echo "[INFO] Criando script principal..."
cat > src/pdf_merge_tool_win.py <<'PYEOF'
#!/usr/bin/env python3
"""
PDF Merge Tool (Windows) - Merge + shrink + OCR opcional
(Variante base: FULL só difere quando pacotes OCR instalados; binários externos não embutidos aqui)

Uso básico:
  pdf_merge_tool_win.exe file1.pdf file2.pdf ...
Principais opções:
  --no-ocr, --final-shrink, --shrink-report, --auto-name, --output, --out-dir, etc.

Retorno 0 em sucesso.
"""

import os, sys, time, subprocess, glob
from typing import List, Tuple
from PyPDF2 import PdfReader, PdfWriter

# ===================== Descoberta de diretórios de binários (se existirem) =====================
BASE_DIR = os.path.dirname(os.path.abspath(sys.argv[0]))
BIN_DIRS = [
    os.path.join(BASE_DIR, "qpdf", "bin"),
    os.path.join(BASE_DIR, "ghostscript", "bin"),
    os.path.join(BASE_DIR, "poppler", "bin"),
    os.path.join(BASE_DIR, "tesseract", "bin"),
]
os.environ["PATH"] = os.pathsep.join([*BIN_DIRS, os.environ.get("PATH","")])
os.environ.setdefault("POPPLER_PATH", os.path.join(BASE_DIR, "poppler", "bin"))
tess_root = os.path.join(BASE_DIR, "tesseract")
if os.path.isdir(os.path.join(tess_root, "tessdata")):
    os.environ.setdefault("TESSDATA_PREFIX", tess_root)

def have_exe(name: str) -> bool:
    for p in os.environ["PATH"].split(os.pathsep):
        cand = os.path.join(p, name)
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return True
    return False

HAVE_QPDF = have_exe("qpdf.exe") or have_exe("qpdf")
HAVE_GS   = any(have_exe(x) for x in ("gswin64c.exe","gswin32c.exe","gswin64c","gs"))
HAVE_TESS = have_exe("tesseract.exe") or have_exe("tesseract")

try:
    import ocrmypdf  # noqa
    HAVE_OCR = True
except Exception:
    HAVE_OCR = False

try:
    import pikepdf  # noqa
    HAVE_PIKEPDF = True
except Exception:
    HAVE_PIKEPDF = False

# ===================== Utilidades =====================
def human_size(n: int) -> str:
    try: n = float(n)
    except: return "?"
    for u in ['B','KB','MB','GB']:
        if n < 1024 or u == 'GB':
            return f"{n:.1f}{u}"
        n /= 1024
    return f"{n:.1f}GB"

def file_size(p: str) -> int:
    try: return os.path.getsize(p)
    except: return -1

def verifica_pdf(path: str) -> bool:
    try:
        PdfReader(path, strict=False)
        return True
    except Exception:
        return False

def is_blank_page(page) -> bool:
    try:
        txt = page.extract_text()
        if txt and txt.strip():
            return False
        res = page.get("/Resources", {})
        if "/XObject" in res:
            return False
    except Exception:
        pass
    return True

def unir_pdfs(arquivos: List[str], saida: str, remove_blank=True) -> Tuple[int,int,str]:
    from PyPDF2 import PdfMerger
    merger = PdfMerger()
    total=0; removidas=0; temps=[]
    try:
        for pdf in arquivos:
            r = PdfReader(pdf, strict=False)
            w = PdfWriter()
            for p in r.pages:
                total += 1
                if remove_blank and is_blank_page(p):
                    removidas += 1
                else:
                    w.add_page(p)
            tmp = pdf + ".tmp_no_blank.pdf"
            with open(tmp,"wb") as f: w.write(f)
            temps.append(tmp)
            merger.append(tmp)
        merger.write(saida)
        merger.close()
        for t in temps:
            try: os.remove(t)
            except: pass
        return total, removidas, None
    except Exception as e:
        for t in temps:
            try:
                if os.path.exists(t): os.remove(t)
            except: pass
        return total, removidas, str(e)

def run_ocr(src: str, dst: str, output_type: str, optimize_level: str):
    if not HAVE_OCR:
        return False,"OCRmyPDF ausente"
    cmd = [
        "ocrmypdf",
        "--deskew",
        "--rotate-pages",
        "--rotate-pages-threshold","1",
        "--optimize", optimize_level,
        "--output-type", output_type,
        src, dst
    ]
    try:
        subprocess.check_call(cmd)
        return True,""
    except subprocess.CalledProcessError as e:
        return False,f"OCR retorno {e.returncode}"
    except Exception as e:
        return False,str(e)

def optimize_gs(src: str, dst: str, quality: str):
    if not HAVE_GS:
        return False,"Ghostscript ausente"
    qm = {"screen":"/screen","ebook":"/ebook","printer":"/printer","prepress":"/prepress","default":"/default"}
    pdfset = qm.get(quality,"/ebook")
    exe = "gswin64c" if have_exe("gswin64c.exe") else ("gswin32c" if have_exe("gswin32c.exe") else "gs")
    cmd = [
        exe,"-sDEVICE=pdfwrite",f"-dPDFSETTINGS={pdfset}",
        "-dNOPAUSE","-dQUIET","-dBATCH","-dCompatibilityLevel=1.4",
        "-dDetectDuplicateImages=true","-dCompressFonts=true","-dSubsetFonts=true",
        "-dAutoRotatePages=/None", f"-sOutputFile={dst}", src
    ]
    try:
        subprocess.check_call(cmd)
        if verifica_pdf(dst): return True,""
        if os.path.exists(dst): os.remove(dst)
        return False,"PDF inválido"
    except Exception as e:
        if os.path.exists(dst):
            try: os.remove(dst)
            except: pass
        return False,str(e)

def qpdf_linearize_inplace(path: str):
    if not HAVE_QPDF:
        return False,"qpdf ausente"
    temp = path + ".qtmp.pdf"
    try:
        subprocess.check_call(["qpdf","--linearize",path,temp],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if verifica_pdf(temp):
            os.replace(temp,path)
            return True,""
        if os.path.exists(temp): os.remove(temp)
        return False,"qpdf gerou inválido"
    except Exception as e:
        if os.path.exists(temp):
            try: os.remove(temp)
            except: pass
        return False,str(e)

def shrink_pipeline(path: str, remove_metadata=True, report=False):
    original = file_size(path)
    if report: print(f"[SHRINK] Inicial: {human_size(original)}")
    best_path = path
    best_size = original

    if HAVE_QPDF:
        cand = path + ".shq.pdf"
        try:
            subprocess.check_call([
                "qpdf","--linearize","--object-streams=generate",
                "--compress-streams=y","--recompress-flate",
                best_path,cand
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if verifica_pdf(cand):
                sz = file_size(cand)
                if report: print(f"[SHRINK] qpdf: {human_size(sz)} (Δ {sz-best_size:+})")
                if 0 < sz < best_size:
                    best_path, best_size = cand, sz
                else:
                    os.remove(cand)
        except Exception:
            if os.path.exists(cand):
                try: os.remove(cand)
                except: pass

    if HAVE_PIKEPDF:
        import pikepdf
        cand = path + ".shp.pdf"
        try:
            with pikepdf.Pdf.open(best_path) as pdf:
                pdf.remove_unreferenced_resources()
                if remove_metadata:
                    pdf.docinfo.clear()
                    if '/Metadata' in pdf.root:
                        try: del pdf.root['/Metadata']
                        except: pass
                pdf.save(
                    cand,
                    linearize=True,
                    object_stream_mode=pikepdf.ObjectStreamMode.generate,
                    compress_streams=True
                )
            if verifica_pdf(cand):
                sz = file_size(cand)
                if report: print(f"[SHRINK] pikepdf: {human_size(sz)} (Δ {sz-best_size:+})")
                if 0 < sz < best_size:
                    best_path, best_size = cand, sz
                else:
                    os.remove(cand)
        except Exception:
            if os.path.exists(cand):
                try: os.remove(cand)
                except: pass

    if best_path != path:
        os.replace(best_path, path)
        if report: print(f"[SHRINK] Final: {human_size(best_size)} (redução {original-best_size} bytes)")
    else:
        if report: print("[SHRINK] Nenhuma redução.")
    for ext in [".shq.pdf",".shp.pdf"]:
        tmp = path + ext
        if os.path.exists(tmp):
            try: os.remove(tmp)
            except: pass

# ===================== CLI =====================
import argparse
def build_parser():
    p = argparse.ArgumentParser(description="PDF Merge Tool (Windows) - Merge + OCR opcional + Shrink")
    p.add_argument("files", nargs="+", help="Arquivos PDF")
    p.add_argument("--no-blank-removal", action="store_true")
    p.add_argument("--no-ocr", action="store_true")
    p.add_argument("--ocr-output-type", choices=["pdf","pdfa"], default="pdfa")
    p.add_argument("--ocr-optimize-level", choices=["0","1","2","3"], default="3")
    p.add_argument("--apply-gs", action="store_true", help="Ghostscript após OCR (se disponível)")
    p.add_argument("--gs-quality", choices=["screen","ebook","printer","prepress","default"], default="ebook")
    p.add_argument("--qpdf-optimize", action="store_true", help="qpdf linearize antes do shrink")
    p.add_argument("--final-shrink", action="store_true", help="Shrink pós-processamento (qpdf+pikepdf)")
    p.add_argument("--shrink-report", action="store_true")
    p.add_argument("--no-shrink-metadata", action="store_true")
    p.add_argument("--output", help="Nome final (inclui .pdf)")
    p.add_argument("--auto-name", action="store_true")
    p.add_argument("--out-dir", help="Diretório destino")
    p.add_argument("--version", action="store_true", help="Mostrar versão embutida.")
    return p

VERSION = os.environ.get("PMT_BUILD_VERSION", "dev")

def compute_output_name(args, first_dir):
    if args.output:
        return args.output
    non_interactive = not sys.stdin.isatty()
    if args.auto_name or non_interactive:
        stamp = time.strftime("%Y%m%d_%H%M%S")
        out_dir = args.out_dir if args.out_dir else first_dir
        return os.path.join(out_dir, f"merge_{stamp}.pdf")
    suggested = os.path.join(first_dir, "unidos.pdf")
    try:
        name = input(f"Nome final (ENTER={suggested}): ").strip()
    except EOFError:
        name = suggested
    if not name: name = suggested
    if not name.lower().endswith(".pdf"):
        name += ".pdf"
    return name

def main():
    if len(sys.argv) == 1:
        print("Uso: pdf_merge_tool_win.exe file1.pdf file2.pdf ... [opções]")
        return
    parser = build_parser()
    args = parser.parse_args()
    if args.version:
        print(VERSION); return

    if len(args.files) < 2:
        print("Forneça ao menos 2 PDFs.")
        return

    print(f"[INFO] qpdf={HAVE_QPDF} ghostscript={HAVE_GS} ocrmypdf={HAVE_OCR} pikepdf={HAVE_PIKEPDF} tesseract={HAVE_TESS}")
    first_dir = os.path.dirname(os.path.abspath(args.files[0]))
    out_path = compute_output_name(args, first_dir)
    print("Saída:", out_path)

    temp_merge = out_path + ".merge.tmp.pdf"
    total, removed, err = unir_pdfs(args.files, temp_merge, remove_blank=not args.no_blank_removal)
    if err:
        print("Erro merge:", err); return
    print(f"[MERGE] Páginas={total} | Removidas={removed}")

    working = temp_merge

    if not args.no_ocr and HAVE_OCR and HAVE_TESS:
        temp_ocr = out_path + ".ocr.tmp.pdf"
        print("[OCR] Executando...")
        ok, msg = run_ocr(working, temp_ocr, args.ocr_output_type, args.ocr_optimize_level)
        if ok and verifica_pdf(temp_ocr):
            working = temp_ocr
            print("[OCR] OK")
        else:
            print("[OCR] Falhou:", msg)
            if os.path.exists(temp_ocr):
                try: os.remove(temp_ocr)
                except: pass
    else:
        print("[OCR] Pulado (flag ou dependências ausentes)")

    if args.apply_gs and HAVE_GS:
        temp_gs = out_path + ".gs.tmp.pdf"
        print(f"[GS] quality={args.gs_quality} ...")
        ok,msg = optimize_gs(working, temp_gs, args.gs_quality)
        if ok and verifica_pdf(temp_gs):
            working = temp_gs
            print("[GS] OK")
        else:
            print("[GS] Falhou:", msg)
            if os.path.exists(temp_gs):
                try: os.remove(temp_gs)
                except: pass
    else:
        print("[GS] Pulado")

    if args.qpdf_optimize:
        print("[QPDF] Linearizando (pré-shrink)...")
        ok,msg = qpdf_linearize_inplace(working)
        print("[QPDF] OK" if ok else f"[QPDF] Falhou: {msg}")

    os.replace(working, out_path)
    print(f"[FINAL] {out_path} ({human_size(file_size(out_path))})")

    if args.final_shrink:
        print("[SHRINK] Iniciando shrink final ...")
        shrink_pipeline(out_path,
                        remove_metadata=not args.no_shrink_metadata,
                        report=args.shrink_report)

    for f in glob.glob(out_path + ".*.tmp.pdf"):
        try: os.remove(f)
        except: pass
    print("Concluído.")

if __name__ == "__main__":
    main()
PYEOF



echo "[INFO] Requirements..."
cat > requirements/requirements-lite.txt <<'EOF'
PyPDF2
Pillow
img2pdf
pikepdf
EOF

cat > requirements/requirements-full.txt <<'EOF'
PyPDF2
Pillow
img2pdf
pikepdf
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

echo "[INFO] LICENSE / TERCEIROS / README / .gitignore..."
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2025 SrWiest

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
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
