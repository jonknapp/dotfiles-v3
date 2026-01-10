{
  inputs,
  ...
}:
{
  flake.modules.homeManager.bash =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.shell.enableBashIntegration = true;

      programs.bash.enable = true;
    };

  flake.modules.homeManager.nixToolbox =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # This stops bash config files from being placed in $HOME which breaks host terminal usage.
      home.file.".bashrc".target = "${config.xdg.configHome}/bash/.bashrc";
      home.file.".bash_profile".target = "${config.xdg.configHome}/bash/.bash_profile";
      home.file.".profile".target = "${config.xdg.configHome}/bash/.profile";

      # run this last after the shell has been setup
      programs.bash.initExtra = lib.mkOrder 2000 ''
        # resolve issues with dbus activation environment
        flatpak-spawn --host --env=DISPLAY=:0 dbus-update-activation-environment --all --systemd
      '';
    };
}
