# Script para volver a habilitar el clic de la rueda cerrando el proceso de bloqueo
$procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*disable_middle_click.ps1*" }
if ($procs) {
    foreach ($p in $procs) {
        Stop-Process -Id $p.ProcessId -Force
    }
    Write-Host "Clic de rueda reactivado con exito."
} else {
    Write-Host "No habia ningun bloqueador activo."
}
