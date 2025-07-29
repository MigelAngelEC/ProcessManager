# ConfigurationService.ps1 - ImplementaciÃ³n del servicio de configuraciÃ³n
using namespace System.Collections.Generic
using namespace System.IO

# Cargar dependencias
. "$PSScriptRoot\..\Models\Configuration.ps1"
. "$PSScriptRoot\..\Models\Category.ps1"
. "$PSScriptRoot\IConfigurationService.ps1"

class ConfigurationService : IConfigurationService {
    [string]$DefaultConfigPath
    [string]$UserConfigPath
    hidden [Configuration]$CachedConfiguration

    ConfigurationService() {
        $this.DefaultConfigPath = Join-Path $PSScriptRoot "..\..\..\config\ProcessConfig.json"
        $this.UserConfigPath = Join-Path $env:USERPROFILE "Documents\ProcessManager\UserConfig.json"
        $this.CachedConfiguration = $null
    }

    ConfigurationService([string]$defaultPath, [string]$userPath) {
        $this.DefaultConfigPath = $defaultPath
        $this.UserConfigPath = $userPath
        $this.CachedConfiguration = $null
    }

    [Configuration] LoadConfiguration() {
        # Si hay configuraciÃ³n en cachÃ©, devolverla
        if ($null -ne $this.CachedConfiguration) {
            return $this.CachedConfiguration
        }

        # Intentar cargar configuraciÃ³n de usuario primero
        if (Test-Path $this.UserConfigPath) {
            try {
                $config = $this.LoadConfigurationFromFile($this.UserConfigPath)
                if ($null -ne $config) {
                    $this.CachedConfiguration = $config
                    return $config
                }
            } catch {
                Write-Warning "Error cargando configuraciÃ³n de usuario: $_"
            }
        }

        # Cargar configuraciÃ³n por defecto
        if (Test-Path $this.DefaultConfigPath) {
            try {
                $config = $this.LoadConfigurationFromFile($this.DefaultConfigPath)
                if ($null -ne $config) {
                    $this.CachedConfiguration = $config
                    return $config
                }
            } catch {
                Write-Warning "Error cargando configuraciÃ³n por defecto: $_"
            }
        }

        # Si todo falla, devolver configuraciÃ³n por defecto
        Write-Warning "No se pudo cargar ninguna configuraciÃ³n, usando valores por defecto"
        $config = $this.GetDefaultConfiguration()
        $this.CachedConfiguration = $config
        return $config
    }

    [Configuration] LoadConfigurationFromFile([string]$filePath) {
        if (-not (Test-Path $filePath)) {
            throw "El archivo de configuraciÃ³n no existe: $filePath"
        }

        try {
            $jsonContent = Get-Content $filePath -Raw -Encoding UTF8
            $configData = $jsonContent | ConvertFrom-Json

            $config = [Configuration]::new()
            $config.Version = $configData.version
            $config.LastUpdated = [DateTime]::Parse($configData.lastUpdated)
            $config.Description = $configData.description

            # Cargar configuraciÃ³n global
            if ($configData.globalSettings) {
                $config.GlobalSettings.DefaultTimeout = $configData.globalSettings.defaultTimeout
                $config.GlobalSettings.RetryAttempts = $configData.globalSettings.retryAttempts
                $config.GlobalSettings.DelayBetweenKills = $configData.globalSettings.delayBetweenKills
                $config.GlobalSettings.EnableLogging = $configData.globalSettings.enableLogging
                $config.GlobalSettings.ShowProgressBar = $configData.globalSettings.showProgressBar
                $config.GlobalSettings.ConfirmBeforeKill = $configData.globalSettings.confirmBeforeKill
            }

            # Cargar protecciÃ³n del sistema
            if ($configData.systemProtection) {
                foreach ($process in $configData.systemProtection.criticalProcesses) {
                    $config.SystemProtection.AddProtectedProcess($process)
                }

                if ($configData.systemProtection.protectedServices) {
                    foreach ($service in $configData.systemProtection.protectedServices) {
                        $config.SystemProtection.AddProtectedService($service)
                    }
                }
            }

            # Cargar categorÃ­as
            foreach ($categoryName in $configData.categories.PSObject.Properties.Name) {
                $categoryData = $configData.categories.$categoryName

                $categoryHash = @{
                    description     = $categoryData.description
                    icon            = $categoryData.icon
                    color           = $categoryData.color
                    priority        = $categoryData.priority
                    aggressiveKill  = $categoryData.aggressiveKill
                    processes       = $categoryData.processes
                    relatedServices = $categoryData.relatedServices
                }

                $category = [Category]::new($categoryName, $categoryHash)
                $config.AddCategory($category)
            }

            return $config
        } catch {
            throw "Error parseando configuraciÃ³n: $_"
        }
    }

    [bool] SaveConfiguration([Configuration]$configuration) {
        return $this.SaveConfigurationToFile($configuration, $this.UserConfigPath)
    }

    [bool] SaveConfigurationToFile([Configuration]$configuration, [string]$filePath) {
        try {
            # Asegurar que el directorio existe
            $directory = [Path]::GetDirectoryName($filePath)
            if (-not (Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }

            # Convertir configuraciÃ³n a estructura para JSON
            $configData = @{
                version          = $configuration.Version
                lastUpdated      = $configuration.LastUpdated.ToString("yyyy-MM-dd")
                description      = $configuration.Description
                globalSettings   = @{
                    defaultTimeout    = $configuration.GlobalSettings.DefaultTimeout
                    retryAttempts     = $configuration.GlobalSettings.RetryAttempts
                    delayBetweenKills = $configuration.GlobalSettings.DelayBetweenKills
                    enableLogging     = $configuration.GlobalSettings.EnableLogging
                    showProgressBar   = $configuration.GlobalSettings.ShowProgressBar
                    confirmBeforeKill = $configuration.GlobalSettings.ConfirmBeforeKill
                }
                systemProtection = @{
                    criticalProcesses = @($configuration.SystemProtection.CriticalProcesses)
                    protectedServices = @($configuration.SystemProtection.ProtectedServices)
                }
                categories       = @{}
            }

            # Convertir categorÃ­as
            foreach ($categoryName in $configuration.Categories.Keys) {
                $category = $configuration.Categories[$categoryName]
                $configData.categories[$categoryName] = @{
                    description     = $category.Description
                    icon            = $category.Icon
                    color           = $category.Color
                    priority        = $category.Priority.ToString().ToLower()
                    aggressiveKill  = $category.AggressiveKill
                    processes       = @($category.ProcessPatterns)
                    relatedServices = @($category.RelatedServices)
                }
            }

            # Guardar a archivo
            $json = $configData | ConvertTo-Json -Depth 10
            $json | Set-Content $filePath -Encoding UTF8

            # Actualizar cachÃ©
            $this.CachedConfiguration = $configuration

            return $true
        } catch {
            Write-Error "Error guardando configuraciÃ³n: $_"
            return $false
        }
    }

    [hashtable] ValidateConfiguration([Configuration]$configuration) {
        $result = @{
            IsValid  = $true
            Errors   = [List[string]]::new()
            Warnings = [List[string]]::new()
        }

        # Validar versiÃ³n
        if ([string]::IsNullOrWhiteSpace($configuration.Version)) {
            $result.Errors.Add("La versiÃ³n no estÃ¡ especificada")
            $result.IsValid = $false
        }

        # Validar categorÃ­as
        if ($configuration.Categories.Count -eq 0) {
            $result.Warnings.Add("No hay categorÃ­as definidas")
        }

        foreach ($categoryName in $configuration.Categories.Keys) {
            $category = $configuration.Categories[$categoryName]

            if ([string]::IsNullOrWhiteSpace($category.Description)) {
                $result.Warnings.Add("La categorÃ­a '$categoryName' no tiene descripciÃ³n")
            }

            if ($category.ProcessPatterns.Count -eq 0) {
                $result.Warnings.Add("La categorÃ­a '$categoryName' no tiene patrones de proceso")
            }
        }

        # Validar configuraciÃ³n global
        if ($configuration.GlobalSettings.DefaultTimeout -le 0) {
            $result.Errors.Add("El timeout por defecto debe ser mayor a 0")
            $result.IsValid = $false
        }

        if ($configuration.GlobalSettings.RetryAttempts -le 0) {
            $result.Errors.Add("Los intentos de reintento deben ser mayor a 0")
            $result.IsValid = $false
        }

        # Validar protecciÃ³n del sistema
        if ($configuration.SystemProtection.CriticalProcesses.Count -eq 0) {
            $result.Warnings.Add("No hay procesos crÃ­ticos definidos")
        }

        return $result
    }

    [Configuration] GetDefaultConfiguration() {
        $config = [Configuration]::new()
        $config.Description = "ConfiguraciÃ³n por defecto de Process Manager"

        # CategorÃ­as por defecto
        $defaultCategories = @{
            "ASUS Software" = @{
                description = "Software y servicios de ASUS"
                icon        = "ðŸ”§"
                color = "#FF6B35"
                priority = "high"
                aggressiveKill = $true
                processes = @("asus_framework", "ArmourySocketServer", "ADU", "ASUS DriverHub")
                relatedServices = @("AsusAppService", "ASUSOptimization")
            }
            "Adobe Software" = @{
                description = "Adobe Creative Suite y servicios"
                icon = "ðŸŽ¨"
                color = "#FF0000"
                priority = "high"
                aggressiveKill = $true
                processes = @("Adobe", "Acrobat", "AdobeCollabSync", "CreativeCloud")
                relatedServices = @("AdobeUpdateService")
            }
            "ComunicaciÃ³n" = @{
                description = "Aplicaciones de mensajerÃ­a"
                icon = "ðŸ’¬"
                color = "#25D366"
                priority = "medium"
                aggressiveKill = $false
                processes = @("WhatsApp", "ChatGPT", "claude", "Teams", "Discord")
                relatedServices = @()
            }
            "Utilidades Sistema" = @{
                description = "Herramientas del sistema"
                icon = "ðŸ”§"
                color = "#6A5ACD"
                priority = "low"
                aggressiveKill = $false
                processes = @("Everything", "PowerToys", "ShareX", "TranslucentTB")
                relatedServices = @()
            }
        }

        foreach ($categoryName in $defaultCategories.Keys) {
            $category = [Category]::new($categoryName, $defaultCategories[$categoryName])
            $config.AddCategory($category)
        }

        return $config
    }

    [bool] ExportConfiguration([Configuration]$configuration, [string]$format, [string]$filePath) {
        try {
            switch ($format.ToLower()) {
                "json" {
                    return $this.SaveConfigurationToFile($configuration, $filePath)
                }
                "xml" {
                    # Implementar exportaciÃ³n XML si es necesario
                    throw "Formato XML no implementado aÃºn"
                }
                default {
                    throw "Formato no soportado: $format"
                }
            }
        }
        catch {
            Write-Error "Error exportando configuraciÃ³n: $_"
            return $false
        }
    }

    [Configuration] ImportConfiguration([string]$filePath, [string]$format) {
        switch ($format.ToLower()) {
            "json" {
                return $this.LoadConfigurationFromFile($filePath)
            }
            "xml" {
                throw "Formato XML no implementado aÃºn"
            }
            default {
                throw "Formato no soportado: $format"
            }
        }
    }

    [Configuration] MergeConfigurations([Configuration]$primary, [Configuration]$secondary) {
        $merged = [Configuration]::new()
        $merged.Version = $primary.Version
        $merged.LastUpdated = [DateTime]::Now
        $merged.Description = "ConfiguraciÃ³n fusionada"

        # Copiar configuraciÃ³n global de primaria
        $merged.GlobalSettings = $primary.GlobalSettings
        $merged.SystemProtection = $primary.SystemProtection

        # Fusionar categorÃ­as
        foreach ($categoryName in $primary.Categories.Keys) {
            $merged.AddCategory($primary.Categories[$categoryName])
        }

        foreach ($categoryName in $secondary.Categories.Keys) {
            if (-not $merged.Categories.ContainsKey($categoryName)) {
                $merged.AddCategory($secondary.Categories[$categoryName])
            }
        }

        return $merged
    }

    # MÃ©todo para limpiar cachÃ©
    [void] ClearCache() {
        $this.CachedConfiguration = $null
    }
}
