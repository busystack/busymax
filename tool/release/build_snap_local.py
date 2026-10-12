#!/usr/bin/env python3
"""Build an exact committed release in new sibling checkouts; never publish."""
from __future__ import annotations

import argparse
import base64
import hashlib
import importlib.util
import json
import os
import platform
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

PRIVACY = 'https://busystack.org/privacy-busymax'
SNAPCRAFT_VERSION = '9.1.4'
PUBLIC_KEYS = {'MICROSOFT_OAUTH_CLIENT_ID', 'MICROSOFT_OAUTH_AUTHORITY_TENANT',
               'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID'}
SYNTHETIC = {'managed.apps.googleusercontent.com','later.apps.googleusercontent.com','fixture.apps.googleusercontent.com','original.apps.googleusercontent.com','owned.apps.googleusercontent.com','synthetic-public-secret','synthetic-managed-project','11111111-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333','55555555-5555-5555-5555-555555555555',
             'busymax-ci-managed.apps.googleusercontent.com',
             'synthetic-ci-public-secret', 'busymax-ci-managed',
             '44444444-4444-4444-4444-444444444444',
             'busymax-ci-original.apps.googleusercontent.com',
             '22222222-2222-2222-2222-222222222222'}


class ReleaseError(Exception):
    """Messages are fixed descriptions and never credential values."""


def require(condition, message):
    if not condition:
        raise ReleaseError(message)


def read_object(path):
    try:
        require(path.is_file() and path.stat().st_size <= 65536,
                'Configuration must be a regular JSON file smaller than 64 KiB.')
        value = json.loads(path.read_text(encoding='utf-8'))
        require(isinstance(value, dict), 'Configuration must contain a JSON object.')
        return value
    except (OSError, ValueError):
        raise ReleaseError('Cannot read a valid JSON configuration.') from None


def google_configuration(selection, source):
    selection = selection.resolve()
    if selection.is_dir():
        candidates = sorted(selection.glob('*.json'))
        require(len(candidates) == 1,
                'Select one explicit Google Desktop JSON; directory selection is ambiguous or empty.')
        selection = candidates[0].resolve()
    require(not selection.is_relative_to(source.resolve()),
            'Keep the downloaded Google JSON outside the source repository.')
    value = read_object(selection)
    require(isinstance(value.get('installed'), dict) and
            'web' not in value and 'type' not in value,
            'Google configuration must be an installed Desktop OAuth client.')
    installed = value['installed']
    fields = {key: installed.get(key) for key in ('client_id', 'client_secret', 'project_id')}
    require(all(isinstance(v, str) and v.strip() for v in fields.values()),
            'Google Desktop JSON requires client ID, client secret and project metadata.')
    require(re.fullmatch(r'[A-Za-z0-9_-]+\.apps\.googleusercontent\.com', fields['client_id']) and
            re.fullmatch(r'[a-z][a-z0-9-]{4,62}[a-z0-9]', fields['project_id']) and
            len(fields['client_secret']) <= 4096,
            'Google Desktop configuration is invalid.')
    require(not any(v.strip() in SYNTHETIC for v in fields.values()),
            'Synthetic CI configuration cannot produce a production release.')
    return {'BUSYMAX_GOOGLE_OAUTH_CLIENT_ID': fields['client_id'],
            'BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET': fields['client_secret'],
            'BUSYMAX_GOOGLE_OAUTH_PROJECT_ID': fields['project_id'],
            'BUSYMAX_PRIVACY_POLICY_URL': PRIVACY}


def public_configuration(path):
    if path is None:
        return {}
    values = read_object(path)
    require(set(values) <= PUBLIC_KEYS,
            'Local public configuration accepts only Microsoft public client/authority settings.')
    require(all(isinstance(v, str) and v.strip() for v in values.values()),
            'Supplied local public configuration is incomplete.')
    for key in ('MICROSOFT_OAUTH_CLIENT_ID', 'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID'):
        if key in values:
            require(re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', values[key]),
                    'Supplied Microsoft public client ID is invalid.')
    if 'MICROSOFT_OAUTH_AUTHORITY_TENANT' in values:
        tenant = values['MICROSOFT_OAUTH_AUTHORITY_TENANT']
        require(tenant in ('common', 'consumers', 'organizations') or
                re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', tenant),
                'Supplied Microsoft authority is invalid.')
    require(not any(v.strip() in SYNTHETIC for v in values.values()),
            'Synthetic CI configuration cannot produce a production release.')
    return values


def run(args, cwd, *, log=None, redactions=()):
    # Capture output before printing. Build tools may repeat dart-defines on failure.
    process = subprocess.run([str(a) for a in args], cwd=cwd, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = process.stdout
    for value in sorted(redactions, key=len, reverse=True):
        for encoded in (value, base64.b64encode(value.encode()).decode()):
            output = output.replace(encoded, '[redacted]')
    if log is not None:
        with log.open('a', encoding='utf-8') as stream:
            stream.write(output)
    require(process.returncode == 0, f'Release step failed: {Path(str(args[0])).name}. Review the redacted build log.')
    return output.strip()


def source_gate(source, revision, version):
    require(re.fullmatch(r'[0-9a-f]{40}', revision), 'Supply an exact 40-character source revision.')
    require(re.fullmatch(r'\d+\.\d+\.\d+', version), 'Supply an exact release version.')
    require(run(['git', 'rev-parse', 'HEAD'], source) == revision,
            'Source HEAD does not match the requested revision.')
    require(not run(['git', 'status', '--porcelain', '--untracked-files=all'], source),
            'Official releases require a clean, committed source checkout.')
    branch = run(['git', 'branch', '--show-current'], source)
    require(branch in ('main', f'release/v{version}'), 'Source is not the intended release branch or main.')
    run(['git', 'fetch', 'origin', 'main'], source)
    run(['git', 'merge-base', '--is-ancestor', 'origin/main', revision], source)
    spec = importlib.util.spec_from_file_location('release_gate', source / 'tool/check_release_pull_request.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    try:
        code = module.validate_versions(lambda p: (source / p).read_text(), version)
    except (ValueError, ET.ParseError, OSError):
        raise ReleaseError('Release metadata does not match the requested version.') from None
    require(code >= 6 if version == '0.3.1' else code > 0, 'Android version code is too old.')
    recipe = (source / 'snap/snapcraft.yaml').read_text()
    for field, value in {'name': 'busymax', 'base': 'core24', 'grade': 'devel', 'confinement': 'strict'}.items():
        require(re.search(rf'^{field}: {value}$', recipe, re.M), 'Canonical Snap metadata changed unexpectedly.')
    # No credential download or generated build configuration can enter Git archives.
    for path in run(['git', 'ls-files'], source).splitlines():
        require(not re.search(r'(^|/)(client_secret.*\.json|release\.local\.json|busymax-dart-defines\.json)$', path),
                'A local credential/configuration file is tracked by Git.')
    return code


def tool_gate(source, flutter):
    flutter = flutter.resolve()
    dart = flutter.parent / 'cache/dart-sdk/bin/dart'
    require(flutter.is_file() and dart.is_file(), 'Flutter and its bundled Dart executable are required.')
    run([dart, source / 'tool/verify_flutter_sdk.dart', '--flutter', flutter, '--dart', dart,
         '--expected-flutter', '3.47.5', '--expected-dart', '3.13.4'], source)
    require(run(['snapcraft', 'version'], source) == f'snapcraft {SNAPCRAFT_VERSION}',
            'Snapcraft version does not match the reviewed release toolchain.')
    for tool in ('git', 'cmake', 'g++', 'pkg-config', 'xvfb-run', 'unsquashfs', 'lxc'):
        require(shutil.which(tool) is not None, 'A required native/release tool is missing.')
    return dart


def workspace_gate(workspace, source):
    require(not workspace.exists() and not workspace.is_symlink(),
            'Release workspace already exists. Choose a new workspace; existing contents are never removed.')
    require(not source.resolve().is_relative_to(workspace.resolve()), 'Workspace cannot contain the source checkout.')
    workspace.mkdir(mode=0o700, parents=True, exist_ok=False)
    (workspace / '.busymax-release-workspace').write_text('schema=1\n')
    os.chmod(workspace / '.busymax-release-workspace', 0o600)


def bundle_gate(bundle, configuration, version=None):
    required = ['busymax', 'lib/libapp.so', 'lib/libflutter_linux_gtk.so',
                'data/icudtl.dat', 'data/flutter_assets/docs/google_setup.md',
                'data/flutter_assets/docs/microsoft_setup.md',
                'data/flutter_assets/assets/branding/busymax-logo.svg']
    require(all((bundle / p).is_file() for p in required), 'Release bundle or a required asset is missing.')
    require(os.access(bundle / 'busymax', os.X_OK), 'Release launcher is not executable.')
    if version is not None:
        metadata = read_object(bundle / 'data/flutter_assets/version.json')
        require(metadata.get('version') == version and metadata.get('app_name') == 'busymax',
                'Compiled Flutter bundle has a stale or unintended application version.')
    binary = (bundle / 'lib/libapp.so').read_bytes()
    for key, value in configuration.items():
        require(value.encode() in binary or value.encode('utf-16le') in binary,
                'The intended OAuth/application metadata is absent from the compiled application.')
    require(not list(bundle.rglob('client_secret*.json')) and
            not list(bundle.rglob('busymax-oauth*.json')), 'Downloaded/generated credential files reached the bundle.')


def package_gate(artifact, output, version, configuration, source):
    require(artifact.is_file(), 'Snapcraft did not produce the final Snap.')
    require(list(output.glob('*.snap')) == [artifact], 'Unexpected package artifacts were produced.')
    unpacked = output / 'inspection'
    run(['unsquashfs', '-no-progress', '-d', unpacked, artifact], source)
    recipe = (unpacked / 'meta/snap.yaml').read_text()
    for field, value in {'name': 'busymax', 'version': version, 'base': 'core24',
                         'grade': 'devel', 'confinement': 'strict'}.items():
        require(re.search(rf'^{field}: [\"\']?{re.escape(value)}[\"\']?$', recipe, re.M),
                'Packaged Snap metadata is inconsistent.')
    require(re.search(r'^    command: busymax$', recipe, re.M), 'Packaged launcher is inconsistent.')
    for asset in ['share/applications/io.busystack.busymax.desktop',
                  'share/metainfo/io.busystack.busymax.metainfo.xml',
                  'share/icons/hicolor/scalable/apps/io.busystack.busymax.svg']:
        require((unpacked / asset).is_file(), 'A required packaged launcher or asset is missing.')
    latest = ET.parse(unpacked / 'share/metainfo/io.busystack.busymax.metainfo.xml').find('releases/release')
    require(latest is not None and latest.get('version') == version, 'Packaged AppStream version is inconsistent.')
    require('autostart: io.busystack.busymax-autostart.desktop' in recipe, 'Packaged autostart configuration is missing.')
    launchers = list((unpacked / 'meta/gui').glob('*.desktop'))
    require([p.name for p in launchers] == ['busymax.desktop'], 'Packaged desktop launchers are inconsistent.')
    bundle_gate(unpacked, configuration, version)
    require(not (unpacked / 'lib/libdartjni.so').exists(), 'Unused Linux JNI bridge was packaged.')
    return unpacked


def build(options):
    require(platform.system() == 'Linux' and platform.machine() in ('x86_64', 'amd64'),
            'Official local Snap builds require Linux amd64.')
    source = options.source.resolve()
    workspace = options.workspace.absolute()
    configuration = google_configuration(options.google_oauth, source)
    configuration.update(public_configuration(options.local_config))
    source_gate(source, options.revision, options.version)
    dart = tool_gate(source, options.flutter)
    # Scan tracked files for the actual downloaded secret, without printing it.
    secret = configuration['BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET'].encode()
    for name in run(['git', 'ls-files'], source).splitlines():
        require(secret not in (source / name).read_bytes(), 'Downloaded client secret appears in a tracked source file.')
    workspace_gate(workspace, source)
    root = workspace / 'busymax'
    log = workspace / 'build.log'
    redactions = tuple(configuration.values()) + tuple(f'{key}={value}' for key, value in configuration.items())
    def step(arguments, label):
        print(label, flush=True)
        return run(arguments, root, log=log, redactions=redactions)
    run(['git', 'clone', '--no-hardlinks', '--no-checkout', source, root], workspace, log=log)
    run(['git', 'checkout', '--detach', options.revision], root, log=log)
    require(not (root / 'build').exists(), 'A stale Flutter bundle reached the isolated source checkout.')
    step(['python3', 'tool/checkout_shared_dependencies.py'], 'Materializing exact pinned sibling dependencies')
    step([options.flutter.resolve(), 'pub', 'get', '--enforce-lockfile'], 'Resolving locked Flutter dependencies')
    step([options.flutter.resolve(), 'gen-l10n'], 'Generating localization')
    step([dart, 'run', 'build_runner', 'build', '--delete-conflicting-outputs', '--force-jit'], 'Generating Drift sources')
    step(['git', 'diff', '--exit-code'], 'Verifying generated-source and lockfile consistency')
    step([dart, 'format', '--output=none', '--set-exit-if-changed', '.'], 'Checking source formatting')
    step([options.flutter.resolve(), 'analyze', '--no-pub'], 'Analyzing source')
    step([dart, 'run', 'tool/check_platform_boundaries.dart'], 'Checking platform boundaries')
    step([options.flutter.resolve(), 'test', '--no-pub'], 'Running Flutter regression tests')
    step(['python3', '-m', 'unittest', 'discover', '-s', 'test/tool', '-p', '*_test.py'], 'Running tool regression tests')
    step(['bash', 'tool/release/check_linux_native.sh'], 'Running native Linux checks')
    step(['env', f'XDG_CONFIG_HOME={root / "build/linux/native-tests/gtk-config"}', 'xvfb-run', '-a',
          options.flutter.resolve(), 'test', '--no-pub', 'integration_test/gtk_header_icons_integration_test.dart', '-d', 'linux'],
         'Verifying Flutter native GTK header integration')
    step(['cmake', '-S', 'native/registration_reader', '-B', 'build/linux/registration-reader-tests'], 'Configuring native registration checks')
    step(['cmake', '--build', 'build/linux/registration-reader-tests', '--target', 'busymax_registration_reader_tests'], 'Building native registration checks')
    step(['ctest', '--test-dir', 'build/linux/registration-reader-tests', '--output-on-failure'], 'Testing native registration handling')
    # The temporary secret file is outside the Snapcraft source, always mode 0600.
    with tempfile.TemporaryDirectory(prefix='.oauth-', dir=workspace) as temporary:
        defines = Path(temporary) / 'busymax-oauth.json'
        with defines.open('x', encoding='utf-8') as stream:
            os.chmod(defines, 0o600)
            json.dump(configuration, stream)
        step([dart, 'run', 'tool/check_desktop_oauth_config.dart', '--config', defines], 'Validating production configuration')
        require(not (root / 'build/linux/x64/release/bundle').exists(), 'Unexpected stale release bundle exists before compilation.')
        step([options.flutter.resolve(), 'build', 'linux', '--no-pub', '--release', '-t', 'lib/main_linux.dart',
              f'--dart-define-from-file={defines}'], 'Compiling configured Linux application')
        bundle_gate(root / 'build/linux/x64/release/bundle', configuration, options.version)
        step(['git', 'diff', '--exit-code'], 'Verifying source and dependency locks after compilation')
    output = workspace / 'artifacts'
    output.mkdir(mode=0o700)
    artifact = output / f'busymax_{options.version}_amd64.snap'
    # Snapcraft's LXD provider requires output paths inside the project tree.
    # Move only the exact resulting package to the external artifact directory.
    pack_output = root / 'build/snap-output'
    pack_output.mkdir(mode=0o700)
    step(['snapcraft', 'pack', '--use-lxd', '--output', 'build/snap-output'],
         'Packaging the canonical Snap in isolated Ubuntu 24.04 LXD')
    packed = pack_output / artifact.name
    require(packed.is_file(), 'Snapcraft did not produce the final Snap.')
    require(list(pack_output.iterdir()) == [packed], 'Unexpected package artifacts were produced.')
    shutil.move(packed, artifact)
    package_gate(artifact, output, options.version, configuration, root)
    step(['bash', 'tool/release/verify_snap_runtime.sh', artifact, output / 'runtime.json'], 'Verifying a fresh isolated strict Snap installation')
    runtime = read_object(output / 'runtime.json')
    require(runtime.get('startup_x11') is True and runtime.get('startup_wayland') is True and
            runtime.get('restart') is True and runtime.get('confined_network') is True and
            runtime.get('snap_sha256') == hashlib.sha256(artifact.read_bytes()).hexdigest() and
            runtime.get('elf_dependencies') is True,
            'Fresh installation runtime checks did not pass.')
    digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
    (output / f'{artifact.name}.sha256').write_text(f'{digest}  {artifact.name}\n')
    manifest = {'schema': 1, 'status': 'candidate', 'release_ready': False,
                'version': options.version, 'revision': options.revision,
                'sha256': digest, 'artifact': str(artifact), 'flutter': '3.47.5', 'dart': '3.13.4',
                'snapcraft': SNAPCRAFT_VERSION, 'base': 'core24', 'grade': 'devel', 'confinement': 'strict',
                'dependencies': json.loads((root / 'tool/shared_dependencies.json').read_text()),
                'google_registration': 'busymaxManaged',
                'google_client_id_sha256': hashlib.sha256(configuration['BUSYMAX_GOOGLE_OAUTH_CLIENT_ID'].encode()).hexdigest(),
                'google_project_id': configuration['BUSYMAX_GOOGLE_OAUTH_PROJECT_ID'], 'managed_microsoft': 'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID' in configuration,
                'runtime': runtime, 'remaining_acceptance': [
                    'Google Console APIs, audience, publishing, branding and verification review',
                    'Real Google Calendar/Tasks/optional read-only contacts authorization, same-account recovery and restart',
                    'Provider upgrade/session recovery and Microsoft/Nextcloud/iCloud round trips',
                    'Desktop tray, file pickers, browser callback, notifications and secret-storage interaction review']}
    # Never emit a success manifest before every automated step passes.
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Candidate built; remaining acceptance is recorded in {output / "manifest.json"}.', flush=True)
    print(artifact)
    return artifact


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--revision', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--workspace', type=Path, required=True)
    parser.add_argument('--google-oauth', type=Path, required=True, help='External Desktop JSON file or a directory containing exactly one JSON')
    parser.add_argument('--local-config', type=Path, help='Ignored local Microsoft public settings JSON')
    parser.add_argument('--flutter', type=Path, default=Path(shutil.which('flutter') or '/missing/flutter'))
    try:
        build(parser.parse_args())
    except (ReleaseError, OSError) as error:
        # OS failures can include filenames; no configuration contents are emitted.
        print(str(error) if isinstance(error, ReleaseError) else 'A required release file/tool could not be accessed.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
