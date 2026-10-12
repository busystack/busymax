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
apt-get install -y -qq snapd xvfb weston dbus-x11 gnome-keyring xdotool
snap wait system seed.loaded
snap install --dangerous /tmp/busymax.snap
snap connections busymax
snap run --shell busymax -c 'test -x "$SNAP/busymax"'
# Resolve ELF dependencies inside the extension's command chain and confinement.
snap run --shell busymax -c '
  set -e
  find "$SNAP" -type f \( -name "*.so" -o -name "*.so.*" -o -name busymax \) -print |
  while IFS= read -r file; do
    report=$(ldd "$file" 2>&1) || {
      case "$report" in *"not a dynamic executable"*|*"statically linked"*) continue;; esac
      printf "%s\n" "$report"; exit 1
    }
    printf "%s\n%s\n" "$file" "$report"
    case "$report" in *"not found"*|*"version "*" not found"*) exit 1;; esac
  done
' > /tmp/busymax-elf.txt
cat /tmp/busymax-elf.txt
useradd -m -s /bin/bash busymaxcheck
uid=$(id -u busymaxcheck)
loginctl enable-linger busymaxcheck
install -d -m700 -o busymaxcheck -g busymaxcheck "/run/user/$uid"
runuser -u busymaxcheck -- env XDG_RUNTIME_DIR="/run/user/$uid" bash -s <<'SESSION'
set -euo pipefail
run_x11() {
  set +e
  rm -f /tmp/busymax-x11-ready
  timeout 30s dbus-run-session -- xvfb-run -a env GDK_BACKEND=x11 bash -c '
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
weston --backend=headless --renderer=pixman --socket=wayland-busymax --idle-time=0 > /tmp/busymax-weston.log 2>&1 &
weston_pid=$!
trap 'kill "$weston_pid" 2>/dev/null || true' EXIT
for attempt in $(seq 1 30); do
  if test -S "$XDG_RUNTIME_DIR/wayland-busymax"; then break; fi
  sleep 1
done
test -S "$XDG_RUNTIME_DIR/wayland-busymax"
set +e
timeout 30s dbus-run-session -- env WAYLAND_DISPLAY=wayland-busymax GDK_BACKEND=wayland snap run busymax > /tmp/busymax-wayland.log 2>&1
status=$?
set -e
test "$status" = 124
! grep -Ei 'error while loading shared libraries|symbol lookup error|cannot open display|GLIBC.*not found|Segmentation fault' /tmp/busymax-wayland.log
SESSION
cat /tmp/busymax-x11.log /tmp/busymax-wayland.log
# Basic confined network reachability, without authorizing or modifying accounts.
snap run --shell busymax -c 'bash -c "exec 3<>/dev/tcp/oauth2.googleapis.com/443"'
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
