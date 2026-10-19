@echo off
setlocal EnableDelayedExpansion
rem Se posiciona en la carpeta donde esta este .bat, para que
rem funcione sin importar desde donde se lo invoque.
cd /d "%~dp0"

rem =================================================================
rem  correr_pruebas_automatizadas.bat
rem
rem  Compila gestion-bancaria.exe, corre los 5 casos de prueba automatizados
rem  de CASOS_DE_PRUEBA.md (entrada_*.txt -> salida_*.txt) y ademas
rem  compara cada salida_*.txt contra su resultado esperado
rem  (esperado_*.txt) con "fc" (File Compare, incluido en Windows,
rem  no requiere instalar nada). Al final muestra un resumen
rem  PASS/FALLO de los 5 casos, en vez de dejar la comparacion para
rem  hacer a mano contra CASOS_DE_PRUEBA.md.
rem
rem  Despues corre, en una segunda parte con su propio resumen, los
rem  casos de INTERESES (MENU-01 e INT-01 a INT-11), cada uno con un
rem  intereses.dat vacio y con fecha de proceso fija (ver mas abajo).
rem  En una tercera parte, los casos de PLAZO FIJO (PF-01 a PF-17),
rem  con la misma tecnica. Y por ultimo, en una cuarta parte, los
rem  casos de VENCIMIENTOS (VTO-01 a VTO-12), que ademas corren el
rem  batch de cierre (BATCH-CIERRE.exe).
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
rem  si en el futuro gestion-bancaria.cbl cambia a proposito (por ejemplo, se
rem  redacta distinto un mensaje), hay que regenerar el esperado_*.txt
rem  correspondiente a mano una vez, revisando que el nuevo texto sea
rem  correcto, y no automaticamente.
rem
rem  Por que hace falta este script y no alcanza con escribir
rem  "gestion-bancaria.exe < entrada.txt > salida.txt" a mano: si la terminal
rem  donde se corre ese comando no tiene el runtime de GnuCOBOL
rem  (libcob y sus DLL) en el PATH, gestion-bancaria.exe falla al arrancar
rem  (Windows STATUS_DLL_NOT_FOUND) SIN mostrar ningun mensaje de
rem  error visible, y el archivo de salida queda en 0 bytes, porque
rem  cmd ya lo habia creado (vacio) por la redireccion antes de que
rem  el programa fallara. Ver README.md, seccion "Solucion de
rem  problemas", para el detalle.
rem
rem  IMPORTANTE: el .exe se compila DENTRO de bin\ y se ejecuta ahi
rem  mismo, para que los clientes de prueba (DNI 800000XX) queden
rem  en bin\clientes_v3.dat, el MISMO archivo que usan gestion-bancaria.exe,
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

echo [pruebas] Compilando gestion-bancaria.cbl en bin\ ...
cobc -x -Wall -o "bin\gestion-bancaria.exe" gestion-bancaria.cbl
if errorlevel 1 (
    echo [pruebas] ERROR: fallo la compilacion. Revise los mensajes
    echo [pruebas] de cobc arriba.
    echo ERROR: fallo la compilacion de gestion-bancaria.cbl. >> "%LOGFILE%"
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

    ".\gestion-bancaria.exe" < "..\entrada_%%C.txt" > "..\salida_%%C.txt"

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

rem -----------------------------------------------------------------
rem  Segunda parte: casos de la Evolucion 1 / Etapa 1 (MENU-01 e
rem  INT-01 a INT-11 de CASOS_DE_PRUEBA.md). Misma logica que
rem  correr_pruebas_intereses.sh (Linux / Docker / CI):
rem   - cada caso corre en bin\prueba_int\, una carpeta que se borra y
rem     se vuelve a crear, asi arranca con un intereses.dat vacio sin
rem     tocar nunca el bin\intereses.dat de verdad;
rem   - cada paso (entrada_<caso>_1.txt, _2.txt...) es una ejecucion
rem     con su propia fecha de proceso fija (FECHA_PROCESO); las
rem     salidas de todos los pasos se juntan en salida_<caso>.txt.
rem  Fechas de octubre de 2026: 14 = miercoles, 15 = jueves,
rem  16 = viernes, 17 = sabado, 18 = domingo, 19 = lunes.
rem -----------------------------------------------------------------
echo.
echo [pruebas] Corriendo y verificando los casos de INTERESES ...
echo.

set /a OK_INT=0
set /a FALLO_INT=0
set /a TOTAL_INT=0

call :caso_int menu01 20261014
call :caso_int int01  20261019
call :caso_int int02  20261014
call :caso_int int03  20261014
call :caso_int int04  20261014 20261016
call :caso_int int05  20261014
call :caso_int int06  20261014
call :caso_int int07  20261016
call :caso_int int08  20261017 20261018
call :caso_int int09  20261014 20261015
call :caso_int int10  20261014 20261015
call :caso_int int11  20261014

echo.
echo [pruebas] ==========================================
echo [pruebas]  Resumen intereses: !OK_INT! OK / !FALLO_INT! FALLO ^(de !TOTAL_INT!^)
echo [pruebas] ==========================================

echo. >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"
echo  Resumen intereses: !OK_INT! OK / !FALLO_INT! FALLO (de !TOTAL_INT!) >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"

rem -----------------------------------------------------------------
rem  Tercera parte: casos de la Evolucion 1 / Etapa 2 (PF-01 a PF-17
rem  de CASOS_DE_PRUEBA.md). Misma logica que la segunda parte y que
rem  correr_pruebas_plazofijo.sh (Linux / Docker / CI), pero en la
rem  carpeta descartable bin\prueba_pf\: cada caso arranca con
rem  clientes_v3.dat, intereses.dat y plazofijo.dat vacios. En
rem  general el paso 1 (miercoles 14/10) da de alta el cliente y la
rem  tasa, y el paso 2 (jueves 15/10, cuando la tasa ya rige) opera
rem  con el plazo fijo. 14/11/2026 = vencimiento de un plazo fijo a
rem  30 dias constituido el 15/10/2026.
rem -----------------------------------------------------------------
echo.
echo [pruebas] Corriendo y verificando los casos de PLAZO FIJO ...
echo.

set /a OK_PF=0
set /a FALLO_PF=0
set /a TOTAL_PF=0

call :caso_pf pf01 20261014 20261015
call :caso_pf pf02 20261014 20261015
call :caso_pf pf03 20261015
call :caso_pf pf04 20261014 20261015
call :caso_pf pf05 20261014 20261015
call :caso_pf pf06 20261014 20261015
call :caso_pf pf07 20261014 20261015
call :caso_pf pf08 20261014 20261015
call :caso_pf pf09 20261015
call :caso_pf pf10 20261014 20261015
call :caso_pf pf11 20261014 20261015
call :caso_pf pf12 20261014 20261015
call :caso_pf pf13 20261014 20261015
call :caso_pf pf14 20261014 20261015 20261016
call :caso_pf pf15 20261014 20261015
call :caso_pf pf16 20261014 20261015
call :caso_pf pf17 20261014 20261015 20261114

echo.
echo [pruebas] ==========================================
echo [pruebas]  Resumen plazo fijo: !OK_PF! OK / !FALLO_PF! FALLO ^(de !TOTAL_PF!^)
echo [pruebas] ==========================================

echo. >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"
echo  Resumen plazo fijo: !OK_PF! OK / !FALLO_PF! FALLO (de !TOTAL_PF!) >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"

rem -----------------------------------------------------------------
rem  Cuarta parte: casos de la Evolucion 1 / Etapa 3 (VTO-01 a VTO-12
rem  de CASOS_DE_PRUEBA.md: vencimientos de plazo fijo en el batch de
rem  cierre). Misma logica que correr_pruebas_vencimientos.sh (Linux
rem  / Docker / CI), en la carpeta descartable bin\prueba_vto\. La
rem  diferencia con la tercera parte es que un caso mezcla corridas
rem  de los dos programas. Cada paso de la lista es una fecha:
rem    AAAAMMDD    corre gestion-bancaria.exe con la siguiente
rem                entrada del caso (entrada_<caso>_1.txt, _2.txt...).
rem    B:AAAAMMDD  corre BATCH-CIERRE.exe con esa fecha y agrega a la
rem                salida su codigo de salida y el reporte_cierre.txt
rem                que genero (antes se borra el anterior).
rem  14/10 = miercoles, 15/10 = jueves (alta del plazo fijo a 30
rem  dias), 13/11 = viernes, 14/11 = sabado (vencimiento),
rem  16/11 = lunes.
rem -----------------------------------------------------------------
echo.
echo [pruebas] Compilando BATCH-CIERRE.cbl en bin\ ...
cobc -x -Wall -o "bin\BATCH-CIERRE.exe" BATCH-CIERRE.cbl
if errorlevel 1 (
    echo [pruebas] ERROR: fallo la compilacion de BATCH-CIERRE.cbl.
    echo ERROR: fallo la compilacion de BATCH-CIERRE.cbl. >> "%LOGFILE%"
    exit /b 1
)
echo [pruebas] Corriendo y verificando los casos de VENCIMIENTOS ...
echo.

set /a OK_VTO=0
set /a FALLO_VTO=0
set /a TOTAL_VTO=0

call :caso_vto vto01 20261014 20261015 B:20261114 20261114
call :caso_vto vto02 20261014 20261015 B:20261113 20261113
call :caso_vto vto03 20261014 20261015 B:20261116 20261116
call :caso_vto vto04 20261014 20261015 B:20261114 20261114
call :caso_vto vto05 20261014 20261015 B:20261114 B:20261114 20261114
call :caso_vto vto06 20261014 20261015 B:20261114 20261114
call :caso_vto vto07 20261014 20261015 B:20261114 20261116 B:20261116 20261116
call :caso_vto vto08 20261014 20261015 B:20261114 20261114
call :caso_vto vto09 B:20261114
call :caso_vto vto10 20261014 20261015 B:20261114 20261114
call :caso_vto vto11 20261014 20261015 B:2026111 20261114
call :caso_vto vto12 20261014 20261015 B:20261114 20261114

echo.
echo [pruebas] ==========================================
echo [pruebas]  Resumen vencimientos: !OK_VTO! OK / !FALLO_VTO! FALLO ^(de !TOTAL_VTO!^)
echo [pruebas] ==========================================

echo. >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"
echo  Resumen vencimientos: !OK_VTO! OK / !FALLO_VTO! FALLO (de !TOTAL_VTO!) >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"

set /a FALLO+=FALLO_INT
set /a FALLO+=FALLO_PF
set /a FALLO+=FALLO_VTO

if !FALLO! GTR 0 (
    echo.
    echo [pruebas] Casos que fallaron:!CASOS_FALLIDOS!
    echo [pruebas] Para ver la diferencia exacta de un caso, corra
    echo [pruebas] por ejemplo:
    echo [pruebas]   fc esperado_alta_ok.txt salida_alta_ok.txt
    echo.
    echo [pruebas] Si el cambio de salida es esperado ^(por ejemplo,
    echo [pruebas] se modifico a proposito un mensaje de gestion-bancaria.cbl^),
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
echo [pruebas] Todos los casos automatizados pasaron.
echo Todos los casos automatizados pasaron. >> "%LOGFILE%"
echo.
echo [pruebas] Resultado guardado en resultado_pruebas.txt
endlocal
exit /b 0

rem =================================================================
rem  :caso_int <caso> <fecha paso 1> [<fecha paso 2> ...]
rem  Corre un caso de INTERESES (ver la segunda parte, arriba).
rem =================================================================
:caso_int
set "CASO=%~1"
shift
if exist "bin\prueba_int" rmdir /s /q "bin\prueba_int"
mkdir "bin\prueba_int"
type nul > "salida_%CASO%.txt"
set /a PASO=1
:caso_int_paso
if "%~1"=="" goto caso_int_comparar
if not exist "entrada_%CASO%_!PASO!.txt" (
    echo [pruebas] ERROR: no se encuentra entrada_%CASO%_!PASO!.txt
    echo ERROR: no se encuentra entrada_%CASO%_!PASO!.txt >> "%LOGFILE%"
    goto caso_int_comparar
)
set "FECHA_PROCESO=%~1"
pushd "bin\prueba_int"
"..\gestion-bancaria.exe" < "..\..\entrada_%CASO%_!PASO!.txt" >> "..\..\salida_%CASO%.txt"
popd
set "FECHA_PROCESO="
set /a PASO+=1
shift
goto caso_int_paso
:caso_int_comparar
rmdir /s /q "bin\prueba_int"
set /a TOTAL_INT+=1
fc "esperado_%CASO%.txt" "salida_%CASO%.txt" >nul
if errorlevel 1 (
    echo [pruebas]   FALLO  - %CASO%
    echo   FALLO  - %CASO% >> "%LOGFILE%"
    set /a FALLO_INT+=1
    set "CASOS_FALLIDOS=!CASOS_FALLIDOS! %CASO%"
) else (
    echo [pruebas]   OK     - %CASO%
    echo   OK     - %CASO% >> "%LOGFILE%"
    set /a OK_INT+=1
)
goto :eof

rem =================================================================
rem  :caso_pf <caso> <fecha paso 1> [<fecha paso 2> ...]
rem  Corre un caso de PLAZO FIJO (ver la tercera parte, arriba).
rem  Es igual a :caso_int, pero en bin\prueba_pf\ y con sus propios
rem  contadores.
rem =================================================================
:caso_pf
set "CASO=%~1"
shift
if exist "bin\prueba_pf" rmdir /s /q "bin\prueba_pf"
mkdir "bin\prueba_pf"
type nul > "salida_%CASO%.txt"
set /a PASO=1
:caso_pf_paso
if "%~1"=="" goto caso_pf_comparar
if not exist "entrada_%CASO%_!PASO!.txt" (
    echo [pruebas] ERROR: no se encuentra entrada_%CASO%_!PASO!.txt
    echo ERROR: no se encuentra entrada_%CASO%_!PASO!.txt >> "%LOGFILE%"
    goto caso_pf_comparar
)
set "FECHA_PROCESO=%~1"
pushd "bin\prueba_pf"
"..\gestion-bancaria.exe" < "..\..\entrada_%CASO%_!PASO!.txt" >> "..\..\salida_%CASO%.txt"
popd
set "FECHA_PROCESO="
set /a PASO+=1
shift
goto caso_pf_paso
:caso_pf_comparar
rmdir /s /q "bin\prueba_pf"
set /a TOTAL_PF+=1
fc "esperado_%CASO%.txt" "salida_%CASO%.txt" >nul
if errorlevel 1 (
    echo [pruebas]   FALLO  - %CASO%
    echo   FALLO  - %CASO% >> "%LOGFILE%"
    set /a FALLO_PF+=1
    set "CASOS_FALLIDOS=!CASOS_FALLIDOS! %CASO%"
) else (
    echo [pruebas]   OK     - %CASO%
    echo   OK     - %CASO% >> "%LOGFILE%"
    set /a OK_PF+=1
)
goto :eof

rem =================================================================
rem  :caso_vto <caso> <paso 1> [<paso 2> ...]
rem  Corre un caso de VENCIMIENTOS (ver la cuarta parte, arriba).
rem  Los pasos AAAAMMDD son como en :caso_pf; los pasos B:AAAAMMDD
rem  corren el batch de cierre. Las lineas "-----" que se agregan a
rem  la salida son las mismas que escribe
rem  correr_pruebas_vencimientos.sh, asi un mismo esperado_*.txt
rem  sirve en Windows y en Linux.
rem =================================================================
:caso_vto
set "CASO=%~1"
shift
if exist "bin\prueba_vto" rmdir /s /q "bin\prueba_vto"
mkdir "bin\prueba_vto"
type nul > "salida_%CASO%.txt"
set /a PASO=1
:caso_vto_paso
if "%~1"=="" goto caso_vto_comparar
set "ARG=%~1"
if /i "%ARG:~0,2%"=="B:" goto caso_vto_batch
if not exist "entrada_%CASO%_!PASO!.txt" (
    echo [pruebas] ERROR: no se encuentra entrada_%CASO%_!PASO!.txt
    echo ERROR: no se encuentra entrada_%CASO%_!PASO!.txt >> "%LOGFILE%"
    goto caso_vto_comparar
)
set "FECHA_PROCESO=%~1"
pushd "bin\prueba_vto"
"..\gestion-bancaria.exe" < "..\..\entrada_%CASO%_!PASO!.txt" >> "..\..\salida_%CASO%.txt"
popd
set "FECHA_PROCESO="
set /a PASO+=1
shift
goto caso_vto_paso
:caso_vto_batch
if exist "bin\prueba_vto\reporte_cierre.txt" del /q "bin\prueba_vto\reporte_cierre.txt"
set "FECHA_PROCESO=%ARG:~2%"
pushd "bin\prueba_vto"
"..\BATCH-CIERRE.exe" < nul >> "..\..\salida_%CASO%.txt"
set "RC=%ERRORLEVEL%"
popd
set "FECHA_PROCESO="
>>"salida_%CASO%.txt" echo ----- codigo de salida del batch: %RC%
if exist "bin\prueba_vto\reporte_cierre.txt" (
    >>"salida_%CASO%.txt" echo ----- reporte_cierre.txt
    type "bin\prueba_vto\reporte_cierre.txt" >> "salida_%CASO%.txt"
    >>"salida_%CASO%.txt" echo ----- fin de reporte_cierre.txt
) else (
    >>"salida_%CASO%.txt" echo ----- no se genero reporte_cierre.txt
)
shift
goto caso_vto_paso
:caso_vto_comparar
rmdir /s /q "bin\prueba_vto"
set /a TOTAL_VTO+=1
fc "esperado_%CASO%.txt" "salida_%CASO%.txt" >nul
if errorlevel 1 (
    echo [pruebas]   FALLO  - %CASO%
    echo   FALLO  - %CASO% >> "%LOGFILE%"
    set /a FALLO_VTO+=1
    set "CASOS_FALLIDOS=!CASOS_FALLIDOS! %CASO%"
) else (
    echo [pruebas]   OK     - %CASO%
    echo   OK     - %CASO% >> "%LOGFILE%"
    set /a OK_VTO+=1
)
goto :eof
