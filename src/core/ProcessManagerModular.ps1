# Process Manager Pro - Version Modular COMPLETAMENTE LIMPIA
# Sin caracteres especiales problemÃ¡ticos

# Configurar politica de ejecucion
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
} catch {
    Write-Host "No se pudo cambiar la politica de ejecucion" -ForegroundColor Yellow
}

# Verificar modo STA
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Write-Host "Reiniciando en modo STA..." -ForegroundColor Yellow
    powershell.exe -STA -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Path
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cargar modulo de configuracion
try {
    $configManagerPath = "$PSScriptRoot\ConfigManager.ps1"
    if (Test-Path $configManagerPath) {
        . $configManagerPath
        Write-Host "ConfigManager cargado exitosamente" -ForegroundColor Green
    } else {
        throw "No se encontro ConfigManager.ps1"
    }
} catch {
    Write-Host "Error cargando ConfigManager: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Usando configuracion por defecto..." -ForegroundColor Yellow

    # Configuracion por defecto si falla
    $ProcessConfig = [PSCustomObject]@{
        Version          = "1.0"
        LastUpdated      = Get-Date -Format "yyyy-MM-dd"
        Categories       = @{
            "ASUS Software"  = @{
                description     = "Software y servicios de ASUS"
                icon            = "[ASUS]"
                color           = "#FF6B35"
                priority        = "high"
                aggressiveKill  = $true
                processes       = @("asus_framework", "ArmourySocketServer", "ADU", "ASUS DriverHub")
                relatedServices = @("AsusAppService")
            }
            "Adobe Software" = @{
                description     = "Adobe Creative Suite y Acrobat"
                icon            = "[ADOBE]"
                color           = "#FF0000"
                priority        = "high"
                aggressiveKill  = $true
                processes       = @("Adobe", "Acrobat", "AdobeCollabSync")
                relatedServices = @("AdobeUpdateService")
            }
            "Comunicacion"   = @{
                description     = "Apps de mensajeria"
                icon            = "[CHAT]"
                color           = "#25D366"
                priority        = "medium"
                aggressiveKill  = $false
                processes       = @("WhatsApp", "ChatGPT", "claude")
                relatedServices = @()
            }
        }
        GlobalSettings   = @{
            DefaultTimeout    = 2000
            RetryAttempts     = 3
            DelayBetweenKills = 150
        }
        SystemProtection = @{
            CriticalProcesses = @("System", "csrss", "winlogon", "services", "lsass")
        }
    }
}

# Cargar configuracion
try {
    $ProcessConfig = Load-ProcessConfig
} catch {
    Write-Host "Usando configuracion basica..." -ForegroundColor Yellow
}

# Variables globales
$AllProcesses = @{}
$SelectedProcesses = @{}

# Archivo de configuracion de usuario
$UserConfigFile = "$env:USERPROFILE\Documents\ProcessManager\UserSelections.json"

# Funcion para guardar selecciones del usuario
function Save-UserSelections {
    param($SelectedProcesses)

    if ($SelectedProcesses.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No hay procesos seleccionados para guardar.", "Aviso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    try {
        # Crear directorio si no existe
        $configDir = Split-Path $UserConfigFile -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        # Crear lista de procesos por nombre (mas estable que PID)
        $savedSelections = @()
        foreach ($proc in $SelectedProcesses.Values) {
            $savedSelections += @{
                ProcessName = $proc.Name
                Category    = $proc.Category
                Priority    = $proc.Priority
                SaveDate    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }

        $configData = @{
            Version           = "1.0"
            SaveDate          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            TotalProcesses    = $savedSelections.Count
            SelectedProcesses = $savedSelections
        }

        $configData | ConvertTo-Json -Depth 5 | Set-Content $UserConfigFile -Encoding UTF8

        [System.Windows.Forms.MessageBox]::Show("Selecciones guardadas exitosamente!`n`nArchivo: $UserConfigFile`nProcesos guardados: $($savedSelections.Count)", "Guardado Exitoso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error al guardar selecciones:`n$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Funcion para cargar selecciones del usuario
function Load-UserSelections {
    if (-not (Test-Path $UserConfigFile)) {
        [System.Windows.Forms.MessageBox]::Show("No se encontro archivo de selecciones guardadas.`n`nUbicacion esperada: $UserConfigFile", "Sin Selecciones Guardadas", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    try {
        $configData = Get-Content $UserConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $savedProcesses = $configData.SelectedProcesses

        if ($savedProcesses.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("El archivo de selecciones esta vacio.", "Sin Selecciones", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }

        # Limpiar selecciones actuales
        foreach ($node in $ProcessTreeView.Nodes) {
            $node.Checked = $false
            foreach ($childNode in $node.Nodes) {
                $childNode.Checked = $false
            }
        }
        $SelectedProcesses.Clear()

        # Cargar selecciones basadas en nombre de proceso
        $loadedCount = 0
        $notFoundCount = 0
        $notFoundProcesses = @()

        foreach ($savedProc in $savedProcesses) {
            $found = $false

            # Buscar por nombre de proceso en el TreeView actual
            foreach ($categoryNode in $ProcessTreeView.Nodes) {
                foreach ($processNode in $categoryNode.Nodes) {
                    if ($processNode.Tag -and $processNode.Tag.Name -eq $savedProc.ProcessName) {
                        $processNode.Checked = $true
                        $SelectedProcesses[$processNode] = $processNode.Tag
                        $loadedCount++
                        $found = $true
                        break
                    }
                }
                if ($found) { break }
            }

            if (-not $found) {
                $notFoundCount++
                $notFoundProcesses += $savedProc.ProcessName
            }
        }

        Update-Stats

        # Mostrar resultado de la carga
        $message = "Selecciones cargadas exitosamente!`n`n"
        $message += "Estadisticas de carga:`n"
        $message += "- Procesos cargados: $loadedCount`n"
        $message += "- Total guardados: $($savedProcesses.Count)`n"
        $message += "- Guardado el: $($configData.SaveDate)`n"

        if ($notFoundCount -gt 0) {
            $message += "`nProcesos no encontrados: $notFoundCount`n"
            $message += "- Estos procesos no estan ejecutandose actualmente`n"
            if ($notFoundProcesses.Count -le 5) {
                $message += "- Procesos: $($notFoundProcesses -join ', ')"
            }
        }

        [System.Windows.Forms.MessageBox]::Show($message, "Selecciones Cargadas", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error al cargar selecciones:`n$($_.Exception.Message)", "Error de Carga", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Funcion para obtener procesos por categoria
function Get-ProcessesByCategory {
    param($CategoryName)

    if (-not $ProcessConfig.Categories.ContainsKey($CategoryName)) {
        return @()
    }

    $category = $ProcessConfig.Categories[$CategoryName]
    $processes = @()

    foreach ($pattern in $category.processes) {
        $foundProcesses = Get-Process | Where-Object {
            $_.ProcessName -like "*$pattern*" -and $_.Id -ne $PID
        }
        foreach ($proc in $foundProcesses) {
            $memoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            $processes += [PSCustomObject]@{
                Name           = $proc.ProcessName
                PID            = $proc.Id
                MemoryMB       = $memoryMB
                Category       = $CategoryName
                FullName       = "$($proc.ProcessName) (PID: $($proc.Id)) - $memoryMB MB"
                Priority       = $category.priority
                AggressiveKill = $category.aggressiveKill
            }
        }
    }
    return $processes | Sort-Object MemoryMB -Descending
}

# Funcion para cerrar procesos con mejor manejo async
function Close-ProcessWithConfig {
    param($Process)

    try {
        if ($Process.Name -in $ProcessConfig.SystemProtection.CriticalProcesses) {
            throw "Proceso critico del sistema - protegido"
        }

        Write-Host "Cerrando: $($Process.Name)" -ForegroundColor Cyan

        # Obtener el proceso y verificar que existe
        $processObj = Get-Process -Id $Process.PID -ErrorAction Stop

        if ($Process.AggressiveKill) {
            # Cierre agresivo con mejor timing
            for ($attempt = 1; $attempt -le 3; $attempt++) {
                try {
                    # Verificar si el proceso aun existe antes de cada intento
                    if (-not (Get-Process -Id $Process.PID -ErrorAction SilentlyContinue)) {
                        Write-Host "  Proceso ya cerrado antes del intento $attempt" -ForegroundColor Green
                        return $true
                    }

                    switch ($attempt) {
                        1 {
                            $processObj.Kill()
                            Write-Host "  Intento $attempt - Kill estandar" -ForegroundColor Gray
                        }
                        2 {
                            Stop-Process -Id $Process.PID -Force -ErrorAction SilentlyContinue
                            Write-Host "  Intento $attempt - Stop-Process Force" -ForegroundColor Gray
                        }
                        3 {
                            cmd /c "taskkill /PID $($Process.PID) /F >nul 2>&1"
                            Write-Host "  Intento $attempt - taskkill Force" -ForegroundColor Gray
                        }
                    }

                    # Esperar tiempo progresivo
                    $waitTime = $attempt * 300
                    Start-Sleep -Milliseconds $waitTime

                    # Verificar si el proceso se cerro
                    if (-not (Get-Process -Id $Process.PID -ErrorAction SilentlyContinue)) {
                        Write-Host "  Proceso cerrado exitosamente en intento $attempt" -ForegroundColor Green
                        return $true
                    }
                } catch {
                    # Si el error es que no se encuentra el proceso, es exito
                    if ($_.Exception.Message -like "*No se encuentra ningÃºn proceso*" -or
                        $_.Exception.Message -like "*Cannot find a process*") {
                        Write-Host "  Proceso cerrado (no encontrado)" -ForegroundColor Green
                        return $true
                    }
                    Write-Host "  Error en intento $attempt`: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        } else {
            # Cierre normal con mejor verificacion
            $processObj.Kill()
            Start-Sleep -Milliseconds 500
        }

        # Verificacion final con espera adicional
        Start-Sleep -Milliseconds 200
        if (Get-Process -Id $Process.PID -ErrorAction SilentlyContinue) {
            throw "Proceso resistio todos los intentos de cierre"
        }

        return $true

    } catch {
        # Manejar errores comunes como exito
        if ($_.Exception.Message -like "*No se encuentra ningÃºn proceso*" -or
            $_.Exception.Message -like "*Cannot find a process*" -or
            $_.Exception.Message -like "*has exited*") {
            return $true
        }
        throw $_.Exception.Message
    }
}

# Funcion para mostrar resultados
function Show-ResultsDialog {
    param($SuccessResults, $ErrorResults, $TotalMemoryFreed)

    $ResultsForm = New-Object System.Windows.Forms.Form
    $ResultsForm.Text = "Resultados de la Operacion"
    $ResultsForm.Size = New-Object System.Drawing.Size(800, 600)
    $ResultsForm.StartPosition = "CenterParent"
    $ResultsForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    # Panel de resumen
    $SummaryPanel = New-Object System.Windows.Forms.Panel
    $SummaryPanel.Dock = "Top"
    $SummaryPanel.Height = 100
    $SummaryPanel.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

    $SummaryLabel = New-Object System.Windows.Forms.Label
    $SummaryLabel.Text = "RESUMEN DE RESULTADOS"
    $SummaryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $SummaryLabel.Location = New-Object System.Drawing.Point(20, 10)
    $SummaryLabel.Size = New-Object System.Drawing.Size(400, 25)

    $StatsLabel = New-Object System.Windows.Forms.Label
    $StatsLabel.Text = "Exitosos: $($SuccessResults.Count) | Errores: $($ErrorResults.Count) | Memoria liberada: $([math]::Round($TotalMemoryFreed, 2)) MB"
    $StatsLabel.Location = New-Object System.Drawing.Point(20, 40)
    $StatsLabel.Size = New-Object System.Drawing.Size(600, 25)

    $SummaryPanel.Controls.Add($SummaryLabel)
    $SummaryPanel.Controls.Add($StatsLabel)

    # TabControl
    $TabControl = New-Object System.Windows.Forms.TabControl
    $TabControl.Dock = "Fill"

    # Tab exitosos
    $SuccessTab = New-Object System.Windows.Forms.TabPage
    $SuccessTab.Text = "Exitosos ($($SuccessResults.Count))"

    $SuccessListView = New-Object System.Windows.Forms.ListView
    $SuccessListView.Dock = "Fill"
    $SuccessListView.View = "Details"
    $SuccessListView.FullRowSelect = $true
    $SuccessListView.GridLines = $true

    $SuccessListView.Columns.Add("Proceso", 200) | Out-Null
    $SuccessListView.Columns.Add("PID", 80) | Out-Null
    $SuccessListView.Columns.Add("Memoria MB", 120) | Out-Null
    $SuccessListView.Columns.Add("Categoria", 150) | Out-Null

    foreach ($result in $SuccessResults) {
        $item = New-Object System.Windows.Forms.ListViewItem($result.Name)
        $item.SubItems.Add($result.PID.ToString()) | Out-Null
        $item.SubItems.Add($result.MemoryMB.ToString()) | Out-Null
        $item.SubItems.Add($result.Category) | Out-Null
        $item.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 0)
        $SuccessListView.Items.Add($item) | Out-Null
    }

    $SuccessTab.Controls.Add($SuccessListView)

    # Tab errores
    $ErrorTab = New-Object System.Windows.Forms.TabPage
    $ErrorTab.Text = "Errores ($($ErrorResults.Count))"

    $ErrorListView = New-Object System.Windows.Forms.ListView
    $ErrorListView.Dock = "Fill"
    $ErrorListView.View = "Details"
    $ErrorListView.FullRowSelect = $true
    $ErrorListView.GridLines = $true

    $ErrorListView.Columns.Add("Proceso", 200) | Out-Null
    $ErrorListView.Columns.Add("PID", 80) | Out-Null
    $ErrorListView.Columns.Add("Error", 300) | Out-Null

    foreach ($result in $ErrorResults) {
        $item = New-Object System.Windows.Forms.ListViewItem($result.Name)
        $item.SubItems.Add($result.PID.ToString()) | Out-Null
        $item.SubItems.Add($result.Error) | Out-Null
        $item.ForeColor = [System.Drawing.Color]::FromArgb(180, 50, 50)
        $ErrorListView.Items.Add($item) | Out-Null
    }

    $ErrorTab.Controls.Add($ErrorListView)

    $TabControl.TabPages.Add($SuccessTab)
    $TabControl.TabPages.Add($ErrorTab)

    # Boton cerrar
    $ButtonPanel = New-Object System.Windows.Forms.Panel
    $ButtonPanel.Dock = "Bottom"
    $ButtonPanel.Height = 50

    $CloseButton = New-Object System.Windows.Forms.Button
    $CloseButton.Text = "Cerrar"
    $CloseButton.Size = New-Object System.Drawing.Size(100, 30)
    $CloseButton.Location = New-Object System.Drawing.Point(680, 10)
    $CloseButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $CloseButton.ForeColor = [System.Drawing.Color]::White
    $CloseButton.FlatStyle = "Flat"
    $CloseButton.Add_Click({ $ResultsForm.Close() })

    $ButtonPanel.Controls.Add($CloseButton)

    $ResultsForm.Controls.Add($TabControl)
    $ResultsForm.Controls.Add($SummaryPanel)
    $ResultsForm.Controls.Add($ButtonPanel)

    $ResultsForm.ShowDialog()
}

# Crear formulario principal
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Process Manager Pro - Sistema Modular"
$Form.Size = New-Object System.Drawing.Size(1200, 800)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "Sizable"
$Form.MinimumSize = New-Object System.Drawing.Size(1000, 700)
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Panel titulo
$TitlePanel = New-Object System.Windows.Forms.Panel
$TitlePanel.Dock = "Top"
$TitlePanel.Height = 60
$TitlePanel.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Process Manager Pro - Sistema Modular"
$TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$TitleLabel.ForeColor = [System.Drawing.Color]::White
$TitleLabel.Location = New-Object System.Drawing.Point(20, 15)
$TitleLabel.Size = New-Object System.Drawing.Size(600, 30)

$TitlePanel.Controls.Add($TitleLabel)

# SplitContainer principal
$SplitContainer = New-Object System.Windows.Forms.SplitContainer
$SplitContainer.Dock = "Fill"
$SplitContainer.SplitterDistance = 600

# Panel izquierdo
$LeftPanel = New-Object System.Windows.Forms.GroupBox
$LeftPanel.Text = "Categorias de Procesos"
$LeftPanel.Dock = "Fill"
$LeftPanel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)

$ProcessTreeView = New-Object System.Windows.Forms.TreeView
$ProcessTreeView.Dock = "Fill"
$ProcessTreeView.CheckBoxes = $true
$ProcessTreeView.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Panel derecho
$RightPanel = New-Object System.Windows.Forms.GroupBox
$RightPanel.Text = "Procesos Seleccionados"
$RightPanel.Dock = "Fill"
$RightPanel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)

$SelectedListView = New-Object System.Windows.Forms.ListView
$SelectedListView.Dock = "Fill"
$SelectedListView.View = "Details"
$SelectedListView.FullRowSelect = $true
$SelectedListView.GridLines = $true

$SelectedListView.Columns.Add("Proceso", 180) | Out-Null
$SelectedListView.Columns.Add("PID", 80) | Out-Null
$SelectedListView.Columns.Add("Memoria MB", 100) | Out-Null
$SelectedListView.Columns.Add("Categoria", 120) | Out-Null

# Panel estadisticas
$StatsPanel = New-Object System.Windows.Forms.Panel
$StatsPanel.Dock = "Bottom"
$StatsPanel.Height = 50

$StatsLabel = New-Object System.Windows.Forms.Label
$StatsLabel.Text = "Estadisticas: 0 procesos seleccionados - 0 MB a liberar"
$StatsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$StatsLabel.Location = New-Object System.Drawing.Point(15, 15)
$StatsLabel.Size = New-Object System.Drawing.Size(500, 30)

$StatsPanel.Controls.Add($StatsLabel)
$RightPanel.Controls.Add($StatsPanel)
$RightPanel.Controls.Add($SelectedListView)

# Funcion actualizar estadisticas
function Update-Stats {
    $selectedCount = $SelectedProcesses.Count
    $totalMemory = ($SelectedProcesses.Values | Measure-Object -Property MemoryMB -Sum).Sum
    if ($totalMemory -eq $null) { $totalMemory = 0 }

    $StatsLabel.Text = "Estadisticas: $selectedCount procesos seleccionados - $([math]::Round($totalMemory, 2)) MB a liberar"

    $SelectedListView.Items.Clear()
    foreach ($proc in $SelectedProcesses.Values) {
        $item = New-Object System.Windows.Forms.ListViewItem($proc.Name)
        $item.SubItems.Add($proc.PID.ToString()) | Out-Null
        $item.SubItems.Add($proc.MemoryMB.ToString()) | Out-Null
        $item.SubItems.Add($proc.Category) | Out-Null
        $SelectedListView.Items.Add($item) | Out-Null
    }
}

# Poblar TreeView
foreach ($categoryName in $ProcessConfig.Categories.Keys) {
    $processes = Get-ProcessesByCategory -CategoryName $categoryName

    if ($processes.Count -gt 0) {
        $categoryMemory = ($processes | Measure-Object -Property MemoryMB -Sum).Sum

        $categoryNode = New-Object System.Windows.Forms.TreeNode("$categoryName ($($processes.Count) items - $([math]::Round($categoryMemory, 2)) MB)")
        $categoryNode.NodeFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

        foreach ($process in $processes) {
            $processNode = New-Object System.Windows.Forms.TreeNode($process.FullName)
            $processNode.Tag = $process
            $AllProcesses[$processNode] = $process
            $categoryNode.Nodes.Add($processNode) | Out-Null
        }

        $ProcessTreeView.Nodes.Add($categoryNode) | Out-Null
    }
}

# Evento TreeView
$ProcessTreeView.Add_AfterCheck({
        param($sender, $e)

        if ($e.Node.Tag -ne $null) {
            $process = $e.Node.Tag
            if ($e.Node.Checked) {
                $SelectedProcesses[$e.Node] = $process
            } else {
                $SelectedProcesses.Remove($e.Node)
            }
        } else {
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
$SplitContainer.Panel1.Controls.Add($LeftPanel)
$SplitContainer.Panel2.Controls.Add($RightPanel)

# Panel botones
$ButtonPanel = New-Object System.Windows.Forms.Panel
$ButtonPanel.Dock = "Bottom"
$ButtonPanel.Height = 70

# Crear botones con funcionalidad completa
function Create-Button {
    param($Text, $BackColor, $Width = 140)

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object System.Drawing.Size($Width, 40)
    $button.BackColor = $BackColor
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = "Flat"
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    return $button
}

$CloseButton = Create-Button -Text "Cerrar Procesos" -BackColor ([System.Drawing.Color]::FromArgb(220, 50, 50)) -Width 160
$SaveButton = Create-Button -Text "Guardar Lista" -BackColor ([System.Drawing.Color]::FromArgb(0, 120, 215)) -Width 140
$LoadButton = Create-Button -Text "Cargar Lista" -BackColor ([System.Drawing.Color]::FromArgb(0, 150, 0)) -Width 140
$RefreshButton = Create-Button -Text "Actualizar" -BackColor ([System.Drawing.Color]::FromArgb(255, 140, 0))
$SelectAllButton = Create-Button -Text "Seleccionar Todo" -BackColor ([System.Drawing.Color]::FromArgb(100, 100, 100)) -Width 160

$CloseButton.Location = New-Object System.Drawing.Point(20, 15)
$SaveButton.Location = New-Object System.Drawing.Point(200, 15)
$LoadButton.Location = New-Object System.Drawing.Point(360, 15)
$RefreshButton.Location = New-Object System.Drawing.Point(520, 15)
$SelectAllButton.Location = New-Object System.Drawing.Point(680, 15)

# Eventos botones con funcionalidad completa
$CloseButton.Add_Click({
        if ($SelectedProcesses.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No hay procesos seleccionados", "Aviso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $totalMemory = ($SelectedProcesses.Values | Measure-Object -Property MemoryMB -Sum).Sum
        $message = "CONFIRMACION DE CIERRE`n`n" +
        "Procesos a cerrar: $($SelectedProcesses.Count)`n" +
        "Memoria que se liberara: $([math]::Round($totalMemory, 2)) MB`n`n" +
        "Esta accion no se puede deshacer.`n`n" +
        "Deseas continuar?"

        $result = [System.Windows.Forms.MessageBox]::Show($message, "Confirmar Cierre", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -eq "Yes") {
            $successResults = @()
            $errorResults = @()
            $totalMemoryFreed = 0

            foreach ($proc in $SelectedProcesses.Values) {
                try {
                    $success = Close-ProcessWithConfig -Process $proc
                    if ($success) {
                        $successResults += $proc
                        $totalMemoryFreed += $proc.MemoryMB
                    } else {
                        $errorResults += [PSCustomObject]@{
                            Name  = $proc.Name
                            PID   = $proc.PID
                            Error = "Proceso no respondio al cierre"
                        }
                    }
                } catch {
                    $errorResults += [PSCustomObject]@{
                        Name  = $proc.Name
                        PID   = $proc.PID
                        Error = $_.Exception.Message
                    }
                }
            }

            Show-ResultsDialog -SuccessResults $successResults -ErrorResults $errorResults -TotalMemoryFreed $totalMemoryFreed
        }
    })

$SaveButton.Add_Click({
        Save-UserSelections -SelectedProcesses $SelectedProcesses
    })

$LoadButton.Add_Click({
        Load-UserSelections
    })

$RefreshButton.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show("Actualizar la lista de procesos?`n`nEsto reiniciara la aplicacion.", "Actualizar", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
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

$ButtonPanel.Controls.Add($CloseButton)
$ButtonPanel.Controls.Add($SaveButton)
$ButtonPanel.Controls.Add($LoadButton)
$ButtonPanel.Controls.Add($RefreshButton)
$ButtonPanel.Controls.Add($SelectAllButton)

# Ensamblar formulario
$Form.Controls.Add($SplitContainer)
$Form.Controls.Add($ButtonPanel)
$Form.Controls.Add($TitlePanel)

# Expandir categorias
foreach ($node in $ProcessTreeView.Nodes) {
    $node.Expand()
}

# Mostrar formulario
[System.Windows.Forms.Application]::EnableVisualStyles()
$Form.ShowDialog()
