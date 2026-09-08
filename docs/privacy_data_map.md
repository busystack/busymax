# Privacy and data map

BusyMax processes calendar, event, task, account, reminder, and synchronization
data to provide its user-requested desktop functions. It does not add telemetry
or analytics.

| Data | Purpose | Local handling | Network destination |
|---|---|---|---|
| OAuth access/refresh tokens and DAV app passwords | Authenticate selected accounts | Windows secure-storage backend or Linux portal/keyring backend; removed on sign-out/account removal as applicable | Google, Microsoft, Apple iCloud, or the user's Nextcloud server over HTTPS |
| OAuth authorization code, PKCE verifier, and state | Complete browser/loopback sign-in | Short-lived in memory; callback binds only to loopback; never logged | Selected provider token endpoint |
| Calendar/event/task/source identifiers and content, including location text | Display, edit, synchronize, recur, import/export, and work offline | Drift database in the user-writable application-support directory | The account provider selected by the user during normal synchronization; location is calendar/task content and can be synchronized |
| Provider-native coordinates | Preserve imported/provider `GEO` and Microsoft structured locations, including through synchronization and copies | Native coordinate columns projected from the provider or iCalendar resource | The selected calendar provider during normal synchronization when its format supports coordinates; external application only after activation |
| Supplemental coordinates (item identity, location snapshot, point, source, attribution) | Retain an imported/copied point when a Google event cannot store it natively, and preserve valid existing records through owner reconciliation | One `location_resolutions` row for the exact saved owner and location snapshot; ordinary text edits and native-coordinate creation do not author another row | Not uploaded through Google Calendar and not automatically available on another installation; passed to an external application only after activation |
| User-activated external location destination | Open a saved address, coordinate, or complete HTTP(S) location value | Prepared locally for one handoff; not retained as opening history and does not mutate the saved item | Registered `geo:`/`maps:` handler on Linux; Google Maps in the browser after native-handler failure; default browser on Windows; a supplied complete HTTP(S) link goes to its own host |
| Reminder schedule rows | Deliver in-process reminders and make actions idempotent | Drift; stopped by explicit Quit | No new scheduling service; Windows toast receives stable opaque IDs only |
| `.ics` files and export destinations | User-requested import review/export | Read or written only through explicit activation/file selection; external activation never silently imports | None unless the user later synchronizes confirmed content |
| WebCal URI | User-requested calendar subscription | Validated and confirmed before subscription | The confirmed HTTPS/WebCal calendar endpoint |
| Local settings | Theme, locale, notification, tray, and startup preferences | User-writable settings storage | None |
| Feedback category, subject, message, optional reply email, random submission ID, app/version/build/platform | Submit feedback requested by the user | Prepared only for an explicit submission | Configured BusyStack feedback HTTPS endpoint |
| Optional feedback technical details | Diagnose explicitly reported issues | OS version and application locale only; checkbox is off by default | Same feedback endpoint when the user opts in |

Feedback never silently attaches logs, account/provider content, calendar/task
content, filenames, screenshots, environment variables, stable device IDs,
tokens, secrets, or activation payloads.

BusyMax performs no location autocomplete or geocoding and sends no location
query to a geocoder. Merely typing a location, opening an editor, loading a
calendar, or synchronizing does not initiate map traffic. Normal calendar/task
synchronization may still send stored location content to the selected account
provider.

External opening happens only after activation. BusyMax passes the selected
saved text or coordinates to the registered external maps handler; if Linux
native launching fails, or on Windows, it opens a Google Maps search in the
default browser. A complete HTTP(S) location value is instead passed directly
to its host. Those external applications and sites can receive the destination
and related network metadata. BusyMax does not request the device's current
location. Opening does not edit an event/task, update timestamps or dirty flags,
or enqueue synchronization.

Existing source and attribution values in `location_resolutions` remain stored
as provenance. Records follow unambiguous owner reconciliation and are
invalidated when their owner's location snapshot changes or the owner is
deleted. BusyMax does not bulk-delete older records merely because their point
also exists natively or their provenance names a retired service.
The removed renderer's former `maps` application-cache child is inactive; the
database, credentials, and unrelated caches are not cleanup targets.

Windows package declarations are limited to internet client and full-trust
desktop execution needed by Flutter Win32. BusyMax does not request location,
microphone, webcam, contacts, broad-filesystem, or private-network capability.
File import/export uses the selected file or manifest-declared `.ics`
association. Startup uses the user-controlled package StartupTask.

The Windows privacy-policy and support URLs are build inputs. Production
validation rejects missing, placeholder, or non-HTTPS values. App disclosures
and the external privacy page must be reviewed whenever provider calls,
feedback fields, storage behavior, or package capabilities change.
Before release, maintainers must update the public privacy page to describe the
user-requested external handoff and removal of geocoding/tile processing. This
repository documents that external release action; it does not claim the public
page has already been published.

Uninstall and package-update retention behavior must be verified with the
installed MSIX because Windows owns package data lifecycle. BusyMax never writes
the database or credentials into the immutable MSIX installation directory.
