#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import argparse
import os
import logging
from pathlib import Path
from typing import List, Tuple

# Importação dos módulos do projeto
from src.utils import (
    get_version_info, is_frozen, human_size, file_size, get_executable_path, run_command
)
from recovery import (
    verifica_pdf, exporta_pdf_ghostscript, exporta_pdf_qpdf, exporta_pdf_mutool,
    exporta_pdf_pdftk, exporta_pdf_como_imagem, exporta_pdf_libreoffice, preparar_pdfs_resiliente
)

# Configuração do logger
log = logging.getLogger(__name__)

def setup_logging():
    log.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(logging.Formatter('%(message)s'))
    log.addHandler(console_handler)
    # File handler
    log_dir = Path(sys.executable).parent if is_frozen() else Path.cwd()
    file_handler = logging.FileHandler(log_dir / "pdf_merge_tool.log", mode='w', encoding='utf-8')
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    log.addHandler(file_handler)

ocrmypdf = None

def import_version_specific_modules():
    global ocrmypdf
    version = get_version_info()
    log.info(f"Versão detectada: {version.upper()}")
    if version in ['medium', 'full', 'development']:
        try:
            import ocrmypdf as _ocrmypdf
            ocrmypdf = _ocrmypdf
            log.debug("Módulo OCRmyPDF carregado.")
        except ImportError as e:
            log.warning(f"Módulo opcional (ocrmypdf) não disponível: {e}")

def should_use_libreoffice() -> bool:
    return get_version_info() == 'full'

def is_blank_page(page) -> bool:
    try:
        text = page.extract_text()
        if text and text.strip():
            return False
        if "/XObject" in page.get("/Resources", {}):
            return False
    except Exception:
        pass
    return True

def unir_pdfs(arquivos: List[Path], saida: Path, no_blank_removal: bool) -> Tuple[int, int, str]:
    from PyPDF2 import PdfWriter, PdfReader
    writer = PdfWriter()
    total_paginas, removidas = 0, 0
    try:
        for pdf_path in arquivos:
            reader = PdfReader(str(pdf_path), strict=False)
            for page in reader.pages:
                total_paginas += 1
                if no_blank_removal or not is_blank_page(page):
                    writer.add_page(page)
                else:
                    removidas += 1
        with open(saida, "wb") as f:
            writer.write(f)
        return total_paginas, removidas, None
    except Exception as e:
        log.error(f"Erro ao unir PDFs: {e}", exc_info=True)
        return total_paginas, removidas, str(e)

def run_ocr_api(src: Path, dst: Path, args) -> Tuple[bool, str]:
    if not ocrmypdf:
        return False, "OCRmyPDF não está disponível nesta versão."
    original_path = os.environ.get('PATH', '')
    try:
        gs_exe_path = get_executable_path("gs")
        tesseract_exe_path = get_executable_path("tesseract")
        os.environ['OCRMYPDF_GHOSTSCRIPT'] = gs_exe_path
        os.environ['OCRMYPDF_TESSERACT'] = tesseract_exe_path
        os.environ['PATH'] = f"{Path(gs_exe_path).parent};{Path(tesseract_exe_path).parent};{original_path}"
        log.info("Iniciando OCR...")
        ocrmypdf.ocr(
            input_file=src,
            output_file=dst,
            deskew=True,
            rotate_pages=True,
            optimize=args.ocr_optimize_level,
            output_type=args.ocr_output_type,
            force_ocr=args.force_ocr
        )
        return True, ""
    except Exception as e:
        log.error(f"API do OCRmyPDF falhou: {e}", exc_info=True)
        return False, str(e)
    finally:
        os.environ['PATH'] = original_path
        os.environ.pop('OCRMYPDF_GHOSTSCRIPT', None)
        os.environ.pop('OCRMYPDF_TESSERACT', None)

def preparar_pdfs_for_processing(file_paths: List[str], prefer_libreoffice: bool) -> Tuple[List[Path], List[Path]]:
    paths = [Path(p) for p in file_paths]
    return preparar_pdfs_resiliente(paths, prefer_libreoffice)

def build_parser():
    parser = argparse.ArgumentParser(description="Ferramenta para unir e processar arquivos PDF.")
    parser.add_argument("files", nargs="*", help="Arquivos PDF de entrada.")
    parser.add_argument("--output", "-o", help="Nome do arquivo de saída.", default=None)
    parser.add_argument("--no-blank-removal", action="store_true", help="Desativa a remoção de páginas em branco.")
    parser.add_argument("--no-ocr", action="store_true", help="Desativa a aplicação de OCR.")
    parser.add_argument("--force-ocr", action="store_true", help="Força OCR mesmo que o PDF já tenha texto.")
    parser.add_argument("--ocr-output-type", choices=["pdf", "pdfa"], default="pdf", help="Tipo de saída do OCR.")
    parser.add_argument("--ocr-optimize-level", type=int, choices=[0, 1, 2, 3], default=1, help="Nível de otimização do OCR.")
    parser.add_argument("--prefer-libreoffice", action="store_true", help="Tenta LibreOffice primeiro para recuperação.")
    parser.add_argument("--version", "-v", action="version", version=f"PDF Merge Tool {get_version_info().upper()}")
    return parser

def main_logic(args):
    if not args.files:
        log.error("É necessário informar pelo menos um arquivo PDF.")
        return 1

    log.info(f"Recebidos {len(args.files)} arquivo(s) para processar.")
    ok_files, ignored_files = preparar_pdfs_for_processing(args.files, args.prefer_libreoffice)
    if not ok_files:
        log.error("Nenhum arquivo válido para processar. Saindo.")
        return 1

    final_name = Path(args.output) if args.output else ok_files[0].with_name(f"{ok_files[0].stem}_unido.pdf")
    log.info(f"\nArquivo de saída será: {final_name}")

    temp_merge = final_name.with_name(f"{final_name.stem}_temp_merge.pdf")

    log.info(f"Unindo {len(ok_files)} arquivo(s)...")
    total_pg, removed_pg, err = unir_pdfs(ok_files, temp_merge, args.no_blank_removal)
    if err:
        log.error(f"Erro fatal ao unir PDFs: {err}")
        return 1

    log.info(f" ✔️ União concluída. Total de páginas: {total_pg}. Páginas em branco removidas: {removed_pg}")

    working_file = temp_merge
    temp_ocr = None

    if not args.no_ocr:
        temp_ocr = final_name.with_name(f"{final_name.stem}_temp_ocr.pdf")
        ok_ocr, msg = run_ocr_api(working_file, temp_ocr, args)
        if ok_ocr and verifica_pdf(temp_ocr):
            log.info(" ✔️ OCR aplicado com sucesso.")
            try:
                working_file.unlink()
            except Exception:
                pass
            working_file = temp_ocr
        else:
            log.warning(f" ⚠️ Falha no OCR: {msg}. Continuando sem OCR.")
            if temp_ocr.exists():
                try:
                    temp_ocr.unlink()
                except Exception:
                    pass

    try:
        working_file.rename(final_name)
    except Exception as e:
        log.error(f"Erro ao salvar arquivo final: {e}")
        return 1

    # Limpeza
    files_to_clean = [temp_merge] + ok_files
    if temp_ocr and temp_ocr.exists():
        files_to_clean.append(temp_ocr)

    for f in files_to_clean:
        try:
            if f.exists() and any(s in f.name for s in [".gs.pdf", ".qpdf.pdf", ".mutool.pdf", ".pdftk.pdf", ".imagem.pdf", ".libreoffice.pdf", "_temp_"]):
                f.unlink()
        except OSError as e:
            log.warning(f"Não foi possível limpar o arquivo temporário {f.name}: {e}")

    log.info(f"\n✨ Processo concluído! Arquivo final: {final_name} ({human_size(file_size(final_name))})")

    return 0

def main():
    setup_logging()
    import_version_specific_modules()

    parser = build_parser()
    args = parser.parse_args()

    if not sys.argv[1:]:
        parser.print_help()
        if is_frozen():
            input("\nNenhum argumento fornecido. Pressione Enter para sair...")
        sys.exit(1)

    try:
        sys.exit(main_logic(args))
    except Exception as e:
        log.critical("-- ERRO INESPERADO E FATAL --", exc_info=True)
        if is_frozen():
            input("\nO PROGRAMA FALHOU. Pressione Enter para fechar...")
        sys.exit(1)

if __name__ == "__main__":
    if is_frozen():
        tessdata_dir = Path(sys._MEIPASS) / "third_party_full" / "tesseract" / "tessdata"
        if tessdata_dir.exists():
            os.environ['TESSDATA_PREFIX'] = str(tessdata_dir)
    main()