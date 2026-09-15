# Android verification report

This report records what was actually exercised for the Android implementation
on September 14, 2026. `PASSED` means the named command or procedure completed
successfully, `FAILED` means it was exercised and failed, `BLOCKED` means a
specific external prerequisite was unavailable, and `NOT RUN` means an
appropriate runner or environment was not available. A skipped live-provider
test is never counted as a pass.

## Build identity and environment

| Item | Recorded value |
|---|---|
| Source baseline | `b0f816ca4687decd4b502d0f0fdf6ac518de40cc` |
| Reviewed Android foundation | The source baseline plus the uncommitted `BusyMax_Android_a8d0604_Review.md` corrections described here |
| Verification host | `skynet3`, Linux x86_64, Ubuntu kernel `7.0.0-31-generic` |
| Verification time | Current correction pass on `2026-09-14` (`America/Vancouver`) |
| Flutter / Dart | Flutter `3.47.2` (`d3b14c8769`), bundled Dart `3.13.2` |
| Java | Eclipse Temurin JDK `17.0.18+8` |
| Android toolchain | platform `37.0` revision 2, Build Tools `37.0.0`, Gradle `9.4.1`, AGP `9.2.0` |
| Kotlin configuration | built-in Kotlin enabled; plugin declaration `2.4.0`; `android.newDsl=false` for the documented Flutter 3.47.2 compatibility requirement |
| Application | `io.busystack.busymax`, beta `0.2.2+2`, min SDK 24, target/compile SDK 37 |
| Available Flutter devices | Linux desktop and Chrome only; no Android emulator or physical Android device |

## Automated and build evidence

| Status | Check | Command or procedure | Evidence |
|---|---|---|---|
| PASSED | Pinned SDK prerequisites | `tool/android/check_prerequisites.sh` with Temurin JDK 17 | Flutter 3.47.2, Dart 3.13.2, API 37 and Build Tools 37.x accepted |
| NOT RUN | Localization and Drift generation | `flutter gen-l10n`; bundled `dart run build_runner build --force-jit` | No localization or schema input changed in this correction pass. The earlier result is not relabeled as a current run. |
| PASSED | Repository-wide formatting | bundled `dart format --output=none --set-exit-if-changed .` | All 719 Dart files were already formatted; the check made no changes. |
| PASSED | Repository-wide static analysis | `flutter analyze` | `No issues found!` for the current correction working tree. |
| PASSED | Platform boundary enforcement | bundled `dart run tool/check_platform_boundaries.dart` | Current Android foreground/headless composition contains no prohibited desktop imports. |
| PASSED | Repository-wide unit and widget suite | `flutter test --concurrency=1 --reporter compact` | 2,271 tests passed and 10 explicitly environment-gated tests were skipped in the current correction working tree. The skipped live-integration cases are not counted as passes. |
| PASSED | Android platform test suite | `flutter test test/platform/android --concurrency=1` | 66 current Android unit/widget tests passed in one serialized run. This includes the scenario-specific rows below; it is not counted again as an additional 66 scenarios. |
| PASSED | Affected shared regression set | `flutter test` over calendar collection/repository, pending sync requester, Nextcloud scheduling service/policy, and feedback submission/presentation test files with `--concurrency=1` | 100 tests passed. These verify shared payload/projection/service behavior used by the new Android routes; they do not turn widget navigation into a live-provider round trip. |
| PASSED | Android adaptive widget matrix | `flutter test test/platform/android/android_adaptive_app_test.dart --concurrency=1` | 29 widget tests passed. The empty shell matrix covers the required sizes/themes/RTL. Populated flows explicitly select Day, Week, Month, and Year, exercise all-day/date-only overflow at compact and wide Week widths, submit and inspect an invitation response, and render Month/Year at 320x500 and 200% text. System Back is exercised independently for every named event/task text field. Stateful secure-storage tests round-trip changed event destinations, recurring scope, and advanced task recurrence. Dirty task save-and-move, cancel, and failure paths inspect real database/recovery state. Settings routes, Apple credential-prompt lifecycle, guest-availability error UI, Google calendar rename/color/delete sync requests, and feedback failure/retry identity are exercised. |
| PASSED | Android notification policy | `flutter test test/platform/android/android_notification_policy_test.dart --concurrency=1` | 8 helper/contract tests passed: stable IDs, quiet-hours eligibility, pending/displayed retention predicates, privacy/exact fingerprinting, explicit Open UI action, and payload parsing. |
| PASSED | Android notification reconciliation | `flutter test test/platform/android/android_notification_reconciliation_test.dart --concurrency=1` | 7 service tests passed against database rows and a stateful pending/active platform fake: displayed retention, stale generation cancellation, Dismiss, overdue inexact pending retention, Snooze, quiet-hours deferral, and overdue daily-summary privacy/precision replacement. |
| PASSED | Android authorization regression | `flutter test test/platform/android/android_authorization_broker_test.dart` | Missing native scopes are not promoted to grants, native interaction-required becomes the shared reconnect error, and non-revoking local Google removal clears its native binding |
| PASSED | Android attendee mutation regression | `flutter test test/platform/android/android_event_attendee_edit_test.dart` | Unchanged guest text preserves the original structured attendee objects and change flag; additions retain existing guest metadata |
| PASSED | Android contextual LAN regression | `flutter test test/platform/android/android_local_network_host_test.dart --concurrency=1` | 6 tests passed for local suffixes and literals plus injected DNS resolution of ordinary dotted names to private, public, mixed, and failed results. These are resolver/onboarding-policy tests, not an Android 17 socket-permission device test. |
| PASSED | Android month/year range regression | `flutter test test/platform/android/android_month_grid_range_test.dart --concurrency=1` | 4 tests passed for exact 42-day Sunday/Monday-first display-query parity, civil-date stepping across offset-changing dates, and Year query coverage of every miniature's adjacent-month cells. |
| PASSED | Android platform channel contract | `flutter test test/platform/android/android_platform_channel_test.dart` | Provider availability, account-specific silent Microsoft request, content-URI behavior, and explicit engine-owned gate release contract |
| PASSED | Android settings persistence | `flutter test test/platform/android/android_settings_persistence_test.dart` | Android view preference is independent and atomically persisted |
| PASSED | Native plugin unit tests | `JAVA_HOME=.../java/17.0.18-tem android/gradlew --project-dir android :busymax_android_platform:testDebugUnitTest --no-daemon --max-workers=1` | 3 native unit tests passed, including UI-required versus service/network/configuration MSAL classification and engine-owned lease release. This does not exercise a live MSAL account. |
| PASSED | Android lint | `JAVA_HOME=.../java/17.0.18-tem android/gradlew --project-dir android :app:lintDebug --no-daemon --max-workers=1` | Current correction tree completed successfully; [lint-results-debug.html](../build/app/reports/lint-results-debug.html). Dependency/build deprecation warnings remain non-fatal and are not reported as app lint findings. |
| PASSED | Current release packaging | Explicit Temurin 17 path and one-worker `tool/android/build_release.sh --all --test-signing --allow-unconfigured-providers` | Current correction tree produced the APK and AAB below. Both use the local debug identity and unconfigured-provider allowance, so this is engineering packaging evidence, not production readiness. |
| PASSED | Current artifact inspection | Temurin 17 `tool/android/inspect_artifacts.sh` | Current APK/AAB hashes and ABIs recorded below; APK v2 signature, manifest/SDK/permission values, and packaged ELF 16 KB LOAD-segment compatibility passed. Bundletool metadata remains the separate blocked row. |
| BLOCKED | End-to-end clean-snapshot wrapper run | Export JDK 17 and `ANDROID_SDK_ROOT`, then run `tool/android/verify.sh` in a clean source snapshot | The earlier clean snapshot entered deterministic generation but the host terminated that duplicate heavy process with signal 9. No current clean-snapshot wrapper pass is claimed; the successful current repository-wide suite and serialized component checks are recorded separately above. |
| BLOCKED | Bundletool AAB configuration dump | `tool/android/inspect_artifacts.sh` | `BUNDLETOOL_JAR` was not installed. Supply a reviewed official bundletool jar and rerun. AAB ZIP contents and every packaged ELF were still inspected directly. |
| BLOCKED | Android integration test | `flutter test integration_test/android_platform_smoke_test.dart -d DEVICE_ID` | No Android device was attached. Supply an API 24/36/37 emulator or phone. |
| NOT RUN | Windows workflow | Existing Windows CI on an appropriate Windows runner | No Windows runner was available from this Linux workspace; no Windows result is claimed. |

Android composition has an explicit `lib/main_android.dart`; the Linux and
Windows entrypoints remain separate.

## Current test-signed release artifact record

The following artifacts were produced from the current correction working
tree. They are release-mode artifacts deliberately signed with the local
Android debug identity and allow unconfigured provider registrations. They are
suitable for engineering inspection only and must not be distributed or
uploaded.

| Artifact | Size | SHA-256 |
|---|---:|---|
| `build/app/outputs/flutter-apk/app-release.apk` | 86,948,944 bytes | `9e7a0ee03242e5d206e3c5df724b4bfcf999342aa15e3853275c72e5558545f5` |
| `build/app/outputs/bundle/release/app-release.aab` | 82,776,685 bytes | `e48f2e64db3bb0186fb898ae26a36e40746efe9cc1e2645a26a9b49ae577848a` |

Inspection found `arm64-v8a`, `armeabi-v7a`, and `x86_64`, with Flutter,
application, Dart JNI, and SQLite native libraries in each ABI. Every packaged
ELF LOAD segment in the APK and AAB passed the 16 KB alignment check, and the
APK passed 16 KB ZIP alignment. This is binary inspection, not a substitute
for the blocked 16 KB system-image launch.

The APK uses signature scheme v2. Its test signer is
`C=US, O=Android, CN=Android Debug`, SHA-256
`7E:E9:78:47:B9:60:7F:3B:84:51:69:F4:C3:92:BA:EE:7F:8E:C2:C5:2C:AC:33:FE:32:7C:D1:A0:0E:94:9B:68`.
Manifest inspection confirmed package `io.busystack.busymax`, version name
`0.2.2`, version code `2`, minimum SDK 24 and target SDK 37. The merged release
permissions are Internet, network state, notifications, exact alarms, boot,
wake lock, vibration, foreground service/short-service, Android 17 local
network, and Android's generated non-exported dynamic-receiver permission. It
contains no contacts, location, device-calendar, SMS, NFC, broad storage,
package-enumeration, or full-screen-alarm permission.

## Required functional matrix

The automated rows below verify repository logic, persistence, presentation,
and platform contracts with deterministic fixtures. The corresponding real-OS
or live-service row remains blocked where this host lacks a device, disposable
provider account, or owner registration.

| Status | Area | Result and evidence or exact unblock requirement |
|---|---|---|
| PASSED | Bootstrap and navigation — automated | Empty/populated/error/offline repository states, adaptive navigation, selected dates/filters, and cold/warm activation routing are covered by the full suite and Android widget/channel tests. |
| BLOCKED | Bootstrap and navigation — installed app | Fresh/returning install, process restoration, and cold/warm file/notification launches require an Android device and installed APK. |
| PASSED | Google — implementation/contract | Native `AuthorizationClient`, explicit selection, exact BusyMax/native binding, provider-reported grant persistence, required-scope validation, reconnect error mapping, local binding removal, Play-services availability, Calendar/Tasks repository reuse, and no Android desktop OAuth imports are implemented and contract-tested. |
| BLOCKED | Google — live | Two disposable Google accounts, enabled Calendar/Tasks APIs, and Android OAuth registrations for the debug, local-release and Play app-signing certificate fingerprints are required to exercise consent/cancel/deny/expiry/reconnect, real data, removal, and foreground/headless silent acquisition. |
| PASSED | Microsoft — implementation/contract | MSAL multiple-account browser flow, exact native-account binding, provider-reported grant persistence, account-specific silent acquisition, domain reconnect mapping, independent reminder date/time editing, and removal isolation are implemented. Native unit tests distinguish interaction-required from service/network/configuration failures; live account recovery is not implied. |
| BLOCKED | Microsoft — live | A real public client ID/tenant, signer-specific debug/local/Play redirects, disposable personal and organizational accounts, and an Android device are required for consent/browser return/silent worker/removal tests. |
| PASSED | Nextcloud — automated | Existing shared tests cover DAV engines, Login Flow v2 state, capabilities, pending operations, conflicts, and collection administration. Android source exposes capability-gated sharing/publishing/trash/restore, scheduling inbox, guest availability, invitation reply, advanced VTODO/hierarchy, and export routes. Current Android widget coverage verifies route presence and error-safe composition; it does not claim a live Nextcloud round trip. |
| BLOCKED | Nextcloud — live | A disposable public-HTTPS server account plus an owner-configured LAN endpoint on an Android 17 device are required to verify polling/resume, app-password storage, real calendars/tasks/sharing/publishing/trash/admin and denied-LAN behavior. |
| PASSED | Apple and WebCal — automated | Calendar-only/read-only capability enforcement, credential separation, subscription refresh state and meaningful account failure state use the existing tested repositories and Android mobile UI. |
| BLOCKED | Apple and WebCal — live | Disposable iCloud credentials with an app-specific password and disposable WebCal endpoints are required to verify revocation, refresh, and private embedded credentials against real services. |
| PASSED | Calendar and tasks — automated | Virtual Agenda, time-axis Day/Week with bounded accessible all-day overflow, scrollable civil-date Month with selected-day agenda, and Year miniatures are implemented. Current populated Android fixtures verify overnight intersection, source/list hiding, Week selection, invitation controls, all-day overflow, and short/large-text Month/Year. Editor tests cover read-only controls, account-qualified destinations, every named text field's system-Back guard, versioned recovery identity/recurrence/scope, and dirty task moves. Shared provider payload tests remain a separate evidence layer. |
| BLOCKED | Calendar and tasks — service round trips | Named destructive workflows for Google, Microsoft, Nextcloud, Apple and WebCal require provider registrations and dedicated QA collections. No owner's real collection was modified. |
| PASSED | Offline and conflicts — automated | Cached browsing, supported queued mutations, replay/backoff, ETags, tombstones, preserved ICS properties, interrupted/ambiguous creates and serialized UI/worker account access are covered by the shared suite and account gate. |
| BLOCKED | Offline and conflicts — real network | Provider-side state after a dropped create response and reconnect must be observed using disposable remote collections and controlled networking on an Android device. |
| PASSED | Database and preferences — automated | Schema migration through version 18, foreground/background visibility, atomic settings writes, account removal, engine-owned coordination release and account resurrection protections are covered by database, settings, sync and native gate tests. |
| BLOCKED | Database and preferences — OS interruption | Kill-during-write, upgrade, and account removal while a real WorkManager job owns the native process require an installed app and device instrumentation. |
| PASSED | Notifications — automated | Durable mappings and stateful reconciliation tests distinguish pending, displayed, dismissed, and stale-generation notifications. They cover quiet-hours deferral, overdue inexact retention, Snooze/Dismiss, explicit Open UI behavior, and overdue daily-summary privacy/precision replacement. Other shared tests cover horizon/cap and mutation-driven rebuilds. Platform delivery, permission recovery, and refill lifecycle remain device rows; future scheduling is not labeled delivery. |
| BLOCKED | Notifications — delivered behavior | A physical phone and signed installed build are required for screen-off timing, process death, permission/channel denial/revocation, reboot, package upgrade, battery idle, exact/inexact observation and cold/warm actions. |
| PASSED | Time and recurrence — automated | Shared timezone, DST gap/overlap, all-day/date-only/floating fields, recurrence and exception tests pass; Android system timezone/12–24-hour channel updates feed the app scope. |
| BLOCKED | Time and recurrence — system changes | A device is required to change clock/timezone/locale/12–24-hour settings and verify alarm rescheduling across provider/device timezone differences. |
| PASSED | Files and links — automated | ICS preview-before-import, no silent mutation, bounded and sanitized content-URI reads, off-main-thread content-provider I/O, SAF create/tree operations, malformed/oversized/cancel/duplicate activation handling, geo/browser fallback and missing-handler feedback are implemented and contract-tested. |
| BLOCKED | Files and links — document providers | A device with at least two document providers and maps/browser handlers is required for persisted/revoked grants, picker cancellation, native collection export, and cold-start share/open behavior. |
| PASSED | Security and release — source/artifact | Secret-free public examples, credential store separation, private notification payload design, backup exclusions, release manifest, R8, exact permissions, v2 test signature, and APK/AAB 16 KB binary inspection passed. |
| BLOCKED | Security and release — production | Owner keystore/CI secret configuration, Play enrollment/app-signing identity, provider console registration, fresh install/upgrade, 16 KB system-image launch, and production-signed inspection are required. |

## Device, lifecycle, visual, and accessibility matrix

| Status | Check | Evidence or unblock requirement |
|---|---|---|
| BLOCKED | API 24 device | No API 24 emulator/device was available. Start one with `adb` visibility and run `tool/android/run.sh --device DEVICE_ID` plus the integration and lifecycle procedures. |
| BLOCKED | API 36 device | No API 36 emulator/device was available. Required for the declared-range permission and lifecycle boundary. |
| BLOCKED | API 37 Google-services image | Required for Android 17 LAN permission and Google integration; no image/device was available. |
| BLOCKED | API 37 AOSP image | Required to verify Google-unavailable while Microsoft/DAV/WebCal remain usable; no image/device was available. |
| BLOCKED | 16 KB system image | Native binaries passed static inspection, but actual launch/runtime requires a configured 16 KB Android image. |
| BLOCKED | Physical phone | Authentication, signed-release reminder delivery, screen-off/battery-idle timing and cold notification activation require a physical phone. |
| BLOCKED | Rotation/split screen/background/foreground | Widget constraints passed, but the real Activity lifecycle needs an Android device. |
| BLOCKED | Ordinary process death/reboot | WorkManager, alarm restoration and database invalidation must be observed after real process removal and reboot. |
| BLOCKED | Force-stop | A device is required. Expected behavior is explicitly limited: Android does not guarantee work or alarms after user force-stop until the app is started again. |
| PASSED | Logical viewport rendering | The empty-shell matrix covers required logical sizes, themes, scales, RTL, and every primary destination. The populated matrix separately covers Day/Week data and short 320x500/200% Month/Year without framework exceptions. This is logical widget rendering, not a device screenshot. |
| PASSED | Automated accessibility | Widget tests verify labelled navigation and accessible all-day overflow, and exercise large text without clamping. Touch-target and color/contrast statements remain source/widget checks rather than TalkBack or physical-device certification. |
| BLOCKED | Actual Android screenshots | No Android device existed, so no device screenshots were produced. Linux screenshots are intentionally not presented as Android evidence. Required scenes are mixed schedule, selected-day month agenda, timed overlaps, tasks with undated/completed items, keyboard-visible event editor, account selection, settings, and loading/error/offline states using QA data. |
| BLOCKED | TalkBack/traversal/contrast | Requires a device or emulator with Android accessibility services and manual observation at all named screens. |
| BLOCKED | Attached keyboard/touch alternatives/predictive Back | Requires an Android Activity and input devices; verify draft preservation and route-first Back behavior. |
| BLOCKED | Profile/release performance | Requires a named phone with populated QA data. Record cold/warm startup, frame timings, account-switch time, list lengths and acceptance thresholds rather than inventing numbers. |

## Owner/external completion checklist

These items cannot be safely fabricated or performed without owner-controlled
inputs. They are deployment verification blockers, not unfinished source
implementation:

1. Copy `android/busymax.android.properties.example` to the ignored local file,
   enter the real Microsoft public client/authority/signature hash and public
   product links, and register Google/MSAL for each actual signing context.
2. Provide owner-controlled production signing through ignored
   `android/key.properties` or protected CI secrets. Rebuild without
   `--test-signing`/`--allow-unconfigured-providers`, then record the new
   fingerprints and artifact hashes.
3. Supply disposable provider accounts and dedicated QA collections; execute
   every live-provider and destructive matrix row without touching production
   data.
4. Run the API 24, 36, API 37 GMS/AOSP, 16 KB image and physical-phone matrices,
   including process death, reboot, notification timing, installation and
   upgrade. Capture the required real-screen evidence.
5. Run the preserved Windows workflow on a Windows runner, and use a reviewed
   local `BUNDLETOOL_JAR` for the remaining AAB configuration inspection.
6. Complete Play Console signing, policy disclosures and publication only with
   the owner's explicit authorization. Internal test readiness is not
   authorization to publish.

Reproducible configuration, run, build, install-oriented launch, signing and
inspection commands are documented in [android_setup.md](android_setup.md) and
[android_release.md](android_release.md). Provider behavior and limitations are
enumerated in [android_provider_parity.md](android_provider_parity.md).
