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
& cmake -S windows -B $BuildDirectory `
  -Dinclude_flutter_timezone_tests=ON `
  -Dinclude_tray_manager_tests=ON
if ($LASTEXITCODE -ne 0) { throw 'BusyMax native test configuration failed.' }
& cmake --build $BuildDirectory --config $Configuration `
  --target busymax_runner_native_test flutter_timezone_test tray_manager_test
if ($LASTEXITCODE -ne 0) { throw 'BusyMax native test compilation failed.' }
$resultDirectory = 'build\windows\test-results'
New-Item -ItemType Directory -Force -Path $resultDirectory | Out-Null
& ctest --test-dir $BuildDirectory -C $Configuration --output-on-failure `
  --output-junit (Join-Path $resultDirectory 'native-tests.xml')
if ($LASTEXITCODE -ne 0) { throw 'BusyMax native tests failed.' }
