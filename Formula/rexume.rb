class Rexume < Formula
  desc "Restore Rex sessions and agent conversations after the server restarts"
  homepage "https://github.com/Entwining/rexume"
  url "https://github.com/Entwining/rexume.git",
      tag:      "v0.1.6",
      revision: "e819ad5a1adb26a27eb46b48fe3fe476351c786b"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/rexume-0.1.5"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "2ed0cea29f4aa4f7b27582436b054e1c03248c194e9c084adb0a9bbe8dc38df3"
  end

  depends_on "cargo-about" => :build
  depends_on "rust" => :build
  depends_on arch: :arm64
  depends_on :macos

  def install
    # Homebrew's make wrapper replaces the -O3 that cc-rs passes for the bundled SQLite with -Os.
    ENV.O3
    # `make build` stages the whole package, so a packaging change ships with the release that makes it.
    system "make", "build", "OUT=#{prefix}"
  end

  test do
    assert_equal "rexume #{version}\n", shell_output("#{bin}/rexume --version")
    assert_path_exists prefix/"LICENSE-THIRD-PARTY.md"
    output = shell_output("#{bin}/rexume status --state-dir #{testpath}/state 2>&1", 1)
    assert_match "the daemon creates it", output
  end
end
