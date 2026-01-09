{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nixToolbox;

  homeManagerWrapper = inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.home-manager;
    runtimeInputs = [ hostHostname ];
    flags = {
      "--flake" = "$HOME/.config/home-manager#$USER@$(host-hostname)";
    };
    preHook = ''
      flake_found=false

      for arg in "$@"; do
        if [[ "$arg" == "--flake" ]]; then
          flake_found=true
        fi
      done

      if ! $flake_found; then
        echo "using: --flake $HOME/.config/home-manager#$USER@$(host-hostname)" >&2
      fi
    '';
  };

  hostBinaries = pkgs.stdenv.mkDerivation {
    name = "fedoraHost";
    src = null;

    buildInputs = [ ];

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/bin

      cat <<EOF > $out/bin/podman
      #!/bin/bash
      /usr/bin/flatpak-spawn --host podman "\$@"
      EOF

      cat <<EOF > $out/bin/systemctl
      #!/bin/bash
      /usr/bin/flatpak-spawn --host systemctl "\$@"
      EOF

      cat <<EOF > $out/bin/xdg-open
      #!/bin/bash
      /usr/bin/flatpak-spawn --env=DISPLAY=:0 --host xdg-open "\$@"
      EOF

      chmod +x $out/bin/*
    '';
  };

  hostHostname = pkgs.writeShellScriptBin "host-hostname" ''
    #!/bin/bash

    echo "$(/usr/bin/flatpak-spawn --host hostname)"
  '';

  postActivation = pkgs.writeShellScriptBin "nix-toolbox-post-activation" ''
    data_dir="$HOME/.local/share/nix-toolbox-profile/share"

    if [ -d "$data_dir" ]; then
      ${pkgs.fd}/bin/fd . "$data_dir" -t d -x chmod u+wx
      rm -rf "$data_dir"
    fi
    mkdir --parents "$data_dir"

    if [ -d ~/.nix-profile/share/applications ]; then
      mkdir "$data_dir/applications"
      cp -rL ~/.nix-profile/share/applications/* "$data_dir/applications/"
    fi

    # NOTE: Does not appear to work in cosmic atomic
    # cp -L ~/.config/nix-toolbox-profile/mimeapps.list "$HOME/.config/"

    if [ -d ~/.nix-profile/share/fonts ]; then
      mkdir "$data_dir/fonts"
      cp -rL ~/.nix-profile/share/fonts/* "$data_dir/fonts/"
    fi

    # Required to force Cosmic Text into allowing nix font override.
    if [ -f ~/.config/fontconfig/fonts.conf ]; then
      target="$(readlink -f ~/.config/fontconfig/fonts.conf)"

      # Only proceed if the symlink resolves to a regular file
      if [[ -f "$target" ]]; then
        # Remove the symlink
        rm ~/.config/fontconfig/fonts.conf

        # Copy the real file into its place
        cp -a "$target" ~/.config/fontconfig/fonts.conf
      fi
    fi

    CONF_DIR="$HOME/.config/fontconfig/conf.d"
    if [ -d "$CONF_DIR" ]; then
      find "$CONF_DIR" -maxdepth 1 -type l | while read -r link; do
        target="$(readlink -f "$link")"

        # Only proceed if the symlink resolves to a regular file
        if [[ -f "$target" ]]; then
          # Remove the symlink
          rm "$link"

          # Copy the real file into its place
          cp -a "$target" "$link"
        fi
      done
    fi

    /usr/bin/flatpak-spawn --host fc-cache -f

    if [ -d ~/.nix-profile/share/icons ]; then
      mkdir "$data_dir/icons/"
      cp -rL ~/.nix-profile/share/icons/* "$data_dir/icons/"
    fi

    mkdir --parents ~/.bashrc.d

    if [ -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then
      # I think we want to always call this; inside toolbox or on host
      cp -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh ~/.bashrc.d/hm-session-vars.sh
    fi

    if [ -f "~/.config/nix-toolbox-profile/.ssh/config" ]; then
      rm -f "$HOME/.ssh/config"
      cp -L ~/.config/nix-toolbox-profile/.ssh/config "$HOME/.ssh/config"
    fi

    # Commented out because it seems to be called by Home Manager.
    # Should we include this outside of our initExtras bash hm config?
    # cp -f ~/.nix-profile/etc/profile.d/nix.sh ~/.bashrc.d/02-nix.sh

    # Ideally, we don't call this unless inside a nix toolbox. I think.
    # cp -f ~/.config/bash/.bashrc ~/.bashrc.d/03-hm-bashrc.sh

    # setup printers on linux with cups at http://localhost:631/
  '';
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
    home.activation.clearSystemdUser = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      run rm -rf ~/.config/fontconfig/conf.d
      run rm -rf ~/.config/fontconfig/fonts.conf
      run rm -rf ~/.config/systemd/user
    '';

    home.activation.duplicateSystemdUnits = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      echo "Duplicating systemd user units to host"

      if [ -d ~/.config/systemd/user ]; then
        run echo "Backing up existing systemd user units"
        run mv ~/.config/systemd/user ~/.config/systemd/user.original
        run mkdir -p ~/.config/systemd/user
        run cp -rL ~/.config/systemd/user.original/* ~/.config/systemd/user
      fi

      if [ -d ~/.config/systemd/user.original ]; then
        run rm -rf ~/.config/systemd/user.original
      fi
    '';

    home.activation.setupNixToolbox = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      run ${postActivation}/bin/nix-toolbox-post-activation
    '';

    home.packages = [
      homeManagerWrapper
      hostBinaries
      hostHostname
    ];

    home.sessionVariablesExtra = lib.mkForce "";

    # disable home-manager so we rely on our wrapper instead
    programs.home-manager.enable = false;

    systemd.user.systemctlPath = "${hostBinaries}/bin/systemctl";
    targets.genericLinux.enable = true;
  };
}
