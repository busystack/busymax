# Generic CalDAV qualification

This is the maintained qualification record. A checked implementation item does
not establish live or native acceptance.

## Current release follow-up — final validation in progress

Baseline: `feature/caldav-support`, clean implementation commit
`3a0e6c368fa14917ff0ef50ecb682331bd200e29`, already committed and pushed.
The release branch starts at `5fbb15a2e103f3ee12627c8ab77974996e60e4d6`.
Corrections below are local until the final validation/commit steps complete.
No release has been merged, tagged or published.

### Corrected collection creation

Schema **23** adds an account-owned creation journal: random operation UUID,
reserved URL, validated authority/home, intended display name/component set and
prepared/dispatched/committed/rejected state. A fresh matching target is a
conflict, never `created`. Recovery requires the persisted operation ID;
titles and deterministic URLs do not establish ownership. Definitive namespace
rejection stays rejected. A pending operation checks remote absence before
retry and reconciles a committed result before any repeat mutation.

Regressions cover fresh creation, matching pre-existing conflict, lost-response
reconciliation, retry of the same demonstrably pending operation, database
reopening, changed intent, wrong account, account removal and both calling
calendar/task-list services. MKCALENDAR and Extended MKCOL bodies are distinct.
The schema-21 v0.4.0 fixture and schema-22 upgrade/rollback checks preserve
accounts, foreign keys, generations, cached objects and queued work.

**Actual OS process restart passed against all three servers:** the first Linux
process saved real keyring credentials, two queued event/task creates and two
committed VEVENT/VTODO collection creates with lost responses. A different PID
recovered the persisted IDs, sent **zero** MKCALENDAR/MKCOL retries, verified
remote collection and item state independently, drained the queue and removed
its credentials. This is stronger evidence than the separate database-reopen
unit tests. Receipts contain no secrets.

### Released server identities and deployment

| Server | Verified release | Isolated configuration |
| --- | --- | --- |
| Radicale | **3.9.0**, 2026-10-25 | Official image, explicit htpasswd authentication/rights, dedicated storage; root/non-root HTTPS fixtures |
| Baïkal | **0.13.0**, 2026-10-19; bundled sabre/dav **4.7.1** | Official complete release archive, official PHP 8.4.13 Apache, SQLite; private configuration/storage outside DocumentRoot; root/non-root deployments |
| BusyStack CalDAV Server | **v0.1.0**, source `db302ec69f786ba89945e1a761734a844572145b` | Official deployment bundle and application image, private PostgreSQL **18.6**, persistent volume, private secrets and HTTPS proxy |

Radicale image index:
`sha256:f68a99907f44b09dc12d81c3a1cdf221e3c55f08ceccfa17dc012991be9fb397`.
Baïkal archive SHA-256:
`81e74df123230e863f608d228fdd7b9a1a788f60b04d37e6973c302192e83f32`.
BusyStack deployment archive SHA-256:
`615c703ef94b21393a3e1ca2c2a1209c90d5f2716d302e1f3e664635a58f04b4`.
Its release manifest, checksum list and every manifest deployment file are
verified by `setup-busystack.py`. Application image:
`ghcr.io/busystack/caldav-server:0.1.0@sha256:0701a86c1d9848924f36111e5a1223c7e5a368737637f4382d1edbe55a50dcb0`.
PostgreSQL image digest:
`sha256:edb0c08dc33befd0262ab3b5cf1c4f3f8cfd8b09e88c05b45adee29d6761ddb6`.
All upstream servers, dependencies and runtime images remain unmodified.

Projects are `busymax-caldav-qa` and `busymax-caldav-busystack-qa`; ports bind to
loopback. BusyStack's database has no published port. Its official administrator
bootstrap is followed by supported browser account creation, password sign-in,
CTAP2 virtual-authenticator enrollment/MFA and named DAV credential issuance.
Playwright 1.61.1 / Chromium 149.0.7827.55 uses a private container trust database.
No normal account password is used for DAV; no artificial credential/verifier is
inserted. The endpoint is `https://localhost:18448/dav/`.

Primary references: [Radicale release](https://github.com/Kozea/Radicale/releases/tag/v3.9.0),
[Baïkal release](https://github.com/sabre-io/Baikal/releases/tag/0.13.0),
[BusyStack release](https://github.com/busystack/caldav-server/releases/tag/v0.1.0)
and its [release conformance record](https://github.com/busystack/caldav-server/blob/db302ec69f786ba89945e1a761734a844572145b/docs/conformance.md).

### Current execution evidence

The clean final shared suite passed **56 tests with no failures or skips**:
**Radicale 18 / Baïkal 20 / BusyStack 18**. Tests exercise production BusyMax
transport, onboarding, repositories, queues and sync engines; independent DAV
requests verify stored results. A prior run found four Baïkal fixture-selector
failures because scheduling inbox/outbox entries also matched its generic
read-only predicate. The selector now identifies the dedicated fixture explicitly
and retains all privilege assertions; the complete suite was rerun cleanly.
The following additional release-specific cases have passed:

| Additional scenario | Radicale 3.9.0 | Baïkal 0.13.0 | BusyStack 0.1.0 |
| --- | --- | --- | --- |
| Conditional PUT `If-Match: *` existing/missing, zero-offset VALARM and VTODO time-range filters | Live pass | Covered by shared applicable CRUD/query tests | Covered by shared applicable CRUD/query tests |
| Locked properties and protected collection deletion | Denial handled safely; upstream ACL inconsistency below | Shared read-only fixture | Shared READ/WRITE fixture |
| Duplicate UID at different member URLs | Rejects 409 | **Still accepts 201**; historical limitation persists | Rejects 403 `CALDAV:no-uid-conflict`, correctly classified |
| Real 507 bounded pages, strict Depth 0, opaque continuation, concurrent writes and server restart during paging | Existing sync coverage | Existing sync coverage | Live pass, 75 initial / 96 final resources, page size 17 |
| Interrupt after first processed page, retain stable cursor/cache, reopen/resume | Existing interrupted multiget coverage | Existing interrupted multiget coverage | Live + fault pass |
| Invalid stable token and real continuation invalidation on permission change | Existing invalid token coverage | Existing invalid token coverage | Live pass; safe rebaseline |
| Direct READ→WRITE→READ→revoke, pending edit retained; group READ/WRITE and membership removal | Rights fixture | Shared read-only fixture | Live pass through supported owner/admin MFA interface |
| Revocation/expiry/disabling reject an already-held local authorization lease | Password rotation coverage | Password rotation coverage | Live pass; queued edit preserved, valid replacement advances generation |
| Transformed VTIMEZONE PUT omits validators, canonical GET, subsequent conditional edit | Normal unchanged timezone round trips | Normal unchanged timezone round trips | Live pass; no false conflict/duplicate, authoritative ETag retained |
| Repair disabled: invalid local observance cutoff rejected atomically, valid UTC representation unchanged | Not applicable | Not applicable | Live pass |
| Configured servlet installation prefix, origin well-known redirect, duplicate verified-identity rejection and restart | Existing root/non-root coverage | Existing root/non-root coverage | Live pass at `/calendar`, with independent resource readback |
| Advertised 1 MiB resource limit, real 413, queued creation retained and remote baseline unchanged | Existing transport budgets | Existing transport budgets | Live pass; many bounded properties exceed resource budget |
| Actual Linux keyring and separate-process collection recovery | Native pass | Native pass | Native pass |
| Real desktop notification daemon accepts synchronized event/task reminders | Native pass | Native pass | Native pass |

BusyStack extra tests total **6 passed**: sharing, paging/strict profile,
representation repair, credential lifecycle, configured installation prefix,
and atomic resource-limit rejection. Expiry is accelerated by aging
only the timestamps of a genuinely MFA/browser-issued disposable credential in
the private QA database; its verifier is unchanged. It tests expiry enforcement,
not a natural 24-hour wait. The dedicated lifecycle user is disabled afterward.

### Demonstrated defects and limitations

BusyMax defects corrected within BusyMax:

- Fresh collection creation could adopt unrelated matching metadata. The durable
  operation identity and four-case regressions above correct it.
- MKCALENDAR included protected `DAV:resourcetype`. BusyStack returned
  `403 DAV:cannot-modify-protected-property`; that property is now sent only
  for Extended MKCOL. References: [RFC 4791 §5.3.1](https://www.rfc-editor.org/rfc/rfc4791.html#section-5.3.1),
  [RFC 5689 §3](https://www.rfc-editor.org/rfc/rfc5689.html#section-3).
- `403 CALDAV:no-uid-conflict` was classified as authorization failure. It now
  reports UID conflict, with separate invalid-data/component precondition
  handling. No authorization failure is turned into success.
- HTTP 413 resource rejection was recorded as a generic protocol error. It now
  maps to the existing resource-size error, with explicit CalDAV size
  preconditions handled separately from authorization. A live oversized queued
  resource remains saved as failed and creates no remote member.
- MOVE was inferred from home methods. Generic discovery now uses collection
  supported-method-set or authenticated collection OPTIONS; it preserves
  Nextcloud's established path and does not infer optional support by brand.
- Equivalent VTIMEZONE observance cutoff repair produced a false conflict.
  Comparison now recognizes only the existing reader's equivalent local/UTC
  cutoff semantics, while retaining the actual GET body and ETag. Changed
  offsets, cutoffs, fields or missing opaque properties still conflict.
- Restored WRITE access left a previously denied edit permanently blocked.
  Fresh complete discovery can release it only when explicit privileges cover
  all required collections/operations. Unknown, missing, read-only and
  authentication-blocked states retain the intent. The live direct/group test
  and deterministic recovery cases cover this path.

**Radicale upstream ACL limitation:** with rights `rwl`, authenticated
`PROPFIND /alice/property-locked/` returns 207 and privileges including
`DAV:all`, `DAV:write`, `DAV:write-content`; authenticated PROPPATCH of
`DAV:displayname` returns **403**. The independent minimal requests are in
`caldav_release_edges_live_test.dart`; the fixture rights are maintained in
`test/interop/caldav/rights`. [RFC 3744 §§3.2–3.3, 3.11](https://www.rfc-editor.org/rfc/rfc3744.html#section-3.2)
make the advertised aggregates include property writes. BusyMax reports the
server rejection and preserves local/remote metadata; it does not invent a
server-specific ACL exception. This is not qualified as accurate property-write
advertisement. The separate `d` collection-delete denial is also preserved.

**Baïkal duplicate UID limitation remains:** two independent conditional PUTs
with the same UID at distinct member URLs both receive 201. This does not meet
[CalDAV UID uniqueness, RFC 4791 §5.3.2](https://www.rfc-editor.org/rfc/rfc4791.html#section-5.3.2).
BusyMax's normal mutation path still uses conditional writes and conflict logic;
qualification does not claim upstream duplicate-UID enforcement.

**BusyStack optional exclusions:** mixed VEVENT/VTODO creation returns
`403 CALDAV:supported-calendar-component`. The released implementation accepts
one VEVENT or VTODO component, so the shared harness uses separate collections.
This is an advertised component restriction, not a fourth provider or client
exception. Scheduling delivery, CardDAV, server-executed alarms and general
file storage are outside this release's scope; stored organizer/attendee/alarm
metadata remains covered by round-trip tests.

### Available native and release checks

- Linux real keyring, actual two-process recovery and daemon notification
  acceptance: **passed for all three**. The QA runner is a native application
  with isolated key names/database paths; Snap confinement remains unverified.
- Current three-server Linux connection/editor suite: **3 passed**, with
  independent event/task readback. Current Android editor rerun: **blocked on
  physical device unlock**, not counted as passed. The isolated QA APK is
  built and installed on the authorized ONEPLUS A6003; its secure keyguard
  remains locked. No PIN bypass or device setting changes were attempted.
- Preserved original Android production secure-storage/process-restart
  qualification below remains valid; it is not claimed as new-server evidence.
- **Windows native: unverified**; the user confirmed no authorized Windows
  environment is available. The other workflow's VM remains untouched.
- **Android 17 local-network permission prompting: unverified, environment
  blocked.** An isolated official API 37.0 x86_64 revision-6 image and emulator
  37.2.13 were installed outside the shared SDK. Acceleration precheck passed
  but execution failed with `KVM: entry failed, hardware error 0x0`. The
  official `-accel off` fallback exposed API 37 through ADB but did not reach
  `sys.boot_completed=1` within 900 seconds. Only that owned AVD was stopped;
  no host kernel, graphics, shared SDK or other VM was changed. Unexecuted
  experimental harness files are excluded from the release candidate. The
  authorized phone runs Android 10/API 29.
- Real Google/Microsoft/iCloud authorizations remain separately unverified;
  their deterministic regressions do not require unavailable production secrets.
- Full final deterministic suite: **4,561 passed, 93 skipped**, no failures.
  The skips require explicitly enabled live fixtures; live acceptance is
  recorded separately above. Existing Google/Microsoft/Nextcloud/iCloud/WebCal,
  authorization, migration, calendar/task, offline and security regressions pass.
- Normal Linux release build: **passed**. Normal Android release APK/AAB
  builds, native platform unit tests and lint: **passed**. Artifacts are
  explicitly test-signed and not for distribution. Official bundletool 1.18.3
  (verified SHA-256 `a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29`)
  confirms AAB `PAGE_ALIGNMENT_16K`; APK manifest/signature/alignment inspection
  also completed. GitHub release-candidate CI remains pending. Read-only official SDK/package integrity passed (1,171 SDK
  files, eight reviewed packages); Python release-tool tests **72 passed**,
  upstream verifier tests **29 passed**; analysis and platform boundaries clean.
  The pinned Git-mode source snapshot secret scan found **zero** leaks.

Reproduction, credential handling, reset and teardown commands are maintained
in [test/interop/caldav/README.md](../test/interop/caldav/README.md). The original
qualification below remains historical evidence rather than current versions.

## Historical qualification of the original implementation

The remainder records the earlier Radicale 3.8.1 / Baïkal 0.12.1 runs.
It does not qualify the follow-up. The exact original record remains in
[implementation commit 3a0e6c3](https://github.com/busystack/busymax/blob/3a0e6c368fa14917ff0ef50ecb682331bd200e29/docs/caldav_qualification.md).

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
- The implementation was subsequently committed and pushed as `3a0e6c3`. No
  release was published. No shared dependency, SDK, package or upstream server
  source was changed.

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
- The original implementation comprised **132 tracked files changed and 38 new
  files**, subsequently committed and pushed in `3a0e6c3`. Two native import/export files and the first-party
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
