cask "opencode-desktop-beta" do
  arch arm: "aarch64", intel: "x64"

  version :latest
  sha256 :no_check

  url "https://opencode.ai/download/beta/darwin-#{arch}-dmg"
  name "OpenCode Beta"
  desc "AI coding agent desktop client (beta channel)"
  homepage "https://opencode.ai/"

  auto_updates true
  depends_on macos: ">= :monterey"

  app "OpenCode Beta.app"

  zap trash: [
    "~/Library/Application Support/ai.opencode.desktop.beta",
    "~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/ai.opencode.desktop.beta.sfl*",
    "~/Library/Caches/ai.opencode.desktop.beta",
    "~/Library/HTTPStorages/ai.opencode.desktop.beta",
    "~/Library/Logs/ai.opencode.desktop.beta",
    "~/Library/Preferences/ai.opencode.desktop.beta.plist",
    "~/Library/Saved Application State/ai.opencode.desktop.beta.savedState",
    "~/Library/WebKit/ai.opencode.desktop.beta",
  ]
end
