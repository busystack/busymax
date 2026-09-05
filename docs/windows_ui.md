# Windows UI

Windows uses `FluentApp.router` and Fluent controls throughout the application
shell. It is a separate presentation target, not the Linux Yaru widget tree in
a Windows runner.

## Shell and destinations

`NavigationView` maps only the existing Schedule, Tasks, and Settings areas.
Settings is a footer destination. The source/calendar/task-list sidebar remains
a content-specific pane and collapses at BusyMax-owned breakpoints so narrow
windows do not show two permanently expanded sidebars.

The Windows presentation covers sign-in and account addition; schedule day,
week, month, year, and agenda views; source visibility; task lists/details;
calendar and task-list creation/rename/removal and reminder/color actions;
event/task editors; recurrence; reminders; date/time and timezone inputs;
calendar import and WebCal subscription; settings; account removal;
diagnostics; feedback; About; third-party licenses; and keyboard shortcuts. The
view/controller and provider logic remains shared.

Existing-task editing is capability-aware. Microsoft and DAV start, due,
reminder, recurrence, category/importance and iCalendar fields are patched
through `TaskDetailsDraft`; unchanged all-day values, unsupported recurrence,
and multi-alarm data are preserved instead of being normalized by merely
opening and saving the dialog. The Fluent task dialog also exposes supported
cross-list moves, hierarchy and checklist mutations, reparenting, DAV
duplication, and native iCalendar export. Event reminders retain multiple
Google/DAV values while Microsoft remains limited to its single provider
reminder. New tasks expose explicit all-day/timed scheduling and retain every
DAV alarm. Event and task editors confirm before discarding unsaved edits,
including Escape/back and hierarchy navigation.

BusyMax presentation contracts use semantic glyphs such as calendar, task,
add, delete, synchronize, reminder, and diagnostics. The Windows mapper uses
Microsoft Fluent System Icons. Feature code does not request `YaruIcons` or
Material `Icons` for Windows chrome.

## Theme and accessibility

- System, light, and dark modes follow the persisted BusyMax preference.
- Accent color follows the Windows system accent.
- High contrast uses opaque black/white Fluent surfaces.
- Reduced-motion preference zeroes Fluent animation durations.
- Segoe UI Variable is requested and Windows supplies its own fallback; no
  Microsoft font is bundled.
- Native text scaling, keyboard traversal, focus indicators, tooltips,
  screen-reader semantics, and RTL direction flow through Flutter/Fluent.
- The supported Windows validation matrix is 100%, 125%, 150%, and 200% display
  scaling, mixed-DPI monitors, 1280x800 and 1920x1080, and Arabic/Persian RTL.

The native title bar remains untouched. There are no Flutter-drawn minimize,
maximize, restore, or close controls and Mica is not a release dependency.

## Compatibility subtrees

Material controls are not used as Windows application chrome. If a custom or
third-party calendar subtree requires Material internals, compatibility must be
narrowly scoped to that subtree and inherit the Fluent brightness, color,
typography, locale, and direction. Material surfaces must not escape into the
shell. Ubuntu localization delegates remain Linux-only.

## Visual verification

Widget tests are not substitutes for native rendering. The release checklist
requires real installed-MSIX screenshots of major screens in light and dark at
1280x800 and 1920x1080, including a 125% or 150% run. Capture RTL, high-contrast,
focus, and mixed-DPI observations in the same Windows test record.
