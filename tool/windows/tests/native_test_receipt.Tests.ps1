BeforeAll {
  $script:nativeRunner = Join-Path (Split-Path -Parent $PSScriptRoot) `
    'run_native_tests.ps1'
}

Describe 'BusyMax native test receipt' {
  BeforeEach {
    $script:previousLocation = Get-Location
    $script:previousProcessDirectory = [Environment]::CurrentDirectory
    $project = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $processDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $processDirectory | Out-Null
    New-Item -ItemType Directory -Force `
      -Path (Join-Path $project 'build\windows\x64') | Out-Null
    Set-Content -LiteralPath `
      (Join-Path $project 'build\windows\x64\CMakeCache.txt') -Value 'fixture'
    Set-Location $project
    [Environment]::CurrentDirectory = $processDirectory
    $script:expectedReport = Join-Path $project `
      'build\windows\test-results\native-tests.xml'
    Mock cmake { $global:LASTEXITCODE = 0 }
  }

  AfterEach {
    Set-Location $script:previousLocation
    [Environment]::CurrentDirectory = $script:previousProcessDirectory
  }

  It 'writes the receipt beneath the PowerShell project location' {
    Mock ctest {
      $arguments = @($args)
      $index = [Array]::IndexOf($arguments, '--output-junit')
      $index | Should -BeGreaterOrEqual 0
      [IO.File]::WriteAllText($arguments[$index + 1], '<testsuite tests="1" />')
      $global:LASTEXITCODE = 0
    }

    { & $script:nativeRunner } | Should -Not -Throw

    Test-Path -LiteralPath $script:expectedReport -PathType Leaf |
      Should -BeTrue
  }

  It 'rejects a missing new receipt even when an older receipt exists' {
    New-Item -ItemType Directory -Force `
      -Path (Split-Path -Parent $script:expectedReport) | Out-Null
    Set-Content -LiteralPath $script:expectedReport `
      -Value '<testsuite tests="1" />'
    Mock ctest { $global:LASTEXITCODE = 0 }

    { & $script:nativeRunner } | Should -Throw `
      -ExpectedMessage '*CTest did not produce a fresh native test report*'
  }

  It 'retains rejection of a failing native test process' {
    Mock ctest { $global:LASTEXITCODE = 9 }

    { & $script:nativeRunner } | Should -Throw `
      -ExpectedMessage '*native tests failed with exit code 9*'
  }
}
