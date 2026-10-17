class Sessidx < Formula
  desc "Index local coding agent session logs for lookup and counts"
  homepage "https://github.com/Entwining/sessidx"
  url "https://github.com/Entwining/sessidx.git",
      tag:      "v0.0.9",
      revision: "23ce4960e66fed484efaa03d56a96e919c8e7ea9"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/sessidx-0.0.8"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "b567ea50b5b0e0cce679c5aafa7a694f67f85c4317b7bc431315d4fcce504342"
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
