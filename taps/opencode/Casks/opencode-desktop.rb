cask "opencode-desktop" do
  arch arm: "arm64", intel: "x64"

  version "2.0.6"
  sha256 arm: "2dc01ac10fb6fca611e9dcca062429513fe798d318e28e2fc7702440a89ea2b1",
         intel: "2d86813122faaf0a799c3df7bbef0da51c682d643c0f6ef6fa4ea0b891ae5284"

  # TODO: bump the version by updating `version` and the `sha256` hashes.
  # ARM hash: shasum -a 256 of
  #   "https://opencode.ai/files/bin/<version>/opencode-desktop-mac-arm64.dmg"
  # (see https://opencode.ai/v2/docs for the versioned download links).
  url "https://opencode.ai/files/bin/#{version}/opencode-desktop-mac-#{arch}.dmg"
  name "OpenCode"
  desc "AI coding agent desktop client"
  homepage "https://opencode.ai/"

  # Pinned to the v2 stable DMG: nix-darwin manages upgrades of this cask
  # on activation, so it must NOT declare auto_updates (brew skips such
  # casks on `brew upgrade` unless --greedy).
  depends_on macos: :monterey

  app "OpenCode.app"

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
