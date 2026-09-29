class AgentGuard < Formula
  desc "Blocks agent filesystem scans and credential reads that trigger macOS App Data prompts"
  homepage "https://github.com/LoopHubs/agent-guard"
  url "https://registry.npmjs.org/@loophubs/agent-guard/-/agent-guard-0.3.0.tgz"
  sha256 "42028af07a71c6db666db785ffc00c8d4c4b92f885f16e42289b5eac95f8dc32"
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
