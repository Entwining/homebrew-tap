cask "maskey" do
  version "0.0.12"
  sha256 "d98814ce87ebd19085acb11fadaed50ac5c90e05a25f006813cec561173ca484"

  url "https://github.com/Entwining/maskey/releases/download/v#{version}/maskey-#{version}-darwin-arm64.tar.gz"
  name "Maskey"
  desc "Credentials in iCloud Keychain, passed to commands as masked variables"
  homepage "https://github.com/Entwining/maskey"

  livecheck do
    url :url
    regex(/^v(0\.\d+\.\d+)$/i)
    strategy :github_latest
  end

  # The app replaces itself with each signed release.
  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Maskey.app"
  # main.go runs the command line when the executable is invoked as mk.
  binary "#{appdir}/Maskey.app/Contents/MacOS/Maskey", target: "mk"

  uninstall launchctl: "io.github.entwining.maskey.service",
            quit:      "io.github.entwining.maskey"

  # Entries live in iCloud Keychain and sync to the user's other Macs, so zap leaves them alone.
  zap trash: "~/Library/Application Support/io.github.entwining.maskey"

  caveats <<~EOS
    Maskey is signed ad hoc and not notarized, so Gatekeeper blocks it until you run:
      xattr -dr com.apple.quarantine #{appdir}/Maskey.app

    Then run `mk setup` to install the Maskey service, which sandboxed commands,
    Bitwarden stores, and `mk grant` need.
    Maskey updates itself; set HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1 so that
    `brew upgrade` does not reinstall it, quarantined again.
  EOS
end
