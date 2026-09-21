# CUENTA – Gestión simple de cuentas bancarias en COBOL

Programa COBOL interactivo (consola) que permite dar de alta clientes, depositar, extraer y consultar saldos. Es un ejemplo didáctico: los datos se guardan **solo en memoria** y se pierden al salir.

## Archivos

| Archivo      | Descripción                          |
|--------------|--------------------------------------|
| `cuenta.cbl` | Código fuente (formato fijo COBOL)   |
| `README.md`  | Esta documentación                   |

## Requisitos, compilación y ejecución

Escrito en COBOL estándar de formato fijo; pensado para [GnuCOBOL](https://gnucobol.sourceforge.io/) 3.x.

```bash
cobc -x -o cuenta cuenta.cbl    # compila a ejecutable
./cuenta                        # Windows: cuenta.exe
```

> Nota: el código no fue compilado en el entorno donde se generó (no había `cobc` instalado); conviene compilarlo y probarlo antes de usarlo.

## Funcionalidad

```
=== CUENTA BANCARIA ===
1 - Alta de cliente
2 - Deposito
3 - Extraccion
4 - Consulta de saldo
0 - Salir
```

| Opción | Qué hace | Validaciones |
|--------|----------|--------------|
| 1 | Registra un cliente (DNI + nombre) con saldo 0 | DNI de 8 dígitos; DNI no repetido; nombre no vacío; tabla no llena |
| 2 | Suma un monto al saldo del cliente | Cliente existente; monto > 0; el saldo no puede desbordar el campo |
| 3 | Resta un monto del saldo | Cliente existente; monto > 0; monto ≤ saldo (no hay descubierto) |
| 4 | Muestra nombre y saldo | Cliente existente |

### Ejemplo de sesión

```
Opcion: 1
DNI (8 digitos): 12345678
Nombre: Ana Perez
Cliente dado de alta.

Opcion: 2
DNI (8 digitos): 12345678
Monto: 1500.50
Saldo actual:       1,500.50

Opcion: 3
DNI (8 digitos): 12345678
Monto: 2000
Saldo insuficiente.
```

## Estructura del programa

### Divisiones

- **IDENTIFICATION DIVISION**: nombre del programa (`CUENTA`). Es lo único obligatorio. Las cláusulas `AUTHOR` y `DATE-WRITTEN` están obsoletas (GnuCOBOL emite warning), por eso autor y fecha figuran en el comentario de cabecera.
- **ENVIRONMENT DIVISION**: entorno de compilación/ejecución. No declara archivos porque no hay persistencia.
- **DATA DIVISION / WORKING-STORAGE SECTION**: todas las variables (ver abajo).
- **PROCEDURE DIVISION**: la lógica, organizada en párrafos.

### Datos principales (WORKING-STORAGE)

| Variable | PIC | Uso |
|----------|-----|-----|
| `WS-OPCION` | `X` | Opción del menú; con nombres de condición nivel 88 (`OPC-ALTA`, `OPC-SALIR`, …) |
| `WS-TABLA-CLIENTES` | – | Tabla de 100 clientes (`OCCURS 100 TIMES`) |
| `CLI-DNI` | `9(8)` | DNI del cliente (clave de búsqueda) |
| `CLI-NOMBRE` | `X(30)` | Nombre del cliente |
| `CLI-SALDO` | `S9(9)V99` | Saldo con signo y 2 decimales implícitos |
| `WS-CANT-CLIENTES` / `WS-MAX-CLIENTES` | `999` | Clientes cargados / capacidad de la tabla |
| `WS-DNI-TXT`, `WS-MONTO-TXT` | `X(8)`, `X(15)` | Entrada cruda del usuario, antes de validar |
| `WS-DNI`, `WS-MONTO` | `9(8)`, `S9(9)V99` | Valores ya validados y convertidos |
| `WS-POS` | `999` | Posición del cliente hallado en la tabla (0 = no existe) |
| `WS-SALDO-EDIT` | `-ZZZ,ZZZ,ZZ9.99` | Campo editado para mostrar el saldo con formato |
| `WS-DNI-OK`, `WS-MONTO-OK` | `X` | Indicadores S/N con condiciones 88 (`DNI-VALIDO`, `MONTO-VALIDO`, …) |

### Párrafos de la PROCEDURE DIVISION

| Párrafo | Responsabilidad |
|---------|-----------------|
| `0000-PRINCIPAL` | Repite el menú hasta elegir salir y ejecuta `STOP RUN` |
| `1000-PROCESAR-MENU` | Lee la opción y despacha con `EVALUATE TRUE` |
| `1100-MOSTRAR-MENU` | Imprime el menú |
| `2000-ALTA-CLIENTE` / `2100-REGISTRAR-CLIENTE` | Alta de cliente |
| `3000-DEPOSITO` | Depósito |
| `4000-EXTRACCION` | Extracción |
| `5000-CONSULTA-SALDO` | Consulta |
| `8000-BUSCAR-CLIENTE` | Búsqueda lineal por DNI; devuelve `WS-POS` |
| `8100-PEDIR-DNI` | Lectura y validación de DNI (`IS NUMERIC`) |
| `8200-PEDIR-MONTO` | Lectura de monto con `FUNCTION NUMVAL` y validación `> 0` |
| `8300-MOSTRAR-SALDO` | Muestra el saldo usando el campo editado |

La numeración agrupa los párrafos: 1xxx menú, 2xxx–5xxx operaciones, 8xxx rutinas compartidas.

## Decisiones de diseño

- **Entrada como texto y validación explícita.** Todo se lee en campos alfanuméricos y se convierte después, para que un dato inválido nunca deje basura en un campo numérico.
- **`COMPUTE ... ON SIZE ERROR` / `ADD ... ON SIZE ERROR`.** Evitan truncamientos silenciosos ante montos o saldos demasiado grandes.
- **Aritmética decimal.** `PIC S9(9)V99` usa decimales exactos (sin errores de punto flotante), lo habitual para dinero en COBOL.
- **Sin descubierto.** La extracción se rechaza si el monto supera el saldo.

## Limitaciones conocidas

- Sin persistencia: al cerrar el programa se pierden todos los clientes. Una evolución natural es un archivo `INDEXED` (clave `CLI-DNI`) o `LINE SEQUENTIAL`.
- Máximo 100 clientes; la búsqueda es lineal (suficiente para ese tamaño).
- Sin autenticación ni registro de movimientos (historial/auditoría).
- Un monto con más de 2 decimales se **trunca** (p. ej. `10.999` pasa a `10.99`).
- El punto decimal debe ingresarse como `.` (no se usa `DECIMAL-POINT IS COMMA`).
- No hay cierre de sesión ni monedas múltiples.

## Formato fijo: recordatorio de columnas

| Columnas | Contenido |
|----------|-----------|
| 1–6 | Números de secuencia (no usados) |
| 7 | `*` = comentario |
| 8–11 | Área A: divisiones, secciones, párrafos, niveles 01 |
| 12–72 | Área B: sentencias y resto de las entradas |
| 73+ | Ignorado por el compilador |
