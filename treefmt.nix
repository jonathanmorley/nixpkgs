{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];
  perSystem = {...}: {
    treefmt = {
      settings.on-unmatched = "fatal"; # Ensure 100% coverage
      # Nested standalone repo (opencode-claude-compat) — formatted by its own toolchain (bun/prettier).
      settings.excludes = ["opencode-claude-compat/**"];
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
