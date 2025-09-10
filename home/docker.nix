# See https://nix-community.github.io/home-manager/options.xhtml
{
  pkgs,
  lib,
  config,
  specialArgs,
  ...
}: {
  home.packages = with pkgs;
  # Tools
    [
      amazon-ecr-credential-helper
      docker-buildx
      docker-client
      (writeShellScriptBin "docker-credential-gh" ''
        echo "{\"Username\":\"JMorley_cvent\",\"Secret\":\"$(${lib.getExe pkgs.gh} auth token --user JMorley_cvent)\"}"
      '')
    ]
    ++ lib.optional pkgs.stdenv.isDarwin colima;

  # Copy the docker config so that docker login can write to it.
  # We can't use `mkOutOfStoreSymlink` because it may contain secrets we don't want to accidentally commit.
  home.activation.writeDockerConfig = let
    contents = (pkgs.formats.json {}).generate "config.json" ({
        credHelpers."ghcr.io" = "gh";
        # CDK has a hardcoded `docker login` that _still_ doesn't play nice with the ECR docker credential helper,
        # even when using AWS_ECR_IGNORE_CREDS_STORAGE, so we can't use it as a catch-all until that is addressed.
        # See https://github.com/aws/aws-cdk/issues/32925.
        # credsStore = "ecr-login";
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        currentContext = "colima";
      });
    path = "${config.home.homeDirectory}/.docker/config.json";
  in
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p $(dirname ${path})
      run cp -f ${contents} ${path}
      run chmod a+w ${path}
    '';

  home.shellAliases.dockerv = "${pkgs.docker-client}/bin/docker run ${lib.cli.toGNUCommandLineShell {} {
    interactive = true;
    tty = true;
    rm = true;
    volume = "$(pwd):$(pwd)";
    workdir = "$(pwd)";
  }}";
  home.sessionVariables.AWS_ECR_IGNORE_CREDS_STORAGE = "true"; # Allow `docker login` to succeed
  home.file."colima template" = lib.mkIf pkgs.stdenv.isDarwin {
    target = ".colima/_templates/default.yaml";
    source = (pkgs.formats.yaml {}).generate "default.yaml" {
      runtime = "docker";
      vmType = "vz";
      memory = 16;
      rosetta = true;
      network.address = true;
      mounts = [
        {
          location = "/tmp/colima";
          mountPoint = "/tmp/colima";
          writable = true;
        }
        {
          location = "/private/var/folders";
          mountPoint = "/private/var/folders";
          writable = true;
        }
        {
          location = "/Users/${specialArgs.username}";
          mountPoint = "/Users/${specialArgs.username}";
          writable = true;
        }
      ];
    };
  };
}
