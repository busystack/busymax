param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [string]$OutputDirectory = 'build\windows\test-signing'
)

. "$PSScriptRoot/common.ps1"
$config = Get-BusyMaxStoreConfig -Path $ConfigPath
Assert-BusyMaxStoreConfig -Config $config -Ci
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$certificate = New-SelfSignedCertificate `
  -Type Custom `
  -Subject $config.publisher `
  -KeyUsage DigitalSignature `
  -FriendlyName 'BusyMax local MSIX test certificate' `
  -CertStoreLocation 'Cert:\CurrentUser\My' `
  -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3')
$password = Read-Host 'Choose a local PFX password' -AsSecureString
$pfx = Join-Path $OutputDirectory 'busymax-test-only.pfx'
$cer = Join-Path $OutputDirectory 'busymax-test-only.cer'
Export-PfxCertificate -Cert $certificate -FilePath $pfx -Password $password | Out-Null
Export-Certificate -Cert $certificate -FilePath $cer | Out-Null
Write-Host "Created local-only files under $OutputDirectory. Never commit them."
Write-Host "Thumbprint: $($certificate.Thumbprint)"
Write-Host "Certificate cleanup: Remove-Item -LiteralPath 'Cert:\CurrentUser\My\$($certificate.Thumbprint)'"
Write-Host "File cleanup: Remove-Item -LiteralPath '$OutputDirectory' -Recurse"
[pscustomobject]@{ Pfx = $pfx; Cer = $cer; Thumbprint = $certificate.Thumbprint }
