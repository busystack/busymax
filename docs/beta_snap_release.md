# Snap beta release

The canonical Snap build packages an existing Flutter Linux release bundle with
`snap/snapcraft.yaml`. Snapcraft does not run `flutter build` or read the
local Dart-defines file, so build the configured Flutter bundle first.

## Prepare

Use Linux amd64 with the [BusyMax development toolchain](development.md),
snapd, Snapcraft with LXD, `libhandy-1-dev`, and `unsquashfs` from
`squashfs-tools`. Publishing also requires authorization for the BusyMax Snap
Store listing.

Confirm that source versions agree:

```bash
grep -nE '^version:|<release version=' \
  pubspec.yaml snap/snapcraft.yaml linux/io.busystack.busymax.metainfo.xml
```

The `pubspec.yaml` version, Snapcraft version, and newest metainfo release
must match. Older metainfo entries are release history.

For a configured release, create the ignored file
`.snap-local/busymax-dart-defines.json` with mode `0600`:

```json
{
  "GOOGLE_OAUTH_CLIENT_ID": "PROTECTED_ORIGINAL_GOOGLE_CLIENT_ID",
  "GOOGLE_OAUTH_CLIENT_SECRET": "PROTECTED_ORIGINAL_GOOGLE_CLIENT_SECRET",
  "MICROSOFT_OAUTH_CLIENT_ID": "PROTECTED_ORIGINAL_MICROSOFT_CLIENT_ID",
  "MICROSOFT_OAUTH_AUTHORITY_TENANT": "PROTECTED_ORIGINAL_AUTHORITY",
  "BUSYMAX_GOOGLE_OAUTH_CLIENT_ID": "PRODUCTION_GOOGLE_DESKTOP_CLIENT_ID",
  "BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET": "PRODUCTION_GOOGLE_DESKTOP_CLIENT_SECRET",
  "BUSYMAX_GOOGLE_OAUTH_PROJECT_ID": "ACTUAL_PRODUCTION_GOOGLE_PROJECT_ID",
  "BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID": "PRODUCTION_MICROSOFT_PUBLIC_CLIENT_ID",
  "BUSYMAX_PRIVACY_POLICY_URL": "https://busystack.org/privacy-busymax"
}
```

Follow [Google OAuth registration](google_setup.md) and
[Microsoft OAuth registration](microsoft_setup.md). These desktop credentials
are embedded in the bundle and can be extracted. Use only the intended
desktop/public-client configuration; never use server credentials or commit
the JSON or generated Snap. Apple iCloud and Nextcloud per-user credentials do
not belong in this file.

Active `BUSYMAX_*` registrations enable new managed connections; protected
originals serve existing account bindings and must retain their original
values. Never use CI fixture values as production credentials. The
[desktop OAuth release checklist](desktop_oauth_release_checklist.md) covers the
provider publishing, verification, and consent prerequisites. Validate the
define file with `tool/check_desktop_oauth_config.dart` before building, as
shown below.

## Build the canonical artifact

Complete the shared preparation and normal validation in
[Development](development.md), supply the real owner-controlled values, then run:

```bash
dart run tool/check_desktop_oauth_config.dart \
  --config .snap-local/busymax-dart-defines.json
flutter build linux --release -t lib/main_linux.dart \
  --dart-define-from-file=.snap-local/busymax-dart-defines.json
snapcraft pack --use-lxd
```

Snapcraft prints the path to `busymax_<version>_amd64.snap`. Use that exact
artifact for every inspection, installation, checksum, and upload. If BusyMax
reports that a provider is not configured, the compiled bundle is missing its
Dart defines and must be rebuilt.

The Flutter Linux workflow performs source validation, builds
`lib/main_linux.dart`, packages a strict Snap, and installs and verifies it.
Pull requests and pushes to `main` need no production OAuth credentials.
They upload the verified `busymax-linux-ci-unconfigured-non-production`
artifact, containing `busymax-linux-ci-unconfigured-non-production.snap`, for
seven days. This unconfigured package keeps custom registration available and
managed connections unavailable. It is not an official release and must not
be published.

For an official production artifact, configure the actual managed Google and
Microsoft registrations plus the protected originals in GitHub Actions, then
explicitly request the production path from `main`:

```bash
gh workflow run flutter-linux.yml --ref main -f production_release=true
```

Manual Linux runs from other branches fail. The production path runs the CI
checks, strictly validates the release configuration, verifies that the
configured registrations reached the binary, and builds, installs, and
verifies the strict Snap before uploading `busymax-linux-production-snap`.
Missing, invalid, or synthetic production registrations fail the run. The
artifact is retained for seven days; the workflow does not publish to the
Snap Store. A manual run without `production_release` selected remains
non-production CI. Managed Microsoft connections always use `common`, and
the app registration must support both personal and organizational accounts.

### Local scaffold helper

For quick local scaffold testing, quit every BusyMax window and tray process,
then run:

```bash
./tool/build_install_snap_local.sh \
  --dart-define-from-file .snap-local/busymax-dart-defines.json
```

The helper repacks `/snap/busymax/current`, or the directory passed with
`--scaffold`, around a newly built bundle. It is not the canonical Snapcraft
build and must not be published. Leave `--root` at its safe default. The helper
does not purge application data. Use `--skip-tests` only for a repeat build of
the same validated revision. **`--no-run` still installs the package; it only
suppresses launch.**

## Inspect and install the exact artifact

Set the actual artifact path, then record its metadata and checksum:

```bash
SNAP_FILE=./busymax_RELEASE_VERSION_amd64.snap
unsquashfs -cat "$SNAP_FILE" meta/snap.yaml |
  sed -n '/^name:/p;/^version:/p;/^grade:/p;/^confinement:/p'
sha256sum "$SNAP_FILE"
```

Confirm that the package is strict and contains one top-level launcher:

```bash
unsquashfs -ll "$SNAP_FILE" |
  sed -nE 's#^.*squashfs-root/meta/gui/([^/]+\.desktop)$#\1#p'
```

The launcher output must contain only `busymax.desktop`.
`share/applications/io.busystack.busymax.desktop` is the expected internal
desktop file.

Quit other BusyMax processes before installing:

```bash
sudo snap install --dangerous "$SNAP_FILE"
snap connections busymax
snap run busymax
```

`--dangerous` bypasses Store signature checking, not strict confinement. The
installation command does not request a purge, but preserve a backup of release
test data before any package operation.

## Release verification

Consolidate results in the release record. At minimum verify:

- the installed revision, strict confinement, single desktop launcher, tray
  actions, notifications, startup, and restart;
- Google and Microsoft browser sign-in and Apple/Nextcloud connection,
  reconnect, revocation, read-only permissions, and synchronization;
- event and provider-supported task create/edit/complete/delete, recurrence,
  alarms, imports/exports, WebCal, conflict behavior, and offline recovery;
- external location/link opening as described in the
  [privacy and data map](privacy_data_map.md), without an embedded map or
  mapping credential;
- the strict-Snap Secret portal credential store across quit and desktop
  restart, followed by account removal;
- network, DNS, and platform TLS failures;
- UI, themes, scaling, localization, calendar views, and tray Agenda targeting;
  and
- upgrade of a copy of data from the last release plus the supported migration
  fixture through the complete current migration chain, preserving credentials,
  provider state, cached content, pending work, conflicts, and supplemental
  location ownership.

Do not use production personal data for release testing.

## Publish an authorized beta

Authenticate and upload the verified artifact once:

```bash
snapcraft login
snapcraft whoami
snapcraft upload --release=beta "$SNAP_FILE"
snapcraft revisions busymax --arch amd64
snapcraft status busymax --arch amd64
```

Record the numeric Store revision printed for the verified checksum. It is an
immutable upload identifier, not the application version. Do not re-upload
while review or release is pending.

The `busymax-dbus` session D-Bus slot can require manual review. If an older
obsolete revision blocks the candidate, reject only that obsolete revision;
otherwise wait or contact the
[Store reviewers](https://forum.snapcraft.io/c/store-requests/19).
`resource-not-ready` or inconsistent-state errors do not prove a release.
Check the publisher dashboard before retrying.

If review completes without automatic release, release the exact reviewed
revision:

```bash
snapcraft release busymax STORE_REVISION beta
snapcraft status busymax --arch amd64
```

The recipe uses `grade: devel`, so it can release only to beta or edge. A
candidate or stable release requires changing the grade, rebuilding, and
repeating artifact verification.

## Verify the Store revision

Prefer a separate test machine:

```bash
sudo snap install busymax --beta
snap info busymax
snap run busymax
```

For an existing beta-tracking install:

```bash
sudo snap refresh busymax --channel=beta
snap info busymax
```

Repeat the installed-package checks against the Store-delivered revision.
Record its revision, channel, checksum, test machine, and results without
account identities, credentials, DAV paths, or calendar/task content.

Official references:
[Snapcraft build environments](https://documentation.ubuntu.com/snapcraft/stable/reference/build-environment-options/),
[upload](https://documentation.ubuntu.com/snapcraft/stable/reference/commands/upload/),
and
[revision management](https://documentation.ubuntu.com/snapcraft/stable/how-to/publishing/manage-revisions-and-releases/).
