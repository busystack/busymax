param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [string]$ReleasePath = 'build\windows\x64\runner\Release',
  [string]$OutputDirectory = 'build\windows\store',
  [switch]$Ci
)

. "$PSScriptRoot/common.ps1"
$prerequisites = & "$PSScriptRoot/check_prerequisites.ps1"
$config = Get-BusyMaxStoreConfig -Path $ConfigPath
Assert-BusyMaxStoreConfig -Config $config -Ci:$Ci
if (-not (Test-Path -LiteralPath "$ReleasePath/busymax.exe")) {
  throw "Windows release output was not found: $ReleasePath"
}
$workspace = [IO.Path]::GetFullPath((Get-Location).Path)
$allowedOutputRoot = [IO.Path]::GetFullPath(
  (Join-Path $workspace 'build\windows'))
$resolvedOutput = [IO.Path]::GetFullPath(
  (Join-Path $workspace $OutputDirectory))
$allowedPrefix = $allowedOutputRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedOutput.StartsWith(
    $allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Windows package output must stay below build\windows.'
}
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
$ownerMarker = Join-Path $resolvedOutput '.busymax-store-output'
$staging = Join-Path $OutputDirectory 'staging'
if ((Test-Path -LiteralPath $staging) -and
    -not (Test-Path -LiteralPath $ownerMarker -PathType Leaf)) {
  throw "Refusing to replace unowned staging directory: $staging"
}
if (Test-Path -LiteralPath $staging) {
  Remove-Item -LiteralPath $staging -Recurse -Force
}
Set-Content -LiteralPath $ownerMarker -Value 'busymax-windows-store-output-v1' `
  -Encoding ascii
New-Item -ItemType Directory -Force -Path $staging | Out-Null
Copy-Item -LiteralPath "$ReleasePath/busymax.exe" -Destination $staging
Get-ChildItem -LiteralPath $ReleasePath -File |
  Where-Object { $_.Extension -in @('.dll', '.dat') } |
  Copy-Item -Destination $staging
Copy-BusyMaxVCRuntime -VisualStudioPath $prerequisites.VisualStudio `
  -Destination $staging
Copy-Item -LiteralPath "$ReleasePath/data" -Destination $staging -Recurse
$assets = Join-Path $staging 'Assets'
New-Item -ItemType Directory -Force -Path $assets | Out-Null
Copy-Item -Path 'windows\runner\resources\msix\*' -Destination $assets
& "$PSScriptRoot/render_manifest.ps1" -ConfigPath $ConfigPath `
  -OutputPath (Join-Path $staging 'AppxManifest.xml') `
  -MaximumTestedVersion $prerequisites.WindowsSdk -Ci:$Ci
& "$PSScriptRoot/validate_package_contents.ps1" -StagingPath $staging
$package = Join-Path $OutputDirectory "BusyMax-$($config.msixVersion)-x64.msix"
if (Test-Path -LiteralPath $package) { Remove-Item -LiteralPath $package -Force }
$makeAppx = Join-Path $prerequisites.WindowsSdkBin 'makeappx.exe'
& $makeAppx pack /d $staging /p $package /o
if ($LASTEXITCODE -ne 0) { throw 'MakeAppx failed.' }
$hash = Get-FileHash -LiteralPath $package -Algorithm SHA256
[pscustomobject]@{
  Package = (Resolve-Path $package).Path
  Version = $config.msixVersion
  Architecture = 'x64'
  MinimumOS = '10.0.26100.0'
  MaximumTestedOS = $prerequisites.WindowsSdk
  SHA256 = $hash.Hash
}
