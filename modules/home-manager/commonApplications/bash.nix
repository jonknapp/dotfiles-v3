{
  inputs,
  ...
}:
{
  flake.modules.homeManager.commonApplications =
    {
      config,
      pkgs,
      ...
    }:
    {
      programs.bash = {
        enable = true;
        initExtra = ''
          if test -f /run/.toolboxenv; then
            source "$HOME/.nix-profile/etc/profile.d/nix.sh"
          else
            return
          fi

          # Add onepassword-cli group required for 1password CLI integration to work
          if ! grep -q onepassword-cli /etc/group; then
            echo "Adding 'onepassword-cli' group"
            sudo groupadd -f onepassword-cli
            sudo usermod -aG onepassword-cli $(whoami)
          fi

          # 1password needs to be run with the correct group for app CLI integration to work
          run-op() {
            sg onepassword-cli -c "op $*"
          }

          # resolve issues with dbus activation environment
          flatpak-spawn --host --env=DISPLAY=:0 dbus-update-activation-environment --all --systemd
        '';

        shellAliases = {
          # 1password with plugins
          op = "run-op";
          #   gh = "run-op plugin run -- gh";
          #   glab = "run-op plugin run -- glab";
        };
      };

      home.shell.enableBashIntegration = true;
    };

  flake.modules.homeManager.nixToolbox =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # TODO: Move me to nix-toolbox
      # This stops bash config files from being placed in $HOME which breaks host terminal usage.
      home.file.".bashrc".target = "${config.xdg.configHome}/bash/.bashrc";
      home.file.".bash_profile".target = "${config.xdg.configHome}/bash/.bash_profile";
      home.file.".profile".target = "${config.xdg.configHome}/bash/.profile";
    };
}
