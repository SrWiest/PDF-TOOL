#!/usr/bin/env pwsh
# Script unificado para baixar, preparar e embutir o LibreOffice

param(
    [string]$OutputDir = "third_party_full/libreoffice"
)

$ErrorActionPreference = "Stop"

# --- Funções Auxiliares ---

function Install-ChocolateyPackages {
    param ([string[]]$packages)
    
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey não encontrado, instalando..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        try {
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        } catch {
            throw "Falha ao instalar Chocolatey. $_"
        }
    }
    
    foreach ($pkg in $packages) {
        Write-Host "Instalando $pkg via Chocolatey..." -ForegroundColor Yellow
        choco install $pkg --yes --no-progress --force
    }
}

function Embed-LibreOffice {
    param ([string]$SourceDir)

    Write-Host "Copiando arquivos essenciais de $SourceDir..." -ForegroundColor Yellow
    $FullOutputDir = Join-Path $PWD $OutputDir
    if (-not (Test-Path $FullOutputDir)) {
        New-Item -ItemType Directory -Force -Path $FullOutputDir | Out-Null
    }

    # Copiar diretórios principais
    foreach ($subDir in @("program", "share")) {
        $src = Join-Path $SourceDir $subDir
        $dest = Join-Path $FullOutputDir $subDir
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $dest -Recurse -Force
            Write-Host "✓ Diretório '$subDir' copiado."
        }
    }

    # Verificar resultado
    $finalSofficeExe = Join-Path $FullOutputDir "program\soffice.exe"
    if (-not (Test-Path $finalSofficeExe)) {
        throw "Falha ao copiar soffice.exe para o destino final"
    }
    
    return $finalSofficeExe
}

# --- Lógica Principal ---

Write-Host "=== Preparando LibreOffice para embedding ===" -ForegroundColor Green
$libreOfficeSourceDir = $null

# --- MÉTODO 1: Instalação via Chocolatey (Preferencial) ---
try {
    Write-Host "`nTentativa 1: Instalar via Chocolatey (método preferencial)" -ForegroundColor Cyan
    Install-ChocolateyPackages -packages "libreoffice-fresh"
    
    # Encontrar a instalação
    $searchPaths = @("${env:ProgramFiles}\LibreOffice", "${env:ProgramFiles(x86)}\LibreOffice")
    foreach ($path in $searchPaths) {
        if (Test-Path (Join-Path $path "program\soffice.exe")) {
            $libreOfficeSourceDir = $path
            Write-Host "LibreOffice encontrado em: $libreOfficeSourceDir" -ForegroundColor Green
            break
        }
    }
    if (-not $libreOfficeSourceDir) { throw "Não foi possível encontrar o diretório do LibreOffice após a instalação." }

} catch {
    Write-Warning "Falha ao instalar LibreOffice via Chocolatey. Erro: $($_.Exception.Message)"
    Write-Warning "Tentando método de fallback (download direto)."
    $libreOfficeSourceDir = $null # Reseta a variável para a próxima tentativa
}

# --- MÉTODO 2: Download Direto e Extração (Fallback) ---
if (-not $libreOfficeSourceDir) {
    try {
        Write-Host "`nTentativa 2: Download direto e extração (fallback)" -ForegroundColor Cyan
        Install-ChocolateyPackages -packages "7zip.install"
        $7zExe = "${env:ProgramFiles}\7-Zip\7z.exe"

        $url = "https://sourceforge.net/projects/portableapps/files/LibreOffice%20Portable/LibreOfficePortable_7.6.7_English.paf.exe/download"
        $downloadFile = Join-Path $env:TEMP "LibreOffice.paf.exe"
        $extractPath = Join-Path $env:TEMP "LibreOfficeExtract"

        Write-Host "Baixando de $url..."
        Invoke-WebRequest -Uri $url -OutFile $downloadFile -UseBasicParsing -TimeoutSec 600

        Write-Host "Extraindo com 7-Zip..."
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
        & $7zExe x "$downloadFile" "-o$extractPath" -y | Out-Null

        # Encontra o diretório correto dentro da extração
        $libreOfficeSourceDir = Get-ChildItem -Path $extractPath -Directory -Recurse | Where-Object {
            Test-Path (Join-Path $_.FullName "App\libreoffice\program\soffice.exe")
        } | Select-Object -First 1 | ForEach-Object { Join-Path $_.FullName "App\libreoffice" }

        if (-not $libreOfficeSourceDir) { throw "soffice.exe não encontrado após extração." }
        Write-Host "LibreOffice extraído para: $libreOfficeSourceDir" -ForegroundColor Green

    } catch {
        Write-Error "Todos os métodos de preparação do LibreOffice falharam. Erro final: $($_.Exception.Message)"
        Write-Warning "O build continuará sem o LibreOffice embutido."
        exit 0 # Não falha o build
    }
}

# --- Etapa Final: Copiar arquivos e verificar ---
try {
    $finalExePath = Embed-LibreOffice -SourceDir $libreOfficeSourceDir
    
    # Criar arquivo de informação
    $infoFile = Join-Path (Join-Path $PWD $OutputDir) "VERSION.txt"
    "LibreOffice (Preparado via script unificado)" | Out-File -FilePath $infoFile -Encoding UTF8
    "Preparado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $infoFile -Append -Encoding UTF8

    $totalSize = (Get-ChildItem -Path (Join-Path $PWD $OutputDir) -Recurse | Measure-Object -Property Length -Sum).Sum
    Write-Host "`n🎉 LibreOffice preparado com sucesso!" -ForegroundColor Green
    Write-Host "   Localização: $(Join-Path $PWD $OutputDir)"
    Write-Host "   Tamanho total: $([math]::Round($totalSize / 1MB, 2)) MB"

    # Teste rápido do executável
    Write-Host "Testando executável..." -ForegroundColor Yellow
    & $finalExePath --version

} catch {
    Write-Error "Falha ao copiar os arquivos do LibreOffice. Erro: $($_.Exception.Message)"
    Write-Warning "O build continuará sem o LibreOffice embutido."
    exit 0 # Não falha o build
} finally {
    # Limpeza de arquivos temporários
    Remove-Item (Join-Path $env:TEMP "LibreOffice.paf.exe") -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:TEMP "LibreOfficeExtract") -Recurse -Force -ErrorAction SilentlyContinue
}