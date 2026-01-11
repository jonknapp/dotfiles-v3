{
  inputs,
  ...
}:
let
  host = "zero";
in
{
  flake.modules.homeManager.${host} =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.homeManager; [
        base
        common-applications
        cosmic-atomic
      ];

      programs.nixToolbox.containerName = "nix-43";
    };

  flake.homeConfigurations = inputs.self.lib.mkHomeManager {
    inherit host;
    system = "x86_64-linux";
    user = "jon";
  };
}
