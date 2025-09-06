#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Funções de recuperação de PDF para o PDF Merge Tool

import logging
import os
import subprocess
import tempfile
import glob
from pathlib import Path

from PyPDF2 import PdfReader

# Módulos que podem não estar presentes em todas as versões
try:
    import img2pdf
    import psutil
    from pdf2image import convert_from_path as pdf2image_convert
except ImportError:
    img2pdf = None
    psutil = None
    pdf2image_convert = None

from src.utils import get_executable_path, run_command

log = logging.getLogger(__name__)

def verifica_pdf(path: Path) -> bool:
    """Verifica rapidamente se um arquivo é um PDF válido e tem páginas."""
    try:
        reader = PdfReader(str(path), strict=False)
        return len(reader.pages) > 0
    except Exception as e:
        log.debug(f"Falha na verificação de PDF para {path.name}: {e}")
        return False

# --- Funções de Recuperação ---

def exporta_pdf_ghostscript(src: Path, dst: Path) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com Ghostscript...")
    try:
        gs_exe = get_executable_path("gswin64c")
        cmd = [gs_exe, "-sDEVICE=pdfwrite", "-dPDFSETTINGS=/prepress", "-dNOPAUSE", "-dQUIET", "-dBATCH", f"-sOutputFile={dst}", str(src.absolute())]
        result = run_command(cmd, timeout=60)
        if result.returncode == 0 and verifica_pdf(dst):
            return True
        log.debug(f"Ghostscript falhou. Stderr: {result.stderr.strip()}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False
    except (FileNotFoundError, Exception) as e:
        log.warning(f"Recuperação com Ghostscript falhou: {e}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False

def exporta_pdf_qpdf(src: Path, dst: Path) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com qpdf...")
    try:
        qpdf_exe = get_executable_path("qpdf")
        cmd = [qpdf_exe, "--linearize", str(src.absolute()), str(dst)]
        result = run_command(cmd, timeout=60)
        if result.returncode == 0 and verifica_pdf(dst):
            return True
        log.debug(f"qpdf falhou. Stderr: {result.stderr.strip()}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False
    except (FileNotFoundError, Exception) as e:
        log.warning(f"Recuperação com qpdf falhou: {e}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False

def exporta_pdf_mutool(src: Path, dst: Path) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com mutool...")
    try:
        mutool_exe = get_executable_path("mutool")
        cmd = [mutool_exe, "clean", str(src.absolute()), str(dst)]
        result = run_command(cmd, timeout=60)
        if result.returncode == 0 and verifica_pdf(dst):
            return True
        log.debug(f"mutool falhou. Stderr: {result.stderr.strip()}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False
    except (FileNotFoundError, Exception) as e:
        log.warning(f"Recuperação com mutool falhou: {e}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False

def exporta_pdf_pdftk(src: Path, dst: Path) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com pdftk...")
    try:
        pdftk_exe = get_executable_path("pdftk")
        cmd = [pdftk_exe, str(src.absolute()), "output", str(dst), "repair"]
        result = run_command(cmd, timeout=60)
        if result.returncode == 0 and verifica_pdf(dst):
            return True
        log.debug(f"pdftk falhou. Stderr: {result.stderr.strip()}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False
    except (FileNotFoundError, Exception) as e:
        log.warning(f"Recuperação com pdftk falhou: {e}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False

def exporta_pdf_como_imagem(src: Path, dst: Path, dpi: int = 250) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com pdftoppm+img2pdf...")
    if not img2pdf:
        log.warning("Recuperação com imagem pulada: img2pdf não está instalado.")
        return False
    
    try:
        pdftoppm_exe = get_executable_path("pdftoppm")
    except FileNotFoundError:
        log.warning("Recuperação com imagem pulada: pdftoppm não encontrado.")
        return False

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        page_pattern = temp_path / f"{src.stem}_page"
        
        cmd = [pdftoppm_exe, "-png", "-r", str(dpi), str(src.absolute()), str(page_pattern.absolute())]
        result = run_command(cmd, timeout=120)

        if result.returncode != 0:
            log.debug(f"pdftoppm falhou. Stderr: {result.stderr.strip()}")
            return False

        png_files = sorted(glob.glob(f"{page_pattern}*.png"))
        if not png_files:
            log.debug("Nenhuma imagem PNG foi gerada pelo pdftoppm.")
            return False

        try:
            with open(dst, "wb") as f:
                f.write(img2pdf.convert(png_files))
            return dst.exists() and verifica_pdf(dst)
        except Exception as e:
            log.error(f"Falha ao converter imagens para PDF com img2pdf: {e}")
            return False

def _find_soffice_executable() -> str:
    """Encontra o executável do LibreOffice, embutido ou no sistema."""
    # 1. Tentar usar LibreOffice embutido
    try:
        return get_executable_path("soffice")
    except FileNotFoundError:
        log.debug("LibreOffice embutido não encontrado, procurando no sistema.")

    # 2. Procurar em locais comuns no Windows
    possible_paths = [
        "C:\\Program Files\\LibreOffice\\program\\soffice.exe",
        "C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe",
    ]
    for path in possible_paths:
        if os.path.exists(path):
            log.debug(f"Encontrado LibreOffice do sistema em: {path}")
            return path

    # 3. Tentar encontrar via `where`
    try:
        result = run_command(["where", "soffice"], timeout=5)
        if result.returncode == 0 and result.stdout.strip():
            found_path = result.stdout.strip().splitlines()[0]
            log.debug(f"Encontrado LibreOffice via PATH: {found_path}")
            return found_path
    except Exception:
        pass

    raise FileNotFoundError("Executável do LibreOffice não encontrado.")

def _kill_hanging_soffice_processes():
    """Encerra processos do LibreOffice que possam ter travado."""
    if not psutil:
        log.warning("psutil não instalado, não é possível verificar processos travados.")
        return

    killed = 0
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            proc_name = proc.info.get('name', '')
            if 'soffice' in proc_name.lower():
                cmdline = proc.info.get('cmdline', [])
                if cmdline and any('--headless' in str(arg) for arg in cmdline):
                    proc.kill()
                    killed += 1
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    if killed > 0:
        log.info(f"{killed} processo(s) travado(s) do LibreOffice foram encerrados.")

def exporta_pdf_libreoffice(src: Path, dst: Path) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com LibreOffice...")
    try:
        soffice_exe = _find_soffice_executable()
    except FileNotFoundError as e:
        log.warning(f"Recuperação com LibreOffice pulada: {e}")
        return False

    with tempfile.TemporaryDirectory() as temp_dir_str:
        temp_dir = Path(temp_dir_str)
        cmd = [soffice_exe, "--headless", "--invisible", "--nologo", "--norestore",
               "--convert-to", "pdf", "--outdir", str(temp_dir.resolve()), str(src.resolve())]
        
        try:
            result = run_command(cmd, timeout=90)
            expected_output = temp_dir / f"{src.stem}.pdf"

            if result.returncode == 0 and expected_output.exists():
                expected_output.rename(dst)
                if verifica_pdf(dst):
                    log.debug("Conversão com LibreOffice bem-sucedida.")
                    return True
            
            log.debug(f"LibreOffice falhou. Stderr: {result.stderr.strip()}")
            return False

        except subprocess.TimeoutExpired:
            log.warning("Timeout na conversão com LibreOffice. O PDF pode ser muito complexo.")
            _kill_hanging_soffice_processes()
            return False
        except Exception as e:
            log.error(f"Erro inesperado na conversão com LibreOffice: {e}")
            return False