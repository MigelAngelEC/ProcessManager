# RelayCommand.ps1 - ImplementaciÃ³n del patrÃ³n Command para MVVM
using namespace System.Windows.Input

class RelayCommand : ICommand {
    hidden [ScriptBlock]$executeAction
    hidden [ScriptBlock]$canExecutePredicate
    hidden [EventHandler]$CanExecuteChanged

    # Constructor con solo acciÃ³n de ejecuciÃ³n
    RelayCommand([ScriptBlock]$execute) {
        if ($null -eq $execute) {
            throw [ArgumentNullException]::new("execute")
        }

        $this.executeAction = $execute
        $this.canExecutePredicate = { $true }
    }

    # Constructor con acciÃ³n y predicado
    RelayCommand([ScriptBlock]$execute, [ScriptBlock]$canExecute) {
        if ($null -eq $execute) {
            throw [ArgumentNullException]::new("execute")
        }

        $this.executeAction = $execute
        $this.canExecutePredicate = if ($null -ne $canExecute) { $canExecute } else { { $true } }
    }

    # ImplementaciÃ³n de ICommand
    [void] add_CanExecuteChanged([EventHandler]$handler) {
        $this.CanExecuteChanged = [Delegate]::Combine($this.CanExecuteChanged, $handler)

        # Suscribirse a CommandManager.RequerySuggested para actualizaciÃ³n automÃ¡tica
        [CommandManager]::add_RequerySuggested($handler)
    }

    [void] remove_CanExecuteChanged([EventHandler]$handler) {
        $this.CanExecuteChanged = [Delegate]::Remove($this.CanExecuteChanged, $handler)
        [CommandManager]::remove_RequerySuggested($handler)
    }

    [bool] CanExecute([object]$parameter) {
        try {
            if ($null -eq $this.canExecutePredicate) {
                return $true
            }

            return & $this.canExecutePredicate $parameter
        } catch {
            Write-Debug "Error en CanExecute: $_"
            return $false
        }
    }

    [void] Execute([object]$parameter) {
        if ($this.CanExecute($parameter)) {
            & $this.executeAction $parameter
        }
    }

    # MÃ©todo para forzar re-evaluaciÃ³n de CanExecute
    [void] RaiseCanExecuteChanged() {
        if ($null -ne $this.CanExecuteChanged) {
            $this.CanExecuteChanged.Invoke($this, [EventArgs]::Empty)
        }

        # TambiÃ©n notificar a CommandManager
        [CommandManager]::InvalidateRequerySuggested()
    }
}

# VersiÃ³n genÃ©rica del RelayCommand
class RelayCommand[T] : ICommand {
    hidden [Action[T]]$executeAction
    hidden [Predicate[T]]$canExecutePredicate
    hidden [EventHandler]$CanExecuteChanged

    RelayCommand([Action[T]]$execute) {
        if ($null -eq $execute) {
            throw [ArgumentNullException]::new("execute")
        }

        $this.executeAction = $execute
        $this.canExecutePredicate = { param($x) $true }
    }

    RelayCommand([Action[T]]$execute, [Predicate[T]]$canExecute) {
        if ($null -eq $execute) {
            throw [ArgumentNullException]::new("execute")
        }

        $this.executeAction = $execute
        $this.canExecutePredicate = if ($null -ne $canExecute) { $canExecute } else { { param($x) $true } }
    }

    [void] add_CanExecuteChanged([EventHandler]$handler) {
        $this.CanExecuteChanged = [Delegate]::Combine($this.CanExecuteChanged, $handler)
        [CommandManager]::add_RequerySuggested($handler)
    }

    [void] remove_CanExecuteChanged([EventHandler]$handler) {
        $this.CanExecuteChanged = [Delegate]::Remove($this.CanExecuteChanged, $handler)
        [CommandManager]::remove_RequerySuggested($handler)
    }

    [bool] CanExecute([object]$parameter) {
        if ($null -eq $this.canExecutePredicate) {
            return $true
        }

        if ($null -eq $parameter -and [T] -ne [object]) {
            return $false
        }

        try {
            $typedParam = [T]$parameter
            return $this.canExecutePredicate.Invoke($typedParam)
        } catch {
            return $false
        }
    }

    [void] Execute([object]$parameter) {
        if ($this.CanExecute($parameter)) {
            $typedParam = [T]$parameter
            $this.executeAction.Invoke($typedParam)
        }
    }

    [void] RaiseCanExecuteChanged() {
        if ($null -ne $this.CanExecuteChanged) {
            $this.CanExecuteChanged.Invoke($this, [EventArgs]::Empty)
        }

        [CommandManager]::InvalidateRequerySuggested()
    }
}

# Factory para crear comandos mÃ¡s fÃ¡cilmente
class CommandFactory {
    static [RelayCommand] Create([ScriptBlock]$execute) {
        return [RelayCommand]::new($execute)
    }

    static [RelayCommand] Create([ScriptBlock]$execute, [ScriptBlock]$canExecute) {
        return [RelayCommand]::new($execute, $canExecute)
    }

    static [RelayCommand] CreateAsync([ScriptBlock]$executeAsync) {
        $asyncExecute = {
            param($parameter)

            $task = [System.Threading.Tasks.Task]::Run({
                    & $executeAsync $parameter
                })
        }

        return [RelayCommand]::new($asyncExecute)
    }

    static [RelayCommand] CreateAsync([ScriptBlock]$executeAsync, [ScriptBlock]$canExecute) {
        $asyncExecute = {
            param($parameter)

            $task = [System.Threading.Tasks.Task]::Run({
                    & $executeAsync $parameter
                })
        }

        return [RelayCommand]::new($asyncExecute, $canExecute)
    }
}
