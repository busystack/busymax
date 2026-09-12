# Live provider tests

Live integration tests are opt-in and are skipped by a normal `flutter test`
run. They create and delete remote calendars and objects, change sharing
permissions, and may revoke app passwords. Run them only against disposable QA
accounts and isolated test servers.

Pass credentials through the test process environment. Do not commit them or
include them in logs, screenshots, or bug reports.

For every Nextcloud run, record the installed Calendar and Tasks app versions
from the QA installation (not the latest available releases):

```text
BUSYMAX_NEXTCLOUD_QA_CALENDAR_VERSION=<installed Calendar version>
BUSYMAX_NEXTCLOUD_QA_TASKS_VERSION=<installed Tasks version>
```

The main DAV, sharing and Login Flow tests read the actual Server version from
the installation's public `status.php` and report version-only evidence. They
do not request administrative app-management access. Initial reference targets
are Server 34.0.3 and Tasks 0.18.1; do not substitute these numbers for actual
installed versions. Supply an installation root (including a subdirectory when
applicable), not a calendar-object URL, in live-test environment variables.

## Nextcloud DAV

Set:

```text
BUSYMAX_NEXTCLOUD_LIVE=1
BUSYMAX_NEXTCLOUD_LIVE_URL=<QA server URL>
BUSYMAX_NEXTCLOUD_LIVE_USERNAME=<QA user>
BUSYMAX_NEXTCLOUD_LIVE_PASSWORD=<QA app password>
```

Run:

```bash
flutter test test/dav/nextcloud_live_integration_test.dart
```

The URL may use HTTP only for an isolated loopback fixture. Production
Nextcloud profiles require HTTPS.

Set `BUSYMAX_NEXTCLOUD_LIVE_LARGE=1` to include the 128-member collection test.
The restart test uses two separate runs:

```text
BUSYMAX_NEXTCLOUD_LIVE_RESTART_ID=<unique fixture name>
BUSYMAX_NEXTCLOUD_LIVE_RESTART_STAGE=prepare
```

Restart the server without replacing its persistent storage, then rerun with
`BUSYMAX_NEXTCLOUD_LIVE_RESTART_STAGE=verify`.

## Nextcloud Login Flow v2

Set:

```text
BUSYMAX_NEXTCLOUD_LOGIN_LIVE=1
BUSYMAX_NEXTCLOUD_LOGIN_LIVE_URL=<HTTPS QA server URL>
BUSYMAX_NEXTCLOUD_LOGIN_LIVE_USERNAME=<QA user>
BUSYMAX_NEXTCLOUD_LOGIN_LIVE_APP_PASSWORD=<disposable bootstrap app password>
BUSYMAX_NEXTCLOUD_LOGIN_LIVE_TLS_CERT=<test CA certificate in PEM format>
BUSYMAX_NEXTCLOUD_LOGIN_LIVE_BROWSER=<optional Chrome-compatible executable>
```

Run:

```bash
flutter test test/dav/nextcloud_login_flow_live_test.dart
```

Run once at the server root and once through a path-prefixed installation such
as `/nextcloud`. The test revokes the app password returned by Login Flow, so
use credentials created for this purpose.

## Nextcloud sharing

Set:

```text
BUSYMAX_NEXTCLOUD_SHARING_LIVE=1
BUSYMAX_NEXTCLOUD_SHARING_LIVE_URL=<QA server URL>
BUSYMAX_NEXTCLOUD_SHARING_LIVE_GROUP=<QA group>
BUSYMAX_NEXTCLOUD_SHARING_LIVE_OWNER_USERNAME=<owner user>
BUSYMAX_NEXTCLOUD_SHARING_LIVE_OWNER_PASSWORD=<owner app password>
BUSYMAX_NEXTCLOUD_SHARING_LIVE_WRITER_USERNAME=<writer user>
BUSYMAX_NEXTCLOUD_SHARING_LIVE_WRITER_PASSWORD=<writer app password>
BUSYMAX_NEXTCLOUD_SHARING_LIVE_READER_USERNAME=<reader user>
BUSYMAX_NEXTCLOUD_SHARING_LIVE_READER_PASSWORD=<reader app password>
BUSYMAX_NEXTCLOUD_SHARING_LIVE_GROUP_MEMBER_USERNAME=<group member>
BUSYMAX_NEXTCLOUD_SHARING_LIVE_GROUP_MEMBER_PASSWORD=<group-member app password>
```

Run:

```bash
flutter test test/dav/nextcloud_sharing_live_test.dart
```

This test creates a calendar, changes user and group shares, verifies effective
permissions including reader write-properties, and removes the collection.

## Extended Nextcloud release matrix

The deterministic suites under `test/dav/nextcloud/` and existing mutation,
discovery and sync suites exercise the shared implementation without accounts.
Normal runs must remain offline from providers. Opt-in live test success alone
does not cover the complete desktop release matrix. In disposable QA collections
also verify and record:

| Area | Live/desktop checks |
| --- | --- |
| Inventory | Mixed, subscribed-only/cache-enabled, delegated read/write, received shares and writable federation; fail one home and retain cached sources/pending edits |
| Management | Calendar/list creation, metadata per-property results, mixed deletion warnings, self-unshare, publication URL, successful write followed by failed refresh |
| Scheduling | Organizer invite/update/remove guests/cancel; attendee RSVP occurrence/series; offline replay; count actual received messages; unknown free/busy; inbox acknowledgement without event deletion |
| Tasks 0.18.1 | Repeating completion with exceptions and alarms; status/percentage/completed consistency; duplication, subtree movement/parents, X-properties and shared classification restrictions |
| Native data | Raw event/task import/export with zones, recurrence, unknown fields and pending edits; explicit copies and parent identities; silent import sends no invitation |
| Trash | Event, VTODO and whole calendar/list restoration; permissions changing after confirmation; collisions, retention expiry; separately confirmed permanent deletion |
| Sync | Exact ETags, disjoint/conflicting edits, invalid sync tokens, truncated reports, restart and unknown-outcome reconciliation |
| Desktop | Both actual entrypoints on native hosts; keyboard, browser launch, small windows, themes and 100/125/150/200% scaling |

Never use unrelated calendars, recipients or user data. Scheduling tests need
QA-only recipient accounts and approval to deliver test invitations; they must
not reuse arbitrary attendees from an imported calendar. Ordinary deletion must
not set the trash-bypass header. Inspect the QA inbox and Nextcloud Calendar/Tasks
applications as well as BusyMax's stored state.

Record unexecuted cases as **not run**, not passed or supported solely from an
enabled UI control. See [the implementation record](nextcloud_interoperability.md).

## Apple iCloud Calendar

Use a dedicated Apple QA account with two-factor authentication, a BusyMax-only
app-specific password, and at least two calendars. Set:

```text
BUSYMAX_ICLOUD_LIVE=1
BUSYMAX_ICLOUD_LIVE_USERNAME=<QA Apple Account email>
BUSYMAX_ICLOUD_LIVE_PASSWORD=<BusyMax app-specific password>
BUSYMAX_ICLOUD_LIVE_EXPECT_SHARED_WRITABLE=1
BUSYMAX_ICLOUD_LIVE_EXPECT_SHARED_READ_ONLY=1
```

The two shared-calendar flags are optional and should be set only when those
fixtures exist. Run:

```bash
flutter test test/dav/apple_icloud_live_integration_test.dart
```

The test covers discovery, collection permissions, conditional event writes,
date and recurrence forms, alarms, conflict behavior, credential replacement,
and local account removal. It does not replace a manual check in Apple Calendar
or iCloud.com.

## Recording results

Record the source revision, provider/server versions, operating environment,
test command, and result. Redact credentials, DAV resource paths, Login Flow
URLs and tokens, raw iCalendar, and user content before sharing any output.
