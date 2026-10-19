# Gestión de Cuentas Bancarias

<a id="sobre-este-proyecto"></a>
## Sobre este proyecto

Este proyecto fue desarrollado con **[Claude Code](https://claude.com/claude-code)** (el asistente de inteligencia artificial de Anthropic para tareas de ingeniería de software), bajo la dirección de un analista con experiencia real en sistemas bancarios.

Es una demostración práctica de cómo la IA puede acelerar el análisis, el desarrollo y la modernización de sistemas legacy en COBOL: partiendo de un programa mínimo de alta/depósito/extracción/consulta, se fue iterando —siempre con revisión humana en cada paso— hasta llegar a un sistema con estados de cliente, baja lógica y reactivación, un proceso batch de cierre con acreditación de interés, un programa de consulta de solo lectura, documentación de referencia de cómo correría el mismo batch en un mainframe z/OS real (JCL), una matriz de casos de prueba, y pruebas semi-automatizadas. En el camino se encontró y se corrigió, con evidencia reproducible, un bug real de generación de código del compilador GnuCOBOL 2.0 (ver [Programa interactivo: gestion-bancaria.cbl](#programa-gestion-bancaria)).

El código, la arquitectura y cada decisión de diseño fueron guiados y revisados por el autor; la IA se usó como herramienta de productividad para escribir, probar y documentar más rápido — no como reemplazo del criterio profesional.

<a id="descripcion-general"></a>
## Descripción general

`gestion-bancaria.cbl` es un programa COBOL interactivo (consola) para gestionar clientes y saldos de una cuenta bancaria simple. Es un ejemplo didáctico, pensado para mostrar patrones típicos de un sistema bancario legacy: archivos indexados, procesos batch nocturnos, y las decisiones de diseño (y las limitaciones) que eso implica.

Funciones del programa interactivo: **alta**, **modificación**, **baja lógica** y **reactivación** de clientes; **depósito**, **extracción** y **consulta de saldo**. Cada cliente tiene DNI, nombre, dirección, teléfono, saldo y **estado** (Activo / Inactivo / Reactivado). Los datos se guardan en un **archivo indexado** (`clientes_v3.dat`, clave = DNI) y sobreviven al cerrar y reabrir el programa.

Desde la **Evolución 1 / Etapa 1** el menú incluye además la opción **Intereses**, que administra la tabla de tasas (TNA) por moneda y plazo, guardada en otro archivo indexado (`intereses.dat`). Desde la **Etapa 2** la opción **Plazo fijo** permite constituir plazos fijos (con confirmación), cancelarlos en forma anticipada y consultarlos; se guardan en un tercer archivo indexado (`plazofijo.dat`) y usan las tasas de Intereses. Las otras opciones nuevas (Cuenta corriente / Caja de ahorro, Historial de movimientos y Pago de servicios) por ahora solo muestran `Opcion en desarrollo.`.

Además del programa interactivo, el proyecto incluye:

- Un **proceso batch de cierre** (`BATCH-CIERRE.cbl`) que acredita interés mensual a las cuentas activas, con un JCL de referencia que documenta cómo correría el mismo proceso en un mainframe z/OS real.
- Un **listado de consulta de solo lectura** (`LISTADO-CLIENTES.cbl`) que muestra la cartera agrupada por estado, sin modificar ningún dato.
- Una **matriz de casos de prueba** y un **juego de pruebas semi-automatizadas** para los escenarios más simples.

## Tabla de contenidos

- [Sobre este proyecto](#sobre-este-proyecto)
- [Descripción general](#descripcion-general)
- [Requisitos previos](#requisitos-previos)
- [Estructura de archivos](#estructura-de-archivos)
- [Compilación y ejecución](#compilacion-y-ejecucion)
- [Programa interactivo: gestion-bancaria.cbl](#programa-gestion-bancaria)
- [Proceso batch de cierre: BATCH-CIERRE.cbl](#proceso-batch-cierre)
- [Listado de clientes (solo lectura): LISTADO-CLIENTES.cbl](#listado-clientes)
- [Testing](#testing)
- [Solución de problemas](#solucion-de-problemas)
- [Limitaciones y mejoras futuras](#limitaciones-y-mejoras)
- [Licencia](#licencia)
- [Autor](#autor)

<a id="requisitos-previos"></a>
## Requisitos previos

- **Windows.** Los scripts `.bat` y las rutas de este documento están pensados para Windows; el código COBOL en sí es portable a otros sistemas operativos con GnuCOBOL, pero eso no se probó.
- **[GnuCOBOL](https://gnucobol.sourceforge.io/)**, con el compilador `cobc` y su runtime (`libcob` y DLLs asociadas). Todo lo de este proyecto se probó con **GnuCOBOL 2.0.0**, el que trae [OpenCobolIDE](http://opencobolide.appspot.com/).
- No hace falta ninguna base de datos, servidor ni conexión de red: todo corre localmente, con archivos.
- Conocimientos básicos de línea de comandos (`cmd` o PowerShell) para compilar y correr los programas o los scripts `.bat`.

<a id="estructura-de-archivos"></a>
## Estructura de archivos

| Archivo | Descripción |
|---------|-------------|
| `gestion-bancaria.cbl` | Programa interactivo (código fuente, formato fijo COBOL) — ver [Programa interactivo: gestion-bancaria.cbl](#programa-gestion-bancaria) |
| `BATCH-CIERRE.cbl` | Proceso batch de cierre: acredita interés mensual y procesa los vencimientos de plazo fijo — ver [Proceso batch de cierre](#proceso-batch-cierre) |
| `LISTADO-CLIENTES.cbl` | Listado de consulta de **solo lectura**: no modifica datos — ver [Listado de clientes (solo lectura)](#listado-clientes) |
| `CLIENTE.cpy` | Copybook con el layout del registro de cliente, compartido por los tres programas de arriba |
| `INTERES.cpy` | Copybook con el layout del registro de tasas (`intereses.dat`), incluido por `gestion-bancaria.cbl` |
| `PLAZOFIJO.cpy` | Copybook con el layout del registro de plazo fijo (`plazofijo.dat`), incluido por `gestion-bancaria.cbl` y `BATCH-CIERRE.cbl` |
| `correr_batch_cierre.bat` | Compila `BATCH-CIERRE.cbl` en `bin\` y lo ejecuta ahí |
| `ver_listado_clientes.bat` | Compila `LISTADO-CLIENTES.cbl` en `bin\` y lo ejecuta ahí |
| `correr_pruebas_automatizadas.bat` | Compila `gestion-bancaria.exe` en `bin\` y corre los 5 casos de prueba semi-automatizados y, después, los casos de INTERESES, los de PLAZO FIJO y los de VENCIMIENTOS (estos últimos también compilan y corren `BATCH-CIERRE.exe`) — ver [Testing](#testing) |
| `correr_pruebas_intereses.sh` | Lo mismo que la segunda parte del `.bat`, pero para Linux (Docker y GitHub Actions) |
| `correr_pruebas_plazofijo.sh` | Lo mismo que la tercera parte del `.bat` (casos de PLAZO FIJO), para Linux (Docker y GitHub Actions) |
| `correr_pruebas_vencimientos.sh` | Lo mismo que la cuarta parte del `.bat` (casos de VENCIMIENTOS con el batch de cierre), para Linux (Docker y GitHub Actions) |
| `.gitattributes` | Fuerza fin de línea LF en los `.sh` (con CRLF, bash no los puede ejecutar) |
| `.dockerignore` | Deja `bin\` afuera de la imagen de Docker: los `.dat` creados en Windows no se pueden leer con el GnuCOBOL de Linux |
| `batch_cierre.jcl` | JCL de **referencia/documentación**: cómo correría el mismo cierre en un mainframe z/OS real (no se ejecuta en este entorno) |
| `README.md` | Esta documentación |
| `CASOS_DE_PRUEBA.md` | Matriz de casos de prueba (QA) — ver [Testing](#testing) |
| `LICENSE` | Licencia del proyecto — ver [Licencia](#licencia) |
| `entrada_*.txt` | Entradas de los casos de prueba automatizados: los 5 de clientes (`alta_ok`, `alta_dni_invalido`, `deposito`, `extraccion`, `consulta`) y los de INTERESES, PLAZO FIJO y VENCIMIENTOS (`entrada_menu01_1.txt`, `entrada_int01_1.txt`, `entrada_pf01_1.txt`, `entrada_vto01_1.txt`, ..., uno por paso) |
| `esperado_*.txt` | Salida de referencia, verificada a mano, de cada caso automatizado |
| `salida_*.txt` | Salidas correspondientes a cada caso, generadas al correr las pruebas (no se suben al repositorio) |

**Se generan al compilar y ejecutar, dentro de `bin\`** (no forman parte del código fuente; ver [Compilación y ejecución](#compilacion-y-ejecucion)):

| Archivo (en `bin\`) | Descripción |
|----------------------|-------------|
| `gestion-bancaria.exe` | Ejecutable de `gestion-bancaria.cbl` |
| `BATCH-CIERRE.exe` | Ejecutable de `BATCH-CIERRE.cbl` |
| `LISTADO-CLIENTES.exe` | Ejecutable de `LISTADO-CLIENTES.cbl` |
| `clientes_v3.dat` | Archivo de datos indexado, compartido por los tres programas. **Se crea solo** en la primera ejecución de `gestion-bancaria.cbl` |
| `intereses.dat` | Archivo indexado de tasas (opción 8 - Intereses). **Se crea solo** en la primera ejecución de `gestion-bancaria.cbl`, junto a `clientes_v3.dat` |
| `plazofijo.dat` | Archivo indexado de plazos fijos (opción 7 - Plazo fijo). **Se crea solo** en la primera ejecución de `gestion-bancaria.cbl`, junto a los otros dos |
| `reporte_cierre.txt` | Reporte del cierre, generado por `BATCH-CIERRE.cbl` en cada corrida |
| `listado_clientes.txt` | Listado de clientes, generado por `LISTADO-CLIENTES.cbl` en cada corrida |

<a id="compilacion-y-ejecucion"></a>
## Compilación y ejecución

Escrito en COBOL de formato fijo. Los tres programas (`gestion-bancaria.cbl`, `BATCH-CIERRE.cbl`, `LISTADO-CLIENTES.cbl`) incluyen el layout del cliente con `COPY CLIENTE.`, así que **`CLIENTE.cpy` tiene que estar en la misma carpeta que el `.cbl`** al compilar cualquiera de los tres (no hace falta copiarlo a `bin\`: `cobc` lo busca junto al código fuente).

### Dónde vive `clientes_v3.dat`

**Todos los programas y scripts de este proyecto tienen que operar sobre el mismo `clientes_v3.dat`.** La convención acá es:

- **En la raíz del proyecto** (esta carpeta): el código fuente (`.cbl`, `CLIENTE.cpy`), la documentación, y los `entrada_*.txt` / `salida_*.txt` de las pruebas.
- **En `bin\`**: los ejecutables compilados y, junto a ellos, **`clientes_v3.dat`** y todo lo que generan (`reporte_cierre.txt`, `listado_clientes.txt`).

Un archivo indexado en COBOL se busca **relativo al directorio desde donde se ejecuta el programa** (no al directorio donde está el `.exe` ni al del código fuente). Por eso importa tanto: si un `.exe` se compila o se corre desde otro lugar, termina creando o leyendo un `clientes_v3.dat` **distinto** ahí, silenciosamente — sin ningún error, porque un archivo nuevo es un caso válido para cualquiera de los tres programas. Esto ya pasó una vez durante el desarrollo de este proyecto: una versión anterior de un script de pruebas compilaba y corría en la raíz en vez de en `bin\`, y creó ahí un `clientes_v3.dat` aparte con clientes de prueba (nada grave — solo contenía esos clientes, ningún dato real — pero igual generaba dos "carteras" distintas sin que nada lo avisara).

**La forma segura de evitarlo es usar siempre los `.bat` provistos:**

```bat
correr_batch_cierre.bat            REM compila y corre en bin\
ver_listado_clientes.bat           REM idem
correr_pruebas_automatizadas.bat   REM idem, para los 5 casos semi-automatizados
```

Los tres compilan el `.exe` directamente en `bin\` y lo ejecutan desde ahí, así que siempre apuntan a `bin\clientes_v3.dat`. `gestion-bancaria.cbl`, al no tener un `.bat` propio (es el programa de uso diario, pensado para dejarse abierto en el menú), hay que compilarlo y correrlo apuntando a `bin\` a mano (ver abajo) — o, más simple, usar OpenCobolIDE, que ya compila y corre con `bin\` como carpeta de trabajo por convención.

### Compilar a mano

Para compilar apuntando siempre a `bin\`:

```bash
cobc -x -Wall -o bin/gestion-bancaria gestion-bancaria.cbl    # programa interactivo
cd bin && ./gestion-bancaria                                  # Windows: bin\gestion-bancaria.exe

cobc -x -Wall -o bin/BATCH-CIERRE BATCH-CIERRE.cbl            # batch de cierre
cd bin && ./BATCH-CIERRE                                      # Windows: bin\BATCH-CIERRE.exe

cobc -x -Wall -o bin/LISTADO-CLIENTES LISTADO-CLIENTES.cbl    # listado (solo lectura)
cd bin && ./LISTADO-CLIENTES                                  # Windows: bin\LISTADO-CLIENTES.exe
```

**Importante:** el `-o bin/programa` solo dice dónde queda el `.exe`; para que el programa *use* `bin\clientes_v3.dat` hay que **ejecutarlo con `bin\` como directorio de trabajo** (por eso el `cd bin` antes de correrlo). Compilar con `-o bin\gestion-bancaria.exe` pero correrlo desde la raíz (`bin\gestion-bancaria.exe` sin más) no alcanza: el archivo de datos se buscaría igual en la raíz.

En Windows, `correr_batch_cierre.bat` y `ver_listado_clientes.bat` hacen cada uno su bloque (compilar en `bin\` y ejecutar ahí) en un solo paso; no hace falta escribir estos comandos a mano para esos dos programas.

### Qué se probó

Probado con GnuCOBOL 2.0.0 (el que trae OpenCobolIDE): los tres programas compilan con `-Wall` sin errores ni warnings.

- **`gestion-bancaria.cbl`:** todas las opciones del menú, cada validación, el ciclo completo de estados (alta → baja → reactivación → baja), la restricción a clientes inactivos, el retorno al menú principal, la persistencia entre ejecuciones y el manejo de un archivo de datos corrupto.
- **`BATCH-CIERRE.cbl`:** el cálculo de interés sobre clientes Activos y Reactivados, la exclusión de Inactivos, el archivo de clientes inexistente (cartera vacía), y que `gestion-bancaria.cbl` sigue leyendo y escribiendo `clientes_v3.dat` correctamente después de una corrida del batch. Desde la Etapa 3, además, los vencimientos de plazo fijo (casos VTO-01 a VTO-12, en GnuCOBOL 2.0.0 en Windows y 3.x en Docker), y que con los datos de CP-12 el reporte nuevo solo **agrega** la sección de vencimientos y las líneas nuevas del resumen respecto del reporte anterior.
- **`LISTADO-CLIENTES.cbl`:** las tres secciones con una cartera mixta (Activos, Reactivados e Inactivos), el archivo inexistente (cartera vacía), que la pantalla y `listado_clientes.txt` muestran exactamente el mismo contenido, y —con un hash del archivo antes y después de correrlo— que `clientes_v3.dat` queda **byte a byte idéntico**.

<a id="programa-gestion-bancaria"></a>
## Programa interactivo: gestion-bancaria.cbl

### Menú principal

```
  ======================================
             GESTION BANCARIA
  ======================================

     1 - Alta de cliente
     2 - Modificar / Baja de cliente
     3 - Deposito
     4 - Extraccion
     5 - Consulta de saldo
     6 - Cuenta corriente / Caja de ahorro
     7 - Plazo fijo
     8 - Intereses
     9 - Historial de movimientos
    10 - Pago de servicios

     0 - Salir

  Opcion:
```

| Opción | Qué hace |
|--------|----------|
| 1 | Registra un cliente (DNI, nombre, dirección, teléfono). Queda con saldo 0 y estado **A** (Activo) |
| 2 | Busca al cliente por DNI, muestra sus datos y permite **modificar** (o **reactivar**, si está inactivo) o dar de **baja** |
| 3 | Suma un monto al saldo. Bloqueado si el cliente está **inactivo** |
| 4 | Resta un monto del saldo (sin descubierto). Bloqueado si el cliente está **inactivo** |
| 5 | Muestra todos los datos del cliente, incluido el estado |
| 6, 9, 10 | En desarrollo: muestran `Opcion en desarrollo.` y vuelven al menú |
| 7 | Submenú de **plazo fijo** (alta, cancelación anticipada y consulta) — ver [Plazo fijo (opción 7)](#plazo-fijo) |
| 8 | Submenú de **tasas de interés** (alta, modificación y baja) — ver [Intereses (opción 8)](#intereses) |
| 0 | Cierra los archivos y sale |

El "10" tiene dos dígitos, por eso la opción se lee en un campo de 2 caracteres (`WS-OPCION PIC X(2)`). Una opción de un dígito queda guardada como `"1 "` (con un espacio), y COBOL la compara igual contra `"1"`, porque completa con espacios el valor más corto.

Cualquier otro valor muestra `Opcion invalida.` y vuelve al menú. Si el cliente no existe, todas las operaciones muestran `Cliente no encontrado.`.

**Después de cualquier operación el programa vuelve directamente a este menú principal.** No queda ningún submenú abierto (ver «Retorno al menú principal», más abajo).

### El campo Estado

Cada cliente tiene un campo **Estado** de 1 carácter con tres valores posibles:

| Valor | Significado | ¿Puede depositar / extraer? |
|-------|-------------|------------------------------|
| `A` | **Activo.** Estado inicial de todo cliente nuevo | Sí |
| `I` | **Inactivo.** Se llega con la baja lógica | **No** |
| `R` | **Reactivado.** Cliente que estuvo inactivo y fue reactivado | Sí (se considera operativo) |

Cómo cambia el estado:

```
   alta            baja (B)             reactivar (M)
  ───────▶  A  ─────────────▶  I  ───────────────────▶  R
                                ▲                        │
                                └────────────────────────┘
                                       baja (B)
```

- **Alta:** el cliente queda en `A`.
- **Baja (`B`):** no elimina el registro; pone el estado en `I` (baja lógica). Vale para clientes `A` y `R`.
- **Reactivación (`M` sobre un cliente `I`):** pone el estado en `R`. Es el único camino de `I` a otro estado.
- **Modificación de datos (`M` sobre un cliente `A` o `R`):** no toca el estado.
- **Depósito y extracción:** se bloquean **solo cuando el estado es `I`** (`Cliente inactivo: no se puede operar.`, sin pedir el monto). `A` y `R` operan igual; `R` solo deja constancia de que el cliente fue reactivado.
- **Consulta** (opción 5) funciona con cualquier estado.
- Un valor de estado distinto de `A`, `I` o `R` (por ejemplo por un archivo dañado) se muestra como `? - Desconocido` y se trata como no operable.

### Datos que muestra el programa

Siempre que se muestra un cliente (opción 5, opción 2 y al terminar una modificación, baja o reactivación) se usa el mismo bloque:

```
Nombre:    Ana Perez
DNI:       12345678
Direccion: Calle 1
Telefono:  011 4444-5555
Saldo:              250.75
Estado:    A - Activo
```

El estado se muestra como `A - Activo`, `I - Inactivo` o `R - Reactivado`.

### Alta de cliente (opción 1)

Pide, en orden: DNI, nombre, dirección y teléfono. Si algún dato es inválido se muestra el motivo, el alta se cancela (`Alta cancelada.`) y **no se graba nada**; hay que volver a elegir la opción 1. El DNI se valida y se verifica que no exista antes de pedir los demás datos. El cliente se graba con saldo `0` y estado `A`.

### Modificar / Baja de cliente (opción 2)

El flujo es siempre el mismo, en este orden:

1. **Pide el DNI** (8 dígitos).
2. **Verifica si existe.** Si NO existe: `Cliente no encontrado.` y vuelve al menú principal.
3. Si existe, **muestra todos sus datos actuales** (nombre, DNI, dirección, teléfono, saldo, estado).
4. **Recién entonces** pregunta:

   ```
   Desea (M)odificar o (B)aja el cliente?
   ```

| Respuesta | Resultado |
|-----------|-----------|
| `M` o `m` | Modificación, o reactivación si el cliente está inactivo (ver abajo) |
| `B` o `b` | Baja lógica (ver abajo) |
| cualquier otra | `Opcion invalida: use M o B.` y vuelve al menú principal (no se repite la pregunta) |

#### Qué pasa con `M` según el estado del cliente

| Estado | Resultado de `M` |
|--------|------------------|
| `I` (Inactivo) | **Solo se puede reactivar**: se pone el estado en `R` directamente, sin confirmación. **No se ofrece** modificar dirección, teléfono ni saldo |
| `A` (Activo) o `R` (Reactivado) | Se pueden modificar Dirección, Teléfono y/o Saldo. El estado no se toca |

##### Reactivación (`M` sobre un cliente inactivo)

```
Cliente reactivado (estado R).

Datos actualizados del cliente:
Nombre:    Ana Perez
...
Estado:    R - Reactivado
```

Se hace un `REWRITE` con `CLI-ESTADO = "R"`, se muestran los datos actualizados y se vuelve al menú principal.

##### Modificación de datos (`M` sobre un cliente `A` o `R`)

Se pueden editar **solo tres datos: Dirección, Teléfono y Saldo**. **El nombre y el DNI no se modifican nunca** (el DNI es la clave del archivo; el nombre ni siquiera se ofrece). El estado tampoco se cambia en este flujo.

Se ofrece un **submenú** que se repite hasta elegir "Terminar modificación":

```
  ======================================
           QUE DESEA MODIFICAR?
  ======================================

     1 - Direccion
     2 - Telefono
     3 - Saldo

     4 - Terminar modificacion

  Opcion:
```

Ejemplo, modificando dirección y saldo en la misma operación:

```
  Opcion: 1
Direccion (hasta 40 caracteres): Nueva 456
Dato modificado.

  ======================================
           QUE DESEA MODIFICAR?
  ======================================

     1 - Direccion
     2 - Telefono
     3 - Saldo

     4 - Terminar modificacion

  Opcion: 3
Nuevo saldo (cero o mayor): 500
Dato modificado.

  ======================================
           QUE DESEA MODIFICAR?
  ======================================

     1 - Direccion
     2 - Telefono
     3 - Saldo

     4 - Terminar modificacion

  Opcion: 4

Datos actualizados del cliente:
Nombre:    Ana Perez
DNI:       12345678
Direccion: Nueva 456
Telefono:  011 4444-5555
Saldo:              500.00
Estado:    A - Activo
```

- Se puede elegir **uno, varios o los tres campos**, en el orden que se quiera, antes de terminar (opción `4`).
- Cada campo elegido se valida con las mismas reglas del alta (ver [Validaciones](#validaciones-cuenta)) y, si es válido, **se graba en el momento** (`REWRITE` inmediato) con el mensaje `Dato modificado.`. El submenú vuelve a aparecer para seguir modificando otro campo o para terminar.
- Si el dato nuevo es inválido, se informa el motivo, **no se graba nada** y el submenú se repite para reintentar ese mismo campo o elegir otro.
- Un número de opción fuera de `1`–`4` muestra `Opcion invalida.` y repite el submenú.
- Al elegir `4`, si no se grabó ningún cambio en toda la sesión se informa `No se modifico ningun dato.`; si se grabó al menos uno, se pasa directo a mostrar los **datos actualizados**. En ambos casos se vuelve al menú principal.

#### Baja (respuesta `B`)

La baja es **lógica**: el registro **no se elimina del archivo**, solo se pone el estado en `I`.

1. Si el cliente **ya está inactivo**: `El cliente ya esta inactivo.` y `Use la opcion M para reactivarlo.`. No se hace nada más.
2. Si el **saldo es distinto de cero**, se rechaza (`No se puede dar de baja: el saldo es distinto de cero. Extraiga el saldo.`). Es una decisión de diseño: un cliente inactivo no puede extraer, así que dar de baja con saldo dejaría dinero inaccesible. Para dar de baja hay que dejar el saldo en cero (extracción, o modificándolo con `M` → saldo).
3. Pide confirmación: `Confirma la baja? (S/N):`. Solo `S` o `s` confirman; cualquier otra respuesta cancela (`Baja cancelada.`).
4. Al confirmar: estado `I`, `REWRITE` del registro, mensaje `Cliente dado de baja (estado Inactivo).` y se muestran los **datos actualizados** (con `Estado: I - Inactivo`). Luego se vuelve al menú principal.

#### Retorno al menú principal

Tanto la modificación (al elegir `4 - Terminar modificacion`) como la baja y la reactivación terminan mostrando los datos actualizados del cliente y **volviendo directamente al menú principal**. El único submenú que se repite es el de campos a modificar (`1`-`4`), y solo mientras se sigue eligiendo `1`, `2` o `3`; en cuanto se elige `4` no queda ningún submenú abierto.

### Depósito y extracción (opciones 3 y 4)

Flujo: DNI → búsqueda → **verificación de estado** → monto → operación.

- Cliente inexistente: `Cliente no encontrado.`
- Cliente inactivo (`I`): `Cliente inactivo: no se puede operar.` (no se pide el monto).
- Cliente activo (`A`) o reactivado (`R`): la operación continúa.
- Monto: mayor a cero, hasta 2 decimales.
- Depósito: el saldo resultante no puede desbordar el campo (`El saldo excede el maximo.`).
- Extracción: el monto no puede superar el saldo (`Saldo insuficiente.`).
- Si todo es válido, se graba y se muestra `Saldo actual: ...`.

<a id="plazo-fijo"></a>
### Plazo fijo (opción 7)

Permite **constituir** un plazo fijo para un cliente existente, **cancelarlo en forma anticipada** y **consultarlo**. Los plazos fijos se guardan en `plazofijo.dat` (ver [Persistencia](#persistencia-plazofijo)) y la tasa sale de la tabla de [Intereses (opción 8)](#intereses). No hay "modificación": como en un banco real, se cancela y se constituye otro. Los **vencimientos** (acreditar capital + interés al llegar la fecha) los procesa el batch de cierre (ver [Vencimientos de plazo fijo](#vencimientos-de-plazo-fijo-etapa-3)).

```
  ======================================
               PLAZO FIJO
  ======================================

  Fecha de proceso: 15/10/2026

     1 - Alta
     2 - Cancelacion anticipada
     3 - Consulta

     4 - Volver

  Opcion:
```

**1 - Alta.**

1. Pide el **DNI**. Si no existe: `Cliente no encontrado.`; si está inactivo (`I`): `Cliente inactivo: no se puede operar.` (igual que depósito y extracción). En los dos casos vuelve al submenú.
2. Pide la **moneda** (`P` o `D`), el **monto** y los **días** (30, 60, 90 o 120). Cada dato inválido se informa y **se vuelve a pedir**. El monto mínimo es **1.000.000 en pesos** y **500 en dólares**; el monto igual al mínimo se acepta.
3. Busca la **tasa** de esa moneda y plazo en `intereses.dat` y decide cuál aplicar:

   | Situación de la tasa | Qué hace |
   |----------------------|----------|
   | No existe o está dada de baja (`B`) | `No hay una tasa activa para esa moneda y plazo. No se constituyo el plazo fijo.` |
   | Fecha de proceso igual o posterior a `Vigente desde` | Usa la `TNA` |
   | Antes de `Vigente desde`, con `TNA anterior` mayor que 0 | Usa la `TNA anterior` (la que regía antes del último cambio) |
   | Antes de `Vigente desde`, con `TNA anterior` en 0 (tasa recién dada de alta o reactivada) | `No hay una tasa vigente para esa moneda y plazo: la tasa rige desde DD/MM/AAAA.` y no constituye |

4. Calcula y muestra TNA, interés, total y vencimiento, y pregunta `Confirma el alta del plazo fijo? (S/N):`.
5. Con `S`: asigna el número, graba y muestra el comprobante. Con cualquier otra respuesta: `Alta cancelada: no se grabo nada.` y vuelve al submenú. **No se limpia la pantalla** (la especificación lo pedía): hacerlo en GnuCOBOL requiere códigos de escape de la terminal, que quedarían como caracteres invisibles en los `esperado_*.txt` de las pruebas.

```
TNA:           40.00 %
Interes:               32,876.71
Total:              1,032,876.71
Vencimiento:   14/11/2026

Confirma el alta del plazo fijo? (S/N): S
Plazo fijo constituido. Comprobante:
Numero:        000001
DNI:           12345678
Moneda:        P - Pesos
Monto:              1,000,000.00
Dias:          30
TNA:           40.00 %
Interes:               32,876.71
Total:              1,032,876.71
Fecha de alta: 15/10/2026
Vencimiento:   14/11/2026
Estado:        A - Activo
```

**Cálculo.** `INTERES = MONTO x TNA / 100 x DIAS / 365` (TNA proporcional a los días), redondeado al centavo con `ROUNDED` (medio centavo hacia arriba). En el programa las dos divisiones se hacen juntas al final (`MONTO * TNA * DIAS / 36500`) para no perder decimales en un paso intermedio. `TOTAL = MONTO + INTERES`. `Vencimiento = fecha de alta + días` (con `INTEGER-OF-DATE` / `DATE-OF-INTEGER`; no se corre a un día hábil). La fecha de alta es la fecha de proceso (no se tipea).

Ejemplo: 1.000.000 al 40% por 30 días → 1.000.000 × 40 × 30 / 36500 = 32.876,712 → **32,876.71**; total **1,032,876.71**.

**Número de plazo fijo.** Es correlativo y automático: el último grabado + 1 (el primero es `000001`). Se calcula **después** de la confirmación, recorriendo `plazofijo.dat` en orden (`START` + `READ NEXT`): como el archivo está ordenado por número, el último que se lee es el mayor. No se usa un registro de control (que todo programa que lea el archivo tendría que saltear) ni `START ... LAST` / `READ PREVIOUS` (no hay garantía de que funcionen igual en GnuCOBOL 2.0 y 3.x).

**El saldo del cliente no cambia.** Ni el alta ni la cancelación tocan `CLI-SALDO`: el dinero entra y sale por caja. Además, las cuentas no tienen moneda y hay plazos fijos en dólares.

**2 - Cancelación anticipada.** Pide el número y muestra el plazo fijo. Solo se puede cancelar uno en estado `A` **que todavía no venció**:

- `C`: `El plazo fijo ya esta cancelado.`
- `V`: `El plazo fijo ya vencio y fue acreditado.`
- Fecha de proceso igual o posterior al vencimiento: `El plazo fijo ya vencio: no se puede cancelar. Se acredita en el proceso de cierre.` (ya no sería "anticipada").
- Si no: pide `Confirma la cancelacion anticipada? (S/N):`. Con `S` pasa a estado `C` y muestra `Capital a devolver: ... (sin intereses)`: en la cancelación anticipada se devuelve **solo el capital**. Con otra respuesta: `Cancelacion no realizada.`.

**3 - Consulta.** Pide el número y muestra todos los datos del plazo fijo, incluido el estado (`A - Activo`, `C - Cancelado`, `V - Vencido y acreditado`). Por ahora es solo por número (el listado por DNI quedó como mejora futura).

**Número de plazo fijo (cancelación y consulta).** De 1 a 6 dígitos y mayor que 0: se acepta `1` o `000001`. Si no es válido: `Numero invalido: de 1 a 6 digitos, mayor que 0.` y vuelve al submenú (como un DNI inválido). Si no existe: `No existe un plazo fijo con ese numero.`.

<a id="intereses"></a>
### Intereses (opción 8)

Administra la **tabla de tasas** que usa el Plazo Fijo: una TNA (tasa nominal anual, en porcentaje) para cada combinación de **moneda** (`P` = pesos, `D` = dólares) y **plazo** (30, 60, 90 o 120 días). Las tasas se guardan en `intereses.dat` (ver [Persistencia](#persistencia-intereses)).

```
  ======================================
                INTERESES
  ======================================

  Fecha de proceso: 14/10/2026

     1 - Alta
     2 - Modificacion
     3 - Baja

     4 - Volver

  Opcion:
```

Cada operación pide primero la **moneda** y los **días**. Si un dato es inválido, avisa y **lo vuelve a pedir** (no cancela la operación). Al terminar, muestra la tasa completa:

```
Moneda:        P - Pesos
Dias:          30
TNA:           45.50 %
TNA anterior:  0.00 %
Vigente desde: 15/10/2026
Estado:        A - Activa
```

- **1 - Alta.** Si la combinación ya existe y está activa: `Ya existe una tasa activa para esa moneda y plazo. No se modifico nada.` (no pide la TNA). Si existe pero está dada de baja (`B`), **la reactiva** con la TNA nueva y avisa `Tasa reactivada (estaba dada de baja).`. En el alta y en la reactivación: `TNA anterior` = 0 y `Vigente desde` = próximo día hábil.
- **2 - Modificación.** Muestra la tasa actual y pide la TNA nueva. Si la TNA actual **ya está vigente** (fecha de proceso igual o posterior a `Vigente desde`), pasa a `TNA anterior`. Si en cambio había un cambio **pendiente** (todavía no vigente), `TNA anterior` no se toca: sigue guardando la tasa que rige hoy. La TNA nueva rige desde el próximo día hábil. Una tasa dada de baja no se puede modificar (`Use la opcion 1 - Alta para reactivarla.`).
- **3 - Baja.** Baja lógica: pone el estado en `B` y **rige de inmediato**. El registro no se borra y no pide confirmación.
- **4 - Volver.** Vuelve al menú principal.

#### Próximo día hábil

Toda tasa que se carga o modifica rige desde el **próximo día hábil** (lunes a viernes; **no se consideran feriados**):

| Fecha de proceso | Vigente desde |
|------------------|---------------|
| lunes a jueves | el día siguiente |
| viernes | el lunes siguiente (+3) |
| sábado | el lunes siguiente (+2) |
| domingo | el lunes siguiente (+1) |

Cómo lo calcula el programa (`8060-CALCULAR-PROX-HABIL`):

1. `FUNCTION INTEGER-OF-DATE(fecha)` convierte la fecha `AAAAMMDD` en un número de día. El día 1 es el 01/01/1601, que fue **lunes**.
2. `FUNCTION MOD(número, 7)` da el resto de dividir por 7, que es el día de la semana: 1 = lunes … 5 = viernes, 6 = sábado, 0 = domingo.
3. Según ese resto se suma 1, 2 o 3 días al número.
4. `FUNCTION DATE-OF-INTEGER` convierte el número de vuelta a `AAAAMMDD`.

#### Fecha de proceso y la variable `FECHA_PROCESO`

La "fecha de hoy" para el programa es la **fecha del sistema**, salvo que exista la variable de entorno **`FECHA_PROCESO`** con una fecha `AAAAMMDD`; en ese caso se usa esa. Sirve para que las pruebas usen siempre la misma fecha: si no, el resultado (`Vigente desde`) cambiaría según el día en que se corran. Se muestra en el submenú (`Fecha de proceso: DD/MM/AAAA`).

```bat
REM Windows (cmd), desde bin\
set FECHA_PROCESO=20261016
gestion-bancaria.exe
set FECHA_PROCESO=
```

```bash
# Linux / Docker
FECHA_PROCESO=20261016 ./gestion-bancaria.exe
```

Si `FECHA_PROCESO` existe pero no es una fecha válida, el programa avisa (`FECHA_PROCESO invalida (use AAAAMMDD):` / `se usa la fecha del sistema.`) y usa la del sistema.

El batch de cierre usa la misma variable, con una diferencia: si la fecha es inválida, **no se ejecuta** (ver [Proceso batch de cierre](#proceso-batch-cierre)).

<a id="validaciones-cuenta"></a>
### Validaciones

| Dato | Reglas |
|------|--------|
| **Opción del menú principal** | `1`–`10` o `0`; cualquier otro valor: `Opcion invalida.` |
| **Opción del submenú Intereses / Plazo fijo** | `1`–`4`; cualquier otro valor: `Opcion invalida.` |
| **Moneda** (Intereses y Plazo fijo) | `P` o `D`, en mayúscula o minúscula; si no: `Moneda invalida: ingrese P o D.` y la vuelve a pedir |
| **Días** (Intereses y Plazo fijo) | `30`, `60`, `90` o `120`; si no: `Dias invalidos: ingrese 30, 60, 90 o 120.` y los vuelve a pedir |
| **Monto** (Plazo fijo) | No vacío, numérico, mayor que 0, hasta 2 decimales (más decimales **se rechazan**) y no menor que el mínimo (`1,000,000.00` en pesos, `500.00` en dólares; el mínimo se acepta). Si no, avisa el motivo y lo vuelve a pedir |
| **Número de plazo fijo** | De 1 a 6 dígitos, mayor que 0; si no: `Numero invalido: de 1 a 6 digitos, mayor que 0.` y vuelve al submenú |
| **Respuesta S/N** (alta y cancelación de plazo fijo) | `S` o `s` = sí; cualquier otra = no |
| **TNA** (Intereses) | No vacía, numérica, mayor que 0, hasta `999.99` y con hasta 2 decimales (más decimales **se rechazan**, no se truncan); el punto decimal es `.`. Si no, avisa el motivo y la vuelve a pedir |
| **Respuesta Modificar / Baja** | `M`, `m`, `B` o `b`; cualquier otra: `Opcion invalida: use M o B.` |
| **Opción del submenú de modificación** | `1`–`4`; cualquier otro valor: `Opcion invalida.` |
| **Respuesta S/N** (confirmación de baja) | `S` o `s` = sí; cualquier otra = no |
| **DNI** | Exactamente 8 dígitos. Alta: no debe existir. Resto de operaciones: debe existir (`Cliente no encontrado.`) |
| **Nombre** (solo alta) | Obligatorio, hasta 30 caracteres |
| **Dirección** | Obligatoria, hasta 40 caracteres |
| **Teléfono** | Obligatorio, hasta 15 caracteres; solo dígitos, `+`, `-`, `(`, `)` y espacios; al menos 6 dígitos |
| **Saldo nuevo** (modificación) | Un número válido (`abc` se rechaza), no vacío, **cero o mayor** (no negativo), dentro del rango del campo; más de 2 decimales se truncan |
| **Monto** (depósito / extracción) | Mayor a cero; hasta 2 decimales (más decimales se truncan); el punto decimal es `.` |
| **Estado del cliente en depósito / extracción** | Debe ser `A` o `R`; con `I` (o un valor desconocido) se bloquea |
| **Estado del cliente en `M`** | `I` → solo reactivación; `A` o `R` → modificación de dirección / teléfono / saldo |
| **Estado del cliente en `B`** | No debe estar ya inactivo; saldo en cero; confirmación explícita |

Los textos se recortan (`FUNCTION TRIM`): se descartan los espacios al principio y al final. Para detectar que se excedió el largo, se lee cada texto en un campo de trabajo de 80 caracteres y se compara el largo real; un `ACCEPT` directo al campo final truncaría sin avisar.

El monto de un depósito/extracción y el saldo nuevo se validan distinto a propósito: el monto debe ser mayor a cero (por eso `NUMVAL` devolviendo 0 para un texto inválido alcanza), pero el saldo nuevo puede ser `0`, así que se usa `FUNCTION TEST-NUMVAL` para distinguir el número `0` de un texto que no es un número.

#### Ejemplo de sesión

Lo que tipea el usuario va siempre en la misma línea del prompt, después de los dos puntos: el número al lado de `Opcion:`, el `12345678` al lado de `DNI (8 digitos):`, `Ana Perez` al lado de `Nombre (hasta 30 caracteres):`, etc.

```
  ======================================
             GESTION BANCARIA
  ======================================

     1 - Alta de cliente
     2 - Modificar / Baja de cliente
     3 - Deposito
     4 - Extraccion
     5 - Consulta de saldo
     6 - Cuenta corriente / Caja de ahorro
     7 - Plazo fijo
     8 - Intereses
     9 - Historial de movimientos
    10 - Pago de servicios

     0 - Salir

  Opcion: 1
DNI (8 digitos): 12345678
Nombre (hasta 30 caracteres): Ana Perez
Direccion (hasta 40 caracteres): Calle 1
Telefono (hasta 15 caracteres): 011 4444-5555
Cliente dado de alta.

  ======================================      <- vuelve al menu principal
             GESTION BANCARIA
  ======================================
     (... mismas opciones de arriba ...)
  Opcion: 2
DNI (8 digitos): 12345678
Nombre:    Ana Perez
DNI:       12345678
Direccion: Calle 1
Telefono:  011 4444-5555
Saldo:                0.00
Estado:    A - Activo
Desea (M)odificar o (B)aja el cliente? B
Confirma la baja? (S/N): S
Cliente dado de baja (estado Inactivo).

Datos actualizados del cliente:
Nombre:    Ana Perez
DNI:       12345678
Direccion: Calle 1
Telefono:  011 4444-5555
Saldo:                0.00
Estado:    I - Inactivo

  ======================================      <- vuelve al menu principal
             GESTION BANCARIA
  ======================================
     (... mismas opciones de arriba ...)
  Opcion: 3
DNI (8 digitos): 12345678
Cliente inactivo: no se puede operar.

  ======================================      <- vuelve al menu principal
             GESTION BANCARIA
  ======================================
     (... mismas opciones de arriba ...)
  Opcion: 2
DNI (8 digitos): 12345678
   (... muestra los datos, Estado: I - Inactivo ...)
Desea (M)odificar o (B)aja el cliente? M
Cliente reactivado (estado R).

Datos actualizados del cliente:
Nombre:    Ana Perez
DNI:       12345678
Direccion: Calle 1
Telefono:  011 4444-5555
Saldo:                0.00
Estado:    R - Reactivado

  ======================================      <- vuelve al menu principal
             GESTION BANCARIA
  ======================================
     (... mismas opciones de arriba ...)
  Opcion:
```

### Persistencia

Los clientes se guardan en `clientes_v3.dat`, un archivo indexado (`ORGANIZATION IS INDEXED`) con el DNI como clave (`RECORD KEY IS CLI-DNI`). Ventajas frente a una tabla en memoria: los datos sobreviven entre ejecuciones, no hay tope fijo de clientes, el acceso por DNI es directo y el archivo rechaza claves duplicadas.

Declaración en `FILE-CONTROL`:

```cobol
SELECT ARCH-CLIENTES ASSIGN TO "clientes_v3.dat"
    ORGANIZATION IS INDEXED
    ACCESS MODE IS RANDOM
    RECORD KEY IS CLI-DNI
    FILE STATUS IS WS-FS.
```

#### Registro (`REG-CLIENTE`, 105 bytes)

| Campo | PIC | Bytes | Nota |
|-------|-----|-------|------|
| `CLI-DNI` | `9(8)` | 8 | **Clave primaria** |
| `CLI-NOMBRE` | `X(30)` | 30 | |
| `CLI-DIRECCION` | `X(40)` | 40 | |
| `CLI-TELEFONO` | `X(15)` | 15 | |
| `CLI-SALDO` | `S9(9)V99` | 11 | Con signo, 2 decimales implícitos |
| `CLI-ESTADO` | `X` | 1 | `A` / `I` / `R`. Niveles 88 `CLIENTE-ACTIVO`, `CLIENTE-INACTIVO`, `CLIENTE-REACTIVADO` |

#### Por qué el archivo se llama `clientes_v3.dat`

Se comprobó que **GnuCOBOL 2.0 no verifica el largo del registro al abrir un archivo indexado**: abrir un archivo con un formato anterior *no da error* y los datos se leen corridos/como basura, con riesgo de corromperlos si luego se escribe. Por eso cada cambio de layout usa un nombre de archivo nuevo:

| Versión | Archivo | Registro |
|---------|---------|----------|
| 1 | `clientes.dat` | 51 bytes (DNI, nombre, saldo) |
| 2 | `clientes_v2.dat` | 104 bytes (+ dirección, teléfono) |
| 3 (actual) | `clientes_v3.dat` | 105 bytes (+ estado) |

- Los archivos de versiones anteriores **quedan intactos y se ignoran**.
- **Los clientes cargados en versiones anteriores no se migran**: hay que volver a darlos de alta. No se incluye un programa de migración (ver [Limitaciones y mejoras futuras](#limitaciones-y-mejoras)).
- Si se vuelve a cambiar el layout del registro, hay que cambiar de nuevo el nombre (`_v4`, …) o migrar los datos.
- **Agregar el valor `R` al estado no cambió el layout** (sigue siendo 1 carácter), así que los clientes ya cargados en `clientes_v3.dat` (estados `A` / `I`) siguen siendo válidos.

#### Ciclo de vida del archivo

1. **Apertura (`0100-ABRIR-ARCHIVO`).** `OPEN I-O`. Si no existe (`FILE STATUS` `35`), se crea con `OPEN OUTPUT`, se cierra y se reabre en `I-O`. Cada paso se verifica por separado.
2. **Búsqueda (`8000-BUSCAR-CLIENTE`).** Mueve el DNI a `CLI-DNI` y hace `READ ... KEY IS CLI-DNI`. Si existe, el registro queda en `REG-CLIENTE` y se activa `CLIENTE-ENCONTRADO`; si no, `INVALID KEY` (estado `23`) activa `CLIENTE-NO-ENC`.
3. **Alta.** `WRITE REG-CLIENTE` con saldo 0 y estado `A`. Una clave duplicada (`22`) se informa como "Ya existe un cliente con ese DNI".
4. **Depósito, extracción, modificación, baja y reactivación.** Se modifican los campos en el buffer del registro y se graba con `REWRITE` (`8400-ACTUALIZAR-CLIENTE`), solo si la operación fue válida. La baja es un `REWRITE` con `CLI-ESTADO = "I"` y la reactivación uno con `"R"`: **el programa no usa `DELETE`**.
5. **Cierre (`0200-CERRAR-ARCHIVO`).** `CLOSE` al elegir la opción 0.

Todo `FILE STATUS` inesperado pasa por `9000-ERROR-ARCHIVO`, que muestra la operación en curso (`OPEN I-O`, `READ`, `WRITE`, `REWRITE`, `CLOSE`), el código y su significado, cierra el archivo y termina con `RETURN-CODE` 1:

| Status | Significado | Qué hacer |
|--------|-------------|-----------|
| `30` | Archivo ilegible o corrupto | Borrar `clientes_v3.dat` |
| `35` | No existe (se maneja solo: se crea) | – |
| `37` | Sin permisos | Revisar permisos de la carpeta/archivo |
| `39` | Formato incompatible | Borrar `clientes_v3.dat` |
| `41` / `42` | Archivo ya abierto / no abierto | Error de lógica |
| `61` | En uso por otro programa | Cerrar la otra instancia |

#### Notas prácticas

- El archivo se busca **en el directorio actual** (el directorio de trabajo desde donde se ejecuta el programa, no donde está el `.exe` ni el código fuente). En este proyecto ese lugar es siempre `bin\` — ver «Dónde vive `clientes_v3.dat`», en [Compilación y ejecución](#compilacion-y-ejecucion). Si el ejecutable se corre desde otra carpeta, se crea o lee un `clientes_v3.dat` **distinto** ahí, sin ningún aviso.
- Según cómo esté compilado GnuCOBOL, puede generarse un archivo de índice auxiliar junto al `.dat`; deben conservarse juntos.
- Para empezar de cero, borrar `clientes_v3.dat`.
- El formato es binario y depende del manejador de archivos de GnuCOBOL: no es legible ni necesariamente portable a otro compilador.
- No hay bloqueo de registros: pensado para un solo usuario a la vez.

<a id="persistencia-intereses"></a>
#### Archivo de tasas: `intereses.dat`

Sigue el mismo patrón que `clientes_v3.dat`: archivo indexado, nombre sin carpeta (así queda en `bin\`, junto a `clientes_v3.dat`), y si no existe se crea vacío al arrancar (`0150-ABRIR-INTERESES`, igual que `0100-ABRIR-ARCHIVO`). El layout está en el copybook `INTERES.cpy`, como el de clientes está en `CLIENTE.cpy`, para que otro programa (por ejemplo, el futuro Plazo Fijo) lo lea con exactamente el mismo formato.

```cobol
SELECT ARCH-INTERESES ASSIGN TO "intereses.dat"
    ORGANIZATION IS INDEXED
    ACCESS MODE IS RANDOM
    RECORD KEY IS INT-CLAVE
    FILE STATUS IS WS-FS.
```

Registro `REG-INTERES` (23 bytes). La clave `INT-CLAVE` es un grupo formado por moneda + días, así que no puede haber dos tasas para la misma combinación:

| Campo | PIC | Bytes | Nota |
|-------|-----|-------|------|
| `INT-MONEDA` | `X` | 1 | **Clave** (1ra parte). `P` = pesos, `D` = dólares. Niveles 88 `MONEDA-PESOS`, `MONEDA-DOLARES` |
| `INT-DIAS` | `9(3)` | 3 | **Clave** (2da parte). 30, 60, 90 o 120 |
| `INT-TNA` | `9(3)V99` | 5 | Tasa nominal anual en %, mayor que 0 |
| `INT-TNA-ANTERIOR` | `9(3)V99` | 5 | Tasa que regía antes del último cambio; cero en un alta nueva o en una reactivación |
| `INT-VIGENTE-DESDE` | `9(8)` | 8 | `AAAAMMDD`: fecha desde la cual rige `INT-TNA` |
| `INT-ESTADO` | `X` | 1 | `A` = activa, `B` = baja lógica. Niveles 88 `TASA-ACTIVA`, `TASA-BAJA` |

Los errores de archivo pasan por el mismo `9000-ERROR-ARCHIVO`, que informa **cuál** de los archivos falló (`WS-ARCHIVO`). Para empezar la tabla de tasas de cero, borrar `bin\intereses.dat` (no afecta a los clientes).

<a id="persistencia-plazofijo"></a>
#### Archivo de plazos fijos: `plazofijo.dat`

Mismo patrón que los otros dos: archivo indexado en `bin\`, que se crea vacío al arrancar si no existe (`0170-ABRIR-PLAZOFIJO`). El layout está en el copybook `PLAZOFIJO.cpy`, para que en la Etapa 3 el batch de cierre lo lea con exactamente el mismo formato. La diferencia es el **acceso dinámico** (`ACCESS MODE IS DYNAMIC`): además de leer un plazo fijo por su número (`READ ... KEY IS PF-NRO`), para asignar el número de uno nuevo se recorre el archivo en orden (`START` + `READ NEXT`), y eso no se puede hacer con `ACCESS MODE IS RANDOM`. El fin de esa lectura en orden es el `FILE STATUS` `10` (88 `FS-FIN-ARCHIVO`).

```cobol
SELECT ARCH-PLAZOFIJO ASSIGN TO "plazofijo.dat"
    ORGANIZATION IS INDEXED
    ACCESS MODE IS DYNAMIC
    RECORD KEY IS PF-NRO
    FILE STATUS IS WS-FS.
```

Registro `REG-PLAZOFIJO` (79 bytes):

| Campo | PIC | Bytes | Nota |
|-------|-----|-------|------|
| `PF-NRO` | `9(6)` | 6 | **Clave**. Número correlativo: último + 1 |
| `PF-DNI` | `9(8)` | 8 | Cliente titular (existe en `clientes_v3.dat`) |
| `PF-MONEDA` | `X` | 1 | `P` / `D`. Niveles 88 `PF-MONEDA-PESOS`, `PF-MONEDA-DOLARES` |
| `PF-MONTO` | `9(11)V99` | 13 | Capital constituido |
| `PF-DIAS` | `9(3)` | 3 | 30, 60, 90 o 120 |
| `PF-TNA-APLICADA` | `9(3)V99` | 5 | Copia de la TNA usada al alta: un cambio posterior en `intereses.dat` no altera el plazo fijo |
| `PF-INTERES` | `9(11)V99` | 13 | Calculado al alta |
| `PF-TOTAL` | `9(11)V99` | 13 | Monto + interés |
| `PF-FECHA-ALTA` | `9(8)` | 8 | `AAAAMMDD`: fecha de proceso del alta |
| `PF-FECHA-VENC` | `9(8)` | 8 | `AAAAMMDD`: alta + días |
| `PF-ESTADO` | `X` | 1 | `A` = activo, `C` = cancelado, `V` = vencido y acreditado (Etapa 3). Niveles 88 `PF-ACTIVO`, `PF-CANCELADO`, `PF-VENCIDO` |

Los plazos fijos no se borran nunca: la cancelación es un `REWRITE` con estado `C`. Para empezar de cero, borrar `bin\plazofijo.dat` (no afecta a clientes ni tasas).

### Estructura del programa

#### Divisiones

- **IDENTIFICATION DIVISION**: nombre del programa (`GESTION-BANCARIA`). Es lo único obligatorio. `AUTHOR` y `DATE-WRITTEN` están obsoletas (GnuCOBOL emite warning), por eso autor y fecha figuran en el comentario de cabecera.
- **ENVIRONMENT DIVISION**:
  - `SPECIAL-NAMES`: define la clase `CLASE-TELEFONO` (dígitos, `+`, `-`, `(`, `)` y espacio), usada para validar el teléfono con `IS NOT CLASE-TELEFONO`.
  - `INPUT-OUTPUT SECTION` / `FILE-CONTROL`: asocia `ARCH-CLIENTES` con `clientes_v3.dat` (indexado, clave `CLI-DNI`), `ARCH-INTERESES` con `intereses.dat` (indexado, clave `INT-CLAVE` = moneda + días) y `ARCH-PLAZOFIJO` con `plazofijo.dat` (indexado, acceso dinámico, clave `PF-NRO`).
- **DATA DIVISION**:
  - `FILE SECTION`: el registro `REG-CLIENTE`, incluido con `COPY CLIENTE.` desde `CLIENTE.cpy` (con el campo `CLI-ESTADO` y sus niveles 88) en vez de declararse ahí mismo, para compartir exactamente el mismo layout con `BATCH-CIERRE.cbl` (ver [Proceso batch de cierre](#proceso-batch-cierre)).
  - `WORKING-STORAGE SECTION`: el resto de las variables.
- **PROCEDURE DIVISION**: la lógica, organizada en párrafos.

#### Condiciones 88

| Variable | Condición | Valor | Significado |
|----------|-----------|-------|-------------|
| `WS-OPCION` | `OPC-ALTA` | `1` | Alta de cliente |
| | `OPC-MODIF-BAJA` | `2` | Modificar / Baja de cliente |
| | `OPC-DEPOSITO` | `3` | Depósito |
| | `OPC-EXTRACCION` | `4` | Extracción |
| | `OPC-CONSULTA` | `5` | Consulta de saldo |
| | `OPC-CTA-CTE-CAJA` | `6` | Cuenta corriente / Caja de ahorro (en desarrollo) |
| | `OPC-PLAZO-FIJO` | `7` | Plazo fijo |
| | `OPC-INTERESES` | `8` | Intereses |
| | `OPC-HISTORIAL` | `9` | Historial de movimientos (en desarrollo) |
| | `OPC-PAGO-SERVICIOS` | `10` | Pago de servicios (en desarrollo) |
| | `OPC-SALIR` | `0` | Salir |
| `WS-OPC-INT` | `OPI-ALTA` | `1` | Alta de tasa |
| | `OPI-MODIFICACION` | `2` | Modificación de tasa |
| | `OPI-BAJA` | `3` | Baja de tasa |
| | `OPI-VOLVER` | `4` | Volver al menú principal |
| `INT-MONEDA` (registro) | `MONEDA-PESOS` / `MONEDA-DOLARES` | `P` / `D` | Moneda de la tasa |
| `INT-ESTADO` (registro) | `TASA-ACTIVA` / `TASA-BAJA` | `A` / `B` | Estado de la tasa |
| `WS-TASA-ENC` | `TASA-ENCONTRADA` / `TASA-NO-ENC` | `S` / `N` | Resultado de buscar una tasa |
| `WS-OPC-PF` | `OPP-ALTA` | `1` | Alta de plazo fijo |
| | `OPP-CANCELACION` | `2` | Cancelación anticipada |
| | `OPP-CONSULTA` | `3` | Consulta de plazo fijo |
| | `OPP-VOLVER` | `4` | Volver al menú principal |
| `PF-MONEDA` (registro) | `PF-MONEDA-PESOS` / `PF-MONEDA-DOLARES` | `P` / `D` | Moneda del plazo fijo |
| `PF-ESTADO` (registro) | `PF-ACTIVO` / `PF-CANCELADO` / `PF-VENCIDO` | `A` / `C` / `V` | Estado del plazo fijo |
| `WS-TASA-VIG` | `TASA-VIGENTE` / `TASA-NO-VIGENTE` | `S` / `N` | Hay una tasa que se puede aplicar hoy a un plazo fijo |
| `WS-PF-ENC` | `PF-ENCONTRADO` / `PF-NO-ENC` | `S` / `N` | Resultado de buscar un plazo fijo |
| `WS-OPC-MB` | `MB-MODIFICAR` | `M`, `m` | Modificar (o reactivar) |
| | `MB-BAJA` | `B`, `b` | Baja |
| `WS-CONFIRMA` | `CONFIRMA-SI` | `S`, `s` | Confirma la baja de cliente, o el alta o la cancelación de un plazo fijo |
| `WS-OPC-MOD` | `MOD-DIRECCION` | `1` | Modificar dirección |
| | `MOD-TELEFONO` | `2` | Modificar teléfono |
| | `MOD-SALDO` | `3` | Modificar saldo |
| | `MOD-TERMINAR` | `4` | Terminar modificación |
| `CLI-ESTADO` (registro) | `CLIENTE-ACTIVO` | `A` | Cliente activo |
| | `CLIENTE-INACTIVO` | `I` | Cliente inactivo (baja lógica) |
| | `CLIENTE-REACTIVADO` | `R` | Cliente reactivado |

El submenú de campos usa `WS-OPC-MOD` con una diferencia respecto de una versión anterior del diseño: "Terminar" es la opción `4` (antes era `0`), para que coincida con el orden `1-Dirección, 2-Teléfono, 3-Saldo, 4-Terminar modificación`. No incluye `MOD-NOMBRE`, porque el nombre no se modifica.

#### Datos de trabajo (`WORKING-STORAGE`)

| Variable | PIC | Uso |
|----------|-----|-----|
| `WS-OPCION` | `X(2)` | Opción del menú principal (2 caracteres por la opción `10`) |
| `WS-OPC-INT` | `X` | Opción del submenú Intereses |
| `WS-OPC-PF` | `X` | Opción del submenú Plazo fijo |
| `WS-ARCHIVO` | `X(16)` | Archivo de la operación en curso (`clientes_v3.dat`, `intereses.dat` o `plazofijo.dat`), solo para informar errores |
| `WS-PF-MONTO` / `WS-PF-MONTO-CALC` | `9(11)V99` / `S9(11)V9(6)` | Monto del plazo fijo ya validado / tipeado con decimales de sobra, para detectar si tiene más de 2 (`WS-MONTO`, el de depósito y extracción, tiene solo 9 enteros) |
| `WS-PF-MINIMO` | `9(11)V99` | Monto mínimo según la moneda |
| `WS-TNA-USADA` | `9(3)V99` | TNA que se aplica al plazo fijo (`INT-TNA` o `INT-TNA-ANTERIOR`) |
| `WS-PF-INTERES`, `WS-PF-TOTAL`, `WS-PF-VENC` | `9(11)V99`, `9(11)V99`, `9(8)` | Interés, total y vencimiento calculados |
| `WS-PF-NRO-TXT`, `WS-PF-NRO`, `WS-PF-ULTIMO` | `X(10)`, `9(6)`, `9(6)` | Número de plazo fijo tipeado / ya validado / último grabado |
| `WS-IMPORTE-EDIT` | `ZZ,ZZZ,ZZZ,ZZ9.99` | Campo editado para mostrar importes de hasta 11 enteros (monto, interés, total) |
| `WS-MONEDA`, `WS-DIAS`, `WS-TNA` | `X`, `9(3)`, `9(3)V99` | Moneda, días y TNA ya validados |
| `WS-TNA-CALC` | `S9(5)V9(6)` | TNA tipeada con decimales de sobra, para detectar si tiene más de 2 |
| `WS-DIAS-EDIT`, `WS-TNA-EDIT` | `ZZ9`, `ZZ9.99` | Campos editados para mostrar días y TNA |
| `WS-FECHA-PROCESO` | `9(8)` | "Hoy" para el programa (`AAAAMMDD`): fecha del sistema o `FECHA_PROCESO` |
| `WS-PROX-HABIL` | `9(8)` | Próximo día hábil calculado |
| `WS-FECHA-INT`, `WS-DIA-SEMANA` | `9(7)`, `9` | Número de día (`INTEGER-OF-DATE`) y resto de dividirlo por 7 |
| `WS-FECHA-ENV`, `WS-FECHA-HORA` | `X(20)`, `X(21)` | Valor de `FECHA_PROCESO` y resultado de `FUNCTION CURRENT-DATE` |
| `WS-FECHA-AUX` / `WS-FECHA-EDIT` | `9(8)` / `X(10)` | Fecha a mostrar (`AAAAMMDD`, con `REDEFINES` en año/mes/día) y su versión `DD/MM/AAAA` |
| `WS-OPC-MB` | `X` | Respuesta a "Modificar o Baja" |
| `WS-CONFIRMA` | `X` | Respuesta S/N: confirmación de baja de cliente y de alta o cancelación de plazo fijo |
| `WS-OPC-MOD` | `X` | Opción del submenú de campos a modificar |
| `WS-CAMBIOS` | `9` | Cantidad de campos grabados en la sesión de modificación actual (decide el mensaje final) |
| `WS-FS` | `XX` | `FILE STATUS`; 88 `FS-OK` (`00`), `FS-FIN-ARCHIVO` (`10`), `FS-CLAVE-DUPLICADA` (`22`), `FS-CLAVE-NO-ENC` (`23`), `FS-NO-EXISTE` (`35`) |
| `WS-OPERACION` | `X(10)` | Operación de archivo en curso, solo para informar errores |
| `WS-DNI-TXT`, `WS-MONTO-TXT` | `X(8)`, `X(15)` | Entrada cruda de DNI y de monto / saldo, antes de validar |
| `WS-TEXTO` | `X(80)` | Entrada cruda de nombre, dirección y teléfono (permite detectar excesos de largo) |
| `WS-DNI`, `WS-MONTO`, `WS-SALDO-NUEVO` | `9(8)`, `S9(9)V99`, `S9(9)V99` | DNI, monto y saldo nuevo ya validados |
| `WS-NOMBRE`, `WS-DIRECCION`, `WS-TELEFONO` | `X(30)`, `X(40)`, `X(15)` | Textos validados, listos para copiar al registro |
| `WS-I`, `WS-CANT-DIG` | `99` | Índice y contador para contar los dígitos del teléfono |
| `WS-SALDO-EDIT` | `-ZZZ,ZZZ,ZZ9.99` | Campo editado para mostrar el saldo con formato |
| `WS-DNI-OK`, `WS-MONTO-OK`, `WS-CAMPO-OK` | `X` | Indicadores S/N: 88 `DNI-VALIDO`/`DNI-INVALIDO`, `MONTO-VALIDO`/`MONTO-INVALIDO`, `CAMPO-VALIDO`/`CAMPO-INVALIDO` |
| `WS-ENCONTRADO` | `X` | Resultado de la búsqueda: `CLIENTE-ENCONTRADO` / `CLIENTE-NO-ENC` |
| `WS-OPERABLE` | `X` | Resultado de la verificación de estado: `CLIENTE-OPERABLE` / `CLIENTE-NO-OPERABLE` |

#### Párrafos de la PROCEDURE DIVISION

| Párrafo | Responsabilidad |
|---------|-----------------|
| `0000-PRINCIPAL` | Abre los tres archivos, repite el menú hasta elegir salir, los cierra y ejecuta `STOP RUN` |
| `0100-ABRIR-ARCHIVO` / `0200-CERRAR-ARCHIVO` | Apertura (creándolo si no existe) y cierre de `clientes_v3.dat` |
| `0150-ABRIR-INTERESES` / `0250-CERRAR-INTERESES` | Lo mismo para `intereses.dat` |
| `0170-ABRIR-PLAZOFIJO` / `0270-CERRAR-PLAZOFIJO` | Lo mismo para `plazofijo.dat` |
| `1000-PROCESAR-MENU` | Lee la opción y despacha con `EVALUATE TRUE`. Al terminar cada operación se vuelve aquí y se muestra de nuevo el menú principal |
| `1100-MOSTRAR-MENU` | Imprime el menú principal |
| `2000-ALTA-CLIENTE` | Pide y valida el DNI; verifica que no exista |
| `2100-REGISTRAR-CLIENTE` | Pide nombre, dirección y teléfono; cancela el alta si alguno es inválido |
| `2200-GRABAR-CLIENTE` | Arma el registro (saldo 0, **estado A**) y hace `WRITE` |
| `2500-MODIFICAR-O-BAJA` | **Opción 2.** Pide el DNI, busca, muestra los datos y recién ahí llama a `2600` |
| `2600-ELEGIR-MODIF-O-BAJA` | Pregunta M/B y deriva a `6000-MODIFICACION` o `7000-BAJA-CLIENTE` |
| `3000-DEPOSITO` / `3100-PROCESAR-DEPOSITO` | Búsqueda + verificación de estado / pedido de monto y suma |
| `4000-EXTRACCION` / `4100-PROCESAR-EXTRACCION` | Búsqueda + verificación de estado / pedido de monto y resta |
| `5000-CONSULTA-SALDO` | Consulta: muestra todos los datos del cliente |
| `5100-PLAZO-FIJO` / `5110-MENU-PLAZO-FIJO` | **Opción 7.** Fija la fecha de proceso y repite el submenú Plazo fijo hasta elegir `4 - Volver` |
| `5200-ALTA-PF` | Pide el DNI, busca al cliente y verifica que esté activo (`8900`) |
| `5210-DATOS-PF` | Pide moneda, monto y días, busca la tasa, calcula y pide confirmación |
| `5220-PEDIR-MONTO-PF` / `5225-VALIDAR-MONTO-PF` | Pide el monto hasta que sea válido (numérico, mayor que 0, hasta 2 decimales, no menor que el mínimo) |
| `5230-BUSCAR-TASA-VIGENTE` | Busca la tasa y decide si se aplica `TNA`, `TNA anterior` o ninguna |
| `5240-CALCULAR-PF` | Interés (`ROUNDED`), total y vencimiento; si no entran en los campos, no constituye |
| `5250-MOSTRAR-CALCULO` | Muestra TNA, interés, total y vencimiento antes de confirmar |
| `5260-CONFIRMAR-ALTA-PF` | Pregunta S/N; con `S` llama a `5270`, con otra respuesta no graba |
| `5270-GRABAR-PF` | Asigna el número (último + 1), arma el registro (estado `A`), hace `WRITE` y muestra el comprobante |
| `5280-BUSCAR-ULTIMO-NRO` | `START` + `READ NEXT` hasta el fin del archivo; deja el número más alto en `WS-PF-ULTIMO` |
| `5300-CANCELAR-PF` / `5310-CONFIRMAR-CANCELACION` | Busca y muestra el plazo fijo, verifica estado y vencimiento / pide S/N, pone estado `C` (`REWRITE`) e informa el capital a devolver |
| `5400-CONSULTAR-PF` | Consulta por número |
| `5410-PEDIR-NRO-PF` | Lee y valida el número de plazo fijo (1 a 6 dígitos, mayor que 0) |
| `5420-BUSCAR-PF` | `READ` por clave (`PF-NRO`); marca encontrado / no encontrado |
| `5490-MOSTRAR-PF` | Muestra todos los datos del plazo fijo (comprobante, cancelación y consulta) |
| `5500-INTERESES` / `5510-MENU-INTERESES` | **Opción 8.** Fija la fecha de proceso y repite el submenú Intereses hasta elegir `4 - Volver` |
| `5600-ALTA-TASA` | Alta (o reactivación de una tasa en `B`); avisa si ya existe activa |
| `5700-MODIFICAR-TASA` | Cambia la TNA; decide si la actual pasa a `TNA anterior` según si ya estaba vigente |
| `5800-BAJA-TASA` | Baja lógica (estado `B`) |
| `5910-PEDIR-MONEDA` / `5920-PEDIR-DIAS` / `5930-PEDIR-TNA` / `5935-VALIDAR-TNA` | Piden y validan cada dato, y lo vuelven a pedir hasta que sea válido |
| `5940-BUSCAR-TASA` | `READ` por clave (moneda + días); marca encontrada / no encontrada |
| `5950-GRABAR-TASA-NUEVA` / `5955-ACTUALIZAR-TASA` | `WRITE` / `REWRITE` del registro de tasa |
| `5960-MOSTRAR-TASA` | Muestra moneda, días, TNA, TNA anterior, vigente desde y estado |
| `6000-MODIFICACION` | Decide según el estado: `I` → `6500-REACTIVAR-CLIENTE`; `A` o `R` → `6100-MODIFICAR-DATOS` |
| `6100-MODIFICAR-DATOS` | Repite el submenú de campos (`6150`) hasta elegir Terminar; al salir, informa si no hubo cambios y muestra los datos actualizados |
| `6150-MENU-CAMPO` | Muestra el submenú `1-Dirección / 2-Teléfono / 3-Saldo / 4-Terminar`, pide el dato elegido, lo valida y llama a `6200` si es válido |
| `6200-GRABAR-CAMBIO` | `REWRITE` inmediato del campo recién cambiado, suma 1 a `WS-CAMBIOS` y confirma `Dato modificado.` |
| `6500-REACTIVAR-CLIENTE` | Pone estado `R`, hace `REWRITE` y muestra los datos actualizados |
| `7000-BAJA-CLIENTE` | Verifica que no esté ya inactivo y que el saldo sea cero |
| `7100-CONFIRMAR-BAJA` | Pide confirmación, pone estado `I`, hace `REWRITE` y muestra los datos actualizados |
| `8000-BUSCAR-CLIENTE` | `READ` por clave (DNI); marca encontrado / no encontrado |
| `8050-FIJAR-FECHA-PROCESO` | Toma la fecha del sistema o, si existe y es válida, la de `FECHA_PROCESO` |
| `8060-CALCULAR-PROX-HABIL` | Calcula el próximo día hábil (lunes a viernes) con `INTEGER-OF-DATE`, `MOD 7` y `DATE-OF-INTEGER` |
| `8070-EDITAR-FECHA` | Pasa una fecha `AAAAMMDD` a `DD/MM/AAAA` para mostrarla |
| `8100-PEDIR-DNI` | Lectura y validación de DNI (`IS NUMERIC`, 8 dígitos) |
| `8200-PEDIR-MONTO` | Lectura de monto con `FUNCTION NUMVAL` y validación `> 0` |
| `8250-PEDIR-SALDO` / `8260-VALIDAR-SALDO-NUEVO` | Lectura del saldo nuevo con `TEST-NUMVAL` / validación de que no sea negativo |
| `8300-MOSTRAR-SALDO` | Muestra el saldo con el campo editado (depósito / extracción) |
| `8400-ACTUALIZAR-CLIENTE` | `REWRITE` del registro |
| `8500-PEDIR-NOMBRE` / `8600-PEDIR-DIRECCION` / `8700-PEDIR-TELEFONO` | Leen y validan cada texto (obligatorio, largo máximo) y lo dejan en `WS-NOMBRE` / `WS-DIRECCION` / `WS-TELEFONO` |
| `8710-VALIDAR-TELEFONO` | Verifica caracteres permitidos y mínimo de 6 dígitos |
| `8800-MOSTRAR-CLIENTE` | Muestra nombre, DNI, dirección, teléfono, saldo y estado (`A - Activo`, `I - Inactivo`, `R - Reactivado`) |
| `8900-VERIFICAR-ACTIVO` | Marca al cliente operable si su estado es `A` o `R`; si no, muestra `Cliente inactivo: no se puede operar.` |
| `9000-ERROR-ARCHIVO` | Informa operación, archivo, `FILE STATUS` y significado, cierra los tres archivos y termina |

Numeración de párrafos: 0xxx apertura/cierre, 1xxx menú, 2xxx–7xxx procesos de negocio, 8xxx rutinas compartidas, 9xxx manejo de errores. Los prefijos de los procesos no siguen el número de opción del menú: el alta es `2000` (opción 1); `3000`, `4000` y `5000` coinciden por casualidad con las opciones 3, 4 y 5; modificación (`6000`) y baja (`7000`) cuelgan ambas de la opción 2.

#### Flujo del menú

```
0000-PRINCIPAL
 └─ 1000-PROCESAR-MENU  (repite hasta OPC-SALIR; cada operacion vuelve aqui)
     ├─ 1 → 2000-ALTA-CLIENTE → 2100-REGISTRAR-CLIENTE → 2200-GRABAR-CLIENTE  (estado A)
     ├─ 2 → 2500-MODIFICAR-O-BAJA
     │        │   DNI → buscar → ¿existe? no: "Cliente no encontrado." / sí: mostrar datos
     │        └─ 2600-ELEGIR-MODIF-O-BAJA
     │             ├─ M → 6000-MODIFICACION
     │             │        ├─ estado I     → 6500-REACTIVAR-CLIENTE  (estado R)
     │             │        └─ estado A / R → 6100-MODIFICAR-DATOS
     │             │                            (6150: submenú 1-3 modifica y graba, 4 termina)
     │             └─ B → 7000-BAJA-CLIENTE
     │                      ├─ estado I → "El cliente ya esta inactivo."
     │                      └─ estado A / R → 7100-CONFIRMAR-BAJA  (estado I)
     │             (en todos los casos: mostrar datos actualizados y volver al menú principal)
     ├─ 3 → 3000-DEPOSITO    → buscar → 8900-VERIFICAR-ACTIVO → 3100-PROCESAR-DEPOSITO
     ├─ 4 → 4000-EXTRACCION  → buscar → 8900-VERIFICAR-ACTIVO → 4100-PROCESAR-EXTRACCION
     ├─ 5 → 5000-CONSULTA-SALDO
     ├─ 6, 9, 10 → "Opcion en desarrollo."
     ├─ 7 → 5100-PLAZO-FIJO → 5110-MENU-PLAZO-FIJO  (repite hasta 4 - Volver)
     │        ├─ 1 → 5200-ALTA-PF → 5210-DATOS-PF
     │        │        (moneda, monto, dias → 5230 tasa → 5240 calculo
     │        │         → 5260 S/N → 5270 numero + WRITE + comprobante)
     │        ├─ 2 → 5300-CANCELAR-PF → 5310-CONFIRMAR-CANCELACION  (estado C)
     │        └─ 3 → 5400-CONSULTAR-PF
     ├─ 8 → 5500-INTERESES → 5510-MENU-INTERESES  (repite hasta 4 - Volver)
     │        ├─ 1 → 5600-ALTA-TASA        (alta, o reactivacion si estaba en B)
     │        ├─ 2 → 5700-MODIFICAR-TASA   (TNA nueva desde el proximo dia habil)
     │        └─ 3 → 5800-BAJA-TASA        (estado B, de inmediato)
     └─ 0 → sale del bucle
```

#### Formato fijo: recordatorio de columnas

Aplica tanto a `gestion-bancaria.cbl` y `BATCH-CIERRE.cbl` como a `CLIENTE.cpy` (el `COPY` inserta el copybook tal cual, columna por columna, en el punto donde aparece `COPY CLIENTE.`).

| Columnas | Contenido |
|----------|-----------|
| 1–6 | Números de secuencia (no usados) |
| 7 | `*` = comentario |
| 8–11 | Área A: divisiones, secciones, párrafos, niveles 01 |
| 12–72 | Área B: sentencias y resto de las entradas |
| 73+ | Ignorado por el compilador (**una línea de más de 72 columnas se corta y no compila**) |

### Decisiones de diseño

- **Submenú de campos a modificar, con "Terminar" como última opción.** Un diseño intermedio (preguntas `S/N` por cada dato, una sola pasada) se reemplazó por pedido explícito: un submenú numerado (`1-Dirección, 2-Teléfono, 3-Saldo, 4-Terminar modificación`) que se repite hasta elegir Terminar, permitiendo modificar uno, varios o los tres campos, en el orden que se quiera.
- **`REWRITE` inmediato por campo, no acumulado.** Cada campo válido se graba apenas se confirma, en vez de acumular cambios en memoria para un único `REWRITE` al final. Así el contador de cambios (`WS-CAMBIOS`) solo refleja grabaciones que realmente ocurrieron, y una interrupción a mitad del submenú no pierde los campos ya grabados.
- **Reactivación directa, sin confirmación.** Por pedido: un cliente inactivo elige `M` y pasa a `R` sin más preguntas, sin ofrecer editar otros datos. Es una operación reversible (se puede volver a dar de baja).
- **`R` se comporta como `A` para operar.** La única diferencia es informativa: `R` deja constancia de que el cliente estuvo dado de baja. Depósito y extracción se bloquean solo con `I`.
- **Baja lógica.** Marcar `I` en vez de borrar conserva la información del cliente y evita perder datos por error. El DNI de un cliente dado de baja sigue ocupado (no se puede repetir en un alta), pero el cliente se puede reactivar.
- **Reglas de la baja.** Confirmación `S/N`, saldo en cero y cliente no inactivo. El rechazo por saldo evita dejar dinero inaccesible, porque un cliente inactivo no puede extraer.
- **Orden de la opción 2: DNI → datos → M/B.** El usuario ve el cliente antes de decidir qué hacer con él, y un DNI inexistente se detecta antes de preguntar nada más.
- **El nombre no se ofrece para modificar.** No hay una opción para elegirlo, en lugar de ofrecerlo y rechazarlo.
- **Verificación de estado antes de pedir el monto.** Evita que el usuario ingrese datos para una operación que no se va a poder hacer. Un estado desconocido también se bloquea, por seguridad.
- **Mensaje único `Cliente no encontrado.`** en todas las operaciones.
- **Respuesta inválida en el paso M/B.** Se informa y se vuelve al menú principal, igual que ante un dato inválido en cualquier otra operación (no se re-pregunta).
- **Mensajes solo en ASCII.** El texto `¿Desea (M)odificar o (B)aja el cliente?` se muestra sin `¿` ni acentos (`Desea (M)odificar o (B)aja el cliente?`), igual que el resto de los mensajes: según la página de códigos de la consola de Windows, los caracteres no ASCII pueden verse mal.
- **Entrada como texto y validación explícita.** Todo se lee en campos alfanuméricos y se convierte después, para que un dato inválido nunca deje basura en un campo numérico o en el registro.
- **Alta atómica.** Los campos se validan antes de grabar; si uno falla, no se escribe nada.
- **Aritmética decimal.** `PIC S9(9)V99` usa decimales exactos (sin errores de punto flotante), lo habitual para dinero en COBOL. `ADD ... ON SIZE ERROR` y `COMPUTE ... ON SIZE ERROR` evitan truncamientos silenciosos.
- **`FILE STATUS` en todas las operaciones de E/S.** Se distinguen los casos esperados (clave no encontrada, duplicada, archivo inexistente) de los errores reales, que terminan el programa con un mensaje claro.
- **Prompts y `WITH NO ADVANCING`.** Todos los prompts (los `Opcion:` de los menús y los de datos: DNI, nombre, monto, moneda, etc.) usan `DISPLAY "texto: " WITH NO ADVANCING`, así que el dato se tipea en la misma línea, después de los dos puntos y un espacio. Se probaron en la terminal web (`webterm-demo`, Docker sobre Ubuntu) y en una pseudo-terminal de Linux, y el prompt se ve antes de tipear. Fuera de una consola real el texto podría no mostrarse mientras se espera la entrada (ver [Solución de problemas](#solucion-de-problemas)). En las pruebas automáticas, como la entrada viene de un archivo, lo tipeado no aparece en la salida y los prompts quedan seguidos en una misma línea de los `esperado_*.txt` (por ejemplo `DNI (8 digitos): Nombre (hasta 30 caracteres): ...`).
- **Archivo con versión en el nombre** (`_v3`), por los cambios de layout (ver «Por qué el archivo se llama `clientes_v3.dat`», en Persistencia).
- **Intereses: los datos inválidos se vuelven a pedir.** A diferencia del alta de clientes (que cancela al primer error), en Intereses un dato inválido se informa y se vuelve a pedir, como pide la especificación de la Etapa 1.
- **Intereses: alta duplicada sin pedir la TNA.** Si la combinación ya existe y está activa, se avisa apenas se ingresan moneda y días, para no hacer tipear una TNA que no se va a usar.
- **Intereses: se muestra la tasa completa después de cada operación** (incluidos `TNA anterior` y `Vigente desde`), para que el usuario vea cuándo entra en vigencia el cambio y para que las pruebas lo puedan verificar.
- **Intereses: la TNA con más de 2 decimales se rechaza** (en el monto y el saldo se truncan): para una tasa, perder decimales sin avisar cambiaría el valor cargado.
- **`FECHA_PROCESO`.** Fijar la fecha con una variable de entorno permite probar cualquier día de la semana sin tocar el reloj de la máquina ni el código.
- **Plazo fijo: el saldo del cliente no se toca.** El alta y la cancelación solo registran el plazo fijo; el dinero entra y sale por caja. Las cuentas no tienen moneda y hay plazos fijos en dólares, así que debitar el saldo no tendría sentido para esos casos.
- **Plazo fijo: número correlativo leyendo el archivo hasta el final.** Sin registro de control (que todos los programas que lean el archivo tendrían que saltear, incluido el batch de la Etapa 3) y sin `START ... LAST` / `READ PREVIOUS` (comportamiento distinto entre GnuCOBOL 2.0 y 3.x). Cuesta leer todo el archivo en cada alta, que para este proyecto no es un problema.
- **Plazo fijo: cliente inactivo bloqueado**, igual que en depósito y extracción (la especificación solo pedía que el cliente existiera).
- **Plazo fijo: no se cancela en la fecha de vencimiento ni después.** Ya no sería "anticipada": el vencimiento lo acredita el batch de cierre (Etapa 3).
- **Plazo fijo: el monto con más de 2 decimales se rechaza**, como la TNA (en depósito, extracción y saldo se truncan).
- **Plazo fijo: importes con el formato del programa** (`1,032,876.71`, punto decimal), igual que el saldo y que el monto que se tipea, y no `1.032.876,71` como el dibujo de la especificación. Las fechas, `DD/MM/AAAA`.
- **Plazo fijo: al no confirmar el alta no se limpia la pantalla** (ver [Plazo fijo (opción 7)](#plazo-fijo)).
- **El `CR` de Windows se descarta en las opciones y los datos de Intereses y de Plazo fijo** (`INSPECT ... REPLACING ALL X"0D" BY SPACE`). Si una entrada con fin de línea CRLF llega al programa compilado en Linux, el `CR` quedaría como parte de lo tipeado (por ejemplo, `0` + `CR` no sería la opción Salir y el menú no terminaría nunca).

<a id="proceso-batch-cierre"></a>
## Proceso batch de cierre: BATCH-CIERRE.cbl

`BATCH-CIERRE.cbl` es un programa COBOL **separado** de `gestion-bancaria.cbl` (no interactivo, sin menú) que recorre toda la cartera de clientes y acredita el interés mensual de las cuentas habilitadas para operar, y después procesa los **vencimientos de plazo fijo** (ver [más abajo](#vencimientos-de-plazo-fijo-etapa-3)). Representa el tipo de proceso batch nocturno típico de un sistema bancario: correrlo es la forma de "cerrar el día" y actualizar los saldos con el interés devengado.

### Regla de negocio

| Estado del cliente | ¿Se le calcula interés? |
|---------------------|--------------------------|
| `A` (Activo) | Sí |
| `R` (Reactivado) | Sí |
| `I` (Inactivo) | **No.** Se excluye del cálculo, pero se cuenta como "cliente inactivo excluido" en las estadísticas |

Para cada cliente `A` o `R`:

1. `interes = saldo_actual × tasa_mensual` (interés simple, no compuesto dentro de una misma corrida).
2. `saldo_nuevo = saldo_actual + interes`, redondeado a 2 decimales (`COMPUTE ... ROUNDED`).
3. El registro se graba de nuevo en `clientes_v3.dat` (`REWRITE`) con el saldo actualizado. El **estado no cambia** (un `A` sigue `A`, un `R` sigue `R`).

La tasa está en `WORKING-STORAGE`, en `WS-TASA-INTERES`, con valor inicial **0,50 % mensual** (`0.0050`). Para cambiarla hay que editar ese `VALUE` en `BATCH-CIERRE.cbl` y recompilar; esta versión no la lee de un parámetro externo (ver [Limitaciones y mejoras futuras](#limitaciones-y-mejoras)).

Si sumar el interés desbordara el campo del saldo (caso extremo, saldo ya cercano al máximo representable), ese cliente se deja sin cambios, se avisa por pantalla y se cuenta aparte (`Clientes con error o estado desconocido`); no se pierde el resto del cierre por un único registro.

> **Nota técnica (para quien modifique `1200-ACREDITAR-INTERES`):** ese control de desborde usa un indicador propio (`WS-INTERES-OK`) y un `IF` después del `ADD`, en vez de poner la lógica directamente dentro de `ON SIZE ERROR` / `NOT ON SIZE ERROR`. Se probó así al principio y **GnuCOBOL 2.0 genera código incorrecto** cuando una sentencia aritmética (por ejemplo, otro `ADD`) queda dentro de la rama `ON SIZE ERROR` de un `ADD ... NOT ON SIZE ERROR`: la rama `NOT ON SIZE ERROR` (y todo lo que sigue en el párrafo) se salteaba en silencio incluso cuando no había ningún error. Se confirmó con un programa mínimo de 13 líneas que aísla el problema. `gestion-bancaria.cbl` no lo sufre porque su único `ON SIZE ERROR` (en el depósito) solo tiene un `DISPLAY`, sin aritmética adentro.

<a id="vencimientos-de-plazo-fijo-etapa-3"></a>
### Vencimientos de plazo fijo (Etapa 3)

Después del interés mensual, el batch recorre `plazofijo.dat` (en orden de número) y procesa cada plazo fijo **Activo (`A`) cuyo vencimiento sea igual o anterior a la fecha de proceso**. "Igual o anterior" importa: si un día el cierre no corrió (por ejemplo, el plazo fijo venció un sábado), el siguiente cierre procesa lo que venció en el medio. Los plazos fijos Cancelados (`C`) y Vencidos (`V`) no se tocan; por eso correr el cierre dos veces **no** acredita dos veces el mismo plazo fijo.

Primero se mira el cliente, y después la moneda:

| Situación | Qué hace | Estado del plazo fijo |
|-----------|----------|------------------------|
| Cliente `A` o `R`, plazo fijo en **pesos** | Suma el total (capital + interés) al saldo del cliente | Pasa a `V` |
| Cliente `A` o `R`, plazo fijo en **dólares** | No toca el saldo (las cuentas no tienen moneda): el reporte lo lista como "a pagar por caja" | Pasa a `V` |
| Cliente **inactivo** (`I`), sea cual sea la moneda | No acredita nada: queda **pendiente** | Sigue en `A` |
| DNI que **no existe** o cliente con estado desconocido | Igual que inactivo, con un aviso en pantalla | Sigue en `A` |
| La suma **supera el saldo máximo** (999.999.999,99) | No acredita nada, con un aviso en pantalla | Sigue en `A` |

Un plazo fijo pendiente se vuelve a evaluar en cada cierre. Por ejemplo, si el cliente estaba inactivo y se lo reactiva (opción 2 → `M`), el siguiente cierre lo acredita sin que haya que corregir nada a mano.

**Por qué los vencimientos van después del interés mensual:** el plazo fijo ya cobró su propio interés (el que se calculó en el alta, con la TNA de ese momento). Si se acreditara antes, ese dinero ganaría además el 0,50 % mensual del cierre en el que entra. Ejemplo (caso VTO-10): saldo 10.000,00 → interés mensual 50,00; después se suma el plazo fijo (1.032.876,71); saldo final 1.042.926,71.

**Orden de grabación:** primero se graba el saldo del cliente y después el estado `V` del plazo fijo. Los dos archivos no se graban "todo o nada" juntos: si el programa fallara justo entre las dos grabaciones, el batch se detiene con error y avisa qué número de plazo fijo hay que corregir a mano (si no, el próximo cierre lo acreditaría dos veces).

**Fecha de proceso.** El batch usa la variable `FECHA_PROCESO` (`AAAAMMDD`) igual que `gestion-bancaria.cbl` (ver [Fecha de proceso y la variable `FECHA_PROCESO`](#intereses)); sin ella usa la fecha del sistema. Se muestra en pantalla y en el encabezado del reporte. **Diferencia:** si la variable existe pero no es una fecha válida, el batch **no se ejecuta**: muestra `FECHA_PROCESO invalida (use AAAAMMDD): ...` / `Cierre NO realizado: no se modifico ningun archivo.` y termina con código de salida `1`, antes de abrir cualquier archivo (ni siquiera borra el reporte anterior). El programa interactivo puede seguir con la fecha del sistema porque alguien lo está mirando; el batch corre solo, y un error de tipeo haría vencer (o no) plazos fijos que no corresponden.

```bat
REM Windows (cmd), desde bin\
set FECHA_PROCESO=20261114
BATCH-CIERRE.exe
set FECHA_PROCESO=
```

**Acceso a los archivos.** Para buscar al cliente de cada plazo fijo por su DNI, el `SELECT` de `clientes_v3.dat` en el batch pasó de `ACCESS MODE IS SEQUENTIAL` a `ACCESS MODE IS DYNAMIC` (el layout y los datos no cambian). Las dos pasadas de siempre siguen leyendo en orden (`READ NEXT`), y la de vencimientos lee por clave (`READ ... KEY IS`); en una misma pasada no se mezclan las dos formas, porque GnuCOBOL 2.0 y 3.x se comportan distinto en ese caso. `plazofijo.dat` se abre con acceso secuencial (se recorre entero y se regraba con `REWRITE` el que vence). Si `plazofijo.dat` no existe, no es un error: no hay vencimientos.

### Cómo ejecutarlo localmente

```bat
correr_batch_cierre.bat
```

El script:
1. Busca `cobc` en el `PATH`; si no lo encuentra, usa la instalación de OpenCobolIDE detectada en esta máquina (`C:\Program Files (x86)\OpenCobolIDE\GnuCOBOL`) como respaldo. Si tampoco la encuentra ahí, informa el error y no continúa.
2. Compila `BATCH-CIERRE.cbl` con `cobc -x -Wall` **dentro de `bin\`**.
3. Ejecuta `BATCH-CIERRE.exe` desde `bin\`, que procesa todo `bin\clientes_v3.dat` y los vencimientos de `bin\plazofijo.dat`, genera `bin\reporte_cierre.txt` y termina mostrando un resumen por pantalla. Usa la fecha del sistema, salvo que la terminal tenga definida `FECHA_PROCESO`.

Se puede correr las veces que se quiera; cada corrida vuelve a acreditar interés sobre los saldos **ya actualizados** de la corrida anterior (ver [Limitaciones y mejoras futuras](#limitaciones-y-mejoras)), pero un plazo fijo ya acreditado no se vuelve a acreditar. Si `clientes_v3.dat` o `plazofijo.dat` todavía no existen, el batch no falla: procesa cero clientes / cero vencimientos y genera igual un `reporte_cierre.txt` con todos los totales en cero.

> **Ojo con los datos de prueba:** el batch usa la fecha **real**. Si en `bin\plazofijo.dat` hay plazos fijos cargados a mano con fechas inventadas (con `FECHA_PROCESO`), los que ya "vencieron" respecto de hoy se acreditan en el próximo cierre real.

### `reporte_cierre.txt`

Archivo de texto (secuencial, se sobreescribe en cada corrida) con, en este orden:

1. **Fecha del proceso**, en formato `DD/MM/AAAA`: la de `FECHA_PROCESO` si está definida, o si no la del sistema (`FUNCTION CURRENT-DATE`).
2. **Detalle de clientes procesados** (uno por línea, solo los `A`/`R`): DNI, nombre, saldo anterior, interés acreditado y saldo nuevo. Si no hay ninguno, dice explícitamente que no había clientes activos ni reactivados para procesar.
3. **Detalle de clientes Inactivos** (sin movimiento): DNI, nombre y saldo de cada cliente con estado `I`, sin columnas de interés ni saldo nuevo, porque no se les calcula nada. Si no hay ninguno, dice explícitamente que no hay clientes inactivos.
4. **Detalle de vencimientos de plazo fijo** (Etapa 3): número, DNI, moneda, capital, interés, total, vencimiento y resultado (`Acreditado`, `Pagar por caja (U$S)`, `Pendiente: cliente inactivo`, `Pendiente: cliente inexistente`, `Pendiente: estado desconocido` o `Error: supera saldo maximo`) de cada plazo fijo vencido. Si no hay ninguno, dice `No hay plazos fijos vencidos.`. Esta tabla mide 121 columnas: por eso el renglón del reporte pasó de 100 a 132 posiciones (el ancho clásico de una impresora de listados). Las líneas de `=` y `-` de las otras secciones siguen teniendo 100, así que esas secciones no cambiaron.
5. **Resumen final**: cantidad de clientes procesados (A/R), cantidad de inactivos excluidos, total de intereses acreditados; cantidad y total de plazos fijos acreditados en pesos, cantidad y total en dólares a pagar por caja, y cantidad de plazos fijos pendientes; y el **saldo total de la cartera**, que suma los saldos de **todos** los clientes después del cierre —activos, reactivados e inactivos, incluidos los plazos fijos acreditados—, aunque a los inactivos no se les haya acreditado interés. (En la práctica, un cliente inactivo siempre tiene saldo 0, porque `gestion-bancaria.cbl` no permite dar de baja con saldo distinto de cero; pero el total se calcula sumando a todos igual, por las dudas.)

Ejemplo:

```
====================================================================================================
PROCESO BATCH DE CIERRE - CUENTA BANCARIA
Fecha del proceso: 22/09/2026
====================================================================================================

Detalle de clientes procesados (Activos / Reactivados):

DNI         Nombre                         Saldo anterior         Interes         Saldo nuevo
----------------------------------------------------------------------------------------------------
11111111   Cliente Uno                            10,000.00              50.00          10,050.00
22222222   Cliente Dos                               500.55               2.50             503.05

Detalle de clientes Inactivos (sin movimiento):

DNI         Nombre                         Saldo
----------------------------------------------------------------------------------------------------
44444444   Cliente Cuatro                              0.00

Detalle de vencimientos de plazo fijo:

Numero  DNI       Mon           Capital            Interes              Total  Vencimiento Resultado
-------------------------------------------------------------------------------------------------------------------------
000001  11111111  P        1,000,000.00          32,876.71       1,032,876.71  14/11/2026  Acreditado
000002  11111111  D              500.00               1.23             501.23  14/11/2026  Pagar por caja (U$S)
000003  44444444  P        1,000,000.00          32,876.71       1,032,876.71  14/11/2026  Pendiente: cliente inactivo

====================================================================================================
RESUMEN DEL CIERRE
====================================================================================================
Clientes procesados (Activos/Reactivados):          2
Clientes inactivos excluidos:                        1
Total de intereses acreditados:      $            52.50
Plazos fijos vencidos acreditados:                  1
Acreditado por vencimientos:         $     1,032,876.71
Plazos fijos en dolares (pago por caja):            1
A pagar por caja en dolares:       U$S           501.23
Plazos fijos vencidos pendientes:                   1
Saldo total de la cartera:           $     1,043,429.76
====================================================================================================
```

El programa también muestra por pantalla un resumen breve equivalente (la fecha de proceso y las mismas líneas del resumen), confirmando que se generó `reporte_cierre.txt`, sin el detalle línea por línea de ninguna de las tablas.

**Por qué el detalle de Activos y el de Inactivos van en dos bloques separados, no intercalados:** el batch recorre el archivo en orden de clave (DNI), y un cliente activo y uno inactivo pueden aparecer intercalados en ese orden. Como el reporte pide las dos tablas agrupadas, el programa hace **dos pasadas** sobre `clientes_v3.dat`: la primera actualiza los saldos y escribe la tabla de Activos/Reactivados; la segunda vuelve a abrir el archivo **solo para lectura** y arma la tabla de Inactivos. Ver `1000-LEER-Y-PROCESAR` (pasada 1) y `1500-LISTAR-INACTIVOS` (pasada 2) en `BATCH-CIERRE.cbl`.

### El copybook CLIENTE.cpy

`gestion-bancaria.cbl` y `BATCH-CIERRE.cbl` incluyen el layout del registro de cliente con `COPY CLIENTE.` en vez de declararlo cada uno por su cuenta, para que sea imposible que se desincronicen y terminen leyendo/escribiendo `clientes_v3.dat` con formatos distintos. **Los dos programas se recompilan siempre juntos** cuando cambia `CLIENTE.cpy`. Ver la tabla «Registro» y la nota «Por qué el archivo se llama `clientes_v3.dat`», en [Persistencia](#programa-gestion-bancaria), que siguen aplicando igual.

### El JCL de referencia (`batch_cierre.jcl`)

`batch_cierre.jcl` **no se ejecuta en este entorno** (Windows + GnuCOBOL no corre JCL). Es documentación: muestra cómo se vería este mismo proceso corriendo como un job batch nocturno en un mainframe z/OS real, con su JOB card, un `EXEC PGM=` para el programa ya compilado, y sentencias `DD` que representan el archivo de clientes como un **VSAM KSDS** (equivalente mainframe del archivo indexado `clientes_v3.dat`, clave = DNI) y el reporte de cierre como un **archivo secuencial** de salida (equivalente de `reporte_cierre.txt`). Cada bloque del JCL está comentado explicando qué hace y su correspondencia con el entorno local; el archivo mismo trae, al principio y al final, una tabla de equivalencias entre ambos entornos.

En este entorno de desarrollo local, el equivalente funcional de ese JCL es `correr_batch_cierre.bat`.

> **PENDIENTE:** `batch_cierre.jcl` todavía describe el cierre **anterior a la Etapa 3**: no tiene una sentencia `DD` para el archivo de plazos fijos (`plazofijo.dat`, que en z/OS sería otro VSAM KSDS) ni muestra cómo se pasa la fecha de proceso (`FECHA_PROCESO`). Se va a actualizar más adelante, aparte (es un archivo protegido del proyecto).

### ⚠ No correr `gestion-bancaria.exe` y el batch al mismo tiempo

**`gestion-bancaria.cbl` y `BATCH-CIERRE.cbl` no deben ejecutarse simultáneamente sobre el mismo `clientes_v3.dat`** (desde la Etapa 3, tampoco sobre el mismo `plazofijo.dat`). Ninguno de los dos programas implementa bloqueo de registros ni control de concurrencia (ver [Limitaciones y mejoras futuras](#limitaciones-y-mejoras)), así que correrlos al mismo tiempo puede producir:

- un `FILE STATUS` de "archivo en uso" (`61`) al intentar abrir el segundo programa,
- una condición de carrera si ambos leen y graban el mismo cliente casi a la vez, con el riesgo de que una de las dos escrituras se pierda.

Es el mismo comportamiento que tendría este proceso en un entorno de producción real: un cierre nocturno corre con el sistema transaccional (acá, `gestion-bancaria.cbl`) fuera de línea o en una ventana de mantenimiento, nunca en simultáneo. En este entorno local, la forma práctica de respetarlo es simplemente no tener `gestion-bancaria.exe` abierto (esperando en el menú) mientras se corre `correr_batch_cierre.bat`, y viceversa. Esto vale para las **dos** pasadas que hace el batch sobre el archivo, no solo para la primera.

<a id="listado-clientes"></a>
## Listado de clientes (solo lectura): LISTADO-CLIENTES.cbl

`LISTADO-CLIENTES.cbl` es un tercer programa, también separado de `gestion-bancaria.cbl` y de `BATCH-CIERRE.cbl`, para **consultar** la cartera completa sin operar sobre ella. A diferencia del batch de cierre, **este programa nunca modifica nada**: no acredita interés, no cambia estados, no toca saldos.

### Por qué es seguro correrlo en cualquier momento

- Abre `clientes_v3.dat` únicamente con `OPEN INPUT` (solo lectura). En ningún punto del código hay un `OPEN I-O`, un `OPEN OUTPUT`, ni una sentencia `WRITE`, `REWRITE` o `DELETE` sobre ese archivo.
- Se verificó tomando un hash del archivo antes y después de correr el programa (incluso dos veces seguidas): **queda byte a byte idéntico**.
- Por esto no tiene la misma restricción de "no correr al mismo tiempo" que `BATCH-CIERRE.cbl`: como no escribe, no hay riesgo de perder una actualización. Aun así, para no arrastrar un `FILE STATUS` de "archivo en uso" (`61`) si `gestion-bancaria.cbl` tiene el archivo abierto en ese instante puntual, lo más prolijo sigue siendo correrlo con `gestion-bancaria.exe` en el menú principal (no a mitad de una operación).

### Qué muestra

El listado agrupa a los clientes en tres secciones, en este orden, y termina con un resumen:

1. **Clientes Activos (A)**
2. **Clientes Reactivados (R)**
3. **Clientes Inactivos (I)**

En cada sección, un bloque por cliente con DNI, Nombre, Dirección, Teléfono, Saldo y Estado (el mismo formato de bloque que ya usa `gestion-bancaria.cbl` en su consulta). Si una sección no tiene clientes, lo dice explícitamente en vez de quedar vacía sin explicación.

El resumen final muestra, en este orden: cantidad de clientes por cada estado (Activos, Inactivos, Reactivados), la cantidad total de clientes del archivo, y el **saldo total de la cartera**, sumando a todos los clientes sin importar su estado.

**La pantalla y `listado_clientes.txt` muestran exactamente el mismo contenido** (una sola rutina de impresión hace `DISPLAY` y `WRITE` juntos para cada línea, así los dos nunca se desincronizan).

Ejemplo (con una cartera de 4 clientes):

```
====================================================================================================
LISTADO DE CLIENTES
(solo lectura - no modifica datos)
====================================================================================================
Clientes Activos (A):
----------------------------------------------------------------------------------------------------
DNI:       11111111
Nombre:    Cliente Uno
Direccion: Calle 1
Telefono:  011 1111-1111
Saldo:            10,000.00
Estado:    A - Activo

DNI:       22222222
...

Clientes Reactivados (R):
----------------------------------------------------------------------------------------------------
DNI:       33333333
...

Clientes Inactivos (I):
----------------------------------------------------------------------------------------------------
DNI:       44444444
...

====================================================================================================
RESUMEN
====================================================================================================
Clientes Activos (A):                 2
Clientes Inactivos (I):               1
Clientes Reactivados (R):             1
Cantidad total de clientes:           4
Saldo total de la cartera: $        10,000.00
====================================================================================================
```

### Cómo ejecutarlo localmente

```bat
ver_listado_clientes.bat
```

Mismo mecanismo que `correr_batch_cierre.bat`: busca `cobc` en el `PATH` y, si no lo encuentra, usa la instalación de OpenCobolIDE de esta máquina como respaldo; compila `LISTADO-CLIENTES.cbl` con `cobc -x -Wall` **dentro de `bin\`** y ejecuta `LISTADO-CLIENTES.exe` desde ahí. Si `clientes_v3.dat` todavía no existe, el listado no falla: muestra las tres secciones vacías y un resumen en cero.

### Por qué son tres pasadas, no una

Igual que `BATCH-CIERRE.cbl` con sus tablas de Activos/Reactivados e Inactivos, un cliente Activo y uno Inactivo pueden aparecer intercalados en el archivo (que está ordenado por DNI, no por estado). Como el listado pide las tres secciones agrupadas, el programa abre y recorre `clientes_v3.dat` **tres veces** (una por sección), siempre en modo `INPUT`. La primera pasada (Activos) además totaliza la cantidad y el saldo de **todos** los clientes del archivo, para no necesitar una cuarta pasada solo para el resumen.

<a id="testing"></a>
## Testing

El documento **[`CASOS_DE_PRUEBA.md`](CASOS_DE_PRUEBA.md)** tiene la matriz de casos de prueba (QA) del proyecto: 12 casos con columnas ID, Módulo, Escenario, Pasos a seguir, Resultado esperado, Resultado obtenido (para completar a mano en cada corrida) y Observaciones. Cubre alta, depósito, extracción, consulta, modificación, baja, reactivación y el batch de cierre, incluyendo casos negativos (DNI inválido, fondos insuficientes, cliente inexistente, operar sobre un cliente inactivo). Desde la Evolución 1 / Etapa 1 suma 12 casos más (MENU-01 e INT-01 a INT-11) para el menú nuevo y las tasas de Intereses, desde la Etapa 2 otros 17 (PF-01 a PF-17) para el Plazo fijo, y desde la Etapa 3 otros 12 (VTO-01 a VTO-12) para los vencimientos de plazo fijo en el batch de cierre, todos automatizados (ver [Casos de INTERESES](#casos-de-intereses-evolución-1--etapa-1), [Casos de PLAZO FIJO](#casos-de-plazo-fijo-evolución-1--etapa-2) y [Casos de VENCIMIENTOS](#casos-de-vencimientos-evolución-1--etapa-3)). En total, **53 casos**: 46 automatizados y 7 manuales.

### Casos automatizados

Los cinco casos más simples y lineales de esa matriz —sin ramificaciones ni confirmaciones S/N— están automatizados de punta a punta: se ejecutan con archivos de entrada que simulan lo que un usuario tipearía en el menú, y el resultado se compara automáticamente (sin intervención manual) contra un archivo de referencia con `fc` (File Compare, incluido en Windows):

| Caso | Entrada | Salida | Esperado (referencia) | Cubre |
|------|---------|--------|------------------------|-------|
| CP-01 | `entrada_alta_ok.txt` | `salida_alta_ok.txt` | `esperado_alta_ok.txt` | Alta exitosa, Estado queda en `A` |
| CP-02 | `entrada_alta_dni_invalido.txt` | `salida_alta_dni_invalido.txt` | `esperado_alta_dni_invalido.txt` | Alta rechazada con DNI de menos de 8 dígitos y con DNI no numérico |
| CP-03 | `entrada_deposito.txt` | `salida_deposito.txt` | `esperado_deposito.txt` | Depósito exitoso a un cliente Activo |
| CP-04 | `entrada_extraccion.txt` | `salida_extraccion.txt` | `esperado_extraccion.txt` | Extracción exitosa (fondos suficientes) |
| CP-06 | `entrada_consulta.txt` | `salida_consulta.txt` | `esperado_consulta.txt` | Consulta muestra todos los datos, incluido Estado |

Cada `esperado_*.txt` es la salida ya verificada a mano contra el "Resultado esperado" de `CASOS_DE_PRUEBA.md`, guardada como referencia fija. Si en el futuro se cambia a propósito algo que afecta la salida de `gestion-bancaria.cbl` (por ejemplo, se redacta distinto un mensaje), hay que revisar el nuevo `salida_*.txt` a mano una vez y, si es correcto, actualizar el `esperado_*.txt` correspondiente — la comparación automática no sabe distinguir un cambio intencional de una regresión, solo detecta que algo cambió.

### Cómo correrlos

La forma más simple y confiable:

```bat
correr_pruebas_automatizadas.bat
```

Compila `gestion-bancaria.exe` **en `bin\`**, corre ahí los 5 pares entrada/salida (leyendo cada `entrada_*.txt` y escribiendo cada `salida_*.txt` en la raíz del proyecto) con el runtime de GnuCOBOL correctamente puesto en el `PATH` para esa sesión (mismo mecanismo de respaldo que `correr_batch_cierre.bat` y `ver_listado_clientes.bat`), y **compara cada `salida_*.txt` contra su `esperado_*.txt` con `fc`**, mostrando al final un resumen del tipo:

```
[pruebas]   OK     - alta_ok
[pruebas]   OK     - alta_dni_invalido
[pruebas]   OK     - deposito
[pruebas]   OK     - extraccion
[pruebas]   OK     - consulta

[pruebas] ==========================================
[pruebas]  Resumen: 5 OK / 0 FALLO (de 5)
[pruebas] ==========================================
```

Si algún caso falla, el script indica cuál y sugiere el comando `fc` puntual para ver la diferencia exacta, y termina con código de salida distinto de cero (útil si en algún momento se engancha a un pipeline de CI).

Ese mismo resumen se guarda además en **`resultado_pruebas.txt`** (en la raíz del proyecto, junto a `CASOS_DE_PRUEBA.md`), igual que `correr_batch_cierre.bat` deja `bin\reporte_cierre.txt` y `ver_listado_clientes.bat` deja `bin\listado_clientes.txt`. Esto es necesario porque si el `.bat` se corre con doble clic (en vez de desde una terminal ya abierta), la ventana de consola se cierra sola apenas termina y no da tiempo a leer el resumen en pantalla; el archivo queda para abrirlo después con cualquier editor de texto.

También se puede correr cada caso a mano, uno por uno, desde `bin\`:

```bat
cd bin
gestion-bancaria.exe < ..\entrada_alta_ok.txt > ..\salida_alta_ok.txt
```

Y así con cada par. **Para esto, el `PATH` de esa terminal tiene que incluir el runtime de GnuCOBOL** (lo mismo que hace falta para compilar); si no, `gestion-bancaria.exe` falla al arrancar sin mostrar ningún error y el `salida_*.txt` queda en 0 bytes — ver [Solución de problemas](#solucion-de-problemas), «El archivo de salida queda en 0 bytes al redirigir la entrada». Por eso conviene usar `correr_pruebas_automatizadas.bat`, que ya se ocupa de eso.

Cada `entrada_*.txt` es autocontenido (da de alta su propio cliente de prueba, con un DNI dedicado en el rango `800000XX` para no chocar con los DNIs que usa la matriz manual) y **termina siempre en `0`**, la opción de salir del menú: es necesario para que no quede colgado, porque una entrada redirigida por archivo que se queda sin líneas antes de un `0` no corta sola (ver [Solución de problemas](#solucion-de-problemas), «Si la entrada se redirige…»).

Si se corren a mano (fuera de `correr_pruebas_automatizadas.bat`), hay que comparar cada `salida_*.txt` contra su `esperado_*.txt` (o contra el "Resultado esperado" de `CASOS_DE_PRUEBA.md`) uno por uno, por ejemplo con `fc esperado_alta_ok.txt salida_alta_ok.txt`. Si `clientes_v3.dat` ya tiene un cliente con ese mismo DNI de una corrida anterior, el script no falla, pero la salida cambia (por ejemplo, `entrada_alta_ok.txt` mostraría `Ya existe un cliente con ese DNI.` en vez de `Cliente dado de alta.`, y la comparación automática lo marcaría como FALLO); para una corrida "limpia" de los cinco casos, borrar `bin\clientes_v3.dat` antes.

Los siete casos restantes (CP-05, CP-07 a CP-12) quedan como pruebas manuales en `CASOS_DE_PRUEBA.md`: tienen ramificaciones (confirmaciones S/N, submenús, un estado previo que hay que preparar, o el batch de cierre) que no se prestan a una sola pasada de entrada redirigida.

### Casos de INTERESES (Evolución 1 / Etapa 1)

`CASOS_DE_PRUEBA.md` tiene además los casos **MENU-01** e **INT-01 a INT-11**, todos automatizados. Se corren en la segunda parte de `correr_pruebas_automatizadas.bat`, que tiene su propio resumen (`Resumen intereses: 12 OK / 0 FALLO (de 12)`), o en Linux/Docker/CI con `correr_pruebas_intereses.sh`:

```bash
docker build -t gestion-bancaria .
docker run --rm gestion-bancaria bash correr_pruebas_intereses.sh
```

Se diferencian de los 5 casos de clientes en tres cosas:

- **Fecha fija.** El resultado depende de la fecha (por ejemplo, `Vigente desde`), así que cada paso se corre con la variable de entorno `FECHA_PROCESO` fija (ver [Intereses (opción 8)](#intereses)).
- **Archivo vacío.** Cada caso corre en `bin\prueba_int\`, una carpeta que el script borra y vuelve a crear, así arranca con un `intereses.dat` vacío **sin tocar el `bin\intereses.dat` real**.
- **Pasos.** Un caso puede tener varios pasos (`entrada_int04_1.txt`, `entrada_int04_2.txt`), cada uno con su fecha, sobre el mismo archivo. Por ejemplo, alta un miércoles y modificación el viernes. Las salidas se juntan en un solo `salida_<caso>.txt`.

En Linux el script quita al vuelo los `\r` de los `.txt` (`tr -d '\r'`), compara ignorándolos (`diff --strip-trailing-cr`) y corta cada ejecución a los 10 segundos (`timeout 10`) por si una entrada quedara incompleta.

### Casos de PLAZO FIJO (Evolución 1 / Etapa 2)

Los casos **PF-01 a PF-17** de `CASOS_DE_PRUEBA.md` también están automatizados. Se corren en la tercera parte de `correr_pruebas_automatizadas.bat` (resumen `Resumen plazo fijo: 17 OK / 0 FALLO (de 17)`), o en Linux/Docker/CI con `correr_pruebas_plazofijo.sh`:

```bash
docker build -t gestion-bancaria .
docker run --rm gestion-bancaria bash correr_pruebas_plazofijo.sh
```

Usan la misma técnica que los de INTERESES (fecha fija, carpeta descartable y varios pasos), con dos diferencias:

- La carpeta es `bin\prueba_pf\`, y en ella arrancan vacíos los **tres** archivos (`clientes_v3.dat`, `intereses.dat` y `plazofijo.dat`). Por eso cada caso da de alta su propio cliente (DNIs `800001XX`) y su tasa: nunca se tocan los archivos de `bin\`.
- En general, el **paso 1** (miércoles 14/10/2026) da de alta el cliente y la tasa, que rige desde el jueves, y el **paso 2** (jueves 15/10/2026) opera con el plazo fijo. Algunos casos tienen un paso 3: PF-14 (otra ejecución, para ver que el número sigue en `000003`) y PF-17 (el 14/11/2026, día del vencimiento).

### Casos de VENCIMIENTOS (Evolución 1 / Etapa 3)

Los casos **VTO-01 a VTO-12** de `CASOS_DE_PRUEBA.md` prueban los vencimientos de plazo fijo en el batch de cierre. Se corren en la cuarta parte de `correr_pruebas_automatizadas.bat` (resumen `Resumen vencimientos: 12 OK / 0 FALLO (de 12)`), que antes compila también `BATCH-CIERRE.cbl` en `bin\`, o en Linux/Docker/CI con `correr_pruebas_vencimientos.sh`:

```bash
docker build -t gestion-bancaria .
docker run --rm gestion-bancaria bash correr_pruebas_vencimientos.sh
```

Usan la misma técnica que los de PLAZO FIJO, en la carpeta descartable `bin\prueba_vto\` (DNIs `800002XX`), con una novedad: **un caso mezcla corridas de los dos programas**. En la lista de pasos de cada caso:

- `AAAAMMDD` corre `gestion-bancaria.exe` con esa fecha y la siguiente entrada del caso (`entrada_vto01_1.txt`, `entrada_vto01_2.txt`, ...).
- `B:AAAAMMDD` corre `BATCH-CIERRE.exe` con esa fecha. Antes se borra el `reporte_cierre.txt` anterior, y después se agregan a la salida el código de salida del batch y el reporte que generó, entre líneas que empiezan con `-----`. Así el `esperado_vtoNN.txt` verifica también el reporte (y, en VTO-11, que el batch termina con código `1` sin generar ninguno).

Por ejemplo, `vto07 20261014 20261015 B:20261114 20261116 B:20261116 20261116` es: alta de cliente y tasa, alta del plazo fijo y baja del cliente, primer cierre (queda pendiente), reactivación, segundo cierre (se acredita) y consulta final. Las líneas `-----` son las mismas en el `.bat` y en el `.sh`, así un mismo esperado sirve en Windows y en Linux.

### Gestión de casos y ejecución en Jira/Xray

Los 12 casos de prueba de `CASOS_DE_PRUEBA.md` (los 5 automatizados y los 7 manuales) están además cargados como Tests en Jira, usando Xray como plugin de gestión de pruebas, cada uno con su Resumen, Descripción, pasos estructurados (Acción / Datos / Resultado Esperado) y — en los automatizados — la referencia a los archivos `entrada_*.txt` / `esperado_*.txt` correspondientes.

Los 12 Tests están agrupados en una Ejecución de Tests (Test Execution) donde quedó registrada la corrida completa: los 5 automatizados con el resultado real obtenido al correr `correr_pruebas_automatizadas.bat`, y los 7 manuales ejecutados paso a paso contra `gestion-bancaria.exe`, marcando cada paso (y el resultado general de cada caso) como PASS o FAIL según lo observado. La última ejecución completa cerró en **12 de 12 casos PASSED**.

Esto documenta, además del código, la práctica de gestión y trazabilidad de QA sobre el proyecto: diseño de casos, automatización de los que se prestan a un script simple, ejecución manual del resto, y registro de resultados en una herramienta de test management real.

<a id="solucion-de-problemas"></a>
## Solución de problemas

**Parece colgado después de ingresar un dato (no aparece el siguiente prompt).** Con `DISPLAY "..." WITH NO ADVANCING`, cuando la salida no va a una consola real (por ejemplo el panel de un IDE, o salida redirigida), el texto puede no mostrarse mientras el programa espera en un `ACCEPT`: el programa no está colgado, espera datos que el usuario no sabe que debe ingresar. Todos los prompts del programa usan `WITH NO ADVANCING` (el dato se tipea en la misma línea); se probaron en la terminal web (`webterm-demo`, Docker sobre Ubuntu) y se ven correctamente antes de tipear. Si en tu consola o IDE no aparecen, ejecutá el programa en una consola real (cmd, PowerShell o `docker run -it --rm gestion-bancaria`).

**Elegí la opción 2 y me pide un DNI, no `M` o `B`.** Es lo esperado: primero se pide el DNI y se muestran los datos; la pregunta `M`/`B` viene después.

**Elegí `M` sobre un cliente y no me deja cambiar la dirección / el teléfono / el saldo, solo dice que lo reactivó.** El cliente estaba inactivo (`I`). Para un cliente inactivo la única acción de `M` es reactivarlo. Una vez reactivado (`R`), volvé a elegir la opción 2 → `M` para modificar sus datos.

**Modifiqué un dato pero el programa dice `No se modifico ningun dato.`** No debería pasar: ese mensaje solo aparece si, al elegir `4 - Terminar modificacion`, no se grabó ningún campo en esa sesión (por ejemplo, si todos los intentos fueron inválidos o si se eligió `4` de entrada). Cada campo válido se graba y confirma con `Dato modificado.` apenas se ingresa, antes de volver a mostrar el submenú; si ese mensaje no apareció para un campo, revisar si el dato fue rechazado por alguna validación (ver la tabla de [Validaciones](#validaciones-cuenta)).

**Un cliente no puede depositar ni extraer.** Probablemente está inactivo (`Cliente inactivo: no se puede operar.`). Ver el estado con la opción 5 y, si corresponde, reactivarlo con la opción 2 → `M`.

**`clientes_v3.dat` corrupto o de otra versión.** El programa lo informa (por ejemplo `FILE STATUS: 30`) y termina. Borrar `clientes_v3.dat` para que se cree de nuevo (se pierden los datos guardados).

**Aparecen clientes "que no existen" o no aparecen los que cargué.** Probablemente se está ejecutando desde otra carpeta y se está usando otro `clientes_v3.dat` (ver «Dónde vive `clientes_v3.dat`», en [Compilación y ejecución](#compilacion-y-ejecucion)), o los clientes se cargaron con una versión anterior del programa (archivo distinto).

**El archivo de salida queda en 0 bytes al redirigir la entrada (`gestion-bancaria.exe < entrada.txt > salida.txt`), sin ningún mensaje de error.** No es un problema de *buffering* del `DISPLAY` ni hace falta tocar `gestion-bancaria.cbl`: es que `gestion-bancaria.exe` no encuentra el runtime de GnuCOBOL (`libcob` y sus DLL) en el `PATH` de esa terminal. Windows falla al arrancar el programa (`STATUS_DLL_NOT_FOUND`, código de salida `-1073741515`) **sin mostrar ningún texto de error** en pantalla; pero `cmd` ya había creado el archivo de salida (vacío) al armar la redirección, así que el único síntoma visible es un archivo de 0 bytes. Se confirmó reproduciéndolo: la *misma* terminal, el *mismo* comando, con y sin el `PATH` del runtime, da exactamente `0 bytes` / archivo completo según corresponda.

- Cómo verificarlo: después de correr el comando, mirar el código de salida (`echo %ERRORLEVEL%` en `cmd`, o `$LASTEXITCODE` en PowerShell). Un número muy negativo (o `-1073741515` puntualmente) confirma este diagnóstico; `0` significa que sí corrió.
- Solución recomendada: usar **`correr_pruebas_automatizadas.bat`** para los 5 casos semi-automatizados (ver [Testing](#testing)), que ya deja el `PATH` bien puesto para esa corrida, igual que `correr_batch_cierre.bat` y `ver_listado_clientes.bat` lo hacen para sus programas.
- Si se prefiere correr `gestion-bancaria.exe < entrada.txt > salida.txt` a mano, hay que asegurarse de que la terminal tenga el runtime de GnuCOBOL en el `PATH` (lo mismo que hace falta para compilar con `cobc`); si se compiló en una terminal y se corre en otra sin ese `PATH`, pasa esto.

<a id="limitaciones-y-mejoras"></a>
## Limitaciones y mejoras futuras

### Limitaciones de `gestion-bancaria.cbl`

- La modificación del **saldo** permite fijar cualquier valor válido sin dejar registro: no hay historial ni auditoría de movimientos. El nombre, el DNI y el estado no se pueden editar por esa vía.
- La reactivación no pide confirmación ni deja constancia de cuándo ni por qué se hizo.
- El estado `R` no distingue cuántas veces se reactivó un cliente ni se puede volver a `A`.
- Un DNI dado de baja (`I`) sigue ocupado: no se puede reutilizar en un alta, solo reactivar al cliente.
- Un solo usuario a la vez: no hay bloqueo de registros ni control de concurrencia. Esto incluye a `BATCH-CIERRE.cbl` (ver «No correr `gestion-bancaria.exe` y el batch al mismo tiempo», en [Proceso batch de cierre](#proceso-batch-cierre)).
- Si el programa se interrumpe de forma abrupta con el archivo abierto, éste podría quedar inconsistente; no hay respaldo ni recuperación.
- Sin autenticación ni historial de movimientos: solo se guarda el saldo actual.
- Sin migración desde los archivos de versiones anteriores (`clientes.dat`, `clientes_v2.dat`).
- El DNI y el nombre no se pueden corregir; ante un error hay que dar de baja (lógica) y usar otro DNI, o borrar el archivo.
- Un monto o saldo con más de 2 decimales se **trunca** (`10.999` pasa a `10.99`); el punto decimal debe ser `.`.
- Un dato inválido en el alta cancela toda la operación (no se vuelve a pedir el campo); una respuesta distinta de `M`/`B` en la opción 2 también vuelve al menú sin repetir la pregunta.
- Si la entrada se redirige desde un archivo o pipe y termina sin un `0` de salida, el programa no detecta el fin de entrada y repite el menú. Con teclado no ocurre. Lo mismo pasa con los datos de Intereses (moneda, días, TNA), que se vuelven a pedir hasta que sean válidos: GnuCOBOL entrega el fin de entrada como un renglón vacío, que es indistinguible de un Enter sin datos.
- Las cuentas no tienen moneda: la moneda solo existe en la tabla de tasas de Intereses (pesos / dólares).
- Intereses: el próximo día hábil **no considera feriados** (solo sábados y domingos).
- Intereses: no hay historial de tasas; solo se guardan la TNA actual y la anterior.
- Intereses: la baja no pide confirmación (rige de inmediato); se puede revertir con un alta (reactivación).
- `BATCH-CIERRE.cbl` todavía no usa la tabla de tasas de `intereses.dat`, y su reporte sigue titulado `CUENTA BANCARIA`.
- Plazo fijo: un plazo fijo vencido sigue en estado `A` hasta que **corra el batch de cierre** (que lo acredita), y mientras tanto no se puede cancelar.
- Plazo fijo: la consulta muestra `V - Vencido y acreditado` también para los de dólares, aunque esos no se suman al saldo sino que se pagan por caja (el detalle está en el reporte del cierre).
- Plazo fijo: la consulta es solo **por número**; no hay listado de los plazos fijos de un DNI.
- Plazo fijo: no mueve el saldo del cliente ni deja registro del dinero que entra o sale (no hay historial de movimientos).
- Plazo fijo: el vencimiento puede caer en sábado, domingo o feriado (es alta + días, sin correrlo a un día hábil).
- Plazo fijo: el monto se vuelve a pedir hasta que sea válido, con el mismo riesgo de bucle que los datos de Intereses si la entrada se termina.

### Limitaciones de `BATCH-CIERRE.cbl`

- **Sin control de corridas duplicadas.** Nada impide correr el batch dos veces el mismo día; cada corrida vuelve a acreditar interés sobre el saldo ya actualizado (interés compuesto entre corridas, aunque simple dentro de una misma corrida). En un entorno real, el scheduler (o el propio JCL) garantizaría una sola corrida por período.
- **Tasa fija en el código.** Cambiarla requiere editar `WS-TASA-INTERES` y recompilar; no se lee de un archivo de parámetros ni se puede pasar por línea de comandos.
- **Reporte no acumulativo.** `reporte_cierre.txt` se sobreescribe en cada corrida; no queda un historial local de cierres anteriores (a diferencia del JCL de referencia, que documenta un dataset generacional (GDG) para eso).
- **Sin control de concurrencia con `gestion-bancaria.cbl`.** Ver «No correr `gestion-bancaria.exe` y el batch al mismo tiempo», en [Proceso batch de cierre](#proceso-batch-cierre).
- **No hay historial de movimientos.** El interés acreditado queda en el reporte de esa corrida, pero no se guarda en el archivo de clientes como un movimiento separado; solo se ve reflejado en el saldo. Lo mismo vale para los plazos fijos acreditados.
- **Vencimientos sin "todo o nada".** El saldo del cliente y el estado `V` del plazo fijo se graban por separado. Si el programa se cortara justo entre las dos grabaciones, hay que corregir ese plazo fijo a mano (el batch avisa cuál) para que no se acredite dos veces.
- **Dólares sin cuenta.** Los plazos fijos en dólares vencidos se informan "a pagar por caja", pero no queda registro de que se hayan pagado.
- **Pendientes sin límite.** Un plazo fijo de un cliente inactivo queda pendiente hasta que se lo reactive; no hay aviso aparte de la línea del reporte en cada cierre.

### Posibles mejoras futuras

Cada limitación de arriba sugiere una mejora natural. Algunas, en orden aproximado de impacto/esfuerzo:

- **PENDIENTE (próximo paso después de la Etapa 1): protección contra el bucle infinito al terminarse la entrada.** Hoy, si la entrada se acaba (archivo redirigido incompleto, o Ctrl+Z / Ctrl+D en el teclado), los datos de Intereses que se vuelven a pedir (moneda, días, TNA) y el menú principal repiten el aviso para siempre, porque GnuCOBOL entrega el fin de entrada como una línea vacía. Propuesta: un **límite de intentos**. Cada dato cuenta los valores inválidos seguidos y, al llegar a 5, cancela la operación (`Demasiados intentos: operacion cancelada.`) sin grabar nada. Los menús cuentan las opciones inválidas seguidas y, al llegar a 10, cierran los archivos y terminan el programa en orden. Alternativa más completa (y más invasiva): leer el teclado como un archivo (`ASSIGN TO KEYBOARD`) y detectar el fin con `AT END`.
- **PENDIENTE: título del reporte de `BATCH-CIERRE.cbl`.** Sigue diciendo `CUENTA BANCARIA` (no se tocó en las Etapas 1, 2 ni 3).
- **PENDIENTE: actualizar `batch_cierre.jcl` a la Etapa 3.** Agregar la sentencia `DD` del archivo de plazos fijos y mostrar cómo se pasa la fecha de proceso (ver [El JCL de referencia](#proceso-batch-cierre)). Requiere permiso aparte, porque es un archivo protegido.
- **PENDIENTE: que los 5 casos de clientes no dependan de `bin\clientes_v3.dat`.** Hoy dan de alta sus clientes `800000XX` en el archivo real de `bin\`, así que **la segunda corrida seguida** de `correr_pruebas_automatizadas.bat` falla con `Ya existe un cliente con ese DNI.` hasta que se borre o se mueva ese archivo. Se podrían correr en una carpeta descartable, como los de INTERESES, PLAZO FIJO y VENCIMIENTOS.
- **Plazo fijo: listado por DNI** (opcional en la especificación): en la consulta, listar todos los plazos fijos de un cliente.
- **Historial de movimientos.** Un archivo de transacciones (depósitos, extracciones, modificaciones, intereses) separado del maestro de clientes, para auditoría y para poder reconstruir cómo se llegó a un saldo.
- **Control de corridas del batch.** Un archivo o registro de "último cierre corrido" que rechace o avise ante una segunda corrida del mismo período.
- **Parametrizar la tasa de interés.** Leerla de un archivo o de un parámetro de ejecución en vez de tenerla fija en `WORKING-STORAGE`, para no depender de recompilar.
- **Migración automática entre versiones del archivo.** Un programa que lea `clientes_v2.dat` (o `clientes.dat`) y regrabe los registros en el formato actual, en vez de tener que dar de alta a mano.
- **Bloqueo de registros / control de concurrencia real.** Para que `gestion-bancaria.cbl` y `BATCH-CIERRE.cbl` puedan convivir sin la restricción manual de "no correrlos juntos" — en GnuCOBOL, vía `LOCK` en el `OPEN`, o una cola de trabajos si se migrara a una arquitectura cliente-servidor.
- **Reactivar con confirmación y trazabilidad**, y una forma de volver a `A` desde `R` si no se necesita distinguir "nunca estuvo inactivo" de "fue reactivado".
- **Autenticación** de quién opera el programa, más allá del acceso físico a la terminal.
- **Reporte acumulativo del batch**, con una generación por corrida (análogo al GDG del JCL de referencia) en vez de sobreescribir siempre el mismo `reporte_cierre.txt`.

<a id="licencia"></a>
## Licencia

Este proyecto se distribuye bajo la **licencia MIT** — ver [`LICENSE`](LICENSE).

Se eligió MIT por ser la licencia open source más simple y más reconocida para un proyecto de portfolio: permite a cualquiera usar, copiar, modificar y redistribuir el código (incluso con fines comerciales), con la única condición de conservar el aviso de copyright, y sin garantía de ningún tipo. No hay motivo para restringir más el uso de un proyecto didáctico como este.

<a id="autor"></a>
## Autor

**Juan Carlos Schiavoni**
[LinkedIn](https://www.linkedin.com/in/juancarlosschiavoni/)
