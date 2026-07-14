{self, ...}: {
  perSystem = {pkgs, ...}: {
    checks.certificates = pkgs.runCommand "certificate-tests" {nativeBuildInputs = [pkgs.openssl];} ''
      ${./tests/certs-static.sh} ${./modules/cvent}
      touch "$out"
    '';

    checks.trajectory = pkgs.runCommand "trajectory-tests" {} ''
      cd ${self}
      ${./tests/trajectory.sh}
      touch "$out"
    '';

    apps = {
      # Certificate testing app - runs the bash script in your local environment
      test-certs = {
        type = "app";
        program = "${pkgs.writeShellScript "test-certs" ''
          #!/usr/bin/env bash
          cd ${self}
          exec ${./tests/certs.sh}
        ''}";
        meta.description = "Run certificate validation tests";
      };
    };
  };
}
