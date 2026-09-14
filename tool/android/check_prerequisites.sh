#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
require_provider=false
require_signing=false
for argument in "$@"; do
  case "$argument" in
    --require-provider-config) require_provider=true ;;
    --require-signing) require_signing=true ;;
    *) echo "Unknown option: $argument" >&2; exit 64 ;;
  esac
done

flutter_bin="${BUSYMAX_FLUTTER_EXECUTABLE:-$(command -v flutter || true)}"
if [[ -z "$flutter_bin" || ! -x "$flutter_bin" ]]; then
  echo 'Flutter is missing. Install Flutter 3.47.2 and put it on PATH.' >&2
  exit 1
fi
flutter_bin="$(readlink -f "$flutter_bin")"
dart_bin="$(dirname "$flutter_bin")/cache/dart-sdk/bin/dart"
if [[ ! -x "$dart_bin" ]]; then
  echo 'The bundled Dart executable could not be found beside Flutter.' >&2
  exit 1
fi
"$dart_bin" "$repo_root/tool/verify_flutter_sdk.dart" \
  --flutter "$flutter_bin" \
  --dart "$dart_bin" \
  --expected-flutter 3.47.2 \
  --expected-dart 3.13.2

java_version="$(java -version 2>&1 | sed -n '1s/.*version "\([^"]*\)".*/\1/p')"
if [[ "$java_version" != 17.* ]]; then
  echo "JDK 17 is required; the active Java reports '${java_version:-unknown}'." >&2
  exit 1
fi

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$sdk_root" && -f "$repo_root/android/local.properties" ]]; then
  sdk_root="$(sed -n 's/^sdk\.dir=//p' "$repo_root/android/local.properties" | head -n 1)"
fi
if [[ -z "$sdk_root" || ! -d "$sdk_root" ]]; then
  echo 'Set ANDROID_SDK_ROOT or android/local.properties to an Android SDK.' >&2
  exit 1
fi
if [[ ! -d "$sdk_root/platforms/android-37" && ! -d "$sdk_root/platforms/android-37.0" ]]; then
  echo 'Android SDK platform API 37 is required.' >&2
  exit 1
fi
build_tools=("$sdk_root"/build-tools/37*)
if [[ ! -d "${build_tools[0]}" ]]; then
  echo 'Android SDK Build Tools 37.x are required.' >&2
  exit 1
fi

config="$repo_root/android/busymax.android.properties"
if $require_provider; then
  if [[ ! -f "$config" ]]; then
    echo 'Copy android/busymax.android.properties.example to android/busymax.android.properties and configure the public provider registrations.' >&2
    exit 1
  fi
  for key in microsoft.clientId microsoft.signatureHash; do
    if ! grep -Eq "^${key//./\\.}=.+" "$config"; then
      echo "Android public configuration is missing $key." >&2
      exit 1
    fi
  done
fi

if $require_signing; then
  signing="$repo_root/android/key.properties"
  if [[ ! -f "$signing" ]]; then
    echo 'Production signing requires an untracked android/key.properties file.' >&2
    exit 1
  fi
  for key in storeFile storePassword keyAlias keyPassword; do
    if ! grep -Eq "^${key}=.+" "$signing"; then
      echo "Android signing configuration is missing $key." >&2
      exit 1
    fi
  done
fi

echo 'PASSED: Flutter 3.47.2, bundled Dart 3.13.2, JDK 17, Android API 37, and Build Tools 37.x are available.'
echo "Flutter: $flutter_bin"
echo "Android SDK: $sdk_root"
