param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [Parameter(Mandatory)][string]$PackagePath,
  [Parameter(Mandatory)][string]$PfxPath
)

. "$PSScriptRoot/common.ps1"
$prerequisites = & "$PSScriptRoot/check_prerequisites.ps1"
$config = Get-BusyMaxStoreConfig -Path $ConfigPath
Assert-BusyMaxStoreConfig -Config $config -Ci
$password = Read-Host 'Local PFX password' -AsSecureString
$certificate = Import-PfxCertificate -FilePath $PfxPath `
  -CertStoreLocation 'Cert:\CurrentUser\My' -Password $password
$testPackage = Join-Path (Split-Path -Parent $PackagePath) 'BusyMax-test-signed.msix'
Copy-Item -LiteralPath $PackagePath -Destination $testPackage -Force
$signTool = Join-Path $prerequisites.WindowsSdkBin 'signtool.exe'
& $signTool sign /fd SHA256 /sha1 $certificate.Thumbprint /s My $testPackage
if ($LASTEXITCODE -ne 0) { throw 'Local test signing failed.' }
$trustedCertificate = Import-Certificate `
  -FilePath ($PfxPath -replace '\.pfx$', '.cer') `
  -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople'
Add-AppxPackage -Path $testPackage
Write-Host 'Installed local test package. It is not a Store artifact.'
Write-Host "Cleanup: Get-AppxPackage -Name '$($config.identityName)' | Remove-AppxPackage"
Write-Host "Certificate cleanup (My): Remove-Item -LiteralPath 'Cert:\CurrentUser\My\$($certificate.Thumbprint)'"
Write-Host "Certificate cleanup (TrustedPeople): Remove-Item -LiteralPath 'Cert:\CurrentUser\TrustedPeople\$($trustedCertificate.Thumbprint)'"
