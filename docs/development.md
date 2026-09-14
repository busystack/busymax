# Development

This guide is the shared setup and validation entry point for BusyMax on Linux
and Windows. Release packaging has separate procedures linked below.

## Shared setup

BusyMax development and CI use Flutter **3.47.2** and the Dart **3.13.2** SDK
bundled with that Flutter installation. Use the bundled `dart` executable; do
not mix Flutter with a different global Dart SDK. The `pubspec.yaml` constraint
`sdk: ^3.12.0` is the Dart language/package compatibility constraint. It is not
the repository's build-toolchain version.

The workflows verify the selected SDK with `tool/verify_flutter_sdk.dart`.
After installing Flutter 3.47.2, prepare the checkout in this order:

```bash
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
```

Dependency resolution must precede localization generation, which must precede
Drift generation. Generated localization and database files are committed; a
generation run should leave them unchanged.

Google and Microsoft sign-in require provider-specific build configuration.
You can build, inspect, and test the application without registering both
providers. Add only the configuration for the sign-in flows you need:

- `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET`: see
  [Google OAuth registration](google_setup.md).
- `MICROSOFT_OAUTH_CLIENT_ID`: see
  [Microsoft OAuth registration](microsoft_setup.md).

Apple iCloud Calendar and Nextcloud do not use compile-time OAuth client
credentials.

## Linux development

The Linux CI build runs on Ubuntu 24.04 and installs the following packages:

```bash
sudo apt-get install -y \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  libgtk-3-dev \
  libhandy-1-dev \
  libstdc++-12-dev \
  libsecret-1-dev \
  libjsoncpp-dev \
  liblzma-dev
```

The CMake project directly requires GTK 3, GLib/GIO, and libhandy; the
additional CI libraries cover the registered Flutter plugins and native build
environment.

Run the Linux composition explicitly:

```bash
flutter config --enable-linux-desktop
flutter run -d linux -t lib/main_linux.dart
```

Append the relevant `--dart-define` arguments when testing Google or Microsoft
sign-in.

### Development desktop registration

Register the checkout for the current user so GNOME can associate native
Wayland windows with the BusyMax launcher and icon:

```bash
tool/install_linux_dev_desktop.sh
```

The helper writes a marked desktop entry and icon below the user's XDG data
directory. It defaults to the Flutter debug bundle and accepts
`--executable FILE`. Remove its files with:

```bash
tool/install_linux_dev_desktop.sh --uninstall
```

Remove this user-level launcher before testing an installed Snap. Desktop
search can prefer it over the packaged launcher.

## Windows development

BusyMax targets Windows 11 24H2 (`10.0.26100.0`) or newer on x64. Windows 10,
x86, ARM64, MSI, and EXE installers are outside the supported target.

Install:

- Flutter 3.47.2 with Windows desktop enabled;
- Visual Studio 2022 with **Desktop development with C++**, the x64 MSVC
  toolchain, and CMake tools;
- Windows SDK `10.0.26100.0` or newer; and
- Pester 5 when running the packaging contract tests (CI uses 5.7.1).

From a PowerShell prompt at the repository root, verify the environment:

```powershell
flutter config --enable-windows-desktop
.\tool\windows\check_prerequisites.ps1
```

Run the Windows composition explicitly. This example configures both browser
sign-in providers and includes the Google desktop client secret required by the
Google setup guide:

```powershell
flutter run -d windows -t lib/main_windows.dart `
  --dart-define=BUSYMAX_WINDOWS_AUMID=BusyStack.BusyMax.Development `
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=<desktop-client-id> `
  --dart-define=GOOGLE_OAUTH_CLIENT_SECRET=<desktop-client-secret> `
  --dart-define=MICROSOFT_OAUTH_CLIENT_ID=<public-client-id>
```

Omit the defines for providers you are not testing. An unpackaged development
build reports `StartupTask` as unavailable and does not use a registry or
Startup-folder substitute. Windows notification display, cancellation, and
action callbacks require installed package identity, so exercise them with the
test-signed MSIX described in [Windows packaging](windows_packaging.md).

## Validation

After the shared preparation sequence, run the normal offline checks:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
dart run tool/check_platform_boundaries.dart
```

The platform-boundary checker prevents shared or Windows code from reaching
Linux-only UI and services, and prevents shared business or Linux code from
depending on Fluent UI.

Normal `flutter test` skips credential-gated provider tests. Those tests mutate
remote data and have separate setup and safety requirements in
[Live-provider testing](live_provider_testing.md).

The Linux and Windows workflows run for pull requests targeting `main` and
pushes to `main`; Windows also supports a manual dispatch. A newer run for the
same workflow and ref cancels the superseded run. Windows test reports are
retained for every run, while the unsigned CI MSIX and package evidence are
retained for seven days only after a successful `main` push or manual run.
The workflows do not deploy Windows packages.

For release artifacts, follow [Snap beta release](beta_snap_release.md) or
[Windows packaging](windows_packaging.md) and the
[Windows release checklist](windows_release_checklist.md).

## Optional feedback endpoint

Local website development can override the feedback destination with the
compile-time `BUSYSTACK_FEEDBACK_ENDPOINT` setting, for example:

```bash
flutter run -d linux -t lib/main_linux.dart \
  --dart-define=BUSYSTACK_FEEDBACK_ENDPOINT=http://127.0.0.1:8090/api/feedback
```

The configuration is defined in
[`BuildConfig`](../lib/src/config/build_config.dart); submission behavior lives
in the [feedback client](../lib/src/features/feedback/data/feedback_api_client.dart).
