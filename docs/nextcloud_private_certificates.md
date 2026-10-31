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
| Full Flutter regression suite | 4,367 passed, 12 opt-in tests skipped |
| Final focused TLS/review suite | 41 passed, including critical-extension, signature-family and foreground-import regressions |
| Final contacts/onboarding/recovery selection | 163 passed, including existing-generation recovery and bounded snapshot history |
| Native Linux Flutter engine | All 26 actual TLS tests passed under a temporary X display and separate D-Bus session |
| Linux application | Debug bundle compiled |
| Android application | Debug APK compiled; no installation performed |
| Android native checks | 15 unit tests and app lint passed |
| First-party shared DAV / contacts | 82 / 119 tests passed; shared DAV static analysis passed |
| Static analysis, source formatting, platform boundaries | Passed |
| Localization and generated sources | Regeneration/reproducibility and localization audits passed |

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
| Explicit private CA | Five cases passed | Five cases passed |
| Explicit pinned self-signed leaf | Five cases passed | Five cases passed |

Each cell covers real discovery, calendar/task sync and conditional mutations,
task completion/reopening, pending-write replay, both contacts resource and
streaming transports, captured app-password revocation and subsequent rejection,
and Login Flow initiation/cancellation/pending polling. Both contacts identities
are explicitly provisioned with separate accepted policies. These are protocol
acceptance tests, not a claim of complete account-settings UI/browser acceptance.

The separate live sharing fixture reaches grants and permission changes but its
unshare-inventory assertion fails on Nextcloud 35.0.1: the recipient still sees
the collection in discovery after unshare. No complete sharing-suite pass is
claimed. TLS itself succeeds through that workflow; the full regression suite
continues to cover the existing administration/sharing/scheduling/import/trash
service routing through the account context.

Remaining acceptance gaps: no Windows native build/runtime was available, and
no Android device/emulator was attached for TLS or foreground/background
cross-engine acceptance. Browser trust was not provisioned in an isolated
browser, so complete browser authorization and subsequent account-controller
reconnect/revalidation/removal were not live accepted. The old browser-fixture
certificate-bypass flag was removed. Live scheduling delivery, import/trash and
federation were not exercised. Native Linux tests establish the bundled Linux
engine boundary; release-package/OS trust-store matrices and platform assistive
technology/manual keyboard checks remain open. Widget keyboard/narrow-layout
checks do not replace those checks. No universal OS private-root visibility,
revocation checking, or unverified-first-use identity guarantee is claimed.
No user BusyMax installation/profile was changed.

The installed Flutter source tree has a pre-existing modified `pubspec.lock`
(September 29, 2026); the ordinary installed-SDK integrity check reports it.
It was not repaired or modified. A pristine local checkout of the exact official
revision using the same cached runtime passed `verify_upstream_packages.py`,
including 1,171 SDK/runtime files and all eight catalogued upstream packages.
No Flutter/Dart/TLS/dependency source was patched or distributed.

Run the focused suite, then the full applicable Flutter suite, static analysis,
platform boundaries, generated-source reproducibility, shared DAV/contacts
tests, upstream integrity and native builds. Keep execution logs outside source.
The existing live Login Flow, calendar/task and sharing suites now use the
production factory. For each suite's environment prefix, set `TRUST_MODE` to
`standard`, `private_ca`, or `pinned_leaf`; private modes additionally require
`TLS_CERT` pointing to explicitly approved disposable certificate material.
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
