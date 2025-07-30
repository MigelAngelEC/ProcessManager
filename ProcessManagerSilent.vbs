' ProcessManagerSilent.vbs - Ejecuta Process Manager sin ventana de consola
' Este script VBS ejecuta el PowerShell script sin mostrar ventana de comando

Dim objShell, strPath, strCommand

Set objShell = CreateObject("WScript.Shell")

' Obtener la ruta del script
strPath = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))

' Verificar qué versión ejecutar
Dim fso
Set fso = CreateObject("Scripting.FileSystemObject")

If fso.FileExists(strPath & "src\core\ProcessManagerModular_Enhanced.ps1") Then
    ' Ejecutar versión mejorada
    strCommand = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File """ & strPath & "src\core\ProcessManagerModular_Enhanced.ps1"""
ElseIf fso.FileExists(strPath & "src\core\ProcessManagerModular.ps1") Then
    ' Ejecutar versión modular original
    strCommand = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File """ & strPath & "src\core\ProcessManagerModular.ps1"""
ElseIf fso.FileExists(strPath & "src\legacy\ProcessManager.ps1") Then
    ' Ejecutar versión legacy
    strCommand = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File """ & strPath & "src\legacy\ProcessManager.ps1"""
Else
    ' Error: no se encontró ninguna versión
    MsgBox "No se encontró ninguna versión de Process Manager en la estructura del proyecto.", vbCritical, "Error"
    WScript.Quit
End If

' Ejecutar el comando sin mostrar ventana
objShell.Run strCommand, 0, False

Set objShell = Nothing
Set fso = Nothing