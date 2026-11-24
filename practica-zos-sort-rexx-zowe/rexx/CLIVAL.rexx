/* REXX */
ADDRESS TSO
"ALLOC F(ENT) DA('ZID.CLIENTES.PRUEBA') SHR REUSE"
"EXECIO * DISKR ENT (STEM REG. FINIS"
"FREE F(ENT)"
malos = 0
DO i = 1 TO reg.0
  dni = SUBSTR(reg.i,1,8)
  IF DATATYPE(dni,'W') = 0 THEN DO
    malos = malos + 1
    SAY 'Registro' i 'con DNI no numerico:' dni
  END
END
SAY 'Leidos:' reg.0 ' DNI invalidos:' malos
