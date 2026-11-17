      ******************************************************************
      * PROGRAMA    : DESCARGA-PLAZOS
      * DESCRIPCION : Descarga (UNLOAD) del archivo indexado
      *               plazofijo.dat a un archivo plano de largo fijo
      *               (plazosfijos.txt), listo para importar a la
      *               tabla PLAZOS_FIJOS de Db2. Ademas genera el
      *               listado detallado de los plazos fijos
      *               constituidos (listado_plazos_ok.txt): titulo
      *               principal, subtitulos de columnas, titular del
      *               plazo fijo y totales de control.
      *               CONTROL DE INTEGRIDAD: cada plazo fijo se busca
      *               en clientes_v3.dat (titular) y en intereses.dat
      *               (tasa de su moneda y plazo). Si falta alguno se
      *               marca en el listado (!C = cliente inexistente,
      *               !T = tasa inexistente) y se cuenta en los
      *               totales: en Db2 esos registros serian rechazados
      *               por las claves foraneas. El registro se descarga
      *               igual, para que el rechazo lo muestre Db2.
      * ENTRADA     : plazofijo.dat (indexado por numero de plazo
      *               fijo); clientes_v3.dat e intereses.dat solo
      *               para consulta.
      * SALIDA      : plazosfijos.txt (87 posiciones por registro):
      *                 1-6    PF_NRO
      *                 7-14   DNI del titular
      *                 15     MONEDA (P / D)
      *                 16-29  MONTO (99999999999.99)
      *                 30-32  DIAS
      *                 33-38  TNA APLICADA (999.99)
      *                 39-52  INTERES (99999999999.99)
      *                 53-66  TOTAL (99999999999.99)
      *                 67-76  FECHA ALTA (AAAA-MM-DD)
      *                 77-86  FECHA VENCIMIENTO (AAAA-MM-DD)
      *                 87     ESTADO (A / C / V)
      * FECHA DE
      * PROCESO     : la de la variable de entorno FECHA_PROCESO
      *               (AAAAMMDD) si existe, si no la del sistema. Se
      *               usa solo en el titulo del listado.
      * CODIGO DE
      * RETORNO     : 0 = descarga completa. 8 = no pudo correr
      *               (archivo inexistente, error de archivo o fecha
      *               invalida). Los plazos fijos huerfanos NO cambian
      *               el codigo: quedan informados en los totales.
      * USO         : correr DESPUES de CARGA-MASIVA y NUNCA al mismo
      *               tiempo que otro programa que use los archivos.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DESCARGA-PLAZOS.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. PC.
       OBJECT-COMPUTER. PC.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARCH-PLAZOFIJO ASSIGN TO "plazofijo.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS SEQUENTIAL
               RECORD KEY IS PF-NRO
               FILE STATUS IS WS-FS.

      * Solo consulta, por clave (para el titular y la tasa)
           SELECT ARCH-CLIENTES ASSIGN TO "clientes_v3.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS CLI-DNI
               FILE STATUS IS WS-FS.

           SELECT ARCH-INTERESES ASSIGN TO "intereses.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS INT-CLAVE
               FILE STATUS IS WS-FS.

           SELECT ARCH-PLANO ASSIGN TO "plazosfijos.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

           SELECT ARCH-LISTADO ASSIGN TO "listado_plazos_ok.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARCH-PLAZOFIJO.
           COPY PLAZOFIJO.

       FD  ARCH-CLIENTES.
           COPY CLIENTE.

       FD  ARCH-INTERESES.
           COPY INTERES.

       FD  ARCH-PLANO.
       01  REG-PLANO.
           05  PL-NRO              PIC 9(6).
           05  PL-DNI              PIC 9(8).
           05  PL-MONEDA           PIC X.
           05  PL-MONTO            PIC 9(11).99.
           05  PL-DIAS             PIC 9(3).
           05  PL-TNA              PIC 9(3).99.
           05  PL-INTERES          PIC 9(11).99.
           05  PL-TOTAL            PIC 9(11).99.
           05  PL-ALTA             PIC X(10).
           05  PL-VENC             PIC X(10).
           05  PL-ESTADO           PIC X.

       FD  ARCH-LISTADO.
       01  REG-LISTADO             PIC X(132).

       WORKING-STORAGE SECTION.

      * Estado de la ultima operacion de E/S
       01  WS-FS                   PIC XX     VALUE "00".
           88  FS-OK                          VALUE "00".
           88  FS-FIN-ARCHIVO                 VALUE "10".
           88  FS-CLAVE-NO-ENC                VALUE "23".
           88  FS-NO-EXISTE                   VALUE "35".
       01  WS-OPERACION            PIC X(12)  VALUE SPACES.
       01  WS-ARCHIVO              PIC X(30)  VALUE SPACES.

       01  WS-FIN-PF               PIC X      VALUE "N".
           88  FIN-PLAZOS                     VALUE "S".

      * Resultado de las consultas de integridad
       01  WS-CLI-ENC              PIC X      VALUE "S".
           88  TITULAR-ENCONTRADO             VALUE "S".
           88  TITULAR-NO-ENC                 VALUE "N".
       01  WS-TASA-ENC             PIC X      VALUE "S".
           88  TASA-ENCONTRADA                VALUE "S".
           88  TASA-NO-ENC                    VALUE "N".

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

      * Contadores y totales de control
       01  WS-CANT                 PIC 9(7)      VALUE 0.
       01  WS-CANT-A               PIC 9(7)      VALUE 0.
       01  WS-CANT-C               PIC 9(7)      VALUE 0.
       01  WS-CANT-V               PIC 9(7)      VALUE 0.
       01  WS-CANT-OTRO            PIC 9(7)      VALUE 0.
       01  WS-CANT-P               PIC 9(7)      VALUE 0.
       01  WS-CANT-D               PIC 9(7)      VALUE 0.
       01  WS-HUERF-CLI            PIC 9(7)      VALUE 0.
       01  WS-HUERF-TASA           PIC 9(7)      VALUE 0.
       01  WS-MONTO-P              PIC 9(13)V99  VALUE 0.
       01  WS-MONTO-D              PIC 9(13)V99  VALUE 0.
       01  WS-TOTAL-P              PIC 9(13)V99  VALUE 0.
       01  WS-TOTAL-D              PIC 9(13)V99  VALUE 0.

      * Control de paginas del listado
       01  WS-PAGINA               PIC 9(4)   VALUE 0.
       01  WS-PAGINA-EDIT          PIC ZZZ9.
       01  WS-LINEAS               PIC 99     VALUE 99.
       01  WS-MAX-LINEAS           PIC 99     VALUE 55.

      * Lineas del listado
       01  WS-LINEA-REP            PIC X(132).
       01  WS-SUBTITULOS.
           05  FILLER              PIC X(7)   VALUE "NRO PF".
           05  FILLER              PIC X(9)   VALUE "DNI".
           05  FILLER              PIC X(21)  VALUE "TITULAR".
           05  FILLER              PIC X(2)   VALUE "M".
           05  FILLER              PIC X(18)  VALUE "            MONTO".
           05  FILLER              PIC X(4)   VALUE "DIA".
           05  FILLER              PIC X(7)   VALUE "TNA %".
           05  FILLER              PIC X(18)  VALUE "         INTERES".
           05  FILLER              PIC X(18)  VALUE "           TOTAL".
           05  FILLER              PIC X(11)  VALUE "FECHA ALTA".
           05  FILLER              PIC X(11)  VALUE "FECHA VENC".
           05  FILLER              PIC X(2)   VALUE "E".
           05  FILLER              PIC X(2)   VALUE "OB".
       01  WS-DETALLE.
           05  DT-NRO              PIC 9(6).
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-DNI              PIC 9(8).
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-TITULAR          PIC X(20).
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-MONEDA           PIC X.
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-MONTO            PIC ZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-DIAS             PIC ZZ9.
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-TNA              PIC ZZ9.99.
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-INTERES          PIC ZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-TOTAL            PIC ZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-ALTA             PIC X(10).
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-VENC             PIC X(10).
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-ESTADO           PIC X.
           05  FILLER              PIC X      VALUE SPACE.
           05  DT-OBS              PIC X(4).
       01  WS-LIN-TOTAL.
           05  WS-TOT-TEXTO        PIC X(46).
           05  WS-TOT-CANT         PIC Z,ZZZ,ZZ9.
       01  WS-LIN-TOTAL-IMP.
           05  WS-TOT-IMP-TEXTO    PIC X(46).
           05  WS-TOT-IMP          PIC Z,ZZZ,ZZZ,ZZZ,ZZ9.99.

       PROCEDURE DIVISION.
      ******************************************************************
      * Si no se puede abrir un archivo, se termina con codigo 8 antes
      * de escribir ningun reporte.
      ******************************************************************
       0000-PRINCIPAL.
           DISPLAY "DESCARGA-PLAZOS"
           PERFORM 0100-FIJAR-FECHA-PROCESO
           PERFORM 0200-ABRIR-ARCHIVOS
           PERFORM 1000-LEER-PLAZO
           PERFORM 2000-PROCESAR-PLAZO UNTIL FIN-PLAZOS
           PERFORM 8000-TOTALES
           PERFORM 8500-CERRAR-ARCHIVOS
           DISPLAY "Plazos fijos descargados a plazosfijos.txt: "
               WS-CANT
           DISPLAY "Sin cliente: " WS-HUERF-CLI
               "   Sin tasa: " WS-HUERF-TASA
           DISPLAY "Listado: listado_plazos_ok.txt"
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
           MOVE "plazofijo.dat" TO WS-ARCHIVO
           MOVE "OPEN INPUT" TO WS-OPERACION
           OPEN INPUT ARCH-PLAZOFIJO
           IF FS-NO-EXISTE
               DISPLAY "No existe plazofijo.dat. Correr antes "
                   "CARGA-MASIVA."
               PERFORM 9900-TERMINAR-CON-ERROR
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           OPEN INPUT ARCH-CLIENTES
           IF FS-NO-EXISTE
               DISPLAY "No existe clientes_v3.dat."
               PERFORM 9900-TERMINAR-CON-ERROR
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "intereses.dat" TO WS-ARCHIVO
           OPEN INPUT ARCH-INTERESES
           IF FS-NO-EXISTE
               DISPLAY "No existe intereses.dat."
               PERFORM 9900-TERMINAR-CON-ERROR
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "plazosfijos.txt" TO WS-ARCHIVO
           MOVE "OPEN OUTPUT" TO WS-OPERACION
           OPEN OUTPUT ARCH-PLANO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "listado_plazos_ok.txt" TO WS-ARCHIVO
           OPEN OUTPUT ARCH-LISTADO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Lectura secuencial: llega en orden de numero de plazo fijo.
       1000-LEER-PLAZO.
           MOVE "plazofijo.dat" TO WS-ARCHIVO
           MOVE "READ" TO WS-OPERACION
           READ ARCH-PLAZOFIJO
               AT END
                   SET FIN-PLAZOS TO TRUE
           END-READ
           IF NOT FS-OK AND NOT FS-FIN-ARCHIVO
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       2000-PROCESAR-PLAZO.
           PERFORM 2050-VERIFICAR-INTEGRIDAD
           PERFORM 2100-GRABAR-PLANO
           PERFORM 2200-ESCRIBIR-DETALLE
           PERFORM 2300-ACUMULAR
           PERFORM 1000-LEER-PLAZO.

      * Busca el titular por DNI y la tasa por moneda + dias. Una clave
      * que no existe (FILE STATUS 23) no es un error del programa: se
      * marca el plazo fijo. Cualquier otro estado si lo es.
       2050-VERIFICAR-INTEGRIDAD.
           SET TITULAR-ENCONTRADO TO TRUE
           MOVE PF-DNI TO CLI-DNI
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           MOVE "READ" TO WS-OPERACION
           READ ARCH-CLIENTES
               INVALID KEY
                   SET TITULAR-NO-ENC TO TRUE
           END-READ
           IF NOT FS-OK AND NOT FS-CLAVE-NO-ENC
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           SET TASA-ENCONTRADA TO TRUE
           MOVE PF-MONEDA TO INT-MONEDA
           MOVE PF-DIAS   TO INT-DIAS
           MOVE "intereses.dat" TO WS-ARCHIVO
           READ ARCH-INTERESES
               INVALID KEY
                   SET TASA-NO-ENC TO TRUE
           END-READ
           IF NOT FS-OK AND NOT FS-CLAVE-NO-ENC
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Un registro del archivo plano: valores sin signo, con punto
      * decimal; las fechas van con guiones (ISO).
       2100-GRABAR-PLANO.
           MOVE PF-NRO          TO PL-NRO
           MOVE PF-DNI          TO PL-DNI
           MOVE PF-MONEDA       TO PL-MONEDA
           MOVE PF-MONTO        TO PL-MONTO
           MOVE PF-DIAS         TO PL-DIAS
           MOVE PF-TNA-APLICADA TO PL-TNA
           MOVE PF-INTERES      TO PL-INTERES
           MOVE PF-TOTAL        TO PL-TOTAL
           MOVE PF-FECHA-ALTA   TO WS-FECHA-AUX
           PERFORM 7950-FECHA-ISO
           MOVE WS-FECHA-ISO    TO PL-ALTA
           MOVE PF-FECHA-VENC   TO WS-FECHA-AUX
           PERFORM 7950-FECHA-ISO
           MOVE WS-FECHA-ISO    TO PL-VENC
           MOVE PF-ESTADO       TO PL-ESTADO
           MOVE "plazosfijos.txt" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-PLANO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       2200-ESCRIBIR-DETALLE.
           IF WS-LINEAS >= WS-MAX-LINEAS
               PERFORM 7000-ENCABEZADO
           END-IF
           MOVE PF-NRO          TO DT-NRO
           MOVE PF-DNI          TO DT-DNI
           IF TITULAR-ENCONTRADO
               MOVE CLI-NOMBRE  TO DT-TITULAR
           ELSE
               MOVE "** NO EXISTE **" TO DT-TITULAR
           END-IF
           MOVE PF-MONEDA       TO DT-MONEDA
           MOVE PF-MONTO        TO DT-MONTO
           MOVE PF-DIAS         TO DT-DIAS
           MOVE PF-TNA-APLICADA TO DT-TNA
           MOVE PF-INTERES      TO DT-INTERES
           MOVE PF-TOTAL        TO DT-TOTAL
           MOVE PF-FECHA-ALTA   TO WS-FECHA-AUX
           PERFORM 7900-EDITAR-FECHA
           MOVE WS-FECHA-EDIT   TO DT-ALTA
           MOVE PF-FECHA-VENC   TO WS-FECHA-AUX
           PERFORM 7900-EDITAR-FECHA
           MOVE WS-FECHA-EDIT   TO DT-VENC
           MOVE PF-ESTADO       TO DT-ESTADO
           MOVE SPACES          TO DT-OBS
           IF TITULAR-NO-ENC
               MOVE "!C" TO DT-OBS
           END-IF
           IF TASA-NO-ENC
               IF DT-OBS = SPACES
                   MOVE "!T" TO DT-OBS
               ELSE
                   MOVE "!C!T" TO DT-OBS
               END-IF
           END-IF
           MOVE WS-DETALLE TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           ADD 1 TO WS-LINEAS.

       2300-ACUMULAR.
           ADD 1 TO WS-CANT
           EVALUATE TRUE
               WHEN PF-ACTIVO
                   ADD 1 TO WS-CANT-A
               WHEN PF-CANCELADO
                   ADD 1 TO WS-CANT-C
               WHEN PF-VENCIDO
                   ADD 1 TO WS-CANT-V
               WHEN OTHER
                   ADD 1 TO WS-CANT-OTRO
           END-EVALUATE
           EVALUATE TRUE
               WHEN PF-MONEDA-PESOS
                   ADD 1 TO WS-CANT-P
                   ADD PF-MONTO TO WS-MONTO-P
                   ADD PF-TOTAL TO WS-TOTAL-P
               WHEN PF-MONEDA-DOLARES
                   ADD 1 TO WS-CANT-D
                   ADD PF-MONTO TO WS-MONTO-D
                   ADD PF-TOTAL TO WS-TOTAL-D
           END-EVALUATE
           IF TITULAR-NO-ENC
               ADD 1 TO WS-HUERF-CLI
           END-IF
           IF TASA-NO-ENC
               ADD 1 TO WS-HUERF-TASA
           END-IF.

      * Titulo principal, fecha y pagina, subtitulos de columnas
       7000-ENCABEZADO.
           ADD 1 TO WS-PAGINA
           IF WS-PAGINA > 1
               MOVE SPACES TO WS-LINEA-REP
               PERFORM 7100-GRABAR-LINEA
           END-IF
           MOVE "GESTION BANCARIA - PLAZOS FIJOS CARGADOS (OK)"
               TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE WS-PAGINA TO WS-PAGINA-EDIT
           MOVE SPACES TO WS-LINEA-REP
           STRING "Fecha de proceso: " WS-FECHA-EDIT
               "   Programa: DESCARGA-PLAZOS   Pagina: "
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
           MOVE "listado_plazos_ok.txt" TO WS-ARCHIVO
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

      * Totales de control al pie. Si no habia ningun plazo fijo,
      * igual sale el titulo (el listado nunca queda vacio).
       8000-TOTALES.
           IF WS-PAGINA = 0
               PERFORM 7000-ENCABEZADO
           END-IF
           MOVE ALL "-" TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA
           MOVE "TOTAL DE PLAZOS FIJOS LISTADOS:" TO WS-TOT-TEXTO
           MOVE WS-CANT TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Activos (A):" TO WS-TOT-TEXTO
           MOVE WS-CANT-A TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Cancelados (C):" TO WS-TOT-TEXTO
           MOVE WS-CANT-C TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  Vencidos y acreditados (V):" TO WS-TOT-TEXTO
           MOVE WS-CANT-V TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           IF WS-CANT-OTRO > 0
               MOVE "  Con estado desconocido:" TO WS-TOT-TEXTO
               MOVE WS-CANT-OTRO TO WS-TOT-CANT
               PERFORM 8100-GRABAR-TOTAL
           END-IF
           MOVE "  En pesos (P):" TO WS-TOT-TEXTO
           MOVE WS-CANT-P TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "  En dolares (D):" TO WS-TOT-TEXTO
           MOVE WS-CANT-D TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "SUMA DE CAPITALES EN PESOS (control):"
               TO WS-TOT-IMP-TEXTO
           MOVE WS-MONTO-P TO WS-TOT-IMP
           PERFORM 8200-GRABAR-IMPORTE
           MOVE "SUMA DE TOTALES EN PESOS (control):"
               TO WS-TOT-IMP-TEXTO
           MOVE WS-TOTAL-P TO WS-TOT-IMP
           PERFORM 8200-GRABAR-IMPORTE
           MOVE "SUMA DE CAPITALES EN DOLARES (control):"
               TO WS-TOT-IMP-TEXTO
           MOVE WS-MONTO-D TO WS-TOT-IMP
           PERFORM 8200-GRABAR-IMPORTE
           MOVE "SUMA DE TOTALES EN DOLARES (control):"
               TO WS-TOT-IMP-TEXTO
           MOVE WS-TOTAL-D TO WS-TOT-IMP
           PERFORM 8200-GRABAR-IMPORTE
           MOVE "PLAZOS FIJOS SIN CLIENTE TITULAR (!C):"
               TO WS-TOT-TEXTO
           MOVE WS-HUERF-CLI TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "PLAZOS FIJOS SIN TASA DE MONEDA/DIAS (!T):"
               TO WS-TOT-TEXTO
           MOVE WS-HUERF-TASA TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL
           MOVE "REGISTROS GRABADOS EN plazosfijos.txt:"
               TO WS-TOT-TEXTO
           MOVE WS-CANT TO WS-TOT-CANT
           PERFORM 8100-GRABAR-TOTAL.

       8100-GRABAR-TOTAL.
           MOVE WS-LIN-TOTAL TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA.

       8200-GRABAR-IMPORTE.
           MOVE WS-LIN-TOTAL-IMP TO WS-LINEA-REP
           PERFORM 7100-GRABAR-LINEA.

       8500-CERRAR-ARCHIVOS.
           CLOSE ARCH-PLAZOFIJO
           CLOSE ARCH-CLIENTES
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
