#!/bin/bash
# =================================================================
#  correr_pruebas_vencimientos.sh  (Linux: Docker y GitHub Actions)
#
#  Corre los casos automatizados de la Evolucion 1 / Etapa 3
#  (VTO-01 a VTO-12 de CASOS_DE_PRUEBA.md: vencimientos de plazo
#  fijo en el batch de cierre) y compara cada salida contra su
#  esperado_*.txt. Es el equivalente en Linux de la cuarta parte
#  de correr_pruebas_automatizadas.bat.
#
#  Funciona igual que correr_pruebas_plazofijo.sh, con una
#  diferencia: un caso mezcla corridas de los DOS programas.
#   - Se borra y se vuelve a crear la carpeta bin/prueba_vto/, y
#     los programas se ejecutan DESDE AHI. Asi cada caso arranca
#     sin archivos, sin tocar nunca los .dat de bin/.
#   - Cada paso de la lista es una fecha de proceso:
#       AAAAMMDD    corre gestion-bancaria.exe con la siguiente
#                   entrada del caso (entrada_<caso>_1.txt, _2.txt,
#                   ...; se numeran solo estos pasos).
#       B:AAAAMMDD  corre BATCH-CIERRE.exe con esa fecha. Antes se
#                   borra reporte_cierre.txt, y despues se agregan a
#                   la salida el codigo de salida del batch y el
#                   reporte que genero (o un aviso si no genero
#                   ninguno). Asi el esperado verifica tambien el
#                   reporte.
#     Todos los pasos trabajan sobre los MISMOS archivos, y sus
#     salidas se juntan en salida_<caso>.txt.
#   - "timeout 10": si una entrada quedara incompleta, el programa
#     se quedaria esperando datos para siempre; asi se corta.
#   - "tr -d '\r'" y "diff --strip-trailing-cr": en Windows (con
#     core.autocrlf=true) los .txt tienen fin de linea CRLF; en
#     Linux el \r se leeria como parte de lo tipeado. Se quita al
#     vuelo, sin modificar los archivos.
#
#  Uso (desde la carpeta del proyecto):  bash correr_pruebas_vencimientos.sh
#  En Docker:  docker run --rm gestion-bancaria bash correr_pruebas_vencimientos.sh
# =================================================================

cd "$(dirname "$0")" || exit 1

mkdir -p bin
cobc -x -Wall -o bin/gestion-bancaria.exe gestion-bancaria.cbl || {
    echo "ERROR: fallo la compilacion de gestion-bancaria.cbl"
    exit 1
}
cobc -x -Wall -o bin/BATCH-CIERRE.exe BATCH-CIERRE.cbl || {
    echo "ERROR: fallo la compilacion de BATCH-CIERRE.cbl"
    exit 1
}

OK=0
FALLO=0
TOTAL=0

# correr_caso <caso> <paso 1> [<paso 2> ...]   (ver arriba)
correr_caso() {
    local CASO=$1
    shift
    rm -rf bin/prueba_vto
    mkdir -p bin/prueba_vto
    : > "salida_${CASO}.txt"
    local PASO=1
    local RC
    for P in "$@"; do
        if [ "${P:0:2}" = "B:" ]; then
            rm -f bin/prueba_vto/reporte_cierre.txt
            ( cd bin/prueba_vto &&
              FECHA_PROCESO=${P:2} timeout 10 ../BATCH-CIERRE.exe < /dev/null
            ) >> "salida_${CASO}.txt"
            RC=$?
            echo "----- codigo de salida del batch: ${RC}" >> "salida_${CASO}.txt"
            if [ -f bin/prueba_vto/reporte_cierre.txt ]; then
                echo "----- reporte_cierre.txt" >> "salida_${CASO}.txt"
                tr -d '\r' < bin/prueba_vto/reporte_cierre.txt >> "salida_${CASO}.txt"
                echo "----- fin de reporte_cierre.txt" >> "salida_${CASO}.txt"
            else
                echo "----- no se genero reporte_cierre.txt" >> "salida_${CASO}.txt"
            fi
        else
            ( cd bin/prueba_vto &&
              tr -d '\r' < "../../entrada_${CASO}_${PASO}.txt" |
              FECHA_PROCESO=$P timeout 10 ../gestion-bancaria.exe
            ) >> "salida_${CASO}.txt"
            PASO=$((PASO+1))
        fi
    done
    rm -rf bin/prueba_vto
    TOTAL=$((TOTAL+1))
    if diff -q --strip-trailing-cr "esperado_${CASO}.txt" "salida_${CASO}.txt" > /dev/null; then
        echo "OK     - ${CASO}"
        OK=$((OK+1))
    else
        echo "FALLO  - ${CASO}"
        echo "----- diff esperado vs salida (${CASO}) -----"
        diff --strip-trailing-cr "esperado_${CASO}.txt" "salida_${CASO}.txt"
        FALLO=$((FALLO+1))
    fi
}

# Fechas: 14/10/2026 = miercoles (alta de cliente y tasa),
# 15/10/2026 = jueves (alta del plazo fijo a 30 dias),
# 13/11/2026 = viernes (un dia antes del vencimiento),
# 14/11/2026 = sabado (vencimiento), 16/11/2026 = lunes.
correr_caso vto01 20261014 20261015 B:20261114 20261114
correr_caso vto02 20261014 20261015 B:20261113 20261113
correr_caso vto03 20261014 20261015 B:20261116 20261116
correr_caso vto04 20261014 20261015 B:20261114 20261114
correr_caso vto05 20261014 20261015 B:20261114 B:20261114 20261114
correr_caso vto06 20261014 20261015 B:20261114 20261114
correr_caso vto07 20261014 20261015 B:20261114 20261116 B:20261116 20261116
correr_caso vto08 20261014 20261015 B:20261114 20261114
correr_caso vto09 B:20261114
correr_caso vto10 20261014 20261015 B:20261114 20261114
correr_caso vto11 20261014 20261015 B:2026111 20261114
correr_caso vto12 20261014 20261015 B:20261114 20261114

echo "=========================================="
echo " Resumen vencimientos: ${OK} OK / ${FALLO} FALLO (de ${TOTAL})"
echo "=========================================="
[ "$FALLO" -eq 0 ]
