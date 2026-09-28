class AgentGuard < Formula
  desc "Blocks agent filesystem scans and credential reads that trigger macOS App Data prompts"
  homepage "https://github.com/LoopHubs/agent-guard"
  url "https://registry.npmjs.org/@loophubs/agent-guard/-/agent-guard-0.1.0.tgz"
  sha256 "e06edbafaab77181adad3511c2475618e094f33bd8871486207ad246a557509b"
  license "MIT"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  def caveats
    <<~EOS
      agent-guard runs under bun. Install bun (for example with proto) and keep it on PATH.
    EOS
  end

  test do
    assert_match "agent-guard", shell_output("#{bin}/agent-guard --runtime claude", 2)
  end
end
