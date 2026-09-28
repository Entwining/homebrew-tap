class AgentGuard < Formula
  desc "Blocks agent filesystem scans and credential reads that trigger macOS App Data prompts"
  homepage "https://github.com/LoopHubs/agent-guard"
  url "https://registry.npmjs.org/@loophubs/agent-guard/-/agent-guard-0.2.0.tgz"
  sha256 "7f678f0e8e587288b87d762a33298310c5c4137b206eb7c7e8125e035018ff04"
  license "MIT"

  depends_on "node"
  depends_on "oven-sh/bun/bun"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    assert_match "agent-guard", shell_output("#{bin}/agent-guard --runtime claude", 2)
  end
end
