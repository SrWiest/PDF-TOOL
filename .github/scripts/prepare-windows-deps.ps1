#!/usr/bin/env pwsh
# Prepara dependências externas para a versão FULL do PDF-TOOL

Write-Host "=== Preparando dependências externas (qpdf, poppler, tesseract, ghostscript, mupdf) ===" -ForegroundColor Cyan
$ErrorActionPreference = "Stop"

# --- Instalação de ferramentas via Chocolatey ---
Write-Host "`nInstalando pré-requisitos via Chocolatey..." -ForegroundColor Yellow
try {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Error "Chocolatey não encontrado. Por favor, instale-o primeiro."
        exit 1
    }

    # Pacotes que funcionam melhor com a flag --x86
    $choco_packages_x86 = @(
        "ghostscript",
        "qpdf"
    )
    # Pacotes que não suportam ou não precisam da flag --x86
    $choco_packages_any = @(
        "poppler",
        "mupdf",
        "vcredist140",
        "pdftk-server"
    )

    foreach ($pkg in $choco_packages_x86) {
        Write-Host "--- Instalando $pkg (x86) ---"
        try {
            choco install $pkg --yes --no-progress --force --force-dependencies --x86
        } catch {
            Write-Warning "Falha ao instalar $pkg (x86). Continuando..."
        }
    }

    foreach ($pkg in $choco_packages_any) {
        Write-Host "--- Instalando $pkg ---"
        try {
            choco install $pkg --yes --no-progress --force --force-dependencies
        } catch {
            Write-Warning "Falha ao instalar $pkg. Continuando..."
        }
    }
}
catch {
    Write-Error "Falha ao instalar pacotes via Chocolatey. Erro: $($_.Exception.Message)"
    exit 1
}

# --- Preparação de diretórios ---
$thirdPartyDir = "third_party_full"
$licensesDir = "licenses"

# Limpa diretório de build para garantir um build limpo, mas preserva o diretório de licenças que vem do Git
if (Test-Path $thirdPartyDir) { Remove-Item -Recurse -Force $thirdPartyDir }
New-Item -ItemType Directory -Force -Path $thirdPartyDir | Out-Null
New-Item -ItemType Directory -Force -Path $licensesDir | Out-Null # Apenas garante que existe

# --- Manual Tesseract Download and Extraction ---
Write-Host "`n--- Baixando e extraindo Tesseract (portátil) ---" -ForegroundColor Cyan
$tesseractUrl = "https://sourceforge.net/projects/tesseract-ocr-alternative/files/tesseract-ocr-3.02-win32-portable.zip/download"
$tesseractZip = Join-Path $PSScriptRoot "tesseract-ocr-3.02-win32-portable.zip"
$tesseractDest = Join-Path $thirdPartyDir "tesseract"

try {
    Invoke-WebRequest -Uri $tesseractUrl -OutFile $tesseractZip
    Expand-Archive -Path $tesseractZip -Destination $tesseractDest -Force
    Remove-Item $tesseractZip # Clean up the zip file
    Write-Host "  ✅ Tesseract portátil baixado e extraído com sucesso." -ForegroundColor Green
} catch {
    Write-Warning "Falha ao baixar ou extrair Tesseract portátil. Erro: $($_.Exception.Message)"
}

# --- Função auxiliar para processar pacotes ---
function Process-Package {
    param (
        [Parameter(Mandatory)][string]$PackageName,
        [string]$DestSubFolder,
        [string[]]$SourcePaths
    )

    Write-Host "`n-- Processando pacote: $PackageName --" -ForegroundColor Cyan
    $found = $false

    foreach ($sourcePath in $SourcePaths) {
        $expandedPath = try { Resolve-Path -Path $sourcePath -ErrorAction SilentlyContinue } catch { $null }
        if (-not $expandedPath) { continue }

        $actualSourcePath = $expandedPath | Select-Object -First 1

        if (Test-Path $actualSourcePath) {
            Write-Host "  Encontrado em: $actualSourcePath"
            $destDir = Join-Path $thirdPartyDir $DestSubFolder
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            Copy-Item -Path "$actualSourcePath\*" -Destination $destDir -Recurse -Force
            Write-Host "  >> Copiado $PackageName para $destDir" -ForegroundColor Green
            $found = $true
            break
        }
    }

    if (-not $found) {
        Write-Warning "  >> Pacote $PackageName não encontrado nos caminhos esperados."
    }
}

# --- Mapeamento de pacotes e caminhos de busca (CORRIGIDO) ---
$chocoLibPath = "C:\ProgramData\chocolatey\lib"

$packages = @{
    qpdf           = @{ Dest = "qpdf";        Paths = @(Join-Path $chocoLibPath "qpdf\tools\qpdf*\bin") }
    poppler        = @{ Dest = "poppler";     Paths = @(Join-Path $chocoLibPath "poppler\tools\poppler*\bin") }
    'pdftk-server' = @{ Dest = "pdftk";       Paths = @(Join-Path $env:ProgramFiles(x86) "PDFtk Server\bin") }
    # tesseract is handled manually
    ghostscript    = @{ Dest = "ghostscript"; Paths = @(Join-Path $chocoLibPath "Ghostscript\tools\gs*\bin") }
    mupdf          = @{ Dest = "mupdf";       Paths = @(Join-Path $chocoLibPath "mupdf\tools\mupdf*") }
}

# --- Processamento dos pacotes ---
foreach ($pkgName in $packages.Keys) {
    $pkgInfo = $packages[$pkgName]
    Process-Package -PackageName $pkgName -DestSubFolder $pkgInfo.Dest -SourcePaths $pkgInfo.Paths
}

# --- Verificação final ---
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  Verificação Final do Conteúdo" -ForegroundColor Cyan
Write-Host "========================================="
Get-ChildItem -Path $thirdPartyDir -Recurse
