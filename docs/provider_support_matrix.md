# Provider support matrix

This page is the central comparison of BusyMax's provider capabilities.
Available actions also depend on account state and the permissions reported for
a specific calendar or task list. A visible or enabled control is not evidence
that a workflow has completed live-provider verification.

## Services and authentication

| Provider | Calendar service | Task service | Account connection |
|---|---|---|---|
| Google | Google Calendar | Google Tasks | Browser OAuth with a configured desktop client |
| Microsoft | Microsoft Calendar | Microsoft To Do | Browser OAuth with a configured public client |
| Apple | iCloud Calendar | Not supported | Apple Account email and app-specific password |
| Nextcloud | CalDAV events | CalDAV tasks | Login Flow v2 in the default browser |
| WebCal | Read-only subscription | Not supported | Confirmed subscription URL |

Apple Reminders, generic CalDAV accounts, Nextcloud Deck, and Nextcloud Notes
are not supported. Production connections require normal platform TLS
validation; BusyMax has no HTTP or invalid-certificate mode. The loopback HTTP
fixtures documented for live tests are test-only.

## Event objects

| Capability | Google | Microsoft | Apple iCloud | Nextcloud | WebCal |
|---|---|---|---|---|---|
| View events | Yes | Yes | Yes | Yes | Yes |
| Create, edit, delete | Supported | Supported | Writable calendars | Permission-dependent | No |
| All-day and timed events | Yes | Yes | Yes | Yes | Preserved for display |
| Recurrence and reminders | Yes | Yes | Preserved and editable subset | Preserved and editable subset | Read-only |
| Attendee editing | Yes | Yes | No | Permission- and scheduling-dependent | No |
| Free/busy workflow | Yes | Work/school accounts only | No | Permission- and scheduling-dependent | No |
| Attachments | Supplied links can be opened; reference editing is not yet exposed | Event/task lists and explicit file downloads; addition/removal not yet exposed | Preserved when present | Supplied URI references can be opened; reference editing is not yet exposed | Read-only |

DAV-backed events preserve data BusyMax does not edit, including recurrence
exceptions, alarms, timezones, parameters, and provider extensions. See the
[iCalendar and DAV data model](icalendar_data_model.md).

Google and Microsoft start with a bounded synchronization window. Navigating
to another month or using a date-bounded search retrieves that period on
demand when online; a failed or offline retrieval retains cached events and
marks the range incomplete. Unrestricted **Any date** search searches only
downloaded data. The additional range snapshots do not replace the baseline
incremental-sync cursor.

Native event details show the full interval, available description and guest
information, and provider-supplied meeting links even on read-only calendars.
Nextcloud's ordinary event URL is shown as an event link; only a preserved
conference property is presented as a meeting link. Link opening still depends
on the system browser and on the provider returning a valid URL.

Attachment references in Google and Nextcloud event details open without
passing provider credentials to those URLs. Microsoft event and task attachment
metadata is fetched only when requested; a `hasAttachments` flag does not mean
an empty list. Microsoft file downloads require an explicit native save action.
This is read/access support, not yet an attachment add/remove workflow.

Android's event editor retains untouched recurrence and reminder data. Its
native recurrence dialog edits the shared supported interval, weekday, and
ending subset, while unsupported rules remain unchanged until explicitly
replaced. The reminder control distinguishes provider default, no reminder,
and a zero-minute reminder; multiple existing reminders remain visible and
unchanged until replaced. Guest rows allow required/optional roles, and Meet
or Teams creation is offered only when the selected calendar advertises that
conference solution.

On Android, supported invitation responses are visible from an invitation's
Schedule detail sheet. Google and eligible Microsoft guest availability is
available in the event editor on all three native platforms after at least one
guest and a valid interval are present. Microsoft uses Graph `getSchedule`;
personal Microsoft accounts are unsupported, and recipient-specific failures
remain unknown rather than appearing free. Capability-enabled Nextcloud guest
availability retains its effective `canQueryFreeBusy` gate. A capability-enabled
Nextcloud calendar exposes its scheduling inbox from **Settings > calendar >
Scheduling inbox**.

## Task objects

| Capability | Google Tasks | Microsoft To Do | Nextcloud Tasks |
|---|---|---|---|
| Create, edit, complete, delete | Yes | Yes | Permission-dependent |
| Due date | Date only | Date and time | Date or date-time |
| Start date/time | No | Yes | Yes |
| Reminder | No | Single provider reminder | Multiple iCalendar alarms |
| Recurrence | No | Provider recurrence subset | BusyMax/Nextcloud editable subset |
| Importance/categories | No | Yes | Yes |
| Hierarchy | Yes | Yes | Yes |
| Move between lists | Yes | Not exposed | Between writable Nextcloud lists |
| Status/progress/completed time | Completion only | Provider completion state | iCalendar status, percentage, and completion time |
| Location, URL, classification | No | No | Yes |
| Advanced iCalendar fields | No | No | Priority, alarms, recurrence, pinning, and subtask visibility |
| Task source links | Supplied assignment/related/task-page URLs | Task-scoped linked resources fetched on request | Preserved task URL where present |

Google exposes assigned and hidden tasks from its API. Docs-assigned tasks
cannot receive notes, and assigned tasks cannot become subtasks or parents;
other permitted edits and top-level ordering remain available. Deletion of an
assigned task requires a warning because it also deletes the original in Docs
or Chat Spaces. Google source links remain available from cached task metadata
offline. Microsoft linked resources require an online Graph detail request and
may be unavailable without affecting task edits or completion. Nextcloud
recurrence rules or alarm forms outside BusyMax's editable subset remain
preserved and read-only;
detached task occurrences are not edited directly.

## Collection administration

Object editing and collection administration are separate capabilities.

| Capability | Google | Microsoft | Apple iCloud | Nextcloud | WebCal |
|---|---|---|---|---|---|
| Create calendar | Yes | Yes | No | Online, with permission | No |
| Rename/recolor/delete calendar | Yes | Yes | No | Online, property/owner permission-dependent | No |
| Create task list | Yes | Yes | No | Online, with permission | No |
| Rename/delete task list | Yes | Yes | No | Permission-dependent | No |
| Share or publish collections | No | No | No | Advertised, permission-dependent | No |
| Restore deleted objects/collections | No | No | No | Advertised, permission-dependent | No |
| Native collection import/export | No | No | No | Supported subset | No |

Deleting an owned mixed Nextcloud collection removes both its events and tasks.
Removing a received share removes the recipient's access. Nextcloud scheduling,
sharing, publishing, trash, and native import/export behavior is described in
[Nextcloud setup](nextcloud_setup.md) and the
[technical reference](icalendar_data_model.md).

## Offline and verification boundaries

All providers cache calendar/task data locally for viewing. Queued offline
changes are supported where the provider adapter and collection permissions
allow them; collection administration and several Nextcloud collaboration
operations require a live server. Conflicting DAV writes use conditional
requests and can require user resolution.

Deterministic tests cover projections, provider adapters, DAV preservation,
permission handling, mutation queues, conflicts, and UI state. Real account
authorization, provider delivery, server/version interoperability, installed
desktop integration, and permission changes still require the
[live-provider test guide](live_provider_testing.md) and the applicable release
checklist.
