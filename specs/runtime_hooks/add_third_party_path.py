import os, sys, pathlib, shutil, subprocess

def _log(msg):
    # Silencioso em produção? Se quiser menos ruído, comente o print.
    print(f"[EMBED-HOOK] {msg}")

def _inject():
    base = pathlib.Path(getattr(sys, "_MEIPASS", pathlib.Path(__file__).resolve().parent))
    tp_root = base / "third_party_full"
    if not tp_root.is_dir():
        _log("third_party_full não encontrado; nada a injetar.")
        return

    candidate_dirs = []
    # Primeiro nível + subníveis moderados
    for p in tp_root.rglob('*'):
        if p.is_dir():
            try:
                if any(child.suffix.lower() in ('.exe', '.dll') for child in p.iterdir()):
                    candidate_dirs.append(p)
            except Exception:
                pass

    # Força inclusão das pastas principais se existirem
    for forced in ("qpdf", "tesseract", "ghostscript/bin", "poppler/bin", "poppler"):
        fpath = tp_root / forced
        if fpath.is_dir():
            candidate_dirs.append(fpath)

    # Remover duplicados (como strings) preservando a ordem
    uniq_paths_str = list(dict.fromkeys(str(p.resolve()) for p in candidate_dirs))

    if uniq_paths_str:
        current = os.environ.get("PATH", "")
        # Prepend para ter precedência
        new_path = os.pathsep.join(uniq_paths_str) + os.pathsep + current
        os.environ["PATH"] = new_path
        _log("PATH atualizado com third_party_full ({} dirs).".format(len(uniq_paths_str)))
    else:
        _log("Nenhum diretório com executáveis encontrado em third_party_full.")

    # Tesseract tessdata
    tessdata_dir = tp_root / "tesseract" / "tessdata"
    if tessdata_dir.is_dir():
        os.environ.setdefault("TESSDATA_PREFIX", str(tessdata_dir))
        _log(f"TESSDATA_PREFIX={os.environ['TESSDATA_PREFIX']}")

    # Ghostscript: alguns códigos procuram gswin64c ou gs
    # Nada extra aqui, só diagnóstico opcional:
    for exe in ("tesseract", "qpdf", "gswin64c", "gswin64", "gs"):
        exe_path = shutil.which(exe)
        if exe_path:
            _log(f"Detectado no PATH: {exe} -> {exe_path}")

_inject()
