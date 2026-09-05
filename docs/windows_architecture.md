# Windows architecture

BusyMax has one domain and data model with two desktop compositions.

```text
domain / providers / repositories / Drift / sync / OAuth / recurrence
                         |
             common desktop interfaces
                 /                   \
      Linux composition          Windows composition
      MaterialApp.router         FluentApp.router
      Yaru + GTK/DBus/XDG        Fluent + Win32/MSIX
```

`lib/main.dart` delegates to `lib/main_linux.dart` to preserve the existing
Linux default. Windows build commands explicitly select `lib/main_windows.dart`.
`LinuxBusyMaxApp` retains Material/Yaru, Ubuntu localization delegates, and the
GTK header-bar integration. `WindowsBusyMaxApp` owns the Fluent root and does
not import the Linux composition.

## Dependency boundaries

Common application, domain, repository, synchronization, OAuth, recurrence,
database, and scheduling code can depend on Flutter primitives and BusyMax
types. It cannot import Yaru, Fluent UI, Ubuntu/GTK/DBus/XDG implementations, or
Windows runner adapters. Platform code translates native/package types into
BusyMax-owned models at the boundary.

The injected desktop interfaces are:

- `DesktopWindowService`
- `DesktopTrayService`
- `DesktopAutostartService`
- `DesktopNotificationBackend`
- `DesktopActivationService`
- `SystemAppearanceSource`
- `LocalTimeZoneSource`

The automated policy is implemented by `tool/check_platform_boundaries.dart`
and runs in Linux and Windows CI.

`tray_manager` 0.5.3 and `flutter_timezone` 5.1.0 are pinned through committed
Windows-only packaging of their upstream plugins. This prevents Flutter's
generated Linux plugin graph from registering a second AppIndicator tray or
replacing the existing Linux timezone path. The boundary check requires both
plugins only in the Windows graph. Their Dart APIs, Windows sources, versions,
and upstream licenses are preserved.

## Window and single instance

The Win32 runner uses the standard Windows title bar, caption buttons, system
menu, maximize/restore behavior, and per-monitor-v2 DPI awareness. Flutter
content begins below the non-client title bar. Minimum tracking size is
900x600 logical pixels and the initial content size is 1280x800.

One process per Windows user owns a named mutex containing that user's SID.
Later processes validate a bounded activation, connect to a local named pipe
whose DACL grants only the current SID, forward a length-prefixed UTF-8 message,
and wait for a one-byte acceptance acknowledgment before exiting. Connection
retries cover the bounded interval between the primary acquiring its mutex and
creating its first pipe instance. The secondary allows the primary process to
take foreground focus and never starts Dart or Drift. The primary acknowledges
only after it validates and queues the activation until the method channel is
ready. No second package owns window lifecycle.

The native single-instance IPC accepts only exact runner-generated normal,
`--start-minimized`, `.ics`, `webcal:`, and bounded notification JSON shapes. It
rejects unsupported kinds, actions, schemes, files, fields, malformed
UTF-8/JSON, NULs, and oversized data; Dart independently validates the common
activation model again.

Toast callbacks normally arrive through the notification plugin's registered
COM activator in the primary process. If Windows starts an activation-server
process while the primary process already owns the mutex, the runner starts a
private, hidden forwarding mode instead of the application composition. That
mode initializes only the notification callback, starts no providers or Drift
database, forwards the validated stable-ID activation through the same
current-user pipe, and exits. This preserves notification actions without ever
letting a second process open BusyMax data.

## Lifecycle and tray

The Windows tray adapter uses `tray_manager`; Linux retains its DBus/XDG
adapter. Shared presentation state supplies Open BusyMax, new event, new task,
today/agenda, synchronize, Settings, and Quit. Close hides only when the setting
is enabled and the tray is available. A failed tray causes the sole window to
remain visible. The icon and menu are periodically reapplied so Explorer's
notification-area restart can recover.

Explicit Quit stops reminder and synchronization schedulers, destroys the tray,
disposes the Windows notification backend, closes Drift, and finally requests
native termination. Closing without background mode exits through the normal
runner lifecycle.

## Activation routes

Manifest `.ics` and `webcal` activations enter the same single-instance bridge.
An `.ics` file always opens the existing review and confirmation flow; it is
never imported silently. A `webcal:` URI opens the existing subscription
confirmation. Cold and warm delivery use the same common activation model.

Windows toast activation uses `flutter_local_notifications` with stable AUMID
and committed CLSID `7B854A6D-8B2A-45A5-B998-1F51EC5A81D7`. Toast arguments
contain only stable internal IDs. Body, Open, Snooze, and Dismiss callbacks are
routed to the idempotent scheduler action handler; event and task text is not
placed in activation arguments.

## Startup and timezone

The MSIX declares one disabled-by-default `BusyMaxStartupTask`. The runner uses
the packaged StartupTask API and preserves enabled, disabled, user-disabled,
policy-disabled, and unpackaged states. There is no registry or Startup-folder
fallback.

`flutter_timezone` supplies the Windows system IANA zone. Recognized IANA values
are used directly; a deterministic Windows-ID mapping covers defensive fallback
cases. An unrecognized or unavailable result records a non-sensitive diagnostic
and falls back to `Etc/UTC`, never an assumed local zone. Timezone search uses
BusyMax's generic IANA catalog, not GWeather.
