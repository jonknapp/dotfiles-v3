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
