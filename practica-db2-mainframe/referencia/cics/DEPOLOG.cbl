       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEPOLOG.
      *================================================================
      * DISENO DE REFERENCIA - NO COMPILADO NI EJECUTADO EN CICS.
      *
      * PROGRAMA DE LOGICA DE LA TRANSACCION DEPO. NO TIENE PANTALLA.
      * Lo llama DEPOPAN con EXEC CICS LINK y recibe DNI y monto por
      * COMMAREA. Es el programa DEPOSITO-DB2 adaptado a CICS: mismo
      * patron de actualizacion segura (cursor FOR UPDATE, UPDATE
      * WHERE CURRENT OF, reintento ante -911), con estas diferencias:
      *   - NO hay CONNECT: CICS ya esta conectado a Db2 (DB2CONN).
      *   - NO hay EXEC SQL COMMIT: dentro de CICS se confirma con
      *     EXEC CICS SYNCPOINT, que confirma Db2 y el resto de los
      *     recursos de CICS juntos.
      *   - NO hay ACCEPT ni DISPLAY: los datos entran y salen por
      *     la COMMAREA y la pantalla es de DEPOPAN.
      *   - Revisa que el cliente este activo (como el batch).
      *   - Devuelve un codigo de resultado (DC-RESULTADO) en lugar
      *     de RETURN-CODE.
      *   - Termina con EXEC CICS RETURN (vuelve a DEPOPAN) y no con
      *     STOP RUN.
      * Los codigos de resultado son los mismos del batch
      * DEPOSITO-DB2-BATCH (ver DEPOCOM.cpy).
      *================================================================
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-DNI                 PIC S9(9)     COMP-5.
       01  HV-MONTO               PIC S9(9)V99  COMP-3.
       01  HV-SALDO               PIC S9(9)V99  COMP-3.
       01  HV-ESTADO              PIC X(1).
       01  HV-NOMBRE.
           49 HV-NOMBRE-LEN       PIC S9(4)     COMP-5.
           49 HV-NOMBRE-TEXT      PIC X(30).
           EXEC SQL END DECLARE SECTION END-EXEC.

           EXEC SQL DECLARE C-CLI CURSOR FOR
               SELECT NOMBRE, SALDO, ESTADO
                 FROM CLIENTES
                WHERE DNI = :HV-DNI
                  FOR UPDATE OF SALDO
           END-EXEC.

       01  WS-RESP                PIC S9(8)     COMP.
       01  WS-INTENTO             PIC 9         VALUE 0.
       01  WS-MAX-INTENTOS        PIC 9         VALUE 2.
       01  WS-ESTADO              PIC X         VALUE SPACE.
           88 ES-OK                             VALUE 'O'.
           88 ES-REINTENTAR                     VALUE 'R'.
           88 ES-ERROR                          VALUE 'E'.

       LINKAGE SECTION.
      *--- La COMMAREA que manda DEPOPAN (DFHCOMMAREA es el nombre que
      *    CICS espera para el area de comunicacion).
           COPY DEPOCOM REPLACING ==DEPO-COMMAREA== BY ==DFHCOMMAREA==.

       PROCEDURE DIVISION.

       0000-PRINCIPAL.
      *    Sin COMMAREA no hay datos: es un error de programacion de
      *    quien llamo, no del usuario. Se termina con abend 'DEPA'.
           IF EIBCALEN = 0
              EXEC CICS ABEND ABCODE('DEPA') END-EXEC
           END-IF
           MOVE 0      TO DC-RESULTADO
           MOVE SPACES TO DC-NOMBRE
           MOVE 0      TO DC-SALDO
           MOVE 0      TO DC-SQLCODE
           EVALUATE TRUE
              WHEN DC-DNI NOT NUMERIC OR DC-DNI = 0
                 MOVE 1 TO DC-RESULTADO
              WHEN DC-MONTO NOT NUMERIC OR DC-MONTO NOT > 0
                 MOVE 3 TO DC-RESULTADO
              WHEN OTHER
                 MOVE DC-DNI   TO HV-DNI
                 MOVE DC-MONTO TO HV-MONTO
                 MOVE 0 TO WS-INTENTO
      *          Cada vuelta es una transaccion completa. Solo se
      *          repite si Db2 pidio reintentar (-911 o -913).
                 PERFORM 3000-DEPOSITAR
                     UNTIL ES-OK OR ES-ERROR
           END-EVALUATE
           EXEC CICS RETURN END-EXEC.

      *----------------------------------------------------------------
      * Una transaccion: abrir cursor (reserva la fila), leer, validar,
      * sumar, actualizar, cerrar y confirmar con SYNCPOINT.
      *----------------------------------------------------------------
       3000-DEPOSITAR.
           ADD 1 TO WS-INTENTO
           MOVE SPACE TO WS-ESTADO

           EXEC SQL OPEN C-CLI END-EXEC
           PERFORM 8000-EVALUAR-SQLCODE

           IF ES-OK
              EXEC SQL FETCH C-CLI
                   INTO :HV-NOMBRE, :HV-SALDO, :HV-ESTADO
              END-EXEC
              IF SQLCODE = 100
                 MOVE 4 TO DC-RESULTADO
                 SET ES-ERROR TO TRUE
                 PERFORM 7000-DESHACER
              ELSE
                 PERFORM 8000-EVALUAR-SQLCODE
              END-IF
           END-IF

           IF ES-OK
              IF HV-NOMBRE-LEN > 0
                 MOVE HV-NOMBRE-TEXT(1:HV-NOMBRE-LEN) TO DC-NOMBRE
              END-IF
              IF HV-ESTADO NOT = 'A'
                 MOVE 5 TO DC-RESULTADO
                 SET ES-ERROR TO TRUE
                 PERFORM 7000-DESHACER
              END-IF
           END-IF

           IF ES-OK
              ADD HV-MONTO TO HV-SALDO
                  ON SIZE ERROR
                     MOVE 6 TO DC-RESULTADO
                     SET ES-ERROR TO TRUE
                     PERFORM 7000-DESHACER
              END-ADD
           END-IF

           IF ES-OK
              EXEC SQL UPDATE CLIENTES
                          SET SALDO = :HV-SALDO
                        WHERE CURRENT OF C-CLI
              END-EXEC
              PERFORM 8000-EVALUAR-SQLCODE
           END-IF

           IF ES-OK
              EXEC SQL CLOSE C-CLI END-EXEC
              EXEC CICS SYNCPOINT RESP(WS-RESP) END-EXEC
              IF WS-RESP = DFHRESP(NORMAL)
                 MOVE HV-SALDO TO DC-SALDO
                 MOVE 0 TO DC-RESULTADO
              ELSE
                 MOVE 9 TO DC-RESULTADO
                 SET ES-ERROR TO TRUE
              END-IF
           END-IF.

      *----------------------------------------------------------------
      * Deshace la transaccion y libera los bloqueos. Se usa cuando el
      * deposito no se puede aplicar. EXEC CICS SYNCPOINT ROLLBACK
      * deshace los cambios de Db2 y de CICS de esta tarea.
      *----------------------------------------------------------------
       7000-DESHACER.
           EXEC SQL CLOSE C-CLI END-EXEC
           EXEC CICS SYNCPOINT ROLLBACK END-EXEC.

      *----------------------------------------------------------------
      * Interpreta el SQLCODE de la ultima sentencia SQL.
      *   0          correcto
      *   -911/-913  timeout o deadlock: se deshace y se reintenta,
      *              hasta WS-MAX-INTENTOS. En una pantalla se
      *              reintenta poco, para no hacer esperar al usuario.
      *   otro       error: se guarda el SQLCODE y se termina
      *----------------------------------------------------------------
       8000-EVALUAR-SQLCODE.
           EVALUATE SQLCODE
              WHEN 0
                 SET ES-OK TO TRUE
              WHEN -911
              WHEN -913
                 EXEC CICS SYNCPOINT ROLLBACK END-EXEC
                 IF WS-INTENTO < WS-MAX-INTENTOS
                    SET ES-REINTENTAR TO TRUE
                 ELSE
                    MOVE 7 TO DC-RESULTADO
                    MOVE SQLCODE TO DC-SQLCODE
                    SET ES-ERROR TO TRUE
                 END-IF
              WHEN OTHER
                 MOVE 9 TO DC-RESULTADO
                 MOVE SQLCODE TO DC-SQLCODE
                 EXEC CICS SYNCPOINT ROLLBACK END-EXEC
                 SET ES-ERROR TO TRUE
           END-EVALUATE.
