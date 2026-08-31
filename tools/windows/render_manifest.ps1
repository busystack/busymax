param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [Parameter(Mandatory)][string]$OutputPath,
  [Parameter(Mandatory)][string]$MaximumTestedVersion,
  [switch]$Ci
)

. "$PSScriptRoot/common.ps1"
$config = Get-BusyMaxStoreConfig -Path $ConfigPath
$mode = if ($Ci) { 'CiNonProduction' } else { 'ProductionStore' }
Assert-BusyMaxStoreConfig -Config $config -Mode $mode
if ([version]$MaximumTestedVersion -lt [version]'10.0.26100.0') {
  throw 'MaximumTestedVersion must be the Windows 11 24H2 SDK or newer.'
}
$template = Get-Content -LiteralPath "$PSScriptRoot/AppxManifest.xml.template" -Raw
$rendered = $template `
  .Replace('@@IDENTITY_NAME@@', [Security.SecurityElement]::Escape($config.identityName)) `
  .Replace('@@PUBLISHER@@', [Security.SecurityElement]::Escape($config.publisher)) `
  .Replace('@@PUBLISHER_DISPLAY_NAME@@', [Security.SecurityElement]::Escape($config.publisherDisplayName)) `
  .Replace('@@PACKAGE_VERSION@@', $config.msixVersion) `
  .Replace('@@MAX_TESTED_VERSION@@', $MaximumTestedVersion) `
  .Replace('@@RESOURCE_LANGUAGES@@', (Get-BusyMaxResourceXml))
$directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $directory | Out-Null
[IO.File]::WriteAllText($OutputPath, $rendered, [Text.UTF8Encoding]::new($false))
& "$PSScriptRoot/validate_manifest.ps1" -ManifestPath $OutputPath
