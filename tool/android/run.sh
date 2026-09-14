#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
device=''
extra=()
while (($#)); do
  case "$1" in
    --device) device="${2:-}"; shift 2 ;;
    --) shift; extra+=("$@"); break ;;
    *) echo 'Usage: tool/android/run.sh --device DEVICE_ID [-- flutter-run-options]' >&2; exit 64 ;;
  esac
done
if [[ -z "$device" ]]; then
  echo 'A device is required: tool/android/run.sh --device DEVICE_ID' >&2
  exit 64
fi
"$repo_root/tool/android/check_prerequisites.sh"
flutter_bin="${BUSYMAX_FLUTTER_EXECUTABLE:-$(command -v flutter)}"
if ! "$flutter_bin" devices | grep -Fq -- "$device"; then
  echo "Flutter does not report a connected device matching '$device'." >&2
  exit 1
fi
cd "$repo_root"
exec "$flutter_bin" run -d "$device" -t lib/main_android.dart "${extra[@]}"
