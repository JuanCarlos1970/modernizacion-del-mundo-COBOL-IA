       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEPOSITO-DB2.
      *================================================================
      * DISENO DE REFERENCIA - NO COMPILADO NI EJECUTADO.
      *
      * Deposito sobre la tabla CLIENTES de Db2 (base TESTDB) usando
      * SQL embebido. Muestra el patron completo de una actualizacion
      * segura frente a la concurrencia:
      *   1. Reservar la fila con un cursor FOR UPDATE (bloqueo U).
      *   2. Leer el saldo, sumarle el deposito.
      *   3. UPDATE ... WHERE CURRENT OF (el bloqueo pasa a X).
      *   4. COMMIT: confirma y libera el bloqueo.
      *   5. Si Db2 devuelve SQLCODE -911 (timeout o deadlock), la
      *      transaccion ya fue deshecha: se reintenta TODO desde el
      *      principio, hasta un maximo de intentos.
      *
      * Equivale a lo practicado a mano con el CLP de Db2:
      *   - prueba 2: UPDATE sin commit y timeout (-911, motivo 68)
      *   - prueba 3: SELECT ... FOR UPDATE
      *   - prueba 4: deadlock (-911, motivo 2)
      *
      * Requiere precompilar (EXEC SQL -> CALL) y enlazar el modulo
      * de acceso a la base. No corre con GnuCOBOL solo.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.

      *--- Area de comunicacion de SQL (SQLCODE, SQLERRMC, etc.)
           EXEC SQL INCLUDE SQLCA END-EXEC.

      *--- Variables huesped: las que intercambian datos con Db2.
      *    INTEGER -> S9(9) COMP-5 (en z/OS: COMP)
      *    DECIMAL(11,2) -> S9(9)V99 COMP-3
      *    VARCHAR(30) -> grupo con largo (49) y texto (49)
           EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-DNI                 PIC S9(9)     COMP-5.
       01  HV-MONTO               PIC S9(9)V99  COMP-3.
       01  HV-SALDO               PIC S9(9)V99  COMP-3.
       01  HV-NOMBRE.
           49 HV-NOMBRE-LEN       PIC S9(4)     COMP-5.
           49 HV-NOMBRE-TEXT      PIC X(30).
           EXEC SQL END DECLARE SECTION END-EXEC.

      *--- Cursor para leer y modificar la fila del cliente.
           EXEC SQL DECLARE C-CLI CURSOR FOR
               SELECT NOMBRE, SALDO
                 FROM CLIENTES
                WHERE DNI = :HV-DNI
                  FOR UPDATE OF SALDO
           END-EXEC.

      *--- Variables propias del programa.
       01  WS-DNI-ENT             PIC 9(8).
       01  WS-MONTO-ENT           PIC 9(9)V99.
       01  WS-INTENTO             PIC 9         VALUE 0.
       01  WS-MAX-INTENTOS        PIC 9         VALUE 3.
       01  WS-ESTADO              PIC X         VALUE SPACE.
           88 ES-OK                             VALUE "O".
           88 ES-REINTENTAR                     VALUE "R".
           88 ES-ERROR                          VALUE "E".
       01  WS-SQLCODE-ED          PIC -(9)9.
       01  WS-SALDO-ED            PIC -,---,---,--9.99.

       PROCEDURE DIVISION.

       0000-PRINCIPAL.
           PERFORM 1000-CONECTAR
           PERFORM 2000-PEDIR-DATOS
           MOVE 0 TO WS-INTENTO
      *    Cada vuelta es una transaccion completa. Solo se repite
      *    si Db2 pidio reintentar (-911).
           PERFORM 3000-DEPOSITAR
               UNTIL ES-OK OR ES-ERROR
           PERFORM 9000-DESCONECTAR
           IF ES-OK
              MOVE 0 TO RETURN-CODE
           ELSE
              MOVE 8 TO RETURN-CODE
           END-IF
           STOP RUN.

      *----------------------------------------------------------------
      * Conexion a la base (Db2 LUW). En z/OS no hay CONNECT: el
      * programa se conecta por el entorno (DSN en batch, CICS).
      *----------------------------------------------------------------
       1000-CONECTAR.
           EXEC SQL CONNECT TO TESTDB END-EXEC
           IF SQLCODE NOT = 0
              MOVE SQLCODE TO WS-SQLCODE-ED
              DISPLAY "NO SE PUDO CONECTAR A TESTDB. SQLCODE="
                      WS-SQLCODE-ED
              MOVE 12 TO RETURN-CODE
              STOP RUN
           END-IF.

       2000-PEDIR-DATOS.
           DISPLAY "DNI DEL CLIENTE (8 DIGITOS): " WITH NO ADVANCING
           ACCEPT WS-DNI-ENT
           DISPLAY "MONTO A DEPOSITAR: " WITH NO ADVANCING
           ACCEPT WS-MONTO-ENT
           IF WS-MONTO-ENT = 0
              DISPLAY "EL MONTO DEBE SER MAYOR A CERO"
              MOVE 8 TO RETURN-CODE
              STOP RUN
           END-IF
           MOVE WS-DNI-ENT   TO HV-DNI
           MOVE WS-MONTO-ENT TO HV-MONTO.

      *----------------------------------------------------------------
      * Una transaccion: abrir cursor (reserva la fila), leer, sumar,
      * actualizar, cerrar y confirmar. Despues de cada sentencia SQL
      * se evalua el SQLCODE; si algo falla se corta el resto.
      *----------------------------------------------------------------
       3000-DEPOSITAR.
           ADD 1 TO WS-INTENTO
           MOVE SPACE TO WS-ESTADO

           EXEC SQL OPEN C-CLI END-EXEC
           PERFORM 8000-EVALUAR-SQLCODE

           IF ES-OK
              EXEC SQL FETCH C-CLI
                   INTO :HV-NOMBRE, :HV-SALDO
              END-EXEC
              IF SQLCODE = 100
                 DISPLAY "CLIENTE INEXISTENTE: " WS-DNI-ENT
                 SET ES-ERROR TO TRUE
                 EXEC SQL CLOSE C-CLI END-EXEC
              ELSE
                 PERFORM 8000-EVALUAR-SQLCODE
              END-IF
           END-IF

           IF ES-OK
              ADD HV-MONTO TO HV-SALDO
                  ON SIZE ERROR
                     DISPLAY "EL SALDO RESULTANTE EXCEDE EL MAXIMO"
                     SET ES-ERROR TO TRUE
                     EXEC SQL CLOSE C-CLI END-EXEC
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
              EXEC SQL COMMIT END-EXEC
              PERFORM 8000-EVALUAR-SQLCODE
           END-IF

           IF ES-OK
              MOVE HV-SALDO TO WS-SALDO-ED
              DISPLAY "DEPOSITO OK. CLIENTE " WS-DNI-ENT
              DISPLAY "NUEVO SALDO: " WS-SALDO-ED
           END-IF.

      *----------------------------------------------------------------
      * Interpreta el SQLCODE de la ultima sentencia SQL.
      *   0     correcto
      *   -911  timeout (motivo 68) o deadlock (motivo 2): Db2 ya
      *         deshizo la transaccion; se reintenta desde el inicio
      *   otro  error: se muestra, se hace ROLLBACK y se termina
      *----------------------------------------------------------------
       8000-EVALUAR-SQLCODE.
           EVALUATE SQLCODE
              WHEN 0
                 SET ES-OK TO TRUE
              WHEN -911
                 IF WS-INTENTO < WS-MAX-INTENTOS
                    DISPLAY "-911: REINTENTO " WS-INTENTO
                            " DE " WS-MAX-INTENTOS
      *             En produccion conviene una pausa corta antes de
      *             reintentar, para dar tiempo a que se libere la fila.
                    SET ES-REINTENTAR TO TRUE
                 ELSE
                    DISPLAY "-911: SE AGOTARON LOS REINTENTOS"
                    SET ES-ERROR TO TRUE
                 END-IF
              WHEN OTHER
                 MOVE SQLCODE TO WS-SQLCODE-ED
                 DISPLAY "ERROR SQL. SQLCODE=" WS-SQLCODE-ED
                 DISPLAY SQLERRMC
                 EXEC SQL ROLLBACK END-EXEC
                 SET ES-ERROR TO TRUE
           END-EVALUATE.

       9000-DESCONECTAR.
           EXEC SQL CONNECT RESET END-EXEC.
