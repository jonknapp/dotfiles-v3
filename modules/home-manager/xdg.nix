{
  inputs,
  ...
}:
{
  flake.modules.homeManager.xdg =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      xdg.enable = true;
      xdg.cacheHome = "${config.home.homeDirectory}/.cache";
      xdg.configHome = "${config.home.homeDirectory}/.config";
      xdg.dataHome = "${config.home.homeDirectory}/.local/share";
      xdg.mimeApps.enable = lib.mkDefault true;
      xdg.stateHome = "${config.home.homeDirectory}/.local/state";
    };

  flake.modules.homeManager.nix-toolbox =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      xdg.mimeApps.enable = false; # not sure if it hurts to have this enabled

      # override where file is stored so we don't mess with home directory
      # xdg.configFile."mimeapps.list".target = "nix-toolbox-profile/mimeapps.list";

      # add our custom data dir to xdg data dirs
      xdg.systemDirs.data = [ "${config.home.homeDirectory}/.local/share/nix-toolbox-profile/share" ];
    };
}
