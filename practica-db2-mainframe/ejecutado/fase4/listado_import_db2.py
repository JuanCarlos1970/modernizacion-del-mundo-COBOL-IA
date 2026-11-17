#!/usr/bin/env python3
# =====================================================================
#  listado_import_db2.py
#
#  Arma los dos listados de la carga a Db2 a partir de lo que informo
#  el comando IMPORT (archivos de mensajes imp_*_db2.msg) y de los
#  archivos de entrada (*_db2.txt):
#
#     listado_import_db2_ok.txt       registros CARGADOS, con el detalle
#                                     completo de cada uno
#     listado_import_db2_errores.txt  registros RECHAZADOS por Db2, con
#                                     el registro tal como venia y el
#                                     motivo (codigo SQL traducido)
#
#  Cada listado: titulo principal, una seccion por tabla (en el orden
#  de carga: tasas, clientes, plazos fijos) con subtitulos de columnas,
#  salto de pagina cada 55 lineas y totales de control al final.
#
#  Controles: (1) contra el resumen que informa el propio IMPORT
#  (mensaje SQL3149N); (2) lo cargado contra los archivos planos que
#  descargo COBOL (intereses.txt, clientes.txt, plazosfijos.txt);
#  (3) los rechazos contra errores_inyectados.txt (clave de respuestas).
#
#  Detalle importante: en los mensajes de un IMPORT de archivo ASC,
#  "column N" es la POSICION INICIAL del campo dentro del registro (no
#  el numero de columna de la tabla). Con las posiciones del METHOD L
#  se traduce al nombre del campo.
#
#  Uso:  python3 listado_import_db2.py [carpeta_con_los_archivos]
# =====================================================================
import datetime
import os
import re
import sys
from decimal import Decimal, InvalidOperation

CARPETA = sys.argv[1] if len(sys.argv) > 1 else "."
HOY = datetime.date.today().strftime("%d/%m/%Y")
MAX_LINEAS = 55
ANCHO = 132
SEP = "  "

# Posicion inicial de cada campo -> nombre (igual al METHOD L del IMPORT)
CAMPOS_INT = {1: "MONEDA", 2: "DIAS", 5: "TNA", 11: "TNA_ANTERIOR",
              17: "VIGENTE_DESDE", 27: "ESTADO"}
CAMPOS_CLI = {1: "DNI", 9: "NOMBRE", 39: "DIRECCION", 79: "TELEFONO",
              94: "SALDO", 107: "ESTADO"}
CAMPOS_PF = {1: "PF_NRO", 7: "DNI", 15: "MONEDA", 16: "MONTO", 30: "DIAS",
             33: "TNA_APLICADA", 39: "INTERES", 53: "TOTAL",
             67: "FECHA_ALTA", 77: "FECHA_VENC", 87: "ESTADO"}


def leer(nombre):
    ruta = os.path.join(CARPETA, nombre)
    if not os.path.exists(ruta):
        return None
    with open(ruta, encoding="ascii") as f:
        return f.read()


def lineas_de(nombre):
    t = leer(nombre)
    if t is None:
        sys.exit("ERROR: falta el archivo " + nombre)
    return [x for x in t.split("\n") if x != ""]


def num(txt):
    try:
        return "{:,.2f}".format(Decimal(txt))
    except (InvalidOperation, ValueError):
        return txt.strip()


def fecha(iso):
    try:
        return "%s/%s/%s" % (iso[8:10], iso[5:7], iso[0:4])
    except IndexError:
        return iso


# ---------- lectura de los mensajes del IMPORT ----------
def parsear_msg(nombre):
    texto = leer(nombre)
    if texto is None:
        sys.exit("ERROR: falta el archivo " + nombre)
    bloques = [re.sub(r"\s+", " ", b).strip()
               for b in re.split(r"\n\s*\n", texto) if b.strip()]
    rechazos, resumen = [], None
    codigo = texto_err = None
    for b in bloques:
        m = re.match(r"(SQL\d{4}[NW])", b)
        if not m:
            continue
        i = m.group(1)
        if i in ("SQL3120W", "SQL3124W"):
            r = re.search(r'row "(\d+)" and column "(\d+)"', b)
            rechazos.append(dict(fila=int(r.group(1)), id=i,
                                 col=int(r.group(2)), codigo=None,
                                 texto=b))
        elif i == "SQL3148W":
            c = re.search(r'SQLCODE "(-?\d+)"', b)
            codigo, texto_err = int(c.group(1)), None
        elif i == "SQL3185W":
            r = re.search(r'row "(\d+)"', b)
            rechazos.append(dict(fila=int(r.group(1)), id="SQL3185W",
                                 col=None, codigo=codigo,
                                 texto=texto_err or ""))
            codigo = texto_err = None
        elif i == "SQL3149N":
            n = re.findall(r'"(\d+)"', b)
            resumen = tuple(int(x) for x in n[:3])
        elif re.match(r"SQL0\d{3}N", i):
            texto_err = b
    return rechazos, resumen


def motivo(r, campos):
    if r["id"] in ("SQL3120W", "SQL3124W"):
        campo = campos.get(r["col"], "col %d" % r["col"])
        tipo = "entero" if r["id"] == "SQL3120W" else "decimal"
        return "%s no convertible a %s (%s)" % (campo, tipo, r["id"])
    c = r["codigo"]
    if c == -803:
        return "Clave primaria duplicada (SQL0803N)"
    if c == -545:
        m = re.search(r'check constraint "[^"]*\.([A-Z0-9_]+)"', r["texto"])
        return "No cumple %s (SQL0545N)" % (m.group(1) if m else "CHECK")
    if c == -530:
        m = re.search(r'FOREIGN KEY "[^"]*\.([A-Z0-9_]+)"', r["texto"])
        fk = m.group(1) if m else "FK"
        det = {"FK_PF_CLIENTE": "titular inexistente",
               "FK_PF_TASA": "tasa inexistente"}.get(fk, "sin padre")
        return "%s: %s (SQL0530N)" % (fk, det)
    if c == -180:
        return "Fecha invalida (SQL0180N)"
    return "SQLCODE %s" % c


# ---------- armado de lineas con columnas alineadas ----------
def ancho_real(spec):
    return [max(w, len(t)) for (t, w, a) in spec]


def subtitulos(spec):
    ws = ancho_real(spec)
    return SEP.join(("{:%s%d}" % (a, w)).format(t)
                    for (t, w, a), w in zip(spec, ws))


def fila(spec, valores):
    ws = ancho_real(spec)
    return SEP.join(("{:%s%d}" % (a, w)).format(str(v)[:w])
                    for (t, w, a), w, v in zip(spec, ws, valores))


class Listado:
    def __init__(self, nombre, titulo, programa):
        self.f = open(os.path.join(CARPETA, nombre), "w",
                      encoding="ascii", newline="\n")
        self.titulo, self.programa = titulo, programa
        self.pagina, self.lineas, self.sec = 0, 0, None

    def _w(self, s=""):
        self.f.write(s.rstrip() + "\n")

    def _enc_sec(self):
        self._w(self.sec[0])
        self._w(self.sec[1])
        self._w("-" * ANCHO)
        self.lineas += 3

    def nueva_pagina(self):
        self.pagina += 1
        if self.pagina > 1:
            self._w()
        self._w(self.titulo)
        self._w("Fecha de proceso: %s   Programa: %s   Pagina: %4d"
                % (HOY, self.programa, self.pagina))
        self._w()
        self.lineas = 3
        if self.sec:
            self._enc_sec()

    def seccion(self, nombre, subt):
        self.sec = (nombre, subt)
        if self.pagina == 0 or self.lineas > MAX_LINEAS - 8:
            self.nueva_pagina()
        else:
            self._w()
            self.lineas += 1
            self._enc_sec()

    def linea(self, s):
        if self.lineas >= MAX_LINEAS:
            self.nueva_pagina()
        self._w(s)
        self.lineas += 1

    def libre(self, s=""):
        self._w(s)
        self.lineas += 1

    def cerrar(self):
        self.f.close()


# ---------- definicion de las tres tablas ----------
def datos_int_ok(r):
    return [r[0], int(r[1:4]), num(r[4:10]), num(r[10:16]),
            fecha(r[16:26]), r[26]]


def datos_cli_ok(r):
    return [r[0:8], r[8:38], r[38:78], r[78:93], num(r[93:106]), r[106]]


def datos_pf_ok(r):
    return [r[0:6], r[6:14], r[14], num(r[15:29]), int(r[29:32]),
            num(r[32:38]), num(r[38:52]), num(r[52:66]),
            fecha(r[66:76]), fecha(r[76:86]), r[86]]


TABLAS = [
    dict(nombre="TASAS DE INTERES (tabla INTERESES)",
         entrada="intereses_db2.txt", msg="imp_intereses_db2.msg",
         original="intereses.txt", campos=CAMPOS_INT,
         spec_ok=[("MON", 3, "<"), ("DIAS", 4, ">"), ("TNA %", 7, ">"),
                  ("TNA ANT %", 9, ">"), ("VIGENTE DESDE", 13, "<"),
                  ("EST", 3, "<")],
         datos_ok=datos_int_ok,
         spec_er=[("FILA", 5, ">"), ("MON", 3, "<"), ("DIAS", 4, "<"),
                  ("TNA", 6, "<"), ("TNA ANT", 6, "<"),
                  ("VIGENTE", 10, "<"), ("EST", 3, "<"),
                  ("MOTIVO", 50, "<")],
         datos_er=lambda i, r: [i, r[0], r[1:4], r[4:10], r[10:16],
                                r[16:26], r[26]]),
    dict(nombre="CLIENTES (tabla CLIENTES)",
         entrada="clientes_db2.txt", msg="imp_clientes_db2.msg",
         original="clientes.txt", campos=CAMPOS_CLI,
         spec_ok=[("DNI", 8, "<"), ("NOMBRE", 30, "<"),
                  ("DIRECCION", 40, "<"), ("TELEFONO", 15, "<"),
                  ("SALDO", 17, ">"), ("EST", 3, "<")],
         datos_ok=datos_cli_ok,
         spec_er=[("FILA", 5, ">"), ("DNI", 8, "<"), ("NOMBRE", 24, "<"),
                  ("TELEFONO", 15, "<"), ("SALDO", 13, "<"),
                  ("EST", 3, "<"), ("MOTIVO", 50, "<")],
         datos_er=lambda i, r: [i, r[0:8], r[8:38], r[78:93],
                                r[93:106], r[106]]),
    dict(nombre="PLAZOS FIJOS (tabla PLAZOS_FIJOS)",
         entrada="plazosfijos_db2.txt", msg="imp_plazos_db2.msg",
         original="plazosfijos.txt", campos=CAMPOS_PF,
         spec_ok=[("NRO PF", 6, "<"), ("DNI", 8, "<"), ("M", 1, "<"),
                  ("MONTO", 17, ">"), ("DIAS", 4, ">"), ("TNA %", 7, ">"),
                  ("INTERES", 17, ">"), ("TOTAL", 17, ">"),
                  ("FECHA ALTA", 10, "<"), ("FECHA VENC", 10, "<"),
                  ("E", 1, "<")],
         datos_ok=datos_pf_ok,
         spec_er=[("FILA", 5, ">"), ("NRO PF", 6, "<"), ("DNI", 8, "<"),
                  ("M", 1, "<"), ("MONTO", 14, "<"), ("DIAS", 4, "<"),
                  ("ALTA", 10, "<"), ("VENC", 10, "<"), ("E", 1, "<"),
                  ("MOTIVO", 50, "<")],
         datos_er=lambda i, r: [i, r[0:6], r[6:14], r[14], r[15:29],
                                r[29:32], r[66:76], r[76:86], r[86]]),
]

for t in TABLAS:
    for k in ("spec_ok", "spec_er"):
        total = sum(ancho_real(t[k])) + len(SEP) * (len(t[k]) - 1)
        assert total <= ANCHO, (t["nombre"], k, total)

# ---------- clave de respuestas (errores_inyectados.txt) ----------
clave = None
txt_clave = leer("errores_inyectados.txt")
if txt_clave is not None:
    clave = {}
    for ln in txt_clave.split("\n"):
        m = re.match(r"^(\S+_db2\.txt)\s+(\d+)\s+(.+)$", ln)
        if m and m.group(3).strip() != "errores":
            clave.setdefault(m.group(1), set()).add(int(m.group(2)))

# ---------- proceso ----------
ok = Listado("listado_import_db2_ok.txt",
             "GESTION BANCARIA - CARGA A DB2 - REGISTROS CARGADOS (OK)",
             "LISTADO-IMPORT-DB2")
er = Listado("listado_import_db2_errores.txt",
             "GESTION BANCARIA - CARGA A DB2 - REGISTROS RECHAZADOS "
             "(ERRORES)", "LISTADO-IMPORT-DB2")

control_ok, control_er, motivos_total = [], [], {}
for t in TABLAS:
    entrada = lineas_de(t["entrada"])
    rechazos, resumen = parsear_msg(t["msg"])
    filas_rech = {}
    for r in rechazos:
        filas_rech[r["fila"]] = motivo(r, t["campos"])
    original = lineas_de(t["original"])

    # -- listado OK
    ok.seccion("TABLA " + t["nombre"] + " - REGISTROS CARGADOS",
               subtitulos(t["spec_ok"]))
    n_ok = 0
    for i, reg in enumerate(entrada, start=1):
        if i not in filas_rech:
            ok.linea(fila(t["spec_ok"], t["datos_ok"](reg)))
            n_ok += 1
    control_ok.append((t["nombre"], len(entrada), n_ok, len(filas_rech),
                       resumen, len(original)))

    # -- listado de errores
    er.seccion("TABLA " + t["nombre"] + " - REGISTROS RECHAZADOS",
               subtitulos(t["spec_er"]))
    motivos = {}
    for i in sorted(filas_rech):
        reg = entrada[i - 1]
        valores = t["datos_er"](i, reg) + [filas_rech[i]]
        er.linea(fila(t["spec_er"], valores))
        clave_m = re.sub(r"\(SQL\w+\)", "", filas_rech[i]).strip()
        motivos[clave_m] = motivos.get(clave_m, 0) + 1
    control_er.append((t["nombre"], t["entrada"], set(filas_rech),
                       motivos, resumen, len(entrada)))

# ---------- pie del listado OK ----------
ok.libre()
ok.libre("-" * ANCHO)
ok.libre("TOTALES DE CONTROL POR TABLA")
ok.libre("%-38s %8s %10s %10s %12s" % ("TABLA", "LEIDOS", "CARGADOS",
                                         "RECHAZADOS", "ARCH. COBOL"))
for nombre, leidos, n_ok, n_rech, resumen, n_cobol in control_ok:
    ok.libre("%-38s %8d %10d %10d %12d" % (nombre[:38], leidos, n_ok,
                                            n_rech, n_cobol))
ok.libre()
for nombre, leidos, n_ok, n_rech, resumen, n_cobol in control_ok:
    nom = nombre.split(" (")[0]
    if resumen is None:
        ok.libre("CONTROL %s: no se encontro el resumen del IMPORT "
                 "(SQL3149N)." % nom)
    elif resumen[1] == n_ok and resumen[2] == n_rech:
        ok.libre("CONTROL %s: coincide con el resumen del IMPORT "
                 "(%d insertadas, %d rechazadas)." % (nom, resumen[1],
                                                       resumen[2]))
    else:
        ok.libre("CONTROL %s: *** NO COINCIDE con el resumen del IMPORT "
                 "***" % nom)
    if n_ok == n_cobol:
        ok.libre("CONTROL %s: lo cargado en Db2 (%d) coincide con lo "
                 "descargado de COBOL." % (nom, n_ok))
    else:
        ok.libre("CONTROL %s: *** Db2 tiene %d y el archivo de COBOL %d "
                 "***" % (nom, n_ok, n_cobol))
ok.cerrar()

# ---------- pie del listado de errores ----------
er.libre()
er.libre("-" * ANCHO)
er.libre("TOTALES DE CONTROL POR TABLA")
er.libre("%-38s %8s %10s" % ("TABLA", "LEIDOS", "RECHAZADOS"))
for nombre, entrada, filas, motivos, resumen, leidos in control_er:
    er.libre("%-38s %8d %10d" % (nombre[:38], leidos, len(filas)))
    for k, v in motivos.items():
        motivos_total[k] = motivos_total.get(k, 0) + v
er.libre("%-38s %8s %10d" % ("TOTAL", "",
                             sum(len(c[2]) for c in control_er)))
er.libre()
er.libre("RESUMEN POR MOTIVO (todas las tablas)")
for k in sorted(motivos_total, key=lambda x: (-motivos_total[x], x)):
    er.libre("  %-50s %6d" % (k, motivos_total[k]))
er.libre()
for nombre, entrada, filas, motivos, resumen, leidos in control_er:
    nom = nombre.split(" (")[0]
    if resumen is None:
        er.libre("CONTROL %s: no se encontro el resumen del IMPORT "
                 "(SQL3149N)." % nom)
    elif resumen[2] == len(filas):
        er.libre("CONTROL %s: coincide con el resumen del IMPORT "
                 "(%d rechazadas)." % (nom, resumen[2]))
    else:
        er.libre("CONTROL %s: *** NO COINCIDE con el resumen del IMPORT "
                 "***" % nom)
    if clave is not None:
        esperadas = clave.get(entrada, set())
        if esperadas == filas:
            er.libre("CONTROL %s: las %d filas rechazadas coinciden con "
                     "la clave de respuestas." % (nom, len(filas)))
        else:
            faltan = sorted(esperadas - filas)
            sobran = sorted(filas - esperadas)
            er.libre("CONTROL %s: *** NO COINCIDE con la clave de "
                     "respuestas: faltan %s, sobran %s ***"
                     % (nom, faltan, sobran))
er.cerrar()

print("Listo.")
print("  listado_import_db2_ok.txt")
print("  listado_import_db2_errores.txt")
