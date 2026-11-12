import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HEAD = "1" * 40
REPOSITORY = "Entwining/homebrew-tap"
MISMATCH = "GraphQL: Failed to add PR #1: expected head oid does not match the current head oid (enablePullRequestAutoMerge)"
QUEUE = ["gh", "pr", "merge", "1", "--repo", REPOSITORY, "--auto", "--match-head-commit", HEAD]
VIEW = ["gh", "pr", "view", "1", "--repo", REPOSITORY, "--json", "headRefOid", "--jq", ".headRefOid"]
QUEUED = "! Pull request Entwining/homebrew-tap#1 is already queued to merge"
ACCEPTED = [[0, ""], [0, "", HEAD]]

CLIENT = r'''
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
calls = pathlib.Path(os.environ["CALLS"])
with calls.open("a") as output:
    output.write(json.dumps([name, *sys.argv[1:]]) + "\n")
if name == "sleep":
    sys.exit(0)
responses = json.loads(pathlib.Path(os.environ["FIXTURE"]).read_text())
attempt = sum(json.loads(line)[0] == "gh" for line in calls.read_text().splitlines())
status, errors, *output = responses[attempt - 1]
if errors:
    print(errors, file=sys.stderr)
print(*output)
sys.exit(status)
'''


class QueuePublishTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="queue-publish-")
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.bin = self.path / "bin"
        self.bin.mkdir()
        for name in ("gh", "sleep"):
            client = self.bin / name
            client.write_text(f"#!{sys.executable}\n" + CLIENT)
            client.chmod(0o755)

    def run_case(self, responses):
        config = self.path / "fixture.json"
        config.write_text(json.dumps(responses))
        calls = self.path / "calls"
        calls.write_text("")
        env = {"PATH": f"{self.bin}:{os.environ['PATH']}", "HOME": str(self.path),
               "FIXTURE": str(config), "CALLS": str(calls), "GITHUB_REPOSITORY": REPOSITORY}
        result = subprocess.run(["bash", str(ROOT / ".github/scripts/queue-publish.sh"), "1", HEAD],
                                env=env, text=True, capture_output=True, timeout=10)
        calls = [json.loads(line) for line in calls.read_text().splitlines()]
        return result, [call for call in calls if call[0] == "gh"], [call for call in calls if call[0] == "sleep"]

    def test_a_transient_head_mismatch_is_retried_with_the_same_sha(self):
        result, queued, waits = self.run_case([[1, MISMATCH], [1, MISMATCH], *ACCEPTED])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(queued, [QUEUE] * 3 + [VIEW])
        self.assertEqual(len(waits), 2)

    def test_a_persistent_head_mismatch_fails_after_bounded_attempts(self):
        result, queued, _ = self.run_case([[1, MISMATCH]] * 20)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(queued, [QUEUE] * 5)

    def test_other_errors_fail_without_a_retry(self):
        for errors in ["GraphQL: Pull request is in clean status (enablePullRequestAutoMerge)",
                       MISMATCH.replace("#1:", "#2:"),
                       f"{MISMATCH}\nHTTP 502: Bad Gateway (https://api.github.com/graphql)"]:
            with self.subTest(errors=errors):
                result, queued, _ = self.run_case([[1, errors], *ACCEPTED])
                self.assertEqual(result.returncode, 1)
                self.assertEqual(queued, [QUEUE])
                self.assertIn(errors, result.stderr)

    def test_success_needs_the_bottle_commit_as_the_current_head(self):
        cases = {
            "queued at another head during the retry wait": ([[1, MISMATCH], [0, QUEUED], [0, "", "2" * 40]], [QUEUE, QUEUE, VIEW]),
            "failed head read": ([[0, ""], [1, "HTTP 502: Bad Gateway"]], [QUEUE, VIEW]),
        }
        for name, (responses, expected) in cases.items():
            with self.subTest(name):
                result, queued, _ = self.run_case([*responses, *ACCEPTED])
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(queued, expected)


if __name__ == "__main__":
    unittest.main()
