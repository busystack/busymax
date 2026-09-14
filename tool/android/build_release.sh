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
export ORG_GRADLE_PROJECT_busymaxTestSigning="$test_signing"
if [[ "$kind" == apk || "$kind" == all ]]; then
  "$flutter_bin" build apk --release -t lib/main_android.dart "${defines[@]}"
fi
if [[ "$kind" == aab || "$kind" == all ]]; then
  "$flutter_bin" build appbundle --release -t lib/main_android.dart "${defines[@]}"
fi
if $test_signing; then
  echo 'Artifacts are explicitly TEST-SIGNED with the local debug identity; they are not production distribution artifacts.'
else
  echo 'Artifacts were signed using the untracked android/key.properties identity.'
fi
