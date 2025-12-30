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
      home.packages = with pkgs; [
        _1password-cli
        _1password-gui
      ];

      home.sessionVariables = {
        SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
        # OP_BIOMETRIC_UNLOCK_ENABLED = "true";
        # OP_PLUGIN_ALIASES_SOURCED = "1";
      };

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        package = pkgs.emptyDirectory;
        matchBlocks = {
          # "*.repo.borgbase.com" = {
          #   identityFile = "~/.ssh/id_ed25519.pub";
          # };
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

      # TODO: Move me to nix-toolbox
      home.file.".ssh/config".target = "${config.xdg.configHome}/nix-toolbox-profile/.ssh/config";
    };
}
