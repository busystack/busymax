param(
  [Parameter(Mandatory)][Alias('StagingPath')][string]$PackageRoot,
  [string]$InventoryOutputPath = '',
  [ValidateSet('Staging', 'FinalMsix')][string]$ValidationMode = 'Staging'
)

. "$PSScriptRoot/common.ps1"

if ($ValidationMode -eq 'FinalMsix') {
  Assert-BusyMaxFinalMsixMetadata -PackageRoot $PackageRoot
}
$packageFiles = @(Get-BusyMaxPackageFiles -PackageRoot $PackageRoot)

if (-not (Test-Path -LiteralPath "$PackageRoot/busymax.exe")) {
  throw 'Staging directory does not contain busymax.exe.'
}
foreach ($required in @(
    'flutter_windows.dll', 'sqlite3.dll',
    'connectivity_plus_plugin.dll', 'file_selector_windows_plugin.dll',
    'flutter_local_notifications_windows.dll',
    'flutter_secure_storage_windows_plugin.dll',
    'flutter_timezone_plugin.dll', 'system_theme_plugin.dll',
    'tray_manager_plugin.dll', 'url_launcher_windows_plugin.dll',
    'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll',
    'data/app.so', 'data/icudtl.dat',
    'data/flutter_assets/AssetManifest.bin',
    'AppxManifest.xml')) {
  if (-not (Test-Path -LiteralPath (Join-Path $PackageRoot $required))) {
    throw "Required package file is missing: $required"
  }
}
$allowedAssets = @(
    'Assets/StoreLogo.png',
    'Assets/Square44x44Logo.png',
    'Assets/Square150x150Logo.png',
    'Assets/FileAssociationLogo.png')
foreach ($asset in $allowedAssets) {
  if (-not (Test-Path -LiteralPath (Join-Path $PackageRoot $asset))) {
    throw "Required unqualified package visual asset is missing: $asset"
  }
}
$unexpectedAssets = @($packageFiles |
  Where-Object {
    $relative = Get-BusyMaxPackageRelativePath -PackageRoot $PackageRoot `
      -Path $_.FullName
    $relative.StartsWith('Assets/', [StringComparison]::OrdinalIgnoreCase) -and
      $relative -notin $allowedAssets
  })
if ($unexpectedAssets.Count -gt 0) {
  throw "Unexpected or unreferenced package visual asset: $($unexpectedAssets.FullName -join ', ')"
}
$qualifiedVisualAssets = @($packageFiles | Where-Object {
    $relative = Get-BusyMaxPackageRelativePath -PackageRoot $PackageRoot `
      -Path $_.FullName
    $relative.StartsWith('Assets/', [StringComparison]::OrdinalIgnoreCase) -and
      $_.Name -match '(?i)\.(scale|targetsize)-'
  })
if ($qualifiedVisualAssets.Count -gt 0) {
  throw 'Qualified visual assets require a generated resources.pri and must not be staged by the unqualified-asset packaging path.'
}
if (Test-Path -LiteralPath (Join-Path $PackageRoot 'resources.pri')) {
  throw 'The unqualified-asset packaging path must not contain a stale resources.pri.'
}
Assert-BusyMaxPackageHasNoProhibitedFiles -PackageRoot $PackageRoot
$executables = @($packageFiles | Where-Object { $_.Extension -ieq '.exe' })
if ($executables.Count -ne 1 -or $executables[0].Name -cne 'busymax.exe') {
  throw "The package must contain only busymax.exe: $($executables.FullName -join ', ')"
}
$allowedDlls = @(
  'flutter_windows.dll', 'sqlite3.dll',
  'connectivity_plus_plugin.dll', 'file_selector_windows_plugin.dll',
  'flutter_local_notifications_windows.dll',
  'flutter_secure_storage_windows_plugin.dll',
  'flutter_timezone_plugin.dll', 'system_theme_plugin.dll',
  'tray_manager_plugin.dll', 'url_launcher_windows_plugin.dll',
  'concrt140.dll', 'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll',
  'msvcp140_atomic_wait.dll', 'msvcp140_codecvt_ids.dll', 'vccorlib140.dll',
  'vcruntime140.dll', 'vcruntime140_1.dll', 'vcruntime140_threads.dll'
)
$unexpectedDlls = @($packageFiles | Where-Object { $_.Extension -ieq '.dll' } |
  Where-Object {
    $relative = Get-BusyMaxPackageRelativePath -PackageRoot $PackageRoot `
      -Path $_.FullName
    $_.Name -notin $allowedDlls -or $relative -cne $_.Name
  })
if ($unexpectedDlls) {
  throw "Unexpected package DLLs: $($unexpectedDlls.FullName -join ', ')"
}
function Assert-BusyMaxX64Pe {
  param([Parameter(Mandatory)][string]$Path)
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
    throw "Packaged native binary is not a Windows PE file: $Path"
  }
  $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
  if ($peOffset -lt 0 -or $peOffset + 6 -gt $bytes.Length -or
      $bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45 -or
      $bytes[$peOffset + 2] -ne 0 -or $bytes[$peOffset + 3] -ne 0 -or
      [BitConverter]::ToUInt16($bytes, $peOffset + 4) -ne 0x8664) {
    throw "Packaged native binary is not x64 PE: $Path"
  }
}
foreach ($nativeBinary in @(
    Get-ChildItem -LiteralPath $PackageRoot -File -Filter '*.exe' -Force
    Get-ChildItem -LiteralPath $PackageRoot -File -Filter '*.dll' -Force
  )) {
  Assert-BusyMaxX64Pe -Path $nativeBinary.FullName
}
function Assert-BusyMaxX64Elf {
  param([Parameter(Mandatory)][string]$Path)
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt 20 -or
      $bytes[0] -ne 0x7f -or $bytes[1] -ne 0x45 -or
      $bytes[2] -ne 0x4c -or $bytes[3] -ne 0x46 -or
      $bytes[4] -ne 2 -or $bytes[5] -ne 1 -or
      [BitConverter]::ToUInt16($bytes, 18) -ne 0x3e) {
    throw "Flutter AOT artifact is not a little-endian x64 ELF file: $Path"
  }
}
Assert-BusyMaxX64Elf -Path `
  (Join-Path $PackageRoot 'data/app.so')
$manifestPath = Join-Path $PackageRoot 'AppxManifest.xml'
& "$PSScriptRoot/validate_manifest.ps1" -ManifestPath $manifestPath
[xml]$packageManifest = Get-Content -LiteralPath $manifestPath -Raw
$manifestNamespaces = [System.Xml.XmlNamespaceManager]::new(
  $packageManifest.NameTable)
$manifestNamespaces.AddNamespace(
  'f', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
$manifestNamespaces.AddNamespace(
  'uap', 'http://schemas.microsoft.com/appx/manifest/uap/windows10')
$propertiesLogo = $packageManifest.SelectSingleNode(
  '/f:Package/f:Properties/f:Logo', $manifestNamespaces)
$visualElements = $packageManifest.SelectSingleNode(
  '//uap:VisualElements', $manifestNamespaces)
$fileAssociationLogo = $packageManifest.SelectSingleNode(
  '//uap:FileTypeAssociation/uap:Logo', $manifestNamespaces)
if ($null -eq $propertiesLogo -or $null -eq $visualElements -or
    $null -eq $fileAssociationLogo) {
  throw 'The exact package manifest is missing required logo declarations.'
}
$logoReferences = @(
  [string]$propertiesLogo.InnerText
  [string]$visualElements.Square44x44Logo
  [string]$visualElements.Square150x150Logo
  [string]$fileAssociationLogo.InnerText
) | Sort-Object -Unique
if ($logoReferences.Count -ne 4) {
  throw 'The manifest must contain exactly four distinct BusyMax logo paths.'
}
foreach ($reference in $logoReferences) {
  if ([string]::IsNullOrWhiteSpace($reference) -or
      [IO.Path]::IsPathRooted($reference) -or
      $reference -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "Manifest logo path is unsafe: $reference"
  }
  $resolvedReference = $reference.Replace(
    '\', [IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath `
      (Join-Path $PackageRoot $resolvedReference) -PathType Leaf)) {
    throw "Manifest logo does not resolve inside the exact package: $reference"
  }
}

$inventory = @(Get-BusyMaxPackageInventory -PackageRoot $PackageRoot)
if (-not [string]::IsNullOrWhiteSpace($InventoryOutputPath)) {
  $inventoryDirectory = Split-Path -Parent $InventoryOutputPath
  if (-not [string]::IsNullOrWhiteSpace($inventoryDirectory)) {
    New-Item -ItemType Directory -Force -Path $inventoryDirectory | Out-Null
  }
  $inventory | ConvertTo-Json -Depth 3 | Set-Content `
    -LiteralPath $InventoryOutputPath -Encoding utf8NoBOM
}
Write-Host "Validated package contents: $PackageRoot"
$inventory
