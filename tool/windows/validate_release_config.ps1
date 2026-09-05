param([Parameter(Mandatory)][string]$ConfigPath, [switch]$Ci)

. "$PSScriptRoot/common.ps1"
$config = Get-BusyMaxStoreConfig -Path $ConfigPath
$mode = if ($Ci) { 'CiNonProduction' } else { 'ProductionStore' }
Assert-BusyMaxStoreConfig -Config $config -Mode $mode
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
