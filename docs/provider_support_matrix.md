# Provider capabilities

This document describes the capabilities exposed by the current source tree.
Actual write access also depends on the permissions reported by each account
and collection. Unknown capabilities fail closed; BusyMax does not infer write
access from a provider name.

| Provider | Calendars | Tasks | Authentication |
|---|---|---|---|
| Google | Google Calendar | Google Tasks | OAuth desktop client |
| Microsoft | Microsoft Calendar | Microsoft To Do | OAuth public client |
| Apple iCloud | iCloud Calendar | Not supported; Apple Reminders is not supported | Apple app-specific password over HTTPS |
| Nextcloud | `VEVENT` collections | `VTODO` collections | Login Flow v2 in the default browser |
| WebCal | Read-only calendar subscriptions | Not supported | Subscription URL stored as a secret |

## Collection creation

| Capability | Google | Microsoft | Nextcloud | Apple iCloud | WebCal |
|---|---|---|---|---|---|
| Create calendar | Yes | Yes | Yes | No | No |
| Create task list | Yes | Yes | Yes | No | No |

Nextcloud event calendars are created remotely with CalDAV `MKCALENDAR` and
an event-only (`VEVENT`) component set. Nextcloud task lists continue to use
their existing `VTODO` collection implementation. This is Nextcloud-specific;
BusyMax does not claim generic CalDAV collection creation. Apple collection
creation remains unsupported, and WebCal subscriptions remain read-only.

## CalDAV synchronization

| Capability | Apple iCloud Calendar | Nextcloud Calendar | Nextcloud Tasks |
|---|---|---|---|
| Collection discovery | Supported | Supported | Supported |
| Initial and incremental synchronization | Supported | Supported | Supported |
| Offline object create, edit, delete, and replay | Writable collections | Writable collections | Writable collections |
| Conditional ETag writes and explicit conflict handling | Supported | Supported | Supported |
| All-day, floating, UTC, and `TZID` date-time values | Supported | Supported | Supported |
| Recurrence rules and exceptions | Supported | Supported | Supported; see the editable subset below |
| `VALARM` preservation | Supported | Supported | Supported |
| Read-only and shared collections | Supported | Supported | Supported |
| Collection creation | Not supported | Supported online through `MKCALENDAR` | Supported online when permitted |
| Collection rename, delete, or unshare | Not supported | Not supported | Supported online when permitted |
| Collection color or order editing | Not supported | Not supported | Not supported |
| Cross-list task moves | Not applicable | Not applicable | Supported between writable Nextcloud task collections |
| Clear completed tasks | Not applicable | Not applicable | Supported |
| Invitation, scheduling, and attendee changes | Not supported | Not supported | Not applicable |
| HTTP-only or private-CA servers | Not supported | Not supported | Not supported |

## Nextcloud task data

BusyMax exposes the task data used by the official Nextcloud Tasks 0.18.1
editor:

- title, description, categories, start, due date, and all-day state;
- status, completion percentage, completion date and time, and iCalendar
  priority from 0 through 9;
- location, URL, and `PUBLIC`, `CONFIDENTIAL`, or `PRIVATE` classification;
- parent-child relationships, recursive subtasks, and Nextcloud's numeric task
  order, including its `CREATED`-based fallback;
- multiple reminders, including absolute and before-start/before-due triggers;
- daily, weekly, monthly, and yearly recurrence with interval, supported
  day/month selectors, count, or end date;
- pinning and the Nextcloud subtask-visibility flags;
- recursive duplication, raw iCalendar export, recursive deletion, moving a
  subtree between lists, and deleting Nextcloud closed root task trees.

Completing a recurring task creates a completed recurrence instance and
advances the master task when another occurrence exists. Recurrence rules that
the editor cannot represent remain intact and read-only. BusyMax also preserves
unknown properties, parameters, duplicate properties, unsupported alarm
actions, sibling components, and time-zone definitions instead of rebuilding
the resource from the visible fields.

The parity reference is the official
[Nextcloud Tasks 0.18.1 source](https://github.com/nextcloud/tasks/tree/v0.18.1).
The wire format and DAV operations follow
[RFC 5545](https://www.rfc-editor.org/rfc/rfc5545),
[RFC 4791](https://www.rfc-editor.org/rfc/rfc4791),
[RFC 4918](https://www.rfc-editor.org/rfc/rfc4918), and
[RFC 5689](https://www.rfc-editor.org/rfc/rfc5689).

## Deliberate boundaries

- Generic CalDAV account setup
- Apple Reminders
- Nextcloud Deck or Notes
- Nextcloud task-list color/order editing, share administration, or trash-bin
  management
- Editing an individual detached task occurrence directly; synchronized
  exceptions are preserved, and recurring completion is handled on the master
- EventKit or private Apple APIs
- HTTP fallback or invalid-certificate exceptions
