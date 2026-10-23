# DAV task lifecycle validation

This ledger records the DAV portion of the task lifecycle repairs against the
current checkout. Tests use synthetic resources and a real SQLite database.
Stateful replay fixtures retain provider resource bodies and ETags after each
successful mutation. Native desktop/mobile and live-server acceptance is a
separate gate; these tests do not establish it.

| ID | Disposition | Verified path and correction |
| --- | --- | --- |
| F02 | Confirmed | Checkbox callers now carry completion intent through `TaskPatchInput.completion`; DAV maps that intent to percentage 100/0. Hierarchy mutation remains atomic. Explicit status/cancellation retains the old-state condition from Nextcloud Tasks 0.18.1. |
| F03 | Confirmed | `_davChildren`, `_davParent`, and `_davParentTask` select masters. Duplication, deletion and cross-list movement preflight the complete tree and commit the local tree/outbox in one transaction, retaining child-first delete/move dependencies. Detached history remains inside its resource. |
| F04 (DAV path) | Confirmed | An actual `TaskDetailsDraft` carries the observed A through a remote B projection into repository Save. Validation runs in the hierarchy transaction; same-field C is retained as a conflicting draft, while independent remote notes merge into the queued candidate. |
| F10 | Withdrawn from repair scope | No authored-timezone/instant rewrite. Focused parity coverage preserves floating history, device-local advancement into a UTC master, COUNT decrement and the existing exhausted-UNTIL/reopen behavior. |
| F15 | Confirmed | The Linux task recurrence editor now receives the complete effective due-first/start-fallback reference, with its time, date-only/floating kind and corresponding zone. A shared draft helper preserves the authored floating kind while timing is untouched. The Android task editor uses the same reference. Calendar recurrence semantics are unchanged. |
| F16 | Confirmed | Explicit DUE authoring removes mutually exclusive DURATION. Queue validation rejects DUE+DURATION and DURATION without DTSTART before changing the projection or queue. Unrelated valid duration-based edits preserve DURATION. |
| U03 | Confirmed bounded parity | Windows existing-task details now open the supported advanced recurrence editor. Real Fluent-dialog/SQLite/outbox tests cover interval/count/end-date changes, preserved raw recurrence on no-op/unrelated saves and protected unsupported recurrence. |
| U04 (Linux creation) | Qualified | Initial loading/error feedback and Retry were missing in the current HEAD implementation. A cached read error already retained its mounted editor; that negative control was preserved. New tests cover exact dirty values/destination, Retry, ownership changes and durable Save. |

## Reproductions and controls

- F02: import open P/C/G, explicitly set P's status to completed, and then
  reopen using checkbox intent. C remains open without cancellation. Completing
  P through checkbox intent completes ordinary descendants; reopening C reopens
  closed P and preserves G's independent completed state. Explicit cancellation
  still cancels open descendants while preserving already-completed ones. A
  recurring child with two completed histories advances once, adds exactly one
  history and retains its original histories. Existing COUNT/UNTIL final-state
  regressions remain in the affected suite.
- F03: import P, recurring C with one or three normal completed history
  components, and grandchild G. Histories appear before the master in the
  resource and inherit its parent. Fresh duplicate/delete/move fixtures verify
  three logical resources, exact dependency order, new UID/new parent for a
  duplicate, retained recurrence identities, alarms, timezone components and
  opaque data. Three-history cases restart the database before queueing and
  before replay. Existing no-history hierarchy cases are the negative control.
  All six history cases failed before the repair; all pass afterward and replay
  exactly three provider mutations.
- F03 validation boundary: a later private child in a shared source/destination
  rejects duplicate/delete/move. Before the repair, the earlier member or copy
  remained changed/queued; all three regressions failed. Afterward every local
  row and the queue remain unchanged. Separate stateful provider-rejection tests
  commit one member, reject C, restart, retain C and its dependent operation,
  then explicitly retry and commit only the remaining two resources.
- F10: Linux parity tests run under UTC and America/Vancouver. A TZID-authored
  task retains floating detached due/recurrence values while its advancing UTC
  master reflects the device-local conversion used by the pinned reference.
  The different resulting instants are a documented compatibility limitation,
  not evidence of ideal cross-device timezone behavior. These two process-zone
  tests explicitly skip hosts without the Linux `tzset` test seam.
- F15: actual Linux recurrence/date-picker/Save controls exercise UTC timed
  due/start, floating due-only, zoned start-only and date-only tasks. All four
  fail with the original editor and pass after the correction. The UTC daily
  09:00 rule expanded through August 12 includes August 12 at 09:00. The shared
  rule helper and already-correct calendar semantics were not changed.
- F16: a valid DTSTART+DURATION task rejects clearing DTSTART and retains the
  exact row, resource and empty outbox; rename retains DURATION; setting DUE
  removes DURATION and preserves UID, alarm and opaque content. The candidate
  regression failed before repair with DURATION still present. Direct queue
  tests reject both invalid relationships. Existing temporal range/type
  rejection tests remain negative controls.
- F04 DAV: title A is loaded into the actual draft, changed locally to C, then
  a provider title B is projected before Save. The observed-baseline Save rejects
  without changing B or adding an operation; the draft still contains C and
  observed A. The disjoint remote-notes control queues C against the current
  exact ETag and retains the remote notes in both the candidate and local row.
- F08 supporting coverage: a real Linux recurrence/date-picker modal opened
  before the parent becomes busy cannot apply its late Save into the busy draft.
  Reminder modal callbacks and direct progress/completion callbacks use the same
  enabled guard. The coordinating ledger covers repository save barriers.
- U03: the isolated interval/count UI test fails against the original Windows
  details implementation because no advanced edit control exists. With the
  repair, interval/count and a timed end date persist through the real DAV queue.
  Opening/unchanged advanced Save adds no operation, and a title-only Save leaves
  the original noncanonical-but-supported RRULE order intact. Unsupported hourly
  recurrence remains disabled and survives title changes. This is widget testing
  of Fluent controls on Linux; native Windows integration remains unexecuted.
- F16 Windows feedback: clearing DTSTART while typing a new title displays the
  localized duration transition explanation and keeps the exact text, original
  resource and empty outbox. Adding a deadline then saves once with no orphan
  DURATION or DTSTART. The supported recurrence set and alarm remain intact.

## Separately confirmed related correction

**R-DAV01 (related to F15/F16):** the DAV schedule projection intentionally stores
`dueUtc = due ?? start`. The draft reused this scheduling fallback as though it
were an actual deadline, so a timed DTSTART-only resource (including a valid
DTSTART+DURATION task) opened with an invented date-only due date. The real
projection regression failed before repair with `dueDate == '2026-08-08'` and
passes afterward with no due date and a 09:30 start recurrence reference. Draft
construction and its patch comparison now use that fallback only for non-DAV
tasks. Normal schedule placement and Google/Microsoft fallback behavior remain
unchanged. The Linux timed start-only UI fixture also includes the actual
projection fallback to protect this boundary.

**Related Linux creation corrections:** list arrival/rebinding initially reset
the dirty creation draft's clean baseline, leaving Create disabled after a
successful Retry; the regression failed with retained values but a disabled
Create control. Switching account could also reuse `StreamBuilder`'s prior
account data to repopulate the newly cleared list cache. Its regression failed
with Create still enabled before the new account's first list result. The editor
now preserves creation dirtiness and the list stream has repository-scoped
identity. These fixes retain the existing account selection model and validate
the final persisted account/list ownership.

## Commands and results

The shared preparation/checker was performed by the coordinating agent with
Flutter 3.47.5 / bundled Dart 3.13.4 and the locked shared dependencies.
Flutter test commands need access to the pinned SDK's cache outside the
workspace sandbox. An initial sandboxed invocation failed before compilation
because that cache was read-only; the same commands ran with approved SDK-cache
access. Temporary raw logs stay outside source control.

Focused before/after commands:

```sh
flutter test test/dav/mutation/dav_repository_mutation_integration_test.dart --plain-name 'task tree' --reporter expanded
flutter test test/dav/mutation/dav_mutation_patch_test.dart --plain-name 'an explicit task deadline replaces duration' --reporter expanded
flutter test test/features/tasks/presentation/ical_task_fields_editor_test.dart --reporter expanded
flutter test test/dav/mutation/dav_repository_mutation_integration_test.dart --name 'checkbox|task timing edits replace duration' --reporter expanded
flutter test test/dav/mutation/dav_repository_mutation_integration_test.dart --plain-name 'provider rejection retains the pending' --reporter expanded
flutter test test/dav/mutation/dav_mutation_patch_test.dart --plain-name 'Nextcloud 0.18.1' --reporter expanded
```

The initial affected-suite command passed **140 tests**:

```sh
flutter test --concurrency=2 --reporter expanded \
  test/dav/mutation/dav_mutation_patch_test.dart \
  test/dav/mutation/dav_repository_mutation_integration_test.dart \
  test/dav/mutation/dav_pending_operations_test.dart \
  test/dav/ical/ical_task_recurrence_test.dart \
  test/features/tasks/presentation/ical_task_fields_editor_test.dart
```

After the added draft/Fluent coverage and R-DAV01 correction, focused follow-ups
passed **5** DAV draft/checkbox tests, **26** draft/Linux recurrence/Windows
recurrence tests, and **1** Windows duration-validation test:

```sh
flutter test test/dav/mutation/dav_repository_mutation_integration_test.dart --name 'a projected start-only DAV task|DAV editor saves|checkbox' --reporter expanded
flutter test test/features/tasks/presentation/task_details_draft_test.dart test/features/tasks/presentation/ical_task_fields_editor_test.dart test/platform/windows/windows_existing_task_recurrence_test.dart --concurrency=2 --reporter expanded
flutter test test/platform/windows/windows_existing_task_recurrence_test.dart --plain-name 'Windows duration validation' --reporter expanded
```

A focused `dart analyze` of the modified DAV/recurrence production and test files
reported no issues after fixing test-only finder/lint mistakes. The later
coordinated full-check result is recorded in the main lifecycle ledger.

Linux creation follow-up passed **4** production UI tests:

```sh
flutter test test/features/tasks/presentation/new_task_loading_test.dart --reporter expanded
dart analyze test/features/tasks/presentation/new_task_loading_test.dart
```

The stream fixture controls waiting, initial errors, empty results, cached errors
and successful Retry; Save uses the actual repository and SQLite outbox. It
checks exact dirty title/notes, selected destination, account/list changes via
the production native-menu bridge, Escape confirmation/cancellation and exactly
one durable task/operation with correct ownership. Initial loading/empty queues
nothing. The final analyzer result has no issues.

A final F03 public-hierarchy check found the same resource/master distinction
still missing from `watchTaskHierarchy`: the parent details exposed three
detached history projections as child actions, and a grandchild resolved its
parent to the alphabetically first history row. Two real-database regressions
failed before the correction and passed after restricting only actionable
parent/child/has-children lookups to masters. The ordinary All projection and
all three stored history rows remain unchanged; no operation is queued. Cycle
validation already receives the master-only SQL result from `_davParent`.

```sh
flutter test test/dav/mutation/dav_repository_mutation_integration_test.dart --plain-name 'actionable hierarchy resolves masters' --reporter expanded
```

The initial desktop checkbox suite passed **2** production-path widget tests,
one using the actual Linux Schedule workspace Yaru root/child checkboxes and
one using the actual Windows task-page Fluent root/child checkboxes. Each uses
SQLite, the production repository/outbox and a stateful conditional DAV fake.
Root completion completes P/C, child reopening reopens P/C, and root reopening
after an explicit status completion leaves its open child uncancelled. Explicit
cancellation remains separate. Every phase checks the pending candidates, local
rows, acknowledged provider state and empty reconciled outbox; each fixture
performs eight conditional provider writes. Isolated original HEAD workspace
and Windows-page copies compiled from `/tmp` both failed at root completion,
where the child remained open. Working production sources were never swapped.

```sh
flutter test test/features/tasks/presentation/desktop_dav_completion_test.dart --reporter expanded
dart analyze test/features/tasks/presentation/desktop_dav_completion_test.dart test/features/tasks/presentation/new_task_loading_test.dart lib/src/features/tasks/data/tasks_repository.dart test/dav/mutation/dav_repository_mutation_integration_test.dart
```

Final focused analysis reported no issues. Formatting verification of the 12
DAV/recurrence source and test files reported zero changes; `git diff --check`
for the final hierarchy and desktop/loading additions was clean. The separate
coordinated full offline/native check results remain in the main ledger.

The final F02 integration follow-up expanded the desktop file to **8 passing
tests**. It preserves the existing Windows details combined status/progress
behavior for explicit Completed, Needs action and Cancelled selections, and
checks the details checkbox completion/reopening separately. A completed parent
changed through the explicit In progress selector must retain 1% progress; an
actual pointer tap at the percentage slider midpoint must retain 50%. Inferring
checkbox intent merely from a changed completed boolean had replaced both with
0%, saving Needs action. The In progress regression failed against the working
implementation before correction, while the isolated original HEAD dialog
passed. The repair tracks intent only from the checkbox and clears it for
explicit status/progress changes, without changing repository status semantics.

The original HEAD dialog passed all **5** status/progress controls, establishing
the negative control against an invented status-only UI contract. The complete
final desktop command is the same file command above; its result is **8/8**.
For the slider's executable before control after source freeze, an isolated
copy of the final dialog restored only the former inferred `completionIntent`
argument; both In progress and pointer-slider cases failed with Needs action.
No working source was swapped. Final test-file analysis reported no issues,
and formatting checks for the dialog and regression file required no changes.

For an executable before control without disturbing native acceptance, the
original HEAD `new_task_dialog.dart` was compiled from `/tmp`, with relative
imports resolved to their existing package targets. Its isolated widget suite
failed the initial-waiting indication and initial-error Retry cases, while the
cached-error mounted-editor case passed. No production sources were swapped.

The suite retains existing cases for exhausted UNTIL, final COUNT and reusing
final history on reopening/recompletion, opaque recurrence, detached history
protection, exact ETags, conditional mutation, shared-calendar restrictions,
unknown siblings and notification projection. Account/notification policy and
Nextcloud provider trash/restore were not redesigned.

No native Windows/Android UI acceptance or live Nextcloud mutation was run by
this work item. Live verification still requires the explicitly opted-in
disposable server/accounts and actual server/Calendar/Tasks versions described
in [development.md](../development.md#live-provider-tests). Reference behavior
was checked against the versioned [tasks.js](https://github.com/nextcloud/tasks/blob/v0.18.1/src/store/tasks.js)
and [storeHelper.js](https://github.com/nextcloud/tasks/blob/v0.18.1/src/store/storeHelper.js).
Duration relationships follow [RFC 5545 section 3.6.2](https://www.rfc-editor.org/rfc/rfc5545#section-3.6.2).
