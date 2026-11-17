      *================================================================
      * DEPOMAP - MAPA SIMBOLICO DEL MAPSET DEPOMS (REFERENCIA)
      * LO GENERA EL ENSAMBLADOR DE BMS A PARTIR DE DEPOMS.BMS (SE
      * OBTIENE UN COPYBOOK COMO ESTE). SE MUESTRA PARA ENTENDER QUE
      * CAMPOS TIENE EL PROGRAMA. POR CADA CAMPO CON NOMBRE:
      *   xxxL  LARGO DE LO QUE ESCRIBIO EL USUARIO (COMP S9(4))
      *   xxxF  BYTE DE ATRIBUTO (SE USA PARA CAMBIAR EL FORMATO)
      *   xxxI  DATO RECIBIDO (MAPA DE ENTRADA)
      *   xxxO  DATO A ENVIAR (MAPA DE SALIDA, MISMA MEMORIA)
      *================================================================
       01  DEPOMAPI.
           02  FILLER PIC X(12).
           02  DNIL    COMP  PIC  S9(4).
           02  DNIF    PICTURE X.
           02  FILLER REDEFINES DNIF.
             03 DNIA    PICTURE X.
           02  DNII  PIC X(8).
           02  MONTOL    COMP  PIC  S9(4).
           02  MONTOF    PICTURE X.
           02  FILLER REDEFINES MONTOF.
             03 MONTOA    PICTURE X.
           02  MONTOI  PIC X(12).
           02  NOMBREL    COMP  PIC  S9(4).
           02  NOMBREF    PICTURE X.
           02  FILLER REDEFINES NOMBREF.
             03 NOMBREA    PICTURE X.
           02  NOMBREI  PIC X(30).
           02  SALDOL    COMP  PIC  S9(4).
           02  SALDOF    PICTURE X.
           02  FILLER REDEFINES SALDOF.
             03 SALDOA    PICTURE X.
           02  SALDOI  PIC X(17).
           02  MSGL    COMP  PIC  S9(4).
           02  MSGF    PICTURE X.
           02  FILLER REDEFINES MSGF.
             03 MSGA    PICTURE X.
           02  MSGI  PIC X(76).
       01  DEPOMAPO REDEFINES DEPOMAPI.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  DNIO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  MONTOO  PIC X(12).
           02  FILLER PICTURE X(3).
           02  NOMBREO  PIC X(30).
           02  FILLER PICTURE X(3).
           02  SALDOO  PIC X(17).
           02  FILLER PICTURE X(3).
           02  MSGO  PIC X(76).
