#!/usr/bin/env bash
# Deterministic release configuration checks. These synthetic public clients
# are never live grants or official shared registration validation.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
config="$repo_root/android/busymax.android.properties"
backup="$(mktemp)"
had_config=false
if [[ -f "$config" ]]; then
  cp "$config" "$backup"
  had_config=true
fi
restore() {
  if $had_config; then cp "$backup" "$config"; else rm -f "$config"; fi
  rm -f "$backup"
}
trap restore EXIT

# Gradle's debug signing identity is deliberately used for these test builds.
key_store="${BUSYMAX_ANDROID_DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
if [[ ! -f "$key_store" ]]; then
  echo 'Build a debug APK first to create the standard test signing identity.' >&2
  exit 1
fi
signature_hash="$(keytool -exportcert -alias androiddebugkey -keystore "$key_store" -storepass android 2>/dev/null | openssl dgst -sha1 -binary | openssl base64 -A)"
for mode in transitional user-owned; do
  destination="$repo_root/build/android/registration-modes/$mode"
  mkdir -p "$destination"
  {
    printf 'microsoft.signatureHash=%s\n' "$signature_hash"
    printf 'microsoft.authorityTenant=common\n'
    if [[ "$mode" == transitional ]]; then
      printf 'microsoft.clientId=22222222-2222-2222-2222-222222222222\n'
    fi
  } > "$config"
  "$repo_root/tool/android/build_release.sh" --all --test-signing
  cp build/app/outputs/flutter-apk/app-release.apk "$destination/app-release.apk"
  cp build/app/outputs/bundle/release/app-release.aab "$destination/app-release.aab"
  "$repo_root/tool/android/inspect_artifacts.sh" "$destination/app-release.apk" "$destination/app-release.aab"
  cp build/android/android-artifact-inspection.txt "$destination/inspection.txt"
  sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [[ -z "$sdk_root" ]]; then sdk_root="$(sed -n 's/^sdk\.dir=//p' android/local.properties | head -n 1)"; fi
  "$sdk_root/build-tools/37.0.0/aapt2" dump resources "$destination/app-release.apk" > "$destination/resources.txt"
  if [[ "$mode" == transitional ]]; then
    rg -q 'raw/busymax_msal_config' "$destination/resources.txt"
  elif rg -q 'raw/busymax_msal_config' "$destination/resources.txt"; then
    echo 'The user-owned build unexpectedly contains the original native MSAL resource.' >&2
    exit 1
  fi
  unzip -Z1 "$destination/app-release.apk" > "$destination/entries.txt"
  rg -q 'assets/flutter_assets/docs/google_setup.md' "$destination/entries.txt"
  rg -q 'assets/flutter_assets/docs/microsoft_setup.md' "$destination/entries.txt"
  echo "PASSED: $mode release configuration, installed debug-signature redirect, and packaged help."
done
