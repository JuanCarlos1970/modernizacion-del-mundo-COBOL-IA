-- =====================================================================
--  consultas_lab.sql
--
--  Consultas sobre las tres tablas cargadas (INTERESES, CLIENTES y
--  PLAZOS_FIJOS) para ver como quedo la carga y compararla con lo que
--  informo COBOL.
--
--  Uso (dentro del contenedor, como db2inst1):
--      db2 -tvf /tmp/consultas_lab.sql
-- =====================================================================

CONNECT TO TESTDB;

-- 1) Cantidad de filas por tabla. Tiene que dar 8, 1000 y 567: lo
--    mismo que cargo COBOL.
SELECT 'INTERESES' AS TABLA, COUNT(*) AS FILAS FROM INTERESES
UNION ALL
SELECT 'CLIENTES', COUNT(*) FROM CLIENTES
UNION ALL
SELECT 'PLAZOS_FIJOS', COUNT(*) FROM PLAZOS_FIJOS;

-- 2) Plazos fijos con el nombre de su titular (JOIN con CLIENTES).
--    Las claves foraneas garantizan que siempre haya un titular.
SELECT P.PF_NRO, C.DNI, C.NOMBRE, P.MONEDA, P.MONTO, P.DIAS,
       P.TNA_APLICADA, P.TOTAL, P.FECHA_VENC
  FROM PLAZOS_FIJOS P
  JOIN CLIENTES C ON C.DNI = P.DNI
 ORDER BY P.PF_NRO
 FETCH FIRST 10 ROWS ONLY;

-- 3) Totales por moneda y plazo, con la tasa vigente de INTERESES
--    (JOIN con la clave compuesta moneda + dias).
SELECT P.MONEDA, P.DIAS, COUNT(*) AS CANTIDAD,
       SUM(P.MONTO) AS CAPITAL, SUM(P.INTERES) AS INTERES,
       SUM(P.TOTAL) AS TOTAL, I.TNA AS TNA_VIGENTE
  FROM PLAZOS_FIJOS P
  JOIN INTERESES I ON I.MONEDA = P.MONEDA AND I.DIAS = P.DIAS
 GROUP BY P.MONEDA, P.DIAS, I.TNA
 ORDER BY P.MONEDA, P.DIAS;

-- 4) CONTROL CONTRA COBOL: sumas por moneda. El listado
--    listado_plazos_ok.txt informo:
--      pesos:    capital 11.241.260.000,00  total 12.209.767.958,93
--      dolares:  capital      3.732.000,00  total      3.744.129,03
SELECT MONEDA, COUNT(*) AS CANTIDAD, SUM(MONTO) AS CAPITAL,
       SUM(TOTAL) AS TOTAL
  FROM PLAZOS_FIJOS
 GROUP BY MONEDA
 ORDER BY MONEDA;

-- 5) Clientes con mas de un plazo fijo (los 10 con mas).
SELECT C.DNI, C.NOMBRE, COUNT(*) AS PLAZOS_FIJOS, SUM(P.MONTO) AS CAPITAL
  FROM CLIENTES C
  JOIN PLAZOS_FIJOS P ON P.DNI = C.DNI
 GROUP BY C.DNI, C.NOMBRE
HAVING COUNT(*) > 1
 ORDER BY COUNT(*) DESC, C.DNI
 FETCH FIRST 10 ROWS ONLY;

-- 6) Clientes que no tienen ningun plazo fijo (LEFT JOIN).
SELECT COUNT(*) AS CLIENTES_SIN_PLAZO_FIJO
  FROM CLIENTES C
  LEFT JOIN PLAZOS_FIJOS P ON P.DNI = C.DNI
 WHERE P.PF_NRO IS NULL;

-- 7) Integridad: plazos fijos sin cliente o sin tasa. Tienen que ser 0
--    y 0 (las claves foraneas no dejaron entrar ninguno).
SELECT COUNT(*) AS PF_SIN_CLIENTE
  FROM PLAZOS_FIJOS P
  LEFT JOIN CLIENTES C ON C.DNI = P.DNI
 WHERE C.DNI IS NULL;

SELECT COUNT(*) AS PF_SIN_TASA
  FROM PLAZOS_FIJOS P
  LEFT JOIN INTERESES I ON I.MONEDA = P.MONEDA AND I.DIAS = P.DIAS
 WHERE I.MONEDA IS NULL;

-- 8) CONTROL CRUZADO: recalcular en SQL el interes que COBOL calculo
--    (MONTO x TNA x DIAS / 36500, redondeado al centavo) y contar las
--    diferencias. Tiene que dar 0.
SELECT COUNT(*) AS INTERESES_DISTINTOS
  FROM PLAZOS_FIJOS
 WHERE ROUND(MONTO * TNA_APLICADA * DIAS / 36500, 2) <> INTERES;

-- 9) Y que el total sea capital + interes. Tiene que dar 0.
SELECT COUNT(*) AS TOTALES_DISTINTOS
  FROM PLAZOS_FIJOS
 WHERE MONTO + INTERES <> TOTAL;

CONNECT RESET;
