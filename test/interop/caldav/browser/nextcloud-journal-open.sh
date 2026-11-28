#!/usr/bin/env bash
set -euo pipefail
umask 077

base=$(cd "$(dirname "$0")" && pwd)
fixture=${BUSYMAX_JOURNAL_LIVE_FIXTURE:?}
ca=$(python3 - "$fixture" <<'PY'
import json
from pathlib import Path
import sys

fixture = Path(sys.argv[1])
if fixture.stat().st_mode & 0o077:
    raise SystemExit('Expected a private journal fixture.')
print(json.loads(fixture.read_text())['nextcloud']['caFile'])
PY
)
printf '%s\n' "$1" |
  docker run --rm -i --network host --shm-size 256m \
    -v "$fixture:/fixture/profile.json:ro" \
    -v "$ca:/fixture/ca.pem:ro" \
    -v "$base/nextcloud-journal.mjs:/qa/nextcloud-journal.mjs:ro" \
    --entrypoint /bin/sh busymax-caldav-browser-qa:1.61.1 -ec '
      export HOME=/tmp/journal-browser
      mkdir -p "$HOME/.pki/nssdb"
      certutil -N --empty-password -d "sql:$HOME/.pki/nssdb"
      certutil -A -d "sql:$HOME/.pki/nssdb" -n journal-qa -t C,, -i /fixture/ca.pem
      exec node /qa/nextcloud-journal.mjs
    '
