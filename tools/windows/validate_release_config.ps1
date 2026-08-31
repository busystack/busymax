param([Parameter(Mandatory)][string]$ConfigPath, [switch]$Ci)

. "$PSScriptRoot/common.ps1"
$config = Get-BusyMaxStoreConfig -Path $ConfigPath
Assert-BusyMaxStoreConfig -Config $config -Ci:$Ci
$familyName = Get-BusyMaxPackageFamilyName `
  -Name $config.identityName -Publisher $config.publisher
[pscustomobject]@{
  IdentityName = $config.identityName
  Publisher = $config.publisher
  Version = $config.msixVersion
  PackageFamilyName = $familyName
  AppUserModelId = "$familyName!BusyMax"
  Production = $config.production
}
