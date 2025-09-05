# PDF Merge Tool

Ferramenta avançada para unir PDFs com recuperação robusta de arquivos corrompidos, OCR automático e otimização de tamanho.

## 🚀 **Versões Disponíveis**

### 📦 **LITE** - Básico e Leve
- ✅ União de PDFs válidos
- ✅ Remoção de páginas em branco
- ❌ Sem ferramentas de recuperação externas
- ❌ Sem OCR
- 📁 **Tamanho**: ~5-10MB

### ⚖️ **MEDIUM** - Equilibrio Perfeito ⭐ **RECOMENDADO**
- ✅ União de PDFs + recuperação robusta
- ✅ **7 métodos de recuperação**: Ghostscript, qpdf, mutool, pdftk, pdftoppm+img2pdf, ImageMagick, Python puro
- ✅ OCR automático (OCRmyPDF + Tesseract)
- ✅ Remoção de páginas em branco
- ✅ Otimização de tamanho
- ❌ Sem LibreOffice (para manter tamanho menor)
- 📁 **Tamanho**: ~150-200MB

### 🔥 **FULL** - Máxima Robustez
- ✅ Todas as funcionalidades do MEDIUM
- ✅ **8 métodos de recuperação** incluindo **LibreOffice Portable**
- ✅ Recuperação superior de PDFs que outras ferramentas não conseguem
- ✅ Timeout inteligente e limpeza automática de processos
- 📁 **Tamanho**: ~400-500MB

## 💻 **Uso Rápido**

```sh
# Versão LITE (básica)
pdf_merge_tool_win_lite.exe A.pdf B.pdf

# Versão MEDIUM (recomendada) - 7 métodos de recuperação
pdf_merge_tool_win_medium.exe A.pdf B.pdf --final-shrink --shrink-report

# Versão FULL - LibreOffice como prioridade para PDFs muito corrompidos
pdf_merge_tool_win_full.exe A.pdf B.pdf --prefer-libreoffice

# Verificar versão
pdf_merge_tool_win_medium.exe --version
```

## 📦 **Downloads Prontos**

Os instaladores são gerados automaticamente via GitHub Actions:

- **📥 `PDFMergeTool-Lite-Setup.exe`** - Versão Lite (~10MB)
- **📥 `PDFMergeTool-Medium-Setup.exe`** - Versão Medium (~150MB) ⭐ **RECOMENDADO**
- **📥 `PDFMergeTool-Setup.exe`** - Versão Full (~500MB)

## 🔧 **Como Compilar Manualmente (Windows)**

1. Instale Python 3.11 (recomendado) e o [PyInstaller](https://pyinstaller.org/):
	 ```sh
	 python -m pip install --upgrade pip setuptools wheel
	 pip install pyinstaller
	 ```
2. Instale as dependências:
	 - Para versão **LITE**:
		 ```sh
		 pip install -r requirements/requirements-lite.txt
		 ```
	 - Para versão **MEDIUM**:
		 ```sh
		 pip install -r requirements/requirements-medium.txt ocrmypdf
		 ```
	 - Para versão **FULL**:
		 ```sh
		 pip install -r requirements/requirements-full.txt ocrmypdf
		 ```
3. Gere o executável:
	 - **LITE**:
		 ```sh
		 pyinstaller specs/pdf_merge_lite.spec --clean
		 ```
	 - **MEDIUM**:
		 ```sh
		 pyinstaller specs/pdf_merge_medium.spec --clean
		 ```
	 - **FULL**:
		 ```sh
		 pyinstaller specs/pdf_merge_full.spec --clean
		 ```

4. O executável estará em `dist/`.

## 🛠 **Gerar Instaladores**

Após compilar, gere os instaladores com Inno Setup:

```sh
cd installer

# Instalar Inno Setup
choco install innosetup

# Gerar instaladores
ISCC.exe install_lite.iss
ISCC.exe install_medium.iss  
ISCC.exe install_full.iss
```

## Troubleshooting
- Certifique-se de rodar o build em ambiente Windows.
- Se faltar algum binário externo (qpdf, tesseract, ghostscript), coloque-os na pasta `third_party_full` antes do build FULL.
- Para checar dependências e ambiente, use o script:
	```sh
	python src/embed_diagnostics.py
	```
- Se der erro de importação, confira se todas as dependências do `requirements` estão instaladas.

## Exemplos de uso
```sh
pdf_merge_tool_win_lite.exe arquivo1.pdf arquivo2.pdf
pdf_merge_tool_win_full.exe arquivo1.pdf arquivo2.pdf --final-shrink --shrink-report
pdf_merge_tool_win_full.exe arquivo1.pdf arquivo2.pdf --prefer-libreoffice  # Melhor recuperação de PDFs corrompidos
pdf_merge_tool_win_full.exe --version
```

## Recuperação de PDFs corrompidos

A ferramenta possui múltiplas opções para recuperar PDFs corrompidos:

1. **Padrão**: Ghostscript → qpdf → mutool → pdftk → LibreOffice
2. **Com `--prefer-libreoffice`**: LibreOffice → Ghostscript → qpdf → mutool → pdftk

O LibreOffice possui algoritmos de recuperação muito robustos e pode recuperar PDFs que outras ferramentas não conseguem. Para ativar:

```sh
pdf_merge_tool_win_full.exe arquivo_corrompido.pdf --prefer-libreoffice
```

**Versão FULL inclui LibreOffice embutido**: A versão FULL já vem com LibreOffice Portable embutido, não necessitando instalação separada. Se o LibreOffice estiver instalado no sistema, será usado preferencialmente.

## Para desenvolvedores
- Scripts principais em `src/`
- Especificações do PyInstaller em `specs/`
- Instalação via Inno Setup: veja `installer/install_full.iss`
- Licenças de terceiros em `licenses/`

## Licença
Consulte o arquivo LICENSE e a seção de terceiros em `licenses/THIRD_PARTY_LICENSES.txt`.

# Test commit after clean history
# CircleCI test commit
# Test: Only CircleCI active
# CircleCI Build Test vie 05 sep 2025 11:21:45 -03
# Test CircleCI with fixed Windows config
# Trigger pre-release build
# Test improved dependency installation
