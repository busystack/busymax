# Android setup and provider registration

BusyMax Android is a beta application with package ID
`io.busystack.busymax`, version `0.4.3`, minimum API 24, and compile/target
API 37. The supported toolchain is Flutter 3.50.1, its bundled Dart 3.14.0,
JDK 17, Android platform 37, and Build Tools 37.x.

The Android build uses Gradle 9.4.1 and Android Gradle Plugin 9.2.0 with built-in
Kotlin. It retains the legacy AGP DSL for the resolved Android plugins. The
included Flutter Gradle build resolves its own compile-time dependencies,
including AGP 9.1.1, Kotlin Gradle Plugin 2.4.10 and Kotlin serialization JSON
1.11.0. An offline build requires those artifacts in Gradle's cache.

Run the prerequisite check before changing the project:

```sh
tool/android/check_prerequisites.sh
cp android/busymax.android.properties.example android/busymax.android.properties
```

`android/busymax.android.properties` is ignored. It contains public
registration values and public web links, never passwords or client secrets.
`android/local.properties` remains the normal ignored Android SDK pointer.

The public configuration keys have these exact consumers:

| Key | Consumer |
|---|---|
| `google.androidPackage` | Owner/CI registration check record; Google Identity Services validates the compiled application ID directly. |
| `google.debugSha256`, `google.releaseSha256`, `google.playSha256` | Owner/CI registration records for the three signer contexts; fingerprints are not credentials or embedded OAuth secrets. |
| `microsoft.clientId` | Gradle-generated MSAL string resource and `raw/busymax_msal_config.json`. |
| `microsoft.authorityTenant` | Audience tenant in the generated MSAL configuration; defaults to `common`. |
| `microsoft.signatureHash` | URL-encoded signer component of the generated `msauth` redirect. |
| `busymax.privacyPolicyUrl`, `busymax.supportUrl`, `busymax.homepageUrl` | `tool/android/build_release.sh` maps these to the corresponding `BUSYMAX_*` Dart defines consumed by `BuildConfig`. |

## Google Identity Services

Create Android OAuth registrations for `io.busystack.busymax`, enable the
Google Calendar and Google Tasks APIs, and register every certificate context
that will install the app: debug, locally distributed release, and Play app
signing. The Android OAuth client in Google Cloud must match the application ID
and the signing certificate's **SHA-1** fingerprint. The SHA-256 values in the
local configuration are owner records; they do not register an OAuth client,
and Gradle does not send them to Google. Google authorization uses
the on-device `AuthorizationClient` with explicit account selection. The
desktop client ID and desktop client secret are neither required nor embedded
on Android. An AOSP device without Google Play services intentionally leaves
only Google unavailable; Microsoft, Apple, Nextcloud, and WebCal remain usable.

The isolated `io.busystack.busymax.caldavqa` and
`io.busystack.busymax.nextcloudqa` packages need their own Android OAuth clients
if used for Google testing. Registering `io.busystack.busymax` does not cover
those package names. A package/signature rejection can occur after the account
chooser; Google's device log reports that the application is not registered.
For normal account setup, launch the **BusyMax Android** configuration without
the QA Gradle properties.

## Microsoft MSAL

Register a public/native Android application for personal and organizational
accounts as required by the product tenant policy. Configure:

- `microsoft.clientId`: the real public client ID;
- `microsoft.authorityTenant`: normally `common`, or the owner-approved tenant;
- `microsoft.signatureHash`: the Base64 certificate signature hash used by
  MSAL's signer-specific Android redirect.

The generated redirect is
`msauth://io.busystack.busymax/<URL-encoded-signature-hash>`. The generated MSAL
resource uses browser authorization and `MULTIPLE` account mode. Debug, local
release, and Play-installed certificates need their own registered redirect.
BusyMax binds each domain account to an MSAL native account ID and uses that
exact ID for silent foreground and WorkManager token requests.

## Other providers and Android permissions

Apple iCloud Calendar continues to require an app-specific password. Nextcloud
uses Login Flow v2 and stores the returned app password in secure storage.
WebCal is read-only. Target API 37 requires ACCESS_LOCAL_NETWORK for applicable
local-network traffic. Foreground Nextcloud/CalDAV and independent
Nextcloud/CardDAV contacts enrollment, reconnect and retry use the shared
contextual permission flow. Native ConnectivityManager/LinkProperties data
checks applicable interfaces and non-default IPv6 routes, with VPN/cellular
excluded. CGNAT 100.64.0.0/10 is included on applicable interfaces; an arbitrary
global IPv6 address is not assumed local. DNS/address hints are a fallback when
route evidence is unavailable. These checks do not scan the network.
Account **Sync** and **Sync all** also check this permission for existing local
CalDAV and Nextcloud accounts. If denied, the recovery dialog opens the app's
Android settings, where Nearby devices access can be allowed before retrying.
No account removal or reconnection is required. Background work never opens a
permission prompt. Contacts also check before request dispatch without showing
UI, so revocation between foreground preflight and connection preserves the
account, credentials, trust and cache. A denied account does not stop unrelated
permitted accounts. For a route not identifiable beforehand, contacts exposes
local-network recovery in its account actions; use Android app settings and
retry. DNS, TLS and ordinary connectivity errors retain their own classification.
See Android's [permission guidance](https://developer.android.com/privacy-and-security/local-network-permission)
and [network definition](https://developer.android.com/privacy-and-security/local-network-definition).
Notification permission is requested when creating reminders or from Settings;
exact-alarm access is requested from Settings. Exact access improves reminder
precision but is not required for synchronization or for inexact reminders.

Run on one explicitly selected device:

```sh
tool/android/run.sh --device DEVICE_ID
```

The same entrypoint is available as the checked-in **BusyMax Android** IDE run
configuration. Live-provider tests must use disposable QA accounts and the
certificate registration matching the installed build.

In Android Studio, select **BusyMax Android** in the run configuration dropdown.
Its Dart entrypoint is `lib/main_android.dart`. The auto-generated **main.dart**
configuration runs the Linux alias and must not be used for Android. An
existing IDE session may need the configuration selected again after an
external workspace-settings change.

For a direct Flutter launch, use:

```sh
flutter run -d DEVICE_ID -t lib/main_android.dart
```

A white screen with `MissingPluginException` for `yaru_window` and a stack frame
in `main_linux.dart` means the Linux entrypoint was launched on Android. Stop
that run and launch **BusyMax Android**; hot reload does not change entrypoints.

On a fresh checkout, the complete non-device verification command is:

```sh
export JAVA_HOME=/path/to/jdk-17
export ANDROID_SDK_ROOT=/path/to/android-sdk
tool/android/verify.sh
```

It enforces the lockfile, regenerates localization and Drift output, checks
generated consistency and formatting, runs analysis, platform boundaries, the
complete Flutter suite, native plugin unit tests, and Android lint.

Android 17/API 37 acceptance must include an upgrade that preserves an existing
local-server account and its queued edits. Deny Nearby devices access, then
verify account Sync and Sync all offer recovery without dispatching local-server
requests. Approve the next permission request and verify synchronization resumes
with the same account. Revoke access in Android settings, run background sync,
and verify the account and queued edits remain and no permission UI appears.
The next foreground account Sync must offer recovery again. Also verify that a
permanently denied request offers the working app-settings action and that
granting access there allows the next Sync to succeed. Repeat for CalDAV and
Nextcloud, independent Nextcloud contacts and independent CardDAV contacts.
Include first grant, denial, permanent denial, later grant, revocation between
preflight and dispatch, retained accounts after process restart, and background
work with a different permitted account. Use an actual routed LAN endpoint;
loopback/adb reverse alone does not qualify the local-network restriction.
API 37 acceptance remains a separate gate in the dated qualification record. Widget and plugin unit
tests do not qualify Android 17's native permission behavior.

## Linux-referenced Android rework

The current reference is the reachable Linux UI at
`3e27eca0578dd2c1c182b5346b8290eb90bc8ed6`, followed by the explicitly recorded
working-tree changes. The former implementation map described substitutions
such as a visible zoom slider, picker-only resizing, a separate All tasks entry
and an all-day overflow sheet. Those descriptions were not parity acceptance.

The concrete source/behavior mapping, exercised flows, runtime identity and
remaining acceptance work are maintained in
[Android Linux reference](android_linux_reference.md). The rework is incomplete;
provider capabilities and large regression totals alone do not qualify it.

For comparison captures and interaction checks, run
`integration_test/android_workspace_parity_test.dart` with
`--dart-define=BUSYMAX_PARITY_QA=true`. Android uses the existing isolated QA
application configuration and writes PNGs into its application-support `parity`
directory. Linux writes to `/tmp/busymax-parity-linux`, overridable with
`BUSYMAX_PARITY_OUTPUT`. `BUSYMAX_PARITY_ANDROID_UI=true` runs the Android widgets
on the Linux engine for additional layout inspection; those captures are **not**
Android device acceptance. The fixture uses an in-memory database, settings,
credentials and recovery records.

Device acceptance remains a separate requirement: all five views, editors,
source actions and settings must be exercised on Android in portrait, landscape,
a wider window, 200% text, RTL, light/dark and with the keyboard visible. Passing
widget tests or Linux-hosted Android captures does not complete that gate.

Run the native fixture and capture driver on a designated disposable emulator:

```sh
BUSYMAX_FLUTTER_EXECUTABLE=/path/to/flutter/bin/flutter \
ANDROID_SDK_ROOT=/path/to/android-sdk \
python3 tool/android/check_workspace_parity.py \
  --device emulator-5556 --output build/android-parity/android
```

The driver installs the isolated `io.busystack.busymax.caldavqa` package, drives
native keyboard and Back events, checks saving an event and a task, and captures
the five views at the existing small-phone, landscape, enlarged-text and tablet
sizes. Emulator display overrides are restored when it exits. Use `--phone`
with an explicitly selected USB device to run the interaction checks without
changing that device's display preferences. The regular BusyMax installation
and its data remain separate. The driver retains screenshots and `runtime.log`
in the requested output directory. These controlled checks do not send live
provider requests or qualify production OAuth registrations.

The 2026-11-15 runtime qualification used an authorized OnePlus A6003 (API 29)
and a disposable official API 35 emulator. The populated fixture passed on both;
the emulator also exercised native display sizes 360×800 at 100%, 412×915 at
130%, 915×412 at 130%, 1200×800 at 100%, 800×1280 at 200%, and 320×500 at 200%.
Each size covered all five views. The checks included previews, full editors,
native keyboard and Back, dirty-draft cancellation/discard, scrolling long task
notes in preview and editor, saving an event and a task, read-only inspection,
empty Agenda, sources, Settings, and Arabic/dark
appearance. Enlarged-text captures also include editors, preview, sources and
Schedule settings. The normal `main_android.dart` QA build was separately
installed and cold-launched on the phone; Week, the workspace menu, all six
Settings categories and native Back were exercised. Regular BusyMax data and
phone display preferences were preserved.

The real Linux application passed its five-view fixture run on an independent
X display, including native GTK header-icon initialization. Captures and logs
are retained under the ignored `build/android-parity/{android,phone,linux}`
directories. Production OAuth registrations, live-provider opt-in tests, and
API 37 native local-network permission/upgrade qualification remain separate
gates; the fixture and shared regression suite do not replace them.

Final automated qualification on 2026-11-15:

| Check | Result |
| --- | --- |
| Complete Flutter suite (`flutter test --no-pub --concurrency=4 --timeout=2m --reporter=expanded`) | 5,387 passed, 121 opt-in/fixture skips, 0 failures; 9m05s |
| Native Android plugin unit tests | 18 passed across 4 suites, 0 failures/errors/skips |
| Android lint | 0 errors, 9 existing warnings |
| Static analysis / formatting | No issues; 903 Dart files, 0 formatting changes |
| Generated output / platform boundaries / repository hygiene | Reproducible / valid / passed |
| Upstream integrity | 8 checked packages and 1,171 SDK files verified; Flutter 3.47.5 / Dart 3.13.4 |
| Native fixture runs | Phone, emulator and real Linux application passed; screenshots visually inspected |
| Release APK | Test-signed; signature, ZIP/native 16 KB alignment, manifest and notification drawable checks passed |

The usable isolated phone build is `build/android-parity/busymax-qa-debug.apk`.
The test-signed release APK is
`build/app/outputs/flutter-apk/app-release.apk`. Full logs, artifact hashes and
representative screenshot paths are recorded in
`build/android-parity/verification.json`. The additional AAB was built and its
native ELF alignment checked; bundletool configuration metadata was not
inspected because no local bundletool jar was configured. Windows regression
widgets and shared logic passed in the Flutter suite; a native Windows runtime
was not exercised on this Linux host. These are development/test artifacts,
without production OAuth registrations or production signing qualification.
