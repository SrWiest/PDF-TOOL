import logging
import os
import subprocess
import tempfile
import glob
from pathlib import Path
from PyPDF2 import PdfReader

try:
    import img2pdf
    import psutil
    from pdf2image import convert_from_path as pdf2image_convert
except ImportError:
    img2pdf = None
    psutil = None
    pdf2image_convert = None

from utils import get_executable_path, run_command

log = logging.getLogger(__name__)

def verifica_pdf(path: Path) -> bool:
    try:
        reader = PdfReader(str(path), strict=False)
        return len(reader.pages) > 0
    except Exception as e:
        log.debug(f"Falha na verificação de PDF para {path.name}: {e}")
        return False

def exporta_pdf_ghostscript(src: Path, dst: Path) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com Ghostscript...")
    try:
        gs_exe = get_executable_path("gs")
        cmd = [gs_exe, "-sDEVICE=pdfwrite", "-dPDFSETTINGS=/prepress",
               "-dNOPAUSE", "-dQUIET", "-dBATCH", f"-sOutputFile={str(dst)}", str(src.absolute())]
        result = run_command(cmd, timeout=90)
        if result.returncode == 0 and verifica_pdf(dst):
            return True
        log.debug(f"Ghostscript falhou. Stderr: {result.stderr.strip()}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False
    except Exception as e:
        log.warning(f"Recuperação com Ghostscript falhou: {e}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False

def exporta_pdf_qpdf(src: Path, dst: Path) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com qpdf...")
    try:
        qpdf_exe = get_executable_path("qpdf")
        cmd = [qpdf_exe, "--linearize", str(src.absolute()), str(dst)]
        result = run_command(cmd, timeout=90)
        if result.returncode == 0 and verifica_pdf(dst):
            return True
        log.debug(f"qpdf falhou. Stderr: {result.stderr.strip()}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False
    except Exception as e:
        log.warning(f"Recuperação com qpdf falhou: {e}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False

def exporta_pdf_mutool(src: Path, dst: Path) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com mutool...")
    try:
        mutool_exe = get_executable_path("mutool")
        cmd = [mutool_exe, "clean", str(src.absolute()), str(dst)]
        result = run_command(cmd, timeout=90)
        if result.returncode == 0 and verifica_pdf(dst):
            return True
        log.debug(f"mutool falhou. Stderr: {result.stderr.strip()}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False
    except Exception as e:
        log.warning(f"Recuperação com mutool falhou: {e}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False

def exporta_pdf_pdftk(src: Path, dst: Path) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com pdftk...")
    try:
        pdftk_exe = get_executable_path("pdftk")
        cmd = [pdftk_exe, str(src.absolute()), "output", str(dst), "repair"]
        result = run_command(cmd, timeout=90)
        if result.returncode == 0 and verifica_pdf(dst):
            return True
        log.debug(f"pdftk falhou. Stderr: {result.stderr.strip()}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False
    except Exception as e:
        log.warning(f"Recuperação com pdftk falhou: {e}")
        if dst.exists():
            dst.unlink(missing_ok=True)
        return False

def exporta_pdf_como_imagem(src: Path, dst: Path, dpi: int = 250) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com pdftoppm+img2pdf...")
    if not img2pdf or not pdf2image_convert:
        log.warning("Recuperação com imagem pulada: dependências img2pdf/pdf2image ausentes.")
        return False
    try:
        pdftoppm_exe = get_executable_path("pdftoppm")
        with tempfile.TemporaryDirectory() as temp_dir_str:
            temp_dir = Path(temp_dir_str)
            page_pattern = temp_dir / f"{src.stem}_page"
            cmd = [pdftoppm_exe, "-png", "-r", str(dpi), str(src.absolute()), str(page_pattern.absolute())]
            result = run_command(cmd, timeout=120)
            if result.returncode != 0:
                log.debug(f"pdftoppm falhou. Stderr: {result.stderr.strip()}")
                return False
            png_files = sorted(glob.glob(f"{page_pattern}*.png"))
            if not png_files:
                log.debug("Nenhuma imagem PNG foi gerada pelo pdftoppm.")
                return False
            with open(dst, "wb") as f:
                f.write(img2pdf.convert(png_files))
            return dst.exists() and verifica_pdf(dst)
    except Exception as e:
        log.error(f"Falha na recuperação por imagem: {e}")
        return False

def exporta_pdf_libreoffice(src: Path, dst: Path) -> bool:
    log.debug(f"Tentando recuperação de {src.name} com LibreOffice...")
    try:
        soffice_exe = None
        try:
            soffice_exe = get_executable_path("soffice")
        except FileNotFoundError:
            # Caminhos comuns Windows pra tentar localizar o LibreOffice
            possible_paths = [
                "C:\\Program Files\\LibreOffice\\program\\soffice.exe",
                "C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe",
            ]
            for p in possible_paths:
                if Path(p).exists():
                    soffice_exe = p
                    log.debug(f"LibreOffice encontrado em {soffice_exe}")
                    break
            if soffice_exe is None:
                raise FileNotFoundError("Executável do LibreOffice não encontrado.")
        with tempfile.TemporaryDirectory() as temp_dir_str:
            temp_dir = Path(temp_dir_str)
            cmd = [
                soffice_exe, "--headless", "--invisible", "--nologo", "--norestore",
                "--convert-to", "pdf", "--outdir", str(temp_dir.resolve()), str(src.resolve())
            ]
            result = run_command(cmd, timeout=120)
            expected_output = temp_dir / f"{src.stem}.pdf"
            if result.returncode == 0 and expected_output.exists() and verifica_pdf(expected_output):
                expected_output.rename(dst)
                return True
            log.debug(f"LibreOffice falhou. Stderr: {result.stderr.strip()}")
            return False
    except Exception as e:
        log.warning(f"Falha na recuperação com LibreOffice: {e}")
        return False

def preparar_pdfs_resiliente(file_paths: list[Path], prefer_libreoffice: bool = False) -> tuple[list[Path], list[Path]]:
    ok_files, ignored_files = [], []
    for file_path in file_paths:
        log.info(f"Processando arquivo: {file_path.name}")
        if not file_path.exists():
            log.warning(f"Arquivo {file_path.name} não encontrado.")
            ignored_files.append(file_path)
            continue

        if verifica_pdf(file_path):
            log.info(f" ✔️ {file_path.name} é um PDF válido.")
            ok_files.append(file_path)
            continue

        log.warning(f" ⚠️ {file_path.name} não é um PDF válido ou está corrompido. Tentando recuperar...")

        recovery_methods = [
            ("libreoffice", exporta_pdf_libreoffice),
            ("qpdf", exporta_pdf_qpdf),
            ("ghostscript", exporta_pdf_ghostscript),
            ("mutool", exporta_pdf_mutool),
            ("pdftk", exporta_pdf_pdftk),
            ("imagem", exporta_pdf_como_imagem),
        ]
        if not prefer_libreoffice:
            recovery_methods.pop(0)
            recovery_methods.append(("libreoffice", exporta_pdf_libreoffice))

        recovered = False
        for method_name, method_func in recovery_methods:
            recovered_path = file_path.with_suffix(f".{method_name}.pdf")
            if method_func(file_path, recovered_path):
                log.info(f" ✔️ Recuperado com sucesso usando {method_name.upper()}.\n")
                ok_files.append(recovered_path)
                recovered = True
                break
            else:
                log.warning(f" ⚠️ Falha na recuperação com {method_name.upper()}.")
                if recovered_path.exists():
                    try:
                        recovered_path.unlink()
                    except OSError:
                        pass
        
        if not recovered:
            log.error(f" ❌ Não foi possível recuperar {file_path.name}. O arquivo será ignorado.")
            ignored_files.append(file_path)
            
    return ok_files, ignored_files