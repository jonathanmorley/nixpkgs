{
  lib,
  pkgs,
  ...
}: {
  home.packages = [pkgs.fnox];
  programs.zsh.initContent = lib.mkBefore ''
    eval "$(fnox activate zsh)"
  '';
}
