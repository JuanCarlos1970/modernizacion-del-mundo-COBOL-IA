#!/bin/bash
# =================================================================
#  generar_carga_cm01.sh
#
#  Vuelve a generar carga_cm01_1.txt, el archivo de carga de 68
#  lineas del caso CM-01 (carga masiva, ver CASOS_DE_PRUEBA.md).
#
#  Por que existe: casi todas las lineas tienen que medir
#  EXACTAMENTE 100 caracteres, con espacios al final, y algunas
#  estan recortadas a proposito (92, 85, 26, 18) o son largas
#  (105). Si un editor recorta los espacios finales al guardar, el
#  caso CM-01 deja de dar lo esperado. Con este script el archivo
#  se arma siempre igual: printf rellena cada campo con espacios
#  hasta su largo fijo.
#
#  Uso (desde la carpeta del proyecto):  bash generar_carga_cm01.sh
#  En Docker:  docker run --rm gestion-bancaria bash generar_carga_cm01.sh
#  Para controlar los largos:  awk '{print NR": "length($0)}' carga_cm01_1.txt
# =================================================================

cd "$(dirname "$0")" || exit 1

# Una linea de cada tipo, con los campos en sus posiciones fijas:
#   C: DNI(8) NOMBRE(30) DIRECCION(40) TELEFONO(15) relleno(6)
#   I: MONEDA(1) DIAS(3) TNA(5) VIGENTE-DESDE(8) relleno(82)
#   P: DNI(8) MONEDA(1) MONTO(13) DIAS(3) relleno(74)
c()  { printf 'C%-8s%-30s%-40s%-15s%6s\n' "$1" "$2" "$3" "$4" ""; }
i()  { printf 'I%s%s%s%s%82s\n' "$1" "$2" "$3" "$4" ""; }
p()  { printf 'P%s%s%s%s%74s\n' "$1" "$2" "$3" "$4" ""; }
rec() { sed 's/ *$//'; }   # recorta los espacios finales
{
c 80000303 "Ana Carga"      "Calle Carga 303"    "011 4300-0303"
c 80000304 "Bruno Carga"    "Calle Carga 304"    "011 4300-0304"
c 80000305 "Carla Carga"    "Calle Carga 305"    "+54(11)4300-055"
c 80000306 "Diego Carga"    "   Calle Carga 306" "011 4300-0306"
c 80000307 "Elena Carga"    "Calle Carga 307"    "011 4300-0307" | rec
c 80000308 "Fabio Carga"    "Calle Carga 308"    "011430"        | rec
c 80000309 "Gina Carga"     "Calle Carga 309"    "011 4300-0309"
c 80000310 "Hugo Carga"     "Calle Carga 310"    "011 4300-0310"
c 80000311 "Ines Carga"     "Calle Carga 311"    "011 4300-0311"
c 80000301 "Pedro Repetido" "Calle Repetida 301" "011 4300-0391"
c 80000303 "Ana Repetida"   "Calle Repetida 303" "011 4300-0393"
c 80000312 ""               "Calle Carga 312"    "011 4300-0312"
c 80000313 "  Carlos Corrido" "Calle Carga 313"  "011 4300-0313"
c 80000314 "Laura Sin Calle" ""                  "011 4300-0314"
c 80000315 "Mario Sin Tel"  "Calle Carga 315"    ""
c 80000316 "Nora Tel Malo"  "Calle Carga 316"    "011-4300-ABCD"
echo
i P 060 04500 20261001
i P 090 05000 20261015
i P 120 05500 20261020
i d 060 00350 20261001
i D 090 00400 20261014 | rec
i P 030 04200 20261015
i D 030 00300 20261015
i X 060 04500 20261015
i P 045 04500 20261015
i D 120 00000 20261015
i D 120 00300 20261131
printf 'X%99s\n' ""
p 80000303 P 0000100000000 030
p 80000303 P 0000250000000 060
p 80000304 P 0000150000000 090
p 80000304 D 0000000050000 060
p 80000305 D 0000000100000 090
p 80000305 p 0000120000000 030
p 80000306 P 0000300000000 030
p 80000306 D 0000000075050 060
p 80000307 P 0000100000001 090
p 80000307 D 0000000200000 090
p 80000308 P 0000500000000 060
p 80000308 P 0000100000000 030 | rec
p 80000309 P 0001000000000 090
p 80000309 D 0000001000000 060
p 80000310 P 0000175000000 030
p 80000310 D 0000000060000 090
p 80000311 P 0000200000000 060
p 80000311 D 0000000080000 060
p 80000301 P 0000100000000 030
p 80000303 D 0000000500000 090
p 80000304 P 0000400000000 090
p 8000031X P 0000100000000 030
p 80000399 P 0000100000000 030
p 80000302 P 0000100000000 030
p 80000303 X 0000100000000 030
p 80000303 P 00001000000AB 030
p 80000303 P 0000099999999 030
p 80000303 P 0000100000000 045
p 80000303 P 0000100000000 120
p 80000303 P 9999999900000 090
printf 'P80000304P0000100000000030%74sEXTRA\n' ""
c 8000031A "Oscar DNI Malo" "Calle Carga 319"    "011 4300-0319"
c 80000317 "Paula Tel Corto" "Calle Carga 317"   "12-345"
printf 'C%-8s%-30s%s\n' 80000318 "Quique Corto" "Calle Corta 318"
i D 120 0A300 20261015
i P 060 04800 20261015
p 80000303 D 0000000049999 060
p 80000303 D 0000000100000 030
p 80000303 D 0000000100000 120
} > carga_cm01_1.txt
