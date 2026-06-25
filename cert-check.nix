{self, ...}: {
  perSystem = {pkgs, ...}: {
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
