# Independent notification follow-up repair

Base: clean `fix/notifications` at `01316eb602a9c888c6ef6290b8491a36ad3f4c9a`.
This record concerns F1–F7 from the independent repair instruction. It does not
adopt the earlier audit's test counts or native claims. No applicable AGENTS.md
was present. Flutter 3.47.5 / Dart 3.13.4, the lockfile, shared package pins and
schema 21 are unchanged. Android native builds use JDK 17 and API/Build Tools 37.

## Finding ledger

| Finding | Reproduction and cause | Repair and focused evidence |
| --- | --- | --- |
| F1: stale Android policy | Confirmed. Independent provider containers and file settings reproduce restoration of detailed/enabled pending requests, locale and quiet-hour rollback, including an awaited native registration. A worker's settings closure stayed cached. | `AndroidSettingsStore` serializes durable reads/mutation rebasing; every production runtime and terminated action injects it. `AndroidNotificationService` reads policy inside the shared gate and checks it before/after native work, retaining cleanup identity on failure. Data-change/resume refreshes UI state. Two SQLite connections, independent settings containers, delayed registration and a failed first cancellation exercise the boundary. An unrelated stale preference save cannot restore old policy. An additional obsolete delayed-registration expectation was reproduced and corrected: a known pending overdue inexact alarm receives a silent private replacement while remaining unsubmitted. |
| F2: duplicate operational delivery / orphan ID | Confirmed against the base commit with a deterministic pause after the second null-ID lookup. Two posts used IDs 411909534 and 411909535 for the same issue; durable state retained only the latter. | The existing engine-owned notification gate now covers coordinator eligibility, allocation, native submission and persistence. Native allocation is transactional; reminders include operational IDs in their used namespace. Concurrent scans/reports, the paused lookup, namespace collision and subsequent recovery assert one durable identity and complete removal. Interrupted submission persistence observes an active native ID without another Show. |
| F3: Windows existing-task editor | Confirmed against the base dialog: due-today/overdue defaults were 23:45 on the previous day; undated defaults were already past; a changed past reminder saved without feedback. | The actual existing-task Fluent dialog uses invocation-time shared defaults and provider-zone validation before mutation. DAV absolute pickers validate changed past minutes, preserve sibling alarms and convert the default to the picker's actual local instant. Widget tests cover due today at 14:00, overdue/undated, a disabled saved historical value, provider zone, current minute, crossing the selected trigger, DAV Add/edit and unchanged historical data. |
| F4: source toggles replay sent alarms | Confirmed through both actual repository toggle methods: sent-only schedule rows disappeared; re-enable created a new unsent generation. Dismissed, expired and future-unsent controls were already correct. | Retain consumed/Snooze, registered and in-flight identity through collection/account ineligibility and withdraw native artifacts using read-only source eligibility. Physical Android acceptance exposed a second case: a post could be visible before sent history was observed; rebuilding on list disable deleted it. Separate calendar/list regressions now preserve that registration for native observation before withdrawal; a delayed desktop Show also records consumed history before cancellation. Tests reopen the SQLite file between toggles, cover sent/dismissed/expired/future/Snooze and a genuinely changed future trigger. Completing/canceling a task also retains consumed identity; old row-deletion expectations were corrected while native withdrawal remains asserted. Repository/replayer tests cover list-ID replacement, offline list deletion, calendar disablement, DAV cancellation and a genuinely changed future occurrence after reconnect. |
| F5: Linux dated-summary controls | Confirmed through the production router/workspace: ordinary search, date/view/sidebar controls remained active over a fixed due-date query. | A dated summary uses the existing GTK header and focused agenda, with irrelevant controls and shortcuts unavailable. Close/Escape restores the same underlying workspace. The widget regression opens an old dated summary across two accounts over a live search, rejects view/search/create shortcuts, opens/edits/completes tasks and restores query, mode and date. |
| F6: obsolete cleanup deletes replacement | Confirmed in both deterministic cancellation-barrier cases: authorization replacement and same-authorization recovery/new failure deleted the new issue. | Cleanup update/delete predicates include revision and evaluated lifecycle. Changed revisions atomically reset submission/retry state while retaining native cleanup identity. The shared Android gate orders old cancellation before new posting. Both replacement regressions preserve and submit the new issue once. |
| F7: timezone/Snooze and quiet release | Confirmed with actual floating temporal projection: Berlin-to-London reprojection moved the source later than a fixed Snooze, and desktop due-time selection skipped the Snooze. Persisted local quiet-hour releases also survived zone changes. | Snooze is the UTC delivery baseline; local deferral is applied separately. The bootstrap zone/offset detector invalidates both memory and persisted deferrals before lifecycle-preserving rebuilding. Controlled process-zone tests exercise floating reprojection, persisted release after restart, moving out of/into quiet hours and unchanged fixed Snooze instants. |

## Production and regression boundaries

- F1/F2: `android_background.dart`, `android_notifications.dart`,
  `android_settings_store.dart`, `android_notification_gate.dart`,
  `android_app.dart`, `app_settings.dart` and
  `operational_notification_coordinator.dart`. The cross-engine regressions in
  `test/platform/android/android_notification_reconciliation_test.dart` use
  independent containers, settings documents and SQLite connections, with
  deterministic native-entry/queue barriers. Native ID and cleanup assertions
  accompany logical deduplication assertions.
- F3: `windows_task_details_dialog.dart` and the actual-dialog regressions in
  `test/platform/windows/windows_existing_task_reminders_test.dart`.
- F4/F6/F7: schedule service, scheduler, coordinator and bootstrap; regressions
  in `notification_policy_regression_test.dart`, schedule-service tests and
  the actual calendar/list/replay/DAV repository suites. F7 uses actual temporal
  projection with isolated controllable process zones, including restart.
- F5: `schedule_workspace.dart` and
  `test/features/schedule/presentation/notification_summary_workspace_test.dart`,
  using the production Linux router and workspace rather than a query helper.
- `tool/android_notification_acceptance.dart` adds an isolated QA WorkManager
  barrier and real repository toggles. It refuses the regular app package and
  disables only synthetic cloud transport. Native delivery/actions remain real.

## Executed verification

These results were executed for this repair. Counts overlap and are not added
together. Commands use the pinned Flutter/Dart executables and JDK 17. Logs,
JSON receipts, native database captures and screenshots are kept locally under
ignored `build/notification-repair/`; earlier `notification-audit/` results are
not adopted as new evidence.

| Command / gate | Result |
| --- | --- |
| `python3 tool/checkout_shared_dependencies.py`; `flutter pub get --enforce-lockfile` | Passed; sibling revisions and dependency pins preserved. |
| `flutter gen-l10n`; `dart run build_runner build --delete-conflicting-outputs --force-jit`; `dart run tool/check_generated_sources.dart verify build/notification-repair/generated-before.json` | Passed; generated localization/database sources reproducible, no generated diff. The pinned builder reports the removed delete-conflicting-outputs option as ignored. |
| `dart format --output=none --set-exit-if-changed .` | Passed, 930 files, no changes. |
| `flutter analyze` | Passed, no issues. |
| `dart run tool/check_platform_boundaries.dart` | Passed. |
| `flutter test --concurrency=4 --reporter=expanded` | **3,970 passed, 10 skipped, 0 failed**, complete final run. Skips remain credential-gated live-provider checks. |
| Affected repository/replay/DAV/UI-audit/Android reconciliation batch, listed below | 294 passed. |
| Broad focused notification/runtime/settings/platform/navigation run | Initially 509 passed / 7 failed: Android UI fixtures supplied initial preferences but an empty authoritative store. Fixtures now seed their durable settings; the complete affected Android app file reran with 51 passes. The final full run includes these tests. |
| First complete run: `flutter test --concurrency=1 --reporter=expanded` | 3,964 passed, 10 skipped, 6 failed. Five assertions expected consumed/inactive schedule rows to disappear; the sixth matched the former literal header expression. Strengthened lifecycle/eligibility/withdrawal assertions and the existing one-toolbar architecture check replace those expectations. This failed run is not relabeled as passing. |
| First affected-suite rerun | Two fixture imports conflicted on Drift/matcher `isNull`, and a polling-based native-entry wait timed out. Imports were disambiguated and polling replaced with native-entry Completers. The whole batch then passed 294 tests; final full run also passed. |
| `python3 -m unittest discover -s test/tool -p '*_test.py'` | 61 passed. |
| Portable C++ activation and short-time-pattern tests | Both built and executed successfully; commands below. Windows backend tests also generate real production payloads and invoke the production native validator. |
| `android/gradlew --project-dir android :busymax_android_platform:testDebugUnitTest --rerun-tasks` | Passed, 15 native unit tests (9 plugin, 3 channels, 3 registration); tasks actually reran. |
| QA `:app:assembleDebug :app:lintDebug`, targeting `tool/android_notification_acceptance.dart` through an isolated application-ID overlay | Passed for final code; regular BusyMax identity/profile untouched. |
| `flutter build linux --release` | Passed. Full Yaru and timing QA Linux builds also passed. |
| `bash tool/android/build_release.sh --all --test-signing --allow-unconfigured-providers` | Passed, APK and AAB. Artifacts are explicitly **test-signed with the local debug identity**; no release signing, publishing or installation over regular BusyMax. |
| `bash tool/release/check_linux_native.sh` | Original command stopped because `xvfb-run` is unavailable. A local copy with only that wrapper removed ran the same native/GTK checks successfully on the existing GNOME/X11 display. This is reported separately from the original gate. |

The affected batch command was:

```sh
flutter test --concurrency=4 --reporter=expanded \
  test/features/sync/pending_ops_replayer_test.dart \
  test/features/task_lists/data/task_lists_repository_test.dart \
  test/features/calendar/data/calendar_repository_test.dart \
  test/dav/storage/dav_object_repository_test.dart \
  test/dav/sync/dav_account_sync_engine_test.dart \
  test/app/native_ui_audit_test.dart \
  test/platform/android/android_notification_reconciliation_test.dart
```

Portable native commands:

```sh
c++ -std=c++17 -Wall -Wextra -Werror \
  windows/runner/notification_activation.cpp \
  windows/runner/tests/notification_activation_test.cpp \
  -o build/notification-repair/notification_activation_test
build/notification-repair/notification_activation_test
c++ -std=c++17 -Wall -Wextra -Werror \
  windows/runner/tests/short_time_pattern_test.cpp \
  -o build/notification-repair/short_time_pattern_test
build/notification-repair/short_time_pattern_test
```

## Native acceptance actually exercised

All data was synthetic and isolated. Native posts were generated through BusyMax
services/adapters, not custom notification mockups. Database rows and native
pending requests were inspected separately from visible presentation.

### Linux: GNOME 46 / X11, unpackaged QA builds

- Actual Yaru app: a real GNOME summary body click opened its original
  `2026-06-08` destination across two accounts. Search/date/view/create controls
  were absent and corresponding keyboard commands ineffective. Task details and
  completion worked; Close restored the ordinary `ordinary` search, month view
  and `/schedule` route. Captures include `linux-summary-destination.png`,
  `linux-summary-task-popover.png`, `linux-summary-completed.png` and
  `linux-summary-restored-settled.png`.
- Actual calendar repository toggle in the final full Yaru QA build: sent
  reminder -> disable withdrew the native post -> enable retained the same
  consumed generation and did not post again. Receipt:
  `linux-calendar-toggle-result.json`.
- Real native Snooze/Dismiss actions on a floating DAV event: Berlin-to-London
  reprojection moved the source by an hour; the Snooze deadline stayed fixed and
  a native reminder returned before the moved source trigger. Dismiss left the
  source neither canceled nor deleted. A controlled app-clock UTC-to-Moscow
  change invalidated a persisted quiet release and posted immediately outside
  quiet hours. Private withdrew two visible detailed event/task posts. Receipt:
  `linux-timing-result.json`; capture `linux-snooze-returned.png`.
- These timing checks changed the QA process's zone and controlled application
  clock, not the host's system clock or timezone. They do not establish exhaustive
  OS clock/DST integration. Sound was not independently measured on Linux.

### Android: OnePlus 6, Android 10 / API 29, isolated debug APK

- Real foreground plus WorkManager engine: worker cached Normal; foreground
  persisted Private and replaced two real future pending requests; the resumed
  worker reported authoritative Private and retained neutral native text.
  A second run disabled event/task categories before release; no native pending
  requests returned. Receipts: `phone-worker-private-done.json` and
  `phone-worker-disabled-done.json`.
- A real visible task post with unobserved sent history exposed F4's additional
  rebuild race. After repair, list disable observed submission before withdrawal;
  enable retained generation `4c42951f-7a4e-4796-8983-5f6cf1711460` without replay.
  Receipt: `phone-final-list-toggle-result.json`.
- The user confirmed a banner and sound or vibration for the private German QA
  reminder in this repair session. This is a user observation, not an inference
  from native submission. Private native title was `Erinnerungen`, body null.
- With the QA process verified absent, the real German Snooze action persisted
  ten minutes ahead in UTC. Native pending content/actions stayed private and
  German; the launcher remained in front. Receipt:
  `phone-terminated-snooze-result.json`.
- Real terminated-process Dismiss persisted dismissal, removed the native post
  and left the task unchanged. Receipt: `phone-terminated-dismiss-result.json`.
  Final focus inspection was interrupted by a host ADB transport failure, so
  physical-phone Dismiss focus behavior is not claimed. The emulator's equivalent
  focus check passed.
- This physical APK includes the F1–F7 repairs. The subsequent overdue-pending
  privacy refinement was verified by the 45-test Android reconciliation suite;
  the rebuilt final APK then repeated the native policy barrier on the emulator.

### Android: API 35 emulator, isolated debug APK

- Real contextual permission denial preserved the saved reminder and displayed
  blocked readiness. The app's existing System action opened package notification
  settings; returning after recovery refreshed readiness and registered the
  saved reminder. Exact alarms were separately unavailable, then enabled through
  their own OS special-access screen.
- Installed reminder channel importance was 4, summary importance 3. Blocking
  only summaries yielded global permission true, reminder channel true, summary
  channel false, exact alarms true. Reconciliation preserved that user choice.
- Real German shade/actions, warm explicit Open and cold body-click Open reached
  the exact task editor. Terminated Snooze/Dismiss persisted the intended state,
  left the source task unchanged and kept the launcher in front.
- Real foreground plus worker reconciliation of one actionable account issue
  retained one durable/native ID (602028792) and one native post. Repeated scans
  stayed deduplicated; recovery left no issue row or native post. Receipt:
  `emulator-operational-result.json`. Deterministic delayed-Show/ID-allocation
  races remain covered by the independent-connection automated tests.
- The final rebuilt APK repeated the real worker barrier with two actual future
  native requests: an older cached-Normal runtime retained Private presentation;
  disabling both categories before the next worker resumed left no registrations.
  Receipts: `emulator-final-worker-private.json` and
  `emulator-final-worker-disabled.json`.
- In the final APK, a real detailed visible reminder was withdrawn on Private.
  Returning to Normal with notifications/channel/exact-alarm readiness all true
  did not revive it; the source task stayed unchanged. Receipt:
  `emulator-final-visible-private-result.json`.
- Emulator audio was disabled; it cannot validate sound/vibration. No physical
  lock-screen accessibility or exhaustive RTL inspection is claimed.

## Remaining environment checks

Windows was unavailable: actual existing-task Fluent widget tests and generated
payload/native C++ validation passed on Linux, but packaged Windows editor,
secondary-process forwarding, cold activation and notification history still
require Windows. Snap/store integration, overnight OEM power behavior, exhaustive
OS clock/DST changes and screen-reader/complete RTL acceptance remain unvalidated.
The host AT-SPI bus was unavailable during Linux acceptance.

During final physical cleanup, Android Studio restarted ADB and the phone's USB
debugging transport subsequently timed out. Linux continued to enumerate the
OnePlus; this was not evidence of a cable disconnect. Host ADB restart, both
supported transport backends and a reset of only that phone's USB connection were
attempted. The user restarted USB debugging, restoring the connection. Only
`io.busystack.busymax.notificationqa` and its owned temporary UI dump were
removed from the phone; no QA native post remained. The regular package
installation state stayed unchanged. Receipt: `phone-cleanup-result.json`.
The isolated emulator QA package was also removed after checking that no native
post or pending alarm remained (`emulator-cleanup-result.json`). Completed Linux
QA processes were closed after their native identity maps became empty.
The owned read-only emulator was stopped, and the host's default native ADB
backend was restored with the physical phone connected. Receipts:
`emulator-stop-result.json` and `host-cleanup-result.json`.

## Platform contracts checked

The installed plugin source was inspected at flutter_local_notifications 22.3.0,
including native pending-request persistence and `getActiveNotifications` (active
IDs are available; Android payload is not returned by this adapter). The repair
also consulted the official contracts for [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission),
[channels and user-owned restrictions](https://developer.android.com/develop/ui/compose/notifications/channels),
[alarm precision](https://developer.android.com/develop/background-work/services/alarms),
[Freedesktop notification capabilities/actions/closure](https://specifications.freedesktop.org/notification/latest/protocol.html),
[GNOME restraint](https://developer.gnome.org/hig/patterns/feedback/notifications.html)
and [Windows notification interaction guidance](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-ux-guidance).
These references do not substitute for the native checks above.

## Policy and limits

Catch-up boundaries, expiry, ten-minute Snooze, quiet-hour relevance, optional
09:00 all-account daily summaries, native channels/actions and mutation safety
remain as specified in [notification policy](notifications.md). These repairs
make that policy durable across runtimes, source toggles and local-time changes.
Normal user content and diagnostic redaction remain separate. Installed channel
choices, OS notification permission/DND, and exact-alarm controls remain owned
by the OS/user. No dependency upgrade, background architecture, notification
renderer, inbox, action or source-resolution policy was added.

Operational delivery is not claimed exactly once across a process crash between
native Show and persistence. A known active unchanged issue is observed without
another Show; a known consumed revision stays consumed when absent. An
unsubmitted ambiguous absent post may retry. Engine-owned leases release on
worker stop/detachment, so abandoned work does not leave a durable claimed state.
