# Format-Code.ps1 - Script para formatear código PowerShell

param(
    [string]$Path = "./src",
    [string]$SettingsFile = "./PSScriptAnalyzerSettings.psd1"
)

# Importar PSScriptAnalyzer
Import-Module PSScriptAnalyzer -ErrorAction Stop

Write-Host "Formatting PowerShell files..." -ForegroundColor Yellow

$files = Get-ChildItem -Path $Path -Filter '*.ps1' -Recurse
$formatted = 0

foreach ($file in $files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        
        if ([string]::IsNullOrWhiteSpace($content)) {
            continue
        }
        
        $newContent = Invoke-Formatter -ScriptDefinition $content -Settings $SettingsFile
        
        if ($newContent -ne $content) {
            Set-Content -Path $file.FullName -Value $newContent -NoNewline
            Write-Host "  Formatted: $($file.Name)" -ForegroundColor Gray
            $formatted++
        }
    }
    catch {
        Write-Warning "Error formatting $($file.Name): $_"
    }
}

if ($formatted -gt 0) {
    Write-Host "Formatted $formatted file(s)" -ForegroundColor Green
} else {
    Write-Host "All files already formatted" -ForegroundColor Green
}