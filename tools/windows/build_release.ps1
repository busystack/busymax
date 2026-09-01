param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [switch]$Ci,
  [ValidateSet(
    'All', 'PesterTests', 'SourceGeneration', 'StaticAnalysis',
    'FlutterTests', 'WindowsCompile', 'NativeTests', 'Package')]
  [string]$Stage = 'All'
)

. "$PSScriptRoot/common.ps1"
& "$PSScriptRoot/check_prerequisites.ps1" | Out-Host
$identity = & "$PSScriptRoot/validate_release_config.ps1" `
  -ConfigPath $ConfigPath -Ci:$Ci
$config = Get-BusyMaxStoreConfig -Path $ConfigPath

function Invoke-BusyMaxPesterTests {
  $pesterModule = Get-Module -ListAvailable Pester |
    Sort-Object Version -Descending | Select-Object -First 1
  if ($null -eq $pesterModule -or $pesterModule.Version -lt [version]'5.0.0') {
    throw 'Pester 5 is required to run the Windows packaging contract tests.'
  }
  Import-Module Pester -MinimumVersion 5.0.0
  New-Item -ItemType Directory -Force `
    -Path 'build\windows\test-results' | Out-Null
  $pester = Invoke-Pester `
    -Path 'tools\windows\tests' -PassThru -Output Detailed
  [pscustomobject]@{
    Result = [string]$pester.Result
    PassedCount = $pester.PassedCount
    FailedCount = $pester.FailedCount
    SkippedCount = $pester.SkippedCount
  } | ConvertTo-Json | Set-Content `
    -LiteralPath 'build\windows\test-results\pester-summary.json' `
    -Encoding utf8NoBOM
  if ($pester.FailedCount -ne 0) {
    throw 'Windows packaging contract tests failed.'
  }
}

function Invoke-BusyMaxSourceGeneration {
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
  & flutter gen-l10n
  if ($LASTEXITCODE -ne 0) { throw 'Localization generation failed.' }
  & dart run build_runner build --delete-conflicting-outputs --force-jit
  if ($LASTEXITCODE -ne 0) { throw 'Code generation failed.' }
  & git diff --exit-code -- lib/l10n/generated lib/src/db
  if ($LASTEXITCODE -ne 0) { throw 'Generated files are not committed.' }
}

function Invoke-BusyMaxStaticAnalysis {
  & dart format --output=none --set-exit-if-changed .
  if ($LASTEXITCODE -ne 0) { throw 'Formatting check failed.' }
  & flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
  & dart run tool/check_platform_boundaries.dart
  if ($LASTEXITCODE -ne 0) { throw 'Platform boundary validation failed.' }
}

function Invoke-BusyMaxFlutterTests {
  New-Item -ItemType Directory -Force `
    -Path 'build\windows\test-results' | Out-Null
  & flutter test --machine | Tee-Object `
    -FilePath 'build\windows\test-results\flutter-tests.jsonl'
  if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
}

function Invoke-BusyMaxWindowsCompile {
  $defines = @(
    '--dart-define=BUSYMAX_WINDOWS_STORE_MODE=true',
    "--dart-define=BUSYMAX_WINDOWS_AUMID=$($identity.AppUserModelId)",
    "--dart-define=BUSYMAX_MSIX_VERSION=$($config.msixVersion)",
    "--dart-define=BUSYMAX_PRIVACY_POLICY_URL=$($config.privacyPolicyUrl)",
    "--dart-define=BUSYMAX_SUPPORT_URL=$($config.supportUrl)",
    "--dart-define=BUSYMAX_HOMEPAGE_URL=$($config.homepageUrl)",
    "--dart-define=GOOGLE_OAUTH_CLIENT_ID=$($config.googleOAuthClientId)",
    "--dart-define=MICROSOFT_OAUTH_CLIENT_ID=$($config.microsoftOAuthClientId)",
    "--dart-define=MICROSOFT_OAUTH_AUTHORITY_TENANT=$($config.microsoftOAuthAuthorityTenant)",
    '--dart-define=BUSYMAX_FAKE_DATA=false'
  )
  if (-not [string]::IsNullOrWhiteSpace($config.googleOAuthClientSecret)) {
    $defines += "--dart-define=GOOGLE_OAUTH_CLIENT_SECRET=$($config.googleOAuthClientSecret)"
  }
  New-Item -ItemType Directory -Force `
    -Path 'build\windows\test-results' | Out-Null
  & flutter build windows --release -t lib/main_windows.dart @defines 2>&1 |
    Tee-Object -FilePath 'build\windows\test-results\windows-build.log'
  $compileExitCode = $LASTEXITCODE
  if ($compileExitCode -ne 0) {
    throw "Flutter Windows release build failed with exit code $compileExitCode."
  }
}

function Invoke-BusyMaxNativeTests {
  & "$PSScriptRoot/run_native_tests.ps1"
  if ($LASTEXITCODE -ne 0) { throw 'Windows native tests failed.' }
}

function Invoke-BusyMaxPackage {
  $metadata = & "$PSScriptRoot/package_store.ps1" `
    -ConfigPath $ConfigPath -Ci:$Ci
  $metadata | Format-List | Out-Host
  $metadata
}

switch ($Stage) {
  'PesterTests' { Invoke-BusyMaxPesterTests }
  'SourceGeneration' { Invoke-BusyMaxSourceGeneration }
  'StaticAnalysis' { Invoke-BusyMaxStaticAnalysis }
  'FlutterTests' { Invoke-BusyMaxFlutterTests }
  'WindowsCompile' { Invoke-BusyMaxWindowsCompile }
  'NativeTests' { Invoke-BusyMaxNativeTests }
  'Package' { Invoke-BusyMaxPackage }
  'All' {
    Invoke-BusyMaxPesterTests
    Invoke-BusyMaxSourceGeneration
    Invoke-BusyMaxStaticAnalysis
    Invoke-BusyMaxFlutterTests
    Invoke-BusyMaxWindowsCompile
    Invoke-BusyMaxNativeTests
    Invoke-BusyMaxPackage
  }
}
