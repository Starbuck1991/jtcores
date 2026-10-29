$ErrorActionPreference = 'Stop'

$quartusMap = 'D:\Dropbox\dev\Mister\tools\quartus-19.1\quartus\bin64\quartus_map.exe'
$testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $testDir

$activeQuartus = Get-Process quartus_map -ErrorAction SilentlyContinue
if ($activeQuartus) {
    Write-Host 'Quartus ya está ejecutándose. No se iniciará otra copia.' -ForegroundColor Yellow
    Read-Host 'Pulsa Intro para cerrar esta ventana'
    exit 2
}

Write-Host 'Comprobando el motor real de récords y su transporte MiSTer con Quartus...'
& $quartusMap --read_settings_files=on --write_settings_files=off hiscore_lint -c hiscore_lint
$result = $LASTEXITCODE

if ($result -eq 0) {
    Write-Host 'COMPLETADO: Quartus no ha encontrado errores de análisis.' -ForegroundColor Green
} else {
    Write-Host "ERROR: Quartus ha terminado con código $result." -ForegroundColor Red
}

Read-Host 'Pulsa Intro para cerrar esta ventana'
exit $result
