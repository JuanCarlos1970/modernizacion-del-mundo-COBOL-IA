# Casos de prueba — CUENTA BANCARIA

Matriz de casos de prueba (QA) para `cuenta.cbl` (programa interactivo) y `BATCH-CIERRE.cbl` (proceso batch de cierre). Complementa a `README.md`; no repite ahí la documentación técnica, solo la referencia cuando hace falta.

## Alcance

Cubre las operaciones principales del menú (alta, depósito, extracción, consulta, modificación, baja, reactivación) y el proceso batch de cierre. No es un reemplazo de una suite de pruebas automatizada completa: los casos lineales más simples están automatizados (ver [Testing](README.md#testing) en el README); el resto son casos manuales, pensados para ejecutarse a mano siguiendo los pasos indicados.

## Requisitos previos

- `cuenta.exe` compilado **en `bin\`** (ver README.md, sección "Dónde vive `clientes_v3.dat`"; usar `cobc -x -Wall -o bin\cuenta.exe cuenta.cbl`, con `CLIENTE.cpy` en la misma carpeta que `cuenta.cbl`). Todos los casos de esta matriz, automatizados o manuales, se corren contra **`bin\clientes_v3.dat`** — el mismo archivo que se usa siempre, no uno aparte.
- Para el caso de batch (CP-12), además `BATCH-CIERRE.exe` compilado en `bin\`, o usar `correr_batch_cierre.bat`.
- Los pasos manuales (todos salvo CP-01 a CP-04 y CP-06) se ejecutan corriendo `cuenta.exe` **desde `bin\`** (por ejemplo, `cd bin` y después `cuenta.exe`, o abriendo el proyecto en OpenCobolIDE, que ya usa `bin\` como carpeta de trabajo).
- Para los 5 casos automatizados (CP-01, CP-02, CP-03, CP-04, CP-06): la terminal donde se corre `cuenta.exe < entrada.txt > salida.txt` tiene que tener el runtime de GnuCOBOL en el `PATH`; si no, el programa falla al arrancar sin mostrar ningún error y la salida queda en 0 bytes (ver README.md, sección "Solución de problemas"). Para evitar ese problema, usar **`correr_pruebas_automatizadas.bat`**, que ya compila y corre en `bin\` con el `PATH` resuelto.

## Convención de datos de prueba

Cada caso usa un **DNI dedicado**, para poder ejecutarlos en cualquier orden sobre el mismo `clientes_v3.dat` sin que se pisen entre sí ni con los scripts automatizados (que usan DNIs `800000XX`, ver [Testing](README.md#testing)):

| Caso | DNI de prueba | Notas |
|------|----------------|-------|
| CP-01 | `90000001` | |
| CP-02 | *(sin alta real; DNIs inválidos)* | |
| CP-03 | `90000003` | |
| CP-04 | `90000004` | |
| CP-05 | `90000005` | |
| CP-06 | `90000006` | |
| CP-07 | `90099999` | debe **no** existir en ningún otro caso |
| CP-08 | `90000008` | |
| CP-09 | `90000009` | |
| CP-10 | `90000009` (o el que reutilice de CP-09) | requiere un cliente ya Inactivo |
| CP-11 | `90000011` | |
| CP-12 | `90000020` (Activo) y `90000021` (Inactivo) | cartera dedicada para el batch |

Si se prefiere partir de una cartera limpia para una pasada completa de regresión, basta con borrar `clientes_v3.dat` antes de empezar (se vuelve a crear solo).

## Cómo usar esta matriz

- **Pasos a seguir** da los datos exactos (DNI, montos, opciones de menú) para que el caso sea reproducible tal cual.
- **Resultado esperado** es lo que definimos que el programa *debe* hacer, verificado contra el comportamiento real del programa al momento de escribir este documento.
- **Resultado obtenido** queda vacío a propósito: se completa a mano en cada corrida (OK / Falló + qué pasó).
- **Observaciones** indica si el caso está automatizado (y con qué archivo) o es manual, más cualquier aclaración.

## Matriz de casos de prueba

| ID | Módulo | Escenario | Pasos a seguir | Resultado esperado | Resultado obtenido | Observaciones |
|----|--------|-----------|-----------------|---------------------|---------------------|----------------|
| CP-01 | Alta | Alta de cliente nuevo exitosa (Estado queda en A) | 1. Opción `1`.<br>2. DNI `90000001`.<br>3. Nombre `Elena Alta`.<br>4. Dirección `Av. Prueba 100`.<br>5. Teléfono `011 4000-0001`.<br>6. Opción `5`, DNI `90000001`.<br>7. Opción `0`. | Tras el paso 5 se muestra `Cliente dado de alta.`. La consulta del paso 6 muestra los datos cargados, `Saldo: 0.00` y `Estado: A - Activo`. |  | Automatizado: `entrada_alta_ok.txt` / `salida_alta_ok.txt` (con DNI `80000001`). |
| CP-02 | Alta | Alta con DNI inválido (menos de 8 dígitos o no numérico) | 1. Opción `1`.<br>2. DNI `1234567` (7 dígitos).<br>3. Verificar mensaje y que vuelve al menú sin pedir más datos.<br>4. Opción `1` de nuevo.<br>5. DNI `ABCDEFGH` (no numérico).<br>6. Verificar mensaje.<br>7. Opción `0`. | En los dos intentos: `DNI invalido: deben ser 8 digitos.`, y el programa vuelve directo al menú principal sin pedir Nombre/Dirección/Teléfono. No se da de alta ningún cliente. |  | Automatizado: `entrada_alta_dni_invalido.txt` / `salida_alta_dni_invalido.txt`. |
| CP-03 | Depósito | Depósito exitoso a un cliente Activo | 1. Dar de alta DNI `90000003` (saldo inicial 0).<br>2. Opción `3`, DNI `90000003`, monto `500.75`.<br>3. Opción `5`, DNI `90000003`.<br>4. Opción `0`. | Tras el depósito: `Saldo actual: 500.75`. La consulta confirma `Saldo: 500.75` y `Estado: A - Activo`. |  | Automatizado: `entrada_deposito.txt` / `salida_deposito.txt` (con DNI `80000003`). |
| CP-04 | Extracción | Extracción exitosa a un cliente Activo (fondos suficientes) | 1. Dar de alta DNI `90000004` y depositarle `1000`.<br>2. Opción `4`, DNI `90000004`, monto `250.50`.<br>3. Opción `5`, DNI `90000004`.<br>4. Opción `0`. | Tras la extracción: `Saldo actual: 749.50` (1000,00 − 250,50), sin rechazo. |  | Automatizado: `entrada_extraccion.txt` / `salida_extraccion.txt` (con DNI `80000004`). |
| CP-05 | Extracción | Extracción rechazada por fondos insuficientes | 1. Dar de alta DNI `90000005` (saldo 0, sin depositar).<br>2. Opción `4`, DNI `90000005`, monto `100`.<br>3. Opción `5`, DNI `90000005`, verificar que el saldo sigue en 0.<br>4. Opción `0`. | El programa muestra `Saldo insuficiente.` y **no** modifica el saldo del cliente. |  | Caso manual (no automatizado). |
| CP-06 | Consulta | Consulta de saldo muestra todos los datos correctos, incluido Estado | 1. Dar de alta DNI `90000006` con nombre, dirección y teléfono conocidos.<br>2. Opción `5`, DNI `90000006`.<br>3. Opción `0`. | Se muestran, en orden, Nombre, DNI, Dirección, Teléfono, `Saldo: 0.00` y `Estado: A - Activo`, todos coincidiendo con lo cargado. |  | Automatizado: `entrada_consulta.txt` / `salida_consulta.txt` (con DNI `80000006`). |
| CP-07 | Modificar / Baja | Opción 2 con DNI inexistente ("Cliente no encontrado") | 1. Opción `2`.<br>2. DNI `90099999` (no dado de alta en ningún otro caso).<br>3. Verificar mensaje y que vuelve al menú sin preguntar M/B.<br>4. Opción `0`. | El programa muestra `Cliente no encontrado.` y vuelve directo al menú principal; **no** llega a preguntar `Desea (M)odificar o (B)aja el cliente?`. |  | Caso manual (no automatizado). |
| CP-08 | Modificar / Baja | Modificación (M) de un cliente Activo: Dirección, Teléfono y Saldo vía el submenú de campos | 1. Dar de alta DNI `90000008` (Activo).<br>2. Opción `2`, DNI `90000008`; verificar los datos actuales.<br>3. Responder `M`.<br>4. Submenú, opción `1` (Dirección), ingresar `Nueva Direccion 500`; verificar `Dato modificado.` y que el submenú vuelve a aparecer.<br>5. Opción `2` (Teléfono), ingresar `011 5000-0008`.<br>6. Opción `3` (Saldo), ingresar `1000`.<br>7. Opción `4` (Terminar modificación).<br>8. Opción `5`, DNI `90000008`, confirmar los tres cambios.<br>9. Opción `0`. | Cada campo modificado se confirma al instante con `Dato modificado.`. Al elegir `4` se muestran los `Datos actualizados del cliente:` con `Direccion: Nueva Direccion 500`, `Telefono: 011 5000-0008` y `Saldo: 1,000.00`; `Estado` sigue en `A - Activo` (no cambia). La consulta del paso 8 confirma los tres valores. |  | Caso manual (no automatizado; flujo con ramificaciones). |
| CP-09 | Modificar / Baja | Baja (B) de un cliente Activo (pasa a Estado I) | 1. Dar de alta DNI `90000009`, sin depositar nada (saldo 0, requisito para poder dar de baja).<br>2. Opción `2`, DNI `90000009`.<br>3. Responder `B`.<br>4. Confirmar con `S` en `Confirma la baja? (S/N):`.<br>5. Opción `5`, DNI `90000009`, confirmar el Estado.<br>6. Opción `0`. | El programa muestra `Cliente dado de baja (estado Inactivo).` y los datos actualizados con `Estado: I - Inactivo`. El registro **no** se elimina: la consulta del paso 5 lo sigue mostrando con sus mismos datos y saldo 0. |  | Caso manual (no automatizado). |
| CP-10 | Depósito / Extracción | Depósito y Extracción bloqueados sobre un cliente Inactivo | 1. Usar un cliente ya Inactivo (por ejemplo, el de CP-09, DNI `90000009`).<br>2. Opción `3`, DNI `90000009`; verificar que se bloquea **sin pedir el monto**.<br>3. Opción `4`, mismo DNI; verificar que también se bloquea sin pedir el monto.<br>4. Opción `0`. | En los dos casos el programa muestra `Cliente inactivo: no se puede operar.` inmediatamente después de encontrar al cliente, sin llegar a pedir `Monto:`. El saldo no cambia. |  | Caso manual (no automatizado). |
| CP-11 | Modificar / Baja | Modificación (M) sobre un cliente Inactivo: reactiva a Estado R directamente, sin preguntar por otros campos | 1. Dar de alta DNI `90000011` y darlo de baja (como en CP-09), para que quede Inactivo.<br>2. Opción `2`, DNI `90000011`; verificar `Estado: I - Inactivo`.<br>3. Responder `M`.<br>4. Verificar que **no** se ofrece el submenú de Dirección/Teléfono/Saldo.<br>5. Opción `5`, DNI `90000011`, confirmar el Estado.<br>6. Opción `0`. | El programa muestra `Cliente reactivado (estado R).` sin preguntar nada más (ni submenú ni confirmación), y los datos actualizados muestran `Estado: R - Reactivado`. Dirección, Teléfono y Saldo quedan exactamente igual que antes de la reactivación. |  | Caso manual (no automatizado). |
| CP-12 | Batch de Cierre | Interés acreditado a Activos/Reactivados; Inactivos excluidos del cálculo pero listados en el reporte; totales del resumen correctos | 1. Con `cuenta.exe`: dar de alta DNI `90000020` (Activo) y depositarle `10000`.<br>2. Dar de alta DNI `90000021` y darlo de baja (Inactivo, saldo 0).<br>3. Anotar el saldo de `90000020` antes del cierre.<br>4. Ejecutar `correr_batch_cierre.bat` (o `BATCH-CIERRE.exe` ya compilado).<br>5. Abrir `reporte_cierre.txt`.<br>6. Verificar que `90000020` aparece en "Detalle de clientes procesados (Activos / Reactivados)" con el interés correcto.<br>7. Verificar que `90000021` **no** aparece ahí, sino en "Detalle de clientes Inactivos (sin movimiento)", con su saldo.<br>8. Verificar el resumen: cantidad procesados, cantidad inactivos, total de intereses y saldo total de la cartera.<br>9. Con `cuenta.exe`, consultar `90000020` y confirmar que el saldo nuevo quedó persistido. | El interés se acredita solo a `90000020`: `saldo nuevo = saldo anterior + (saldo anterior × tasa)`, con la tasa configurada en `WS-TASA-INTERES` (0,50% por defecto ⇒ interés de 50,00 sobre 10.000,00). `90000021` aparece únicamente en la tabla de Inactivos, sin interés, con el saldo sin cambios. El resumen muestra `Clientes procesados: 1`, `Clientes inactivos excluidos: 1`, el interés total coincide con el de `90000020`, y el saldo total de la cartera suma los saldos de los dos clientes (el de `90000020` ya con interés). |  | Caso manual (no automatizado). Ver también README.md, sección "Proceso Batch de Cierre". |

## Notas

- Los siete casos "manuales" (CP-05, CP-07 a CP-12) tienen ramificaciones (confirmaciones S/N, submenús, estados previos que hay que preparar) que no se prestan a un script de una sola pasada; se dejaron fuera de la automatización a propósito, como se acordó.
- Si un caso falla, además de completar "Resultado obtenido", conviene anotar el `FILE STATUS` o el mensaje exacto que mostró el programa (ver README.md, sección "Solución de problemas", para los códigos de error de archivo).
- Antes de reportar un caso como fallido por "el programa no responde", revisar primero la nota del README sobre `WITH NO ADVANCING` y prompts sin salto de línea: en algunas consolas el prompt puede no verse aunque el programa esté esperando la entrada correctamente.
