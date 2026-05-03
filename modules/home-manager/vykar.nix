{
  inputs,
  ...
}:
{
  flake-file.inputs = {
    vykar = {
      url = "github:borgbase/vykar/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  flake.modules.homeManager.vykar =
    {
      config,
      pkgs,
      ...
    }:
    let
      vykar-gui = inputs.vykar.packages.${pkgs.stdenv.hostPlatform.system}.vykar-gui;
    in
    {
      home.packages = [
        inputs.vykar.packages.${pkgs.stdenv.hostPlatform.system}.vykar
        vykar-gui
      ];

      xdg.desktopEntries = {
        vykar = {
          name = "Vykar - Backups";
          exec = "toolbox run --container ${config.programs.nixToolbox.containerName} ${vykar-gui}/bin/vykar-gui";
          terminal = false;
          categories = [
            "Network"
          ];
          icon = "application-x-executable";
        };
      };
    };
}
