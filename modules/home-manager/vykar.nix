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

  # By default the Nix vykar-gui binary runs directly on the host (e.g.
  # megaman, zero). The nix-toolbox module below overrides the desktop entry to
  # run it inside the toolbox container instead.
  flake.modules.homeManager.vykar =
    {
      lib,
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

      # Reference config to copy from when creating a real vykar config.
      xdg.configFile."vykar/config.yaml.template".source = ./vykar/config.yaml.template;

      xdg.desktopEntries = {
        vykar = {
          name = "Vykar - Backups";
          exec = lib.mkDefault "${selfPackages.vykar-gui}/bin/vykar-gui";
          terminal = false;
          categories = [
            "Network"
          ];
          icon = "application-x-executable";
        };
      };
    };

  flake.modules.homeManager.nix-toolbox =
    {
      config,
      pkgs,
      ...
    }:
    let
      selfPackages = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      # Run the GUI inside the toolbox container.
      xdg.desktopEntries.vykar.exec = "toolbox run --container ${config.programs.nixToolbox.containerName} ${selfPackages.vykar-gui}/bin/vykar-gui";
    };
}
