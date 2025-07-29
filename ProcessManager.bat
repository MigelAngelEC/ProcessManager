@echo off
echo Ejecutando Process Manager Pro - Solucion Rapida
echo.

cd /d "%~dp0"

echo Verificando estructura del proyecto...
echo.

if exist "src\core\ProcessManagerModular.ps1" (
    echo [OK] Sistema modular encontrado
    echo.
    echo Intentando ejecutar sistema modular...
    powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0src\core\ProcessManagerModular.ps1'"
    
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