# Android implementation status

The Android entrypoint composes a Material 3 Schedule, Tasks, and Settings
application independently of the Yaru Linux and Fluent Windows entrypoints.
Compact windows use bottom navigation and wider windows use a navigation rail.
Schedule supports a virtual agenda, day/week time grids with all-day and
overlap placement, a civil-date month grid with selected-day agenda, and a
year of month miniatures. Date navigation, search, calendar/task-list filters,
details, maps handoff, and contextual creation are Android-owned Material
flows. Empty periods retain the selected calendar view, and intersecting
overnight/multiday events appear on every applicable day. Mobile event/task
editors use concrete provider capabilities, account-qualified destinations,
discard confirmation, and encrypted draft recovery.

The app-owned `busymax_android_platform` plugin owns Google Identity Services,
MSAL, account binding, secure cross-engine account gates, Android system time
settings, document/content URI activation, document-tree export, external URI
handoff, local-network permission, and cold/warm activation delivery. Desktop
OAuth loopback flows are not used by Android.

WorkManager registers separate unique 15-minute provider-sync and local
notification-refill jobs. Provider sync requires a network; reminder refill
does not, so cached reminders are maintained while offline or after a provider
failure. Both use battery/storage constraints and bounded exponential backoff,
and provider mutations can also request a replaceable immediate sync. A
headless provider container uses no widgets. Foreground and headless mutations
serialize by account; notification reconciliation has its own process-wide
gate. Native leases are engine-owned and released both by the worker stop
callback and native engine teardown, preventing an abandoned worker from
holding synchronization indefinitely.

Android notification mappings are durable database rows. Reconciliation uses a
90-day/256-alarm horizon, stable collision-safe IDs, generation checks, exact
alarms when allowed and inexact fallback otherwise, quiet hours, private text,
Open/Snooze/Dismiss, due-today deduplication, and sync/conflict status channels.
Quiet-hour-adjusted delivery time is used for reconciliation, pending overdue
inexact alarms are retained, and privacy/precision changes replace stale
registrations. The explicit Open action launches the UI. Ordinary reminder
creation requests notification permission. Snooze/Dismiss persist and
reconcile from the background callback without requiring a live UI engine.
Future scheduling is never recorded as proof that a notification was displayed.

ICS import previews content and destination before mutation; incoming shared
URIs are bounded `content:` reads. Content-provider reads and document writes
run off Android's UI thread. Single DAV items and native collections use
Storage Access Framework output. Android routes expose supported Nextcloud
sharing, publishing, trash/restore, task hierarchy, advanced VTODO fields, and
native export. Android 17 local-network permission is requested only for
contextual hostnames/private addresses and denial stops onboarding. Settings
persistence uses flush plus atomic rename. Backup/transfer rules exclude the
secure store, preferences, and local database. The database itself is
app-private but not described as encrypted.

External console registration, production signing, Play app-signing identity,
physical-device lifecycle testing, live disposable-provider accounts, and store
publication cannot be completed from source alone. Their exact verification
state is maintained in [android_verification.md](android_verification.md).
