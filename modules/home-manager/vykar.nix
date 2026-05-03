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
      vykarPackages = inputs.vykar.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      home.packages = with vykarPackages; [
        vykar
        vykar-gui
      ];

      xdg.desktopEntries = {
        vykar = {
          name = "Vykar - Backups";
          exec = "toolbox run --container ${config.programs.nixToolbox.containerName} ${vykarPackages.vykar-gui}/bin/vykar-gui";
          terminal = false;
          categories = [
            "Network"
          ];
          icon = "application-x-executable";
        };
      };
    };
}
