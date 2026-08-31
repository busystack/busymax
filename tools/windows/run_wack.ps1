param(
  [Parameter(Mandatory)][string]$PackagePath,
  [string]$ReportPath = 'build\windows\store\wack-report.xml'
)

& "$PSScriptRoot/check_prerequisites.ps1" -RequireWack | Out-Host
$appCert = Join-Path ${env:ProgramFiles(x86)} `
  'Windows Kits\10\App Certification Kit\appcert.exe'
$directory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $directory | Out-Null
& $appCert reset
if ($LASTEXITCODE -ne 0) { throw 'Windows App Certification Kit reset failed.' }
& $appCert test -appxpackagepath $PackagePath -reportoutputpath $ReportPath
if ($LASTEXITCODE -ne 0) { throw 'Windows App Certification Kit failed.' }
if (-not (Test-Path -LiteralPath $ReportPath)) { throw 'WACK did not emit a report.' }
Write-Host "WACK report: $ReportPath"
