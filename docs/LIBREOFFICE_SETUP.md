# Instruções para incluir LibreOffice Portable no PDF Merge Tool

## Download manual do LibreOffice Portable

Se o script automático falhar ou você quiser incluir o LibreOffice manualmente:

### 1. Baixar LibreOffice Portable
- Acesse: https://portableapps.com/apps/office/libreoffice_portable
- Baixe a versão mais recente (arquivo .paf.exe)

### 2. Extrair para o local correto
```
third_party_full/
└── libreoffice/
    ├── program/
    │   ├── soffice.exe
    │   ├── soffice.bin
    │   └── (outros arquivos)
    └── share/
        ├── config/
        ├── registry/
        └── (outros diretórios)
```

### 3. Estrutura mínima necessária
Para reduzir o tamanho do executável final, você pode incluir apenas:

**Essencial:**
- `program/soffice.exe` (executável principal)
- `program/soffice.bin` (binário principal)
- `program/*.dll` (bibliotecas necessárias)
- `share/config/` (configurações)
- `share/registry/` (registro do programa)

**Opcional (para funcionalidade completa):**
- `share/autocorr/` (correção automática)
- `share/template/` (modelos)
- `share/gallery/` (galeria de imagens)

### 4. Teste local
Antes de fazer build, teste se o LibreOffice funciona:

```cmd
cd third_party_full/libreoffice/program
soffice.exe --headless --convert-to pdf --outdir C:\temp C:\caminho\para\teste.pdf
```

### 5. Versões recomendadas
- **LibreOffice 7.6.x**: Versão estável mais recente
- **Tamanho típico**: 150-300 MB (dependendo dos componentes incluídos)
- **Compatibilidade**: Windows 10/11 x64

## Notas importantes

1. **Licença**: LibreOffice é licenciado sob MPL 2.0, compatível para distribuição
2. **Tamanho**: O executável final ficará maior (adiciona ~200MB)
3. **Performance**: Primeira execução pode ser mais lenta (inicialização do LibreOffice)
4. **Fallback**: Se LibreOffice embutido falhar, tenta instalação do sistema

## Troubleshooting

### LibreOffice não inicia
- Verifique se todas as DLLs estão presentes
- Teste execução manual do soffice.exe
- Verifique permissões de execução

### Timeout na conversão
- Aumente o timeout no código (padrão: 60s)
- Verifique se há antivírus bloqueando
- Teste com PDF menor primeiro

### Arquivo não convertido
- Verifique se o PDF original abre no LibreOffice Desktop
- Teste conversão manual via linha de comando
- Confira logs de debug no output
