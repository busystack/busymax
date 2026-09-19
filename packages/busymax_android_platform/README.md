# BusyMax Android platform bridge

This first-party Flutter plugin is the only native Android bridge used by
BusyMax. It exposes typed Dart APIs for:

- Google Identity Services authorization and account selection;
- MSAL multiple-account interactive and silent authorization;
- secure native-to-domain account binding;
- Storage Access Framework import and export;
- time-zone and 12/24-hour system settings;
- allow-listed external URI launch and Android 17 local-network permission;
- cold/warm Android activation delivery; and
- process-wide account gates shared by foreground and WorkManager engines.

The package is application-owned and is not intended as a general-purpose
published plugin. Provider secrets and production signing material are never
stored in this package.

Native unit tests are run from the repository root with:

```sh
android/gradlew --project-dir android \
  :busymax_android_platform:testDebugUnitTest
```
