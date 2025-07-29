# Script to fix line endings in PowerShell files
$files = @(
    'src/core/ConfigManager.ps1',
    'src/core/ProcessManagerModular.ps1', 
    'src/legacy/ProcessManager.ps1',
    'src/legacy/ProcessManagerSimple.ps1'
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "Fixing line endings in: $file"
        try {
            $content = Get-Content $file -Raw
            # Normalize to CRLF (Windows standard)
            $content = $content -replace "`r`n", "`n"  # First convert all CRLF to LF
            $content = $content -replace "`r", "`n"    # Convert any CR to LF
            $content = $content -replace "`n", "`r`n"  # Finally convert all LF to CRLF
            
            [System.IO.File]::WriteAllText((Resolve-Path $file).Path, $content)
            Write-Host "  Fixed!" -ForegroundColor Green
        } catch {
            Write-Warning "  Error fixing $file : $_"
        }
    } else {
        Write-Warning "$file not found"
    }
}

Write-Host "`nDone fixing line endings!" -ForegroundColor Green