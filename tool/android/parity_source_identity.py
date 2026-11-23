#!/usr/bin/env python3
"""Read-only identity of the checkout used by the parity fixture."""
import hashlib
import json
from pathlib import Path
import subprocess


def parity_source_identity(root):
    root = Path(root)
    def git(*args):
        return subprocess.check_output(['git', '-C', str(root), *args])
    paths = set(git('ls-files', '-z').split(b'\0'))
    paths.update(git('ls-files', '--others', '--exclude-standard', '-z').split(b'\0'))
    digest = hashlib.sha256()
    count = 0
    for raw in sorted(path for path in paths if path):
        path = root / raw.decode()
        if not path.is_file():
            digest.update(raw + b'\0deleted\0')
            continue
        digest.update(raw + b'\0' + hashlib.sha256(path.read_bytes()).digest())
        count += 1
    return {
        'base_revision': git('rev-parse', 'HEAD').decode().strip(),
        'source_sha256': digest.hexdigest(),
        'file_count': count,
        'dirty': bool(git('status', '--porcelain')),
    }


if __name__ == '__main__':
    print(json.dumps(parity_source_identity(Path(__file__).resolve().parents[2])))
