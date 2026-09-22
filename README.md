# CUENTA – Gestión de cuentas bancarias en COBOL

<a id="sobre-este-proyecto"></a>
## Sobre este proyecto

Este proyecto fue desarrollado con **[Claude Code](https://claude.com/claude-code)** (el asistente de inteligencia artificial de Anthropic para tareas de ingeniería de software), bajo la dirección de un analista con experiencia real en sistemas bancarios.

Es una demostración práctica de cómo la IA puede acelerar el análisis, el desarrollo y la modernización de sistemas legacy en COBOL: partiendo de un programa mínimo de alta/depósito/extracción/consulta, se fue iterando —siempre con revisión humana en cada paso— hasta llegar a un sistema con estados de cliente, baja lógica y reactivación, un proceso batch de cierre con acreditación de interés, un programa de consulta de solo lectura, documentación de referencia de cómo correría el mismo batch en un mainframe z/OS real (JCL), una matriz de casos de prueba, y pruebas semi-automatizadas. En el camino se encontró y se corrigió, con evidencia reproducible, un bug real de generación de código del compilador GnuCOBOL 2.0 (ver [Programa interactivo: cuenta.cbl](#programa-cuenta)).

El código, la arquitectura y cada decisión de diseño fueron guiados y revisados por el autor; la IA se usó como herramienta de productividad para escribir, probar y documentar más rápido — no como reemplazo del criterio profesional.

<a id="descripcion-general"></a>
## Descripción general

`cuenta.cbl` es un programa COBOL interactivo (consola) para gestionar clientes y saldos de una cuenta bancaria simple. Es un ejemplo didáctico, pensado para mostrar patrones típicos de un sistema bancario legacy: archivos indexados, procesos batch nocturnos, y las decisiones de diseño (y las limitaciones) que eso implica.

Funciones del programa interactivo: **alta**, **modificación**, **baja lógica** y **reactivación** de clientes; **depósito**, **extracción** y **consulta de saldo**. Cada cliente tiene DNI, nombre, dirección, teléfono, saldo y **estado** (Activo / Inactivo / Reactivado). Los datos se guardan en un **archivo indexado** (`clientes_v3.dat`, clave = DNI) y sobreviven al cerrar y reabrir el programa.

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
- [Programa interactivo: cuenta.cbl](#programa-cuenta)
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
| `cuenta.cbl` | Programa interactivo (código fuente, formato fijo COBOL) — ver [Programa interactivo: cuenta.cbl](#programa-cuenta) |
| `BATCH-CIERRE.cbl` | Proceso batch de cierre: acredita interés mensual — ver [Proceso batch de cierre](#proceso-batch-cierre) |
| `LISTADO-CLIENTES.cbl` | Listado de consulta de **solo lectura**: no modifica datos — ver [Listado de clientes (solo lectura)](#listado-clientes) |
| `CLIENTE.cpy` | Copybook con el layout del registro de cliente, compartido por los tres programas de arriba |
| `correr_batch_cierre.bat` | Compila `BATCH-CIERRE.cbl` en `bin\` y lo ejecuta ahí |
| `ver_listado_clientes.bat` | Compila `LISTADO-CLIENTES.cbl` en `bin\` y lo ejecuta ahí |
| `correr_pruebas_automatizadas.bat` | Compila `cuenta.exe` en `bin\` y corre los 5 casos de prueba semi-automatizados — ver [Testing](#testing) |
| `batch_cierre.jcl` | JCL de **referencia/documentación**: cómo correría el mismo cierre en un mainframe z/OS real (no se ejecuta en este entorno) |
| `README.md` | Esta documentación |
| `CASOS_DE_PRUEBA.md` | Matriz de casos de prueba (QA) — ver [Testing](#testing) |
| `LICENSE` | Licencia del proyecto — ver [Licencia](#licencia) |
| `entrada_*.txt` | Entradas de los 5 casos de prueba semi-automatizados (`alta_ok`, `alta_dni_invalido`, `deposito`, `extraccion`, `consulta`) |
| `salida_*.txt` | Salidas correspondientes a cada `entrada_*.txt`, generadas al correr las pruebas |

**Se generan al compilar y ejecutar, dentro de `bin\`** (no forman parte del código fuente; ver [Compilación y ejecución](#compilacion-y-ejecucion)):

| Archivo (en `bin\`) | Descripción |
|----------------------|-------------|
| `cuenta.exe` | Ejecutable de `cuenta.cbl` |
| `BATCH-CIERRE.exe` | Ejecutable de `BATCH-CIERRE.cbl` |
| `LISTADO-CLIENTES.exe` | Ejecutable de `LISTADO-CLIENTES.cbl` |
| `clientes_v3.dat` | Archivo de datos indexado, compartido por los tres programas. **Se crea solo** en la primera ejecución de `cuenta.cbl` |
| `reporte_cierre.txt` | Reporte del cierre, generado por `BATCH-CIERRE.cbl` en cada corrida |
| `listado_clientes.txt` | Listado de clientes, generado por `LISTADO-CLIENTES.cbl` en cada corrida |

<a id="compilacion-y-ejecucion"></a>
## Compilación y ejecución

Escrito en COBOL de formato fijo. Los tres programas (`cuenta.cbl`, `BATCH-CIERRE.cbl`, `LISTADO-CLIENTES.cbl`) incluyen el layout del cliente con `COPY CLIENTE.`, así que **`CLIENTE.cpy` tiene que estar en la misma carpeta que el `.cbl`** al compilar cualquiera de los tres (no hace falta copiarlo a `bin\`: `cobc` lo busca junto al código fuente).

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

Los tres compilan el `.exe` directamente en `bin\` y lo ejecutan desde ahí, así que siempre apuntan a `bin\clientes_v3.dat`. `cuenta.cbl`, al no tener un `.bat` propio (es el programa de uso diario, pensado para dejarse abierto en el menú), hay que compilarlo y correrlo apuntando a `bin\` a mano (ver abajo) — o, más simple, usar OpenCobolIDE, que ya compila y corre con `bin\` como carpeta de trabajo por convención.

### Compilar a mano

Para compilar apuntando siempre a `bin\`:

```bash
cobc -x -Wall -o bin/cuenta cuenta.cbl                        # programa interactivo
cd bin && ./cuenta                                            # Windows: bin\cuenta.exe

cobc -x -Wall -o bin/BATCH-CIERRE BATCH-CIERRE.cbl            # batch de cierre
cd bin && ./BATCH-CIERRE                                      # Windows: bin\BATCH-CIERRE.exe

cobc -x -Wall -o bin/LISTADO-CLIENTES LISTADO-CLIENTES.cbl    # listado (solo lectura)
cd bin && ./LISTADO-CLIENTES                                  # Windows: bin\LISTADO-CLIENTES.exe
```

**Importante:** el `-o bin/programa` solo dice dónde queda el `.exe`; para que el programa *use* `bin\clientes_v3.dat` hay que **ejecutarlo con `bin\` como directorio de trabajo** (por eso el `cd bin` antes de correrlo). Compilar con `-o bin\cuenta.exe` pero correrlo desde la raíz (`bin\cuenta.exe` sin más) no alcanza: el archivo de datos se buscaría igual en la raíz.

En Windows, `correr_batch_cierre.bat` y `ver_listado_clientes.bat` hacen cada uno su bloque (compilar en `bin\` y ejecutar ahí) en un solo paso; no hace falta escribir estos comandos a mano para esos dos programas.

### Qué se probó

Probado con GnuCOBOL 2.0.0 (el que trae OpenCobolIDE): los tres programas compilan con `-Wall` sin errores ni warnings.

- **`cuenta.cbl`:** todas las opciones del menú, cada validación, el ciclo completo de estados (alta → baja → reactivación → baja), la restricción a clientes inactivos, el retorno al menú principal, la persistencia entre ejecuciones y el manejo de un archivo de datos corrupto.
- **`BATCH-CIERRE.cbl`:** el cálculo de interés sobre clientes Activos y Reactivados, la exclusión de Inactivos, el archivo de clientes inexistente (cartera vacía), y que `cuenta.cbl` sigue leyendo y escribiendo `clientes_v3.dat` correctamente después de una corrida del batch.
- **`LISTADO-CLIENTES.cbl`:** las tres secciones con una cartera mixta (Activos, Reactivados e Inactivos), el archivo inexistente (cartera vacía), que la pantalla y `listado_clientes.txt` muestran exactamente el mismo contenido, y —con un hash del archivo antes y después de correrlo— que `clientes_v3.dat` queda **byte a byte idéntico**.

<a id="programa-cuenta"></a>
## Programa interactivo: cuenta.cbl

### Menú principal

```
=== CUENTA BANCARIA ===
1 - Alta de cliente
2 - Modificar / Baja de cliente
3 - Deposito
4 - Extraccion
5 - Consulta de saldo
0 - Salir
```

| Opción | Qué hace |
|--------|----------|
| 1 | Registra un cliente (DNI, nombre, dirección, teléfono). Queda con saldo 0 y estado **A** (Activo) |
| 2 | Busca al cliente por DNI, muestra sus datos y permite **modificar** (o **reactivar**, si está inactivo) o dar de **baja** |
| 3 | Suma un monto al saldo. Bloqueado si el cliente está **inactivo** |
| 4 | Resta un monto del saldo (sin descubierto). Bloqueado si el cliente está **inactivo** |
| 5 | Muestra todos los datos del cliente, incluido el estado |
| 0 | Cierra el archivo y sale |

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
Que desea modificar?
1 - Direccion
2 - Telefono
3 - Saldo
4 - Terminar modificacion
Opcion:
```

Ejemplo, modificando dirección y saldo en la misma operación:

```
Opcion:
1
Direccion (hasta 40 caracteres):
Nueva 456
Dato modificado.

Que desea modificar?
1 - Direccion
2 - Telefono
3 - Saldo
4 - Terminar modificacion
Opcion:
3
Nuevo saldo (cero o mayor):
500
Dato modificado.

Que desea modificar?
...
Opcion:
4

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

Tanto la modificación (al elegir `4 - Terminar modificacion`) como la baja y la reactivación terminan mostrando los datos actualizados del cliente y **volviendo directamente al menú principal de 6 líneas** (1-Alta, 2-Modificar/Baja, 3-Depósito, 4-Extracción, 5-Consulta de saldo, 0-Salir). El único submenú que se repite es el de campos a modificar (`1`-`4`), y solo mientras se sigue eligiendo `1`, `2` o `3`; en cuanto se elige `4` no queda ningún submenú abierto.

### Depósito y extracción (opciones 3 y 4)

Flujo: DNI → búsqueda → **verificación de estado** → monto → operación.

- Cliente inexistente: `Cliente no encontrado.`
- Cliente inactivo (`I`): `Cliente inactivo: no se puede operar.` (no se pide el monto).
- Cliente activo (`A`) o reactivado (`R`): la operación continúa.
- Monto: mayor a cero, hasta 2 decimales.
- Depósito: el saldo resultante no puede desbordar el campo (`El saldo excede el maximo.`).
- Extracción: el monto no puede superar el saldo (`Saldo insuficiente.`).
- Si todo es válido, se graba y se muestra `Saldo actual: ...`.

<a id="validaciones-cuenta"></a>
### Validaciones

| Dato | Reglas |
|------|--------|
| **Opción del menú principal** | `1`–`5` o `0`; cualquier otro valor: `Opcion invalida.` |
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

Las líneas `1`, `12345678`, `Ana Perez`, etc. son lo que tipea el usuario.

```
Opcion:
1
DNI (8 digitos):
12345678
Nombre (hasta 30 caracteres):
Ana Perez
Direccion (hasta 40 caracteres):
Calle 1
Telefono (hasta 15 caracteres):
011 4444-5555
Cliente dado de alta.

=== CUENTA BANCARIA ===        <- vuelve al menu principal
...
Opcion:
2
DNI (8 digitos):
12345678
Nombre:    Ana Perez
DNI:       12345678
Direccion: Calle 1
Telefono:  011 4444-5555
Saldo:                0.00
Estado:    A - Activo
Desea (M)odificar o (B)aja el cliente?
B
Confirma la baja? (S/N):
S
Cliente dado de baja (estado Inactivo).

Datos actualizados del cliente:
Nombre:    Ana Perez
DNI:       12345678
Direccion: Calle 1
Telefono:  011 4444-5555
Saldo:                0.00
Estado:    I - Inactivo

=== CUENTA BANCARIA ===        <- vuelve al menu principal
...
Opcion:
3
DNI (8 digitos):
12345678
Cliente inactivo: no se puede operar.

=== CUENTA BANCARIA ===
...
Opcion:
2
DNI (8 digitos):
12345678
   (... muestra los datos, Estado: I - Inactivo ...)
Desea (M)odificar o (B)aja el cliente?
M
Cliente reactivado (estado R).

Datos actualizados del cliente:
Nombre:    Ana Perez
DNI:       12345678
Direccion: Calle 1
Telefono:  011 4444-5555
Saldo:                0.00
Estado:    R - Reactivado

=== CUENTA BANCARIA ===        <- vuelve al menu principal
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

### Estructura del programa

#### Divisiones

- **IDENTIFICATION DIVISION**: nombre del programa (`CUENTA`). Es lo único obligatorio. `AUTHOR` y `DATE-WRITTEN` están obsoletas (GnuCOBOL emite warning), por eso autor y fecha figuran en el comentario de cabecera.
- **ENVIRONMENT DIVISION**:
  - `SPECIAL-NAMES`: define la clase `CLASE-TELEFONO` (dígitos, `+`, `-`, `(`, `)` y espacio), usada para validar el teléfono con `IS NOT CLASE-TELEFONO`.
  - `INPUT-OUTPUT SECTION` / `FILE-CONTROL`: asocia `ARCH-CLIENTES` con `clientes_v3.dat` (indexado, clave `CLI-DNI`).
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
| | `OPC-SALIR` | `0` | Salir |
| `WS-OPC-MB` | `MB-MODIFICAR` | `M`, `m` | Modificar (o reactivar) |
| | `MB-BAJA` | `B`, `b` | Baja |
| `WS-CONFIRMA` | `CONFIRMA-SI` | `S`, `s` | Confirma la baja |
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
| `WS-OPCION` | `X` | Opción del menú principal |
| `WS-OPC-MB` | `X` | Respuesta a "Modificar o Baja" |
| `WS-CONFIRMA` | `X` | Respuesta S/N: confirmación de baja |
| `WS-OPC-MOD` | `X` | Opción del submenú de campos a modificar |
| `WS-CAMBIOS` | `9` | Cantidad de campos grabados en la sesión de modificación actual (decide el mensaje final) |
| `WS-FS` | `XX` | `FILE STATUS`; 88 `FS-OK` (`00`), `FS-CLAVE-DUPLICADA` (`22`), `FS-CLAVE-NO-ENC` (`23`), `FS-NO-EXISTE` (`35`) |
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
| `0000-PRINCIPAL` | Abre el archivo, repite el menú hasta elegir salir, cierra el archivo y ejecuta `STOP RUN` |
| `0100-ABRIR-ARCHIVO` / `0200-CERRAR-ARCHIVO` | Apertura (creándolo si no existe) y cierre |
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
| `6000-MODIFICACION` | Decide según el estado: `I` → `6500-REACTIVAR-CLIENTE`; `A` o `R` → `6100-MODIFICAR-DATOS` |
| `6100-MODIFICAR-DATOS` | Repite el submenú de campos (`6150`) hasta elegir Terminar; al salir, informa si no hubo cambios y muestra los datos actualizados |
| `6150-MENU-CAMPO` | Muestra el submenú `1-Dirección / 2-Teléfono / 3-Saldo / 4-Terminar`, pide el dato elegido, lo valida y llama a `6200` si es válido |
| `6200-GRABAR-CAMBIO` | `REWRITE` inmediato del campo recién cambiado, suma 1 a `WS-CAMBIOS` y confirma `Dato modificado.` |
| `6500-REACTIVAR-CLIENTE` | Pone estado `R`, hace `REWRITE` y muestra los datos actualizados |
| `7000-BAJA-CLIENTE` | Verifica que no esté ya inactivo y que el saldo sea cero |
| `7100-CONFIRMAR-BAJA` | Pide confirmación, pone estado `I`, hace `REWRITE` y muestra los datos actualizados |
| `8000-BUSCAR-CLIENTE` | `READ` por clave (DNI); marca encontrado / no encontrado |
| `8100-PEDIR-DNI` | Lectura y validación de DNI (`IS NUMERIC`, 8 dígitos) |
| `8200-PEDIR-MONTO` | Lectura de monto con `FUNCTION NUMVAL` y validación `> 0` |
| `8250-PEDIR-SALDO` / `8260-VALIDAR-SALDO-NUEVO` | Lectura del saldo nuevo con `TEST-NUMVAL` / validación de que no sea negativo |
| `8300-MOSTRAR-SALDO` | Muestra el saldo con el campo editado (depósito / extracción) |
| `8400-ACTUALIZAR-CLIENTE` | `REWRITE` del registro |
| `8500-PEDIR-NOMBRE` / `8600-PEDIR-DIRECCION` / `8700-PEDIR-TELEFONO` | Leen y validan cada texto (obligatorio, largo máximo) y lo dejan en `WS-NOMBRE` / `WS-DIRECCION` / `WS-TELEFONO` |
| `8710-VALIDAR-TELEFONO` | Verifica caracteres permitidos y mínimo de 6 dígitos |
| `8800-MOSTRAR-CLIENTE` | Muestra nombre, DNI, dirección, teléfono, saldo y estado (`A - Activo`, `I - Inactivo`, `R - Reactivado`) |
| `8900-VERIFICAR-ACTIVO` | Marca al cliente operable si su estado es `A` o `R`; si no, muestra `Cliente inactivo: no se puede operar.` |
| `9000-ERROR-ARCHIVO` | Informa operación, `FILE STATUS` y significado, y termina |

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
     └─ 0 → sale del bucle
```

#### Formato fijo: recordatorio de columnas

Aplica tanto a `cuenta.cbl` y `BATCH-CIERRE.cbl` como a `CLIENTE.cpy` (el `COPY` inserta el copybook tal cual, columna por columna, en el punto donde aparece `COPY CLIENTE.`).

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
- **Prompts con salto de línea.** No se usa `WITH NO ADVANCING`, porque ese texto puede no mostrarse mientras se espera la entrada (ver [Solución de problemas](#solucion-de-problemas)).
- **Archivo con versión en el nombre** (`_v3`), por los cambios de layout (ver «Por qué el archivo se llama `clientes_v3.dat`», en Persistencia).

<a id="proceso-batch-cierre"></a>
## Proceso batch de cierre: BATCH-CIERRE.cbl

`BATCH-CIERRE.cbl` es un programa COBOL **separado** de `cuenta.cbl` (no interactivo, sin menú) que recorre toda la cartera de clientes y acredita el interés mensual de las cuentas habilitadas para operar. Representa el tipo de proceso batch nocturno típico de un sistema bancario: correrlo es la forma de "cerrar el día" y actualizar los saldos con el interés devengado.

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

> **Nota técnica (para quien modifique `1200-ACREDITAR-INTERES`):** ese control de desborde usa un indicador propio (`WS-INTERES-OK`) y un `IF` después del `ADD`, en vez de poner la lógica directamente dentro de `ON SIZE ERROR` / `NOT ON SIZE ERROR`. Se probó así al principio y **GnuCOBOL 2.0 genera código incorrecto** cuando una sentencia aritmética (por ejemplo, otro `ADD`) queda dentro de la rama `ON SIZE ERROR` de un `ADD ... NOT ON SIZE ERROR`: la rama `NOT ON SIZE ERROR` (y todo lo que sigue en el párrafo) se salteaba en silencio incluso cuando no había ningún error. Se confirmó con un programa mínimo de 13 líneas que aísla el problema. `cuenta.cbl` no lo sufre porque su único `ON SIZE ERROR` (en el depósito) solo tiene un `DISPLAY`, sin aritmética adentro.

### Cómo ejecutarlo localmente

```bat
correr_batch_cierre.bat
```

El script:
1. Busca `cobc` en el `PATH`; si no lo encuentra, usa la instalación de OpenCobolIDE detectada en esta máquina (`C:\Program Files (x86)\OpenCobolIDE\GnuCOBOL`) como respaldo. Si tampoco la encuentra ahí, informa el error y no continúa.
2. Compila `BATCH-CIERRE.cbl` con `cobc -x -Wall` **dentro de `bin\`**.
3. Ejecuta `BATCH-CIERRE.exe` desde `bin\`, que procesa todo `bin\clientes_v3.dat`, genera `bin\reporte_cierre.txt` y termina mostrando un resumen por pantalla.

Se puede correr las veces que se quiera; cada corrida vuelve a acreditar interés sobre los saldos **ya actualizados** de la corrida anterior (ver [Limitaciones y mejoras futuras](#limitaciones-y-mejoras)). Si `clientes_v3.dat` todavía no existe (cartera vacía), el batch no falla: procesa cero clientes y genera igual un `reporte_cierre.txt` con todos los totales en cero.

### `reporte_cierre.txt`

Archivo de texto (secuencial, se sobreescribe en cada corrida) con, en este orden:

1. **Fecha del proceso**, tomada de `FUNCTION CURRENT-DATE`, en formato `DD/MM/AAAA`.
2. **Detalle de clientes procesados** (uno por línea, solo los `A`/`R`): DNI, nombre, saldo anterior, interés acreditado y saldo nuevo. Si no hay ninguno, dice explícitamente que no había clientes activos ni reactivados para procesar.
3. **Detalle de clientes Inactivos** (sin movimiento): DNI, nombre y saldo de cada cliente con estado `I`, sin columnas de interés ni saldo nuevo, porque no se les calcula nada. Si no hay ninguno, dice explícitamente que no hay clientes inactivos.
4. **Resumen final**: cantidad de clientes procesados (A/R), cantidad de inactivos excluidos, total de intereses acreditados y **saldo total de la cartera**, que suma los saldos de **todos** los clientes después del cierre —activos, reactivados e inactivos—, aunque a los inactivos no se les haya acreditado interés. (En la práctica, un cliente inactivo siempre tiene saldo 0, porque `cuenta.cbl` no permite dar de baja con saldo distinto de cero; pero el total se calcula sumando a todos igual, por las dudas.)

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

====================================================================================================
RESUMEN DEL CIERRE
====================================================================================================
Clientes procesados (Activos/Reactivados):          2
Clientes inactivos excluidos:                        1
Total de intereses acreditados:      $            52.50
Saldo total de la cartera:           $        10,553.05
====================================================================================================
```

El programa también muestra por pantalla un resumen breve equivalente, confirmando que se generó `reporte_cierre.txt`. Ese resumen de pantalla no cambia: sigue siendo solo los totales, sin el detalle línea por línea de ninguna de las dos tablas.

**Por qué el detalle de Activos y el de Inactivos van en dos bloques separados, no intercalados:** el batch recorre el archivo en orden de clave (DNI), y un cliente activo y uno inactivo pueden aparecer intercalados en ese orden. Como el reporte pide las dos tablas agrupadas, el programa hace **dos pasadas** sobre `clientes_v3.dat`: la primera actualiza los saldos y escribe la tabla de Activos/Reactivados; la segunda vuelve a abrir el archivo **solo para lectura** y arma la tabla de Inactivos. Ver `1000-LEER-Y-PROCESAR` (pasada 1) y `1500-LISTAR-INACTIVOS` (pasada 2) en `BATCH-CIERRE.cbl`.

### El copybook CLIENTE.cpy

`cuenta.cbl` y `BATCH-CIERRE.cbl` incluyen el layout del registro de cliente con `COPY CLIENTE.` en vez de declararlo cada uno por su cuenta, para que sea imposible que se desincronicen y terminen leyendo/escribiendo `clientes_v3.dat` con formatos distintos. **Los dos programas se recompilan siempre juntos** cuando cambia `CLIENTE.cpy`. Ver la tabla «Registro» y la nota «Por qué el archivo se llama `clientes_v3.dat`», en [Persistencia](#programa-cuenta), que siguen aplicando igual.

### El JCL de referencia (`batch_cierre.jcl`)

`batch_cierre.jcl` **no se ejecuta en este entorno** (Windows + GnuCOBOL no corre JCL). Es documentación: muestra cómo se vería este mismo proceso corriendo como un job batch nocturno en un mainframe z/OS real, con su JOB card, un `EXEC PGM=` para el programa ya compilado, y sentencias `DD` que representan el archivo de clientes como un **VSAM KSDS** (equivalente mainframe del archivo indexado `clientes_v3.dat`, clave = DNI) y el reporte de cierre como un **archivo secuencial** de salida (equivalente de `reporte_cierre.txt`). Cada bloque del JCL está comentado explicando qué hace y su correspondencia con el entorno local; el archivo mismo trae, al principio y al final, una tabla de equivalencias entre ambos entornos.

En este entorno de desarrollo local, el equivalente funcional de ese JCL es `correr_batch_cierre.bat`.

### ⚠ No correr `cuenta.exe` y el batch al mismo tiempo

**`cuenta.cbl` y `BATCH-CIERRE.cbl` no deben ejecutarse simultáneamente sobre el mismo `clientes_v3.dat`.** Ninguno de los dos programas implementa bloqueo de registros ni control de concurrencia (ver [Limitaciones y mejoras futuras](#limitaciones-y-mejoras)), así que correrlos al mismo tiempo puede producir:

- un `FILE STATUS` de "archivo en uso" (`61`) al intentar abrir el segundo programa,
- una condición de carrera si ambos leen y graban el mismo cliente casi a la vez, con el riesgo de que una de las dos escrituras se pierda.

Es el mismo comportamiento que tendría este proceso en un entorno de producción real: un cierre nocturno corre con el sistema transaccional (acá, `cuenta.cbl`) fuera de línea o en una ventana de mantenimiento, nunca en simultáneo. En este entorno local, la forma práctica de respetarlo es simplemente no tener `cuenta.exe` abierto (esperando en el menú) mientras se corre `correr_batch_cierre.bat`, y viceversa. Esto vale para las **dos** pasadas que hace el batch sobre el archivo, no solo para la primera.

<a id="listado-clientes"></a>
## Listado de clientes (solo lectura): LISTADO-CLIENTES.cbl

`LISTADO-CLIENTES.cbl` es un tercer programa, también separado de `cuenta.cbl` y de `BATCH-CIERRE.cbl`, para **consultar** la cartera completa sin operar sobre ella. A diferencia del batch de cierre, **este programa nunca modifica nada**: no acredita interés, no cambia estados, no toca saldos.

### Por qué es seguro correrlo en cualquier momento

- Abre `clientes_v3.dat` únicamente con `OPEN INPUT` (solo lectura). En ningún punto del código hay un `OPEN I-O`, un `OPEN OUTPUT`, ni una sentencia `WRITE`, `REWRITE` o `DELETE` sobre ese archivo.
- Se verificó tomando un hash del archivo antes y después de correr el programa (incluso dos veces seguidas): **queda byte a byte idéntico**.
- Por esto no tiene la misma restricción de "no correr al mismo tiempo" que `BATCH-CIERRE.cbl`: como no escribe, no hay riesgo de perder una actualización. Aun así, para no arrastrar un `FILE STATUS` de "archivo en uso" (`61`) si `cuenta.cbl` tiene el archivo abierto en ese instante puntual, lo más prolijo sigue siendo correrlo con `cuenta.exe` en el menú principal (no a mitad de una operación).

### Qué muestra

El listado agrupa a los clientes en tres secciones, en este orden, y termina con un resumen:

1. **Clientes Activos (A)**
2. **Clientes Reactivados (R)**
3. **Clientes Inactivos (I)**

En cada sección, un bloque por cliente con DNI, Nombre, Dirección, Teléfono, Saldo y Estado (el mismo formato de bloque que ya usa `cuenta.cbl` en su consulta). Si una sección no tiene clientes, lo dice explícitamente en vez de quedar vacía sin explicación.

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

El documento **[`CASOS_DE_PRUEBA.md`](CASOS_DE_PRUEBA.md)** tiene la matriz de casos de prueba (QA) del proyecto: 12 casos con columnas ID, Módulo, Escenario, Pasos a seguir, Resultado esperado, Resultado obtenido (para completar a mano en cada corrida) y Observaciones. Cubre alta, depósito, extracción, consulta, modificación, baja, reactivación y el batch de cierre, incluyendo casos negativos (DNI inválido, fondos insuficientes, cliente inexistente, operar sobre un cliente inactivo).

### Casos automatizados (semi-automatizados)

Los cinco casos más simples y lineales de esa matriz —sin ramificaciones ni confirmaciones S/N— están automatizados con archivos de entrada que simulan lo que un usuario tipearía en el menú:

| Caso | Entrada | Salida | Cubre |
|------|---------|--------|-------|
| CP-01 | `entrada_alta_ok.txt` | `salida_alta_ok.txt` | Alta exitosa, Estado queda en `A` |
| CP-02 | `entrada_alta_dni_invalido.txt` | `salida_alta_dni_invalido.txt` | Alta rechazada con DNI de menos de 8 dígitos y con DNI no numérico |
| CP-03 | `entrada_deposito.txt` | `salida_deposito.txt` | Depósito exitoso a un cliente Activo |
| CP-04 | `entrada_extraccion.txt` | `salida_extraccion.txt` | Extracción exitosa (fondos suficientes) |
| CP-06 | `entrada_consulta.txt` | `salida_consulta.txt` | Consulta muestra todos los datos, incluido Estado |

### Cómo correrlos

La forma más simple y confiable:

```bat
correr_pruebas_automatizadas.bat
```

Compila `cuenta.exe` **en `bin\`** y corre ahí los 5 pares entrada/salida (leyendo cada `entrada_*.txt` y escribiendo cada `salida_*.txt` en la raíz del proyecto), con el runtime de GnuCOBOL correctamente puesto en el `PATH` para esa sesión (mismo mecanismo de respaldo que `correr_batch_cierre.bat` y `ver_listado_clientes.bat`).

También se puede correr cada caso a mano, uno por uno, desde `bin\`:

```bat
cd bin
cuenta.exe < ..\entrada_alta_ok.txt > ..\salida_alta_ok.txt
```

Y así con cada par. **Para esto, el `PATH` de esa terminal tiene que incluir el runtime de GnuCOBOL** (lo mismo que hace falta para compilar); si no, `cuenta.exe` falla al arrancar sin mostrar ningún error y el `salida_*.txt` queda en 0 bytes — ver [Solución de problemas](#solucion-de-problemas), «El archivo de salida queda en 0 bytes al redirigir la entrada». Por eso conviene usar `correr_pruebas_automatizadas.bat`, que ya se ocupa de eso.

Cada `entrada_*.txt` es autocontenido (da de alta su propio cliente de prueba, con un DNI dedicado en el rango `800000XX` para no chocar con los DNIs que usa la matriz manual) y **termina siempre en `0`**, la opción de salir del menú: es necesario para que no quede colgado, porque una entrada redirigida por archivo que se queda sin líneas antes de un `0` no corta sola (ver [Solución de problemas](#solucion-de-problemas), «Si la entrada se redirige…»).

Después de correr uno, conviene abrir el `salida_*.txt` correspondiente y comparar a mano contra el "Resultado esperado" de esa fila en `CASOS_DE_PRUEBA.md`; no hay un comparador automático de resultados en este proyecto. Si `clientes_v3.dat` ya tiene un cliente con ese mismo DNI de una corrida anterior, el script no falla, pero la salida cambia (por ejemplo, `entrada_alta_ok.txt` mostraría `Ya existe un cliente con ese DNI.` en vez de `Cliente dado de alta.`); para una corrida "limpia" de los cinco casos, borrar `bin\clientes_v3.dat` antes.

Los siete casos restantes (CP-05, CP-07 a CP-12) quedan como pruebas manuales en `CASOS_DE_PRUEBA.md`: tienen ramificaciones (confirmaciones S/N, submenús, un estado previo que hay que preparar, o el batch de cierre) que no se prestan a una sola pasada de entrada redirigida.

<a id="solucion-de-problemas"></a>
## Solución de problemas

**Parece colgado después de ingresar un dato (no aparece el siguiente prompt).** Con `DISPLAY "..." WITH NO ADVANCING`, cuando la salida no va a una consola real (por ejemplo el panel de un IDE, o salida redirigida), el texto puede no mostrarse mientras el programa espera en un `ACCEPT`: el programa no está colgado, espera datos que el usuario no sabe que debe ingresar. Por eso todos los prompts terminan en salto de línea y lo tipeado va en la línea siguiente.

**Elegí la opción 2 y me pide un DNI, no `M` o `B`.** Es lo esperado: primero se pide el DNI y se muestran los datos; la pregunta `M`/`B` viene después.

**Elegí `M` sobre un cliente y no me deja cambiar la dirección / el teléfono / el saldo, solo dice que lo reactivó.** El cliente estaba inactivo (`I`). Para un cliente inactivo la única acción de `M` es reactivarlo. Una vez reactivado (`R`), volvé a elegir la opción 2 → `M` para modificar sus datos.

**Modifiqué un dato pero el programa dice `No se modifico ningun dato.`** No debería pasar: ese mensaje solo aparece si, al elegir `4 - Terminar modificacion`, no se grabó ningún campo en esa sesión (por ejemplo, si todos los intentos fueron inválidos o si se eligió `4` de entrada). Cada campo válido se graba y confirma con `Dato modificado.` apenas se ingresa, antes de volver a mostrar el submenú; si ese mensaje no apareció para un campo, revisar si el dato fue rechazado por alguna validación (ver la tabla de [Validaciones](#validaciones-cuenta)).

**Un cliente no puede depositar ni extraer.** Probablemente está inactivo (`Cliente inactivo: no se puede operar.`). Ver el estado con la opción 5 y, si corresponde, reactivarlo con la opción 2 → `M`.

**`clientes_v3.dat` corrupto o de otra versión.** El programa lo informa (por ejemplo `FILE STATUS: 30`) y termina. Borrar `clientes_v3.dat` para que se cree de nuevo (se pierden los datos guardados).

**Aparecen clientes "que no existen" o no aparecen los que cargué.** Probablemente se está ejecutando desde otra carpeta y se está usando otro `clientes_v3.dat` (ver «Dónde vive `clientes_v3.dat`», en [Compilación y ejecución](#compilacion-y-ejecucion)), o los clientes se cargaron con una versión anterior del programa (archivo distinto).

**El archivo de salida queda en 0 bytes al redirigir la entrada (`cuenta.exe < entrada.txt > salida.txt`), sin ningún mensaje de error.** No es un problema de *buffering* del `DISPLAY` ni hace falta tocar `cuenta.cbl`: es que `cuenta.exe` no encuentra el runtime de GnuCOBOL (`libcob` y sus DLL) en el `PATH` de esa terminal. Windows falla al arrancar el programa (`STATUS_DLL_NOT_FOUND`, código de salida `-1073741515`) **sin mostrar ningún texto de error** en pantalla; pero `cmd` ya había creado el archivo de salida (vacío) al armar la redirección, así que el único síntoma visible es un archivo de 0 bytes. Se confirmó reproduciéndolo: la *misma* terminal, el *mismo* comando, con y sin el `PATH` del runtime, da exactamente `0 bytes` / archivo completo según corresponda.

- Cómo verificarlo: después de correr el comando, mirar el código de salida (`echo %ERRORLEVEL%` en `cmd`, o `$LASTEXITCODE` en PowerShell). Un número muy negativo (o `-1073741515` puntualmente) confirma este diagnóstico; `0` significa que sí corrió.
- Solución recomendada: usar **`correr_pruebas_automatizadas.bat`** para los 5 casos semi-automatizados (ver [Testing](#testing)), que ya deja el `PATH` bien puesto para esa corrida, igual que `correr_batch_cierre.bat` y `ver_listado_clientes.bat` lo hacen para sus programas.
- Si se prefiere correr `cuenta.exe < entrada.txt > salida.txt` a mano, hay que asegurarse de que la terminal tenga el runtime de GnuCOBOL en el `PATH` (lo mismo que hace falta para compilar con `cobc`); si se compiló en una terminal y se corre en otra sin ese `PATH`, pasa esto.

<a id="limitaciones-y-mejoras"></a>
## Limitaciones y mejoras futuras

### Limitaciones de `cuenta.cbl`

- La modificación del **saldo** permite fijar cualquier valor válido sin dejar registro: no hay historial ni auditoría de movimientos. El nombre, el DNI y el estado no se pueden editar por esa vía.
- La reactivación no pide confirmación ni deja constancia de cuándo ni por qué se hizo.
- El estado `R` no distingue cuántas veces se reactivó un cliente ni se puede volver a `A`.
- Un DNI dado de baja (`I`) sigue ocupado: no se puede reutilizar en un alta, solo reactivar al cliente.
- Un solo usuario a la vez: no hay bloqueo de registros ni control de concurrencia. Esto incluye a `BATCH-CIERRE.cbl` (ver «No correr `cuenta.exe` y el batch al mismo tiempo», en [Proceso batch de cierre](#proceso-batch-cierre)).
- Si el programa se interrumpe de forma abrupta con el archivo abierto, éste podría quedar inconsistente; no hay respaldo ni recuperación.
- Sin autenticación ni historial de movimientos: solo se guarda el saldo actual.
- Sin migración desde los archivos de versiones anteriores (`clientes.dat`, `clientes_v2.dat`).
- El DNI y el nombre no se pueden corregir; ante un error hay que dar de baja (lógica) y usar otro DNI, o borrar el archivo.
- Un monto o saldo con más de 2 decimales se **trunca** (`10.999` pasa a `10.99`); el punto decimal debe ser `.`.
- Un dato inválido en el alta cancela toda la operación (no se vuelve a pedir el campo); una respuesta distinta de `M`/`B` en la opción 2 también vuelve al menú sin repetir la pregunta.
- Si la entrada se redirige desde un archivo o pipe y termina sin un `0` de salida, el programa no detecta el fin de entrada y repite el menú. Con teclado no ocurre.
- No hay monedas múltiples.

### Limitaciones de `BATCH-CIERRE.cbl`

- **Sin control de corridas duplicadas.** Nada impide correr el batch dos veces el mismo día; cada corrida vuelve a acreditar interés sobre el saldo ya actualizado (interés compuesto entre corridas, aunque simple dentro de una misma corrida). En un entorno real, el scheduler (o el propio JCL) garantizaría una sola corrida por período.
- **Tasa fija en el código.** Cambiarla requiere editar `WS-TASA-INTERES` y recompilar; no se lee de un archivo de parámetros ni se puede pasar por línea de comandos.
- **Reporte no acumulativo.** `reporte_cierre.txt` se sobreescribe en cada corrida; no queda un historial local de cierres anteriores (a diferencia del JCL de referencia, que documenta un dataset generacional (GDG) para eso).
- **Sin control de concurrencia con `cuenta.cbl`.** Ver «No correr `cuenta.exe` y el batch al mismo tiempo», en [Proceso batch de cierre](#proceso-batch-cierre).
- **No hay historial de movimientos.** El interés acreditado queda en el reporte de esa corrida, pero no se guarda en el archivo de clientes como un movimiento separado; solo se ve reflejado en el saldo.

### Posibles mejoras futuras

Cada limitación de arriba sugiere una mejora natural. Algunas, en orden aproximado de impacto/esfuerzo:

- **Historial de movimientos.** Un archivo de transacciones (depósitos, extracciones, modificaciones, intereses) separado del maestro de clientes, para auditoría y para poder reconstruir cómo se llegó a un saldo.
- **Control de corridas del batch.** Un archivo o registro de "último cierre corrido" que rechace o avise ante una segunda corrida del mismo período.
- **Parametrizar la tasa de interés.** Leerla de un archivo o de un parámetro de ejecución en vez de tenerla fija en `WORKING-STORAGE`, para no depender de recompilar.
- **Migración automática entre versiones del archivo.** Un programa que lea `clientes_v2.dat` (o `clientes.dat`) y regrabe los registros en el formato actual, en vez de tener que dar de alta a mano.
- **Bloqueo de registros / control de concurrencia real.** Para que `cuenta.cbl` y `BATCH-CIERRE.cbl` puedan convivir sin la restricción manual de "no correrlos juntos" — en GnuCOBOL, vía `LOCK` en el `OPEN`, o una cola de trabajos si se migrara a una arquitectura cliente-servidor.
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
