# Isolated CalDAV interoperability environment

These first-party deployment fixtures package **unmodified** upstream Radicale
3.9.0 and Baïkal 0.13.0 (bundled sabre/dav 4.7.1). Exact image digests are in
`compose.yaml` and `baikal.Dockerfile`. Baïkal's official release archive is
verified against SHA-256
`81e74df123230e863f608d228fdd7b9a1a788f60b04d37e6973c302192e83f32`.
BusyStack CalDAV Server v0.1.0 is the third mandatory target. Historical
Radicale 3.8.1 / Baïkal 0.12.1 evidence remains in the qualification record.

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

# Actual Linux settings and editors, with independent server readback.
BUSYMAX_CALDAV_NATIVE=1 \
BUSYMAX_CALDAV_FIXTURE_DIR="$PWD/test/interop/caldav/.runtime" \
GDK_BACKEND=x11 flutter test integration_test/caldav_workflows_test.dart -d linux --reporter expanded
```

The HTTPS profile covers Radicale root (18443), Baïkal direct endpoint (18444),
Radicale installation path (18445), an untrusted certificate (18446), and a
separate Baïkal installation (18447). Its first-party proxy also provides
cross-origin and HTTP-downgrade redirect fixtures. Upstream servers remain
unmodified. Live fault tests lose a gateway response after an upstream commit;
they do not replace the server with a simulated protocol implementation.

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
flutter test integration_test/caldav_android_workflows_test.dart -d DEVICE \
  --dart-define-from-file=test/interop/caldav/.runtime/android-defines.json --reporter expanded
```

Generate Android defines after the live lifecycle tests, which rotate the
BusyStack DAV credential. The QA flags are mutually exclusive with Nextcloud QA and require explicit test
signing. Only this QA package keeps its test activity awake; device lock and
power settings are unchanged. The native harness injects disposable in-memory
secrets, a file-backed test database and the fixture CA; it does not qualify
platform secure storage.
`integration_test/caldav_android_process_restart_test.dart` is a separate
two-process qualification using production Android secure storage, SQLite,
authorization recovery and native account gates. Run it twice with the same
QA package and fixture defines, substituting its path in the Android command
above, adding **`--no-uninstall` to both runs**, without clearing application
data between runs. Flutter's integration runner otherwise uninstalls the QA app
after a test. After preparation, explicitly stop only this QA package with
`adb -s DEVICE shell am force-stop io.busystack.busymax.caldavqa`, then run the
same test again with `--no-uninstall`. The first process prints
`BUSYMAX_CALDAV_PROCESS_PREPARED` after persisting queued edits. The second must
print `BUSYMAX_CALDAV_PROCESS_PASS` separately for all three servers, verify
independent remote changes, and remove its test accounts and credentials.
After testing, uninstall only this QA package and remove only mappings created
for this run. Windows native acceptance requires a separately authorized
Windows environment; a Linux build is not Windows runtime acceptance.

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

Run the additional cases **sequentially** after the shared live suite:

```bash
BUSYMAX_CALDAV_LIVE=1 BUSYMAX_CALDAV_LIFECYCLE=1 \
flutter test test/dav/busystack_live_integration_test.dart --reporter expanded
```

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
