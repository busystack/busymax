# Journal follow-up qualification

The first-party and supported Nextcloud acceptance matrices remain open,
including Windows, Android and strict Snap package qualification. The Linux
and DAV results below cover the named scenarios. Strict Nextcloud storage
conformance is upstream-blocked for the recorded representations.
Use the [fixture and runner instructions](../test/interop/caldav/README.md#journal-candidate-qualification)
to repeat the run.

## Diagnostics discard follow-up

Diagnostics can discard a quarantined journal create or update once its
outcome is known. For an unsent create, discard removes its local
projections. For an update, discard restores the server-confirmed
projection. A previously attempted create requires a read confirming the
original href is absent. A previously attempted update requires matching
raw bytes and a strong ETag. A dependent operation with an uncertain
outcome blocks discard of the chain. The quarantine retains its separate
reviewed repair workflow.

The two historical databases reproduced four failures through
`PendingOpResolutionService.discard`, including an attempted update that
used to discard despite a server mismatch. The four regressions now pass.
They check read-only reconciliation, zero mutation requests, dependent
cleanup, projection restoration, and preservation of siblings and unrelated
queued changes. The focused legacy recovery and DAV mutation suites passed
81 tests, including the existing partially completed move checks.

The stock Nextcloud CRUD and Linux deletion scenarios passed twice in
private profiles. A controlled Linux run reproduced the confirmation
timeout with five successful HTTP responses delayed by twelve seconds
each. Nextcloud returned DELETE 204 before the former UI test wait expired
during refresh. The revised bounded test wait passed the same timing case
and independently checked provider deletion and local projection removal.
The original deletion log lacks the wire timing needed to identify its
exact cause. The earlier range promotion replay failure also remains
unexplained. New diagnostics record pending error codes, request methods,
statuses and elapsed times without recording fixture contents or credentials.

Results for this pass are under
`build/qualification/vjournal-discard-followup`. The strict Nextcloud
admission failures and the incomplete native and installed-package
acceptance requirements remain open.

## Pending journal and collection export follow-up

The historical database coverage includes unsent creations as well as
updates. The original request JSON, patch and rendered payload are available
in the JSON recovery bundle. The queue validates persisted journal creates,
updates and move candidates before dispatch. A create that may have reached
the server becomes repairable only after the original href is confirmed
absent. For an attempted update, the current representation must still match
the original bytes and strong ETag. **Check server before repair** performs
that read-only reconciliation. An existing create target or changed update
baseline keeps the operation locked and exportable for review.

The collection-management and source export actions now warn when they omit
journals awaiting recovery. The desktop collection exporter writes each
permitted recovery bundle as a separate JSON file alongside the valid
calendar files. On Android, the message directs the user to the affected
entry in Journals to export its bundle. Without permission to view the full
representation, the warning remains visible and the bundle contents stay
private.

Changing a recurring journal's date form revises each changed component
using one captured instant. The converted master and detached exceptions
each get an eligible DTSTAMP and existing LAST-MODIFIED. An organizer-owned
sequence is advanced for a significant change, with the master organizer
used when an exception inherits it. A derived field stays protected.
Regressions check multiple exceptions with different sequences, file
database reopen, a conditional write and independent HTTPS readback.
[RFC 5545 revision properties](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.8.7)
[RFC 5546 component revisions](https://www.rfc-editor.org/rfc/rfc5546.html#section-2.1.4)

Follow-up evidence is under `build/qualification/vjournal-recovery-followup`.
The portable evidence archive contains the manifest, coverage, sanitized logs,
artifact hashes and Git tree comparisons. Earlier source and binary
identities remain separately identified. The follow-up began at BusyMax
`ac6397d158838ac08d52f324e3e4f35535bc372d`. Its application build inputs
through `ba8753a00db011d62af51f4922d223530607f30a` include all three
corrections and their translated messages.

| Follow-up gate | Observed result and scope |
| --- | --- |
| Historical create recovery | The genuine old-version fixture reached the queue as a pending create with no ETag. Both HTTPS providers saw zero mutations before repair and independently read back one chosen exception after conditional creation with the original operation ID. File database tests cover attempted, interrupted-first-dispatch and queued-dependent states. |
| Production collection export | The Nextcloud controller and desktop writer regression checks that a mixed collection exports valid event and journal siblings, discloses the omission, and produces a separate JSON recovery file when the collection allows it. A restricted view still signals the omission and exposes no recovery payload. |
| Converted component revisions | The BusyMax repository and real HTTPS cases checked one revision instant for the master and both changed detached exceptions. Queue reopen and conditional readback retained the resulting timestamps and organizer sequence values. |
| Linux GTK files | Three production processes passed the recovery export, reviewed repair, and byte-for-byte attachment save. The third process exported ICS with the binary attachment and imported it under a distinct UID. This scenario uses one private offline profile. |
| Linux native journal conflicts | Both providers returned HTTP 412 for each competing write. The journal UI displayed the local and remote versions, and the test verified all three stored versions. Independent readback confirmed keep-server, reapply and duplicate results. This case covers competing title changes. |
| Android API 35 QA | Both native editor smokes passed on the isolated emulator after retrying with SwiftShader and Vulkan disabled. The manifest records each debug QA application ID, signer and installed APK hash separately from the preflight build. Eleven required case markers remain open on each provider. |
| BusyStack and Nextcloud raw admission | BusyStack passed all 22 operations. The official Nextcloud 35.0.3 image passed 12 and rejected 10 across the two dated PERIOD forms and three typed relationship forms. The independent admission runner checked prior bytes, ETag and collection state after the rejected writes. |

The shared DAV lifecycle tests use calendar and task fixtures. The earlier
API 37 LAN smoke exercised system permission and direct HTTPS. The full
native journal matrix and installed release packages still require their
own acceptance results.

In this follow-up, the four configured journal HTTPS cases passed in a serial
run. A later aggregate run failed to apply a range promotion on Nextcloud.
The same named durable CRUD case passed on a freshly initialized stock
fixture. The Linux two-process replay passed on both providers. A separate
Nextcloud Linux rerun hit a collection deletion confirmation timeout. The
manifest retains the earlier passing scenarios and the failed reruns.

## November 27 continuation

This continuation started from BusyMax `759b971580f23d451f0eef57c67cc62b336a99b8`
and BusyStack `75685be70c48a776322f957a17d937b5352a279b`. Both starting commits
matched the fetched release refs. The client schema stays at 28 and the server
schema stays at 17. The server changes from the previous run remain in the
same candidate. A fresh build reproduced the verified JAR digest shown below.

| Requirement | Expected result and evidence | Scope remaining |
| --- | --- | --- |
| A1 and J16–J18, RFC 5545 §3.8.4.4 and RFC 5546 §3.5.3 | An individual cancellation at the start of a range changes that occurrence only. The next unoccupied original position carries the prior range. `JournalMessage.update` and `IcalRecurrenceExpander` passed the UTC, DATE, floating and embedded-DST tests in `journal_itip_test.dart`. All four date modes then passed pending export, database reopen, idempotent reimport, conditional replay and independent HTTPS readback on both services in `journal_live_test.dart`. | The full provider matrix for combined messages and native occurrence editing. |
| A2 and O09, RFC 4791 §5.3 | The historical SQLite fixture from `df88856c2ec98aae37152f5cdc887c99de3bf6b3` stays inspectable, and the invalid candidate never reaches the mutation transport. The file database regression passes pending and failed reopen, exact JSON export, unaffected collection export, access gating and conditional reapply after choosing the range. The workspace regression exercises export and explicit selection. Both focused `journal range and historical queue recovery` HTTPS cases passed conditional replay and independent readback after reviewed repair. | Complete native package recovery with each platform's real file adapter and dependent queue scenarios beyond the file database regression. |
| A3 and J23, RFC 5545 §§3.6.3 and 3.8.7.2 | The oracle counts malformed, floating, grouped and parameterized duplicates before validating the only direct stamp. Both real providers passed the default repair assertion under their own expected policy. BusyStack rejected the unstamped object with HTTP 403 and unchanged state. Nextcloud returned 201, then GET 200 with one valid UTC stamp and unchanged remaining content. | Stock Nextcloud's separate query and storage failures remain visible. |
| B1 and J12, RFC 9253 §§2, 7 and 9.1 | The repository resolves projected journals, events and tasks using collection-local UID or an exact same-account resource URI. It uses the existing schedule detail routes and sends XML URI references to the external handler with their fragment intact. `journal_repository_test.dart` passes mixed target lookup, account boundaries, and visible unresolved values after event hiding or task deselection. | Native route exercise, ambiguous recurring event projections and complete cross-server transfer qualification. |
| B2 and J13–J21, RFC 5545 §§3.3.5, 3.3.10 and 3.8.5 | Switching a supported series time mode preserves civil dates and clock times. An all-day to timed edit uses the chosen clock time on every original date. `convertJournalSeriesDate` updates detached identities, moved starts, RDATE, EXDATE and UNTIL together. The repository regression verifies independent DATE, UTC, floating and embedded +05:30 expectations. | A timed-to-DATE conversion, a civil reanchor that would change recurrence positions, and PERIOD or incompatible forms are rejected before queueing. Complete native and real-provider conversion qualification remains open. |
| B4 and J26, RFC 5546 §3.5 | The versioned import review retains the original bytes, destination, per-entry outcomes and queued operation IDs. `journal_workspace_test.dart` passes route remount, review export and SQLite reopen. A failed review write rolls back the queue additions in the same transaction. | Real platform file pickers and transfer, process interruption during provider replay and the full message corpus. |
| B6 and O11/O15, Android DAV access | An unused DAV request lease checks the grant immediately before dispatch, even when its TLS lane is reused. The revoked-grant regression delivers no PUT to the fixture, a second account continues and the same client can resume after regrant. Android routes manual journal refresh through existing account permission prompts. The contacts and journal workspace suites still pass. | Full Android permission lifecycle with actual journal sync, per-account recovery and installed-package upgrade. |

An invalid historical update appears in its ordinary journal list. Open the
entry to review the competing occurrences and optionally save the recovery
bundle. The bundle contains the baseline, saved patch, and invalid candidate
as JSON. Choose the occurrence to keep at each duplicate position, then
select **Queue reviewed journal**. Normal conditional replay still applies.
A changed remote baseline requires reconciliation before using the bundle to
recover the edit. A collection export includes the unaffected journals and
reports excluded entries separately.

The new independent storage run passed 22 of 22 operations on BusyStack.
Unmodified Nextcloud 35.0.3 passed 12 and reproduced 10 rejections with
unchanged prior state. The five blocked forms and the reduced parser and server
diagnostics appear in the [local upstream drafts](journal_nextcloud_upstream_drafts.md).
The supported Nextcloud workflow profile requires its own complete native and
installed-package results.

### Current runtime and artifact evidence

The application build and deterministic verification used BusyMax source
`2f4239bcc72e20782eaf1b5a6fa1f62fb011b2ac`. The original two-provider native
matrix ran at `278bdbf68b8cea0aa63e4cf610e855f433bb496b`. Its per-case manifest
is `build/qualification/vjournal-cae1a1899601/manifest.json`. The consolidated
record is in `build/qualification/vjournal-completion-20261127`.

| Runtime or gate | Observed result |
| --- | --- |
| Linux production window | The release bundle built from `2f4239b` opened a mapped X11 window in an isolated profile. The executable SHA-256 is `4386e9dbaa87edeb6be0bb9e5d1c54ec0a59b7d63038b3d0c706cb54faf6ad07` and the AOT library SHA-256 is `b1a2cf10e6421f4843a2f44ac3ec41c024b7387390017d6471a5bd6ba06020fe`. |
| Linux journal workflows | Both providers passed queued create, edit and delete through a process restart, SQLite and the isolated native keyring. The same run's separate Nextcloud editor test hit an HTTPS connection close during refresh. The subsequent final-source Linux editor smoke passed for both providers. |
| Linux BusyStack account enrollment | The separate native test at `c394fc596402dd8a62ea553728e17544f29a204c` started the production entry point with an empty database, imported the private CA through the GTK chooser, enrolled through Settings, discovered and selected the independently created journal, and reconnected with the same account identity and a new credential generation. It emitted `account-connect-and-discover` for BusyStack. Nextcloud's browser enrollment remains open. |
| Android API 35 | The two named editor smoke tests passed using their separate installed QA APKs and independent HTTPS checks. The fixed minimum marker set remains incomplete. |
| Android API 37 | Both routed LAN smoke cases passed the system permission dialog and journal creation, GET and cleanup over trusted HTTPS. The first BusyStack test encountered a principal on its configured loopback origin. The successful retry used an explicitly configured LAN origin and the same verified server JAR. |
| Android test-signed release | Both APK and AAB passed inspection, including 16 KB alignment. The APK opened on both API 35 and API 37, and both installed copies matched its SHA-256 `8b7ab03664a42c9b257beff7abc8d523829ab48eb4b3046b753768d42db7877e`. The AAB SHA-256 is `497323e21827306cb4d800469af34d8d3d6e6157d17ebcd5037afe2fede8c09f`. Production provider registration, signing and the distribution build code remain required. |
| Windows and strict Snap | The Windows launcher requires an authorized healthy desktop host. The local VM booted into Automatic Repair. The canonical Snap builder requires the owner’s desktop OAuth configuration. The installed-package gates remain open. |

The final-source journal HTTPS suite passed four named cases, including
recovery after downstream denial and historical queue repair. The event,
task and sharing reruns used official Calendar 6.7.0 and Tasks 0.18.1 on
a new unmodified Nextcloud 35.0.3 instance. Both the exact-version DAV
semantics case and the 128-member collection case passed, along with the
separate user and group ACL case. Earlier attempts had an unknown HTTP
mutation outcome and a large-collection rediscovery timeout.

Both stages of the Nextcloud service-restart regression in
`test/dav/nextcloud_live_integration_test.dart` passed with a real container
restart and the same stock installation. A separate HTTPS peer verified that
a dated journal kept its bytes, ETag, inventory and sync token, that its
deleted sibling stayed absent, and that a conditional journal update
succeeded afterward. This covers a service restart. Restored-cache
qualification after a backup restore still needs its own client scenario.

The final deterministic rerun passed 5,533 tests with 125 skips and no
failures at `4fbf75aef35b19c78df3630c871cd89d44d5ffe1`, which carries the
tested application code plus the extended live date-mode suite. It used
`flutter test --no-pub --concurrency 4 --timeout 90s --reporter expanded`.
Earlier runs surfaced TLS, activation and tray timeouts. Each affected case
also passed in isolation, as did both journal migrations. Android platform
unit tests and lint, SDK and package integrity, formatting, analysis,
platform boundaries and the five CalDAV Python harness tests passed.
Credential-gated or native skips are tracked separately.

The server candidate in this continuation uses JAR SHA-256
`8fc37a17246761a3c654866b41bca30bd5ae595bd4db2769e3dc1b7fdd061bfe` and
image ID
`sha256:38152c13f99345ed98eab4a99b5e56b88dfaf99094c2a86d6783e190064726b8`.
The final serial `./mvnw -B -ntp clean verify` passed 649 unit and 272
integration tests and reproduced the deployed JAR's exact SHA-256. The
earlier run reported five errors across 227 integration cases. The final
run passed all of those classes. Protocol and OAuth companion tests passed
all ten. The distribution and operations gates, including V9-to-V17 archive
restore, passed on the candidate image. All six browser profiles passed,
including strict DAV Depth, reverse proxy, OpenID Connect and both restore
variants. The OpenID Connect restore retry ran after other fixtures had shut
down, following an earlier Chromium network-change error.

The final candidate-aware BusyStack lifecycle suite passed all six named
cases, including direct and group permissions, strict paged sync, canonical
ETag retrieval after timezone normalization, and credential revocation,
expiry and disabling. An earlier timezone case hit a fixture readiness
failure. Both the focused rerun and the full serial rerun passed on fresh
instances of the verified image.

## Property and behavior checklist

| Properties and applicable clause | Authoring and preservation | Evidence available |
| --- | --- | --- |
| `UID`, `DTSTAMP`, `CREATED`, `LAST-MODIFIED`, `SEQUENCE`, RFC 5545 §§3.6.3, 3.8.4.7 and 3.8.7 | The repository manages identity and revision data. The validator requires exactly one UID and one UTC DTSTAMP for authored journals. | J01 and J23 provider checks, retained revision through local reopen and HTTPS readback, and the separate repair oracle. The organizer and scope combinations still need full qualification. |
| `SUMMARY`, repeatable `DESCRIPTION`, RFC 5545 §§3.8.1.5 and 3.8.1.12 | The standard editor provides independent description blocks and retains language, ALTREP, parameters and empty properties. | J07 and R01 focused regressions plus narrower native edit smoke. |
| `STATUS`, `CLASS`, `URL`, `ORGANIZER`, repeatable `ATTENDEE`, `CATEGORIES`, `COMMENT`, `CONTACT`, `REQUEST-STATUS`, RFC 5545 §§3.6.3 and 3.8 | Status has a dedicated control. The Details editor supports the other authorable values. The raw component retains recorded revisions and parameters. | Individual property and editor cases passed. The full cross-runtime property and negative corpus remains open. |
| `DTSTART`, `RECURRENCE-ID`, `RRULE`, `RDATE`, `EXDATE`, RFC 5545 §§3.3, 3.8.4.4 and 3.8.5 | Date modes, recurrence and original positions remain in one raw UID set. Date conversion is atomic, and ambiguous conversions leave the original set intact. | Independent date and recurrence unit tests, provider round trips for selected cases and journal REPORT boundary probes. |
| Repeatable `ATTACH`, RFC 5545 §3.8.1.1 | The editor supports URI and binary attachments. It retains format parameters and rejects file URIs for DAV storage. | Byte and metadata tests in the journal repository and workspace. Complete real file-provider and installed-package scenarios remain open. |
| `COLOR`, repeatable `IMAGE` and wrapper metadata, RFC 7986 | Journal Details supports applicable component fields. Collection and wrapper fields stay in their original scope. | Admission J10 and preserved extension readback. All placement negatives and authoring combinations remain open. |
| `STYLED-DESCRIPTION`, `STRUCTURED-DATA`, `PARTICIPANT`, `VLOCATION`, `VRESOURCE`, RFC 9073 §§4–7 | The editor retains nested structures and property parameters. Derived values are protected during replay. | J11 admission and nested editor, coalescence and stable-signature regressions. |
| `RELATED-TO`, `LINK`, `CONCEPT`, `REFID`, RFC 9253 §§2, 7–9 | Details retains typed relationship values. Navigation uses same-collection UID or same-account URI lookup, and unresolved values remain visible. | Repository routing tests and J12 wire probes. Scoped transfer, native navigation and complete relationship validation remain open. |
| `VSTATUS`, RFC 10051 §§8 and 12.1 | The nested editor and typed mutation patches retain applicable status fields and parent status. | Direct and participant editor regressions, durable queue reopen and provider readback. |
| `METHOD`, event and task properties and unknown extensions, RFC 5546 §3.5 and RFC 4791 §§4.1 and 5.3.3 | Journal file messages use the import review. The stored journal omits METHOD and excludes event duration, alarms, task completion and event-only fields. Unrecognized raw data can be retained and exported. | RFC 5546 focused tests, independent METHOD-free readback and journal validation negatives. Full platform import and transfer qualification remains open. |

## Range, draft and admission corrections

This follow-up started from BusyMax `df88856c2ec98aae37152f5cdc887c99de3bf6b3`
on `release/v0.5.0` and BusyStack `b1fe00a4edf80630767eee07476585d3cf024c92`
on `release/v0.2.0`. The BusyStack candidate is
`75685be70c48a776322f957a17d937b5352a279b`, with schema 17 and JAR SHA-256
`8fc37a17246761a3c654866b41bca30bd5ae595bd4db2769e3dc1b7fdd061bfe`.
The local image ID is `sha256:38152c13f99345ed98eab4a99b5e56b88dfaf99094c2a86d6783e190064726b8`.
`clean verify` passed 649 unit and 272 integration tests. The protocol and
OAuth companion suites passed six and four tests. The distribution gate and
all four browser profiles passed on that image. The first operations run hit
Docker’s exhausted default subnet pool when creating a nested restore test
network. The sequential retry passed both the current-version and V9-to-V17
restore profiles.
BusyMax remains at schema 28. Recurrence-position comparison ignores RANGE,
while the durable event/task and journal editing keys retain their previous
representation. The draft document carries its own format version.

| Requirement and standard | Independent expected result | Path, command and executed scope |
| --- | --- | --- |
| F01, RFC 5545 §3.8.4.4 | A moved ordinary exception promoted by edit or cancellation occurs once at its original recurrence position. Its effective start stays moved. | `JournalRepository.editOccurrence`, `cancelOccurrenceRange` and `JournalMessage.update`. `flutter test test/journal/journal_itip_test.dart` passed. `journal_live_test.dart` exercised the stored and queued DATE, UTC and TZID combinations with file reopen and HTTPS readback on stock Nextcloud. |
| F02 | An unfinished name, multiline value, quoting flag and edits in later fields or children survive draft decoding. A validated save still rejects an incomplete name. | `JournalPropertyDraft` and `JournalChildDraft`. `flutter test test/journal/journal_repository_test.dart` passed the nested JSON and persisted-patch regression. The native runner reports incomplete-parameter readback separately. |
| F03 | A failed local write leaves the same editor contents on Close, system back and route exit. Retrying allows Close and reopen with the exact text. | `JournalWorkspace`, `BusyMaxWindowCloseCoordinator` and platform routes. `flutter test test/journal/journal_workspace_test.dart` passed an injected SQLite failure and retry. Delayed-write, Windows and Android native variants remain open. |
| F04 | Stale advanced and ordinary edits remain visible and export alongside the saved ICS. Unsupported or incomplete editor input remains raw JSON. | `JournalWorkspace` draft recovery. `journal_workspace_test.dart` passed stale LINK, RRULE, VSTATUS, description and attachment export assertions through an injected file adapter. Native adapter and permission-transition qualification remain open. |
| F05, RFC 9073 §5.3 and RFC 10051 §8 | Reordering or removing unrelated UID-less children preserves each derived child. A change to protected data is rejected. | `DavMutationPatch.applyTo`. `journal_repository_test.dart` passed durable JSON replay for direct VSTATUS and VSTATUS under PARTICIPANT. |
| F06, RFC 5545 §3.8.4.4 and RFC 4791 §4.1 | An incompatible detached identity yields HTTP 403 with `valid-calendar-data` and leaves the old representation, ETag, membership, history and sync token unchanged. Valid adjacent objects remain queryable. | `CalendarContent` and `CalendarConstraints`. `DavHttpIT#mismatchedRecurrenceIdentityFailsBeforeWritingOrIndexing` passed for VJOURNAL, VEVENT and VTODO in server `clean verify`. BusyMax whole-resource validation also rejects incompatible authored data. |
| F07, RFC 5546 §3.5 | A mixed PUBLISH review keeps the organizer failure and the queued sibling separately. Closing, reopening and retrying preserves the review without requeuing the successful sibling. | `JournalImportReview`, `DavNativeImportService` and `JournalWorkspace`. `journal_workspace_test.dart` passed the partial PUBLISH review and retry. Provider rejection remains a queue outcome, and a full native import matrix remains open. |
| F08, RFC 5545 §3.6.3 and provider validation behavior | BusyStack rejects the unstamped create with HTTP 403, `valid-calendar-data` and unchanged inventory. Nextcloud accepts it and GET returns a valid single UTC DTSTAMP on the journal with the remaining semantics preserved. | `test/interop/caldav/journal-provider-reports.py` passed the named default-repair and strict replacement assertions on both fixtures. BusyStack passed all 15 report probes. `python3 -m unittest discover -s test/interop/caldav -p test_journal_provider_reports.py` checks missing, misplaced, invalid and repeated repaired stamps. Other stock Nextcloud REPORT results retain their separate outcomes. |
| O11, RFC 3744 privileges and RFC 4791 §5.3.4 | Changed privileges force a fetch even if the href and ETag stay the same. Cache the redacted bytes for a reader and refetch the full object for an upgraded reader. Identical grants allow reusing the existing representation. | `DavDiscoveryRepository` and `DavSyncEngine`. `flutter test test/dav/sync/dav_account_sync_engine_test.dart --plain-name 'journal discovery refetches the authoritative view'` passed against a controlled DAV transport. The independent stock Nextcloud role probe passed separately. |
| O03, RFC 4918 §§9.2 and 9.6 | Journal rename is offered when discovery allows collection mutation and confirms write-properties. A read-only source continues to hide the action. | The Linux DAV test first reached the deletion tombstone and then exposed a missing stored capability. `DavDiscoveryRepository` now saves the provider policy and `collectionCapabilitiesFromStored` restores it. The sync engine regression verifies that the persisted reader and writer views expose different capabilities. |
| O03 and O17, stock Nextcloud collection deletion | A deleted collection returns either an absent resource or authoritative `nc:deleted-at` metadata. The active journal workspace drops it and stored identity remains available for recovery. | The independent stock 35.0.3 probe returned DELETE 204 followed by PROPFIND 207 for the same href. The live home still showed ordinary collection/calendar resource types and an ISO 8601 `deleted-at` value. `DavDiscoveryService` now consumes that marker and `NextcloudCollectionService` recognizes it for uncertain deletion. The discovery regression verifies the stored identity and inactive projection. This covers collection deletion, and item restoration requires separate qualification. |
| Native narrow layout | A journal collection form fits a narrow viewport with the keyboard and larger text. Title and Save remain reachable by scrolling, and scrolling keeps the title intact. | The API 29 Nextcloud run reproduced a vertical overflow at 320 pixels wide. `JournalWorkspace` now scrolls the controls and lazy entry list together. `journal_workspace_test.dart` passed the 320-pixel viewport regression with keyboard insets and 1.5× text scaling. |

The [matrix runner](../test/interop/caldav/README.md#journal-candidate-qualification)
records the candidate’s running JAR hash, provider versions, raw outcomes,
native markers and skipped or missing gates in `build/qualification`.

## Sources and artifacts

This section and the reviewed R01–R10 coverage below describe the preceding qualification run.

| Input | Identity |
| --- | --- |
| BusyMax starting source | `e283ff2231a2aaf6c104be29ef11c871e92799b1`, release/v0.5.0 |
| BusyStack starting source | `2753e7d152e94faf1d446287fe7a4a13fa76a1a5`, release/v0.2.0 |
| Verified BusyStack candidate | `b1fe00a4edf80630767eee07476585d3cf024c92`, Flyway schema 17 |
| BusyStack JAR SHA-256 | `cf9791e9278b218ad6e6891407aee7b415ee2143583f0f259986cefd62b1ee4f` |
| BusyStack local image ID | `sha256:a48954d6ac243df20059f4e0b177c5f9a09fea02720e7084ec682b8c8a1a9775` |
| BusyMax Flutter and database | Flutter 3.50.1, Dart 3.14.0, Drift schema 28 |
| Stock Nextcloud fixture | Server 35.0.3, internal 35.0.3.2, PHP 8.5.13, SQLite, SabreDAV 4.7.0, VObject 4.5.6 |
| Official Nextcloud image digest | `sha256:f44180601f18e7664557232b4c5edb0eb4a82d649c05b93313f4e15909553d42` |
| Nextcloud local image ID | `sha256:7d7c1ecc23d6d3848a44b1502cd7011082d1299466ad169de758aadf74fbb555` |
| Admission corpus | `qualification/fixtures/vjournal/admission-v1.json` in caldav-server, SHA-256 `68fe8ab310463333ddc6371c3b8b58744223b3f78f3a41152b47d15e498847a0` |

The BusyStack candidate used the verified JAR from `./mvnw -B -ntp clean
verify` with Temurin 25.0.5+8, Maven 3.9.12, iCal4j 4.4.0 and PostgreSQL
18.6. Its 649 unit and 271 integration tests passed. Protocol and OAuth
companion suites passed 6 and 4 tests respectively. The packaged
distribution and operations gates passed. Portal qualification added
creation, rename, import, export, deletion, direct read-only sharing and
group writing. The reverse-proxy restore profile created and updated
journals via DAV, restored them with fresh credentials, recovered sync
membership and verified absence of resurrected members.

The shared BusyMax packages were verified at the revisions pinned in
`tool/shared_dependencies.json`. The clean verification checkout used
exact sibling clones because the original sibling worktrees contained
unrelated local changes. No shared package source changes were needed.

## Reviewed corrections

| Requirement and standard | Implementation and executed evidence | Scope still open |
| --- | --- | --- |
| R01, RFC 5545 §3.8 and RFC 4791 §5.3.3 | Value-only journal patches preserve original parameters and group data. `journal_live_test.dart` checked empty SUMMARY and parameter-bearing SUMMARY and STATUS through a file database reopen, sync and independent GET on both providers. | All three UI runtimes with parameter-bearing edits. |
| R02, RFC 9073 §5.3 | The editor and `DavMutationPatch.applyTo` protect derived properties and nested data. Direct edit rejection and unrelated edit preservation passed in `journal_repository_test.dart`. | Live conflicts with a newly derived remote property, delayed save and per-platform guards. |
| R03, RFC 5545 §§3.8.7.2–3.8.7.4 | `JournalRepository.edit` freezes the queued revision. Both HTTPS tests verified DTSTAMP, existing LAST-MODIFIED and the same effective payload after reopen. Duplicates receive a new UID and revision metadata. | Journal-specific lost-response replay and organizer sequence cases. |
| R04, RFC 5545 §§3.3.10 and 3.8.4.4–5 | Whole-resource author validation rejects the reported DATE to UTC change with existing DATE exclusions, rule bounds and detached identities. The repository test covers a moved instance, an exclusion, future cancellation and range deletion. | Further conversions, custom-zone and COUNT/UNTIL native scenarios. |
| R05, RFC 5545 §3.3.10 and verified erratum 4271 | The shared recurrence engine counts visited periods and bounds work separately from the absolute period index. Old sparse SECONDLY, MINUTELY and HOURLY cases passed in `test/dav/ical`. | Full independent recurrence corpus. |
| R06, RFC 10051 §§8 and 12.1 | Typed patches and draft JSON retain direct and participant VSTATUS. Offline edits to two components passed a reopen, effective export, replay and exact BusyStack readback. Both providers passed the separate direct VSTATUS readback probe. | Full native structure editing, coalescence beside other extensions on Nextcloud. |
| R07, RFC 4791 §§4.1, 9.6.5 and 9.6.6 | `DavHttpIT` and the independent REPORT probe preserve detached identity and moved DTSTART. Server integration tests cover UTC, DATE, custom TZID and limit behavior. The raw bytes remain unchanged. | Nextcloud returns no expanded journals. BusyMax uses unexpanded inventory. |
| R08 | Schema 28 persists journal drafts. The editor locks controls for Save and retains drafts across close and reopen. The BusyMax migration and Linux draft-close checks passed. | Native delayed-save, permission changes while the editor is open, and full Windows and Android draft coverage. |
| R09 | Settings and account discovery include journal-only and mixed DAV collections. Journal selection is independent of event/task selections. Linux and live tests exercised journal collection creation. BusyStack browser and stock Nextcloud permission tests verified server-side views. | End-to-end native sharing management, account transitions and visibility refresh on each platform. |
| R10 | The search controller retains and clears the visible filter. The Linux workflow checked exact entry visibility after close, reopen, edit and search clear against both providers. | Windows/Android completion and large pagination. |

## Corpus and workflow scope

| Scope | Executed evidence | Remaining qualification |
| --- | --- | --- |
| J01–J09 | Admission, unit and Linux checks exercised undated, dated and UTC support, repeated descriptions, retained parameters, read-only confidential rows without DTSTAMP and binary/URI attachment handling in the repository. | Full core-property and native file-adapter corpus, display-zone/restart for every date mode, text scaling and large attachments. |
| J10–J12 | Shared admission, nested JSON/queue regression and direct VSTATUS readback. | Nextcloud blocks three explicitly typed relationship fixtures. Complete reference resolution and native editing workflows remain open. |
| J13–J22 | Independent point/day and recurrence REPORT probes on BusyStack, focused recurrence and repository tests, detached REPORT coverage and PERIOD lexical preservation. BusyStack interprets PERIOD starts through the journal point/day table. | Complete independent recurrence oracle, full native dated workflows and the journal cases blocked at Nextcloud admission. |
| J23–J26 | Strict missing-DTSTAMP replacement, ordinary Nextcloud repair readback, invalid journal statuses, conditional ETags, UID/type invariants and method-aware import tests. | Full negative matrix, all identity/transfer scope cases and platform import of each iTIP form. |
| O01–O03 | HTTPS create/edit/delete with independent readback against both providers. Linux UI smoke exercised journal collection creation and entry changes. BusyStack portal scenarios exercised sharing and administration. | Peer BusyMax profiles, full Settings/collection administration and copy/move UI on all platforms. |
| O04–O07 | File database reopen, pending revision and VSTATUS replay, conflict detection for reordered bodies, and Linux native offline process restart against BusyStack. | Full journal-specific lost-response, concurrent writer and privilege-change acceptance. |
| O08–O10 | Mixed Nextcloud cache bootstrap from complete inventory, sync token handling and BusyMax migration from schemas 26 and 27. | Full interrupted paging/token matrix and native source selection cases. |
| O11–O12 | BusyStack HTTP ACL, portal sharing and real DAV backup/restore with no resurrection. The Nextcloud live role probe proves private access filtering, confidential redaction, full readback on upgrade and denied stale writes on downgrade. | BusyMax-client privilege refetch and offline replay on all runtimes, discarded/redacted data transitions and client restore rebaseline. |
| O13–O17 | Storage and iTIP import tests, effective export, Linux search, VJOURNAL WebCal projection and ordinary offline regression suite. | Native file/link, pagination and scaling, background journal invalidation, credential-gated regression suite and Nextcloud journal trash restoration. |

The proof for the five upstream admission failures remains separate from
the BusyMax recovery result. Dated RDATE with start/end or start/duration,
LINK with VALUE=UID or VALUE=XML-REFERENCE and RELATED-TO with VALUE=UID each
returned HTTP 500 on create and conditional replacement. The independent
probe checked the prior bytes, ETag, membership and sync token. The BusyMax
live test verified failed/pending state, preserved export and file database
reopen for all five. The current fixture is unmodified. An official version
that admits and returns the complete corpus is still required.
