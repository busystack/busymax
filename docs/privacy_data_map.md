# Privacy and data map

BusyMax processes calendar, event, task, account, reminder, and synchronization
data to provide its user-requested desktop functions. It does not add telemetry
or analytics.

| Data | Purpose | Local handling | Network destination |
|---|---|---|---|
| OAuth access/refresh tokens and DAV app passwords | Authenticate selected accounts | Windows secure-storage backend or Linux portal/keyring backend; removed on sign-out/account removal as applicable | Google, Microsoft, Apple iCloud, or the user's Nextcloud server over HTTPS |
| OAuth authorization code, PKCE verifier, and state | Complete browser/loopback sign-in | Short-lived in memory; callback binds only to loopback; never logged | Selected provider token endpoint |
| Calendar/event/task/source identifiers and content | Display, edit, synchronize, recur, import/export, and work offline | Drift database in the user-writable application-support directory | Only the account provider selected by the user |
| Reminder schedule rows | Deliver in-process reminders and make actions idempotent | Drift; stopped by explicit Quit | No new scheduling service; Windows toast receives stable opaque IDs only |
| `.ics` files and export destinations | User-requested import review/export | Read or written only through explicit activation/file selection; external activation never silently imports | None unless the user later synchronizes confirmed content |
| WebCal URI | User-requested calendar subscription | Validated and confirmed before subscription | The confirmed HTTPS/WebCal calendar endpoint |
| Local settings | Theme, locale, notification, tray, and startup preferences | User-writable settings storage | None |
| Feedback category, subject, message, optional reply email, random submission ID, app/version/build/platform | Submit feedback requested by the user | Prepared only for an explicit submission | Configured BusyStack feedback HTTPS endpoint |
| Optional feedback technical details | Diagnose explicitly reported issues | OS version and application locale only; checkbox is off by default | Same feedback endpoint when the user opts in |

Feedback never silently attaches logs, account/provider content, calendar/task
content, filenames, screenshots, environment variables, stable device IDs,
tokens, secrets, or activation payloads.

Windows package declarations are limited to internet client and full-trust
desktop execution needed by Flutter Win32. BusyMax does not request location,
microphone, webcam, contacts, broad-filesystem, or private-network capability.
File import/export uses the selected file or manifest-declared `.ics`
association. Startup uses the user-controlled package StartupTask.

The Windows privacy-policy and support URLs are build inputs. Production
validation rejects missing, placeholder, or non-HTTPS values. App disclosures
and the external privacy page must be reviewed whenever provider calls,
feedback fields, storage behavior, or package capabilities change.

Uninstall and package-update retention behavior must be verified with the
installed MSIX because Windows owns package data lifecycle. BusyMax never writes
the database or credentials into the immutable MSIX installation directory.
