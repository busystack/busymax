# Linux button visual reference

This reference is fixed for the Ubuntu button-alignment work. Do not combine
measurements from a different Yaru or libadwaita generation when reviewing the
corresponding BusyMax screenshots.

## Recorded environment

- Ubuntu 26.04.1 LTS (Resolute Raccoon), GNOME Wayland session
- GTK 3.24.52 (the BusyMax native host)
- libadwaita 1.9.1 (the contemporary GNOME control reference)
- Yaru GTK and GNOME Shell 26.04.5.1
- Active GTK theme: `Yaru-magenta-dark`
- Active color scheme: `prefer-dark`
- Active accent preference: `pink`
- UI font: Ubuntu Sans 11 pt
- Text scale: 1.0
- Display scale: 1x
- Flutter 3.47.4 / Dart 3.13.3, with Yaru Flutter 10.2.0

The environment was recorded on 2026-09-19 before changing the BusyMax button
theme. The installed libadwaita stylesheet embedded in
`libadwaita-1.so.0` was inspected directly. Its normal button rule uses a
24-pixel content-box minimum, 5-pixel vertical padding, bold labels, explicit
hover and keyboard-activation states, and a 2-pixel `:focus-visible` outline.
Text-only buttons add horizontal padding to the common button rule. BusyMax
uses the requested 17-pixel text-button padding and retains Yaru Flutter's
34-pixel overall minimum and 8-pixel radius.

The GTK fixture at `tool/linux/native_button_reference.cc` captures the real
GTK 3 controls used by the BusyMax host, including its standard, suggested,
destructive, focused, and disabled variants. The Flutter fixture at
`tool/linux_button_comparison.dart` renders the production BusyMax theme and
`BusyMaxPushButton` factories; it contains no fixture-only button styling.

The GTK 3 capture is retained specifically to compare the app-owned native
onboarding actions with Flutter actions. It is not used as a substitute for
the libadwaita 1.9 measurements above.

## Review procedure

1. Run the native fixture under the recorded desktop theme and capture it.
2. Run the Flutter comparison fixture with the same theme, font, accent, and
   scale.
3. Compare overall height, horizontal padding, radius, label weight/baseline,
   semantic role colors, hover/pressed changes, and focus-outline placement.
4. Only update regression images after that comparison.

## Reviewed artifacts

- `docs/screenshots/linux_buttons_native_reference.png`: GTK 3/Yaru host
  controls from the recorded environment.
- `docs/screenshots/linux_buttons_before.png`: the unmodified production
  theme rendered by the Linux desktop engine from an isolated baseline
  checkout.
- `docs/screenshots/linux_buttons_after_desktop.png`: the corrected production
  theme and components rendered by the same Linux desktop engine.
- `test/app/goldens/linux_buttons_reviewed.png`: the post-review widget-test
  regression image.

The visual review confirmed a common 34-pixel baseline and compact rounded
geometry, bold and baseline-aligned action labels, distinct whole-control
hover/pressed states, semantic neutral/accent/destructive colors, stable
disabled sizing, and an inside-aligned 2-pixel keyboard focus outline. The
outline remains visible on each role without changing layout or being clipped
on the window, dialog, and popover surfaces.
