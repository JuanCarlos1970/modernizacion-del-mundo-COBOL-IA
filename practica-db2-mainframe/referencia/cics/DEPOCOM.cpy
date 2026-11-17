      *================================================================
      * DEPOCOM - COMMAREA ENTRE DEPOPAN (PANTALLA) Y DEPOLOG (LOGICA)
      * DEPOPAN LLENA LA ENTRADA, HACE EXEC CICS LINK Y DEPOLOG
      * DEVUELVE LA SALIDA EN EL MISMO AREA.
      *
      * DC-RESULTADO (IGUAL A LOS CODIGOS DE DEPOSITO-DB2-BATCH):
      *   00 DEPOSITO APLICADO        05 CLIENTE NO ACTIVO
      *   01 DNI INVALIDO             06 EL SALDO EXCEDE EL MAXIMO
      *   03 MONTO EN CERO O NEGATIVO 07 -911/-913 SIN MAS REINTENTOS
      *   04 CLIENTE INEXISTENTE      09 ERROR SQL INESPERADO
      *================================================================
       01  DEPO-COMMAREA.
           05  DC-ENTRADA.
               10  DC-DNI          PIC 9(8).
               10  DC-MONTO        PIC S9(9)V99 COMP-3.
           05  DC-SALIDA.
               10  DC-RESULTADO    PIC 9(2).
               10  DC-NOMBRE       PIC X(30).
               10  DC-SALDO        PIC S9(9)V99 COMP-3.
               10  DC-SQLCODE      PIC S9(9) COMP.
