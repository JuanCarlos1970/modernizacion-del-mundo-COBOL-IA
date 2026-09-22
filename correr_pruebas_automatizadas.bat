@echo off
setlocal
rem Se posiciona en la carpeta donde esta este .bat, para que
rem funcione sin importar desde donde se lo invoque.
cd /d "%~dp0"

rem =================================================================
rem  correr_pruebas_automatizadas.bat
rem
rem  Compila cuenta.exe y corre los 5 casos de prueba
rem  semi-automatizados de CASOS_DE_PRUEBA.md (entrada_*.txt ->
rem  salida_*.txt), con el runtime de GnuCOBOL correctamente
rem  puesto en el PATH para esta sesion.
rem
rem  Por que hace falta este script y no alcanza con escribir
rem  "cuenta.exe < entrada.txt > salida.txt" a mano: si la terminal
rem  donde se corre ese comando no tiene el runtime de GnuCOBOL
rem  (libcob y sus DLL) en el PATH, cuenta.exe falla al arrancar
rem  (Windows STATUS_DLL_NOT_FOUND) SIN mostrar ningun mensaje de
rem  error visible, y el archivo de salida queda en 0 bytes, porque
rem  cmd ya lo habia creado (vacio) por la redireccion antes de que
rem  el programa fallara. Ver README.md, seccion "Solucion de
rem  problemas", para el detalle.
rem
rem  IMPORTANTE: el .exe se compila DENTRO de bin\ y se ejecuta ahi
rem  mismo, para que los clientes de prueba (DNI 800000XX) queden
rem  en bin\clientes_v3.dat, el MISMO archivo que usan cuenta.exe,
rem  BATCH-CIERRE.exe y LISTADO-CLIENTES.exe (no en uno aparte en
rem  esta carpeta). Los entrada_*.txt se leen desde aca y los
rem  salida_*.txt tambien se escriben aca, para quedar junto a
rem  CASOS_DE_PRUEBA.md. Ver README.md, seccion "Dónde vive
rem  clientes_v3.dat".
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
        echo [pruebas] "cobc" no esta en el PATH; usando la
        echo [pruebas] instalacion de OpenCobolIDE en
        echo [pruebas] "%GNUCOBOL_DIR%".
        set "PATH=%GNUCOBOL_DIR%\bin;%PATH%"
        set "COB_CONFIG_DIR=%GNUCOBOL_DIR%\config"
        set "COB_COPY_DIR=%GNUCOBOL_DIR%\copy"
    ) else (
        echo [pruebas] ERROR: no se encontro "cobc" en el PATH ni
        echo [pruebas] en "%GNUCOBOL_DIR%". Instale GnuCOBOL o
        echo [pruebas] ajuste GNUCOBOL_DIR en este script.
        exit /b 1
    )
)

echo [pruebas] Compilando cuenta.cbl en bin\ ...
cobc -x -Wall -o "bin\cuenta.exe" cuenta.cbl
if errorlevel 1 (
    echo [pruebas] ERROR: fallo la compilacion. Revise los mensajes
    echo [pruebas] de cobc arriba.
    exit /b 1
)

echo [pruebas] Compilacion OK. Corriendo los 5 casos automatizados
echo [pruebas] desde bin\ (sobre bin\clientes_v3.dat) ...
echo.

pushd "bin"
for %%C in (alta_ok alta_dni_invalido deposito extraccion consulta) do (
    if not exist "..\entrada_%%C.txt" (
        echo [pruebas] ERROR: no se encuentra entrada_%%C.txt
        popd
        exit /b 1
    )
    echo [pruebas] entrada_%%C.txt -^> salida_%%C.txt
    ".\cuenta.exe" < "..\entrada_%%C.txt" > "..\salida_%%C.txt"
)
popd

echo.
echo [pruebas] Listo. Compare cada salida_*.txt contra el
echo [pruebas] "Resultado esperado" de CASOS_DE_PRUEBA.md.

endlocal
exit /b 0
