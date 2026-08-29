# Third-Party Dependencies

This directory contains third-party source vendored into BusyMax. Direct Dart
dependencies with security or licensing significance are also listed here.

## xml

- Package: `xml`
- Pinned version: `6.6.1`
- Source: https://github.com/renggli/dart-xml
- License: MIT
- Purpose: namespace-aware WebDAV/CalDAV XML parsing
- Native/transitive review: pure Dart; no transitive native dependency is
  introduced by this direct dependency.

BusyMax applies its own parser limits and rejects DTD and entity declarations.
DAV properties are identified by namespace URI and local name, not by prefix.

## posix

- Package: `posix`
- Pinned lockfile version: `6.5.0`
- Source: https://github.com/onepub-dev/dart_posix
- License: MIT
- Purpose: apply restrictive `0700` directory and `0600` file modes to the
  strict-Snap portal-encrypted credential store
- Native/transitive review: Dart FFI calls the platform C library; BusyMax uses
  only `chmod`, only on Linux/macOS, and maps failures to the typed
  secret-store-unavailable state.

The encrypted credential store repairs inherited permissions before reading
and creates replacement files atomically. See
[`docs/icalendar_data_model.md`](../docs/icalendar_data_model.md) for the
CalDAV and iCalendar dependency decision.

## xdg_status_notifier_item

- Package: `xdg_status_notifier_item`
- Vendored path: `third_party/xdg_status_notifier_item`
- Original pub.dev package: `xdg_status_notifier_item` version `0.0.1`
- Original source: https://github.com/canonical/xdg_status_notifier_item.dart
- License: Mozilla Public License 2.0 (`MPL-2.0`)

BusyMax vendors this package because Linux tray support depends on
StatusNotifierItem and DBusMenu behavior that is not available in the published
`0.0.1` pub.dev release.

The vendored package keeps its upstream `LICENSE` file in
`third_party/xdg_status_notifier_item/LICENSE`. MPL-2.0 is compatible with
including the package in BusyMax's Apache-2.0 larger work, provided the
MPL-2.0-covered files and any modifications to those files remain available
under MPL-2.0 and the license notices are preserved.

BusyMax-specific patches currently include:

- Widening the package SDK constraint to support Dart 3.
- Exporting DBusMenu objects at the StatusNotifierItem menu path used by
  BusyMax.
- Supporting explicit, stable DBusMenu item IDs.
- Adding DBusMenu `GetGroupProperties` support and menu object properties.
- Supporting both `org.kde.StatusNotifierItem` and
  `org.freedesktop.StatusNotifierItem` interfaces.
- Fixing StatusNotifierItem callback argument handling for x/y, scroll delta,
  and scroll orientation values.
- Adding `ItemIsMenu`, custom menu path, object path accessors, and diagnostic
  logging hooks used by BusyMax tray tests and runtime diagnostics.
- Supporting runtime title, icon, and tooltip updates with the standard
  StatusNotifierItem change signals.
- Correcting the StatusNotifierItem tooltip signature and exposing its title
  and description to desktop hosts and assistive technologies.

### Maintenance

- Upstream the StatusNotifierItem/DBusMenu fixes where practical, or replace
  this vendored copy with a maintained pub.dev release once the required
  behavior is available.
