# Isolated CalDAV interoperability environment

These first-party deployment fixtures package **unmodified** upstream Radicale
3.8.1 and Baïkal 0.12.1 (bundled sabre/dav 4.7.1). Exact image digests are in
`compose.yaml` and `baikal.Dockerfile`. Baïkal's official release archive is
verified against SHA-256
`0449abb72b151d39d9c08c63cb83a05d9e9adb065b1165ef6786b0b6a13d203c`.
These are the reviewed qualification targets, not a claim that they are latest.

Prerequisites: Docker with Compose v2, Python 3, OpenSSL, the repository's
official Flutter/Dart toolchain, free loopback ports 18443–18447, 18532 and 18580.
Run commands from the BusyMax repository root. Do not reuse production secrets.

## Setup, start and authenticated readiness

```bash
python3 test/interop/caldav/setup.py
sh test/interop/caldav/make-certificates.sh
docker compose -f test/interop/caldav/compose.yaml --profile https up --build --wait
python3 test/interop/caldav/probe.py --provision
python3 test/interop/caldav/probe.py --https
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

# Actual BusyMax transport, onboarding, repositories, queues and sync engines.
BUSYMAX_CALDAV_LIVE=1 flutter test test/dav/caldav_live_integration_test.dart --reporter expanded

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
ORG_GRADLE_PROJECT_busymaxCalDavQa=true \
ORG_GRADLE_PROJECT_busymaxTestSigning=true \
flutter test integration_test/caldav_android_workflows_test.dart -d DEVICE \
  --dart-define-from-file=test/interop/caldav/.runtime/android-defines.json --reporter expanded
```

The QA flags are mutually exclusive with Nextcloud QA and require explicit test
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
print `BUSYMAX_CALDAV_PROCESS_PASS` separately for both servers, verify
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
