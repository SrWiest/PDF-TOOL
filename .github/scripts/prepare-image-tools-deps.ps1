#!/usr/bin/env pwsh
# Baixa e configura ferramentas de imagem necessárias para PDF-TOOL

$ErrorActionPreference = "Stop"

# =========================================
# FUNÇÃO DE INSTALAÇÃO DE FERRAMENTAS
# =========================================

function Install-Tool {
    param (
        [string]$Name,
        [string]$Url,
        [string]$AltUrl,
        [string]$TargetDir,
        [string]$ExecutablePath,
        [string]$ChocoPackage,
        [switch]$SpecialExtraction
    )

    Write-Host "`n🔽 Baixando e configurando $Name..." -ForegroundColor Yellow
    
    $full_executable_path = Join-Path $TargetDir $ExecutablePath
    if (Test-Path $full_executable_path) {
        Write-Host "  ✅ $Name já configurado" -ForegroundColor Green
        return $true
    }

    $download_success = $false
    $zip_file = "$Name.zip"

    # Tentar URL principal
    try {
        Write-Host "  Tentando URL principal: $Url"
        Invoke-WebRequest -Uri $Url -OutFile $zip_file -TimeoutSec 180
        $download_success = $true
        Write-Host "  ✅ Download da URL principal completo."
    }
    catch {
        Write-Host "  ❌ URL principal falhou: $($_.Exception.Message)" -ForegroundColor Yellow
        # Tentar URL alternativa
        try {
            Write-Host "  Tentando URL alternativa: $AltUrl"
            Invoke-WebRequest -Uri $AltUrl -OutFile $zip_file -TimeoutSec 180
            $download_success = $true
            Write-Host "  ✅ Download da URL alternativa completo."
        }
        catch {
            Write-Host "  ❌ URL alternativa também falhou: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if ($download_success) {
        try {
            Write-Host "  Extraindo $Name..."
            if ($SpecialExtraction) {
                # Lógica de extração especial para Poppler
                $temp_extract_dir = "temp_${Name}_extract"
                if (Test-Path $temp_extract_dir) { Remove-Item $temp_extract_dir -Recurse -Force }
                New-Item -ItemType Directory -Path $temp_extract_dir -Force | Out-Null
                
                Expand-Archive -Path $zip_file -DestinationPath $temp_extract_dir -Force
                
                $extracted_dir = Get-ChildItem -Path $temp_extract_dir -Directory | Select-Object -First 1
                if ($extracted_dir) {
                    if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force }
                    Move-Item -Path "$($extracted_dir.FullName)/*" -Destination $TargetDir -Force
                    Remove-Item $temp_extract_dir -Recurse -Force
                } else {
                    throw "Não foi possível encontrar o diretório extraído para $Name"
                }
            } else {
                # Lógica de extração padrão
                if (-not (Test-Path $TargetDir)) {
                    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
                }
                Expand-Archive -Path $zip_file -DestinationPath $TargetDir -Force
            }
            Remove-Item $zip_file -Force
            
            if (Test-Path $full_executable_path) {
                Write-Host "  ✅ $Name configurado com sucesso" -ForegroundColor Green
                return $true
            } else {
                Write-Host "  ❌ Executável não encontrado após extração: $full_executable_path" -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-Host "  ❌ Erro durante extração: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Fallback para Chocolatey
    if (-not (Test-Path $full_executable_path)) {
        Write-Host "  Tentando fallback com Chocolatey..." -ForegroundColor Yellow
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            try {
                choco install $ChocoPackage -y --force --no-progress --x86
                Write-Host "  ✅ $Name instalado via Chocolatey" -ForegroundColor Green
                # Para Poppler, o choco instala em um local diferente, então não podemos verificar o full_executable_path aqui
                return $true 
            }
            catch {
                Write-Host "  ❌ Fallback Chocolatey falhou: $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "  ❌ Chocolatey não encontrado. Pulando fallback." -ForegroundColor Yellow
            return $false
        }
    }
    return $false
}

# =========================================
# SCRIPT PRINCIPAL
# =========================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " PDF-TOOL - Preparação Image Tools" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Verificar arquitetura
$arch = $env:PROCESSOR_ARCHITECTURE
Write-Host "Arquitetura do sistema: $arch" -ForegroundColor Cyan
if ($arch -ne "AMD64") {
    Write-Host "⚠️  Sistema não é 64-bit. Pode haver problemas de compatibilidade." -ForegroundColor Yellow
}

$THIRD_PARTY_DIR = "third_party_full"
$BASE_DIR = Get-Location

if (-not (Test-Path $THIRD_PARTY_DIR)) {
    New-Item -ItemType Directory -Path $THIRD_PARTY_DIR -Force | Out-Null
}
Set-Location $THIRD_PARTY_DIR

# Instalar Poppler
$poppler_ok = Install-Tool `
    -Name "Poppler" `
    -Url "https://github.com/oschwartz10612/poppler-windows/releases/download/v24.03.0/poppler-24.03.0_x86.zip" `
    -AltUrl "https://github.com/oschwartz10612/poppler-windows/releases/download/v23.11.0/poppler-23.11.0_x86.zip" `
    -TargetDir "poppler" `
    -ExecutablePath "Library/bin/pdftoppm.exe" `
    -ChocoPackage "poppler" `
    -SpecialExtraction

# Instalar ImageMagick
$imagemagick_ok = Install-Tool `
    -Name "ImageMagick" `
    -Url "https://imagemagick.org/archive/binaries/ImageMagick-7.1.1-35-portable-Q16-x86.zip" `
    -AltUrl "https://imagemagick.org/archive/binaries/ImageMagick-7.1.1-34-portable-Q16-x86.zip" `
    -TargetDir "imagemagick" `
    -ExecutablePath "convert.exe" `
    -ChocoPackage "imagemagick.tool"

# =====================================
# 3. img2pdf (será instalado via pip)
# =====================================

Write-Host "`n📦 img2pdf será instalado via pip (requirements.txt)" -ForegroundColor Cyan

# =====================================
# Resumo final
# =====================================

Set-Location $BASE_DIR

Write-Host "`n" -NoNewline
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " RESUMO FINAL - Image Tools" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Usar caminhos absolutos para verificação
$poppler_path = Join-Path $BASE_DIR "third_party_full/poppler/Library/bin/pdftoppm.exe"
$imagemagick_path = Join-Path $BASE_DIR "third_party_full/imagemagick/convert.exe"

# Verifica o Poppler instalado via choco em um caminho padrão
$choco_poppler_path = "C:/ProgramData/chocolatey/bin/pdftoppm.exe"

$poppler_status = if ((Test-Path $poppler_path) -or (Test-Path $choco_poppler_path)) { "✅ OK" } else { "❌ FALTANDO" }
$imagemagick_status = if (Test-Path $imagemagick_path) { "✅ OK" } else { "❌ FALTANDO" }

Write-Host "Poppler (pdftoppm): $poppler_status"
Write-Host "ImageMagick: $imagemagick_status"

$total_ok = 0
if ($poppler_status -like "*OK*") { $total_ok++ }
if ($imagemagick_status -like "*OK*") { $total_ok++ }

Write-Host "`nStatus geral: $total_ok/2 ferramentas configuradas" -ForegroundColor $(if ($total_ok -eq 2) { "Green" } else { "Yellow" })

if ($total_ok -eq 2) {
    Write-Host "🎉 Todas as ferramentas de imagem estão prontas!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Algumas ferramentas faltando - PDF recovery pode ser limitado" -ForegroundColor Yellow
}