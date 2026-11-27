# Isolated CalDAV interoperability environment

These first-party deployment fixtures package **unmodified** upstream Radicale
3.9.0 and Baïkal 0.13.0 (bundled sabre/dav 4.7.1). Exact image digests are in
`compose.yaml` and `baikal.Dockerfile`. Baïkal's official release archive is
verified against SHA-256
`81e74df123230e863f608d228fdd7b9a1a788f60b04d37e6973c302192e83f32`.
BusyStack CalDAV Server v0.1.0 is the third mandatory target. The
qualification record distinguishes current protocol results from older native
process-restart evidence.

Prerequisites: Docker with Compose v2, Python 3, OpenSSL, the repository's
official Flutter/Dart toolchain, free loopback ports 18443–18448, 18532, 18580 and 18581.
Run commands from the BusyMax repository root. Do not reuse production secrets.

## Setup, start and authenticated readiness

```bash
python3 test/interop/caldav/setup.py
sh test/interop/caldav/make-certificates.sh
docker compose -f test/interop/caldav/compose.yaml --profile https up --build --wait
python3 test/interop/caldav/probe.py --provision --server radicale --server baikal
python3 test/interop/caldav/probe.py --https --server radicale --server baikal
```

The setup downloads an official, complete Baïkal archive including its bundled
dependencies. PHP 8.4.13 Apache is the pinned official runtime, using SQLite.
No upstream source or runtime is patched. The Apache DocumentRoot is Baïkal's
`html` directory; private configuration and SQLite storage are outside it.
The non-root Baïkal fixture has its own configured base URI and storage.

The Compose project is `busymax-caldav-qa`; all host ports bind to loopback and
its volumes are project-scoped. Readiness requires authenticated PROPFIND, not
an unauthenticated web page. `probe.py` independently verifies principals,
homes, component sets, optional ACL properties and methods for Alice and Bob.
Radicale uses explicit SHA-256-crypt htpasswd authentication and explicit rights.
Both servers contain event-only, task-only and mixed collections plus a fixture
that Alice can read but cannot write. Baïkal's read-only collection is a share
from Bob; Radicale's rights file grants Bob provisioning access.

Generated credentials, archives, certificates, private keys and local Android
defines live only in ignored `.runtime/`. The CA is trusted only by fixture
clients through a private SecurityContext; no global trust changes or disabled
certificate checks are used. Certificates expire after seven days. To renew,
stop this project, remove the generated certificate files, and rerun the
certificate script. Do not commit `.runtime` or copy its keys to other systems.

## Test execution

```bash
# Deterministic tests do not need Docker.
flutter test test/providers test/db test/dav test/core/auth

# Run the complete three-server suite alone (including credential rotation).
BUSYMAX_CALDAV_LIVE=1 BUSYMAX_CALDAV_LIFECYCLE=1 flutter test test/dav/caldav_live_integration_test.dart --reporter expanded

# Run alone: restarts fixtures and rotates/restores disposable passwords.
BUSYMAX_CALDAV_LIVE=1 BUSYMAX_CALDAV_LIFECYCLE=1 \
flutter test test/dav/caldav_live_integration_test.dart --plain-name 'real password' --reporter expanded

# Audit-correction probe: real read-only namespace, rejected journal, DB reopen,
# three subsequent rounds of independently changed VEVENT/VTODO synchronization.
# Uses the production account-sync route, fresh successful retries in the owner
# home, explicit notice dismissal, and acknowledgment persistence after reopening.
BUSYMAX_CALDAV_LIVE=1 flutter test test/dav/caldav_live_integration_test.dart \
  --plain-name 'rejected creation in a read-only namespace' --reporter expanded

# Real RFC 6578 pagination, strict Depth 0, concurrent writes and interruption.
# Run alone: the test changes/restores only the isolated BusyStack QA profile.
BUSYMAX_CALDAV_LIVE=1 BUSYMAX_CALDAV_LIFECYCLE=1 \
flutter test test/dav/busystack_live_integration_test.dart \
  --plain-name 'strict Depth, real 507 pages' --reporter expanded

# Labelled gateway fault injection over all three unmodified live servers.
# Property-only multiget 404 with real GET 200/404, injected GET denial/network
# failure, DB reopening and independent readback; injected HEAD 303 discovery.
BUSYMAX_CALDAV_LIVE=1 flutter test test/dav/caldav_reconciliation_live_test.dart --reporter expanded

# Actual Linux settings and editors, with independent server readback.
BUSYMAX_CALDAV_NATIVE=1 \
BUSYMAX_CALDAV_FIXTURE_DIR="$PWD/test/interop/caldav/.runtime" \
GDK_BACKEND=x11 flutter test integration_test/caldav_workflows_test.dart -d linux --reporter expanded
```

The default harness provisions collections through BusyMax's production service.
Under the explicitly approved provider-neutral policy, unavailable child OPTIONS
leaves method capability unknown; a user-requested persisted creation can use
MKCALENDAR only with a fresh explicit parent bind/write/all grant. Successful
child OPTIONS/Allow and HTTP 405/Allow excluding creation methods still block,
including an empty Allow field. A 405 without Allow remains unknown; explicit
denials still block.
Lost responses retain the journal/reserved URL and require reconciliation.

For separately labelled independent setup (never application-creation evidence):

```bash
BUSYMAX_CALDAV_LIVE=1 BUSYMAX_CALDAV_LIFECYCLE=1 \
BUSYMAX_CALDAV_FIXTURE_COLLECTION_SETUP=independent \
flutter test test/dav/caldav_live_integration_test.dart --reporter expanded
```

The release-edge harness also injects a DELETE 207/423 through an identified
gateway after one child is really removed upstream; independent GET/PROPFIND
and database reopening verify reconciliation. This is client fault handling
evidence, not a claim that the server naturally emits that response.

The HTTPS profile covers Radicale root (18443), Baïkal direct endpoint (18444),
Radicale installation path (18445), an untrusted certificate (18446), and a
separate Baïkal installation (18447). Its first-party proxy also provides
cross-origin and HTTP-downgrade redirect fixtures. Upstream servers remain
unmodified. Live fault tests lose a gateway response after an upstream commit;
they do not replace the server with a simulated protocol implementation.

For an explicitly scoped run, set `BUSYMAX_CALDAV_QA_TARGETS=radicale,baikal`
(or the matching Dart define for native tests). The default remains all three
pinned targets. Unknown names fail; partial target selection is recorded as
partial evidence and never closes the omitted target's qualification gate.
The Android two-process harness currently covers Radicale and Baïkal only.

Run the full Flutter suite, complete live suites and native builds sequentially.
The previous failed Radicale run overlapped the Flutter suite and Android
builds; independent PUT/root PROPFIND requests stalled for over 30 seconds.
The exact socket closure remains unproven; passing focused repeats do not
explain it. Preserve complete-run and timestamped server/gateway logs.
Run Flutter tests and native builds sequentially. In particular, starting an
Android release build while `flutter test` is generating plugin registration
can leave the build with mismatched integration-test plugin sources.

For Android, use an authorized, unlocked device and the isolated QA application
ID `io.busystack.busymax.caldavqa`. Do not install over a normal BusyMax account
or use another developer's environment. Generate local defines with
`python3 test/interop/caldav/android-fixture.py`, map only unused QA ports, then:

```bash
adb -s DEVICE reverse tcp:18443 tcp:18443
adb -s DEVICE reverse tcp:18444 tcp:18444
adb -s DEVICE reverse tcp:18448 tcp:18448
ORG_GRADLE_PROJECT_busymaxCalDavQa=true \
ORG_GRADLE_PROJECT_busymaxTestSigning=true \
flutter test integration_test/caldav_android_workflows_test.dart -d DEVICE --no-uninstall \
  --dart-define-from-file=test/interop/caldav/.runtime/android-defines.json --reporter expanded
```

Generate Android defines after the live lifecycle tests, which rotate the
BusyStack DAV credential. The QA flags are mutually exclusive with Nextcloud QA and require explicit test
signing. Only this QA package keeps its test activity awake; device lock and
power settings are unchanged. The native harness injects disposable in-memory
secrets, a file-backed test database and the fixture CA; it does not qualify
platform secure storage. It also checks a rejected VTODO collection's named
account-settings notice through the production sync route while ordinary
synchronization remains successful.
`integration_test/caldav_android_process_restart_test.dart` is a separate
two-process qualification using production Android secure storage, SQLite,
authorization recovery and native account gates. Run it twice with the same
QA package and fixture defines, substituting its path in the Android command
above, adding **`--no-uninstall` to both runs**, without clearing application
data between runs. With dynamic Gradle QA application IDs, Flutter's default cleanup can select
the base package ID. Always use `--no-uninstall`; verify the APK's application
ID before installation and explicitly remove only the task-owned QA package
after testing. After preparation, explicitly stop only this QA package with
`adb -s DEVICE shell am force-stop io.busystack.busymax.caldavqa`, then run the
same test again with `--no-uninstall`. The first process prints
`BUSYMAX_CALDAV_PROCESS_PREPARED` after persisting queued edits. The second must
print `BUSYMAX_CALDAV_PROCESS_PASS` separately for Radicale and Baïkal, verify
independent remote changes, and remove its test accounts and credentials.
After testing, uninstall only this QA package and remove only mappings created
for this run. Windows native acceptance requires a separately authorized
Windows environment; a Linux build is not Windows runtime acceptance.

## Scheduling qualification

```bash
BUSYMAX_CALDAV_LIVE=1 flutter test test/dav/caldav_scheduling_live_test.dart --reporter expanded
flutter test test/dav/mutation/dav_conflict_scheduling_consent_test.dart test/platform/conflict_duplication_consent_routes_test.dart
```

The Baïkal VTODO client-consent case always runs its queue guard, accepted
copy, database reopening and independent object readback. Its separate delivery
case skips only when no initial inbox REQUEST is demonstrated. Storage never
counts as scheduling delivery. The deterministic conflict tests exercise the
production resolution service and all three production UI routes, including
cancel/approve, both component types, native properties and recurrence identity.
They do not establish native Windows/Android acceptance.

## Reset and teardown

```bash
# Stop and retain this project's fixture storage.
docker compose -f test/interop/caldav/compose.yaml --profile https down

# Reset only this project's disposable server data, then start/provision again.
docker compose -f test/interop/caldav/compose.yaml --profile https down --volumes
```

Do not run global Docker prune or remove unrelated containers/volumes. Do not
delete credentials while retaining volumes: Baïkal's persisted users would then
have different passwords. A full reset can remove `.runtime` only after this
project is down with its volumes removed, then repeat setup.

The [maintained qualification record](../../../docs/caldav_qualification.md)
distinguishes implementation, deterministic tests, live tests and native tests.

## BusyStack released deployment and supported provisioning

Use only the official **v0.1.0** deployment bundle, source commit
`db302ec69f786ba89945e1a761734a844572145b`. `setup-busystack.py` verifies the
archive (`615c703ef94b21393a3e1ca2c2a1209c90d5f2716d302e1f3e664635a58f04b4`),
release-manifest and checksum-list hashes, source identity, image pins and every
manifest deployment file before starting anything. The application image is
`ghcr.io/busystack/caldav-server:0.1.0@sha256:0701a86c1d9848924f36111e5a1223c7e5a368737637f4382d1edbe55a50dcb0`.
PostgreSQL 18.6 remains private, with a dedicated persistent volume. The project
name is fixed to `busymax-caldav-busystack-qa`. No server build or patch is used.
The first-party override adds only the isolated HTTPS fixture proxy.

After the certificate setup above, provision a fresh, disposable deployment:

```bash
python3 test/interop/caldav/busystack-fixture.py setup
python3 test/interop/caldav/busystack-fixture.py start
python3 test/interop/caldav/busystack-fixture.py bootstrap
python3 test/interop/caldav/busystack-fixture.py build-browser
python3 test/interop/caldav/busystack-fixture.py provision
python3 test/interop/caldav/probe.py --provision --server busystack
python3 test/interop/caldav/busystack-fixture.py share bob 'BusyMax QA restricted' alice READ
python3 test/interop/caldav/probe.py --https
```

Bootstrap is the released administrator bootstrap command, once per fresh
volume. Provisioning uses the supported browser forms: administrator-created
users, password sign-in, CTAP2 virtual-authenticator enrollment and completed
MFA, then named, one-day DAV credentials. The normal account passwords are
never sent to DAV. Playwright/Chromium is isolated in its own container profile;
its certificate trust database is private to that container. No global trust,
certificate exceptions, invented credentials or database authentication bypasses
are used. Browser tooling packages official, unmodified upstream components.

Random account passwords and database secrets are under an owner-only temporary
directory referenced by ignored `.runtime/busystack-private-directory`. DAV
credentials and virtual-authenticator keys are owner-only ignored runtime files.
Do not print or commit them. Generated Android defines also contain disposable
secrets and must stay ignored. The endpoint is `https://localhost:18448/dav/`;
BusyMax uses its ordinary generic CalDAV provider.

This release supports separate VEVENT and VTODO collections, and explicitly
rejects mixed component creation. The probe verifies that rejection rather than
assuming a missing task collection means VTODO is unsupported. Sharing controls
belong to the server fixture, not BusyMax.

## Journal candidate qualification

Build the server image from the JAR produced by a successful clean Maven verify
on the candidate commit. The preparation command checks its source label,
image ID and embedded JAR hash. The startup check verifies schema 17. This
candidate uses loopback port 18448. Stop any other task-owned fixture on that
port before starting the candidate. The already released BusyStack profile
documented above has its own provenance and workflow.

```sh
candidate=$(python3 test/interop/caldav/vjournal-candidate.py prepare ../caldav-server)
python3 test/interop/caldav/vjournal-candidate.py start "$candidate"
python3 test/interop/caldav/busystack-fixture.py build-browser
python3 test/interop/caldav/vjournal-candidate.py provision "$candidate"
nextcloud=$(python3 test/interop/caldav/vjournal-nextcloud.py start /tmp)

umask 077
python3 - "$candidate" "$nextcloud" <<'PY'
import json
from pathlib import Path
import sys

candidate, nextcloud = map(Path, sys.argv[1:])
profile = json.loads((nextcloud / 'busymax-live.json').read_text())
profile.update(json.loads((candidate / 'busymax-connection.json').read_text()))
(nextcloud / 'busymax-live.json').write_text(json.dumps(profile))
PY

python3 test/interop/caldav/verify-vjournal.py \
  --server ../caldav-server --candidate "$candidate" --nextcloud "$nextcloud" \
  --fixture "$nextcloud/busymax-live.json" --artifacts build/qualification
```

The command runs independent raw admission and REPORT probes, configured
BusyMax DAV tests, and the Linux journal workflow in the active graphical
session. Add `--android-device SERIAL --android-aapt /path/to/aapt` to run
the Android workflow on an authorized device. The runner verifies each
test-signed QA APK's application ID and uses `--no-uninstall`. To qualify
Windows, pass `--windows-runner /path/to/runner`. The launcher receives the
provider and a private fixture path as positional arguments. It must run
`integration_test/journal_windows_workflows_test.dart` on Windows and
forward the named test and case output. Run all native suites in isolated
profiles. Missing scenarios and failed writes keep the matrix incomplete.
The generated evidence reports source and provider identities alongside
named cases. Keep fixture files and generated device credentials out of Git.
The disposable Nextcloud fixture allows 100 calendar creations per hour and
100 calendars or subscriptions per account. These documented `occ` settings
keep repeated fixture runs within a finite quota. The fixture records the
settings beside the official image identity.

For an existing authorized Windows OpenSSH host with a desktop session and
the pinned Flutter and Visual Studio toolchains, use
`--windows-runner test/interop/caldav/windows-journal-ssh.py`. Set
`BUSYMAX_WINDOWS_QA_SSH` to the known-host alias and
`BUSYMAX_WINDOWS_QA_CHECKOUT` to the clean Windows checkout of the same
BusyMax commit. The launcher uses an SSH reverse forward to each fixture’s
original HTTPS port. It sends the private fixture over SSH standard input,
keeps it in a current-user-only directory and removes that directory after
the run. The launcher requires the host key in `known_hosts` and SSH port
forwarding enabled for the authorized account.

Use `--linux-process-restart` on a graphical Linux session with D-Bus and
GNOME Keyring available. This adds two separate native processes per provider.
The first queues a creation, edit and deletion in a private SQLite profile.
The second opens the same profile, unlocks access through the isolated native
keyring, reconciles those operations and checks the result with HTTPS GETs.

Use `--linux-account-enrollment` for the additional BusyStack native setup
case. It requires `xvfb-run`, `xauth`, GNOME Keyring and `xdotool` in the
test host's executable path. The runner creates a private X11 display and
keyring. The case starts the production Linux entry point with a fresh
database, adds the CalDAV account through Settings, imports the fixture CA
through the GTK picker and verifies journal discovery, selection and account
reconnection. It exercises the CalDAV credential flow. Nextcloud's browser
enrollment requires its own scenario.

### Routed Android API 37 smoke

Use a private routed IPv4 address belonging to the QA host and a disposable
API 37 device profile. Run this stage after the loopback tests. The relay
temporarily configures the verified, disposable BusyStack candidate to
advertise its LAN origin. Stop the relay with SIGINT or SIGTERM to restore
the loopback origin. It uses a fresh CA for the LAN address and verifies
both upstream endpoints with their original fixture CAs.

```sh
python3 test/interop/caldav/vjournal-lan.py \
  "$nextcloud/busymax-live.json" "$candidate" "$nextcloud" "$VJOURNAL_LAN_RUNTIME" \
  --address "$VJOURNAL_LAN_ADDRESS" --caldav-port "$VJOURNAL_CALDAV_LAN_PORT" \
  --nextcloud-port "$VJOURNAL_NEXTCLOUD_LAN_PORT"
```

Create a private Android defines file from the relay's `busymax-live.json`.
Set `BUSYMAX_JOURNAL_PROVIDER` to the selected provider key and
`BUSYMAX_JOURNAL_NATIVE_FIXTURE` to its base64 JSON object. Put the CA PEM
content in `ca` and omit `caFile`. Use the matching QA application ID,
verify the built APK's application ID and signer on the authorized device,
and run `integration_test/journal_android_lan_smoke_test.dart` with
`--no-uninstall` and the private defines file. Start with the QA package's
LAN permission denied and grant it in the Android permission dialog. The
smoke checks Android's route classification, the dispatch guard and a
trusted HTTPS journal create, read and cleanup. Full app synchronization,
permission recovery, restart and installed-package scenarios require their
own assertions. Stop the relay process before stopping the provider fixtures.

Clean up only the fixtures created above.

```sh
python3 test/interop/caldav/vjournal-candidate.py stop "$candidate"
python3 test/interop/caldav/vjournal-nextcloud.py stop "$nextcloud"
```

### Journal coverage

| Scope | Parse and preserve | Presentation and authoring | Exercised checks |
| --- | --- | --- | --- |
| RFC 5545 journal properties | Authoritative lines, property parameters, multiple descriptions and retained opaque fields | Title, status, date mode, description blocks, language, ALTREP and attachments | J01, J07 and J09 subsets in `test/journal` and admission J01 |
| RFC 7986 and RFC 9073 extensions | Wrapper and journal fields, nested components and property parameters retained on unrelated edits | Details can edit COLOR, IMAGE, styled descriptions, structured data, participants, locations and resources. DERIVED values are read-only | Admission J10 and J11, nested draft and mutation regressions |
| RFC 9253 relationships | URI, UID and XML-reference forms retained in raw resources | Open a uniquely resolved journal, event or task by same-collection UID or exact same-account resource URI. XML references open explicitly in the external handler with the fragment intact | Admission J12, repository target lookup, visibility checks and Nextcloud rejected-write recovery. Native navigation and transfer scope still require qualification |
| RFC 10051 status components | A journal can contain VSTATUS and must retain its parent STATUS | Advanced details expose status components. Top-level journal status values stay within RFC 5545 | VSTATUS storage/readback, nested draft and retained-child edit regressions |
| Recurrence and dates | Period values retained. Bounded expansion uses period starts and journal point/day matching | Browse occurrences by month. Edit or delete an occurrence or future range. Trimming a range that exceeds the recurrence work limit leaves the resource unchanged | J15 and J19 subsets in `test/journal`, J20 REPORT probes |
| Offline and conflicts | Conditional queue and effective export. Overlapping reordered descriptions require conflict resolution | Pending or failed operations appear in the journal list. Journal details offer server, reapply and duplicate choices where available | O04, O06 and O09 subsets in `test/journal`. Native restart and conflict acceptance are outstanding |
| Import and export | Storage-form ICS resource sets, including detached-only data | Preview storage-form entries and journal PUBLISH, ADD and CANCEL files. Export effective local entries or collections. WebCal journal snapshots appear as read-only entries | O13, O17 and J26 subsets in `test/journal` and `test/webcal` |

BusyMax schema 28 stores journal drafts, including incomplete parameter names
and nested edits. Close and reopen an entry to resume editing. If a local
draft write fails, the editor keeps the text open until Retry succeeds or
you explicitly discard it. If the saved entry changes meanwhile, inspect
the draft, export it as JSON with its saved counterpart, or start a reviewed
new entry after checking the destination. Changing the date form of a
series requires compatible recurrence dates and rule bounds.

Import review retains the exact source bytes, reviewed destination and local
queue outcomes when BusyMax closes. Reopen **Import .ics file** to resume.
Use **Export recovery bundle (JSON)** to save the original content and
per-entry outcomes. Discarding the review leaves previously queued entries
in the journal. A visible unavailable reference keeps its original value
and can be edited in Details.

Stock Nextcloud 35.0.3 rejected both dated RDATE PERIOD forms and three
explicit relationship VALUE cases on create and conditional replacement.
The independent probe checks that rejected writes leave prior bytes,
ETags, inventory and sync tokens unchanged. BusyMax keeps the pending
resource available for export. Nextcloud's time-range and expanded
REPORT results cannot provide a complete journal inventory.

Run the additional cases **sequentially** after the shared live suite:

```bash
python3 test/interop/caldav/busystack-fixture.py \
  --candidate "$VJOURNAL_CANDIDATE" prepare-lifecycle
BUSYMAX_CALDAV_LIVE=1 BUSYMAX_CALDAV_LIFECYCLE=1 \
BUSYMAX_CALDAV_CANDIDATE="$VJOURNAL_CANDIDATE" \
flutter test test/dav/busystack_live_integration_test.dart --reporter expanded
```

Use a candidate provisioned with the current browser script so its disposable
passkeys are available for repeated portal actions. The candidate controller
reads that deployment's endpoint and private runtime directory, verifies the
running image, source label, JAR and schema, and applies profiles only in that
Compose project. Leaving `BUSYMAX_CALDAV_CANDIDATE` unset selects the separately
provisioned 0.1.0 regression deployment.

The extra suite changes only this deployment's profiles, groups and disposable
users. It tests real 507 paging and continuation, strict sync Depth, configured installation
prefix/well-known discovery, resource limits, restart,
concurrent writes, interrupted inventory, transformed timezone PUTs and direct/
group permissions. Each profile test restores the normal upstream defaults.
`profile subpath` uses the documented public URL and matching servlet context
`https://localhost:18448/calendar`, preserving the prefix at the proxy.
`profile strict` sets `BUSYSTACK_DAV_ALLOW_SYNC_DEPTH_ONE=false`; `profile
no-repair` additionally disables `BUSYSTACK_DAV_REPAIR_LOCAL_OBSERVANCE_UNTIL`.
No production default is changed.

The credential case permanently disables the dedicated `disabled` user; run it
once per fresh provisioning. Expiry is accelerated by aging only the timestamps
of that user's genuinely browser-issued credential in this private QA database.
Its verifier is unchanged; this establishes expiry enforcement, not a natural
24-hour wait. Revocation and disabling use the real MFA/account administration
interfaces. Reset this deployment before repeating the entire extra suite:

```bash
python3 test/interop/caldav/busystack-fixture.py stop
# Destructive only to the fixed dedicated QA project's volumes:
python3 test/interop/caldav/busystack-fixture.py reset
# Repeat start, bootstrap, provision and DAV collection provisioning above.
```

`restart`, `issue USER LABEL`, `revoke USER LABEL` and `share OWNER TITLE USER
READ|WRITE|REVOKE` are supported fixture actions. Credential rotation issues a
new named credential and revokes the prior one; it never restores a revoked
secret. Do not overlap lifecycle tests, browser actions, profile changes or
native runs against this same fixture.

## Linux real keyring and process recovery

The same existing harness can also run in the confinement of an installed
BusyMax core24 strict Snap, without replacing that package or opening its normal
account database. Close the normal BusyMax application, then run in an authorized
desktop session after the live lifecycle tests:

```bash
flutter build linux --debug -t integration_test/caldav_linux_process_restart_test.dart
python3 test/interop/caldav/linux-confined-restart.py
```

The helper creates one private UUID-named directory under that Snap's common
directory, copies only the QA bundle/fixture inputs, and launches two separate
processes through the installed wrappers with their matching official debug
engine. It uses the production `SECRET_BACKEND=file` configuration and prefixed
test keys, verifies independent DAV readback and notification-daemon acceptance,
then removes test credentials and its owned directory. Ignored runtime logs and
a secret-free result record retain the source/kernel/installed-profile identity.
On failure it retains only its QA directory for diagnosis/recovery. A standalone
integration-plugin warning is expected because the helper captures results
directly; the existing harness assertions and per-server markers must pass.
This verifies the installed confinement/storage profile; it does not substitute
for interactive account/editor acceptance in an installed new release package.

In an authorized Linux desktop session with its normal secret service and
notification daemon, run this command twice as separate OS processes:

```bash
BUSYMAX_CALDAV_NATIVE=1 \
BUSYMAX_CALDAV_FIXTURE_DIR="$PWD/test/interop/caldav/.runtime" \
GDK_BACKEND=x11 flutter test integration_test/caldav_linux_process_restart_test.dart \
  -d linux --reporter expanded
```

The first process prints `BUSYMAX_CALDAV_LINUX_PROCESS_PREPARED`: two queued
edits and two remotely committed creations with lost responses per server.
The second must have a different PID, recover production secure storage and
SQLite, reconcile by persisted operation UUID without another MKCALENDAR,
independently verify the stored items, deliver reminders through the real
freedesktop daemon, then remove its owned fixtures and secure credentials.
Only QA key names are prefixed; the native secure-storage plugin is real.
Its receipt contains no secrets. This does not claim Snap confinement or
Windows acceptance. Do not delete the receipt before recovery/cleanup.

### Repeating destructive credential lifecycle qualification

Before each full BusyStack lifecycle run, use
`python3 test/interop/caldav/busystack-fixture.py prepare-lifecycle`. The supported
administrator UI creates a fresh disposable account, then its browser/MFA flow
issues a named DAV credential. Its private receipt is required by the expiry
fixture. The test independently removes its owned remote collections before
disabling that account. Disabling is terminal; prepare another fresh account
for another run. Do not attempt to re-enable or repurpose an unrelated account.

The credential registry binds each browser-issued label to the exact held
credential ID. Rotation refuses a mismatched registry before revocation. The
expiry fault ages only timestamps for the recorded disposable account and
issued credential; this is explicit QA database fault injection, not a natural
expiry interval or an authentication bypass. All receipts, credentials and MFA
state remain in ignored private fixture storage.
