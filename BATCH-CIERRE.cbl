      ******************************************************************
      * PROGRAMA    : BATCH-CIERRE
      * DESCRIPCION : Proceso batch de cierre de la cartera de
      *               clientes. Recorre TODO clientes_v3.dat (el
      *               mismo archivo indexado que usa CUENTA) y, para
      *               cada cliente Activo (A) o Reactivado (R),
      *               acredita un interes simple mensual sobre su
      *               saldo. Los clientes Inactivos (I) se excluyen
      *               del calculo, pero se cuentan en el resumen.
      *               Al terminar, genera reporte_cierre.txt con el
      *               detalle y los totales del cierre.
      * AUTOR       : EJEMPLO
      * FECHA       : 2026-09-22
      * USO         : Pensado para correrse fuera del horario de
      *               atencion (cierre nocturno), NUNCA al mismo
      *               tiempo que CUENTA sobre el mismo archivo (ver
      *               README.md, seccion "Proceso Batch de Cierre").
      * EJECUCION   : correr_batch_cierre.bat (compila y ejecuta).
      *               batch_cierre.jcl documenta el equivalente en
      *               un mainframe z/OS real.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-CIERRE.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. PC.
       OBJECT-COMPUTER. PC.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
      * Mismo archivo fisico que usa CUENTA. Acceso SEQUENTIAL: el
      * cierre recorre todos los registros en orden de clave (DNI),
      * no busca clientes puntuales.
           SELECT ARCH-CLIENTES ASSIGN TO "clientes_v3.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS SEQUENTIAL
               RECORD KEY IS CLI-DNI
               FILE STATUS IS WS-FS-CLI.

           SELECT ARCH-REPORTE ASSIGN TO "reporte_cierre.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-REP.

       DATA DIVISION.
       FILE SECTION.
       FD  ARCH-CLIENTES.
      * Mismo layout que usa CUENTA (ver CLIENTE.cpy). Ambos
      * programas se recompilan siempre juntos si el layout cambia.
           COPY CLIENTE.

       FD  ARCH-REPORTE.
       01  REG-REPORTE             PIC X(100).

       WORKING-STORAGE SECTION.

      * Estado de las operaciones de E/S de cada archivo
       01  WS-FS-CLI               PIC XX     VALUE "00".
           88  FS-CLI-OK                      VALUE "00".
           88  FS-CLI-FIN                     VALUE "10".
           88  FS-CLI-NO-EXISTE                VALUE "35".
       01  WS-FS-REP               PIC XX     VALUE "00".
           88  FS-REP-OK                      VALUE "00".
      * Operacion de archivo en curso, solo para informar errores.
       01  WS-OPERACION            PIC X(10)  VALUE SPACES.

      * El archivo de clientes puede no existir todavia (cartera
      * vacia): en ese caso el cierre no falla, simplemente no
      * procesa a nadie y el reporte queda en cero.
       01  WS-CLIENTES-ABIERTOS    PIC X      VALUE "N".
           88  CLIENTES-ABIERTOS               VALUE "S".

       01  WS-FIN-CLIENTES         PIC X      VALUE "N".
           88  FIN-DE-CLIENTES                 VALUE "S".

      * Indica si ya se escribio el encabezado de la tabla de
      * detalle en el reporte (se escribe una sola vez, antes del
      * primer cliente procesado).
       01  WS-PRIMER-DETALLE       PIC X      VALUE "S".
           88  PRIMER-DETALLE                  VALUE "S".

      * Resultado de intentar acreditar el interes de un cliente.
      * NOTA IMPORTANTE: no cambiar 1200-ACREDITAR-INTERES para que
      * vuelva a poner un ADD (u otra sentencia aritmetica) dentro de
      * la rama ON SIZE ERROR de otro ADD con NOT ON SIZE ERROR. Se
      * probo asi al principio y GnuCOBOL 2.0 genera codigo C
      * incorrecto en ese caso: anida la rama NOT ON SIZE ERROR (y
      * todo lo que sigue en el parrafo) dentro del "if" de la rama
      * ON SIZE ERROR, asi que se salta en silencio incluso cuando
      * NO hubo error. Por eso aqui se usa un indicador propio
      * (WS-INTERES-OK) y un IF aparte despues del END-ADD, en vez
      * de poner logica dentro de ON SIZE ERROR / NOT ON SIZE ERROR.
       01  WS-INTERES-OK            PIC X      VALUE "S".
           88  INTERES-ACREDITADO               VALUE "S".
           88  INTERES-NO-ACREDITADO            VALUE "N".

      ******************************************************************
      * TASA DE INTERES DEL CIERRE
      * Tasa mensual aplicada al saldo de cada cliente Activo o
      * Reactivado. 0,0050 = 0,50% mensual. Para cambiar la tasa de
      * un cierre a otro, modificar este VALUE y recompilar (no hay
      * forma de pasarla por parametro en esta version).
      ******************************************************************
       01  WS-TASA-INTERES         PIC 9V9(4) VALUE 0.0050.

       01  WS-SALDO-ANTERIOR       PIC S9(9)V99.
       01  WS-INTERES-CLIENTE      PIC S9(9)V99.

      * Acumuladores del cierre
       01  WS-CANT-PROCESADOS      PIC 9(7)   VALUE 0.
       01  WS-CANT-INACTIVOS       PIC 9(7)   VALUE 0.
       01  WS-CANT-OMITIDOS        PIC 9(7)   VALUE 0.
       01  WS-TOTAL-INTERESES      PIC S9(11)V99 VALUE 0.
       01  WS-TOTAL-SALDO-CARTERA  PIC S9(11)V99 VALUE 0.

      * Fecha del proceso (DD/MM/AAAA)
       01  WS-FECHA-HORA           PIC X(21).
       01  WS-FECHA-REPORTE        PIC X(10).

      * Campos editados para el reporte y la pantalla
       01  WS-CANT-EDIT             PIC ZZ,ZZZ,ZZ9.
       01  WS-TOTAL-INT-EDIT        PIC Z,ZZZ,ZZZ,ZZ9.99.
       01  WS-TOTAL-SALDO-EDIT      PIC Z,ZZZ,ZZZ,ZZ9.99.

      * Linea de detalle del reporte: un cliente procesado por fila,
      * en columnas de ancho fijo.
       01  WS-LINEA-DETALLE.
           05  WS-LD-DNI            PIC 9(8).
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  WS-LD-NOMBRE         PIC X(30).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  WS-LD-SALDO-ANT      PIC Z,ZZZ,ZZZ,ZZ9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  WS-LD-INTERES        PIC Z,ZZZ,ZZZ,ZZ9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  WS-LD-SALDO-NUE      PIC Z,ZZZ,ZZZ,ZZ9.99.

      * Linea de detalle de un cliente Inactivo: sin interes ni
      * saldo nuevo, solo DNI, Nombre y Saldo.
       01  WS-LINEA-INACTIVO.
           05  WS-LI-DNI            PIC 9(8).
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  WS-LI-NOMBRE         PIC X(30).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  WS-LI-SALDO          PIC Z,ZZZ,ZZZ,ZZ9.99.

       PROCEDURE DIVISION.

      ******************************************************************
      * Programa principal del cierre.
      ******************************************************************
      * Dos pasadas sobre clientes_v3.dat: la primera (1000) actualiza
      * los saldos de Activos/Reactivados y escribe esa tabla; la
      * segunda (1500) vuelve a abrir el archivo SOLO PARA LEER y
      * lista los Inactivos. Se necesitan dos pasadas porque, en un
      * unico recorrido en orden de clave (DNI), un cliente Activo y
      * uno Inactivo pueden aparecer intercalados, y el reporte pide
      * las dos tablas como bloques separados (primero Activos, luego
      * Inactivos), no intercaladas.
       0000-PRINCIPAL.
           DISPLAY " "
           DISPLAY "=== BATCH DE CIERRE - CUENTA BANCARIA ==="
           PERFORM 0100-ABRIR-ARCHIVO-CLIENTES
           PERFORM 0150-ABRIR-ARCHIVO-REPORTE
           PERFORM 0200-ARMAR-FECHA
           PERFORM 0300-ESCRIBIR-ENCABEZADO
           IF CLIENTES-ABIERTOS
               PERFORM 1000-LEER-Y-PROCESAR UNTIL FIN-DE-CLIENTES
               PERFORM 0410-CERRAR-CLIENTES-PASE1
           END-IF
           PERFORM 1450-CERRAR-DETALLE-ACTIVOS
           PERFORM 1500-LISTAR-INACTIVOS
           PERFORM 2000-ESCRIBIR-RESUMEN
           PERFORM 0400-CERRAR-ARCHIVOS
           PERFORM 3000-MOSTRAR-RESUMEN-PANTALLA
           STOP RUN.

      * Si el archivo no existe todavia, el cierre sigue (cartera
      * vacia); cualquier otro error de apertura es fatal.
       0100-ABRIR-ARCHIVO-CLIENTES.
           OPEN I-O ARCH-CLIENTES
           EVALUATE TRUE
               WHEN FS-CLI-OK
                   SET CLIENTES-ABIERTOS TO TRUE
               WHEN FS-CLI-NO-EXISTE
                   DISPLAY "No se encontro clientes_v3.dat: no hay"
                   DISPLAY "clientes para procesar en este cierre."
               WHEN OTHER
                   PERFORM 9000-ERROR-CLIENTES
           END-EVALUATE.

       0150-ABRIR-ARCHIVO-REPORTE.
           OPEN OUTPUT ARCH-REPORTE
           IF NOT FS-REP-OK
               PERFORM 9100-ERROR-REPORTE
           END-IF.

      * FUNCTION CURRENT-DATE devuelve 21 caracteres: AAAAMMDD +
      * hora + huso horario. Se toman solo los primeros 8 (AAAAMMDD)
      * y se arman como DD/MM/AAAA.
       0200-ARMAR-FECHA.
           MOVE FUNCTION CURRENT-DATE TO WS-FECHA-HORA
           STRING WS-FECHA-HORA(7:2) "/" WS-FECHA-HORA(5:2) "/"
                  WS-FECHA-HORA(1:4)
               DELIMITED BY SIZE INTO WS-FECHA-REPORTE
           END-STRING.

       0300-ESCRIBIR-ENCABEZADO.
           PERFORM 0310-ESCRIBIR-SEPARADOR
           MOVE "PROCESO BATCH DE CIERRE - CUENTA BANCARIA"
               TO REG-REPORTE
           WRITE REG-REPORTE
           MOVE SPACES TO REG-REPORTE
           STRING "Fecha del proceso: " WS-FECHA-REPORTE
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 0310-ESCRIBIR-SEPARADOR
           MOVE SPACES TO REG-REPORTE
           WRITE REG-REPORTE
           MOVE SPACES TO REG-REPORTE
           STRING "Detalle de clientes procesados (Activos /"
                  " Reactivados):"
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE.

       0310-ESCRIBIR-SEPARADOR.
           MOVE ALL "=" TO REG-REPORTE
           WRITE REG-REPORTE.

       0320-ESCRIBIR-GUIONES.
           MOVE ALL "-" TO REG-REPORTE
           WRITE REG-REPORTE.

      * Encabezado de la tabla de detalle: se escribe una unica vez,
      * justo antes del primer cliente procesado (si ninguno se
      * procesa, no aparece).
       0330-ENCABEZADO-DETALLE.
           MOVE SPACES TO REG-REPORTE
           WRITE REG-REPORTE
           MOVE SPACES TO REG-REPORTE
           STRING "DNI         Nombre                         Saldo"
                  " anterior         Interes         Saldo nuevo"
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 0320-ESCRIBIR-GUIONES.

      * Cierra clientes_v3.dat despues de la primera pasada (la que
      * actualiza saldos). CLIENTES-ABIERTOS vuelve a "N" para que
      * 1500-LISTAR-INACTIVOS sepa que tiene que reabrirlo.
       0410-CERRAR-CLIENTES-PASE1.
           MOVE "CLOSE" TO WS-OPERACION
           CLOSE ARCH-CLIENTES
           IF NOT FS-CLI-OK
               DISPLAY "Aviso: error al cerrar clientes_v3.dat"
               DISPLAY "(fin de la 1ra pasada). FILE STATUS: "
                   WS-FS-CLI
           END-IF
           MOVE "N" TO WS-CLIENTES-ABIERTOS.

      * Cierra el archivo de reporte. Se hace siempre, incluso si el
      * cierre no proceso ningun cliente, para que el reporte quede
      * grabado. clientes_v3.dat ya se cerro en 0410 y, si hizo
      * falta, se reabrio y se volvio a cerrar en 1500.
       0400-CERRAR-ARCHIVOS.
           MOVE "CLOSE" TO WS-OPERACION
           CLOSE ARCH-REPORTE
           IF NOT FS-REP-OK
               DISPLAY "Aviso: error al cerrar reporte_cierre.txt."
               DISPLAY "FILE STATUS: " WS-FS-REP
           END-IF.

      ******************************************************************
      * Recorrido secuencial de TODOS los clientes.
      ******************************************************************
       1000-LEER-Y-PROCESAR.
           READ ARCH-CLIENTES NEXT RECORD
               AT END
                   SET FIN-DE-CLIENTES TO TRUE
               NOT AT END
                   PERFORM 1100-PROCESAR-UN-CLIENTE
           END-READ
           IF NOT FS-CLI-OK AND NOT FS-CLI-FIN
               PERFORM 9000-ERROR-CLIENTES
           END-IF.

      * Decide segun el estado del cliente: Activo/Reactivado
      * acreditan interes; Inactivo se excluye (solo se cuenta);
      * cualquier otro valor (archivo danado) tambien se excluye,
      * mostrando un aviso, para no perder el cierre completo por
      * un unico registro corrupto.
       1100-PROCESAR-UN-CLIENTE.
           EVALUATE TRUE
               WHEN CLIENTE-ACTIVO OR CLIENTE-REACTIVADO
                   PERFORM 1200-ACREDITAR-INTERES
               WHEN CLIENTE-INACTIVO
                   ADD 1 TO WS-CANT-INACTIVOS
               WHEN OTHER
                   ADD 1 TO WS-CANT-OMITIDOS
                   DISPLAY "Aviso: DNI " CLI-DNI " con estado"
                   DISPLAY "desconocido; se excluye de este cierre."
           END-EVALUATE
           ADD CLI-SALDO TO WS-TOTAL-SALDO-CARTERA.

      * Interes simple: SALDO x TASA. Si sumarlo al saldo desborda
      * el campo (caso extremo, saldo ya cercano al maximo), no se
      * acredita nada y se avisa, en vez de truncar en silencio.
      * (Ver la nota junto a WS-INTERES-OK: a proposito NO hay
      * sentencias aritmeticas dentro de ON SIZE ERROR aqui.)
       1200-ACREDITAR-INTERES.
           MOVE CLI-SALDO TO WS-SALDO-ANTERIOR
           COMPUTE WS-INTERES-CLIENTE ROUNDED =
               CLI-SALDO * WS-TASA-INTERES
           SET INTERES-ACREDITADO TO TRUE
           ADD WS-INTERES-CLIENTE TO CLI-SALDO
               ON SIZE ERROR
                   SET INTERES-NO-ACREDITADO TO TRUE
           END-ADD
           IF INTERES-ACREDITADO
               PERFORM 1300-GRABAR-Y-REPORTAR
           ELSE
               DISPLAY "Aviso: el saldo de " CLI-DNI " supera"
               DISPLAY "el maximo; no se acredito interes."
               MOVE WS-SALDO-ANTERIOR TO CLI-SALDO
               ADD 1 TO WS-CANT-OMITIDOS
           END-IF.

       1300-GRABAR-Y-REPORTAR.
           REWRITE REG-CLIENTE
           IF NOT FS-CLI-OK
               PERFORM 9000-ERROR-CLIENTES
           END-IF
           ADD 1 TO WS-CANT-PROCESADOS
           ADD WS-INTERES-CLIENTE TO WS-TOTAL-INTERESES
           IF PRIMER-DETALLE
               PERFORM 0330-ENCABEZADO-DETALLE
               MOVE "N" TO WS-PRIMER-DETALLE
           END-IF
           PERFORM 1400-ESCRIBIR-DETALLE.

       1400-ESCRIBIR-DETALLE.
           MOVE CLI-DNI TO WS-LD-DNI
           MOVE FUNCTION TRIM(CLI-NOMBRE TRAILING) TO WS-LD-NOMBRE
           MOVE WS-SALDO-ANTERIOR TO WS-LD-SALDO-ANT
           MOVE WS-INTERES-CLIENTE TO WS-LD-INTERES
           MOVE CLI-SALDO TO WS-LD-SALDO-NUE
           MOVE WS-LINEA-DETALLE TO REG-REPORTE
           WRITE REG-REPORTE
           IF NOT FS-REP-OK
               PERFORM 9100-ERROR-REPORTE
           END-IF.

      * Si nunca se escribio ninguna fila en la tabla de Activos /
      * Reactivados (encabezado ya escrito por 0300, sin filas
      * despues), lo aclara antes de pasar a la tabla de Inactivos.
       1450-CERRAR-DETALLE-ACTIVOS.
           IF PRIMER-DETALLE
               MOVE SPACES TO REG-REPORTE
               WRITE REG-REPORTE
               MOVE SPACES TO REG-REPORTE
               STRING "No hay clientes activos ni reactivados"
                      " para procesar."
                   DELIMITED BY SIZE INTO REG-REPORTE
               WRITE REG-REPORTE
           END-IF.

      ******************************************************************
      * Segunda pasada: lista los clientes Inactivos (DNI, Nombre y
      * Saldo, sin interes). Va despues de la tabla de Activos /
      * Reactivados y antes del resumen final.
      ******************************************************************
       1500-LISTAR-INACTIVOS.
           MOVE SPACES TO REG-REPORTE
           WRITE REG-REPORTE
           MOVE SPACES TO REG-REPORTE
           STRING "Detalle de clientes Inactivos (sin movimiento):"
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE
           IF WS-CANT-INACTIVOS = 0
               MOVE SPACES TO REG-REPORTE
               WRITE REG-REPORTE
               MOVE SPACES TO REG-REPORTE
               STRING "No hay clientes inactivos."
                   DELIMITED BY SIZE INTO REG-REPORTE
               WRITE REG-REPORTE
           ELSE
               PERFORM 1550-ENCABEZADO-INACTIVOS
               PERFORM 1600-REABRIR-Y-LISTAR
           END-IF.

       1550-ENCABEZADO-INACTIVOS.
           MOVE SPACES TO REG-REPORTE
           WRITE REG-REPORTE
           MOVE SPACES TO REG-REPORTE
           STRING "DNI         Nombre                         Saldo"
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 0320-ESCRIBIR-GUIONES.

      * Reabre clientes_v3.dat solo para lectura (ya no hace falta
      * escribir nada en esta pasada) y recorre TODO el archivo de
      * nuevo, listando unicamente los Inactivos.
       1600-REABRIR-Y-LISTAR.
           MOVE "OPEN INPUT" TO WS-OPERACION
           OPEN INPUT ARCH-CLIENTES
           IF NOT FS-CLI-OK
               PERFORM 9000-ERROR-CLIENTES
           END-IF
           SET CLIENTES-ABIERTOS TO TRUE
           MOVE "N" TO WS-FIN-CLIENTES
           PERFORM 1650-LEER-Y-LISTAR-INACTIVO UNTIL FIN-DE-CLIENTES
           MOVE "CLOSE" TO WS-OPERACION
           CLOSE ARCH-CLIENTES
           IF NOT FS-CLI-OK
               PERFORM 9000-ERROR-CLIENTES
           END-IF
           MOVE "N" TO WS-CLIENTES-ABIERTOS.

       1650-LEER-Y-LISTAR-INACTIVO.
           READ ARCH-CLIENTES NEXT RECORD
               AT END
                   SET FIN-DE-CLIENTES TO TRUE
               NOT AT END
                   IF CLIENTE-INACTIVO
                       PERFORM 1700-ESCRIBIR-INACTIVO
                   END-IF
           END-READ
           IF NOT FS-CLI-OK AND NOT FS-CLI-FIN
               PERFORM 9000-ERROR-CLIENTES
           END-IF.

       1700-ESCRIBIR-INACTIVO.
           MOVE CLI-DNI TO WS-LI-DNI
           MOVE FUNCTION TRIM(CLI-NOMBRE TRAILING) TO WS-LI-NOMBRE
           MOVE CLI-SALDO TO WS-LI-SALDO
           MOVE WS-LINEA-INACTIVO TO REG-REPORTE
           WRITE REG-REPORTE
           IF NOT FS-REP-OK
               PERFORM 9100-ERROR-REPORTE
           END-IF.

      ******************************************************************
      * Resumen final: al reporte y (resumido) a pantalla.
      ******************************************************************
       2000-ESCRIBIR-RESUMEN.
           MOVE SPACES TO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 0310-ESCRIBIR-SEPARADOR
           MOVE "RESUMEN DEL CIERRE" TO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 0310-ESCRIBIR-SEPARADOR

           MOVE WS-CANT-PROCESADOS TO WS-CANT-EDIT
           MOVE SPACES TO REG-REPORTE
           STRING "Clientes procesados (Activos/Reactivados): "
                  WS-CANT-EDIT
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE

           MOVE WS-CANT-INACTIVOS TO WS-CANT-EDIT
           MOVE SPACES TO REG-REPORTE
           STRING "Clientes inactivos excluidos:               "
                  WS-CANT-EDIT
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE

           IF WS-CANT-OMITIDOS > 0
               MOVE WS-CANT-OMITIDOS TO WS-CANT-EDIT
               MOVE SPACES TO REG-REPORTE
               STRING "Clientes con error o estado desconocido:    "
                      WS-CANT-EDIT
                   DELIMITED BY SIZE INTO REG-REPORTE
               WRITE REG-REPORTE
           END-IF

           MOVE WS-TOTAL-INTERESES TO WS-TOTAL-INT-EDIT
           MOVE SPACES TO REG-REPORTE
           STRING "Total de intereses acreditados:      $ "
                  WS-TOTAL-INT-EDIT
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE

           MOVE WS-TOTAL-SALDO-CARTERA TO WS-TOTAL-SALDO-EDIT
           MOVE SPACES TO REG-REPORTE
           STRING "Saldo total de la cartera:           $ "
                  WS-TOTAL-SALDO-EDIT
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 0310-ESCRIBIR-SEPARADOR.

       3000-MOSTRAR-RESUMEN-PANTALLA.
           MOVE WS-CANT-PROCESADOS TO WS-CANT-EDIT
           DISPLAY " "
           DISPLAY "Cierre finalizado."
           DISPLAY "Clientes procesados (Activos/Reactivados): "
               WS-CANT-EDIT
           MOVE WS-CANT-INACTIVOS TO WS-CANT-EDIT
           DISPLAY "Clientes inactivos excluidos:               "
               WS-CANT-EDIT
           IF WS-CANT-OMITIDOS > 0
               MOVE WS-CANT-OMITIDOS TO WS-CANT-EDIT
               DISPLAY "Clientes con error o estado desconocido:    "
                   WS-CANT-EDIT
           END-IF
           MOVE WS-TOTAL-INTERESES TO WS-TOTAL-INT-EDIT
           DISPLAY "Total de intereses acreditados:      $ "
               WS-TOTAL-INT-EDIT
           MOVE WS-TOTAL-SALDO-CARTERA TO WS-TOTAL-SALDO-EDIT
           DISPLAY "Saldo total de la cartera:           $ "
               WS-TOTAL-SALDO-EDIT
           DISPLAY "Reporte generado: reporte_cierre.txt"
           DISPLAY " ".

      * Error de E/S inesperado sobre clientes_v3.dat: informa el
      * FILE STATUS, cierra lo que se pueda y termina el programa.
       9000-ERROR-CLIENTES.
           DISPLAY "Error de archivo en clientes_v3.dat."
           DISPLAY "FILE STATUS: " WS-FS-CLI
           IF CLIENTES-ABIERTOS
               CLOSE ARCH-CLIENTES
           END-IF
           IF FS-REP-OK OR WS-FS-REP NOT = SPACES
               CLOSE ARCH-REPORTE
           END-IF
           MOVE 1 TO RETURN-CODE
           STOP RUN.

      * Error de E/S inesperado sobre reporte_cierre.txt.
       9100-ERROR-REPORTE.
           DISPLAY "Error de archivo en reporte_cierre.txt."
           DISPLAY "FILE STATUS: " WS-FS-REP
           IF CLIENTES-ABIERTOS
               CLOSE ARCH-CLIENTES
           END-IF
           MOVE 1 TO RETURN-CODE
           STOP RUN.
