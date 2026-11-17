# Android rework: Linux reference and acceptance record

This is an in-progress rework, not a full Android parity qualification. Test
execution, comparison with Linux, hosted layout inspection, and native Android
interaction are separate evidence categories. A working provider operation does
not establish presentation parity.

## Reference identity

The starting checkout is `3e27eca0578dd2c1c182b5346b8290eb90bc8ed6`, the revision
reviewed in the handoff. It was clean when work started. No later Linux product
revision was substituted. The older implementation map's
`d2d10e2831d98417fec0b1e79fdf7cd58ee84d0a` is not the current acceptance reference.
Repository development and Android setup instructions were read; no AGENTS.md
was found in the checkout or its ancestor directories.

The runtime environment has Flutter 3.47.5, bundled Dart 3.13.4, an Ubuntu 24.04
Linux graphical session, and a OnePlus A6003 running Android 10/API 29. The
installed Flutter working tree was checked clean before the rework. The repository's publisher-file and SDK
identity checker passes. No Flutter, calendar package, or other dependency was
patched. The resolved upstream calendar package is 2.12.0, permitted by the
existing lockfile and pubspec constraint; dependencies were not changed.

All captures use the existing `seedScheduleParityStress` in-memory fixture. The
controlled comparison uses English, light theme, Monday-first weeks, 24-hour
time, and the hidden task list excluded from the normal schedule. The connected phone reports `America/Edmonton` and a UTC−07:00 offset. The host
zone database resolves that zone differently at this date. Controlled runs
therefore use `Etc/GMT+7` (UTC−07:00) for the fixture's app time-zone provider
and host `TZ`, without changing the phone's settings. The production entry
points initialize the time-zone provider before building the shell; the
integration harness now does that explicitly too. Dates come from the run's
local clock, not the handoff's review date. Runtime records must
include their actual date. No fixture sends provider mutations or invitations.

`tool/android/parity_source_identity.py` records HEAD plus a digest of tracked
and non-ignored untracked source files. This distinguishes an uncommitted rework
from the base revision. Pass the same digest to Linux, hosted Android and native
Android runs. The native driver writes `source-identity.json`; the integration
fixture writes `environment.json`. Runtime output stays outside Git, following
`docs/development.md`.

## Workspace reference and implementation

The Linux entry point remains `ScheduleWorkspace`. The Linux widget entry points
now supply `LinuxSchedulePresentation` to shared first-party implementations under
`lib/src/ui/common/schedule/`. That renderer retains the existing Yaru controls,
boxed lists, menu/popover route and focus treatment. Android supplies Material
controls. Models, source projections, arrangement, grouping, and operation
coordinators retain their existing ownership.

| Area | Reachable Linux reference, content and commands | Activation, conditions and Android translation | Implementation / evidence to compare |
| --- | --- | --- | --- |
| Header | `ScheduleToolbar`: sidebar, Today, applicable period arrows, localized title, separate view selector, Create Event/Task, Refresh, Search, main menu | Agenda has no arrows. Create entries have independent capabilities. GTK menus translate to native Android menus/sheets. Android has a view selector and header Create; its FAB and All tasks menu entry were removed. | Linux toolbar; Android `AndroidScheduleScreen` / `_navigationRow`. Capture each view and exercise selector, Today, arrows, Create and Refresh. |
| Sources/search | `ScheduleSidebar`, `MiniCalendar`, `ScheduleSearchFilters`: mini-calendar then independent source list; temporary search replaces normal sidebar and uses Agenda | Android uses a sheet when compact and a requested pane only when the measured mini-calendar plus an independently scrolling source list fit. Wide search substitutes filters. Source names are passive; visibility and one contextual menu are separate. Search criteria capture normal selection and closing search preserves it. | `_AndroidSourcesPane`, shared `MiniCalendar`, `AndroidScheduleSearchFilters`. Compare sources and search captures; inspect navigation and restoration. Account disclosure/options are separate, with capability-aware account-scoped creation, reorder and Nextcloud Trash. Further provider-state checks remain open below. |
| Day/Week | `ScheduleDayWeekView`: one/seven configured days, no Day date-header row, pinch, inline scrolling all-day panel and boundary handle, neutral event blocks/source edges, task identity and separate completion | Shared planner keeps non-snapping horizontal navigation and same-slot strips. Touch holds distinguish range selection, movement and boundary resize from scrolling. Event mutations use `ScheduleReschedulingCoordinator`; tasks are not draggable. Range creation opens Event directly; an ordinary slot offers capability-aware Event/Task. | Shared `schedule_day_week_view.dart`, `schedule_interactions.dart`, `schedule_planner_events.dart`; native control renderer. Compare timed/all-day captures and actual gesture outcomes. Picker timing actions remain in preview. |
| Initial position | Linux visible-minute rule includes earlier intersecting segments before configured day start | Android can mount while data loads; the shared planner must apply that rule when its first nonempty data arrives. | `_positionedForItems` and `_visibleMinuteRange`. Check overnight and early-event captures after asynchronous loading. |
| Month | `ScheduleMonthView` and `ScheduleRange.month`: actual week count, seven columns, selected-only Create, independent today/outside-month treatment, compact rows, dated overflow | Android fits the overview to its area. At enlarged type or very short height, measured row capacity and the existing vertical/overflow mechanisms preserve access. Touch period swipes and shared event/date targets remain. | Shared Month; Android `_showAndroidDayItems` queries live state rather than retaining an immutable checkbox list. Compare normal and enlarged captures; toggle twice in one overflow sheet. |
| Year | `ScheduleYearView`, `YearMonthMiniCalendar`, `MiniCalendarGrid`: twelve grouped miniatures, localized month/year, numeric week actions, borderless days, circular markers, dots, six rows | Same 900/680/520 column thresholds. Month heading → Month; day → Day; week → Week. Android hold supplies contextual creation while normal activation retains navigation. | Shared Year/mini-calendar and `miniCalendarMarkerColorsForItems`. Compare narrow/wide captures, spillover markers, and all three destinations. |
| Agenda | `ScheduleAgendaView`: section headings outside grouped surfaces, row dividers, Overdue/No date/day sections, hierarchy/context, separate checkbox and preview activation | Android now uses the same ordinary and search grouping implementation. Search groups by each item's own display date before hierarchy. Overdue/undated load controls stay in their sections; chronological continuation follows scrolling. | Shared Agenda; Android `_AgendaList` passes the growing query range and existing mutation intent. Check ongoing events, missing parents, checklist activation/completion and pagination. |
| Previews | `ScheduleItemDetailsPopover`: identity/title/kind, primary actions, common date/source/account context, conditional provider details | Android sheet retains explicit preview → Edit. Edit/Delete/Export/Close and timing actions precede long details. RSVP styling reflects response. Saved supplemental location resolution precedes native launch, with visible failure feedback. | `_showItem`. Native preview/editor/dirty Back captures exist; complete provider detail ordering remains open below. |
| Event editor | `EventEditor`: primary fields, account/calendar, time controls, description, recurrence scope/repeat, reminders, guests, Organization, final Delete | The native form now has primary fields, account then filtered calendar, separate date/time/zone controls, rich description, occurrence scope or supported Repeat, reminders, individual guest rows with contact suggestions, Organization with the Linux populated-state predicate, and final Delete. Existing coordinators are retained. Destination changes flush live reminder buffers and use shared availability/visibility policy. New timed DAV creation initializes zones before recurrence. Nextcloud guest eligibility checks `canInvite`. | `AndroidEventEditor`; Provider-dependent combinations still need a complete runtime comparison; the source reordering alone does not qualify them. |
| Task editor | `TaskDetailsEditor`, `IcalTaskFieldsEditor`: ordered conditional sections and one Save-owned draft/movement transaction | The form now orders Title, attachments/links, destination, Due/Start, Notes, grouped iCalendar progress/priority/location/organization/reminders/Repeat, provider reminder/Repeat/Organization, hierarchy, advanced operations and final Delete. Account and List are distinct creation choices; existing task movement stays in the draft until Save, using the existing partial-save recovery. Due time label corrected. Alarm editing uses shared trigger policy, supports mode choice and preserves unchanged duration precision. | `AndroidTaskEditor`; Recovery and stale-occurrence regression checks are retained; additional provider/native acceptance remains open. |
| Settings | `SettingsScreen`: System, Accounts, Schedule, Notifications, Privacy, Diagnostics; focused account/contact/collection contexts | Settings now selects categories within one surface. The Accounts overview contains provider creation, connected rows, independent contacts, Import ICS and subscriptions; account rows open focused details with retained Back position. Diagnostics content is embedded directly. Time format/first weekday moved to Schedule. Read-only/pending-deletion task defaults are filtered. Provider-hidden local visibility is disabled. Task-only/physical Nextcloud contexts reach metadata, including role/owner, sharing and export/scheduling actions. Metadata save Retry preserves dirty values. Subscription creation is one validated URL/name/color/frequency form with a safe-origin preview. Persistence failures offer Retry. | Android settings/source actions/Nextcloud screen. Provider combinations, contacts recovery and subscription runtime validation remain open; category labels alone do not qualify them. |

## Editor and account flow observations

These are the ordered Linux groups used for the native forms. Implemented
controls still require the provider and device checks listed below; their
presence is not a parity certificate.

| Linux entry point | Content order and state ownership | Android implementation and comparison flow |
| --- | --- | --- |
| `EventEditor` | Title/location; account/calendar; mode/start/end/zone; rich description; occurrence scope **or** Repeat; reminders; individual guests and availability; populated Organization; final role-sensitive Delete | `AndroidEventEditor`. Time components have separate pickers. Immutable attendees remain inspectable. Nextcloud eligibility includes canInvite. Unsupported recurrence remains locked. Save/move/recovery and guest delivery remain owned by existing coordinators. Open event preview → Edit → change destination after unsaved reminders → Save; compare editor and recurring-scope states. |
| `TaskDetailsEditor`, `IcalTaskFieldsEditor` | Title; attachments/links; creation Account/current List; Due; Start; Notes; iCalendar Status/Priority/Location/Organization/Reminders/Repeat; provider reminder/Repeat/Organization; hierarchy; advanced operations; final Delete | `AndroidTaskEditor` and `AndroidEditorGroup`. List changes stay in the draft until Save and retain partial-save recovery. Hierarchy activation remains distinct from completion. Alarm mode changes use the shared editability policy; unchanged −45/−90 seconds are preserved. Parent/child Back and dirty-close decisions remain editor-owned. |
| `RecurrenceEditor` | Frequency/interval; frequency-specific pattern and named ordinal choices; ending; locked unsupported rules | `AndroidRecurrenceDialog` uses shared ordinal semantics, keeps interval/end across frequency transitions and preserves unsupported rules. Compare accepted rule data, not only the dialog's widgets. |
| `SettingsScreen` Accounts | Add providers; connected rows; independent contacts; Import ICS; subscriptions. Account detail owns status/recovery, sync expansion, provider collections, extras, linked contacts, Advanced and final Remove | `AndroidSettingsScreen` now has focused account routes and one category selector. Physical DAV collections have qualified content switches, rather than three projected copies. Google local visibility is selected AND not provider-hidden and disabled while hidden. Conflict notification entry points retain their diagnostics destination. |
| Independent/linked contacts | Independent identity rows open details; linked accounts stay with their parent. Details retain read-only permission context, address books, recovery/Advanced and final Remove | `AndroidContactsSettings`. Existing route tests cover read-only enrollment, source selection, cancellation, permission recovery, reconnect and removal. Independent Back returns to overview; removing a focused independent account returns there. |
| `NextcloudCollectionDialog` | Collection identity/role/editability; metadata/content; owner/time zone in Advanced; sharing; scheduling/export actions | `AndroidNextcloudCollectionScreen`, reachable from calendar, task-only and physical-collection contexts. Failed Save retries Save with dirty values; load Retry is offered only without loaded state. |
| `SettingsScreen` subscriptions | Identity/color/safe origin; read-only; last/next refresh and health; refresh/rename/color/frequency/unsubscribe | Accounts overview retains the existing service. Add is one validated URL/name/color/refresh form. Import ICS remains its preceding independent operation. |

## Interaction evidence and limits

The expanded Linux runtime driver exercises the real GTK view selector using
X11 keyboard input after opening it, Today/period buttons, search, task and event
preview/Edit/Cancel, and the application menu's Settings destination. Native GTK
menus live outside Flutter's repaint boundary: a boundary PNG alone is not
proof of the menu's pixels. The input helper drives the visible menu, not an
internal application command.

An earlier native Android fixture run completed on the connected phone with all
five views, visible view changes, temporary task search, preview/Edit, creation
and save, dirty Back cancellation/discard, actual system keyboard visibility,
Settings, source sheet, read-only preview, RTL/dark Week and empty Agenda. The
phone driver uses only `io.busystack.busymax.caldavqa` and preserves the phone's
display/font settings and the normal installed application.

The hosted Android matrix is a separate layout check. Its required matrix is
360×800/100%, 412×915/130%, 915×412/130%, 1200×800/100%,
800×1280/200%, and 320×500/200%. It does not qualify native Android resizing,
permissions, authentication, routed local-network access, or live providers.
Layout failures found during this work are not a successful matrix run.

Width reflow preserves the visible day, fractional horizontal position and
vertical position. Direction changes retain the selected period with the
upstream RTL planner's corresponding origin. Initialization callbacks and
inactive retained planners cannot replace the workspace selection. Regression
checks cover both direction transitions and inactive planner callbacks.
The Android period title now uses the same localized heading formatter as
Linux, including the weekday/date context and both Week endpoints. An Arabic
five-view regression checks the actual visible headings against that reference.
The full heading scrolls horizontally when it exceeds the native title area
and remains available by long press, including at 200% text size.
All-day resize targets also reserve a separate move area in narrow cells;
otherwise the boundary targets overlap and a center hold changes the end.
Focused Month tests check move, start resize and end resize independently.
The native clock ruler measures the scaled current-time label before reserving
space from adjacent hour labels; Linux retains its existing spacing.
Native Year starts from the Linux column thresholds and reduces columns when
the measured date numbers need more room at enlarged text. Date numbers stay
on one line without reducing their text scale. The 800×1280/200% regression
checks both glyph bounds and activation of January 12. Event date controls
also retain the localized year, matching the Linux date context.
The failed Nextcloud metadata Save regression checks both live field retention
and identical edited values in the retried PROPPATCH through the real service
with a controlled transport response.
Account headers now share Linux's secondary email/Nextcloud-host projection.
Source account menus also use the shared collection-creation eligibility,
network/running states and Linux command order. Focused account settings remain
reachable through the common Settings → Accounts flow.

Focused touch tests exercise scroll versus mutation, held range preview/commit,
event move, end resize, pointer cancellation, pinch, and distinct assistive preview/completion/dated-slot actions. Existing Linux mouse
movement/resize/cancellation checks are retained. Additional native direct
manipulation and all-day/month boundary usability checks are still required.

## Remaining acceptance work

- Inspect the first-party planner accessibility projection with native TalkBack.
  It describes visible time slots and mounted item anchors, preserves separate
  preview/completion actions and supplies semantic scrolling. Pointer input
  still uses the upstream planner. The labeled/touch-target gates and focused
  action-dispatch tests pass without changing the package.
- Native timed event move/start/end resize and cancellation, inline all-day
  scrolling/expansion, slot/range creation and pinch now pass with saved-state
  assertions. The driver also exercises Month all-day move, both boundaries,
  cancellation and restoration, checking the saved dates after each gesture;
  its actual outcome is recorded with each run. Complete inline Week all-day
  manipulation, edge scrolling and provider confirmation combinations before
  qualifying those remaining interactions.
- Verify every conditional provider field/action and explanation in both
  previews and editors, especially attendee delegation, unsupported recurrence,
  changed destinations/reminders, scheduling delivery and read-only inspection.
- Finish comparing independent/linked contacts details, address-book recovery,
  account registration/reconnect, private certificates and federation states.
  Contacts details now put identity/server and read-only context before source
  switches, Advanced recovery/certificates and final Remove. Their existing
  native-route tests pass; physical authentication/provider writes remain
  unqualified.
- Review all conditional reminder states on the phone. Single-reminder providers
  now use Add → date/time/zone → Remove. iCalendar alarms show empty and locked
  unsupported states and preserve their original precision/type.
- Compare every source capability/context command, inventory failure, settings
  persistence failure and subscription health/recovery state at runtime.
- The required hosted matrix and phone light/dark/RTL and keyboard-open editor
  flows pass. Review provider states separately and keep regression execution,
  visual comparison and native interaction outcomes distinct. The 320×500 at
  200% run also opens dated Month overflow through the visible control.

## Evidence records

The final review artifact directory is `build/parity-rework/` (ignored by Git).
`verification.json` records exact source identity, environment, commands, exit
status, test counts/failures and limitations. `comparison.html` links the paired
Linux, hosted Android and phone images without changing the captured PNGs.
A capture is evidence only for the displayed state and the flow actually
exercised. In particular, viewport screenshot loops are rendering checks, not
visual parity assertions. The first five captures precede workflow mutations;
later stress-matrix captures also include the fixture edits made by the driver.

The same driver now captures the System category, Accounts overview, focused
account detail, Schedule, Notifications, Privacy and Diagnostics using their
visible category controls. GTK menu activation uses real X11 input; Flutter
boundary captures still cannot prove GTK popup pixels outside that boundary.

A fixture pass or a large passing regression suite does not close the remaining
work or establish full Linux-to-Android UI/UX parity.
