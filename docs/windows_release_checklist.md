# Windows release checklist

This checklist is evidence-driven. Source review or a Linux build cannot mark
the Windows package ready. Record host OS/build, display setup, package version,
MSIX filename/SHA-256, commands, results, screenshots, and WACK report beside
the release candidate.

## Automated gates

- [ ] Clean checkout uses Flutter 3.44.4.
- [ ] Localization and build-runner generation are committed and reproducible.
- [ ] Formatting, analyzer, unit tests, widget tests, and platform-boundary
      checks pass on Linux and `windows-latest`.
- [ ] Linux release builds explicitly from `lib/main_linux.dart`; Snap checks
      remain green and Yaru/GTK behavior is unchanged.
- [ ] Windows x64 release builds explicitly from `lib/main_windows.dart`.
- [ ] CI creates only the explicitly non-production unsigned test MSIX and
      uploads it and test reports as CI artifacts; no deployment job exists.
- [ ] Manifest and package-content validators pass.
- [ ] Executable runner, timezone, and tray native tests pass on Windows.
- [ ] The packed MSIX is unpacked to a clean directory; the exact final
      manifest, runtime inventory, and per-file SHA-256 report pass validation.

## Installed package lifecycle

- [ ] Ordinary start, offline start, and `--start-minimized`.
- [ ] Close-to-tray enabled/disabled, explicit Quit, reopen and restore.
- [ ] Second launch cannot open Drift and restores the primary instance.
- [ ] Explorer restart recovers the tray; tray failure leaves a visible window.
- [ ] Sign-out/restart and launch-at-login behavior.
- [ ] StartupTask disabled by default, user enable/disable, start minimized,
      user-disabled, policy-disabled, and unpackaged states.

## Activation and notifications

- [ ] Cold, warm, hidden-window, and initialization-time `.ics` activation opens
      review/confirmation without silent import.
- [ ] Cold/warm/hidden `webcal:` enters subscription confirmation.
- [ ] Malformed URI/JSON/UTF-8, unsupported file/scheme, oversized input, and
      concurrent activations are safely rejected or serialized.
- [ ] Notification display, body click, Open, Snooze, Dismiss, duplicate action,
      cancellation, warm/cold activation, hidden window, and package-identity
      behavior pass.
- [ ] Activation arguments contain stable internal IDs only and no title, body,
      account email, token, code, or secret.

## Accounts, storage, and files

- [ ] Google and Microsoft browser/loopback OAuth pass unpackaged, installed
      test-signed, and final Store-mode configurations, including cancellation,
      timeout, PKCE/state validation, and restored focus.
- [ ] Secure credentials persist after restart and are removed on sign-out and
      account removal; no plaintext preference/log/payload contains a token.
- [ ] Existing Drift schema/migrations, SQLite DLLs, restart, package update,
      backup/recovery, Unicode paths, and long paths pass.
- [ ] `.ics` import/export, overwrite, cancellation, read-only destination,
      Unicode/long filename, malformed iCalendar, and WebCal pass without broad
      filesystem capability.
- [ ] Recurrence and timezone behavior covers UTC, standard/DST, skipped and
      ambiguous local time, non-hour offsets, and a system-zone change followed
      by restart.

## UI and accessibility

- [ ] Every existing screen has Fluent presentation; no Windows-visible Yaru,
      Ubuntu, Material shell control, or Flutter template icon remains.
- [ ] Native title bar, caption controls, snap/maximize/restore/system menu.
- [ ] Light, dark, high contrast, reduced motion, system accent changes, text
      scaling, keyboard-only order/focus/tooltips, and basic Narrator.
- [ ] 100%, 125%, 150%, and 200%; 1280x800 and 1920x1080; mixed-DPI monitors.
- [ ] Arabic and Persian RTL through navigation, dialogs, and editors; all
      other supported locales open without English Windows placeholders.
- [ ] Real installed-MSIX light/dark screenshots captured at both target sizes,
      including at least one 125% or 150% run.
- [ ] Windows 11 24H2 and 25H2 both exercised.

## Final package and WACK

- [ ] Production configuration has exact owner identity/OAuth values, valid
      HTTPS privacy/support URLs, fake data off, and no development backend.
- [ ] Product version and Store package version are displayed distinctly.
- [ ] MSIX is x64, minimum `10.0.26100.0`, fourth version segment 0, expected
      capabilities/extensions/languages/assets only, and newer than the prior
      supplied version.
- [ ] Manual content review finds no certificate/PFX, secret/token, logs,
      database, source, debug symbols, test data, Linux content, unreferenced
      assets, or missing Flutter/plugin/SQLite runtime DLL.
- [ ] Clean Windows test environment without build tools installs and runs.
- [ ] WACK finishes with zero failures; every warning is investigated and its
      written disposition, complete XML report, and parsed summary are
      retained. Repeat after package-affecting changes.

## Release record

- [ ] Architecture/dependency summary.
- [ ] Exact commands and results for Linux, Windows, CI, installed MSIX, and
      WACK.
- [ ] CI run links/artifact identifiers.
- [ ] Windows screenshots.
- [ ] MSIX filename, version, architecture, minimum OS, and SHA-256.
- [ ] WACK report path/result.
- [ ] Exact remaining external owner values, if any.
- [ ] Confirmation that no package was uploaded or deployed.
