#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
apk="${1:-$repo_root/build/app/outputs/flutter-apk/app-release.apk}"
aab="${2:-$repo_root/build/app/outputs/bundle/release/app-release.aab}"
report="$repo_root/build/android/android-artifact-inspection.txt"
mkdir -p "$(dirname "$report")"
: > "$report"
log() { printf '%s\n' "$*" | tee -a "$report"; }
for artifact in "$apk" "$aab"; do
  if [[ ! -f "$artifact" ]]; then
    log "FAILED: missing artifact $artifact"
    exit 1
  fi
  log "ARTIFACT: $artifact"
  log "SHA-256: $(sha256sum "$artifact" | cut -d' ' -f1)"
  log 'Native libraries:'
  unzip -Z1 "$artifact" '*.so' 2>/dev/null | tee -a "$report" || true
done

readelf_bin="$(command -v llvm-readelf || command -v readelf || true)"
if [[ -z "$readelf_bin" ]]; then
  log 'BLOCKED: neither llvm-readelf nor readelf is available for ELF segment inspection.'
  exit 1
fi
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
for artifact in "$apk" "$aab"; do
  while IFS= read -r entry; do
    extracted="$temporary/$(basename "$entry")"
    unzip -p "$artifact" "$entry" > "$extracted"
    while IFS= read -r alignment; do
      if (( alignment < 0x4000 )); then
        log "FAILED: $entry has ELF LOAD alignment $alignment below 0x4000."
        exit 1
      fi
    done < <("$readelf_bin" -lW "$extracted" | awk '$1 == "LOAD" {print $NF}')
  done < <(unzip -Z1 "$artifact" '*.so' 2>/dev/null || true)
  log "PASSED: native ELF LOAD segments in $(basename "$artifact") are 16 KB compatible."
done

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$sdk_root" && -f "$repo_root/android/local.properties" ]]; then
  sdk_root="$(sed -n 's/^sdk\.dir=//p' "$repo_root/android/local.properties" | head -n 1)"
fi
build_tools="$(find "$sdk_root/build-tools" -mindepth 1 -maxdepth 1 -type d -name '37*' | sort -V | tail -n 1)"
"$build_tools/zipalign" -c -P 16 4 "$apk" | tee -a "$report"
"$build_tools/apksigner" verify --verbose --print-certs "$apk" | tee -a "$report"
if command -v keytool >/dev/null; then
  keytool -printcert -jarfile "$aab" | tee -a "$report"
fi
apkanalyzer_bin="$(command -v apkanalyzer || true)"
if [[ -z "$apkanalyzer_bin" && -x "$sdk_root/cmdline-tools/latest/bin/apkanalyzer" ]]; then
  apkanalyzer_bin="$sdk_root/cmdline-tools/latest/bin/apkanalyzer"
fi
if [[ -n "$apkanalyzer_bin" ]]; then
  "$apkanalyzer_bin" manifest application-id "$apk" | tee -a "$report"
  "$apkanalyzer_bin" manifest version-name "$apk" | tee -a "$report"
  "$apkanalyzer_bin" manifest version-code "$apk" | tee -a "$report"
  "$apkanalyzer_bin" manifest min-sdk "$apk" | tee -a "$report"
  "$apkanalyzer_bin" manifest target-sdk "$apk" | tee -a "$report"
  "$apkanalyzer_bin" manifest permissions "$apk" | tee -a "$report"
fi
if [[ -n "${BUNDLETOOL_JAR:-}" && -f "$BUNDLETOOL_JAR" ]]; then
  java -jar "$BUNDLETOOL_JAR" dump config --bundle="$aab" | tee -a "$report"
else
  log 'BLOCKED: AAB bundletool alignment metadata was not inspected; set BUNDLETOOL_JAR to a local bundletool jar.'
fi
log "Inspection report: $report"
