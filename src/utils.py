#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Funções utilitárias para o PDF Merge Tool

import sys
import os
import subprocess
import logging
from pathlib import Path
from typing import List

log = logging.getLogger(__name__)

def is_frozen() -> bool:
    """Verifica se o script está rodando como um executável PyInstaller."""
    return getattr(sys, 'frozen', False)

def get_version_info() -> str:
    """Detecta a versão (lite, medium, full) baseada no nome do executável."""
    if is_frozen():
        exe_name = Path(sys.executable).name.lower()
        if 'lite' in exe_name: return 'lite'
        if 'medium' in exe_name: return 'medium'
        if 'full' in exe_name: return 'full'
    return 'development'

def get_executable_path(name: str) -> str:
    """Encontra o caminho para um executável embutido na pasta third_party_full."""
    name_exe = name if name.endswith('.exe') else f"{name}.exe"
    if not is_frozen():
        # Em modo de desenvolvimento, assume que está no PATH
        return name

    # No modo frozen, os executáveis estão embutidos
    base_path = Path(sys._MEIPASS)
    search_dir = base_path / 'third_party_full'
    
    for exe_path in search_dir.rglob(name_exe):
        if exe_path.is_file():
            log.debug(f"Encontrado executável embutido: {exe_path}")
            return str(exe_path)
            
    raise FileNotFoundError(f"Executável '{name_exe}' não foi encontrado em '{search_dir}'")

def human_size(n: int) -> str:
    """Converte bytes para um formato legível (KB, MB, GB)."""
    try:
        n = float(n)
    except (ValueError, TypeError):
        return "?"
    for u in ['B', 'KB', 'MB', 'GB']:
        if n < 1024 or u == 'GB':
            return f"{n:.1f}{u}"
        n /= 1024
    return f"{n:.1f}GB"

def file_size(path: Path) -> int:
    """Retorna o tamanho de um arquivo em bytes."""
    try:
        return path.stat().st_size
    except OSError:
        return -1

def run_command(cmd_list: List[str], custom_env=None, timeout=None):
    """Executa um comando externo de forma segura e captura a saída."""
    env = os.environ.copy()
    if custom_env:
        env.update(custom_env)

    startupinfo = None
    if sys.platform == "win32":
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

    return subprocess.run(
        cmd_list, capture_output=True, text=True, startupinfo=startupinfo,
        encoding='utf-8', errors='ignore', env=env, timeout=timeout
    )
