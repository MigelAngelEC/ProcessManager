# IProcessService.ps1 - Interface para el servicio de procesos
using namespace System.Collections.Generic

# Interface para el servicio de procesos
class IProcessService {
    # Obtener todos los procesos del sistema
    [List[ProcessModel]] GetAllProcesses() {
        throw [NotImplementedException]::new("GetAllProcesses must be implemented")
    }

    # Obtener procesos por categorÃ­a
    [List[ProcessModel]] GetProcessesByCategory([Category]$category) {
        throw [NotImplementedException]::new("GetProcessesByCategory must be implemented")
    }

    # Obtener proceso por ID
    [ProcessModel] GetProcessById([int]$processId) {
        throw [NotImplementedException]::new("GetProcessById must be implemented")
    }

    # Cerrar un proceso
    [ProcessOperationResult] KillProcess([ProcessModel]$process) {
        throw [NotImplementedException]::new("KillProcess must be implemented")
    }

    # Cerrar mÃºltiples procesos
    [List[ProcessOperationResult]] KillProcesses([List[ProcessModel]]$processes) {
        throw [NotImplementedException]::new("KillProcesses must be implemented")
    }

    # Verificar si un proceso estÃ¡ en ejecuciÃ³n
    [bool] IsProcessRunning([int]$processId) {
        throw [NotImplementedException]::new("IsProcessRunning must be implemented")
    }

    # Refrescar informaciÃ³n de un proceso
    [ProcessModel] RefreshProcess([ProcessModel]$process) {
        throw [NotImplementedException]::new("RefreshProcess must be implemented")
    }

    # Obtener estadÃ­sticas de memoria
    [hashtable] GetMemoryStatistics() {
        throw [NotImplementedException]::new("GetMemoryStatistics must be implemented")
    }

    # Buscar procesos por nombre
    [List[ProcessModel]] SearchProcesses([string]$searchTerm) {
        throw [NotImplementedException]::new("SearchProcesses must be implemented")
    }
}

# Interface para manejo de servicios de Windows
class IServiceManager {
    # Obtener servicios relacionados
    [List[hashtable]] GetRelatedServices([List[string]]$serviceNames) {
        throw [NotImplementedException]::new("GetRelatedServices must be implemented")
    }

    # Detener un servicio
    [bool] StopService([string]$serviceName) {
        throw [NotImplementedException]::new("StopService must be implemented")
    }

    # Obtener estado de un servicio
    [string] GetServiceStatus([string]$serviceName) {
        throw [NotImplementedException]::new("GetServiceStatus must be implemented")
    }

    # Verificar si un servicio estÃ¡ protegido
    [bool] IsServiceProtected([string]$serviceName) {
        throw [NotImplementedException]::new("IsServiceProtected must be implemented")
    }
}
