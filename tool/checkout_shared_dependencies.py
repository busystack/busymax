#!/usr/bin/env python3
"""Materialize BusyMax's revision-pinned sibling package sources."""

import json
import pathlib
import subprocess


def run(*arguments: str, cwd: pathlib.Path | None = None) -> str:
    return subprocess.run(
        arguments,
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()


root = pathlib.Path(__file__).resolve().parents[1]
manifest = json.loads((root / "tool/shared_dependencies.json").read_text())
if manifest.get("schema") != 1 or manifest.get("layout") != "sibling-working-trees":
    raise SystemExit("Unsupported shared dependency manifest")
for dependency in manifest["dependencies"]:
    name = dependency["name"]
    destination = (root / dependency["path"]).resolve()
    if destination.name != name or destination.parent != root.parent:
        raise SystemExit(f"Unsafe sibling destination for {name}")
    if destination.exists():
        if not (destination / ".git").exists():
            raise SystemExit(f"Existing dependency is not a Git checkout: {destination}")
        if run("git", "remote", "get-url", "origin", cwd=destination) != dependency["repository"]:
            raise SystemExit(f"Unexpected origin for {name}")
        if run("git", "rev-parse", "HEAD", cwd=destination) != dependency["revision"]:
            raise SystemExit(f"Unexpected revision for {name}")
        if run("git", "status", "--porcelain", cwd=destination):
            raise SystemExit(f"Existing {name} checkout has local changes")
        continue
    destination.mkdir(mode=0o755)
    run("git", "init", "--quiet", cwd=destination)
    run("git", "remote", "add", "origin", dependency["repository"], cwd=destination)
    run("git", "fetch", "--depth=1", "origin", dependency["revision"], cwd=destination)
    run("git", "checkout", "--detach", "FETCH_HEAD", cwd=destination)
    if run("git", "rev-parse", "HEAD", cwd=destination) != dependency["revision"]:
        raise SystemExit(f"Failed to select pinned revision for {name}")
