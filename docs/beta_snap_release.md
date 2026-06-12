# BusyMax Beta Snap Release

BusyMax `0.1.0+1` is a beta release target for public/listed visibility in
Ubuntu App Center and the Snap Store.

## Build

The snap build requires OAuth configuration at build time. Do not commit real
values.

```bash
export GOOGLE_OAUTH_CLIENT_ID=<google-desktop-client-id>
export GOOGLE_OAUTH_CLIENT_SECRET=<google-desktop-client-secret>
export MICROSOFT_OAUTH_CLIENT_ID=<microsoft-public-client-id>
snapcraft pack
```

The build fails if any required OAuth value is missing.

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
- The tray/status-notifier feature is available but disabled by default for the
  beta. Users can enable it in settings.
- Settings, task data, and token metadata are stored inside the snap user data
  sandbox. Normal app restarts preserve data. Removing the snap removes user
  data unless snapd creates and restores a snapshot.
- OAuth uses the system browser and a local loopback callback listener.

## Validation Matrix

Record the exact desktop environments tested before upload:

- Ubuntu GNOME on Wayland: pending local installed-snap validation.
- Ubuntu GNOME on X11/XWayland: pending local installed-snap validation.

Required smoke checks before upload:

- Launch from terminal and desktop launcher.
- Google and Microsoft sign-in open in the browser and complete the loopback
  callback.
- Secure token storage survives app restart.
- Settings and task data survive app restart.
- Notifications appear through the desktop notification service.
- Tray opt-in either works or fails without crashing.

## Reporting Bugs

Report beta issues at https://github.com/busystack/busymax/issues.

Source code is available at https://github.com/busystack/busymax.
