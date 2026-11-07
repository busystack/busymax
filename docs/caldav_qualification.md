# Generic CalDAV qualification

BusyMax qualifies the following implementations for the workflows below, not
universal CalDAV conformance. Results were recorded on 2026-11-02–03. This
record distinguishes deterministic regression coverage, real-server protocol
checks, native application checks and build validation. Documentation cleanup
does not constitute a new execution of these checks.

## 2026-11-07 final-corrections follow-up

This follow-up starts with a **clean** `release/v0.4.0` at
`40827a012638825b89a2898da570226218b29b57`. The earlier A1–A7 implementation
is already in this commit. Comparing HEAD with the private manifest of the
historical 5,081-pass run finds only a qualification-document difference.
Those historical results explain the baseline; they do not qualify the new
uncommitted corrections. Nothing in this follow-up is committed, pushed,
tagged or published. Version 0.4.0, Android code 8, schema 25 and all pins stay.

The optional-property regression first failed for structured 403 and 404 ACL
errors on the unchanged validator. The corrected BusyMax inventory validator
accepts the RFC 4918 sections 14.5/14.22 error container, including structured
condition details, while rejecting empty, duplicate and text/mixed-content
errors. It retains mandatory-property, resource-failure, href, duplicate and
baseline completeness checks. Optional ACL failure remains unknown; readable
calendars do not acquire inferred content/admin grants.

Conflict duplication now supplies explicit scheduling authorization to the
existing durable queue. Linux Settings, Windows conflict review and Android
Settings ask before attendee-bearing VEVENT/VTODO duplication. Cancellation
leaves the conflict/recovery options intact. The underlying queue still blocks
missing consent. Tests invoke the actual resolution service, preserve organizer,
attendees, unknown native properties, RRULE and RECURRENCE-ID, and reopen the
database before and after approval. Ordinary duplication remains covered.
The VTODO live consent case now executes independently of the separate inbox
REQUEST delivery case; successful storage is never labelled delivery evidence.

Independent observations of the unchanged pinned BusyStack server confirm:
home OPTIONS 200 with no creation method, proposed child OPTIONS 404, explicit
parent `DAV:all`/`write`, MKCALENDAR 201 and independent calendar readback 207.
Only the UUID-named disposable probe was removed (204). This is **independent
protocol evidence**, not acceptance of BusyMax's creation service. The user explicitly approved the provider-neutral unknown-capability policy
on this follow-up. Discovery persists method evidence separately from parent
ACLs. The UI permits a request when capability is unknown only if the parent
has an explicit grant. The production service then requires a fresh parent
bind/write/all grant before its journalled MKCALENDAR fallback. A successful
reserved-target OPTIONS/Allow omitting creation methods is unsupported; target
403 remains denied. OPTIONS 404/405/410/501 or a successful response without
Allow cannot establish creation support/refusal. General calendar-access grants
nothing. Unknown parent privileges block this fallback. Existing operation
UUID/reserved URL, exclusive lease, definitive rejection and reconciliation
rules remain. A previously rejected operation never becomes success solely
because policy changed. No provider override or upstream change was applied.

The original Radicale failure is retained. Its independent fixture client failed
before the next production sync, after a separately issued PUT. Server logs show
a 35.575-second PUT and concurrent 36.766/26.212-second health PROPFINDs;
no subsequent GET for that member reached Radicale before cleanup. Gateway
request logging was suppressed and retains no correlated event. Receipt times
prove the complete live run overlapped full Flutter, Android registration builds
and Gradle lint. This violated the maintained sequential qualification procedure
and is consistent with environmental stalls. It does **not** prove the precise
closing socket or original timeout mechanism. No retries, longer timeouts or
application transport changes were introduced on that basis. Current runs are
sequential; the original exact disconnect cause remains explicitly unproven.

Completed live results for this follow-up:

| Gate | Actual result |
| --- | --- |
| Complete main matrix | **59 passed, exit 0**, default application collection provisioning on all three pinned servers; no independent setup override. |
| Previously blocked BusyStack cases | All three focused cases passed through production administration: rejected creation/restart, lost-response identity reconciliation, and collection metadata/component management. |
| BusyStack additional suite | **6 passed, exit 0**, supported fresh lifecycle provisioning, unmodified pinned server. |
| Release-edge live suite | **5 passed, exit 0**, including identified partial-DELETE fault gateways and independent readback. |
| Scheduling live suite | **2 passed, 1 skipped, exit 0**: VEVENT REQUEST delivery and VTODO client consent/durable copy passed. Only actual VTODO REQUEST delivery skipped, because no initial inbox REQUEST was observed. |

The first complete follow-up run retained **58 passes, 1 failure, exit 1**:
the absent-calendar-ACL fault also removed parent-home ACL during fixture
creation. The new policy correctly blocked creation with unknown parent
privileges. Scoping that fault to calendar resources preserves every item-write
assertion and parent authorization for fixture setup. The subsequent complete
59-pass run includes the final strict-parent-ACL logic and this fixture correction.
An earlier full Flutter run was interrupted when the user approved the creation
policy; it is retained as partial evidence and supplies no complete-suite pass.

Completed deterministic/build results for this follow-up:

| Gate | Actual result |
| --- | --- |
| Complete Flutter, corrected catalogs | **5,142 passed, 103 gated/optional skips, exit 0**; source manifest `85485771499fb8a07a61e7922491a5ef24d97a991192ec27e98fec2fec276d83` over HEAD `40827a012638825b89a2898da570226218b29b57`. |
| Affected regressions | 405 passed; separate strict-parent/method/restart matrix 28 passed; all six production conflict routes use the actual service. These counts are separate runs, not added into the full-suite total. |
| Static/generation gates | Clean analysis, zero formatting changes, platform boundaries, localization and Drift reproduction passed. The final 38-test catalog audit passed without changed assertions. |
| Tooling and integrity | 81 release-tool tests and 29 verifier tests passed; actual read-only integrity verification passed 1,171 SDK files and eight reviewed packages. Repository hygiene and native registration CTest passed. |
| Native Linux clock/GTK | Maintained native script passed with the retained unmodified upstream Xvfb packages on PATH; no system package or tool source changes. |
| Android native/lint | Passed, 506 Gradle tasks. Newly built APK/AAB passed manifest/version/permissions, signature and 16 KiB ELF/ZIP/bundle alignment inspection. |

The first complete Flutter follow-up retained 5,141 passes, 103 skips and one
catalog-parity failure. New warning translations now cover every supported
catalog; the metadata-only generic Portuguese catalog and reviewed French
punctuation remain intact. Intermediate audit and generation-snapshot failures
are retained in private failure accounting. A braces-only lint issue was also
corrected. Hash reconstruction confirms that the earlier 59-pass live matrix
differs from the final runtime source only by that lint fix and warning
translations; no protocol/queue/recovery behavior changed afterward.

The new Android artifacts are **test-signed and provider-unconfigured**, not
production distribution artifacts. They are preserved before registration-mode
and QA builds can overwrite build output:

| Artifact | SHA-256 |
| --- | --- |
| New test-signed 0.4.0/code 8 APK | `eb553667709a11ffdda2a649950b31a9ca1541c0502f36372b12dddd08b7c9d8` |
| New test-signed 0.4.0/code 8 AAB | `9fe15ac450f2ec584e5b1c40555d96b9c169ea1fc203bf277f7948b519372400` |

Native and packaging results for this follow-up:

| Gate | Actual result and scope |
| --- | --- |
| Linux native TLS | **51 passed, exit 0**, real native TLS/authorization lifecycle and concurrency. |
| Linux editors and GTK | **3 pinned-server workflows passed** through production Settings/event/task editors; separate GTK header integration passed. Disposable fixture secrets/CA are explicit overrides. |
| Linux secure storage/process recovery | Both distinct OS-process phases passed for **all three servers**, including BusyStack. Production keyring/SQLite, queued edits, persisted uncertain collection identity and native notification acceptance were independently verified in an isolated desktop session. |
| Linux release bundle | New unconfigured release bundle built, exit 0. Its file-manifest SHA-256 is `bbebaf977012498f73137873aa3c46931bf61a76061dc9fc3d67326ad727264d`. This is not an installed Snap result. |
| Android registration modes | Both maintained registration-mode builds/inspections passed with synthetic public clients, not live production grants. |
| Android release-package smoke | After physical unlock, the exact saved test-signed APK passed cold startup and restart with distinct PIDs on API 29, exit 0. The application ID was initially absent; the owned installation was removed successfully. |
| Android native editors | **3 pinned-server workflows passed, exit 0**, including BusyStack production collection setup and failure feedback. Isolated QA package, disposable fixture secrets and private fixture trust; this does not substitute for production secure-storage or normal-package account acceptance. Owned QA package and only its three port mappings were removed. |
| Secret scans | Pinned Gitleaks: **282 reachable commits** and current source passed, exit 0, unchanged allowlist. The absolute-path diagnostic's 64 findings were independently matched to the existing allowlist: 62 checksum rows and two public curve names. Repository-relative paths restore those exact anchored exceptions. |
| Strict Snap | Actual fresh-bundle `snapcraft pack --use-lxd` failed, exit 1: the shared Snapcraft LXD profile references an unavailable storage pool. No shared profile/pool/project was changed; no new 0.4.0 Snap was produced or installed. |

The first phone launch waited behind secure keyguard. That owned attempt was
stopped and removed; no acceptance is claimed for it. After the owner unlocked
the phone, the separate successful smoke/native runs above completed. The
previous API-29 certificate/storage/process evidence remains historical and
separate. API 29 cannot establish API-37 permission acceptance.

The final formatting check covers 871 real repository files, zero changes.
An intermediate scan export under `build/` was included by recursive formatting;
its differently scoped package language settings caused one check-only format
finding in that copy. The preserved export was moved outside the repository;
no application file or formatter expectation changed. Private command receipts
also preserve intermediate fixture, catalog, scan-path and orchestration errors.

**Remaining external release requirements:** a newly packaged and installed
strict 0.4.0 Snap with full confined account/storage/editor/recovery acceptance;
authorized native Windows build/tests/MSIX/runtime acceptance (the other
agent's VM was untouched); native API-37 permission/interface acceptance;
actual VTODO scheduling delivery on a suitable unmodified server; production
signing/required provider-registration configuration; and successful Linux,
Android and Windows CI on the exact final committed candidate. Normal-ID
Android account/storage workflows are not established by the release startup
smoke or injected-fixture editor tests. The original Radicale socket closure
remains unproven because correlated gateway diagnostics are unavailable;
overlapping load and server stalls are established, and the isolated full
matrix passed without retries or increased timeouts.

No commit, push, tag, publication, merge or PR-state change was performed.
Committing the reviewed changes and pushing the branch to run exact-revision
CI require explicit authorization under the mission's no-commit/no-push rule.
This candidate is **not release-ready** while these mandatory gates remain.

Private evidence is appended as `corrections-*` command/source/exit receipts
under the existing ignored qualification directory; original receipts are
preserved. Each gate above records the actual command outcome; private receipts retain
exact source manifests and environment scope. Source manifests precede only documented later
warning translations and a braces-only lint fix; private hash reconstruction
verifies no other runtime change after the 59-pass live run. The replacement
full Flutter run and candidate native builds include those final translations.
This is not a release-ready declaration.

## Earlier 2026-11-07 qualification (superseded by the follow-up above)

This follow-up starts at `6b26f1db46f29dd7e68c75fe79367d88a2009a1d` on
`release/v0.4.0`, initially clean. Corrections are uncommitted; this is not a
release-ready declaration or final-revision hosted CI result. Version 0.4.0,
Android versionCode 8, schema 25 and the recorded shared-package pins remain.
The DAV pin is `33afd70a761822847a37c7ad47f5e61dfeaa74a7`. The official
Flutter 3.47.5 / bundled Dart 3.13.4 toolchain and lockfiles are used.

| Finding | Implementation and regression evidence |
| --- | --- |
| A1 contacts transport termination | Request-owned leased delegates; `authorization_leased_http_client_test.dart` and `nextcloud_certificate_lifecycle_test.dart` cover retries without reconnect across standard fixture HTTPS, private CA and leaf pinning. Fixture roots are explicit, not public-PKI native acceptance. |
| A2 fallback completeness | Dedicated PROPFIND validation; file-backed `dav_sync_engine_test.dart` seeds events/tasks/pending edits, rejects empty/failed/ambiguous/malformed inventories, reopens and recovers with an ETag-less empty collection. RFC 6578 pagination is separate. |
| A3 partial DELETE | Inspect multistatus, reconcile uncertain outcomes and distinguish refresh pending; `dav_collection_creation_identity_test.dart` plus production Linux sidebar, Windows source pane and Android settings tests retain partial-deletion feedback. Windows widgets execute on Linux, not in a Windows runtime. |
| A4 home layouts | Inspect direct homes, bound/cancel nested traversal, deduplicate overlaps, persist actual parent evidence; `caldav_discovery_test.dart` includes denied/incomplete traversal and database reopening. |
| A5 duplication consent | Repository and pending-create boundary, recursive transaction, persisted decision; repository mutation and three production duplication route tests. Baikal delivered an isolated VEVENT REQUEST. VTODO delivery has not been demonstrated on that unmodified target and is not inferred from storage. |
| A6 contacts permission routes | Shared foreground permission flow and headless per-request gate; production settings routes and file-backed retained-account recovery tests. Native API 37 acceptance is recorded separately. |
| A7 routed classification | App-owned Android route/interface bridge, CGNAT boundaries and scoped IPv6 handling; Kotlin route tests and Dart host tests. Unknown routing retains explicit settings recovery. |

Historical hygiene's seven matches were synthetic fixture URLs, corrected to
unambiguous `calendar-homes` URLs without weakening the checker. The Windows
transport fixture now explicitly establishes keep-alive and bypasses ambient
proxy settings; both body assertions and the one-connection assertion remain.
A Windows rerun is pending because the VM belongs to another agent and must
remain untouched. The Android timed-detail fixture pins UTC and viewport,
places the event at visible local noon, and asserts the detail opened before
checking labels. The previously unfinished Python runtime-verifier test and
complete 81-test release-tool suite have completed successfully; fake-lxc tests
are tooling evidence, not real-VM acceptance.

Executed checks retain private command/UTC/source-manifest/exit receipts and
logs under ignored `build/release-v040-qualification-20261107/`. Each receipt
records its own source hash; counts from intermediate trees are not combined.
Negative controls in an isolated source copy reproduced A1–A7 regressions.
Official SDK/package integrity verification executed successfully (not just its
unit tests). Sibling IDE metadata is pre-existing and was left untouched;
clean pinned clones separately passed the dependency checkout/resolution gate.
Generated localization/Drift sources reproduced without changes. A subsequent
full run exposed host-disk latency in the new file-backed contacts permission
regression. A diagnostic repeat exceeded its unchanged 30-second deadline;
the maintained real-file persistence helper completed all stages in 574 ms
under the same workload. The test now uses that helper without changing SQLite
durability, assertions or its deadline. The complete rerun passed 5,081 tests with 102 gated/optional skips and exit 0
after this fixture correction.

### Earlier execution evidence (2026-11-07)

| Check | Result and practical scope |
| --- | --- |
| Complete Flutter suite | 5,081 passed, 102 gated/optional skips, exit 0 after the final test correction; includes migrations through schema 25 and existing provider/security/persistence regressions. |
| Static and generation gates | Formatting: 868 files, zero changes; analysis clean; platform boundaries and repository hygiene passed; localization/Drift reproduction matched the reviewed generated files. |
| Android native/build checks | Native platform unit tests and app lint passed (506 Gradle tasks); both registration-mode builds and inspections passed with synthetic public clients, not live grants; candidate manifest/alignment/signature inspection passed. |
| Python release tooling | 81 passed; separate runtime-verifier file: 10 passed in under one second, including the exact-package/owned-VM cleanup case. Its fake `lxc` is not real VM acceptance. |
| SDK and package integrity | Actual read-only verifier: 1,171 SDK files and eight reviewed packages passed; separate verifier unit suite: 29 passed. |
| Linux native TLS and GTK | 51 TLS/concurrency cases and the GTK integration passed in the native engine. Native clock/weekday/GTK checks, registration-helper teardown and the standalone registration CTest also passed. Explicit fixture trust is identified. |
| Linux production settings/editors | Three server workflows passed with injected disposable secrets and fixture CA. This does not qualify secure storage or the installed Snap. |
| Linux separate OS processes | Both phases passed for Radicale 3.9.0 and Baïkal 0.13.0, with an isolated production keyring, SQLite, pending edits, persisted collection identity and real notification-daemon acceptance. BusyStack was explicitly omitted because collection creation lacks positive advertisement. |
| Android certificate review | API 29: six native TLS/storage cases passed; the separately enabled native CA-picker case also passed. An earlier gated picker case adds no acceptance evidence. |
| Android native settings/editors | Three pinned-server workflows passed on the unlocked API 29 phone. A locked first attempt was interrupted and excluded; the clean retry completed with independent readback. |
| Android secure storage and engine coordination | Both real-process recovery phases passed for Radicale 3.9.0 and Baïkal 0.13.0. Production secure storage/SQLite retained queued work; a separate real foreground/WorkManager lease test also passed. |
| Release artifacts | Linux release bundle and normal-ID Android APK/AAB built. Android manifest/version/permissions, signatures and 16 KiB ELF/ZIP/bundle alignment passed. Android artifacts use the test signer and unconfigured provider paths; they are not distribution artifacts. |
| Partial collection deletion | Five release-edge live tests passed, including all three pinned servers behind an identified fault gateway. A real child deletion, injected DELETE 207/423, independent server readback and database reopening verify reconciliation. This does not assert that those servers naturally emit 207/423. |

Android runtime evidence uses isolated QA integration APKs built from the same
application code, with their test trust/storage overrides identified above.
The saved normal-ID release APK/AAB were built and inspected, not installed for
interactive release-package acceptance. Both task-owned QA packages, recorded
phone mappings and the public certificate-picker file were removed afterward;
normal application/package state and device settings were preserved.

The source manifest used for the final-code artifacts is
`03483cdc8ab85a33bdad1009d99a30e950b869e5131f9d9588a6e9218252b742`
over HEAD `6b26f1db46f29dd7e68c75fe79367d88a2009a1d`. Subsequent changes
are qualification documentation and the contacts persistence-test fixture; the
application/build inputs remain identical. Private receipts retain exact file
manifests and commands.

| Artifact | SHA-256 |
| --- | --- |
| Test-signed 0.4.0/code 8 APK | `f7cb1b21e1f5a0d59710fecf9fd00a55e832d0a7c95a477675bf6cff27d1b8df` |
| Test-signed 0.4.0/code 8 AAB | `c8760ae0f721d84b0235187761999f3dfe098e5680186dd99e18d6f57359b366` |
| Linux release bundle file-manifest hash | `192a9d08230530e881452b15d633ca2b4b890330e737715056e3f955cc84e062` |

The final complete main live run with explicitly independent fixture provisioning
completed with **55 passes, four failures, exit 1**. Three BusyStack application
collection-administration cases were blocked by missing positive method
advertisement. The fourth was a Radicale independent GET readback disconnect
before response headers, not an established production lifecycle defect. Three
focused repetitions passed without source changes; the failed complete result
remains, and the disconnect cause is not established.
An earlier main run also finished 55/4, but its fourth failure was the subsequently
corrected credential-registry fixture. Those results must not be combined into
a successful complete harness. The default application-provisioned BusyStack
matrix also remains blocked. Independent MKCALENDAR fixture setup is not evidence
that BusyMax's creation route passed.

All **six BusyStack additional cases passed together, exit 0**, after provisioning
a fresh disposable lifecycle account through supported administration and MFA.
The first preparation attempt hit the browser's 30-second navigation timeout;
an instrumented copy of the same BusyMax-owned script retried successfully
without changing authentication or server software. Credential expiry aging is
explicit database fault injection restricted to that issued QA credential.
Real 507 paging, strict Depth 0, installation prefixes, sharing, representation
repair, revocation and account disabling retain independent readback.

The final release-edge suite passed **five tests, exit 0**. The final scheduling
suite passed **one VEVENT delivery test and skipped one VTODO delivery test**:
Baïkal stored the attendee-bearing VTODO, but no inbox REQUEST was observed.
A stored object or successful PUT is not task-delivery evidence.

The actual strict Snap pack command failed because the existing Snapcraft
project's provider profile references an unavailable storage pool. No shared
LXD project, profile, instance or pool was changed. No new 0.4.0 Snap was produced
or installed, and the installed older Snap was left untouched. Official release
packaging also requires a clean committed candidate; committing is not authorized.
The API 37 AVD failed to boot with either hardware or software acceleration; only
that task-owned emulator was stopped and its isolated AVD removed. The connected phone is API 29 and cannot
close the API 37 gate. The authorized Windows VM is deferred by the user because
another agent is using it; no Windows runtime or MSIX acceptance was attempted.

Required gates remain open until explicitly supported by candidate evidence:
final committed-revision Linux/Windows/Android CI (publishing needs separate
authorization); actual newly packaged strict 0.4.0 Snap acceptance; Windows
candidate/MSIX/native acceptance (deferred by request); API 37 permission
acceptance; and actual VTODO message delivery on an unmodified capable target.
Older native/Snap results below are historical and do not close these gates.

## Historical qualification baseline (2026-11-02–03)

The matrices and counts below retain their original revision-specific results.
They are not current-candidate passes. In particular, their BusyStack collection
administration and older Snap/API coverage do not close the open gates above.

### Qualified implementations

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

### Offline-notice settings correction (2026-11-04)

A follow-up review found that the earlier offline-notice regression mounted the
shared feedback widget directly. It missed all three production settings parents,
which still required an in-memory failure before mounting that widget. The
4,683-test run and native/build results above predate this correction.

The settings parents now observe a shared provider merging persisted notices
with current-process failures before deciding whether to mount feedback. Empty
results produce no feedback row or warning panel. The Linux account overview
uses the same persisted state for its warning indicator.

Six regressions exercise the real Linux, Android and Windows settings screens
with empty collection-failure activity and a failed DAV synchronization: stored
rejections appear, accounts without notices have no feedback widget, other-account
notices stay hidden, and offline dismissal removes feedback while preserving the
rejected journal entry. These tests issue no HTTP requests. Restoring the original
parents makes all three stored-rejection cases fail; the corrected parents pass.
The affected settings/storage/native-UI suite passed **191 tests**, and static
analysis was clean. This is scoped validation, not another full-suite or native
runtime qualification; CI must still cover the final committed revision.

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

Deterministic transport regressions now cover a stalled connection on a reusable
native lane, connection reuse with a slower response, and sibling cancellation
isolation. Compact timezone continuation tests cover Cairo, Santiago, shifted
transition clocks, leap/century boundaries, round trips, and an ordinary event
edit sent to a simulated 16 KiB-limited DAV endpoint. For definitions starting in
2025, measured Cairo output decreased from 149,133 to 3,466 bytes and Santiago
from 295,006 to 3,286 bytes (unfolded CRLF-separated VTIMEZONE UTF-8). These are
local deterministic results, not new live-server or native API-37 acceptance.
See the [retained-account permission acceptance steps](android_setup.md) for
denial, approval, revocation, permanent denial, and background synchronization.

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
  test/features/settings/presentation/account_collection_creation_routes_test.dart \
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
