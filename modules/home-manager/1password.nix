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
    let
      op = pkgs._1password-cli;
      # Runs `op` with the onepassword-cli group (stand-in for the setgid bit,
      # which store paths can't have). The group and membership are created by
      # `nix run .#setup-new-machine`.
      _1password-cli-sg = inputs.wrappers.lib.wrapPackage {
        inherit pkgs;
        package = op;
        exePath = "${op}/bin/op";
        binName = "op";
        wrapper = attrs: ''
          #!${pkgs.stdenv.shell}
          # sg only accepts a single command string (run via `sh -c`), so each
          # argument is shell-quoted with printf %q to preserve spaces/quotes.
          exec sg onepassword-cli -c "$(printf '%q ' ${op}/bin/op "$@")"
        '';
      };
    in
    {
      home.packages =
        with pkgs;
        [
          _1password-gui
        ]
        ++ [
          _1password-cli-sg
        ];

      home.sessionVariables = {
        SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
        # OP_BIOMETRIC_UNLOCK_ENABLED = "true";
        # OP_PLUGIN_ALIASES_SOURCED = "1";
      };

      programs.ssh = {
        package = pkgs.emptyDirectory;
        settings = {
          "Host *" = {
            IdentityAgent = "~/.1password/agent.sock";
          };
        };
      };
    };

  flake.modules.homeManager.nix-toolbox =
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
            sed 's|Exec=1password|#Exec=1password\nExec=toolbox run --container ${config.programs.nixToolbox.containerName} 1password|g' \
              ${pkgs._1password-gui}/share/applications/com.onepassword.OnePassword.desktop \
              > $out/share/applications/com.onepassword.OnePassword.desktop
          ''
        ))
      ];
    };
}
