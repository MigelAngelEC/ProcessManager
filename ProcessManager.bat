@echo off
echo Ejecutando Process Manager Pro - Solucion Rapida
echo.

cd /d "%~dp0"

echo Verificando estructura del proyecto...
echo.

if exist "src\core\ProcessManagerModular_Enhanced_v2.ps1" (
    echo [OK] Sistema modular mejorado v2 encontrado
    echo.
    echo Intentando ejecutar sistema modular mejorado v2...
    powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0src\core\ProcessManagerModular_Enhanced_v2.ps1'"
    
    if %errorLevel% NEQ 0 (
        echo.
        echo Error con version v2, intentando version mejorada original...
        if exist "src\core\ProcessManagerModular_Enhanced.ps1" (
            powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0src\core\ProcessManagerModular_Enhanced.ps1'"
        )
    )
    
    if %errorLevel% NEQ 0 (
        echo.
        echo Error con version mejorada, intentando version modular original...
        if exist "src\core\ProcessManagerModular.ps1" (
            powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0src\core\ProcessManagerModular.ps1'"
        )
    )
    
    if %errorLevel% NEQ 0 (
        echo.
        echo Error con version modular, verificando versiones legacy...
        if exist "src\legacy\ProcessManager.ps1" (
            echo Probando version clasica...
            powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0src\legacy\ProcessManager.ps1'"
        )
        
        if %errorLevel% NEQ 0 (
            if exist "src\legacy\ProcessManagerSimple.ps1" (
                echo Probando version consola...
                powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0src\legacy\ProcessManagerSimple.ps1'"
            )
        )
    )
) else (
    echo [ERROR] No se encuentra la estructura del proyecto
    echo Por favor ejecute scripts\SetupManager.bat para configurar el proyecto
)

pause