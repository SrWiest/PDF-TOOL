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
    $choco_packages = @(
        "ghostscript",
        "qpdf",
        "poppler",
        "tesseract",
        "mupdf",
        "vcredist140",
        "pdftk-server"
    )

    foreach ($pkg in $choco_packages) {
        Write-Host "--- Instalando $pkg ---" -ForegroundColor Cyan
        try {
            # A flag --x86 não é confiável e pode não ser suportada por todos os pacotes.
            # A maioria dos pacotes modernos lida com a arquitetura correta.
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

# Limpa diretórios antigos para garantir um build limpo
if (Test-Path $thirdPartyDir) { Remove-Item -Recurse -Force $thirdPartyDir }
if (Test-Path $licensesDir) { Remove-Item -Recurse -Force $licensesDir }
New-Item -ItemType Directory -Force -Path $thirdPartyDir | Out-Null
New-Item -ItemType Directory -Force -Path $licensesDir | Out-Null

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
        $expandedPath = try { Resolve-Path -Path $sourcePath -ErrorAction SilentlyContinue } catch { $null }
        if (-not $expandedPath) { continue }

        # Pega o primeiro caminho encontrado que existe
        $actualSourcePath = $expandedPath | Select-Object -First 1

        if (Test-Path $actualSourcePath) {
            Write-Host "  Encontrado em: $actualSourcePath"
            $destDir = Join-Path $thirdPartyDir $DestSubFolder
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            Copy-Item -Path "$actualSourcePath\*" -Destination $destDir -Recurse -Force
            Write-Host "  >> Copiado $PackageName para $destDir" -ForegroundColor Green

            # Lógica de licença (simplificada)
            $licenseFile = Get-ChildItem -Path $actualSourcePath -Include $LicenseSearchPattern -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($licenseFile) {
                $licenseDest = Join-Path $licensesDir "$($PackageName)_LICENSE.txt"
                Copy-Item -Path $licenseFile.FullName -Destination $licenseDest -Force
                Write-Host "  >> Licença copiada para $licenseDest" -ForegroundColor Green
            }
            $found = $true
            break # Para de procurar assim que encontrar um caminho válido
        }
    }

    if (-not $found) {
        Write-Warning "  >> Pacote $PackageName não encontrado nos caminhos esperados."
    }
}

# --- Mapeamento de pacotes e caminhos de busca ---
$chocoLibPath = "C:\ProgramData\chocolatey\lib"

# Caminhos mais robustos e específicos para cada ferramenta
$packages = @{
    qpdf           = @{ Dest = "qpdf";        Paths = @(Join-Path $chocoLibPath "qpdf\tools\bin") }
    poppler        = @{ Dest = "poppler";     Paths = @(Join-Path $chocoLibPath "poppler\tools\poppler*\bin") }
    'pdftk-server' = @{ Dest = "pdftk";       Paths = @(Join-Path $chocoLibPath "pdftk-server\tools\bin") }
    tesseract      = @{ Dest = "tesseract";   Paths = @(Join-Path $chocoLibPath "tesseract\tools") }
    ghostscript    = @{ Dest = "ghostscript"; Paths = @(Join-Path $chocoLibPath "ghostscript\tools\gs*\bin") }
    mupdf          = @{ Dest = "mupdf";       Paths = @(Join-Path $chocoLibPath "mupdf\tools") }
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
