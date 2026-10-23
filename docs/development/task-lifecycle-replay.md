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
