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

# Read the certificate from the test-signed APK so the redirect uses the actual
# signing identity without assuming where Gradle stores its debug keystore.
apk="$repo_root/build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -f "$apk" ]]; then
  echo 'Build a test-signed release APK first to establish the signing identity.' >&2
  exit 1
fi
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$sdk_root" ]]; then sdk_root="$(sed -n 's/^sdk\.dir=//p' android/local.properties | head -n 1)"; fi
signature_sha1="$("$sdk_root/build-tools/37.0.0/apksigner" verify --print-certs "$apk" | sed -n 's/^Signer #1 certificate SHA-1 digest: //p')"
if [[ ! "$signature_sha1" =~ ^[[:xdigit:]]{40}$ ]]; then
  echo 'Could not read the test-signed APK certificate SHA-1 digest.' >&2
  exit 1
fi
signature_hash="$(python3 -c 'import base64, sys; print(base64.b64encode(bytes.fromhex(sys.argv[1])).decode("ascii"))' "$signature_sha1")"
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
