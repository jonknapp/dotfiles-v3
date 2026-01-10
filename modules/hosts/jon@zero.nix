{
  inputs,
  ...
}:
let
  machine = "zero";
  username = "jon";
  configHame = "${username}@${machine}";
in
{
  flake.modules.homeManager."${configHame}" =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.homeManager; [
        base
        common-applications
        cosmic-atomic
      ];

      home.username = "${username}";

      programs.nixToolbox.containerName = "nix-43";
    };

  flake.homeConfigurations = inputs.self.lib.mkHomeManager "x86_64-linux" "${configHame}";
}
