# CLAUDE.md — Reglas de trabajo de este repositorio

Proyecto COBOL (GnuCOBOL) de gestión de cuentas bancarias:
- `cuenta.cbl`: programa interactivo (menú).
- `BATCH-CIERRE.cbl`: proceso batch nocturno de cierre (acredita intereses).
- `LISTADO-CLIENTES.cbl`: listado de solo lectura.
- `CLIENTE.cpy`: layout del registro del archivo indexado `clientes_v3.dat`
  (lo incluyen los tres programas con `COPY CLIENTE.`).
- `batch_cierre.jcl`: JCL de referencia para z/OS.

El usuario está aprendiendo: explicar todo con lenguaje simple, sin jerga
innecesaria y diciendo el "por qué" de cada paso.

## Cómo compilar y correr (comandos reales)

Regla de oro: compilar en `bin\` y ejecutar con `bin\` como carpeta de
trabajo, porque `clientes_v3.dat` se busca en la carpeta desde donde se
ejecuta el programa. Si se corre desde otro lado, se crea otro
`clientes_v3.dat` sin ningún aviso.

- Compilar `cuenta.cbl` (Windows):
  `cobc -x -Wall -o bin\cuenta.exe cuenta.cbl`
  Si `cobc` no está en el PATH, los `.bat` usan
  `C:\Program Files (x86)\OpenCobolIDE\GnuCOBOL` automáticamente.
- Pruebas automáticas (compila + corre + compara con `fc`):
  `cmd /c correr_pruebas_automatizadas.bat`
  El resumen queda también en `resultado_pruebas.txt`.
- Batch de cierre (compila + corre en `bin\`):
  `cmd /c correr_batch_cierre.bat` → genera `bin\reporte_cierre.txt`.
- Listado (solo lectura): `cmd /c ver_listado_clientes.bat`
  → genera `bin\listado_clientes.txt`.
- En CI (GitHub Actions, `.github/workflows/pruebas.yml`) y en el
  `Dockerfile` se usa Ubuntu con el paquete `gnucobol3` (no `gnucobol4`,
  que trae los archivos indexados deshabilitados). En CI se compara con
  `diff` en vez de `fc`.
- Si los `.bat` fallan por el bloqueo de Windows (Device Guard), las
  pruebas se corren en Docker: `docker build -t cuenta-cobol .` y después
  (desde PowerShell):
  `docker run --rm cuenta-cobol bash -c 'cd bin && sed -i s/\\r$// ../entrada_*.txt ../esperado_*.txt && FALLO=0 && for C in alta_ok alta_dni_invalido deposito extraccion consulta; do ./cuenta.exe < ../entrada_$C.txt > ../salida_$C.txt; if diff -q ../esperado_$C.txt ../salida_$C.txt > /dev/null; then echo OK - $C; else echo FALLO - $C; FALLO=1; fi; done; exit $FALLO'`
  Tienen que salir los 5 en `OK` y código de salida 0. Los casos manuales
  se corren con `docker run -it --rm cuenta-cobol`.
  Detalles de este comando (no "simplificarlo"):
  - El `sed` pasa los `.txt` de CRLF a LF solo dentro del contenedor. Hace
    falta porque con `core.autocrlf=true` la carpeta de Windows tiene CRLF,
    `docker build` copia eso, y en Linux el `\r` se lee como parte de lo
    tipeado (por ejemplo, el teléfono sale inválido y fallan los 5 casos).
  - No lleva comillas dobles dentro: PowerShell 5.1 las borra al pasarlas
    a `docker` y bash recibe el comando cortado.
  - Con `--rm`, los `salida_*.txt` quedan dentro del contenedor y se
    borran al terminar; el resultado se ve en pantalla.

Si una salida queda en 0 bytes, no es un bug de `cuenta.cbl`: falta el
runtime de GnuCOBOL en el PATH (ver README, "Solución de problemas").
No correr `cuenta.exe` y el batch al mismo tiempo sobre el mismo
`clientes_v3.dat`.

## Regla 1 — Después de cualquier cambio en `cuenta.cbl`

Recompilar y correr los 12 casos de `CASOS_DE_PRUEBA.md`:

- 5 automáticos (CP-01, CP-02, CP-03, CP-04, CP-06):
  `cmd /c correr_pruebas_automatizadas.bat`. Tiene que decir
  `Resumen: 5 OK / 0 FALLO (de 5)`.
- 7 manuales (CP-05, CP-07, CP-08, CP-09, CP-10, CP-11 y CP-12):
  seguir los pasos de la matriz, ejecutando `cuenta.exe` desde `bin\`.
  CP-12 incluye correr `correr_batch_cierre.bat` y revisar
  `bin\reporte_cierre.txt` (interés de 50,00 sobre 10.000,00 con la
  tasa por defecto de 0,50%).
- Usar los DNIs indicados en la matriz (800000XX para los automáticos,
  900000XX para los manuales).
- En cada caso manual, mostrarle al usuario qué se hizo: qué datos se
  ingresaron, qué mostró el programa y si coincide con el "Resultado
  esperado" de la matriz.
- Al terminar, informar un resumen caso por caso (OK / FALLO).
- Si un automático falla por "Ya existe un cliente con ese DNI", es por
  datos de una corrida anterior en `bin\clientes_v3.dat`. Avisar y
  preguntar antes de borrar ese archivo.

## Regla 2 — Si algún caso falla

Avisar cuál falló y por qué (mostrar la diferencia, por ejemplo
`fc esperado_alta_ok.txt salida_alta_ok.txt`) ANTES de tocar cualquier
`esperado_*.txt`. Los `esperado_*.txt` son la referencia verificada a
mano: nunca actualizarlos solos para que la prueba "pase".

## Regla 3 — Archivos que no se tocan sin confirmación

Pedir confirmación antes de modificar:
- `BATCH-CIERRE.cbl`
- `batch_cierre.jcl`
- el layout del archivo indexado: `CLIENTE.cpy` (y cualquier cambio en el
  `SELECT`/`FD` de `clientes_v3.dat` en los programas). Cambiar el layout
  obliga a recompilar los tres programas y puede romper los datos
  guardados.

## Regla 4 — Commit y push

No hacer `git commit` hasta que el usuario haya revisado el diff y lo
autorice. Nunca hacer `git push`: el push lo hace siempre el usuario.

## Regla 5 — Resultados de pruebas

`salida_*.txt` y `resultado_pruebas.txt` son resultados de las pruebas y
están en `.gitignore` (igual que `bin/`): no se agregan al repositorio.
No usar `git add -f` con ellos.
