{
  inputs,
  ...
}:
{
  flake.modules.homeManager.commonApplications =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        tailscale

        # used by tailscale systray for clipboard access in wayland
        # https://tailscale.com/kb/1597/linux-systray#support-for-non-linux-desktops
        wl-clipboard
      ];
    };

  flake.modules.homeManager.nixToolbox =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.bash = {
        initExtra = ''
          # tailscale trayscale &
        '';
      };
    };
}
