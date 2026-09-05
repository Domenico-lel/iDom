#Requires -RunAsAdministrator
[CmdletBinding()]
param([switch]$RemoveCredentials)
$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:ProgramFiles 'iDom Remote'
$task = Get-ScheduledTask -TaskName 'iDom Remote' -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName 'iDom Remote'
    Unregister-ScheduledTask -TaskName 'iDom Remote' -Confirm:$false
}
if ($RemoveCredentials) { Remove-Item (Join-Path $installDir 'config.json') -ErrorAction SilentlyContinue }
Write-Host 'Avvio automatico rimosso. Il servizio iDom è stato fermato; eventuali conti alla rovescia iDom sono annullati.'
Write-Host 'Per rimuovere anche la pubblicazione Tailscale dedicata, esegui: tailscale serve --https=8443 off'
Write-Host 'La cartella in Program Files resta disponibile per aggiornamento o rimozione manuale.'
