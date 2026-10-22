# Notification convergence, authorization and pending-alarm follow-up

This follow-up starts from clean `fix/notifications` at
`ce065dc530d403b203344103bdf7ffe8127ffcf1`. It independently evaluates the three
subsequent source-review findings. Earlier results remain in
[the F1–F7 record](notification-repair-validation.md); their counts are not
adopted as results for this revision.

The pinned SDK is Flutter 3.47.5 / bundled Dart 3.13.4. The actual lockfile uses
Drift 2.35.0, flutter_local_notifications 22.3.0 and desktop_notifications 0.6.3.
Shared package revisions, dependencies and schema 21 remain unchanged. No
applicable AGENTS.md was present; the checkout began clean.

## Reproductions and corrections

### 1. Disabled desktop source caused a watched-query feedback loop

Confirmed for both event calendars and task lists. The new regression starts the
real scheduler and Drift subscriptions, uses the actual repository toggle,
leaves a future reminder disabled as the controlled clock passes its trigger,
and bounds work at 30 scheduler checks. Against the base implementation both
cases exhausted that budget without a notification submission. The retained
unsent row was repeatedly scrubbed even after its title/body were empty.
The pinned Drift implementation and its [stream-query contract](https://drift.simonbinder.eu/dart_api/streams/)
reschedule watched queries after updates; the running regression verifies that
behavior directly rather than assuming equal results suppress emissions.

`notification_schedule_service.dart` now skips that already-completed scrub.
Consumed, Snooze, terminal, registered and temporarily disabled identities remain
intact. With the repair, checks, schedule-table update events and cancellation
attempts settle; the same still-relevant unsent alarm submits once after enable.
A second disable/enable preserves the consumed generation and does not replay.
The test asserts lifecycle fields as well as convergence. It exercises the real
watch subscription, rather than only isolated calls to `checkNow()`.

### 2. Authorization snapshot predating issue selection could delete a current issue

Confirmed with a query interceptor paused before issue selection, after the base
implementation's generation snapshot. A second SQLite connection commits
replacement Google authorization through `AuthorizationPersistence.commit`.
While the scan is paused, `notifySyncFailure` persists its genuine generation-1
scoped failure. Resuming the base scan deletes it; selecting the expected durable
issue fails with `Bad state: No element`.

`operational_notification_coordinator.dart` no longer classifies selected issues
using the earlier authorization map. Its resolution predicate reads authoritative
account, authorization-generation and unresolved-conflict state. Both cleanup
updates and deletion include that predicate in the SQL statement, together with
the existing issue revision/lifecycle predicate. This protects the write itself,
including state changes while native cancellation awaits; it does not merely
move an unprotected Dart read closer to deletion. Generation zero retains its
established absent-row meaning.

The new regression preserves/submits the current revision once and verifies no
repeat on another reconciliation. Existing delayed-cancellation replacements,
obsolete authorization, concurrent runtime/native ID, retry and conflict cases
remain in the affected suites.

### 3. Android privacy replacement could consume an unfired inexact alarm

Confirmed by extending the exact delayed-registration regression. With native
active-state inspection available, the base test passes. With inspection failing,
it schedules only the original detailed alarm, cancels it, marks the row sent
and leaves no private replacement.

`android_notifications.dart` now persists `replacing:` in the existing mapping
state before canceling a positively observed pending registration. An absent
native alarm with this marker is known replacement work, rather than evidence
of delivery or dismissal. Real active-post evidence still takes precedence;
genuinely uncertain consumed posts keep their conservative suppression policy.
The marker retains native ID, generation and presentation provenance for silent
replacement, and survives service/connection recreation. It distinguishes known
replacement work until a new native registration attempt begins; it does not
promise exactly-once delivery across a crash during that subsequent native call.
The policy check before starting another registration no longer overwrites this
marker first.

The regression runs with active inspection available/unavailable and with no
cancellation failure, failure before removal, or interruption after removal.
Interrupted cases recover through a new service and SQLite connection. Assertions
cover cancellation, the same native identity, neutral private pending content,
silent replacement, null sent history, no repeat, active-query recovery and later
positive delivery observation. Existing displayed-private withdrawal tests also
remain enabled.

## Executed verification

All current-session logs and receipts are local under ignored
`build/notification-followup/`. The first reproduction command had a synthetic
credential fixture compile error (missing required `projectId`); after correcting
that fixture, both desktop loops and the authorization race reproduced against
unchanged production code. The Android failure/control reproduced in the first
command independently of that fixture error.

- The complete affected notification-policy and Android reconciliation files:
  **96 passed** after repair.
- The broader notification/runtime/Android policy/authorization/Linux backend/
  Windows backend, runtime and existing editor/Linux summary batch:
  **350 passed**. This overlaps the 96 and is not added to it.

All commands below were executed for this follow-up. Counts overlap and are
not added. The full suite completed on the final production/test sources.

| Command | Result |
| --- | --- |
| `python3 tool/checkout_shared_dependencies.py`; `flutter pub get --enforce-lockfile` | Passed; pinned sibling revisions/lockfile unchanged. |
| `flutter gen-l10n`; `dart run build_runner build --delete-conflicting-outputs --force-jit` | Passed; pinned builder warns that the removed delete-conflicting-outputs flag is ignored. |
| `dart run tool/check_generated_sources.dart snapshot build/notification-followup/generated-before.json`; subsequent `verify` with the same file | Passed; generated sources reproducible with no diff. |
| `flutter analyze` | Passed, no issues. |
| `dart run tool/check_platform_boundaries.dart` | Passed. |
| `dart format --output=none --set-exit-if-changed .` | Final run passed, 932 files, no changes. |
| `flutter test --concurrency=4 --reporter=expanded` | **3,978 passed, 10 skipped, 0 failed**; exit 0, 571 seconds. This follow-up's only complete full-suite run. |
| `python3 -m unittest discover -s test/tool -p '*_test.py'` | 61 passed. |
| `android/gradlew --project-dir android :busymax_android_platform:testDebugUnitTest --rerun-tasks` | 15 passed (9 plugin, 3 channel, 3 registration); tasks reran, no failures/skips. XML copied to `android-native-results/`. |
| Portable activation and short-time-pattern C++ commands below | Both built and executed successfully. |
| `flutter build linux --release` | Passed. |
| `bash tool/android/build_release.sh --all --test-signing --allow-unconfigured-providers` | Passed, APK and AAB; explicitly local **TEST-SIGNED**, not distribution artifacts. |
| Linux isolated debug target and Android isolated `:app:assembleDebug :app:lintDebug` | Passed; exact commands and targets in `final-results.json`. Native harness analysis also passed. |
| `git diff --check` | Passed. |

The ten skips are credential-gated live Nextcloud sharing, collection/large/
restart probes, two iCloud cases and three Nextcloud Login Flow cases. No
notification regression was skipped. Earlier intentional red reproductions are
not relabeled as passing. The first whole-tree formatting check found the two
new ignored native harnesses unformatted; those were formatted and the final
whole-tree check passed. Harness preparation also caught an invalid constant
and an unused import; corrected harnesses passed explicit analysis and builds.
No final Flutter assertion was weakened or disabled to make this run pass.

The broader affected command was:

```sh
flutter test --concurrency=4 --reporter=expanded \
  test/features/notifications/ \
  test/app/notification_runtime_provider_test.dart \
  test/platform/android/android_notification_reconciliation_test.dart \
  test/platform/android/android_notification_policy_test.dart \
  test/features/sync/sync_failure_notification_policy_test.dart \
  test/core/auth/authorization_transition_test.dart \
  test/platform/linux/linux_notification_backend_test.dart \
  test/platform/windows/windows_notification_backend_test.dart \
  test/platform/windows/windows_notification_runtime_test.dart \
  test/platform/windows/windows_existing_task_reminders_test.dart \
  test/features/schedule/presentation/notification_summary_workspace_test.dart
```

Portable native commands:

```sh
c++ -std=c++17 -Wall -Wextra -Werror \
  windows/runner/notification_activation.cpp \
  windows/runner/tests/notification_activation_test.cpp \
  -o build/notification-followup/notification_activation_test
build/notification-followup/notification_activation_test
c++ -std=c++17 -Wall -Wextra -Werror \
  windows/runner/tests/short_time_pattern_test.cpp \
  -o build/notification-followup/short_time_pattern_test
build/notification-followup/short_time_pattern_test
```

`validation-results.json` records preparation/focused/static commands and the
initial formatting failure; `final-results.json` records subsequent native/build/
full-suite commands. `flutter-full.log` is the complete final full-run log.
Native harnesses, controllers, APK/bundle hashes and captures are ignored local
evidence under `build/notification-followup/`, not committed release artifacts.

## Native acceptance and remaining checks

Focused acceptance uses marked synthetic Linux profiles and the isolated Android
package `io.busystack.busymax.notificationqa`. Production services, database
schema, repositories and native adapters are used. Fault injection controls
native inspection failure and asynchronous barriers, not notification rendering. A controlled
application clock can model a pending overdue inexact alarm without changing the
host/device system clock.

Packaged Windows activation/forwarding/history, Snap/store integration,
exhaustive OS clock/DST transitions, overnight OEM behavior, full accessibility/
RTL inspection and the earlier interrupted physical-phone Dismiss focus check
remain separate gaps unless explicitly completed here. A native successful
submission alone is not treated as proof of a banner, sound or user observation.

### Native results in this follow-up

Linux: GNOME 46 / X11, unpackaged debug QA bundle, real Freedesktop adapter.
Both calendar and list repository toggles were left disabled across their trigger
with the scheduler and watch subscriptions running. Across the observation
windows, affected schedule writes stayed at 2 -> 2 (event) and 11 -> 11 (task).
Checks advanced only for the requested snapshot (8 -> 9 and 21 -> 22). Neither
source posted while disabled; each then submitted once on re-enable. Withdrawal
and another enable preserved its consumed generation without another post. The
native identity map was empty after each case, and the owned QA process exited.
Receipt: `linux-native-result.json`; detailed native events remain in
`linux-profile/events.jsonl`. Timing used the controlled QA application clock,
not a change to the OS clock. CPU, power and sound were not measured.

The first native Linux controller sampled a still-running native send before its
sent-history write; the later submission was present in the trace. The controller
was corrected to wait for durable completion. A subsequent launch exceeded the
controller's 25-second ready timeout; its log included an unavailable AT-SPI
bridge. The final run used a longer bounded ready wait and `NO_AT_BRIDGE=1`
for the QA process and passed. These unsuccessful controller attempts are retained
as `linux-first-profile/` and `linux-startup-timeout-profile/`; they are not
reported as passing acceptance runs.

Android: physical OnePlus 6 (`7422120f`, ONEPLUS A6003), Android 10 / API 29,
isolated debug APK `busymax-notification-qa.apk`.

- Real inexact pending alarms, production service/adapter, authoritative settings
  and injected failure of active-notification inspection. After the first actual
  native registration, the foreground changed to Private. An ordinary run and a
  run interrupted after actual native cancellation both retained one private
  pending replacement, the original ID (669489292 / 1518392551 respectively),
  null `sentAtUtc`, and exactly two native registration calls each. A new
  service/SQLite connection recovered the interrupted run. Another reconciliation
  and recovery of history inspection did not repeat either replacement.
- A controlled application clock 15 minutes ahead models an overdue logical
  trigger while the real OS alarm remains future and pending. This avoids changing
  the phone clock and makes pending-state evidence deterministic. It does not
  establish an OEM's real-world inexact-alarm delay behavior.
- Actual `AuthorizationPersistence.commit` with a synthetic native Google
  credential advanced generation 0 -> 1 under the Android authorization gate
  while the primary notification scan was paused before issue selection. A real
  WorkManager engine reported generation 1 and persisted its issue before waiting
  for the notification gate. Release preserved `reconnectRequired:1`, submitted
  it once, and retained native ID 739713593. The combined foreground/worker Show
  log contains one call, and native active inspection found that one issue.
  Another scan did not repeat it. Recovery removed the issue and native post.
- Final native pending and active counts were both zero. Receipts, worker
  handoff files, native Show log and synthetic SQLite captures are under
  `phone-native/`. `cleanup.json` records successful QA uninstall; the regular
  package's installation state stayed unchanged. No emulator was used here.

These are delivery-state and process-overlap checks. No new claim about banner,
sound/vibration, lock-screen presentation or user acknowledgement is made from
this follow-up. No live Google reconnection or native account credential was used.
