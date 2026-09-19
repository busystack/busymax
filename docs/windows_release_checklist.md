# Windows release checklist

Use this as the single verification checklist for a Windows release. Source
review and Linux tests do not establish native Windows behavior.

Start a release record with the source revision, Windows edition/build and
hardware, display/DPI setup, Flutter and Windows SDK versions, configuration
mode, MSIX filename/version/SHA-256, CI run and artifact identity, and the
person/date responsible for each result.

## Automated gates

- [ ] A clean checkout uses Flutter 3.47.4 and its bundled Dart 3.13.3.
- [ ] Dependency resolution, localization generation, and Drift generation
      follow [Development](development.md) and leave committed outputs clean.
- [ ] The non-writing formatting check, analyzer, normal tests, and
      platform-boundary check pass.
- [ ] Linux CI still builds `lib/main_linux.dart` and its strict Snap checks
      pass; Windows CI builds `lib/main_windows.dart`.
- [ ] Windows Pester packaging contracts and runner, tray, and timezone native
      tests pass.
- [ ] Production configuration validation uses the owner identity and provider
      settings; CI configuration remains explicitly non-production.
- [ ] Manifest and content validation pass before and after MakeAppx packaging.
- [ ] The exact unpacked MSIX matches the staged runtime inventory except for
      expected MakeAppx metadata.

## Installed-package lifecycle

Use a locally test-signed copy of the release-equivalent Store package.

- [ ] Ordinary, offline, and `--start-minimized` launches work.
- [ ] Close-to-tray on/off, hide, restore, explicit Quit, and reopen work.
- [ ] A second launch forwards activation and never opens a second Drift owner.
- [ ] Explorer restart recovers the tray; a tray failure leaves a visible
      window.
- [ ] Sign-out, OS restart, and launch-at-login behavior work.
- [ ] StartupTask starts disabled and correctly represents enable, disable,
      start-minimized, user-disabled, policy-disabled, and unpackaged states.
- [ ] Package update preserves supported local data and account state; package
      removal behavior is observed and recorded rather than inferred.
- [ ] A clean Windows 11 24H2 x64 system without developer tools installs and
      runs the package. Exercise any newer Windows 11 release claimed by the
      release as well.

## Activation and notifications

- [ ] Cold, warm, hidden-window, and initialization-time `.ics` activation
      opens review/confirmation and never imports silently.
- [ ] Cold, warm, and hidden-window `webcal:` activation opens subscription
      confirmation.
- [ ] Malformed URI/JSON/UTF-8, unsupported file/scheme/action, oversized
      input, and concurrent activations are rejected or serialized safely.
- [ ] Notifications display the intended title and body; body click, Open,
      Snooze, Dismiss, duplicate action, cancellation, warm/cold activation,
      hidden window, and installed package identity all work.
- [ ] Activation arguments contain only bounded identifiers and action data,
      with no display text, account email, token, code, or secret.
- [ ] Opening a notification reveals the exact event or task, including an item
      that arrives after background synchronization.
- [ ] The tray **Today** action selects today's day view after navigation to a
      distant date.

## Accounts, storage, files, and synchronization

- [ ] Google and Microsoft browser/loopback sign-in pass in unpackaged and
      installed configurations, including cancellation, timeout, callback
      validation, and restored focus.
- [ ] Apple iCloud and Nextcloud setup, reconnect, remote revocation behavior,
      read-only permissions, and account removal match their setup guides.
- [ ] Credentials survive restart in the secure backend and are removed by the
      applicable sign-out/account-removal action; tokens do not appear in
      preferences, logs, activation data, or exported evidence.
- [ ] Existing Drift migrations, SQLite runtime, restart, backup/recovery,
      Unicode paths, and long paths work.
- [ ] iCalendar import/export, overwrite/copy choice, cancellation, read-only
      destinations, malformed input, Unicode/long filenames, and WebCal work
      without broad filesystem capability.
- [ ] Timezone handling covers UTC, standard/DST, skipped and ambiguous local
      times, non-hour offsets, and a system-zone change followed by restart.
- [ ] Editing a zoned event without changing its times preserves both endpoint
      zones, seconds, and instants.
- [ ] Switching an event to another compatible calendar preserves unrelated
      recurrence, reminders, meeting data, personal fields, and title edits;
      switching away and back does not erase the draft.
- [ ] Schedule and Tasks views refresh after background object, account,
      source, list, capability, and permission changes.
- [ ] Provider-supported task completion, recurrence, hierarchy, reparenting,
      list moves, and subtree behavior persist after refresh and restart.

## Workflow and editor behavior

- [ ] Tasks account/list scope, completed filtering, hierarchy indentation,
      account-qualified list labels, creation context, and empty/loading/error
      states behave correctly.
- [ ] Removing a selected account or list reconciles the active task filter;
      retry and refresh recover failed account, list, and task queries.
- [ ] Month view adapts row capacity, preserves source identity/color, and
      opens all hidden items through the overflow control with keyboard access
      and larger text.
- [ ] Year view renders weekday/date grids, item markers, and selectable dates;
      long-range navigation returns accurately to Today.
- [ ] Event and task editors preserve unsupported recurrence and alarm data
      when opened and saved without related edits.
- [ ] Schedule, URL, recurrence, and destination validation follow the selected
      provider without destroying fields retained for another destination.
- [ ] Escape, Back, window close, and hierarchy navigation prompt before
      discarding unsaved edits, including edits made only to notes or
      description.

## UI, accessibility, and DPI

- [ ] The Windows shell and dialogs use Fluent presentation; no Yaru or Ubuntu
      UI enters the Windows graph.
- [ ] Native title bar, caption controls, system menu, snap, maximize, restore,
      resize, and minimum-size behavior work.
- [ ] Light, dark, high contrast, reduced motion, system accent changes, text
      scaling, keyboard-only traversal, visible focus, tooltips, and basic
      Narrator labels are usable.
- [ ] Test 100%, 125%, 150%, and 200% scaling, 1280x800 and 1920x1080, and
      movement between mixed-DPI monitors.
- [ ] Arabic and Persian RTL work through navigation, dialogs, calendars, and
      editors; every supported locale opens without Windows-only placeholder
      text.
- [ ] Capture installed-MSIX light and dark screenshots at both target sizes,
      including at least one 125% or 150% run. Include high contrast, RTL,
      keyboard focus, Month overflow, Year selection, Tasks hierarchy, and
      populated editors in the evidence.

## Final package, privacy, and WACK

- [ ] The exact production configuration contains the owner identity,
      production OAuth values, valid HTTPS privacy/support URLs, fake data off,
      and no development backend.
- [ ] Application version and four-part Store package version are displayed and
      recorded distinctly.
- [ ] The MSIX is x64, targets minimum `10.0.26100.0`, has fourth version
      component 0, contains only expected capabilities/extensions/languages,
      and is newer than the previous supplied Store version.
- [ ] Manual inspection finds no certificate/PFX, secret/token, log, database,
      source, debug symbol, test/fake data, Linux content, unreferenced asset,
      or missing Flutter/plugin/SQLite/VC runtime file.
- [ ] Published privacy disclosures are reviewed against the
      [privacy and data map](privacy_data_map.md). Record discrepancies as
      release blockers; do not assume an external page is current.
- [ ] WACK reports no failure. Investigate every warning and retain its written
      disposition, complete XML report, and parsed summary.
- [ ] Repeat package inspection and WACK after package-affecting changes.

## Complete the release record

Record the tested revision, environment, exact artifact identity and checksum,
commands or checklist cases executed, pass/fail/not-run results, CI links,
screenshots, WACK files, privacy review, and relevant redacted evidence. List
remaining external verification or owner-supplied values explicitly. Do not
mark unexecuted cases as passed.
