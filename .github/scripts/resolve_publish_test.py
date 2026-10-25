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

CLIENT = r'''
import json, os, pathlib, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
fixture = json.loads(pathlib.Path(os.environ["FIXTURE"]).read_text())
with open(os.environ["CALLS"], "a") as output:
    output.write(json.dumps([name, *args]) + "\n")
if name == "git":
    assert args[0] == "fetch"
    sys.exit(0)
if name == "brew":
    assert args[0] == "ruby"
    print(json.dumps(fixture.get("seed", {}) if args[2] == "seed" else fixture.get("status", {"state": "prepare", "formulae": None})))
    sys.exit(0)
if args[0:2] == ["pr", "list"]:
    result = [{"number": 1}]
else:
    assert args[0] == "api"
    result = fixture["responses"][args[1]]
    if "--slurp" in args:
        result = [result]
if "--jq" in args:
    result = subprocess.run(["jq", "-r", args[args.index("--jq") + 1]], input=json.dumps(result), text=True, capture_output=True, check=True).stdout
    print(result, end="")
else:
    print(json.dumps(result))
'''


class ResolvePublishTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="resolve-publish-")
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.bin = self.path / "bin"
        self.bin.mkdir()
        for name in ("gh", "git", "brew"):
            client = self.bin / name
            client.write_text(f"#!{sys.executable}\n" + CLIENT)
            client.chmod(0o755)
        self.pr = {"number": 1, "node_id": "PR_fixture", "user": {"login": "entwining-release[bot]"},
                   "state": "open", "merged": False, "draft": False, "mergeable_state": "clean",
                   "head": {"sha": HEAD, "ref": "bump-demo-0.1.2", "repo": {"full_name": REPOSITORY}}, "base": {"ref": "main"}}
        self.run = {"id": 101, "run_attempt": 1, "conclusion": "success"}
        self.artifact = {"id": 201, "digest": "sha256:" + "d" * 64, "expired": False}
        prefix = f"repos/{REPOSITORY}"
        self.fixture = {"responses": {
            f"{prefix}/pulls/1": self.pr,
            f"{prefix}/pulls/1/files": [{"filename": "Formula/demo.rb", "status": "modified"}],
            f"{prefix}/actions/runs/101": self.run,
            f"{prefix}/actions/runs/101/attempts/1": self.run,
            f"{prefix}/actions/runs/101/artifacts?name=bottles_macos-26-1": {"artifacts": [self.artifact]},
            f"{prefix}/actions/artifacts/201": self.artifact,
        }}

    def run_case(self, *, identify=False, **overrides):
        config = self.path / "fixture.json"
        config.write_text(json.dumps(self.fixture))
        output = self.path / "outputs"
        output.write_text("")
        calls = self.path / "calls"
        calls.write_text("")
        env = {
            "PATH": f"{self.bin}:{os.environ['PATH']}", "HOME": str(self.path),
            "FIXTURE": str(config), "CALLS": str(calls), "GITHUB_OUTPUT": str(output),
            "GITHUB_STEP_SUMMARY": str(self.path / "summary"), "GITHUB_REPOSITORY": REPOSITORY,
            "PULL_REQUEST": "1", "EXPECTED_SHA": HEAD, "SOURCE_RUN_ID": "101", "SOURCE_RUN_ATTEMPT": "1",
            **overrides,
        }
        command = ["bash", str(ROOT / ".github/scripts/resolve-publish.sh"), str(self.path / "source")]
        if identify:
            command.append("--identify")
        result = subprocess.run(command,
                                env=env, text=True, capture_output=True, timeout=10)
        return result, dict(line.split("=", 1) for line in output.read_text().splitlines()), [json.loads(line) for line in calls.read_text().splitlines()]

    def test_success_binds_the_run_attempt_and_artifact(self):
        result, outputs, calls = self.run_case()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(outputs["state"], "prepare")
        selection = json.loads((self.path / "source/selection.json").read_text())
        self.assertEqual(selection["run"]["id"], 101)
        self.assertEqual(selection["artifact"]["id"], 201)
        details = json.loads((self.path / "source/pr.json").read_text())
        self.assertEqual(details["node_id"], "PR_fixture")
        self.assertEqual(details["author"], "entwining-release[bot]")
        self.assertTrue(all("-X" not in call for call in calls))

    def test_a_new_head_invalidates_the_old_trigger(self):
        self.pr["head"]["sha"] = "2" * 40
        result, outputs, calls = self.run_case()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(outputs["state"], "inactive")
        self.assertFalse(any(call[0] in ("git", "brew") for call in calls))

    def test_identification_needs_no_git_homebrew_or_artifact_access(self):
        result, outputs, calls = self.run_case(identify=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(outputs, {"state": "active", "pull_request": "1", "head_sha": HEAD})
        self.assertFalse(any(call[0] in ("git", "brew") or "/actions/" in str(call) for call in calls))

    def test_behind_branches_without_receipts_sync_before_selecting_bottles(self):
        self.pr["mergeable_state"] = "behind"
        result, outputs, calls = self.run_case()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(outputs["state"], "sync")
        self.assertEqual(outputs["head_sha"], HEAD)
        self.assertFalse(any("/actions/" in str(call) for call in calls))

    def test_behind_ready_heads_sync_without_selecting_a_build(self):
        self.pr["mergeable_state"] = "behind"
        self.fixture["status"] = {"state": "ready", "formulae": ["demo"]}
        for repository, expected in [(REPOSITORY, "sync"), ("contributor/homebrew-tap", "waiting")]:
            with self.subTest(repository=repository):
                self.pr["head"]["repo"]["full_name"] = repository
                result, outputs, calls = self.run_case()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(outputs["state"], expected)
                self.assertFalse(any("/actions/" in str(call) for call in calls))

    def test_behind_forks_wait_for_the_contributor(self):
        self.pr["mergeable_state"] = "behind"
        self.pr["head"]["repo"]["full_name"] = "contributor/homebrew-tap"
        result, outputs, _ = self.run_case()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(outputs["state"], "waiting")
        self.assertIn("fork branch", (self.path / "summary").read_text())

    def test_recovery_resumes_the_receipt_before_branch_sync(self):
        self.pr["mergeable_state"] = "behind"
        self.fixture["seed"] = {"run_id": 101, "run_attempt": 1, "artifact_id": 201, "artifact_digest": self.artifact["digest"]}
        for repository in [REPOSITORY, "contributor/homebrew-tap"]:
            with self.subTest(repository=repository):
                self.pr["head"]["repo"]["full_name"] = repository
                result, outputs, calls = self.run_case(SOURCE_RUN_ID="999", SOURCE_RUN_ATTEMPT="2")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(outputs["state"], "prepare")
                self.assertEqual(outputs["head_sha"], HEAD)
                self.assertEqual(outputs["artifact_id"], "201")
                self.assertFalse(any("999" in str(call) for call in calls))

    def test_expired_artifacts_fail_instead_of_looking_ready(self):
        self.artifact["expired"] = True
        result, outputs, _ = self.run_case()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("state", outputs)


if __name__ == "__main__":
    unittest.main()
