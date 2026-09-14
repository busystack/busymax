# Live-provider testing

Live integration tests are opt-in and are skipped by a normal `flutter test`
run. They create and delete remote calendars and objects, change sharing
permissions, and can revoke app passwords. Use only disposable QA accounts,
isolated test servers, and QA-only invitation recipients.

Pass credentials through the test process environment. Never commit them or
include credentials, DAV paths, Login Flow URLs or tokens, raw iCalendar, or
user content in logs, screenshots, and bug reports. A fixture may use loopback
HTTP or a test CA only where stated below; production account connections still
require HTTPS and normal platform certificate validation.

## Record installed Nextcloud versions

For each Nextcloud run, record the versions actually installed on the QA
system. Do not copy implementation-reference versions from other documentation.

```text
BUSYMAX_NEXTCLOUD_QA_CALENDAR_VERSION=<installed Calendar version>
BUSYMAX_NEXTCLOUD_QA_TASKS_VERSION=<installed Tasks version>
```

The DAV, sharing, and Login Flow tests read the Server version from the
installation's public `status.php`. They do not request administrative app
management. Supply the installation root, including a subdirectory when used,
rather than a calendar-object URL.

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

The URL may use HTTP only for an isolated loopback fixture. Set
`BUSYMAX_NEXTCLOUD_LIVE_LARGE=1` to include the 128-member collection case.

The restart scenario requires two runs against the same persistent server
storage. First set:

```text
BUSYMAX_NEXTCLOUD_LIVE_RESTART_ID=<unique fixture name>
BUSYMAX_NEXTCLOUD_LIVE_RESTART_STAGE=prepare
```

Restart the server without replacing storage, then rerun with
`BUSYMAX_NEXTCLOUD_LIVE_RESTART_STAGE=verify`.

## Nextcloud Login Flow v2

Set:

```text
BUSYMAX_NEXTCLOUD_LOGIN_LIVE=1
BUSYMAX_NEXTCLOUD_LOGIN_LIVE_URL=<HTTPS QA server URL>
BUSYMAX_NEXTCLOUD_LOGIN_LIVE_USERNAME=<QA user>
BUSYMAX_NEXTCLOUD_LOGIN_LIVE_APP_PASSWORD=<disposable bootstrap app password>
BUSYMAX_NEXTCLOUD_LOGIN_LIVE_TLS_CERT=<path to test CA certificate PEM file>
BUSYMAX_NEXTCLOUD_LOGIN_LIVE_BROWSER=<optional Chrome-compatible executable>
```

Run:

```bash
flutter test test/dav/nextcloud_login_flow_live_test.dart
```

Run once at the server root and once through a path-prefixed installation such
as `/nextcloud`. The test revokes the app password returned by Login Flow, so
use credentials created for this test.

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

The test creates a calendar, changes user and group shares, verifies effective
permissions including reader property access, and removes the collection.

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

The shared-calendar flags are optional and should be set only when those
fixtures exist. Run:

```bash
flutter test test/dav/apple_icloud_live_integration_test.dart
```

The test covers discovery, collection permissions, conditional writes, date
and recurrence forms, alarms, conflicts, credential replacement, and local
account removal. Confirm important results independently in Apple Calendar or
iCloud.com.

## Coverage that still needs real systems

Deterministic suites under `test/dav/` cover parsing and preservation,
discovery, exact ETags, mutation queues, conflicts, delegated discovery
failures, scheduling intent, import/export, and trash/sharing safety with fake
transports. They do not prove a particular server version, browser
authorization, invitation delivery, federation, retention, Nextcloud
Calendar/Tasks rendering, Apple rendering, or native desktop integration.

Before a release claim, exercise and record:

- authentication, reconnect, and account removal at the Nextcloud root and a
  subdirectory installation;
- owned, read-only, writable, group-shared, delegated, federated, mixed, and
  cached-subscription collections, including permission changes while work is
  queued;
- collection creation/settings, mixed-collection deletion warnings,
  self-unshare, publishing, failed refresh after a committed change, and
  uncertain-outcome reconciliation;
- organizer invitations, updates, guest removal and cancellation; attendee
  occurrence/series replies; free/busy failures; inbox acknowledgement; and
  the actual count of delivered QA messages;
- repeating task completion, exceptions, alarms, status/progress consistency,
  duplication, hierarchy, subtree moves, and shared-classification rules in
  the installed Nextcloud Tasks app;
- silent import, effective-resource export, timezones, recurrence, unknown
  properties, copied UIDs/parent identities, and pending local edits;
- event, task, and collection trash restoration, collisions, retention expiry,
  and separately confirmed permanent deletion;
- restart, invalid sync tokens, truncated reports, concurrent edits, and
  unknown outcomes; and
- both native entry points on their actual hosts, including browser launch,
  keyboard access, themes, small windows, and 100%, 125%, 150%, and 200% scale.

Never send test invitations to arbitrary attendees copied from imported data.
Ordinary deletion must not use a trash-bypass action. Inspect the QA provider
applications as well as BusyMax's local state.

## Recording results

Keep one release record containing the source revision, provider and installed
server/app versions, operating system, native entry point or package identity,
commands, result for each case, and relevant redacted evidence. Mark
unexecuted cases **not run**; do not infer a pass from an enabled control or a
deterministic test.
