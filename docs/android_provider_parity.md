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
| Nextcloud | Login Flow v2 and secure app-password storage | CalDAV read/write, native ICS, collection permissions, sharing/publishing/trash services | VTODO read/write with per-collection DAV capabilities | Calendar/task-list create, rename, delete/remove, reminders, and document-tree native export are available only when server privileges allow them. Local hosts use contextual Android 17 LAN permission. |
| WebCal | Confirmed subscription URL; embedded credentials remain in credential storage | Read-only subscription refresh and local rename/color metadata | Not supported | No event mutation or provider collection write is presented. |

All five schedule views are available. Android defaults independently to
Agenda, while the existing desktop default remains Week. Creating from the
Schedule screen always asks for a destination when more than one writable
calendar or task list exists, preserving account/list identity even when remote
IDs collide.
