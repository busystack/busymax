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

The pinned stylesheet gives ordinary buttons an outline offset of `-2px` and
gives `button.suggested-action` (through its opaque-button treatment) an outer
outline offset of `1px`. Both use a 2-pixel accent outline at 50% opacity, or
80% in high-contrast mode. These offsets, rather than the GTK 3 host's focus
rendering, are the focus-placement reference used by the Flutter fixture and
rendering tests.

The GTK fixture at `tool/linux/native_button_reference.cc` captures the real
GTK 3 controls used by the BusyMax host, including its standard, suggested,
destructive, focused, and disabled variants. The separate
`tool/linux/native_libadwaita_button_reference.js` fixture renders real GTK 4
buttons through the installed libadwaita 1.9.1 runtime. Its focused row uses
GTK's native `FOCUSED | FOCUS_VISIBLE` state so the inset standard outline and
offset suggested-action outline can be compared directly. The Flutter fixture
at `tool/linux_button_comparison.dart` renders the production BusyMax theme
and `BusyMaxPushButton` factories; it contains no fixture-only button styling.

The GTK 3 capture is retained specifically to compare the app-owned native
onboarding actions with Flutter actions. It is not used as a substitute for
the libadwaita 1.9 measurements above.

## Review procedure

1. Run both native fixtures under the recorded desktop theme and capture the
   GTK 3 host controls and libadwaita target separately.
2. Run the Flutter comparison fixture with the same theme, font, accent, and
   scale.
3. Compare overall height, horizontal padding, radius, label weight/baseline,
   semantic role colors, hover/pressed changes, and focus-outline placement.
4. Only update regression images after that comparison.

## Reviewed artifacts

- `docs/screenshots/linux_buttons_native_reference.png`: GTK 3/Yaru host
  controls from the recorded environment.
- `docs/screenshots/linux_buttons_libadwaita_reference.png`: GTK 4/libadwaita
  1.9.1 standard and suggested controls, including native focus-visible rings.
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
disabled sizing, and role-aware keyboard focus outlines. Neutral and
destructive actions use the ordinary inset outline; suggested actions use the
1-pixel-offset outer outline from libadwaita's opaque-button rule. Actual mouse
focus remains quiet, while Tab and Shift+Tab focus displays the appropriate
outline without changing layout or being clipped on the window, dialog, and
popover surfaces.
