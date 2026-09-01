param(
  [string]$BuildDirectory = 'build\windows\x64',
  [string]$Configuration = 'Release'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) { throw 'BusyMax native tests require Windows.' }
if (-not (Test-Path -LiteralPath (Join-Path $BuildDirectory 'CMakeCache.txt'))) {
  throw "The configured Windows CMake build was not found: $BuildDirectory"
}
$resultDirectory = 'build\windows\test-results'
New-Item -ItemType Directory -Force -Path $resultDirectory | Out-Null
& cmake -S windows -B $BuildDirectory `
  -Dinclude_flutter_timezone_tests=ON `
  -Dinclude_tray_manager_tests=ON 2>&1 | Tee-Object `
  -FilePath (Join-Path $resultDirectory 'native-configure.log')
$configureExitCode = $LASTEXITCODE
if ($configureExitCode -ne 0) {
  throw "BusyMax native test configuration failed with exit code $configureExitCode."
}
& cmake --build $BuildDirectory --config $Configuration `
  --target busymax_runner_native_test flutter_timezone_test tray_manager_test `
  2>&1 | Tee-Object `
  -FilePath (Join-Path $resultDirectory 'native-build.log')
$buildExitCode = $LASTEXITCODE
if ($buildExitCode -ne 0) {
  throw "BusyMax native test compilation failed with exit code $buildExitCode."
}
& ctest --test-dir $BuildDirectory -C $Configuration --output-on-failure `
  --output-junit (Join-Path $resultDirectory 'native-tests.xml') 2>&1 |
  Tee-Object -FilePath (Join-Path $resultDirectory 'native-tests.log')
$testExitCode = $LASTEXITCODE
if ($testExitCode -ne 0) {
  throw "BusyMax native tests failed with exit code $testExitCode."
}
