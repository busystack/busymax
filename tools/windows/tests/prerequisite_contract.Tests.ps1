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
