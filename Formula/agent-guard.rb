class AgentGuard < Formula
  desc "Blocks agent filesystem scans and protected credential reads"
  homepage "https://github.com/Entwining/agent-guard"
  url "https://github.com/Entwining/agent-guard.git",
      tag:      "v0.8.1",
      revision: "85af0573f7274fe7e4c0bf607dff16e2c6545a78"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/agent-guard-0.8.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "dbcabcce24c32b7be9a022f89350f2e3d9acde05de8f406aae5783a4a5a00f93"
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
