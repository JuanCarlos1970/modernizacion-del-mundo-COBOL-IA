@echo off
setlocal
rem Se posiciona en la carpeta donde esta este .bat, para que
rem funcione sin importar desde donde se lo invoque (doble clic,
rem otra carpeta, un acceso directo, etc).
cd /d "%~dp0"

rem =================================================================
rem  correr_carga_masiva.bat
rem
rem  Compila CARGA-MASIVA.cbl y lo ejecuta: carga clientes, tasas y
rem  plazos fijos desde un archivo de texto (ver la seccion "Carga
rem  masiva" de README.md).
rem
rem  IMPORTANTE: el .exe se compila DENTRO de bin\ y se ejecuta ahi
rem  mismo, para que trabaje siempre sobre los .dat de bin\
rem  (clientes_v3.dat, intereses.dat y plazofijo.dat, los mismos que
rem  usa gestion-bancaria.exe). Por eso el archivo de carga tambien
rem  se busca en bin\: bin\carga.txt, o el nombre que diga la
rem  variable de entorno ARCHIVO_CARGA (relativo a bin\). Los
rem  reportes carga_ok.txt y carga_rechazos.txt quedan en bin\.
rem
rem  Si todo sale bien (codigo 0), el archivo de carga se renombra a
rem  <nombre>.procesado.AAAAMMDD.HHMMSS para que no se cargue dos
rem  veces. Con codigo 8 no se renombra.
rem
rem  Requisitos: GnuCOBOL (cobc) instalado. Si "cobc" no esta en el
rem  PATH, este script intenta usar la instalacion de OpenCobolIDE
rem  detectada en esta maquina (ajustar GNUCOBOL_DIR si no aplica).
rem
rem  IMPORTANTE: no correr este script mientras gestion-bancaria.exe
rem  o el batch de cierre estan abiertos sobre los mismos archivos.
rem =================================================================

if not exist "bin" mkdir "bin"

set "GNUCOBOL_DIR=C:\Program Files (x86)\OpenCobolIDE\GnuCOBOL"

where cobc >nul 2>nul
if errorlevel 1 (
    if exist "%GNUCOBOL_DIR%\bin\cobc.exe" (
        echo [correr_carga_masiva] "cobc" no esta en el PATH; usando
        echo [correr_carga_masiva] la instalacion de OpenCobolIDE en
        echo [correr_carga_masiva] "%GNUCOBOL_DIR%".
        set "PATH=%GNUCOBOL_DIR%\bin;%PATH%"
        set "COB_CONFIG_DIR=%GNUCOBOL_DIR%\config"
        set "COB_COPY_DIR=%GNUCOBOL_DIR%\copy"
    ) else (
        echo [correr_carga_masiva] ERROR: no se encontro "cobc" en el
        echo [correr_carga_masiva] PATH ni en "%GNUCOBOL_DIR%".
        echo [correr_carga_masiva] Instale GnuCOBOL o ajuste
        echo [correr_carga_masiva] GNUCOBOL_DIR en este script.
        exit /b 1
    )
)

echo [correr_carga_masiva] Compilando CARGA-MASIVA.cbl en bin\ ...
cobc -x -Wall -o "bin\CARGA-MASIVA.exe" CARGA-MASIVA.cbl
if errorlevel 1 (
    echo [correr_carga_masiva] ERROR: fallo la compilacion. Revise
    echo [correr_carga_masiva] los mensajes de cobc.
    exit /b 1
)

echo [correr_carga_masiva] Compilacion OK. Ejecutando la carga en
echo [correr_carga_masiva] bin\ (sobre los .dat de bin\) ...
echo.
pushd "bin"
".\CARGA-MASIVA.exe"
set "RC=%ERRORLEVEL%"
popd

echo.
if "%RC%"=="0" (
    echo [correr_carga_masiva] Carga finalizada ^(codigo 0^). Ver
    echo [correr_carga_masiva] bin\carga_ok.txt y bin\carga_rechazos.txt
) else (
    echo [correr_carga_masiva] La carga no pudo correr. RC=%RC%
    echo [correr_carga_masiva] Ver los mensajes de arriba. El archivo
    echo [correr_carga_masiva] de carga NO se renombro.
)

rem En la misma linea: %RC% se reemplaza por su valor ANTES de que
rem endlocal borre la variable (en dos lineas, exit recibiria vacio
rem y el codigo de retorno se perderia).
endlocal & exit /b %RC%
