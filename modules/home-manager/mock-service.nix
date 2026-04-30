{ inputs, ... }:
{
  flake.modules.homeManager.nixToolbox = {
    imports = [ ../../programs/mock-service/default.nix ];
  };
}
