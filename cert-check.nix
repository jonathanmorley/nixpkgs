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
