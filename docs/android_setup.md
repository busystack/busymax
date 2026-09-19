# Android setup and provider registration

BusyMax Android is a beta application with package ID
`io.busystack.busymax`, version `0.2.2+2`, minimum API 24, and compile/target
API 37. The supported toolchain is Flutter 3.47.4, its bundled Dart 3.13.3,
JDK 17, Android platform 37, and Build Tools 37.x.

The resolved Android build uses Gradle 9.4.1 and Android Gradle Plugin 9.2.0.
Built-in Kotlin is enabled; the Kotlin plugin declaration is 2.4.0 so Flutter's
toolchain validation sees the supported language level. Flutter 3.47.4's own
Gradle integration still casts the Android application extension to the legacy
type, so this pinned project retains `android.newDsl=false`. Enabling the new
DSL was exercised and reproducibly fails in Flutter's Gradle plugin with an
`ApplicationExtensionImpl`/`AbstractAppExtension` class cast before the app is
configured. This is a narrow pinned-toolchain compatibility setting, not a
blanket AGP 9 restriction.

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
signing. Put their SHA-256 fingerprints in the local configuration as an owner
record; Gradle does not send these values anywhere. Google authorization uses
the on-device `AuthorizationClient` with explicit account selection. The
desktop client ID and desktop client secret are neither required nor embedded
on Android. An AOSP device without Google Play services intentionally leaves
only Google unavailable; Microsoft, Apple, Nextcloud, and WebCal remain usable.

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
WebCal is read-only. On Android 17, a local Nextcloud hostname causes a
contextual local-network permission request; a public HTTPS server does not.
Notification and exact-alarm permissions are requested only from the relevant
Settings controls. Exact access improves reminder precision but is not required
for synchronization or for inexact reminders.

Run on one explicitly selected device:

```sh
tool/android/run.sh --device DEVICE_ID
```

The same entrypoint is available as the checked-in **BusyMax Android** IDE run
configuration. Live-provider tests must use disposable QA accounts and the
certificate registration matching the installed build.

On a fresh checkout, the complete non-device verification command is:

```sh
export JAVA_HOME=/path/to/jdk-17
export ANDROID_SDK_ROOT=/path/to/android-sdk
tool/android/verify.sh
```

It enforces the lockfile, regenerates localization and Drift output, checks
generated consistency and formatting, runs analysis, platform boundaries, the
complete Flutter suite, native plugin unit tests, and Android lint.
