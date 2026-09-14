# Windows architecture

BusyMax shares its domain and data layers while keeping separate Linux and
Windows desktop compositions.

```text
providers / repositories / Drift / sync / OAuth / recurrence
                         |
              BusyMax desktop interfaces
                 /                    \
       Linux composition       Windows composition
       Material + Yaru         Fluent
       GTK/DBus/XDG            Win32/MSIX
```

`lib/main.dart` delegates to `lib/main_linux.dart` for the existing Linux
default. Windows commands explicitly select `lib/main_windows.dart`.
`LinuxBusyMaxApp` owns the Material/Yaru root and GTK integration;
`WindowsBusyMaxApp` owns `FluentApp.router` and does not import the Linux
composition.

## Shared and platform boundaries

Provider clients, repositories, synchronization, recurrence, database, account
state, editor drafts, and scheduling controllers are shared. Platform adapters
translate native or package-specific values into BusyMax-owned models.

The common desktop interfaces cover window, tray, startup, notifications,
activation, system appearance, and local timezone behavior. Windows and common
code cannot import Yaru, Ubuntu localization, DBus, freedesktop notification,
XDG tray, or GTK services. Shared business and Linux code cannot import Fluent
UI. `tool/check_platform_boundaries.dart` enforces these dependency rules.

Windows registers the vendored `tray_manager` and `flutter_timezone` plugins;
Linux retains its existing XDG tray and Linux timezone implementation. See the
[vendoring index](../third_party/README.md) for versions and local packaging
notes.

## Fluent composition

The Windows shell uses `NavigationView` for Schedule, Tasks, and Settings.
Calendar and task-list sources remain content panes and collapse at
BusyMax-controlled widths. Windows screens use Fluent controls and Fluent
System Icons while repositories, provider state, editor drafts, and mutation
controllers remain shared.

The Windows-specific day/week adapter renders shared schedule data through
`infinite_calendar_view` and supplies Fluent colors, controls, and
interactions around that planner. Linux UI, Ubuntu localization delegates, and
Yaru chrome do not enter the Windows application graph.

Theme selection follows the saved system/light/dark preference. The Windows
composition applies the system accent, opaque high-contrast colors, reduced
motion, Segoe UI Variable with the system Segoe UI fallback, Flutter text
scaling, locale direction, focus traversal, tooltips, and semantics.

The Win32 runner owns the standard non-client title bar, caption buttons,
system menu, maximize/restore behavior, and per-monitor DPI response. Flutter
does not draw duplicate window controls. The runner starts at 1280x800 logical
pixels and enforces a 900x600 logical minimum.

## Window ownership and single instance

One process per Windows user owns a named mutex containing the user's SID.
Later processes validate a bounded activation, forward it through a
current-user-only named pipe, wait for acceptance, and exit before starting
Dart or Drift. The primary queues accepted activation until its method channel
is ready.

The native bridge accepts only runner-generated normal launch,
`--start-minimized`, `.ics`, `webcal:`, and bounded notification shapes.
It rejects unsupported actions, schemes, files, fields, malformed data, and
oversized input. Dart validates the shared activation model again.

If Windows starts a toast activation server while the primary is running, the
runner enters a hidden forwarding mode. It initializes only the notification
callback, forwards the validated activation through the same pipe, and exits.
No secondary process opens BusyMax data.

## Tray and lifecycle

Windows uses `tray_manager`; Linux uses the XDG/DBus tray adapter. Shared
presentation state supplies the menu actions. Close hides the window only when
background operation is enabled and a tray is available; a tray failure keeps
the only window visible. The Windows adapter reapplies its icon and menu after
Explorer notification-area restarts.

Explicit Quit stops reminder and synchronization schedulers, destroys the
tray, disposes notifications, closes Drift, and requests native termination.
Closing when background mode is disabled follows the runner's normal exit path.

## Activation and notifications

Manifest `.ics` and `webcal:` activations use the single-instance bridge. An
iCalendar file enters the existing review and confirmation flow and is never
silently imported. A WebCal URI enters subscription confirmation. Cold and
warm activation share the same model.

Windows notifications use a stable package AUMID and the committed toast
activator CLSID. Notification title and body are passed to Windows for display.
Activation arguments contain only bounded BusyMax identifiers and action
information. Body, Open, Snooze, and Dismiss callbacks reach the idempotent
scheduler action handler.

## Startup and timezone

The MSIX declares `BusyMaxStartupTask` disabled by default. The Windows
adapter uses the packaged StartupTask API and distinguishes enabled, disabled,
user-disabled, policy-disabled, and unpackaged states. There is no registry or
Startup-folder fallback.

`flutter_timezone` supplies the Windows system IANA zone. Recognized IANA
values are used directly; a deterministic Windows-ID mapping handles fallback
values. An unavailable or unknown zone records a non-sensitive diagnostic and
uses `Etc/UTC`. Windows timezone search uses BusyMax's IANA catalog rather
than the Linux GWeather source.

Native rendering, activation, DPI, accessibility, and installed-package
verification belong in the
[Windows release checklist](windows_release_checklist.md).
