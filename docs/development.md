# Development

This guide is the shared setup and validation entry point for BusyMax on Linux
and Windows. Release packaging has separate procedures linked below.

## Shared setup

BusyMax development and CI use Flutter **3.47.5** and the Dart **3.13.4** SDK
bundled with that Flutter installation. Use the bundled `dart` executable; do
not mix Flutter with a different global Dart SDK. The `pubspec.yaml` constraint
`sdk: ^3.13.4` is the Dart language/package compatibility constraint. It is not
the repository's build-toolchain version.

The workflows verify the selected SDK with `tool/verify_flutter_sdk.dart`.
After installing Flutter 3.47.5, prepare the checkout in this order:

```bash
python3 tool/checkout_shared_dependencies.py
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
```

Dependency resolution must precede localization generation, which must precede
Drift generation. Generated localization and database files are committed; a
generation run should leave them unchanged.

The shared packages are ordinary siblings of `busymax/`. Their canonical URLs
and exact commits are recorded in `tool/shared_dependencies.json`.
`busystack_contacts` develops on `main`; its tested commit is pinned there for
reproducible builds while `pubspec.yaml` and `pubspec.lock` resolve the sibling
path. The checkout tool rejects a different origin, revision, or dirty sibling;
use the pinned checkouts before running Pub, CI, or release packaging.

New desktop **Connect with BusyMax** connections require explicitly active
registrations in [`BuildConfig`](../lib/src/config/build_config.dart):

- Google: `BUSYMAX_GOOGLE_OAUTH_CLIENT_ID`,
  `BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET`, and `BUSYMAX_GOOGLE_OAUTH_PROJECT_ID`.
- Microsoft: `BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID`. Managed connections always use
  `common` for personal and organizational Microsoft accounts. Custom
  registrations retain their own audience and tenant selections.

For local Linux releases, select the new external Google Desktop OAuth JSON.
The release tool derives managed `BUSYMAX_GOOGLE_OAUTH_*` values automatically,
including project metadata. Original Google credentials are not needed.
Use ignored local public settings for the established Microsoft client ID;
managed Microsoft remains optional. Custom provider registrations remain usable
in unconfigured development builds. See the [local Snap release procedure](beta_snap_release.md)
and [provider prerequisites](desktop_oauth_release_checklist.md).

## Linux development

Generic CalDAV development uses maintained, isolated Docker fixtures for
unmodified Radicale, Baïkal and BusyStack CalDAV Server, including root/non-root HTTPS, authenticated
readiness and independent readback. Follow the [fixture commands](../test/interop/caldav/README.md)
for setup, start, provisioning, test execution, reset and teardown. Normal
`flutter test` runs do not need Docker; real-server tests require the explicit
`BUSYMAX_CALDAV_LIVE=1` opt-in. Linux and Android native editor tests are separate
from protocol tests. The [qualification record](caldav_qualification.md) records
exact server versions and distinguishes native acceptance from unit coverage.

Schema 22 extends account CHECK constraints for `caldav`/`caldav_password` in a
transactional forward migration. The actual v0.4.0 schema-21 SQL fixture is in
`test/fixtures/schema_v21_v040.sql`; migration tests compare all seeded rows,
foreign keys, generations, sync state and queued work, and inject failure before
the version commit. Do not reset a user's database or downgrade a schema-22
database into an older application. Schema 23 adds the account-owned collection
creation journal. A random operation UUID and reserved remote URL are persisted
before dispatch; recovery uses that ID rather than a matching title. The
schema-22 additive migration and rollback are also tested. Never downgrade a
schema-23 database into an older application. Schema 24 adds safe rejection
diagnostics. Schema 25 stores terminal-notice acknowledgments separately from
the journal; dismissal preserves operation identity, execution state and
diagnostics. The schema-24 acknowledgment upgrade and interrupted-upgrade
rollback preserve all journal states and the active-name constraint. Do not
open a schema-25 database with an older application.

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

Linux GitHub Actions verifies source, locked dependencies, generated files,
formatting, analysis, platform boundaries, Flutter/native tests and an
unconfigured strict Snap packaging/install smoke test. It has no production
dispatch, OAuth credentials or artifact uploads. Windows and Android CI remain
independent. The official Linux build is `tool/release/build_snap_local.sh`;
`tool/build_install_snap_local.sh` only repacks a development scaffold.

### Android authorization engine coordination

`integration_test/android_authorization_leases_test.dart` runs a foreground
reader and a real WorkManager engine against the same native authorization gate.
It verifies overlapping readers, exclusive replacement, account independence and
lease cleanup with filesystem barriers. Use the isolated `busymaxNextcloudQa`
package and explicit test signer described below, with
`--dart-define=BUSYMAX_AUTHORIZATION_LEASE_QA=true`. It schedules and cancels only
its unique fixture job; the normal application and its work are untouched.
The retained-startup host tool also supports
`--package io.busystack.busymax.nextcloudqa`, verifies the APK and launcher, and
refuses to replace an existing target installation. Build
`integration_test/android_retained_startup_test.dart` with both
`--dart-define=BUSYMAX_RETAINED_STARTUP_QA=true` and
`--dart-define=BUSYMAX_SQLITE_TRACE=true`; the host requires the trace to prove
real database overlap. Traces record operation timing, never SQL text, parameters
or credentials. The same APK and original periodic jobs must survive restart.

### DAV transport regression comparison

Run `BUSYMAX_DAV_BENCHMARK=1 flutter test test/dav/trust/dav_transport_benchmark_test.dart`
for the maintained real-loopback TLS comparison of direct transport, exclusive
leases and shared leases under concurrent reads and mutations. Its synthetic
5,000-event payloads, eight task-list paths and controlled server delay isolate
transport overhead; results do not establish live Nextcloud synchronization
performance or native-platform acceptance.
The trash regression discovers all 300 objects representing 37.5 MiB of full
content through size-budgeted batches, and verifies that the old single full-body
response exceeds the unchanged limit. Run it with
`flutter test test/dav/nextcloud/nextcloud_administration_test.dart`.
For the real 300-object fixture, also enable `BUSYMAX_NEXTCLOUD_EXTENDED_LIVE=1`
and `BUSYMAX_NEXTCLOUD_TRASH_SCALE_LIVE=1`, and set
`BUSYMAX_NEXTCLOUD_LIVE_CONTAINER` to the explicitly disposable `busymax-qa-*`
server. Fixture preparation calls official backend APIs; BusyMax listing,
restoration and deletion use the configured account's pinned HTTPS transport.
The live fixture measures metadata listing separately from explicitly selected
full-detail reads and verifies restore/permanent-delete readback. These checks
remain separate from native Windows and Android acceptance.

Authorization acquisition and active HTTP ownership each have a separate
two-minute bound; the DAV operation deadline can cancel either sooner.
`test/core/http/authorization_leased_http_client_test.dart` checks the real
default durations with a fake clock; the real TLS concurrency regression also
queues longer than its scaled active budget before completing a slow response.
Native Linux qualification uses
`flutter test integration_test/nextcloud_private_tls_linux_test.dart -d linux`.
On a prepared Windows host with OpenSSL available in PATH:

```powershell
flutter test integration_test/nextcloud_private_tls_windows_test.dart -d windows
```

This Windows target exercises real loopback TLS, authorization replacement,
concurrency, abandonment and ordinary iCloud HTTPS. It does not use a user profile
or install fixture certificates into a platform trust store.

### Linux task lifecycle integration

Run [the native task lifecycle test](../integration_test/task_lifecycle_linux_test.dart)
explicitly after shared setup, with Linux desktop dependencies and a graphical
session available. The test requires `BUSYMAX_ACCEPTANCE_ROOT` and
`XDG_DATA_HOME` set to its `data` child:

```bash
busymax_acceptance_root="$(mktemp -d "${TMPDIR:-/tmp}/busymax-task-lifecycle.XXXXXX")"
mkdir -p "$busymax_acceptance_root/data"
BUSYMAX_ACCEPTANCE_ROOT="$busymax_acceptance_root" \
  XDG_DATA_HOME="$busymax_acceptance_root/data" \
  flutter test integration_test/task_lifecycle_linux_test.dart \
    -d linux --no-pub --reporter=expanded
```

The test uses a synthetic in-memory database/provider and in-memory secrets and
settings. The isolated data directory keeps native plugin state away from the
regular profile. It exercises the Yaru window, task creation and acknowledgment,
dirty-close guards, retry, hierarchy, ordering and deletion through real native
plugins. It does not contact a live provider. Use `GDK_BACKEND=x11` when selecting
an X11 session. The separate `tool/release/check_linux_native.sh` gate runs
native C++/GTK checks and requires `xvfb-run` from the `xvfb` package.

## Repository contents

Keep application and platform source, tests and synthetic fixtures, locked
dependencies, CI-verified generated sources, vendored code and licenses, build
recipes, shared launch configurations and maintained documentation in Git.
Reviewed product screenshots and test golden images are also source inputs.
The checked-in Google Tasks discovery document is a pinned API contract used by
tests, not a disposable build cache.

Keep local profiles, credentials, signing material, per-run logs, captures,
command receipts, delivery manifests and release artifacts outside Git. Use
ignored `build/` locations or temporary directories for validation evidence;
summarize results in the relevant pull request. Downloaded Google Desktop JSON
and local release settings follow the [local Snap release procedure](beta_snap_release.md).

The [read-only contacts integration](development/contacts-read-only.md)
documents the provider, authorization, storage and lifecycle boundaries and
their regression coverage.

## Release branches

Continue reviewed v0.4.0 work on the existing `release/v0.4.0` branch and its
release PR into `main`, with matching title `release/v0.4.0`. Fetch before final
review and incorporate later `origin/main` commits with a normal merge. The existing
`tool/check_release_pull_request.py` validates the actual PR head, release
metadata and current-main ancestry. A synthetic PR merge does not establish
that ancestry. Preserve worktrees and uncommitted work; do not rewrite history
or repeatedly squash feature branches into long-lived branches. The owner
reviews and merges the release PR. Official artifact production follows
[Local Snap beta release](beta_snap_release.md).

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
| [test/dav/nextcloud_contacts_live_test.dart](../test/dav/nextcloud_contacts_live_test.dart) | Same `BUSYMAX_NEXTCLOUD_LIVE_*` HTTPS fixture; reads through linked/independent resource and streaming transports and removes its disposable contact |
| [test/dav/nextcloud_login_flow_live_test.dart](../test/dav/nextcloud_login_flow_live_test.dart) | `BUSYMAX_NEXTCLOUD_LOGIN_LIVE=1`, `BUSYMAX_NEXTCLOUD_LOGIN_LIVE_URL`, `BUSYMAX_NEXTCLOUD_LOGIN_LIVE_USERNAME`, `BUSYMAX_NEXTCLOUD_LOGIN_LIVE_APP_PASSWORD` (disposable bootstrap password), `BUSYMAX_NEXTCLOUD_LOGIN_LIVE_TRUST_MODE` and, for private modes, `BUSYMAX_NEXTCLOUD_LOGIN_LIVE_TLS_CERT` |
| [test/dav/nextcloud_sharing_live_test.dart](../test/dav/nextcloud_sharing_live_test.dart) | `BUSYMAX_NEXTCLOUD_SHARING_LIVE=1`, `BUSYMAX_NEXTCLOUD_SHARING_LIVE_URL`, `BUSYMAX_NEXTCLOUD_SHARING_LIVE_GROUP`, and `BUSYMAX_NEXTCLOUD_SHARING_LIVE_<ROLE>_USERNAME` / `BUSYMAX_NEXTCLOUD_SHARING_LIVE_<ROLE>_PASSWORD` for each of `OWNER`, `WRITER`, `READER`, `GROUP_MEMBER` |
| [test/dav/nextcloud_extended_live_test.dart](../test/dav/nextcloud_extended_live_test.dart) | `BUSYMAX_NEXTCLOUD_EXTENDED_LIVE=1`, the HTTPS `BUSYMAX_NEXTCLOUD_LIVE_*` fixture, `BUSYMAX_NEXTCLOUD_EXTENDED_LIVE_ATTENDEE_USERNAME`, and `BUSYMAX_NEXTCLOUD_MAIL_CAPTURE_DIR` |
| [test/dav/apple_icloud_live_integration_test.dart](../test/dav/apple_icloud_live_integration_test.dart) | `BUSYMAX_ICLOUD_LIVE=1`, `BUSYMAX_ICLOUD_LIVE_USERNAME` (QA Apple Account email), `BUSYMAX_ICLOUD_LIVE_PASSWORD` (BusyMax-only app-specific password) |

The calendar/task, Login Flow and sharing suites also require `BUSYMAX_NEXTCLOUD_QA_CALENDAR_VERSION`
and `BUSYMAX_NEXTCLOUD_QA_TASKS_VERSION` with the versions actually installed;
Server version is read from `status.php`. Supply the installation root,
including any path prefix. DAV and sharing fixtures allow HTTP only on isolated
loopback hosts. Login Flow requires HTTPS. Each Nextcloud suite uses its prefix
with `_TRUST_MODE=standard`, `private_ca`, or `pinned_leaf`; private modes require
`_TLS_CERT` with the explicitly approved disposable CA or self-signed leaf.
The suites use the production account-scoped factory. Run both private modes;
see [private-certificate verification](nextcloud_private_certificates.md).
Optionally set
`BUSYMAX_NEXTCLOUD_LOGIN_LIVE_BROWSER` to a Chrome-compatible executable. Run
Login Flow at both the server root and a path-prefixed installation; it revokes
the returned app password. Production connections always require HTTPS and
the accepted account TLS policy. Browser trust must be provisioned separately
in the isolated browser environment; the fixture does not bypass browser
certificate validation.

The separate captured-revocation case additionally needs
`BUSYMAX_NEXTCLOUD_LOGIN_LIVE_REVOCATION_APP_PASSWORD`. Use a different disposable
app password from the DAV/contacts fixture: this case revokes it. Run live files
with `--concurrency=1` against an SQLite QA server. Repeated collection creation
can exhaust Nextcloud's default hourly quota; configure only the disposable
server's documented `dav/rateLimitCalendarCreation` setting for repeated runs.

The extended suite uses production discovery, queued mutations and synchronization.
Provision distinct organizer/attendee QA users with valid `.invalid` email addresses,
default calendars, enabled invitations and a local SMTP capture service. Use
Nextcloud 35.0.2 with a supported database, and record installed Calendar/Tasks
versions. Run this suite serially when accounts are shared between cases.
The external-cancellation test compares BusyMax delivery with raw conditional
CalDAV writes; a stored event or HTTP 204 is insufficient for that test.

For real federation, additionally set `BUSYMAX_NEXTCLOUD_FEDERATION_LIVE=1`, the
peer's `BUSYMAX_NEXTCLOUD_FEDERATION_LIVE_URL`, `_USERNAME`, `_PASSWORD`,
`_TRUST_MODE` and `_TLS_CERT`, plus `_CLOUD_ID` from the peer's canonical
`occ user:info --output=json` result. Include ports and installation paths.
`_CONTAINER` must name the explicitly disposable `busymax-qa-*` peer on which
the test executes the official `occ federation:sync-calendars` command. The
servers must validate each other's HTTPS, and trusted-peer auto-accept must be
disabled to exercise pending invitation acceptance. Do not disable TLS checks.

The disabled-feature cases require a separately configured disposable server
and `BUSYMAX_NEXTCLOUD_DISABLED_FREEBUSY_LIVE=1` or
`BUSYMAX_NEXTCLOUD_DISABLED_RETENTION_LIVE=1`. Restore its previous settings
after testing. These cases distinguish unavailable privileges and zero retention
from connection failures.

[integration_test/nextcloud_workflows_test.dart](../integration_test/nextcloud_workflows_test.dart)
runs real platform controls against these HTTPS fixtures. Supply
`BUSYMAX_NEXTCLOUD_UI_FIXTURE` as base64 JSON containing the same environment
values, using `--dart-define-from-file` with a temporary file outside source.
Public certificate PEM can be supplied as `_TLS_CERT_PEM` for device builds.
Build the test target in release mode for Linux, Windows and Android; observe
`BUSYMAX_NEXTCLOUD_UI_RESULT PASS` from the native process. Keep the official
server federation job running during the native tests, which observe bounded
cache convergence. Use separate QA users per platform for concurrent runs.
Desktop runs can set `BUSYMAX_NEXTCLOUD_UI_RESULT_FILE` to a temporary absolute
path for progress and a structured final result when a GUI runner has no console.
Require `passed: true`, a configured fixture and all four named workflows.
The release driver registers its text-input client before editing; Flutter's
debug-only text-input client ID is ignored in release mode.
The Android QA build requires both `busymaxTestSigning=true` and
`busymaxNextcloudQa=true` Gradle properties and installs as
`io.busystack.busymax.nextcloudqa`, leaving the normal package untouched.

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
