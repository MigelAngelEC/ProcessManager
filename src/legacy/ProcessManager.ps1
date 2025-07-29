# Process Manager GUI - Cerrar Procesos en Bulk
# UI/UX Mejorado para Windows 11 24H2 - Sin Emojis

# Configurar politica de ejecucion para este script
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
} catch {
    Write-Host "No se pudo cambiar la politica de ejecucion" -ForegroundColor Yellow
}

# Verificar que estamos en modo STA (Single Threaded Apartment)
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Write-Host "Reiniciando en modo STA..." -ForegroundColor Yellow
    powershell.exe -STA -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Path
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Verificar disponibilidad de Windows Forms
try {
    $testForm = New-Object System.Windows.Forms.Form
    $testForm.Dispose()
    Write-Host "Windows Forms disponible" -ForegroundColor Green
} catch {
    Write-Host "Error: Windows Forms no esta disponible" -ForegroundColor Red
    Write-Host "Detalles: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Presiona Enter para continuar"
    exit
}

# Configuracion de categorias y patrones de procesos
$ProcessCategories = @{
    "ASUS Software"          = @("asus_framework", "ArmourySocketServer", "ADU", "ASUS DriverHub", "ArmourySwAgent", "AcPowerNotification", "atkexComSvc", "AsusCertService", "AsusFanControlService", "AsusUpdateCheck")
    "Comunicacion"           = @("WhatsApp", "ChatGPT", "claude", "copilot")
    "Apple/iCloud"           = @("ApplePhotoStreams", "iCloudHome", "iCloudDrive", "iCloudPhotos", "iCloudCKKS", "iCloudOutlookConfig", "secd", "APSDaemon")
    "Corsair/iCUE"           = @("iCUE", "QmlRenderer", "CorsairCpuIdService", "CorsairDeviceControlService", "iCUEDevicePluginHost", "iCUEUpdateService", "CorsairGamingAudioCfgService")
    "Elgato Software"        = @("ElgatoAudioControlServer", "ElgatoAudioControlServerWatcher", "StreamDeck", "Elgato", "4KCaptureUtility", "GameCapture", "CameraHub")
    "AVG Software"           = @("TuneupUI", "TuneupSvc", "Vpn", "VpnSvc")
    "Driver Booster"         = @("Scheduler")
    "Utilidades Sistema"     = @("Everything", "DisplayFusion", "DisplayFusionHookApp", "PowerToys", "RTSS", "RTSSHooksLoader", "EncoderServer", "MSIAfterburner", "ShareX", "TranslucentTB")
    "Fondos/Personalizacion" = @("wallpaper32", "wallpaperservice32")
    "Widgets/Microsoft"      = @("Widgets", "msedgewebview2", "StartMenuExperienceHost", "PhoneExperienceHost")
}

# Archivo de configuracion
$ConfigFile = "$env:USERPROFILE\Documents\ProcessManagerConfig.json"

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
                Name     = $proc.ProcessName
                PID      = $proc.Id
                MemoryMB = $memoryMB
                Category = $Category
                FullName = "$($proc.ProcessName) (PID: $($proc.Id)) - $memoryMB MB"
            }
        }
    }
    return $processes | Sort-Object MemoryMB -Descending
}

# Funcion para cargar configuracion guardada
function Load-SavedConfig {
    if (Test-Path $ConfigFile) {
        try {
            return Get-Content $ConfigFile | ConvertFrom-Json
        } catch {
            return @()
        }
    }
    return @()
}

# Funcion para guardar configuracion
function Save-Config {
    param($SelectedProcesses)
    $SelectedProcesses | ConvertTo-Json | Set-Content $ConfigFile
    [System.Windows.Forms.MessageBox]::Show("Configuracion guardada exitosamente en:`n$ConfigFile", "Guardado", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# Funcion para cerrar procesos seleccionados
function Close-SelectedProcesses {
    param($ProcessesToClose)

    $results = @()
    $successCount = 0
    $errorCount = 0
    $totalMemoryFreed = 0

    foreach ($proc in $ProcessesToClose) {
        try {
            $process = Get-Process -Id $proc.PID -ErrorAction Stop
            $totalMemoryFreed += $proc.MemoryMB
            $process.Kill()
            $results += "EXITOSO: $($proc.Name) (PID: $($proc.PID)) - $($proc.MemoryMB) MB liberados"
            $successCount++
            Start-Sleep -Milliseconds 150
        } catch {
            $results += "ERROR: $($proc.Name) (PID: $($proc.PID)) - $($_.Exception.Message)"
            $errorCount++
        }
    }

    $summary = "RESUMEN DE LA OPERACION`n" +
    "===============================================`n" +
    "Procesos cerrados exitosamente: $successCount`n" +
    "Errores: $errorCount`n" +
    "Memoria total liberada: $([math]::Round($totalMemoryFreed, 2)) MB`n`n" +
    "DETALLES:`n" +
    "===============================================`n" +
    ($results -join "`n")

    [System.Windows.Forms.MessageBox]::Show($summary, "Resultado Final", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# Crear formulario principal con diseÃ±o moderno
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Process Manager Pro - Optimizador de Memoria"
$Form.Size = New-Object System.Drawing.Size(1200, 800)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "Sizable"
$Form.MinimumSize = New-Object System.Drawing.Size(1000, 700)
$Form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Crear barra de titulo personalizada
$TitlePanel = New-Object System.Windows.Forms.Panel
$TitlePanel.Dock = "Top"
$TitlePanel.Height = 80
$TitlePanel.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Process Manager Pro"
$TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$TitleLabel.ForeColor = [System.Drawing.Color]::White
$TitleLabel.Location = New-Object System.Drawing.Point(20, 15)
$TitleLabel.Size = New-Object System.Drawing.Size(400, 35)

$SubTitleLabel = New-Object System.Windows.Forms.Label
$SubTitleLabel.Text = "Optimiza tu sistema cerrando procesos innecesarios"
$SubTitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$SubTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$SubTitleLabel.Location = New-Object System.Drawing.Point(20, 45)
$SubTitleLabel.Size = New-Object System.Drawing.Size(400, 25)

$TitlePanel.Controls.Add($TitleLabel)
$TitlePanel.Controls.Add($SubTitleLabel)

# Crear panel principal con layout mejorado
$MainContainer = New-Object System.Windows.Forms.Panel
$MainContainer.Dock = "Fill"
$MainContainer.Padding = New-Object System.Windows.Forms.Padding(20)
$MainContainer.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 250)

# Crear splitter container para divisiÃ³n responsive
$SplitContainer = New-Object System.Windows.Forms.SplitContainer
$SplitContainer.Dock = "Fill"
$SplitContainer.SplitterDistance = 600
$SplitContainer.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 250)

# Panel izquierdo - Categorias
$LeftPanel = New-Object System.Windows.Forms.GroupBox
$LeftPanel.Text = "Categorias de Procesos Detectados"
$LeftPanel.Dock = "Fill"
$LeftPanel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$LeftPanel.ForeColor = [System.Drawing.Color]::FromArgb(0, 80, 140)
$LeftPanel.Padding = New-Object System.Windows.Forms.Padding(15)

# Crear TreeView para mejor organizaciÃ³n
$ProcessTreeView = New-Object System.Windows.Forms.TreeView
$ProcessTreeView.Dock = "Fill"
$ProcessTreeView.CheckBoxes = $true
$ProcessTreeView.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$ProcessTreeView.BackColor = [System.Drawing.Color]::White
$ProcessTreeView.BorderStyle = "FixedSingle"

# Panel derecho - Lista de seleccionados
$RightPanel = New-Object System.Windows.Forms.GroupBox
$RightPanel.Text = "Procesos Seleccionados para Cerrar"
$RightPanel.Dock = "Fill"
$RightPanel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$RightPanel.ForeColor = [System.Drawing.Color]::FromArgb(180, 50, 50)
$RightPanel.Padding = New-Object System.Windows.Forms.Padding(15)

# Lista mejorada de procesos seleccionados
$SelectedListView = New-Object System.Windows.Forms.ListView
$SelectedListView.Dock = "Fill"
$SelectedListView.View = "Details"
$SelectedListView.FullRowSelect = $true
$SelectedListView.GridLines = $true
$SelectedListView.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$SelectedListView.BackColor = [System.Drawing.Color]::White

# Agregar columnas al ListView
$SelectedListView.Columns.Add("Proceso", 200) | Out-Null
$SelectedListView.Columns.Add("PID", 80) | Out-Null
$SelectedListView.Columns.Add("Memoria (MB)", 100) | Out-Null
$SelectedListView.Columns.Add("Categoria", 150) | Out-Null

# Panel de estadÃ­sticas
$StatsPanel = New-Object System.Windows.Forms.Panel
$StatsPanel.Dock = "Bottom"
$StatsPanel.Height = 60
$StatsPanel.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$StatsPanel.BorderStyle = "FixedSingle"

$StatsLabel = New-Object System.Windows.Forms.Label
$StatsLabel.Text = "Estadisticas: 0 procesos seleccionados | 0 MB a liberar"
$StatsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$StatsLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 100, 0)
$StatsLabel.Location = New-Object System.Drawing.Point(15, 15)
$StatsLabel.Size = New-Object System.Drawing.Size(500, 30)

$StatsPanel.Controls.Add($StatsLabel)
$RightPanel.Controls.Add($StatsPanel)
$RightPanel.Controls.Add($SelectedListView)

# Variables globales
$AllProcesses = @{}
$SelectedProcesses = @{}

# FunciÃ³n para actualizar estadÃ­sticas
function Update-Stats {
    $selectedCount = $SelectedProcesses.Count
    $totalMemory = ($SelectedProcesses.Values | Measure-Object -Property MemoryMB -Sum).Sum
    if ($totalMemory -eq $null) { $totalMemory = 0 }

    $StatsLabel.Text = "Estadisticas: $selectedCount procesos seleccionados | $([math]::Round($totalMemory, 2)) MB a liberar"

    # Actualizar ListView
    $SelectedListView.Items.Clear()
    foreach ($proc in $SelectedProcesses.Values) {
        $item = New-Object System.Windows.Forms.ListViewItem($proc.Name)
        $item.SubItems.Add($proc.PID.ToString()) | Out-Null
        $item.SubItems.Add($proc.MemoryMB.ToString()) | Out-Null
        $item.SubItems.Add($proc.Category) | Out-Null
        $SelectedListView.Items.Add($item) | Out-Null
    }
}

# Poblar TreeView con categorÃ­as y procesos
foreach ($category in $ProcessCategories.Keys) {
    $processes = Get-ProcessesByCategory -Category $category -Patterns $ProcessCategories[$category]

    if ($processes.Count -gt 0) {
        $categoryMemory = ($processes | Measure-Object -Property MemoryMB -Sum).Sum

        # Crear nodo de categorÃ­a
        $categoryNode = New-Object System.Windows.Forms.TreeNode("$category ($($processes.Count) procesos - $([math]::Round($categoryMemory, 2)) MB)")
        $categoryNode.ForeColor = [System.Drawing.Color]::FromArgb(0, 80, 140)
        $categoryNode.NodeFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

        # Agregar procesos como nodos hijos
        foreach ($process in $processes) {
            $processNode = New-Object System.Windows.Forms.TreeNode($process.FullName)
            $processNode.Tag = $process
            $AllProcesses[$processNode] = $process
            $categoryNode.Nodes.Add($processNode) | Out-Null
        }

        $ProcessTreeView.Nodes.Add($categoryNode) | Out-Null
    }
}

# Evento para manejar selecciÃ³n de checkboxes en TreeView
$ProcessTreeView.Add_AfterCheck({
        param($sender, $e)

        if ($e.Node.Tag -ne $null) {
            # Es un proceso individual
            $process = $e.Node.Tag
            if ($e.Node.Checked) {
                $SelectedProcesses[$e.Node] = $process
            } else {
                $SelectedProcesses.Remove($e.Node)
            }
        } else {
            # Es una categorÃ­a - marcar/desmarcar todos los hijos
            foreach ($childNode in $e.Node.Nodes) {
                $childNode.Checked = $e.Node.Checked
                $process = $childNode.Tag
                if ($e.Node.Checked) {
                    $SelectedProcesses[$childNode] = $process
                } else {
                    $SelectedProcesses.Remove($childNode)
                }
            }
        }

        Update-Stats
    })

$LeftPanel.Controls.Add($ProcessTreeView)

# Configurar SplitContainer
$SplitContainer.Panel1.Controls.Add($LeftPanel)
$SplitContainer.Panel2.Controls.Add($RightPanel)

# Panel de botones con diseÃ±o moderno
$ButtonPanel = New-Object System.Windows.Forms.Panel
$ButtonPanel.Dock = "Bottom"
$ButtonPanel.Height = 80
$ButtonPanel.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$ButtonPanel.Padding = New-Object System.Windows.Forms.Padding(20, 15, 20, 15)

# FunciÃ³n para crear botones modernos
function Create-ModernButton {
    param($Text, $BackColor, $ForeColor, $Width = 160)

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object System.Drawing.Size($Width, 50)
    $button.BackColor = $BackColor
    $button.ForeColor = $ForeColor
    $button.FlatStyle = "Flat"
    $button.FlatAppearance.BorderSize = 0
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $button.Cursor = "Hand"

    # Efectos hover
    $button.Add_MouseEnter({
            $this.FlatAppearance.BorderSize = 2
            $this.FlatAppearance.BorderColor = [System.Drawing.Color]::White
        })

    $button.Add_MouseLeave({
            $this.FlatAppearance.BorderSize = 0
        })

    return $button
}

# Crear botones
$CloseButton = Create-ModernButton -Text "Cerrar Procesos" -BackColor ([System.Drawing.Color]::FromArgb(220, 50, 50)) -ForeColor ([System.Drawing.Color]::White) -Width 180
$SaveButton = Create-ModernButton -Text "Guardar Lista" -BackColor ([System.Drawing.Color]::FromArgb(0, 120, 215)) -ForeColor ([System.Drawing.Color]::White)
$LoadButton = Create-ModernButton -Text "Cargar Lista" -BackColor ([System.Drawing.Color]::FromArgb(0, 150, 0)) -ForeColor ([System.Drawing.Color]::White)
$RefreshButton = Create-ModernButton -Text "Actualizar" -BackColor ([System.Drawing.Color]::FromArgb(255, 140, 0)) -ForeColor ([System.Drawing.Color]::White)
$SelectAllButton = Create-ModernButton -Text "Seleccionar Todo" -BackColor ([System.Drawing.Color]::FromArgb(100, 100, 100)) -ForeColor ([System.Drawing.Color]::White) -Width 180
$ClearAllButton = Create-ModernButton -Text "Limpiar Todo" -BackColor ([System.Drawing.Color]::FromArgb(150, 150, 150)) -ForeColor ([System.Drawing.Color]::White)

# Posicionar botones
$CloseButton.Location = New-Object System.Drawing.Point(20, 15)
$SaveButton.Location = New-Object System.Drawing.Point(220, 15)
$LoadButton.Location = New-Object System.Drawing.Point(400, 15)
$RefreshButton.Location = New-Object System.Drawing.Point(580, 15)
$SelectAllButton.Location = New-Object System.Drawing.Point(760, 15)
$ClearAllButton.Location = New-Object System.Drawing.Point(960, 15)

# Eventos de botones
$CloseButton.Add_Click({
        if ($SelectedProcesses.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No hay procesos seleccionados para cerrar.", "Aviso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $totalMemory = ($SelectedProcesses.Values | Measure-Object -Property MemoryMB -Sum).Sum
        $message = "CONFIRMACION DE CIERRE`n`n" +
        "Estas a punto de cerrar $($SelectedProcesses.Count) procesos`n" +
        "Memoria que se liberara: $([math]::Round($totalMemory, 2)) MB`n`n" +
        "Esta accion no se puede deshacer.`n`n" +
        "Deseas continuar?"

        $result = [System.Windows.Forms.MessageBox]::Show($message, "Confirmar Cierre de Procesos", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -eq "Yes") {
            Close-SelectedProcesses -ProcessesToClose $SelectedProcesses.Values
            $Form.Close()
        }
    })

$SaveButton.Add_Click({
        if ($SelectedProcesses.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No hay procesos seleccionados para guardar.", "Aviso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $configData = @()
        foreach ($proc in $SelectedProcesses.Values) {
            $configData += @{
                Name     = $proc.Name
                Category = $proc.Category
            }
        }
        Save-Config -SelectedProcesses $configData
    })

$LoadButton.Add_Click({
        $savedConfig = Load-SavedConfig
        if ($savedConfig.Count -gt 0) {
            # Limpiar selecciÃ³n actual
            foreach ($node in $ProcessTreeView.Nodes) {
                $node.Checked = $false
                foreach ($childNode in $node.Nodes) {
                    $childNode.Checked = $false
                }
            }
            $SelectedProcesses.Clear()

            # Aplicar configuraciÃ³n guardada
            foreach ($savedProc in $savedConfig) {
                foreach ($node in $ProcessTreeView.Nodes) {
                    foreach ($childNode in $node.Nodes) {
                        if ($childNode.Tag.Name -eq $savedProc.Name -and $childNode.Tag.Category -eq $savedProc.Category) {
                            $childNode.Checked = $true
                            $SelectedProcesses[$childNode] = $childNode.Tag
                            break
                        }
                    }
                }
            }

            Update-Stats
            [System.Windows.Forms.MessageBox]::Show("Configuracion cargada exitosamente!`n`nSe han seleccionado $($savedConfig.Count) procesos.", "Configuracion Cargada", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            [System.Windows.Forms.MessageBox]::Show("No se encontro ninguna configuracion guardada.", "Sin Configuracion", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })

$RefreshButton.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show("Deseas actualizar la lista de procesos?`n`nEsto reiniciara la aplicacion.", "Actualizar Lista", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -eq "Yes") {
            $Form.Close()
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
        }
    })

$SelectAllButton.Add_Click({
        foreach ($node in $ProcessTreeView.Nodes) {
            $node.Checked = $true
        }
    })

$ClearAllButton.Add_Click({
        foreach ($node in $ProcessTreeView.Nodes) {
            $node.Checked = $false
        }
        $SelectedProcesses.Clear()
        Update-Stats
    })

$ButtonPanel.Controls.Add($CloseButton)
$ButtonPanel.Controls.Add($SaveButton)
$ButtonPanel.Controls.Add($LoadButton)
$ButtonPanel.Controls.Add($RefreshButton)
$ButtonPanel.Controls.Add($SelectAllButton)
$ButtonPanel.Controls.Add($ClearAllButton)

$MainContainer.Controls.Add($SplitContainer)

# Ensamblar formulario
$Form.Controls.Add($MainContainer)
$Form.Controls.Add($ButtonPanel)
$Form.Controls.Add($TitlePanel)

# Expandir categorÃ­as por defecto
foreach ($node in $ProcessTreeView.Nodes) {
    $node.Expand()
}

# Mostrar formulario
[System.Windows.Forms.Application]::EnableVisualStyles()
$Form.ShowDialog()
