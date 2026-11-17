       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEPOPAN.
      *================================================================
      * DISENO DE REFERENCIA - NO COMPILADO NI EJECUTADO EN CICS.
      *
      * TRANSACCION DEPO - PROGRAMA DE PANTALLA (PSEUDOCONVERSACIONAL).
      * Muestra el mapa DEPOMAP, valida lo que el usuario escribio y,
      * si esta bien, llama con EXEC CICS LINK al programa de logica
      * DEPOLOG pasandole DNI y monto por COMMAREA. Con la respuesta
      * arma el mensaje y vuelve a mostrar la pantalla.
      * NO ACCEDE A Db2: eso es trabajo de DEPOLOG.
      *
      * PSEUDOCONVERSACIONAL: despues de cada pantalla el programa
      * TERMINA (EXEC CICS RETURN TRANSID('DEPO')) y no queda esperando
      * al usuario con recursos tomados. Cuando el usuario aprieta
      * una tecla, CICS vuelve a arrancar la transaccion DEPO y este
      * programa se ejecuta de nuevo desde el principio.
      * Como sabe en que vuelta esta: por EIBCALEN (largo de la
      * COMMAREA que recibio). 0 = primera vez; 1 = vuelta siguiente.
      *
      * TECLAS: ENTER = depositar; PF3 o CLEAR = salir.
      *================================================================
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.

      *--- Constantes de teclas (DFHENTER, DFHPF3, DFHCLEAR...).
           COPY DFHAID.
      *--- Mapa simbolico generado por BMS (DEPOMAPI / DEPOMAPO).
           COPY DEPOMAP.
      *--- COMMAREA para llamar a DEPOLOG.
           COPY DEPOCOM.

       01  WS-RESP               PIC S9(8) COMP.
       01  WS-ESTADO             PIC X       VALUE 'P'.
       01  WS-MSG                PIC X(76)   VALUE SPACES.
       01  WS-VALIDO             PIC X       VALUE 'N'.
           88 ES-VALIDO                      VALUE 'S'.
       01  WS-MONTO-TXT          PIC X(12).
       01  WS-MONTO-NUM          PIC S9(9)V99 COMP-3.
       01  WS-SALDO-ED           PIC -,---,---,--9.99.
       01  WS-FIN                PIC X(30)
                                 VALUE 'FIN DE LA TRANSACCION DEPO.'.

       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X.

       PROCEDURE DIVISION.

       0000-PRINCIPAL.
           EVALUATE TRUE
              WHEN EIBCALEN = 0
                 PERFORM 1000-PANTALLA-INICIAL
              WHEN EIBAID = DFHPF3 OR EIBAID = DFHCLEAR
                 PERFORM 9000-SALIR
              WHEN EIBAID = DFHENTER
                 PERFORM 2000-PROCESAR
              WHEN OTHER
                 MOVE LOW-VALUES TO DEPOMAPO
                 MOVE -1 TO DNIL
                 MOVE 'TECLA NO VALIDA. USE ENTER O PF3.' TO WS-MSG
                 PERFORM 3000-ENVIAR-DATOS
           END-EVALUATE
           PERFORM 8000-VOLVER.

      *----------------------------------------------------------------
      * Primera vez: mapa vacio con el cursor en el campo DNI.
      *----------------------------------------------------------------
       1000-PANTALLA-INICIAL.
           MOVE LOW-VALUES TO DEPOMAPO
           EXEC CICS SEND MAP('DEPOMAP') MAPSET('DEPOMS')
                     FROM(DEPOMAPO) ERASE CURSOR
                     RESP(WS-RESP)
           END-EXEC.

      *----------------------------------------------------------------
      * El usuario apreto ENTER: recibir, validar, llamar, responder.
      *----------------------------------------------------------------
       2000-PROCESAR.
           EXEC CICS RECEIVE MAP('DEPOMAP') MAPSET('DEPOMS')
                     INTO(DEPOMAPI)
                     RESP(WS-RESP)
           END-EXEC
           EVALUATE WS-RESP
              WHEN DFHRESP(NORMAL)
      *          Los campos de salida (cliente y saldo) se limpian: el
      *          usuario no los escribe y no deben quedar datos viejos.
                 MOVE SPACES TO NOMBREO
                 MOVE SPACES TO SALDOO
                 PERFORM 2100-VALIDAR
                 IF ES-VALIDO
                    PERFORM 2200-LLAMAR-LOGICA
                 END-IF
              WHEN DFHRESP(MAPFAIL)
      *          ENTER sin escribir nada: no llega ningun dato.
                 MOVE LOW-VALUES TO DEPOMAPO
                 MOVE 'INGRESE DNI Y MONTO.' TO WS-MSG
                 MOVE -1 TO DNIL
              WHEN OTHER
                 MOVE 'ERROR AL RECIBIR LA PANTALLA.' TO WS-MSG
           END-EVALUATE
           PERFORM 3000-ENVIAR-DATOS.

      *----------------------------------------------------------------
      * Validaciones de pantalla (formato). Las de negocio las hace
      * DEPOLOG. Si algo esta mal se deja el cursor en ese campo
      * poniendo -1 en su largo (xxxL).
      *----------------------------------------------------------------
       2100-VALIDAR.
           MOVE 'N' TO WS-VALIDO
           EVALUATE TRUE
              WHEN DNIL < 8 OR DNII NOT NUMERIC
                 MOVE 'EL DNI DEBE TENER 8 DIGITOS.' TO WS-MSG
                 MOVE -1 TO DNIL
              WHEN MONTOL = 0
                 MOVE 'INGRESE EL MONTO A DEPOSITAR.' TO WS-MSG
                 MOVE -1 TO MONTOL
              WHEN OTHER
                 MOVE SPACES TO WS-MONTO-TXT
                 MOVE MONTOI(1:MONTOL) TO WS-MONTO-TXT
      *          TEST-NUMVAL da 0 si el texto es un numero valido.
                 IF FUNCTION TEST-NUMVAL(WS-MONTO-TXT) NOT = 0
                    MOVE 'EL MONTO NO ES UN NUMERO VALIDO.' TO WS-MSG
                    MOVE -1 TO MONTOL
                 ELSE
                    COMPUTE WS-MONTO-NUM =
                            FUNCTION NUMVAL(WS-MONTO-TXT)
                       ON SIZE ERROR
                          MOVE 'EL MONTO ES DEMASIADO GRANDE.'
                               TO WS-MSG
                          MOVE -1 TO MONTOL
                       NOT ON SIZE ERROR
                          IF WS-MONTO-NUM > 0
                             MOVE 'S' TO WS-VALIDO
                          ELSE
                             MOVE 'EL MONTO DEBE SER MAYOR A CERO.'
                                  TO WS-MSG
                             MOVE -1 TO MONTOL
                          END-IF
                    END-COMPUTE
                 END-IF
           END-EVALUATE.

      *----------------------------------------------------------------
      * EXEC CICS LINK: llama a DEPOLOG como una subrutina de CICS.
      * La COMMAREA viaja por referencia: lo que DEPOLOG escribe en la
      * salida lo vemos aca al volver.
      *----------------------------------------------------------------
       2200-LLAMAR-LOGICA.
           INITIALIZE DEPO-COMMAREA
           MOVE DNII          TO DC-DNI
           MOVE WS-MONTO-NUM  TO DC-MONTO
           EXEC CICS LINK PROGRAM('DEPOLOG')
                     COMMAREA(DEPO-COMMAREA)
                     LENGTH(LENGTH OF DEPO-COMMAREA)
                     RESP(WS-RESP)
           END-EXEC
           IF WS-RESP NOT = DFHRESP(NORMAL)
              MOVE 'NO SE PUDO EJECUTAR EL DEPOSITO (LINK).'
                   TO WS-MSG
           ELSE
              PERFORM 2300-ARMAR-RESPUESTA
           END-IF.

       2300-ARMAR-RESPUESTA.
           MOVE DC-NOMBRE TO NOMBREO
           EVALUATE DC-RESULTADO
              WHEN 0
                 MOVE DC-SALDO TO WS-SALDO-ED
                 MOVE WS-SALDO-ED TO SALDOO
                 MOVE 'DEPOSITO APLICADO CORRECTAMENTE.' TO WS-MSG
      *          Se limpian DNI y monto para que otro ENTER no
      *          repita el deposito por error.
                 MOVE SPACES TO DNIO
                 MOVE SPACES TO MONTOO
                 MOVE -1 TO DNIL
              WHEN 1
                 MOVE 'DNI INVALIDO.' TO WS-MSG
                 MOVE -1 TO DNIL
              WHEN 3
                 MOVE 'EL MONTO DEBE SER MAYOR A CERO.' TO WS-MSG
                 MOVE -1 TO MONTOL
              WHEN 4
                 MOVE 'CLIENTE INEXISTENTE.' TO WS-MSG
                 MOVE -1 TO DNIL
              WHEN 5
                 MOVE 'EL CLIENTE NO ESTA ACTIVO.' TO WS-MSG
                 MOVE -1 TO DNIL
              WHEN 6
                 MOVE 'EL SALDO RESULTANTE EXCEDE EL MAXIMO.'
                      TO WS-MSG
                 MOVE -1 TO MONTOL
              WHEN 7
                 MOVE 'REGISTRO EN USO. INTENTE NUEVAMENTE.' TO WS-MSG
              WHEN OTHER
                 MOVE 'ERROR INESPERADO. AVISE A SISTEMAS.' TO WS-MSG
           END-EVALUATE.

      *----------------------------------------------------------------
      * Envia solo los datos (DATAONLY): el texto fijo de la pantalla
      * ya esta en la terminal y no hace falta mandarlo de nuevo.
      *----------------------------------------------------------------
       3000-ENVIAR-DATOS.
           MOVE WS-MSG TO MSGO
           EXEC CICS SEND MAP('DEPOMAP') MAPSET('DEPOMS')
                     FROM(DEPOMAPO) DATAONLY CURSOR
                     RESP(WS-RESP)
           END-EXEC.

      *----------------------------------------------------------------
      * Fin de la vuelta: la transaccion TERMINA y CICS la vuelve a
      * arrancar con el proximo ENTER. WS-ESTADO viaja como COMMAREA
      * de 1 byte solo para que EIBCALEN valga 1 en la proxima vuelta.
      *----------------------------------------------------------------
       8000-VOLVER.
           EXEC CICS RETURN TRANSID('DEPO')
                     COMMAREA(WS-ESTADO)
                     LENGTH(1)
           END-EXEC.

       9000-SALIR.
           EXEC CICS SEND TEXT FROM(WS-FIN) LENGTH(30)
                     ERASE FREEKB
           END-EXEC
           EXEC CICS RETURN
           END-EXEC.
