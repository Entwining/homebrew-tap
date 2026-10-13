class Sessidx < Formula
  desc "Index local coding agent session logs for lookup and counts"
  homepage "https://github.com/Entwining/sessidx"
  url "https://github.com/Entwining/sessidx.git",
      tag:      "v0.0.7",
      revision: "9131d080c8f8f486d51886a7d580cb0ae65fa7a9"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/sessidx-0.0.7"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "7e60e2100d828cde012142e1fa97d376e45c86244c4958201944b6d9ec4c4177"
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
