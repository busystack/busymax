#!/usr/bin/env python3
"""Verify resolved, formerly forked dependencies against publisher file identities.

Read-only: does not repair the pub cache, edit upstream files, resolve packages,
or accept a version string as proof of unchanged source. The JSON manifest is
generated from checksum-verified publisher archives when an upgrade is reviewed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlparse
from urllib.request import url2pathname


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def package_root(configuration, value):
    uri = urlparse(value)
    if uri.scheme == 'file':
        if uri.netloc not in ('', 'localhost'):
            raise ValueError('Package root must be local')
        return Path(url2pathname(uri.path)).resolve()
    if uri.scheme or uri.netloc or uri.query or uri.fragment:
        raise ValueError('Unsupported resolved package root')
    return (configuration.parent / unquote(uri.path)).resolve()


def canonical_source_blobs(root, revision, paths, command, environment):
    """Apply only the pinned tree's Git attributes, without trusting local policy.

    A private Git directory excludes installed SDK config, info/attributes,
    global attributes and configured clean filters. The installed object store
    is read-only input; hash-object has no -w and never repairs source files.
    """
    objects = subprocess.check_output(
        [*command, 'rev-parse', '--path-format=absolute', '--git-path', 'objects'],
        env=environment, text=True, timeout=30,
    ).strip()
    clean = {**environment, 'GIT_CONFIG_GLOBAL': os.devnull,
             'GIT_CONFIG_NOSYSTEM': '1', 'GIT_ATTR_NOSYSTEM': '1'}
    with tempfile.TemporaryDirectory(prefix='busymax-sdk-attributes-') as directory:
        subprocess.run(
            ['git', 'init', '--bare', '--template=', '--object-format=sha1', '--quiet', directory],
            env=clean, check=True, timeout=30,
        )
        # C-quoted UTF-8 paths also handle spaces, control bytes and Windows
        # separators without treating SDK names as command-line options.
        quoted = b''.join(
            b'"' + b''.join(
                bytes([byte]) if 32 <= byte < 127 and byte not in (34, 92)
                else ('\\%03o' % byte).encode('ascii')
                for byte in path
            ) + b'"\n'
            for path in paths
        )
        result = subprocess.check_output(
            ['git', '--no-optional-locks', '-c', 'core.fsmonitor=false',
             '-c', 'core.hooksPath=' + os.devnull, '-c', 'core.attributesFile=' + os.devnull,
             '-c', 'core.autocrlf=false', '--git-dir=' + directory,
             '--work-tree=' + str(root), 'hash-object', '--stdin-paths'],
            input=quoted, cwd=root, timeout=60,
            env={**clean, 'GIT_OBJECT_DIRECTORY': objects, 'GIT_ATTR_SOURCE': revision},
        ).splitlines()
    if len(result) != len(paths) or any(not re.fullmatch(b'[0-9a-f]{40}', item) for item in result):
        raise ValueError('Invalid canonical SDK source identity response')
    return result


def verify_sdk(root, expected, host=None):
    root = Path(root).resolve()
    host = host or sys.platform
    if host not in expected['artifacts']:
        raise ValueError('No reviewed official SDK artifact catalog for this host')
    version = json.loads((root / 'bin/cache/flutter.version.json').read_text())
    if any(version.get(key) != value for key, value in expected['identity'].items()):
        raise ValueError('Flutter/Dart identity differs from the approved official toolchain')
    environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
    command = ['git', '--no-optional-locks', '-c', 'core.fsmonitor=false',
               '-c', 'core.hooksPath=' + os.devnull, '-C', str(root)]
    head = subprocess.check_output([*command, 'rev-parse', 'HEAD'], env=environment, text=True, timeout=30).strip()
    if head != expected['identity']['frameworkRevision']:
        raise ValueError('Flutter framework is not the approved upstream revision')
    entries = subprocess.check_output([*command, 'ls-tree', '-rz', '--full-tree', 'HEAD'], env=environment, timeout=30)
    mismatched = []
    for entry in entries.split(b'\0'):
        if not entry: continue
        metadata, relative = entry.split(b'\t', 1)
        mode, kind, object_id = metadata.split()
        path = root / os.fsdecode(relative)
        if kind != b'blob' or mode not in (b'100644', b'100755', b'120000'):
            raise ValueError('Unsupported official SDK source entry: ' + os.fsdecode(relative))
        if mode == b'120000':
            if not path.is_symlink():
                kind = 'file' if path.is_file() else 'directory' if path.is_dir() else 'missing'
                actual = path.read_bytes() if kind == 'file' else None
                digest = (hashlib.sha1(b'blob ' + str(len(actual)).encode() + b'\0' + actual).hexdigest()
                          if actual is not None else 'unavailable')
                symlinks = subprocess.run(
                    [*command, 'config', '--local', '--type=bool', '--get', 'core.symlinks'],
                    env=environment, capture_output=True, text=True, timeout=30,
                )
                setting = symlinks.stdout.strip() if symlinks.returncode == 0 else 'unset'
                raise ValueError('Flutter SDK source link was replaced: ' + os.fsdecode(relative) +
                                 ' (entry type ' + kind + '; expected blob ' + object_id.decode() +
                                 ', got ' + digest + '; core.symlinks=' + setting + ')')
            content = os.fsencode(os.readlink(path))
        else:
            if path.is_symlink() or not path.is_file(): raise ValueError('Flutter SDK source is missing or substituted: ' + os.fsdecode(relative))
            if os.name != 'nt' and bool(path.stat().st_mode & 0o111) != (mode == b'100755'):
                raise ValueError('Flutter SDK source mode was modified: ' + os.fsdecode(relative))
            content = path.read_bytes()
        digest = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()
        if digest.encode() != object_id:
            if mode != b'120000' and b'\0' not in content:
                mismatched.append((relative, object_id))
                continue
            raise ValueError('Flutter SDK contains source modifications: ' + os.fsdecode(relative) +
                             ' (Git blob identity mismatch; expected ' + object_id.decode() + ', got ' + digest + ')')
    if mismatched:
        # The official Windows archive also checks out Markdown with CRLF.
        # Compare its canonical blob using upstream policy, not SDK-local rules.
        canonical = canonical_source_blobs(root, head, [path for path, _ in mismatched], command, environment)
        for (relative, object_id), digest in zip(mismatched, canonical, strict=True):
            if digest != object_id:
                raise ValueError('Flutter SDK contains source modifications: ' + os.fsdecode(relative) +
                                 ' (Git blob identity mismatch after upstream text normalization; expected ' +
                                 object_id.decode() + ', got ' + digest.decode() + ')')
    verified = 0
    for artifact in expected['artifacts'][host]:
        directory = PurePosixPath(artifact['directory'])
        if directory.is_absolute() or '..' in directory.parts:
            raise ValueError('Invalid SDK artifact directory')
        parent = root.joinpath(*directory.parts)
        # A mode not yet precached has no executable input to attest. Recheck
        # after Flutter has acquired/build-used it; existing inputs never skip.
        if not parent.exists():
            if artifact.get('required'): raise ValueError('Official Dart SDK is missing')
            continue
        for relative, digest in artifact['files'].items():
            path = PurePosixPath(relative)
            if path.is_absolute() or '..' in path.parts:
                raise ValueError('Invalid SDK artifact path')
            actual = parent.joinpath(*path.parts)
            if not actual.exists() and not actual.is_symlink() and not artifact.get('required'):
                continue
            approved = digest if isinstance(digest, list) else [digest]
            if not actual.is_file() or actual.is_symlink() or sha(actual) not in approved:
                raise ValueError('Official SDK compiler/runtime missing or modified: ' + relative)
            verified += 1
    return verified


def verify(configuration, manifest):
    configuration = Path(configuration).resolve()
    packages = json.loads(configuration.read_text())['packages']
    expected = json.loads(Path(manifest).read_text())
    if expected.get('schema') != 1:
        raise ValueError('Unsupported upstream package identity manifest')
    resolved = {}
    for package in packages:
        name = package['name']
        if name in resolved:
            raise ValueError('Duplicate resolved package identity')
        resolved[name] = package_root(configuration, package['rootUri'])
    checked = []
    for record in expected['packages']:
        name, version = record['name'], record['version']
        if not re.fullmatch(r'[a-z][a-z0-9_]*', name) or not re.fullmatch(r'[0-9a-f]{64}', record['archive_sha256']):
            raise ValueError('Invalid pinned publisher identity')
        if record['archive_url'] != f'https://pub.dev/api/archives/{name}-{version}.tar.gz':
            raise ValueError('Publisher package URL differs from its reviewed identity')
        if name not in resolved:
            if record.get('optional'):
                continue
            raise ValueError(f'Required upstream package is unresolved: {name}')
        root = resolved[name]
        entries = record['files']
        for relative, digest in entries.items():
            path = PurePosixPath(relative)
            if path.is_absolute() or '..' in path.parts or not relative or '\\' in relative:
                raise ValueError('Publisher path escapes its package')
            actual = root.joinpath(*path.parts)
            if actual.is_symlink() or not actual.is_file() or not actual.resolve().is_relative_to(root):
                raise ValueError(f'Upstream package file missing or substituted: {name}/{relative}')
            if sha(actual) != digest:
                raise ValueError(f'Upstream package source modified: {name}/{relative}')
        # Extra source can alter compilation without changing an archived file.
        # Ignore only root-level tool output, never a similarly named lib path.
        ignored = {'.dart_tool', '.git', 'build', '__pycache__'}
        for parent, directories, files in os.walk(root, followlinks=False):
            parent = Path(parent)
            if parent == root:
                directories[:] = [item for item in directories if item not in ignored]
            for item in [*directories, *files]:
                path = parent / item
                if path.is_symlink():
                    raise ValueError(f'Unreviewed package symlink: {name}/{path.relative_to(root)}')
            for item in files:
                relative = (parent / item).relative_to(root).as_posix()
                if relative not in entries:
                    raise ValueError(f'Unreviewed package source added: {name}/{relative}')
        checked.append({'name': name, 'version': version, 'archive_sha256': record['archive_sha256']})
    return checked


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--configuration', type=Path, default=root / '.dart_tool/package_config.json')
    parser.add_argument('--manifest', type=Path, default=root / 'tool/upstream_packages.json')
    parser.add_argument('--sdk', type=Path)
    parser.add_argument('--sdk-only', action='store_true')
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    sdk = args.sdk
    if args.sdk_only and sdk is None:
        parser.error('--sdk-only requires an explicit --sdk')
    if sdk is None and 'flutter' in manifest:
        configuration = args.configuration.resolve()
        flutter = next((p for p in json.loads(configuration.read_text())['packages'] if p['name'] == 'flutter'), None)
        if flutter is None: raise ValueError('Resolved Flutter SDK is unavailable')
        sdk = package_root(configuration, flutter['rootUri']).parent.parent
    sdk_files = verify_sdk(sdk, manifest['flutter']) if 'flutter' in manifest else None
    packages = [] if args.sdk_only else verify(args.configuration, args.manifest)
    print(json.dumps({'verifiedUpstreamPackages': packages, 'verifiedSdkFiles': sdk_files}))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as failure:
        raise SystemExit('Official dependency integrity check failed: ' + str(failure))
