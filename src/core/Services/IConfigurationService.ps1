# IConfigurationService.ps1 - Interface para el servicio de configuraciÃ³n
using namespace System.Collections.Generic

# Interface para el servicio de configuraciÃ³n
class IConfigurationService {
    # Cargar configuraciÃ³n desde fuente
    [Configuration] LoadConfiguration() {
        throw [NotImplementedException]::new("LoadConfiguration must be implemented")
    }

    # Cargar configuraciÃ³n desde archivo especÃ­fico
    [Configuration] LoadConfigurationFromFile([string]$filePath) {
        throw [NotImplementedException]::new("LoadConfigurationFromFile must be implemented")
    }

    # Guardar configuraciÃ³n
    [bool] SaveConfiguration([Configuration]$configuration) {
        throw [NotImplementedException]::new("SaveConfiguration must be implemented")
    }

    # Guardar configuraciÃ³n en archivo especÃ­fico
    [bool] SaveConfigurationToFile([Configuration]$configuration, [string]$filePath) {
        throw [NotImplementedException]::new("SaveConfigurationToFile must be implemented")
    }

    # Validar configuraciÃ³n
    [hashtable] ValidateConfiguration([Configuration]$configuration) {
        throw [NotImplementedException]::new("ValidateConfiguration must be implemented")
    }

    # Obtener configuraciÃ³n por defecto
    [Configuration] GetDefaultConfiguration() {
        throw [NotImplementedException]::new("GetDefaultConfiguration must be implemented")
    }

    # Exportar configuraciÃ³n
    [bool] ExportConfiguration([Configuration]$configuration, [string]$format, [string]$filePath) {
        throw [NotImplementedException]::new("ExportConfiguration must be implemented")
    }

    # Importar configuraciÃ³n
    [Configuration] ImportConfiguration([string]$filePath, [string]$format) {
        throw [NotImplementedException]::new("ImportConfiguration must be implemented")
    }

    # Fusionar configuraciones
    [Configuration] MergeConfigurations([Configuration]$primary, [Configuration]$secondary) {
        throw [NotImplementedException]::new("MergeConfigurations must be implemented")
    }
}

# Interface para persistencia de preferencias de usuario
class IUserPreferencesService {
    # Cargar preferencias de usuario
    [UserPreferences] LoadUserPreferences() {
        throw [NotImplementedException]::new("LoadUserPreferences must be implemented")
    }

    # Guardar preferencias de usuario
    [bool] SaveUserPreferences([UserPreferences]$preferences) {
        throw [NotImplementedException]::new("SaveUserPreferences must be implemented")
    }

    # Resetear preferencias a valores por defecto
    [UserPreferences] ResetToDefaults() {
        throw [NotImplementedException]::new("ResetToDefaults must be implemented")
    }

    # Cargar selecciones guardadas
    [List[string]] LoadSavedSelections() {
        throw [NotImplementedException]::new("LoadSavedSelections must be implemented")
    }

    # Guardar selecciones actuales
    [bool] SaveSelections([List[ProcessModel]]$selectedProcesses) {
        throw [NotImplementedException]::new("SaveSelections must be implemented")
    }
}
