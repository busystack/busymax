#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tools/install_linux_dev_desktop.sh [options]

Register this BusyMax checkout with the current user's Linux desktop so GNOME
can associate native Wayland windows with the BusyMax launcher and icon.

Options:
  --executable FILE  Launcher target. Defaults to the Flutter debug bundle.
  --uninstall        Remove files previously installed by this helper.
  -h, --help         Show this help.
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
APP_ID="io.busystack.busymax"
DESKTOP_SOURCE="$PROJECT_ROOT/linux/${APP_ID}.desktop"
ICON_SOURCE="$PROJECT_ROOT/assets/branding/busymax-logo.svg"
EXECUTABLE="$PROJECT_ROOT/build/linux/x64/debug/bundle/busymax"
UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --executable)
      [[ $# -ge 2 ]] || fail "--executable requires a value"
      EXECUTABLE="$2"
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
  shift
done

[[ -f "$DESKTOP_SOURCE" ]] || fail "desktop entry not found: $DESKTOP_SOURCE"
[[ -f "$ICON_SOURCE" ]] || fail "icon not found: $ICON_SOURCE"

if [[ "$EXECUTABLE" != /* ]]; then
  EXECUTABLE="$PROJECT_ROOT/$EXECUTABLE"
fi
EXECUTABLE="$(realpath -m -- "$EXECUTABLE")"
case "$EXECUTABLE" in
  *$'\n'*|*$'\r'*|*%*)
    fail "executable path contains characters unsupported by desktop entries"
    ;;
esac

if [[ -n "${XDG_DATA_HOME:-}" ]]; then
  DATA_HOME="$(realpath -m -- "$XDG_DATA_HOME")"
else
  [[ -n "${HOME:-}" ]] || fail "HOME or XDG_DATA_HOME must be set"
  DATA_HOME="$(realpath -m -- "$HOME/.local/share")"
fi

DESKTOP_DEST="$DATA_HOME/applications/${APP_ID}.desktop"
ICON_DEST="$DATA_HOME/icons/hicolor/scalable/apps/${APP_ID}.svg"
OWNERSHIP_MARKER="X-BusyMax-Development=true"

refresh_desktop_database() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DATA_HOME/applications"
  fi
}

if [[ "$UNINSTALL" == 1 ]]; then
  if [[ ! -e "$DESKTOP_DEST" && ! -L "$DESKTOP_DEST" ]]; then
    echo "BusyMax development desktop entry is not installed."
    exit 0
  fi
  [[ ! -L "$DESKTOP_DEST" ]] ||
    fail "refusing to remove symbolic link: $DESKTOP_DEST"
  grep -Fxq "$OWNERSHIP_MARKER" "$DESKTOP_DEST" ||
    fail "refusing to remove desktop entry not owned by this helper: $DESKTOP_DEST"

  rm -f -- "$DESKTOP_DEST" "$ICON_DEST"
  refresh_desktop_database
  echo "Removed BusyMax development desktop registration."
  exit 0
fi

if [[ -e "$DESKTOP_DEST" || -L "$DESKTOP_DEST" ]]; then
  [[ ! -L "$DESKTOP_DEST" ]] ||
    fail "refusing to replace symbolic link: $DESKTOP_DEST"
  grep -Fxq "$OWNERSHIP_MARKER" "$DESKTOP_DEST" ||
    fail "refusing to replace desktop entry not owned by this helper: $DESKTOP_DEST"
fi
[[ ! -L "$ICON_DEST" ]] ||
  fail "refusing to replace symbolic link: $ICON_DEST"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/busymax-dev-desktop.XXXXXX")"
trap 'rm -rf -- "$TEMP_DIR"' EXIT
GENERATED_DESKTOP="$TEMP_DIR/${APP_ID}.desktop"

awk -v executable="$EXECUTABLE" -v icon="$ICON_DEST" '
  /^Exec=/ {
    print "Exec=\"" executable "\""
    next
  }
  /^Icon=/ {
    print "Icon=" icon
    next
  }
  /^X-BusyMax-Development=/ { next }
  { print }
  END { print "X-BusyMax-Development=true" }
' "$DESKTOP_SOURCE" > "$GENERATED_DESKTOP"

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$GENERATED_DESKTOP"
fi

install -Dm644 "$GENERATED_DESKTOP" "$DESKTOP_DEST"
install -Dm644 "$ICON_SOURCE" "$ICON_DEST"
refresh_desktop_database

echo "Registered BusyMax for native Wayland desktop integration:"
echo "  Desktop entry: $DESKTOP_DEST"
echo "  Icon:          $ICON_DEST"
echo "  Executable:    $EXECUTABLE"
if [[ ! -x "$EXECUTABLE" ]]; then
  echo "The executable does not exist yet; Flutter will create it on first run."
fi
echo "Quit all BusyMax windows and relaunch the app to refresh its dock icon."
