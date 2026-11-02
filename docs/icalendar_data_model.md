# iCalendar and DAV data model

This page describes the preservation and mutation rules maintainers must keep
when changing BusyMax's Apple iCloud Calendar, Nextcloud or generic CalDAV integrations.

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

New DAV resources and edits that introduce IANA TZID references include missing
`VTIMEZONE` definitions through the same first-party timezone exporter used by
cloud series export. Existing embedded definitions, including custom zones,
take precedence and remain intact. This prevents server-added timezone data
from turning a successful create into a false conflict.

Generic discovery respects advertised component restrictions. An absent
`supported-calendar-component-set` uses RFC 4791's all-component default;
absence is distinct from an invalid empty restriction or a denied property.
Absent `supported-calendar-data`, and omitted attributes on its calendar-data
elements, use text/calendar version 2.0 defaults. Unsupported advertised
formats do not become invented capabilities. One mixed remote collection owns
both event and task projections.

Persisted capability metadata distinguishes unknown ACLs, explicit privileges
and explicit denial. Confirmed write flags never become true merely because
the ACL property is missing. Authenticated retrieval preserves readable
projections; guarded item mutation entry points can attempt an unknown
permission and retain rejected work for resolution. Subscriptions, scheduling
resources and trash are not made writable by an unknown ACL.

The `xml` package parses namespace-aware WebDAV responses. BusyMax enforces
response, depth, element, and text limits and rejects DTD and entity
declarations before parsing.

## Editable and preserved task data

The shared DAV task editor projects and patches the following supported data:

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

Generic accounts use the standard VTODO rows above. Nextcloud state extensions
remain restricted to Nextcloud. `RELATED-TO` hierarchy is retained; cross-list
generic moves require advertised MOVE and guarded source/destination access.
Unknown task properties and parameters remain in the document when supported
fields change. The recurrence history and hierarchy transitions are BusyMax
application behavior, not an assumption that every server implements a task UI.

Status, percentage, and completion time change as one state transition.
Completing a parent completes open descendants; reopening a descendant reopens
a closed ancestor. Completing a recurring master records its completed
instance and advances the master when another occurrence exists.
When an UNTIL rule is exhausted, the wire master remains intact for Nextcloud
compatibility. Its matching completed history determines the local completed
state. Explicit reopening updates that same history component; completing it
again retains its recurrence identity.

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

Generic collection administration negotiates MKCALENDAR or advertised Extended
MKCOL through existing DAV request interfaces. Item editing rights, parent
bind/unbind rights and property-write rights remain separate. Deterministic
creation targets and readback reconcile uncertain creation/property/deletion
outcomes before another mutation. The dedicated Nextcloud collection and
extension services retain their established behavior.

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
[live-provider tests](development.md#live-provider-tests).

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
