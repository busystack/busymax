param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [Parameter(Mandatory)][string]$PackagePath,
  [Parameter(Mandatory)][string]$PfxPath
)

. "$PSScriptRoot/common.ps1"
$prerequisites = & "$PSScriptRoot/check_prerequisites.ps1" -RequireWindows11
$config = Get-BusyMaxStoreConfig -Path $ConfigPath
Assert-BusyMaxStoreConfig -Config $config -Mode LocalTestSigning
$password = Read-Host 'Local PFX password' -AsSecureString
$certificate = Import-PfxCertificate -FilePath $PfxPath `
  -CertStoreLocation 'Cert:\CurrentUser\My' -Password $password
$certificateSubject = [string]$certificate.Subject
Assert-BusyMaxCertificatePublisher -CertificateSubject $certificateSubject `
  -ManifestPublisher ([string]$config.publisher)
# The exact package manifest is checked below after a clean unpack.
$inspection = Join-Path ([IO.Path]::GetTempPath()) `
  "busymax-install-inspection-$([guid]::NewGuid().ToString('N'))"
& (Join-Path $prerequisites.WindowsSdkBin 'makeappx.exe') unpack /p $PackagePath /d $inspection /o
if ($LASTEXITCODE -ne 0) {
  if (Test-Path -LiteralPath $inspection) {
    Remove-Item -LiteralPath $inspection -Recurse -Force
  }
  throw 'Could not unpack the MSIX before local test signing.'
}
try {
  [xml]$manifest = Get-Content `
    -LiteralPath (Join-Path $inspection 'AppxManifest.xml') -Raw
} finally {
  Remove-Item -LiteralPath $inspection -Recurse -Force
}
$manifestPublisher = [string]$manifest.Package.Identity.Publisher
Assert-BusyMaxCertificatePublisher -CertificateSubject $certificateSubject `
  -ManifestPublisher $manifestPublisher
if ([string]$manifest.Package.Identity.Name -cne [string]$config.identityName) {
  throw "Packed manifest identity '$($manifest.Package.Identity.Name)' does not match configuration field 'identityName' in LocalTestSigning mode."
}
if ([string]$manifest.Package.Identity.Version -cne [string]$config.msixVersion) {
  throw "Packed manifest version '$($manifest.Package.Identity.Version)' does not match configuration field 'msixVersion' in LocalTestSigning mode."
}
$testPackage = Join-Path (Split-Path -Parent $PackagePath) 'BusyMax-test-signed.msix'
Copy-Item -LiteralPath $PackagePath -Destination $testPackage -Force
$signTool = Join-Path $prerequisites.WindowsSdkBin 'signtool.exe'
& $signTool sign /fd SHA256 /sha1 $certificate.Thumbprint /s My $testPackage
if ($LASTEXITCODE -ne 0) { throw 'Local test signing failed.' }
$trustedCertificate = Import-Certificate `
  -FilePath ([IO.Path]::ChangeExtension($PfxPath, '.cer')) `
  -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople'
Add-AppxPackage -Path $testPackage
Write-Host 'Installed local test package. It is not a Store artifact.'
Write-Host "Cleanup: Get-AppxPackage -Name '$($config.identityName)' | Remove-AppxPackage"
Write-Host "Certificate cleanup (My): Remove-Item -LiteralPath 'Cert:\CurrentUser\My\$($certificate.Thumbprint)'"
Write-Host "Certificate cleanup (TrustedPeople): Remove-Item -LiteralPath 'Cert:\CurrentUser\TrustedPeople\$($trustedCertificate.Thumbprint)'"
