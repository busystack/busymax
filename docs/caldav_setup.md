# CalDAV accounts

Choose **Add CalDAV account** in Settings. Enter your server URL, username and
password (or an app password issued by your server). BusyMax discovers calendars
and task lists using the same account type for compatible servers. Choose the
collections to display after connection.

The URL must use HTTPS with a valid certificate. Custom ports and installation
paths are supported, for example `https://calendar.example.org:8443/team/dav/`.
Use the exact endpoint supplied by your administrator. BusyMax preserves
significant paths and encoded path components. URLs containing passwords,
fragments or query strings are rejected. Basic authentication over HTTPS is
supported; Digest, OAuth and email/domain DNS discovery are not offered.

An origin-root URL uses `/.well-known/caldav` with a direct-URL fallback. An
explicit installation or DAV endpoint is verified directly. Redirects cannot
authorize another origin or downgrade to HTTP. If your administrator redirects
to a different host or port, enter that verified HTTPS endpoint explicitly.
An installation landing page can fall back to the origin's well-known endpoint;
a successful HTML page alone never establishes a connected account.

## Radicale

Configure authentication and rights on the server before connecting. Supply its
HTTPS root or the configured reverse-proxy installation URL. Calendars can be
restricted to `VEVENT`, `VTODO`, or both. A task-only collection appears as a
task list; a mixed collection appears in both views with one remote identity.
Collection creation depends on server methods and your rights.

## Baïkal

Use the HTTPS DAV endpoint, usually `https://example.org/dav.php/`, or
`https://example.org/baikal/dav.php/` for a non-root installation. Obtain the
username/password from the administrator, independently of the administrator
web-console login. Default calendars may support only events. Enable **VTODO**
in Baïkal's calendar administration to use a collection for tasks; enable
VEVENT and VTODO for a mixed collection. BusyMax reads the advertised component
set rather than assuming every calendar supports tasks.

## Editing and synchronization

Writable collections support event and task creation, editing, completion and
deletion through the existing editors. Supported recurrence and alarm controls
edit the shared iCalendar subset. Unknown properties, parameters, attendees,
organizers and recurrence forms outside that subset remain in the stored
resource. Changing an unrelated field preserves them. Cross-list task moves
require advertised MOVE support and suitable permissions on both lists.

Whole-event moves on the same server use native HTTP MOVE when the calendar
ownership establishes the same scheduling principal, including calendars shown
under separate BusyMax accounts. MOVE preserves the complete resource: UID,
organizer, attendees and their responses, recurrence exceptions, alarms and
custom properties. Both calendars must authorize the operation and the source
must advertise MOVE support. An unsupported or rejected MOVE never falls back
to PUT followed by DELETE.

Meetings cannot be transferred transparently between different servers or
scheduling principals. Such a transfer needs explicit invitation, cancellation
and response handling; BusyMax keeps the original instead of performing it.
Personal events can be transferred between CalDAV/Nextcloud accounts using
their complete iCalendar data. The destination is read back and verified before
the original is deleted (or the selected occurrence is cancelled). A destination
that cannot preserve the complete CalDAV event is rejected.

These boundaries follow the resource preconditions in
[RFC 4791 §5.3.2.1](https://www.rfc-editor.org/rfc/rfc4791#section-5.3.2.1)
and the calendar-to-calendar MOVE semantics in
[RFC 6638 §3.2.3.4](https://www.rfc-editor.org/rfc/rfc6638#section-3.2.3.4).

Offline item edits enter a durable queue. Reconnection replays conditional
writes with ETags; conflicts remain visible for resolution. Failed refreshes do
not establish that cached items were deleted. Collection administration needs
an online connection. Deleting a mixed remote collection deletes both its
events and tasks, subject to the existing confirmation process.

When the server omits optional privilege information, BusyMax labels permission
as unknown. A requested edit may be attempted conditionally and the server can
reject it. Unknown privilege information is not a promise of write access.
Explicit read-only restrictions disable mutations.

Basic CalDAV does not imply invitation delivery. Generic accounts do not expose
Nextcloud login, sharing, trash, federation, attachment services, certificate
exceptions or scheduling controls. Scheduling metadata is preserved. Use the
dedicated Nextcloud account type for its supported extensions.

When importing a file containing attendees, review the explicit consent checkbox.
A server with implicit scheduling can send invitations or meeting updates as
soon as imported events are uploaded, even if the file has no `METHOD` property.
Leave the checkbox clear and cancel if you do not want those messages sent.

## Reconnect and troubleshooting

- Use the account's reconnect action to replace the password. The verified
  principal and home must remain the same; cached content and account identity
  are retained. A rejected password does not replace working credentials.
- For authentication errors, check the username, app-password requirements and
  server authentication configuration. BusyMax does not guess alternate paths.
- For discovery errors, use the administrator's direct DAV URL and verify the
  principal and calendar-home properties are accessible.
- For missing tasks, check the collection's VTODO configuration and selection.
- After resolving a failed calendar or task-list creation, use **Dismiss** on
  its account-settings notice. Dismissal persists across synchronization and
  restarts and retains the operation's diagnostic history. A successful new
  request does not automatically clear an older failure with the same name.
  Pending reconciliation notices cannot be dismissed; synchronize to determine
  their remote outcome before attempting another creation.
- For TLS errors, correct the certificate chain and hostname. Generic accounts
  use normal platform validation; no certificate bypass is provided.
- Removing the account removes local credentials, cached account data and
  queued work. It does not delete remote collections or revoke a server password.
  Rotate or revoke that password on the server separately when required.

## BusyStack CalDAV Server

For release 0.1.0, sign in to the server's account interface, complete its MFA
requirements and issue a named DAV credential. Copy the displayed CalDAV
endpoint, username and issued secret into BusyMax's CalDAV connection dialog.
The normal account password does not authenticate DAV requests. Keep the issued
secret securely; the server displays it once. Revoke it through the server when
it is no longer needed, and use BusyMax's reconnect action after replacement.

Use separate event and task collections: this release accepts VEVENT-only and
VTODO-only collections, and rejects mixed collections. Owner-controlled READ
and WRITE shares appear through ordinary DAV discovery; manage sharing on the
server. Scheduling delivery, CardDAV, server-executed alarms and general file
storage are outside this server's CalDAV scope. Stored attendee, organizer and
alarm metadata remain preserved.

See the [qualification record](caldav_qualification.md) for exact tested server
versions, scenarios and verification boundaries, and the
[security and recovery model](caldav_security.md). Qualification of Radicale,
Baïkal and BusyStack does not establish universal interoperability.
