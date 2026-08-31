This is the public Dart API from upstream `yaru_window` 0.2.2, licensed under
the included LGPL-3.0 license. BusyMax narrows the plugin declaration to Linux.

The upstream package selects a `window_manager` implementation on Windows.
BusyMax has a separate native Windows runner bridge, so registering that second
window lifecycle owner would violate the Windows architecture. Linux continues
to use the upstream `yaru_window_linux` implementation unchanged.
