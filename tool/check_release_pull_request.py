#!/usr/bin/env python3
"""Validate release PR identity, head metadata, and current target ancestry.

Actions normally checks out refs/pull/<number>/merge. That synthetic merge
cannot establish that the actual release head incorporates main. Fetch both
real refs and read metadata from the fetched PR head, never the checkout.
"""

import json
import os
import pathlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


RELEASE = re.compile(r"release/v(\d+\.\d+\.\d+)", re.IGNORECASE)


def git(root: pathlib.Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments], cwd=root, text=True, capture_output=True, check=True
    )
    return result.stdout.strip()


def capture(source: str, pattern: str, label: str) -> str:
    match = re.search(pattern, source, re.MULTILINE)
    if not match:
        raise ValueError(f"Missing or invalid {label}")
    return match[1]


def validate_versions(read, version: str) -> int:
    versions = {
        "pubspec.yaml": capture(
            read("pubspec.yaml"), r"^version:\s*(\d+\.\d+\.\d+)\s*$", "application version"
        ),
        "snap/snapcraft.yaml": capture(
            read("snap/snapcraft.yaml"),
            r"^version:\s*[\"']?(\d+\.\d+\.\d+)[\"']?\s*$",
            "Snap version",
        ),
    }
    metainfo = ET.fromstring(read("linux/io.busystack.busymax.metainfo.xml"))
    release = metainfo.find("releases/release")
    versions["AppStream latest release"] = (
        release.get("version", "") if release is not None else ""
    )
    runner = read("windows/runner/Runner.rc")
    versions["Windows resource string"] = capture(
        runner, r'^#define VERSION_AS_STRING "([^"]+)"$', "Windows resource string"
    )
    numeric = capture(
        runner, r"^#define VERSION_AS_NUMBER (\d+,\d+,\d+,\d+)$", "Windows resource version"
    )
    if numeric != version.replace(".", ",") + ",0":
        raise ValueError(f"Windows resource version {numeric} does not match {version}")
    for label, declared in versions.items():
        if declared != version:
            raise ValueError(f"{label} declares {declared!r}; release PR identifies {version}")
    android = read("android/app/build.gradle.kts")
    if not re.search(r"^\s*versionName\s*=\s*flutter\.versionName\s*$", android, re.MULTILINE):
        raise ValueError("Android versionName must use the Flutter application version")
    return int(capture(android, r"^\s*versionCode\s*=\s*(\d+)\s*$", "Android versionCode"))


def main() -> int:
    title = os.environ.get("RELEASE_PR_TITLE", "")
    source = os.environ.get("GITHUB_HEAD_REF", "")
    if not any(value.casefold().startswith("release/v") for value in (title, source)):
        return 0

    match = RELEASE.fullmatch(title)
    if not match or not RELEASE.fullmatch(source) or source.casefold() != title.casefold():
        print(
            "::error::Release pull requests must originate from the matching "
            "release branch. Changing the PR title does not change its source.",
            file=sys.stderr,
        )
        return 1
    try:
        event = json.loads(pathlib.Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
        pr = event["pull_request"]
        number = int(event["number"])
        if number <= 0 or pr["head"]["ref"] != source or pr["base"]["ref"] != "main":
            raise ValueError("Release validation requires the actual PR head and main target")
        expected_head = pr["head"]["sha"]
        if not re.fullmatch(r"[0-9a-f]{40}", expected_head):
            raise ValueError("Invalid PR head SHA")
        root = pathlib.Path.cwd()
        head = f"refs/busymax-release-check/pr-{number}-head"
        target = f"refs/busymax-release-check/pr-{number}-main"
        fetch = ["fetch", "--no-tags"]
        if git(root, "rev-parse", "--is-shallow-repository") == "true":
            fetch.append("--unshallow")
        git(root, *fetch, "origin", f"+refs/pull/{number}/head:{head}", f"+refs/heads/main:{target}")
        if git(root, "rev-parse", head) != expected_head:
            raise ValueError("The PR head changed during validation; rerun checks for its current head")
        ancestor = subprocess.run(
            ["git", "merge-base", "--is-ancestor", target, head], cwd=root, capture_output=True
        )
        if ancestor.returncode == 1:
            raise ValueError("Release branch must incorporate current main with a normal merge before final review")
        if ancestor.returncode != 0:
            raise ValueError("Unable to verify release ancestry: " + ancestor.stderr.decode().strip())
        code = validate_versions(lambda path: git(root, "show", f"{head}:{path}"), match[1])
        previous = int(capture(
            git(root, "show", f"{target}:android/app/build.gradle.kts"),
            r"^\s*versionCode\s*=\s*(\d+)\s*$", "target Android versionCode"
        ))
        if code <= previous:
            raise ValueError(f"Android versionCode {code} must exceed target main's {previous}; also verify the distribution ledger")
    except (KeyError, OSError, ValueError, ET.ParseError, subprocess.CalledProcessError) as error:
        detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        print(f"::error::Release validation failed: {detail}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
