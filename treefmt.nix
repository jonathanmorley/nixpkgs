{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];
  perSystem = {...}: {
    treefmt = {
      settings.on-unmatched = "fatal"; # Ensure 100% coverage
      programs.actionlint.enable = true; # github action linter
      programs.alejandra.enable = true; # nix
      programs.deadnix.enable = true; # nix
      programs.nixf-diagnose.enable = true; # nix
      programs.mdformat.enable = true; # markdown
      programs.shfmt.enable = true; # shell
      programs.shellcheck.enable = true; # shell
      programs.jsonfmt.enable = true; # JSON
    };
  };
}
