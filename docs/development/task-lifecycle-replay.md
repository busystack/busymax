# Task lifecycle replay and recovery validation

Validated against the current checkout on 2026-10-22, using Flutter 3.47.5 and
its bundled Dart 3.13.4. This is the replay/recovery portion of the task lifecycle
ledger. Native interaction and live-provider mutation were not run here.
Fixtures use real Drift/SQLite databases and mutable provider state; restart
cases close and reopen a file-backed database. Logs remain outside Git.

| ID | Disposition | Verified path and causal evidence | Repair and regression evidence |
|---|---|---|---|
| F01 | Confirmed | `TasksRepository.moveTask` optimistically moves the row; `TaskListsRepository.deleteTaskList` previously chained only list mutations. With the list newer than the task, a rejected or deferred move left the task remotely in the source while deletion was dispatched. Before repair, three tests applied the deletion or overtook a remaining move. | List deletion captures every unfinished operation touching source/destination and complete child snapshots. Replay checks both captured and newly queued operations, including blocked/future retries, and checks again after provider preflight reads. Stateful tests retain the optimistic destination and queued intent for rejected/deferred moves, multiple moves with partial success, successful moves followed by deletion, a genuine changed child, and file-backed restart. Full membership reads replace the former timestamp-only assertion; the unchanged/changed-child controls remain. |
| F05 | Blocked by endpoint-specific external evidence | Both queued PATCH and reachable PUT perform a conflict GET before an unconditional write. The exact Google Tasks method references do not establish a conditional-write enforcement contract; the performance guide's conditional example uses a fictional Demo resource. | No unsupported If-Match contract, wildcard, repeated-GET atomicity claim, or fallback was added. Required next action: obtain authoritative Tasks endpoint evidence, or explicitly enable a disposable Google QA task and verify correct/stale revisions at the actual PATCH and reachable PUT endpoints. Only then can a checked revision be required across the interface/transport and a 412 reconciliation test claim provider enforcement. |
| F06 | Confirmed | Microsoft checklist update/delete originally mutated without comparing the observed item with the provider. The initial tests issued no supported checklist reads. | The repository captures the original item; replay reads all provider pages, compares only update fields and the original semantic item for deletion, retains conflicts, and treats missing updates as conflicts and an already-missing deletion as satisfied. Tests cover rename/rename, delete/remote edit, completion/independent rename, remote deletion, independent sibling edits, pending create/edit identity acknowledgment and restart. Successful acknowledgment rebases only touched checklist fields and overlays later pending intent. |
| F07 | Confirmed, coordinated with editor/repository repairs | Creation acknowledgment replaces the temporary task row and rewrites queued references. An active editor still holds the temporary ID. | The same transaction records the exact old ID in `_busymaxTaskIdAliases`, preserving local aliases and acknowledged provider metadata. Repository/editor consumers resolve only verified, account/list-scoped aliases. Existing task creation/restart/notification-target tests exercise the replayer side; platform/editor evidence belongs to the main lifecycle ledger. |
| F12 | Confirmed | Selective ordinary patch discard refreshed the complete row and removed only the selected operation. Before repair, retained local notes Q became remote R and a later local list rename Q became Remote B. Queued bytes survived. | Recovery refreshes the provider baseline and overlays surviving intent atomically with selected removal. Remaining comparison snapshots remain byte-for-byte unchanged. Six regressions verify notes conflict retention, SQLite close/reopen and explicit successful retry, completion/move/delete flags and payloads, and list-rename recovery. Existing checklist discard uses its established separate overlay path. |
| F13 | Confirmed | A stateful provider commits title/notes clearing, advances its revision, and then throws after committing. Before repair, retry applied zero operations and blocked its own result. | A sent PATCH/PUT records `in_progress` before dispatch. On retry, provider-normalized intended fields can establish the postcondition; acknowledgment, dependent field rebasing, projection and removal commit together. Tests cover title, explicit clearing, a dependent notes edit after file-backed restart, genuine unrelated remote notes conflicts, ordinary completion and no duplicate remote mutation. First-attempt matching values still follow ordinary conflict checks. An unknown recurring completion remains `recovery_required`; automatic and manual Retry cannot advance an unproved occurrence again. Resolve the specific provider occurrence before discarding that retained operation. |
| F14 | Confirmed; residual provider race qualified | Offline completion retained the old revision; Clear completed captured it, then mistook the acknowledged completion's new timestamp for an independent edit. Before repair, completion applied but clear did not. | Clear captures the approved completed-task set and unfinished operations. Only acknowledged captured writes rebase the approved snapshots. Replay waits for all relevant mutations and verifies the exact completed set and original unaffected fields using complete provider reads, then uses Google's existing clear/hide endpoint. Tests cover one/several completions, deferred completion across SQLite restart, reopen before replay, reopen during provider preflight, and a new unrelated remote completion. A genuinely changed/new set blocks the clear. |

The initial fail-before commands were:

```bash
flutter test test/features/sync/pending_ops_replayer_test.dart --plain-name F01 --reporter=expanded
flutter test test/features/sync/pending_ops_replayer_test.dart --plain-name F06 --reporter=expanded
flutter test test/features/sync/pending_op_resolution_service_test.dart --plain-name F12 --reporter=expanded
flutter test test/features/sync/pending_ops_replayer_test.dart --plain-name F13 --reporter=expanded
flutter test test/features/sync/pending_ops_replayer_test.dart --plain-name F14 --reporter=expanded
```

F01 failed all three original cases, F06 failed all four original cases because
no reads occurred, F12 failed both original retained-projection cases, F13 failed
both original unknown-response acknowledgment cases, and F14 failed the
own-completion case while its unrelated remote-completion control passed.
Subsequent focused runs passed the added restart and negative controls.

Affected-suite verification:

```bash
flutter test test/features/sync/pending_ops_replayer_test.dart \
  test/features/sync/pending_op_resolution_service_test.dart \
  test/features/task_lists/data/task_lists_repository_test.dart \
  --concurrency=2 --reporter=expanded
dart analyze lib/src/features/sync/pending_ops_replayer.dart \
  lib/src/features/sync/pending_op_resolution_service.dart \
  lib/src/features/sync/task_mutation_barrier.dart \
  lib/src/features/sync/conflict_detector.dart \
  lib/src/features/task_lists/data/task_lists_repository.dart \
  test/features/sync/pending_ops_replayer_test.dart \
  test/features/sync/pending_op_resolution_service_test.dart
```

These commands use `/home/albert/flutter/bin/flutter` and its bundled Dart.
SDK-cache writes required the host's standard escalation; dependency pins were
unchanged. The affected replay/recovery/list run passed **179 tests**. The
targeted analyzer reported no issues. After that run, four focused stateful
Microsoft adapter regressions passed (notes, reopening, completion and due), and the existing
Microsoft task adapter suite passed **10 tests**.
The final combined replayer/Microsoft-adapter run, including all four new
adapter-normalization cases, passed **140 tests**.

The additional F13 Microsoft checks reproduced acknowledgment failures for
shared `needsAction` reopening versus Graph's native `notStarted`, and for the
shared completion instant versus Graph's `completedDateTime` resource. The
adapter normalizes the reopening alias and completion instant through the
existing provider-time converter; native `inProgress`, `deferred` and other
statuses remain distinct. Fail-before tests applied zero operations on retry;
afterward notes, reopening, completion with normalized fractional precision,
and due edits acknowledge one provider mutation without resending. These are
directly related normalization repairs.

Supplemental F17–F19 production-projection coverage in
`test/schedule/task_lifecycle_projection_test.dart` passed **6 tests** using
SQLite, the actual schedule/task repositories, parsed DAV resources and rendered
agenda rows. These verify stateful Move to top acknowledgment and restart,
child promotion, numeric DAV sibling ordering, multiple account/list scopes and
comparator transitivity, unchanged calendar chronology, actual-deadline
pagination/search/agenda parity, and imported/local cancellation with reopening.
These are headless widget tests; they do not establish native window behavior.

Provider and native boundaries:

- Google's [PATCH](https://developers.google.com/workspace/tasks/reference/rest/v1/tasks/patch),
  [PUT](https://developers.google.com/workspace/tasks/reference/rest/v1/tasks/update)
  and [Task resource](https://developers.google.com/workspace/tasks/reference/rest/v1/tasks)
  references were read. The [performance guide](https://developers.google.com/workspace/tasks/performance)
  demonstrates If-Match on Demo; it is insufficient evidence of Tasks enforcement.
- [tasks.clear](https://developers.google.com/workspace/tasks/reference/rest/v1/tasks/clear)
  accepts an empty body and hides every completed item. A task completed remotely
  after the final check can still be included in that provider-wide operation;
  no atomic selective clear or conditional-clear support is claimed. The client
  repair prevents its own acknowledged writes from falsely conflicting and
  blocks unrelated completed-set changes already observed before dispatch.
- Microsoft documents the supported [checklist collection read](https://learn.microsoft.com/en-us/graph/api/todotask-list-checklistitems?view=graph-rest-1.0)
  and [partial update](https://learn.microsoft.com/en-us/graph/api/checklistitem-update?view=graph-rest-1.0).
  The read/compare repair does not establish conditional Graph writes or eliminate
  the final provider read/write window.
- No disposable Google/Microsoft QA mutation fixture was enabled, and no native
  Linux/Windows/Android task acceptance was performed in this portion. Provider
  and server versions therefore cannot be reported as tested here. Required
  follow-up is the explicit QA/native acceptance in `docs/development.md` and the
  main lifecycle ledger, without exposing credentials or personal task content.

The replayer/recovery changes preserve task-provider models, approved account
and notification policy, existing notification identities, and Nextcloud's
documented F10 compatibility choice. They introduce no recurrence rewrite,
cross-list Microsoft support, duplication feature, or universal undo system.

Related integration correction found during bounded F04/F11 review:

- Windows details loaded the current task row for its edit baseline, but initialized
  its completion checkbox from the potentially older schedule item passed to the
  dialog. A Google fixture with a completed current row and an open schedule
  snapshot, followed by a title-only Save, reproduced an unintended reopening:
  the real local row became `needsAction` and a completion mutation was queued.
  The matching completed schedule snapshot was the negative control and passed.
- Initialize completion from the loaded task, consistently with the remaining
  observed draft. `test/platform/windows/windows_task_observed_completion_test.dart`
  exercises the actual Fluent dialog, repository and SQLite row/outbox for Google
  and Microsoft. It verifies the title changes while completion and the
  title-only pending payload remain unchanged, for stale and matching snapshots.
  This is a directly related correctness repair, not a new completion policy.
- The possible alias DAO read/write interleaving was not established on reachable
  refresh, import and creation acknowledgment paths, which use transactions; it
  was not treated as a confirmed defect or repaired. No other concrete data-loss,
  baseline, identity or partial-commit issue was reproduced in this bounded
  independent review. These conclusions do not substitute for native acceptance.

The Windows integration correction's final command was
`flutter test test/platform/windows/windows_task_observed_completion_test.dart --concurrency=1 --reporter=expanded`:
**4 passed**. The initial production-path reproduction had one failing stale
Google case and one passing matching-state negative control. Test-harness
iterations corrected SQLite stream disposal before the final passing run;
those failures were not attributed to provider or application behavior.

## Follow-up replay validation: R05, R06 and R08

The follow-up was revalidated against the current clean committed baseline on
2026-10-22 with the same pinned Flutter 3.47.5 / bundled Dart 3.13.4 and shared
locked dependencies. The original F/U ledger entries remain recorded; this section corrects the
narrower composition gaps found during the follow-up.
The tests below use production repositories/replay, real SQLite, durable
file-backed restart fixtures, and mutable provider state. A fake's supported
read behavior is not evidence of provider conditional writes or native delivery.

| ID | Disposition | Reachable reproduction and controls | Correction and executable evidence |
|---|---|---|---|
| R05 | Confirmed | Queue title A→B and dependent notes N→L. The provider commits B and loses the response. A later reconciliation GET fails with `RequestNotDispatchedException`; the old handler reset PATCH/PUT to `retry`, erasing the earlier write's durable uncertainty. Four initial PATCH/PUT cases failed because the retained state became `retry`; the first genuinely unsent mutation control passed. | Preserve an existing `in_progress` marker across an unsent reconciliation read and scheduling/manual Retry. A first mutation prevented from dispatch remains safely retryable. After file close/reopen and explicit Retry, the intended postcondition acknowledges one title mutation and permits the dependent notes mutation. A value different from baseline and desired still conflicts and retains both local intents. A recurring-completion control retains `recovery_required` protection after an unsent read; it does not demonstrate provider occurrence advancement.  This established the unsent-read path only; see [S02](#synchronization-follow-up-s01-and-s02) for a dispatched HTTP rejection. |
| R06 | Confirmed | Actual `MicrosoftTodoTaskRemoteClient` over a stateful Graph checklist interface commits rename/check/uncheck, then loses its response. Before repair, all nine valid initial cases observed one provider mutation but no durable dispatched marker (`pending` remained). The fixture also fails a later second-page reconciliation read and closes/reopens SQLite. | Mark the item update immediately before dispatch. Supported paginated reads may establish only that item's requested, adapter-normalized fields. Use the same transaction for acknowledgment, field-scoped dependent baseline updates, visible projection overlay and operation removal. Rename/check/uncheck each cover normal dependent progress, an independently changed untouched field that must still conflict, a missing remote item, and sibling independence. The acknowledgment-commit barrier opens a second database connection and verifies exact dependent baseline, retained visible completion, one rename and one dependent check. Existing temporary-create/alias and uncertain-create protections remain covered by the affected suite. No Graph atomic-write contract is claimed. |
| R08 | Confirmed | All three offline compositions reproduced: clear→list deletion conflicted with its own hidden flag; child deletion→list deletion misclassified returned Google tombstones as live membership; completed move A→B→clear B did not rebase the destination clear. Six initial deferred/blocked restart variants applied only the predecessor (1 instead of 2). External notes, new live child and new completed-task controls blocked destruction. | Rebase only approved hidden effects, captured move fields/membership and their acknowledged revisions. Read all pages with the existing Google flags; exclude true deletion tombstones from live membership while unexpected missing/live members still conflict. A clear's empty response establishes hidden=true, so its narrow durable marker explains a revision advance only when the complete approved semantic snapshot still matches. It never replaces untouched fields. Source/destination clear handling requires the captured move and never adds absent approved members. Predecessor acknowledgment, dependent snapshots, local projection and operation removal commit together. Three commit barriers inspect these states from a second SQLite connection before permitting the remaining destructive operation. |

Two directly related R08 defects were verified and recorded separately:

- **Clear already acknowledged before list deletion is queued:** the local
  hidden flag had changed but `rawJson` still said hidden=false. The control
  without external edits failed (0 instead of 1 list deletion); the external
  notes control remained blocked. Successful clear now records only its known
  hidden effect in local raw/metadata. Later list-deletion snapshots carry that
  effect while keeping every original notes/status field. A fresh provider
  import replaces this local explanation with its actual provider revision.
- **Incoming move response replaced an existing destination deletion snapshot:**
  an independent notes N→R arriving in the move response was copied wholesale
  into a previously approved child baseline. The regression observed both move
  and list deletion succeeding (2 instead of the expected 1), destroying the
  changed remote child; the unchanged control passed. Initialization now occurs
  only when no approved child snapshot exists. Existing snapshots rebase the
  acknowledged move fields and retain notes N, so remote R blocks deletion.

Valid fail-before commands and outcomes:

```bash
flutter test test/features/sync/pending_ops_replayer_test.dart --plain-name R0 --concurrency=1 --reporter=expanded
flutter test test/features/sync/pending_ops_replayer_test.dart --plain-name R06 --concurrency=1 --reporter=expanded
flutter test test/features/sync/pending_ops_replayer_test.dart --plain-name 'R08 related' --concurrency=1 --reporter=expanded
flutter test test/features/sync/pending_ops_replayer_test.dart --plain-name 'R08 related incoming' --concurrency=1 --reporter=expanded
```

The first combined command reproduced the four R05 and six R08 failures;
checklist fixture setup was then corrected to implement the adapter's explicit
`MicrosoftTodoChecklistApiClient` interface, and the separate R06 command
reproduced all nine missing-dispatch-marker failures after an actual provider
commit. The related-clear command had one failing unchanged-state case and one
passing remote-notes control. The related-incoming command had one failing
remote-notes case and one passing unchanged control. A matcher import ambiguity
and test-name filter typo were harness issues, not application/provider results.
No production sources were swapped for these checks.

Passing focused commands:

```bash
flutter test test/features/sync/pending_ops_replayer_test.dart --name 'R05|R06' --concurrency=1 --reporter=expanded
flutter test test/features/sync/pending_ops_replayer_test.dart --plain-name R08 --concurrency=1 --reporter=expanded
flutter test test/features/sync/pending_ops_replayer_test.dart --plain-name R0 --concurrency=1 --reporter=expanded
flutter test test/features/sync/pending_ops_replayer_test.dart --name 'R08 Google.*commits predecessor' --concurrency=1 --reporter=expanded
```

These passed 14, 9, 28 and 3 cases respectively as coverage was added. The final
full affected run follows the last incoming-move correction, so its result is
the final integration count, rather than a sum of those overlapping focused runs:

```bash
flutter test test/features/sync/pending_ops_replayer_test.dart \
  test/features/sync/pending_op_resolution_service_test.dart \
  test/features/task_lists/data/task_lists_repository_test.dart \
  test/microsoft_todo/api/microsoft_todo_task_remote_client_test.dart \
  --concurrency=2 --reporter=expanded
dart analyze lib/src/features/sync/pending_ops_replayer.dart \
  lib/src/features/sync/task_mutation_barrier.dart \
  lib/src/features/task_lists/data/task_lists_repository.dart \
  test/features/sync/pending_ops_replayer_test.dart
```

The final affected run passed **226 tests**. Targeted analysis reported
**No issues found**, the owned Dart format check made **0 changes**, and
`git diff --check` found no whitespace errors. Logs remain in `/tmp`.
No existing regression was removed, weakened, or made to pass by erasing pending
payloads. No live Google/Microsoft credentials or provider mutations were used
in this portion, and no native host acceptance was run here.

The official [tasks.list endpoint](https://developers.google.com/workspace/tasks/reference/rest/v1/tasks/list)
was read for pagination and `showDeleted`/`showHidden` behavior, and the official
[tasks.clear endpoint](https://developers.google.com/workspace/tasks/reference/rest/v1/tasks/clear)
for its existing all-completed hide operation and empty response. Google still
has the documented preflight/clear race: another task can complete after the
last read. F05 remains blocked on exact Tasks conditional-write evidence or an
explicit disposable QA endpoint test; no If-Match fallback or atomicity claim
was added. Microsoft checklist read/compare has the previously documented final
read/write window. F10 remains withdrawn from automatic repair, and the pinned
Nextcloud recurrence, account and notification policies remain unchanged.

## Synchronization follow-up S01 and S02

These findings were reproduced against unchanged production source at
`6bc44e5` on 2026-10-23, before either repair. Only test source had changed for
the before runs. The historical F/U/R evidence above remains intact; the R07
identity result did not establish parent cleanliness after all acknowledgments,
and R05's earlier failure injection established only an unsent read.

### S01: checklist identity dependency versus parent fields

Reachable path: `TasksRepository.createTask` → `createSubtask` → dependent
checklist create/edit → parent acknowledgment in `_replaceLocalTaskId` →
checklist acknowledgment → ordinary `SyncEngine.fullSync`/incremental pull.
The existing R07 after-enqueue case now additionally checks parent cleanliness.
Before repair it had an empty outbox and correct parent/step identities, but
`localDirty == true`. The new disk-backed stateful provider test changed the
remote parent title/deadline/completion and ran the actual SyncEngine; its
first full pull still showed `Parent` rather than `Remote title`.

`_rebaseDependentTaskMutations` previously counted checklist-only identity
dependents as parent mutations. It now traverses the same identity/dependency
chains but filters the parent-field protection/rebase set to task entities.
`_mutatesSameTask` itself and all identity/location callers remain intact:
`_applyTaskEditResult` and `_replaceLocalTaskId` use the narrower result;
`_moveTask` keeps real task dependents protected; `_dependentTaskProjectionListId`
still follows the original identity chain. Checklist references and temporary
aliases are rewritten by the existing acknowledgment transaction. No
unconditional dirty-flag cleanup was added to checklist acknowledgment.

The stateful fake reflects every successful parent/step write and implements
ordinary list/task reads plus paginated checklist reads. It proves exactly one
parent creation and one step creation. A barrier after step-create acknowledgment
but before the dependent step PATCH inspects the persisted server IDs, original
item baseline, exact retained rename, alias and parent flag. The item edit then
replays successfully. A genuine deferred parent title edit remains dirty and
visible through checklist acknowledgment and an ordinary pull; actual
resolution-service Retry replays it once and imports independent remote notes.
The clean parent subsequently imports title, due and completion changes via a
full pull, a full pull after file-database close/reopen and the Microsoft
full-refresh incremental path. The temporary task and checklist aliases survive.
A further real pending parent deletion remains dirty/pending with its exact
operation intact while checklist PATCH succeeds and a normal pull runs. This
negative control deliberately retains the pending deletion; it does not erase
it to produce a clean flag. Existing task move/delete and R07 scope/dependency
controls remain in the affected suites.

The ack-before-read and read-delivery-barrier controls still pass. The original
bug was recoverable through explicit refresh or a later acknowledged parent edit;
it did not physically delete the local draft or provider data.

### S02: dispatched reconciliation rejection retains write evidence

Reachable path: repository PATCH/PUT → stateful provider commits then loses its
response → GET returns decoded non-quota `GoogleTasksApiError` HTTP 403 →
`_blockOp` → restored account eligibility → actual
`PendingOpResolutionService.retryNow` → file-database restart → replay.
Before repair all four ordinary PATCH/PUT success/divergence variants and both
recurring variants lost `in_progress` and became `failed` at the rejected read.
The Graph checklist rename/check/uncheck negative controls already retained it.

`_blockOp` now preserves an existing `in_progress` task-write marker while
recording the same useful 403 message/code, incremented attempt and blocked
schedule. Retry and restart retain that marker through the existing persistence
model; no schema, scheduling, account or provider-precondition change was needed.
A first definitively rejected task mutation still becomes `failed`, as before.

The tests inspect the blocked operation, original payload/baseline, projection,
account eligibility gate, real Retry callback, file-database restart, provider
state and field-specific writes. They count one title write plus the distinct
dependent notes write; remote C retains both local intents and conflicts.
Definitive first-write rejection controls either retry safely against unchanged
A or retain a genuine conflict when another client independently supplied B.
The existing KnownUnsentRequestException controls remain. Unknown recurring
PATCH/PUT completion reaches `recovery_required` after the failed read/Retry and
cannot be retried/resubmitted; no provider occurrence advancement is claimed by
that fake. The actual Microsoft adapter's paginated checklist controls decode a
Graph 403 and still acknowledge one already-applied item write, rebase only its
touched fields, and permit the separate dependent item edit.
Here PATCH/PUT identify the two queued task mutation forms. The Microsoft
adapter maps both task-edit interfaces to Graph PATCH; no Graph PUT capability
or live provider recurrence behavior is inferred from these tests.

### Commands and results

Commands below use `/home/albert/flutter/bin/flutter` and that installation's
bundled `dart`. Per-run logs remain in `/tmp` without credentials or personal
task content.

```sh
flutter test test/features/tasks/data/checklist_creation_identity_test.dart test/features/sync/pending_ops_replayer_test.dart --name 'S01|S02|R07' --concurrency=1 --reporter=expanded
flutter test test/features/tasks/data/checklist_creation_identity_test.dart test/features/sync/pending_ops_replayer_test.dart --name 'S01|S02|R07|R05' --concurrency=1 --reporter=expanded
flutter test test/features/tasks/data/checklist_creation_identity_test.dart test/features/sync/pending_ops_replayer_test.dart test/features/sync/sync_engine_test.dart test/features/sync/pending_op_resolution_service_test.dart --concurrency=2 --reporter=expanded
```

The final valid before command returned exit 1 with **11 passed, 8 failed**.
Its first smaller iteration returned **6 passed, 7 failed**; one extra failure
was the fixture's use of `9999-12-31` for a parent patch. Identity acknowledgment
correctly unblocked that sentinel, so an ordinary future retry date was used to
hold real pending work instead. That control then passed on unchanged code.
The focused after command passed **25**. The affected command passed **249**;
the final controlled-barrier cleanup and adapter-decoded Graph error were also
run in the final affected command. Targeted analysis reported no issues.
No existing protective assertion or queued payload was removed to pass.

Preparation used the SDK checker, pinned shared-checkout verifier,
`flutter pub get --enforce-lockfile`, `flutter gen-l10n` and
`dart run build_runner build --delete-conflicting-outputs --force-jit`.
Fresh generated-source verification and normal offline checks are recorded in
the central S01/S02 ledger. No native or live-provider pass is claimed for this
follow-up. F05 remains blocked; F10 and all documented provider/account/
notification boundaries, including both check/write windows, remain unchanged.

Final S01/S02 normal checks passed: `dart format --output=none
--set-exit-if-changed .` (**950 files, zero changes**), `flutter analyze`
(**no issues**), `dart run tool/check_platform_boundaries.dart`, and a freshly
created `/tmp/busymax-s01-s02-generated-20261023.json` snapshot → localization/
build-runner regeneration → verification, without a generated diff. The final
`flutter test --concurrency=2 --reporter=expanded` run passed **4,266 tests**
with **10 existing provider-gated skips**, no failures, exit 0 in **10:10**.
These are new executions, not the earlier F/U/R totals. The final four affected
suites passed **249** in 0:06 after the final harness/error-decoding controls.
Production and regression-source hashes were unchanged during the aggregate.
