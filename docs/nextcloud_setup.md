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
BusyMax. Packaged-runtime verification and remaining acceptance gaps are tracked
in the [engineering note](nextcloud_private_certificates.md). Windows native
and Android device acceptance are still pending; Linux tests and APK builds do
not establish those results.

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

For a server that supports calendar federation, enter a remote calendar
recipient as `<username>@<instance>` in the existing sharing search. If no
local user or group matches, BusyMax offers the federated recipient and sends
the share request to your own Nextcloud server. Nextcloud 32 supports
read-only federated calendar shares; remote write access requires Nextcloud 33
or later, and the server administrator can disable federation. A failed or
unsupported share is not saved locally as a successful grant. Verify the
recipient and role in Nextcloud Calendar after sharing.

For supported calendars, organizers can manage guests and attendees can
respond from event details. Recurring responses require the offered
occurrence-or-series choice. BusyMax also exposes guest availability and the
scheduling inbox when the server provides them.

Meeting changes synchronize through the selected Nextcloud calendar. **A
response saved locally is pending work, not proof that the server delivered
it.** Confirm important invitations, replies, and cancellations with the
recipient or Nextcloud Calendar. Federation and permission differences can
disable meeting actions.

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
items exposed by Nextcloud's CalDAV trash support. Restoration follows the
current permissions and destination reported by the server; expired entries or
collisions can prevent restoration.

Ordinary deletion uses Nextcloud's normal trash behavior. **Permanently
delete** is a separate, confirmed action. A successful restore is not treated
as complete until the list refreshes.

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
