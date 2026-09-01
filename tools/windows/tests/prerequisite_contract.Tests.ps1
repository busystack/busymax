BeforeAll {
  . (Join-Path (Split-Path -Parent $PSScriptRoot) 'common.ps1')
}

Describe 'BusyMax Windows SDK discovery' {
  It 'ignores architecture directories and selects the newest supported SDK' {
    $kitsBin = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $kitsBin | Out-Null
    foreach ($directory in @(
        'arm', 'arm64', 'x64', 'x86', '10.0.22621.0',
        '10.0.26100.0', '10.0.30000.0')) {
      New-Item -ItemType Directory -Path (Join-Path $kitsBin $directory) |
        Out-Null
    }

    $sdk = Get-BusyMaxWindowsSdkDirectory -KitsBin $kitsBin

    $sdk.Name | Should -Be '10.0.30000.0'
  }

  It 'returns no SDK when only architecture and unsupported folders exist' {
    $kitsBin = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $kitsBin | Out-Null
    foreach ($directory in @('arm64', 'x64', '10.0.22621.0', 'not-a-version')) {
      New-Item -ItemType Directory -Path (Join-Path $kitsBin $directory) |
        Out-Null
    }

    $sdk = Get-BusyMaxWindowsSdkDirectory -KitsBin $kitsBin

    $sdk | Should -BeNullOrEmpty
  }
}

Describe 'BusyMax Visual C++ runtime discovery' {
  It 'prefers the newest numeric runtime and tolerates toolset aliases' {
    $visualStudio = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $redistRoot = Join-Path $visualStudio 'VC\Redist\MSVC'
    $numericCrt = Join-Path $redistRoot `
      '14.50.35717\x64\Microsoft.VC145.CRT'
    $aliasCrt = Join-Path $redistRoot 'v145\x64\Microsoft.VC145.CRT'
    New-Item -ItemType Directory -Path $numericCrt -Force | Out-Null
    New-Item -ItemType Directory -Path $aliasCrt -Force | Out-Null
    foreach ($name in @(
        'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
      Set-Content -LiteralPath (Join-Path $numericCrt $name) `
        -Value 'numeric' -Encoding ascii
      Set-Content -LiteralPath (Join-Path $aliasCrt $name) `
        -Value 'alias' -Encoding ascii
    }
    $destination = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $destination | Out-Null

    Copy-BusyMaxVCRuntime -VisualStudioPath $visualStudio `
      -Destination $destination

    Get-Content -LiteralPath (Join-Path $destination 'msvcp140.dll') |
      Should -Be 'numeric'
  }
}
