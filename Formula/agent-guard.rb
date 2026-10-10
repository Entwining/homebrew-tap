class AgentGuard < Formula
  desc "Blocks agent filesystem scans and protected credential reads"
  homepage "https://github.com/Entwining/agent-guard"
  url "https://github.com/Entwining/agent-guard.git",
      tag:      "v0.8.0",
      revision: "34470399874811a0542d9bfaec0ac4d2a26d2261"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/agent-guard-0.7.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "4955836bc9ca8bafb9b87103f7dc42d3cf1cdac3516f0a82d9f9911667f24790"
  end

  depends_on "cargo-about" => :build
  depends_on "rust" => :build
  depends_on arch: :arm64
  depends_on :macos

  def install
    system "cargo", "install", *std_cargo_args(root: libexec), "--bin", "agent-guard-native"
    (libexec/"bin").install "bin/agent-guard"
    libexec.install "VERSION"
    bin.install_symlink libexec/"bin/agent-guard"
    # Homebrew copies LICENSE* files from the build directory into the keg, so the bottle carries these notices.
    # cargo-about reads metadata for every target, so fetch the crates that `cargo install` skips.
    system "cargo", "fetch", "--locked"
    system "cargo", "about", "generate", "--frozen", "--fail", "--output-file", "LICENSE-THIRD-PARTY.md", "about.hbs"
  end

  test do
    assert_equal "agent-guard #{version}\n", shell_output("#{bin}/agent-guard --version")
    assert_path_exists prefix/"LICENSE-THIRD-PARTY.md"
    event = '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
    assert_equal "", pipe_output("#{bin}/agent-guard --runtime claude", event, 0)
    event = '{"tool_name":"Bash","tool_input":{"command":"env"}}'
    assert_match "DENIED:", pipe_output("#{bin}/agent-guard --runtime claude 2>&1", event, 2)
  end
end
