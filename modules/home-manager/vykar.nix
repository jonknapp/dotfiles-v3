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

  perSystem =
    { pkgs, ... }:
    let
      vykarPackages = inputs.vykar.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      packages = {
        inherit (vykarPackages) vykar vykar-gui;
      };
    };

  flake.modules.homeManager.vykar =
    {
      config,
      pkgs,
      ...
    }:
    let
      selfPackages = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      home.packages = with selfPackages; [
        vykar
        vykar-gui
      ];

      xdg.desktopEntries = {
        vykar = {
          name = "Vykar - Backups";
          exec = "toolbox run --container ${config.programs.nixToolbox.containerName} ${selfPackages.vykar-gui}/bin/vykar-gui";
          terminal = false;
          categories = [
            "Network"
          ];
          icon = "application-x-executable";
        };
      };
    };
}
