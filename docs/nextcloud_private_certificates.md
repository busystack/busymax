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

Contacts-only enrollment reviews a different canonical server separately from
the entered login server. Consent to the canonical URL does not transfer a
private-certificate exception. A private canonical server requires a second
certificate review scoped to that installation, before contacts credentials
are committed. Rejecting or cancelling either review leaves no enrolled account.

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

DAV requests acquire shared authorization leases; replacement, removal and
recovery acquire exclusive leases. FIFO ordering prevents a waiting writer
from being starved by later readers. Android uses a fair native multi-permit
semaphore shared by foreground and background engines; executor thread identity
does not own the lease. The local gate uses the same ordering. Credentials and
policy are selected and checked inside the lease, before any transmission.
Secure-storage staging and SQLite journal commits remain exclusive.

Each account request owns its TLS client, without idle connections surviving
its lease. A response releases ownership on EOF, error, cancellation or client
disposal. Lease acquisition has its own two-minute timeout. After acquisition,
the active request has a fresh two-minute lifetime, matching the default DAV
operation budget and covering stalled connections, paused bodies and bodies
that are never subscribed. The transport's operation deadline and cancellation
can terminate either phase sooner. Native clients are terminated before lease
release. Authorization writers may wait up to 150 seconds on Android, allowing
an active reader's two-minute budget plus cleanup. No request is replayed after
a generation change. A failure after mutation dispatch still requires reconciliation.

A replacement drains existing readers before invalidating local factory clients
and committing the new generation. Other engines cannot acquire a new reader
until that writer releases; they read durable credentials afresh. No cached
connection can cross a policy generation. Removal revokes with its captured
immutable secret and policy after local commit. Failed replacement retains the
previous policy and cached data. iCloud shares only this authorization lifecycle;
its client uses ordinary system HTTPS and never selects Nextcloud trust policy.

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

TLS closure before a validated socket is available is a network failure with
pre-dispatch evidence. Observed certificate rejection retains its certificate
failure classification. Loss after dispatch retains unknown-outcome reconciliation.

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

## Developer verification

Use the official SDK and pinned shared revisions described in
[Development](development.md). The disposable OpenSSL fixture creates keys only
in the operating system temporary directory; it never installs trust anchors.

```bash
flutter test test/dav/trust/nextcloud_private_tls_test.dart
flutter test test/core/auth/authorization_transition_test.dart
flutter test test/contacts/nextcloud_certificate_lifecycle_test.dart
flutter test test/platform/android/android_platform_channel_test.dart
```

The real socket regressions cover private CA renewal, exact-leaf replacement,
SAN identity, account/origin/port isolation, pre-dispatch rejection and bounded
cancellation. Authorization regressions cover journal rollback, restart recovery,
stale generations and captured removal credentials. Platform presenters must
retain explicit rejection as the initial action, selectable certificate details,
large-text support and no implicit approval.

Android startup coordinates database writers and notifications through the
existing native gates. Retained-worker tests must exercise overlapping engines,
process restart and certificate recovery with the isolated QA package. Run native
TLS and workflow targets on Linux, Windows and Android as described in
[Development](development.md); widget tests alone do not establish native TLS,
browser trust or provider delivery. Keep per-run evidence outside tracked source.
