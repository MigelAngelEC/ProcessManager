# Bootstrap.ps1 - ConfiguraciÃ³n inicial y arranque de la aplicaciÃ³n
using namespace System.Collections.Generic

# Importar el contenedor DI
. "$PSScriptRoot\Container.ps1"

class ApplicationBootstrap {
    hidden [ServiceProvider]$serviceProvider
    hidden [hashtable]$configuration
    hidden [string]$environment

    ApplicationBootstrap() {
        $this.environment = $this.DetectEnvironment()
        $this.configuration = @{}
    }

    # Detectar el entorno de ejecuciÃ³n
    hidden [string] DetectEnvironment() {
        if ($env:PROCESSMANAGER_ENVIRONMENT) {
            return $env:PROCESSMANAGER_ENVIRONMENT
        }

        if ($env:COMPUTERNAME -match "-DEV$") {
            return "Development"
        }

        return "Production"
    }

    # Configurar servicios
    [void] ConfigureServices([ServiceCollection]$services) {
        Write-Verbose "Configurando servicios para entorno: $($this.environment)"

        # ConfiguraciÃ³n base
        $configPath = $this.GetConfigurationPath()

        # Registrar servicios bÃ¡sicos
        $services.AddLogging()
        $services.AddConfiguration($configPath)
        $services.AddProcessServices()

        # Registrar ViewModels
        $this.RegisterViewModels($services)

        # Registrar servicios de infraestructura
        $this.RegisterInfrastructureServices($services)

        # Servicios especÃ­ficos del entorno
        if ($this.environment -eq "Development") {
            $this.ConfigureDevelopmentServices($services)
        }
    }

    # Obtener ruta de configuraciÃ³n segÃºn el entorno
    hidden [string] GetConfigurationPath() {
        $basePath = Join-Path $PSScriptRoot "..\..\config"

        switch ($this.environment) {
            "Development" {
                $envConfig = Join-Path $basePath "appsettings.Development.json"
                if (Test-Path $envConfig) {
                    return $envConfig
                }
            }
            "Production" {
                $envConfig = Join-Path $basePath "appsettings.Production.json"
                if (Test-Path $envConfig) {
                    return $envConfig
                }
            }
        }

        # ConfiguraciÃ³n por defecto
        return Join-Path $basePath "ProcessConfig.json"
    }

    # Registrar ViewModels
    hidden [void] RegisterViewModels([ServiceCollection]$services) {
        # Importar ViewModels
        . "$PSScriptRoot\..\Presentation\ViewModels\BaseViewModel.ps1"

        # MainViewModel se registrarÃ¡ cuando se implemente
        # $services.AddTransient([MainViewModel], [MainViewModel])
    }

    # Registrar servicios de infraestructura
    hidden [void] RegisterInfrastructureServices([ServiceCollection]$services) {
        # Importar servicios de Windows
        . "$PSScriptRoot\..\Infrastructure\Windows\WindowsProcessManager.ps1"

        $services.AddSingleton([WindowsProcessManager], [WindowsProcessManager])
    }

    # ConfiguraciÃ³n especÃ­fica para desarrollo
    hidden [void] ConfigureDevelopmentServices([ServiceCollection]$services) {
        # En desarrollo, usar un logger mÃ¡s detallado
        . "$PSScriptRoot\..\Core\Utilities\Logger.ps1"

        $services.AddSingleton([ILogger], {
                param($provider)
                [ConsoleLogger]::new([LogLevel]::Debug)
            })
    }

    # Construir la aplicaciÃ³n
    [ServiceProvider] Build() {
        $services = [ServiceCollection]::new()
        $this.ConfigureServices($services)

        $this.serviceProvider = $services.BuildServiceProvider()

        # Validar servicios crÃ­ticos
        $this.ValidateServices()

        return $this.serviceProvider
    }

    # Validar que los servicios crÃ­ticos estÃ©n disponibles
    hidden [void] ValidateServices() {
        $criticalServices = @(
            [ILogger],
            [IConfigurationService],
            [Configuration],
            [IProcessService],
            [IServiceManager]
        )

        foreach ($serviceType in $criticalServices) {
            try {
                $this.serviceProvider.GetRequiredService($serviceType) | Out-Null
                Write-Verbose "âœ“ Servicio validado: $($serviceType.Name)"
            }
            catch {
                throw "Error validando servicio crÃ­tico $($serviceType.Name): $_"
            }
        }
    }

    # Inicializar la aplicaciÃ³n
    [void] Initialize() {
        Write-Host "Inicializando Process Manager..." -ForegroundColor Green
        Write-Host "Entorno: $($this.environment)" -ForegroundColor Cyan

        # Obtener logger
        $logger = $this.serviceProvider.GetRequiredService([ILogger])
        $logger.LogInformation("AplicaciÃ³n iniciada en modo $($this.environment)")

        # Cargar configuraciÃ³n
        $config = $this.serviceProvider.GetRequiredService([Configuration])
        $logger.LogInformation("ConfiguraciÃ³n cargada: v$($config.Version)")
        $logger.LogInformation("CategorÃ­as disponibles: $($config.Categories.Count)")

        # Verificar servicios de Windows si es necesario
        if ($this.environment -eq "Production") {
            $this.CheckWindowsServices($logger)
        }
    }

    # Verificar servicios de Windows necesarios
    hidden [void] CheckWindowsServices([ILogger]$logger) {
        try {
            $serviceManager = $this.serviceProvider.GetRequiredService([IServiceManager])

            # Verificar que no estamos ejecutando como servicio del sistema
            $currentProcess = Get-Process -Id $PID
            if ($currentProcess.SessionId -eq 0) {
                $logger.LogWarning("Ejecutando como servicio del sistema - algunas funciones pueden estar limitadas")
            }
        }
        catch {
            $logger.LogError("Error verificando servicios de Windows", $_)
        }
    }

    # MÃ©todo estÃ¡tico para crear y configurar la aplicaciÃ³n
    static [ServiceProvider] CreateApplication() {
        $bootstrap = [ApplicationBootstrap]::new()
        $provider = $bootstrap.Build()
        $bootstrap.Initialize()
        return $provider
    }

    # MÃ©todo para ejecutar la aplicaciÃ³n
    [void] Run() {
        try {
            # El punto de entrada principal se implementarÃ¡ cuando tengamos la UI
            Write-Host "Process Manager estÃ¡ listo para ejecutar" -ForegroundColor Green

            # Por ahora, mostrar informaciÃ³n de configuraciÃ³n
            $config = $this.serviceProvider.GetRequiredService([Configuration])
            Write-Host "`nCategorÃ­as configuradas:" -ForegroundColor Yellow

            foreach ($categoryName in $config.Categories.Keys) {
                $category = $config.Categories[$categoryName]
                Write-Host "  - $categoryName`: $($category.ProcessPatterns.Count) procesos" -ForegroundColor Cyan
            }
        }
        catch {
            $logger = $this.serviceProvider.GetService([ILogger])
            if ($logger) {
                $logger.LogCritical("Error fatal en la aplicaciÃ³n", $_)
            }
            else {
                Write-Error "Error fatal: $_"
            }
            throw
        }
    }
}

# FunciÃ³n helper para arranque rÃ¡pido
function Start-ProcessManager {
    param(
        [switch]$Debug
    )

    if ($Debug) {
        $env:PROCESSMANAGER_ENVIRONMENT = "Development"
    }

    try {
        $app = [ApplicationBootstrap]::CreateApplication()
        return $app
    }
    catch {
        Write-Error "Error iniciando Process Manager: $_"
        throw
    }
}
