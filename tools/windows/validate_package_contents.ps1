param([Parameter(Mandatory)][string]$StagingPath)

if (-not (Test-Path -LiteralPath "$StagingPath/busymax.exe")) {
  throw 'Staging directory does not contain busymax.exe.'
}
foreach ($required in @(
    'flutter_windows.dll', 'sqlite3.dll', 'msvcp140.dll', 'vcruntime140.dll',
    'vcruntime140_1.dll', 'data/flutter_assets/AssetManifest.bin',
    'AppxManifest.xml')) {
  if (-not (Test-Path -LiteralPath (Join-Path $StagingPath $required))) {
    throw "Required package file is missing: $required"
  }
}
foreach ($asset in @(
    'StoreLogo', 'Square44x44Logo', 'Square150x150Logo',
    'FileAssociation')) {
  foreach ($scale in @(100, 125, 150, 200, 400)) {
    $candidate = "Assets/$asset.scale-$scale.png"
    if (-not (Test-Path -LiteralPath (Join-Path $StagingPath $candidate))) {
      throw "Required package visual asset is missing: $candidate"
    }
  }
}
$prohibited = Get-ChildItem -LiteralPath $StagingPath -Recurse -File |
  Where-Object {
    $relative = [IO.Path]::GetRelativePath($StagingPath, $_.FullName).Replace('\', '/')
    $_.Extension -in @(
      '.pfx', '.cer', '.log', '.db', '.sqlite', '.dart', '.cc', '.h', '.pdb',
      '.so', '.snap', '.AppImage'
    ) -or
    $_.Name -match '(?i)(^|[._-])(test|fake)([._-]|$)|flutter_logo' -or
    $relative -match '(?i)(^|/)(linux|snap|snapcraft)(/|$)'
  }
if ($prohibited) {
  throw "Prohibited package content: $($prohibited.FullName -join ', ')"
}
$executables = @(Get-ChildItem -LiteralPath $StagingPath -Recurse -File -Filter '*.exe')
if ($executables.Count -ne 1 -or $executables[0].Name -cne 'busymax.exe') {
  throw "The package must contain only busymax.exe: $($executables.FullName -join ', ')"
}
Write-Host "Validated package contents: $StagingPath"
