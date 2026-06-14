# BusyMax Beta Snap Release

BusyMax `0.1.0+1` is a beta release target for public/listed visibility in
Ubuntu App Center and the Snap Store.

## Build

The snap build requires OAuth configuration at build time. Do not commit real
values.

```bash
mkdir -p .snap-local
$EDITOR .snap-local/busymax-dart-defines.json
snapcraft pack --use-lxd
```

The ignored `.snap-local/busymax-dart-defines.json` file must contain the
required Dart defines. The build fails if that local file is missing.

## Install The Beta

For local validation:

```bash
sudo snap install --dangerous busymax_0.1.0+1_amd64.snap
```

For store users after the revision is uploaded and released to beta:

```bash
sudo snap install busymax --beta
```

## Scope

- Snap confinement is strict.
- The tray/status-notifier feature and background-on-close behavior are enabled
  by default for the beta. Users can disable them in settings.
- The tray menu is intentionally simple: Open BusyMax, Agenda, and Quit.
- The tray Agenda action opens the compact Agenda utility window. On GNOME
  Wayland this window is a normal top-level utility window and may be placed by
  Mutter instead of under the tray icon. Under X11/XWayland, BusyMax requests a
  top-right position when the backend supports absolute movement.
- Settings, task data, and token metadata are stored inside the snap user data
  sandbox. Normal app restarts preserve data. Removing the snap removes user
  data unless snapd creates and restores a snapshot.
- OAuth uses the system browser and a local loopback callback listener.
- OAuth tokens use the XDG Secret portal in the snap to retrieve a
  per-application encryption secret, then store only AES-GCM ciphertext under
  `XDG_DATA_HOME`. BusyMax must not require the `password-manager-service`
  interface.

## Validation Matrix

Record the exact desktop environments tested before upload:

- Ubuntu GNOME on Wayland: pending local installed-snap validation.
- Ubuntu GNOME on X11/XWayland: pending local installed-snap validation.

Required smoke checks before upload:

- Launch from terminal and desktop launcher.
- Google and Microsoft sign-in open in the browser and complete the loopback
  callback.
- Secure token storage survives app restart.
- `grep -R` over snap user data does not show plaintext OAuth tokens.
- Settings and task data survive app restart.
- Notifications appear through the desktop notification service.
- Tray icon appears, the menu opens, Open BusyMax restores the existing main
  window, Agenda opens the compact Agenda window, and Quit exits cleanly.
- Compact Agenda data loads through the main-window bridge without opening a
  second migrating SQLite connection.

## Reporting Bugs

Report beta issues at https://github.com/busystack/busymax/issues.

Source code is available at https://github.com/busystack/busymax.
