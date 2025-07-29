# ConfigManager.ps1 - Gestor de configuracion CORREGIDO
# Sin errores de sintaxis

# Funcion para cargar configuracion desde archivo JSON
function Load-ProcessConfig {
    param(
        [string]$ConfigPath = "ProcessConfig.json"
    )

    try {
        # Buscar archivo en multiples ubicaciones
        $searchPaths = @(
            $ConfigPath,
            "$PSScriptRoot\$ConfigPath",
            "$PSScriptRoot\..\..\config\$ConfigPath",
            "$env:USERPROFILE\Documents\ProcessManager\$ConfigPath",
            "$env:APPDATA\ProcessManager\$ConfigPath"
        )

        $configFile = $null
        foreach ($path in $searchPaths) {
            if (Test-Path $path) {
                $configFile = $path
                break
            }
        }

        if (-not $configFile) {
            throw "No se encontro el archivo de configuracion ProcessConfig.json"
        }

        Write-Host "Cargando configuracion desde: $configFile" -ForegroundColor Green

        # Cargar y parsear JSON
        $jsonContent = Get-Content $configFile -Raw -Encoding UTF8
        $configData = $jsonContent | ConvertFrom-Json

        # Crear objeto de configuracion simplificado
        $config = [PSCustomObject]@{
            Version          = $configData.version
            LastUpdated      = $configData.lastUpdated
            Categories       = @{}
            GlobalSettings   = @{
                DefaultTimeout    = 2000
                RetryAttempts     = 3
                DelayBetweenKills = 150
            }
            SystemProtection = @{
                CriticalProcesses = @("System", "csrss", "winlogon", "services", "lsass", "smss", "wininit")
            }
        }

        # Cargar categorias de forma simplificada
        foreach ($categoryName in $configData.categories.PSObject.Properties.Name) {
            $categoryData = $configData.categories.$categoryName
            $config.Categories[$categoryName] = @{
                description     = $categoryData.description
                icon            = if ($categoryData.icon) { $categoryData.icon } else { "[CAT]" }
                color           = if ($categoryData.color) { $categoryData.color } else { "#0066CC" }
                priority        = if ($categoryData.priority) { $categoryData.priority } else { "medium" }
                aggressiveKill  = if ($categoryData.aggressiveKill -ne $null) { $categoryData.aggressiveKill } else { $false }
                processes       = if ($categoryData.processes) { $categoryData.processes } else { @() }
                relatedServices = if ($categoryData.relatedServices) { $categoryData.relatedServices } else { @() }
            }
        }

        Write-Host "Configuracion cargada exitosamente: $($config.Categories.Count) categorias" -ForegroundColor Green
        return $config

    } catch {
        Write-Host "Error cargando configuracion: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Usando configuracion por defecto..." -ForegroundColor Yellow
        return Get-DefaultConfig
    }
}

# Funcion para generar configuracion por defecto
function Get-DefaultConfig {
    $config = [PSCustomObject]@{
        Version          = "1.0"
        LastUpdated      = Get-Date -Format "yyyy-MM-dd"
        Categories       = @{
            "ASUS Software"          = @{
                description     = "Software y servicios de ASUS"
                icon            = "[ASUS]"
                color           = "#FF6B35"
                priority        = "high"
                aggressiveKill  = $true
                processes       = @("asus_framework", "ArmourySocketServer", "ADU", "ASUS DriverHub", "ArmourySwAgent", "AcPowerNotification")
                relatedServices = @("AsusAppService")
            }
            "Adobe Software"         = @{
                description     = "Adobe Creative Suite y Acrobat"
                icon            = "[ADOBE]"
                color           = "#FF0000"
                priority        = "high"
                aggressiveKill  = $true
                processes       = @("Adobe", "Acrobat", "AdobeCollabSync", "AdobeNotificationClient", "CreativeCloud")
                relatedServices = @("AdobeUpdateService")
            }
            "AVG Software"           = @{
                description     = "AVG Antivirus y TuneUp"
                icon            = "[AVG]"
                color           = "#FF8C00"
                priority        = "high"
                aggressiveKill  = $true
                processes       = @("TuneupUI", "TuneupSvc", "Vpn", "VpnSvc")
                relatedServices = @("AVGTuneup")
            }
            "Comunicacion"           = @{
                description     = "Apps de mensajeria"
                icon            = "[CHAT]"
                color           = "#25D366"
                priority        = "medium"
                aggressiveKill  = $false
                processes       = @("WhatsApp", "ChatGPT", "claude", "copilot")
                relatedServices = @()
            }
            "Apple/iCloud"           = @{
                description     = "Servicios de Apple"
                icon            = "[APPLE]"
                color           = "#007AFF"
                priority        = "medium"
                aggressiveKill  = $false
                processes       = @("ApplePhotoStreams", "iCloudHome", "iCloudDrive", "iCloudPhotos", "secd", "APSDaemon")
                relatedServices = @()
            }
            "Corsair/iCUE"           = @{
                description     = "Software Corsair"
                icon            = "[CORSAIR]"
                color           = "#FFD700"
                priority        = "medium"
                aggressiveKill  = $true
                processes       = @("iCUE", "QmlRenderer", "CorsairCpuIdService", "CorsairDeviceControlService")
                relatedServices = @("CorsairService")
            }
            "Elgato Software"        = @{
                description     = "Software Elgato"
                icon            = "[ELGATO]"
                color           = "#0066CC"
                priority        = "low"
                aggressiveKill  = $false
                processes       = @("ElgatoAudioControlServer", "ElgatoAudioControlServerWatcher", "StreamDeck")
                relatedServices = @()
            }
            "Utilidades Sistema"     = @{
                description     = "Herramientas del sistema"
                icon            = "[UTILS]"
                color           = "#6A5ACD"
                priority        = "low"
                aggressiveKill  = $false
                processes       = @("Everything", "DisplayFusion", "PowerToys", "RTSS", "MSIAfterburner", "ShareX", "TranslucentTB")
                relatedServices = @()
            }
            "Fondos/Personalizacion" = @{
                description     = "Wallpaper Engine"
                icon            = "[WALL]"
                color           = "#FF1493"
                priority        = "low"
                aggressiveKill  = $false
                processes       = @("wallpaper32", "wallpaperservice32")
                relatedServices = @()
            }
            "Widgets/Microsoft"      = @{
                description     = "Widgets de Microsoft"
                icon            = "[WIDGET]"
                color           = "#0078D4"
                priority        = "low"
                aggressiveKill  = $false
                processes       = @("Widgets", "msedgewebview2", "StartMenuExperienceHost", "PhoneExperienceHost")
                relatedServices = @()
            }
        }
        GlobalSettings   = @{
            DefaultTimeout    = 2000
            RetryAttempts     = 3
            DelayBetweenKills = 150
        }
        SystemProtection = @{
            CriticalProcesses = @("System", "csrss", "winlogon", "services", "lsass", "smss", "wininit", "dwm", "explorer")
        }
    }

    return $config
}

# Funcion para guardar configuracion personalizada
function Save-UserConfig {
    param(
        [PSCustomObject]$Config,
        [string]$ConfigPath = "$env:USERPROFILE\Documents\ProcessManager\UserConfig.json"
    )

    try {
        $configDir = Split-Path $ConfigPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        $jsonConfig = $Config | ConvertTo-Json -Depth 10
        $jsonConfig | Set-Content $ConfigPath -Encoding UTF8

        Write-Host "Configuracion guardada en: $ConfigPath" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Error guardando configuracion: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Funcion para validar configuracion
function Test-ProcessConfig {
    param([PSCustomObject]$Config)

    $valid = $true
    $errors = @()

    if (-not $Config.Version) {
        $errors += "Version no especificada"
        $valid = $false
    }

    if ($Config.Categories.Count -eq 0) {
        $errors += "No hay categorias definidas"
        $valid = $false
    }

    if ($valid) {
        Write-Host "Configuracion valida" -ForegroundColor Green
    } else {
        Write-Host "Configuracion invalida:" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "  - $err" -ForegroundColor Red
        }
    }

    return @{
        Valid  = $valid
        Errors = $errors
    }
}

# Funcion para mostrar informacion de configuracion
function Show-ConfigInfo {
    param([PSCustomObject]$Config)

    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                INFORMACION DE CONFIGURACION                    " -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Version: $($Config.Version)" -ForegroundColor White
    Write-Host "Actualizada: $($Config.LastUpdated)" -ForegroundColor White
    Write-Host "Categorias: $($Config.Categories.Count)" -ForegroundColor White
    Write-Host ""

    foreach ($categoryName in $Config.Categories.Keys) {
        $category = $Config.Categories[$categoryName]
        $priorityColor = switch ($category.priority) {
            "high" { "Red" }
            "medium" { "Yellow" }
            "low" { "Green" }
            default { "White" }
        }

        Write-Host "$($category.icon) $categoryName" -ForegroundColor $priorityColor
        Write-Host "   Descripcion: $($category.description)" -ForegroundColor Gray
        Write-Host "   Procesos: $($category.processes.Count)" -ForegroundColor Gray
        Write-Host "   Prioridad: $($category.priority)" -ForegroundColor Gray
        Write-Host "   Cierre agresivo: $($category.aggressiveKill)" -ForegroundColor Gray
        Write-Host ""
    }
}

# Funcion para crear archivo de configuracion por defecto
function Create-DefaultConfigFile {
    param([string]$OutputPath = "ProcessConfig.json")

    # Crear configuracion JSON simplificada
    $defaultConfig = @{
        version          = "1.0"
        lastUpdated      = Get-Date -Format "yyyy-MM-dd"
        description      = "Configuracion simplificada para Process Manager Pro"
        categories       = @{
            "ASUS Software"  = @{
                description    = "Software ASUS"
                priority       = "high"
                aggressiveKill = $true
                processes      = @("asus_framework", "ArmourySocketServer", "ADU")
            }
            "Adobe Software" = @{
                description    = "Adobe Creative Suite"
                priority       = "high"
                aggressiveKill = $true
                processes      = @("Adobe", "Acrobat", "AdobeCollabSync")
            }
            "Comunicacion"   = @{
                description    = "Apps de chat"
                priority       = "medium"
                aggressiveKill = $false
                processes      = @("WhatsApp", "ChatGPT", "claude")
            }
        }
        globalSettings   = @{
            defaultTimeout    = 2000
            retryAttempts     = 3
            delayBetweenKills = 150
        }
        systemProtection = @{
            criticalProcesses = @("System", "csrss", "winlogon", "services", "lsass")
        }
    }

    try {
        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8
        Write-Host "Archivo de configuracion creado: $OutputPath" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Error creando archivo: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Exportar funciones principales
Write-Host "ConfigManager cargado exitosamente" -ForegroundColor Green
