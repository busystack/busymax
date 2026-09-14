# Privacy and data map

This is the canonical repository description of data BusyMax stores locally,
sends to account providers, or hands to external applications. BusyMax does not
add telemetry or analytics.

## Local storage and provider traffic

| Data | Local handling | Network or external destination |
|---|---|---|
| Google/Microsoft OAuth tokens, Apple app-specific password, Nextcloud app password, WebCal subscription secret | Operating-system credential storage on unpackaged Linux and Windows; the strict Snap uses an encrypted Secret portal file | Used only with the selected provider, Nextcloud server, or WebCal endpoint |
| OAuth authorization code, PKCE verifier, and state | Short-lived in memory during browser sign-in; callbacks are restricted to loopback and secrets are redacted from logs | Selected provider's authorization/token endpoints |
| Account, calendar, task-list, event, task, attendee, reminder, recurrence, DAV resource, synchronization, pending-operation, and conflict data | Cached and projected in the Drift database under the platform application-support directory | Selected provider during discovery, synchronization, or a user-requested mutation |
| Local settings | Platform application-support/settings storage | No provider destination |
| iCalendar imports and exports | Read or written only after file activation or explicit user selection; imports require review | No network destination unless confirmed imported content is later synchronized |
| WebCal data | Confirmed URL stored as a credential; downloaded calendar content is cached read-only | Confirmed subscription endpoint |
| Notification schedule and identifier mapping | Stored locally to deliver and deduplicate reminders | Platform notification service as described below |
| Feedback submission | Prepared only after the user selects **Send feedback** | Configured BusyStack feedback HTTPS endpoint |

Credential protection applies to credential records, not to every local database
row. Cached calendar/task content and synchronization metadata in
`busymax.sqlite` are not described as encrypted by BusyMax.

On unpackaged Linux, BusyMax uses the system keyring through its secure-storage
backend. Windows uses the operating-system credential-storage backend. The
strict Snap retrieves key material through the XDG Secret portal and stores an
AES-GCM encrypted credential envelope under its writable data directory. That
directory is restricted to mode `0700` and the file to `0600`; the `posix`
dependency applies and repairs those Linux file permissions. Account removal
deletes the applicable local credential and account data. Remote revocation is
provider-specific and can require a separate user action.

## Locations and external applications

Ordinary location text is event or task content. Normal synchronization sends
it to the selected account provider when that provider and object support the
field. Provider-native Microsoft structured coordinates and iCalendar `GEO`
values remain part of provider data.

When an imported or copied point cannot be represented by a Google Calendar
event, BusyMax can retain a supplemental local `location_resolutions` record.
The record belongs to the exact item or to a scoped Google account, calendar,
provider-series identity, and matching location snapshot. An occurrence-specific
record takes precedence. A series split copies supplemental ownership only when
the new series keeps the location snapshot; the earlier series keeps its own
record. These supplemental coordinates are not uploaded through Google
Calendar and do not appear automatically on another BusyMax installation.
Records are invalidated when the owning location, item, series, calendar, or
account no longer matches.

BusyMax does not geocode, autocomplete, request device location, display an
embedded map, or contact a map service merely because a location is typed,
viewed, saved, or synchronized.

External opening occurs only after the user chooses **Show on map** or
**Open link**. BusyMax hands the saved address or coordinates to a registered
`geo:`/maps handler on Linux, with a Google Maps browser fallback, or to the
default browser on Windows. A complete saved HTTP(S) value opens its own host.
The receiving application or website can receive the destination and normal
network metadata. BusyMax does not retain a separate opening history or mutate
the event/task during this handoff.

## Windows notifications

Windows notification display and activation are separate data flows:

- BusyMax passes the notification title and body to the Windows notification
  API so Windows can display them.
- The toast payload and action arguments contain bounded BusyMax identifiers
  such as the notification schedule, item kind, account, source, and item IDs,
  together with the stable ID and selected action. They do not contain the
  notification title/body, account email, credential, authorization code, or
  token.

Click, Open, Snooze, and Dismiss activation data returns through the packaged
Windows activation bridge. Linux notifications use the desktop notification
service to display reminder content and route actions.

## Feedback

Every explicit feedback submission contains:

- a random submission ID;
- application ID `busymax`, application version, and build number;
- runtime platform;
- category, subject, and message; and
- the optional reply email, or `null` when omitted.

The optional technical-details checkbox is off by default. When selected, it
adds only the operating-system version and application locale. Feedback does
not silently attach logs, account/provider content, calendar/task content,
filenames, screenshots, environment variables, stable device IDs, tokens,
secrets, or activation payloads.

Developers can override the endpoint through `BUSYSTACK_FEEDBACK_ENDPOINT` as
described in [Development](development.md).

## Windows package disclosures

The Windows package declares internet client and full-trust desktop execution
for the Flutter Win32 application. It does not request location, microphone,
webcam, contacts, broad-filesystem, or private-network capability. Import and
export use user-selected files or the declared `.ics` association; startup
uses the user-controlled packaged StartupTask.

Privacy-policy and support URLs are production build inputs. Before release,
review the disclosures actually published for the artifact against this data
map. Client code does not establish provider, website, or feedback-service
retention policies, does not prove that an external privacy page is published,
and does not establish operating-system cleanup after uninstall. Record those
as external policy or installed-package verification rather than inferring
them from the source.
