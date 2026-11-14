#!/bin/sh
set -eu
cd "$(dirname "$0")"
umask 077
mkdir -p .runtime
if [ -f .runtime/server.pem ]; then exit 0; fi
openssl req -x509 -newkey rsa:2048 -nodes -days 7 -subj '/CN=BusyMax disposable QA CA' \
  -addext 'basicConstraints=critical,CA:TRUE' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign' \
  -addext 'subjectKeyIdentifier=hash' \
  -keyout .runtime/ca.key -out .runtime/ca.pem 2>/dev/null
openssl req -newkey rsa:2048 -nodes -subj '/CN=localhost' \
  -keyout .runtime/server.key -out .runtime/server.csr 2>/dev/null
printf 'basicConstraints=critical,CA:FALSE\nsubjectAltName=DNS:localhost,IP:127.0.0.1\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nauthorityKeyIdentifier=keyid,issuer\n' > .runtime/server.ext
openssl x509 -req -days 7 -in .runtime/server.csr -CA .runtime/ca.pem \
  -CAkey .runtime/ca.key -CAcreateserial -extfile .runtime/server.ext \
  -out .runtime/server.pem 2>/dev/null
openssl req -x509 -newkey rsa:2048 -nodes -days 7 -subj '/CN=untrusted.invalid' \
  -keyout .runtime/untrusted.key -out .runtime/untrusted.pem 2>/dev/null
