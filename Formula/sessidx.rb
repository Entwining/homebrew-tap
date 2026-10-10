class Sessidx < Formula
  desc "Index local coding agent session logs for lookup and counts"
  homepage "https://github.com/Entwining/sessidx"
  url "https://github.com/Entwining/sessidx.git",
      tag:      "v0.0.2",
      revision: "229d417f8af921cbe6c3e9f2b1941b7cb1b9e364"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/sessidx-0.0.1"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "89bcac9824ebb7a32ed09d2fefeef4bcafe23ebd82e5f35c3ae1b9adc09cb191"
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
