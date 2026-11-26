# Journals

Open **Journals** to browse diary entries independently of the calendar date
range. Turn on journals for a DAV account in Settings and select the
collections you want to see. A mixed collection shares its network refresh
and sync token with its events and tasks. A journal collection can be created
from the journal workspace. The provider controls membership and write
permissions.

An entry can be undated, all-day, floating, UTC, or tied to a timezone. Add
separate description blocks for text variants. Each block keeps its own
language and alternate representation. A final entry remains editable when
the server grants permission. A cancelled entry keeps its history.

Use **Details** for repeat rules, reference and publishing properties, and
nested participant, location, resource and status records. The editor displays
derived values as read-only. It renders styled data as text and performs no
automatic external fetch. Attachment controls support portable web links and
inline files. Open a remote link or save an inline file using the entry's
attachment actions. See [RFC 5545](https://www.rfc-editor.org/rfc/rfc5545.html),
[RFC 9073](https://www.rfc-editor.org/rfc/rfc9073.html), and
[RFC 10051](https://www.rfc-editor.org/rfc/rfc10051.html).

Browse a repeating entry's occurrences by month. Edit a single occurrence
or apply a change beginning at that occurrence. Single deletions retain an
exclusion in the series. Deleting a future range keeps the earlier recurrence
identities. Cancelling a future range marks that range as cancelled. A
recurrence operation that exceeds the expansion budget leaves the original
data available. A date-form conversion that leaves incompatible recurrence
fields is rejected before it can change a queued resource.

Search includes every description block and supports dated or undated
filters. The search field stays populated when returning from an entry.
BusyMax stores unfinished editor changes locally. Reopen the entry to review
its draft and use **Discard changes** to remove the draft intentionally.
Pending entries can be exported as ICS before synchronizing. A failed write
keeps its local changes, and conflict resolution shows the source and local
versions. Choosing **Refresh** checks the selected source and attempts to
send its queued changes when the server permits it.

Import previews both stored calendars and journal PUBLISH, ADD and CANCEL
files. Confirm the destination before applying an import. BusyMax exports
effective journal entries and collections with their recurrence data and
timezone definitions. Read-only WebCal entries appear in the journal
workspace when the subscription contains journals.

The qualification record describes the tested provider versions, known
provider storage limits, and the scope of the native tests.
[Journal qualification](journal_qualification.md)
