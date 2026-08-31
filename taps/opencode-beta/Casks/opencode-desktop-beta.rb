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

  app "OpenCode.app"

  conflicts_with cask: "opencode-desktop"

  zap trash: [
    "~/Library/Application Support/ai.opencode.desktop",
    "~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/ai.opencode.desktop.sfl*",
    "~/Library/Caches/ai.opencode.desktop",
    "~/Library/HTTPStorages/ai.opencode.desktop",
    "~/Library/Logs/ai.opencode.desktop",
    "~/Library/Preferences/ai.opencode.desktop.plist",
    "~/Library/Saved Application State/ai.opencode.desktop.savedState",
    "~/Library/WebKit/ai.opencode.desktop",
  ]
end
