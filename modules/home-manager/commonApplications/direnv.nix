{ inputs, ... }:

{
  flake.modules.homeManager.commonApplications =
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
