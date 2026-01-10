{
  inputs,
  ...
}:
{
  flake.modules.homeManager.ssh =
    {
      config,
      pkgs,
      ...
    }:
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks = {
          # "*.repo.borgbase.com" = {
          #   identityFile = "~/.ssh/id_ed25519.pub";
          # };
        };
      };
    };

  flake.modules.homeManager.nixToolbox =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.file.".ssh/config".target = "${config.xdg.configHome}/nix-toolbox-profile/.ssh/config";
    };
}
