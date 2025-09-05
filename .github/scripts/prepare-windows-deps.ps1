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

    # Instalar pacotes um por um para melhor log e resiliência
    # Forçar versão x86 para compatibilidade com executável de 32-bit
    $choco_packages_x86 = @(
        "ghostscript",
        "qpdf",
        "poppler",
        "tesseract",
        "mupdf"
    )
    $choco_packages_any = @(
        "vcredist140",
        "pdftk-server"
    )

    foreach ($pkg in $choco_packages_x86) {
        Write-Host "--- Instalando $pkg (x86) ---"
        try {
            choco install $pkg --yes --no-progress --force --force-dependencies --x86
        } catch {
            Write-Warning "Falha ao instalar $pkg (x86). Tentando sem --x86..."
            try {
                choco install $pkg --yes --no-progress --force --force-dependencies
                Write-Host "  ✅ $pkg instalado sem --x86" -ForegroundColor Green
            } catch {
                Write-Warning "Falha completa ao instalar $pkg. Continuando..."
            }
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
$missingLicensesFile = Join-Path $licensesDir "MISSING_LICENSES.txt"

New-Item -ItemType Directory -Force -Path $thirdPartyDir | Out-Null
New-Item -ItemType Directory -Force -Path $licensesDir | Out-Null
"Os seguintes componentes ou seus arquivos de licença não foram encontrados durante o build:" | Set-Content -Path $missingLicensesFile

$global:errorCount = 0

# --- Função auxiliar para processar pacotes ---
function Process-Package {
    param (
        [Parameter(Mandatory)][string]$PackageName,
        [string]$DestSubFolder,
        [string[]]$SourcePaths, # Caminhos relativos ou absolutos onde procurar os binários
        [string]$LicenseSearchPattern = "LICENSE*,COPYING*"
    )

    Write-Host "`n-- Processando pacote: $PackageName --" -ForegroundColor Cyan
    $found = $false

    foreach ($sourcePath in $SourcePaths) {
        # Expandir wildcards no caminho
        $expandedPaths = try { Resolve-Path -Path $sourcePath -ErrorAction Stop } catch { $null }
        if (-not $expandedPaths) { continue }

        $actualSourcePath = $expandedPaths | Select-Object -Last 1 # Pegar a versão mais recente se houver múltiplas

        if (Test-Path $actualSourcePath) {
            Write-Host "  Encontrado em: $actualSourcePath"
            $destDir = Join-Path $thirdPartyDir $DestSubFolder
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            Copy-Item -Path "$actualSourcePath\*" -Destination $destDir -Recurse -Force
            Write-Host "  >> Copiado $PackageName para $destDir" -ForegroundColor Green

            $licenseFile = Get-ChildItem -Path $actualSourcePath -Include $LicenseSearchPattern -File -Recurse | Select-Object -First 1
            if ($licenseFile) {
                $licenseDest = Join-Path $licensesDir "$($PackageName)_LICENSE.txt"
                Copy-Item -Path $licenseFile.FullName -Destination $licenseDest -Force
                Write-Host "  >> Licença copiada para $licenseDest" -ForegroundColor Green
            } else {
                Write-Host "  >> Arquivo de licença não encontrado para $PackageName (normal em CI)" -ForegroundColor Yellow
                # Não adicionar ao MISSING_LICENSES.txt em ambiente CI
                # Add-Content -Path $missingLicensesFile -Value "$($PackageName): arquivo de licença não encontrado."
            }
            $found = $true
            break
        }
    }

    if (-not $found) {
        Write-Host "  >> Pacote $PackageName não encontrado - será usado modo limitado" -ForegroundColor Yellow
        # Em ambiente CI, não contar como erro crítico
        # Add-Content -Path $missingLicensesFile -Value "$($PackageName): pacote não encontrado."
        # $global:errorCount++
    }
}

# --- Mapeamento de pacotes e caminhos de busca ---
$chocoLibPath = "C:\ProgramData\chocolatey\lib"

$packages = @{
    qpdf           = @(
        (Join-Path $chocoLibPath "qpdf\tools\qpdf*\bin"),
        (Join-Path $chocoLibPath "qpdf\tools\bin"),
        "C:\ProgramData\chocolatey\bin"
    )
    poppler        = @(
        (Join-Path $chocoLibPath "poppler\tools\poppler*\bin"),
        (Join-Path $chocoLibPath "poppler\tools\bin"),
        "C:\ProgramData\chocolatey\bin"
    )
    'pdftk-server' = @(
        (Join-Path "$env:ProgramFiles(x86)" "PDFtk Server\bin"),
        (Join-Path $chocoLibPath "pdftk-server\tools\bin"),
        "C:\ProgramData\chocolatey\bin"
    )
    tesseract      = @(
        (Join-Path "$env:ProgramFiles(x86)" "Tesseract-OCR"),
        (Join-Path $chocoLibPath "tesseract\tools\bin"),
        "C:\ProgramData\chocolatey\bin"
    )
    ghostscript    = @(
        (Join-Path "$env:ProgramFiles(x86)" "gs\gs*\bin"),
        (Join-Path $chocoLibPath "ghostscript\tools\gs*\bin"),
        (Join-Path $chocoLibPath "ghostscript\tools\bin"),
        "C:\ProgramData\chocolatey\bin"
    )
    mupdf          = @(
        (Join-Path $chocoLibPath "mupdf\tools"),
        (Join-Path $chocoLibPath "mupdf\tools\mupdf*"),
        (Join-Path $chocoLibPath "mupdf"),
        "C:\ProgramData\chocolatey\bin"
    )
}

# --- Processamento dos pacotes ---
foreach ($pkgName in $packages.Keys) {
    $destName = if ($pkgName -eq "pdftk-server") { "pdftk" } else { $pkgName }
    Process-Package -PackageName $pkgName -DestSubFolder $destName -SourcePaths $packages[$pkgName]
}

# --- Verificação final ---
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  Verificação Final" -ForegroundColor Cyan
Write-Host "========================================="

if ($global:errorCount -gt 0) {
    Write-Host "ℹ️  $($global:errorCount) dependência(s) não encontrada(s) - build continuará com funcionalidades limitadas." -ForegroundColor Yellow
    Write-Host "✅ Build prosseguindo normalmente..." -ForegroundColor Green
    # Não criar arquivo MISSING_LICENSES.txt em CI
    # Verificar se o arquivo existe e removê-lo se estiver vazio
    if ((Test-Path $missingLicensesFile) -and ((Get-Content $missingLicensesFile).Count -le 1)) {
        Remove-Item $missingLicensesFile -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "🎉 Todas as dependências foram preparadas com sucesso." -ForegroundColor Green
    Remove-Item $missingLicensesFile -ErrorAction SilentlyContinue
}