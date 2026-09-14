# BusyMax vendoring notes: flutter_timezone

This directory contains the Dart API and Windows implementation from upstream
[flutter_timezone 5.1.0](https://github.com/tjarvstrand/flutter_timezone) under
the included [Apache-2.0 license](LICENSE).

BusyMax omits non-Windows plugin registrations so Windows uses the upstream
plugin while Linux retains its existing timezone sources. The override is not a
general fork for other platforms.
