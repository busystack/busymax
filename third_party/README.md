# Third-Party Dependencies

This directory contains third-party source that is vendored into BusyMax.

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

Plan:

- Keep the vendored package scoped to tray support only.
- Do not commit build artifacts, generated outputs, or dependency caches under
  `third_party`.
- Upstream the StatusNotifierItem/DBusMenu fixes where practical, or replace
  this vendored copy with a maintained pub.dev release once the required
  behavior is available.
