      ******************************************************************
      * COPYBOOK    : CLIENTE
      * DESCRIPCION : Layout del registro de cliente del archivo
      *               indexado clientes_v3.dat. Lo comparten CUENTA
      *               (programa interactivo) y BATCH-CIERRE (proceso
      *               batch nocturno) para garantizar que ambos leen
      *               y escriben el archivo con el MISMO formato.
      * USO         : Se incluye con "COPY CLIENTE." inmediatamente
      *               despues de la clausula FD del archivo, en cada
      *               programa que lo necesite.
      * ADVERTENCIA : Si se cambia este layout, hay que recompilar
      *               TODOS los programas que lo incluyen (CUENTA y
      *               BATCH-CIERRE) y, salvo que el cambio agregue
      *               campos al final sin correr los existentes,
      *               cambiar tambien el nombre del archivo de datos
      *               (ver la nota de versionado en cuenta.cbl).
      ******************************************************************
       01  REG-CLIENTE.
           05  CLI-DNI             PIC 9(8).
           05  CLI-NOMBRE          PIC X(30).
           05  CLI-DIRECCION       PIC X(40).
           05  CLI-TELEFONO        PIC X(15).
           05  CLI-SALDO           PIC S9(9)V99.
           05  CLI-ESTADO          PIC X.
               88  CLIENTE-ACTIVO             VALUE "A".
               88  CLIENTE-INACTIVO           VALUE "I".
               88  CLIENTE-REACTIVADO         VALUE "R".
