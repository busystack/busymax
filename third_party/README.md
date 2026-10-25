# Third-party dependencies

BusyMax consumes official, unmodified upstream packages. Exact package versions
and publisher archive hashes are recorded in `pubspec.lock`; Pub resolves their
published source. Local path overrides and downstream dependency patches are
not supported.

| Package | Version | Upstream | License |
|---|---|---|---|
| fluent_ui | 4.16.1 | https://pub.dev/packages/fluent_ui/versions/4.16.1 | BSD-3-Clause |
| flutter_timezone | 5.1.0 | https://pub.dev/packages/flutter_timezone/versions/5.1.0 | Apache-2.0 |
| tray_manager | 0.5.3 | https://pub.dev/packages/tray_manager/versions/0.5.3 | MIT |
| yaru_window | 0.2.2 | https://pub.dev/packages/yaru_window/versions/0.2.2 | MPL-2.0 |
| xdg_status_notifier_item | 0.0.1 | https://pub.dev/packages/xdg_status_notifier_item/versions/0.0.1 | MPL-2.0 |

Linux tray presentation is owned by `lib/src/platform/application_tray.dart`.
It composes the upstream client's public registration and menu serialization
APIs with application identities and presentation. Windows clock draft behavior
is owned by `lib/src/ui/windows/windows_time_picker.dart`, using public Fluent
and Flutter controls. Neither integration changes upstream source.

Preserve all upstream licenses, notices and corresponding source obligations in
application distributions. Native Windows and Linux acceptance must use the
same unmodified dependency sources selected by the lockfile.
