# Notification audit and acceptance record

Audit date: 2026-10-21 (America/Vancouver). Baseline: clean `fix/notifications`
at `4ffe86f0e02c62011b54924f607b4f3084c1cb44`. No applicable `AGENTS.md` was
present. Flutter 3.47.5 and its bundled Dart 3.13.4 were used with the repository
lockfile and shared dependency pins. SDK constraints, dependency versions and
other BusyStack applications were not changed. Native Android unit checks used
JDK 17; Android builds used the existing release/bootstrap scripts and API 37 /
Build Tools 37. See [the resulting policy](notifications.md) for delivery rules.

## Findings

| Area | Result and evidence |
| --- | --- |
| Missed reminders | Confirmed and fixed. Shared generation now persists relevance/expiry and consolidates overdue offsets per occurrence. Desktop validates before and after native delivery. Android retains relevant newly discovered past triggers, pending inexact alarms and a trigger crossed during registration. Controlled-clock schedule, scheduler and Android reconciliation tests cover restart, inactivity, quiet hours, disable/re-enable, dismissed native absence, supported alarm forms and explicit Snooze. |
| New task reminders | Confirmed and fixed. Invocation-time defaults are future, newly selected past minutes receive validation, and current-minute saves catch up. Existing/imported values survive unrelated edits. Editor draft and schedule regression tests cover due today, overdue/no due date, provider zones and crossing the trigger. |
| Privacy/category changes | Confirmed and fixed. Known native identities are withdrawn or silently updated, including delayed submissions and cleanup failures. Categories independently withdraw visible/pending posts. Delayed-backend and native Linux/Android checks cover privacy; returning to normal does not revive consumed posts. Native Linux testing also found and fixed cancellation through a different D-Bus sender. |
| Readiness | Confirmed and fixed. Android reports preference, OS permission, channels, precision and backend failure separately. Editors explain denial, a blocked reminder channel, or unavailable delivery status while preserving the saved data. A real DAV editor mutation regression covers granted app permission with ineffective delivery and retains sibling alarms. Notification settings and precision have separate recovery actions. Windows queries packaged notification permission where available; Linux states the limits of its API. Widget/backend tests and Android native denial/revocation/recovery checks cover these boundaries. |
| Windows activation | Confirmed and fixed. Account-specific sync/conflict routes pass bounded route-specific validation. Production service/backend payloads are fed into the production C++ validator, including body/Open and forwarded/cold models plus negative controls. The existing single action router was correct and remains intact. Actual packaged Windows process forwarding remains unvalidated on this Linux host. |
| Daily summaries | Confirmed and fixed. Optional, all eligible accounts, default 09:00 local with a time selector on every platform, durable once-per-date history and dated destinations independent of browsing filters. Count updates do not re-alert. DAV's existing real-deadline helper already excluded DTSTART fallback; that behavior is preserved and shared by the new query. Native Linux caught and verified a fix for a settings-write/submission race that otherwise withdrew a freshly posted summary. |
| Android channels | Confirmed and fixed. Timed reminders retain their existing channel; summaries get an independently controlled channel. Installed user choices are preserved. Native Kotlin tests cover both creation orders and migration restrictions; API 35 native channel blocking confirms independent delivery. |
| Operational alerts | Confirmed and fixed. Shared classification suppresses transport/timeouts/cooldowns. Durable per-account issue state records only successful submission, retries failed submission after one minute, and withdraws on recovery/removal. Explicit authorization replacement invalidates the old issue even before a successful sync; late old-generation errors and delayed sends are suppressed/withdrawn. Both cases were reproduced before the repair. Production coordinator/backend regressions cover two accounts, issue changes and deferred cleanup. Android native cold account-specific recovery navigation was exercised. Existing preflight offline suppression was already correct. |
| Conflicts | Confirmed and fixed. Shared unresolved-operation reconciliation covers Google/Microsoft blocked operations and DAV conflicts, quiet-hours deferral, deduplication, retry, resolution and account removal. Account-specific activation opens existing resolution/diagnostics UI. Mutation resolution rules are unchanged. |
| User text and timing | Confirmed and fixed. Ordinary content no longer uses diagnostic redaction. Absolute date/time with UTC offset, useful location and list/calendar context replace long descriptions. Tests cover Basic, Contact:, Location:, Summary:, markup characters, multiline and non-Latin text. Existing Linux markup-capability escaping was correct and remains intact. |
| Localization | Confirmed and fixed. Saved supported locale resolution and notification-string construction are shared by foreground, worker and terminated action contexts. Snooze labels state ten minutes. A German Snooze after process termination returned with German/private content on Android. Plural/RTL catalogs and locale changes have automated coverage. |
| Actions and lifecycle | Fixed and preserved. Conditional generation writes, persisted Snooze, source-ID replacement, cancellation retries and retired-runtime protection remain authoritative. Cold Android Open can reveal a consumed but still-valid source without resurrecting delivery. Dismiss changes notification state only. Native Linux and Android actions exercised actual production paths. |
| System time/background | Repaired floating/date-only recalculation before native rescheduling; fixed instants and Snooze deadlines remain UTC. Automated temporal/quiet-hours/recurrence coverage exercises the policy. Desktop UI explains process/tray/Quit limits. Exhaustive native DST/clock changes, overnight power restrictions and packaged launch-at-login/tray acceptance remain outstanding. |

## Automated checks

All commands ran from the repository root unless stated otherwise. Per-run logs,
native captures and synthetic profiles are under ignored
`build/notification-audit/`; they are not production assets or committed fixtures.

The full regression command `flutter test --concurrency=4` completed with **3,914
passed, 10 skipped and 3 failed**. Two contact lifecycle tests hit their existing
30-second timeouts. A new settings widget test had an ambiguous locator; its
locator was corrected. The full suite is not reported as green. Both complete
contact suites and the repaired notification suites subsequently passed together
at their original timeouts, serially: **313 passed**:

```sh
flutter test --concurrency=1 \
  test/features/notifications \
  test/app/notification_runtime_provider_test.dart \
  test/features/sync/sync_failure_notification_policy_test.dart \
  test/platform/android/android_notification_backend_test.dart \
  test/platform/android/android_notification_policy_test.dart \
  test/platform/android/android_notification_reconciliation_test.dart \
  test/platform/android/android_settings_sync_test.dart \
  test/platform/linux/linux_notification_backend_test.dart \
  test/platform/windows/windows_notification_backend_test.dart \
  test/platform/windows/windows_notification_id_store_test.dart \
  test/platform/windows/windows_notification_readiness_ui_test.dart \
  test/platform/windows/windows_notification_runtime_test.dart \
  test/contacts/contacts_enrollment_test.dart \
  test/contacts/parent_removal_lifecycle_test.dart
```

Additional completed checks:

* `flutter pub get --enforce-lockfile`: succeeded without lockfile changes.
* `flutter gen-l10n` and `dart run build_runner build --delete-conflicting-outputs`:
  succeeded; generated schema 21 and localization outputs are included.
* `flutter test test/platform/windows/windows_notification_runtime_test.dart test/ui/windows/windows_schedule_commands_test.dart test/features/notifications/due_today_notification_scheduler_test.dart`: 29 passed.
* `python3 -m unittest discover -s test/tool -p '*_test.py'`: 61 passed.
* `cmake --build build/notification-audit/native` followed by
  `ctest --test-dir build/notification-audit/native --output-on-failure`: 2/2 passed.
* From `android/`, `./gradlew --no-daemon :busymax_android_platform:testDebugUnitTest :app:lintDebug`
  with the configured JDK 17: build successful, 15 native tests passed and lint passed.
* `tool/android/build_release.sh --apk --test-signing --allow-unconfigured-providers`:
  release APK built. This is local test signing, not a distributable release.
* `flutter build linux --release -t lib/main_linux.dart`: release bundle built.
* `flutter analyze`: no issues found.
* `dart run tool/check_platform_boundaries.dart`: passed.
* `dart format --output=none --set-exit-if-changed .`: 924 files, zero changes.
* `git diff --check`: passed.

After the final authorization-generation repair,
`flutter test --concurrency=1 test/features/notifications test/app/notification_runtime_provider_test.dart test/platform/android/android_notification_reconciliation_test.dart test/platform/windows/windows_notification_runtime_test.dart`
passed **156 tests**, including both newly reproduced races. The release builds
and static analysis were repeated for that production change.

The final editor readiness and production-transport payload check,
`flutter test --concurrency=1 test/platform/android/android_adaptive_app_test.dart test/platform/android/android_notification_reconciliation_test.dart test/platform/android/android_settings_sync_test.dart test/platform/windows/windows_notification_backend_test.dart`,
passed **105 tests**. This includes saved reminder edits with blocked/unknown
delivery and account-specific sync/conflict activations generated by the actual
runtime service transport and validated by production C++. Android release and
static checks were repeated after the editor change; Linux's last production
change had already passed its release build.

## Native acceptance

All posts used production services/adapters with synthetic source data. The
Android driver uses a separate `io.busystack.busymax.notificationqa` package and
never reads or writes the regular BusyMax profile. Only its cloud transports are
disabled. No provider credentials are needed for this QA data.

**Linux, GNOME 46/X11:** Actual banners/history, faithful user text and timing,
body Open, ten-minute Snooze across restart, Dismiss without completing the task,
privacy while several posts were visible, restart cleanup and German/private
labels were exercised. The real Yaru task destination opened a native summary's
original due date despite an unrelated search; closing it restored the search.
No custom notification UI was used. Native cancellation's shared D-Bus sender
repair was confirmed in actual GNOME history and a real D-Bus server regression.
An additional native body click opened the exact synthetic event in the actual
Yaru source detail view, with matching date, location, calendar and reminder.
With background operation disabled, the native window Close action exited the
QA process. Close-to-tray and packaged launch-at-login still need their separate
native acceptance checks.

**Android API 35 emulator:** Fresh denial and later permission recovery, blocked
summary channel with timed reminders still working, exact-alarm revocation and
restoration, silent same-ID summary updates, privacy withdrawal, warm task Open,
cold event Open and cold account recovery navigation were exercised. With the app
process confirmed absent, native German Snooze persisted a new generation,
returned at its ten-minute deadline and retained localized private presentation.
Terminated-process Dismiss retained the source and did not raise the app. Native
summary activation opened the original dated results despite an unrelated active
search; Back restored that query and its ordinary results. Audio was disabled on the
emulator, so this environment establishes neither audible sound nor vibration.
The final recovery-button check opened `android.settings.APP_NOTIFICATION_SETTINGS`
and refreshed notification permission to allowed while exact alarms remained
unavailable. A real native conflict alert opened the affected Microsoft blocked
operation with its existing Retry/Discard controls; no competing edit was resolved.

**OnePlus 6, Android 10/API 29:** The isolated app was installed on the authorized
USB device. Real normal and private posts were inspected on its secure lock
screen. Private presentation contained no source title, location, timing or
account details. The user confirmed a heads-up banner and sound or vibration.
The device's secure lock screen prevented completing its process-terminated
action checks; those actions were exercised on API 35 instead. No lock, sound,
network, Do Not Disturb or clock settings were changed on this phone.
The isolated QA package was uninstalled after acceptance, canceling its synthetic
posts and alarms. The disposable emulator was stopped.

**Windows:** No Windows runtime was available. Portable production native schema
tests and Dart/backend forwarding integration passed, but they do not establish
actual Windows banners/history, packaged cold launch or secondary-process
forwarding. These remain explicit native acceptance gaps.

Other remaining native checks include installed Snap/MSIX/store identity,
screen-reader/keyboard inspection of OS-owned controls, exhaustive RTL/long-text
layout on each OS, overnight OEM power behavior, and system timezone/DST/clock
transitions. Credential-gated live provider tests were not enabled. No push,
publication or release is part of this work.
