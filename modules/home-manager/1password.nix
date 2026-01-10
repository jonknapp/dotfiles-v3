{
  inputs,
  ...
}:
{
  flake.modules.homeManager._1password =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        _1password-cli
        _1password-gui
      ];

      home.sessionVariables = {
        SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
        # OP_BIOMETRIC_UNLOCK_ENABLED = "true";
        # OP_PLUGIN_ALIASES_SOURCED = "1";
      };

      programs.bash = {
        initExtra = ''
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
        '';

        shellAliases = {
          # 1password with plugins
          op = "run-op";
          #   gh = "run-op plugin run -- gh";
          #   glab = "run-op plugin run -- glab";
        };
      };

      programs.ssh = {
        package = pkgs.emptyDirectory;
        matchBlocks = {
          "*" = {
            extraOptions = {
              IdentityAgent = "~/.1password/agent.sock";
            };
          };
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
      home.packages = [
        (lib.hiPrio (
          pkgs.runCommand "1password-desktop-modify" { } ''
            mkdir -p $out/share/applications
            substitute ${pkgs._1password-gui}/share/applications/1password.desktop $out/share/applications/1password.desktop \
              --replace-fail "Exec=1password" "Exec=toolbox run --container ${config.programs.nixToolbox.containerName} 1password"
          ''
        ))
      ];
    };
}
