#!/usr/bin/env python3
"""Reject disposable artifacts and workstation paths in tracked product/docs.

Uses Git's index inventory, so ignored local QA files do not cause failures.
Secret detection is owned by upstream Gitleaks, not this targeted check.
"""
from pathlib import Path
import re
import subprocess
import sys

ARTIFACT = re.compile(
    r'(^|/)(?:qa-results|test-results|diagnostics-captures|vm-backups|'
    r'__pycache__|\.dart_tool|build|coverage)(/|$)|'
    r'\.(?:log|apk|aab|exe|msix|snap|vdi|vmdk|qcow2|pfx|p12|key|pem|crt|cer)$',
    re.IGNORECASE,
)
WORKSTATION = re.compile(
    r'/home/(?!example/|fixture/|test/|user/|runner/|demo/)[\w.-]+/'
    r'|/mnt/(?:Media|media)/'
    r'|[A-Za-z]:[/\\]Users[/\\](?!example[/\\]|fixture[/\\]|user[/\\]|Public[/\\])[\w.-]+[/\\]'
)


def violations(name, content):
    result = []
    if ARTIFACT.search(name):
        result.append(f'{name}: disposable or private artifact')
    # Tests may deliberately exercise arbitrary valid OS paths and private IPs.
    if name.startswith(('lib/', 'docs/')) or name in ('README.md', 'tool/README.md'):
        for n, line in enumerate(content.splitlines(), 1):
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
        try:
            content = path.read_text()
        except UnicodeError:
            content = ''
        errors.extend(violations(name, content))
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    print('Tracked repository hygiene passed.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
