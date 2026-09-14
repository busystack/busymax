# Android release and signing

Production key material is never tracked. Copy
`android/key.properties.example` to ignored `android/key.properties`, point
`storeFile` at the owner-controlled keystore, and fill its passwords and alias
outside logs and shell history. Do not replace an established upload identity.

With real public provider configuration and owner signing present, build both
formats with:

```sh
tool/android/build_release.sh --all
tool/android/inspect_artifacts.sh
```

The individual release branches are `tool/android/build_release.sh --apk` and
`tool/android/build_release.sh --aab`. To install the already-built APK without
starting a debug session, use the Android SDK platform tool explicitly:

```sh
adb -s DEVICE_ID install -r build/app/outputs/flutter-apk/app-release.apk
```

To launch/install from source with the explicit Android entrypoint, use
`tool/android/run.sh --device DEVICE_ID`. Certificate identity can be inspected
directly with the Build Tools 37 `apksigner verify --verbose --print-certs`
command, or as part of `tool/android/inspect_artifacts.sh`. The build and
inspection commands were exercised with test signing; device install/launch is
recorded as blocked, not passed, in the verification report.

Outputs are:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`
- `build/android/android-artifact-inspection.txt`

The script selects `lib/main_android.dart`, enables R8/resource shrinking, and
fails if Microsoft public registration or production signing is absent. For CI
or development only, `--test-signing --allow-unconfigured-providers` produces
an explicitly labeled debug-identity release-mode artifact. That artifact is
not a finished distribution build and its unavailable provider flows are
expected to remain disabled.

`inspect_artifacts.sh` records SHA-256 values, APK certificate identity,
manifest metadata when `apkanalyzer` is available, ABIs, APK 16 KB zip
alignment, and ELF LOAD alignment in both APK and AAB. Set `BUNDLETOOL_JAR` to
an existing official bundletool jar to add its AAB configuration dump; the
script does not silently download tools.

Three identities must be tracked separately:

1. Debug/test-signed builds use the Android debug certificate.
2. A locally distributed release APK uses the certificate from
   `android/key.properties`.
3. A Play-installed APK normally uses the Play app-signing certificate; the
   AAB upload certificate may be different.

Register Google and Microsoft for the certificate that signs the installed
APK. Before release, test a fresh install and upgrade on physical hardware,
then verify cold notification activation and a real calendar/task round trip.
Publishing, Play enrollment, store disclosures, and production key use require
the owner's authorization.
