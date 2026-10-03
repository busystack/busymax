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
