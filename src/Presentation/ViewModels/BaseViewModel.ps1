# BaseViewModel.ps1 - Clase base para ViewModels con INotifyPropertyChanged
using namespace System.ComponentModel
using namespace System.Collections.Generic
using namespace System.Runtime.CompilerServices

class BaseViewModel : INotifyPropertyChanged {
    hidden [PropertyChangedEventHandler]$PropertyChanged
    hidden [Dictionary[string, object]]$properties
    hidden [bool]$IsBusy
    hidden [string]$Title

    BaseViewModel() {
        $this.properties = [Dictionary[string, object]]::new()
        $this.IsBusy = $false
        $this.Title = ""
    }

    # ImplementaciÃ³n de INotifyPropertyChanged
    [void] add_PropertyChanged([PropertyChangedEventHandler]$handler) {
        $this.PropertyChanged = [Delegate]::Combine($this.PropertyChanged, $handler)
    }

    [void] remove_PropertyChanged([PropertyChangedEventHandler]$handler) {
        $this.PropertyChanged = [Delegate]::Remove($this.PropertyChanged, $handler)
    }

    # MÃ©todo para notificar cambios de propiedad
    [void] OnPropertyChanged([string]$propertyName) {
        if ($null -ne $this.PropertyChanged) {
            $args = [PropertyChangedEventArgs]::new($propertyName)
            $this.PropertyChanged.Invoke($this, $args)
        }
    }

    # MÃ©todo helper para establecer propiedades y notificar cambios
    [bool] SetProperty([ref]$storage, [object]$value, [string]$propertyName) {
        if ([object]::Equals($storage.Value, $value)) {
            return $false
        }

        $storage.Value = $value
        $this.OnPropertyChanged($propertyName)
        return $true
    }

    # MÃ©todo alternativo usando diccionario interno
    [object] GetPropertyValue([string]$propertyName) {
        if ($this.properties.ContainsKey($propertyName)) {
            return $this.properties[$propertyName]
        }
        return $null
    }

    [void] SetPropertyValue([object]$value, [string]$propertyName) {
        $oldValue = $null
        if ($this.properties.ContainsKey($propertyName)) {
            $oldValue = $this.properties[$propertyName]
        }

        if (-not [object]::Equals($oldValue, $value)) {
            $this.properties[$propertyName] = $value
            $this.OnPropertyChanged($propertyName)
        }
    }

    # Propiedades comunes
    [bool] GetIsBusy() {
        return $this.IsBusy
    }

    [void] SetIsBusy([bool]$value) {
        if ($this.IsBusy -ne $value) {
            $this.IsBusy = $value
            $this.OnPropertyChanged("IsBusy")
            $this.OnPropertyChanged("IsNotBusy")
        }
    }

    [bool] GetIsNotBusy() {
        return -not $this.IsBusy
    }

    [string] GetTitle() {
        return $this.Title
    }

    [void] SetTitle([string]$value) {
        if ($this.Title -ne $value) {
            $this.Title = $value
            $this.OnPropertyChanged("Title")
        }
    }

    # MÃ©todo para ejecutar acciones en el UI thread
    [void] InvokeOnUIThread([ScriptBlock]$action) {
        if ([System.Windows.Forms.Application]::MessageLoop) {
            # Estamos en el UI thread
            & $action
        } else {
            # Necesitamos invocar en el UI thread
            [System.Windows.Forms.Application]::Current.Dispatcher.Invoke($action)
        }
    }

    # MÃ©todo para validaciÃ³n
    hidden [Dictionary[string, List[string]]]$errors = [Dictionary[string, List[string]]]::new()

    [bool] HasErrors() {
        return $this.errors.Count -gt 0
    }

    [List[string]] GetErrors([string]$propertyName) {
        if ($this.errors.ContainsKey($propertyName)) {
            return $this.errors[$propertyName]
        }
        return [List[string]]::new()
    }

    [void] AddError([string]$propertyName, [string]$errorMessage) {
        if (-not $this.errors.ContainsKey($propertyName)) {
            $this.errors[$propertyName] = [List[string]]::new()
        }

        if (-not $this.errors[$propertyName].Contains($errorMessage)) {
            $this.errors[$propertyName].Add($errorMessage)
            $this.OnPropertyChanged("HasErrors")
            $this.OnErrorsChanged($propertyName)
        }
    }

    [void] RemoveError([string]$propertyName, [string]$errorMessage) {
        if ($this.errors.ContainsKey($propertyName)) {
            $this.errors[$propertyName].Remove($errorMessage) | Out-Null

            if ($this.errors[$propertyName].Count -eq 0) {
                $this.errors.Remove($propertyName)
            }

            $this.OnPropertyChanged("HasErrors")
            $this.OnErrorsChanged($propertyName)
        }
    }

    [void] ClearErrors([string]$propertyName) {
        if ($this.errors.ContainsKey($propertyName)) {
            $this.errors.Remove($propertyName)
            $this.OnPropertyChanged("HasErrors")
            $this.OnErrorsChanged($propertyName)
        }
    }

    [void] ClearAllErrors() {
        $this.errors.Clear()
        $this.OnPropertyChanged("HasErrors")
    }

    # Evento para cambios en errores
    hidden [EventHandler[DataErrorsChangedEventArgs]]$ErrorsChanged

    [void] add_ErrorsChanged([EventHandler[DataErrorsChangedEventArgs]]$handler) {
        $this.ErrorsChanged = [Delegate]::Combine($this.ErrorsChanged, $handler)
    }

    [void] remove_ErrorsChanged([EventHandler[DataErrorsChangedEventArgs]]$handler) {
        $this.ErrorsChanged = [Delegate]::Remove($this.ErrorsChanged, $handler)
    }

    [void] OnErrorsChanged([string]$propertyName) {
        if ($null -ne $this.ErrorsChanged) {
            $args = [DataErrorsChangedEventArgs]::new($propertyName)
            $this.ErrorsChanged.Invoke($this, $args)
        }
    }
}

# Clase base para ViewModels con colecciones observables
class CollectionViewModel : BaseViewModel {
    hidden [System.Collections.ObjectModel.ObservableCollection[object]]$items
    hidden [object]$selectedItem
    hidden [List[object]]$selectedItems

    CollectionViewModel() {
        $this.items = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
        $this.selectedItems = [List[object]]::new()
    }

    [System.Collections.ObjectModel.ObservableCollection[object]] GetItems() {
        return $this.items
    }

    [void] AddItem([object]$item) {
        $this.items.Add($item)
        $this.OnPropertyChanged("Items")
        $this.OnPropertyChanged("ItemCount")
        $this.OnPropertyChanged("HasItems")
    }

    [void] RemoveItem([object]$item) {
        $this.items.Remove($item) | Out-Null
        $this.OnPropertyChanged("Items")
        $this.OnPropertyChanged("ItemCount")
        $this.OnPropertyChanged("HasItems")
    }

    [void] ClearItems() {
        $this.items.Clear()
        $this.OnPropertyChanged("Items")
        $this.OnPropertyChanged("ItemCount")
        $this.OnPropertyChanged("HasItems")
    }

    [int] GetItemCount() {
        return $this.items.Count
    }

    [bool] GetHasItems() {
        return $this.items.Count -gt 0
    }

    [object] GetSelectedItem() {
        return $this.selectedItem
    }

    [void] SetSelectedItem([object]$value) {
        if ($this.selectedItem -ne $value) {
            $this.selectedItem = $value
            $this.OnPropertyChanged("SelectedItem")
            $this.OnPropertyChanged("HasSelection")
            $this.OnSelectionChanged()
        }
    }

    [List[object]] GetSelectedItems() {
        return $this.selectedItems
    }

    [void] SetSelectedItems([List[object]]$value) {
        $this.selectedItems = $value
        $this.OnPropertyChanged("SelectedItems")
        $this.OnPropertyChanged("HasMultipleSelection")
        $this.OnPropertyChanged("SelectionCount")
    }

    [bool] GetHasSelection() {
        return $null -ne $this.selectedItem
    }

    [bool] GetHasMultipleSelection() {
        return $this.selectedItems.Count -gt 0
    }

    [int] GetSelectionCount() {
        return $this.selectedItems.Count
    }

    # MÃ©todo virtual para manejar cambios de selecciÃ³n
    [void] OnSelectionChanged() {
        # Override en clases derivadas
    }

    # MÃ©todos de filtrado y bÃºsqueda
    [void] FilterItems([ScriptBlock]$predicate) {
        $filtered = $this.items | Where-Object $predicate
        $this.items.Clear()

        foreach ($item in $filtered) {
            $this.items.Add($item)
        }

        $this.OnPropertyChanged("Items")
        $this.OnPropertyChanged("ItemCount")
        $this.OnPropertyChanged("HasItems")
    }

    [void] SortItems([ScriptBlock]$keySelector) {
        $sorted = $this.items | Sort-Object $keySelector
        $this.items.Clear()

        foreach ($item in $sorted) {
            $this.items.Add($item)
        }

        $this.OnPropertyChanged("Items")
    }
}
