# Run-Lint.ps1 - Script para ejecutar PSScriptAnalyzer

param(
    [string]$Path = "./src",
    [string]$SettingsFile = "./PSScriptAnalyzerSettings.psd1"
)

# Importar PSScriptAnalyzer
Import-Module PSScriptAnalyzer -ErrorAction Stop

Write-Host "Running PSScriptAnalyzer..." -ForegroundColor Yellow

$results = Invoke-ScriptAnalyzer -Path $Path -Recurse -Settings $SettingsFile

if ($results) {
    # Separar por severidad
    $errors = $results | Where-Object { $_.Severity -eq 'Error' }
    $warnings = $results | Where-Object { $_.Severity -eq 'Warning' }
    $information = $results | Where-Object { $_.Severity -eq 'Information' }
    
    # Mostrar resumen
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  Errors: $($errors.Count)" -ForegroundColor Red
    Write-Host "  Warnings: $($warnings.Count)" -ForegroundColor Yellow
    Write-Host "  Information: $($information.Count)" -ForegroundColor Blue
    Write-Host ""
    
    # Mostrar errores primero
    if ($errors) {
        Write-Host "ERRORS:" -ForegroundColor Red
        $errors | Format-Table -Property ScriptName, Line, Column, RuleName, Message -AutoSize -Wrap
    }
    
    # Luego warnings
    if ($warnings) {
        Write-Host "`nWARNINGS:" -ForegroundColor Yellow
        $warnings | Format-Table -Property ScriptName, Line, Column, RuleName, Message -AutoSize -Wrap
    }
    
    # Finalmente información
    if ($information) {
        Write-Host "`nINFORMATION:" -ForegroundColor Blue
        $information | Format-Table -Property ScriptName, Line, Column, RuleName, Message -AutoSize -Wrap
    }
    
    # Exit con código de error si hay errores
    if ($errors) {
        exit 1
    }
} else {
    Write-Host "No issues found!" -ForegroundColor Green
}