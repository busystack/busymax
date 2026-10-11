"""Release validation regressions using real Git refs and merge histories."""

import json
import os
import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "tool/check_release_pull_request.py"


class ReleasePullRequestTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="busymax-release-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.repo = self.root / "checkout"
        self.repo.mkdir()
        self.remote = self.root / "origin.git"
        self.run_git("init", "--bare", str(self.remote))
        self.run_git("init", "-b", "main")
        self.run_git("config", "user.name", "Release test")
        self.run_git("config", "user.email", "release-test@example.invalid")
        self.run_git("config", "commit.gpgsign", "false")
        self.run_git("remote", "add", "origin", str(self.remote))
        self.metadata("0.2.4", 4)
        self.commit("Initial main")
        self.run_git("push", "origin", "main")
        self.run_git("checkout", "-b", "release/v0.3.0")
        self.metadata("0.3.0", 5)
        self.commit("Release metadata")
        self.push_head()

    def run_git(self, *arguments, cwd=None):
        return subprocess.run(
            ["git", *arguments], cwd=cwd or self.repo, check=True,
            text=True, capture_output=True,
        ).stdout.strip()

    def write(self, path, content):
        destination = self.repo / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content)

    def metadata(self, version, code):
        self.write("pubspec.yaml", f"version: {version}\n")
        self.write("snap/snapcraft.yaml", f'version: "{version}"\n')
        self.write("linux/io.busystack.busymax.metainfo.xml", (
            f'<component><releases><release version="{version}" />'
            '<release version="0.2.3" /></releases></component>\n'
        ))
        self.write("windows/runner/Runner.rc", (
            f'#define VERSION_AS_NUMBER {version.replace(".", ",")},0\n'
            f'#define VERSION_AS_STRING "{version}"\n'
        ))
        self.write("android/app/build.gradle.kts", (
            f"versionCode = {code}\nversionName = flutter.versionName\n"
        ))

    def commit(self, message):
        self.run_git("add", ".")
        self.run_git("commit", "-m", message)

    def push_head(self):
        self.run_git("push", "origin", "HEAD:refs/pull/29/head")
        self.head = self.run_git("rev-parse", "HEAD")

    def advance_main(self):
        self.run_git("checkout", "main")
        self.write("main-change.txt", "Later main change\n")
        self.commit("Advance main")
        self.run_git("push", "origin", "main")
        self.run_git("checkout", "release/v0.3.0")

    def check(self, title="Release/v0.3.0", source="release/v0.3.0", cwd=None, head=None, base="main"):
        event = self.root / "event.json"
        event.write_text(json.dumps({
            "number": 29,
            "pull_request": {
                "head": {"ref": source, "sha": head or self.head},
                "base": {"ref": base},
            },
        }))
        environment = dict(os.environ, RELEASE_PR_TITLE=title, GITHUB_HEAD_REF=source,
                           GITHUB_EVENT_PATH=str(event))
        return subprocess.run([os.sys.executable, str(SCRIPT)], cwd=cwd or self.repo,
                              env=environment, text=True, capture_output=True)

    def assert_allowed(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout + result.stderr, "")

    def assert_rejected(self, result, message):
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(message, result.stderr)

    def test_valid_lowercase_release(self):
        self.assert_allowed(self.check())

    def test_valid_matching_uppercase_release(self):
        self.assert_allowed(self.check(source="Release/v0.3.0"))

    def test_outdated_release(self):
        self.advance_main()
        self.assert_rejected(self.check(), "incorporate current main")

    def test_normal_merge_synchronizes_release(self):
        self.advance_main()
        self.run_git("merge", "--no-ff", "main", "-m", "Merge main into release")
        self.push_head()
        self.assert_allowed(self.check())

    def test_synthetic_merge_does_not_prove_head_ancestry(self):
        self.advance_main()
        self.run_git("merge", "--no-ff", "main", "-m", "Synthetic Actions merge")
        self.assert_rejected(self.check(), "incorporate current main")

    def test_shallow_actions_checkout(self):
        checkout = self.root / "shallow"
        self.run_git("clone", "--depth=1", "--branch", "main", self.remote.as_uri(), str(checkout))
        self.assertEqual(self.run_git("rev-parse", "--is-shallow-repository", cwd=checkout), "true")
        self.assert_allowed(self.check(cwd=checkout))

    def test_metadata_is_read_from_actual_pr_head(self):
        self.metadata("0.2.4", 4)
        self.commit("Synthetic checkout has different metadata")
        self.assert_allowed(self.check())

    def test_mismatched_declared_versions(self):
        cases = {
            "pubspec.yaml": "version: 0.2.4\n",
            "snap/snapcraft.yaml": 'version: "0.2.4"\n',
            "linux/io.busystack.busymax.metainfo.xml": '<component><releases><release version="0.2.4" /></releases></component>',
            "windows/runner/Runner.rc": '#define VERSION_AS_NUMBER 0,3,0,0\n#define VERSION_AS_STRING "0.2.4"\n',
        }
        for path, content in cases.items():
            with self.subTest(path=path):
                self.metadata("0.3.0", 5)
                self.write(path, content)
                self.commit("Mismatched version")
                self.push_head()
                self.assert_rejected(self.check(), "release PR identifies 0.3.0")

    def test_mismatched_windows_numeric_version(self):
        self.write("windows/runner/Runner.rc", '#define VERSION_AS_NUMBER 0,2,4,0\n#define VERSION_AS_STRING "0.3.0"\n')
        self.commit("Mismatched Windows numeric version")
        self.push_head()
        self.assert_rejected(self.check(), "Windows resource version")

    def test_android_version_code_must_increase(self):
        self.metadata("0.3.0", 4)
        self.commit("Non-increasing Android code")
        self.push_head()
        self.assert_rejected(self.check(), "must exceed target main's 4")

    def test_android_version_name_uses_flutter(self):
        self.write("android/app/build.gradle.kts", 'versionCode = 5\nversionName = "0.2.4"\n')
        self.commit("Stale Android name")
        self.push_head()
        self.assert_rejected(self.check(), "Android versionName")

    def test_wrong_release_source(self):
        for source in ("fix/release-action-names", "hotfix/ci-oauth-configuration", "release/v0.2.4", ""):
            with self.subTest(source=source):
                self.assert_rejected(self.check(source=source), "matching release branch")

    def test_release_branch_cannot_bypass_checks_by_renaming_title(self):
        self.assert_rejected(self.check(title="A feature"), "matching release branch")

    def test_non_release_pr_and_push(self):
        self.assert_allowed(self.check(title="Feature/shared contacts package", source="feature/shared-contacts-package"))
        self.assert_allowed(self.check(title="", source=""))

    def test_concurrent_pr_head_change_is_rejected(self):
        self.assert_rejected(self.check(head="a" * 40), "PR head changed")

    def test_target_must_remain_main(self):
        self.assert_rejected(self.check(base="another-branch"), "main target")

    def test_release_requires_github_event(self):
        environment = dict(os.environ, RELEASE_PR_TITLE="Release/v0.3.0", GITHUB_HEAD_REF="release/v0.3.0")
        environment.pop("GITHUB_EVENT_PATH", None)
        result = subprocess.run([os.sys.executable, str(SCRIPT)], cwd=self.repo,
                                env=environment, text=True, capture_output=True)
        self.assert_rejected(result, "GITHUB_EVENT_PATH")


if __name__ == "__main__":
    unittest.main(verbosity=2)
