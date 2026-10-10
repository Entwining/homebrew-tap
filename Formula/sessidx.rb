class Sessidx < Formula
  desc "Index local coding agent session logs for lookup and counts"
  homepage "https://github.com/Entwining/sessidx"
  url "https://github.com/Entwining/sessidx.git",
      tag:      "v0.0.3",
      revision: "d74232666322cdc26f7f4141837898918c2d7711"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/sessidx-0.0.3"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "3dfe0095c8d7be1767a44420d510fc3ca3a60e36189ff123a4673e6082a9df47"
  end

  depends_on "cargo-about" => :build
  depends_on "rust" => :build
  depends_on arch: :arm64
  depends_on :macos

  def install
    system "cargo", "install", *std_cargo_args
    # Homebrew copies LICENSE* files from the build directory into the keg, so the bottle carries these notices.
    # cargo-about reads metadata for every target, so fetch the crates that `cargo install` skips.
    system "cargo", "fetch", "--locked"
    system "cargo", "about", "generate", "--frozen", "--fail", "--output-file", "LICENSE-THIRD-PARTY.md", "about.hbs"
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
