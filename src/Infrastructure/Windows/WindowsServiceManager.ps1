# WindowsServiceManager.ps1 - ImplementaciÃ³n para manejo de servicios de Windows
using namespace System.Collections.Generic
using namespace System.ServiceProcess

# Cargar dependencias
. "$PSScriptRoot\..\..\Core\Services\IProcessService.ps1"

class WindowsServiceManager : IServiceManager {
    hidden [hashtable]$ServiceCache
    hidden [DateTime]$LastCacheUpdate
    hidden [int]$CacheTimeout = 10000  # 10 segundos

    WindowsServiceManager() {
        $this.ServiceCache = @{}
        $this.LastCacheUpdate = [DateTime]::MinValue
    }

    [List[hashtable]] GetRelatedServices([List[string]]$serviceNames) {
        $services = [List[hashtable]]::new()

        if ($null -eq $serviceNames -or $serviceNames.Count -eq 0) {
            return $services
        }

        foreach ($serviceName in $serviceNames) {
            try {
                $service = $this.GetServiceInfo($serviceName)
                if ($null -ne $service) {
                    $services.Add($service)
                }
            } catch {
                Write-Verbose "Error obteniendo servicio $serviceName : $_"
            }
        }

        return $services
    }

    [bool] StopService([string]$serviceName) {
        try {
            # Verificar si el servicio existe
            $service = Get-Service -Name $serviceName -ErrorAction Stop

            # Verificar si ya estÃ¡ detenido
            if ($service.Status -eq [ServiceControllerStatus]::Stopped) {
                Write-Verbose "El servicio $serviceName ya estÃ¡ detenido"
                return $true
            }

            # Verificar si se puede detener
            if (-not $service.CanStop) {
                Write-Warning "El servicio $serviceName no se puede detener"
                return $false
            }

            # Intentar detener el servicio
            Write-Verbose "Deteniendo servicio $serviceName..."
            Stop-Service -Name $serviceName -Force -ErrorAction Stop

            # Esperar hasta que se detenga (mÃ¡ximo 30 segundos)
            $timeout = 30
            $elapsed = 0

            while ($service.Status -ne [ServiceControllerStatus]::Stopped -and $elapsed -lt $timeout) {
                Start-Sleep -Milliseconds 500
                $elapsed += 0.5
                $service.Refresh()
            }

            # Limpiar cachÃ©
            if ($this.ServiceCache.ContainsKey($serviceName)) {
                $this.ServiceCache.Remove($serviceName)
            }

            return $service.Status -eq [ServiceControllerStatus]::Stopped
        } catch {
            Write-Error "Error deteniendo servicio $serviceName : $_"
            return $false
        }
    }

    [string] GetServiceStatus([string]$serviceName) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop
            return $service.Status.ToString()
        } catch {
            return "NotFound"
        }
    }

    [bool] IsServiceProtected([string]$serviceName) {
        # Lista de servicios crÃ­ticos del sistema que no deben detenerse
        $protectedServices = @(
            "BITS",           # Background Intelligent Transfer Service
            "CryptSvc",       # Cryptographic Services
            "DcomLaunch",     # DCOM Server Process Launcher
            "Dhcp",           # DHCP Client
            "Dnscache",       # DNS Client
            "EventLog",       # Windows Event Log
            "LanmanServer",   # Server
            "LanmanWorkstation", # Workstation
            "PlugPlay",       # Plug and Play
            "Power",          # Power
            "ProfSvc",        # User Profile Service
            "RpcEptMapper",   # RPC Endpoint Mapper
            "RpcSs",          # Remote Procedure Call (RPC)
            "SamSs",          # Security Accounts Manager
            "Schedule",       # Task Scheduler
            "SecurityHealthService", # Windows Security Service
            "Themes",         # Themes
            "WinDefend",      # Windows Defender Antivirus Service
            "Winmgmt",        # Windows Management Instrumentation
            "WlanSvc",        # WLAN AutoConfig
            "wuauserv"        # Windows Update
        )

        return $serviceName -in $protectedServices
    }

    # Obtener informaciÃ³n detallada del servicio
    [hashtable] GetServiceInfo([string]$serviceName) {
        # Verificar cachÃ©
        if ($this.ServiceCache.ContainsKey($serviceName) -and
            ([DateTime]::Now - $this.LastCacheUpdate).TotalMilliseconds -lt $this.CacheTimeout) {
            return $this.ServiceCache[$serviceName]
        }

        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop
            $wmiService = Get-WmiObject Win32_Service -Filter "Name = '$serviceName'" -ErrorAction Stop

            $serviceInfo = @{
                Name                = $service.Name
                DisplayName         = $service.DisplayName
                Status              = $service.Status.ToString()
                StartType           = $service.StartType.ToString()
                CanStop             = $service.CanStop
                CanPauseAndContinue = $service.CanPauseAndContinue
                DependentServices   = @($service.DependentServices | Select-Object -ExpandProperty Name)
                ServicesDependedOn  = @($service.ServicesDependedOn | Select-Object -ExpandProperty Name)
                ProcessId           = if ($wmiService.ProcessId) { $wmiService.ProcessId } else { 0 }
                PathName            = $wmiService.PathName
                Description         = $wmiService.Description
                StartMode           = $wmiService.StartMode
                State               = $wmiService.State
                AcceptPause         = $wmiService.AcceptPause
                AcceptStop          = $wmiService.AcceptStop
                DesktopInteract     = $wmiService.DesktopInteract
                ErrorControl        = $wmiService.ErrorControl
                ServiceType         = $wmiService.ServiceType
                IsProtected         = $this.IsServiceProtected($serviceName)
            }

            # Actualizar cachÃ©
            $this.ServiceCache[$serviceName] = $serviceInfo
            $this.LastCacheUpdate = [DateTime]::Now

            return $serviceInfo
        } catch {
            Write-Verbose "Error obteniendo informaciÃ³n del servicio $serviceName : $_"
            return $null
        }
    }

    # Iniciar servicio
    [bool] StartService([string]$serviceName) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop

            if ($service.Status -eq [ServiceControllerStatus]::Running) {
                Write-Verbose "El servicio $serviceName ya estÃ¡ en ejecuciÃ³n"
                return $true
            }

            Start-Service -Name $serviceName -ErrorAction Stop

            # Esperar hasta que inicie (mÃ¡ximo 30 segundos)
            $timeout = 30
            $elapsed = 0

            while ($service.Status -ne [ServiceControllerStatus]::Running -and $elapsed -lt $timeout) {
                Start-Sleep -Milliseconds 500
                $elapsed += 0.5
                $service.Refresh()
            }

            return $service.Status -eq [ServiceControllerStatus]::Running
        } catch {
            Write-Error "Error iniciando servicio $serviceName : $_"
            return $false
        }
    }

    # Reiniciar servicio
    [bool] RestartService([string]$serviceName) {
        try {
            Restart-Service -Name $serviceName -Force -ErrorAction Stop
            return $true
        } catch {
            Write-Error "Error reiniciando servicio $serviceName : $_"
            return $false
        }
    }

    # Cambiar tipo de inicio del servicio
    [bool] SetServiceStartType([string]$serviceName, [string]$startType) {
        try {
            Set-Service -Name $serviceName -StartupType $startType -ErrorAction Stop

            # Limpiar cachÃ©
            if ($this.ServiceCache.ContainsKey($serviceName)) {
                $this.ServiceCache.Remove($serviceName)
            }

            return $true
        } catch {
            Write-Error "Error cambiando tipo de inicio del servicio $serviceName : $_"
            return $false
        }
    }

    # Obtener servicios por estado
    [List[hashtable]] GetServicesByStatus([ServiceControllerStatus]$status) {
        $services = [List[hashtable]]::new()

        try {
            $matchingServices = Get-Service | Where-Object { $_.Status -eq $status }

            foreach ($service in $matchingServices) {
                $services.Add(@{
                        Name        = $service.Name
                        DisplayName = $service.DisplayName
                        Status      = $service.Status.ToString()
                        StartType   = $service.StartType.ToString()
                    })
            }
        } catch {
            Write-Error "Error obteniendo servicios por estado: $_"
        }

        return $services
    }

    # Obtener servicios que dependen de un proceso
    [List[string]] GetServicesForProcess([int]$processId) {
        $services = [List[string]]::new()

        try {
            $wmiServices = Get-WmiObject Win32_Service -Filter "ProcessId = $processId"

            foreach ($service in $wmiServices) {
                $services.Add($service.Name)
            }
        } catch {
            Write-Verbose "Error obteniendo servicios para proceso $processId : $_"
        }

        return $services
    }

    # Limpiar cachÃ©
    [void] ClearCache() {
        $this.ServiceCache.Clear()
        $this.LastCacheUpdate = [DateTime]::MinValue
    }
}
