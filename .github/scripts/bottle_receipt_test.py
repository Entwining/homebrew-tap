import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HEAD = "1" * 40
TREE = "2" * 40
BLOB = "3" * 40
NEXT_HEAD = "4" * 40
REVISION = "a" * 40
SOURCE = f'''class Demo < Formula
  desc "Bottle receipt fixture"
  url "https://github.com/example/demo.git",
      tag: "v0.1.2",
      revision: "{REVISION}"
  raise "PR Ruby must not be evaluated"

  def install
    ENV.O3
    system "make", "build"
  end
end
'''

DRIVER = r'''
require ARGV.shift
fixture = JSON.parse(File.read(ARGV.shift))
operation = ARGV.shift
Utils.define_singleton_method(:safe_popen_read) do |*args|
  raise "Unexpected client: #{args.inspect}" unless args.first == "git"
  if args[1] == "show" && args.length == 3
    fixture.fetch("sources").fetch(args[2])
  elsif args[1..3] == ["show", "-s", "--format=%P"]
    fixture.fetch("parents").fetch(args[4]).join(" ")
  elsif args[1] == "rev-parse"
    fixture.fetch("blobs").fetch(args[2])
  elsif args[1] == "for-each-ref"
    if args[2] == "--format=%(contents)"
      record = fixture.fetch("tags", {})[args[3]]
      record ? JSON.generate(record) + "\n" : ""
    else
      fixture.fetch("tags", {}).keys.map { |ref| ref.delete_prefix("refs/tags/") }.join("\n") + "\n"
    end
  else
    raise "Unexpected Git operation: #{args.inspect}"
  end
end
Object.prepend(Module.new do
  define_method(:system) do |*args, **options|
    return true if args[0..2] == ["git", "cat-file", "-e"]
    super(*args, **options)
  end
end)
selection = fixture.fetch("selection")
result = case operation
when "plan"
  BottleReceipt.plan(selection, fixture.fetch("directory"))
when "roundtrip"
  records = BottleReceipt.plan(selection, fixture.fetch("directory"))
  BottleReceipt.write_plan(records, fixture.fetch("output"))
  commit = BottleReceipt.commit_input(selection, records)
  addition = commit.fetch("variables").fetch("input").fetch("fileChanges").fetch("additions").first
  text = addition.fetch("contents").unpack1("m0")
  fixture["sources"]["#{fixture.fetch("next_head")}:Formula/demo.rb"] = text
  fixture["tags"] = { "refs/tags/publish/#{BottleReceipt.key(records.first)}" => records.first }
  current = selection.merge("head_sha" => fixture.fetch("next_head"))
  { "records" => records, "text" => text, "commit" => commit, "ready" => BottleReceipt.ready_formulae(current) }
when "ready"
  BottleReceipt.ready_formulae(selection)
when "seed"
  BottleReceipt.seed(selection)
end
puts JSON.generate(result)
'''


class BottleReceiptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="bottle-receipt-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.directory = Path(cls.temp.name)
        (cls.directory / "driver.rb").write_text(DRIVER)
        cls.payload = b"synthetic bottle bytes\n"
        checksum = hashlib.sha256(cls.payload).hexdigest()
        cls.filename = "demo--0.1.2.arm64_tahoe.bottle.tar.gz"
        cls.metadata = {
            "entwining/tap/demo": {
                "formula": {
                    "name": "demo", "pkg_version": "0.1.2",
                    "path": "Library/Taps/entwining/homebrew-tap/Formula/demo.rb",
                    "tap_git_path": "Formula/demo.rb", "tap_git_revision": TREE,
                },
                "bottle": {
                    "root_url": "https://github.com/Entwining/homebrew-tap/releases/download/demo-0.1.2",
                    "rebuild": 0,
                    "cellar": "any_skip_relocation",
                    "tags": {"arm64_tahoe": {
                        "filename": "demo-0.1.2.arm64_tahoe.bottle.tar.gz",
                        "local_filename": cls.filename, "sha256": checksum,
                        "tab": {"source": {"scm_revision": REVISION}},
                    }},
                },
            }
        }
        cls.baseline = {
            "selection": {
                "repository": "Entwining/homebrew-tap", "pull_request": 1,
                "head_sha": HEAD, "branch": "bump-demo-0.1.2", "paths": ["Formula/demo.rb"],
                "run": {"id": 101, "run_attempt": 1, "event": "pull_request", "conclusion": "success",
                        "head_sha": HEAD, "path": ".github/workflows/tests.yml",
                        "repository": {"full_name": "Entwining/homebrew-tap"}},
                "artifact": {"id": 201, "name": "bottles_macos-26-1", "expired": False,
                             "digest": "sha256:" + "d" * 64, "workflow_run": {"id": 101, "head_sha": HEAD}},
            },
            "sources": {f"{HEAD}:Formula/demo.rb": SOURCE},
            "blobs": {f"{HEAD}:Formula/demo.rb": BLOB, f"{TREE}:Formula/demo.rb": BLOB},
            "parents": {TREE: ["b" * 40, HEAD]}, "next_head": NEXT_HEAD,
        }

    def setUp(self):
        self.case = tempfile.TemporaryDirectory(dir=self.directory)
        self.addCleanup(self.case.cleanup)
        self.path = Path(self.case.name)
        self.bottles = self.path / "bottles"
        self.bottles.mkdir()
        (self.bottles / self.filename).write_bytes(self.payload)
        self.data = copy.deepcopy(self.metadata)
        self.fixture = copy.deepcopy(self.baseline)
        self.fixture.update(directory=str(self.bottles), output=str(self.path / "output"))

    def run_case(self, operation="plan", success=True):
        (self.bottles / "demo--0.1.2.arm64_tahoe.bottle.json").write_text(json.dumps(self.data))
        config = self.path / "fixture.json"
        config.write_text(json.dumps(self.fixture))
        result = subprocess.run(
            ["brew", "ruby", str(self.directory / "driver.rb"), str(ROOT / ".github/scripts/bottle_receipt.rb"), str(config), operation],
            cwd=ROOT, env={**os.environ, "HOMEBREW_NO_AUTO_UPDATE": "1"},
            text=True, capture_output=True, timeout=60,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        return result.stderr

    def published(self):
        result = self.run_case("roundtrip")
        record = result["records"][0]
        self.fixture["tags"] = {"refs/tags/publish/demo-0.1.2": record}
        self.fixture["sources"][f"{NEXT_HEAD}:Formula/demo.rb"] = result["text"]
        self.fixture["selection"]["head_sha"] = NEXT_HEAD
        return result

    def test_roundtrip_preserves_source_and_binds_commit_head(self):
        result = self.published()
        self.assertEqual(result["ready"], ["demo"])
        self.assertIn('raise "PR Ruby must not be evaluated"', result["text"])
        commit = result["commit"]["variables"]["input"]
        self.assertEqual(commit["expectedHeadOid"], HEAD)
        self.assertEqual([entry["path"] for entry in commit["fileChanges"]["additions"]], ["Formula/demo.rb"])
        self.assertEqual(commit["message"]["headline"], "build(demo): add 0.1.2 bottle")

    def test_same_version_install_change_cannot_reuse_old_bottle(self):
        self.published()
        self.fixture["sources"][f"{NEXT_HEAD}:Formula/demo.rb"] = self.fixture["sources"][f"{NEXT_HEAD}:Formula/demo.rb"].replace("ENV.O3", "ENV.O2")
        self.assertIsNone(self.run_case("ready"))

    def test_bottle_checksum_must_match_the_receipt(self):
        self.published()
        text = self.fixture["sources"][f"{NEXT_HEAD}:Formula/demo.rb"]
        checksum = hashlib.sha256(self.payload).hexdigest()
        self.fixture["sources"][f"{NEXT_HEAD}:Formula/demo.rb"] = text.replace(checksum, "0" * 64)
        self.assertIsNone(self.run_case("ready"))

    def test_resume_selects_original_artifact(self):
        record = self.run_case()[0]
        self.fixture["tags"] = {"refs/tags/publish/demo-0.1.2": record}
        self.fixture["selection"]["run"]["id"] = 999
        seed = self.run_case("seed")
        self.assertEqual(seed["run_id"], 101)
        self.assertEqual(seed["artifact_id"], 201)

    def test_tested_commit_must_contain_source_head(self):
        self.fixture["parents"][TREE] = ["b" * 40]
        self.assertIn("unrelated", self.run_case(success=False))

    def test_tested_formula_must_match_source_blob(self):
        self.fixture["blobs"][f"{TREE}:Formula/demo.rb"] = "c" * 40
        self.assertIn("differs", self.run_case(success=False))

    def test_bottle_must_contain_declared_upstream_revision(self):
        self.data["entwining/tap/demo"]["bottle"]["tags"]["arm64_tahoe"]["tab"]["source"]["scm_revision"] = "f" * 40
        self.assertIn("another source revision", self.run_case(success=False))

    def test_tar_bytes_must_match_metadata(self):
        (self.bottles / self.filename).write_bytes(b"corrupt")
        self.assertIn("checksum differs", self.run_case(success=False))

    def test_artifact_symlink_is_rejected(self):
        (self.bottles / "extra").symlink_to(self.bottles / self.filename)
        self.assertIn("symlink", self.run_case(success=False))

    def test_metadata_cannot_redirect_or_inject_ruby(self):
        for field, value in [("root_url", "https://example.com/bottles"), ("cellar", 'any"; raise "injected')]:
            with self.subTest(field=field):
                self.data = copy.deepcopy(self.metadata)
                bottle = self.data["entwining/tap/demo"]["bottle"]
                bottle[field] = value
                self.run_case(success=False)

    def test_artifact_attempt_and_expiry_are_enforced(self):
        for change in [{"name": "bottles_macos-26-2"}, {"expired": True}, {"digest": None}]:
            with self.subTest(change=change):
                self.fixture["selection"]["artifact"] = {**self.baseline["selection"]["artifact"], **change}
                self.run_case(success=False)

    def test_only_successful_pr_builds_are_eligible(self):
        for change in [{"event": "workflow_dispatch"}, {"conclusion": "failure"}, {"head_sha": NEXT_HEAD}]:
            with self.subTest(change=change):
                self.fixture["selection"]["run"] = {**self.baseline["selection"]["run"], **change}
                self.run_case(success=False)

    def test_maintenance_needs_no_bottle(self):
        self.fixture["selection"]["paths"] = []
        self.assertEqual(self.run_case("ready"), [])


if __name__ == "__main__":
    unittest.main()
