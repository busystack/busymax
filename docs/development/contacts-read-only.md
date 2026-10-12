# Read-only contacts integration

BusyMax synchronizes and caches contacts for attendee suggestions and offline
lookup. It does not create, update or delete remote contacts, photos, Google
groups, Microsoft folders or DAV address books. Account enrollment, consent,
refresh, local disconnection/removal, source preferences and cache/cursor writes
remain supported. Calendar/task writes and invitations use their existing
provider permissions.

## Provider and storage boundaries

[`ReadOnlyContactsProvider`](../../lib/src/contacts/read_only_contacts_provider.dart)
wraps the shared `ContactsProvider` contract. It delegates discovery, paging,
retrieval, photo reads, reconciliation reads, action decoding and disposal.
It rejects contact mutations and provider actions before invoking its private
delegate. Native records, identities, revisions, cancellation and pagination
are preserved. Effective source capabilities disable contact/photo writes,
rename and remove while retaining read access and other source metadata.

[`BusyMaxContactsController`](../../lib/src/contacts/busymax_contacts_controller.dart)
applies the wrapper to provider bindings during startup, enrollment, reconnect
and removal recovery, including bindings from the injectable provider factory.
Its CardDAV provider also uses `readOnly: true`. Existing DAV configuration,
passwords and historical `carddav:write` markers remain readable; new enrollment
records the read-only configuration.

[`BusyMaxContactsStore`](../../lib/src/contacts/busymax_contacts_store.dart)
normalizes cached source capabilities in a Drift transaction before startup
restores the directory. Reads and subsequent source writes apply the same
policy, including for disabled sources and before online discovery. This
preserves account and contact IDs, records, selected sources, cursors,
preferences, generations and credentials without a schema change or data reset.

## Authorization

Contacts are optional. Initial calendar/task sign-in requests no contacts
permission. Explicit Google contacts enrollment requests only
`https://www.googleapis.com/auth/contacts.readonly`; desktop Microsoft requests
Graph-qualified `Contacts.Read`, while native MSAL uses its short form.
Historical full Google contacts and Microsoft `Contacts.ReadWrite` grants can
satisfy read access without new consent. Stored grants reflect the provider's
actual authorization; the read-only policy does not revoke those grants or
clear working refresh tokens.

Desktop reconnect/replacement carries previous contacts access forward as
read-only while retaining Calendar/Tasks, identity/offline access and enabled
Microsoft shared-calendar/category permissions. Google uses the installed-app
system-browser PKCE flow with the complete required scope set. Google refresh
remains scope-free. Microsoft refresh omits its optional scope parameter,
including during claims recovery, while preserving registration binding,
rotation, cooldown and generation fencing. Omitted returned scopes retain the
existing grant; explicit partial or revoked grants are honored.

The Android broker requests read-only contacts scopes for interactive and silent
authorization. Sufficient existing grants use silent acquisition with
subject/tenant/registration/generation checks. First optional enrollment commits
the actual native grants and contacts link through the existing credential
transaction; persistence failure rolls both back. Requested scopes are never
treated as evidence of a provider grant.

## Pending work and lifecycle

Contacts synchronization does not call `directory.resumeQueued`. Historic
queued, unknown and conflicting contact writes retain their IDs, payloads and
uncertainty evidence. Existing executing-to-unknown crash/removal handling and
unresolved recovery remain available. Startup, timers, manual synchronization,
reconnect and removal rollback do not dispatch historical contact writes.
Explicit new mutation attempts fail at the provider boundary.

Authorization persistence, account lock ordering and removal receipts retain
their existing roles. The lifecycle regressions exercise the production
persistence/lock chain, cancellation and drain ordering, conditional restoration,
detached bindings, generation fencing, unknown writes and shutdown.

## Settings and attendee lookup

Linux/Yaru, Windows/Fluent and Android Settings retain account/source controls
and platform routes. Contact editing actions, writable badges and DAV mode
switches are absent. Localized descriptions explain read-only attendee lookup.
Shared calendar/task editing strings remain available.

Attendee suggestions use source-qualified cached contacts, including offline.
Manual input, exclusions, limits, draft selections and stale-result fencing use
the existing implementation. Provider setup guides describe contacts as optional
and make no claim that historical grants were revoked or verification approved.

## Regression coverage

Follow [Development](../development.md) for the pinned toolchain, locked
dependencies, generated sources and offline checks. Contacts regressions cover:

- [Provider boundaries](../../test/contacts/read_only_contacts_provider_test.dart)
  and [cached state and journals](../../test/contacts/contacts_read_only_state_test.dart).
- [Desktop scope assembly](../../test/core/auth/contacts_authorization_requests_test.dart)
  and the existing Google/Microsoft OAuth transport tests.
- [Parent account lifecycle](../../test/contacts/parent_removal_lifecycle_test.dart)
  and authorization persistence/transition tests.
- Android broker, contacts enrollment, registration transition and platform
  channel tests under `test/platform/android/`.
- Platform Settings routes and attendee fencing under `test/platform/`.
- [Native Linux Settings](../../integration_test/contacts_read_only_linux_test.dart)
  with an isolated synthetic cache and XDG profile.

Automated regressions do not establish live provider authorization or installed
Windows/Android behavior. Record those checks separately. Keep per-run logs,
captures, command receipts and delivery manifests in ignored `build/` locations
or temporary directories, with a concise result in the relevant pull request.

## Provider contracts

- [Google People connections authorization](https://developers.google.com/people/api/rest/v1/people.connections/list)
  accepts read-only or full contacts authorization.
- [Microsoft Graph permissions](https://learn.microsoft.com/en-us/graph/permissions-reference)
  distinguish `Contacts.Read` from `Contacts.ReadWrite`.
- [Google installed-app authorization](https://developers.google.com/identity/protocols/oauth2/native-app)
  requires the installed-app flow rather than web incremental authorization.
- [Microsoft token refresh](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow#refresh-the-access-token)
  and [RFC 6749 section 6](https://www.rfc-editor.org/rfc/rfc6749.html#section-6)
  describe renewal when the optional refresh scope is omitted.
- [Google sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
  applies to the requested scopes and actual user-facing functionality.
