# Maintenance tools

Run these entry points from the repository root. Most detailed procedures live
in the linked development or release guides.

## Shared checks

- `verify_flutter_sdk.dart` verifies an explicitly supplied Flutter executable,
  its bundled Dart executable, and exact expected versions. It invokes only
  version commands and writes a JSON summary to standard output. Both CI
  workflows call it; see [Development](../docs/development.md).
- `check_platform_boundaries.dart` scans `lib/` and generated plugin
  registrations for forbidden Linux/Windows dependency crossings. It is
  read-only and is part of normal validation.

## Linux and Snap

- `install_linux_dev_desktop.sh` installs or removes a BusyMax desktop entry
  and icon in the current user's XDG data directory, then refreshes the desktop
  database when available. The files can take precedence over an installed
  Snap; follow the registration and removal instructions in
  [Development](../docs/development.md).
- `build_install_snap_local.sh` analyzes/tests by default, builds the Linux
  bundle, copies it into an installed or supplied Snap scaffold, creates a
  local package, installs it, and normally launches it. It replaces only its
  marked temporary root and does not purge user data. `--no-run` still
  installs the package. This is a scaffold helper, not the canonical release
  build; see [Snap beta release](../docs/beta_snap_release.md).

## Generated assets and API references

- `generate_windows_assets.dart` rewrites the committed Windows runner icon,
  tray icons, and MSIX PNG variants from
  `assets/branding/busymax-logo.png`. Review every generated image before
  committing it; see [Windows packaging](../docs/windows_packaging.md).
- `google_tasks_discovery/fetch_tasks_discovery.dart` makes a network request
  to Google's Tasks v1 discovery endpoint, rewrites the cached discovery JSON,
  and rewrites the checked-in discovery revision constant. It warns when the
  fetched revision differs from the locked revision. Run it only as a
  deliberate API-surface maintenance task, not as a build prerequisite.

## Windows build, signing, and validation

- `windows/check_prerequisites.ps1` verifies the pinned Flutter/bundled Dart
  pair, Visual Studio x64 C++ tools, Windows SDK, and optional Windows 11/WACK
  requirements. It returns structured environment information.
- `windows/build_release.ps1` is the main source-validation, Windows build,
  native-test, staging, MakeAppx packaging, and exact-artifact inspection
  workflow. It creates or replaces managed output under `build\windows`; see
  [Windows packaging](../docs/windows_packaging.md).
- `windows/create_test_certificate.ps1` creates an ignored local certificate
  and PFX/CER files. `windows/install_test_package.ps1` imports and trusts the
  certificate for the current user, signs a copy of the MSIX, and installs it.
  Both print cleanup commands and are only for installed-package testing.
- `windows/run_wack.ps1` resets and runs the Windows App Certification Kit for
  an exact package, then writes the XML report and parsed JSON summary. Warning
  dispositions are mandatory when WACK reports warnings.

The full Windows procedure and evidence requirements are in
[Windows packaging](../docs/windows_packaging.md) and the
[Windows release checklist](../docs/windows_release_checklist.md). Supporting
PowerShell modules and validators under `tool/windows/` are implementation
details of these entry points.
