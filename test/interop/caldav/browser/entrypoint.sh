#!/bin/bash
set -euo pipefail
# Trust is confined to this disposable browser container, never the host/device.
install -d -m 700 /root/.pki/nssdb
certutil -N --empty-password -d sql:/root/.pki/nssdb
certutil -A -d sql:/root/.pki/nssdb -n 'BusyMax disposable QA CA' -t 'C,,' -i /fixtures/.runtime/ca.pem
exec node /qa/busystack.mjs "$@"
