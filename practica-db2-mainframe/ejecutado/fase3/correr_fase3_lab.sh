#!/bin/bash
# =================================================================
#  correr_fase3_lab.sh
#
#  Compila y corre los programas de la Fase 3 (descarga a archivos
#  planos + listados) sobre los archivos que dejo CARGA-MASIVA.
#
#  Uso (dentro del contenedor, parado en la carpeta de trabajo que
#  tiene los .dat y los reportes de la carga, por ejemplo /app/lab):
#     bash correr_fase3_lab.sh
#  Variables opcionales:
#     FUENTES=carpeta con los .cbl nuevos   (por defecto: la de este script)
#     COPYDIR=carpeta con los .cpy          (por defecto: /app)
#     FECHA_PROCESO=AAAAMMDD                (por defecto: la de hoy)
#     ARCHIVO_CARGA=archivo de carga original (por defecto: carga_lab.original.txt)
#
#  Orden: tasas, clientes, plazos fijos (el mismo orden en que despues
#  se importan a Db2, porque los plazos fijos dependen de los otros
#  dos) y al final el listado detallado de rechazos. Si un paso
#  termina con codigo distinto de 0 se corta ahi.
# =================================================================

FUENTES=${FUENTES:-$(cd "$(dirname "$0")" && pwd)}
COPYDIR=${COPYDIR:-/app}
export FECHA_PROCESO=${FECHA_PROCESO:-$(date +%Y%m%d)}
export ARCHIVO_CARGA=${ARCHIVO_CARGA:-carga_lab.original.txt}

echo "=== Compilando ==="
for P in DESCARGA-INTERESES DESCARGA-CLIENTES DESCARGA-PLAZOS LISTADO-RECHAZOS; do
    cobc -x -Wall -I "$COPYDIR" -o "$P.exe" "$FUENTES/$P.cbl" || {
        echo "ERROR: fallo la compilacion de $P.cbl"; exit 8; }
    echo "  $P.exe OK"
done

for P in DESCARGA-INTERESES DESCARGA-CLIENTES DESCARGA-PLAZOS LISTADO-RECHAZOS; do
    echo
    echo "=== $P ==="
    ./"$P.exe"
    RC=$?
    echo "--- codigo de retorno de $P: $RC"
    if [ "$RC" -ne 0 ]; then
        echo "Se corta aca: $P termino con error."
        exit "$RC"
    fi
done

echo
echo "=== Archivos generados ==="
ls -l intereses.txt clientes.txt plazosfijos.txt listado_*.txt
echo
echo "=== Largos de los archivos planos (cantidad de registros x largo) ==="
for A in intereses.txt clientes.txt plazosfijos.txt; do
    printf '%-18s' "$A"
    awk '{print length($0)}' "$A" | sort -n | uniq -c | tr '\n' ' '
    echo
done
