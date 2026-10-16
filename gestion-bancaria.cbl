      ******************************************************************
      * PROGRAMA    : GESTION-BANCARIA
      * DESCRIPCION : Gestion simple de cuentas bancarias.
      *               Alta, modificacion y baja logica de clientes,
      *               deposito, extraccion y consulta de saldo,
      *               mediante un menu interactivo.
      * AUTOR       : JuanKa
      * FECHA       : 2026-09-21
      * NOTA        : Los clientes se guardan en un archivo indexado
      *               (clientes_v3.dat, clave = DNI) y persisten entre
      *               ejecuciones. Si el archivo no existe, se crea.
      *               La baja es logica: el cliente pasa a estado I
      *               (Inactivo) y su registro NO se elimina. Un
      *               cliente inactivo se puede reactivar (estado R).
      *               Las tasas de interes (TNA por moneda y plazo)
      *               se guardan en otro archivo indexado,
      *               intereses.dat (clave = moneda + dias), en la
      *               misma carpeta que clientes_v3.dat.
      *               La fecha de proceso es la del sistema, salvo que
      *               exista la variable de entorno FECHA_PROCESO
      *               (AAAAMMDD), que se usa para fijarla en pruebas.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. GESTION-BANCARIA.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. PC.
       OBJECT-COMPUTER. PC.
       SPECIAL-NAMES.
           CLASS CLASE-TELEFONO IS "0" THRU "9" "+" "-" "(" ")" " ".

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
      * El nombre lleva _v3 porque el layout del registro cambio (se
      * agrego el campo Estado). GnuCOBOL no verifica el largo del
      * registro al abrir: un archivo con el layout anterior se
      * leeria como basura. Con otro nombre, el viejo se ignora.
           SELECT ARCH-CLIENTES ASSIGN TO "clientes_v3.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS CLI-DNI
               FILE STATUS IS WS-FS.

      * Tabla de tasas (menu INTERESES). Mismo patron que
      * clientes_v3.dat: nombre sin carpeta, asi queda en la carpeta
      * desde donde se ejecuta el programa (bin\).
           SELECT ARCH-INTERESES ASSIGN TO "intereses.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS INT-CLAVE
               FILE STATUS IS WS-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARCH-CLIENTES.
      * Layout del registro compartido con BATCH-CIERRE (ver
      * CLIENTE.cpy). Cambiarlo aqui tambien cambia BATCH-CIERRE:
      * ambos programas se recompilan siempre juntos.
           COPY CLIENTE.

       FD  ARCH-INTERESES.
      * Layout del registro de tasas (ver INTERES.cpy).
           COPY INTERES.

       WORKING-STORAGE SECTION.

      * Opcion elegida en el menu principal. Ocupa 2 caracteres
      * porque hay una opcion "10"; una opcion de un digito queda
      * como "1 " y se compara igual contra "1".
       01  WS-OPCION               PIC X(2)   VALUE SPACES.
           88  OPC-ALTA                       VALUE "1".
           88  OPC-MODIF-BAJA                 VALUE "2".
           88  OPC-DEPOSITO                   VALUE "3".
           88  OPC-EXTRACCION                 VALUE "4".
           88  OPC-CONSULTA                   VALUE "5".
           88  OPC-CTA-CTE-CAJA               VALUE "6".
           88  OPC-PLAZO-FIJO                 VALUE "7".
           88  OPC-INTERESES                  VALUE "8".
           88  OPC-HISTORIAL                  VALUE "9".
           88  OPC-PAGO-SERVICIOS             VALUE "10".
           88  OPC-SALIR                      VALUE "0".

      * Opcion elegida en el submenu INTERESES
       01  WS-OPC-INT              PIC X      VALUE SPACE.
           88  OPI-ALTA                       VALUE "1".
           88  OPI-MODIFICACION               VALUE "2".
           88  OPI-BAJA                       VALUE "3".
           88  OPI-VOLVER                     VALUE "4".

      * Respuesta a "Modificar o Baja" (opcion 2 del menu principal)
       01  WS-OPC-MB               PIC X      VALUE SPACE.
           88  MB-MODIFICAR                   VALUE "M" "m".
           88  MB-BAJA                        VALUE "B" "b".

      * Respuesta S/N: solo confirmacion de baja
       01  WS-CONFIRMA             PIC X      VALUE SPACE.
           88  CONFIRMA-SI                    VALUE "S" "s".

      * Opcion elegida en el submenu de modificacion de datos
       01  WS-OPC-MOD              PIC X      VALUE SPACE.
           88  MOD-DIRECCION                  VALUE "1".
           88  MOD-TELEFONO                   VALUE "2".
           88  MOD-SALDO                      VALUE "3".
           88  MOD-TERMINAR                   VALUE "4".

      * Cantidad de datos modificados en la pasada actual
       01  WS-CAMBIOS              PIC 9      VALUE 0.

      * Estado de la ultima operacion sobre el archivo
       01  WS-FS                   PIC XX     VALUE "00".
           88  FS-OK                          VALUE "00".
           88  FS-CLAVE-DUPLICADA             VALUE "22".
           88  FS-CLAVE-NO-ENC                VALUE "23".
           88  FS-NO-EXISTE                   VALUE "35".
      * Nombre de la operacion en curso, para informar el error
       01  WS-OPERACION            PIC X(10)  VALUE SPACES.
      * Archivo sobre el que se hace la operacion en curso
       01  WS-ARCHIVO              PIC X(16)  VALUE SPACES.

      * Campos de entrada (texto tal cual lo tipea el usuario)
       01  WS-DNI-TXT              PIC X(8).
       01  WS-MONTO-TXT            PIC X(15).
       01  WS-TEXTO                PIC X(80).

      * Campos de trabajo
       01  WS-DNI                  PIC 9(8).
       01  WS-MONTO                PIC S9(9)V99.
       01  WS-SALDO-NUEVO          PIC S9(9)V99.
       01  WS-NOMBRE               PIC X(30).
       01  WS-DIRECCION            PIC X(40).
       01  WS-TELEFONO             PIC X(15).
       01  WS-I                    PIC 99.
       01  WS-CANT-DIG             PIC 99.
       01  WS-SALDO-EDIT           PIC -ZZZ,ZZZ,ZZ9.99.

      * Campos de trabajo de INTERESES
       01  WS-MONEDA               PIC X.
       01  WS-DIAS                 PIC 9(3).
       01  WS-TNA                  PIC 9(3)V99.
      * La TNA tipeada, con decimales de sobra para detectar si
      * tiene mas de 2 (al pasarla a WS-TNA se perderian sin aviso)
       01  WS-TNA-CALC             PIC S9(5)V9(6).
       01  WS-DIAS-EDIT            PIC ZZ9.
       01  WS-TNA-EDIT             PIC ZZ9.99.

      * Fechas. WS-FECHA-PROCESO es "hoy" para el programa: sale
      * del sistema o de la variable de entorno FECHA_PROCESO.
       01  WS-FECHA-ENV            PIC X(20).
       01  WS-FECHA-HORA           PIC X(21).
       01  WS-FECHA-PROCESO        PIC 9(8).
       01  WS-PROX-HABIL           PIC 9(8).
      * Numero de dia (1 = 01/01/1601, que fue lunes)
       01  WS-FECHA-INT            PIC 9(7).
      * Resto de dividir por 7: 1 = lunes ... 6 = sabado, 0 = domingo
       01  WS-DIA-SEMANA           PIC 9.
      * Fecha a mostrar (AAAAMMDD) y su version DD/MM/AAAA
       01  WS-FECHA-AUX            PIC 9(8).
       01  WS-FECHA-AUX-R REDEFINES WS-FECHA-AUX.
           05  WS-FA-ANIO          PIC 9(4).
           05  WS-FA-MES           PIC 99.
           05  WS-FA-DIA           PIC 99.
       01  WS-FECHA-EDIT           PIC X(10).

      * Indicadores de validacion / busqueda
       01  WS-DNI-OK               PIC X      VALUE "N".
           88  DNI-VALIDO                     VALUE "S".
           88  DNI-INVALIDO                   VALUE "N".
       01  WS-MONTO-OK             PIC X      VALUE "N".
           88  MONTO-VALIDO                   VALUE "S".
           88  MONTO-INVALIDO                 VALUE "N".
       01  WS-CAMPO-OK             PIC X      VALUE "N".
           88  CAMPO-VALIDO                   VALUE "S".
           88  CAMPO-INVALIDO                 VALUE "N".
       01  WS-ENCONTRADO           PIC X      VALUE "N".
           88  CLIENTE-ENCONTRADO             VALUE "S".
           88  CLIENTE-NO-ENC                 VALUE "N".
       01  WS-OPERABLE             PIC X      VALUE "N".
           88  CLIENTE-OPERABLE               VALUE "S".
           88  CLIENTE-NO-OPERABLE            VALUE "N".
       01  WS-TASA-ENC             PIC X      VALUE "N".
           88  TASA-ENCONTRADA                VALUE "S".
           88  TASA-NO-ENC                    VALUE "N".

       PROCEDURE DIVISION.

      ******************************************************************
      * Programa principal: abre los archivos, repite el menu hasta
      * que se elige salir y cierra los archivos
      ******************************************************************
       0000-PRINCIPAL.
           PERFORM 0100-ABRIR-ARCHIVO
           PERFORM 0150-ABRIR-INTERESES
           PERFORM 1000-PROCESAR-MENU UNTIL OPC-SALIR
           PERFORM 0200-CERRAR-ARCHIVO
           PERFORM 0250-CERRAR-INTERESES
           DISPLAY "Hasta luego."
           STOP RUN.

      * Abre el archivo para lectura/escritura. Si todavia no existe
      * (FILE STATUS 35) lo crea vacio y lo vuelve a abrir.
       0100-ABRIR-ARCHIVO.
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           MOVE "OPEN I-O" TO WS-OPERACION
           OPEN I-O ARCH-CLIENTES
           IF FS-NO-EXISTE
               MOVE "OPEN OUT" TO WS-OPERACION
               OPEN OUTPUT ARCH-CLIENTES
               IF NOT FS-OK
                   PERFORM 9000-ERROR-ARCHIVO
               END-IF
               MOVE "CLOSE" TO WS-OPERACION
               CLOSE ARCH-CLIENTES
               IF NOT FS-OK
                   PERFORM 9000-ERROR-ARCHIVO
               END-IF
               MOVE "OPEN I-O" TO WS-OPERACION
               OPEN I-O ARCH-CLIENTES
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       0200-CERRAR-ARCHIVO.
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           MOVE "CLOSE" TO WS-OPERACION
           CLOSE ARCH-CLIENTES
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Igual que 0100-ABRIR-ARCHIVO, pero para intereses.dat.
       0150-ABRIR-INTERESES.
           MOVE "intereses.dat" TO WS-ARCHIVO
           MOVE "OPEN I-O" TO WS-OPERACION
           OPEN I-O ARCH-INTERESES
           IF FS-NO-EXISTE
               MOVE "OPEN OUT" TO WS-OPERACION
               OPEN OUTPUT ARCH-INTERESES
               IF NOT FS-OK
                   PERFORM 9000-ERROR-ARCHIVO
               END-IF
               MOVE "CLOSE" TO WS-OPERACION
               CLOSE ARCH-INTERESES
               IF NOT FS-OK
                   PERFORM 9000-ERROR-ARCHIVO
               END-IF
               MOVE "OPEN I-O" TO WS-OPERACION
               OPEN I-O ARCH-INTERESES
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       0250-CERRAR-INTERESES.
           MOVE "intereses.dat" TO WS-ARCHIVO
           MOVE "CLOSE" TO WS-OPERACION
           CLOSE ARCH-INTERESES
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       1000-PROCESAR-MENU.
           PERFORM 1100-MOSTRAR-MENU
           ACCEPT WS-OPCION
      * Si la entrada llega con fin de linea de Windows (CRLF) a un
      * programa compilado en Linux, el CR (X"0D") queda en el
      * segundo caracter ("0" + CR no es "0" y no se podria salir).
           INSPECT WS-OPCION REPLACING ALL X"0D" BY SPACE
           EVALUATE TRUE
               WHEN OPC-ALTA        PERFORM 2000-ALTA-CLIENTE
               WHEN OPC-MODIF-BAJA  PERFORM 2500-MODIFICAR-O-BAJA
               WHEN OPC-DEPOSITO    PERFORM 3000-DEPOSITO
               WHEN OPC-EXTRACCION  PERFORM 4000-EXTRACCION
               WHEN OPC-CONSULTA    PERFORM 5000-CONSULTA-SALDO
               WHEN OPC-INTERESES   PERFORM 5500-INTERESES
               WHEN OPC-CTA-CTE-CAJA
               WHEN OPC-PLAZO-FIJO
               WHEN OPC-HISTORIAL
               WHEN OPC-PAGO-SERVICIOS
                                    DISPLAY "Opcion en desarrollo."
               WHEN OPC-SALIR       CONTINUE
               WHEN OTHER           DISPLAY "Opcion invalida."
           END-EVALUATE.

      * Solo presentacion: lineas en blanco y sangria con espacios.
      * Las opciones 1 a 10 van en un solo bloque; el "10" lleva un
      * espacio menos de sangria para que los guiones queden
      * alineados.
       1100-MOSTRAR-MENU.
           DISPLAY " "
           DISPLAY "  ======================================"
           DISPLAY "             GESTION BANCARIA"
           DISPLAY "  ======================================"
           DISPLAY " "
           DISPLAY "     1 - Alta de cliente"
           DISPLAY "     2 - Modificar / Baja de cliente"
           DISPLAY "     3 - Deposito"
           DISPLAY "     4 - Extraccion"
           DISPLAY "     5 - Consulta de saldo"
           DISPLAY "     6 - Cuenta corriente / Caja de ahorro"
           DISPLAY "     7 - Plazo fijo"
           DISPLAY "     8 - Intereses"
           DISPLAY "     9 - Historial de movimientos"
           DISPLAY "    10 - Pago de servicios"
           DISPLAY " "
           DISPLAY "     0 - Salir"
           DISPLAY " "
           DISPLAY "  Opcion: " WITH NO ADVANCING.

      ******************************************************************
      * 1 - Alta de cliente (saldo inicial en cero, estado A)
      ******************************************************************
       2000-ALTA-CLIENTE.
           PERFORM 8100-PEDIR-DNI
           IF DNI-VALIDO
               PERFORM 8000-BUSCAR-CLIENTE
               IF CLIENTE-ENCONTRADO
                   DISPLAY "Ya existe un cliente con ese DNI."
               ELSE
                   PERFORM 2100-REGISTRAR-CLIENTE
               END-IF
           END-IF.

      * Pide nombre, direccion y telefono (en ese orden). Si algun
      * dato es invalido se cancela el alta y no se graba nada.
       2100-REGISTRAR-CLIENTE.
           PERFORM 8500-PEDIR-NOMBRE
           IF CAMPO-VALIDO
               MOVE WS-NOMBRE TO CLI-NOMBRE
               PERFORM 8600-PEDIR-DIRECCION
           END-IF
           IF CAMPO-VALIDO
               MOVE WS-DIRECCION TO CLI-DIRECCION
               PERFORM 8700-PEDIR-TELEFONO
           END-IF
           IF CAMPO-VALIDO
               MOVE WS-TELEFONO TO CLI-TELEFONO
               PERFORM 2200-GRABAR-CLIENTE
           ELSE
               DISPLAY "Alta cancelada."
           END-IF.

      * Todo cliente nuevo nace con saldo 0 y estado A (Activo).
       2200-GRABAR-CLIENTE.
           MOVE WS-DNI TO CLI-DNI
           MOVE 0      TO CLI-SALDO
           SET CLIENTE-ACTIVO TO TRUE
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-CLIENTE
               INVALID KEY
                   DISPLAY "Ya existe un cliente con ese DNI."
               NOT INVALID KEY
                   DISPLAY "Cliente dado de alta."
           END-WRITE
           IF NOT FS-OK AND NOT FS-CLAVE-DUPLICADA
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      ******************************************************************
      * 2 - Modificar / Baja de cliente.
      *     1) pide el DNI  2) si no existe: "Cliente no encontrado."
      *     3) si existe, muestra todos sus datos  4) recien ahi
      *     pregunta si desea Modificar o dar de Baja.
      ******************************************************************
       2500-MODIFICAR-O-BAJA.
           PERFORM 8100-PEDIR-DNI
           IF DNI-VALIDO
               PERFORM 8000-BUSCAR-CLIENTE
               IF CLIENTE-NO-ENC
                   DISPLAY "Cliente no encontrado."
               ELSE
                   PERFORM 8800-MOSTRAR-CLIENTE
                   PERFORM 2600-ELEGIR-MODIF-O-BAJA
               END-IF
           END-IF.

      * Cualquier respuesta distinta de M o B se rechaza y se vuelve
      * al menu principal.
       2600-ELEGIR-MODIF-O-BAJA.
           DISPLAY "Desea (M)odificar o (B)aja el cliente? "
               WITH NO ADVANCING
           ACCEPT WS-OPC-MB
           EVALUATE TRUE
               WHEN MB-MODIFICAR  PERFORM 6000-MODIFICACION
               WHEN MB-BAJA       PERFORM 7000-BAJA-CLIENTE
               WHEN OTHER         DISPLAY "Opcion invalida: use M o B."
           END-EVALUATE.

      ******************************************************************
      * 3 - Deposito (clientes A o R; se bloquea si el estado es I)
      ******************************************************************
       3000-DEPOSITO.
           PERFORM 8100-PEDIR-DNI
           IF DNI-VALIDO
               PERFORM 8000-BUSCAR-CLIENTE
               IF CLIENTE-NO-ENC
                   DISPLAY "Cliente no encontrado."
               ELSE
                   PERFORM 8900-VERIFICAR-ACTIVO
                   IF CLIENTE-OPERABLE
                       PERFORM 3100-PROCESAR-DEPOSITO
                   END-IF
               END-IF
           END-IF.

       3100-PROCESAR-DEPOSITO.
           PERFORM 8200-PEDIR-MONTO
           IF MONTO-VALIDO
               ADD WS-MONTO TO CLI-SALDO
                   ON SIZE ERROR
                       DISPLAY "El saldo excede el maximo."
                   NOT ON SIZE ERROR
                       PERFORM 8400-ACTUALIZAR-CLIENTE
                       PERFORM 8300-MOSTRAR-SALDO
               END-ADD
           END-IF.

      ******************************************************************
      * 4 - Extraccion (clientes A o R; sin descubierto)
      ******************************************************************
       4000-EXTRACCION.
           PERFORM 8100-PEDIR-DNI
           IF DNI-VALIDO
               PERFORM 8000-BUSCAR-CLIENTE
               IF CLIENTE-NO-ENC
                   DISPLAY "Cliente no encontrado."
               ELSE
                   PERFORM 8900-VERIFICAR-ACTIVO
                   IF CLIENTE-OPERABLE
                       PERFORM 4100-PROCESAR-EXTRACCION
                   END-IF
               END-IF
           END-IF.

       4100-PROCESAR-EXTRACCION.
           PERFORM 8200-PEDIR-MONTO
           IF MONTO-VALIDO
               IF WS-MONTO > CLI-SALDO
                   DISPLAY "Saldo insuficiente."
               ELSE
                   SUBTRACT WS-MONTO FROM CLI-SALDO
                   PERFORM 8400-ACTUALIZAR-CLIENTE
                   PERFORM 8300-MOSTRAR-SALDO
               END-IF
           END-IF.

      ******************************************************************
      * 5 - Consulta de saldo (muestra todos los datos del cliente,
      *     activo o inactivo)
      ******************************************************************
       5000-CONSULTA-SALDO.
           PERFORM 8100-PEDIR-DNI
           IF DNI-VALIDO
               PERFORM 8000-BUSCAR-CLIENTE
               IF CLIENTE-NO-ENC
                   DISPLAY "Cliente no encontrado."
               ELSE
                   PERFORM 8800-MOSTRAR-CLIENTE
               END-IF
           END-IF.

      ******************************************************************
      * 8 - Intereses: tabla de TNA por moneda (P/D) y plazo (30, 60,
      *     90 o 120 dias). Toda tasa que se carga o modifica rige
      *     desde el PROXIMO DIA HABIL (lunes a viernes, sin contar
      *     feriados). La baja es logica (estado B) y rige de
      *     inmediato. Al elegir 4 se vuelve al menu principal.
      ******************************************************************
       5500-INTERESES.
           PERFORM 8050-FIJAR-FECHA-PROCESO
           MOVE SPACE TO WS-OPC-INT
           PERFORM 5510-MENU-INTERESES UNTIL OPI-VOLVER.

      * Mismo formato que 1100-MOSTRAR-MENU (solo presentacion).
       5510-MENU-INTERESES.
           MOVE WS-FECHA-PROCESO TO WS-FECHA-AUX
           PERFORM 8070-EDITAR-FECHA
           DISPLAY " "
           DISPLAY "  ======================================"
           DISPLAY "                INTERESES"
           DISPLAY "  ======================================"
           DISPLAY " "
           DISPLAY "  Fecha de proceso: " WS-FECHA-EDIT
           DISPLAY " "
           DISPLAY "     1 - Alta"
           DISPLAY "     2 - Modificacion"
           DISPLAY "     3 - Baja"
           DISPLAY " "
           DISPLAY "     4 - Volver"
           DISPLAY " "
           DISPLAY "  Opcion: " WITH NO ADVANCING
           ACCEPT WS-OPC-INT
           EVALUATE TRUE
               WHEN OPI-ALTA          PERFORM 5600-ALTA-TASA
               WHEN OPI-MODIFICACION  PERFORM 5700-MODIFICAR-TASA
               WHEN OPI-BAJA          PERFORM 5800-BAJA-TASA
               WHEN OPI-VOLVER        CONTINUE
               WHEN OTHER             DISPLAY "Opcion invalida."
           END-EVALUATE.

      * 8/1 - Alta. Si la combinacion moneda + dias ya existe:
      *   - activa (A): avisa y no la toca (no pide la TNA).
      *   - en baja (B): la reactiva con la TNA nueva.
      * En el alta y en la reactivacion: TNA-ANTERIOR en cero y
      * VIGENTE-DESDE = proximo dia habil.
       5600-ALTA-TASA.
           PERFORM 5910-PEDIR-MONEDA
           PERFORM 5920-PEDIR-DIAS
           PERFORM 5940-BUSCAR-TASA
           IF TASA-ENCONTRADA AND TASA-ACTIVA
               DISPLAY "Ya existe una tasa activa para esa moneda"
               DISPLAY "y plazo. No se modifico nada."
               PERFORM 5960-MOSTRAR-TASA
           ELSE
               PERFORM 5930-PEDIR-TNA
               PERFORM 8060-CALCULAR-PROX-HABIL
               MOVE WS-MONEDA     TO INT-MONEDA
               MOVE WS-DIAS       TO INT-DIAS
               MOVE WS-TNA        TO INT-TNA
               MOVE 0             TO INT-TNA-ANTERIOR
               MOVE WS-PROX-HABIL TO INT-VIGENTE-DESDE
               SET TASA-ACTIVA TO TRUE
               IF TASA-ENCONTRADA
                   PERFORM 5955-ACTUALIZAR-TASA
                   DISPLAY "Tasa reactivada (estaba dada de baja)."
               ELSE
                   PERFORM 5950-GRABAR-TASA-NUEVA
                   DISPLAY "Tasa dada de alta."
               END-IF
               PERFORM 5960-MOSTRAR-TASA
           END-IF.

      * 8/2 - Modificacion de la TNA de una combinacion activa.
      * Si la tasa actual ya esta vigente (fecha de proceso igual o
      * posterior a VIGENTE-DESDE) pasa a TNA-ANTERIOR. Si todavia
      * no estaba vigente (cambio pendiente), TNA-ANTERIOR no se
      * toca: sigue guardando la tasa que rige hoy.
       5700-MODIFICAR-TASA.
           PERFORM 5910-PEDIR-MONEDA
           PERFORM 5920-PEDIR-DIAS
           PERFORM 5940-BUSCAR-TASA
           EVALUATE TRUE
               WHEN TASA-NO-ENC
                   DISPLAY "No existe una tasa para esa moneda y plazo."
               WHEN TASA-BAJA
                   DISPLAY "La tasa esta dada de baja."
                   DISPLAY "Use la opcion 1 - Alta para reactivarla."
               WHEN OTHER
                   DISPLAY "Tasa actual:"
                   PERFORM 5960-MOSTRAR-TASA
                   PERFORM 5930-PEDIR-TNA
                   IF WS-FECHA-PROCESO >= INT-VIGENTE-DESDE
                       MOVE INT-TNA TO INT-TNA-ANTERIOR
                   END-IF
                   PERFORM 8060-CALCULAR-PROX-HABIL
                   MOVE WS-TNA        TO INT-TNA
                   MOVE WS-PROX-HABIL TO INT-VIGENTE-DESDE
                   PERFORM 5955-ACTUALIZAR-TASA
                   DISPLAY "Tasa modificada."
                   PERFORM 5960-MOSTRAR-TASA
           END-EVALUATE.

      * 8/3 - Baja logica: estado B, rige de inmediato. El registro
      * no se borra y VIGENTE-DESDE no cambia.
       5800-BAJA-TASA.
           PERFORM 5910-PEDIR-MONEDA
           PERFORM 5920-PEDIR-DIAS
           PERFORM 5940-BUSCAR-TASA
           EVALUATE TRUE
               WHEN TASA-NO-ENC
                   DISPLAY "No existe una tasa para esa moneda y plazo."
               WHEN TASA-BAJA
                   DISPLAY "La tasa ya esta dada de baja."
               WHEN OTHER
                   SET TASA-BAJA TO TRUE
                   PERFORM 5955-ACTUALIZAR-TASA
                   DISPLAY "Tasa dada de baja."
                   PERFORM 5960-MOSTRAR-TASA
           END-EVALUATE.

      * Pide la moneda hasta que sea P o D (acepta minusculas).
       5910-PEDIR-MONEDA.
           SET CAMPO-INVALIDO TO TRUE
           PERFORM UNTIL CAMPO-VALIDO
               DISPLAY "Moneda (P = pesos, D = dolares): "
                   WITH NO ADVANCING
               ACCEPT WS-TEXTO
               INSPECT WS-TEXTO REPLACING ALL X"0D" BY SPACE
               MOVE FUNCTION UPPER-CASE(FUNCTION TRIM(WS-TEXTO))
                   TO WS-TEXTO
               IF WS-TEXTO = "P" OR WS-TEXTO = "D"
                   MOVE WS-TEXTO(1:1) TO WS-MONEDA
                   SET CAMPO-VALIDO TO TRUE
               ELSE
                   DISPLAY "Moneda invalida: ingrese P o D."
               END-IF
           END-PERFORM.

      * Pide el plazo hasta que sea 30, 60, 90 o 120.
       5920-PEDIR-DIAS.
           SET CAMPO-INVALIDO TO TRUE
           PERFORM UNTIL CAMPO-VALIDO
               DISPLAY "Dias (30, 60, 90 o 120): " WITH NO ADVANCING
               ACCEPT WS-TEXTO
               INSPECT WS-TEXTO REPLACING ALL X"0D" BY SPACE
               MOVE FUNCTION TRIM(WS-TEXTO) TO WS-TEXTO
               IF WS-TEXTO = "30" OR WS-TEXTO = "60"
                  OR WS-TEXTO = "90" OR WS-TEXTO = "120"
                   COMPUTE WS-DIAS = FUNCTION NUMVAL(WS-TEXTO)
                   SET CAMPO-VALIDO TO TRUE
               ELSE
                   DISPLAY "Dias invalidos: ingrese 30, 60, 90 o 120."
               END-IF
           END-PERFORM.

      * Pide la TNA hasta que sea un numero mayor que 0, de hasta
      * 999.99 (lo maximo que entra en 9(3)V99) y con hasta 2
      * decimales. Como en el monto, se usa el punto decimal.
       5930-PEDIR-TNA.
           SET CAMPO-INVALIDO TO TRUE
           PERFORM UNTIL CAMPO-VALIDO
               DISPLAY "TNA en % (mayor que 0, hasta 999.99): "
                   WITH NO ADVANCING
               ACCEPT WS-MONTO-TXT
               INSPECT WS-MONTO-TXT REPLACING ALL X"0D" BY SPACE
               IF WS-MONTO-TXT = SPACES
                   DISPLAY "La TNA no puede estar vacia."
               ELSE
                   IF FUNCTION TEST-NUMVAL(WS-MONTO-TXT) NOT = 0
                       DISPLAY "TNA invalida: ingrese un numero."
                   ELSE
                       COMPUTE WS-TNA-CALC =
                           FUNCTION NUMVAL(WS-MONTO-TXT)
                           ON SIZE ERROR
                               DISPLAY "TNA invalida: maximo 999.99."
                           NOT ON SIZE ERROR
                               PERFORM 5935-VALIDAR-TNA
                       END-COMPUTE
                   END-IF
               END-IF
           END-PERFORM.

       5935-VALIDAR-TNA.
           EVALUATE TRUE
               WHEN WS-TNA-CALC NOT > 0
                   DISPLAY "TNA invalida: debe ser mayor que 0."
               WHEN WS-TNA-CALC > 999.99
                   DISPLAY "TNA invalida: maximo 999.99."
               WHEN OTHER
                   MOVE WS-TNA-CALC TO WS-TNA
                   IF WS-TNA NOT = WS-TNA-CALC
                       DISPLAY "TNA invalida: maximo 2 decimales."
                   ELSE
                       SET CAMPO-VALIDO TO TRUE
                   END-IF
           END-EVALUATE.

      * Lee la tasa con clave WS-MONEDA + WS-DIAS. Si existe, sus
      * datos quedan en REG-INTERES y TASA-ENCONTRADA es verdadero.
       5940-BUSCAR-TASA.
           SET TASA-NO-ENC TO TRUE
           MOVE WS-MONEDA TO INT-MONEDA
           MOVE WS-DIAS   TO INT-DIAS
           MOVE "intereses.dat" TO WS-ARCHIVO
           MOVE "READ" TO WS-OPERACION
           READ ARCH-INTERESES KEY IS INT-CLAVE
               INVALID KEY
                   SET TASA-NO-ENC TO TRUE
               NOT INVALID KEY
                   SET TASA-ENCONTRADA TO TRUE
           END-READ
           IF NOT FS-OK AND NOT FS-CLAVE-NO-ENC
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       5950-GRABAR-TASA-NUEVA.
           MOVE "intereses.dat" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-INTERES
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       5955-ACTUALIZAR-TASA.
           MOVE "intereses.dat" TO WS-ARCHIVO
           MOVE "REWRITE" TO WS-OPERACION
           REWRITE REG-INTERES
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Muestra todos los datos de la tasa que esta en REG-INTERES.
       5960-MOSTRAR-TASA.
           EVALUATE TRUE
               WHEN MONEDA-PESOS
                   DISPLAY "Moneda:        P - Pesos"
               WHEN MONEDA-DOLARES
                   DISPLAY "Moneda:        D - Dolares"
               WHEN OTHER
                   DISPLAY "Moneda:        ? - Desconocida"
           END-EVALUATE
           MOVE INT-DIAS TO WS-DIAS-EDIT
           DISPLAY "Dias:          " FUNCTION TRIM(WS-DIAS-EDIT)
           MOVE INT-TNA TO WS-TNA-EDIT
           DISPLAY "TNA:           " FUNCTION TRIM(WS-TNA-EDIT) " %"
           MOVE INT-TNA-ANTERIOR TO WS-TNA-EDIT
           DISPLAY "TNA anterior:  " FUNCTION TRIM(WS-TNA-EDIT) " %"
           MOVE INT-VIGENTE-DESDE TO WS-FECHA-AUX
           PERFORM 8070-EDITAR-FECHA
           DISPLAY "Vigente desde: " WS-FECHA-EDIT
           EVALUATE TRUE
               WHEN TASA-ACTIVA
                   DISPLAY "Estado:        A - Activa"
               WHEN TASA-BAJA
                   DISPLAY "Estado:        B - Baja"
               WHEN OTHER
                   DISPLAY "Estado:        ? - Desconocido"
           END-EVALUATE.

      ******************************************************************
      * 2/M - Modificacion. El cliente ya esta leido y mostrado.
      *     - Estado I (Inactivo): la unica accion permitida es
      *       reactivarlo (estado R); no se ofrece editar datos.
      *     - Estado A o R: se ofrece un submenu con Direccion,
      *       Telefono, Saldo y Terminar. Se pueden modificar uno,
      *       varios o los tres campos, en el orden que se elija,
      *       antes de terminar (el estado no se toca en este flujo).
      *       Nombre y DNI no se modifican nunca.
      *     En ambos casos, al terminar se muestran los datos
      *     actualizados y se VUELVE AL MENU PRINCIPAL: no queda
      *     ningun submenu abierto.
      ******************************************************************
       6000-MODIFICACION.
           IF CLIENTE-INACTIVO
               PERFORM 6500-REACTIVAR-CLIENTE
           ELSE
               PERFORM 6100-MODIFICAR-DATOS
           END-IF.

      * Repite el submenu de campos hasta elegir "Terminar
      * modificacion". Cada campo elegido se valida y se graba en
      * el momento (REWRITE inmediato), asi que WS-CAMBIOS solo
      * cuenta grabaciones que realmente ocurrieron.
       6100-MODIFICAR-DATOS.
           MOVE 0 TO WS-CAMBIOS
           MOVE SPACE TO WS-OPC-MOD
           PERFORM 6150-MENU-CAMPO UNTIL MOD-TERMINAR
           IF WS-CAMBIOS = 0
               DISPLAY "No se modifico ningun dato."
           END-IF
           DISPLAY " "
           DISPLAY "Datos actualizados del cliente:"
           PERFORM 8800-MOSTRAR-CLIENTE.

      * Mismo formato que 1100-MOSTRAR-MENU (solo presentacion).
       6150-MENU-CAMPO.
           DISPLAY " "
           DISPLAY "  ======================================"
           DISPLAY "           QUE DESEA MODIFICAR?"
           DISPLAY "  ======================================"
           DISPLAY " "
           DISPLAY "     1 - Direccion"
           DISPLAY "     2 - Telefono"
           DISPLAY "     3 - Saldo"
           DISPLAY " "
           DISPLAY "     4 - Terminar modificacion"
           DISPLAY " "
           DISPLAY "  Opcion: " WITH NO ADVANCING
           ACCEPT WS-OPC-MOD
           EVALUATE TRUE
               WHEN MOD-DIRECCION
                   PERFORM 8600-PEDIR-DIRECCION
                   IF CAMPO-VALIDO
                       MOVE WS-DIRECCION TO CLI-DIRECCION
                       PERFORM 6200-GRABAR-CAMBIO
                   END-IF
               WHEN MOD-TELEFONO
                   PERFORM 8700-PEDIR-TELEFONO
                   IF CAMPO-VALIDO
                       MOVE WS-TELEFONO TO CLI-TELEFONO
                       PERFORM 6200-GRABAR-CAMBIO
                   END-IF
               WHEN MOD-SALDO
                   PERFORM 8250-PEDIR-SALDO
                   IF CAMPO-VALIDO
                       MOVE WS-SALDO-NUEVO TO CLI-SALDO
                       PERFORM 6200-GRABAR-CAMBIO
                   END-IF
               WHEN MOD-TERMINAR
                   CONTINUE
               WHEN OTHER
                   DISPLAY "Opcion invalida."
           END-EVALUATE.

      * Graba el campo recien cambiado y confirma la grabacion antes
      * de volver a mostrar el submenu.
       6200-GRABAR-CAMBIO.
           PERFORM 8400-ACTUALIZAR-CLIENTE
           ADD 1 TO WS-CAMBIOS
           DISPLAY "Dato modificado.".

      * Cliente inactivo + M: se lo reactiva directamente (estado R),
      * sin confirmacion y sin ofrecer editar otros datos.
       6500-REACTIVAR-CLIENTE.
           SET CLIENTE-REACTIVADO TO TRUE
           PERFORM 8400-ACTUALIZAR-CLIENTE
           DISPLAY "Cliente reactivado (estado R)."
           DISPLAY " "
           DISPLAY "Datos actualizados del cliente:"
           PERFORM 8800-MOSTRAR-CLIENTE.

      ******************************************************************
      * 2/B - Baja LOGICA. El cliente ya esta leido y mostrado.
      *     No se elimina el registro: se pone el estado en I.
      *     No se permite si ya esta inactivo ni si tiene saldo
      *     distinto de cero; pide confirmacion. Despues de la baja
      *     se muestran los datos y se vuelve al menu principal.
      ******************************************************************
       7000-BAJA-CLIENTE.
           IF CLIENTE-INACTIVO
               DISPLAY "El cliente ya esta inactivo."
               DISPLAY "Use la opcion M para reactivarlo."
           ELSE
               IF CLI-SALDO NOT = 0
                   DISPLAY "No se puede dar de baja: el saldo"
                   DISPLAY "es distinto de cero. Extraiga el saldo."
               ELSE
                   PERFORM 7100-CONFIRMAR-BAJA
               END-IF
           END-IF.

       7100-CONFIRMAR-BAJA.
           DISPLAY "Confirma la baja? (S/N): " WITH NO ADVANCING
           ACCEPT WS-CONFIRMA
           IF CONFIRMA-SI
               SET CLIENTE-INACTIVO TO TRUE
               PERFORM 8400-ACTUALIZAR-CLIENTE
               DISPLAY "Cliente dado de baja (estado Inactivo)."
               DISPLAY " "
               DISPLAY "Datos actualizados del cliente:"
               PERFORM 8800-MOSTRAR-CLIENTE
           ELSE
               DISPLAY "Baja cancelada."
           END-IF.

      ******************************************************************
      * Rutinas auxiliares
      ******************************************************************

      * Lee del archivo el cliente con clave WS-DNI. Si existe, sus
      * datos quedan en REG-CLIENTE y CLIENTE-ENCONTRADO es verdadero.
       8000-BUSCAR-CLIENTE.
           SET CLIENTE-NO-ENC TO TRUE
           MOVE WS-DNI TO CLI-DNI
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           MOVE "READ" TO WS-OPERACION
           READ ARCH-CLIENTES KEY IS CLI-DNI
               INVALID KEY
                   SET CLIENTE-NO-ENC TO TRUE
               NOT INVALID KEY
                   SET CLIENTE-ENCONTRADO TO TRUE
           END-READ
           IF NOT FS-OK AND NOT FS-CLAVE-NO-ENC
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Fija WS-FECHA-PROCESO ("hoy" para el programa). Si existe la
      * variable de entorno FECHA_PROCESO con una fecha AAAAMMDD
      * valida, se usa esa (sirve para que las pruebas usen siempre
      * la misma fecha). Si no existe, se usa la fecha del sistema.
      * Si existe pero no es una fecha valida, avisa y usa la del
      * sistema (asi un error de tipeo no graba una fecha basura).
       8050-FIJAR-FECHA-PROCESO.
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
                   DISPLAY "FECHA_PROCESO invalida (use AAAAMMDD):"
                   DISPLAY "se usa la fecha del sistema."
               END-IF
           END-IF.

      * Calcula WS-PROX-HABIL: el proximo dia habil (lunes a
      * viernes) despues de WS-FECHA-PROCESO. No considera feriados.
      * INTEGER-OF-DATE numera los dias desde el 01/01/1601, que fue
      * lunes; por eso el resto de dividir por 7 da el dia de la
      * semana: 1 = lunes ... 5 = viernes, 6 = sabado, 0 = domingo.
      *   lunes a jueves: +1    viernes: +3 (lunes)
      *   sabado: +2 (lunes)    domingo: +1 (lunes)
       8060-CALCULAR-PROX-HABIL.
           COMPUTE WS-FECHA-INT =
               FUNCTION INTEGER-OF-DATE(WS-FECHA-PROCESO)
           COMPUTE WS-DIA-SEMANA = FUNCTION MOD(WS-FECHA-INT, 7)
           EVALUATE WS-DIA-SEMANA
               WHEN 5      ADD 3 TO WS-FECHA-INT
               WHEN 6      ADD 2 TO WS-FECHA-INT
               WHEN OTHER  ADD 1 TO WS-FECHA-INT
           END-EVALUATE
           COMPUTE WS-PROX-HABIL =
               FUNCTION DATE-OF-INTEGER(WS-FECHA-INT).

      * Pasa WS-FECHA-AUX (AAAAMMDD) a WS-FECHA-EDIT (DD/MM/AAAA).
       8070-EDITAR-FECHA.
           MOVE SPACES TO WS-FECHA-EDIT
           STRING WS-FA-DIA "/" WS-FA-MES "/" WS-FA-ANIO
               DELIMITED BY SIZE INTO WS-FECHA-EDIT.

      * Pide un DNI de exactamente 8 digitos.
      * NOTA: todos los prompts (los "Opcion:" de los menus y los de
      * datos, como este) usan WITH NO ADVANCING: el dato se tipea en
      * la misma linea, despues de los dos puntos y un espacio. Se
      * probo en la terminal web (Docker, Ubuntu). Cuidado: si la
      * salida no va a una consola real (stdout redirigido o buffer
      * de algunas consolas o IDEs), el texto podria no mostrarse
      * mientras se espera el ACCEPT, y pareceria que el programa se
      * colgo.
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

      * Pide un saldo nuevo para la modificacion: un numero valido,
      * cero o mayor, hasta 2 decimales. A diferencia del monto, el
      * cero es valido, por eso se usa TEST-NUMVAL para distinguir
      * un "0" de un texto que no es un numero.
       8250-PEDIR-SALDO.
           SET CAMPO-INVALIDO TO TRUE
           DISPLAY "Nuevo saldo (cero o mayor): " WITH NO ADVANCING
           ACCEPT WS-MONTO-TXT
           IF WS-MONTO-TXT = SPACES
               DISPLAY "El saldo no puede estar vacio."
           ELSE
               IF FUNCTION TEST-NUMVAL(WS-MONTO-TXT) NOT = 0
                   DISPLAY "Saldo invalido: ingrese un numero."
               ELSE
                   COMPUTE WS-SALDO-NUEVO =
                       FUNCTION NUMVAL(WS-MONTO-TXT)
                       ON SIZE ERROR
                           DISPLAY "Saldo invalido: fuera de rango."
                       NOT ON SIZE ERROR
                           PERFORM 8260-VALIDAR-SALDO-NUEVO
                   END-COMPUTE
               END-IF
           END-IF.

       8260-VALIDAR-SALDO-NUEVO.
           IF WS-SALDO-NUEVO < 0
               DISPLAY "Saldo invalido: no puede ser negativo."
           ELSE
               SET CAMPO-VALIDO TO TRUE
           END-IF.

       8300-MOSTRAR-SALDO.
           MOVE CLI-SALDO TO WS-SALDO-EDIT
           DISPLAY "Saldo actual: " WS-SALDO-EDIT.

      * Graba en el archivo el registro modificado.
       8400-ACTUALIZAR-CLIENTE.
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           MOVE "REWRITE" TO WS-OPERACION
           REWRITE REG-CLIENTE
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Pide el nombre: obligatorio, hasta 30 caracteres.
      * Se lee en un campo de 80 para detectar si se excede el largo
      * (un ACCEPT directo al campo final truncaria sin avisar).
       8500-PEDIR-NOMBRE.
           SET CAMPO-INVALIDO TO TRUE
           DISPLAY "Nombre (hasta 30 caracteres): " WITH NO ADVANCING
           ACCEPT WS-TEXTO
           IF WS-TEXTO = SPACES
               DISPLAY "El nombre no puede estar vacio."
           ELSE
               IF FUNCTION LENGTH(FUNCTION TRIM(WS-TEXTO)) > 30
                   DISPLAY "El nombre admite hasta 30 caracteres."
               ELSE
                   MOVE FUNCTION TRIM(WS-TEXTO) TO WS-NOMBRE
                   SET CAMPO-VALIDO TO TRUE
               END-IF
           END-IF.

      * Pide la direccion: obligatoria, hasta 40 caracteres.
       8600-PEDIR-DIRECCION.
           SET CAMPO-INVALIDO TO TRUE
           DISPLAY "Direccion (hasta 40 caracteres): " WITH NO ADVANCING
           ACCEPT WS-TEXTO
           IF WS-TEXTO = SPACES
               DISPLAY "La direccion no puede estar vacia."
           ELSE
               IF FUNCTION LENGTH(FUNCTION TRIM(WS-TEXTO)) > 40
                   DISPLAY "La direccion admite hasta 40 caracteres."
               ELSE
                   MOVE FUNCTION TRIM(WS-TEXTO) TO WS-DIRECCION
                   SET CAMPO-VALIDO TO TRUE
               END-IF
           END-IF.

      * Pide el telefono: obligatorio, hasta 15 caracteres, solo
      * digitos, + - ( ) y espacios, con al menos 6 digitos.
       8700-PEDIR-TELEFONO.
           SET CAMPO-INVALIDO TO TRUE
           DISPLAY "Telefono (hasta 15 caracteres): " WITH NO ADVANCING
           ACCEPT WS-TEXTO
           IF WS-TEXTO = SPACES
               DISPLAY "El telefono no puede estar vacio."
           ELSE
               IF FUNCTION LENGTH(FUNCTION TRIM(WS-TEXTO)) > 15
                   DISPLAY "El telefono admite hasta 15 caracteres."
               ELSE
                   MOVE FUNCTION TRIM(WS-TEXTO) TO WS-TELEFONO
                   PERFORM 8710-VALIDAR-TELEFONO
               END-IF
           END-IF.

       8710-VALIDAR-TELEFONO.
           IF WS-TELEFONO IS NOT CLASE-TELEFONO
               DISPLAY "Telefono invalido: solo digitos, + - ( )"
               DISPLAY "y espacios."
           ELSE
               MOVE 0 TO WS-CANT-DIG
               PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 15
                   IF WS-TELEFONO(WS-I:1) IS NUMERIC
                       ADD 1 TO WS-CANT-DIG
                   END-IF
               END-PERFORM
               IF WS-CANT-DIG < 6
                   DISPLAY "Telefono invalido: minimo 6 digitos."
               ELSE
                   SET CAMPO-VALIDO TO TRUE
               END-IF
           END-IF.

      * Muestra todos los datos del cliente que esta en REG-CLIENTE.
       8800-MOSTRAR-CLIENTE.
           MOVE CLI-SALDO TO WS-SALDO-EDIT
           DISPLAY "Nombre:    " FUNCTION TRIM(CLI-NOMBRE TRAILING)
           DISPLAY "DNI:       " CLI-DNI
           DISPLAY "Direccion: " FUNCTION TRIM(CLI-DIRECCION TRAILING)
           DISPLAY "Telefono:  " FUNCTION TRIM(CLI-TELEFONO TRAILING)
           DISPLAY "Saldo:     " WS-SALDO-EDIT
           EVALUATE TRUE
               WHEN CLIENTE-ACTIVO
                   DISPLAY "Estado:    A - Activo"
               WHEN CLIENTE-INACTIVO
                   DISPLAY "Estado:    I - Inactivo"
               WHEN CLIENTE-REACTIVADO
                   DISPLAY "Estado:    R - Reactivado"
               WHEN OTHER
                   DISPLAY "Estado:    ? - Desconocido"
           END-EVALUATE.

      * Un cliente puede operar (deposito / extraccion) si su estado
      * es A (Activo) o R (Reactivado). Con estado I se bloquea. Un
      * valor desconocido (archivo danado) tambien se bloquea.
       8900-VERIFICAR-ACTIVO.
           IF CLIENTE-ACTIVO OR CLIENTE-REACTIVADO
               SET CLIENTE-OPERABLE TO TRUE
           ELSE
               SET CLIENTE-NO-OPERABLE TO TRUE
               DISPLAY "Cliente inactivo: no se puede operar."
           END-IF.

      * Error de E/S inesperado: informa operacion, FILE STATUS y
      * su significado, y termina el programa. WS-ARCHIVO dice cual
      * de los dos archivos fallo (clientes_v3.dat o intereses.dat).
      * Se cierran los dos: cerrar uno que no estaba abierto solo da
      * FILE STATUS 42, que aca se ignora.
       9000-ERROR-ARCHIVO.
           DISPLAY "Error de archivo en " WS-OPERACION
           DISPLAY "FILE STATUS: " WS-FS
           EVALUATE WS-FS
               WHEN "30"
                   DISPLAY FUNCTION TRIM(WS-ARCHIVO)
                       " ilegible o corrupto."
                   DISPLAY "Borrelo para que se cree de nuevo."
               WHEN "35"
                   DISPLAY "El archivo " FUNCTION TRIM(WS-ARCHIVO)
                       " no existe."
               WHEN "37"
                   DISPLAY "Sin permisos sobre "
                       FUNCTION TRIM(WS-ARCHIVO) "."
               WHEN "39"
                   DISPLAY FUNCTION TRIM(WS-ARCHIVO)
                       ": formato incompatible."
                   DISPLAY "Borrelo para que se cree de nuevo."
               WHEN "41"
                   DISPLAY "El archivo ya estaba abierto."
               WHEN "42"
                   DISPLAY "El archivo no estaba abierto."
               WHEN "61"
                   DISPLAY FUNCTION TRIM(WS-ARCHIVO)
                       " esta en uso por otro"
                   DISPLAY "programa."
               WHEN OTHER
                   DISPLAY "Codigo no previsto; revisar el archivo."
           END-EVALUATE
           CLOSE ARCH-CLIENTES
           CLOSE ARCH-INTERESES
           MOVE 1 TO RETURN-CODE
           STOP RUN.
