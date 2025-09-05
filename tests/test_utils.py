#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Testes para as funções utilitárias

import pytest
from pathlib import Path
import sys
from unittest.mock import patch

# Adicionar o diretório src ao path para que possamos importar os módulos
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from utils import human_size, file_size, is_frozen, get_version_info

# --- Testes para human_size ---

@pytest.mark.parametrize("size_in, expected_out", [
    (100, "100.0B"),
    (1023, "1023.0B"),
    (1024, "1.0KB"),
    (1500, "1.5KB"),
    (1024 * 1024 - 1, "1024.0KB"),
    (1024 * 1024, "1.0MB"),
    (1.5 * 1024 * 1024, "1.5MB"),
    (1024 * 1024 * 1024, "1.0GB"),
    (0, "0.0B"),
    (-100, "-100.0B"), # Embora não esperado, o comportamento deve ser consistente
    ("invalid", "?"),
    (None, "?"),
])
def test_human_size(size_in, expected_out):
    assert human_size(size_in) == expected_out

# --- Testes para file_size ---

def test_file_size(tmp_path):
    # Criar um arquivo temporário com conteúdo
    p = tmp_path / "test_file.txt"
    p.write_text("1234567890")
    
    # Testar se o tamanho está correto
    assert file_size(p) == 10
    
    # Testar um arquivo que não existe
    non_existent_file = tmp_path / "not_real.txt"
    assert file_size(non_existent_file) == -1

# --- Testes para is_frozen e get_version_info ---

def test_get_version_info_lite_frozen():
    with patch('sys.frozen', True, create=True), \
         patch('sys.executable', "/path/to/pdf_merge_tool_win_lite.exe"):
        assert is_frozen() is True
        assert get_version_info() == 'lite'

def test_get_version_info_medium_frozen():
    with patch('sys.frozen', True, create=True), \
         patch('sys.executable', "/path/to/pdf_merge_tool_win_medium.exe"):
        assert is_frozen() is True
        assert get_version_info() == 'medium'

def test_get_version_info_full_frozen():
    with patch('sys.frozen', True, create=True), \
         patch('sys.executable', "/path/to/pdf_merge_tool_win_full.exe"):
        assert is_frozen() is True
        assert get_version_info() == 'full'

def test_get_version_info_development():
    # Garante que o atributo 'frozen' não existe para este teste
    if hasattr(sys, 'frozen'):
        del sys.frozen
    assert is_frozen() is False
    assert get_version_info() == 'development'