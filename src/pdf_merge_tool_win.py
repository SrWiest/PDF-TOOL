#!/usr/bin/env python
# -*- coding: utf-8 -*-
# PDF Merge Tool - Copyright (c) 2025 SrWiest
# Licença: Consulte LICENSE e THIRD_PARTY_LICENSES.txt

import sys
import argparse
import os
import logging
from pathlib import Path
from typing import List, Tuple

# --- Módulos do Projeto ---
from src.utils import (
    get_version_info, is_frozen, human_size, file_size, get_executable_path
)
from src.recovery import (
    verifica_pdf, exporta_pdf_ghostscript, exporta_pdf_qpdf, exporta_pdf_mutool,
    exporta_pdf_pdftk, exporta_pdf_como_imagem, exporta_pdf_libreoffice
)

# --- Configuração do Logging ---
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

# --- Importações Condicionais ---
try:
    from PyPDF2 import PdfReader, PdfWriter
except ImportError as e:
    log.critical(f"ERRO DE IMPORTAÇÃO BÁSICA: PyPDF2 não encontrado. {e}")
    sys.exit(1)

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

def should_use_libreoffice():
    return get_version_info() == 'full'

# --- Lógica Principal ---

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

def preparar_pdfs_resiliente(lista_paths: List[Path], prefer_libreoffice: bool = False) -> Tuple[List[Path], List[Path]]:
    ok, ignorados = [], []
    log.info("\nVerificando e recuperando PDFs...")
    
    all_methods = {
        "LibreOffice": exporta_pdf_libreoffice,
        "Ghostscript": exporta_pdf_ghostscript,
        "qpdf": exporta_pdf_qpdf,
        "mutool": exporta_pdf_mutool,
        "pdftk": exporta_pdf_pdftk,
        "imagem": exporta_pdf_como_imagem,
    }

    use_lo = should_use_libreoffice()
    method_order = list(all_methods.keys())

    if prefer_libreoffice and use_lo:
        method_order.insert(0, method_order.pop(method_order.index("LibreOffice")))
    elif not use_lo:
        method_order.remove("LibreOffice")

    for arq_path in lista_paths:
        if verifica_pdf(arq_path):
            log.info(f"  • {arq_path.name} ✔️ OK")
            ok.append(arq_path)
            continue

        log.warning(f"  • {arq_path.name} ⚠️ Corrompido! Tentando recuperar...")
        recovered = False
        for tool_name in method_order:
            recovery_func = all_methods[tool_name]
            output_file = arq_path.with_name(f"{arq_path.stem}.{tool_name.lower()}.pdf")
            if recovery_func(arq_path, output_file):
                log.info(f"    ✔️ Recuperado com {tool_name}: {output_file.name}")
                ok.append(output_file)
                recovered = True
                break
        
        if not recovered:
            log.error(f"    ❌ Não foi possível recuperar {arq_path.name}.")
            ignorados.append(arq_path)
            
    return ok, ignorados

def unir_pdfs(arquivos: List[Path], saida: Path, no_blank_removal: bool) -> Tuple[int, int, str]:
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
        # A API do ocrmypdf espera argumentos nomeados (keyword arguments), não uma string de linha de comando.
        # A chamada original estava passando os argumentos de forma incorreta.
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
        if 'OCRMYPDF_GHOSTSCRIPT' in os.environ: del os.environ['OCRMYPDF_GHOSTSCRIPT']
        if 'OCRMYPDF_TESSERACT' in os.environ: del os.environ['OCRMYPDF_TESSERACT']

def build_parser():
    p = argparse.ArgumentParser(description="Ferramenta para unir e processar arquivos PDF.")
    p.add_argument("files", nargs="*", help="Arquivos PDF de entrada.")
    p.add_argument("--output", "-o", help="Nome do arquivo de saída.", default=None)
    p.add_argument("--no-blank-removal", action="store_true", help="Desativa a remoção de páginas em branco.")
    p.add_argument("--no-ocr", action="store_true", help="Desativa a aplicação de OCR.")
    p.add_argument("--force-ocr", action="store_true", help="Força OCR mesmo que o PDF já tenha texto.")
    p.add_argument("--ocr-output-type", choices=["pdf", "pdfa"], default="pdf", help="Tipo de saída do OCR.")
    p.add_argument("--ocr-optimize-level", type=int, choices=[0, 1, 2, 3], default=1, help="Nível de otimização do OCR.")
    p.add_argument("--prefer-libreoffice", action="store_true", help="Tenta LibreOffice primeiro para recuperação.")
    p.add_argument("--version", "-v", action="version", version=f"PDF Merge Tool {get_version_info().upper()}")
    return p

def main_logic(args):
    if not args.files:
        log.error("É necessário informar pelo menos um arquivo PDF.")
        return 1

    input_files = [Path(f) for f in args.files]
    log.info(f"Recebidos {len(input_files)} arquivo(s) para processar.")
    
    ok_files, ignored_files = preparar_pdfs_resiliente(input_files, args.prefer_libreoffice)
    if not ok_files:
        log.error("Nenhum arquivo válido para processar. Saindo.")
        return 1

    final_name = Path(args.output) if args.output else ok_files[0].with_name(f"{ok_files[0].stem}_unido.pdf")
    log.info(f"\nArquivo de saída será: {final_name}")

    temp_merge = final_name.with_name(f"{final_name.stem}_temp_merge.pdf")
    
    log.info(f"Unindo {len(ok_files)} arquivo(s)...")
    total_pg, removed_pg, err = unir_pdfs(ok_files, temp_merge, args.no_blank_removal)
    if err:
        raise RuntimeError(f"Erro fatal ao unir PDFs: {err}")
    log.info(f"  ✔️ União concluída. Total de páginas: {total_pg}. Páginas em branco removidas: {removed_pg}")
    
    working_file = temp_merge
    temp_ocr = None
    if not args.no_ocr:
        temp_ocr = final_name.with_name(f"{final_name.stem}_temp_ocr.pdf")
        ok_ocr, msg = run_ocr_api(working_file, temp_ocr, args)
        if ok_ocr and verifica_pdf(temp_ocr):
            log.info("  ✔️ OCR aplicado com sucesso.")
            working_file.unlink()
            working_file = temp_ocr
        else:
            log.warning(f"  ⚠️ Falha no OCR: {msg}. Continuando sem OCR.")
            if temp_ocr.exists(): temp_ocr.unlink()
    
    log.info(f"Salvando resultado final em: {final_name}")
    working_file.rename(final_name)

    # Limpeza de arquivos temporários e recuperados
    files_to_clean = [temp_merge] + ok_files
    if temp_ocr and temp_ocr.exists():
        files_to_clean.append(temp_ocr)
    for f in files_to_clean:
        if f.exists() and any(s in f.name for s in [".gs.pdf", ".qpdf.pdf", ".mutool.pdf", ".pdftk.pdf", ".imagem.pdf", ".libreoffice.pdf", "_temp_"]):
            try:
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
        return 1
        
    try:
        return main_logic(args)
    except Exception as e:
        log.critical("--- ERRO INESPERADO E FATAL ---", exc_info=True)
        if is_frozen():
            input("\nO PROGRAMA FALHOU. Pressione Enter para fechar...")
        return 1

if __name__ == "__main__":
    if is_frozen():
        tessdata_dir = Path(sys._MEIPASS) / "third_party_full" / "tesseract" / "tessdata"
        if tessdata_dir.exists():
            os.environ['TESSDATA_PREFIX'] = str(tessdata_dir)
    
    sys.exit(main())
