# Time-format correction

Validated against this checkout with Flutter 3.47.2, Dart 3.13.2,
intl 0.20.2, and fluent_ui 4.16.1. The reported Linux picker, parser,
Fluent picker, schedule boundary, and Windows tray-cache defects were present.

The distinction between a locale default and forced 12-hour formatting is
confirmed by Flutter's [formatTimeOfDay contract](https://api.flutter.dev/flutter/material/MaterialLocalizations/formatTimeOfDay.html).
Windows locale changes use the `intl` category of
[WM_SETTINGCHANGE](https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-settingchange).

## Implementation

- One persisted System / 12-hour / 24-hour preference uses the existing settings
  mutation, loading, persistence and error-handling machinery. Both settings
  interfaces expose it alongside schedule display settings.
- `lib/src/l10n/time_format.dart` owns context-independent formatting, explicit
  12-hour patterns, localized periods, component conversion and strict user
  parsing. Its inherited scope sits above each application navigator. No time
  zone conversion takes place in the formatter.
- The Linux anchored popover has a keyboard-accessible period selector and
  canonical hour stepping. Focused text retains its original parsing locale;
  incomplete components retain their parsing mode until they can normalize.
  Valid changes remain live, and parent-rejected changes restore the accepted
  value. Nullable clearing, disabled controls, time zones and validation remain
  connected to their editors.
- All ten Windows picker sites use `WindowsTimePicker`. The vendored 4.16.1
  Fluent patch fixes midnight/noon labels, wheel labels, padding, period
  conversion and controller synchronization. Format changes retain pending
  selections, including initially empty pickers. Unchanged confirmation does
  not dirty an editor. See [vendoring notes](../third_party/fluent_ui/README.busymax.md).
- Both trays use the shared policy. The Windows cache includes locale and
  effective clock; callbacks fetch the current formatting snapshot after data
  loading. Relevant changes refresh the actual tray presentation.
- Schedule boundaries preserve 0 versus 1440. The 12-hour end boundary includes
  a translated end-of-day qualifier. Rulers measure localized labels with the
  active text scale, and gutter-dependent resize positioning uses the same
  width. A small HoursPainter subclass fixes the upstream refusal to repaint
  changed labels when canvas dimensions stay the same.
- The Windows runner reads the user clock preference at initialization and on
  locale-setting messages/reactivation. It notifies Dart only on changes and
  retains existing message processing. Linux continues using Flutter's existing
  settings path; the pinned engine's settings handler, GNOME settings and portal
  sources were inspected for clock propagation and change subscriptions.
- The optional GTK picker remains opt-in. Its request supplies format and
  translated component/period labels; native input and output remain canonical
  `HH:mm`. Native tests exercise strict whole-input parsing, conversions and
  the actual GTK controls. The Linux workflow now runs these under Xvfb.

## Display audit

The supplied inventory was updated, including schedule rulers/current-time
labels, event ranges, agenda/details, previews, reminders, DAV timestamps,
Nextcloud proposals/availability, schedule boundaries, quiet hours and trays.
Existing date-only/all-day presentation and each caller's zone conversion are
retained. Truncated Text widgets keep their full semantic text; existing event
and compact-item tooltips retain complete clock labels.

Final searches under `lib/src` classify the remaining occurrences as follows:

| Search | Remaining use |
| --- | --- |
| `DateFormat.jm`, `add_jm`, `formatTimeOfDay`, direct `.format(context)` | None |
| `DateFormat.Hm` | Shared 24-hour formatting and discovery of the locale's input separator |
| `alwaysUse24HourFormat` | Original platform reads and presentation overrides at the two roots; a scope fallback for isolated widgets/tests |
| Raw hour/minute padding | Canonical settings storage, task/provider date-time strings, Graph serialization, iCalendar/recurrence export |
| `TimeOfDay(hour: 24)` | Calendar layout end boundary; explicitly displayed as midnight |

Provider/storage parsing still requires canonical `HH:mm`. User parsing accepts
localized clock output, supported localized digits, whitespace variants and
English AM/PM case variants. It validates hour/minute ranges before period
conversion. Unmarked `2:30` remains 02:30; single-digit minute input such as
`9:5` retains its prior unambiguous interpretation. No notification payload or
schedule calculation was changed.

## Verification

The SDK verifier passed for the workflow pins. Localization output was
regenerated with `flutter gen-l10n`; generated classes were not edited manually.
Static analysis, formatting, platform-boundary checks and the Linux release
build passed. The final full test run passed with 2,189 tests and 10 skips.

Regression coverage includes all 1,440 minutes in both formats for every exposed
locale, malformed period input, native-digit input, English examples, German
forced 12-hour output, end boundaries, actual Linux/Windows picker interactions,
open-control format changes, keyboard period selection, RTL/scaled Linux input,
settings persistence/loading/failure, immediate Windows tray label refresh,
Linux root system updates without router replacement, ruler repainting and
calendar gestures. Task/event tests retain draft state, canonical times, dates,
time zones, recurrence and absolute alarms across format changes.

The native GTK executable compiled with `-Wall -Wextra -Werror` and passed under
Xvfb. Windows clock reader/message tests are included in the existing runner
native-test target used by `tool/windows/run_native_tests.ps1`.

### Outstanding platform verification

Windows native compilation, the Windows workflow for this uncommitted checkout,
and interactive system-clock changes in new installed Snap/MSIX packages were
not executed. The installed Linux Snap is 0.2.0 and was not replaced; testing it
would not verify this patch. The Linux release bundle build and widget/native
tests do not establish packaged desktop behavior.

For release acceptance, use the checked-in Linux and Windows packaging
workflows. In each installed package, switch the OS between 12 and 24 hours
while BusyMax is open and while it is inactive, then reactivate it. In System
mode, verify the calendar, an open picker/editor and tray all update. Repeat
with explicit 12/24-hour preferences and German/English application language;
explicit preferences must stay fixed. Check midnight/noon, schedule end-of-day,
RTL and larger text, and confirm unchanged editors without producing mutations.
