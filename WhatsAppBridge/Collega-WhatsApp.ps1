[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:ProgramFiles 'iDom WhatsApp'
$dataDir = Join-Path $env:LOCALAPPDATA 'iDom WhatsApp'
Start-ScheduledTask -TaskName 'iDom WhatsApp'
Start-Sleep -Seconds 3
& (Join-Path $installDir 'node.exe') (Join-Path $installDir 'index.mjs') --data $dataDir --pair
if ($LASTEXITCODE -ne 0) { throw 'Collegamento non completato. Riprova dopo aver controllato il componente.' }
$config = Get-Content (Join-Path $dataDir 'config.json') -Raw | ConvertFrom-Json
Write-Host 'Chiave privata da inserire solo in iDom:'
Write-Host $config.token
