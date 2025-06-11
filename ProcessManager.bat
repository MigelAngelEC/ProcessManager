@echo off
echo Ejecutando Process Manager Pro - Solucion Rapida
echo.

cd /d "%~dp0"

echo Archivos encontrados:
dir *.ps1 *.json

echo.
echo Intentando ejecutar sistema modular...

powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0ProcessManagerModular.ps1'"

if %errorLevel% NEQ 0 (
    echo.
    echo Error con version modular, probando version clasica...
    powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0ProcessManager.ps1'"
)

if %errorLevel% NEQ 0 (
    echo.
    echo Error con version clasica, probando version consola...
    powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0ProcessManagerSimple.ps1'"
)

pause