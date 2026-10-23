# Task lifecycle validation

Validated on 2026-10-22 from `8d82282` on `fix/task-management`. The working
tree was initially clean. No applicable `AGENTS.md` was present. Development,
iCalendar data-model, and provider-support contracts were read before editing.
Findings were checked against this checkout rather than assumed from the
v0.3.2 review. Synthetic fixtures and per-run logs remain outside Git.

The detailed [replay/recovery](task-lifecycle-replay.md),
[DAV](task-lifecycle-dav.md), and [Android](task-lifecycle-android.md) ledgers
record the provider paths, before/after reproductions, controls and scoped
commands. This ledger ties the shared repository and platform work together.
"Confirmed" describes a reproduced defect and its correction; it does not
mean that every native or live-provider acceptance gate was executed.

## Dispositions

| ID | Disposition | Reachable path, correction and regression evidence |
| --- | --- | --- |
| F01 | Confirmed | Google task move → list deletion → replay. Deletion now waits for every unfinished operation touching either list, including deferred/blocked chains and later queued work. Stateful tests check actual source membership, partial success, restart, successful moves and independently changed children. Optimistic destination and intent survive blocking. See replay ledger. |
| F02 | Confirmed, narrowed as requested | Linux Schedule/details, Windows task/details and Android root/subtask checkboxes carry completion intent. DAV translates it to percentage 100/0, preserving explicit status/cancellation's reference old-state condition. Ordinary descendants/ancestors and recurring-history advancement are covered in the real DAV repository/outbox. Actual root/child checkbox tests on all three platform paths inspect local rows and persisted provider mutations; original desktop UI copies fail both parent-completion cases. Google/Microsoft retain the original platform payloads, including Android's status-only form. |
| F03 | Confirmed | DAV duplicate/delete/cross-collection move previously revisited recurring history as children. Master-only actionable traversal and editor parent/child lookup, complete-tree preflight and transactional local changes process each resource once. Stateful resource tests cover several histories, grandchildren, restart and rejected child mutations, with exact resource preservation and accurate retained dependencies. Public hierarchy regressions also reject history rows as actionable children/parents. See DAV ledger. |
| F04 | Confirmed | Dirty editor A→C, database/provider A→B, then Save. The observed editable snapshot crosses Linux/Windows/Android Save into atomic touched-field validation. Same-field changes reject without a new operation; disjoint fields merge without reverting remote values. Real SQLite/outbox tests cover Google, Microsoft and the reproduced DAV equivalent, acknowledged predecessors, still-pending edits, no-op and explicit reload followed by another edit. |
| F05 | Blocked by endpoint evidence / disposable QA prerequisite | Google PATCH and reachable PUT still have a non-atomic check/write window. Exact endpoint documentation did not establish conditional enforcement; the fictional Demo performance example is insufficient. No invented precondition, wildcard or unconditional-retry fallback was added. Required action is endpoint-specific authoritative evidence or an explicitly enabled disposable QA task to test correct/stale revisions on PATCH and PUT. See replay ledger. |
| F06 | Confirmed | Microsoft checklist rename/delete → repository/outbox → paginated provider read. The observed item is retained before projection changes. Replay compares touched fields for update and original semantic state for deletion, retains conflicts and aliases, and merges independent changes. Stateful tests and Android controls cover rename/rename, delete/edit, completion/rename, missing item, pending create/edit acknowledgment and sibling changes. The final read/write window is not claimed atomic. |
| F07 | Confirmed | Temporary creation acknowledgment → mounted editor/recovery → subsequent commands. A verified account/list-scoped alias is recorded in the acknowledgment transaction, preserved on refresh and consumed by watchers, drafts and commands. Real tests cover title/notes, child creation, move, delete, restart/recovery and notification targeting. Missing/incorrectly scoped IDs fail rather than queue zero-row mutations. The native Linux test keeps an exact dirty draft through acknowledgment and Cancel on a dirty Escape prompt. |
| F08 | Confirmed | Linux/Android Save disables draft-mutating controls after the repository has received arguments. Late picker/hierarchy callbacks are guarded; failure restores inputs and exact content, and one retry queues one operation. Linux repository-barrier and recurrence-picker tests plus Android post-capture typing/picker/failure tests exercise outcomes. Existing Windows busy protection is preserved. |
| F09 | Confirmed | Android process recovery with a changed title or supported list movement preserves edits and original comparison data. Untouched current fields are retained; same-field conflicts remain visible. Verified aliases, discard, generation-specific cleanup, failed Save and successful Save are tested. Current schema-v2 records without an exact snapshot remain recoverable and review-only; no guessed baseline or legacy format was introduced. |
| F10 | Withdrawn from repair scope | No blanket timezone rewrite. Focused parity tests retain floating detached history, device-local conversion into the advancing UTC master, COUNT decrement and final UNTIL/reopen history reuse. Compatibility with Nextcloud Tasks 0.18.1 does not guarantee ideal cross-device instants. |
| F11 | Confirmed | Linux Create now durably commits task+operation before dismissing the form. A delayed repository proves the form stays mounted/busy; precommit failure retains title/notes and retry creates exactly one task/op. Notification rebuilding failure after commit is reported through the existing operational reporter while mutation success and sync requests are retained. Patch/move Save preserves the committed patch and retries only the failed move. Linux existing-save/completion/delete/move-to-top failures use existing localized feedback. Real repository, widget and native Linux tests distinguish precommit failure, auxiliary failure and partial committed outcomes. |
| F12 | Confirmed | Selective ordinary patch/list-rename discard refreshes the provider baseline and overlays surviving queued intent atomically. Later notes/completion/move/delete and rename remain visible/pending after restart and later conflict. Their genuine comparison payloads are not rebased away. The original defect hid surviving work; it did not physically erase its queued bytes. Existing checklist overlay is preserved. |
| F13 | Confirmed | A stateful provider commits then loses the response. A sent marker and provider-normalized, field-scoped postcondition acknowledgment avoid resending an established edit. Acknowledgment/rebasing/projection/removal commit together. Title, notes, explicit clearing and ordinary completion tests retain genuine independent notes conflicts and one remote write after restart. Unknown recurrence advancement remains recovery-required rather than automatically resent. Graph normalization is covered with the actual adapter. |
| F14 | Confirmed, provider race qualified | Offline completion → Clear completed captures the approved set and all relevant operations, waits for acknowledgment and rebases only their established writes. Restart, deferred/multiple completion, reopening and independently completed/changed task tests pass. Complete provider reads check the exact set before the existing Google clear/hide endpoint. A newly completed task between that read and provider clear remains an endpoint limitation; no selective or conditional clear API is assumed. |
| F15 | Confirmed task-caller subset | Linux and Android task recurrence editors use full due-first/start-fallback references including time, kind and zone. Android unchanged Save preserves the exact original UNTIL and displays its boundary in the correct zone. Actual task dialogs cover 09:00 through the final day, due-only/start-only, date-only, floating and zoned tasks. Shared calendar recurrence semantics and unsupported/history protection remain unchanged. |
| F16 | Confirmed | DAV DTSTART+DURATION → explicit DUE removes DURATION. Removing DTSTART while DURATION remains is rejected before projection/outbox changes, with the exact draft retained and useful platform feedback. Candidate tests retain UID/history/timezones/alarms/opaque properties and prove rename-only preservation. No duration editor or source migration was added. |
| F17 | Confirmed | Shared Schedule projection now carries provider position/numeric DAV order. A deterministic scope/sibling ordering honors existing Move to top and child promotion without changing chronological date buckets. Rendered agenda tests use stateful acknowledgment, a file-backed database restart, numeric DAV siblings and multiple account/list scopes; calendar chronology and comparator transitivity are negative controls. |
| F18 | Confirmed | Schedule Overdue query and agenda eligibility now use the actual deadline, matching search. Tests cover yesterday-start/future-due, start-only, expired due, date-only/zoned values and pagination. Ordinary calendar placement continues to use start. |
| F19 | Confirmed | Shared projection carries cancellation separately from completion. Open/Overdue exclude cancelled tasks; All retains their explicit state and reopening. SQLite/DAV rendered agenda, search and reopening tests cover imported/local cancellation and completed-filter controls. Linux/Windows/Android presentation uses the shared state; notification eligibility and closed-root clear policy remain intact. |
| F20 | Confirmed | Android invalid Save shows localized title/visible-URL/temporal feedback, reveals the first invalid field, retains values and queues nothing. Correction then saves once. Hidden unsupported Google fields do not block Save, and existing past-reminder feedback remains. |
| U01 | Confirmed | Android selected-list Clear completed uses the existing confirmation convention with account/list, logical tree count and provider-accurate hide/delete consequences. Real count tests avoid recurrence projection double-counting; cancellation queues nothing. Existing Nextcloud trash/restore remains intact. |
| U02 | Confirmed bounded parity | Android Microsoft checklist menu exposes existing rename/delete, observed-item validation, busy/error retention and destructive confirmation. Real repository/stateful paginated provider tests exercise cancel, offline replay, aliases and F06 conflicts. Steps remain checklist items. |
| U03 | Confirmed bounded parity | Windows existing Nextcloud details reuse the supported advanced recurrence dialog/codec for interval/count/end date. Fluent widget/SQLite/outbox tests cover no-op raw-rule preservation, title-only edits and protected unsupported rules. Ordinary unchanged Windows Save was not labeled corrupt. Native Windows behavior remains unexecuted. |
| U04 | Qualified, confirmed errors repaired | Linux details distinguishes initial error, cached error and actual disappearance, retaining dirty drafts for explicit recovery. Creation distinguishes loading/error/true empty and retains destination/content across Retry. Android localized Retry keeps usable cached tasks/filter state. Original creation cached-data errors already retained the editor; no such defect is claimed. Windows' working list retry was preserved. Production widget tests cover all states. |

## Shared repository and editor evidence

`test/features/tasks/data/task_draft_lifecycle_test.dart` uses real SQLite,
stateful provider mutation, and gates around creation acknowledgment. It checks
the row, full retained draft, outbox payload, provider state, verified aliases
and failure outcomes. A SQLite rejection trigger proves failed local creation
rolls back both row and operation; removing that rejection allows exactly one
successful retry. Notification failure is injected only after commit and is
observed separately from returned mutation success.

`test/features/tasks/presentation/task_details_pane_test.dart` extends dirty
stream tests through real Google/Microsoft repository Save. Original pane/editor
code failed same-field Save regressions; current code retains C and B without
an operation. A post-argument barrier verifies all editable inputs are disabled
and failure preserves exact title/notes. Controlled streams distinguish initial
error, cached refresh error and actual null; a real missing task keeps the dirty
editor mounted with Save disabled. Partial patch/move tests inspect one patch
and one move after retry, rather than resubmitting the committed patch.

`test/features/schedule/presentation/schedule_workspace_task_mutations_test.dart`
extends production Create through local persistence. Against original dialog
and workspace code, the form is absent after the repository receives arguments.
The repaired test waits for that boundary and a rendered frame, then verifies
busy controls, retained fields on failure and one committed retry. A separate
postcommit scheduler failure proves the dialog closes once with one task/op.

`test/features/tasks/presentation/new_task_loading_test.dart` drives actual
account/list menus and dialog Save. Original-source runtime checks fail initial
loading/error feedback and pass the cached-error preservation control. A new
account's list data cannot inherit the previous account's retained stream
snapshot. Dirty creation content remains a dirty draft across list changes,
and Escape cancellation retains it until Save commits into the chosen account.

Related corrections found while exercising these paths are tracked separately:

- **R-DAV01:** a start-only DAV scheduling fallback was mistaken for an authored
  deadline in the draft. Draft construction/comparison now uses native due/start
  separately, with a real-projection before/after regression (DAV ledger).
- **R-CREATE01:** reloading creation destinations treated typed initial content
  as a clean baseline, disabling Create and the dirty-close guard. The editor
  now retains dirty ownership while changing only the destination; actual menu
  and Escape/Save tests cover it.
- **R-CREATE02:** changing account retained the old list stream's snapshot and
  offered an invalid destination until the new account loaded. Keying the list
  subscriber by its repository prevents cross-account cache reuse; the test
  requires Create disabled until the new account supplies its own list.
- **R-WINDOWS01:** Windows details initialized completion from a possibly stale
  Schedule argument while loading other fields from the current task. A
  title-only Save could reopen a task completed before opening. Completion now
  uses the same loaded task; real SQLite/Fluent Google/Microsoft tests include
  stale and matching Schedule snapshots.
- **R-GRAPH01:** lost-response acknowledgment needed the existing Graph adapter's
  native status/time normalization. Stateful adapter tests verify reopening,
  completion fractional precision, due and notes without weakening genuine
  independent-field conflicts (replay ledger).

The proposed extra RDATE/EXDATE edit-loss issue was not reproducible: the
current codec already protects those forms as unsupported. The preservation
negative control remains; no new recurrence capability was added.

## Toolchain and checks

Flutter **3.47.5** and its bundled Dart **3.13.4** were verified with
`tool/verify_flutter_sdk.dart`. The existing shared-dependency checkout checker
passed against pinned siblings. SDK-cache access needed the normal sandbox
escalation; SDK pins, dependency versions and lockfiles were unchanged.

Completed preparation:

```sh
python3 tool/checkout_shared_dependencies.py
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
```

The pinned builder reports that `--delete-conflicting-outputs` is deprecated
and ignored. Generation itself succeeds. All six new shared messages were
added to the supported ARBs and regenerated; the generic Portuguese file stays
a locale-only generator stub. Generated-source reproducibility
is checked against a reviewed working-tree snapshot, using the repository's
`tool/check_generated_sources.dart`; generated source is never hand-edited.

Scoped results and their exact commands are in the three detailed ledgers.
Additional coordinator checks include the shared draft lifecycle suite,
details pane, creation mutation, draft and schedule projection suites. Initial
test fixture mistakes (a missing post-submission render frame, opening a
popover rather than its Edit action, and asserting old-list identity after an
explicit cross-list move) were corrected without relaxing product validation.

The final normal offline results are recorded here after completion:

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | Passed (942 files, zero changes). |
| `flutter analyze` | Passed: no issues. Final Windows intent/test additions also passed scoped analysis. Initial scoped style/unused-field diagnostics were corrected. |
| `flutter test --concurrency=2 --reporter=expanded` | Passed: **4,119 tests**, **10 provider-gated skips**, no failures. This preceded the final narrow Windows intent guard; all affected Windows/desktop DAV suites passed afterward (**265 tests**). |
| `dart run tool/check_platform_boundaries.dart` | Passed. |
| Reviewed snapshot → localization/build regeneration → generated-source verify | Passed: generated sources are reproducible; database generated source and dependency pins unchanged. |

The initial aggregate run completed with **4,106 passed, 10 skipped and nine
failed**. The failures are accounted for below; they were not treated as skips.

The first complete offline run found three existing schedule expectations that
needed adjustment to the repaired contract. The two overdue fixtures supplied
only a start date; they now supply actual overdue deadlines and retain their
completed/hierarchy controls. The More-popover test now scrolls to and selects
the same stable item identity rather than assuming an index across account
groups. All three targeted cases pass. Separate regressions retain the
start-only/future-deadline negative controls and visible ordering assertions;
no pending data or protective validation was removed to pass these tests.
That run also exercised the two new public-hierarchy regressions against code
compiled before the final master-only lookup repair; both failed. Their focused
passing-after runs are recorded in the DAV ledger, and the final aggregate run
uses the frozen repaired sources.
The same run caught new Retry buttons bypassing the shared Linux button role
and three localization audit failures. Retry now uses `BusyMaxPushButton`;
the generic Portuguese stub, French nonbreaking punctuation and Arabic/Persian
placeholder isolation/number formatting follow the existing catalog rules.
No audit exemption was added. Focused Retry/style/loading checks passed eight
tests. The unchanged 36-test localization audit passed after regeneration, and
two permanent runtime regressions additionally verify Arabic/Persian isolation
and Persian confirmation counts (38 audit cases in the final suite).

A final explicit-control regression caught an integration error not exercised
by that aggregate run: inferring checkbox intent from the final completed
boolean replaced explicit Windows In progress (1%) and slider (50%) edits with
0%. The original dialog preserved both. Intent is now recorded only by the
checkbox, cleared by status/progress controls and reset after partial commit.
Both regressions fail with the former inferred argument and pass with the
guard. Original explicit status/combined-field UI behavior and the repository's
separate status/cancellation branch remain intact. The final affected run was:

```sh
flutter test test/ui/windows test/platform/windows \
  test/features/tasks/presentation/desktop_dav_completion_test.dart \
  --concurrency=2 --reporter=expanded
dart analyze lib/src/ui/windows/windows_task_details_dialog.dart \
  test/features/tasks/presentation/desktop_dav_completion_test.dart
```

It passed **265 tests** and analysis reported no issues. The desktop file alone
passed eight cases, including real details checkbox completion/reopening and
the explicit-control negative controls. Formatting and diff checks passed on
the final additions. No new provider capability or status semantic was added.

## Native and live-provider acceptance

| Gate actually attempted | Result and limit |
| --- | --- |
| Linux debug build, `flutter build linux --debug -t lib/main_linux.dart` | Passed on this Linux host. |
| `tool/release/check_linux_native.sh` | Native C++/locale/ASAN checks ran, then the launcher stopped because `xvfb-run` is absent. The identical script with only the virtual-display launcher removed passed all tests against the available X11 display, using `GDK_BACKEND=x11`. No test assertion or package was replaced. |
| `integration_test/task_lifecycle_linux_test.dart`, `-d linux --no-pub` | Passed (one extended native test). Synthetic memory database, stateful provider, in-memory secrets/settings and an explicitly isolated data directory. Actual Yaru/Linux window/native plugins exercise T, creation Ctrl+S, dirty title/notes through gated acknowledgment, Escape/Cancel, failed Save feedback, successful retry against the server identity, Ctrl+F, guarded Backspace, Delete/Cancel, child creation/acknowledgment, hierarchy navigation, Move to top child promotion and visible provider order, and confirmed deletion/replay. This is not a live Google test. |
| Android prerequisites / debug APK | Prerequisite checker passed; `flutter build apk --debug -t lib/main_android.dart` passed. No install was performed. Existing locked Kotlin-plugin deprecation warnings remain. |
| Android native unit tests and lint | `:busymax_android_platform:testDebugUnitTest :app:lintDebug` passed with the installed CI-compatible JDK 17.0.20. Initial JDK 25 execution failed three Mockito/ByteBuddy tests because the locked test tooling does not support that Java version. No dependency change was made. |
| Windows native build/dialog integration | Blocked on a Windows host with the repository's documented native/package setup. Fluent widget tests run on Linux do not establish real Windows focus/dialog behavior. |
| Android installed Back/process recovery/pickers | Not run on a designated QA device. An attached device was not designated disposable QA and was not modified. The installed emulator image/AVD was inspected; `emulator -accel-check` fails because `/dev/kvm` is absent. Requires a usable isolated QA emulator/host or an explicitly designated QA device. Headless Back/recovery/busy/focus tests passed. |
| Live Google / Microsoft / Nextcloud | Not run: no explicitly enabled disposable QA fixture/accounts/server versions were supplied. No live provider or server version is claimed. Follow `docs/development.md` and record actual versions when opting in. |

Native execution included these commands (the temporary Linux script changes
only the display launcher):

```sh
sed 's/xvfb-run -a //' tool/release/check_linux_native.sh > /tmp/busymax-check-linux-native-display.sh
GDK_BACKEND=x11 bash /tmp/busymax-check-linux-native-display.sh
BUSYMAX_ACCEPTANCE_ROOT="$PWD/build/task-lifecycle-native" \
  XDG_DATA_HOME="$PWD/build/task-lifecycle-native/data" \
  flutter test integration_test/task_lifecycle_linux_test.dart -d linux --no-pub --reporter=expanded
android/gradlew --project-dir android \
  -Dorg.gradle.java.home=/home/albert/.sdkman/candidates/java/17.0.20-tem \
  :busymax_android_platform:testDebugUnitTest :app:lintDebug
flutter build linux --debug -t lib/main_linux.dart
JAVA_HOME=/home/albert/.sdkman/candidates/java/17.0.20-tem \
  flutter build apk --debug -t lib/main_android.dart
```

The ten retained offline exclusions are the opt-in Nextcloud sharing case,
four Nextcloud DAV/live/large/restart cases, two Apple iCloud cases and three
Nextcloud Login Flow cases. No external credential gate was bypassed.

Existing runtime keyboard tests cover Linux T/Ctrl+F/Ctrl+S/Escape and guarded
Delete/Backspace, Windows T/Ctrl+F and dialog close guards, and Android Back.
Windows Ctrl+S was optional parity and was not added. Native Linux confirms the
paths listed above; real Windows and installed Android focus behavior remain
explicit acceptance gates rather than inferred passes.

## Preserved concepts and remaining action

Linux GTK/Yaru, Windows Fluent and Android composition remain in place.
Account and notification policies, Google date-only/hierarchy restrictions,
Microsoft checklist semantics, provider capability checks, Nextcloud full
resource/trash/restore and the pinned Tasks 0.18.1 F10 compatibility choice were
preserved. There is no universal undo/bulk system, new cloud duplication,
Microsoft cross-list move, recurrence type or provider fallback.

F05 requires endpoint-specific evidence or disposable Google QA before atomic
preconditions can be implemented or claimed. Google's check/clear and Graph's
checklist check/write windows are also recorded provider limitations. Complete
the explicitly unexecuted native/live gates above with the documented hosts,
QA opt-ins and actual provider/server versions. These limits do not invalidate
the executable client regressions and must not be reported as passes.
