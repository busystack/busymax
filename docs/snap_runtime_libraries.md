# core24 runtime library investigation

Checked 2026-10-11 with Snapcraft 9.1.4, core24 revision 2124,
GNOME 46-2404 revision 168 and mesa-2404 revision 1839. The installed BusyMax
v0.3.0 revision x3 was used only to establish runtime provenance; it is not
v0.3.1 acceptance evidence. The local release command repeats resolution in a
fresh Ubuntu 24.04 VM against the exact new package and its checksum.

Inside `snap run --shell busymax`, `ldd` on the runner, Flutter engine and
libgweather resolved the reported libraries as follows:

| Libraries | Runtime supplier | Observed path prefix |
|---|---|---|
| `libX11.so.6`, `libXdamage.so.1`, `libXext.so.6`, `libXfixes.so.3` | mesa-2404, through GNOME extension GPU content plug | `$SNAP/gpu-2404/usr/lib/x86_64-linux-gnu/` |
| `libwayland-client.so.0`, `libwayland-cursor.so.0`, `libwayland-egl.so.1` | same GPU content mount | same |
| `libxcb-shm.so.0`, `libxcb.so.1`, `libxml2.so.2` | same GPU content mount | same |
| GTK, GLib and ordinary desktop integration libraries | GNOME content runtime and some BusyMax staged package dependencies | `$SNAP/gnome-platform/usr/lib/x86_64-linux-gnu/` and `$SNAP/usr/lib/x86_64-linux-gnu/` |
| Base system dependencies such as `libcap.so.2`, `liblz4.so.1`, `libbsd.so.0` | core24 runtime | `/usr/lib/x86_64-linux-gnu/` inside the confined namespace |

`snap connections busymax` confirmed connected GNOME, GPU, GTK themes, desktop,
X11, Wayland, OpenGL and network/network-bind plugs. The GPU libraries above
are not supplied by core24 alone. Testing only host `ldd` or only unpacked
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
because an ELF linter labels them unused. The pre-existing exclusion of
`libdartjni.so` remains: the Linux runner does not register/use Android JNI and
there is no JVM in the package.

[Canonical's library-linter guidance](https://ubuntu.com/docs/snapcraft/9/how-to/debugging/use-the-library-linter/)
requires staging packages for actually missing dependencies and explains why
dynamically loaded libraries may appear unused. No broad `lint.ignore` entries
have been added. If a new package cannot resolve a dependency after content
mounts are active, treat that as a packaging defect and fail the release.
Record remaining warnings with their exact runtime supplier and test evidence.

`tool/release/verify_snap_runtime.sh` creates a fresh tagged Ubuntu 24.04 LXD VM,
installs the exact candidate, checks all packaged ELF libraries in the confined
runtime, then starts/restarts under X11 and starts under headless Wayland. It
also checks confined DNS/TCP reachability. The VM is removed only when its
ownership tag matches this invocation. Existing instances are never reused.
Manual file-picker, tray, notification, browser callback, Secret portal and
real provider tests remain necessary; headless startup cannot establish those.
The core24 recipe always packages in Snapcraft's isolated LXD environment,
without destructive builds on the Ubuntu 26.04 host. See
[Canonical's build environment guidance](https://documentation.ubuntu.com/snapcraft/stable/reference/build-environment-options/).
