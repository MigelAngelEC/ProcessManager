# Category.ps1 - Modelo de CategorÃ­a
using namespace System.Collections.Generic

class Category {
    [string]$Name
    [string]$Description
    [string]$Icon
    [string]$Color
    [ProcessPriority]$Priority
    [bool]$AggressiveKill
    [List[string]]$ProcessPatterns
    [List[string]]$RelatedServices
    [bool]$IsEnabled

    Category() {
        $this.ProcessPatterns = [List[string]]::new()
        $this.RelatedServices = [List[string]]::new()
        $this.IsEnabled = $true
        $this.Priority = [ProcessPriority]::Medium
        $this.AggressiveKill = $false
    }

    Category([string]$name) {
        $this.Name = $name
        $this.ProcessPatterns = [List[string]]::new()
        $this.RelatedServices = [List[string]]::new()
        $this.IsEnabled = $true
        $this.Priority = [ProcessPriority]::Medium
        $this.AggressiveKill = $false
    }

    # Constructor desde hashtable (para cargar desde JSON)
    Category([string]$name, [hashtable]$data) {
        $this.Name = $name
        $this.Description = $data.description
        $this.Icon = $data.icon
        $this.Color = $data.color
        $this.IsEnabled = $true

        # Mapear prioridad
        $this.Priority = switch ($data.priority) {
            "low" { [ProcessPriority]::Low }
            "medium" { [ProcessPriority]::Medium }
            "high" { [ProcessPriority]::High }
            "critical" { [ProcessPriority]::Critical }
            default { [ProcessPriority]::Medium }
        }

        $this.AggressiveKill = if ($null -ne $data.aggressiveKill) { $data.aggressiveKill } else { $false }

        # Inicializar listas
        $this.ProcessPatterns = [List[string]]::new()
        if ($data.processes) {
            foreach ($process in $data.processes) {
                $this.ProcessPatterns.Add($process)
            }
        }

        $this.RelatedServices = [List[string]]::new()
        if ($data.relatedServices) {
            foreach ($service in $data.relatedServices) {
                $this.RelatedServices.Add($service)
            }
        }
    }

    [bool] MatchesProcess([string]$processName) {
        foreach ($pattern in $this.ProcessPatterns) {
            if ($processName -like "*$pattern*") {
                return $true
            }
        }
        return $false
    }

    [string] ToString() {
        return "$($this.Name) - $($this.ProcessPatterns.Count) patterns"
    }
}

# Clase para estadÃ­sticas de categorÃ­a
class CategoryStatistics {
    [string]$CategoryName
    [int]$ProcessCount
    [double]$TotalMemoryMB
    [int]$SelectedCount
    [double]$SelectedMemoryMB

    CategoryStatistics([string]$name) {
        $this.CategoryName = $name
        $this.ProcessCount = 0
        $this.TotalMemoryMB = 0
        $this.SelectedCount = 0
        $this.SelectedMemoryMB = 0
    }

    [void] AddProcess([ProcessModel]$process, [bool]$isSelected) {
        $this.ProcessCount++
        $this.TotalMemoryMB += $process.MemoryMB

        if ($isSelected) {
            $this.SelectedCount++
            $this.SelectedMemoryMB += $process.MemoryMB
        }
    }

    [string] GetSummary() {
        return "$($this.ProcessCount) procesos - $([Math]::Round($this.TotalMemoryMB, 2)) MB"
    }

    [string] GetSelectedSummary() {
        return "$($this.SelectedCount) seleccionados - $([Math]::Round($this.SelectedMemoryMB, 2)) MB"
    }
}
