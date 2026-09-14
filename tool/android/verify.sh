#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build=false
if [[ "${1:-}" == '--build-test-signed' ]]; then build=true; shift; fi
if (($#)); then
  echo 'Usage: tool/android/verify.sh [--build-test-signed]' >&2
  exit 64
fi
"$repo_root/tool/android/check_prerequisites.sh"
flutter_bin="${BUSYMAX_FLUTTER_EXECUTABLE:-$(command -v flutter)}"
flutter_bin="$(readlink -f "$flutter_bin")"
dart_bin="$(dirname "$flutter_bin")/cache/dart-sdk/bin/dart"
cd "$repo_root"
"$flutter_bin" pub get --enforce-lockfile
"$flutter_bin" gen-l10n
"$dart_bin" run build_runner build --force-jit
git diff --exit-code -- lib/l10n/generated lib/src/db/app_database.g.dart
"$dart_bin" format --output=none --set-exit-if-changed .
"$flutter_bin" analyze
"$dart_bin" run tool/check_platform_boundaries.dart
"$flutter_bin" test
"$repo_root/android/gradlew" --project-dir "$repo_root/android" \
  :busymax_android_platform:testDebugUnitTest :app:lintDebug
if $build; then
  "$repo_root/tool/android/build_release.sh" --all --test-signing \
    --allow-unconfigured-providers
  "$repo_root/tool/android/inspect_artifacts.sh"
fi
