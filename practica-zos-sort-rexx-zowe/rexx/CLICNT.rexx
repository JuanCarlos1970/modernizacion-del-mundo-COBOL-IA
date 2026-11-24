/* REXX */
ADDRESS TSO
"ALLOC F(ENT) DA('ZID.CLIENTES.PLANO') SHR REUSE"
"EXECIO * DISKR ENT (STEM REG. FINIS"
"FREE F(ENT)"
act = 0
DO i = 1 TO reg.0
  IF SUBSTR(reg.i,107,1) = 'A' THEN act = act + 1
END
SAY 'Leidos:' reg.0 ' Activos:' act
