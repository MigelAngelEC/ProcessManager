# Process.ps1 - Modelo de Proceso
using namespace System.Management.Automation

class ProcessModel {
    [int]$Id
    [string]$Name
    [string]$ProcessName
    [double]$MemoryMB
    [string]$Category
    [ProcessPriority]$Priority
    [bool]$IsSelected
    [bool]$IsProtected
    [DateTime]$StartTime

    ProcessModel() {
        $this.IsSelected = $false
        $this.IsProtected = $false
        $this.Priority = [ProcessPriority]::Medium
    }

    ProcessModel([System.Diagnostics.Process]$process, [string]$category) {
        $this.Id = $process.Id
        $this.Name = $process.ProcessName
        $this.ProcessName = $process.ProcessName
        $this.MemoryMB = [Math]::Round($process.WorkingSet64 / 1MB, 2)
        $this.Category = $category
        $this.IsSelected = $false
        $this.IsProtected = $false
        $this.Priority = [ProcessPriority]::Medium

        try {
            $this.StartTime = $process.StartTime
        } catch {
            $this.StartTime = [DateTime]::MinValue
        }
    }

    [string] ToString() {
        return "$($this.Name) (PID: $($this.Id)) - $($this.MemoryMB) MB"
    }

    [string] GetDisplayName() {
        return "$($this.Name) (PID: $($this.Id)) - $($this.MemoryMB) MB - $($this.Category)"
    }
}

enum ProcessPriority {
    Low
    Medium
    High
    Critical
}

# Clase para resultados de operaciones de proceso
class ProcessOperationResult {
    [bool]$Success
    [ProcessModel]$Process
    [string]$Message
    [Exception]$Exception

    ProcessOperationResult([bool]$success, [ProcessModel]$process) {
        $this.Success = $success
        $this.Process = $process
    }

    ProcessOperationResult([bool]$success, [ProcessModel]$process, [string]$message) {
        $this.Success = $success
        $this.Process = $process
        $this.Message = $message
    }

    ProcessOperationResult([ProcessModel]$process, [Exception]$exception) {
        $this.Success = $false
        $this.Process = $process
        $this.Exception = $exception
        $this.Message = $exception.Message
    }
}
