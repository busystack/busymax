# Journal follow-up qualification

The Windows, Android and strict Snap journal qualification remains open.
The Linux and DAV results below cover the named scenarios. The complete
two-provider matrix remains blocked by stock Nextcloud storage admission.
Use the [fixture and runner instructions](../test/interop/caldav/README.md#journal-candidate-qualification)
to repeat the run.

## November 27 continuation

This continuation started from BusyMax `759b971580f23d451f0eef57c67cc62b336a99b8`
and BusyStack `75685be70c48a776322f957a17d937b5352a279b`. Both starting commits
matched the fetched release refs. The client schema stays at 28 and the server
schema stays at 17. The server changes from the previous run remain in the
same candidate. A fresh build reproduced the verified JAR digest shown below.

| Requirement | Expected result and evidence | Scope remaining |
| --- | --- | --- |
| A1 and J16–J18, RFC 5545 §3.8.4.4 and RFC 5546 §3.5.3 | An individual cancellation at the start of a range changes that occurrence only. The next unoccupied original position carries the prior range. `JournalMessage.update` and `IcalRecurrenceExpander` passed the UTC, DATE, floating and embedded-DST tests in `journal_itip_test.dart`. The UTC case also passed pending export, database reopen, conditional replay and independent HTTPS readback on both services in `journal_live_test.dart`. | Provider replay of all date forms, combined multi-component messages and full native occurrence editing. |
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
select **Queue reviewed update**. Normal conditional replay still applies.
A changed remote baseline requires reconciliation before using the bundle to
recover the edit. A collection export includes the unaffected journals and
reports excluded entries separately.

The new independent storage run passed 22 of 22 operations on BusyStack.
Unmodified Nextcloud 35.0.3 passed 12 and reproduced 10 rejections with
unchanged prior state. The five blocked forms and the reduced parser and server
diagnostics appear in the [local upstream drafts](journal_nextcloud_upstream_drafts.md).
The supported Nextcloud workflow profile requires its own complete native and
installed-package results.

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
