param(
  [Parameter(Mandatory)][string]$PackagePath,
  [string]$ReportPath = 'build\windows\store\wack-report.xml',
  [string]$WarningDispositionPath = '',
  [string]$SummaryPath = 'build\windows\store\wack-summary.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/wack_report.ps1"

if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) {
  throw "WACK package does not exist: $PackagePath"
}
$packageHash = (Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash

& "$PSScriptRoot/check_prerequisites.ps1" `
  -RequireWindows11 -RequireWack | Out-Host
$appCert = Join-Path ${env:ProgramFiles(x86)} `
  'Windows Kits\10\App Certification Kit\appcert.exe'
$directory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $directory | Out-Null
& $appCert reset
if ($LASTEXITCODE -ne 0) { throw 'Windows App Certification Kit reset failed.' }
& $appCert test -appxpackagepath $PackagePath -reportoutputpath $ReportPath
$appCertExitCode = $LASTEXITCODE
$analysis = Read-BusyMaxWackReport -ReportPath $ReportPath
$warnings = @($analysis.Warnings)
if ($warnings.Count -gt 0) {
  Write-Host 'WACK warnings:'
  $warnings | ForEach-Object { Write-Host "  - $_" }
}
Assert-BusyMaxWackWarningDispositions -Warnings $warnings `
  -WarningDispositionPath $WarningDispositionPath

$summary = [pscustomobject]@{
  Package = [IO.Path]::GetFullPath($PackagePath)
  PackageSHA256 = $packageHash
  Report = [IO.Path]::GetFullPath($ReportPath)
  OverallResult = $analysis.OverallResult
  AppCertExitCode = $appCertExitCode
  ResultCount = $analysis.ResultCount
  FailureCount = $analysis.FailureNames.Count
  Warnings = $warnings
  WarningDispositionPath = if ($warnings.Count -gt 0) {
    [IO.Path]::GetFullPath($WarningDispositionPath)
  } else { $null }
}
$summaryDirectory = Split-Path -Parent $SummaryPath
if (-not [string]::IsNullOrWhiteSpace($summaryDirectory)) {
  New-Item -ItemType Directory -Force -Path $summaryDirectory | Out-Null
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $SummaryPath `
  -Encoding utf8NoBOM

if ($analysis.FailureNames.Count -gt 0) {
  throw "WACK reported failed tests: $($analysis.FailureNames -join ', ')"
}
if ($analysis.OverallResult -notin @('PASS', 'PASSED', 'PASS WITH WARNINGS', 'PASSED WITH WARNINGS')) {
  throw "WACK overall result is not passing: $($analysis.OverallResult)"
}
if ($appCertExitCode -ne 0) {
  throw "WACK process exited with code $appCertExitCode despite producing a report."
}
Write-Host "WACK report passed: $ReportPath"
$summary
