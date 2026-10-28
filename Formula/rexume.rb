class Rexume < Formula
  desc "Restore Rex sessions and agent conversations after the server restarts"
  homepage "https://github.com/Entwining/rexume"
  url "https://github.com/Entwining/rexume.git",
      tag:      "v0.1.10",
      revision: "8aa3ed785edb35fd2615ceb35be24cf79d84868b"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/rexume-0.1.10"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "65f1d6302b3bfb61616cca1a4a5c602dd1f43432b3d51de9a6aae60307c23db0"
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
