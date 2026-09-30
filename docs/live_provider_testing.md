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

For the bounded cloud-range and native-detail changes, use disposable Google
and Microsoft calendars and record the provider application, BusyMax build,
OS, and test date. Create one event before and one after the initial sync
horizon, navigate/search those months, change and delete events in the
provider, then reopen offline and after reconnect. Check that cached results
are marked incomplete offline and that baseline incremental synchronization
continues after the range reads. Use a read-only invitation with a real
provider-supplied meeting URL to check details and browser launch on each
native platform; separately check an invalid URL and a general Nextcloud event
URL. For Microsoft, edit an HTML event that contains a Teams meeting, verify
the changed body and meeting in Outlook after replay, then restart and check
notification reconciliation. For a Google Docs/Chat-assigned task, cancel the
deletion warning and verify both the original and queue remain unchanged;
then explicitly confirm on a separate disposable task and verify deletion in
the assignment surface. These are manual acceptance cases until run and
recorded against the actual accounts; a passing widget test is not a live
provider result.

For guest availability, check Google and a Microsoft work/school account from
Linux, Windows, and Android with one free recipient, one busy recipient, one
denied recipient, and one nonexistent recipient. Confirm the denied/missing
rows remain unknown, including after refresh, account changes, and a
daylight-saving boundary. A personal Microsoft account must not be reported as
free or be sent to Graph `getSchedule`. Verify opening availability neither
saves the draft nor sends invitations. Retest a Nextcloud collection whose
effective `canQueryFreeBusy` permission is denied.

For Android event authoring, open a recurring event with an every-two-weeks
weekday rule and multiple existing reminders. Save an unrelated title edit and
verify the original recurrence/reminders in the provider application. Then
edit interval, weekdays, and termination; separately test provider default,
no reminder, and a reminder at start. Change one guest between required and
optional without changing existing responses. Create a Meet/Teams conference
only on a calendar that advertises its solution, and confirm that the provider
created the meeting rather than BusyMax merely showing a local switch.

For iCalendar export, choose both the standalone occurrence and entire-series
options on each native platform. Use a disposable Google and Microsoft series
with a moved exception, a cancelled occurrence, an all-day case, and a rule
crossing a daylight-saving transition. Open the resulting file in a separate
calendar application and inspect UID, original recurrence identities, local
wall time, alarms, attendees, and any omitted provider-only metadata. Repeat
with a failed later provider page and offline cache: neither may be reported
as a complete series export. Import the same fixture into a disposable
calendar, verify every remote master/exception independently, and confirm no
unintended invitations were delivered.

On disposable Google calendars, create and edit each native status event type
(focus time, out of office, and working location) on an eligible primary
calendar; verify type-specific properties, visibility/free-busy state, and the
provider's own display after replay. Repeat against an ineligible account and
nonprimary calendar and confirm rejection without an ordinary-event fallback.
Confirm a title-only edit retains the status settings and unsafe recurring
series splitting remains unavailable. On a labeled Google calendar, select and
clear one returned event label, then edit only the title and verify label
preservation; repeat on a different calendar to check ID isolation. On an
Outlook mailbox with multiple existing master categories, select two on an
event and task, leave one unknown/deleted assignment untouched, and verify
the names and colors in Outlook/To Do. Decline optional category consent and
confirm normal editing still works. Record the actual account eligibility,
tenant consent, and provider application results; local tests are not proof.

For task-source navigation, open a Docs- or Chat-assigned Google task and a
Google task with related links and `webViewLink`, including after offline
reopening. For Microsoft To Do, open a task with multiple linked resources,
explicitly request them in each native task detail, and verify the supplied
application/display names and destination URLs. Repeat with a missing URL, a
denied resource request, and an account switch; editing and completion must
remain usable throughout. Do not treat browser launch or resource access as
successful merely because a URL is displayed.

For attachment read/access, check a Google event with multiple supplied links,
a Nextcloud event with URI `ATTACH`, and Microsoft events and To Do tasks with
and without attachments. Verify that the Microsoft list is requested only on
explicit opening, that a successful empty list differs from a denied request,
and that downloaded file bytes match the provider copy. Test a reference
attachment separately from a file attachment, an unsafe URL, a malformed
filename, pagination failure, read-only event, and offline cached metadata.
On disposable data, add and remove a Google event attachment reference using
an existing Drive file URL; check the provider event retains other references
and the underlying file still exists. Repeat after an uncertain mutation
response, and verify a normal title edit did not replace a newer attachment
array. Add and remove a Nextcloud URI `ATTACH`; inspect the raw iCalendar
resource for preserved binary attachments, parameters, alarms, exceptions,
and unrelated properties. Check the pending DAV queue, offline reopening,
reconnect, and read-only denial. For Microsoft, separately exercise event and
task file add/remove, small and upload-session paths, explicit download, and
remote state after an uncertain upload outcome. Record each provider mutation
not actually run as **not run**; local widget/API tests are not live acceptance.

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
- calendar federation initiation from each native sharing entry point with a
  disposable remote ID on an enabled Nextcloud 32+ server; verify recipient
  appearance in Nextcloud Calendar, read-only behavior on version 32, and
  permitted remote writes only on version 33+; repeat against a server with
  federation disabled and confirm no local-only success;
- Google owner-calendar and Microsoft signed-in primary-calendar sharing from
  Linux, Windows, and Android settings: list the provider's grants, add a
  disposable recipient with an explicit role, change only a provider-allowed
  role, then revoke; confirm each state in Google Calendar or Outlook and
  verify immutable owner grants, recipient/revoked access, and committed
  mutation followed by refresh failure are presented accurately;
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
