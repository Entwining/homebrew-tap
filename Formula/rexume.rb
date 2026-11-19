class Rexume < Formula
  desc "Reopen agent conversations in restored Rex panes and return worker results"
  homepage "https://github.com/Entwining/rexume"
  url "https://github.com/Entwining/rexume.git",
      tag:      "v0.1.26",
      revision: "1d04f8a7f44b04ee6e1fa5be2b62fc77358e6d91"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/rexume-0.1.26"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "7434903ca118043c650e02b9a4f505b1fd5f3f50c2fa3668d11abd733d2f1bdd"
  end

  depends_on "cargo-about" => :build
  depends_on "rust" => :build
  depends_on arch: :arm64
  depends_on macos: :sequoia

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
