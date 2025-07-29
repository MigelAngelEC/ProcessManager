# ProcessManager.ps1 - Launcher principal
#Requires -Version 5.1

<#
.SYNOPSIS
    Process Manager Pro - Sistema modular de gestión de procesos
.DESCRIPTION
    Herramienta avanzada para gestionar procesos del sistema Windows
    con arquitectura modular y patrones de diseño modernos.
.PARAMETER Mode
    Modo de ejecución: GUI (predeterminado), Console, o Service
.PARAMETER Debug
    Activa el modo debug con logs detallados
.PARAMETER ConfigFile
    Ruta a un archivo de configuración personalizado
.EXAMPLE
    .\ProcessManager.ps1
    Ejecuta en modo GUI (interfaz gráfica)
.EXAMPLE
    .\ProcessManager.ps1 -Mode Console -Debug
    Ejecuta en modo consola con debug activado
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("GUI", "Console", "Service")]
    [string]$Mode = "GUI",
    
    [Parameter()]
    [switch]$Debug,
    
    [Parameter()]
    [switch]$NoLogo,
    
    [Parameter()]
    [string]$ConfigFile,
    
    [Parameter()]
    [switch]$Help
)

# Verificar privilegios de administrador
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "Process Manager requiere privilegios de administrador."
    
    # Intentar reiniciar con privilegios elevados
    $arguments = @()
    
    if ($Mode) { $arguments += "-Mode $Mode" }
    if ($Debug) { $arguments += "-Debug" }
    if ($NoLogo) { $arguments += "-NoLogo" }
    if ($ConfigFile) { $arguments += "-ConfigFile '$ConfigFile'" }
    if ($Help) { $arguments += "-Help" }
    
    $argumentString = $arguments -join " "
    
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" $argumentString" -Verb RunAs
    }
    catch {
        Write-Error "No se pudo elevar privilegios: $_"
        exit 1
    }
    
    exit
}

# Cambiar al directorio del script
Set-Location -Path $PSScriptRoot

# Verificar que existe la nueva estructura
$appPath = Join-Path $PSScriptRoot "src\Application\ProcessManager.ps1"

if (-not (Test-Path $appPath)) {
    Write-Error "No se encuentra la aplicación en: $appPath"
    Write-Error "Asegúrese de que la nueva arquitectura esté correctamente instalada."
    
    # Ofrecer ejecutar la versión legacy si existe
    $legacyPath = Join-Path $PSScriptRoot "src\legacy\ProcessManager.ps1"
    if (Test-Path $legacyPath) {
        Write-Warning "Se encontró una versión legacy del sistema."
        $useLegacy = Read-Host "¿Desea ejecutar la versión legacy? (S/N)"
        
        if ($useLegacy -eq "S") {
            & $legacyPath
            exit
        }
    }
    
    exit 1
}

# Pasar todos los parámetros a la aplicación principal
$params = @{}

if ($Mode) { $params.Mode = $Mode }
if ($Debug) { $params.Debug = $Debug }
if ($NoLogo) { $params.NoLogo = $NoLogo }
if ($ConfigFile) { $params.ConfigFile = $ConfigFile }
if ($Help) { $params.Help = $Help }

# Ejecutar la aplicación
try {
    & $appPath @params
}
catch {
    Write-Error "Error ejecutando Process Manager: $_"
    
    if ($Debug) {
        Write-Error $_.Exception.StackTrace
    }
    
    # En caso de error, pausar para que el usuario pueda ver el mensaje
    Write-Host "`nPresione cualquier tecla para salir..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    exit 1
}