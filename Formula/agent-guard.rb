class AgentGuard < Formula
  desc "Blocks agent filesystem scans and protected credential reads"
  homepage "https://github.com/LoopHubs/agent-guard"
  url "https://github.com/LoopHubs/agent-guard.git",
      tag:      "v0.6.0",
      revision: "2a22ea4c1eeb2f971a1216d82d56b5c7d0710761"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  depends_on "go" => :build
  depends_on arch: :arm64
  depends_on :macos

  def install
    system "go", "build", *std_go_args(output: libexec/"bin/agent-guard-native", ldflags: "-X main.version=#{version}"), "./cmd/agent-guard"
    (libexec/"bin").install "bin/agent-guard"
    libexec.install "VERSION"
    bin.install_symlink libexec/"bin/agent-guard"
  end

  test do
    assert_equal "agent-guard #{version}\n", shell_output("#{bin}/agent-guard --version")
    event = '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
    assert_equal "", pipe_output("#{bin}/agent-guard --runtime claude", event, 0)
    event = '{"tool_name":"Bash","tool_input":{"command":"env"}}'
    assert_match "DENIED:", pipe_output("#{bin}/agent-guard --runtime claude 2>&1", event, 2)
  end
end
