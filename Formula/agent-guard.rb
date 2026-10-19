class AgentGuard < Formula
  desc "Blocks agent filesystem scans and protected credential reads"
  homepage "https://github.com/Entwining/agent-guard"
  url "https://github.com/Entwining/agent-guard.git",
      tag:      "v0.8.6",
      revision: "71849adcaabf7b3c7f227b47583cc78cb1d46be4"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/agent-guard-0.8.5"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "1e5d4dc189655c2beb0b0209408f5323d803e64b173359b6c2c85855a6ebb5bf"
  end

  depends_on "cargo-about" => :build
  depends_on "rust" => :build
  depends_on arch: :arm64
  depends_on :macos

  def install
    # `make build` stages the whole package, so a packaging change ships with the release that makes it.
    # It refuses directories inside a Git checkout, which the build directory and the Homebrew prefix both are.
    mktemp do |staging|
      package = staging.tmpdir/"package"
      system "make", "--directory=#{buildpath}", "build", "OUT=#{package}",
             "CARGO_TARGET_DIR=#{staging.tmpdir}/cargo-target"
      libexec.install package.children
    end
    bin.install_symlink libexec/"bin/agent-guard"
  end

  test do
    assert_equal "agent-guard #{version}\n", shell_output("#{bin}/agent-guard --version")
    assert_path_exists libexec/"LICENSE-THIRD-PARTY.md"
    event = '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
    assert_equal "", pipe_output("#{bin}/agent-guard --runtime claude", event, 0)
    event = '{"tool_name":"Bash","tool_input":{"command":"env"}}'
    assert_match "DENIED:", pipe_output("#{bin}/agent-guard --runtime claude 2>&1", event, 2)
  end
end
