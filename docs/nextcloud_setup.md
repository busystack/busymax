# Nextcloud Calendar and Tasks setup

This guide explains how to connect and use a Nextcloud account in BusyMax.
BusyMax supports Nextcloud calendar collections, task lists, and mixed
collections that contain both events and tasks.

## Server requirements

Enter either the public HTTPS address used in your browser or Nextcloud's
**primary CalDAV address**. For example, both of these forms are accepted:

```text
https://cloud.example.net/nextcloud/
https://cloud.example.net/nextcloud/remote.php/dav
```

A copied calendar-specific DAV path is also normalized back to the Nextcloud
installation. The address must use HTTPS and contain no username or password.
Publicly trusted HTTPS works without certificate enrollment. Private servers
can use an explicitly approved private CA or an explicitly approved self-signed
server certificate as described below. HTTP-only servers, invalid certificates,
arbitrary CalDAV servers, and incorrectly configured reverse-proxy paths are
not supported.

## Connect in the browser

1. In BusyMax, open **Add account** and choose **Nextcloud**.
2. Enter the server URL and select **Continue in browser**.
3. Sign in through the default browser, complete any two-factor or
   identity-provider step, and grant BusyMax access.
4. Return to BusyMax and wait for connection and collection discovery to
   finish.

BusyMax uses Nextcloud Login Flow v2. It never asks for the primary Nextcloud
password; Nextcloud returns a dedicated app password for BusyMax.

When Nextcloud returns a different canonical HTTPS address after login, BusyMax
shows both addresses and asks before sending the new app password there. Reject
an unexpected address. A private-certificate approval belongs to one installation;
a different canonical installation needs its own certificate review. Login and
poll redirects still stay within the entered installation. These rules follow
[Nextcloud Login Flow v2](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/LoginFlow/index.html#login-flow-v2)
without silently forwarding credentials to a new destination.

Publicly trusted HTTPS retains Dart's environment proxy configuration, including
CONNECT tunneling and destination certificate verification. Private-certificate
connections currently require a direct connection: configure the server in
`no_proxy` (or the equivalent environment proxy bypass). BusyMax reports a
configured proxy as unsupported for private trust instead of silently bypassing
it or relaxing certificate checks. This restriction also applies to observing a
private certificate during setup; the certificate-only observation connects
directly.

## Private server certificates

On Linux, Windows, and Android, an untrusted Nextcloud connection stops before
sending HTTP headers, credentials, poll tokens, or calendar/contact data. The
foreground setup flow offers **Private server certificates** review. Reject
the certificate if you cannot verify the server. Encryption alone does not
establish identity on first use: compare the displayed **SHA-256 fingerprint**
with an administrator using an independently trusted channel.

Prefer **Import private CA** when your administrator operates a private PKI.
Choose a PEM/DER X.509 CA certificate or PEM CA bundle supplied through a trusted
channel, review its fingerprint and details, and approve it. Imports are limited
to 64 KiB and eight certificates. Each CA must permit certificate signing.
Private keys, PKCS#12/PFX, other containers, malformed and unsuitable material
are rejected. BusyMax adds the approved CA only to this account's TLS context;
it does not install it into an operating system or browser trust store.

Imported certificates support critical basic constraints, key usage, extended
key usage and SAN extensions. Other critical extensions are rejected when their
mandatory semantics cannot be enforced. Ask the administrator for a supported
certificate profile; a matching fingerprint cannot override suitability checks.

As a fallback, an eligible self-signed server leaf can be explicitly pinned.
BusyMax verifies the self signature, modern key/signature algorithms, validity,
TLS server suitability, and Subject Alternative Name before allowing approval.
DNS addresses need DNS SANs; IP addresses need IP SANs. A Common Name alone
does not suffice. Unsupported certificate formats/algorithms must be replaced
by the administrator, rather than bypassed.

The approval belongs to the individual account and exact server hostname and
effective port, plus its normalized Nextcloud installation. Other accounts on
the same server, subdomains, IP aliases, different ports, and redirected hosts
do not inherit it. Nextcloud-linked contacts use their parent's policy;
Nextcloud contacts-only accounts have independent approval. Other providers
keep their existing HTTPS behavior.

The system browser still performs Nextcloud Login Flow v2 authorization.
**Approving a certificate in BusyMax does not configure browser trust.** Your
administrator must separately arrange browser trust. BusyMax never substitutes
a certificate-bypassing embedded browser or asks for your primary password.

## Certificate renewal and recovery

Open **Private server certificates** in the existing Nextcloud account settings
to inspect trust, import/replace a private CA, review a replacement pin, or
explicitly return to standard HTTPS. Independent Nextcloud contacts accounts
have the same management action in contacts settings. **Revalidate account**
checks the currently accepted policy again, without approving a different
certificate or removing an active pin. Use it after correcting a server chain,
renewing an expired CA-issued leaf, or correcting the device clock.

- Standard HTTPS certificates renew normally, without saved leaf pins.
- With a private CA, server certificates may renew when their chain and identity
  still validate under the approved trust context.
- A pinned leaf changing requires explicit review, **even with the same key**.
  A new publicly trusted certificate cannot override an active pin.

Replacement shows the previously approved and newly observed identities.
Rejecting/cancelling, failed validation, persistence failure, or a confirmation
arriving after the account changed leaves the accepted policy intact. Removing
private trust is also explicit and succeeds only after standard HTTPS discovery
validates; it is not an automatic recovery fallback.

Background failures do not open dialogs or enroll certificates. Cached data and
pending changes remain available. **Review server certificate** identifies the
needed action; known trust failures wait for deliberate review/revalidation.
Use that account's certificate settings instead of repeatedly reconnecting.
Contacts keep this paused review state across startup and restart, including
expired certificates. An inconsistent saved trust record also stops requests;
it never reverts to ordinary HTTPS. A damaged policy with valid ownership can
be explicitly replaced. If the ownership/provider metadata itself is damaged,
local account removal remains available before a fresh, explicitly authorized
setup.

Dart-owned TLS has platform-specific trust sources; an OS-installed private CA
is not a portable way to configure BusyMax. Import approved private material in
BusyMax. Certificate design and recovery are documented in the
[engineering note](nextcloud_private_certificates.md).

## Permissions and collection settings

BusyMax shows the event and task views advertised by each collection and
enables actions only when the server reports the required permissions.
Read-only content stays visible. Object editing, property changes, collection
administration, sharing, and scheduling can have different permissions, so one
available action does not imply access to every other action.

Open a calendar or task-list menu and choose **Collection settings** to manage
the supported name, color, description, order, timezone, enabled state, and
calendar transparency fields. The server can reject individual changes.
Calendar and task-list creation are online operations.

A mixed collection has one remote owner. **Deleting an owned mixed collection
removes both its events and its tasks.** Removing a collection shared with you
removes your access rather than the owner's data.

Task fields and provider differences are documented in the
[provider support matrix](provider_support_matrix.md).

## Sharing and meetings

Collection settings expose sharing, publishing, and removal controls when
Nextcloud advertises them and the account has permission. Write access to event
or task content does not automatically grant sharing administration.

For a server that supports calendar federation, use the recipient's canonical
**Cloud ID**, including any port and installation subpath. BusyMax sends the
request to your own Nextcloud server. A grant on the owner's server does not
prove peer delivery or remote acceptance. Normal account refresh discovers pending invitations, with a 15-minute passive
freshness interval and no extra Android wakeups. Account indicators show only
the pending count, retained across restarts and hidden after authorization changes.
Open **Shared calendar invitations** in recipient account settings to refresh,
accept, or decline. Offline refresh retains the last known count. No invitation
is accepted automatically, and no system notification exposes remote details.
Acceptance is followed by calendar discovery and the server's federation
synchronization. Writable shares support the components and permissions the
server advertises; federated calendars do not support automatic meeting
scheduling. Revocation stops origin authorization immediately, while an already
cached recipient calendar disappears after the server's federation background
job processes it.

Both servers need reachable canonical HTTPS URLs, correct DNS, mutually valid
certificate chains, enabled federation and functioning background jobs. BusyMax's
account-local certificate approval does not configure server-to-server trust.
A successful HTTP sharing response alone cannot establish successful peer
delivery. Permission, peer delivery, refresh and uncertain-outcome failures
remain distinct in BusyMax.

For supported calendars, organizers can manage guests and attendees can
respond from event details. Recurring responses require the offered
occurrence-or-series choice. BusyMax also exposes guest availability and the
scheduling inbox when the discovered endpoint privileges permit them. An inbox
message can be acknowledged independently of its corresponding calendar event.
Unknown or failed free/busy responses are shown as unknown availability.

Meeting changes use CalDAV automatic scheduling through the selected calendar;
BusyMax does not separately send duplicate invitations or replies. A response
saved locally remains queued until synchronization. A stored server event is
not proof of delivery to every attendee. Inspect available attendee delivery
statuses and confirm important invitations with recipients. Nextcloud requires
valid calendar-user email addresses and a default scheduling calendar. External
invitation mail also requires configured SMTP and the Groupware invitation
setting. Administrators may disable external invitations or free/busy separately.

Existing accounts obtain endpoint-specific capabilities during normal
rediscovery, preserving cached collections and queued changes. A failed
rediscovery retains cached content and requires a successful refresh before
administrative actions can proceed.

Qualification uses Nextcloud 35.0.2 with Calendar 6.6.4 and Tasks 0.18.1.
One server delivery limitation remains: with working SMTP and external invitations,
removing an external attendee did not send cancellation mail, both through
BusyMax and a minimal conditional CalDAV update. The opt-in external-cancellation
regression compares both paths and can detect a future upstream fix. See
[Nextcloud/server #63242](https://github.com/nextcloud/server/issues/63242). BusyMax relies on the server's automatic
scheduling and does not send a duplicate cancellation as a workaround.

## Import and export

The iCalendar import flow accepts events and tasks for compatible Nextcloud
destinations. An imported scheduling method must be explicitly normalized:
**importing data stores calendar content; it does not send an invitation or
reply.** Existing UIDs are skipped unless **Import as new copies** is selected.

Individual export includes the effective local event or task resource.
**Export collection resources** writes separate `.ics` files to a new
directory chosen by the user. Collection export uses locally cached content;
synchronize first when you need the newest server snapshot.

See the [iCalendar and DAV data model](icalendar_data_model.md) for preservation,
scheduling, and import/export semantics.

## Deleted items

Open **Deleted calendars and tasks** from account or source management to view
deleted events, tasks, calendars, task lists and mixed collections exposed by
Nextcloud's CalDAV trash support. This is separate from Nextcloud Files trash.
Restoration follows the current permissions and destination reported by the
server; expired entries or collisions can prevent restoration.

Ordinary deletion uses Nextcloud's normal trash behavior. **Permanently
delete** is a separate, confirmed action. Restore uses the original server
resource, preserving its UID and properties.
Pending changes in the affected collection must be resolved before restoration,
so an old queued deletion cannot immediately delete a restored resource again.
A committed operation whose refresh fails is shown as awaiting refresh; an
uncertain MOVE or DELETE is never automatically repeated.

Nextcloud's retention duration is displayed when available. A zero duration
means retention is disabled, so newly deleted content cannot be recovered from
trash. Expired or already-restored entries and changed permissions require a
fresh listing before further actions.

## Reconnect, revoke, or remove

- Use **Reconnect** to repeat browser authorization after the app password is
  revoked. Cached data and pending work remain available while the account
  needs authentication.
- Revoking the BusyMax token in **Personal settings > Security > Devices &
  sessions** stops future synchronization until reconnection.
- When removing an account, BusyMax first commits local removal and then uses
  the captured credential and certificate policy for a bounded app-password
  revocation request. **Remote revocation can
  fail even when local removal completes.** If BusyMax reports a warning,
  remove the token manually in Nextcloud.

Official setup references:
[Nextcloud Login Flow v2](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/LoginFlow/index.html)
and
[Nextcloud WebDAV basics](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/WebDAV/basic.html).
Maintainers should use [live-provider tests](development.md#live-provider-tests) before
making release-specific interoperability claims.

Trash listing discovers identity, size and permissions in one lightweight
VCALENDAR query without calendar bodies. The interfaces immediately show this
metadata in scrolling lists. Choose **Show** on an object to load its title and
type through a conditional GET; other rows remain available during that read.
Closing the view cancels its reads. No full bodies are fetched automatically.
The opt-in service batch-enrichment path retains its 32-object/1 MiB raw budget;
interactive listing does not wait for those batches. Objects above the 16 MiB
response limit remain discoverable by filename and metadata, and can still be
restored or deleted without downloading their bodies.
The server's bundled SabreDAV does not implement component/property projection;
BusyMax does not rely on it. Nextcloud
35.0.2's [deleted-object container](https://github.com/nextcloud/server/blob/v35.0.2/apps/dav/lib/CalDAV/Trashbin/DeletedCalendarObjectsCollection.php)
has no pagination API. The 16 MiB transport limit still applies to each response,
including the lightweight identity inventory; an oversized inventory fails visibly,
without truncating older entries. Refresh removes withdrawn objects; on-demand
details reject changed ETags and leave the metadata listing intact for refresh.
Restore and delete revalidate lightweight metadata rather than downloading
calendar bodies again. They recheck identity,
permissions and authorization generation after confirmation.
