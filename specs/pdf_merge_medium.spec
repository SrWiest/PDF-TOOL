# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec file for PDF Merge Tool - Medium Version

import os
import sys
from pathlib import Path

# Get the base directory
if '__file__' in globals():
    BASE_DIR = Path(__file__).resolve().parent.parent
else:
    # Fallback for when __file__ is not available
    BASE_DIR = Path.cwd().parent

# Configuration for Medium version
VERSION = "medium"
SCRIPT_PATH = BASE_DIR / 'src' / 'pdf_merge_tool_win.py'
EXE_NAME = f'pdf_merge_tool_win_{VERSION}'

# Data files to include
datas = [
    (str(BASE_DIR / 'LICENSE'), '.'),
    (str(BASE_DIR / 'licenses' / 'THIRD_PARTY_LICENSES.txt'), 'licenses'),
]

# Add third_party_full for medium version (excluding LibreOffice)
third_party_dir = BASE_DIR / 'third_party_full'
if third_party_dir.is_dir():
    for item in third_party_dir.iterdir():
        if item.is_dir() and item.name != 'libreoffice':
            datas.append((str(item), f'third_party_full/{item.name}'))

# Hidden imports for medium version
hiddenimports = [
    'ocrmypdf', 'ocrmypdf._graft', 'ocrmypdf.api',
    'ocrmypdf.pdfinfo', 'ocrmypdf.data', 'ocrmypdf.builtin_plugins',
    'pikepdf', 'PIL', 'reportlab', 'pytesseract', 'pdf2image'
]

# PyInstaller configuration
block_cipher = None

a = Analysis(
    [str(SCRIPT_PATH)],
    pathex=[str(BASE_DIR)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[str(BASE_DIR / 'specs' / 'runtime_hooks' / 'add_third_party_path.py')],
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
