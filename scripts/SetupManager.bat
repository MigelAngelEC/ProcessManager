@echo off
chcp 65001 >nul 2>&1
title Process Manager Pro - Instalador del Sistema Modular
color 0B

echo ================================================================
echo                PROCESS MANAGER PRO - INSTALADOR
echo                    Sistema Modular Avanzado
echo ================================================================
echo.

:: Verificar permisos de administrador
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [✓] Ejecutando como Administrador
) else (
    echo [!] RECOMENDACION: Ejecutar como Administrador para mejor funcionamiento
)

echo.
echo [INFO] Verificando archivos del sistema...
echo.

:: Crear directorio de instalacion si no existe
set "INSTALL_DIR=%~dp0"
set "CONFIG_DIR=%USERPROFILE%\Documents\ProcessManager"

:: Verificar archivos necesarios
set "FILES_FOUND=0"
set "TOTAL_FILES=0"

echo Verificando archivos principales:
echo --------------------------------

if exist "%INSTALL_DIR%config\ProcessConfig.json" (
    echo [✓] ProcessConfig.json - ENCONTRADO
    set /a FILES_FOUND+=1
) else (
    echo [✗] ProcessConfig.json - FALTANTE
)
set /a TOTAL_FILES+=1

if exist "%INSTALL_DIR%src\core\ConfigManager.ps1" (
    echo [✓] ConfigManager.ps1 - ENCONTRADO  
    set /a FILES_FOUND+=1
) else (
    echo [✗] ConfigManager.ps1 - FALTANTE
)
set /a TOTAL_FILES+=1

if exist "%INSTALL_DIR%src\core\ProcessManagerModular.ps1" (
    echo [✓] ProcessManagerModular.ps1 - ENCONTRADO
    set /a FILES_FOUND+=1
) else (
    echo [✗] ProcessManagerModular.ps1 - FALTANTE
)
set /a TOTAL_FILES+=1

if exist "%INSTALL_DIR%ProcessManager.bat" (
    echo [✓] ProcessManager.bat - ENCONTRADO
    set /a FILES_FOUND+=1
) else (
    echo [✗] ProcessManager.bat - FALTANTE
)
set /a TOTAL_FILES+=1

echo.
echo Verificando archivos de respaldo:
echo ---------------------------------

if exist "%INSTALL_DIR%src\legacy\ProcessManager.ps1" (
    echo [✓] ProcessManager.ps1 (clasico) - DISPONIBLE
) else (
    echo [!] ProcessManager.ps1 (clasico) - NO DISPONIBLE
)

if exist "%INSTALL_DIR%src\legacy\ProcessManagerSimple.ps1" (
    echo [✓] ProcessManagerSimple.ps1 (consola) - DISPONIBLE
) else (
    echo [!] ProcessManagerSimple.ps1 (consola) - NO DISPONIBLE
)

echo.
echo ================================================================
echo RESUMEN DE INSTALACION:
echo ================================================================
echo Archivos principales encontrados: %FILES_FOUND% de %TOTAL_FILES%

if %FILES_FOUND% EQU %TOTAL_FILES% (
    echo [✓] INSTALACION COMPLETA - Sistema modular listo
    echo.
    echo El sistema incluye:
    echo • Configuracion externa editable (ProcessConfig.json)
    echo • Gestor de configuracion avanzado (ConfigManager.ps1)  
    echo • Interfaz modular mejorada (ProcessManagerModular.ps1)
    echo • Ejecutor inteligente (ProcessManager.bat)
    echo.
    goto :COMPLETE_SETUP
) else (
    echo [!] INSTALACION INCOMPLETA - Faltan archivos
    echo.
    goto :INCOMPLETE_SETUP
)

:COMPLETE_SETUP
echo [CONFIGURACION] Preparando directorios...

:: Crear directorio de configuracion de usuario
if not exist "%CONFIG_DIR%" (
    mkdir "%CONFIG_DIR%" 2>nul
    if exist "%CONFIG_DIR%" (
        echo [✓] Directorio de configuracion creado: %CONFIG_DIR%
    ) else (
        echo [!] No se pudo crear directorio de configuracion
    )
) else (
    echo [✓] Directorio de configuracion ya existe: %CONFIG_DIR%
)

echo.
echo [VALIDACION] Probando configuracion...

:: Probar carga de configuracion
powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "try { $config = Get-Content '%INSTALL_DIR%config\ProcessConfig.json' | ConvertFrom-Json; Write-Host '[✓] Archivo JSON valido - Version: ' $config.version -ForegroundColor Green; Write-Host '[✓] Categorias encontradas: ' $config.categories.PSObject.Properties.Count -ForegroundColor Green } catch { Write-Host '[✗] Error en archivo JSON: ' $_.Exception.Message -ForegroundColor Red }" 2>nul

echo.
echo ================================================================
echo                    INSTALACION COMPLETADA
echo ================================================================
echo.
echo ¿Como usar Process Manager Pro?
echo.
echo 1. METODO RECOMENDADO:
echo    • Doble clic en "ProcessManager.bat"
echo.
echo 2. METODO MANUAL:
echo    • Abrir PowerShell como Administrador
echo    • Navegar a la carpeta: cd "%INSTALL_DIR%src\core"  
echo    • Ejecutar: .\ProcessManagerModular.ps1
echo.
echo 3. PERSONALIZACION:
echo    • Editar "config\ProcessConfig.json" para agregar/quitar procesos
echo    • Cambiar prioridades, colores y categorias
echo    • Las configuraciones se guardan en: %CONFIG_DIR%
echo.
echo ================================================================
echo.

set /p "LAUNCH=¿Deseas ejecutar Process Manager Pro ahora? (S/N): "
if /i "%LAUNCH%"=="S" (
    echo.
    echo [EJECUTANDO] Iniciando Process Manager Pro...
    call "%INSTALL_DIR%ProcessManager.bat"
) else (
    echo.
    echo [INFO] Process Manager Pro esta listo para usar
    echo Ejecuta "ProcessManager.bat" cuando lo necesites
)
goto :END

:INCOMPLETE_SETUP
echo.
echo ARCHIVOS FALTANTES - Necesitas descargar:
echo.

if not exist "%INSTALL_DIR%config\ProcessConfig.json" (
    echo • config\ProcessConfig.json - Archivo de configuracion principal
)

if not exist "%INSTALL_DIR%src\core\ConfigManager.ps1" (
    echo • src\core\ConfigManager.ps1 - Gestor de configuracion  
)

if not exist "%INSTALL_DIR%src\core\ProcessManagerModular.ps1" (
    echo • src\core\ProcessManagerModular.ps1 - Interfaz principal
)

if not exist "%INSTALL_DIR%ProcessManager.bat" (
    echo • ProcessManager.bat - Ejecutor del sistema
)

echo.
echo OPCIONES DISPONIBLES:
echo.

if exist "%INSTALL_DIR%src\legacy\ProcessManager.ps1" (
    echo [OPCION 1] Version clasica disponible
    set /p "USE_CLASSIC=¿Usar version clasica? (S/N): "
    if /i "!USE_CLASSIC!"=="S" (
        echo Ejecutando version clasica...
        powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%INSTALL_DIR%src\legacy\ProcessManager.ps1"
        goto :END
    )
)

if exist "%INSTALL_DIR%src\legacy\ProcessManagerSimple.ps1" (
    echo [OPCION 2] Version de consola disponible  
    set /p "USE_SIMPLE=¿Usar version de consola? (S/N): "
    if /i "!USE_SIMPLE!"=="S" (
        echo Ejecutando version de consola...
        powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%INSTALL_DIR%src\legacy\ProcessManagerSimple.ps1"
        goto :END
    )
)

echo.
echo [RECOMENDACION] Descarga todos los archivos del sistema modular
echo para obtener la mejor experiencia.

:END
echo.
echo ================================================================
echo Presiona cualquier tecla para salir...
pause >nul
exit