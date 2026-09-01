BeforeAll {
  $script:tools = Split-Path -Parent $PSScriptRoot
  . (Join-Path $script:tools 'common.ps1')
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
