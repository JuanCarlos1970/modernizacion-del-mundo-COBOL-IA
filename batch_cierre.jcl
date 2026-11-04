//*********************************************************************
//* ARCHIVO DE REFERENCIA / DOCUMENTACION - NO SE EJECUTA EN ESTE
//* ENTORNO DE DESARROLLO LOCAL (Windows + GnuCOBOL).
//*
//* Este JCL muestra como correria este MISMO proceso de cierre
//* (BATCH-CIERRE) en un mainframe z/OS real, como un job batch
//* nocturno programado por un scheduler (CA-7, Control-M, etc.),
//* leyendo y actualizando la cartera de clientes desde un archivo
//* VSAM KSDS y grabando un reporte de cierre en un archivo
//* secuencial.
//*
//* En este entorno de desarrollo local, el equivalente funcional
//* es el script correr_batch_cierre.bat: compila BATCH-CIERRE.cbl
//* con GnuCOBOL y lo ejecuta contra el archivo indexado
//* clientes_v3.dat (equivalente "de escritorio" del VSAM KSDS) y
//* genera reporte_cierre.txt (equivalente del archivo secuencial
//* de salida SYSREPRT de este JCL).
//*
//* Ver tambien: README.md, seccion "Proceso Batch de Cierre".
//*********************************************************************
//BCIERRE  JOB (CTA0001),'CIERRE CTA BANCARIA',
//             CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,REGION=0M
//*
//* JOB CARD:
//*   BCIERRE     - nombre del job.
//*   (CTA0001)   - numero de cuenta/cargo (accounting information),
//*                 depende de las normas del sitio.
//*   CLASS=A     - clase de ejecucion (definida por el sitio; suele
//*                 usarse una clase de batch nocturno de baja
//*                 prioridad para procesos de cierre).
//*   MSGCLASS=X  - clase de la salida del JES (donde van los
//*                 mensajes del job).
//*   MSGLEVEL=(1,1) - pide el JCL completo y los mensajes de
//*                 asignacion de datasets en el listado.
//*   NOTIFY=&SYSUID - avisa al usuario que envio el job (por TSO)
//*                 cuando termina.
//*   REGION=0M   - memoria maxima disponible (0M = la que el sitio
//*                 permita).
//*
//*********************************************************************
//* PASO 1: acredita el interes mensual a las cuentas Activas y
//* Reactivadas, procesa los vencimientos de plazo fijo y genera el
//* reporte de cierre. Equivale a ejecutar BATCH-CIERRE.exe (ya
//* compilado) en el entorno local.
//*********************************************************************
//PASO010  EXEC PGM=BCIERRE,REGION=0M
//*
//* PGM=BCIERRE - el programa COBOL ya compilado y enlazado (link-
//* edit) en una libreria de cargas del sitio (STEPLIB), equivalente
//* al ejecutable BATCH-CIERRE.exe generado por "cobc -x" en este
//* entorno local.
//*
//STEPLIB  DD DISP=SHR,DSN=PROD.CTA.LOADLIB
//*   Libreria de carga (load library) donde esta el modulo objeto
//*   BCIERRE, ya compilado. DISP=SHR porque varios jobs pueden
//*   leerla al mismo tiempo (no la modifica este paso).
//*
//SYSOUT   DD SYSOUT=*
//*   Salida estandar del programa (los DISPLAY de COBOL van aqui).
//*   Equivale a lo que en el .bat local se ve impreso en la
//*   consola.
//*
//SYSPRINT DD SYSOUT=*
//*   Mensajes del entorno COBOL/compilador en tiempo de ejecucion
//*   (abends, mensajes de sistema). Tambien a la salida del JES.
//*
//*-------------------------------------------------------------------
//* Fecha de proceso (opcional): por defecto el cierre usa la fecha
//* del sistema. Para reprocesar un dia puntual, activar estas tres
//* lineas y poner la fecha (AAAAMMDD) en la del medio. Es una
//* "tarjeta de control": datos escritos dentro del mismo JCL
//* (DD *) que el programa lee como un archivo de una linea (SELECT
//* OPTIONAL ARCH-FECHA, ASSIGN TO "FECHAPRC", en BATCH-CIERRE.cbl).
//* En produccion, el scheduler suele generar esta linea solo.
//*-------------------------------------------------------------------
//*FECHAPRC DD *
//*20261103
//*/*
//*   Para activarlo: en las tres lineas borrar el "//*" del
//*   principio, salvo en la primera, donde se borra solo el "*"
//*   (queda "//FECHAPRC DD *"); la fecha queda en la columna 1.
//*   Si el DD no esta, el programa sigue con la fecha del sistema
//*   (OPTIONAL). Si la fecha no es valida, termina con codigo 1 sin
//*   tocar ningun archivo (igual que en local).
//*   Localmente es lo mismo que un archivo llamado FECHAPRC en la
//*   carpeta de ejecucion (o "set DD_FECHAPRC=ruta"), o que
//*   "set FECHA_PROCESO=AAAAMMDD" antes del .bat. Si estan los dos,
//*   gana el archivo FECHAPRC.
//*   NOTA: el programa sigue teniendo partes que son de GnuCOBOL y
//*   que habria que adaptar para compilarlo con Enterprise COBOL
//*   ("ACCEPT ... FROM ENVIRONMENT", que se mantiene para el uso
//*   local, ORGANIZATION LINE SEQUENTIAL y los ASSIGN con nombre de
//*   archivo); esta version de BATCH-CIERRE.cbl NO las adapta.
//*
//*-------------------------------------------------------------------
//* Archivo de clientes: VSAM KSDS (Key Sequenced Data Set), leido y
//* actualizado en el mismo paso (equivalente a abrir clientes_v3.dat
//* con OPEN I-O en BATCH-CIERRE.cbl). La clave (DNI) del KSDS
//* equivale a RECORD KEY IS CLI-DNI en el programa.
//*-------------------------------------------------------------------
//CLIENTES DD DSN=PROD.CTA.CLIENTES.KSDS,DISP=SHR
//*   DSN=PROD.CTA.CLIENTES.KSDS - nombre del dataset VSAM KSDS en
//*   el catalogo del sitio; equivale a "clientes_v3.dat" en el
//*   entorno local.
//*   DISP=SHR - se abre para lectura Y escritura (I-O) dentro del
//*   mismo paso; en produccion real normalmente se protegeria con
//*   un turno de mantenimiento o un mecanismo de serializacion
//*   (ENQ/DEQ, RLS) para evitar que otra aplicacion lo toque al
//*   mismo tiempo (ver la nota de acceso concurrente en README.md,
//*   que aplica igual en el entorno local con gestion-bancaria.exe).
//*   El SELECT del programa asociaria este DD con el archivo por
//*   su nombre logico (ARCH-CLIENTES), igual que ASSIGN TO
//*   "clientes_v3.dat" lo hace en GnuCOBOL.
//*
//*-------------------------------------------------------------------
//* Archivo de plazos fijos (Etapa 3): VSAM KSDS, leido y actualizado
//* en el mismo paso (equivale a abrir plazofijo.dat con OPEN I-O en
//* BATCH-CIERRE.cbl). La clave del KSDS (numero de plazo fijo)
//* equivale a RECORD KEY IS PF-NRO en el programa.
//*-------------------------------------------------------------------
//PLAZOFIJ DD DSN=PROD.CTA.PLAZOFIJ.KSDS,DISP=SHR
//*   DSN=PROD.CTA.PLAZOFIJ.KSDS - equivale a "plazofijo.dat" en el
//*   entorno local. DISP=SHR por la misma razon que en CLIENTES.
//*   Un nombre de DD tiene como maximo 8 caracteres, y cada parte
//*   del DSN (entre puntos) tambien: por eso es PLAZOFIJ y no
//*   PLAZOFIJO (9). El SELECT del programa
//*   (ARCH-PLAZOFIJO) se asociaria con este DD por ese nombre.
//*
//*-------------------------------------------------------------------
//* Reporte de cierre: archivo secuencial de salida (equivalente a
//* reporte_cierre.txt, ORGANIZATION LINE SEQUENTIAL en el programa
//* local).
//*-------------------------------------------------------------------
//REPORTE  DD DSN=PROD.CTA.REPORTE.CIERRE(+1),
//            DISP=(NEW,CATLG,DELETE),
//            SPACE=(TRK,(5,5),RLSE),
//            DCB=(RECFM=FB,LRECL=132,BLKSIZE=0)
//*   DSN=...REPORTE.CIERRE(+1) - dataset secuencial generado (GDG,
//*   Generation Data Group): cada corrida del cierre crea una
//*   generacion nueva (+1), sin pisar el reporte de la corrida
//*   anterior. En el entorno local, en cambio, reporte_cierre.txt
//*   se sobreescribe en cada corrida (OPEN OUTPUT); si se quisiera
//*   conservar el historial local habria que renombrar el archivo
//*   despues de cada corrida o adaptar el .bat para eso.
//*   DISP=(NEW,CATLG,DELETE) - se crea nuevo; si el paso termina
//*   bien queda catalogado; si termina mal, se borra (no deja un
//*   reporte a medias).
//*   SPACE=(TRK,(5,5),RLSE) - espacio en pistas, con liberacion del
//*   espacio no usado al cerrar el archivo.
//*   RECFM=FB,LRECL=132 - registros de formato fijo de 132
//*   caracteres, igual al PIC X(132) de REG-REPORTE en
//*   BATCH-CIERRE.cbl (paso de 100 a 132 en la Etapa 3, para que
//*   entre la tabla de vencimientos).
//*
//*-------------------------------------------------------------------
//* Parametros del cierre (opcional): en esta version local la tasa
//* de interes esta fija en WORKING-STORAGE (WS-TASA-INTERES) y hay
//* que recompilar para cambiarla. En un mainframe real es habitual
//* leerla de un dataset de parametros en vez de recompilar; se deja
//* como ejemplo de como se veria (el programa deberia declarar el
//* SELECT y la logica de lectura correspondientes, algo que esta
//* version de BATCH-CIERRE.cbl NO implementa todavia):
//*-------------------------------------------------------------------
//*PARAM   DD DSN=PROD.CTA.PARAMS.CIERRE,DISP=SHR
//*
//*********************************************************************
//* Notas de correspondencia con el entorno local:
//*
//*   z/OS (este JCL)                    Entorno local (Windows)
//*   ----------------------------       -----------------------------
//*   JOB programado por el scheduler    correr_batch_cierre.bat
//*     de cierre nocturno                 (ejecutado manualmente o
//*                                         por el Programador de
//*                                         tareas de Windows)
//*   PGM=BCIERRE (ya compilado)         cobc compila BATCH-CIERRE.cbl
//*     en STEPLIB                         en cada corrida del .bat
//*   DD CLIENTES: VSAM KSDS             clientes_v3.dat (archivo
//*                                         indexado de GnuCOBOL)
//*   DD PLAZOFIJ: VSAM KSDS             plazofijo.dat (archivo
//*                                         indexado de GnuCOBOL)
//*   DD REPORTE: dataset secuencial     reporte_cierre.txt (archivo
//*     generado (GDG)                     de texto, se sobreescribe)
//*   SYSOUT / SYSPRINT                  Salida de consola del .bat
//*   DD FECHAPRC (opcional)             archivo FECHAPRC o variable
//*                                         FECHA_PROCESO (opcional)
//*
//* En ambos casos la regla de negocio es identica: interes simple
//* mensual sobre clientes Activos (A) y Reactivados (R), exclusion
//* de los Inactivos (I), y el mismo layout de registro de cliente
//* (ver CLIENTE.cpy).
//*********************************************************************
