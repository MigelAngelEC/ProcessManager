# Process Manager - Version Consola para Windows 11 24H2
# Alternativa sin interfaz grafica

Clear-Host
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                    PROCESS MANAGER - CONSOLA                   " -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Configuracion de categorias
$ProcessCategories = @{
    "ASUS Software" = @("asus_framework", "ArmourySocketServer", "ADU", "ASUS DriverHub", "ArmourySwAgent", "AcPowerNotification", "atkexComSvc", "AsusCertService", "AsusFanControlService", "AsusUpdateCheck")
    "Comunicacion" = @("WhatsApp", "ChatGPT", "claude", "copilot")
    "Apple/iCloud" = @("ApplePhotoStreams", "iCloudHome", "iCloudDrive", "iCloudPhotos", "iCloudCKKS", "iCloudOutlookConfig", "secd", "APSDaemon")
    "Corsair/iCUE" = @("iCUE", "QmlRenderer", "CorsairCpuIdService", "CorsairDeviceControlService", "iCUEDevicePluginHost", "iCUEUpdateService", "CorsairGamingAudioCfgService")
    "Elgato Software" = @("ElgatoAudioControlServer", "ElgatoAudioControlServerWatcher", "StreamDeck", "Elgato", "4KCaptureUtility", "GameCapture", "CameraHub")
    "AVG Software" = @("TuneupUI", "TuneupSvc", "Vpn", "VpnSvc")
    "Driver Booster" = @("Scheduler")
    "Utilidades de Sistema" = @("Everything", "DisplayFusion", "DisplayFusionHookApp", "PowerToys", "RTSS", "RTSSHooksLoader", "EncoderServer", "MSIAfterburner", "ShareX", "TranslucentTB")
    "Fondos/Personalizacion" = @("wallpaper32", "wallpaperservice32")
    "Widgets/Microsoft" = @("Widgets", "msedgewebview2", "StartMenuExperienceHost", "PhoneExperienceHost")
}

# Funcion para obtener procesos por categoria
function Get-ProcessesByCategory {
    param($Category, $Patterns)
    
    $processes = @()
    foreach ($pattern in $Patterns) {
        $foundProcesses = Get-Process | Where-Object { 
            $_.ProcessName -like "*$pattern*" -and $_.Id -ne $PID 
        }
        foreach ($proc in $foundProcesses) {
            $memoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            $processes += [PSCustomObject]@{
                Name = $proc.ProcessName
                PID = $proc.Id
                MemoryMB = $memoryMB
                Category = $Category
                FullName = "$($proc.ProcessName) (PID: $($proc.Id)) - $memoryMB MB"
            }
        }
    }
    return $processes | Sort-Object MemoryMB -Descending
}

# Funcion para mostrar menu
function Show-Menu {
    Write-Host ""
    Write-Host "┌─────────────────────────────────────────────────────────────┐" -ForegroundColor White
    Write-Host "│                         OPCIONES                           │" -ForegroundColor White  
    Write-Host "├─────────────────────────────────────────────────────────────┤" -ForegroundColor White
    Write-Host "│  1. Ver procesos por categoria                             │" -ForegroundColor Green
    Write-Host "│  2. Cerrar TODOS los procesos recomendados                 │" -ForegroundColor Red
    Write-Host "│  3. Cerrar procesos por categoria especifica               │" -ForegroundColor Yellow
    Write-Host "│  4. Cerrar proceso individual                              │" -ForegroundColor Cyan
    Write-Host "│  5. Salir                                                  │" -ForegroundColor Gray
    Write-Host "└─────────────────────────────────────────────────────────────┘" -ForegroundColor White
    Write-Host ""
}

# Funcion para cerrar procesos
function Close-Processes {
    param($ProcessesToClose)
    
    if ($ProcessesToClose.Count -eq 0) {
        Write-Host "No hay procesos para cerrar." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "Cerrando $($ProcessesToClose.Count) procesos..." -ForegroundColor Red
    Write-Host "────────────────────────────────────────────────" -ForegroundColor Gray
    
    $successCount = 0
    $errorCount = 0
    
    foreach ($proc in $ProcessesToClose) {
        try {
            $process = Get-Process -Id $proc.PID -ErrorAction Stop
            $process.Kill()
            Write-Host "✓ Cerrado: $($proc.Name) (PID: $($proc.PID))" -ForegroundColor Green
            $successCount++
            Start-Sleep -Milliseconds 200
        } catch {
            Write-Host "✗ Error: $($proc.Name) (PID: $($proc.PID)) - $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
    }
    
    Write-Host ""
    Write-Host "Resumen:" -ForegroundColor Cyan
    Write-Host "  Exitosos: $successCount" -ForegroundColor Green
    Write-Host "  Errores: $errorCount" -ForegroundColor Red
    Write-Host ""
}

# Bucle principal
do {
    Show-Menu
    $choice = Read-Host "Selecciona una opcion (1-5)"
    
    switch ($choice) {
        "1" {
            Clear-Host
            Write-Host "PROCESOS ENCONTRADOS POR CATEGORIA:" -ForegroundColor Yellow
            Write-Host "================================================================" -ForegroundColor Yellow
            
            $totalMemory = 0
            $totalProcesses = 0
            
            foreach ($category in $ProcessCategories.Keys) {
                $processes = Get-ProcessesByCategory -Category $category -Patterns $ProcessCategories[$category]
                
                if ($processes.Count -gt 0) {
                    $categoryMemory = ($processes | Measure-Object -Property MemoryMB -Sum).Sum
                    $totalMemory += $categoryMemory
                    $totalProcesses += $processes.Count
                    
                    Write-Host ""
                    Write-Host "$category ($($processes.Count) procesos - $([math]::Round($categoryMemory, 2)) MB)" -ForegroundColor Cyan
                    Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor Gray
                    
                    foreach ($proc in $processes) {
                        Write-Host "   $($proc.FullName)" -ForegroundColor White
                    }
                }
            }
            
            Write-Host ""
            Write-Host "================================================================" -ForegroundColor Yellow
            Write-Host "TOTAL: $totalProcesses procesos usando $([math]::Round($totalMemory, 2)) MB" -ForegroundColor Green
            Write-Host ""
            Read-Host "Presiona Enter para continuar"
            Clear-Host
        }
        
        "2" {
            Clear-Host
            Write-Host "CERRANDO TODOS LOS PROCESOS RECOMENDADOS" -ForegroundColor Red
            Write-Host "================================================================" -ForegroundColor Red
            
            $allProcesses = @()
            foreach ($category in $ProcessCategories.Keys) {
                $processes = Get-ProcessesByCategory -Category $category -Patterns $ProcessCategories[$category]
                $allProcesses += $processes
            }
            
            if ($allProcesses.Count -gt 0) {
                $totalMemory = ($allProcesses | Measure-Object -Property MemoryMB -Sum).Sum
                Write-Host "Se encontraron $($allProcesses.Count) procesos que liberaran aprox. $([math]::Round($totalMemory, 2)) MB" -ForegroundColor Yellow
                Write-Host ""
                
                $confirm = Read-Host "Estas seguro? (S/N)"
                if ($confirm -eq "S" -or $confirm -eq "s") {
                    Close-Processes -ProcessesToClose $allProcesses
                } else {
                    Write-Host "Operacion cancelada." -ForegroundColor Yellow
                }
            } else {
                Write-Host "No se encontraron procesos para cerrar." -ForegroundColor Green
            }
            
            Read-Host "Presiona Enter para continuar"
            Clear-Host
        }
        
        "3" {
            Clear-Host
            Write-Host "SELECCIONAR CATEGORIA:" -ForegroundColor Yellow
            Write-Host "================================================================" -ForegroundColor Yellow
            
            $categoryList = $ProcessCategories.Keys | Sort-Object
            for ($i = 0; $i -lt $categoryList.Count; $i++) {
                $category = $categoryList[$i]
                $processes = Get-ProcessesByCategory -Category $category -Patterns $ProcessCategories[$category]
                if ($processes.Count -gt 0) {
                    $categoryMemory = ($processes | Measure-Object -Property MemoryMB -Sum).Sum
                    Write-Host "$($i + 1). $category ($($processes.Count) procesos - $([math]::Round($categoryMemory, 2)) MB)" -ForegroundColor Cyan
                }
            }
            
            Write-Host ""
            $categoryChoice = Read-Host "Selecciona el numero de categoria"
            
            if ($categoryChoice -match '^\d+$' -and [int]$categoryChoice -le $categoryList.Count -and [int]$categoryChoice -gt 0) {
                $selectedCategory = $categoryList[[int]$categoryChoice - 1]
                $processes = Get-ProcessesByCategory -Category $selectedCategory -Patterns $ProcessCategories[$selectedCategory]
                
                if ($processes.Count -gt 0) {
                    Write-Host ""
                    Write-Host "Procesos en $selectedCategory" -ForegroundColor Green
                    foreach ($proc in $processes) {
                        Write-Host "  $($proc.FullName)" -ForegroundColor White
                    }
                    
                    Write-Host ""
                    $confirm = Read-Host "Cerrar todos estos procesos? (S/N)"
                    if ($confirm -eq "S" -or $confirm -eq "s") {
                        Close-Processes -ProcessesToClose $processes
                    } else {
                        Write-Host "Operacion cancelada." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "No hay procesos en esta categoria." -ForegroundColor Yellow
                }
            } else {
                Write-Host "Seleccion invalida." -ForegroundColor Red
            }
            
            Read-Host "Presiona Enter para continuar"
            Clear-Host
        }
        
        "4" {
            Clear-Host
            Write-Host "CERRAR PROCESO INDIVIDUAL:" -ForegroundColor Yellow
            Write-Host "================================================================" -ForegroundColor Yellow
            
            $processName = Read-Host "Ingresa el nombre del proceso (ej: notepad, chrome)"
            if ($processName) {
                $foundProcesses = Get-Process | Where-Object { $_.ProcessName -like "*$processName*" }
                
                if ($foundProcesses.Count -gt 0) {
                    Write-Host ""
                    Write-Host "Procesos encontrados:" -ForegroundColor Green
                    for ($i = 0; $i -lt $foundProcesses.Count; $i++) {
                        $proc = $foundProcesses[$i]
                        $memoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
                        Write-Host "$($i + 1). $($proc.ProcessName) (PID: $($proc.Id)) - $memoryMB MB" -ForegroundColor White
                    }
                    
                    Write-Host ""
                    $procChoice = Read-Host "Selecciona el numero del proceso"
                    
                    if ($procChoice -match '^\d+$' -and [int]$procChoice -le $foundProcesses.Count -and [int]$procChoice -gt 0) {
                        $selectedProcess = $foundProcesses[[int]$procChoice - 1]
                        $processObj = [PSCustomObject]@{
                            Name = $selectedProcess.ProcessName
                            PID = $selectedProcess.Id
                            MemoryMB = [math]::Round($selectedProcess.WorkingSet64 / 1MB, 2)
                        }
                        Close-Processes -ProcessesToClose @($processObj)
                    } else {
                        Write-Host "Seleccion invalida." -ForegroundColor Red
                    }
                } else {
                    Write-Host "No se encontraron procesos con ese nombre." -ForegroundColor Red
                }
            }
            
            Read-Host "Presiona Enter para continuar"
            Clear-Host
        }
        
        "5" {
            Write-Host "Hasta luego!" -ForegroundColor Green
            Start-Sleep -Seconds 1
            break
        }
        
        default {
            Write-Host "Opcion invalida. Por favor selecciona 1-5." -ForegroundColor Red
            Start-Sleep -Seconds 2
            Clear-Host
        }
    }
} while ($true)