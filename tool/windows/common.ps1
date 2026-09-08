Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-BusyMaxStoreConfig {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Windows Store configuration does not exist: $Path"
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-BusyMaxWindowsSdkDirectory {
  param(
    [Parameter(Mandatory)][string]$KitsBin,
    [version]$MinimumVersion = [version]'10.0.26100.0'
  )
  return Get-ChildItem -LiteralPath $KitsBin -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
    Where-Object { [version]$_.Name -ge $MinimumVersion } |
    Sort-Object { [version]$_.Name } -Descending |
    Select-Object -First 1
}

function Test-BusyMaxWindows11ValidationHost {
  param(
    [Parameter(Mandatory)][int]$Build,
    [Parameter(Mandatory)][uint32]$ProductType
  )
  return $ProductType -eq 1 -and $Build -ge 26100
}

function Assert-BusyMaxWindows11ValidationHost {
  param(
    [Parameter(Mandatory)][int]$Build,
    [Parameter(Mandatory)][uint32]$ProductType
  )
  if ($ProductType -ne 1) {
    throw "Installed-package and WACK validation require a Windows 11 workstation (Win32_OperatingSystem.ProductType 1); found ProductType $ProductType."
  }
  if ($Build -lt 26100) {
    throw "Installed-package and WACK validation require Windows 11 24H2/build 26100 or newer; found build $Build."
  }
}

function Get-BusyMaxPackageFiles {
  param([Parameter(Mandatory)][string]$PackageRoot)
  if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    throw "Package root does not exist: $PackageRoot"
  }
  return @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Force)
}

function Get-BusyMaxPackageRelativePath {
  param(
    [Parameter(Mandatory)][string]$PackageRoot,
    [Parameter(Mandatory)][string]$Path
  )
  return [IO.Path]::GetRelativePath($PackageRoot, $Path).Replace('\', '/')
}

function Test-BusyMaxProhibitedPackageFile {
  param(
    [Parameter(Mandatory)][string]$PackageRoot,
    [Parameter(Mandatory)][IO.FileInfo]$File
  )
  $relative = Get-BusyMaxPackageRelativePath -PackageRoot $PackageRoot `
    -Path $File.FullName
  return $File.Extension -in @(
    '.pfx', '.cer', '.log', '.db', '.sqlite', '.dart', '.cc', '.h', '.pdb',
    '.cpp', '.c', '.hpp', '.cmake', '.ps1', '.jsonl', '.yaml', '.yml',
    '.md', '.p12', '.pem', '.key', '.crt', '.p7x', '.snap', '.AppImage'
  ) -or
    ($File.Extension -eq '.so' -and $relative -cne 'data/app.so') -or
    $File.Name -match '(?i)(^|[._-])(test|fake|credential|secret|token|development)([._-]|$)|flutter_logo' -or
    $relative -match '(?i)(^|/)(linux|snap|snapcraft)(/|$)'
}

function Assert-BusyMaxPackageHasNoProhibitedFiles {
  param([Parameter(Mandatory)][string]$PackageRoot)
  $prohibited = @(Get-BusyMaxPackageFiles -PackageRoot $PackageRoot |
    Where-Object {
      Test-BusyMaxProhibitedPackageFile -PackageRoot $PackageRoot -File $_
    })
  if ($prohibited.Count -gt 0) {
    throw "Prohibited package content: $($prohibited.FullName -join ', ')"
  }
}

function Assert-BusyMaxFinalMsixMetadata {
  param([Parameter(Mandatory)][string]$PackageRoot)
  foreach ($metadataFile in @('AppxBlockMap.xml', '[Content_Types].xml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackageRoot $metadataFile) `
        -PathType Leaf)) {
      throw "Final MSIX metadata is missing: $metadataFile"
    }
  }
}

function Expand-BusyMaxMsixMetadata {
  param(
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][string]$PackageRoot
  )
  if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) {
    throw "MSIX package does not exist: $PackagePath"
  }
  if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    throw "Unpacked MSIX directory does not exist: $PackageRoot"
  }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead(
    (Resolve-Path -LiteralPath $PackagePath).Path)
  try {
    foreach ($metadataFile in @('AppxBlockMap.xml', '[Content_Types].xml')) {
      $entries = @($archive.Entries | Where-Object {
          $_.FullName -ceq $metadataFile
        })
      if ($entries.Count -ne 1) {
        throw "Exact MSIX archive must contain one $metadataFile entry; found $($entries.Count)."
      }
      $destination = Join-Path $PackageRoot $metadataFile
      $inputStream = $entries[0].Open()
      try {
        $outputStream = [IO.File]::Open(
          $destination, [IO.FileMode]::Create, [IO.FileAccess]::Write,
          [IO.FileShare]::None)
        try {
          $inputStream.CopyTo($outputStream)
        } finally {
          $outputStream.Dispose()
        }
      } finally {
        $inputStream.Dispose()
      }
    }
  } finally {
    $archive.Dispose()
  }
}

function Get-BusyMaxPackageInventory {
  param([Parameter(Mandatory)][string]$PackageRoot)
  return @(Get-BusyMaxPackageFiles -PackageRoot $PackageRoot |
    Sort-Object FullName |
    ForEach-Object {
      [pscustomobject]@{
        Path = Get-BusyMaxPackageRelativePath -PackageRoot $PackageRoot `
          -Path $_.FullName
        Length = $_.Length
        SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
      }
    })
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

function Assert-BusyMaxCertificatePublisher {
  param(
    [Parameter(Mandatory)][string]$CertificateSubject,
    [Parameter(Mandatory)][string]$ManifestPublisher
  )
  if ($CertificateSubject -cne $ManifestPublisher) {
    throw "Certificate subject '$CertificateSubject' does not exactly match AppxManifest Publisher '$ManifestPublisher' in LocalTestSigning mode."
  }
}

function Assert-BusyMaxStoreConfig {
  param(
    [Parameter(Mandatory)]$Config,
    [Parameter(Mandatory)]
    [ValidateSet('ProductionStore', 'CiNonProduction', 'LocalTestSigning')]
    [string]$Mode
  )
  foreach ($field in @(
      'identityName', 'publisher', 'publisherDisplayName', 'msixVersion',
      'privacyPolicyUrl', 'supportUrl', 'googleOAuthClientId',
      'microsoftOAuthClientId', 'microsoftOAuthAuthorityTenant',
      'homepageUrl')) {
    if (Test-BusyMaxPlaceholder -Value ([string]$Config.$field)) {
      throw "Store configuration field '$field' is missing or still a placeholder in $Mode mode."
    }
  }
  switch ($Mode) {
    'ProductionStore' {
      if ($Config.production -ne $true) {
        throw "Field 'production' must be true in ProductionStore mode."
      }
      if ([string]$Config.identityName -ceq 'BusyStack.BusyMax.CI' -or
          [string]$Config.publisher -ceq 'CN=BusyMax CI Package') {
        throw "Field 'identityName' and 'publisher' must not use the committed CI identity in ProductionStore mode."
      }
    }
    'LocalTestSigning' {
      if ($Config.production -ne $true) {
        throw "Field 'production' must be true in LocalTestSigning mode because the test certificate must match the owner's rendered Store identity."
      }
      if ([string]$Config.identityName -ceq 'BusyStack.BusyMax.CI' -or
          [string]$Config.publisher -ceq 'CN=BusyMax CI Package') {
        throw "Field 'identityName' and 'publisher' must use the owner's Store identity, not the committed CI identity, in LocalTestSigning mode."
      }
    }
    'CiNonProduction' {
      if ($Config.production -ne $false) {
        throw "Field 'production' must be false in CiNonProduction mode. Production configurations cannot be used by CI."
      }
      $expected = [ordered]@{
        identityName = 'BusyStack.BusyMax.CI'
        publisher = 'CN=BusyMax CI Package'
        publisherDisplayName = 'BusyMax CI'
        msixVersion = '1.0.0.0'
        privacyPolicyUrl = 'https://busystack.org/privacy'
        supportUrl = 'https://busystack.org/support'
        homepageUrl = 'https://busystack.org'
        googleOAuthClientId = 'busymax-ci-google-client-id'
        microsoftOAuthClientId = 'busymax-ci-microsoft-client-id'
        microsoftOAuthAuthorityTenant = 'common'
      }
      foreach ($entry in $expected.GetEnumerator()) {
        $property = $Config.PSObject.Properties[$entry.Key]
        if ($null -eq $property -or
            [string]$property.Value -cne [string]$entry.Value) {
          throw "Field '$($entry.Key)' must equal the committed nonproduction test value in CiNonProduction mode."
        }
      }
    }
  }
  if ($Config.fakeData -eq $true) {
    throw "Field 'fakeData' must be false in $Mode mode."
  }
  if ($Config.developmentBackend -eq $true) {
    throw "Field 'developmentBackend' must be false in $Mode mode."
  }
  if ($Config.identityName -notmatch '^[A-Za-z0-9.-]{3,50}$') {
    throw "Field 'identityName' must be a valid Partner Center package identity name in $Mode mode."
  }
  if ($Config.publisher -notmatch '^CN=.+') {
    throw "Field 'publisher' must be the exact Partner Center Publisher CN in $Mode mode."
  }
  if (-not [string]::IsNullOrWhiteSpace($Config.googleOAuthClientSecret) -and
      (Test-BusyMaxPlaceholder -Value ([string]$Config.googleOAuthClientSecret))) {
    throw "Field 'googleOAuthClientSecret' is still a placeholder in $Mode mode."
  }
  try {
    Assert-BusyMaxMsixVersion -Version ([string]$Config.msixVersion) `
      -PreviousVersion ([string]$Config.previousMsixVersion)
  } catch {
    throw "Field 'msixVersion' is invalid in $Mode mode: $($_.Exception.Message)"
  }
  foreach ($urlField in @('privacyPolicyUrl', 'supportUrl', 'homepageUrl')) {
    try {
      Assert-BusyMaxHttpsUrl -Name $urlField -Value $Config.$urlField
    } catch {
      throw "Field '$urlField' is invalid in $Mode mode: $($_.Exception.Message)"
    }
  }
}

function Get-BusyMaxPackageFamilyName {
  param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Publisher)
  if (-not ('BusyMax.PackageIdentity' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
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
      StringBuilder packageFamilyName);
    public static string FamilyName(string name, string publisher) {
      var id = new PACKAGE_ID { name = name, publisher = publisher };
      // PACKAGE_FAMILY_NAME_MAX_LENGTH is 64 characters, excluding the
      // terminating null. A fixed buffer avoids a nullable output pointer in
      // managed interop and follows Microsoft's documented C# example.
      uint length = 65;
      var value = new StringBuilder((int)length);
      int result = PackageFamilyNameFromId(ref id, ref length, value);
      if (result != 0) throw new Win32Exception(result,
        "PackageFamilyNameFromId failed");
      var familyName = value.ToString();
      if (String.IsNullOrWhiteSpace(familyName)) throw new InvalidOperationException(
        "PackageFamilyNameFromId returned an empty package family name");
      return familyName;
    }
  }
}
'@
  }
  return [BusyMax.PackageIdentity]::FamilyName($Name, $Publisher)
}

function Get-BusyMaxResourceLanguages {
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
  return @($locales)
}

function Get-BusyMaxResourceXml {
  return (Get-BusyMaxResourceLanguages | ForEach-Object {
      "    <Resource Language=`"$_`" />"
    }) -join "`r`n"
}

function Get-BusyMaxVCRuntimeDirectory {
  param([Parameter(Mandatory)][string]$RedistRoot)
  $rankedDirectories = @(Get-ChildItem -LiteralPath $RedistRoot -Directory |
    ForEach-Object {
      $directory = $_
      try {
        [pscustomobject]@{
          Directory = $directory
          IsNumericVersion = 1
          Version = [version]$directory.Name
        }
      } catch {
        # Recent Visual Studio layouts can include aliases such as `v145`
        # beside numeric redistributable versions. Keep them as a fallback.
        [pscustomobject]@{
          Directory = $directory
          IsNumericVersion = 0
          Version = [version]'0.0'
        }
      }
    } | Sort-Object -Property `
      @{ Expression = 'IsNumericVersion'; Descending = $true }, `
      @{ Expression = 'Version'; Descending = $true }, `
      @{ Expression = { $_.Directory.Name }; Descending = $true })
  foreach ($entry in $rankedDirectories) {
    $candidate = Get-ChildItem -LiteralPath `
      (Join-Path $entry.Directory.FullName 'x64') -Directory `
      -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending | Select-Object -First 1
    if ($null -ne $candidate) { return $candidate }
  }
  return $null
}

function Copy-BusyMaxVCRuntime {
  param(
    [Parameter(Mandatory)][string]$VisualStudioPath,
    [Parameter(Mandatory)][string]$Destination
  )
  $redistRoot = Join-Path $VisualStudioPath 'VC\Redist\MSVC'
  $crt = Get-BusyMaxVCRuntimeDirectory -RedistRoot $redistRoot
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
