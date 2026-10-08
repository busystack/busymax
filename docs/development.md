# Development

This guide is the shared setup and validation entry point for BusyMax on Linux
and Windows. Release packaging has separate procedures linked below.

## Shared setup

BusyMax development and CI use Flutter **3.47.5** and the Dart **3.13.4** SDK
bundled with that Flutter installation. Use the bundled `dart` executable; do
not mix Flutter with a different global Dart SDK. The `pubspec.yaml` constraint
`sdk: ^3.12.0` is the Dart language/package compatibility constraint. It is not
the repository's build-toolchain version.

The workflows verify the selected SDK with `tool/verify_flutter_sdk.dart`.
After installing Flutter 3.47.5, prepare the checkout in this order:

```bash
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
```

Dependency resolution must precede localization generation, which must precede
Drift generation. Generated localization and database files are committed; a
generation run should leave them unchanged.

New desktop **Connect with BusyMax** connections require explicitly active
registrations in [`BuildConfig`](../lib/src/config/build_config.dart):

- Google: `BUSYMAX_GOOGLE_OAUTH_CLIENT_ID`,
  `BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET`, and `BUSYMAX_GOOGLE_OAUTH_PROJECT_ID`.
- Microsoft: `BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID`. Managed connections always use
  `common` for personal and organizational Microsoft accounts. Custom
  registrations retain their own audience and tenant selections.

Protected `GOOGLE_OAUTH_*` and `MICROSOFT_OAUTH_*` originals serve eligible
existing account bindings. Keep them separate from active registrations; they
do not enable new managed connections or provide an implicit fallback. You can
build and run offline tests without provider configuration; unconfigured
desktop builds keep custom registration setup available.

Use the [Google](google_setup.md) and [Microsoft](microsoft_setup.md) registration
guides for custom setup. Official packages must pass
`dart run tool/check_desktop_oauth_config.dart --config <dart-defines.json>`;
the [desktop OAuth release checklist](desktop_oauth_release_checklist.md) owns the
complete configuration and provider approval requirements.

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

- Flutter 3.47.5 with Windows desktop enabled;
- Visual Studio 2022 with **Desktop development with C++**, the x64 MSVC
  toolchain, and CMake tools;
- Windows SDK `10.0.26100.0` or newer; and
- Pester 5 when running the packaging contract tests (CI uses 5.7.1).

From a PowerShell prompt at the repository root, verify the environment:

```powershell
flutter config --enable-windows-desktop
.\tool\windows\check_prerequisites.ps1
```

Run the Windows composition explicitly. This example supplies active
registrations for both browser sign-in providers:

```powershell
flutter run -d windows -t lib/main_windows.dart `
  --dart-define=BUSYMAX_WINDOWS_AUMID=BusyStack.BusyMax.Development `
  --dart-define=BUSYMAX_GOOGLE_OAUTH_CLIENT_ID=<desktop-client-id> `
  --dart-define=BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET=<desktop-client-secret> `
  --dart-define=BUSYMAX_GOOGLE_OAUTH_PROJECT_ID=<actual-project-id> `
  --dart-define=BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID=<public-client-id>
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

Normal `flutter test` skips credential-gated provider tests. See
[Live-provider tests](#live-provider-tests) for their setup and safety requirements.

The Linux and Windows workflows run for pull requests targeting `main` and
pushes to `main`; both also support manual dispatch. Routine Linux CI requires
no production OAuth configuration: it builds, installs, and verifies an
unconfigured strict Snap with custom registration available and managed
connections unavailable. Its verified artifact is explicitly labeled
`busymax-linux-ci-unconfigured-non-production` and must not be published.
Manual Linux runs are restricted to `main`; selecting `production_release`
validates production registrations and builds a verified production Snap.
Without that selection, a manual run remains non-production CI.
A newer run for the same workflow and ref cancels the superseded run. Windows
test reports are retained for every run, while the unsigned CI MSIX and package
evidence are retained for seven days only after a successful `main` push or manual run.
The workflows do not deploy Windows packages.

For release artifacts, follow [Snap beta release](beta_snap_release.md) or
[Windows packaging](windows_packaging.md) and the
[Windows release checklist](windows_release_checklist.md).

## Live-provider tests

Live tests require explicit opt-in through the environment variables below.
Use only disposable QA accounts, isolated test servers, and QA-only invitation
recipients: these tests create and delete remote collections and objects,
change sharing permissions, and revoke app passwords. Never send invitations
to arbitrary attendees from imported data or use trash bypass for ordinary
deletion. Pass credentials through the test process environment; keep
credentials, DAV paths, Login Flow URLs/tokens, raw iCalendar, and user content
out of logs, screenshots, and bug reports.

Run `flutter test <path>` for the selected entry point:

| Test path | Required environment variables |
|---|---|
| [test/dav/nextcloud_live_integration_test.dart](../test/dav/nextcloud_live_integration_test.dart) | `BUSYMAX_NEXTCLOUD_LIVE=1`, `BUSYMAX_NEXTCLOUD_LIVE_URL`, `BUSYMAX_NEXTCLOUD_LIVE_USERNAME`, `BUSYMAX_NEXTCLOUD_LIVE_PASSWORD` (QA app password) |
| [test/dav/nextcloud_login_flow_live_test.dart](../test/dav/nextcloud_login_flow_live_test.dart) | `BUSYMAX_NEXTCLOUD_LOGIN_LIVE=1`, `BUSYMAX_NEXTCLOUD_LOGIN_LIVE_URL`, `BUSYMAX_NEXTCLOUD_LOGIN_LIVE_USERNAME`, `BUSYMAX_NEXTCLOUD_LOGIN_LIVE_APP_PASSWORD` (disposable bootstrap password), `BUSYMAX_NEXTCLOUD_LOGIN_LIVE_TLS_CERT` (test CA PEM) |
| [test/dav/nextcloud_sharing_live_test.dart](../test/dav/nextcloud_sharing_live_test.dart) | `BUSYMAX_NEXTCLOUD_SHARING_LIVE=1`, `BUSYMAX_NEXTCLOUD_SHARING_LIVE_URL`, `BUSYMAX_NEXTCLOUD_SHARING_LIVE_GROUP`, and `BUSYMAX_NEXTCLOUD_SHARING_LIVE_<ROLE>_USERNAME` / `BUSYMAX_NEXTCLOUD_SHARING_LIVE_<ROLE>_PASSWORD` for each of `OWNER`, `WRITER`, `READER`, `GROUP_MEMBER` |
| [test/dav/apple_icloud_live_integration_test.dart](../test/dav/apple_icloud_live_integration_test.dart) | `BUSYMAX_ICLOUD_LIVE=1`, `BUSYMAX_ICLOUD_LIVE_USERNAME` (QA Apple Account email), `BUSYMAX_ICLOUD_LIVE_PASSWORD` (BusyMax-only app-specific password) |

Every Nextcloud suite also requires `BUSYMAX_NEXTCLOUD_QA_CALENDAR_VERSION`
and `BUSYMAX_NEXTCLOUD_QA_TASKS_VERSION` with the versions actually installed;
Server version is read from `status.php`. Supply the installation root,
including any path prefix. DAV and sharing fixtures allow HTTP only on isolated
loopback hosts. Login Flow requires HTTPS with its test CA; optionally set
`BUSYMAX_NEXTCLOUD_LOGIN_LIVE_BROWSER` to a Chrome-compatible executable. Run
Login Flow at both the server root and a path-prefixed installation; it revokes
the returned app password. Production connections always require HTTPS and
normal platform certificate validation.

For the DAV suite's large-collection case, also set
`BUSYMAX_NEXTCLOUD_LIVE_LARGE=1`. To test restart persistence, set a unique
`BUSYMAX_NEXTCLOUD_LIVE_RESTART_ID` and
`BUSYMAX_NEXTCLOUD_LIVE_RESTART_STAGE=prepare`, run the DAV suite, restart the
server without replacing its storage, then rerun the same suite with the same
ID and `BUSYMAX_NEXTCLOUD_LIVE_RESTART_STAGE=verify`.

The Apple fixture needs two-factor authentication and at least two calendars.
Set `BUSYMAX_ICLOUD_LIVE_EXPECT_SHARED_WRITABLE=1` and/or
`BUSYMAX_ICLOUD_LIVE_EXPECT_SHARED_READ_ONLY=1` only when those shared fixtures
exist. Deterministic tests do not establish live authorization, provider
delivery, or server interoperability. Keep per-run logs, captures, evidence,
archives, and checksums in ignored `build/` locations or temporary directories;
CI artifact uploads remain appropriate.

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
