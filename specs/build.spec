# -*- mode: python ; coding: utf-8 -*- # type: ignore
# Spec unificado para PyInstaller - PDF Merge Tool
# Lê a variável de ambiente PDF_TOOL_VERSION para configurar o build.

import os
import pathlib
import sys

def _get_base_dir():
    """Determina o diretório base do projeto de forma robusta."""
    if getattr(sys, 'frozen', False):
        # Estamos rodando no bundle do PyInstaller
        return pathlib.Path(sys.executable).parent.parent
    # Durante o build com PyInstaller, __file__ não é definido.
    # Usar sys.argv[0] é a alternativa mais fiável para obter o caminho do spec.
    return pathlib.Path(sys.argv[0]).resolve().parent.parent

BASE_DIR = _get_base_dir()

# --- Configuração da Versão ---
VERSION = os.environ.get('PDF_TOOL_VERSION', 'medium').lower()
VALID_VERSIONS = ['lite', 'medium', 'full']
if VERSION not in VALID_VERSIONS:
    sys.exit(f"ERRO: Versão inválida '{VERSION}'. Válidas são: {VALID_VERSIONS}")

print(f"[BUILD.SPEC] Construindo versão: {VERSION.upper()}")
print(f"[BUILD.SPEC] Diretório Base: {BASE_DIR}")

# --- Configuração Dinâmica baseada na Versão ---
SCRIPT_PATH = BASE_DIR / 'src' / 'pdf_merge_tool_win.py'
EXE_NAME = f'pdf_merge_tool_win_{VERSION}'
datas = []
hiddenimports = []

# Adicionar licenças
datas.append((str(BASE_DIR / 'LICENSE'), '.'))
datas.append((str(BASE_DIR / 'licenses' / 'THIRD_PARTY_LICENSES.txt'), 'licenses'))

if VERSION in ['medium', 'full']:
    hiddenimports.extend([
        'ocrmypdf', 'ocrmypdf._graft', 'ocrmypdf.api',
        'ocrmypdf.pdfinfo', 'ocrmypdf.data', 'ocrmypdf.builtin_plugins',
        'pikepdf', 'PIL', 'reportlab', 'pytesseract', 'pdf2image'
    ])
    
    third_party_dir = BASE_DIR / 'third_party_full'
    if third_party_dir.is_dir():
        for item in third_party_dir.iterdir():
            if item.is_dir():
                if VERSION == 'medium' and item.name == 'libreoffice':
                    continue
                datas.append((str(item), f'third_party_full/{item.name}'))

# --- Configuração do PyInstaller ---

block_cipher = None

a = Analysis(
    [str(SCRIPT_PATH)],
    pathex=[str(BASE_DIR)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[str(BASE_DIR / 'hooks')],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter', 'setuptools', 'numpy', 'pandas', 'matplotlib', 'scipy',
        'PyQt5', 'PySide2', 'wx'
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name=EXE_NAME,
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name=EXE_NAME,
)
