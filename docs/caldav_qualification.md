# Generic CalDAV qualification

BusyMax qualifies the following implementations for the workflows below, not
universal CalDAV conformance. Initial results were recorded on 2026-11-02–03;
dated follow-ups below identify subsequent executions. This record
distinguishes deterministic regression coverage, real-server protocol
checks, native application checks and build validation. Documentation cleanup
does not constitute a new execution of these checks.

## 2026-11-08 engineering audit and release decision

**Recommendation: NO-GO for production release.** The investigated implementation
faults have focused corrections and regression evidence. Native distribution
acceptance and CI for the new local revision are separate, still-open gates.
Nothing was pushed, merged, tagged, published, or changed on PR #38.

### Revision and scope

- Clean starting BusyMax branch: `release/v0.4.0`,
  `34d771b91e460469b7d513f1ff241dc9c822cc52`; PR #38's actual head matched it.
- Audited implementation and final regression revision:
  `60edc0fdadff260a2b2215bc95534dc3db24467f`. The main corrections are
  `b8e72a57a3950ca698031eaca55cc222501bf730`, explicit coverage is
  `9370560da5bb01eaead86f278887667535194e44`, and the final worker correction is
  `88d5e6678505c075d6cddc75f2c5b896954f97be`; owner cancellation during pool
  retirement is protected by `60edc0fdadff260a2b2215bc95534dc3db24467f`. The documentation-only
  follow-up containing this record is identified by `git log -1 -- docs/caldav_qualification.md`.
  The final delivery supplies that documentation commit's exact hash.
- Comparison base: PR's `main` at `daee1dfc3c0a3bf24e6124d88c88ad399ab7fcdc`;
  387 release files, 58,590 additions and 2,891 deletions were inventoried before
  these fixes. Review concentrated on reachable application paths and their
  maintained deterministic, persistence, security, live and native checks.
  This is workflow qualification, not a universal CalDAV conformance certificate.
- First-party `busystack_dav` started at
  `33afd70a761822847a37c7ad47f5e61dfeaa74a7` and now pins
  `ce5f75aee0477b2056bb60e928ee362949a82b23`, through its own local commits
  `1702615b96fef73b5b928020c1c1c065012fcd9c` and
  `ce5f75aee0477b2056bb60e928ee362949a82b23`. Its pre-existing IDE edit was
  preserved and excluded. Contacts and Graph pins, version 0.4.0,
  Android versionCode 8 and schema 25 are unchanged. No third-party source was modified.

### Independently established findings

| ID / impact | Production path, reproduction and root cause | Correction and regression evidence |
| --- | --- | --- |
| A / high, destructive transfer | `CalendarRepository._transferDavEventResource` journals a destination `dav.create` and dependent source delete or recurrence update. Successful replay records durable copy confirmation, then removes the create dependency. Under production `implicitScheduling=true`, a successful PUT followed by same-UID readback could bypass content comparison. The old movement fixture used the default `false`, hiding this path. Five initial regressions failed for lost alarm description, alarm, RRULE, detached exception and changed extension data; final coverage separately checks loss of the VEVENT description. | Creates with source-destruction dependents now require the existing conservative semantic comparison, including known metadata normalization. A changed UID or meaningful property loss remains an explicit conflict and retains the original and dependency. Ordinary scheduling creates retain the approved server-updated participation behavior. File-backed transfer tests reopen after an unverified successful PUT and again after durable confirmation, proving one PUT and a source DELETE only after confirmation. A normalization success case preserves alarms and detached exceptions. |
| B / medium, synchronization availability | Batches contain up to 100 members; the application and HTTP resource budget is 16 MiB, whereas the parser limits XML to 8 MiB and text to 4 MiB. Valid members can collectively exceed text/transport budgets, or one valid member can exceed XML budgets. Previously the same REPORT would fail every attempt. | On aggregate byte/text limits only, discard the REPORT and use sequential, individually bounded GETs. All other XML/protocol errors remain fatal. Tests exercise valid large ICS payloads, both parser and transport limits, real production UTF-16 multiget, and file-backed rejection/success with cursor, projections, raw resources and queue comparisons after reopen. Existing transaction boundaries promote no batch until every fetch and parse succeeds. A real-server case on each pinned implementation uses a labelled smaller parser text budget and independent GET/ETag comparison; this qualifies recovery without claiming every server permits a 9 MiB resource. |
| C / medium, incorrect recovery feedback | `accountCollectionCreationFailuresProvider` preferred cached activity failures, including IDs absent from loaded storage. A pending notice could survive a committed journal or override a newer rejected journal after unrelated synchronization failure. Both focused transition tests failed before correction. | Once storage loads, its complete result is authoritative, including an empty result. Activity remains only the loading fallback. Durable identities, rejection diagnostics and acknowledgments are unchanged. New transition tests and the existing UI/restart/acknowledgment and live journal tests cover feedback. |
| D / medium, stale foreground Settings | Android's worker already emits native `dataChanged`; the foreground invalidated accounts, tasks and conflicts, but not collection/journal query state. Separate SQLite connections do not broadcast Drift updates. Both mounted-Settings event/resume tests fail on the original code. Provider recreation alone also failed the retained-query resume case. An additional worker-path regression demonstrated that a reminder refresh exception suppressed the native data-change signal after DAV work. | Notify Drift of changes to collections, creation journals and acknowledgments at the existing `dataChanged` and resume boundaries, preserving other refreshes. File-backed widget tests use two independent SQLite connections and the actual native event/lifecycle handlers. They demonstrate refreshed discovery inventory and rejected creation state without polling in production. The worker now attempts foreground notification independently while retaining its failure/retry result; both success and reminder-failure tests invoke the actual platform-channel API. Device-level worker-engine acceptance is still a separate gate. |
| E / medium, unstable retry identity | After HTTP 412 the mutation service chose a replacement filename only in memory. Restart reconciliation still fetched the original occupied URI; the regression independently reproduced that identity mismatch. | A pre-dispatch callback transaction persists the selected member URI, create payload filename and pending draft object's URI before the replacement PUT. Failed persistence prevents dispatch. Five file-backed failpoints cover before-send, after-send, readback, projection insertion and acknowledgment deletion, reopening the DB and asserting one canonical draft identity, the replacement target and no duplicate committed PUT. These are deterministic failure injection and database-reopen tests, not a claim of OS process killing at every instruction. |
| XML / medium, inherited first-party standards defect | Both buffered and streaming DAV parsers decoded unconditionally as UTF-8. Four UTF-16 BE/LE buffered/byte-stream cases failed. Discovery, PROPFIND and REPORT use the shared parser, so the defect is reachable in production. | Fixed in the separate first-party DAV component, with strict surrogate/odd-byte validation, split-BOM/character handling, endian-specific input, DTD/entity rejection and unchanged resource/cancellation limits. Its full suite passes 101 tests and analysis is clean. No third-party XML library changed. BusyMax's production multiget regression verifies adoption. |
| TLS / medium, confirmed narrow renewal failure | Existing renewal tests closed the old server and constructed new clients. The requested real sequence retained a CA-approved live socket, replaced the server certificate under the same CA, let the old leaf expire and reused the client. It failed before dispatch with `NextcloudCertificateexpired`. | Retire the pool before new dispatch when a private-CA peer has expired; establish a fresh connection with a validated chain, validity period and service identity. Four real-socket cases cover renewed/unrenewed servers and ordinary/terminating HTTP. Expired unrenewed servers remain rejected before HTTP. Separate real-response tests prove that graceful retirement permits an in-flight response to finish, while owner closure still terminates retired responses. A cancellation regression in the initial implementation was reproduced and corrected before final acceptance: only actively draining retired pools remain tracked, and completion/cancellation removes them. No request replay was introduced. Exact leaf pinning and ordinary HTTPS retain existing validation. |

The seven investigation targets were confirmed in the narrower forms above;
none was accepted solely from a previous AI report. No original target was
disproved. The TLS evidence is limited to the retained, expired peer; ordinary
fresh-client renewal already worked. The approved ordinary scheduling-create
flow can receive updated participation, but its UID-only acceptance cannot
authorize destructive transfer. Server normalization is not
itself a defect. Missing property data is not proof of resource deletion.

One additional **test-fixture defect** was independently exposed: the partial
collection-deletion live test counted tasks by title across the entire account.
After a timed-out earlier run, two different collections contained `Partial locked`.
Raw collection objects and independent server readback were correct. Both task
assertions now use the fixture's collection identity. This is not a BusyMax
cross-collection deletion bug, and no product code or server behavior was changed
for it.

### Independent implementation and standards review

The actual execution paths checked include generic onboarding and secret binding,
provider profiles and href resolution, discovery inventories, account replay and
leases, collection administration/journals, object projection transactions,
recurrence/timezone semantics, native notifications, and platform settings.
Regression and live evidence substantiate the supported operations below;
unexecuted platforms and feature extensions remain explicitly unqualified.

| Requirement and authoritative reference | Implementation and evidence checked |
| --- | --- |
| [CalDAV RFC 4791](https://www.rfc-editor.org/rfc/rfc4791.html), sections 4.1, 5.3 and 7.9 | Complete calendar resources, strong conditional writes, UID conflicts, multiget resource versus property status, component restrictions and actual GET readback. Existing ambiguity/duplicate safeguards were retained; no property-404 deletion fallback was reintroduced. |
| [WebDAV RFC 4918](https://www.rfc-editor.org/rfc/rfc4918.html), sections 8, 9, 13 and 19 | Href boundaries, conditional operations, partial DELETE handling, multistatus interpretation and required UTF-16 processing. Byte/text/depth/entity protections remain enforced; HTML/error responses cannot become inventory. |
| [iCalendar RFC 5545](https://www.rfc-editor.org/rfc/rfc5545.html) and its [current update metadata](https://www.rfc-editor.org/info/rfc5545/) | Recurrence exceptions, DTSTART/DTEND and all-day semantics, embedded timezones, alarms, opaque properties, VTODO completion/recurrence and preservation during moves/imports. Existing gap-resolution and UNTIL tests align with verified errata 4271 and 4414. Later extensions, including non-Gregorian recurrence and new task extensions, were not silently added to product support. |
| [WebDAV Sync RFC 6578](https://www.rfc-editor.org/rfc/rfc6578.html), sections 3.3, 3.6 and 3.7 | Depth 0, real 507 continuation, token loops/page bounds, invalid-token rebaseline, collection-scoped failure barriers, resource deletions and atomic cursor promotion. Oversized/rejected fetches retain the baseline. |
| [Scheduling RFC 6638](https://www.rfc-editor.org/rfc/rfc6638.html) | Scheduling consent, Schedule-Tag/ETag policy, readback and server SCHEDULE-STATUS transformations; safe source retention for content changes. Actual VEVENT delivery is distinct from successful storage of an attendee-bearing VTODO. |
| [Discovery RFC 6764](https://www.rfc-editor.org/rfc/rfc6764.html), sections 5–6 | Root well-known discovery, installation prefixes, same-origin HTTPS redirects including the pre-existing HEAD 303 fix, principal/home discovery and relative hrefs. Cross-origin/downgrade redirects do not acquire account credentials. No new DNS enrollment contract was added. |
| [TLS identity RFC 9525](https://www.rfc-editor.org/rfc/rfc9525.html) | SAN/IP/wildcard checks, no CN fallback, certificate time/signature/CA constraints, owner/authority/installation binding, exact self-signed leaf pinning and private-CA isolation. Generic CalDAV still constructs the standard native client and cannot inherit Nextcloud exception approval. |
| [XML media types RFC 7303](https://www.rfc-editor.org/rfc/rfc7303.html) | Strict XML UTF-16 decoding belongs in first-party DAV parsing; UTF-8 remains strict. Buffer and stream paths retain security/resource guards. |

The current RFC Editor update relationships and errata were retrieved on
2026-11-08. The web tool could not follow most errata redirects; direct HTTPS
retrieval of the official RFC Editor records succeeded. Records retrieved:
RFC 4791: 24; RFC 4918: 9; RFC 5545: 39; RFC 9525: 1; no records returned for
6578, 6638 or 6764. Verified errata were distinguished from reported, held and
rejected proposals. Relevant checks included 4791/1002 (privilege condition),
1476 (namespaces), 4161/4166/4167 (VTODO alarm anchoring), 4918/1519 (href versus
Destination semantics), 5545/3779, 4271 and 4414 (recurrence), and held editorial
9525/8173. The updated CalDAV relationships include RFC 5689, 6638, 6764, 7809,
7953 and 8996; these were not treated as authorization to expand supported
components or administration. A full implementation of every optional extension
was not claimed.

Official [sabre/dav client](https://sabre.io/dav/building-a-caldav-client/),
[scheduling](https://sabre.io/dav/scheduling/),
[Baïkal](https://sabre.io/baikal/) and
[Radicale](https://radicale.org/v3.html) documentation was consulted. Server
limitations remain server observations, including Radicale's property-lock ACL
inconsistency, Baïkal's recorded duplicate-UID behavior, and the absence of
independently demonstrated VTODO scheduling delivery. Dart documents
[graceful HttpClient closure](https://api.dart.dev/dart-io/HttpClient/close.html)
and [TLS 1.2 as the default minimum](https://api.dart.dev/dart-io/SecurityContext/minimumTlsProtocolVersion.html).
The corrected foreground notification follows Drift's
[manual table-update API](https://drift.simonbinder.eu/dart_api/streams/).
Android worker scheduling was checked against the official
[WorkManager documentation](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work).

### Exact changed-file inventory

BusyMax production:
`lib/src/features/calendar/data/calendar_repository.dart` was traced but did
not require modification. Changes are limited to:

- `lib/src/dav/mutation/dav_conditional_mutation_service.dart`: transfer content
  requirement and awaited target reservation hook.
- `lib/src/dav/mutation/dav_pending_operations.dart`: recognize destructive
  dependents; transactionally reserve dispatch and pending-draft identities.
- `lib/src/dav/sync/dav_collection_remote_client.dart`: bounded sequential GET
  recovery for oversized aggregate XML only.
- `lib/src/app/app_bootstrap.dart`: authoritative persisted notice precedence.
- `lib/src/android/android_app.dart`: external table-update notification on the
  existing event/resume boundaries; `lib/src/android/android_background.dart`:
  publish foreground changes even when reminder reconciliation fails.
- `lib/src/dav/trust/nextcloud_http_client_factory.dart` and
  `lib/src/core/http/native_terminating_http_client.dart`: gracefully retire
  obsolete private-CA pools before validated fresh dispatch.
- `tool/shared_dependencies.json`: pin the independently tested DAV correction.

Regression changes:
`test/dav/mutation/caldav_event_movement_test.dart`,
`test/dav/mutation/dav_conditional_mutation_service_test.dart`,
`test/dav/mutation/dav_pending_operations_test.dart`,
`test/dav/sync/dav_collection_remote_client_test.dart`,
`test/dav/sync/dav_sync_engine_test.dart`,
`test/dav/trust/nextcloud_private_tls_test.dart`,
`test/core/http/native_terminating_http_client_test.dart`,
`test/features/settings/presentation/account_collection_creation_feedback_test.dart`,
`test/platform/android/android_adaptive_app_test.dart`,
`test/platform/android/android_runtime_lifecycle_test.dart`,
`test/dav/caldav_reconciliation_live_test.dart` and
`test/dav/caldav_release_edges_live_test.dart`.
This qualification record is the sole documentation change.

First-party DAV changes, in its own repository:
`lib/src/xml/dav_xml.dart`, `lib/src/xml/dav_stream_parser.dart`,
new `lib/src/xml/dav_xml_encoding.dart`,
`test/xml_contract_test.dart`, new `test/xml_encoding_test.dart`, and
`CHANGELOG.md`.

### Executed verification and remaining acceptance gates

The final full-suite and release-build revision is
`60edc0fdadff260a2b2215bc95534dc3db24467f`; only this report changes afterward.
The live mutation/synchronization/discovery implementations and DAV pin are
unchanged since the executed live runs. Android notification and native pool
follow-ups were checked separately and in the final suite. Intermediate
5223/5227-test passes and intentionally interrupted follow-up runs are not
substituted for the final result below.

| Executed check / maintained command | Independently observed outcome |
| --- | --- |
| `flutter test --concurrency=4 --reporter expanded` | **5,232 passed, 121 skipped, 0 failed, exit 0** on final source. Skips remain opt-in live/provider/benchmark gaps, not passes. |
| Focused mutation/sync/feedback, file-backed recovery and Android lifecycle checks | All final cases pass within the complete suite. Separate final checks: **68** movement/remote-client cases, **5** collision failpoints, **15** worker lifecycle cases; TLS/HTTP **93 passed, 2 opt-in skips**. Initial failing regressions are described with their findings above. |
| `flutter test test/db --reporter expanded` | **36 passed**, including actual schema upgrades, interruption rollback and bounded database contention. No schema change was introduced. |
| First-party DAV: bundled `dart test`; `dart analyze`; formatting | **101 passed, 0 failed**; analysis clean. Contacts consumer's own suite: **119 passed**. |
| `BUSYMAX_CALDAV_LIVE=1 BUSYMAX_CALDAV_LIFECYCLE=1 flutter test test/dav/caldav_live_integration_test.dart --reporter expanded` | Complete final three-server run: **59 passed**. Initial run: 57 passed/2 rejected authentications; both were the expired disposable BusyStack `bob` credential. Supported MFA issuance corrected the fixture, then all 59 passed unchanged. |
| `test/dav/busystack_live_integration_test.dart`, same opt-ins | **6 distinct cases passed across executions**. Five passed in the combined additional run; the old lifecycle account returned 401. A fresh disposable account was provisioned through supported administration/MFA; the isolated revocation/expiry/disabling case passed, **1/1, exit 0**. This is not described as one new 6/6 invocation. |
| `BUSYMAX_CALDAV_LIVE=1 flutter test test/dav/caldav_reconciliation_live_test.dart --reporter expanded` | **18 passed**: three actual-server aggregate-budget cases plus the 15 existing labelled gateway reconciliation/discovery cases. Each uses independent remote readback; injected gateway behavior is not attributed to upstream servers. |
| Same opt-in, `test/dav/caldav_release_edges_live_test.dart` | Final isolated run after the collection-scoping fixture correction: **5 passed, exit 0**. The initial combined run had one timeout while the full suite was active; the first isolated attempt exposed the unrelated-collection title count, which was fixed only in the fixture. |
| Same opt-in, `test/dav/caldav_scheduling_live_test.dart` | Isolated unchanged rerun: **2 passed, 1 skipped, exit 0**. VTODO consent/storage and real VEVENT inbox REQUEST passed. VTODO inbox REQUEST was not demonstrated and remains unqualified. The initial concurrent run timed out in the consent case; no deadline or product code was changed to obtain the isolated pass. |
| `flutter analyze`; `dart format --output=none --set-exit-if-changed .`; platform-boundary and hygiene tools | Clean analysis; **872 files, zero formatting changes**; boundary, tracked-text hygiene and `git diff --check` pass. |
| Locked Pub resolution; generated-source snapshot, `flutter gen-l10n`, `dart run build_runner build --delete-conflicting-outputs --force-jit`, snapshot verify | Locked resolution succeeds; localization/Drift output reproduces the reviewed source unchanged. The generator reports that its deprecated delete-conflicting-outputs flag is ignored; no generated drift was accepted. |
| SDK verifier; upstream checker; checker tests | Official Flutter **3.47.5**, bundled Dart **3.13.4**. **1,171 SDK files and 8 upstream packages** verify unchanged; **29** checker tests pass. |
| `python3 -m unittest discover -s test/tool -p '*_test.py'` | **81 passed**. |
| Workflow-pinned gitleaks Git-history scans | BusyMax and the separate first-party DAV histories have **no detected leaks**. Synthetic fixture private material is not committed. The first-party scan includes both new parser commits. |
| `bash tool/release/check_linux_native.sh`; native registration-reader CMake/build/CTest | Native checks pass with official unmodified Ubuntu Xvfb/xauth packages in isolated tooling; registration reader **1 CTest passed**. The sandbox initially denied D-Bus socket creation; execution with socket access passed. |
| Isolated XDG/Xvfb Linux CalDAV integration | **3 passed, exit 0** on final source. Actual Settings/onboarding and event/task editors with independent DAV readback. The fixture injects its database, secrets and QA CA client, so this does **not** certify the normal package's secure-storage backend. |
| `xvfb-run -a flutter test integration_test/nextcloud_private_tls_linux_test.dart -d linux --reporter expanded` | Final implementation: **55 passed, exit 0** in the real Linux Flutter engine, including renewed/unrenewed retained private-CA sockets and authorization lifecycle. |
| `android/gradlew --project-dir android :busymax_android_platform:testDebugUnitTest :app:lintDebug` | **BUILD SUCCESSFUL**; native plugin JUnit results show **18 tests, 0 failures/errors/skips**. This is native unit/lint evidence, not device acceptance. |
| `flutter build linux --release -t lib/main_linux.dart` | **Passed** on final source, normal unconfigured entry point. Compilation is not installed-package runtime acceptance. |
| `tool/android/build_release.sh --all --test-signing --allow-unconfigured-providers`; maintained artifact inspector with official bundletool | Final-source APK and AAB **built and inspected successfully**. 16 KiB native LOAD/ZIP alignment, AAB `PAGE_ALIGNMENT_16K`, notification drawable, package permissions and signing were inspected. Explicitly **test-signed and unconfigured**. Existing KGP/Gradle deprecation and watcher diagnostics were retained; no dependency/SDK patch was used. |
| Android device/API 37 runtime | No device attached. A new task-owned AVD using the official installed API 37 image passed acceleration preflight, then failed actual boot with a KVM hardware error and exit **139**, before ADB. The owned AVD was deleted. No emulator timeout, software modification or platform/security restriction was changed. Physical/background-engine, API 37 permission and normal secure-storage acceptance remain **open**. |
| Canonical strict Snap packaging/runtime | Official Snapcraft **9.2.1**, unchanged core24/strict/devel recipe and the final normal Linux bundle were staged in a task-owned directory. `snapcraft pack --use-lxd` fails copying the build instance because the shared storage pool is **UNAVAILABLE**. Shared storage/profiles and existing installed BusyMax were not altered. **No new final Snap artifact or runtime pass** exists; the runtime verifier cannot qualify a missing candidate. Historical container/VM receipts below are not reused. |
| Windows native/build/MSIX | No running authorized Windows VM/toolchain was available in the inspected environment. **Not executed for this revision**. Linux-hosted Windows-widget tests are not Windows native acceptance. |
| Exact-final-source CI | **Not run**: the new commits and DAV dependency pin are local only and were not pushed. GitHub returned no workflow runs for the final source hash. Starting revision `34d771b` has successful [Linux](https://github.com/busystack/busymax/actions/runs/42472442027), [Android](https://github.com/busystack/busymax/actions/runs/42472442015) and [Windows](https://github.com/busystack/busymax/actions/runs/42472441995) runs; these do not qualify the new code. PR #38 remains draft at its original head. |

There are **90 distinct passing live cases across the maintained executions**
(59 shared, 6 BusyStack-specific, 18 reconciliation, 5 edges, 2 scheduling),
with the separate VTODO-delivery skip. This total does not count repeated cases
again or relabel a composed result as a single clean suite invocation.

Current package identity remains `io.busystack.busymax`, version `0.4.0`,
Android code `8`, compile/target API `37`. Final-source artifact SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| Linux runner | `00652942bf6fce3b4580788eb99e3a3c614196cc0b201625993b02a232c2eac9` |
| Linux `libapp.so` | `957a204f23b38cb462d8bd9874f132ab5b9d8f0f70f816a4386442db1d92df86` |
| Test-signed APK | `a3062764fc13b96dd086dd2533b45b2ab38174c96d24205229a2c6aed368e69d` |
| Test-signed AAB | `f6d2a7355675cf70577c8654ded22f2303d5750133a97805eacada81640350c9` |

APK/AAB filename inspection found no fixture `.pem`/`.key`, test or interop
assets. The managed-production Android configuration and signing prerequisite
checks fail because the corresponding public registration configuration and
`android/key.properties` are absent. The existing local desktop configuration
also fails the required managed Google and product privacy-policy validator.
No production credentials, signing keys or registrations were invented.

| Remaining issue | Classification / impact |
| --- | --- |
| Unpublished local first-party dependency and no final-revision CI | Release blocker: remote reproducibility and all required CI gates remain open until separately authorized publication/CI. |
| Android physical/worker/API 37 acceptance | Release blocker: widget/channel and native-unit evidence do not replace actual device processes, permission flows and platform storage. |
| Current strict Snap and Windows distribution/runtime acceptance | Release blocker: current Snap packaging infrastructure failed; Windows environment was absent. No installed candidate or runtime result is fabricated. |
| Production registrations, signing and normal-package secure storage/private-Nextcloud workflows | External release prerequisites / inherited acceptance gap. Current fixture runs do not prove these normal-package workflows. |
| Independently demonstrated VTODO scheduling delivery | Inherited interoperability gap on the available server; storage/consent passes are not delivery evidence. Do not expand or silently narrow the approved scheduling contract. |

No confirmed implementation defect from the reported destructive transfer,
multiget-budget, persisted-notice, dispatch-identity, XML-decoding or retained-CA
cases is left without a correction and regression. Native/platform gaps above
remain sufficient grounds for **NO-GO**.

Earlier sections below are historical receipts. Their artifacts, hashes,
platform results and CI identities do not qualify this new local implementation.
The new first-party commits are local only, so fresh remote CI cannot resolve the
new dependency pin until separately authorized publication. No push was attempted.

Before release, obtain exact-final-revision CI on all three platforms, qualify
normal installed distribution workflows on Android/Windows and the current strict
Snap, complete the remaining platform/security-store and private-Nextcloud
acceptance, and close the already recorded VTODO delivery qualification gap on
a suitable server where delivery is part of the approved support contract.
Validation and provider contracts remain unchanged. No uncorrected destructive source-delete path was
reproduced after the transfer fix; that conclusion is bounded by the documented
regressions and live workflows.

## Historical 2026-11-07 remaining-corrections qualification

This run began with a clean `release/v0.4.0` at
`2c0d1e82007ec9586f167868117c4e647e756ada`, matching the reviewed PR head.
At that execution these changes were uncommitted; they were subsequently
recorded in `34d771b91e460469b7d513f1ff241dc9c822cc52`. The restrictions,
source digests and receipts in this dated section describe that historical run.
The present 2026-11-08 audit separately authorizes local commits. No push,
merge, tag, publication or PR-state change was performed. Existing
A1–A7 work, creation policy and HTTP 405/Allow handling are retained. Version
0.4.0, Android versionCode 8, schema 25 and all dependency pins are unchanged.
The earlier evidence and failures below remain historical evidence.

### Corrected source and fixture defects

- **Ambiguous multiget:** `dav_collection_remote_client.dart` previously promoted
  all-property-404 responses to resource deletion. [RFC 4918 section 13](https://www.rfc-editor.org/rfc/rfc4918.html#section-13)
  does not give property status that meaning. Property-only 404, missing calendar data or
  ETag and omitted responses now use the existing bounded safe GET. Only an
  authoritative resource 404 establishes deletion; GET denial, failure or
  malformed data fails synchronization. All duplicate hrefs, even identical
  copies, reject the batch before reconciliation; later responses cannot
  overwrite earlier evidence. `dav_sync_engine.dart` additionally validates
  fetched identities and checks cancellation before promotion. Inspection of
  `dav_object_repository.dart` confirmed that its existing transaction already
  promotes objects, projections and the stable cursor atomically; no storage or
  schema redesign was needed. This preserves [calendar-multiget resource/property
  status semantics](https://www.rfc-editor.org/rfc/rfc4791.html#section-7.9) and
  [WebDAV synchronization baselines](https://www.rfc-editor.org/rfc/rfc6578.html).
- **Well-known 303:** generic `dav_discovery_service.dart` resolves the endpoint
  with HEAD through the actual pinned DAV transport before principal PROPFIND.
  The transport's operational 303 rejection is unchanged. Same-origin HTTPS,
  redirect bounds/loops, cancellation and the selected installation boundary
  remain enforced; credentials are not transferred to another authority.
  Explicit endpoints, HTML fallback and supported 301/307 paths remain covered.
  This follows [RFC 6764 bootstrapping](https://www.rfc-editor.org/rfc/rfc6764.html#section-5)
  and [HTTP 303 retrieval semantics](https://www.rfc-editor.org/rfc/rfc9110.html#section-15.4.4).
- **Windows SQLite fixtures:** the five PROPFIND persistence tests registered
  directory deletion with `addTearDown`, which precedes regular `tearDown` and
  therefore the reopened connection's close. The regular teardown now owns
  closure of the current connection followed by awaited directory removal and
  absence assertion. The established persistence-directory helper is used.
  [Flutter documents this callback order](https://api.flutter.dev/flutter/flutter_test/addTearDown.html).
  Linux execution verifies the assertions; actual Windows execution of these
  five Flutter tests remains an open gate.
- **Windows connection reuse:** an actual Windows x64 comparison using official
  Dart 3.13.4, the unchanged BusyMax implementation and pinned package:http 1.6.0
  reproduced the original two-request/100 ms response/50 ms connection-deadline
  flow. With the default unlimited connection policy, the single-socket
  assertion failed **24/30** times for BusyMax and **27/30** for plain IOClient.
  With `maxConnectionsPerHost = 1`, each passed **30/30**. A second comparison
  with socket-creation tracing observed **15/30**, **26/30**, **0/30**, **0/30**
  respectively. Response body, length and persistence checks passed throughout.
  This reproduces an assumption in the fixture, without demonstrating premature
  BusyMax termination. Runtime idle-pool return timing is the supported
  explanation; internal runtime event ordering was not instrumented.
  The fixture now explicitly bounds its sequential native client to one live
  connection while retaining the single-socket assertion and completion signal.
  No sleep, timeout increase or production transport change was introduced.
  Dart documents [opportunistic connection reuse](https://api.dart.dev/dart-io/HttpClient-class.html)
  and the [unlimited default connection bound](https://api.dart.dev/dart-io/HttpClient/maxConnectionsPerHost.html).
  The standalone comparison is Windows runtime evidence, **not** a Windows
  Flutter-suite or installed-package pass.

Regression locations are
`test/dav/sync/dav_collection_remote_client_test.dart`,
`test/dav/sync/dav_sync_engine_test.dart`,
`test/dav/discovery/caldav_discovery_test.dart`, and
`test/core/http/native_terminating_http_client_test.dart`.
File-backed multiget cases seed events, tasks and a pending mutation, reopen the
SQLite database after reconciliation/failure, and assert raw resources, ETags,
server-deletion state, projections, pending rows, baseline generation and cursor.
They cover resource 404, property 404 with GET 200/404/403/network failure,
missing mandatory properties, omissions, identical/contradictory duplicates,
cancellation and malformed/incomplete GET. Discovery tests execute production
service and pinned transport for principal/home discovery, non-root and multiple
redirects, loops/limits, cross-origin/downgrade, invalid Location, cancellation
and explicit endpoints. These deterministic protocol responses do not establish
that any qualified server naturally exhibits the defects.

### Execution and release gates

The source-file manifest (1,070 files under `lib`, `test`, `tool`, `android`,
`linux`, `windows`, including the new live regression) has SHA-256
`658f44ec6e602232dd256a9721fe6ee2c7919b7664a025441ccad439d7aa7511`.
This identifies uncommitted source atop the HEAD above, not a new Git revision.
Documentation and private execution receipts are outside this source digest.

Pinned shared revisions remain:

| Dependency | Revision |
| --- | --- |
| busystack_contacts | `af6490c55f1c4c638ea51066603eb97bf0d8e2c8` |
| busystack_dav | `33afd70a761822847a37c7ad47f5e61dfeaa74a7` |
| busystack_graph | `0ccf8a654a159aa453ebf322e95503972fec5e64` |

| Check and maintained command | Current-run result |
| --- | --- |
| `flutter test test/dav/sync test/dav/discovery test/dav/trust test/core/http test/db --reporter expanded` | Final affected run: **332 passed, 2 opt-in benchmark skips**, exit 0. Includes all five persistence fixtures and the corrected native reuse fixture on Linux. |
| `flutter test --concurrency=4 --reporter expanded` | Initial correction run: **5,201 passed, 103 skips**, exit 0. Final rerun after the reuse fixture correction: **5,201 passed, 118 skips**, exit 0. The 15 extra live-only skips passed separately in the injected live suite. |
| `BUSYMAX_CALDAV_LIVE=1 BUSYMAX_CALDAV_LIFECYCLE=1 flutter test test/dav/caldav_live_integration_test.dart --reporter expanded` | **59 passed**, exit 0, all three pinned servers with application collection provisioning and independent readback. The first run overlapped the beginning of Android packaging. The final sequential rerun also passed **59/59, exit 0**, with no concurrent native build or full suite. |
| Same live opt-ins, `test/dav/busystack_live_integration_test.dart` | **6 passed**, exit 0, including strict Depth/507 pages, restart, permission changes and durable recovery. |
| `BUSYMAX_CALDAV_LIVE=1 flutter test test/dav/caldav_release_edges_live_test.dart --reporter expanded` | **5 passed**, exit 0. |
| Same opt-in, `test/dav/caldav_scheduling_live_test.dart` | **2 passed, 1 skipped**, exit 0. Client VTODO consent/storage and VEVENT REQUEST delivery passed; no initial VTODO inbox REQUEST was demonstrated. |
| Same opt-in, `test/dav/caldav_reconciliation_live_test.dart` | **15 passed**, exit 0. Identified gateway injection of property-only 404 and well-known HEAD 303 over all three actual servers; real GET 200/404, injected GET 403/network failure, database reopen and independent readback. This does not attribute injected behavior to the unmodified servers. |
| `flutter analyze`; `dart run tool/check_platform_boundaries.dart`; `dart format --output=none --set-exit-if-changed .` | Final complete analysis and platform boundaries passed; formatting checked **872 files, zero changes**; repository hygiene and `git diff --check` passed. |
| `flutter pub get --enforce-lockfile`; generated snapshot, `flutter gen-l10n`, `dart run build_runner build --delete-conflicting-outputs --force-jit`, snapshot verify | Locked resolution passed; localization and Drift outputs are reproducible and unchanged. Database migrations/recovery are included in the affected and full suites. |
| SDK verifier; `python3 tool/verify_upstream_packages.py`; `python3 -m unittest discover -s tool -p test_upstream_packages.py` | Official Flutter 3.47.5 / bundled Dart 3.13.4; **1,171 SDK files**, **8 reviewed upstream packages** verified; **29 checker tests** passed. Shared heads match the unchanged manifest; unrelated sibling IDE metadata was left untouched rather than resetting those working trees. |
| `python3 tool/check_repository_hygiene.py`; workflow-pinned gitleaks container `git --log-opts=--all --redact --config .gitleaks.toml` | Hygiene passed; **284 reachable commits scanned, no leaks**. A supplementary current public-source directory scan also passed from the repository root. Its first absolute-path invocation produced 64 checksum/curve false positives because it missed the existing repository-relative path allowlists (62 dependency hashes, 2 named-curve checks); rules were unchanged. Private receipts and credentials remain outside public Git. |
| `python3 -m unittest discover -s test/tool -p '*_test.py'` | **81 passed**, exit 0. |
| `bash tool/release/check_linux_native.sh`; registration-reader CMake/build/CTest commands from Linux CI | Native checks and **1 CTest** passed. Initial native run stopped because `xvfb-run` was absent; a rerun used official unmodified Ubuntu xvfb/xauth packages extracted into private QA storage, without changing system packages. |
| Isolated XDG profile, `BUSYMAX_CALDAV_NATIVE=1 ... xvfb-run -a flutter test integration_test/caldav_workflows_test.dart -d linux --reporter expanded` | **3 passed**, exit 0, real native settings/editors and independent readback on all three servers. Fixture database/secrets do not qualify normal-package secure storage. |
| Same isolated native session, `integration_test/nextcloud_private_tls_linux_test.dart` | **51 passed**, exit 0. Dedicated Nextcloud private trust, authorization, cancellation and ordinary HTTPS coverage retained. |
| `xvfb-run -a flutter test integration_test/gtk_header_icons_integration_test.dart -d linux --reporter expanded` | **1 passed**, exit 0. |
| `android/gradlew --project-dir android :busymax_android_platform:testDebugUnitTest :app:lintDebug` | **BUILD SUCCESSFUL**, exit 0. API 37/Build Tools 37 prerequisites passed. |
| `tool/android/build_release.sh --all --test-signing --allow-unconfigured-providers`; `BUNDLETOOL_JAR=... tool/android/inspect_artifacts.sh` | Fresh APK/AAB built and inspected, including native 16 KiB LOAD alignment, AAB `PAGE_ALIGNMENT_16K`, retained notification drawable, permissions and signing certificate. First inspection reported missing bundletool input; the complete rerun with the existing official jar passed. Explicitly **test-signed and unconfigured**, not production distribution artifacts. |

Android package identity is `io.busystack.busymax`, version `0.4.0`, code `8`,
compile/target API `37`. Current APK SHA-256:
`c6a235967d9263965b373594cc3134b3ee735ffc605907c0bcffa01e635cfb93`.
Current AAB SHA-256:
`7c7957e71cf6217fc1de6fed2d3beafada844adb10b3ab26e7126b6c4a7798d6`.

No Android device remains attached. A fresh task-owned AVD used the installed
official API-37 Google APIs x64 image. Although `emulator -accel-check` reported
KVM usable, actual boot failed with `KVM: entry failed, hardware error 0x80000021`
and exit 139 before ADB was available. No software-rendering timeout extension,
platform restriction change or existing-VM shutdown was attempted. The owned AVD
was removed. Existing API-29 results are retained, but API-37 local-network
permission/interface acceptance and normal-package secure-storage/account
workflows remain open. The installed host Snap is 0.3.2 and was not used as
current-candidate acceptance; the fresh 0.4.0 package checks are recorded below.
Windows has no prepared Flutter toolchain; official pinned Flutter archive and
release-manifest retrieval returned HTTP 404 from this environment. The official
Dart 3.13.4 diagnostic runtime was downloaded with matching upstream SHA-256 and
removed from the QA guest after comparison. Windows Flutter fixtures/full suite,
release builds, native C++ tests, MSIX and installed runtime acceptance remain
open; standalone Dart evidence cannot close them.

Production Android prerequisite checks independently report missing public
provider configuration and missing `android/key.properties`. Existing desktop
local public settings alone fail the production validator: required managed
Google Desktop client ID/secret/project and product privacy-policy configuration
are not supplied in that file. No production registrations, signing credentials
or Windows Store identity were invented or certified. Actual VTODO scheduling
delivery still needs a suitable unmodified scheduling-capable server.

All skipped live/provider/benchmark tests remain unqualified. Baseline CI does
not qualify the uncommitted candidate. The normal
Linux release build (`flutter build linux --release -t lib/main_linux.dart`)
passed with an unconfigured normal entry point. Its staged `libapp.so` matches
the new release bundle (SHA-256
`78ab9216265e4ee72860093459ae0d9d1e8b0a7d024cfeab3d6fe3ca1eaa31ba`);
no fixture certificates or integration-test assets were found in its asset
payload. Runner executable SHA-256:
`00652942bf6fce3b4580788eb99e3a3c614196cc0b201625993b02a232c2eac9`.

The unchanged Snapcraft recipe was copied with this fresh bundle into new
private staging. `snapcraft pack --use-lxd` failed before packaging because
the shared LXD storage pool was unavailable. Shared infrastructure was left
untouched. A separate task-owned Ubuntu 24.04 LXD project, pool and bridge then
built the same staged recipe using the official unmodified Snapcraft 9.2.1,
revision 19387, with `snapcraft pack --destructive-mode` inside its disposable
container. An initial output path outside the project was rejected; selecting
an output directory inside that project corrected the invocation. Packaging
passed with all linters enabled. Nonfatal unused-library warnings were retained
for the dynamic registration reader, colord, dconf and gweather libraries.

The resulting `busymax_0.4.0_amd64.snap` is version 0.4.0, core24, **strict**,
grade **devel**, unconfigured and locally installed with `--dangerous`; it is
not a production-configured or Store-signed artifact. SHA-256:
`6925d8526b091486ea491d6e352b1308978ca94458fda3f7033ed4ff23aeb7c0`.
Its extracted `libapp.so` matches the fresh normal release bundle above.

### Normal strict-Snap native acceptance

The exact new package was installed only in the disposable Ubuntu environment.
The normal entry point ran under `snap.busymax.busymax (enforce)` with a fresh
user/profile, X11/Xvfb, session D-Bus, normal GNOME Keyring and portal services.
No injected database, secret backend, fixture assets or custom app TLS provider
was used. A labeled HTTPS gateway forwarded DAV to unmodified Radicale; its QA
root was installed only in the disposable operating system's trust store.
An initially incomplete QA-root key-usage extension was corrected after the
independent strict verifier rejected it; no certificate validation was disabled.

| Actual normal-package workflow | Result and evidence scope |
| --- | --- |
| CalDAV onboarding and synchronization | Passed through normal account UI and platform TLS/secure storage; principal/home inventory and existing tasks loaded. |
| Native collection administration | Created a calendar and task list through the approved creation flow. Both creation journals committed; independent PROPFIND confirmed them. Deleted only these owned collections through native confirmation dialogs; independent readback returned 404, local collections were tombstoned and no pending mutations remained. |
| Native editors | Created and edited an event, and created a task in the owned list. Independent GET verified exact titles, UIDs and authoritative ETags. GUI automation waited for complete rendered input before submission; an earlier premature input submission was corrected through the editor. |
| Secure storage, forced restart and offline recovery | Stopped the QA gateway, created an offline task, observed the durable pending row, then killed only the owned app process. Restarted the same normal Snap without plaintext onboarding inputs. Account and projection survived; pending ID, reserved member URI, UID and mutation payload matched before/after reopening; stable cursors and baseline generations did not advance offline. After gateway restoration, synchronization drained the queue and independent GET found exactly one task with the reserved identity. The local draft projection became one canonical projection after acknowledgement. |
| Rejection feedback | A naturally denied PROPPATCH on the existing QA property-locked collection produced visible permission feedback. Local state and independent PROPFIND retained its authoritative title; no pending operation remained. |
| Nextcloud private-certificate review | An explicitly untrusted self-signed TLS fixture displayed the expected authority, validity and independently computed fingerprint in the dedicated Nextcloud review. Reject created no account; retry required review again. The approval action was exercised. This fixture fronts Radicale, so it does **not** qualify live Nextcloud login or a successfully persisted Nextcloud account. Generic CalDAV at the same untrusted authority failed without an exception-review path or a new account. |
| Profile cleanup | Normal account removal completed, leaving zero accounts, pending operations, event projections or tasks. The owned gateway, user profile, container, failed verifier VM, project, pool and bridge were removed after private evidence capture. The host's older Snap and shared LXD infrastructure were untouched. |

These are scripted normal-package GUI checks in an enforced Ubuntu container,
not physical desktop or Wayland acceptance. The maintained fresh-VM command,
`bash tool/release/verify_snap_runtime.sh <exact-snap> <evidence-path>`, was also
attempted in the task-owned project. Its VM stopped before cloud-init with
`KVM: entry failed, hardware error 0x0` and a QEMU assertion; the verifier exited
1 and produced no passing receipt. This fresh-VM/X11/Wayland gate remains open,
as do live Nextcloud sign-in and the other platform gates above. No timeout,
runtime, virtualization tool or platform restriction was modified to obtain a
pass. Private screenshots, readbacks, repository snapshots and execution logs
are retained outside public Git.

The baseline commit's verified workflow identities are
[Linux 42433201277](https://github.com/busystack/busymax/actions/runs/42433201277)
(success),
[Android 42433201276](https://github.com/busystack/busymax/actions/runs/42433201276)
(success), and
[Windows 42433201308](https://github.com/busystack/busymax/actions/runs/42433201308)
(failed at Flutter tests; release builds/native C++/MSIX steps skipped).
All three exact-final-revision CI gates remain open until a separately authorized
commit/push and successful workflows on that same revision.

## 2026-11-07 HTTP 405 method-evidence follow-up

This narrow follow-up starts clean at
`4d2d92195bdb953e695ca68f6c88078c7446cb14` on `release/v0.4.0`.
The issue is source-confirmed and reproduced by deterministic fixtures; it has
not been observed against the three pinned live servers. HTTP 405 with Allow
now supplies target-specific method evidence in both production administration
and discovery, per [RFC 9110 sections 10.2.1 and 15.5.6](https://www.rfc-editor.org/rfc/rfc9110.html#section-15.5.6).
An empty Allow or one omitting both supported calendar-creation methods blocks
creation before dispatch; a positive advertisement selects the advertised
method, including Extended MKCOL only with its existing DAV feature evidence.
A 405 lacking Allow remains unknown under the approved fallback policy and
still requires explicit parent authorization. The existing 404 fallback is
unchanged even if its error response contains Allow.

Regressions cover VEVENT/VTODO, negative/empty/positive Allow, Extended MKCOL,
missing Allow with unknown/denied parent ACL, rejected-journal persistence,
and restart reconciliation without another mutation. The previous implementation
failed 13 of the initial 18 new 405 cases; its failure receipts are retained.
The complete affected discovery/creation/service suites passed **346 tests,
exit 0**; analysis and repository hygiene passed. The four changed Dart files
were formatted. Commands, negative controls and source identities are appended
as `options405-*` under the existing private qualification directory. Prior full-suite, live-server,
native and package evidence below predates this change and is not a new run.
No release metadata, schema, pins, upstream software, commits or pushes are
changed by this follow-up; outstanding release gates remain open.

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
403 remains denied. OPTIONS 404/410/501, HTTP 405 without Allow, or a
successful response without Allow cannot establish creation support/refusal.
HTTP 405 with Allow is target-specific evidence, including an empty field;
see the method-evidence follow-up above. General calendar-access grants
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
