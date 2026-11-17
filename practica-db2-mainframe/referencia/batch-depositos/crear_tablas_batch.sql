-- =====================================================================
-- Tablas de apoyo del proceso batch DEPOSITO-DB2-BATCH (Db2 LUW)
--
-- DISENO DE REFERENCIA - NO EJECUTADO TODAVIA EN LA BASE TESTDB.
-- Para correrlo (dentro del contenedor, como db2inst1):
--   db2 connect to testdb
--   db2 -tvf crear_tablas_batch.sql
--
-- Requiere que CLIENTES tenga DNI como clave primaria.
-- =====================================================================

-- ---------------------------------------------------------------------
-- HISTORIAL_DEPOSITOS: una fila por deposito aplicado.
-- La referencia es la clave: si se intenta aplicar dos veces la misma
-- referencia, el INSERT falla con SQLCODE -803 (duplicado) y el
-- programa lo informa como "ya aplicado" (codigo 08).
-- ---------------------------------------------------------------------
CREATE TABLE HISTORIAL_DEPOSITOS (
    REFERENCIA     CHAR(20)       NOT NULL,
    LOTE_ID        CHAR(20)       NOT NULL,
    NRO_REG        INTEGER        NOT NULL,
    DNI            INTEGER        NOT NULL,
    MONTO          DECIMAL(11,2)  NOT NULL,
    FECHA_PROCESO  DATE           NOT NULL,
    CONSTRAINT PK_HIST_DEP PRIMARY KEY (REFERENCIA),
    CONSTRAINT FK_HIST_CLI FOREIGN KEY (DNI) REFERENCES CLIENTES (DNI)
);

-- Para consultar por lote (por ejemplo, para regenerar un listado).
CREATE INDEX IX_HIST_LOTE ON HISTORIAL_DEPOSITOS (LOTE_ID, NRO_REG);

-- ---------------------------------------------------------------------
-- CONTROL_PROCESO: el checkpoint. Una fila por proceso y lote.
--   ULTIMO_REG  ultimo registro del archivo ya confirmado
--   APLICADOS / RECHAZADOS / MONTO_*  contadores acumulados
--   ESTADO      P = en proceso (se puede reiniciar), F = finalizado
-- Se actualiza en la MISMA transaccion que el saldo del cliente.
-- ---------------------------------------------------------------------
CREATE TABLE CONTROL_PROCESO (
    PROCESO        CHAR(20)       NOT NULL,
    LOTE_ID        CHAR(20)       NOT NULL,
    ULTIMO_REG     INTEGER        NOT NULL,
    APLICADOS      INTEGER        NOT NULL,
    RECHAZADOS     INTEGER        NOT NULL,
    MONTO_LEIDO    DECIMAL(15,2)  NOT NULL,
    MONTO_OK       DECIMAL(15,2)  NOT NULL,
    MONTO_RECH     DECIMAL(15,2)  NOT NULL,
    ESTADO         CHAR(1)        NOT NULL,
    FECHA_ULT_ACT  TIMESTAMP      NOT NULL,
    CONSTRAINT PK_CTL_PROC PRIMARY KEY (PROCESO, LOTE_ID),
    CONSTRAINT CK_CTL_ESTADO CHECK (ESTADO IN ('P', 'F'))
);

-- =====================================================================
-- Consultas utiles (no se ejecutan con el script; copiar y correr)
-- =====================================================================

-- Estado de un lote (reemplazar el ID):
--   SELECT ULTIMO_REG, APLICADOS, RECHAZADOS, ESTADO, FECHA_ULT_ACT
--     FROM CONTROL_PROCESO
--    WHERE PROCESO = 'DEPOSITO-DB2-BATCH' AND LOTE_ID = 'LOTE-001';

-- Regenerar el listado de aplicados desde la base (la fuente de
-- verdad si un corte dejo el archivo RPTOK incompleto):
--   SELECT H.NRO_REG, H.DNI, C.NOMBRE, H.REFERENCIA, H.MONTO
--     FROM HISTORIAL_DEPOSITOS H
--     JOIN CLIENTES C ON C.DNI = H.DNI
--    WHERE H.LOTE_ID = 'LOTE-001'
--    ORDER BY H.NRO_REG;

-- Total aplicado de un lote (debe coincidir con MONTO_OK del control):
--   SELECT COUNT(*), SUM(MONTO)
--     FROM HISTORIAL_DEPOSITOS
--    WHERE LOTE_ID = 'LOTE-001';
