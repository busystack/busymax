# Android provider parity

Android uses the same repositories, conflict handling, DAV engines, pending
operation rules, and provider capability models as the desktop applications.
The Material editors hide or disable fields and operations not supported by the
selected concrete collection.

| Provider | Authorization | Calendar | Tasks | Administration and limits |
|---|---|---|---|---|
| Google | Native Google Identity Services `AuthorizationClient`; explicit chooser; account-specific silent tokens | Read/write, recurrence, reminders, guests, colors and supported calendar mutation | Read/write Google Tasks fields; no invented reminder/time/recurrence support | Calendar/list creation and supported rename/remove/delete are queued through existing cloud mutations. Google alone is disabled when Play services is absent. |
| Microsoft | Native MSAL multiple-account public client; browser interactive flow; exact native-account silent lookup | Read/write Microsoft Graph calendars and supported recurrence/reminder/attendee fields | Read/write Microsoft To Do including supported due time, reminders, importance, categories, progress, recurrence, and hierarchy | Built-in/non-owner restrictions remain enforced. Signer-specific redirects must be registered. |
| Apple iCloud | CalDAV with user-supplied app-specific password in secure storage | Calendar-only read/write according to server privileges | Not supported | BusyMax does not imply Apple Reminders support or collection creation where the existing capability matrix denies it. |
| Nextcloud | Login Flow v2 and secure app-password storage | CalDAV read/write, native ICS, collection permissions, and Android sharing/publishing/trash/restore routes | VTODO read/write with per-collection DAV capabilities; due/start/completion, status/progress/priority, recurrence, multiple alarms, hierarchy, duplicate/move and native export are exposed when supported | Calendar/task-list create, rename, delete/remove, sharing grants, publish/unpublish, trash restore/permanent delete, reminders, and document-tree native export are available only when server privileges allow them. Local hosts use contextual Android 17 LAN permission and denial aborts onboarding. |
| WebCal | Confirmed subscription URL; embedded credentials remain in credential storage | Read-only subscription refresh and local rename/color metadata | Not supported | No event mutation or provider collection write is presented. |

## Android workflow entry points

| Workflow | Visible route | Capability and permission gate | Input and result behavior |
|---|---|---|---|
| Invitation response | Schedule item detail > **Accept**, **Tentative**, or **Decline** | The current user must be an attendee. Google and Microsoft use their existing response mutations; Nextcloud also requires scheduling reply capability and asks for occurrence/series scope when applicable. | Updates the shared local event projection, queues the account-specific calendar sync, and reports a redacted failure without inventing support for Apple or WebCal. |
| Guest availability | Event editor > **Check guest availability** | A valid start/end and at least one guest are required. Google uses the shared free/busy API. Nextcloud additionally requires a DAV collection with `canQueryFreeBusy`. Microsoft, Apple, and WebCal do not show the action. | Queries the edited guest set and draft interval, then shows a bounded per-recipient free/busy result with refresh and error states. It does not mutate the event. |
| Nextcloud scheduling inbox | Settings > a Nextcloud calendar > **Scheduling inbox** | Requires a Nextcloud DAV calendar; server scheduling capability and responses are enforced by the shared service. | Loads cached then refreshed inbox messages. Acknowledgement is explicitly confirmed and removes the inbox message, not the calendar event. |
| Calendar administration | Settings > calendar > rename/color/delete | Concrete source capabilities determine which actions appear. Queued Google/Microsoft mutations use the existing account-specific pending-calendar sync requester; online DAV administration stays on its shared service path. | Optimistic local changes retain the normal pending/error state and are not duplicated by a second sync subsystem. |
| Diagnostics | Settings > **Diagnostics** | Always local; individual retry/discard actions require a concrete blocked operation. | Shows account/auth and last-sync state, reminder precision, and live blocked operations. Retry is explicit; discard requires confirmation; diagnostic errors are redacted according to Settings. |
| Feedback | Settings > **Send feedback** | Available only when the configured HTTPS feedback endpoint is valid. | Validates category, subject, message, optional reply address, and explicit technical-detail consent; shows stable success/failure state and protects a dirty form from Back. |

These are UI entry points, not live-provider certification. Provider payload,
projection, and capability tests are deterministic; authorization, delivery,
server interoperability, and Android lifecycle behavior retain the device/live
test boundaries in [android_verification.md](android_verification.md).

All five schedule views are available as distinct implementations: virtual
Agenda, time-axis Day/Week, scrollable Month with selected-day agenda, and Year
month miniatures. Android defaults independently to Agenda, while the existing
desktop default remains Week. Creating from the Schedule screen always asks for
a destination when more than one writable calendar or task list exists and
shows the account with the collection, preserving identity even when names or
remote IDs collide. Microsoft's task reminder is edited independently from its
due/start date and time.
