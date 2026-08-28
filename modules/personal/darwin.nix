{pkgs, ...}: {
  # Non-work applications — only included when the "personal" profile is active.
  homebrew.casks = [
    # The GUI is not available in nixpkgs
    "tailscale-app"
    "balenaetcher"
    "bambu-studio"
    # Not available in nixpkgs
    "chrome-remote-desktop-host"
  ];

  # Windscribe: not in nixpkgs, and its homebrew cask is `installer manual:`
  # (a GUI wizard that must be run by hand), so brew can't automate it.
  # Instead, run the installer's silent mode during activation (as root).
  # ponytail: dmg URL+hash pinned to 2.23.11 — bump on release. If `-silent`
  #   ever needs a EULA interaction, fall back to adding "windscribe" to
  #   homebrew.casks above and accept the one-time manual installer.
  system.activationScripts.windscribe = {
    text = ''
      if [[ ! -d /Applications/Windscribe.app ]]; then
        dmg="${pkgs.fetchurl {
        url = "https://deploy.totallyacdn.com/desktop-apps/2.23.11/Windscribe_2.23.11_universal.dmg";
        sha256 = "393a9c0650a66b4fea87716f9a47369a20cb70681cb2cc6ee0cef157f693d116";
      }}"
        mount_point="$(/usr/bin/hdiutil attach -nobrowse -readonly "$dmg" | /usr/bin/awk 'END {print $3}')"
        # shellcheck disable=SC2064
        trap '/usr/bin/hdiutil detach "$mount_point" >/dev/null' EXIT
        "$mount_point/WindscribeInstaller.app/Contents/MacOS/installer" -silent -dir /Applications
      fi
    '';
  };
}
