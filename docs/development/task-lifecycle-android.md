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
| F20 | Confirmed: native editor Save/validation. | Original empty-title Save returned silently. Blank title, visible invalid URL, deadline-before-start, and mixed date/time modes now show localized feedback and reveal the first invalid field. Values remain and no operation is queued. Correcting the title saves once. Hidden unsupported Google fields do not prevent a title save. The existing past-reminder feedback remains. |
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

The coordinating agent runs normal full-checkout checks and available native
build/tests. Android device Back, process/lifecycle interruption, actual picker
focus, provider authorization, installed UI behavior, and live provider
interoperability still require an explicitly enabled disposable QA device and
accounts. No application was installed onto an undesignated attached device.
The pinned Nextcloud 0.18.1 recurrence compatibility, existing account policy,
and notification policy were preserved. Google conditional-write support is
not established by these tests; see the main F05 limitation.
