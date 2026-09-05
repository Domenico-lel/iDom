#Requires -RunAsAdministrator
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskName = 'iDom WhatsApp'
$installDir = Join-Path $env:ProgramFiles 'iDom WhatsApp'
$dataDir = Join-Path $env:LOCALAPPDATA 'iDom WhatsApp'
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$tailscale = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
if (-not (Test-Path $tailscale)) { throw 'Installa e collega prima Tailscale.' }
foreach ($required in @('node.exe', 'index.mjs', 'queue.mjs', 'server.mjs', 'node_modules')) {
    if (-not (Test-Path (Join-Path $PSScriptRoot $required))) { throw 'Estrai tutta la cartella scaricata prima di installare.' }
}
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    throw 'Componente gia installato. Per aggiornare usa prima Disinstalla-WhatsApp.ps1: conserva sessione e coda.'
}
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
& icacls.exe $installDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Impossibile proteggere la cartella programma.' }
foreach ($name in @('node.exe', 'index.mjs', 'queue.mjs', 'server.mjs', 'package.json', 'node_modules', 'Collega-WhatsApp.ps1', 'Disinstalla-WhatsApp.ps1')) {
    Copy-Item (Join-Path $PSScriptRoot $name) $installDir -Recurse -Force
}
& icacls.exe (Join-Path $installDir '*') /reset /T | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Impossibile proteggere i file del programma.' }
Unblock-File -LiteralPath (Join-Path $installDir 'Collega-WhatsApp.ps1'), (Join-Path $installDir 'Disinstalla-WhatsApp.ps1')
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
& icacls.exe $dataDir /inheritance:r /grant:r ('*{0}:(OI)(CI)F' -f $sid) '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Impossibile proteggere sessione e coda.' }
$node = Join-Path $installDir 'node.exe'
$entry = Join-Path $installDir 'index.mjs'
& $node $entry --data $dataDir --init
if ($LASTEXITCODE -ne 0) { throw 'Creazione configurazione non riuscita.' }
# Browser runs at the interactive user's limited token, never as SYSTEM.
$action = New-ScheduledTaskAction -Execute $node -Argument ('"{0}" --data "{1}"' -f $entry, $dataDir) -WorkingDirectory $installDir
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $sid
$principal = New-ScheduledTaskPrincipal -UserId $sid -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 100 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Invia solo i messaggi programmati esplicitamente da iDom. Richiede utente collegato e PC acceso.' | Out-Null
Start-ScheduledTask -TaskName $taskName
$config = Get-Content (Join-Path $dataDir 'config.json') -Raw | ConvertFrom-Json
$status = $null
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    try {
        $status = Invoke-RestMethod 'http://127.0.0.1:47322/v1/status' -Headers @{ Authorization = 'Bearer ' + $config.token } -TimeoutSec 2
        break
    } catch { Start-Sleep -Seconds 1 }
}
if (-not $status -or $status.role -ne 'whatsapp' -or $status.simulated) { throw 'Servizio non avviato. Controlla iDom WhatsApp in Utilita di pianificazione.' }
if ($status.error) { throw $status.error }
Write-Host 'Componente iDom WhatsApp installato.'
Write-Host 'Da iPhone: WhatsApp > Impostazioni > Dispositivi collegati > Collega un dispositivo.'
& $node $entry --data $dataDir --pair
if ($LASTEXITCODE -ne 0) { Write-Host 'Collegamento non completato. Puoi riprovare con Collega-WhatsApp.ps1.' }
Write-Host 'Per rendere il servizio disponibile a iDom esegui:'
Write-Host ('& "{0}" serve --bg --https=8444 http://127.0.0.1:47322' -f $tailscale)
Write-Host 'Usa il nuovo indirizzo HTTPS con porta 8444, senza cambiare PC Remote sulla 8443.'
Write-Host 'Chiave privata WhatsApp per iDom (non inviarla in chat):'
Write-Host $config.token
Write-Host 'Il PC deve rimanere acceso e con questo utente entrato in Windows; puoi bloccare lo schermo.'
