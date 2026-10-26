      ******************************************************************
      * PROGRAMA    : CARGA-MASIVA
      * DESCRIPCION : Proceso batch de carga masiva (Etapa 4). Lee un
      *               archivo de texto de lineas de 100 posiciones y
      *               carga clientes (tipo C), tasas de interes (tipo
      *               I) y plazos fijos (tipo P) en clientes_v3.dat,
      *               intereses.dat y plazofijo.dat, con las MISMAS
      *               reglas que la carga manual de GESTION-BANCARIA.
      *               Las lineas se procesan en el orden del archivo,
      *               sin reordenar. Una linea invalida se rechaza y
      *               se sigue con la siguiente (no es todo-o-nada).
      * ARCHIVO     : el de la variable de entorno ARCHIVO_CARGA o, si
      *               no existe, carga.txt. Al terminar bien se
      *               renombra a <nombre>.procesado.AAAAMMDD.HHMMSS
      *               (fecha de proceso + hora del sistema), asi no se
      *               vuelve a cargar por error.
      * REPORTES    : carga_ok.txt (lo cargado) y carga_rechazos.txt
      *               (lo rechazado y el motivo). Se reescriben en
      *               cada corrida.
      * FECHA DE
      * PROCESO     : la de la variable de entorno FECHA_PROCESO
      *               (AAAAMMDD) si existe, si no la del sistema.
      * CODIGO DE
      * RETORNO     : 0 = se proceso todo el archivo (con o sin
      *               rechazos). 8 = no pudo correr (fecha invalida,
      *               archivo inexistente, error de archivo o de
      *               renombrado); con 8 el archivo NO se renombra.
      * AUTOR       : JuanKa
      * FECHA       : 2026-10-26
      * USO         : NUNCA al mismo tiempo que GESTION-BANCARIA o
      *               BATCH-CIERRE sobre los mismos archivos.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARGA-MASIVA.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. PC.
       OBJECT-COMPUTER. PC.
       SPECIAL-NAMES.
      * Misma clase que GESTION-BANCARIA para validar el telefono
           CLASS CLASE-TELEFONO IS "0" THRU "9" "+" "-" "(" ")" " ".

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
      * Los tres archivos de datos: mismos nombres y claves que en
      * GESTION-BANCARIA (se buscan en la carpeta de ejecucion).
           SELECT ARCH-CLIENTES ASSIGN TO "clientes_v3.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS CLI-DNI
               FILE STATUS IS WS-FS.

           SELECT ARCH-INTERESES ASSIGN TO "intereses.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS INT-CLAVE
               FILE STATUS IS WS-FS.

      * DYNAMIC: al arrancar se recorre en orden (READ NEXT) para
      * saber el ultimo numero de plazo fijo grabado.
           SELECT ARCH-PLAZOFIJO ASSIGN TO "plazofijo.dat"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS PF-NRO
               FILE STATUS IS WS-FS.

      * ASSIGN USING: el nombre del archivo sale de WS-NOMBRE-CARGA
      * en el momento del OPEN (ARCHIVO_CARGA o carga.txt).
           SELECT ARCH-CARGA ASSIGN USING WS-NOMBRE-CARGA
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

           SELECT ARCH-OK ASSIGN TO "carga_ok.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

           SELECT ARCH-RECH ASSIGN TO "carga_rechazos.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARCH-CLIENTES.
           COPY CLIENTE.

       FD  ARCH-INTERESES.
           COPY INTERES.

       FD  ARCH-PLAZOFIJO.
           COPY PLAZOFIJO.

      * Registro variable de hasta 200: al leer, WS-LARGO queda con
      * la cantidad de caracteres que trajo la linea (los espacios
      * del final cuentan; el CR de Windows lo saca GnuCOBOL). Asi se
      * detecta una linea de mas de 100. Una de mas de 200 llega
      * recortada a 200 (igual es "Largo incorrecto"). Se probo en
      * GnuCOBOL 2.0 (Windows) y 3.1 (Docker): mismo resultado. Va
      * "FROM 1" y no "FROM 0" porque 3.1 da un aviso con "FROM 0";
      * una linea vacia igual llega con WS-LARGO = 0.
       FD  ARCH-CARGA
           RECORD IS VARYING IN SIZE FROM 1 TO 200 CHARACTERS
               DEPENDING ON WS-LARGO.
       01  REG-CARGA               PIC X(200).

       FD  ARCH-OK.
       01  REG-OK                  PIC X(132).

       FD  ARCH-RECH.
       01  REG-RECH                PIC X(132).

       WORKING-STORAGE SECTION.

      * Estado de la ultima operacion de E/S (de cualquier archivo:
      * se mira siempre justo despues de cada operacion)
       01  WS-FS                   PIC XX     VALUE "00".
           88  FS-OK                          VALUE "00".
           88  FS-FIN-ARCHIVO                 VALUE "10".
           88  FS-CLAVE-DUPLICADA             VALUE "22".
           88  FS-CLAVE-NO-ENC                VALUE "23".
           88  FS-NO-EXISTE                   VALUE "35".
      * Operacion y archivo en curso, para informar un error
       01  WS-OPERACION            PIC X(10)  VALUE SPACES.
       01  WS-ARCHIVO              PIC X(100) VALUE SPACES.

      * Nombre del archivo de carga y nombre al renombrarlo
       01  WS-NOMBRE-CARGA         PIC X(100) VALUE SPACES.
       01  WS-NOMBRE-NUEVO         PIC X(130) VALUE SPACES.
       01  WS-RC-RENOMBRAR         PIC S9(9)  VALUE 0.

      * Linea leida: largo informado por el READ y sus primeras 100
      * posiciones (si la linea es mas corta, el resto en espacios)
       01  WS-LARGO                PIC 9(4)   VALUE 0.
       01  WS-FIN-CARGA            PIC X      VALUE "N".
           88  FIN-CARGA                      VALUE "S".
       01  WS-LINEA                PIC X(100).
      * Registro C (cliente)
       01  WS-LIN-C REDEFINES WS-LINEA.
           05  LC-TIPO             PIC X.
           05  LC-DNI              PIC X(8).
           05  LC-NOMBRE           PIC X(30).
           05  LC-DIRECCION        PIC X(40).
           05  LC-TELEFONO         PIC X(15).
           05  FILLER              PIC X(6).
      * Registro I (tasa)
       01  WS-LIN-I REDEFINES WS-LINEA.
           05  LI-TIPO             PIC X.
           05  LI-MONEDA           PIC X.
           05  LI-DIAS             PIC X(3).
           05  LI-DIAS-N REDEFINES LI-DIAS
                                   PIC 9(3).
           05  LI-TNA              PIC X(5).
           05  LI-TNA-N REDEFINES LI-TNA
                                   PIC 9(3)V99.
           05  LI-VIGENTE          PIC X(8).
           05  LI-VIGENTE-N REDEFINES LI-VIGENTE
                                   PIC 9(8).
           05  FILLER              PIC X(82).
      * Registro P (plazo fijo)
       01  WS-LIN-P REDEFINES WS-LINEA.
           05  LP-TIPO             PIC X.
           05  LP-DNI              PIC X(8).
           05  LP-MONEDA           PIC X.
           05  LP-MONTO            PIC X(13).
           05  LP-MONTO-N REDEFINES LP-MONTO
                                   PIC 9(11)V99.
           05  LP-DIAS             PIC X(3).
           05  LP-DIAS-N REDEFINES LP-DIAS
                                   PIC 9(3).
           05  FILLER              PIC X(74).

      * Tipo de la linea (posicion 1). Cualquier otro valor (o una
      * linea en blanco) se cuenta como "sin tipo".
       01  WS-TIPO-REG             PIC X.
           88  TIPO-CLIENTE                   VALUE "C".
           88  TIPO-TASA                      VALUE "I".
           88  TIPO-PF                        VALUE "P".
       01  WS-BLANCA               PIC X      VALUE "N".
           88  LINEA-EN-BLANCO                VALUE "S".

      * Motivo de rechazo de la linea (en blanco = se carga) y texto
      * del resultado de una linea cargada
       01  WS-MOTIVO               PIC X(40)  VALUE SPACES.
           88  SIN-RECHAZO                    VALUE SPACES.
       01  WS-RESULTADO            PIC X(60)  VALUE SPACES.

      * Campos de trabajo (mismos nombres que en GESTION-BANCARIA)
       01  WS-DNI                  PIC 9(8).
       01  WS-NOMBRE               PIC X(30).
       01  WS-DIRECCION            PIC X(40).
       01  WS-TELEFONO             PIC X(15).
       01  WS-I                    PIC 99.
       01  WS-CANT-DIG             PIC 99.
       01  WS-MONEDA               PIC X.
       01  WS-DIAS                 PIC 9(3).
       01  WS-PF-MONTO             PIC 9(11)V99.
       01  WS-TNA-USADA            PIC 9(3)V99.
       01  WS-PF-INTERES           PIC 9(11)V99.
       01  WS-PF-TOTAL             PIC 9(11)V99.
       01  WS-PF-VENC              PIC 9(8).
      * Ultimo numero de plazo fijo grabado (se busca una sola vez al
      * arrancar y despues se suma 1 por cada alta)
       01  WS-PF-ULTIMO            PIC 9(6)   VALUE 0.
       01  WS-FECHA-INT            PIC 9(7).
       01  WS-CALCULO-OK           PIC X      VALUE "S".
           88  CALCULO-VALIDO                 VALUE "S".
           88  CALCULO-INVALIDO               VALUE "N".
       01  WS-ENCONTRADO           PIC X      VALUE "N".
           88  CLIENTE-ENCONTRADO             VALUE "S".
           88  CLIENTE-NO-ENC                 VALUE "N".
       01  WS-TASA-ENC             PIC X      VALUE "N".
           88  TASA-ENCONTRADA                VALUE "S".
           88  TASA-NO-ENC                    VALUE "N".

      * Fechas
       01  WS-FECHA-ENV            PIC X(20).
       01  WS-FECHA-HORA           PIC X(21).
       01  WS-FECHA-PROCESO        PIC 9(8).
       01  WS-FECHA-AUX            PIC 9(8).
       01  WS-FECHA-AUX-R REDEFINES WS-FECHA-AUX.
           05  WS-FA-ANIO          PIC 9(4).
           05  WS-FA-MES           PIC 99.
           05  WS-FA-DIA           PIC 99.
       01  WS-FECHA-EDIT           PIC X(10).

      * Contadores. "Leidos" = cargados + rechazados.
       01  WS-NRO-LINEA            PIC 9(7)   VALUE 0.
       01  WS-OK-CLI               PIC 9(7)   VALUE 0.
       01  WS-OK-INT               PIC 9(7)   VALUE 0.
       01  WS-OK-PF                PIC 9(7)   VALUE 0.
       01  WS-RE-CLI               PIC 9(7)   VALUE 0.
       01  WS-RE-INT               PIC 9(7)   VALUE 0.
       01  WS-RE-PF                PIC 9(7)   VALUE 0.
       01  WS-RE-SIN-TIPO          PIC 9(7)   VALUE 0.
       01  WS-TOTAL-OK             PIC 9(7)   VALUE 0.
       01  WS-TOTAL-RECH           PIC 9(7)   VALUE 0.

       01  WS-IMPORTE-EDIT         PIC ZZ,ZZZ,ZZZ,ZZ9.99.

      * Lineas de los reportes
       01  WS-LINEA-REP            PIC X(132).
       01  WS-TITULOS.
           05  FILLER              PIC X(13)  VALUE "LINEA  TIPO  ".
           05  FILLER              PIC X(31)  VALUE "CLAVE".
           05  WS-TIT-ULTIMA       PIC X(9).
      * Detalle: linea (5 digitos), tipo, clave y resultado/motivo
       01  WS-DETALLE.
           05  WS-DET-LINEA        PIC 9(5).
           05  FILLER              PIC X(2)   VALUE SPACES.
           05  WS-DET-TIPO         PIC X.
           05  FILLER              PIC X(5)   VALUE SPACES.
           05  WS-DET-CLAVE        PIC X(31).
           05  WS-DET-TEXTO        PIC X(60).
       01  WS-LIN-TOTAL.
           05  WS-TOT-TEXTO        PIC X(26).
           05  WS-TOT-CANT         PIC ZZZZZZ9.

       PROCEDURE DIVISION.

      ******************************************************************
      * Programa principal. El orden importa: la fecha, el archivo de
      * carga y los de datos se validan ANTES de abrir los reportes,
      * asi un error de arranque no borra los reportes anteriores.
      ******************************************************************
       0000-PRINCIPAL.
           DISPLAY "CARGA MASIVA"
           PERFORM 0100-FIJAR-FECHA-PROCESO
           PERFORM 0200-ABRIR-CARGA
           PERFORM 0300-ABRIR-DATOS
           PERFORM 0400-ABRIR-REPORTES
           PERFORM 1000-LEER-LINEA
           IF FIN-CARGA
               PERFORM 0500-ARCHIVO-VACIO
           ELSE
               PERFORM 2000-PROCESAR-LINEA UNTIL FIN-CARGA
           END-IF
           PERFORM 8000-TOTALES
           PERFORM 8500-CERRAR-ARCHIVOS
           PERFORM 8600-RENOMBRAR-CARGA
           DISPLAY "Carga terminada (codigo 0)."
           MOVE 0 TO RETURN-CODE
           STOP RUN.

      * Igual que 8050-FIJAR-FECHA-PROCESO de GESTION-BANCARIA, salvo
      * que una FECHA_PROCESO invalida termina con codigo 8 (en un
      * batch no se sigue con otra fecha sin que nadie lo vea).
       0100-FIJAR-FECHA-PROCESO.
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
                   DISPLAY "No se proceso nada."
                   PERFORM 9900-TERMINAR-CON-ERROR
               END-IF
           END-IF
           MOVE WS-FECHA-PROCESO TO WS-FECHA-AUX
           PERFORM 7900-EDITAR-FECHA
           DISPLAY "Fecha de proceso: " WS-FECHA-EDIT.

       0200-ABRIR-CARGA.
           MOVE SPACES TO WS-NOMBRE-CARGA
           ACCEPT WS-NOMBRE-CARGA FROM ENVIRONMENT "ARCHIVO_CARGA"
           IF WS-NOMBRE-CARGA = SPACES
               MOVE "carga.txt" TO WS-NOMBRE-CARGA
           END-IF
           DISPLAY "Archivo de carga: " FUNCTION TRIM(WS-NOMBRE-CARGA)
           MOVE WS-NOMBRE-CARGA TO WS-ARCHIVO
           MOVE "OPEN INPUT" TO WS-OPERACION
           OPEN INPUT ARCH-CARGA
           IF FS-NO-EXISTE
               DISPLAY "No existe el archivo de carga: "
                   FUNCTION TRIM(WS-NOMBRE-CARGA)
               DISPLAY "No se proceso nada."
               PERFORM 9900-TERMINAR-CON-ERROR
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Abre los tres archivos de datos para lectura/escritura. Si
      * alguno no existe (FILE STATUS 35) lo crea vacio y lo vuelve a
      * abrir, igual que 0100-ABRIR-ARCHIVO de GESTION-BANCARIA.
       0300-ABRIR-DATOS.
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           MOVE "OPEN I-O" TO WS-OPERACION
           OPEN I-O ARCH-CLIENTES
           IF FS-NO-EXISTE
               OPEN OUTPUT ARCH-CLIENTES
               IF FS-OK
                   CLOSE ARCH-CLIENTES
                   OPEN I-O ARCH-CLIENTES
               END-IF
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "intereses.dat" TO WS-ARCHIVO
           OPEN I-O ARCH-INTERESES
           IF FS-NO-EXISTE
               OPEN OUTPUT ARCH-INTERESES
               IF FS-OK
                   CLOSE ARCH-INTERESES
                   OPEN I-O ARCH-INTERESES
               END-IF
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "plazofijo.dat" TO WS-ARCHIVO
           OPEN I-O ARCH-PLAZOFIJO
           IF FS-NO-EXISTE
               OPEN OUTPUT ARCH-PLAZOFIJO
               IF FS-OK
                   CLOSE ARCH-PLAZOFIJO
                   OPEN I-O ARCH-PLAZOFIJO
               END-IF
           END-IF
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           PERFORM 0350-BUSCAR-ULTIMO-NRO.

      * Misma logica que 5280-BUSCAR-ULTIMO-NRO de GESTION-BANCARIA:
      * se posiciona al principio y lee en orden hasta el final; el
      * ultimo leido es el mayor (0 si el archivo esta vacio).
       0350-BUSCAR-ULTIMO-NRO.
           MOVE 0 TO WS-PF-ULTIMO
           MOVE 0 TO PF-NRO
           MOVE "START" TO WS-OPERACION
           START ARCH-PLAZOFIJO KEY IS NOT LESS THAN PF-NRO
               INVALID KEY
                   SET FS-FIN-ARCHIVO TO TRUE
           END-START
           IF NOT FS-OK AND NOT FS-FIN-ARCHIVO
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "READ NEXT" TO WS-OPERACION
           PERFORM UNTIL FS-FIN-ARCHIVO
               READ ARCH-PLAZOFIJO NEXT RECORD
                   AT END
                       CONTINUE
                   NOT AT END
                       MOVE PF-NRO TO WS-PF-ULTIMO
               END-READ
               IF NOT FS-OK AND NOT FS-FIN-ARCHIVO
                   PERFORM 9000-ERROR-ARCHIVO
               END-IF
           END-PERFORM.

      * Abre los dos reportes (OUTPUT: se reescriben) y graba los
      * encabezados.
       0400-ABRIR-REPORTES.
           MOVE "OPEN OUT" TO WS-OPERACION
           MOVE "carga_ok.txt" TO WS-ARCHIVO
           OPEN OUTPUT ARCH-OK
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "carga_rechazos.txt" TO WS-ARCHIVO
           OPEN OUTPUT ARCH-RECH
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "CARGA MASIVA - REGISTROS CARGADOS" TO WS-LINEA-REP
           PERFORM 8100-ESCRIBIR-OK
           MOVE "CARGA MASIVA - REGISTROS RECHAZADOS" TO WS-LINEA-REP
           PERFORM 8200-ESCRIBIR-RECH
           MOVE SPACES TO WS-LINEA-REP
           STRING "Fecha de proceso: " WS-FECHA-EDIT
               "   Archivo: " FUNCTION TRIM(WS-NOMBRE-CARGA)
               DELIMITED BY SIZE INTO WS-LINEA-REP
           PERFORM 8100-ESCRIBIR-OK
           PERFORM 8200-ESCRIBIR-RECH
           MOVE "RESULTADO" TO WS-TIT-ULTIMA
           MOVE WS-TITULOS TO WS-LINEA-REP
           PERFORM 8100-ESCRIBIR-OK
           MOVE "MOTIVO" TO WS-TIT-ULTIMA
           MOVE WS-TITULOS TO WS-LINEA-REP
           PERFORM 8200-ESCRIBIR-RECH.

      * Archivo sin ninguna linea: no es un error (codigo 0).
       0500-ARCHIVO-VACIO.
           DISPLAY "Archivo vacio: sin datos para procesar"
           MOVE "Archivo vacio: sin datos para procesar"
               TO WS-LINEA-REP
           PERFORM 8100-ESCRIBIR-OK
           PERFORM 8200-ESCRIBIR-RECH.

      * Lee la linea siguiente y la deja en WS-LINEA (las posiciones
      * que la linea no trae quedan en espacios).
       1000-LEER-LINEA.
           MOVE WS-NOMBRE-CARGA TO WS-ARCHIVO
           MOVE "READ" TO WS-OPERACION
           MOVE 0 TO WS-LARGO
           READ ARCH-CARGA
               AT END
                   SET FIN-CARGA TO TRUE
           END-READ
           IF NOT FS-OK AND NOT FS-FIN-ARCHIVO
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           IF NOT FIN-CARGA
               MOVE SPACES TO WS-LINEA
               IF WS-LARGO > 0
                   MOVE REG-CARGA(1:WS-LARGO) TO WS-LINEA
               END-IF
           END-IF.

      ******************************************************************
      * Procesa la linea leida: valida el formato, la carga segun su
      * tipo, la informa en el reporte que corresponde y lee la
      * siguiente. Cada linea tiene UN solo motivo: el primer error
      * que se encuentra, en el mismo orden en que el alta manual
      * pide los datos.
      ******************************************************************
       2000-PROCESAR-LINEA.
           ADD 1 TO WS-NRO-LINEA
           MOVE SPACES TO WS-MOTIVO
           MOVE SPACES TO WS-RESULTADO
           PERFORM 2100-VALIDAR-FORMATO
           IF SIN-RECHAZO
               EVALUATE TRUE
                   WHEN TIPO-CLIENTE  PERFORM 3000-CARGAR-CLIENTE
                   WHEN TIPO-TASA     PERFORM 4000-CARGAR-TASA
                   WHEN TIPO-PF       PERFORM 5000-CARGAR-PF
               END-EVALUATE
           END-IF
           PERFORM 2200-ARMAR-CLAVE
           IF SIN-RECHAZO
               PERFORM 2300-INFORMAR-CARGADO
           ELSE
               PERFORM 2400-INFORMAR-RECHAZO
           END-IF
           PERFORM 1000-LEER-LINEA.

      * Linea en blanco, tipo y largo. Una linea mas corta que 100 se
      * acepta si llega hasta el ultimo campo obligatorio de su tipo
      * (lo que falta se toma como espacios): C hasta la posicion 85
      * (6 posiciones de telefono), I hasta la 18 (fin de la fecha de
      * vigencia) y P hasta la 26 (fin de los dias).
       2100-VALIDAR-FORMATO.
           MOVE WS-LINEA(1:1) TO WS-TIPO-REG
           MOVE "N" TO WS-BLANCA
           IF WS-LINEA = SPACES
               IF WS-LARGO <= 100
                   SET LINEA-EN-BLANCO TO TRUE
               ELSE
                   IF REG-CARGA(101:WS-LARGO - 100) = SPACES
                       SET LINEA-EN-BLANCO TO TRUE
                   END-IF
               END-IF
           END-IF
           EVALUATE TRUE
               WHEN LINEA-EN-BLANCO
                   MOVE "Linea en blanco" TO WS-MOTIVO
               WHEN NOT TIPO-CLIENTE AND NOT TIPO-TASA
                    AND NOT TIPO-PF
                   IF WS-LARGO > 100
                       MOVE "Largo incorrecto" TO WS-MOTIVO
                   ELSE
                       MOVE "Tipo de registro desconocido"
                           TO WS-MOTIVO
                   END-IF
               WHEN WS-LARGO > 100
                   MOVE "Largo incorrecto" TO WS-MOTIVO
               WHEN TIPO-CLIENTE AND WS-LARGO < 85
                   MOVE "Largo incorrecto" TO WS-MOTIVO
               WHEN TIPO-TASA AND WS-LARGO < 18
                   MOVE "Largo incorrecto" TO WS-MOTIVO
               WHEN TIPO-PF AND WS-LARGO < 26
                   MOVE "Largo incorrecto" TO WS-MOTIVO
           END-EVALUATE.

      * Clave para los reportes, con los datos tal cual vienen en la
      * linea: DNI (C), moneda y dias (I), DNI, moneda y monto (P).
       2200-ARMAR-CLAVE.
           MOVE SPACES TO WS-DET-CLAVE
           EVALUATE TRUE
               WHEN LINEA-EN-BLANCO
                   CONTINUE
               WHEN TIPO-CLIENTE
                   MOVE LC-DNI TO WS-DET-CLAVE
               WHEN TIPO-TASA
                   STRING LI-MONEDA " " LI-DIAS
                       DELIMITED BY SIZE INTO WS-DET-CLAVE
               WHEN TIPO-PF
                   IF LP-MONTO IS NUMERIC
                       MOVE LP-MONTO-N TO WS-IMPORTE-EDIT
                       STRING LP-DNI " " LP-MONEDA " "
                           FUNCTION TRIM(WS-IMPORTE-EDIT)
                           DELIMITED BY SIZE INTO WS-DET-CLAVE
                   ELSE
                       STRING LP-DNI " " LP-MONEDA " " LP-MONTO
                           DELIMITED BY SIZE INTO WS-DET-CLAVE
                   END-IF
           END-EVALUATE
           MOVE WS-NRO-LINEA TO WS-DET-LINEA
           IF WS-TIPO-REG = SPACE
               MOVE "-" TO WS-DET-TIPO
           ELSE
               MOVE WS-TIPO-REG TO WS-DET-TIPO
           END-IF.

       2300-INFORMAR-CARGADO.
           EVALUATE TRUE
               WHEN TIPO-CLIENTE  ADD 1 TO WS-OK-CLI
               WHEN TIPO-TASA     ADD 1 TO WS-OK-INT
               WHEN TIPO-PF       ADD 1 TO WS-OK-PF
           END-EVALUATE
           MOVE WS-RESULTADO TO WS-DET-TEXTO
           MOVE WS-DETALLE TO WS-LINEA-REP
           PERFORM 8100-ESCRIBIR-OK.

       2400-INFORMAR-RECHAZO.
           EVALUATE TRUE
               WHEN LINEA-EN-BLANCO  ADD 1 TO WS-RE-SIN-TIPO
               WHEN TIPO-CLIENTE     ADD 1 TO WS-RE-CLI
               WHEN TIPO-TASA        ADD 1 TO WS-RE-INT
               WHEN TIPO-PF          ADD 1 TO WS-RE-PF
               WHEN OTHER            ADD 1 TO WS-RE-SIN-TIPO
           END-EVALUATE
           MOVE WS-MOTIVO TO WS-DET-TEXTO
           MOVE WS-DETALLE TO WS-LINEA-REP
           PERFORM 8200-ESCRIBIR-RECH.

      ******************************************************************
      * C - Alta de cliente: mismas reglas que 2000-ALTA-CLIENTE de
      *     GESTION-BANCARIA (saldo 0, estado A). Como en el alta
      *     manual, al nombre, la direccion y el telefono se les
      *     sacan los espacios de adelante.
      ******************************************************************
       3000-CARGAR-CLIENTE.
           IF LC-DNI IS NOT NUMERIC
               MOVE "DNI no numerico" TO WS-MOTIVO
           ELSE
               MOVE LC-DNI TO WS-DNI
               PERFORM 7000-BUSCAR-CLIENTE
               IF CLIENTE-ENCONTRADO
                   MOVE "DNI duplicado" TO WS-MOTIVO
               END-IF
           END-IF
           IF SIN-RECHAZO
               EVALUATE TRUE
                   WHEN LC-NOMBRE = SPACES
                       MOVE "Nombre en blanco" TO WS-MOTIVO
                   WHEN LC-DIRECCION = SPACES
                       MOVE "Direccion en blanco" TO WS-MOTIVO
                   WHEN LC-TELEFONO = SPACES
                       MOVE "Telefono en blanco" TO WS-MOTIVO
               END-EVALUATE
           END-IF
           IF SIN-RECHAZO
               MOVE FUNCTION TRIM(LC-NOMBRE LEADING)
                   TO WS-NOMBRE
               MOVE FUNCTION TRIM(LC-DIRECCION LEADING)
                   TO WS-DIRECCION
               MOVE FUNCTION TRIM(LC-TELEFONO LEADING)
                   TO WS-TELEFONO
               PERFORM 3100-VALIDAR-TELEFONO
           END-IF
           IF SIN-RECHAZO
               PERFORM 3200-GRABAR-CLIENTE
           END-IF.

      * Misma regla que 8710-VALIDAR-TELEFONO de GESTION-BANCARIA:
      * solo digitos, + - ( ) y espacios, con al menos 6 digitos.
       3100-VALIDAR-TELEFONO.
           IF WS-TELEFONO IS NOT CLASE-TELEFONO
               MOVE "Telefono invalido" TO WS-MOTIVO
           ELSE
               MOVE 0 TO WS-CANT-DIG
               PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 15
                   IF WS-TELEFONO(WS-I:1) IS NUMERIC
                       ADD 1 TO WS-CANT-DIG
                   END-IF
               END-PERFORM
               IF WS-CANT-DIG < 6
                   MOVE "Telefono invalido" TO WS-MOTIVO
               END-IF
           END-IF.

       3200-GRABAR-CLIENTE.
           MOVE WS-DNI       TO CLI-DNI
           MOVE WS-NOMBRE    TO CLI-NOMBRE
           MOVE WS-DIRECCION TO CLI-DIRECCION
           MOVE WS-TELEFONO  TO CLI-TELEFONO
           MOVE 0            TO CLI-SALDO
           SET CLIENTE-ACTIVO TO TRUE
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-CLIENTE
               INVALID KEY
                   MOVE "DNI duplicado" TO WS-MOTIVO
               NOT INVALID KEY
                   MOVE "Cliente dado de alta" TO WS-RESULTADO
           END-WRITE
           IF NOT FS-OK AND NOT FS-CLAVE-DUPLICADA
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      ******************************************************************
      * I - Alta de tasa. Solo alta: si la moneda + dias ya existe
      *     (activa o de baja) se rechaza; no modifica ni reactiva.
      *     VIGENTE-DESDE es la del archivo (no se calcula el proximo
      *     dia habil), TNA-ANTERIOR en cero y estado A.
      ******************************************************************
       4000-CARGAR-TASA.
           MOVE FUNCTION UPPER-CASE(LI-MONEDA) TO WS-MONEDA
           EVALUATE TRUE
               WHEN WS-MONEDA NOT = "P" AND WS-MONEDA NOT = "D"
                   MOVE "Moneda invalida" TO WS-MOTIVO
               WHEN LI-DIAS IS NOT NUMERIC
                   MOVE "Campo numerico invalido" TO WS-MOTIVO
               WHEN LI-DIAS-N NOT = 30 AND LI-DIAS-N NOT = 60
                    AND LI-DIAS-N NOT = 90 AND LI-DIAS-N NOT = 120
                   MOVE "Dias no permitidos" TO WS-MOTIVO
               WHEN LI-TNA IS NOT NUMERIC
                   MOVE "Campo numerico invalido" TO WS-MOTIVO
               WHEN LI-TNA-N = 0
                   MOVE "TNA invalida" TO WS-MOTIVO
               WHEN LI-VIGENTE IS NOT NUMERIC
                   MOVE "Fecha de vigencia invalida" TO WS-MOTIVO
               WHEN FUNCTION TEST-DATE-YYYYMMDD(LI-VIGENTE-N) NOT = 0
                   MOVE "Fecha de vigencia invalida" TO WS-MOTIVO
           END-EVALUATE
           IF SIN-RECHAZO
               MOVE LI-DIAS-N TO WS-DIAS
               PERFORM 7100-BUSCAR-TASA
               IF TASA-ENCONTRADA
                   MOVE "Tasa ya existe" TO WS-MOTIVO
               ELSE
                   PERFORM 4100-GRABAR-TASA
               END-IF
           END-IF.

       4100-GRABAR-TASA.
           MOVE WS-MONEDA    TO INT-MONEDA
           MOVE WS-DIAS      TO INT-DIAS
           MOVE LI-TNA-N     TO INT-TNA
           MOVE 0            TO INT-TNA-ANTERIOR
           MOVE LI-VIGENTE-N TO INT-VIGENTE-DESDE
           SET TASA-ACTIVA TO TRUE
           MOVE "intereses.dat" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-INTERES
               INVALID KEY
                   MOVE "Tasa ya existe" TO WS-MOTIVO
           END-WRITE
           IF NOT FS-OK AND NOT FS-CLAVE-DUPLICADA
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           IF SIN-RECHAZO
               MOVE LI-VIGENTE-N TO WS-FECHA-AUX
               PERFORM 7900-EDITAR-FECHA
               STRING "Tasa dada de alta, rige desde " WS-FECHA-EDIT
                   DELIMITED BY SIZE INTO WS-RESULTADO
           END-IF.

      ******************************************************************
      * P - Alta de plazo fijo: mismas reglas que 5200-ALTA-PF de
      *     GESTION-BANCARIA, sin confirmacion. NO toca el saldo del
      *     cliente.
      ******************************************************************
       5000-CARGAR-PF.
           IF LP-DNI IS NOT NUMERIC
               MOVE "DNI no numerico" TO WS-MOTIVO
           ELSE
               MOVE LP-DNI TO WS-DNI
               PERFORM 7000-BUSCAR-CLIENTE
               EVALUATE TRUE
                   WHEN CLIENTE-NO-ENC
                       MOVE "Cliente inexistente" TO WS-MOTIVO
                   WHEN NOT CLIENTE-ACTIVO AND NOT CLIENTE-REACTIVADO
                       MOVE "Cliente inactivo" TO WS-MOTIVO
               END-EVALUATE
           END-IF
           IF SIN-RECHAZO
               PERFORM 5100-VALIDAR-DATOS-PF
           END-IF
           IF SIN-RECHAZO
               PERFORM 5200-BUSCAR-TASA-VIGENTE
           END-IF
           IF SIN-RECHAZO
               PERFORM 5300-CALCULAR-PF
           END-IF
           IF SIN-RECHAZO
               PERFORM 5400-GRABAR-PF
           END-IF.

      * Moneda, monto (con el minimo de la moneda: pesos 1.000.000,
      * dolares 500; igual al minimo se acepta) y dias, en el orden
      * en que los pide el alta manual.
       5100-VALIDAR-DATOS-PF.
           MOVE FUNCTION UPPER-CASE(LP-MONEDA) TO WS-MONEDA
           EVALUATE TRUE
               WHEN WS-MONEDA NOT = "P" AND WS-MONEDA NOT = "D"
                   MOVE "Moneda invalida" TO WS-MOTIVO
               WHEN LP-MONTO IS NOT NUMERIC
                   MOVE "Campo numerico invalido" TO WS-MOTIVO
               WHEN WS-MONEDA = "P" AND LP-MONTO-N < 1000000
                   MOVE "Monto menor al minimo" TO WS-MOTIVO
               WHEN WS-MONEDA = "D" AND LP-MONTO-N < 500
                   MOVE "Monto menor al minimo" TO WS-MOTIVO
               WHEN LP-DIAS IS NOT NUMERIC
                   MOVE "Campo numerico invalido" TO WS-MOTIVO
               WHEN LP-DIAS-N NOT = 30 AND LP-DIAS-N NOT = 60
                    AND LP-DIAS-N NOT = 90 AND LP-DIAS-N NOT = 120
                   MOVE "Dias no permitidos" TO WS-MOTIVO
           END-EVALUATE
           IF SIN-RECHAZO
               MOVE LP-MONTO-N TO WS-PF-MONTO
               MOVE LP-DIAS-N  TO WS-DIAS
           END-IF.

      * Misma regla que 5230-BUSCAR-TASA-VIGENTE de GESTION-BANCARIA:
      * sin tasa o en baja: no hay; fecha de proceso >= VIGENTE-DESDE:
      * rige INT-TNA; antes: INT-TNA-ANTERIOR si es mayor que cero.
       5200-BUSCAR-TASA-VIGENTE.
           PERFORM 7100-BUSCAR-TASA
           EVALUATE TRUE
               WHEN TASA-NO-ENC
               WHEN TASA-BAJA
                   MOVE "Sin tasa vigente" TO WS-MOTIVO
               WHEN WS-FECHA-PROCESO >= INT-VIGENTE-DESDE
                   MOVE INT-TNA TO WS-TNA-USADA
               WHEN INT-TNA-ANTERIOR > 0
                   MOVE INT-TNA-ANTERIOR TO WS-TNA-USADA
               WHEN OTHER
                   MOVE "Sin tasa vigente" TO WS-MOTIVO
           END-EVALUATE.

      * Mismo calculo que 5240-CALCULAR-PF de GESTION-BANCARIA:
      * INTERES = MONTO x TNA x DIAS / 36500 (redondeado al centavo),
      * TOTAL = MONTO + INTERES, vencimiento = fecha de proceso + dias.
      * Si el interes o el total no entran en 9(11)V99 se rechaza.
       5300-CALCULAR-PF.
           SET CALCULO-VALIDO TO TRUE
           COMPUTE WS-PF-INTERES ROUNDED =
               WS-PF-MONTO * WS-TNA-USADA * WS-DIAS / 36500
               ON SIZE ERROR
                   SET CALCULO-INVALIDO TO TRUE
           END-COMPUTE
           IF CALCULO-VALIDO
               COMPUTE WS-PF-TOTAL = WS-PF-MONTO + WS-PF-INTERES
                   ON SIZE ERROR
                       SET CALCULO-INVALIDO TO TRUE
               END-COMPUTE
           END-IF
           IF CALCULO-VALIDO
               COMPUTE WS-FECHA-INT =
                   FUNCTION INTEGER-OF-DATE(WS-FECHA-PROCESO) + WS-DIAS
               COMPUTE WS-PF-VENC =
                   FUNCTION DATE-OF-INTEGER(WS-FECHA-INT)
           ELSE
               MOVE "Total excede el maximo permitido" TO WS-MOTIVO
           END-IF.

      * Numero = ultimo + 1. Si ya no hay numeros es un error grave
      * (no un rechazo de la linea): se termina con codigo 8.
       5400-GRABAR-PF.
           IF WS-PF-ULTIMO = 999999
               DISPLAY "No hay mas numeros de plazo fijo disponibles"
               DISPLAY "(linea " WS-NRO-LINEA ")."
               PERFORM 9900-TERMINAR-CON-ERROR
           END-IF
           ADD 1 TO WS-PF-ULTIMO
           MOVE WS-PF-ULTIMO     TO PF-NRO
           MOVE WS-DNI           TO PF-DNI
           MOVE WS-MONEDA        TO PF-MONEDA
           MOVE WS-PF-MONTO      TO PF-MONTO
           MOVE WS-DIAS          TO PF-DIAS
           MOVE WS-TNA-USADA     TO PF-TNA-APLICADA
           MOVE WS-PF-INTERES    TO PF-INTERES
           MOVE WS-PF-TOTAL      TO PF-TOTAL
           MOVE WS-FECHA-PROCESO TO PF-FECHA-ALTA
           MOVE WS-PF-VENC       TO PF-FECHA-VENC
           SET PF-ACTIVO TO TRUE
           MOVE "plazofijo.dat" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-PLAZOFIJO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           STRING "Plazo fijo " PF-NRO " constituido"
               DELIMITED BY SIZE INTO WS-RESULTADO.

      ******************************************************************
      * Rutinas auxiliares
      ******************************************************************

      * Lee el cliente con clave WS-DNI (igual que 8000-BUSCAR-CLIENTE
      * de GESTION-BANCARIA).
       7000-BUSCAR-CLIENTE.
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

      * Lee la tasa con clave WS-MONEDA + WS-DIAS (igual que
      * 5940-BUSCAR-TASA de GESTION-BANCARIA).
       7100-BUSCAR-TASA.
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

      * Pasa WS-FECHA-AUX (AAAAMMDD) a WS-FECHA-EDIT (DD/MM/AAAA).
       7900-EDITAR-FECHA.
           MOVE SPACES TO WS-FECHA-EDIT
           STRING WS-FA-DIA "/" WS-FA-MES "/" WS-FA-ANIO
               DELIMITED BY SIZE INTO WS-FECHA-EDIT.

      * Totales al final de los dos reportes y por pantalla.
       8000-TOTALES.
           COMPUTE WS-TOTAL-OK = WS-OK-CLI + WS-OK-INT + WS-OK-PF
           COMPUTE WS-TOTAL-RECH = WS-RE-CLI + WS-RE-INT + WS-RE-PF
                                 + WS-RE-SIN-TIPO
           MOVE ALL "-" TO WS-LINEA-REP(1:100)
           PERFORM 8100-ESCRIBIR-OK
           PERFORM 8200-ESCRIBIR-RECH
           DISPLAY "Cargados:"
           MOVE "Clientes cargados:" TO WS-TOT-TEXTO
           MOVE WS-OK-CLI TO WS-TOT-CANT
           PERFORM 8010-TOTAL-OK
           MOVE "Tasas cargadas:" TO WS-TOT-TEXTO
           MOVE WS-OK-INT TO WS-TOT-CANT
           PERFORM 8010-TOTAL-OK
           MOVE "Plazos fijos cargados:" TO WS-TOT-TEXTO
           MOVE WS-OK-PF TO WS-TOT-CANT
           PERFORM 8010-TOTAL-OK
           MOVE "TOTAL GENERAL CARGADO:" TO WS-TOT-TEXTO
           MOVE WS-TOTAL-OK TO WS-TOT-CANT
           PERFORM 8010-TOTAL-OK
           MOVE "TOTAL LEIDOS:" TO WS-TOT-TEXTO
           MOVE WS-NRO-LINEA TO WS-TOT-CANT
           PERFORM 8010-TOTAL-OK
           DISPLAY "Rechazados:"
           MOVE "Clientes rechazados:" TO WS-TOT-TEXTO
           MOVE WS-RE-CLI TO WS-TOT-CANT
           PERFORM 8020-TOTAL-RECH
           MOVE "Tasas rechazadas:" TO WS-TOT-TEXTO
           MOVE WS-RE-INT TO WS-TOT-CANT
           PERFORM 8020-TOTAL-RECH
           MOVE "Plazos fijos rechazados:" TO WS-TOT-TEXTO
           MOVE WS-RE-PF TO WS-TOT-CANT
           PERFORM 8020-TOTAL-RECH
           MOVE "Sin tipo:" TO WS-TOT-TEXTO
           MOVE WS-RE-SIN-TIPO TO WS-TOT-CANT
           PERFORM 8020-TOTAL-RECH
           MOVE "TOTAL GENERAL RECHAZADO:" TO WS-TOT-TEXTO
           MOVE WS-TOTAL-RECH TO WS-TOT-CANT
           PERFORM 8020-TOTAL-RECH
           MOVE "TOTAL LEIDOS:" TO WS-TOT-TEXTO
           MOVE WS-NRO-LINEA TO WS-TOT-CANT
           PERFORM 8020-TOTAL-RECH.

       8010-TOTAL-OK.
           DISPLAY "  " WS-LIN-TOTAL
           MOVE WS-LIN-TOTAL TO WS-LINEA-REP
           PERFORM 8100-ESCRIBIR-OK.

       8020-TOTAL-RECH.
           DISPLAY "  " WS-LIN-TOTAL
           MOVE WS-LIN-TOTAL TO WS-LINEA-REP
           PERFORM 8200-ESCRIBIR-RECH.

       8100-ESCRIBIR-OK.
           MOVE "carga_ok.txt" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-OK FROM WS-LINEA-REP
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

       8200-ESCRIBIR-RECH.
           MOVE "carga_rechazos.txt" TO WS-ARCHIVO
           MOVE "WRITE" TO WS-OPERACION
           WRITE REG-RECH FROM WS-LINEA-REP
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Cierra todo antes de renombrar (en Windows no se puede
      * renombrar un archivo abierto).
       8500-CERRAR-ARCHIVOS.
           MOVE "CLOSE" TO WS-OPERACION
           MOVE WS-NOMBRE-CARGA TO WS-ARCHIVO
           CLOSE ARCH-CARGA
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "clientes_v3.dat" TO WS-ARCHIVO
           CLOSE ARCH-CLIENTES
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "intereses.dat" TO WS-ARCHIVO
           CLOSE ARCH-INTERESES
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "plazofijo.dat" TO WS-ARCHIVO
           CLOSE ARCH-PLAZOFIJO
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "carga_ok.txt" TO WS-ARCHIVO
           CLOSE ARCH-OK
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF
           MOVE "carga_rechazos.txt" TO WS-ARCHIVO
           CLOSE ARCH-RECH
           IF NOT FS-OK
               PERFORM 9000-ERROR-ARCHIVO
           END-IF.

      * Renombra el archivo de carga a
      * <nombre>.procesado.AAAAMMDD.HHMMSS con CBL_RENAME_FILE (rutina
      * del sistema de GnuCOBOL; devuelve 0 si salio bien). El CALL
      * pisa RETURN-CODE: por eso el codigo final se fija despues.
       8600-RENOMBRAR-CARGA.
           MOVE FUNCTION CURRENT-DATE TO WS-FECHA-HORA
           MOVE SPACES TO WS-NOMBRE-NUEVO
           STRING FUNCTION TRIM(WS-NOMBRE-CARGA) ".procesado."
               WS-FECHA-PROCESO "." WS-FECHA-HORA(9:6)
               DELIMITED BY SIZE INTO WS-NOMBRE-NUEVO
           CALL "CBL_RENAME_FILE" USING WS-NOMBRE-CARGA
                                        WS-NOMBRE-NUEVO
           MOVE RETURN-CODE TO WS-RC-RENOMBRAR
           IF WS-RC-RENOMBRAR NOT = 0
               DISPLAY "No se pudo renombrar "
                   FUNCTION TRIM(WS-NOMBRE-CARGA)
               DISPLAY "Lo cargado YA quedo grabado: renombrelo a mano"
               DISPLAY "antes de volver a correr la carga."
               MOVE 8 TO RETURN-CODE
               DISPLAY "Carga terminada con error (codigo 8)."
               STOP RUN
           END-IF
           DISPLAY "Archivo renombrado a: "
               FUNCTION TRIM(WS-NOMBRE-NUEVO).

      * Error de E/S inesperado: informa operacion, archivo y FILE
      * STATUS (mismos significados que 9000-ERROR-ARCHIVO de
      * GESTION-BANCARIA) y termina con codigo 8.
       9000-ERROR-ARCHIVO.
           DISPLAY "Error de archivo en " WS-OPERACION
               " sobre " FUNCTION TRIM(WS-ARCHIVO)
           DISPLAY "FILE STATUS: " WS-FS
           EVALUATE WS-FS
               WHEN "30"
                   DISPLAY "Archivo ilegible o corrupto."
               WHEN "35"
                   DISPLAY "El archivo no existe."
               WHEN "37"
                   DISPLAY "Sin permisos sobre el archivo."
               WHEN "39"
                   DISPLAY "Formato incompatible."
               WHEN "61"
                   DISPLAY "Archivo en uso por otro programa."
               WHEN OTHER
                   DISPLAY "Codigo no previsto; revisar el archivo."
           END-EVALUATE
           PERFORM 9900-TERMINAR-CON-ERROR.

      * Cierra todo y termina con codigo 8, SIN renombrar el archivo
      * de carga. Cerrar un archivo que no estaba abierto solo da
      * FILE STATUS 42, que aca se ignora.
       9900-TERMINAR-CON-ERROR.
           CLOSE ARCH-CARGA
           CLOSE ARCH-CLIENTES
           CLOSE ARCH-INTERESES
           CLOSE ARCH-PLAZOFIJO
           CLOSE ARCH-OK
           CLOSE ARCH-RECH
           DISPLAY "Carga terminada con error (codigo 8)."
           MOVE 8 TO RETURN-CODE
           STOP RUN.
