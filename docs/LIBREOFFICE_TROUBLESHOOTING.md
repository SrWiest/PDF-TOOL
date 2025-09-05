# Guia de Teste e Troubleshooting - LibreOffice PDF Recovery

## Como testar a recuperação com LibreOffice

### 1. Teste básico com PDF corrompido
```cmd
# Testar recuperação padrão (LibreOffice como último recurso)
pdf_merge_tool_win_full.exe arquivo_corrompido.pdf

# Testar priorizando LibreOffice
pdf_merge_tool_win_full.exe arquivo_corrompido.pdf --prefer-libreoffice
```

### 2. Interpretar logs do LibreOffice

**✅ Sucesso esperado:**
```
[INFO] Encontrado executável embutido: ...\libreoffice\program\soffice.exe
[libreoffice_debug] Usando LibreOffice embutido: ...
[libreoffice_debug] Comando: soffice.exe --headless --invisible...
[libreoffice_debug] Conversão bem-sucedida!
✔️ LibreOffice: arquivo.libreoffice.pdf
```

**❌ Erros comuns e soluções:**

#### "User installation could not be completed"
**Causa:** Profile do LibreOffice não pode ser criado
**Solução implementada:** 
- Profile temporário com `-env:UserInstallation`
- Variável `SAL_USE_VCLPLUGIN=svp` para modo headless
- Fallback com comando simplificado

#### "The application cannot be started"
**Causa:** Dependências DLL faltando ou conflito
**Soluções:**
1. Verificar se todas as DLLs do LibreOffice foram copiadas
2. Testar com LibreOffice do sistema: instalar LibreOffice Desktop
3. Verificar antivírus não está bloqueando

#### "format error: cannot find version marker"
**Causa:** PDF muito corrompido até para LibreOffice
**Resultado:** Normal - nem todo PDF pode ser recuperado

### 3. Testes manuais para debug

#### Testar LibreOffice embutido diretamente:
```cmd
cd "C:\Program Files (x86)\PDF Merge Tool\_internal\third_party_full\libreoffice\program"
soffice.exe --headless --convert-to pdf --outdir C:\temp C:\caminho\para\test.pdf
```

#### Verificar se profile funciona:
```cmd
soffice.exe --headless --safe-mode --version
```

#### Testar conversão específica:
```cmd
soffice.exe --headless --invisible --convert-to pdf C:\test.pdf
```

### 4. Comparação de eficácia por ferramenta

**Ordem recomendada para PDFs muito corrompidos:**
1. **LibreOffice** - Melhor para PDFs com estrutura danificada
2. **Ghostscript** - Bom para problemas de compressão/codificação  
3. **qpdf** - Eficaz para problemas de xref/trailer
4. **mutool** - Rápido para reparos básicos
5. **pdftk** - Limitado mas estável

### 5. Criando PDFs de teste corrompidos

```python
# Script para corromper PDF para teste
with open('original.pdf', 'rb') as f:
    data = f.read()

# Corromper header
corrupted = b'%PDF-1.4\n' + data[9:100] + b'\x00\x00\x00' + data[103:]

with open('corrupted_test.pdf', 'wb') as f:
    f.write(corrupted)
```

### 6. Métricas de sucesso esperadas

**PDFs levemente corrompidos:** 95% de sucesso
**PDFs moderadamente corrompidos:** 70-80% de sucesso  
**PDFs severamente corrompidos:** 30-50% de sucesso
**PDFs completamente ilegíveis:** 0-10% de sucesso

### 7. Troubleshooting por código de erro

| Código | Descrição | Ação |
|--------|-----------|------|
| 0 | Sucesso | ✅ |
| 1 | Erro geral | Verificar logs, tentar método simplificado |
| 77 | Profile error | Normal - fallback implementado |
| 81 | Conversion failed | PDF pode estar muito corrompido |

### 8. Performance esperada

- **Ghostscript:** 1-5 segundos
- **qpdf:** 1-3 segundos  
- **mutool:** 1-2 segundos
- **pdftk:** 2-5 segundos
- **LibreOffice:** 10-30 segundos (mais lento, mas mais eficaz)

### 9. Quando usar cada opção

```cmd
# Para PDFs que outras ferramentas falharam
pdf_merge_tool_win_full.exe corrupted.pdf --prefer-libreoffice

# Para velocidade máxima (sem LibreOffice)
pdf_merge_tool_win_lite.exe files*.pdf

# Para máxima compatibilidade (todas as ferramentas)
pdf_merge_tool_win_full.exe mixed_files*.pdf
```

### 10. Logs úteis para reportar bugs

Se encontrar problemas, inclua estes logs:
- `[libreoffice_debug]` - Comando executado
- `[libreoffice_debug_stderr]` - Erros específicos
- Exit code do processo
- Tamanho do arquivo original vs convertido
