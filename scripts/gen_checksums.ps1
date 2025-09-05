# Script para gerar ou verificar checksums SHA256 para os arquivos em um diretório.

param(
    [string]$Folder = ".",
    [switch]$Verify
)

$targetFolder = (Resolve-Path $Folder).Path
$hashFile = Join-Path $targetFolder "CHECKSUMS.txt"

function Generate-Checksums {
    Write-Host "Gerando checksums SHA256 para arquivos em $targetFolder..." -ForegroundColor Yellow
    
    $filesToHash = Get-ChildItem -Path $targetFolder -File -Exclude "CHECKSUMS.txt"
    
    if ($null -eq $filesToHash) {
        Write-Host "Nenhum arquivo para processar." -ForegroundColor Green
        return
    }

    $checksums = foreach ($file in $filesToHash) {
        $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
        "{0}  {1}" -f $hash.Hash.ToLower(), $file.Name
    }
    
    $checksums | Out-File -Encoding UTF8 -FilePath $hashFile
    
    Write-Host "Arquivo de checksums gerado: $hashFile" -ForegroundColor Green
}

function Verify-Checksums {
    if (-not (Test-Path $hashFile)) {
        Write-Error "Arquivo CHECKSUMS.txt não encontrado em $targetFolder."
        return
    }

    Write-Host "Verificando checksums em $targetFolder usando $hashFile..." -ForegroundColor Yellow
    $mismatches = 0

    Get-Content $hashFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and $line -match "^([a-f0-9]{64})\s{2}(.+)") {
            $expectedHash = $matches[1]
            $fileName = $matches[2]
            $filePath = Join-Path $targetFolder $fileName

            if (-not (Test-Path $filePath)) {
                Write-Warning "ARQUIVO NÃO ENCONTRADO: $fileName"
                $mismatches++
                return
            }

            $calculatedHash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLower()

            if ($calculatedHash -ne $expectedHash) {
                Write-Host "[FALHA] $fileName" -ForegroundColor Red
                $mismatches++
            } else {
                Write-Host "[OK]      $fileName" -ForegroundColor Green
            }
        }
    }

    Write-Host "`nVerificação concluída." -ForegroundColor Yellow
    if ($mismatches -eq 0) {
        Write-Host "Todos os arquivos foram verificados com sucesso." -ForegroundColor Green
    } else {
        Write-Error "$mismatches arquivo(s) com erro de checksum ou não encontrado(s)."
    }
}

if ($Verify) {
    Verify-Checksums
} else {
    Generate-Checksums
}