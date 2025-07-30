# Process Manager Pro - Version Modular MEJORADA
# Con búsqueda en tiempo real, exportación, modo oscuro, atajos y tooltips

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
        Version = "1.0"
        LastUpdated = Get-Date -Format "yyyy-MM-dd"
        Categories = @{
            "ASUS Software" = @{
                description = "Software y servicios de ASUS"
                icon = "[ASUS]"
                color = "#FF6B35"
                priority = "high"
                aggressiveKill = $true
                processes = @("asus_framework", "ArmourySocketServer", "ADU", "ASUS DriverHub")
                relatedServices = @("AsusAppService")
            }
            "Adobe Software" = @{
                description = "Adobe Creative Suite y Acrobat"
                icon = "[ADOBE]"
                color = "#FF0000"
                priority = "high"
                aggressiveKill = $true
                processes = @("Adobe", "Acrobat", "AdobeCollabSync")
                relatedServices = @("AdobeUpdateService")
            }
            "Comunicacion" = @{
                description = "Apps de mensajeria"
                icon = "[CHAT]"
                color = "#25D366"
                priority = "medium"
                aggressiveKill = $false
                processes = @("WhatsApp", "ChatGPT", "claude")
                relatedServices = @()
            }
        }
        GlobalSettings = @{
            DefaultTimeout = 2000
            RetryAttempts = 3
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
$FilteredProcesses = @{}
$ToolTip = New-Object System.Windows.Forms.ToolTip
$IsDarkMode = $false
$ClosedProcessesHistory = @()

# Archivo de configuracion de usuario
$UserConfigFile = "$env:USERPROFILE\Documents\ProcessManager\UserSelections.json"
$UserPreferencesFile = "$env:USERPROFILE\Documents\ProcessManager\UserPreferences.json"

# Colores para modo oscuro
$DarkModeColors = @{
    Background = [System.Drawing.Color]::FromArgb(30, 30, 30)
    Foreground = [System.Drawing.Color]::FromArgb(230, 230, 230)
    Control = [System.Drawing.Color]::FromArgb(45, 45, 45)
    Button = [System.Drawing.Color]::FromArgb(60, 60, 60)
    Highlight = [System.Drawing.Color]::FromArgb(0, 120, 215)
}

# Colores para modo claro
$LightModeColors = @{
    Background = [System.Drawing.SystemColors]::Window
    Foreground = [System.Drawing.SystemColors]::WindowText
    Control = [System.Drawing.SystemColors]::Control
    Button = [System.Drawing.SystemColors]::ButtonFace
    Highlight = [System.Drawing.Color]::FromArgb(0, 120, 215)
}

# Funcion para cargar preferencias de usuario
function Load-UserPreferences {
    if (Test-Path $UserPreferencesFile) {
        try {
            $preferences = Get-Content $UserPreferencesFile -Raw | ConvertFrom-Json
            $script:IsDarkMode = $preferences.DarkMode
            return $preferences
        } catch {
            Write-Host "Error cargando preferencias: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    return @{ DarkMode = $false }
}

# Funcion para guardar preferencias de usuario
function Save-UserPreferences {
    try {
        $preferences = @{
            DarkMode = $IsDarkMode
            LastSaved = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        $prefDir = Split-Path $UserPreferencesFile -Parent
        if (-not (Test-Path $prefDir)) {
            New-Item -ItemType Directory -Path $prefDir -Force | Out-Null
        }
        
        $preferences | ConvertTo-Json | Set-Content $UserPreferencesFile -Encoding UTF8
    } catch {
        Write-Host "Error guardando preferencias: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Funcion para aplicar tema
function Apply-Theme {
    param($Control, $IsDarkMode)
    
    $colors = if ($IsDarkMode) { $DarkModeColors } else { $LightModeColors }
    
    if ($Control -is [System.Windows.Forms.Form] -or 
        $Control -is [System.Windows.Forms.Panel] -or 
        $Control -is [System.Windows.Forms.GroupBox]) {
        # No cambiar color si está marcado para mantener
        if ($Control.Tag -ne "KeepColor") {
            $Control.BackColor = $colors.Background
            $Control.ForeColor = $colors.Foreground
        }
    }
    elseif ($Control -is [System.Windows.Forms.Button]) {
        if ($Control.Tag -eq "OriginalColor") {
            # Botón con color especial
            if ($IsDarkMode) {
                # En modo oscuro, oscurecer un poco el color original
                $originalColor = $Control.OriginalBackColor
                $darkerColor = [System.Drawing.Color]::FromArgb(
                    [Math]::Max(0, $originalColor.R - 40),
                    [Math]::Max(0, $originalColor.G - 40),
                    [Math]::Max(0, $originalColor.B - 40)
                )
                $Control.BackColor = $darkerColor
                $Control.ForeColor = [System.Drawing.Color]::White
            } else {
                # En modo claro, restaurar colores originales
                $Control.BackColor = $Control.OriginalBackColor
                $Control.ForeColor = $Control.OriginalForeColor
            }
        } else {
            # Botón estándar
            $Control.BackColor = $colors.Button
            $Control.ForeColor = $colors.Foreground
        }
        
        # Mantener estilo flat para todos
        $Control.FlatStyle = "Flat"
        if ($IsDarkMode) {
            $Control.FlatAppearance.BorderColor = $colors.Foreground
        } else {
            $Control.FlatAppearance.BorderColor = [System.Drawing.SystemColors]::ControlDark
        }
    }
    elseif ($Control -is [System.Windows.Forms.ListView] -or 
            $Control -is [System.Windows.Forms.TreeView] -or
            $Control -is [System.Windows.Forms.TextBox]) {
        $Control.BackColor = $colors.Control
        $Control.ForeColor = $colors.Foreground
    }
    elseif ($Control -is [System.Windows.Forms.Label]) {
        # Asegurar que las etiquetas sean visibles
        if ($Control.Parent -is [System.Windows.Forms.Panel] -and 
            $Control.Parent.BackColor -eq [System.Drawing.Color]::FromArgb(0, 120, 215)) {
            # Mantener texto blanco en paneles con fondo azul
            $Control.ForeColor = [System.Drawing.Color]::White
        } else {
            $Control.ForeColor = $colors.Foreground
        }
    }
    
    # Aplicar recursivamente a controles hijos
    if ($Control.Controls) {
        foreach ($child in $Control.Controls) {
            Apply-Theme -Control $child -IsDarkMode $IsDarkMode
        }
    }
}

# Funcion para exportar reporte
function Export-Report {
    param(
        [string]$Format = "CSV",
        [string]$FilePath = ""
    )
    
    if ($FilePath -eq "") {
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Title = "Guardar Reporte de Procesos"
        $saveDialog.Filter = if ($Format -eq "CSV") { 
            "CSV files (*.csv)|*.csv|All files (*.*)|*.*" 
        } else { 
            "Text files (*.txt)|*.txt|All files (*.*)|*.*" 
        }
        $saveDialog.DefaultExt = if ($Format -eq "CSV") { "csv" } else { "txt" }
        $saveDialog.FileName = "ProcessManager_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        
        if ($saveDialog.ShowDialog() -eq 'OK') {
            $FilePath = $saveDialog.FileName
        } else {
            return
        }
    }
    
    try {
        if ($Format -eq "CSV") {
            # Exportar en formato CSV
            $csvData = @()
            $csvData += "Fecha,Hora,Proceso,PID,Memoria MB,Categoria,Estado"
            
            foreach ($item in $ClosedProcessesHistory) {
                $csvData += "$($item.Date),$($item.Time),$($item.Name),$($item.PID),$($item.MemoryMB),$($item.Category),$($item.Status)"
            }
            
            # Agregar resumen
            $csvData += ""
            $csvData += "RESUMEN"
            $csvData += "Total de procesos cerrados,$($ClosedProcessesHistory.Count)"
            $csvData += "Memoria total liberada,$($ClosedProcessesHistory | Measure-Object -Property MemoryMB -Sum | Select-Object -ExpandProperty Sum) MB"
            
            $csvData | Out-File -FilePath $FilePath -Encoding UTF8
        }
        else {
            # Exportar en formato TXT
            $txtData = @()
            $txtData += "================================================================"
            $txtData += "          REPORTE DE PROCESS MANAGER PRO"
            $txtData += "          Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
            $txtData += "================================================================"
            $txtData += ""
            
            foreach ($item in $ClosedProcessesHistory) {
                $txtData += "[$($item.Time)] $($item.Name) (PID: $($item.PID)) - $($item.MemoryMB) MB - $($item.Category) - $($item.Status)"
            }
            
            $txtData += ""
            $txtData += "----------------------------------------------------------------"
            $txtData += "RESUMEN:"
            $txtData += "Total de procesos cerrados: $($ClosedProcessesHistory.Count)"
            $txtData += "Memoria total liberada: $($ClosedProcessesHistory | Measure-Object -Property MemoryMB -Sum | Select-Object -ExpandProperty Sum) MB"
            $txtData += "================================================================"
            
            $txtData | Out-File -FilePath $FilePath -Encoding UTF8
        }
        
        [System.Windows.Forms.MessageBox]::Show(
            "Reporte exportado exitosamente!`n`nArchivo: $FilePath", 
            "Exportacion Exitosa", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error al exportar reporte:`n$($_.Exception.Message)", 
            "Error de Exportacion", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# Funcion para filtrar procesos
function Filter-ProcessTree {
    param([string]$FilterText)
    
    $ProcessTreeView.BeginUpdate()
    
    foreach ($categoryNode in $ProcessTreeView.Nodes) {
        $categoryVisible = $false
        
        foreach ($processNode in $categoryNode.Nodes) {
            if ($FilterText -eq "" -or 
                $processNode.Text -like "*$FilterText*" -or 
                $processNode.Tag.Name -like "*$FilterText*") {
                $processNode.ForeColor = if ($IsDarkMode) { $DarkModeColors.Foreground } else { $LightModeColors.Foreground }
                $categoryVisible = $true
            } else {
                $processNode.ForeColor = [System.Drawing.Color]::Gray
            }
        }
        
        # Expandir categoria si tiene coincidencias
        if ($categoryVisible -and $FilterText -ne "") {
            $categoryNode.Expand()
        }
    }
    
    $ProcessTreeView.EndUpdate()
}

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
                Category = $proc.Category
                Priority = $proc.Priority
                SaveDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        
        $configData = @{
            Version = "1.0"
            SaveDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            TotalProcesses = $savedSelections.Count
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
                Name = $proc.ProcessName
                PID = $proc.Id
                MemoryMB = $memoryMB
                Category = $CategoryName
                FullName = "$($proc.ProcessName) (PID: $($proc.Id)) - $memoryMB MB"
                Priority = $category.priority
                AggressiveKill = $category.aggressiveKill
                StartTime = $proc.StartTime
                Path = $proc.Path
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
                    if ($_.Exception.Message -like "*No se encuentra ningún proceso*" -or 
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
        if ($_.Exception.Message -like "*No se encuentra ningún proceso*" -or 
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
    
    # Aplicar tema
    Apply-Theme -Control $ResultsForm -IsDarkMode $IsDarkMode
    
    # Panel de resumen
    $SummaryPanel = New-Object System.Windows.Forms.Panel
    $SummaryPanel.Dock = "Top"
    $SummaryPanel.Height = 100
    $SummaryPanel.BackColor = if ($IsDarkMode) { [System.Drawing.Color]::FromArgb(40, 40, 40) } else { [System.Drawing.Color]::FromArgb(245, 245, 245) }
    
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
    Apply-Theme -Control $SuccessListView -IsDarkMode $IsDarkMode
    
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
    Apply-Theme -Control $ErrorListView -IsDarkMode $IsDarkMode
    
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

# Cargar preferencias de usuario
$userPrefs = Load-UserPreferences

# Crear formulario principal
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Process Manager Pro - Sistema Modular Mejorado"
$Form.Size = New-Object System.Drawing.Size(1200, 800)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "Sizable"
$Form.MinimumSize = New-Object System.Drawing.Size(1000, 700)
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Asegurar que la terminal se cierre cuando se cierre el formulario
$Form.Add_FormClosing({
    Save-UserPreferences
    [Environment]::Exit(0)
})

# Configurar atajos de teclado
$Form.KeyPreview = $true
$Form.Add_KeyDown({
    param($sender, $e)
    
    # Ctrl+A - Seleccionar todo
    if ($e.Control -and $e.KeyCode -eq 'A') {
        foreach ($node in $ProcessTreeView.Nodes) {
            $node.Checked = $true
        }
        $e.Handled = $true
    }
    # Ctrl+R - Refrescar
    elseif ($e.Control -and $e.KeyCode -eq 'R') {
        $RefreshButton.PerformClick()
        $e.Handled = $true
    }
    # Delete - Cerrar procesos seleccionados
    elseif ($e.KeyCode -eq 'Delete') {
        if ($SelectedProcesses.Count -gt 0) {
            $CloseButton.PerformClick()
        }
        $e.Handled = $true
    }
    # Ctrl+D - Cambiar modo oscuro
    elseif ($e.Control -and $e.KeyCode -eq 'D') {
        $DarkModeButton.PerformClick()
        $e.Handled = $true
    }
    # Ctrl+E - Exportar reporte
    elseif ($e.Control -and $e.KeyCode -eq 'E') {
        $ExportButton.PerformClick()
        $e.Handled = $true
    }
})

# Panel titulo
$TitlePanel = New-Object System.Windows.Forms.Panel
$TitlePanel.Dock = "Top"
$TitlePanel.Height = 60
$TitlePanel.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$TitlePanel.Tag = "KeepColor"  # Marcar para no cambiar color

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Process Manager Pro - Sistema Modular Mejorado"
$TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$TitleLabel.ForeColor = [System.Drawing.Color]::White
$TitleLabel.Location = New-Object System.Drawing.Point(20, 15)
$TitleLabel.Size = New-Object System.Drawing.Size(600, 30)

$TitlePanel.Controls.Add($TitleLabel)

# Panel de búsqueda
$SearchPanel = New-Object System.Windows.Forms.Panel
$SearchPanel.Dock = "Top"
$SearchPanel.Height = 50
$SearchPanel.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 5)

$SearchLabel = New-Object System.Windows.Forms.Label
$SearchLabel.Text = "Buscar:"
$SearchLabel.Location = New-Object System.Drawing.Point(15, 18)
$SearchLabel.Size = New-Object System.Drawing.Size(50, 23)

$SearchTextBox = New-Object System.Windows.Forms.TextBox
$SearchTextBox.Location = New-Object System.Drawing.Point(70, 15)
$SearchTextBox.Size = New-Object System.Drawing.Size(300, 23)
$SearchTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$ToolTip.SetToolTip($SearchTextBox, "Buscar procesos por nombre (Ctrl+F)")

# Evento de búsqueda en tiempo real
$SearchTextBox.Add_TextChanged({
    Filter-ProcessTree -FilterText $SearchTextBox.Text
})

$ClearSearchButton = New-Object System.Windows.Forms.Button
$ClearSearchButton.Text = "X"
$ClearSearchButton.Location = New-Object System.Drawing.Point(375, 15)
$ClearSearchButton.Size = New-Object System.Drawing.Size(30, 23)
$ClearSearchButton.FlatStyle = "Flat"
$ToolTip.SetToolTip($ClearSearchButton, "Limpiar búsqueda")
$ClearSearchButton.Add_Click({
    $SearchTextBox.Clear()
})

$SearchPanel.Controls.Add($SearchLabel)
$SearchPanel.Controls.Add($SearchTextBox)
$SearchPanel.Controls.Add($ClearSearchButton)

# SplitContainer principal
$SplitContainer = New-Object System.Windows.Forms.SplitContainer
$SplitContainer.Dock = "Fill"
$SplitContainer.Orientation = "Vertical"  # Horizontal split (columnas lado a lado)
$SplitContainer.SplitterWidth = 5
$SplitContainer.IsSplitterFixed = $false  # Permitir ajuste manual

# Establecer tamaño mínimo para cada panel
$SplitContainer.Panel1MinSize = 300
$SplitContainer.Panel2MinSize = 300

# Panel izquierdo
$LeftPanel = New-Object System.Windows.Forms.GroupBox
$LeftPanel.Text = "Categorias de Procesos"
$LeftPanel.Dock = "Fill"
$LeftPanel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)

$ProcessTreeView = New-Object System.Windows.Forms.TreeView
$ProcessTreeView.Dock = "Fill"
$ProcessTreeView.CheckBoxes = $true
$ProcessTreeView.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$ProcessTreeView.ShowNodeToolTips = $true

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
        $category = $ProcessConfig.Categories[$categoryName]
        
        $categoryNode = New-Object System.Windows.Forms.TreeNode("$categoryName ($($processes.Count) items - $([math]::Round($categoryMemory, 2)) MB)")
        $categoryNode.NodeFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $categoryNode.ToolTipText = "$($category.description)`nPrioridad: $($category.priority)`nCierre agresivo: $($category.aggressiveKill)"
        
        foreach ($process in $processes) {
            $processNode = New-Object System.Windows.Forms.TreeNode($process.FullName)
            $processNode.Tag = $process
            $AllProcesses[$processNode] = $process
            
            # Agregar tooltip con información adicional
            $tooltipText = "Proceso: $($process.Name)`n"
            $tooltipText += "PID: $($process.PID)`n"
            $tooltipText += "Memoria: $($process.MemoryMB) MB`n"
            if ($process.StartTime) {
                $tooltipText += "Iniciado: $($process.StartTime.ToString('dd/MM/yyyy HH:mm:ss'))`n"
            }
            if ($process.Path) {
                $tooltipText += "Ruta: $($process.Path)"
            }
            $processNode.ToolTipText = $tooltipText
            
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
$ButtonPanel.Height = 100

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
    $button.Tag = "OriginalColor"  # Marcar que tiene color especial
    
    # Guardar colores originales en propiedades personalizadas
    $button | Add-Member -MemberType NoteProperty -Name "OriginalBackColor" -Value $BackColor
    $button | Add-Member -MemberType NoteProperty -Name "OriginalForeColor" -Value ([System.Drawing.Color]::White)
    
    return $button
}

# Primera fila de botones
$CloseButton = Create-Button -Text "Cerrar Procesos" -BackColor ([System.Drawing.Color]::FromArgb(220, 50, 50)) -Width 160
$SaveButton = Create-Button -Text "Guardar Lista" -BackColor ([System.Drawing.Color]::FromArgb(0, 120, 215)) -Width 140
$LoadButton = Create-Button -Text "Cargar Lista" -BackColor ([System.Drawing.Color]::FromArgb(0, 150, 0)) -Width 140
$RefreshButton = Create-Button -Text "Actualizar" -BackColor ([System.Drawing.Color]::FromArgb(255, 140, 0))
$SelectAllButton = Create-Button -Text "Seleccionar Todo" -BackColor ([System.Drawing.Color]::FromArgb(100, 100, 100)) -Width 160

# Segunda fila de botones (nuevos)
$ExportButton = Create-Button -Text "Exportar Reporte" -BackColor ([System.Drawing.Color]::FromArgb(70, 130, 180)) -Width 160
$DarkModeButton = Create-Button -Text "Modo Oscuro" -BackColor ([System.Drawing.Color]::FromArgb(64, 64, 64)) -Width 140

# Posiciones primera fila
$CloseButton.Location = New-Object System.Drawing.Point(20, 15)
$SaveButton.Location = New-Object System.Drawing.Point(200, 15)
$LoadButton.Location = New-Object System.Drawing.Point(360, 15)
$RefreshButton.Location = New-Object System.Drawing.Point(520, 15)
$SelectAllButton.Location = New-Object System.Drawing.Point(680, 15)

# Posiciones segunda fila
$ExportButton.Location = New-Object System.Drawing.Point(20, 60)
$DarkModeButton.Location = New-Object System.Drawing.Point(200, 60)

# Agregar tooltips a los botones
$ToolTip.SetToolTip($CloseButton, "Cerrar procesos seleccionados (Delete)")
$ToolTip.SetToolTip($SaveButton, "Guardar selección actual")
$ToolTip.SetToolTip($LoadButton, "Cargar selección guardada")
$ToolTip.SetToolTip($RefreshButton, "Actualizar lista de procesos (Ctrl+R)")
$ToolTip.SetToolTip($SelectAllButton, "Seleccionar todos los procesos (Ctrl+A)")
$ToolTip.SetToolTip($ExportButton, "Exportar reporte de procesos cerrados (Ctrl+E)")
$ToolTip.SetToolTip($DarkModeButton, "Cambiar entre modo claro/oscuro (Ctrl+D)")

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
                    
                    # Agregar al historial
                    $script:ClosedProcessesHistory += [PSCustomObject]@{
                        Date = Get-Date -Format "yyyy-MM-dd"
                        Time = Get-Date -Format "HH:mm:ss"
                        Name = $proc.Name
                        PID = $proc.PID
                        MemoryMB = $proc.MemoryMB
                        Category = $proc.Category
                        Status = "Cerrado"
                    }
                } else {
                    $errorResults += [PSCustomObject]@{
                        Name = $proc.Name
                        PID = $proc.PID
                        Error = "Proceso no respondio al cierre"
                    }
                }
            } catch {
                $errorResults += [PSCustomObject]@{
                    Name = $proc.Name
                    PID = $proc.PID
                    Error = $_.Exception.Message
                }
                
                # Agregar al historial como error
                $script:ClosedProcessesHistory += [PSCustomObject]@{
                    Date = Get-Date -Format "yyyy-MM-dd"
                    Time = Get-Date -Format "HH:mm:ss"
                    Name = $proc.Name
                    PID = $proc.PID
                    MemoryMB = $proc.MemoryMB
                    Category = $proc.Category
                    Status = "Error: $($_.Exception.Message)"
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
        Save-UserPreferences
        $Form.Close()
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    }
})

$SelectAllButton.Add_Click({
    foreach ($node in $ProcessTreeView.Nodes) {
        $node.Checked = $true
    }
})

$ExportButton.Add_Click({
    if ($ClosedProcessesHistory.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No hay historial de procesos cerrados para exportar.", 
            "Sin Datos", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }
    
    # Mostrar diálogo de opciones
    $exportForm = New-Object System.Windows.Forms.Form
    $exportForm.Text = "Exportar Reporte"
    $exportForm.Size = New-Object System.Drawing.Size(300, 150)
    $exportForm.StartPosition = "CenterParent"
    
    $csvRadio = New-Object System.Windows.Forms.RadioButton
    $csvRadio.Text = "Formato CSV"
    $csvRadio.Location = New-Object System.Drawing.Point(50, 20)
    $csvRadio.Checked = $true
    
    $txtRadio = New-Object System.Windows.Forms.RadioButton
    $txtRadio.Text = "Formato TXT"
    $txtRadio.Location = New-Object System.Drawing.Point(50, 50)
    
    $exportBtn = New-Object System.Windows.Forms.Button
    $exportBtn.Text = "Exportar"
    $exportBtn.Location = New-Object System.Drawing.Point(100, 80)
    $exportBtn.Add_Click({
        $format = if ($csvRadio.Checked) { "CSV" } else { "TXT" }
        Export-Report -Format $format
        $exportForm.Close()
    })
    
    $exportForm.Controls.Add($csvRadio)
    $exportForm.Controls.Add($txtRadio)
    $exportForm.Controls.Add($exportBtn)
    
    Apply-Theme -Control $exportForm -IsDarkMode $IsDarkMode
    
    $exportForm.ShowDialog()
})

$DarkModeButton.Add_Click({
    $script:IsDarkMode = -not $IsDarkMode
    $DarkModeButton.Text = if ($IsDarkMode) { "Modo Claro" } else { "Modo Oscuro" }
    
    # Aplicar tema a todos los controles
    Apply-Theme -Control $Form -IsDarkMode $IsDarkMode
    
    # Forzar actualización de los nodos del TreeView
    foreach ($categoryNode in $ProcessTreeView.Nodes) {
        foreach ($processNode in $categoryNode.Nodes) {
            $processNode.ForeColor = if ($IsDarkMode) { $DarkModeColors.Foreground } else { [System.Drawing.SystemColors]::WindowText }
        }
    }
    
    # Guardar preferencia
    Save-UserPreferences
})

$ButtonPanel.Controls.Add($CloseButton)
$ButtonPanel.Controls.Add($SaveButton)
$ButtonPanel.Controls.Add($LoadButton)
$ButtonPanel.Controls.Add($RefreshButton)
$ButtonPanel.Controls.Add($SelectAllButton)
$ButtonPanel.Controls.Add($ExportButton)
$ButtonPanel.Controls.Add($DarkModeButton)

# Ensamblar formulario
$Form.Controls.Add($SplitContainer)
$Form.Controls.Add($ButtonPanel)
$Form.Controls.Add($SearchPanel)
$Form.Controls.Add($TitlePanel)

# Aplicar tema inicial
Apply-Theme -Control $Form -IsDarkMode $IsDarkMode
if ($IsDarkMode) {
    $DarkModeButton.Text = "Modo Claro"
}

# Expandir categorias
foreach ($node in $ProcessTreeView.Nodes) {
    $node.Expand()
}

# Configurar división inicial 50/50 después de cargar el formulario
$Form.Add_Shown({
    # Establecer división 50/50
    $SplitContainer.SplitterDistance = [int]($SplitContainer.Width / 2)
    
    # Configurar el manejador de resize para mantener proporción al cambiar tamaño
    $script:LastSplitterRatio = 0.5
    
    # Remover el handler anterior y agregar uno nuevo
    $SplitContainer.remove_Resize($null)
    
    # Cuando el usuario mueve el splitter manualmente
    $SplitContainer.Add_SplitterMoved({
        if ($SplitContainer.Width -gt 0) {
            $script:LastSplitterRatio = $SplitContainer.SplitterDistance / $SplitContainer.Width
        }
    })
    
    # Cuando se redimensiona la ventana
    $Form.Add_Resize({
        if ($Form.WindowState -ne "Minimized" -and $SplitContainer.Width -gt 0) {
            # Mantener la proporción que el usuario estableció
            $newDistance = [int]($SplitContainer.Width * $script:LastSplitterRatio)
            # Respetar los límites mínimos
            $newDistance = [Math]::Max($SplitContainer.Panel1MinSize, $newDistance)
            $newDistance = [Math]::Min($SplitContainer.Width - $SplitContainer.Panel2MinSize - $SplitContainer.SplitterWidth, $newDistance)
            $SplitContainer.SplitterDistance = $newDistance
        }
    })
})

# Mostrar formulario
[System.Windows.Forms.Application]::EnableVisualStyles()
$Form.ShowDialog()

# Guardar preferencias al cerrar
Save-UserPreferences

# Cerrar la consola/terminal al cerrar la GUI
[Environment]::Exit(0)