# Práctica en z/OS real: SORT, REXX y Zowe CLI

Práctica personal hecha en noviembre de 2026 en un sistema z/OS real de IBM Z Xplore, con datos de clientes de prueba.

**Esto es práctica, no experiencia laboral.** Mi experiencia de producción en mainframe viene de mi trabajo en bancos. Acá documento lo que ejecuté, con los resultados que obtuve.

## Qué hice

| Tema | Qué se hizo | Resultado verificado |
|---|---|---|
| JCL y SORT | Filtrar clientes activos y ordenarlos por DNI | 21 registros entran, 18 salen |
| JCL y SORT | Eliminar duplicados (`SUM FIELDS=NONE`) | 21 entran, 20 salen |
| ICETOOL | Contar registros (`COUNT`) | 21 registros |
| Lectura de errores | Dataset inexistente y reutilizar un dataset ya creado | JCL ERROR / dataset no encontrado, causa identificada en el listado |
| REXX en batch | Leer un archivo y contar activos (`IKJEFT01`) | Leidos: 21, Activos: 18 |
| REXX en batch | Validar que el DNI sea numérico (`DATATYPE`) | 2 DNI inválidos detectados con su número de registro |
| REXX en batch | Generar un JCL de SORT por cada estado y ejecutarlo | JCL de 24 líneas generado y ejecutado con CC 0000; el SORT del estado I dejó 3 registros |
| Zowe CLI | Listar datasets, subir un archivo y enviar jobs desde PowerShell | Conexión y envío verificados |
| Automatización | Script de PowerShell que envía un JCL y revisa el código de retorno | CC 0000 devuelve código de salida 0; JCL ERROR devuelve 1 |

## Estructura

- `jcl/`: los jobs, numerados en el orden en que se hicieron.
- `rexx/`: los scripts REXX (`CLICNT`, `CLIVAL`, `CLIGEN`). Son miembros de una biblioteca en el mainframe, a la que apunta el `SYSEXEC` de los JCL 06 a 08.
- `scripts/automatizar_job.ps1`: envía un JCL con Zowe CLI y revisa el código de retorno.

## Datos de prueba

Archivo de ancho fijo, 107 caracteres por registro, 21 registros. El DNI ocupa las posiciones 1 a 8 y el estado (`A` activo, `I` inactivo) la posición 107.

## Notas

- El identificador de usuario de la plataforma fue reemplazado por `ZID` en todos los archivos. Antes de ejecutar los JCL hay que cambiarlo por el propio.
- No hay contraseñas, ni servidor, ni credenciales en este repositorio.
- Los JCL usan `CLASS=7`, que es la clase que funcionó en mi cuenta de práctica; en otro sistema puede ser distinta.
- Los jobs que crean datasets (`01`) fallan si el dataset ya existe. Los jobs `02` y `04` borran el dataset de salida antes de crearlo y se pueden repetir.

## Cómo ejecutar el script

```
powershell -ExecutionPolicy Bypass -File .\scripts\automatizar_job.ps1 -Jcl ".\jcl\02_sort_sin_duplicados.jcl"
```

Requiere Zowe CLI con una conexión configurada a z/OSMF.
