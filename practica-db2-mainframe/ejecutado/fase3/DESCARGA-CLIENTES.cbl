      ******************************************************************
      * PROGRAMA    : DESCARGA-CLIENTES
      * DESCRIPCION : Descarga (UNLOAD) del archivo indexado
      *               clientes_v3.dat a un archivo plano de largo
      *               fijo (clientes.txt), listo para importar a la
      *               tabla CLIENTES de Db2. Ademas genera el listado
      *               detallado de los clientes cargados
      *               (listado_clientes_ok.txt): titulo principal,
      *               subtitulos de columnas, salto de pagina cada
      *               55 lineas y totales de control al final.
      * ENTRADA     : clientes_v3.dat (indexado por DNI), en la
      *               carpeta de ejecucion.
      * SALIDA      : clientes.txt (107 posiciones por registro):
      *                 1-8    DNI
      *                 9-38   NOMBRE
      *                 39-78  DIRECCION
      *                 79-93  TELEFONO
      *                 94-106 SALDO (signo, 9 enteros, punto, 2 dec.)
      *                 107    ESTADO
      *               El saldo se descarga como numero editado con
      *               signo y punto decimal visibles: el campo del
      *               VSAM (S9(9)V99) guarda el signo "pisado" en el
      *               ultimo digito y Db2 no lo entiende.
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
       PROGRAM-ID. DESCARGA-CLIENTES.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. PC.
       OBJECT-COMPUTER. PC.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARCH-CLIENTES ASSIGN TO "clientes_v3.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS SEQUENTIAL
               RECORD KEY IS CLI-DNI
               FILE STATUS IS WS-FS.

           SELECT ARCH-PLANO ASSIGN TO "clientes.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

           SELECT ARCH-LISTADO ASSIGN TO "listado_clientes_ok.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARCH-CLIENTES.
           COPY CLIENTE.

       FD  ARCH-PLANO.
       01  REG-PLANO.
           05  PL-DNI              PIC 9(8).
           05  PL-NOMBRE           PIC X(30).
           05  PL-DIRECCION        PIC X(40).
           05  PL-TELEFONO         PIC X(15).
           05  PL-SALDO            PIC +9(9).99.
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

       01  WS-FIN-CLI              PIC X      VALUE "N".
           88  FIN-CLIENTES                   VALUE "S".

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

      * Contadores y total de control
       01  WS-CANT                 PIC 9(7)      VALUE 0.
       01  WS-CANT-A               PIC 9(7)      VALUE 0.
       01  WS-CANT-I               PIC 9(7)      VALUE 0.
       01  WS-CANT-R               PIC 9(7)      VALUE 0.
       01  WS-CANT-OTRO            PIC 9(7)      VALUE 0.
       01  WS-SUMA-SALDO           PIC S9(11)V99 VALUE 0.

      * Control de paginas del listado
       01  WS-PAGINA               PIC 9(4)   VALUE 0.
       01  WS-PAGINA-EDIT          PIC ZZZ9.
       01  WS-LINEAS               PIC 99     VALUE 99.
       01  WS-MAX-LINEAS           PIC 99     VALUE 55.

      * Lineas del listado
       01  WS-LINEA-REP            PIC X(132).
       01  WS-SUBTITULOS.
           05  FILLER              PIC X(10)  VALUE "DNI".
           05  FILLER              PIC X(31)  VALUE "NOMBRE".
           05  FILLER              PIC X(41)  VALUE "DIRECCION".
           05  FILLER              PIC X(17)  VALUE "TELEFONO".
           05  FILLER              PIC X(18)  VALUE "          SALDO".
           05  FILLER              PIC X(3)   VALUE "EST".
       01  WS-DETALLE.
           05  DT-DNI              PIC 9(8).
           05  FILLER              PIC X(2)   VALUE SPACES.
           05  DT-NOMBRE           PIC X(30).
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-DIRECCION        PIC X(40).
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-TELEFONO         PIC X(15).
           05  FILLER              PIC X(2)   VALUE SPACES.
           05  DT-SALDO            PIC -ZZZ,ZZZ,ZZ9.99.
           05  FILLER              PIC X(3)   VALUE SPACES.
           05  DT-ESTADO           PIC X.
       01  WS-LIN-TOTAL.
           05  WS-TOT-TEXTO        PIC X(40).
           05  WS-TOT-CANT         PIC Z,ZZZ,ZZ9.
       01  WS-LIN-TOTAL-IMP.
           05  WS-TOT-IMP-TEXTO    PIC X(40).
           05  WS-TOT-IMP          PIC -ZZZ,ZZZ,ZZZ,ZZ9.99.

       PROCEDURE DIVISION.
      ******************************************************************
      * Si no se puede abrir un archivo, se termina con codigo 8 antes
      * de escribir ningun reporte.
      ******************************************************************
       0000-PRINCIPAL.
           DISPLAY "DESCARGA-CLIENTES"
           PERFORM 0100-FIJAR-FECHA-PROCESO
           PERFORM 0200-ABRIR-ARCHIVOS
           PERFORM 1000-LEER-CLIENTE
           PERFORM 2000-PROCESAR-CLIENTE UNTIL FIN-CLIENTES
           PERFORM 8000-TOTALES
           PERFORM 8500-CERRAR-ARCHIVOS
           DISPLAY "Clientes descargados a clientes.txt: " WS-CANT
           DISPLAY "Listado: listado_clientes_ok.txt"
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
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           MOVE "OPEN INPUT" TO WS-OPERACION
           OPEN INPUT ARCH-CLIENTES
           IF FS-NO-EXISTE
               DISPLAY "No existe clientes_v3.dat. Correr antes "
                   "CARGA-MASIVA."
               PERFORM 9900-TERMINAR-CON-ERROR
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "clientes.txt" TO WS-ARCHIVO
           MOVE "OPEN OUTPUT" TO WS-OPERACION
           OPEN OUTPUT ARCH-PLANO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "listado_clientes_ok.txt" TO WS-ARCHIVO
           OPEN OUTPUT ARCH-LISTADO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Lectura secuencial: llega en orden de DNI (la clave).
       1000-LEER-CLIENTE.
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           MOVE "READ" TO WS-OPERACION
           READ ARCH-CLIENTES
               AT END
                   SET FIN-CLIENTES TO TRUE
           END-READ
           IF NOT FS-OK AND NOT FS-FIN-ARCHIVO
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       2000-PROCESAR-CLIENTE.
           PERFORM 2100-GRABAR-PLANO
           PERFORM 2200-ESCRIBIR-DETALLE
           PERFORM 2300-ACUMULAR
           PERFORM 1000-LEER-CLIENTE.

      * Un registro del archivo plano: mismos campos, el saldo editado
       2100-GRABAR-PLANO.
           MOVE CLI-DNI       TO PL-DNI
           MOVE CLI-NOMBRE    TO PL-NOMBRE
           MOVE CLI-DIRECCION TO PL-DIRECCION
           MOVE CLI-TELEFONO  TO PL-TELEFONO
           MOVE CLI-SALDO     TO PL-SALDO
           MOVE CLI-ESTADO    TO PL-ESTADO
           MOVE "clientes.txt" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-PLANO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       2200-ESCRIBIR-DETALLE.
           IF WS-LINEAS >= WS-MAX-LINEAS
               PERFORM 7000-ENCABEZADO
           END-IF
           MOVE CLI-DNI       TO DT-DNI
           MOVE CLI-NOMBRE    TO DT-NOMBRE
           MOVE CLI-DIRECCION TO DT-DIRECCION
           MOVE CLI-TELEFONO  TO DT-TELEFONO
           MOVE CLI-SALDO     TO DT-SALDO
           MOVE CLI-ESTADO    TO DT-ESTADO
           MOVE WS-DETALLE TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           ADD 1 TO WS-LINEAS.

       2300-ACUMULAR.
           ADD 1 TO WS-CANT
           ADD CLI-SALDO TO WS-SUMA-SALDO
           EVALUATE TRUE
               WHEN CLIENTE-ACTIVO
                   ADD 1 TO WS-CANT-A
               WHEN CLIENTE-INACTIVO
                   ADD 1 TO WS-CANT-I
               WHEN CLIENTE-REACTIVADO
                   ADD 1 TO WS-CANT-R
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
           MOVE "GESTION BANCARIA - CLIENTES CARGADOS (LISTADO OK)"
               TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE WS-PAGINA TO WS-PAGINA-EDIT
           MOVE SPACES TO WS-LINEA-REP
           STRING "Fecha de proceso: " WS-FECHA-EDIT
               "   Programa: DESCARGA-CLIENTES   Pagina: "
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
           MOVE "listado_clientes_ok.txt" TO WS-ARCHIVO
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

      * Totales de control al pie. Si no habia ningun cliente, igual
      * sale el titulo (el listado nunca queda vacio).
       8000-TOTALES.
           IF WS-PAGINA = 0
               PERFORM 7000-ENCABEZADO
           END-IF
           MOVE ALL "-" TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE "TOTAL DE CLIENTES LISTADOS:" TO WS-TOT-TEXTO
           MOVE WS-CANT TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Activos (A):" TO WS-TOT-TEXTO
           MOVE WS-CANT-A TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Inactivos (I):" TO WS-TOT-TEXTO
           MOVE WS-CANT-I TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Reactivados (R):" TO WS-TOT-TEXTO
           MOVE WS-CANT-R TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           IF WS-CANT-OTRO > 0
               MOVE "  Con estado desconocido:" TO WS-TOT-TEXTO
               MOVE WS-CANT-OTRO TO WS-TOT-CANT
               PERFORM 8100-GRABAR-TOTAL
           END-IF
           MOVE "SUMA DE SALDOS (total de control):"
               TO WS-TOT-IMP-TEXTO
           MOVE WS-SUMA-SALDO TO WS-TOT-IMP
           MOVE WS-LIN-TOTAL-IMP TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE "REGISTROS GRABADOS EN clientes.txt:" TO WS-TOT-TEXTO
           MOVE WS-CANT TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL.

       8100-GRABAR-TOTAL.
           MOVE WS-LIN-TOTAL TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA.

       8500-CERRAR-ARCHIVOS.
           CLOSE ARCH-CLIENTES
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
