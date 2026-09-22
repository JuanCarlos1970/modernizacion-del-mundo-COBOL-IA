      ******************************************************************
      * PROGRAMA    : LISTADO-CLIENTES
      * DESCRIPCION : Listado de consulta de la cartera de clientes,
      *               de SOLO LECTURA. Recorre clientes_v3.dat (el
      *               mismo archivo indexado que usan CUENTA y
      *               BATCH-CIERRE) y muestra a los clientes
      *               agrupados en tres secciones por estado:
      *               Activos (A), Reactivados (R) e Inactivos (I),
      *               con un resumen de cantidades y saldo total al
      *               final. Genera el mismo contenido por pantalla
      *               (DISPLAY) y en listado_clientes.txt.
      * AUTOR       : EJEMPLO
      * FECHA       : 2026-09-22
      * IMPORTANTE  : Este programa NUNCA abre clientes_v3.dat en
      *               modo I-O ni OUTPUT, solo INPUT. No hace ningun
      *               WRITE, REWRITE ni DELETE sobre ese archivo: no
      *               modifica clientes ni saldos bajo ninguna
      *               circunstancia. A diferencia de BATCH-CIERRE.cbl
      *               se puede correr en cualquier momento sin
      *               riesgo para los datos (aunque igual conviene
      *               no correrlo mientras CUENTA esta escribiendo
      *               un registro puntual, ver README.md).
      * EJECUCION   : ver_listado_clientes.bat (compila y ejecuta).
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LISTADO-CLIENTES.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. PC.
       OBJECT-COMPUTER. PC.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
      * Mismo archivo fisico que usan CUENTA y BATCH-CIERRE. Acceso
      * SEQUENTIAL: este listado recorre todos los registros en
      * orden de clave (DNI), no busca clientes puntuales.
           SELECT ARCH-CLIENTES ASSIGN TO "clientes_v3.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS SEQUENTIAL
               RECORD KEY IS CLI-DNI
               FILE STATUS IS WS-FS.

           SELECT ARCH-LISTADO ASSIGN TO "listado_clientes.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-LIS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARCH-CLIENTES.
      * Mismo layout que usan CUENTA y BATCH-CIERRE (ver CLIENTE.cpy).
      * Los tres programas se recompilan siempre juntos si el
      * layout cambia.
           COPY CLIENTE.

       FD  ARCH-LISTADO.
       01  REG-LISTADO              PIC X(100).

       WORKING-STORAGE SECTION.

      * Estado de las operaciones de E/S de cada archivo
       01  WS-FS                    PIC XX     VALUE "00".
           88  FS-OK                           VALUE "00".
           88  FS-FIN                          VALUE "10".
           88  FS-NO-EXISTE                     VALUE "35".
       01  WS-FS-LIS                PIC XX     VALUE "00".
           88  FS-LIS-OK                       VALUE "00".
      * Operacion de archivo en curso, solo para informar errores.
       01  WS-OPERACION             PIC X(10)  VALUE SPACES.

      * El archivo de clientes puede no existir todavia (cartera
      * vacia): el listado no falla, simplemente no lista a nadie.
       01  WS-ARCHIVO-EXISTE        PIC X      VALUE "N".
           88  ARCHIVO-EXISTE                   VALUE "S".
      * Indica si clientes_v3.dat esta abierto en este momento (una
      * de las tres pasadas de lectura en curso), para saber si hay
      * que cerrarlo al informar un error fatal.
       01  WS-CLIENTES-ABIERTOS     PIC X      VALUE "N".
           88  CLIENTES-ABIERTOS                VALUE "S".
       01  WS-FIN-CLIENTES          PIC X      VALUE "N".
           88  FIN-DE-CLIENTES                  VALUE "S".

      * Acumuladores del listado
       01  WS-CANT-ACTIVOS          PIC 9(7)   VALUE 0.
       01  WS-CANT-REACTIVADOS      PIC 9(7)   VALUE 0.
       01  WS-CANT-INACTIVOS        PIC 9(7)   VALUE 0.
       01  WS-CANT-TOTAL            PIC 9(7)   VALUE 0.
       01  WS-SALDO-TOTAL           PIC S9(11)V99 VALUE 0.

      * Campos editados para mostrar cantidades y saldos con formato
       01  WS-CANT-EDIT             PIC ZZ,ZZZ,ZZ9.
       01  WS-SALDO-EDIT            PIC Z,ZZZ,ZZZ,ZZ9.99.
       01  WS-SALDO-TOTAL-EDIT      PIC Z,ZZZ,ZZZ,ZZ9.99.

      * Buffer general de linea: toda salida (por pantalla y al
      * archivo) pasa por aca antes de escribirse (ver
      * 0900-ESCRIBIR-LINEA). Se limpia solo despues de cada
      * escritura, asi que en cada parrafo se arma sobre un buffer
      * ya en blanco.
       01  WS-LINEA                 PIC X(100) VALUE SPACES.

      * Buffer para las lineas "Etiqueta: valor" del detalle de
      * cada cliente (DNI, Nombre, Direccion, Telefono, Saldo,
      * Estado). WS-LC-ETIQUETA siempre mide 11 caracteres, para que
      * los valores queden alineados en una misma columna.
       01  WS-LINEA-CLIENTE.
           05  WS-LC-ETIQUETA       PIC X(11).
           05  WS-LC-VALOR          PIC X(60).

       PROCEDURE DIVISION.

      ******************************************************************
      * Programa principal: arma el listado en 3 secciones (Activos,
      * Reactivados, Inactivos) mas un resumen final.
      ******************************************************************
       0000-PRINCIPAL.
           DISPLAY " "
           DISPLAY "=== LISTADO DE CLIENTES (solo lectura) ==="
           PERFORM 0100-ABRIR-ARCHIVO-LISTADO
           PERFORM 0150-VERIFICAR-ARCHIVO-CLIENTES
           PERFORM 0300-ESCRIBIR-ENCABEZADO
           PERFORM 2000-LISTAR-ACTIVOS
           PERFORM 3000-LISTAR-REACTIVADOS
           PERFORM 4000-LISTAR-INACTIVOS
           PERFORM 5000-ESCRIBIR-RESUMEN
           PERFORM 0400-CERRAR-ARCHIVO-LISTADO
           STOP RUN.

       0100-ABRIR-ARCHIVO-LISTADO.
           MOVE "OPEN OUT" TO WS-OPERACION
           OPEN OUTPUT ARCH-LISTADO
           IF NOT FS-LIS-OK
               PERFORM 9100-ERROR-LISTADO
           END-IF.

      * Comprueba si clientes_v3.dat existe, sin dejarlo abierto:
      * cada seccion (2000/3000/4000) abre y cierra el archivo por
      * su cuenta, en modo INPUT, nunca I-O ni OUTPUT.
       0150-VERIFICAR-ARCHIVO-CLIENTES.
           MOVE "OPEN INPUT" TO WS-OPERACION
           OPEN INPUT ARCH-CLIENTES
           EVALUATE TRUE
               WHEN FS-OK
                   SET CLIENTES-ABIERTOS TO TRUE
                   SET ARCHIVO-EXISTE TO TRUE
                   MOVE "CLOSE" TO WS-OPERACION
                   CLOSE ARCH-CLIENTES
                   IF NOT FS-OK
                       PERFORM 9000-ERROR-CLIENTES
                   END-IF
                   MOVE "N" TO WS-CLIENTES-ABIERTOS
               WHEN FS-NO-EXISTE
                   CONTINUE
               WHEN OTHER
                   PERFORM 9000-ERROR-CLIENTES
           END-EVALUATE.

       0300-ESCRIBIR-ENCABEZADO.
           PERFORM 0310-SEPARADOR
           MOVE "LISTADO DE CLIENTES" TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA
           MOVE "(solo lectura - no modifica datos)" TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA
           PERFORM 0310-SEPARADOR.

       0310-SEPARADOR.
           MOVE ALL "=" TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA.

       0320-GUIONES.
           MOVE ALL "-" TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA.

      * Unico lugar del programa que hace DISPLAY y WRITE: mantiene
      * la salida por pantalla y el archivo con el mismo contenido.
       0900-ESCRIBIR-LINEA.
           DISPLAY FUNCTION TRIM(WS-LINEA TRAILING)
           MOVE WS-LINEA TO REG-LISTADO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-LISTADO
           IF NOT FS-LIS-OK
               PERFORM 9100-ERROR-LISTADO
           END-IF
           MOVE SPACES TO WS-LINEA.

       0400-CERRAR-ARCHIVO-LISTADO.
           MOVE "CLOSE" TO WS-OPERACION
           CLOSE ARCH-LISTADO
           IF NOT FS-LIS-OK
               DISPLAY "Aviso: error al cerrar listado_clientes.txt."
               DISPLAY "FILE STATUS: " WS-FS-LIS
           END-IF.

      ******************************************************************
      * Seccion 1: Clientes Activos (A). Esta pasada, al recorrer
      * TODO el archivo, tambien totaliza la cantidad y el saldo de
      * TODOS los clientes (sea cual sea su estado), para no
      * necesitar una cuarta pasada solo para el resumen.
      ******************************************************************
       2000-LISTAR-ACTIVOS.
           MOVE "Clientes Activos (A):" TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA
           PERFORM 0320-GUIONES
           IF ARCHIVO-EXISTE
               MOVE "OPEN INPUT" TO WS-OPERACION
               OPEN INPUT ARCH-CLIENTES
               IF NOT FS-OK
                   PERFORM 9000-ERROR-CLIENTES
               END-IF
               SET CLIENTES-ABIERTOS TO TRUE
               MOVE "N" TO WS-FIN-CLIENTES
               PERFORM 2100-LEER-Y-LISTAR-ACTIVO
                   UNTIL FIN-DE-CLIENTES
               MOVE "CLOSE" TO WS-OPERACION
               CLOSE ARCH-CLIENTES
               IF NOT FS-OK
                   PERFORM 9000-ERROR-CLIENTES
               END-IF
               MOVE "N" TO WS-CLIENTES-ABIERTOS
           END-IF
           IF WS-CANT-ACTIVOS = 0
               MOVE "No hay clientes en estado Activo (A)."
                   TO WS-LINEA
               PERFORM 0900-ESCRIBIR-LINEA
           END-IF
           PERFORM 0900-ESCRIBIR-LINEA.

       2100-LEER-Y-LISTAR-ACTIVO.
           READ ARCH-CLIENTES NEXT RECORD
               AT END
                   SET FIN-DE-CLIENTES TO TRUE
               NOT AT END
                   PERFORM 2200-PROCESAR-REGISTRO-ACTIVOS
           END-READ
           IF NOT FS-OK AND NOT FS-FIN
               PERFORM 9000-ERROR-CLIENTES
           END-IF.

       2200-PROCESAR-REGISTRO-ACTIVOS.
           ADD 1 TO WS-CANT-TOTAL
           ADD CLI-SALDO TO WS-SALDO-TOTAL
           IF CLIENTE-ACTIVO
               ADD 1 TO WS-CANT-ACTIVOS
               PERFORM 6800-MOSTRAR-CLIENTE
           END-IF.

      ******************************************************************
      * Seccion 2: Clientes Reactivados (R).
      ******************************************************************
       3000-LISTAR-REACTIVADOS.
           MOVE "Clientes Reactivados (R):" TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA
           PERFORM 0320-GUIONES
           IF ARCHIVO-EXISTE
               MOVE "OPEN INPUT" TO WS-OPERACION
               OPEN INPUT ARCH-CLIENTES
               IF NOT FS-OK
                   PERFORM 9000-ERROR-CLIENTES
               END-IF
               SET CLIENTES-ABIERTOS TO TRUE
               MOVE "N" TO WS-FIN-CLIENTES
               PERFORM 3100-LEER-Y-LISTAR-REACTIVADO
                   UNTIL FIN-DE-CLIENTES
               MOVE "CLOSE" TO WS-OPERACION
               CLOSE ARCH-CLIENTES
               IF NOT FS-OK
                   PERFORM 9000-ERROR-CLIENTES
               END-IF
               MOVE "N" TO WS-CLIENTES-ABIERTOS
           END-IF
           IF WS-CANT-REACTIVADOS = 0
               MOVE "No hay clientes en estado Reactivado (R)."
                   TO WS-LINEA
               PERFORM 0900-ESCRIBIR-LINEA
           END-IF
           PERFORM 0900-ESCRIBIR-LINEA.

       3100-LEER-Y-LISTAR-REACTIVADO.
           READ ARCH-CLIENTES NEXT RECORD
               AT END
                   SET FIN-DE-CLIENTES TO TRUE
               NOT AT END
                   PERFORM 3200-PROCESAR-REGISTRO-REACTIV
           END-READ
           IF NOT FS-OK AND NOT FS-FIN
               PERFORM 9000-ERROR-CLIENTES
           END-IF.

       3200-PROCESAR-REGISTRO-REACTIV.
           IF CLIENTE-REACTIVADO
               ADD 1 TO WS-CANT-REACTIVADOS
               PERFORM 6800-MOSTRAR-CLIENTE
           END-IF.

      ******************************************************************
      * Seccion 3: Clientes Inactivos (I).
      ******************************************************************
       4000-LISTAR-INACTIVOS.
           MOVE "Clientes Inactivos (I):" TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA
           PERFORM 0320-GUIONES
           IF ARCHIVO-EXISTE
               MOVE "OPEN INPUT" TO WS-OPERACION
               OPEN INPUT ARCH-CLIENTES
               IF NOT FS-OK
                   PERFORM 9000-ERROR-CLIENTES
               END-IF
               SET CLIENTES-ABIERTOS TO TRUE
               MOVE "N" TO WS-FIN-CLIENTES
               PERFORM 4100-LEER-Y-LISTAR-INACTIVO
                   UNTIL FIN-DE-CLIENTES
               MOVE "CLOSE" TO WS-OPERACION
               CLOSE ARCH-CLIENTES
               IF NOT FS-OK
                   PERFORM 9000-ERROR-CLIENTES
               END-IF
               MOVE "N" TO WS-CLIENTES-ABIERTOS
           END-IF
           IF WS-CANT-INACTIVOS = 0
               MOVE "No hay clientes en estado Inactivo (I)."
                   TO WS-LINEA
               PERFORM 0900-ESCRIBIR-LINEA
           END-IF
           PERFORM 0900-ESCRIBIR-LINEA.

       4100-LEER-Y-LISTAR-INACTIVO.
           READ ARCH-CLIENTES NEXT RECORD
               AT END
                   SET FIN-DE-CLIENTES TO TRUE
               NOT AT END
                   PERFORM 4200-PROCESAR-REGISTRO-INACTIVO
           END-READ
           IF NOT FS-OK AND NOT FS-FIN
               PERFORM 9000-ERROR-CLIENTES
           END-IF.

       4200-PROCESAR-REGISTRO-INACTIVO.
           IF CLIENTE-INACTIVO
               ADD 1 TO WS-CANT-INACTIVOS
               PERFORM 6800-MOSTRAR-CLIENTE
           END-IF.

      ******************************************************************
      * Resumen final: cantidad de clientes por estado (A, I, R),
      * cantidad total de clientes en el archivo, y saldo total de
      * la cartera (todos los clientes, sin importar el estado).
      ******************************************************************
       5000-ESCRIBIR-RESUMEN.
           PERFORM 0310-SEPARADOR
           MOVE "RESUMEN" TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA
           PERFORM 0310-SEPARADOR

           MOVE WS-CANT-ACTIVOS TO WS-CANT-EDIT
           STRING "Clientes Activos (A):        " WS-CANT-EDIT
               DELIMITED BY SIZE INTO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           MOVE WS-CANT-INACTIVOS TO WS-CANT-EDIT
           STRING "Clientes Inactivos (I):      " WS-CANT-EDIT
               DELIMITED BY SIZE INTO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           MOVE WS-CANT-REACTIVADOS TO WS-CANT-EDIT
           STRING "Clientes Reactivados (R):    " WS-CANT-EDIT
               DELIMITED BY SIZE INTO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           MOVE WS-CANT-TOTAL TO WS-CANT-EDIT
           STRING "Cantidad total de clientes:  " WS-CANT-EDIT
               DELIMITED BY SIZE INTO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           MOVE WS-SALDO-TOTAL TO WS-SALDO-TOTAL-EDIT
           STRING "Saldo total de la cartera: $ " WS-SALDO-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           PERFORM 0310-SEPARADOR.

      ******************************************************************
      * Muestra el detalle de un cliente (el que esta actualmente en
      * REG-CLIENTE): DNI, Nombre, Direccion, Telefono, Saldo y
      * Estado, uno por linea, mas una linea en blanco de separacion.
      ******************************************************************
       6800-MOSTRAR-CLIENTE.
           MOVE "DNI:       " TO WS-LC-ETIQUETA
           MOVE CLI-DNI TO WS-LC-VALOR
           MOVE WS-LINEA-CLIENTE TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           MOVE "Nombre:    " TO WS-LC-ETIQUETA
           MOVE FUNCTION TRIM(CLI-NOMBRE TRAILING) TO WS-LC-VALOR
           MOVE WS-LINEA-CLIENTE TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           MOVE "Direccion: " TO WS-LC-ETIQUETA
           MOVE FUNCTION TRIM(CLI-DIRECCION TRAILING) TO WS-LC-VALOR
           MOVE WS-LINEA-CLIENTE TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           MOVE "Telefono:  " TO WS-LC-ETIQUETA
           MOVE FUNCTION TRIM(CLI-TELEFONO TRAILING) TO WS-LC-VALOR
           MOVE WS-LINEA-CLIENTE TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           MOVE CLI-SALDO TO WS-SALDO-EDIT
           MOVE "Saldo:     " TO WS-LC-ETIQUETA
           MOVE WS-SALDO-EDIT TO WS-LC-VALOR
           MOVE WS-LINEA-CLIENTE TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           MOVE "Estado:    " TO WS-LC-ETIQUETA
           EVALUATE TRUE
               WHEN CLIENTE-ACTIVO
                   MOVE "A - Activo" TO WS-LC-VALOR
               WHEN CLIENTE-INACTIVO
                   MOVE "I - Inactivo" TO WS-LC-VALOR
               WHEN CLIENTE-REACTIVADO
                   MOVE "R - Reactivado" TO WS-LC-VALOR
               WHEN OTHER
                   MOVE "? - Desconocido" TO WS-LC-VALOR
           END-EVALUATE
           MOVE WS-LINEA-CLIENTE TO WS-LINEA
           PERFORM 0900-ESCRIBIR-LINEA

           PERFORM 0900-ESCRIBIR-LINEA.

      * Error de E/S inesperado sobre clientes_v3.dat: informa el
      * FILE STATUS, cierra lo que se pueda y termina el programa.
      * NOTA: como este programa solo lee (OPEN INPUT), este error
      * nunca puede deberse a un dato mal grabado por el listado.
       9000-ERROR-CLIENTES.
           DISPLAY "Error de archivo en clientes_v3.dat."
           DISPLAY "FILE STATUS: " WS-FS
           IF CLIENTES-ABIERTOS
               CLOSE ARCH-CLIENTES
           END-IF
           CLOSE ARCH-LISTADO
           MOVE 1 TO RETURN-CODE
           STOP RUN.

      * Error de E/S inesperado sobre listado_clientes.txt.
       9100-ERROR-LISTADO.
           DISPLAY "Error de archivo en listado_clientes.txt."
           DISPLAY "FILE STATUS: " WS-FS-LIS
           IF CLIENTES-ABIERTOS
               CLOSE ARCH-CLIENTES
           END-IF
           MOVE 1 TO RETURN-CODE
           STOP RUN.
