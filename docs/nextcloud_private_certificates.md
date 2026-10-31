# Nextcloud private certificate transport and lifecycle

This note maintains the security boundary and verification procedure for
BusyMax's account-scoped private HTTPS support. See
[user setup](nextcloud_setup.md) for enrollment and management.

## TLS enforcement

`NextcloudHttpClientFactory` creates dedicated contexts and clients for a
temporary onboarding session, persisted Nextcloud account, independent contacts
account, or captured removal snapshot. It never changes `baseHttpClientProvider`,
`SecurityContext.defaultContext`, an OS store, or browser trust. HTTPS is checked
at the application boundary; Android cleartext remains disabled. Test-only
loopback DAV fixtures and unrelated OAuth loopback callbacks remain separate.

There are three accepted states:

| Policy | Native TLS context | Additional enforcement | Renewal |
|---|---|---|---|
| Standard (no private policy) | Normal trusted roots | Existing destination policy | Normal public PKI renewal |
| Private CA | Normal roots plus explicitly imported account-local CA material | SAN-only identity and bounded certificate eligibility checks | Valid leaf renewal under permitted anchors |
| Pinned leaf | Empty roots plus the exact approved self-signed leaf | Exact SHA-256 of DER, SAN identity, validity, modern algorithms, server usage and self signature | Every DER change requires explicit review |

The factory uses supported `HttpClient.connectionFactory` and
`SecureSocket.startConnect` APIs. Native TLS completes its normal verification;
the actual peer certificate is then checked **before the socket is returned to
HTTP**. Every `badCertificateCallback`/`onBadCertificate` returns false. No probe
or response certificate check authorizes a later connection. Management-only
observation sends no HTTP and cannot bypass validation on the authenticated
socket. Dedicated native-client construction is also injected into
`NativeTerminatingHttpClient.sendTerminating`; cancellation does not create an
unconfigured client. Connections are direct; private-mode HTTP proxy tunnelling
is not supported by this boundary.

SHA-256 is calculated over immutable original DER. Maintained upstream `x509`
and `asn1lib` decode certificates; Pointy Castle verifies self signatures over
the original TBSCertificate encoding. BusyMax does not implement chain building
or cryptographic primitives. Supported private algorithms are RSA 2048–8192
with SHA-256/384/512 and ECDSA P-256/384/521 with SHA-256/384/512. Unsupported
algorithms fail closed. Certificates require SANs (no CN fallback), exact IP
SAN matching for literals, and only a complete leftmost-label DNS wildcard with at least two fixed labels.
Native chain, hostname, protocol and applicable TLS checks remain enabled.
This is not a claim of universal revocation checking.

Imported anchors (including pinned leaves) support critical basic constraints,
key usage, extended key usage and SAN extensions. Other critical extensions fail
closed: parsing an extension does not establish that its mandatory semantics
are enforced for a trust anchor. Native anchor validation alone is insufficient
here, as real TLS counterexamples demonstrate. CA extended key usage, if present,
must permit TLS server authentication. Duplicate extensions are rejected.

Imports accept PEM certificate bundles or a DER certificate, bounded to 64 KiB
and eight certificates. CA basic constraints and certificate-signing key usage
are required. Input containing private keys or unsupported containers is
rejected. Certificate display is bounded plain text with controls and bidi
overrides removed; fingerprints and details are selectable. Dates are UTC.

## Ownership and authorization

Version 1 private policies store mode, owner, normalized installation (including
exact hostname/effective port), original certificate material and SHA-256,
approval time and a policy generation. Display names/dates come from the
certificate. Absence means standard HTTPS. A malformed/unsupported configured
record is retained as an explicit invalid policy for journal recovery and
local removal; it cannot construct a TLS client, become standard HTTPS, or
trigger automatic enrollment.

`NextcloudSecretRecord` carries policy and app password through the existing
authorization journal. Onboarding approvals stay session-local until successful
discovery and account commit. Canonical Login Flow handoffs must retain the
entered installation; the shared contacts Login Flow also rejects endpoints
outside that installation. Existing DAV destination/redirect policies remain
independent of certificate trust.

Account operations use the existing authorization lease through response
stream consumption. This prevents foreground/background engines from committing
a replacement while an old operation still uses its credential/policy. Active
clients are invalidated before authorization changes. Requests leave no idle
keep-alive socket; bindings validate their durable generation under the existing
lease before every request, including requests from other engines. No client
pool is shared between owners. No independent lock ordering is added.
Replacement uses existing account serialization, validates before journal
commit, and checks the captured generation. Failed replacement preserves the
previous policy and cached data. Removal drains existing work, commits locally,
then revokes using the captured immutable secret and policy; it never looks up
a deleted record or falls back to global trust.

Linked contacts resolve the parent authorization for requests and transfers.
Independent Nextcloud contacts store their own policy and authorization
generation with the independent secret. A staged replacement retains the
previous accepted snapshot, stamped with its actual durable generation even
for existing standard-HTTPS accounts. Nested obsolete snapshots are discarded;
restart selects only the snapshot matching the durable contacts generation.
Enrollment discovery precedes any durable approval.
Replacement drains the previous binding and validates generation/ownership;
failure restores the previous envelope. No standard or generic CardDAV account
inherits a Nextcloud policy.

Independent contacts validate the private envelope before selecting a recovery
snapshot and again before constructing a provider. Private metadata requires
the boolean Nextcloud marker, supported envelope version and valid durable
generation. Configured trust cannot use an ordinary/shared client when the
scoped factory is unavailable. An inconsistent envelope is a certificate-policy
failure; removal stays local and available. A well-owned malformed policy can
be deliberately replaced without reverting to standard HTTPS.

## Failures and foreground review

`NextcloudCertificateException` distinguishes approval required, pin mismatch,
expiry, not-yet-valid, hostname mismatch, invalid policy, ineligible material,
and native verification failure. It implements the first-party DAV
`DavRequestNotDispatchedException` contract only at the pre-HTTP boundary.
The shared transport preserves that exact failure and never retries it or
converts it into `DavUnknownMutationOutcome`. Genuine post-dispatch loss keeps
unknown-outcome/reconciliation behavior.

Native interruption acceptance exposed one transport regression: TLS closure
before a validated socket was returned, without an observed certificate
rejection, was being converted into a certificate-review failure. This could
pause ordinary outage recovery. The factory now reports that boundary as a
network failure with explicit pre-dispatch evidence. It still returns no socket
to HTTP, so no headers/body can have been sent. Observed certificate rejection
and malformed certificate material retain their specific certificate failures;
accepted policies are never dropped or replaced during retry. Six real-socket
regressions reproduce the old error and cover all three trust modes through
ordinary and terminating clients. Genuine post-dispatch losses retain their
existing unknown-outcome/reconciliation behavior.

Known trust failures pause account/contacts retries and pending writes, preserve
caches and credentials, and use the existing durable notification deduplication
with a **Review server certificate** state. No background enrollment/dialogs.
Contacts check the persisted review state before recreating a provider, both
at startup and synchronization. Direct certificate exceptions retain their
specific code, including expiry; a restart cannot overwrite them with a generic
sync/reconnect error. Error writes remain guarded by the captured generation.
Linux uses the existing Yaru dialog system, Windows Fluent `ContentDialog`, and
Android Material presentation. Approval is a separate explicit action; initial
keyboard focus is rejection. CA trust is preferred; unverified first-use
fingerprint approval is not equivalent to a CA provisioned through an independent
trusted channel. External-browser trust is managed separately.

## Verification and acceptance gaps

The development runtime is Flutter 3.47.5 / bundled Dart 3.13.4 on Linux x64.
Real loopback TLS fixtures generate disposable keys under the OS temporary
directory. They cover exact leaf and CA validation, same-key leaf change, CA
leaf renewal, pre-send rejection, account/origin/port isolation, serialization,
SAN rules, cryptographic eligibility and cancellation. Native TLS tests are not
mocked HTTP responses. Platform widget tests cover keyboard rejection, selectable
details, narrow layouts and larger text for all three presenters. Authorization
tests cover failed discovery/storage/database replacement, generation checks,
cached-data preservation and captured revocation snapshots.

Verification on October 30–31, 2026 (Vancouver):

| Check | Actual result |
|---|---|
| Two complete Flutter runs after notification fixture correction | **4,385 passed / 16 opt-in skips**, then **4,385 passed / 17 opt-in skips**; **zero failures in both**. The added skip is the new opt-in federation case |
| Contacts/TLS/authorization regressions | Included in the complete suite; the 18 contacts corrections cover startup, disk restart, malformed records, expiry, recovery and cache retention |
| Complete Flutter run after transport correction | **4,391 passed / 17 opt-in skips / zero failures** in 8m03s; the six additional cases reproduce pre-certificate connection loss |
| Independent-cache official SDK recheck | **4,391 passed / 17 opt-in skips / zero failures** again in 9m45s; full pipeline exited 0, including shared suites, native Android checks, analysis, generation and default integrity verification |
| Retained-startup follow-up, affected regressions | **64 passed** across contacts lifecycle, real TLS and certificate-dialog tests |
| Retained-startup follow-up, complete repeat | **4,391 passed / 17 opt-in skips / zero failures**, exit 0 in 9m59s; the first full-run release-fixture timeout is recorded below |
| Startup correction, focused regressions | **117 passed**: four real SQLite connection/concurrency/trace cases, 13 lifecycle/resource/gate cases and 100 existing notification/schedule regressions |
| Startup correction, first complete Flutter run | **4,401 passed / 17 opt-in skips / one failure**, the unchanged Linux weekday/startup-activation widget case; all 16 cases pass in isolation, but the loaded-run cause remains unresolved |
| Startup correction, final complete Flutter run | **4,408 passed / 17 opt-in skips / zero failures**, exit 0 in 7m15s, on the final production source in `7ba620c`. Earlier successful correction runs were 4,402, 4,404 (twice) and 4,405 as regressions were added; repeats do not explain the first widget failure |
| Native Linux Flutter engine | All **32** actual TLS tests passed again after the startup correction on a separate X display, D-Bus session and XDG directories; no desktop profile was used |
| Native Android retained-work lifecycle | **Passed on the physical phone** after correction: both original periodic workers `SUCCESS`, actual overlapping foreground/background database operations, CA renewal, changed-pin rejection, process termination with pending work, explicit UI replacement, recovery and captured remote revocation. All unsuccessful preparation/trial outcomes are retained below |
| Native Android phone | **Seven passed** on OnePlus 6 / Android 10 (API 29, ARM64): rejection before HTTP, CA renewal/identity validation, exact pin/change/replacement, ownership/disposal isolation, actual encrypted storage, native review UI and actual CA file selection/rejection/approval |
| Android application | Acceptance APKs built, installed and launched on the designated test runtimes; the phone had no pre-existing BusyMax package |
| Android native checks | **15** platform unit tests passed with zero failures/skips; app lint passed |
| First-party shared DAV / contacts | **82/82** and **119/119** passed again, respectively; zero failures or skips; both static analyses passed |
| Static analysis, formatting and platform boundaries | Passed on the final correction; maintained Dart sources include the new lifecycle/concurrency probes, excluding ignored execution artifacts |
| Localization/generated sources | Localization and Drift regeneration matched the reviewed source snapshot |
| Official SDK/upstream integrity | Default verifier passed eight protected dependencies and 1,171 SDK/runtime files; all 29 verifier regressions passed |
| Windows | **Environment-blocked** by the existing VM's SYSTEM registry-hive boot failure; no new recovery attempt in this follow-up |

The two previous notification failures were in an unchanged baseline fixture:
`android_notification_reconciliation_test.dart` has the same original Git blob
in pre-feature `daee1df` and `406665c`. The first failed while awaiting its initial
native settings-file save, before creating either notification runtime or
executing certificate handling. Teardown removed the directory while that save
was outstanding; the following case also encountered a late platform-channel
null result. The fixture writes with `flush: true` and renames real files on the
shared host filesystem. The unchanged file and an exact baseline copy each
passed all 64 cases under syscall tracing. Tracing observed host flush latency
but did not reproduce the original 30-second stall; no precise kernel-level
cause is claimed.

`ba993ee` moves six persistence directories to the existing
`createPersistenceTestDirectory` helper, which uses Linux tmpfs when available.
The tests still perform actual file writes, flushes, atomic renames, native
SQLite transactions and close/reopen recovery. No assertion, test timeout,
notification implementation or TLS policy was changed. This removes the shared
disk journal dependency from those coordination tests. Both previously failing
cases passed in all four complete follow-up suites. A separate old startup-widget
flake also passed in that full run; its implementation and assertions remain
unchanged.

The retained-startup follow-up's first complete Flutter run finished with
**4,390 passed / 17 opt-in skips / one failure**: the unchanged
`test/tool/release_pull_request_test.dart` exceeded its existing two-minute
limit while awaiting the local Python/Git fixture. Its Dart wrapper, all 19
Python regressions and release validator have the same Git blobs as `daee1df`;
none imports certificate or startup code. The 19 regressions then passed in
7.6 seconds under isolated syscall tracing. No two-minute stall was reproduced
and no precise host/process root cause is claimed. No timeout/assertion or
release implementation was changed; the failed full run is not a pass.
The exact complete command then passed with **4,391 passed / 17 opt-in skips /
zero failures** in 9m59s and exit code 0, using the same concurrency, assertions
and timeout limits. The isolated pass and successful repeat do not establish
the precise cause of the first stall.

The Android test-only Mockito dependency was upgraded to upstream 5.24.0 because
5.0.0's bundled instrumentation cannot run on this host's supported Java 25.
No SDK or dependency was downgraded or patched.

The startup correction's first complete run reproduced the already documented
startup-widget flake: Linux `weekday_startup_activation_test.dart` did not find
“Import calendar events” within its existing 30 × 20 ms polling loop. The test,
root activation/readiness and import-flow source match `daee1df`. This fixture
uses `AppDatabase.memoryForTests()`, so the new native connection busy handler
is not exercised. All **16** cases passed in the isolated rerun. No assertion,
polling bound or application behavior was changed to obtain that result.
The loaded-run cause remains **unresolved**; source identity and a successful
repeat do not establish its precise cause or exclude every timing interaction.
It is recorded separately from the original notification fixtures and the
Android SQLite defect. The historical Git-fixture timeout above also remains
unexplained and did not recur in this complete run.

Live protocol tests used an isolated official Nextcloud 35.0.1 container with
Calendar 6.6.4 and Tasks 0.18.1, fresh QA users/app passwords, and a temporary
loopback TLS reverse proxy. Server installation, app installation and fixture
settings used supported administration commands. Authentication-delay protection
was disabled and the calendar-creation quota raised only in this disposable
instance so deliberate failed-credential/repeated-creation tests could run.
Client account URLs always used HTTPS. No CA was installed in an OS or normal
browser store. Browser acceptance used
only a disposable Firefox profile; all keys and execution logs stayed outside
tracked source.

| Live protocol matrix | Root installation | `/nextcloud` installation |
|---|---|---|
| Explicit private CA | Seven cases passed | Seven cases passed |
| Explicit pinned self-signed leaf | Seven cases passed | Seven cases passed |

Each cell covers real discovery, calendar/task sync and conditional mutations,
task completion/reopening, pending-write replay, both contacts resource and
streaming transports, captured app-password revocation and subsequent rejection,
and Login Flow initiation/cancellation/pending polling. The additional cases
verify sharing ACL changes/unshare access revocation and persisted-policy native
import with queue replay and readback. Both contacts identities
are explicitly provisioned with separate accepted policies. These are protocol
acceptance tests, not a claim of complete account-settings UI/browser acceptance.

The Nextcloud 35.0.1 unshare failure was reproduced using unchanged pre-feature
BusyMax `daee1df` and DAV `75bdc14ff793a2cf41c0632500dbdfd32d1910a2` in
isolated detached worktrees. Those clients used ordinary native HTTPS with the
disposable fixture CA added only to a test-local context; no certificate-error
callback or global trust exception was used. The original inventory assertion
failed with both transports. Diagnostic discovery showed a
`{http://nextcloud.com/ns}deleted-calendar` trash entry, not an active share.
The maintained sharing test now excludes that resource kind and additionally
checks that an actual event is readable before unshare and rejected afterward.
The corrected suite passes with both transports. This was an acceptance-fixture
classification bug, not a TLS regression; no sharing implementation or server
source was changed.

One extended-fixture creation returned `403 Calendar limit reached`: repeated
tests and retained trash mounts exhausted the default 30-calendar inventory
limit. The disposable server's `dav.maximumCalendarsSubscriptions` was then set
to integer 1000 using `occ config:app:set`. The pinned-subpath import rerun passed.
A separate retry against an already exited child proxy was an orchestration
error; persistent proxy sessions were used for subsequent runs. Neither failure
was a TLS-policy failure or evidence of a successful import.

The follow-up federation fixture added a second independent official Nextcloud
35.0.1 instance. Initial `DavCollectionOutcomeUnknown` failures occurred with
both private modes and unchanged pre-feature BusyMax `daee1df` / DAV `75bdc14`
using ordinary HTTPS with a dedicated CA context. Server diagnostics identified
fixture failures: server-to-server cURL error 60 (unapproved peer trust), then
SQLite `database is locked`. Strict cURL subsequently returned HTTP 200 in both
directions after explicit server-local certificate-bundle configuration; this
is separate from BusyMax account trust. No OS store or TLS bypass was used.

Upstream `occ db:convert-type` failed in migration/sequence handling. Instead,
the **same two disposable containers** were initialized on fresh independent
PostgreSQL databases using supported `maintenance:install`; original fixture
data/configuration were preserved during testing. Calendar/Tasks versions and
TLS endpoints remained unchanged. The official federation synchronization jobs
were executed with supported Nextcloud commands: accepted remote calendars are
materialized asynchronously. The test observes read-only 404 responses for up
to 30 seconds inside its unchanged three-minute limit; it never retries a
sharing mutation. Creation-rate exhaustion (429) was identified separately and
only the QA `dav.rateLimitCalendarCreation` was raised to 1000.

The final PostgreSQL comparisons still fail at `DavCollectionOutcomeUnknown`
with ordinary unchanged standard HTTPS, private CA and pinned leaf. An earlier
CA attempt confirmed invitation acceptance and peer event readback, then
observed a retained cached event (HTTP 200) after owner-side grant removal;
that is not a pass of the asserted revocation workflow. Other preparation
attempts encountered server-to-server cURL timeout 28. These distinguish
server/fixture behavior from a certificate-policy rejection, but establish no
complete federation pass or definitive root cause for every inventory failure.
Peer delivery, refreshed readback and revocation remain unqualified. No product
sharing code, third-party source or uncertain-write safeguards were changed to
force a pass. The final baseline comparison again used exact unchanged product
and shared-package worktrees and was removed after verification.

The new opt-in `nextcloud_extended_live_test.dart` exercises the actual persisted
account client, authorization journal, import queue/replay, trash service and
scheduling service against HTTPS. Native import was observed to queue, commit
and read back. Trash stops with `DavTrashUnsupported` because discovery does
not advertise `nc-calendar-trashbin`; free/busy stops with `DavFreeBusyDenied`
at the existing scheduling-policy check. Restoration, permanent deletion,
invitation/reply delivery and inbox completion therefore remain unqualified.
These are recorded failures, not mocked passes or evidence that the guarded
operations work. They also persisted after provisioning actual sender/recipient
mailboxes and switching the fixture to PostgreSQL. Both failures reproduce
against the unchanged pre-feature standard-HTTPS product/DAV baseline, with
native import passing there. Matching codes alone do not establish identical
upstream causes. These comparisons demonstrate failures on the baseline and candidate; they qualify
neither the guarded workflows nor private-TLS interoperability, and do not
automatically prove a TLS regression. The affected services were not changed.
One import rerun under load also timed out with
`DavUnknownMutationOutcome`; that attempt has an uncertain result, not a
certificate-failure classification. Later serial reruns are recorded below.

Real external-browser acceptance now uses Firefox 158 in an isolated profile,
with ordinary certificate validation enabled. The private CA was provisioned
only in that profile. For the self-signed peer, the certificate-viewer DER
SHA-256 was compared with the independently held disposable fixture before
using Firefox's normal per-server exception. No global browser bypass or
`acceptInsecureCerts` capability was enabled.

`nextcloud_browser_lifecycle_live_test.dart` passed with **both private CA and
pinned leaf** against the actual Nextcloud server. It covers explicit rejection,
cancellation before authorization, normal browser login/Grant, discovery and
account commit, reconnect, credential revalidation, stale approval rejection,
failed return to standard HTTPS preserving the previous policy, explicit trust
replacement, CA renewal, changed-pin rejection with unchanged application-request
count, network interruption/recovery, local-first removal and captured remote
revocation followed by authentication rejection. SQLite is closed/reopened and
journal recovery is run. This browser fixture uses an in-memory secret store;
it does **not** establish native secure-storage process-crash recovery.

The existing VirtualBox VM was discovered as **Windows 11**, UUID
`474b7e1c-3ee7-4260-9d28-f6ce97c6f8e3`. Its saved desktop initially resumed and
exposed the pristine official Flutter 3.47.5 SDK. The VM then stopped unexpectedly;
cold boot reports **0xc000014c**, `\Windows\system32\config\system`.
No snapshots were present, and no known-good recovery point could be verified.
Before recovery,
the full disk, configuration, NVRAM and saved state were preserved under
`/mnt/Media/busystack/windows-vm-preserved-20261030-224330`.
Official Microsoft recovery media was downloaded and matched Microsoft's
published SHA-256. The DVD booted; selecting **Repair my PC** returned to the
same hive error before Startup Repair became available. The bounded attempt
stopped there: no reinstall, reset, registry replacement or new VM. The
original optical drive, boot order and bridged NIC configuration were restored.
Windows native TLS, storage/restart and management UI remain
**environment-blocked and unaccepted**. To resume, the existing Windows 11 VM
must boot to a usable Windows user session with native Flutter/Visual Studio
build-and-run access and local shared-folder/Guest Additions transfer. Bootable
access or known-good recovery data must be restored outside this bounded task.
The preserved backup remains intact; this follow-up made no further recovery
attempt, reinstall or new VM.

Android initially suffered a VirtualBox/KVM conflict and unstable software
emulation. The software-emulated storage test exceeded its normal timeout and
later completed during another test; it is not a platform pass. A stale process
belonging to this same Windows VM was stopped after preservation/recovery,
allowing the isolated KVM emulator to boot again. One retry encountered a
stopped TLS-fixture peer and was classified as an orchestration failure.
The connected physical phone passed all six native core checks in seven
seconds, including the previously delayed secure-storage case. After the
transport correction it passed all **seven** maintained checks, including real
Android DocumentsUI selection of the disposable public CA, explicit rejection,
then explicit import approval and a successful CA-authenticated request. These
checks use actual sockets, native secure storage and Android dialogs. File-picker
automation initially selected the search field and an obscured file; those
automation attempts did not authorize a connection. Exact native title selection
completed the maintained test without weakening assertions or changing timeouts.

The new Android lifecycle probe uses the production runtime, real Nextcloud
accounts, secure storage, authorization journal, native account gates and
WorkManager; it does not override transports or synchronization. Its first
background attempts were blocked by Android's explicitly unmet validated-network
constraint. The phone connection
was subsequently validated. The first lifecycle phase passed in 21 seconds:
two separately owned CA/pinned accounts, native encrypted credentials/journal,
foreground synchronization, real WorkManager synchronization, selectable
certificate details and the actual Android settings presenter.

The earlier lifecycle attempts failed at `COMMIT TRANSACTION` during startup
notification rebuild. File identity alone did not establish baseline behavior.
A subsequent **actual Android APK comparison** now establishes a pre-feature
startup contention defect; it does not qualify startup or erase the earlier
failures.

`android_retained_startup_test.dart` is a separate two-phase path. The same APK
seeds two standard-HTTPS Nextcloud accounts (closed localhost ports, synthetic
credentials), 500 cached tasks and six future reminders, then leaves both
periodic jobs persisted across a real force-stop. Restart performs the production
`AndroidHeadlessRuntime.create()` alongside the production sync/refill dispatcher.
There is **no `cancelAll()` and no job registration/replacement during restart**.
The host removes only the initially absent QA package after each complete
comparison, including failed comparisons.

The candidate's product source was `61b5906`; the actual pre-feature product was
`daee1dfc3c0a3bf24e6124d88c88ad399ab7fcdc`, with its selected DAV `75bdc14` and
unchanged contacts/Graph revisions. All four detached baseline repositories had
zero tracked changes. Both APKs used the identical untracked acceptance entry
point, SHA-256 `ad466976379012278127e2c72066c18915808fc0b7d0f007c5d410b01ac092a6`,
and the pristine official Flutter/Dart SDK. The resolved WorkManager Dart/Android
sources were additionally compared file-for-file with their checksum-matching
published archives: zero differences. Drift, SQLite, SQLite Flutter assets and
native secure storage were also checked against their exact locked publisher
archives, with zero differences. No SDK/dependency was patched.

Both builds ran serially on the same OnePlus 6/API 29 installation target,
including a second comparison in reverse order. Native WorkManager snapshots
proved two retained `ENQUEUED` rows, zero attempts/periods and unchanged UUIDs;
logcat identified both worker UUIDs/tags and simultaneous startup. Read-only VM
sampling observed **three engine isolate groups** in every evaluated restart.
Both snapshots used `journal_mode=delete`, `busy_timeout=0` and normal locking.

| Actual retained-worker restart | Foreground SQLite primary/extended code | Time from runtime-create entry to observed SQL failure | Native engine groups |
|---|---|---|---|
| Pre-feature APK, first comparison | **5 / 5 (`SQLITE_BUSY`)** | 3,884 ms | 3 |
| Candidate APK, first comparison | **5 / 5** | 4,409 ms | 3 |
| Candidate APK, reverse-order comparison | **5 / 5** | 5,480 ms | 3 |
| Pre-feature APK, reverse-order comparison | **5 / 5** | 9,423 ms | 3 |

The foreground stacks enter `AndroidHeadlessRuntime.create` notification
reconciliation, including `NotificationScheduleService._taskNotifications` /
`isReminderSourceEligible`. The failing reads vary (`accounts`, `task_lists`,
`notification_schedule`) with interleaving. These are real serialized SQLite
extended codes, preserved with the causing statement and stack, not generic
synchronization errors. The table records startup-to-SQL-failure bounds and
native job timing; it is **not** a measurement of each individual SQL transaction's
BEGIN/COMMIT duration. The original exact COMMIT failure site was not reproduced
in these four foreground captures. The evidence confirms pre-existing startup
SQLite contention, without asserting an identical statement-level cause for
every earlier failure. Two trials per build do not quantify whether timing
changes alter the incidence; both builds remained affected before the correction
described below.

Probe preparation failures were classified separately: Android does not support
scheduled-task printing or this phone's UID logcat filter; supported work-info
and PID capture replaced them. Fresh production periodic work is initially due
ten minutes later; interrupted running work also retains its backoff. Neither
preparation exercised concurrent restart and neither counted as a pass. The
common fixture therefore uses a full first flex window and a three-second
initial delay, verifies unattempted retained rows, then lets that delay expire
while stopped. Frequency, real dispatcher, network/battery/storage constraints
and ten-minute backoff remain intact. No WorkManager database row is edited.
The stricter host verifier requires both original worker results, successful
notification refill, absence of SQLite errors and three concurrent groups;
worker initialization failure cannot become a passing foreground result.

Classification of the original failure: **pre-existing Android product defect**,
demonstrated by the actual unchanged binaries. That baseline comparison is
retained above and was not repeated for the corrective task.

### Startup coordination correction and retained-worker follow-up

Commit `7ba620c` coordinates native notification observation and the
subsequent lifecycle-preserving rebuild as one operation under the existing
engine-owned notification gate. Observation still precedes rebuilding. Schedule
mutations invoked by ordinary sync, repositories and system-settings changes
use that same gate through the Android runtime's database dependency. The lock
order is account/authorization lease, notification lease, then SQLite
transaction; data transactions finish before requesting a notification rebuild.
No new account lock hierarchy or journal-mode change is introduced.

Other accounts and ordinary synchronization still write independently. Every
Android native connection now installs a bounded, monotonic five-second busy
handler using the public `sqlite3.Database.busyHandler` API. Drift already uses
`BEGIN IMMEDIATE`. SQLite controls which lock acquisitions may wait and may
still reject a deadlock-prone upgrade without invoking the handler. BusyMax
never replays a Dart transaction callback, HTTP request or external side effect.
The handler also covers autocommit reads/writes and commit lock acquisition.
The existing rollback journal is unchanged. In the actual Flutter/Linux
reproduction, all 59 native sleeps in SQLite's default busy handler were
interrupted by runtime signals, consuming its requested-sleep budget in about
70 ms. The monotonic bound addresses that observed failure; it is not a blind
increase to a test or database timeout. See SQLite's [busy-handler contract](https://www.sqlite.org/c3ref/busy_handler.html).

Runtime initialization now owns its allocated database, HTTP client, staging,
notification service and provider container. Failure closes all acquired
resources in reverse order. Cleanup failures cannot mask an escaping original
failure; successful shutdown reports a cleanup failure after attempting the
remaining closes. Disposal is idempotent and drains notification work without
withdrawing scheduled reminders or clearing their history. Gate release uses
only the captured lease; worker/engine termination retains the existing native
owner-specific release mechanism. Notification action background entry points
use the same exception-preserving resource cleanup. Each runtime drains only
its own submitted notification operations; disposal never acquires another
global lease or waits for another runtime's queued work. Completion tracking
does not attach a handler that hides unobserved operation errors. Foreground
snooze/dismiss and headless actions use the reentrant notification operation
before starting SQL, avoiding self-acquisition of the existing native lease.

The notification lease acquisition budget is 90 seconds; account/settings
leases remain 30 seconds. This follows an observed finite queue, rather than a
timeout-only workaround: live trial 6 measured foreground observation at about
six seconds followed by a refill operation holding the notification lease for
about 25 seconds under concurrent writers. The third runtime exhausted the old
30-second acquisition budget immediately before that operation released its
lease. Stage traces identified the owners and successful release, with no SQL
failure. The longer notification-only budget accommodates three startup owners;
it does not serialize unrelated account SQL or change worker constraints.

The retained probe now keeps the foreground runtime, UI and database activity
alive until the host records both **original** WorkSpec outcomes. It does not
cancel or re-register retained jobs on restart. Opt-in metadata-only connection
tracing records transaction begin/read/write/commit timing without SQL,
arguments, credentials or account contents. Passing requires actual overlapping
foreground/background database operations, not merely three engine groups.
The full VM stack sampler is now optional because it is intrusive; ordinary
capture retains isolate metadata alongside the SQL timing. Bounded trace files
are buffered in app-private storage and flushed during connection disposal;
per-SQL console output had overloaded logcat. The host requires the foreground
test's completion after its verification receipt, not just that receipt.
Typed `CancellationException` from an obsolete nontransaction read subscription
is recorded separately. Every SQLite code, unknown failure, failed transaction
or write remains fatal; no database error is suppressed. Twelve host regressions
cover these distinctions and log/completion evidence.

Closed-port corrective trials (all outcomes retained):

| Phone trial | Actual outcome |
|---|---|
| 1, initial instrumentation | Foreground assertions and both workers succeeded with no SQLite errors, but Android had no writable stderr; no SQL timing was captured. **Not accepted** |
| 2, instrumented | **Passed**; 37 foreground/background overlaps, original sync `RETRY` for the intentionally unreachable fixture, refill `SUCCESS`, zero failed SQL operations |
| 3, instrumented repeat | **Passed**; 142 foreground/background overlaps, original sync `RETRY`, refill `SUCCESS`, zero failed SQL operations |
| 4, intrusive sampler | Neither worker outcome nor foreground completion arrived within the unchanged observation bound. Zero SQLite errors, but an encrypted-preferences initialization/decryption diagnostic occurred. **Incomplete/unqualified**; its cause is not established by the successful repeats |
| 5, preflight | Phone locked before installation; no runtime trial occurred |
| 6 | Foreground and both worker assertions passed; 185 overlaps, zero SQLite errors. **Host rejected** an untyped canceled read; it was not retrospectively counted as a pass |
| 7 | Foreground and both worker assertions passed; 118 overlaps. Typed tracing proved a nontransaction read `CancellationException`, not a SQLite failure; the previous host classifier still rejected it |
| 8 | **Passed**, 258 overlaps with corrected typed classification; original sync `RETRY`, refill `SUCCESS` |
| 9 | **Passed**, 184 overlaps using buffered trace files and confirmed foreground finalization |
| 10, final production source | **Passed**, 189 overlaps, original sync `RETRY`, refill `SUCCESS`, foreground finalization confirmed, zero SQLite/unexpected operation errors |
| 11, same final APK | **Passed**, 103 overlaps with the same outcomes and no SQLite/unexpected operation errors |
| 12, same final APK | **Passed**, 155 overlaps with the same outcomes and no SQLite/unexpected operation errors; three consecutive final-source closed-port restarts passed |

The four focused database cases use separate real native executor isolates to
exercise competing writers, an independent reader blocking commit, bounded lock
exhaustion, successful subsequent work and private metadata-only trace cleanup.
Thirteen resource/gate regressions cover allocation/initialization failure,
cleanup failure, foreign-lease isolation, own-operation draining, visible
unobserved errors, foreground/direct reminder actions and subsequent startup.
Restoring the previous foreground manual-lease callback in a temporary negative
control made both reminder-action regressions fail on same-operation gate
reentry; restoring the correction made them pass. No timeout or ownership
assertion was relaxed. Together with existing notification/schedule regressions,
**117 passed**.

The successful closed-port fixture intentionally returns sync `RETRY`; it alone
cannot establish successful live synchronization. The retained live probe uses
two real accounts on official Nextcloud 35.0.1 with PostgreSQL, 30 events and 30
tasks per account, future alarms, real native encrypted storage, the production
runtime/dispatcher and the same two original periodic jobs across force-stop.
Every trial used a new initially absent QA installation. Its outcomes were:

| Live retained-work trial | Actual outcome |
|---|---|
| 1 | Preparation failed: proxy forwarded a backend HTTP well-known redirect. Corrected only the disposable reverse proxy's exact-origin Location mapping and compressed-response handling; no client redirect/TLS policy changed |
| 2–3 | Incomplete: console tracing overloaded capture; logcat EOF/restart observation did not establish worker/foreground completion. No pass claimed |
| 4 | Incomplete: host's total observation bound included runtime initialization and ended before the Dart phase's own bound. Buffered trace capture retained; clocks subsequently aligned at the current runtime-opened receipt |
| 5 | Foreground failed because the original workers did not finish within its 35-second observation window; no SQLite error. Stage instrumentation was added to locate the wait |
| 6 | Actual worker initialization failed at the old 30-second notification gate budget while other owners made finite progress, as measured above. No SQLite error; led to the notification-only production correction |
| 7 | Both originals `SUCCESS`, 8,253 foreground/database overlaps, zero SQLite/unexpected failures; CA renewal, pin rejection, interrupted process recovery, explicit replacement and pending replay passed. **Overall incomplete**: the 180-second aggregate host watchdog stopped publishing a later worker's already successful native result, which completed in about 21 seconds, within its unchanged 45-second Dart bound |
| 8, final production source | **Passed end to end**: both originals `SUCCESS`, 7,887 foreground/background overlaps (7,888 total), three concurrent engine groups, no SQLite/unexpected operation errors, no logcat reconnect, foreground test and cleanup completed |

The live observation window is 120 seconds, based on measured repeated
notification reconciliations (about 25 seconds each under the foreground writer)
and successful real sync. The host lifecycle watchdog is now the sum of eight
existing 45-second step bounds plus 60 seconds for UI/revocation (420 seconds).
Trial 7 identified a prematurely stopped receipt publisher; individual worker
assertions remain at 45 seconds. These are explicit fixture budgets, not passes
obtained by cancelling, replacing or disabling retained workers.

Trial 8 verified both accounts' successful sync timestamps advance while
foreground writes continue. After private-CA leaf renewal, a changed pin
received **zero additional application requests**; pending-write IDs and cached
object IDs survived a second force-stop and different PID. CA sync continued.
Native settings displayed previous/new fingerprints; rejection left generation
and application-request count unchanged, explicit approval saved the exact new
leaf, and background sync replayed the pending write. Network interruption
remained an ordinary network error and recovered without replacing trust.
Local-first removal of both accounts reported successful captured-policy
revocation; subsequent authentication with each captured app password returned
**401**, and accounts, credentials and authorization journals were empty.
All original jobs were retained throughout the evaluated phases; cleanup
followed complete foreground/worker outcomes. This qualifies the retained-work
scenarios on this OnePlus 6/API 29 debug test installation, not a universal
Android/API-level or signed-release matrix.

For historical comparison, before this retained-work path, after clearing only
the QA app's retained WorkManager jobs through the supported
plugin API, the **unchanged second lifecycle phase passed in 64 seconds** after
an actual force-stop (a different PID is asserted). Both credential/policy records
survived process death. Production background workers accepted CA leaf renewal;
a changed pin produced the exact persisted review state, no additional
application requests, and retained caches/pending changes while the other
account continued. The actual settings UI displayed old/new fingerprints,
rejected one replacement without changing generation, then explicitly approved
the exact replacement. Background work resumed and replayed the retained write.
Listener interruption stayed an ordinary network error after `474add6` and
recovered without dropping trust. Removal used the captured policies, committed
locally and revoked both app passwords; authenticated readback returned 401 and
accounts, credentials and authorization journals were empty. These results
qualified only those operations on the tested phone at that time; they did not
qualify concurrent startup. Trial 8 above supplies the new retained-work result.

Certificate replacement/removal races, concurrent clients, credential isolation
and stale approvals also pass the real-TLS/authorization regression suites.
These do not establish unavailable Windows behavior. Release-package/OS
trust-store matrices and platform assistive-technology checks remain open;
widget checks do not replace them. No universal OS private-root visibility,
revocation checking or unverified-first-use identity guarantee is claimed.
The initially absent Android QA package and its public certificate file were
removed, only QA ADB forwards were removed, and the original USB-awake setting
was restored. No normal desktop BusyMax installation/profile was changed.

The previous SDK discrepancy came from a pre-existing modified `pubspec.lock`
in `/home/albert/flutter`. That tree remains untouched. This follow-up actually
selects `/tmp/busymax-official-flutter-6a19cca`, pristine official Flutter
`6a19cca56475dbfba1478ee68d7bd0c2ef891da1`, for `pub get --enforce-lockfile`,
tests, analysis, code generation and native checks. Direct Dart commands also
set `FLUTTER_ROOT` to that checkout: otherwise the shared cache's physical path
can cause Dart's automatic package resolution to reselect the pre-existing SDK.
This reselection was caught by a failing integrity recheck and corrected before
the final standalone run. Package resolution and
Android `flutter.sdk` point at that checkout. The checkout has no tracked SDK
changes. The final recheck uses an independent, unchanged copy of the
publisher-verified runtime cache, so Flutter also reports the selected checkout
as its runtime root. Earlier checks used a shared cache link. The ordinary
integrity command passes **without `--sdk` override**, checking the selected source and verified
cached official runtime together. No checker was weakened and no SDK or
third-party source was patched, downgraded or distributed.

The actual reviewed root history contains `ad3c1da82f397d66be3fa6c91b8d9be1d890df83`
(only the Android test Mockito update), `1a11d1a` (private trust implementation)
and `53c7efe` (contacts corrections and 18 regressions). The selected sibling DAV
revision is `33afd70a761822847a37c7ad47f5e61dfeaa74a7`, matching
`tool/shared_dependencies.json`; contacts is
`af6490c55f1c4c638ea51066603eb97bf0d8e2c8`. The 82/119 figures are complete
independent shared-package suites, not an incomplete 82-of-119 run. No sibling
source changes were needed in this follow-up, and existing sibling IDE edits
were preserved.

The hermetic full suite leaves live tests opt-in. Every skipped case is accounted
for here; skipping is not platform or protocol acceptance:

| Case(s) | Follow-up acceptance |
|---|---|
| Main Nextcloud DAV semantics | Passed separately with explicit private CA; the earlier root/subpath and pinned matrix is recorded above |
| Nextcloud contacts resource/streaming | Passed separately with explicit private CA |
| Captured revocation, Login Flow cancellation, pending polling expiry (three cases) | Passed separately with explicit private CA |
| User/group sharing | Corrected fixture passed with private CA and unchanged standard HTTPS; actual reader access revocation verified |
| Large 128-member collection | Passed alone in 19 seconds; the earlier loaded attempt timed out at five minutes |
| Server restart prepare/verify (two cases) | Passed with private CA across an actual container restart and unchanged front TLS identity |
| Complete browser Login Flow and new lifecycle driver (two opt-in cases) | New driver passed separately with private CA and pinned leaf using a normally validating isolated Firefox profile |
| iCloud semantics and iCloud atomic lifecycle (two cases) | Outside this Nextcloud change; no disposable iCloud credentials supplied, not rerun |
| Native import (new extended case) | Passed alone in all four private-mode/root/subpath cells; one loaded rerun timed out with unknown outcome |
| Trash restore/permanent deletion (extended case) | Failed at `DavTrashUnsupported` with standard baseline, private CA and pinned leaf; guarded operations unqualified |
| Scheduling free/busy and inbox (extended case) | Failed at `DavFreeBusyDenied` with standard baseline, private CA and pinned leaf; inbox/delivery unqualified |
| Federation to an independent HTTPS Nextcloud peer (new case) | Matching `DavCollectionOutcomeUnknown` with both private modes and unchanged ordinary baseline, including fresh PostgreSQL fixtures. No complete end-to-end pass; server/fixture issues and the partial cached-read result are detailed above |

Android acceptance: the corrected startup and retained-worker certificate
lifecycle **passed on the tested phone**, including successful live sync and
process-death recovery. Earlier incomplete trials and the unrelated unresolved
Linux widget/Git-fixture stalls remain recorded; successful repeats do not
explain them. Other Android versions, signed release packaging and native
assistive-technology coverage remain unverified.

Overall release recommendation: **NO-GO**. Required Windows native TLS,
persistence/restart and certificate-management acceptance is still
**environment-blocked**. Linux/Android results cannot substitute for it.
Scheduling and trash have matching unchanged standard-HTTPS baseline
failures, with guarded end-to-end operations still unqualified. Federation's
fixture failures are separately classified above; no TLS or uncertain-write
safeguards were relaxed to produce a pass. Passing Linux/unit/widget tests or
compilation cannot close unverified native behavior.

Run the focused suite, then the full applicable Flutter suite, static analysis,
platform boundaries, generated-source reproducibility, shared DAV/contacts
tests, upstream integrity and native builds. Keep execution logs outside source.
The existing live Login Flow, calendar/task and sharing suites now use the
production factory. For each suite's environment prefix, set `TRUST_MODE` to
`standard`, `private_ca`, or `pinned_leaf`; private modes additionally require
`TLS_CERT` pointing to explicitly approved disposable certificate material.
The extended suite uses `BUSYMAX_NEXTCLOUD_LIVE_*` for its HTTPS address,
credentials and trust, plus `BUSYMAX_NEXTCLOUD_EXTENDED_LIVE=1` and
`BUSYMAX_NEXTCLOUD_EXTENDED_LIVE_RECIPIENT` for a disposable attendee's email.
It creates and deletes its own collections and objects. Run live suites
serially against a SQLite fixture; overlapping mutating runs produced database
locks and 500 responses. Use a supported PostgreSQL fixture and normal server
federation jobs for concurrent server-to-server federation acceptance. Do not
run other build/test/generation jobs against the same checkout during final acceptance.
Run both private modes at the root and at a subpath, and record browser,
discovery, sync, mutations, completion, reconnect and revocation results before
making release interoperability claims. Never use personal accounts for these
mutating/revoking fixtures.

The maintained native probe uses `tool/nextcloud_native_tls_host.dart` with a
temporary output path. Pass that JSON file to
`integration_test/nextcloud_native_certificate_test.dart` with
`--dart-define-from-file`; on Android reverse only the printed loopback ports.
`BUSYMAX_NATIVE_CA_PICKER=true` enables the real file-selector case; provision
only its public CA as `BusyMax-certificate-QA.crt` in the test device's Downloads.
Run on an explicitly isolated test app/profile and remove the test installation
and public file afterward.

The separate Android lifecycle probe runs twice with `--no-uninstall`, the same
`BUSYMAX_NEXTCLOUD_ANDROID_QA` base64 JSON define, and an actual force-stop
between runs. Its fixture has a unique `runId` and two `accounts`: separate
`id`, HTTPS `authority`, `mode` (`private_ca` / `pinned_leaf`), approved public
`certificate`, `replacement`, disposable `username`/`password`, and loopback-only
`control`/`nonce`. The disposable server control implements `/change`, `/counts`,
`/offline` and `/online`; it changes actual TLS listeners and records application
request counts. Store this credential-bearing define outside source. Do not
clear or replace account trust to make a resumed probe pass. For retained-worker
acceptance, also set `BUSYMAX_RETAINED_STARTUP_QA=true`
and `BUSYMAX_SQLITE_TRACE=true`, then run the host verifier below with
`--lifecycle`. This path registers the original periodic jobs after provisioning,
retains them across the first real process stop, waits for both recorded
outcomes while foreground database activity remains active, and then exercises
the live lifecycle. It adds another real process stop with a changed pin and a
pending write before explicit UI replacement. Follow-up one-off workers use
unique QA names, the production dispatcher/constraints/backoff and exact native
outcome receipts; none is replaced or cancelled to obtain a pass. This path
passed on the physical phone as recorded above. Earlier cleanup-based lifecycle
passes are not substituted for retained-work acceptance.

For the independent startup comparison, build
`integration_test/android_retained_startup_test.dart` with
`BUSYMAX_RETAINED_STARTUP_QA=true` and a `BUSYMAX_RETAINED_STARTUP_BUILD` label.
Run `python3 tool/android/check_retained_startup.py --device SERIAL --apk APK`
on an unlocked designated device with no BusyMax package installed. It verifies
the APK identity, uses a fresh evidence directory outside source, captures
retained WorkManager rows and errors, performs both phases with the same APK,
and restores the prior USB-awake setting/removes only its QA installation.
An actual baseline comparison needs `daee1df` and its own sibling revisions;
copy only the identical test entry point, never candidate product source.

The browser driver uses `BUSYMAX_NEXTCLOUD_BROWSER_LIFECYCLE=1`, the existing
`BUSYMAX_NEXTCLOUD_LOGIN_LIVE_*` HTTPS/credential/certificate variables and
`BUSYMAX_NEXTCLOUD_BROWSER_DRIVER`. That executable receives the actual browser
URL and must complete Login Flow v2 in an isolated normally validating browser.
`BUSYMAX_NEXTCLOUD_FIXTURE_CONTROL` names a Python driver for the disposable
server's change/count/offline/online controls. Never point these mutating/revoking
probes at a personal server/account.

References: [Dart connection factory](https://api.dart.dev/dart-io/HttpClient/connectionFactory.html),
[Dart callback semantics](https://api.dart.dev/dart-io/HttpClient/badCertificateCallback.html),
[Dart default trust](https://api.dart.dev/dart-io/SecurityContext/defaultContext.html),
[RFC 9525](https://www.rfc-editor.org/rfc/rfc9525.html),
[OWASP pinning guidance](https://cheatsheetseries.owasp.org/cheatsheets/Pinning_Cheat_Sheet.html),
[Flutter socket policy boundary](https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android),
[Nextcloud Login Flow](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/LoginFlow/index.html).
