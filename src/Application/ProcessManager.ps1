# ProcessManager.ps1 - Punto de entrada principal de la aplicaciÃ³n
#Requires -Version 5.1
#Requires -RunAsAdministrator

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

# Configurar el entorno
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Establecer la ubicaciÃ³n del script
Set-Location -Path $PSScriptRoot

# Importar Bootstrap
. "$PSScriptRoot\Bootstrap.ps1"

# FunciÃ³n para mostrar el logo
function Show-Logo {
    if (-not $NoLogo) {
        $logo = @"
â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
â•‘                                                               â•‘
â•‘    â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—  â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—  â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â•‘
â•‘    â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â• â•‘
â•‘    â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—  â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â•‘
â•‘    â–ˆâ–ˆâ•”â•â•â•â• â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•”â•â•â•  â•šâ•â•â•â•â–ˆâ–ˆâ•‘â•šâ•â•â•â•â–ˆâ–ˆâ•‘ â•‘
â•‘    â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•‘ â•‘
â•‘    â•šâ•â•     â•šâ•â•  â•šâ•â• â•šâ•â•â•â•â•â•  â•šâ•â•â•â•â•â•â•šâ•â•â•â•â•â•â•â•šâ•â•â•â•â•â•â•â•šâ•â•â•â•â•â•â• â•‘
â•‘                                                               â•‘
â•‘              MANAGER PRO v2.0 - Nueva Arquitectura            â•‘
â•‘                                                               â•‘
â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
"@
        Write-Host $logo -ForegroundColor Cyan
        Write-Host ""
    }
}

# FunciÃ³n para mostrar ayuda
function Show-Help {
    Write-Host "Process Manager Pro - Sistema de gestiÃ³n de procesos" -ForegroundColor Green
    Write-Host ""
    Write-Host "Uso:" -ForegroundColor Yellow
    Write-Host "  ProcessManager.ps1 [-Mode <GUI|Console|Service>] [-Debug] [-NoLogo] [-ConfigFile <path>]"
    Write-Host ""
    Write-Host "ParÃ¡metros:" -ForegroundColor Yellow
    Write-Host "  -Mode        : Modo de ejecuciÃ³n (GUI por defecto)"
    Write-Host "                 GUI     = Interfaz grÃ¡fica"
    Write-Host "                 Console = Modo consola"
    Write-Host "                 Service = Ejecutar como servicio"
    Write-Host "  -Debug       : Habilitar modo debug con logs detallados"
    Write-Host "  -NoLogo      : No mostrar el logo al iniciar"
    Write-Host "  -ConfigFile  : Ruta a archivo de configuraciÃ³n personalizado"
    Write-Host "  -Help        : Mostrar esta ayuda"
    Write-Host ""
    Write-Host "Ejemplos:" -ForegroundColor Yellow
    Write-Host "  .\ProcessManager.ps1"
    Write-Host "  .\ProcessManager.ps1 -Mode Console -Debug"
    Write-Host "  .\ProcessManager.ps1 -ConfigFile 'C:\config\custom.json'"
    Write-Host ""
}

# FunciÃ³n principal
function Main {
    try {
        # Mostrar ayuda si se solicita
        if ($Help) {
            Show-Help
            return
        }

        # Mostrar logo
        Show-Logo

        # Configurar entorno de debug si es necesario
        if ($Debug) {
            $env:PROCESSMANAGER_ENVIRONMENT = "Development"
            $VerbosePreference = "Continue"
            Write-Host "Modo DEBUG activado" -ForegroundColor Yellow
        }

        # Configurar archivo de configuraciÃ³n personalizado si se proporciona
        if ($ConfigFile) {
            if (Test-Path $ConfigFile) {
                $env:PROCESSMANAGER_CONFIG = $ConfigFile
                Write-Host "Usando configuraciÃ³n personalizada: $ConfigFile" -ForegroundColor Green
            } else {
                Write-Error "Archivo de configuraciÃ³n no encontrado: $ConfigFile"
                return
            }
        }

        # Crear y configurar la aplicaciÃ³n
        Write-Host "Inicializando aplicaciÃ³n..." -ForegroundColor Cyan
        $bootstrap = [ApplicationBootstrap]::new()
        $serviceProvider = $bootstrap.Build()

        # Obtener logger
        $logger = $serviceProvider.GetRequiredService([ILogger])
        $logger.LogInformation("Process Manager iniciado en modo: $Mode")

        # Ejecutar segÃºn el modo seleccionado
        switch ($Mode) {
            "GUI" {
                Start-GUIMode -ServiceProvider $serviceProvider -Logger $logger
            }
            "Console" {
                Start-ConsoleMode -ServiceProvider $serviceProvider -Logger $logger
            }
            "Service" {
                Start-ServiceMode -ServiceProvider $serviceProvider -Logger $logger
            }
        }
    } catch {
        Write-Error "Error fatal en la aplicaciÃ³n: $_"

        if ($Debug) {
            Write-Error $_.Exception.StackTrace
        }

        # Pausar antes de cerrar en caso de error
        Write-Host "`nPresione cualquier tecla para salir..." -ForegroundColor Red
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        exit 1
    }
}

# Modo GUI
function Start-GUIMode {
    param(
        [Parameter(Mandatory)]
        $ServiceProvider,

        [Parameter(Mandatory)]
        $Logger
    )

    $Logger.LogInformation("Iniciando modo GUI...")

    # TODO: Implementar la UI principal cuando se cree MainWindow.ps1
    Write-Host "NOTA: La interfaz grÃ¡fica se implementarÃ¡ prÃ³ximamente" -ForegroundColor Yellow
    Write-Host "Por ahora, ejecutando en modo demo..." -ForegroundColor Yellow

    # Demo: Mostrar procesos por categorÃ­a
    Show-ProcessDemo -ServiceProvider $ServiceProvider
}

# Modo Consola
function Start-ConsoleMode {
    param(
        [Parameter(Mandatory)]
        $ServiceProvider,

        [Parameter(Mandatory)]
        $Logger
    )

    $Logger.LogInformation("Iniciando modo consola...")

    # MenÃº de consola simple
    $running = $true

    while ($running) {
        Clear-Host
        Write-Host "=== Process Manager Pro - Modo Consola ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Listar procesos por categorÃ­a" -ForegroundColor Green
        Write-Host "2. Buscar proceso" -ForegroundColor Green
        Write-Host "3. Cerrar procesos seleccionados" -ForegroundColor Green
        Write-Host "4. Ver estadÃ­sticas de memoria" -ForegroundColor Green
        Write-Host "5. Recargar configuraciÃ³n" -ForegroundColor Green
        Write-Host "0. Salir" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "Seleccione una opciÃ³n"

        switch ($choice) {
            "1" { Show-ProcessesByCategory -ServiceProvider $ServiceProvider }
            "2" { Search-Process -ServiceProvider $ServiceProvider }
            "3" { Kill-SelectedProcesses -ServiceProvider $ServiceProvider }
            "4" { Show-MemoryStats -ServiceProvider $ServiceProvider }
            "5" { Reload-Configuration -ServiceProvider $ServiceProvider }
            "0" { $running = $false }
            default { Write-Host "OpciÃ³n no vÃ¡lida" -ForegroundColor Red }
        }

        if ($running -and $choice -ne "0") {
            Write-Host "`nPresione cualquier tecla para continuar..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }

    $Logger.LogInformation("AplicaciÃ³n cerrada por el usuario")
}

# Modo Servicio
function Start-ServiceMode {
    param(
        [Parameter(Mandatory)]
        $ServiceProvider,

        [Parameter(Mandatory)]
        $Logger
    )

    $Logger.LogInformation("Modo servicio no implementado aÃºn")
    Write-Host "El modo servicio se implementarÃ¡ en una versiÃ³n futura" -ForegroundColor Yellow
}

# Funciones auxiliares para el modo consola
function Show-ProcessesByCategory {
    param($ServiceProvider)

    $processService = $ServiceProvider.GetRequiredService([IProcessService])
    $config = $ServiceProvider.GetRequiredService([Configuration])

    foreach ($categoryName in $config.Categories.Keys) {
        $category = $config.Categories[$categoryName]
        Write-Host "`n=== $categoryName ===" -ForegroundColor Yellow
        Write-Host $category.Description -ForegroundColor Gray

        $processes = $processService.GetProcessesByCategory($category)

        if ($processes.Count -eq 0) {
            Write-Host "  No hay procesos en ejecuciÃ³n" -ForegroundColor DarkGray
        } else {
            $totalMemory = ($processes | Measure-Object -Property MemoryMB -Sum).Sum
            Write-Host "  Total: $($processes.Count) procesos - $([Math]::Round($totalMemory, 2)) MB" -ForegroundColor Cyan

            foreach ($proc in $processes | Select-Object -First 5) {
                Write-Host "    - $($proc.Name) (PID: $($proc.Id)) - $($proc.MemoryMB) MB"
            }

            if ($processes.Count -gt 5) {
                Write-Host "    ... y $($processes.Count - 5) mÃ¡s" -ForegroundColor DarkGray
            }
        }
    }
}

function Show-ProcessDemo {
    param($ServiceProvider)

    Write-Host "`nDemo: Mostrando procesos por categorÃ­a..." -ForegroundColor Cyan
    Show-ProcessesByCategory -ServiceProvider $ServiceProvider

    Write-Host "`nPresione cualquier tecla para salir..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-MemoryStats {
    param($ServiceProvider)

    $processService = $ServiceProvider.GetRequiredService([IProcessService])
    $stats = $processService.GetMemoryStatistics()

    Write-Host "`n=== EstadÃ­sticas de Memoria ===" -ForegroundColor Yellow
    Write-Host "Total de procesos: $($stats.TotalProcesses)" -ForegroundColor Cyan
    Write-Host "Memoria total en uso: $([Math]::Round($stats.TotalMemoryMB, 2)) MB" -ForegroundColor Cyan
    Write-Host "Memoria promedio por proceso: $([Math]::Round($stats.AverageMemoryMB, 2)) MB" -ForegroundColor Cyan

    if ($null -ne $stats.LargestProcess) {
        Write-Host "`nProceso con mÃ¡s memoria:" -ForegroundColor Yellow
        Write-Host "  $($stats.LargestProcess.Name) - $($stats.LargestProcess.MemoryMB) MB" -ForegroundColor Red
    }

    Write-Host "`nMemoria por categorÃ­a:" -ForegroundColor Yellow
    foreach ($category in $stats.CategoriesStats.Keys | Sort-Object) {
        $catStats = $stats.CategoriesStats[$category]
        Write-Host "  $category`: $($catStats.Count) procesos - $([Math]::Round($catStats.TotalMemoryMB, 2)) MB"
    }
}

# Ejecutar la aplicaciÃ³n
Main
