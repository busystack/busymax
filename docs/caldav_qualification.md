# Generic CalDAV qualification

This is the implementation checklist and maintained qualification record. A
checked implementation item does not establish live or native acceptance.

## Source baseline

- BusyMax `feature/caldav-support`, `5fbb15a2e103f3ee12627c8ab77974996e60e4d6`
  (version 0.4.0, schema 21); initially clean.
- `busystack_dav` remains pinned to
  `33afd70a761822847a37c7ad47f5e61dfeaa74a7`.
- Shared repositories have pre-existing IDE changes; preserve them.
- Official Flutter 3.47.5 / Dart 3.13.4; upstream integrity verifier passed
  (1,171 SDK files plus the reviewed package inventory).
- Baseline: `flutter test test/providers test/db test/dav test/core/auth`: 719 passed,
  29 credential-gated live tests skipped, no failures.
- Schema 21 fixture captured from the actual unmodified AppDatabase onCreate
  path before implementation: `test/fixtures/schema_v21_v040.sql`.
- Final source remains on the same branch and HEAD. Changes are local and
  uncommitted; no new commit, push or release was created. No shared dependency,
  SDK, package or upstream server source was changed.

## Source-grounded checklist

- [x] Add provider/credential identities without changing existing values.
- [x] Migrate schema 21 account CHECK constraints transactionally; verify
  accounts, foreign keys, queued work and authorization generations survive.
- [x] Add a dedicated validated, redacted CalDAV secret and integrate
  authorization persistence, leasing, recovery, replacement and removal.
- [x] Add safe URL normalization and origin-scoped provider profile.
- [x] Add onboarding, verified remote identity and reconnect handling.
- [x] Correct BusyMax discovery's OPTIONS-only well-known entry and add
  explicit-endpoint fallback without guessed paths.
- [x] Persist unknown/allowed/denied ACL state; preserve readable projections
  and guard user-requested writes with server-authoritative outcomes.
- [x] Respect component restrictions and default calendar data formats.
- [x] Integrate account sync, mutation routing, calendars, VTODO, recurrence,
  import/export, offline work, notifications and all provider switches.
- [x] Qualify collection creation, rename, metadata and deletion using
  advertised methods and appropriate permissions; retain outcome reconciliation.
- [x] Keep Nextcloud trust, sharing, scheduling and extensions isolated.
- [x] Integrate Linux, Windows and Android UI and generated localization.
- [x] Complete clean-fixture and final live reruns. Deterministic, Linux/Android
  editor and production Android process-restart layers also passed.
- [x] Update setup, development, data model, security and synchronization docs.

## Server targets

The reproducible primary targets are the assignment's reviewed Radicale 3.8.1
and Baïkal 0.12.1 (bundled sabre/dav 4.7.1). They are **not** the latest releases:
the official release pages checked on 2026-11-02 list Radicale 3.9.0 and Baïkal
0.13.0. No qualification of those newer versions is implied.

Baïkal release archive SHA-256 (GitHub release asset digest and local download):
`0449abb72b151d39d9c08c63cb83a05d9e9adb065b1165ef6786b0b6a13d203c`.

## Acceptance matrix

Recorded 2026-11-02. **Live** means BusyMax exercised the real Docker server.
**Live + fault** adds a first-party gateway/client fault while leaving the server
unchanged. **Deterministic** is protocol/lifecycle coverage without Docker and
is not counted as a server pass. The fixture's independent HTTP requests verify
stored objects separately from BusyMax's client.

| Scenario | Radicale 3.8.1 | Baïkal 0.12.1 |
| --- | --- | --- |
| Authenticated readiness, Alice and Bob | Live pass | Live pass |
| Principal/home resolution, direct URLs, HTTPS ports | Live pass | Live pass |
| Non-root installation discovery | Live pass | Live pass, separately configured instance, DAV URL and HTML landing page |
| Origin-root well-known entry | Direct fallback passes; upstream well-known absent | Live pass, HTTPS redirect |
| Wrong password / unknown user | Live pass, 401 | Live pass, 401 |
| Successful connect, password replacement, reconnect | Live pass | Live pass |
| Rejected reconnect preserves credential and generation | Live pass | Live pass |
| Actual password rotation with queued changes | Live pass | Live pass |
| Two accounts: principal, credential lease and private item isolation | Live pass | Live pass |
| Remove one account, preserve the other | Live pass | Live pass |
| Cancellation during credential validation | Live + delayed response pass | Live + delayed response pass |
| Account removal during active sync | Live + delayed response pass | Live + delayed response pass |
| VEVENT-only, VTODO-only and mixed inventories | Live pass | Live pass |
| Explicit read-only collection | Live pass | Live pass, read-only share |
| Optional ACL omitted: readable, unknown writes, real 403 retains queue | Live + omitted property pass | Live + omitted property pass |
| Missing component/data-format properties and property defaults | Deterministic pass | Deterministic pass |
| Malformed/denied mandatory properties, incomplete inventory | Deterministic pass | Deterministic pass |
| Event CRUD; all-day, floating, UTC and TZID times | Live pass | Live pass |
| DST-zone event creation with embedded VTIMEZONE | Live pass | Live pass |
| Event RRULE, EXDATE, RECURRENCE-ID, moved/cancelled occurrences | Live pass | Live pass |
| Event RDATE preservation | Live pass | Live pass |
| Multiple alarms, attendee/organizer, Unicode, unknown parameters | Live pass | Live pass |
| Task CRUD, complete/reopen, date/date-time, priority/progress/completed | Live pass | Live pass |
| VTODO RRULE, RDATE, EXDATE, recurrence exceptions | Live pass | Live pass |
| Recurring task completion: master advance and completed occurrence history | Live pass | Live pass |
| Task alarms, categories, RELATED-TO, unknown properties | Live pass | Live pass |
| Parent/child MOVE to another list, preserving hierarchy | Live pass | Live pass |
| Native resource import/export, duplicate import skipped | Live pass | Live pass |
| MKCALENDAR: event-only, task-only, mixed | Live pass | Live pass |
| Rename, description/color update, delete | Live pass | Live pass |
| Lost PUT/create/update/delete responses | Live + fault pass; one mutation | Live + fault pass; one mutation |
| Lost MKCALENDAR/PROPPATCH/collection DELETE responses | Live + fault pass; one mutation | Live + fault pass; one mutation |
| Initial/incremental sync; remote add/update/delete | Live pass | Live pass |
| Invalid sync token: safe rebaseline | Live pass | Live pass |
| Forced ETag fallback, 240 mixed resources, multi-batch fetch | Live pass | Live pass |
| Interrupted later multiget retains committed objects/cursor | Live + fault pass | Live + fault pass |
| Offline calendar/task create/update/delete; database reopening | Live pass | Live pass |
| Stale ETags, disjoint merge, overlapping conflict | Live pass | Live pass |
| Server restart with queued work and database reopening | Live pass | Live pass |
| Remote collection deletion retains unresolved local edits | Live pass | Live pass |
| TLS chain/hostname validation and untrusted certificate rejection | Live pass | Live pass |
| Cross-origin redirect and HTTP downgrade rejection | Live pass | Live pass |
| Response-byte and XML-depth budgets | Live + configured limits pass | Live + configured limits pass |
| 429/500/502/503/504 transient gateway retry then real read | Live + fault pass | Live + fault pass |
| UID conflict at a different resource URL | Live: rejects with 409 | Upstream does not enforce it: accepts with 201 |
| Native Linux connection and existing event/task editors | Pass, both independently read back | Pass, both independently read back |
| Native Android connection and existing event/task editors | Pass on ONEPLUS A6003 / Android 10 | Pass on ONEPLUS A6003 / Android 10 |
| Native Android secure storage / actual process restart | Pass, production runtime | Pass, production runtime |
| Native Windows execution | Unverified: no authorized Windows environment | Unverified: no authorized Windows environment |

## Validation evidence and reproduction

See [the maintained fixture instructions](../test/interop/caldav/README.md).
The Compose project, loopback ports and volumes are isolated. No upstream source
or runtime is patched. Baïkal uses the official PHP 8.4.13 Apache image and its
bundled SQLite schema/backend. Radicale uses explicit htpasswd authentication
and a rights file. HTTPS is terminated by a first-party fixture proxy; root
well-known routing belongs to that HTTPS origin. An HTTP upstream-generated
redirect was correctly rejected as a downgrade before that fixture routing was
configured. Certificates include strict CA/leaf constraints and are trusted
only in test-specific contexts. Global host/device trust settings are unchanged.

- Full deterministic suite: **4,503 passed, 67 skipped**, no failures. The skips
  require explicit live credentials/fixtures. Live/native runs are separate.
- Clean reset: removed only this Compose project's volumes, rebuilt/started
  unmodified upstream servers, provisioned fixtures and independently verified
  authenticated HTTP/HTTPS readiness. The clean run passed **37 live tests**.
  After the demonstrated installation-base discovery correction, the complete
  final matrix passed **38 live tests: Radicale 18, Baïkal 20**, with no skips or
  failures. These counts include the UID behavior probes; Baïkal's acceptance
  of duplicate UIDs is recorded as an upstream standards limitation, not as
  enforcement passing. The final independent HTTPS probe passed for both users
  across all four server/installation profiles.
- Affected DAV/provider/database/calendar/task/authentication and Windows/Android
  widget regressions: **2,025 passed, 57 skipped**, no failures.
- Generic discovery and account-sync focused tests: **28 passed**.
- Final discovery, authorization, HTTP transport and sync regressions:
  **121 passed**, including the reproduced HTML-200 discovery failure and
  preservation of authoritative 401/429/500 errors.
- Final Android settings, editing and local-network classification regressions:
  **132 passed**. Generic local-network permission denial uses provider-neutral
  localized feedback; actual Android 17 permission prompting remains unverified.
- Separate real HTTPS security rerun: **2 passed**, one per server, including
  independent untrusted-chain and trusted-chain/wrong-hostname rejection.
- Linux native editor suite: **2 passed**, one per server, after final provider
  and permission changes. This native harness uses disposable injected storage;
  installed Linux keyring/process-restart acceptance is not established by it.
  Native tests are separate from Flutter unit tests.
- Android native editor suite: **2 passed**, one per server, using a dedicated
  `io.busystack.busymax.caldavqa` package and actual native widgets. This harness
  uses disposable injected credentials/database; it alone does not establish
  production secure-storage or process-restart acceptance.
- Separate Android production-runtime restart qualification passed: the official
  `--no-uninstall` option retained the app, the process was explicitly stopped,
  and a new process recovered two real secure credentials, stable generations
  and four offline event/task edits. Independent GET/conditional PUT verified
  both remote objects and subsequent remote-to-local convergence for each
  server. Remote test collections and both local accounts/credentials were
  removed through production services. Separate per-server PASS markers were
  emitted. No platform trust settings or unrelated applications were changed.
- Cleanup completed: the isolated Android QA package and its two ADB reverse
  mappings are absent. Only the `busymax-caldav-qa` containers/network were
  stopped and removed after authenticated final readiness; project volumes and
  ignored local fixture inputs remain available for reproduction.
- Official Drift generation and localization generation completed. Account CHECK
  constraints remain inherited from the table definition, so regenerating Drift
  does not require a generated SQL constraint diff.
- Migration from the actual v0.4.0 schema-21 fixture compares every seeded row
  after upgrade to schema 22: existing providers, foreign keys, cached DAV
  resources, opaque hrefs, sync tokens, authorization generations, queued edits
  and linked contacts survive. An injected failure before version commit rolls
  back and the same database can reopen/migrate. No user database is reset.
- Official upstream integrity verification passed **1,171 SDK files** and all
  reviewed packages. The verifier's **29 tests** passed. Shared dependency pins
  remain unchanged.
- Static analysis, platform boundaries and `git diff --check` passed. Formatting
  checked **832 Dart files with zero changes**. Android release builds passed
  with the isolated QA ID and with the normal `io.busystack.busymax` ID
  (version 0.4.0/code 8), using explicit local test signing. The normal package
  was inspected but not installed or published. The final Linux release build
  also passed (`build/linux/x64/release/bundle/busymax`). No Windows build or
  installed-package acceptance is implied.
- Final BusyMax working tree: **132 tracked files changed and 38 new files**,
  all local and uncommitted. Two native import/export files and the first-party
  timezone data moved into provider-neutral DAV/time locations. Shared source
  revisions, the dependency manifest and `pubspec.lock` are unchanged; the
  shared DAV tree still has only its pre-existing IDE-cache modification.

## Observed defects corrected in BusyMax

The implementation corrects direct endpoint discovery, optional ACL handling and
persistence, generic credential lifecycle/dispatch, and database provider CHECK
constraints. A live Baïkal installation landing page exposed an ordinary HTML
200 response before discovery; BusyMax now tries the remaining same-origin
entry while still requiring complete mandatory DAV properties. Authentication,
rate-limit, server, TLS and redirect failures remain authoritative. Real
Radicale writes exposed missing VTIMEZONE definitions on new
TZID resources; BusyMax now reuses its existing timezone exporter and retains
embedded/custom definitions. Live password rotation exposed missing generic
pre-replay discovery; generic queues now revalidate permissions/authentication
before replay. Paused generic authorization failures are reported as errors,
with queued work retained. Native import and Windows task entry points now use
the shared DAV routes and permissions. Mixed-collection deletion warnings
cover both event/task projections, including default component sets.

## Qualification boundaries

This record does not claim universal CalDAV interoperability or acceptance of
newer server versions. Baïkal 0.12.1 accepts two resources with the same UID in a
calendar in the independent collision probe, despite RFC 4791's no-uid-conflict
precondition. BusyMax creates fresh UIDs and skips duplicate native imports;
that successful application behavior does not establish upstream UID enforcement.
Neither upstream software nor the shared DAV library was changed to hide this.

Generic accounts do not advertise DNS email/domain discovery, Digest/OAuth,
RFC 6638 invitation delivery/free-busy, Nextcloud sharing/federation/trash,
certificate exceptions, native attachment services, pinning or subtask-visibility
extensions. Unsupported recurrence forms and unknown fields are preserved.
Detached task occurrences are not independently edited by the UI.

Existing-provider deterministic regressions passed. New live Google, Microsoft,
iCloud and Nextcloud account authorizations were not performed; those credentials
were unavailable and no production credentials or other agents' environments
were used. Windows native execution, Android 17 runtime permission behavior,
installed Linux keyring recovery and new native system-notification delivery
remain unverified. The server results qualify the listed BusyMax workflows and
configurations; they do not establish complete upstream standards conformance.

## Governing references

[RFC 4918](https://www.rfc-editor.org/rfc/rfc4918.html),
[RFC 4791](https://www.rfc-editor.org/rfc/rfc4791.html),
[RFC 6764](https://www.rfc-editor.org/rfc/rfc6764.html),
[RFC 6578](https://www.rfc-editor.org/rfc/rfc6578.html),
[RFC 5545](https://www.rfc-editor.org/rfc/rfc5545.html),
[RFC 3744](https://www.rfc-editor.org/rfc/rfc3744.html),
[RFC 5689](https://www.rfc-editor.org/rfc/rfc5689.html),
[RFC 6638](https://www.rfc-editor.org/rfc/rfc6638.html),
[RFC 7617](https://www.rfc-editor.org/rfc/rfc7617.html),
[RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html).
Use applicable verified RFC Editor errata. Scheduling is a separate optional
protocol. Missing component restrictions mean all components are accepted;
missing supported-calendar-data means text/calendar version 2.0. Missing ACL
properties do not establish either write permission or write denial.

[Radicale documentation](https://radicale.org/v3.html),
[Radicale releases](https://github.com/Kozea/Radicale/releases),
[Baïkal installation](https://sabre.io/baikal/install/),
[Baïkal Docker guidance](https://sabre.io/baikal/docker-install/),
[Baïkal releases](https://github.com/sabre-io/Baikal/releases),
[sabre/dav](https://github.com/sabre-io/dav),
[independent server tester](https://github.com/python-caldav/caldav-server-tester).
