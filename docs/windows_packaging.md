# Windows MSIX packaging

BusyMax produces an x64 Microsoft Store-mode MSIX for Windows 11 24H2 or newer.
The scripts build and inspect the package but never upload or deploy it.
Production Store artifacts remain unsigned locally; Store signing and local
test signing are separate workflows.

## Store configuration

Copy `config/windows_store.example.json` to the ignored
`config/windows_store.local.json` and replace every placeholder with the
owner's registered values:

- package identity name, Publisher CN, and publisher display name;
- four-part Store package version and optional previous version;
- privacy-policy, support, and homepage HTTPS URLs;
- Google desktop OAuth client ID and client secret;
- Microsoft public client ID and authority tenant; and
- `production=true`, `fakeData=false`, and `developmentBackend=false`.

Never commit the local file. Identity and desktop client values are embedded
configuration, not protected server-side secrets. Tokens, authorization codes,
certificates, PFX files, and passwords must never enter the configuration or
package.

The application version remains in `pubspec.yaml`. `msixVersion` is a
separate Store version with four numeric components. The first must be at least
1, the fourth must be 0, each must be at most 65535, and a supplied previous
version must compare lower. CI uses the non-production version `1.0.0.0`;
that is not the owner's release version.

Configuration validation has three modes:

- **ProductionStore** is the normal release build and requires the final owner
  identity with `production=true`.
- **CiNonProduction** is selected by `-Ci` and accepts only the committed
  workflow's non-production identity.
- **LocalTestSigning** accepts a complete production identity so the local test
  certificate can match the Publisher rendered into the package.

All modes reject placeholders, fake data, development backends, invalid
versions, and incomplete input. Production and local-test-signing modes require
production HTTPS URLs and complete OAuth configuration.

## Build and package

Use a 64-bit Windows 11 PowerShell prompt:

```powershell
.\tool\windows\build_release.ps1 `
  -ConfigPath config\windows_store.local.json
```

The script verifies Flutter 3.47.4 and bundled Dart 3.13.3, Visual Studio x64
C++ tools, and Windows SDK 10.0.26100.0 or newer. It runs source generation,
formatting, analysis, Dart/Flutter and PowerShell tests, platform-boundary and
native tests, builds `lib/main_windows.dart`, stages runtime files, validates
the manifest, packages the MSIX, unpacks the exact artifact, compares file
inventories, and prints metadata and SHA-256. It performs no deployment.

The manifest is rendered from
`tool/windows/AppxManifest.xml.template`. It declares x64, minimum OS
`10.0.26100.0`, internet-client and full-trust desktop capabilities,
`.ics` and `webcal` activation, a disabled-by-default StartupTask, toast COM
activation, localized resources, and BusyMax assets. `MaxVersionTested` comes
from the Windows SDK selected by the prerequisite check.

The repository keeps the `msix` Dart dependency pinned, but the release path
uses the selected Windows SDK's `MakeAppx` because the committed manifest
contains the complete StartupTask, toast activation, and language declarations.
The script stages the Flutter release, renders and validates the manifest, and
runs `MakeAppx pack /v`; no generated package output is hand-edited.

The package includes a whitelisted set of version-matched x64 Visual C++
runtime DLLs from the selected Visual Studio installation. Branding variants
come from `assets/branding/busymax-logo.png`. After changing that source,
regenerate and review the committed Windows assets:

```powershell
dart run tool/generate_windows_assets.dart
```

The current MakeAppx staging path uses the unqualified PNG files referenced by
the manifest. It rejects scale- or target-size-qualified staged variants and
does not require `resources.pri`.

## Local test signing and installation

For installed-package testing only:

```powershell
.\tool\windows\create_test_certificate.ps1 `
  -ConfigPath config\windows_store.local.json
.\tool\windows\install_test_package.ps1 `
  -ConfigPath config\windows_store.local.json `
  -PackagePath build\windows\store\BusyMax-<version>-x64.msix `
  -PfxPath build\windows\test-signing\busymax-test-only.pfx
```

The certificate script creates a local self-signed certificate and ignored
PFX/CER files, then prompts for a password. The installer imports the
certificate, verifies its subject against both configuration and the unpacked
MSIX manifest, signs a copied `BusyMax-test-signed.msix`, trusts it for the
current user, installs it, and prints package and certificate cleanup commands.
Never reuse or distribute the local test certificate as a production signing
credential.

## Package validation

`validate_manifest.ps1` checks architecture, OS target, identity, extensions,
StartupTask defaults, capabilities, language/resources, and placeholder
removal. `validate_package_contents.ps1` checks required Flutter, plugin,
SQLite, VC runtime, and asset files while rejecting source, certificates, logs,
databases, tests, fake data, debug symbols, Linux content, and unexpected
executables.

After packing, `package_store.ps1` unpacks the exact MSIX to a clean managed
directory, validates it again, records SHA-256 file inventories, and compares
the payload with staging except for MakeAppx package metadata. Retain the final
manifest, inventories, package metadata, and artifact checksum.

## WACK

After installing the release-equivalent test-signed package, run:

```powershell
.\tool\windows\run_wack.ps1 `
  -PackagePath build\windows\store\BusyMax-test-signed.msix
```

Retain the complete XML report and generated `wack-summary.json`. The script
requires a passing overall result and passing per-test results; a zero process
exit code or report file alone is insufficient.

For warnings, create a local JSON object whose keys exactly match the reported
warning names and whose values contain the written release disposition. Pass
it with `-WarningDispositionPath`. Empty, placeholder, or missing
dispositions fail validation. Repeat WACK after any native runner, dependency,
manifest, or package-content change.

Use the [Windows release checklist](windows_release_checklist.md) for installed
behavior, privacy review, accessibility, DPI, and release evidence.
