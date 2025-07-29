# Configuration.ps1 - Modelo de ConfiguraciÃ³n
using namespace System.Collections.Generic

class Configuration {
    [string]$Version
    [DateTime]$LastUpdated
    [string]$Description
    [Dictionary[string, Category]]$Categories
    [GlobalSettings]$GlobalSettings
    [SystemProtection]$SystemProtection

    Configuration() {
        $this.Version = "2.0"
        $this.LastUpdated = [DateTime]::Now
        $this.Categories = [Dictionary[string, Category]]::new()
        $this.GlobalSettings = [GlobalSettings]::new()
        $this.SystemProtection = [SystemProtection]::new()
    }

    [void] AddCategory([Category]$category) {
        if (-not $this.Categories.ContainsKey($category.Name)) {
            $this.Categories.Add($category.Name, $category)
        }
    }

    [Category] GetCategory([string]$name) {
        if ($this.Categories.ContainsKey($name)) {
            return $this.Categories[$name]
        }
        return $null
    }

    [List[Category]] GetEnabledCategories() {
        $enabled = [List[Category]]::new()
        foreach ($category in $this.Categories.Values) {
            if ($category.IsEnabled) {
                $enabled.Add($category)
            }
        }
        return $enabled
    }

    [bool] IsProtectedProcess([string]$processName) {
        return $this.SystemProtection.IsProtected($processName)
    }
}

class GlobalSettings {
    [int]$DefaultTimeout
    [int]$RetryAttempts
    [int]$DelayBetweenKills
    [bool]$EnableLogging
    [bool]$ShowProgressBar
    [bool]$ConfirmBeforeKill
    [bool]$AutoRefreshEnabled
    [int]$AutoRefreshInterval

    GlobalSettings() {
        $this.DefaultTimeout = 2000
        $this.RetryAttempts = 3
        $this.DelayBetweenKills = 150
        $this.EnableLogging = $true
        $this.ShowProgressBar = $true
        $this.ConfirmBeforeKill = $true
        $this.AutoRefreshEnabled = $false
        $this.AutoRefreshInterval = 300000  # 5 minutos
    }
}

class SystemProtection {
    [HashSet[string]]$CriticalProcesses
    [HashSet[string]]$ProtectedServices

    SystemProtection() {
        $this.CriticalProcesses = [HashSet[string]]::new()
        $this.ProtectedServices = [HashSet[string]]::new()

        # Procesos crÃ­ticos por defecto
        $defaultCritical = @(
            "System", "csrss", "winlogon", "services", "lsass",
            "smss", "wininit", "dwm", "explorer", "svchost"
        )

        foreach ($process in $defaultCritical) {
            $this.CriticalProcesses.Add($process.ToLower()) | Out-Null
        }
    }

    [bool] IsProtected([string]$processName) {
        return $this.CriticalProcesses.Contains($processName.ToLower())
    }

    [bool] IsProtectedService([string]$serviceName) {
        return $this.ProtectedServices.Contains($serviceName.ToLower())
    }

    [void] AddProtectedProcess([string]$processName) {
        $this.CriticalProcesses.Add($processName.ToLower()) | Out-Null
    }

    [void] AddProtectedService([string]$serviceName) {
        $this.ProtectedServices.Add($serviceName.ToLower()) | Out-Null
    }
}

# Clase para preferencias de usuario
class UserPreferences {
    [string]$Theme
    [string]$Language
    [bool]$MinimizeToTray
    [bool]$StartWithWindows
    [bool]$CheckForUpdates
    [string]$DefaultView
    [List[string]]$FavoriteCategories
    [DateTime]$LastUsed

    UserPreferences() {
        $this.Theme = "Default"
        $this.Language = "es-ES"
        $this.MinimizeToTray = $false
        $this.StartWithWindows = $false
        $this.CheckForUpdates = $true
        $this.DefaultView = "Categories"
        $this.FavoriteCategories = [List[string]]::new()
        $this.LastUsed = [DateTime]::Now
    }
}
