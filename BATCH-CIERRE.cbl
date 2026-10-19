      ******************************************************************
      * PROGRAMA    : BATCH-CIERRE
      * DESCRIPCION : Proceso batch de cierre de la cartera de
      *               clientes. Recorre TODO clientes_v3.dat (el
      *               mismo archivo indexado que usa
      *               GESTION-BANCARIA) y, para
      *               cada cliente Activo (A) o Reactivado (R),
      *               acredita un interes simple mensual sobre su
      *               saldo. Los clientes Inactivos (I) se excluyen
      *               del calculo, pero se cuentan en el resumen.
      *               Despues procesa los vencimientos de plazo fijo
      *               (plazofijo.dat, Etapa 3): cada plazo fijo
      *               Activo (A) con vencimiento igual o anterior a
      *               la fecha de proceso pasa a Vencido (V); si es
      *               en pesos, su total (capital + interes) se suma
      *               al saldo del cliente; si es en dolares, se
      *               paga por caja (las cuentas no tienen moneda).
      *               Si el cliente no esta Activo ni Reactivado, el
      *               plazo fijo queda pendiente (sigue en A) para
      *               el proximo cierre.
      *               Al terminar, genera reporte_cierre.txt con el
      *               detalle y los totales del cierre.
      * FECHA DE
      * PROCESO     : la del sistema, o la de la variable de entorno
      *               FECHA_PROCESO (AAAAMMDD) si existe. Si la
      *               variable existe pero no es una fecha valida,
      *               el cierre termina con error (RETURN-CODE 1)
      *               sin abrir ni modificar ningun archivo.
      * AUTOR       : EJEMPLO
      * FECHA       : 2026-09-22
      * USO         : Pensado para correrse fuera del horario de
      *               atencion (cierre nocturno), NUNCA al mismo
      *               tiempo que GESTION-BANCARIA sobre el mismo
      *               archivo (ver README.md, seccion "Proceso
      *               Batch de Cierre").
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
      * Mismo archivo fisico que usa GESTION-BANCARIA. Acceso
      * DYNAMIC: el interes mensual y el listado de Inactivos recorren
      * todos los registros en orden de clave (DNI) con READ NEXT, y
      * los vencimientos de plazo fijo buscan a un cliente puntual
      * por su DNI (READ ... KEY IS). En una misma pasada no se
      * mezclan las dos formas de leer.
           SELECT ARCH-CLIENTES ASSIGN TO "clientes_v3.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CLI-DNI
               FILE STATUS IS WS-FS-CLI.

      * Mismo archivo fisico que usa GESTION-BANCARIA (menu PLAZO
      * FIJO). Acceso SEQUENTIAL: se recorren todos los plazos fijos
      * en orden de numero y se regraba (REWRITE) el que vence.
           SELECT ARCH-PLAZOFIJO ASSIGN TO "plazofijo.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS SEQUENTIAL
               RECORD KEY IS PF-NRO
               FILE STATUS IS WS-FS-PF.

           SELECT ARCH-REPORTE ASSIGN TO "reporte_cierre.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-REP.

       DATA DIVISION.
       FILE SECTION.
       FD  ARCH-CLIENTES.
      * Mismo layout que usa GESTION-BANCARIA (ver CLIENTE.cpy).
      * Ambos programas se recompilan siempre juntos si el layout
      * cambia.
           COPY CLIENTE.

       FD  ARCH-PLAZOFIJO.
      * Mismo layout que usa GESTION-BANCARIA (ver PLAZOFIJO.cpy).
           COPY PLAZOFIJO.

      * 132 posiciones (el ancho clasico de una impresora de listados)
      * para que entre la tabla de vencimientos. Las lineas de "=" y
      * "-" siguen teniendo 100, y como los espacios del final no se
      * graban, las secciones anteriores quedan exactamente iguales.
       FD  ARCH-REPORTE.
       01  REG-REPORTE             PIC X(132).

       WORKING-STORAGE SECTION.

      * Estado de las operaciones de E/S de cada archivo
       01  WS-FS-CLI               PIC XX     VALUE "00".
           88  FS-CLI-OK                      VALUE "00".
           88  FS-CLI-FIN                     VALUE "10".
           88  FS-CLI-NO-EXISTE                VALUE "35".
           88  FS-CLI-NO-ENCONTRADO            VALUE "23".
       01  WS-FS-PF                PIC XX     VALUE "00".
           88  FS-PF-OK                       VALUE "00".
           88  FS-PF-FIN                      VALUE "10".
           88  FS-PF-NO-EXISTE                 VALUE "35".
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

      * Lo mismo para plazofijo.dat: si no existe (nunca se
      * constituyo un plazo fijo), no hay vencimientos que procesar.
       01  WS-PLAZOFIJO-ABIERTO    PIC X      VALUE "N".
           88  PLAZOFIJO-ABIERTO               VALUE "S".

       01  WS-FIN-PLAZOFIJO        PIC X      VALUE "N".
           88  FIN-DE-PLAZOFIJO                VALUE "S".

      * Indica si ya se escribio el encabezado de la tabla de
      * vencimientos (antes del primer plazo fijo vencido).
       01  WS-PRIMER-VENC          PIC X      VALUE "S".
           88  PRIMER-VENC                     VALUE "S".

      * Que se hizo con un plazo fijo vencido. Solo "ACREDITADO" y
      * "PAGO-CAJA" lo pasan a V; los demas lo dejan en A
      * (pendiente para el proximo cierre).
       01  WS-RESULTADO-VENC       PIC X      VALUE SPACE.
           88  VENC-ACREDITADO                 VALUE "A".
           88  VENC-PAGO-CAJA                  VALUE "C".
           88  VENC-CLI-INACTIVO               VALUE "I".
           88  VENC-CLI-INEXISTENTE            VALUE "X".
           88  VENC-CLI-ESTADO-DESC            VALUE "E".
           88  VENC-SALDO-MAXIMO               VALUE "M".

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

      * Acumuladores de los vencimientos de plazo fijo
       01  WS-CANT-PF-ACREDITADOS  PIC 9(7)   VALUE 0.
       01  WS-CANT-PF-CAJA         PIC 9(7)   VALUE 0.
       01  WS-CANT-PF-PENDIENTES   PIC 9(7)   VALUE 0.
       01  WS-TOTAL-PF-PESOS       PIC 9(13)V99 VALUE 0.
       01  WS-TOTAL-PF-DOLARES     PIC 9(13)V99 VALUE 0.

      * Fecha de proceso ("hoy" para el cierre): AAAAMMDD para
      * comparar con el vencimiento, DD/MM/AAAA para el reporte.
       01  WS-FECHA-HORA           PIC X(21).
       01  WS-FECHA-PROCESO        PIC 9(8).
       01  WS-FECHA-ENV            PIC X(20).
       01  WS-FECHA-AUX            PIC 9(8).
       01  WS-FECHA-AUX-R REDEFINES WS-FECHA-AUX.
           05  WS-FA-ANIO          PIC 9(4).
           05  WS-FA-MES           PIC 9(2).
           05  WS-FA-DIA           PIC 9(2).
       01  WS-FECHA-EDIT           PIC X(10).
       01  WS-FECHA-REPORTE        PIC X(10).

      * Campos editados para el reporte y la pantalla
       01  WS-CANT-EDIT             PIC ZZ,ZZZ,ZZ9.
       01  WS-TOTAL-INT-EDIT        PIC Z,ZZZ,ZZZ,ZZ9.99.
       01  WS-TOTAL-SALDO-EDIT      PIC Z,ZZZ,ZZZ,ZZ9.99.

      * Lineas del resumen para los vencimientos: los anchos estan
      * elegidos para que el "$" y los numeros queden en las mismas
      * columnas que en las lineas anteriores del resumen.
       01  WS-LINEA-RES-CANT.
           05  WS-LRC-TEXTO         PIC X(43).
           05  WS-LRC-CANT          PIC ZZ,ZZZ,ZZ9.
       01  WS-LINEA-RES-IMPORTE.
           05  WS-LRI-TEXTO         PIC X(32).
           05  WS-LRI-MONEDA        PIC X(6).
           05  WS-LRI-IMPORTE       PIC ZZ,ZZZ,ZZZ,ZZ9.99.

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

      * Tabla de vencimientos de plazo fijo: encabezado y una fila
      * por plazo fijo vencido (acreditado, pagado por caja o
      * pendiente). Los dos grupos tienen los mismos anchos.
       01  WS-ENCAB-VENC.
           05  FILLER               PIC X(8)  VALUE "Numero".
           05  FILLER               PIC X(10) VALUE "DNI".
           05  FILLER               PIC X(4)  VALUE "Mon".
           05  FILLER               PIC X(17) VALUE
                                        "          Capital".
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  FILLER               PIC X(17) VALUE
                                        "          Interes".
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  FILLER               PIC X(17) VALUE
                                        "            Total".
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  FILLER               PIC X(12) VALUE "Vencimiento".
           05  FILLER               PIC X(30) VALUE "Resultado".

       01  WS-LINEA-VENC.
           05  WS-LV-NRO            PIC 9(6).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  WS-LV-DNI            PIC 9(8).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  WS-LV-MONEDA         PIC X(3).
           05  FILLER               PIC X     VALUE SPACE.
           05  WS-LV-CAPITAL        PIC ZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  WS-LV-INTERES        PIC ZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  WS-LV-TOTAL          PIC ZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  WS-LV-VENC           PIC X(10).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  WS-LV-RESULTADO      PIC X(30).

      * Saldo del cliente antes de sumarle un plazo fijo (para
      * dejarlo como estaba si la suma desborda el campo).
       01  WS-SALDO-ANTES-PF        PIC S9(9)V99.

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
      * Despues (4000) se procesan los vencimientos de plazo fijo. Van
      * DESPUES del interes mensual a proposito: el capital de un
      * plazo fijo ya gano su propio interes, y no tiene que ganar
      * ademas el interes mensual del cierre en que se acredita.
      * La fecha de proceso se fija (0050) antes de abrir cualquier
      * archivo: si FECHA_PROCESO es invalida, el cierre termina sin
      * tocar nada (ni siquiera el reporte anterior).
       0000-PRINCIPAL.
           DISPLAY " "
           DISPLAY "=== BATCH DE CIERRE - CUENTA BANCARIA ==="
           PERFORM 0050-FIJAR-FECHA-PROCESO
           PERFORM 0200-ARMAR-FECHA
           DISPLAY "Fecha de proceso: " WS-FECHA-REPORTE
           PERFORM 0100-ABRIR-ARCHIVO-CLIENTES
           PERFORM 0150-ABRIR-ARCHIVO-REPORTE
           PERFORM 0300-ESCRIBIR-ENCABEZADO
           IF CLIENTES-ABIERTOS
               PERFORM 1000-LEER-Y-PROCESAR UNTIL FIN-DE-CLIENTES
               PERFORM 0410-CERRAR-CLIENTES-PASE1
           END-IF
           PERFORM 1450-CERRAR-DETALLE-ACTIVOS
           PERFORM 1500-LISTAR-INACTIVOS
           PERFORM 4000-PROCESAR-VENCIMIENTOS
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

      * Fija WS-FECHA-PROCESO ("hoy" para el cierre), con el mismo
      * criterio que GESTION-BANCARIA: la variable de entorno
      * FECHA_PROCESO (AAAAMMDD) si existe, o si no la del sistema.
      * FUNCTION CURRENT-DATE devuelve 21 caracteres: AAAAMMDD +
      * hora + huso horario; se toman solo los primeros 8.
      * DIFERENCIA con GESTION-BANCARIA: si la variable existe pero
      * no es una fecha valida, aca se termina con error. El batch
      * corre sin nadie mirando la pantalla, y un error de tipeo en
      * la fecha haria vencer (o no) plazos fijos que no corresponden.
       0050-FIJAR-FECHA-PROCESO.
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
                   DISPLAY "Cierre NO realizado: no se modifico"
                   DISPLAY "ningun archivo."
                   MOVE 1 TO RETURN-CODE
                   STOP RUN
               END-IF
           END-IF.

      * Arma la fecha de proceso como DD/MM/AAAA para el reporte.
       0200-ARMAR-FECHA.
           MOVE WS-FECHA-PROCESO TO WS-FECHA-AUX
           PERFORM 8070-EDITAR-FECHA
           MOVE WS-FECHA-EDIT TO WS-FECHA-REPORTE.

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

      * Los separadores ocupan 100 posiciones (no las 132 del
      * renglon), para que las lineas de siempre no cambien.
       0310-ESCRIBIR-SEPARADOR.
           MOVE SPACES TO REG-REPORTE
           MOVE ALL "=" TO REG-REPORTE(1:100)
           WRITE REG-REPORTE.

       0320-ESCRIBIR-GUIONES.
           MOVE SPACES TO REG-REPORTE
           MOVE ALL "-" TO REG-REPORTE(1:100)
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
      * Vencimientos de plazo fijo (Etapa 3). Recorre plazofijo.dat
      * en orden de numero y procesa cada plazo fijo Activo (A) cuyo
      * vencimiento sea igual o anterior a la fecha de proceso (asi,
      * si un dia no corrio el cierre, el siguiente procesa lo que
      * vencio en el medio). Los Cancelados (C) y Vencidos (V) no se
      * tocan, por eso correr el cierre dos veces no acredita dos
      * veces el mismo plazo fijo.
      ******************************************************************
       4000-PROCESAR-VENCIMIENTOS.
           MOVE SPACES TO REG-REPORTE
           WRITE REG-REPORTE
           MOVE SPACES TO REG-REPORTE
           STRING "Detalle de vencimientos de plazo fijo:"
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 4010-ABRIR-PLAZOFIJO
           IF PLAZOFIJO-ABIERTO
               PERFORM 4020-ABRIR-CLIENTES-VENC
               MOVE "N" TO WS-FIN-PLAZOFIJO
               PERFORM 4100-LEER-PLAZO-FIJO UNTIL FIN-DE-PLAZOFIJO
               PERFORM 4900-CERRAR-VENCIMIENTOS
           END-IF
           IF PRIMER-VENC
               MOVE SPACES TO REG-REPORTE
               WRITE REG-REPORTE
               MOVE SPACES TO REG-REPORTE
               STRING "No hay plazos fijos vencidos."
                   DELIMITED BY SIZE INTO REG-REPORTE
               WRITE REG-REPORTE
           END-IF.

      * Si plazofijo.dat no existe (nunca se constituyo un plazo
      * fijo), no es un error: no hay vencimientos.
       4010-ABRIR-PLAZOFIJO.
           MOVE "OPEN I-O" TO WS-OPERACION
           OPEN I-O ARCH-PLAZOFIJO
           EVALUATE TRUE
               WHEN FS-PF-OK
                   SET PLAZOFIJO-ABIERTO TO TRUE
               WHEN FS-PF-NO-EXISTE
                   CONTINUE
               WHEN OTHER
                   PERFORM 9200-ERROR-PLAZOFIJO
           END-EVALUATE.

      * Reabre clientes_v3.dat para leer clientes por DNI y sumarles
      * el plazo fijo. Si no existe, cada plazo fijo vencido queda
      * pendiente como "cliente inexistente" (ver 4210).
       4020-ABRIR-CLIENTES-VENC.
           MOVE "OPEN I-O" TO WS-OPERACION
           OPEN I-O ARCH-CLIENTES
           EVALUATE TRUE
               WHEN FS-CLI-OK
                   SET CLIENTES-ABIERTOS TO TRUE
               WHEN FS-CLI-NO-EXISTE
                   CONTINUE
               WHEN OTHER
                   PERFORM 9000-ERROR-CLIENTES
           END-EVALUATE.

       4100-LEER-PLAZO-FIJO.
           READ ARCH-PLAZOFIJO NEXT RECORD
               AT END
                   SET FIN-DE-PLAZOFIJO TO TRUE
               NOT AT END
                   IF PF-ACTIVO
                      AND PF-FECHA-VENC <= WS-FECHA-PROCESO
                       PERFORM 4200-PROCESAR-UN-VENCIMIENTO
                   END-IF
           END-READ
           IF NOT FS-PF-OK AND NOT FS-PF-FIN
               PERFORM 9200-ERROR-PLAZOFIJO
           END-IF.

      * Primero se controla el cliente (sea cual sea la moneda: un
      * cliente inactivo no cobra ni por cuenta ni por caja). Si esta
      * bien: en pesos se suma al saldo; en dolares se paga por caja.
      * Solo en esos dos casos el plazo fijo pasa a V.
       4200-PROCESAR-UN-VENCIMIENTO.
           PERFORM 4210-BUSCAR-CLIENTE
           IF WS-RESULTADO-VENC = SPACE
               IF PF-MONEDA-DOLARES
                   SET VENC-PAGO-CAJA TO TRUE
               ELSE
                   PERFORM 4220-SUMAR-AL-SALDO
               END-IF
           END-IF
           IF VENC-ACREDITADO OR VENC-PAGO-CAJA
               PERFORM 4230-MARCAR-VENCIDO
           END-IF
           PERFORM 4300-CONTAR-Y-REPORTAR.

      * Deja WS-RESULTADO-VENC en SPACE si el cliente existe y esta
      * Activo o Reactivado; si no, en el motivo por el que el plazo
      * fijo queda pendiente.
       4210-BUSCAR-CLIENTE.
           MOVE SPACE TO WS-RESULTADO-VENC
           IF NOT CLIENTES-ABIERTOS
               SET VENC-CLI-INEXISTENTE TO TRUE
           ELSE
               MOVE PF-DNI TO CLI-DNI
               MOVE "READ" TO WS-OPERACION
               READ ARCH-CLIENTES KEY IS CLI-DNI
                   INVALID KEY
                       SET VENC-CLI-INEXISTENTE TO TRUE
               END-READ
               IF NOT FS-CLI-OK AND NOT FS-CLI-NO-ENCONTRADO
                   PERFORM 9000-ERROR-CLIENTES
               END-IF
               IF FS-CLI-OK
                   EVALUATE TRUE
                       WHEN CLIENTE-ACTIVO OR CLIENTE-REACTIVADO
                           CONTINUE
                       WHEN CLIENTE-INACTIVO
                           SET VENC-CLI-INACTIVO TO TRUE
                       WHEN OTHER
                           SET VENC-CLI-ESTADO-DESC TO TRUE
                   END-EVALUATE
               END-IF
           END-IF
           EVALUATE TRUE
               WHEN VENC-CLI-INEXISTENTE
                   DISPLAY "Aviso: el plazo fijo " PF-NRO " es del DNI "
                       PF-DNI ", que"
                   DISPLAY "no existe; queda pendiente."
               WHEN VENC-CLI-ESTADO-DESC
                   DISPLAY "Aviso: el cliente " PF-DNI
                       " tiene un estado"
                   DISPLAY "desconocido; el plazo fijo " PF-NRO
                       " queda pendiente."
           END-EVALUATE.

      * Suma el total (capital + interes) al saldo del cliente. Si
      * desborda el campo, no se acredita nada y el plazo fijo queda
      * pendiente. Igual que en 1200: a proposito NO hay sentencias
      * aritmeticas dentro de ON SIZE ERROR (ver la nota junto a
      * WS-INTERES-OK), solo se marca el resultado.
       4220-SUMAR-AL-SALDO.
           MOVE CLI-SALDO TO WS-SALDO-ANTES-PF
           SET VENC-ACREDITADO TO TRUE
           ADD PF-TOTAL TO CLI-SALDO
               ON SIZE ERROR
                   SET VENC-SALDO-MAXIMO TO TRUE
           END-ADD
           IF VENC-ACREDITADO
               MOVE "REWRITE" TO WS-OPERACION
               REWRITE REG-CLIENTE
               IF NOT FS-CLI-OK
                   PERFORM 9000-ERROR-CLIENTES
               END-IF
           ELSE
               MOVE WS-SALDO-ANTES-PF TO CLI-SALDO
               DISPLAY "Aviso: el plazo fijo " PF-NRO " haria superar"
               DISPLAY "el saldo maximo del cliente " PF-DNI
                   "; no se acredito."
           END-IF.

      * Pasa el plazo fijo a V. Se hace DESPUES de grabar el saldo:
      * si fallara justo aca, el saldo ya tiene la plata, y hay que
      * avisar para que se corrija a mano (si no, el proximo cierre
      * lo volveria a acreditar).
       4230-MARCAR-VENCIDO.
           SET PF-VENCIDO TO TRUE
           MOVE "REWRITE" TO WS-OPERACION
           REWRITE REG-PLAZOFIJO
           IF NOT FS-PF-OK
               IF VENC-ACREDITADO
                   DISPLAY "ATENCION: el plazo fijo " PF-NRO
                       " ya se sumo al saldo"
                   DISPLAY "del cliente " PF-DNI ", pero no se pudo"
                   DISPLAY "marcar como vencido. Corregirlo a mano"
                   DISPLAY "antes del proximo cierre (si no, se"
                   DISPLAY "acreditaria dos veces)."
               END-IF
               PERFORM 9200-ERROR-PLAZOFIJO
           END-IF.

       4300-CONTAR-Y-REPORTAR.
           EVALUATE TRUE
               WHEN VENC-ACREDITADO
                   ADD 1 TO WS-CANT-PF-ACREDITADOS
                   ADD PF-TOTAL TO WS-TOTAL-PF-PESOS
                   ADD PF-TOTAL TO WS-TOTAL-SALDO-CARTERA
                   MOVE "Acreditado" TO WS-LV-RESULTADO
               WHEN VENC-PAGO-CAJA
                   ADD 1 TO WS-CANT-PF-CAJA
                   ADD PF-TOTAL TO WS-TOTAL-PF-DOLARES
                   MOVE "Pagar por caja (U$S)" TO WS-LV-RESULTADO
               WHEN VENC-CLI-INACTIVO
                   ADD 1 TO WS-CANT-PF-PENDIENTES
                   MOVE "Pendiente: cliente inactivo"
                       TO WS-LV-RESULTADO
               WHEN VENC-CLI-INEXISTENTE
                   ADD 1 TO WS-CANT-PF-PENDIENTES
                   MOVE "Pendiente: cliente inexistente"
                       TO WS-LV-RESULTADO
               WHEN VENC-CLI-ESTADO-DESC
                   ADD 1 TO WS-CANT-PF-PENDIENTES
                   MOVE "Pendiente: estado desconocido"
                       TO WS-LV-RESULTADO
               WHEN VENC-SALDO-MAXIMO
                   ADD 1 TO WS-CANT-PF-PENDIENTES
                   MOVE "Error: supera saldo maximo"
                       TO WS-LV-RESULTADO
           END-EVALUATE
           IF PRIMER-VENC
               PERFORM 4310-ENCABEZADO-VENC
               MOVE "N" TO WS-PRIMER-VENC
           END-IF
           MOVE PF-NRO TO WS-LV-NRO
           MOVE PF-DNI TO WS-LV-DNI
           MOVE PF-MONEDA TO WS-LV-MONEDA
           MOVE PF-MONTO TO WS-LV-CAPITAL
           MOVE PF-INTERES TO WS-LV-INTERES
           MOVE PF-TOTAL TO WS-LV-TOTAL
           MOVE PF-FECHA-VENC TO WS-FECHA-AUX
           PERFORM 8070-EDITAR-FECHA
           MOVE WS-FECHA-EDIT TO WS-LV-VENC
           MOVE WS-LINEA-VENC TO REG-REPORTE
           WRITE REG-REPORTE
           IF NOT FS-REP-OK
               PERFORM 9100-ERROR-REPORTE
           END-IF.

      * La tabla de vencimientos tiene 121 posiciones de ancho: la
      * linea de guiones la acompana (las otras tablas usan 100).
       4310-ENCABEZADO-VENC.
           MOVE SPACES TO REG-REPORTE
           WRITE REG-REPORTE
           MOVE WS-ENCAB-VENC TO REG-REPORTE
           WRITE REG-REPORTE
           MOVE SPACES TO REG-REPORTE
           MOVE ALL "-" TO REG-REPORTE(1:121)
           WRITE REG-REPORTE.

       4900-CERRAR-VENCIMIENTOS.
           MOVE "CLOSE" TO WS-OPERACION
           CLOSE ARCH-PLAZOFIJO
           IF NOT FS-PF-OK
               PERFORM 9200-ERROR-PLAZOFIJO
           END-IF
           MOVE "N" TO WS-PLAZOFIJO-ABIERTO
           IF CLIENTES-ABIERTOS
               CLOSE ARCH-CLIENTES
               IF NOT FS-CLI-OK
                   PERFORM 9000-ERROR-CLIENTES
               END-IF
               MOVE "N" TO WS-CLIENTES-ABIERTOS
           END-IF.

      * Pasa WS-FECHA-AUX (AAAAMMDD) a WS-FECHA-EDIT (DD/MM/AAAA).
      * (Igual que en GESTION-BANCARIA.)
       8070-EDITAR-FECHA.
           MOVE SPACES TO WS-FECHA-EDIT
           STRING WS-FA-DIA "/" WS-FA-MES "/" WS-FA-ANIO
               DELIMITED BY SIZE INTO WS-FECHA-EDIT.

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

           PERFORM 2010-RESUMEN-VENC-REPORTE

           MOVE WS-TOTAL-SALDO-CARTERA TO WS-TOTAL-SALDO-EDIT
           MOVE SPACES TO REG-REPORTE
           STRING "Saldo total de la cartera:           $ "
                  WS-TOTAL-SALDO-EDIT
               DELIMITED BY SIZE INTO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 0310-ESCRIBIR-SEPARADOR.

      * Lineas del resumen de los vencimientos de plazo fijo, en el
      * reporte. Se escriben siempre (aunque sean cero), para que el
      * resumen tenga siempre la misma forma.
       2010-RESUMEN-VENC-REPORTE.
           PERFORM 2020-ARMAR-LINEA-ACREDITADOS
           MOVE WS-LINEA-RES-CANT TO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 2030-ARMAR-LINEA-TOTAL-PESOS
           MOVE WS-LINEA-RES-IMPORTE TO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 2040-ARMAR-LINEA-CAJA
           MOVE WS-LINEA-RES-CANT TO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 2050-ARMAR-LINEA-TOTAL-DOLARES
           MOVE WS-LINEA-RES-IMPORTE TO REG-REPORTE
           WRITE REG-REPORTE
           PERFORM 2060-ARMAR-LINEA-PENDIENTES
           MOVE WS-LINEA-RES-CANT TO REG-REPORTE
           WRITE REG-REPORTE.

      * Cada uno de estos parrafos arma una linea del resumen de
      * vencimientos; la usan el reporte (2010) y la pantalla (3010).
       2020-ARMAR-LINEA-ACREDITADOS.
           MOVE "Plazos fijos vencidos acreditados:" TO WS-LRC-TEXTO
           MOVE WS-CANT-PF-ACREDITADOS TO WS-LRC-CANT.

       2030-ARMAR-LINEA-TOTAL-PESOS.
           MOVE "Acreditado por vencimientos:" TO WS-LRI-TEXTO
           MOVE "     $" TO WS-LRI-MONEDA
           MOVE WS-TOTAL-PF-PESOS TO WS-LRI-IMPORTE.

       2040-ARMAR-LINEA-CAJA.
           MOVE "Plazos fijos en dolares (pago por caja):"
               TO WS-LRC-TEXTO
           MOVE WS-CANT-PF-CAJA TO WS-LRC-CANT.

       2050-ARMAR-LINEA-TOTAL-DOLARES.
           MOVE "A pagar por caja en dolares:" TO WS-LRI-TEXTO
           MOVE "   U$S" TO WS-LRI-MONEDA
           MOVE WS-TOTAL-PF-DOLARES TO WS-LRI-IMPORTE.

       2060-ARMAR-LINEA-PENDIENTES.
           MOVE "Plazos fijos vencidos pendientes:" TO WS-LRC-TEXTO
           MOVE WS-CANT-PF-PENDIENTES TO WS-LRC-CANT.

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
           PERFORM 2020-ARMAR-LINEA-ACREDITADOS
           DISPLAY WS-LINEA-RES-CANT
           PERFORM 2030-ARMAR-LINEA-TOTAL-PESOS
           DISPLAY WS-LINEA-RES-IMPORTE
           PERFORM 2040-ARMAR-LINEA-CAJA
           DISPLAY WS-LINEA-RES-CANT
           PERFORM 2050-ARMAR-LINEA-TOTAL-DOLARES
           DISPLAY WS-LINEA-RES-IMPORTE
           PERFORM 2060-ARMAR-LINEA-PENDIENTES
           DISPLAY WS-LINEA-RES-CANT
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
           IF PLAZOFIJO-ABIERTO
               CLOSE ARCH-PLAZOFIJO
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
           IF PLAZOFIJO-ABIERTO
               CLOSE ARCH-PLAZOFIJO
           END-IF
           MOVE 1 TO RETURN-CODE
           STOP RUN.

      * Error de E/S inesperado sobre plazofijo.dat.
       9200-ERROR-PLAZOFIJO.
           DISPLAY "Error de archivo en plazofijo.dat ("
               FUNCTION TRIM(WS-OPERACION) ")."
           DISPLAY "FILE STATUS: " WS-FS-PF
           IF PLAZOFIJO-ABIERTO
               CLOSE ARCH-PLAZOFIJO
           END-IF
           IF CLIENTES-ABIERTOS
               CLOSE ARCH-CLIENTES
           END-IF
           CLOSE ARCH-REPORTE
           MOVE 1 TO RETURN-CODE
           STOP RUN.
