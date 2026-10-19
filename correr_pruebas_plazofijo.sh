#!/bin/bash
# =================================================================
#  correr_pruebas_plazofijo.sh  (Linux: Docker y GitHub Actions)
#
#  Corre los casos automatizados de la Evolucion 1 / Etapa 2
#  (PF-01 a PF-17 de CASOS_DE_PRUEBA.md) y compara cada salida
#  contra su esperado_*.txt. Es el equivalente en Linux de la
#  tercera parte de correr_pruebas_automatizadas.bat.
#
#  Funciona igual que correr_pruebas_intereses.sh:
#   - Se borra y se vuelve a crear la carpeta bin/prueba_pf/, y el
#     programa se ejecuta DESDE AHI. Asi cada caso arranca con
#     clientes_v3.dat, intereses.dat y plazofijo.dat vacios, sin
#     tocar nunca los de bin/.
#   - Un caso puede tener varios pasos: entrada_<caso>_1.txt,
#     entrada_<caso>_2.txt, ... Cada paso es una ejecucion del
#     programa con su propia fecha de proceso fija (FECHA_PROCESO),
#     sobre los MISMOS archivos. En general el paso 1 (miercoles)
#     da de alta el cliente y la tasa, y el paso 2 (jueves, cuando
#     la tasa ya rige) opera con el plazo fijo. Las salidas de todos
#     los pasos se juntan en salida_<caso>.txt.
#   - "timeout 10": si una entrada quedara incompleta, el programa
#     se quedaria esperando datos para siempre; asi se corta.
#   - "tr -d '\r'" y "diff --strip-trailing-cr": en Windows (con
#     core.autocrlf=true) los .txt tienen fin de linea CRLF; en
#     Linux el \r se leeria como parte de lo tipeado. Se quita al
#     vuelo, sin modificar los archivos.
#
#  Uso (desde la carpeta del proyecto):  bash correr_pruebas_plazofijo.sh
#  En Docker:  docker run --rm gestion-bancaria bash correr_pruebas_plazofijo.sh
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
    rm -rf bin/prueba_pf
    mkdir -p bin/prueba_pf
    : > "salida_${CASO}.txt"
    local PASO=1
    for FECHA in "$@"; do
        ( cd bin/prueba_pf &&
          tr -d '\r' < "../../entrada_${CASO}_${PASO}.txt" |
          FECHA_PROCESO=$FECHA timeout 10 ../gestion-bancaria.exe
        ) >> "salida_${CASO}.txt"
        PASO=$((PASO+1))
    done
    rm -rf bin/prueba_pf
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

# Fechas: 14/10/2026 = miercoles, 15/10/2026 = jueves,
# 16/10/2026 = viernes, 14/11/2026 = vencimiento de un plazo fijo
# a 30 dias constituido el 15/10/2026.
correr_caso pf01 20261014 20261015
correr_caso pf02 20261014 20261015
correr_caso pf03 20261015
correr_caso pf04 20261014 20261015
correr_caso pf05 20261014 20261015
correr_caso pf06 20261014 20261015
correr_caso pf07 20261014 20261015
correr_caso pf08 20261014 20261015
correr_caso pf09 20261015
correr_caso pf10 20261014 20261015
correr_caso pf11 20261014 20261015
correr_caso pf12 20261014 20261015
correr_caso pf13 20261014 20261015
correr_caso pf14 20261014 20261015 20261016
correr_caso pf15 20261014 20261015
correr_caso pf16 20261014 20261015
correr_caso pf17 20261014 20261015 20261114

echo "=========================================="
echo " Resumen plazo fijo: ${OK} OK / ${FALLO} FALLO (de ${TOTAL})"
echo "=========================================="
[ "$FALLO" -eq 0 ]
