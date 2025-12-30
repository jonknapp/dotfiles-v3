{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nixToolbox;

  homeManagerWrapper = pkgs.writeShellScriptBin "home-manager" ''
    #!/bin/bash

    has_flake=false
    for arg in "$@"; do
      if [[ "$arg" == "--flake" ]]; then
        has_flake=true
        break
      fi
    done

    if $has_flake; then
      exec ${pkgs.home-manager}/bin/home-manager "$@"
    else
      hostname="$(${hostHostname}/bin/host-hostname)"
      echo "using: --flake $HOME/.config/home-manager#$USER@$hostname"
      exec ${pkgs.home-manager}/bin/home-manager "$@" "--flake" "$HOME/.config/home-manager#$USER@$hostname";
    fi
  '';

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

    mkdir "$data_dir/applications"
    cp -rL ~/.nix-profile/share/applications/* "$data_dir/applications/"

    # NOTE: Does not appear to work in cosmic atomic
    # cp -L ~/.config/nix-toolbox-profile/mimeapps.list "$HOME/.config/"

    mkdir "$data_dir/fonts"
    cp -rL ~/.nix-profile/share/fonts/* "$data_dir/fonts/"

    # if [ -f ~/.config/fontconfig/conf.d/52-default-fonts.conf ]; then
    #   sudo rm ~/.config/fontconfig/conf.d/52-default-fonts.conf
    # fi
    # cp ~/.config/fontconfig/conf.d/52-hm-default-fonts.conf ~/.config/fontconfig/conf.d/52-default-fonts.conf

    # if [ -f ~/.config/fontconfig/conf.d/90-noto-emoji-disable.conf ]; then
    #   sudo rm ~/.config/fontconfig/conf.d/90-noto-emoji-disable.conf
    # fi
    # cp ~/.config/fontconfig/conf.d/90-hm-noto-emoji-disable.conf ~/.config/fontconfig/conf.d/90-noto-emoji-disable.conf

    /usr/bin/flatpak-spawn --host fc-cache -f

    mkdir "$data_dir/icons/"
    cp -rL ~/.nix-profile/share/icons/* "$data_dir/icons/"

    mkdir --parents ~/.bashrc.d

    # I think we want to always call this; inside toolbox or on host
    cp -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh ~/.bashrc.d/hm-session-vars.sh

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
    home.activation.setupNixToolbox = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      run ${postActivation}/bin/nix-toolbox-post-activation
    '';

    home.packages = [
      homeManagerWrapper
      hostBinaries
      hostHostname
    ];

    # disable home-manager so we rely on our wrapper instead
    programs.home-manager.enable = false;
  };
}
