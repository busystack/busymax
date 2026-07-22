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
  --root DIR           Use DIR as the temporary snap root. Existing directories
                       must have been created by this helper.
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

canonical_path() {
  local label="$1"
  local path="$2"
  local canonical
  [[ -n "${path//[[:space:]]/}" ]] || fail "$label must not be empty"
  canonical="$(realpath -m -- "$path")" || fail "could not resolve $label: $path"
  [[ "$canonical" == /* ]] || fail "$label did not resolve to an absolute path: $path"
  printf '%s\n' "$canonical"
}

path_is_within() {
  local path="$1"
  local parent="$2"
  [[ "$path" == "$parent" || "$path" == "$parent/"* ]]
}

validate_path_component() {
  local label="$1"
  local value="$2"
  [[ -n "$value" && "$value" != "." && "$value" != ".." ]] ||
    fail "$label must be a non-empty file name"
  [[ "$value" != */* ]] || fail "$label must not contain path separators: $value"
  [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] ||
    fail "$label contains unsupported characters: $value"
}

reject_snap_root_overlap() {
  local label="$1"
  local protected="$2"
  local mode="${3:-ancestor-only}"
  [[ -n "$protected" ]] || return 0

  if path_is_within "$protected" "$SNAP_ROOT"; then
    fail "unsafe snap root $SNAP_ROOT: it contains $label $protected"
  fi
  if [[ "$mode" == "both" ]] && path_is_within "$SNAP_ROOT" "$protected"; then
    fail "unsafe snap root $SNAP_ROOT: it is inside $label $protected"
  fi
}

validate_snap_root() {
  SNAP_ROOT="$(canonical_path "snap root" "$SNAP_ROOT")"
  [[ "$SNAP_ROOT" != "/" ]] || fail "unsafe snap root: /"

  reject_snap_root_overlap "the project" "$PROJECT_ROOT" both
  reject_snap_root_overlap "the invocation directory" "$INVOCATION_DIR"
  reject_snap_root_overlap "the temporary directory" "$TEMP_BASE"
  reject_snap_root_overlap "the snap scaffold" "$CANONICAL_SCAFFOLD" both

  local home_path
  for home_path in "${PROTECTED_HOME_PATHS[@]}"; do
    reject_snap_root_overlap "a home directory" "$home_path"
  done

  if [[ -e "$SNAP_ROOT" || -L "$SNAP_ROOT" ]]; then
    [[ -d "$SNAP_ROOT" ]] || fail "snap root exists but is not a directory: $SNAP_ROOT"
    snap_root_has_valid_marker ||
      fail "refusing to delete unowned snap root: $SNAP_ROOT"
  fi
}

snap_root_marker_contents() {
  printf 'busymax-local-snap-root-v1\nproject=%s\n' "$PROJECT_ROOT"
}

snap_root_has_valid_marker() {
  local marker="$SNAP_ROOT/$SNAP_ROOT_MARKER_NAME"
  [[ -f "$marker" && ! -L "$marker" ]] || return 1
  [[ "$(cat -- "$marker")" == "$(snap_root_marker_contents)" ]]
}

write_snap_root_marker() {
  local current
  [[ -d "$SNAP_ROOT" ]] || return 0
  current="$(realpath -m -- "$SNAP_ROOT")" || return 0
  [[ "$current" == "$SNAP_ROOT" ]] || return 0
  snap_root_marker_contents > "$SNAP_ROOT/$SNAP_ROOT_MARKER_NAME"
}

prepare_snap_root() {
  validate_snap_root
  if [[ -e "$SNAP_ROOT" || -L "$SNAP_ROOT" ]]; then
    rm -rf -- "$SNAP_ROOT"
  fi
  mkdir -p -- "$SNAP_ROOT"
  write_snap_root_marker
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

INVOCATION_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$PROJECT_ROOT"

SNAP_ROOT_MARKER_NAME=".busymax-local-snap-root"

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

if [[ ${SNAP_ROOT+x} == x ]]; then
  [[ -n "${SNAP_ROOT//[[:space:]]/}" ]] || fail "snap root must not be empty"
fi

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

validate_path_component "snap name" "$SNAP_NAME"
validate_path_component "binary name" "$BINARY_NAME"
validate_path_component "app id" "$APP_ID"

TEMP_BASE="$(canonical_path "temporary directory" "${TMPDIR:-/tmp}")"
CANONICAL_SCAFFOLD="$(canonical_path "snap scaffold" "$SNAP_SCAFFOLD")"
declare -a PROTECTED_HOME_PATHS=()
if [[ -n "${HOME:-}" ]]; then
  PROTECTED_HOME_PATHS+=("$(canonical_path "home directory" "$HOME")")
fi
if command -v getent >/dev/null 2>&1; then
  PASSWD_HOME="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6 || true)"
  if [[ -n "$PASSWD_HOME" ]]; then
    PROTECTED_HOME_PATHS+=(
      "$(canonical_path "account home directory" "$PASSWD_HOME")"
    )
  fi
  if [[ -n "${SUDO_USER:-}" ]]; then
    SUDO_USER_HOME="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || true)"
    if [[ -n "$SUDO_USER_HOME" ]]; then
      PROTECTED_HOME_PATHS+=(
        "$(canonical_path "sudo user home directory" "$SUDO_USER_HOME")"
      )
    fi
  fi
fi
validate_snap_root

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

prepare_snap_root
trap write_snap_root_marker EXIT
cp -a -- "$SNAP_SCAFFOLD/." "$SNAP_ROOT/"
write_snap_root_marker

test -f "$SNAP_ROOT/meta/snap.yaml" || fail "missing $SNAP_ROOT/meta/snap.yaml"

echo "== Replace Flutter payload =="
rm -rf -- "$SNAP_ROOT/$BINARY_NAME" "$SNAP_ROOT/data" "$SNAP_ROOT/lib"
cp -a -- "$BUNDLE_DIR/." "$SNAP_ROOT/"

test -f "$SNAP_ROOT/$BINARY_NAME" || fail "missing staged binary: $SNAP_ROOT/$BINARY_NAME"

echo "== Stage desktop integration files =="
DESKTOP_SOURCE="linux/${APP_ID}.desktop"
METAINFO_SOURCE="linux/${APP_ID}.metainfo.xml"

if [[ -f "$DESKTOP_SOURCE" ]]; then
  install -Dm644 "$DESKTOP_SOURCE" \
    "$SNAP_ROOT/share/applications/${APP_ID}.desktop"
  mkdir -p "$SNAP_ROOT/meta/gui"
  find "$SNAP_ROOT/meta/gui" -mindepth 1 -maxdepth 1 \
    \( -type f -o -type l \) -name '*.desktop' -exec rm -f -- {} +
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
    sed "s#^Icon=.*#Icon=\${SNAP}/meta/gui/icon.${ICON_EXT}#" \
      "$DESKTOP_SOURCE" > "$SNAP_ROOT/meta/gui/${SNAP_NAME}.desktop"
  fi
else
  echo "No icon file found from snapcraft icon: ${ICON_SOURCE:-<unset>}"
fi

if [[ -f "$METAINFO_SOURCE" ]]; then
  install -Dm644 "$METAINFO_SOURCE" \
    "$SNAP_ROOT/share/metainfo/${APP_ID}.metainfo.xml"
fi

STAGED_DESKTOP_MANIFEST="$(
  find "$SNAP_ROOT/meta/gui" -mindepth 1 -maxdepth 1 \
    -type f -name '*.desktop' -printf '%f\n' | LC_ALL=C sort
)"
[[ "$STAGED_DESKTOP_MANIFEST" == "${SNAP_NAME}.desktop" ]] ||
  fail "expected exactly one staged launcher: ${SNAP_NAME}.desktop"

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
rm -f -- "$SNAP_ROOT/$SNAP_ROOT_MARKER_NAME"
snap pack "$SNAP_ROOT" --filename="$OUT"

echo "== Verify packed snap =="
unsquashfs -cat "$OUT" meta/snap.yaml | grep '^version:'
unsquashfs -ll "$OUT" | grep -F "$BINARY_NAME"
PACKED_DESKTOP_MANIFEST="$(
  unsquashfs -ll "$OUT" |
    sed -nE 's#^.*squashfs-root/meta/gui/([^/]+\.desktop)$#\1#p' |
    LC_ALL=C sort
)"
[[ "$PACKED_DESKTOP_MANIFEST" == "${SNAP_NAME}.desktop" ]] ||
  fail "expected exactly one packed launcher: ${SNAP_NAME}.desktop"
if [[ -d "$BUNDLE_DIR/lib" ]]; then
  while IFS= read -r plugin; do
    name="$(basename "$plugin")"
    unsquashfs -ll "$OUT" | grep -F "$name" >/dev/null
  done < <(find "$BUNDLE_DIR/lib" -maxdepth 1 -type f -name 'lib*_plugin.so' | sort)
fi
! unsquashfs -cat "$OUT" meta/snap.yaml | grep -q '^icon:'
! unsquashfs -cat "$OUT" meta/snap.yaml | grep -q '^[[:space:]]*desktop:'

echo "== Install snap =="
INSTALL_SNAP_PATH="$OUT"
if [[ "$INSTALL_SNAP_PATH" != /* ]]; then
  INSTALL_SNAP_PATH="./$INSTALL_SNAP_PATH"
fi
sudo snap install --dangerous "$INSTALL_SNAP_PATH"

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
