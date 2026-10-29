# core24 runtime libraries

Validate runtime-library resolution against the exact candidate Snap and its
checksum in a fresh Ubuntu 24.04 VM. The confined runtime includes core24,
GNOME 46-2404 and mesa-2404 content mounts as well as BusyMax's staged libraries.

Inside `snap run --shell busymax`, run `ldd` on the runner, Flutter engine and
libgweather. Check these runtime suppliers:

| Libraries | Runtime supplier | Confined path prefix |
|---|---|---|
| `libX11.so.6`, `libXdamage.so.1`, `libXext.so.6`, `libXfixes.so.3` | mesa-2404, through GNOME extension GPU content plug | `$SNAP/gpu-2404/usr/lib/x86_64-linux-gnu/` |
| `libwayland-client.so.0`, `libwayland-cursor.so.0`, `libwayland-egl.so.1` | same GPU content mount | same |
| `libxcb-shm.so.0`, `libxcb.so.1`, `libxml2.so.2` | same GPU content mount | same |
| GTK, GLib and ordinary desktop integration libraries | GNOME content runtime and some BusyMax staged package dependencies | `$SNAP/gnome-platform/usr/lib/x86_64-linux-gnu/` and `$SNAP/usr/lib/x86_64-linux-gnu/` |
| Base system dependencies such as `libcap.so.2`, `liblz4.so.1`, `libbsd.so.0` | core24 runtime | `/usr/lib/x86_64-linux-gnu/` inside the confined namespace |

Use `snap connections busymax` to verify connected GNOME, GPU, GTK themes,
desktop, X11, Wayland, OpenGL and network/network-bind plugs. The GPU libraries
above are not supplied by core24 alone. Testing only host `ldd` or only unpacked
BusyMax files omits these content mounts and gives incomplete results. Fresh
runtime checks must include the extension's command chain, connected content
snaps and strict confinement.

The recipe explicitly stages fonts-noto-core, libhandy-1-0, libgweather-4-0t64,
liblzma5 and libsecret-1-0 with their package dependencies. libhandy is used by
`linux/runner/my_application.cc` (`hdy_init`, native windows and preference
rows). libgweather is dynamically opened by
`lib/src/core/time/linux_gweather_location_source.dart`; its `Locations.bin`
is required. Fonts are loaded by Fontconfig rather than an ELF dependency.
Secret-storage plugins require libsecret. These must not be removed merely
because an ELF linter labels them unused. The recipe excludes `libdartjni.so`:
the Linux runner does not register/use Android JNI and
there is no JVM in the package.

The registration-reader library is loaded through Dart FFI, and libgweather is
explicitly opened at runtime. Evaluate libdconf and libcolordprivate with their
dynamically loaded consumers, including GNOME's GIO dconf settings backend.
Before removing staged copies, verify that the content runtime supplies them
and that interactive settings and color integration work with the exact
candidate. An unused warning alone is insufficient evidence for removal.

The verifier runs the desktop checks as an ordinary user with a systemd user
manager and session bus. Running from LXD's root agent service does not model a
desktop login and can prevent snapd from creating its application cgroup. See
the [snapd maintainer's explanation](https://forum.snapcraft.io/t/cannot-launch-snap-applications-with-cgroup-v2/27700).

[Canonical's library-linter guidance](https://ubuntu.com/docs/snapcraft/9/how-to/debugging/use-the-library-linter/)
requires staging packages for actually missing dependencies and explains why
dynamically loaded libraries may appear unused. If a candidate cannot resolve
a dependency after content mounts are active, treat that as a packaging defect
and fail the release.
Record remaining warnings with their exact runtime supplier and test evidence.

`tool/release/verify_snap_runtime.sh` creates a fresh tagged Ubuntu 24.04 LXD VM,
installs the exact candidate, checks all packaged ELF libraries in the confined
runtime, then starts/restarts under X11 and starts under headless Wayland. It
also checks confined DNS/TCP reachability. The VM is removed only when its
ownership tag matches this invocation. Existing instances are never reused.
Manual file-picker, tray, notification, browser callback, Secret portal and
real provider tests remain necessary; headless startup cannot establish those.
The core24 recipe packages in Snapcraft's isolated LXD environment. See
[Canonical's build environment guidance](https://documentation.ubuntu.com/snapcraft/stable/reference/build-environment-options/).
