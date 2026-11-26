param(
  [string]$BuildDirectory = 'build\windows\x64',
  [string]$Configuration = 'Release'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) { throw 'BusyMax native tests require Windows.' }
$releaseCache = Join-Path $BuildDirectory 'CMakeCache.txt'
if (-not (Test-Path -LiteralPath $releaseCache -PathType Leaf)) {
  throw "The configured Windows CMake build was not found: $BuildDirectory"
}
$releaseBuild = Convert-Path -LiteralPath $BuildDirectory
$testBuild = Join-Path (Split-Path -Parent $releaseBuild) 'native-tests'
if ($testBuild -eq $releaseBuild -or
    ((Test-Path -LiteralPath $testBuild) -and
      ((Get-Item -LiteralPath $testBuild -Force).Attributes -band
        [IO.FileAttributes]::ReparsePoint))) {
  throw "Expected a separate Windows native test build directory: $testBuild"
}

# Reuse the release toolchain selection without reconfiguring its build tree.
$selection = @{}
foreach ($line in Get-Content -LiteralPath $releaseCache) {
  if ($line -match '^(CMAKE_GENERATOR(?:_(?:PLATFORM|TOOLSET|INSTANCE))?):[^=]+=(.+)$') {
    $selection[$Matches[1]] = $Matches[2]
  }
}
if (-not $selection.ContainsKey('CMAKE_GENERATOR')) {
  throw "The release CMake cache does not identify its generator: $releaseCache"
}
$configureArgs = @('-G', $selection['CMAKE_GENERATOR'])
if ($selection['CMAKE_GENERATOR_PLATFORM']) {
  $configureArgs += @('-A', $selection['CMAKE_GENERATOR_PLATFORM'])
}
if ($selection['CMAKE_GENERATOR_TOOLSET']) {
  $configureArgs += @('-T', $selection['CMAKE_GENERATOR_TOOLSET'])
}
if ($selection['CMAKE_GENERATOR_INSTANCE']) {
  $configureArgs += "-DCMAKE_GENERATOR_INSTANCE=$($selection['CMAKE_GENERATOR_INSTANCE'])"
}

$resultDirectory = 'build\windows\test-results'
New-Item -ItemType Directory -Force -Path $resultDirectory | Out-Null
& cmake -S windows -B $testBuild @configureArgs `
  -DBUSYMAX_NATIVE_OS_TESTS=ON 2>&1 | Tee-Object `
  -FilePath (Join-Path $resultDirectory 'native-configure.log')
$configureExitCode = $LASTEXITCODE
if ($configureExitCode -ne 0) {
  throw "BusyMax native test configuration failed with exit code $configureExitCode."
}
& cmake --build $testBuild --config $Configuration `
  --target busymax_runner_native_test busymax_notification_activation_test `
    busymax_short_time_pattern_test busymax_timezone_native_test busymax_tray_native_test `
    busymax_registration_reader_tests `
  2>&1 | Tee-Object `
  -FilePath (Join-Path $resultDirectory 'native-build.log')
$buildExitCode = $LASTEXITCODE
if ($buildExitCode -ne 0) {
  throw "BusyMax native test compilation failed with exit code $buildExitCode."
}
$junitPath = Join-Path (Convert-Path -LiteralPath $resultDirectory) `
  'native-tests.xml'
if (Test-Path -LiteralPath $junitPath) {
  Remove-Item -LiteralPath $junitPath
}
& ctest --test-dir $testBuild -C $Configuration --output-on-failure `
  --output-junit $junitPath 2>&1 |
  Tee-Object -FilePath (Join-Path $resultDirectory 'native-tests.log')
$testExitCode = $LASTEXITCODE
if ($testExitCode -ne 0) {
  throw "BusyMax native tests failed with exit code $testExitCode."
}
if (-not (Test-Path -LiteralPath $junitPath -PathType Leaf)) {
  throw "CTest did not produce a fresh native test report: $junitPath"
}
