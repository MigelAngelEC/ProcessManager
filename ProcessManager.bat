@echo off
title Process Manager Pro - Nueva Arquitectura
color 0B

echo ================================================================
echo                    PROCESS MANAGER PRO v2.0
echo                      Nueva Arquitectura MVVM
echo ================================================================
echo.

cd /d "%~dp0"

REM Verificar si existe el nuevo launcher
if exist "ProcessManager.ps1" (
    echo [OK] Launcher principal encontrado
    echo.
    echo Iniciando Process Manager...
    echo.
    
    REM Ejecutar el nuevo launcher con todos los argumentos pasados
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0ProcessManager.ps1" %*
    
    if %errorLevel% NEQ 0 (
        echo.
        echo [ERROR] Hubo un problema al ejecutar Process Manager
        echo Codigo de error: %errorLevel%
    )
) else (
    echo [ERROR] No se encuentra ProcessManager.ps1
    echo.
    
    REM Intentar con la estructura antigua si existe
    if exist "src\core\ProcessManagerModular.ps1" (
        echo Detectada estructura antigua, intentando ejecutar...
        powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0src\core\ProcessManagerModular.ps1'"
    ) else if exist "src\legacy\ProcessManager.ps1" (
        echo Ejecutando version legacy...
        powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0src\legacy\ProcessManager.ps1'"
    ) else (
        echo.
        echo No se encuentra ninguna version ejecutable del sistema.
        echo Por favor, reinstale Process Manager o contacte soporte.
    )
)

pause