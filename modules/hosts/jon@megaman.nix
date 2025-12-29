{
  inputs,
  ...
}:
let
  machine = "megaman";
  username = "jon";
  configHame = "${username}@${machine}";
in
{
  flake.modules.homeManager."${configHame}" =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.homeManager; [
        base
        commonApplications
      ];

      home.username = "${username}";
    };

  flake.homeConfigurations = inputs.self.lib.mkHomeManager "x86_64-linux" "${configHame}";
}
