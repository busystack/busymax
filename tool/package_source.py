#!/usr/bin/env python3
"""Create a deterministic sibling-layout BusyMax source archive."""

import gzip
import hashlib
import json
import os
import pathlib
import subprocess
import tarfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
EPOCH = int(os.environ.get("SOURCE_DATE_EPOCH", "1790899200"))


def tracked(root: pathlib.Path) -> list[pathlib.Path]:
    raw = subprocess.run(
        ("git", "ls-files", "-z"),
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    paths = []
    for encoded in raw.split(b"\0"):
        if not encoded:
            continue
        relative = pathlib.PurePosixPath(os.fsdecode(encoded))
        if relative.is_absolute() or ".." in relative.parts:
            raise SystemExit(f"Unsafe tracked path: {relative}")
        paths.append(root.joinpath(*relative.parts))
    return paths


def add_tree(archive: tarfile.TarFile, root: pathlib.Path, prefix: str) -> None:
    directory = tarfile.TarInfo(prefix)
    directory.type = tarfile.DIRTYPE
    directory.mode = 0o755
    directory.mtime = EPOCH
    archive.addfile(directory)
    for path in tracked(root):
        relative = path.relative_to(root)
        item = archive.gettarinfo(str(path), str(pathlib.PurePosixPath(prefix) / relative))
        item.uid = item.gid = 0
        item.uname = item.gname = ""
        item.mtime = EPOCH
        if item.isfile():
            item.mode = 0o755 if item.mode & 0o111 else 0o644
            with path.open("rb") as stream:
                archive.addfile(item, stream)
        else:
            archive.addfile(item)


manifest = json.loads((ROOT / "tool/shared_dependencies.json").read_text())
roots = [(ROOT, "busymax")]
for dependency in manifest["dependencies"]:
    source = (ROOT / dependency["path"]).resolve()
    if source.parent != ROOT.parent or source.name != dependency["name"]:
        raise SystemExit(f"Unsafe sibling source for {dependency['name']}")
    revision = subprocess.run(
        ("git", "rev-parse", "HEAD"),
        cwd=source,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    if revision != dependency["revision"]:
        raise SystemExit(f"Unexpected revision for {dependency['name']}")
    roots.append((source, dependency["name"]))

output = ROOT / "dist/source"
output.mkdir(parents=True, exist_ok=True)
destination = output / "busymax-0.2.4-source.tar.gz"
with destination.open("wb") as raw, gzip.GzipFile(
    filename="", mode="wb", fileobj=raw, mtime=EPOCH
) as zipped, tarfile.open(fileobj=zipped, mode="w") as archive:
    for source, prefix in roots:
        add_tree(archive, source, prefix)
digest = hashlib.sha256(destination.read_bytes()).hexdigest()
(output / "SHA256SUMS").write_text(f"{digest}  {destination.name}\n")
print(f"{digest}  {destination}")
