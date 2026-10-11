#!/usr/bin/env python3
"""Check that release pull requests originate from their release branch."""

import os
import sys


def main() -> int:
    title = os.environ.get("RELEASE_PR_TITLE", "")
    if not title.casefold().startswith("release/v"):
        return 0

    source = os.environ.get("GITHUB_HEAD_REF", "")
    if source.casefold() != title.casefold():
        print(
            "::error::Release pull requests must originate from the matching "
            "release branch. Changing the PR title does not change its source.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
