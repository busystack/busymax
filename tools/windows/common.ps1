Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-BusyMaxStoreConfig {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Windows Store configuration does not exist: $Path"
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Test-BusyMaxPlaceholder {
  param([AllowNull()][string]$Value)
  return [string]::IsNullOrWhiteSpace($Value) -or
    $Value -match '(?i)(replace_with|placeholder|your[-_]|example\.com|todo)'
}

function Assert-BusyMaxMsixVersion {
  param(
    [Parameter(Mandatory)][string]$Version,
    [string]$PreviousVersion = ''
  )
  if ($Version -notmatch '^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$') {
    throw 'BUSYMAX_MSIX_VERSION must have exactly four numeric components.'
  }
  $parts = @($Matches[1], $Matches[2], $Matches[3], $Matches[4]) |
    ForEach-Object { [uint64]$_ }
  if ($parts[0] -lt 1) { throw 'The first MSIX version component must be at least 1.' }
  if ($parts[3] -ne 0) { throw 'The fourth MSIX version component is reserved and must be 0.' }
  if ($parts | Where-Object { $_ -gt 65535 }) {
    throw 'Each MSIX version component must be no greater than 65535.'
  }
  if (-not [string]::IsNullOrWhiteSpace($PreviousVersion)) {
    Assert-BusyMaxMsixVersion -Version $PreviousVersion
    if ([version]$Version -le [version]$PreviousVersion) {
      throw "MSIX version $Version must be greater than $PreviousVersion."
    }
  }
}

function Assert-BusyMaxHttpsUrl {
  param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value)
  $uri = $null
  if (-not [uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or
      $uri.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($uri.Host)) {
    throw "$Name must be a valid HTTPS URL."
  }
}

function Assert-BusyMaxStoreConfig {
  param([Parameter(Mandatory)]$Config, [switch]$Ci)
  foreach ($field in @(
      'identityName', 'publisher', 'publisherDisplayName', 'msixVersion',
      'privacyPolicyUrl', 'supportUrl', 'googleOAuthClientId',
      'microsoftOAuthClientId', 'microsoftOAuthAuthorityTenant',
      'homepageUrl')) {
    if (Test-BusyMaxPlaceholder -Value ([string]$Config.$field)) {
      throw "Store configuration field '$field' is missing or still a placeholder."
    }
  }
  if ($Ci) {
    if ($Config.production -ne $false) {
      throw 'A CI package must use an explicitly non-production identity.'
    }
  } elseif ($Config.production -ne $true) {
    throw 'A production Store build requires production=true.'
  }
  if ($Config.fakeData -eq $true) { throw 'Fake-data mode is prohibited for Store packages.' }
  if ($Config.developmentBackend -eq $true) {
    throw 'A development backend is prohibited for Store packages.'
  }
  if ($Config.identityName -notmatch '^[A-Za-z0-9.-]{3,50}$') {
    throw 'identityName must be a valid Partner Center package identity name.'
  }
  if ($Config.publisher -notmatch '^CN=') {
    throw 'publisher must be the exact Partner Center Publisher CN.'
  }
  if (-not [string]::IsNullOrWhiteSpace($Config.googleOAuthClientSecret) -and
      (Test-BusyMaxPlaceholder -Value ([string]$Config.googleOAuthClientSecret))) {
    throw 'googleOAuthClientSecret is still a placeholder.'
  }
  Assert-BusyMaxMsixVersion -Version ([string]$Config.msixVersion) `
    -PreviousVersion ([string]$Config.previousMsixVersion)
  Assert-BusyMaxHttpsUrl -Name 'privacyPolicyUrl' -Value $Config.privacyPolicyUrl
  Assert-BusyMaxHttpsUrl -Name 'supportUrl' -Value $Config.supportUrl
  Assert-BusyMaxHttpsUrl -Name 'homepageUrl' -Value $Config.homepageUrl
}

function Get-BusyMaxPackageFamilyName {
  param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Publisher)
  if (-not ('BusyMax.PackageIdentity' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace BusyMax {
  public static class PackageIdentity {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct PACKAGE_ID {
      public uint reserved;
      public uint processorArchitecture;
      public ulong version;
      [MarshalAs(UnmanagedType.LPWStr)] public string name;
      [MarshalAs(UnmanagedType.LPWStr)] public string publisher;
      [MarshalAs(UnmanagedType.LPWStr)] public string resourceId;
      [MarshalAs(UnmanagedType.LPWStr)] public string publisherId;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern int PackageFamilyNameFromId(
      ref PACKAGE_ID packageId, ref uint packageFamilyNameLength,
      System.Text.StringBuilder packageFamilyName);
    public static string FamilyName(string name, string publisher) {
      var id = new PACKAGE_ID { name = name, publisher = publisher,
        resourceId = "", publisherId = "" };
      uint length = 0;
      PackageFamilyNameFromId(ref id, ref length, null);
      var value = new System.Text.StringBuilder((int)length);
      int result = PackageFamilyNameFromId(ref id, ref length, value);
      if (result != 0) throw new InvalidOperationException(
        "PackageFamilyNameFromId failed: " + result);
      return value.ToString();
    }
  }
}
'@
  }
  return [BusyMax.PackageIdentity]::FamilyName($Name, $Publisher)
}

function Get-BusyMaxResourceXml {
  $locales = Get-ChildItem -LiteralPath 'lib/l10n' -Filter 'app_*.arb' |
    ForEach-Object {
      $json = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
      $translationKeys = @($json.PSObject.Properties.Name |
        Where-Object { -not $_.StartsWith('@') })
      # Flutter requires an empty generic `pt` catalog to generate pt-PT, but
      # BusyMax does not expose generic Portuguese as a supported locale.
      if ($translationKeys.Count -gt 0) {
        $locale = ([string]$json.'@@locale').Replace('_', '-')
        if ($locale -notmatch '^[A-Za-z]{2,3}(?:-[A-Za-z]{4})?(?:-[A-Za-z]{2}|-[0-9]{3})?$') {
          throw "ARB locale is not a valid BCP-47 language tag: $locale"
        }
        try {
          [Globalization.CultureInfo]::GetCultureInfo($locale) | Out-Null
        } catch {
          throw "ARB locale is not recognized as a BCP-47 language tag: $locale"
        }
        $locale
      }
    } | Sort-Object -Unique
  if (-not $locales) { throw 'No BusyMax ARB locales were found.' }
  return ($locales | ForEach-Object { "    <Resource Language=`"$_`" />" }) -join "`r`n"
}

function Copy-BusyMaxVCRuntime {
  param(
    [Parameter(Mandatory)][string]$VisualStudioPath,
    [Parameter(Mandatory)][string]$Destination
  )
  $redistRoot = Join-Path $VisualStudioPath 'VC\Redist\MSVC'
  $crt = Get-ChildItem -LiteralPath $redistRoot -Directory |
    Sort-Object { [version]$_.Name } -Descending |
    ForEach-Object {
      Get-ChildItem -LiteralPath (Join-Path $_.FullName 'x64') `
        -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue
    } | Select-Object -First 1
  if ($null -eq $crt) {
    throw 'The Visual Studio x64 VC runtime redistributable was not found.'
  }
  $runtimeNames = @(
    'concrt140.dll', 'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll',
    'msvcp140_atomic_wait.dll', 'msvcp140_codecvt_ids.dll', 'vccorlib140.dll',
    'vcruntime140.dll', 'vcruntime140_1.dll', 'vcruntime140_threads.dll'
  )
  foreach ($name in $runtimeNames) {
    $source = Join-Path $crt.FullName $name
    if (Test-Path -LiteralPath $source) {
      Copy-Item -LiteralPath $source -Destination $Destination
    }
  }
  foreach ($required in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Destination $required))) {
      throw "Required Visual C++ runtime file was not staged: $required"
    }
  }
}
