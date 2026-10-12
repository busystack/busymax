# Local Snap beta release

Official Linux Snaps are built locally from an exact committed revision with
`tool/release/build_snap_local.sh`. GitHub Actions verifies source, tests and an
unconfigured packaging smoke build. It supplies no production Snap or source
archive and requires no OAuth variables or secrets. Source archives remain
available explicitly through `python3 tool/package_source.py`.

## Local configuration

Keep the downloaded Google **Desktop** OAuth JSON outside the repository.
Select it with `--google-oauth /path/to/download.json`, or select a directory
containing exactly one `.json` file. Multiple candidates require an explicit
filename; the command never guesses. The file must contain `installed.client_id`,
`installed.client_secret` and `installed.project_id`. Web clients, service
accounts, malformed/incomplete files and known synthetic CI values are rejected.

These fields become `BUSYMAX_GOOGLE_OAUTH_CLIENT_ID`,
`BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET` and `BUSYMAX_GOOGLE_OAUTH_PROJECT_ID`
automatically. No separate project-ID entry is needed. They designate the active
managed registration and enable **Connect with BusyMax**. The retiring
`GOOGLE_OAUTH_*` configuration is not needed for this local release and the new
client is never written into those original-registration fields. Custom Desktop
JSON and Workspace setup remain available in the app.

Put additional public configuration in ignored `config/release.local.json`
(mode `0600`), passed with `--local-config`:

```json
{
  "MICROSOFT_OAUTH_CLIENT_ID": "EXISTING_MICROSOFT_PUBLIC_CLIENT_ID",
  "MICROSOFT_OAUTH_AUTHORITY_TENANT": "common"
}
```

Use the existing Microsoft public client ID and its actual established authority;
there is no Microsoft client secret. `BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID` is optional
and should only be supplied when a real managed registration exists. No new
Microsoft registration is required. Apple/Nextcloud passwords and account tokens
never belong in release configuration. The privacy-policy URL is fixed product
metadata: `https://busystack.org/privacy-busymax`.

Generated Flutter defines are written outside the Snapcraft source with mode
`0600` and removed after compilation/binary inspection, including on failure.
The downloaded JSON is never copied into the workspace or Snap. Installed-app
client configuration can be extracted from the distributed binary; it is not a
server-side credential. See [Google's OAuth overview](https://developers.google.com/identity/protocols/oauth2).

## One supported build command

Prerequisites: Linux amd64, Flutter **3.47.5** and its bundled Dart **3.13.4**,
Snapcraft **9.1.4**, snapd, configured LXD, `squashfs-tools`, and the Linux native
build/test dependencies listed in [Development](development.md). The runtime
verifier creates a new tagged Ubuntu 24.04 VM; the host needs VM-capable LXD.
The source checkout must be clean on `release/vVERSION` or `main`, match the
explicit revision, and incorporate fetched `origin/main`.

```bash
tool/release/build_snap_local.sh \
  --version 0.3.2 \
  --revision "$(git rev-parse HEAD)" \
  --google-oauth /path/to/google-desktop-download-directory \
  --local-config config/release.local.json \
  --workspace /path/to/new-release-workspace
```

The workspace must not exist. It contains independent `busymax/`,
`busystack_contacts/`, `busystack_dav/` and `busystack_graph/` Git checkouts.
Dependencies are materialized at the exact manifest revisions. Existing sibling
repositories and earlier worktrees remain untouched. Failed workspaces are
retained for inspection; choose a new path for another attempt. No reset,
forced worktree removal, or destructive cleanup is used.

The command checks all five version files before compiling; it never rewrites
them. v0.3.2 uses Android code **7**. It resolves the lockfile,
generates/rechecks localization and Drift,
runs formatting, analysis, platform boundaries, full Flutter/tool/native tests,
and compiles a fresh configured bundle. It verifies the actual managed Google
configuration in `libapp.so`, runs canonical Snapcraft packaging with
`--use-lxd`. Its output stays inside the checkout during the LXD pack step,
then the exact package moves to `artifacts/`. The command checks version,
strict confinement, launchers and
assets. An old bundle cannot enter the new checkout. The recipe remains
`base: core24`, `grade: devel`, `confinement: strict`.

It then checks ELF resolution, X11/Wayland startup, restart and confined network
access in a fresh Ubuntu 24.04 VM. Runtime failures stop the build. A successful
command prints the exact Snap path last and writes its SHA-256 file, redacted
build log, runtime evidence and `artifacts/manifest.json`. The manifest records
`status: candidate` and `release_ready: false` until interactive/provider
acceptance is completed. Compilation and packing alone never establish release
readiness. Failed builds emit no success manifest. Nothing is installed on the
owner's desktop or uploaded automatically.

## Inspect, verify and test upgrade

Use the exact printed path throughout. In its artifacts directory:

```bash
sha256sum --check busymax_0.3.2_amd64.snap.sha256
unsquashfs -cat busymax_0.3.2_amd64.snap meta/snap.yaml
```

Confirm `0.3.2`, `core24`, `devel`, `strict`, the BusyMax launcher, its autostart
entry, desktop file, icon and AppStream history. Investigate library warnings
using [the library investigation record](snap_runtime_libraries.md); do not add
broad linter suppression. The VM evidence must show no unresolved runtime ELF
dependencies. Headless startup does not prove interactive native integration.

On a separate test machine/user session, first install the previous v0.3.0
package and prepare test accounts, cached tasks/events, disabled collection
preferences, contacts settings, conflicts and pending offline work. Back up
that test state. Quit BusyMax and upgrade using the exact candidate:

```bash
sudo snap install --dangerous /absolute/path/busymax_0.3.2_amd64.snap
snap connections busymax
snap run busymax
```

Do not purge data. Verify that the previous account remains visible and its
local content can be inspected. Its Google failure must offer **Reconnect
Google account**, select that account, and authorize through the current client.
Verify same-subject replacement, wrong-account rejection, cancellation, offline
failure and callback failure. An unverifiable legacy identity retains its local
account and offers a separate connection; pending operations must stay with the
original account. Confirm no duplicate account after successful verified
replacement, sync resumes, and restart uses the new issuing registration.

Test real Calendar/Tasks changes, read-only Contacts, Microsoft Calendar/To Do,
Nextcloud and iCloud, GTK windows and file pickers, browser loopback callbacks,
tray, Secret portal storage and notifications on X11 and Wayland sessions.
Record version/revision/checksum and results without tokens or personal content.
Review the [Google production prerequisites](desktop_oauth_release_checklist.md).

## Owner-performed upload

After interactive acceptance and provider prerequisite review, the owner uploads
only the verified checksum. The build command never publishes:

```bash
snapcraft login
snapcraft whoami
snapcraft upload --release=beta /absolute/path/busymax_0.3.2_amd64.snap
snapcraft revisions busymax --arch amd64
snapcraft status busymax --arch amd64
```

Record the immutable numeric Store revision. The `busymax-dbus` slot may require
manual Store review; wait or contact reviewers rather than repeatedly uploading.
`grade: devel` supports beta/edge only. If review completes without release, the
owner may release that exact reviewed revision with
`snapcraft release busymax STORE_REVISION beta`. Verify the Store-delivered
revision on a separate test machine. These instructions authorize no automatic
upload, release or merge.

## Development scaffold helper

`tool/build_install_snap_local.sh` remains development-only: it repacks an
installed/supplied scaffold and installs it on the local machine. It is not the
production packager and its output must not be published. `--no-run` still
installs that development package. Use the dedicated release command above for
official artifacts.
