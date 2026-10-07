class Sessidx < Formula
  desc "Index local Claude Code, Codex, and Pi session logs for lookup and counts"
  homepage "https://github.com/LoopHubs/sessidx"
  url "https://github.com/LoopHubs/sessidx.git",
      tag:      "v0.0.1",
      revision: "765188f3a33c507c86744af1e986629c73518256"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  depends_on "rust" => :build
  depends_on arch: :arm64
  depends_on :macos

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_equal "sessidx #{version}\n", shell_output("#{bin}/sessidx --version")
    (testpath/"codex/session.jsonl").write <<~JSON
      {"type":"response_item","timestamp":"2026-10-01T00:00:00Z","payload":{"type":"message","id":"m1","role":"user","content":[{"type":"input_text","text":"brewneedle"}]}}
    JSON
    output = shell_output("#{bin}/sessidx --db #{testpath}/index.db --root codex=#{testpath}/codex search brewneedle")
    assert_match '"type":"session"', output
  end
end
