{ ... }:
{
  flake.modules.homeManager.nixToolbox = {
    imports = [ ../../programs/nix-toolbox.nix ];
  };
}
