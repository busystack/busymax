# Android implementation status

The Android entrypoint composes a Material 3 Schedule, Tasks, and Settings
application independently of the Yaru Linux and Fluent Windows entrypoints.
Compact windows use bottom navigation and wider windows use a navigation rail.
Schedule supports agenda, day, week, month, and year modes, date navigation,
search, source filters, details, maps handoff, and contextual creation. Mobile
event/task editors use the shared drafts and concrete provider capabilities.

The app-owned `busymax_android_platform` plugin owns Google Identity Services,
MSAL, account binding, secure cross-engine account gates, Android system time
settings, document/content URI activation, document-tree export, external URI
handoff, local-network permission, and cold/warm activation delivery. Desktop
OAuth loopback flows are not used by Android.

WorkManager registers unique 15-minute periodic work with a five-minute flex,
network/battery/storage constraints, bounded exponential backoff, and a
replaceable immediate request. A headless provider container uses no widgets.
Foreground and headless mutations serialize by account; notification
reconciliation has its own process-wide gate and signals the foreground engine
after background changes.

Android notification mappings are durable database rows. Reconciliation uses a
90-day/256-alarm horizon, stable collision-safe IDs, generation checks, exact
alarms when allowed and inexact fallback otherwise, quiet hours, private text,
Open/Snooze/Dismiss, due-today deduplication, and sync/conflict status channels.
Snooze/Dismiss persist and reconcile from the background callback without
requiring a live UI engine. Future scheduling is never recorded as proof that a
notification was displayed.

ICS import previews content and destination before mutation; incoming shared
URIs are bounded `content:` reads. Single DAV items and native collections use
Storage Access Framework output. Settings persistence uses flush plus atomic
rename. Backup/transfer rules exclude the secure store, preferences, and local
database. The database itself is app-private but not described as encrypted.

External console registration, production signing, Play app-signing identity,
physical-device lifecycle testing, live disposable-provider accounts, and store
publication cannot be completed from source alone. Their exact verification
state is maintained in [android_verification.md](android_verification.md).
