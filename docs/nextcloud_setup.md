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

- read-only sources remain visible and cannot be mutated; shared sources use
  the privileges granted by their owner;
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

Task lists can be created, renamed, deleted, or unshared when the server grants
the required collection privileges. These collection changes require an online
server round trip. List color/order editing, new-share administration, and the
Nextcloud trash bin are not exposed by this release.

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

For maintainer instructions covering disposable-server and live-account tests,
see [Live provider tests](live_provider_testing.md).
