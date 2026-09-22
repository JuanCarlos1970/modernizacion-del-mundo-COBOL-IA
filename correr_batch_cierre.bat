@echo off
setlocal
rem Se posiciona en la carpeta donde esta este .bat, para que
rem funcione sin importar desde donde se lo invoque (doble clic,
rem otra carpeta, un acceso directo, etc).
cd /d "%~dp0"

rem =================================================================
rem  correr_batch_cierre.bat
rem
rem  Compila BATCH-CIERRE.cbl y lo ejecuta. Simula, en este entorno
rem  local, la ejecucion de un job batch nocturno: en un mainframe
rem  z/OS real, este mismo proceso correria via el JCL de referencia
rem  batch_cierre.jcl (ver ese archivo y la seccion "Proceso Batch
rem  de Cierre" de README.md).
rem
rem  IMPORTANTE: el .exe se compila DENTRO de bin\ y se ejecuta ahi
rem  mismo, para que trabaje siempre sobre bin\clientes_v3.dat (el
rem  mismo archivo que usan cuenta.exe y LISTADO-CLIENTES.exe), en
rem  vez de crear un clientes_v3.dat aparte en esta carpeta. reporte_
rem  cierre.txt tambien queda en bin\. Ver README.md, seccion
rem  "Dónde vive clientes_v3.dat".
rem
rem  Requisitos: GnuCOBOL (cobc) instalado. Si "cobc" no esta en el
rem  PATH, este script intenta usar la instalacion de OpenCobolIDE
rem  detectada en esta maquina (ajustar GNUCOBOL_DIR si no aplica).
rem
rem  IMPORTANTE: no correr este script mientras cuenta.exe esta
rem  abierto sobre el mismo clientes_v3.dat (ver limitacion de
rem  acceso concurrente en README.md).
rem =================================================================

if not exist "bin" mkdir "bin"

set "GNUCOBOL_DIR=C:\Program Files (x86)\OpenCobolIDE\GnuCOBOL"

where cobc >nul 2>nul
if errorlevel 1 (
    if exist "%GNUCOBOL_DIR%\bin\cobc.exe" (
        echo [correr_batch_cierre] "cobc" no esta en el PATH; usando
        echo [correr_batch_cierre] la instalacion de OpenCobolIDE en
        echo [correr_batch_cierre] "%GNUCOBOL_DIR%".
        set "PATH=%GNUCOBOL_DIR%\bin;%PATH%"
        set "COB_CONFIG_DIR=%GNUCOBOL_DIR%\config"
        set "COB_COPY_DIR=%GNUCOBOL_DIR%\copy"
    ) else (
        echo [correr_batch_cierre] ERROR: no se encontro "cobc" en el
        echo [correr_batch_cierre] PATH ni en "%GNUCOBOL_DIR%".
        echo [correr_batch_cierre] Instale GnuCOBOL o ajuste
        echo [correr_batch_cierre] GNUCOBOL_DIR en este script.
        exit /b 1
    )
)

echo [correr_batch_cierre] Compilando BATCH-CIERRE.cbl en bin\ ...
cobc -x -Wall -o "bin\BATCH-CIERRE.exe" BATCH-CIERRE.cbl
if errorlevel 1 (
    echo [correr_batch_cierre] ERROR: fallo la compilacion. Revise
    echo [correr_batch_cierre] los mensajes de cobc.
    exit /b 1
)

echo [correr_batch_cierre] Compilacion OK. Ejecutando el cierre en
echo [correr_batch_cierre] bin\ (sobre bin\clientes_v3.dat) ...
echo.
pushd "bin"
".\BATCH-CIERRE.exe"
set "RC=%ERRORLEVEL%"
popd

echo.
if "%RC%"=="0" (
    echo [correr_batch_cierre] Cierre finalizado. Ver bin\reporte_cierre.txt
) else (
    echo [correr_batch_cierre] El cierre termino con errores. RC=%RC%
    echo [correr_batch_cierre] Ver los mensajes de arriba y, si se
    echo [correr_batch_cierre] genero, bin\reporte_cierre.txt.
)

endlocal
exit /b %RC%
