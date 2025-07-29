# Logger.ps1 - Sistema de logging
using namespace System.Collections.Generic
using namespace System.IO

enum LogLevel {
    Debug = 0
    Verbose = 1
    Information = 2
    Warning = 3
    Error = 4
    Critical = 5
}

# Interface base para loggers
class ILogger {
    [void] Log([LogLevel]$level, [string]$message) {
        throw [NotImplementedException]::new("Log must be implemented")
    }

    [void] Log([LogLevel]$level, [string]$message, [Exception]$exception) {
        throw [NotImplementedException]::new("Log with exception must be implemented")
    }

    [void] LogDebug([string]$message) {
        $this.Log([LogLevel]::Debug, $message)
    }

    [void] LogVerbose([string]$message) {
        $this.Log([LogLevel]::Verbose, $message)
    }

    [void] LogInformation([string]$message) {
        $this.Log([LogLevel]::Information, $message)
    }

    [void] LogWarning([string]$message) {
        $this.Log([LogLevel]::Warning, $message)
    }

    [void] LogError([string]$message) {
        $this.Log([LogLevel]::Error, $message)
    }

    [void] LogError([string]$message, [Exception]$exception) {
        $this.Log([LogLevel]::Error, $message, $exception)
    }

    [void] LogCritical([string]$message) {
        $this.Log([LogLevel]::Critical, $message)
    }

    [void] LogCritical([string]$message, [Exception]$exception) {
        $this.Log([LogLevel]::Critical, $message, $exception)
    }
}

# Logger que escribe en consola
class ConsoleLogger : ILogger {
    [LogLevel]$MinimumLevel
    [bool]$UseColors

    ConsoleLogger() {
        $this.MinimumLevel = [LogLevel]::Information
        $this.UseColors = $true
    }

    ConsoleLogger([LogLevel]$minimumLevel) {
        $this.MinimumLevel = $minimumLevel
        $this.UseColors = $true
    }

    [void] Log([LogLevel]$level, [string]$message) {
        if ($level -lt $this.MinimumLevel) {
            return
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $levelText = $this.GetLevelText($level)
        $logMessage = "[$timestamp] [$levelText] $message"

        if ($this.UseColors) {
            $color = $this.GetLevelColor($level)
            Write-Host $logMessage -ForegroundColor $color
        } else {
            Write-Host $logMessage
        }
    }

    [void] Log([LogLevel]$level, [string]$message, [Exception]$exception) {
        $this.Log($level, "$message - Exception: $($exception.Message)")

        if ($level -ge [LogLevel]::Error) {
            $this.Log($level, "StackTrace: $($exception.StackTrace)")
        }
    }

    hidden [string] GetLevelText([LogLevel]$level) {
        switch ($level) {
            ([LogLevel]::Debug) { return "DEBUG" }
            ([LogLevel]::Verbose) { return "VERBOSE" }
            ([LogLevel]::Information) { return "INFO" }
            ([LogLevel]::Warning) { return "WARN" }
            ([LogLevel]::Error) { return "ERROR" }
            ([LogLevel]::Critical) { return "CRITICAL" }
            default { return "UNKNOWN" }
        }
    }

    hidden [ConsoleColor] GetLevelColor([LogLevel]$level) {
        switch ($level) {
            ([LogLevel]::Debug) { return [ConsoleColor]::Gray }
            ([LogLevel]::Verbose) { return [ConsoleColor]::DarkGray }
            ([LogLevel]::Information) { return [ConsoleColor]::White }
            ([LogLevel]::Warning) { return [ConsoleColor]::Yellow }
            ([LogLevel]::Error) { return [ConsoleColor]::Red }
            ([LogLevel]::Critical) { return [ConsoleColor]::DarkRed }
            default { return [ConsoleColor]::White }
        }
    }
}

# Logger compuesto que puede escribir en mÃºltiples destinos
class CompositeLogger : ILogger {
    [List[ILogger]]$Loggers

    CompositeLogger() {
        $this.Loggers = [List[ILogger]]::new()
    }

    [void] AddLogger([ILogger]$logger) {
        if ($null -ne $logger) {
            $this.Loggers.Add($logger)
        }
    }

    [void] RemoveLogger([ILogger]$logger) {
        $this.Loggers.Remove($logger) | Out-Null
    }

    [void] Log([LogLevel]$level, [string]$message) {
        foreach ($logger in $this.Loggers) {
            try {
                $logger.Log($level, $message)
            } catch {
                # Silenciar errores de logging para evitar interrumpir la aplicaciÃ³n
                Write-Debug "Error en logger: $_"
            }
        }
    }

    [void] Log([LogLevel]$level, [string]$message, [Exception]$exception) {
        foreach ($logger in $this.Loggers) {
            try {
                $logger.Log($level, $message, $exception)
            } catch {
                Write-Debug "Error en logger: $_"
            }
        }
    }
}

# Logger con buffer para mejorar rendimiento
class BufferedLogger : ILogger {
    [ILogger]$InnerLogger
    [Queue[hashtable]]$Buffer
    [int]$BufferSize
    [System.Timers.Timer]$FlushTimer
    hidden [object]$SyncRoot

    BufferedLogger([ILogger]$innerLogger) {
        $this.InnerLogger = $innerLogger
        $this.Buffer = [Queue[hashtable]]::new()
        $this.BufferSize = 100
        $this.SyncRoot = [object]::new()
        $this.InitializeTimer()
    }

    BufferedLogger([ILogger]$innerLogger, [int]$bufferSize) {
        $this.InnerLogger = $innerLogger
        $this.Buffer = [Queue[hashtable]]::new()
        $this.BufferSize = $bufferSize
        $this.SyncRoot = [object]::new()
        $this.InitializeTimer()
    }

    hidden [void] InitializeTimer() {
        $this.FlushTimer = [System.Timers.Timer]::new(5000)  # Flush cada 5 segundos
        $this.FlushTimer.AutoReset = $true

        Register-ObjectEvent -InputObject $this.FlushTimer -EventName Elapsed -Action {
            $Event.MessageData.Flush()
        } -MessageData $this | Out-Null

        $this.FlushTimer.Start()
    }

    [void] Log([LogLevel]$level, [string]$message) {
        $logEntry = @{
            Level        = $level
            Message      = $message
            Timestamp    = [DateTime]::Now
            HasException = $false
        }

        [System.Threading.Monitor]::Enter($this.SyncRoot)
        try {
            $this.Buffer.Enqueue($logEntry)

            if ($this.Buffer.Count -ge $this.BufferSize) {
                $this.FlushInternal()
            }
        } finally {
            [System.Threading.Monitor]::Exit($this.SyncRoot)
        }
    }

    [void] Log([LogLevel]$level, [string]$message, [Exception]$exception) {
        $logEntry = @{
            Level        = $level
            Message      = $message
            Exception    = $exception
            Timestamp    = [DateTime]::Now
            HasException = $true
        }

        [System.Threading.Monitor]::Enter($this.SyncRoot)
        try {
            $this.Buffer.Enqueue($logEntry)

            if ($this.Buffer.Count -ge $this.BufferSize) {
                $this.FlushInternal()
            }
        } finally {
            [System.Threading.Monitor]::Exit($this.SyncRoot)
        }
    }

    [void] Flush() {
        [System.Threading.Monitor]::Enter($this.SyncRoot)
        try {
            $this.FlushInternal()
        } finally {
            [System.Threading.Monitor]::Exit($this.SyncRoot)
        }
    }

    hidden [void] FlushInternal() {
        while ($this.Buffer.Count -gt 0) {
            $entry = $this.Buffer.Dequeue()

            try {
                if ($entry.HasException) {
                    $this.InnerLogger.Log($entry.Level, $entry.Message, $entry.Exception)
                } else {
                    $this.InnerLogger.Log($entry.Level, $entry.Message)
                }
            } catch {
                # Silenciar errores de logging
            }
        }
    }

    [void] Dispose() {
        if ($null -ne $this.FlushTimer) {
            $this.FlushTimer.Stop()
            $this.FlushTimer.Dispose()
        }

        $this.Flush()
    }
}

# Factory para crear loggers
class LoggerFactory {
    static [ILogger] CreateConsoleLogger() {
        return [ConsoleLogger]::new()
    }

    static [ILogger] CreateConsoleLogger([LogLevel]$minimumLevel) {
        return [ConsoleLogger]::new($minimumLevel)
    }

    static [ILogger] CreateFileLogger([string]$filePath) {
        # Importar FileLogger cuando sea necesario
        . "$PSScriptRoot\..\..\Infrastructure\Logging\FileLogger.ps1"
        return [FileLogger]::new($filePath)
    }

    static [ILogger] CreateCompositeLogger([ILogger[]]$loggers) {
        $composite = [CompositeLogger]::new()
        foreach ($logger in $loggers) {
            $composite.AddLogger($logger)
        }
        return $composite
    }

    static [ILogger] CreateBufferedLogger([ILogger]$innerLogger) {
        return [BufferedLogger]::new($innerLogger)
    }

    static [ILogger] CreateDefaultLogger() {
        # Logger por defecto: consola con nivel Information
        return [ConsoleLogger]::new([LogLevel]::Information)
    }
}
