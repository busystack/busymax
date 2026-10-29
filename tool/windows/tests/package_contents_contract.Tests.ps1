BeforeAll {
  $script:tools = Split-Path -Parent $PSScriptRoot
  . (Join-Path $script:tools 'common.ps1')

  function New-BusyMaxRuntimePackage {
    param([Parameter(Mandatory)][string]$PackageRoot)
    New-Item -ItemType Directory -Path $PackageRoot | Out-Null
    $pe = [byte[]]::new(128)
    $pe[0] = 0x4d
    $pe[1] = 0x5a
    $pe[0x3c] = 0x40
    $pe[0x40] = 0x50
    $pe[0x41] = 0x45
    $pe[0x44] = 0x64
    $pe[0x45] = 0x86
    foreach ($name in @('busymax.exe') + @(Get-BusyMaxWindowsRuntimeDlls) + @(
        'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
      [IO.File]::WriteAllBytes((Join-Path $PackageRoot $name), $pe)
    }
    foreach ($relative in @(
        'data/app.so', 'data/icudtl.dat',
        'data/flutter_assets/AssetManifest.bin',
        'data/flutter_assets/docs/google_setup.md',
        'data/flutter_assets/docs/microsoft_setup.md')) {
      $path = Join-Path $PackageRoot $relative
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) |
        Out-Null
      [IO.File]::WriteAllText($path, 'synthetic runtime data')
    }
    $elf = [byte[]]::new(32)
    $elf[0] = 0x7f
    $elf[1] = 0x45
    $elf[2] = 0x4c
    $elf[3] = 0x46
    $elf[4] = 2
    $elf[5] = 1
    $elf[18] = 0x3e
    [IO.File]::WriteAllBytes((Join-Path $PackageRoot 'data/app.so'), $elf)
    $assetRoot = Join-Path $PackageRoot 'Assets'
    New-Item -ItemType Directory -Path $assetRoot | Out-Null
    foreach ($name in @(
        'StoreLogo.png', 'Square44x44Logo.png', 'Square150x150Logo.png',
        'FileAssociationLogo.png')) {
      [IO.File]::WriteAllText((Join-Path $assetRoot $name), 'synthetic logo')
    }
    $manifest = Get-Content `
      -LiteralPath (Join-Path $script:tools 'AppxManifest.xml.template') -Raw
    $replacements = @{
      '@@IDENTITY_NAME@@' = 'BusyStack.BusyMax.CI'
      '@@PUBLISHER@@' = 'CN=BusyMax CI Package'
      '@@PUBLISHER_DISPLAY_NAME@@' = 'BusyMax CI'
      '@@PACKAGE_VERSION@@' = '1.0.0.0'
      '@@MAX_TESTED_VERSION@@' = '10.0.26100.0'
      '@@RESOURCE_LANGUAGES@@' = (Get-BusyMaxResourceXml)
    }
    foreach ($replacement in $replacements.GetEnumerator()) {
      $manifest = $manifest.Replace($replacement.Key, $replacement.Value)
    }
    [IO.File]::WriteAllText(
      (Join-Path $PackageRoot 'AppxManifest.xml'), $manifest)
  }
}

Describe 'BusyMax current Windows plugin payload' {
  BeforeEach {
    $packageRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-BusyMaxRuntimePackage -PackageRoot $packageRoot
  }

  It 'accepts current runtime DLLs without retired timezone and tray plugins' {
    $inventory = @(& (Join-Path $tools 'validate_package_contents.ps1') `
        -PackageRoot $packageRoot)

    $inventory.Path | Should -Contain 'screen_retriever_windows_plugin.dll'
    $inventory.Path | Should -Contain 'window_manager_plugin.dll'
    $inventory.Path | Should -Not -Contain 'flutter_timezone_plugin.dll'
    $inventory.Path | Should -Not -Contain 'tray_manager_plugin.dll'
  }

  It 'requires the current plugin <Dll>' -ForEach @(
    @{ Dll = 'screen_retriever_windows_plugin.dll' }
    @{ Dll = 'window_manager_plugin.dll' }
  ) {
    Remove-Item -LiteralPath (Join-Path $packageRoot $Dll)

    { & (Join-Path $tools 'validate_package_contents.ps1') `
        -PackageRoot $packageRoot } |
      Should -Throw -ExpectedMessage "*Required package file is missing: $Dll*"
  }

  It 'rejects the retired plugin <Dll>' -ForEach @(
    @{ Dll = 'flutter_timezone_plugin.dll' }
    @{ Dll = 'tray_manager_plugin.dll' }
  ) {
    Copy-Item -LiteralPath (Join-Path $packageRoot 'flutter_windows.dll') `
      -Destination (Join-Path $packageRoot $Dll)

    { & (Join-Path $tools 'validate_package_contents.ps1') `
        -PackageRoot $packageRoot } |
      Should -Throw -ExpectedMessage "*Unexpected package DLLs: *$Dll*"
  }
}

Describe 'BusyMax exact-package file inspection' {
  BeforeEach {
    $packageRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $packageRoot | Out-Null
  }

  It 'rejects a hidden prohibited package file' {
    $hiddenSecret = New-Item -ItemType File `
      -Path (Join-Path $packageRoot '.hidden-secret.key')
    if ($IsWindows) {
      $hiddenSecret.Attributes = $hiddenSecret.Attributes -bor `
        [IO.FileAttributes]::Hidden
    }

    { Assert-BusyMaxPackageHasNoProhibitedFiles -PackageRoot $packageRoot } |
      Should -Throw -ExpectedMessage '*Prohibited package content*hidden-secret.key*'
  }

  It 'allows the two packaged registration help files' {
    $helpDirectory = Join-Path $packageRoot 'data/flutter_assets/docs'
    New-Item -ItemType Directory -Path $helpDirectory -Force | Out-Null
    foreach ($name in @('google_setup.md', 'microsoft_setup.md')) {
      [IO.File]::WriteAllText((Join-Path $helpDirectory $name), 'Setup help')
    }

    { Assert-BusyMaxPackageHasNoProhibitedFiles -PackageRoot $packageRoot } |
      Should -Not -Throw
  }

  It 'rejects other Markdown files and misplaced registration help' {
    foreach ($relative in @(
        'data/flutter_assets/docs/notes.md',
        'google_setup.md',
        'docs/microsoft_setup.md')) {
      $filePath = Join-Path $packageRoot $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $filePath) `
        -Force | Out-Null
      [IO.File]::WriteAllText($filePath, 'Not packaged help')

      Test-BusyMaxProhibitedPackageFile -PackageRoot $packageRoot `
        -File (Get-Item -LiteralPath $filePath) | Should -BeTrue
    }
  }

  It 'requires and inventories hidden final-MSIX metadata' {
    $metadataNames = @('AppxBlockMap.xml', '[Content_Types].xml')
    foreach ($metadataName in $metadataNames) {
      $metadataPath = Join-Path $packageRoot $metadataName
      [IO.File]::WriteAllText($metadataPath, 'package metadata')
      $metadata = Get-Item -LiteralPath $metadataPath
      if ($IsWindows) {
        $metadata.Attributes = $metadata.Attributes -bor `
          [IO.FileAttributes]::Hidden
      }
    }

    { Assert-BusyMaxFinalMsixMetadata -PackageRoot $packageRoot } |
      Should -Not -Throw
    $inventory = @(Get-BusyMaxPackageInventory -PackageRoot $packageRoot)
    $inventory.Path | Should -Contain 'AppxBlockMap.xml'
    $inventory.Path | Should -Contain '[Content_Types].xml'
  }

  It 'rejects a final-MSIX inventory missing either metadata file' {
    [IO.File]::WriteAllText(
      (Join-Path $packageRoot 'AppxBlockMap.xml'), 'package metadata')

    { Assert-BusyMaxFinalMsixMetadata -PackageRoot $packageRoot } |
      Should -Throw -ExpectedMessage '*Content_Types*.xml*'
  }

  It 'extracts generated metadata from the exact MSIX container' {
    $archiveSource = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $archiveSource | Out-Null
    [IO.File]::WriteAllText(
      (Join-Path $archiveSource 'AppxBlockMap.xml'), 'block map')
    [IO.File]::WriteAllText(
      (Join-Path $archiveSource '[Content_Types].xml'), 'content types')
    [IO.File]::WriteAllText(
      (Join-Path $archiveSource 'busymax.exe'), 'payload')
    $packagePath = Join-Path $TestDrive `
      "$([guid]::NewGuid().ToString('N')).msix"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($archiveSource, $packagePath)

    Expand-BusyMaxMsixMetadata -PackagePath $packagePath `
      -PackageRoot $packageRoot

    Get-Content -LiteralPath (Join-Path $packageRoot 'AppxBlockMap.xml') |
      Should -Be 'block map'
    Get-Content -LiteralPath (Join-Path $packageRoot '[Content_Types].xml') |
      Should -Be 'content types'
  }

  It 'wires distinct staging and final-MSIX validation modes' {
    $validator = Get-Content `
      -LiteralPath (Join-Path $tools 'validate_package_contents.ps1') -Raw
    $packager = Get-Content `
      -LiteralPath (Join-Path $tools 'package_store.ps1') -Raw

    $validator | Should -Match "ValidateSet\('Staging', 'FinalMsix'\)"
    $packager | Should -Match '-ValidationMode Staging'
    $packager | Should -Match '-ValidationMode FinalMsix'
    $packager | Should -Match 'Expand-BusyMaxMsixMetadata'
  }
}
