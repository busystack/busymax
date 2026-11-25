#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kind=all
test_signing=false
allow_unconfigured=false
while (($#)); do
  case "$1" in
    --apk) kind=apk; shift ;;
    --aab) kind=aab; shift ;;
    --all) kind=all; shift ;;
    --test-signing) test_signing=true; shift ;;
    --allow-unconfigured-providers) allow_unconfigured=true; shift ;;
    *) echo 'Usage: tool/android/build_release.sh [--apk|--aab|--all] [--test-signing] [--allow-unconfigured-providers]' >&2; exit 64 ;;
  esac
done

prerequisite_args=()
if ! $allow_unconfigured; then prerequisite_args+=(--require-provider-config); fi
if ! $test_signing; then prerequisite_args+=(--require-signing); fi
"$repo_root/tool/android/check_prerequisites.sh" "${prerequisite_args[@]}"

flutter_bin="${BUSYMAX_FLUTTER_EXECUTABLE:-$(command -v flutter)}"
flutter_bin="$(readlink -f "$flutter_bin")"
flutter_sdk="$(dirname "$(dirname "$flutter_bin")")"
config="$repo_root/android/busymax.android.properties"
defines=()
property_value() {
  [[ -f "$config" ]] || return 0
  sed -n "s/^$1=//p" "$config" | head -n 1
}
for mapping in \
  'busymax.privacyPolicyUrl:BUSYMAX_PRIVACY_POLICY_URL' \
  'busymax.supportUrl:BUSYMAX_SUPPORT_URL' \
  'busymax.homepageUrl:BUSYMAX_HOMEPAGE_URL'; do
  property="${mapping%%:*}"
  define="${mapping##*:}"
  value="$(property_value "$property")"
  if [[ -n "$value" ]]; then defines+=("--dart-define=$define=$value"); fi
done

cd "$repo_root"
mkdir -p build
exec 9>build/.android-release.lock
flock -n 9 || { echo 'An Android release build is already running.' >&2; exit 1; }

remove_release_outputs() {
  local status=0
  if [[ "$kind" == apk || "$kind" == all ]]; then
    rm -f -- build/app/outputs/flutter-apk/app-release.apk{,.sha1} || status=1
    rm -rf -- build/app/outputs/apk/release || status=1
  fi
  if [[ "$kind" == aab || "$kind" == all ]]; then
    rm -rf -- build/app/outputs/bundle/release || status=1
  fi
  return "$status"
}

registrant=android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
temporary="$(mktemp -d)"
accepted=false
finish() {
  local status=$?
  trap - EXIT
  if ! $accepted; then remove_release_outputs || status=1; fi
  if [[ -f "$temporary/GeneratedPluginRegistrant.java" ]]; then
    cp -- "$temporary/GeneratedPluginRegistrant.java" "$registrant" || status=1
  fi
  rm -rf -- "$temporary" || status=1
  exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
remove_release_outputs

export ORG_GRADLE_PROJECT_busymaxTestSigning="$test_signing"
export PUB_CACHE="$temporary/pub-cache"
export PUB_HOSTED_URL=https://pub.dev
mkdir -- "$PUB_CACHE"
"$flutter_bin" precache --android_gen_snapshot --android_internal_build
"$flutter_bin" pub get --enforce-lockfile
integrity=(python3 tool/verify_upstream_packages.py --sdk "$flutter_sdk"
  --require-target android-release)
"${integrity[@]}"

# Flutter 3.50.1's pub get writes a debug registrant. A --no-pub build skips
# release regeneration, so invoke the pinned SDK's generator directly.
cp -- "$registrant" "$temporary/GeneratedPluginRegistrant.java"
cat > "$temporary/generate.dart" <<'DART'
import 'package:flutter_tools/src/base/template.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/context_runner.dart';
import 'package:flutter_tools/src/flutter_plugins.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/isolated/mustache_template.dart';
import 'package:flutter_tools/src/project.dart';

Future<void> main(List<String> args) async {
  Cache.flutterRoot = args.single;
  await runInContext(
    () async {
      final project = FlutterProject.fromDirectory(globals.fs.currentDirectory);
      await injectPlugins(project, releaseMode: true, androidPlatform: true);
    },
    overrides: {TemplateRenderer: () => const MustacheTemplateRenderer()},
  );
}
DART
"$flutter_sdk/bin/cache/dart-sdk/bin/dart" \
  --packages="$flutter_sdk/packages/flutter_tools/.dart_tool/package_config.json" \
  "$temporary/generate.dart" "$flutter_sdk"

if [[ "$kind" == apk || "$kind" == all ]]; then
  "$flutter_bin" build apk --no-pub --release -t lib/main_android.dart "${defines[@]}"
  "${integrity[@]}" --android-maven-mode release
  test -s build/app/outputs/flutter-apk/app-release.apk
fi
if [[ "$kind" == aab || "$kind" == all ]]; then
  "$flutter_bin" build appbundle --no-pub --release -t lib/main_android.dart "${defines[@]}"
  "${integrity[@]}" --android-maven-mode release
  test -s build/app/outputs/bundle/release/app-release.aab
fi
accepted=true
if $test_signing; then
  echo 'Artifacts are explicitly TEST-SIGNED with the local debug identity; they are not production distribution artifacts.'
else
  echo 'Artifacts were signed using the untracked android/key.properties identity.'
fi
