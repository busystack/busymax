# OAuth transition implementation and validation handoff

Work is uncommitted in BusyMax. The starting Git revision was
`5986de8f07a9845826dbf5a27cfae34be2c3dd16`; the working tree was clean when work
started. No other BusyStack repository, external registration, project quota or
published application was changed. This is a migration release: shared
registrations are retained for eligible existing accounts.

## Transition behavior and platform setup

| Platform/provider | New connection | Eligible existing connection |
|---|---|---|
| Linux/Windows Google | Imported user-provided installed Desktop JSON | Original client refresh/reconnect; targeted replacement |
| Linux/Windows Microsoft | Public client ID and validated audience/tenant | Original client refresh/reconnect and optional consent; targeted replacement |
| Android Microsoft | Registration-specific native MSAL, multiple accounts | Original native binding continues; targeted native replacement |
| Android Google | Approved native Google Identity Services | Native operation retained; no Desktop importer or retirement notice |

Typed registration origin is separate from connection health. The database
upgrade snapshots pre-existing accounts before onboarding; legacy desktop
binding is established only using the known original registration and validated
provider identity. Unknown provenance and corrupt/unknown versions retain their
records and data and report an explicit problem. A token-derived Google local
ID stays unchanged when its independently verified subject is established.

New-account paths require configuration and cannot silently use compiled shared
values. Known retiring clients cannot be disguised as user-provided migration.
Successful replacement has no switch back. Neither time-based expiry nor remote
retirement is added. Protected original build inputs remain in the transitional
release paths. See the exact [next-release removal checklist](oauth_next_release_checklist.md),
including the Google Android Cloud-project dependency that must remain intact.

The Google importer reads a regular local file in the authentication layer, with
64 KiB size and bounded/cancellable reads, snapshots it, and gives widgets an
opaque single-use handle and safe summary. Installed Desktop configuration is
required; imported endpoint/redirect fields are ignored. PKCE/state, browser
loopback, identity scopes, Tasks and Calendar remain. Microsoft setup accepts
only supported public client/audience/tenant values, fixed Microsoft endpoints
and no secret. Android derives redirect/package/signature values from the
installed identity and validates its manifest; native caches and refresh tokens
remain with MSAL/GIS.

[Google help](google_setup.md) and [Microsoft help](microsoft_setup.md) are packaged
assets and linked from setup. Normal onboarding removes the migration-specific
sections. Official documentation was checked; authenticated Console/Entra portal
walkthroughs were not performed or claimed.

## Account and data safety

New connection, reconnect and registration replacement are explicit intents.
Candidates pass required/offline permission checks and provider subject or
Graph-user/actual-tenant checks before persistence. Reconnect/replacement keeps
the existing primary key. New sign-in cannot replace an existing identity's
registration. Login hints and email are not identity checks.

Versioned provider-specific secure records hold desktop credentials and issuing
registration together. Native records contain only registration/account
bindings. Compatibility token helpers preserve bound fields. Secure writes,
native alias updates and SQLite metadata changes use a recoverable journal and
serialized account boundary, with verified rollback and restart recovery.
Rollback captures the latest accepted record, including token rotation.
Microsoft reads enabled-domain preferences inside the commit, so changes made
during a secure write survive.

Normal refresh retains authorization generation; replacement/removal advances
it. Establishing a previously missing original binding also retains the
generation, so a normal refresh during browser consent does not invalidate the
candidate. A versioned commit receipt is written in the same SQLite transaction
as account metadata, allowing restart recovery to distinguish a committed
same-generation binding upgrade from an interrupted credential write.
Stale commits, refresh results and failure side effects are rejected.
Recoverable reconnect state does not sign Microsoft out or delete credentials,
native aliases or reminders. Failed/cancelled/wrong-account/missing-permission
replacement preserves the working account. Native cache removal is limited to
the selected account and occurs after account deletion commits.

Native Microsoft silent requests capture the secure record's registration,
native account and authority. MSAL results expose the authenticated tenant rather
than inferring it from the configured audience or root account authority.
Generation, native-account and actual-tenant checks precede accepting a result;
an original-client result completing after replacement is discarded.

Fault and barrier tests cover secure-write failure, database failure after a
credential write, recovery journals, concurrent rotation/consent, removal,
provisional credential readers, stale failure state and preferences changed at
the write boundary. Other account tables, pending changes, collection choices,
cached events and task data are retained; migration does not remove/re-add an
account. Apple, Nextcloud and WebCal retain their existing formats and paths.

## Warning targeting

Linux/Yaru, Windows/Fluent and Android settings consume one predicate from the
actual secure binding plus pre-existing transition eligibility. Each account
has independent notice state. Migrate opens setup for that account; reconnect
uses its current registration and remains available this release. Cancellation
keeps the connection and notice. Successful migration removes that account's
notice immediately and after restart. New/user-provided accounts and native
Android Google do not receive retirement prompts. Regression widgets exercise
mixed Google/Microsoft accounts, cancellation/retry and restart.

## Synchronization and retry measurements

The 15-minute scheduler and WorkManager wakeups remain. Persisted per-account,
per-domain state separates successful pull, passive eligibility and provider
cooldown, inside existing foreground/headless coordination gates. Tasks passive
eligibility is one hour plus one sampled 0–10% jitter; Calendar is 15 minutes
plus jitter; the periodic wake can add up to 15 minutes, with further delay from
the operating system, offline periods or cooldowns. Resume uses 15-minute
freshness. Manual requests stay incremental,
local writes dispatch promptly in their own domain, and cooldowns override
remote attempts. Tasks failure does not prevent Calendar work. Cached eligible
reminders continue during deferred remote work.

Measured production-client/engine requests on synthetic fixtures: quiet pulls
with 1/5/20 collections use 2/6/21 reads, three intervening ineligible wakes use
zero reads, changed pagination uses four reads, and one local creation uses one
POST without a passive collection poll. Overlapping foreground/background
requests consume one eligible pull. Checkpoint overlap, pagination, pending-edit
protection and cursor recovery remain. See [budget calculations and freshness
tradeoffs](synchronization_budget.md). These are request-budget evidence for a
possible Android quota request, not live telemetry, approval or demonstrated
project isolation.

Safe-read retries honor existing Retry-After parsing, Google quota-specific 403,
429 and transient 5xx, bounded attempts/deadlines and cancellation. Long provider
cooldowns are persisted without shortening. Mutations are not automatically
HTTP-replayed; durable replay retains uncertain-commit protection and retry
timing. Token-service 429/5xx cannot become revoked authorization because of a
misleading body. Conclusive invalid grants and rejected client configuration
have separate safe classifications.

## Automated and build validation

Host: Ubuntu 24.04.5 LTS, Linux x64. Approved Flutter 3.47.5, framework
`6a19cca564`, engine revision `af7e796e16`, bundled Dart 3.13.4, DevTools 2.60.0.
Android used installed Temurin JDK 25.0.1, pinned Gradle 9.4.1, API 37 and Build
Tools 37.0.0. No SDK/dependency/runtime/project pin was downgraded. Lockfile changes
only make the already-locked file_selector_platform_interface a direct test
dependency; version and checksum remain unchanged.

Final counts and artifact hashes are recorded in the sanitized
[machine-readable evidence](validation/oauth_transition_evidence.json).
The final full suite result is **3,158 passed, 10 skipped, zero failures**. Localization and Drift
regeneration are reproducible, formatting reports zero changes, analysis reports
no issues, and platform boundaries pass. The same checks and full suite were
run from a fresh source extraction. An earlier concurrent run had one existing
Calendar timeout; it passed in isolation and the full suite passed with controlled
concurrency. No test was disabled or timeout raised to hide it.

Android native Kotlin JUnit: 10 tests, zero failures/errors/skips; lint passes.
Linux native checks: seven executables pass, plus AddressSanitizer and allocation/
locale variants. GTK header-icon integration: one pass. Actual Linux secure
storage: one pass using an isolated temporary unlocked keyring, after the default
keyring service was unavailable. Native file-dialog automation timed out twice
and remains unverified.

Linux release builds pass both without shared values and with synthetic original
build inputs; expected fixture values are absent/present respectively and both
guides are packaged. Android APK and AAB builds pass in both modes, explicitly
test-signed with the existing debug identity. Original MSAL resources are retained
only in the transitional mode. APK signatures, package/manifest values, ELF 16 KB
LOAD alignment and zip alignment pass. Supplementary cached bundletool 1.18.3
inspection confirms PAGE_ALIGNMENT_16K for both AABs; the existing inspector's
initial no-bundletool warning is superseded by that separate inspection.

These synthetic registration builds prove build/runtime routing boundaries,
not the validity of a real official shared grant or a production signing identity.
Windows workflow/package-script contracts are tested in Dart; Windows native
builds, Pester/MSIX/WACK, actual Windows file selection/storage, and Snap packaging
were not executed on this host. Android device registration-specific MSAL checks
remain pending: the attached device was ADB unauthorized, and nothing was installed.

## Commands and source handoff

All commands run from BusyMax or its fresh extraction, using the approved SDK:

```bash
export BUSYMAX_FLUTTER_EXECUTABLE=/home/albert/flutter/bin/flutter
export JAVA_HOME=/home/albert/.sdkman/candidates/java/25.0.1-tem
export ANDROID_SDK_ROOT=/home/albert/Android/Sdk
export PATH="$JAVA_HOME/bin:/home/albert/flutter/bin:$PATH"
BUSYMAX_TEST_CONCURRENCY=4 tool/android/verify.sh
```

The fresh extraction also ran these commands explicitly, including unchanged
source hash verification before and after tests:

```bash
sha256sum --check --status SOURCE_SHA256SUMS
flutter pub get --enforce-lockfile
dart run tool/check_generated_sources.dart snapshot /tmp/busymax-fresh-generated-snapshot
flutter gen-l10n
dart run build_runner build --force-jit
dart run tool/check_generated_sources.dart verify /tmp/busymax-fresh-generated-snapshot
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run tool/check_platform_boundaries.dart
flutter test --concurrency=4
sha256sum --check --status SOURCE_SHA256SUMS
```

Release and selected native commands:

```bash
flutter build linux --release -t lib/main_linux.dart
flutter build linux --release -t lib/main_linux.dart \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=transition-fixture.apps.googleusercontent.com \
  --dart-define=GOOGLE_OAUTH_CLIENT_SECRET=synthetic-build-secret \
  --dart-define=MICROSOFT_OAUTH_CLIENT_ID=22222222-2222-2222-2222-222222222222
tool/android/test_registration_modes.sh
android/gradlew --project-dir android :busymax_android_platform:testDebugUnitTest :app:lintDebug
dbus-run-session -- flutter test integration_test/gtk_header_icons_integration_test.dart -d linux
```

Native storage additionally used a private D-Bus session with XDG data/config/
cache/runtime paths and keyring control directory under a task-created `/tmp`
directory. Inside it, `printf '\n' | gnome-keyring-daemon --unlock
--components=secrets --control-directory="$BUSYMAX_NATIVE_KEYRING_CONTROL"`
preceded `flutter test integration_test/native_registration_storage_test.dart
-d linux --plain-name 'native secure storage preserves registration on routine refresh'`.
Native unit compilation uses the existing Linux CI's `g++ -std=c++17 -Wall
-Wextra -Werror` commands and installed GTK/GIO; no native tool was installed.

Create the handoff with:

```bash
python3 tool/create_source_handoff.py \
  --output build/handoff/busymax-oauth-transition-source.tar.gz
```

The archive contains source, all required assets/generated files, guides,
synthetic fixtures and this evidence. It excludes Git metadata, local private
configuration, signing material, caches, binaries and raw OS/provider logs.
`SOURCE_SHA256SUMS` inside the archive covers every source file; the adjacent
`.sha256` sidecar identifies the archive itself. Artifact hashes in the evidence
identify the locally built test releases. Imported real configurations/tokens
were never supplied or packaged. A second identical archive generation verifies
reproducible handoff bytes.

## Live checks and external execution gaps

No authorized real Google/Microsoft registration/account inputs were supplied.
Consequently live initial setup, original shared refresh, browser migration,
real refresh, Calendar/Tasks reads and optional Microsoft consent were not
executed. No provider writes occurred. Deterministic tests cover these paths
with production services and synthetic transports/storage, including two clients
and account-specific selection; they are not presented as live project isolation.

Before distribution, finish those live checks with designated disposable inputs,
Windows native/package checks, manual native file selection, and correctly
production-signed Android/device validation. These are explicit execution gaps,
not permission gates, claims of successful external testing, or instructions to
remove the shared registrations now.
