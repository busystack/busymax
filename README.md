# BusyMax

BusyMax is a beta calendar and task manager for Linux and Windows. It brings
events, tasks, reminders, and day, week, month, year, and agenda views into one
desktop application.

Linux uses a Yaru/GTK desktop composition with XDG integrations. Windows uses
a separate Fluent composition with a native Windows title bar, tray,
notifications, and packaged startup integration. Provider capabilities differ;
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
- Desktop reminders, tray actions, import/export, themes, keyboard navigation,
  and localized interfaces.

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

- Google and Microsoft accounts connect through browser-based sign-in.
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

## Documentation

Account, provider, and data information:

- [Provider support matrix](docs/provider_support_matrix.md)
- [Apple iCloud Calendar setup](docs/apple_icloud_setup.md)
- [Nextcloud Calendar and Tasks setup](docs/nextcloud_setup.md)
- [Privacy and data map](docs/privacy_data_map.md)

Development and maintenance:

- [Development setup for Linux and Windows](docs/development.md)
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
