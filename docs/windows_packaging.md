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

The scripts enforce three non-interchangeable validation modes:

- `ProductionStore` is selected by the normal release build. It requires the
  owner's final identity and `production=true`.
- `CiNonProduction` is selected only by `-Ci`. It requires
  `production=false` and the exact committed CI identity used by the Windows
  workflow. An owner or production configuration is rejected.
- `LocalTestSigning` is selected by the certificate and installation scripts.
  It accepts the owner's complete production identity so the local certificate
  subject can exactly match the Publisher rendered into the package. It never
  applies CI identity rules.

Every mode rejects placeholders, fake data, development backends, invalid
Store versions, and incomplete inputs. Production and local-test-signing modes
also require production HTTPS and OAuth configuration.

## Build

From a 64-bit Windows 11 PowerShell prompt:

```powershell
.\tools\windows\build_release.ps1 `
  -ConfigPath config\windows_store.local.json
```

The script checks Windows, Flutter 3.44.4, Visual Studio x64 C++ tools, and a
Windows 11 SDK; resolves dependencies; generates localization and Drift code;
checks committed generation, formatting, analysis, tests, architecture
boundaries, PowerShell contracts, native runner/plugin tests, and release
inputs; builds `lib/main_windows.dart`; stages release runtime files; renders
and validates the manifest; packs the MSIX; and prints its path, metadata, and
SHA-256. It performs no network deployment.

`MaxVersionTested` is taken from the Windows SDK selected by the prerequisite
check, so the manifest cannot claim a newer SDK than the release builder used.

The manifest is rendered reproducibly from
`tools/windows/AppxManifest.xml.template`. It declares x64, minimum OS
`10.0.26100.0`, only internet client and full-trust desktop capabilities, `.ics`,
`webcal`, StartupTask, toast activation, resource languages derived from ARB
catalogs, and BusyMax visual assets. It contains no location, microphone,
webcam, contacts, broad-filesystem, or private-network capability.

Toast activation uses the base `desktop:Extension` and
`desktop:ToastNotificationActivation` schema. Its CLSID is validated against
both the COM class and the notification backend constant. The obsolete
`desktop4` namespace is neither declared nor accepted for this extension.

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

The Store package deliberately stages concrete, unqualified PNG files for all
four manifest logo paths. Scale-qualified source variants remain committed for
review and possible future PRI-based packaging, but this packaging path does
not place them in the MSIX. `validate_package_contents.ps1` rejects a staged
`.scale-*` or `.targetsize-*` asset and confirms every logo reference resolves
to a real file after the exact MSIX is unpacked. Consequently this path does
not require or pretend to contain `resources.pri`.

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
command for cleanup. Both scripts validate in `LocalTestSigning` mode. They
verify the generated/imported certificate subject against the configured
Publisher, and the installer unpacks the actual MSIX and verifies the same
subject against its `AppxManifest.xml` before signing. The unsigned Store-mode
artifact must not depend on this development certificate.

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

Validation is not limited to staging. After `MakeAppx` packs the artifact, the
packaging script unpacks that exact MSIX into a new clean directory, reruns the
manifest/content checks, writes a per-file SHA-256 inventory, and compares the
unpacked inventory with the deterministic staging inventory (excluding only
the package metadata files produced by `MakeAppx`). Both inventories are CI
artifacts. `MakeAppx pack /v` is also the mandatory Windows SDK schema and
package validation gate; a successful custom XML check alone cannot produce an
artifact.

After installing a release-equivalent locally signed package, run:

```powershell
.\tools\windows\run_wack.ps1 `
  -PackagePath build\windows\store\BusyMax-test-signed.msix
```

Retain the XML report. Any native runner, dependency, manifest, or packaging
change invalidates an earlier WACK result and requires a repeat. See the
[release checklist](windows_release_checklist.md) for behavioral coverage.

`run_wack.ps1` parses both `OVERALL_RESULT` and every per-test `RESULT`; a zero
process exit code or a report file by itself is not accepted. Missing, empty,
malformed, result-free, or failing reports stop the release. When WACK emits a
warning, create a local JSON object whose keys exactly match the warning names
printed by the script and whose values are the written release dispositions,
then pass it with `-WarningDispositionPath`. The script refuses warnings with
missing, placeholder, or empty dispositions and emits `wack-summary.json`
beside the complete XML report.
