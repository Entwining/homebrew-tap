class Rexume < Formula
  desc "Restore Rex sessions and agent conversations after the server restarts"
  homepage "https://github.com/Entwining/rexume"
  url "https://github.com/Entwining/rexume.git",
      tag:      "v0.1.9",
      revision: "f74c3eb954a4dee6ae0905c1b77d5d6079c2c656"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/rexume-0.1.9"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "52588120b1376ec2992008b8054bdd9bd524501d41540fde814471db5313e390"
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
