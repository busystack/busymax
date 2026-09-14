# iCalendar and DAV data model

This page describes the preservation and mutation rules maintainers must keep
when changing BusyMax's Apple iCloud Calendar or Nextcloud integrations.

## Complete resources and projections

The server's complete iCalendar resource is the synchronization authority.
BusyMax does not rebuild DAV objects from normalized event or task rows.

Each resource has two layers:

- The document layer retains property order, unknown and duplicate properties,
  parameters, sibling components, alarms, recurrence exceptions, and
  `VTIMEZONE` definitions. Edits patch only affected fields.
- The semantic layer projects supported `VEVENT` and `VTODO` values into
  Drift for display, search, reminders, and recurrence expansion.

Mutated resources use CRLF line endings and fold content lines at 75 UTF-8
octets. Unknown provider extensions, unsupported recurrence forms, detached
instances, custom timezones, and alarm details remain intact when BusyMax edits
a supported field.

The `xml` package parses namespace-aware WebDAV responses. BusyMax enforces
response, depth, element, and text limits and rejects DTD and entity
declarations before parsing.

## Editable and preserved task data

The Nextcloud task editor projects and patches the following supported data:

| Area | iCalendar representation |
|---|---|
| Identity and text | `UID`, `SUMMARY`, `DESCRIPTION`, `CATEGORIES` |
| Schedule | `DTSTART`, `DUE`, date-only, floating, UTC, and `TZID` values |
| Progress | `STATUS`, `PERCENT-COMPLETE`, `COMPLETED` |
| Details | `PRIORITY`, `LOCATION`, `URL`, `CLASS` |
| Hierarchy and order | parent `RELATED-TO`, `X-APPLE-SORT-ORDER` |
| Recurrence | `RRULE`, `RDATE`, `EXDATE`, `RECURRENCE-ID` |
| Reminders | `VALARM` child components |
| Nextcloud state | `X-PINNED`, `X-OC-HIDESUBTASKS`, `X-OC-HIDECOMPLETEDSUBTASKS` |
| Bookkeeping | `CREATED`, `LAST-MODIFIED`, `DTSTAMP` |

Status, percentage, and completion time change as one state transition.
Completing a parent completes open descendants; reopening a descendant reopens
a closed ancestor. Completing a recurring master records its completed
instance and advances the master when another occurrence exists.

The editor supports the daily, weekly, monthly, and yearly recurrence subset
represented by its controls, including supported intervals, selectors, counts,
and end dates. Rules outside that subset, multiple `RRULE` properties, and
detached instances remain synchronized but read-only.

All alarms remain in source order. BusyMax can add absolute reminders and
supported start- or due-relative reminders. Unsupported trigger forms and alarm
actions remain visible or preserved without normalization. Removing a start or
due value with a dependent alarm requires removing that alarm or converting it
to an absolute trigger.

The implementation reference is
[Nextcloud Tasks 0.18.1](https://github.com/nextcloud/tasks/tree/v0.18.1).
That version defines the current compatibility target; it is not a claim that a
live server with that Tasks version has been tested.

## Durable mutations and conflicts

Creates, updates, moves, and deletes are durable pending operations. Updates
and deletes use exact ETag preconditions. On a concurrent server change,
BusyMax merges only provably disjoint field edits; otherwise it records an
explicit conflict for the user.

Task hierarchy operations preserve parent identity and dependency order.
Parent deletion is queued child-first. Cross-list Nextcloud moves retain the
member name and move descendants child-first. Duplication assigns new UIDs to
the recurrence set and maps descendants to the corresponding new parents.
Clear-completed applies to closed root task trees.

Collection creation and administration are separate from object mutations and
require live permission checks. Nextcloud event collections are created for
`VEVENT`; task lists use a `VTODO` component set. Mixed collections remain a
single remote resource.

## Nextcloud extensions

BusyMax discovers collection types, privileges, scheduling principals, and
supported reports rather than enabling behavior from the server brand alone.
Cached WebCal subscriptions remain Nextcloud-owned sources and use the
advertised `nc-calendar-webcal-cache` extension; BusyMax does not send account
credentials to the upstream subscription URL.

Collection settings, sharing, and publishing follow advertised properties and
principal permissions. Content writing, property writing, sharing
administration, and owner deletion are distinct. A partial property update is
reported per property; an uncertain commit is reconciled before the user is
asked to retry.

Calendar scheduling uses discovered calendar-user addresses and outbox
privileges. Organizer and attendee changes use the ordinary conditional event
write and the server's implicit scheduling; BusyMax does not also send an SMTP
or duplicate scheduling message. Free/busy failures produce unknown
availability. Inbox acknowledgement removes the scheduling message, not the
calendar event. `Schedule-Tag` support and VTODO invitations are not assumed.

Native imports group resources by component type and UID and preserve
recurrence sets, timezones, alarms, participant parameters, and unknown
properties. Scheduling methods require normalization acknowledgement, and
Nextcloud imports use `X-NC-Scheduling: false` so stored imports do not send
invitations. Exports use the effective local resource, including pending edits.
Collection export is a cached snapshot and writes separate resources so
conflicting timezone definitions are not merged.

Trash discovery covers deleted events, tasks, and collections when Nextcloud
advertises the extension. Restore uses the deleted-resource href and restore
target returned by the server and rechecks permissions. Ordinary deletion and
confirmed permanent deletion remain separate operations.

Nextcloud Server **34.0.3** is an implementation reference, not a tested server
version. Useful versioned sources include the
[calendar-home implementation](https://github.com/nextcloud/server/blob/v34.0.3/apps/dav/lib/CalDAV/CalendarHome.php),
[scheduling plugin](https://github.com/nextcloud/server/blob/v34.0.3/apps/dav/lib/CalDAV/Schedule/Plugin.php),
[WebCal caching plugin](https://github.com/nextcloud/server/blob/v34.0.3/apps/dav/lib/CalDAV/WebcalCaching/Plugin.php),
and
[trash restore target](https://github.com/nextcloud/server/blob/v34.0.3/apps/dav/lib/CalDAV/Trashbin/RestoreTarget.php).
Record the versions actually installed during
[live-provider testing](live_provider_testing.md).

## Standards

- [RFC 5545](https://www.rfc-editor.org/rfc/rfc5545): iCalendar
- [RFC 5546](https://www.rfc-editor.org/rfc/rfc5546): iTIP scheduling
- [RFC 4791](https://www.rfc-editor.org/rfc/rfc4791): CalDAV
- [RFC 4918](https://www.rfc-editor.org/rfc/rfc4918): WebDAV
- [RFC 5689](https://www.rfc-editor.org/rfc/rfc5689): extended `MKCOL`
- [RFC 6578](https://www.rfc-editor.org/rfc/rfc6578): collection synchronization
- [RFC 6638](https://www.rfc-editor.org/rfc/rfc6638): CalDAV scheduling
- [RFC 6764](https://www.rfc-editor.org/rfc/rfc6764): service discovery
- [RFC 7809](https://www.rfc-editor.org/rfc/rfc7809): timezones by reference
