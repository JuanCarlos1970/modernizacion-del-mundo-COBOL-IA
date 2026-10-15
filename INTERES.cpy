      ******************************************************************
      * COPYBOOK    : INTERES
      * DESCRIPCION : Layout del registro de tasas del archivo
      *               indexado intereses.dat (tabla de TNA por
      *               moneda y plazo, para Plazo Fijo). Lo incluye
      *               GESTION-BANCARIA, que da de alta, modifica y
      *               da de baja las tasas (menu INTERESES).
      * CLAVE       : INT-CLAVE = INT-MONEDA + INT-DIAS.
      * USO         : Se incluye con "COPY INTERES." inmediatamente
      *               despues de la clausula FD del archivo, en cada
      *               programa que lo necesite.
      * ADVERTENCIA : Si se cambia este layout, hay que recompilar
      *               TODOS los programas que lo incluyen y, salvo
      *               que el cambio agregue campos al final sin correr
      *               los existentes, cambiar tambien el nombre del
      *               archivo de datos (como se hizo con
      *               clientes_v3.dat).
      ******************************************************************
       01  REG-INTERES.
           05  INT-CLAVE.
      * P = pesos, D = dolares
               10  INT-MONEDA      PIC X.
                   88  MONEDA-PESOS           VALUE "P".
                   88  MONEDA-DOLARES         VALUE "D".
      * Plazo en dias: solo 30, 60, 90 o 120
               10  INT-DIAS        PIC 9(3).
      * Tasa nominal anual en porcentaje (45.50 = 45,50%)
           05  INT-TNA             PIC 9(3)V99.
      * Tasa que regia antes del ultimo cambio (cero en un alta
      * nueva o en una reactivacion)
           05  INT-TNA-ANTERIOR    PIC 9(3)V99.
      * Fecha desde la cual rige INT-TNA (AAAAMMDD)
           05  INT-VIGENTE-DESDE   PIC 9(8).
      * A = activa, B = baja logica (el registro no se borra)
           05  INT-ESTADO          PIC X.
               88  TASA-ACTIVA                VALUE "A".
               88  TASA-BAJA                  VALUE "B".
