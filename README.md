# BusyMax

BusyMax is a beta calendar and task manager for Android, Linux, and Windows. It
brings events, tasks, reminders, and day, week, month, year, and agenda views
into one application.

Linux uses a Yaru/GTK desktop composition with XDG integrations. Windows uses
a separate Fluent composition with a native Windows title bar, tray,
notifications, and packaged startup integration. Android uses a separate
adaptive Material 3 composition, native account authorization, WorkManager,
Android notifications, and the Storage Access Framework. Provider capabilities differ;
see the [provider support matrix](docs/provider_support_matrix.md) before
relying on a particular task field or operation.

[![Install BusyMax from the Snap Store](https://snapcraft.io/busymax/badge.svg)](https://snapcraft.io/busymax)

<p align="center">
  <img src="docs/screenshots/main_window_month.png"
       alt="BusyMax month view on Linux"
       width="900">
</p>

<p align="center"><sub>Month view in the Linux desktop application.</sub></p>

## Highlights

- Calendar and task planning in day, week, month, year, and agenda views.
- Direct connections to Google, Microsoft, Apple iCloud Calendar, and
  Nextcloud, plus read-only WebCal subscriptions.
- Event and task editing that follows each provider's supported fields and the
  permissions granted for a collection.
- Local caching for offline viewing. Supported changes can be queued for some
  providers; offline behavior is not identical across every integration.
- Platform-native reminders, Android document import/export, desktop tray
  actions, themes, keyboard navigation, and localized interfaces.

<details>
<summary>More Linux screenshots</summary>

<table>
  <tr>
    <td><img src="docs/screenshots/main_window_week.png" alt="BusyMax week view on Linux"><br><sub>Week view</sub></td>
    <td><img src="docs/screenshots/main_window_day.png" alt="BusyMax day view on Linux"><br><sub>Day view</sub></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/main_window_agenda.png" alt="BusyMax agenda view on Linux"><br><sub>Agenda view</sub></td>
    <td><img src="docs/screenshots/main_window_year.png" alt="BusyMax year view on Linux"><br><sub>Year view</sub></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/main_window_new_task.png" alt="BusyMax task editor on Linux"><br><sub>Task editor</sub></td>
    <td><img src="docs/screenshots/main_window_edit_event.png" alt="BusyMax event editor on Linux"><br><sub>Event editor</sub></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/account_provider_selection.png" alt="BusyMax account provider selection on Linux"><br><sub>Account providers</sub></td>
  </tr>
</table>

</details>

## Installation and accounts

The public packaged release is the Linux beta in the
[Snap Store](https://snapcraft.io/busymax). The repository does not document a
public production Windows download or Store listing. Windows maintainers can
build and install a test-signed package by following the
[Windows packaging guide](docs/windows_packaging.md); unsigned CI packages are
test artifacts, not ordinary user downloads.

Packaged users do not need Flutter, Visual Studio, Linux development libraries,
or their own OAuth registration. In a configured build:

- Desktop Google and Microsoft accounts connect through browser-based sign-in.
  Android uses Google Play services authorization for Google and MSAL's
  registered browser redirect for Microsoft.
- Apple iCloud Calendar uses an Apple app-specific password; Apple Reminders is
  not supported. See [Connect Apple iCloud Calendar](docs/apple_icloud_setup.md).
- Nextcloud authorizes BusyMax in the default browser and requires a compatible
  HTTPS server. See [Connect Nextcloud Calendar and Tasks](docs/nextcloud_setup.md).
- WebCal adds a read-only calendar subscription from a confirmed URL.

Developers who need to configure their own desktop OAuth applications should
use the [Google OAuth registration guide](docs/google_setup.md) or
[Microsoft OAuth registration guide](docs/microsoft_setup.md). Provider
differences and limitations are summarized in the
[provider support matrix](docs/provider_support_matrix.md).

### Android development build

Android support targets API 37 with a minimum API of 24 and uses the explicit
entrypoint `lib/main_android.dart`. It requires Flutter 3.47.4, bundled Dart
3.13.3, JDK 17, Android platform 37, and Build Tools 37.x.

```sh
tool/android/check_prerequisites.sh
cp android/busymax.android.properties.example android/busymax.android.properties
tool/android/run.sh --device DEVICE_ID
```

The copied public configuration needs real Microsoft and certificate-specific
provider registrations before those sign-in flows work. It contains no client
secret. See [Android setup](docs/android_setup.md), [Android release](docs/android_release.md),
and the [Android verification report](docs/android_verification.md). Generated
test-signed artifacts are not production releases.

## Documentation

Account, provider, and data information:

- [Provider support matrix](docs/provider_support_matrix.md)
- [Apple iCloud Calendar setup](docs/apple_icloud_setup.md)
- [Nextcloud Calendar and Tasks setup](docs/nextcloud_setup.md)
- [Privacy and data map](docs/privacy_data_map.md)
- [Android setup and OAuth registration](docs/android_setup.md)
- [Android provider parity](docs/android_provider_parity.md)

Development and maintenance:

- [Development setup for Linux and Windows](docs/development.md)
- [Android release](docs/android_release.md), [verification](docs/android_verification.md),
  and [implementation status](docs/android_implementation_status.md)
- [Google developer OAuth registration](docs/google_setup.md) and
  [Microsoft developer OAuth registration](docs/microsoft_setup.md)
- [iCalendar and DAV data model](docs/icalendar_data_model.md)
- [Live-provider testing](docs/live_provider_testing.md)
- [Windows architecture](docs/windows_architecture.md)
- [Snap beta release](docs/beta_snap_release.md)
- [Windows packaging](docs/windows_packaging.md) and
  [release checklist](docs/windows_release_checklist.md)
- [Maintenance tools](tool/README.md) and
  [vendored dependencies](third_party/README.md)

## Support and feedback

Report defects and request features in the
[BusyMax issue tracker](https://github.com/busystack/busymax/issues). The
in-app **Send feedback** action submits only the fields described in the
[privacy and data map](docs/privacy_data_map.md); optional technical details are
off by default.

## License

BusyMax is licensed under the [Apache License 2.0](LICENSE). See
[NOTICE](NOTICE) for attribution and trademark information.
