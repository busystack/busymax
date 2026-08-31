# BusyMax tray_manager packaging

This directory contains the API and Windows implementation from upstream
`tray_manager` 0.5.3 under its original license. The Linux and macOS plugin
registrations are intentionally omitted: BusyMax Linux retains its existing
DBus/XDG tray implementation, while this package is used only by the Windows
composition.
