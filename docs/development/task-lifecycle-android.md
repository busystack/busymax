# Android task lifecycle validation

This ledger covers the Android paths changed with the task lifecycle repair.
The shared repository, replay, DAV, Linux, and Windows findings are tracked by
the main task lifecycle ledger. All fixtures used here contain synthetic data.
No Android device or live provider mutation is claimed by these widget tests.

| ID | Android disposition and reachable path | Reproduction, control, and resulting coverage |
| --- | --- | --- |
| F02 | Confirmed: Tasks root checkbox and editor subtask checkbox. | Original Android source completed a DAV parent while leaving its child open. Both checkbox callers now carry completion intent; DAV translates that intent to percentage 100/0. A real DAV projection/outbox test completes both resources, then reopens the child and its ancestor without cancellation. It checks coalesced resource operations contain `[100, 0]`; percentage zero removes the wire property and projects as null. Explicit status/cancellation and recurrence semantics remain repository concerns and were not replaced. Google/Microsoft retain Android's original status-only payload. |
| F04 | Confirmed: editor Save into the real repository/outbox. | A local title draft over an unseen local database update is rejected, preserving the draft and current row with no new operation. An independent remote notes edit survives a title save. The original observed snapshot crosses the Save boundary. Existing server-version/discard conventions allow explicit current-state reload, cancellation retains recovery, and a subsequent edit uses the reviewed baseline. |
| F07 | Confirmed: active editor and recovery identity after create acknowledgement. | Gate a stateful create, edit the temporary task, acknowledge creation, then save title/notes. The server ID appears in the queued patch and provider request; the draft remains open until Save. A restart test reads recovery through verified identity aliases and removes both applicable recovery keys after successful save. Arbitrary absent IDs are not redirected. |
| F08 | Confirmed: editor inputs, picker results, hierarchy actions, Back, and Save. | With the barrier after repository argument capture, original inputs stayed enabled. Repaired controls remain disabled until persistence finishes; a late date picker result cannot alter the submitted draft. A failed save restores controls and preserves exact notes/recovery; one retry produces one operation. Existing Android Back/dirty-close tests pass. |
| F09 | Confirmed: current schema-v2 recovery restore/persist/cleanup. | Original source did not offer Restore after the same task's title/list changed. Snapshot-backed recovery now retains local notes, preserves an unrelated current title/location, and retains the original comparison on a same-field notes conflict. Verified acknowledgement aliases work after restart. Current v2 records lacking an exact field snapshot remain recoverable and review-only: Save queues nothing, original base title/content remain, and no fabricated baseline is persisted. Explicit discard/current reload remains available. Schema/account/identity/expiration checks are retained. |
| F11 | Confirmed integration: Save followed by cross-list move. | A real patch commits, an independent untouched field changes, and move fails. The editor reports the saved-edit/failed-move outcome, rebuilds its baseline from the committed projection, retains the remaining destination, and retry queues only the move. The outbox contains exactly one patch and one move; current unrelated notes are retained. Notification auxiliary-failure handling is implemented and covered in the shared repository work. |
| F15 | Confirmed Android subset: private task recurrence dialog. | Original unchanged Save changed a 09:00 UTC UNTIL to midnight. The task editor uses the full effective due/start reference, temporal kind, and zone. Tests cover unchanged exact rules, UTC due/start and date-only endings, and an existing cutoff displayed in America/Vancouver. RDATE/EXDATE forms were verified as already protected by the codec; unrelated notes edits retain them exactly. No ancillary-date-loss repair or new editable recurrence form was introduced. |
| F16 | Confirmed shared repair; Android feedback integration. | The shared duration validation error maps to the localized deadline-before-start-removal explanation. Save retains the draft. Candidate/resource/outbox validation is covered by the shared DAV suites; no server acceptance is claimed here. |
| F19 | Shared projection integration. | Android displays the retained cancelled state in All. Open/Overdue eligibility is controlled by the repaired shared query/projection contract; cancelled tasks remain distinct from completed tasks. |
| F20 | Confirmed: Android editor Save/validation. | Original empty-title Save returned silently. Blank title, visible invalid URL, deadline-before-start, and mixed date/time modes now show localized feedback and reveal the first invalid field. Values remain and no operation is queued. Correcting the title saves once. Hidden unsupported Google fields do not prevent a title save. The existing past-reminder feedback remains. |
| U01 | Confirmed missing confirmation: selected-list Clear completed. | Both provider confirmations identify account/list and show the logical count. Google describes clear/hide; Nextcloud describes closed root trees and descendant deletion. Tests use real count logic, including multiple history projections, and prove cancellation queues nothing. Google confirmation queues the existing clear operation. Provider trash/restore is unchanged. |
| U02 | Confirmed missing parity: Microsoft checklist row menu. | Rename and confirmed deletion use the existing checklist repository operations, observed item snapshots, busy states, and retained-error conventions. Stateful paginated replay tests cover rename/rename conflict, delete/remote-edit conflict, completion/remote-rename merge, sibling preservation, cancel, rename failure/retry, and pending-create → rename → server identity acknowledgement. Checklist steps remain checklist items. |
| U04 | Confirmed Android error presentation. | An initial task-query failure shows localized Retry rather than raw error text or an empty-state claim. A later failure retains cached tasks, query, and selected list; Retry recovers. Task-list loading/error state does not reset a selected filter merely because a request failed. Linux creation/details and Windows loading behavior are outside this Android ledger. |

## Executed checks

The repository's pinned Flutter 3.47.5 / bundled Dart 3.13.4 toolchain and locked
shared dependencies were used. Shared setup and generated localization were
run by the coordinating agent. All new strings were added through ARB inputs
in the existing supported catalogs; the generic Portuguese ARB remains the
locale-only generation stub and European Portuguese uses `app_pt_PT.arb`.
Generated localization was regenerated, not edited manually.

- `flutter test test/platform/android/android_adaptive_app_test.dart --reporter=expanded`
  passed all 83 tests after the main repairs, including existing Back/dirty
  guards. The final status-only cloud payload regressions were added afterward
  and run with the focused checkbox command below.
- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'Android explains|Android task recurrence dates|Android recovery without|Android Nextcloud root' --reporter=expanded`
  passed 6 focused tests after the final validation/recovery corrections.
- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'checkbox retains|Android Nextcloud root' --reporter=expanded`
  passed all 3 tests, proving exact status-only Google/Microsoft payloads and
  the percentage-based Nextcloud hierarchy after the shared factory adjustment.
- `dart analyze lib/src/android/presentation/android_tasks_screen.dart test/platform/android/android_adaptive_app_test.dart`
  reported no issues after correcting scoped style/context diagnostics.
- `dart format lib/src/android/presentation/android_tasks_screen.dart test/platform/android/android_adaptive_app_test.dart`
  and scoped `git diff --check` completed successfully.
- `flutter gen-l10n` followed by the unchanged
  `flutter test test/app/localization_audit_test.dart --reporter=expanded`
  passed all 36 original audit tests after catalog corrections. The audit had caught
  three input issues: entries in the generic Portuguese stub, ordinary French
  spaces around quotation/punctuation, and missing RTL placeholder isolation.
  The ARB inputs were corrected without changing the audit.
- Two durable regressions were then added to the existing localization audit
  for the new confirmation methods, bringing the audit to 38 tests without
  altering its original checks or exemptions.
  `flutter test test/app/localization_audit_test.dart --name 'clear-completed (Persian|Arabic) confirmations' --reporter=expanded`
  passed both new cases. Arabic/Persian names and counts use FSI/PDI isolation.
  Persian count metadata uses the established `decimalPattern` formatter and
  the generated output contains Persian digits. An earlier ignored synthetic
  probe also passed both cases before they were promoted to the audit.

Behavioral failing-before runs temporarily selected only the original Android
source and restored the repaired source automatically afterward. Original
source failed the new F02 hierarchy, F08 post-submission locking, F09 recovery,
F15 unchanged-UNTIL, F20 title feedback, U01 confirmation, and U04 Retry checks.
The attempted additional recurrence-date-loss hypothesis was rejected:
RDATE/EXDATE editing is unreachable because those forms are already read-only.
Its replacement is a preservation negative control, not a claimed repair.

Fixture mistakes corrected during validation were an invalid credential-kind
seed, an incorrect task-list ID for DAV projection, assumed nested task patch
JSON, and assuming blocked operations use a separate state. Existing conflict
convention is `state=pending`, `lastErrorCode=conflict`, with the retry deferred;
tests check that convention together with retained payload/projection and
provider state. Unsent DAV resource updates coalesce, so hierarchy tests check
the exact progress sequence in two resource operations rather than expecting
four operations. No existing regression was weakened.

## Remaining acceptance boundary

At completion of the original F/U repairs, Android device Back,
process/lifecycle interruption, installed picker interaction, provider
authorization and installed UI behavior had not been run. A later explicitly
authorized disposable-emulator session is recorded below; its coverage and
renderer limits apply only as stated there. No application was installed onto
an undesignated attached device.
The pinned Nextcloud 0.18.1 recurrence compatibility, existing account policy,
and notification policy were preserved. Google conditional-write support is
not established by these tests; see the main F05 limitation.

## Follow-up R02/R03/R04/R10/R12/R13

The follow-up started from a clean Git status. The development, iCalendar data
model and provider-support contracts were reread. These changes use the same
pinned SDK and locked shared dependencies; they add no strings, recovery
formats, provider capabilities, account rules or notification rules.

| ID | Disposition and reachable reproduction | Correction and executable controls |
| --- | --- | --- |
| R02 | Confirmed in Android Tasks. A real DAV daily COUNT=3 master advances to D+1/COUNT=2 with one history row, but its rendered checkbox/title remains completed. A barrier after repository arguments also accepted a second activation (two calls). Ordinary cloud completion is the negative control. | Tasks and Schedule bind completion presentation and the queued command to the observed occurrence key from the shared projection contract. Per-task busy guards reject concurrent activations. The actual master row renders open after advancement; a retained old callback cannot add history or alter the pending candidate. A deliberate new callback completes D+1 once, and final COUNT=1 closes normally. Android lifecycle Save inputs and editor results also carry the affected occurrence. A supplementary stale-editor probe was already rejected by existing validation before that explicit binding; no separate pre-repair Android editor overwrite is claimed. The final control checks the occurrence-specific rejection and retained draft. |
| R03 | Confirmed through editor hierarchy navigation: parent A notes L1 → child B → A opens another parent editor and Restore prompt. A controlled isolated baseline run then established the actual durable loss: L2 was stored, an older L1 write was released, and recovery changed back to L1. Rapid row activation behind a repository-read barrier also mounted two editors. Different child/task records and equal IDs in distinct account/list scopes are independence controls. | Identified task opens reserve their Navigator/account/list/ID before loading; verified temporary/server aliases converge on the earliest reservation, and cleanup removes only that reservation's owned keys. Repeated creation requests with the same account/list/provider/initial-date context reuse their owner; different explicit creation dates retain independent drafts and recovery. An already mounted logical task is reused. Returning to a hidden ancestor uses the existing dirty-close decisions; unrelated blocking routes are retained. Every intervening dirty editor receives the existing discard confirmation; cancellation leaves both drafts/records intact. Navigation remains blocked during submission and while another hierarchy route is being opened. The original A state owns the only timer/IO chain. Controlled storage barriers prove L2 cannot overtake an older blocked L1 write, and Save/Discard cleanup waits behind that write and cannot be recreated by its completion or a later timer. L2 remains recoverable after editor recreation. |
| R04 | Confirmed in real Android Schedule agenda and search checkbox controls: completing DAV P left C open. The original status-only Google/Microsoft payloads are the negative controls. | Schedule uses `TaskPatchInput.completion` with `includeCompletedTimestamp: false`, preserving both cloud payloads. Real DAV controls complete P and C; reopening C reopens its closed ancestor. Tests inspect both queued resource candidates, replay against the stateful conditional DAV fake, verify actual remote resource state and empty outbox, reload the real schedule query, then repeat reopening with updated ETags. Explicit status/cancellation semantics remain unchanged. |
| R10 | Confirmed for current-v2 recovery without an observed snapshot. Discard followed by a new notes edit/Save left the database unchanged because the rejected record had already set review-only metadata. A malformed categories record reproduced the same poisoned state. | Recovery comparison flags/source information become editor state only after the complete record is parsed and Restore is accepted. The pending destination is also parsed before acceptance. Discard and malformed categories/destination controls can save fresh notes as one proper operation without inventing a baseline. Existing Restore-without-snapshot remains review-only and retains its original content. |
| R12 | Confirmed after both a pre-commit patch failure and a committed patch followed by move failure. Pressing List immediately retried B instead of showing still-available C. | Main Save retains explicit retry of B. List opens destination selection, including the actual current list when a move is pending; selecting that current list cancels only the pending move. It retains unsaved text and any durable patch. Failure recovery is persisted before returning. Four control paths verify C selection/cancellation before and after patch commit, one retained patch operation, and accurate move calls. Recovery/recreated editor controls cancel only the restored move or choose the surviving destination after B disappears. Choosing the sole current list still requires an explicit selection when cancelling a pending move. |
| R13 | Confirmed with a real read-only DAV collection: tapping the child left the parent editor open. Editable hierarchy navigation is the negative control. | Read navigation uses loading/busy/recovery guards independently of mutation capability. Read-only parent/child links navigate and reuse the existing route, while Save, completion, creation and deletion remain disabled. A saved hierarchy callback invoked after repository submission cannot navigate. No operation or recovery record is created by read-only browsing. |

The DAV notes Save exercised by R03 exposed an additional correctness defect,
D01: the existing notes patch removes the master's `X-ALT-DESC`, but the patch
allowlist rejected that operation with `DavMutationPatchInvalid`. The DAV
ledger records its separate reproduction and narrow repair. The unchanged
Android Save/storage-barrier regression passes through that real patch path
afterward; failure was not hidden by a stub or a weakened assertion.

Before-state commands used `flutter test
test/platform/android/android_adaptive_app_test.dart --name ...
--reporter expanded`. The following outcomes were observed before the relevant
production corrections:

- Tasks recurring presentation: expected open, actual rendered completed,
  despite correct D+1/COUNT=2/history state in the database. The second-activation
  barrier observed two repository calls instead of one.
- Schedule agenda/search: actual statuses were `completed, needsAction`
  instead of both completed.
- Parent→child→parent: an unexpected Restore prompt and another parent owner.
  In an isolated `/tmp` snapshot of the original matching Android sources, a
  stateful secure-storage barrier confirmed L2 was durable before releasing an
  older owner write; the final retained notes were L1 rather than L2. The test
  failed on that actual storage value. The shared working source was untouched.
- Rapid activation of the same actual task row during a gated repository read
  mounted two editor states rather than one.
- Recovery Discard/malformed: fresh notes remained null and Save was blocked.
- Failed-move controls: C was absent because B retried automatically, in all
  four before/after-patch replacement/cancellation cases.
- Read-only hierarchy: expected child title, actual parent title. That single
  before-state run used the original owned source and restored the current
  source automatically afterward.

Final focused commands/results:

- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'Android Tasks reconciles an advancing|Android Tasks ignores a second|Android recurring editor completion|Android Schedule .* checkbox|Android hierarchy|recovery leaves a fresh editable baseline|Android read-only DAV hierarchy|Android failed move' --reporter expanded`
  passed 18 cases after the core corrections.
- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'Android failed move recovery|Android hierarchy navigation is blocked|Android recurring editor completion' --reporter expanded`
  passed four cases, adding the restored-move, disappeared-destination and
  in-flight hierarchy controls.
- The final focused rerun added the malformed pending-destination control:
  `flutter test test/platform/android/android_adaptive_app_test.dart --name 'Android failed move recovery|Android hierarchy navigation is blocked|Android recurring editor completion|recovery leaves a fresh editable baseline' --reporter expanded`
  passed all seven selected cases.
- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'Android identified editor reservations|Android rapid task row|Android concurrent acknowledged aliases|Android top-level reopening|Android hierarchy' --reporter expanded`
  passed all ten ownership cases after the broader reachable entry-point
  reproduction. They include actual cloud creation acknowledgment, concurrent
  old/canonical-ID opens, a later fresh open after reservation cleanup, hidden
  parent reopen with Cancel/Discard, and independent account/list scopes.
  Across these commands 27 distinct new follow-up cases passed; this is not a
  claim that the whole Android suite or native application passed here.
- `dart analyze lib/src/android/presentation/android_tasks_screen.dart lib/src/android/presentation/android_schedule_screen.dart test/platform/android/android_adaptive_app_test.dart`
  reported no issues after correcting six null-promotion diagnostics and one
  test brace lint introduced during the changes.
- Scoped `dart format` and `git diff --check` passed. Raw logs remain in `/tmp`,
  outside version control. The coordinating agent runs the affected and full
  offline suites on the integrated final checkout.

Test-harness corrections were to select the actual master by its existing
mutation-cell identity (All also exposes protected history), select direct
hierarchy-link titles, and recreate an editor over the same real database
rather than inventing an unrelated new resource identity. Reopening a parent
does not reopen its already-closed descendants under the approved percentage
lifecycle; the Schedule ancestor test therefore reopens the child. No existing
expectation was weakened to erase pending work or change that contract.

Installed Android acceptance was still unexecuted at this point; the later
disposable-emulator evidence below supersedes that historical limitation only
for its listed checks. Live-provider execution remains external. The stateful DAV fake proves the client
path, candidates, reconciliation and provider-state effects in tests. It does
not establish undocumented Google endpoint preconditions. F05 remains
externally unverified and F10 remains withdrawn from automatic repair.


### R03 additional storage-scope and delayed-open validation

A bounded independent control review confirmed two further reachable ownership
holes after the initial hierarchy fix. With two real live Google rows sharing
an ID in different lists of one account, each list could open independently,
but both wrote the old account/task recovery key. After writing both notes and
discarding the second editor, the first record was absent. The different-account
control passed. A second actual-controls barrier held delivery of a completed
SQLite-backed task-list read for a top-level child open. Opening and editing
that child through the parent hierarchy, then releasing the old read, mounted
three editors instead of the parent and one child. These failures were observed
before the additional production corrections; no source swap was used.

A related actual New task FAB control also reproduced two editor owners after
repeating the same creation request with an unsaved title/notes draft. The old
clean expectation that all such creation requests were independent did not
prove durable ownership. The corrected contract reuses an identical explicit
request while keeping different date intents separate; no draft chooser or new
creation workflow was introduced.

New recovery writes retain the existing current-v2 payload and use an encoded
account/list/task key. Creation writes use an encoded account/list/provider/
initial-date request key. Exact scoped identities and their verified persisted
aliases are checked first. Existing current-v2 account/task entries are accepted
only when their payload belongs to that exact scope or a verified actual-move
provenance; another live scoped row prevents claiming a historical-scope record.
Default creation can still read its existing current-v2 `new-list` record;
a distinct dated request neither claims nor deletes it. Skipped foreign records
remain byte-for-byte intact. Cleanup only touches the editor's owned scoped key
and an explicitly accepted recovery source. Submitted IO captures its keys, so
location rebinding cannot retarget an older queued payload.

Both production push paths share reservations, including the interval before a
hierarchy route builds. The delayed top-level path rechecks ownership after
its reads and immediately before push. For a still-mounted editor moved from A
to B, normal reuse requires exact account/verified identity, B's persisted
actual-move provenance for A, absence of the original live A row, and the
current B row still carrying that provenance. Absence alone never proves
movement. The same editor is rebound to B without replacing its observed edited
field values or draft; its existing serialized recovery chain migrates the
record. There is no former editor timer left to resurrect an obsolete record.

The prior F09 movement fixture was corrected causally: it had inserted a second
same-ID destination row while retaining the original live source row. That is
the newly protected independence control, rather than proof of movement. It now
performs the actual supported repository move, replays against a stateful
provider that changes membership/revision, verifies the source row is absent,
refreshes the renamed destination through `taskFromDto`/TasksDao, and recreates
the app with the resulting database state. The draft notes remain recoverable
without reverting the remote title; Save queues only destination notes and
stateful replay preserves both values. The shared repository/DAV provenance
regressions are recorded by the coordinating and DAV agents.

Additional controls exercise two-list durable drafts across app/database
recreation; explicit discard of one leaves the other's exact recovery intact.
An old current-v2 canonical record belonging to another live list survives a
pre-commit Save failure and Discard byte-for-byte and remains restorable by its
actual owner. A mounted real move retains one editor and exact draft, queues
only the remaining notes against B, clears only its migrated records on Save,
and cannot recreate them after a later timer. Distinct dated creation and the
default request keep their separate drafts and cleanup; repeated identical
requests do not mount another writer. Existing alias, dirty-close, read-only,
R10 baseline, R12 destination and in-flight controls remain in the affected file.

Executed before-state commands/results:

- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'equal IDs in different|R03 late top-level' --concurrency=1 --reporter=expanded`
  established the same-account/different-list retained-record failure and a
  passing different-account control. The first delayed-open harness awaited IO
  without yielding; that harness issue was corrected separately.
- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'R03 late top-level' --concurrency=1 --reporter=expanded`
  then failed with three actual editor widgets instead of two after release of
  the completed-read barrier.
- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'R03 repeated New' --concurrency=1 --reporter=expanded`
  failed with two actual creation editors instead of one. An initial tooltip
  finder cast was corrected to select the real FAB before this causal result.

Raw output stays in `/tmp`. Final affected commands/results are recorded below.
Native installed acceptance is recorded separately by the Android agent after
rebuilding the frozen source. No live provider evidence or Google atomic-write
support is claimed by these stateful tests; F05 stays blocked and F10 stays
withdrawn. Existing account and notification policies are unchanged.


A final creation-context control also verified returning from a dated creation
editor to the already-open default creation request. Before its correction,
that request threw a null check in `_revealTaskEditor`, because a new draft has
no task entity. The existing intervening-editor dirty confirmation, serialized
cleanup and route-pop logic is now reused independently of a TaskEntity.
Cancel keeps the dated draft and both durable records; Discard returns to the
exact default draft and removes only the dated editor's recovery. Existing
ordinary/read-only hierarchy navigation uses the same guarded return logic.
The before command was
`flutter test test/platform/android/android_adaptive_app_test.dart --name 'R03 differing creation date' --concurrency=1 --reporter=expanded`.
It failed at the null check and did not display the expected Cancel action.

Final focused verification:

- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'R03|equal IDs in different|retains notes after a remote rename|task recovery retains full creation|Android hierarchy|Android top-level reopening|Android read-only DAV hierarchy|Android recovery without an exact baseline|failed task move retains editor' --concurrency=1 --reporter=expanded`
  passed all 19 cases on the final frozen source.
- `flutter analyze lib/src/android/presentation/android_tasks_screen.dart test/platform/android/android_adaptive_app_test.dart`
  reported no issues on the final frozen source.
- `dart format lib/src/android/presentation/android_tasks_screen.dart test/platform/android/android_adaptive_app_test.dart`
  completed, and scoped `git diff --check` passed.

The first complete affected-file run exposed three storage assertions that
still assumed the old unscoped slot. They were corrected to verify the actual
owned scope/current-v2 migration, retaining every original recurrence,
timezone, original-comparison, draft and no-operation assertion. The purposely
unavailable-task fixture uses `missing-source`, rather than an invented valid
source-list identity. A misplaced test edit briefly affected an event-recovery
read and caused an undefined fixture identifier; that event assertion was
restored exactly before final verification. The two-list restart harness now
waits for the second editor's actual title before typing its notes; otherwise
the test typed into the first editor while SQLite delivery was still pending.
The active-move control scopes its callback to the pushed Tasks screen because
the application also retains a cached offstage Tasks screen. These are harness
corrections, not weakened user-visible outcome requirements.

The complete affected-file command at that checkpoint
`flutter test test/platform/android/android_adaptive_app_test.dart --concurrency=1 --reporter=expanded`
passed all 118 cases on that source (1:01). Targeted analysis reported no
issues (14.1s); formatting changed zero files and scoped diff-check passed.
An additional actual active-move assertion had confirmed that the list caption
still displayed A after the same editor rebound to B. The narrow correction
reads the shared list provider by exact account/list, with a fallback only for
the original matching widget scope; header and hierarchy captions now show B.
Commands, observed baselines, account rules and notification rules are unchanged.

### R03-observed-occurrence: retain the edited occurrence during verified movement

A final bounded active-editor review confirmed an additional defect in the new
movement rebinding path. `_rebindMovedTask` replaced the editor's complete
observed provider metadata with the moved task's latest metadata. For a daily
UNTIL recurrence whose rule does not decrement COUNT, this replaced the
observed native due date with the next occurrence's date while retaining the
old completion draft. The occurrence token could then authorize that old draft
against the newly advancing master.

The first production-path fixture had an explicit `STATUS:NEEDS-ACTION`.
Actual completion/replay legitimately removed that optional property from the
advanced open master. The existing semantic conflict check rejected Save on
`taskStatus` and retained the draft, master, provider state and outbox. The
initial assertion requiring the occurrence-specific error was therefore too
narrow. Its useful localized draft-conflict response was verified through the
real repository exception; that protected case was retained as a control.

A standard open VTODO with the optional STATUS omitted established the actual
unsafe path. The task has `FREQ=DAILY;UNTIL=...`, no COUNT, and equal null/open
status and normalized 0% progress before and after advancing. Through actual
Android controls, the editor captures a 100% draft for D. A separate real
repository completion is acknowledged against the stateful conditional DAV
provider, leaving master D+1 and one history instance. A supported repository
move of the parent/child resources is then acknowledged through two real MOVE
operations, including canonical projection-ID aliases and prior-list
provenance. Opening the moved master through its actual destination row reuses
the original editor. Before the correction, Save advanced the actual local
master from October 25 to October 26 instead of retaining October 25. This
failed on the observed database date before any error-message assertion. The
explicit-status control and both legitimate notes/unchanged-occurrence controls
passed in that same four-case before run. No guard was relaxed and no source
swap was used to produce this result.

Rebinding now retains the complete observed semantic/native metadata and
merges only the already verified task-ID aliases and previous-list provenance.
The task ID and list location still rebind explicitly. It does not replace the
old occurrence token with the latest task's dates. Both stale draft forms now
receive the existing occurrence-changed error before mutation, with the exact
100% draft retained. The master stays at D+1, its one history instance and
provider resources are unchanged, and no operation is queued. The durable v2
recovery comparison checks every draft-body value before/after movement, the
old observed occurrence/native due metadata, current verified identity/location,
aliases and prior-list provenance; its former source key is removed only after
migration. A notes-only draft remains mergeable after advancement and movement.
Completing the unchanged occurrence after movement remains valid, advances once
and replays the existing parent/child lifecycle. Successful controls clean only
their owned recovery entries.

Commands/results using the unchanged pinned SDK:

- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'R03 verified DAV move preserves' --concurrency=1 --reporter=expanded`
  before the repair: the valid omitted-STATUS stale-completion case failed on
  the actual unintended master date (expected October 25, actual October 26);
  the explicit-status, notes-after-advancement and unchanged-occurrence controls
  passed (3 passed / 1 failed).
- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'R03 verified DAV move preserves|R03 a verified moved|R03 equal IDs|R03 a foreign|R03 differing creation|Android concurrent acknowledged|Android recovery follows' --concurrency=1 --reporter=expanded`
  after the repair: all 10 selected recurrence/identity/recovery controls passed.
- `flutter analyze lib/src/android/presentation/android_tasks_screen.dart test/platform/android/android_adaptive_app_test.dart`
  reported no issues after the narrow correction.

The final complete affected-file run includes the added exact durable-recovery
assertions. Raw logs stay outside source control under `/tmp`. This is client
behavior against real local storage and a stateful conditional DAV fake, not a
live-provider or installed-native result. The advancing master, floating
history, UNTIL/COUNT exhaustion and all other F10 compatibility semantics are
unchanged. Existing account and notification policies remain intact; F05's
unverified external atomicity limitation remains independent.

- Final `flutter test test/platform/android/android_adaptive_app_test.dart --concurrency=1 --reporter=expanded`
  passed all **122 tests** in 1:17 after the observed-occurrence correction and
  exact durable-recovery assertions. All four named recurrence/move cases ran
  in that complete-file result, alongside the original recurrence, conflict,
  recovery, capability, hierarchy, Back and failed-move controls.
- Final scoped `dart format --output=none --set-exit-if-changed` checked both
  Android files with zero changes, and scoped `git diff --check` passed.
- The coordinating agent's final whole-checkout `flutter analyze` reported no
  issues on the frozen app/test source (61.1 seconds), and its complete format
  check reported 949 files with zero changes. The earlier post-correction
  scoped analyzer also passed. A redundant last scoped analyzer remained at
  its progress message after the normal whole-checkout analysis completed and
  was interrupted; that extra invocation is not counted as a pass.

### R03 occurrence-conflict localization

A final narrowly scoped localization regression confirmed that the new
`TaskOccurrenceChangedException` reached Android through its diagnostic English
`toString`, including when the application locale was German. The actual stale
editor Save and retained Tasks, Schedule and hierarchy checkbox callbacks all
showed the English diagnostic instead of the existing German draft-conflict
message. These production controls first acknowledged a real recurring DAV
completion through the stateful conditional provider, then verified exact
unchanged local rows, an empty outbox, unchanged provider resources and the
retained 100% editor draft before checking the message.

The initial German editor/hierarchy probe also encountered an existing long
recurrence-dropdown label overflow at the default test width. The editor
localization defect was independently reproduced at the supported 1200×900
Android viewport with no layout exception: its sole failure was the missing
German message and actual English SnackBar. This check does not claim that the
unrelated narrow-width German recurrence layout was repaired or natively
accepted.

Only the four exception-presentation boundaries changed: the editor formatter
and Tasks, Schedule and hierarchy checkbox error handlers map this new
exception to the existing localized `taskDraftConflict`. Other exception
presentation and policies remain unchanged. No strings, catalogs, recovery
formats or frameworks were added. Existing recurrence regressions now assert
the useful localized product message while retaining their exact draft,
observed occurrence, row, outbox, history and provider-state assertions. The
domain diagnostic remains available for diagnostics rather than being used as
translated UI copy.

Executed checks with the pinned SDK:

- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'Android stale occurrence conflicts use the selected locale' --concurrency=1 --reporter=expanded`
  reproduced the English diagnostic in all four German paths before repair;
  the Tasks and Schedule failures had no companion layout error.
- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'Android stale occurrence conflicts use the selected locale in editor' --concurrency=1 --reporter=expanded`
  independently failed only on the wrong English message at 1200×900 before
  production edits. All preceding retained-state/provider assertions passed.
- `flutter test test/platform/android/android_adaptive_app_test.dart --name 'Android stale occurrence conflicts use the selected locale|R03 verified DAV move preserves|Android recurring editor completion' --concurrency=1 --reporter=expanded`
  passed all **9** selected cases after repair: four German surfaces, four
  real movement/occurrence controls and the existing stale-editor control.
- `flutter analyze lib/src/android/presentation/android_tasks_screen.dart lib/src/android/presentation/android_schedule_screen.dart test/platform/android/android_adaptive_app_test.dart`
  reported no issues (8.6 seconds).
- Final scoped `dart format --output=none --set-exit-if-changed` checked all
  three files with zero changes, and scoped `git diff --check` passed.

The final complete affected-file run includes these four German controls and
all existing ordinary failure/retry controls. Raw logs remain under `/tmp`,
outside source control. Installed-native checks are recorded separately by the
Android agent against the frozen localized-mapping source. F10 compatibility
and the existing account/notification policies remain unchanged.

## Installed disposable Android acceptance, 2026-10-22

The later host check established usable KVM; the earlier unavailable/sandbox
observation is historical. No existing AVD or attached personal device was
used. A fresh `busymax_task_lifecycle_qa` AVD was created under
`/tmp/busymax-task-native-qa/avd` from the installed Google Play x86_64 API 35
image (revision 9, extension 13). Emulator 37.1.11.0 / build 15917651 ran
Android 15 / API 35 (`AE3A.240806.036/12592187`). The application's compile and
target API 37 were unchanged. Flutter 3.47.5, bundled Dart 3.13.4 and the
existing locked packages were used. Build commands supplied the installed JDK
17.0.20 through `JAVA_HOME`; Flutter's existing JVM selection was not changed,
and that environment assignment alone is not evidence of the actual Gradle JVM.
The separate unit/lint checks explicitly selecting JDK 17 are recorded by the
coordinator.

The emulator used port 5584, gRPC port 8590, a fresh userdata directory, no
snapshot, `-no-window -no-audio -no-boot-anim -no-metrics
-gpu swiftshader_indirect -memory 2048 -cores 2`. Its AVD, Android-user and
emulator-home environment directories were isolated under the same `/tmp`
root. A private ADB server used port 5039 with `--one-device emulator-5584`.
Every host device command explicitly selected `-P 5039 -s emulator-5584`;
none targeted the host's default server or another device. The regular package
ID was used only on this fresh, explicitly designated disposable emulator.
All task/account contents were synthetic, there were no credentials, and sync
was disabled through the existing test override.

Commands used the absolute pinned SDK executable. The initial installed native
bridge check ran as:

```sh
JAVA_HOME=/home/albert/.sdkman/candidates/java/17.0.20-tem \
ADB_SERVER_SOCKET=tcp:127.0.0.1:5039 ANDROID_ADB_SERVER_PORT=5039 \
ANDROID_SERIAL=emulator-5584 \
/home/albert/flutter/bin/flutter test \
  integration_test/android_platform_smoke_test.dart \
  -d emulator-5584 --no-pub --reporter expanded
```

It passed its **one test**. This exercises actual device settings and the
platform availability bridge; it is not Google or Microsoft authorization.

`integration_test/task_lifecycle_android_test.dart` adds one opt-in installed
acceptance case with three durable phases. It uses the actual Android runtime,
file-backed SQLite database, Android secure-storage plugin and existing task
controls. Its repository subclass only supplies the specified post-argument,
precommit Save barrier/failure; durable writes use the real repository/outbox.
The file refuses non-Android execution, requires
`--dart-define=BUSYMAX_TASK_NATIVE_QA=true`, and rejects foreign accounts.

The standalone QA APK was built with:

```sh
JAVA_HOME=/home/albert/.sdkman/candidates/java/17.0.20-tem \
/home/albert/flutter/bin/flutter build apk --debug \
  --target-platform android-x64 \
  -t integration_test/task_lifecycle_android_test.dart \
  --dart-define=BUSYMAX_TASK_NATIVE_QA=true --no-pub
```

The successful core build containing the observed-occurrence repair completed
in 87.6 seconds. The APK was
copied outside the checkout before another build could replace the standard
artifact. Raw APKs, AVD data, screenshots, logcat, receipts and host controllers
remain outside Git under `/tmp/busymax-task-native-qa`.

The host controller used only the selected emulator's `adb shell input`,
`run-as`, `am force-stop`, `pidof` and `am start` commands. Input is synchronized
by JSON receipts in `files/task-lifecycle-qa`; the test selects the complete
field using its existing editable state and verifies that selection before the
host sends actual platform text. No framework `enterText` result is used as
native-input evidence. The repeatable receipt protocol is:

1. Wait for `awaiting-initial-notes.json`, send
   `input text Native%sretained%snotes%sL1`, and touch `initial-notes-done`
   using `run-as`.
   Repeat for `awaiting-notes-input.json`, L2, and `notes-input-done`.
2. On `awaiting-back.json`, send `input keyevent 4`. On `prepared.json`, verify
   exact L2 and one editor owner, force-stop the package, and require an empty
   `pidof` result. Install the preserved observed-occurrence-repair APK before relaunch.
3. Relaunch the package's `MainActivity`. On `awaiting-title-clear.json`, send
   keyevent 67 and touch `title-clear-done`. On
   `awaiting-title-correction.json`, send `Native%sparent` and touch
   `title-correction-done`. On `awaiting-busy-input.json`, send
   `NATIVE_LATE` and touch `busy-input-done`.
4. On `restored-and-saved.json`, require exact L2 and four pending operations,
   force-stop again, verify process absence, relaunch the same APK, and require
   `final-restarted.json` from its new PID. The host ignores stale receipts
   whose PID differs from the live process and reports `failure.json` rather
   than accepting an earlier run's result.

Successful observed outcomes:

- PID **13914** navigated parent A → child B → A with one parent editor owner,
  persisted exact notes L2, and cancelled the actual Android Back dirty-close
  prompt with the draft retained and no queued operation. This preparation
  phase intentionally waits for host interruption and is not counted as a
  completed Flutter test run.
- The first `am force-stop` left no app process. After installing the build
  containing the observed-occurrence repair, PID **14535** restored exact L2
  from Android secure storage into the actual editor. Blank-title validation
  retained content and queued nothing. Correcting the title made Save usable.
  A barrier after the repository received the submitted arguments showed the
  rendered text controls disabled; actual late platform input changed neither
  submitted nor retained title/notes.
- Releasing the injected precommit failure retained exact L2, displayed the
  failure and left the outbox empty. One retry durably saved one patch and
  removed only its recovery. The installed Material date picker interaction
  then saved a deadline, and the actual task checkbox completed and reopened
  the task. There were five repository calls (one failed attempt and four
  committed mutations), with exactly four queued operations.
- A second actual force-stop again left no process. PID **15121** reopened the
  same file database and verified L2, open status, the deadline, four pending
  operations and absence of the saved recovery. Both final-source recovery/
  Save and final-restart phases reported `All tests passed`; each executes the
  same single integration case, not two distinct test definitions. These are
  real process deaths/relaunches, rather than widget recreation.

The four later localized occurrence-message mappings were not exercised by
this Google-only core case. Its accepted app sources include the preceding
observed-occurrence repair; the following checklist installation includes the
later message mapping as well.

Several attempted runs exposed harness or platform limits and were retained as
failed attempts. A lazy hierarchy field required scrolling before interaction.
The integration runner uninstalled its package after one early failure; the
resulting short `run-as` error capture was not a database and is not counted
as database evidence. An asynchronous Restore prompt needed an explicit
Restore-or-writable readiness condition. Framework test input after a retained
route failed to reach `onChanged`; real ADB input did reach it. Unsupported
Ctrl+A was replaced by explicit full-selection preparation followed by actual
platform text. One disabled-control assertion needed the next rendered frame
after the repository barrier. These corrections did not clear recovery or
pending operations, change expected L2, relax product validation, or change
application code.

The default renderer also encountered a native startup ANR. Its captured stack
waits in `HardwareRenderer.setStopped` / RenderProxy, with a RenderThread
`FrameCommitWrapper.onFrameCommit` frame. This observation does not establish a
specific driver cause. The successful task acceptance launches used the
bundled Flutter runtime's supported flags
`--ez enable-impeller false --ez enable-software-rendering true` on `am start`.
No app manifest, framework, dependency or SDK setting was changed. Therefore
normal hardware-renderer Android acceptance remains an external gate on a
stable, designated QA device/emulator. This run proves only the stated
installed scenarios using software rendering. It does not establish live
provider behavior, an undocumented precondition, API 37 device behavior, or
all Android task flows. F05 remains externally unverified and F10's reference
compatibility model and the existing account/notification policies are intact.

The final complete Android adaptive widget-file command, after the four
localized occurrence-error mappings, passed **126 tests** in 2:34. The earlier
122 and 118 counts above describe their respective preceding checkpoints.
The final focused localization/recurrence run passed nine cases, and scoped
analysis reported no issues. These runtime regressions are independent of the
installed tests below.

### Installed offline Microsoft checklist controls

`integration_test/task_checklist_android_test.dart` adds one further opt-in
case for the same disposable profile, after the core case. Before adding its
synthetic Microsoft fixture it verifies the exact retained core notes, open
status, deadline and four Google operations. It uses the real file database,
repository and outbox. A test-only interface client identifies checklist
capability and throws on every attempted remote call; the accepted runs assert
zero such calls. Sync is disabled, and linked-resource/attachment reads are
excluded from this bounded checklist phase. No Graph result or live provider
conflict protection is claimed by this fixture.

The final APK build command replaces the target above with
`-t integration_test/task_checklist_android_test.dart`, retaining the same
opt-in flag, x86_64 target, pinned SDK and `--no-pub`. It passed in **126.6
seconds** after the tab-readiness harness correction. The installed app source
SHA-256 values were:

- Tasks: `e1a1412a41240b4ca1d537ffd0b056908b7f111c7c1adfc5840e826b27d69798`
- Schedule: `2682391a082864432d18dc8f26d68438e658237114ed92f3f568b0c3d377e5c1`

These match the final observed-occurrence repair and four localized-error
mappings. The APK was preserved in `/tmp` before the normal application build
artifact was restored. The test source hash and APK hash are retained with the
raw run evidence rather than treating an earlier APK as final-source coverage.

The first checklist attempt opened the prior Schedule row's existing preview
sheet: its finder ran before the tapped Tasks tab rendered. It timed out before
any checklist action. The harness now waits for that tab's actual settled
frame; product code and validation were unchanged. Before the corrected APK
could install, the owned emulator process exited and produced native crash
snapshot/ptrace errors. No cause was inferred. The same isolated AVD was
restarted once **without `-wipe-data`**, booted in **89.558 seconds**, and
retained the entire synthetic database and earlier core results. An
`am start -W` launch wait later timed out, while the actual installed test and
receipt barriers proceeded successfully. That launch status was not used as
passing evidence.

The host protocol uses `files/task-checklist-qa`. It waits for
`awaiting-rename-cancel.json`, sends native text `Cancelled%sstep`, and touches
`rename-cancel-done`; it repeats for `awaiting-rename-apply.json`,
`Native%srenamed%sstep`, and `rename-apply-done`. On
`awaiting-checklist-back.json` it sends real keyevent 4. After
`checklist-mutated.json`, it force-stops the QA package, verifies no process
remains, relaunches the same preserved APK with the recorded software flags,
and requires `checklist-verified.json` from the new PID. As with the core
controller, receipts from a different live PID are rejected.

Observed results:

- PID **3847** opened the actual task editor and checklist menu. Rename →
  Cancel retained `Original step` and queued no Microsoft operation. Rename →
  Save retained the exact native-entered `Native renamed step` and queued one
  `patch_task_checklist_item` with `displayName` and the original step ID.
- Delete → Cancel retained the renamed local item and one operation. Confirmed
  Delete removed the local step and queued exactly one
  `delete_task_checklist_item`, depending on the rename operation and retaining
  the same step identity. The actual Back action closed the clean editor. All
  local row/payload/dependency assertions completed before the host's intended
  process stop; that UI phase was interrupted at its receipt and is not counted
  as a separately completed Flutter test.
- The host proved process absence after force-stop. PID **4459** reopened the
  same file database and verified the empty checklist, both pending payloads,
  their dependency and all four unchanged core operations. This verification
  phase reported **one integration case passed** (`All tests passed`, 3
  seconds). The two phases execute the same test definition. The profile now
  contains exactly the intended four core operations and two checklist
  operations; none were cleared to obtain a pass.

The native tests cover installed local/offline controls and durable client
state. Existing stateful provider regressions cover replay and F06 conflicts;
this installed phase did not contact Graph, acknowledge a checklist create,
or establish a conditional-write guarantee. Native Google creation-ID
acknowledgment, installed Nextcloud recurrence/move flows, live synchronization
and normal hardware-renderer acceptance remain outside these specific runs.
Their checks require a stable designated device/renderer and explicitly enabled
disposable provider accounts/servers; no credentials or personal tasks were
used here.

Final native-test checks:

- `flutter analyze integration_test/task_checklist_android_test.dart integration_test/task_lifecycle_android_test.dart`
  passed with no issues (27.2 seconds) after the readiness correction.
- `dart format --output=none --set-exit-if-changed integration_test/task_checklist_android_test.dart integration_test/task_lifecycle_android_test.dart`
  checked both files with zero changes. Scoped `git diff --check` passed.
- Cleanup sent `adb -P 5039 -s emulator-5584 emu kill`, which returned its normal
  success response. The owned emulator PID was absent afterward. Then
  `adb -P 5039 kill-server` stopped only the private QA server. Raw evidence
  remains outside Git; no other device or default host ADB server was stopped.

These results do not remove the documented F05 provider atomicity limit, alter
F10's Nextcloud 0.18.1 compatibility choice, or change account/notification
policy.
