# WindowsProcessManager.ps1 - ImplementaciÃ³n especÃ­fica de Windows para manejo de procesos
using namespace System.Collections.Generic
using namespace System.Diagnostics

# Cargar dependencias
. "$PSScriptRoot\..\..\Core\Models\Process.ps1"
. "$PSScriptRoot\..\..\Core\Services\IProcessService.ps1"

class WindowsProcessManager {
    hidden [hashtable]$WmiCache
    hidden [DateTime]$LastWmiUpdate
    hidden [int]$WmiCacheTimeout = 5000  # 5 segundos

    WindowsProcessManager() {
        $this.WmiCache = @{}
        $this.LastWmiUpdate = [DateTime]::MinValue
    }

    # Obtener informaciÃ³n detallada del proceso usando WMI
    [hashtable] GetProcessDetails([int]$processId) {
        try {
            # Verificar cachÃ©
            if ($this.WmiCache.ContainsKey($processId) -and
                ([DateTime]::Now - $this.LastWmiUpdate).TotalMilliseconds -lt $this.WmiCacheTimeout) {
                return $this.WmiCache[$processId]
            }

            $wmiProcess = Get-WmiObject Win32_Process -Filter "ProcessId = $processId" -ErrorAction Stop

            if ($null -eq $wmiProcess) {
                return $null
            }

            $details = @{
                ProcessId          = $wmiProcess.ProcessId
                Name               = $wmiProcess.Name
                ExecutablePath     = $wmiProcess.ExecutablePath
                CommandLine        = $wmiProcess.CommandLine
                CreationDate       = $this.ConvertWmiDateTime($wmiProcess.CreationDate)
                ParentProcessId    = $wmiProcess.ParentProcessId
                ThreadCount        = $wmiProcess.ThreadCount
                HandleCount        = $wmiProcess.HandleCount
                WorkingSetSize     = $wmiProcess.WorkingSetSize
                VirtualSize        = $wmiProcess.VirtualSize
                PageFileUsage      = $wmiProcess.PageFileUsage
                PeakWorkingSetSize = $wmiProcess.PeakWorkingSetSize
                Priority           = $wmiProcess.Priority
                Owner              = $this.GetProcessOwner($wmiProcess)
            }

            # Actualizar cachÃ©
            $this.WmiCache[$processId] = $details
            $this.LastWmiUpdate = [DateTime]::Now

            return $details
        } catch {
            Write-Verbose "Error obteniendo detalles WMI del proceso $processId : $_"
            return $null
        }
    }

    # Obtener propietario del proceso
    [string] GetProcessOwner([object]$wmiProcess) {
        try {
            $owner = $wmiProcess.GetOwner()
            if ($owner.ReturnValue -eq 0) {
                return "$($owner.Domain)\$($owner.User)"
            }
        } catch {
            Write-Verbose "No se pudo obtener el propietario del proceso"
        }
        return "N/A"
    }

    # Cerrar proceso con diferentes mÃ©todos
    [bool] TerminateProcess([int]$processId, [int]$method) {
        try {
            switch ($method) {
                1 {
                    # MÃ©todo .NET
                    $process = [Process]::GetProcessById($processId)
                    $process.Kill()
                    return $true
                }
                2 {
                    # PowerShell cmdlet
                    Stop-Process -Id $processId -Force -ErrorAction Stop
                    return $true
                }
                3 {
                    # WMI
                    $wmiProcess = Get-WmiObject Win32_Process -Filter "ProcessId = $processId"
                    if ($null -ne $wmiProcess) {
                        $result = $wmiProcess.Terminate()
                        return $result.ReturnValue -eq 0
                    }
                    return $false
                }
                4 {
                    # Taskkill
                    $output = & taskkill /PID $processId /F 2>&1
                    return $LASTEXITCODE -eq 0
                }
                5 {
                    # TerminateProcess API via .NET
                    Add-Type -TypeDefinition @"
                        using System;
                        using System.Runtime.InteropServices;
                        public class Win32 {
                            [DllImport("kernel32.dll", SetLastError = true)]
                            public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

                            [DllImport("kernel32.dll", SetLastError = true)]
                            public static extern bool TerminateProcess(IntPtr hProcess, uint uExitCode);

                            [DllImport("kernel32.dll", SetLastError = true)]
                            public static extern bool CloseHandle(IntPtr hObject);

                            public const int PROCESS_TERMINATE = 0x0001;
                        }
"@
                    $hProcess = [Win32]::OpenProcess([Win32]::PROCESS_TERMINATE, $false, $processId)
                    if ($hProcess -ne [IntPtr]::Zero) {
                        $terminated = [Win32]::TerminateProcess($hProcess, 0)
                        [Win32]::CloseHandle($hProcess) | Out-Null
                        return $terminated
                    }
                    return $false
                }
                default {
                    return $false
                }
            }
        } catch {
            Write-Verbose "Error terminando proceso con mÃ©todo $method : $_"
            return $false
        }
    }

    # Obtener Ã¡rbol de procesos (proceso y sus hijos)
    [List[int]] GetProcessTree([int]$parentProcessId) {
        $processTree = [List[int]]::new()
        $processTree.Add($parentProcessId)

        try {
            $childProcesses = Get-WmiObject Win32_Process -Filter "ParentProcessId = $parentProcessId"

            foreach ($child in $childProcesses) {
                $childTree = $this.GetProcessTree($child.ProcessId)
                foreach ($childPid in $childTree) {
                    if (-not $processTree.Contains($childPid)) {
                        $processTree.Add($childPid)
                    }
                }
            }
        } catch {
            Write-Verbose "Error obteniendo Ã¡rbol de procesos: $_"
        }

        return $processTree
    }

    # Suspender proceso
    [bool] SuspendProcess([int]$processId) {
        try {
            $process = Get-Process -Id $processId -ErrorAction Stop
            $process.Suspend()
            return $true
        } catch {
            Write-Verbose "Error suspendiendo proceso: $_"
            return $false
        }
    }

    # Reanudar proceso
    [bool] ResumeProcess([int]$processId) {
        try {
            $process = Get-Process -Id $processId -ErrorAction Stop
            $process.Resume()
            return $true
        } catch {
            Write-Verbose "Error reanudando proceso: $_"
            return $false
        }
    }

    # Cambiar prioridad del proceso
    [bool] SetProcessPriority([int]$processId, [ProcessPriorityClass]$priority) {
        try {
            $process = Get-Process -Id $processId -ErrorAction Stop
            $process.PriorityClass = $priority
            return $true
        } catch {
            Write-Verbose "Error cambiando prioridad del proceso: $_"
            return $false
        }
    }

    # Obtener informaciÃ³n de memoria del sistema
    [hashtable] GetSystemMemoryInfo() {
        try {
            $os = Get-WmiObject Win32_OperatingSystem

            return @{
                TotalPhysicalMemory = $os.TotalVisibleMemorySize * 1KB
                FreePhysicalMemory  = $os.FreePhysicalMemory * 1KB
                UsedPhysicalMemory  = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB
                MemoryUsagePercent  = [Math]::Round(((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100), 2)
                TotalVirtualMemory  = $os.TotalVirtualMemorySize * 1KB
                FreeVirtualMemory   = $os.FreeVirtualMemory * 1KB
            }
        } catch {
            Write-Error "Error obteniendo informaciÃ³n de memoria: $_"
            return @{}
        }
    }

    # Verificar si un proceso estÃ¡ respondiendo
    [bool] IsProcessResponding([int]$processId) {
        try {
            $process = Get-Process -Id $processId -ErrorAction Stop
            return $process.Responding
        } catch {
            return $false
        }
    }

    # Convertir fecha/hora WMI a DateTime
    hidden [DateTime] ConvertWmiDateTime([string]$wmiDateTime) {
        try {
            if ([string]::IsNullOrEmpty($wmiDateTime)) {
                return [DateTime]::MinValue
            }
            return [System.Management.ManagementDateTimeConverter]::ToDateTime($wmiDateTime)
        } catch {
            return [DateTime]::MinValue
        }
    }

    # Limpiar cachÃ©
    [void] ClearCache() {
        $this.WmiCache.Clear()
        $this.LastWmiUpdate = [DateTime]::MinValue
    }

    # Obtener procesos que consumen mÃ¡s recursos
    [List[hashtable]] GetTopProcessesByMemory([int]$count) {
        $topProcesses = [List[hashtable]]::new()

        try {
            $processes = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First $count

            foreach ($proc in $processes) {
                $topProcesses.Add(@{
                        ProcessId = $proc.Id
                        Name      = $proc.ProcessName
                        MemoryMB  = [Math]::Round($proc.WorkingSet64 / 1MB, 2)
                        CPU       = $proc.CPU
                        Threads   = $proc.Threads.Count
                        Handles   = $proc.HandleCount
                    })
            }
        } catch {
            Write-Error "Error obteniendo procesos top: $_"
        }

        return $topProcesses
    }
}
