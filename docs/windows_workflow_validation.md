# Desktop workflow feedback validation

The supplied findings were reproduced in the current source. The changes retain
Fluent on Windows and Yaru on Linux; they do not change provider support or the
state-management library.

| Finding | Change and automated evidence |
| --- | --- |
| Existing event zones overwritten | Windows initializes each endpoint from `EventEditorDraft`, edits zones independently, retains seconds, and uses the shared draft's instant-based range validation. `windows_event_preservation_test.dart` saves an event whose end wall time precedes its start wall time in a different zone. It checks stored instants, both zones, and the outgoing patch. |
| Calendar switching clears unrelated fields | Windows retains the original draft's recurrence, reminders, meeting and personal values while selecting destinations. The repository converts at save time; its existing copy/delete confirmation describes potential losses, and unsupported recurrence is rejected. Tests cover a compatible move and switching away and back. Queued Google moves now also project the title edit locally while retaining source identity until the remote move succeeds. |
| Stale Tasks and Schedule | A shared repository change signal covers items and joined account/source/capability metadata. Both Windows pages invalidate cached queries. Tests write directly to the database while a page remains open. Search is debounced and retains the previous result during refresh. |
| Notification and Today targeting | Windows consumes pending workspace commands, matches complete item identity using the shared command contract, and opens item details. It retries pending targets when sync supplies them. Today sets the date and day view; the planner recenters for destinations outside its previous scroll bounds. Tests cover events, late-arriving tasks, and returning from a distant event to Today. |
| Incomplete Tasks workflow | Inline writable completion, account/list scope, completed filtering, hierarchy indentation, account-qualified list labels, creation context, and separate signed-out/empty/search/loading/error states. Direct `WindowsTasksPage` tests exercise these workflows and persistence. |
| Month and Year behavior | Month sizes cells from available height, calculates row capacity, shows source colors and full-identity tooltips, and exposes an operable overflow dialog. Year renders weekday/date grids with item markers and individual date selection. Tests cover overflow, keyboard activation, larger text, variable height and multi-day markers. |
| Editor prominence and duplicated behavior | Notes precede secondary task fields on both platforms. Native disclosures group detailed properties and reminders; existing non-default details open automatically. Events keep location/description ahead of secondary controls. Windows task creation uses `TaskDetailsDraft.toCreateInput`; the task editors share simple recurrence encoding; event editors and repository share provider-property conversion rules. |
| Source-shape tests | Removed the mode-control source-syntax ban and part of the widget-class inventory. Existing rendering/keyboard/scaling tests in `busymax_grouped_surface_test.dart` cover that control. Native platform-boundary checks remain. Added workflow tests rather than replacing domain coverage. |

Test paths are under `test/ui/windows/` unless otherwise noted. Existing editor,
repository, native UI and calendar gesture suites are also included in validation.

## Follow-up safety and recovery review

The four follow-up issues required changes:

| Finding | Change and regression evidence |
| --- | --- |
| Creation serializes recurrence while building | `TaskDetailsDraft.forCreation` retains the recurrence rule without provider encoding. Destination capability validation reports incompatible patterns or missing dates; serialization happens in the guarded save path. A visible warning lets users change the pattern or destination. Draft and dialog tests cover a monthly rule on days 1 and 15, switching to Microsoft and back, cancelling the correction, and explicitly removing repeat before saving. The dialog test supplies the complex rule at the recurrence editor's result boundary. |
| Hidden fields still invalidate a new destination | URL and schedule validation follow destination capabilities. Tests switch an invalid Nextcloud URL to Google, return to confirm the URL is retained, and create the Google task. Draft tests also cover an inapplicable retained start date. |
| Notes/description do not refresh dismissal protection | The Windows creation, task-details and event editors use a shared builder that listens to every editable text controller. Back-dismissal tests edit only notes or description, cancel the discard prompt, and verify that the text and dialog remain without writes. |
| Removed scope remains active | Successfully loaded account/list data reconciles the stored filters before querying. Tests remove the selected account or list while Tasks remains open and verify both selector values and repository filters, plus tasks in the remaining account. A pending-refresh test verifies that loading alone does not clear scope. |
| Retry leaves failed dependencies unchanged | Retry and Refresh invalidate failed account/list providers and refresh the task query. Tests independently fail the task query, list loading and account stream, then verify recovery. |

The two new compatibility messages are included in all supported translations.

## Automated verification

- `flutter test --no-pub`: 2,062 passed, 10 skipped after the follow-up fixes.
  The skipped tests are existing opt-in/live-environment checks.
- `flutter analyze --no-pub`: no issues.
- `flutter build linux --debug --no-pub`: passed.
- `git diff --check`: passed.

## Native Windows release verification

Native Windows visual approval remains **pending**. The development environment
for this change is Linux; headless Fluent widget tests are not installed-MSIX
screenshots or a Windows accessibility/DPI verification.

Use the matrix in [windows_ui.md](windows_ui.md):

- Installed MSIX, light and dark, at 1280×800 and 1920×1080.
- Display scaling at 100%, 125%, 150% and 200%, including mixed-DPI monitor moves.
- Arabic/Persian RTL, high contrast, keyboard focus and screen-reader labels.
- Capture Tasks with scoped lists, completed rows, hierarchy, empty and failure
  states; Month with overflow open; Year with selected dates and markers; event
  and task editors with collapsed and populated secondary sections.
- Exercise a title-only zoned event edit, a calendar switch and return, background
  sync while views stay open, task completion, notification activation, and tray
  Today after navigating several years away.

Record screenshots and observations in the Windows release test record before
marking the native rendering matrix complete.
