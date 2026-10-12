#!/usr/bin/env bash
# Fresh core24 runtime smoke checks. This never touches an existing installation.
set -euo pipefail
snap_path="$(readlink -f "${1:?Supply the exact Snap}")"
evidence_path="$(realpath -m "${2:?Supply the evidence output path}")"
test -f "$snap_path"
test ! -e "$evidence_path"
digest="$(sha256sum "$snap_path" | cut -d ' ' -f1)"
instance="busymax-check-${digest:0:12}"
if lxc info "$instance" >/dev/null 2>&1; then
  echo 'Runtime verification instance already exists; retain it and select a fresh build.' >&2
  exit 1
fi
owned=false
cleanup() {
  if $owned; then
    # Only the instance created and tagged by this invocation may be removed.
    if [ "$(lxc config get "$instance" user.busymax-release-verifier)" = "$digest" ]; then
      lxc stop "$instance" --timeout 30
      lxc delete "$instance"
    fi
  fi
}
trap cleanup EXIT
lxc launch ubuntu:24.04 "$instance" --vm \
  -c limits.cpu=2 -c limits.memory=4GiB \
  -c "user.busymax-release-verifier=$digest"
owned=true
for attempt in $(seq 1 90); do
  if lxc exec "$instance" -- true 2>/dev/null; then break; fi
  sleep 2
done
lxc exec "$instance" -- cloud-init status --wait
lxc file push "$snap_path" "$instance/tmp/busymax.snap"
lxc exec "$instance" -- bash -s <<'CHECK'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends snapd xvfb xauth weston dbus-x11 dbus-user-session gnome-keyring xdotool
snap wait system seed.loaded
snap install --dangerous /tmp/busymax.snap
snap connections busymax
useradd -m -s /bin/bash busymaxcheck
uid=$(id -u busymaxcheck)
loginctl enable-linger busymaxcheck
install -d -m700 -o busymaxcheck -g busymaxcheck "/run/user/$uid"
systemctl start "user@$uid.service"
runuser -u busymaxcheck -- env XDG_RUNTIME_DIR="/run/user/$uid" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
  systemd-run --user --scope --quiet bash -s <<'SESSION'
set -euo pipefail
cd "$HOME"
weston_pid=''
session_cleanup() {
  status=$?
  if [ "$status" != 0 ]; then
    for log in /tmp/busymax-elf.txt /tmp/busymax-x11.log /tmp/busymax-wayland.log /tmp/busymax-weston.log; do
      if test -f "$log"; then cat "$log"; fi
    done
  fi
  if [ -n "$weston_pid" ]; then kill "$weston_pid" 2>/dev/null || true; fi
}
trap session_cleanup EXIT
snap run --shell busymax -c 'test -x "$SNAP/busymax"'
# Resolve BusyMax's packaged ELF files inside the content-mounted runtime.
# Do not scan every unrelated library exported by the GNOME/GPU content snaps.
if ! snap run --shell busymax -c '
  set -e
  find "$SNAP/busymax" "$SNAP/lib" "$SNAP/usr" -type f \( -name "*.so" -o -name "*.so.*" -o -name busymax \) -print |
  while IFS= read -r file; do
    report=$(ldd "$file" 2>&1) || {
      case "$report" in *"not a dynamic executable"*|*"statically linked"*) continue;; esac
      printf "%s\n" "$report"; exit 1
    }
    printf "%s\n%s\n" "$file" "$report"
    case "$report" in *"not found"*|*"version "*" not found"*) exit 1;; esac
  done
' > /tmp/busymax-elf.txt 2>&1; then
  cat /tmp/busymax-elf.txt
  exit 1
fi
cat /tmp/busymax-elf.txt
run_x11() {
  set +e
  rm -f /tmp/busymax-x11-ready
  timeout --kill-after=2s 30s xvfb-run -a env GDK_BACKEND=x11 bash -c '
    snap run busymax > /tmp/busymax-x11.log 2>&1 &
    app_pid=$!
    for attempt in $(seq 1 25); do
      if xdotool search --onlyvisible --pid "$app_pid" >/dev/null 2>&1; then
        touch /tmp/busymax-x11-ready
        break
      fi
      sleep 1
    done
    wait "$app_pid"
  '
  status=$?
  set -e
  test "$status" = 124
  test -f /tmp/busymax-x11-ready
  ! grep -Ei 'error while loading shared libraries|symbol lookup error|cannot open display|GLIBC.*not found|Segmentation fault' /tmp/busymax-x11.log
}
run_x11
# Launch twice against the same per-user state to check session reopening.
run_x11
weston --backend=headless --renderer=pixman --socket=wayland-0 --idle-time=0 > /tmp/busymax-weston.log 2>&1 &
weston_pid=$!
for attempt in $(seq 1 30); do
  if test -S "$XDG_RUNTIME_DIR/wayland-0"; then break; fi
  sleep 1
done
test -S "$XDG_RUNTIME_DIR/wayland-0"
set +e
timeout --kill-after=2s 30s env WAYLAND_DISPLAY=wayland-0 WAYLAND_DEBUG=1 GDK_BACKEND=wayland snap run busymax > /tmp/busymax-wayland.log 2>&1
status=$?
set -e
test "$status" = 124
# Confirm GTK created a native Wayland toplevel and submitted a surface.
grep -q "get_toplevel" /tmp/busymax-wayland.log
grep -q "wl_surface.*commit" /tmp/busymax-wayland.log
! grep -Ei 'error while loading shared libraries|symbol lookup error|cannot open display|GLIBC.*not found|Segmentation fault' /tmp/busymax-wayland.log
# Basic confined network reachability, without authorizing or modifying accounts.
network_reachable=false
for attempt in 1 2 3; do
  if timeout --kill-after=2s 15s snap run --shell busymax -c 'bash -c "exec 3<>/dev/tcp/oauth2.googleapis.com/443"'; then
    network_reachable=true
    break
  fi
done
$network_reachable
SESSION
cat /tmp/busymax-x11.log /tmp/busymax-wayland.log
CHECK
# Evidence is only written after every command above succeeds.
python3 - "$evidence_path" "$digest" <<'PY'
import json, sys
from pathlib import Path
with Path(sys.argv[1]).open('x') as stream:
    json.dump({'schema':1, 'snap_sha256':sys.argv[2], 'environment':'fresh Ubuntu 24.04 LXD VM',
               'elf_dependencies':True, 'startup_x11':True, 'startup_wayland':True,
               'restart':True, 'confined_network':True,
               'interactive_provider_acceptance':'pending'}, stream, indent=2)
PY
