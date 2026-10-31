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

Verification on October 30, 2026 (Vancouver):

| Check | Actual result |
|---|---|
| Final standalone full Flutter suite, explicitly selected official SDK | **4,383 passed, 15 opt-in tests skipped, 2 failed** (Android notification coordination; details below) |
| Focused contacts/TLS/authorization selection | 202 passed |
| New contacts findings regressions | 18 passed, including real TLS recovery, startup, disk restart, malformed marker/envelope/policy records, expiry and cached contacts |
| Native Linux Flutter engine | All 26 actual TLS tests passed under a temporary X display and separate D-Bus session |
| Linux application | Debug bundle compiled |
| Android application | Debug APK compiled; no installation performed |
| Android native checks | 15 unit tests and app lint passed |
| First-party shared DAV / contacts | 82 / 119 passed respectively; **zero failures or skips in either package**; both static analyses passed |
| Static analysis, source formatting, platform boundaries | Passed |
| Localization and generated sources | Localization/database regeneration and source-snapshot reproducibility passed; existing localization regressions included in full suite |
| Upstream integrity | Default check passed eight protected dependencies and 1,171 SDK/runtime files; 29 verifier regression tests passed |

An intermediate full run reported 4,384 passes, 15 live skips and one unchanged
Windows startup-activation widget failure: its real-time wait did not observe
the import dialog. The unchanged 16-test file passed on immediate rerun. The
final standalone full-suite result is recorded here separately; no startup
implementation, assertion or timing limit was changed. An unrestricted
`dart format .` also found six old generated listeners under ignored
`build/pr37-runtime-tmp`; formatting all 795 maintained Dart files passed without
changes. Generated listeners were not edited or treated as source failures.

The final full run's two failures are
`android_notification_reconciliation_test.dart`: **independent old runtime
cannot restore private**, for native-call-in-flight `false` and `true`.
The first timed out after 30 seconds; teardown then removed its settings file
while an asynchronous save remained outstanding, producing a rename failure.
The following case encountered a platform-channel null-value error. These
notification tests do not exercise Nextcloud TLS. No notification implementation,
test assertions or timeout was changed. The earlier full run before adding the
extended live cases passed 4,385 tests with 12 skips; that earlier pass does not
override the final failures. The unchanged notification file passed all **64**
tests on isolated rerun, including both failing cases. This establishes an
intermittent full-suite failure, not a repaired or accepted notification path.
The default integrity check passed again after the full run with the selected
official SDK retained.

The Android test-only Mockito dependency was upgraded to upstream 5.24.0 because
5.0.0's bundled instrumentation cannot run on this host's supported Java 25.
No SDK or dependency was downgraded or patched.

Live protocol tests used an isolated official Nextcloud 35.0.1 container with
Calendar 6.6.4 and Tasks 0.18.1, fresh QA users/app passwords, and a temporary
loopback TLS reverse proxy. Server installation, app installation and fixture
settings used supported administration commands. Authentication-delay protection
was disabled and the calendar-creation quota raised only in this disposable
instance so deliberate failed-credential/repeated-creation tests could run.
Client account URLs always used HTTPS. No CA was installed in an OS/browser
store; all keys and execution logs stayed outside tracked source.

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

The new opt-in `nextcloud_extended_live_test.dart` exercises the actual persisted
account client, authorization journal, import queue/replay, trash service and
scheduling service against HTTPS. Native import was observed to queue, commit
and read back. Trash stops with `DavTrashUnsupported` because discovery does
not advertise `nc-calendar-trashbin`; free/busy stops with `DavFreeBusyDenied`
at the existing scheduling-policy check. Restoration, permanent deletion,
invitation/reply delivery and inbox completion therefore remain unqualified.
These are recorded failures, not mocked passes or evidence that the guarded
operations work. Both failures reproduce against the unchanged pre-feature
standard-HTTPS product/DAV baseline, with native import passing there. They are
existing service/discovery interoperability gaps, not private-TLS regressions;
the affected product services were not changed in this correction.
One import rerun under load also timed out with
`DavUnknownMutationOutcome`; that attempt has an uncertain result, not a
certificate-failure classification. Later serial reruns are recorded below.
Server-restart preparation initially rejected an underscore in the disposable
member name; using the existing permitted name grammar fixed the fixture input.
Docker then reassigned its dynamic backend port on restart. Restoring that
fixture-only loopback route preserved the front HTTPS origin and certificate;
durable rediscovery, update and deletion passed after the actual restart.

Remaining acceptance gaps: no Windows VM/native runtime was available. ADB
reported no attached Android device/emulator; an API 35 emulator image/AVD is
present, but no current BusyMax build was installed, as requested. Android
device TLS, certificate-management UI, background/foreground coordination and
recovery therefore remain unqualified. The isolated installed Chrome 156
profile still reported `NET::ERR_CERT_AUTHORITY_INVALID` after attempts at
normal certificate-manager provisioning; no bypass or user/system trust-store
change was used. Complete browser authorization and subsequent account-controller
reconnect/revalidation/removal were not live accepted. Federation requires a
second reachable Nextcloud peer and has not been exercised. Certificate
replacement/removal races, concurrent clients, credential isolation and stale
approvals pass the real-TLS/authorization regression suites; that is not a claim
of complete device/UI account-lifecycle acceptance. Native Linux tests establish
the bundled Linux engine boundary; release-package/OS trust-store matrices and
platform assistive technology/manual keyboard checks remain open. Widget keyboard/narrow-layout
checks do not replace those checks. No universal OS private-root visibility,
revocation checking, or unverified-first-use identity guarantee is claimed.
No user BusyMax installation/profile was changed.

The previous SDK discrepancy came from a pre-existing modified `pubspec.lock`
in `/home/albert/flutter`. That tree remains untouched. This follow-up actually
selects `/tmp/busymax-official-flutter-6a19cca`, pristine official Flutter
`6a19cca56475dbfba1478ee68d7bd0c2ef891da1`, for `pub get --enforce-lockfile`,
tests, analysis, code generation and native checks. Direct Dart commands also
set `FLUTTER_ROOT` to that checkout: otherwise the shared cache's physical path
can cause Dart's automatic package resolution to reselect the older SDK.
This reselection was caught by a failing integrity recheck and corrected before
the final standalone run. Package resolution and
Android `flutter.sdk` point at that checkout. The ordinary integrity command
passes **without `--sdk` override**, checking the selected source and verified
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
| Complete browser Login Flow | Blocked by isolated browser trust provisioning; no bypass used |
| iCloud semantics and iCloud atomic lifecycle (two cases) | Outside this Nextcloud change; no disposable iCloud credentials supplied, not rerun |
| Native import (new extended case) | Passed alone in all four private-mode/root/subpath cells; one loaded rerun timed out with unknown outcome |
| Trash restore/permanent deletion (new extended case) | Failed at `DavTrashUnsupported`; guarded operations unqualified |
| Scheduling free/busy and inbox (new extended case) | Failed at `DavFreeBusyDenied`; inbox/delivery unqualified |

Release recommendation: **NO-GO** until Windows and Android device acceptance,
complete browser/account lifecycle, scheduling/trash interoperability and
federation are qualified, and the intermittent full-suite notification failures
are resolved. Passing Linux/unit/widget tests or APK compilation
does not close those gaps.

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
locks and 500 responses, which disappeared on serial rerun. Do not run other
build/test/generation jobs against the same checkout during final acceptance.
Run both private modes at the root and at a subpath, and record browser,
discovery, sync, mutations, completion, reconnect and revocation results before
making release interoperability claims. Never use personal accounts for these
mutating/revoking fixtures.

References: [Dart connection factory](https://api.dart.dev/dart-io/HttpClient/connectionFactory.html),
[Dart callback semantics](https://api.dart.dev/dart-io/HttpClient/badCertificateCallback.html),
[Dart default trust](https://api.dart.dev/dart-io/SecurityContext/defaultContext.html),
[RFC 9525](https://www.rfc-editor.org/rfc/rfc9525.html),
[OWASP pinning guidance](https://cheatsheetseries.owasp.org/cheatsheets/Pinning_Cheat_Sheet.html),
[Flutter socket policy boundary](https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android),
[Nextcloud Login Flow](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/LoginFlow/index.html).
