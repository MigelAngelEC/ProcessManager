' ProcessManagerSilent.vbs - Ejecuta Process Manager sin ventana de consola
' Este script VBS ejecuta el PowerShell script sin mostrar ventana de comando

Dim objShell, strPath, strCommand

Set objShell = CreateObject("WScript.Shell")

' Obtener la ruta del script
strPath = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))

' Verificar que existe el archivo principal
Dim fso
Set fso = CreateObject("Scripting.FileSystemObject")

If fso.FileExists(strPath & "src\core\ProcessManager.ps1") Then
    ' Ejecutar Process Manager
    strCommand = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File """ & strPath & "src\core\ProcessManager.ps1"""
Else
    ' Error: no se encontró el archivo
    MsgBox "No se encontró ProcessManager.ps1 en src\core\", vbCritical, "Error"
    WScript.Quit
End If

' Ejecutar el comando sin mostrar ventana
objShell.Run strCommand, 0, False

Set objShell = Nothing
Set fso = Nothing