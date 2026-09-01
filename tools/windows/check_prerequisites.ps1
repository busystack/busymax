param(
  [switch]$RequireWindows11,
  [switch]$RequireWack
)

. "$PSScriptRoot/common.ps1"

if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem) {
  throw 'BusyMax Windows builds require 64-bit Windows 11.'
}
if ($RequireWindows11 -and [Environment]::OSVersion.Version.Build -lt 26100) {
  throw 'Installed-package and WACK validation require Windows 11 24H2/build 26100 or newer.'
}
$flutterVersion = (& flutter --version --machine | ConvertFrom-Json).frameworkVersion
if ($flutterVersion -ne '3.44.4') {
  throw "BusyMax requires Flutter 3.44.4; found $flutterVersion."
}
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) {
  throw 'Visual Studio 2022 with Desktop development with C++ is required.'
}
$visualStudio = & $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property installationPath
if ([string]::IsNullOrWhiteSpace($visualStudio)) {
  throw 'Visual Studio C++ x64 desktop tools were not found.'
}
$visualStudioVersion = & $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property installationVersion
$visualStudioDisplayName = & $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property displayName
$kitsBin = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$sdk = Get-BusyMaxWindowsSdkDirectory -KitsBin $kitsBin
if ($null -eq $sdk) { throw 'Windows SDK 10.0.26100.0 or newer is required.' }
foreach ($tool in @('makeappx.exe', 'signtool.exe')) {
  if (-not (Test-Path -LiteralPath (Join-Path $sdk.FullName "x64\$tool"))) {
    throw "$tool was not found in Windows SDK $($sdk.Name)."
  }
}
if ($RequireWack) {
  $appCert = Join-Path ${env:ProgramFiles(x86)} `
    'Windows Kits\10\App Certification Kit\appcert.exe'
  if (-not (Test-Path -LiteralPath $appCert)) {
    throw 'The Windows App Certification Kit is required.'
  }
}
$windowsVersion = Get-ItemProperty -LiteralPath `
  'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
[pscustomobject]@{
  Flutter = $flutterVersion
  VisualStudio = $visualStudio
  VisualStudioDisplayName = $visualStudioDisplayName
  VisualStudioVersion = $visualStudioVersion
  WindowsSdk = $sdk.Name
  WindowsSdkBin = Join-Path $sdk.FullName 'x64'
  HostProductName = [string]$windowsVersion.ProductName
  HostEditionId = [string]$windowsVersion.EditionID
  HostDisplayVersion = [string]$windowsVersion.DisplayVersion
  HostVersion = [Environment]::OSVersion.Version.ToString()
  HostBuild = [Environment]::OSVersion.Version.Build
  Windows11ValidationHost = [Environment]::OSVersion.Version.Build -ge 26100
}
