# Windows MSIX packaging

BusyMax produces an x64 Microsoft Store-mode MSIX. The scripts never upload or
deploy it. The production artifact is unsigned locally because Microsoft Store
signing is separate from local test signing.

## Identity configuration

Copy `config/windows_store.example.json` to the ignored path
`config/windows_store.local.json` and replace every placeholder with values the
owner obtained for this product:

- package identity name;
- Publisher CN;
- publisher display name;
- four-part Store package version;
- previous package version when monotonic comparison is wanted;
- privacy-policy, support, and homepage HTTPS URLs;
- Google desktop OAuth client ID/configuration;
- Microsoft public client ID and authority tenant;

Do not commit the local file. Identity values are not secrets, but they must
match the final product registration exactly. OAuth tokens, authorization
codes, certificates, PFX files, and passwords must never enter configuration or
the package.

The product version remains in `pubspec.yaml`. `msixVersion` is independent and
must have four numeric components, a first component of at least 1, a fourth
component of 0, and components no greater than 65535. If a previous version is
provided, the new value must be greater. CI deliberately uses non-production
`1.0.0.0`; it is not an owner production version.

## Build

From a 64-bit Windows 11 PowerShell prompt:

```powershell
.\tools\windows\build_release.ps1 `
  -ConfigPath config\windows_store.local.json
```

The script checks Windows, Flutter 3.44.4, Visual Studio x64 C++ tools, and a
Windows 11 SDK; resolves dependencies; generates localization and Drift code;
checks committed generation, formatting, analysis, tests, architecture
boundaries, and release inputs; builds `lib/main_windows.dart`; stages release
runtime files; renders and validates the manifest; packs the MSIX; and prints
its path, metadata, and SHA-256. It performs no network deployment.

`MaxVersionTested` is taken from the Windows SDK selected by the prerequisite
check, so the manifest cannot claim a newer SDK than the release builder used.

The manifest is rendered reproducibly from
`tools/windows/AppxManifest.xml.template`. It declares x64, minimum OS
`10.0.26100.0`, only internet client and full-trust desktop capabilities, `.ics`,
`webcal`, StartupTask, toast activation, resource languages derived from ARB
catalogs, and BusyMax visual assets. It contains no location, microphone,
webcam, contacts, broad-filesystem, or private-network capability.

`msix` remains pinned as the repository's Store packaging tool dependency, but
its generated configuration does not express BusyMax's complete combination of
StartupTask parameters, full-trust toast COM activation, and resource-derived
languages. The release script therefore follows the documented deterministic
fallback: stage the Flutter release, render the committed manifest template,
validate it, and invoke the selected Windows SDK's `MakeAppx`. No generated
output is hand-edited.

Runner, tray, file-association, and package logo variants are derived from the
existing `assets/branding/busymax-logo.png`; no separate product mark is used.
After changing that source branding asset, regenerate and review all committed
Windows assets with:

```powershell
dart run tool/generate_windows_assets.dart
```

The startup extension passes `--start-minimized` through its schema-valid
`uap10:Parameters` attribute. The nested `desktop:StartupTask` remains disabled
by default; that element does not define an arguments attribute.

## Local test signing and installation

For installed-package testing only:

```powershell
.\tools\windows\create_test_certificate.ps1 `
  -ConfigPath config\windows_store.local.json
.\tools\windows\install_test_package.ps1 `
  -ConfigPath config\windows_store.local.json `
  -PackagePath build\windows\store\BusyMax-<version>-x64.msix `
  -PfxPath build\windows\test-signing\busymax-test-only.pfx
```

The password is prompted, never stored. PFX/CER files and the signed copy stay
under ignored build output. The installer prints a package-specific uninstall
command for cleanup. The unsigned Store-mode artifact must not depend on this
development certificate.

## Validation

The staging step includes only the whitelisted, version-matched x64 Visual C++
redistributable DLLs from the selected Visual Studio installation, so a clean
machine does not need developer tools or a preinstalled VC runtime.

`validate_manifest.ps1` enforces architecture, OS target, extensions,
stable application/executable identity, StartupTask defaults, the exact `.ics`
and `webcal` registration set, capabilities, and placeholder removal.
`validate_package_contents.ps1` rejects source, PFX/CER, logs, databases, test
data, fake data, debug symbols, Linux/Snap content, extra executables, and
template branding while checking required Flutter assets and DLLs.

After installing a release-equivalent locally signed package, run:

```powershell
.\tools\windows\run_wack.ps1 `
  -PackagePath build\windows\store\BusyMax-test-signed.msix
```

Retain the XML report. Any native runner, dependency, manifest, or packaging
change invalidates an earlier WACK result and requires a repeat. See the
[release checklist](windows_release_checklist.md) for behavioral coverage.
