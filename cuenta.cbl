      ******************************************************************
      * PROGRAMA    : CUENTA
      * DESCRIPCION : Gestion simple de cuentas bancarias.
      *               Alta de cliente, deposito, extraccion y
      *               consulta de saldo, mediante un menu interactivo.
      * AUTOR       : EJEMPLO
      * FECHA       : 2026-09-21
      * NOTA       : Los datos viven solo en memoria (tabla); se
      *               pierden al terminar el programa.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUENTA.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. PC.
       OBJECT-COMPUTER. PC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

      * Opcion elegida en el menu
       01  WS-OPCION               PIC X      VALUE SPACE.
           88  OPC-ALTA                       VALUE "1".
           88  OPC-DEPOSITO                   VALUE "2".
           88  OPC-EXTRACCION                 VALUE "3".
           88  OPC-CONSULTA                   VALUE "4".
           88  OPC-SALIR                      VALUE "0".

      * Tabla de clientes (maximo 100)
       01  WS-MAX-CLIENTES         PIC 999    VALUE 100.
       01  WS-CANT-CLIENTES        PIC 999    VALUE 0.
       01  WS-TABLA-CLIENTES.
           05  WS-CLIENTE OCCURS 100 TIMES.
               10  CLI-DNI         PIC 9(8).
               10  CLI-NOMBRE      PIC X(30).
               10  CLI-SALDO       PIC S9(9)V99.

      * Campos de entrada (texto tal cual lo tipea el usuario)
       01  WS-DNI-TXT              PIC X(8).
       01  WS-MONTO-TXT            PIC X(15).
       01  WS-NOMBRE               PIC X(30).

      * Campos de trabajo
       01  WS-DNI                  PIC 9(8).
       01  WS-MONTO                PIC S9(9)V99.
       01  WS-IDX                  PIC 999.
       01  WS-POS                  PIC 999.
       01  WS-SALDO-EDIT           PIC -ZZZ,ZZZ,ZZ9.99.

      * Indicadores de validacion
       01  WS-DNI-OK               PIC X      VALUE "N".
           88  DNI-VALIDO                     VALUE "S".
           88  DNI-INVALIDO                   VALUE "N".
       01  WS-MONTO-OK             PIC X      VALUE "N".
           88  MONTO-VALIDO                   VALUE "S".
           88  MONTO-INVALIDO                 VALUE "N".

       PROCEDURE DIVISION.

      ******************************************************************
      * Programa principal: repite el menu hasta que se elige salir
      ******************************************************************
       0000-PRINCIPAL.
           PERFORM 1000-PROCESAR-MENU UNTIL OPC-SALIR
           DISPLAY "Hasta luego."
           STOP RUN.

       1000-PROCESAR-MENU.
           PERFORM 1100-MOSTRAR-MENU
           ACCEPT WS-OPCION
           EVALUATE TRUE
               WHEN OPC-ALTA       PERFORM 2000-ALTA-CLIENTE
               WHEN OPC-DEPOSITO   PERFORM 3000-DEPOSITO
               WHEN OPC-EXTRACCION PERFORM 4000-EXTRACCION
               WHEN OPC-CONSULTA   PERFORM 5000-CONSULTA-SALDO
               WHEN OPC-SALIR      CONTINUE
               WHEN OTHER          DISPLAY "Opcion invalida."
           END-EVALUATE.

       1100-MOSTRAR-MENU.
           DISPLAY " "
           DISPLAY "=== CUENTA BANCARIA ==="
           DISPLAY "1 - Alta de cliente"
           DISPLAY "2 - Deposito"
           DISPLAY "3 - Extraccion"
           DISPLAY "4 - Consulta de saldo"
           DISPLAY "0 - Salir"
           DISPLAY "Opcion: " WITH NO ADVANCING.

      ******************************************************************
      * 1 - Alta de cliente (saldo inicial en cero)
      ******************************************************************
       2000-ALTA-CLIENTE.
           IF WS-CANT-CLIENTES >= WS-MAX-CLIENTES
               DISPLAY "No hay lugar para mas clientes."
           ELSE
               PERFORM 8100-PEDIR-DNI
               IF DNI-VALIDO
                   PERFORM 8000-BUSCAR-CLIENTE
                   IF WS-POS > 0
                       DISPLAY "Ya existe un cliente con ese DNI."
                   ELSE
                       PERFORM 2100-REGISTRAR-CLIENTE
                   END-IF
               END-IF
           END-IF.

       2100-REGISTRAR-CLIENTE.
           DISPLAY "Nombre: " WITH NO ADVANCING
           ACCEPT WS-NOMBRE
           IF WS-NOMBRE = SPACES
               DISPLAY "El nombre no puede estar vacio."
           ELSE
               ADD 1 TO WS-CANT-CLIENTES
               MOVE WS-DNI    TO CLI-DNI(WS-CANT-CLIENTES)
               MOVE WS-NOMBRE TO CLI-NOMBRE(WS-CANT-CLIENTES)
               MOVE 0         TO CLI-SALDO(WS-CANT-CLIENTES)
               DISPLAY "Cliente dado de alta."
           END-IF.

      ******************************************************************
      * 2 - Deposito
      ******************************************************************
       3000-DEPOSITO.
           PERFORM 8100-PEDIR-DNI
           IF DNI-VALIDO
               PERFORM 8000-BUSCAR-CLIENTE
               IF WS-POS = 0
                   DISPLAY "No existe un cliente con ese DNI."
               ELSE
                   PERFORM 8200-PEDIR-MONTO
                   IF MONTO-VALIDO
                       ADD WS-MONTO TO CLI-SALDO(WS-POS)
                           ON SIZE ERROR
                               DISPLAY "El saldo excede el maximo."
                           NOT ON SIZE ERROR
                               PERFORM 8300-MOSTRAR-SALDO
                       END-ADD
                   END-IF
               END-IF
           END-IF.

      ******************************************************************
      * 3 - Extraccion (no permite quedar en descubierto)
      ******************************************************************
       4000-EXTRACCION.
           PERFORM 8100-PEDIR-DNI
           IF DNI-VALIDO
               PERFORM 8000-BUSCAR-CLIENTE
               IF WS-POS = 0
                   DISPLAY "No existe un cliente con ese DNI."
               ELSE
                   PERFORM 8200-PEDIR-MONTO
                   IF MONTO-VALIDO
                       IF WS-MONTO > CLI-SALDO(WS-POS)
                           DISPLAY "Saldo insuficiente."
                       ELSE
                           SUBTRACT WS-MONTO FROM CLI-SALDO(WS-POS)
                           PERFORM 8300-MOSTRAR-SALDO
                       END-IF
                   END-IF
               END-IF
           END-IF.

      ******************************************************************
      * 4 - Consulta de saldo
      ******************************************************************
       5000-CONSULTA-SALDO.
           PERFORM 8100-PEDIR-DNI
           IF DNI-VALIDO
               PERFORM 8000-BUSCAR-CLIENTE
               IF WS-POS = 0
                   DISPLAY "No existe un cliente con ese DNI."
               ELSE
                   DISPLAY "Cliente: " CLI-NOMBRE(WS-POS)
                   PERFORM 8300-MOSTRAR-SALDO
               END-IF
           END-IF.

      ******************************************************************
      * Rutinas auxiliares
      ******************************************************************

      * Busca WS-DNI en la tabla. Deja en WS-POS la posicion
      * encontrada, o 0 si no existe.
       8000-BUSCAR-CLIENTE.
           MOVE 0 TO WS-POS
           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-CANT-CLIENTES OR WS-POS > 0
               IF CLI-DNI(WS-IDX) = WS-DNI
                   MOVE WS-IDX TO WS-POS
               END-IF
           END-PERFORM.

      * Pide un DNI de exactamente 8 digitos.
       8100-PEDIR-DNI.
           SET DNI-INVALIDO TO TRUE
           DISPLAY "DNI (8 digitos): " WITH NO ADVANCING
           ACCEPT WS-DNI-TXT
           IF WS-DNI-TXT IS NUMERIC
               MOVE WS-DNI-TXT TO WS-DNI
               SET DNI-VALIDO TO TRUE
           ELSE
               DISPLAY "DNI invalido: deben ser 8 digitos."
           END-IF.

      * Pide un monto positivo (se admiten hasta 2 decimales).
       8200-PEDIR-MONTO.
           SET MONTO-INVALIDO TO TRUE
           DISPLAY "Monto: " WITH NO ADVANCING
           ACCEPT WS-MONTO-TXT
           COMPUTE WS-MONTO = FUNCTION NUMVAL(WS-MONTO-TXT)
               ON SIZE ERROR MOVE 0 TO WS-MONTO
           END-COMPUTE
           IF WS-MONTO > 0
               SET MONTO-VALIDO TO TRUE
           ELSE
               DISPLAY "Monto invalido: debe ser mayor a cero."
           END-IF.

       8300-MOSTRAR-SALDO.
           MOVE CLI-SALDO(WS-POS) TO WS-SALDO-EDIT
           DISPLAY "Saldo actual: " WS-SALDO-EDIT.
