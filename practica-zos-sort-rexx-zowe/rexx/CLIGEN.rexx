/* REXX */
ADDRESS TSO
estados = 'A I'
n = 0
n = n + 1; jcl.n = '//GENJOB1  JOB ,MSGLEVEL=(2,0),CLASS=7'
n = n + 1; jcl.n = '//BORRA    EXEC PGM=IEFBR14'
DO k = 1 TO WORDS(estados)
  e = WORD(estados,k)
  n = n + 1
  jcl.n = '//D'k'       DD DSN=ZID.CLIENTES.EST.'e',DISP=(MOD,DELETE),'
  n = n + 1; jcl.n = '//            SPACE=(TRK,(1,1))'
END
DO k = 1 TO WORDS(estados)
  e = WORD(estados,k)
  n = n + 1; jcl.n = '//SORT'k'    EXEC PGM=SORT'
  n = n + 1; jcl.n = '//SYSOUT   DD SYSOUT=*'
  n = n + 1; jcl.n = '//SORTIN   DD DSN=ZID.CLIENTES.PLANO,DISP=SHR'
  n = n + 1
  jcl.n = '//SORTOUT  DD DSN=ZID.CLIENTES.EST.'e',DISP=(NEW,CATLG,DELETE),'
  n = n + 1; jcl.n = '//            SPACE=(TRK,(5,5),RLSE),RECFM=FB,LRECL=107'
  n = n + 1; jcl.n = '//SYSIN    DD *'
  n = n + 1; jcl.n = "  INCLUDE COND=(107,1,CH,EQ,C'"e"')"
  n = n + 1; jcl.n = '  OPTION COPY'
  n = n + 1; jcl.n = '/*'
END
jcl.0 = n
"ALLOC F(SAL) DA('ZID.JCLGEN') OLD REUSE"
"EXECIO" jcl.0 "DISKW SAL (STEM JCL. FINIS"
"FREE F(SAL)"
SAY 'Lineas generadas:' jcl.0
