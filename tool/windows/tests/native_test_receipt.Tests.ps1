BeforeAll {
  $tools = Split-Path -Parent $PSScriptRoot
  $script:nativeRunner = Join-Path $tools 'run_native_tests.ps1'
  . (Join-Path $tools 'common.ps1')
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
    $script:releaseCache = Join-Path $project 'build\windows\x64\CMakeCache.txt'
    Set-Content -LiteralPath $script:releaseCache -Value @(
      'CMAKE_GENERATOR:INTERNAL=Visual Studio 18 2026',
      'CMAKE_GENERATOR_PLATFORM:INTERNAL=x64',
      'CMAKE_GENERATOR_TOOLSET:INTERNAL=',
      'CMAKE_GENERATOR_INSTANCE:INTERNAL=C:/Fixture/Visual Studio'
    )
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

  It 'keeps compiled test outputs out of the accepted release inventory' {
    $script:testBuild = Join-Path $project 'build\windows\native-tests'
    $releasePath = Join-Path $project 'build\windows\x64\runner\Release'
    $configPath = Join-Path $project 'release.json'
    New-Item -ItemType Directory -Force -Path $releasePath | Out-Null
    Set-Content -LiteralPath (Join-Path $releasePath 'busymax.exe') 'accepted runner'
    Set-Content -LiteralPath (Join-Path $releasePath 'flutter_windows.dll') 'accepted engine'
    Set-Content -LiteralPath $configPath 'release configuration'
    Set-Content -LiteralPath 'pubspec.lock' 'locked packages'
    $configHash = (Get-FileHash -LiteralPath $configPath).Hash
    $lockHash = (Get-FileHash -LiteralPath 'pubspec.lock').Hash
    Write-BusyMaxReleaseReceipt $releasePath $configHash $lockHash $true
    $receiptPath = "$releasePath.busymax-integrity.json"
    $receiptHash = (Get-FileHash -LiteralPath $receiptPath).Hash
    $cacheHash = (Get-FileHash -LiteralPath $script:releaseCache).Hash
    $before = @(Assert-BusyMaxAcceptedRelease $releasePath $configPath $true)

    Mock cmake {
      if ($args[0] -eq '-S') {
        $args[3] | Should -Be $script:testBuild
        $args | Should -Contain 'Visual Studio 18 2026'
        $args | Should -Contain 'x64'
        $args | Should -Contain '-DCMAKE_GENERATOR_INSTANCE=C:/Fixture/Visual Studio'
      } else {
        $output = Join-Path $args[1] 'runner\Release'
        New-Item -ItemType Directory -Force -Path $output | Out-Null
        Set-Content -LiteralPath (Join-Path $output 'busymax_timezone_native_test.exe') 'test runner'
        Set-Content -LiteralPath (Join-Path $output 'flutter_windows.dll') 'test engine copy'
      }
      $global:LASTEXITCODE = 0
    }
    Mock ctest {
      $args[1] | Should -Be $script:testBuild
      $index = [Array]::IndexOf($args, '--output-junit')
      [IO.File]::WriteAllText($args[$index + 1], '<testsuite tests="1" />')
      $global:LASTEXITCODE = 0
    }

    & $script:nativeRunner

    Join-Path $script:testBuild 'runner\Release\busymax_timezone_native_test.exe' |
      Should -Exist
    $after = @(Assert-BusyMaxAcceptedRelease $releasePath $configPath $true)
    ($after -join "`n") | Should -BeExactly ($before -join "`n")
    (Get-FileHash -LiteralPath $receiptPath).Hash | Should -BeExactly $receiptHash
    (Get-FileHash -LiteralPath $script:releaseCache).Hash | Should -BeExactly $cacheHash
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
