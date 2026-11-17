-- =====================================================================
--  crear_tablas_lab.sql
--
--  Crea en Db2 (base TESTDB) las tres tablas del laboratorio, con los
--  mismos campos y largos que los copybooks CLIENTE.cpy, INTERES.cpy
--  y PLAZOFIJO.cpy, mas las reglas que en COBOL se validaban a mano:
--    - claves primarias (PRIMARY KEY)
--    - claves foraneas (FOREIGN KEY): un plazo fijo solo puede existir
--      si existe su cliente titular y la tasa de su moneda y plazo
--    - restricciones de valores validos (CHECK)
--
--  Uso (dentro del contenedor, como db2inst1):
--      db2 -tvf /tmp/crear_tablas_lab.sql
--    -t  cada sentencia termina con ;
--    -v  muestra cada sentencia antes de ejecutarla
--    -f  lee las sentencias de un archivo
--
--  ATENCION: borra las tablas CLIENTES, INTERESES y PLAZOS_FIJOS de las
--  pruebas anteriores (si existen) y las vuelve a crear VACIAS. Si una
--  no existe, el DROP da error SQL0204N: es normal, el script sigue.
-- =====================================================================

CONNECT TO TESTDB;

-- Se borran en orden inverso a las dependencias: primero la que tiene
-- las claves foraneas (PLAZOS_FIJOS), despues las que referencia.
DROP TABLE PLAZOS_FIJOS;
DROP TABLE CLIENTES;
DROP TABLE INTERESES;

-- ---------------------------------------------------------------------
--  INTERESES  <-  INTERES.cpy  (clave: moneda + dias)
-- ---------------------------------------------------------------------
CREATE TABLE INTERESES (
    MONEDA         CHAR(1)       NOT NULL,
    DIAS           SMALLINT      NOT NULL,
    TNA            DECIMAL(5,2)  NOT NULL,
    TNA_ANTERIOR   DECIMAL(5,2)  NOT NULL,
    VIGENTE_DESDE  DATE          NOT NULL,
    ESTADO         CHAR(1)       NOT NULL,
    CONSTRAINT PK_INTERESES   PRIMARY KEY (MONEDA, DIAS),
    CONSTRAINT CK_INT_MONEDA  CHECK (MONEDA IN ('P', 'D')),
    CONSTRAINT CK_INT_DIAS    CHECK (DIAS IN (30, 60, 90, 120)),
    CONSTRAINT CK_INT_ESTADO  CHECK (ESTADO IN ('A', 'B'))
);

-- ---------------------------------------------------------------------
--  CLIENTES  <-  CLIENTE.cpy  (clave: DNI)
-- ---------------------------------------------------------------------
CREATE TABLE CLIENTES (
    DNI        INTEGER        NOT NULL,
    NOMBRE     VARCHAR(30)    NOT NULL,
    DIRECCION  VARCHAR(40)    NOT NULL,
    TELEFONO   VARCHAR(15)    NOT NULL,
    SALDO      DECIMAL(11,2)  NOT NULL,
    ESTADO     CHAR(1)        NOT NULL,
    CONSTRAINT PK_CLIENTES    PRIMARY KEY (DNI),
    CONSTRAINT CK_CLI_ESTADO  CHECK (ESTADO IN ('A', 'I', 'R'))
);

-- ---------------------------------------------------------------------
--  PLAZOS_FIJOS  <-  PLAZOFIJO.cpy  (clave: numero de plazo fijo)
-- ---------------------------------------------------------------------
CREATE TABLE PLAZOS_FIJOS (
    PF_NRO        INTEGER        NOT NULL,
    DNI           INTEGER        NOT NULL,
    MONEDA        CHAR(1)        NOT NULL,
    MONTO         DECIMAL(13,2)  NOT NULL,
    DIAS          SMALLINT       NOT NULL,
    TNA_APLICADA  DECIMAL(5,2)   NOT NULL,
    INTERES       DECIMAL(13,2)  NOT NULL,
    TOTAL         DECIMAL(13,2)  NOT NULL,
    FECHA_ALTA    DATE           NOT NULL,
    FECHA_VENC    DATE           NOT NULL,
    ESTADO        CHAR(1)        NOT NULL,
    CONSTRAINT PK_PLAZOS_FIJOS  PRIMARY KEY (PF_NRO),
    CONSTRAINT CK_PF_MONEDA     CHECK (MONEDA IN ('P', 'D')),
    CONSTRAINT CK_PF_DIAS       CHECK (DIAS IN (30, 60, 90, 120)),
    CONSTRAINT CK_PF_ESTADO     CHECK (ESTADO IN ('A', 'C', 'V')),
    CONSTRAINT FK_PF_CLIENTE    FOREIGN KEY (DNI)
        REFERENCES CLIENTES (DNI),
    CONSTRAINT FK_PF_TASA       FOREIGN KEY (MONEDA, DIAS)
        REFERENCES INTERESES (MONEDA, DIAS)
);

-- Verificacion: tienen que aparecer las tres tablas, con 6, 6 y 11
-- columnas.
SELECT TABNAME, COLCOUNT
  FROM SYSCAT.TABLES
 WHERE TABSCHEMA = CURRENT SCHEMA
   AND TABNAME IN ('INTERESES', 'CLIENTES', 'PLAZOS_FIJOS')
 ORDER BY TABNAME;

CONNECT RESET;
