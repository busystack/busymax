# Generic CalDAV qualification

BusyMax qualifies the following implementations for the workflows below, not
universal CalDAV conformance. Results were recorded on 2026-11-02–03. This
record distinguishes deterministic regression coverage, real-server protocol
checks, native application checks and build validation. Documentation cleanup
does not constitute a new execution of these checks.

## Qualified implementations

| Implementation | Version | Tested configuration |
| --- | --- | --- |
| Radicale | **3.9.0** | Pinned official image; htpasswd authentication and explicit rights; root and installation-path HTTPS |
| Baïkal | **0.13.0**, bundled **sabre/dav 4.7.1** | Verified official archive; pinned PHP 8.4.13 Apache runtime, SQLite, separate root and installation-path deployments |
| BusyStack CalDAV Server | **0.1.0** | Additional regression target; verified official deployment bundle, source `db302ec69f786ba89945e1a761734a844572145b`, pinned application image and private PostgreSQL 18.6 |

Image digests, archive checksums, provisioning, authentication and teardown are
maintained in [the fixture guide](../test/interop/caldav/README.md),
[Compose configuration](../test/interop/caldav/compose.yaml),
[Baïkal setup](../test/interop/caldav/setup.py) and
[BusyStack release verification](../test/interop/caldav/setup-busystack.py).
Upstream software is unmodified. HTTPS uses a fixture proxy and private test
trust contexts. BusyStack uses separately issued DAV credentials, not normal
account passwords, and separate event/task collections.

## Interoperability matrix

The shared live harness exercises production transport, onboarding, repositories,
queues and sync engines. Independent authenticated DAV requests verify remote
state. “Live + fault” uses a first-party gateway/client fault against the real
server. Unsupported features and observed server defects are recorded as such,
even when their behavior probe passes.

| Scope | Radicale 3.9.0 | Baïkal 0.13.0 | BusyStack 0.1.0 |
| --- | --- | --- | --- |
| Authenticated readiness; principal/home discovery; direct and installation-path URLs; wrong password/unknown user | Live pass | Live pass | Live pass |
| Event-only and task-only collections | Live pass | Live pass | Live pass |
| Mixed VEVENT/VTODO collections | Live pass | Live pass | Advertised restriction; creation rejected |
| Read-only access, optional ACL handling and guarded writes | Live pass; ACL caveat below | Live pass | Live pass |
| Collection create, rename, metadata and delete; lost-response reconciliation by persisted operation identity | Live + fault pass | Live + fault pass | Live + fault pass |
| Rejected VEVENT/VTODO creation, DB reopening and continued item synchronization | Live pass | Live pass | Live pass |
| Fresh successful creation after rejection; terminal-notice acknowledgment survives reopening without changing journal outcomes | Live pass | Live pass | Live pass |
| VEVENT CRUD; all-day, floating, UTC, TZID/DST and embedded VTIMEZONE | Live pass | Live pass | Live pass |
| RRULE/RDATE/EXDATE, moved/cancelled exceptions, RECURRENCE-ID, alarms, Unicode and unknown properties | Live pass | Live pass | Live pass |
| VTODO CRUD, completion/reopening, date/date-time, priority/progress, recurrence/history, alarms and RELATED-TO | Live pass | Live pass | Live pass |
| Parent/child movement and resource import/export, duplicate import skipped | Live pass | Live pass | Applicable shared tests; MOVE requires advertisement |
| Initial/incremental sync, ETags, remote add/update/delete, invalid-token rebaseline and interrupted fetch | Live + fault pass | Live + fault pass | Live + fault pass; real paging below |
| Offline create/update/delete, SQLite reopening, stale ETags, disjoint merge and overlapping conflict | Live pass | Live pass | Live pass |
| Server restart with queued work; remote collection deletion retains unresolved edits | Live pass | Live pass | Live pass |
| TLS chain/hostname checks, untrusted certificates, cross-origin redirects and downgrade rejection | Live pass | Live pass | Live pass |
| Response/XML limits and transient gateway failures followed by real reads | Live + fault pass | Live + fault pass | Live + fault pass |
| Reconnect, rejected reconnect, credential replacement/rotation, account isolation and removal during active work | Live + fault pass | Live + fault pass | Live + fault pass |

Missing component/data-format properties, malformed mandatory properties,
incomplete inventories, cancellation and unknown/denied permissions also have
deterministic coverage; that coverage alone is not a server pass.

### Release-specific coverage

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

BusyStack's six additional live cases cover sharing, paging/strict profile,
representation repair, credential lifecycle, installation prefix and resource
limits. Credential expiry is accelerated by aging timestamps of a genuinely
browser/MFA-issued disposable credential in the private QA database; its verifier
is unchanged. This tests enforcement, not a natural 24-hour wait.

## Verified results and evidence scope

Source revisions identify the evidence; their counts must not be added together.

| Layer | Latest recorded result | Source/scope |
| --- | --- | --- |
| Deterministic Flutter suite | **4,665 passed, 96 gated/optional skips** | `c94b159`; four workers; includes provider, authorization, migration, offline/conflict and security regressions |
| Focused notice lifecycle | **70 passed**; separate button/feedback/release-workflow run **16 passed** | `c94b159`; file-backed VEVENT/VTODO recovery, account isolation, journal preservation, schema upgrades/rollback, three platform widget hosts |
| Complete main live harness | **59 passed: Radicale 19, Baïkal 21, BusyStack 19** | `56abc81`; includes denied creation, reopen and three later event/task update rounds |
| Affected live lifecycle follow-up | Passed separately on all three servers | `c94b159`; rejected and fresh successful creations, authenticated readback, production notice acknowledgment and reopening; not another full matrix run |
| Additional live tests | **6 BusyStack cases** and **2 Radicale release-edge cases** passed | Protocol baseline `221c757` with strict-pagination rerun at `56abc81` |
| Linux native connection/editors | **3 passed**, one per server, independent event/task readback | `56abc81`; native harness with disposable injected storage |
| Android native connection/editors and recovery feedback | **3 passed**, one per server, independent readback and production settings feedback | `3be80a3`; Android **10/API 29**, isolated QA package, injected disposable secrets/fixture CA |
| Linux real keyring and separate OS-process recovery | Passed for all three servers, including daemon notification acceptance | `221c757`; real secure-storage plugin, isolated database/key names; zero repeat collection-creation requests |
| Snap confinement/process recovery | Passed for all three under installed **0.3.2 core24 strict profile**, `SECRET_BACKEND=file` | `6b5e89d`; current QA bundle in isolated directory; qualifies that profile, not interactive installed 0.4.0 acceptance |
| Android production secure-storage/process restart | Passed for **Radicale 3.8.1 and Baïkal 0.12.1** | Original qualification `3a0e6c3`; separate two-process harness; not new-version or BusyStack evidence |
| Build/static validation | Linux release and normal-ID Android APK/AAB passed; analysis clean; formatting unchanged; platform boundaries passed | `c94b159`; Android unit tests/lint and artifact manifest/signature/alignment checks, including AAB 16 KiB page alignment; artifacts test-signed, not for distribution |

The latest build record also verifies localization/Drift regeneration and
read-only integrity of 1,171 SDK files and eight reviewed packages. Windows
widget tests run on Linux establish widget coverage only. Gated skips do not
establish live acceptance. The native editor harnesses do not establish
production secure storage; the separate process tests above have narrower,
explicit server/platform scopes.

## Review follow-up: working tree based on `cbebba7` (2026-11-03)

The review's two functional findings were reproduced. Account transport now
keeps at most four idle request lanes, with reuse bound to the exact credential,
trust policy and durable authorization generation. Request cancellation remains
isolated, and private TLS validity checks cover live sockets only. Permission
recovery covers denial → discard → complete discovery → a subsequent successful
write. Diagnostics permits that local discard while permissions need recovery;
explicit account revalidation also evaluates retained blocked work before
changing the account state.

Public HTTPS proxy CONNECT succeeds with a trusted destination and rejects an
untrusted destination before credential delivery. Private trust requires an
explicit proxy bypass; see [the Nextcloud guide](nextcloud_setup.md). Canonical
Nextcloud destinations require user review, and a new private installation needs
its own certificate approval. Tests cover approving and declining that second
approval, including zero HTTP requests to the rejected destination.

Settings observes persisted creation notices without a network dependency.
Generic attendee-bearing imports require consent in all three platform previews
and in the import service, including files without `METHOD`. A live Baïkal probe
also exposed and fixed a false conflict after successful import: generic servers
advertising `calendar-auto-schedule` now use scheduling-aware canonical readback
and Schedule-Tag validators. Unknown ACLs remain
distinct from explicit grants; retained blocked operations still need advertised
grants unless the user discards them.

### Follow-up validation

| Check | Result and scope |
| --- | --- |
| Complete deterministic Flutter suite | **4,683 passed; 98 gated/optional skips**, four workers, after the final code changes |
| Real-server main harness | All **59 distinct cases** have passing results across the main run and focused follow-ups; one initial BusyStack secondary-account authentication failure was resolved by issuing a fresh disposable Bob credential through browser/MFA and rerunning all three account-isolation cases |
| Affected Baïkal matrix | **21 passed** after the implicit-scheduling correction, including lifecycle, import, offline/conflict and subsequent event/task edits |
| Baïkal implicit scheduling | **1 passed**: no `METHOD`, consent required before any queued mutation or attendee delivery, real local-inbox `REQUEST` after consent, no retained false conflict, database reopening and a subsequent synchronized meeting edit |
| Linux native settings and editors | **3 passed**, one per server, with independent event/task readback |
| Linux native TLS/concurrency | **51 passed**, including proxy verification, pooling, cancellation and generation/trust isolation |
| Android native settings and editors | **3 passed on API 35**, one per server, in a fresh disposable emulator; independent event/task readback and production creation-failure feedback. The API 29 phone attempts were interrupted by ADB loss and owner lock; their recorded collection/forwarding was cleaned up and those attempts add no acceptance evidence |
| Linux release build | `flutter build linux --release -t lib/main_linux.dart` passed for this working tree |
| Android release builds | Normal-ID APK/AAB built with explicit **test signing**, not distribution keys; manifests/signatures, permissions and AAB `PAGE_ALIGNMENT_16K` metadata inspected |
| Static and repository checks | Analysis clean; platform boundaries and repository hygiene passed; **75** release-tool tests passed; integrity verification covered **1,171** SDK files and **eight** reviewed upstream packages |

The native tests use disposable fixture storage and CA material. They do not
establish production secure-storage behavior or installed release-package
acceptance. Skipped tests do not add live or native evidence.

### Comparative transport and discovery measurements

The transport workload uses 50 sequential synthetic DAV resources through a TCP
relay with 20 ms delay per direction. These are transport measurements, **not a
complete v0.3.2 application synchronization or battery benchmark**. The historical
terminating request lifecycle is reproduced from v0.3.2 (`42f3f7b`); the shared
IOClient reference is listed separately.

| Transport | Elapsed | TLS connections |
| --- | --- | --- |
| Shared IOClient reference | 2,392 ms | 1 |
| v0.3.2 terminating request lifecycle | 6,594 ms | 50 |
| Reviewed per-request account lifecycle | 6,768 ms | 50 |
| Pooled account lifecycle | 2,392 ms | 1 |

The review correctly identifies missing reuse on its candidate, but attributing
all missing DAV reuse to this branch overstates the regression: v0.3.2 already
created isolated native clients for terminating DAV requests. The replacement
improves both lifecycles in this workload. Repeat with
`BUSYMAX_DAV_BENCHMARK=1 flutter test test/dav/trust/dav_connection_reuse_benchmark_test.dart`.

For 100 collections at 40 ms simulated request latency, complete discovery took
about 1.6 seconds initially and 0.3 seconds with persisted method hints; warm
discovery sent zero collection method probes. Former sequential probes alone
would require 4 seconds. Hints retain their original timestamps, expire after
24 hours and never substitute for ACL grants. Cold probes use concurrency four;
optional network/server failures do not abort readable inventory. The normal
[discovery regression](../test/dav/discovery/caldav_discovery_test.dart) checks
request counts, persistence and expiry without a timing-based assertion.

### CI and acceptance scope

The reviewed head `cbebba7facf552117a867001665225b3583f96f5` now has passing
[Linux](https://github.com/busystack/busymax/actions/runs/41760333781),
[Android](https://github.com/busystack/busymax/actions/runs/41760333876) and
[Windows](https://github.com/busystack/busymax/actions/runs/41760333952) workflows.
Those runs do **not** qualify these subsequent working-tree changes. Release
still requires passing CI for the exact final committed revision. Native Windows,
interactive installed 0.4.0 Snap and Android 17/API 37 local-network prompting
remain acceptance gates; they are not silently accepted by this record.

## Known limitations and acceptance boundaries

- **Baïkal duplicate UIDs:** independent conditional PUTs of the same UID at
  distinct member URLs both receive **201**, contrary to
  [RFC 4791 §5.3.2](https://www.rfc-editor.org/rfc/rfc4791.html#section-5.3.2).
  Fresh BusyMax UIDs and duplicate-import skipping do not qualify server UID
  enforcement.
- **Radicale permission advertisement:** rights `rwl` yield PROPFIND 207 with
  `DAV:all`, `DAV:write` and `DAV:write-content`, while displayname PROPPATCH
  returns **403**. The advertised aggregates are inconsistent with
  [RFC 3744](https://www.rfc-editor.org/rfc/rfc3744.html#section-3.2).
  BusyMax reports rejection and preserves metadata. Protected collection-delete
  denial is also covered. See [the edge tests](../test/dav/caldav_release_edges_live_test.dart)
  and [fixture rights](../test/interop/caldav/rights).
- **Radicale initial synchronization:** an empty-token REPORT returns HTTP 207
  containing a 404 tombstone for a previously deleted member alongside the kept
  member's ETag and a sync token, contrary to
  [RFC 6578 §3.4](https://www.rfc-editor.org/rfc/rfc6578.html#section-3.4).
  BusyMax handles valid-form tombstones without inferring inventory completion
  or bypassing pagination validation. Real lost-response/rebaseline tests and
  parser regressions cover this behavior; server conformance is not claimed.
- **BusyStack component scope:** mixed creation returns
  `403 CALDAV:supported-calendar-component`; separate VEVENT/VTODO collections
  are qualified. Scheduling delivery, CardDAV, server-executed alarms and general
  file storage are outside this server release's scope. Stored metadata is
  covered by round trips.
- **Unverified native acceptance:** Windows runtime, Android **17/API 37**
  local-network permission prompting, and interactive installed **0.4.0 Snap**
  account/editor acceptance remain unverified. The older Snap profile and
  Android API-29 evidence do not close these boundaries.
- New live Google, Microsoft, iCloud and Nextcloud authorization was not part
  of this qualification. Their deterministic regressions are separate evidence.

Generic accounts do not advertise DNS email/domain discovery, Digest/OAuth,
RFC 6638 invitation delivery/free-busy, Nextcloud sharing/federation/trash,
certificate exceptions, native attachment services, pinning or subtask-visibility
extensions. Unsupported recurrence forms and unknown fields are preserved;
detached task occurrences are not independently edited in the UI. See the
[provider matrix](provider_support_matrix.md) and [setup guide](caldav_setup.md).

## Reproduction

Use the toolchain and setup in [Development](development.md). The maintained
[CalDAV fixture guide](../test/interop/caldav/README.md) contains the exact
Docker setup/provisioning, HTTPS readiness, complete live and additional suites,
Linux/Android native and process-restart commands, reset and teardown procedures.
Run shared lifecycle, additional profile tests and native tests sequentially;
they rotate credentials or restart isolated servers. Keep generated credentials,
private keys, local defines and execution logs in ignored fixture storage.

```bash
# Deterministic focused coverage and complete suite; Docker is unnecessary.
flutter test test/dav/storage/dav_collection_creation_notices_test.dart \
  test/dav/sync/dav_account_sync_engine_test.dart \
  test/features/settings/presentation/account_collection_creation_feedback_test.dart \
  test/db --reporter expanded
flutter test --concurrency=4 --reporter expanded

# After provisioning all three fixtures according to their guide:
BUSYMAX_CALDAV_LIVE=1 BUSYMAX_CALDAV_LIFECYCLE=1 \
flutter test test/dav/caldav_live_integration_test.dart --reporter expanded
BUSYMAX_CALDAV_LIVE=1 BUSYMAX_CALDAV_LIFECYCLE=1 \
flutter test test/dav/busystack_live_integration_test.dart --reporter expanded
```

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
