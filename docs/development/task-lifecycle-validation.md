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

## Follow-up R01–R13 (2026-10-22)

This follow-up started from `cd725b1` with a clean working tree. The F/U
dispositions and earlier run results above remain historical evidence; none of
their totals is counted as a new follow-up run. Applicable repository
instructions and the development, data-model, provider, replay, DAV, Android and
validation contracts were reread. Flutter 3.47.5 / bundled Dart 3.13.4 and the
pinned sibling checkouts were verified with the existing tools. No SDK,
dependency, lockfile, database schema or localization catalog change was needed.

| ID | Follow-up disposition | Production reproduction, repair and controls |
| --- | --- | --- |
| R01 | Confirmed/repaired | Actual Windows details checkbox (0/20%) and Linux progress control (IN-PROCESS/20→50) through SQLite/DAV accepted a synchronized cancellation before repair. DAV validation now derives the lifecycle write set from the actual candidate patch, comparing the observed status/percentage/completion time that it will replace. Exact local drafts and remote cancellation survive conflict without a source/outbox write. Unchanged and remote-notes controls save; explicit cancellation can merge an untouched timestamp. Focused 14 cases pass; see DAV ledger. |
| R02 | Confirmed/repaired | Actual Android Tasks, Windows Tasks and Linux agenda retained a checked overlay after a real COUNT=3 master advanced under its same ID. Linux/Android also lacked a per-task in-flight guard. Completion intents now carry the authored occurrence identity, settle when it advances and never overlay the next occurrence. An atomic repository guard rejects callbacks bound to an older occurrence; deliberate completion of the newly rendered open occurrence remains valid. Rendered/raw-resource tests verify D+1, COUNT=2, one history, stale callback rejection, in-flight activation, ordinary completion and final COUNT=1. A separately reproduced stale Windows editor Save also receives the lifecycle-only occurrence guard; title-only edits still merge after advancement. The earlier explicit-status Android stale-editor probe was already protected; D03 below records the separately confirmed omitted-status task after an acknowledged move. |
| R03 | Confirmed/repaired | Actual parent→child→parent navigation let a hidden editor overwrite durably saved L2 with older L1 in an isolated copy of the checkout's original Android path. Rapid row activation across a controlled task-read boundary separately opened two editors. Hierarchy navigation now reuses the mounted editor/exact draft through existing dirty-close decisions. Bounded Navigator/account/list/verified-identity reservations also prevent duplicate top-level owners and converge temporary aliases; independent creation requests remain independent. Controlled IO retains the newest notes across timers/recreation and drains pending writes before Save/Discard cleanup. Dirty-child cancellation retains both routes/drafts. See Android ledger for exact before/after evidence and scope controls. |
| R04 | Confirmed/repaired | Actual Android Schedule agenda/search and Windows day/week checkboxes completed only the parent through the explicit-status branch before repair. The missed callers now use `TaskPatchInput.completion`; Android retains status-only Google/Microsoft payloads and Windows retains its completion timestamp. Real DAV rows/candidates and stateful replay/reload check descendants, ancestor reopening and absence of cancellation. Existing explicit status/progress/cancellation and task-page controls remain covered. |
| R05 | Confirmed/repaired | A provider committed PATCH/PUT, lost its response, then an unsent reconciliation GET erased the durable `in_progress` evidence. Earlier dispatch uncertainty now survives failed reads, retry scheduling, manual Retry and restart. Stateful/disk-backed tests establish one remote write, dependent progress and retained genuine divergence; a first genuinely unsent write remains retryable and uncertain recurrence remains recovery-required. See replay ledger.  Its read-failure regression covered an unsent request; [S02](#synchronization-follow-up-s01-and-s02) qualifies the dispatched-rejection path. |
| R06 | Confirmed/repaired | Actual Microsoft adapter with paginated mutable checklist state committed rename/check/uncheck then lost the response; retry self-conflicted. Item updates now persist attempt evidence and acknowledge only established touched-field postconditions. Acknowledgment, dependent baselines, visible overlay and removal commit together. Tests cover failed reconciliation reads, restart, second-connection commit barriers, unrelated fields, missing/sibling items and existing create/alias safeguards. Graph's final read/write window remains unguarded by any proven endpoint precondition. |
| R07 | Confirmed/repaired | A real SQLite interceptor held delivery of an already-read temporary parent while acknowledgment committed its server identity; creation then queued the obsolete ID and could replace newer sibling state. Parent identity/items are reread and merged inside the projection/outbox transaction, with parent-create dependencies. The regression preserves an acknowledged sibling alias plus its later edit and makes exactly one remote creation for the held item. Ack-before-read and ack-after-enqueue controls pass. A related unavailable-list race was also reproduced and repaired below.  This identity result did not establish parent cleanliness after checklist acknowledgment; see [S01](#synchronization-follow-up-s01-and-s02). |
| R08 | Confirmed/repaired | Stateful paginated Google responses reproduced clear→list-delete hidden self-conflict, child-delete→list-delete tombstone membership self-conflict and incoming completed-move→destination-clear self-conflict. Only captured predecessor effects rebase approved snapshots, including both move endpoints, hidden state and live-versus-deleted membership. Acknowledgment/projection/dependent updates/removal are atomic locally. Restart, deferred/blocked predecessors and second-connection barriers pass; external notes/new live children/new completed tasks still block. Related snapshot defects are listed in the replay ledger. Google's endpoint check/clear race remains. |
| R09 | Confirmed/repaired | Same-list DAV C→top with A PUBLIC/0, B PRIVATE/1 and C PUBLIC/3 partially changed A before rejecting B. The complete local plan now preflights affected members and commits sibling normalization, hierarchy effects, candidates, outbox and pending marker in one transaction. Exact before/after snapshots remain equal on privacy rejection and late SQLite failures. All-public acknowledgment/restart and private-first controls pass. Remote multi-resource atomicity is not claimed. |
| R10 | Confirmed/repaired | Discarding current-v2 recovery without an observed snapshot (or rejecting malformed late-parsed metadata) poisoned fresh Android Save with recovery-only comparison flags. Those flags/source metadata are now accepted only with the restored draft and reset on discard/rejection. Fresh edits queue once against the loaded task; Restore without a historical snapshot remains review-only. No legacy format or guessed baseline was added. |
| R11 | Confirmed/repaired | Real Linux New Task account/list controls retained an invalid Nextcloud URL/start-deadline pair when switched to Google, but hidden fields disabled Create/Ctrl+S. Button, feedback and Save now use the existing active-provider validation. A further actual account-switch regression proved retained LocationChange was forwarded and rejected Google creation; creation output now filters that change by capability while preserving the hidden draft. The final three affected suites pass 27 cases. Actual Linux recurrence switching and factory recurrence protection were already correct and remain controls. |
| R12 | Confirmed/repaired | After Android move A→B failed, List retried B instead of allowing C. Save retains explicit retry, while List offers another destination or the current source to cancel only the pending move. Before/after-patch tests preserve the exact draft, do not repeat a committed patch and cover recovery/restart, retry B, C, cancellation and disappeared B. |
| R13 | Confirmed/repaired | Actual read-only Android parent/child links remained disabled because navigation required write permission. A separate navigation guard permits readable relatives while retaining saving/loading/recovery guards. Completion/create/edit/delete remain disabled. Route reuse and submitted-Save navigation controls cover the R03 interaction. |

### Additional directly related corrections

- **D01 (R03 Save path):** real ordinary/plain and HTML DAV notes replacement
  failed because the builder removes the stale target `X-ALT-DESC`, while its
  own mutation allowlist rejected that property. Only that intended property
  was admitted. Two failing-before/passing-after resource/outbox/replay tests
  preserve detached HTML/history, UID/parent/rule, timezone/alarm and opaque
  data; a title-only control preserves the alternative description.
- **R07-list availability:** while the parent-read delivery was held, actual
  repository list deletion marked the list unavailable but checklist creation
  still succeeded. The transaction now requires the list as well as the parent.
  The before test completed instead of throwing; all four final checklist
  creation cases pass, with exact row/outbox preservation on rejection.
- **R03 movement provenance:** scoped recovery must distinguish a real move
  from two live equal-ID rows in different lists. Supported cross-list local
  move transactions now remember the prior list in client metadata; provider
  refresh preserves that evidence for the same scoped row. No missing-row
  inference or arbitrary identity redirection was added. The before movement
  regression lacked this evidence. A real stateful cloud move/ack/refresh/disk
  restart test and the affected repository/draft suites pass **25** cases;
  same-list movement adds no scope and unrelated equal-ID rows inherit none.
  DAV controls preserve each master/history row's own native metadata. The
  final DAV integration run passes **82** cases, including acknowledgment,
  refresh/restart, partial rejection/retry and unrelated UID replacement at the
  same destination URL. A confirmed DAV move transfers only verified aliases
  and prior scopes per UID/recurrence key to its new projection identity.
  Reprojection never transfers those identities to another UID.
- **R03 ownership boundaries:** additional actual-control failures established
  shared storage between equal IDs in different lists, a delayed top-level
  read pushing a second editor after hierarchy navigation, and repeated New
  Task activation sharing one recovery slot. Existing-task recovery is now
  scoped by account/list/verified identity, and both navigation entry points
  reserve/recheck ownership. Repeated identical creation contexts reuse their
  draft; differing initial dates remain independent. The current-v2 body stays
  unchanged. Accepted current-v2 source records migrate through the same
  serialized owner; foreign candidates are preserved. The earlier F09 movement
  fixture actually left two live scoped rows. It now performs a real supported
  move, acknowledgment and refresh before restart; the two-live-row case is
  retained as the independence negative control.
- **D02 (R04 Windows planner failure):** the changed checkbox caller rethrew a
  failed local mutation from its void callback, yielding an unhandled error and
  no feedback. An actual planner checkbox fails before repair. It now uses the
  existing localized Fluent InfoBar, retains exact rows/outbox and allows one
  successful retry. The feedback test waits for the existing entrance animation;
  no production delay was introduced.
- **D03 (R02/R03 observed occurrence after movement):** an open recurring DAV
  task without an explicit STATUS reproduced an additional stale completion:
  complete D, acknowledge the resource, move/acknowledge its tree to B, then
  reopen the already-mounted dirty editor and Save its old 100% draft. The
  identity rebind copied D+1's native temporal metadata into the observed
  snapshot, so Save advanced D+1 again. Rebinding now merges only verified
  aliases and prior-list provenance into the original observed metadata.
  Actual Android controls, real DAV storage and stateful PUT/MOVE replay retain
  D+1, one history, the exact draft/recovery comparison and no new candidate.
  Notes-only merging and completing an unchanged occurrence remain valid.
  An explicitly authored NEEDS-ACTION control was already protected by the
  semantic status comparison; that passing protection was not misreported as
  an overwrite. The four final cases and six related ownership controls pass.
- **D04 (R02 Android feedback):** the new occurrence guard reached an English
  diagnostic fallback in the editor, Tasks, Schedule and hierarchy checkbox
  handlers. Actual German controls reproduced the untranslated snackbar after
  first proving retained draft/provider/outbox state. These four handlers now
  use the existing localized draft-conflict message for this exception only.
  All four German controls and five existing occurrence controls pass; no
  strings, layouts or other error conventions changed.
- **R08-clear-after-ack / R08-incoming-move:** separately reproduced snapshot
  composition defects are recorded in the replay ledger. Known hidden effects
  remain attributable after acknowledgment; an existing destination-deletion
  snapshot never adopts independent notes from a move response.

### Follow-up commands and results

The following are new executions, with temporary logs outside Git. Focused
before failures were established before their corresponding behavior changes;
test harness compile/selector mistakes were corrected without changing valid
contracts. Detailed replay, DAV and Android commands/results are in their
respective ledgers. Coordinator-focused runs were:

```sh
flutter test test/features/tasks/presentation/new_task_loading_test.dart --plain-name R11 --reporter expanded
flutter test test/features/tasks/data/checklist_creation_identity_test.dart --reporter expanded
flutter test test/features/tasks/data/checklist_creation_identity_test.dart --plain-name 'after read with unavailable list' --reporter expanded
flutter test test/features/tasks/presentation/desktop_recurring_completion_test.dart --reporter expanded
flutter test test/features/tasks/presentation/desktop_recurring_completion_test.dart test/features/tasks/data/checklist_creation_identity_test.dart test/features/tasks/presentation/new_task_loading_test.dart --concurrency=2 --reporter expanded
```

The initial checklist run passed its ack-before-read control and failed the
obsolete-ID and missing-parent-dependency cases. The initial corrected desktop
run passed four ordinary/final controls and failed six assertions: two stuck
COUNT=3 presentations, Linux's duplicate submission, Windows' guarded submission
whose next presentation still stuck, and the two planner descendant cases.
After repair the desktop file passes **12**, creation/loading passes **8**, and
the original three checklist cases pass; the combined run passes **23**. The
later unavailable-list regression brings the final checklist file to **4**.
The final desktop file including D02 passes **13** cases.
The additional actual account-switch/location controls and affected draft and
creation suites pass **27**. The Android adaptive checkpoint passes **118**,
including the scoped ownership extensions, moved-list caption and hidden
creation-owner Cancel/Discard controls. After D03/D04, the complete file passes
**126**; the earlier counts remain historical checkpoints. Commands for these
extensions were:

```sh
flutter test test/features/tasks/presentation/new_task_capability_emission_test.dart test/features/tasks/presentation/task_details_draft_test.dart test/features/tasks/presentation/new_task_loading_test.dart --concurrency=2 --reporter expanded
flutter test test/features/tasks/data/task_move_identity_test.dart test/features/tasks/data/task_draft_lifecycle_test.dart test/features/tasks/data/tasks_repository_test.dart --concurrency=2 --no-pub --reporter=expanded
flutter test test/platform/android/android_adaptive_app_test.dart --concurrency=1 --reporter=expanded
```

The scoped movement/repository command passes **25**, and the final full DAV
integration file passes **82**. These overlapping affected runs are not added
to the full-suite total.

Preparation used the pinned SDK executables (`flutter` and bundled `dart` below)
and the documented shared-dependency workflow:

```sh
dart tool/verify_flutter_sdk.dart --flutter /home/albert/flutter/bin/flutter --dart /home/albert/flutter/bin/cache/dart-sdk/bin/dart --expected-flutter 3.47.5 --expected-dart 3.13.4
python3 tool/checkout_shared_dependencies.py
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run tool/check_platform_boundaries.dart
flutter build linux --debug -t lib/main_linux.dart
BUSYMAX_ACCEPTANCE_ROOT="$PWD/build/task-lifecycle-followup-native" XDG_DATA_HOME="$PWD/build/task-lifecycle-followup-native/data" flutter test integration_test/task_lifecycle_linux_test.dart -d linux --no-pub --reporter=expanded
BUSYMAX_FLUTTER_EXECUTABLE=/home/albert/flutter/bin/flutter JAVA_HOME=/home/albert/.sdkman/candidates/java/17.0.20-tem ANDROID_SDK_ROOT=/home/albert/Android/Sdk tool/android/check_prerequisites.sh
android/gradlew --project-dir android -Dorg.gradle.java.home=/home/albert/.sdkman/candidates/java/17.0.20-tem :busymax_android_platform:testDebugUnitTest :app:lintDebug
JAVA_HOME=/home/albert/.sdkman/candidates/java/17.0.20-tem flutter build apk --debug -t lib/main_android.dart --no-pub
```

The SDK checker, sibling checkout verification, lockfile-enforced resolution,
localization and builders passed. The pinned builder reports its existing
deprecated flag warning; pins were retained. Generated-source snapshot →
generation → verification passed with **no checked-in generation diff**.
Platform boundaries passed. Formatting passed (946 files, zero changes before
the added native Android test); initial analysis found one test-helper braces
info, corrected without behavioral changes, and the subsequent full analysis
passed with no issues. Final checks for later additions are recorded below.

Linux debug build passed. The native Linux task integration test passed **1**
in 24 seconds in a real Yaru window using isolated synthetic state. It exercised
creation, temporary identity acknowledgment, dirty Escape/Cancel, failed Save
and retry, hierarchy/promotion/order, keyboard shortcuts and deletion guards;
it did not contact a live provider. Android prerequisites, native unit/lint
Gradle tasks and debug APK build passed. Existing locked-plugin Gradle warnings
were retained; building the APK alone is not installed Android acceptance.

Unlike the historical native-limit row above, current KVM acceleration was
usable. Installed Android checks therefore use a newly created, explicitly
designated disposable API 35 emulator with a private ADB server; the existing
AVD and attached personal device are untouched. The app still compiles/targets
API 37. The native Android bridge smoke test passed **1** on that emulator.
The Android ledger records the separate installed task acceptance and process
receipts; no widget recreation is counted as process recovery.

Final follow-up results below supersede these historical checkpoints for this
repair. Previous totals and native results are not substitutes for those runs.
An initial follow-up aggregate run (`flutter test --concurrency=2
--reporter=expanded`) was intentionally interrupted after **3,260 passed and
10 provider-gated skips**, while additional bounded R03/R11 regressions were
being established. SIGINT caused a loader/channel shutdown error; this partial
run is not counted as a passing full suite. The final run uses the completed
sources after those focused repairs.
Two brief aggregate attempts were also stopped after **148** and **153**
passes when the additional creation-owner navigation and moved-list caption
controls established remaining corrections. Their interrupted loader cleanup
is not a product regression or a passing suite. Intermediate analysis found
two undefined fixture variables in a storage-key migration assertion; the
fixture was corrected while preserving its original recurrence/timezone
checks. That Android checkpoint passed all 118 tests; final D03/D04 coverage
passes 126.

The later full formatting command passed **949 files, zero changes**. Full
analysis passed with **no issues** (182.4 seconds); the last Android caption
edit also passed focused analysis and formatting. Final Linux debug build and
the native task integration test passed **1** in 17 seconds using
`build/task-lifecycle-followup-final-native` for both the acceptance root and
isolated data directory. Generated-source verification after the UI-only
corrections still matches the reviewed snapshot. Platform boundaries passed.

The next aggregate completed with **4,245 passed, 10 provider-gated skips and
one failed assertion**. The new moved-occurrence regression expected the
occurrence-specific message, while its explicit-status fixture correctly
received the existing useful draft-conflict message. A supported omitted-status
control then established D03's actual unsafe advancement separately; the
identity-only correction and exact durable-recovery controls passed before
starting the final aggregate. This failed aggregate is not reported as a pass.
The following aggregate was intentionally stopped after **1,030 passes** when
the separate German controls confirmed D04. Its SIGINT cleanup errors and zero
CLI exit status are not counted as a passing full suite. All nine focused D04
and occurrence controls passed before the final aggregate/check sequence.

### Final follow-up verification

The final application and widget-test source hashes stayed unchanged during
the aggregate. A later native-checklist harness tab-readiness correction was
checked separately with scoped analysis/formatting; it does not change the
application or the offline suite.

| Command | Actual final result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | Passed: **950 files, zero changes**, 164.82 seconds. |
| `flutter analyze` | Passed: **no issues**, 124.7 seconds. |
| `flutter test --concurrency=2 --reporter=expanded` | Passed: **4,251 tests**, **10 existing provider-gated skips**, **no failures**, 36:03; process exit 0. |
| `dart run tool/check_platform_boundaries.dart` | Passed. |
| `dart run tool/check_generated_sources.dart verify /tmp/busymax-followup-final-r03-generated.json` | Passed against the reviewed regeneration snapshot; no generated, schema, locale or dependency-pin diff. |
| `JAVA_HOME=/home/albert/.sdkman/candidates/java/17.0.20-tem flutter build apk --debug -t lib/main_android.dart --no-pub` | Passed: **158.6 seconds**, normal debug APK preserved separately from native acceptance artifacts. `JAVA_HOME` records the command environment; Flutter's existing JVM selection was retained. |

The final check sequence ran sequentially. An earlier concurrent invocation of
two Dart checks raced while copying `.dart_tool/lib/libsqlite3.so`, causing
generated verification to fail before executing its check. The unchanged
command passed sequentially, and the final sequential sequence passed both
checks. No source, pending data or validation was changed to avoid that race.
The ten skips require eight explicitly enabled Nextcloud fixtures/stages and
two explicitly enabled iCloud fixtures. Their existing exclusions were retained;
none is counted as a pass. No Google/Microsoft live acceptance is inferred from
the offline suite. Final source-hash verification matches all 790 application,
widget-test and integration-test sources, including the separately checked
native harness correction.

The final Linux build/native test above passed before the last Android-only
metadata and feedback corrections; the shared/Linux sources were unchanged
afterward. Installed Android core acceptance passed one scenario across actual
process deaths/relaunches using software rendering, and its separate platform
bridge smoke passed one test. Exact scope, PID receipts, failed harness attempts
and the normal-renderer limit are recorded in the Android ledger.

Installed offline Microsoft checklist acceptance also completed on the final
localized application sources. PID 3847 exercised Rename Cancel/Apply, Delete
Cancel/confirm and real Android Back. It retained exactly two pending item
operations with their dependency, leaving the core fixture's four operations
unchanged. After an actual force-stop/process-absence check, PID 4459 reopened
the same database and verified the projection, payloads and dependency. The
verification phase reported `All tests passed`; the preceding UI checkpoint
was deliberately interrupted for that restart and is not counted as another
passed test. No Graph call or credential was used. The two native integration
files passed scoped analysis and formatting after their final synchronization
correction. The normal APK byte-matches its preserved build artifact.

The first checklist attempt selected the prior Schedule row before the Tasks
tab rendered; the test now waits for the tab transition. A subsequent QA
emulator native crash occurred before installation. Its cause was not
established. The same owned AVD restarted without wiping userdata and completed
the installed checklist/restart checks. The owned emulator and private ADB
server were stopped afterward; no personal device or existing AVD was used.

Remaining external actions are specific: run the documented native task/dialog
checks on a designated Windows QA host; repeat installed Android acceptance
with the normal renderer on a stable designated device/emulator; and explicitly
enable the disposable provider fixtures from `docs/development.md`, recording
actual server/provider versions before live mutation checks. The API 35 emulator
run does not prove API 37 runtime acceptance. No confirmed R01–R13 code defect
remains from this bounded repair, but these unexecuted gates remain unverified.

F05 remains **blocked** on endpoint-specific authoritative PATCH/reachable PUT
evidence or explicitly enabled disposable Google QA. F10 remains **withdrawn**;
device-local advancement, floating detached history, COUNT/final-UNTIL/reopen
behavior and the Tasks 0.18.1 compatibility limitation are preserved. Account
and notification policies, Google clear/hide, Microsoft checklist identity and
Nextcloud trash/restore remain unchanged. Native Windows and live-provider
checks still require the designated host/disposable fixtures described above;
none is inferred from widget tests or builds. Installed Android acceptance is
limited to the explicitly recorded disposable-emulator scenarios.

The exact Google [PATCH](https://developers.google.com/workspace/tasks/reference/rest/v1/tasks/patch)
and [PUT](https://developers.google.com/workspace/tasks/reference/rest/v1/tasks/update)
method pages were reread during this follow-up. They do not specify a verified
conditional-write mechanism for these endpoints. That is insufficient evidence
to implement or claim atomic protection, and does not prove such support is
absent. No disposable Google fixture was enabled for an endpoint experiment.

## Synchronization follow-up S01 and S02

Revalidated on 2026-10-23 from clean commit `6bc44e5`. No applicable AGENTS.md
was present. Development, provider, iCalendar and lifecycle/replay contracts
were reread. Flutter 3.47.5 / bundled Dart 3.13.4 and the pinned shared
checkouts passed their existing checkers. No SDK, dependency, schema or locale
pin changed. The detailed [replay evidence](task-lifecycle-replay.md#synchronization-follow-up-s01-and-s02)
records the production paths, before/after commands and controls.

| ID | Disposition | Verified outcome and correction |
|---|---|---|
| S01 | Confirmed/repaired | The R07 after-enqueue sequence left an acknowledged Microsoft parent dirty with an empty outbox. A stateful, file-backed repository/replayer/SyncEngine regression then retained `Parent` instead of importing `Remote title` on an ordinary full pull. Identity dependencies are still traversed/rewritten, but only actual task mutations retain the parent's optimistic fields or receive parent-field baseline rebasing. Checklist-only work preserves its own projection, aliases and baselines without keeping the parent dirty. Full pulls, full pulls after database restart, Microsoft's ordinary full-refresh incremental path, a controlled checklist-acknowledgment barrier, pending parent patch/replay and pending parent deletion controls pass. This was persistent exclusion from regular sync, not unrecoverable loss: an acknowledged parent edit already cleared it. |
| S02 | Confirmed/repaired | Stateful PATCH and PUT committed B and lost the response; a parsed non-quota HTTP 403 from the reconciliation GET changed `in_progress` to `failed`. Blocked feedback/timing now preserve an existing task-write marker, which survives real resolution-service Retry, restored account eligibility and database restart. The applied title is acknowledged without another title write, and the separate dependent notes edit proceeds. Remote C still conflicts; first rejected/unsent writes are not treated as prior uncertain writes. Recurring completion retains `recovery_required` and cannot be resent automatically. Paginated Microsoft checklist PATCH already retained its marker; adapter-decoded 403 rename/check/uncheck controls remain passing. |

The unchanged-production before run completed **11 passed / 8 failed**: two
S01 state/import failures, four ordinary S02 PATCH/PUT failures and two S02
recurrence-marker failures. First-write rejection and checklist 403 controls
passed. The initial run had one extra fixture failure: a parent edit scheduled
at the identity-recovery sentinel was correctly unblocked by acknowledgment.
Using a genuine future retry date fixed that control without changing code or
erasing an operation. The focused passing-after command completed **25 tests**;
the four affected suites completed **249 tests**. These counts overlap and are
not added together. The finalized affected command passed **249** in 0:06
after adding acknowledgment-barrier cleanup and actual Graph-error decoding.

New preparation and normal-check executions used the pinned executables:

```sh
dart tool/verify_flutter_sdk.dart --flutter /home/albert/flutter/bin/flutter --dart /home/albert/flutter/bin/cache/dart-sdk/bin/dart --expected-flutter 3.47.5 --expected-dart 3.13.4
python3 tool/checkout_shared_dependencies.py
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
dart run tool/check_generated_sources.dart snapshot /tmp/busymax-s01-s02-generated-20261023.json
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs --force-jit
dart run tool/check_generated_sources.dart verify /tmp/busymax-s01-s02-generated-20261023.json
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run tool/check_platform_boundaries.dart
```

The snapshot was created fresh for this follow-up before the final regeneration;
no historical ledger snapshot was reused. SDK/shared checks, lockfile-enforced
resolution and both setup/generation sequences passed. The final builder took
48.5 seconds, retained the existing deprecated-flag/Drift warnings and produced
no checked-in generated diff. Fresh verification passed. Formatting passed
**950 files, zero changes** (12.57 seconds); analysis reported **no issues**
(7.3 seconds); platform boundaries passed. No validation or exclusion changed.

Final aggregate command:

```sh
flutter test --concurrency=2 --reporter=expanded
```

It passed **4,266 tests**, **10 existing provider-gated skips**, **no failures**
in **10:10**, exit 0. The skips require eight enabled Nextcloud fixtures/stages
and two enabled iCloud fixtures; none is counted as passed. No Google/Microsoft
live pass is inferred. Source hashes confirm the repaired replayer and both
regression files stayed unchanged during that run. The final diff check was
clean; only the two ledgers, replayer and two regression files changed.

No production account or live provider was accessed. No new native acceptance
is claimed here; prior software-rendered Android evidence remains bounded.
F05 remains blocked on endpoint-specific Google PATCH/PUT evidence or explicitly
enabled disposable QA. F10 remains withdrawn. The Google clear and Graph
checklist check/write windows, account/notification policies, DAV explicit
cancellation, percentage checkbox semantics, recovery ownership and occurrence
guards are unchanged.
