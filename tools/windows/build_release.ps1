param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [switch]$Ci
)

. "$PSScriptRoot/common.ps1"
& "$PSScriptRoot/check_prerequisites.ps1" | Out-Host
$identity = & "$PSScriptRoot/validate_release_config.ps1" `
  -ConfigPath $ConfigPath -Ci:$Ci
$config = Get-BusyMaxStoreConfig -Path $ConfigPath

& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
& flutter gen-l10n
if ($LASTEXITCODE -ne 0) { throw 'Localization generation failed.' }
& dart run build_runner build --delete-conflicting-outputs --force-jit
if ($LASTEXITCODE -ne 0) { throw 'Code generation failed.' }
& git diff --exit-code -- lib/l10n/generated lib/src/db
if ($LASTEXITCODE -ne 0) { throw 'Generated files are not committed.' }
& dart format --output=none --set-exit-if-changed .
if ($LASTEXITCODE -ne 0) { throw 'Formatting check failed.' }
& flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
New-Item -ItemType Directory -Force -Path 'build\windows\test-results' | Out-Null
& flutter test --machine | Tee-Object `
  -FilePath 'build\windows\test-results\flutter-tests.jsonl'
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
& dart run tool/check_platform_boundaries.dart
if ($LASTEXITCODE -ne 0) { throw 'Platform boundary validation failed.' }

$defines = @(
  "--dart-define=BUSYMAX_WINDOWS_STORE_MODE=true",
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
& flutter build windows --release -t lib/main_windows.dart @defines
if ($LASTEXITCODE -ne 0) { throw 'Flutter Windows release build failed.' }

$metadata = & "$PSScriptRoot/package_store.ps1" `
  -ConfigPath $ConfigPath -Ci:$Ci
$metadata | Format-List | Out-Host
$metadata
