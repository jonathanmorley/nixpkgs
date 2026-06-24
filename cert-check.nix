{self, ...}: {
  perSystem = {pkgs, ...}: {
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
      test-trajectory = {
        type = "app";
        program = "${pkgs.writeShellScript "test-trajectory" ''
          #!/usr/bin/env bash
          cd ${self}
          exec ${pkgs.bash}/bin/bash ${./tests/trajectory.sh}
        ''}";
        meta.description = "Run Trajectory AI instrumentation tests";
      };
    };
  };
}
