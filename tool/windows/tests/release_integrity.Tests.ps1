BeforeAll {
  $tools = Split-Path -Parent $PSScriptRoot
  . (Join-Path $tools 'common.ps1')
  $ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $tools 'build_release.ps1'), [ref]$null, [ref]$null)
  $compile = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
      $node.Name -eq 'Invoke-BusyMaxWindowsCompile'
  }, $false)
  . ([scriptblock]::Create($compile.Extent.Text))

  function Invoke-TestFlutter {
    $global:LASTEXITCODE = 0
    $env:PUB_HOSTED_URL | Should -Be 'https://pub.dev'
    $env:PUB_CACHE | Should -Not -Be $script:inheritedCache
    switch ($args[0]) {
      'pub' {
        ($args -join ' ') | Should -Be 'pub get --enforce-lockfile'
        @(Get-ChildItem -LiteralPath $env:PUB_CACHE -Force).Count | Should -Be 0
        Set-Content -LiteralPath (Join-Path $env:PUB_CACHE 'unlisted.dart') 'official archive'
      }
      'build' {
        $args | Should -Contain '--no-pub'
        $releasePath | Should -Not -Exist
        Get-Content -LiteralPath (Join-Path $env:PUB_CACHE 'unlisted.dart') |
          Should -Be 'official archive'
        New-Item -ItemType Directory -Force -Path (Join-Path $releasePath 'data') | Out-Null
        Set-Content -LiteralPath (Join-Path $releasePath 'busymax.exe') 'compiled executable'
        Set-Content -LiteralPath (Join-Path $releasePath 'data/app.so') 'compiled data'
      }
    }
  }

  function Assert-BusyMaxUpstreamIntegrity([string]$Target) {
    $Target | Should -Be 'windows-release'
    $script:integrityChecks++
    if ($script:rejectAfterCompile -and $script:integrityChecks -eq 2) {
      throw 'Rejected after compilation.'
    }
  }
}

Describe 'BusyMax Windows release acceptance' {
  BeforeEach {
    $workspace = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $workspace | Out-Null
    Push-Location -LiteralPath $workspace
    $script:previousCache = $env:PUB_CACHE
    $script:previousHost = $env:PUB_HOSTED_URL
    $script:inheritedCache = Join-Path $workspace 'old-cache'
    $env:PUB_CACHE = $script:inheritedCache
    $env:PUB_HOSTED_URL = 'https://fixture.invalid'
    New-Item -ItemType Directory -Path $env:PUB_CACHE | Out-Null
    Set-Content -LiteralPath (Join-Path $env:PUB_CACHE 'unlisted.dart') 'modified cached package'
    $releasePath = Join-Path $workspace 'build/windows/x64/runner/Release'
    $ConfigPath = Join-Path $workspace 'release.json'
    Set-Content -LiteralPath $ConfigPath 'release config'
    $configHash = (Get-FileHash -LiteralPath $ConfigPath -Algorithm SHA256).Hash
    Set-Content -LiteralPath 'pubspec.lock' 'locked dependencies'
    $identity = @{ AppUserModelId = 'BusyMax.AUMID' }
    $config = @{
      msixVersion = '1.0.0.0'
      privacyPolicyUrl = 'https://fixture.invalid/privacy'
      supportUrl = 'https://fixture.invalid/support'
      homepageUrl = 'https://fixture.invalid'
      googleOAuthClientId = ''
      googleOAuthClientSecret = ''
      googleOAuthProjectId = ''
      microsoftOAuthClientId = ''
      microsoftOAuthAuthorityTenant = ''
      busyMaxGoogleOAuthClientId = ''
      busyMaxGoogleOAuthClientSecret = ''
      busyMaxGoogleOAuthProjectId = ''
      busyMaxMicrosoftOAuthClientId = ''
    }
    $flutterExecutable = 'Invoke-TestFlutter'
    $Ci = $true
    $Unconfigured = $false
    $script:integrityChecks = 0
    $script:rejectAfterCompile = $false
  }

  AfterEach {
    $env:PUB_CACHE = $script:previousCache
    $env:PUB_HOSTED_URL = $script:previousHost
    Pop-Location
  }

  It 'rejects a compiled bundle without a receipt after the post-build check fails' {
    Invoke-BusyMaxWindowsCompile
    "$releasePath.busymax-integrity.json" | Should -Exist
    $script:integrityChecks = 0
    $script:rejectAfterCompile = $true

    { Invoke-BusyMaxWindowsCompile } | Should -Throw '*Rejected after compilation*'

    (Join-Path $releasePath 'busymax.exe') | Should -Exist
    "$releasePath.busymax-integrity.json" | Should -Not -Exist
    { Assert-BusyMaxAcceptedRelease $releasePath $ConfigPath $Ci } |
      Should -Throw '*no post-build integrity receipt*'
  }

  It 'accepts the verified payload and rejects changed files or package configuration' {
    Invoke-BusyMaxWindowsCompile
    $env:PUB_CACHE | Should -Be $script:inheritedCache
    Get-Content -LiteralPath (Join-Path $env:PUB_CACHE 'unlisted.dart') |
      Should -Be 'modified cached package'
    @(Assert-BusyMaxAcceptedRelease $releasePath $ConfigPath $Ci).Count | Should -Be 2
    Set-Content -LiteralPath $ConfigPath 'another config'
    { Assert-BusyMaxAcceptedRelease $releasePath $ConfigPath $Ci } |
      Should -Throw '*differs from the current release configuration or lockfile*'
    Set-Content -LiteralPath $ConfigPath 'release config'
    Set-Content -LiteralPath (Join-Path $releasePath 'data/app.so') 'different bytes'
    { Assert-BusyMaxAcceptedRelease $releasePath $ConfigPath $Ci } |
      Should -Throw '*bundle differs from the post-build integrity receipt*'
  }

  It 'withholds the package receipt from an unconfigured validation build' {
    $Unconfigured = $true
    Invoke-BusyMaxWindowsCompile
    $script:integrityChecks | Should -Be 2
    "$releasePath.busymax-integrity.json" | Should -Not -Exist
  }
}
