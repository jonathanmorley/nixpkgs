# See https://daiderd.com/nix-darwin/manual/index.html#sec-options
{
  pkgs,
  lib,
  config,
  opencode,
  ...
}: let
  netskopeRootCert = builtins.readFile ./netskope-root.pem;
  netskopeRootFingerprint = "EA0D6091E2A2B9509FDF9E9145517BE4DBEE6A915169C3EF2DF0D102165F7E37";

  # Create custom cacert by appending the Netskope root to the standard bundle
  # Using a custom derivation because extraCertificateStrings doesn't work in nixpkgs 25.11
  customCacert = pkgs.runCommand "cacert-with-netskope" {} ''
        mkdir -p $out/etc/ssl/certs

        # Copy all certs from the base cacert package
        cp -r ${pkgs.cacert}/etc/ssl/certs/* $out/etc/ssl/certs/

        # Make files writable
        chmod -R +w $out/etc/ssl/certs

        # Append the Netskope root certificate
        cat >> $out/etc/ssl/certs/ca-bundle.crt << 'EOF'

    ${netskopeRootCert}
    EOF

        # Also append to ca-certificates.crt if it exists
        if [ -f $out/etc/ssl/certs/ca-certificates.crt ]; then
          cat >> $out/etc/ssl/certs/ca-certificates.crt << 'EOF'

    ${netskopeRootCert}
    EOF
        fi
  '';

  certBundle = "${customCacert}/etc/ssl/certs/ca-bundle.crt";
  upstreamOpencode = opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  cventNodeModules = upstreamOpencode.node_modules.overrideAttrs (old: {
    buildPhase =
      lib.replaceStrings
      ["bun install"]
      ["bun install --cafile \"${certBundle}\""]
      old.buildPhase;
  });
  cventOpencode = upstreamOpencode.override {node_modules = cventNodeModules;};
  cventOpencodeDesktop = opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop.override {
    opencode = cventOpencode;
  };
in {
  # Override custom packages so their source fetches use a cert bundle that
  # includes the Netskope proxy cert. Explicit .override chains replace
  # cacert → fetchurl → fetchzip → fetchFromGitHub for just these packages,
  # keeping binary cache hits for everything else.
  nixpkgs.overlays = lib.mkAfter [
    (_final: prev: let
      corpoFetchurl = prev.fetchurl.override {cacert = customCacert;};
      corpoFetchzip = prev.fetchzip.override {fetchurl = corpoFetchurl;};
      corpoFetchFromGitHub = prev.fetchFromGitHub.override {fetchzip = corpoFetchzip;};
    in {
      fnox = prev.fnox.override {fetchFromGitHub = corpoFetchFromGitHub;};
      gig = prev.gig.override {fetchFromGitHub = corpoFetchFromGitHub;};
      rtk = prev.rtk.override {fetchFromGitHub = corpoFetchFromGitHub;};
    })
    (_final: _prev: {
      opencode = cventOpencode;
      opencode-desktop = cventOpencodeDesktop;
    })
  ];

  # Netskope trust anchor for the Nix/OpenSSL system CA bundle
  security.pki.certificates = [netskopeRootCert];
  # security.pki only manages the PEM bundle, so install and trust the same
  # root in the macOS System Keychain for SecureTransport clients.
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    if ! /usr/bin/security find-certificate -c "certadmin" -a -Z /Library/Keychains/System.keychain 2>/dev/null \
      | ${pkgs.gnugrep}/bin/grep -Fq "SHA-256 hash: ${netskopeRootFingerprint}" \
      || ! /usr/bin/security verify-cert -c ${./netskope-root.pem} -p ssl -L -l -k /Library/Keychains/System.keychain -q; then
      /usr/bin/security add-trusted-cert -d -r trustRoot -p ssl -k /Library/Keychains/System.keychain ${./netskope-root.pem}
    fi
  '';
  # Ensure that Node (and Bun) use the system CA (keystore) which includes the Netskope cert.
  environment.variables.NODE_USE_SYSTEM_CA = "1";
  # Standalone pnpm (via mise/asdf) bundles its own Node runtime that ignores
  # NODE_USE_SYSTEM_CA. It needs NODE_EXTRA_CA_CERTS to trust the Netskope cert.
  environment.variables.NODE_EXTRA_CA_CERTS = certBundle;
  # Homebrew Python/OpenSSL and Bundler do not read NIX_SSL_CERT_FILE. Export
  # the same bundle through their dedicated configuration variables.
  environment.variables.SSL_CERT_FILE = certBundle;
  environment.variables.REQUESTS_CA_BUNDLE = certBundle;
  environment.variables.BUNDLE_SSL_CA_CERT = certBundle;
  environment.variables.UV_NATIVE_TLS = "1";

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = {
    casks = [
      # Stay on latest better
      "claude-code@latest"
      "claude"
      # Not available in nixpkgs
      "microsoft-outlook"
      # Not available in nixpkgs
      "microsoft-excel"
    ];
    masApps = {
      # The firefox extension doesnt unlock with biometrics if bitwarden is installed any other way
      "bitwarden" = 1352778147;
    };
  };

  system.defaults.dock.persistent-apps = [
    "${pkgs.slack}/Applications/Slack.app"
    "/Applications/Microsoft Outlook.app"
  ];

  home-manager.users.${config.system.primaryUser}.programs.ssh.settings."*".IdentityAgent = "\"/Users/${config.system.primaryUser}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock\"";
}
