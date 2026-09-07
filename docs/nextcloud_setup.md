# Nextcloud Calendar and Tasks setup

BusyMax connects directly to a selected Nextcloud server over CalDAV. It
synchronizes `VEVENT` calendars and `VTODO` task lists, including mixed
collections when the server exposes both component types.

## Server requirements

- Enter either the public HTTPS URL used in your browser or Nextcloud's
  standard **primary CalDAV address**. For example, both
  `https://cloud.example.net/nextcloud/` and
  `https://cloud.example.net/nextcloud/remote.php/dav` are accepted.
- BusyMax recognizes `/remote.php/dav` (including a copied calendar-specific
  DAV path), removes the DAV suffix, and starts Login Flow v2 at the actual
  Nextcloud installation root. You do not need to edit a primary CalDAV
  address before pasting it.
- The URL must use HTTPS, contain no username/password, and pass normal
  platform certificate validation.
- This release does not support HTTP-only servers, private-CA exceptions, an
  invalid-certificate toggle, or arbitrary non-Nextcloud CalDAV accounts. A
  standard Nextcloud CalDAV address is supported as an input shortcut.

Reverse proxies must preserve the installation path and return the canonical
public server URL. BusyMax accepts only same-origin Login Flow redirects that
remain within that path contract.

## Connect with the default browser

1. In BusyMax, open **Add account** and choose **Nextcloud**.
2. Enter the server URL or paste **Copy primary CalDAV address**, then select
   **Continue in browser**.
3. BusyMax anonymously starts Nextcloud Login Flow v2 and opens the login URL
   in your system's default browser.
4. Sign in there, complete any two-factor or identity-provider step, and grant
   BusyMax access.
5. Return to BusyMax. It polls the one-time endpoint until Nextcloud returns
   the canonical server, `loginName`, and a dedicated app password.

BusyMax never asks for or stores the user's primary Nextcloud password. The
polling token and browser URL are treated as secrets and excluded from logs.
Nextcloud documents that the polling token is valid for 20 minutes and a
successful credential result is returned only once. Canceling the BusyMax
dialog cancels local polling.

## Calendars, task lists, and capabilities

BusyMax inventories the account's DAV collections and exposes event and task
views only when the advertised component set permits them. It uses ACL
privileges as the primary writability signal:

- content-read-only sources remain visible; read, write-content, bind, unbind,
  and write-properties privileges are evaluated separately. A reader may be
  allowed to rename or recolor their collection without editing its objects;
- calendar and task fields are enabled only when the relevant collection and
  component capabilities are present;
- a task shared with the account remains editable only when the collection is
  writable and its classification is `PUBLIC`; classification itself cannot be
  changed by the recipient;
- unsupported scheduling or collection operations stay disabled rather than
  being guessed from the server brand.

For writable Nextcloud task lists, BusyMax supports the same task data model as
the official Nextcloud Tasks 0.18.1 editor: start and due values, all-day state,
status, percentage complete, completion time, iCalendar priority, description,
categories, location, URL, classification, multiple alarms, recurrence,
subtasks, pinning, and subtask-visibility flags. It also supports recursive
duplicate and delete, raw iCalendar export, clear-completed, task ordering,
and moving a complete task subtree between writable Nextcloud lists.

The account inventory includes the authenticated home and returned delegated
principal/home contexts. Subscriptions cached by Nextcloud remain Nextcloud
sources; BusyMax enables the advertised `nc-calendar-webcal-cache` extension
and never fetches the upstream subscription with account credentials. Scheduling
inboxes, outboxes, deleted calendars and trash containers are not normal sources.
An incomplete discovery does not mark cached sources missing.

### Collection settings and sharing

On Linux and Windows, use the existing calendar/task-list menu's **Collection
settings** action. Settings include display name, color, server order,
description, calendar timezone, server-enabled state and scheduling transparency
when write-properties is granted. Unsupported properties can still be rejected
by the server; BusyMax checks each PROPPATCH property result. Event transparency,
collection availability, local visibility and sidebar order are separate.

Event-calendar creation uses VEVENT-only MKCALENDAR. Task-list creation keeps
the existing VTODO-only extended MKCOL path. Both are online operations; no
optimistic calendar is created before server confirmation. A mixed collection
remains one backing resource: owner deletion removes **both events and tasks**.
Removing a received share removes the recipient's access, not the owner's data.

The same settings dialog exposes advertised sharing modes, server principal
search, user/group read or write grants, revocation and publishing. Publishing
requires confirmation and displays the URL returned by the server. Being a
writer does not imply sharing administration rights. No Files Sharing API is
used. A committed write followed by failed refresh is reported as refresh
pending; do not repeat it. An uncertain outcome requires reconciliation.

### Invitations and availability

Nextcloud meeting actions use discovered calendar-user addresses and the
selected principal's scheduling outbox privileges, not the account login name.
An authorized organizer can add/remove required or optional guests. Attendees
can accept, tentatively accept or decline from event details. Recurring responses
require an occurrence/series choice; attendee "this and following" is not offered.
Organizer cancellation and attendee decline/removal have distinct actions.

Meeting changes are queued locally and use Nextcloud's implicit VEVENT
scheduling during ordinary conditional CalDAV writes. BusyMax does not send a
second invitation or SMTP message. A locally saved response is **pending**, not
proof of delivery. After a successful write, the server's canonical resource and
new ETag are fetched, including reported participant scheduling status. Permission
and identity changes are rechecked before replay. Schedule-Tag and VTODO
invitations are not assumed.

**Check guest availability** in the event editor uses the discovered outbox and
VFREEBUSY. Missing, denied, malformed or failed recipient results mean unknown
availability, not free time. **Scheduling inbox** in collection settings shows
cached/fresh messages; acknowledging one removes only the inbox message, not
the calendar event already processed by Nextcloud.

Federated content follows actual content permissions, but Nextcloud does not
implicitly schedule federated calendar objects. BusyMax does not offer meeting
guest changes or RSVP there. Meeting moves are restricted to native MOVE under
the same scheduling identity; a copy-and-delete move is rejected to avoid
unintended invitations and cancellations.

### Native import and export

The existing iCalendar import flow offers Nextcloud calendars and task-capable
destinations. It groups VEVENT/VTODO by component type and UID, keeping recurrence
exceptions, embedded timezones, alarms, participant parameters and unknown fields.
An imported scheduling METHOD requires explicit normalization acknowledgement;
this stores data, not an iTIP invitation or reply. Imports are explicitly silent
using `X-NC-Scheduling: false`, including offline replay. This header is not applied
to normal meeting edits.

Existing UIDs are skipped unless **Import as new copies** is selected. BusyMax
does not overwrite an existing UID implicitly. Copied task parent references are
rewritten together, queued in dependency order, and cycles or unavailable parents
are reported. Results are per resource; a rejected item is not counted as saved.

Individual event/task export uses the effective raw resource, including pending
local edits and the whole recurrence set. **Export collection resources** writes
separate `.ics` resources into a new directory under a location you choose. This
preserves calendar-level extensions and embedded timezones without merging
different definitions with the same TZID. It exports locally cached content;
synchronize first if you need the latest complete server snapshot.

### Deleted items

Use **Deleted calendars and tasks** in account/source management on either
desktop. The view uses Nextcloud's advertised CalDAV trash extension, including
VEVENT, VTODO and deleted calendars/lists, and displays server retention. Restore
uses the returned deleted-resource href and the discovered restore target, with
fresh permission and identity checks. An expired or changed entry cannot be
restored from an old cached identity. Server collisions are not resolved by
inventing new UIDs.

Ordinary deletion retains Nextcloud's normal trash behavior. **Permanently
delete** is a separate confirmed action. Restored items disappear from the view
only after success and refresh; a refresh failure is not a failed restore.

Calendar and task objects are cached locally for offline use. Object writes,
including cross-list task moves, are queued and use exact ETags when
connectivity returns. A server-side concurrent edit is merged only when the
changed fields are provably disjoint; otherwise BusyMax creates an explicit
conflict for the user. The complete iCalendar resource remains authoritative,
so unsupported properties and recurrence forms survive edits unchanged.

## Reconnect, revoke, or remove

- Use **Reconnect** to repeat Login Flow v2 after an app password is revoked.
  Cached data and pending work remain available while reauthentication is
  required.
- When a Nextcloud account is removed, BusyMax attempts the official
  authenticated app-password deletion endpoint, then always removes its local
  credential and account data. A network or server failure can prevent remote
  revocation, so check **Personal settings > Security > Devices & sessions**
  and revoke the BusyMax token manually when removal reports a warning.
- Revoking the BusyMax token in Nextcloud pauses synchronization without
  deleting local pending work.

Official protocol guidance: [Nextcloud Login Flow
v2](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/LoginFlow/index.html)
and [Nextcloud WebDAV
basics](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/WebDAV/basic.html).
Task behavior is cross-checked against the official
[Nextcloud Tasks 0.18.1 source](https://github.com/nextcloud/tasks/tree/v0.18.1).

The initial protocol reference is Server **34.0.3** and Tasks **0.18.1**. These
are reference versions, **not a claim of completed live interoperability**.
The Calendar app version must be recorded separately in a QA run. See the
[implementation and verification record](nextcloud_interoperability.md) for
automated evidence and remaining release checks.

For maintainer instructions covering disposable-server and live-account tests,
see [Live provider tests](live_provider_testing.md).
