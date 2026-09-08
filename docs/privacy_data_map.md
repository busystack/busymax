# Privacy and data map

BusyMax processes calendar, event, task, account, reminder, and synchronization
data to provide its user-requested desktop functions. It does not add telemetry
or analytics.

| Data | Purpose | Local handling | Network destination |
|---|---|---|---|
| OAuth access/refresh tokens and DAV app passwords | Authenticate selected accounts | Windows secure-storage backend or Linux portal/keyring backend; removed on sign-out/account removal as applicable | Google, Microsoft, Apple iCloud, or the user's Nextcloud server over HTTPS |
| OAuth authorization code, PKCE verifier, and state | Complete browser/loopback sign-in | Short-lived in memory; callback binds only to loopback; never logged | Selected provider token endpoint |
| Calendar/event/task/source identifiers and content | Display, edit, synchronize, recur, import/export, and work offline | Drift database in the user-writable application-support directory | The account provider selected by the user; location text is additionally sent to Geoapify only when the user types in location search, explicitly submits a lookup, or opens a map that needs resolution |
| Location-search text and result area | Suggest or resolve a destination after a user action | Search requests and responses are held in memory; no search history is created | Geoapify over HTTPS |
| Map tile coordinates, style, scale, and IP/network metadata | Render the map area the user chose to open | Fresh tiles may be cached in the application-cache directory, with a configured 100 MiB target; this performance cache is not guaranteed offline coverage | Geoapify and its map-data delivery infrastructure over HTTPS |
| Remembered map selection (item identity, current location-text snapshot, label, point, source, attribution) | Reopen the same saved item's selected destination without modifying calendar/task content | Drift database; isolated by item, account, and collection and removed/reconciled with the owning item lifecycle | None after it has been stored locally |
| Directions destination (coordinates when available, otherwise location text) | Open directions only when requested | Not retained by BusyMax as directions history | Google Maps in the system browser |
| Reminder schedule rows | Deliver in-process reminders and make actions idempotent | Drift; stopped by explicit Quit | No new scheduling service; Windows toast receives stable opaque IDs only |
| `.ics` files and export destinations | User-requested import review/export | Read or written only through explicit activation/file selection; external activation never silently imports | None unless the user later synchronizes confirmed content |
| WebCal URI | User-requested calendar subscription | Validated and confirmed before subscription | The confirmed HTTPS/WebCal calendar endpoint |
| Local settings | Theme, locale, notification, tray, and startup preferences | User-writable settings storage | None |
| Feedback category, subject, message, optional reply email, random submission ID, app/version/build/platform | Submit feedback requested by the user | Prepared only for an explicit submission | Configured BusyStack feedback HTTPS endpoint |
| Optional feedback technical details | Diagnose explicitly reported issues | OS version and application locale only; checkbox is off by default | Same feedback endpoint when the user opts in |

Feedback never silently attaches logs, account/provider content, calendar/task
content, filenames, screenshots, environment variables, stable device IDs,
tokens, secrets, or activation payloads.

BusyMax sends Geoapify only the text needed for a requested location lookup and
the tile coordinates/style needed for a map the user opened. It does not send
event titles, descriptions, attendees, account identifiers, calendar access
tokens, or device-location data to Geoapify. The app requests no device-location
permission. Geoapify result attribution is retained with remembered selections.
Opening or remembering a map resolution does not edit an event/task or enqueue a
provider synchronization operation.

Windows package declarations are limited to internet client and full-trust
desktop execution needed by Flutter Win32. BusyMax does not request location,
microphone, webcam, contacts, broad-filesystem, or private-network capability.
File import/export uses the selected file or manifest-declared `.ics`
association. Startup uses the user-controlled package StartupTask.

The Windows privacy-policy and support URLs are build inputs. Production
validation rejects missing, placeholder, or non-HTTPS values. App disclosures
and the external privacy page must be reviewed whenever provider calls,
feedback fields, storage behavior, or package capabilities change.
Before releasing maps, maintainers must update the public privacy policy to
describe Geoapify search/tile processing, local tile and selection storage, and
the user-requested Google Maps handoff. This repository documents that required
update; it does not claim the external policy has already been published.

Uninstall and package-update retention behavior must be verified with the
installed MSIX because Windows owns package data lifecycle. BusyMax never writes
the database or credentials into the immutable MSIX installation directory.
