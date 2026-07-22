{self, ...}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: let
    certificateChecks = lib.optionalAttrs (system == "aarch64-darwin") (
      let
        cventConfig = self.darwinConfigurations.D3W27G1QW9.config;
        cventEnvironment = cventConfig.environment.variables;
        systemCertificates = pkgs.writeText "system-certificates.pem" (lib.concatStringsSep "\n" cventConfig.security.pki.certificates);
        activationScript = pkgs.writeText "activation-script" cventConfig.system.activationScripts.extraActivation.text;
        cventOpencodeDesktop = self.darwinConfigurations.D3W27G1QW9.pkgs.opencode-desktop;
        ghaOpencodeDesktop = self.darwinConfigurations.gha-aarch64-darwin.pkgs.opencode-desktop;
        cventMakeBinaryWrapper = self.darwinConfigurations.D3W27G1QW9.pkgs.makeBinaryWrapper;
        ghaMakeBinaryWrapper = self.darwinConfigurations.gha-aarch64-darwin.pkgs.makeBinaryWrapper;
        cventProfileBin = "/etc/profiles/per-user/${self.darwinConfigurations.D3W27G1QW9.config.system.primaryUser}/bin";
        ghaProfileBin = "/etc/profiles/per-user/${self.darwinConfigurations.gha-aarch64-darwin.config.system.primaryUser}/bin";
      in {
        certificates = pkgs.runCommand "certificate-tests" {nativeBuildInputs = [pkgs.openssl];} ''
          ${./tests/certs-static.sh} \
            ${./modules/cvent} \
            ${cventEnvironment.BUNDLE_SSL_CA_CERT} \
            ${systemCertificates} \
            ${activationScript} \
            ${cventEnvironment.NODE_EXTRA_CA_CERTS} \
            ${cventEnvironment.SSL_CERT_FILE} \
            ${cventEnvironment.REQUESTS_CA_BUNDLE} \
            ${cventEnvironment.BUNDLE_SSL_CA_CERT}
          touch "$out"
        '';

        opencode-desktop-fnox-wrap = pkgs.runCommand "opencode-desktop-fnox-wrap-tests" {} ''
          assert_wrapper() {
            local configuration="$1"
            local post_install="$2"
            local fnox="$3"
            local native_build_inputs="$4"
            local make_binary_wrapper="$5"
            local profile_bin="$6"

            if [[ "$post_install" != *".OpenCode-unwrapped"* ]]; then
              echo "$configuration opencode-desktop fnox wrapper assertion failed: postInstall is missing .OpenCode-unwrapped" >&2
              return 1
            fi

            if [[ "$post_install" != *"makeBinaryWrapper $fnox"* ]]; then
              echo "$configuration opencode-desktop fnox wrapper assertion failed: postInstall is missing makeBinaryWrapper $fnox" >&2
              return 1
            fi

            if [[ "$native_build_inputs" != *"$make_binary_wrapper"* ]]; then
              echo "$configuration opencode-desktop fnox wrapper assertion failed: nativeBuildInputs is missing $make_binary_wrapper" >&2
              return 1
            fi

            if [[ "$post_install" != *"--prefix PATH : \"$profile_bin\""* ]]; then
              echo "$configuration opencode-desktop fnox wrapper assertion failed: postInstall is missing profile PATH prefix $profile_bin" >&2
              return 1
            fi
          }

          assert_wrapper \
            gha-aarch64-darwin \
            ${lib.escapeShellArg (ghaOpencodeDesktop.postInstall or "")} \
            ${lib.escapeShellArg "${self.darwinConfigurations.gha-aarch64-darwin.pkgs.fnox}/bin/fnox"} \
            ${lib.escapeShellArg (lib.concatStringsSep "\n" (map toString (ghaOpencodeDesktop.nativeBuildInputs or [])))} \
            ${lib.escapeShellArg (toString ghaMakeBinaryWrapper)} \
            ${lib.escapeShellArg ghaProfileBin}
          echo "gha-aarch64-darwin opencode-desktop fnox wrapper assertion passed"

          assert_wrapper \
            D3W27G1QW9 \
            ${lib.escapeShellArg (cventOpencodeDesktop.postInstall or "")} \
            ${lib.escapeShellArg "${self.darwinConfigurations.D3W27G1QW9.pkgs.fnox}/bin/fnox"} \
            ${lib.escapeShellArg (lib.concatStringsSep "\n" (map toString (cventOpencodeDesktop.nativeBuildInputs or [])))} \
            ${lib.escapeShellArg (toString cventMakeBinaryWrapper)} \
            ${lib.escapeShellArg cventProfileBin}
          touch "$out"
        '';
      }
    );
  in {
    # Preserve checks.trajectory on every configured system while adding the
    # Cvent certificate check only where its Darwin configuration is native.
    checks =
      certificateChecks
      // {
        trajectory = pkgs.runCommand "trajectory-tests" {} ''
          cd ${self}
          ${./tests/trajectory.sh}
          touch "$out"
        '';
      };

    apps = {
      # Certificate testing app - runs the bash script in your local environment
      test-certs = {
        type = "app";
        program = "${pkgs.writeShellScript "test-certs" ''
          #!/usr/bin/env bash
          cd ${self}
          export NETSKOPE_ROOT_CERT=${./modules/cvent/netskope-root.pem}
          exec ${./tests/certs.sh}
        ''}";
        meta.description = "Run certificate validation tests";
      };
    };
  };
}
