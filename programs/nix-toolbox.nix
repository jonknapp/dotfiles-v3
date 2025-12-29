{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nixToolbox;
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

    # Example: install a package configured by the option
    # home.packages = [
    #   (pkgs.writeShellScriptBin "my-container-info" ''
    #     echo "Container name: ${cfg.containerName}"
    #   '')
    # ];
  };
}
