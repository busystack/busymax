#!/usr/bin/env python3
"""Run one journal scenario on an already authorized Windows OpenSSH host."""

import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.parse import urlsplit


REMOTE = r"""
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'A Windows runtime is required.' }
$config = [Console]::In.ReadToEnd() | ConvertFrom-Json
Set-Location -LiteralPath $config.checkout
if ((git rev-parse HEAD).Trim() -ne $config.source) {
    throw 'The remote checkout must match the requested source commit.'
}
if (git status --porcelain) { throw 'The remote source checkout must be clean.' }
$native = Join-Path $env:LOCALAPPDATA ('BusyMax-Journal-QA-' + [Guid]::NewGuid())
$security = New-Object Security.AccessControl.DirectorySecurity
$security.SetAccessRuleProtection($true, $false)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
$security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
))
[IO.Directory]::CreateDirectory($native, $security) | Out-Null
$status = 1
try {
    $ca = Join-Path $native 'fixture-ca.pem'
    $fixture = Join-Path $native 'fixture.json'
    $config.profile.caFile = $ca
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($ca, $config.ca, $utf8)
    $profiles = @{}
    $profiles[$config.provider] = $config.profile
    [IO.File]::WriteAllText($fixture, ($profiles | ConvertTo-Json -Depth 8 -Compress), $utf8)
    $env:BUSYMAX_JOURNAL_LIVE_FIXTURE = $fixture
    $test = "Windows journal collection and editor on $($config.provider)"
    flutter test -d windows integration_test/journal_windows_workflows_test.dart --reporter expanded --plain-name $test
    $status = $LASTEXITCODE
} finally {
    Remove-Item Env:BUSYMAX_JOURNAL_LIVE_FIXTURE -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $native -Recurse -Force
}
exit $status
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('provider', choices=('caldav', 'nextcloud'))
    parser.add_argument('private_fixture', type=Path)
    args = parser.parse_args()
    host = os.environ.get('BUSYMAX_WINDOWS_QA_SSH', '')
    checkout = os.environ.get('BUSYMAX_WINDOWS_QA_CHECKOUT', '')
    if not re.fullmatch(r'[A-Za-z0-9_@][A-Za-z0-9_.@-]*', host) or not checkout:
        parser.error('Set BUSYMAX_WINDOWS_QA_SSH and BUSYMAX_WINDOWS_QA_CHECKOUT for an authorized runner.')
    if args.private_fixture.stat().st_mode & 0o077:
        parser.error('The fixture contains app passwords and must be private.')
    profile = json.loads(args.private_fixture.read_text())[args.provider]
    authority = urlsplit(profile['authority'])
    if authority.scheme != 'https' or authority.hostname != 'localhost' or not authority.port:
        parser.error('An explicit fixture HTTPS localhost port is required for reverse forwarding.')
    repository = Path(__file__).resolve().parents[3]
    source = subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=repository, text=True,
    ).strip()
    input_data = json.dumps({
        'provider': args.provider,
        'profile': profile,
        'checkout': checkout,
        'source': source,
        'ca': Path(profile['caFile']).read_text(),
    }).encode('utf-8')
    command = base64.b64encode(REMOTE.encode('utf-16le')).decode('ascii')
    port = authority.port
    # SSH validates the runner's host key and forwards the fixture's original
    # port so the app continues to verify its existing TLS authority.
    return subprocess.run(
        ['ssh', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
         '-o', 'ExitOnForwardFailure=yes', '-R', f'127.0.0.1:{port}:127.0.0.1:{port}',
         host, 'powershell.exe', '-NoProfile', '-NonInteractive', '-EncodedCommand', command],
        input=input_data,
    ).returncode


if __name__ == '__main__':
    raise SystemExit(main())
