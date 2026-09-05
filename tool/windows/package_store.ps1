param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [string]$ReleasePath = 'build\windows\x64\runner\Release',
  [string]$OutputDirectory = 'build\windows\store',
  [switch]$Ci
)

. "$PSScriptRoot/common.ps1"
$prerequisites = & "$PSScriptRoot/check_prerequisites.ps1"
$config = Get-BusyMaxStoreConfig -Path $ConfigPath
$mode = if ($Ci) { 'CiNonProduction' } else { 'ProductionStore' }
Assert-BusyMaxStoreConfig -Config $config -Mode $mode
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
$unpacked = Join-Path $OutputDirectory 'unpacked-final-msix'
$package = Join-Path $OutputDirectory "BusyMax-$($config.msixVersion)-x64.msix"
foreach ($managedPath in @($staging, $unpacked, $package)) {
  if ((Test-Path -LiteralPath $managedPath) -and
      -not (Test-Path -LiteralPath $ownerMarker -PathType Leaf)) {
    throw "Refusing to replace unowned Windows package output: $managedPath"
  }
}
if (Test-Path -LiteralPath $staging) {
  Remove-Item -LiteralPath $staging -Recurse -Force
}
Set-Content -LiteralPath $ownerMarker -Value 'busymax-windows-store-output-v1' `
  -Encoding ascii
New-Item -ItemType Directory -Force -Path $staging | Out-Null
Copy-Item -LiteralPath "$ReleasePath/busymax.exe" -Destination $staging
$runtimeFiles = @(
  'flutter_windows.dll', 'sqlite3.dll',
  'connectivity_plus_plugin.dll', 'file_selector_windows_plugin.dll',
  'flutter_local_notifications_windows.dll',
  'flutter_secure_storage_windows_plugin.dll',
  'flutter_timezone_plugin.dll', 'system_theme_plugin.dll',
  'tray_manager_plugin.dll', 'url_launcher_windows_plugin.dll'
)
foreach ($runtimeFile in $runtimeFiles) {
  $source = Join-Path $ReleasePath $runtimeFile
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Required Windows runtime file was not built: $runtimeFile"
  }
  Copy-Item -LiteralPath $source -Destination $staging
}
Get-ChildItem -LiteralPath $ReleasePath -File -Filter '*.dat' |
  Copy-Item -Destination $staging
Copy-BusyMaxVCRuntime -VisualStudioPath $prerequisites.VisualStudio `
  -Destination $staging
Copy-Item -LiteralPath "$ReleasePath/data" -Destination $staging -Recurse
$assets = Join-Path $staging 'Assets'
New-Item -ItemType Directory -Force -Path $assets | Out-Null
$logicalAssets = [ordered]@{
  'StoreLogo.png' = 'StoreLogo.png'
  'Square44x44Logo.png' = 'Square44x44Logo.png'
  'Square150x150Logo.png' = 'Square150x150Logo.png'
  'FileAssociationLogo.png' = 'FileAssociationLogo.png'
}
foreach ($asset in $logicalAssets.GetEnumerator()) {
  $source = Join-Path 'windows\runner\resources\msix' $asset.Value
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Required unqualified MSIX visual asset is missing: $source"
  }
  Copy-Item -LiteralPath $source -Destination (Join-Path $assets $asset.Key)
}
& "$PSScriptRoot/render_manifest.ps1" -ConfigPath $ConfigPath `
  -OutputPath (Join-Path $staging 'AppxManifest.xml') `
  -MaximumTestedVersion $prerequisites.WindowsSdk -Ci:$Ci
$stagingInventoryPath = Join-Path $OutputDirectory 'staging-inventory.json'
$stagingInventory = @(& "$PSScriptRoot/validate_package_contents.ps1" `
  -PackageRoot $staging -InventoryOutputPath $stagingInventoryPath `
  -ValidationMode Staging)
if (Test-Path -LiteralPath $package) { Remove-Item -LiteralPath $package -Force }
$makeAppx = Join-Path $prerequisites.WindowsSdkBin 'makeappx.exe'
& $makeAppx pack /v /d $staging /p $package /o
if ($LASTEXITCODE -ne 0) {
  throw 'MakeAppx schema validation or packing failed.'
}
if (Test-Path -LiteralPath $unpacked) {
  Remove-Item -LiteralPath $unpacked -Recurse -Force
}
& $makeAppx unpack /p $package /d $unpacked /o
if ($LASTEXITCODE -ne 0) { throw 'MakeAppx could not unpack the final MSIX.' }
# MakeAppx validates and unpacks package payloads but omits the OPC container
# member [Content_Types].xml. Restore both generated metadata members directly
# from the exact MSIX so validation and inventory cover the complete archive.
Expand-BusyMaxMsixMetadata -PackagePath $package -PackageRoot $unpacked
$finalInventoryPath = Join-Path $OutputDirectory 'final-msix-inventory.json'
$finalInventory = @(& "$PSScriptRoot/validate_package_contents.ps1" `
  -PackageRoot $unpacked -InventoryOutputPath $finalInventoryPath `
  -ValidationMode FinalMsix)
$packageMetadataFiles = @('AppxBlockMap.xml', '[Content_Types].xml')
$finalInventoryObjects = @($finalInventory | Where-Object {
  $_ -is [pscustomobject]
})
foreach ($metadataFile in $packageMetadataFiles) {
  if ($metadataFile -cnotin $finalInventoryObjects.Path) {
    throw "Final MSIX metadata is absent from the exact-package inventory: $metadataFile"
  }
}
$expectedInventory = @($stagingInventory | Where-Object {
  $_ -is [pscustomobject]
})
$actualInventory = @($finalInventoryObjects | Where-Object {
  $_.Path -notin $packageMetadataFiles
})
$expectedLines = @($expectedInventory | ForEach-Object {
  "$($_.Path)|$($_.Length)|$($_.SHA256)"
})
$actualLines = @($actualInventory | ForEach-Object {
  "$($_.Path)|$($_.Length)|$($_.SHA256)"
})
$difference = Compare-Object -ReferenceObject $expectedLines `
  -DifferenceObject $actualLines
if ($difference) {
  throw "The exact packed MSIX inventory differs from staging: $($difference.InputObject -join ', ')"
}
$hash = Get-FileHash -LiteralPath $package -Algorithm SHA256
$metadata = [pscustomobject]@{
  Package = (Resolve-Path $package).Path
  Version = $config.msixVersion
  Architecture = 'x64'
  MinimumOS = '10.0.26100.0'
  MaximumTestedOS = $prerequisites.WindowsSdk
  SHA256 = $hash.Hash
  Inventory = (Resolve-Path $finalInventoryPath).Path
}
$metadataPath = Join-Path $OutputDirectory 'package-metadata.json'
$metadata | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $metadataPath `
  -Encoding utf8NoBOM
$metadata
