#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tools/build_install_snap_local.sh [version] [options]

Build the Flutter Linux release, replace the payload in an installed snap
scaffold, pack it, install it locally, and optionally run it.

Options:
  --no-run             Install the snap but do not run it.
  --skip-tests         Skip flutter analyze/test.
  --output FILE        Write the packed snap to FILE.
  --root DIR           Use DIR as the temporary snap root.
  --scaffold DIR       Use DIR instead of /snap/<snap-name>/current.
  --snap-name NAME     Override the snap name.
  --binary-name NAME   Override the Linux executable name.
  --app-id ID          Override the desktop/application id.
  --dart-define K=V    Pass a compile-time Flutter define. Repeatable.
  --dart-define-from-file FILE
                       Pass Flutter compile-time defines from FILE.
  -h, --help           Show this help.

Environment overrides are also supported:
  VERSION, OUT, SNAP_ROOT, SNAP_SCAFFOLD, SNAP_NAME, BINARY_NAME, APP_ID,
  RUN_AFTER_INSTALL=0, SKIP_TESTS=1, DART_DEFINE_FROM_FILE
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

project_value() {
  local key="$1"
  sed -nE "s/^${key}:[[:space:]]*['\"]?([^'\"]+)['\"]?[[:space:]]*$/\\1/p" \
    pubspec.yaml | head -n 1
}

cmake_value() {
  local key="$1"
  sed -nE "s/^[[:space:]]*set\\(${key}[[:space:]]+\"([^\"]+)\"\\).*/\\1/p" \
    linux/CMakeLists.txt | head -n 1
}

snapcraft_value() {
  local key="$1"
  [[ -f snap/snapcraft.yaml ]] || return 0
  sed -nE "s/^${key}:[[:space:]]*['\"]?([^'\"]+)['\"]?[[:space:]]*$/\\1/p" \
    snap/snapcraft.yaml | head -n 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

VERSION_ARG=""
RUN_AFTER_INSTALL="${RUN_AFTER_INSTALL:-1}"
SKIP_TESTS="${SKIP_TESTS:-0}"
declare -a DART_DEFINE_ARGS=()
declare -a DART_DEFINE_FILE_ARGS=()

if [[ -n "${DART_DEFINE_FROM_FILE:-}" ]]; then
  DART_DEFINE_FILE_ARGS+=("--dart-define-from-file=$DART_DEFINE_FROM_FILE")
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-run)
      RUN_AFTER_INSTALL=0
      ;;
    --skip-tests)
      SKIP_TESTS=1
      ;;
    --output)
      [[ $# -ge 2 ]] || fail "--output requires a value"
      OUT="$2"
      shift
      ;;
    --root)
      [[ $# -ge 2 ]] || fail "--root requires a value"
      SNAP_ROOT="$2"
      shift
      ;;
    --scaffold)
      [[ $# -ge 2 ]] || fail "--scaffold requires a value"
      SNAP_SCAFFOLD="$2"
      shift
      ;;
    --snap-name)
      [[ $# -ge 2 ]] || fail "--snap-name requires a value"
      SNAP_NAME="$2"
      shift
      ;;
    --binary-name)
      [[ $# -ge 2 ]] || fail "--binary-name requires a value"
      BINARY_NAME="$2"
      shift
      ;;
    --app-id)
      [[ $# -ge 2 ]] || fail "--app-id requires a value"
      APP_ID="$2"
      shift
      ;;
    --dart-define)
      [[ $# -ge 2 ]] || fail "--dart-define requires KEY=VALUE"
      DART_DEFINE_ARGS+=("--dart-define=$2")
      shift
      ;;
    --dart-define=*)
      DART_DEFINE_ARGS+=("$1")
      ;;
    --dart-define-from-file)
      [[ $# -ge 2 ]] || fail "--dart-define-from-file requires a file"
      DART_DEFINE_FILE_ARGS+=("--dart-define-from-file=$2")
      shift
      ;;
    --dart-define-from-file=*)
      DART_DEFINE_FILE_ARGS+=("$1")
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      fail "unknown option: $1"
      ;;
    *)
      [[ -z "$VERSION_ARG" ]] || fail "only one version argument is supported"
      VERSION_ARG="$1"
      ;;
  esac
  shift
done

PROJECT_NAME="$(project_value name)"
[[ -n "$PROJECT_NAME" ]] || fail "could not read project name from pubspec.yaml"

VERSION="${VERSION_ARG:-${VERSION:-$(project_value version)}}"
[[ -n "$VERSION" ]] || fail "could not read version from pubspec.yaml"

SNAP_NAME="${SNAP_NAME:-$PROJECT_NAME}"
BINARY_NAME="${BINARY_NAME:-$(cmake_value BINARY_NAME)}"
BINARY_NAME="${BINARY_NAME:-$PROJECT_NAME}"
APP_ID="${APP_ID:-$(cmake_value APPLICATION_ID)}"
APP_ID="${APP_ID:-$SNAP_NAME}"
ICON_SOURCE="${ICON_SOURCE:-$(snapcraft_value icon)}"

SNAP_SCAFFOLD="${SNAP_SCAFFOLD:-/snap/${SNAP_NAME}/current}"
SNAP_ROOT="${SNAP_ROOT:-/tmp/${SNAP_NAME}-snap-root}"
OUT="${OUT:-${SNAP_NAME}_${VERSION}_amd64_$(date +%Y%m%d%H%M%S).snap}"
BUNDLE_DIR="build/linux/x64/release/bundle"

echo "== ${SNAP_NAME} local snap build =="
echo "Project:  $PROJECT_ROOT"
echo "Version:  $VERSION"
echo "Binary:   $BINARY_NAME"
echo "App ID:   $APP_ID"
echo "Scaffold: $SNAP_SCAFFOLD"
echo "Root:     $SNAP_ROOT"
echo "Output:   $OUT"
echo "Defines:  $((${#DART_DEFINE_ARGS[@]} + ${#DART_DEFINE_FILE_ARGS[@]})) build-time entries"

if [[ "$SKIP_TESTS" != "1" ]]; then
  echo "== Validate source =="
  flutter analyze
  flutter test --reporter=compact
else
  echo "== Validate source =="
  echo "Skipping tests because SKIP_TESTS=1"
fi

echo "== Build Flutter Linux release =="
flutter build linux --release "${DART_DEFINE_ARGS[@]}" "${DART_DEFINE_FILE_ARGS[@]}"

test -f "$BUNDLE_DIR/$BINARY_NAME" || fail "missing built binary: $BUNDLE_DIR/$BINARY_NAME"

echo "== Recreate snap root from installed scaffold =="
test -d "$SNAP_SCAFFOLD" || {
  echo "No installed snap scaffold at $SNAP_SCAFFOLD"
  echo "Install the snap once from the store or pass --scaffold DIR."
  exit 1
}

rm -rf "$SNAP_ROOT"
mkdir -p "$SNAP_ROOT"
cp -a "$SNAP_SCAFFOLD/." "$SNAP_ROOT/"

test -f "$SNAP_ROOT/meta/snap.yaml" || fail "missing $SNAP_ROOT/meta/snap.yaml"

echo "== Replace Flutter payload =="
rm -rf "$SNAP_ROOT/$BINARY_NAME" "$SNAP_ROOT/data" "$SNAP_ROOT/lib"
cp -a "$BUNDLE_DIR/." "$SNAP_ROOT/"

test -f "$SNAP_ROOT/$BINARY_NAME" || fail "missing staged binary: $SNAP_ROOT/$BINARY_NAME"

echo "== Stage desktop integration files =="
DESKTOP_SOURCE="linux/${APP_ID}.desktop"
METAINFO_SOURCE="linux/${APP_ID}.metainfo.xml"

if [[ -f "$DESKTOP_SOURCE" ]]; then
  install -Dm644 "$DESKTOP_SOURCE" \
    "$SNAP_ROOT/share/applications/${APP_ID}.desktop"
else
  echo "No desktop file found at $DESKTOP_SOURCE"
fi

if [[ -n "$ICON_SOURCE" && -f "$ICON_SOURCE" ]]; then
  ICON_EXT="${ICON_SOURCE##*.}"
  install -Dm644 "$ICON_SOURCE" "$SNAP_ROOT/meta/gui/${APP_ID}.${ICON_EXT}"
  install -Dm644 "$ICON_SOURCE" "$SNAP_ROOT/meta/gui/icon.${ICON_EXT}"
  install -Dm644 "$ICON_SOURCE" \
    "$SNAP_ROOT/share/icons/hicolor/scalable/apps/${APP_ID}.${ICON_EXT}"

  if [[ -f "$DESKTOP_SOURCE" ]]; then
    mkdir -p "$SNAP_ROOT/meta/gui"
    sed "s#^Icon=.*#Icon=\${SNAP}/meta/gui/${APP_ID}.${ICON_EXT}#" \
      "$DESKTOP_SOURCE" > "$SNAP_ROOT/meta/gui/${APP_ID}.desktop"
  fi
else
  echo "No icon file found from snapcraft icon: ${ICON_SOURCE:-<unset>}"
fi

if [[ -f "$METAINFO_SOURCE" ]]; then
  install -Dm644 "$METAINFO_SOURCE" \
    "$SNAP_ROOT/share/metainfo/${APP_ID}.metainfo.xml"
fi

echo "== Patch staged snap metadata =="
python3 - "$SNAP_ROOT/meta/snap.yaml" "snap/snapcraft.yaml" "$VERSION" "$SNAP_NAME" <<'PY'
from pathlib import Path
import re
import sys

meta_path = Path(sys.argv[1])
source_path = Path(sys.argv[2])
version = sys.argv[3]
app_name = sys.argv[4]

text = meta_path.read_text()
text, count = re.subn(r"(?m)^version:\s*.*$", f"version: {version}", text, count=1)
if count != 1:
    raise SystemExit("version line not found in meta/snap.yaml")

# snap pack consumes installed-style metadata. Source snapcraft-only keys are
# removed from the temporary root only; source files are left untouched.
text = re.sub(r"(?m)^icon:\s*.*\n", "", text)
text = re.sub(r"(?m)^[ \t]+desktop:\s*.*\n", "", text)


def extract_app_list(source: str, app: str, key: str) -> list[str]:
    lines = source.splitlines()
    apps_index = next(
        (i for i, line in enumerate(lines) if line.rstrip() == "apps:"), None
    )
    if apps_index is None:
        return []

    app_start = None
    for i in range(apps_index + 1, len(lines)):
        if re.match(r"^\S", lines[i]):
            break
        if lines[i].rstrip() == f"  {app}:":
            app_start = i
            break
    if app_start is None:
        return []

    app_end = len(lines)
    for i in range(app_start + 1, len(lines)):
        if re.match(r"^  \S.*:\s*$", lines[i]):
            app_end = i
            break
        if re.match(r"^\S", lines[i]):
            app_end = i
            break

    key_start = None
    for i in range(app_start + 1, app_end):
        if lines[i].rstrip() == f"    {key}:":
            key_start = i
            break
    if key_start is None:
        return []

    items: list[str] = []
    for i in range(key_start + 1, app_end):
        if re.match(r"^    [A-Za-z0-9_-][^:]*:", lines[i]):
            break
        match = re.match(r"^\s*-\s+(.+?)\s*$", lines[i])
        if match:
            items.append(match.group(1))
    return items


def ensure_app_list_items(target: str, app: str, key: str, items: list[str]) -> str:
    if not items:
        return target

    lines = target.splitlines(keepends=True)
    app_start = next(
        (i for i, line in enumerate(lines) if line.rstrip() == f"  {app}:"),
        None,
    )
    if app_start is None:
        raise SystemExit(f"app {app!r} not found in meta/snap.yaml")

    app_end = len(lines)
    for i in range(app_start + 1, len(lines)):
        if re.match(r"^  \S.*:\s*$", lines[i]):
            app_end = i
            break
        if re.match(r"^\S", lines[i]):
            app_end = i
            break

    key_start = None
    for i in range(app_start + 1, app_end):
        if lines[i].rstrip() == f"    {key}:":
            key_start = i
            break

    if key_start is None:
        insertion = [f"    {key}:\n", *[f"      - {item}\n" for item in items]]
        lines[app_start + 1:app_start + 1] = insertion
        return "".join(lines)

    key_end = app_end
    existing: set[str] = set()
    for i in range(key_start + 1, app_end):
        if re.match(r"^    [A-Za-z0-9_-][^:]*:", lines[i]):
            key_end = i
            break
        match = re.match(r"^\s*-\s+(.+?)\s*$", lines[i])
        if match:
            existing.add(match.group(1))

    missing = [item for item in items if item not in existing]
    if missing:
        lines[key_end:key_end] = [f"      - {item}\n" for item in missing]
    return "".join(lines)


if source_path.exists():
    source = source_path.read_text()
    text = ensure_app_list_items(
        text,
        app_name,
        "plugs",
        extract_app_list(source, app_name, "plugs"),
    )

meta_path.write_text(text)
PY

grep '^version:' "$SNAP_ROOT/meta/snap.yaml"
grep -A80 "^  ${SNAP_NAME}:" "$SNAP_ROOT/meta/snap.yaml" | sed -n '/plugs:/,/^[[:space:]]*[[:alpha:]_-].*:/p'

echo "== Pack snap =="
snap pack "$SNAP_ROOT" --filename="$OUT"

echo "== Verify packed snap =="
unsquashfs -cat "$OUT" meta/snap.yaml | grep '^version:'
unsquashfs -ll "$OUT" | grep -F "$BINARY_NAME"
if [[ -d "$BUNDLE_DIR/lib" ]]; then
  while IFS= read -r plugin; do
    name="$(basename "$plugin")"
    unsquashfs -ll "$OUT" | grep -F "$name" >/dev/null
  done < <(find "$BUNDLE_DIR/lib" -maxdepth 1 -type f -name 'lib*_plugin.so' | sort)
fi
! unsquashfs -cat "$OUT" meta/snap.yaml | grep -q '^icon:'
! unsquashfs -cat "$OUT" meta/snap.yaml | grep -q '^[[:space:]]*desktop:'

echo "== Install snap =="
sudo snap remove --purge "$SNAP_NAME" 2>/dev/null || true
sudo snap install --dangerous "./$OUT"

echo "== Verify installed snap =="
snap connections "$SNAP_NAME" || true
snap info "$SNAP_NAME" | sed -n '/installed:/p;/tracking:/p'

echo "Built snap: $OUT"
if [[ "$RUN_AFTER_INSTALL" == "1" ]]; then
  echo "== Running ${SNAP_NAME} =="
  snap run "$SNAP_NAME"
else
  echo "Run skipped. Start it with: snap run $SNAP_NAME"
fi
