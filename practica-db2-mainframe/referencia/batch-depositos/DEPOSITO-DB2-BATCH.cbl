       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEPOSITO-DB2-BATCH.
      *================================================================
      * DISENO DE REFERENCIA - NO COMPILADO CON DB2 REAL.
      * (La logica se probo reemplazando el SQL por una simulacion.)
      *
      * Version BATCH de DEPOSITO-DB2. Aplica depositos masivos sobre
      * la tabla CLIENTES de Db2 (base TESTDB) a partir de un archivo
      * de entrada con N registros, y genera dos listados:
      *   RPTOK   depositos aplicados (cliente, monto, saldo antes y
      *           despues)
      *   RPTERR  depositos rechazados, con codigo y motivo
      *
      * ARCHIVOS (nombres logicos; en z/OS son los DD del JCL):
      *   ENTRADA  entrada, secuencial de 80 bytes
      *              col  1- 8  DNI (8 digitos, con ceros a la izq.)
      *              col  9-19  monto: 11 digitos, 2 decimales
      *                         implicitos (sin punto)
      *              col 20-39  referencia (obligatoria y unica)
      *   RPTOK    salida, listado de depositos aplicados
      *   RPTERR   salida, listado de depositos rechazados
      *   SYSIN    entrada, UNA linea con el ID del lote (hasta 20
      *            caracteres). Identifica la corrida del archivo.
      *
      * CODIGOS DE RECHAZO (columna CD de RPTERR):
      *   01  DNI no numerico o vacio
      *   02  monto no numerico
      *   03  monto en cero
      *   04  cliente inexistente (FETCH con SQLCODE 100)
      *   05  cliente no activo (ESTADO distinto de "A")
      *   06  el saldo resultante excede el maximo (9 enteros)
      *   07  SQLCODE -911 (timeout o deadlock) y se agotaron los
      *       reintentos
      *   08  deposito ya aplicado: la referencia ya esta en el
      *       historial (SQLCODE -803 al insertar)
      *   09  error SQL inesperado (se informa el SQLCODE)
      *   10  referencia vacia
      *
      * CODIGO DE RETORNO (RETURN-CODE, para el JCL / Control-M):
      *   0   todo aplicado
      *   4   termino bien pero hubo rechazos (revisar RPTERR)
      *   12  error grave: no conecta, no abre archivos, falta el ID
      *       de lote, lote ya procesado, aborto por errores SQL
      *       seguidos o los totales de control no cuadran
      *
      * UNIDAD DE TRABAJO: cada registro es una transaccion propia
      * (un COMMIT por registro). Un rechazo no afecta a los demas.
      * Ante -911 se reintenta ese registro completo (maximo
      * WS-MAX-INTENTOS). Si hay WS-MAX-ERR-SQL registros seguidos con
      * error SQL inesperado, se corta (la base probablemente cayo).
      *
      * REINICIO ANTE CORTES (checkpoint + historial):
      *   Si el proceso se corta (caida del sistema, abend, apagon),
      *   se vuelve a ejecutar con el MISMO archivo y el MISMO ID de
      *   lote, y continua donde quedo sin repetir depositos.
      *   - CONTROL_PROCESO: una fila por lote con el ultimo registro
      *     confirmado, los contadores y el estado (P en proceso,
      *     F finalizado). Se actualiza en la MISMA transaccion que
      *     el deposito: o se confirma todo junto, o nada.
      *   - HISTORIAL_DEPOSITOS: una fila por deposito aplicado, con
      *     la referencia como clave unica. Es la segunda red de
      *     seguridad: si por cualquier motivo se intenta aplicar dos
      *     veces la misma referencia, el INSERT da -803 y el
      *     deposito se rechaza como ya aplicado (codigo 08).
      *   Al reiniciar se leen y se descartan los registros ya
      *   confirmados, se restauran los contadores y los listados se
      *   abren para agregar al final (OPEN EXTEND).
      *   Limitacion: los listados no son transaccionales. Tras un
      *   corte puede faltar la linea del ultimo registro confirmado;
      *   la fuente de verdad es la base (ver crear_tablas_batch.sql).
      *
      * JCL que lo ejecuta: DEPOSITO-DB2-BATCH.jcl
      *
      * Requiere precompilar (EXEC SQL -> CALL) y enlazar el modulo
      * de acceso a la base. No corre con GnuCOBOL solo.
      *================================================================
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARCH-ENT ASSIGN TO ENTRADA
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS FS-ENTRADA.
           SELECT RPT-OK   ASSIGN TO RPTOK
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS FS-RPT-OK.
           SELECT RPT-ERR  ASSIGN TO RPTERR
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS FS-RPT-ERR.

       DATA DIVISION.
       FILE SECTION.
       FD  ARCH-ENT.
       01  REG-ENT.
           05 ENT-DNI             PIC X(8).
           05 ENT-DNI-N REDEFINES ENT-DNI
                                  PIC 9(8).
           05 ENT-MONTO           PIC X(11).
           05 ENT-MONTO-N REDEFINES ENT-MONTO
                                  PIC 9(9)V99.
           05 ENT-REF             PIC X(20).
           05 FILLER              PIC X(41).

       FD  RPT-OK.
       01  LIN-OK                 PIC X(132).

       FD  RPT-ERR.
       01  LIN-ERR                PIC X(132).

       WORKING-STORAGE SECTION.

      *--- Area de comunicacion de SQL (SQLCODE, SQLERRMC, etc.)
           EXEC SQL INCLUDE SQLCA END-EXEC.

      *--- Variables huesped: las que intercambian datos con Db2.
      *    INTEGER -> S9(9) COMP-5 (en z/OS: COMP)
      *    DECIMAL(11,2) -> S9(9)V99 COMP-3
      *    DECIMAL(15,2) -> S9(13)V99 COMP-3
      *    CHAR(20) -> X(20)
      *    VARCHAR(30) -> grupo con largo (49) y texto (49)
           EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-DNI                 PIC S9(9)     COMP-5.
       01  HV-MONTO               PIC S9(9)V99  COMP-3.
       01  HV-SALDO               PIC S9(9)V99  COMP-3.
       01  HV-ESTADO              PIC X(1).
       01  HV-NOMBRE.
           49 HV-NOMBRE-LEN       PIC S9(4)     COMP-5.
           49 HV-NOMBRE-TEXT      PIC X(30).
       01  HV-REF                 PIC X(20).
       01  HV-LOTE                PIC X(20).
       01  HV-PROCESO             PIC X(20)
                                  VALUE "DEPOSITO-DB2-BATCH".
       01  HV-NRO-REG             PIC S9(9)     COMP-5.
      *    Checkpoint (fila de CONTROL_PROCESO).
       01  HV-ULT                 PIC S9(9)     COMP-5.
       01  HV-APL                 PIC S9(9)     COMP-5.
       01  HV-REC                 PIC S9(9)     COMP-5.
       01  HV-ML                  PIC S9(13)V99 COMP-3.
       01  HV-MO                  PIC S9(13)V99 COMP-3.
       01  HV-MR                  PIC S9(13)V99 COMP-3.
       01  HV-CTL-ESTADO          PIC X(1).
           EXEC SQL END DECLARE SECTION END-EXEC.

      *--- Cursor: lee y reserva (bloqueo U) la fila del cliente.
           EXEC SQL DECLARE C-CLI CURSOR FOR
               SELECT NOMBRE, SALDO, ESTADO
                 FROM CLIENTES
                WHERE DNI = :HV-DNI
                  FOR UPDATE OF SALDO
           END-EXEC.

      *--- Estados de los archivos.
       01  FS-ENTRADA             PIC XX.
       01  FS-RPT-OK              PIC XX.
       01  FS-RPT-ERR             PIC XX.

      *--- Banderas y control del proceso.
       01  WS-FIN                 PIC X         VALUE "N".
           88 FIN-ENTRADA                       VALUE "S".
       01  WS-ABORTO              PIC X         VALUE "N".
           88 ABORTAR                           VALUE "S".
       01  WS-VALIDO              PIC X         VALUE "S".
           88 REG-VALIDO                        VALUE "S".
           88 REG-INVALIDO                      VALUE "N".
       01  WS-CONTROL             PIC X         VALUE "S".
           88 CONTROL-OK                        VALUE "S".
       01  WS-CIERRE              PIC X         VALUE "S".
           88 CIERRE-OK                         VALUE "S".
       01  WS-MODO                PIC X         VALUE "N".
           88 ES-REINICIO                       VALUE "R".
       01  WS-ESTADO              PIC X         VALUE SPACE.
           88 ES-OK                             VALUE "O".
           88 ES-REINTENTAR                     VALUE "R".
           88 ES-RECHAZO                        VALUE "E".
       01  WS-COD-RECHAZO         PIC 99        VALUE 0.
       01  WS-INTENTO             PIC 9         VALUE 0.
       01  WS-MAX-INTENTOS        PIC 9         VALUE 3.
       01  WS-ERR-SQL-SEGUIDOS    PIC 99        VALUE 0.
       01  WS-MAX-ERR-SQL         PIC 99        VALUE 5.

      *--- Lote y reinicio.
       01  WS-LOTE-ID             PIC X(20)     VALUE SPACES.
       01  WS-SALTEAR             PIC 9(7)      VALUE 0.
       01  WS-I                   PIC 9(7)      VALUE 0.
       01  WS-MARCA               PIC X(132).

      *--- Ultimo resultado SQL (se guarda antes de cualquier ROLLBACK,
      *    que pisaria el SQLCODE).
       01  WS-SQLCODE-ULT         PIC S9(9)     VALUE 0.
       01  WS-SQLERRMC-ULT        PIC X(70)     VALUE SPACES.
       01  WS-SQLCODE-ED          PIC -(9)9.

       01  WS-SALDO-ANT           PIC S9(9)V99  VALUE 0.
       01  WS-DESC                PIC X(40).

      *--- Contadores y totales de control (en un reinicio se
      *    restauran desde CONTROL_PROCESO).
       01  WS-LEIDOS              PIC 9(7)      VALUE 0.
       01  WS-OK                  PIC 9(7)      VALUE 0.
       01  WS-RECH                PIC 9(7)      VALUE 0.
       01  WS-TOT-MONTO-LEIDO     PIC 9(11)V99  VALUE 0.
       01  WS-TOT-MONTO-OK        PIC 9(11)V99  VALUE 0.
       01  WS-TOT-MONTO-RECH      PIC 9(11)V99  VALUE 0.
       01  WS-CANT-ED             PIC Z,ZZZ,ZZ9.
       01  WS-MONTO-ED            PIC ZZ,ZZZ,ZZZ,ZZ9.99.

       01  WS-FECHA               PIC 9(8).
       01  WS-FECHA-R REDEFINES WS-FECHA.
           05 WS-FEC-AAAA         PIC 9(4).
           05 WS-FEC-MM           PIC 99.
           05 WS-FEC-DD           PIC 99.

      *--- Listado de depositos aplicados.
       01  WS-CAB-OK.
           05 FILLER              PIC X(8)  VALUE "   REG  ".
           05 FILLER              PIC X(10) VALUE "DNI".
           05 FILLER              PIC X(32) VALUE "NOMBRE".
           05 FILLER              PIC X(22) VALUE "REFERENCIA".
           05 FILLER              PIC X(16) VALUE "         MONTO  ".
           05 FILLER              PIC X(18) VALUE "  SALDO ANTERIOR  ".
           05 FILLER              PIC X(16) VALUE "     SALDO NUEVO".
       01  WS-LIN-OK.
           05 LO-NRO              PIC ZZZZZ9.
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LO-DNI              PIC 9(8).
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LO-NOMBRE           PIC X(30).
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LO-REF              PIC X(20).
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LO-MONTO            PIC ZZZ,ZZZ,ZZ9.99.
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LO-SALDO-ANT        PIC -,---,---,--9.99.
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LO-SALDO-NVO        PIC -,---,---,--9.99.

      *--- Listado de depositos rechazados.
       01  WS-CAB-ERR.
           05 FILLER              PIC X(8)  VALUE "   REG  ".
           05 FILLER              PIC X(10) VALUE "DNI".
           05 FILLER              PIC X(13) VALUE "MONTO".
           05 FILLER              PIC X(22) VALUE "REFERENCIA".
           05 FILLER              PIC X(4)  VALUE "CD".
           05 FILLER              PIC X(42) VALUE "MOTIVO".
           05 FILLER              PIC X(10) VALUE "SQLCODE".
       01  WS-LIN-ERR.
           05 LE-NRO              PIC ZZZZZ9.
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LE-DNI              PIC X(8).
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LE-MONTO            PIC X(11).
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LE-REF              PIC X(20).
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LE-COD              PIC 99.
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LE-DESC             PIC X(40).
           05 FILLER              PIC X(2)  VALUE SPACES.
           05 LE-SQLCODE          PIC X(10).

      *--- Linea de totales (se usa en los dos listados).
       01  WS-TOT-LIN.
           05 TL-TEXTO            PIC X(32).
           05 TL-CANT             PIC Z,ZZZ,ZZ9.
           05 FILLER              PIC X(3)  VALUE SPACES.
           05 TL-MONTO            PIC ZZ,ZZZ,ZZZ,ZZ9.99.

       PROCEDURE DIVISION.

       0000-PRINCIPAL.
           PERFORM 1000-INICIO
           PERFORM 2000-LEER-ENTRADA
      *    Un registro por vuelta. Se corta al terminar el archivo o
      *    si se pidio abortar.
           PERFORM 3000-PROCESAR-REGISTRO
               UNTIL FIN-ENTRADA OR ABORTAR
           PERFORM 9000-FIN
           STOP RUN.

      *----------------------------------------------------------------
       1000-INICIO.
           PERFORM 1050-LEER-LOTE
           PERFORM 1100-CONECTAR
           PERFORM 1400-CONTROL-LOTE
           PERFORM 1200-ABRIR-ARCHIVOS
           IF ES-REINICIO
              PERFORM 1500-REINICIAR
           ELSE
              PERFORM 1300-CABECERAS
           END-IF.

      *    El ID de lote identifica la corrida de este archivo. Lo da
      *    quien planifica el job (en Control-M puede armarse con la
      *    fecha de orden). Se lee de SYSIN.
       1050-LEER-LOTE.
           ACCEPT WS-LOTE-ID
           IF WS-LOTE-ID = SPACES
              DISPLAY "FALTA EL ID DE LOTE (SYSIN)"
              MOVE 12 TO RETURN-CODE
              STOP RUN
           END-IF
           MOVE WS-LOTE-ID TO HV-LOTE.

      *    Conexion (Db2 LUW). En z/OS no hay CONNECT: la conexion la
      *    da el entorno (DSN en batch).
       1100-CONECTAR.
           EXEC SQL CONNECT TO TESTDB END-EXEC
           IF SQLCODE NOT = 0
              MOVE SQLCODE TO WS-SQLCODE-ED
              DISPLAY "NO SE PUDO CONECTAR A TESTDB. SQLCODE="
                      WS-SQLCODE-ED
              MOVE 12 TO RETURN-CODE
              STOP RUN
           END-IF.

       1200-ABRIR-ARCHIVOS.
           OPEN INPUT ARCH-ENT
           IF FS-ENTRADA NOT = "00"
              DISPLAY "NO SE PUDO ABRIR ENTRADA. FILE STATUS="
                      FS-ENTRADA
              PERFORM 9900-ABORTO-FATAL
           END-IF
      *    En un reinicio los listados se abren para agregar al final.
           IF ES-REINICIO
              OPEN EXTEND RPT-OK
           ELSE
              OPEN OUTPUT RPT-OK
           END-IF
           IF FS-RPT-OK NOT = "00" AND FS-RPT-OK NOT = "05"
              DISPLAY "NO SE PUDO ABRIR RPTOK. FILE STATUS="
                      FS-RPT-OK
              PERFORM 9900-ABORTO-FATAL
           END-IF
           IF ES-REINICIO
              OPEN EXTEND RPT-ERR
           ELSE
              OPEN OUTPUT RPT-ERR
           END-IF
           IF FS-RPT-ERR NOT = "00" AND FS-RPT-ERR NOT = "05"
              DISPLAY "NO SE PUDO ABRIR RPTERR. FILE STATUS="
                      FS-RPT-ERR
              PERFORM 9900-ABORTO-FATAL
           END-IF.

       1300-CABECERAS.
           ACCEPT WS-FECHA FROM DATE YYYYMMDD

           MOVE "DEPOSITOS APLICADOS - DEPOSITO-DB2-BATCH" TO LIN-OK
           WRITE LIN-OK
           MOVE SPACES TO LIN-OK
           STRING "FECHA DE PROCESO: " WS-FEC-DD "/" WS-FEC-MM "/"
                  WS-FEC-AAAA "   LOTE: " WS-LOTE-ID
                  DELIMITED BY SIZE INTO LIN-OK
           END-STRING
           WRITE LIN-OK
           MOVE SPACES TO LIN-OK
           WRITE LIN-OK
           WRITE LIN-OK FROM WS-CAB-OK

           MOVE "DEPOSITOS RECHAZADOS - DEPOSITO-DB2-BATCH" TO LIN-ERR
           WRITE LIN-ERR
           MOVE SPACES TO LIN-ERR
           STRING "FECHA DE PROCESO: " WS-FEC-DD "/" WS-FEC-MM "/"
                  WS-FEC-AAAA "   LOTE: " WS-LOTE-ID
                  DELIMITED BY SIZE INTO LIN-ERR
           END-STRING
           WRITE LIN-ERR
           MOVE SPACES TO LIN-ERR
           WRITE LIN-ERR
           WRITE LIN-ERR FROM WS-CAB-ERR.

      *----------------------------------------------------------------
      * Control del lote: consulta CONTROL_PROCESO.
      *   no existe  -> lote nuevo: se da de alta con contadores en 0
      *   estado F   -> el lote ya termino: no se reprocesa
      *   estado P   -> el lote se corto: REINICIO, se restauran los
      *                 contadores y se continua despues del ultimo
      *                 registro confirmado
      *----------------------------------------------------------------
       1400-CONTROL-LOTE.
           EXEC SQL SELECT ULTIMO_REG, APLICADOS, RECHAZADOS,
                           MONTO_LEIDO, MONTO_OK, MONTO_RECH,
                           ESTADO
                      INTO :HV-ULT, :HV-APL, :HV-REC,
                           :HV-ML, :HV-MO, :HV-MR, :HV-CTL-ESTADO
                      FROM CONTROL_PROCESO
                     WHERE PROCESO = :HV-PROCESO
                       AND LOTE_ID = :HV-LOTE
           END-EXEC
           EVALUATE SQLCODE
              WHEN 100
                 PERFORM 1410-ALTA-LOTE
              WHEN 0
      *          Termina la lectura (suelta bloqueos).
                 EXEC SQL COMMIT END-EXEC
                 PERFORM 1420-EVALUAR-LOTE
              WHEN OTHER
                 PERFORM 6900-ERROR-FATAL-SQL
           END-EVALUATE.

       1410-ALTA-LOTE.
           EXEC SQL INSERT INTO CONTROL_PROCESO
                      (PROCESO, LOTE_ID, ULTIMO_REG, APLICADOS,
                       RECHAZADOS, MONTO_LEIDO, MONTO_OK,
                       MONTO_RECH, ESTADO, FECHA_ULT_ACT)
                    VALUES
                      (:HV-PROCESO, :HV-LOTE, 0, 0, 0, 0, 0, 0,
                       'P', CURRENT TIMESTAMP)
           END-EXEC
           IF SQLCODE NOT = 0
              PERFORM 6900-ERROR-FATAL-SQL
           END-IF
           EXEC SQL COMMIT END-EXEC
           IF SQLCODE NOT = 0
              PERFORM 6900-ERROR-FATAL-SQL
           END-IF.

       1420-EVALUAR-LOTE.
           IF HV-CTL-ESTADO = "F"
              DISPLAY "EL LOTE " WS-LOTE-ID
              DISPLAY "YA FUE PROCESADO COMPLETO. NO SE REPROCESA."
              PERFORM 9900-ABORTO-FATAL
           END-IF
      *    Estado P: si ya hay registros confirmados es un reinicio.
      *    Si el ultimo es 0, el corte fue antes del primero y se
      *    trata como lote nuevo.
           IF HV-ULT > 0
              SET ES-REINICIO TO TRUE
              MOVE HV-ULT TO WS-LEIDOS
              MOVE HV-ULT TO WS-SALTEAR
              MOVE HV-APL TO WS-OK
              MOVE HV-REC TO WS-RECH
              MOVE HV-ML  TO WS-TOT-MONTO-LEIDO
              MOVE HV-MO  TO WS-TOT-MONTO-OK
              MOVE HV-MR  TO WS-TOT-MONTO-RECH
           END-IF.

      *----------------------------------------------------------------
      * Reinicio: se leen y descartan los registros que ya estaban
      * confirmados, y se deja una marca en los dos listados.
      *----------------------------------------------------------------
       1500-REINICIAR.
           MOVE 0 TO WS-I
           PERFORM UNTIL WS-I >= WS-SALTEAR
              READ ARCH-ENT
                 AT END
                    DISPLAY "REINICIO: EL ARCHIVO TIENE MENOS "
                            "REGISTROS QUE EL CHECKPOINT"
                    PERFORM 9900-ABORTO-FATAL
              END-READ
              ADD 1 TO WS-I
           END-PERFORM
           MOVE WS-SALTEAR TO WS-CANT-ED
           DISPLAY "REINICIO DEL LOTE " WS-LOTE-ID
           DISPLAY "  SE SALTEAN " WS-CANT-ED
                   " REGISTROS YA CONFIRMADOS"
           MOVE SPACES TO WS-MARCA
           STRING "*** REINICIO: SE CONTINUA DESPUES DEL REGISTRO "
                  WS-SALTEAR " ***"
                  DELIMITED BY SIZE INTO WS-MARCA
           END-STRING
           WRITE LIN-OK FROM WS-MARCA
           WRITE LIN-ERR FROM WS-MARCA.

      *----------------------------------------------------------------
       2000-LEER-ENTRADA.
           READ ARCH-ENT
               AT END
                  SET FIN-ENTRADA TO TRUE
           END-READ
           IF FS-ENTRADA NOT = "00" AND FS-ENTRADA NOT = "10"
              DISPLAY "ERROR DE LECTURA EN ENTRADA. FILE STATUS="
                      FS-ENTRADA
              PERFORM 9900-ABORTO-FATAL
           END-IF.

      *----------------------------------------------------------------
      * Procesa el registro actual: valida, aplica el deposito (con
      * reintentos si hace falta), graba el checkpoint y lo informa en
      * el listado que corresponda. Al final lee el siguiente.
      *----------------------------------------------------------------
       3000-PROCESAR-REGISTRO.
           ADD 1 TO WS-LEIDOS
           MOVE 0 TO WS-INTENTO
           MOVE 0 TO WS-COD-RECHAZO
           MOVE 0 TO WS-SQLCODE-ULT
           MOVE SPACE TO WS-ESTADO

           PERFORM 3100-VALIDAR-REGISTRO
           IF REG-VALIDO
              PERFORM 3200-DEPOSITAR
                  UNTIL ES-OK OR ES-RECHAZO
           ELSE
              SET ES-RECHAZO TO TRUE
           END-IF

      *    Si se aplico, el checkpoint ya se confirmo junto con el
      *    deposito. Si se rechazo, se confirma ahora por separado.
           IF ES-RECHAZO
              PERFORM 6000-CHECKPOINT-RECHAZO
           END-IF

      *    Los listados se escriben DESPUES del COMMIT: reflejan solo
      *    lo confirmado.
           IF ES-OK
              PERFORM 4000-REGISTRAR-OK
           ELSE
              PERFORM 5000-REGISTRAR-ERROR
           END-IF

      *    Corte de seguridad: varios errores SQL inesperados seguidos
      *    suelen indicar que la base no esta disponible.
           IF WS-COD-RECHAZO = 09
              ADD 1 TO WS-ERR-SQL-SEGUIDOS
           ELSE
              MOVE 0 TO WS-ERR-SQL-SEGUIDOS
           END-IF
           IF WS-ERR-SQL-SEGUIDOS >= WS-MAX-ERR-SQL
              DISPLAY "ABORTO: " WS-ERR-SQL-SEGUIDOS
                      " ERRORES SQL SEGUIDOS"
              SET ABORTAR TO TRUE
           END-IF

           IF NOT ABORTAR
              PERFORM 2000-LEER-ENTRADA
           END-IF.

      *----------------------------------------------------------------
      * Validaciones que no necesitan la base.
      *----------------------------------------------------------------
       3100-VALIDAR-REGISTRO.
           SET REG-VALIDO TO TRUE
           IF ENT-MONTO IS NUMERIC
              ADD ENT-MONTO-N TO WS-TOT-MONTO-LEIDO
           END-IF
           EVALUATE TRUE
              WHEN ENT-DNI NOT NUMERIC
                 MOVE 01 TO WS-COD-RECHAZO
              WHEN ENT-MONTO NOT NUMERIC
                 MOVE 02 TO WS-COD-RECHAZO
              WHEN ENT-MONTO-N = 0
                 MOVE 03 TO WS-COD-RECHAZO
              WHEN ENT-REF = SPACES
                 MOVE 10 TO WS-COD-RECHAZO
           END-EVALUATE
           IF WS-COD-RECHAZO NOT = 0
              SET REG-INVALIDO TO TRUE
           ELSE
              MOVE ENT-DNI-N   TO HV-DNI
              MOVE ENT-MONTO-N TO HV-MONTO
              MOVE ENT-REF     TO HV-REF
              MOVE WS-LEIDOS   TO HV-NRO-REG
           END-IF.

      *----------------------------------------------------------------
      * Una transaccion: abrir cursor (reserva la fila), leer, validar
      * el estado, sumar, registrar en el historial, actualizar el
      * saldo, grabar el checkpoint, cerrar y confirmar con UN solo
      * COMMIT. Despues de cada sentencia SQL se evalua el SQLCODE; si
      * algo falla se corta el resto. Si Db2 pide reintentar (-911),
      * el que llama vuelve a ejecutar este parrafo completo.
      *----------------------------------------------------------------
       3200-DEPOSITAR.
           ADD 1 TO WS-INTENTO
           MOVE SPACE TO WS-ESTADO

           EXEC SQL OPEN C-CLI END-EXEC
           PERFORM 8000-EVALUAR-SQLCODE

           IF ES-OK
              EXEC SQL FETCH C-CLI
                   INTO :HV-NOMBRE, :HV-SALDO, :HV-ESTADO
              END-EXEC
              IF SQLCODE = 100
                 MOVE 04 TO WS-COD-RECHAZO
                 PERFORM 8100-RECHAZAR
              ELSE
                 PERFORM 8000-EVALUAR-SQLCODE
              END-IF
           END-IF

           IF ES-OK
              IF HV-ESTADO NOT = "A"
                 MOVE 05 TO WS-COD-RECHAZO
                 PERFORM 8100-RECHAZAR
              ELSE
                 MOVE HV-SALDO TO WS-SALDO-ANT
                 ADD HV-MONTO TO HV-SALDO
                     ON SIZE ERROR
                        MOVE 06 TO WS-COD-RECHAZO
                        PERFORM 8100-RECHAZAR
                 END-ADD
              END-IF
           END-IF

      *    Historial: si la referencia ya existe (-803) el deposito
      *    ya se aplico antes. No es un error de SQL: se rechaza como
      *    "ya aplicado" y no se toca el saldo.
           IF ES-OK
              EXEC SQL INSERT INTO HISTORIAL_DEPOSITOS
                         (REFERENCIA, LOTE_ID, NRO_REG, DNI,
                          MONTO, FECHA_PROCESO)
                       VALUES
                         (:HV-REF, :HV-LOTE, :HV-NRO-REG, :HV-DNI,
                          :HV-MONTO, CURRENT DATE)
              END-EXEC
              IF SQLCODE = -803
                 MOVE 08 TO WS-COD-RECHAZO
                 PERFORM 8100-RECHAZAR
              ELSE
                 PERFORM 8000-EVALUAR-SQLCODE
              END-IF
           END-IF

           IF ES-OK
              EXEC SQL UPDATE CLIENTES
                          SET SALDO = :HV-SALDO
                        WHERE CURRENT OF C-CLI
              END-EXEC
              PERFORM 8000-EVALUAR-SQLCODE
           END-IF

      *    Checkpoint dentro de la MISMA transaccion que el deposito.
           IF ES-OK
              PERFORM 6100-PREPARAR-CHECKPOINT
              EXEC SQL UPDATE CONTROL_PROCESO
                          SET ULTIMO_REG = :HV-ULT,
                              APLICADOS = :HV-APL,
                              RECHAZADOS = :HV-REC,
                              MONTO_LEIDO = :HV-ML,
                              MONTO_OK = :HV-MO,
                              MONTO_RECH = :HV-MR,
                              FECHA_ULT_ACT = CURRENT TIMESTAMP
                        WHERE PROCESO = :HV-PROCESO
                          AND LOTE_ID = :HV-LOTE
              END-EXEC
              PERFORM 8000-EVALUAR-SQLCODE
           END-IF

           IF ES-OK
              EXEC SQL CLOSE C-CLI END-EXEC
              EXEC SQL COMMIT END-EXEC
              PERFORM 8000-EVALUAR-SQLCODE
           END-IF.

      *----------------------------------------------------------------
      * Registro aplicado: va al listado RPTOK.
      *----------------------------------------------------------------
       4000-REGISTRAR-OK.
           ADD 1 TO WS-OK
           ADD HV-MONTO TO WS-TOT-MONTO-OK
           MOVE WS-LEIDOS    TO LO-NRO
           MOVE ENT-DNI-N    TO LO-DNI
           MOVE SPACES       TO LO-NOMBRE
           IF HV-NOMBRE-LEN > 0
              MOVE HV-NOMBRE-TEXT(1:HV-NOMBRE-LEN) TO LO-NOMBRE
           END-IF
           MOVE ENT-REF      TO LO-REF
           MOVE HV-MONTO     TO LO-MONTO
           MOVE WS-SALDO-ANT TO LO-SALDO-ANT
           MOVE HV-SALDO     TO LO-SALDO-NVO
           WRITE LIN-OK FROM WS-LIN-OK.

      *----------------------------------------------------------------
      * Registro rechazado: va al listado RPTERR con codigo y motivo.
      *----------------------------------------------------------------
       5000-REGISTRAR-ERROR.
           ADD 1 TO WS-RECH
           IF ENT-MONTO IS NUMERIC
              ADD ENT-MONTO-N TO WS-TOT-MONTO-RECH
           END-IF
           EVALUATE WS-COD-RECHAZO
              WHEN 01
                 MOVE "DNI NO NUMERICO O VACIO" TO WS-DESC
              WHEN 02
                 MOVE "MONTO NO NUMERICO" TO WS-DESC
              WHEN 03
                 MOVE "MONTO EN CERO" TO WS-DESC
              WHEN 04
                 MOVE "CLIENTE INEXISTENTE" TO WS-DESC
              WHEN 05
                 MOVE "CLIENTE NO ACTIVO" TO WS-DESC
              WHEN 06
                 MOVE "SALDO RESULTANTE EXCEDE EL MAXIMO" TO WS-DESC
              WHEN 07
                 MOVE "-911: REINTENTOS AGOTADOS" TO WS-DESC
              WHEN 08
                 MOVE "YA APLICADO (REFERENCIA REPETIDA)" TO WS-DESC
              WHEN 10
                 MOVE "REFERENCIA VACIA" TO WS-DESC
              WHEN OTHER
                 MOVE "ERROR SQL INESPERADO" TO WS-DESC
           END-EVALUATE

           MOVE WS-LEIDOS      TO LE-NRO
           MOVE ENT-DNI        TO LE-DNI
           MOVE ENT-MONTO      TO LE-MONTO
           MOVE ENT-REF        TO LE-REF
           MOVE WS-COD-RECHAZO TO LE-COD
           MOVE WS-DESC        TO LE-DESC
           MOVE SPACES         TO LE-SQLCODE
           IF WS-COD-RECHAZO = 07 OR WS-COD-RECHAZO = 09
              MOVE WS-SQLCODE-ULT TO WS-SQLCODE-ED
              MOVE WS-SQLCODE-ED  TO LE-SQLCODE
           END-IF
           WRITE LIN-ERR FROM WS-LIN-ERR

           IF WS-COD-RECHAZO = 09
              DISPLAY "REG " LE-NRO " ERROR SQL. SQLCODE="
                      WS-SQLCODE-ED
              DISPLAY WS-SQLERRMC-ULT
           END-IF.

      *----------------------------------------------------------------
      * Checkpoint de un registro RECHAZADO: no hubo cambio de saldo,
      * pero igual hay que dejar constancia de que el registro se
      * proceso. Es una transaccion propia (UPDATE + COMMIT).
      *----------------------------------------------------------------
       6000-CHECKPOINT-RECHAZO.
           PERFORM 6100-PREPARAR-CHECKPOINT
           EXEC SQL UPDATE CONTROL_PROCESO
                       SET ULTIMO_REG = :HV-ULT,
                           APLICADOS = :HV-APL,
                           RECHAZADOS = :HV-REC,
                           MONTO_LEIDO = :HV-ML,
                           MONTO_OK = :HV-MO,
                           MONTO_RECH = :HV-MR,
                           FECHA_ULT_ACT = CURRENT TIMESTAMP
                     WHERE PROCESO = :HV-PROCESO
                       AND LOTE_ID = :HV-LOTE
           END-EXEC
           IF SQLCODE NOT = 0
              PERFORM 6900-ERROR-FATAL-SQL
           END-IF
           EXEC SQL COMMIT END-EXEC
           IF SQLCODE NOT = 0
              PERFORM 6900-ERROR-FATAL-SQL
           END-IF.

      *    Valores que tendra el checkpoint si este registro se
      *    confirma. Los contadores del programa (WS-) recien se
      *    actualizan despues del COMMIT, asi un reintento por -911
      *    no cuenta dos veces.
       6100-PREPARAR-CHECKPOINT.
           MOVE WS-LEIDOS          TO HV-ULT
           MOVE WS-OK              TO HV-APL
           MOVE WS-RECH            TO HV-REC
           MOVE WS-TOT-MONTO-LEIDO TO HV-ML
           MOVE WS-TOT-MONTO-OK    TO HV-MO
           MOVE WS-TOT-MONTO-RECH  TO HV-MR
           IF ES-OK
              ADD 1 TO HV-APL
              ADD HV-MONTO TO HV-MO
           ELSE
              ADD 1 TO HV-REC
              IF ENT-MONTO IS NUMERIC
                 ADD ENT-MONTO-N TO HV-MR
              END-IF
           END-IF.

      *    Si no se puede grabar el checkpoint no se puede garantizar
      *    el reinicio: se corta. La proxima corrida retoma desde el
      *    ultimo checkpoint confirmado.
       6900-ERROR-FATAL-SQL.
           MOVE SQLCODE TO WS-SQLCODE-ED
           DISPLAY "ERROR SQL EN CONTROL DE LOTE. SQLCODE="
                   WS-SQLCODE-ED
           DISPLAY SQLERRMC
           EXEC SQL ROLLBACK END-EXEC
           PERFORM 9900-ABORTO-FATAL.

      *----------------------------------------------------------------
      * Interpreta el SQLCODE de la ultima sentencia SQL.
      *   0     correcto
      *   >0    aviso: la sentencia se ejecuto (el 100 de FETCH se
      *         trata aparte, antes de llamar aca)
      *   -911  timeout (motivo 68) o deadlock (motivo 2): Db2 ya
      *         deshizo la transaccion; se reintenta desde el inicio.
      *         (En z/OS el timeout puede venir como -913, que NO
      *         deshace sola: ahi hace falta un ROLLBACK explicito.)
      *   otro  error: se guarda SQLCODE y SQLERRMC, se hace ROLLBACK
      *         y se rechaza el registro (codigo 09)
      * Se guarda el SQLCODE antes del ROLLBACK porque este lo pisa.
      *----------------------------------------------------------------
       8000-EVALUAR-SQLCODE.
           MOVE SQLCODE  TO WS-SQLCODE-ULT
           MOVE SQLERRMC TO WS-SQLERRMC-ULT
           EVALUATE TRUE
              WHEN WS-SQLCODE-ULT = 0
                 SET ES-OK TO TRUE
              WHEN WS-SQLCODE-ULT > 0
                 SET ES-OK TO TRUE
              WHEN WS-SQLCODE-ULT = -911
                 IF WS-INTENTO < WS-MAX-INTENTOS
                    DISPLAY "REG " WS-LEIDOS " -911: REINTENTO "
                            WS-INTENTO " DE " WS-MAX-INTENTOS
      *             En produccion conviene una pausa corta antes de
      *             reintentar, para dar tiempo a que se libere la fila.
                    SET ES-REINTENTAR TO TRUE
                 ELSE
                    MOVE 07 TO WS-COD-RECHAZO
                    SET ES-RECHAZO TO TRUE
                 END-IF
              WHEN OTHER
                 MOVE 09 TO WS-COD-RECHAZO
                 EXEC SQL ROLLBACK END-EXEC
                 SET ES-RECHAZO TO TRUE
           END-EVALUATE.

      *----------------------------------------------------------------
      * Rechazo de negocio (cliente inexistente, no activo, saldo
      * excedido, ya aplicado): el ROLLBACK cierra el cursor y suelta
      * el bloqueo de la fila reservada. No deshace nada anterior: lo
      * confirmado en otras transacciones no se toca.
      *----------------------------------------------------------------
       8100-RECHAZAR.
           EXEC SQL ROLLBACK END-EXEC
           SET ES-RECHAZO TO TRUE.

      *----------------------------------------------------------------
      * Cierre: totales de control en los dos listados y en consola.
      * Si el archivo se proceso completo y los totales cuadran, el
      * lote queda marcado como finalizado (estado F).
      *----------------------------------------------------------------
       9000-FIN.
           PERFORM 9100-ESCRIBIR-TOTALES
           IF NOT ABORTAR AND CONTROL-OK
              PERFORM 9300-CERRAR-LOTE
           END-IF
           CLOSE ARCH-ENT RPT-OK RPT-ERR
           EXEC SQL CONNECT RESET END-EXEC
           PERFORM 9200-RESUMEN-CONSOLA
           EVALUATE TRUE
              WHEN ABORTAR OR NOT CONTROL-OK OR NOT CIERRE-OK
                 MOVE 12 TO RETURN-CODE
              WHEN WS-RECH > 0
                 MOVE 4 TO RETURN-CODE
              WHEN OTHER
                 MOVE 0 TO RETURN-CODE
           END-EVALUATE.

       9100-ESCRIBIR-TOTALES.
      *    Control: lo leido debe ser igual a lo aplicado mas lo
      *    rechazado, tanto en cantidad como en monto. En un reinicio
      *    los contadores incluyen lo hecho antes del corte.
           IF WS-LEIDOS = WS-OK + WS-RECH
              AND WS-TOT-MONTO-LEIDO =
                  WS-TOT-MONTO-OK + WS-TOT-MONTO-RECH
              SET CONTROL-OK TO TRUE
           ELSE
              MOVE "N" TO WS-CONTROL
           END-IF

           MOVE SPACES TO LIN-OK
           WRITE LIN-OK
           MOVE "REGISTROS LEIDOS (*)" TO TL-TEXTO
           MOVE WS-LEIDOS          TO TL-CANT
           MOVE WS-TOT-MONTO-LEIDO TO TL-MONTO
           WRITE LIN-OK FROM WS-TOT-LIN
           MOVE "DEPOSITOS APLICADOS" TO TL-TEXTO
           MOVE WS-OK              TO TL-CANT
           MOVE WS-TOT-MONTO-OK    TO TL-MONTO
           WRITE LIN-OK FROM WS-TOT-LIN
           MOVE "(*) EL MONTO SUMA SOLO IMPORTES NUMERICOS" TO LIN-OK
           WRITE LIN-OK
           PERFORM 9110-PIE-OK

           MOVE SPACES TO LIN-ERR
           WRITE LIN-ERR
           MOVE "REGISTROS LEIDOS (*)" TO TL-TEXTO
           MOVE WS-LEIDOS          TO TL-CANT
           MOVE WS-TOT-MONTO-LEIDO TO TL-MONTO
           WRITE LIN-ERR FROM WS-TOT-LIN
           MOVE "DEPOSITOS RECHAZADOS" TO TL-TEXTO
           MOVE WS-RECH            TO TL-CANT
           MOVE WS-TOT-MONTO-RECH  TO TL-MONTO
           WRITE LIN-ERR FROM WS-TOT-LIN
           MOVE "(*) EL MONTO SUMA SOLO IMPORTES NUMERICOS" TO LIN-ERR
           WRITE LIN-ERR
           PERFORM 9120-PIE-ERR.

      *    Resultado del control y aviso de aborto, en cada listado.
       9110-PIE-OK.
           IF CONTROL-OK
              MOVE "CONTROL: CUADRA" TO LIN-OK
           ELSE
              MOVE "CONTROL: DESCUADRE" TO LIN-OK
           END-IF
           WRITE LIN-OK
           IF ABORTAR
              MOVE "*** PROCESO ABORTADO: ARCHIVO SIN TERMINAR ***"
                   TO LIN-OK
              WRITE LIN-OK
           END-IF.

       9120-PIE-ERR.
           IF CONTROL-OK
              MOVE "CONTROL: CUADRA" TO LIN-ERR
           ELSE
              MOVE "CONTROL: DESCUADRE" TO LIN-ERR
           END-IF
           WRITE LIN-ERR
           IF ABORTAR
              MOVE "*** PROCESO ABORTADO: ARCHIVO SIN TERMINAR ***"
                   TO LIN-ERR
              WRITE LIN-ERR
           END-IF.

       9200-RESUMEN-CONSOLA.
           DISPLAY "DEPOSITO-DB2-BATCH - RESUMEN"
           DISPLAY "  LOTE       : " WS-LOTE-ID
           IF ES-REINICIO
              DISPLAY "  MODO       : REINICIO"
           END-IF
           MOVE WS-LEIDOS TO WS-CANT-ED
           DISPLAY "  LEIDOS     : " WS-CANT-ED
           MOVE WS-OK TO WS-CANT-ED
           MOVE WS-TOT-MONTO-OK TO WS-MONTO-ED
           DISPLAY "  APLICADOS  : " WS-CANT-ED "  " WS-MONTO-ED
           MOVE WS-RECH TO WS-CANT-ED
           MOVE WS-TOT-MONTO-RECH TO WS-MONTO-ED
           DISPLAY "  RECHAZADOS : " WS-CANT-ED "  " WS-MONTO-ED
           IF CONTROL-OK
              DISPLAY "  CONTROL    : CUADRA"
           ELSE
              DISPLAY "  CONTROL    : DESCUADRE"
           END-IF
           IF ABORTAR
              DISPLAY "  PROCESO ABORTADO (EL LOTE QUEDA EN PROCESO)"
           END-IF.

      *    Marca el lote como finalizado: un nuevo intento con el
      *    mismo ID ya no lo reprocesa.
       9300-CERRAR-LOTE.
           EXEC SQL UPDATE CONTROL_PROCESO
                       SET ESTADO = 'F',
                           FECHA_ULT_ACT = CURRENT TIMESTAMP
                     WHERE PROCESO = :HV-PROCESO
                       AND LOTE_ID = :HV-LOTE
           END-EXEC
           IF SQLCODE = 0
              EXEC SQL COMMIT END-EXEC
           END-IF
           IF SQLCODE NOT = 0
              MOVE SQLCODE TO WS-SQLCODE-ED
              DISPLAY "NO SE PUDO CERRAR EL LOTE. SQLCODE="
                      WS-SQLCODE-ED
              EXEC SQL ROLLBACK END-EXEC
              MOVE "N" TO WS-CIERRE
           END-IF.

      *    Error grave de archivos o de control: se corta con codigo
      *    12. El lote queda en estado P (se puede reiniciar).
       9900-ABORTO-FATAL.
           EXEC SQL CONNECT RESET END-EXEC
           MOVE 12 TO RETURN-CODE
           STOP RUN.
