{ inputs, ... }:

{
  flake.modules.homeManager.direnv =
    {
      config,
      pkgs,
      ...
    }:
    {
      programs.direnv.enable = true;
      programs.direnv.nix-direnv.enable = true;
    };
}
