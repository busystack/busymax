param(
  [Parameter(Mandatory)][Alias('StagingPath')][string]$PackageRoot,
  [string]$InventoryOutputPath = ''
)

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
foreach ($asset in @(
    'StoreLogo', 'Square44x44Logo', 'Square150x150Logo',
    'FileAssociation')) {
  foreach ($scale in @(100, 125, 150, 200, 400)) {
    $candidate = "Assets/$asset.scale-$scale.png"
    if (-not (Test-Path -LiteralPath (Join-Path $PackageRoot $candidate))) {
      throw "Required package visual asset is missing: $candidate"
    }
  }
}
$prohibited = Get-ChildItem -LiteralPath $PackageRoot -Recurse -File |
  Where-Object {
    $relative = [IO.Path]::GetRelativePath($PackageRoot, $_.FullName).Replace('\', '/')
    $_.Extension -in @(
      '.pfx', '.cer', '.log', '.db', '.sqlite', '.dart', '.cc', '.h', '.pdb',
      '.cpp', '.c', '.hpp', '.cmake', '.ps1', '.jsonl', '.yaml', '.yml',
      '.md', '.p12', '.pem', '.key', '.crt', '.p7x', '.snap', '.AppImage'
    ) -or
    ($_.Extension -eq '.so' -and $relative -cne 'data/app.so') -or
    $_.Name -match '(?i)(^|[._-])(test|fake|credential|secret|token|development)([._-]|$)|flutter_logo' -or
    $relative -match '(?i)(^|/)(linux|snap|snapcraft)(/|$)'
  }
if ($prohibited) {
  throw "Prohibited package content: $($prohibited.FullName -join ', ')"
}
$executables = @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Filter '*.exe')
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
$unexpectedDlls = @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Filter '*.dll' |
  Where-Object {
    $relative = [IO.Path]::GetRelativePath($PackageRoot, $_.FullName).Replace('\', '/')
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
    Get-ChildItem -LiteralPath $PackageRoot -File -Filter '*.exe'
    Get-ChildItem -LiteralPath $PackageRoot -File -Filter '*.dll'
    Get-Item -LiteralPath (Join-Path $PackageRoot 'data/app.so')
  )) {
  Assert-BusyMaxX64Pe -Path $nativeBinary.FullName
}
& "$PSScriptRoot/validate_manifest.ps1" `
  -ManifestPath (Join-Path $PackageRoot 'AppxManifest.xml')

$inventory = @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File |
  Sort-Object FullName |
  ForEach-Object {
    [pscustomobject]@{
      Path = [IO.Path]::GetRelativePath($PackageRoot, $_.FullName).Replace('\', '/')
      Length = $_.Length
      SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
  })
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
