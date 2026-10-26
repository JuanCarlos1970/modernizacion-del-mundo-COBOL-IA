#!/bin/bash
# =================================================================
#  correr_pruebas_carga.sh  (Linux: Docker y GitHub Actions)
#
#  Corre los casos automatizados de la Evolucion 1 / Etapa 4
#  (CM-01 a CM-08 de CASOS_DE_PRUEBA.md: carga masiva con
#  CARGA-MASIVA.exe) y compara cada salida contra su
#  esperado_*.txt. Es el equivalente en Linux de la quinta parte
#  de correr_pruebas_automatizadas.bat.
#
#  Funciona igual que correr_pruebas_vencimientos.sh, pero cada
#  paso dice tambien QUE archivo usa (asi CM-02 y CM-03 reusan la
#  carga de 68 lineas de CM-01 sin duplicarla):
#   - Se borra y se vuelve a crear la carpeta bin/prueba_carga/, y
#     los programas se ejecutan DESDE AHI. Asi cada caso arranca
#     sin archivos, sin tocar nunca los .dat de bin/.
#   - Pasos:
#       G:AAAAMMDD:entrada   corre gestion-bancaria.exe con esa
#                            fecha y esas teclas.
#       C:AAAAMMDD:carga[:nombre]
#                            copia el archivo de carga a la carpeta
#                            (como carga.txt, o como <nombre>, que
#                            se avisa con ARCHIVO_CARGA) y corre
#                            CARGA-MASIVA.exe con esa fecha. Con
#                            "-" en vez de archivo no copia nada
#                            (archivo inexistente / ya procesado).
#     Despues de cada carga se agregan a la salida el codigo de
#     salida, los dos reportes (o un aviso si no se generaron), si
#     el archivo de carga sigue ahi y los archivos .procesado.*.
#   - La hora del renombrado (HHMMSS) cambia en cada corrida: en la
#     salida se reemplaza por "HHMMSS" para que el esperado no
#     cambie.
#   - "timeout 10": si una entrada quedara incompleta, el programa
#     se quedaria esperando datos para siempre; asi se corta.
#   - "tr -d '\r'" y "diff --strip-trailing-cr": en Windows (con
#     core.autocrlf=true) los .txt tienen fin de linea CRLF; en
#     Linux el \r se leeria como parte de lo tipeado. Los archivos
#     de carga se copian tal cual: GnuCOBOL saca el \r solo.
#
#  Uso (desde la carpeta del proyecto):  bash correr_pruebas_carga.sh
#  En Docker:  docker run --rm gestion-bancaria bash correr_pruebas_carga.sh
# =================================================================

cd "$(dirname "$0")" || exit 1

mkdir -p bin
cobc -x -Wall -o bin/gestion-bancaria.exe gestion-bancaria.cbl || {
    echo "ERROR: fallo la compilacion de gestion-bancaria.cbl"
    exit 1
}
cobc -x -Wall -o bin/CARGA-MASIVA.exe CARGA-MASIVA.cbl || {
    echo "ERROR: fallo la compilacion de CARGA-MASIVA.cbl"
    exit 1
}

OK=0
FALLO=0
TOTAL=0
DIR=bin/prueba_carga
PANTALLA=bin/pantalla_carga.tmp

# Reemplaza la hora de un nombre .procesado.AAAAMMDD.HHMMSS
normalizar_hora() {
    sed 's/\(\.procesado\.[0-9]\{8\}\)\.[0-9]\{6\}/\1.HHMMSS/'
}

# correr_carga <salida> <fecha> <archivo de carga o -> [<nombre>]
correr_carga() {
    local SALIDA=$1 FECHA=$2 ARCH=$3 NOMBRE=${4:-carga.txt}
    local RC
    if [ "$ARCH" != "-" ]; then
        cp "$ARCH" "$DIR/$NOMBRE"
    fi
    echo "----- CARGA-MASIVA: FECHA_PROCESO=${FECHA}, archivo ${NOMBRE}" >> "$SALIDA"
    if [ -n "$4" ]; then
        ( cd "$DIR" &&
          ARCHIVO_CARGA=$NOMBRE FECHA_PROCESO=$FECHA timeout 10 ../CARGA-MASIVA.exe < /dev/null
        ) > "$PANTALLA"
    else
        ( cd "$DIR" &&
          FECHA_PROCESO=$FECHA timeout 10 ../CARGA-MASIVA.exe < /dev/null
        ) > "$PANTALLA"
    fi
    RC=$?
    normalizar_hora < "$PANTALLA" >> "$SALIDA"
    rm -f "$PANTALLA"
    echo "----- codigo de salida de la carga: ${RC}" >> "$SALIDA"
    for R in carga_ok.txt carga_rechazos.txt; do
        if [ -f "$DIR/$R" ]; then
            echo "----- $R" >> "$SALIDA"
            tr -d '\r' < "$DIR/$R" >> "$SALIDA"
            echo "----- fin de $R" >> "$SALIDA"
        else
            echo "----- no se genero $R" >> "$SALIDA"
        fi
    done
    if [ -f "$DIR/$NOMBRE" ]; then
        echo "----- ${NOMBRE}: sigue ahi (no se renombro)" >> "$SALIDA"
    else
        echo "----- ${NOMBRE}: no esta" >> "$SALIDA"
    fi
    echo "----- archivos procesados:" >> "$SALIDA"
    ( cd "$DIR" && ls | grep '\.procesado\.' | normalizar_hora ) >> "$SALIDA"
}

# correr_caso <caso> <paso 1> [<paso 2> ...]   (ver arriba)
correr_caso() {
    local CASO=$1
    shift
    rm -rf "$DIR"
    mkdir -p "$DIR"
    : > "salida_${CASO}.txt"
    local P T F A N
    for P in "$@"; do
        IFS=: read -r T F A N <<< "$P"
        if [ "$T" = "G" ]; then
            ( cd "$DIR" &&
              tr -d '\r' < "../../$A" |
              FECHA_PROCESO=$F timeout 10 ../gestion-bancaria.exe
            ) >> "salida_${CASO}.txt"
        else
            correr_carga "salida_${CASO}.txt" "$F" "$A" "$N"
        fi
    done
    rm -rf "$DIR"
    TOTAL=$((TOTAL+1))
    if [ ! -f "esperado_${CASO}.txt" ]; then
        echo "FALLO  - ${CASO} (no existe esperado_${CASO}.txt)"
        FALLO=$((FALLO+1))
    elif diff -q --strip-trailing-cr "esperado_${CASO}.txt" "salida_${CASO}.txt" > /dev/null; then
        echo "OK     - ${CASO}"
        OK=$((OK+1))
    else
        echo "FALLO  - ${CASO}"
        echo "----- diff esperado vs salida (${CASO}) -----"
        diff --strip-trailing-cr "esperado_${CASO}.txt" "salida_${CASO}.txt"
        FALLO=$((FALLO+1))
    fi
}

# Fechas: 14/10/2026 = miercoles (preparacion con gestion-bancaria:
# clientes 80000301 activo y 80000302 inactivo, tasa P/030 activa y
# D/030 de baja), 15/10/2026 = jueves (fecha de la carga).
# 20261315 = fecha invalida (mes 13).
correr_caso cm01 G:20261014:entrada_cm01_1.txt C:20261015:carga_cm01_1.txt
correr_caso cm02 G:20261014:entrada_cm01_1.txt C:20261015:carga_cm01_1.txt G:20261015:entrada_cm02_1.txt
correr_caso cm03 G:20261014:entrada_cm01_1.txt C:20261015:carga_cm01_1.txt G:20261015:entrada_cm03_1.txt
correr_caso cm04 C:20261015:-
correr_caso cm05 C:20261015:carga_cm05_1.txt
correr_caso cm06 C:20261015:carga_cm06_1.txt C:20261315:carga_cm06_1.txt
correr_caso cm07 C:20261015:carga_cm07_1.txt:otra_carga.txt
correr_caso cm08 C:20261015:carga_cm08_1.txt C:20261015:-

echo "=========================================="
echo " Resumen carga masiva: ${OK} OK / ${FALLO} FALLO (de ${TOTAL})"
echo "=========================================="
[ "$FALLO" -eq 0 ]
