#!/usr/bin/env bash
# Fresh core24 runtime smoke checks. This never touches an existing installation.
set -Eeuo pipefail
check='preflight'
trap 'failure_status=$?; printf "Runtime verification failed [%s] at line %s: %s (exit %s)\n" "$check" "$LINENO" "$BASH_COMMAND" "$failure_status" >&2' ERR
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
check='launch fresh Ubuntu 24.04 VM'
lxc launch ubuntu:24.04 "$instance" --vm \
  -c limits.cpu=2 -c limits.memory=4GiB \
  -c "user.busymax-release-verifier=$digest"
owned=true
for attempt in $(seq 1 90); do
  if lxc exec "$instance" -- true 2>/dev/null; then break; fi
  sleep 2
done
check='wait for cloud-init'
lxc exec "$instance" -- cloud-init status --wait
lxc file push "$snap_path" "$instance/tmp/busymax.snap"
check='runtime checks in VM'
lxc exec "$instance" -- bash -s <<'CHECK'
set -Eeuo pipefail
check='preflight'
trap 'failure_status=$?; printf "Runtime verification failed [%s] at line %s: %s (exit %s)\n" "$check" "$LINENO" "$BASH_COMMAND" "$failure_status" >&2' ERR
export DEBIAN_FRONTEND=noninteractive
check='install runtime prerequisites'
apt-get update -qq
apt-get install -y -qq --no-install-recommends snapd xvfb xauth weston dbus-x11 dbus-user-session gnome-keyring xdotool
check='install exact Snap and connect runtime content'
snap wait system seed.loaded
snap install --dangerous /tmp/busymax.snap
snap connections busymax
check='create isolated user session'
useradd -m -s /bin/bash busymaxcheck
uid=$(id -u busymaxcheck)
loginctl enable-linger busymaxcheck
install -d -m700 -o busymaxcheck -g busymaxcheck "/run/user/$uid"
systemctl start "user@$uid.service"
runuser -u busymaxcheck -- env XDG_RUNTIME_DIR="/run/user/$uid" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
  systemd-run --user --scope --quiet bash -s <<'SESSION'
set -Eeuo pipefail
check='preflight'
trap 'failure_status=$?; printf "Runtime verification failed [%s] at line %s: %s (exit %s)\n" "$check" "$LINENO" "$BASH_COMMAND" "$failure_status" >&2' ERR
cd "$HOME"
weston_pid=''
session_cleanup() {
  status=$?
  if [ "$status" != 0 ]; then
    for log in /tmp/busymax-dbus.txt /tmp/busymax-elf.txt /tmp/busymax-x11.log /tmp/busymax-wayland.log /tmp/busymax-weston.log /tmp/busymax-network.log; do
      if test -f "$log"; then printf "\n--- %s ---\n" "$log"; cat "$log"; fi
    done
  fi
  if [ -n "$weston_pid" ]; then kill "$weston_pid" 2>/dev/null || true; fi
}
trap session_cleanup EXIT
check='session D-Bus availability'
dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames > /tmp/busymax-dbus.txt
check='packaged executable'
snap run --shell busymax -c 'test -x "$SNAP/busymax"'
# Resolve BusyMax's packaged ELF files inside the content-mounted runtime.
# Do not scan every unrelated library exported by the GNOME/GPU content snaps.
check='packaged ELF dependencies'
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
  printf 'Runtime verification failed [%s]: unresolved packaged ELF dependency\n' "$check" >&2
  cat /tmp/busymax-elf.txt
  exit 1
fi
cat /tmp/busymax-elf.txt
run_x11() {
  check="X11 startup and visible window (launch $1)"
  local status=0
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
  ' || status=$?
  printf "X11 launch %s: timeout status=%s (expected 124)\n" "$1" "$status"
  test "$status" = 124
  test -f /tmp/busymax-x11-ready
  if grep -Ei 'error while loading shared libraries|symbol lookup error|cannot open display|GLIBC.*not found|Segmentation fault|Unhandled Exception' /tmp/busymax-x11.log; then
    return 1
  fi
}
run_x11 1
# Launch twice against the same per-user state to check session reopening.
run_x11 2
check='Wayland compositor startup'
weston --backend=headless --renderer=pixman --socket=wayland-0 --idle-time=0 > /tmp/busymax-weston.log 2>&1 &
weston_pid=$!
for attempt in $(seq 1 30); do
  if test -S "$XDG_RUNTIME_DIR/wayland-0"; then break; fi
  sleep 1
done
test -S "$XDG_RUNTIME_DIR/wayland-0"
check='Wayland application lifetime'
status=0
timeout --kill-after=2s 30s env WAYLAND_DISPLAY=wayland-0 WAYLAND_DEBUG=1 GDK_BACKEND=wayland snap run busymax > /tmp/busymax-wayland.log 2>&1 || status=$?
printf "Wayland: timeout status=%s (expected 124)\n" "$status"
test "$status" = 124
# Confirm GTK created a native Wayland toplevel and submitted a surface.
check='Wayland native toplevel'
grep -q "get_toplevel" /tmp/busymax-wayland.log
check='Wayland surface submission'
grep -q "wl_surface.*commit" /tmp/busymax-wayland.log
check='Wayland application errors'
if grep -Ei 'error while loading shared libraries|symbol lookup error|cannot open display|GLIBC.*not found|Segmentation fault|Unhandled Exception' /tmp/busymax-wayland.log; then
  printf 'Runtime verification failed [%s]: application error detected\n' "$check" >&2
  exit 1
fi
# Basic confined network reachability, without authorizing or modifying accounts.
check='confined network: oauth2.googleapis.com:443'
network_reachable=false
: > /tmp/busymax-network.log
for attempt in 1 2 3; do
  if ! addresses="$(timeout --kill-after=2s 15s snap run --shell busymax -c 'getent ahosts oauth2.googleapis.com' 2>> /tmp/busymax-network.log)"; then
    continue
  fi
  printf '%s\n' "$addresses" >> /tmp/busymax-network.log
  # Bash's /dev/tcp can spend the entire deadline on an unreachable first
  # address. Try every resolved STREAM address so working IPv6 is also tested.
  while read -r address kind rest; do
    [ "$kind" = STREAM ] || continue
    case "$address" in ''|*[!0-9a-fA-F:.]*) continue;; esac
    printf 'Connecting to %s:443\n' "$address" >> /tmp/busymax-network.log
    if timeout --kill-after=2s 15s snap run --shell busymax -c "bash -c 'exec 3<>/dev/tcp/$address/443'" >> /tmp/busymax-network.log 2>&1; then
      network_reachable=true
      break
    else
      printf 'Connection failed (exit %s)\n' "$?" >> /tmp/busymax-network.log
    fi
  done <<< "$addresses"
  if $network_reachable; then break; fi
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
