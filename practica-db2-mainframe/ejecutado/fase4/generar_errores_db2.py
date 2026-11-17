#!/usr/bin/env python3
# =====================================================================
#  generar_errores_db2.py
#
#  Toma los tres archivos planos que descargo COBOL (intereses.txt,
#  clientes.txt, plazosfijos.txt) y arma tres archivos nuevos con 100
#  registros ERRONEOS mezclados entre los buenos:
#      intereses_db2.txt    5 errores
#      clientes_db2.txt    40 errores
#      plazosfijos_db2.txt 55 errores
#  Cada error rompe UNA regla que Db2 controla (clave primaria,
#  clave foranea, CHECK, dato no numerico, fecha invalida).
#
#  Los originales NO se tocan. Ademas escribe errores_inyectados.txt
#  con archivo, numero de linea y tipo de cada error: es la "clave de
#  respuestas" para comparar contra lo que informe el IMPORT.
#
#  Uso:  python3 generar_errores_db2.py [carpeta_con_los_planos]
#        (por defecto, la carpeta actual)
#  El azar tiene semilla fija: siempre sale el mismo resultado.
# =====================================================================
import os
import random
import sys

random.seed(2026)
CARPETA = sys.argv[1] if len(sys.argv) > 1 else "."


def leer(nombre):
    with open(os.path.join(CARPETA, nombre), encoding="ascii") as f:
        return [linea.rstrip("\n") for linea in f]


def grabar(nombre, lineas):
    with open(os.path.join(CARPETA, nombre), "w", encoding="ascii",
              newline="\n") as f:
        f.write("\n".join(lineas) + "\n")


def mezclar(buenas, cantidad, tipos, fabricar, archivo, registro):
    """Intercala `cantidad` errores entre las lineas buenas.
    Cada error se arma a partir de una linea buena ANTERIOR (asi un
    duplicado siempre aparece despues del original)."""
    posiciones = sorted(random.sample(range(10, len(buenas)), cantidad))
    random.shuffle(tipos)
    salida, emitidas, k = [], [], 0
    for i, linea in enumerate(buenas):
        salida.append(linea)
        emitidas.append(linea)
        while k < cantidad and posiciones[k] == i:
            base = random.choice(emitidas)
            tipo = tipos[k]
            nueva = fabricar(tipo, base, k + 1)
            salida.append(nueva)
            registro.append((archivo, len(salida), tipo))
            k += 1
    return salida


registro = []

# ---------------- INTERESES (27 posiciones) ----------------
# 1 moneda | 2-4 dias | 5-10 TNA | 11-16 TNA ant | 17-26 fecha | 27 estado
ok = leer("intereses.txt")
extra = {
    0: ("clave duplicada (D030 ya existe)", ok[0]),
    1: ("moneda X (CHECK)", "X030001.00000.002026-10-01A"),
    2: ("dias 045 (CHECK)", "D045001.00000.002026-10-01A"),
    4: ("fecha invalida 2026-13-31", "P030038.00000.002026-13-31A"),
    6: ("TNA no numerica", "P090AB1.00000.002026-10-01A"),
}
salida = []
for i, linea in enumerate(ok):
    salida.append(linea)
    if i in extra:
        salida.append(extra[i][1])
        registro.append(("intereses_db2.txt", len(salida), extra[i][0]))
assert all(len(x) == 27 for x in salida)
grabar("intereses_db2.txt", salida)

# ---------------- CLIENTES (107 posiciones) ----------------
# 1-8 DNI | 9-38 nombre | 39-78 direccion | 79-93 telefono
# 94-106 saldo | 107 estado
ok = leer("clientes.txt")


def fabricar_cliente(tipo, base, n):
    dni_nuevo = str(70000000 + n).zfill(8)
    if tipo == "DNI duplicado (clave primaria)":
        nombre = ("Duplicado Db2 %02d" % n).ljust(30)
        return base[:8] + nombre + base[38:]
    if tipo == "estado X (CHECK)":
        return dni_nuevo + base[8:106] + "X"
    if tipo == "saldo no numerico":
        return dni_nuevo + base[8:93] + "+ABC000000.00" + base[106]
    if tipo == "DNI no numerico":
        dni = "%04dA%03d" % (random.randint(1000, 9999),
                             random.randint(100, 999))
        return dni + base[8:]
    raise ValueError(tipo)


tipos = (["DNI duplicado (clave primaria)"] * 15 +
         ["estado X (CHECK)"] * 10 +
         ["saldo no numerico"] * 8 +
         ["DNI no numerico"] * 7)
salida = mezclar(ok, 40, tipos, fabricar_cliente,
                 "clientes_db2.txt", registro)
assert all(len(x) == 107 for x in salida)
grabar("clientes_db2.txt", salida)

# ---------------- PLAZOS FIJOS (87 posiciones) ----------------
# 1-6 nro | 7-14 DNI | 15 moneda | 16-29 monto | 30-32 dias
# 33-38 TNA | 39-52 interes | 53-66 total | 67-76 alta | 77-86 venc
# 87 estado
ok = leer("plazosfijos.txt")


def fabricar_pf(tipo, base, n):
    nro_nuevo = str(900000 + n).zfill(6)
    if tipo == "titular inexistente (clave foranea)":
        return nro_nuevo + str(99990000 + n) + base[14:]
    if tipo == "numero de plazo fijo duplicado (clave primaria)":
        return base
    if tipo == "estado X (CHECK)":
        return nro_nuevo + base[6:86] + "X"
    if tipo == "fecha de vencimiento invalida":
        return nro_nuevo + base[6:76] + "2027-02-30" + base[86]
    if tipo == "monto no numerico":
        return nro_nuevo + base[6:15] + "ABCDEFGHIJK.00" + base[29:]
    if tipo == "dias 045 (CHECK)":
        return nro_nuevo + base[6:29] + "045" + base[32:]
    raise ValueError(tipo)


tipos = (["titular inexistente (clave foranea)"] * 20 +
         ["numero de plazo fijo duplicado (clave primaria)"] * 10 +
         ["estado X (CHECK)"] * 10 +
         ["fecha de vencimiento invalida"] * 5 +
         ["monto no numerico"] * 5 +
         ["dias 045 (CHECK)"] * 5)
salida = mezclar(ok, 55, tipos, fabricar_pf,
                 "plazosfijos_db2.txt", registro)
assert all(len(x) == 87 for x in salida)
grabar("plazosfijos_db2.txt", salida)

# ---------------- clave de respuestas ----------------
with open(os.path.join(CARPETA, "errores_inyectados.txt"), "w",
          encoding="ascii", newline="\n") as f:
    f.write("ERRORES INYECTADOS EN LOS ARCHIVOS PARA DB2 "
            "(clave de respuestas)\n")
    f.write("ARCHIVO              LINEA  TIPO DE ERROR\n")
    f.write("-" * 78 + "\n")
    for archivo, linea, tipo in registro:
        f.write("%-20s %5d  %s\n" % (archivo, linea, tipo))
    f.write("-" * 78 + "\n")
    for archivo in ("intereses_db2.txt", "clientes_db2.txt",
                    "plazosfijos_db2.txt"):
        n = sum(1 for r in registro if r[0] == archivo)
        f.write("%-20s %5d errores\n" % (archivo, n))
    f.write("TOTAL                %5d errores\n" % len(registro))

print("Listo. Errores inyectados por archivo:")
for archivo in ("intereses_db2.txt", "clientes_db2.txt",
                "plazosfijos_db2.txt"):
    n = sum(1 for r in registro if r[0] == archivo)
    print("  %-20s %d" % (archivo, n))
print("  TOTAL                %d" % len(registro))
