# Third-party dependencies

BusyMax consumes official, unmodified upstream packages. Exact package versions
and publisher archive hashes are recorded in `pubspec.lock`; Pub resolves their
published source. Local path overrides and downstream dependency patches are
not supported.

| Package | Version | Upstream | License |
|---|---|---|---|
| fluent_ui | 4.16.1 | https://pub.dev/packages/fluent_ui/versions/4.16.1 | BSD-3-Clause |
| yaru_window | 0.2.2 | https://pub.dev/packages/yaru_window/versions/0.2.2 | MPL-2.0 |
| xdg_status_notifier_item | 0.0.1 | https://pub.dev/packages/xdg_status_notifier_item/versions/0.0.1 | MPL-2.0 |

Linux tray presentation is owned by `lib/src/platform/application_tray.dart`.
It composes the upstream client's public registration and menu serialization
APIs with application identities and presentation. Windows clock draft behavior
is owned by `lib/src/ui/windows/windows_time_picker.dart`, using public Fluent
and Flutter controls. Windows notification-area and time-zone services use BusyMax-owned runner
adapters through public Win32 and ICU APIs. The former tray/time-zone plugins
are no longer dependencies. These integrations do not change upstream source.

Preserve all upstream licenses, notices and corresponding source obligations in
application distributions. Native Windows and Linux acceptance must use the
same unmodified dependency sources selected by the lockfile.
