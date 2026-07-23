# BusyMax Snap Build and Beta Release

`snap/snapcraft.yaml` packages an existing Flutter Linux bundle. It does not
run `flutter build` or read `.snap-local/busymax-dart-defines.json`, so the
OAuth-enabled Flutter build must run first.

## Prepare

Required: Linux amd64, the Flutter Linux toolchain, snapd, Snapcraft with LXD,
the `libhandy-1-dev` build package, `unsquashfs` from `squashfs-tools`, and
BusyMax Store access for publishing.

Check that the package versions match:

```bash
grep -nE '^version:|<release version=' \
  pubspec.yaml snap/snapcraft.yaml linux/io.busystack.busymax.metainfo.xml
```

`pubspec.yaml`, `snap/snapcraft.yaml`, and the newest metainfo release must
match. Older metainfo entries are history. Change these source files instead
of overriding the helper version, which would not change Flutter's embedded
version.

Create the ignored OAuth file:

```bash
mkdir -p .snap-local
$EDITOR .snap-local/busymax-dart-defines.json
chmod 600 .snap-local/busymax-dart-defines.json
```

```json
{
  "GOOGLE_OAUTH_CLIENT_ID": "your-google-client-id",
  "GOOGLE_OAUTH_CLIENT_SECRET": "your-google-client-secret",
  "MICROSOFT_OAUTH_CLIENT_ID": "your-microsoft-client-id"
}
```

See [Google Setup](google_setup.md) and
[Microsoft Setup](microsoft_setup.md). These values are embedded in the Snap
and can be extracted, so use only native Desktop/public-client credentials.
Never use server credentials or commit the JSON or generated `.snap` files.

## Build

From the repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter build linux --release \
  --dart-define-from-file=.snap-local/busymax-dart-defines.json
snapcraft pack --use-lxd
```

Snapcraft writes `busymax_<version>_amd64.snap`. Use the exact path it prints.
If the app says **This provider is not configured**, the bundle was built
without valid defines; reconnecting cannot fix it, so rebuild the package.

For a local scaffold smoke build instead, first quit every running BusyMax
instance, including its tray process and any development build:

```bash
./tools/build_install_snap_local.sh \
  --dart-define-from-file .snap-local/busymax-dart-defines.json
```

The helper requires `/snap/busymax/current` or `--scaffold DIR`, repacks and
installs the local payload, and is not the canonical Store build above. Leave
`--root` at its safe default. It does not remove or purge app data. Its
`Defines: 1` output only confirms that one file argument was passed, not that
the required values are present. Use `--skip-tests` only for a repeat build of
the same commit after its tests passed; `--no-run` still installs the package.

## Verify Locally

Set the exact artifact path:

```bash
SNAP_FILE=./busymax_RELEASE_VERSION_amd64.snap
```

Check its metadata and save its checksum:

```bash
unsquashfs -cat "$SNAP_FILE" meta/snap.yaml |
  sed -n '/^name:/p;/^version:/p;/^grade:/p;/^confinement:/p'
sha256sum "$SNAP_FILE"
```

Check the top-level launchers:

```bash
unsquashfs -ll "$SNAP_FILE" |
  sed -nE 's#^.*squashfs-root/meta/gui/([^/]+\.desktop)$#\1#p'
```

The output must contain exactly `busymax.desktop`.
`share/applications/io.busystack.busymax.desktop` is an expected internal file,
not a second top-level launcher.

Close BusyMax and its tray process, then install and launch the local package:

```bash
sudo snap install --dangerous "$SNAP_FILE"
snap connections busymax
snap run busymax
```

`--dangerous` bypasses Store signature checks, not strict confinement.

Before upload, verify:

- Desktop search shows one BusyMax launcher; both main and Agenda windows open.
- Google and Microsoft sign-in complete successfully.
- Tasks and events can be created, edited, completed, and deleted; a task
  created in Agenda appears immediately without manual refresh.
- Accounts, settings, and data survive restart.
- Notifications and tray actions, including Agenda and Quit, work.

## Upload To Beta

Authenticate if needed, then upload once with the beta release target:

```bash
snapcraft login
snapcraft whoami
snapcraft upload --release=beta "$SNAP_FILE"
snapcraft revisions busymax --arch amd64
snapcraft status busymax --arch amd64
```

Save the numeric Store revision printed for the verified checksum. It is an
immutable upload identifier, separate from the app version. Do not re-upload
the artifact because review or release is pending.

The `busymax-dbus` session D-Bus slot may trigger manual review. If an older
revision blocks the new one, reject it only when it is obsolete; otherwise
wait or contact the
[Store reviewers](https://forum.snapcraft.io/c/store-requests/19). A
`resource-not-ready` or inconsistent-state error means nothing was released.
Check the [publisher dashboard](https://dashboard.snapcraft.io/) and retry only
after review clears.

If manual review completes but the revision was not automatically released,
release the exact reviewed revision:

```bash
snapcraft release busymax STORE_REVISION beta
snapcraft status busymax --arch amd64
```

The recipe currently has `grade: devel`, so only `beta` and `edge` are allowed.
Candidate or stable requires `grade: stable`, a rebuild, a new upload, and the
same verification.

## Verify The Store Revision

Prefer a separate test machine. For a fresh install:

```bash
sudo snap install busymax --beta
snap info busymax
snap run busymax
```

For an existing Store-tracking install:

```bash
sudo snap refresh busymax --channel=beta
snap info busymax
```

Repeat the local smoke checks against the Store-delivered revision.

Official references: [build environments](https://documentation.ubuntu.com/snapcraft/stable/reference/build-environment-options/),
[upload](https://documentation.ubuntu.com/snapcraft/stable/reference/commands/upload/),
and [revision management](https://documentation.ubuntu.com/snapcraft/stable/how-to/publishing/manage-revisions-and-releases/).
