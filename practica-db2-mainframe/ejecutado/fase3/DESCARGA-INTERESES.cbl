      ******************************************************************
      * PROGRAMA    : DESCARGA-INTERESES
      * DESCRIPCION : Descarga (UNLOAD) del archivo indexado
      *               intereses.dat a un archivo plano de largo fijo
      *               (intereses.txt), listo para importar a la tabla
      *               INTERESES de Db2. Ademas genera el listado
      *               detallado de las tasas cargadas
      *               (listado_intereses_ok.txt): titulo principal,
      *               subtitulos de columnas y totales de control.
      * ENTRADA     : intereses.dat (indexado por moneda + dias).
      * SALIDA      : intereses.txt (27 posiciones por registro):
      *                 1      MONEDA (P = pesos, D = dolares)
      *                 2-4    DIAS
      *                 5-10   TNA (999.99)
      *                 11-16  TNA ANTERIOR (999.99)
      *                 17-26  VIGENTE DESDE (AAAA-MM-DD)
      *                 27     ESTADO (A = activa, B = baja)
      *               La fecha se descarga en formato ISO (con guiones)
      *               para que Db2 la tome como DATE sin conversion.
      * FECHA DE
      * PROCESO     : la de la variable de entorno FECHA_PROCESO
      *               (AAAAMMDD) si existe, si no la del sistema. Se
      *               usa solo en el titulo del listado.
      * CODIGO DE
      * RETORNO     : 0 = descarga completa. 8 = no pudo correr
      *               (archivo inexistente, error de archivo o fecha
      *               invalida).
      * USO         : correr DESPUES de CARGA-MASIVA y NUNCA al mismo
      *               tiempo que otro programa que use los archivos.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DESCARGA-INTERESES.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. PC.
       OBJECT-COMPUTER. PC.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARCH-INTERESES ASSIGN TO "intereses.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS SEQUENTIAL
               RECORD KEY IS INT-CLAVE
               FILE STATUS IS WS-FS.

           SELECT ARCH-PLANO ASSIGN TO "intereses.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

           SELECT ARCH-LISTADO ASSIGN TO "listado_intereses_ok.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARCH-INTERESES.
           COPY INTERES.

       FD  ARCH-PLANO.
       01  REG-PLANO.
           05  PL-MONEDA           PIC X.
           05  PL-DIAS             PIC 9(3).
           05  PL-TNA              PIC 9(3).99.
           05  PL-TNA-ANT          PIC 9(3).99.
           05  PL-VIGENTE          PIC X(10).
           05  PL-ESTADO           PIC X.

       FD  ARCH-LISTADO.
       01  REG-LISTADO             PIC X(132).

       WORKING-STORAGE SECTION.

      * Estado de la ultima operacion de E/S
       01  WS-FS                   PIC XX     VALUE "00".
           88  FS-OK                          VALUE "00".
           88  FS-FIN-ARCHIVO                 VALUE "10".
           88  FS-NO-EXISTE                   VALUE "35".
       01  WS-OPERACION            PIC X(12)  VALUE SPACES.
       01  WS-ARCHIVO              PIC X(30)  VALUE SPACES.

       01  WS-FIN-INT              PIC X      VALUE "N".
           88  FIN-INTERESES                  VALUE "S".

      * Fechas
       01  WS-FECHA-ENV            PIC X(20).
       01  WS-FECHA-HORA           PIC X(21).
       01  WS-FECHA-PROCESO        PIC 9(8).
       01  WS-FECHA-AUX            PIC 9(8).
       01  WS-FECHA-AUX-R REDEFINES WS-FECHA-AUX.
           05  WS-FA-ANIO          PIC 9(4).
           05  WS-FA-MES           PIC 99.
           05  WS-FA-DIA           PIC 99.
       01  WS-FECHA-EDIT           PIC X(10).
       01  WS-FECHA-ISO            PIC X(10).

      * Contadores
       01  WS-CANT                 PIC 9(7)   VALUE 0.
       01  WS-CANT-A               PIC 9(7)   VALUE 0.
       01  WS-CANT-B               PIC 9(7)   VALUE 0.
       01  WS-CANT-OTRO            PIC 9(7)   VALUE 0.

      * Control de paginas del listado
       01  WS-PAGINA               PIC 9(4)   VALUE 0.
       01  WS-PAGINA-EDIT          PIC ZZZ9.
       01  WS-LINEAS               PIC 99     VALUE 99.
       01  WS-MAX-LINEAS           PIC 99     VALUE 55.

      * Lineas del listado
       01  WS-LINEA-REP            PIC X(132).
       01  WS-SUBTITULOS.
           05  FILLER              PIC X(13)  VALUE "MONEDA".
           05  FILLER              PIC X(7)   VALUE "DIAS".
           05  FILLER              PIC X(10)  VALUE "TNA %".
           05  FILLER              PIC X(10)  VALUE "TNA ANT.".
           05  FILLER              PIC X(14)  VALUE "VIGENTE DESDE".
           05  FILLER              PIC X(6)   VALUE "ESTADO".
       01  WS-DETALLE.
           05  DT-MONEDA           PIC X.
           05  FILLER              PIC X(2)   VALUE SPACES.
           05  DT-MONEDA-DESC      PIC X(8).
           05  FILLER              PIC X(2)   VALUE SPACES.
           05  DT-DIAS             PIC ZZ9.
           05  FILLER              PIC X(4)   VALUE SPACES.
           05  DT-TNA              PIC ZZ9.99.
           05  FILLER              PIC X(4)   VALUE SPACES.
           05  DT-TNA-ANT          PIC ZZ9.99.
           05  FILLER              PIC X(4)   VALUE SPACES.
           05  DT-VIGENTE          PIC X(10).
           05  FILLER              PIC X(4)   VALUE SPACES.
           05  DT-ESTADO           PIC X.
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-ESTADO-DESC      PIC X(6).
       01  WS-LIN-TOTAL.
           05  WS-TOT-TEXTO        PIC X(40).
           05  WS-TOT-CANT         PIC Z,ZZZ,ZZ9.

       PROCEDURE DIVISION.
      ******************************************************************
      * Si no se puede abrir un archivo, se termina con codigo 8 antes
      * de escribir ningun reporte.
      ******************************************************************
       0000-PRINCIPAL.
           DISPLAY "DESCARGA-INTERESES"
           PERFORM 0100-FIJAR-FECHA-PROCESO
           PERFORM 0200-ABRIR-ARCHIVOS
           PERFORM 1000-LEER-TASA
           PERFORM 2000-PROCESAR-TASA UNTIL FIN-INTERESES
           PERFORM 8000-TOTALES
           PERFORM 8500-CERRAR-ARCHIVOS
           DISPLAY "Tasas descargadas a intereses.txt: " WS-CANT
           DISPLAY "Listado: listado_intereses_ok.txt"
           DISPLAY "Descarga terminada (codigo 0)."
           MOVE 0 TO RETURN-CODE
           STOP RUN.

       0100-FIJAR-FECHA-PROCESO.
           MOVE FUNCTION CURRENT-DATE TO WS-FECHA-HORA
           MOVE WS-FECHA-HORA(1:8) TO WS-FECHA-PROCESO
           MOVE SPACES TO WS-FECHA-ENV
           ACCEPT WS-FECHA-ENV FROM ENVIRONMENT "FECHA_PROCESO"
           IF WS-FECHA-ENV NOT = SPACES
               IF WS-FECHA-ENV(1:8) IS NUMERIC
                  AND WS-FECHA-ENV(9:) = SPACES
                   MOVE WS-FECHA-ENV(1:8) TO WS-FECHA-AUX
               ELSE
                   MOVE 0 TO WS-FECHA-AUX
               END-IF
               IF FUNCTION TEST-DATE-YYYYMMDD(WS-FECHA-AUX) = 0
                   MOVE WS-FECHA-AUX TO WS-FECHA-PROCESO
               ELSE
                   DISPLAY "FECHA_PROCESO invalida (use AAAAMMDD): "
                       FUNCTION TRIM(WS-FECHA-ENV)
                   PERFORM 9900-TERMINAR-CON-ERROR
               END-IF
           END-IF
           MOVE WS-FECHA-PROCESO TO WS-FECHA-AUX
           PERFORM 7900-EDITAR-FECHA
           DISPLAY "Fecha de proceso: " WS-FECHA-EDIT.

       0200-ABRIR-ARCHIVOS.
           MOVE "intereses.dat" TO WS-ARCHIVO
           MOVE "OPEN INPUT" TO WS-OPERACION
           OPEN INPUT ARCH-INTERESES
           IF FS-NO-EXISTE
               DISPLAY "No existe intereses.dat. Correr antes "
                   "CARGA-MASIVA."
               PERFORM 9900-TERMINAR-CON-ERROR
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "intereses.txt" TO WS-ARCHIVO
           MOVE "OPEN OUTPUT" TO WS-OPERACION
           OPEN OUTPUT ARCH-PLANO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "listado_intereses_ok.txt" TO WS-ARCHIVO
           OPEN OUTPUT ARCH-LISTADO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Lectura secuencial: llega en orden de clave (moneda + dias).
       1000-LEER-TASA.
           MOVE "intereses.dat" TO WS-ARCHIVO
           MOVE "READ" TO WS-OPERACION
           READ ARCH-INTERESES
               AT END
                   SET FIN-INTERESES TO TRUE
           END-READ
           IF NOT FS-OK AND NOT FS-FIN-ARCHIVO
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       2000-PROCESAR-TASA.
           PERFORM 2100-GRABAR-PLANO
           PERFORM 2200-ESCRIBIR-DETALLE
           PERFORM 2300-ACUMULAR
           PERFORM 1000-LEER-TASA.

      * Un registro del archivo plano: la fecha va con guiones (ISO)
       2100-GRABAR-PLANO.
           MOVE INT-MONEDA         TO PL-MONEDA
           MOVE INT-DIAS           TO PL-DIAS
           MOVE INT-TNA            TO PL-TNA
           MOVE INT-TNA-ANTERIOR   TO PL-TNA-ANT
           MOVE INT-VIGENTE-DESDE  TO WS-FECHA-AUX
           PERFORM 7950-FECHA-ISO
           MOVE WS-FECHA-ISO       TO PL-VIGENTE
           MOVE INT-ESTADO         TO PL-ESTADO
           MOVE "intereses.txt" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-PLANO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       2200-ESCRIBIR-DETALLE.
           IF WS-LINEAS >= WS-MAX-LINEAS
               PERFORM 7000-ENCABEZADO
           END-IF
           MOVE INT-MONEDA TO DT-MONEDA
           EVALUATE TRUE
               WHEN MONEDA-PESOS
                   MOVE "PESOS" TO DT-MONEDA-DESC
               WHEN MONEDA-DOLARES
                   MOVE "DOLARES" TO DT-MONEDA-DESC
               WHEN OTHER
                   MOVE "?" TO DT-MONEDA-DESC
           END-EVALUATE
           MOVE INT-DIAS          TO DT-DIAS
           MOVE INT-TNA           TO DT-TNA
           MOVE INT-TNA-ANTERIOR  TO DT-TNA-ANT
           MOVE INT-VIGENTE-DESDE TO WS-FECHA-AUX
           PERFORM 7900-EDITAR-FECHA
           MOVE WS-FECHA-EDIT     TO DT-VIGENTE
           MOVE INT-ESTADO        TO DT-ESTADO
           EVALUATE TRUE
               WHEN TASA-ACTIVA
                   MOVE "ACTIVA" TO DT-ESTADO-DESC
               WHEN TASA-BAJA
                   MOVE "BAJA" TO DT-ESTADO-DESC
               WHEN OTHER
                   MOVE "?" TO DT-ESTADO-DESC
           END-EVALUATE
           MOVE WS-DETALLE TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           ADD 1 TO WS-LINEAS.

       2300-ACUMULAR.
           ADD 1 TO WS-CANT
           EVALUATE TRUE
               WHEN TASA-ACTIVA
                   ADD 1 TO WS-CANT-A
               WHEN TASA-BAJA
                   ADD 1 TO WS-CANT-B
               WHEN OTHER
                   ADD 1 TO WS-CANT-OTRO
           END-EVALUATE.

      * Titulo principal, fecha y pagina, subtitulos de columnas
       7000-ENCABEZADO.
           ADD 1 TO WS-PAGINA
           IF WS-PAGINA > 1
               MOVE SPACES TO WS-LINEA-REP
               PERFORM 7100-GRABAR-LINEA
           END-IF
           MOVE "GESTION BANCARIA - TASAS DE INTERES CARGADAS (OK)"
               TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE WS-PAGINA TO WS-PAGINA-EDIT
           MOVE SPACES TO WS-LINEA-REP
           STRING "Fecha de proceso: " WS-FECHA-EDIT
               "   Programa: DESCARGA-INTERESES   Pagina: "
               WS-PAGINA-EDIT
               DELIMITED BY SIZE INTO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE SPACES TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE WS-SUBTITULOS TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE ALL "-" TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE 0 TO WS-LINEAS.

       7100-GRABAR-LINEA.
           MOVE "listado_intereses_ok.txt" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-LISTADO FROM WS-LINEA-REP
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * AAAAMMDD (WS-FECHA-AUX) -> DD/MM/AAAA (WS-FECHA-EDIT)
       7900-EDITAR-FECHA.
           MOVE SPACES TO WS-FECHA-EDIT
           STRING WS-FA-DIA "/" WS-FA-MES "/" WS-FA-ANIO
               DELIMITED BY SIZE INTO WS-FECHA-EDIT.

      * AAAAMMDD (WS-FECHA-AUX) -> AAAA-MM-DD (WS-FECHA-ISO)
       7950-FECHA-ISO.
           MOVE SPACES TO WS-FECHA-ISO
           STRING WS-FA-ANIO "-" WS-FA-MES "-" WS-FA-DIA
               DELIMITED BY SIZE INTO WS-FECHA-ISO.

      * Totales de control al pie. Si no habia ninguna tasa, igual
      * sale el titulo (el listado nunca queda vacio).
       8000-TOTALES.
           IF WS-PAGINA = 0
               PERFORM 7000-ENCABEZADO
           END-IF
           MOVE ALL "-" TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE "TOTAL DE TASAS LISTADAS:" TO WS-TOT-TEXTO
           MOVE WS-CANT TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Activas (A):" TO WS-TOT-TEXTO
           MOVE WS-CANT-A TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  De baja (B):" TO WS-TOT-TEXTO
           MOVE WS-CANT-B TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           IF WS-CANT-OTRO > 0
               MOVE "  Con estado desconocido:" TO WS-TOT-TEXTO
               MOVE WS-CANT-OTRO TO WS-TOT-CANT
               PERFORM 8100-GRABAR-TOTAL
           END-IF
           MOVE "REGISTROS GRABADOS EN intereses.txt:" TO WS-TOT-TEXTO
           MOVE WS-CANT TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL.

       8100-GRABAR-TOTAL.
           MOVE WS-LIN-TOTAL TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA.

       8500-CERRAR-ARCHIVOS.
           CLOSE ARCH-INTERESES
           CLOSE ARCH-PLANO
           CLOSE ARCH-LISTADO.

       9000-ERROR-ARCHIVO.
           DISPLAY "Error de archivo: " FUNCTION TRIM(WS-ARCHIVO)
               " (" FUNCTION TRIM(WS-OPERACION) "), FILE STATUS "
               WS-FS
           PERFORM 9900-TERMINAR-CON-ERROR.

       9900-TERMINAR-CON-ERROR.
           DISPLAY "Descarga terminada con error (codigo 8)."
           MOVE 8 TO RETURN-CODE
           STOP RUN.
