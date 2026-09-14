# BusyMax vendoring notes: yaru_window

This directory contains the public Dart API from upstream
[yaru_window 0.2.2](https://github.com/ubuntu/yaru_window.dart) under the
included [MPL-2.0 license](LICENSE).

BusyMax narrows plugin registration to Linux, where the upstream
`yaru_window_linux` implementation remains in use. The upstream Windows path
would register a second window lifecycle implementation, so the BusyMax
Windows composition uses only its native runner bridge.
