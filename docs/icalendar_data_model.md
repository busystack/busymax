# iCalendar data model

BusyMax keeps the server's complete iCalendar resource as the synchronization
authority. It does not reconstruct DAV resources from normalized event or task
rows.

Two layers operate on each resource:

- The document layer retains property order, unknown and duplicate properties,
  parameters, sibling components, alarms, recurrence exceptions, and
  `VTIMEZONE` data. Edits patch only the affected fields.
- The semantic layer projects supported `VEVENT` and `VTODO` fields into the
  local database for display, search, reminders, and recurrence expansion.

Mutated resources use CRLF line endings and fold content lines at 75 UTF-8
octets. Untouched data remains intact, including provider-specific extensions
that BusyMax does not interpret.

## Editable Nextcloud `VTODO` data

The Nextcloud task editor is based on the official
[Nextcloud Tasks 0.18.1 source](https://github.com/nextcloud/tasks/tree/v0.18.1).
BusyMax can project and patch these properties without regenerating the rest of
the resource:

| Data | iCalendar representation |
|---|---|
| Identity and text | `UID`, `SUMMARY`, `DESCRIPTION`, `CATEGORIES` |
| Scheduling | `DTSTART`, `DUE`, date-only, floating, UTC, or `TZID` values |
| Progress | `STATUS`, `PERCENT-COMPLETE`, `COMPLETED` |
| Details | `PRIORITY`, `LOCATION`, `URL`, `CLASS` |
| Hierarchy and order | parent `RELATED-TO`, `X-APPLE-SORT-ORDER` |
| Recurrence | `RRULE`, `RDATE`, `EXDATE`, `RECURRENCE-ID` |
| Reminders | every `VALARM` child component |
| Nextcloud UI state | `X-PINNED`, `X-OC-HIDESUBTASKS`, `X-OC-HIDECOMPLETEDSUBTASKS` |
| Bookkeeping | `CREATED`, `LAST-MODIFIED`, `DTSTAMP` |

Status, percentage, and completion date are changed together using the same
state transitions as Nextcloud Tasks. In particular, reopening a 100-percent
complete task changes it to 99 percent when an in-progress value is needed.
Completing a parent completes its open descendants; reopening a descendant
reopens a closed ancestor. Parent deletion is queued child-first.

The recurrence editor covers the subset exposed by Nextcloud Tasks 0.18.1:
`DAILY`, `WEEKLY`, `MONTHLY`, and `YEARLY`; `INTERVAL`; the supported `BYDAY`,
`BYMONTH`, `BYMONTHDAY`, and `BYSETPOS` combinations; and either `COUNT` or
`UNTIL`. Rules outside that subset, multiple `RRULE` properties, and detached
instances remain synchronized and preserved but are not rewritten by the
editor. Completing a recurring master creates the completed exception and
advances the master when the rule has another occurrence.

Every alarm remains in source order. The editor adds absolute reminders and
before-start or before-due relative reminders. It applies the same editability
rules as Nextcloud Tasks 0.18.1: absolute UTC triggers and supported
start-relative triggers can be changed; due-relative, timed positive, and
other unsupported trigger forms remain visible, removable, and intact. Alarm
actions and additional properties are preserved. Removing a start or due value
with related alarms requires the user to either remove those alarms or convert
them to absolute triggers.

## DAV task operations

Task-object creates, updates, moves, and deletes are represented as durable
pending operations. Updates use exact ETag preconditions. A cross-list move
uses WebDAV `MOVE` with the original member name, `Depth: infinity`, and
`Overwrite: F`; descendants are moved child-first so parent relationships stay
valid. Recursive duplication assigns a new UID to the complete recurrence set
and then duplicates descendants under their corresponding new parents. Clear
completed selects closed root tasks and recursively deletes their descendants,
including cancelled root trees as Nextcloud Tasks does.

Creating a Nextcloud task list uses extended `MKCOL` with a `VTODO`-only
supported component set, the Nextcloud default blue `#0082C9`, and the enabled
property. Rename uses `PROPPATCH`; delete and unshare use `DELETE`. The list
slug rules and collision suffixes follow Nextcloud Tasks 0.18.1.

## Dependency decision

No general-purpose iCalendar or CalDAV package is authoritative for this data.
The evaluated packages normalized or regenerated resources in ways that could
discard unsupported content or could not satisfy BusyMax's sync-token,
conditional-write, redirect, and parser-limit requirements.

The `xml` package is used only for namespace-aware WebDAV XML parsing. BusyMax
adds response-size, depth, element-count, and text-size limits and rejects DTD
and entity declarations before parsing.

## Protocol references

- [RFC 4791](https://www.rfc-editor.org/rfc/rfc4791): CalDAV collections,
  reports, object resources, and write preconditions
- [RFC 5545](https://www.rfc-editor.org/rfc/rfc5545): iCalendar syntax and
  semantics
- [RFC 4918](https://www.rfc-editor.org/rfc/rfc4918): WebDAV properties,
  conditional writes, `PROPPATCH`, `MOVE`, and `DELETE`
- [RFC 5689](https://www.rfc-editor.org/rfc/rfc5689): extended `MKCOL`
- [RFC 6578](https://www.rfc-editor.org/rfc/rfc6578): WebDAV collection
  synchronization
- [RFC 6764](https://www.rfc-editor.org/rfc/rfc6764): service discovery
- [RFC 7809](https://www.rfc-editor.org/rfc/rfc7809): time zones by reference

The DAV and iCalendar test suites cover lossless field patches, task-state and
hierarchy transitions, recurring completion, alarms, custom time zones,
recursive duplicate/delete, cross-list `MOVE`, collection mutations, offline
mutation replay, and server conflict handling.
