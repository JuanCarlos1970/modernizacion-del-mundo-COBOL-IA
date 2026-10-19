      ******************************************************************
      * COPYBOOK    : PLAZOFIJO
      * DESCRIPCION : Layout del registro del archivo indexado
      *               plazofijo.dat (plazos fijos constituidos). Lo
      *               incluye GESTION-BANCARIA, que da de alta,
      *               cancela y consulta plazos fijos (menu PLAZO
      *               FIJO), y BATCH-CIERRE, que procesa los
      *               vencimientos (Etapa 3).
      * CLAVE       : PF-NRO (numero correlativo, se asigna solo).
      * LARGO       : 79 bytes.
      * USO         : Se incluye con "COPY PLAZOFIJO." inmediatamente
      *               despues de la clausula FD del archivo, en cada
      *               programa que lo necesite.
      * ADVERTENCIA : Si se cambia este layout, hay que recompilar
      *               TODOS los programas que lo incluyen y, salvo
      *               que el cambio agregue campos al final sin correr
      *               los existentes, cambiar tambien el nombre del
      *               archivo de datos (como se hizo con
      *               clientes_v3.dat).
      ******************************************************************
       01  REG-PLAZOFIJO.
      * Numero de plazo fijo: el ultimo grabado + 1 (el primero es 1)
           05  PF-NRO              PIC 9(6).
      * Cliente titular (tiene que existir en clientes_v3.dat)
           05  PF-DNI              PIC 9(8).
      * P = pesos, D = dolares
           05  PF-MONEDA           PIC X.
               88  PF-MONEDA-PESOS            VALUE "P".
               88  PF-MONEDA-DOLARES          VALUE "D".
      * Capital constituido
           05  PF-MONTO            PIC 9(11)V99.
      * Plazo en dias: 30, 60, 90 o 120
           05  PF-DIAS             PIC 9(3).
      * Copia de la TNA vigente al momento del alta (asi un cambio
      * posterior en intereses.dat no altera este plazo fijo)
           05  PF-TNA-APLICADA     PIC 9(3)V99.
      * Interes = MONTO x TNA / 100 x DIAS / 365 (redondeado)
           05  PF-INTERES          PIC 9(11)V99.
      * Monto + interes
           05  PF-TOTAL            PIC 9(11)V99.
      * Fecha de proceso del alta y fecha de vencimiento (alta + dias),
      * ambas AAAAMMDD
           05  PF-FECHA-ALTA       PIC 9(8).
           05  PF-FECHA-VENC       PIC 9(8).
      * A = activo, C = cancelado, V = vencido y acreditado (Etapa 3)
           05  PF-ESTADO           PIC X.
               88  PF-ACTIVO                  VALUE "A".
               88  PF-CANCELADO               VALUE "C".
               88  PF-VENCIDO                 VALUE "V".
