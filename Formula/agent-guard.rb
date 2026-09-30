class AgentGuard < Formula
  desc "Blocks agent filesystem scans and credential reads that trigger macOS App Data prompts"
  homepage "https://github.com/LoopHubs/agent-guard"
  url "https://registry.npmjs.org/@loophubs/agent-guard/-/agent-guard-0.5.0.tgz"
  sha256 "bbeedeb6625ed9c6a18ef029e7bb88fa7f3bf465ff1425487e27f7354dcd42ce"
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
