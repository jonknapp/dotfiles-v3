{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nixToolbox;
  hostBinaries = pkgs.stdenv.mkDerivation {
    name = "fedoraHost";
    src = null;

    buildInputs = [ ];

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/bin

      cat <<EOF > $out/bin/xdg-open
      #!/bin/bash
      /usr/bin/flatpak-spawn --env=DISPLAY=:0 --host xdg-open "\$@"
      EOF

      chmod +x $out/bin/*
    '';
  };
in
{
  options.programs.nixToolbox = {
    enable = lib.mkEnableOption "Toolbx container support for Nix";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "nix";
      description = "Name of the toolbx container.";
    };
  };

  config = lib.mkIf cfg.enable {
    # TODO: This is where we'd write pre/post HM switch scripts and possibly
    #       pre/post installation scripts.

    # Example: expose container name to user environment
    home.sessionVariables.MY_TOOLBOX_CONTAINER_NAME = cfg.containerName;

    # For various final configurations
    home.activation.toolboxSetup = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      # Only for toolbox
      test -f /run/.toolboxenv || exit
    '';

    # Example: install a package configured by the option
    # home.packages = [
    #   (pkgs.writeShellScriptBin "my-container-info" ''
    #     echo "Container name: ${cfg.containerName}"
    #   '')
    # ];

    home.packages = [
      hostBinaries
    ];
  };
}
