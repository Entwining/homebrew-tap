class AgentGuard < Formula
  desc "Blocks agent filesystem scans and protected credential reads"
  homepage "https://github.com/Entwining/agent-guard"
  url "https://github.com/Entwining/agent-guard.git",
      tag:      "v0.8.3",
      revision: "7185eb1118b4c97ba30b7e6c5a140588823d7aa0"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/Entwining/homebrew-tap/releases/download/agent-guard-0.8.3"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "020e69b7e0c8965eef6ca75c6922411fcf409ca2823b87c381db5ee1146bdc80"
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
