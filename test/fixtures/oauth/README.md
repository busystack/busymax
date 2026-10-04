This Desktop configuration is entirely synthetic. It cannot authorize a real
Google account and contains no client secret or tokens. It is for importer and
native file-selection validation only. OAuth destinations in imported JSON are
never trusted by BusyMax.

For an interactive native picker check, set `BUSYMAX_NATIVE_IMPORT_FIXTURE` to the
absolute path of `desktop_synthetic.json`, run
`flutter test integration_test/native_registration_storage_test.dart -d linux`
(or `-d windows` on Windows), and select this file when the system dialog opens.
The integration test also writes and removes its own disposable synthetic secure
storage key; it does not change accounts or the active-account key.

For automated Linux coverage of the real Settings Cancel/disposal controls,
native storage, chooser and handle reader, run
`DISPLAY=:1 python3 tool/linux/test_oauth_corrective_native.py` with the approved
Flutter executable on PATH (or set `BUSYMAX_FLUTTER_EXECUTABLE`). This requires
an available X11 display and installed D-Bus, GNOME keyring and system Python GI/AT-SPI libraries.
It creates a private temporary keyring and targets only its own chooser through accessibility.
Run it sequentially with other Linux Flutter builds so generated entry points
are not changed while its app is compiling. It uses this fixture only and never
authorizes, revokes or removes a provider account.
