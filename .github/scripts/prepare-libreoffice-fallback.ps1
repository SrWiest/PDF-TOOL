#!/usr/bin/env pwsh
# Script de fallback para preparar LibreOffice quando o método principal falha

param(
    [string]$OutputDir = "third_party_full/libreoffice"
)

$ErrorActionPreference = "Stop"

Write-Host "=== LibreOffice Fallback Preparation ===" -ForegroundColor Yellow

# Método simplificado de fallback
try {
    Write-Host "Tentando instalar LibreOffice via Chocolatey..." -ForegroundColor Cyan

    # Instalar Chocolatey se necessário
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Instalando Chocolatey..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }

    # Instalar LibreOffice
    choco install libreoffice-fresh --yes --no-progress --force

    # Verificar instalação
    $libreOfficePath = "${env:ProgramFiles}\LibreOffice\program\soffice.exe"
    if (Test-Path $libreOfficePath) {
        Write-Host "✅ LibreOffice instalado com sucesso via Chocolatey" -ForegroundColor Green

        # Copiar para o diretório do projeto
        $destDir = Join-Path $PWD $OutputDir
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        }

        Copy-Item -Path "${env:ProgramFiles}\LibreOffice\*" -Destination $destDir -Recurse -Force
        Write-Host "✅ LibreOffice copiado para: $destDir" -ForegroundColor Green
    } else {
        Write-Host "❌ soffice.exe não encontrado após instalação" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Host "❌ Falha no fallback do LibreOffice: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "O build continuará sem LibreOffice" -ForegroundColor Yellow
    exit 0
}
