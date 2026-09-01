# Windows development

BusyMax supports Windows 11 24H2 (`10.0.26100.0`) or newer on x64. Windows 10,
x86, ARM64, MSI, and EXE installers are intentionally outside the target.
Flutter and Dart must come from the repository's pinned Flutter 3.44.4 SDK.

## Prerequisites

- 64-bit Windows 11 24H2 or newer.
- Flutter 3.44.4 with Windows desktop enabled.
- Visual Studio 2022 with **Desktop development with C++**, including the x64
  MSVC toolchain and CMake tools.
- Windows SDK `10.0.26100.0` or newer.
- Pester 5 (CI pins 5.7.1) for packaging and WACK parser contracts.
- Developer Mode for unpackaged development, or a local test certificate for
  installed MSIX testing.

Check the toolchain from a PowerShell prompt at the repository root:

```powershell
flutter config --enable-windows-desktop
.\tools\windows\check_prerequisites.ps1
```

## Entry points

Entrypoints are always explicit. The Windows application must never be built
from the Linux default entrypoint.

```powershell
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
flutter run -d windows -t lib/main_windows.dart `
  --dart-define=BUSYMAX_WINDOWS_AUMID=BusyStack.BusyMax.Development `
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=<desktop-client-id> `
  --dart-define=MICROSOFT_OAUTH_CLIENT_ID=<public-client-id>
```

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
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
dart format --set-exit-if-changed .
flutter analyze
flutter test
dart run tool/check_platform_boundaries.dart
```

The Windows workflow can be started manually with `workflow_dispatch` and runs
automatically for pushes to `main` and `Release/**`. This permits validation of
the exact release-branch commit without first merging it into `main`.

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

The Drift schema version was 13 and remains 13. Existing migrations, the Linux
Snap configuration, and the Linux workflow remain in place.

## Current source-side validation

On 2026-08-31, the post-port working tree was validated on Linux with Flutter
3.44.4 and Dart 3.12.2:

| Command | Result |
| --- | --- |
| `flutter gen-l10n` | Passed; every supported catalog generated. |
| `dart run build_runner build --delete-conflicting-outputs` | Passed; generated Drift content remained consistent and the schema version remained 13. The pinned build runner reported that the legacy delete-conflicting option is ignored. |
| `dart format --output=none --set-exit-if-changed .` | Passed; 459 files checked, zero changes required. |
| `flutter analyze` | Passed; no issues found. |
| `dart run tool/check_platform_boundaries.dart` | Passed. |
| `flutter test --reporter compact` | Passed; 1,568 tests passed, 10 skipped, zero failed. |
| `flutter build linux --release -t lib/main_linux.dart` | Passed; produced `build/linux/x64/release/bundle/busymax`. |

These results establish Linux and platform-neutral source health only. They do
not replace the Windows gates below, a Windows CI result, or installed-package
testing.

## Windows-only verification

Compilation, native bridge validation, installed-package activation, package
identity notifications, StartupTask, screenshots, and WACK cannot be certified
from Linux. Run the checklist in [windows_release_checklist.md](windows_release_checklist.md)
on a clean Windows 11 host and retain the resulting artifacts.
