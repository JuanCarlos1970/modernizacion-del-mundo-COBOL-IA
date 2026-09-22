@echo off
setlocal
rem Se posiciona en la carpeta donde esta este .bat, para que
rem funcione sin importar desde donde se lo invoque (doble clic,
rem otra carpeta, un acceso directo, etc).
cd /d "%~dp0"

rem =================================================================
rem  ver_listado_clientes.bat
rem
rem  Compila LISTADO-CLIENTES.cbl y lo ejecuta. Programa de SOLO
rem  LECTURA: muestra la cartera de clientes agrupada por estado
rem  (Activos, Reactivados, Inactivos) con un resumen final, tanto
rem  por pantalla como en listado_clientes.txt. No modifica
rem  clientes_v3.dat bajo ninguna circunstancia (a diferencia de
rem  correr_batch_cierre.bat, que si actualiza saldos).
rem
rem  IMPORTANTE: el .exe se compila DENTRO de bin\ y se ejecuta ahi
rem  mismo, para que lea siempre bin\clientes_v3.dat (el mismo
rem  archivo que usan cuenta.exe y BATCH-CIERRE.exe), en vez de
rem  crear/leer un clientes_v3.dat aparte en esta carpeta. listado_
rem  clientes.txt tambien queda en bin\. Ver README.md, seccion
rem  "Dónde vive clientes_v3.dat".
rem
rem  Requisitos: GnuCOBOL (cobc) instalado. Si "cobc" no esta en el
rem  PATH, este script intenta usar la instalacion de OpenCobolIDE
rem  detectada en esta maquina (ajustar GNUCOBOL_DIR si no aplica).
rem =================================================================

if not exist "bin" mkdir "bin"

set "GNUCOBOL_DIR=C:\Program Files (x86)\OpenCobolIDE\GnuCOBOL"

where cobc >nul 2>nul
if errorlevel 1 (
    if exist "%GNUCOBOL_DIR%\bin\cobc.exe" (
        echo [ver_listado_clientes] "cobc" no esta en el PATH; usando
        echo [ver_listado_clientes] la instalacion de OpenCobolIDE en
        echo [ver_listado_clientes] "%GNUCOBOL_DIR%".
        set "PATH=%GNUCOBOL_DIR%\bin;%PATH%"
        set "COB_CONFIG_DIR=%GNUCOBOL_DIR%\config"
        set "COB_COPY_DIR=%GNUCOBOL_DIR%\copy"
    ) else (
        echo [ver_listado_clientes] ERROR: no se encontro "cobc" en el
        echo [ver_listado_clientes] PATH ni en "%GNUCOBOL_DIR%".
        echo [ver_listado_clientes] Instale GnuCOBOL o ajuste
        echo [ver_listado_clientes] GNUCOBOL_DIR en este script.
        exit /b 1
    )
)

echo [ver_listado_clientes] Compilando LISTADO-CLIENTES.cbl en bin\ ...
cobc -x -Wall -o "bin\LISTADO-CLIENTES.exe" LISTADO-CLIENTES.cbl
if errorlevel 1 (
    echo [ver_listado_clientes] ERROR: fallo la compilacion. Revise
    echo [ver_listado_clientes] los mensajes de cobc.
    exit /b 1
)

echo [ver_listado_clientes] Compilacion OK. Generando el listado
echo [ver_listado_clientes] desde bin\ (lee bin\clientes_v3.dat) ...
echo.
pushd "bin"
".\LISTADO-CLIENTES.exe"
set "RC=%ERRORLEVEL%"
popd

echo.
if "%RC%"=="0" (
    echo [ver_listado_clientes] Listo. Ver bin\listado_clientes.txt
) else (
    echo [ver_listado_clientes] Termino con errores. RC=%RC%
    echo [ver_listado_clientes] Ver los mensajes de arriba y, si se
    echo [ver_listado_clientes] genero, bin\listado_clientes.txt.
)

endlocal
exit /b %RC%
