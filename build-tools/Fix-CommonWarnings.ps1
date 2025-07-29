# Fix-CommonWarnings.ps1 - Script para corregir warnings comunes

param(
    [string]$Path = "./src"
)

Write-Host "Fixing common warnings..." -ForegroundColor Yellow

# Obtener todos los archivos PowerShell
$files = Get-ChildItem -Path $Path -Filter '*.ps1' -Recurse

$fixedFiles = 0

foreach ($file in $files) {
    $fixed = $false
    $content = Get-Content -Path $file.FullName -Raw
    
    # Remover trailing whitespace
    $newContent = $content -replace '[ \t]+(\r?\n)', '$1'
    $newContent = $newContent -replace '[ \t]+$', ''
    
    if ($newContent -ne $content) {
        $fixed = $true
    }
    
    # Asegurar que no hay líneas vacías múltiples
    $newContent = $newContent -replace '(\r?\n){3,}', '$1$1'
    
    # Asegurar nueva línea al final del archivo
    if (-not $newContent.EndsWith("`n")) {
        $newContent += "`n"
    }
    
    # Guardar con BOM UTF-8
    if ($fixed -or $content -ne $newContent) {
        $utf8WithBom = New-Object System.Text.UTF8Encoding $true
        [System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8WithBom)
        Write-Host "  Fixed: $($file.Name)" -ForegroundColor Gray
        $fixedFiles++
    }
}

Write-Host "Fixed $fixedFiles file(s)" -ForegroundColor Green

# Ahora arreglar algunos warnings específicos
Write-Host "`nFixing specific warnings..." -ForegroundColor Yellow

# Fix unused variables and parameters
$specificFixes = @{
    "Bootstrap.ps1" = @{
        130 = {
            # Remover la variable $service no usada
            $content = Get-Content -Path $args[0] -Raw
            $content = $content -replace '\$service = \$this\.serviceProvider\.GetRequiredService\(\$serviceType\)\s*\n\s*Write-Verbose "✓ Servicio validado: \$\(\$serviceType\.Name\)"', 
                                      '$this.serviceProvider.GetRequiredService($serviceType) | Out-Null
                Write-Verbose "✓ Servicio validado: $($serviceType.Name)"'
            [System.IO.File]::WriteAllText($args[0], $content, [System.Text.UTF8Encoding]::new($true))
        }
    }
}

foreach ($fileName in $specificFixes.Keys) {
    $filePath = Get-ChildItem -Path $Path -Filter $fileName -Recurse | Select-Object -First 1
    if ($filePath) {
        foreach ($fix in $specificFixes[$fileName].Values) {
            & $fix $filePath.FullName
            Write-Host "  Applied specific fix to: $fileName" -ForegroundColor Gray
        }
    }
}

Write-Host "`nAll common warnings fixed!" -ForegroundColor Green