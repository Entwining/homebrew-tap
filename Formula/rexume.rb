class Rexume < Formula
  desc "Restore Rex sessions and agent conversations after the server restarts"
  homepage "https://github.com/Entwining/rexume"
  url "https://github.com/Entwining/rexume.git",
      tag:      "v0.1.11",
      revision: "40431092569c93ea320d94fe66a7cec6f0f0fc07"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/rexume-0.1.11"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "8299455fbe8fdb7af96501f21e059b6e41478315d14f0d0c50465b8b8d821877"
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
    # After `install`, Homebrew moves the build directory's README.md into the prefix,
    # over the one `make build` staged with links to the release's documents.
    rm "README.md"
  end

  test do
    assert_equal "rexume #{version}\n", shell_output("#{bin}/rexume --version")
    assert_path_exists prefix/"LICENSE-THIRD-PARTY.md"
    assert_match "/blob/v#{version}/", (prefix/"README.md").read
    output = shell_output("#{bin}/rexume status --state-dir #{testpath}/state 2>&1", 1)
    assert_match "the daemon creates it", output
  end
end
