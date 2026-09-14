# BusyMax vendoring notes: tray_manager

This directory contains the Dart API and Windows implementation from upstream
[tray_manager 0.5.3](https://github.com/leanflutter/tray_manager) under the
included [MIT license](LICENSE).

BusyMax omits Linux and macOS plugin registrations. Windows uses this tray
plugin and its BusyMax native test surface; Linux retains the existing XDG/DBus
tray implementation.
