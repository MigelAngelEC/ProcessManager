# ProcessService.ps1 - ImplementaciÃ³n del servicio de procesos
using namespace System.Collections.Generic

# Cargar dependencias
. "$PSScriptRoot\..\Models\Process.ps1"
. "$PSScriptRoot\..\Models\Category.ps1"
. "$PSScriptRoot\IProcessService.ps1"

class ProcessService : IProcessService {
    [IServiceManager]$ServiceManager
    [Configuration]$Configuration
    hidden [hashtable]$ProcessCache

    ProcessService([Configuration]$configuration, [IServiceManager]$serviceManager) {
        $this.Configuration = $configuration
        $this.ServiceManager = $serviceManager
        $this.ProcessCache = @{}
    }

    [List[ProcessModel]] GetAllProcesses() {
        $processes = [List[ProcessModel]]::new()

        try {
            $systemProcesses = Get-Process | Where-Object { $_.Id -ne $PID }

            foreach ($proc in $systemProcesses) {
                # Determinar categorÃ­a
                $category = $this.DetermineCategory($proc.ProcessName)
                $processModel = [ProcessModel]::new($proc, $category)

                # Verificar si estÃ¡ protegido
                $processModel.IsProtected = $this.Configuration.IsProtectedProcess($proc.ProcessName)

                # Establecer prioridad basada en la categorÃ­a
                if ($category -and $this.Configuration.Categories.ContainsKey($category)) {
                    $processModel.Priority = $this.Configuration.Categories[$category].Priority
                }

                $processes.Add($processModel)

                # Agregar a cachÃ©
                $this.ProcessCache[$proc.Id] = $processModel
            }
        } catch {
            Write-Error "Error obteniendo procesos: $_"
            throw
        }

        return $processes
    }

    [List[ProcessModel]] GetProcessesByCategory([Category]$category) {
        $processes = [List[ProcessModel]]::new()

        if ($null -eq $category) {
            return $processes
        }

        try {
            foreach ($pattern in $category.ProcessPatterns) {
                $matchingProcesses = Get-Process | Where-Object {
                    $_.ProcessName -like "*$pattern*" -and $_.Id -ne $PID
                }

                foreach ($proc in $matchingProcesses) {
                    $processModel = [ProcessModel]::new($proc, $category.Name)
                    $processModel.IsProtected = $this.Configuration.IsProtectedProcess($proc.ProcessName)
                    $processModel.Priority = $category.Priority

                    # Evitar duplicados
                    $exists = $false
                    foreach ($existing in $processes) {
                        if ($existing.Id -eq $processModel.Id) {
                            $exists = $true
                            break
                        }
                    }

                    if (-not $exists) {
                        $processes.Add($processModel)
                    }
                }
            }
        } catch {
            Write-Error "Error obteniendo procesos por categorÃ­a: $_"
            throw
        }

        return $processes | Sort-Object -Property MemoryMB -Descending
    }

    [ProcessModel] GetProcessById([int]$processId) {
        # Verificar cachÃ© primero
        if ($this.ProcessCache.ContainsKey($processId)) {
            # Verificar si el proceso aÃºn existe
            if ($this.IsProcessRunning($processId)) {
                return $this.RefreshProcess($this.ProcessCache[$processId])
            } else {
                $this.ProcessCache.Remove($processId)
                return $null
            }
        }

        try {
            $proc = Get-Process -Id $processId -ErrorAction Stop
            $category = $this.DetermineCategory($proc.ProcessName)
            $processModel = [ProcessModel]::new($proc, $category)
            $processModel.IsProtected = $this.Configuration.IsProtectedProcess($proc.ProcessName)

            $this.ProcessCache[$processId] = $processModel
            return $processModel
        } catch {
            return $null
        }
    }

    [ProcessOperationResult] KillProcess([ProcessModel]$process) {
        if ($null -eq $process) {
            return [ProcessOperationResult]::new($false, $null, "Proceso no vÃ¡lido")
        }

        # Verificar si estÃ¡ protegido
        if ($process.IsProtected) {
            return [ProcessOperationResult]::new($false, $process, "Proceso protegido del sistema")
        }

        try {
            $proc = Get-Process -Id $process.Id -ErrorAction Stop

            # Determinar mÃ©todo de cierre basado en configuraciÃ³n
            $category = $this.Configuration.GetCategory($process.Category)
            $aggressiveKill = $false

            if ($category) {
                $aggressiveKill = $category.AggressiveKill
            }

            if ($aggressiveKill) {
                # Cierre agresivo con reintentos
                for ($attempt = 1; $attempt -le $this.Configuration.GlobalSettings.RetryAttempts; $attempt++) {
                    try {
                        if (-not $this.IsProcessRunning($process.Id)) {
                            return [ProcessOperationResult]::new($true, $process, "Proceso ya cerrado")
                        }

                        switch ($attempt) {
                            1 {
                                $proc.Kill()
                                Write-Verbose "Intento $attempt - Kill estÃ¡ndar"
                            }
                            2 {
                                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                                Write-Verbose "Intento $attempt - Stop-Process Force"
                            }
                            3 {
                                & cmd /c "taskkill /PID $($process.Id) /F" 2>$null
                                Write-Verbose "Intento $attempt - taskkill Force"
                            }
                        }

                        Start-Sleep -Milliseconds $this.Configuration.GlobalSettings.DelayBetweenKills

                        if (-not $this.IsProcessRunning($process.Id)) {
                            $this.ProcessCache.Remove($process.Id)
                            return [ProcessOperationResult]::new($true, $process, "Proceso cerrado exitosamente")
                        }
                    } catch {
                        if ($_.Exception.Message -like "*Cannot find a process*") {
                            $this.ProcessCache.Remove($process.Id)
                            return [ProcessOperationResult]::new($true, $process, "Proceso cerrado")
                        }
                    }
                }
            } else {
                # Cierre normal
                $proc.Kill()
                Start-Sleep -Milliseconds 500

                if (-not $this.IsProcessRunning($process.Id)) {
                    $this.ProcessCache.Remove($process.Id)
                    return [ProcessOperationResult]::new($true, $process, "Proceso cerrado exitosamente")
                }
            }

            return [ProcessOperationResult]::new($false, $process, "El proceso no respondiÃ³ al cierre")
        } catch {
            if ($_.Exception.Message -like "*Cannot find a process*") {
                $this.ProcessCache.Remove($process.Id)
                return [ProcessOperationResult]::new($true, $process, "Proceso ya no existe")
            }

            return [ProcessOperationResult]::new($process, $_.Exception)
        }
    }

    [List[ProcessOperationResult]] KillProcesses([List[ProcessModel]]$processes) {
        $results = [List[ProcessOperationResult]]::new()

        foreach ($process in $processes) {
            $result = $this.KillProcess($process)
            $results.Add($result)

            # PequeÃ±a pausa entre procesos
            if ($processes.IndexOf($process) -lt ($processes.Count - 1)) {
                Start-Sleep -Milliseconds 100
            }
        }

        return $results
    }

    [bool] IsProcessRunning([int]$processId) {
        try {
            $proc = Get-Process -Id $processId -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }

    [ProcessModel] RefreshProcess([ProcessModel]$process) {
        if ($null -eq $process) {
            return $null
        }

        try {
            $proc = Get-Process -Id $process.Id -ErrorAction Stop
            $process.MemoryMB = [Math]::Round($proc.WorkingSet64 / 1MB, 2)
            return $process
        } catch {
            return $null
        }
    }

    [hashtable] GetMemoryStatistics() {
        $stats = @{
            TotalProcesses  = 0
            TotalMemoryMB   = 0.0
            AverageMemoryMB = 0.0
            LargestProcess  = $null
            CategoriesStats = @{}
        }

        $allProcesses = $this.GetAllProcesses()
        $stats.TotalProcesses = $allProcesses.Count

        foreach ($proc in $allProcesses) {
            $stats.TotalMemoryMB += $proc.MemoryMB

            if ($null -eq $stats.LargestProcess -or $proc.MemoryMB -gt $stats.LargestProcess.MemoryMB) {
                $stats.LargestProcess = $proc
            }

            # EstadÃ­sticas por categorÃ­a
            if ($proc.Category) {
                if (-not $stats.CategoriesStats.ContainsKey($proc.Category)) {
                    $stats.CategoriesStats[$proc.Category] = @{
                        Count         = 0
                        TotalMemoryMB = 0.0
                    }
                }

                $stats.CategoriesStats[$proc.Category].Count++
                $stats.CategoriesStats[$proc.Category].TotalMemoryMB += $proc.MemoryMB
            }
        }

        if ($stats.TotalProcesses -gt 0) {
            $stats.AverageMemoryMB = $stats.TotalMemoryMB / $stats.TotalProcesses
        }

        return $stats
    }

    [List[ProcessModel]] SearchProcesses([string]$searchTerm) {
        $results = [List[ProcessModel]]::new()

        if ([string]::IsNullOrWhiteSpace($searchTerm)) {
            return $results
        }

        $allProcesses = $this.GetAllProcesses()

        foreach ($proc in $allProcesses) {
            if ($proc.Name -like "*$searchTerm*" -or
                $proc.Category -like "*$searchTerm*" -or
                $proc.Id.ToString() -eq $searchTerm) {
                $results.Add($proc)
            }
        }

        return $results
    }

    # MÃ©todo auxiliar para determinar la categorÃ­a de un proceso
    hidden [string] DetermineCategory([string]$processName) {
        foreach ($categoryName in $this.Configuration.Categories.Keys) {
            $category = $this.Configuration.Categories[$categoryName]
            if ($category.MatchesProcess($processName)) {
                return $categoryName
            }
        }

        return "Sin categorÃ­a"
    }
}
