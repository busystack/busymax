# BusyMax

BusyMax is a Linux desktop calendar and task manager built with Flutter.

It brings calendar events and tasks into a native-feeling Linux desktop interface, with support for `Google Calendar`, `Google Tasks`, `Microsoft Calendar`, and `Microsoft To Do`.

![BusyMax month view](docs/screenshots/main_window_month.png)

**Month view** — calendars, tasks, and event details in one workspace.

## Highlights

- Linux desktop app built with Flutter.
- Calendar views for day, week, month, year, and agenda planning.
- Task creation with lists, due dates, reminders, and repeat options.
- Event editing with calendar selection, time controls, repeat rules, and reminders.
- Compact agenda window for quick access to upcoming work.
- Integrations with Google Calendar, Google Tasks, Microsoft Calendar, and Microsoft To Do.

## Screenshots

### Week view

![BusyMax week view](docs/screenshots/main_window_week.png)

Color-coded calendars and scheduled tasks.

### Day view

![BusyMax day view](docs/screenshots/main_window_day.png)

Focused daily planning with calendar events and tasks.

### Agenda view

![BusyMax agenda view](docs/screenshots/main_window_agenda.png)

Upcoming events, tasks, and details in a compact agenda layout.

### Task creation

![BusyMax new task editor](docs/screenshots/main_window_new_task.png)

Task creation with lists, due dates, reminders, and repeat options.

### Event editing

![BusyMax event editor](docs/screenshots/main_window_edit_event.png)

Event editing with calendar selection, time controls, repeat rules, and reminders.

### Year view

![BusyMax year view](docs/screenshots/main_window_year.png)

A high-level view for navigating the calendar year.

### Compact agenda window

![BusyMax compact agenda window](docs/screenshots/agenda_window_agenda.png)

A small agenda window for quick access to upcoming work.

### Compact agenda event details

![BusyMax compact agenda event details](docs/screenshots/agenda_window_agenda_event_details.png)

Event details from the compact agenda window.

### Compact agenda event editing

![BusyMax compact agenda event editor](docs/screenshots/agenda_window_edit_event.png)

Event editing from the compact agenda window.

## Prerequisites

- Flutter: https://docs.flutter.dev/install
- `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET`, see [Google Setup](docs/google_setup.md)
- `MICROSOFT_OAUTH_CLIENT_ID`, see [Microsoft Setup](docs/microsoft_setup.md)

## Run locally

```bash
flutter run -d linux \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=<google-client-id> \
  --dart-define=GOOGLE_OAUTH_CLIENT_SECRET=<google-secret-if-needed> \
  --dart-define=MICROSOFT_OAUTH_CLIENT_ID=<microsoft-client-id>
```