{
  inputs,
  ...
}:
{
  flake.modules.homeManager.xdg =
    {
      config,
      pkgs,
      ...
    }:
    {
      xdg.enable = true;
      xdg.cacheHome = "${config.home.homeDirectory}/.cache";
      xdg.configHome = "${config.home.homeDirectory}/.config";
      xdg.dataHome = "${config.home.homeDirectory}/.local/share";
      xdg.stateHome = "${config.home.homeDirectory}/.local/state";
    };

  flake.modules.homeManager.nixToolbox =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # override where file is stored so we don't mess with home directory
      # xdg.configFile."mimeapps.list".target = "nix-toolbox-profile/mimeapps.list";

      # add our custom data dir to xdg data dirs
      xdg.systemDirs.data = [ "${config.home.homeDirectory}/.local/share/nix-toolbox-profile/share" ];
    };
}
