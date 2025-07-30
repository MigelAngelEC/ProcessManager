@echo off
echo Ejecutando Process Manager Pro - Solucion Rapida
echo.

cd /d "%~dp0"

echo Verificando estructura del proyecto...
echo.

if exist "src\core\ProcessManager.ps1" (
    echo [OK] Process Manager encontrado
    echo.
    echo Ejecutando Process Manager Pro...
    powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0src\core\ProcessManager.ps1'"
    
    if %errorLevel% NEQ 0 (
        echo.
        echo [ERROR] Hubo un problema al ejecutar Process Manager
        echo Codigo de error: %errorLevel%
        echo.
        echo Intente ejecutar ProcessManagerSilent.vbs en su lugar
    )
) else (
    echo [ERROR] No se encuentra ProcessManager.ps1
    echo.
    echo Verificando versiones legacy...
    if exist "src\legacy\ProcessManager.ps1" (
        echo Ejecutando version legacy...
        powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0src\legacy\ProcessManager.ps1'"
    ) else (
        echo [ERROR] No se encuentra ninguna version de Process Manager
        echo Por favor verifique la instalacion
    )
)

pause