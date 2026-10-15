#!/bin/bash
# =================================================================
#  correr_pruebas_intereses.sh  (Linux: Docker y GitHub Actions)
#
#  Corre los casos automatizados de la Evolucion 1 / Etapa 1
#  (MENU-01 e INT-01 a INT-11 de CASOS_DE_PRUEBA.md) y compara cada
#  salida contra su esperado_*.txt. Es el equivalente en Linux de
#  la segunda parte de correr_pruebas_automatizadas.bat.
#
#  Como funciona cada caso:
#   - Se borra y se vuelve a crear la carpeta bin/prueba_int/, y el
#     programa se ejecuta DESDE AHI. Asi cada caso arranca con un
#     intereses.dat vacio, sin tocar nunca el bin/intereses.dat (ni
#     el bin/clientes_v3.dat) de verdad.
#   - Un caso puede tener varios pasos: entrada_<caso>_1.txt,
#     entrada_<caso>_2.txt, ... Cada paso es una ejecucion del
#     programa con su propia fecha de proceso fija (variable de
#     entorno FECHA_PROCESO), sobre el MISMO intereses.dat. Las
#     salidas de todos los pasos se juntan en salida_<caso>.txt.
#   - "timeout 10": si una entrada quedara incompleta, el programa
#     se quedaria esperando datos para siempre; asi se corta.
#   - "tr -d '\r'" y "diff --strip-trailing-cr": en Windows (con
#     core.autocrlf=true) los .txt tienen fin de linea CRLF; en
#     Linux el \r se leeria como parte de lo tipeado. Se quita al
#     vuelo, sin modificar los archivos.
#
#  Uso (desde la carpeta del proyecto):  bash correr_pruebas_intereses.sh
#  En Docker:  docker run --rm gestion-bancaria bash correr_pruebas_intereses.sh
# =================================================================

cd "$(dirname "$0")" || exit 1

mkdir -p bin
cobc -x -Wall -o bin/gestion-bancaria.exe gestion-bancaria.cbl || {
    echo "ERROR: fallo la compilacion de gestion-bancaria.cbl"
    exit 1
}

OK=0
FALLO=0
TOTAL=0

# correr_caso <caso> <fecha paso 1> [<fecha paso 2> ...]
correr_caso() {
    local CASO=$1
    shift
    rm -rf bin/prueba_int
    mkdir -p bin/prueba_int
    : > "salida_${CASO}.txt"
    local PASO=1
    for FECHA in "$@"; do
        ( cd bin/prueba_int &&
          tr -d '\r' < "../../entrada_${CASO}_${PASO}.txt" |
          FECHA_PROCESO=$FECHA timeout 10 ../gestion-bancaria.exe
        ) >> "salida_${CASO}.txt"
        PASO=$((PASO+1))
    done
    rm -rf bin/prueba_int
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

# Fechas de octubre de 2026: 14 = miercoles, 15 = jueves,
# 16 = viernes, 17 = sabado, 18 = domingo, 19 = lunes.
correr_caso menu01 20261014
correr_caso int01  20261019
correr_caso int02  20261014
correr_caso int03  20261014
correr_caso int04  20261014 20261016
correr_caso int05  20261014
correr_caso int06  20261014
correr_caso int07  20261016
correr_caso int08  20261017 20261018
correr_caso int09  20261014 20261015
correr_caso int10  20261014 20261015
correr_caso int11  20261014

echo "=========================================="
echo " Resumen intereses: ${OK} OK / ${FALLO} FALLO (de ${TOTAL})"
echo "=========================================="
[ "$FALLO" -eq 0 ]
