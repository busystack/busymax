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
generated_snapshot="$(mktemp)"
trap 'rm -f "$generated_snapshot"' EXIT
"$dart_bin" run tool/check_generated_sources.dart snapshot "$generated_snapshot"
"$flutter_bin" gen-l10n
"$dart_bin" run build_runner build --force-jit
"$dart_bin" run tool/check_generated_sources.dart verify "$generated_snapshot"
"$dart_bin" format --output=none --set-exit-if-changed .
"$flutter_bin" analyze
"$dart_bin" run tool/check_platform_boundaries.dart
test_args=()
if [[ -n "${BUSYMAX_TEST_CONCURRENCY:-}" ]]; then
  if [[ ! "$BUSYMAX_TEST_CONCURRENCY" =~ ^[1-9][0-9]*$ ]]; then
    echo 'BUSYMAX_TEST_CONCURRENCY must be a positive integer.' >&2
    exit 64
  fi
  test_args+=(--concurrency "$BUSYMAX_TEST_CONCURRENCY")
fi
"$flutter_bin" test "${test_args[@]}"
"$repo_root/android/gradlew" --project-dir "$repo_root/android" \
  :busymax_android_platform:testDebugUnitTest :app:lintDebug
if $build; then
  "$repo_root/tool/android/build_release.sh" --all --test-signing \
    --allow-unconfigured-providers
  "$repo_root/tool/android/inspect_artifacts.sh"
fi
