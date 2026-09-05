#Requires -RunAsAdministrator
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$task = Get-ScheduledTask -TaskName 'iDom WhatsApp' -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName 'iDom WhatsApp'
    Unregister-ScheduledTask -TaskName 'iDom WhatsApp' -Confirm:$false
}
Write-Host 'Componente fermato. Sessione e coda sono conservate per un eventuale aggiornamento.'
Write-Host 'Se riavvii il componente, i messaggi ancora programmati potranno partire.'
Write-Host 'Per revocare WhatsApp: iPhone > WhatsApp > Impostazioni > Dispositivi collegati > iDom > Disconnetti.'
Write-Host 'Per rimuovere la pubblicazione dedicata: tailscale serve --https=8444 off'
