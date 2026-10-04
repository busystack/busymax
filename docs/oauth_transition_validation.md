# OAuth transition corrections and validation

This report concerns the F1–F5 corrections on top of
`089afdeb3c55555275c80e7c5b613ecb582b4f30`. The starting tree was clean; the
corrections remain uncommitted. No other BusyStack repository, external app
registration, quota, signing identity, or published application was changed.
The earlier transition report's 3,158-pass result is historical evidence only.
It does not validate these corrections and is not the final result below.

## Transition behavior and setup

| Platform/provider | New connection | Eligible existing shared connection |
|---|---|---|
| Linux/Windows Google | User-owned installed Desktop JSON | Original registration refresh/reconnect and targeted migration |
| Linux/Windows Microsoft | Public client ID and supported audience/tenant | Original registration refresh/reconnect, optional consent and targeted migration |
| Android Microsoft | Registration-specific native MSAL | Original eligible native binding and targeted native migration |
| Android Google | Approved native Google Identity Services | Native registration preserved; no Desktop importer or retirement notice |

Shared registrations remain available only to eligible existing accounts. No new
shared shortcut, fallback, time-based retirement, or switch back was added.
Ownership remains separate from connection health. The warning uses the actual
binding and transition eligibility, independently per account. Failed or
cancelled replacement preserves the warning; successful migration removes it.
The [next-release checklist](oauth_next_release_checklist.md) still distinguishes
retiring Google's desktop client from its Android Cloud-project dependency.

Scopes, PKCE/state, fixed provider endpoints, account IDs, provider-identity
validation, native token ownership, generation rules, recoverable commits and
latest-record rollback remain. Google Tasks and Calendar remain enabled together;
Microsoft optional scopes remain feature-triggered. Apple, Nextcloud and WebCal
retain their existing paths. [Google](google_setup.md) and
[Microsoft](microsoft_setup.md) setup help remains packaged and linked.

## Root causes, production corrections and regressions

Every finding was reproduced before its fix. Inputs are synthetic network and
storage responses; decisive tests use the actual defective production boundary.
Parser tests or immediately returning OAuth/replay mocks are supplementary.

| Finding | Failure reproduced | Production correction | Decisive regression |
|---|---|---|---|
| F1 | Google removal held the authorization gate while revocation reacquired it; the composed operation timed out before remote dispatch. | `runRemoval()` recovers first, then owns the boundary once and supplies a generation-validated, lifetime-limited removal snapshot. Google revokes that selected record without another reader or issuer-discovery refresh. | `auth_repository_test.dart`: real repository, Google service and the same persistence instance; shared/user-owned success, failure, timeout, local-only and repeated removal; late refresh, legacy record and database failure after successful remote revocation. |
| F2 | Settings Cancel allowed candidate persistence; cancellation during preparation was superseded by a later attempt. | Captured invocation identity and cancellation precede asynchronous preparation. Desktop/native dispatch and commit check that invocation; stale cleanup cannot cancel a newer invocation. UI controls/disposal own their signals. Recovery continues coherently. A completed commit marks the signal committed before journal cleanup. | Real Settings Cancel/disposal across binding lookup, browser, exchange and identity for both origins; desktop recovery and commit barriers; real loopback cancel/retry; native broker and Kotlin reservation scoping; optional-consent preparation cancellation. |
| F3 | Real replay swallowed throttling, continued remaining writes and entered a pull without durable domain cooldown. | Replayers persist the domain cooldown before propagating the typed failure and stop the pass. Every policy branch consults the same state; cooldown maintenance performs only cached work. Atomic maximum updates retain longer cooldowns and reject stale-success checkpoints. Additional-month Calendar reads consult this state too. | Actual Google/Microsoft Tasks/Calendar clients, replayers and engines with three queued writes, manual/local/background triggers, a two-hour Retry-After, database close/reopen, range reads, expiry and resumption; quota 403 and malformed/missing timing fallback. |
| F4 | Validated provider/configuration failures became cancellation or generic temporary exchange errors. | Strict callback validation is separate from allowlisted authorization outcomes. Exchange classifies status first, preserves retry timing and never infers revocation of the old grant from a bad candidate code. Bounded transport consumes/cancels response streams without closing a shared client or waiting indefinitely for cleanup. | Real loopback outcomes, complete Google/Microsoft replacements for both origins, visible Settings recovery/retry, malformed/oversized and stalled responses, fake-clock deadlines, 429 and misleading 503 bodies. |
| F5 | A symlink substituted after pathname inspection was imported successfully. | Native Linux/Windows reader opens once, validates the actual descriptor/handle and reads it on a worker isolate. Linux uses no-follow/nonblocking open and fstat; Windows checks reparse attributes and disk handle type and uses overlapped reads. Cancellation rejects late bytes; staging never reopens the pathname. | Native C++ substitution hooks before open and after handle validation; directories, disappearance, permissions, special files, accepted hard links, 64 KiB boundary/growth, cancellation and deadlines; Dart importer uses the compiled native library. |

Removal reports remote success/failure accurately. If revocation succeeds and
local persistence or cleanup later fails, a typed recoverable error explicitly
says that remote authorization was revoked; rollback cannot restore a remote
grant. Post-deletion cleanup failures retain a committed recovery journal and
never claim already-deleted local data was preserved. Both origins exercise
that boundary, recovery, and the released account gate.
Other accounts remain usable, stale refresh/replacement cannot resurrect a
removed account, and the gate is released. No live grant was revoked for testing.

Cancellation during journal recovery stops that invocation from dispatching but
lets recovery finish. Cancellation before commit rolls back the candidate;
cancellation after coherent commit cannot falsely turn success into cancellation.
Setup dialogs retain ordinary presentation without a spinning authorization
indicator behind them. Stored-registration reconnect retries directly; consumed
imported configurations require a fresh selection. Category/shared-calendar
consent callers use the same owned lifecycle. Native cancellation rejects late
results; it does not claim physical dismissal of an SDK screen.

All new recovery messages use typed classifications and existing localization.
The locale catalogs include translated messages; raw provider descriptions,
error values, response bodies, codes, tokens and imported secrets are not UI text.

## Scheduling and request measurements

The 15-minute scheduler and Android periodic work remain. Approved passive
eligibility stays one hour plus sampled 0–10% jitter for Tasks and 15 minutes plus
jitter for Calendar; foreground freshness remains 15 minutes. Existing account
and cross-engine gates, checkpoints, cursors, pagination, pending-edit protection
and overlap remain. A longer interval alone is not claimed to solve quota scaling.

For each of Google/Microsoft Tasks/Calendar and manual/local/background triggers,
three durable writes are queued. The first POST returns 429 with Retry-After
7200 seconds: **one POST, zero later affected requests**, including subsequent
wakes, local dispatch, a recreated database/service and applicable range reads.
Only the dispatched operation has an attempt recorded. At expiry, replay and
pull resume: **four POSTs total** (one failed plus three successful creations),
no pending operations, and a successful pull checkpoint. Independent domains
remain eligible; cached reminders continue. Atomic updates retain an active
longer cooldown. Recognized Google quota 403 and missing/invalid timing use the
existing one-minute fallback. No automatic POST/PATCH HTTP replay was introduced.

Quiet 1/5/20-collection workloads retain 2/6/21 reads per eligible Tasks pull,
zero reads on three ineligible wakes, four reads for changed pagination, and one
POST for a local creation without passive collection polling. See
[synchronization_budget.md](synchronization_budget.md) for freshness and Android
request-budget calculations. This is synthetic production-client evidence,
not live quota approval or demonstrated isolation between real projects.

## Final automated and build results

Host: Ubuntu 24.04.5 LTS, Linux x64. Approved Flutter 3.47.5, Dart 3.13.4,
framework `6a19cca564`, engine `af7e796e16`, Temurin JDK 25.0.1, Gradle 9.4.1,
Android API 37 and Build Tools 37.0.0. No dependency version, SDK, runtime or project pin
was changed or downgraded. The only lockfile change declares the already-locked
`fake_async` package as a direct test dependency for deterministic deadline
regressions; its version and checksum remain unchanged.

| Final validation | Result |
|---|---|
| Locked dependency resolution / reproducible localization and Drift | Passed; no dependency versions changed |
| Formatting / analysis / platform boundaries | 845 Dart files unchanged; no analyzer issues; boundary check passed |
| Complete Flutter suite, concurrency 4 | 3,276 passed, 10 existing skips, 0 failures (05:32 in final isolated source extraction) |
| Fresh-source `BUSYMAX_TEST_CONCURRENCY=4 tool/android/verify.sh` | Exit 0, including complete suite, Kotlin and lint |
| Kotlin JUnit / Android lint | 11 passed, 0 skipped/failed; lint passed |
| Linux native C++ | Seven existing executables, locale/ASan variants, and descriptor-reader CTest passed in root and final fresh source |
| Linux GTK header integration | 1 passed, 0 failures/skips |
| Linux native integration | 18 passed: 16 actual Settings Cancel/disposal cases, private-keyring storage, actual GTK file selection/import; repeated in final fresh source |
| Linux / Android release modes | Passed: two Linux releases, two test-signed Android APKs and two AABs; registration/help, ELF/ZIP 16 KiB and AAB alignment verified |

Final command results, fresh counts, root causes and artifact hashes are in
[the evidence JSON](validation/oauth_transition_evidence.json). Earlier failing
runs exposed missing native test-library injection, changed replay/error
contracts and a loopback deadline race. Those were corrected, without disabling
tests, relaxing persisted-state assertions or raising global timeouts. Final
Flutter stages run sequentially to avoid competing generated entry-point and
cache writers; each complete suite uses concurrency four.

Linux reader checks use the actual native library and descriptor hooks. Native
Settings integration uses real controls with synthetic providers. Native storage
uses a private temporary D-Bus/keyring. The chooser is operated through its
accessible fixture action after it is available, selecting only the packaged
synthetic JSON; the actual file_selector/native reader then imports it. Initial
coordinate-based chooser automation timed out before this helper was corrected.
The helper also unmounts its own temporary GVFS mount before cleanup.
OS diagnostics and raw logs are not distributed.

Both release modes use synthetic public registration inputs for deterministic
routing checks. Android artifacts are explicitly test-signed with the existing
debug identity. They do not establish real official grant validity, production
signing or Android-device acceptance. User-imported registration data, tokens,
signing material and machine-local settings are excluded from the handoff.
Intentionally compiled transition inputs are distinguished from credential leaks.

## External execution gaps

No authorized real OAuth inputs were available. No provider reads/writes,
revocation or removal of a real account were performed. Live initial setup,
refresh, migration and optional consent remain external checks. Authenticated
Console/Entra walkthroughs and two-real-project validation remain deferred;
two clients in one synthetic project are not evidence of project quota isolation.

Windows native code and existing CMake/PowerShell test/package surfaces are
implemented, but Windows compilation, native chooser/storage, Pester/MSIX/WACK
were not executed: no Windows host or PowerShell is available. Dart Windows
contract/widget tests do not prove Windows handle safety. Snap packaging was not
executed because Snapcraft is unavailable. Android Kotlin/lint and test-signed
release builds are separate from device checks; the attached device is ADB
unauthorized, and nothing was installed or authorized on it.

## Reproducible commands and handoff

From the repository, with the approved installed toolchain:

```bash
export BUSYMAX_FLUTTER_EXECUTABLE=/home/albert/flutter/bin/flutter
export JAVA_HOME=/home/albert/.sdkman/candidates/java/25.0.1-tem
export ANDROID_SDK_ROOT=/home/albert/Android/Sdk
export PATH="$JAVA_HOME/bin:/home/albert/flutter/bin:$PATH"
BUSYMAX_TEST_CONCURRENCY=4 tool/android/verify.sh
git diff --check
```

The verifier performs locked dependency resolution, localization/Drift
regeneration with a generated-source snapshot check, formatting, analysis,
platform boundaries, the full suite, Kotlin JUnit and Android lint:

```bash
flutter pub get --enforce-lockfile
dart run tool/check_generated_sources.dart snapshot /tmp/busymax-generated-snapshot
flutter gen-l10n
dart run build_runner build --force-jit
dart run tool/check_generated_sources.dart verify /tmp/busymax-generated-snapshot
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run tool/check_platform_boundaries.dart
flutter test --concurrency=4
android/gradlew --project-dir android :busymax_android_platform:testDebugUnitTest :app:lintDebug
```

Native and release checks (Linux integration requires the available X11 display,
installed keyring/D-Bus and system Python GI/AT-SPI libraries and only the packaged synthetic fixture):

```bash
cmake -S native/registration_reader -B build/linux/registration-reader-tests
cmake --build build/linux/registration-reader-tests --target busymax_registration_reader_tests
ctest --test-dir build/linux/registration-reader-tests --output-on-failure
DISPLAY=:1 python3 tool/linux/test_oauth_corrective_native.py
# Existing g++/GTK/GIO and ASan commands in .github/workflows/flutter-linux.yml
flutter build linux --release -t lib/main_linux.dart
flutter build linux --release -t lib/main_linux.dart \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=transition-fixture.apps.googleusercontent.com \
  --dart-define=GOOGLE_OAUTH_CLIENT_SECRET=synthetic-build-secret \
  --dart-define=MICROSOFT_OAUTH_CLIENT_ID=22222222-2222-2222-2222-222222222222
tool/android/test_registration_modes.sh
python3 tool/create_source_handoff.py --output build/handoff/busymax-oauth-transition-source.tar.gz
```

A fresh Android checkout needs local SDK locators (no registrations, tokens or
signing keys). The validation extraction created this excluded file:

```bash
printf 'flutter.sdk=/home/albert/flutter\nsdk.dir=/home/albert/Android/Sdk\n' > android/local.properties
```

Use the paths of the approved installed SDKs on the validation host.
The fresh extraction verifies `SOURCE_SHA256SUMS`, packaged help, synthetic
fixtures and Linux/Windows native reader sources, then runs locked dependencies,
reproducible generators, static checks, the complete Flutter suite and affected
native checks. Checksums are verified again afterward. Final documentation is
updated with these results, then the handoff is regenerated and implementation
files compared to the tested extraction; only this report/evidence may differ.
All 1,211 source checksums remained unchanged after the final fresh pipeline
and native checks. The final archive has only the two result documents updated;
its remaining 1,209 source/help/fixture files match that tested extraction.
Archive and manifest hashes are provided beside the final handoff. The source
archive excludes transient Kotlin compiler-session state as well as local
configuration, credentials, private logs and build outputs.
