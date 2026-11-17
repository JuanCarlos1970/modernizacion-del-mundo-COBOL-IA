      ******************************************************************
      * PROGRAMA    : LISTADO-RECHAZOS
      * DESCRIPCION : Listado DETALLADO de los registros rechazados por
      *               CARGA-MASIVA. El reporte carga_rechazos.txt solo
      *               trae numero de linea, tipo, clave y motivo; este
      *               programa toma cada numero de linea, busca esa
      *               linea en el archivo de carga original y muestra
      *               el registro completo tal como venia, con el
      *               motivo del rechazo. Sale en
      *               listado_rechazos_detalle.txt: titulo principal,
      *               una seccion por tipo de registro (clientes,
      *               tasas, plazos fijos, otros) con sus subtitulos de
      *               columnas, salto de pagina cada 55 lineas, un
      *               resumen por motivo y un control contra el total
      *               que informo CARGA-MASIVA.
      * ENTRADA     : carga_rechazos.txt (reporte de CARGA-MASIVA) y el
      *               archivo de carga original, el de la variable de
      *               entorno ARCHIVO_CARGA (si no existe, carga.txt).
      *               CARGA-MASIVA renombra el archivo al terminar bien
      *               (<nombre>.procesado.AAAAMMDD.HHMMSS): usar ese
      *               nombre o una copia del original.
      * SALIDA      : listado_rechazos_detalle.txt (132 posiciones).
      *               La direccion de los clientes se muestra recortada
      *               a 30 posiciones (en el archivo ocupa 40).
      * CODIGO DE
      * RETORNO     : 0 = listado completo. 8 = no pudo correr
      *               (falta algun archivo o error de archivo).
      * USO         : correr DESPUES de CARGA-MASIVA, sobre los
      *               reportes de ESA misma corrida.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LISTADO-RECHAZOS.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. PC.
       OBJECT-COMPUTER. PC.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARCH-RECH ASSIGN TO "carga_rechazos.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

      * El nombre sale de WS-NOMBRE-CARGA en el momento del OPEN
           SELECT ARCH-ORIG ASSIGN USING WS-NOMBRE-CARGA
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

           SELECT ARCH-LISTADO ASSIGN TO "listado_rechazos_detalle.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARCH-RECH.
       01  REG-RECH                PIC X(132).

       FD  ARCH-ORIG.
       01  REG-ORIG                PIC X(200).

       FD  ARCH-LISTADO.
       01  REG-LISTADO             PIC X(132).

       WORKING-STORAGE SECTION.

      * Estado de la ultima operacion de E/S
       01  WS-FS                   PIC XX     VALUE "00".
           88  FS-OK                          VALUE "00".
           88  FS-FIN-ARCHIVO                 VALUE "10".
           88  FS-NO-EXISTE                   VALUE "35".
       01  WS-OPERACION            PIC X(12)  VALUE SPACES.
       01  WS-ARCHIVO              PIC X(100) VALUE SPACES.
       01  WS-NOMBRE-CARGA         PIC X(100) VALUE SPACES.

       01  WS-FIN-RECH             PIC X      VALUE "N".
           88  FIN-RECHAZOS                   VALUE "S".
       01  WS-FIN-ORIG             PIC X      VALUE "N".
           88  FIN-ORIGINAL                   VALUE "S".

      * Linea de detalle del reporte de rechazos, por posiciones:
      * linea (5), tipo (1), clave (31), motivo (60)
       01  WS-DET-RECH.
           05  WR-LINEA            PIC X(5).
           05  FILLER              PIC X(2).
           05  WR-TIPO             PIC X.
           05  FILLER              PIC X(5).
           05  WR-CLAVE            PIC X(31).
           05  WR-MOTIVO           PIC X(60).
       01  WS-LINEA-N              PIC 9(5).

      * Linea del archivo de carga original y sus tres vistas (las
      * primeras 100 posiciones; el resto, en blanco o recortado)
       01  WS-ORIG-NRO             PIC 9(7)   VALUE 0.
       01  WS-ORIG-HALLADA         PIC X      VALUE "N".
           88  ORIGINAL-HALLADA               VALUE "S".
           88  ORIGINAL-NO-HALLADA            VALUE "N".
       01  WS-ORIG                 PIC X(200).
       01  WS-LIN-C REDEFINES WS-ORIG.
           05  LC-TIPO             PIC X.
           05  LC-DNI              PIC X(8).
           05  LC-NOMBRE           PIC X(30).
           05  LC-DIRECCION        PIC X(40).
           05  LC-TELEFONO         PIC X(15).
           05  FILLER              PIC X(106).
       01  WS-LIN-I REDEFINES WS-ORIG.
           05  LI-TIPO             PIC X.
           05  LI-MONEDA           PIC X.
           05  LI-DIAS             PIC X(3).
           05  LI-TNA              PIC X(5).
           05  LI-TNA-N REDEFINES LI-TNA
                                   PIC 9(3)V99.
           05  LI-VIGENTE          PIC X(8).
           05  FILLER              PIC X(182).
       01  WS-LIN-P REDEFINES WS-ORIG.
           05  LP-TIPO             PIC X.
           05  LP-DNI              PIC X(8).
           05  LP-MONEDA           PIC X.
           05  LP-MONTO            PIC X(13).
           05  LP-MONTO-N REDEFINES LP-MONTO
                                   PIC 9(11)V99.
           05  LP-DIAS             PIC X(3).
           05  FILLER              PIC X(174).

      * Fechas (la del proceso se toma del reporte de rechazos)
       01  WS-FECHA-HORA           PIC X(21).
       01  WS-FECHA-EDIT           PIC X(10)  VALUE SPACES.

      * Contadores
       01  WS-CANT-C               PIC 9(7)   VALUE 0.
       01  WS-CANT-I               PIC 9(7)   VALUE 0.
       01  WS-CANT-P               PIC 9(7)   VALUE 0.
       01  WS-CANT-OTROS           PIC 9(7)   VALUE 0.
       01  WS-CANT-TOTAL           PIC 9(7)   VALUE 0.
       01  WS-CANT-SIN-ORIG        PIC 9(7)   VALUE 0.
       01  WS-TOTAL-INFORMADO      PIC 9(7)   VALUE 0.
       01  WS-HAY-INFORMADO        PIC X      VALUE "N".
           88  HAY-TOTAL-INFORMADO            VALUE "S".

      * Resumen por motivo (hasta 30 motivos distintos)
       01  WS-TABLA-MOTIVOS.
           05  TM-FILA OCCURS 30 TIMES.
               10  TM-TEXTO        PIC X(32).
               10  TM-CANT         PIC 9(7).
       01  WS-NMOT                 PIC 99     VALUE 0.
       01  WS-I                    PIC 99.
       01  WS-MOT-ENC              PIC X      VALUE "N".
           88  MOTIVO-ENCONTRADO              VALUE "S".
       01  WS-CANT-OTROS-MOT       PIC 9(7)   VALUE 0.

      * Control de paginas y secciones del listado
       01  WS-PAGINA               PIC 9(4)   VALUE 0.
       01  WS-PAGINA-EDIT          PIC ZZZ9.
       01  WS-LINEAS               PIC 99     VALUE 99.
       01  WS-MAX-LINEAS           PIC 99     VALUE 55.
       01  WS-SECCION              PIC X      VALUE SPACE.
       01  WS-SECCION-ACT          PIC X      VALUE SPACE.

      * Lineas del listado
       01  WS-LINEA-REP            PIC X(132).
       01  WS-MONTO-EDIT           PIC ZZ,ZZZ,ZZZ,ZZ9.99.
       01  WS-TNA-EDIT             PIC ZZ9.99.

       01  WS-SUBT-C.
           05  FILLER              PIC X(6)   VALUE "LINEA".
           05  FILLER              PIC X(9)   VALUE "DNI".
           05  FILLER              PIC X(31)  VALUE "NOMBRE".
           05  FILLER              PIC X(31)  VALUE "DIRECCION".
           05  FILLER              PIC X(16)  VALUE "TELEFONO".
           05  FILLER              PIC X(6)   VALUE "MOTIVO".
       01  WS-DET-C.
           05  DC-LINEA            PIC 9(5).
           05  FILLER              PIC X      VALUE SPACE.
           05  DC-DNI              PIC X(8).
           05  FILLER              PIC X      VALUE SPACE.
           05  DC-NOMBRE           PIC X(30).
           05  FILLER              PIC X      VALUE SPACE.
           05  DC-DIRECCION        PIC X(30).
           05  FILLER              PIC X      VALUE SPACE.
           05  DC-TELEFONO         PIC X(15).
           05  FILLER              PIC X      VALUE SPACE.
           05  DC-MOTIVO           PIC X(32).

       01  WS-SUBT-I.
           05  FILLER              PIC X(6)   VALUE "LINEA".
           05  FILLER              PIC X(7)   VALUE "MONEDA".
           05  FILLER              PIC X(6)   VALUE "DIAS".
           05  FILLER              PIC X(8)   VALUE "TNA %".
           05  FILLER              PIC X(14)  VALUE "VIGENTE DESDE".
           05  FILLER              PIC X(6)   VALUE "MOTIVO".
       01  WS-DET-I.
           05  DI-LINEA            PIC 9(5).
           05  FILLER              PIC X      VALUE SPACE.
           05  FILLER              PIC X(3)   VALUE SPACES.
           05  DI-MONEDA           PIC X.
           05  FILLER              PIC X(3)   VALUE SPACES.
           05  DI-DIAS             PIC X(3).
           05  FILLER              PIC X(3)   VALUE SPACES.
           05  DI-TNA              PIC X(6).
           05  FILLER              PIC X(2)   VALUE SPACES.
           05  DI-VIGENTE          PIC X(10).
           05  FILLER              PIC X(4)   VALUE SPACES.
           05  DI-MOTIVO           PIC X(32).

       01  WS-SUBT-P.
           05  FILLER              PIC X(6)   VALUE "LINEA".
           05  FILLER              PIC X(9)   VALUE "DNI".
           05  FILLER              PIC X(2)   VALUE "M".
           05  FILLER              PIC X(18)  VALUE "            MONTO".
           05  FILLER              PIC X(5)   VALUE "DIAS".
           05  FILLER              PIC X(6)   VALUE "MOTIVO".
       01  WS-DET-P.
           05  DP-LINEA            PIC 9(5).
           05  FILLER              PIC X      VALUE SPACE.
           05  DP-DNI              PIC X(8).
           05  FILLER              PIC X      VALUE SPACE.
           05  DP-MONEDA           PIC X.
           05  FILLER              PIC X      VALUE SPACE.
           05  DP-MONTO            PIC X(17).
           05  FILLER              PIC X      VALUE SPACE.
           05  DP-DIAS             PIC X(3).
           05  FILLER              PIC X(2)   VALUE SPACES.
           05  DP-MOTIVO           PIC X(32).

       01  WS-SUBT-O.
           05  FILLER              PIC X(6)   VALUE "LINEA".
           05  FILLER              PIC X(5)   VALUE "TIPO".
           05  FILLER              PIC X(81)  VALUE
               "CONTENIDO (primeras 80 posiciones)".
           05  FILLER              PIC X(6)   VALUE "MOTIVO".
       01  WS-DET-O.
           05  DO-LINEA            PIC 9(5).
           05  FILLER              PIC X      VALUE SPACE.
           05  DO-TIPO             PIC X.
           05  FILLER              PIC X(3)   VALUE SPACES.
           05  DO-CONTENIDO        PIC X(80).
           05  FILLER              PIC X      VALUE SPACE.
           05  DO-MOTIVO           PIC X(32).

       01  WS-LIN-TOTAL.
           05  WS-TOT-TEXTO        PIC X(46).
           05  WS-TOT-CANT         PIC Z,ZZZ,ZZ9.

       PROCEDURE DIVISION.
      ******************************************************************
      * Los dos archivos de entrada se abren ANTES de crear el listado,
      * asi un error de arranque no borra el listado anterior.
      ******************************************************************
       0000-PRINCIPAL.
           DISPLAY "LISTADO-RECHAZOS"
           MOVE FUNCTION CURRENT-DATE TO WS-FECHA-HORA
           PERFORM 0200-ABRIR-ARCHIVOS
           PERFORM 1000-LEER-RECHAZO
           PERFORM 2000-PROCESAR-LINEA UNTIL FIN-RECHAZOS
           PERFORM 8000-TOTALES
           PERFORM 8500-CERRAR-ARCHIVOS
           DISPLAY "Rechazos listados: " WS-CANT-TOTAL
           DISPLAY "Listado: listado_rechazos_detalle.txt"
           DISPLAY "Listado terminado (codigo 0)."
           MOVE 0 TO RETURN-CODE
           STOP RUN.

       0200-ABRIR-ARCHIVOS.
           MOVE "carga_rechazos.txt" TO WS-ARCHIVO
           MOVE "OPEN INPUT" TO WS-OPERACION
           OPEN INPUT ARCH-RECH
           IF FS-NO-EXISTE
               DISPLAY "No existe carga_rechazos.txt. Correr antes "
                   "CARGA-MASIVA."
               PERFORM 9900-TERMINAR-CON-ERROR
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE SPACES TO WS-NOMBRE-CARGA
           ACCEPT WS-NOMBRE-CARGA FROM ENVIRONMENT "ARCHIVO_CARGA"
           IF WS-NOMBRE-CARGA = SPACES
               MOVE "carga.txt" TO WS-NOMBRE-CARGA
           END-IF
           DISPLAY "Archivo de carga original: "
               FUNCTION TRIM(WS-NOMBRE-CARGA)
           MOVE WS-NOMBRE-CARGA TO WS-ARCHIVO
           OPEN INPUT ARCH-ORIG
           IF FS-NO-EXISTE
               DISPLAY "No existe el archivo de carga original: "
                   FUNCTION TRIM(WS-NOMBRE-CARGA)
               DISPLAY "Indicar el nombre en ARCHIVO_CARGA."
               PERFORM 9900-TERMINAR-CON-ERROR
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "listado_rechazos_detalle.txt" TO WS-ARCHIVO
           MOVE "OPEN OUTPUT" TO WS-OPERACION
           OPEN OUTPUT ARCH-LISTADO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       1000-LEER-RECHAZO.
           MOVE "carga_rechazos.txt" TO WS-ARCHIVO
           MOVE "READ" TO WS-OPERACION
           READ ARCH-RECH
               AT END
                   SET FIN-RECHAZOS TO TRUE
           END-READ
           IF NOT FS-OK AND NOT FS-FIN-ARCHIVO
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Del reporte de CARGA-MASIVA interesan tres cosas: la fecha de
      * proceso (renglon "Fecha de proceso: "), las lineas de detalle
      * (empiezan con 5 digitos) y el total general rechazado.
       2000-PROCESAR-LINEA.
           EVALUATE TRUE
               WHEN REG-RECH(1:18) = "Fecha de proceso: "
                   MOVE REG-RECH(19:10) TO WS-FECHA-EDIT
               WHEN REG-RECH(1:5) IS NUMERIC
                   PERFORM 2100-PROCESAR-RECHAZO
               WHEN REG-RECH(1:24) = "TOTAL GENERAL RECHAZADO:"
                   MOVE FUNCTION NUMVAL(REG-RECH(27:7))
                       TO WS-TOTAL-INFORMADO
                   SET HAY-TOTAL-INFORMADO TO TRUE
           END-EVALUATE
           PERFORM 1000-LEER-RECHAZO.

       2100-PROCESAR-RECHAZO.
           MOVE REG-RECH TO WS-DET-RECH
           MOVE WR-LINEA TO WS-LINEA-N
           PERFORM 2200-BUSCAR-ORIGINAL
           EVALUATE WR-TIPO
               WHEN "C"
                   MOVE "C" TO WS-SECCION
               WHEN "I"
                   MOVE "I" TO WS-SECCION
               WHEN "P"
                   MOVE "P" TO WS-SECCION
               WHEN OTHER
                   MOVE "O" TO WS-SECCION
           END-EVALUATE
           IF WS-LINEAS >= WS-MAX-LINEAS
               PERFORM 7000-ENCABEZADO-PAGINA
           END-IF
           IF WS-SECCION NOT = WS-SECCION-ACT
               PERFORM 7100-ENCABEZADO-SECCION
           END-IF
           EVALUATE WS-SECCION
               WHEN "C"
                   PERFORM 3000-DETALLE-CLIENTE
               WHEN "I"
                   PERFORM 3100-DETALLE-TASA
               WHEN "P"
                   PERFORM 3200-DETALLE-PLAZO
               WHEN OTHER
                   PERFORM 3300-DETALLE-OTRO
           END-EVALUATE
           ADD 1 TO WS-LINEAS
           ADD 1 TO WS-CANT-TOTAL
           PERFORM 2300-ACUMULAR-MOTIVO.

      * Avanza el archivo original hasta la linea pedida. Las lineas
      * rechazadas llegan en orden creciente, asi que el original se
      * recorre UNA sola vez.
       2200-BUSCAR-ORIGINAL.
           MOVE SPACES TO WS-ORIG
           SET ORIGINAL-NO-HALLADA TO TRUE
           PERFORM UNTIL WS-ORIG-NRO >= WS-LINEA-N OR FIN-ORIGINAL
               MOVE SPACES TO WS-ORIG
               MOVE WS-NOMBRE-CARGA TO WS-ARCHIVO
               MOVE "READ" TO WS-OPERACION
               READ ARCH-ORIG
                   AT END
                       SET FIN-ORIGINAL TO TRUE
                   NOT AT END
                       ADD 1 TO WS-ORIG-NRO
                       MOVE REG-ORIG TO WS-ORIG
               END-READ
               IF NOT FS-OK AND NOT FS-FIN-ARCHIVO
                   PERFORM 9000-ERROR-ARCHIVO
               END-IF
           END-PERFORM
           IF WS-ORIG-NRO = WS-LINEA-N
               SET ORIGINAL-HALLADA TO TRUE
           ELSE
               MOVE SPACES TO WS-ORIG
               ADD 1 TO WS-CANT-SIN-ORIG
           END-IF.

      * Suma el motivo al resumen (si hay mas de 30 motivos distintos,
      * los de mas se cuentan aparte)
       2300-ACUMULAR-MOTIVO.
           EVALUATE WS-SECCION
               WHEN "C"
                   ADD 1 TO WS-CANT-C
               WHEN "I"
                   ADD 1 TO WS-CANT-I
               WHEN "P"
                   ADD 1 TO WS-CANT-P
               WHEN OTHER
                   ADD 1 TO WS-CANT-OTROS
           END-EVALUATE
           MOVE "N" TO WS-MOT-ENC
           PERFORM VARYING WS-I FROM 1 BY 1
                   UNTIL WS-I > WS-NMOT OR MOTIVO-ENCONTRADO
               IF TM-TEXTO(WS-I) = WR-MOTIVO(1:32)
                   ADD 1 TO TM-CANT(WS-I)
                   SET MOTIVO-ENCONTRADO TO TRUE
               END-IF
           END-PERFORM
           IF NOT MOTIVO-ENCONTRADO
               IF WS-NMOT < 30
                   ADD 1 TO WS-NMOT
                   MOVE WR-MOTIVO(1:32) TO TM-TEXTO(WS-NMOT)
                   MOVE 1 TO TM-CANT(WS-NMOT)
               ELSE
                   ADD 1 TO WS-CANT-OTROS-MOT
               END-IF
           END-IF.

       3000-DETALLE-CLIENTE.
           MOVE WS-LINEA-N     TO DC-LINEA
           MOVE LC-DNI         TO DC-DNI
           MOVE LC-NOMBRE      TO DC-NOMBRE
           MOVE LC-DIRECCION   TO DC-DIRECCION
           MOVE LC-TELEFONO    TO DC-TELEFONO
           MOVE WR-MOTIVO      TO DC-MOTIVO
           IF ORIGINAL-NO-HALLADA
               MOVE "(no hallada en el original)" TO DC-NOMBRE
           END-IF
           MOVE WS-DET-C TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA.

      * Los campos numericos se muestran editados si son numericos; si
      * no lo son, tal como vinieron (es justamente lo que se rechazo).
       3100-DETALLE-TASA.
           MOVE WS-LINEA-N     TO DI-LINEA
           MOVE LI-MONEDA      TO DI-MONEDA
           MOVE LI-DIAS        TO DI-DIAS
           IF LI-TNA IS NUMERIC
               MOVE LI-TNA-N TO WS-TNA-EDIT
               MOVE WS-TNA-EDIT TO DI-TNA
           ELSE
               MOVE LI-TNA TO DI-TNA
           END-IF
           IF LI-VIGENTE IS NUMERIC
               MOVE SPACES TO DI-VIGENTE
               STRING LI-VIGENTE(7:2) "/" LI-VIGENTE(5:2) "/"
                   LI-VIGENTE(1:4)
                   DELIMITED BY SIZE INTO DI-VIGENTE
           ELSE
               MOVE LI-VIGENTE TO DI-VIGENTE
           END-IF
           MOVE WR-MOTIVO      TO DI-MOTIVO
           MOVE WS-DET-I TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA.

       3200-DETALLE-PLAZO.
           MOVE WS-LINEA-N     TO DP-LINEA
           MOVE LP-DNI         TO DP-DNI
           MOVE LP-MONEDA      TO DP-MONEDA
           IF LP-MONTO IS NUMERIC
               MOVE LP-MONTO-N TO WS-MONTO-EDIT
               MOVE WS-MONTO-EDIT TO DP-MONTO
           ELSE
               MOVE LP-MONTO TO DP-MONTO
           END-IF
           MOVE LP-DIAS        TO DP-DIAS
           MOVE WR-MOTIVO      TO DP-MOTIVO
           MOVE WS-DET-P TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA.

      * Linea sin tipo, en blanco o de largo incorrecto: se muestra el
      * contenido crudo
       3300-DETALLE-OTRO.
           MOVE WS-LINEA-N     TO DO-LINEA
           MOVE WR-TIPO        TO DO-TIPO
           MOVE WS-ORIG(1:80)  TO DO-CONTENIDO
           MOVE WR-MOTIVO      TO DO-MOTIVO
           MOVE WS-DET-O TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA.

      * Titulo principal, fecha, archivo y pagina. Al empezar pagina
      * hay que repetir tambien el encabezado de la seccion en curso.
       7000-ENCABEZADO-PAGINA.
           ADD 1 TO WS-PAGINA
           IF WS-PAGINA > 1
               MOVE SPACES TO WS-LINEA-REP
               PERFORM 7500-GRABAR-LINEA
           END-IF
           MOVE "GESTION BANCARIA - CARGA MASIVA - RECHAZOS (DETALLE)"
               TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA
           IF WS-FECHA-EDIT = SPACES
               STRING WS-FECHA-HORA(7:2) "/" WS-FECHA-HORA(5:2) "/"
                   WS-FECHA-HORA(1:4)
                   DELIMITED BY SIZE INTO WS-FECHA-EDIT
           END-IF
           MOVE WS-PAGINA TO WS-PAGINA-EDIT
           MOVE SPACES TO WS-LINEA-REP
           STRING "Fecha de proceso: " WS-FECHA-EDIT
               "   Archivo: " FUNCTION TRIM(WS-NOMBRE-CARGA)
               "   Pagina: " WS-PAGINA-EDIT
               DELIMITED BY SIZE INTO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA
           MOVE SPACES TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA
           MOVE 4 TO WS-LINEAS
           MOVE SPACE TO WS-SECCION-ACT.

      * Nombre de la seccion, subtitulos de columnas y raya
       7100-ENCABEZADO-SECCION.
           IF WS-PAGINA = 0
               PERFORM 7000-ENCABEZADO-PAGINA
           END-IF
           IF WS-LINEAS > 4
               MOVE SPACES TO WS-LINEA-REP
               PERFORM 7500-GRABAR-LINEA
               ADD 1 TO WS-LINEAS
           END-IF
           MOVE SPACES TO WS-LINEA-REP
           EVALUATE WS-SECCION
               WHEN "C"
                   MOVE "CLIENTES RECHAZADOS (tipo C)" TO WS-LINEA-REP
               WHEN "I"
                   MOVE "TASAS RECHAZADAS (tipo I)" TO WS-LINEA-REP
               WHEN "P"
                   MOVE "PLAZOS FIJOS RECHAZADOS (tipo P)"
                       TO WS-LINEA-REP
               WHEN OTHER
                   MOVE "LINEAS SIN TIPO, EN BLANCO O LARGO INCORRECTO"
                       TO WS-LINEA-REP
           END-EVALUATE
           PERFORM 7500-GRABAR-LINEA
           EVALUATE WS-SECCION
               WHEN "C"
                   MOVE WS-SUBT-C TO WS-LINEA-REP
               WHEN "I"
                   MOVE WS-SUBT-I TO WS-LINEA-REP
               WHEN "P"
                   MOVE WS-SUBT-P TO WS-LINEA-REP
               WHEN OTHER
                   MOVE WS-SUBT-O TO WS-LINEA-REP
           END-EVALUATE
           PERFORM 7500-GRABAR-LINEA
           MOVE ALL "-" TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA
           ADD 3 TO WS-LINEAS
           MOVE WS-SECCION TO WS-SECCION-ACT.

       7500-GRABAR-LINEA.
           MOVE "listado_rechazos_detalle.txt" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-LISTADO FROM WS-LINEA-REP
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Totales por tipo, resumen por motivo y control contra el total
      * que informo CARGA-MASIVA. Si no hubo ningun rechazo, igual sale
      * el titulo (el listado nunca queda vacio).
       8000-TOTALES.
           IF WS-PAGINA = 0
               PERFORM 7000-ENCABEZADO-PAGINA
           END-IF
           MOVE SPACES TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA
           MOVE ALL "-" TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA
           MOVE "TOTAL DE REGISTROS RECHAZADOS LISTADOS:"
               TO WS-TOT-TEXTO
           MOVE WS-CANT-TOTAL TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Clientes (C):" TO WS-TOT-TEXTO
           MOVE WS-CANT-C TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Tasas (I):" TO WS-TOT-TEXTO
           MOVE WS-CANT-I TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Plazos fijos (P):" TO WS-TOT-TEXTO
           MOVE WS-CANT-P TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Sin tipo / en blanco / largo incorrecto:"
               TO WS-TOT-TEXTO
           MOVE WS-CANT-OTROS TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           IF WS-CANT-SIN-ORIG > 0
               MOVE "  Lineas NO halladas en el archivo original:"
                   TO WS-TOT-TEXTO
               MOVE WS-CANT-SIN-ORIG TO WS-TOT-CANT
               PERFORM 8100-GRABAR-TOTAL
           END-IF
           MOVE SPACES TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA
           MOVE "RESUMEN POR MOTIVO" TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-NMOT
               MOVE SPACES TO WS-TOT-TEXTO
               STRING "  " TM-TEXTO(WS-I)
                   DELIMITED BY SIZE INTO WS-TOT-TEXTO
               MOVE TM-CANT(WS-I) TO WS-TOT-CANT
               PERFORM 8100-GRABAR-TOTAL
           END-PERFORM
           IF WS-CANT-OTROS-MOT > 0
               MOVE "  Otros motivos (tabla llena):" TO WS-TOT-TEXTO
               MOVE WS-CANT-OTROS-MOT TO WS-TOT-CANT
               PERFORM 8100-GRABAR-TOTAL
           END-IF
           MOVE SPACES TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA
           IF HAY-TOTAL-INFORMADO
               MOVE "TOTAL INFORMADO POR CARGA-MASIVA:" TO WS-TOT-TEXTO
               MOVE WS-TOTAL-INFORMADO TO WS-TOT-CANT
               PERFORM 8100-GRABAR-TOTAL
               MOVE SPACES TO WS-LINEA-REP
               IF WS-TOTAL-INFORMADO = WS-CANT-TOTAL
                   MOVE "CONTROL: el total coincide con CARGA-MASIVA."
                       TO WS-LINEA-REP
               ELSE
                   MOVE "CONTROL: *** EL TOTAL NO COINCIDE ***"
                       TO WS-LINEA-REP
               END-IF
               PERFORM 7500-GRABAR-LINEA
           END-IF.

       8100-GRABAR-TOTAL.
           MOVE WS-LIN-TOTAL TO WS-LINEA-REP
           PERFORM 7500-GRABAR-LINEA.

       8500-CERRAR-ARCHIVOS.
           CLOSE ARCH-RECH
           CLOSE ARCH-ORIG
           CLOSE ARCH-LISTADO.

       9000-ERROR-ARCHIVO.
           DISPLAY "Error de archivo: " FUNCTION TRIM(WS-ARCHIVO)
               " (" FUNCTION TRIM(WS-OPERACION) "), FILE STATUS "
               WS-FS
           PERFORM 9900-TERMINAR-CON-ERROR.

       9900-TERMINAR-CON-ERROR.
           DISPLAY "Listado terminado con error (codigo 8)."
           MOVE 8 TO RETURN-CODE
           STOP RUN.
