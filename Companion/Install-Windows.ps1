#Requires -RunAsAdministrator
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:ProgramFiles 'iDom Remote'
$sourceExe = Join-Path $PSScriptRoot 'iDomRemote.exe'
$sourceRuntime = Join-Path $PSScriptRoot '_internal'
$taskName = 'iDom Remote'
if (-not (Test-Path $sourceExe) -or -not (Test-Path $sourceRuntime)) { throw 'Estrai tutta la cartella scaricata: servono iDomRemote.exe e la cartella _internal.' }
$tailscale = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
if (-not (Test-Path $tailscale)) { throw 'Installa prima Tailscale per Windows ed entra nel tuo account.' }
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    throw 'iDom Remote è già installato. Per aggiornare: disinstalla conservando le credenziali, poi installa la nuova versione.'
}
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
# Files executed at boot as SYSTEM must not be writable by ordinary users.
& icacls.exe $installDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Impossibile proteggere la cartella di installazione.' }
Copy-Item $sourceExe (Join-Path $installDir 'iDomRemote.exe') -Force
Copy-Item $sourceRuntime $installDir -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot 'Uninstall-Windows.ps1') $installDir -Force
$exe = Join-Path $installDir 'iDomRemote.exe'
$config = Join-Path $installDir 'config.json'
if (-not (Test-Path $config)) {
    & $exe --config $config --init pc
    if ($LASTEXITCODE -ne 0) { throw 'Creazione configurazione non riuscita.' }
}
& $exe --config $config --check
if ($LASTEXITCODE -ne 0) { throw 'Configurazione non valida.' }
$action = New-ScheduledTaskAction -Execute $exe -Argument ('--config "{0}"' -f $config) -WorkingDirectory $installDir
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Accetta solo comandi alimentazione autenticati da iDom tramite Tailscale.' | Out-Null
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 3
$localConfig = Get-Content $config -Raw | ConvertFrom-Json
$headers = @{ Authorization = 'Bearer ' + $localConfig.token }
$status = Invoke-RestMethod -Uri 'http://127.0.0.1:47321/v1/status' -Headers $headers -TimeoutSec 10
if ($status.role -ne 'pc' -or $status.simulated) { throw 'Il componente non risponde correttamente.' }
Write-Host 'Componente Windows installato e verificato.'
Write-Host 'In Tailscale attiva Run unattended (Esegui senza accesso utente).'
Write-Host 'Poi esegui in questo terminale:'
Write-Host ('& "{0}" serve --bg --https=8443 http://127.0.0.1:47321' -f $tailscale)
Write-Host 'Se richiesto, segui il collegamento per abilitare HTTPS. Usa solo Serve, mai Funnel.'
Write-Host 'Inserisci in iDom questo indirizzo HTTPS, con porta :8443.'
Write-Host 'Questa è la chiave privata da copiare nel campo Chiave di collegamento (non inviarla in chat):'
Write-Host $localConfig.token
Write-Host 'Puoi ritrovarla nel file config.json della cartella di installazione, come amministratore.'
