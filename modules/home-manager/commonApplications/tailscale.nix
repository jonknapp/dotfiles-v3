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
      home.packages = [
        (lib.hiPrio (
          pkgs.stdenv.mkDerivation {
            pname = "wrapped-tailscale";
            version = "1.0";
            dontUnpack = true;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              mkdir -p $out/bin

              makeWrapper ${pkgs.tailscale}/bin/tailscale $out/bin/tailscale \
                --add-flags "--socket \$XDG_RUNTIME_DIR/tailscaled.sock"
            '';
          }
        ))
      ];

      systemd.user.services.tailscale-systray = {
        Unit = {
          Description = "Start tailscale systray";
          Requires = [
            "tailscaled.service"
            "tray.target"
          ];
          After = [
            "tailscaled.service"
            "tray.target"
          ];
        };

        Service = {
          ExecStart = ''
            toolbox --container ${config.programs.nixToolbox.containerName} run tailscale systray
          '';
          Type = "exec";
        };
      };

      systemd.user.services.tailscaled = {
        Unit = {
          Description = "Start tailscaled with user networking";
          Wants = [ "network-pre.target" ];
          After = [
            "network-pre.target"
            "NetworkManager.service"
            "systemd-resolved.service"
          ];
          BindsTo = [ "tailscale-systray.service" ];
        };

        Service = {
          ExecStart = ''
            toolbox --container ${config.programs.nixToolbox.containerName} run tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 --socket=%t/tailscaled.sock
          '';
          ExecStopPost = "tailscaled --socket=%t/tailscaled.sock --cleanup";
          Restart = "on-failure";
          RuntimeDirectory = "tailscale";
          RuntimeDirectoryMode = "0755";
          StateDirectory = "tailscale";
          StateDirectoryMode = "0700";
          CacheDirectory = "tailscale";
          CacheDirectoryMode = "0750";
          Type = "simple";
        };
      };

      xdg.desktopEntries = {
        tailscale-systray = {
          name = "Tailscale";
          exec = "systemctl --user start --no-block tailscale-systray.service";
          terminal = false;
          categories = [
            "Network"
          ];
          icon = "application-x-executable";
        };
      };
    };
}
