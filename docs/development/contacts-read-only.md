# BusyMax contacts are read-only attendee lookup

Implemented the owner's approved product policy. BusyMax synchronizes and caches contacts for attendee suggestions and offline lookup. It does not create, update or delete remote contacts, photos, Google groups, Microsoft folders or DAV address books. Contact account enrollment, consent, refresh, local disconnection/removal, source preferences and cache/cursor writes remain supported. Calendar/task writes and invitations retain their existing authorization and providers.

The live starting point was `fix/contacts-read-only` at `42dd355454cfc5e86bd10f0c58ea786267f20b5f`, with no staged, unstaged or untracked work. No owner instruction files were found in BusyMax or its ancestor directories. [Baseline evidence](evidence/contacts-read-only/baseline.json) records sibling heads and pre-existing BusyCards IDE/cache work. The supplied archive identifies `788e8a8e4be563eecddc45f8f783e02e315ae0e2`, SHA-256 `e4830832d85d210df33fa459a8ec9623fd9eed1cbbb1c5ab6d06fc7da9b4dd86`; its static report was not treated as an executed test run of this correction.

## Integration boundary

`ReadOnlyContactsProvider` implements the existing public `ContactsProvider` contract. It keeps its concrete delegate private, delegates discovery, paging, retrieval, photo reads, create reconciliation reads, action decoding and disposal, and rejects `create`, `update`, `delete`, `setPhoto` and every provider action before calling the delegate. It preserves native contact records, identities, revisions, cancellation and pagination. Effective source capabilities disable create/update/delete/photo-write, rename and remove; read/photo-read and all other metadata retain their original values, including server-unreadable sources.

`BusyMaxContactsController._bindProvider` applies this boundary to every `_bind` route, including the injectable factory, startup, enrollment, reconnect and removal recovery. The factory is private after construction. `_davProvider` also constructs CardDAV with `readOnly: true`. Stored OAuth grants remain actual provider grants rather than fabricated read-only sets. Old DAV configuration/passwords and `carddav:write` markers remain readable; only new DAV enrollment records the constant read-only configuration. Existing mode selection arguments and the Google contacts client's writable field were removed.

`BusyMaxContactsStore` uses the existing Drift transaction to normalize cached source capabilities at startup before directory restoration. Reads and future source writes apply the same effective policy, including before online discovery and for disabled sources. IDs, records, source selection, cursors, preferences, account generations, credentials and schema 20 remain intact. No Drift regeneration, schema bump or data reset is needed.

## Requested and granted authorization

Contacts remain optional. First calendar/task sign-in requests no contacts scope. Explicit Google contacts enrollment requests only `https://www.googleapis.com/auth/contacts.readonly`; desktop Microsoft requests Graph-qualified `Contacts.Read`, and native MSAL uses the short representation. Already granted full Google contacts or Microsoft `Contacts.ReadWrite` permission satisfies read access without write consent or a new browser. Recognition of historical write grants is separate from outgoing scope assembly.

Desktop reconnect/replacement requests carry previous contact access forward as read-only and retain base Calendar/Tasks, identity/offline access and enabled Microsoft shared-calendar/category scopes. Google keeps the installed-app system-browser PKCE full-required-set flow; it does not use web incremental authorization. Google refresh remains scope-free. Microsoft refresh now omits its optional scope parameter, including claims recovery, while retaining the issuing registration, rotation, returned-grant parsing, cooldown and generation fencing. Omitted returned scopes retain the existing grant under the renewal contract; explicit partial/revoked grants are honored. No local policy change revokes an existing provider grant or clears a working refresh token.

The real Android broker sends read-only contacts scopes for interactive and silent requests. Existing sufficient native authorization uses silent acquisition, checks the actual result and preserves subject/tenant/registration/generation fencing. First optional enrollment persists accepted actual native grants before validating the contacts link, inside the existing native credential commit. Persistence failure rolls the grant/link back together. Requested scopes are never concatenated into a fictitious token grant. Existing optional native calendar/category access is carried into explicit reconnect/replacement. The Kotlin bridge already accepts supplied scope lists and returns provider-reported scopes; no new allowlist or bridge change was necessary.

The resolved native artifacts were inspected: Google `play-services-auth:21.5.0` exposes `getGrantedScopes(): List<String>` and `setRequestedScopes(List<Scope>)`; MSAL `8.4.1` exposes `getScope(): String[]`. Artifact hashes and `javap` output are retained with delivery evidence. No SDK, runtime, dependency or registration versions changed.

## Journals and lifecycle

BusyMax no longer calls `directory.resumeQueued` during synchronization. Queued, unknown and conflicting entries retain their IDs, payloads and uncertainty evidence. Existing executing-to-unknown crash/removal handling remains in the shared directory, with unresolved recovery still actionable through the existing reconnect/removal state. Startup, timer, manual sync, reconnect and removal rollback do not dispatch historic contact writes. Explicit contact mutation attempts fail at the integration boundary; the shared directory may record a newly attempted provider action as failed, while existing journals are preserved.

AuthRepository, AuthorizationPersistence, C1 lock ordering and C2 removal receipts were preserved. The actual LifecycleFixture still includes its production persistence/lock chain. Tests retain original enabled/disabled/absent state, cancellation/drain ordering, conditional restoration, detached-binding recovery, newer-generation fencing, unknown writes and shutdown assertions.

## Settings and localization

Linux/Yaru, Windows/Fluent and Android Settings retain account/source controls and platform routes. Editing/upgrade actions, writable badges and DAV mode switches were removed. Every supported locale contains a contacts-specific read-only attendee description, and the three unused editing keys were removed through normal `flutter gen-l10n`. The generic Portuguese alias remains empty; the existing European Portuguese locale carries its translation. Shared calendar/task editing strings remain. Manual attendee input, source-qualified cached suggestions, exclusions, limits, draft selections and stale-result fencing use the existing implementation. The embedded provider setup guides label contacts as optional and make no claim that prior grants were revoked or verification approved.

## Verification and delivery

Use the unchanged Flutter 3.47.5 and bundled Dart 3.13.4 pins verified by `tool/verify_flutter_sdk.dart`; `tool/shared_dependencies.json` retains contacts `cf399b9af0b7bf8a315e8c5d6123e601c90b7bd2`, DAV `18f636f3227e3df8c1406bafd85b45e7f12cf8bd` and Graph `6572ee14ae992d4cd4f8c2218babaff5051bc132`. Sibling repositories are read-only dependencies; their checkout helper was inspected and not run over owner working trees.

Commands and full logs are recorded under `build/contacts-read-only` and included in the delivery evidence archive. Command receipts retain their actual exit status, duration, head/tree and source fingerprint. The delivery manifest records the final commit/tree, archive and per-file checksums. Source uses the existing `python3 tool/package_source.py` sibling layout and contains the unchanged pinned dependency inputs. Linux release packaging preserves its native helper/assets. Extraction receipts verify both manifests, the relative dependency layout and locked offline resolution. The pre-existing source archive was preserved under `build/contacts-read-only/preserved-source-input` before replacing the packaging output; its revision is unverified and it is not presented as this correction.

Targeted regressions include the existing contacts/store/enrollment/removal, authorization/consent/credential persistence, actual platform Settings routes and attendee fencing tests; additions inspect actual desktop authorization URLs, real Android broker method-channel scopes/native commits, shared-provider transports under broad grants, cached schema-20 state and journal preservation across startup/timer/reconnect/removal rollback. The final evidence also records normal localization generation, touched-file formatting, `git diff --check`, `flutter analyze`, `dart run tool/check_platform_boundaries.dart`, the full BusyMax Flutter suite, Linux debug/release builds, available native workflow checks and an isolated native Linux Settings session with a synthetic cache and screenshot.

The final application and test inputs are commit `4a4bd5528725fe1eca067099a9671ced9e4a745a`, tree `e0e1c52405d73f26a259ecd59cff8f6ee48863f2`, source fingerprint `8d968885e8e340d57aa5ee640f865ef3ed6c0aff6a2110f873b7bd4781c93dd6`. Subsequent changes contain development evidence only; the delivery manifest identifies that final documentation commit and proves identical tested inputs. [Verification record](evidence/contacts-read-only/verification.json) includes exact commands, exit statuses, durations, log hashes and skip names.

| Gate | Measured result |
| --- | --- |
| Locked resolution, localization generation, touched-file formatting, diff check, analysis, platform boundaries | Passed |
| Complete BusyMax Flutter suite | 3,619 passed, 10 live-provider skips, 0 failures |
| Affected cases within that final complete run | 435 passed, 0 skips |
| Corrective locale and linked-DAV focused run | 42 passed |
| Native Linux workflow checks and debug/release builds | Passed on the recorded Linux host |
| Real isolated Linux Settings session | 1 passed; synthetic offline cache, source selection, dialog and screenshot |
| Android bridge native unit tests and app lint | 11 tests passed; lint passed; unchanged native inputs checked across the correction |
| Independent Android test-signed APK/AAB builds and inspection | Passed; signatures, notification resources, 16 KB ELF segments and APK zip alignment checked |

The first complete run caught the generic Portuguese alias regression (3,617 passes, 10 skips, 1 failure). It was corrected without changing supported locales, and the complete suite was rerun. An initial Android release build in the shared build layout failed because the generated registrant referenced the dev-only integration plugin without its release dependency. The independent temporary source/sibling layout resolved that build failure without changing pins or generated source manually. Both diagnostic logs remain in the evidence archive. Newly built Android files are labeled test-signed and were never installed.

Native Windows builds/device acceptance require a Windows host; Fluent route tests are not native acceptance. Android on-device acceptance and live-provider tests are unverified: no device installation, disposable accounts or registrations were authorized. AAB bundletool alignment metadata remains unverified because no local bundletool jar is available; the other recorded artifact checks passed. Historical Windows/Android/Snap/offline artifacts are not relabeled as builds of this correction. Unchanged Snap/engine/driver qualification was not restarted.

## References checked 11 October 2026

- [Google People connections authorization](https://developers.google.com/people/api/rest/v1/people.connections/list): accepts readonly or full contacts authorization.
- [Microsoft Graph permission meanings](https://learn.microsoft.com/en-us/graph/permissions-reference): `Contacts.Read` reads; `Contacts.ReadWrite` also includes mutations.
- [Google installed-app authorization](https://developers.google.com/identity/protocols/oauth2/native-app): PKCE and full-set reauthorization; installed-app incremental authorization is unsupported.
- [Microsoft refresh parameters](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow#refresh-the-access-token) and [RFC 6749 section 6](https://www.rfc-editor.org/rfc/rfc6749.html#section-6): optional refresh scope omission renews existing authorization.
- [Google sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification): scope access must match actual user-facing functionality.
