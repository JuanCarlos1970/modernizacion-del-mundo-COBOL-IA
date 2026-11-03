#!/bin/bash
# =================================================================
#  correr_pruebas_clientes.sh  (Linux: Docker y GitHub Actions)
#
#  Corre los 5 casos automatizados de clientes (CP-01 a CP-04 y
#  CP-06 de CASOS_DE_PRUEBA.md) y compara cada salida contra su
#  esperado_*.txt. Es el equivalente en Linux de la primera parte
#  de correr_pruebas_automatizadas.bat.
#
#  Funciona igual que correr_pruebas_intereses.sh:
#   - Se borra y se vuelve a crear la carpeta bin/prueba_cli/, y el
#     programa se ejecuta DESDE AHI. Asi cada caso arranca con un
#     clientes_v3.dat vacio, sin tocar nunca el bin/clientes_v3.dat
#     de verdad, y el script se puede correr dos veces seguidas sin
#     que la segunda falle por "Ya existe un cliente con ese DNI".
#   - Cada caso es una sola ejecucion (entrada_<caso>.txt), sin
#     FECHA_PROCESO: usa la fecha del sistema, como siempre.
#   - "timeout 10": si una entrada quedara incompleta, el programa
#     se quedaria esperando datos para siempre; asi se corta.
#   - "tr -d '\r'" y "diff --strip-trailing-cr": en Windows (con
#     core.autocrlf=true) los .txt tienen fin de linea CRLF; en
#     Linux el \r se leeria como parte de lo tipeado. Se quita al
#     vuelo, sin modificar los archivos.
#
#  Uso (desde la carpeta del proyecto):  bash correr_pruebas_clientes.sh
#  En Docker:  docker run --rm gestion-bancaria bash correr_pruebas_clientes.sh
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

# correr_caso <caso>
correr_caso() {
    local CASO=$1
    rm -rf bin/prueba_cli
    mkdir -p bin/prueba_cli
    ( cd bin/prueba_cli &&
      tr -d '\r' < "../../entrada_${CASO}.txt" |
      timeout 10 ../gestion-bancaria.exe
    ) > "salida_${CASO}.txt"
    rm -rf bin/prueba_cli
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

correr_caso alta_ok
correr_caso alta_dni_invalido
correr_caso deposito
correr_caso extraccion
correr_caso consulta

echo "=========================================="
echo " Resumen: ${OK} OK / ${FALLO} FALLO (de ${TOTAL})"
echo "=========================================="
[ "$FALLO" -eq 0 ]
