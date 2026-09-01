# nixpkgs

After creating a PR in this repository, enable automerge on it (e.g., `gh pr merge --auto --squash`).

## Baseline vs Personal

- **Baseline** — everything `lib/mkDarwinSystem.nix` imports by default: `modules/darwin.nix`, `modules/home.nix`, `modules/ai/*`, `modules/docker/*`, `modules/git/*`, `modules/secrets/*`. This is what external flakes get via `flake.lib.mkDarwinSystem`; it must stay free of personal-only content.
- **Personal** — `modules/personal/darwin.nix`, only imported when the `personal` profile is active (see `lib/mkDarwinSystem.nix`). Personal machines (`medusa`) enable it; the CI host (`gha-aarch64-darwin`, profiles = `[]`) does not.

Rule: anything you'd mind sharing gets a `personal` gate, never a default import. The `gha-aarch64-darwin` configuration is the proof the baseline stays clean.
