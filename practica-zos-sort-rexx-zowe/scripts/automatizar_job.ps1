# automatizar_job.ps1
# Envia un JCL a z/OS con Zowe CLI y revisa el codigo de retorno
param(
    [Parameter(Mandatory=$true)]
    [string]$Jcl
)

if (-not (Test-Path $Jcl)) {
    Write-Host "No existe el archivo: $Jcl" -ForegroundColor Red
    exit 2
}

Write-Host "Enviando $Jcl ..."
$salida = zowe zos-jobs submit local-file $Jcl --wait-for-output --response-format-json | ConvertFrom-Json

$jobid   = $salida.data.jobid
$retcode = $salida.data.retcode

Write-Host "Job: $jobid"
Write-Host "Codigo de retorno: $retcode"

if ($retcode -eq "CC 0000") {
    Write-Host "OK: el job termino bien." -ForegroundColor Green
    exit 0
} else {
    Write-Host "ATENCION: el job no termino con CC 0000." -ForegroundColor Yellow
    Write-Host "Para ver el listado: zowe zos-jobs view all-spool-content $jobid"
    exit 1
}