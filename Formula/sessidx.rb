class Sessidx < Formula
  desc "Index local coding agent session logs for lookup and counts"
  homepage "https://github.com/Entwining/sessidx"
  url "https://github.com/Entwining/sessidx.git",
      tag:      "v0.0.10",
      revision: "c2417dfd6a263da5078510f8f21d80b6c92cc1e8"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/sessidx-0.0.10"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "2252a6b12aa2161e7fc645794b50ff594989b90fc66b45bcaa1e3c7846c39fa6"
  end

  depends_on "cargo-about" => :build
  depends_on "rust" => :build
  depends_on arch: :arm64
  depends_on :macos

  def install
    # Homebrew's make wrapper replaces the -O3 that cc-rs passes for the bundled SQLite and zstd with -Os.
    ENV.O3
    # `make build` stages the whole package, so a packaging change ships with the release that makes it.
    system "make", "build", "OUT=#{prefix}"
  end

  test do
    assert_equal "sessidx #{version}\n", shell_output("#{bin}/sessidx --version")
    assert_path_exists prefix/"LICENSE-THIRD-PARTY.md"
    (testpath/"codex/session.jsonl").write <<~JSON
      {"type":"response_item","timestamp":"2026-10-01T00:00:00Z","payload":{"type":"message","id":"m1","role":"user","content":[{"type":"input_text","text":"brewneedle"}]}}
    JSON
    output = shell_output("#{bin}/sessidx --db #{testpath}/index.db --root codex=#{testpath}/codex search brewneedle")
    assert_match '"type":"session"', output
  end
end
