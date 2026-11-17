# Práctica Db2 y mainframe

Práctica personal que se sumó después de cerrar el proyecto de cuentas bancarias, para repasar Db2, bloqueos, Control-M, CICS y Endevor. Se hizo con la ayuda de IA (Claude y Claude Code), dirigida y revisada por mí. **No es experiencia laboral.**

La carpeta separa lo que se ejecutó de lo que es diseño de referencia.

## `ejecutado/`: lo que corrió de verdad

Se ejecutó en un laboratorio con Docker: GnuCOBOL (contenedor `cobol-lab`) y Db2 Community Edition 12.1.5 (contenedor `db2server`, base `TESTDB`).

| Archivo | Qué hace |
|---|---|
| `fase3/DESCARGA-CLIENTES.cbl`, `DESCARGA-INTERESES.cbl`, `DESCARGA-PLAZOS.cbl` | Descargan cada archivo indexado (el equivalente abierto de VSAM) a un archivo plano de largo fijo, listo para importar a Db2. También generan un listado de lo descargado, con totales de control. |
| `fase3/LISTADO-RECHAZOS.cbl` | Listado detallado de los registros que rechazó la carga masiva, con el motivo y un resumen por motivo. |
| `fase3/correr_fase3_lab.sh` | Compila y corre los programas de la fase 3 en el contenedor, en el orden de carga: tasas, clientes y plazos fijos. |
| `fase4/generar_errores_db2.py` | Mezcla 100 registros erróneos (clave duplicada, clave foránea, CHECK, dato no numérico, fecha inválida) entre los buenos, y deja una "clave de respuestas" para comparar. |
| `fase4/listado_import_db2.py` | Arma los listados de lo cargado y de lo rechazado por Db2 a partir de los mensajes de `IMPORT`, con totales y controles cruzados. |
| `sql/crear_tablas_lab.sql` | Crea las tablas `INTERESES`, `CLIENTES` y `PLAZOS_FIJOS` con claves primarias, claves foráneas y restricciones CHECK. |
| `sql/consultas_lab.sql` | Consultas para ver cómo quedó la carga y compararla con lo que informó COBOL. |

Además se hicieron a mano, en el CLP de Db2, ejercicios de bloqueos con dos sesiones (timeout, `SELECT FOR UPDATE`, deadlock) y la práctica de historial y checkpoint con reinicio. En ese reinicio el corte se simuló con un `ROLLBACK`; no fue una caída real. Esos ejercicios están documentados con capturas en documentos Word que no se incluyen acá.

## `referencia/`: diseño, no ejecutado

Está escrito con la sintaxis correspondiente y se revisó, pero no se ejecutó, porque no hay un mainframe disponible.

| Carpeta | Contenido |
|---|---|
| `cobol-sql-embebido/` | `DEPOSITO-DB2.cbl`: depósito individual con SQL embebido, cursor `FOR UPDATE` y manejo de -911. |
| `batch-depositos/` | Versión masiva con checkpoint y reinicio (`DEPOSITO-DB2-BATCH.cbl` y `.jcl`), su archivo de prueba y el SQL de las tablas de apoyo. Solo se probó con una base simulada. |
| `control-m-jcl/` | Los 13 JCL de la cadena de la migración, uno por job de Control-M. |
| `cics/` | Transacción `DEPO`: mapa BMS, copybooks, programa de pantalla, programa de lógica con `LINK` y COMMAREA, y definiciones de CSD. |

El ciclo de vida de un cambio en Endevor quedó como diseño conceptual en un documento aparte, sin código.
