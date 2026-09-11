# Windows development

BusyMax supports Windows 11 24H2 (`10.0.26100.0`) or newer on x64. Windows 10,
x86, ARM64, MSI, and EXE installers are intentionally outside the target.
Flutter and Dart must come from the repository's pinned Flutter 3.47.2 SDK,
which bundles Dart 3.13.2.

## Prerequisites

- A 64-bit Windows build host for compilation and unsigned packaging. The
  GitHub workflow uses `windows-latest`.
- 64-bit Windows 11 24H2 or newer for installing, exercising, signing, and
  WACK-validating the release-equivalent package.
- Flutter 3.47.2 with Windows desktop enabled.
- Visual Studio 2022 with **Desktop development with C++**, including the x64
  MSVC toolchain and CMake tools.
- Windows SDK `10.0.26100.0` or newer.
- Pester 5 (CI pins 5.7.1) for packaging and WACK parser contracts.
- Developer Mode for unpackaged development, or a local test certificate for
  installed MSIX testing.

Check the build toolchain from a PowerShell prompt at the repository root.
This requires SDK 10.0.26100.0 or newer and never lowers the MSIX manifest's
Windows 11 24H2 minimum:

```powershell
flutter config --enable-windows-desktop
.\tool\windows\check_prerequisites.ps1
```

The prerequisite check selects the first `flutter` application on `PATH`,
normalizes that path, and invokes the Dart executable under that SDK's
`bin\cache\dart-sdk\bin`. It does not select an unrelated global Dart or
require Flutter and Dart to have the same immediate parent directory.

## Entry points

Entrypoints are always explicit. The Windows application must never be built
from the Linux default entrypoint.

```powershell
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
flutter run -d windows -t lib/main_windows.dart `
  --dart-define=BUSYMAX_WINDOWS_AUMID=BusyStack.BusyMax.Development `
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=<desktop-client-id> `
  --dart-define=MICROSOFT_OAUTH_CLIENT_ID=<public-client-id>
```

Location fields require no map-service configuration. Windows opens a saved
location through the default browser using a Google Maps search URL, or opens a
complete saved HTTP(S) link directly; BusyMax does not embed a map or geocoder.
Microsoft structured coordinates and iCalendar `GEO` remain native provider
data. Local supplemental rows are authored only when an imported/copied Google
event or series would otherwise lose its point; they are neither a search
history nor a Google-synchronized extension. Series reuse is account-,
calendar-, provider-series-, and location-snapshot-scoped.

An unpackaged build accurately reports Windows StartupTask as unavailable. It
does not create a registry or Startup-folder fallback. Windows notifications
are also deliberately unavailable without installed package identity, and the
Settings page shows that limitation. Display, cancellation, and action
callbacks must be exercised from a locally installed test-signed MSIX.

Linux continues to use:

```bash
flutter run -d linux -t lib/main_linux.dart
flutter build linux --release -t lib/main_linux.dart
```

## Source validation

Run these before requesting Windows CI:

```powershell
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
dart format --set-exit-if-changed .
flutter analyze
flutter test
dart run tool/check_platform_boundaries.dart
```

Both platform workflows run automatically for pull requests targeting `main`
and pushes to `main`; pushes to other branches do not independently start
either workflow. The Windows workflow can still be started manually with
`workflow_dispatch` on a selected branch.

For a given workflow and ref, a newer run cancels the superseded run without
affecting the other platform or unrelated pull requests. CI artifacts are
retained for seven days. Pull requests still build and validate the package,
but the Windows package artifact is retained only for successful `main` pushes
and manual runs.

The boundary checker fails if Windows/common code reaches Yaru, Ubuntu
localizations, DBus, freedesktop notifications, XDG tray, or GTK services, or
if business code reaches Fluent UI.

## Baseline recorded before the port

The original Linux tree was checked with Flutter 3.44.4 using `flutter pub
get`, `flutter gen-l10n`, `dart run build_runner build
--delete-conflicting-outputs --force-jit`, the formatting check, `flutter
analyze`, `flutter test`, and `flutter build linux --release`. Dependency
resolution, generation, formatting, analysis, and the Linux release build
succeeded. The test run recorded 1,508 passing tests, 10 skipped tests, and five
pre-existing failures: one Nextcloud recurrence parse/serialize case and four
account-add routing widget cases. This is a baseline record, not a waiver for
CI; the release workflows require a fully passing current test suite.

The Drift schema version at that baseline was 13. A later location-data
migration established schema 14; removing embedded maps does not roll it back
or delete its coordinate columns and `location_resolutions` records. Existing
migrations, the Linux Snap configuration, and the Linux workflow remain in
place.

## Current source-side validation

On 2026-09-10, the PR 15 release-blocker fixes and toolchain update through
source revision `c2e0e29` were validated on Linux with
`/home/albert/flutter-sdk/bin/flutter` 3.47.2 and its bundled
`/home/albert/flutter-sdk/bin/cache/dart-sdk/bin/dart` 3.13.2. The completion
report records the final documentation revision:

| Command | Result |
| --- | --- |
| SDK verifier | Passed; the selected Flutter executable, bundled Dart executable, normalized SDK roots, and exact 3.47.2/3.13.2 versions matched. |
| `flutter pub get --enforce-lockfile` | Passed; the Flutter 3.47.2 resolution matched the committed lockfile without changing it. The same command, localization generation, and build-runner generation also left a clean checkout of `c2e0e29` unchanged. |
| `flutter gen-l10n` | Passed; every supported catalog generated. |
| `dart run build_runner build --delete-conflicting-outputs --force-jit` | Passed; generated Drift content remained consistent and the schema version remained 14. The pinned build runner reported that the legacy delete-conflicting option is ignored. Its analyzer supports BusyMax's Dart 3.12 language constraint; the generator also reports that the newer bundled Dart 3.13 language is not yet enabled for source analysis. |
| `dart format --output=none --set-exit-if-changed .` | Passed; 528 files checked, zero changes required. |
| `flutter analyze` | Passed; no issues found. |
| `dart run tool/check_platform_boundaries.dart` | Passed. |
| Toolchain/workflow regressions | Passed; 9 tests cover SDK selection, wrapper and bundled-executable layouts, use of the verified executables by later build steps, and both workflow contracts. |
| `flutter test --concurrency=1 --reporter failures-only --file-reporter json:build/linux/test-results/flutter-tests-flutter-3.47.2.jsonl` | Passed; 1,975 tests passed, 10 credential-gated live tests skipped with explicit reasons, and zero failed. Report SHA-256: `05aa4c6c7104fe121dce048943412b4c38dba33b4b03437e20805613904e080b`. |
| `flutter build linux --release -t lib/main_linux.dart` | Passed; produced `build/linux/x64/release/bundle/busymax`. The completion report records the rebuilt artifact's SHA-256. |
| Snap packaging and installation | Not run for this revision by owner instruction. No Snap was built, installed, uploaded, or published as part of the toolchain update. |

These results establish Linux and platform-neutral source health only. They do
not replace the Windows gates below, successful Linux and Windows workflow runs
for the final revision, installed-package testing, or credential-gated live
provider checks.

## Windows-only verification

Compilation, native bridge validation, installed-package activation, package
identity notifications, StartupTask, screenshots, and WACK cannot be certified
from Linux. Run the checklist in [windows_release_checklist.md](windows_release_checklist.md)
on a clean Windows 11 host and retain the resulting artifacts.
