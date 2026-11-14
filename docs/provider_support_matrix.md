# Provider support matrix

This page is the central comparison of BusyMax's provider capabilities.
Available actions also depend on account state and the permissions reported for
a specific calendar or task list. A visible or enabled control is not evidence
that a workflow has completed live-provider verification.

## Services and authentication

| Provider | Calendar service | Task service | Account connection |
|---|---|---|---|
| Google | Google Calendar | Google Tasks | Configured desktop browser OAuth; native Google Identity Services on Android |
| Microsoft | Microsoft Calendar | Microsoft To Do | Configured desktop public-client OAuth; native MSAL on Android |
| Apple | iCloud Calendar | Not supported | Apple Account email and app-specific password |
| Nextcloud | CalDAV events | CalDAV tasks | Login Flow v2 in the default browser |
| CalDAV | Advertised VEVENT collections | Advertised VTODO collections | HTTPS server URL, username and password/app password |
| WebCal | Read-only subscription | Not supported | Confirmed subscription URL |

Apple Reminders, Nextcloud Deck, and Nextcloud Notes
are not supported. Production connections require normal platform TLS
validation; BusyMax has no HTTP or invalid-certificate mode. The loopback HTTP
fixtures documented for live tests are test-only.

Generic CalDAV uses the existing DAV resource, queue and synchronization model.
It supports writable event/task CRUD, supported recurrence and alarms,
preservation of unknown iCalendar fields, and permission-dependent collection
administration. Mixed collections retain one remote identity. Missing optional
ACL information is shown as unknown; conditional user-requested operations can
still be rejected by the server. Cross-list task movement requires advertised
MOVE support. Nextcloud-specific pinning and subtask-visibility extensions,
sharing, federation, trash, certificate exceptions and scheduling are not
enabled for generic accounts. Standard resource import/export reuses the DAV
implementation. See [CalDAV setup](caldav_setup.md) and the per-server
[qualification matrix](caldav_qualification.md) for tested scope and limits.

The current qualification targets are Radicale 3.9.0, Baïkal 0.13.0
(sabre/dav 4.7.1) and BusyStack CalDAV Server 0.1.0. BusyStack uses separately
issued DAV credentials and separate event/task collections; its normal account
password is not a DAV password. These are server configurations of the same
CalDAV provider. The three-server Android connection/editor and collection-recovery
feedback workflows are qualified on Android 10/API 29.
Native Windows and Android 17 permission-prompt acceptance remain unverified;
see the qualification record for actual runtime evidence.

Android Google authorization requires Google Play services; when absent, only
Google is unavailable. Microsoft requires a registered MSAL redirect matching
the certificate that signs the installed APK. Android uses native account
authorization rather than desktop loopback flows. Local Nextcloud and CalDAV hosts on
Android 17 require contextual local-network permission; denial stops the
connection. See [Android setup](android_setup.md) for registrations and
permissions.

## Event objects

| Capability | Google | Microsoft | Apple iCloud | Nextcloud | WebCal | CalDAV |
|---|---|---|---|---|---| --- |
| View events | Yes | Yes | Yes | Yes | Yes | Yes |
| Create, edit, delete | Supported | Supported | Writable calendars | Permission-dependent | No | Permission-dependent conditional writes |
| All-day and timed events | Yes | Yes | Yes | Yes | Preserved for display | Yes |
| Recurrence and reminders | Yes | Yes | Preserved and editable subset | Preserved and editable subset | Read-only | Preserved and editable subset |
| Attendee editing | Yes | Yes | No | Permission- and scheduling-dependent | No | No; metadata preserved |
| Free/busy workflow | Yes | Work/school accounts only | No | Permission- and scheduling-dependent | No | No |
| Attachments | Supplied links open; permission-gated event reference add/remove using an existing HTTPS file URL | Event/task lists, explicit file downloads, and permission-gated file addition/removal | Preserved when present | Supplied URI references open; permission-gated URI `ATTACH` add/remove through the DAV queue | Read-only | Event/task HTTP/HTTPS references open; inline binary contents explicitly save; raw properties preserved; no upload service |
| Provider-native event organization | Calendar-scoped event labels can be selected or cleared; ordinary event colors remain separate | Existing mailbox categories can be selected by name and viewed with their account colors; multiple assignments remain intact | Existing fields preserved | Existing categories preserved | Read-only | iCalendar categories preserved |
| Status events | Primary-calendar focus time, out-of-office, and working location, subject to Google's account eligibility and provider validation | No special authoring | No special authoring | No special authoring | Read-only | No special authoring |

DAV-backed events preserve data BusyMax does not edit, including recurrence
exceptions, alarms, timezones, parameters, and provider extensions. See the
[iCalendar and DAV data model](icalendar_data_model.md).

Google and Microsoft start with a bounded synchronization window. Navigating
to another month or using a date-bounded search retrieves that period on
demand when online; a failed or offline retrieval retains cached events and
marks the range incomplete. Unrestricted **Any date** search searches only
downloaded data. The additional range snapshots do not replace the baseline
incremental-sync cursor.

Individual export distinguishes a standalone occurrence from an entire
recurring series. Google and Microsoft series export reads the provider's
master and exception identities online before writing an iCalendar file; it
does not call a finite local month cache a complete backup. Nextcloud, generic
CalDAV and iCloud resource export keeps the effective original iCalendar document,
including pending local changes. A standalone occurrence export remains a
portable snapshot, not a series backup. Provider fields that iCalendar cannot
represent are not silently treated as a complete provider-account backup.
WebCal and cloud events still awaiting a remote identity offer occurrence
export only; they do not claim an authoritative series export.

Native event details show the full interval, available description and guest
information, and provider-supplied meeting links even on read-only calendars.
Nextcloud's ordinary event URL is shown as an event link; only a preserved
conference property is presented as a meeting link. Link opening still depends
on the system browser and on the provider returning a valid URL.

Google event-label IDs belong to a single calendar. BusyMax requests label
metadata for the selected calendar and uses Google's label-version request
semantics only for explicit label mutations. Unknown labels and Microsoft
category names remain on events when optional metadata lookup is unavailable.
Microsoft's master-category lookup requests `MailboxSettings.Read` separately;
declining that grant does not block ordinary event or task editing. Google's
status-event controls are limited to eligible primary calendars, retain
type-specific properties, and do not permit changing an existing event's type.
BusyMax does not infer Workspace eligibility from an email address; Google's
rejection is reported instead of converting a status event to an ordinary one.

Attachment references in Google and Nextcloud event details open without
passing provider credentials to those URLs. Microsoft event and task attachment
metadata is fetched only when requested; a `hasAttachments` flag does not mean
an empty list. Microsoft file downloads require an explicit native save action.
Eligible Microsoft event and task details also offer file addition/removal;
an upload error with an uncertain remote outcome requires a refresh before
retrying. Google reference changes read the event's authoritative attachment
array and use its ETag; they never delete the underlying Drive file. Nextcloud
URI-reference changes preserve unrelated iCalendar properties, parameters,
binary attachments, and pending DAV mutations. Neither workflow provides file
browsing or upload to Drive or Nextcloud Files.

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

| Capability | Google Tasks | Microsoft To Do | Nextcloud Tasks | CalDAV VTODO |
|---|---|---|---| --- |
| Create, edit, complete, delete | Yes | Yes | Permission-dependent | Permission-dependent |
| Due date | Date only | Date and time | Date or date-time | Date or date-time |
| Start date/time | No | Yes | Yes | Yes |
| Reminder | No | Single provider reminder | Multiple iCalendar alarms | Multiple iCalendar alarms |
| Recurrence | No | Provider recurrence subset | BusyMax/Nextcloud editable subset | BusyMax editable subset |
| Importance/categories | No | Yes | Yes | Yes |
| Hierarchy | Yes | Yes | Yes | RELATED-TO hierarchy |
| Move between lists | Yes | Not exposed | Between writable Nextcloud lists | Advertised MOVE and suitable source/destination rights |
| Status/progress/completed time | Completion only | Provider completion state | iCalendar status, percentage, and completion time | iCalendar status, percentage and completion time |
| Location, URL, classification | No | No | Yes | Yes |
| Advanced iCalendar fields | No | No | Priority, alarms, recurrence, pinning, and subtask visibility | Priority, alarms and supported recurrence; no Nextcloud pinning/visibility controls |
| Task source links | Supplied assignment/related/task-page URLs | Task-scoped linked resources fetched on request | Preserved task URL where present | Preserved task URL where present |

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

| Capability | Google | Microsoft | Apple iCloud | Nextcloud | WebCal | CalDAV |
|---|---|---|---|---|---| --- |
| Create calendar | Yes | Yes | No | Online, with permission | No | Online, advertised method and permission-dependent |
| Rename/recolor/delete calendar | Yes | Yes | No | Online, property/owner permission-dependent | No | Online, guarded property/parent permission checks |
| Create task list | Yes | Yes | No | Online, with permission | No | Online, advertised method and permission-dependent |
| Rename/delete task list | Yes | Yes | No | Permission-dependent | No | Online, guarded permission checks |
| Share or publish collections | Owner-calendar ACL list/add/role/revoke from native settings; no public/domain administration | Signed-in primary-calendar permission list/add/role/revoke from native settings; provider allowed-role/removability enforced | No | Advertised, permission-dependent; calendar federation initiation on supported servers | No | No |
| Restore deleted objects/collections | No | No | No | Advertised, permission-dependent | No | No |
| Native collection import/export | No | No | No | Supported subset | No | Supported resource subset |

Deleting an owned mixed Nextcloud or generic CalDAV collection removes both its
events and tasks.
Removing a received share removes the recipient's access. Nextcloud scheduling,
sharing, publishing, trash, and native import/export behavior is described in
[Nextcloud setup](nextcloud_setup.md) and the
[technical reference](icalendar_data_model.md).

Google and Microsoft sharing administration is available from Linux, Windows,
and Android settings for eligible calendars. Google requires an owner access
role; Microsoft management targets the signed-in account's primary calendar,
not every recipient-local or delegated calendar. Provider denials and revoked
access remain errors rather than local-only changes. A successful grant with a
failed follow-up refresh is shown as committed but requires a fresh list before
another change. Public publishing, ownership transfer, and domain-wide
administration are not included.

Nextcloud calendar sharing accepts local users/groups and a validated
federated ID when the installed server supports calendar federation. BusyMax
sends the share only through the authenticated local DAV server. Nextcloud 32
provides read-only federation; writable federated shares require Nextcloud 33
or later.

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
[live-provider tests](development.md#live-provider-tests) and the applicable
release checklist.
