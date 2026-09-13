# BusyMax fluent_ui patch

Upstream: bdlukaa/fluent_ui 4.16.1, copied from the pinned pub package.
The upstream public API and BSD-3-Clause license are retained. Only the time picker
implementation is patched; this is not a dependency upgrade.

`lib/src/controls/pickers/time_picker.dart` corrects 12-hour labels (12 at
midnight/noon), two-digit minutes and 24-hour components, noon selection,
period conversion using hour modulo 12, and controller indices. Clock/locale
changes refresh an open picker while retaining its pending selection, date,
UTC status, and confirmation/cancellation behavior. Presentation changes do
not emit onChanged. Minute increment indices use the increment consistently.

BusyMax's WindowsTimePicker wrapper supplies the resolved clock and application
locale and suppresses unchanged confirmations. Regression coverage is in
test/ui/windows/windows_time_picker_test.dart.
