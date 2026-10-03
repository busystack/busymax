#!/usr/bin/env python3
"""Archive tracked/unignored source without Git, local configuration or builds.

Uses only the existing Python standard library. The source manifest covers every
regular source file, including generated code, packaged help and test fixtures.
"""

import argparse
import gzip
import hashlib
import io
from pathlib import Path
import subprocess
import tarfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = args.output.resolve()
    listed = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=root,
    )
    paths = sorted({p.decode() for p in listed.split(b"\0") if p})
    excluded = {".git", ".agents", ".codex", ".aws", ".dart_tool", "build"}
    local_names = {
        "busymax.android.properties", "key.properties", "local.properties",
        "windows_store.local.json", "google-services.json",
    }
    entries = []
    manifest = []
    for relative in paths:
        path = root / relative
        if (Path(relative).parts[0] in excluded or path.name in local_names
                or path.suffix in {".jks", ".keystore", ".pfx", ".p12", ".pem", ".key"}
                or path == output or not path.exists()):
            continue
        if path.is_symlink() or not path.is_file():
            raise SystemExit(f"Review unsupported source entry: {relative}")
        data = path.read_bytes()
        manifest.append(f"{hashlib.sha256(data).hexdigest()}  {relative}\n")
        entries.append((relative, data, 0o755 if path.stat().st_mode & 0o111 else 0o644))
    manifest_data = "".join(manifest).encode()
    entries.append(("SOURCE_SHA256SUMS", manifest_data, 0o644))
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as zipped:
            with tarfile.open(fileobj=zipped, mode="w") as archive:
                for relative, data, mode in entries:
                    entry = tarfile.TarInfo("busymax/" + relative)
                    entry.size = len(data)
                    entry.mode = mode
                    entry.mtime = 0
                    archive.addfile(entry, io.BytesIO(data))
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(output.suffix + ".sha256").write_text(
        f"{digest}  {output.name}\n"
    )
    print(f"Archived {len(manifest)} source files: {output}")
    print(f"Source manifest SHA-256: {hashlib.sha256(manifest_data).hexdigest()}")
    print(f"Archive SHA-256: {digest}")


if __name__ == "__main__":
    main()
