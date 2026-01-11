{
  inputs,
  ...
}:
let
  host = "megaman";
in
{
  flake.modules.homeManager.${host} =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.homeManager; [
        base
        common-applications
      ];
    };

  flake.homeConfigurations = inputs.self.lib.mkHomeManager {
    inherit host;
    system = "x86_64-linux";
    user = "jon";
  };
}
