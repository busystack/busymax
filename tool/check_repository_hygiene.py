#!/usr/bin/env python3
"""Reject disposable artifacts and workstation paths in all tracked text.

Uses Git's index inventory, so ignored local QA files do not cause failures.
General secret detection is owned by upstream Gitleaks.
"""
from pathlib import Path
import re
import subprocess
import sys

ARTIFACT = re.compile(
    r'(^|/)(?:qa-results|test-results|diagnostics-captures|vm-backups|'
    r'__pycache__|\.dart_tool|build|dist|coverage)(/|$)|'
    r'(^|/)(?:\.env(?:\.(?!example$)[^/]+)?|credentials\.json)$|'
    r'\.(?:log|db|sqlite|sqlite3|apk|aab|exe|msix|snap|vdi|vmdk|qcow2|'
    r'keystore|jks|pfx|p12|key|pem|crt|cer)$',
    re.IGNORECASE,
)
# A path boundary avoids matching DAV URLs such as https://example.test/home/.
# Conventional synthetic usernames and CI's runner home remain portable.
WORKSTATION = re.compile(
    r'(?<![\w/:])/home/'
    r'(?!(?:example|fixture|test|user|runner|demo)(?=/|[\s\x22\x27]|$))'
    r'[\w.-]+(?:/|(?=[\s\x22\x27]|$))'
    r'|/mnt/(?:Media|media)/'
    r'|[A-Za-z]:[/\\]+Users[/\\]+'
    r'(?!(?:example|fixture|user|Public)(?=[/\\]|[\s\x22\x27]|$))'
    r'[^/\\\s\x22\x27]+',
    re.IGNORECASE,
)
# Exact synthetic resources, not directory exemptions. These tests exercise a
# Unicode Windows filename and DAV hrefs that happen to resemble home paths.
SYNTHETIC_PATHS = {
    'test/platform/common/desktop_activation_test.dart': ('C:' + r'\Users\Renée\Calendar\予定.ics',),
    'test/dav/mutation/dav_collection_creation_identity_test.dart': ('/home/' + 'existing/',),
    'test/dav/discovery/caldav_discovery_test.dart': ('/home/' + 'team%2Fwork/',),
}
PRIVATE_KEY = re.compile(r'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----')


def text_content(data):
    """Only inspect UTF-8 text; do not decode NUL-containing binary resources."""
    if b'\0' in data:
        return ''
    try:
        return data.decode('utf-8-sig')
    except UnicodeError:
        return ''


def violations(name, content):
    result = []
    public_fixture = (
        name.startswith('test/fixtures/')
        and Path(name).suffix.lower() in ('.pem', '.crt', '.cer')
        and '-----BEGIN CERTIFICATE-----' in content
        and 'PRIVATE KEY' not in content
    )
    if ARTIFACT.search(name) and not public_fixture:
        result.append(f'{name}: disposable or private artifact')
    for n, line in enumerate(content.splitlines(), 1):
        if PRIVATE_KEY.search(line):
            result.append(f'{name}:{n}: private key material')
        for synthetic in SYNTHETIC_PATHS.get(name, ()):
            line = line.replace(synthetic, '')
        if WORKSTATION.search(line):
            result.append(f'{name}:{n}: workstation-specific path')
    return result


def main():
    paths = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
    errors = []
    for name in filter(None, paths):
        path = Path(name)
        if not path.exists():  # A tracked deletion awaiting staging.
            continue
        errors.extend(violations(name, text_content(path.read_bytes())))
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    print('Tracked repository hygiene passed.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
