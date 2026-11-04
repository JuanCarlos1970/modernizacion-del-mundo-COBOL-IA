//*********************************************************************
//* ARCHIVO DE REFERENCIA / DOCUMENTACION - NO SE EJECUTA EN ESTE
//* ENTORNO DE DESARROLLO LOCAL (Windows + GnuCOBOL).
//*
//* Este JCL muestra como correria este MISMO proceso de carga
//* masiva (CARGA-MASIVA, Etapa 4) en un mainframe z/OS real, como un
//* job batch: lee un archivo secuencial con clientes (C), tasas (I)
//* y plazos fijos (P), los da de alta en tres archivos VSAM KSDS y
//* graba dos reportes secuenciales (lo cargado y lo rechazado).
//*
//* En este entorno de desarrollo local, el equivalente funcional
//* es el script correr_carga_masiva.bat: compila CARGA-MASIVA.cbl
//* con GnuCOBOL y lo ejecuta en bin\ contra clientes_v3.dat,
//* intereses.dat y plazofijo.dat (equivalentes "de escritorio" de
//* los VSAM KSDS), leyendo carga.txt y generando carga_ok.txt y
//* carga_rechazos.txt.
//*
//* Ver tambien: README.md, seccion "Carga masiva".
//*********************************************************************
//BCARGA   JOB (CTA0001),'CARGA MASIVA CTAS',
//             CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,REGION=0M
//*
//* JOB CARD: igual que en batch_cierre.jcl (ver la explicacion de
//* cada parametro alli). BCARGA es el nombre del job.
//*
//*-------------------------------------------------------------------
//* Fecha de proceso (opcional): por defecto la carga usa la fecha
//* del sistema. Para cargar con otra fecha (AAAAMMDD), activar esta
//* linea SET y el DD CEEOPTS de mas abajo (los dos juntos). Es lo
//* mismo que "set FECHA_PROCESO=AAAAMMDD" antes del .bat local.
//*-------------------------------------------------------------------
//* SET FECHA=20261103
//*
//*********************************************************************
//* PASO 1: carga los clientes, tasas y plazos fijos del archivo de
//* entrada y genera los dos reportes. Equivale a ejecutar
//* CARGA-MASIVA.exe (ya compilado) en el entorno local.
//*********************************************************************
//PASO010  EXEC PGM=BCARGA,REGION=0M
//*
//* PGM=BCARGA - el programa COBOL ya compilado y enlazado en la
//* libreria de cargas del sitio (STEPLIB), equivalente al
//* ejecutable CARGA-MASIVA.exe generado por "cobc -x".
//*
//STEPLIB  DD DISP=SHR,DSN=PROD.CTA.LOADLIB
//*   Libreria de carga donde esta el modulo BCARGA (solo lectura).
//*
//SYSOUT   DD SYSOUT=*
//*   Salida de los DISPLAY de COBOL (lo que en el .bat local se ve
//*   en la consola: fecha de proceso, totales, codigo de retorno).
//*
//SYSPRINT DD SYSOUT=*
//*   Mensajes del runtime (abends, mensajes de sistema).
//*
//*CEEOPTS DD *,SYMBOLS=JCLONLY
//*  ENVAR("FECHA_PROCESO=&FECHA")
//*/*
//*   Opciones del runtime (Language Environment). ENVAR crea la
//*   variable de entorno FECHA_PROCESO que lee el programa, con el
//*   valor del SET de arriba (&FECHA). SYMBOLS=JCLONLY hace que
//*   &FECHA se reemplace tambien dentro de estas lineas de datos.
//*   Para activarlo: en la linea CEEOPTS borrar solo el "*"; en
//*   las dos siguientes borrar el "//*" del principio. Activar
//*   siempre junto con el SET. Si la fecha no es valida, el
//*   programa termina con codigo 8 sin cargar nada.
//*   (batch_cierre.jcl usa otra forma, el DD FECHAPRC, porque
//*   BATCH-CIERRE.cbl ya lee ese archivo; CARGA-MASIVA.cbl todavia
//*   lee solo la variable FECHA_PROCESO.)
//*   NOTA: "ACCEPT ... FROM ENVIRONMENT" es de GnuCOBOL; en
//*   Enterprise COBOL el programa leeria la variable con un
//*   servicio del runtime, algo que esta version de
//*   CARGA-MASIVA.cbl NO adapta.
//*
//*-------------------------------------------------------------------
//* Los tres archivos de datos: VSAM KSDS, actualizados en el mismo
//* paso (en CARGA-MASIVA.cbl se abren con OPEN I-O). Son los MISMOS
//* datasets que usa el programa interactivo; el cierre usa solo
//* CLIENTES y PLAZOFIJ (las tasas no las lee).
//*-------------------------------------------------------------------
//CLIENTES DD DSN=PROD.CTA.CLIENTES.KSDS,DISP=SHR
//*   Equivale a "clientes_v3.dat" (SELECT ARCH-CLIENTES, clave
//*   CLI-DNI). DISP=SHR: ver la nota de acceso concurrente en
//*   batch_cierre.jcl; no correr este job junto con el cierre.
//*
//INTERES  DD DSN=PROD.CTA.INTERES.KSDS,DISP=SHR
//*   Equivale a "intereses.dat" (SELECT ARCH-INTERESES, clave
//*   INT-CLAVE). Un nombre de DD tiene como maximo 8 caracteres,
//*   y cada parte del DSN (entre puntos) tambien: por eso es
//*   INTERES y no INTERESES (9).
//*
//PLAZOFIJ DD DSN=PROD.CTA.PLAZOFIJ.KSDS,DISP=SHR
//*   Equivale a "plazofijo.dat" (SELECT ARCH-PLAZOFIJO, clave
//*   PF-NRO). PLAZOFIJ (DD y DSN) por el mismo limite de 8
//*   caracteres; es el mismo dataset que en batch_cierre.jcl.
//*
//*-------------------------------------------------------------------
//* Archivo de entrada: secuencial, ya catalogado (lo deja otro
//* proceso o un usuario). Equivale a carga.txt o al archivo que
//* indica la variable ARCHIVO_CARGA (SELECT ARCH-CARGA).
//*-------------------------------------------------------------------
//CARGA    DD DSN=PROD.CTA.CARGA.ENTRADA,DISP=SHR
//*   Las lineas validas tienen 100 posiciones, pero el programa
//*   lee registros de 1 a 200 para poder rechazar los de "Largo
//*   incorrecto". Por eso este dataset tendria que ser de largo
//*   variable (RECFM=VB, LRECL=204 = 200 + 4 del largo): con FB
//*   todos los registros miden lo mismo y ese control no sirve.
//*   En GnuCOBOL el nombre sale de "ASSIGN USING WS-NOMBRE-CARGA";
//*   en z/OS el SELECT apuntaria a este DD (ASSIGN TO CARGA).
//*
//*-------------------------------------------------------------------
//* Reportes: secuenciales de salida, generados (GDG) como el
//* reporte del cierre, asi cada corrida crea una generacion nueva.
//*-------------------------------------------------------------------
//CARGAOK  DD DSN=PROD.CTA.CARGA.OK(+1),
//            DISP=(NEW,CATLG,DELETE),
//            SPACE=(TRK,(5,5),RLSE),
//            DCB=(RECFM=FB,LRECL=132,BLKSIZE=0)
//*   Equivale a "carga_ok.txt" (SELECT ARCH-OK). LRECL=132 igual
//*   al PIC X(132) de REG-OK. DISP=(NEW,CATLG,DELETE): si el paso
//*   termina mal, se borra (no deja un reporte a medias).
//*
//CARGARCH DD DSN=PROD.CTA.CARGA.RECHAZOS(+1),
//            DISP=(NEW,CATLG,DELETE),
//            SPACE=(TRK,(5,5),RLSE),
//            DCB=(RECFM=FB,LRECL=132,BLKSIZE=0)
//*   Equivale a "carga_rechazos.txt" (SELECT ARCH-RECH), PIC
//*   X(132) de REG-RECH. CARGARCH = CARGA + RECHazos (8 letras).
//*
//*-------------------------------------------------------------------
//* Codigo de retorno: 0 = se proceso todo el archivo (con o sin
//* rechazos); 8 = no pudo correr. Un paso siguiente puede usar
//* COND para ejecutarse solo con codigo 0.
//*
//* Renombrado: localmente, con codigo 0 el programa renombra el
//* archivo de carga a <nombre>.procesado.AAAAMMDD.HHMMSS con
//* CBL_RENAME_FILE (rutina de GnuCOBOL), para no cargarlo dos
//* veces. En z/OS eso se haria FUERA del programa, por ejemplo con
//* un paso de IDCAMS (ALTER ... NEWNAME) que corra solo si PASO010
//* termino con 0, o recibiendo la entrada como un GDG. Se deja
//* como ejemplo comentado (esta version NO lo implementa):
//*-------------------------------------------------------------------
//*PASO020 EXEC PGM=IDCAMS,COND=(0,NE,PASO010)
//*SYSPRINT DD SYSOUT=*
//*SYSIN    DD *
//*  ALTER PROD.CTA.CARGA.ENTRADA NEWNAME(PROD.CTA.CARGA.PROCESAD)
//*/*
//*
//*********************************************************************
//* Notas de correspondencia con el entorno local:
//*
//*   z/OS (este JCL)                    Entorno local (Windows)
//*   ----------------------------       -----------------------------
//*   JOB BCARGA                         correr_carga_masiva.bat
//*   PGM=BCARGA (ya compilado)          cobc compila CARGA-MASIVA.cbl
//*     en STEPLIB                         en cada corrida del .bat
//*   DD CLIENTES: VSAM KSDS             clientes_v3.dat
//*   DD INTERES:  VSAM KSDS             intereses.dat
//*   DD PLAZOFIJ: VSAM KSDS             plazofijo.dat
//*   DD CARGA: secuencial (VB)          carga.txt o ARCHIVO_CARGA
//*   DD CARGAOK: secuencial (GDG)       carga_ok.txt (se reescribe)
//*   DD CARGARCH: secuencial (GDG)      carga_rechazos.txt (idem)
//*   SYSOUT / SYSPRINT                  Salida de consola del .bat
//*   CEEOPTS ENVAR (opcional)           variable FECHA_PROCESO
//*   PASO020 IDCAMS (opcional)          renombrado a .procesado.*
//*
//* En ambos casos las reglas de negocio son identicas a las de la
//* carga manual de GESTION-BANCARIA (ver README.md).
//*********************************************************************
