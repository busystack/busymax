#!/usr/bin/env python3
"""Encode disposable fixture material for the isolated Android native test."""
import base64
import json
import pathlib

runtime = pathlib.Path(__file__).resolve().parent / '.runtime'
material = {'ca': (runtime / 'ca.pem').read_text(),
            'credentials': json.loads((runtime / 'credentials.json').read_text()),
            'busystackCredentials': json.loads((runtime / 'busystack-credentials.json').read_text())}
target = runtime / 'android-defines.json'
target.write_text(json.dumps({'BUSYMAX_CALDAV_NATIVE_FIXTURE':
                             base64.b64encode(json.dumps(material).encode()).decode()}))
target.chmod(0o600)
print('Disposable Android fixture defines prepared (not printed).')
