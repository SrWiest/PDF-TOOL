
# -*- coding: utf-8 -*-
# PDF Merge Tool - Copyright (c) 2025 SrWiest
# Licença: Consulte LICENSE e THIRD_PARTY_LICENSES.txt
import shutil
import subprocess
import os
import json

def _which_any(*names):
    for n in names:
        p = shutil.which(n)
        if p:
            return n, p
    return None, None

def tool_status():
    status = {}

    def has(name):
        return shutil.which(name) is not None

    # Executáveis principais
    status["qpdf_exe"] = has("qpdf")
    gs_name, gs_path = _which_any("gswin64c", "gswin64", "gs")
    status["ghostscript_exe"] = bool(gs_name)
    status["ghostscript_cmd"] = gs_name or ""

    status["tesseract_exe"] = has("tesseract")
    status["TESSDATA_PREFIX"] = os.environ.get("TESSDATA_PREFIX", "")

    # Bibliotecas Python
    def _importable(mod):
        try:
            __import__(mod)
            return True
        except Exception:
            return False

    status["pikepdf"] = _importable("pikepdf")
    status["pytesseract"] = _importable("pytesseract")
    status["ocrmypdf"] = _importable("ocrmypdf")

    # Versões (best effort)
    def safe_run(cmd):
        try:
            p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, timeout=6)
            return p.returncode == 0, (p.stdout.splitlines()[:2])
        except Exception as e:
            return False, [str(e)]

    if status["qpdf_exe"]:
        ok, out = safe_run(["qpdf", "--version"])
        status["qpdf_version_ok"] = ok
        status["qpdf_version_head"] = out
    if status["ghostscript_exe"] and gs_name:
        ok, out = safe_run([gs_name, "-h"])
        status["ghostscript_version_ok"] = ok
        status["ghostscript_version_head"] = out
    if status["tesseract_exe"]:
        ok, out = safe_run(["tesseract", "--version"])
        status["tesseract_version_ok"] = ok
        status["tesseract_version_head"] = out

    return status

def print_status_as_table():
    st = tool_status()
    # Formato simples chave=valor
    for k in sorted(st.keys()):
        v = st[k]
        if isinstance(v, list):
            v = " | ".join(v)
        print(f"{k}={v}")

def print_status_json():
    print(json.dumps(tool_status(), indent=2, ensure_ascii=False))
