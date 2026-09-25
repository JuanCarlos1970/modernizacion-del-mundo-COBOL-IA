@echo off
setlocal EnableDelayedExpansion
rem Se posiciona en la carpeta donde esta este .bat, para que
rem funcione sin importar desde donde se lo invoque.
cd /d "%~dp0"

rem =================================================================
rem  correr_pruebas_automatizadas.bat
rem
rem  Compila cuenta.exe, corre los 5 casos de prueba automatizados
rem  de CASOS_DE_PRUEBA.md (entrada_*.txt -> salida_*.txt) y ademas
rem  compara cada salida_*.txt contra su resultado esperado
rem  (esperado_*.txt) con "fc" (File Compare, incluido en Windows,
rem  no requiere instalar nada). Al final muestra un resumen
rem  PASS/FALLO de los 5 casos, en vez de dejar la comparacion para
rem  hacer a mano contra CASOS_DE_PRUEBA.md.
rem
rem  El resumen se muestra en pantalla Y ADEMAS se guarda en
rem  resultado_pruebas.txt (en esta misma carpeta), igual que
rem  correr_batch_cierre.bat deja bin\reporte_cierre.txt y
rem  ver_listado_clientes.bat deja bin\listado_clientes.txt: si se
rem  corrio haciendo doble clic, la ventana de consola se cierra
rem  sola al terminar y no da tiempo a leer el resultado ahi, pero
rem  el archivo queda para abrirlo con cualquier editor de texto.
rem
rem  Los esperado_*.txt son la salida ya verificada manualmente
rem  contra CASOS_DE_PRUEBA.md al momento de escribir este script:
rem  si en el futuro cuenta.cbl cambia a proposito (por ejemplo, se
rem  redacta distinto un mensaje), hay que regenerar el esperado_*.txt
rem  correspondiente a mano una vez, revisando que el nuevo texto sea
rem  correcto, y no automaticamente.
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
rem  salida_*.txt, esperado_*.txt y resultado_pruebas.txt tambien
rem  viven aca, junto a CASOS_DE_PRUEBA.md. Ver README.md, seccion
rem  "Donde vive clientes_v3.dat".
rem
rem  Requisitos: GnuCOBOL (cobc) instalado. Si "cobc" no esta en el
rem  PATH, este script intenta usar la instalacion de OpenCobolIDE
rem  detectada en esta maquina (ajustar GNUCOBOL_DIR si no aplica).
rem =================================================================

rem Ruta absoluta del log, calculada ANTES de cualquier pushd, para
rem que valga sin importar desde que carpeta se escriba despues.
set "LOGFILE=%CD%\resultado_pruebas.txt"

echo Resultado de correr_pruebas_automatizadas.bat > "%LOGFILE%"
echo Fecha/hora: %DATE% %TIME% >> "%LOGFILE%"
echo. >> "%LOGFILE%"

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
        echo ERROR: no se encontro "cobc" en el PATH ni en "%GNUCOBOL_DIR%". >> "%LOGFILE%"
        exit /b 1
    )
)

echo [pruebas] Compilando cuenta.cbl en bin\ ...
cobc -x -Wall -o "bin\cuenta.exe" cuenta.cbl
if errorlevel 1 (
    echo [pruebas] ERROR: fallo la compilacion. Revise los mensajes
    echo [pruebas] de cobc arriba.
    echo ERROR: fallo la compilacion de cuenta.cbl. >> "%LOGFILE%"
    exit /b 1
)

echo [pruebas] Compilacion OK. Corriendo y verificando los 5 casos
echo [pruebas] automatizados desde bin\ (sobre bin\clientes_v3.dat) ...
echo.

set /a OK=0
set /a FALLO=0
set "CASOS_FALLIDOS="

pushd "bin"
for %%C in (alta_ok alta_dni_invalido deposito extraccion consulta) do (
    if not exist "..\entrada_%%C.txt" (
        echo [pruebas] ERROR: no se encuentra entrada_%%C.txt
        echo ERROR: no se encuentra entrada_%%C.txt >> "%LOGFILE%"
        popd
        exit /b 1
    )
    if not exist "..\esperado_%%C.txt" (
        echo [pruebas] ERROR: no se encuentra esperado_%%C.txt
        echo ERROR: no se encuentra esperado_%%C.txt >> "%LOGFILE%"
        popd
        exit /b 1
    )

    ".\cuenta.exe" < "..\entrada_%%C.txt" > "..\salida_%%C.txt"

    fc "..\esperado_%%C.txt" "..\salida_%%C.txt" >nul
    if errorlevel 1 (
        echo [pruebas]   FALLO  - %%C
        echo   FALLO  - %%C >> "%LOGFILE%"
        set /a FALLO+=1
        set "CASOS_FALLIDOS=!CASOS_FALLIDOS! %%C"
    ) else (
        echo [pruebas]   OK     - %%C
        echo   OK     - %%C >> "%LOGFILE%"
        set /a OK+=1
    )
)
popd

echo.
echo [pruebas] ==========================================
echo [pruebas]  Resumen: !OK! OK / !FALLO! FALLO ^(de 5^)
echo [pruebas] ==========================================

echo. >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"
echo  Resumen: !OK! OK / !FALLO! FALLO (de 5) >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"

if !FALLO! GTR 0 (
    echo.
    echo [pruebas] Casos que fallaron:!CASOS_FALLIDOS!
    echo [pruebas] Para ver la diferencia exacta de un caso, corra
    echo [pruebas] por ejemplo:
    echo [pruebas]   fc esperado_alta_ok.txt salida_alta_ok.txt
    echo.
    echo [pruebas] Si el cambio de salida es esperado ^(por ejemplo,
    echo [pruebas] se modifico a proposito un mensaje de cuenta.cbl^),
    echo [pruebas] revise el nuevo salida_*.txt a mano contra
    echo [pruebas] CASOS_DE_PRUEBA.md y, si esta correcto, actualice
    echo [pruebas] el esperado_*.txt correspondiente.

    echo. >> "%LOGFILE%"
    echo Casos que fallaron:!CASOS_FALLIDOS! >> "%LOGFILE%"
    echo Para ver la diferencia exacta de un caso, corra por ejemplo: >> "%LOGFILE%"
    echo   fc esperado_alta_ok.txt salida_alta_ok.txt >> "%LOGFILE%"

    echo.
    echo [pruebas] Resultado guardado en resultado_pruebas.txt
    endlocal
    exit /b 1
)

echo.
echo [pruebas] Los 5 casos automatizados pasaron.
echo Los 5 casos automatizados pasaron. >> "%LOGFILE%"
echo.
echo [pruebas] Resultado guardado en resultado_pruebas.txt
endlocal
exit /b 0
