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
installation. The address must use HTTPS, contain no username or password, and
pass normal platform certificate validation. HTTP-only servers, private-CA or
invalid-certificate exceptions, arbitrary CalDAV servers, and incorrectly
configured reverse-proxy paths are not supported.

## Connect in the browser

1. In BusyMax, open **Add account** and choose **Nextcloud**.
2. Enter the server URL and select **Continue in browser**.
3. Sign in through the default browser, complete any two-factor or
   identity-provider step, and grant BusyMax access.
4. Return to BusyMax and wait for connection and collection discovery to
   finish.

BusyMax uses Nextcloud Login Flow v2. It never asks for the primary Nextcloud
password; Nextcloud returns a dedicated app password for BusyMax.

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
- When removing an account, BusyMax attempts to revoke its app password and
  then removes the local credential and account data. **Remote revocation can
  fail even when local removal completes.** If BusyMax reports a warning,
  remove the token manually in Nextcloud.

Official setup references:
[Nextcloud Login Flow v2](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/LoginFlow/index.html)
and
[Nextcloud WebDAV basics](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/WebDAV/basic.html).
Maintainers should use [live-provider testing](live_provider_testing.md) before
making release-specific interoperability claims.
